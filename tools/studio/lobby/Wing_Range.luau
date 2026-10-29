--!strict
-- Lobby greybox: the Range, in two places of the same Lobby place.
--   Wing_Range (hub side, south of the ring): a 1:4 ramp drops 8 studs into the
--     Range Lobby, a scaled-down copy of the real range (mini lanes behind glass
--     under a big RANGE title). The far wall holds the ENTER RANGE gate; its
--     sealed vestibule is RangeEnterTrigger, and RangeReturnPoint beside the
--     gate is where players reappear (phase 2 does the teleports).
--   RangeFar (z 1010-1298): the real range, a separate sealed building so guns
--     never mix with the hub. It fits RangeBuilder's yard with the firing line at
--     z 1214 (range-space z 0, downrange -Z). Arrival pad and EXIT TO LOBBY
--     alcove at the south (entrance) end.
-- Run it as a bundle: `python tools/studio/lobby/bundle.py Wing_Range`.

local FY = -8 -- Range Lobby floor, 8 below the hub
local FL = 1214 -- RangeFar firing line
local DAY = Color3.fromHex("DDE8F2") -- range daylight accents
local YELLOW = Color3.fromHex("E2B93B") -- safety paint
local BERM = Color3.fromHex("7A6A55")
local MUTED = Color3.fromRGB(190, 192, 196)
local ABILITY = Color3.fromRGB(214, 202, 202)

local function glow(): PartOpts
	return { material = Enum.Material.Neon, collide = false, shadow = false }
end

-- A wall or floor band `thick` wide along (x0, z0) -> (x1, z1), stretched by
-- `ext` at both ends so it overlaps its neighbours.
local function seg(
	f: Instance,
	name: string,
	x0: number,
	z0: number,
	x1: number,
	z1: number,
	y0: number,
	y1: number,
	thick: number,
	color: Color3,
	ext: number
): Part
	local dx, dz = x1 - x0, z1 - z0
	local len = math.sqrt(dx * dx + dz * dz)
	local yc = (y0 + y1) / 2
	local mid = Vector3.new((x0 + x1) / 2, yc, (z0 + z1) / 2)
	local cf = CFrame.lookAt(mid, Vector3.new(x1, yc, z1))
	return make(f, name, Vector3.new(thick, y1 - y0, len + 2 * ext), cf, color)
end

-- Invisible, non-colliding marker for phase 2 (teleport points and triggers).
local function marker(
	f: Instance,
	name: string,
	x0: number,
	x1: number,
	y0: number,
	y1: number,
	z0: number,
	z1: number,
	facing: Vector3?,
	touch: boolean
): Part
	local p = box(
		f,
		name,
		x0,
		x1,
		y0,
		y1,
		z0,
		z1,
		C.white,
		{ transparency = 1, collide = false, shadow = false }
	)
	if facing then
		p.CFrame = CFrame.lookAt(p.Position, p.Position + facing)
	end
	p.CanTouch = touch
	return p
end

-- Hub side -------------------------------------------------------------------------

local function buildDescent(f: Instance)
	box(f, "DescentLip", -14, 14, -2, 0, 70, 72, C.ringFloor)
	ramp(f, "Ramp", Vector3.new(0, 0, 72), Vector3.new(0, FY, 104), 28, 6, C.range)
	for _, x in { -5, 5 } do
		ramp(
			f,
			"RampLine",
			Vector3.new(x, 0.06, 72),
			Vector3.new(x, FY + 0.06, 104),
			0.4,
			0.2,
			C.white,
			{ collide = false, shadow = false }
		)
	end
	for _, s in { -1, 1 } do
		box(f, "DescentWall", s * 14, s * 16, FY - 2, 17, 70, 104, C.concrete)
		-- A daylight strip on each wall, 3 above the ramp, pulls you down.
		local a, b = Vector3.new(s * 13.85, 3, 72), Vector3.new(s * 13.85, FY + 3, 104)
		make(
			f,
			"RampGlow",
			Vector3.new(0.3, 0.3, (b - a).Magnitude),
			CFrame.lookAt((a + b) / 2, b),
			DAY,
			glow()
		)
		box(f, "DescentSlot", s * 6 - 0.4, s * 6 + 0.4, 15.85, 16, 70, 103, DAY, glow())
	end
	box(f, "DescentCeiling", -16, 16, 16, 17, 66.7, 104, C.concrete)
	-- Two steel portal frames give the descent a rhythm (24 wide, 14 high).
	for _, z in { 82, 96 } do
		for _, s in { -1, 1 } do
			box(f, "FrameJamb", s * 12, s * 14, FY - 2, 16, z - 1, z + 1, C.steel)
		end
		box(f, "FrameHead", -12, 12, 14, 16, z - 1, z + 1, C.steel)
	end
