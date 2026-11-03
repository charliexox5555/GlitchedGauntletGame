--!strict
-- Dockyard art pass (vault/01 Design/Maps/Dockyard.md): dresses the greybox with the Blender kit.
-- Needs: the greybox (Greybox.luau) and the kit installed in ServerStorage.MapKit.Dockyard
-- (python tools/studio/maps/kit_bundle.py Dockyard Kit). Bundle:
--   python tools/studio/maps/bundle.py Dockyard Art Lighting -o dockyard_art.luau
-- and run it in the match place, edit mode. Re-runnable: every Art section is rebuilt.
--
-- It reads the greybox parts' attributes (Kind, Lane, Piece, Stack) so the art always follows
-- the layout. Greybox parts the art replaces are hidden (they stay the collision); when a kit
-- piece is missing the greybox part stays visible and the report lists the piece.

local map = newMap("Dockyard", CFrame.new(-1500, 200, 0))
local greybox = layer("Greybox")

local LANE_COLOR: { [string]: Color3 } = {
	west = Color3.fromHex("9A3B2E"),
	mid = Color3.fromHex("2F5E9E"),
	east = Color3.fromHex("3E7D4F"),
}
-- End walls and far stacks: muted, so the lane colours stay the loudest containers.
local WALL_MIX = {
	Color3.fromHex("6E7277"),
	Color3.fromHex("C9C2B0"),
	Color3.fromHex("3B4A63"),
	Color3.fromHex("6B3A33"),
	Color3.fromHex("3C6766"),
	Color3.fromHex("8A8F96"),
	Color3.fromHex("5B6B4F"),
}
local VALUE_JITTER = { 0.9, 1.0, 1.08 }
local rng = Random.new(20261103)

local function shade(c: Color3, k: number): Color3
	return Color3.new(math.min(c.R * k, 1), math.min(c.G * k, 1), math.min(c.B * k, 1))
end

-- Map-space CFrame of a greybox part.
local function mapCF(p: BasePart): CFrame
	return ORIGIN:ToObjectSpace(p.CFrame)
end

-- Lane tint on a kit model: *_Body and *_Stripe take the colour, *_Frame a darker step.
local function tint(m: Model?, color: Color3)
	if not m then
		return
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local n = d.Name
			if string.sub(n, -5) == "_Body" or string.sub(n, -7) == "_Stripe" then
				d.Color = color
			elseif string.sub(n, -6) == "_Frame" then
				d.Color = shade(color, 0.8)
			end
		end
	end
end

