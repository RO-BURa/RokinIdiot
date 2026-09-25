--!nonstrict
-- 시작 화면. 마지막으로 하던 작업 목록에서 골라 열거나 새로 만든다.

local Selection = game:GetService("Selection")

local Component = require(script.Parent.Parent.Component)
local Create = require(script.Parent.Parent.Create)
local Theme = require(script.Parent.Parent.Theme)
local Button = require(script.Parent.Parent.Components.Button)
local Dialog = require(script.Parent.Parent.Components.Dialog)

local Store = require(script.Parent.Parent.Parent.Plugin.Store)
local Recents = require(script.Parent.Parent.Parent.Plugin.Recents)
local Lock = require(script.Parent.Parent.Parent.Plugin.Lock)
local PluginEnv = require(script.Parent.Parent.Parent.Plugin.PluginEnv)
local Locale = require(script.Parent.Parent.Parent.Core.Locale)

local HomeScreen = Component.extend()

local ROW_HEIGHT = 44
local HEADER_BOTTOM = 54
local LOCK_BANNER_HEIGHT = 28
local IMPORT_BANNER_HEIGHT = 46
local BANNER_GAP = 8
local FOOTER_HEIGHT = 20

local function timeAgo(timestamp: number): string
	if timestamp <= 0 then
		return Locale.T("home.neverOpened")
	end
	local delta = os.time() - timestamp
	if delta < 60 then
		return Locale.T("home.justNow")
	elseif delta < 3600 then
		return Locale.T("home.minutesAgo", delta // 60)
	elseif delta < 86400 then
		return Locale.T("home.hoursAgo", delta // 3600)
	elseif delta < 86400 * 30 then
		return Locale.T("home.daysAgo", delta // 86400)
	end
	return os.date("%Y-%m-%d", timestamp)
end

function HomeScreen.new(props)
	local self = Component.construct(HomeScreen)

	self._app = props.App
	self._overlay = props.App:GetOverlay()
	self._rowButtons = {}

	local root = Create("Frame", {
		Name = "HomeScreen",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = props.Parent,
	}, {
		Create.padding(18, 20),
	})
	self.Instance = root

	--------------------------------------------------------------------------
	-- 머리말
	--------------------------------------------------------------------------

	self._title = Create.label({
		Name = "Title",
		Text = "RokinIdiot",
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		Size = UDim2.new(1, -140, 0, 24),
		Parent = root,
	})

	self._subtitle = Create.label({
		Name = "Subtitle",
		Text = Locale.T("home.subtitle"),
		TextSize = 12,
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, -140, 0, 16),
		Parent = root,
	})

	self._newButton = Button.new({
		Text = "+  New Animation",
		Variant = "primary",
		Size = UDim2.new(0, 0, 0, 30),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 6),
		OnClick = function()
			self._app:NewProject()
		end,
		Parent = root,
	})
	self:Track(self._newButton)

	--------------------------------------------------------------------------
	-- 잠금 안내
	--------------------------------------------------------------------------

	self._lockBanner = Create("Frame", {
		Name = "LockBanner",
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, HEADER_BOTTOM),
		Size = UDim2.new(1, 0, 0, LOCK_BANNER_HEIGHT),
		Visible = false,
		Parent = root,
	}, {
		Create.corner(4),
		Create.padding(0, 10),
	})

	self._lockBannerLabel = Create.label({
		Name = "Message",
		Text = "",
		TextSize = 12,
		Size = UDim2.fromScale(1, 1),
		Parent = self._lockBanner,
	})

	--------------------------------------------------------------------------
	-- 가져오기 안내
	--
	-- 다른 플레이스에서 Export한 작업을 Explorer에서 고르면 여기로 들여올 수 있다.
	--------------------------------------------------------------------------

	self._importBanner = Create("Frame", {
		Name = "ImportBanner",
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, HEADER_BOTTOM),
		Size = UDim2.new(1, 0, 0, IMPORT_BANNER_HEIGHT),
		Visible = false,
		Parent = root,
	}, {
		Create.corner(4),
		Create.padding(0, 10),
	})

	self._importStroke = Create.stroke(Color3.new())
	self._importStroke.Parent = self._importBanner

	self._importTitle = Create.label({
		Name = "Title",
		Text = Locale.T("home.foreignSelection"),
		TextSize = 11,
		Position = UDim2.fromOffset(0, 7),
		Size = UDim2.new(1, -110, 0, 14),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = self._importBanner,
	})

	self._importName = Create.label({
		Name = "Name",
		Text = "",
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		Position = UDim2.fromOffset(0, 23),
		Size = UDim2.new(1, -110, 0, 16),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = self._importBanner,
	})

	self._importButton = Button.new({
		Text = Locale.T("home.saveSelection"),
		Variant = "primary",
		TextSize = 11,
		Size = UDim2.new(0, 0, 0, 24),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		OnClick = function()
			self:_importSelected()
		end,
		Parent = self._importBanner,
	})
	self:Track(self._importButton)

	--------------------------------------------------------------------------
	-- 목록
	--------------------------------------------------------------------------

	self._listTitle = Create.label({
		Name = "ListTitle",
		Text = Locale.T("home.recentTitle"),
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		Position = UDim2.fromOffset(0, 90),
		Size = UDim2.new(1, 0, 0, 18),
		Parent = root,
	})

	self._list = Create("ScrollingFrame", {
		Name = "List",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 114),
		Size = UDim2.new(1, 0, 1, -114),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = root,
	}, {
		Create.list(Enum.FillDirection.Vertical, 4),
		Create.padding(0, 8, 8, 0),
	})

	self._empty = Create.label({
		Name = "Empty",
		Text = Locale.T("home.empty"),
		TextSize = 12,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(0, 124),
		Size = UDim2.new(1, 0, 0, 40),
		Visible = false,
		Parent = root,
	})

	--------------------------------------------------------------------------
	-- 바닥
	--------------------------------------------------------------------------

	self._author = Create.label({
		Name = "Author",
		Text = PluginEnv.AUTHOR,
		TextSize = 11,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(0.5, 0, 0, FOOTER_HEIGHT),
		Parent = root,
	})

	self._version = Create.label({
		Name = "Version",
		Text = "v" .. PluginEnv.VERSION,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.new(0.5, 0, 0, FOOTER_HEIGHT),
		Parent = root,
	})

	-- 언어를 바꿔도 이미 만들어둔 글자는 그대로 남으므로 여기서 다시 넣는다.
	local built = false
	self:BindLocale(function()
		self._subtitle.Text = Locale.T("home.subtitle")
		self._importTitle.Text = Locale.T("home.foreignSelection")
		self._importButton:SetText(Locale.T("home.saveSelection"))
		self._listTitle.Text = Locale.T("home.recentTitle")
		self._empty.Text = Locale.T("home.empty")
		-- 목록 행은 만들 때 글자를 넣으니 다시 그려야 바뀐다.
		-- 첫 호출은 아직 화면이 다 서기 전이라 건너뛴다.
		if built then
			self:Refresh()
		end
		built = true
	end)

	self:BindTheme(function(tokens)
		self:_applyTheme(tokens)
	end)

	-- Explorer에서 다른 걸 고르면 가져오기 안내가 바로 따라온다.
	self:Track(Selection.SelectionChanged:Connect(function()
		self:_refreshImport()
	end))

	self:Refresh()
	return self
