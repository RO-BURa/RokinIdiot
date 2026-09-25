--!nonstrict
-- 왼쪽 패널. 아이템 → 엘리먼트 → 트랙 트리를 그리고 추가/삭제를 처리한다.
--
--   v 1  Character1                       [+] [...]
--       v MainParticle                    [+] [...]
--           Enabled                       [키] [...]
--           :Emit()
--   v 2  Character2                       [+] [...]
--
-- 기호는 ASCII와 직접 그린 도형만 쓴다. 폰트에 없는 특수문자는 네모로 깨진다.

local Selection = game:GetService("Selection")
local TextService = game:GetService("TextService")

local Component = require(script.Parent.Parent.Component)
local Create = require(script.Parent.Parent.Create)
local Theme = require(script.Parent.Parent.Theme)
local Button = require(script.Parent.Parent.Components.Button)
local Menu = require(script.Parent.Parent.Components.Menu)
local Dialog = require(script.Parent.Parent.Components.Dialog)

local Ops = require(script.Parent.Parent.Parent.Core.Ops)
local Schema = require(script.Parent.Parent.Parent.Core.Schema)
local PathSpec = require(script.Parent.Parent.Parent.Core.PathSpec)
local RigResolver = require(script.Parent.Parent.Parent.Core.RigResolver)
local Store = require(script.Parent.Parent.Parent.Plugin.Store)
local Metrics = require(script.Parent.Metrics)
local ViewOptions = require(script.Parent.ViewOptions)
local TrackPicker = require(script.Parent.TrackPicker)
local Locale = require(script.Parent.Parent.Parent.Core.Locale)

local ElementTree = Component.extend()

local INDENT = 12
-- 왼쪽에 붙인 스크롤 막대(6px) 위로 접기 화살표가 올라가지 않게 띄운다.
-- 막대가 없을 때도 같은 값을 쓴다. 목록이 길어질 때 줄이 옆으로 튀는 것보다
-- 늘 조금 들여쓰는 편이 낫다.
local BASE_INSET = 10
local ACTION_WIDTH = 46

-- 값 타입 꼬리표. 글자 길이에 맞춰 줄어들고 이 폭을 넘지 않는다.
local TAG_TEXT_SIZE = 10
local TAG_GAP = 8
local MAX_TAG_WIDTH = 88
local TAG_BOUNDS = Vector2.new(200, 20)

local function trim(text: string): string
	return text:match("^%s*(.-)%s*$") or ""
end

-- 모델 안에 Motor6D가 있으면 리그로 본다.
local function detectItemKind(instance: Instance): string
	if instance:FindFirstChildWhichIsA("Motor6D", true) then
		return Schema.ITEM_KIND.RIG
	end
	return Schema.ITEM_KIND.OBJECT
end

