--!nonstrict
-- 현재 테마를 들고 있다가 바뀌면 알린다.
-- 새 테마를 추가하려면 Style 폴더에 토큰 파일을 넣고 여기 themes/ORDER에 등록한다.

local Signal = require(script.Parent.Parent.Core.Signal)
local PluginEnv = require(script.Parent.Parent.Plugin.PluginEnv)
local Dark = require(script.Parent.Style.Dark)
local Light = require(script.Parent.Style.Light)

local Theme = {}

export type Tokens = typeof(Dark)

local themes: { [string]: Tokens } = {
	Dark = Dark,
	Light = Light,
}

Theme.ORDER = { "Dark", "Light" }
Theme.DEFAULT = "Dark"

Theme.Changed = Signal.new()

local current: Tokens = themes[Theme.DEFAULT]

-- 플러그인 설정에서 마지막으로 고른 테마를 복원한다.
function Theme.Init()
	local saved = PluginEnv.GetSetting("theme", Theme.DEFAULT)
	if typeof(saved) == "string" and themes[saved] then
		current = themes[saved]
	end
end

function Theme.Get(): Tokens
	return current
end

function Theme.GetName(): string
	return current.name
end

function Theme.Set(name: string)
	local tokens = themes[name]
	if not tokens or tokens == current then
		return
	end
	current = tokens
	PluginEnv.SetSetting("theme", name)
	Theme.Changed:Fire(current)
end

return Theme
