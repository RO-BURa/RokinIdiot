--!nonstrict
-- 탑바용 드롭다운 메뉴.
-- 팝업은 오버레이 레이어에 그려서 다른 UI 위에 확실히 뜨게 한다.

local TextService = game:GetService("TextService")

local Component = require(script.Parent.Parent.Component)
local Create = require(script.Parent.Parent.Create)
local Drag = require(script.Parent.Parent.Drag)
local Theme = require(script.Parent.Parent.Theme)
local PluginEnv = require(script.Parent.Parent.Parent.Plugin.PluginEnv)

local Menu = Component.extend()

-- 살아있는 모든 메뉴. 열린 메뉴 바깥을 눌렀을 때 그 자리에 다른 메뉴 버튼이
-- 있으면 한 번의 클릭으로 바로 넘어가기 위해 필요하다.
local liveMenus: { any } = {}

local ITEM_HEIGHT = 20
local SEPARATOR_HEIGHT = 5
local PANEL_PADDING_Y = 3
local ITEM_TEXT_SIZE = 13
local ITEM_FONT = Enum.Font.Gotham

-- 체크 표시가 하나라도 있을 때만 왼쪽에 자리를 낸다.
local CHECK_COLUMN = 16
local TEXT_INSET = 8
local TEXT_TAIL = 10

local MIN_WIDTH = 110
local MAX_WIDTH = 340

-- 화면보다 길어질 때 붙는 위/아래 이동 버튼의 높이와, 창 가장자리 여백.
local ARROW_HEIGHT = 16
local SCREEN_MARGIN = 6

-- 목록이 보이는 창의 이 배수 이상으로 길면 한 칸씩 움직인다.
-- 살짝 넘치는 정도면 한 번에 끝으로 가는 게 빠르고, 훨씬 길면 조금씩 봐야 한다.
local STEP_MODE_RATIO = 1.7
local ARROW_HOLD_DELAY = 0.35 -- 누르고 있을 때 반복이 시작되기까지
local ARROW_HOLD_INTERVAL = 0.05

export type Item = {
	Text: string?,
	Separator: boolean?,
	Checked: boolean?,
	Disabled: boolean?,
	Variant: string?, -- "danger"
	OnSelect: (() -> ())?,
}

export type Props = {
	Text: string,
	Overlay: Instance,
	Parent: Instance?,
	LayoutOrder: number?,
	Height: number?, -- 없으면 부모 높이를 채운다 (탑바용)
	PaddingX: number?,
	TextSize: number?,
	ZIndex: number?, -- 모달 위에 띄워야 하면 올린다
	-- 열 때마다 호출된다. 체크 표시나 비활성 상태를 그때그때 계산할 수 있다.
	GetItems: () -> { Item },
}

function Menu.new(props: Props)
	local self = Component.construct(Menu)

	self._overlay = props.Overlay
	self._getItems = props.GetItems
	self._zIndex = props.ZIndex or 50
	self._open = false
	self._hovered = false

	table.insert(liveMenus, self)
	self:Track(function()
		local index = table.find(liveMenus, self)
		if index then
			table.remove(liveMenus, index)
		end
	end)

	local trigger = Create("TextButton", {
		Name = "MenuTrigger",
		Text = props.Text,
		Font = Enum.Font.GothamMedium,
		TextSize = props.TextSize or 13,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Size = if props.Height then UDim2.fromOffset(0, props.Height) else UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = props.LayoutOrder or 0,
	}, {
		Create.corner(4),
		Create.padding(0, props.PaddingX or 10),
	})

	self.Instance = trigger

	self:BindTheme(function()
		self:_refreshTrigger()
	end)

	self:Track(trigger.MouseEnter:Connect(function()
		self._hovered = true
		self:_refreshTrigger()
	end))
	self:Track(trigger.MouseLeave:Connect(function()
		self._hovered = false
		self:_refreshTrigger()
	end))
	self:Track(trigger.Activated:Connect(function()
		if self._open then
			self:Close()
		else
			self:Open()
		end
	end))

	-- 컴포넌트가 사라질 때 열려있던 팝업도 같이 치운다.
	self:Track(function()
		self:Close()
	end)

	if props.Parent then
		trigger.Parent = props.Parent
	end

	return self
end

-- 커서 아래에 있는 다른 메뉴의 트리거를 찾는다.
-- 팝업 뒤에 깔린 투명 버튼이 클릭을 먹기 때문에, 그 클릭이 원래 어느
-- 버튼으로 갈 예정이었는지 좌표로 직접 알아내야 한다.
function Menu:_menuUnderCursor()
	local mouse = PluginEnv.GetMousePosition()
	if not mouse then
		return nil
	end

	for _, menu in liveMenus do
		local trigger = menu.Instance
		if trigger and trigger.Parent and trigger.Visible then
			local position = trigger.AbsolutePosition
			local size = trigger.AbsoluteSize
			if
				mouse.X >= position.X
				and mouse.X <= position.X + size.X
				and mouse.Y >= position.Y
				and mouse.Y <= position.Y + size.Y
			then
				return menu
			end
		end
	end
	return nil
