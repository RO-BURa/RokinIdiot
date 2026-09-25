--!nonstrict
-- 모든 UI 컴포넌트의 베이스 클래스.
--
-- 상속:
--   local Button = Component.extend()
--   function Button.new(props)
--       local self = Component.construct(Button)
--       ...
--       return self
--   end

local Maid = require(script.Parent.Parent.Core.Maid)
local Theme = require(script.Parent.Theme)
local Locale = require(script.Parent.Parent.Core.Locale)

local Component = {}
Component.__index = Component

-- 새 하위 클래스를 만든다.
function Component.extend()
	local class = setmetatable({}, { __index = Component })
	class.__index = class
	return class
end

-- 하위 클래스의 .new 안에서 인스턴스를 만들 때 쓴다.
function Component.construct(class)
	return setmetatable({
		_maid = Maid.new(),
		_destroyed = false,
		Instance = nil,
	}, class or Component)
end

-- 테마가 바뀔 때마다 apply를 다시 호출한다. 등록 즉시 한 번 호출된다.
function Component:BindTheme(apply: (any) -> ())
	apply(Theme.Get())
	self._maid:Give(Theme.Changed:Connect(function(tokens)
		if not self._destroyed then
			apply(tokens)
		end
	end))
end

-- 언어가 바뀔 때마다 apply를 다시 호출한다. 등록 즉시 한 번 호출된다.
-- 만들 때 한 번 넣고 마는 글자들을 여기서 다시 넣어줘야
-- 언어를 바꿨을 때 화면이 따라 바뀐다.
function Component:BindLocale(apply: () -> ())
	apply()
	self._maid:Give(Locale.Changed:Connect(function()
		if not self._destroyed then
			apply()
		end
	end))
end

-- 이 컴포넌트와 수명을 같이 할 대상을 등록한다.
function Component:Track<T>(item: T): T
	return self._maid:Give(item)
end

function Component:SetParent(parent: Instance?)
	if self.Instance then
		self.Instance.Parent = parent
	end
end

function Component:SetVisible(visible: boolean)
	if self.Instance then
		self.Instance.Visible = visible
	end
end

function Component:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	self._maid:DoCleaning()
	if self.Instance then
		self.Instance:Destroy()
		self.Instance = nil
	end
end

return Component
