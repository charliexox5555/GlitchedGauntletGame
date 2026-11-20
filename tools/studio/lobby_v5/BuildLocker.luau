--!nocheck
-- Lobby V5 LOCKER room (vault/02 Art/Lobby V5 Plan.md, "Locker room"). ONE-TIME placement record run through the
-- Studio MCP: opens the hub's armoury frame (removes its doors, transom and back block) and rebuilds
-- Workspace.LobbyV5.Shell.Locker. Concept: third-party/lobby-v5-concepts/03 (pegboard gun walls behind mesh, a
-- central bench with a turntable). Hooks reused, no new code: `LobbyGunDisplay` anchors (each player's own skins,
-- LobbyGunDisplays.luau), a `LobbyLocker` prompt part (WorldPrompts opens the Locker menu), the `LobbyNPC` Armorer.
-- Every piece is its own Part; lockers, tables, racks and lamps are their own Models.

local CS = game:GetService("CollectionService")
local MS = game:GetService("MaterialService")
local O = Vector3.new(0, 0, -1600)
local UP = Vector3.yAxis
local hub = workspace.LobbyV5.Shell.Hub

local function variant(name)
	for _, v in MS:GetDescendants() do
		if v:IsA("MaterialVariant") and v.Name == name then
			return v
		end
	end
	error("missing " .. name)
end
local function look(var, col, mat)
	if var then
		return { mat = variant(var).BaseMaterial, var = var, col = col }
	end
	return { mat = mat or Enum.Material.SmoothPlastic, col = col }
end
local L = {
	board = look("Lobby_ConcreteBoard", Color3.fromRGB(118, 116, 112)),
	trim = look("Concrete-02a", Color3.fromRGB(128, 126, 123)),
	wains = look("Concrete-02a", Color3.fromRGB(88, 87, 85)),
	darkConc = look("Concrete-02a", Color3.fromRGB(62, 62, 64)),
	floor = look("Lobby_ConcretePolished", Color3.fromRGB(98, 96, 93)),
	steel = look("Metal 2022", Color3.fromRGB(120, 122, 126)),
	dark = look("Metal 2022", Color3.fromRGB(52, 54, 58)),
	diamond = look("Diamond Plate 2022", Color3.fromRGB(104, 106, 110)),
	locker = look("Metal 2022", Color3.fromRGB(58, 61, 66)),
	door = look("Metal 2022", Color3.fromRGB(92, 100, 80)), -- muted olive: the room's colour
	pad = look(nil, Color3.fromRGB(46, 46, 50), Enum.Material.Fabric),
	mat = look(nil, Color3.fromRGB(40, 41, 44), Enum.Material.Rubber),
	paint = look(nil, Color3.fromRGB(196, 152, 34), Enum.Material.SmoothPlastic),
	white = look(nil, Color3.fromRGB(126, 120, 112), Enum.Material.Neon),
	face = look(nil, Color3.fromRGB(236, 234, 228), Enum.Material.SmoothPlastic),
	peg = look(nil, Color3.fromRGB(150, 147, 141), Enum.Material.SmoothPlastic),
	slot = look(nil, Color3.fromRGB(24, 24, 26), Enum.Material.SmoothPlastic),
}
local RUBIK = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy)
local TEX = { hazard = "rbxassetid://75158634706115", peg = "rbxassetid://120794687026437", mesh = "rbxassetid://79156982233553" }
local WHITE = Color3.fromRGB(255, 244, 228)
local WARM = Color3.fromRGB(255, 214, 170)