function ElementTree.new(props)
	local self = Component.construct(ElementTree)

	self._state = props.State
	self._project = props.State.Project
	self._overlay = props.Overlay
	self._rowObjects = {}
	self._syncingScroll = false

	local root = Create("Frame", {
		Name = "ElementTree",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = props.Parent,
	})
	self.Instance = root

	--------------------------------------------------------------------------
	-- 머리말
	--------------------------------------------------------------------------

	local header = Create("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, Metrics.HEADER_HEIGHT),
		Parent = root,
	}, {
		Create.padding(0, 6),
	})

	self._headerLabel = Create.label({
		Name = "Title",
		Text = "ELEMENTS",
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		Size = UDim2.new(1, -90, 1, 0),
		Parent = header,
	})

	self._addItemButton = Button.new({
		Text = "+ Item",
		Variant = "default",
		TextSize = 11,
		Size = UDim2.new(0, 0, 0, 20),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		OnClick = function()
			self:_promptAddItem()
		end,
		Parent = header,
	})
	self:Track(self._addItemButton)

	-- 오른쪽 눈금자와 같은 높이의 띠.
	-- 예전에는 행 시작 위치를 맞추려고 비워둔 자리였는데, 미리보기 조작
	-- 버튼(Preview / Play / 배속 / 반복)이 여기로 들어왔다. 그 버튼들은
	-- 재생기를 들고 있는 타임라인이 만들고, 여기는 자리만 내준다.
	self._rulerSpacer = Create("Frame", {
		Name = "RulerSpacer",
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, Metrics.HEADER_HEIGHT),
		Size = UDim2.new(1, 0, 0, Metrics.RULER_HEIGHT),
		Parent = root,
	})

	-- 버튼 줄은 한 겹 안에 둔다. 구분선까지 같은 부모에 두면 줄 세우기에
	-- 딸려 들어가서 아래가 아니라 버튼 옆에 서 버린다.
	--
	-- 타임라인이 여기에 조작 버튼을 붙인다 (EditorScreen이 이어준다).
	self.RulerSlot = Create("Frame", {
		Name = "TransportSlot",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = self._rulerSpacer,
	}, {
		Create.list(Enum.FillDirection.Horizontal, 4, {
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		Create.padding(0, 6),
	})

	-- 마커 줄을 껐을 때 여기가 구분선 자리가 된다.
	self._rulerDivider = Create("Frame", {
		Name = "Divider",
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
		Visible = false,
		Parent = self._rulerSpacer,
	})

	-- 오른쪽 키프레임 줄과 같은 높이의 띠. 여기엔 이름표만 둔다.
	-- 마커 자체는 시간 축 위에 있어야 하므로 오른쪽 패널이 그린다.
	self._markerSpacer = Create("Frame", {
		Name = "MarkerSpacer",
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, Metrics.HEADER_HEIGHT + Metrics.RULER_HEIGHT),
		Size = UDim2.new(1, 0, 0, Metrics.MARKER_HEIGHT),
		Parent = root,
	}, {
		Create.padding(0, 6),
	})

	self._markerLabel = Create.label({
		Name = "Title",
		Text = "KEYFRAMES",
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		Size = UDim2.fromScale(1, 1),
		Parent = self._markerSpacer,
	})

	self._headerDivider = Create("Frame", {
		Name = "Divider",
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
		Parent = self._markerSpacer,
	})

	--------------------------------------------------------------------------
	-- 행 목록
	--------------------------------------------------------------------------

	self._scroll = Create("ScrollingFrame", {
		Name = "Rows",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, Metrics.topHeight(true)),
		Size = UDim2.new(1, 0, 1, -Metrics.topHeight(true)),
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		-- 막대를 왼쪽에 붙인다. 오른쪽이면 두 패널 사이 경계에 붙어서
		-- 분할선처럼 보이고, 행 오른쪽 끝의 동작 버튼과도 겹쳐 보인다.
		VerticalScrollBarPosition = Enum.VerticalScrollBarPosition.Left,
		Parent = root,
	})

	self._empty = Create.label({
		Name = "Empty",
		Text = Locale.T("tree.empty"),
		TextSize = 11,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(10, Metrics.topHeight(true) + 10),
		Size = UDim2.new(1, -20, 0, 70),
		Visible = false,
		Parent = root,
	})

	-- 만들 때 넣은 글자는 언어를 바꿔도 남으므로 줄을 다시 만든다.
	local built = false
	self:BindLocale(function()
		self._empty.Text = Locale.T("tree.empty")
		if built then
			self:_rebuild()
		end
		built = true
	end)

	self:BindTheme(function(tokens)
		self:_applyTheme(tokens)
	end)

	self:Track(self._state.OutlineChanged:Connect(function()
		self:_rebuild()
	end))
	self:Track(self._state.SelectionChanged:Connect(function()
		self:_refreshSelection()
	end))

	-- 오른쪽 타임라인과 세로 스크롤을 맞춘다.
	self:Track(self._scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		if self._syncingScroll then
			return
		end
		self._state.ScrollChanged:Fire(self._scroll.CanvasPosition.Y, self)
	end))
	self:Track(self._state.ScrollChanged:Connect(function(y, source)
		if source == self then
			return
		end
		-- 이미 같은 값이면 건드리지 않는다. 두 패널이 서로를 계속 밀어대는
		-- 되먹임을 여기서 끊는다.
		if math.abs(self._scroll.CanvasPosition.Y - y) < 0.5 then
			return
		end
		self._syncingScroll = true
		self._scroll.CanvasPosition = Vector2.new(0, y)
		self._syncingScroll = false
	end))

	self:Track(ViewOptions.Changed:Connect(function()
		self:_applyViewOptions()
	end))

	self:_applyViewOptions()
	self:_rebuild()
	return self
end

-- 마커 줄을 끄면 행 목록이 그만큼 위로 올라온다.
-- 오른쪽 타임라인도 같은 값을 쓰므로 두 패널이 같이 움직인다.
function ElementTree:_applyViewOptions()
	local showMarkers = ViewOptions.AreMarkersVisible()
	local top = Metrics.topHeight(showMarkers)

	self._markerSpacer.Visible = showMarkers
	-- 마커 줄을 숨기면 그 밑에 붙어 있던 구분선도 같이 사라진다.
	-- 눈금자 쪽 구분선이 그 자리를 대신한다.
	self._rulerDivider.Visible = not showMarkers

	self._scroll.Position = UDim2.fromOffset(0, top)
	self._scroll.Size = UDim2.new(1, 0, 1, -top)
	self._empty.Position = UDim2.fromOffset(10, top + 10)
end
function ElementTree:_applyTheme(tokens)
	self._headerLabel.TextColor3 = tokens.color.textMuted
	self._rulerSpacer.BackgroundColor3 = tokens.color.panelAlt
	self._markerSpacer.BackgroundColor3 = tokens.color.panelAlt
	self._markerLabel.TextColor3 = tokens.color.textMuted
	self._rulerDivider.BackgroundColor3 = tokens.color.border
	self._headerDivider.BackgroundColor3 = tokens.color.border
	self._scroll.ScrollBarImageColor3 = tokens.color.border
	self._empty.TextColor3 = tokens.color.textMuted

	for _, row in self._rowObjects do
		row.applyTheme(tokens)
	end
end

--------------------------------------------------------------------------------
-- 그리기
--------------------------------------------------------------------------------

