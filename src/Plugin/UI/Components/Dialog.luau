--!nonstrict
-- 모달 대화상자. 새 작업 만들기, 이름 바꾸기, 삭제 확인, 잠금 인수에 쓰인다.
--
--   Dialog.show(overlay, {
--       Title = "New Animation",
--       Input = { Placeholder = "이름", Default = "MyCutscene" },
--       Confirm = "Create",
--       Validate = function(text) return #text > 0, "이름을 입력하세요" end,
--       OnConfirm = function(text) ... end,
--   })

local Create = require(script.Parent.Parent.Create)
local Theme = require(script.Parent.Parent.Theme)
local Locale = require(script.Parent.Parent.Parent.Core.Locale)

local Dialog = {}

export type Options = {
	Title: string,
	Message: string?,
	Input: { Placeholder: string?, Default: string? }?,
	-- 드롭다운 줄. 고른 값들이 Validate/OnConfirm의 두 번째 인자로 들어온다.
	-- VisibleWhen을 주면 다른 드롭다운의 값에 따라 이 줄이 나타났다 사라진다.
	Selects: {
		{
			Label: string,
			Options: { string },
			Default: string?,
			VisibleWhen: ((values: { string }) -> boolean)?,
		}
	}?,
	Confirm: string?,
	Cancel: string?,
	HideCancel: boolean?, -- 알림처럼 선택지가 없는 경우
	ConfirmVariant: string?, -- "primary" | "danger"
	-- 버튼 줄 왼쪽 아래에 흐리게 놓이는 세 번째 선택지.
	-- "저장하지 않고 닫기"처럼 눈에 덜 띄어야 하는 것들.
	Tertiary: { Text: string, Variant: string?, OnSelect: (() -> ())? }?,
	Validate: ((string, { string }) -> (boolean, string?))?,
	OnConfirm: ((string, { string }) -> ())?,
	OnCancel: (() -> ())?,
	-- 입력이 바뀔 때마다 부르고, 돌려준 문자열을 힌트 줄에 보여준다.
	Hint: ((string, { string }) -> string?)?,
}

local DIALOG_WIDTH = 300
local DIALOG_WIDTH_WIDE = 360 -- 버튼이 셋이면 한 줄에 다 들어가야 한다
local SELECT_LABEL_WIDTH = 72
local SELECT_HEIGHT = 24

