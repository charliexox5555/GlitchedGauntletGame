--!strict
-- Lobby greybox kit: the shared prelude for every greybox script in this folder
-- (vault/02 Art/Lobby Art Plan.md, "Sunwell Bunker"). It holds the colours and
-- the part helpers. It does nothing on its own: bundle.py puts it in front of
-- Hub.luau or a Wing_*.luau body, and the bundle runs in the Studio Command Bar
-- (or through the Studio MCP).
--
-- Coordinates: studs, origin at the rotunda centre on the floor, +X east, -Z
-- north, bearings clockwise from north. Round parts use 11.25 degree pieces.

local Lighting = game:GetService("Lighting")

local LOBBY_PLACE_ID = 133387545285290
assert(game.PlaceId == LOBBY_PLACE_ID, "Lobby greybox: this is not the Lobby place")

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
-- facing the centre (its local -Z points inward). The centre is the origin
-- unless cx/cz are given.
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
	opts: PartOpts?,
	cx: number?,
	cz: number?
): Part
	local ox, oz = cx or 0, cz or 0
	local half = math.rad((b1 - b0) / 2)
	local bm = (b0 + b1) / 2
	local inner = rIn * math.cos(half)
	local width = 2 * rOut * math.sin(half) + 0.1
	local rc = (rOut + inner) / 2
	local x, z = polar(rc, bm)
	local yc = (y0 + y1) / 2
	local pos = Vector3.new(ox + x, yc, oz + z)
	local cf = CFrame.lookAt(pos, Vector3.new(ox, yc, oz))
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
	maxBand: number?,
	cx: number?,
	cz: number?
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
				opts,
				cx,
				cz
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

-- A sloped slab whose top surface runs along the centre line from `top` to
-- `bottom`, `width` wide and `thick` deep (extra thickness hides the underside).
local function ramp(
	parent: Instance,
	name: string,
	top: Vector3,
	bottom: Vector3,
	width: number,
	thick: number,
	color: Color3,
	opts: PartOpts?
): Part
	local mid = (top + bottom) / 2
	local cf = CFrame.lookAt(mid, bottom) * CFrame.new(0, -thick / 2, 0)
	return make(
		parent,
		name,
		Vector3.new(width, thick, (bottom - top).Magnitude + 0.5),
		cf,
		color,
		opts
	)
end

-- A queue pad bay x0..x1 by z0..z1: a deck 1 stud in from the edge at +0.52 and a
-- 1-stud ring around it (Neon in the mode colour when live, grey when dormant).
local function pad(
	f: Instance,
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

-- Section folders are built detached, then swapped in for the old one under
-- Workspace.Lobby.Greybox in a single parent write.
local function greyboxRoot(): Instance
	local lobby = workspace:FindFirstChild("Lobby")
	if not lobby then
		local folder = Instance.new("Folder")
		folder.Name = "Lobby"
		folder.Parent = workspace
		lobby = folder
	end
	assert(lobby)
	local root = lobby:FindFirstChild("Greybox")
	if not root then
		local folder = Instance.new("Folder")
		folder.Name = "Greybox"
		folder.Parent = lobby
		root = folder
	end
	assert(root)
	return root
end

local function newSection(name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	return f
end

-- One line per published section; bundle.py returns it at the end of the run.
local REPORT: { string } = {}

local function publish(f: Folder)
	local root = greyboxRoot()
	local old = root:FindFirstChild(f.Name)
	if old then
		old:Destroy()
	end
	f.Parent = root
	task.wait()
	local line = string.format("%s %d", f.Name, #f:GetDescendants())
	table.insert(REPORT, line)
	print("Lobby greybox: " .. line)
end
