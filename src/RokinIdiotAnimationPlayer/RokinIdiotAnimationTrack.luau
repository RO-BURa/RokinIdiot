--!nonstrict
-- 재생 중인 애니메이션 하나.
--
-- 로블록스의 AnimationTrack과 같은 모양으로 쓴다. 속성으로 읽고 쓰고,
-- 값이 바뀌면 Changed와 GetPropertyChangedSignal이 울린다.
--
--   const track = AnimationPlayer:LoadAnimation(save, character)
--   track.Looped = true
--   track:Play(0.3)
--
-- 값 계산은 Core.Sampler가, 실제로 꽂는 일은 Core.Applier가 한다. 에디터
-- 미리보기가 쓰는 것과 같은 모듈이라 스튜디오에서 본 것과 여기서 도는 것이
-- 갈라지지 않는다. 여기가 하는 일은 시간과 비중을 미는 것뿐이다.

const Packages = script:FindFirstChild("Packages") or script.Parent.Packages
const Core = script:FindFirstChild("Core") or script.Parent.Core

const XClass = require(Packages.XClass)
const Signal = require(Packages.Signal)
const RobloxStyleObject = require(Packages.RobloxStyleObject)

const Sampler = require(Core.Sampler)
const Applier = require(Core.Applier)
const RigResolver = require(Core.RigResolver)

-- 비중이 이만큼 가까우면 목표에 닿은 것으로 본다.
const WEIGHT_EPSILON = 1e-4

export type Signal = typeof(Signal.new())

export type RobloxStyleObject = typeof(RobloxStyleObject.new())

export type RokinIdiotAnimationTrack = RobloxStyleObject & {
	-- 읽기 전용
	read Animation: StringValue?, -- 이 트랙이 재생 중인 저장 값
	read IsPlaying: boolean, -- 페이드아웃 중에도 참이다
	read Length: number, -- 초
	read Speed: number, -- 바꿀 때는 AdjustSpeed
	read WeightCurrent: number, -- 지금 비중
	read WeightTarget: number, -- 가고 있는 목표 비중
	read MissingItems: { number }, -- 인스턴스를 못 받은 아이템 Id

	-- 읽고 쓰기
	Looped: boolean,
	Priority: number, -- 문서에 적힌 값으로 시작한다
	TimePosition: number, -- 넣으면 그 자리로 건너뛴다
	Restore: boolean, -- 멈출 때 원래 값으로 돌릴지
	FireMarkers: boolean, -- 마커 신호를 울릴지

	-- 신호
	read DidLoop: Signal, -- ()  반복이 한 바퀴 돌았다
	read KeyframeReached: Signal, -- (name: string)  이름 붙은 시점을 지났다
	read Stopped: Signal, -- ()  재생이 끝났다 (아직 페이드아웃 중일 수 있다)
	read Ended: Signal, -- ()  페이드아웃까지 끝나 더는 아무것도 안 건드린다

	-- 메소드
	read Play: (self: RokinIdiotAnimationTrack, fadeTime: number?, weight: number?, speed: number?) -> (),
	read Stop: (self: RokinIdiotAnimationTrack, fadeTime: number?) -> (),
	read AdjustSpeed: (self: RokinIdiotAnimationTrack, speed: number?) -> (),
	read AdjustWeight: (self: RokinIdiotAnimationTrack, weight: number?, fadeTime: number?) -> (),
	read GetMarkerReachedSignal: (self: RokinIdiotAnimationTrack, name: string) -> Signal,
	read GetTimeOfKeyframe: (self: RokinIdiotAnimationTrack, name: string) -> number?,
	read Destroy: (self: RokinIdiotAnimationTrack) -> (),
}

export type RokinIdiotAnimationTrackClass = {
	read new: (options: any) -> RokinIdiotAnimationTrack,
}

