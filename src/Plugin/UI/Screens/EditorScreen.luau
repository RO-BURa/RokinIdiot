--!nonstrict
-- 작업 화면. 상단 바 + [왼쪽 엘리먼트 트리 | 오른쪽 타임라인] 분할.

local Component = require(script.Parent.Parent.Component)
local Create = require(script.Parent.Parent.Create)
local Drag = require(script.Parent.Parent.Drag)
local Theme = require(script.Parent.Parent.Theme)
local TopBar = require(script.Parent.Parent.Editor.TopBar)
local EditorState = require(script.Parent.Parent.Editor.EditorState)
local ElementTree = require(script.Parent.Parent.Editor.ElementTree)
local Timeline = require(script.Parent.Parent.Editor.Timeline)

local EditorScreen = Component.extend()

local SPLITTER_WIDTH = 4
local MIN_LEFT = 200
local MIN_RIGHT = 240
local DEFAULT_LEFT = 280

function EditorScreen.new(props)
	local self = Component.construct(EditorScreen)

	self._app = props.App
	self._project = props.Project
	self._leftWidth = DEFAULT_LEFT
	self._dragging = false
	self._hovering = false

	local root = Create("Frame", {
		Name = "EditorScreen",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = props.Parent,
	})
	self.Instance = root

	self._state = EditorState.new(props.App, props.Project)
	self:Track(self._state)

	-- 화면 맨 아래에 깔린 클릭 받이.
	-- 버튼이 아닌 곳(패널 여백, 머리말 등)을 누르면 여기까지 내려오므로
	-- 키프레임 선택이 어디를 눌러도 풀린다. 키 자신과 편집 바는 Active를
	-- 켜둬서 클릭을 자기가 먹고 여기까지 오지 않는다.
	self._deselectCatcher = Create("TextButton", {
		Name = "DeselectCatcher",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
		Parent = root,
	})

	self:Track(self._deselectCatcher.MouseButton1Down:Connect(function()
		self._state:SelectFrame(nil)
	end))

	self._topBar = TopBar.new({
		Parent = root,
		Overlay = props.App:GetOverlay(),
		App = props.App,
		Project = props.Project,
	})
	self:Track(self._topBar)

	local body = Create("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, TopBar.HEIGHT),
		Size = UDim2.new(1, 0, 1, -TopBar.HEIGHT),
		Parent = root,
	})
	self._body = body

	--------------------------------------------------------------------------
	-- 왼쪽: 엘리먼트 트리
	--------------------------------------------------------------------------

	self.LeftPanel = Create("Frame", {
		Name = "Left",
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.new(0, self._leftWidth, 1, 0),
		Parent = body,
	})

	self._tree = ElementTree.new({
		Parent = self.LeftPanel,
		Overlay = props.App:GetOverlay(),
		State = self._state,
	})
	self:Track(self._tree)

	--------------------------------------------------------------------------
	-- 분할 손잡이
	--------------------------------------------------------------------------

	self._splitter = Create("TextButton", {
		Name = "Splitter",
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(self._leftWidth, 0),
		Size = UDim2.new(0, SPLITTER_WIDTH, 1, 0),
		ZIndex = 3,
		Parent = body,
	})

	--------------------------------------------------------------------------
	-- 오른쪽: 타임라인
	--------------------------------------------------------------------------

	self.RightPanel = Create("Frame", {
		Name = "Right",
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(self._leftWidth + SPLITTER_WIDTH, 0),
		Size = UDim2.new(1, -(self._leftWidth + SPLITTER_WIDTH), 1, 0),
		Parent = body,
	})

	self._timeline = Timeline.new({
		Parent = self.RightPanel,
		Overlay = props.App:GetOverlay(),
		Widget = props.App:GetWidget(),
		-- 미리보기 조작 버튼은 왼쪽 눈금자 자리에 들어간다.
		-- 만드는 건 재생기를 들고 있는 타임라인이고, 자리는 트리가 낸다.
		TransportParent = self._tree.RulerSlot,
		State = self._state,
	})
	self:Track(self._timeline)

	self:BindTheme(function(tokens)
		self:_applyTheme(tokens)
	end)

	self:_setupSplitter()
	return self
end

function EditorScreen:_applyTheme(tokens)
	self.LeftPanel.BackgroundColor3 = tokens.color.panel
	self.RightPanel.BackgroundColor3 = tokens.color.windowBackground
	self._splitter.BackgroundColor3 = if self._dragging or self._hovering
		then tokens.color.accent
		else tokens.color.border
end

function EditorScreen:_setLeftWidth(width: number)
	local available = self._body.AbsoluteSize.X
	local maxLeft = math.max(MIN_LEFT, available - MIN_RIGHT - SPLITTER_WIDTH)
	self._leftWidth = math.clamp(width, MIN_LEFT, maxLeft)

	self.LeftPanel.Size = UDim2.new(0, self._leftWidth, 1, 0)
	self._splitter.Position = UDim2.fromOffset(self._leftWidth, 0)
	self.RightPanel.Position = UDim2.fromOffset(self._leftWidth + SPLITTER_WIDTH, 0)
	self.RightPanel.Size = UDim2.new(1, -(self._leftWidth + SPLITTER_WIDTH), 1, 0)
end

function EditorScreen:_setupSplitter()
	local widget = self._app:GetWidget()
	local overlay = self._app:GetOverlay()

	local function paint()
		self._splitter.BackgroundColor3 = if self._dragging or self._hovering
			then Theme.Get().color.accent
			else Theme.Get().color.border
	end

	local function stopDrag()
		local stop = self._dragStop
		if stop then
			self._dragStop = nil
			stop()
		end
		self._dragging = false
		paint()
	end

	-- 커서가 손잡이 밖으로 나가도 계속 끌려야 하므로, 자식 프레임이 가로채는
	-- 마우스 이동 이벤트 대신 위젯 기준 커서 좌표를 매 프레임 읽는다.
	local function startDrag()
		if self._dragging then
			return
		end
		self._dragging = true
		paint()

		self._dragStop = Drag.begin(widget, overlay, function(mouse)
			self:_setLeftWidth(mouse.X - self._body.AbsolutePosition.X)
		end, function()
			self._dragStop = nil
			self._dragging = false
			paint()
		end)
	end

	self:Track(stopDrag)

	self:Track(self._splitter.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			startDrag()
		end
	end))

	self:Track(self._splitter.MouseEnter:Connect(function()
		self._hovering = true
		paint()
	end))
	self:Track(self._splitter.MouseLeave:Connect(function()
		self._hovering = false
		paint()
	end))

	-- 위젯 크기가 줄면 최소 폭 제약을 다시 적용한다.
	self:Track(self._body:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_setLeftWidth(self._leftWidth)
	end))
end

return EditorScreen
