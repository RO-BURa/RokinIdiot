--!strict
-- 프로젝트 문서 스키마 정의와 마이그레이션.
-- 여기서 나오는 테이블이 곧 StringValue에 들어가는 JSON이다.

local Locale = require(script.Parent.Locale)

local Schema = {}

Schema.VERSION = 4

-- 키(또는 키프레임 줄의 항목)를 지날 때 울릴 표식.
-- 재생하는 쪽이 이름별로 신호를 받는다 (GetMarkerReachedSignal).
export type Marker = {
	name: string,
}

export type Key = {
	t: number, -- 초
	v: any?, -- property / motor6d / transform 트랙의 값
	-- method 트랙의 호출 인자. 칸마다 타입을 달고 있는 상자다 ({ t, v }).
	-- 상자로 담아야 가운데 nil이 있어도 JSON 배열에 구멍이 안 생긴다.
	args: { any }?,
	ease: { string }?, -- { EasingStyle, EasingDirection }
	-- 이름을 붙이면 재생하는 쪽에서 GetTimeOfKeyframe으로 찾을 수 있고,
	-- 지날 때 KeyframeReached가 이 이름으로 울린다.
	name: string?,
	-- 이 키를 지날 때 울릴 표식들. 한 키에 여럿 넣을 수 있다.
	markers: { Marker }?,
}

export type Track = {
	itemId: number,
	path: string, -- 아이템 루트 기준 "a.b.c" (빈 문자열이면 루트 자신)
	kind: string, -- "property" | "method" | "motor6d" | "transform"
	target: string, -- 속성명 또는 메소드명
	valueType: string?,
	-- valueType이 EnumItem일 때 어느 Enum인지 ("Material", "PartType" ...).
	-- typeof로는 알 수 없어서 리플렉션에서 받아 문서에 함께 저장한다.
	-- 그래야 바인딩이 없어도 목록에서 고를 수 있다.
	enumType: string?,
	keys: { Key },
}

-- 이름 붙은 시점. 로블록스의 Keyframe과 같은 자리다.
--
-- 트랙마다 찍는 값 키(Key)와는 다른 것이다. 값 키는 트랙에 딸리고 값을 갖고,
-- 키프레임은 문서 전체에 딸리고 이름과 마커를 갖는다.
-- 에디터는 기록만 하고, 지날 때 무슨 일을 할지는 재생하는 쪽이 정한다.
export type Keyframe = {
	t: number, -- 초
	name: string,
	markers: { Marker },
}

export type Item = {
	id: number,
	name: string,
	kind: string, -- "rig" | "object"
}

export type Document = {
	schemaVersion: number,
	name: string,
	fps: number,
	duration: number,
	-- 키프레임과 재생헤드가 붙는 간격, 프레임 단위. 2면 두 프레임마다 붙는다.
	snapUnit: number,
	-- 재생하는 쪽이 어느 애니메이션을 위에 둘지 정할 때 쓰는 숫자.
	-- Enum.AnimationPriority가 아니라 그냥 숫자다. 에디터는 기록만 한다.
	priority: number,
	originItemId: number?,
	nextItemId: number,
	items: { Item },
	tracks: { Track },
	keyframes: { Keyframe },
}

Schema.TRACK_KIND = {
	PROPERTY = "property",
	METHOD = "method",
	MOTOR6D = "motor6d",
	TRANSFORM = "transform",
}

Schema.ITEM_KIND = {
	RIG = "rig",
	OBJECT = "object",
}

function Schema.newDocument(name: string): Document
	return {
		schemaVersion = Schema.VERSION,
		name = name,
		fps = 30,
		duration = 5,
		snapUnit = 2,
		priority = 0,
		originItemId = nil,
		nextItemId = 1,
		items = {},
		tracks = {},
		keyframes = {},
	}
end

-- 오래된 문서를 현재 버전으로 끌어올린다.
-- 버전이 올라갈 때마다 여기에 단계를 추가한다.
local migrations: { [number]: (any) -> any } = {}

-- v1 -> v2: 우선순위와 마커가 생겼다.
-- 없던 문서는 우선순위 0, 마커 없음으로 본다.
migrations[1] = function(doc)
	doc.priority = 0
	doc.markers = {}
	return doc
end

-- v2 -> v3: 마커가 키프레임 안으로 들어갔다.
--
-- 예전에는 마커 자체가 시점이라 한 시점에 하나뿐이었다. 같은 지점에서
-- 타격과 발소리를 함께 울릴 방법이 없었다. 이제 시점(키프레임)과 표식(마커)이
-- 나뉘고, 키프레임 하나가 마커를 여럿 들 수 있다.
--
-- 옛 마커는 같은 이름의 키프레임 하나 + 그 안의 마커 하나가 된다.
migrations[2] = function(doc)
	local keyframes = {}

	for _, marker in doc.markers or {} do
		table.insert(keyframes, {
			t = marker.t,
			name = marker.name,
			markers = { { name = marker.name } },
		})
	end

	doc.keyframes = keyframes
	doc.markers = nil
	return doc
end