function Dialog.show(overlay: Instance, options: Options)
	local tokens = Theme.Get()
	local Button = require(script.Parent.Button)
	local Menu = require(script.Parent.Menu)

	local hasInput = options.Input ~= nil
	local hasMessage = options.Message ~= nil
	local selectCount = if options.Selects then #options.Selects else 0
	local hasHint = options.Hint ~= nil
	local panelWidth = if options.Tertiary then DIALOG_WIDTH_WIDE else DIALOG_WIDTH

	local height = 16 + 20 + 12 -- 패딩 + 제목 + 간격
	if hasMessage then
		height += 34
	end
	if hasInput then
		height += 30 + 8
	end
	height += selectCount * (SELECT_HEIGHT + 6)
	if hasHint then
		height += 16
	end
	height += 18 -- 오류 문구 자리
	height += 28 + 12 -- 버튼 줄 + 아래 패딩

	local root = Create("Frame", {
		Name = "DialogLayer",
		BackgroundColor3 = tokens.color.scrim,
		BackgroundTransparency = tokens.scrimTransparency,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 100,
	})

	-- 바깥 클릭은 취소로 처리한다.
	local scrimButton = Create("TextButton", {
		Name = "Scrim",
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 100,
		Parent = root,
	})

	-- 판이 Frame이면 창 안을 눌러도 클릭이 밑의 스크림 버튼으로 통과해서
	-- 창이 닫혀버린다. Frame은 Active를 켜도 클릭을 확실히 삼키지 못한다.
	-- 버튼으로 만들어 두면 확실히 여기서 멈춘다 (누가 눌러도 아무 일 없음).
	local panel = Create("TextButton", {
		Name = "Dialog",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = tokens.color.panel,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(panelWidth, height),
		ZIndex = 101,
		Parent = root,
	}, {
		Create.corner(6),
		Create.stroke(tokens.color.border),
		Create.padding(14, 16),
	})

	Create.label({
		Name = "Title",
		Text = options.Title,
		TextColor3 = tokens.color.text,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		Size = UDim2.new(1, 0, 0, 20),
		ZIndex = 102,
		Parent = panel,
	})

	local cursorY = 28

	if hasMessage then
		Create.label({
			Name = "Message",
			Text = options.Message,
			TextColor3 = tokens.color.textMuted,
			TextSize = 12,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(0, cursorY),
			Size = UDim2.new(1, 0, 0, 32),
			ZIndex = 102,
			Parent = panel,
		})
		cursorY += 36
	end

	-- 드롭다운 콜백이 힌트를 갱신해야 해서 미리 선언해둔다.
	local refreshHint: (() -> ())? = nil

	local textBox: TextBox? = nil
	local inputOptions = options.Input
	if inputOptions then
		local box = Create("TextBox", {
			Name = "Input",
			Text = inputOptions.Default or "",
			PlaceholderText = inputOptions.Placeholder or "",
			ClearTextOnFocus = false,
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextColor3 = tokens.color.text,
			PlaceholderColor3 = tokens.color.textMuted,
			TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundColor3 = tokens.color.inputBackground,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, cursorY),
			Size = UDim2.new(1, 0, 0, 30),
			ZIndex = 102,
			Parent = panel,
		}, {
			Create.corner(4),
			Create.stroke(tokens.color.border),
			Create.padding(0, 8),
		})
		textBox = box
		cursorY += 38
	end

	--------------------------------------------------------------------------
	-- 드롭다운
	--------------------------------------------------------------------------

	-- 고른 값들. Validate/OnConfirm/Hint에 이 배열이 그대로 넘어간다.
	local selected: { string } = {}
	local selectMenus = {}

	local selects = options.Selects or {}

	-- 줄마다 보일지 말지가 다른 드롭다운 값에 따라 달라질 수 있어서
	-- (값 타입이 EnumItem일 때만 Enum 종류를 묻는 식) 위치를 나중에
	-- 다시 잡는다. 만들 때 쓰는 자리는 layout()이 곧바로 덮어쓴다.
	local selectRows = {}
	local selectsTop = cursorY
	local layout: (() -> ())? = nil
	for index, selectOptions in selects do
		selected[index] = selectOptions.Default or selectOptions.Options[1]

		local label = Create.label({
			Name = "SelectLabel",
			Text = selectOptions.Label,
			TextColor3 = tokens.color.textMuted,
			TextSize = 11,
			Position = UDim2.fromOffset(0, cursorY),
			Size = UDim2.fromOffset(SELECT_LABEL_WIDTH, SELECT_HEIGHT),
			ZIndex = 102,
			Parent = panel,
		})

		local slot = Create("Frame", {
			Name = "SelectSlot",
			BackgroundColor3 = tokens.color.inputBackground,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(SELECT_LABEL_WIDTH, cursorY),
			Size = UDim2.new(1, -SELECT_LABEL_WIDTH, 0, SELECT_HEIGHT),
			ZIndex = 102,
			Parent = panel,
		}, {
			Create.corner(4),
			Create.stroke(tokens.color.border),
			Create.padding(0, 4),
		})

		-- 모달 위에 떠야 하므로 ZIndex를 스크림보다 높게 준다.
		local menu
		menu = Menu.new({
			Text = selected[index],
			Overlay = overlay,
			ZIndex = 110,
			TextSize = 11,
			PaddingX = 6,
			Parent = slot,
			GetItems = function()
				local items = {}
				for _, option in selectOptions.Options do
					table.insert(items, {
						Text = option,
						Checked = option == selected[index],
						OnSelect = function()
							selected[index] = option
							menu:SetText(option)
							if layout then
								layout()
							end
							if refreshHint then
								refreshHint()
							end
						end,
					})
				end
				return items
			end,
		})
		table.insert(selectMenus, menu)
		selectRows[index] = { label = label, slot = slot, visibleWhen = selectOptions.VisibleWhen }

		cursorY += SELECT_HEIGHT + 6
	end

	local hintLabel: TextLabel? = nil
	if hasHint then
		hintLabel = Create.label({
			Name = "Hint",
			Text = "",
			TextColor3 = tokens.color.textMuted,
			TextSize = 11,
			Position = UDim2.fromOffset(0, cursorY),
			Size = UDim2.new(1, 0, 0, 14),
			ZIndex = 102,
			Parent = panel,
		})
		cursorY += 16
	end

	local errorLabel = Create.label({
		Name = "Error",
		Text = "",
		TextColor3 = tokens.color.danger,
		TextSize = 11,
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

	-- 세 번째 선택지는 같은 줄 왼쪽에 따로 놓는다.
	-- 오른쪽 목록과 섞이면 실수로 누르기 쉬운 자리에 놓이게 된다.
	local tertiaryRow = if options.Tertiary
		then Create("Frame", {
			Name = "TertiaryButton",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, cursorY),
			Size = UDim2.new(0, 200, 0, 28),
			ZIndex = 102,
			Parent = panel,
		}, {
			Create.list(Enum.FillDirection.Horizontal, 0, {
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
		})
		else nil

	-- 숨긴 줄은 자리도 차지하면 안 된다. 보이는 줄만 세어 아래 것들을
	-- 끌어올리고 창 높이도 같이 줄인다.
	local function doLayout()
		local y = selectsTop
		for _, row in selectRows do
			local visible = row.visibleWhen == nil or row.visibleWhen(selected)
			row.label.Visible = visible
			row.slot.Visible = visible
			if visible then
				row.label.Position = UDim2.fromOffset(0, y)
				row.slot.Position = UDim2.fromOffset(SELECT_LABEL_WIDTH, y)
				y += SELECT_HEIGHT + 6
			end
		end

		if hintLabel then
			hintLabel.Position = UDim2.fromOffset(0, y)
			y += 16
		end

		errorLabel.Position = UDim2.fromOffset(0, y)
		y += 20

		buttonRow.Position = UDim2.fromOffset(0, y)
		if tertiaryRow then
			tertiaryRow.Position = UDim2.fromOffset(0, y)
		end
		y += 28

		panel.Size = UDim2.fromOffset(panelWidth, y + 30)
	end

	layout = doLayout

	if selectCount > 0 then
		doLayout()
	end

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		root:Destroy()
	end

	local function cancel()
		close()
		if options.OnCancel then
			options.OnCancel()
		end
	end

	local function currentText(): string
		return if textBox then textBox.Text else ""
	end

	local hintFn = options.Hint
	if hintLabel and hintFn then
		local label = hintLabel
		local function update()
			label.Text = hintFn(currentText(), selected) or ""
		end
		refreshHint = update
		update()
	end

	local function confirm()
		local text = currentText()

		if options.Validate then
			local ok, reason = options.Validate(text, selected)
			if not ok then
				errorLabel.Text = reason or Locale.T("key.checkValue")
				return
			end
		end

		close()
		if options.OnConfirm then
			options.OnConfirm(text, selected)
		end
	end

	local buttons = {}

	local tertiary = options.Tertiary
	if tertiary and tertiaryRow then
		table.insert(
			buttons,
			Button.new({
				Text = tertiary.Text,
				Variant = tertiary.Variant or "muted",
				TextSize = 12,
				LayoutOrder = 1,
				OnClick = function()
					close()
					if tertiary.OnSelect then
						tertiary.OnSelect()
					end
				end,
				Parent = tertiaryRow,
			})
		)
	end

	if not options.HideCancel then
		table.insert(
			buttons,
			Button.new({
				Text = options.Cancel or "Cancel",
				Variant = "default",
				LayoutOrder = 1,
				OnClick = cancel,
				Parent = buttonRow,
			})
		)
	end

	table.insert(
		buttons,
		Button.new({
			Text = options.Confirm or "OK",
			Variant = options.ConfirmVariant or "primary",
			LayoutOrder = 2,
			OnClick = confirm,
			Parent = buttonRow,
		})
	)

	root.Destroying:Connect(function()
		for _, button in buttons do
			button:Destroy()
		end
		for _, menu in selectMenus do
			menu:Destroy()
		end
	end)

	scrimButton.Activated:Connect(cancel)

	if textBox then
		textBox.FocusLost:Connect(function(enterPressed)
			if enterPressed then
				confirm()
			end
		end)
		-- 입력을 고치면 이전 오류 문구를 지운다.
		textBox:GetPropertyChangedSignal("Text"):Connect(function()
			errorLabel.Text = ""
			if refreshHint then
				refreshHint()
			end
		end)
	end

	root.Parent = overlay

	if textBox then
		task.defer(function()
			if not closed then
				textBox:CaptureFocus()
			end
		end)
	end

	return { Close = close }
end

-- 예/아니오 확인용 단축 함수
function Dialog.confirm(overlay: Instance, title: string, message: string, confirmText: string, onConfirm: () -> ())
	return Dialog.show(overlay, {
		Title = title,
		Message = message,
		Confirm = confirmText,
		ConfirmVariant = "danger",
		OnConfirm = function()
			onConfirm()
		end,
	})
end

return Dialog
