--!nonstrict
-- 오른쪽 패널. 왼쪽 트리와 같은 행 목록을 쓰되 각 행을 시간 축 위에 편다.
--
-- 눈금자, 재생헤드, 행 레인, 키프레임 편집까지 여기서 다룬다.
--
-- 가로는 배율 1에서 전체 길이가 패널 폭에 딱 맞고, Ctrl+휠로 확대한다.
-- 가로 스크롤바는 두지 않고 (배율, 보이는 구간 시작) 두 값으로만 다룬다.

local TextService = game:GetService("TextService")

local Component = require(script.Parent.Parent.Component)
local Create = require(script.Parent.Parent.Create)
local Drag = require(script.Parent.Parent.Drag)
local Theme = require(script.Parent.Parent.Theme)
local Dialog = require(script.Parent.Parent.Components.Dialog)
local Menu = require(script.Parent.Parent.Components.Menu)

local Ops = require(script.Parent.Parent.Parent.Core.Ops)
local PathSpec = require(script.Parent.Parent.Parent.Core.PathSpec)
local Debug = require(script.Parent.Parent.Parent.Core.Debug)
local Value = require(script.Parent.Parent.Parent.Core.Value)
local Schema = require(script.Parent.Parent.Parent.Core.Schema)
local Metrics = require(script.Parent.Metrics)
local ViewOptions = require(script.Parent.ViewOptions)
local KeyEditor = require(script.Parent.KeyEditor)
local QuickEdit = require(script.Parent.QuickEdit)
local Player = require(script.Parent.Parent.Parent.Preview.Player)
local Locale = require(script.Parent.Parent.Parent.Core.Locale)

local Timeline = Component.extend()

local MIN_LABEL_SPACING = 54
local KEY_SIZE = 8
local KEY_HIT_SIZE = 16
local DOUBLE_CLICK_SECONDS = 0.35
-- 스냅 격자 눈금은 이보다 촘촘해지면 그리지 않는다.
local MIN_SNAP_TICK_SPACING = 5

-- 마커 딱지. 왼쪽 끝이 곧 그 시간이라 가운데 정렬은 하지 않는다.
local MARKER_TEXT_SIZE = 10
local MARKER_TICK = 2
local MARKER_PADDING = 4
local MARKER_MIN_WIDTH = 22
local MARKER_MAX_WIDTH = 120
local MARKER_BOUNDS = Vector2.new(200, 20)

-- 배율 1이면 전체 길이가 패널 폭에 딱 맞는다.
local MIN_ZOOM = 1
local MAX_ZOOM = 60
local ZOOM_STEP = 1.2
local PAN_STEP = 0.12 -- Shift+휠 한 칸이 보이는 구간의 몇 배를 움직이는지

-- 머리말 좌우 묶음의 폭. 가운데 시간 표시가 그 사이를 채운다.
local TRANSPORT_WIDTH = 250
-- 왼쪽 시간 표시 칸. "1.93s / 5.00s   frame 58 / 150"이 들어갈 만큼.
local TIME_WIDTH = 230
local SETTINGS_WIDTH = 250

local function formatTime(seconds: number): string
	-- -0을 그대로 넘기면 "-0.00s"로 찍힌다. 0을 더하면 +0이 된다.
	-- 눈금 시작점 계산에서 math.ceil(-1e-6) 같은 식으로 -0이 쉽게 나온다.
	return string.format("%.2fs", seconds + 0)
end

function Timeline.new(props)
	local self = Component.construct(Timeline)

	self._state = props.State
	self._project = props.State.Project
	self._overlay = props.Overlay
	self._widget = props.Widget
	self._laneObjects = {}
	self._tickObjects = {}
	self._settingButtons = {}
	self._syncingScroll = false
	self._scrubbing = false
	self._zoom = 1
	self._viewStart = 0

	local root = Create("Frame", {
		Name = "Timeline",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = props.Parent,
	})
	self.Instance = root

	--------------------------------------------------------------------------
	-- 머리말
	--------------------------------------------------------------------------

	local header = Create("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, Metrics.HEADER_HEIGHT),
		Parent = root,
	}, {
		Create.padding(0, 8),
	})

	self._player = Player.new(self._state)
	self:Track(self._player)

	--------------------------------------------------------------------------
	-- 왼쪽: 미리보기 조작
	--------------------------------------------------------------------------

	-- 조작 버튼은 왼쪽 패널의 눈금자 자리로 들어간다. 거기가 비어 있었다.
	-- 자리를 못 받으면 (혼자 띄워보는 경우) 예전처럼 머리말에 붙는다.
	local transportParent = props.TransportParent
	self._transport = if transportParent
		then transportParent
		else Create("Frame", {
			Name = "Transport",
			BackgroundTransparency = 1,
			Size = UDim2.new(0, TRANSPORT_WIDTH, 1, 0),
			Parent = header,
		}, {
			Create.list(Enum.FillDirection.Horizontal, 4, {
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
		})

	self._previewButton = self:_createSettingButton(
		Locale.T("timeline.preview"),
		1,
		function()
			self._player:SetEnabled(not self._player:IsEnabled())
		end,
		self._transport,
		function()
			return self._player:IsEnabled()
		end
	)

	self._playButton = self:_createSettingButton(
		"Play",
		2,
		function()
			if self._player:IsPlaying() then
				self._player:Stop()
			else
				self._player:Play()
			end
		end,
		self._transport,
		function()
			return self._player:IsPlaying()
		end
	)

	self._speedButton = self:_createSettingButton("", 3, function()
		self:_promptSpeed()
	end, self._transport)

	self._loopButton = self:_createSettingButton(
		"",
		4,
		function()
			self._player:SetLooping(not self._player:IsLooping())
		end,
		self._transport,
		function()
			return self._player:IsLooping()
		end
	)

	-- 조작 버튼이 빠진 자리라 시간 표시가 맨 왼쪽으로 온다.
	self._timeLabel = Create.label({
		Name = "Time",
		Text = "0.00s",
		Font = Enum.Font.Code,
		TextSize = 12,
		Size = UDim2.new(0, TIME_WIDTH, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = header,
	})

	-- 가운데는 고른 키프레임 이야기다. 아무것도 안 골랐으면 비워둔다.
	-- 값을 확인하려고 매번 편집 창을 열지 않아도 되게 하려는 것이다.
	self._selectionLabel = Create.label({
		Name = "Selection",
		Text = "",
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(TIME_WIDTH + 8, 0),
		Size = UDim2.new(1, -(TIME_WIDTH + 8 + SETTINGS_WIDTH), 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = header,
	})

	--------------------------------------------------------------------------
	-- 오른쪽: 시간축 설정
	--------------------------------------------------------------------------

	self._settings = Create("Frame", {
		Name = "Settings",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(0, SETTINGS_WIDTH, 0, 20),
		Parent = header,
	}, {
		Create.list(Enum.FillDirection.Horizontal, 4, {
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})

	-- 눌러서 확대를 되돌린다. Ctrl+휠로 확대, Shift+휠로 좌우 이동.
	self._priorityButton = self:_createSettingButton("", 0, function()
		self:_promptPriority()
	end)
	self._zoomButton = self:_createSettingButton("", 1, function()
		self._viewStart = 0
		self:_setZoom(1)
		self:_refreshView()
	end)
	self._snapButton = self:_createSettingButton("", 2, function()
		self:_promptSnapUnit()
	end)
	self._durationButton = self:_createSettingButton("", 3, function()
		self:_promptDuration()
	end)
	self._fpsButton = self:_createSettingButton("", 4, function()
		self:_promptFps()
	end)

	--------------------------------------------------------------------------
	-- 눈금자
	--------------------------------------------------------------------------

	self._ruler = Create("TextButton", {
		Name = "Ruler",
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, Metrics.HEADER_HEIGHT),
		Size = UDim2.new(1, 0, 0, Metrics.RULER_HEIGHT),
		ClipsDescendants = true,
		Parent = root,
	})

	self._rulerDivider = Create("Frame", {
		Name = "Divider",
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
		Parent = self._ruler,
	})

	--------------------------------------------------------------------------
	-- 마커 줄
	--------------------------------------------------------------------------

	-- 마커는 문서 하나에 딸린 것이라 행 목록과 같이 스크롤하지 않는다.
	-- 버튼이어야 빈 자리 우클릭을 받는다. 프레임은 클릭을 삼키지 못한다.
	self._markerLane = Create("TextButton", {
		Name = "Markers",
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, Metrics.HEADER_HEIGHT + Metrics.RULER_HEIGHT),
		Size = UDim2.new(1, 0, 0, Metrics.MARKER_HEIGHT),
		ClipsDescendants = true,
		Parent = root,
	})

	self._markerDivider = Create("Frame", {
		Name = "Divider",
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
		Parent = self._markerLane,
	})

	self._markerObjects = {}

	--------------------------------------------------------------------------
	-- 행 레인
	--------------------------------------------------------------------------

	self._scroll = Create("ScrollingFrame", {
		Name = "Lanes",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, Metrics.topHeight(true)),
		Size = UDim2.new(1, 0, 1, -Metrics.topHeight(true)),
		CanvasSize = UDim2.new(),
		-- 스크롤바는 왼쪽 트리에만 둔다. 두 패널이 어차피 같이 움직이는데
		-- 막대가 둘이면 서로 다른 목록처럼 보인다. 휠 스크롤은 그대로 된다.
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ClipsDescendants = true,
		Parent = root,
	})

	self._empty = Create.label({
		Name = "Empty",
		Text = Locale.T("timeline.empty"),
		TextSize = 11,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(12, Metrics.topHeight(true) + 10),
		Size = UDim2.new(1, -24, 0, 40),
		Visible = false,
		Parent = root,
	})

	--------------------------------------------------------------------------
	-- 재생헤드
	--------------------------------------------------------------------------

	-- 눈금자와 레인을 가로지르는 한 줄. 마우스를 가로채면 안 되므로 Frame이다.
	self._playhead = Create("Frame", {
		Name = "Playhead",
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, Metrics.HEADER_HEIGHT),
		Size = UDim2.new(0, 1, 1, -Metrics.HEADER_HEIGHT),
		ZIndex = 5,
		Parent = root,
	})

	-- 손잡이는 버튼이어야 한다. 프레임이면 눈금자 클릭을 가로채기만 하고
	-- 정작 잡아끌 수는 없게 된다.
	self._playheadHandle = Create("TextButton", {
		Name = "Handle",
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(11, 11),
		ZIndex = 6,
		Parent = self._playhead,
	}, {
		Create.corner(2),
	})

	-- 고른 키 바로 아래에 뜨는 편집 바.
	self._quickEdit = QuickEdit.new({
		State = self._state,
		Widget = self._widget,
		Overlay = self._overlay,
		GetAnchor = function()
			return self:_selectedKeyAnchor()
		end,
	})
	self:Track(self._quickEdit)

	-- 만들 때 한 번 넣은 글자는 언어를 바꿔도 그대로 남는다.
	-- 설정 줄(배속·확대·스냅·길이)과 트랙 줄을 통째로 다시 그린다.
	-- 첫 호출은 아직 화면이 다 서기 전이라 건너뛴다.
	local built = false
	self:BindLocale(function()
		self._empty.Text = Locale.T("timeline.empty")
		if built then
			self:_refreshSettings()
		end
		built = true
	end)
	self:BindTheme(function(tokens)
		self:_applyTheme(tokens)
	end)

	self:Track(self._state.OutlineChanged:Connect(function()
		self:_rebuild()
		-- 바인딩이 바뀌었을 수도 있으니 미리보기도 다시 잡는다.
		self._player:Refresh()
	end))
	self:Track(self._state.SelectionChanged:Connect(function()
		self:_refreshSelection()
	end))
	self:Track(self._state.TimeChanged:Connect(function(time)
		self:_refreshPlayhead()
		-- 스크럽 중이면 커서를 따라가고 있으니 화면을 억지로 옮기지 않는다.
		if not self._scrubbing then
			self:_followPlayhead()
		end
		-- 재생 중에는 Player가 이미 적용하고 있다. 스크럽할 때만 여기서 반영한다.
		if not self._player:IsPlaying() then
			self._player:ApplyAt(time)
		end
	end))

	-- 미리보기 상태(켜짐/재생/배속)가 바뀌면 버튼 표시를 맞춘다.
	self:Track(self._player.Changed:Connect(function()
		self:_refreshSettings()
	end))

	-- Ctrl+휠 확대, Shift+휠 좌우 이동. 눈금자와 레인 양쪽에서 받는다.
	self:Track(self._ruler.InputChanged:Connect(function(input)
		self:_handleWheel(input, false)
	end))
	self:Track(self._scroll.InputChanged:Connect(function(input)
		self:_handleWheel(input, true)
	end))
	self:Track(self._state.FrameSelectionChanged:Connect(function()
		self:_refreshKeys()
		self:_refreshSelectionInfo()
		self:_rebindValueWatcher()
		self:_followSelection()
	end))
	self:Track(function()
		self:_endKeyDrag()
		self:_endMarkerDrag()
		self:_endBandSelect()
		if self._valueWatch then
			self._valueWatch:Disconnect()
			self._valueWatch = nil
		end
		self:_endPanDrag()
	end)
	self:Track(self._project.Changed:Connect(function()
		self:_refreshSettings()
		self:_rebuildRuler()
		self:_rebuildMarkers()
		self:_refreshSelectionInfo()
		self:_rebindValueWatcher()
		-- 키를 고치면 미리보기에도 바로 반영되어야 한다.
		if not self._player:IsPlaying() then
			self._player:ApplyAt(self._state:GetTime())
		end
	end))

	-- 왼쪽 트리와 세로 스크롤을 맞춘다.
	self:Track(self._scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		if self._syncingScroll then
			return
		end
		self._state.ScrollChanged:Fire(self._scroll.CanvasPosition.Y, self)
	end))
	self:Track(self._state.ScrollChanged:Connect(function(y, source)
		if source == self then
			return
		end
		-- 이미 같은 값이면 건드리지 않는다. 두 패널이 서로를 계속 밀어대는
		-- 되먹임을 여기서 끊는다.
		if math.abs(self._scroll.CanvasPosition.Y - y) < 0.5 then
			return
		end
		self._syncingScroll = true
		self._scroll.CanvasPosition = Vector2.new(0, y)
		self._syncingScroll = false
	end))

	-- 스크롤하면 편집 바도 키를 따라 움직여야 한다.
	self:Track(self._scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		self._quickEdit:Update()
	end))

	-- 폭이 바뀌면 시간 축 전체를 다시 그린다.
	self:Track(root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_rebuildRuler()
		self:_rebuildMarkers()
		self:_refreshPlayhead()
		self:_refreshKeys()
	end))

	-- 줄이 적어서 스크롤이 없을 때, 그 아래 빈 자리에서도 사각형이 시작돼야
	-- 한다. 레인 버튼이 안 깔린 곳이라 클릭이 여기 스크롤 프레임까지 온다.
	-- 줄 아래 빈 자리 우클릭. 여기엔 트랙이 없으니 전체 선택만 낸다.
	-- 스크롤 프레임은 버튼이 아니라서 MouseButton2Click이 없다. 입력으로 받는다.
	self:Track(self._scroll.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton2 then
			return
		end
		Menu.openContext(self._overlay, {
			self:_movePlayheadItem(self:_timeUnderCursor()),
			{ Separator = true },
			self:_selectAllItem(),
		})
	end))

	self:Track(self._scroll.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		if not input:IsModifierKeyDown(Enum.ModifierKey.Shift) then
			return
		end
		self:_beginBandSelect()
	end))

	self:Track(ViewOptions.Changed:Connect(function()
		self:_applyViewOptions()
	end))

	self:_setupScrubbing()
	self:_refreshSettings()
	self:_rebuild()
	self:_refreshPlayhead()
	self:_applyViewOptions()
	self:_refreshSelectionInfo()

	return self
