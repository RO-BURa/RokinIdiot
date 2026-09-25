--!nonstrict
-- 에디터의 화면 상태. 문서에 저장되지 않는 것들만 들고 있다.
-- (접힘, 선택, 재생헤드 위치, 스크롤 동기화)

local Signal = require(script.Parent.Parent.Parent.Core.Signal)
local Outline = require(script.Parent.Parent.Parent.Core.Outline)
local Ops = require(script.Parent.Parent.Parent.Core.Ops)
local Schema = require(script.Parent.Parent.Parent.Core.Schema)
local PathSpec = require(script.Parent.Parent.Parent.Core.PathSpec)
local Value = require(script.Parent.Parent.Parent.Core.Value)
local Sampler = require(script.Parent.Parent.Parent.Core.Sampler)
local RigResolver = require(script.Parent.Parent.Parent.Core.RigResolver)
local Store = require(script.Parent.Parent.Parent.Plugin.Store)
local Locale = require(script.Parent.Parent.Parent.Core.Locale)

-- 리그 관절과 아이템 위치 트랙이 쓰는 고정 타겟 이름.
local MOTOR_TARGET = "Transform"
local TRANSFORM_TARGET = "Pivot"

local EditorState = {}
EditorState.__index = EditorState

function EditorState.new(app, project)
	local self = setmetatable({
		App = app,
		Project = project,

		_collapsed = {},
		_selectedKey = nil,
		_selectedFrame = nil,
		_multiFrames = {},
		_time = 0,

		-- 행 구성이 바뀌었다 (아이템/엘리먼트/트랙 추가·삭제, 접기)
		OutlineChanged = Signal.new(),
		SelectionChanged = Signal.new(),
		-- 고른 키프레임이 바뀌었다
		FrameSelectionChanged = Signal.new(),
		TimeChanged = Signal.new(),
		-- 두 패널의 세로 스크롤을 맞추기 위한 신호
		ScrollChanged = Signal.new(),
	}, EditorState)

	self._outline, self._contentHeight = Outline.build(project:GetDocument(), self._collapsed)

	self._projectConnection = project.Changed:Connect(function()
		self:RebuildOutline()
	end)

	return self
end

-- 이름을 바꿔도 바인딩을 잃지 않도록 매번 App에서 최신 이름을 가져온다.
function EditorState:GetSavedName(): string?
	return self.App:GetSavedName()
end

function EditorState:RebuildOutline()
	local doc = self.Project:GetDocument()
	self._outline, self._contentHeight = Outline.build(doc, self._collapsed)

	-- 선택한 행이 사라졌으면 선택을 푼다.
	if self._selectedKey and not self:FindRow(self._selectedKey) then
		self._selectedKey = nil
		self.SelectionChanged:Fire(nil)
	end

	-- 길이가 줄었으면 재생헤드도 따라 줄인다.
	if self._time > doc.duration then
		self:SetTime(doc.duration)
	end

	-- 고른 키가 지워졌으면 선택을 푼다.
	if self._selectedFrame then
		local key = self:ResolveSelectedFrame()
		if not key then
			self:SelectFrame(nil)
		else
			self.FrameSelectionChanged:Fire(self._selectedFrame)
		end
	end

	self.OutlineChanged:Fire(self._outline, self._contentHeight)
end

function EditorState:GetOutline()
	return self._outline, self._contentHeight
end

function EditorState:FindRow(key: string)
	for _, row in self._outline do
		if row.key == key then
			return row
		end
	end
	return nil
end

--------------------------------------------------------------------------------
-- 접기
--------------------------------------------------------------------------------

function EditorState:IsCollapsed(key: string): boolean
	return self._collapsed[key] == true
end

function EditorState:ToggleCollapsed(key: string)
	self._collapsed[key] = if self._collapsed[key] then nil else true
	self:RebuildOutline()
end

--------------------------------------------------------------------------------
-- 선택
--------------------------------------------------------------------------------

function EditorState:GetSelectedKey(): string?
	return self._selectedKey
end

function EditorState:GetSelectedRow()
	if not self._selectedKey then
		return nil
	end
	return self:FindRow(self._selectedKey)
end

function EditorState:Select(key: string?)
	if self._selectedKey == key then
		return
	end
	self._selectedKey = key
	self.SelectionChanged:Fire(key)
end

--------------------------------------------------------------------------------
-- 키프레임 선택
--
-- 인덱스로 잡아두면 키를 옮기거나 지울 때 엉뚱한 키를 가리키게 된다.
-- 그래서 (트랙, 시간)으로 잡고 매번 다시 찾는다.
--------------------------------------------------------------------------------

export type FrameRef = {
	itemId: number,
	path: string,
	target: string,
	t: number,
}

function EditorState:GetSelectedFrame(): FrameRef?
	return self._selectedFrame
