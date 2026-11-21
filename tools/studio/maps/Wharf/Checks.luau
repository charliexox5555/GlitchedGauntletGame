--!strict
-- Wharf reach + clearance check on the real collision (2026-11-20; vault/01 Design/Maps/Wharf.md → Checks).
-- Match place, edit mode. Returns a function; run it as require(<clone>)("Wharf").
--
-- 1. Surfaces: on a 1-stud grid over the play box, rays down (collidable parts only, the bounds ignored) find up
--    to 4 stacked standable surfaces per column (5.5 studs of headroom above each).
-- 2. Clearance: a surface cell is walkable if a 2 x 4.6 x 2 box (an R15 body) fits above it.
-- 3. Moves (Jump Audit 2026-11-13): walk to a neighbour with a rise <= 1.3 (steps), any drop; jump up to a
--    surface within 2 cells with a rise <= 7.0 (sprint ledge 7.5, 0.5 kept as margin), or across up to 8 cells
--    (gap 9 at sprint, 1 kept) at a rise <= 1.
-- 4. Flood from team A's spawns (and B's, for the balance): what's reached, at which heights; the walking
--    distance from each team's spawn centre to the map centre and to the enemy spawn.

return function(mapName: string): string
	local map = workspace:FindFirstChild(mapName)
	assert(map and map:IsA("Model"), "no map " .. mapName)
	local O = map:GetPivot()
	local X0, X1, Z0, Z1 = -64, 64, -92, 92
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.RespectCanCollide = true
	local excl: { Instance } = {}
	local bounds = map:FindFirstChild("Bounds")
	if bounds then
		table.insert(excl, bounds)
	end
	rp.FilterDescendantsInstances = excl
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.RespectCanCollide = true
	op.FilterDescendantsInstances = excl

	-- CanQuery is off on visuals; collision parts have it on. Rays and overlaps see only CanQuery parts, and
	-- solid visuals (floors, steps, roofs) have CanQuery on too.
	type Cell = { x: number, z: number, y: number, id: number }
	local cells: { Cell } = {}
	local byCol: { [number]: { Cell } } = {}
	local function key(x: number, z: number): number
		return (x - X0) * 1000 + (z - Z0)
	end
	for x = X0, X1 do
		for z = Z0, Z1 do
			local top = 40
			for _ = 1, 4 do
				local r = workspace:Raycast(
					(O * CFrame.new(x, top, z)).Position,
					Vector3.new(0, -(top + 12), 0),
					rp
				)
				if not r or r.Normal.Y < 0.6 then
					break
				end
				local y = O:PointToObjectSpace(r.Position).Y
				local head = workspace:Raycast(
					r.Position + Vector3.new(0, 0.05, 0),
					Vector3.new(0, 5.5, 0),
					rp
				)
				if not head then
					local fits = #workspace:GetPartBoundsInBox(
						O * CFrame.new(x, y + 2.45, z),
						Vector3.new(1.9, 4.6, 1.9),
						op
					) == 0
					if fits then
						local c = { x = x, z = z, y = y, id = #cells + 1 }
						table.insert(cells, c)
						local k = key(x, z)
						byCol[k] = byCol[k] or {}
						table.insert(byCol[k], c)
					end
				end
				top = y - 0.2
				if top < -8 then
					break
				end
			end
		end
		if x % 16 == 0 then
			task.wait()
		end
	end

	local function neighbours(c: Cell, out: { { any } })
		table.clear(out)
		for dx = -8, 8 do
			for dz = -8, 8 do
				local d = math.sqrt(dx * dx + dz * dz)
				if d > 0 and d <= 8.5 then
					local col = byCol[key(c.x + dx, c.z + dz)]
					if col then
						for _, n in col do
							local rise = n.y - c.y
							local ok = false
							if d <= 1.5 then
								ok = rise <= 1.3
							elseif d <= 2.9 then
								ok = rise <= 7.0
							else
								ok = rise <= 1.0 and rise >= -12
							end
							if ok then
								table.insert(out, { n, d })
							end
						end
					end
				end
			end
		end
	end

	local function flood(starts: { Vector3 }): { [number]: number }
		local dist: { [number]: number } = {}
		local q: { Cell } = {}
		for _, s in starts do
			local col = byCol[key(math.floor(s.X + 0.5), math.floor(s.Z + 0.5))]
			if col then
				for _, c in col do
					if math.abs(c.y - s.Y) < 1.5 then
						dist[c.id] = 0
						table.insert(q, c)
					end
				end
			end
		end
		local head = 1
		local nb = {}
		while head <= #q do
			local c = q[head]
			head += 1
			neighbours(c, nb)
			for _, e in nb do
				local n: Cell, d: number = e[1], e[2]
				local nd = dist[c.id] + d
				if not dist[n.id] or nd < dist[n.id] - 0.01 then
					dist[n.id] = nd
					table.insert(q, n)
				end
			end
			if head % 4000 == 0 then
				task.wait()
			end
		end
		return dist
	end

	local spawnsA, spawnsB = {}, {}
	for _, s in map.Spawns:GetChildren() do
		if s:IsA("BasePart") then
			local p = O:PointToObjectSpace(s.Position)
			table.insert(
				if s:HasTag("ArenaSpawn_A") then spawnsA else spawnsB,
				Vector3.new(p.X, 0, p.Z)
			)
		end
	end
	local dA = flood(spawnsA)
	local dB = flood(spawnsB)

	-- report: surfaces by height band, reached or not
	local bands: { [string]: { total: number, reached: number, eg: string } } = {}
	local function band(y: number): string
		return string.format("%+.1f", math.floor(y * 2 + 0.5) / 2)
	end
	for _, c in cells do
		local b = band(c.y)
		local e = bands[b] or { total = 0, reached = 0, eg = "" }
		bands[b] = e
		e.total += 1
		if dA[c.id] then
			e.reached += 1
		elseif e.eg == "" then
			e.eg = string.format(" e.g. unreached (%d,%d)", c.x, c.z)
		end
	end
	local lines =
		{ string.format("%s: %d standable cells (2 x 4.6 x 2 clearance)", mapName, #cells) }
	local keys = {}
	for k in bands do
		table.insert(keys, k)
	end
	table.sort(keys, function(a, b)
		return (tonumber(a) :: number) < (tonumber(b) :: number)
	end)
	for _, k in keys do
		local e = bands[k]
		table.insert(
			lines,
			string.format("  height %s: %d cells, %d reached from A%s", k, e.total, e.reached, e.eg)
		)
	end
	local function at(d: { [number]: number }, x: number, z: number, y: number): number?
		local col = byCol[key(x, z)]
		if col then
			for _, c in col do
				if math.abs(c.y - y) < 1 then
					return d[c.id]
				end
			end
		end
		return nil
	end
	local function fmt(v: number?): string
		return if v then string.format("%.0f studs (%.1f s sprint)", v, v / 20.9) else "UNREACHED"
	end
	table.insert(
		lines,
		"  A -> centre (0,-14): "
			.. fmt(at(dA, 0, -14, 0))
			.. "   B -> centre (0,14): "
			.. fmt(at(dB, 0, 14, 0))
	)
	table.insert(
		lines,
		"  A -> B spawn: "
			.. fmt(at(dA, -3, -78, 0))
			.. "   B -> A spawn: "
			.. fmt(at(dB, 3, 78, 0))
	)
	table.insert(
		lines,
		"  A -> own office deck (-52,82,+12): "
			.. fmt(at(dA, -52, 82, 12))
			.. "   B -> own office deck: "
			.. fmt(at(dB, 52, -82, 12))
	)
	table.insert(
		lines,
		"  A -> enemy office deck: "
			.. fmt(at(dA, 52, -82, 12))
			.. "   A -> landing pit floor: "
			.. fmt(at(dA, 60, -3, -3))
	)
	return table.concat(lines, "\n")
end