function ElementTree:_clearRows()
	for _, row in self._rowObjects do
		row.destroy()
	end
	table.clear(self._rowObjects)
end

function ElementTree:_rebuild()
	self:_clearRows()

	local rows, contentHeight = self._state:GetOutline()
	self._scroll.CanvasSize = UDim2.fromOffset(0, contentHeight)
	self._empty.Visible = #rows == 0

	local tokens = Theme.Get()
	for _, row in rows do
		table.insert(self._rowObjects, self:_createRow(row, tokens))
	end

	self:_refreshSelection()
end

function ElementTree:_refreshSelection()
	local selected = self._state:GetSelectedKey()
	for _, row in self._rowObjects do
		row.setSelected(row.key == selected)
	end
end

function ElementTree:_createRow(row, tokens)
	local frame = Create("TextButton", {
		Name = row.key,
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, row.offset),
		Size = UDim2.new(1, 0, 0, row.height),
		Parent = self._scroll,
	})

	local inset = BASE_INSET + row.depth * INDENT
	local hovered = false
	local selected = false
	local components = {}

	--------------------------------------------------------------------------
	-- 접기 화살표
	--------------------------------------------------------------------------

	local arrow: TextButton? = nil
	if row.kind ~= "track" then
		local hasChildren = (row.childCount or 0) > 0
		arrow = Create("TextButton", {
			Name = "Arrow",
			-- 폰트에 없는 특수문자는 네모로 깨지므로 ASCII만 쓴다.
			Text = if not hasChildren then "" elseif row.collapsed then ">" else "v",
			Font = Enum.Font.Gotham,
			TextSize = 10,
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(inset, 0),
			Size = UDim2.new(0, 14, 1, 0),
			Parent = frame,
		})
	end

	-- 트랙 행에는 접기 화살표가 없다. 그 자리를 비워두면 글자만 손해다.
	local textLeft = inset + (if row.kind == "track" then 2 else 15)

	--------------------------------------------------------------------------
	-- 본문
	--------------------------------------------------------------------------

	local primary, secondary, typeTag
	if row.kind == "item" then
		primary = Create.label({
			Name = "Name",
			Text = string.format("%d  %s", row.itemId, row.item.name),
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			Position = UDim2.fromOffset(textLeft, 3),
			Size = UDim2.new(1, -(textLeft + ACTION_WIDTH), 0, 14),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = frame,
		})
		secondary = Create.label({
			Name = "Binding",
			Text = "",
			TextSize = 10,
			Position = UDim2.fromOffset(textLeft, 16),
			Size = UDim2.new(1, -(textLeft + ACTION_WIDTH), 0, 12),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = frame,
		})
	elseif row.kind == "element" then
		primary = Create.label({
			Name = "Path",
			Text = row.label or PathSpec.leafName(row.path),
			TextSize = 12,
			Position = UDim2.fromOffset(textLeft, 0),
			Size = UDim2.new(1, -(textLeft + ACTION_WIDTH), 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = frame,
		})
	else
		-- 타입 꼬리표는 글자 길이만큼만 차지한다. 고정 폭으로 두면
		-- "number" 하나에 90px을 잡아먹어서 정작 속성 이름이 잘린다.
		local tagWidth = 0
		local tagText = nil
		if row.track.kind == Schema.TRACK_KIND.PROPERTY then
			tagText = row.track.valueType or "number"
			local bounds = TextService:GetTextSize(tagText, TAG_TEXT_SIZE, Enum.Font.Gotham, TAG_BOUNDS)
			tagWidth = math.min(math.ceil(bounds.X) + TAG_GAP, MAX_TAG_WIDTH)
		end

		primary = Create.label({
			Name = "Target",
			Text = PathSpec.formatTarget(row.track.kind, row.track.target),
			Font = Enum.Font.Code,
			TextSize = 12,
			Position = UDim2.fromOffset(textLeft, 0),
			Size = UDim2.new(1, -(textLeft + ACTION_WIDTH + tagWidth), 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = frame,
		})

		-- 속성 트랙은 어떤 타입으로 잡혔는지 항상 보이게 한다.
		if tagText then
			typeTag = Create.label({
				Name = "ValueType",
				Text = tagText,
				TextSize = TAG_TEXT_SIZE,
				TextXAlignment = Enum.TextXAlignment.Right,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -ACTION_WIDTH, 0, 0),
				Size = UDim2.new(0, tagWidth - TAG_GAP, 1, 0),
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = frame,
			})
		end
	end

	--------------------------------------------------------------------------
	-- 오른쪽 동작
	--------------------------------------------------------------------------

	local actions = Create("Frame", {
		Name = "Actions",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, ACTION_WIDTH, 1, 0),
		Parent = frame,
	}, {
		Create.list(Enum.FillDirection.Horizontal, 0, {
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})

	-- 아이템·엘리먼트는 "하위 추가", 트랙은 "재생헤드 자리에 키프레임 찍기".
	local isTrack = row.kind == "track"
	local addButton = Create("TextButton", {
		Name = "Add",
		Text = if isTrack then "" else "+",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(20, 20),
		LayoutOrder = 1,
		Parent = actions,
	})

	-- 키프레임 표시는 타임라인과 똑같이 마름모를 직접 그린다.
	local addMark = nil
	if isTrack then
		addMark = Create("Frame", {
			Name = "Diamond",
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(7, 7),
			Rotation = 45,
			Parent = addButton,
		}, {
			Create.corner(1),
		})
	end

	local menu = Menu.new({
		Text = "...",
		Overlay = self._overlay,
		LayoutOrder = 2,
		Height = 20,
		PaddingX = 6,
		TextSize = 14,
		Parent = actions,
		GetItems = function()
			return self:_rowMenuItems(row)
		end,
	})
	table.insert(components, menu)

	--------------------------------------------------------------------------
	-- 색칠
	--------------------------------------------------------------------------

	local bindingWarning = false

	local function applyTheme(t)
		local background = t.color.panel
		if selected then
			background = t.color.rowSelected
		elseif hovered then
			background = t.color.rowHover
		end
		frame.BackgroundTransparency = if selected or hovered then 0 else 1
		frame.BackgroundColor3 = background

		if arrow then
			arrow.TextColor3 = t.color.textMuted
		end
		addButton.TextColor3 = t.color.textMuted
		if addMark then
			addMark.BackgroundColor3 = t.color.textMuted
		end

		if row.kind == "item" then
			primary.TextColor3 = t.color.text
			secondary.TextColor3 = if bindingWarning then t.color.danger else t.color.textMuted
		elseif row.kind == "element" then
			primary.TextColor3 = t.color.text
		else
			primary.TextColor3 = if row.track.kind == Schema.TRACK_KIND.METHOD then t.color.accent else t.color.text
			if typeTag then
				typeTag.TextColor3 = t.color.textMuted
			end
		end
	end

	-- 아이템 행은 바인딩 상태를 아래줄에 보여준다.
	local function refreshBinding()
		if row.kind ~= "item" then
			return
		end

		local bound = self:_getBinding(row.itemId)
		if not bound then
			bindingWarning = true
			secondary.Text = Locale.T("tree.noBinding")
			applyTheme(Theme.Get())
			return
		end

		-- 같은 오브젝트를 다른 아이템도 쓰고 있으면 알려준다.
		-- 게임에서는 한 오브젝트를 두 번호에 넘기는 게 문제없지만,
		-- 미리보기에서는 둘이 같은 값을 서로 덮어써서 결과가 뒤엉킨다.
		local shared = self:_itemsSharingBinding(row.itemId, bound)
		if #shared > 0 then
			bindingWarning = true
			secondary.Text = Locale.T("tree.sharedBinding", bound.Name, table.concat(shared, ", "))
		else
			bindingWarning = false
			secondary.Text = "-> " .. bound:GetFullName()
		end
		applyTheme(Theme.Get())
	end

	refreshBinding()
	applyTheme(tokens)

	--------------------------------------------------------------------------
	-- 입력
	--------------------------------------------------------------------------

	local connections = {
		frame.MouseEnter:Connect(function()
			hovered = true
			applyTheme(Theme.Get())
		end),
		frame.MouseLeave:Connect(function()
			hovered = false
			applyTheme(Theme.Get())
		end),
		frame.Activated:Connect(function()
			-- 왼쪽 트리를 눌렀으면 타임라인의 키 선택은 푼다.
			self._state:SelectFrame(nil)
			self._state:Select(row.key)
		end),
	}

	if arrow then
		table.insert(
			connections,
			arrow.Activated:Connect(function()
				if (row.childCount or 0) > 0 then
					self._state:ToggleCollapsed(row.key)
				end
			end)
		)
	end

	table.insert(
		connections,
		addButton.Activated:Connect(function()
			if row.kind == "item" then
				self:_promptAddElement(row.itemId)
			elseif row.kind == "element" then
				self:_openTrackPicker(row.itemId, row.path)
			else
				self:_addKeyAtPlayhead(row)
			end
		end)
	)

	return {
		key = row.key,
		applyTheme = applyTheme,
		setSelected = function(value)
			if selected == value then
				return
			end
			selected = value
			applyTheme(Theme.Get())
		end,
		destroy = function()
			for _, connection in connections do
				connection:Disconnect()
			end
			for _, component in components do
				component:Destroy()
			end
			frame:Destroy()
		end,
	}
end

--------------------------------------------------------------------------------
-- 키프레임
--------------------------------------------------------------------------------

-- 재생헤드 자리에 키를 찍는다. 실제 동작은 EditorState:AddKey에 있고,
-- 타임라인 우클릭 메뉴도 같은 경로를 쓴다.
function ElementTree:_addKeyAtPlayhead(row)
	local state = self._state
	state:AddKey(row.itemId, row.path, row.track, state:SnapTime(state:GetTime()))
end

--------------------------------------------------------------------------------
-- 바인딩
--------------------------------------------------------------------------------

-- 같은 인스턴스에 묶여있는 다른 아이템 번호들.
function ElementTree:_itemsSharingBinding(itemId: number, instance: Instance): { string }
	local shared = {}
	for otherId, otherInstance in Store.GetBindings(self._state:GetSavedName()) do
		if otherId ~= itemId and otherInstance == instance then
			table.insert(shared, tostring(otherId))
		end
	end
	table.sort(shared)
	return shared
end

function ElementTree:_getBinding(itemId: number): Instance?
	local bound = Store.GetBinding(self._state:GetSavedName(), itemId)
	-- 지워진 인스턴스를 가리키고 있을 수 있다.
	if bound and not bound:IsDescendantOf(game) then
		return nil
	end
	return bound
end

function ElementTree:_bindSelection(itemId: number)
	local selected = Selection:Get()
	if #selected ~= 1 then
		self:_notify(Locale.T("tree.bindFailedTitle"), Locale.T("tree.bindFailedMessage"))
		return
	end

	local instance = selected[1]
	Store.SetBinding(self._state:GetSavedName(), itemId, instance)

	-- Motor6D가 들어있으면 리그로 표시한다. 3단계 포즈 캡처가 이 값을 본다.
	local kind = detectItemKind(instance)
	self._project:Commit(Locale.T("undo.setItemClass"), function(doc)
		Ops.setItemKind(doc, itemId, kind)
	end)
	self._state:RebuildOutline()
end

--------------------------------------------------------------------------------
-- 추가 / 편집
--------------------------------------------------------------------------------

function ElementTree:_promptAddItem()
	local selected = Selection:Get()

	-- Explorer에서 하나 고른 상태면 이름과 바인딩을 그대로 가져온다.
	if #selected == 1 then
		local instance = selected[1]
		local doc = self._project:GetDocument()
		local name = instance.Name
		if Ops.isItemNameTaken(doc, name) then
			name = name .. " " .. tostring(doc.nextItemId)
		end

		local newId
		self._project:Commit(Locale.T("undo.addItem"), function(document)
			newId = Ops.addItem(document, name)
			Ops.setItemKind(document, newId, detectItemKind(instance))
		end)
		if newId then
			Store.SetBinding(self._state:GetSavedName(), newId, instance)
			self._state:RebuildOutline()
		end
		return
	end

	Dialog.show(self._overlay, {
		Title = "New Item",
		Message = Locale.T("tree.addItemMessage"),
		Input = { Placeholder = Locale.T("app.namePlaceholder"), Default = "" },
		Confirm = "Add",
		Validate = function(text)
			local name = trim(text)
			if name == "" then
				return false, Locale.T("tree.nameEmpty")
			end
			if Ops.isItemNameTaken(self._project:GetDocument(), name) then
				return false, Locale.T("tree.itemNameTaken", name)
			end
			return true
		end,
		OnConfirm = function(text)
			self._project:Commit(Locale.T("undo.addItem"), function(doc)
				Ops.addItem(doc, trim(text))
			end)
		end,
	})
end

function ElementTree:_promptRenameItem(itemId: number, currentName: string)
	Dialog.show(self._overlay, {
		Title = "Rename Item",
		Input = { Placeholder = Locale.T("app.namePlaceholder"), Default = currentName },
		Confirm = "Rename",
		Validate = function(text)
			local name = trim(text)
			if name == "" then
				return false, Locale.T("tree.nameEmpty")
			end
			if Ops.isItemNameTaken(self._project:GetDocument(), name, itemId) then
				return false, Locale.T("tree.itemNameTaken", name)
			end
			return true
		end,
		OnConfirm = function(text)
			self._project:Commit(Locale.T("undo.renameItem"), function(doc)
				Ops.renameItem(doc, itemId, trim(text))
			end)
		end,
	})
end

function ElementTree:_promptChangeItemId(itemId: number)
	Dialog.show(self._overlay, {
		Title = "Change Item ID",
		Message = Locale.T("tree.idMessage"),
		Input = { Placeholder = Locale.T("tree.idPlaceholder"), Default = tostring(itemId) },
		Confirm = "Save",
		Validate = function(text)
			local value = tonumber(text)
			if not value or value ~= math.floor(value) then
				return false, Locale.T("tree.integerRequired")
			end
			if value < 1 or value > 999 then
				return false, Locale.T("tree.idRange")
			end
			return true
		end,
		OnConfirm = function(text)
			local newId = math.floor(tonumber(text) :: number)
			if newId == itemId then
				return
			end

			-- 커밋하면 문서가 바뀌므로 상대 아이템 여부를 먼저 확인해둔다.
			local swapping = Ops.findItem(self._project:GetDocument(), newId) ~= nil

			self._project:Commit(Locale.T("undo.setItemId"), function(doc)
				Ops.setItemId(doc, itemId, newId)
			end)

			-- 바인딩은 문서 밖(ObjectValue)에 있으니 따로 옮긴다.
			local savedName = self._state:GetSavedName()
			if swapping then
				Store.SwapBindings(savedName, itemId, newId)
			else
				local bound = Store.GetBinding(savedName, itemId)
				Store.SetBinding(savedName, itemId, nil)
				Store.SetBinding(savedName, newId, bound)
			end

			self._state:RebuildOutline()
		end,
	})
end

function ElementTree:_promptAddElement(itemId: number)
	local bound = self:_getBinding(itemId)

	Dialog.show(self._overlay, {
		Title = "Add Element",
		Message = Locale.T("tree.pathMessage"),
		Input = {
			Placeholder = "HumanoidRootPart.RootAttachment.MainParticle",
			Default = "",
		},
		Confirm = "Add",

		-- 바인딩은 임시로 걸어둔 것일 수 있으니 못 찾는다고 막지 않는다.
		-- 지금 바인딩된 오브젝트에 없을 뿐, 실제로 대입될 것에는 있을 수 있다.
		Hint = function(text)
			if not bound then
				return Locale.T("tree.pathNoBinding")
			end
			local _, missing = PathSpec.resolve(bound, PathSpec.normalizePath(text))
			if missing then
				return string.format(Locale.T("tree.pathMissing"), missing)
			end
			return Locale.T("tree.pathFound")
		end,

		Validate = function(text)
			local ok, reason = PathSpec.validatePath(text)
			if not ok then
				return false, reason
			end

			local path = PathSpec.normalizePath(text)
			if Ops.hasElement(self._project:GetDocument(), itemId, path) then
				return false, Locale.T("tree.pathTaken")
			end
			return true
		end,
		OnConfirm = function(text)
			local path = PathSpec.normalizePath(text)
			self:_openTrackPicker(itemId, path)
		end,
	})
end

-- 걸 만한 속성을 창에서 골라 넣는다. 목록에 없는 건 Custom으로 직접 적는다.
function ElementTree:_openTrackPicker(itemId: number, path: string)
	TrackPicker.open(self._overlay, self._state, itemId, path, function()
		self:_promptAddTrack(itemId, path)
	end)
end

-- isNewElement가 참이면 트랙을 취소했을 때 빈 엘리먼트가 남지 않는다.
function ElementTree:_promptAddTrack(itemId: number, path: string, isNewElement: boolean?)
	local bound = self:_getBinding(itemId)
	local resolved = if bound then PathSpec.resolve(bound, path) else nil

	-- (Auto)면 지금 값에서 어느 Enum인지 알아낸다.
	local function resolveEnumType(chosen: string?, target: string): string?
		if chosen and chosen ~= PathSpec.AUTO_ENUM then
			return chosen
		end
		return PathSpec.inferEnumType(resolved, target)
	end

	Dialog.show(self._overlay, {
		Title = if isNewElement then Locale.T("tree.addTrackFirstTitle") else "Add Track",
		Message = Locale.T("tree.addTrackMessage"),
		Input = { Placeholder = Locale.T("tree.targetPlaceholder"), Default = "" },
		Selects = {
			{ Label = Locale.T("tree.valueTypeLabel"), Options = PathSpec.VALUE_TYPES, Default = PathSpec.AUTO_TYPE },
			{
				Label = Locale.T("tree.enumTypeLabel"),
				Options = PathSpec.enumNames(),
				Default = PathSpec.AUTO_ENUM,
				-- Enum이 아닌 타입에는 물어볼 것도 없으니 줄을 아예 숨긴다.
				VisibleWhen = function(values)
					return values[1] == "EnumItem"
				end,
			},
		},
		Confirm = "Add",

		-- 이 창은 속성 목록의 Custom...으로 들어온다. 잘못 눌렀거나 마음이
		-- 바뀌었을 때 목록으로 되돌아갈 길을 남겨둔다.
		Tertiary = {
			Text = "Back",
			OnSelect = function()
				self:_openTrackPicker(itemId, path)
			end,
		},

		-- 지금 바인딩에 없는 속성이어도 막지 않는다. 바인딩은 미리보기용으로
		-- 임시로 걸어둔 것일 수 있고, 실제로 대입될 오브젝트에는 있을 수 있다.
		-- 그래서 확인 결과는 알려만 주고 판단은 사용자에게 맡긴다.
		Hint = function(text, values)
			local valueType = values[1]
			local spec = PathSpec.parseTarget(text)
			if not spec then
				return nil
			end

			-- 지금 바인딩에서 확인되는지부터 본다.
			if resolved then
				local ok, value = pcall(function()
					return (resolved :: any)[spec.target]
				end)
				if not ok then
					return string.format(Locale.T("tree.trackMissing"), resolved.ClassName, spec.target)
				end
				if spec.kind == "method" and typeof(value) ~= "function" then
					return string.format(Locale.T("tree.notMethod"), spec.target)
				end
				if spec.kind == "property" and typeof(value) == "function" then
					return string.format(Locale.T("tree.isMethod"), spec.target)
				end
			end

			if spec.kind == "method" then
				return Locale.T("tree.methodNoType")
			end

			local inferredType = PathSpec.inferValueType(resolved, spec.target)

			if valueType == "EnumItem" or (valueType == PathSpec.AUTO_TYPE and inferredType == "EnumItem") then
				local enumType = resolveEnumType(values[2], spec.target)
				return if enumType then Locale.T("tree.enumHint", enumType) else Locale.T("tree.enumUnknown")
			end

			if valueType ~= PathSpec.AUTO_TYPE then
				if valueType == "Instance" then
					return Locale.T("tree.instanceHint")
				end
				return nil
			end

			if inferredType then
				return Locale.T("tree.inferredHint", inferredType)
			end
			if not resolved then
				return Locale.T("tree.noBindingInfer")
			end
			return Locale.T("tree.cannotInfer")
		end,

		Validate = function(text)
			local spec, reason = PathSpec.parseTarget(text)
			if not spec then
				return false, reason
			end

			if Ops.findTrack(self._project:GetDocument(), itemId, path, spec.target) then
				return false, string.format(Locale.T("tree.trackTaken"), PathSpec.formatTarget(spec.kind, spec.target))
			end
			return true
		end,
		OnConfirm = function(text, values)
			local spec = PathSpec.parseTarget(text)
			if not spec then
				return
			end

			local valueType = nil
			local enumType = nil

			if spec.kind == "property" then
				local chosenType = values[1]
				if chosenType and chosenType ~= PathSpec.AUTO_TYPE then
					valueType = chosenType
				else
					-- (Auto): 바인딩된 인스턴스의 현재 값에서 타입을 읽는다.
					valueType = PathSpec.inferValueType(resolved, spec.target)
				end

				if valueType == "EnumItem" then
					enumType = resolveEnumType(values[2], spec.target)
				end
			end

			self._project:Commit(Locale.T("undo.addTrack"), function(doc)
				Ops.addTrack(doc, itemId, path, spec.kind, spec.target, valueType, enumType)
			end)
		end,
	})
end

function ElementTree:_promptEditPath(itemId: number, currentPath: string)
	Dialog.show(self._overlay, {
		Title = "Edit Element Path",
		Input = { Placeholder = Locale.T("tree.pathPlaceholder"), Default = currentPath },
		Confirm = "Save",
		Validate = function(text)
			local ok, reason = PathSpec.validatePath(text)
			if not ok then
				return false, reason
			end
			local path = PathSpec.normalizePath(text)
			if path ~= currentPath and Ops.hasElement(self._project:GetDocument(), itemId, path) then
				return false, Locale.T("tree.pathTaken")
			end
			return true
		end,
		OnConfirm = function(text)
			self._project:Commit(Locale.T("undo.setPath"), function(doc)
				Ops.setElementPath(doc, itemId, currentPath, PathSpec.normalizePath(text))
			end)
		end,
	})
end

--------------------------------------------------------------------------------
-- 행 메뉴
--------------------------------------------------------------------------------

function ElementTree:_rowMenuItems(row)
	if row.kind == "item" then
		local doc = self._project:GetDocument()
		local isOrigin = doc.originItemId == row.itemId
		local bound = self:_getBinding(row.itemId)

		return {
			{
				Text = "Add Element...",
				OnSelect = function()
					self:_promptAddElement(row.itemId)
				end,
			},
			{
				Text = "Rename...",
				OnSelect = function()
					self:_promptRenameItem(row.itemId, row.item.name)
				end,
			},
			{
				Text = "Change ID...",
				OnSelect = function()
					self:_promptChangeItemId(row.itemId)
				end,
			},
			{ Separator = true },
			{
				Text = "Capture Rig Pose",
				Disabled = not RigResolver.hasRig(bound),
				OnSelect = function()
					local count, reason = self._state:CaptureRigPose(row.itemId)
					if reason then
						self:_notify(Locale.T("tree.poseFailed"), reason)
					else
						self:_notify(Locale.T("tree.poseTitle"), Locale.T("tree.poseMessage", count))
					end
				end,
			},
			{
				Text = "Capture Position",
				Disabled = bound == nil,
				OnSelect = function()
					local ok, reason = self._state:CaptureItemPosition(row.itemId)
					if not ok then
						self:_notify(Locale.T("tree.positionFailed"), reason or "")
					end
				end,
			},
			{ Separator = true },
			{
				Text = "Bind Selected Object",
				OnSelect = function()
					self:_bindSelection(row.itemId)
				end,
			},
			{
				Text = "Select Bound Object",
				Disabled = bound == nil,
				OnSelect = function()
					if bound then
						Selection:Set({ bound })
					end
				end,
			},
			{
				Text = "Clear Binding",
				Disabled = bound == nil,
				OnSelect = function()
					Store.SetBinding(self._state:GetSavedName(), row.itemId, nil)
					self._state:RebuildOutline()
				end,
			},
			{ Separator = true },
			{
				Text = "Set as Origin",
				Checked = isOrigin,
				Disabled = isOrigin,
				OnSelect = function()
					self._project:Commit(Locale.T("undo.setOrigin"), function(doc2)
						Ops.setOriginItem(doc2, row.itemId)
					end)
				end,
			},
			{ Separator = true },
			{
				Text = "Delete Item",
				Variant = "danger",
				OnSelect = function()
					Dialog.confirm(
						self._overlay,
						Locale.T("tree.deleteItemTitle"),
						string.format(Locale.T("tree.deleteItemMessage"), row.item.name),
						"Delete",
						function()
							self._project:Commit(Locale.T("undo.deleteItem"), function(doc2)
								Ops.removeItem(doc2, row.itemId)
							end)
							Store.SetBinding(self._state:GetSavedName(), row.itemId, nil)
						end
					)
				end,
			},
		}
	end

	if row.kind == "element" then
		return {
			{
				Text = "Add Track...",
				OnSelect = function()
					self:_openTrackPicker(row.itemId, row.path)
				end,
			},
			{
				Text = "Edit Path...",
				OnSelect = function()
					self:_promptEditPath(row.itemId, row.path)
				end,
			},
			{
				Text = "Copy Full Path",
				OnSelect = function()
					self:_showPath(row)
				end,
			},
			{ Separator = true },
			{
				Text = "Delete Element",
				Variant = "danger",
				OnSelect = function()
					self._project:Commit(Locale.T("undo.deleteElement"), function(doc)
						Ops.removeElement(doc, row.itemId, row.path)
					end)
				end,
			},
		}
	end

	local items: { any } = {}

	if row.track.kind == Schema.TRACK_KIND.PROPERTY then
		table.insert(items, {
			Text = "Change Value Type...",
			OnSelect = function()
				self:_promptValueType(row)
			end,
		})
		table.insert(items, { Separator = true })
	end

	table.insert(items, {
		Text = "Delete Track",
		Variant = "danger",
		OnSelect = function()
			self._project:Commit(Locale.T("undo.deleteTrack"), function(doc)
				Ops.removeTrack(doc, row.itemId, row.path, row.track.target)
			end)
		end,
	})

	return items
end

function ElementTree:_promptValueType(row)
	local bound = self:_getBinding(row.itemId)
	local resolved = if bound then PathSpec.resolve(bound, row.path) else nil
	local current = row.track.valueType or "number"

	-- (Auto)면 지금 값에서 어느 Enum인지 알아낸다.
	local function resolveEnumType(chosen: string?): string?
		if chosen and chosen ~= PathSpec.AUTO_ENUM then
			return chosen
		end
		return PathSpec.inferEnumType(resolved, row.track.target)
	end

	Dialog.show(self._overlay, {
		Title = "Value Type",
		Message = string.format(Locale.T("tree.valueTypeMessage"), row.track.target),
		Selects = {
			{ Label = Locale.T("tree.valueTypeLabel"), Options = PathSpec.VALUE_TYPES, Default = current },
			{
				Label = Locale.T("tree.enumTypeLabel"),
				Options = PathSpec.enumNames(),
				Default = row.track.enumType or PathSpec.AUTO_ENUM,
				VisibleWhen = function(values)
					return values[1] == "EnumItem"
				end,
			},
		},
		Confirm = "Save",
		Hint = function(_, values)
			local valueType = values[1]
			local inferred = PathSpec.inferValueType(resolved, row.track.target)

			if valueType == "EnumItem" or (valueType == PathSpec.AUTO_TYPE and inferred == "EnumItem") then
				local enumType = resolveEnumType(values[2])
				return if enumType then Locale.T("tree.enumHint", enumType) else Locale.T("tree.enumUnknown")
			end

			if valueType == PathSpec.AUTO_TYPE then
				return if inferred then Locale.T("tree.inferredHint", inferred) else Locale.T("tree.cannotInferShort")
			end
			if valueType == "Instance" then
				return Locale.T("tree.instanceHint")
			end
			return nil
		end,
		OnConfirm = function(_, values)
			local valueType = values[1]
			if valueType == PathSpec.AUTO_TYPE then
				valueType = PathSpec.inferValueType(resolved, row.track.target) or "number"
			end

			local enumType = if valueType == "EnumItem" then resolveEnumType(values[2]) else nil
			if valueType == current and enumType == row.track.enumType then
				return
			end

			-- 타입이 바뀌면 기존 키 값은 해석할 수 없다.
			local keyCount = #row.track.keys
			local function apply()
				self._project:Commit(Locale.T("undo.setValueType"), function(doc)
					Ops.setTrackValueType(doc, row.itemId, row.path, row.track.target, valueType :: string, enumType)
				end)
			end

			if keyCount == 0 then
				apply()
				return
			end

			Dialog.confirm(
				self._overlay,
				Locale.T("tree.keysClearedTitle"),
				string.format(Locale.T("tree.keysClearedMessage"), keyCount),
				"Change",
				apply
			)
		end,
	})
end

-- 클립보드 API가 없으므로 전체 경로를 띄워서 직접 복사하게 한다.
function ElementTree:_showPath(row)
	local bound = self:_getBinding(row.itemId)
	local full = if row.path == "" then Locale.T("common.itemRoot") else row.path
	Dialog.show(self._overlay, {
		Title = "Element Path",
		Message = Locale.T(
			"tree.infoMessage",
			full,
			if bound then bound:GetFullName() else Locale.T("tree.bindingNone")
		),
		Confirm = Locale.T("common.ok"),
		HideCancel = true,
	})
end

function ElementTree:_notify(title: string, message: string)
	Dialog.show(self._overlay, {
		Title = title,
		Message = message,
		Confirm = Locale.T("common.ok"),
		HideCancel = true,
	})
end

function ElementTree:Destroy()
	self:_clearRows()
	Component.Destroy(self)
end

return ElementTree
