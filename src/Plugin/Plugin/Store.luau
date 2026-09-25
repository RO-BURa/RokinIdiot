--!strict
-- ServerStorage.RokinIdiotAnimationSaves 안의 저장 파일을 읽고 쓴다.
--
-- 구조:
--   RokinIdiotAnimationSaves
--    ├─ _Lock          (StringValue)  편집 잠금
--    └─ MyCutscene     (StringValue)  Value = 애니메이션 JSON
--         └─ Bindings  (Folder)
--              └─ 1    (ObjectValue → workspace.Character1)
--
-- 런타임은 StringValue.Value만 읽는다. Bindings는 스튜디오 미리보기 전용이다.

local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")

local Schema = require(script.Parent.Parent.Core.Schema)
local Locale = require(script.Parent.Parent.Core.Locale)

local Store = {}

Store.FOLDER_NAME = "RokinIdiotAnimationSaves"
Store.LOCK_NAME = "_Lock"
Store.BINDINGS_NAME = "Bindings"

-- 저장 폴더 안에서 작업 이름으로 쓸 수 없는 예약어.
local RESERVED_NAMES = { [Store.LOCK_NAME] = true }

-- 읽기 전용 경로에서 쓴다. 폴더가 없어도 만들지 않는다.
-- 플러그인을 열기만 했는데 플레이스가 수정된 것으로 표시되면 곤란하다.
function Store.FindFolder(): Folder?
	local folder = ServerStorage:FindFirstChild(Store.FOLDER_NAME)
	if folder and folder:IsA("Folder") then
		return folder
	end

	-- 같은 이름의 다른 클래스가 있으면 건드리지 않고 오류를 낸다.
	if folder then
		error(string.format(Locale.T("store.folderConflict"), Store.FOLDER_NAME, folder.ClassName), 0)
	end

	return nil
end

-- 쓰기 경로에서 쓴다. 없으면 만든다.
function Store.GetFolder(): Folder
	local folder = Store.FindFolder()
	if folder then
		return folder
	end

	local created = Instance.new("Folder")
	created.Name = Store.FOLDER_NAME
	created.Parent = ServerStorage
	return created
end

function Store.IsValidName(name: string): (boolean, string?)
	if #name == 0 then
		return false, Locale.T("store.nameEmpty")
	end
	if #name > 50 then
		return false, Locale.T("store.nameTooLong")
	end
	if RESERVED_NAMES[name] then
		return false, Locale.T("store.nameReserved", name)
	end
	return true
end

function Store.List(): { string }
	local names: { string } = {}
	local folder = Store.FindFolder()
	if not folder then
		return names
	end

	for _, child in folder:GetChildren() do
		if child:IsA("StringValue") and not RESERVED_NAMES[child.Name] then
			table.insert(names, child.Name)
		end
	end
	table.sort(names)
	return names
end

function Store.Exists(name: string): boolean
	return Store.FindSaveValue(name) ~= nil
end

function Store.FindSaveValue(name: string?): StringValue?
	if name == nil or RESERVED_NAMES[name] then
		return nil
	end
	local folder = Store.FindFolder()
	if not folder then
		return nil
	end
	local child = folder:FindFirstChild(name)
	if child and child:IsA("StringValue") then
		return child
	end
	return nil
end

-- 문서를 JSON 문자열로. 실패하면 오류를 던진다.
function Store.Encode(doc: Schema.Document): string
	return HttpService:JSONEncode(doc)
end

function Store.Decode(json: string): Schema.Document
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, json)
	if not ok then
		error(Locale.T("store.corrupt") .. tostring(decoded), 0)
	end
	return Schema.migrate(decoded)
end

function Store.Load(name: string): Schema.Document
	local value = Store.FindSaveValue(name)
	if not value then
		error(Locale.T("store.notFound", name), 0)
	end
	return Store.Decode(value.Value)
end

-- 문서를 저장한다. 문서의 name이 바뀌었으면 인스턴스 이름도 따라간다.
function Store.Save(doc: Schema.Document, previousName: string?)
	local valid, reason = Store.IsValidName(doc.name)
	if not valid then
		error("[RokinIdiot] " .. tostring(reason), 0)
	end

	local folder = Store.GetFolder()
	local value: StringValue? = nil

	if previousName and previousName ~= doc.name then
		value = Store.FindSaveValue(previousName)
		if value and Store.Exists(doc.name) then
			error(Locale.T("store.nameTaken", doc.name), 0)
		end
	else
		value = Store.FindSaveValue(doc.name)
	end

	if not value then
		local created = Instance.new("StringValue")
		created.Parent = folder
		value = created
	end

	local target = value :: StringValue
	target.Name = doc.name
	target.Value = Store.Encode(doc)
end

function Store.Delete(name: string)
	local value = Store.FindSaveValue(name)
	if value then
		value:Destroy()
	end
end

--------------------------------------------------------------------------------
-- 가져오기
--
-- 다른 플레이스에서 Export한 StringValue를 그대로 들고 온 경우를 위한 길이다.
-- 저장 폴더 밖에 있는 우리 형식의 값을 알아보고 복사해 온다.
--------------------------------------------------------------------------------

