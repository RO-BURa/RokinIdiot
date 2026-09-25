--!nonstrict
-- 문서를 제자리에서 고치는 순수 함수들.
-- 반드시 Project:Commit 안에서 호출한다. 그래야 Undo와 변경 알림이 붙는다.
--
--   project:Commit("아이템 추가", function(doc)
--       Ops.addItem(doc, "Character1")
--   end)

local Schema = require(script.Parent.Schema)
local PathSpec = require(script.Parent.PathSpec)
local Locale = require(script.Parent.Locale)

local Ops = {}

--------------------------------------------------------------------------------
-- 아이템
--------------------------------------------------------------------------------

function Ops.findItem(doc, id: number)
	for index, item in doc.items do
		if item.id == id then
			return item, index
		end
	end
	return nil, nil
end

function Ops.isItemNameTaken(doc, name: string, exceptId: number?): boolean
	for _, item in doc.items do
		if item.name == name and item.id ~= exceptId then
			return true
		end
	end
	return false
end

-- 비어있는 가장 작은 번호를 고른다.
-- 1, 2, 5가 있으면 다음은 6이 아니라 3이다. 빈 번호를 그대로 두면
-- 런타임에서 대입 테이블에 구멍이 생겨서 헷갈린다.
local function nextFreeId(doc): number
	local used = {}
	for _, item in doc.items do
		used[item.id] = true
	end

	local id = 1
	while used[id] do
		id += 1
	end
	return id
end

function Ops.addItem(doc, name: string): number
	local id = nextFreeId(doc)
	doc.nextItemId = math.max(doc.nextItemId, id + 1)

	table.insert(doc.items, {
		id = id,
		name = name,
		kind = Schema.ITEM_KIND.OBJECT,
	})

	-- 첫 아이템은 자동으로 위치 기준이 된다.
	if doc.originItemId == nil then
		doc.originItemId = id
	end

	return id
end

function Ops.removeItem(doc, id: number)
	local _, index = Ops.findItem(doc, id)
	if not index then
		return
	end
	table.remove(doc.items, index)

	for trackIndex = #doc.tracks, 1, -1 do
		if doc.tracks[trackIndex].itemId == id then
			table.remove(doc.tracks, trackIndex)
		end
	end

	-- 기준 아이템이 사라졌으면 남은 첫 아이템으로 넘긴다.
	if doc.originItemId == id then
		doc.originItemId = if #doc.items > 0 then doc.items[1].id else nil
	end
end

function Ops.renameItem(doc, id: number, name: string)
	local item = Ops.findItem(doc, id)
	if item then
		item.name = name
	end
end

function Ops.setItemKind(doc, id: number, kind: string)
	local item = Ops.findItem(doc, id)
	if item then
		item.kind = kind
	end
end

function Ops.setOriginItem(doc, id: number?)
	doc.originItemId = id
end

-- 아이템의 Id를 바꾼다. 그 번호를 이미 쓰는 아이템이 있으면 서로 맞바꾼다.
--
-- Id는 런타임에서 PlayAnimation에 넘기는 대입 번호라서 삭제해도 자동으로
-- 당겨지지 않는다. 빈 번호를 메우는 건 사용자가 직접 정한다.
function Ops.setItemId(doc, oldId: number, newId: number): boolean
	if oldId == newId then
		return true
	end

	local item = Ops.findItem(doc, oldId)
	if not item then
		return false
	end

	local other = Ops.findItem(doc, newId)

	local function retagTracks(from: number, to: number)
		for _, track in doc.tracks do
			if track.itemId == from then
				track.itemId = to
			end
		end
	end

	if other then
		-- 임시 번호를 거쳐야 두 아이템이 서로를 덮어쓰지 않는다.
		local temp = -1
		item.id = temp
		retagTracks(oldId, temp)

		other.id = oldId
		retagTracks(newId, oldId)

		item.id = newId
		retagTracks(temp, newId)

		if doc.originItemId == oldId then
			doc.originItemId = newId
		elseif doc.originItemId == newId then
			doc.originItemId = oldId
		end
	else
		item.id = newId
		retagTracks(oldId, newId)

		if doc.originItemId == oldId then
			doc.originItemId = newId
		end
	end

	local maxId = 0
	for _, entry in doc.items do
		maxId = math.max(maxId, entry.id)
	end
	doc.nextItemId = maxId + 1

	return true