end

function Menu:_refreshTrigger()
	local tokens = Theme.Get()
	local trigger = self.Instance
	trigger.TextColor3 = tokens.color.text
	if self._open then
		trigger.BackgroundTransparency = 0
		trigger.BackgroundColor3 = tokens.color.buttonPressed
	elseif self._hovered then
		trigger.BackgroundTransparency = 0
		trigger.BackgroundColor3 = tokens.color.buttonHover
	else
		trigger.BackgroundTransparency = 1
	end
end

function Menu:SetText(text: string)
	self.Instance.Text = text
end

function Menu:Close()
	if not self._open then
		return
	end
	self._open = false
	if self._popup then
		self._popup:Destroy()
		self._popup = nil
	end
	self:_refreshTrigger()
end

-- 항목 목록에서 팝업 크기를 잰다.
local function measure(items)
	-- 체크 표시가 하나도 없으면 왼쪽 여백을 아예 없앤다.
	local hasCheck = false
	for _, item in items do
		if item.Checked then
			hasCheck = true
			break
		end
	end
	local textLeft = TEXT_INSET + (if hasCheck then CHECK_COLUMN else 0)

	-- 가장 긴 항목에 맞춰 폭을 잡는다. 고정 폭으로 두면 짧은 메뉴가 휑해진다.
	-- 돌려주는 높이는 항목만의 높이다. 판 여백은 부르는 쪽에서 더한다.
	local contentHeight = 0
	local widest = 0
	for _, item in items do
		if item.Separator then
			contentHeight += SEPARATOR_HEIGHT
		else
			contentHeight += ITEM_HEIGHT
			local bounds =
				TextService:GetTextSize(item.Text or "", ITEM_TEXT_SIZE, ITEM_FONT, Vector2.new(MAX_WIDTH, 100))
			widest = math.max(widest, bounds.X)
		end
	end

	local width = math.clamp(math.ceil(widest) + textLeft + TEXT_TAIL, MIN_WIDTH, MAX_WIDTH)
	return width, contentHeight, textLeft
end

-- anchor는 오버레이 기준 사각형. 버튼 메뉴는 버튼 자리, 우클릭 메뉴는 커서 자리.
local function place(overlay: Instance, anchor, width: number, height: number)
	local originX = anchor.x
	local gap = if anchor.height > 0 then 2 else 0
	local originY = anchor.y + anchor.height + gap

	-- 아래로 넘치면 위로 펼치고, 위에도 자리가 없으면 화면 안으로 밀어 올린다.
	-- 어느 쪽이든 항목이 잘려서 안 보이는 일은 없어야 한다.
	local overlayHeight = overlay.AbsoluteSize.Y
	if originY + height > overlayHeight then
		local above = anchor.y - height - gap
		originY = if above >= SCREEN_MARGIN then above else overlayHeight - height - SCREEN_MARGIN
	end
	originY = math.max(originY, SCREEN_MARGIN)

	-- 오른쪽으로 넘치면 왼쪽으로 편다.
	local overlayWidth = overlay.AbsoluteSize.X
	if originX + width > overlayWidth then
		originX = math.max(overlayWidth - width, 0)
	end

	return originX, math.max(originY, 0)
end

