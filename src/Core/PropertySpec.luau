--!nonstrict
-- 클래스별로 "애니메이션에 자주 쓰는 속성"을 적어둔다.
--
-- 로블록스는 어떤 속성이 있는지, 허용 범위가 얼마인지 스크립트로 알려주지 않는다.
-- Transparency가 0~1이라는 것도, ParticleEmitter에 Rate가 있다는 것도
-- 우리가 적어두는 수밖에 없다.
--
-- 여기 적은 것들은 두 곳에서 쓰인다.
--   animatable / methods → 트랙 추가할 때 고르는 목록
--   properties           → 키를 고르면 바로 나오는 슬라이더의 범위
--
-- 목록은 일반 클래스 → 구체 클래스 순서다. 앞에 나온 정의가 먼저 쌓인다.
-- 여기 없는 속성도 "Custom..."으로 직접 적으면 그대로 쓸 수 있다.

local PropertySpec = {}

export type Spec = {
	min: number,
	max: number,
	-- 슬라이더를 끌 때 붙는 간격. 없으면 연속.
	step: number?,
}

export type Suggestion = {
	name: string,
	valueType: string,
}

-- { 속성이름, 값타입 }
local SPECS = {
	{
		className = "BasePart",
		properties = {
			Transparency = { min = 0, max = 1, step = 0.01 },
			Reflectance = { min = 0, max = 1, step = 0.01 },
		},
		animatable = {
			{ "Transparency", "number" },
			{ "Reflectance", "number" },
			{ "Color", "Color3" },
			{ "Material", "EnumItem" },
			{ "CFrame", "CFrame" },
			{ "Size", "Vector3" },
			{ "Anchored", "boolean" },
			{ "CanCollide", "boolean" },
		},
	},

	--------------------------------------------------------------------------
	-- VFX
	--------------------------------------------------------------------------
	{
		className = "ParticleEmitter",
		properties = {
			Rate = { min = 0, max = 500, step = 1 },
			LightEmission = { min = 0, max = 1, step = 0.01 },
			LightInfluence = { min = 0, max = 1, step = 0.01 },
			Brightness = { min = 0, max = 10, step = 0.1 },
			TimeScale = { min = 0, max = 2, step = 0.01 },
			Drag = { min = 0, max = 20, step = 0.1 },
			ZOffset = { min = -10, max = 10, step = 0.1 },
		},
		animatable = {
			{ "Enabled", "boolean" },
			{ "Rate", "number" },
			{ "Lifetime", "NumberRange" },
			{ "Speed", "NumberRange" },
			{ "Color", "ColorSequence" },
			{ "Transparency", "NumberSequence" },
			{ "Size", "NumberSequence" },
			{ "LightEmission", "number" },
			{ "LightInfluence", "number" },
			{ "Brightness", "number" },
			{ "Rotation", "NumberRange" },
			{ "RotSpeed", "NumberRange" },
			{ "Acceleration", "Vector3" },
			{ "SpreadAngle", "Vector2" },
			{ "Drag", "number" },
			{ "TimeScale", "number" },
			{ "ZOffset", "number" },
		},
		methods = { "Emit", "Clear" },
	},
	{
		className = "Beam",
		properties = {
			Brightness = { min = 0, max = 10, step = 0.1 },
			LightEmission = { min = 0, max = 1, step = 0.01 },
			LightInfluence = { min = 0, max = 1, step = 0.01 },
			Width0 = { min = 0, max = 20, step = 0.1 },
			Width1 = { min = 0, max = 20, step = 0.1 },
			TextureSpeed = { min = -10, max = 10, step = 0.1 },
		},
		animatable = {
			{ "Enabled", "boolean" },
			{ "Color", "ColorSequence" },
			{ "Transparency", "NumberSequence" },
			{ "Brightness", "number" },
			{ "Width0", "number" },
			{ "Width1", "number" },
			{ "CurveSize0", "number" },
			{ "CurveSize1", "number" },
			{ "TextureSpeed", "number" },
			{ "TextureLength", "number" },
			{ "LightEmission", "number" },
			{ "LightInfluence", "number" },
		},
	},
	{
		className = "Trail",
		properties = {
			Lifetime = { min = 0, max = 10, step = 0.05 },
			LightEmission = { min = 0, max = 1, step = 0.01 },
			WidthScale = { min = 0, max = 5, step = 0.05 },
		},
		animatable = {
			{ "Enabled", "boolean" },
			{ "Color", "ColorSequence" },
			{ "Transparency", "NumberSequence" },
			{ "Lifetime", "number" },
			{ "WidthScale", "number" },
			{ "LightEmission", "number" },
		},
	},
	{
		className = "Highlight",
		animatable = {
			{ "Enabled", "boolean" },
			{ "FillColor", "Color3" },
			{ "FillTransparency", "number" },
			{ "OutlineColor", "Color3" },
			{ "OutlineTransparency", "number" },
		},
		properties = {
			FillTransparency = { min = 0, max = 1, step = 0.01 },
			OutlineTransparency = { min = 0, max = 1, step = 0.01 },
		},
	},
	{
		className = "Attachment",
		animatable = {
			{ "CFrame", "CFrame" },
			{ "Position", "Vector3" },
			{ "Visible", "boolean" },
		},
	},
	{
		className = "Decal",
		properties = { Transparency = { min = 0, max = 1, step = 0.01 } },
		animatable = {
			{ "Transparency", "number" },
			{ "Color3", "Color3" },
			{ "Texture", "string" },
		},
	},

	--------------------------------------------------------------------------
	-- 조명
	--------------------------------------------------------------------------
	{
		className = "Light",
		properties = { Brightness = { min = 0, max = 10, step = 0.1 } },
		animatable = {
			{ "Enabled", "boolean" },
			{ "Brightness", "number" },
			{ "Color", "Color3" },
			{ "Shadows", "boolean" },
		},
	},
	{
		className = "PointLight",
		properties = { Range = { min = 0, max = 60, step = 0.5 } },
		animatable = { { "Range", "number" } },
	},
	{
		className = "SpotLight",
		properties = {
			Range = { min = 0, max = 60, step = 0.5 },
			Angle = { min = 0, max = 180, step = 1 },
		},
		animatable = { { "Range", "number" }, { "Angle", "number" } },
	},
	{
		className = "SurfaceLight",
		properties = {
			Range = { min = 0, max = 60, step = 0.5 },
			Angle = { min = 0, max = 180, step = 1 },
		},
		animatable = { { "Range", "number" }, { "Angle", "number" } },
	},

	--------------------------------------------------------------------------
	-- 소리
	--------------------------------------------------------------------------
	{
		className = "Sound",
		properties = {
			Volume = { min = 0, max = 10, step = 0.05 },
			PlaybackSpeed = { min = 0, max = 4, step = 0.01 },
		},
		animatable = {
			{ "Playing", "boolean" },
			{ "Volume", "number" },
			{ "PlaybackSpeed", "number" },
			{ "TimePosition", "number" },
			{ "SoundId", "string" },
		},
		methods = { "Play", "Stop", "Pause", "Resume" },
	},

	--------------------------------------------------------------------------
	-- 화면 UI
	--------------------------------------------------------------------------
	{
		className = "GuiObject",
		properties = { BackgroundTransparency = { min = 0, max = 1, step = 0.01 } },
		animatable = {
			{ "Visible", "boolean" },
			{ "Position", "UDim2" },
			{ "Size", "UDim2" },
			{ "Rotation", "number" },
			{ "AnchorPoint", "Vector2" },
			{ "BackgroundColor3", "Color3" },
			{ "BackgroundTransparency", "number" },
		},
	},
	{
		className = "TextLabel",
		properties = {
			TextTransparency = { min = 0, max = 1, step = 0.01 },
			TextStrokeTransparency = { min = 0, max = 1, step = 0.01 },
		},
		animatable = {
			{ "Text", "string" },
			{ "TextColor3", "Color3" },
			{ "TextTransparency", "number" },
			{ "TextSize", "number" },
			{ "TextStrokeTransparency", "number" },
		},
	},
	{
		className = "ImageLabel",
		properties = { ImageTransparency = { min = 0, max = 1, step = 0.01 } },
		animatable = {
			{ "Image", "string" },
			{ "ImageColor3", "Color3" },
			{ "ImageTransparency", "number" },
		},
	},
	{
		className = "UIStroke",
		properties = {
			Transparency = { min = 0, max = 1, step = 0.01 },
			Thickness = { min = 0, max = 20, step = 0.1 },
		},
		animatable = {
			{ "Enabled", "boolean" },
			{ "Color", "Color3" },
			{ "Thickness", "number" },
			{ "Transparency", "number" },
		},
	},

	--------------------------------------------------------------------------
	-- 카메라 / 분위기
	--------------------------------------------------------------------------
	{
		className = "Camera",
		properties = { FieldOfView = { min = 1, max = 120, step = 1 } },
		animatable = { { "CFrame", "CFrame" }, { "FieldOfView", "number" } },
	},
	{
		className = "Atmosphere",
		properties = {
			Density = { min = 0, max = 1, step = 0.01 },
			Offset = { min = -1, max = 1, step = 0.01 },
			Haze = { min = 0, max = 10, step = 0.1 },
			Glare = { min = 0, max = 10, step = 0.1 },
		},
		animatable = {
			{ "Density", "number" },
			{ "Offset", "number" },
			{ "Haze", "number" },
			{ "Glare", "number" },
			{ "Color", "Color3" },
			{ "Decay", "Color3" },
		},
	},
}

