--!nonstrict
-- 계산한 값을 실제 인스턴스에 꽂는 절반.
--
-- Sampler가 "t초에 값이 얼마인가"까지 답하고, 여기가 그 값을 실제로 쓴다.
-- 에디터 미리보기와 게임 런타임이 이 모듈 하나를 같이 쓴다. 한쪽에만 있는
-- 절반이 있으면 스튜디오에서 본 것과 게임에서 도는 것이 반드시 갈라진다.
--
-- 여기는 재생을 모른다. 시간을 받아서 그 시점을 칠할 뿐이다.
-- 재생·정지·반복·스냅샷은 부르는 쪽(에디터의 Preview/Player, 런타임의 Track)
-- 이 맡는다.
--
--   const applier = Applier.new({
--       GetDocument = function() return doc end,
--       ResolveItem = function(itemId) return instances[itemId] end,
--       Remember = ...,      -- 되돌릴 값을 적어두라는 신호
--       BaseValue = ...,     -- 적어둔 원래 값 (첫 키 앞 구간을 여기서 잇는다)
--       RestoreProperty = ...,
--   })
--   applier:ApplyAt(1.5)

local Schema = require(script.Parent.Schema)
local Sampler = require(script.Parent.Sampler)
local PathSpec = require(script.Parent.PathSpec)
local RigResolver = require(script.Parent.RigResolver)
local Debug = require(script.Parent.Debug)
local Literal = require(script.Parent.Literal)

-- 피벗은 속성이 아니라서 스냅샷에 이 이름으로 따로 표시한다.
-- 부르는 쪽도 같은 이름을 봐야 해서 밖으로 내놓는다.
local PIVOT_KEY = "__pivot"

-- pcall에 클로저를 넘기면 프레임마다 함수 객체가 새로 생긴다.
-- 함수와 인자를 따로 넘기면 할당이 없다.
local function readProperty(instance: Instance, property: string): any
	return (instance :: any)[property]
end

local function writeProperty(instance: Instance, property: string, value: any)
	(instance :: any)[property] = value
end

local Applier = {}
Applier.__index = Applier

Applier.PIVOT_KEY = PIVOT_KEY

-- host가 채워야 하는 것들.
--
--   GetDocument()                       -- 지금 문서
--   ResolveItem(itemId) -> Instance?    -- 아이템 번호가 가리키는 실제 오브젝트
--   OriginCFrame() -> CFrame?           -- 기준 아이템의 원래 위치 (transform 트랙용)
--   Remember(instance, property)        -- 되돌릴 값을 적어두라는 신호
--   BaseValue(instance, property) -> any?
--   RestoreProperty(instance, property)
--   OnWrite()                           -- 실제로 값을 쓴 순간 (선택)
--
--   Claim(instance, property, value, valueType)  -- (선택)
--     주면 바로 쓰지 않고 이 함수에 넘긴다. 런타임은 애니메이션이 여럿
--     겹칠 수 있어서 프레임마다 값을 모았다가 중재한 뒤 한 번만 쓴다.
--     에디터는 하나뿐이라 주지 않고, 그러면 여기서 바로 쓴다.
export type Host = {
	GetDocument: () -> any,
	ResolveItem: (number) -> Instance?,
	OriginCFrame: () -> CFrame?,
	Remember: (Instance, string) -> (),
	BaseValue: (Instance, string) -> any,
	RestoreProperty: (Instance, string) -> (),
	OnWrite: (() -> ())?,
	Claim: ((Instance, string, any, string?) -> ())?,
}

function Applier.new(host: Host)
	return setmetatable({
		_host = host,
		-- [track] = instance | false. 경로를 매 프레임 다시 풀지 않기 위한 것.
		_resolved = {},
	}, Applier)
end

-- 바인딩이나 문서가 바뀌었으면 풀어둔 경로를 버린다.
function Applier:ClearCache()
	table.clear(self._resolved)
end