-- v3 -> v4: 메소드 인자가 타입을 달게 되었다.
--
-- 예전에는 숫자·불리언·문자열만 넣을 수 있었고 가운데 nil은 아예 막혀 있었다.
-- JSON 배열에 구멍을 내면 길이를 믿을 수 없어 뒤의 인자가 사라지기 때문이다.
-- 이제 칸마다 { t = 타입, v = 값 } 상자로 담아서 구멍이 생기지 않는다.
migrations[3] = function(doc)
	for _, track in doc.tracks or {} do
		for _, key in track.keys or {} do
			if typeof(key.args) ~= "table" then
				continue
			end

			local boxed: { any } = {}
			for _, arg in key.args do
				local argType = typeof(arg)
				if argType == "number" or argType == "boolean" or argType == "string" then
					table.insert(boxed, { t = argType, v = arg })
				else
					-- 알 수 없는 것이 들어 있으면 자리만 지킨다.
					table.insert(boxed, { t = "nil" })
				end
			end
			key.args = boxed
		end
	end

	return doc
end

function Schema.migrate(doc: any): Document
	if typeof(doc) ~= "table" then
		error(Locale.T("schema.notTable"), 0)
	end

	local version = tonumber(doc.schemaVersion) or 0
	if version > Schema.VERSION then
		error(Locale.T("schema.tooNew", version, Schema.VERSION), 0)
	end

	while version < Schema.VERSION do
		local step = migrations[version]
		if not step then
			error(Locale.T("schema.noPath", version), 0)
		end
		doc = step(doc)
		version += 1
		doc.schemaVersion = version
	end

	return Schema.validate(doc)
end

-- 손상된 필드를 기본값으로 채운다. 저장 파일이 손으로 편집되는 경우가 있다.
function Schema.validate(doc: any): Document
	doc.schemaVersion = Schema.VERSION
	doc.name = tostring(doc.name or "Untitled")
	doc.fps = math.clamp(tonumber(doc.fps) or 30, 1, 240)
	doc.duration = math.max(tonumber(doc.duration) or 5, 0.1)
	doc.snapUnit = math.clamp(math.floor(tonumber(doc.snapUnit) or 2), 1, 240)
	doc.priority = math.floor(tonumber(doc.priority) or 0)
	doc.items = typeof(doc.items) == "table" and doc.items or {}
	doc.tracks = typeof(doc.tracks) == "table" and doc.tracks or {}
	doc.keyframes = typeof(doc.keyframes) == "table" and doc.keyframes or {}

	local maxId = 0
	for _, item in doc.items do
		item.id = tonumber(item.id) or 0
		item.name = tostring(item.name or "Item")
		item.kind = item.kind == Schema.ITEM_KIND.RIG and Schema.ITEM_KIND.RIG or Schema.ITEM_KIND.OBJECT
		maxId = math.max(maxId, item.id)
	end
	doc.nextItemId = math.max(tonumber(doc.nextItemId) or 1, maxId + 1)

	-- 키는 항상 시간순이고, 한 시간에 하나뿐이어야 한다.
	-- 샘플러와 키 이동이 이 두 가지를 전제로 한다.
	for _, track in doc.tracks do
		track.keys = typeof(track.keys) == "table" and track.keys or {}

		for _, key in track.keys do
			key.t = math.clamp(tonumber(key.t) or 0, 0, doc.duration)

			if key.name ~= nil then
				key.name = tostring(key.name)
			end

			-- 이름 없는 마커는 신호로 받을 방법이 없으니 버린다.
			-- 마커가 하나도 안 남으면 필드 자체를 없앤다. 저장 파일에
			-- 빈 배열이 키마다 붙으면 읽기만 어려워진다.
			if typeof(key.markers) == "table" then
				for index = #key.markers, 1, -1 do
					local marker = key.markers[index]
					if typeof(marker) ~= "table" or marker.name == nil then
						table.remove(key.markers, index)
					else
						marker.name = tostring(marker.name)
					end
				end
				if #key.markers == 0 then
					key.markers = nil
				end
			else
				key.markers = nil
			end
		end

		table.sort(track.keys, function(a, b)
			return a.t < b.t
		end)

		-- 손으로 편집했거나 옛 버전에서 겹쳐진 키를 정리한다.
		for index = #track.keys, 2, -1 do
			if math.abs(track.keys[index].t - track.keys[index - 1].t) < 1e-4 then
				table.remove(track.keys, index)
			end
		end
	end

	-- 키프레임도 키와 같다. 시간순이고 한 시간에 하나뿐이어야 한다.
	-- 줄이 하나뿐이라 같은 자리에 둘이 있으면 하나는 가려진다.
	-- 대신 그 하나가 마커를 여럿 들 수 있다.
	for _, keyframe in doc.keyframes do
		keyframe.t = math.clamp(tonumber(keyframe.t) or 0, 0, doc.duration)
		keyframe.name = tostring(keyframe.name or "Keyframe")
		keyframe.markers = typeof(keyframe.markers) == "table" and keyframe.markers or {}

		-- 이름 없는 마커는 신호로 받을 방법이 없으니 버린다.
		for index = #keyframe.markers, 1, -1 do
			local marker = keyframe.markers[index]
			if typeof(marker) ~= "table" or marker.name == nil then
				table.remove(keyframe.markers, index)
			else
				marker.name = tostring(marker.name)
			end
		end
	end

	table.sort(doc.keyframes, function(a, b)
		return a.t < b.t
	end)

	for index = #doc.keyframes, 2, -1 do
		if math.abs(doc.keyframes[index].t - doc.keyframes[index - 1].t) < 1e-4 then
			table.remove(doc.keyframes, index)
		end
	end

	-- originItemId가 사라진 아이템을 가리키면 해제한다.
	if doc.originItemId ~= nil then
		local found = false
		for _, item in doc.items do
			if item.id == doc.originItemId then
				found = true
				break
			end
		end
		if not found then
			doc.originItemId = nil
		end
	end

	return doc
end

return Schema
