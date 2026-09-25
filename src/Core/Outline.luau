--!nonstrict
-- 문서를 한 줄짜리 행 목록으로 편다.
--
-- 왼쪽 엘리먼트 트리와 오른쪽 타임라인이 같은 목록을 쓴다.
-- 그래야 두 패널의 행 높이가 어긋날 일이 없다.

local Ops = require(script.Parent.Ops)
local PathSpec = require(script.Parent.PathSpec)

local Outline = {}

Outline.ITEM_HEIGHT = 30
Outline.ELEMENT_HEIGHT = 22
Outline.TRACK_HEIGHT = 22

export type Row = {
	kind: string, -- "item" | "element" | "track"
	height: number,
	offset: number, -- 목록 맨 위에서의 y 좌표
	key: string, -- 접힘 상태와 선택을 가리키는 고유 키
	depth: number,

	itemId: number,
	item: any?,
	path: string?,
	-- 엘리먼트 줄에 보여줄 이름. 부모 밑에 들어갔으면 부모 다음 조각만 남는다.
	label: string?,
	track: any?,
	childCount: number?,
	collapsed: boolean?,
}

function Outline.itemKey(itemId: number): string
	return "i" .. tostring(itemId)
end

function Outline.elementKey(itemId: number, path: string): string
	return "e" .. tostring(itemId) .. "|" .. path
end

function Outline.trackKey(itemId: number, path: string, target: string): string
	return "t" .. tostring(itemId) .. "|" .. path .. "|" .. target
end

-- 부모 밑에 들어간 줄에 쓸 이름. 부모 경로 다음 조각들만 남긴다.
--   ("Frame.UIStroke", "Frame")  ->  "UIStroke"
--   ("Frame.UIStroke", nil)      ->  "Frame.UIStroke"
-- 부모가 없을 때 통째로 쓰는 건, 중간 단계(Frame)가 엘리먼트로 존재하지
-- 않는데 줄만 만들어 두면 눌러도 할 게 없는 빈 줄이 되기 때문이다.
local function relativeLabel(path: string, parentPath: string?): string
	if not parentPath or parentPath == "" then
		return if path == "" then PathSpec.leafName(path) else path
	end
	return string.sub(path, #parentPath + 2)
end

-- 엘리먼트를 부모-자식으로 묶는다.
-- 부모는 "내 경로의 앞부분이면서 가장 긴" 엘리먼트다. 형제끼리는 원래
-- 순서를 지킨다 (트랙을 먼저 만든 쪽이 위).
--
-- 빈 경로("")는 부모로 치지 않는다. 그건 아이템 자신이고 그 줄은 이미
-- 위에 아이템으로 있다. 부모로 삼으면 접었을 때 아이템의 모든 줄이
-- 같이 사라져 버린다.
local function groupByPath(elements)
	local byPath = {}
	for _, element in elements do
		byPath[element.path] = element
	end

	local function parentPathOf(path: string): string?
		local segments = PathSpec.split(path)
		for count = #segments - 1, 1, -1 do
			local head = table.concat(segments, ".", 1, count)
			if byPath[head] then
				return head
			end
		end
		return nil
	end

	local roots = {}
	local childrenOf: { [string]: { any } } = {}

	for _, element in elements do
		local parentPath = parentPathOf(element.path)
		if parentPath then
			local bucket = childrenOf[parentPath]
			if not bucket then
				bucket = {}
				childrenOf[parentPath] = bucket
			end
			table.insert(bucket, element)
		else
			table.insert(roots, element)
		end
	end

	return roots, childrenOf
end

-- collapsed는 접어둔 키만 담는다. 기본은 펼침이다.
function Outline.build(doc, collapsed: { [string]: boolean }): ({ Row }, number)
	local rows: { Row } = {}
	local offset = 0

	local function push(row)
		row.offset = offset
		offset += row.height
		table.insert(rows, row)
	end

	-- Id 순으로 보여준다. Id를 맞바꾸면 목록에서도 자리가 바뀌어야 한다.
	local items = table.clone(doc.items)
	table.sort(items, function(a, b)
		return a.id < b.id
	end)

	for _, item in items do
		local elements = Ops.elementsOf(doc, item.id)
		local itemKey = Outline.itemKey(item.id)
		local itemCollapsed = collapsed[itemKey] == true

		-- 경로가 겹치는 엘리먼트는 트리로 보여준다.
		-- Frame 과 Frame.UIStroke 가 둘 다 있으면 UIStroke를 Frame 안에 넣는다.
		local roots, childrenOf = groupByPath(elements)

		push({
			kind = "item",
			height = Outline.ITEM_HEIGHT,
			key = itemKey,
			depth = 0,
			itemId = item.id,
			item = item,
			childCount = #elements,
			collapsed = itemCollapsed,
		})

		if itemCollapsed then
			continue
		end

		local function pushElement(element, depth: number, parentPath: string?)
			local elementKey = Outline.elementKey(item.id, element.path)
			local elementCollapsed = collapsed[elementKey] == true
			local children = childrenOf[element.path] or {}

			push({
				kind = "element",
				height = Outline.ELEMENT_HEIGHT,
				key = elementKey,
				depth = depth,
				itemId = item.id,
				item = item,
				path = element.path,
				-- 부모 밑에 들어간 줄은 부모 다음 조각만 보여준다.
				-- 부모가 될 엘리먼트가 없으면 남은 경로를 통째로 쓴다.
				label = relativeLabel(element.path, parentPath),
				-- 화살표는 트랙과 하위 엘리먼트를 합쳐서 판단한다.
				childCount = #element.tracks + #children,
				collapsed = elementCollapsed,
			})

			if elementCollapsed then
				return
			end

			for _, track in element.tracks do
				push({
					kind = "track",
					height = Outline.TRACK_HEIGHT,
					key = Outline.trackKey(item.id, element.path, track.target),
					depth = depth + 1,
					itemId = item.id,
					item = item,
					path = element.path,
					track = track,
				})
			end

			for _, child in children do
				pushElement(child, depth + 1, element.path)
			end
		end

		for _, element in roots do
			pushElement(element, 1, nil)
		end
	end

	return rows, offset
end

return Outline
