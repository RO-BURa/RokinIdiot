--!strict
-- 플레이스당 한 명만 편집하게 막는다.
--
-- 미리보기가 실제 인스턴스를 건드리기 때문에 두 명이 동시에 작업하면
-- 서로의 재생이 겹쳐서 데이터가 꼬인다. Team Create에서 저장 폴더가 공유되는 걸
-- 이용해서, 폴더 안 _Lock StringValue에 하트비트를 찍어 점유를 표시한다.
--
-- 스튜디오가 크래시하면 해제 코드가 안 돌기 때문에 STALE_AFTER가 지나면
-- 다른 사람이 인수할 수 있게 열어둔다.

local HttpService = game:GetService("HttpService")
local StudioService = game:GetService("StudioService")

local Signal = require(script.Parent.Parent.Core.Signal)
local Debug = require(script.Parent.Parent.Core.Debug)
local Store = require(script.Parent.Store)
local Locale = require(script.Parent.Parent.Core.Locale)

local HEARTBEAT_INTERVAL = 15
local STALE_AFTER = 60

local Lock = {}

export type Holder = {
	userId: number,
	userName: string,
	heartbeat: number,
	sessionId: string,
}

-- 같은 계정으로 스튜디오를 두 개 띄운 경우를 구분하기 위한 세션 식별자.
local sessionId = HttpService:GenerateGUID(false)
local held = false
local heartbeatThread: thread? = nil

-- 잠금을 다른 세션에게 빼앗겼을 때 알린다.
Lock.Lost = Signal.new()

local function localUserId(): number
	local ok, id = pcall(function()
		return StudioService:GetUserId()
	end)
	return (ok and tonumber(id)) or 0
end

-- 사용자 표기는 번호로만 한다.
--
-- 스튜디오에는 로컬 사용자 이름을 알려주는 API가 없어서 이름을 쓰려면
-- Players:GetNameFromUserIdAsync 같은 웹 조회가 필요하다. 그건 yield하는
-- 호출이라 부르는 자리를 멈춰 세운다. 잠금은 userId와 세션 id로 구분하니
-- 이름은 애초에 필요 없다. 안내 문구가 조금 딱딱해지는 대신 네트워크를 안 탄다.
local function localUserName(): string
	local userId = localUserId()
	if userId <= 0 then
		return Locale.T("lock.unknownUser")
	end
	return Locale.T("lock.userNamed", tostring(userId))
end

local function lockValue(create: boolean): StringValue?
	-- 잠금을 확인만 할 때는 저장 폴더를 새로 만들지 않는다.
	local folder = if create then Store.GetFolder() else Store.FindFolder()
	if not folder then
		return nil
	end

	local existing = folder:FindFirstChild(Store.LOCK_NAME)
	if existing and existing:IsA("StringValue") then
		return existing
	end
	if not create then
		return nil
	end
	if existing then
		existing:Destroy()
	end
	local created = Instance.new("StringValue")
	created.Name = Store.LOCK_NAME
	created.Parent = folder
	return created
end

local function readHolder(): Holder?
	local value = lockValue(false)
	if not value or value.Value == "" then
		return nil
	end

	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, value.Value)
	if not ok or typeof(decoded) ~= "table" then
		return nil
	end

	return {
		userId = tonumber(decoded.userId) or 0,
		userName = tostring(decoded.userName or Locale.T("lock.unknownUser")),
		heartbeat = tonumber(decoded.heartbeat) or 0,
		sessionId = tostring(decoded.sessionId or ""),
	}
end

local function writeHolder()
	local value = lockValue(true)
	if not value then
		return
	end
	value.Value = HttpService:JSONEncode({
		userId = localUserId(),
		userName = localUserName(),
		heartbeat = os.time(),
		sessionId = sessionId,
	})
end

local function isStale(holder: Holder): boolean
	return os.time() - holder.heartbeat > STALE_AFTER
end

local function isMine(holder: Holder): boolean
	return holder.sessionId == sessionId
end

function Lock.GetHolder(): Holder?
	return readHolder()
end

-- 다른 세션이 살아있는 잠금을 쥐고 있으면 그 정보를 돌려준다.
function Lock.GetBlocker(): Holder?
	local holder = readHolder()
	if not holder or isMine(holder) or isStale(holder) then
		return nil
	end
	return holder
end

function Lock.IsHeld(): boolean
	return held
end

local function stopHeartbeat()
	if heartbeatThread then
		task.cancel(heartbeatThread)
		heartbeatThread = nil
	end
end

local function startHeartbeat()
	stopHeartbeat()
	heartbeatThread = task.spawn(function()
		while true do
			task.wait(HEARTBEAT_INTERVAL)
			if not held then
				break
			end

			local holder = readHolder()
			-- 다른 세션이 stale로 보고 인수해갔다면 조용히 물러난다.
			if holder and not isMine(holder) and not isStale(holder) then
				held = false
				heartbeatThread = nil
				Lock.Lost:Fire(holder)
				break
			end

			-- 이제 웹 호출이 없다. 정말 안 걸리는지 확인용으로만 재둔다.
			local heartbeatAt = os.clock()
			writeHolder()
			Debug.record("debug.lockHeartbeat", os.clock() - heartbeatAt)
		end
	end)
end

-- 잠금을 잡는다. 실패하면 (false, 현재 점유자)를 돌려준다.
-- force가 참이면 stale 여부와 관계없이 빼앗는다.
function Lock.Acquire(force: boolean?): (boolean, Holder?)
	local blocker = Lock.GetBlocker()
	if blocker and not force then
		return false, blocker
	end

	held = true
	writeHolder()
	startHeartbeat()
	return true, nil
end

function Lock.Release()
	stopHeartbeat()
	if not held then
		return
	end
	held = false

	-- 내가 쥔 잠금일 때만 지운다. 이미 남이 인수해갔으면 건드리지 않는다.
	local holder = readHolder()
	if holder and isMine(holder) then
		local value = lockValue(false)
		if value then
			value:Destroy()
		end
	end
end

function Lock.DescribeHolder(holder: Holder): string
	local ago = math.max(os.time() - holder.heartbeat, 0)
	return Locale.T("lock.holder", holder.userName, ago)
end

return Lock
