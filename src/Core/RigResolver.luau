--!nonstrict
-- Motor6D 리그를 다룬다.
--
-- 스튜디오 편집 모드에서는 뷰포트에서 파트를 옮겨도 Motor6D.Transform은
-- 그대로다. 관절 값은 파트 위치에서 되계산해야 한다.
--
--   Part1.CFrame = Part0.CFrame * C0 * Transform * C1:Inverse()
--   Transform    = (Part0.CFrame * C0):Inverse() * Part1.CFrame * C1
--
-- 그래서 "뷰포트에서 팔을 돌린 다음 키를 찍는다"가 성립한다.
-- 반대로 재생할 때는 Transform만 써주면 파트가 따라 움직인다.
-- C0/C1은 절대 건드리지 않으므로 리그를 다시 만들어도 안 깨진다.

local RigResolver = {}

-- root 기준 경로. 찾을 수 없으면 nil.
function RigResolver.pathOf(root: Instance, instance: Instance): string?
	local segments = {}
	local current: Instance? = instance

	while current and current ~= root do
		table.insert(segments, 1, current.Name)
		current = current.Parent
	end

	if current ~= root then
		return nil
	end
	return table.concat(segments, ".")
end

export type Joint = {
	motor: Motor6D,
	path: string,
}

-- 아이템 아래의 모든 Motor6D를 경로와 함께 모은다.
-- Part0/Part1이 없는 것은 값을 계산할 수 없으므로 건너뛴다.
function RigResolver.collect(root: Instance?): { Joint }
	local joints: { Joint } = {}
	if not root then
		return joints
	end

	for _, descendant in root:GetDescendants() do
		if descendant:IsA("Motor6D") and descendant.Part0 and descendant.Part1 then
			local path = RigResolver.pathOf(root, descendant)
			if path then
				table.insert(joints, { motor = descendant, path = path })
			end
		end
	end

	-- 경로 순으로 정렬해두면 트리에 늘 같은 순서로 나온다.
	table.sort(joints, function(a, b)
		return a.path < b.path
	end)
	return joints
end

function RigResolver.hasRig(root: Instance?): boolean
	return root ~= nil and root:FindFirstChildWhichIsA("Motor6D", true) ~= nil
end

-- 지금 파트가 놓인 자리로부터 관절 값을 읽는다.
function RigResolver.readTransform(motor: Motor6D): CFrame
	local part0 = motor.Part0
	local part1 = motor.Part1
	if not part0 or not part1 then
		return CFrame.identity
	end
	return (part0.CFrame * motor.C0):Inverse() * part1.CFrame * motor.C1
end

-- 아이템의 기준 위치. 모델이면 피벗, 파트면 자기 CFrame.
function RigResolver.pivotOf(instance: Instance?): CFrame?
	if not instance then
		return nil
	end

	local ok, pivot = pcall(function()
		return (instance :: any):GetPivot()
	end)
	if ok and typeof(pivot) == "CFrame" then
		return pivot
	end
	return nil
end

function RigResolver.setPivot(instance: Instance, pivot: CFrame)
	pcall(function()
		(instance :: any):PivotTo(pivot)
	end)
end

return RigResolver
