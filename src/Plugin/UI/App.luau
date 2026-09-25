--!nonstrict
-- 위젯 안의 최상위 컨트롤러. 화면 전환과 문서 수명(열기/저장/닫기)을 담당한다.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")

local Component = require(script.Parent.Component)
local Create = require(script.Parent.Create)
local Dialog = require(script.Parent.Components.Dialog)

local Project = require(script.Parent.Parent.Core.Project)
local Debug = require(script.Parent.Parent.Core.Debug)
local Store = require(script.Parent.Parent.Plugin.Store)
local Lock = require(script.Parent.Parent.Plugin.Lock)
local Recents = require(script.Parent.Parent.Plugin.Recents)
local Locale = require(script.Parent.Parent.Core.Locale)

local App = Component.extend()

-- 플러그인 안에 들어 있는 런타임 모듈 이름. default.project.json에서 붙인다.
local PLAYER_MODULE_NAME = "RokinIdiotAnimationPlayer"

function App.new(widget: DockWidgetPluginGui)
	local self = Component.construct(App)

	self._widget = widget
	self._project = nil
	self._openName = nil -- 저장된 인스턴스 이름 (이름 변경 감지용)
	self._screen = nil

	local root = Create("Frame", {
		Name = "Root",
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = widget,
	})
	self.Instance = root

	self._body = Create("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = root,
	})

	-- 메뉴 팝업과 모달이 그려지는 레이어. 항상 본문 위에 있다.
	self.Overlay = Create("Frame", {
		Name = "Overlay",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
		Parent = root,
	})

	self:BindTheme(function(tokens)
		root.BackgroundColor3 = tokens.color.windowBackground
	end)

	-- 다른 스튜디오 세션이 잠금을 인수해가면 편집을 계속할 수 없다.
	self:Track(Lock.Lost:Connect(function(holder)
		if not self._project then
			return
		end
		local name = self._project:GetName()
		self:_forceCloseProject()
		Dialog.show(self.Overlay, {
			Title = Locale.T("app.lockLostTitle"),
			Message = string.format(Locale.T("app.lockLostMessage"), holder.userName, name),
			Confirm = Locale.T("common.ok"),
			HideCancel = true,
		})
	end))

	self:ShowHome()
	return self
end

function App:GetOverlay(): Instance
	return self.Overlay
end

function App:GetWidget(): DockWidgetPluginGui
	return self._widget
end

function App:GetProject()
	return self._project
end

-- 저장 폴더 안 StringValue의 현재 이름. 미리보기 바인딩을 찾을 때 쓴다.
-- 이름 변경이 아직 저장되지 않았을 수 있어서 문서의 name과 다를 수 있다.
function App:GetSavedName(): string?
	return self._openName
end

--------------------------------------------------------------------------------
-- 화면 전환
--------------------------------------------------------------------------------

function App:_setScreen(screen)
	if self._screen then
		self._screen:Destroy()
	end
	self._screen = screen
end

function App:ShowHome()
	local HomeScreen = require(script.Parent.Screens.HomeScreen)
	self:_setScreen(HomeScreen.new({
		Parent = self._body,
		App = self,
	}))
end

function App:ShowEditor()
	local EditorScreen = require(script.Parent.Screens.EditorScreen)
	self:_setScreen(EditorScreen.new({
		Parent = self._body,
		App = self,
		Project = self._project,
	}))
end

--------------------------------------------------------------------------------
-- 문서 수명
--------------------------------------------------------------------------------

-- 잠금을 잡는다. 실패하면 인수 여부를 물어본다.
function App:_ensureLock(onGranted: () -> ())
	local ok = Lock.Acquire()
	if ok then
		onGranted()
		return
	end

	local blocker = Lock.GetBlocker()
	if not blocker then
		-- 물어보는 사이에 잠금이 풀렸다.
		if Lock.Acquire() then
			onGranted()
		end
		return
	end

	Dialog.show(self.Overlay, {
		Title = Locale.T("app.lockedTitle"),
		Message = Locale.T("app.lockedMessage", Lock.DescribeHolder(blocker)),
		Confirm = Locale.T("app.takeOver"),
		ConfirmVariant = "danger",
		OnConfirm = function()
			if Lock.Acquire(true) then
				onGranted()
			end
		end,
	})