end

-- isActive를 주면 켜짐 상태일 때 강조색으로 칠한다 (Preview, Play, 반복).
function Timeline:_createSettingButton(
	text: string,
	order: number,
	onClick: () -> (),
	parent: Instance?,
	isActive: (() -> boolean)?
)
	local button = Create("TextButton", {
		Name = "Setting",
		Text = text,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = order,
		Parent = parent or self._settings,
	}, {
		Create.corner(3),
		Create.padding(0, 8),
	})

	local entry = { button = button, isActive = isActive, hovered = false }
	table.insert(self._settingButtons, entry)

	self:Track(button.Activated:Connect(onClick))
	self:Track(button.MouseEnter:Connect(function()
		entry.hovered = true
		self:_paintButtons()
	end))
	self:Track(button.MouseLeave:Connect(function()
		entry.hovered = false
		self:_paintButtons()
	end))

	return button
end

function Timeline:_paintButtons()
	local tokens = Theme.Get()
	for _, entry in self._settingButtons do
		local active = entry.isActive ~= nil and entry.isActive()
		if active then
			entry.button.BackgroundColor3 = if entry.hovered then tokens.color.accentHover else tokens.color.accent
			entry.button.TextColor3 = tokens.color.textOnAccent
		else
			entry.button.BackgroundColor3 = if entry.hovered
				then tokens.color.buttonHover
				else tokens.color.buttonBackground
			entry.button.TextColor3 = tokens.color.text
		end
	end
end

-- 마커 줄을 끄면 레인이 그만큼 위로 올라온다.
-- 왼쪽 트리도 Metrics.topHeight를 쓰므로 두 패널이 같이 움직인다.
function Timeline:_applyViewOptions()
	local showMarkers = ViewOptions.AreMarkersVisible()
	local top = Metrics.topHeight(showMarkers)

	self._markerLane.Visible = showMarkers
	self._scroll.Position = UDim2.fromOffset(0, top)
	self._scroll.Size = UDim2.new(1, 0, 1, -top)
	self._empty.Position = UDim2.fromOffset(12, top + 10)

	-- 숨겨둔 줄에 딱지를 그려봐야 소용없다. 다시 켜면 그때 그린다.
	if showMarkers then
		self:_rebuildMarkers()
	else
		self:_clearMarkers()
	end
end
function Timeline:_applyTheme(tokens)
	self._timeLabel.TextColor3 = tokens.color.textMuted
	self._selectionLabel.TextColor3 = tokens.color.textMuted
	self._ruler.BackgroundColor3 = tokens.color.panelAlt
	self._rulerDivider.BackgroundColor3 = tokens.color.border
	self._scroll.ScrollBarImageColor3 = tokens.color.border
	self._empty.TextColor3 = tokens.color.textMuted

	self._markerLane.BackgroundColor3 = tokens.color.panelAlt
	self._markerDivider.BackgroundColor3 = tokens.color.border
	self._playhead.BackgroundColor3 = tokens.color.accent
	self._playheadHandle.BackgroundColor3 = tokens.color.accent

	self:_paintButtons()

	for _, lane in self._laneObjects do
		lane.applyTheme(tokens)
	end
	for _, object in self._markerObjects do
		object.applyTheme(tokens)
	end
	self:_rebuildRuler()
end

--------------------------------------------------------------------------------
-- 시간 ↔ 픽셀
--
-- 배율 1이면 전체 길이가 패널 폭에 딱 맞는다. 확대하면 보이는 구간이 좁아지고
-- _viewStart가 그 구간의 시작 시간이 된다. 가로 스크롤바 대신 이 두 값만 쓴다.
--------------------------------------------------------------------------------

function Timeline:_laneWidth(): number
	return math.max(self._ruler.AbsoluteSize.X, 1)
end

-- 지금 화면에 담기는 시간 길이
function Timeline:_visibleSpan(): number
	return self._project:GetDocument().duration / self._zoom
end

function Timeline:_timeToX(time: number): number
	return ((time - self._viewStart) / self:_visibleSpan()) * self:_laneWidth()
end