local function matches(instance: Instance, className: string): boolean
	local ok, isA = pcall(function()
		return instance:IsA(className)
	end)
	return ok and isA
end

-- 바인딩된 인스턴스의 클래스를 보고 범위를 찾는다.
-- 바인딩이 없으면 어떤 클래스인지 알 수 없으므로 nil이다.
function PropertySpec.find(instance: Instance?, property: string): Spec?
	if not instance then
		return nil
	end

	local found: Spec? = nil
	for _, entry in SPECS do
		if entry.properties and matches(instance, entry.className) then
			local spec = entry.properties[property]
			if spec then
				found = spec
			end
		end
	end
	return found
end

-- 이 인스턴스에 걸 만한 속성과 메소드 목록.
-- 바인딩이 없으면 클래스를 모르니 빈 목록이다 (Custom으로 직접 적으면 된다).
function PropertySpec.suggest(instance: Instance?): ({ Suggestion }, { string })
	local properties: { Suggestion } = {}
	local methods: { string } = {}

	if not instance then
		return properties, methods
	end

	local seenProperty = {}
	local seenMethod = {}

	for _, entry in SPECS do
		if matches(instance, entry.className) then
			for _, item in entry.animatable or {} do
				if not seenProperty[item[1]] then
					seenProperty[item[1]] = true
					table.insert(properties, { name = item[1], valueType = item[2] })
				end
			end
			for _, name in entry.methods or {} do
				if not seenMethod[name] then
					seenMethod[name] = true
					table.insert(methods, name)
				end
			end
		end
	end

	return properties, methods
