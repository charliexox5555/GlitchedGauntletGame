--!strict
-- Lobby greybox (step 2 of the Lobby build; plan: vault/02 Art/Lobby Art Plan.md,
-- "Sunwell Bunker"). Builds Workspace.Lobby.Greybox from simple coloured parts
-- per zone at real scale, so the layout can be walked and slide-tested before
-- the Blender kit replaces it. Coordinates follow the plan: studs, origin at
-- the rotunda centre on the floor, +X east, -Z north, bearings clockwise from
-- north. Round parts use 32 segments of 11.25 degrees.
--
-- Run it in the LOBBY place only (Command Bar, or Claude through the Studio
-- MCP). It refuses any other place and replaces an existing greybox.

local Lighting = game:GetService("Lighting")

local LOBBY_PLACE_ID = 133387545285290
assert(game.PlaceId == LOBBY_PLACE_ID, "LobbyGreybox: this is not the Lobby place")

local SEG = 11.25

local C = {
	floor = Color3.fromRGB(201, 196, 186),
	sunPatch = Color3.fromRGB(242, 234, 219),
	brass = Color3.fromRGB(184, 135, 63),
	concrete = Color3.fromRGB(142, 140, 135),
	ringFloor = Color3.fromRGB(70, 71, 74),
	oak = Color3.fromRGB(160, 112, 63),
	rock = Color3.fromRGB(85, 82, 78),
	steel = Color3.fromRGB(28, 29, 32),
	deck = Color3.fromRGB(190, 188, 182),
	duelsWall = Color3.fromRGB(40, 41, 45),
	duelsFloor = Color3.fromRGB(30, 31, 34),
	duelsAisle = Color3.fromRGB(24, 25, 28),
	duelsRed = Color3.fromHex("B3262E"),
	marketFloor = Color3.fromRGB(214, 200, 176),
	marketWall = Color3.fromRGB(231, 216, 191),
	weaponsFloor = Color3.fromRGB(196, 195, 191),
	weaponsWall = Color3.fromRGB(214, 213, 209),
	locker = Color3.fromRGB(158, 162, 168),
	range = Color3.fromRGB(211, 214, 218),
	lanes = Color3.fromRGB(228, 231, 234),
	course = Color3.fromRGB(205, 214, 226),
	yard = Color3.fromRGB(226, 212, 212),
	white = Color3.fromRGB(244, 244, 242),
	screen = Color3.fromRGB(11, 13, 16),
	sign = Color3.fromRGB(42, 44, 48),
	glass = Color3.fromRGB(169, 201, 207),
	unpowered = Color3.fromRGB(90, 92, 96),
	m1v1 = Color3.fromHex("3DDC84"),
	m2v2 = Color3.fromHex("3B8CFF"),
	m3v3 = Color3.fromHex("9B5CFF"),
	m4v4 = Color3.fromHex("FF7A1A"),
	gauntlet = Color3.fromHex("FFC83D"),
}

type PartOpts = {
	material: Enum.Material?,
	transparency: number?,
	collide: boolean?,
	shape: Enum.PartType?,
	shadow: boolean?,
}

type Line = { text: string, cap: number, color: Color3? }

local function polar(r: number, bearing: number): (number, number)
	local a = math.rad(bearing)
	return r * math.sin(a), -r * math.cos(a)
end

