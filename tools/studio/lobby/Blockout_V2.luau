--!strict
-- Blockout_V2.luau: compact "Sunwell Bunker, redone" blockout (vault/02 Art/Lobby Rebuild 2026-11-04.md, phase 3).
-- Plain parts only, built BESIDE the current lobby at ORIGIN so nothing is demolished until it passes the critique.
-- Re-runnable: rebuilds Workspace.LobbyBlockoutV2. Bearings: 0 = north (-Z), 90 = east (+X). Spawn faces north.
assert(game.PlaceId == 133387545285290, "Blockout_V2: this is not the Lobby place")

local ORIGIN = Vector3.new(700, 0, 0)
local old = workspace:FindFirstChild("LobbyBlockoutV2")
if old then
	old:Destroy()
end
local root = Instance.new("Model")
root.Name = "LobbyBlockoutV2"
root.Parent = workspace

local GREY, DARK, LIGHT = Color3.fromHex("9A9690"), Color3.fromHex("5E5B57"), Color3.fromHex("C9C4BC")
local ZONE = {
	duels = Color3.fromHex("3A4450"),
	market = Color3.fromHex("8C7F6B"),
	armoury = Color3.fromHex("6E8A92"),
	range = Color3.fromHex("8E4A4A"),
}
local ACCENT = {
	duels = Color3.fromHex("FF5A36"),
	market = Color3.fromHex("F2B33D"),
	armoury = Color3.fromHex("3DD9F2"),
	range = Color3.fromHex("FF4757"),
}

local function folder(name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = root
	return f
end

local function box(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = CFrame.new(ORIGIN) * cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function cyl(parent: Instance, name: string, r: number, y0: number, y1: number, x: number, z: number, color: Color3): Part
	return box(parent, name, Vector3.new(y1 - y0, r * 2, r * 2), CFrame.new(x, (y0 + y1) / 2, z) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.PartType.Cylinder)
end

local function polar(r: number, b: number): (number, number)
	local a = math.rad(b)
	return math.sin(a) * r, -math.cos(a) * r
end

-- Ring of tangent boxes between radii r0..r1 and heights y0..y1, skipping `gaps` ({bearing, width at r1}).
local function arc(parent: Instance, name: string, r0: number, r1: number, y0: number, y1: number, color: Color3, gaps: { { number } }?, cx: number?, cz: number?)
	local n = math.max(16, math.ceil(2 * math.pi * r1 / 5))
	local step = 360 / n
	for i = 0, n - 1 do
		local b = (i + 0.5) * step
		local skip = false
		for _, g in gaps or {} do
			local half = math.deg(math.asin(math.min(1, (g[2] / 2) / r1)))
			local d = math.abs(((b - g[1] + 180) % 360) - 180)
			if d < half then
				skip = true
			end
		end
		if not skip then
			local x, z = polar((r0 + r1) / 2, b)
			x += cx or 0
			z += cz or 0
			local chord = 2 * r1 * math.sin(math.rad(step / 2)) + 0.05
			local look = CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(cx or 0, 0, cz or 0))
			box(parent, name, Vector3.new(chord, y1 - y0, r1 - r0), look.Rotation + Vector3.new(x, (y0 + y1) / 2, z), color)
		end
	end
end

local function label(p: BasePart, text: string, color: Color3)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 12
	sg.LightInfluence = 0
	sg.Parent = p
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = color
	t.Parent = sg
end

-- A sign panel facing `toward` (a point), centre at (x, y, z).
local function sign(parent: Instance, text: string, w: number, h: number, x: number, y: number, z: number, toward: Vector3, color: Color3)
	local cf = CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(toward.X, y, toward.Z))
	local p = box(parent, "Sign_" .. text, Vector3.new(w, h, 0.6), cf, Color3.fromHex("23272D"))
	label(p, text, color)
end

local function avatar(parent: Instance, x: number, z: number)
	box(parent, "Avatar", Vector3.new(2, 5, 1), CFrame.new(x, 2.5, z), Color3.fromHex("E8B04A"))
end

-- ---------------------------------------------------------------- hub: floor, rotunda, ring
local hub = folder("Hub")
box(hub, "Floor", Vector3.new(182, 1, 176), CFrame.new(2, -0.5, -25), DARK)
cyl(hub, "RotundaFloor", 30, -0.4, 0.1, 0, 0, LIGHT)
cyl(hub, "SpawnDais", 9, 0, 0.6, 0, 0, Color3.fromHex("B08D55"))
local spawnMark = box(hub, "SpawnFacing", Vector3.new(1, 0.2, 6), CFrame.new(0, 0.7, -4), ACCENT.duels)
spawnMark.CanCollide = false

