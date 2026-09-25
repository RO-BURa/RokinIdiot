--!strict
-- 사용자가 직접 입력하는 두 가지 문자열을 다룬다.
--
--   경로   ".HumanoidRootPart.RootAttachment.MainParticle"  (아이템 루트 기준)
--   타겟   ":Emit()" 또는 "Enabled"
--
-- 타겟 판정 규칙: ":" 로 시작하면 메소드, 아니면 속성.
-- 표기 안에 적은 인자는 무시된다. 인자는 키프레임마다 따로 들어간다.

local Locale = require(script.Parent.Locale)

local PathSpec = {}

--------------------------------------------------------------------------------
-- 경로
--------------------------------------------------------------------------------

-- 앞뒤 공백과 점을 떼어낸다. ".A.B." 도 "A.B" 로 받아준다.
function PathSpec.normalizePath(text: string): string
	local trimmed = text:match("^%s*(.-)%s*$") or ""
	trimmed = trimmed:gsub("^%.+", "")
	trimmed = trimmed:gsub("%.+$", "")
	return trimmed
end

function PathSpec.split(path: string): { string }
	local segments = {}
	for segment in string.gmatch(path, "[^%.]+") do
		table.insert(segments, segment)
	end
	return segments
end

-- 빈 경로는 아이템 루트 자신을 뜻하므로 유효하다.
function PathSpec.validatePath(text: string): (boolean, string?)
	local path = PathSpec.normalizePath(text)
	if path:find("%.%.") then
		return false, Locale.T("path.doubleDot")
	end
	if #path > 300 then
		return false, Locale.T("path.tooLong")
	end
	return true, nil
end

-- 루트에서 경로를 따라간다. 끊기면 어느 이름에서 끊겼는지 같이 돌려준다.
function PathSpec.resolve(root: Instance?, path: string): (Instance?, string?)
	if not root then
		return nil, nil
	end

	local current: Instance = root
	for _, segment in PathSpec.split(path) do
		local child = current:FindFirstChild(segment)
		if not child then
			return nil, segment
		end
		current = child
	end
	return current, nil
end