end

--------------------------------------------------------------------------------
-- 엘리먼트 (같은 아이템 + 같은 경로를 공유하는 트랙 묶음)
--------------------------------------------------------------------------------

-- 아이템 안의 엘리먼트를 처음 등장 순서대로 돌려준다.
function Ops.elementsOf(doc, itemId: number)
	local elements = {}
	local lookup = {}

	for _, track in doc.tracks do
		if track.itemId == itemId then
			local element = lookup[track.path]
			if not element then
				element = { path = track.path, tracks = {} }
				lookup[track.path] = element
				table.insert(elements, element)
			end
			table.insert(element.tracks, track)
		end
	end

	return elements
end

function Ops.hasElement(doc, itemId: number, path: string): boolean
	for _, track in doc.tracks do
		if track.itemId == itemId and track.path == path then
			return true
		end
	end
	return false
end

function Ops.removeElement(doc, itemId: number, path: string)
	for index = #doc.tracks, 1, -1 do
		local track = doc.tracks[index]
		if track.itemId == itemId and track.path == path then
			table.remove(doc.tracks, index)
		end
	end
end

function Ops.setElementPath(doc, itemId: number, oldPath: string, newPath: string)
	for _, track in doc.tracks do
		if track.itemId == itemId and track.path == oldPath then
			track.path = newPath
		end
	end
end

--------------------------------------------------------------------------------
-- 트랙
--------------------------------------------------------------------------------

function Ops.findTrack(doc, itemId: number, path: string, target: string)
	for index, track in doc.tracks do
		if track.itemId == itemId and track.path == path and track.target == target then
			return track, index
		end
	end
	return nil, nil
end

-- 이미 있는 타겟이면 nil과 이유를 돌려준다.
function Ops.addTrack(
	doc,
	itemId: number,
	path: string,
	kind: string,
	target: string,
	valueType: string?,
	enumType: string?
)
	if Ops.findTrack(doc, itemId, path, target) then
		return nil, Locale.T("tree.trackTaken", PathSpec.formatTarget(kind, target))
	end

	-- 리그 관절과 아이템 위치는 언제나 CFrame이다.
	local resolvedType = nil
	if kind == Schema.TRACK_KIND.PROPERTY then
		resolvedType = valueType or "number"
	elseif kind == Schema.TRACK_KIND.MOTOR6D or kind == Schema.TRACK_KIND.TRANSFORM then
		resolvedType = "CFrame"
	end

	local track = {
		itemId = itemId,
		path = path,
		kind = kind,
		target = target,
		valueType = resolvedType,
		enumType = if resolvedType == "EnumItem" then enumType else nil,
		keys = {},
	}

	-- 같은 엘리먼트의 트랙끼리 붙어있어야 트리가 흩어지지 않는다.
	local insertAt = #doc.tracks + 1
	for index = #doc.tracks, 1, -1 do
		local existing = doc.tracks[index]
		if existing.itemId == itemId and existing.path == path then
			insertAt = index + 1
			break
		end
	end
	table.insert(doc.tracks, insertAt, track)

	return track, nil
end

function Ops.removeTrack(doc, itemId: number, path: string, target: string)
	local _, index = Ops.findTrack(doc, itemId, path, target)
	if index then
		table.remove(doc.tracks, index)
	end
end