const RokinIdiotAnimationTrack = XClass.new(function(self, options)
	XClass.Super(self, RobloxStyleObject.new)

	self._doc = options.Document
	self._items = options.Items
	self._arbiter = options.Arbiter
	self._order = options.Order

	-- 재생이 시작되면 서비스가 프레임을 돌리기 시작해야 한다.
	-- 트랙은 서비스를 모르므로 깨우는 방법과 빠지는 방법만 받아둔다.
	self._wake = options.Wake
	self._forget = options.Forget

	-- 마커 신호를 울릴지. 꺼두면 값만 재생한다.
	self.FireMarkers = options.FireMarkers ~= false

	-- 되돌리기 여부는 Arbiter가 본다.
	self.Restore = options.Restore ~= false

	self.Animation = options.Animation
	self.Length = self._doc.duration
	self.Priority = options.Priority or self._doc.priority or 0
	self.MissingItems = options.MissingItems or {}

	self.IsPlaying = false
	self.Looped = false
	self.Speed = 1
	self.TimePosition = 0
	self.WeightCurrent = 0
	self.WeightTarget = 0

	-- 페이드 중이면 남은 시간. 0이면 바로 목표 비중이다.
	self._fadeLeft = 0
	self._stopping = false

	-- 마커 이름별 신호. 물어본 이름만 만든다.
	self._markerSignals = {}

	self.DidLoop = Signal.new("DidLoop")
	self.Ended = Signal.new("Ended")
	self.KeyframeReached = Signal.new("KeyframeReached")
	self.Stopped = Signal.new("Stopped")

	-- 값을 바로 쓰지 않고 Arbiter에 맡긴다. 여럿이 겹칠 수 있어서
	-- 누가 이길지는 프레임 끝에 한꺼번에 정해야 한다.
	self._applier = Applier.new({
		GetDocument = function()
			return self._doc
		end,
		ResolveItem = function(itemId: number): Instance?
			return self._items[itemId]
		end,
		OriginCFrame = function(): CFrame?
			return self._originCFrame
		end,
		Remember = function(instance: Instance, property: string)
			self._arbiter:Remember(instance, property)
		end,
		BaseValue = function(instance: Instance, property: string)
			return self._arbiter:BaseValue(instance, property)
		end,
		RestoreProperty = function()
			-- 여기서 되돌리지 않는다. claim이 안 오면 Arbiter가 알아서 푼다.
			-- 우리가 직접 되돌리면 더 높은 우선순위가 쓴 값을 지워버린다.
		end,
		Claim = function(instance: Instance, property: string, value: any, valueType: string?)
			self._arbiter:Claim(self, instance, property, value, valueType)
		end,
	})

	-- 기준 아이템의 처음 위치. 상대 위치 트랙이 이걸 기준으로 편다.
	-- 재생을 시작할 때마다 다시 잡는다 (Play). 불러둔 뒤 캐릭터가 걸어가도
	-- 지금 선 자리에서 연출이 나와야 한다.
	self._originCFrame = nil
end, {
	--------------------------------------------------------------------------
	-- 조작
	--------------------------------------------------------------------------

	Play = function(self, fadeTime: number?, weight: number?, speed: number?)
		if speed ~= nil then
			self.Speed = speed
		end

		self._stopping = false
		self.WeightTarget = weight or 1
		self:_startFade(fadeTime or 0)

		if not self.IsPlaying then
			-- 멈췄다 다시 트는 것이면 반대쪽 끝에서 시작한다. 뒤로 가는
			-- 중이면 그 끝은 마지막이다.
			--
			-- 로블록스는 여기서 마지막 프레임에 그대로 멈춰 서서, 다시
			-- 로드해야 뒤로 감긴다. 그건 따라 하지 않는다.
			if self.Speed < 0 then
				if self.TimePosition <= 0 then
					self.TimePosition = self.Length
				end
			elseif self.TimePosition >= self.Length then
				self.TimePosition = 0
			end
			self._lastTime = self.TimePosition
			self.IsPlaying = true

			-- 불러둔 뒤 오브젝트가 바뀌었을 수 있다 (리스폰, 나중에 붙은 파티클).
			-- 풀어둔 경로와 기준 위치를 새로 잡는다.
			self._applier:ClearCache()
			self:_captureOrigin()
		end

		if self._wake then
			self._wake()
		end
	end,

	Stop = function(self, fadeTime: number?)
		if not self.IsPlaying then
			return
		end

		-- 페이드아웃 중에 또 부르면 페이드 시간만 바꾼다. Stopped는 한 번만 울린다.
		const alreadyStopping = self._stopping
		self._stopping = true

		-- 재생은 여기서 끝난다. 아직 값은 들고 있다 (페이드아웃).
		if not alreadyStopping then
			self.Stopped:Fire()
		end

		self.WeightTarget = 0
		self:_startFade(fadeTime or 0)

		-- 페이드가 없으면 이 자리에서 손까지 뗀다.
		if self._fadeLeft <= 0 then
			self:_finishStop()
		end
	end,

	AdjustSpeed = function(self, speed: number?)
		self.Speed = speed or 1
	end,

	AdjustWeight = function(self, weight: number?, fadeTime: number?)
		self.WeightTarget = weight or 1
		self:_startFade(fadeTime or 0)
	end,

	--------------------------------------------------------------------------
	-- 신호
	--------------------------------------------------------------------------

	-- 없는 이름으로 불러도 만들어 준다. 마커는 나중에 추가될 수 있다.
	GetMarkerReachedSignal = function(self, name: string)
		local signal = self._markerSignals[name]
		if not signal then
			signal = Signal.new(name)
			self._markerSignals[name] = signal
		end
		return signal
	end,

	-- 그 이름의 키프레임이 없으면 nil. 로블록스는 오류를 던지지만,
	-- 애니메이션은 나중에 고쳐질 수 있는 데이터라 이름 하나 때문에 게임
	-- 로직이 멈추는 편이 더 나쁘다.
	GetTimeOfKeyframe = function(self, name: string): number?
		for _, keyframe in self._doc.keyframes do
			if keyframe.name == name then
				return keyframe.t
			end
		end

		for _, track in self._doc.tracks do
			for _, key in track.keys do
				if key.name == name then
					return key.t
				end
			end
		end

		return nil
	end,

	--------------------------------------------------------------------------
	-- 한 프레임
	--------------------------------------------------------------------------

	-- 서비스가 프레임마다 부른다. 여기서는 값을 계산해 Arbiter에 맡기기만 한다.
	Step = function(self, delta: number)
		if not self.IsPlaying then
			return
		end

		self:_stepWeight(delta)

		-- 밖에서 TimePosition을 옮겼으면 그 자리에서 이어 간다.
		-- 건너뛴 구간의 마커는 울리지 않는다. 지나간 게 아니라 옮겨간 것이다.
		local from = self._lastTime or self.TimePosition
		if math.abs(self.TimePosition - from) > 1e-4 then
			from = self.TimePosition
		end

		local to = from + delta * self.Speed
		local looped = false

		-- 뒤로 가는 중이면 끝나는 쪽이 반대다. 반복이면 0을 지나 마지막으로
		-- 되돌아간다 (로블록스 Looped가 그렇게 적혀 있다).
		const backward = self.Speed < 0

		if to >= self.Length then
			if self.Looped then
				-- 끝을 넘긴 만큼만 처음으로 돌린다. 그래야 배속이 빨라도
				-- 프레임마다 같은 자리에서 시작하지 않는다.
				looped = true
				to = if self.Length > 0 then to % self.Length else 0
			else
				to = self.Length
			end
		elseif to < 0 then
			if self.Looped then
				-- Lua의 %는 음수에서도 양수를 돌려준다. (-0.05 % 3 = 2.95)
				looped = true
				to = if self.Length > 0 then to % self.Length else 0
			else
				to = 0
			end
		end

		self.TimePosition = to

		-- 지나온 구간의 키프레임과 마커를 울린다. 뒤로 갈 때는 울리지 않는다.
		-- 되감기에서 소리나 이펙트가 다시 나면 안 된다. 메소드도 같다.
		if backward then
			self._applier:ApplyAt(to)
			if looped then
				self.DidLoop:Fire()
			end
		elseif looped then
			-- 끝까지 갔다가 처음으로 돌아온 것이므로 두 토막으로 나눠 본다.
			self:_fireBetween(from, self.Length)
			self:_fireBetween(0, to)

			-- 값은 지금 자리 하나로 잡고, 메소드만 두 토막을 따로 훑는다.
			self._applier:ApplyAt(to)
			self._applier:FireMethods(from, self.Length)
			self._applier:FireMethods(0, to)

			self.DidLoop:Fire()
		else
			self:_fireBetween(from, to)
			self._applier:ApplyAt(to, from)
		end
		self._lastTime = to

		-- 끝까지 갔다. Stop이 Stopped를, 페이드가 끝나면 Ended를 울린다.
		-- 이미 페이드아웃 중이면 끝에 선 채로 페이드가 마저 끝나길 기다린다.
		-- 여기서 Stop(0)을 부르면 남은 페이드가 뚝 끊긴다.
		if not self.Looped and not self._stopping and (if backward then to <= 0 else to >= self.Length) then
			self:Stop(0)
		end
	end,

	--------------------------------------------------------------------------
	-- 안쪽
	--------------------------------------------------------------------------

	-- 기준 아이템이 지금 선 자리. 재생 내내 이 값 하나로 편다.
	-- 기준이 움직이는 중에 다시 재면 그 값이 계속 밀려난다.
	--
	-- 다른 트랙이 이미 기준 아이템을 옮기고 있으면 그 트랙이 적어둔 원래
	-- 자리를 쓴다. 옮겨진 자리를 기준으로 삼으면 둘이 서로를 밀어낸다.
	_captureOrigin = function(self)
		const originItem = self._doc.originItemId and self._items[self._doc.originItemId]
		if not originItem then
			self._originCFrame = nil
			return
		end
		self._originCFrame = self._arbiter:BaseValue(originItem, Applier.PIVOT_KEY) or RigResolver.pivotOf(originItem)
	end,

	_startFade = function(self, fadeTime: number)
		if fadeTime <= 0 then
			self.WeightCurrent = self.WeightTarget
			self._fadeLeft = 0
			return
		end
		self._fadeLeft = fadeTime
	end,

	-- 비중을 목표까지 일정한 속도로 옮긴다 (Linear).
	_stepWeight = function(self, delta: number)
		if self._fadeLeft <= 0 then
			self.WeightCurrent = self.WeightTarget
			return
		end

		const gap = self.WeightTarget - self.WeightCurrent
		const step = gap * math.min(delta / self._fadeLeft, 1)

		self.WeightCurrent += step
		self._fadeLeft -= delta

		if self._fadeLeft <= 0 or math.abs(self.WeightTarget - self.WeightCurrent) <= WEIGHT_EPSILON then
			self.WeightCurrent = self.WeightTarget
			self._fadeLeft = 0

			-- 멈추는 중이었으면 여기서 정말로 멈춘다.
			if self._stopping and self.WeightCurrent <= 0 then
				self:_finishStop()
			end
		end
	end,

	-- 페이드아웃까지 끝나 이제 아무것도 안 건드린다.
	_finishStop = function(self)
		self.IsPlaying = false
		self._stopping = false
		self.WeightCurrent = 0
		self.WeightTarget = 0
		self.Ended:Fire()
	end,

	-- (from, to] 구간의 키프레임 이름과 그 안의 마커를 울린다.
	_fireBetween = function(self, from: number, to: number)
		if self.FireMarkers == false then
			return
		end

		for _, keyframe in Sampler.keyframesBetween(self._doc, from, to) do
			if keyframe.name then
				self.KeyframeReached:Fire(keyframe.name)
			end

			for _, marker in keyframe.markers do
				const signal = self._markerSignals[marker.name]
				if signal then
					signal:Fire(keyframe.t)
				end
			end
		end
	end,

	Destroy = function(self)
		self:Stop(0)

		-- Signal에는 Destroy가 없다. 연결만 끊으면 남는 것이 없다.
		self.DidLoop:DisconnectAll()
		self.Ended:DisconnectAll()
		self.KeyframeReached:DisconnectAll()
		self.Stopped:DisconnectAll()

		for _, signal in self._markerSignals do
			signal:DisconnectAll()
		end
		table.clear(self._markerSignals)

		-- 서비스가 들고 있는 목록에서도 빠진다. 안 빼면 재생이 끝난 트랙이
		-- 계속 쌓여서 프레임마다 훑는 목록만 길어진다.
		if self._forget then
			self._forget()
			self._forget = nil
		end
	end,

	__tostring = function(self)
		return `RokinIdiotAnimationTrack ({self._doc.name})`
	end,
}, {
	Type = "RokinIdiotAnimationTrack",
	Extends = RobloxStyleObject,
})

return RokinIdiotAnimationTrack
