--!nonstrict
-- 고른 키프레임 바로 아래에 뜨는 작은 편집 바.
--
--        ◆
--   ┌──────────────────────────┐
--   │ [━━━━●━━━━━━━━] [0.35]   │   0~1 범위를 아는 속성
--   └──────────────────────────┘
--
-- 범위를 아는 속성(PropertySpec)은 슬라이더, 그냥 숫자는 입력칸,
-- 참/거짓은 토글로 나온다. 그 밖의 타입은 이 바가 안 뜨고
-- 우클릭 → Edit Keyframe 으로 고친다.

local Component = require(script.Parent.Parent.Component)
local Create = require(script.Parent.Parent.Create)
local Drag = require(script.Parent.Parent.Drag)
local Menu = require(script.Parent.Parent.Components.Menu)
local Theme = require(script.Parent.Parent.Theme)

local Ops = require(script.Parent.Parent.Parent.Core.Ops)
local Schema = require(script.Parent.Parent.Parent.Core.Schema)
local Value = require(script.Parent.Parent.Parent.Core.Value)
local PropertySpec = require(script.Parent.Parent.Parent.Core.PropertySpec)
local Locale = require(script.Parent.Parent.Parent.Core.Locale)

local QuickEdit = Component.extend()

local HEIGHT = 26
local SLIDER_WIDTH = 140
local BOX_WIDTH = 62
local TOGGLE_WIDTH = 52
local MINMAX_WIDTH = 30
local MINMAX_GAP = 4
local ENUM_WIDTH = 150
local HANDLE_SIZE = 11
local HANDLE_HIT = 20 -- 보이는 크기보다 넓게 잡아야 놓치지 않는다
local PADDING = 6
local GAP = 6
local ZINDEX = 40