function Ops.setTrackValueType(doc, itemId: number, path: string, target: string, valueType: string, enumType: string?)
	local track = Ops.findTrack(doc, itemId, path, target)
	if not track then
		return
	end

	local sameType = track.valueType == valueType
	local sameEnum = track.enumType == enumType
	if sameType and sameEnum then
		return
	end

	track.valueType = valueType
	track.enumType = if valueType == "EnumItem" then enumType else nil

	-- 이전 타입으로 찍은 값은 새 타입으로 해석할 수 없다.
	-- Enum 종류만 바뀐 경우도 마찬가지다 (Material.Neon을 PartType으로 읽을 수 없다).
	table.clear(track.keys)
end

--------------------------------------------------------------------------------
-- 키프레임
--
-- 트랙의 keys는 항상 t 오름차순으로 정렬되어 있다. 샘플러가 이걸 전제로 한다.
-- key.v 에는 JSON에 그대로 들어가는 형태(Value.encode의 결과)를 넣는다.
--------------------------------------------------------------------------------

-- 같은 프레임으로 볼 만큼 가까운지. 격자에 스냅해도 부동소수 오차가 남는다.
local KEY_EPSILON = 1e-4

function Ops.findKeyAt(track, t: number): (any?, number?)
	for index, key in track.keys do
		if math.abs(key.t - t) <= KEY_EPSILON then
			return key, index
		end
	end
	return nil, nil
end

-- t보다 앞(또는 같은 자리)에 있는 마지막 키. 새 키의 값을 물려받을 때 쓴다.
function Ops.keyBefore(track, t: number)
	local found = nil
	for _, key in track.keys do
		if key.t <= t + KEY_EPSILON then
			found = key
		else
			break
		end
	end
	return found
end

local function sortKeys(track)
	table.sort(track.keys, function(a, b)
		return a.t < b.t
	end)
end

-- 같은 시간에 이미 키가 있으면 덮어쓴다. 한 프레임에 키가 둘일 수는 없다.
function Ops.putKey(doc, itemId: number, path: string, target: string, t: number, encodedValue: any, args: { any }?)
	local track = Ops.findTrack(doc, itemId, path, target)
	if not track then
		return nil
	end

	local existing = Ops.findKeyAt(track, t)
	if existing then
		existing.v = encodedValue
		existing.args = args
		return existing
	end

	local key = { t = t, v = encodedValue, args = args }
	table.insert(track.keys, key)
	sortKeys(track)
	return key
end

function Ops.removeKeyAt(doc, itemId: number, path: string, target: string, t: number)
	local track = Ops.findTrack(doc, itemId, path, target)
	if not track then
		return
	end
	local _, index = Ops.findKeyAt(track, t)
	if index then
		table.remove(track.keys, index)
	end
end

-- 옮길 자리에 이미 키가 있으면 아무것도 하지 않고 false를 돌려준다.
-- 밀어낸 키를 조용히 지우면 애써 찍은 키가 사라지는 걸 알아채기 어렵다.
function Ops.moveKey(doc, itemId: number, path: string, target: string, fromTime: number, toTime: number): boolean
	local track = Ops.findTrack(doc, itemId, path, target)
	if not track then
		return false
	end

	local key, index = Ops.findKeyAt(track, fromTime)
	if not key or not index then
		return false
	end

	local _, occupantIndex = Ops.findKeyAt(track, toTime)
	if occupantIndex and occupantIndex ~= index then
		return false
	end

	key.t = toTime
	sortKeys(track)
	return true
end

-- 끄는 중처럼 key.t를 직접 건드린 뒤에 순서를 다시 맞춘다.
-- 샘플러는 keys가 시간순이라고 믿고 읽는다.
function Ops.resortKeys(track)
	sortKeys(track)
end

-- 그 시간에 이미 다른 키가 앉아 있는지 본다.
-- except는 검사에서 뺄 키다 (지금 끌고 있는 키는 자기 자신과 겹칠 수 없다).
-- 이웃을 뛰어넘는 건 막지 않는다. 막으면 키 순서를 바꿀 방법이 없어진다.
function Ops.isTimeTaken(track, t: number, except): boolean
	for _, other in track.keys do
		if other ~= except and math.abs(other.t - t) <= KEY_EPSILON then
			return true
		end
	end
	return false
