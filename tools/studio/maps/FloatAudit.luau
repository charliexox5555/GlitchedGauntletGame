--!strict
-- Map audit: finds floating parts (visible geometry that touches nothing that
-- holds it up; vault/01 Design/Maps/00 Maps.md → "Nothing floats"). Run in the
-- match place, edit mode, next to Audit.luau (z-fighting) on every install:
--
--   loadstring(<this file>)("Rooftops2")   (the map id is the chunk's argument)
--
-- It returns a summary and, when tools/studio/receive_server.py is listening,
-- saves the full list to art-source/maps/<Map>/float_audit.json.
--
-- How: every visible part is a node. Two parts are joined when they touch or
-- overlap, tested on real geometry: a Part is its box, a MeshPart its
-- triangles (EditableMesh). A vertex of one part that lies on or inside the
-- other (within EPS) is contact; so is a triangle centroid (crossing boxes). Inside / on a mesh is found by casting short
-- axis rays through a column grid of its triangles: a hit closer than EPS is
-- on the surface; a nearest hit leaving the mesh (a back face) means inside.
-- Parts at the bottom of the map (the street, the sea bed, the water) are the
-- ground. Every group of joined parts that can't reach the ground floats, and
-- is listed. Things meant to fly (birds, drifting ships) are skipped:
-- tags LifeGull / LifePigeon / LifeDrift, or attribute AllowFloat on the part
-- or an ancestor. Templates (a name with "Template", parked out of sight) too.

local ARGS = { ... }
local MAP: string = ARGS[1] or "Rooftops2"

local AssetService = game:GetService("AssetService")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

local EPS = 0.06 -- studs: closer than this counts as touching
local GROUND = 1.5 -- studs above the map's lowest visible point count as ground
local SKIP_FOLDERS = { Spawns = true, Barriers = true, Ambience = true }
local FLY_TAGS = { "LifeGull", "LifePigeon", "LifeDrift" }
local CHUNK = 60

local root = workspace:FindFirstChild(MAP)
assert(root, "no map " .. MAP)

local function skipped(p: Instance): boolean
	local a: Instance? = p
	while a and a ~= root do
		if a:GetAttribute("AllowFloat") == true or string.find(a.Name, "Template") then
			return true
		end
		for _, t in FLY_TAGS do
			if CollectionService:HasTag(a, t) then
				return true
			end
		end
		if a.Parent == root and SKIP_FOLDERS[a.Name] then
			return true
		end
		a = a.Parent
	end
	return false
end

-- Shapes -----------------------------------------------------------------------

type Tri = { a: Vector3, b: Vector3, c: Vector3, n: Vector3 }
type Grid = { [number]: { [string]: { Tri } } } -- axis -> cell key -> tris
type Shape = {
	part: BasePart,
	mesh: boolean,
	lo: Vector3,
	hi: Vector3,
	verts: { Vector3 },
	tris: { Tri }?,
	grid: Grid?,
	cell: number,
}

local meshCache: { [string]: any } = {}
local meshFailed = 0

local function localMesh(id: string): any
	local cached = meshCache[id]
	if cached ~= nil then
		return cached
	end
	local ok, em = pcall(function()
		return AssetService:CreateEditableMeshAsync(Content.fromUri(id))
	end)
	if not (ok and em) then
		meshFailed += 1
		meshCache[id] = false
		return false
	end
	local pos: { [number]: Vector3 } = {}
	local ids: { number } = {}
	local mn, mx = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, v in em:GetVertices() do
		local p = em:GetPosition(v)
		pos[v] = p
		table.insert(ids, v)
		mn, mx = mn:Min(p), mx:Max(p)
	end
	local faces = {}
	for _, f in em:GetFaces() do
		local vs = em:GetFaceVertices(f)
		if #vs >= 3 then
			table.insert(faces, { vs[1], vs[2], vs[3] })
		end
	end
	em:Destroy()
	local centre = (mn + mx) / 2
	local verts = {}
	for _, v in ids do
		verts[v] = pos[v] - centre
	end
	local out = { verts = verts, ids = ids, faces = faces }
	meshCache[id] = out
	return out
end

local AX = { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis }
local function comp(v: Vector3, i: number): number
	return if i == 1 then v.X elseif i == 2 then v.Y else v.Z
end
-- The two axes of the plane a column on axis i is keyed by.
local OTHER = { { 2, 3 }, { 1, 3 }, { 1, 2 } }

local function keyOf(u: number, v: number): string
	return u .. "," .. v
end

local function boxShape(p: BasePart): Shape
	local cf, h = p.CFrame, p.Size / 2
	local verts = {}
	for _, x in { -1, 0, 1 } do
		for _, y in { -1, 0, 1 } do
			for _, z in { -1, 0, 1 } do
				if x ~= 0 or y ~= 0 or z ~= 0 then
					table.insert(
						verts,
						cf:PointToWorldSpace(Vector3.new(x * h.X, y * h.Y, z * h.Z))
					)
				end
			end
		end
	end
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, v in verts do
		lo, hi = lo:Min(v), hi:Max(v)
	end
	return { part = p, mesh = false, lo = lo, hi = hi, verts = verts, cell = 0 }
end

local function meshShape(p: MeshPart): Shape?
	local m = localMesh(p.MeshId)
	if not m then
		return nil
	end
	local scale = p.Size / p.MeshSize
	local cf = p.CFrame
	local world: { [number]: Vector3 } = {}
	local verts = {}
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, v in m.ids do
		local w = cf:PointToWorldSpace(m.verts[v] * scale)
		world[v] = w
		table.insert(verts, w)
		lo, hi = lo:Min(w), hi:Max(w)
	end
	local ext = hi - lo
	local cell = math.max(2, math.max(ext.X, ext.Y, ext.Z) / 48)
	local tris: { Tri } = {}
	local grid: Grid = { {}, {}, {} }
	for _, f in m.faces do
		local a, b, c = world[f[1]], world[f[2]], world[f[3]]
		local n = (b - a):Cross(c - a)
		if n.Magnitude < 1e-9 then
			continue
		end
		local t = { a = a, b = b, c = c, n = n.Unit }
		table.insert(tris, t)
		-- the centroid is a test point too: two crossing boxes (a boom through a frame) overlap with no
		-- vertex of either inside the other, but their face centroids are
		table.insert(verts, (a + b + c) / 3)
		local tlo, thi = a:Min(b):Min(c), a:Max(b):Max(c)
		for i = 1, 3 do
			if math.abs(comp(t.n, i)) < 1e-4 then
				continue -- parallel to this axis: its rays never cross it
			end
			local o = OTHER[i]
			local g = grid[i]
			for u = math.floor(comp(tlo, o[1]) / cell), math.floor(comp(thi, o[1]) / cell) do
				for v = math.floor(comp(tlo, o[2]) / cell), math.floor(comp(thi, o[2]) / cell) do
					local k = keyOf(u, v)
					local list = g[k]
					if not list then
						list = {}
						g[k] = list
					end
					table.insert(list, t)
				end
			end
		end
	end
	return {
		part = p,
		mesh = true,
		lo = lo,
		hi = hi,
		verts = verts,
		tris = tris,
		grid = grid,
		cell = cell,
	}
end

-- Along axis i through q: the signed distance to each crossing of the mesh.
-- Returns the nearest |d| and whether the nearest crossing ahead is a back
-- face (leaving the mesh, so q is inside).
local function cast(s: Shape, q: Vector3, i: number): (number, boolean)
	local grid = s.grid :: Grid
	local o = OTHER[i]
	local qu, qv = comp(q, o[1]), comp(q, o[2])
	local list = grid[i][keyOf(math.floor(qu / s.cell), math.floor(qv / s.cell))]
	if not list then
		return math.huge, false
	end
	local qa = comp(q, i)
	local nearest = math.huge
	local ahead, aheadBack = math.huge, false
	for _, t in list do
		local au, av = comp(t.a, o[1]) - qu, comp(t.a, o[2]) - qv
		local bu, bv = comp(t.b, o[1]) - qu, comp(t.b, o[2]) - qv
		local cu, cv = comp(t.c, o[1]) - qu, comp(t.c, o[2]) - qv
		-- Point in the projected triangle (origin), either winding.
		local d1 = au * bv - av * bu
		local d2 = bu * cv - bv * cu
		local d3 = cu * av - cv * au
		local neg = d1 < -1e-7 or d2 < -1e-7 or d3 < -1e-7
		local pos = d1 > 1e-7 or d2 > 1e-7 or d3 > 1e-7
		if neg and pos then
			continue
		end
		local nn = comp(t.n, i)
		-- Plane: n . (x - a) = 0 → the axis coordinate at (qu, qv).
		local na, nb = comp(t.n, o[1]), comp(t.n, o[2])
		local x = comp(t.a, i) - (na * (qu - comp(t.a, o[1])) + nb * (qv - comp(t.a, o[2]))) / nn
		local d = x - qa
		if math.abs(d) < nearest then
			nearest = math.abs(d)
		end
		if d > 0 and d < ahead then
			ahead = d
			aheadBack = nn > 0
		end
	end
	return nearest, aheadBack
end

local function pointTouches(s: Shape, q: Vector3): boolean
	if
		q.X < s.lo.X - EPS
		or q.Y < s.lo.Y - EPS
		or q.Z < s.lo.Z - EPS
		or q.X > s.hi.X + EPS
		or q.Y > s.hi.Y + EPS
		or q.Z > s.hi.Z + EPS
	then
		return false
	end
	if not s.mesh then
		local rel = s.part.CFrame:PointToObjectSpace(q)
		local h = s.part.Size / 2 + Vector3.one * EPS
		return math.abs(rel.X) <= h.X and math.abs(rel.Y) <= h.Y and math.abs(rel.Z) <= h.Z
	end
	local insideVotes = 0
	for i = 1, 3 do
		local near, back = cast(s, q, i)
		if near <= EPS then
			return true
		end
		if back then
			insideVotes += 1
		end
	end
	return insideVotes >= 2
end

local function touching(a: Shape, b: Shape): boolean
	if
		a.hi.X < b.lo.X - EPS
		or a.hi.Y < b.lo.Y - EPS
		or a.hi.Z < b.lo.Z - EPS
		or a.lo.X > b.hi.X + EPS
		or a.lo.Y > b.hi.Y + EPS
		or a.lo.Z > b.hi.Z + EPS
	then
		return false
	end
	for _, v in a.verts do
		if pointTouches(b, v) then
			return true
		end
	end
	for _, v in b.verts do
		if pointTouches(a, v) then
			return true
		end
	end
	return false
end

-- Build ------------------------------------------------------------------------

local shapes: { Shape } = {}
local index: { [BasePart]: number } = {}
local restore: { BasePart } = {}
for _, d in root:GetDescendants() do
	if not d:IsA("BasePart") or d.Transparency >= 0.99 or skipped(d) then
		continue
	end
	local s: Shape? = if d:IsA("MeshPart") then meshShape(d) else nil
	if not s then
		s = boxShape(d)
	end
	table.insert(shapes, s :: Shape)
	index[d] = #shapes
	if not d.CanQuery then
		d.CanQuery = true
		table.insert(restore, d)
	end
	if #shapes % CHUNK == 0 then
		task.wait()
	end
end

local parent: { number } = {}
for i = 1, #shapes do
	parent[i] = i
end
local function find(i: number): number
	while parent[i] ~= i do
		parent[i] = parent[parent[i]]
		i = parent[i]
	end
	return i
end

local minY = math.huge
for _, s in shapes do
	minY = math.min(minY, s.lo.Y)
end
local GROUND_NODE = #shapes + 1
parent[GROUND_NODE] = GROUND_NODE
for i, s in shapes do
	if s.lo.Y <= minY + GROUND then
		parent[find(i)] = find(GROUND_NODE)
	end
end

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include
overlap.FilterDescendantsInstances = { root }
local tested = 0
for i, s in shapes do
	if i % CHUNK == 0 then
		task.wait()
	end
	local size = s.hi - s.lo + Vector3.one * (EPS * 2)
	for _, o in workspace:GetPartBoundsInBox(CFrame.new((s.lo + s.hi) / 2), size, overlap) do
		local j = index[o]
		if not j or j == i then
			continue
		end
		local ri, rj = find(i), find(j)
		if ri == rj then
			continue
		end
		tested += 1
		if touching(s, shapes[j]) then
			parent[ri] = rj
		end
	end
end

-- Report -----------------------------------------------------------------------

local pivot = root:GetPivot()
local function path(p: Instance): string
	return string.sub(p:GetFullName(), #root:GetFullName() + 2)
end
-- The placed piece a part belongs to: the model just under a category folder.
local function piece(p: Instance): Instance
	local a: Instance = p
	while a.Parent and a.Parent ~= root and a.Parent.Parent ~= root and a.Parent.Parent ~= nil do
		a = a.Parent
	end
	return if a:IsA("Model") or a:IsA("BasePart") then a else p
end

local groups: { [number]: { number } } = {}
local ground = find(GROUND_NODE)
for i = 1, #shapes do
	local r = find(i)
	if r ~= ground then
		local g = groups[r]
		if not g then
			g = {}
			groups[r] = g
		end
		table.insert(g, i)
	end
end

type Float = { pieces: { string }, parts: { string }, at: { number }, size: { number }, gap: number? }
local found: { Float } = {}
local down = RaycastParams.new()
down.FilterType = Enum.RaycastFilterType.Include
down.FilterDescendantsInstances = { root }
for _, g in groups do
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	local names, pieceSet, pieceNames = {}, {}, {}
	local members = {}
	for _, i in g do
		local s = shapes[i]
		lo, hi = lo:Min(s.lo), hi:Max(s.hi)
		table.insert(members, s.part)
		if #names < 12 then
			table.insert(names, path(s.part))
		end
		local pc = piece(s.part)
		if not pieceSet[pc] then
			pieceSet[pc] = true
			table.insert(pieceNames, path(pc))
		end
	end
	-- How far it hangs above whatever is under its centre.
	local c = (lo + hi) / 2
	local exclude = RaycastParams.new()
	exclude.FilterType = Enum.RaycastFilterType.Exclude
	exclude.FilterDescendantsInstances = members
	local hit =
		workspace:Raycast(Vector3.new(c.X, lo.Y - 0.01, c.Z), Vector3.new(0, -60, 0), exclude)
	local at = pivot:PointToObjectSpace(c)
	table.insert(found, {
		pieces = pieceNames,
		parts = names,
		at = { math.round(at.X * 10) / 10, math.round(at.Y * 10) / 10, math.round(at.Z * 10) / 10 },
		size = {
			math.round((hi.X - lo.X) * 10) / 10,
			math.round((hi.Y - lo.Y) * 10) / 10,
			math.round((hi.Z - lo.Z) * 10) / 10,
		},
		gap = if hit then math.round(hit.Distance * 100) / 100 else nil,
	})
end
for _, p in restore do
	p.CanQuery = false
end
table.sort(found, function(a, b)
	return a.size[1] * a.size[2] * a.size[3] > b.size[1] * b.size[2] * b.size[3]
end)

local lines = {
	string.format(
		"%s: %d visible parts, %d floating groups (%d pair tests)%s",
		MAP,
		#shapes,
		#found,
		tested,
		if meshFailed > 0
			then string.format(" (%d meshes unreadable, tested as boxes)", meshFailed)
			else ""
	),
}
for i = 1, math.min(#found, 40) do
	local f = found[i]
	table.insert(
		lines,
		string.format(
			"  %s at (%g, %g, %g) size %gx%gx%g gap %s",
			table.concat(f.pieces, " + "),
			f.at[1],
			f.at[2],
			f.at[3],
			f.size[1],
			f.size[2],
			f.size[3],
			if f.gap then tostring(f.gap) else "none"
		)
	)
end

pcall(function()
	HttpService:RequestAsync({
		Url = "http://127.0.0.1:34999/save?path=art-source/maps/" .. MAP .. "/float_audit.json",
		Method = "POST",
		Body = HttpService:JSONEncode(found),
	})
end)

return table.concat(lines, "\n")