end

--------------------------------------------------------------------------------
-- 실제 인스턴스에서 속성 찾기
--------------------------------------------------------------------------------

local PropertyNames = require(script.Parent.PropertyNames)
local PathSpec = require(script.Parent.PathSpec)
local Reflection = require(script.Parent.Reflection)

local function readProperty(instance: Instance, name: string): any
	return (instance :: any)[name]
end

local function writeProperty(instance: Instance, name: string, value: any)
	(instance :: any)[name] = value
end

export type Found = {
	name: string,
	valueType: string,
	common: boolean, -- 위 목록에 적어둔 "자주 쓰는 것"인가
	deprecated: boolean,
	-- EnumItem 속성일 때 어떤 Enum인지 ("Material", "PartType" ...)
	enumType: string?,
}

-- 이 클래스의 속성 후보.
--
-- ReflectionService가 있으면 그걸로 전부 가져온다. 없으면 손으로 적어둔
-- 후보 목록으로 물러난다. 어느 쪽이든 아래에서 실제로 읽어보고 걸러낸다.
local function candidates(instance: Instance): { Reflection.Entry }
	local reflected = Reflection.propertiesOf(instance.ClassName)
	if reflected then
		return reflected
	end

	local fallback = {}
	for _, name in PropertyNames do
		table.insert(fallback, { name = name, deprecated = false })
	end
	return fallback
end