end

-- 여러 키를 한꺼번에 옮길 때 쓴다.
--
-- entries는 { track = 트랙, key = 키, from = 원래 시간 } 목록이다.
-- 함께 움직이는 키끼리는 서로 걸림돌로 치지 않는다. 셋이 나란히 붙어 있어도
-- 통째로는 옮길 수 있어야 하기 때문이다.
function Ops.canShiftKeys(entries, delta: number, duration: number): boolean
	-- 같이 움직이는 키를 표로 만들어 둔다.
	local moving = {}
	for _, entry in entries do
		moving[entry.key] = true
	end

	for _, entry in entries do
		local target = entry.from + delta
		if target < -KEY_EPSILON or target > duration + KEY_EPSILON then
			return false
		end

		for _, other in entry.track.keys do
			if not moving[other] and math.abs(other.t - target) <= KEY_EPSILON then
				return false
			end
		end
	end

	return true
end

-- 고른 키들을 delta만큼 민다. refs는 { itemId, path, target, t } 목록이다.
-- 옮길 수 없는 상황이면 아무것도 하지 않고 false를 돌려준다.
function Ops.shiftKeys(doc, refs, delta: number): boolean
	local entries = {}

	for _, ref in refs do
		local track = Ops.findTrack(doc, ref.itemId, ref.path, ref.target)
		local key = track and Ops.findKeyAt(track, ref.t)
		if not key then
			return false
		end
		table.insert(entries, { track = track, key = key, from = key.t })
	end

	if not Ops.canShiftKeys(entries, delta, doc.duration) then
		return false
	end

	-- 검사를 다 마친 뒤에 한꺼번에 옮긴다. 하나씩 옮기면 중간 상태에서
	-- 자기들끼리 겹쳐 보인다.
	for _, entry in entries do
		entry.key.t = math.clamp(entry.from + delta, 0, doc.duration)
	end

	local sorted = {}
	for _, entry in entries do
		if not sorted[entry.track] then
			sorted[entry.track] = true
			sortKeys(entry.track)
		end
	end

	return true
end

function Ops.setKeyValue(doc, itemId: number, path: string, target: string, t: number, encodedValue: any)
	local track = Ops.findTrack(doc, itemId, path, target)
	if not track then
		return
	end
	local key = Ops.findKeyAt(track, t)
	if key then
		key.v = encodedValue
	end
end

function Ops.setKeyArgs(doc, itemId: number, path: string, target: string, t: number, args: { any })
	local track = Ops.findTrack(doc, itemId, path, target)
	if not track then
		return
	end
	local key = Ops.findKeyAt(track, t)
	if key then
		key.args = args
	end
end

function Ops.clearKeys(doc, itemId: number, path: string, target: string)
	local track = Ops.findTrack(doc, itemId, path, target)
	if track then
		table.clear(track.keys)
	end
end

-- style이 nil이면 이징을 지우고 선형으로 돌린다.
function Ops.setKeyEasing(
	doc,
	itemId: number,
	path: string,
	target: string,
	t: number,
	style: string?,
	direction: string?
)
	local track = Ops.findTrack(doc, itemId, path, target)
	if not track then
		return
	end
	local key = Ops.findKeyAt(track, t)
	if not key then
		return
	end
	key.ease = if style then { style, direction or "InOut" } else nil
end

-- 키에 이름을 붙인다. 빈 문자열이면 이름을 뗀다.
--
-- 이름이 붙은 키는 재생하는 쪽에서 GetTimeOfKeyframe으로 찾을 수 있고,
-- 지날 때 KeyframeReached가 이 이름으로 울린다.
function Ops.setKeyName(doc, itemId: number, path: string, target: string, t: number, name: string?)
	local track = Ops.findTrack(doc, itemId, path, target)
	if not track then
		return
	end
	local key = Ops.findKeyAt(track, t)
	if not key then
		return
	end

	key.name = if name == nil or name == "" then nil else name
