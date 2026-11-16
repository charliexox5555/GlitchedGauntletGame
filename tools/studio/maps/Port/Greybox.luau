--!strict
-- Pier + Dockyard greybox (map redesign batch 2, 2026-11-16). Layout data from tools/maps/port_layout.py
-- (rows: name, kind, x, z, sx, sz, h, yaw, base; the first `center` rows are not mirrored, the rest are
-- mirrored by a 180-degree turn). Run in the match place, edit mode (Studio MCP execute_luau or the Command
-- Bar). Builds Workspace.Pier at (4800, 200, 0) and Workspace.Dockyard at (4800, 200, -600).
-- Map contract: Greybox / Spawns (ArenaSpawn_A/B) / Barriers (empty: ghost hold) / Lighting / LightingFx /
-- KillDepth. Plain parts with the grid tile; the Blender kit (tools/blender/maps_port) replaces the look later.

local CollectionService = game:GetService("CollectionService")

assert(game.PlaceId == 133387545285290, "Port greybox: not the match place")

local IMG = "rbxassetid://99198970022758" -- our grid tile (vault/01 Design/Maps/Arena.md)
local COL = {
	floor = Color3.fromRGB(151, 153, 163),
	container = Color3.fromRGB(116, 124, 138),
	crate = Color3.fromRGB(176, 158, 128),
	wall = Color3.fromRGB(140, 142, 150),
	roof = Color3.fromRGB(118, 120, 128),
	gantry = Color3.fromRGB(132, 134, 143),
	ramp = Color3.fromRGB(165, 167, 176),
	water = Color3.fromRGB(72, 108, 136),
}

local FACES = { Enum.NormalId.Top, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }

local function tex(p: BasePart)
	for _, f in FACES do
		local t = Instance.new("Texture")
		t.Name = "Grid"
		t.Texture = IMG
		t.Face = f
		t.StudsPerTileU = 5
		t.StudsPerTileV = 5
		t.Color3 = Color3.new(0, 0, 0)
		t.Transparency = 0.75
		t.Parent = p
	end
end

type Row = { any }
type Data = {
	id: string,
	origin: { number },
	hx: number,
	hz: number,
	ceiling: number,
	clock: number,
	center: number,
	rows: { Row },
	spawns: { { number } },
}

