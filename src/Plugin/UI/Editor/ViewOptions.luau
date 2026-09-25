--!nonstrict
-- 화면에 무엇을 보일지.
--
-- 프로젝트가 아니라 쓰는 사람에 딸린 설정이라 문서가 아니라 플러그인 설정에
-- 넣는다. 저장 파일을 남과 주고받아도 이 값은 따라가지 않는다.
--
-- 두 패널이 같은 값을 봐야 해서 (마커 줄을 숨기면 양쪽 행 시작 위치가 같이
-- 밀린다) 상태를 여기 한 곳에 두고 바뀌면 알린다.

local Signal = require(script.Parent.Parent.Parent.Core.Signal)
local PluginEnv = require(script.Parent.Parent.Parent.Plugin.PluginEnv)

local ViewOptions = {}

ViewOptions.Changed = Signal.new()

local MARKERS_SETTING = "showMarkers"

function ViewOptions.AreMarkersVisible(): boolean
	return PluginEnv.GetSetting(MARKERS_SETTING, true) == true
end

function ViewOptions.SetMarkersVisible(visible: boolean)
	if visible == ViewOptions.AreMarkersVisible() then
		return
	end
	PluginEnv.SetSetting(MARKERS_SETTING, visible)
	ViewOptions.Changed:Fire()
end

-- 키를 고르면 재생헤드를 그 자리로 옮길지.
--
-- 고른 키의 값을 보려면 어차피 그 시점을 봐야 해서 대개는 따라가는 게 맞다.
-- 다만 다른 시점을 보면서 키를 고르고 싶을 때가 있어서 끌 수 있게 둔다.
local FOLLOW_SETTING = "followSelection"

function ViewOptions.IsFollowSelectionEnabled(): boolean
	return PluginEnv.GetSetting(FOLLOW_SETTING, true) == true
end

function ViewOptions.SetFollowSelection(enabled: boolean)
	if enabled == ViewOptions.IsFollowSelectionEnabled() then
		return
	end
	PluginEnv.SetSetting(FOLLOW_SETTING, enabled)
	ViewOptions.Changed:Fire()
end

-- 눈금자·키프레임 줄·재생헤드 손잡이로 재생헤드를 옮길 때 키 선택을 풀지.
--
-- 기본은 풀지 않는다. 키를 골라둔 채로 재생헤드를 끌며 앞뒤 모습을
-- 확인하는 게 자연스럽다.
local DESELECT_ON_SCRUB_SETTING = "deselectOnScrub"

function ViewOptions.IsDeselectOnScrubEnabled(): boolean
	return PluginEnv.GetSetting(DESELECT_ON_SCRUB_SETTING, false) == true
end

function ViewOptions.SetDeselectOnScrub(enabled: boolean)
	if enabled == ViewOptions.IsDeselectOnScrubEnabled() then
		return
	end
	PluginEnv.SetSetting(DESELECT_ON_SCRUB_SETTING, enabled)
	ViewOptions.Changed:Fire()
end

return ViewOptions
