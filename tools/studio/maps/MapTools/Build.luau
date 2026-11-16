--!strict
-- Shared map builder (maps overnight run 2026-11-16; vault/01 Design/Maps/Overnight Run 2026-11-16.md).
-- Installed as ServerStorage.MapTools.Build (a ModuleScript) in the match place; returns build(data).
-- Data comes from tools/maps/map_plans.py (`python tools/maps/map_plans.py --luau <id>`).
--
-- Map contract (MapService / Config/Match): Workspace.<id> with
--   Greybox.<Section>  collision Parts (kit meshes replace their look; the part stays, invisible)
--   Art                kit meshes and props (no collision)
--   Spawns             SpawnLocations tagged ArenaSpawn_A / ArenaSpawn_B (ghost hold, no gates)
--   Barriers           empty
--   Lighting / LightingFx / attribute KillDepth
-- Rows: { name, kind, x, z, sx, sz, h, yaw, base, look, piece, extra }. Rows after `center` are mirrored
-- by a 180-degree turn. Kinds: full, baffle, low, pillar, deck, plinth, ramp, bridge, void, decor, glass.
--   ramp: rises toward extra.rise ("+z", "-z", "+x", "-x"; mirrored with the row)
--   bridge: walkable slab, top at h, extra.thick (default 1)
--   void: no deck there (the floor is cut round it); nothing else is built
--   decor: no collision, no queries
--   extra.raise: build the top this much higher (legs that must stand proud of a beam)
--   piece: a kit model in ServerStorage.MapKit.<kit>; placed at (x, base, z) turned by yaw + extra.pieceYaw,
--          and the part is hidden (kept as collision)

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

type Rect = { number } -- x0, z0, x1, z1

local FACES = { Enum.NormalId.Top, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }

local function subtract(rects: { Rect }, hole: Rect): { Rect }
	local out: { Rect } = {}
	for _, r in rects do
		local x0, z0, x1, z1 = r[1], r[2], r[3], r[4]
		local hx0, hz0, hx1, hz1 = math.max(hole[1], x0), math.max(hole[2], z0), math.min(hole[3], x1), math.min(hole[4], z1)
		if hx0 >= hx1 or hz0 >= hz1 then
			table.insert(out, r)
			continue
		end
		if z0 < hz0 then
			table.insert(out, { x0, z0, x1, hz0 })
		end
		if hz1 < z1 then
			table.insert(out, { x0, hz1, x1, z1 })
		end
		if x0 < hx0 then
			table.insert(out, { x0, hz0, hx0, hz1 })
		end
		if hx1 < x1 then
			table.insert(out, { hx1, hz0, x1, hz1 })
		end
	end
	return out
end

