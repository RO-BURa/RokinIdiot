--!strict
-- 열려있는 애니메이션 문서 하나. 편집은 전부 :Commit()을 통해서만 이뤄지며
-- 그 덕분에 Undo 스택과 변경 알림이 자동으로 따라온다.

local Signal = require(script.Parent.Signal)
local Schema = require(script.Parent.Schema)
local Locale = require(script.Parent.Locale)

local UNDO_LIMIT = 100

local function deepCopy(value: any): any
	if typeof(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

local Project = {}
Project.__index = Project

export type Project = typeof(setmetatable(
	{} :: {
		_doc: Schema.Document,
		_undo: { Schema.Document },
		_redo: { Schema.Document },
		_dirty: boolean,
		Changed: any,
		DirtyChanged: any,
	},
	Project
))

function Project.new(doc: Schema.Document): Project
	local self = setmetatable({
		_doc = doc,
		_undo = {},
		_redo = {},
		_dirty = false,
		Changed = Signal.new(),
		DirtyChanged = Signal.new(),
	}, Project)
	return (self :: any) :: Project
end

function Project.newBlank(name: string): Project
	return Project.new(Schema.newDocument(name))
end

function Project:GetDocument(): Schema.Document
	return self._doc
end

function Project:GetName(): string
	return self._doc.name
end

function Project:IsDirty(): boolean
	return self._dirty
end

function Project:_setDirty(dirty: boolean)
	if self._dirty == dirty then
		return
	end
	self._dirty = dirty
	self.DirtyChanged:Fire(dirty)
end

-- 모든 편집의 유일한 통로.
-- mutator가 문서를 제자리에서 수정한다. 오류가 나면 이전 상태로 되돌린다.
function Project:Commit(label: string, mutator: (Schema.Document) -> ())
	local snapshot = deepCopy(self._doc)

	local ok, err = pcall(mutator, self._doc)
	if not ok then
		self._doc = snapshot
		warn(Locale.T("error.commit", label, tostring(err)))
		self.Changed:Fire(self._doc, "revert")
		return false
	end

	table.insert(self._undo, snapshot)
	if #self._undo > UNDO_LIMIT then
		table.remove(self._undo, 1)
	end
	table.clear(self._redo)

	self:_setDirty(true)
	self.Changed:Fire(self._doc, label)
	return true
end

function Project:CanUndo(): boolean
	return #self._undo > 0
end

function Project:CanRedo(): boolean
	return #self._redo > 0
end

function Project:Undo()
	local snapshot = table.remove(self._undo)
	if not snapshot then
		return
	end
	table.insert(self._redo, deepCopy(self._doc))
	self._doc = snapshot
	self:_setDirty(true)
	self.Changed:Fire(self._doc, "undo")
end

function Project:Redo()
	local snapshot = table.remove(self._redo)
	if not snapshot then
		return
	end
	table.insert(self._undo, deepCopy(self._doc))
	self._doc = snapshot
	self:_setDirty(true)
	self.Changed:Fire(self._doc, "redo")
end

-- 저장이 성공한 뒤 호출한다.
function Project:MarkSaved()
	self:_setDirty(false)
end

function Project:Destroy()
	self.Changed:Destroy()
	self.DirtyChanged:Destroy()
	table.clear(self._undo)
	table.clear(self._redo)
end

return Project