end

function HomeScreen:_applyTheme(tokens)
	self._title.TextColor3 = tokens.color.text
	self._subtitle.TextColor3 = tokens.color.textMuted
	self._listTitle.TextColor3 = tokens.color.textMuted
	self._empty.TextColor3 = tokens.color.textMuted
	self._list.ScrollBarImageColor3 = tokens.color.border

	self._lockBanner.BackgroundColor3 = tokens.color.panelAlt
	self._lockBannerLabel.TextColor3 = tokens.color.danger

	self._importBanner.BackgroundColor3 = tokens.color.panelAlt
	self._importStroke.Color = tokens.color.accent
	self._importTitle.TextColor3 = tokens.color.textMuted
	self._importName.TextColor3 = tokens.color.text

	self._author.TextColor3 = tokens.color.textMuted
	self._version.TextColor3 = tokens.color.textMuted

	for _, row in self._rowButtons do
		row.applyTheme(tokens)
	end
end

--------------------------------------------------------------------------------
-- 가져오기
--------------------------------------------------------------------------------

-- Explorer에서 고른 게 우리 형식이고 저장 폴더 밖에 있으면 안내를 띄운다.
function HomeScreen:_refreshImport()
	self._importSource = nil
	self._importDocument = nil

	local selected = Selection:Get()
	if #selected == 1 then
		local instance = selected[1]
		if not Store.IsInSaves(instance) then
			local ok, doc = Store.Probe(instance)
			if ok and doc then
				self._importSource = instance
				self._importDocument = doc
			end
		end
	end

	if self._importDocument then
		self._importBanner.Visible = true
		self._importName.Text = self._importDocument.name
	else
		self._importBanner.Visible = false
	end

	self:_layout()
