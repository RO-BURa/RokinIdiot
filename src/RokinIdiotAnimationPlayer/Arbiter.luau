--!nonstrict
-- 여러 애니메이션이 같은 값을 건드릴 때 누가 이길지 정하고, 한 번만 쓴다.
--
-- 트랙은 프레임마다 값을 계산해서 여기에 맡긴다 (claim). 실제로 쓰는 건
-- 프레임 끝의 Flush 한 번이다. 트랙이 저마다 바로 써버리면 마지막에 쓴
-- 쪽이 이기게 되는데, 그건 우선순위도 비중도 아니고 그냥 순서다.
--
-- 원래 값을 적어두는 곳도 여기다. 두 트랙이 같은 속성을 건드렸다면 먼저
-- 온 쪽이 적어둔 값이 진짜 원래 값이라, 트랙마다 따로 적어두면 나중에
-- 온 쪽이 "우리가 쓴 값"을 원래 값으로 착각한다.

const Core = script:FindFirstChild("Core") or script.Parent.Core

const Value = require(Core.Value)
const Applier = require(Core.Applier)
const RigResolver = require(Core.RigResolver)

const PIVOT_KEY = Applier.PIVOT_KEY

-- 비중이 이만큼이면 1로 본다. 페이드가 정확히 1.0에 안 떨어질 수 있다.
const FULL = 0.999

const Arbiter = {}
Arbiter.__index = Arbiter

function Arbiter.new()
	return setmetatable({
		-- [instance][property] = { 원래값 }  (값 자체가 nil일 수 있어 한 겹 감싼다)
		_snapshot = {},
		-- [instance][property] = { claim, ... }  이번 프레임에 모인 것
		_claims = {},
		-- [instance][property] = { restore = boolean }  지금 누가 들고 있는 자리
		_held = {},
	}, Arbiter)
end

--------------------------------------------------------------------------------
-- 원래 값
--------------------------------------------------------------------------------

const function readProperty(instance: Instance, property: string): any
	return (instance :: any)[property]
end

const function writeProperty(instance: Instance, property: string, value: any)
	(instance :: any)[property] = value
end

-- 아직 안 적어뒀으면 지금 값을 적어둔다. 이미 있으면 건드리지 않는다.
function Arbiter:Remember(instance: Instance, property: string)
	local properties = self._snapshot[instance]
	if not properties then
		properties = {}
		self._snapshot[instance] = properties
	end
	if properties[property] ~= nil then
		return
	end

	if property == PIVOT_KEY then
		const pivot = RigResolver.pivotOf(instance)
		if pivot then
			properties[property] = { pivot }
		end
		return
	end

	const ok, value = pcall(readProperty, instance, property)
	if ok then
		properties[property] = { value }
	end
end

function Arbiter:BaseValue(instance: Instance, property: string): any
	const properties = self._snapshot[instance]
	const box = properties and properties[property]
	return if box then box[1] else nil
end

function Arbiter:_restore(instance: Instance, property: string)
	const properties = self._snapshot[instance]
	const box = properties and properties[property]
	if not box then
		return
	end

	if property == PIVOT_KEY then
		RigResolver.setPivot(instance, box[1])
		return
	end
	pcall(writeProperty, instance, property, box[1])
end

--------------------------------------------------------------------------------
-- 모으기
--------------------------------------------------------------------------------

-- track은 Priority / WeightCurrent / _order 를 들고 있어야 한다.
-- _order는 재생을 시작한 차례다. 섞을 수 없는 값이 같은 우선순위로 부딪히면
-- 먼저 시작한 쪽이 가져간다.
function Arbiter:Claim(track, instance: Instance, property: string, value: any, valueType: string?)
	local properties = self._claims[instance]
	if not properties then
		properties = {}
		self._claims[instance] = properties
	end

	local list = properties[property]
	if not list then
		list = {}
		properties[property] = list
	end

	table.insert(list, {
		track = track,
		value = value,
		valueType = valueType,
		priority = track.Priority,
		weight = track.WeightCurrent,
		order = track._order,
	})
end

--------------------------------------------------------------------------------
-- 중재해서 쓰기
--------------------------------------------------------------------------------