-- 이 인스턴스가 우리 형식의 애니메이션인지 살펴본다.
-- 아니면 그냥 (false, nil)이다. 아무 StringValue나 물고 들어올 수 있으니
-- 판별에 실패해도 조용히 넘어간다.
function Store.Probe(instance: Instance?): (boolean, Schema.Document?)
	if not instance or not instance:IsA("StringValue") or instance.Value == "" then
		return false, nil
	end

	local decoded = nil
	local ok = pcall(function()
		decoded = HttpService:JSONDecode(instance.Value)
	end)
	if not ok or typeof(decoded) ~= "table" then
		return false, nil
	end

	-- 우리 스키마의 최소 표식. 이게 없으면 남의 JSON이다.
	if
		tonumber(decoded.schemaVersion) == nil
		or typeof(decoded.items) ~= "table"
		or typeof(decoded.tracks) ~= "table"
	then
		return false, nil
	end

	local migrated, result = pcall(Schema.migrate, decoded)
	if not migrated then
		return false, nil
	end
	return true, result
end

-- 저장 폴더 안에 이미 들어있는 것인가.
function Store.IsInSaves(instance: Instance): boolean
	local folder = Store.FindFolder()
	return folder ~= nil and instance:IsDescendantOf(folder)
end

-- 고른 StringValue를 저장 폴더로 복사해 온다. 원본은 건드리지 않는다.
function Store.ImportFrom(source: StringValue, doc: Schema.Document, name: string)
	doc.name = name
	Store.Save(doc)

	-- 원본에 붙어있던 미리보기 바인딩도 옮겨 담는다.
	-- 여기서도 Clone은 쓰지 않는다. 가리키는 대상이 복사 범위 밖이라 끊긴다.
	local sourceBindings = source:FindFirstChild(Store.BINDINGS_NAME)
	if not sourceBindings then
		return
	end

	for _, child in sourceBindings:GetChildren() do
		local id = tonumber(child.Name)
		if id and child:IsA("ObjectValue") and child.Value then
			Store.SetBinding(name, id, child.Value)
		end
	end
end

--------------------------------------------------------------------------------
-- 미리보기 바인딩
--------------------------------------------------------------------------------

local function bindingsFolder(name: string?, create: boolean): Folder?
	local value = Store.FindSaveValue(name)
	if not value then
		return nil
	end

	local folder = value:FindFirstChild(Store.BINDINGS_NAME)
	if folder and folder:IsA("Folder") then
		return folder
	end
	if not create then
		return nil
	end

	if folder then
		folder:Destroy()
	end
	local created = Instance.new("Folder")
	created.Name = Store.BINDINGS_NAME
	created.Parent = value
	return created
end

-- 아이템 id → 미리보기 인스턴스.
function Store.GetBindings(name: string?): { [number]: Instance }
	local result: { [number]: Instance } = {}
	local folder = bindingsFolder(name, false)
	if not folder then
		return result
	end

	for _, child in folder:GetChildren() do
		local id = tonumber(child.Name)
		if id and child:IsA("ObjectValue") and child.Value then
			result[id] = child.Value
		end
	end
	return result
end

function Store.GetBinding(name: string?, itemId: number): Instance?
	return Store.GetBindings(name)[itemId]
end

-- instance가 nil이면 바인딩을 해제한다.
function Store.SetBinding(name: string?, itemId: number, instance: Instance?)
	local folder = bindingsFolder(name, instance ~= nil)
	if not folder then
		return
	end

	local key = tostring(itemId)
	local existing = folder:FindFirstChild(key)

	if not instance then
		if existing then
			existing:Destroy()
		end
		return
	end

	if existing and existing:IsA("ObjectValue") then
		existing.Value = instance
		return
	end
	if existing then
		existing:Destroy()
	end

	local objectValue = Instance.new("ObjectValue")
	objectValue.Name = key
	objectValue.Value = instance
	objectValue.Parent = folder
end

-- 아이템 Id를 맞바꿀 때 바인딩도 같이 따라가야 한다.
function Store.SwapBindings(name: string?, idA: number, idB: number)
	local a = Store.GetBinding(name, idA)
	local b = Store.GetBinding(name, idB)
	Store.SetBinding(name, idA, b)
	Store.SetBinding(name, idB, a)
end

-- 아이템이 삭제됐을 때 남은 바인딩을 치운다.
function Store.PruneBindings(name: string, liveItemIds: { [number]: true })
	local folder = bindingsFolder(name, false)
	if not folder then
		return
	end
	for _, child in folder:GetChildren() do
		local id = tonumber(child.Name)
		if not id or not liveItemIds[id] then
			child:Destroy()
		end
	end
end

--------------------------------------------------------------------------------
-- 내보내기
--------------------------------------------------------------------------------

-- 현재 문서를 StringValue로 Workspace에 복사한다.
-- 저장본에 붙어있는 미리보기 바인딩도 같이 딸려간다. 작업을 다른 곳으로
-- 옮길 때 아이템 연결까지 따라가야 쓸모가 있다.
--
-- Bindings 폴더를 Clone하면 안 된다. ObjectValue가 가리키는 대상이 복사
-- 범위 밖(Workspace의 모델)이라 클론에서는 참조가 끊긴다. 그래서 새로 만든다.
function Store.ExportToWorkspace(doc: Schema.Document, savedName: string?): StringValue
	local value = Instance.new("StringValue")
	value.Name = doc.name
	value.Value = Store.Encode(doc)

	local folder: Folder? = nil
	for id, instance in Store.GetBindings(savedName) do
		if not folder then
			local created = Instance.new("Folder")
			created.Name = Store.BINDINGS_NAME
			created.Parent = value
			folder = created
		end

		local objectValue = Instance.new("ObjectValue")
		objectValue.Name = tostring(id)
		objectValue.Value = instance
		objectValue.Parent = folder
	end

	value.Parent = workspace
	return value
end

return Store