local function build(D: Data): string
	local origin = CFrame.new(D.origin[1], D.origin[2], D.origin[3])
	local old = workspace:FindFirstChild(D.id)
	if old then
		old:Destroy()
	end
	local map = Instance.new("Model")
	map.Name = D.id
	map.WorldPivot = origin
	map:SetAttribute("KillDepth", 30)
	map:SetAttribute("LayoutVersion", "greybox v1 2026-11-16")
	local function folder(parent: Instance, name: string): Folder
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
		return f
	end
	local greybox = folder(map, "Greybox")
	local spawns = folder(map, "Spawns")
	folder(map, "Barriers")
	local secs: { [string]: Folder } = {}
	local function sec(n: string): Folder
		secs[n] = secs[n] or folder(greybox, n)
		return secs[n]
	end
	local function part(class: string, parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, textured: boolean?): BasePart
		local p = Instance.new(class) :: BasePart
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = origin * cf
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = parent
		if textured ~= false then
			tex(p)
		end
		return p
	end
	local hx, hz = D.hx, D.hz
	-- deck (top 0), water 4 below, bounds at the deck edge
	part("Part", sec("Floor"), "Deck", Vector3.new(2 * hx, 4, 2 * hz), CFrame.new(0, -2, 0), COL.floor)
	local water = part("Part", sec("Water"), "Water", Vector3.new(2 * hx + 400, 2, 2 * hz + 400), CFrame.new(0, -6, 0), COL.water, false)
	water.CanCollide = false
	water.CanQuery = false
	water.CastShadow = false
	for _, b in {
		{ Vector3.new(2, D.ceiling, 2 * hz + 4), CFrame.new(hx + 1, D.ceiling / 2, 0) },
		{ Vector3.new(2, D.ceiling, 2 * hz + 4), CFrame.new(-hx - 1, D.ceiling / 2, 0) },
		{ Vector3.new(2 * hx, D.ceiling, 2), CFrame.new(0, D.ceiling / 2, hz + 1) },
		{ Vector3.new(2 * hx, D.ceiling, 2), CFrame.new(0, D.ceiling / 2, -hz - 1) },
		{ Vector3.new(2 * hx + 4, 2, 2 * hz + 4), CFrame.new(0, D.ceiling + 1, 0) },
	} do
		local p = part("Part", sec("Bounds"), "Bound", b[1], b[2], COL.floor, false)
		p.Transparency = 1
		p.CastShadow = false
		p.CanQuery = false
	end
	local rows: { Row } = {}
	for _, r in D.rows do
		table.insert(rows, r)
	end
	for i = D.center + 1, #D.rows do
		local r = D.rows[i]
		table.insert(rows, { r[1] .. "'", r[2], -r[3], -r[4], r[5], r[6], r[7], r[8], r[9] })
	end
	local decks: { Row } = {}
	for _, r in rows do
		if r[2] == "deck" or r[2] == "plinth" then
			table.insert(decks, r)
		end
	end
	-- a deck marker on the same footprint as a container is the container's top: don't build it twice
	local function dup(r: Row): boolean
		for _, q in rows do
			if q ~= r and q[2] == "full" and q[3] == r[3] and q[4] == r[4] and q[5] == r[5] and q[6] == r[6] and q[7] == r[7] then
				return true
			end
		end
		return false
	end
	for _, r in rows do
		local name, kind, x, z, sx, sz, h, yaw, base = r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9]
		if kind == "deck" and dup(r) then
			continue
		end
		local color, s = COL.container, "Containers"
		if string.find(name, "Gantry") and not string.find(name, "crate") then
			color, s = COL.gantry, "Gantry"
		elseif string.find(name, "Warehouse wall") then
			color, s = COL.wall, "Warehouse"
		elseif string.find(name, "Warehouse roof") or string.find(name, "Roof landing") then
			color, s = COL.roof, "Warehouse"
		elseif string.find(name, "rate") or string.find(name, "step") or kind == "low" or kind == "plinth" then
			color, s = COL.crate, "Crates"
		end
		if kind == "ramp" then
			local best: Row? = nil
			local bd = math.huge
			for _, d in decks do
				if math.abs(d[7] - h) < 0.1 and d[1] ~= "Warehouse roof" then
					local dd = (d[3] - x) ^ 2 + (d[4] - z) ^ 2
					if dd < bd then
						best, bd = d, dd
					end
				end
			end
			assert(best, "ramp without a landing: " .. name)
			local vx, vz = best[3] - x, best[4] - z
			local dir = if math.abs(vz) >= math.abs(vx) then Vector3.new(0, 0, math.sign(vz)) else Vector3.new(math.sign(vx), 0, 0)
			local pos = Vector3.new(x, h / 2, z)
			-- WedgePart: low at local -Z, high at +Z (faces the landing)
			part("WedgePart", sec("Warehouse"), name, Vector3.new(sx, h, sz), CFrame.lookAt(pos, pos - dir), COL.ramp)
		else
			local top = if string.find(name, "Gantry leg") then h + 1 else h -- legs stand proud of the beam (no shared top)
			local p = part(
				"Part",
				sec(s),
				name,
				Vector3.new(sx, top - base, sz),
				CFrame.new(x, base + (top - base) / 2, z) * CFrame.Angles(0, math.rad(-yaw), 0),
				color
			)
			p:SetAttribute("Kind", kind)
		end
	end
	for team, sign in { A = 1, B = -1 } do
		for i, s in D.spawns do
			local sp = Instance.new("SpawnLocation")
			sp.Name = string.format("Spawn_%s%d", team, i)
			sp.Anchored = true
			sp.Size = Vector3.new(4, 0.2, 4)
			sp.CFrame = origin * CFrame.new(s[1] * sign, 0.1, s[2] * sign) * CFrame.Angles(0, if team == "A" then 0 else math.pi, 0)
			sp.Transparency = 1
			sp.CanCollide = false
			sp.CanQuery = false
			sp.CanTouch = false
			sp.Neutral = true
			sp.Duration = 0
			sp.Enabled = false
			sp.Parent = spawns
			CollectionService:AddTag(sp, "ArenaSpawn_" .. team)
		end
	end
	local light = Instance.new("Configuration")
	light.Name = "Lighting"
	light:SetAttribute("ClockTime", D.clock)
	light:SetAttribute("Brightness", 3)
	light:SetAttribute("ExposureCompensation", 0.1)
	light:SetAttribute("Ambient", Color3.fromRGB(128, 132, 142))
	light:SetAttribute("OutdoorAmbient", Color3.fromRGB(168, 174, 188))
	light.Parent = map
	local fx = folder(map, "LightingFx")
	local atm = Instance.new("Atmosphere")
	atm.Density = 0.3
	atm.Offset = 0.1
	atm.Color = Color3.fromRGB(214, 222, 232)
	atm.Decay = Color3.fromRGB(150, 164, 186)
	atm.Haze = 1.2
	atm.Parent = fx
	map.Parent = workspace
	local c = 0
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") then
			c += 1
		end
	end
	return D.id .. " " .. c .. " parts"
end