local function make(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	opts: PartOpts?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	if opts and opts.shape then
		p.Shape = opts.shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = (opts and opts.material) or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if opts and opts.transparency then
		p.Transparency = opts.transparency
	end
	if opts and opts.collide == false then
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
	end
	if opts and opts.shadow == false then
		p.CastShadow = false
	end
	p.Parent = parent
	return p
end

-- Axis-aligned box from its extents.
local function box(
	parent: Instance,
	name: string,
	x0: number,
	x1: number,
	y0: number,
	y1: number,
	z0: number,
	z1: number,
	color: Color3,
	opts: PartOpts?
): Part
	local size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	local cf = CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
	return make(parent, name, size, cf, color, opts)
end

-- Vertical cylinder standing on y0.
local function cylinder(
	parent: Instance,
	name: string,
	cx: number,
	cz: number,
	r: number,
	y0: number,
	y1: number,
	color: Color3,
	opts: PartOpts?
): Part
	local o: PartOpts = opts or {}
	o.shape = Enum.PartType.Cylinder
	local cf = CFrame.new(cx, (y0 + y1) / 2, cz) * CFrame.Angles(0, 0, math.pi / 2)
	return make(parent, name, Vector3.new(y1 - y0, r * 2, r * 2), cf, color, o)
end

-- One straight block approximating the arc rIn..rOut between two bearings,
-- facing the centre (its local -Z points inward).
local function arcPiece(
	parent: Instance,
	name: string,
	rIn: number,
	rOut: number,
	b0: number,
	b1: number,
	y0: number,
	y1: number,
	color: Color3,
	opts: PartOpts?
): Part
	local half = math.rad((b1 - b0) / 2)
	local bm = (b0 + b1) / 2
	local inner = rIn * math.cos(half)
	local width = 2 * rOut * math.sin(half) + 0.1
	local rc = (rOut + inner) / 2
	local x, z = polar(rc, bm)
	local yc = (y0 + y1) / 2
	local pos = Vector3.new(x, yc, z)
	local cf = CFrame.lookAt(pos, Vector3.new(0, yc, 0))
	return make(parent, name, Vector3.new(width, y1 - y0, rOut - inner), cf, color, opts)
end

-- An arc from b0 to b1 (wrapping through north is fine) built from 11.25 degree
-- pieces, split radially into bands of at most maxBand studs.
local function arc(
	parent: Instance,
	name: string,
	rIn: number,
	rOut: number,
	b0: number,
	b1: number,
	y0: number,
	y1: number,
	color: Color3,
	opts: PartOpts?,
	maxBand: number?
)
	if b1 <= b0 then
		b1 += 360
	end
	local band = maxBand or (rOut - rIn)
	local bands = math.max(1, math.ceil((rOut - rIn) / band - 1e-6))
	local step = (rOut - rIn) / bands
	local b = b0
	local i = 0
	while b < b1 - 1e-6 do
		local e = math.min(b + SEG, b1)
		for k = 0, bands - 1 do
			i += 1
			arcPiece(
				parent,
				name .. "_" .. i,
				rIn + step * k,
				rIn + step * (k + 1),
				b,
				e,
				y0,
				y1,
				color,
				opts
			)
		end
		b = e
	end
end

local function inRange(b: number, from: number, to: number): boolean
	b %= 360
	from %= 360
	to %= 360
	if from <= to then
		return b > from and b < to
	end
	return b > from or b < to
end

-- Text lines on one face of a panel `height` studs tall. Cap heights follow the
-- plan (readable to about 30x the cap); if the lines would overflow the panel
-- they all shrink by the same factor.
local function addSurface(part: BasePart, face: Enum.NormalId, lines: { Line }, height: number)
	local maxFont, stack = 0, 0
	for _, l in lines do
		local font = l.cap / 0.72
		local _, breaks = string.gsub(l.text, "\n", "")
		maxFont = math.max(maxFont, font)
		stack += font * 1.1 * (breaks + 1)
	end
	local k = math.min(1, height * 0.92 / stack)
	local pps = math.clamp(math.floor(95 / (maxFont * k)), 4, 50)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pps
	gui.LightInfluence = 0
	gui.Brightness = 1.5
	gui.MaxDistance = 250
	gui.ClipsDescendants = true
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = gui
	for i, l in lines do
		local font = l.cap / 0.72 * k
		local _, breaks = string.gsub(l.text, "\n", "")
		local t = Instance.new("TextLabel")
		t.LayoutOrder = i
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, 0, 0, math.ceil(font * pps * 1.1 * (breaks + 1)))
		t.Font = Enum.Font.GothamBlack
		t.TextSize = math.floor(font * pps)
		t.TextColor3 = l.color or C.white
		t.Text = l.text
		-- GothamBlack runs wide: scale down to fit the panel, never above the
		-- planned cap size.
		t.TextScaled = true
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = math.floor(font * pps)
		limit.Parent = t
		t.Parent = gui
	end
	gui.Parent = part
end

-- A flat sign panel whose front faces `facing`. Signs never collide.
local function sign(
	parent: Instance,
	name: string,
	w: number,
	h: number,
	pos: Vector3,
	facing: Vector3,
	lines: { Line },
	back: { Line }?,
	bg: Color3?
): Part
	local p =
		make(parent, name, Vector3.new(w, h, 0.3), CFrame.lookAt(pos, pos + facing), bg or C.sign, {
			collide = false,
			shadow = false,
		})
	addSurface(p, Enum.NormalId.Front, lines, h)
	if back then
		addSurface(p, Enum.NormalId.Back, back, h)
	end
	return p
end

local NORTH = Vector3.new(0, 0, -1)
local SOUTH = Vector3.new(0, 0, 1)
local EAST = Vector3.new(1, 0, 0)
local WEST = Vector3.new(-1, 0, 0)

local PORTALS = {
	{ 337.5, 22.5 }, -- Duels (double width)
	{ 78.75, 101.25 }, -- Weapons
	{ 168.75, 191.25 }, -- Range
	{ 258.75, 281.25 }, -- Market
}
local ALCOVES = { { 33.75, 56.25 }, { 123.75, 146.25 }, { 213.75, 236.25 }, { 303.75, 326.25 } }

local function inAny(b: number, list: { { number } }): boolean
	for _, r in list do
		if inRange(b, r[1], r[2]) then
			return true
		end
	end
	return false
end

---------------------------------------------------------------------------
-- Sections
---------------------------------------------------------------------------