local function laneColor(lane: string): Color3
	local c = LANE_COLOR[lane] or LANE_COLOR.mid
	return shade(c, VALUE_JITTER[rng:NextInteger(1, #VALUE_JITTER)])
end

local function wallColor(): Color3
	return WALL_MIX[rng:NextInteger(1, #WALL_MIX)]
end

local secContainers = section("Art", "Containers")
local secYard = section("Art", "Yard")
local secSheds = section("Art", "Sheds")
local secCrane = section("Art", "Crane")
local secQuay = section("Art", "Quay")
local secEnds = section("Art", "EndWalls")
local secSky = section("Art", "Skyline")
local secDeck = section("Art", "Deck")

local parts: { BasePart } = {}
for _, d in greybox:GetDescendants() do
	if d:IsA("BasePart") then
		table.insert(parts, d)
	end
end

local placed = 0
local shedParts: { [string]: { BasePart } } = { A = {}, B = {} }
local craneParts: { BasePart } = {}
local backdrops: { BasePart } = {}

for _, p in parts do
	local kind = p:GetAttribute("Kind")
	local lane = (p:GetAttribute("Lane") :: string?) or "mid"
	local half = (p:GetAttribute("Half") :: string?) or "C"
	local cf = mapCF(p)
	local floor = cf.Y - p.Size.Y / 2
	if kind == "box" then
		local piece = p:GetAttribute("Piece") :: string?
		local stack = (p:GetAttribute("Stack") :: number?) or 1
		local alongX = p.Size.X > p.Size.Z
		local ok = piece ~= nil
		for k = 0, stack - 1 do
			local yaw = (if alongX then 90 else 0) + (if rng:NextNumber() < 0.5 then 180 else 0)
			local m = put(secContainers, piece :: string, at(cf.X, floor + 8 * k, cf.Z, yaw))
			tint(m, laneColor(lane))
			ok = ok and m ~= nil
			placed += if m then 1 else 0
		end
		if ok then
			hide(p)
		end
	elseif kind == "low" then
		if
			put(secYard, "Crate", at(cf.X, floor, cf.Z, if rng:NextNumber() < 0.5 then 0 else 90))
		then
			hide(p)
			placed += 1
		end
	elseif kind == "ramp" then
		-- The stair rises toward its local +Z, like the WedgePart it dresses.
		if put(secYard, "Stair", cf * CFrame.new(0, -p.Size.Y / 2, 0)) then
			hide(p)
			placed += 1
		end
	elseif kind == "rack" then
		if put(secYard, "Rack", at(cf.X, floor, cf.Z, if half == "A" then 180 else 0)) then
			hide(p)
			placed += 1
		end
	elseif kind == "office" then
		if put(secYard, "Office", at(cf.X, floor, cf.Z, if cf.X > 0 then 0 else 180)) then
			hide(p)
			placed += 1
		end
	elseif kind == "wall" or kind == "roof" or kind == "lintel" then
		table.insert(shedParts[if half == "A" then "A" else "B"], p)
	elseif kind == "pillar" or kind == "beam" then
		table.insert(craneParts, p)
	elseif kind == "edge" then
		-- Quay barrier segments (8 long) along the part, bollards on every other one.
		local side = if cf.X > 0 then 1 else -1
		local n = math.floor(p.Size.Z / 8 + 0.5)
		local all = true
		for i = 0, n - 1 do
			local z = cf.Z - p.Size.Z / 2 + 4 + 8 * i
			local m =
				put(secQuay, "QuayBarrier8", at(cf.X + side, floor, z, if side > 0 then 0 else 180))
			all = all and m ~= nil
			if i % 2 == 0 then
				put(secQuay, "Bollard", at(cf.X, floor + 3, z, 0))
			end
		end
		if all then
			hide(p)
			placed += n
		end
	elseif kind == "backdrop" then
		table.insert(backdrops, p)
	elseif kind == "deck" then
		p.Color = Color3.fromRGB(74, 74, 76)
		p.Material = Enum.Material.Asphalt
	end
end

-- The Sheds (one per half) and their name boards.
for _, s in { 1, -1 } do
	local key = if s > 0 then "B" else "A"
	local m = put(secSheds, "Shed", at(55 * s, 0, 42 * s, if s > 0 then 0 else 180), "Shed_" .. key)
	tint(m, if s > 0 then LANE_COLOR.east else LANE_COLOR.west)
	if m then
		for _, p in shedParts[key] do
			hide(p)
		end
		placed += 1
	end
	local board = box(
		secSheds,
		"ShedName_" .. key,
		Vector3.new(12.6, 2.8, 0.1),
		at(55 * s, 17.1, 23.25 * s, if s > 0 then 0 else 180),
		Color3.new(0, 0, 0),
		{ transparency = 1, castShadow = false }
	)
	decor(board)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0.35
	gui.Brightness = 1.5
	gui.PixelsPerStud = 40
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(240, 232, 214)
	label.Text = if s > 0 then "GREEN SHED" else "RED SHED"
	label.Parent = gui
	gui.Parent = board
end

-- The gantry crane over the middle.
if put(secCrane, "Crane", at(0, 0, 0)) then
	for _, p in craneParts do
		hide(p)
	end
	placed += 1
end

-- End walls: 7-high container faces toward the yard and the alcove (map space for the B end;
-- the A end is the same rotated), with a dark filler behind so gaps between boxes read as depth.
local END_FACES: { { x: number, z: number, piece: string, yaw: number } } = {
	{ x = -52, z = 96, piece = "C40", yaw = 90 },
	{ x = -31, z = 100, piece = "C20", yaw = 0 },
	{ x = -22, z = 102, piece = "C20", yaw = 0 },
	{ x = 52, z = 96, piece = "C40", yaw = 90 },
	{ x = 31, z = 100, piece = "C20", yaw = 0 },
	{ x = 22, z = 102, piece = "C20", yaw = 0 },
	{ x = 0, z = 114, piece = "C40", yaw = 90 },
}
local endsOk = true
for _, s in { 1, -1 } do
	for row = 0, 6 do
		for _, f in END_FACES do
			local yaw = f.yaw
				+ (if s < 0 then 180 else 0)
				+ (if rng:NextNumber() < 0.3 then 180 else 0)
			local m = put(secEnds, f.piece, at(f.x * s, 8 * row, f.z * s, yaw))
			tint(m, wallColor())
			endsOk = endsOk and m ~= nil
		end
	end
end
if endsOk then
	for _, p in backdrops do
		local cf = mapCF(p)
		hide(p)
		local filler = box(
			secEnds,
			"Filler",
			p.Size - Vector3.new(1, 1, 1),
			at(cf.X, cf.Y - 0.5, cf.Z),
			Color3.fromRGB(28, 29, 34),
			{ material = Enum.Material.Metal, castShadow = false }
		)
		decor(filler)
	end
end

-- Quay faces all round the deck (8-long segments, the face at the deck edge, water outside).
for _, s in { 1, -1 } do
	for i = 0, 29 do
		put(secQuay, "QuayFace8", at(68 * s, 0, -116 + 8 * i, if s > 0 then 0 else 180))
	end
	for i = 0, 16 do
		put(secQuay, "QuayFace8", at(-64 + 8 * i, 0, 118 * s, if s > 0 then -90 else 90))
	end
end

-- High-mast lamps on the quay barrier (the sodium pools; their SpotLights are in Lighting.luau).
for _, p in { { -67, 40 }, { 67, 84 }, { 67, -40 }, { -67, -84 } } do
	put(secQuay, "LampMast", at(p[1], 3, p[2]))
end

-- Deck markings: yellow bay lines on a 16-stud grid (the containers sit on them).
local yellow = Color3.fromHex("D9B23A")
for x = -64, 64, 16 do
	decor(
		box(
			secDeck,
			"BayLine",
			Vector3.new(0.5, 0.05, 184),
			at(x, 0.025, 0),
			yellow,
			{ castShadow = false }
		)
	)
end
for z = -80, 80, 16 do
	decor(
		box(
			secDeck,
			"BayLine",
			Vector3.new(132, 0.05, 0.5),
			at(0, 0.03, z),
			yellow,
			{ castShadow = false }
		)
	)
end

-- Harbour water (no collision, no queries: a player who goes over the barrier falls through).
local water = box(
	secDeck,
	"Water",
	Vector3.new(2048, 1, 2048),
	at(0, -9.5, 0),
	Color3.fromRGB(30, 42, 68),
	{ material = Enum.Material.SmoothPlastic, castShadow = false }
)
water.Reflectance = 0.3
decor(water)

-- Skyline: far quays with ship-to-shore cranes reaching over a moored container ship (east set;
-- the west set is the same rotated). Keep in step with build_map_kit_dockyard.py (SKY_CRANES ...).
local SKY_CRANES = { { 158, 60, 180 }, { 158, -12, 180 } }
local SHIP_BAYS = { -50, -16, 18 }
local SHIP_ROWS = { -12, -4, 4, 12 }
local SHIP_HEIGHTS = { { 2, 3, 3, 2 }, { 3, 2, 3, 3 }, { 2, 3, 2, 1 } }
local FAR_STACKS = {
	{ 190, -120, 2 },
	{ 190, -86, 3 },
	{ 222, -120, 1 },
	{ 222, 100, 2 },
	{ 190, 120, 3 },
	{ 254, 40, 2 },
}
for _, s in { 1, -1 } do
	local farQuay = box(
		secSky,
		"FarQuay",
		Vector3.new(268, 4, 1000),
		at(266 * s, -10, 0),
		Color3.fromRGB(119, 115, 108),
		{ material = Enum.Material.Concrete, castShadow = false }
	)
	decor(farQuay)
	for _, c in SKY_CRANES do
		put(secSky, "StsCrane", at(c[1] * s, -8, c[2] * s, c[3] + (if s < 0 then 180 else 0)))
	end
	put(secSky, "Ship", at(108 * s, -9, 20 * s, if s > 0 then 0 else 180))
	for bi, bz in SHIP_BAYS do
		for ri, rx in SHIP_ROWS do
			for k = 0, SHIP_HEIGHTS[bi][ri] - 1 do
				tint(
					put(secSky, "C40Lo", at((108 + rx) * s, 9.4 + 8 * k, (20 + bz) * s)),
					wallColor()
				)
			end
		end
	end
	for _, f in FAR_STACKS do
		for k = 0, f[3] - 1 do
			tint(put(secSky, "C40Lo", at(f[1] * s, -8 + 8 * k, f[2] * s, 90)), wallColor())
		end
	end
end

-- Nothing in the art layer collides, is hit by bullets or touches (put and decor do this).
local meshes = 0
for _, d in layer("Art"):GetDescendants() do
	if d:IsA("MeshPart") then
		meshes += 1
	end
end
map:SetAttribute("ArtMeshParts", meshes)
report(
	string.format(
		"Dockyard art: %d greybox pieces dressed, %d MeshParts; %s",
		placed,
		meshes,
		missingReport()
	)
)