end

function App:NewProject()
	Dialog.show(self.Overlay, {
		Title = "New Animation",
		Input = { Placeholder = Locale.T("app.namePlaceholder"), Default = "" },
		Confirm = "Create",
		Validate = function(text)
			local trimmed = text:match("^%s*(.-)%s*$") or ""
			local valid, reason = Store.IsValidName(trimmed)
			if not valid then
				return false, reason
			end
			if Store.Exists(trimmed) then
				return false, Locale.T("app.nameTaken", trimmed)
			end
			return true
		end,
		OnConfirm = function(text)
			local name = text:match("^%s*(.-)%s*$") or ""
			self:_ensureLock(function()
				local project = Project.newBlank(name)

				local ok, err = pcall(function()
					Store.Save(project:GetDocument())
				end)
				if not ok then
					self:_showError(Locale.T("app.createFailed"), tostring(err))
					Lock.Release()
					return
				end

				project:MarkSaved()
				Recents.Touch(name)

				self._project = project
				self._openName = name
				self:ShowEditor()
			end)
		end,
	})
end

function App:OpenProject(name: string)
	-- 여는 데 걸리는 시간을 단계별로 재둔다. Options → Print Debug Log로 확인.
	local openedAt = os.clock()

	self:_ensureLock(function()
		Debug.record("debug.openLock", os.clock() - openedAt)

		local loadAt = os.clock()
		local ok, result = pcall(Store.Load, name)
		Debug.record("debug.openLoad", os.clock() - loadAt)

		if not ok then
			Lock.Release()
			self:_showError(Locale.T("app.openFailed"), tostring(result))
			return
		end

		local project = Project.new(result)
		project:MarkSaved()
		Recents.Touch(name)

		self._project = project
		self._openName = name

		local screenAt = os.clock()
		self:ShowEditor()
		Debug.record("debug.openScreen", os.clock() - screenAt)

		Debug.record("debug.openTotal", os.clock() - openedAt)
	end)
end

function App:SaveProject(): boolean
	local project = self._project
	if not project then
		return false
	end

	local ok, err = pcall(function()
		Store.Save(project:GetDocument(), self._openName)
	end)
	if not ok then
		self:_showError(Locale.T("app.saveFailed"), tostring(err))
		return false
	end

	local newName = project:GetName()
	if self._openName and self._openName ~= newName then
		Recents.Rename(self._openName, newName)
	end
	self._openName = newName

	project:MarkSaved()
	Recents.Touch(newName)
	return true
end

function App:RenameProject()
	local project = self._project
	if not project then
		return
	end
	local currentName = project:GetName()

	Dialog.show(self.Overlay, {
		Title = "Rename Animation",
		Input = { Placeholder = Locale.T("app.namePlaceholder"), Default = currentName },
		Confirm = "Rename",
		Validate = function(text)
			local trimmed = text:match("^%s*(.-)%s*$") or ""
			local valid, reason = Store.IsValidName(trimmed)
			if not valid then
				return false, reason
			end
			if trimmed ~= currentName and Store.Exists(trimmed) then
				return false, Locale.T("app.nameTaken", trimmed)
			end
			return true
		end,
		OnConfirm = function(text)
			local name = text:match("^%s*(.-)%s*$") or ""
			-- 이름은 TopBar가 Changed를 듣고 알아서 갱신한다.
			project:Commit("rename", function(doc)
				doc.name = name
			end)
			self:SaveProject()
		end,
	})
end