-- 우선순위가 가장 높은 것들만 남긴다.
const function winners(list)
	local best = nil
	for _, claim in list do
		if best == nil or claim.priority > best then
			best = claim.priority
		end
	end

	local kept = {}
	for _, claim in list do
		if claim.priority == best then
			table.insert(kept, claim)
		end
	end
	return kept
end

-- 섞을 수 있는 값. 비중대로 평균을 내고, 모자란 만큼은 원래 값이 채운다.
--
-- 하나씩 누적하면서 lerp를 쓰면 타입마다 따로 평균 공식을 만들지 않아도 된다.
-- (a를 accW만큼, b를 w만큼 섞는 것은 lerp(a, b, w / (accW + w)) 와 같다)
const function blend(valueType: string?, kept, base: any): any
	local acc = nil
	local accWeight = 0

	for _, claim in kept do
		if claim.weight <= 0 then
			continue
		end
		if acc == nil then
			acc = claim.value
			accWeight = claim.weight
		else
			const total = accWeight + claim.weight
			acc = Value.lerp(valueType, acc, claim.value, claim.weight / total)
			accWeight = total
		end
	end

	if acc == nil then
		return nil
	end

	-- 비중 합이 1보다 작으면 나머지는 원래 모습이다. 그래야 페이드인이
	-- 원래 값에서 시작한다. 원래 값을 모르면 있는 것만으로 간다.
	if accWeight < 1 and base ~= nil then
		return Value.lerp(valueType, base, acc, accWeight)
	end
	return acc
end

-- 섞을 수 없는 값. 비중이 1에 닿은 것 중 먼저 시작한 쪽이 가져간다.
const function pick(kept): any
	local best = nil
	for _, claim in kept do
		if claim.weight < FULL then
			continue
		end
		if best == nil or claim.order < best.order then
			best = claim
		end
	end
	return if best then best.value else nil
end

function Arbiter:Flush()
	-- 이번 프레임에 결정된 값을 쓴다.
	for instance, properties in self._claims do
		for property, list in properties do
			const kept = winners(list)
			const valueType = kept[1].valueType

			local final
			if Value.canInterpolate(valueType) then
				final = blend(valueType, kept, self:BaseValue(instance, property))
			else
				final = pick(kept)
			end

			-- 아무도 온전히 들고 있지 않으면 원래 모습으로 둔다.
			if final == nil then
				self:_restore(instance, property)
			else
				self:_apply(instance, property, final)
			end

			-- 이 자리를 누가 들고 있는지 적어둔다. 원복 여부는 이긴 쪽을 따른다.
			local held = self._held[instance]
			if not held then
				held = {}
				self._held[instance] = held
			end
			held[property] = { restore = kept[1].track.Restore ~= false }
		end
	end

	-- 아무도 claim하지 않게 된 자리는 원래 값으로 돌린다.
	for instance, properties in self._held do
		const claimed = self._claims[instance]
		for property, entry in properties do
			if claimed and claimed[property] then
				continue
			end
			if entry.restore then
				self:_restore(instance, property)
			end
			properties[property] = nil
		end
		if next(properties) == nil then
			self._held[instance] = nil
		end
	end

	table.clear(self._claims)
end

function Arbiter:_apply(instance: Instance, property: string, value: any)
	if not instance:IsDescendantOf(game) then
		return
	end

	if property == PIVOT_KEY then
		RigResolver.setPivot(instance, value)
		return
	end

	-- 같은 값을 다시 쓰지 않는다. 서버에서 돌릴 때는 이게 그대로
	-- 네트워크 트래픽이라 더 중요하다.
	const readOk, current = pcall(readProperty, instance, property)
	if readOk and current == value then
		return
	end
	pcall(writeProperty, instance, property, value)
end

-- 트랙이 사라졌다. 그 트랙만 들고 있던 자리는 다음 Flush에서 원복된다.
-- 여기서는 아무것도 하지 않는다. claim이 안 오면 알아서 풀린다.
function Arbiter:Destroy()
	for instance, properties in self._held do
		for property, entry in properties do
			if entry.restore then
				self:_restore(instance, property)
			end
		end
	end
	table.clear(self._held)
	table.clear(self._claims)
	table.clear(self._snapshot)
end

return Arbiter