function Timeline:_xToTime(x: number): number
	local doc = self._project:GetDocument()
	local time = self._viewStart + (x / self:_laneWidth()) * self:_visibleSpan()
	return math.clamp(time, 0, doc.duration)
end

function Timeline:_isTimeVisible(time: number): boolean
	local span = self:_visibleSpan()
	return time >= self._viewStart - 1e-6 and time <= self._viewStart + span + 1e-6
end

--------------------------------------------------------------------------------
-- 확대 / 이동
--------------------------------------------------------------------------------

function Timeline:_clampView()
	local doc = self._project:GetDocument()
	local span = self:_visibleSpan()
	self._viewStart = math.clamp(self._viewStart, 0, math.max(doc.duration - span, 0))
end

function Timeline:_refreshView()
	self:_rebuildMarkers()
	self:_rebuildRuler()
	self:_refreshKeys()
	self:_refreshPlayhead()
	self:_refreshSettings()
end

-- anchorX 아래에 있던 시간이 제자리에 남도록 확대한다.
-- 그래야 커서로 가리킨 지점을 파고드는 느낌이 난다.
function Timeline:_setZoom(zoom: number, anchorX: number?)
	local clamped = math.clamp(zoom, MIN_ZOOM, MAX_ZOOM)
	if math.abs(clamped - self._zoom) < 1e-4 then
		return
	end

	local x = anchorX or self:_laneWidth() / 2
	local anchorTime = self:_xToTime(x)

	self._zoom = clamped
	self._viewStart = anchorTime - (x / self:_laneWidth()) * self:_visibleSpan()

	self:_clampView()
	self:_refreshView()
end

function Timeline:_panBy(seconds: number)
	local before = self._viewStart
	self._viewStart += seconds
	self:_clampView()
	if math.abs(self._viewStart - before) > 1e-9 then
		self:_refreshView()
	end
end

-- 아이템·엘리먼트 줄을 잡아끌어 시간축을 민다.
-- 오른쪽으로 끌면 내용이 오른쪽으로 따라온다 (종이를 잡아 미는 느낌).
function Timeline:_beginPanDrag()
	if self._panDrag then
		return
	end

	local lastX = self._widget:GetRelativeMousePosition().X

	self._panDrag = Drag.begin(self._widget, self._overlay, function(mouse)
		local delta = mouse.X - lastX
		if math.abs(delta) < 0.5 then
			return
		end
		lastX = mouse.X
		self:_panBy(-delta / self:_laneWidth() * self:_visibleSpan())
	end, function()
		self._panDrag = nil
	end)
end

function Timeline:_endPanDrag()
	local stop = self._panDrag
	if stop then
		self._panDrag = nil
		stop()
	end
end

-- 재생헤드가 보이는 구간을 벗어나면 따라간다.
function Timeline:_followPlayhead()
	local time = self._state:GetTime()
	if self:_isTimeVisible(time) then
		return
	end
	self._viewStart = time - self:_visibleSpan() / 2
	self:_clampView()
	self:_refreshView()
end

-- Ctrl+휠은 확대, Shift+휠은 좌우 이동. 그냥 휠은 세로 스크롤(기본 동작).
function Timeline:_handleWheel(input: InputObject, insideLanes: boolean): boolean
	if input.UserInputType ~= Enum.UserInputType.MouseWheel then
		return false
	end

	local delta = input.Position.Z
	if delta == 0 then
		return false
	end

	local ctrl = input:IsModifierKeyDown(Enum.ModifierKey.Ctrl)
	local shift = input:IsModifierKeyDown(Enum.ModifierKey.Shift)
	if not ctrl and not shift then
		return false
	end

	-- 레인 위에서는 로블록스가 같은 휠로 세로 스크롤도 해버린다.
	-- 확대는 세로 위치를 건드리지 않아야 하므로 원래 자리로 되돌린다.
	local keepY = self._scroll.CanvasPosition.Y

	if ctrl then
		local mouse = self._widget:GetRelativeMousePosition()
		self:_setZoom(
			self._zoom * (if delta > 0 then ZOOM_STEP else 1 / ZOOM_STEP),
			mouse.X - self._ruler.AbsolutePosition.X
		)
	else
		self:_panBy(-delta * self:_visibleSpan() * PAN_STEP)
	end

	if insideLanes then
		task.defer(function()
			if self._scroll.Parent then
				self._scroll.CanvasPosition = Vector2.new(0, keepY)
			end
		end)
	end
	return true
end

--------------------------------------------------------------------------------
-- 눈금자
--------------------------------------------------------------------------------

-- 라벨이 겹치지 않는 가장 촘촘한 간격을 고른다.
local TICK_STEPS = { 0.01, 0.02, 0.05, 0.1, 0.25, 0.5, 1, 2, 5, 10, 15, 30, 60 }

function Timeline:_pickTickStep(): number
	local span = self:_visibleSpan()
	local width = self:_laneWidth()

	for _, step in TICK_STEPS do
		if (step / span) * width >= MIN_LABEL_SPACING then
			return step
		end
	end
	return TICK_STEPS[#TICK_STEPS]
end

function Timeline:_rebuildRuler()
	-- 눈금을 전부 파괴하고 다시 만든다. 스냅이 촘촘하면 한 번에 수십~수백 개다.
	-- 화면을 만드는 동안 여러 번 불릴 수 있어서 따로 재둔다.
	local startedAt = os.clock()

	for _, tick in self._tickObjects do
		tick:Destroy()
	end
	table.clear(self._tickObjects)

	local tokens = Theme.Get()
	local doc = self._project:GetDocument()
	local span = self:_visibleSpan()
	local viewEnd = math.min(self._viewStart + span, doc.duration)

	-- 보이는 구간만 그린다. 확대하면 전체를 다 그릴 이유가 없다.
	local function eachTick(step: number, handler: (number) -> ())
		local time = math.max(math.ceil(self._viewStart / step - 1e-6) * step, 0)
		while time <= viewEnd + 1e-6 do
			handler(time)
			time += step
		end
	end

	-- 스냅 격자를 눈금자 바닥에 옅게 깔아준다. 어디에 붙는지 보여야
	-- 키가 왜 그 자리로 튀는지 납득이 된다. 너무 촘촘하면 생략한다.
	local snapStep = self._state:SnapStep()
	if (snapStep / span) * self:_laneWidth() >= MIN_SNAP_TICK_SPACING then
		eachTick(snapStep, function(time)
			local tick = Create("Frame", {
				Name = "SnapTick",
				BackgroundColor3 = tokens.color.border,
				BackgroundTransparency = 0.5,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(math.floor(self:_timeToX(time)), Metrics.RULER_HEIGHT - 3),
				Size = UDim2.fromOffset(1, 3),
				Parent = self._ruler,
			})
			table.insert(self._tickObjects, tick)
		end)
	end

	eachTick(self:_pickTickStep(), function(time)
		local x = math.floor(self:_timeToX(time))

		local tick = Create("Frame", {
			Name = "Tick",
			BackgroundColor3 = tokens.color.border,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(x, Metrics.RULER_HEIGHT - 6),
			Size = UDim2.fromOffset(1, 6),
			Parent = self._ruler,
		})
		table.insert(self._tickObjects, tick)

		local label = Create.label({
			Name = "Label",
			Text = formatTime(time),
			TextColor3 = tokens.color.textMuted,
			TextSize = 10,
			Position = UDim2.fromOffset(x + 3, 0),
			Size = UDim2.fromOffset(50, 12),
			Parent = self._ruler,
		})
		table.insert(self._tickObjects, label)
	end)

	Debug.record("debug.rulerRedraw", os.clock() - startedAt)
	Debug.bump("debug.rulerTicks", #self._tickObjects)
end

--------------------------------------------------------------------------------
-- 레인
--------------------------------------------------------------------------------

function Timeline:_clearLanes()
	for _, lane in self._laneObjects do
		lane.destroy()
	end
	table.clear(self._laneObjects)
end

function Timeline:_rebuild()
	self:_clearLanes()

	local rows, contentHeight = self._state:GetOutline()
	self._scroll.CanvasSize = UDim2.fromOffset(0, contentHeight)
	self._empty.Visible = #rows == 0

	local tokens = Theme.Get()
	for _, row in rows do
		table.insert(self._laneObjects, self:_createLane(row, tokens))
	end

	self:_refreshSelection()
end

function Timeline:_createLane(row, tokens)
	-- 모든 레인이 버튼이다. 트랙은 클릭·우클릭을, 아이템·엘리먼트 줄은
	-- 잡아끌기를 받아야 하고, 휠 확대는 어느 줄에서든 먹어야 한다.
	local isTrack = row.kind == "track"
	local frame = Create("TextButton", {
		Name = row.key,
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, row.offset),
		Size = UDim2.new(1, 0, 0, row.height),
		Parent = self._scroll,
	})

	local separator = Create("Frame", {
		Name = "Separator",
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
		Parent = frame,
	})

	-- 선택 표시는 왼쪽 끝 얇은 띠로만 한다. 레인 전체를 칠하면 왼쪽 패널이
	-- 타임라인까지 넘어온 것처럼 보인다.
	local selectionBar = Create("Frame", {
		Name = "SelectionBar",
		BorderSizePixel = 0,
		Size = UDim2.new(0, 2, 1, -1),
		Visible = false,
		ZIndex = 2,
		Parent = frame,
	})

	local selected = false

	local function applyTheme(t)
		separator.BackgroundColor3 = t.color.divider
		selectionBar.BackgroundColor3 = t.color.accent
		selectionBar.Visible = selected

		if row.kind == "track" then
			-- 트랙 레인은 배경을 비워 키프레임이 잘 보이게 한다.
			frame.BackgroundTransparency = 1
		else
			-- 아이템·엘리먼트 줄은 묶음 머리말처럼 살짝 어둡게.
			frame.BackgroundTransparency = 0
			frame.BackgroundColor3 = t.color.panelAlt
		end
	end
	applyTheme(tokens)

	-- 트랙 레인에만 키프레임을 그린다.
	local keyObjects = {}
	local function clearKeys()
		for _, keyObject in keyObjects do
			keyObject.destroy()
		end
		table.clear(keyObjects)
	end

	local function redrawKeys()
		clearKeys()
		if row.kind ~= "track" then
			return
		end
		for _, key in row.track.keys do
			table.insert(keyObjects, self:_createKey(frame, row, key))
		end
	end
	redrawKeys()

	-- 어느 레인 위에서든 Ctrl/Shift+휠은 먹어야 한다.
	local connections = {
		frame.InputChanged:Connect(function(input)
			self:_handleWheel(input, true)
		end),
	}

	-- 왼쪽 클릭은 한 군데서 다 판단한다. MouseButton1Down과 InputBegan을
	-- 나눠 쓰면 어느 쪽이 먼저 오는지에 기대게 되는데, 그 순서는 보장되지
	-- 않는다. InputBegan만 쓰면 수정키도 여기서 바로 읽을 수 있다.
	table.insert(
		connections,
		frame.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end

			-- Shift+드래그는 어느 줄에서든 사각형 선택이다.
			if input:IsModifierKeyDown(Enum.ModifierKey.Shift) then
				self:_beginBandSelect()
				return
			end

			-- 키가 아닌 빈 곳을 눌렀으니 키 선택은 푼다.
			self._state:SelectFrame(nil)
			self._state:Select(row.key)

			if isTrack then
				self:_scrubToMouse()
			else
				-- 아이템·엘리먼트 줄은 재생헤드를 옮길 이유가 없다.
				-- 대신 잡아끌어서 시간축을 민다 (Shift+휠과 같은 일).
				self:_beginPanDrag()
			end
		end)
	)

	table.insert(
		connections,
		frame.MouseButton2Click:Connect(function()
			self._state:Select(row.key)
			if isTrack then
				Menu.openContext(self._overlay, self:_laneMenuItems(row))
			else
				Menu.openContext(self._overlay, self:_groupMenuItems())
			end
		end)
	)

	return {
		key = row.key,
		applyTheme = function(t)
			applyTheme(t)
			for _, keyObject in keyObjects do
				keyObject.applyTheme(t)
			end
		end,
		refreshKeys = function()
			for _, keyObject in keyObjects do
				keyObject.refresh()
			end
		end,
		setSelected = function(value)
			if selected == value then
				return
			end
			selected = value
			applyTheme(Theme.Get())
		end,
		destroy = function()
			for _, connection in connections do
				connection:Disconnect()
			end
			clearKeys()
			frame:Destroy()
		end,
	}