-- 이름 후보를 하나씩 읽어보고 실제로 쓸 수 있는 것만 남긴다.
--
-- 값이 읽히면 그 속성은 존재하는 것이고, 읽은 값의 typeof로 값 타입을
-- 정확히 알 수 있다. 리플렉션이 돌려주는 Type 표에 기대지 않는 이유는
-- 그 모양을 확인하지 않았기 때문이고, 실제 값에서 읽는 쪽이 어차피 더 정확하다.
function PropertySpec.discover(instance: Instance?): { Found }
	local found: { Found } = {}
	if not instance then
		return found
	end

	-- 자주 쓰는 것 목록에 있으면 위쪽에 모아 보여준다.
	local common = {}
	local order = {}
	local suggested = PropertySpec.suggest(instance)
	for index, suggestion in suggested do
		common[suggestion.name] = true
		order[suggestion.name] = index
	end

	-- 폐기 여부와 Enum 종류는 리플렉션만 알고 있으니 먼저 모아둔다.
	local candidateList = candidates(instance)
	local info = {}
	for _, entry in candidateList do
		info[entry.name] = entry
	end

	local seen = {}
	local function probe(name: string)
		if seen[name] then
			return
		end
		seen[name] = true

		local ok, value = pcall(readProperty, instance, name)
		if not ok then
			return
		end

		local valueType = typeof(value)
		if not PathSpec.isSupportedValueType(valueType) then
			return
		end

		-- 쓸 수 있는 속성인지 직접 확인한다.
		--
		-- 리플렉션의 Permits는 SecurityCapabilities 값이라 tostring으로는
		-- 뜻을 알 수 없고, 비교 규칙도 우리가 확인하지 않았다. 표 모양을
		-- 짐작하느니 실제로 해보는 쪽이 확실하다.
		--
		-- 방금 읽은 값을 그대로 다시 쓴다. 값이 같으면 로블록스가 변경으로
		-- 보지 않아 아무 일도 일어나지 않고, 읽기 전용이면 여기서 실패한다.
		if not pcall(writeProperty, instance, name, value) then
			return
		end

		local entry = info[name]
		table.insert(found, {
			name = name,
			valueType = valueType,
			common = common[name] == true,
			deprecated = entry ~= nil and entry.deprecated,
			-- EnumItem이면 어느 Enum인지. typeof로는 알 수 없어서 리플렉션이 필요하다.
			enumType = if valueType == "EnumItem" then (entry and entry.enumType) else nil,
		})
	end

	-- 자주 쓰는 것을 먼저 확인해서 순서를 잡고, 나머지를 훑는다.
	for _, suggestion in suggested do
		probe(suggestion.name)
	end
	for _, entry in candidateList do
		probe(entry.name)
	end

	-- 자주 쓰는 것은 적어둔 순서대로, 나머지는 이름순으로.
	table.sort(found, function(a, b)
		if a.common ~= b.common then
			return a.common
		end
		if a.common then
			return (order[a.name] or 0) < (order[b.name] or 0)
		end
		return a.name < b.name
	end)

	return found
end

export type FoundMethod = {
	name: string,
	common: boolean,
	deprecated: boolean,
}

-- 이 인스턴스에서 부를 수 있는 메소드.
-- 리플렉션이 알려준 이름을 실제로 읽어보고 함수인 것만 남긴다.
function PropertySpec.discoverMethods(instance: Instance?): { FoundMethod }
	local found: { FoundMethod } = {}
	if not instance then
		return found
	end

	local common = {}
	local order = {}
	local _, suggested = PropertySpec.suggest(instance)
	for index, name in suggested do
		common[name] = true
		order[name] = index
	end

	local seen = {}
	local function probe(name: string, deprecated: boolean)
		if seen[name] then
			return
		end
		seen[name] = true

		local ok, value = pcall(readProperty, instance, name)
		if not ok or typeof(value) ~= "function" then
			return
		end

		table.insert(found, {
			name = name,
			common = common[name] == true,
			deprecated = deprecated,
		})
	end

	local reflected = Reflection.methodsOf(instance.ClassName)
	for _, name in suggested do
		probe(name, false)
	end
	if reflected then
		for _, entry in reflected do
			probe(entry.name, entry.deprecated)
		end
	end

	table.sort(found, function(a, b)
		if a.common ~= b.common then
			return a.common
		end
		if a.common then
			return (order[a.name] or 0) < (order[b.name] or 0)
		end
		return a.name < b.name
	end)

	return found
end

-- 슬라이더 위치(0~1)를 실제 값으로
function PropertySpec.fromAlpha(spec: Spec, alpha: number): number
	local value = spec.min + (spec.max - spec.min) * math.clamp(alpha, 0, 1)
	if spec.step then
		value = math.round(value / spec.step) * spec.step
	end
	return math.clamp(value, spec.min, spec.max)
end

function PropertySpec.toAlpha(spec: Spec, value: number): number
	if spec.max == spec.min then
		return 0
	end
	return math.clamp((value - spec.min) / (spec.max - spec.min), 0, 1)
end

return PropertySpec
