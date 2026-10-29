--!strict
-- Lobby greybox: the Weapons + Locker wing (east). A short low corridor
-- squeezes you, then releases you into the ARMOURY, a second, smaller rotunda
-- (R42, 30 tall, ribbed ceiling under a glazed lantern). Eight gun bays sit in
-- chapels between piers around its wall, the 8x hero rifle floats over a dais in
-- the middle, and the LOCKER is the apse on the far (east) side. Everything is on
-- the z = 0 axis, so from the hub you look through the portal at the hero gun
-- with the locker mannequin under it.
-- Run it as a bundle: `python tools/studio/lobby/bundle.py Wing_Weapons`.

local CX = 136 -- armoury centre (z = 0)
local R_IN = 42 -- armoury wall, inner radius
local R_OUT = 44
local WALL_TOP = 30
local BAY_BACK = 56 -- chapel back wall, inner radius (flat chord)
local BAY_TOP = 18
local DOOR = 13.27 -- half width of the ring portal

local gunBody = Color3.fromRGB(36, 37, 40)
local gunTrim = Color3.fromRGB(112, 116, 122)
local bayBack = Color3.fromRGB(58, 60, 64)
local lockerFloor = Color3.fromRGB(122, 126, 132)
local neonWhite = Color3.fromHex("F2F0EA") -- the planned 4500K museum light
local mannequin = Color3.fromRGB(226, 226, 222)
-- Fresh option tables each call: the kit's cylinder() writes `shape` into its opts.
local function metal(): PartOpts
	return { material = Enum.Material.Metal }
end
local function glow(): PartOpts
	return { material = Enum.Material.Neon, collide = false, shadow = false }
end

-- A box given by its extents in a local frame (for guns and other turned props).
local function lbox(
	f: Instance,
	name: string,
	frame: CFrame,
	x0: number,
	x1: number,
	y0: number,
	y1: number,
	z0: number,
	z1: number,
	color: Color3,
	opts: PartOpts?
): Part
	local size = Vector3.new(x1 - x0, y1 - y0, z1 - z0)
	local cf = frame * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
	return make(f, name, size, cf, color, opts)
end

-- Rifle stand-in `len` long along the frame's X (muzzle at -X), centre line on
-- the frame's origin. Proportions are drawn at 28 studs and scaled.
local function rifle(f: Instance, name: string, frame: CFrame, len: number)
	local s = len / 28
	local function piece(
		n: string,
		x0: number,
		x1: number,
		y0: number,
		y1: number,
		hz: number,
		c: Color3
	)
		lbox(
			f,
			name .. n,
			frame,
			x0 * s,
			x1 * s,
			y0 * s,
			y1 * s,
			-hz * s,
			hz * s,
			c,
			{ collide = false }
		)
	end
	piece("_Barrel", -14, -9, -0.4, 0.4, 0.4, gunTrim)
	piece("_Handguard", -10, -3, -1.1, 1.1, 0.8, gunBody)
	piece("_Receiver", -3, 6, -1.5, 1.7, 0.8, gunBody)
	piece("_Stock", 6, 14, -1.9, 0.9, 0.7, gunBody)
	piece("_Mag", 0, 2.6, -5.2, -1.5, 0.6, gunTrim)
	piece("_Scope", -2, 4, 1.7, 3.1, 0.6, gunTrim)
	return -1.1 * s -- underside of the handguard, where a stand meets it
end

-- Pistol stand-in `len` long, same frame convention.
local function pistol(f: Instance, name: string, frame: CFrame, len: number)
	local s = len / 6.5
	local function piece(
		n: string,
		x0: number,
		x1: number,
		y0: number,
		y1: number,
		hz: number,
		c: Color3
	)
		lbox(
			f,
			name .. n,
			frame,
			x0 * s,
			x1 * s,
			y0 * s,
			y1 * s,
			-hz * s,
			hz * s,
			c,
			{ collide = false }
		)
	end
	piece("_Slide", -3.25, 3.25, 0, 1.3, 0.45, gunBody)
	piece("_Frame", -2.6, 3.0, -0.6, 0, 0.4, gunTrim)
	piece("_Grip", 1.4, 3.1, -3.4, -0.6, 0.4, gunBody)
	return -0.6 * s
end