end

-- The Range Lobby: x -64..64, z 104..200, 28 clear under a beamed ceiling, with
-- chamfered north corners and soffits that step the side aisles down to 22.
local function buildHall(f: Instance)
	box(f, "HallFloor", -64, 64, FY - 2, FY, 104, 200, C.range)
	box(f, "HallRoof", -64, 64, 20, 21, 104, 200, C.concrete)
	box(f, "Lintel", -14, 14, 16, 21, 104, 106, C.concrete)
	for _, s in { -1, 1 } do
		box(f, "NorthWall", s * 14, s * 36, FY - 2, 21, 104, 106, C.concrete)
		seg(f, "Chamfer", s * 36, 105, s * 63, 132, FY - 2, 21, 2, C.concrete, 1)
		box(f, "SideWall", s * 62, s * 64, FY - 2, 21, 131, 200, C.concrete)
		box(f, "Soffit", s * 56, s * 62, 14, 20, 132, 198, C.concrete)
		box(f, "SoffitCove", s * 55.7, s * 56, 13.7, 14, 132, 198, DAY, glow())
		for _, z in { 150, 172 } do
			box(f, "Pilaster", s * 60, s * 62, FY, 14, z - 1, z + 1, C.concrete)
		end
		box(f, "CeilingSlot", s * 40 - 0.4, s * 40 + 0.4, 19.85, 20, 108, 196, DAY, glow())
		box(
			f,
			"Bench",
			s * 25,
			s * 28,
			FY,
			FY + 1.5,
			150,
			170,
			C.oak,
			{ material = Enum.Material.Wood }
		)
	end
	for _, z in { 118, 140, 162, 184 } do
		box(f, "Beam", -62, 62, 18, 20, z - 0.75, z + 0.75, C.concrete)
	end
	-- The big south wall, cut for the gate (x -49..-37).
	box(f, "SouthWallW", -64, -49, FY - 2, 21, 198, 200, C.concrete)
	box(f, "SouthWallE", -37, 64, FY - 2, 21, 198, 200, C.concrete)
	box(f, "GateHead", -49, -37, FY + 10, 21, 198, 200, C.concrete)

	-- Floor paint: the hall's own firing line, and a guide band from the ramp
	-- foot to the gate.
	box(f, "HallFiringLine", -62, 62, FY, FY + 0.12, 125.4, 126, YELLOW)
	box(f, "GuideBand", -46, -40, FY, FY + 0.06, 120, 196, C.lanes)
	seg(f, "GuideLink", -5, 107, -43, 121, FY, FY + 0.09, 6, C.lanes, 0)
end