-- Colonnade R30 (8 piers between the 8 openings), drum 20..27, stepped dome to the skylight R11 at 38.
for k = 0, 7 do
	local x, z = polar(30, 22.5 + 45 * k)
	box(hub, "Pier", Vector3.new(4, 20, 4), CFrame.new(x, 10, z) * CFrame.Angles(0, -math.rad(22.5 + 45 * k), 0), GREY)
end
arc(hub, "Drum", 28.5, 31.5, 20, 27, GREY)
arc(hub, "Dome1", 24, 31.5, 27, 30, LIGHT)
arc(hub, "Dome2", 17.5, 24, 30, 34, LIGHT)
arc(hub, "Dome3", 11, 17.5, 34, 38, LIGHT)

-- Ring R30..44: ceiling at 22, outer wall with the four wing portals (Duels 40 wide, others 28), 14 tall.
arc(hub, "RingCeiling", 31.5, 45, 22, 23.5, GREY)
local gaps = { { 0, 40 }, { 270, 28 }, { 90, 28 }, { 180, 28 } }
arc(hub, "RingWall", 44, 46, 0, 22, DARK, gaps)
for _, g in gaps do -- lintels over the portals (14 clear)
	local x, z = polar(45, g[1])
	box(hub, "PortalLintel", Vector3.new(g[2] + 2, 8, 2), CFrame.lookAt(Vector3.new(x, 18, z), Vector3.new(0, 18, 0)), GREY)
end
-- Leaderboards behind the NE / NW colonnade openings, facing spawn.
for _, b in { -45, 45 } do
	local x, z = polar(37, b)
	sign(hub, "LEADERBOARD", 14, 8, x, 10, z, Vector3.zero, Color3.fromHex("FFFFFF"))
end

-- ---------------------------------------------------------------- Duels hall (north)
-- RIVALS-style: one long open hall (44 x 92, 28 high), a central walkway with chevrons, pads set into the floor
-- on both sides with no walls between them, a count screen on the side wall behind each pad, mode tabs overhead.
local duels = folder("Duels")
box(duels, "HallFloor", Vector3.new(44, 0.2, 92), CFrame.new(0, 0.1, -90), ZONE.duels)
box(duels, "Walkway", Vector3.new(10, 0.25, 92), CFrame.new(0, 0.12, -90), Color3.fromHex("4A5562"))
for z = -50, -128, -8 do
	local c = box(duels, "Chevron", Vector3.new(4, 0.3, 1), CFrame.new(0, 0.15, z), Color3.new(1, 1, 1))
	c.CanCollide = false
end
box(duels, "WallW", Vector3.new(2, 28, 94), CFrame.new(-23, 14, -90), DARK)
box(duels, "WallE", Vector3.new(2, 28, 94), CFrame.new(23, 14, -90), DARK)
box(duels, "WallBack", Vector3.new(48, 28, 2), CFrame.new(0, 14, -137), DARK)
box(duels, "Ceiling", Vector3.new(48, 1.5, 94), CFrame.new(0, 28.75, -90), GREY)
for z = -52, -128, -19 do -- buttresses and roof trusses give the hall its rhythm
	for _, s in { -1, 1 } do
		box(duels, "Buttress", Vector3.new(3, 22, 3), CFrame.new(20.5 * s, 11, z), GREY)
	end
	box(duels, "Truss", Vector3.new(44, 2, 2), CFrame.new(0, 25, z), GREY)
end
sign(duels, "DUELS", 26, 6, 0, 18, -42.6, Vector3.new(0, 0, 0), ACCENT.duels)
local modeColor = { ["1V1"] = Color3.fromHex("FF7A2F"), ["2V2"] = Color3.fromHex("27B7FF"), ["3V3"] = Color3.fromHex("A15CFF") }
local pads = { { "1V1", 12, -54 }, { "1V1", 12, -68 }, { "2V2", 14, -84 }, { "3V3", 16, -102 } }
for _, p in pads do
	for _, s in { -1, 1 } do
		local x = s * (5 + 1 + p[2] / 2)
		box(duels, "Pad_" .. p[1], Vector3.new(p[2], 0.4, p[2]), CFrame.new(x, 0.2, p[3]), modeColor[p[1]])
		sign(duels, "0/" .. string.sub(p[1], 1, 1), p[2] - 2, 7, s * 21.9, 6, p[3], Vector3.new(0, 0, p[3]), Color3.new(1, 1, 1))
		local tab = box(duels, "ModeTab_" .. p[1], Vector3.new(6, 2.5, 0.4), CFrame.new(x, 16, p[3]) * CFrame.Angles(math.rad(-20), 0, 0), modeColor[p[1]])
		label(tab, p[1], Color3.fromHex("10151C"))
	end