return function(D: any): string
	assert(game.PlaceId == 133387545285290, "MapTools: not the match place")
	local origin = CFrame.new(D.origin[1], D.origin[2], D.origin[3])
	local old = workspace:FindFirstChild(D.id)
	if old then
		old:Destroy()
	end
	local map = Instance.new("Model")
	map.Name = D.id
	map.WorldPivot = origin
	map:SetAttribute("KillDepth", D.killDepth or 30)
	map:SetAttribute("LayoutVersion", D.version or "v1")
	local function folder(parent: Instance, name: string): Folder
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
		return f
	end
	local greybox = folder(map, "Greybox")
	local art = folder(map, "Art")
	local spawns = folder(map, "Spawns")
	folder(map, "Barriers")
	local secs: { [string]: Folder } = {}
	local function sec(n: string): Folder
		secs[n] = secs[n] or folder(greybox, n)
		return secs[n]
	end

	local textures = D.textures or {}
	local looks = D.looks or {}
	local function dress(p: BasePart, lookKey: string?)
		local look = looks[lookKey or "default"] or looks.default or { color = "9EA2AA" }
		p.Color = Color3.fromHex(look.color)
		p.Material = (Enum.Material :: any)[look.mat or "SmoothPlastic"]
		if look.transparency then
			p.Transparency = look.transparency
		end
		local t = look.tex and textures[look.tex]
		if t then
			for _, f in (if look.topOnly then { Enum.NormalId.Top } else FACES) do
				local tx = Instance.new("Texture")
				tx.Name = "Tile"
				tx.Texture = t.id
				tx.Face = f
				tx.StudsPerTileU = t.tile or 5
				tx.StudsPerTileV = t.tile or 5
				tx.Color3 = Color3.fromHex(t.color or "000000")
				tx.Transparency = t.transparency or 0.75
				tx.Parent = p
			end
		end
	end
	local function part(class: string, parent: Instance, name: string, size: Vector3, cf: CFrame, lookKey: string?): BasePart
		local p = Instance.new(class) :: BasePart
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = origin * cf
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		dress(p, lookKey)
		p.Parent = parent
		return p
	end
	local function hide(p: BasePart)
		p.Transparency = 1
		p.CastShadow = false
		for _, t in p:GetChildren() do
			if t:IsA("Texture") then
				t:Destroy()
			end
		end
	end
	local kitLib = D.kit and ServerStorage:FindFirstChild("MapKit") and ServerStorage.MapKit:FindFirstChild(D.kit)
	local placed, missing = 0, {}
	local function putPiece(piece: string, cf: CFrame, name: string?, parent: Instance?): Model?
		local src = kitLib and kitLib:FindFirstChild(piece)
		if not src then
			missing[piece] = true
			return nil
		end
		local m = src:Clone()
		m.Name = name or piece
		m:PivotTo(origin * cf)
		m.Parent = parent or art
		placed += 1
		return m
	end

	-- rows (mirrored after `center`)
	local rows = {}
	for _, r in D.rows do
		table.insert(rows, r)
	end
	for i = (D.center or 0) + 1, #D.rows do
		local r = D.rows[i]
		local e = r[12]
		local m = table.clone(r)
		m[1] = r[1] .. "'"
		m[3], m[4] = -r[3], -r[4]
		if e and e.rise then
			local flip = { ["+z"] = "-z", ["-z"] = "+z", ["+x"] = "-x", ["-x"] = "+x" }
			m[12] = table.clone(e)
			m[12].rise = flip[e.rise]
		end
		m[13] = true -- mirrored
		table.insert(rows, m)
	end

	-- deck: the deck rect cut round every void
	local hx, hz = D.hx, D.hz
	local floor: { Rect } = { { -hx, -hz, hx, hz } }
	for _, r in rows do
		if r[2] == "void" then
			floor = subtract(floor, { r[3] - r[5] / 2, r[4] - r[6] / 2, r[3] + r[5] / 2, r[4] + r[6] / 2 })
		end
	end
	for i, f in floor do
		part("Part", sec("Floor"), "Deck" .. i, Vector3.new(f[3] - f[1], 4, f[4] - f[2]), CFrame.new((f[1] + f[3]) / 2, -2, (f[2] + f[4]) / 2), "deck")
	end
	if D.apron then -- ground round the map (past the bounds, never reachable) so scenery beyond the edge stands on something
		local w = D.apron.w
		for i, a in {
			{ Vector3.new(w, 4, 2 * hz + 2 * w), CFrame.new(hx + w / 2, -2, 0) },
			{ Vector3.new(w, 4, 2 * hz + 2 * w), CFrame.new(-hx - w / 2, -2, 0) },
			{ Vector3.new(2 * hx, 4, w), CFrame.new(0, -2, hz + w / 2) },
			{ Vector3.new(2 * hx, 4, w), CFrame.new(0, -2, -hz - w / 2) },
		} do
			local p = part("Part", sec("Apron"), "Apron" .. i, a[1], a[2], D.apron.look or "deck")
			p.CanQuery = false
		end
	end
	if D.water then
		local w = part("Part", sec("Water"), "Water", Vector3.new(2 * hx + 400, 2, 2 * hz + 400), CFrame.new(0, D.waterY or -6, 0), "water")
		w.CanCollide = false
		w.CanQuery = false
		w.CastShadow = false
	end
	if D.under then -- a ground far below (alleys, pits): something to see, deadly by KillDepth
		local g = part("Part", sec("Under"), "Under", Vector3.new(2 * hx, 2, 2 * hz), CFrame.new(0, D.under.y, 0), D.under.look)
		g.CanCollide = false
		g.CanQuery = false
	end
	-- bounds, and a roof for indoor maps (cut round its openings)
	local ceil = D.ceiling
	for _, b in {
		{ Vector3.new(2, ceil, 2 * hz + 4), CFrame.new(hx + 1, ceil / 2, 0) },
		{ Vector3.new(2, ceil, 2 * hz + 4), CFrame.new(-hx - 1, ceil / 2, 0) },
		{ Vector3.new(2 * hx, ceil, 2), CFrame.new(0, ceil / 2, hz + 1) },
		{ Vector3.new(2 * hx, ceil, 2), CFrame.new(0, ceil / 2, -hz - 1) },
		{ Vector3.new(2 * hx + 4, 2, 2 * hz + 4), CFrame.new(0, ceil + 1, 0) },
	} do
		local p = part("Part", sec("Bounds"), "Bound", b[1], b[2], "default")
		hide(p)
		p.CanQuery = false
	end
	if D.roof then
		local tiles: { Rect } = { { -hx, -hz, hx, hz } }
		for _, h in D.roof.holes or {} do
			tiles = subtract(tiles, { h[1] - h[3] / 2, h[2] - h[4] / 2, h[1] + h[3] / 2, h[2] + h[4] / 2 })
			if h[5] then -- mirrored hole
				tiles = subtract(tiles, { -h[1] - h[3] / 2, -h[2] - h[4] / 2, -h[1] + h[3] / 2, -h[2] + h[4] / 2 })
			end
		end
		for i, f in tiles do
			part("Part", sec("Roof"), "Roof" .. i, Vector3.new(f[3] - f[1], 2, f[4] - f[2]), CFrame.new((f[1] + f[3]) / 2, D.roof.h + 1, (f[2] + f[4]) / 2), "roof")
		end
	end
	-- an indoor map is closed: visible outer walls just outside the bounds, floor to roof top. D.walls
	-- ({h, look}) closes a map without a roof the same way (Greenhouse glass)
	if D.roof or D.walls then
		local wh = if D.walls then D.walls.h else D.roof.h + 2
		local wl = (D.walls and D.walls.look) or (D.roof and D.roof.wallLook) or "cover"
		for i, w in {
			{ Vector3.new(4, wh + 12, 2 * hz + 8), CFrame.new(hx + 2, wh / 2 - 6, 0) },
			{ Vector3.new(4, wh + 12, 2 * hz + 8), CFrame.new(-hx - 2, wh / 2 - 6, 0) },
			{ Vector3.new(2 * hx, wh + 12, 4), CFrame.new(0, wh / 2 - 6, hz + 2) },
			{ Vector3.new(2 * hx, wh + 12, 4), CFrame.new(0, wh / 2 - 6, -hz - 2) },
		} do
			local p = part("Part", sec("Walls"), "OuterWall" .. i, w[1], w[2], wl)
			p.CanQuery = false
		end
	end

	-- pieces
	local decks = {}
	for _, r in rows do
		if r[2] == "deck" or r[2] == "plinth" then
			table.insert(decks, r)
		end
	end
	local DIR = { ["+z"] = Vector3.new(0, 0, 1), ["-z"] = Vector3.new(0, 0, -1), ["+x"] = Vector3.new(1, 0, 0), ["-x"] = Vector3.new(-1, 0, 0) }
	for _, r in rows do
		local name, kind, x, z, sx, sz, h, yaw, base, look, piece, e = r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10], r[11], r[12] or {}
		if kind == "void" then
			continue
		end
		local s = e.section or (if kind == "ramp" then "Ramps" elseif kind == "deck" or kind == "plinth" or kind == "bridge" then "Heights" elseif kind == "low" then "LowCover" elseif kind == "decor" then "Decor" else "Cover")
		local p: BasePart
		if kind == "ramp" then
			local dir = DIR[e.rise or "+z"]
			local alongZ = dir.Z ~= 0
			local width, length = if alongZ then sx else sz, if alongZ then sz else sx
			local pos = Vector3.new(x, base + (h - base) / 2, z)
			p = part("WedgePart", sec(s), name, Vector3.new(width, h - base, length), CFrame.lookAt(pos, pos - dir), look)
		else
			local top = h + (e.raise or 0)
			local bottom = if kind == "bridge" then h - (e.thick or 1) else base
			p = part("Part", sec(s), name, Vector3.new(sx, top - bottom, sz), CFrame.new(x, bottom + (top - bottom) / 2, z) * CFrame.Angles(0, math.rad(-yaw), 0), look)
		end
		p:SetAttribute("Kind", kind)
		if kind == "decor" then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
		if piece and piece ~= "" then
			local ry = math.rad(-yaw) + math.rad(e.pieceYaw or 0) + (if r[13] then math.pi else 0)
			local m = putPiece(piece, CFrame.new(x, if kind == "bridge" then h - (e.thick or 1) else base, z) * CFrame.Angles(0, ry, 0), name)
			if m and not e.keepPart then
				hide(p)
				if kind == "decor" then
					p:Destroy()
				end
			end
		end
	end

	-- free props: { piece, x, z, y, yaw, mirror }
	for _, pr in D.props or {} do
		putPiece(pr[1], CFrame.new(pr[2], pr[4] or 0, pr[3]) * CFrame.Angles(0, math.rad(pr[5] or 0), 0), pr[1])
		if pr[6] then
			putPiece(pr[1], CFrame.new(-pr[2], pr[4] or 0, -pr[3]) * CFrame.Angles(0, math.rad((pr[5] or 0) + 180), 0), pr[1])
		end
	end

	-- spawns (ghost hold: open markers, no gates)
	for team, sign in { A = 1, B = -1 } do
		for i, sp in D.spawns do
			local s = Instance.new("SpawnLocation")
			s.Name = string.format("Spawn_%s%d", team, i)
			s.Anchored = true
			s.Size = Vector3.new(4, 0.2, 4)
			s.CFrame = origin * CFrame.new(sp[1] * sign, (sp[3] or 0) + 0.1, sp[2] * sign) * CFrame.Angles(0, if team == "A" then 0 else math.pi, 0)
			s.Transparency = 1
			s.CanCollide = false
			s.CanQuery = false
			s.CanTouch = false
			s.Neutral = true
			s.Duration = 0
			s.Enabled = false
			s.Parent = spawns
			CollectionService:AddTag(s, "ArenaSpawn_" .. team)
		end
	end

	-- lighting profile
	local L = Instance.new("Configuration")
	L.Name = "Lighting"
	for k, v in D.lighting or {} do
		if typeof(v) == "string" then
			L:SetAttribute(k, Color3.fromHex(v))
		else
			L:SetAttribute(k, v)
		end
	end
	L.Parent = map
	local fx = folder(map, "LightingFx")
	local A = D.atmosphere or {}
	local atm = Instance.new("Atmosphere")
	atm.Density = A.density or 0.28
	atm.Offset = A.offset or 0.1
	atm.Color = Color3.fromHex(A.color or "D6DEE8")
	atm.Decay = Color3.fromHex(A.decay or "96A4BA")
	atm.Glare = A.glare or 0
	atm.Haze = A.haze or 1.1
	atm.Parent = fx

	map.Parent = workspace
	local c = 0
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") then
			c += 1
		end
	end
	local miss = {}
	for k in missing do
		table.insert(miss, k)
	end
	return string.format("%s: %d parts, %d kit pieces%s", D.id, c, placed, if #miss > 0 then " (kit missing: " .. table.concat(miss, ", ") .. ")" else "")
end
