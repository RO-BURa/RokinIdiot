--!nonstrict
-- 사용자가 한 줄에 적는 값 하나를 읽는다.
--
-- 속성 값은 트랙이 타입을 알고 있어서 그냥 Value.parse로 충분하다. 그런데
-- 메소드 인자는 칸마다 타입이 다를 수 있고 알려줄 사람도 없다. 그래서
-- 적은 글에서 타입을 알아내야 한다.
--
--   25                     number
--   true / false           boolean
--   nil                    없음 (인자 자리를 비운다)
--   "asdf"                 문자열
--   Vector3(1, 2, 3)       그 타입으로 읽는다
--   Color3(255, 0, 0)
--   Enum.Material.Neon     EnumItem
--   [2].Handle.Tip         아이템 2번 아래의 인스턴스
--   asdf                   따옴표를 잊었을 때도 문자열로 봐준다
--
-- 읽은 결과는 타입을 달고 있는 상자다.
--
--   { t = "Vector3", v = { 1, 2, 3 } }
--   { t = "nil" }
--
-- 상자로 담는 이유는 저장이 JSON이기 때문이다. 배열 한가운데를 nil로 비우면
-- 길이를 믿을 수 없게 되어 뒤의 인자가 통째로 사라진다. 모든 칸이 표면
-- 구멍이 생기지 않는다.

local Value = require(script.Parent.Value)
local PathSpec = require(script.Parent.PathSpec)
local Locale = require(script.Parent.Locale)

local Literal = {}

Literal.NIL = "nil"

local function trim(text: string): string
	return text:match("^%s*(.-)%s*$") or ""
end

-- Vector3(...) 처럼 이름을 앞에 붙여 쓸 수 있는 타입들.
local named: { [string]: boolean } = {}
for _, valueType in PathSpec.VALUE_TYPES do
	if valueType ~= PathSpec.AUTO_TYPE then
		named[valueType] = true
	end
end

--------------------------------------------------------------------------------
-- 읽기
--------------------------------------------------------------------------------

-- (성공 여부, 상자, 실패 이유)
function Literal.parse(text: string): (boolean, any, string?)
	local token = trim(text)

	if token == "" or token == Literal.NIL then
		return true, { t = Literal.NIL }, nil
	end

	if token == "true" or token == "false" then
		return true, { t = "boolean", v = token == "true" }, nil
	end

	local number = tonumber(token)
	if number then
		return true, { t = "number", v = number }, nil
	end

	-- 따옴표로 감싼 건 무조건 문자열이다. 25나 true를 글자로 넣고 싶을 때 쓴다.
	local quoted = token:match('^"(.*)"$') or token:match("^'(.*)'$")
	if quoted then
		return true, { t = "string", v = quoted }, nil
	end

	-- Enum.Material.Neon
	if token:match("^Enum%.") then
		local ok, parsed, reason = Value.parse("EnumItem", (token:gsub("^Enum%.", "")))
		if not ok then
			return false, nil, reason
		end
		return true, { t = "EnumItem", v = Value.encode("EnumItem", parsed) }, nil
	end

	-- [2].Handle.Tip
	if token:match("^%[") then
		local ok, parsed, reason = Value.parse("Instance", token)
		if not ok then
			return false, nil, reason
		end
		return true, { t = "Instance", v = Value.encode("Instance", parsed) }, nil
	end

	-- Vector3(1, 2, 3)
	local typeName, inner = token:match("^([%a%d]+)%s*%((.*)%)$")
	if typeName then
		if not named[typeName] then
			return false, nil, Locale.T("literal.unknownType", typeName)
		end
		local ok, parsed, reason = Value.parse(typeName, inner)
		if not ok then
			return false, nil, reason
		end
		return true, { t = typeName, v = Value.encode(typeName, parsed) }, nil
	end

	-- 남은 건 따옴표를 잊은 문자열로 본다. 인자로 이름을 넘기는 일이 흔해서
	-- 매번 따옴표를 강요하면 성가시기만 하다.
	return true, { t = "string", v = token }, nil
end

-- 쉼표로 나눠 여러 개를 읽는다. 괄호 안의 쉼표는 세지 않는다.
-- (성공 여부, 상자 목록, 실패 이유)
function Literal.parseList(text: string): (boolean, { any }, string?)
	local boxes = {}
	local trimmed = trim(text)
	if trimmed == "" then
		return true, boxes, nil
	end

	local depth = 0
	local current = ""

	local function flush(): (boolean, string?)
		local ok, box, reason = Literal.parse(current)
		if not ok then
			return false, reason
		end
		table.insert(boxes, box)
		current = ""
		return true, nil
	end

	for index = 1, #trimmed do
		local char = trimmed:sub(index, index)
		if char == "(" or char == "[" then
			depth += 1
			current ..= char
		elseif char == ")" or char == "]" then
			depth -= 1
			current ..= char
		elseif char == "," and depth <= 0 then
			local ok, reason = flush()
			if not ok then
				return false, {}, reason
			end
		else
			current ..= char
		end
	end

	local ok, reason = flush()
	if not ok then
		return false, {}, reason
	end

	return true, boxes, nil
end

--------------------------------------------------------------------------------
-- 되돌리기
--------------------------------------------------------------------------------

-- 상자에서 실제 값을 꺼낸다. Instance 상자는 아이템 번호를 들고 있을 뿐이라
-- 여기서는 그 참조를 그대로 돌려준다. 실제 인스턴스로 푸는 건 Applier의 몫이다.
function Literal.decode(box: any): any
	if typeof(box) ~= "table" or box.t == nil or box.t == Literal.NIL then
		return nil
	end
	return Value.decode(box.t, box.v)
end

-- 다시 글로 적는다. 읽은 것과 같은 모양이어야 창을 열었다 닫아도 안 바뀐다.
function Literal.format(box: any): string
	if typeof(box) ~= "table" or box.t == nil or box.t == Literal.NIL then
		return Literal.NIL
	end

	local decoded = Value.decode(box.t, box.v)
	if box.t == "number" or box.t == "boolean" then
		return tostring(decoded)
	end
	if box.t == "string" then
		return string.format("%q", tostring(decoded))
	end
	if box.t == "EnumItem" then
		return "Enum." .. Value.format(box.t, decoded)
	end
	if box.t == "Instance" then
		return Value.format(box.t, decoded)
	end
	return string.format("%s(%s)", box.t, Value.format(box.t, decoded))
end

function Literal.formatList(boxes: { any }): string
	local parts = {}
	for _, box in boxes do
		table.insert(parts, Literal.format(box))
	end
	return table.concat(parts, ", ")
end

return Literal
