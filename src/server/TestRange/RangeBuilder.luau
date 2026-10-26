--!strict
-- Builds the practice range from code (so it lives in git and only exists
-- while test mode is on): an open-air concrete yard with shooting lanes and
-- distance markers, a cover section with a shoot-through ThinWall, and a
-- movement course. Plain and realistic (vault/02 Art/Art Direction.md, new
-- direction): concrete, painted lines, simple signs, no neon.
--
-- Range space: X right, Y up from the floor, -Z downrange from the firing line.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Movement = require(ReplicatedStorage.Shared.Config.Movement)
local TestRange = require(ReplicatedStorage.Shared.Config.TestRange)

local RangeBuilder = {}

local FLOOR = Color3.fromHex("8C8D8A") -- weathered concrete
local LANE_A = Color3.fromHex("979894")
local LANE_B = Color3.fromHex("8F908C")
local WALL = Color3.fromHex("B4B2AC") -- concrete block
local BLOCK = Color3.fromHex("A19F99")
local METAL = Color3.fromHex("54575B")
local SIGN = Color3.fromHex("2E3033")
local PAINT = Color3.fromHex("ECECE8") -- white line paint
local YELLOW = Color3.fromHex("E2B93B") -- safety yellow
local RED = Color3.fromHex("C0453A")
local WOOD = Color3.fromHex("B88E5F") -- plywood
local TEXT = Color3.fromHex("F2F2F2")
local MUTED = Color3.fromHex("B9BCC0")

-- Yard bounds (range space).
local MIN_X, MAX_X = -110, 110
local MIN_Z, MAX_Z = -196, 46
local WALL_HEIGHT = 12

export type Built = {
	root: Model,
	spawn: SpawnLocation,
	toWorld: (Vector3) -> CFrame,
}

local origin = CFrame.new(TestRange.ORIGIN)
-- Signs show their text on the Front (-Z) face; this turns one to face +Z,
-- toward the spawn and the firing line.
local TO_SPAWN = CFrame.Angles(0, math.pi, 0)

local function at(x: number, y: number, z: number): CFrame
	return origin * CFrame.new(x, y, z)
end

local function block(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Concrete
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A painted line: no collision, never a wall for bullets.
local function paint(parent: Instance, size: Vector3, cf: CFrame, color: Color3?)
	local p = block(parent, "Paint", size, cf, color or PAINT, Enum.Material.SmoothPlastic)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function label(
	gui: Instance,
	text: string,
	size: UDim2,
	pos: UDim2,
	font: Enum.Font,
	color: Color3
): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.Font = font
	l.TextScaled = true
	l.TextColor3 = color
	l.RichText = true
	l.Text = text
	l.Parent = gui
	return l
end

local function surface(part: BasePart, face: Enum.NormalId, pps: number?): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pps or 40
	gui.LightInfluence = 1
	gui.MaxDistance = 400
	gui.Parent = part
	return gui
end

-- A dark sign with a title and body text facing `cf`'s look direction, and a
-- painted stripe along its top in `accent`.
local function sign(
	parent: Instance,
	name: string,
	size: Vector2,
	cf: CFrame,
	title: string,
	body: string?,
	accent: Color3?
): Part
	local p = block(parent, name, Vector3.new(size.X, size.Y, 0.3), cf, SIGN, Enum.Material.Metal)
	p.CanQuery = false
	paint(parent, Vector3.new(size.X, 0.14, 0.32), cf * CFrame.new(0, size.Y / 2 - 0.07, 0), accent)
	local gui = surface(p, Enum.NormalId.Front, 50)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.05, 0)
	pad.PaddingRight = UDim.new(0.05, 0)
	pad.PaddingTop = UDim.new(0.1, 0)
	pad.PaddingBottom = UDim.new(0.08, 0)
	pad.Parent = gui
	if body then
		label(
			gui,
			title,
			UDim2.fromScale(1, 0.3),
			UDim2.fromScale(0, 0),
			Enum.Font.GothamBold,
			TEXT
		)
		local b = label(
			gui,
			body,
			UDim2.fromScale(1, 0.6),
			UDim2.fromScale(0, 0.38),
			Enum.Font.Gotham,
			MUTED
		)
		b.TextYAlignment = Enum.TextYAlignment.Top
		b.TextWrapped = true
	else
		label(gui, title, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Enum.Font.GothamBold, TEXT)
	end
	return p