end

function HomeScreen:_importSelected()
	local source = self._importSource
	local doc = self._importDocument
	if not source or not doc then
		return
	end

	-- 이름이 비어있으면 바로 저장하고, 겹치면 다른 이름을 물어본다.
	if not Store.Exists(doc.name) then
		self:_saveImport(source, doc, doc.name)
		return
	end

	Dialog.show(self._overlay, {
		Title = "Import Animation",
		Message = Locale.T("home.importRenamed", doc.name),
		Input = { Placeholder = Locale.T("app.namePlaceholder"), Default = doc.name .. " (2)" },
		Confirm = "Save",
		Validate = function(text)
			local name = text:match("^%s*(.-)%s*$") or ""
			local valid, reason = Store.IsValidName(name)
			if not valid then
				return false, reason
			end
			if Store.Exists(name) then
				return false, Locale.T("app.nameTaken", name)
			end
			return true
		end,
		OnConfirm = function(text)
			self:_saveImport(source, doc, text:match("^%s*(.-)%s*$") or "")
		end,
	})
end

function HomeScreen:_saveImport(source: Instance, doc, name: string)
	local ok, err = pcall(Store.ImportFrom, source, doc, name)
	if not ok then
		Dialog.show(self._overlay, {
			Title = Locale.T("home.importFailed"),
			Message = tostring(err):gsub("^.-%[RokinIdiot%]%s*", ""),
			Confirm = Locale.T("common.ok"),
			HideCancel = true,
		})
		return
	end

	Recents.Touch(name)
	self:Refresh()
end

--------------------------------------------------------------------------------
-- 배치
--
-- 안내 띠가 보이는지에 따라 아래 것들이 밀린다.
--------------------------------------------------------------------------------

function HomeScreen:_layout()
	local y = HEADER_BOTTOM

	if self._lockBanner.Visible then
		self._lockBanner.Position = UDim2.fromOffset(0, y)
		y += LOCK_BANNER_HEIGHT + BANNER_GAP
	end

	if self._importBanner.Visible then
		self._importBanner.Position = UDim2.fromOffset(0, y)
		y += IMPORT_BANNER_HEIGHT + BANNER_GAP
	end

	self._listTitle.Position = UDim2.fromOffset(0, y)
	y += 24

	-- 바닥의 만든이/버전 줄만큼 목록을 줄인다.
	self._list.Position = UDim2.fromOffset(0, y)
	self._list.Size = UDim2.new(1, 0, 1, -(y + FOOTER_HEIGHT))
	self._empty.Position = UDim2.fromOffset(0, y + 4)
end

