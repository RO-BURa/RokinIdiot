--!nonstrict
-- 키프레임 하나를 고쳐 쓰는 모달.
-- 타임라인에서 키를 우클릭 → Edit Keyframe, 또는 더블클릭으로 연다.
--
--   ┌ Edit Keyframe ─────────────────────────────┐
--   │ 2 · MainParticle · Enabled                  │
--   │ 시간  [0.500      ]  프레임 15               │
--   │ 값    [true                      ] [Capture]│
--   │ 이징  [Sine  v] [Out  v]                     │
--   │ Delete                      [Cancel] [Save] │
--   └─────────────────────────────────────────────┘

local Create = require(script.Parent.Parent.Create)
local Theme = require(script.Parent.Parent.Theme)
local Button = require(script.Parent.Parent.Components.Button)
local Menu = require(script.Parent.Parent.Components.Menu)

local Ops = require(script.Parent.Parent.Parent.Core.Ops)
local Schema = require(script.Parent.Parent.Parent.Core.Schema)
local PathSpec = require(script.Parent.Parent.Parent.Core.PathSpec)
local Value = require(script.Parent.Parent.Parent.Core.Value)
local Literal = require(script.Parent.Parent.Parent.Core.Literal)
local Easing = require(script.Parent.Parent.Parent.Core.Easing)
local Store = require(script.Parent.Parent.Parent.Plugin.Store)
local Locale = require(script.Parent.Parent.Parent.Core.Locale)

local KeyEditor = {}

local WIDTH = 430
local LABEL_WIDTH = 46
local FIELD_HEIGHT = 24
local ROW_GAP = 8
local SWATCH_SIZE = 14

-- state: EditorState, frame: 편집할 키의 (아이템, 경로, 타겟, 시간)
-- 여럿 골라둔 키를 한꺼번에 고친다.
-- 타입이 같은 것들만 여기로 올 수 있다 (EditorState:MultiFramesShareType).
function KeyEditor.openMulti(overlay: Instance, state)
	local entries = state:ResolveMultiFrames()
	if #entries < 2 then
		return
	end

	local frames = {}
	for _, entry in entries do
		table.insert(frames, entry.frame)
	end

	-- 값은 첫 번째 것으로 채워 넣고, 저장하면 전부에 같은 값이 들어간다.
	KeyEditor.open(overlay, state, frames[1], frames)
end