-- 항목이 화면보다 많을 때 붙는 위/아래 이동 버튼.
-- 스크롤 막대는 숨기고 휠과 이 버튼으로만 옮긴다.
--
-- stepped가 참이면 한 칸씩 (누르고 있으면 계속), 거짓이면 한 번에 끝으로.
local function addScrollArrow(
	panel: Instance,
	overlay: Instance,
	scroll: ScrollingFrame,
	tokens,
	base: number,
	toTop: boolean,
	stepped: boolean
)
	local button = Create("TextButton", {
		Name = if toTop then "ScrollTop" else "ScrollBottom",
		Text = if toTop then "^" else "v",
		Font = ITEM_FONT,
		TextSize = 11,
		TextColor3 = tokens.color.textMuted,
		AutoButtonColor = false,
		BackgroundColor3 = tokens.color.panelAlt,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, if toTop then 0 else 1),
		Position = UDim2.fromScale(0, if toTop then 0 else 1),
		Size = UDim2.new(1, 0, 0, ARROW_HEIGHT),
		ZIndex = base + 3,
		Parent = panel,
	})

	-- 더 갈 곳이 없으면 흐리게. 목록 어디쯤인지 감이 온다.
	local function refresh()
		local atEnd
		if toTop then
			atEnd = scroll.CanvasPosition.Y <= 1
		else
			local maxScroll = math.max(scroll.CanvasSize.Y.Offset - scroll.AbsoluteWindowSize.Y, 0)
			atEnd = scroll.CanvasPosition.Y >= maxScroll - 1
		end
		button.TextTransparency = if atEnd then 0.6 else 0
	end
	refresh()

	if stepped then
		local widget = PluginEnv.GetWidget()
		local stopHold: (() -> ())? = nil

		local function step()
			local delta = if toTop then -ITEM_HEIGHT else ITEM_HEIGHT
			scroll.CanvasPosition = Vector2.new(0, scroll.CanvasPosition.Y + delta)
		end

		button.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end
			step()

			-- 누르고 있으면 계속 넘긴다. 한 칸씩만 되면 긴 목록에서 지친다.
			if not widget or stopHold then
				return
			end

			local pressedAt = os.clock()
			local lastStepAt = pressedAt
			stopHold = Drag.begin(widget, overlay, function()
				local now = os.clock()
				if now - pressedAt < ARROW_HOLD_DELAY or now - lastStepAt < ARROW_HOLD_INTERVAL then
					return
				end
				lastStepAt = now
				step()
			end, function()
				stopHold = nil
			end)
		end)

		-- 누른 채로 팝업이 사라지면 반복이 남는다.
		button.Destroying:Connect(function()
			if stopHold then
				stopHold()
				stopHold = nil
			end
		end)
	else
		button.Activated:Connect(function()
			scroll.CanvasPosition = Vector2.new(0, if toTop then 0 else scroll.CanvasSize.Y.Offset)
		end)
	end

	button.MouseEnter:Connect(function()
		button.BackgroundColor3 = tokens.color.rowHover
	end)
	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = tokens.color.panelAlt
	end)
	scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(refresh)

	return button
end

-- 팝업 하나를 만든다. onCatcher는 바깥을 눌렀을 때 부른다.
local function buildPopup(overlay: Instance, items, anchor, base: number, onCatcher: () -> (), onClose: () -> ())
	local tokens = Theme.Get()
	local width, contentHeight, textLeft = measure(items)

	-- 화면보다 길면 잘라내지 않고 스크롤로 넘긴다.
	local naturalHeight = contentHeight + PANEL_PADDING_Y * 2
	local maxHeight = math.max(overlay.AbsoluteSize.Y - SCREEN_MARGIN * 2, ARROW_HEIGHT * 2 + ITEM_HEIGHT)
	local scrolling = naturalHeight > maxHeight
	local panelHeight = if scrolling then maxHeight else naturalHeight

	local originX, originY = place(overlay, anchor, width, panelHeight)

	-- 바깥을 누르면 닫히도록 뒤에 투명 버튼을 깐다.
	local root = Create("Frame", {
		Name = "MenuPopup",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = base,
	}, {
		Create("TextButton", {
			Name = "Catcher",
			Text = "",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = base,
		}),
	})

	-- 항목 사이 여백을 눌렀다고 메뉴가 닫히면 안 된다.
	-- Frame은 클릭을 삼키지 못해서 밑의 캐처로 통과하므로 버튼으로 만든다.
	local panel = Create("TextButton", {
		Name = "Items",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = tokens.color.panel,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(originX, originY),
		Size = UDim2.fromOffset(width, panelHeight),
		ZIndex = base + 1,
	}, {
		Create.corner(5),
		Create.stroke(tokens.color.border),
	})

	-- 항목이 들어갈 자리. 넘칠 때만 ScrollingFrame이 된다.
	local holder
	if scrolling then
		holder = Create("ScrollingFrame", {
			Name = "Scroll",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, ARROW_HEIGHT),
			Size = UDim2.new(1, 0, 1, -ARROW_HEIGHT * 2),
			CanvasSize = UDim2.fromOffset(0, contentHeight),
			-- 막대는 숨기고 휠과 위/아래 버튼으로만 움직인다.
			ScrollBarThickness = 0,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ClipsDescendants = true,
			ZIndex = base + 1,
			Parent = panel,
		}, {
			Create.list(Enum.FillDirection.Vertical, 0),
		})

		-- 창보다 훨씬 길면 한 칸씩, 살짝 넘치는 정도면 한 번에 끝으로.
		local windowHeight = math.max(panelHeight - ARROW_HEIGHT * 2, 1)
		local stepped = contentHeight >= windowHeight * STEP_MODE_RATIO

		addScrollArrow(panel, overlay, holder, tokens, base, true, stepped)
		addScrollArrow(panel, overlay, holder, tokens, base, false, stepped)
	else
		holder = Create("Frame", {
			Name = "Holder",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, PANEL_PADDING_Y),
			Size = UDim2.new(1, 0, 1, -PANEL_PADDING_Y * 2),
			ZIndex = base + 1,
			Parent = panel,
		}, {
			Create.list(Enum.FillDirection.Vertical, 0),
		})
	end

	local order = 0
	for _, item in items do
		order += 1
		if item.Separator then
			Create("Frame", {
				Name = "SeparatorSlot",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, SEPARATOR_HEIGHT),
				LayoutOrder = order,
				ZIndex = base + 1,
				Parent = holder,
			}, {
				Create("Frame", {
					Name = "Line",
					BackgroundColor3 = tokens.color.divider,
					BorderSizePixel = 0,
					Size = UDim2.new(1, -12, 0, 1),
					Position = UDim2.new(0, 6, 0.5, 0),
					ZIndex = base + 1,
				}),
			})
		else
			Menu._createItem(holder, item, order, tokens, textLeft, base, onClose)
		end
	end

	panel.Parent = root
	root.Parent = overlay

	root.Catcher.Activated:Connect(onCatcher)

	return root