-- The hero: a 1:3-deep scale model of the real range behind glass, set in a
-- core block that carries the RANGE title.
local function buildMiniRange(f: Instance)
	for _, s in { -1, 1 } do
		box(f, "CoreWall", s * 22, s * 24, FY - 2, 20, 130, 198, C.concrete)
	end
	box(f, "Header", -24, 24, 4, 20, 130, 132, C.concrete)
	box(f, "Sill", -22, 22, FY, FY + 3, 130, 132, C.concrete)
	box(f, "ViewingGlass", -22, 22, FY + 3, 4, 130.8, 131.2, C.glass, {
		material = Enum.Material.Glass,
		transparency = 0.7,
		shadow = false,
	})
	for _, x in { -15, -9, -3, 3, 9, 15 } do
		box(f, "Mullion", x - 0.25, x + 0.25, FY + 3, 4, 130.7, 131.3, C.steel)
	end
	box(f, "MiniRoof", -22, 22, 4, 5, 132, 198, C.concrete)
	for _, x in { -12, 0, 12 } do
		box(f, "MiniSunSlot", x - 0.4, x + 0.4, 3.85, 4, 133, 197, DAY, glow())
	end
	box(f, "Rail", -22, 22, FY + 3.3, FY + 3.6, 127.4, 127.8, C.steel)
	for _, x in { -21.5, -7.5, 7.5, 21.5 } do
		box(f, "RailPost", x - 0.15, x + 0.15, FY, FY + 3.3, 127.45, 127.75, C.steel)
	end

	-- Inside: 7 lanes 6 wide, firing line, stalls, distance lines and boards at
	-- a third of the real distances, silhouettes on plywood, and a berm.
	local fz = 135
	for i = 1, 7, 2 do
		local cx = -24 + 6 * i
		box(f, "MiniLane", cx - 3, cx + 3, FY, FY + 0.06, 132, 196, C.lanes)
	end
	box(f, "MiniFiringLine", -21, 21, FY, FY + 0.1, fz - 0.3, fz + 0.3, YELLOW)
	box(f, "MiniCounter", -21, 21, FY, FY + 1.2, 132.6, 134, C.steel)
	for x = -15, 15, 6 do
		box(f, "MiniStall", x - 0.15, x + 0.15, FY, FY + 2.4, 132, 135.5, C.steel)
	end
	local boards =
		{ { 10, 1.1, 3.4 }, { 25, 1.3, 3.8 }, { 50, 1.5, 4.2 }, { 100, 1.7, 5 }, { 150, 1.9, 5.6 } }
	for _, b in boards do
		local d, cap, w = b[1], b[2], b[3]
		local z = fz + d / 3
		box(f, "MiniMark" .. d, -21, 21, FY, FY + 0.08, z - 0.15, z + 0.15, C.white)
		for _, s in { -1, 1 } do
			sign(
				f,
				"MiniBoard" .. d,
				w,
				cap * 1.6,
				Vector3.new(s * (21.8 - w / 2), 1.5, z),
				NORTH,
				{ { text = tostring(d), cap = cap, color = if d >= 100 then YELLOW else nil } }
			)
		end
	end
	for i, d in { 25, 50, 100, 150, 100, 50, 25 } do
		local cx = -24 + 6 * i
		local z = fz + d / 3 + 1
		box(
			f,
			"MiniBacker",
			cx - 1,
			cx + 1,
			FY,
			FY + 2.4,
			z + 0.1,
			z + 0.3,
			C.oak,
			{ material = Enum.Material.Wood }
		)
		box(f, "MiniTarget", cx - 0.6, cx + 0.6, FY, FY + 1.3, z - 0.1, z + 0.1, C.steel)
		box(f, "MiniTargetHead", cx - 0.3, cx + 0.3, FY + 1.3, FY + 1.75, z - 0.1, z + 0.1, C.steel)
	end
	-- Default wedge: low edge north, high edge against the back wall.
	make(
		f,
		"MiniBerm",
		Vector3.new(42, 4, 10),
		CFrame.new(0, FY + 2, 193),
		BERM,
		{ shape = Enum.PartType.Wedge }
	)

	sign(f, "RangeTitle", 42, 11, Vector3.new(0, 12.5, 129.8), NORTH, {
		{ text = "RANGE", cap = 5 },
		{ text = "PRACTICE LANES  ·  MOVEMENT  ·  ABILITIES", cap = 1.3, color = MUTED },
	})
	sign(
		f,
		"ScalePlaque",
		12,
		1.6,
		Vector3.new(0, FY + 1.6, 129.8),
		NORTH,
		{ { text = "SCALE MODEL  1:3", cap = 1 } }
	)
end

