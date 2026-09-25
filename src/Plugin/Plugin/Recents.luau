--!strict
-- 최근에 연 작업 목록. plugin 설정에 저장되므로 플레이스가 아니라 사용자에게 따라붙는다.

local PluginEnv = require(script.Parent.PluginEnv)

local MAX_ENTRIES = 12
local SETTING_KEY = "recents"

local Recents = {}

export type Entry = {
	name: string,
	placeId: number,
	openedAt: number,
}

local function currentPlaceId(): number
	return game.PlaceId
end

function Recents.GetAll(): { Entry }
	local raw = PluginEnv.GetSetting(SETTING_KEY, nil)
	if typeof(raw) ~= "table" then
		return {}
	end

	local entries: { Entry } = {}
	for _, item in raw do
		if typeof(item) == "table" and typeof(item.name) == "string" then
			table.insert(entries, {
				name = item.name,
				placeId = tonumber(item.placeId) or 0,
				openedAt = tonumber(item.openedAt) or 0,
			})
		end
	end
	return entries
end

-- 다른 플레이스에서 만든 작업은 여기 저장 폴더에 없으므로 걸러낸다.
function Recents.GetForThisPlace(): { Entry }
	local placeId = currentPlaceId()
	local result: { Entry } = {}
	for _, entry in Recents.GetAll() do
		if entry.placeId == placeId then
			table.insert(result, entry)
		end
	end
	table.sort(result, function(a, b)
		return a.openedAt > b.openedAt
	end)
	return result
end

local function save(entries: { Entry })
	PluginEnv.SetSetting(SETTING_KEY, entries)
end

function Recents.Touch(name: string)
	local entries = Recents.GetAll()
	local placeId = currentPlaceId()

	for index = #entries, 1, -1 do
		local entry = entries[index]
		if entry.name == name and entry.placeId == placeId then
			table.remove(entries, index)
		end
	end

	table.insert(entries, 1, { name = name, placeId = placeId, openedAt = os.time() })

	while #entries > MAX_ENTRIES do
		table.remove(entries)
	end

	save(entries)
end

function Recents.Remove(name: string)
	local entries = Recents.GetAll()
	local placeId = currentPlaceId()
	for index = #entries, 1, -1 do
		local entry = entries[index]
		if entry.name == name and entry.placeId == placeId then
			table.remove(entries, index)
		end
	end
	save(entries)
end

-- 이름이 바뀐 작업이 목록에서 사라지지 않게 한다.
function Recents.Rename(oldName: string, newName: string)
	local entries = Recents.GetAll()
	local placeId = currentPlaceId()
	for _, entry in entries do
		if entry.name == oldName and entry.placeId == placeId then
			entry.name = newName
		end
	end
	save(entries)
end

return Recents