end

function Menu:Open()
	self:Close()

	local items = self._getItems()
	if #items == 0 then
		return
	end

	local trigger = self.Instance
	local anchor = {
		x = trigger.AbsolutePosition.X - self._overlay.AbsolutePosition.X,
		y = trigger.AbsolutePosition.Y - self._overlay.AbsolutePosition.Y,
		height = trigger.AbsoluteSize.Y,
	}

	self._popup = buildPopup(self._overlay, items, anchor, self._zIndex, function()
		local target = self:_menuUnderCursor()
		self:Close()

		-- 다른 메뉴 버튼 위를 눌렀다면 그 메뉴가 바로 열려야 한다.
		-- (자기 자신이면 방금 닫은 게 맞으므로 다시 열지 않는다)
		if target and target ~= self then
			target:Open()
		end
	end, function()
		self:Close()
	end)

	self._open = true
	self:_refreshTrigger()
end

--------------------------------------------------------------------------------
-- 우클릭 메뉴
--
-- 트리거 버튼 없이 커서 자리에 뜬다. 고르거나 바깥을 누르면 사라진다.
--------------------------------------------------------------------------------

local contextPopup: Instance? = nil

function Menu.closeContext()
	if contextPopup then
		contextPopup:Destroy()
		contextPopup = nil
	end
end

function Menu.openContext(overlay: Instance, items, zIndex: number?)
	Menu.closeContext()

	if #items == 0 then
		return
	end

	local mouse = PluginEnv.GetMousePosition()
	if not mouse then
		return
	end

	local anchor = {
		x = mouse.X - overlay.AbsolutePosition.X,
		y = mouse.Y - overlay.AbsolutePosition.Y,
		height = 0,
	}

	contextPopup = buildPopup(overlay, items, anchor, zIndex or 60, Menu.closeContext, Menu.closeContext)
end

function Menu._createItem(panel: Instance, item, order: number, tokens, textLeft: number, base: number, onClose)
	local disabled = item.Disabled == true
	local textColor = if disabled
		then tokens.color.textMuted
		elseif item.Variant == "danger" then tokens.color.danger
		else tokens.color.text

	local button = Create("TextButton", {
		Name = "Item",
		Text = "",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, ITEM_HEIGHT),
		LayoutOrder = order,
		AutoButtonColor = false,
		ZIndex = base + 1,
		Parent = panel,
	}, {
		Create.label({
			Name = "Label",
			Text = item.Text or "",
			TextColor3 = textColor,
			TextSize = ITEM_TEXT_SIZE,
			Font = ITEM_FONT,
			Size = UDim2.new(1, -(textLeft + TEXT_TAIL), 1, 0),
			Position = UDim2.fromOffset(textLeft, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = base + 2,
		}),
	})

	-- 체크 표시는 글자가 아니라 점으로 그린다.
	-- 폰트에 없는 특수문자는 네모(▯)로 깨져서 나온다.
	if item.Checked then
		Create("Frame", {
			Name = "Check",
			BackgroundColor3 = tokens.color.accent,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, TEXT_INSET + 3, 0.5, 0),
			Size = UDim2.fromOffset(6, 6),
			ZIndex = base + 2,
			Parent = button,
		}, {
			Create.corner(3),
		})
	end

	if disabled then
		return
	end

	button.MouseEnter:Connect(function()
		button.BackgroundTransparency = 0
		button.BackgroundColor3 = tokens.color.rowHover
	end)
	button.MouseLeave:Connect(function()
		button.BackgroundTransparency = 1
	end)
	button.Activated:Connect(function()
		onClose()
		if item.OnSelect then
			item.OnSelect()
		end
	end)
end

return Menu