local function buildCorridor(f: Instance)
	-- Front wall over the hub throat, with the matching 26.54 x 16 opening.
	box(f, "FrontWallN", 70, 72, 0, 20, -19, -DOOR, C.concrete)
	box(f, "FrontWallS", 70, 72, 0, 20, DOOR, 19, C.concrete)
	box(f, "FrontLintel", 70, 72, 16, 20, -DOOR, DOOR, C.concrete)

	-- Floor runs on under the armoury's entry so the seam sits inside the drum.
	box(f, "CorridorFloor", 72, 98, -2, 0, -19, 19, C.weaponsFloor)
	box(f, "CorridorRunner", 72, 116, -0.5, 0.06, -5, 5, C.concrete)
	box(f, "CorridorRoof", 70, 98, 16, 17, -19, 19, C.concrete)
	for _, s in { -1, 1 } do
		local tag = s < 0 and "N" or "S"
		box(f, "CorridorWall" .. tag, 72, 90, 0, 17, s * DOOR, s * 16, C.weaponsWall)
		-- Shoulders close the gap between the corridor and the curved drum.
		box(f, "Shoulder" .. tag, 90, 97.5, 0, WALL_TOP, s * DOOR, s * 19, C.concrete)
		box(f, "EdgeLight" .. tag, 72, 90, 0, 0.12, s * 12.95, s * 13.25, neonWhite, glow())
	end

	-- Two steel frames step the ceiling down to 14 and 13.5: the squeeze before
	-- the release into the 30-tall drum.
	for i, fr in { { 79, 14 }, { 87, 13.5 } } do
		local x = fr[1]
		box(f, "FrameN_" .. i, x, x + 2, 0, 16, -DOOR, -11.27, C.steel, metal())
		box(f, "FrameS_" .. i, x, x + 2, 0, 16, 11.27, DOOR, C.steel, metal())
		box(f, "FrameBeam_" .. i, x, x + 2, fr[2], 16, -11.27, 11.27, C.steel, metal())
	end
	sign(f, "ArmourySign", 20, 2.4, Vector3.new(86.8, 14.75, 0), WEST, {
		{ text = "ARMOURY  +  LOCKER", cap = 1.6 },
	})
end

-- Bay layout: piers on these bearings, chapels between them (west = entry,
-- east = locker apse).
local PIERS = { 292.5, 326.25, 0, 33.75, 67.5, 112.5, 146.25, 180, 213.75, 247.5 }
-- { first bearing, name, gun length (0 = pistol), back wall radius }. The two
-- pistol chapels beside the entry are shallower, so the wing stays inside
-- |z| <= 26 west of x = 90.
local BAYS = {
	{ 292.5, "BYTE", 0, 50 },
	{ 326.25, "BANDWIDTH", 14, BAY_BACK },
	{ 0, "PULSE", 16, BAY_BACK },
	{ 33.75, "CHECKSUM", 17, BAY_BACK },
	{ 112.5, "OVERFLOW", 17, BAY_BACK },
	{ 146.25, "KERNEL", 18, BAY_BACK },
	{ 180, "HARD RESET", 15, BAY_BACK },
	{ 213.75, "ROOT", 0, 50 },
}
local BAY_SPAN = 33.75

local function at(r: number, b: number, y: number): Vector3
	local x, z = polar(r, b)
	return Vector3.new(CX + x, y, z)
end

