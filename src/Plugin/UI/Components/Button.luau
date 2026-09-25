--!nonstrict
-- 텍스트 버튼. variant로 색만 갈아끼운다.

local Component = require(script.Parent.Parent.Component)
local Create = require(script.Parent.Parent.Create)
local Theme = require(script.Parent.Parent.Theme)

local Button = Component.extend()

export type Props = {
	Text: string,
	Variant: string?, -- "default" | "primary" | "ghost" | "danger"
	Size: UDim2?,
	AutomaticSize: Enum.AutomaticSize?,
	TextSize: number?,
	LayoutOrder: number?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Parent: Instance?,
	OnClick: (() -> ())?,
}

local function palette(tokens, variant: string)
	local c = tokens.color
	if variant == "primary" then
		return c.accent, c.accentHover, c.accentPressed, c.textOnAccent
	elseif variant == "danger" then
		return c.danger, c.dangerHover, c.danger, c.textOnAccent
	elseif variant == "ghost" then
		return c.panel, c.buttonHover, c.buttonPressed, c.text
	elseif variant == "muted" then
		-- 눈에 덜 띄어야 하는 선택지 (예: 저장하지 않고 닫기)
		return c.panel, c.buttonHover, c.buttonPressed, c.textMuted
	end
	return c.buttonBackground, c.buttonHover, c.buttonPressed, c.text
end

-- 배경 없이 글자만 있다가 호버할 때만 칠해지는 변형들
local FLAT_VARIANTS = { ghost = true, muted = true }

function Button.new(props: Props)
	local self = Component.construct(Button)

	self._variant = props.Variant or "default"
	self._enabled = true
	self._hovered = false
	self._pressed = false

	local button = Create("TextButton", {
		Name = "Button",
		Text = props.Text,
		Font = Enum.Font.GothamMedium,
		TextSize = props.TextSize or 13,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Size = props.Size or UDim2.new(0, 0, 0, 26),
		AutomaticSize = props.AutomaticSize or Enum.AutomaticSize.X,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder or 0,
	}, {
		Create.corner(4),
		Create.padding(0, 12),
	})

	self.Instance = button
	self._stroke = Create.stroke(Color3.new(), 1)
	self._stroke.Transparency = 1
	self._stroke.Parent = button

	self:BindTheme(function()
		self:_refresh()
	end)

	self:Track(button.MouseEnter:Connect(function()
		self._hovered = true
		self:_refresh()
	end))
	self:Track(button.MouseLeave:Connect(function()
		self._hovered = false
		self._pressed = false
		self:_refresh()
	end))
	self:Track(button.MouseButton1Down:Connect(function()
		self._pressed = true
		self:_refresh()
	end))
	self:Track(button.MouseButton1Up:Connect(function()
		self._pressed = false
		self:_refresh()
	end))

	if props.OnClick then
		self:Track(button.Activated:Connect(function()
			if self._enabled then
				props.OnClick()
			end
		end))
	end

	if props.Parent then
		button.Parent = props.Parent
	end

	return self
end

function Button:_refresh()
	local tokens = Theme.Get()
	local base, hover, pressed, textColor = palette(tokens, self._variant)

	local background = base
	if not self._enabled then
		background = tokens.color.buttonBackground
	elseif self._pressed then
		background = pressed
	elseif self._hovered then
		background = hover
	end

	local button = self.Instance
	button.BackgroundColor3 = background
	button.TextColor3 = if self._enabled then textColor else tokens.color.textMuted
	button.BackgroundTransparency = if FLAT_VARIANTS[self._variant] and not self._hovered then 1 else 0

	-- ghost는 테두리로만 존재를 표시한다.
	self._stroke.Color = tokens.color.border
	self._stroke.Transparency = if self._variant == "default" then 0 else 1
end

function Button:SetText(text: string)
	self.Instance.Text = text
end

function Button:SetEnabled(enabled: boolean)
	self._enabled = enabled
	self.Instance.Active = enabled
	self.Instance.AutoButtonColor = false
	self:_refresh()
end

return Button
