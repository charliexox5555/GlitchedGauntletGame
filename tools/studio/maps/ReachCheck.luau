--!strict
-- Map reach + clearance check on the real collision (generalised from Wharf/Checks.luau, 2026-11-20;
-- vault/01 Design/Maps/Metro4.md). Match place, edit mode. Run: require(<clone>)(mapName, opts) with
--   opts = { bounds = { x0, x1, z0, z1 }, points = { { label, "A" | "B", x, z, y } } } (map space).
-- Surfaces from rays down (collidable parts, bounds ignored), a 1.9 x 4.6 x 1.9 body box from 0.6 up (so stairs
-- up to ~35 degrees pass) for clearance, moves:
-- walk rise <= 1.3, jump rise <= 7.0 within 2 cells, gaps <= 8 at rise <= 1 (Jump Audit 2026-11-13).

type Opts = { bounds: { number }, points: { { any } } }

return function(mapName: string, opts: Opts): string
	local map = workspace:FindFirstChild(mapName)
	assert(map and map:IsA("Model"), "no map " .. mapName)
	local O = map:GetPivot()
	local X0, X1, Z0, Z1 = opts.bounds[1], opts.bounds[2], opts.bounds[3], opts.bounds[4]
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
	local flipped: { BasePart } = {}
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") and d.CanCollide and not d.CanQuery then
			d.CanQuery = true
			table.insert(flipped, d)
		end
	end
	local probe = Instance.new("Part")
	probe.Name = "_ReachProbe"
	probe.Anchored = true
	probe.CanCollide = false
	probe.CanQuery = false
	probe.CanTouch = false
	probe.Transparency = 1
	probe.Size = Vector3.new(1.9, 4.6, 1.9)
	probe.Parent = workspace
	table.insert(excl, probe)
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
					-- true geometry (GetPartBoundsInBox would test a wedge's whole bounding box)
					probe.CFrame = O * CFrame.new(x, y + 2.9, z)
					local fits = #workspace:GetPartsInPart(probe, op) == 0
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
							-- a jump (more than a step) must have a clear path: a ray from the higher of the two
							-- surfaces' head height (walls, parapets and glass block it)
							if ok and d > 1.5 and math.abs(rise) > 0.3 then
								local hy = math.max(c.y, n.y) + 2.2
								local from = (O * CFrame.new(c.x, hy, c.z)).Position
								local to = (O * CFrame.new(n.x, hy, n.z)).Position
								if workspace:Raycast(from, to - from, rp) then
									ok = false
								end
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
	-- reached cells by height band, binned to 10 studs (to find what is reached), for the bands in opts.bins
	for _, want in (opts :: any).bins or {} do
		local bins: { [string]: number } = {}
		for _, c in cells do
			if math.abs(c.y - want) < 0.6 and dA[c.id] then
				local k2 =
					string.format("(%d,%d)", math.floor(c.x / 10) * 10, math.floor(c.z / 10) * 10)
				bins[k2] = (bins[k2] or 0) + 1
			end
		end
		local bl = {}
		for k2, n in bins do
			table.insert(bl, k2 .. "x" .. n)
		end
		table.sort(bl)
		table.insert(lines, string.format("  reached at %+.1f: %s", want, table.concat(bl, " ")))
	end
	for _, pt in opts.points do
		local d = if pt[2] == "A" then dA else dB
		table.insert(
			lines,
			string.format("  %s -> %s: %s", pt[2], pt[1], fmt(at(d, pt[3], pt[4], pt[5])))
		)
	end
	return table.concat(lines, "\n")
end
