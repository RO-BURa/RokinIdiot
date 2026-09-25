--!nonstrict
-- 에디터 상단 바:  [Menu] [Language] [Theme] [Options]     작업이름 *     [Save] [Close]

local Selection = game:GetService("Selection")

local Component = require(script.Parent.Parent.Component)
local Create = require(script.Parent.Parent.Create)
local Theme = require(script.Parent.Parent.Theme)
local Locale = require(script.Parent.Parent.Parent.Core.Locale)
local Button = require(script.Parent.Parent.Components.Button)
local Menu = require(script.Parent.Parent.Components.Menu)

local Debug = require(script.Parent.Parent.Parent.Core.Debug)
local Reflection = require(script.Parent.Parent.Parent.Core.Reflection)
local Player = require(script.Parent.Parent.Parent.Preview.Player)
local ViewOptions = require(script.Parent.ViewOptions)

local TopBar = Component.extend()

TopBar.HEIGHT = 34

function TopBar.new(props)
	local self = Component.construct(TopBar)

	self._app = props.App
	self._project = props.Project

	local root = Create("Frame", {
		Name = "TopBar",
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, TopBar.HEIGHT),
		Parent = props.Parent,
	})
	self.Instance = root

	self._divider = Create("Frame", {
		Name = "Divider",
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
		Parent = root,
	})

	--------------------------------------------------------------------------
	-- 왼쪽 메뉴들
	--------------------------------------------------------------------------

	local left = Create("Frame", {
		Name = "Left",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 300, 1, 0),
		Parent = root,
	}, {
		Create.list(Enum.FillDirection.Horizontal, 2, {
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		Create.padding(4, 6),
	})

	self._menu = Menu.new({
		Text = Locale.T("topbar.menu"),
		Overlay = props.Overlay,
		LayoutOrder = 1,
		Parent = left,
		GetItems = function()
			return self:_menuItems()
		end,
	})
	self:Track(self._menu)

	self._languageMenu = Menu.new({
		Text = Locale.T("topbar.language"),
		Overlay = props.Overlay,
		LayoutOrder = 2,
		Parent = left,
		GetItems = function()
			return self:_languageItems()
		end,
	})
	self:Track(self._languageMenu)

	self._themeMenu = Menu.new({
		Text = Locale.T("topbar.theme"),
		Overlay = props.Overlay,
		LayoutOrder = 3,
		Parent = left,
		GetItems = function()
			return self:_themeItems()
		end,
	})
	self:Track(self._themeMenu)

	self._optionsMenu = Menu.new({
		Text = Locale.T("topbar.options"),
		Overlay = props.Overlay,
		LayoutOrder = 4,
		Parent = left,
		GetItems = function()
			return self:_optionItems()
		end,
	})
	self:Track(self._optionsMenu)

	--------------------------------------------------------------------------
	-- 가운데 작업 이름
	--------------------------------------------------------------------------

	self._nameLabel = Create.label({
		Name = "ProjectName",
		Text = "",
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 260, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = root,
	})

	--------------------------------------------------------------------------
	-- 오른쪽
	--------------------------------------------------------------------------

	local right = Create("Frame", {
		Name = "Right",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 220, 1, 0),
		Parent = root,
	}, {
		Create.list(Enum.FillDirection.Horizontal, 6, {
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		Create.padding(4, 6),
	})

	self._saveButton = Button.new({
		Text = "Save",
		Variant = "primary",
		Size = UDim2.new(0, 0, 0, 24),
		TextSize = 12,
		LayoutOrder = 1,
		OnClick = function()
			self._app:SaveProject()
		end,
		Parent = right,
	})
	self:Track(self._saveButton)

	self._closeButton = Button.new({
		Text = "Close",
		Variant = "default",
		Size = UDim2.new(0, 0, 0, 24),
		TextSize = 12,
		LayoutOrder = 2,
		OnClick = function()
			self._app:CloseProject()
		end,
		Parent = right,
	})
	self:Track(self._closeButton)

	-- 메뉴 버튼 글자는 만들 때 한 번 넣으므로 언어가 바뀌면 다시 넣는다.
	self:BindLocale(function()
		self._menu:SetText(Locale.T("topbar.menu"))
		self._languageMenu:SetText(Locale.T("topbar.language"))
		self._themeMenu:SetText(Locale.T("topbar.theme"))
		self._optionsMenu:SetText(Locale.T("topbar.options"))
	end)

	self:BindTheme(function(tokens)
		root.BackgroundColor3 = tokens.color.topBar
		self._divider.BackgroundColor3 = tokens.color.border
		self._nameLabel.TextColor3 = tokens.color.text
	end)

	-- 저장 필요 여부를 이름 옆 점으로 표시한다.
	self:Track(self._project.DirtyChanged:Connect(function()
		self:_refreshName()
	end))
	self:Track(self._project.Changed:Connect(function()
		self:_refreshName()
	end))
	self:_refreshName()

	return self
end

function TopBar:_refreshName()
	local dirty = self._project:IsDirty()
	self._nameLabel.Text = self._project:GetName() .. (if dirty then "  *" else "")
	self._saveButton:SetEnabled(dirty)
end

function TopBar:_menuItems()
	local project = self._project
	return {
		{
			Text = Locale.T("topbar.export"),
			OnSelect = function()
				self._app:ExportToWorkspace()
			end,
		},
		{
			Text = Locale.T("topbar.exportPlayer"),
			OnSelect = function()
				self._app:ExportPlayerToWorkspace()
			end,
		},
		{ Separator = true },
		{
			Text = "Save",
			Disabled = not project:IsDirty(),
			OnSelect = function()
				self._app:SaveProject()
			end,
		},
		{
			Text = "Rename...",
			OnSelect = function()
				self._app:RenameProject()
			end,
		},
		{ Separator = true },
		{
			Text = "Undo",
			Disabled = not project:CanUndo(),
			OnSelect = function()
				project:Undo()
			end,
		},
		{
			Text = "Redo",
			Disabled = not project:CanRedo(),
			OnSelect = function()
				project:Redo()
			end,
		},
		{ Separator = true },
		{
			Text = "Close Animation",
			OnSelect = function()
				self._app:CloseProject()
			end,
		},
		{
			Text = "Delete Animation",
			Variant = "danger",
			OnSelect = function()
				self._app:DeleteProject(project:GetName())
			end,
		},
	}
end

function TopBar:_optionItems()
	return {
		{
			Text = Locale.T("topbar.followSelection"),
			Checked = ViewOptions.IsFollowSelectionEnabled(),
			OnSelect = function()
				ViewOptions.SetFollowSelection(not ViewOptions.IsFollowSelectionEnabled())
			end,
		},
		{
			Text = Locale.T("topbar.showMarkers"),
			Checked = ViewOptions.AreMarkersVisible(),
			OnSelect = function()
				ViewOptions.SetMarkersVisible(not ViewOptions.AreMarkersVisible())
			end,
		},
		{
			Text = Locale.T("topbar.deselectWhilePlaying"),
			Checked = Player.IsDeselectEnabled(),
			OnSelect = function()
				Player.SetDeselectEnabled(not Player.IsDeselectEnabled())
			end,
		},
		{ Separator = true },
		{
			Text = "Print Reflection Info",
			OnSelect = function()
				self:_printReflectionInfo()
			end,
		},
		{ Separator = true },
		{
			Text = "Print Debug Log",
			OnSelect = function()
				print(Debug.report())
			end,
		},
		{
			Text = "Clear Debug Log",
			OnSelect = function()
				Debug.clear()
				print(Locale.T("log.debugCleared"))
			end,
		},
	}
end

-- 리플렉션이 돌려주는 표가 실제로 어떻게 생겼는지 출력한다.
-- Type과 Permits의 모양을 알면 그걸 써서 읽기 전용 속성을 걸러낼 수 있다.
function TopBar:_printReflectionInfo()
	if not Reflection.IsAvailable() then
		print(Locale.T("log.reflectionUnavailable"))
		return
	end

	-- Explorer에서 고른 게 있으면 그 클래스를, 없으면 Part를 본다.
	local selected = Selection:Get()
	local className = if #selected == 1 then selected[1].ClassName else "Part"

	print(Locale.T("log.reflectionReady", className))
	print(Reflection.describe(className))
end

function TopBar:_languageItems()
	local currentName = Locale.GetName()
	local items = {}
	for _, name in Locale.ORDER do
		table.insert(items, {
			-- 목록에는 그 언어로 쓴 이름을 보여준다. 지금 언어를 못 읽는
			-- 사람이 자기 언어를 찾을 수 있어야 하기 때문이다.
			Text = Locale.DISPLAY[name] or name,
			Checked = name == currentName,
			OnSelect = function()
				Locale.Set(name)
			end,
		})
	end
	return items
end

function TopBar:_themeItems()
	local currentName = Theme.GetName()
	local items = {}
	for _, name in Theme.ORDER do
		table.insert(items, {
			Text = name,
			Checked = name == currentName,
			OnSelect = function()
				Theme.Set(name)
			end,
		})
	end
	return items
end

return TopBar
