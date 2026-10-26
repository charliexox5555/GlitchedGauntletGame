--!strict
-- Builds the test range geometry from code (so it lives in git and only exists
-- while test mode is on): an enclosed hall with shooting lanes and distance
-- markers, a cover section with ThinWall pieces, a movement course and an
-- armory of walk-up weapon racks behind the spawn. Style B colours
-- (vault/02 Art/Art Direction.md): slate and dark panels, thin cyan neon.
--
-- Range space: X right, Y up from the floor, -Z downrange from the firing line.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Movement = require(ReplicatedStorage.Shared.Config.Movement)
local TestRange = require(ReplicatedStorage.Shared.Config.TestRange)
local Types = require(ReplicatedStorage.Shared.Types)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local RangeBuilder = {}

local PANEL = Color3.fromHex("56607C")
local DARK = Color3.fromHex("1C2030")
local METAL = Color3.fromHex("14161D")
local FLOOR = Color3.fromHex("1A1E2B")
local LANE_A = Color3.fromHex("20253A")
local LANE_B = Color3.fromHex("1C2133")
local WALL = Color3.fromHex("2B3147")
local NEON = Color3.fromHex("00E5FF")
local GOLD = Color3.fromHex("FFC83D")
local MAGENTA = Color3.fromHex("FF3DCB")
local RED = Color3.fromHex("FF3355")
local WHITE = Color3.new(1, 1, 1)
local MUTED = Color3.fromHex("AEB6CC")

local TIER_COLORS: { [number]: Color3 } = {
	[1] = MUTED,
	[2] = NEON,
	[3] = GOLD,
	[4] = MAGENTA,
}
local CLASS_NAMES: { [string]: string } = { MachineGun = "MACHINE GUN" }

-- Hall bounds (range space).
local MIN_X, MAX_X = -110, 110
local MIN_Z, MAX_Z = -196, 62
local WALL_HEIGHT = 26

export type Built = {
	root: Model,
	spawn: SpawnLocation,
	stations: { { prompt: ProximityPrompt, base: BasePart, weaponId: string } },
	toWorld: (Vector3) -> CFrame,
}

local origin = CFrame.new(TestRange.ORIGIN)
-- Boards show their text on the Front (-Z) face; this turns one to face +Z,
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
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = material ~= Enum.Material.Neon
	p.Parent = parent
	return p
end

-- A thin glowing strip: no collision, never a wall for bullets.
local function strip(
	parent: Instance,
	size: Vector3,
	cf: CFrame,
	color: Color3?,
	transparency: number?
)
	local p = block(parent, "Neon", size, cf, color or NEON, Enum.Material.Neon)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = transparency or 0
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
	color: Color3,
	align: Enum.TextXAlignment?
): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.Font = font
	l.TextScaled = true
	l.TextColor3 = color
	l.TextXAlignment = align or Enum.TextXAlignment.Center
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
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.MaxDistance = 400
	gui.Parent = part
	return gui
end

-- A board with a title and body text facing `cf`'s look direction.
local function board(
	parent: Instance,
	name: string,
	size: Vector2,
	cf: CFrame,
	title: string,
	body: string?,
	accent: Color3?
): Part
	local p = block(parent, name, Vector3.new(size.X, size.Y, 0.4), cf, DARK)
	p.CanQuery = false
	local colour = accent or NEON
	-- Neon edge along the top.
	strip(parent, Vector3.new(size.X, 0.12, 0.45), cf * CFrame.new(0, size.Y / 2 - 0.06, 0), colour)
	local gui = surface(p, Enum.NormalId.Front, 50)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.04, 0)
	pad.PaddingRight = UDim.new(0.04, 0)
	pad.PaddingTop = UDim.new(0.06, 0)
	pad.PaddingBottom = UDim.new(0.06, 0)
	pad.Parent = gui
	if body then
		label(
			gui,
			title,
			UDim2.fromScale(1, 0.3),
			UDim2.fromScale(0, 0),
			Enum.Font.GothamBlack,
			colour
		)
		local b = label(
			gui,
			body,
			UDim2.fromScale(1, 0.62),
			UDim2.fromScale(0, 0.36),
			Enum.Font.GothamMedium,
			WHITE
		)
		b.TextYAlignment = Enum.TextYAlignment.Top
		b.TextWrapped = true
	else
		label(
			gui,
			title,
			UDim2.fromScale(1, 1),
			UDim2.fromScale(0, 0),
			Enum.Font.GothamBlack,
			colour
		)
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
	label(gui, text, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Enum.Font.GothamBlack, color)
end

-- Hall ---------------------------------------------------------------------------

