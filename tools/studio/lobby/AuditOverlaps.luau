--!strict
-- AuditOverlaps.luau: z-fighting audit for the built Lobby (Workspace.Lobby.Hub). Edit mode, read-only.
-- For every pair of visible parts (Transparency < 1) whose boxes touch, it compares the 6 box faces of each: two faces
-- that face the same way, lie in the same plane (within EPS) and overlap by more than MIN_AREA studs² are a z-fight
-- candidate. Faces inside one kit piece (same Model) are skipped: kit pieces are audited per mesh in Blender
-- (tools/blender/audit_lobby_coplanar.py). Mesh boxes are a conservative stand-in for mesh faces, so every finding is
-- looked at, not auto-fixed. Returns a summary line plus up to 40 findings.
local root = workspace:WaitForChild("Lobby"):WaitForChild("Hub")
local EPS, MIN_AREA, CELL = 0.03, 0.05, 16

type Face = { n: Vector3, d: number, pts: { Vector3 } }

local function faces(p: BasePart): { Face }
	local cf, s = p.CFrame, p.Size / 2
	local out = {}
	for _, ax in { { cf.RightVector, s.X, cf.UpVector, s.Y, cf.LookVector, s.Z }, { cf.UpVector, s.Y, cf.RightVector, s.X, cf.LookVector, s.Z }, { cf.LookVector, s.Z, cf.RightVector, s.X, cf.UpVector, s.Y } } do
		local n: Vector3, h: number, u: Vector3, hu: number, v: Vector3, hv: number = ax[1], ax[2], ax[3], ax[4], ax[5], ax[6]
		for _, sgn in { 1, -1 } do
			local c = cf.Position + n * h * sgn
			table.insert(out, {
				n = n * sgn,
				d = (n * sgn):Dot(c),
				pts = { c + u * hu + v * hv, c - u * hu + v * hv, c - u * hu - v * hv, c + u * hu - v * hv },
			})
		end
	end
	return out
end

-- Overlap area of two convex polygons in a plane (Sutherland-Hodgman), given a 2D basis.
local function area2(poly: { Vector2 }): number
	local a = 0
	for i = 1, #poly do
		local p, q = poly[i], poly[i % #poly + 1]
		a += p.X * q.Y - q.X * p.Y
	end
	return math.abs(a) / 2
end
local function clip(subject: { Vector2 }, clipper: { Vector2 }): { Vector2 }
	local out = subject
	local ccw = 0
	for i = 1, #clipper do
		local p, q = clipper[i], clipper[i % #clipper + 1]
		ccw += p.X * q.Y - q.X * p.Y
	end
	local sgn = if ccw >= 0 then 1 else -1
	for i = 1, #clipper do
		local a, b = clipper[i], clipper[i % #clipper + 1]
		local input = out
		out = {}
		if #input == 0 then
			break
		end
		local function inside(p: Vector2): boolean
			return sgn * ((b.X - a.X) * (p.Y - a.Y) - (b.Y - a.Y) * (p.X - a.X)) >= -1e-6
		end
		local prev = input[#input]
		for _, cur in input do
			local ci, pi = inside(cur), inside(prev)
			if ci ~= pi then
				local d1 = (b.X - a.X) * (prev.Y - a.Y) - (b.Y - a.Y) * (prev.X - a.X)
				local d2 = (b.X - a.X) * (cur.Y - a.Y) - (b.Y - a.Y) * (cur.X - a.X)
				local t = d1 / (d1 - d2)
				table.insert(out, prev + (cur - prev) * t)
			end
			if ci then
				table.insert(out, cur)
			end
			prev = cur
		end
	end
	return out
end

local parts: { BasePart } = {}
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") and d.Transparency < 1 then
		table.insert(parts, d)
	end
end

-- Broad phase: hash every part's world AABB into CELL-sized cells.
local grid: { [string]: { number } } = {}
local boxes: { { Vector3 } } = {}
for i, p in parts do
	local cf, s = p.CFrame, p.Size / 2
	local ext = Vector3.new(
		math.abs(cf.RightVector.X) * s.X + math.abs(cf.UpVector.X) * s.Y + math.abs(cf.LookVector.X) * s.Z,
		math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z,
		math.abs(cf.RightVector.Z) * s.X + math.abs(cf.UpVector.Z) * s.Y + math.abs(cf.LookVector.Z) * s.Z
	)
	local lo, hi = cf.Position - ext - Vector3.one * EPS, cf.Position + ext + Vector3.one * EPS
	boxes[i] = { lo, hi }
	for x = math.floor(lo.X / CELL), math.floor(hi.X / CELL) do
		for y = math.floor(lo.Y / CELL), math.floor(hi.Y / CELL) do
			for z = math.floor(lo.Z / CELL), math.floor(hi.Z / CELL) do
				local k = x .. "," .. y .. "," .. z
				grid[k] = grid[k] or {}
				table.insert(grid[k], i)
			end
		end
	end
end

local findings = {}
local seen: { [string]: boolean } = {}
local faceCache: { [number]: { Face } } = {}
for _, list in grid do
	for a = 1, #list do
		for b = a + 1, #list do
			local i, j = math.min(list[a], list[b]), math.max(list[a], list[b])
			local key = i .. ":" .. j
			if not seen[key] then
				seen[key] = true
				local A, B = parts[i], parts[j]
				local ba, bb = boxes[i], boxes[j]
				local touch = ba[1].X <= bb[2].X and bb[1].X <= ba[2].X and ba[1].Y <= bb[2].Y and bb[1].Y <= ba[2].Y and ba[1].Z <= bb[2].Z and bb[1].Z <= ba[2].Z
				local sameModel = A:FindFirstAncestorOfClass("Model") ~= nil and A:FindFirstAncestorOfClass("Model") == B:FindFirstAncestorOfClass("Model")
				if touch and not sameModel then
					faceCache[i] = faceCache[i] or faces(A)
					faceCache[j] = faceCache[j] or faces(B)
					for _, fa in faceCache[i] do
						for _, fb in faceCache[j] do
							-- Bottoms at floor level (buried) and roof tops above the ceilings are never seen.
							local hidden = (fa.n.Y < -0.99 and fa.pts[1].Y < 3) or (fa.n.Y > 0.99 and fa.pts[1].Y > 21.5)
							if not hidden and fa.n:Dot(fb.n) > 0.999 and math.abs(fa.d - fb.d) < EPS then
								local u = (fa.pts[1] - fa.pts[2]).Unit
								local v = fa.n:Cross(u)
								local function to2(list2: { Vector3 }): { Vector2 }
									local o = {}
									for _, p in list2 do
										table.insert(o, Vector2.new(p:Dot(u), p:Dot(v)))
									end
									return o
								end
								local poly = clip(to2(fb.pts), to2(fa.pts))
								local ar = if #poly >= 3 then area2(poly) else 0
								if ar > MIN_AREA then
									table.insert(findings, { ar, A:GetFullName(), B:GetFullName(), fa.n })
								end
							end
						end
					end
				end
			end
		end
	end
end
table.sort(findings, function(x, y)
	return x[1] > y[1]
end)
local out = { ("parts %d, z-fight candidates %d"):format(#parts, #findings) }
for k = 1, math.min(40, #findings) do
	local f = findings[k]
	table.insert(out, ("%.2f  %s  |  %s  n=%s"):format(f[1], string.gsub(f[2], "Workspace.Lobby.Hub.", ""), string.gsub(f[3], "Workspace.Lobby.Hub.", ""), tostring(f[4])))
end
return table.concat(out, "\n")
