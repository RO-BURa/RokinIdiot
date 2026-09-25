--!nonstrict
-- 키프레임 사이를 어떻게 이을지.
--
-- 이름은 TweenService의 EasingStyle을 그대로 쓰되 두 개를 더 둔다.
--   Linear    곧게 이음 (기본)
--   Constant  잇지 않고 다음 키에 닿을 때까지 앞 키 값을 유지 (뚝뚝 끊김)
--
-- 실제 곡선은 TweenService:GetValue로 빌려온다. 우리가 직접 계산하지 않으니
-- 스튜디오에서 본 감각과 게임에서의 결과가 갈라질 일이 없다.

local TweenService = game:GetService("TweenService")

local Locale = require(script.Parent.Locale)

local Easing = {}

Easing.LINEAR = "Linear"
Easing.CONSTANT = "Constant"

-- 목록 순서가 곧 드롭다운 순서다.
Easing.STYLES = {
	"Linear",
	"Constant",
	"Sine",
	"Quad",
	"Cubic",
	"Quart",
	"Quint",
	"Back",
	"Bounce",
	"Elastic",
	"Exponential",
	"Circular",
}

Easing.DIRECTIONS = { "In", "Out", "InOut" }

-- 방향을 고르는 게 의미 있는 스타일인가.
function Easing.hasDirection(style: string?): boolean
	return style ~= nil and style ~= Easing.LINEAR and style ~= Easing.CONSTANT
end

function Easing.isConstant(ease: { string }?): boolean
	return ease ~= nil and ease[1] == Easing.CONSTANT
end

function Easing.describe(style: string?): string
	if style == Easing.CONSTANT then
		return Locale.T("easing.constant")
	end
	if style == Easing.LINEAR or style == nil then
		return Locale.T("easing.linear")
	end
	return ""
end

-- 두 키 사이의 진행도(0~1)에 이징을 입힌다.
-- Constant는 0을 돌려주므로 보간하면 앞 키 값이 그대로 남는다.
function Easing.apply(ease: { string }?, alpha: number): number
	if not ease then
		return alpha
	end

	local style = ease[1]
	if style == Easing.CONSTANT then
		return 0
	end
	if style == nil or style == Easing.LINEAR then
		return alpha
	end

	local ok, eased = pcall(function()
		return TweenService:GetValue(alpha, Enum.EasingStyle[style], Enum.EasingDirection[ease[2] or "InOut"])
	end)
	if not ok then
		return alpha
	end
	return eased
end

return Easing