local function buildArmoury(f: Instance)
	cylinder(f, "Floor", CX, 0, R_OUT, -2, 0, C.weaponsFloor)
	cylinder(f, "InlayRing", CX, 0, 20, -0.5, 0.06, C.concrete)
	box(f, "LockerRunner", 156, 176, -0.5, 0.06, -5, 5, C.concrete)

	-- Drum wall: heads over the chapels, a 16-tall entry and a 20-tall apse mouth.
	for _, bay in BAYS do
		local b0 = bay[1] :: number
		arc(
			f,
			"WallHead",
			R_IN,
			R_OUT,
			b0,
			b0 + BAY_SPAN,
			BAY_TOP,
			WALL_TOP,
			C.weaponsWall,
			nil,
			nil,
			CX,
			0
		)
	end
	arc(f, "EntryLintel", R_IN, R_OUT, 247.5, 292.5, 16, WALL_TOP, C.weaponsWall, nil, nil, CX, 0)
	arc(f, "ApseLintel", R_IN, R_OUT, 67.5, 112.5, 20, WALL_TOP, C.weaponsWall, nil, nil, CX, 0)

	-- Full-height concrete piers, with steel fins behind them splitting the
	-- chapels.
	for i, b in PIERS do
		make(
			f,
			"Pier_" .. i,
			Vector3.new(3, WALL_TOP, 2.5),
			CFrame.lookAt(at(41.25, b, WALL_TOP / 2), Vector3.new(CX, WALL_TOP / 2, 0)),
			C.concrete
		)
		local finOut = (b == 292.5 or b == 247.5) and 53 or 59
		make(
			f,
			"Fin_" .. i,
			Vector3.new(2, BAY_TOP + 1, finOut - 42),
			CFrame.lookAt(
				at((42 + finOut) / 2, b, (BAY_TOP + 1) / 2),
				Vector3.new(CX, (BAY_TOP + 1) / 2, 0)
			),
			C.steel,
			metal()
		)
	end

	for i, bay in BAYS do
		local b0 = bay[1] :: number
		local b1 = b0 + BAY_SPAN
		local bm = b0 + BAY_SPAN / 2
		local n = "Bay" .. i
		-- Chapel shell: a half-stud stage, a flat dark back wall, a lower roof.
		-- Shallow chapels follow the curve (11.25 degree pieces) instead.
		local rb = bay[4] :: number
		local deep = rb >= BAY_BACK
		local function shell(nm: string, r0: number, y0: number, y1: number, color: Color3)
			if deep then
				arcPiece(f, nm, r0, rb + 2, b0, b1, y0, y1, color, nil, CX, 0)
			else
				arc(f, nm, r0, rb + 2, b0, b1, y0, y1, color, nil, nil, CX, 0)
			end
		end
		shell(n .. "_Stage", 44, -2, 0.5, C.concrete)
		shell(n .. "_Back", rb, 0, BAY_TOP + 1, bayBack)
		shell(n .. "_Roof", 43.7, BAY_TOP, BAY_TOP + 1, C.weaponsWall)
		local inward = (Vector3.new(CX, 0, 0) - at(1, bm, 0)).Unit
		local panelW = deep and 20 or 14
		-- Inner face of the back wall on the chapel's centre line.
		local face = rb * math.cos(math.rad(deep and BAY_SPAN / 2 or SEG / 2))
		local back = at(face - 0.3, bm, 8)
		make(
			f,
			n .. "_Trophy",
			Vector3.new(panelW, 12, 0.4),
			CFrame.lookAt(back, back + inward),
			C.steel
		)
		local cove = at(face - 0.6, bm, 17.6)
		make(
			f,
			n .. "_Cove",
			Vector3.new(panelW + 2, 0.3, 0.3),
			CFrame.lookAt(cove, cove + inward),
			neonWhite,
			glow()
		)

		-- Turntable plinth with a white under-ring and the gun on a stand.
		local pr = deep and 5 or 3.5
		local p = at(42.5 + pr, bm, 0)
		cylinder(f, n .. "_Plinth", p.X, p.Z, pr, 0.5, 3, C.steel, metal())
		cylinder(f, n .. "_UnderRing", p.X, p.Z, pr + 0.3, 0.5, 0.75, neonWhite, glow())
		cylinder(f, n .. "_Turntable", p.X, p.Z, pr - 0.4, 3, 3.4, C.white)
		local len = bay[3] :: number
		local a = math.rad(bm)
		local tangent = Vector3.new(math.cos(a), 0, math.sin(a))
		local frame = CFrame.fromMatrix(Vector3.new(p.X, 7.5, p.Z), tangent, Vector3.yAxis)
		local under: number
		if len > 0 then
			under = rifle(f, n .. "_Gun", frame, len)
		else
			under = pistol(f, n .. "_Gun", frame, 6.5)
		end
		box(
			f,
			n .. "_Stand",
			p.X - 0.4,
			p.X + 0.4,
			3.4,
			7.5 + under,
			p.Z - 0.4,
			p.Z + 0.4,
			C.steel,
			metal()
		)
		sign(
			f,
			n .. "_Label",
			7,
			1.6,
			at(42.25, bm, 2),
			inward,
			{ { text = bay[2] :: string, cap = 1.2 } }
		)
	end

	-- Hero island: two-step dais with a light ring, the 8x rifle on two pylons,
	-- side-on to the entry so it reads in profile from the hub.
	cylinder(f, "HeroRing", CX, 0, 13.3, -0.5, 0.25, neonWhite, glow())
	cylinder(f, "HeroDais", CX, 0, 13, 0, 0.8, C.concrete)
	cylinder(f, "HeroDaisTop", CX, 0, 10, 0.8, 1.6, C.weaponsWall)
	local hero = CFrame.fromMatrix(Vector3.new(CX, 12.5, 0), Vector3.new(0, 0, 1), Vector3.yAxis)
	rifle(f, "HeroRifle", hero, 28)
	box(f, "HeroPylonN", CX - 0.6, CX + 0.6, 1.6, 11.4, -7.6, -6.4, C.steel, metal())
	box(f, "HeroPylonS", CX - 0.6, CX + 0.6, 1.6, 10.6, 8.4, 9.6, C.steel, metal())
	box(f, "HeroLectern", CX - 12, CX - 10.4, 0.8, 2.8, -4.5, 4.5, C.steel, metal())
	sign(f, "HeroLabel", 9, 1.8, Vector3.new(CX - 12.2, 1.8, 0), WEST, {
		{ text = "OVERWRITE", cap = 1.5 },
	})

	-- Ceiling: ribs from every pier to a glazed lantern (the light well) on a
	-- roof ring. 22.5 degree pieces keep the part count down.
	for i, b in PIERS do
		make(
			f,
			"Rib_" .. i,
			Vector3.new(1.5, 3, 25),
			CFrame.lookAt(at(28.5, b, 28.5), Vector3.new(CX, 28.5, 0)),
			C.concrete
		)
	end
	for k = 0, 15 do
		local b0 = k * 22.5
		arcPiece(
			f,
			"Roof_" .. k,
			14,
			45,
			b0,
			b0 + 22.5,
			WALL_TOP,
			WALL_TOP + 1,
			C.concrete,
			nil,
			CX,
			0
		)
		arcPiece(f, "Lantern_" .. k, 14, 16, b0, b0 + 22.5, WALL_TOP, 37, C.weaponsWall, nil, CX, 0)
	end
	cylinder(f, "LanternGlass", CX, 0, 16.5, 37, 37.6, C.glass, { transparency = 0.5 })

	-- Wayfinding back out (on the entry lintel, facing in).
	sign(
		f,
		"ExitSign",
		16,
		3,
		Vector3.new(95.3, 19.5, 0),
		EAST,
		{ { text = "<  EXIT TO HUB", cap = 2 } }
	)
