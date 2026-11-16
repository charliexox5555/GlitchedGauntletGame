--!strict
-- Arena / Big Arena greybox (map redesign 2026-11-16). Data comes from
-- tools/maps/arena_layout.py (`python tools/maps/arena_layout.py --luau <map>` writes a
-- bundle with DATA filled in); run the bundle with the Studio MCP execute_luau or the
-- Command Bar, edit mode. Works in the Lobby place (staging while the match place is
-- busy, under Workspace.MapsRedesign) and in the match place (Workspace.<id>).
--
-- Map contract (MapService / Config/Match): a Model named by the map id with
--   Greybox.<Section>  collision Parts (the art pass hides, never deletes, them)
--   Spawns             SpawnLocations tagged ArenaSpawn_A / ArenaSpawn_B
--   Barriers           empty (no spawn gates: ghost hold at the markers)
--   Lighting           Configuration, attributes = Lighting properties
--   LightingFx         Atmosphere (+ Sky later)
--   attribute KillDepth (studs below the pivot)
-- Layout space: X across, Z along, +Z = team A, floor top at Y = 0.

local CollectionService = game:GetService("CollectionService")

type Row = { string | number }
type Data = {
	id: string,
	title: string,
	origin: { number },
	room: { { number } },
	boxes: { Row },
	spawnsA: { { number } },
	spawnsB: { { number } },
	duel: boolean,
	ceiling: number,
	wallHeight: number,
}