end

-- Text painted on the floor, readable from the firing line (looking -Z).
local function floorText(
	parent: Instance,
	text: string,
	size: Vector2,
	x: number,
	z: number,
	color: Color3
)
	-- A Top-face SurfaceGui's "up" is the part's -X, so turn the plate a
	-- quarter so the text's top points downrange (-Z).
	local p = block(
		parent,
		"FloorText",
		Vector3.new(size.Y, 0.05, size.X),
		at(x, 0.08, z) * CFrame.Angles(0, -math.pi / 2, 0),
		FLOOR
	)
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	local gui = surface(p, Enum.NormalId.Top, 30)
	label(gui, text, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Enum.Font.GothamBold, color)
end

-- Yard ---------------------------------------------------------------------------

local function buildYard(root: Model)
	local yard = folder(root, "Yard")
	local w, d = MAX_X - MIN_X, MAX_Z - MIN_Z
	local cx, cz = (MIN_X + MAX_X) / 2, (MIN_Z + MAX_Z) / 2
	block(yard, "Floor", Vector3.new(w, 1, d), at(cx, -0.5, cz), FLOOR)

	-- Perimeter: block walls with a coping on top and a pillar every 24 studs.
	local sides = {
		{ Vector3.new(w + 4, 0, 0), Vector3.new(cx, 0, MIN_Z - 1), Vector3.new(0, 0, 1) },
		{ Vector3.new(w + 4, 0, 0), Vector3.new(cx, 0, MAX_Z + 1), Vector3.new(0, 0, -1) },
		{ Vector3.new(0, 0, d), Vector3.new(MIN_X - 1, 0, cz), Vector3.new(1, 0, 0) },
		{ Vector3.new(0, 0, d), Vector3.new(MAX_X + 1, 0, cz), Vector3.new(-1, 0, 0) },
	}
	for i, side in sides do
		local length = side[1].Magnitude
		local alongX = side[1].X > 0
		local function sized(len: number, h: number, t: number): Vector3
			return if alongX then Vector3.new(len, h, t) else Vector3.new(t, h, len)
		end
		local c = side[2]
		local inward = side[3]
		block(yard, "Wall" .. i, sized(length, WALL_HEIGHT, 2), at(c.X, WALL_HEIGHT / 2, c.Z), WALL)
		block(
			yard,
			"Coping",
			sized(length, 0.5, 2.6),
			at(c.X, WALL_HEIGHT + 0.25, c.Z),
			BLOCK,
			Enum.Material.Concrete
		)
		local pillars = math.floor(length / 24)
		for s = 1, pillars do
			local offset = -length / 2 + s * length / (pillars + 1)
			local face = c + inward * 1.2
			local pos = if alongX
				then face + Vector3.new(offset, 0, 0)
				else face + Vector3.new(0, 0, offset)
			block(
				yard,
				"Pillar",
				sized(1.6, WALL_HEIGHT, 0.6),
				at(pos.X, WALL_HEIGHT / 2, pos.Z),
				BLOCK
			)
		end
	end
end

-- Lanes ----------------------------------------------------------------------------

local function laneHalfWidth(): number
	return TestRange.LANES * TestRange.LANE_WIDTH / 2
end

