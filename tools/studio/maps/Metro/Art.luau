--!strict
-- Metro art pass (vault/01 Design/Maps/Metro.md): dresses the greybox with the Blender kit group
-- "Station" (tools/blender/build_map_kit_metro.py, asset in art-source/maps/Metro/Exports/assets.json).
-- Run after the greybox and after installing the kit:
--   python tools/studio/maps/kit_bundle.py Metro Station -o metro_kit.luau      (run it first)
--   python tools/studio/maps/bundle.py Metro Greybox Art Lighting -o metro.luau (then this)
-- Re-runnable: it rebuilds Metro.Art.<Section> and re-applies the looks. The greybox stays the
-- collision: parts the kit replaces are hidden (they keep CanCollide/CanQuery), the rest get a
-- finished look. Placements are written for team B's half (+Z, the blue end) and repeated turned
-- 180 degrees for team A's half (the yellow end); parts named *_Band, *_Stripe, *_Trim take the
-- end colour of the half they stand in.

newMap("Metro", CFrame.new(1500, 200, 0))

local BLUE = Color3.fromHex("2F64C8")
local YELLOW = Color3.fromHex("E0A82E")
local MID = Color3.fromHex("2E3440") -- bands on the middle bays (neither end)
local AMBER = Color3.fromHex("FFB547")
local WHITE = Color3.fromHex("F4F4F2")

local SECTIONS = {
	Hall = section("Art", "Hall"),
	Walls = section("Art", "Walls"),
	Ceiling = section("Art", "Ceiling"),
	Track = section("Art", "Track"),
	Trains = section("Art", "Trains"),
	Concourse = section("Art", "Concourse"),
	Corridor = section("Art", "Corridor"),
}

local placed = 0

local function endColour(z: number): Color3
	if z > 0.5 then
		return BLUE
	elseif z < -0.5 then
		return YELLOW
	end
	return MID
end

-- Recolours the end-colour parts of a placed piece.
local function tint(m: Model, colour: Color3)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local n = d.Name
			if
				string.sub(n, -5) == "_Band"
				or string.sub(n, -7) == "_Stripe"
				or string.sub(n, -5) == "_Trim"
			then
				d.Color = colour
			end
		end
	end
end

local function place(
	sec: string,
	piece: string,
	x: number,
	y: number,
	z: number,
	yaw: number
): Model?
	local m = put(SECTIONS[sec], piece, at(x, y, z, yaw))
	if m then
		tint(m, endColour(z))
		placed += 1
	end
	return m
end

-- Team B's placement and its 180-degree partner in team A's half.
local function both(
	sec: string,
	piece: string,
	x: number,
	y: number,
	z: number,
	yaw: number
): { Model }
	local out: { Model } = {}
	local a = place(sec, piece, x, y, z, yaw)
	local b = place(sec, piece, -x, y, -z, yaw + 180)
	if a then
		table.insert(out, a)
	end
	if b then
		table.insert(out, b)
	end
	return out
end

--------------------------------------------------------------------------------
-- Placements (numbers from tools/maps/metro_layout.py)
--------------------------------------------------------------------------------

-- Coffered ceiling over the hall: columns of coffers line up with the platform columns (x ±24),
-- the trench edges (±14) and the centre.
local COFFER_X = { { -29, 10 }, { -19, 10 }, { -7, 14 }, { 7, 14 }, { 19, 10 }, { 29, 10 } }
for z = -44, 44, 8 do
	for _, c in COFFER_X do
		local m = put(SECTIONS.Ceiling, "Coffer" .. c[2], at(c[1], 0, z))
		if m then
			placed += 1
		end
	end
end

-- Hall walls: 8-stud bays (east wall listed; the west wall is its rotation), the service doors at the
-- middle and at the far end, 4-stud end bays, the station name on the band.
for zc = -40, 40, 8 do
	local isDoor = zc == 0 or zc == -40
	place("Walls", if isDoor then "WallDoor8" else "WallBay8", 34, 0, zc, 180)
	place("Walls", if isDoor then "WallDoor8" else "WallBay8", -34, 0, -zc, 0)
end
both("Walls", "WallEnd4", 34, 0, 46, 180)
both("Walls", "WallEnd4", 34, 0, -46, 180)
both("Walls", "NameSign", -34, 0, 16, 0)
both("Walls", "NameSign", 34, 0, 24, 180)

-- Platform furniture.
for _, p in { { 24, 24 }, { 24, 40 }, { -24, 8 }, { -24, 24 }, { -24, 40 } } do
	both("Hall", "Column", p[1], 0, p[2], 0)