local function buildHall(root: Model)
	local hall = folder(root, "Hall")
	local w, d = MAX_X - MIN_X, MAX_Z - MIN_Z
	local cx, cz = (MIN_X + MAX_X) / 2, (MIN_Z + MAX_Z) / 2
	block(hall, "Floor", Vector3.new(w, 1, d), at(cx, -0.5, cz), FLOOR, Enum.Material.Concrete)

	-- Walls: dark skirting, slate panels, a cyan line at eye height and
	-- vertical seams every 24 studs.
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
		block(hall, "Wall" .. i, sized(length, WALL_HEIGHT, 2), at(c.X, WALL_HEIGHT / 2, c.Z), WALL)
		local face = c + inward * 1.05
		block(hall, "Skirting", sized(length, 3, 0.3), at(face.X, 1.5, face.Z), METAL)
		strip(hall, sized(length, 0.2, 0.3), at(face.X, 3.2, face.Z))
		strip(hall, sized(length, 0.3, 0.3), at(face.X, WALL_HEIGHT - 0.6, face.Z), PANEL)
		local seams = math.floor(length / 24)
		for s = 1, seams do
			local offset = -length / 2 + s * length / (seams + 1)
			local pos = if alongX
				then face + Vector3.new(offset, 0, 0)
				else face + Vector3.new(0, 0, offset)
			strip(
				hall,
				sized(0.15, WALL_HEIGHT - 4, 0.3),
				at(pos.X, 3.4 + (WALL_HEIGHT - 4) / 2, pos.Z),
				PANEL,
				0.2
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
		local plate = block(
			lanes,
			"Lane" .. i,
			Vector3.new(TestRange.LANE_WIDTH, 0.1, length),
			at(x, 0.05, -length / 2),
			if i % 2 == 0 then LANE_A else LANE_B
		)
		plate.Material = Enum.Material.SmoothPlastic
	end
	for i = 0, TestRange.LANES do
		local x = -half + i * TestRange.LANE_WIDTH
		local edge = i == 0 or i == TestRange.LANES
		strip(
			lanes,
			Vector3.new(if edge then 0.3 else 0.15, 0.06, length),
			at(x, 0.12, -length / 2),
			if edge then NEON else PANEL,
			if edge then 0 else 0.35
		)
	end

	-- Firing line.
	strip(lanes, Vector3.new(half * 2, 0.06, 0.5), at(0, 0.12, 0), GOLD)
	floorText(lanes, "FIRING LINE", Vector2.new(20, 2.6), 0, 2.2, GOLD)

	-- Distance markers: a line across the lanes, the number on the floor and a
	-- sign on a post either side.
	for _, distance in TestRange.MARKERS do
		local z = -distance
		strip(lanes, Vector3.new(half * 2, 0.06, 0.35), at(0, 0.12, z))
		for i = 1, TestRange.LANES do
			local x = -half + (i - 0.5) * TestRange.LANE_WIDTH
			floorText(lanes, tostring(distance), Vector2.new(5, 2.5), x, z + 2, NEON)
		end
		for _, side in { -1, 1 } do
			local x = side * (half + 2.5)
			block(lanes, "MarkerPost", Vector3.new(0.4, 6, 0.4), at(x, 3, z), METAL)
			board(
				lanes,
				"Marker" .. distance,
				Vector2.new(3.6, 2),
				at(x, 6.6, z) * TO_SPAWN,
				string.format("%d", distance),
				nil,
				if distance >= 100 then GOLD else NEON
			)
		end
	end

	-- Backstop and the long-range platform.
	local backZ = -length - 2
	block(lanes, "Backstop", Vector3.new(half * 2 + 8, 18, 3), at(0, 9, backZ), DARK)
	for ring = 1, 3 do
		strip(
			lanes,
			Vector3.new(half * 2 + 8, 0.2, 0.2),
			at(0, 4 * ring, backZ + 1.6),
			if ring == 2 then NEON else PANEL
		)
	end
	for _, spot in TestRange.DUMMIES do
		local y = spot.y or 0
		if y > 0 then
			local accent = TestRange.KINDS[spot.kind].accent
			local pos = Vector3.new(spot.x, y / 2, -spot.distance)
			block(lanes, "Platform", Vector3.new(8, y, 8), at(pos.X, pos.Y, pos.Z), PANEL)
			strip(lanes, Vector3.new(8.1, 0.15, 8.1), at(pos.X, y - 0.1, pos.Z), accent)
		end
	end
end

-- Cover section (left) -----------------------------------------------------------

local function gunsWith(penetration: { [Types.Penetration]: boolean }): string
	local names = {}
	for _, w in Weapons.list do
		if penetration[w.penetration] then
			table.insert(names, w.displayName)
		end
	end
	table.sort(names)
	return if #names > 0 then table.concat(names, ", ") else "none"
end

local function buildCover(root: Model)
	local cover = folder(root, "Cover")
	-- Floor plate for the section.
	block(cover, "CoverFloor", Vector3.new(56, 0.1, 64), at(-80, 0.05, -28), LANE_B)
	strip(cover, Vector3.new(56, 0.06, 0.4), at(-80, 0.12, 0), GOLD)

	-- ThinWall: guns with ThinWall penetration shoot through it.
	local thin = block(
		cover,
		"ThinWall",
		Vector3.new(10, 9, 0.4),
		at(-78, 4.5, -23),
		NEON,
		Enum.Material.Glass
	)
	thin.Transparency = 0.6
	CollectionService:AddTag(thin, Combat.THIN_WALL_TAG)
	for _, x in { -83.2, -72.8 } do
		block(cover, "Frame", Vector3.new(0.4, 9.4, 0.8), at(x, 4.7, -23), METAL)
	end
	strip(cover, Vector3.new(10.8, 0.25, 0.8), at(-78, 9.4, -23))

	-- Solid wall: blocks everything except guns that ignore walls.
	block(cover, "SolidWall", Vector3.new(10, 9, 1.5), at(-94, 4.5, -23), WALL)
	strip(cover, Vector3.new(10, 0.2, 1.6), at(-94, 9, -23), PANEL)
	block(cover, "Skirting", Vector3.new(10.2, 1.2, 1.7), at(-94, 0.6, -23), METAL)

	-- Low cover: the head shows above it from the firing line.
	block(cover, "LowCover", Vector3.new(8, 3.6, 1.5), at(-62, 1.8, -25), WALL)
	strip(cover, Vector3.new(8, 0.15, 1.6), at(-62, 3.6, -25), NEON)

	-- Pillars to strafe-peek around.
	for _, x in { -70, -86, -102 } do
		block(cover, "Pillar", Vector3.new(3, 10, 3), at(x, 5, -10), WALL)
		strip(cover, Vector3.new(3.1, 0.2, 3.1), at(x, 3.2, -10))
	end

	board(
		cover,
		"ThinWallSign",
		Vector2.new(10, 3.4),
		at(-78, 12.2, -23) * TO_SPAWN,
		"THINWALL",
		"Shoots through: " .. gunsWith({ ThinWall = true, All = true }),
		NEON
	)
	board(
		cover,
		"SolidWallSign",
		Vector2.new(10, 3.4),
		at(-94, 12.2, -23) * TO_SPAWN,
		"SOLID WALL",
		"Only guns that ignore walls: " .. gunsWith({ All = true }),
		PANEL
	)
	board(
		cover,
		"LowCoverSign",
		Vector2.new(8, 3),
		at(-62, 6.5, -25) * TO_SPAWN,
		"LOW COVER",
		"Aim for the head, or crouch behind it",
		GOLD
	)
	board(
		cover,
		"CoverTitle",
		Vector2.new(18, 3),
		at(-80, 14, -2) * TO_SPAWN,
		"COVER & PENETRATION",
		nil,
		NEON
	)
end

-- Movement course (right) ----------------------------------------------------------

local function wedge(parent: Instance, size: Vector3, cf: CFrame): WedgePart
	local p = Instance.new("WedgePart")
	p.Name = "Ramp"
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = PANEL
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

local function buildMovement(root: Model)
	local course = folder(root, "Movement")
	block(course, "CourseFloor", Vector3.new(58, 0.1, 230), at(80, 0.05, -60), LANE_B)

	-- Sprint and slide strip with a tick every 10 studs (slide distance).
	local trackX = 62
	block(course, "Track", Vector3.new(10, 0.06, 160), at(trackX, 0.13, -40), LANE_A)
	for _, x in { trackX - 5, trackX + 5 } do
		strip(course, Vector3.new(0.25, 0.06, 160), at(x, 0.18, -40))
	end
	for i = 0, 16 do
		local z = 40 - i * 10
		strip(
			course,
			Vector3.new(10, 0.06, 0.2),
			at(trackX, 0.18, z),
			if i % 5 == 0 then GOLD else PANEL
		)
		if i > 0 and i % 2 == 0 then
			floorText(course, tostring(i * 10), Vector2.new(4, 2), trackX, z + 1.6, MUTED)
		end
	end
	board(
		course,
		"TrackSign",
		Vector2.new(12, 4),
		at(trackX, 8, 14) * TO_SPAWN,
		"SPRINT & SLIDE",
		"Hold Shift to sprint, press C while sprinting to slide. Jump out of a slide to keep its speed.",
		NEON
	)

	-- Jump boxes, rising toward the jump height.
	local boxX = 80
	local heights = { 2, 3.5, 5, 6.5 }
	for i, h in heights do
		local z = -4 - i * 9
		block(course, "JumpBox", Vector3.new(6, h, 6), at(boxX, h / 2, z), WALL)
		strip(
			course,
			Vector3.new(6.1, 0.15, 6.1),
			at(boxX, h - 0.05, z),
			if i == #heights then GOLD else NEON
		)
		floorText(course, string.format("%.1f", h), Vector2.new(4, 2), boxX, z + 4.2, MUTED)
	end
	board(
		course,
		"JumpSign",
		Vector2.new(10, 3.4),
		at(boxX, 9, 4) * TO_SPAWN,
		"JUMP",
		string.format("Box heights in studs. A jump reaches %.1f.", Movement.JUMP_HEIGHT),
		NEON
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
			WALL
		)
		strip(course, Vector3.new(8.1, 0.15, 8.1), at(gapX, platformH - 0.05, z - 4))
		if gap[1] > 0 then
			floorText(
				course,
				string.format("%d · %s", gap[1], gap[2]),
				Vector2.new(8, 2),
				gapX,
				z + gap[1] / 2,
				GOLD
			)
		end
		z -= 8
	end
	board(
		course,
		"GapSign",
		Vector2.new(10, 3.4),
		at(gapX, 9, 4) * TO_SPAWN,
		"GAPS",
		"Gaps of 6, 10 and 13 studs: walk, sprint, slide-jump",
		GOLD
	)

	-- Crouch walls: half height, crouch to hide behind them.
	for i = 0, 2 do
		local wz = -120 - i * 14
		block(course, "CrouchWall", Vector3.new(10, 3.2, 1.2), at(80, 1.6, wz), WALL)
		strip(course, Vector3.new(10, 0.15, 1.3), at(80, 3.2, wz), NEON)
	end
	board(
		course,
		"CrouchSign",
		Vector2.new(10, 3),
		at(80, 7, -112) * TO_SPAWN,
		"CROUCH",
		"Hold C to crouch behind the half walls",
		NEON
	)
end

-- Hub and armory -------------------------------------------------------------------

local function weaponTemplate(id: string): Model?
	local weapons = ReplicatedStorage:FindFirstChild("Weapons")
	local m = weapons and weapons:FindFirstChild(id)
	return if m and m:IsA("Model") then m else nil
end

-- A display copy of a gun: anchored and never a hitbox or a wall.
local function displayModel(id: string, cf: CFrame, parent: Instance): Model?
	local template = weaponTemplate(id)
	if not template then
		return nil
	end
	local m = template:Clone()
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	-- Barrel to the right, side profile facing the firing line.
	m:PivotTo(cf * CFrame.Angles(0, math.pi / 2, 0))
	m.Parent = parent
	return m
end

local function sortedWeapons(): { Types.WeaponConfig }
	local order: { [string]: number } = { Primary = 1, Secondary = 2, Melee = 3 }
	local list = {}
	for _, w in Weapons.list do
		table.insert(list, w)
	end
	table.sort(list, function(a, b)
		if a.slot ~= b.slot then
			return order[a.slot] < order[b.slot]
		end
		if a.tier ~= b.tier then
			return a.tier < b.tier
		end
		return a.displayName < b.displayName
	end)
	return list
end

type Station = { prompt: ProximityPrompt, base: BasePart, weaponId: string }

local function buildArmory(root: Model, stations: { Station })
	local armory = folder(root, "Armory")
	local list = sortedWeapons()
	local rackZ = 54
	-- Slots: weapons plus one empty space between slot groups.
	local count = #list + 2
	local spacing = TestRange.STATION_SPACING
	local x = -(count - 1) * spacing / 2
	local lastSlot = list[1] and list[1].slot
	block(armory, "RackPlinth", Vector3.new(count * spacing + 4, 0.6, 5), at(0, 0.3, rackZ), METAL)
	strip(armory, Vector3.new(count * spacing + 4, 0.1, 0.2), at(0, 0.62, rackZ - 2.5))
	for _, w in list do
		if w.slot ~= lastSlot then
			x += spacing
			lastSlot = w.slot
		end
		local tierColor = TIER_COLORS[w.tier] or WHITE
		local base =
			block(armory, "Station_" .. w.id, Vector3.new(2.6, 3, 2.4), at(x, 2.1, rackZ), DARK)
		-- Tier colour as a thin line along the top front edge.
		strip(armory, Vector3.new(2.7, 0.1, 0.12), at(x, 3.58, rackZ - 1.2), tierColor)
		block(armory, "Cap", Vector3.new(2.8, 0.12, 2.6), at(x, 3.66, rackZ), METAL)
		local gui = surface(base, Enum.NormalId.Front, 60)
		label(
			gui,
			string.upper(w.displayName),
			UDim2.fromScale(0.92, 0.2),
			UDim2.fromScale(0.04, 0.08),
			Enum.Font.GothamBlack,
			WHITE
		)
		label(
			gui,
			string.format(
				"%s · <font color='#%s'>T%d</font>",
				CLASS_NAMES[w.class] or string.upper(w.class),
				tierColor:ToHex(),
				w.tier
			),
			UDim2.fromScale(0.92, 0.13),
			UDim2.fromScale(0.04, 0.3),
			Enum.Font.GothamBold,
			MUTED
		)
		label(
			gui,
			string.upper(w.slot),
			UDim2.fromScale(0.92, 0.11),
			UDim2.fromScale(0.04, 0.8),
			Enum.Font.GothamBold,
			tierColor
		)

		local models = w.models
		local showCf = at(x, 4.9, rackZ)
		if models and models.left then
			displayModel(models.right, showCf * CFrame.new(0, 0.35, 0), armory)
			displayModel(models.left, showCf * CFrame.new(0, -0.35, 0), armory)
		else
			displayModel(if models then models.right else w.id, showCf, armory)
		end

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Take"
		prompt.ObjectText = w.displayName
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		-- X is reload on a gamepad, so racks use the D-pad.
		prompt.GamepadKeyCode = Enum.KeyCode.DPadRight
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = TestRange.STATION_PROMPT_DISTANCE
		prompt.RequiresLineOfSight = false
		prompt.Parent = base
		table.insert(stations, { prompt = prompt, base = base, weaponId = w.id })
		x += spacing
	end
	board(
		armory,
		"ArmorySign",
		Vector2.new(30, 4.5),
		at(0, 10, rackZ + 4.6),
		"ARMORY",
		"Walk up to a gun and press E (D-pad right / tap) to take it. Press B for the tester menu.",
		NEON
	)
end

local function buildHub(root: Model): SpawnLocation
	local hub = folder(root, "Hub")
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "RangeSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0 -- no spawn shield: testers can shoot each other right away
	spawn.Size = Vector3.new(14, 0.4, 14)
	spawn.CFrame = at(0, 0.2, 26)
	spawn.Color = DARK
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	for _, d in spawn:GetChildren() do
		d:Destroy()
	end
	spawn.Parent = hub
	for _, offset in
		{ Vector3.new(0, 0, 7), Vector3.new(0, 0, -7), Vector3.new(7, 0, 0), Vector3.new(-7, 0, 0) }
	do
		local alongX = offset.X == 0
		strip(
			hub,
			if alongX then Vector3.new(14.2, 0.1, 0.25) else Vector3.new(0.25, 0.1, 14.2),
			at(offset.X, 0.42, 26 + offset.Z)
		)
	end
	floorText(hub, "TEST RANGE", Vector2.new(10, 2), 0, 18, NEON)

	board(
		hub,
		"WelcomeSign",
		Vector2.new(16, 9),
		at(-24, 6.5, 24) * CFrame.Angles(0, -math.pi / 2 - 0.25, 0),
		"WELCOME, TESTER",
		table.concat({
			"• <b>B</b> (D-pad up, or the TEST button) opens the tester menu: loadout, ammo, dummies, FOV, controls.",
			"• Lanes ahead: dummies at 10 / 25 / 50 / 100 / 150 studs for damage falloff.",
			"• Left: cover and ThinWall. Right: movement course. Behind you: the armory.",
			"• Your stats (damage, TTK, accuracy, DPS) are on the left of the screen.",
		}, "\n"),
		NEON
	)
	board(
		hub,
		"ShooterWarning",
		Vector2.new(8, 2.4),
		at(-54, 9.5, -40) * TO_SPAWN,
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
	local stations: { Station } = {}
	buildHall(root)
	buildLanes(root)
	buildCover(root)
	buildMovement(root)
	buildArmory(root, stations)
	local spawn = buildHub(root)
	root.Parent = workspace
	return {
		root = root,
		spawn = spawn,
		stations = stations,
		toWorld = function(p: Vector3): CFrame
			return at(p.X, p.Y, p.Z)
		end,
	}
end

return RangeBuilder
