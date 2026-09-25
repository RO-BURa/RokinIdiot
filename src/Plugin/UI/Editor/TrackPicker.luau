--!nonstrict
-- 트랙에 걸 속성이나 메소드를 고르는 창.
--
--   ┌ Add Track ────── MainParticle · ParticleEmitter ┐
--   │ [속성] [메소드]                                  │
--   │ [검색                                           ]│
--   │  Enabled                             boolean     │
--   │  Rate                                number      │
--   │  ─ 그 밖의 속성 ─                                │
--   │  Acceleration                        Vector3     │
--   │  VelocitySpread                      number      │ ← 폐기된 것은 취소선
--   │ [Custom...]                            [Cancel] │
--   └──────────────────────────────────────────────────┘
--
-- 목록은 ReflectionService가 알려준 이름을 바인딩된 오브젝트에서 실제로
-- 읽어보고 남긴 것이다. 값 타입은 읽은 값의 typeof라 정확하다.
-- 폐기 표시는 Display.DeprecationMessage가 있는 것들이다.

local Create = require(script.Parent.Parent.Create)
local Theme = require(script.Parent.Parent.Theme)
local Button = require(script.Parent.Parent.Components.Button)

local Ops = require(script.Parent.Parent.Parent.Core.Ops)
local Schema = require(script.Parent.Parent.Parent.Core.Schema)
local PathSpec = require(script.Parent.Parent.Parent.Core.PathSpec)
local PropertySpec = require(script.Parent.Parent.Parent.Core.PropertySpec)
local Locale = require(script.Parent.Parent.Parent.Core.Locale)

local TrackPicker = {}

local WIDTH = 290
local HEIGHT = 280
local ROW_HEIGHT = 19
local HEADING_HEIGHT = 16

-- 창 안 세로 배치
local TITLE_HEIGHT = 20
local TAB_TOP = 26
local TAB_HEIGHT = 20
local SEARCH_TOP = 52
local SEARCH_HEIGHT = 22
local LIST_TOP = 80
local LIST_BOTTOM = 30

