--!nonstrict
-- 스튜디오 안에서 애니메이션을 실제로 돌려본다.
--
-- 미리보기를 켜면 먼저 건드릴 값을 전부 스냅샷하고, 끄거나 오류가 나면
-- 그대로 되돌린다. 되돌리지 못하면 사용자의 플레이스가 망가진 채로 남는다.
--
-- 값 계산은 Core/Sampler가, 실제로 꽂는 일은 Core/Applier가 한다.
-- 게임에 넣는 런타임 패키지도 그 두 모듈을
-- 그대로 쓰기 때문에 스튜디오에서 본 결과와 게임에서의 결과가 갈라지지 않는다.
--
-- 미리보기는 ChangeHistoryService에 기록하지 않는다. 실행 취소 목록이
-- 재생 프레임으로 뒤덮이면 정작 되돌리고 싶은 편집을 찾을 수 없다.

local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")

local Signal = require(script.Parent.Parent.Core.Signal)
local Schema = require(script.Parent.Parent.Core.Schema)
local RigResolver = require(script.Parent.Parent.Core.RigResolver)
local Debug = require(script.Parent.Parent.Core.Debug)
local Applier = require(script.Parent.Parent.Core.Applier)
local Store = require(script.Parent.Parent.Plugin.Store)
local PluginEnv = require(script.Parent.Parent.Plugin.PluginEnv)

-- 피벗은 속성이 아니라서 스냅샷에 이 이름으로 따로 표시한다 (Applier와 같은 값).
local PIVOT_KEY = Applier.PIVOT_KEY

-- pcall에 클로저를 넘기면 프레임마다 함수 객체가 새로 생긴다.
-- 함수와 인자를 따로 넘기면 할당이 없다.
local function readProperty(instance: Instance, property: string): any
	return (instance :: any)[property]
end

local function writeProperty(instance: Instance, property: string, value: any)
	(instance :: any)[property] = value
end

local Player = {}
Player.__index = Player

function Player.new(state)
	local self = setmetatable({
		_state = state,
		_project = state.Project,

		_enabled = false,
		_playing = false,
		_speed = 1,
		_loop = true,

		-- 되돌릴 값들. [instance][property] = { 원래값 }
		-- 값 자체가 nil일 수 있어서 한 겹 감싼다.
		_snapshot = {},
		_originCFrame = nil,
		_bindings = {},
		_frameConnection = nil,

		-- 이 프레임에 실제로 값을 썼는가. 프레임 간격을 분류할 때 쓴다.
		_wroteThisFrame = false,
		_wroteLastFrame = false,

		Changed = Signal.new(),
	}, Player)

	self._applier = self:_makeApplier()

	return self
end

--------------------------------------------------------------------------------
-- 상태
--------------------------------------------------------------------------------

function Player:IsEnabled(): boolean
	return self._enabled
end

function Player:IsPlaying(): boolean
	return self._playing
end

function Player:GetSpeed(): number
	return self._speed
end

function Player:SetSpeed(speed: number)
	self._speed = math.clamp(speed, 0.05, 8)
	self.Changed:Fire()
end

function Player:IsLooping(): boolean
	return self._loop
end

function Player:SetLooping(loop: boolean)
	self._loop = loop
	self.Changed:Fire()
end

--------------------------------------------------------------------------------
-- 켜고 끄기
--------------------------------------------------------------------------------

function Player:SetEnabled(enabled: boolean)
	if self._enabled == enabled then
		return
	end

	if enabled then
		self._enabled = true
		self:_captureContext()
		self:ApplyAt(self._state:GetTime())
	else
		self:Stop()
		self._enabled = false
		self:_restore()
	end

	self.Changed:Fire()
end

function Player:_captureContext()
	self._bindings = Store.GetBindings(self._state:GetSavedName())
	-- 바인딩이 바뀌었을 수 있으니 풀어둔 경로는 버린다.
	self._applier:ClearCache()

	-- 기준 위치는 미리보기를 켤 때 딱 한 번만 잡는다.
	-- 기준 아이템 자신이 움직이는 중에 다시 재면 그 값이 계속 밀려난다.
	if self._originCFrame == nil then
		local doc = self._project:GetDocument()
		local originItem = doc.originItemId and self._bindings[doc.originItemId]
		self._originCFrame = RigResolver.pivotOf(originItem)
	end
end

-- 바인딩이나 키가 바뀌었을 때 다시 잡고 지금 시점을 다시 적용한다.
function Player:Refresh()
	if not self._enabled or self._playing then
		return
	end
	self:_captureContext()
	self:ApplyAt(self._state:GetTime())
end

