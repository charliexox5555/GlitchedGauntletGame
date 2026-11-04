--!strict
-- Map audit: finds z-fighting (two visible surfaces in the same plane that
-- overlap, so the renderer flickers between them; vault/01 Design/Maps/00
-- Maps.md → "No z-fighting"). Run in the match place, edit mode:
--
--   loadstring(<this file>)("Metro")   (the map id is the chunk's argument;
--   the Studio MCP can fetch the file from a local server). It returns a
--   summary and, when tools/studio/receive_server.py is listening, saves the
--   full list to art-source/maps/<Map>/audit.json.
--
-- How: every visible part's box faces are candidate planes. For each pair of
-- parts whose boxes touch and that have parallel faces within PLANE_TOL of the
-- same plane, rays are cast at sample points over the shared rectangle, once
-- against each part alone. Where both parts are hit at the same distance (within
-- HIT_TOL), the two surfaces really coincide there: a z-fight. Rays make it
-- work for MeshParts too (a curved mesh whose box face is in the plane but whose
-- surface isn't won't match). Surfaces that aren't on a box face (a slanted
-- mesh face) aren't checked.

local ARGS = { ... }
local MAP: string = ARGS[1] or "Metro"
-- Fix mode (second argument true): for each pair, the lesser part (a paint /
-- band / trim part, else the smaller one) moves its coinciding face in by
-- FIX_DEPTH: a Part shrinks that face (an invisible 0.04), a MeshPart is
-- nudged along the normal, away from the other part. For hand-built Part maps
-- (Whitebox); kit-built maps are fixed at their source scripts instead.
local FIX: boolean = ARGS[2] == true
local FIX_DEPTH = 0.04

local PLANE_TOL = 0.02 -- studs: parallel faces closer than this are "the same plane"
local HIT_TOL = 0.006 -- studs: both surfaces hit this close together = coincident
local SAMPLES = 5 -- per axis over the shared rectangle (25 rays per face pair)
local MIN_HITS = 3 -- coincident samples needed to report a pair
local CHUNK = 150 -- parts per yield

local HttpService = game:GetService("HttpService")

local root = workspace:FindFirstChild(MAP)
assert(root, "no map " .. MAP)

type Face = { n: Vector3, c: Vector3, u: Vector3, v: Vector3, hu: number, hv: number }

local function visible(p: BasePart): boolean
	if p.Transparency >= 0.99 then
		return false
	end
	if p.Size.X < 0.02 or p.Size.Y < 0.02 or p.Size.Z < 0.02 then
		-- A plate this thin still has two faces; keep it.
		return p.Size.Magnitude > 0.05
	end
	return true
end

local function faces(p: BasePart): { Face }
	local cf, s = p.CFrame, p.Size / 2
	local axes = { cf.RightVector, cf.UpVector, -cf.LookVector }
	local half = { s.X, s.Y, s.Z }
	local out: { Face } = {}
	for i = 1, 3 do
		local j, k = (i % 3) + 1, ((i + 1) % 3) + 1
		for _, sign in { 1, -1 } do
			table.insert(out, {
				n = axes[i] * sign,
				c = cf.Position + axes[i] * sign * half[i],
				u = axes[j],
				v = axes[k],
				hu = half[j],
				hv = half[k],
			})
		end
	end
	return out
end

local function project(f: Face, axis: Vector3): (number, number)
	-- Interval of the face's rectangle along `axis`.
	local c = f.c:Dot(axis)
	local r = math.abs(f.u:Dot(axis)) * f.hu + math.abs(f.v:Dot(axis)) * f.hv
	return c - r, c + r
end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include

-- A spot only counts when it can be seen: the point just outside it must not
-- be inside another visible solid block (a bottom face on the floor, a face
-- buried in a wall). MeshParts are left out of this test (their boxes are
-- too coarse to say a point is inside them).
local probe = OverlapParams.new()
probe.FilterType = Enum.RaycastFilterType.Include
local function buried(q: Vector3, a: BasePart, b: BasePart): boolean
	for _, o in workspace:GetPartBoundsInBox(CFrame.new(q), Vector3.new(0.02, 0.02, 0.02), probe) do
		if
			o ~= a
			and o ~= b
			and o:IsA("Part")
			and o.Shape == Enum.PartType.Block
			and o.Transparency < 0.99
		then
			local rel = o.CFrame:PointToObjectSpace(q)
			local h = o.Size / 2
			if math.abs(rel.X) < h.X and math.abs(rel.Y) < h.Y and math.abs(rel.Z) < h.Z then
				return true
			end
		end
	end
	return false
