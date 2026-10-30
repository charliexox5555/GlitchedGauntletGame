--!strict
-- Lobby art: the hub (spawn rotunda + outer ring), phase 1 step 5.
-- Bundle: `python tools/studio/lobby/bundle.py Art_Hub -o art_hub.luau` (after the
-- Hub kit group is installed with kit_bundle.py Hub). Re-runnable: it hides the
-- greybox parts it replaces (they stay the collision), finishes the ones that stay
-- visible, and rebuilds Workspace.Lobby.Art.Rotunda and Art.Ring.
--
-- Kit pieces (tools/blender/build_lobby_kit_hub.py):
--   rotunda  RotundaFloor, SpawnDais, RotundaPier x8, RotundaColumn x4, RingBeam_R44 /
--            Drum_R44 / DomeCoffer_R44 x32, OculusRim_R16, LeaderboardFrame x4, PierPlaque x2
--   ring     RingFloor_R44_68 / RingCeiling_R44_68 x32, RockPlinth_R68 + RockWall_R68_A/B/C
--            (each upright or turned over, so 6 looks) on the 14 rock segments,
--            Alcove_R68 x4, PortalFrame_52 (Duels) + PortalFrame_26 x3, TitleBand_40/_26
-- Lights: one SurfaceLight per portal soffit (4, shadowless). Everything else glows
-- with Neon; the sunbeam rig is step 6.

local rotGrey = grey("Rotunda")
assert(rotGrey, "no Greybox.Rotunda (run Hub.luau first)")
local ringGrey = grey("Ring")
assert(ringGrey, "no Greybox.Ring (run Hub.luau first)")

local LIGHTS = 0
-- Roblox Neon pushes toward white: the kit's cove colour (#FFDDB0) read clinical,
-- so every warm line is tinted down to a warm 3000K-looking amber.
local KIT_COVE = Color3.fromHex("FFDDB0")
local WARM = Color3.fromHex("D9A577")
local SCREEN_GLOW = Color3.fromHex("A9BACB")

