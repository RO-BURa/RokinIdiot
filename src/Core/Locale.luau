--!nonstrict
-- 지금 언어를 들고 있다가 바뀌면 알린다. 짜임새는 UI/Theme과 같다.
-- 새 언어를 넣으려면 Strings 폴더에 문구 파일을 두고 아래 tables/ORDER에 등록한다.

local Signal = require(script.Parent.Signal)
local En = require(script.Parent.Strings.En)
local Ko = require(script.Parent.Strings.Ko)

local Locale = {}

local tables: { [string]: { [string]: string } } = {
	English = En,
	Korean = Ko,
}

Locale.ORDER = { "English", "Korean" }
Locale.DEFAULT = "English"

-- 메뉴에는 그 언어를 쓰는 사람이 읽을 이름으로 보여준다.
Locale.DISPLAY = {
	English = "English",
	Korean = "한국어",
}

Locale.Changed = Signal.new()

local currentName = Locale.DEFAULT
local current = tables[Locale.DEFAULT]

-- 고른 언어를 어디에 적어둘지는 부르는 쪽이 정한다.
--
-- 예전에는 여기서 PluginEnv를 직접 불렀는데, 그러면 Core 전체가 플러그인에
-- 묶인다. 게임에 넣는 런타임 패키지에는 plugin 객체가 없어서 그대로는 못 쓴다.
-- 접근자를 받아두면 Core는 설정이 어디에 적히는지 몰라도 된다.
--
-- 아무도 Init을 부르지 않으면 기본 언어(영어)로 그냥 동작한다.
-- 런타임에서는 오류 문구 몇 개에만 쓰이므로 그걸로 충분하다.
local setSetting: ((string, any) -> ())? = nil

function Locale.Init(get: (string, any) -> any, set: (string, any) -> ())
	setSetting = set

	local saved = get("language", Locale.DEFAULT)
	if typeof(saved) == "string" and tables[saved] then
		currentName = saved
		current = tables[saved]
	end
end

function Locale.GetName(): string
	return currentName
end

function Locale.Set(name: string)
	local strings = tables[name]
	if not strings or name == currentName then
		return
	end
	currentName = name
	current = strings
	if setSetting then
		setSetting("language", name)
	end
	Locale.Changed:Fire(name)
end

-- 문구를 찾는다. 인자를 주면 string.format으로 끼워 넣는다.
--
-- 번역이 빠진 키는 영어로, 영어에도 없으면 키를 그대로 돌려준다.
-- 문구 하나가 빠졌다고 UI가 빈칸으로 보이면 안 되기 때문이다.
-- 서식이 안 맞아 format이 실패할 때도 원문을 돌려주고 넘어간다.
function Locale.T(key: string, ...): string
	local text = current[key] or En[key] or key
	if select("#", ...) > 0 then
		local ok, formatted = pcall(string.format, text, ...)
		if ok then
			return formatted
		end
	end
	return text
end

return Locale