end

-- 하나만 고른 것과 여럿 고른 것을 함께 본다. 키를 칠하는 쪽은 둘을
-- 구분할 이유가 없다 — 골라져 있으면 골라져 있는 것이다.
function EditorState:IsFrameSelected(itemId: number, path: string, target: string, t: number): boolean
	local frame = self._selectedFrame
	if
		frame
		and frame.itemId == itemId
		and frame.path == path
		and frame.target == target
		and math.abs(frame.t - t) < 1e-4
	then
		return true
	end
	return self:IsFrameInMulti(itemId, path, target, t)
end

function EditorState:SelectFrame(frame: FrameRef?)
	-- 하나를 고르면 여럿 고른 건 푼다. 둘이 같이 켜져 있으면 안 된다.
	self._multiFrames = {}
	self._selectedFrame = frame
	self.FrameSelectionChanged:Fire(frame)
end

--------------------------------------------------------------------------------
-- 여러 개 고르기
--
-- Shift+드래그로 사각형을 그려 고른다. 하나만 고른 것과 다르게 다루는 이유는
-- 아래 편집 바(QuickEdit)가 값 하나를 전제로 만들어져 있어서다.
-- 여럿일 때는 편집 바를 접고 우클릭 메뉴로만 다룬다.
--------------------------------------------------------------------------------

function EditorState:GetMultiFrames(): { FrameRef }
	return self._multiFrames
end

function EditorState:IsFrameInMulti(itemId: number, path: string, target: string, t: number): boolean
	for _, frame in self._multiFrames do
		if
			frame.itemId == itemId
			and frame.path == path
			and frame.target == target
			and math.abs(frame.t - t) < 1e-4
		then
			return true
		end
	end
	return false
end

-- 하나만 골렸으면 그냥 평범한 선택으로 넘긴다. 그래야 편집 바가 뜬다.
function EditorState:SetMultiFrames(frames: { FrameRef })
	if #frames == 1 then
		self._multiFrames = {}
		self:SelectFrame(frames[1])
		return
	end

	self._multiFrames = frames
	self._selectedFrame = nil
	self.FrameSelectionChanged:Fire(nil)
end

-- 지금 골라둔 것 전부. 하나만 고른 것도 목록에 넣어 돌려준다.
-- Shift로 더 고를 때 "전에 고르던 것"이 이걸 뜻한다.
function EditorState:CollectSelectedFrames(): { FrameRef }
	local frames = {}

	if self._selectedFrame then
		table.insert(frames, self._selectedFrame)
	end
	for _, frame in self._multiFrames do
		table.insert(frames, frame)
	end

	return frames
end

local function sameFrame(a: FrameRef, b: FrameRef): boolean
	return a.itemId == b.itemId and a.path == b.path and a.target == b.target and math.abs(a.t - b.t) < 1e-4
end

-- 골라둔 것에 더 얹는다. 이미 들어 있는 건 두 번 넣지 않는다.
function EditorState:AddMultiFrames(frames: { FrameRef })
	local merged = self:CollectSelectedFrames()

	for _, frame in frames do
		local exists = false
		for _, already in merged do
			if sameFrame(already, frame) then
				exists = true
				break
			end
		end
		if not exists then
			table.insert(merged, frame)
		end
	end

	self:SetMultiFrames(merged)
end

-- Shift+클릭. 안 골라둔 건 더하고, 이미 골라둔 건 뺀다.
-- 잘못 누른 걸 되돌릴 방법이 있어야 한다.
function EditorState:ToggleMultiFrame(frame: FrameRef)
	local merged = {}
	local removed = false

	for _, already in self:CollectSelectedFrames() do
		if sameFrame(already, frame) then
			removed = true
		else
			table.insert(merged, already)
		end
	end

	if not removed then
		table.insert(merged, frame)
	end

	if #merged == 0 then
		self:SelectFrame(nil)
		return
	end
	self:SetMultiFrames(merged)
end

function EditorState:ClearMultiFrames()
	if #self._multiFrames == 0 then
		return
	end
	self._multiFrames = {}
	self.FrameSelectionChanged:Fire(self._selectedFrame)
end

-- 고른 것들이 아직 다 살아 있는지 확인하고, 사라진 건 빼고 돌려준다.
-- 함께 (키, 트랙) 짝으로 준다. 지우기나 한꺼번에 편집이 이걸 쓴다.
function EditorState:ResolveMultiFrames(): { { frame: FrameRef, key: any, track: any } }
	local doc = self.Project:GetDocument()
	local resolved = {}

	for _, frame in self._multiFrames do
		local track = Ops.findTrack(doc, frame.itemId, frame.path, frame.target)
		local key = track and Ops.findKeyAt(track, frame.t)
		if key then
			table.insert(resolved, { frame = frame, key = key, track = track })
		end
	end

	return resolved