-- ENTER RANGE gate (west) with its sealed transfer vestibule, the return point
-- beside it, and a matching status screen (east).
local function buildGate(f: Instance)
	local x0, x1 = -49, -37
	box(f, "GateJambW", x0 - 2, x0, FY, FY + 12, 196, 198, C.steel)
	box(f, "GateJambE", x1, x1 + 2, FY, FY + 12, 196, 198, C.steel)
	box(f, "GateFrameHead", x0 - 2, x1 + 2, FY + 10, FY + 12, 196, 198, C.steel)
	box(f, "GateGlowW", x0 - 0.6, x0, FY, FY + 10.6, 195.8, 196, DAY, glow())
	box(f, "GateGlowE", x1, x1 + 0.6, FY, FY + 10.6, 195.8, 196, DAY, glow())
	box(f, "GateGlowTop", x0 - 0.6, x1 + 0.6, FY + 10, FY + 10.6, 195.8, 196, DAY, glow())
	sign(f, "EnterSign", 20, 5, Vector3.new(-43, FY + 15, 197.75), NORTH, {
		{ text = "ENTER RANGE", cap = 2.6 },
		{ text = "LANES  ·  MOVEMENT  ·  ABILITIES", cap = 1, color = MUTED },
	})

	box(f, "VestibuleFloor", x0 - 2, x1 + 2, FY - 2, FY, 200, 216, C.range)
	box(f, "VestibuleWallW", x0 - 2, x0, FY - 2, FY + 11, 198, 216, C.concrete)
	box(f, "VestibuleWallE", x1, x1 + 2, FY - 2, FY + 11, 198, 216, C.concrete)
	box(f, "VestibuleBack", x0 - 2, x1 + 2, FY - 2, FY + 11, 214, 216, C.concrete)
	box(f, "VestibuleRoof", x0 - 2, x1 + 2, FY + 10, FY + 11, 198, 216, C.concrete)
	box(f, "Threshold", x0, x1, FY, FY + 0.06, 200.2, 200.8, DAY, glow())
	sign(f, "TransferPanel", 10, 6, Vector3.new(-43, FY + 5, 213.8), NORTH, {
		{ text = "RANGE", cap = 1.6 },
		{ text = "STEP IN TO TRAVEL", cap = 1, color = MUTED },
	}, nil, C.screen)
	marker(f, "RangeEnterTrigger", x0, x1, FY, FY + 10, 198.2, 214, nil, true)

	-- Return point: west of the gate, facing back into the hall.
	box(f, "ReturnPad", -59, -53, FY, FY + 0.06, 183, 189, C.lanes)
	marker(f, "RangeReturnPoint", -58, -54, FY, FY + 1, 184, 188, NORTH, false)
	sign(
		f,
		"ReturnLabel",
		9,
		2,
		Vector3.new(-61.75, FY + 7, 186),
		EAST,
		{ { text = "RETURN POINT", cap = 1.2 } }
	)

	-- Status screen in a frame matching the gate.
	box(f, "StatusJambW", 35, 37, FY, FY + 12, 196, 198, C.steel)
	box(f, "StatusJambE", 49, 51, FY, FY + 12, 196, 198, C.steel)
	box(f, "StatusHead", 35, 51, FY + 10, FY + 12, 196, 198, C.steel)
	sign(f, "StatusScreen", 12, 10, Vector3.new(43, FY + 5, 197.75), NORTH, {
		{ text = "RANGE STATUS", cap = 1.6 },
		{ text = "LANES OPEN  7 / 7\nIN RANGE  0 / 30", cap = 1.2, color = MUTED },
	}, nil, C.screen)
end

-- The real range -------------------------------------------------------------------

