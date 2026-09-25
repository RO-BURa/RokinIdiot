--!nonstrict
-- 인스턴스 생성 헬퍼.
--   local frame = Create("Frame", { Size = UDim2.fromScale(1, 1) }, {
--       Create.list(Enum.FillDirection.Vertical, 4),
--   })
-- Parent는 자식이 다 붙은 뒤 마지막에 설정한다 (렌더 리플로우 1회).

local function build(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent: Instance? = nil

	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				instance[key] = value
			end
		end
	end

	if children then
		for _, child in children do
			child.Parent = instance
		end
	end

	if parent then
		instance.Parent = parent
	end

	return instance
end

local Create = setmetatable({}, {
	__call = function(_, className: string, props: { [string]: any }?, children: { Instance }?)
		return build(className, props, children)
	end,
})

--------------------------------------------------------------------------------
-- 자주 쓰는 조합
--------------------------------------------------------------------------------

function Create.corner(radius: number): UICorner
	return build("UICorner", { CornerRadius = UDim.new(0, radius) })
end

-- Create.padding(8) / Create.padding(8, 12) / Create.padding(top, right, bottom, left)
function Create.padding(top: number, right: number?, bottom: number?, left: number?): UIPadding
	local r = right or top
	local b = bottom or top
	local l = left or r
	return build("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, r),
		PaddingBottom = UDim.new(0, b),
		PaddingLeft = UDim.new(0, l),
	})
end

function Create.list(direction: Enum.FillDirection, padding: number, extra: { [string]: any }?): UIListLayout
	local props = {
		FillDirection = direction,
		Padding = UDim.new(0, padding),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	}
	if extra then
		for key, value in extra do
			props[key] = value
		end
	end
	return build("UIListLayout", props)
end

function Create.stroke(color: Color3, thickness: number?): UIStroke
	return build("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		-- 기본값 Round는 모서리를 둥글려서 각진 테두리가 뭉개진다.
		LineJoinMode = Enum.LineJoinMode.Miter,
	})
end

-- 텍스트 라벨 기본값 (배경 없음, 왼쪽 정렬)
function Create.label(props: { [string]: any }?): TextLabel
	local merged = {
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		RichText = false,
	}
	if props then
		for key, value in props do
			merged[key] = value
		end
	end
	return build("TextLabel", merged)
end

return Create