end

-- 키에 마커를 넣는다. 같은 이름이 이미 있으면 넣지 않는다.
-- 신호는 이름으로 받으므로 둘이 있으면 같은 신호가 두 번 울릴 뿐이다.
function Ops.addKeyMarker(doc, itemId: number, path: string, target: string, t: number, name: string): boolean
	local track = Ops.findTrack(doc, itemId, path, target)
	if not track then
		return false
	end
	local key = Ops.findKeyAt(track, t)
	if not key then
		return false
	end

	if key.markers == nil then
		key.markers = {}
	end

	for _, marker in key.markers do
		if marker.name == name then
			return false
		end
	end

	table.insert(key.markers, { name = name })
	return true
end

function Ops.removeKeyMarker(doc, itemId: number, path: string, target: string, t: number, name: string): boolean
	local track = Ops.findTrack(doc, itemId, path, target)
	if not track then
		return false
	end
	local key = Ops.findKeyAt(track, t)
	if not key or key.markers == nil then
		return false
	end

	for index, marker in key.markers do
		if marker.name == name then
			table.remove(key.markers, index)
			-- 다 빠지면 필드를 없앤다. 저장 파일에 빈 배열을 남기지 않는다.
			if #key.markers == 0 then
				key.markers = nil
			end
			return true
		end
	end
	return false
end

-- 이름이 붙은 키를 이름으로 찾는다. 여럿이면 가장 이른 것.
-- 재생하는 쪽의 GetTimeOfKeyframe이 쓴다.
function Ops.findNamedKey(doc, name: string)
	local best = nil
	for _, track in doc.tracks do
		for _, key in track.keys do
			if key.name == name and (best == nil or key.t < best.t) then
				best = key
			end
		end
	end
	return best
end

--------------------------------------------------------------------------------
-- 재생 설정
--------------------------------------------------------------------------------

-- 길이를 이만큼으로 줄이면 사라질 키가 몇 개인지.
function Ops.countKeysAfter(doc, duration: number): number
	local count = 0
	for _, track in doc.tracks do
		for _, key in track.keys do
			if key.t > duration + KEY_EPSILON then
				count += 1
			end
		end
	end
	return count
end

--------------------------------------------------------------------------------
-- 우선순위
--------------------------------------------------------------------------------

-- Enum.AnimationPriority가 아니라 그냥 숫자다.
-- 에디터는 적어두기만 하고, 이 값으로 무엇을 할지는 재생하는 쪽이 정한다.
function Ops.setPriority(doc, priority: number)
	doc.priority = math.floor(priority)
end

--------------------------------------------------------------------------------
-- 키프레임 (이름 붙은 시점) 과 그 안의 마커
--
-- 값 키와 규칙이 같다. 한 시점에 하나뿐이고 시간순이다.
-- 다른 점은 하나가 마커를 여럿 들 수 있다는 것이다.
--------------------------------------------------------------------------------

function Ops.keyframeAt(doc, t: number)
	for _, keyframe in doc.keyframes do
		if math.abs(keyframe.t - t) <= KEY_EPSILON then
			return keyframe
		end
	end
	return nil
end

function Ops.findKeyframeByName(doc, name: string)
	for _, keyframe in doc.keyframes do
		if keyframe.name == name then
			return keyframe
		end
	end
	return nil
end

-- 그 시간에 이미 다른 키프레임이 있는지. except는 지금 끌고 있는 것이다.
function Ops.isKeyframeTimeTaken(doc, t: number, except): boolean
	for _, keyframe in doc.keyframes do
		if keyframe ~= except and math.abs(keyframe.t - t) <= KEY_EPSILON then
			return true
		end
	end
	return false