function App:DeleteProject(name: string, onDone: (() -> ())?)
	Dialog.confirm(self.Overlay, Locale.T("app.deleteTitle"), Locale.T("app.deleteMessage", name), "Delete", function()
		Store.Delete(name)
		Recents.Remove(name)
		if self._project and self._openName == name then
			self:_forceCloseProject()
		elseif onDone then
			onDone()
		end
	end)
end

-- 저장 여부를 물어보고 닫는다.
function App:CloseProject()
	local project = self._project
	if not project then
		self:ShowHome()
		return
	end

	if not project:IsDirty() then
		self:_forceCloseProject()
		return
	end

	Dialog.show(self.Overlay, {
		Title = Locale.T("app.unsavedTitle"),
		Message = Locale.T("app.unsavedMessage", project:GetName()),
		Confirm = Locale.T("app.saveAndClose"),
		Cancel = Locale.T("common.cancel"),
		Tertiary = {
			Text = Locale.T("app.closeWithoutSaving"),
			OnSelect = function()
				self:_forceCloseProject()
			end,
		},
		OnConfirm = function()
			if self:SaveProject() then
				self:_forceCloseProject()
			end
		end,
	})
end

function App:_forceCloseProject()
	if self._project then
		self._project:Destroy()
		self._project = nil
	end
	self._openName = nil
	Lock.Release()
	self:ShowHome()
end

--------------------------------------------------------------------------------
-- 메뉴 동작
--------------------------------------------------------------------------------

-- 현재 문서를 StringValue로 Workspace에 복사하고 선택해준다.
function App:ExportToWorkspace()
	local project = self._project
	if not project then
		return
	end

	local recording = ChangeHistoryService:TryBeginRecording("RokinIdiot: Export Animation")
	local ok, result = pcall(Store.ExportToWorkspace, project:GetDocument(), self._openName)

	if not ok then
		if recording then
			ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Cancel)
		end
		self:_showError(Locale.T("app.exportFailed"), tostring(result))
		return
	end

	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end

	Selection:Set({ result })
end

-- 게임에서 애니메이션을 재생하는 모듈을 Workspace에 꺼내 놓는다.
--
-- 플러그인 안에 들어 있는 그 폴더를 그대로 복제한다. 쓰는 사람은 이걸
-- ReplicatedStorage 같은 곳으로 옮겨서 require하면 된다.
-- 플러그인 안의 원본은 건드리지 않는다. 옮겨버리면 다음에 꺼낼 게 없다.
function App:ExportPlayerToWorkspace()
	-- UI/App 기준으로 두 단계 위가 플러그인 뿌리다.
	local root = script.Parent.Parent
	local source = root:FindFirstChild(PLAYER_MODULE_NAME)
	if not source then
		self:_showError(Locale.T("app.exportFailed"), Locale.T("app.playerMissing", PLAYER_MODULE_NAME))
		return
	end

	local recording = ChangeHistoryService:TryBeginRecording("RokinIdiot: Export Player")
	local ok, result = pcall(function()
		local copy = source:Clone()
		copy.Parent = workspace
		return copy
	end)

	if not ok then
		if recording then
			ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Cancel)
		end
		self:_showError(Locale.T("app.exportFailed"), tostring(result))
		return
	end

	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end

	Selection:Set({ result })
end

function App:_showError(title: string, message: string)
	-- 오류 메시지 앞의 "[RokinIdiot] " 접두사와 스크립트 위치 표기를 정리한다.
	local cleaned = message:gsub("^.-%[RokinIdiot%]%s*", ""):gsub("^%S+:%d+:%s*", "")
	Dialog.show(self.Overlay, {
		Title = title,
		Message = cleaned,
		Confirm = Locale.T("common.ok"),
		HideCancel = true,
	})
end

function App:Destroy()
	if self._screen then
		self._screen:Destroy()
		self._screen = nil
	end
	if self._project then
		self._project:Destroy()
		self._project = nil
	end
	Lock.Release()
	Component.Destroy(self)
end

return App
