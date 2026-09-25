--!strict
-- 두 패널이 공유하는 높이 값. 여기가 어긋나면 행이 서로 밀린다.

local Metrics = {}

Metrics.HEADER_HEIGHT = 30
-- 눈금자 높이. 왼쪽 같은 자리에는 미리보기 조작 버튼이 들어가므로
-- 버튼(20px)이 답답하지 않을 만큼은 있어야 한다.
Metrics.RULER_HEIGHT = 24
-- 눈금자 밑에 붙는 마커 줄. 문서 전체에 하나뿐이라 스크롤하지 않는다.
Metrics.MARKER_HEIGHT = 18

-- 머리말 + 눈금자 (+ 켜져 있으면 마커 줄). 행 목록은 항상 이 아래에서 시작한다.
-- 마커 줄을 끌 수 있어서 상수가 아니라 함수다.
function Metrics.topHeight(showMarkers: boolean): number
	local height = Metrics.HEADER_HEIGHT + Metrics.RULER_HEIGHT
	if showMarkers then
		height += Metrics.MARKER_HEIGHT
	end
	return height
end

return Metrics