local function buildRotunda(f: Folder)
	-- Floor: one disc for the rotunda over the hub floor (built in Ring).
	cylinder(f, "RotundaFloor", 0, 0, 44, -0.98, 0.02, C.floor)
	cylinder(f, "SunPatchInlay", 0, -10.05, 16, -0.96, 0.04, C.sunPatch)
	cylinder(f, "SpawnDais", 0, 0, 12, 0, 0.5, C.brass, { material = Enum.Material.Metal })
	box(f, "DaisNorthArrow", -0.6, 0.6, 0.5, 0.56, -11, -2, C.white, { collide = false })

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 0.2, 12)
	spawn.CFrame = CFrame.new(0, 0.6, -3) -- faces north (-Z), toward Duels
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = f

	-- Colonnade: 8 piers and 4 slim columns, ring beam, drum, dome, oculus.
	for k = 0, 7 do
		local b = 22.5 + 45 * k
		local x, z = polar(44, b)
		local pos = Vector3.new(x, 14, z)
		make(
			f,
			"Pier_" .. k,
			Vector3.new(3, 28, 3),
			CFrame.lookAt(pos, Vector3.new(0, 14, 0)),
			C.concrete
		)
	end
	for k = 0, 3 do
		local x, z = polar(44, 45 + 90 * k)
		cylinder(
			f,
			"SlimColumn_" .. k,
			x,
			z,
			0.6,
			0,
			28,
			C.steel,
			{ material = Enum.Material.Metal }
		)
	end
	arc(f, "RingBeam", 42.5, 45.5, 0, 360, 28, 31, C.concrete)
	arc(f, "Drum", 44, 45.5, 0, 360, 31, 46, C.concrete)
	-- Shallow coffered dome (greybox: tilted panels) from y 46 at R44 up to the
	-- oculus rim at y 54, R16.
	local slope = math.sqrt(28 * 28 + 8 * 8)
	for k = 0, 31 do
		local bm = k * SEG + SEG / 2
		local mx, mz = polar(30, bm)
		local ix, iz = polar(16, bm)
		local width = 2 * 44 * math.sin(math.rad(SEG / 2)) + 0.2
		make(
			f,
			"Dome_" .. k,
			Vector3.new(width, 1, slope),
			CFrame.lookAt(Vector3.new(mx, 50, mz), Vector3.new(ix, 54, iz)),
			C.concrete
		)
	end
	arc(f, "OculusShaft", 16, 17.5, 0, 360, 54, 60, C.concrete)

	-- Leaderboards on the diagonals, facing the centre (y 12-25.5, so the two
	-- north boards sit in the default camera's first frame). Their backs point
	-- ring walkers to the wings on either side (as seen from the ring).
	local boards = {
		{ 45, "TOP WINS TODAY", "< WEAPONS | DUELS >" },
		{ 315, "TOP RATING", "< DUELS | MARKET >" },
		{ 135, "TOP STREAKS", "< RANGE | WEAPONS >" },
		{ 225, "MOST ELIMS (WEEK)", "< MARKET | RANGE >" },
	}
	-- Short rows, so 1.8-cap names fit an 18-wide board and read from spawn.
	local rows = "1  NOVA   42\n2  KAIRO  37\n3  VEX    31"
	for i, bd in boards do
		local x, z = polar(42.5, bd[1] :: number)
		local pos = Vector3.new(x, 18.75, z)
		local inward = (Vector3.new(0, 18.75, 0) - pos).Unit
		sign(f, "Leaderboard_" .. i, 18, 13.5, pos, inward, {
			{ text = bd[2] :: string, cap = 2.4 },
			{ text = rows, cap = 1.8, color = Color3.fromRGB(200, 205, 212) },
		}, { { text = bd[3] :: string, cap = 2.0 } }, C.screen)
	end

	-- Pier plaques pointing at the side wings (they sit outside the first frame).
	-- 15 wide: "WEAPONS >" at a readable cap is about 14 studs of GothamBlack.
	for _, pl in { { 22.5, "WEAPONS  >" }, { 337.5, "<  MARKET" } } do
		local x, z = polar(42.3, pl[1] :: number)
		local pos = Vector3.new(x, 10.5, z)
		sign(
			f,
			"Plaque",
			15,
			3,
			pos,
			(Vector3.new(0, 10.5, 0) - pos).Unit,
			{ { text = pl[2] :: string, cap = 2.2 } }
		)
	end
end

local function buildRing(f: Folder)
	cylinder(f, "HubFloor", 0, 0, 70, -2, 0, C.ringFloor)
	arc(f, "SlideBand", 54, 58, 0, 360, -0.97, 0.03, C.oak, nil, 4)
	arc(f, "RingCeiling", 44, 70, 0, 360, 28, 29, C.concrete, nil, 13)

	for k = 0, 31 do
		local b0 = k * SEG
		local b1 = b0 + SEG
		local bm = b0 + SEG / 2
		if inAny(bm, PORTALS) then
			arcPiece(
				f,
				"PortalLintel_" .. k,
				68,
				70,
				b0,
				b1,
				16,
				28,
				C.rock,
				{ material = Enum.Material.Slate }
			)
		elseif inAny(bm, ALCOVES) then
			arcPiece(
				f,
				"AlcoveHead_" .. k,
				68,
				70,
				b0,
				b1,
				12,
				28,
				C.rock,
				{ material = Enum.Material.Slate }
			)
		else
			arcPiece(
				f,
				"RockWall_" .. k,
				68,
				70,
				b0,
				b1,
				0,
				28,
				C.rock,
				{ material = Enum.Material.Slate }
			)
		end
	end

	-- Seating alcoves cut into the rock: lip, three oak tiers, back, sides, roof.
	for i, a in ALCOVES do
		local b0, b1 = a[1], a[2]
		local n = "Alcove" .. i
		arc(f, n .. "Floor", 68, 82, b0, b1, -2, 0, C.ringFloor)
		arc(f, n .. "Tier1", 71, 74, b0, b1, 0, 1.5, C.oak, { material = Enum.Material.Wood })
		arc(f, n .. "Tier2", 74, 77, b0, b1, 0, 3, C.oak, { material = Enum.Material.Wood })
		arc(f, n .. "Tier3", 77, 80, b0, b1, 0, 4.5, C.oak, { material = Enum.Material.Wood })
		arc(f, n .. "Back", 80, 82, b0, b1, 0, 12, C.rock, { material = Enum.Material.Slate })
		arc(f, n .. "Roof", 68, 82, b0, b1, 12, 13, C.rock, { material = Enum.Material.Slate })
		for _, b in { b0, b1 } do
			local x, z = polar(75, b)
			make(
				f,
				n .. "Side",
				Vector3.new(1, 12, 14),
				CFrame.lookAt(Vector3.new(x, 6, z), Vector3.new(0, 6, 0)),
				C.rock,
				{ material = Enum.Material.Slate }
			)
		end
	end

	-- Portal title bands above each opening (y 16.5-26.5). They hang in front of
	-- the curved lintel: flat panels at R67.4 sank into its chord ends, so the
	-- side titles sit at R66.3 and the two-segment DUELS band at R64.4.
	local titles = {
		{ 0, 64.4, 40, "DUELS", 5.5, "STEP ON A PAD TO QUEUE" },
		{ 90, 66.3, 26, "WEAPONS", 4, "GUNS + LOCKER" },
		{ 180, 66.3, 26, "RANGE", 4.5, "PRACTICE" },
		{ 270, 66.3, 26, "MARKET", 4.5, "SHOP + BATTLE PASS" },
	}
	for _, t in titles do
		local x, z = polar(t[2] :: number, t[1] :: number)
		local pos = Vector3.new(x, 21.5, z)
		sign(
			f,
			"Title_" .. (t[4] :: string),
			t[3] :: number,
			10,
			pos,
			(Vector3.new(0, 21.5, 0) - pos).Unit,
			{
				{ text = t[4] :: string, cap = t[5] :: number },
				{ text = t[6] :: string, cap = 1.2, color = Color3.fromRGB(190, 192, 196) },
			}
		)
	end

	-- Throat walls and roofs where the straight wings meet the round ring.
	for _, s in { -1, 1 } do
		-- Market (s = -1) and Weapons (s = 1)
		box(f, "ThroatFloor", s * 66, s * 72, -2, 0, -13.27, 13.27, C.ringFloor)
		box(f, "ThroatRoof", s * 66.69, s * 72, 16, 17, -13.27, 13.27, C.concrete)
		box(f, "ThroatSideN", s * 66.7, s * 72, 0, 28, -14.27, -13.27, C.concrete)
		box(f, "ThroatSideS", s * 66.7, s * 72, 0, 28, 13.27, 14.27, C.concrete)
	end
	box(f, "RangeThroatFloor", -14, 14, -2, 0, 66, 70, C.ringFloor)
	box(f, "RangeThroatSideW", -14, -13.27, -8, 28, 66.7, 71, C.concrete)
	box(f, "RangeThroatSideE", 13.27, 14, -8, 28, 66.7, 71, C.concrete)
end

local function pad(
	f: Folder,
	name: string,
	x0: number,
	x1: number,
	z0: number,
	z1: number,
	ring: Color3,
	live: boolean
)
	box(f, name .. "_Deck", x0 + 1, x1 - 1, 0, 0.52, z0 + 1, z1 - 1, live and C.deck or C.unpowered)
	local o: PartOpts = { material = live and Enum.Material.Neon or Enum.Material.SmoothPlastic }
	local rc = live and ring or C.unpowered
	box(f, name .. "_RingN", x0, x1, 0, 0.55, z0, z0 + 1, rc, o)
	box(f, name .. "_RingS", x0, x1, 0, 0.55, z1 - 1, z1, rc, o)
	box(f, name .. "_RingW", x0, x0 + 1, 0, 0.55, z0 + 1, z1 - 1, rc, o)
	box(f, name .. "_RingE", x1 - 1, x1, 0, 0.55, z0 + 1, z1 - 1, rc, o)
end

local function buildDuels(f: Folder)
	-- Floor and ceiling start at z -64.6, behind the DUELS title, so neither
	-- pokes into the ring.
	box(f, "Floor", -26, 26, -2, 0.02, -126, -64.6, C.duelsFloor)
	box(f, "Aisle", -11, 11, -1, 0.08, -104, -71, C.duelsAisle)
	box(
		f,
		"AisleRedW",
		-11.3,
		-11,
		0.08,
		0.12,
		-104,
		-71,
		C.duelsRed,
		{ material = Enum.Material.Neon, collide = false }
	)
	box(
		f,
		"AisleRedE",
		11,
		11.3,
		0.08,
		0.12,
		-104,
		-71,
		C.duelsRed,
		{ material = Enum.Material.Neon, collide = false }
	)
	box(f, "WallW", -28, -26, 0, 22, -128, -62.82, C.duelsWall)
	box(f, "WallE", 26, 28, 0, 22, -128, -62.82, C.duelsWall)
	box(f, "WallBack", -28, 28, 0, 22, -128, -126, C.duelsWall)
	box(f, "Ceiling", -28, 28, 22, 23, -128, -64.6, C.steel)

	-- End trio on the back wall: 2V2 | 1V1 | 3V3, 1V1 dead centre on the axis.
	-- Signs are 14 x 9.5 (y 8-17.5) so the 5-cap mode and the count both fit.
	local ends = {
		{ "Pad1v1", -7.5, 7.5, C.m1v1, "1V1", "0 / 2 QUEUED" },
		{ "Pad2v2", -24.5, -9.5, C.m2v2, "2V2", "0 / 4 QUEUED" },
		{ "Pad3v3", 9.5, 24.5, C.m3v3, "3V3", "0 / 6 QUEUED" },
	}
	for _, e in ends do
		local x0, x1 = e[2] :: number, e[3] :: number
		pad(f, e[1] :: string, x0, x1, -126, -111, e[4] :: Color3, true)
		sign(
			f,
			(e[1] :: string) .. "_Sign",
			14,
			9.5,
			Vector3.new((x0 + x1) / 2, 12.75, -125.7),
			SOUTH,
			{
				{ text = e[5] :: string, cap = 5, color = e[4] :: Color3 },
				{ text = e[6] :: string, cap = 1.2 },
			}
		)
	end
	box(f, "KerbW", -9.5, -7.5, 0, 1, -126, -111, C.steel)
	box(f, "KerbE", 7.5, 9.5, 0, 1, -126, -111, C.steel)

	-- Row 1: second 1V1 and 2V2 queues. Row 2: reserved 4V4 and Gauntlet bays.
	pad(f, "Pad1v1_B", -26, -11, -86, -71, C.m1v1, true)
	sign(f, "Pad1v1_B_Sign", 14, 7, Vector3.new(-25.7, 11.5, -78.5), EAST, {
		{ text = "1V1", cap = 2.5, color = C.m1v1 },
		{ text = "0 / 2 QUEUED", cap = 1.2 },
	})
	pad(f, "Pad2v2_B", 11, 26, -86, -71, C.m2v2, true)
	sign(f, "Pad2v2_B_Sign", 14, 7, Vector3.new(25.7, 11.5, -78.5), WEST, {
		{ text = "2V2", cap = 2.5, color = C.m2v2 },
		{ text = "0 / 4 QUEUED", cap = 1.2 },
	})
	pad(f, "Reserved4v4", -26, -11, -104, -89, C.m4v4, false)
	sign(f, "Reserved4v4_Sign", 14, 7, Vector3.new(-25.7, 11.5, -96.5), EAST, {
		{ text = "4V4", cap = 2.5, color = C.unpowered },
		{ text = "SOON", cap = 1.2, color = C.unpowered },
	})
	pad(f, "ReservedGauntlet", 11, 26, -104, -89, C.gauntlet, false)
	sign(f, "ReservedGauntlet_Sign", 14, 7, Vector3.new(25.7, 11.5, -96.5), WEST, {
		{ text = "GAUNTLET", cap = 2.5, color = C.unpowered },
		{ text = "SOON", cap = 1.2, color = C.unpowered },
	})
	box(f, "RowKerbW", -26, -11, 0, 1, -89, -86, C.steel)
	box(f, "RowKerbE", 11, 26, 0, 1, -89, -86, C.steel)

	-- Queue terminals (open the queue menu in phase 2).
	for _, t in
		{ { -24, -68.5, EAST }, { 24, -68.5, WEST }, { -24, -107.5, EAST }, { 24, -107.5, WEST } }
	do
		local x, z, face = t[1] :: number, t[2] :: number, t[3] :: Vector3
		box(f, "Terminal", x - 1.5, x + 1.5, 0, 5, z - 1.5, z + 1.5, C.steel)
		sign(
			f,
			"TerminalScreen",
			2.5,
			1.6,
			Vector3.new(x, 4, z) + face * 1.6,
			face,
			{ { text = "QUEUE", cap = 0.6 } },
			nil,
			C.screen
		)
	end
end

-- A side wing (Market or Weapons): floor, walls with the portal opening in the
-- front wall, ceiling. s = -1 for west, 1 for east.
local function sideShell(f: Folder, s: number, floorColor: Color3, wallColor: Color3)
	local near, far = s * 70, s * 124
	local nearIn, farIn = s * 72, s * 122
	box(f, "Floor", nearIn, farIn, -2, 0.02, -24, 24, floorColor)
	box(f, "WallN", near, far, 0, 26, -26, -24, wallColor)
	box(f, "WallS", near, far, 0, 26, 24, 26, wallColor)
	box(f, "WallBack", farIn, far, 0, 26, -26, 26, wallColor)
	box(f, "FrontN", near, nearIn, 0, 26, -24, -13.27, wallColor)
	box(f, "FrontS", near, nearIn, 0, 26, 13.27, 24, wallColor)
	box(f, "FrontLintel", near, nearIn, 16, 26, -13.27, 13.27, wallColor)
	box(f, "Ceiling", near, far, 26, 27, -26, 26, C.concrete)
end

local function buildMarket(f: Folder)
	sideShell(f, -1, C.marketFloor, C.marketWall)
	box(f, "OakRunner", -122, -72, -0.99, 0.08, -6, 6, C.oak, { material = Enum.Material.Wood })
	sign(f, "BattlePassWall", 36, 16, Vector3.new(-121.6, 12, 0), EAST, {
		{ text = "BATTLE PASS", cap = 4.6 },
		{ text = "SEASON 1  ·  TIER TRACK", cap = 1.6, color = Color3.fromRGB(255, 217, 168) },
	}, nil, C.screen)
	local kiosks = {
		{ -86, -74, -24, -18, SOUTH, "SKINS" },
		{ -102, -90, -24, -18, SOUTH, "BUNDLES" },
		{ -86, -74, 18, 24, NORTH, "CURRENCY" },
		{ -102, -90, 18, 24, NORTH, "PASSES + CODES" },
	}
	for _, k in kiosks do
		local x0, x1, z0, z1 = k[1] :: number, k[2] :: number, k[3] :: number, k[4] :: number
		local face = k[5] :: Vector3
		box(f, "Kiosk", x0, x1, 0, 3.5, z0, z1, C.oak, { material = Enum.Material.Wood })
		box(
			f,
			"KioskShelf",
			x0,
			x1,
			3.5,
			8,
			face.Z > 0 and z0 or z1 - 1,
			face.Z > 0 and z0 + 1 or z1,
			C.oak,
			{
				material = Enum.Material.Wood,
			}
		)
		local fz = face.Z > 0 and z0 + 1.2 or z1 - 1.2
		sign(
			f,
			"KioskHeader",
			12,
			2.5,
			Vector3.new((x0 + x1) / 2, 9.5, fz),
			face,
			{ { text = k[6] :: string, cap = 1.6 } }
		)
	end
	for _, z in { -12, 12 } do
		cylinder(f, "FeaturedPodium", -110, z, 4, 0, 3, C.white)
	end
end

local function buildWeapons(f: Folder)
	sideShell(f, 1, C.weaponsFloor, C.weaponsWall)
	for _, t in { { 80, -15 }, { 96, -15 }, { 80, 15 }, { 96, 15 } } do
		local x, z = t[1], t[2]
		cylinder(f, "Turntable", x, z, 6, 0, 2.5, C.white)
		-- Scale stand-in for a rifle shown at display size (~14 studs, about 4x).
		box(
			f,
			"GunStandIn",
			x - 7,
			x + 7,
			7.5,
			10,
			z - 0.6,
			z + 0.6,
			C.steel,
			{ collide = false, shadow = false }
		)
	end
	sign(
		f,
		"HeroRifle",
		28,
		7,
		Vector3.new(121.6, 13.5, 0),
		WEST,
		{ { text = "HERO RIFLE  8×", cap = 2 } },
		nil,
		C.steel
	)
	box(f, "LockerFloor", 104, 122, -1, 0.08, -24, 24, C.locker)
	-- The blade hangs above the sightline from the portal to the hero rifle.
	sign(
		f,
		"LockerBlade",
		10,
		3,
		Vector3.new(104, 18.5, 0),
		WEST,
		{ { text = "LOCKER", cap = 2 } },
		{
			{ text = "LOCKER", cap = 2 },
		}
	)
	cylinder(f, "PreviewPedestal", 113, 0, 4, 0, 1, C.brass, { material = Enum.Material.Metal })
	box(f, "MannequinStandIn", 112, 114, 1, 6, -0.5, 0.5, C.unpowered, { collide = false })
	for _, t in { { -9, SOUTH }, { 9, NORTH } } do
		local z, face = t[1] :: number, t[2] :: Vector3
		box(f, "LockerTerminal", 104.5, 107.5, 0, 5, z - 1.5, z + 1.5, C.steel)
		sign(
			f,
			"LockerTerminalScreen",
			2.5,
			1.6,
			Vector3.new(106, 4, z) + face * 1.6,
			face,
			{ { text = "LOCKER", cap = 0.6 } },
			nil,
			C.screen
		)
	end
end

local function buildRangeWing(f: Folder)
	-- Descent: walls, ceiling, and a 1:4 ramp from y 0 at z 70 down to -8 at z 102.
	box(f, "DescentWallW", -16, -14, -8, 16, 66, 102, C.concrete)
	box(f, "DescentWallE", 14, 16, -8, 16, 66, 102, C.concrete)
	box(f, "DescentCeiling", -16, 16, 16, 17, 66.69, 102, C.concrete)
	local top, bottom = Vector3.new(0, 0, 70), Vector3.new(0, -8, 102)
	local mid = (top + bottom) / 2
	local len = (bottom - top).Magnitude
	make(
		f,
		"Ramp",
		Vector3.new(28, 9, len + 0.5),
		CFrame.lookAt(mid, bottom) * CFrame.new(0, -4.5, 0),
		C.floor
	)

	-- Viewing gallery (floor -8, ceiling 16).
	box(f, "GalleryFloor", -48, 48, -10, -8, 100, 118, C.concrete)
	box(f, "GalleryWallW", -50, -48, -8, 16, 100, 120, C.concrete)
	box(f, "GalleryWallE", 48, 50, -8, 16, 100, 120, C.concrete)
	box(f, "GalleryFrontW", -50, -14, -8, 16, 100, 102, C.concrete)
	box(f, "GalleryFrontE", 14, 50, -8, 16, 100, 102, C.concrete)
	box(f, "GalleryCeiling", -50, 50, 16, 17, 100, 120, C.concrete)

	-- North wall of the range: viewing glass in the middle, a gate each side.
	box(f, "ShellNorthW", -122, -42, -12, 28, 118, 120, C.concrete)
	box(f, "ShellNorthE", 42, 122, -12, 28, 118, 120, C.concrete)
	for _, s in { -1, 1 } do
		box(f, "GateSill", s * 30, s * 42, -12, -8, 118, 120, C.concrete)
		box(f, "GateHead", s * 30, s * 42, 2, 28, 118, 120, C.concrete)
		local gTop, gBottom = Vector3.new(s * 36, -8, 120), Vector3.new(s * 36, -12, 136)
		local gMid = (gTop + gBottom) / 2
		make(
			f,
			"GateRamp",
			Vector3.new(12, 5, (gBottom - gTop).Magnitude + 0.5),
			CFrame.lookAt(gMid, gBottom) * CFrame.new(0, -2.5, 0),
			C.floor
		)
	end
	box(f, "Parapet", -30, 30, -12, -7, 118, 120, C.concrete)
	box(f, "ViewingGlass", -30, 30, -7, 9, 118.8, 119.2, C.glass, {
		material = Enum.Material.Glass,
		transparency = 0.7,
		shadow = false,
	})
	for _, x in { -18, -6, 6, 18 } do
		box(f, "Mullion", x - 0.25, x + 0.25, -7, 9, 118.7, 119.3, C.steel)
	end
	box(f, "GlassHead", -30, 30, 9, 28, 118, 120, C.concrete)
	sign(
		f,
		"EnterHeader",
		12,
		3,
		Vector3.new(-36, 4.5, 117.7),
		NORTH,
		{ { text = "ENTER RANGE", cap = 2.2 } }
	)
	sign(
		f,
		"ExitHeader",
		12,
		3,
		Vector3.new(36, 4.5, 117.7),
		NORTH,
		{ { text = "EXIT (ONE WAY)", cap = 1.6 } }
	)
	sign(
		f,
		"ExitToLobby",
		12,
		3,
		Vector3.new(36, 4.5, 120.3),
		SOUTH,
		{ { text = "EXIT TO LOBBY", cap = 2.2 } }
	)
end

local function buildRangeShell(f: Folder)
	box(f, "Floor", -122, 122, -14, -12, 118, 360, C.range)
	box(f, "WallW", -122, -118, -12, 28, 120, 360, C.concrete)
	box(f, "WallE", 118, 122, -12, 28, 120, 360, C.concrete)
	box(f, "WallS", -118, 118, -12, 28, 356, 360, C.concrete)
	-- Roof with three north-south sun slots over the lanes (free daylight
	-- stripes under the due-south sun).
	box(f, "RoofNorth", -122, 122, 28, 29, 118, 146, C.concrete)
	box(f, "RoofSouth", -122, 122, 28, 29, 316, 360, C.concrete)
	for _, xs in { { -122, -27 }, { -21, -3 }, { 3, 21 }, { 27, 122 } } do
		box(f, "RoofStrip", xs[1], xs[2], 28, 29, 146, 316, C.concrete)
	end
	box(f, "ShooterStrip", -60, 60, -13, -11.94, 120, 146, Color3.fromRGB(195, 199, 204))
	box(f, "Lanes", -42, 42, -13, -11.94, 146, 316, C.lanes)
	box(f, "FiringLine", -42, 42, -11.94, -11.86, 145.6, 146.4, C.duelsRed, { collide = false })
	for i = 1, 6 do
		local x = -42 + 12 * i
		box(
			f,
			"LaneLine",
			x - 0.15,
			x + 0.15,
			-11.94,
			-11.88,
			146,
			316,
			Color3.fromRGB(170, 175, 182),
			{ collide = false }
		)
	end
	box(f, "LaneWallW", -46, -42, -12, 0, 146, 328, C.concrete)
	box(f, "LaneWallE", 42, 46, -12, 0, 146, 328, C.concrete)
	box(f, "Berm", -42, 42, -12, 4, 316, 328, Color3.fromRGB(120, 112, 100))
	-- Distance markers; cap sizes read from the gallery (25 is ~70-75 away).
	local markers = { { 10, 2 }, { 25, 2.6 }, { 50, 3 }, { 100, 4.5 }, { 150, 6.5 } }
	for _, m in markers do
		local d, cap = m[1], m[2]
		local z = 146 + d
		box(
			f,
			"Marker" .. d,
			-42,
			42,
			-11.94,
			-11.86,
			z - 0.25,
			z + 0.25,
			C.white,
			{ collide = false }
		)
		local h = cap / 0.72 + 1
		sign(
			f,
			"MarkerSign" .. d,
			cap * 2.4 + 2,
			h,
			Vector3.new(-44, h / 2, z),
			NORTH,
			{ { text = tostring(d), cap = cap } }
		)
	end
	box(f, "MovementCourse", -118, -60, -13, -11.94, 124, 354, C.course)
	box(f, "CoverYard", 60, 116, -13, -11.94, 146, 210, C.yard)
	sign(
		f,
		"MovementLabel",
		20,
		4,
		Vector3.new(-89, -9, 130),
		NORTH,
		{ { text = "MOVEMENT COURSE", cap = 2 } }
	)
	sign(
		f,
		"YardLabel",
		20,
		4,
		Vector3.new(88, -9, 150),
		NORTH,
		{ { text = "COVER / ABILITY YARD", cap = 1.8 } }
	)
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------

local lobby = workspace:FindFirstChild("Lobby")
if not lobby then
	local folder = Instance.new("Folder")
	folder.Name = "Lobby"
	folder.Parent = workspace
	lobby = folder
end
assert(lobby)
local old = lobby:FindFirstChild("Greybox")
if old then
	old:Destroy()
end

-- The template's baseplate would cover the sunken Range, and its spawn would
-- compete with ours.
for _, name in { "Baseplate", "SpawnLocation" } do
	local inst = workspace:FindFirstChild(name)
	if inst then
		inst:Destroy()
	end
end

local greybox = Instance.new("Folder")
greybox.Name = "Greybox"
greybox.Parent = lobby

local sections: { { name: string, build: (Folder) -> () } } = {
	{ name = "Rotunda", build = buildRotunda },
	{ name = "Ring", build = buildRing },
	{ name = "Wing_Duels", build = buildDuels },
	{ name = "Wing_Market", build = buildMarket },
	{ name = "Wing_Weapons", build = buildWeapons },
	{ name = "Wing_Range", build = buildRangeWing },
	{ name = "RangeShell", build = buildRangeShell },
}
local counts = {}
for _, s in sections do
	local f = Instance.new("Folder")
	f.Name = s.name
	s.build(f)
	f.Parent = greybox
	table.insert(counts, string.format("%s %d", s.name, #f:GetDescendants()))
	task.wait()
end

-- Planned sun (Lobby Art Plan, Lighting): due south, 80 degrees up, so the
-- skylight beam lands on the spawn. Ambient is lifted for the greybox walk only;
-- step 6 sets the real values.
Lighting.ClockTime = 12
Lighting.GeographicLatitude = 33.5
Lighting.Ambient = Color3.fromRGB(105, 105, 110)
Lighting.OutdoorAmbient = Color3.fromRGB(120, 120, 125)

print("LobbyGreybox: built " .. table.concat(counts, ", "))
return counts