end

--------------------------------------------------------------------------------
-- 우클릭 메뉴
--------------------------------------------------------------------------------

-- 우클릭한 자리의 시간. 여기에 키를 찍는 게 가장 직관적이다.
function Timeline:_timeUnderCursor(): number
	local mouse = self._widget:GetRelativeMousePosition()
	return self._state:SnapTime(self:_xToTime(mouse.X - self._scroll.AbsolutePosition.X))
end

-- 우클릭한 자리로 재생헤드를 옮기는 항목. 어느 줄에서든 쓸 수 있어야 한다.
function Timeline:_movePlayheadItem(atCursor: number)
	return {
		Text = string.format("Move Playhead Here  (%.2fs)", atCursor),
		OnSelect = function()
			self._state:SetTime(atCursor)
		end,
	}
end

-- 아이템·엘리먼트 줄에는 키가 없으니 재생헤드 이동만 있다.

-- 문서에 있는 모든 값 키를 고른다. 빈 자리 우클릭에서 부른다.
function Timeline:_selectAllKeys()
	local frames = {}

	for _, row in self._state:GetOutline() do
		if row.kind == "track" then
			for _, key in row.track.keys do
				table.insert(frames, {
					itemId = row.itemId,
					path = row.path,
					target = row.track.target,
					t = key.t,
				})
			end
		end
	end

	self._state:SetMultiFrames(frames)
end

function Timeline:_selectAllItem()
	local count = 0
	for _, row in self._state:GetOutline() do
		if row.kind == "track" then
			count += #row.track.keys
		end
	end

	return {
		Text = string.format("Select All Keyframes  (%d)", count),
		Disabled = count == 0,
		OnSelect = function()
			self:_selectAllKeys()
		end,
	}
end
function Timeline:_groupMenuItems()
	return { self:_movePlayheadItem(self:_timeUnderCursor()), { Separator = true }, self:_selectAllItem() }
end

function Timeline:_laneMenuItems(row)
	local track = row.track
	local atCursor = self:_timeUnderCursor()
	local atPlayhead = self._state:SnapTime(self._state:GetTime())
	local keyCount = #track.keys

	return {
		self:_movePlayheadItem(atCursor),
		self:_selectAllItem(),
		{ Separator = true },
		{
			Text = string.format("Add Keyframe Here  (%.2fs)", atCursor),
			OnSelect = function()
				self._state:AddKey(row.itemId, row.path, track, atCursor)
			end,
		},
		{
			Text = string.format("Add Keyframe at Playhead  (%.2fs)", atPlayhead),
			OnSelect = function()
				self._state:AddKey(row.itemId, row.path, track, atPlayhead)
			end,
		},
		{ Separator = true },
		{
			Text = string.format("Delete All Keyframes  (%d)", keyCount),
			Variant = "danger",
			Disabled = keyCount == 0,
			OnSelect = function()
				Dialog.confirm(
					self._overlay,
					Locale.T("timeline.clearKeysTitle"),
					Locale.T("timeline.clearKeysMessage", PathSpec.formatTarget(track.kind, track.target), keyCount),
					"Delete All",
					function()
						self._project:Commit(Locale.T("undo.clearKeys"), function(doc)
							Ops.clearKeys(doc, row.itemId, row.path, track.target)
						end)
					end
				)
			end,
		},
	}
end

function Timeline:_keyMenuItems(row, key)
	local frameRef = {
		itemId = row.itemId,
		path = row.path,
		target = row.track.target,
		t = key.t,
	}

	local items: { any } = {
		{
			Text = "Edit Keyframe...",
			OnSelect = function()
				KeyEditor.open(self._overlay, self._state, frameRef)
			end,
		},
		{
			Text = if key.name then string.format("Rename Keyframe...  (%s)", key.name) else "Name Keyframe...",
			OnSelect = function()
				self:_promptKeyName(frameRef, key.name)
			end,
		},
		{
			Text = "Add Marker...",
			OnSelect = function()
				self:_promptKeyMarker(frameRef)
			end,
		},
		{
			Text = string.format("Move Playhead to Keyframe  (%.2fs)", key.t),
			OnSelect = function()
				self._state:SetTime(key.t)
			end,
		},
	}

	-- 이 키가 들고 있는 마커를 한 줄씩 편다. 메뉴에 하위 메뉴가 없어서
	-- 이게 가장 단순하다.
	if key.markers and #key.markers > 0 then
		table.insert(items, { Separator = true })
		for _, marker in key.markers do
			local name = marker.name
			table.insert(items, {
				Text = string.format("Remove Marker: %s", name),
				OnSelect = function()
					self._project:Commit(Locale.T("undo.removeMarker"), function(doc)
						Ops.removeKeyMarker(doc, frameRef.itemId, frameRef.path, frameRef.target, frameRef.t, name)
					end)
				end,
			})
		end
	end

	table.insert(items, { Separator = true })
	table.insert(items, {
		Text = "Delete Keyframe",
		Variant = "danger",
		OnSelect = function()
			self._project:Commit(Locale.T("undo.deleteKey"), function(doc)
				Ops.removeKeyAt(doc, frameRef.itemId, frameRef.path, frameRef.target, frameRef.t)
			end)
			self._state:SelectFrame(nil)
		end,
	})

	return items
end

-- 키에 이름 붙이기. 비우면 이름을 뗀다.
function Timeline:_promptKeyName(frameRef, currentName: string?)
	Dialog.show(self._overlay, {
		Title = if currentName then "Rename Keyframe" else "Name Keyframe",
		Message = Locale.T("key.nameMessage"),
		Input = { Placeholder = Locale.T("key.namePlaceholder"), Default = currentName or "" },
		Confirm = "Save",
		Validate = function(text)
			local name = text:match("^%s*(.-)%s*$") or ""
			if #name > 64 then
				return false, Locale.T("marker.nameTooLong")
			end
			return true
		end,
		OnConfirm = function(text)
			local name = text:match("^%s*(.-)%s*$") or ""
			self._project:Commit(Locale.T("undo.setKeyName"), function(doc)
				Ops.setKeyName(doc, frameRef.itemId, frameRef.path, frameRef.target, frameRef.t, name)
			end)
		end,
	})
end

function Timeline:_promptKeyMarker(frameRef)
	local _, track = self._state:ResolveSelectedFrame()
	local existing = Ops.findTrack(self._project:GetDocument(), frameRef.itemId, frameRef.path, frameRef.target)
	track = existing or track

	local key = if track then Ops.findKeyAt(track, frameRef.t) else nil
	if not key then
		return
	end

	Dialog.show(self._overlay, {
		Title = "Add Marker",
		Message = Locale.T("key.markerMessage", frameRef.t),
		Input = { Placeholder = Locale.T("marker.markerPlaceholder"), Default = "" },
		Confirm = "Add",
		Validate = function(text)
			local name = text:match("^%s*(.-)%s*$") or ""
			if name == "" then
				return false, Locale.T("marker.nameEmpty")
			end
			if #name > 64 then
				return false, Locale.T("marker.nameTooLong")
			end
			for _, marker in key.markers or {} do
				if marker.name == name then
					return false, Locale.T("marker.duplicate", name)
				end
			end
			return true
		end,
		OnConfirm = function(text)
			local name = text:match("^%s*(.-)%s*$") or ""
			self._project:Commit(Locale.T("undo.addMarker"), function(doc)
				Ops.addKeyMarker(doc, frameRef.itemId, frameRef.path, frameRef.target, frameRef.t, name)
			end)
		end,
	})
end

--------------------------------------------------------------------------------
-- 키프레임
--------------------------------------------------------------------------------