-- frames를 주면 그 전부에 같은 값을 넣는다. 이때 시간 칸은 없앤다.
-- 서로 다른 시간에 있는 키들이라 하나로 맞출 수가 없다.
function KeyEditor.open(overlay: Instance, state, frame, frames)
	local project = state.Project
	local track = Ops.findTrack(project:GetDocument(), frame.itemId, frame.path, frame.target)
	if not track then
		return
	end
	local key = Ops.findKeyAt(track, frame.t)
	if not key then
		return
	end

	local isMulti = frames ~= nil and #frames > 1
	local targets = frames or { frame }

	local tokens = Theme.Get()
	local isMethod = track.kind == Schema.TRACK_KIND.METHOD
	local canEase = not isMethod and Value.canInterpolate(track.valueType)

	--------------------------------------------------------------------------
	-- 편집 중인 값 (Save 전까지는 문서를 건드리지 않는다)
	--------------------------------------------------------------------------

	local easingStyle, easingDirection = "Linear", "InOut"
	if key.ease then
		easingStyle = key.ease[1] or "Linear"
		easingDirection = key.ease[2] or "InOut"
	end

	-- 여럿을 고칠 때는 시간 칸이 없어서 한 줄이 줄어든다.
	local rowCount = (if isMulti then 1 else 2) + (if canEase then 1 else 0)
	local height = 14 + 20 + 6 + rowCount * (FIELD_HEIGHT + ROW_GAP) + 16 + 28 + 14

	--------------------------------------------------------------------------
	-- 틀
	--------------------------------------------------------------------------

	local root = Create("Frame", {
		Name = "KeyEditorLayer",
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

	-- Frame이면 창 안을 눌러도 클릭이 밑의 스크림으로 통과해서 닫혀버린다.
	-- 버튼이어야 여기서 확실히 멈춘다.
	local panel = Create("TextButton", {
		Name = "Panel",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = tokens.color.panel,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WIDTH, height),
		ZIndex = 101,
		Parent = root,
	}, {
		Create.corner(6),
		Create.stroke(tokens.color.border),
		Create.padding(14, 16),
	})

	Create.label({
		Name = "Title",
		Text = if isMulti then string.format("Edit %d Keyframes", #targets) else "Edit Keyframe",
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = tokens.color.text,
		Size = UDim2.new(1, 0, 0, 20),
		ZIndex = 102,
		Parent = panel,
	})

	local leaf = if track.path == "" then Locale.T("common.root") else PathSpec.leafName(track.path)
	Create.label({
		Name = "Track",
		Text = string.format("%d · %s · %s", track.itemId, leaf, PathSpec.formatTarget(track.kind, track.target)),
		TextSize = 11,
		TextColor3 = tokens.color.textMuted,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 3),
		Size = UDim2.new(0, 260, 0, 16),
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 102,
		Parent = panel,
	})

	local cursorY = 26

	local function addLabel(text: string)
		Create.label({
			Name = "Label",
			Text = text,
			TextSize = 11,
			TextColor3 = tokens.color.textMuted,
			Position = UDim2.fromOffset(0, cursorY),
			Size = UDim2.fromOffset(LABEL_WIDTH, FIELD_HEIGHT),
			ZIndex = 102,
			Parent = panel,
		})
	end

	local function addTextBox(width: number, placeholder: string): TextBox
		return Create("TextBox", {
			Name = "Input",
			Text = "",
			PlaceholderText = placeholder,
			ClearTextOnFocus = false,
			Font = Enum.Font.Code,
			TextSize = 12,
			TextColor3 = tokens.color.text,
			PlaceholderColor3 = tokens.color.textMuted,
			TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundColor3 = tokens.color.inputBackground,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(LABEL_WIDTH, cursorY),
			Size = UDim2.new(width, if width == 0 then 120 else -LABEL_WIDTH, 0, FIELD_HEIGHT),
			ZIndex = 102,
			Parent = panel,
		}, {
			Create.corner(4),
			Create.stroke(tokens.color.border),
			Create.padding(0, 6),
		})
	end

	--------------------------------------------------------------------------
	-- 시간
	--------------------------------------------------------------------------

	-- 여럿을 고칠 때는 시간 칸을 아예 두지 않는다. 서로 다른 시간에 있는
	-- 키들이라 한 값으로 맞출 수가 없고, 맞춰봐야 전부 한 자리에 겹친다.
	local timeBox: TextBox? = nil
	if not isMulti then
		addLabel(Locale.T("key.time"))
		local box = addTextBox(0, "")
		box.Name = "Time"
		box.Text = string.format("%.3f", key.t)
		timeBox = box

		local frameLabel = Create.label({
			Name = "FrameHint",
			Text = "",
			TextSize = 11,
			TextColor3 = tokens.color.textMuted,
			Position = UDim2.fromOffset(LABEL_WIDTH + 130, cursorY),
			Size = UDim2.new(1, -(LABEL_WIDTH + 130), 0, FIELD_HEIGHT),
			ZIndex = 102,
			Parent = panel,
		})

		local doc = project:GetDocument()
		local function refreshFrameHint()
			local seconds = tonumber(box.Text)
			if not seconds then
				frameLabel.Text = ""
				return
			end
			local snapped = state:SnapTime(seconds)
			frameLabel.Text = string.format(
				Locale.T("key.frameInfo"),
				math.round(snapped * doc.fps),
				math.round(doc.duration * doc.fps),
				state:SnapLabel()
			)
		end
		refreshFrameHint()
		box:GetPropertyChangedSignal("Text"):Connect(refreshFrameHint)

		cursorY += FIELD_HEIGHT + ROW_GAP
	end

	--------------------------------------------------------------------------
	-- 값 / 인자
	--------------------------------------------------------------------------

	local components = {}
	local captureButton = nil
	local swatch: Frame? = nil
	local gradient: UIGradient? = nil

	-- 지금 들고 있는 값. 글자가 아니라 값 자체다.
	--
	-- ColorSequence처럼 글로 적을 수 없는 타입이 있다. 그런 타입은 화면에
	-- "키포인트 3개" 같은 설명을 띄우는데, 저장할 때 그 글을 도로 값으로
	-- 읽으려 하면 당연히 실패한다. 그래서 값을 따로 들고 있다가 그대로 쓴다.
	--
	-- 사용자가 칸을 직접 고치면 그 글이 우선이므로 여기를 비운다.
	local heldValue = nil
	if not isMethod then
		heldValue = Value.decode(track.valueType, key.v)
	end

	addLabel(if isMethod then Locale.T("key.args") else Locale.T("key.value"))

	local valueBox = addTextBox(1, "")
	valueBox.Name = "Value"

	if isMethod then
		valueBox.Text = Literal.formatList(key.args or {})
		valueBox.PlaceholderText = Locale.T("key.valuePlaceholder")
	else
		valueBox.Text = Value.format(track.valueType, heldValue)
		valueBox.PlaceholderText = track.valueType or ""

		-- 색 타입은 값 칸 왼쪽에 견본을 세운다. ColorSequence처럼 글로는
		-- "키포인트 3개"밖에 못 보여주는 타입에서 특히 이게 유일한 단서다.
		if Value.previewColor(track.valueType, heldValue) ~= nil or track.valueType == "ColorSequence" then
			swatch = Create("Frame", {
				Name = "Swatch",
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(LABEL_WIDTH - SWATCH_SIZE - 6, cursorY + (FIELD_HEIGHT - SWATCH_SIZE) // 2),
				Size = UDim2.fromOffset(SWATCH_SIZE, SWATCH_SIZE),
				ZIndex = 102,
				Parent = panel,
			}, {
				Create.corner(3),
				Create.stroke(tokens.color.border),
			})
		end

		-- 글이 바뀌면 사용자가 직접 적은 것이므로 들고 있던 값을 버린다.
		-- Capture와 처음 채울 때는 우리가 넣는 것이라 그때만 다시 잡는다.
		valueBox:GetPropertyChangedSignal("Text"):Connect(function()
			heldValue = nil
		end)

		-- Capture 자리를 비워두고 값 칸을 줄인다.
		valueBox.Size = UDim2.new(1, -(LABEL_WIDTH + 74), 0, FIELD_HEIGHT)

		captureButton = Button.new({
			Text = "Capture",
			Variant = "default",
			TextSize = 11,
			Size = UDim2.new(0, 0, 0, FIELD_HEIGHT),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, cursorY),
			Parent = panel,
		})
		table.insert(components, captureButton)
		captureButton.Instance.ZIndex = 102
	end

	-- 견본 색을 지금 값에 맞춘다. Capture로 값이 바뀔 때마다 다시 부른다.
	--
	-- ColorSequence는 색이 여럿이라 하나로 줄이면 그라디언트인지도 알 수 없다.
	-- 값을 UIGradient에 그대로 꽂으면 실제 모양이 그대로 보인다.
	local function refreshSwatch()
		if not swatch then
			return
		end

		if track.valueType == "ColorSequence" then
			swatch.Visible = heldValue ~= nil
			swatch.BackgroundColor3 = Color3.new(1, 1, 1)

			if heldValue ~= nil then
				if not gradient then
					gradient = Create("UIGradient", { Parent = swatch }) :: UIGradient
				end
				(gradient :: UIGradient).Color = heldValue
			end
			return
		end

		local color = Value.previewColor(track.valueType, heldValue)
		swatch.Visible = color ~= nil
		if color then
			swatch.BackgroundColor3 = color
		end
	end
	refreshSwatch()

	cursorY += FIELD_HEIGHT + ROW_GAP

	--------------------------------------------------------------------------
	-- 이징
	--------------------------------------------------------------------------

	local styleMenu, directionMenu, directionSlot

	if canEase then
		addLabel(Locale.T("key.easing"))

		local function addMenuSlot(offsetX: number, width: number, options, getCurrent, onChoose)
			local slot = Create("Frame", {
				Name = "MenuSlot",
				BackgroundColor3 = tokens.color.inputBackground,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(LABEL_WIDTH + offsetX, cursorY),
				Size = UDim2.fromOffset(width, FIELD_HEIGHT),
				ZIndex = 102,
				Parent = panel,
			}, {
				Create.corner(4),
				Create.stroke(tokens.color.border),
				-- 오른쪽은 펼침 표시 자리로 비워둔다.
				Create.padding(0, 14, 0, 4),
			})

			Create.label({
				Name = "Caret",
				Text = "v",
				TextColor3 = tokens.color.textMuted,
				TextSize = 10,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 10, 0.5, 0),
				Size = UDim2.fromOffset(10, FIELD_HEIGHT),
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 102,
				Parent = slot,
			})

			local menu = Menu.new({
				Text = "",
				Overlay = overlay,
				-- 모달 위에 떠야 한다.
				ZIndex = 110,
				TextSize = 11,
				PaddingX = 6,
				Parent = slot,
				GetItems = function()
					local current = getCurrent()
					local items = {}
					for _, option in options do
						table.insert(items, {
							Text = option,
							Checked = option == current,
							OnSelect = function()
								onChoose(option)
							end,
						})
					end
					return items
				end,
			})
			table.insert(components, menu)
			return slot, menu
		end

		local easingHint = Create.label({
			Name = "EasingHint",
			Text = "",
			TextSize = 10,
			TextColor3 = tokens.color.textMuted,
			TextWrapped = true,
			Position = UDim2.fromOffset(LABEL_WIDTH + 232, cursorY),
			Size = UDim2.new(1, -(LABEL_WIDTH + 232), 0, FIELD_HEIGHT),
			ZIndex = 102,
			Parent = panel,
		})

		local function refreshEasing()
			styleMenu:SetText(easingStyle)
			directionMenu:SetText(easingDirection)
			-- Linear와 Constant는 방향이 의미가 없다.
			directionSlot.Visible = Easing.hasDirection(easingStyle)
			easingHint.Text = Easing.describe(easingStyle)
		end

		local _, style = addMenuSlot(0, 120, Easing.STYLES, function()
			return easingStyle
		end, function(choice)
			easingStyle = choice
			refreshEasing()
		end)
		styleMenu = style

		directionSlot, directionMenu = addMenuSlot(128, 96, Easing.DIRECTIONS, function()
			return easingDirection
		end, function(choice)
			easingDirection = choice
			refreshEasing()
		end)

		refreshEasing()
		cursorY += FIELD_HEIGHT + ROW_GAP
	else
		addLabel("")
		Create.label({
			Name = "Hint",
			Text = if isMethod
				then Locale.T("key.methodHint")
				else Locale.T("key.constantHint", track.valueType or Locale.T("key.thisType")),
			TextSize = 11,
			TextColor3 = tokens.color.textMuted,
			Position = UDim2.fromOffset(0, cursorY - ROW_GAP),
			Size = UDim2.new(1, 0, 0, 16),
			ZIndex = 102,
			Parent = panel,
		})
	end

	--------------------------------------------------------------------------
	-- 오류 문구 + 버튼
	--------------------------------------------------------------------------

	local errorLabel = Create.label({
		Name = "Error",
		Text = "",
		TextSize = 11,
		TextColor3 = tokens.color.danger,
		TextWrapped = true,
		Position = UDim2.fromOffset(0, cursorY),
		Size = UDim2.new(1, 0, 0, 16),
		ZIndex = 102,
		Parent = panel,
	})
	cursorY += 20

	local buttonRow = Create("Frame", {
		Name = "Buttons",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, cursorY),
		Size = UDim2.new(1, 0, 0, 28),
		ZIndex = 102,
		Parent = panel,
	}, {
		Create.list(Enum.FillDirection.Horizontal, 8, {
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
		}),
	})

	local deleteSlot = Create("Frame", {
		Name = "DeleteSlot",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, cursorY),
		Size = UDim2.new(0, 120, 0, 28),
		ZIndex = 102,
		Parent = panel,
	}, {
		Create.list(Enum.FillDirection.Horizontal, 0, {
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})

	--------------------------------------------------------------------------
	-- 동작
	--------------------------------------------------------------------------

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		Menu.closeContext()
		for _, component in components do
			component:Destroy()
		end
		root:Destroy()
	end

	local function save()
		-- 여럿일 때는 시간을 안 건드리므로 원래 자리를 그대로 쓴다.
		local newTime = frame.t
		if timeBox then
			local seconds = tonumber(timeBox.Text)
			if not seconds then
				errorLabel.Text = Locale.T("key.timeNumber")
				return
			end
			newTime = state:SnapTime(seconds)

			-- 그 자리에 다른 키가 있으면 밀어내지 않고 알려준다.
			local occupant = Ops.findKeyAt(track, newTime)
			if occupant and occupant ~= key then
				errorLabel.Text = Locale.T("key.timeTaken", newTime)
				return
			end
		end

		local parsedValue, parsedArgs
		if isMethod then
			local ok, boxes, reason = Literal.parseList(valueBox.Text)
			if not ok then
				errorLabel.Text = reason or Locale.T("key.checkValue")
				return
			end
			parsedArgs = boxes
		else
			if heldValue ~= nil then
				-- 칸을 건드리지 않았거나 Capture로 채운 값. 글을 거치지 않는다.
				parsedValue = Value.encode(track.valueType, heldValue)
			else
				local ok, parsed, reason = Value.parse(track.valueType, valueBox.Text, track.enumType)
				if not ok then
					errorLabel.Text = reason or Locale.T("key.checkValue")
					return
				end
				parsedValue = Value.encode(track.valueType, parsed)
			end
		end

		local oldTime = frame.t
		project:Commit(if isMulti then Locale.T("undo.editKeys") else Locale.T("undo.editKey"), function(document)
			-- 고른 것 전부에 같은 값을 넣는다. 하나만 고쳤으면 목록이 하나다.
			for _, target in targets do
				if isMethod then
					Ops.setKeyArgs(document, target.itemId, target.path, target.target, target.t, parsedArgs)
				else
					Ops.setKeyValue(document, target.itemId, target.path, target.target, target.t, parsedValue)
					if canEase then
						-- Linear는 기본값이라 아예 안 적는다. 저장 파일이 깔끔해진다.
						if easingStyle == Easing.LINEAR then
							Ops.setKeyEasing(document, target.itemId, target.path, target.target, target.t, nil, nil)
						else
							Ops.setKeyEasing(
								document,
								target.itemId,
								target.path,
								target.target,
								target.t,
								easingStyle,
								easingDirection
							)
						end
					end
				end
			end

			-- 시간을 먼저 옮기면 위에서 키를 못 찾는다. 그래서 여기가 마지막이다.
			if not isMulti and math.abs(newTime - oldTime) > 1e-6 then
				Ops.moveKey(document, frame.itemId, frame.path, frame.target, oldTime, newTime)
			end
		end)

		if not isMulti then
			state:SelectFrame({
				itemId = frame.itemId,
				path = frame.path,
				target = frame.target,
				t = newTime,
			})
		end
		close()
	end

	if captureButton then
		captureButton.Instance.Activated:Connect(function()
			local bound = Store.GetBinding(state:GetSavedName(), track.itemId)
			if bound and not bound:IsDescendantOf(game) then
				bound = nil
			end

			local resolved = if bound then PathSpec.resolve(bound, track.path) else nil
			local ok, current, reason = Value.capture(resolved, track.target, track.valueType)
			if not ok then
				errorLabel.Text = reason or Locale.T("key.readFailed")
				return
			end

			-- 글은 보여주기용이고 저장에는 이 값을 쓴다.
			-- Text를 넣으면 위의 연결이 heldValue를 비우므로 뒤에 다시 잡는다.
			valueBox.Text = Value.format(track.valueType, current)
			heldValue = current
			refreshSwatch()
			errorLabel.Text = ""
		end)
	end

	table.insert(
		components,
		Button.new({
			Text = if isMulti then string.format("Delete %d Keyframes", #targets) else "Delete Keyframe",
			Variant = "muted",
			TextSize = 11,
			Size = UDim2.new(0, 0, 0, 26),
			OnClick = function()
				project:Commit(
					if isMulti then Locale.T("undo.deleteKeys") else Locale.T("undo.deleteKey"),
					function(document)
						for _, target in targets do
							Ops.removeKeyAt(document, target.itemId, target.path, target.target, target.t)
						end
					end
				)
				state:SelectFrame(nil)
				close()
			end,
			Parent = deleteSlot,
		})
	)

	table.insert(
		components,
		Button.new({
			Text = "Cancel",
			Variant = "default",
			LayoutOrder = 1,
			OnClick = close,
			Parent = buttonRow,
		})
	)

	table.insert(
		components,
		Button.new({
			Text = "Save",
			Variant = "primary",
			LayoutOrder = 2,
			OnClick = save,
			Parent = buttonRow,
		})
	)

	scrim.Activated:Connect(close)
	valueBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			save()
		end
	end)
	if timeBox then
		timeBox.FocusLost:Connect(function(enterPressed)
			if enterPressed then
				save()
			end
		end)
	end

	root.Parent = overlay

	task.defer(function()
		if not closed then
			valueBox:CaptureFocus()
		end
	end)

	return { Close = close }
end

return KeyEditor