-- Rows printed by tools/maps/port_layout.py (keep in step with it).
local pier = build({
	id = "Pier",
	origin = { 4800, 200, 0 },
	hx = 45,
	hz = 75,
	ceiling = 60,
	clock = 13.5,
	center = 4,
	rows = {
		{ "Mid container", "full", 0, 0, 10, 20, 10, 0, 0 },
		{ "Gantry leg", "pillar", -42.5, 0, 5, 10, 30, 0, 0 },
		{ "Gantry leg", "pillar", 42.5, 0, 5, 10, 30, 0, 0 },
		{ "Gantry beam", "full", 0, 0, 85, 5, 30, 0, 25 },
		{ "Spawn container", "full", 0, 55, 30, 10, 10, 0, 0 },
		{ "Flank container", "full", -37.5, 55, 15, 10, 10, 0, 0 },
		{ "Row container", "full", -25, 25, 10, 30, 10, 0, 0 },
		{ "Crate stack", "full", -17.5, 17.5, 5, 5, 10, 0, 0 },
		{ "Perch deck", "deck", 30, 32.5, 10, 25, 10, 0, 0 },
		{ "Step crate high", "deck", 22.5, 22.5, 5, 5, 7, 0, 0 },
		{ "Step crate low", "plinth", 17.5, 22.5, 5, 5, 3.5, 0, 0 },
		{ "Back step high", "deck", 30, 47.5, 5, 5, 7, 0, 0 },
		{ "Back step low", "plinth", 30, 52.5, 5, 5, 3.5, 0, 0 },
		{ "Cross container", "full", 0, 35, 20, 10, 10, 0, 0 },
		{ "Edge crates", "low", -42.5, 20, 5, 10, 3.5, 0, 0 },
	},
	spawns = { { -5, 70 }, { 5, 70 }, { -5, 65 }, { 5, 65 } },
})
local dockyard = build({
	id = "Dockyard",
	origin = { 4800, 200, -600 },
	hx = 100,
	hz = 115,
	ceiling = 80,
	clock = 17.2,
	center = 4,
	rows = {
		{ "Mid container", "full", 0, 0, 10, 30, 10, 0, 0 },
		{ "Gantry leg", "pillar", -60, 0, 5, 10, 34, 0, 0 },
		{ "Gantry leg", "pillar", 60, 0, 5, 10, 34, 0, 0 },
		{ "Gantry beam", "full", 0, 0, 120, 5, 34, 0, 29 },
		{ "Spawn container", "full", 0, 85, 30, 10, 10, 0, 0 },
		{ "Spawn flank", "full", -40, 92.5, 20, 10, 10, 0, 0 },
		{ "Warehouse wall N1", "full", -92.5, 77.5, 15, 5, 11.8, 0, 0 },
		{ "Warehouse wall N2", "full", -67.5, 77.5, 15, 5, 11.8, 0, 0 },
		{ "Warehouse wall S", "full", -80, 42.5, 40, 5, 11.8, 0, 0 },
		{ "Warehouse wall E1", "full", -62.5, 50, 5, 10, 11.8, 0, 0 },
		{ "Warehouse wall E2", "full", -62.5, 70, 5, 10, 11.8, 0, 0 },
		{ "Warehouse roof", "deck", -80, 60, 40, 40, 14, 0, 12 },
		{ "Roof stair", "ramp", -55, 52.5, 10, 25, 14, 0, 0 },
		{ "Roof landing", "deck", -55, 72.5, 10, 15, 14, 0, 0 },
		{ "Roof container", "full", -80, 35, 20, 10, 10, 0, 0 },
		{ "Roof container top", "deck", -80, 35, 20, 10, 10, 0, 0 },
		{ "Roof step high", "deck", -77.5, 27.5, 5, 5, 7, 0, 0 },
		{ "Roof step low", "plinth", -77.5, 22.5, 5, 5, 3.5, 0, 0 },
		{ "Lane stack L", "full", -30, 40, 10, 30, 10, 0, 0 },
		{ "Lane stack R", "full", 30, 25, 10, 30, 10, 0, 0 },
		{ "Cross container", "full", 5, 55, 30, 10, 10, 0, 0 },
		{ "Mid crates", "low", 15, 15, 5, 10, 3.5, 0, 0 },
		{ "Lane crate stack", "full", -20, 10, 10, 10, 10, 0, 0 },
		{ "Yard container", "full", 40, 75, 20, 10, 10, 0, 0 },
		{ "Perch deck", "deck", 70, 50, 10, 30, 10, 0, 0 },
		{ "Step crate high", "deck", 62.5, 40, 5, 5, 7, 0, 0 },
		{ "Step crate low", "plinth", 57.5, 40, 5, 5, 3.5, 0, 0 },
		{ "Back step high", "deck", 70, 67.5, 5, 5, 7, 0, 0 },
		{ "Back step low", "plinth", 70, 72.5, 5, 5, 3.5, 0, 0 },
		{ "Right short", "full", 85, 10, 10, 20, 10, 0, 0 },
		{ "Gantry crate stack", "full", 45, 0, 10, 10, 10, 0, 0 },
	},
	spawns = { { -12, 103 }, { 0, 106 }, { 12, 103 }, { -6, 98 }, { 6, 98 } },
})
return pier .. " | " .. dockyard
