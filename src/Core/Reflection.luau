--!nonstrict
-- ReflectionService 감싸기.
--
-- 이 서비스로 클래스의 속성 이름을 전부 얻을 수 있다. 그러면 손으로 적어둔
-- 후보 목록(PropertyNames)에 없는 속성도 목록에 나온다.
--
-- 다만 돌려주는 표에서 우리가 확실히 아는 건 Name뿐이다. Type과 Permits의
-- 정확한 모양은 문서에 안 나와 있어서, 거기에 기대는 코드는 쓰지 않는다.
-- 타입은 지금처럼 실제 인스턴스에서 값을 읽어 typeof로 알아낸다. 그게 더 정확하고
-- 이 서비스가 없는 환경에서도 똑같이 동작한다.
--
-- 서비스가 없거나 호출이 실패하면 nil을 돌려주고, 부르는 쪽이 적어둔 목록으로
-- 물러난다. 모든 접근을 pcall로 감싸는 이유다.

local Locale = require(script.Parent.Locale)

local Reflection = {}

local service: any = nil
local looked = false

local function getService(): any
	if not looked then
		looked = true
		local ok, result = pcall(game.GetService, game, "ReflectionService")
		if ok then
			service = result
		end
	end
	return service
end

function Reflection.IsAvailable(): boolean
	return getService() ~= nil
end

-- descriptor 하나는 이렇게 생겼다 (Part.Shape 기준):
--
--   {
--     Name = "Shape",
--     Owner = "Part",
--     Serialized = false,
--     Display = { Category = "Part" },
--     Permits = { Read = Basic, Write = None },
--     Type = { EngineType = "Enum", EnumType = "PartType", ScriptType = "EnumItem" },
--   }
--
-- ScriptType은 typeof와 같은 이름을 쓰고, Enum이면 EnumType에 어떤 Enum인지 들어있다.
-- EnumItem 속성은 이게 없으면 "Neon"이 어느 Enum의 것인지 알 수 없다.

export type Entry = {
	name: string,
	deprecated: boolean,
	scriptType: string?,
	enumType: string?,
}

-- Display.DeprecationMessage가 있으면 폐기된 것으로 본다.
local function isDeprecated(descriptor: any): boolean
	local ok, message = pcall(function()
		return descriptor.Display.DeprecationMessage
	end)
	return ok and typeof(message) == "string" and message ~= ""
end

local function readField(descriptor: any, path: string, key: string): string?
	local ok, value = pcall(function()
		return descriptor[path][key]
	end)
	if ok and typeof(value) == "string" and value ~= "" then
		return value
	end
	return nil
end

local function entriesOf(descriptors: any): { Entry }?
	if typeof(descriptors) ~= "table" then
		return nil
	end

	local entries: { Entry } = {}
	for _, descriptor in descriptors do
		local ok, name = pcall(function()
			return descriptor.Name
		end)
		if ok and typeof(name) == "string" and name ~= "" then
			table.insert(entries, {
				name = name,
				deprecated = isDeprecated(descriptor),
				scriptType = readField(descriptor, "Type", "ScriptType"),
				enumType = readField(descriptor, "Type", "EnumType"),
			})
		end
	end

	if #entries == 0 then
		return nil
	end
	return entries
end

-- 이 클래스가 가진 속성 전부 (상속받은 것 포함). 못 얻으면 nil.
function Reflection.propertiesOf(className: string): { Entry }?
	local reflection = getService()
	if not reflection then
		return nil
	end

	local ok, descriptors = pcall(function()
		return reflection:GetPropertiesOfClass(className)
	end)
	if not ok then
		return nil
	end
	return entriesOf(descriptors)
end

-- 이 클래스가 가진 메소드 전부. 못 얻으면 nil.
-- (GetMethodsOfClass는 2026년 2월에 추가됐다. 없는 버전이면 실패하고 nil이다)
function Reflection.methodsOf(className: string): { Entry }?
	local reflection = getService()
	if not reflection then
		return nil
	end

	local ok, descriptors = pcall(function()
		return reflection:GetMethodsOfClass(className)
	end)
	if not ok then
		return nil
	end
	return entriesOf(descriptors)
end

-- 돌려주는 표가 실제로 어떻게 생겼는지 눈으로 확인하기 위한 덤프.
-- Type과 Permits의 모양을 알면 그걸 쓰도록 고칠 수 있다.
function Reflection.describe(className: string): string
	local reflection = getService()
	if not reflection then
		return Locale.T("reflection.unavailable")
	end

	local ok, descriptors = pcall(function()
		return reflection:GetPropertiesOfClass(className)
	end)
	if not ok then
		return Locale.T("reflection.callFailed", className, tostring(descriptors))
	end
	if typeof(descriptors) ~= "table" then
		return Locale.T("reflection.notTable", typeof(descriptors))
	end

	local lines = {
		Locale.T("reflection.header", className, #descriptors),
	}

	local function dump(value: any, indent: string, depth: number): string
		if typeof(value) ~= "table" or depth > 2 then
			return string.format("%s (%s)", tostring(value), typeof(value))
		end

		local parts = {}
		for key, inner in value do
			table.insert(
				parts,
				string.format("\n%s  %s = %s", indent, tostring(key), dump(inner, indent .. "  ", depth + 1))
			)
		end
		table.sort(parts)
		return "{" .. table.concat(parts) .. "\n" .. indent .. "}"
	end

	for index = 1, math.min(3, #descriptors) do
		table.insert(lines, string.format("  [%d] %s", index, dump(descriptors[index], "  ", 0)))
	end

	return table.concat(lines, "\n")
end

return Reflection