local function buildLanes(root: Model)
	local lanes = folder(root, "Lanes")
	local half = laneHalfWidth()
	local length = TestRange.LANE_LENGTH
	for i = 1, TestRange.LANES do
		local x = -half + (i - 0.5) * TestRange.LANE_WIDTH
		block(
			lanes,
			"Lane" .. i,
			Vector3.new(TestRange.LANE_WIDTH, 0.1, length),
			at(x, 0.05, -length / 2),
			if i % 2 == 0 then LANE_A else LANE_B
		)
	end
	for i = 0, TestRange.LANES do
		local x = -half + i * TestRange.LANE_WIDTH
		local edge = i == 0 or i == TestRange.LANES
		paint(
			lanes,
			Vector3.new(if edge then 0.35 else 0.18, 0.06, length),
			at(x, 0.12, -length / 2)
		)
	end

	-- Firing line.
	paint(lanes, Vector3.new(half * 2, 0.06, 0.5), at(0, 0.12, 0), YELLOW)
	floorText(lanes, "FIRING LINE", Vector2.new(20, 2.6), 0, 2.2, YELLOW)

	-- Distance markers: a line across the lanes, the number on the floor and a
	-- sign on a post either side.
	for _, distance in TestRange.MARKERS do
		local z = -distance
		paint(lanes, Vector3.new(half * 2, 0.06, 0.3), at(0, 0.12, z))
		for i = 1, TestRange.LANES do
			local x = -half + (i - 0.5) * TestRange.LANE_WIDTH
			floorText(lanes, tostring(distance), Vector2.new(5, 2.5), x, z + 2, PAINT)
		end
		for _, side in { -1, 1 } do
			local x = side * (half + 2.5)
			block(
				lanes,
				"MarkerPost",
				Vector3.new(0.3, 6, 0.3),
				at(x, 3, z),
				METAL,
				Enum.Material.Metal
			)
			sign(
				lanes,
				"Marker" .. distance,
				Vector2.new(3.4, 1.9),
				at(x, 6.6, z) * TO_SPAWN,
				string.format("%d", distance),
				nil,
				if distance >= 100 then YELLOW else PAINT
			)
		end
	end

	-- Earth berm behind the targets, and the long-range platform.
	local backZ = -length - 4
	block(
		lanes,
		"Berm",
		Vector3.new(half * 2 + 10, 14, 6),
		at(0, 7, backZ),
		Color3.fromHex("7A6A55"),
		Enum.Material.Ground
	)
	for _, spot in TestRange.DUMMIES do
		local y = spot.y or 0
		if y > 0 then
			local pos = Vector3.new(spot.x, y / 2, -spot.distance)
			block(lanes, "Platform", Vector3.new(8, y, 8), at(pos.X, pos.Y, pos.Z), BLOCK)
			paint(lanes, Vector3.new(8.05, 0.12, 0.3), at(pos.X, y - 0.05, pos.Z + 3.9), YELLOW)
		end
	end
end

-- Cover section (left) -----------------------------------------------------------

local function buildCover(root: Model)
	local cover = folder(root, "Cover")
	block(cover, "CoverFloor", Vector3.new(56, 0.1, 64), at(-80, 0.05, -28), LANE_B)
	paint(cover, Vector3.new(56, 0.06, 0.4), at(-80, 0.12, 0), YELLOW)

	-- ThinWall: a plywood sheet that guns with ThinWall penetration shoot through.
	local thin = block(
		cover,
		"ThinWall",
		Vector3.new(10, 9, 0.3),
		at(-78, 4.5, -23),
		WOOD,
		Enum.Material.WoodPlanks
	)
	CollectionService:AddTag(thin, Combat.THIN_WALL_TAG)
	for _, x in { -83.1, -72.9 } do
		block(
			cover,
			"Post",
			Vector3.new(0.35, 9.4, 0.35),
			at(x, 4.7, -23),
			METAL,
			Enum.Material.Metal
		)
	end

	-- Solid wall: concrete, blocks everything.
	block(cover, "SolidWall", Vector3.new(10, 9, 1.5), at(-94, 4.5, -23), WALL)

	-- Low cover: the head shows above it from the firing line.
	block(cover, "LowCover", Vector3.new(8, 3.6, 1.5), at(-62, 1.8, -25), BLOCK)

	-- Pillars to strafe-peek around.
	for _, x in { -70, -86, -102 } do
		block(cover, "Pillar", Vector3.new(3, 10, 3), at(x, 5, -10), WALL)
	end

	sign(
		cover,
		"ThinWallSign",
		Vector2.new(9, 3),
		at(-78, 11.6, -23) * TO_SPAWN,
		"PLYWOOD",
		"Rifles shoot through it",
		WOOD
	)
	sign(
		cover,
		"SolidWallSign",
		Vector2.new(9, 3),
		at(-94, 11.6, -23) * TO_SPAWN,
		"CONCRETE",
		"Stops every bullet",
		PAINT
	)
	sign(
		cover,
		"LowCoverSign",
		Vector2.new(8, 2.8),
		at(-62, 6.2, -25) * TO_SPAWN,
		"LOW COVER",
		"Aim for the head",
		YELLOW
	)