local DATA: Data = {
	id = "BigArena",
	title = "Big Arena",
	origin = {4500, 200, -600},
	room = {{28.9877, 108.184}, {79.196, 79.196}, {108.184, 28.9877}, {108.184, -28.9877}, {79.196, -79.196}, {28.9877, -108.184}, {-28.9877, -108.184}, {-79.196, -79.196}, {-108.184, -28.9877}, {-108.184, 28.9877}, {-79.196, 79.196}, {-28.9877, 108.184}},
	boxes = {
		{"Beacon plinth", "plinth", 0, 0, 25, 25, 3, 0, 0},
		{"Beacon pylon", "pillar", 0, 0, 5, 5, 45, 0, 0},
		{"Spawn screen", "baffle", 0, 77.5, 40, 5, 10, 0, 0},
		{"Spawn screen wing", "baffle", -22.5, 82.5, 5, 15, 10, 0, 0},
		{"Spawn wall", "full", 42.5, 77.5, 15, 5, 10, 0, 0},
		{"Spawn low", "low", -45, 82.5, 10, 5, 3, 0, 0},
		{"Tower deck", "deck", -60, 60, 20, 20, 14, 0, 0},
		{"Tower stair", "ramp", -60, 40, 10, 20, 14, 0, 0},
		{"Tower step deck", "deck", -45, 57.5, 10, 15, 7, 0, 0},
		{"Step crate", "plinth", -37.5, 62.5, 5, 5, 3, 0, 0},
		{"Side deck", "deck", 65, 45, 20, 20, 7, 0, 0},
		{"Side deck ramp", "ramp", 65, 27.5, 10, 15, 7, 0, 0},
		{"Divider", "full", -32.5, 15, 5, 20, 10, 0, 0},
		{"Divider sill", "low", -32.5, 32.5, 5, 15, 3, 0, 0},
		{"Divider lintel", "full", -32.5, 32.5, 5, 15, 10, 0, 7.5},
		{"Divider post", "pillar", -32.5, 42.5, 5, 5, 10, 0, 0},
		{"Mid wall", "full", 12.5, 52.5, 15, 5, 10, 0, 0},
		{"Mid low wall", "low", 0, 52.5, 10, 5, 3, 0, 0},
		{"Mid slab", "full", -15, 25, 15, 5, 10, 20, 0},
		{"Beacon wing", "full", -25, -7.5, 10, 5, 10, 0, 0},
		{"Mid post", "pillar", 17.5, 32.5, 5, 5, 10, 0, 0},
		{"Left slab", "full", -65, 15, 15, 5, 10, -15, 0},
		{"Left low", "low", -82.5, -7.5, 5, 15, 3, 0, 0},
		{"Left block", "full", -50, -35, 10, 10, 10, 0, 0},
		{"Outer slab", "full", -90, 30, 5, 15, 10, 30, 0},
		{"Right block", "full", 60, 5, 10, 10, 10, 0, 0},
		{"Right slab", "full", 87.5, -7.5, 5, 15, 10, 0, 0},
		{"Outer post", "pillar", 87.5, 32.5, 5, 5, 10, 0, 0},
		{"Spawn screen'", "baffle", 0, -77.5, 40, 5, 10, 0, 0},
		{"Spawn screen wing'", "baffle", 22.5, -82.5, 5, 15, 10, 0, 0},
		{"Spawn wall'", "full", -42.5, -77.5, 15, 5, 10, 0, 0},
		{"Spawn low'", "low", 45, -82.5, 10, 5, 3, 0, 0},
		{"Tower deck'", "deck", 60, -60, 20, 20, 14, 0, 0},
		{"Tower stair'", "ramp", 60, -40, 10, 20, 14, 0, 0},
		{"Tower step deck'", "deck", 45, -57.5, 10, 15, 7, 0, 0},
		{"Step crate'", "plinth", 37.5, -62.5, 5, 5, 3, 0, 0},
		{"Side deck'", "deck", -65, -45, 20, 20, 7, 0, 0},
		{"Side deck ramp'", "ramp", -65, -27.5, 10, 15, 7, 0, 0},
		{"Divider'", "full", 32.5, -15, 5, 20, 10, 0, 0},
		{"Divider sill'", "low", 32.5, -32.5, 5, 15, 3, 0, 0},
		{"Divider lintel'", "full", 32.5, -32.5, 5, 15, 10, 0, 7.5},
		{"Divider post'", "pillar", 32.5, -42.5, 5, 5, 10, 0, 0},
		{"Mid wall'", "full", -12.5, -52.5, 15, 5, 10, 0, 0},
		{"Mid low wall'", "low", 0, -52.5, 10, 5, 3, 0, 0},
		{"Mid slab'", "full", 15, -25, 15, 5, 10, 20, 0},
		{"Beacon wing'", "full", 25, 7.5, 10, 5, 10, 0, 0},
		{"Mid post'", "pillar", -17.5, -32.5, 5, 5, 10, 0, 0},
		{"Left slab'", "full", 65, -15, 15, 5, 10, -15, 0},
		{"Left low'", "low", 82.5, 7.5, 5, 15, 3, 0, 0},
		{"Left block'", "full", 50, 35, 10, 10, 10, 0, 0},
		{"Outer slab'", "full", 90, -30, 5, 15, 10, 30, 0},
		{"Right block'", "full", -60, -5, 10, 10, 10, 0, 0},
		{"Right slab'", "full", -87.5, 7.5, 5, 15, 10, 0, 0},
		{"Outer post'", "pillar", -87.5, -32.5, 5, 5, 10, 0, 0},
	},
	spawnsA = {{-12, 94}, {0, 96}, {12, 94}, {-6, 88}, {6, 88}},
	spawnsB = {{12, -94}, {0, -96}, {-12, -94}, {6, -88}, {-6, -88}},
	duel = false,
	ceiling = 80,
	wallHeight = 18,
}

local LOBBY, MATCH = 71551303511506, 133387545285290
assert(game.PlaceId == LOBBY or game.PlaceId == MATCH, "Arena greybox: not our place")

local COLORS = {
	floor = Color3.fromRGB(200, 202, 204),
	wall = Color3.fromRGB(158, 162, 168),
	full = Color3.fromRGB(185, 186, 183),
	baffle = Color3.fromRGB(176, 178, 176),
	low = Color3.fromRGB(214, 215, 211),
	pillar = Color3.fromRGB(120, 125, 133),
	deck = Color3.fromRGB(142, 147, 155),
	ramp = Color3.fromRGB(169, 173, 179),
	plinth = Color3.fromRGB(214, 196, 150),
	gold = Color3.fromRGB(217, 163, 58),
}

local origin = CFrame.new(DATA.origin[1], DATA.origin[2], DATA.origin[3])