function Timeline:_createKey(lane: Instance, row, key)
	local state = self._state

	-- 회전한 마름모는 클릭 판정이 어색하므로 판정용 사각 버튼 안에 넣는다.
	local hit = Create("TextButton", {
		Name = "Key",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(KEY_HIT_SIZE, KEY_HIT_SIZE),
		ZIndex = 3,
		Parent = lane,
	})

	local diamond = Create("Frame", {
		Name = "Diamond",
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(KEY_SIZE, KEY_SIZE),
		Rotation = 45,
		ZIndex = 4,
		Parent = hit,
	}, {
		Create.corner(1),
	})

	-- 이름이 붙었거나 마커를 든 키는 위에 작은 표를 하나 세운다.
	-- 이게 없으면 이름을 지어놓고도 어느 키에 지었는지 알 수가 없다.
	local flag = Create("Frame", {
		Name = "Flag",
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.5, -(KEY_SIZE // 2) - 1),
		Size = UDim2.fromOffset(2, 5),
		Visible = false,
		ZIndex = 4,
		Parent = hit,
	})

	local function applyTheme(t)
		local isSelected = state:IsFrameSelected(row.itemId, row.path, row.track.target, key.t)

		-- 색 트랙은 마름모를 그 색으로 칠한다. 숫자를 읽는 것보다 빠르다.
		-- 고른 키는 강조색으로 덮는다. 어느 게 골라졌는지가 더 급한 정보다.
		local color = nil
		if not isSelected then
			color = Value.previewColor(row.track.valueType, Value.decode(row.track.valueType, key.v))
		end

		diamond.BackgroundColor3 = color or (if isSelected then t.color.accent else t.color.text)
		diamond.Size = UDim2.fromOffset(
			if isSelected then KEY_SIZE + 2 else KEY_SIZE,
			if isSelected then KEY_SIZE + 2 else KEY_SIZE
		)

		flag.Visible = key.name ~= nil or (key.markers ~= nil and #key.markers > 0)
		flag.BackgroundColor3 = t.color.accent
	end

	local function refresh()
		hit.Position = UDim2.new(0, math.floor(self:_timeToX(key.t)), 0.5, 0)
		hit.Visible = self:_isTimeVisible(key.t)
		applyTheme(Theme.Get())
	end
	refresh()

	local function select()
		state:SelectFrame({
			itemId = row.itemId,
			path = row.path,
			target = row.track.target,
			t = key.t,
		})
		state:Select(row.key)
	end

	local lastClickAt = 0

	local connections = {
		hit.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end

			-- Shift+클릭은 골라둔 것에 이 키를 더하거나 뺀다.
			-- 키 위에서 시작한 Shift는 사각형이 아니다. 눌렀다 뗄 때까지
			-- 기다려야 클릭인지 드래그인지 갈리는데, 그동안 아무 반응이
			-- 없으면 눌린 건지 알 수가 없다. 사각형은 빈 자리에서 시작한다.
			if input:IsModifierKeyDown(Enum.ModifierKey.Shift) then
				state:ToggleMultiFrame({
					itemId = row.itemId,
					path = row.path,
					target = row.track.target,
					t = key.t,
				})
				return
			end

			-- 여럿 골라둔 것 중 하나를 눌렀으면 선택을 그대로 둔다.
			-- 여기서 select()를 부르면 SelectFrame이 여럿 고른 걸 풀어버려서
			-- 통째로 끌려던 것이 이 키 하나만 움직이게 된다.
			local inMulti = state:IsFrameInMulti(row.itemId, row.path, row.track.target, key.t)

			-- 이미 고른 키를 그냥 한 번 더 누르면 선택이 풀린다.
			-- 끌었을 때는 이동이므로 풀지 않는다. 판단은 놓을 때 한다.
			-- 여럿 고른 상태에서는 그렇게 풀지 않는다. 안에 있는 걸 한 번
			-- 눌렀다고 애써 고른 게 없어지면 곤란하다.
			local wasSelected = not inMulti and state:IsFrameSelected(row.itemId, row.path, row.track.target, key.t)

			if not inMulti then
				select()
			end

			-- 로블록스에는 더블클릭 이벤트가 없어서 직접 잰다.
			local now = os.clock()
			if now - lastClickAt < DOUBLE_CLICK_SECONDS then
				lastClickAt = 0
				KeyEditor.open(self._overlay, state, {
					itemId = row.itemId,
					path = row.path,
					target = row.track.target,
					t = key.t,
				})
				return
			end
			lastClickAt = now

			self:_beginKeyDrag(row, key, wasSelected)
		end),

		hit.MouseButton2Click:Connect(function()
			-- 여럿 골라둔 것 중 하나를 우클릭하면 그 묶음을 다루는 메뉴가 뜬다.
			-- 여기서 select()를 부르면 애써 고른 게 하나로 줄어든다.
			if state:IsFrameInMulti(row.itemId, row.path, row.track.target, key.t) then
				Menu.openContext(self._overlay, self:_multiMenuItems())
				return
			end

			select()
			Menu.openContext(self._overlay, self:_keyMenuItems(row, key))
		end),
	}

	return {
		applyTheme = applyTheme,
		refresh = refresh,
		destroy = function()
			for _, connection in connections do
				connection:Disconnect()
			end
			hit:Destroy()
		end,
	}
end

-- 키를 끌어서 시간을 옮긴다. 스냅 격자에 붙는다.
-- 커서 아래의 시간. 레인 기준이라 스크롤과 확대를 그대로 따른다.
function Timeline:_timeAtMouse(mouseX: number): number
	return self:_xToTime(mouseX - self._scroll.AbsolutePosition.X)
end

function Timeline:_beginKeyDrag(row, key, wasSelected: boolean?)
	if self._keyDrag then
		return
	end

	local state = self._state
	local startTime = key.t
	local moved = false
	local lastDelta = 0

	local duration = self._project:GetDocument().duration

	-- 잡은 지점과 키 사이의 거리를 기억한다. 이게 없으면 끄는 순간 키가
	-- 커서 한가운데로 순간이동한다. 마름모 가장자리를 잡았을 때 특히 티난다.
	local grabOffset = startTime - self:_timeAtMouse(self._widget:GetRelativeMousePosition().X)

	-- 여럿 골라둔 것 중 하나를 잡았으면 통째로 민다.
	-- 아니면 이 키 하나만 움직인다.
	local refs = {}
	if state:IsFrameInMulti(row.itemId, row.path, row.track.target, key.t) then
		refs = state:GetMultiFrames()
	else
		refs = { { itemId = row.itemId, path = row.path, target = row.track.target, t = key.t } }
	end

	-- 끄는 동안 문서를 직접 건드리므로 (키, 원래 시간)을 미리 잡아둔다.
	-- 사라진 키를 가리키는 참조는 여기서 걸러진다. 그래서 커밋할 때는
	-- 원래 목록이 아니라 실제로 찾은 것만 쓴다.
	local doc = self._project:GetDocument()
	local entries = {}
	local moving = {}
	for _, ref in refs do
		local track = Ops.findTrack(doc, ref.itemId, ref.path, ref.target)
		local target = track and Ops.findKeyAt(track, ref.t)
		if target then
			table.insert(entries, { track = track, key = target, from = target.t, ref = ref })
			table.insert(moving, { itemId = ref.itemId, path = ref.path, target = ref.target, t = target.t })
		end
	end

	local function applyDelta(delta: number)
		for _, entry in entries do
			entry.key.t = math.clamp(entry.from + delta, 0, duration)
			-- 고른 목록의 시간도 같이 옮긴다. 키를 칠할 때 이 시간과 맞춰
			-- 보기 때문에, 그대로 두면 끄는 동안 선택이 풀린 것처럼 보인다.
			entry.ref.t = entry.key.t
		end

		local sorted = {}
		for _, entry in entries do
			if not sorted[entry.track] then
				sorted[entry.track] = true
				Ops.resortKeys(entry.track)
			end
		end
	end

	self._keyDrag = Drag.begin(self._widget, self._overlay, function(mouse)
		local raw = state:SnapTime(self:_timeAtMouse(mouse.X) + grabOffset)
		local delta = math.clamp(raw, 0, duration) - startTime

		if math.abs(delta - lastDelta) < 1e-6 then
			return
		end

		-- 다른 키가 앉아 있는 자리에는 못 놓는다. 대신 지나가는 건 된다.
		-- 이웃 앞에서 멈춰 세우면 키 순서를 바꿀 방법이 아예 없어진다.
		-- 같이 움직이는 키끼리는 서로 걸림돌로 치지 않는다.
		if not Ops.canShiftKeys(entries, delta, duration) then
			return
		end

		-- 끄는 동안에는 화면만 움직이고 커밋은 놓을 때 한 번만 한다.
		-- 매 프레임 커밋하면 Undo 스택이 프레임 수만큼 쌓인다.
		moved = true
		lastDelta = delta
		applyDelta(delta)
		self:_refreshKeys()
	end, function()
		self._keyDrag = nil

		-- 실제로 움직였을 때만 문서에 남긴다.
		if not moved then
			-- 안 움직였는데 원래 골라져 있던 키였다면 선택을 푸는 뜻이다.
			if wasSelected then
				state:SelectFrame(nil)
			end
			return
		end

		local delta = lastDelta

		-- 끄는 동안 화면용으로 key.t를 직접 건드렸으므로 원래 자리로
		-- 되돌려놓는다. 그래야 Commit이 Undo 스냅샷을 제대로 남기고
		-- shiftKeys가 옮길 키를 찾을 수 있다.
		applyDelta(0)

		self._project:Commit(
			if #moving > 1 then Locale.T("undo.moveKeys") else Locale.T("undo.moveKey"),
			function(document)
				Ops.shiftKeys(document, moving, delta)
			end
		)

		-- 옮긴 자리로 선택을 따라 옮긴다. 그래야 이어서 또 끌 수 있다.
		local after = {}
		for _, ref in moving do
			table.insert(after, {
				itemId = ref.itemId,
				path = ref.path,
				target = ref.target,
				t = math.clamp(ref.t + delta, 0, duration),
			})
		end

		if #after > 1 then
			state:SetMultiFrames(after)
		else
			state:SelectFrame(after[1])
		end
	end)
end

function Timeline:_endKeyDrag()
	local stop = self._keyDrag
	if stop then
		self._keyDrag = nil
		stop()
	end
end

function Timeline:_refreshKeys()
	for _, lane in self._laneObjects do
		lane.refreshKeys()
	end
	if self._quickEdit then
		self._quickEdit:Update()
	end
end

-- 고른 키의 화면 좌표(마름모 아래쪽). 레인 밖으로 스크롤됐으면 nil이다.
function Timeline:_selectedKeyAnchor(): (number?, number?)
	local frame = self._state:GetSelectedFrame()
	if not frame then
		return nil, nil
	end

	local rows = self._state:GetOutline()
	for _, row in rows do
		if
			row.kind == "track"
			and row.itemId == frame.itemId
			and row.path == frame.path
			and row.track.target == frame.target
		then
			-- 확대해서 보이는 구간을 벗어난 키에는 편집 바를 띄우지 않는다.
			if not self:_isTimeVisible(frame.t) then
				return nil, nil
			end

			local top = self._scroll.AbsolutePosition.Y
			local y = top + row.offset - self._scroll.CanvasPosition.Y + row.height

			-- 레인 영역 밖이면 숨긴다. 안 그러면 목록 위아래에 떠 있게 된다.
			if y < top or y > top + self._scroll.AbsoluteSize.Y then
				return nil, nil
			end

			local x = self._scroll.AbsolutePosition.X + self:_timeToX(frame.t)
			return x - self._overlay.AbsolutePosition.X, y - self._overlay.AbsolutePosition.Y
		end
	end

	return nil, nil
end

function Timeline:_refreshSelection()
	local selected = self._state:GetSelectedKey()
	for _, lane in self._laneObjects do
		lane.setSelected(lane.key == selected)
	end
end

--------------------------------------------------------------------------------
-- 재생헤드
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- 머리말 가운데: 고른 키프레임 이야기
--
-- 값을 확인하려고 매번 편집 창을 열지 않아도 되게 한다.
-- 아무것도 안 골랐으면 비워둔다. 늘 무언가 떠 있으면 읽지 않게 된다.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- 스튜디오에서 속성을 고치면 골라둔 키에 받아 적는다
--
-- 색이나 숫자를 Properties 패널에서 만지작거리며 맞추는 게 자연스럽다.
-- 맞춰놓고 다시 Capture를 누르러 가는 건 손이 한 번 더 가는 일이다.
--
-- 골라둔 키가 전부 같은 트랙일 때만 켠다. 섞여 있으면 어느 속성을 받아
-- 적어야 할지 알 수 없다.
--------------------------------------------------------------------------------

-- 고른 키 자리로 재생헤드를 옮긴다 (옵션, 기본 켜짐).
--
-- 여럿 골랐을 때는 옮기지 않는다. 어느 키로 가야 할지 정할 수 없고,
-- 사각형으로 훑을 때마다 재생헤드가 튀면 성가시다.
function Timeline:_followSelection()
	if not ViewOptions.IsFollowSelectionEnabled() then
		return
	end

	-- 재생 중에는 건드리지 않는다. 재생헤드는 지금 흐르고 있는 중이다.
	if self._player:IsPlaying() then
		return
	end

	local frame = self._state:GetSelectedFrame()
	if not frame then
		return
	end

	self._state:SetTime(frame.t)
end
function Timeline:_rebindValueWatcher()
	if self._valueWatch then
		self._valueWatch:Disconnect()
		self._valueWatch = nil
	end

	local track, frames = self._state:GetSelectedTrack()
	if not track or not frames then
		return
	end

	-- 속성 트랙만 해당한다. 메소드는 값이 없고, 리그 관절과 위치는
	-- 편집 모드에서 속성이 바뀌지 않아 (되계산해서 찍는다) 여기서 들을 게 없다.
	if track.kind ~= Schema.TRACK_KIND.PROPERTY then
		return
	end

	local instance = self._state:ResolveInstance(track.itemId, track.path)
	if not instance then
		return
	end

	local ok, connection = pcall(function()
		return instance:GetPropertyChangedSignal(track.target):Connect(function()
			self:_captureIntoSelection(track, instance)
		end)
	end)

	if ok then
		self._valueWatch = connection
	end
end

function Timeline:_captureIntoSelection(track, instance: Instance)
	-- 미리보기가 꺼져 있으면 받아 적지 않는다. 스튜디오에서 오브젝트를
	-- 그냥 만질 때 골라둔 키가 따라 바뀌면 안 된다.
	if not self._player:IsEnabled() then
		return
	end

	-- 미리보기가 쓴 값이면 받아 적지 않는다. 그러면 재생헤드가 지나갈 때마다
	-- 골라둔 키가 제 값을 잃는다.
	if self._player:IsApplying() or self._player:IsPlaying() then
		return
	end

	local _, frames = self._state:GetSelectedTrack()
	if not frames or #frames == 0 then
		return
	end

	local ok, current = Value.capture(instance, track.target, track.valueType)
	if not ok then
		return
	end

	local encoded = Value.encode(track.valueType, current)

	self._project:Commit(
		if #frames > 1 then Locale.T("undo.setKeyValues") else Locale.T("undo.setKeyValue"),
		function(doc)
			for _, frame in frames do
				Ops.setKeyValue(doc, frame.itemId, frame.path, frame.target, frame.t, encoded)
			end
		end
	)
end
function Timeline:_refreshSelectionInfo()
	local state = self._state

	-- 여럿 골랐으면 개수만. 값이 서로 달라 하나로 보여줄 수가 없다.
	local multi = state:GetMultiFrames()
	if #multi > 1 then
		self._selectionLabel.Text = Locale.T("timeline.selectedCount", #multi)
		return
	end

	local key, track = state:ResolveSelectedFrame()
	if not key or not track then
		self._selectionLabel.Text = ""
		return
	end

	-- 무엇을 건드리는 트랙인지는 왼쪽 트리에 이미 적혀 있다. 여기서는
	-- 값만 보여준다. 이름을 붙였으면 그것만 앞에 세운다.
	local text
	if track.kind == Schema.TRACK_KIND.METHOD then
		-- 메소드는 값이 아니라 호출 인자를 들고 있다.
		local parts = {}
		for _, arg in key.args or {} do
			table.insert(parts, tostring(arg))
		end
		text = string.format("%s(%s)", PathSpec.formatTarget(track.kind, track.target), table.concat(parts, ", "))
	else
		local decoded = Value.decode(track.valueType, key.v)
		text = Value.format(track.valueType, decoded)
	end

	if key.name then
		text = string.format("%s: %s", key.name, text)
	end

	self._selectionLabel.Text = text
end
function Timeline:_refreshPlayhead()
	local doc = self._project:GetDocument()
	local time = self._state:GetTime()

	self._playhead.Position = UDim2.fromOffset(math.floor(self:_timeToX(time)), Metrics.HEADER_HEIGHT)
	-- 확대해서 보이는 구간을 벗어났으면 감춘다. 안 그러면 끝에 붙어있다.
	self._playhead.Visible = self:_isTimeVisible(time)

	-- 표시가 프레임 단위라 프레임 번호가 그대로면 글자도 그대로다.
	-- 매 프레임 string.format을 돌리고 Text를 새로 넣으면 쓰레기만 쌓인다.
	local frame = math.round(time * doc.fps)
	if frame == self._shownFrame then
		return
	end
	self._shownFrame = frame

	self._timeLabel.Text = string.format(
		"%s / %s   frame %d / %d",
		formatTime(time),
		formatTime(doc.duration),
		frame,
		math.round(doc.duration * doc.fps)
	)
end

function Timeline:_scrubToMouse()
	local mouse = self._widget:GetRelativeMousePosition()
	local x = mouse.X - self._ruler.AbsolutePosition.X
	self._state:SetTime(self._state:SnapTime(self:_xToTime(x)))
end

function Timeline:_setupScrubbing()
	local function stopScrub()
		local stop = self._scrubStop
		if stop then
			self._scrubStop = nil
			stop()
		end
		self._scrubbing = false
	end

	local function startScrub()
		if self._scrubbing then
			return
		end
		-- 눈금자를 누른 것도 키 바깥을 누른 것이다.
		self._state:SelectFrame(nil)
		self._scrubbing = true
		self:_scrubToMouse()

		self._scrubStop = Drag.begin(self._widget, self._overlay, function()
			self:_scrubToMouse()
		end, function()
			self._scrubStop = nil
			self._scrubbing = false
		end)
	end

	self:Track(stopScrub)

	self:Track(self._ruler.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			startScrub()
		end
	end))

	-- 마커 줄의 빈 자리도 눈금자처럼 재생헤드를 옮긴다.
	self:Track(self._markerLane.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			startScrub()
		end
	end))

	self:Track(self._markerLane.MouseButton2Click:Connect(function()
		Menu.openContext(self._overlay, self:_markerLaneMenuItems())
	end))

	self:Track(self._playheadHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			startScrub()
		end
	end))