local function buildFarShell(f: Instance)
	box(f, "Floor", -122, 122, -2, 0, 1010, 1298, C.range)
	for _, s in { -1, 1 } do
		box(f, "WallSide", s * 120, s * 122, -2, 38, 1010, 1298, C.concrete)
		for z = 1040, 1240, 40 do
			box(f, "Pilaster", s * 118, s * 120, 0, 36, z - 1, z + 1, C.concrete)
		end
	end
	box(f, "WallNorth", -122, 122, -2, 38, 1010, 1012, C.concrete)
	box(f, "WallSouth", -122, 122, -2, 38, 1296, 1298, C.concrete)
	-- Roof with three north-south sun slots over lanes 2, 4 and 6.
	box(f, "RoofN", -122, 122, 36, 37.5, 1010, 1050, C.concrete)
	box(f, "RoofS", -122, 122, 36, 37.5, 1200, 1298, C.concrete)
	local edges = { -122, -26, -22, -2, 2, 22, 26, 122 }
	for i = 1, #edges, 2 do
		box(f, "RoofBand", edges[i], edges[i + 1], 36, 37.5, 1050, 1200, C.concrete)
	end
	for z = 1060, 1240, 36 do
		box(f, "Truss", -120, 120, 33, 36, z - 0.75, z + 0.75, C.steel)
	end
	sign(f, "Title", 84, 11, Vector3.new(0, 29.5, 1012.25), SOUTH, {
		{ text = "PRACTICE RANGE", cap = 7 },
		{ text = "LANES  10 · 25 · 50 · 100 · 150", cap = 1.8, color = MUTED },
	})
end