function TrackPicker.open(overlay: Instance, state, itemId: number, path: string, onCustom: () -> ())
	local project = state.Project
	local instance = state:ResolveInstance(itemId, path)
	local tokens = Theme.Get()

	local properties = PropertySpec.discover(instance)
	local methods = PropertySpec.discoverMethods(instance)

	local function isTaken(target: string): boolean
		return Ops.findTrack(project:GetDocument(), itemId, path, target) ~= nil
	end

	--------------------------------------------------------------------------
	-- 틀
	--------------------------------------------------------------------------

	local root = Create("Frame", {
		Name = "TrackPickerLayer",
		BackgroundColor3 = tokens.color.scrim,
		BackgroundTransparency = tokens.scrimTransparency,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 100,
	})

	local scrim = Create("TextButton", {
		Name = "Scrim",
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 100,
		Parent = root,
	})

	-- 버튼이어야 창 안 클릭이 스크림으로 새지 않는다.
	local panel = Create("TextButton", {
		Name = "Panel",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = tokens.color.panel,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		ZIndex = 101,
		Parent = root,
	}, {
		Create.corner(6),
		Create.stroke(tokens.color.border),
		Create.padding(10, 10),
	})

	Create.label({
		Name = "Title",
		Text = "Add Track",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = tokens.color.text,
		Size = UDim2.new(0, 90, 0, TITLE_HEIGHT),
		ZIndex = 102,
		Parent = panel,
	})

	local leaf = if path == "" then Locale.T("common.itemRoot") else PathSpec.leafName(path)
	Create.label({
		Name = "Target",
		Text = if instance
			then string.format("%s · %s", leaf, instance.ClassName)
			else leaf .. " · " .. Locale.T("picker.noBinding"),
		TextSize = 10,
		TextColor3 = tokens.color.textMuted,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 4),
		Size = UDim2.new(1, -96, 0, 14),
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 102,
		Parent = panel,
	})

	--------------------------------------------------------------------------
	-- 탭
	--------------------------------------------------------------------------

	local mode = "property"
	local tabButtons = {}
	local render

	local function makeTab(text: string, value: string, offsetX: number, width: number)
		local button = Create("TextButton", {
			Name = value,
			Text = text,
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(offsetX, TAB_TOP),
			Size = UDim2.fromOffset(width, TAB_HEIGHT),
			ZIndex = 102,
			Parent = panel,
		}, {
			Create.corner(3),
		})

		tabButtons[value] = button
		button.Activated:Connect(function()
			if mode ~= value then
				mode = value
				render()
			end
		end)
		return button
	end

	makeTab(Locale.T("picker.properties", #properties), "property", 0, 76)
	makeTab(Locale.T("picker.methods", #methods), "method", 80, 76)

	local function paintTabs()
		for value, button in tabButtons do
			local active = value == mode
			button.BackgroundColor3 = if active then tokens.color.accent else tokens.color.buttonBackground
			button.TextColor3 = if active then tokens.color.textOnAccent else tokens.color.text
		end
	end

	--------------------------------------------------------------------------
	-- 검색
	--------------------------------------------------------------------------

	local search = Create("TextBox", {
		Name = "Search",
		Text = "",
		PlaceholderText = Locale.T("picker.search"),
		ClearTextOnFocus = false,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextColor3 = tokens.color.text,
		PlaceholderColor3 = tokens.color.textMuted,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundColor3 = tokens.color.inputBackground,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, SEARCH_TOP),
		Size = UDim2.new(1, 0, 0, SEARCH_HEIGHT),
		ZIndex = 102,
		Parent = panel,
	}, {
		Create.corner(3),
		Create.stroke(tokens.color.border),
		Create.padding(0, 6),
	})

	--------------------------------------------------------------------------
	-- 목록
	--------------------------------------------------------------------------

	local list = Create("ScrollingFrame", {
		Name = "List",
		BackgroundColor3 = tokens.color.inputBackground,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, LIST_TOP),
		Size = UDim2.new(1, 0, 1, -(LIST_TOP + LIST_BOTTOM)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarImageColor3 = tokens.color.border,
		ZIndex = 102,
		Parent = panel,
	}, {
		Create.corner(3),
		Create.list(Enum.FillDirection.Vertical, 0),
		Create.padding(3, 0),
	})

	local empty = Create.label({
		Name = "Empty",
		Text = "",
		TextSize = 11,
		TextColor3 = tokens.color.textMuted,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, LIST_TOP + 12),
		Size = UDim2.new(1, 0, 0, 40),
		Visible = false,
		ZIndex = 103,
		Parent = panel,
	})

	--------------------------------------------------------------------------
	-- 동작
	--------------------------------------------------------------------------

	local components = {}
	local rows = {}
	local closed = false

	local function close()
		if closed then
			return
		end
		closed = true
		for _, component in components do
			component:Destroy()
		end
		root:Destroy()
	end

	local function choose(name: string, valueType: string?, enumType: string?)
		local kind = if mode == "method" then Schema.TRACK_KIND.METHOD else Schema.TRACK_KIND.PROPERTY
		project:Commit(Locale.T("undo.addTrack"), function(doc)
			Ops.addTrack(doc, itemId, path, kind, name, valueType, enumType)
		end)
		close()
	end

	local function clearRows()
		for _, row in rows do
			row:Destroy()
		end
		table.clear(rows)
	end

	local function addHeading(text: string, order: number)
		local heading = Create.label({
			Name = "Heading",
			Text = text,
			Font = Enum.Font.GothamBold,
			TextSize = 9,
			TextColor3 = tokens.color.textMuted,
			TextYAlignment = Enum.TextYAlignment.Bottom,
			Size = UDim2.new(1, 0, 0, HEADING_HEIGHT),
			LayoutOrder = order,
			ZIndex = 102,
			Parent = list,
		})
		Create.padding(0, 8).Parent = heading
		table.insert(rows, heading)
	end

	local function addRow(entry, order: number)
		local taken = isTaken(entry.name)
		local isMethod = mode == "method"
		local label = if isMethod then PathSpec.formatTarget("method", entry.name) else entry.name

		local row = Create("TextButton", {
			Name = entry.name,
			Text = "",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
			LayoutOrder = order,
			ZIndex = 102,
			Parent = list,
		})
		table.insert(rows, row)

		Create.label({
			Name = "Name",
			-- 폐기된 것은 취소선. RichText를 켜야 <s>가 먹는다.
			Text = if entry.deprecated then "<s>" .. label .. "</s>" else label,
			RichText = entry.deprecated,
			Font = if isMethod then Enum.Font.Code else Enum.Font.Gotham,
			TextSize = 11,
			TextColor3 = if taken or entry.deprecated
				then tokens.color.textMuted
				elseif isMethod then tokens.color.accent
				else tokens.color.text,
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(1, -100, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 103,
			Parent = row,
		})

		Create.label({
			Name = "Type",
			-- Enum이면 어느 Enum인지까지 보여준다. "EnumItem"만으로는 알 수 없다.
			Text = if taken
				then Locale.T("picker.alreadyAdded")
				elseif entry.enumType then "Enum." .. entry.enumType
				else (entry.valueType or ""),
			TextSize = 9,
			TextColor3 = tokens.color.textMuted,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 0),
			Size = UDim2.fromOffset(88, ROW_HEIGHT),
			ZIndex = 103,
			Parent = row,
		})

		if taken then
			return
		end

		row.MouseEnter:Connect(function()
			row.BackgroundTransparency = 0
			row.BackgroundColor3 = tokens.color.rowHover
		end)
		row.MouseLeave:Connect(function()
			row.BackgroundTransparency = 1
		end)
		row.Activated:Connect(function()
			choose(entry.name, entry.valueType, entry.enumType)
		end)
	end

	render = function()
		clearRows()
		paintTabs()

		local entries = if mode == "method" then methods else properties
		local needle = search.Text:lower()
		local order = 0
		local shown = 0
		local addedOtherHeading = false

		for _, entry in entries do
			if needle == "" or entry.name:lower():find(needle, 1, true) then
				-- 검색 중에는 묶음 머리말이 의미가 없다.
				if needle == "" and not entry.common and not addedOtherHeading then
					addedOtherHeading = true
					order += 1
					addHeading(
						if mode == "method" then Locale.T("picker.otherMethods") else Locale.T("picker.otherProperties"),
						order
					)
				end

				order += 1
				shown += 1
				addRow(entry, order)
			end
		end

		empty.Visible = shown == 0
		if shown == 0 then
			if #entries == 0 then
				empty.Text = if instance then Locale.T("picker.emptyList") else Locale.T("picker.noBindingList")
			else
				empty.Text = Locale.T("picker.noMatch", search.Text)
			end
		end
	end

	render()
	search:GetPropertyChangedSignal("Text"):Connect(render)

	--------------------------------------------------------------------------
	-- 아래쪽 버튼
	--------------------------------------------------------------------------

	local customSlot = Create("Frame", {
		Name = "CustomSlot",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(0, 140, 0, 24),
		ZIndex = 102,
		Parent = panel,
	}, {
		Create.list(Enum.FillDirection.Horizontal, 0, {
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})

	local cancelSlot = Create("Frame", {
		Name = "CancelSlot",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.new(0, 140, 0, 24),
		ZIndex = 102,
		Parent = panel,
	}, {
		Create.list(Enum.FillDirection.Horizontal, 0, {
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})

	table.insert(
		components,
		Button.new({
			Text = "Custom...",
			Variant = "default",
			TextSize = 11,
			Size = UDim2.new(0, 0, 0, 22),
			OnClick = function()
				close()
				onCustom()
			end,
			Parent = customSlot,
		})
	)

	table.insert(
		components,
		Button.new({
			Text = "Cancel",
			Variant = "default",
			TextSize = 11,
			Size = UDim2.new(0, 0, 0, 22),
			OnClick = close,
			Parent = cancelSlot,
		})
	)

	scrim.Activated:Connect(close)
	root.Parent = overlay

	task.defer(function()
		if not closed then
			search:CaptureFocus()
		end
	end)

	return { Close = close }
end

return TrackPicker