end

--------------------------------------------------------------------------------
-- 사각형으로 여러 키 고르기
--
-- Shift+드래그. 레인 위 어디서 시작하든 된다.
-- 좌표는 캔버스 기준으로 잡는다. 끄는 동안 목록이 스크롤될 수 있어서
-- 화면 좌표로 잡아두면 사각형이 내용과 따로 논다.
--------------------------------------------------------------------------------

function Timeline:_canvasPoint(mouse: Vector2): Vector2
	return Vector2.new(
		mouse.X - self._scroll.AbsolutePosition.X,
		mouse.Y - self._scroll.AbsolutePosition.Y + self._scroll.CanvasPosition.Y
	)
end

function Timeline:_beginBandSelect()
	if self._bandDrag then
		return
	end

	local tokens = Theme.Get()
	local origin = self:_canvasPoint(self._widget:GetRelativeMousePosition())
	local current = origin

	local band = Create("Frame", {
		Name = "BandSelect",
		BackgroundColor3 = tokens.color.accent,
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
		ZIndex = 20,
		Parent = self._scroll,
	}, {
		Create.stroke(tokens.color.accent),
	})

	local function redraw()
		local left = math.min(origin.X, current.X)
		local top = math.min(origin.Y, current.Y)
		band.Position = UDim2.fromOffset(left, top)
		band.Size = UDim2.fromOffset(math.abs(current.X - origin.X), math.abs(current.Y - origin.Y))
	end
	redraw()

	self._bandDrag = Drag.begin(self._widget, self._overlay, function(mouse)
		current = self:_canvasPoint(mouse)
		redraw()
	end, function()
		self._bandDrag = nil
		band:Destroy()

		-- 거의 안 움직였으면 그냥 클릭으로 본다. 선택만 푼다.
		if math.abs(current.X - origin.X) < 3 and math.abs(current.Y - origin.Y) < 3 then
			self._state:SelectFrame(nil)
			return
		end

		self:_selectFramesInBand(
			math.min(origin.X, current.X),
			math.max(origin.X, current.X),
			math.min(origin.Y, current.Y),
			math.max(origin.Y, current.Y)
		)
	end)