local parentFolder: Instance = workspace
if game.PlaceId == LOBBY then
	local f = workspace:FindFirstChild("MapsRedesign")
	if not f then
		f = Instance.new("Folder")
		f.Name = "MapsRedesign"
		f.Parent = workspace
	end
	parentFolder = f :: Instance
end

local old = parentFolder:FindFirstChild(DATA.id)
if old then
	old:Destroy()
end
local map = Instance.new("Model")
map.Name = DATA.id
map.WorldPivot = origin
map:SetAttribute("KillDepth", 40)
map:SetAttribute("LayoutVersion", "v1 2026-11-16")

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local greybox = folder(map, "Greybox")
local spawns = folder(map, "Spawns")
local barriers = folder(map, "Barriers")
local sections: { [string]: Folder } = {}
local function section(name: string): Folder
	local s = sections[name]
	if not s then
		s = folder(greybox, name)
		sections[name] = s
	end
	return s
end

local function part(class: string, parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): BasePart
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
	return p
end

-- Floor: one slab under the room's bounding box (top at Y = 0).
local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
for _, p in DATA.room do
	minX, maxX = math.min(minX, p[1]), math.max(maxX, p[1])
	minZ, maxZ = math.min(minZ, p[2]), math.max(maxZ, p[2])
end
part(
	"Part",
	section("Floor"),
	"Floor",
	Vector3.new(maxX - minX + 8, 4, maxZ - minZ + 8),
	CFrame.new((minX + maxX) / 2, -2, (minZ + maxZ) / 2),
	COLORS.floor
)

-- Outer walls along the room outline (outside the playable polygon), plus invisible
-- bounds up to the ceiling and a lid.
local n = #DATA.room
local signedArea = 0
for i = 1, n do
	local a, b = DATA.room[i], DATA.room[i % n + 1]
	signedArea += a[1] * b[2] - b[1] * a[2]
end
local ccw = signedArea > 0
for i = 1, n do
	local a, b = DATA.room[i], DATA.room[i % n + 1]
	local ax, az, bx, bz = a[1], a[2], b[1], b[2]
	local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
	local dx, dz = (bx - ax) / len, (bz - az) / len
	-- outward normal
	local nx, nz = if ccw then dz else -dz, if ccw then -dx else dx
	local cx, cz = (ax + bx) / 2 + nx * 2, (az + bz) / 2 + nz * 2
	local yaw = math.atan2(-dz, dx)
	local cf = CFrame.new(cx, DATA.wallHeight / 2, cz) * CFrame.Angles(0, yaw, 0)
	part("Part", section("Walls"), "Wall", Vector3.new(len + 4, DATA.wallHeight, 4), cf, COLORS.wall)
	local hb = DATA.ceiling - DATA.wallHeight
	local bound = part(
		"Part",
		section("Bounds"),
		"Bound",
		Vector3.new(len + 4, hb, 4),
		CFrame.new(cx, DATA.wallHeight + hb / 2, cz) * CFrame.Angles(0, yaw, 0),
		COLORS.wall
	)
	bound.Transparency = 1
	bound.CastShadow = false
	bound.CanQuery = false
end
local lid = part(
	"Part",
	section("Bounds"),
	"Ceiling",
	Vector3.new(maxX - minX + 8, 2, maxZ - minZ + 8),
	CFrame.new((minX + maxX) / 2, DATA.ceiling + 1, (minZ + maxZ) / 2),
	COLORS.wall
)
lid.Transparency = 1
lid.CastShadow = false
lid.CanQuery = false

-- Cover, decks, ramps. Row: name, kind, x, z, sx, sz, h, yaw, base
local decks: { { number } } = {}
for _, r in DATA.boxes do
	if r[2] == "deck" or r[2] == "plinth" then
		table.insert(decks, { r[3] :: number, r[4] :: number, r[7] :: number })
	end
end