function QuickEdit.new(props)
	local self = Component.construct(QuickEdit)

	self._state = props.State
	self._project = props.State.Project
	self._widget = props.Widget
	self._overlay = props.Overlay
	self._getAnchor = props.GetAnchor

	-- 슬라이더를 끄는 동안 들고 있는 값. 놓을 때 한 번만 커밋한다.
	self._pending = nil
	self._dragStop = nil

	-- 이 바는 고른 키의 일부다. 여기를 눌렀다고 선택이 풀리면 안 되므로
	-- 클릭이 밑으로 새지 않아야 한다. Frame은 못 삼키니 버튼으로 만든다.
	local root = Create("TextButton", {
		Name = "QuickEdit",
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(200, HEIGHT),
		Visible = false,
		ZIndex = ZINDEX,
		Parent = props.Overlay,
	}, {
		Create.corner(4),
		Create.padding(0, PADDING),
	})
	self.Instance = root

	self._stroke = Create.stroke(Color3.new())
	self._stroke.Parent = root

	--------------------------------------------------------------------------
	-- 슬라이더
	--------------------------------------------------------------------------

	-- 슬라이더 양 끝에 범위를 적어준다. 0~1인지 0~500인지 알아야 감이 온다.
	self._minLabel = Create.label({
		Name = "Min",
		Text = "",
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(0, MINMAX_WIDTH, 1, 0),
		Visible = false,
		ZIndex = ZINDEX + 1,
		Parent = root,
	})

	self._maxLabel = Create.label({
		Name = "Max",
		Text = "",
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(0, MINMAX_WIDTH, 1, 0),
		Visible = false,
		ZIndex = ZINDEX + 1,
		Parent = root,
	})

	self._sliderTrack = Create("TextButton", {
		Name = "SliderTrack",
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, MINMAX_WIDTH + MINMAX_GAP, 0.5, 0),
		Size = UDim2.fromOffset(SLIDER_WIDTH, 4),
		Visible = false,
		ZIndex = ZINDEX + 1,
		Parent = root,
	}, {
		Create.corner(2),
	})

	self._sliderFill = Create("Frame", {
		Name = "Fill",
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		ZIndex = ZINDEX + 2,
		Parent = self._sliderTrack,
	}, {
		Create.corner(2),
	})

	-- 손잡이는 눈에 보이는 동그라미보다 잡히는 범위가 넓어야 한다.
	-- 막대는 4px뿐이고 동그라미는 그 위아래로 삐져나와 있는데, 동그라미가
	-- Frame이면 삐져나온 부분을 눌러도 클릭이 뒤로 새어나가 아무 일도 없다.
	-- 버튼으로 만들어 두면 동그라미 언저리를 눌러도 바로 끌리기 시작한다.
	self._sliderHandle = Create("TextButton", {
		Name = "Handle",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(HANDLE_HIT, HANDLE_HIT),
		ZIndex = ZINDEX + 3,
		Parent = self._sliderTrack,
	})

	self._sliderDot = Create("Frame", {
		Name = "Dot",
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(HANDLE_SIZE, HANDLE_SIZE),
		ZIndex = ZINDEX + 4,
		Parent = self._sliderHandle,
	}, {
		Create.corner(HANDLE_SIZE), -- 반지름은 크기의 절반으로 알아서 잘린다
	})

	--------------------------------------------------------------------------
	-- 값 입력칸
	--------------------------------------------------------------------------

	self._box = Create("TextBox", {
		Name = "Value",
		Text = "",
		ClearTextOnFocus = false,
		Font = Enum.Font.Code,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Center,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(BOX_WIDTH, 18),
		Visible = false,
		ZIndex = ZINDEX + 1,
		Parent = root,
	}, {
		Create.corner(3),
		Create.padding(0, 4),
	})

	--------------------------------------------------------------------------
	-- 참 / 거짓 토글
	--------------------------------------------------------------------------

	self._toggle = Create("TextButton", {
		Name = "Toggle",
		Text = "",
		Font = Enum.Font.Code,
		TextSize = 11,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(TOGGLE_WIDTH, 18),
		Visible = false,
		ZIndex = ZINDEX + 1,
		Parent = root,
	}, {
		Create.corner(3),
	})

	--------------------------------------------------------------------------
	-- Enum 고르기
	--------------------------------------------------------------------------

	self._enumSlot = Create("Frame", {
		Name = "EnumSlot",
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(ENUM_WIDTH, 18),
		Visible = false,
		ZIndex = ZINDEX + 1,
		Parent = root,
	}, {
		Create.corner(3),
		Create.padding(0, 4),
	})

	self._enumMenu = Menu.new({
		Text = "",
		Overlay = props.Overlay,
		-- 편집 바보다 위에 떠야 한다.
		ZIndex = ZINDEX + 20,
		TextSize = 11,
		PaddingX = 4,
		Parent = self._enumSlot,
		GetItems = function()
			return self:_enumItems()
		end,
	})
	self:Track(self._enumMenu)

	self:BindTheme(function(tokens)
		self:_applyTheme(tokens)
	end)

	self:Track(self._state.FrameSelectionChanged:Connect(function()
		self:Update()
	end))

	self:Track(function()
		self:_stopDrag()
	end)

	self:_wire()
	self:Update()

	return self
end

function QuickEdit:_applyTheme(tokens)
	self.Instance.BackgroundColor3 = tokens.color.panel
	self._stroke.Color = tokens.color.border

	self._sliderTrack.BackgroundColor3 = tokens.color.inputBackground
	self._sliderFill.BackgroundColor3 = tokens.color.accent
	self._sliderDot.BackgroundColor3 = tokens.color.accent

	self._minLabel.TextColor3 = tokens.color.textMuted
	self._maxLabel.TextColor3 = tokens.color.textMuted

	self._box.BackgroundColor3 = tokens.color.inputBackground
	self._box.TextColor3 = tokens.color.text
	-- 현재 값은 Placeholder로 보여준다. 그래야 칸을 비우지 않고 바로 덧쓸 수 있다.
	-- 흐리게 나오면 값이 아니라 안내처럼 보이므로 본문과 같은 색을 쓴다.
	self._box.PlaceholderColor3 = tokens.color.text

	self._toggle.BackgroundColor3 = tokens.color.inputBackground
	self._toggle.TextColor3 = tokens.color.text

	self._enumSlot.BackgroundColor3 = tokens.color.inputBackground
end

--------------------------------------------------------------------------------
-- 현재 대상
--------------------------------------------------------------------------------

