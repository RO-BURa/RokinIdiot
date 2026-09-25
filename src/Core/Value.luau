--!nonstrict
-- 키프레임 값의 저장 / 표시 / 입력 해석 / 보간을 타입별로 모아둔다.
--
-- JSON에는 Color3나 CFrame을 그대로 넣을 수 없어서 저장할 때 풀어 쓰고
-- 읽을 때 다시 만든다. 인스펙터의 텍스트 입력도 같은 표에서 처리한다.
--
--   encode / decode  저장 파일용
--   format / parse   인스펙터 텍스트용
--   lerp             없으면 스텝 (다음 키까지 값을 유지)

local PathSpec = require(script.Parent.PathSpec)
local Locale = require(script.Parent.Locale)

local Value = {}

local function trim(text: string): string
	return text:match("^%s*(.-)%s*$") or ""
end

-- "1, 2, 3" → { 1, 2, 3 }
local function numberList(text: string, count: number, label: string): ({ number }?, string?)
	local parts = {}
	for piece in string.gmatch(text, "[^,]+") do
		local n = tonumber(trim(piece))
		if not n then
			return nil, Locale.T("value.numbersOnly", label)
		end
		table.insert(parts, n)
	end
	if #parts ~= count then
		return nil, Locale.T("value.numberCount", count, #parts, label)
	end
	return parts, nil
end

local function numText(n: number, places: number?): string
	local factor = 10 ^ (places or 3)
	-- 0을 더해서 -0을 +0으로 만든다. 안 그러면 "-0"으로 찍힌다.
	return tostring(math.round(n * factor) / factor + 0)
end

--------------------------------------------------------------------------------
-- 타입별 처리기
--------------------------------------------------------------------------------

local handlers: { [string]: any } = {}

handlers.number = {
	default = 0,
	encode = function(v)
		return v
	end,
	decode = function(raw)
		return tonumber(raw) or 0
	end,
	format = function(v)
		return numText(v, 4)
	end,
	parse = function(text)
		local n = tonumber(trim(text))
		if not n then
			return false, nil, Locale.T("value.number")
		end
		return true, n, nil
	end,
	lerp = function(a, b, t)
		return a + (b - a) * t
	end,
}

handlers.boolean = {
	default = false,
	encode = function(v)
		return v
	end,
	decode = function(raw)
		return raw == true
	end,
	format = function(v)
		return if v then "true" else "false"
	end,
	parse = function(text)
		local lower = trim(text):lower()
		if lower == "true" or lower == "1" then
			return true, true, nil
		end
		if lower == "false" or lower == "0" then
			return true, false, nil
		end
		return false, nil, Locale.T("value.boolean")
	end,
}

handlers.string = {
	default = "",
	encode = function(v)
		return v
	end,
	decode = function(raw)
		return tostring(raw or "")
	end,
	format = function(v)
		return tostring(v)
	end,
	parse = function(text)
		return true, text, nil
	end,
}

handlers.Color3 = {
	default = Color3.new(1, 1, 1),
	encode = function(v)
		return { v.R, v.G, v.B }
	end,
	decode = function(raw)
		if typeof(raw) ~= "table" then
			return Color3.new(1, 1, 1)
		end
		return Color3.new(tonumber(raw[1]) or 0, tonumber(raw[2]) or 0, tonumber(raw[3]) or 0)
	end,
	format = function(v)
		return string.format("%d, %d, %d", math.round(v.R * 255), math.round(v.G * 255), math.round(v.B * 255))
	end,
	parse = function(text)
		local parts, reason = numberList(text, 3, "255, 128, 0")
		if not parts then
			return false, nil, reason
		end
		return true, Color3.fromRGB(parts[1], parts[2], parts[3]), nil
	end,
	lerp = function(a, b, t)
		return a:Lerp(b, t)
	end,
}

handlers.Vector3 = {
	default = Vector3.zero,
	encode = function(v)
		return { v.X, v.Y, v.Z }
	end,
	decode = function(raw)
		if typeof(raw) ~= "table" then
			return Vector3.zero
		end
		return Vector3.new(tonumber(raw[1]) or 0, tonumber(raw[2]) or 0, tonumber(raw[3]) or 0)
	end,
	format = function(v)
		return string.format("%s, %s, %s", numText(v.X), numText(v.Y), numText(v.Z))
	end,
	parse = function(text)
		local parts, reason = numberList(text, 3, "0, 5, 0")
		if not parts then
			return false, nil, reason
		end
		return true, Vector3.new(parts[1], parts[2], parts[3]), nil
	end,
	lerp = function(a, b, t)
		return a:Lerp(b, t)
	end,
}

handlers.Vector2 = {
	default = Vector2.zero,
	encode = function(v)
		return { v.X, v.Y }
	end,
	decode = function(raw)
		if typeof(raw) ~= "table" then
			return Vector2.zero
		end
		return Vector2.new(tonumber(raw[1]) or 0, tonumber(raw[2]) or 0)
	end,
	format = function(v)
		return string.format("%s, %s", numText(v.X), numText(v.Y))
	end,
	parse = function(text)
		local parts, reason = numberList(text, 2, "0, 1")
		if not parts then
			return false, nil, reason
		end
		return true, Vector2.new(parts[1], parts[2]), nil
	end,
	lerp = function(a, b, t)
		return a:Lerp(b, t)
	end,
}

handlers.UDim = {
	default = UDim.new(),
	encode = function(v)
		return { v.Scale, v.Offset }
	end,
	decode = function(raw)
		if typeof(raw) ~= "table" then
			return UDim.new()
		end
		return UDim.new(tonumber(raw[1]) or 0, tonumber(raw[2]) or 0)
	end,
	format = function(v)
		return string.format("%s, %d", numText(v.Scale), v.Offset)
	end,
	parse = function(text)
		local parts, reason = numberList(text, 2, "0.5, 10")
		if not parts then
			return false, nil, reason
		end
		return true, UDim.new(parts[1], math.round(parts[2])), nil
	end,
	lerp = function(a, b, t)
		return UDim.new(a.Scale + (b.Scale - a.Scale) * t, math.round(a.Offset + (b.Offset - a.Offset) * t))
	end,
}

handlers.UDim2 = {
	default = UDim2.new(),
	encode = function(v)
		return { v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset }
	end,
	decode = function(raw)
		if typeof(raw) ~= "table" then
			return UDim2.new()
		end
		return UDim2.new(tonumber(raw[1]) or 0, tonumber(raw[2]) or 0, tonumber(raw[3]) or 0, tonumber(raw[4]) or 0)
	end,
	format = function(v)
		return string.format("%s, %d, %s, %d", numText(v.X.Scale), v.X.Offset, numText(v.Y.Scale), v.Y.Offset)
	end,
	parse = function(text)
		local parts, reason = numberList(text, 4, "0.5, 0, 0.5, 0")
		if not parts then
			return false, nil, reason
		end
		return true, UDim2.new(parts[1], math.round(parts[2]), parts[3], math.round(parts[4])), nil
	end,
	lerp = function(a, b, t)
		return a:Lerp(b, t)
	end,
}

handlers.CFrame = {
	default = CFrame.identity,
	encode = function(v)
		return { v:GetComponents() }
	end,
	decode = function(raw)
		if typeof(raw) ~= "table" or #raw < 12 then
			return CFrame.identity
		end
		return CFrame.new(
			raw[1],
			raw[2],
			raw[3],
			raw[4],
			raw[5],
			raw[6],
			raw[7],
			raw[8],
			raw[9],
			raw[10],
			raw[11],
			raw[12]
		)
	end,
	-- 12개 성분을 그대로 보여주면 못 읽으니 위치와 각도로 풀어서 보여준다.
	format = function(v)
		local position = v.Position
		local rx, ry, rz = v:ToOrientation()
		return string.format(
			"%s, %s, %s | %s, %s, %s",
			numText(position.X),
			numText(position.Y),
			numText(position.Z),
			numText(math.deg(rx), 2),
			numText(math.deg(ry), 2),
			numText(math.deg(rz), 2)
		)
	end,
	parse = function(text)
		-- "x, y, z" 또는 "x, y, z | rx, ry, rz" (각도는 도 단위)
		local positionText, orientationText = text:match("^(.-)|(.*)$")
		positionText = positionText or text

		local position, reason = numberList(positionText, 3, "0, 5, 0 | 0, 90, 0")
		if not position then
			return false, nil, reason
		end

		local base = CFrame.new(position[1], position[2], position[3])
		if not orientationText or trim(orientationText) == "" then
			return true, base, nil
		end

		local orientation, orientationReason = numberList(orientationText, 3, "0, 5, 0 | 0, 90, 0")
		if not orientation then
			return false, nil, orientationReason
		end

		return true,
			base * CFrame.fromOrientation(math.rad(orientation[1]), math.rad(orientation[2]), math.rad(orientation[3])),
			nil
	end,
	lerp = function(a, b, t)
		return a:Lerp(b, t)
	end,
}

handlers.NumberRange = {
	default = NumberRange.new(0),
	encode = function(v)
		return { v.Min, v.Max }
	end,
	decode = function(raw)
		if typeof(raw) ~= "table" then
			return NumberRange.new(0)
		end
		return NumberRange.new(tonumber(raw[1]) or 0, tonumber(raw[2]) or tonumber(raw[1]) or 0)
	end,
	format = function(v)
		if v.Min == v.Max then
			return numText(v.Min)
		end
		return string.format("%s, %s", numText(v.Min), numText(v.Max))
	end,
	parse = function(text)
		local single = tonumber(trim(text))
		if single then
			return true, NumberRange.new(single), nil
		end
		local parts, reason = numberList(text, 2, "1, 5")
		if not parts then
			return false, nil, reason
		end
		if parts[1] > parts[2] then
			return false, nil, Locale.T("value.rangeOrder")
		end
		return true, NumberRange.new(parts[1], parts[2]), nil
	end,
	lerp = function(a, b, t)
		return NumberRange.new(a.Min + (b.Min - a.Min) * t, a.Max + (b.Max - a.Max) * t)
	end,
}

handlers.BrickColor = {
	default = BrickColor.new("Medium stone grey"),
	encode = function(v)
		return v.Number
	end,
	decode = function(raw)
		return BrickColor.new(tonumber(raw) or 194)
	end,
	format = function(v)
		return v.Name
	end,
	parse = function(text)
		local name = trim(text)
		local ok, color = pcall(BrickColor.new, name)
		if not ok or color.Name ~= name then
			return false, nil, Locale.T("value.brickColor")
		end
		return true, color, nil
	end,
}

handlers.EnumItem = {
	default = nil,
	encode = function(v)
		if not v then
			return nil
		end
		return { tostring(v.EnumType), v.Name }
	end,
	decode = function(raw)
		if typeof(raw) ~= "table" then
			return nil
		end
		local ok, item = pcall(function()
			return (Enum :: any)[raw[1]][raw[2]]
		end)
		return if ok then item else nil
	end,
	format = function(v)
		if not v then
			return ""
		end
		return string.format("%s.%s", tostring(v.EnumType), v.Name)
	end,
	-- enumType을 알면 "Neon"처럼 항목 이름만 적어도 된다.
	-- 모르면 "Material.Neon"처럼 Enum 이름까지 있어야 어느 Enum인지 알 수 있다.
	parse = function(text, enumType)
		local cleaned = trim(text):gsub("^Enum%.", "")

		local enumName, itemName = cleaned:match("^([%w_]+)%.([%w_]+)$")
		if not enumName then
			if not enumType then
				return false, nil, Locale.T("value.enumName")
			end
			enumName, itemName = enumType, cleaned
		end

		local ok, item = pcall(function()
			return (Enum :: any)[enumName][itemName]
		end)
		if not ok or not item then
			return false, nil, Locale.T("value.enumMissing", enumName, itemName)
		end
		return true, item, nil
	end,
}

--------------------------------------------------------------------------------
-- 시퀀스 (파티클 색·크기)
--------------------------------------------------------------------------------

-- 손으로 적기엔 너무 길어서 인스펙터에서는 Capture로만 넣는다.
local function sequenceHandler(constructor, keypointConstructor, isColor: boolean)
	return {
		default = nil,
		captureOnly = true,
		encode = function(v)
			if not v then
				return nil
			end
			local points = {}
			for _, keypoint in v.Keypoints do
				if isColor then
					local c = keypoint.Value
					table.insert(points, { keypoint.Time, c.R, c.G, c.B })
				else
					table.insert(points, { keypoint.Time, keypoint.Value, keypoint.Envelope })
				end
			end
			return points
		end,
		decode = function(raw)
			if typeof(raw) ~= "table" or #raw == 0 then
				return nil
			end
			local points = {}
			for _, entry in raw do
				if isColor then
					table.insert(
						points,
						keypointConstructor(entry[1], Color3.new(entry[2] or 0, entry[3] or 0, entry[4] or 0))
					)
				else
					table.insert(points, keypointConstructor(entry[1], entry[2] or 0, entry[3] or 0))
				end
			end
			local ok, sequence = pcall(constructor, points)
			return if ok then sequence else nil
		end,
		format = function(v)
			if not v then
				return Locale.T("common.none")
			end
			return Locale.T("value.keypoints", #v.Keypoints)
		end,
		parse = function()
			return false, nil, Locale.T("value.captureOnly")
		end,
		-- 키포인트 구성이 같을 때만 섞는다. 다르면 스텝으로 떨어진다.
		lerp = function(a, b, t)
			if not a or not b or #a.Keypoints ~= #b.Keypoints then
				return a
			end
			local points = {}
			for index, keypointA in a.Keypoints do
				local keypointB = b.Keypoints[index]
				if math.abs(keypointA.Time - keypointB.Time) > 1e-4 then
					return a
				end
				if isColor then
					table.insert(points, keypointConstructor(keypointA.Time, keypointA.Value:Lerp(keypointB.Value, t)))
				else
					local blended = keypointA.Value + (keypointB.Value - keypointA.Value) * t
					local envelope = keypointA.Envelope + (keypointB.Envelope - keypointA.Envelope) * t
					table.insert(points, keypointConstructor(keypointA.Time, blended, envelope))
				end
			end
			local ok, sequence = pcall(constructor, points)
			return if ok then sequence else a
		end,
	}
end

handlers.ColorSequence = sequenceHandler(ColorSequence.new, ColorSequenceKeypoint.new, true)
handlers.NumberSequence = sequenceHandler(NumberSequence.new, NumberSequenceKeypoint.new, false)

--------------------------------------------------------------------------------
-- Instance 참조
--------------------------------------------------------------------------------

handlers.Instance = {
	default = nil,
	encode = function(v)
		if not v then
			return nil
		end
		return { v.itemId, v.path }
	end,
	decode = function(raw)
		if typeof(raw) ~= "table" or not tonumber(raw[1]) then
			return nil
		end
		return { itemId = tonumber(raw[1]), path = tostring(raw[2] or "") }
	end,
	format = function(v)
		return PathSpec.formatInstanceRef(v)
	end,
	parse = function(text)
		local ok, ref, reason = PathSpec.parseInstanceRef(text)
		if not ok then
			return false, nil, reason
		end
		return true, ref, nil
	end,
}

--------------------------------------------------------------------------------
-- 공개 API
--------------------------------------------------------------------------------

-- 모르는 타입은 손대지 않고 그대로 들고만 있는다.
local opaque = {
	default = nil,
	encode = function(v)
		return v
	end,
	decode = function(raw)
		return raw
	end,
	format = function()
		return Locale.T("value.unsupported")
	end,
	parse = function()
		return false, nil, Locale.T("value.notEditable")
	end,
	captureOnly = true,
}

function Value.handler(valueType: string?)
	return handlers[valueType or ""] or opaque
end

function Value.defaultFor(valueType: string?): any
	return Value.handler(valueType).default
end

function Value.encode(valueType: string?, value: any): any
	if value == nil then
		return nil
	end
	return Value.handler(valueType).encode(value)
end

-- 디코드 결과 저장소.
--
-- 저장 파일의 값은 JSON에서 온 배열이라 쓸 때마다 CFrame이나 ColorSequence를
-- 새로 만들어야 한다. 재생 중에는 같은 키를 초당 60번 디코드하게 되는데
-- 결과는 늘 같으므로 한 번만 만들고 재사용한다.
--
-- 열쇠는 원본 테이블 자체다. 키 값을 고치면 Ops가 새 테이블을 넣기 때문에
-- 참조가 달라져 자동으로 새로 계산된다. 약한 참조라서 키를 지우면 같이 사라진다.
local decodeCache = setmetatable({}, { __mode = "k" })

function Value.decode(valueType: string?, raw: any): any
	if raw == nil then
		return Value.defaultFor(valueType)
	end

	-- 숫자·참거짓·문자열은 만들 게 없어서 저장할 이유가 없다.
	if typeof(raw) ~= "table" then
		return Value.handler(valueType).decode(raw)
	end

	local cached = decodeCache[raw]
	if cached and cached.valueType == valueType then
		return cached.value
	end

	local decoded = Value.handler(valueType).decode(raw)
	decodeCache[raw] = { valueType = valueType, value = decoded }
	return decoded
end

function Value.format(valueType: string?, value: any): string
	if value == nil then
		return ""
	end
	return Value.handler(valueType).format(value)
end

-- (성공 여부, 값, 실패 이유)
-- enumType은 EnumItem 트랙에서만 쓴다. 있으면 항목 이름만 적어도 된다.
function Value.parse(valueType: string?, text: string, enumType: string?): (boolean, any, string?)
	return Value.handler(valueType).parse(text, enumType)
end

-- 이 Enum이 가진 항목 전부. 고르는 목록을 만들 때 쓴다.
function Value.enumItems(enumType: string?): { EnumItem }
	if not enumType then
		return {}
	end

	local ok, items = pcall(function()
		return (Enum :: any)[enumType]:GetEnumItems()
	end)
	if not ok or typeof(items) ~= "table" then
		return {}
	end
	return items
end

function Value.isCaptureOnly(valueType: string?): boolean
	return Value.handler(valueType).captureOnly == true
end

function Value.canInterpolate(valueType: string?): boolean
	return Value.handler(valueType).lerp ~= nil
end

-- 화면에 색 견본으로 보여줄 수 있는 값이면 그 색을 돌려준다.
--
-- 숫자를 읽는 것보다 색을 보는 편이 빠르다. 키프레임 마름모와 편집 창이
-- 이걸로 값을 물들인다.
--
-- ColorSequence는 여러 색이라 하나로 줄일 수 없다. 가운데 색을 쓴다 —
-- 그라디언트를 대표하는 값으로 대충 맞고, 무엇보다 늘 하나가 나온다.
function Value.previewColor(valueType: string?, value: any): Color3?
	if value == nil then
		return nil
	end

	if valueType == "Color3" then
		return value
	end
	if valueType == "BrickColor" then
		return value.Color
	end
	if valueType == "ColorSequence" then
		local keypoints = value.Keypoints
		if #keypoints == 0 then
			return nil
		end
		return keypoints[math.ceil(#keypoints / 2)].Value
	end

	return nil
end

-- 보간을 못 하는 타입은 다음 키에 닿기 전까지 앞 키 값을 유지한다.
function Value.lerp(valueType: string?, a: any, b: any, alpha: number): any
	local handler = Value.handler(valueType)
	if not handler.lerp or a == nil or b == nil then
		return a
	end
	return handler.lerp(a, b, alpha)
end

-- 바인딩된 인스턴스의 현재 값을 읽는다. 선언한 타입과 다르면 실패로 본다.
function Value.capture(instance: Instance?, property: string, valueType: string?): (boolean, any, string?)
	if not instance then
		return false, nil, Locale.T("value.noBinding")
	end

	-- Instance 값은 아이템 번호 기준으로 적어야 해서 현재 값을 그대로 못 쓴다.
	if valueType == "Instance" then
		return false, nil, Locale.T("value.instanceRef")
	end

	local ok, current = pcall(function()
		return (instance :: any)[property]
	end)
	if not ok then
		return false, nil, Locale.T("value.missingProperty", instance.ClassName, property)
	end

	local actualType = typeof(current)
	if valueType and actualType ~= valueType then
		return false, nil, Locale.T("value.typeMismatch", actualType, valueType)
	end

	return true, current, nil
end

return Value
