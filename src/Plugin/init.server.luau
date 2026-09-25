--!nonstrict
-- RokinIdiot — 특수 애니메이션 에디터 플러그인 엔트리 포인트
--
-- 실행 모드에서는 스크립트가 게임 안에 복사돼도 아무 일도 하지 않게 막는다.

if not plugin then
	return
end

local PluginEnv = require(script.Plugin.PluginEnv)
local Theme = require(script.UI.Theme)
local Locale = require(script.Core.Locale)
local Debug = require(script.Core.Debug)
local App = require(script.UI.App)

PluginEnv.Set(plugin)
-- 성능 기록은 에디터에서만 켠다. 게임에 들어가는 쪽은 끈 채로 둔다.
Debug.Enabled = true

Theme.Init()
-- Core는 설정을 어디에 적는지 모른다. 접근자를 여기서 넘겨준다.
Locale.Init(PluginEnv.GetSetting, PluginEnv.SetSetting)

local WIDGET_ID = "RokinIdiot_Main"

local toolbar = plugin:CreateToolbar("RokinIdiot")
-- 아이콘은 아직 없다. 빈 문자열이면 스튜디오가 기본 아이콘을 쓴다.
-- 툴바 버튼은 플러그인이 뜰 때 한 번만 만들어진다. 언어를 바꿔도
-- 이 툴팁만은 스튜디오를 다시 켜야 바뀐다.
local toggleButton = toolbar:CreateButton("RokinIdiot", Locale.T("app.tooltip"), "")
toggleButton.ClickableWhenViewportHidden = true

local widget = plugin:CreateDockWidgetPluginGui(
	WIDGET_ID,
	DockWidgetPluginGuiInfo.new(
		Enum.InitialDockState.Float,
		false, -- 초기 활성화 여부
		false, -- 저장된 상태 무시 여부
		980, -- 기본 너비
		580, -- 기본 높이
		640, -- 최소 너비
		380 -- 최소 높이
	)
)
widget.Name = "RokinIdiot"
widget.Title = "RokinIdiot"
widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

PluginEnv.SetWidget(widget)

local app: any = nil

local function mount()
	if app then
		return
	end
	app = App.new(widget)
end

local function unmount()
	if not app then
		return
	end
	app:Destroy()
	app = nil
end

-- 위젯이 닫히면 UI를 통째로 버린다. 편집 잠금도 App:Destroy에서 같이 풀린다.
local function syncToWidget()
	toggleButton:SetActive(widget.Enabled)
	if widget.Enabled then
		mount()
	else
		unmount()
	end
end

toggleButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

widget:GetPropertyChangedSignal("Enabled"):Connect(syncToWidget)

plugin.Unloading:Connect(unmount)

syncToWidget()