function HomeScreen:Refresh()
	for _, row in self._rowButtons do
		row.destroy()
	end
	table.clear(self._rowButtons)

	-- 다른 사람이 편집 중이면 목록 위에 알려준다.
	local blocker = Lock.GetBlocker()
	if blocker then
		self._lockBanner.Visible = true
		self._lockBannerLabel.Text = Locale.T("home.lockedBy", Lock.DescribeHolder(blocker))
	else
		self._lockBanner.Visible = false
	end

	-- 가져올 게 선택되어 있는지 확인하고, 그 결과에 맞춰 아래를 다시 배치한다.
	self:_refreshImport()

	-- 최근 목록을 먼저, 나머지 저장된 작업을 그 뒤에.
	local saved = Store.List()
	local savedLookup = {}
	for _, name in saved do
		savedLookup[name] = true
	end

	local ordered: { { name: string, openedAt: number } } = {}
	local seen = {}

	for _, entry in Recents.GetForThisPlace() do
		if savedLookup[entry.name] and not seen[entry.name] then
			seen[entry.name] = true
			table.insert(ordered, { name = entry.name, openedAt = entry.openedAt })
		end
	end
	for _, name in saved do
		if not seen[name] then
			table.insert(ordered, { name = name, openedAt = 0 })
		end
	end

	self._empty.Visible = #ordered == 0
	self._list.Visible = #ordered > 0

	local tokens = Theme.Get()
	for index, entry in ordered do
		table.insert(self._rowButtons, self:_createRow(entry, index, tokens))
	end
end

function HomeScreen:_createRow(entry, order: number, tokens)
	local row = Create("TextButton", {
		Name = entry.name,
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		LayoutOrder = order,
		Parent = self._list,
	}, {
		Create.corner(5),
		Create.padding(0, 10),
	})

	local stroke = Create.stroke(tokens.color.border)
	stroke.Parent = row

	local nameLabel = Create.label({
		Name = "Name",
		Text = entry.name,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		Position = UDim2.fromOffset(0, 7),
		Size = UDim2.new(1, -80, 0, 16),
		Parent = row,
	})

	local metaLabel = Create.label({
		Name = "Meta",
		Text = timeAgo(entry.openedAt),
		TextSize = 11,
		Position = UDim2.fromOffset(0, 23),
		Size = UDim2.new(1, -80, 0, 14),
		Parent = row,
	})

	local deleteButton = Create("TextButton", {
		Name = "Delete",
		Text = Locale.T("common.delete"),
		Font = Enum.Font.Gotham,
		TextSize = 11,
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(36, 22),
		Parent = row,
	})

	local function applyTheme(t)
		row.BackgroundColor3 = t.color.panel
		stroke.Color = t.color.border
		nameLabel.TextColor3 = t.color.text
		metaLabel.TextColor3 = t.color.textMuted
		deleteButton.TextColor3 = t.color.textMuted
	end
	applyTheme(tokens)

	-- 삭제 버튼은 항상 띄워둔다. 호버로 보였다 숨겼다 하면 커서가 그 위로 갈 때
	-- 행의 MouseLeave가 먼저 걸려서 깜빡이는 문제가 생긴다.
	local connections = {
		row.MouseEnter:Connect(function()
			row.BackgroundColor3 = Theme.Get().color.rowHover
		end),
		row.MouseLeave:Connect(function()
			row.BackgroundColor3 = Theme.Get().color.panel
		end),
		row.Activated:Connect(function()
			self._app:OpenProject(entry.name)
		end),
		deleteButton.MouseEnter:Connect(function()
			deleteButton.TextColor3 = Theme.Get().color.danger
		end),
		deleteButton.MouseLeave:Connect(function()
			deleteButton.TextColor3 = Theme.Get().color.textMuted
		end),
		deleteButton.Activated:Connect(function()
			self._app:DeleteProject(entry.name, function()
				self:Refresh()
			end)
		end),
	}

	return {
		applyTheme = applyTheme,
		destroy = function()
			for _, connection in connections do
				connection:Disconnect()
			end
			row:Destroy()
		end,
	}
end

function HomeScreen:Destroy()
	for _, row in self._rowButtons do
		row.destroy()
	end
	table.clear(self._rowButtons)
	Component.Destroy(self)
end

return HomeScreen