end
sign(duels, "4V4 / GAUNTLET SOON", 20, 14, 0, 9, -135.6, Vector3.new(0, 0, 0), Color3.fromHex("8899AA"))
sign(duels, "QUEUE BOARD", 14, 8, -21.9, 14, -122, Vector3.new(0, 0, -122), Color3.new(1, 1, 1))
sign(duels, "WIN STREAKS", 14, 8, 21.9, 14, -122, Vector3.new(0, 0, -122), Color3.new(1, 1, 1))

-- ---------------------------------------------------------------- Market (west)
local market = folder("Market")
box(market, "Floor", Vector3.new(40, 0.2, 44), CFrame.new(-64, 0.1, 0), ZONE.market)
box(market, "WallBack", Vector3.new(2, 22, 46), CFrame.new(-85, 11, 0), DARK)
box(market, "WallN", Vector3.new(42, 22, 2), CFrame.new(-64, 11, -23), DARK)
box(market, "WallS", Vector3.new(42, 22, 2), CFrame.new(-64, 11, 23), DARK)
box(market, "FrontN", Vector3.new(2, 22, 8), CFrame.new(-44, 11, -18), DARK)
box(market, "FrontS", Vector3.new(2, 22, 8), CFrame.new(-44, 11, 18), DARK)
box(market, "Ceiling", Vector3.new(42, 1.5, 46), CFrame.new(-64, 22.75, 0), GREY)
sign(market, "SHOP · BATTLE PASS", 24, 5, -42.6, 17.5, 0, Vector3.zero, ACCENT.market)
box(market, "ShopCounter", Vector3.new(20, 4, 3), CFrame.new(-64, 2, 19), Color3.fromHex("94683F"))
sign(market, "SHOP", 12, 3, -64, 9, 21.6, Vector3.new(-64, 0, 0), ACCENT.market)
sign(market, "BATTLE PASS WALL", 24, 14, -83.6, 9, 0, Vector3.new(0, 0, 0), ACCENT.market)
cyl(market, "FeaturedTurntable", 4, 0, 1, -62, -6, GREY)

-- ---------------------------------------------------------------- Armoury + Locker (east): round room R22 at x 66
local arm = folder("Armoury")
cyl(arm, "Floor", 22, 0, 0.2, 66, 0, ZONE.armoury)
arc(arm, "Wall", 22, 24, 0, 22, DARK, { { 270, 28 } }, 66, 0)
arc(arm, "Ceiling", 0.5, 24, 22, 23.5, GREY, nil, 66, 0)
sign(arm, "ARMOURY · LOCKER", 24, 5, 42.6, 17.5, 0, Vector3.zero, ACCENT.armoury)
cyl(arm, "HeroPlinth", 5, 0, 2, 64, 0, GREY)
box(arm, "HeroGun", Vector3.new(14, 3, 1), CFrame.new(64, 6, 0), Color3.fromHex("2A2D33"))
for _, b in { 45, 135, 225, 315 } do
	local x, z = polar(14, b)
	cyl(arm, "GunTurntable", 2.5, 0, 1.5, 66 + x, z, GREY)
end
cyl(arm, "LockerPedestal", 4, 0, 1, 82, 0, Color3.fromHex("B08D55"))
sign(arm, "LOCKER", 10, 3, 87.4, 12, 0, Vector3.new(66, 0, 0), ACCENT.armoury)

-- ---------------------------------------------------------------- Range door (south)
local range = folder("Range")
box(range, "VestW", Vector3.new(2, 16, 16), CFrame.new(-15, 8, 51), DARK)
box(range, "VestE", Vector3.new(2, 16, 16), CFrame.new(15, 8, 51), DARK)
box(range, "VestBack", Vector3.new(32, 16, 2), CFrame.new(0, 8, 59), DARK)
box(range, "VestCeiling", Vector3.new(32, 1.5, 16), CFrame.new(0, 16.75, 51), GREY)
local door = box(range, "EnterRangeDoor", Vector3.new(12, 14, 0.4), CFrame.new(0, 7, 57.8), ACCENT.range)
door.Material = Enum.Material.Neon
sign(range, "RANGE", 18, 4, 0, 17.5, 42.6, Vector3.zero, ACCENT.range)

-- ---------------------------------------------------------------- scale proxies and a sunbeam stand-in
local people = folder("People")
for _, p in { { 0, 0 }, { -12, -54 }, { 12, -84 }, { -14, -102 }, { 2, -120 }, { -64, 15 }, { 64, 4 }, { 0, 52 }, { 36, -6 }, { -38, 10 } } do
	avatar(people, p[1], p[2])
end
local beam = box(hub, "SunPatch", Vector3.new(0.2, 18, 18), CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromHex("FFE2B8"), Enum.PartType.Cylinder)
beam.Material = Enum.Material.Neon
beam.Transparency = 0.6
beam.CanCollide = false

local n = #root:GetDescendants()
return ("blockout built: %d instances at %s"):format(n, tostring(ORIGIN))
