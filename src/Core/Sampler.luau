--!nonstrict
-- "지금 t초에 이 트랙의 값은 얼마인가"를 계산한다.
--
-- 에디터 미리보기와 런타임이 이 모듈 하나를 같이 쓴다.
-- 스튜디오에서 본 결과와 게임에서의 결과가 갈라질 수 없게 하는 게 목적이다.
--
-- 트랙의 keys는 시간순으로 정렬되어 있고 같은 시간에 키가 둘일 수 없다.
-- (Schema.validate와 Ops가 그 규칙을 지킨다)

local Value = require(script.Parent.Value)
local Easing = require(script.Parent.Easing)
local Debug = require(script.Parent.Debug)

local Sampler = {}

-- "키 위에 정확히 서 있다"고 볼 간격.
--
-- 이게 필요한 이유는 보간되지 않는 타입 때문이다. boolean, string, EnumItem
-- 같은 것들은 lerp가 없어서 alpha가 1이어도 앞 값을 그대로 돌려준다.
-- 그래서 "키 직전까지 앞 값"과 "키에 닿으면 그 값"을 시간으로 갈라야 한다.
-- 부등호 하나로 처리하면 재생헤드가 키에 정확히 올라섰을 때 그 키가 아직
-- 적용되지 않는다.
--
-- 한 트랙 안에서 키는 1e-4보다 가까울 수 없으므로 (Schema.validate가 정리한다)
-- 이 값이 이웃 키를 잡아먹을 일은 없다.
local ON_KEY = 1e-6

-- 마커가 없는 키를 위해 빈 표를 하나만 만들어 돌려쓴다.
-- 프레임마다 {} 를 새로 만들면 그만큼 쓰레기가 쌓인다.
local EMPTY = table.freeze({})

-- baseValue는 오브젝트가 원래 갖고 있던 값이다.
-- 이 값이 0초에 놓인 암묵적인 키처럼 동작해서, 0초부터 첫 키까지를 곧게 잇는다.
--
--   원래 Transparency 0, 1.0초에 키 1 → 0.5초에 0.5 (자연스러운 페이드)
--
-- 첫 키 값을 그대로 물려버리면 0.5초에 켜지는 파티클이 0초부터 켜져 있게 된다.
-- 시작 값을 직접 정하고 싶으면 0초에 키를 하나 찍으면 된다.
--
-- 보간이 안 되는 타입(boolean, string, Enum ...)은 Value.lerp가 앞 값을 유지하므로
-- 첫 키에 닿기 전까지 원래 값이 그대로 남는다. 그게 이 타입들에 맞는 동작이다.
--
-- 이 구간은 늘 Linear다. 키의 ease는 "그 키에서 다음 키로" 가는 방식이라
-- 첫 키 앞 구간에는 적용할 이징이 없다.
--
-- baseValue가 없으면(스냅샷 실패 등) 첫 키 앞에서는 nil이다.
-- 마지막 키보다 뒤면 마지막 값을 유지한다. 연출이 끝난 상태로 남는 게 맞다.
function Sampler.valueAt(track, time: number, baseValue: any?): any
	local keys = track.keys
	local count = #keys
	if count == 0 then
		return nil
	end

	local first = keys[1]
	-- 첫 키에 닿았으면 여기가 아니다. 그 아래에서 첫 키 값을 돌려준다.
	if time < first.t - ON_KEY then
		Debug.bump("debug.beforeFirstKey")
		local firstValue = Value.decode(track.valueType, first.v)

		-- 첫 키가 0초에 있거나 원래 값을 모르면 이을 구간이 없다.
		if first.t <= 0 then
			return firstValue
		end
		if baseValue == nil then
			return nil
		end

		return Value.lerp(track.valueType, baseValue, firstValue, math.clamp(time / first.t, 0, 1))
	end

	local last = keys[count]
	if time >= last.t - ON_KEY then
		Debug.bump("debug.afterLastKey")
		return Value.decode(track.valueType, last.v)
	end

	for index = 1, count - 1 do
		local a = keys[index]
		local b = keys[index + 1]
		if time <= b.t then
			-- 뒤쪽 키에 올라섰으면 그 키 값이다. 보간되는 타입은 alpha가 1이라
			-- 어차피 같은 값이 나오지만, 보간되지 않는 타입은 여기서 걸러야
			-- 앞 값에 머무르지 않는다.
			if time >= b.t - ON_KEY then
				return Value.decode(track.valueType, b.v)
			end

			local span = b.t - a.t
			local alpha = if span <= 1e-9 then 0 else (time - a.t) / span

			-- 여기가 렉이 걸리는 구간이라 시간을 재둔다.
			-- 이름을 문자열로 조립하면 매 프레임 쓰레기가 생기므로 상수만 쓴다.
			local startedAt = os.clock()

			local fromValue = Value.decode(track.valueType, a.v)
			local toValue = Value.decode(track.valueType, b.v)

			-- 이징은 앞 키에 붙어있다. 그 키에서 다음 키로 가는 방식이니까.
			-- Constant면 여기서 0이 나와 앞 키 값이 그대로 남는다.
			local eased = Easing.apply(a.ease, alpha)
			local result = Value.lerp(track.valueType, fromValue, toValue, eased)

			Debug.record("debug.betweenKeys", os.clock() - startedAt)
			return result
		end
	end

	return Value.decode(track.valueType, last.v)