end

local function sortKeyframes(doc)
	table.sort(doc.keyframes, function(a, b)
		return a.t < b.t
	end)
end

-- 끄는 중처럼 keyframe.t를 직접 건드린 뒤에 순서를 다시 맞춘다.
function Ops.resortKeyframes(doc)
	sortKeyframes(doc)
end

-- 같은 시간에 이미 있으면 이름만 바꾼다. 안에 있던 마커는 그대로 둔다.
function Ops.putKeyframe(doc, t: number, name: string)
	local existing = Ops.keyframeAt(doc, t)
	if existing then
		existing.name = name
		return existing
	end

	local keyframe = { t = t, name = name, markers = {} }
	table.insert(doc.keyframes, keyframe)
	sortKeyframes(doc)
	return keyframe
end

function Ops.removeKeyframeAt(doc, t: number)
	for index, keyframe in doc.keyframes do
		if math.abs(keyframe.t - t) <= KEY_EPSILON then
			table.remove(doc.keyframes, index)
			return true
		end
	end
	return false
end

function Ops.clearKeyframes(doc)
	table.clear(doc.keyframes)
end

-- 값 키와 같은 규칙이다. 이미 다른 키프레임이 앉은 자리로는 못 옮기지만,
-- 지나가는 건 막지 않는다.
function Ops.moveKeyframe(doc, fromTime: number, toTime: number): boolean
	local keyframe = Ops.keyframeAt(doc, fromTime)
	if not keyframe then
		return false
	end
	if Ops.isKeyframeTimeTaken(doc, toTime, keyframe) then
		return false
	end

	keyframe.t = toTime
	sortKeyframes(doc)
	return true
end

function Ops.countKeyframesAfter(doc, duration: number): number
	local count = 0
	for _, keyframe in doc.keyframes do
		if keyframe.t > duration + KEY_EPSILON then
			count += 1
		end
	end
	return count
end

-- 같은 이름의 마커를 한 키프레임에 둘 넣을 이유가 없다. 신호는 이름으로
-- 받으므로 둘이 있으면 같은 신호가 두 번 울릴 뿐이다.
function Ops.addMarker(doc, t: number, name: string): boolean
	local keyframe = Ops.keyframeAt(doc, t)
	if not keyframe then
		return false
	end

	for _, marker in keyframe.markers do
		if marker.name == name then
			return false
		end
	end

	table.insert(keyframe.markers, { name = name })
	return true
end

function Ops.removeMarker(doc, t: number, name: string): boolean
	local keyframe = Ops.keyframeAt(doc, t)
	if not keyframe then
		return false
	end

	for index, marker in keyframe.markers do
		if marker.name == name then
			table.remove(keyframe.markers, index)
			return true
		end
	end
	return false
end

function Ops.setDuration(doc, duration: number)
	doc.duration = math.max(duration, 0.1)

	-- 밖으로 나간 키는 지운다.
	-- 예전처럼 끝으로 당기면 여러 키가 같은 시간에 겹쳐서
	-- "한 시간에 키는 하나" 규칙이 깨진다. 샘플러가 그걸 전제로 한다.
	for _, track in doc.tracks do
		for index = #track.keys, 1, -1 do
			if track.keys[index].t > doc.duration + KEY_EPSILON then
				table.remove(track.keys, index)
			end
		end
	end

	-- 키프레임도 같이 정리한다. 길이 밖에 남으면 보이지도 않고 지울 수도 없다.
	for index = #doc.keyframes, 1, -1 do
		if doc.keyframes[index].t > doc.duration + KEY_EPSILON then
			table.remove(doc.keyframes, index)
		end
	end
end

function Ops.setFps(doc, fps: number)
	doc.fps = math.clamp(math.floor(fps), 1, 240)
end

function Ops.setSnapUnit(doc, frames: number)
	doc.snapUnit = math.clamp(math.floor(frames), 1, 240)
end

return Ops