-- 이 키를 이 바로 고칠 수 있는지 판단하고, 어떻게 그릴지 정한다.
function QuickEdit:_resolve()
	local frame = self._state:GetSelectedFrame()
	if not frame then
		return nil
	end

	local key, track = self._state:ResolveSelectedFrame()
	if not key or not track then
		return nil
	end

	-- 메소드 트랙은 값이 아니라 인자라서 여기서 다루지 않는다.
	if track.kind == Schema.TRACK_KIND.METHOD then
		return nil
	end

	local valueType = track.valueType
	if valueType == "boolean" then
		return { frame = frame, key = key, track = track, kind = "boolean" }
	end

	-- Enum은 목록에서 고르는 게 낫다. 이름을 외워서 칠 이유가 없다.
	if valueType == "EnumItem" and track.enumType then
		return { frame = frame, key = key, track = track, kind = "enum" }
	end

	if valueType ~= "number" then
		return nil
	end

	local instance = self._state:ResolveInstance(frame.itemId, frame.path)
	local spec = PropertySpec.find(instance, track.target)

	return {
		frame = frame,
		key = key,
		track = track,
		kind = if spec then "slider" else "number",
		spec = spec,
	}
end

function QuickEdit:_currentValue(context)
	if self._pending ~= nil then
		return self._pending
	end
	return Value.decode(context.track.valueType, context.key.v)
end

--------------------------------------------------------------------------------
-- 그리기
--------------------------------------------------------------------------------

function QuickEdit:Update()
	local context = self:_resolve()
	if not context then
		self.Instance.Visible = false
		return
	end

	local x, y = self._getAnchor()
	if not x then
		self.Instance.Visible = false
		return
	end

	local width = PADDING * 2
	if context.kind == "slider" then
		width += MINMAX_WIDTH + MINMAX_GAP + SLIDER_WIDTH + MINMAX_GAP + MINMAX_WIDTH + GAP + BOX_WIDTH
	elseif context.kind == "number" then
		width += BOX_WIDTH + 24
	elseif context.kind == "enum" then
		width += ENUM_WIDTH + 12
	else
		width += TOGGLE_WIDTH + 12
	end

	-- 좌우로 잘리지 않게 오버레이 안으로 밀어 넣는다.
	local overlayWidth = self._overlay.AbsoluteSize.X
	local half = width / 2
	local clampedX = math.clamp(x, half, math.max(overlayWidth - half, half))

	self.Instance.Size = UDim2.fromOffset(width, HEIGHT)
	self.Instance.Position = UDim2.fromOffset(math.floor(clampedX), math.floor(y) + 4)
	self.Instance.Visible = true

	local isSlider = context.kind == "slider"
	self._sliderTrack.Visible = isSlider
	self._minLabel.Visible = isSlider
	self._maxLabel.Visible = isSlider
	self._box.Visible = context.kind == "slider" or context.kind == "number"
	self._toggle.Visible = context.kind == "boolean"
	self._enumSlot.Visible = context.kind == "enum"

	local current = self:_currentValue(context)

	if context.kind == "boolean" then
		self._toggle.Text = if current then "true" else "false"
		self._toggle.TextColor3 = if current then Theme.Get().color.accent else Theme.Get().color.textMuted
		return
	end

	if context.kind == "enum" then
		-- "Enum.Material.Neon"에서 항목 이름만 보여준다. 칸이 좁다.
		self._enumMenu:SetText(if current then current.Name else Locale.T("common.none"))
		return
	end

	if isSlider then
		local spec = context.spec
		self._minLabel.Text = Value.format("number", spec.min)
		self._maxLabel.Text = Value.format("number", spec.max)
		self._maxLabel.Position = UDim2.fromOffset(MINMAX_WIDTH + MINMAX_GAP + SLIDER_WIDTH + MINMAX_GAP, 0)

		-- 범위 밖 값이면 손잡이는 끝에 붙어있고 숫자만 그 값을 보여준다.
		local alpha = PropertySpec.toAlpha(spec, current)
		self._sliderFill.Size = UDim2.fromScale(alpha, 1)
		self._sliderHandle.Position = UDim2.fromScale(alpha, 0.5)
	end

	-- 현재 값은 Text가 아니라 Placeholder로 띄운다. 칸이 비어있으니
	-- 지우지 않고 바로 새 값을 칠 수 있다.
	self._box.PlaceholderText = Value.format(context.track.valueType, current)
	if not self._box:IsFocused() then
		self._box.Text = ""
	end
