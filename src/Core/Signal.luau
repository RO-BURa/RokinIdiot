--!strict
-- 경량 이벤트. BindableEvent보다 가볍고 테이블 인자를 그대로 넘길 수 있다.

export type Connection = { Disconnect: (Connection) -> () }

local Connection = {}
Connection.__index = Connection

local function disconnect(self)
	if self._dead then
		return
	end
	self._dead = true
	local handlers = self._signal._handlers
	local index = table.find(handlers, self._fn)
	if index then
		table.remove(handlers, index)
	end
end
Connection.Disconnect = disconnect

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(fn: (...any) -> ()): Connection
	table.insert(self._handlers, fn)
	return (setmetatable({ _signal = self, _fn = fn, _dead = false }, Connection) :: any) :: Connection
end

function Signal:Fire(...: any)
	-- 핸들러가 재생 중에 스스로를 해제할 수 있으므로 복사본을 순회한다.
	for _, fn in table.clone(self._handlers) do
		local ok, err = pcall(fn, ...)
		if not ok then
			-- Locale이 Signal을 require하므로 여기서는 번역하지 않는다 (순환).
			warn("[RokinIdiot] Error in a signal handler: " .. tostring(err))
		end
	end
end

function Signal:Destroy()
	table.clear(self._handlers)
end

return Signal