end

local function buildLocker(f: Instance)
	-- Apse: straight cheeks, then a half-round back (R16 about x 182), roof at 20.
	box(f, "Floor", 174, 201, -2, 0, -19, 19, C.weaponsFloor)
	box(f, "CarpetFront", 176, 182, -0.5, 0.06, -14, 14, lockerFloor)
	cylinder(f, "CarpetRound", 182, 0, 14, -0.5, 0.06, lockerFloor)
	box(f, "CheekN", 174, 182, 0, WALL_TOP, -19, -16, C.locker)
	box(f, "CheekS", 174, 182, 0, WALL_TOP, 16, 19, C.locker)
	arc(f, "ApseWall", 16, 18, 0, 180, 0, 21, C.locker, nil, nil, 182, 0)
	box(f, "Roof", 174, 201, 20, 21, -19, 19, C.weaponsWall)
	box(f, "CoveLight", 175, 175.6, 19.5, 19.8, -15, 15, neonWhite, glow())

	-- Back-lit panel, brass pedestal and a ~5-tall mannequin facing the drum.
	box(f, "BackPanel", 196.6, 197, 2, 15, -4.5, 4.5, C.white)
	cylinder(f, "Pedestal", 188, 0, 4, 0, 1.2, C.brass, metal())
	cylinder(f, "PedestalRing", 188, 0, 4.3, 0, 0.25, neonWhite, glow())
	local m = CFrame.fromMatrix(Vector3.new(188, 1.2, 0), Vector3.new(0, 0, -1), Vector3.yAxis)
	lbox(f, "MannequinLegs", m, -1, 1, 0, 2, -0.5, 0.5, mannequin)
	lbox(f, "MannequinTorso", m, -1, 1, 2, 4, -0.5, 0.5, mannequin)
	lbox(f, "MannequinArmL", m, -2, -1, 2, 4, -0.5, 0.5, mannequin)
	lbox(f, "MannequinArmR", m, 1, 2, 2, 4, -0.5, 0.5, mannequin)
	lbox(f, "MannequinHead", m, -0.5, 0.5, 4, 5, -0.5, 0.5, mannequin)

	-- Loadout terminals on either side of the pedestal, facing the axis.
	for _, s in { -1, 1 } do
		local tag = s < 0 and "N" or "S"
		local z = s * 10
		box(f, "Terminal" .. tag, 182.5, 185.5, 0, 3.4, z - 0.8, z + 0.8, C.steel, metal())
		local facing = Vector3.new(0, 0, -s)
		local sp = Vector3.new(184, 4.3, z - s * 0.2)
		make(
			f,
			"TerminalScreen" .. tag,
			Vector3.new(2.6, 1.8, 0.2),
			CFrame.lookAt(sp, sp + facing) * CFrame.Angles(math.rad(-20), 0, 0),
			C.screen
		)
		sign(f, "TerminalLabel" .. tag, 5, 1.2, Vector3.new(184, 6, z - s * 0.2), facing, {
			{ text = "LOADOUT", cap = 1 },
		})
	end

	sign(f, "LockerSign", 16, 6, Vector3.new(177, 24.5, 0), WEST, {
		{ text = "LOCKER", cap = 3.5 },
		{ text = "LOADOUT + SKINS", cap = 1.2, color = Color3.fromRGB(190, 192, 196) },
	})
end

local wing = newSection("Wing_Weapons")
buildCorridor(wing)
buildArmoury(wing)
buildLocker(wing)
publish(wing)