end

-- 고른 것들이 같은 방식으로 편집될 수 있는지.
-- 메소드는 인자가 대상마다 달라서 같은 메소드끼리만 묶는다.
-- 속성은 값 타입(과 Enum 종류)이 같아야 한 값을 넣을 수 있다.

-- 골라둔 키가 전부 같은 트랙(같은 오브젝트의 같은 속성)에 속하면 그 트랙을
-- 돌려준다. 하나만 골랐어도 된다. 섞여 있으면 nil.
--
-- 스튜디오에서 속성을 고치면 골라둔 키에 그대로 받아 적는 기능이 이걸 쓴다.
-- 트랙이 섞여 있으면 어느 속성을 받아 적어야 할지 알 수 없다.
function EditorState:GetSelectedTrack()
	local frames = self:CollectSelectedFrames()
	if #frames == 0 then
		return nil, nil
	end

	local first = frames[1]
	for index = 2, #frames do
		local frame = frames[index]
		if frame.itemId ~= first.itemId or frame.path ~= first.path or frame.target ~= first.target then
			return nil, nil
		end
	end

	local track = Ops.findTrack(self.Project:GetDocument(), first.itemId, first.path, first.target)
	if not track then
		return nil, nil
	end
	return track, frames
end
function EditorState:MultiFramesShareType(): boolean
	local entries = self:ResolveMultiFrames()
	if #entries < 2 then
		return false
	end

	local first = entries[1].track
	for index = 2, #entries do
		local track = entries[index].track
		if track.kind ~= first.kind then
			return false
		end
		if track.kind == Schema.TRACK_KIND.METHOD then
			if track.target ~= first.target then
				return false
			end
		elseif track.valueType ~= first.valueType or track.enumType ~= first.enumType then
			return false
		end
	end

	return true
end
-- 고른 키가 아직 있는지 확인하고, 없으면 선택을 푼다.
function EditorState:ResolveSelectedFrame()
	local frame = self._selectedFrame
	if not frame then
		return nil, nil
	end

	local track = Ops.findTrack(self.Project:GetDocument(), frame.itemId, frame.path, frame.target)
	if not track then
		return nil, nil
	end

	local key = Ops.findKeyAt(track, frame.t)
	if not key then
		return nil, track
	end
	return key, track
end

--------------------------------------------------------------------------------
-- 키프레임 찍기
--
-- 트리의 ◆ 버튼과 타임라인 우클릭이 같은 경로를 쓴다.
--------------------------------------------------------------------------------

-- 트랙에 묶인 미리보기 인스턴스. 없으면 nil.
function EditorState:ResolveInstance(itemId: number, path: string): Instance?
	local bound = Store.GetBinding(self:GetSavedName(), itemId)
	if not bound or not bound:IsDescendantOf(game) then
		return nil
	end
	local resolved = PathSpec.resolve(bound, path)
	return resolved
end

-- t 자리에 키를 찍는다. 값은 바인딩된 오브젝트의 현재 값을 그대로 담는다.
-- 스튜디오에서 값을 맞춰놓고 찍는 게 기본 작업 흐름이다.
function EditorState:AddKey(itemId: number, path: string, track, t: number)
	local encoded = nil
	local args = nil

	if track.kind == Schema.TRACK_KIND.METHOD then
		-- 앞 키의 인자를 물려받아서 같은 호출을 반복하기 쉽게 한다.
		local previous = Ops.keyBefore(track, t)
		args = if previous and previous.args then table.clone(previous.args) else {}
	else
		local resolved = self:ResolveInstance(itemId, path)
		local ok, current = Value.capture(resolved, track.target, track.valueType)

		if ok then
			encoded = Value.encode(track.valueType, current)
		else
			-- 읽을 수 없으면 앞 키 값을, 그것도 없으면 타입 기본값을 쓴다.
			local previous = Ops.keyBefore(track, t)
			encoded = if previous then previous.v else Value.encode(track.valueType, Value.defaultFor(track.valueType))
		end

		-- 재생헤드가 아닌 자리에 찍을 때는 오브젝트의 지금 값을 쓰면 안 된다.
		-- 오브젝트는 재생헤드 시점의 모습을 하고 있는데 키는 다른 시점에
		-- 찍히기 때문이다 (레인 우클릭 → Add Keyframe Here 가 그렇다).
		--
		-- 이미 키가 있는 트랙이면 그 시점에 미리보기가 보여줄 값을 그대로
		-- 가져온다. 그래야 중간에 키를 하나 끼워도 곡선 모양이 안 바뀐다.
		if #track.keys > 0 and math.abs(t - self._time) > 1e-4 then
			local base = if ok then current else nil
			local sampled = Sampler.valueAt(track, t, base)
			if sampled ~= nil then
				encoded = Value.encode(track.valueType, sampled)
			end
		end
	end

	self.Project:Commit(Locale.T("undo.addKey"), function(doc)
		Ops.putKey(doc, itemId, path, track.target, t, encoded, args)
	end)

	self:SelectFrame({ itemId = itemId, path = path, target = track.target, t = t })