-- 트리에 보여줄 짧은 이름. 경로의 마지막 조각만 쓴다.
function PathSpec.leafName(path: string): string
	local segments = PathSpec.split(path)
	if #segments == 0 then
		return Locale.T("common.root")
	end
	return segments[#segments]
end

--------------------------------------------------------------------------------
-- 타겟
--------------------------------------------------------------------------------

export type Target = {
	kind: string, -- "property" | "method"
	target: string,
}

function PathSpec.parseTarget(text: string): (Target?, string?)
	local trimmed = text:match("^%s*(.-)%s*$") or ""
	if trimmed == "" then
		return nil, Locale.T("path.targetEmpty")
	end

	if trimmed:sub(1, 1) == ":" then
		-- ":" 다음부터 "(" 전까지가 메소드 이름이다. ":Emit" 처럼 괄호가 없어도 받는다.
		local name = trimmed:sub(2):match("^([%a_][%w_]*)")
		if not name then
			return nil, Locale.T("path.badMethod")
		end
		return { kind = "method", target = name }, nil
	end

	local name = trimmed:match("^([%a_][%w_]*)$")
	if not name then
		return nil, Locale.T("path.badProperty")
	end
	return { kind = "property", target = name }, nil
end

-- 트리에 다시 그릴 때 쓰는 표기
function PathSpec.formatTarget(kind: string, target: string): string
	if kind == "method" then
		return ":" .. target .. "()"
	end
	return target
end

--------------------------------------------------------------------------------
-- 값 타입 추론
--------------------------------------------------------------------------------

-- 값 타입 선택지. (Auto)는 바인딩된 인스턴스의 현재 값에서 알아낸다는 뜻이다.
PathSpec.AUTO_TYPE = "(Auto)"

-- Enum 종류 고르기에서 "알아서" 를 뜻하는 값.
PathSpec.AUTO_ENUM = "(Auto)"

-- 스튜디오가 가진 모든 Enum 이름. Enum 값을 직접 고를 때 쓴다.
function PathSpec.enumNames(): { string }
	local names = { PathSpec.AUTO_ENUM }

	local ok, enums = pcall(function()
		return Enum:GetEnums()
	end)
	if not ok then
		return names
	end

	local sorted = {}
	for _, item in enums do
		table.insert(sorted, tostring(item))
	end
	table.sort(sorted)

	for _, name in sorted do
		table.insert(names, name)
	end
	return names
end

PathSpec.VALUE_TYPES = {
	PathSpec.AUTO_TYPE,
	"number",
	"boolean",
	"string",
	"Color3",
	"Vector3",
	"Vector2",
	"UDim",
	"UDim2",
	"CFrame",
	"NumberRange",
	"ColorSequence",
	"NumberSequence",
	"BrickColor",
	"EnumItem",
	"Instance",
}

local SUPPORTED_TYPES = {}
for _, valueType in PathSpec.VALUE_TYPES do
	if valueType ~= PathSpec.AUTO_TYPE then
		SUPPORTED_TYPES[valueType] = true
	end
end

-- 바인딩된 인스턴스에서 현재 값을 읽어 타입을 알아낸다.
-- 바인딩이 없거나 속성이 없으면 nil을 돌려주고, 호출한 쪽에서 기본값을 정한다.
function PathSpec.inferValueType(instance: Instance?, property: string): string?
	if not instance then
		return nil
	end

	local ok, value = pcall(function()
		return (instance :: any)[property]
	end)
	if not ok then
		return nil
	end

	local valueType = typeof(value)
	if SUPPORTED_TYPES[valueType] then
		return valueType
	end
	return nil
end

-- 지금 값이 EnumItem이면 어느 Enum인지 알아낸다. 아니면 nil.
function PathSpec.inferEnumType(instance: Instance?, property: string): string?
	if not instance then
		return nil
	end

	local ok, value = pcall(function()
		return (instance :: any)[property]
	end)
	if not ok or typeof(value) ~= "EnumItem" then
		return nil
	end
	return tostring(value.EnumType)
end

function PathSpec.isSupportedValueType(valueType: string): boolean
	return SUPPORTED_TYPES[valueType] == true
end

--------------------------------------------------------------------------------
-- Instance 값 참조
--------------------------------------------------------------------------------

-- 인스턴스를 값으로 갖는 속성(Adornee, PrimaryPart, Attachment0 ...)은
-- 절대 경로로 저장할 수 없다. 게임에서는 매번 다른 인스턴스가 들어오기 때문이다.
--
-- 그래서 아이템 번호를 기준으로 적는다. 아이템 대입 규칙을 그대로 재사용한다.
--
--   nil 또는 빈 칸   → 값 없음
--   [2]              → 2번 아이템 자신
--   [2].Handle.Tip   → 2번 아이템 아래 경로
--
-- 실제 인스턴스로 바꾸는 건 미리보기와 런타임이 PlayAnimation에 넘어온
-- 대입 테이블을 들고 resolveInstanceRef를 부를 때 일어난다.

export type InstanceRef = {
	itemId: number,
	path: string,
}

-- (성공 여부, 참조 또는 nil, 실패 이유)
-- 빈 칸은 "값 없음"이라 성공이면서 참조가 nil이다.
function PathSpec.parseInstanceRef(text: string): (boolean, InstanceRef?, string?)
	local trimmed = text:match("^%s*(.-)%s*$") or ""
	if trimmed == "" or trimmed:lower() == "nil" then
		return true, nil, nil
	end

	local idText, rest = trimmed:match("^%[(%d+)%]%s*(.*)$")
	if not idText then
		return false, nil, Locale.T("path.refStart")
	end

	local itemId = tonumber(idText)
	if not itemId or itemId < 1 then
		return false, nil, Locale.T("path.badItemId")
	end

	local path = PathSpec.normalizePath(rest or "")
	local ok, reason = PathSpec.validatePath(path)
	if not ok then
		return false, nil, reason
	end

	return true, { itemId = itemId, path = path }, nil
end

function PathSpec.formatInstanceRef(ref: InstanceRef?): string
	if not ref then
		return "nil"
	end
	if ref.path == "" then
		return string.format("[%d]", ref.itemId)
	end
	return string.format("[%d].%s", ref.itemId, ref.path)
end

-- itemInstances는 아이템 번호 → 실제 인스턴스. 미리보기 바인딩이나
-- PlayAnimation에 넘어온 대입 테이블이 그대로 들어온다.
function PathSpec.resolveInstanceRef(ref: InstanceRef?, itemInstances: { [number]: Instance }): Instance?
	if not ref then
		return nil
	end

	local root = itemInstances[ref.itemId]
	if not root then
		return nil
	end

	local resolved = PathSpec.resolve(root, ref.path)
	return resolved
end

return PathSpec