local function warmGlows(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Glow") and d.Color == KIT_COVE then
			d.Color = WARM
		end
	end
end

local function bearingOf(p: Vector3): number
	return math.deg(math.atan2(p.X, -p.Z)) % 360
end

local function child(m: Instance, name: string): BasePart
	local p = m:FindFirstChild(name)
	assert(p and p:IsA("BasePart"), "kit part missing: " .. name)
	return p
end

-- ---------------------------------------------------------------- rotunda

local rot = artSection("Rotunda")

for _, p in rotGrey:GetChildren() do
	local n = p.Name
	if n == "LobbySpawn" then
		continue -- phase-2 hook: stays exactly as built (invisible spawn)
	elseif string.find(n, "^Leaderboard_") then
		finish(p, "Screen") -- keeps both SurfaceGuis
	elseif n == "Plaque" then
		finish(p, "Sign")
	else
		hide(p) -- floor, inlay, dais, arrow, piers, columns, beam, drum, dome, oculus
	end
end

-- The disc's top is z 0 in the kit; the greybox floor top is 0.02 (inlay 0.04).
put(rot, "RotundaFloor", CFrame.new(0, 0.02, 0))
put(rot, "SpawnDais", CFrame.identity)
put(rot, "OculusRim_R16", CFrame.identity)

local structure = Instance.new("Folder")
structure.Name = "Structure"
structure.Parent = rot
for k = 0, 7 do
	put(structure, "RotundaPier", ringCF(45.5, 22.5 + 45 * k), "Pier_" .. k)
end
for k = 0, 3 do
	put(structure, "RotundaColumn", ringCF(44, 45 + 90 * k), "Column_" .. k)
end
for k = 0, 31 do
	local cf = segCF(k * SEG)
	put(structure, "RingBeam_R44", cf, "RingBeam_" .. k)
	put(structure, "Drum_R44", cf, "Drum_" .. k)
	put(structure, "DomeCoffer_R44", cf, "Dome_" .. k)
end

-- Leaderboards keep their greybox screens (and SurfaceGuis); the kit bezel and
-- hangers frame them on the slim columns' brackets.
for _, p in rotGrey:GetChildren() do
	if p:IsA("BasePart") and string.find(p.Name, "^Leaderboard_") then
		local m =
			put(rot, "LeaderboardFrame", ringCF(42.5, bearingOf(p.Position)), p.Name .. "_Frame")
		m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		tint(m, SCREEN_GLOW)
	elseif p:IsA("BasePart") and p.Name == "Plaque" then
		local b = bearingOf(p.Position)
		local m = put(rot, "PierPlaque", ringCF(42.5, b), "Plaque_" .. math.floor(b + 0.5))
		m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		-- WEAPONS (east side) gets the neutral museum white, MARKET the warm cove.
		tint(m, if b < 180 then Color3.fromHex("E6E2D8") else WARM)
	end
end

warmGlows(rot)
publishArt(rot)

-- ---------------------------------------------------------------- ring

local ring = artSection("Ring")

for _, p in ringGrey:GetChildren() do
	hide(p) -- every ring greybox part is dressed by a kit piece (titles are rebuilt below)
end

local floors = Instance.new("Folder")
floors.Name = "FloorCeiling"
floors.Parent = ring
local rock = Instance.new("Folder")
rock.Name = "Rock"
rock.Parent = ring

-- Rock variety: 3 meshes, each upright or turned over about its mid radial line
-- (the rock's foot and top edges are both held on R68.9, so either way meets its
-- neighbours). Neighbours never share a look.
local ORDER = { 1, 5, 3, 4, 2, 6 }
local VARIANTS = { "RockWall_R68_A", "RockWall_R68_B", "RockWall_R68_C" }
local mid = math.rad(SEG / 2)
local FLIP = CFrame.new(0, 16.8, 0)
	* CFrame.fromAxisAngle(Vector3.new(math.sin(mid), 0, -math.cos(mid)), math.pi)
	* CFrame.new(0, -16.8, 0)

local rockCount = 0
for k = 0, 31 do
	local b = k * SEG
	local cf = segCF(b)
	put(floors, "RingFloor_R44_68", cf, "Floor_" .. k)
	put(floors, "RingCeiling_R44_68", cf, "Ceiling_" .. k)
	local bm = b + SEG / 2
	if not inAny(bm, PORTALS) and not inAny(bm, ALCOVES) then
		put(rock, "RockPlinth_R68", cf, "Plinth_" .. k)
		local idx = ORDER[(rockCount % #ORDER) + 1]
		local v = VARIANTS[((idx - 1) % 3) + 1]
		put(rock, v, if idx > 3 then cf * FLIP else cf, "Rock_" .. k)
		rockCount += 1
	end
end

local alcoves = Instance.new("Folder")
alcoves.Name = "Alcoves"
alcoves.Parent = ring
for i, a in ALCOVES do
	put(alcoves, "Alcove_R68", segCF(a[1]), "Alcove_" .. i)
end

-- Portals: frames (fronts 2 in front of the rock chord; side frames run back to the
-- wing boundary at 72), title bands in the frames' title slots, and the title signs
-- rebuilt on the bands (the greybox Title_* panels sat inside the new frame heads).
local FRONT_26 = 68 * math.cos(math.rad(SEG)) - 2
local FRONT_52 = 68 * math.cos(math.rad(2 * SEG)) - 2
local SUB = Color3.fromRGB(190, 192, 196)
type PortalSpec = {
	name: string,
	b: number,
	frame: string,
	back: number,
	band: string,
	w: number,
	title: string,
	cap: number,
	sub: string,
	strip: Color3,
	light: Color3,
}
local PORTAL_SPECS: { PortalSpec } = {
	{
		name = "DUELS",
		b = 0,
		frame = "PortalFrame_52",
		back = FRONT_52 + 6,
		band = "TitleBand_40",
		w = 40,
		title = "DUELS",
		cap = 5.5,
		sub = "STEP ON A PAD TO QUEUE",
		strip = GLOW.duelsRed,
		light = Color3.fromHex("FFF1DC"),
	},
	{
		name = "WEAPONS",
		b = 90,
		frame = "PortalFrame_26",
		back = 72,
		band = "TitleBand_26",
		w = 26,
		title = "WEAPONS",
		cap = 4,
		sub = "GUNS + LOCKER",
		strip = Color3.fromHex("F2EEE4"),
		light = Color3.fromHex("F2F0EA"),
	},
	{
		name = "RANGE",
		b = 180,
		frame = "PortalFrame_26",
		back = 72,
		band = "TitleBand_26",
		w = 26,
		title = "RANGE",
		cap = 4.5,
		sub = "PRACTICE",
		strip = GLOW.cool,
		light = Color3.fromHex("DDE8F2"),
	},
	{
		name = "MARKET",
		b = 270,
		frame = "PortalFrame_26",
		back = 72,
		band = "TitleBand_26",
		w = 26,
		title = "MARKET",
		cap = 4.5,
		sub = "SHOP + BATTLE PASS",
		strip = WARM,
		light = Color3.fromHex("FFD9A8"),
	},
}

local portals = Instance.new("Folder")
portals.Name = "Portals"
portals.Parent = ring
for _, s in PORTAL_SPECS do
	local frame = put(portals, s.frame, ringCF(s.back, s.b), "Portal_" .. s.name)
	local front = if s.frame == "PortalFrame_52" then FRONT_52 else FRONT_26
	-- One shadowless SurfaceLight on the hidden soffit strip washes the jamb returns
	-- and the sill, so each portal reads as a deep frame from the dais.
	local strip = child(frame, s.frame .. "_Soffit_Glow")
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = 120
	light.Range = 18
	light.Brightness = 1.6
	light.Color = s.light
	light.Shadows = false
	light.Parent = strip
	LIGHTS += 1

	local slotBack = front + 0.6
	local band = put(portals, s.band, ringCF(slotBack, s.b, 17), "TitleBand_" .. s.name)
	band.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	tint(band, s.strip)

	-- The SurfaceGui panel: kit x 0.2-0.3 in front of the band's backing, z 0.7-9.6.
	local x, z = polar(slotBack - 0.25, s.b)
	local pos = Vector3.new(x, 17 + 5.15, z)
	local facing = Vector3.new(-x, 0, -z).Unit
	local panel = make(
		band,
		"Title_" .. s.name,
		Vector3.new(s.w - 0.8, 8.9, 0.1),
		CFrame.lookAt(pos, pos + facing),
		C.sign,
		{
			collide = false,
			shadow = false,
		}
	)
	finish(panel, "Sign")
	addSurface(panel, Enum.NormalId.Front, {
		{ text = s.title, cap = s.cap },
		{ text = s.sub, cap = 1.2, color = SUB },
	}, 8.9)
	local gui = panel:FindFirstChildOfClass("SurfaceGui")
	if gui then
		for _, l in gui:GetChildren() do
			if l:IsA("TextLabel") and l.LayoutOrder == 2 then
				l.Font = Enum.Font.GothamBold
			end
		end
	end
end

warmGlows(ring)
publishArt(ring)
table.insert(REPORT, string.format("hub dynamic lights %d, rock segments %d", LIGHTS, rockCount))