--------------------------------------------------------------------------------
-- 선택 비켜두기
--
-- Properties 패널은 선택된 인스턴스의 속성이 바뀌면 매 프레임 다시 그린다.
-- 그게 재생 중 멈춤의 실제 원인이다. 우리 계산은 프레임당 수십 마이크로초인데
-- 패널 갱신은 그보다 훨씬 크고, 우리가 줄일 수 있는 비용이 아니다.
--
-- 그래서 재생하는 동안에는 우리가 건드릴 오브젝트만 선택에서 빼둔다.
-- 나머지 선택은 그대로 두고, 정지하면 원래대로 돌려놓는다.
-- (게임에서는 이 비용이 없다. 에디터에서만 겪는 문제다)
--------------------------------------------------------------------------------

local DESELECT_SETTING = "deselectDuringPlayback"

function Player.IsDeselectEnabled(): boolean
	return PluginEnv.GetSetting(DESELECT_SETTING, true) == true
end

function Player.SetDeselectEnabled(enabled: boolean)
	PluginEnv.SetSetting(DESELECT_SETTING, enabled)
end

-- 이번 재생에서 우리가 값을 쓸 인스턴스들.
function Player:_targetInstances(): { [Instance]: true }
	local targets = {}

	for _, track in self._project:GetDocument().tracks do
		local instance = if track.kind == Schema.TRACK_KIND.TRANSFORM
			then self._bindings[track.itemId]
			else self._applier:Resolve(track)

		if instance then
			targets[instance] = true

			-- Motor6D를 건드리면 그 관절이 움직이는 파트도 패널에서 갱신된다.
			if instance:IsA("Motor6D") then
				if instance.Part0 then
					targets[instance.Part0] = true
				end
				if instance.Part1 then
					targets[instance.Part1] = true
				end
			end
		end
	end

	return targets
end

function Player:_stashSelection()
	if not Player.IsDeselectEnabled() then
		return
	end

	local previous = Selection:Get()
	if #previous == 0 then
		return
	end

	local targets = self:_targetInstances()
	local kept = {}
	local removedAny = false

	for _, instance in previous do
		if targets[instance] then
			removedAny = true
		else
			table.insert(kept, instance)
		end
	end

	if not removedAny then
		return
	end

	self._stashedSelection = previous
	Selection:Set(kept)
end

function Player:_restoreSelection()
	local previous = self._stashedSelection
	if not previous then
		return
	end
	self._stashedSelection = nil

	-- 그 사이에 지워진 것은 빼고 되돌린다.
	local alive = {}
	for _, instance in previous do
		if instance:IsDescendantOf(game) then
			table.insert(alive, instance)
		end
	end
	Selection:Set(alive)
end

--------------------------------------------------------------------------------
-- 재생
--------------------------------------------------------------------------------

function Player:Play()
	if self._playing then
		return
	end
	if not self._enabled then
		self:SetEnabled(true)
	end

	local doc = self._project:GetDocument()
	-- 끝에 서 있는데 재생을 누르면 처음부터 다시 본다는 뜻이다.
	if self._state:GetTime() >= doc.duration - 1e-4 then
		self._state:SetTime(0)
	end

	self._playing = true
	self:_stashSelection()

	self._frameConnection = RunService.Heartbeat:Connect(function(delta)
		self:_step(delta)
	end)

	self.Changed:Fire()
end

function Player:Stop()
	if not self._playing then
		return
	end

	self._playing = false
	if self._frameConnection then
		self._frameConnection:Disconnect()
		self._frameConnection = nil
	end

	self:_restoreSelection()
	self.Changed:Fire()
end

function Player:_step(delta: number)
	-- delta는 "지난 프레임이 실제로 걸린 시간"이다.
	-- 우리 계산은 프레임당 수십 마이크로초라, 이 값이 크다면 시간은 우리 밖에서
	-- 새고 있다는 뜻이다. 값을 실제로 쓴 프레임과 그렇지 않은 프레임을 나눠
	-- 재면 "쓰기가 원인인가"에 바로 답이 나온다.
	Debug.record(if self._wroteLastFrame then "debug.frameWithWrite" else "debug.frameNoWrite", delta)
	Debug.frame(delta)
	self._wroteThisFrame = false

	local doc = self._project:GetDocument()
	local from = self._state:GetTime()
	local to = from + delta * self._speed

	if to >= doc.duration then
		if self._loop then
			-- 끝까지 한 번 훑어 마지막 이벤트까지 흘려보낸 뒤 처음으로 돌아간다.
			self:ApplyAt(doc.duration, from)
			self._state:SetTime(0)
			self._wroteLastFrame = self._wroteThisFrame
			return
		end

		self._state:SetTime(doc.duration)
		self:ApplyAt(doc.duration, from)
		self:Stop()
		self._wroteLastFrame = self._wroteThisFrame
		return
	end

	self._state:SetTime(to)
	self:ApplyAt(to, from)
	self._wroteLastFrame = self._wroteThisFrame