-- RangeBuilder's lanes: 7 x 12 wide, 170 long, markers, berm, shooter strip.
local function buildFarLanes(f: Instance)
	local z0 = FL - 170
	for i = 1, 7, 2 do
		local cx = -48 + 12 * i
		box(f, "Lane" .. i, cx - 6, cx + 6, 0, 0.06, z0, FL, C.lanes)
	end
	for k = 0, 7 do
		local x = -42 + 12 * k
		local w = if k == 0 or k == 7 then 0.5 else 0.3
		box(f, "LaneLine", x - w / 2, x + w / 2, 0, 0.1, z0, FL, C.white)
	end
	box(f, "FiringLine", -42, 42, 0, 0.16, FL - 0.5, FL + 0.5, YELLOW)
	-- Big boards hang over the lanes (staggered so they don't hide each other
	-- from the firing line); small ones sit on posts at the lane edges.
	local big = {
		{ 10, 2, 0, 22 },
		{ 25, 2.6, -20, 22 },
		{ 50, 3.5, 20, 24 },
		{ 100, 5, -20, 24 },
		{ 150, 6.5, 20, 8 },
	}
	for _, m in big do
		local d, cap, x, base = m[1], m[2], m[3], m[4]
		local z = FL - d
		local text = tostring(d)
		local h = cap * 1.7
		box(f, "MarkLine" .. d, -42, 42, 0, 0.14, z - 0.2, z + 0.2, C.white)
		sign(
			f,
			"Marker" .. d,
			cap * (#text * 0.95 + 0.8),
			h,
			Vector3.new(x, base + h / 2, z),
			SOUTH,
			{
				{ text = text, cap = cap, color = if d >= 100 then YELLOW else nil },
			}
		)
		for _, s in { -1, 1 } do
			box(f, "MarkerPost", s * 44.3, s * 44.7, 0, 5, z - 0.2, z + 0.2, C.steel)
			sign(
				f,
				"MarkerSmall" .. d,
				3.4,
				1.9,
				Vector3.new(s * 44.5, 6, z),
				SOUTH,
				{ { text = text, cap = 1.2 } }
			)
		end
	end
	box(f, "Berm", -48, 48, 0, 14, FL - 184, FL - 178, BERM)
	make(
		f,
		"BermSlope",
		Vector3.new(96, 14, 8),
		CFrame.new(0, 7, FL - 174) * CFrame.Angles(0, math.pi, 0),
		BERM,
		{ shape = Enum.PartType.Wedge }
	)
	for i, d in { 10, 25, 50, 150, 100, 50, 25 } do
		local cx = -48 + 12 * i
		local z = FL - d
		box(f, "Target", cx - 0.9, cx + 0.9, 0, 3.8, z - 0.2, z + 0.2, C.steel)
		box(f, "TargetHead", cx - 0.6, cx + 0.6, 3.8, 5, z - 0.2, z + 0.2, C.steel)
	end
	box(f, "LongPlatform", 32, 40, 0, 6, FL - 104, FL - 96, C.concrete)
	box(f, "LongPlatformEdge", 32, 40, 6, 6.12, FL - 96.4, FL - 96, YELLOW)
	for _, s in { -1, 1 } do
		box(f, "LaneWall", s * 46, s * 48, 0, 4, z0, FL - 8, C.concrete)
	end

	box(f, "ShooterStrip", -42, 42, 0, 0.06, FL + 0.5, FL + 30, C.deck)
	for k = 0, 7 do
		local x = -42 + 12 * k
		box(f, "Stall", x - 0.3, x + 0.3, 0, 7, FL + 0.5, FL + 6.5, C.steel)
	end
	for i = 1, 7 do
		sign(
			f,
			"LaneNumber",
			4,
			2.4,
			Vector3.new(-48 + 12 * i, 9, FL + 3),
			SOUTH,
			{ { text = tostring(i), cap = 1.5 } }
		)
	end
end

-- Cover + ability yard (west) and movement course (east), as in RangeBuilder.
local function buildFarYards(f: Instance)
	box(f, "CoverYard", -108, -52, 0, 0.06, FL - 60, FL + 4, C.yard)
	box(f, "CoverLine", -108, -52, 0, 0.12, FL - 0.2, FL + 0.2, YELLOW)
	box(
		f,
		"ThinWall",
		-81,
		-71,
		0,
		9,
		FL - 20.15,
		FL - 19.85,
		C.oak,
		{ material = Enum.Material.Wood }
	)
	box(f, "SolidWall", -99, -89, 0, 9, FL - 24, FL - 22.5, C.concrete)
	box(f, "LowCover", -66, -58, 0, 3.6, FL - 26, FL - 24.5, C.concrete)
	for _, x in { -100, -80, -60 } do
		box(f, "Pillar", x - 1.5, x + 1.5, 0, 10, FL - 11.5, FL - 8.5, C.concrete)
	end
	box(f, "AbilityYard", -108, -52, 0, 0.06, FL - 150, FL - 66, ABILITY)
	sign(
		f,
		"CoverSign",
		22,
		4,
		Vector3.new(-80, 9, FL + 8),
		SOUTH,
		{ { text = "COVER + ABILITY YARD", cap = 1.8 } }
	)
	sign(
		f,
		"AbilitySign",
		18,
		3,
		Vector3.new(-80, 6, FL - 64),
		SOUTH,
		{ { text = "ABILITY TEST SPACE", cap = 1.4 } }
	)

	box(f, "Course", 51, 109, 0, 0.06, FL - 191, FL + 39, C.course)
	box(f, "Track", 57, 67, 0, 0.1, FL - 120, FL + 38, C.lanes)
	for i, h in { 2, 3.5, 5, 6.5 } do
		local z = FL - 4 - i * 9
		box(f, "JumpBox", 77, 83, 0, h, z - 3, z + 3, C.concrete)
	end
	-- Gap jumps of 6 (walk), 10 (sprint) and 13 (slide jump).
	for _, p in
		{ { FL - 30, FL - 20 }, { FL - 44, FL - 36 }, { FL - 62, FL - 54 }, { FL - 83, FL - 75 } }
	do
		box(f, "GapPlatform", 94, 102, 0, 3, p[1], p[2], C.concrete)
	end
	for i = 0, 2 do
		local wz = FL - 120 - i * 14
		box(f, "CrouchWall", 75, 85, 0, 3.2, wz - 0.6, wz + 0.6, C.concrete)
	end
	sign(
		f,
		"CourseSign",
		22,
		4,
		Vector3.new(80, 9, FL + 44),
		SOUTH,
		{ { text = "MOVEMENT COURSE", cap = 1.8 } }
	)
end

-- Entrance end: a low canopy over the arrival pad (compress, then the range
-- opens up), the EXIT TO LOBBY alcove (east) and a guide niche (west).
local function buildFarArrival(f: Instance)
	box(f, "Canopy", -50, 50, 16, 18, 1262, 1296, C.concrete)
	box(f, "CanopyCove", -50, 50, 15.7, 16, 1262, 1262.4, DAY, glow())
	for _, s in { -1, 1 } do
		box(f, "CanopyColumn", s * 48, s * 50, 0, 16, 1262, 1264, C.concrete)
	end
	for _, w in { { -32, "<  COVER YARD" }, { 0, "LANES  1 - 7" }, { 32, "MOVEMENT  >" } } do
		sign(f, "Wayfinding", 20, 4, Vector3.new(w[1] :: number, 12, 1263), SOUTH, {
			{ text = w[2] :: string, cap = 1.8 },
		})
	end

	box(f, "ArrivalPad", -7, 7, 0, 0.08, 1271, 1285, C.deck)
	box(f, "ArrivalRingN", -7.6, 7.6, 0, 0.1, 1270.4, 1271, DAY, glow())
	box(f, "ArrivalRingS", -7.6, 7.6, 0, 0.1, 1285, 1285.6, DAY, glow())
	box(f, "ArrivalRingW", -7.6, -7, 0, 0.1, 1271, 1285, DAY, glow())
	box(f, "ArrivalRingE", 7, 7.6, 0, 0.1, 1271, 1285, DAY, glow())
	marker(f, "RangeArrivalPoint", -2, 2, 0, 1, 1276, 1280, NORTH, false)

	local x0, x1 = 26, 38
	box(f, "ExitWallW", x0 - 2, x0, 0, 12, 1282, 1296, C.concrete)
	box(f, "ExitWallE", x1, x1 + 2, 0, 12, 1282, 1296, C.concrete)
	box(f, "ExitRoof", x0 - 2, x1 + 2, 10, 12, 1282, 1296, C.concrete)
	box(f, "ExitGlowW", x0 - 0.6, x0, 0, 10.6, 1281.8, 1282, DAY, glow())
	box(f, "ExitGlowE", x1, x1 + 0.6, 0, 10.6, 1281.8, 1282, DAY, glow())
	box(f, "ExitGlowTop", x0 - 0.6, x1 + 0.6, 10, 10.6, 1281.8, 1282, DAY, glow())
	sign(
		f,
		"ExitSign",
		14,
		3.2,
		Vector3.new(32, 14, 1281.75),
		NORTH,
		{ { text = "EXIT TO LOBBY", cap = 2.2 } }
	)
	sign(f, "ExitPanel", 10, 6, Vector3.new(32, 5, 1295.8), NORTH, {
		{ text = "LOBBY", cap = 1.6 },
		{ text = "STEP IN TO RETURN", cap = 1, color = MUTED },
	}, nil, C.screen)
	marker(f, "RangeExitTrigger", x0, x1, 0, 10, 1282.2, 1296, nil, true)

	box(f, "GuideWallW", -40, -38, 0, 12, 1288, 1296, C.concrete)
	box(f, "GuideWallE", -26, -24, 0, 12, 1288, 1296, C.concrete)
	box(f, "GuideRoof", -40, -24, 10, 12, 1288, 1296, C.concrete)
	sign(f, "GuideBoard", 12, 9, Vector3.new(-32, 5, 1295.8), NORTH, {
		{ text = "RANGE GUIDE", cap = 1.4 },
		{
			text = "AHEAD: LANES, DUMMIES 10-150\nLEFT: COVER + ABILITIES\nRIGHT: MOVEMENT COURSE",
			cap = 1,
			color = MUTED,
		},
	}, nil, C.screen)
end

-- The old sunken range shell is replaced by RangeFar.
local old = greyboxRoot():FindFirstChild("RangeShell")
if old then
	old:Destroy()
end

local wing = newSection("Wing_Range")
buildDescent(wing)
buildHall(wing)
buildMiniRange(wing)
buildGate(wing)
publish(wing)

local far = newSection("RangeFar")
buildFarShell(far)
buildFarLanes(far)
buildFarYards(far)
buildFarArrival(far)
publish(far)
