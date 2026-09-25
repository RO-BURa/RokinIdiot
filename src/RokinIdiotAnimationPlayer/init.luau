--!nonstrict
-- 게임 안에서 저장된 애니메이션을 재생한다.
--
--   const AnimationPlayer = require(ReplicatedStorage.RokinIdiotAnimationPlayer)
--
--   const track = AnimationPlayer:LoadAnimation(save, character, sword)
--   track.Looped = true
--   track:Play(0.3)
--
--   track:GetMarkerReachedSignal("Impact"):Connect(function()
--       hitbox:Fire()
--   end)
--
-- Core는 에디터와 같은 소스다. 값 계산(Sampler)과 실제로 꽂는 일(Applier)을
-- 그대로 쓰기 때문에 스튜디오에서 본 것과 게임에서 도는 것이 갈라지지 않는다.
--
-- 클라이언트에서 돌리는 것을 권한다. 서버에서도 돌아가지만 속성 변경이 전부
-- 복제되어 네트워크를 많이 쓴다. Motor6D.Transform은 아예 복제되지 않아서
-- 리그 포즈는 서버에서 돌려도 다른 사람에게 보이지 않는다.

const HttpService = game:GetService("HttpService")
const RunService = game:GetService("RunService")

const Packages = script:FindFirstChild("Packages") or script.Parent.Packages
const Core = script:FindFirstChild("Core") or script.Parent.Core

const XClass = require(Packages.XClass)
const RobloxStyleObject = require(Packages.RobloxStyleObject)

const Schema = require(Core.Schema)

const Arbiter = require(script.Arbiter)
const RokinIdiotAnimationTrack = require(script.RokinIdiotAnimationTrack)

export type RokinIdiotAnimationTrack = RokinIdiotAnimationTrack.RokinIdiotAnimationTrack
export type Signal = RokinIdiotAnimationTrack.Signal
export type RobloxStyleObject = RokinIdiotAnimationTrack.RobloxStyleObject

export type RokinIdiotAnimationPlayer = RobloxStyleObject & {
	read LoadAnimation: (
		self: RokinIdiotAnimationPlayer,
		save: StringValue | Instance | string,
		...any
	) -> RokinIdiotAnimationTrack,
	read GetPlayingTracks: (self: RokinIdiotAnimationPlayer) -> { RokinIdiotAnimationTrack },
	read StopAll: (self: RokinIdiotAnimationPlayer, fadeTime: number?) -> (),
	read Destroy: (self: RokinIdiotAnimationPlayer) -> (),
}

export type RokinIdiotAnimationPlayerClass = {
	read new: () -> RokinIdiotAnimationPlayer,
}

--------------------------------------------------------------------------------
-- 저장 값 읽기
--------------------------------------------------------------------------------

-- StringValue든, 그걸 담은 폴더든, JSON 문자열이든 받는다.
-- (문서, 그 문서를 담고 있던 StringValue)
const function readSave(save: any): (any, StringValue?)
	local json = nil
	local value = nil

	if typeof(save) == "string" then
		json = save
	elseif typeof(save) == "Instance" then
		if save:IsA("StringValue") then
			value = save
		else
			value = save:FindFirstChildWhichIsA("StringValue")
		end
		json = if value then value.Value else nil
	end

	if json == nil or json == "" then
		error("[RokinIdiot] 재생할 애니메이션을 찾지 못했습니다.", 0)
	end

	const ok, decoded = pcall(HttpService.JSONDecode, HttpService, json)
	if not ok or typeof(decoded) ~= "table" then
		error("[RokinIdiot] 저장 파일을 읽을 수 없습니다.", 0)
	end

	return Schema.migrate(decoded), value
end

