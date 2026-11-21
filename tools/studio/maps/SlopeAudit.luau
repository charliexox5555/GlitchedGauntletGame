--!strict
-- Slope / rotated-face audit (2026-11-21, after the owner saw flicker the box-face audit missed): Audit.luau only
-- tests faces that lie on box faces of axis planes it pairs up; a WedgePart's slope and the faces of rotated parts
-- (roof planes, braces, stringers) can still coincide with another surface. For every visible WedgePart slope and
-- every face of a rotated Part, a grid of rays is cast at the surface from 0.4 outside, against everything but the
-- part itself: a hit within HIT_TOL of the surface, on a face that points the same way, is a coincident surface.
-- Run in the match place, edit mode: require(<clone>)("Wharf") → summary lines.

local HIT_TOL = 0.012
local GRID = 4

return function(mapName: string): string
	local map = workspace:FindFirstChild(mapName)
	assert(map, "no map " .. mapName)
	local parts: { BasePart } = {}
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.95 then
			table.insert(parts, d)
		end
	end
	-- rays must see every visible part and nothing invisible: flip CanQuery for the run, restore after
	local saved: { [BasePart]: boolean } = {}
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") then
			saved[d] = d.CanQuery
			d.CanQuery = d.Transparency < 0.95
		end
	end
	local found: { [string]: number } = {}
	local examples: { [string]: string } = {}
	local function isAxis(cf: CFrame): boolean
		local function ax(v: Vector3): boolean
			local a = v:Abs()
			return math.max(a.X, a.Y, a.Z) > 0.999
		end
		return ax(cf.RightVector) and ax(cf.UpVector)
	end
	local function probe(
		p: BasePart,
		origin: Vector3,
		n: Vector3,
		u: Vector3,
		v: Vector3,
		w: number,
		h: number
	)
		local hits = 0
		for i = 1, GRID do
			for j = 1, GRID do
				local a = ((i - 0.5) / GRID - 0.5) * w * 0.9
				local b = ((j - 0.5) / GRID - 0.5) * h * 0.9
				local pt = origin + u * a + v * b
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = { p }
				local r = workspace:Raycast(pt + n * 0.4, -n * 0.8, params)
				if
					r
					and r.Instance:IsA("BasePart")
					and (r.Instance :: BasePart).Transparency < 0.95
					and math.abs((r.Position - pt):Dot(n)) < HIT_TOL
					and r.Normal:Dot(n) > 0.995
				then
					hits += 1
					if hits >= 2 then
						local key = p.Name .. " + " .. r.Instance.Name
						found[key] = (found[key] or 0) + 1
						if not examples[key] then
							local rel = map:GetPivot():PointToObjectSpace(pt)
							examples[key] = string.format("(%.1f, %.1f, %.1f)", rel.X, rel.Y, rel.Z)
						end
						return
					end
				end
			end
		end
	end
	local nChecked = 0
	for k, p in parts do
		local cf, s = p.CFrame, p.Size
		if p:IsA("WedgePart") then
			-- the slope: from (top, back) to (bottom, front) across X
			local n = (cf.UpVector * s.Z + cf.LookVector * s.Y).Unit
			local origin = cf.Position
			local u = cf.RightVector
			local v = n:Cross(u).Unit
			probe(p, origin, n, u, v, s.X, math.sqrt(s.Y * s.Y + s.Z * s.Z))
			nChecked += 1
		elseif not isAxis(cf) and p.ClassName == "Part" then
			for _, f in
				{
					{ cf.RightVector, s.X, cf.UpVector, s.Y, cf.LookVector, s.Z },
					{ cf.UpVector, s.Y, cf.RightVector, s.X, cf.LookVector, s.Z },
					{ cf.LookVector, s.Z, cf.RightVector, s.X, cf.UpVector, s.Y },
				}
			do
				for _, sg in { -1, 1 } do
					local n = f[1] * sg
					probe(p, cf.Position + n * f[2] / 2, n, f[3], f[5], f[4], f[6])
				end
			end
			nChecked += 1
		end
		if k % 300 == 0 then
			task.wait()
		end
	end
	for d, q in saved do
		d.CanQuery = q
	end
	local lines = {}
	local total = 0
	for key, c in found do
		total += c
		table.insert(lines, string.format("  %3d  %s  e.g. %s", c, key, examples[key]))
	end
	table.sort(lines)
	table.insert(
		lines,
		1,
		string.format(
			"%s: %d slopes / rotated parts checked, %d coincident surfaces",
			mapName,
			nChecked,
			total
		)
	)
	return table.concat(lines, "\n")
end