end

function Timeline:_endBandSelect()
	local stop = self._bandDrag
	if stop then
		self._bandDrag = nil
		stop()
	end
end

function Timeline:_selectFramesInBand(left: number, right: number, top: number, bottom: number)
	local frames = {}

	for _, row in self._state:GetOutline() do
		if row.kind ~= "track" then
			continue
		end

		-- 키는 줄 한가운데에 그려진다. 사각형이 그 점을 덮으면 고른 것이다.
		local centerY = row.offset + row.height / 2
		if centerY < top or centerY > bottom then
			continue
		end

		for _, key in row.track.keys do
			local x = self:_timeToX(key.t)
			if x >= left and x <= right then
				table.insert(frames, {
					itemId = row.itemId,
					path = row.path,
					target = row.track.target,
					t = key.t,
				})
			end
		end
	end

	-- 전에 고르던 것은 그대로 두고 얹는다. 사각형은 Shift로만 열리니
	-- 여기서 갈아치우면 여러 번에 나눠 고를 방법이 없어진다.
	-- 새로 시작하려면 빈 곳을 그냥 클릭하면 된다.
	self._state:AddMultiFrames(frames)
end

-- 여럿 골라둔 키 위에서 우클릭했을 때 뜨는 메뉴.
function Timeline:_multiMenuItems()
	local entries = self._state:ResolveMultiFrames()
	local count = #entries

	local items: { any } = {}

	if self._state:MultiFramesShareType() then
		table.insert(items, {
			Text = string.format("Edit Selected...  (%d)", count),
			OnSelect = function()
				KeyEditor.openMulti(self._overlay, self._state)
			end,
		})
		table.insert(items, { Separator = true })
	end

	table.insert(items, {
		Text = string.format("Delete Selected  (%d)", count),
		Variant = "danger",
		OnSelect = function()
			self._project:Commit(Locale.T("undo.deleteKeys"), function(doc)
				for _, entry in entries do
					local frame = entry.frame
					Ops.removeKeyAt(doc, frame.itemId, frame.path, frame.target, frame.t)
				end
			end)
			self._state:ClearMultiFrames()
		end,
	})

	table.insert(items, { Separator = true })
	table.insert(items, {
		Text = "Deselect",
		OnSelect = function()
			self._state:ClearMultiFrames()
		end,
	})

	return items
end

--------------------------------------------------------------------------------
-- 키프레임 줄 (이름 붙은 시점 + 그 안의 마커)
--
-- 에디터는 기록만 한다. 지날 때 무슨 일을 할지는 재생하는 쪽이 정한다.
-- 한 시점에 키프레임은 하나다. 줄이 하나뿐이라 겹치면 하나가 가려진다.
-- 대신 그 하나가 마커를 여럿 든다. 같은 지점에서 타격과 발소리를 함께
-- 울려야 하는 경우가 있기 때문이다.
--------------------------------------------------------------------------------

function Timeline:_clearMarkers()
	for _, object in self._markerObjects do
		object.destroy()
	end
	table.clear(self._markerObjects)
end

function Timeline:_rebuildMarkers()
	if not ViewOptions.AreMarkersVisible() then
		return
	end

	self:_clearMarkers()

	local tokens = Theme.Get()
	for _, keyframe in self._project:GetDocument().keyframes do
		if self:_isTimeVisible(keyframe.t) then
			table.insert(self._markerObjects, self:_createKeyframeChip(keyframe, tokens))
		end
	end
end