-- 아이템은 자리로 이어 넘기거나 (자리 = 아이템 Id) 표로 넘긴다.
-- 두 번째 인자가 Instance면 앞의 방식, table이면 뒤의 방식이다.
--
-- 넘어오지 않은 아이템은 그냥 빠진다. 일부러 하나만 넘기고 쓰는 경우가 있고,
-- 그때마다 출력창이 더러워지면 안 된다.
const function readItems(doc, ...): ({ [number]: Instance }, { number })
	local items = {}

	const first = ...
	if typeof(first) == "table" then
		for id, instance in first do
			if typeof(id) == "number" and typeof(instance) == "Instance" then
				items[id] = instance
			end
		end
	else
		const count = select("#", ...)
		for index = 1, count do
			const instance = select(index, ...)
			if typeof(instance) == "Instance" then
				items[index] = instance
			end
		end
	end

	local missing = {}
	for _, item in doc.items do
		if items[item.id] == nil then
			table.insert(missing, item.id)
		end
	end

	return items, missing
end

--------------------------------------------------------------------------------
-- 서비스
--------------------------------------------------------------------------------

const RokinIdiotAnimationPlayer = XClass.new(function(self)
	XClass.Super(self, RobloxStyleObject.new)

	self._arbiter = Arbiter.new()
	self._tracks = {}
	self._connection = nil

	-- 재생을 시작한 차례. 섞을 수 없는 값이 같은 우선순위로 부딪히면
	-- 먼저 시작한 쪽이 가져간다.
	self._nextOrder = 1
end, {
	LoadAnimation = function(self, save: any, ...)
		const doc, value = readSave(save)
		const items, missing = readItems(doc, ...)

		local track
		track = RokinIdiotAnimationTrack.new({
			Document = doc,
			Items = items,
			MissingItems = missing,
			Animation = value,
			Arbiter = self._arbiter,
			Order = self._nextOrder,
			Wake = function()
				self:_startStepping()
			end,
			Forget = function()
				const index = table.find(self._tracks, track)
				if index then
					table.remove(self._tracks, index)
				end
			end,
		})

		self._nextOrder += 1
		table.insert(self._tracks, track)
		return track
	end,

	GetPlayingTracks = function(self)
		local playing = {}
		for _, track in self._tracks do
			if track.IsPlaying then
				table.insert(playing, track)
			end
		end
		return playing
	end,

	StopAll = function(self, fadeTime: number?)
		for _, track in self._tracks do
			if track.IsPlaying then
				track:Stop(fadeTime)
			end
		end
	end,

	--------------------------------------------------------------------------
	-- 한 프레임
	--
	-- 트랙마다 따로 Heartbeat를 걸지 않는다. 값을 모았다가 한 번에 중재해야
	-- 하는데, 연결이 여럿이면 그 순서를 우리가 정할 수 없다.
	--------------------------------------------------------------------------

	_step = function(self, delta: number)
		local anyPlaying = false

		for index = #self._tracks, 1, -1 do
			const track = self._tracks[index]
			track:Step(delta)
			if track.IsPlaying then
				anyPlaying = true
			end
		end

		-- 모인 값을 중재해서 실제로 쓴다. 아무도 안 맡긴 자리는 여기서 원복된다.
		self._arbiter:Flush()

		-- 마지막 트랙이 이번 프레임에 끝났어도 그 트랙이 잡은 값은 방금 쓰였다.
		-- 되돌리는 건 다음 Flush라서, 들고 있는 자리가 없어질 때까지 더 돈다.
		if not anyPlaying and self._arbiter:IsIdle() then
			self:_stopStepping()
		end
	end,

	_startStepping = function(self)
		if self._connection then
			return
		end
		self._connection = RunService.Heartbeat:Connect(function(delta)
			self:_step(delta)
		end)
	end,

	_stopStepping = function(self)
		if not self._connection then
			return
		end
		self._connection:Disconnect()
		self._connection = nil
	end,

	Destroy = function(self)
		self:_stopStepping()

		-- track:Destroy()가 이 목록에서 스스로 빠지므로 사본을 돈다.
		for _, track in table.clone(self._tracks) do
			track:Destroy()
		end
		table.clear(self._tracks)
		self._arbiter:Destroy()
	end,

	__tostring = "RokinIdiotAnimationPlayer",
}, {
	Type = "RokinIdiotAnimationPlayer",
	Extends = RobloxStyleObject,
}) :: RokinIdiotAnimationPlayer

-- 서비스는 하나만 쓴다. 여럿이면 Arbiter가 갈라져서 우선순위 중재가 깨진다.
return RokinIdiotAnimationPlayer.new()