-- 트랙이 가리키는 실제 인스턴스. 아이템이 없거나 경로가 안 맞으면 nil.
--
-- 경로 해석은 문자열을 쪼개고 FindFirstChild를 반복하는 일이라 매 프레임
-- 할 일이 아니다. 한 번 풀어서 들고 있다가 ClearCache 때만 다시 푼다.
-- 못 찾은 것도 false로 기억해서 없는 경로를 매 프레임 다시 뒤지지 않는다.
function Applier:Resolve(track): Instance?
	local cached = self._resolved[track]
	-- 잡아둔 것이 지워졌으면 (파티클을 새로 갈아 끼운 경우 등) 다시 푼다.
	-- Parent 하나 읽는 값이라 매 프레임 봐도 싸다.
	if cached ~= nil and (cached == false or cached.Parent ~= nil) then
		return if cached == false then nil else cached
	end

	local instance = nil
	local root = self._host.ResolveItem(track.itemId)
	if root and root:IsDescendantOf(game) then
		instance = PathSpec.resolve(root, track.path)
	end

	self._resolved[track] = instance or false
	return instance
end

-- fromTime을 주면 그 사이를 지나간 메소드도 함께 호출한다.
-- 스크럽처럼 값만 보고 싶을 때는 생략한다.
function Applier:ApplyAt(time: number, fromTime: number?)
	local startedAt = os.clock()
	local doc = self._host.GetDocument()

	for _, track in doc.tracks do
		if track.kind == Schema.TRACK_KIND.METHOD then
			if fromTime then
				self:_applyMethod(track, fromTime, time)
			end
		elseif track.kind == Schema.TRACK_KIND.TRANSFORM then
			self:_applyTransform(track, time)
		elseif track.kind == Schema.TRACK_KIND.MOTOR6D then
			self:_applyMotor(track, time)
		else
			self:_applyProperty(track, time)
		end
	end

	Debug.record("debug.applyAt", os.clock() - startedAt)
end

-- 값은 건드리지 않고 메소드만 부른다.
--
-- 반복 재생이 끝을 넘어 처음으로 돌아온 프레임에는 지나온 구간이 두 토막
-- (from~끝, 0~to) 이라 ApplyAt으로는 한 번에 못 준다. 그렇다고 ApplyAt을
-- 두 번 부르면 값까지 두 번 계산되어 한 프레임에 두 값이 잡힌다.
function Applier:FireMethods(fromTime: number, toTime: number)
	for _, track in self._host.GetDocument().tracks do
		if track.kind == Schema.TRACK_KIND.METHOD then
			self:_applyMethod(track, fromTime, toTime)
		end
	end
end

-- 값이 이미 같으면 쓰지 않는다.
--
-- 같은 값을 다시 대입하면 로블록스는 변경으로 보지 않아 어차피 아무 일도
-- 안 하지만, 그걸 확인하는 것도 스튜디오 쪽 일이다. 여기서 걸러내면
-- 상수 구간과 스텝 트랙(boolean, Enum ...)에서는 쓰기가 아예 사라진다.
function Applier:_write(instance: Instance, property: string, value: any, valueType: string?)
	-- 모으는 쪽이 있으면 쓰지 않고 넘긴다. 누구 값이 이길지는 그쪽이 정한다.
	local claim = self._host.Claim
	if claim then
		claim(instance, property, value, valueType)
		return
	end

	local readOk, current = pcall(readProperty, instance, property)
	if readOk and current == value then
		Debug.bump("debug.skipSameValue")
		return
	end

	local writeAt = os.clock()
	pcall(writeProperty, instance, property, value)
	Debug.record("debug.writeProperty", os.clock() - writeAt)

	local onWrite = self._host.OnWrite
	if onWrite then
		onWrite()
	end
end

function Applier:_applyProperty(track, time: number)
	if #track.keys == 0 then
		return
	end

	local instance = self:Resolve(track)
	if not instance then
		return
	end

	-- 원래 값을 먼저 확보해둔다. 0초부터 첫 키까지를 이 값에서 잇는다.
	-- Remember는 처음 한 번만 기록하므로 우리가 쓴 값이 섞이지 않는다.
	self._host.Remember(instance, track.target)

	local sampleAt = os.clock()
	local value = Sampler.valueAt(track, time, self._host.BaseValue(instance, track.target))
	Debug.record("Sampler.valueAt", os.clock() - sampleAt)
	if value == nil then
		self._host.RestoreProperty(instance, track.target)
		return
	end

	-- Instance 값은 아이템 번호로 적혀 있으니 실제 인스턴스로 바꿔준다.
	if track.valueType == "Instance" then
		value = PathSpec.resolveInstanceRef(value, self:_itemInstances())
	end

	self:_write(instance, track.target, value, track.valueType)