function Timeline:_createKeyframeChip(keyframe, tokens)
	-- 마커를 몇 개 들고 있는지 이름 뒤에 붙인다. 없으면 아무것도 안 붙인다.
	local label = keyframe.name
	local count = #keyframe.markers
	if count > 0 then
		label ..= string.format(" (%d)", count)
	end

	-- 이름이 길면 줄이되, 지나치게 넓어지지 않게 자른다.
	local bounds = TextService:GetTextSize(label, MARKER_TEXT_SIZE, Enum.Font.Gotham, MARKER_BOUNDS)
	local width = math.clamp(math.ceil(bounds.X) + MARKER_PADDING * 2 + MARKER_TICK, MARKER_MIN_WIDTH, MARKER_MAX_WIDTH)

	-- 왼쪽 끝이 곧 그 시간이다. 가운데 정렬하면 어느 지점인지 흐려진다.
	local chip = Create("TextButton", {
		Name = "Keyframe",
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(math.floor(self:_timeToX(keyframe.t)), 2),
		Size = UDim2.fromOffset(width, Metrics.MARKER_HEIGHT - 5),
		Parent = self._markerLane,
	}, {
		Create.corner(3),
	})

	local tick = Create("Frame", {
		Name = "Tick",
		BorderSizePixel = 0,
		Size = UDim2.new(0, MARKER_TICK, 1, 0),
		Parent = chip,
	})

	local nameLabel = Create.label({
		Name = "Name",
		Text = label,
		TextSize = MARKER_TEXT_SIZE,
		Position = UDim2.fromOffset(MARKER_TICK + MARKER_PADDING, 0),
		Size = UDim2.new(1, -(MARKER_TICK + MARKER_PADDING * 2), 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = chip,
	})

	local function applyTheme(t)
		chip.BackgroundColor3 = t.color.inputBackground
		tick.BackgroundColor3 = t.color.accent
		nameLabel.TextColor3 = t.color.text
	end
	applyTheme(tokens)

	local connections = {
		chip.MouseButton1Down:Connect(function()
			self:_beginMarkerDrag(keyframe)
		end),
		chip.MouseButton2Click:Connect(function()
			Menu.openContext(self._overlay, self:_markerMenuItems(keyframe))
		end),
	}

	return {
		applyTheme = applyTheme,
		destroy = function()
			for _, connection in connections do
				connection:Disconnect()
			end
			chip:Destroy()
		end,
	}
end

-- 값 키 끌기와 규칙이 같다. 다른 키프레임이 앉은 자리에는 못 놓지만
-- 지나가는 건 된다.
function Timeline:_beginMarkerDrag(keyframe)
	if self._markerDrag then
		return
	end

	local state = self._state
	local startTime = keyframe.t
	local moved = false
	local lastTime = startTime
	local duration = self._project:GetDocument().duration

	-- 잡은 지점과 딱지 사이의 거리를 기억한다. 없으면 끄는 순간 딱지가
	-- 커서 한가운데로 순간이동한다.
	local grabOffset = startTime - self:_timeAtMouse(self._widget:GetRelativeMousePosition().X)

	self._markerDrag = Drag.begin(self._widget, self._overlay, function(mouse)
		local raw = state:SnapTime(self:_timeAtMouse(mouse.X) + grabOffset)
		local target = math.clamp(raw, 0, duration)

		if Ops.isKeyframeTimeTaken(self._project:GetDocument(), target, keyframe) then
			return
		end
		if math.abs(target - lastTime) < 1e-6 then
			return
		end

		-- 끄는 동안에는 화면만 움직이고 커밋은 놓을 때 한 번만 한다.
		moved = true
		lastTime = target
		keyframe.t = target
		Ops.resortKeyframes(self._project:GetDocument())
		self:_rebuildMarkers()
	end, function()
		self._markerDrag = nil
		if not moved then
			return
		end

		local from = startTime
		local to = lastTime

		-- 화면용으로 직접 건드린 값을 되돌려야 Commit이 제대로 된 스냅샷을 남긴다.
		keyframe.t = from
		Ops.resortKeyframes(self._project:GetDocument())

		self._project:Commit(Locale.T("undo.moveKeyframe"), function(doc)
			Ops.moveKeyframe(doc, from, to)
		end)
	end)
end

function Timeline:_endMarkerDrag()
	local stop = self._markerDrag
	if stop then
		self._markerDrag = nil
		stop()
	end
end

function Timeline:_markerLaneMenuItems()
	local atCursor = self:_timeUnderCursor()
	local atPlayhead = self._state:SnapTime(self._state:GetTime())
	local count = #self._project:GetDocument().keyframes

	return {
		self:_movePlayheadItem(atCursor),
		{ Separator = true },
		{
			Text = string.format("Add Keyframe Here  (%.2fs)", atCursor),
			OnSelect = function()
				self:_promptKeyframe(atCursor)
			end,
		},
		{
			Text = string.format("Add Keyframe at Playhead  (%.2fs)", atPlayhead),
			OnSelect = function()
				self:_promptKeyframe(atPlayhead)
			end,
		},
		{ Separator = true },
		{
			Text = string.format("Delete All Keyframes  (%d)", count),
			Variant = "danger",
			Disabled = count == 0,
			OnSelect = function()
				Dialog.confirm(
					self._overlay,
					Locale.T("marker.clearTitle"),
					Locale.T("marker.clearMessage", count),
					"Delete All",
					function()
						self._project:Commit(Locale.T("undo.clearKeyframes"), function(doc)
							Ops.clearKeyframes(doc)
						end)
					end
				)
			end,
		},
	}
end

function Timeline:_markerMenuItems(keyframe)
	local items: { any } = {
		{
			Text = "Rename Keyframe...",
			OnSelect = function()
				self:_promptKeyframe(keyframe.t, keyframe.name)
			end,
		},
		{
			Text = "Add Marker...",
			OnSelect = function()
				self:_promptAddMarker(keyframe.t)
			end,
		},
		{
			Text = string.format("Move Playhead to Keyframe  (%.2fs)", keyframe.t),
			OnSelect = function()
				self._state:SetTime(keyframe.t)
			end,
		},
	}

	-- 들고 있는 마커를 한 줄씩 편다. 하위 메뉴가 없어서 이게 가장 단순하다.
	if #keyframe.markers > 0 then
		table.insert(items, { Separator = true })
		for _, marker in keyframe.markers do
			local name = marker.name
			table.insert(items, {
				Text = string.format("Remove Marker: %s", name),
				OnSelect = function()
					local t = keyframe.t
					self._project:Commit(Locale.T("undo.removeMarker"), function(doc)
						Ops.removeMarker(doc, t, name)
					end)
				end,
			})
		end
	end

	table.insert(items, { Separator = true })
	table.insert(items, {
		Text = "Delete Keyframe",
		Variant = "danger",
		OnSelect = function()
			local t = keyframe.t
			self._project:Commit(Locale.T("undo.deleteKeyframe"), function(doc)
				Ops.removeKeyframeAt(doc, t)
			end)
		end,
	})

	return items
end

-- 같은 창으로 새로 만들기와 이름 바꾸기를 다 한다. 둘이 하는 일이 같다.
function Timeline:_promptKeyframe(t: number, currentName: string?)
	local snapped = self._state:SnapTime(t)
	local existing = Ops.keyframeAt(self._project:GetDocument(), snapped)

	Dialog.show(self._overlay, {
		Title = if currentName then "Rename Keyframe" else "Add Keyframe",
		Message = Locale.T("marker.message", snapped),
		Input = { Placeholder = Locale.T("marker.namePlaceholder"), Default = currentName or "" },
		Confirm = "Save",
		Hint = function()
			-- 이미 있는 자리면 이름만 바뀐다는 걸 미리 알려준다.
			if existing and existing.name ~= currentName then
				return Locale.T("marker.overwrite", existing.name)
			end
			return nil
		end,
		Validate = function(text)
			local name = text:match("^%s*(.-)%s*$") or ""
			if name == "" then
				return false, Locale.T("marker.nameEmpty")
			end
			if #name > 64 then
				return false, Locale.T("marker.nameTooLong")
			end
			return true
		end,
		OnConfirm = function(text)
			local name = text:match("^%s*(.-)%s*$") or ""
			self._project:Commit(Locale.T("undo.putKeyframe"), function(doc)
				Ops.putKeyframe(doc, snapped, name)
			end)
		end,
	})
end

function Timeline:_promptAddMarker(t: number)
	local keyframe = Ops.keyframeAt(self._project:GetDocument(), t)
	if not keyframe then
		return
	end

	Dialog.show(self._overlay, {
		Title = "Add Marker",
		Message = Locale.T("marker.addMessage", keyframe.name),
		Input = { Placeholder = Locale.T("marker.markerPlaceholder"), Default = "" },
		Confirm = "Add",
		Validate = function(text)
			local name = text:match("^%s*(.-)%s*$") or ""
			if name == "" then
				return false, Locale.T("marker.nameEmpty")
			end
			if #name > 64 then
				return false, Locale.T("marker.nameTooLong")
			end
			-- 같은 이름이 둘이면 같은 신호가 두 번 울릴 뿐이다.
			for _, marker in keyframe.markers do
				if marker.name == name then
					return false, Locale.T("marker.duplicate", name)
				end
			end
			return true
		end,
		OnConfirm = function(text)
			local name = text:match("^%s*(.-)%s*$") or ""
			self._project:Commit(Locale.T("undo.addMarker"), function(doc)
				Ops.addMarker(doc, t, name)
			end)
		end,
	})
end

--------------------------------------------------------------------------------
-- 재생 설정
--------------------------------------------------------------------------------

function Timeline:_refreshSettings()
	local doc = self._project:GetDocument()

	self._previewButton.Text = Locale.T("timeline.preview")
	self._priorityButton.Text = Locale.T("timeline.priority", doc.priority)
	self._playButton.Text = if self._player:IsPlaying() then "Stop" else "Play"
	self._speedButton.Text = Locale.T("timeline.speed", self._player:GetSpeed())
	self._loopButton.Text = Locale.T("timeline.loop")
	self:_paintButtons()

	-- 길이나 fps가 바뀌면 시간 표시 글자도 달라지므로 다시 쓰게 만든다.
	self._shownFrame = nil

	self._zoomButton.Text = Locale.T("timeline.zoom", self._zoom)
	self._snapButton.Text = Locale.T("timeline.snap", self._state:SnapLabel())
	self._durationButton.Text = Locale.T("timeline.duration", doc.duration)
	self._fpsButton.Text = string.format("%d fps", doc.fps)
	self:_refreshPlayhead()
end

function Timeline:_promptSpeed()
	Dialog.show(self._overlay, {
		Title = "Playback Speed",
		Message = Locale.T("timeline.speedMessage"),
		Input = {
			Placeholder = Locale.T("timeline.speedPlaceholder"),
			Default = string.format("%.2g", self._player:GetSpeed()),
		},
		Confirm = "Save",
		Validate = function(text)
			local value = tonumber(text)
			if not value then
				return false, Locale.T("timeline.numberRequired")
			end
			if value < 0.05 or value > 8 then
				return false, Locale.T("timeline.speedRange")
			end
			return true
		end,
		OnConfirm = function(text)
			self._player:SetSpeed(tonumber(text) :: number)
		end,
	})
end

function Timeline:_promptPriority()
	local doc = self._project:GetDocument()
	Dialog.show(self._overlay, {
		Title = "Priority",
		Message = Locale.T("timeline.priorityMessage"),
		Input = { Placeholder = Locale.T("timeline.priorityPlaceholder"), Default = tostring(doc.priority) },
		Confirm = "Save",
		Validate = function(text)
			local value = tonumber(text)
			if not value then
				return false, Locale.T("timeline.integerRequired")
			end
			if value ~= math.floor(value) then
				return false, Locale.T("timeline.integerRequired")
			end
			return true
		end,
		OnConfirm = function(text)
			local value = tonumber(text)
			if not value then
				return
			end
			self._project:Commit(Locale.T("undo.setPriority"), function(document)
				Ops.setPriority(document, value)
			end)
		end,
	})
end
function Timeline:_promptSnapUnit()
	local doc = self._project:GetDocument()
	Dialog.show(self._overlay, {
		Title = "Snap Unit",
		Message = Locale.T("timeline.snapMessage"),
		Input = { Placeholder = Locale.T("timeline.snapPlaceholder"), Default = tostring(doc.snapUnit or 2) },
		Confirm = "Save",
		Hint = function(text)
			local frames = tonumber(text)
			if not frames or frames < 1 then
				return nil
			end
			return Locale.T("timeline.snapHint", doc.fps, math.floor(frames) / doc.fps)
		end,
		Validate = function(text)
			local frames = tonumber(text)
			if not frames or frames ~= math.floor(frames) then
				return false, Locale.T("timeline.integerRequired")
			end
			if frames < 1 or frames > 240 then
				return false, Locale.T("timeline.snapRange")
			end
			return true
		end,
		OnConfirm = function(text)
			self._project:Commit(Locale.T("undo.setSnap"), function(document)
				Ops.setSnapUnit(document, tonumber(text) :: number)
			end)
		end,
	})
end

function Timeline:_promptDuration()
	local doc = self._project:GetDocument()
	Dialog.show(self._overlay, {
		Title = "Animation Length",
		Message = Locale.T("timeline.durationMessage"),
		Input = {
			Placeholder = Locale.T("timeline.durationPlaceholder"),
			Default = string.format("%.2f", doc.duration),
		},
		Confirm = "Save",
		Hint = function(text)
			local value = tonumber(text)
			if not value or value >= doc.duration then
				return nil
			end
			local lostKeys = Ops.countKeysAfter(doc, value)
			local lostMarkers = Ops.countKeyframesAfter(doc, value)
			if lostKeys == 0 and lostMarkers == 0 then
				return nil
			end
			if lostMarkers == 0 then
				return Locale.T("timeline.durationLost", lostKeys)
			end
			return Locale.T("timeline.durationLostBoth", lostKeys, lostMarkers)
		end,
		Validate = function(text)
			local value = tonumber(text)
			if not value then
				return false, Locale.T("timeline.numberRequired")
			end
			if value < 0.1 or value > 3600 then
				return false, Locale.T("timeline.durationRange")
			end
			return true
		end,
		OnConfirm = function(text)
			self._project:Commit(Locale.T("undo.setDuration"), function(document)
				Ops.setDuration(document, tonumber(text) :: number)
			end)
		end,
	})
end

function Timeline:_promptFps()
	local doc = self._project:GetDocument()
	Dialog.show(self._overlay, {
		Title = "Frame Rate",
		Message = Locale.T("timeline.fpsMessage"),
		Input = { Placeholder = "fps", Default = tostring(doc.fps) },
		Confirm = "Save",
		Validate = function(text)
			local value = tonumber(text)
			if not value then
				return false, Locale.T("timeline.numberRequired")
			end
			if value < 1 or value > 240 then
				return false, Locale.T("timeline.snapRange")
			end
			return true
		end,
		OnConfirm = function(text)
			self._project:Commit(Locale.T("undo.setFps"), function(document)
				Ops.setFps(document, tonumber(text) :: number)
			end)
		end,
	})
end

function Timeline:Destroy()
	self:_clearLanes()
	for _, tick in self._tickObjects do
		tick:Destroy()
	end
	table.clear(self._tickObjects)
	Component.Destroy(self)
end

return Timeline