end

-- (from, to] 구간을 지나간 메소드 키들. 재생이 앞으로 갈 때만 잡힌다.
-- 되감거나 제자리면 빈 목록이라 같은 호출이 두 번 일어나지 않는다.
function Sampler.eventsBetween(track, fromTime: number, toTime: number)
	local hits = {}
	if toTime <= fromTime then
		return hits
	end

	for _, key in track.keys do
		if key.t > fromTime and key.t <= toTime then
			table.insert(hits, key)
		elseif key.t > toTime then
			break
		end
	end
	return hits
end

-- 이 구간을 지나며 만나는 키프레임. 규칙은 메소드 이벤트와 같다.
-- (fromTime, toTime] 이고 앞으로 갈 때만 잡는다. 되감을 때 다시 울리면
-- 소리나 이펙트가 두 번 난다.
--
-- 이름 붙은 것이 두 군데에 있다. 트랙 위의 값 키에 이름을 달 수도 있고,
-- 키프레임 줄에 값 없이 시점만 찍어둘 수도 있다. 재생하는 쪽에서는 둘을
-- 구분할 이유가 없어서 여기서 한 목록으로 합쳐 준다.
--
-- 돌려주는 것은 { t, name, markers } 모양이다.
--
-- 에디터는 이걸 쓰지 않는다. 기록만 하고 실제로 무엇을 할지는 재생하는
-- 쪽이 정한다. 런타임 패키지가 이 함수를 쓴다.
function Sampler.keyframesBetween(doc, fromTime: number, toTime: number)
	local hits = {}
	if toTime <= fromTime then
		return hits
	end

	for _, keyframe in doc.keyframes do
		if keyframe.t > fromTime and keyframe.t <= toTime then
			table.insert(hits, keyframe)
		elseif keyframe.t > toTime then
			break
		end
	end

	-- 값 키 중 이름이 붙었거나 마커를 든 것.
	for _, track in doc.tracks do
		for _, key in track.keys do
			if key.t > toTime then
				break
			end
			local named = key.name ~= nil or (key.markers ~= nil and #key.markers > 0)
			if named and key.t > fromTime then
				table.insert(hits, {
					t = key.t,
					name = key.name,
					markers = key.markers or EMPTY,
				})
			end
		end
	end

	-- 두 군데에서 모았으니 시간순으로 다시 세운다.
	table.sort(hits, function(a, b)
		return a.t < b.t
	end)
	return hits
end

return Sampler