end

local function hitDistance(part: BasePart, from: Vector3, dir: Vector3): number?
	params.FilterDescendantsInstances = { part }
	local r = workspace:Raycast(from, dir, params)
	return if r then r.Distance else nil
end

-- Collect parts; make every part queryable for the audit (restored after).
local parts: { BasePart } = {}
local restore: { [BasePart]: boolean } = {}
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") and visible(d) then
		table.insert(parts, d)
		if not d.CanQuery then
			restore[d] = true
			d.CanQuery = true
		end
	end
end

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include
overlap.FilterDescendantsInstances = { root }
probe.FilterDescendantsInstances = { root }

local seen: { [string]: boolean } = {}
type Hit = { a: string, b: string, at: { number }, normal: { number }, hits: number, area: number }
type Pair = { a: BasePart, b: BasePart, at: Vector3, n: Vector3 }
local pairsFound: { Pair } = {}
local found: { Hit } = {}
local pivot = root:GetPivot()

local function path(p: Instance): string
	return string.sub(p:GetFullName(), #root:GetFullName() + 2)
end

for idx, a in parts do
	if idx % CHUNK == 0 then
		task.wait()
	end
	local near =
		workspace:GetPartBoundsInBox(a.CFrame, a.Size + Vector3.new(0.1, 0.1, 0.1), overlap)
	local fa = faces(a)
	for _, b in near do
		if b == a or not visible(b) then
			continue
		end
		local key = if a:GetDebugId() < b:GetDebugId()
			then a:GetDebugId() .. b:GetDebugId()
			else b:GetDebugId() .. a:GetDebugId()
		if seen[key] then
			continue
		end
		seen[key] = true
		local fb = faces(b)
		local best = 0
		local bestAt, bestN, bestArea = Vector3.zero, Vector3.zero, 0
		for _, f1 in fa do
			for _, f2 in fb do
				if math.abs(f1.n:Dot(f2.n)) < 0.9995 then
					continue
				end
				if math.abs((f2.c - f1.c):Dot(f1.n)) > PLANE_TOL then
					continue
				end
				-- Shared rectangle along f1's u and v.
				local a0, a1 = project(f1, f1.u)
				local b0, b1 = project(f2, f1.u)
				local u0, u1 = math.max(a0, b0), math.min(a1, b1)
				a0, a1 = project(f1, f1.v)
				b0, b1 = project(f2, f1.v)
				local v0, v1 = math.max(a0, b0), math.min(a1, b1)
				if u1 - u0 < 0.05 or v1 - v0 < 0.05 then
					continue
				end
				local planeD = f1.c:Dot(f1.n)
				local hits = 0
				for i = 1, SAMPLES do
					for j = 1, SAMPLES do
						local su = u0 + (u1 - u0) * (i - 0.5) / SAMPLES
						local sv = v0 + (v1 - v0) * (j - 0.5) / SAMPLES
						-- Point on the plane: start from the u/v coordinates.
						local p = f1.u * su + f1.v * sv
						p = p + f1.n * (planeD - p:Dot(f1.n))
						-- Look at the plane from both sides (one of them is the outside).
						for _, side in { 1, -1 } do
							local from = p + f1.n * side * 0.5
							local dir = -f1.n * side * 1
							local da = hitDistance(a, from, dir)
							local db = hitDistance(b, from, dir)
							if da and db and math.abs(da - db) < HIT_TOL then
								local q = from + dir * (da - 0.05)
								if not buried(q, a, b) then
									hits += 1
								end
								break
							end
						end
					end
				end
				if hits > best then
					best = hits
					bestAt = f1.c
					bestN = f1.n
					bestArea = (u1 - u0) * (v1 - v0)
				end
			end
		end
		if best >= MIN_HITS then
			table.insert(pairsFound, { a = a, b = b, at = bestAt, n = bestN })
			local local_ = pivot:PointToObjectSpace(bestAt)
			table.insert(found, {
				a = path(a),
				b = path(b),
				at = {
					math.round(local_.X * 10) / 10,
					math.round(local_.Y * 10) / 10,
					math.round(local_.Z * 10) / 10,
				},
				normal = { math.round(bestN.X), math.round(bestN.Y), math.round(bestN.Z) },
				hits = best,
				area = math.round(bestArea * 10) / 10,
			})
		end
	end
end

-- Fix mode: move the lesser part's coinciding face off the plane.
local DECOR_NAMES = { "Band", "Paint", "Trim", "Stripe", "Line", "Sign", "Letter" }
local function isDecor(p: BasePart): boolean
	for _, k in DECOR_NAMES do
		if string.find(p.Name, k) then
			return true
		end
	end
	local parent = p.Parent
	return parent ~= nil and parent.Name == "Paint"
end
local fixed = 0
if FIX then
	for _, pr in pairsFound do
		local a, b = pr.a, pr.b
		local lesser, other = a, b
		if isDecor(b) and not isDecor(a) then
			lesser, other = b, a
		elseif
			isDecor(a) == isDecor(b)
			and b.Size.X * b.Size.Y * b.Size.Z < a.Size.X * a.Size.Y * a.Size.Z
		then
			lesser, other = b, a
		end
		local n = pr.n
		if lesser:IsA("MeshPart") then
			-- Away from the other part's centre, along the normal.
			local away = if (lesser.Position - other.Position):Dot(n) >= 0 then n else -n
			lesser.CFrame += away * 0.03
			fixed += 1
			continue
		end
		-- The lesser part's local axis along n, and which of its faces lies in the plane.
		local cf = lesser.CFrame
		local axes = { cf.RightVector, cf.UpVector, cf.LookVector }
		local sizes = { lesser.Size.X, lesser.Size.Y, lesser.Size.Z }
		for i, ax in axes do
			if math.abs(ax:Dot(n)) > 0.999 then
				local planeD = pr.at:Dot(n)
				local sign = if (cf.Position + ax * sizes[i] / 2):Dot(n) - planeD < 0.03
						and (cf.Position + ax * sizes[i] / 2):Dot(n) - planeD > -0.03
					then 1
					else -1
				if sizes[i] > FIX_DEPTH * 3 then
					local grow = Vector3.zero
					if i == 1 then
						grow = Vector3.new(-FIX_DEPTH, 0, 0)
					elseif i == 2 then
						grow = Vector3.new(0, -FIX_DEPTH, 0)
					else
						grow = Vector3.new(0, 0, -FIX_DEPTH)
					end
					lesser.Size += grow
					lesser.CFrame = cf - ax * sign * FIX_DEPTH / 2
				else
					-- Too thin to shrink (a paint plate): lift it off instead.
					lesser.CFrame = cf + ax * sign * FIX_DEPTH
				end
				fixed += 1
				break
			end
		end
	end
end

for p in restore do
	p.CanQuery = false
end

-- Summary: counts by the pair of part names (without numbers), biggest first.
local groups: { [string]: number } = {}
for _, h in found do
	local na = string.gsub(string.match(h.a, "[^%.]+$") or h.a, "%d+", "#")
	local nb = string.gsub(string.match(h.b, "[^%.]+$") or h.b, "%d+", "#")
	local g = if na < nb then na .. " + " .. nb else nb .. " + " .. na
	groups[g] = (groups[g] or 0) + 1
end
local list = {}
for g, n in groups do
	table.insert(list, { g = g, n = n })
end
table.sort(list, function(x, y)
	return x.n > y.n
end)
local lines = {
	string.format(
		"%s: %d visible parts, %d z-fighting pairs%s",
		MAP,
		#parts,
		#found,
		if FIX then string.format(" (fixed %d)", fixed) else ""
	),
}
for i = 1, math.min(#list, 25) do
	table.insert(lines, string.format("  %3d  %s", list[i].n, list[i].g))
end

pcall(function()
	HttpService:RequestAsync({
		Url = "http://127.0.0.1:34999/save?path=art-source/maps/" .. MAP .. "/audit.json",
		Method = "POST",
		Body = HttpService:JSONEncode(found), -- .json is saved as sent (only .rbxm is base64)
	})
end)

return table.concat(lines, "\n")
