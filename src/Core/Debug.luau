--!nonstrict
-- 성능 기록판.
--
-- 어디서 시간이 새는지 보려고 재는 곳마다 여기에 적어둔다.
-- Menu → Print Debug Log 를 누르면 그동안 모인 걸 출력한다.
--
-- os.time()은 1초 단위라 이런 걸 재면 늘 0이 나온다. os.clock()을 쓴다.
--
-- 한 번의 값만 보면 프레임마다 튀어서 판단이 안 되므로, 마지막 값과 함께
-- 호출 수·합계·최대치도 같이 들고 있는다. 평균은 출력할 때 계산한다.

local Locale = require(script.Parent.Locale)

local Debug = {}

export type Stat = {
	count: number,
	total: number,
	last: number,
	max: number,
}

Debug.stats = {} :: { [string]: Stat }

-- 꺼져 있으면 record/bump가 바로 돌아온다.
--
-- 재는 곳이 프레임마다 도는 자리(Sampler, Player)에 있어서, 게임에서까지
-- 표를 건드리게 두면 아무도 안 보는 통계에 값을 치르게 된다.
-- 에디터가 켤 때까지는 꺼져 있는 게 맞다.
Debug.Enabled = false

function Debug.record(name: string, seconds: number)
	if not Debug.Enabled then
		return
	end

	local stat = Debug.stats[name]
	if not stat then
		stat = { count = 0, total = 0, last = 0, max = 0 }
		Debug.stats[name] = stat
	end

	stat.count += 1
	stat.total += seconds
	stat.last = seconds
	if seconds > stat.max then
		stat.max = seconds
	end
end

-- 시간이 아니라 횟수만 셀 때.
function Debug.bump(name: string, amount: number?)
	if not Debug.Enabled then
		return
	end

	local stat = Debug.stats[name]
	if not stat then
		stat = { count = 0, total = 0, last = 0, max = 0 }
		Debug.stats[name] = stat
	end
	stat.count += amount or 1
end

function Debug.clear()
	Debug.stats = {}
end

-- 간헐적인 멈춤은 평균으로는 안 보인다. 평균 20ms인데 60프레임 중 하나가
-- 200ms면 눈에는 확실히 걸리지만 평균은 멀쩡해 보인다.
-- 그래서 프레임 간격은 몇 개가 얼마나 늦었는지 구간별로 센다.
local FRAME_LIMITS = { 0.020, 0.034, 0.050, 0.100 }
local FRAME_LABELS = {
	"debug.band1",
	"debug.band2",
	"debug.band3",
	"debug.band4",
	"debug.band5",
}

function Debug.frame(seconds: number)
	for index, limit in FRAME_LIMITS do
		if seconds < limit then
			Debug.bump(FRAME_LABELS[index])
			return
		end
	end
	Debug.bump(FRAME_LABELS[#FRAME_LABELS])
end

local function milliseconds(seconds: number): string
	return string.format("%.4fms", seconds * 1000)
end

function Debug.report(): string
	local names = {}
	for name in Debug.stats do
		table.insert(names, name)
	end
	table.sort(names, function(a, b)
		return Debug.stats[a].total > Debug.stats[b].total
	end)

	if #names == 0 then
		return Locale.T("debug.empty")
	end

	local lines = { Locale.T("debug.header") }

	for _, name in names do
		local stat = Debug.stats[name]
		if stat.total == 0 and stat.count > 0 then
			-- 횟수만 센 항목
			table.insert(lines, string.format(Locale.T("debug.countLine"), Locale.T(name), stat.count))
		else
			table.insert(
				lines,
				string.format(
					Locale.T("debug.statLine"),
					Locale.T(name),
					stat.count,
					milliseconds(stat.total),
					milliseconds(stat.total / math.max(stat.count, 1)),
					milliseconds(stat.max),
					milliseconds(stat.last)
				)
			)
		end
	end

	return table.concat(lines, "\n")
end

return Debug