end

-- Movement course (right) ----------------------------------------------------------

local function wedge(parent: Instance, size: Vector3, cf: CFrame): WedgePart
	local p = Instance.new("WedgePart")
	p.Name = "Ramp"
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = BLOCK
	p.Material = Enum.Material.Concrete
	p.Parent = parent
	return p
end

local function buildMovement(root: Model)
	local course = folder(root, "Movement")
	block(course, "CourseFloor", Vector3.new(58, 0.1, 230), at(80, 0.05, -76), LANE_B)

	-- Sprint and slide strip with a tick every 10 studs (slide distance).
	local trackX = 62
	block(course, "Track", Vector3.new(10, 0.06, 160), at(trackX, 0.13, -40), LANE_A)
	for _, x in { trackX - 5, trackX + 5 } do
		paint(course, Vector3.new(0.25, 0.06, 160), at(x, 0.18, -40))
	end
	for i = 0, 16 do
		local z = 40 - i * 10
		paint(
			course,
			Vector3.new(10, 0.06, 0.2),
			at(trackX, 0.18, z),
			if i % 5 == 0 then YELLOW else PAINT
		)
		if i > 0 and i % 2 == 0 then
			floorText(course, tostring(i * 10), Vector2.new(4, 2), trackX, z + 1.6, PAINT)
		end
	end
	sign(
		course,
		"TrackSign",
		Vector2.new(11, 3.6),
		at(trackX, 7.5, 14) * TO_SPAWN,
		"SPRINT & SLIDE",
		"Shift to sprint, C while sprinting to slide. Jump out of a slide to keep its speed.",
		PAINT
	)

	-- Jump boxes, rising toward the jump height.
	local boxX = 80
	local heights = { 2, 3.5, 5, 6.5 }
	for i, h in heights do
		local z = -4 - i * 9
		block(course, "JumpBox", Vector3.new(6, h, 6), at(boxX, h / 2, z), BLOCK)
		paint(course, Vector3.new(6.05, 0.1, 0.3), at(boxX, h - 0.04, z + 2.9), YELLOW)
		floorText(course, string.format("%.1f", h), Vector2.new(4, 2), boxX, z + 4.2, PAINT)
	end
	sign(
		course,
		"JumpSign",
		Vector2.new(9, 3),
		at(boxX, 8.5, 4) * TO_SPAWN,
		"JUMP",
		string.format("Box heights in studs. A jump reaches %.1f.", Movement.JUMP_HEIGHT),
		PAINT
	)

	-- Gap jumps: walk, sprint and slide-jump distances.
	local gapX = 98
	local platformH = 3
	local z = -30
	wedge(
		course,
		Vector3.new(8, platformH, 10),
		at(gapX, platformH / 2, z + 5) * CFrame.Angles(0, math.pi, 0)
	)
	local gaps = { { 0, "" }, { 6, "WALK" }, { 10, "SPRINT" }, { 13, "SLIDE JUMP" } }
	for _, gap in gaps do
		z -= gap[1]
		block(
			course,
			"GapPlatform",
			Vector3.new(8, platformH, 8),
			at(gapX, platformH / 2, z - 4),
			BLOCK
		)
		if gap[1] > 0 then
			paint(course, Vector3.new(8.05, 0.1, 0.3), at(gapX, platformH - 0.04, z - 0.15), YELLOW)
			floorText(
				course,
				string.format("%d · %s", gap[1], gap[2]),
				Vector2.new(8, 2),
				gapX,
				z + gap[1] / 2,
				YELLOW
			)
		end
		z -= 8
	end
	sign(
		course,
		"GapSign",
		Vector2.new(9, 3),
		at(gapX, 8.5, 4) * TO_SPAWN,
		"GAPS",
		"6, 10 and 13 studs: walk, sprint, slide-jump",
		YELLOW
	)

	-- Crouch walls: half height, crouch to hide behind them.
	for i = 0, 2 do
		local wz = -120 - i * 14
		block(course, "CrouchWall", Vector3.new(10, 3.2, 1.2), at(80, 1.6, wz), BLOCK)
	end
	sign(
		course,
		"CrouchSign",
		Vector2.new(9, 2.8),
		at(80, 6.5, -112) * TO_SPAWN,
		"CROUCH",
		"Hold C to crouch behind the half walls",
		PAINT
	)