end

--------------------------------------------------------------------------------
-- 쓰기
--------------------------------------------------------------------------------

function QuickEdit:_commit(context, value)
	local encoded = Value.encode(context.track.valueType, value)
	local frame = context.frame
	self._project:Commit(Locale.T("undo.setKeyValue"), function(doc)
		Ops.setKeyValue(doc, frame.itemId, frame.path, frame.target, frame.t, encoded)
	end)
end

-- 이 Enum의 항목 전부. 지금 값에 체크가 붙는다.
function QuickEdit:_enumItems()
	local context = self:_resolve()
	if not context or context.kind ~= "enum" then
		return {}
	end

	local current = self:_currentValue(context)
	local items = {}

	for _, item in Value.enumItems(context.track.enumType) do
		table.insert(items, {
			Text = item.Name,
			Checked = current ~= nil and current == item,
			OnSelect = function()
				self:_commit(context, item)
				self:Update()
			end,
		})
	end

	return items
end

function QuickEdit:_stopDrag()
	local stop = self._dragStop
	if stop then
		self._dragStop = nil
		stop()
	end
end

function QuickEdit:_wire()
	--------------------------------------------------------------------------
	-- 슬라이더 끌기
	--------------------------------------------------------------------------

	local function alphaFromMouse(mouse: Vector2): number
		local left = self._sliderTrack.AbsolutePosition.X
		local width = math.max(self._sliderTrack.AbsoluteSize.X, 1)
		return math.clamp((mouse.X - left) / width, 0, 1)
	end

	local function beginSliderDrag(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end

		local context = self:_resolve()
		if not context or context.kind ~= "slider" then
			return
		end

		-- 끄는 동안에는 화면만 바꾸고, 놓을 때 한 번만 커밋한다.
		-- 매 프레임 커밋하면 Undo 스택이 프레임 수만큼 쌓인다.
		self._dragStop = Drag.begin(self._widget, self._overlay, function(mouse)
			self._pending = PropertySpec.fromAlpha(context.spec, alphaFromMouse(mouse))
			self:Update()
		end, function()
			self._dragStop = nil
			local value = self._pending
			self._pending = nil
			if value ~= nil then
				self:_commit(context, value)
			end
			self:Update()
		end)
	end

	-- 막대와 손잡이 둘 다에서 끌기를 시작할 수 있다.
	self:Track(self._sliderTrack.InputBegan:Connect(beginSliderDrag))
	self:Track(self._sliderHandle.InputBegan:Connect(beginSliderDrag))

	--------------------------------------------------------------------------
	-- 값 입력칸
	--------------------------------------------------------------------------

	self:Track(self._box.FocusLost:Connect(function()
		local text = self._box.Text
		self._box.Text = ""

		local context = self:_resolve()
		if not context then
			return
		end

		-- 아무것도 안 치고 나갔으면 그대로 둔다.
		if text:match("^%s*$") then
			self:Update()
			return
		end

		local ok, parsed = Value.parse(context.track.valueType, text, context.track.enumType)
		if not ok then
			self:Update()
			return
		end

		-- 슬라이더 범위 밖이어도 그대로 넣는다. 범위는 어디까지나 손으로
		-- 끌 때의 눈금이지, 속성이 거기까지만 된다는 뜻은 아니다.
		self:_commit(context, parsed)
		self:Update()
	end))

	--------------------------------------------------------------------------
	-- 참 / 거짓 토글
	--------------------------------------------------------------------------

	--------------------------------------------------------------------------
	-- Enum 고르기
	--------------------------------------------------------------------------

	self:Track(self._enumSlot:GetPropertyChangedSignal("Visible"):Connect(function()
		if not self._enumSlot.Visible then
			self._enumMenu:Close()
		end
	end))

	--------------------------------------------------------------------------
	-- 참 / 거짓 토글
	--------------------------------------------------------------------------

	self:Track(self._toggle.Activated:Connect(function()
		local context = self:_resolve()
		if not context or context.kind ~= "boolean" then
			return
		end
		self:_commit(context, not self:_currentValue(context))
		self:Update()
	end))
end

return QuickEdit