end

--------------------------------------------------------------------------------
-- 리그 포즈 / 위치 캡처
--
-- 스튜디오에서 직접 자세를 잡아놓고 찍는 방식이다.
-- 편집 모드에서는 파트를 옮겨도 Motor6D.Transform이 안 바뀌므로
-- 파트가 놓인 자리에서 관절 값을 되계산한다 (RigResolver 참고).
--------------------------------------------------------------------------------

-- 지금 자세를 모든 Motor6D에 대해 키로 찍는다.
-- (찍은 관절 수, 실패 이유)
function EditorState:CaptureRigPose(itemId: number): (number, string?)
	local root = Store.GetBinding(self:GetSavedName(), itemId)
	if not root or not root:IsDescendantOf(game) then
		return 0, Locale.T("value.noBinding")
	end

	local joints = RigResolver.collect(root)
	if #joints == 0 then
		return 0, Locale.T("state.noMotor6d")
	end

	local time = self:SnapTime(self:GetTime())

	self.Project:Commit(Locale.T("undo.capturePose"), function(doc)
		for _, joint in joints do
			if not Ops.findTrack(doc, itemId, joint.path, MOTOR_TARGET) then
				Ops.addTrack(doc, itemId, joint.path, Schema.TRACK_KIND.MOTOR6D, MOTOR_TARGET)
			end
			local encoded = Value.encode("CFrame", RigResolver.readTransform(joint.motor))
			Ops.putKey(doc, itemId, joint.path, MOTOR_TARGET, time, encoded)
		end
	end)

	return #joints, nil
end

-- 아이템이 지금 놓인 자리를 기준 아이템에 대한 상대 위치로 찍는다.
function EditorState:CaptureItemPosition(itemId: number): (boolean, string?)
	local doc = self.Project:GetDocument()
	local bindings = Store.GetBindings(self:GetSavedName())

	local root = bindings[itemId]
	if not root or not root:IsDescendantOf(game) then
		return false, Locale.T("value.noBinding")
	end

	local origin = doc.originItemId and bindings[doc.originItemId]
	local originCFrame = RigResolver.pivotOf(origin)
	if not originCFrame then
		return false, Locale.T("state.noOriginBinding")
	end

	local pivot = RigResolver.pivotOf(root)
	if not pivot then
		return false, Locale.T("state.noPivot")
	end

	local encoded = Value.encode("CFrame", originCFrame:Inverse() * pivot)
	local time = self:SnapTime(self:GetTime())

	self.Project:Commit(Locale.T("undo.capturePosition"), function(document)
		if not Ops.findTrack(document, itemId, "", TRANSFORM_TARGET) then
			Ops.addTrack(document, itemId, "", Schema.TRACK_KIND.TRANSFORM, TRANSFORM_TARGET)
		end
		Ops.putKey(document, itemId, "", TRANSFORM_TARGET, time, encoded)
	end)

	return true, nil
end

--------------------------------------------------------------------------------
-- 재생헤드
--------------------------------------------------------------------------------

function EditorState:GetTime(): number
	return self._time
end

function EditorState:SetTime(time: number)
	local doc = self.Project:GetDocument()
	local clamped = math.clamp(time, 0, doc.duration)
	if math.abs(clamped - self._time) < 1e-6 then
		return
	end
	self._time = clamped
	self.TimeChanged:Fire(clamped)
end

-- 스냅 간격(초). 프레임 단위 설정을 초로 바꾼 값이다.
function EditorState:SnapStep(): number
	local doc = self.Project:GetDocument()
	return math.max(doc.snapUnit or 1, 1) / doc.fps
end

-- 재생헤드와 키는 이 격자에 맞춰 움직인다.
function EditorState:SnapTime(time: number): number
	local doc = self.Project:GetDocument()
	local step = self:SnapStep()
	return math.clamp(math.round(time / step) * step, 0, doc.duration)
end

-- "2f" 처럼 사람이 읽는 표기
function EditorState:SnapLabel(): string
	local doc = self.Project:GetDocument()
	return string.format("%df", math.max(doc.snapUnit or 1, 1))
end

function EditorState:Destroy()
	if self._projectConnection then
		self._projectConnection:Disconnect()
		self._projectConnection = nil
	end
	self.OutlineChanged:Destroy()
	self.SelectionChanged:Destroy()
	self.FrameSelectionChanged:Destroy()
	self.TimeChanged:Destroy()
	self.ScrollChanged:Destroy()
end

return EditorState