end

-- Spawn ------------------------------------------------------------------------------

local function buildSpawn(root: Model): SpawnLocation
	local hub = folder(root, "Spawn")
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "RangeSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0 -- no spawn shield: testers can shoot each other right away
	spawn.Size = Vector3.new(14, 0.3, 14)
	spawn.CFrame = at(0, 0.15, 26)
	spawn.Color = LANE_A
	spawn.Material = Enum.Material.Concrete
	spawn.TopSurface = Enum.SurfaceType.Smooth
	for _, d in spawn:GetChildren() do
		d:Destroy()
	end
	spawn.Parent = hub
	for _, offset in
		{ Vector3.new(0, 0, 7), Vector3.new(0, 0, -7), Vector3.new(7, 0, 0), Vector3.new(-7, 0, 0) }
	do
		local alongX = offset.X == 0
		paint(
			hub,
			if alongX then Vector3.new(14.2, 0.06, 0.25) else Vector3.new(0.25, 0.06, 14.2),
			at(offset.X, 0.32, 26 + offset.Z),
			YELLOW
		)
	end

	sign(
		hub,
		"WelcomeSign",
		Vector2.new(14, 7.5),
		at(-24, 5.5, 24) * CFrame.Angles(0, -math.pi / 2 - 0.25, 0),
		"PRACTICE RANGE",
		table.concat({
			"Lanes ahead: dummies at 10 / 25 / 50 / 100 / 150 studs.",
			"Left: cover and plywood. Right: movement course.",
			"R reload · RMB aim · Shift sprint · C slide/crouch · Y inspect",
		}, "\n"),
		YELLOW
	)
	sign(
		hub,
		"ShooterWarning",
		Vector2.new(7, 2.2),
		at(-54, 9, -40) * TO_SPAWN,
		"SHOOTER",
		"Fires harmless tracers",
		RED
	)
	return spawn
end

-- Builds everything under workspace.TestRange (replacing an old copy).
function RangeBuilder.build(): Built
	local old = workspace:FindFirstChild("TestRange")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Model")
	root.Name = "TestRange"
	buildYard(root)
	buildLanes(root)
	buildCover(root)
	buildMovement(root)
	local spawn = buildSpawn(root)
	root.Parent = workspace
	return {
		root = root,
		spawn = spawn,
		toWorld = function(p: Vector3): CFrame
			return at(p.X, p.Y, p.Z)
		end,
	}
end

return RangeBuilder
