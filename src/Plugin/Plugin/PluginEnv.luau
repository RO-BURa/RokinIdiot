--!strict
-- plugin 객체는 엔트리 스크립트에만 존재하므로 여기에 보관해서 모듈들이 공유한다.

local PluginEnv = {}

PluginEnv.VERSION = "1.0.0"
PluginEnv.AUTHOR = "@RO_BURa"

local pluginObject: Plugin? = nil

function PluginEnv.Set(p: Plugin)
	pluginObject = p
end

function PluginEnv.Get(): Plugin
	-- 이 두 곳(PluginEnv, Signal)의 문구만 번역하지 않는다. Locale이
	-- 이 둘을 require하고 있어서 반대로 걸면 require가 순환한다.
	-- 둘 다 버그일 때만 보이는 글이라 기본 언어인 영어로 적어둔다.
	assert(pluginObject, "[RokinIdiot] PluginEnv.Set has not been called yet")
	return pluginObject
end

-- 위젯은 하나뿐이다. 커서 좌표를 알아야 하는 컴포넌트들이 깊이 박혀 있어서
-- 프롭으로 계속 넘기는 대신 여기에 둔다.
local widgetObject: DockWidgetPluginGui? = nil

function PluginEnv.SetWidget(widget: DockWidgetPluginGui)
	widgetObject = widget
end

function PluginEnv.GetWidget(): DockWidgetPluginGui?
	return widgetObject
end

-- 위젯 기준 커서 좌표. GuiObject.AbsolutePosition과 같은 좌표계다.
function PluginEnv.GetMousePosition(): Vector2?
	if not widgetObject then
		return nil
	end
	return widgetObject:GetRelativeMousePosition()
end

-- 설정 키는 전부 접두사를 붙여서 다른 플러그인과 충돌하지 않게 한다.
local PREFIX = "RokinIdiot_"

function PluginEnv.GetSetting(key: string, default: any): any
	local value = PluginEnv.Get():GetSetting(PREFIX .. key)
	if value == nil then
		return default
	end
	return value
end

function PluginEnv.SetSetting(key: string, value: any)
	PluginEnv.Get():SetSetting(PREFIX .. key, value)
end

return PluginEnv
