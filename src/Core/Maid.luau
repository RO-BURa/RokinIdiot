--!strict
-- 정리 대상을 모아뒀다가 한 번에 해제한다.
-- Instance / RBXScriptConnection / Signal.Connection / 함수 / :Destroy() 가진 객체를 받는다.

local Locale = require(script.Parent.Locale)

local Maid = {}
Maid.__index = Maid

function Maid.new()
	return setmetatable({ _tasks = {} }, Maid)
end

function Maid:Give<T>(item: T): T
	table.insert(self._tasks, item)
	return item
end

local function cleanup(item: any)
	if typeof(item) == "function" then
		item()
	elseif typeof(item) == "RBXScriptConnection" then
		item:Disconnect()
	elseif typeof(item) == "Instance" then
		item:Destroy()
	elseif typeof(item) == "table" then
		if item.Disconnect then
			item:Disconnect()
		elseif item.Destroy then
			item:Destroy()
		end
	end
end

function Maid:DoCleaning()
	local tasks = self._tasks
	self._tasks = {}
	-- 나중에 추가된 것부터 해제해야 의존 관계가 꼬이지 않는다.
	for i = #tasks, 1, -1 do
		local ok, err = pcall(cleanup, tasks[i])
		if not ok then
			warn(Locale.T("error.cleanup") .. tostring(err))
		end
	end
end

Maid.Destroy = Maid.DoCleaning

return Maid