local function part(parent, name, size, cf, lk, cls)
	local p = Instance.new(cls or "Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Material = lk.mat
	if lk.var then
		p.MaterialVariant = lk.var
	end
	p.Color = lk.col
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local function box(parent, name, a, b, lk)
	local lo, hi = a:Min(b), a:Max(b)
	return part(parent, name, hi - lo, CFrame.new(O + (lo + hi) / 2), lk)
end
local function tri(parent, name, p, u, a, v, b, w, th, lk)
	local X, Y = w.Unit, u.Unit
	if X:Cross(Y):Dot(-v.Unit) < 0 then
		X = -X
	end
	return part(parent, name, Vector3.new(th, a, b), CFrame.fromMatrix(O + p + u.Unit * a / 2 + v.Unit * b / 2, X, Y), lk, "WedgePart")
end
local function model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end
local function texture(p, face, id, tile)
	local t = Instance.new("Texture")
	t.Face = face
	t.Texture = id
	t.StudsPerTileU = tile
	t.StudsPerTileV = tile
	t.Parent = p
	return t
end
local function state(inst, name, encoded) -- StateValues: "s" text, "n" number
	local f = inst:FindFirstChild("GauntletState") or Instance.new("Folder")
	f.Name = "GauntletState"
	f.Parent = inst
	local v = Instance.new("StringValue")
	v.Name = name
	v.Value = encoded
	v.Parent = f
end
local function anchorPart(parent, name, pos)
	local p = part(parent, name, Vector3.new(1, 1, 1), CFrame.new(O + pos), look(nil, Color3.new(0, 1, 0)))
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end
-- a gun display anchor: Roblox barrel / face directions converted to the Blender axes the client reads
local function gunAnchor(parent, name, pos, gun, mount, barrel, face, scale, fill, spin)
	local a = anchorPart(parent, name, pos)
	state(a, "Gun", "s" .. gun)
	state(a, "Mount", "s" .. mount)
	state(a, "BX", "n" .. barrel.X)
	state(a, "BY", "n" .. -barrel.Z)
	state(a, "BZ", "n" .. barrel.Y)
	state(a, "FX", "n" .. face.X)
	state(a, "FY", "n" .. -face.Z)
	state(a, "FZ", "n" .. face.Y)
	state(a, "Scale", "n" .. scale)
	state(a, "Fill", "n" .. fill)
	if spin then
		state(a, "Spin", "n" .. spin)
	end
	CS:AddTag(a, "LobbyGunDisplay")
	return a
end
local function spot(parent, lensPart, face, col, bright, range, angle)
	local s = Instance.new("SpotLight")
	s.Face = face
	s.Color = col
	s.Brightness = bright
	s.Range = range
	s.Angle = angle
	s.Parent = lensPart
end

---------------------------------------------------------------------------------------------------
-- open the hub's armoury frame
for _, n in { "Door_N", "Door_S", "DoorGap", "Transom", "Back" } do
	local p = hub.Armoury:FindFirstChild(n)
	if p then
		p:Destroy()
	end
end
local shell = workspace.LobbyV5.Shell
local old = shell:FindFirstChild("Locker")
if old then
	old:Destroy()
end
local locker = model(shell, "Locker")

local RX0, RX1, RZ, RH = 55, 103, 22, 18 -- room interior: x 55..103, z -22..22, y 0..18

-- 1. VESTIBULE (x 46..55) continuing the frame's cut-corner profile ------------------------------------
local vest = model(locker, "Vestibule")
box(vest, "Threshold", Vector3.new(46, 0, -7), Vector3.new(55, 0.06, 7), L.diamond)
box(vest, "Wall_N", Vector3.new(46, 0, -9), Vector3.new(55, 15, -7), L.darkConc)
box(vest, "Wall_S", Vector3.new(46, 0, 7), Vector3.new(55, 15, 9), L.darkConc)
box(vest, "Ceiling", Vector3.new(46, 15, -9), Vector3.new(55, 16.5, 9), L.darkConc)
for _, s in { -1, 1 } do
	tri(vest, "Cut", Vector3.new(50.5, 15, 7 * s), Vector3.new(0, -1, 0), 3, Vector3.new(0, 0, -s), 3, Vector3.xAxis, 9, L.darkConc)
end
local vl = model(vest, "Light")
box(vl, "Housing", Vector3.new(48.5, 14.4, -2.5), Vector3.new(52.5, 15, 2.5), L.dark)
spot(vl, box(vl, "Lens", Vector3.new(48.8, 14.32, -2.2), Vector3.new(52.2, 14.4, 2.2), L.white), Enum.NormalId.Bottom, WHITE, 2, 18, 110)
box(locker, "FloorLink", Vector3.new(52, -2, -9), Vector3.new(54, 0, 9), L.floor) -- hub floor stops at x 52, the room floor starts at 54

-- 2. ROOM SHELL --------------------------------------------------------------------------------------
local room = model(locker, "Room")
box(room, "Floor", Vector3.new(RX0 - 1, -2, -RZ - 1), Vector3.new(RX1 + 1, 0, RZ + 1), L.floor)
box(room, "Ceiling", Vector3.new(RX0 - 1, RH, -RZ - 1), Vector3.new(RX1 + 1, RH + 1, RZ + 1), L.darkConc)
box(room, "Wall_E", Vector3.new(RX1, 0, -RZ - 1), Vector3.new(RX1 + 1, RH, RZ + 1), L.board)
box(room, "Wall_N", Vector3.new(RX0 - 1, 0, -RZ - 1), Vector3.new(RX1, RH, -RZ), L.board)
box(room, "Wall_S", Vector3.new(RX0 - 1, 0, RZ), Vector3.new(RX1, RH, RZ + 1), L.board)
box(room, "Wall_W_N", Vector3.new(RX0 - 1, 0, -RZ), Vector3.new(RX0, RH, -9), L.board)
box(room, "Wall_W_S", Vector3.new(RX0 - 1, 0, 9), Vector3.new(RX0, RH, RZ), L.board)
box(room, "Wall_W_Top", Vector3.new(RX0 - 1, 16.5, -9), Vector3.new(RX0, RH, 9), L.board) -- above the vestibule ceiling (no shared face)
-- wainscot on the west wall either side of the door
for _, z in { { -RZ, -9 }, { 9, RZ } } do
	box(room, "Wainscot", Vector3.new(RX0, 0, z[1]), Vector3.new(RX0 + 0.5, 3, z[2]), L.wains)
	tri(room, "WainscotSlope", Vector3.new(RX0, 3, (z[1] + z[2]) / 2), Vector3.new(0, 1, 0), 0.5, Vector3.new(1, 0, 0), 0.5, Vector3.zAxis, z[2] - z[1], L.wains) -- slope faces the room
end
-- dropped soffit round the ceiling with a lit cove (neon strips on its top lighting the ceiling)
local soff = model(room, "Soffit")
local SY0, SY1 = 15.5, 17
for _, s in {
	{ "N", Vector3.new(RX0, SY0, -RZ), Vector3.new(RX1, SY1, -RZ + 3) },
	{ "S", Vector3.new(RX0, SY0, RZ - 3), Vector3.new(RX1, SY1, RZ) },
	{ "W", Vector3.new(RX0, SY0, -RZ + 3), Vector3.new(RX0 + 3, SY1, RZ - 3) },
	{ "E", Vector3.new(RX1 - 3, SY0, -RZ + 3), Vector3.new(RX1, SY1, RZ - 3) },
} do
	box(soff, "Band_" .. s[1], s[2], s[3], L.trim)
end
for _, c in {
	{ Vector3.new(RX0 + 3.2, SY1, -RZ + 2.6), Vector3.new(RX1 - 3.2, SY1 + 0.1, -RZ + 2.8) },
	{ Vector3.new(RX0 + 3.2, SY1, RZ - 2.8), Vector3.new(RX1 - 3.2, SY1 + 0.1, RZ - 2.6) },
	{ Vector3.new(RX0 + 2.6, SY1, -RZ + 3.2), Vector3.new(RX0 + 2.8, SY1 + 0.1, RZ - 3.2) },
	{ Vector3.new(RX1 - 2.8, SY1, -RZ + 3.2), Vector3.new(RX1 - 2.6, SY1 + 0.1, RZ - 3.2) },
} do
	local cove = box(soff, "Cove", c[1], c[2], L.white)
	cove.CastShadow = false
	spot(soff, cove, Enum.NormalId.Top, WARM, 2, 10, 150)
end
-- ceiling light panels
for _, x in { 67, 91 } do
	for _, z in { -8, 8 } do
		local m = model(room, "CeilingLight")
		box(m, "Frame", Vector3.new(x - 3.2, RH - 0.5, z - 2.2), Vector3.new(x + 3.2, RH, z + 2.2), L.dark)
		local lens = box(m, "Lens", Vector3.new(x - 2.8, RH - 0.58, z - 1.8), Vector3.new(x + 2.8, RH - 0.5, z + 1.8), L.white)
		spot(m, lens, Enum.NormalId.Bottom, Color3.fromRGB(255, 236, 214), 2.3, 30, 120)
	end
end

-- warm fill (no shadows) so the room never drops to the cold ambient
for _, x in { 67, 91 } do
	local p = anchorPart(room, "Fill", Vector3.new(x, 10, 0))
	local pl = Instance.new("PointLight")
	pl.Color = WARM
	pl.Brightness = 0.8
	pl.Range = 36
	pl.Shadows = false
	pl.Parent = p
end

-- 3. GUN WALL (east): pegboard in a steel frame, mesh cages either side, 9 hung guns, a lightbox sign ------
local gw = model(locker, "GunWall")
local PX = RX1 - 0.4 -- pegboard face
local peg = box(gw, "Pegboard", Vector3.new(PX, 2.5, -14.5), Vector3.new(RX1, 13.5, 14.5), L.peg)
texture(peg, Enum.NormalId.Left, TEX.peg, 1).Color3 = Color3.fromRGB(150, 148, 144) -- tinted: the light image blew out under the spots
for _, f in {
	{ Vector3.new(PX - 0.4, 13.5, -15.1), Vector3.new(RX1, 14.1, 15.1) },
	{ Vector3.new(PX - 0.4, 1.9, -15.1), Vector3.new(RX1, 2.5, 15.1) },
	{ Vector3.new(PX - 0.4, 2.5, -15.1), Vector3.new(RX1, 13.5, -14.5) },
	{ Vector3.new(PX - 0.4, 2.5, 14.5), Vector3.new(RX1, 13.5, 15.1) },
} do
	box(gw, "Frame", f[1], f[2], L.steel)
end
local GUNS_WALL = { "Bulldog", "Guardian", "Stinger", "Ares", "Ghost", "Marshal", "Bucky", "Shorty", "Outlaw" }
local i = 0
for _, y in { 11, 8, 5 } do
	for _, z in { -9, 0, 9 } do
		i += 1
		gunAnchor(gw, "Wall_" .. GUNS_WALL[i], Vector3.new(PX - 0.02, y, z), GUNS_WALL[i], "Wall", Vector3.new(0, 0, -1), Vector3.new(-1, 0, 0), 1.9, 5.9)
		for _, dz in { -1.6, 1.6 } do -- two pegs under each gun
			box(gw, "Peg", Vector3.new(PX - 0.6, y - 0.95, z + dz - 0.12), Vector3.new(PX, y - 0.75, z + dz + 0.12), L.dark)
		end
	end
end
for _, s in { -1, 1 } do -- mesh cages with shelves of cases behind them
	local cage = model(gw, s < 0 and "Cage_N" or "Cage_S")
	local za, zb = s < 0 and -RZ or 15.6, s < 0 and -15.6 or RZ
	local front = RX1 - 2.6
	for _, f in {
		{ Vector3.new(front - 0.3, 0, za), Vector3.new(front, 15, za + 0.4) },
		{ Vector3.new(front - 0.3, 0, zb - 0.4), Vector3.new(front, 15, zb) },
		{ Vector3.new(front - 0.3, 14.6, za), Vector3.new(front, 15, zb) },
		{ Vector3.new(front - 0.3, 0, za), Vector3.new(front, 0.4, zb) },
	} do
		box(cage, "Frame", f[1], f[2], L.dark)
	end
	local mesh = box(cage, "Mesh", Vector3.new(front - 0.2, 0.4, za + 0.4), Vector3.new(front - 0.1, 14.6, zb - 0.4), L.steel)
	mesh.Transparency = 1
	texture(mesh, Enum.NormalId.Left, TEX.mesh, 1)
	texture(mesh, Enum.NormalId.Right, TEX.mesh, 1)
	box(cage, "Back", Vector3.new(RX1 - 0.3, 0, za), Vector3.new(RX1, 15, zb), L.dark)
	box(cage, "Roof", Vector3.new(front, 14.6, za), Vector3.new(RX1, 15, zb), L.dark)
	for _, y in { 4.5, 9 } do
		box(cage, "Shelf", Vector3.new(front + 0.2, y - 0.2, za + 0.4), Vector3.new(RX1 - 0.3, y, zb - 0.4), L.steel)
		for k = 0, 1 do
			local zc = za + 1.4 + k * 2.6
			box(cage, "Case", Vector3.new(front + 0.6, y, zc - 1), Vector3.new(front + 2.0, y + 1.3, zc + 1), L.locker)
			box(cage, "CaseLatch", Vector3.new(front + 0.5, y + 0.8, zc - 0.25), Vector3.new(front + 0.6, y + 1.1, zc + 0.25), L.paint)
		end
	end
end
-- lightbox sign over the gun wall (same build as the duels signs)
do
	local sign = model(gw, "Sign")
	local W, H = 14, 3.4
	local c = O + Vector3.new(RX1 - 3.4, 16.2, 0) -- on the soffit's face, clear of the pegboard frame
	local S = CFrame.lookAt(c, c - Vector3.xAxis)
	part(sign, "Case", Vector3.new(W, H, 0.8), S, L.dark)
	local face = part(sign, "Face", Vector3.new(W - 1, H - 0.8, 0.06), S * CFrame.new(0, 0, -0.43), L.face)
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 20
	g.LightInfluence = 0
	g.Parent = face
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(240, 238, 232)
	bg.BorderSizePixel = 0
	bg.Parent = g
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(0.9, 0.8)
	t.Position = UDim2.fromScale(0.05, 0.1)
	t.FontFace = RUBIK
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(28, 28, 32)
	t.Text = "LOCKER"
	t.Parent = bg
	local sl = Instance.new("SurfaceLight")
	sl.Face = Enum.NormalId.Front
	sl.Color = WHITE
	sl.Brightness = 0.8
	sl.Range = 10
	sl.Parent = face
end
-- spots onto the gun wall
for _, z in { -9, 0, 9 } do
	local m = model(gw, "WallSpot")
	local F = CFrame.lookAt(O + Vector3.new(RX1 - 7, RH - 0.8, z), O + Vector3.new(RX1, 8, z))
	box(m, "Mount", Vector3.new(RX1 - 7.4, RH - 0.4, z - 0.4), Vector3.new(RX1 - 6.6, RH, z + 0.4), L.dark)
	part(m, "Housing", Vector3.new(1.2, 1.2, 1.4), F, L.dark)
	local lens = part(m, "Lens", Vector3.new(0.9, 0.9, 0.06), F * CFrame.new(0, 0, -0.73), L.white)
	spot(m, lens, Enum.NormalId.Front, WHITE, 0.9, 16, 55)
end

-- 4. LOCKERS along the north and south walls, padded benches in front -------------------------------
local lockers = model(locker, "Lockers")
local num = 0
for _, side in { -1, 1 } do
	local zw = side * RZ -- wall face
	local n = -side -- the lockers face into the room
	local row = model(lockers, side < 0 and "Row_N" or "Row_S")
	local D = 1.8
	local zf = zw + n * D -- front face
	for k = 0, 17 do
		num += 1
		local x0 = 57.2 + k * 2.2
		local x1 = x0 + 2.2
		local m = model(row, ("Locker_%02d"):format(num))
		local za, zb = math.min(zw, zf), math.max(zw, zf)
		box(m, "Plinth", Vector3.new(x0 + 0.1, 0, za + (side < 0 and 0 or 0.15)), Vector3.new(x1 - 0.1, 0.4, zb - (side < 0 and 0.15 or 0)), L.dark)
		box(m, "Body", Vector3.new(x0, 0.4, za), Vector3.new(x1, 7.8, zb), L.locker)
		-- sloped top (angled plate back up to the wall)
		tri(m, "Crown", Vector3.new((x0 + x1) / 2, 7.8, zw), Vector3.new(0, 1, 0), 0.9, Vector3.new(0, 0, n), D, Vector3.xAxis, 2.2, L.locker)
		local door = box(m, "Door", Vector3.new(x0 + 0.12, 0.6, zf), Vector3.new(x1 - 0.12, 7.6, zf + n * 0.08), L.door)
		for _, vy in { 6.6, 6.9, 7.2, 1.0, 1.3 } do
			box(m, "Vent", Vector3.new(x0 + 0.5, vy, zf + n * 0.08), Vector3.new(x1 - 0.5, vy + 0.12, zf + n * 0.1), L.slot)
		end
		box(m, "Handle", Vector3.new(x1 - 0.55, 3.6, zf + n * 0.08), Vector3.new(x1 - 0.35, 4.6, zf + n * 0.26), L.steel)
		local plate = box(m, "NumberPlate", Vector3.new(x0 + 0.6, 5.6, zf + n * 0.08), Vector3.new(x1 - 0.6, 6.2, zf + n * 0.12), L.slot)
		local g = Instance.new("SurfaceGui")
		g.Face = side < 0 and Enum.NormalId.Back or Enum.NormalId.Front
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 40
		g.LightInfluence = 0.4
		g.Parent = plate
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.FontFace = RUBIK
		t.TextScaled = true
		t.TextColor3 = Color3.fromRGB(226, 222, 212)
		t.Text = ("%02d"):format(num)
		t.Parent = g
		door.Name = "Door"
	end
	-- two padded benches in front of the row
	for _, xs in { { 60, 74 }, { 82, 96 } } do
		local b = model(row, "Bench")
		local zc = zf + n * 3.6
		box(b, "Seat", Vector3.new(xs[1], 1.6, zc - 0.8), Vector3.new(xs[2], 2.1, zc + 0.8), L.pad)
		box(b, "Rail", Vector3.new(xs[1] + 0.2, 1.3, zc - 0.6), Vector3.new(xs[2] - 0.2, 1.6, zc + 0.6), L.steel)
		for _, lx in { xs[1] + 0.8, (xs[1] + xs[2]) / 2, xs[2] - 0.8 } do
			box(b, "Leg", Vector3.new(lx - 0.2, 0, zc - 0.55), Vector3.new(lx + 0.2, 1.3, zc + 0.55), L.dark)
		end
	end
end

-- 5. DISPLAY TABLES with the 8 laid guns ---------------------------------------------------------------
local tables = model(locker, "Tables")
local GUNS_LAY = { "Phantom", "Operator", "Spectre", "Judge", "Vandal", "Odin", "Classic", "Sheriff" }
local g = 0
for _, tx in { 64, 92 } do
	for _, tz in { -9, 9 } do
		local m = model(tables, "Table")
		local x0, x1, z0, z1, TH = tx - 4.6, tx + 4.6, tz - 2.6, tz + 2.6, 3
		box(m, "Top", Vector3.new(x0, TH - 0.3, z0), Vector3.new(x1, TH, z1), L.steel)
		box(m, "Mat", Vector3.new(x0 + 0.3, TH, z0 + 0.3), Vector3.new(x1 - 0.3, TH + 0.06, z1 - 0.3), L.mat)
		box(m, "Apron", Vector3.new(x0 + 0.3, TH - 0.9, z0 + 0.3), Vector3.new(x1 - 0.3, TH - 0.3, z1 - 0.3), L.dark)
		for _, lx in { x0 + 0.6, x1 - 0.6 } do
			for _, lz in { z0 + 0.6, z1 - 0.6 } do
				box(m, "Leg", Vector3.new(lx - 0.25, 0, lz - 0.25), Vector3.new(lx + 0.25, TH - 0.9, lz + 0.25), L.dark)
			end
		end
		box(m, "Stretcher", Vector3.new(x0 + 0.6, 0.8, tz - 0.2), Vector3.new(x1 - 0.6, 1.1, tz + 0.2), L.dark)
		for _, dz in { -1.2, 1.2 } do
			g += 1
			gunAnchor(m, "Lay_" .. GUNS_LAY[g], Vector3.new(tx, TH + 0.06, tz + dz), GUNS_LAY[g], "Lay", Vector3.new(-0.9239, 0, -0.3827), Vector3.new(0, 1, 0), 2.3, 6.6)
		end
	end
end

-- 6. WORKBENCH island: sloped hazard sides, steel top, a turntable with the Knife turning, the Locker prompt ---
local bench = model(locker, "Workbench")
local BX0, BX1, BZ0, BZ1, BH = 72.5, 83.5, -2.8, 2.8, 3.4
box(bench, "Plinth", Vector3.new(BX0 + 0.4, 0, BZ0 + 0.4), Vector3.new(BX1 - 0.4, 0.5, BZ1 - 0.4), L.dark)
box(bench, "Core", Vector3.new(BX0 + 0.9, 0.5, BZ0 + 0.9), Vector3.new(BX1 - 0.9, BH - 0.3, BZ1 - 0.9), L.dark)
for _, s in { -1, 1 } do -- sloped long sides with hazard panels
	local zEdge = s < 0 and BZ0 or BZ1
	-- right angle at the core's foot, legs up and outward: the slope faces out
	local w = tri(bench, "Side", Vector3.new((BX0 + BX1) / 2, 0.5, zEdge - s * 0.9), Vector3.new(0, 1, 0), BH - 0.8, Vector3.new(0, 0, s), 0.9, Vector3.xAxis, BX1 - BX0 - 1.8, L.paint)
	texture(w, Enum.NormalId.Top, TEX.hazard, 2.4)
	texture(w, Enum.NormalId.Front, TEX.hazard, 2.4)
end
for _, s in { -1, 1 } do -- end caps (steel)
	local xEdge = s < 0 and BX0 or BX1
	tri(bench, "End", Vector3.new(xEdge - s * 0.9, 0.5, 0), Vector3.new(0, 1, 0), BH - 0.8, Vector3.new(s, 0, 0), 0.9, Vector3.zAxis, BZ1 - BZ0 - 1.8, L.steel)
end
box(bench, "Top", Vector3.new(BX0 - 0.2, BH - 0.3, BZ0 - 0.2), Vector3.new(BX1 + 0.2, BH, BZ1 + 0.2), L.steel)
local tt = workspace.LobbyV5:FindFirstChild("Shell") and game:GetService("ServerStorage").V5Kit.V5_Flange8:Clone()
tt.Name = "Turntable"
tt.Size = Vector3.new(0.5, 4.2, 4.2)
tt.CFrame = CFrame.new(O + Vector3.new(78, BH + 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90))
tt.Material = L.dark.mat
tt.MaterialVariant = L.dark.var
tt.Color = L.dark.col
tt.Parent = bench
gunAnchor(bench, "Stand_Knife", Vector3.new(78, BH + 2.6, 0), "Knife", "Stand", Vector3.new(0, 1, 0), Vector3.new(1, 0, 0), 2.6, 0, 30)
local prompt = anchorPart(bench, "LockerZone", Vector3.new(78, 3.5, 0))
prompt.Size = Vector3.new(14, 7, 8)
CS:AddTag(prompt, "LobbyLocker")
-- yellow floor box round the bench
local fb = model(bench, "FloorBox")
local fx0, fx1, fz0, fz1 = BX0 - 2.2, BX1 + 2.2, BZ0 - 2.2, BZ1 + 2.2
box(fb, "Line", Vector3.new(fx0, 0, fz0), Vector3.new(fx1, 0.04, fz0 + 0.4), L.paint)
box(fb, "Line", Vector3.new(fx0, 0, fz1 - 0.4), Vector3.new(fx1, 0.04, fz1), L.paint)
box(fb, "Line", Vector3.new(fx0, 0, fz0 + 0.4), Vector3.new(fx0 + 0.4, 0.04, fz1 - 0.4), L.paint)
box(fb, "Line", Vector3.new(fx1 - 0.4, 0, fz0 + 0.4), Vector3.new(fx1, 0.04, fz1 - 0.4), L.paint)
-- walkway lines from the door
box(locker, "Line_N", Vector3.new(46.5, 0.06, -6.6), Vector3.new(fx0, 0.1, -6.2), L.paint)
box(locker, "Line_S", Vector3.new(46.5, 0.06, 6.2), Vector3.new(fx0, 0.1, 6.6), L.paint)

-- 7. THE ARMORER by the gun wall ------------------------------------------------------------------
local src = workspace:FindFirstChild("LobbyV4Staging") and workspace.LobbyV4Staging:FindFirstChild("NPCs") and workspace.LobbyV4Staging.NPCs:FindFirstChild("Armorer")
if src then
	local npc = src:Clone()
	local cf, size = npc:GetBoundingBox()
	local pivot = npc:GetPivot()
	local bottom = cf.Position.Y - size.Y / 2
	local target = O + Vector3.new(98.5, 0, -12.5)
	local rot = CFrame.lookAt(target, target + Vector3.new(-1, 0, 0.5))
	npc:PivotTo(rot.Rotation + Vector3.new(target.X, pivot.Position.Y - bottom + O.Y, target.Z))
	npc.Parent = locker
end

local n = 0
for _, d in locker:GetDescendants() do
	if d:IsA("BasePart") then
		n += 1
	end
end
return ("locker built: %d pieces, %d gun anchors"):format(n, #CS:GetTagged("LobbyGunDisplay"))