end

--------------------------------------------------------------------------------
-- 값 적용
--------------------------------------------------------------------------------

-- 원래 값을 아직 안 적어뒀으면 지금 적어둔다.
function Player:_remember(instance: Instance, property: string)
	local properties = self._snapshot[instance]
	if not properties then
		properties = {}
		self._snapshot[instance] = properties
	end
	if properties[property] ~= nil then
		return
	end

	local ok, value = pcall(readProperty, instance, property)
	if ok then
		properties[property] = { value }
	end
end

function Player:_restore()
	for instance, properties in self._snapshot do
		-- 미리보기 도중에 지워진 오브젝트는 건너뛴다.
		if instance:IsDescendantOf(game) then
			for property, box in properties do
				if property == PIVOT_KEY then
					RigResolver.setPivot(instance, box[1])
				else
					pcall(writeProperty, instance, property, box[1])
				end
			end
		end
	end
	table.clear(self._snapshot)
	self._originCFrame = nil
end

--------------------------------------------------------------------------------
-- 값 꽂기
--
-- 실제로 값을 쓰는 일은 Core/Applier가 한다. 런타임 패키지도 같은 모듈을
-- 쓰기 때문에 스튜디오에서 본 것과 게임에서 도는 것이 갈라지지 않는다.
-- 여기는 그 모듈에 "원래 값이 뭐였는지"와 "무엇이 무엇을 가리키는지"만 대준다.
--------------------------------------------------------------------------------

function Player:_makeApplier()
	return Applier.new({
		GetDocument = function()
			return self._project:GetDocument()
		end,
		ResolveItem = function(itemId: number): Instance?
			return self._bindings[itemId]
		end,
		OriginCFrame = function(): CFrame?
			return self._originCFrame
		end,
		Remember = function(instance: Instance, property: string)
			if property == PIVOT_KEY then
				local pivot = RigResolver.pivotOf(instance)
				if pivot then
					self:_rememberPivot(instance, pivot)
				end
				return
			end
			self:_remember(instance, property)
		end,
		BaseValue = function(instance: Instance, property: string)
			return self:_baseValue(instance, property)
		end,
		RestoreProperty = function(instance: Instance, property: string)
			self:_restoreProperty(instance, property)
		end,
		OnWrite = function()
			self._wroteThisFrame = true
		end,
	})
end

-- fromTime을 주면 그 사이를 지나간 메소드도 함께 호출한다.
-- 스크럽처럼 값만 보고 싶을 때는 생략한다.
function Player:ApplyAt(time: number, fromTime: number?)
	if not self._enabled then
		return
	end

	-- 우리가 쓰는 동안임을 밖에서 알 수 있게 표시해둔다.
	-- 속성 변경을 듣고 키에 적어넣는 쪽이 우리가 쓴 값까지 받아 적으면
	-- 재생헤드가 지나갈 때마다 키가 제멋대로 바뀐다.
	self._applying = true
	self._applier:ApplyAt(time, fromTime)
	self._applying = false
end

-- 지금 이 순간 우리가 값을 쓰고 있는가.
function Player:IsApplying(): boolean
	return self._applying == true
end

-- 스냅샷에 적어둔 원래 값. 첫 키 앞 구간을 여기서부터 잇는다.
function Player:_baseValue(instance: Instance, property: string): any
	local properties = self._snapshot[instance]
	local box = properties and properties[property]
	return if box then box[1] else nil
end

-- 스냅샷에 적어둔 원래 값으로 되돌린다. 스냅샷 자체는 남겨둔다.
-- (미리보기를 끌 때 다시 한 번 전체 원복이 돌기 때문)
function Player:_restoreProperty(instance: Instance, property: string)
	local properties = self._snapshot[instance]
	local box = properties and properties[property]
	if not box then
		return
	end

	if property == PIVOT_KEY then
		RigResolver.setPivot(instance, box[1])
		return
	end
	pcall(writeProperty, instance, property, box[1])
end

-- 피벗은 속성이 아니라서 따로 기억한다.
function Player:_rememberPivot(instance: Instance, pivot: CFrame)
	local properties = self._snapshot[instance]
	if not properties then
		properties = {}
		self._snapshot[instance] = properties
	end
	if properties[PIVOT_KEY] == nil then
		properties[PIVOT_KEY] = { pivot }
	end
end

function Player:Destroy()
	self:Stop()
	self:_restoreSelection()
	if self._enabled then
		self._enabled = false
		self:_restore()
	end
	self.Changed:Destroy()
end

return Player