end
both("Hall", "Kiosk", 24, 0, 8, 0)
both("Hall", "Vending", 34, 0, 18, 180)
both("Hall", "Bench", -34, 0, 16, 0)
for zc = -44, 44, 8 do
	-- under team A's hall stairs (x 14..22, z -48..-26) the edge has no tactile strip
	local plain = zc == -28 or zc == -36 or zc == -44
	both("Hall", if plain then "PlatformEdge8Plain" else "PlatformEdge8", 14, 0, zc, 180)
end
for _, x in { 18, 30, -18, -30 } do
	for _, z in { 16, 32 } do
		both("Hall", "PendantLight", x, 0, z, 0)
	end
end
place("Hall", "Gantry", 0, 0, 0, 0)
both("Hall", "EndWall", 0, 0, 48, 0)
both("Hall", "EscalatorBank", 29.5, 0, 48, 0)
both("Hall", "HallStairs", -18, 0, 26, 0)

-- Track bed (both tracks: each listed track's rotation is the other) and the trains.
for zc = -48, 48, 8 do
	both("Track", "TrackBay8", 8.5, -4, zc, 0)
end
both("Track", "TrackBox", -14, -4, 32, 0)
-- One two-section unit per track, its centre at z 20 (team B's runs z -6..46 on the east track).
both("Trains", "Train", 8.5, 0, 20, 0)

-- Concourse: portals, fare gates, ticket office, spawn doors, pendant lights over the ticket hall.
both("Concourse", "Portal10", -9, 14, 67, 0)
both("Concourse", "Portal10", 9, 14, 67, 0)
both("Concourse", "FareGateRow", -20, 14, 82.75, 0)
both("Concourse", "FareGateRow", 20, 14, 82.75, 0)
both("Concourse", "TicketOffice", -38, 14, 97, 0)
both("Concourse", "DoorFrame8", -10, 14, 106.5, 0)
both("Concourse", "DoorFrame8", 10, 14, 106.5, 0)
for _, x in { -26, -8, 8, 26 } do
	for _, z in { 76, 92 } do
		both("Concourse", "PendantLight", x, 0, z, 0)
	end
end

-- Service corridors: pipes and lights on the outer wall, doors on the pump rooms, the stair.
for zc = -44, 44, 8 do
	if math.abs(zc - 19) > 8 then -- the pump room block stands against the outer wall at z 14..24
		both("Corridor", "PipeRun8", 48, 0, zc, 180)
	end
end
for _, zc in { -40, -8, 36 } do
	both("Corridor", "CorridorLight", 48, 0, zc, 180)
end
both("Corridor", "PumpDoor", 42, 0, 19, 180)
both("Corridor", "PumpDoor", 42, 0, -19, 0)
both("Corridor", "CorridorStair", 42, 0, 48, 0)

--------------------------------------------------------------------------------
-- Greybox: hide what the kit replaced, finish what stays visible
--------------------------------------------------------------------------------

local HIDE: { [string]: boolean } = {
	HallCeiling = true,
	Gantry = true,
	GantryClock = true,
	Column = true,
	Kiosk = true,
	Vending = true,
	Bench = true,
	TrackBox = true,
	Parapet = true,
	NamePanel = true,
	FareGates = true,
	TicketOffice = true,
	Escalator = true,
	HallStairs = true,
	CorridorStair = true,
	EscalatorRail = false,
}

type Finish = { material: Enum.Material, color: Color3 }
local function F(material: Enum.Material, hex: string): Finish
	return { material = material, color = Color3.fromHex(hex) }
end
local GRANITE = F(Enum.Material.Granite, "A8A49C")
local CONCRETE = F(Enum.Material.Concrete, "A7A49D")
local CONCRETE_DARK = F(Enum.Material.Concrete, "6B6A68")
local TILE = F(Enum.Material.CeramicTiles, "E7E6E1")
local STEEL = F(Enum.Material.Metal, "22252A")
local FINISH: { [string]: Finish } = {
	PlatformEast = GRANITE,
	TerraceBlock = GRANITE,
	TerraceFront = GRANITE,
	TicketFloor = GRANITE,
	SpawnFloor = GRANITE,
	TrenchFloor = F(Enum.Material.Concrete, "57575A"),
	PortalLintel = CONCRETE,
	CorridorFloor = CONCRETE_DARK,
	StairBase = CONCRETE_DARK,
	EscalatorBase = CONCRETE_DARK,
	DoorSill = STEEL,
	HallWallEast = F(Enum.Material.Concrete, "8E8C87"),
	OuterWallEast = F(Enum.Material.Concrete, "8E8C87"),
	CorridorCeiling = CONCRETE_DARK,
	CorridorHead = F(Enum.Material.Concrete, "8E8C87"),
	PumpRoom = F(Enum.Material.Concrete, "7E7C78"),
	WellDivider = TILE,
	WingWall = TILE,
	ConcourseWall = TILE,
	PortalHead = TILE,
	TicketWallNorth = TILE,
	ConcourseCeiling = CONCRETE,
	SpawnWall = TILE,
	SpawnBaffle = TILE,
	SpawnLintel = TILE,
	EscalatorRail = STEEL,
}

local hidden, finished = 0, 0
local greybox = layer("Greybox")
for _, d in greybox:GetDescendants() do
	if not d:IsA("BasePart") then
		continue
	end
	if d.Parent and d.Parent.Name == "Train" or HIDE[d.Name] then
		hide(d)
		if d.Name == "HallCeiling" then
			d.CastShadow = true -- invisible, still keeps the hall in shade
		end
		hidden += 1
		continue
	end
	local f = FINISH[d.Name]
	if f then
		d.Material = f.material
		d.Color = f.color
		finished += 1
	end
end

--------------------------------------------------------------------------------
-- Signs and boards (SurfaceGuis on the kit's sign faces)
--------------------------------------------------------------------------------

-- The face of `part` that points most along the world direction `dir`.
local function faceToward(part: BasePart, dir: Vector3): Enum.NormalId
	local best, bestDot = Enum.NormalId.Front, -math.huge
	for _, n in Enum.NormalId:GetEnumItems() do
		local w = part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(n))
		local dot = w:Dot(dir)
		if dot > bestDot then
			best, bestDot = n, dot
		end
	end
	return best
end

local function gui(part: BasePart, face: Enum.NormalId, pps: number?): SurfaceGui
	local name = "Sign_" .. face.Name
	local old = part:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local g = Instance.new("SurfaceGui")
	g.Name = name
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = pps or 40
	g.LightInfluence = 0
	g.Brightness = 1.6
	g.Adornee = part
	g.Parent = part
	return g
end

local function label(
	parent: Instance,
	text: string,
	pos: UDim2,
	size: UDim2,
	colour: Color3,
	font: Enum.Font?
): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Position = pos
	t.Size = size
	t.Text = text
	t.TextScaled = true
	t.Font = font or Enum.Font.GothamBlack
	t.TextColor3 = colour
	t.Parent = parent
	return t
end

local signs = 0
local function eachPart(sec: string, name: string, fn: (BasePart) -> ())
	for _, d in SECTIONS[sec]:GetDescendants() do
		if d:IsA("BasePart") and d.Name == name then
			fn(d)
		end
	end
end

local mapCentre = W(CFrame.identity).Position

-- Station name: the panels over the tunnel portals and on the wall bands face the hall centre.
local function towardCentre(p: BasePart): Vector3
	local v = mapCentre - p.CFrame.Position
	return Vector3.new(v.X, 0, v.Z).Unit
end
eachPart("Hall", "EndWall_PanelTrim", function(p)
	local g = gui(p, faceToward(p, towardCentre(p)), 24)
	label(g, "MERIDIAN", UDim2.fromScale(0.16, 0.14), UDim2.fromScale(0.68, 0.72), WHITE)
	signs += 1
end)
-- The wall-band signs face across the hall (their wall is at x = 34 or -34).
eachPart("Walls", "NameSign_Face", function(p)
	local g =
		gui(p, faceToward(p, Vector3.new(-math.sign((p.CFrame.Position - mapCentre).X), 0, 0)), 24)
	label(g, "MERIDIAN", UDim2.fromScale(0.08, 0.1), UDim2.fromScale(0.84, 0.8), WHITE)
	signs += 1
end)

-- Departure board: three rows on the centre screen, the platform names on the side screens.
eachPart("Hall", "Gantry_Screen", function(p)
	for _, dir in { Vector3.zAxis, -Vector3.zAxis } do
		local face = faceToward(p, dir)
		local g = gui(p, face, 30)
		-- GUI right edge in world X: on the face toward +Z the viewer's right is -X.
		local rightX = (-dir):Cross(Vector3.yAxis).X
		local width = 62
		local centre = Instance.new("Frame")
		centre.BackgroundTransparency = 1
		centre.Position = UDim2.fromScale((31 - 12) / width, 0)
		centre.Size = UDim2.fromScale(24 / width, 1)
		centre.Parent = g
		label(
			centre,
			"DEPARTURES",
			UDim2.fromScale(0.3, 0.05),
			UDim2.fromScale(0.4, 0.18),
			WHITE,
			Enum.Font.GothamBold
		)
		local rows = {
			{ "1", "NORTHGATE", "2 min" },
			{ "2", "RIVERSIDE", "4 min" },
			{ "1", "NORTHGATE", "9 min" },
		}
		for i, r in rows do
			local y = 0.3 + (i - 1) * 0.22
			label(
				centre,
				r[1],
				UDim2.fromScale(0.04, y),
				UDim2.fromScale(0.08, 0.17),
				AMBER,
				Enum.Font.RobotoMono
			)
			label(
				centre,
				r[2],
				UDim2.fromScale(0.16, y),
				UDim2.fromScale(0.5, 0.17),
				AMBER,
				Enum.Font.RobotoMono
			).TextXAlignment =
				Enum.TextXAlignment.Left
			label(
				centre,
				r[3],
				UDim2.fromScale(0.72, y),
				UDim2.fromScale(0.24, 0.17),
				AMBER,
				Enum.Font.RobotoMono
			).TextXAlignment =
				Enum.TextXAlignment.Right
		end
		-- Side screens: the platform on the viewer's left first.
		local leftName = if rightX > 0 then "PLATFORM 2" else "PLATFORM 1" -- the east platform is 1
		local rightName = if rightX > 0 then "PLATFORM 1" else "PLATFORM 2"
		label(g, leftName, UDim2.fromScale(0.0, 0.25), UDim2.fromScale(14 / width, 0.4), WHITE)
		label(
			g,
			rightName,
			UDim2.fromScale(1 - 14 / width, 0.25),
			UDim2.fromScale(14 / width, 0.4),
			WHITE
		)
		signs += 1
	end
end)

-- Smaller signs. `axis` is the sign's thin local axis; two-sided signs get text on both faces, the
-- others only on the face toward the hall centre.
local function simple(
	sec: string,
	part: string,
	text: string,
	colour: Color3,
	axis: Enum.NormalId,
	two: boolean
)
	eachPart(sec, part, function(p)
		local n = p.CFrame:VectorToWorldSpace(Vector3.FromNormalId(axis))
		local dirs = if two then { n, -n } else { if n:Dot(towardCentre(p)) >= 0 then n else -n }
		for _, dir in dirs do
			local g = gui(p, faceToward(p, dir), 30)
			label(g, text, UDim2.fromScale(0.06, 0.12), UDim2.fromScale(0.88, 0.76), colour)
			signs += 1
		end
	end)
end
local INK = Color3.fromHex("2A1E12")
simple("Hall", "Kiosk_Sign_Glow", "COFFEE · NEWS", INK, Enum.NormalId.Right, true)
simple("Concourse", "TicketOffice_Sign_Glow", "TICKETS", INK, Enum.NormalId.Right, false)
simple(
	"Concourse",
	"Portal10_Sign_Glow",
	"PLATFORMS",
	Color3.fromHex("1C2030"),
	Enum.NormalId.Back,
	true
)
simple(
	"Walls",
	"WallDoor8_Sign_Glow",
	"SERVICE",
	Color3.fromHex("0E2A18"),
	Enum.NormalId.Right,
	false
)
simple("Hall", "EndWall_MouthSign", "PLATFORM 1  ·  EXIT", WHITE, Enum.NormalId.Back, false)

-- Spawn rooms: a big end letter on the back wall.
for _, d in greybox:GetDescendants() do
	if d:IsA("BasePart") and d.Name == "SpawnWall" and d.Size.X > 20 then
		local z = (d.CFrame.Position - mapCentre).Z
		local g = gui(d, faceToward(d, Vector3.new(0, 0, -math.sign(z))), 10)
		g.Brightness = 1
		local letter = label(
			g,
			if z > 0 then "B" else "A",
			UDim2.fromScale(0.35, 0.12),
			UDim2.fromScale(0.3, 0.7),
			if z > 0 then BLUE else YELLOW
		)
		letter.TextStrokeTransparency = 1
		signs += 1
	end
end

-- The gantry trim is neither end's: warm amber like the board.
eachPart("Hall", "Gantry_Trim", function(p)
	p.Color = AMBER
end)

report(
	string.format(
		"Metro art: %d pieces placed, %d greybox parts hidden, %d finished, %d signs; %s",
		placed,
		hidden,
		finished,
		signs,
		missingReport()
	)
)