for _, r in DATA.boxes do
	local name, kind = r[1] :: string, r[2] :: string
	local x, z, sx, sz, h, yaw, base =
		r[3] :: number, r[4] :: number, r[5] :: number, r[6] :: number, r[7] :: number, r[8] :: number, r[9] :: number
	local sec = if kind == "deck" or kind == "ramp" then "Heights" elseif kind == "low" then "LowCover" else "Cover"
	if string.find(name, "Beacon") then
		sec = "Beacon"
	elseif string.find(name, "Spawn") then
		sec = "Spawn"
	end
	if kind == "ramp" then
		-- Walk up toward the deck of the same height that touches it.
		local best, bd = nil, math.huge
		for _, d in decks do
			if math.abs(d[3] - h) < 0.1 then
				local dd = (d[1] - x) ^ 2 + (d[2] - z) ^ 2
				if dd < bd then
					best, bd = d, dd
				end
			end
		end
		assert(best, "ramp without a deck: " .. name)
		local vx, vz = best[1] - x, best[2] - z
		local alongZ = math.abs(vz) >= math.abs(vx)
		local width, length = if alongZ then sx else sz, if alongZ then sz else sx
		local dir = if alongZ then Vector3.new(0, 0, math.sign(vz)) else Vector3.new(math.sign(vx), 0, 0)
		local pos = Vector3.new(x, h / 2, z)
		-- WedgePart: low at local -Z, high at +Z, so +Z faces the deck.
		local cf = CFrame.lookAt(pos, pos - dir)
		part("WedgePart", section(sec), name, Vector3.new(width, h, length), cf, COLORS.ramp)
	else
		local height = h - base
		local cf = CFrame.new(x, base + height / 2, z) * CFrame.Angles(0, math.rad(-yaw), 0)
		local color = (COLORS :: any)[kind] or COLORS.full
		local p = part("Part", section(sec), name, Vector3.new(sx, height, sz), cf, color)
		if name == "Beacon pylon" then
			part(
				"Part",
				section(sec),
				"Beacon crown",
				Vector3.new(sx + 1, 3, sz + 1),
				CFrame.new(x, h - 4, z) * CFrame.Angles(0, math.rad(-yaw), 0),
				COLORS.gold
			)
		end
		p:SetAttribute("Kind", kind)
	end
end

-- Spawns (tagged) and spawn gates.
for team, list in { A = DATA.spawnsA, B = DATA.spawnsB } do
	for i, s in list do
		local sp = Instance.new("SpawnLocation")
		sp.Name = string.format("Spawn_%s%d", team, i)
		sp.Anchored = true
		sp.Size = Vector3.new(4, 0.2, 4)
		local face = if team == "A" then 0 else math.pi -- look toward the middle (-Z for A)
		sp.CFrame = origin * CFrame.new(s[1], 0.1, s[2]) * CFrame.Angles(0, face, 0)
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

-- No spawn gates: players are held in place at their markers as ghosts until GO
-- (RIVALS-style hold, owner 2026-11-16; vault/01 Design/Spawn Hold.md). `barriers`
-- stays empty so MapService.setBarriers is a no-op on these maps.
local _ = barriers

-- Lighting profile (RIVALS-clean: bright, neutral, warm key, cool shade).
local light = Instance.new("Configuration")
light.Name = "Lighting"
light:SetAttribute("ClockTime", 13.2)
light:SetAttribute("Brightness", 3)
light:SetAttribute("ExposureCompensation", 0.15)
light:SetAttribute("Ambient", Color3.fromRGB(128, 132, 142))
light:SetAttribute("OutdoorAmbient", Color3.fromRGB(168, 174, 188))
light:SetAttribute("ColorShift_Top", Color3.fromRGB(255, 244, 226))
light:SetAttribute("EnvironmentDiffuseScale", 0.4)
light:SetAttribute("EnvironmentSpecularScale", 0.1)
light.Parent = map
local fx = folder(map, "LightingFx")
local atm = Instance.new("Atmosphere")
atm.Density = 0.28
atm.Offset = 0.1
atm.Color = Color3.fromRGB(214, 222, 232)
atm.Decay = Color3.fromRGB(150, 164, 186)
atm.Glare = 0
atm.Haze = 1.2
atm.Parent = fx

map.Parent = parentFolder

local count = 0
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") then
		count += 1
	end
end
return string.format("%s built at %s: %d parts", DATA.id, tostring(origin.Position), count)
