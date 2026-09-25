--!nonstrict
-- 위젯 안에서의 마우스 끌기.
--
-- 플러그인 위젯에서 마우스를 언제 놨는지 알아내는 게 생각보다 까다롭다.
--   · UserInputService는 위젯 창의 입력을 아예 못 본다.
--     (InputEnded도 안 오고 IsMouseButtonPressed는 늘 false다)
--   · PluginGui의 입력 이벤트도 환경에 따라 없거나 안 온다.
--
-- 확실히 동작하는 건 GuiObject의 입력 이벤트다. 끌기가 그걸로 시작하니까.
-- 그래서 끄는 동안 위젯 전체를 덮는 투명 버튼을 깔고, 그 위에서 버튼을
-- 뗀 것을 잡는다. 덤으로 이 버튼이 밑에 깔린 ScrollingFrame이 끌림을
-- 스크롤로 가로채는 것도 막아준다.
--
-- 나머지 신호(위젯/UIS의 InputEnded, 창 포커스 해제)는 밖에서 뗐을 때를 위한
-- 보조 장치다. 없거나 안 와도 상관없도록 각각 따로 감싼다.
--
-- 순서가 중요하다. 끝내는 수단을 전부 연결한 뒤에 Heartbeat를 건다.
-- 반대로 하면 중간에 하나가 실패했을 때 멈출 방법이 없는 채로 루프가 돈다.

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Drag = {}

local CATCHER_ZINDEX = 200

-- onStep(mousePosition)은 매 프레임, onFinish()는 놓을 때 한 번 불린다.
-- 돌려주는 함수를 부르면 강제로 끝낼 수 있다 (컴포넌트가 사라질 때 등).
function Drag.begin(widget: PluginGui, overlay: Instance, onStep: (Vector2) -> (), onFinish: (() -> ())?): () -> ()
	local finished = false
	local connections = {}

	local catcher = Instance.new("TextButton")
	catcher.Name = "DragCatcher"
	catcher.Text = ""
	catcher.BackgroundTransparency = 1
	catcher.AutoButtonColor = false
	catcher.Size = UDim2.fromScale(1, 1)
	catcher.ZIndex = CATCHER_ZINDEX
	catcher.Parent = overlay

	local function finish()
		if finished then
			return
		end
		finished = true

		for _, connection in connections do
			pcall(function()
				connection:Disconnect()
			end)
		end
		table.clear(connections)

		catcher:Destroy()

		if onFinish then
			onFinish()
		end
	end

	-- 하나가 없거나 실패해도 나머지는 살아있어야 한다.
	local function watch(subscribe: () -> RBXScriptConnection?)
		local ok, connection = pcall(subscribe)
		if ok and connection then
			table.insert(connections, connection)
		end
	end

	watch(function()
		return catcher.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				finish()
			end
		end)
	end)

	watch(function()
		return catcher.MouseButton1Up:Connect(finish)
	end)

	watch(function()
		return (widget :: any).InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				finish()
			end
		end)
	end)

	watch(function()
		return UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				finish()
			end
		end)
	end)

	watch(function()
		return widget.WindowFocusReleased:Connect(finish)
	end)

	-- 위젯이 닫히면 남은 루프가 계속 돌면 안 된다.
	watch(function()
		return widget:GetPropertyChangedSignal("Enabled"):Connect(function()
			if not widget.Enabled then
				finish()
			end
		end)
	end)

	watch(function()
		return RunService.Heartbeat:Connect(function()
			onStep(widget:GetRelativeMousePosition())
		end)
	end)

	return finish
end

return Drag