end

-- Instance 값을 풀 때만 쓴다. 문서에 있는 아이템 번호 전부를 한 번에 준다.
function Applier:_itemInstances(): { [number]: Instance }
	local instances = {}
	for _, item in self._host.GetDocument().items do
		local instance = self._host.ResolveItem(item.id)
		if instance then
			instances[item.id] = instance
		end
	end
	return instances
end

function Applier:_applyMotor(track, time: number)
	if #track.keys == 0 then
		return
	end

	local motor = self:Resolve(track)
	if not motor or not motor:IsA("Motor6D") then
		return
	end

	-- C0/C1은 건드리지 않는다. Transform만 써도 파트가 따라 움직인다.
	-- 원래 자세에서 첫 키 자세로 자연스럽게 이어진다.
	self._host.Remember(motor, "Transform")

	local value = Sampler.valueAt(track, time, self._host.BaseValue(motor, "Transform"))
	if value == nil then
		self._host.RestoreProperty(motor, "Transform")
		return
	end

	self:_write(motor, "Transform", value, "CFrame")
end

function Applier:_applyTransform(track, time: number)
	if #track.keys == 0 then
		return
	end

	local root = self._host.ResolveItem(track.itemId)
	if not root or not root:IsDescendantOf(game) then
		return
	end

	local origin = self._host.OriginCFrame()
	if not origin then
		return
	end

	local pivot = RigResolver.pivotOf(root)
	if pivot then
		self._host.Remember(root, PIVOT_KEY)
	end

	-- 저장된 값은 기준 아이템 기준이라, 원래 위치도 같은 기준으로 바꿔서 넘긴다.
	local basePivot = self._host.BaseValue(root, PIVOT_KEY)
	local baseRelative = if basePivot then origin:Inverse() * basePivot else nil

	local value = Sampler.valueAt(track, time, baseRelative)
	if value == nil then
		self._host.RestoreProperty(root, PIVOT_KEY)
		return
	end

	-- 기준을 어디에 놓든 같은 연출이 나오게 상대 위치를 다시 세계 좌표로 편다.
	local target = origin * value

	-- 피벗도 값을 모으는 쪽이 있으면 그리로 보낸다. 쓰는 방법이 속성과
	-- 다를 뿐(setPivot) 겹칠 때 중재해야 하는 건 똑같다.
	local claim = self._host.Claim
	if claim then
		claim(root, PIVOT_KEY, target, "CFrame")
		return
	end

	if pivot and pivot == target then
		Debug.bump("debug.skipSameValue")
		return
	end

	local writeAt = os.clock()
	RigResolver.setPivot(root, target)
	Debug.record("debug.writePivot", os.clock() - writeAt)

	local onWrite = self._host.OnWrite
	if onWrite then
		onWrite()
	end
end

function Applier:_applyMethod(track, fromTime: number, toTime: number)
	local hits = Sampler.eventsBetween(track, fromTime, toTime)
	if #hits == 0 then
		return
	end

	local instance = self:Resolve(track)
	if not instance then
		return
	end

	for _, key in hits do
		local args = self:_unpackArgs(key)

		-- 게임 코드가 부르는 남의 메소드다. 하나가 던져도 나머지는 돌아야 한다.
		pcall(function()
			local method = (instance :: any)[track.target]
			if typeof(method) == "function" then
				-- 개수를 반드시 같이 넘긴다. 가운데가 nil이면 #로 센 길이는
				-- 거기서 끊겨서 뒤의 인자가 통째로 사라진다.
				method(instance, table.unpack(args, 1, args.n))
			end
		end)
	end
end

-- 저장된 인자 상자를 실제 값으로 푼다.
-- Instance 인자는 아이템 번호로 적혀 있으니 여기서 실제 오브젝트로 바꾼다.
function Applier:_unpackArgs(key)
	local boxes = key.args
	if typeof(boxes) ~= "table" or #boxes == 0 then
		return table.pack()
	end

	local values = table.create(#boxes)
	local items = nil

	for index, box in boxes do
		local value = Literal.decode(box)
		if typeof(box) == "table" and box.t == "Instance" and value ~= nil then
			items = items or self:_itemInstances()
			value = PathSpec.resolveInstanceRef(value, items)
		end
		values[index] = value
	end

	values.n = #boxes
	return values
end

return Applier
