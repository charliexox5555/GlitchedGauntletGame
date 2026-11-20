--!strict
-- Lobby V5 hub shell (vault/02 Art/Lobby V5 Plan.md). A ONE-TIME placement script: run it through the
-- Studio MCP while the hub is being blocked in; after the owner starts editing by hand, the place owns the
-- parts and this script is only a record. It rebuilds Workspace.LobbyV5.Shell.Hub only.
-- Every piece is its own Part / MeshPart so it can be moved, swapped or deleted in Studio.
-- Rock pieces are Blender meshes (tools/blender/lobby_v5/v5_rock.py) kept in ServerStorage.V5Kit;
-- after import their rock face points local -Z (Blender -Y -> Roblox -Z), so pieces get a 180 degree turn
-- about their own centre; the placement math uses the back-bottom-centre.

local MS = game:GetService("MaterialService")
local SS = game:GetService("ServerStorage")

local O = Vector3.new(0, 0, -1600) -- hub centre, floor top
local UP = Vector3.yAxis

local function variant(name: string): MaterialVariant
	for _, v in MS:GetDescendants() do
		if v:IsA("MaterialVariant") and v.Name == name then
			return v
		end
	end
	error("missing MaterialVariant " .. name)
end

type Look = { mat: Enum.Material, var: string?, col: Color3 }
local function look(var: string?, col: Color3, mat: Enum.Material?): Look
	if var then
		return { mat = variant(var).BaseMaterial, var = var, col = col }
	end
	return { mat = mat or Enum.Material.SmoothPlastic, col = col }
end

local L = {
	floor = look("ConcretePanels-02a", Color3.fromRGB(106, 103, 99)),
	board = look("Lobby_ConcreteBoard", Color3.fromRGB(118, 116, 112)),
	trim = look("Concrete-02a", Color3.fromRGB(128, 126, 123)),
	darkConc = look("Concrete-02a", Color3.fromRGB(62, 62, 64)),
	steel = look("Metal 2022", Color3.fromRGB(96, 98, 102)),
	darkSteel = look("Metal 2022", Color3.fromRGB(56, 58, 62)),
	diamond = look("Diamond Plate 2022", Color3.fromRGB(112, 114, 118)),
	grate = look("Bunker_Grate", Color3.fromRGB(88, 90, 94)),
	shutter = look("Corrugated_01a", Color3.fromRGB(150, 152, 156)),
	rock = look("Lobby_Rock", Color3.fromRGB(132, 116, 102)),
	cable = look(nil, Color3.fromRGB(30, 30, 32), Enum.Material.Metal),
	black = look(nil, Color3.fromRGB(12, 12, 14), Enum.Material.SmoothPlastic),
}

local HAZARD = "rbxassetid://75158634706115" -- image id of the Decal asset 128601803791013

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, lk: Look, cls: string?): BasePart
	local p = Instance.new((cls or "Part") :: any) :: BasePart
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

-- axis-aligned box from min/max corners, in hub-local coordinates
local function box(parent: Instance, name: string, a: Vector3, b: Vector3, lk: Look): BasePart
	local lo, hi = a:Min(b), a:Max(b)
	return part(parent, name, hi - lo, CFrame.new(O + (lo + hi) / 2), lk)
end

-- flat right triangle (horizontal or vertical) as a WedgePart: right angle at p, legs u*a and v*b, thickness along w
local function tri(parent: Instance, name: string, p: Vector3, u: Vector3, a: number, v: Vector3, b: number, w: Vector3, th: number, lk: Look): BasePart
	local X = w.Unit
	local Y = u.Unit
	local Z = X:Cross(Y)
	if Z:Dot(-v.Unit) < 0 then
		X = -X
		Z = X:Cross(Y)
	end
	local c = O + p + u.Unit * a / 2 + v.Unit * b / 2
	return part(parent, name, Vector3.new(th, a, b), CFrame.fromMatrix(c, X, Y), lk, "WedgePart")
end

local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function texture(p: BasePart, face: Enum.NormalId, id: string, tile: number)
	local t = Instance.new("Texture")
	t.Face = face
	t.Texture = id
	t.StudsPerTileU = tile
	t.StudsPerTileV = tile
	t.Parent = p
end

local function spot(parent: Instance, name: string, pos: Vector3, target: Vector3, col: Color3, bright: number, range: number, angle: number)
	local p = part(parent, name, Vector3.new(0.5, 0.5, 0.5), CFrame.lookAt(O + pos, O + target), look(nil, Color3.new(1, 1, 1)))
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	local s = Instance.new("SpotLight")
	s.Color = col
	s.Brightness = bright
	s.Range = range
	s.Angle = angle
	s.Shadows = true
	s.Face = Enum.NormalId.Front
	s.Parent = p
end

---------------------------------------------------------------------------------------------------
local root = workspace:FindFirstChild("LobbyV5") or Instance.new("Folder")
root.Name = "LobbyV5"
root.Parent = workspace
local shell = root:FindFirstChild("Shell") or Instance.new("Folder")
shell.Name = "Shell"
shell.Parent = root
local old = shell:FindFirstChild("Hub")
if old then
	old:Destroy()
end
local hub = model(shell, "Hub")

-- 1. FLOOR: 4 x 4 slabs of 32 studs, top at y = 0 --------------------------------------------------
local floor = model(hub, "Floor")
for i = 0, 3 do
	for j = 0, 3 do
		local x0, z0 = -52 + i * 26, -52 + j * 26
		local s = box(floor, ("Slab_%d_%d"):format(i, j), Vector3.new(x0, -2, z0), Vector3.new(x0 + 26, 0, z0 + 26), L.floor)
		local k = ((i + j) % 2) * 3
		s.Color = Color3.fromRGB(104 + k, 101 + k, 97 + k)
	end
end

-- 2. FREIGHT LIFT PLATFORM: elongated octagon 40 x 32, corner cut 8, centre (0, 4), deck top y = 0.6 --
local lift = model(hub, "LiftPlatform")
local LZ = 0
local TOP = 0.6
box(lift, "Deck_Mid", Vector3.new(-12, -0.6, LZ - 16), Vector3.new(12, TOP, LZ + 16), L.diamond)
box(lift, "Deck_W", Vector3.new(-20, -0.6, LZ - 8), Vector3.new(-12, TOP, LZ + 8), L.diamond)
box(lift, "Deck_E", Vector3.new(12, -0.6, LZ - 8), Vector3.new(20, TOP, LZ + 8), L.diamond)
for _, sx in { -1, 1 } do
	for _, sz in { -1, 1 } do
		tri(lift, ("Deck_Corner_%s%s"):format(sz < 0 and "N" or "S", sx < 0 and "W" or "E"),
			Vector3.new(12 * sx, (TOP - 0.6) / 2, LZ + 8 * sz), Vector3.new(0, 0, sz), 8, Vector3.new(sx, 0, 0), 8, UP, TOP + 0.6, L.diamond)
	end
end
-- hazard border: a 2-stud strip just inside every edge, 0.1 proud of the deck (straight edges), 0.12 (diagonals)
local hz = model(lift, "HazardBorder")
local function strip(name: string, a: Vector3, b: Vector3, h: number)
	-- a, b: edge end points (y ignored); the strip runs inward of the edge toward the platform centre
	local mid = (a + b) / 2
	local dir = (b - a).Unit
	local len = (b - a).Magnitude
	local inward = (Vector3.new(0, 0, LZ) - mid) * Vector3.new(1, 0, 1)
	local n = Vector3.new(-dir.Z, 0, dir.X)
	if n:Dot(inward) < 0 then
		n = -n
	end
	local c = O + mid + n * 1 + Vector3.new(0, TOP + h / 2 - 0.05, 0)
	local p = part(hz, name, Vector3.new(len - 0.04, h, 1.96), CFrame.fromMatrix(c, dir, UP), look(nil, Color3.fromRGB(240, 180, 20))) -- 0.02 inside the deck edges: no shared faces
	texture(p, Enum.NormalId.Top, HAZARD, 3)
end
local V = {
	Vector3.new(-12, 0, LZ - 16), Vector3.new(12, 0, LZ - 16), Vector3.new(20, 0, LZ - 8), Vector3.new(20, 0, LZ + 8),
	Vector3.new(12, 0, LZ + 16), Vector3.new(-12, 0, LZ + 16), Vector3.new(-20, 0, LZ + 8), Vector3.new(-20, 0, LZ - 8),
}
for i = 1, 8 do
	local a, b = V[i], V[i % 8 + 1]
	local diag = math.abs(a.X - b.X) > 0.1 and math.abs(a.Z - b.Z) > 0.1
	strip("Hazard_" .. i, a, b, diag and 0.17 or 0.15)
end

-- 3. LIFT TOWERS: two steel towers behind the platform, rising into the shaft ------------------------
local towers = model(hub, "LiftTowers")
local TZ = -17
for _, sx in { -1, 1 } do
	local t = model(towers, sx < 0 and "Tower_W" or "Tower_E")
	local x = 22 * sx
	box(t, "Plinth", Vector3.new(x - 4, 0, TZ - 5), Vector3.new(x + 4, 1.5, TZ + 5), L.trim)
	for _, dz in { -3, 3 } do
		box(t, "Post_" .. (dz < 0 and "N" or "S"), Vector3.new(x - 0.8, 1.5, TZ + dz - 0.8), Vector3.new(x + 0.8, 120, TZ + dz + 0.8), L.darkSteel)
	end
	for k = 0, 9 do
		local y = 8 + k * 12
		box(t, "Tie_" .. k, Vector3.new(x - 0.5, y - 0.5, TZ - 2.2), Vector3.new(x + 0.5, y + 0.5, TZ + 2.2), L.steel)
	end
	-- counterweight stack between the posts
	local cw = model(t, "Counterweight")
	for k = 0, 4 do
		local y0 = 18 + k * 2.1
		box(cw, "Block_" .. k, Vector3.new(x - 1.6, y0, TZ - 2.1), Vector3.new(x + 1.6, y0 + 2, TZ + 2.1), k % 2 == 0 and L.steel or L.darkSteel)
	end
	box(cw, "Yoke", Vector3.new(x - 1.8, 28.5, TZ - 2.2), Vector3.new(x + 1.8, 29.5, TZ + 2.2), L.darkSteel)
	for k = -1, 1 do
		box(t, "Cable_" .. (k + 2), Vector3.new(x - 0.15, 29.5, TZ + k * 0.9 - 0.15), Vector3.new(x + 0.15, 114, TZ + k * 0.9 + 0.15), L.cable)
	end
end
box(towers, "Crossbeam", Vector3.new(-21.2, 55, TZ - 0.9), Vector3.new(21.2, 57.4, TZ + 0.9), L.steel)
box(towers, "Crossbeam_Flange_Top", Vector3.new(-21.2, 57.4, TZ - 1.4), Vector3.new(21.2, 57.9, TZ + 1.4), L.darkSteel)
box(towers, "Crossbeam_Flange_Bot", Vector3.new(-21.2, 54.5, TZ - 1.4), Vector3.new(21.2, 55, TZ + 1.4), L.darkSteel)
-- headframe beam above the cave mouth
box(towers, "Headframe", Vector3.new(-23, 114, TZ - 1.2), Vector3.new(23, 117, TZ + 1.2), L.steel)
box(towers, "Headframe_Flange_Top", Vector3.new(-23, 117, TZ - 1.8), Vector3.new(23, 117.6, TZ + 1.8), L.darkSteel)
box(towers, "Headframe_Flange_Bot", Vector3.new(-23, 113.4, TZ - 1.8), Vector3.new(23, 114, TZ + 1.8), L.darkSteel)

-- 4. ROCK: octagon of rock, flats at R = 62 (back of each piece), two rows + ceiling -------------------
local rockF = Instance.new("Folder")
rockF.Name = "Rock"
rockF.Parent = hub
local kit = SS:WaitForChild("V5Kit")
local R = 50
local SIDE = 2 * R * math.tan(math.rad(22.5)) -- 51.36
local TPL = { "V5_RockWall_A", "V5_RockWall_B", "V5_RockWall_C" }
local count = 0

local function rock(name: string, tpl: string, k: number, along: number, w: number, h: number, y0: number, tilt: number, flip: boolean)
	local th = math.rad(k * 45)
	local d = Vector3.new(math.sin(th), 0, -math.cos(th)) -- outward
	local n = -d
	local t = (kit :: any)[tpl] :: MeshPart
	local depth = t.Size.Z
	local base = O + d * R + Vector3.new(math.cos(th), 0, math.sin(th)) * along + Vector3.new(0, y0, 0)
	local X = UP:Cross(n)
	local cf = CFrame.fromMatrix(base, X, UP) * CFrame.Angles(tilt, 0, 0) * CFrame.new(0, h / 2, depth / 2)
	cf *= CFrame.Angles(0, math.pi, 0) -- the imported face points -Z
	if flip then
		cf *= CFrame.Angles(0, 0, math.pi)
	end
	local m = t:Clone()
	m.Name = name
	m.Size = Vector3.new(w, h, depth)
	m.CFrame = cf
	m.Material = L.rock.mat
	m.MaterialVariant = L.rock.var :: string
	m.Color = L.rock.col
	m.Parent = rockF
	count += 1
end

-- door sides: {side, frame width, top of the frame}; side 0 = north (duels), 2 = east, 4 = south, 6 = west
local DOORS = { [0] = { 42, 26 }, [2] = { 26, 20 }, [4] = { 30, 18 }, [6] = { 42, 18.5 } }
local SIDE_NAMES = { [0] = "N", "NE", "E", "SE", "S", "SW", "W", "NW" }
for k = 0, 7 do
	local sn = SIDE_NAMES[k]
	local door = DOORS[k]
	if not door then
		for i, along in { -SIDE / 4, SIDE / 4 } do
			local w = SIDE / 2 + 2.5
			-- the panels next to the duels portal stop 8 studs short of the corner and end on a concrete buttress
			if (k == 7 and i == 2) or (k == 1 and i == 1) then
				local a0, a1 = SIDE / 4 - w / 2, SIDE / 2 - 8
				along, w = (k == 7 and 1 or -1) * (a0 + a1) / 2, a1 - a0
			end
			rock(("Wall_%s_%d"):format(sn, i), TPL[(k + i) % 3 + 1], k, along, w, 48, 0, 0, (k + i) % 2 == 0)
		end
	else
		local fw, top = door[1], door[2]
		local sw = (SIDE - fw) / 2 + 1.5
		if sw > 6 then
			for i, s in { -1, 1 } do
				rock(("Wall_%s_%d"):format(sn, i), TPL[(k + i) % 3 + 1], k, s * (fw / 2 + sw / 2 - 1.5), sw, 48, 0, 0, i == 2)
			end
		end
		rock(("Above_%s"):format(sn), "V5_RockLow_A", k, 0, math.min(fw + 3, SIDE + 2), 48 - top, top, 0, false)
	end
	-- upper row leans in 20 degrees toward the sky opening
	for i, along in { -SIDE / 4, SIDE / 4 } do
		rock(("Upper_%s_%d"):format(sn, i), TPL[(k + i + 1) % 3 + 1], k, along, SIDE / 2 + 2.5, 26, 46, math.rad(20), (k + i) % 2 == 1)
	end
end

-- skylight chimney: the cave narrows into an open rock chimney with a jagged rim (owner 2026-11-20:
-- "the top opens up where the sky shines in"). Back of each piece on the upper row's top edge, leaning out
-- 8 degrees, shallow (depth 7) so the rock stays clear of the lift towers rising through the opening.
local RC = R - 26 * math.sin(math.rad(20)) -- 41.1, where the upper row ends
local YC = 46 + 26 * math.cos(math.rad(20)) - 0.6 -- 69.8
local CSIDE = 2 * RC * math.tan(math.rad(22.5))
for k = 0, 7 do
	local th = math.rad(k * 45)
	local d = Vector3.new(math.sin(th), 0, -math.cos(th))
	local n = -d
	local tpl = (k % 2 == 0) and "V5_RockChimney_A" or "V5_RockChimney_B"
	local t = (kit :: any)[tpl] :: MeshPart
	local h, depth = 40, 7
	local base = O + d * RC + Vector3.new(0, YC, 0)
	local X = UP:Cross(n)
	local cf = CFrame.fromMatrix(base, X, UP) * CFrame.Angles(math.rad(-8), 0, 0) * CFrame.new(0, h / 2, depth / 2) * CFrame.Angles(0, math.pi, 0)
	local m = t:Clone()
	m.Name = "Chimney_" .. SIDE_NAMES[k]
	m.Size = Vector3.new(CSIDE + 4, h, depth)
	m.CFrame = cf
	m.Material = L.rock.mat
	m.MaterialVariant = L.rock.var :: string
	m.Color = L.rock.col
	m.Parent = rockF
	count += 1
end

-- 6. DUELS PORTAL (north): concrete frame with cut top corners, 36 x 20 opening ----------------------
local portal = model(hub, "Portal_Duels")
local PZ0, PZ1 = -50, -42 -- frame depth; pillars reach out to the rock so no rock pokes into the opening
box(portal, "Pillar_W", Vector3.new(-24, 0, PZ0), Vector3.new(-17, 26, PZ1), L.trim)
box(portal, "Pillar_E", Vector3.new(17, 0, PZ0), Vector3.new(24, 26, PZ1), L.trim)
box(portal, "Lintel", Vector3.new(-17, 20, PZ0), Vector3.new(17, 26, PZ1), L.trim)
for _, s in { -1, 1 } do
	tri(portal, s < 0 and "Cut_W" or "Cut_E", Vector3.new(17 * s, 20, (PZ0 + PZ1) / 2), Vector3.new(0, -1, 0), 4, Vector3.new(-s, 0, 0), 4,
		Vector3.zAxis, PZ1 - PZ0, L.trim)
end
box(portal, "Threshold", Vector3.new(-17, -0.4, PZ0), Vector3.new(17, 0.05, PZ1), L.darkSteel)
-- concrete buttresses fill the cave corners beside the portal (rock ends on them instead of cutting the frame)
for _, spec in { { 7, 1, "Buttress_W" }, { 1, -1, "Buttress_E" } } do
	local k, s = spec[1], spec[2]
	local th = math.rad(k * 45)
	local d = Vector3.new(math.sin(th), 0, -math.cos(th))
	local tv = Vector3.new(math.cos(th), 0, math.sin(th))
	local c = O + d * R - d * 2.25 + tv * (s * (SIDE / 2 - 4.5)) + Vector3.new(0, 24, 0)
	part(portal, spec[3], Vector3.new(9, 48, 4.5), CFrame.fromMatrix(c, tv, UP), L.trim)
end
-- stub of the duels tunnel (replaced when the duels deck is built): one step down, grating floor
local stub = model(hub, "DuelsStub")
box(stub, "Floor", Vector3.new(-17, -3, -84), Vector3.new(17, -1, PZ0), L.grate)
box(stub, "Step", Vector3.new(-17, -1, PZ0 - 1.5), Vector3.new(17, -0.4, PZ0), L.darkSteel)
box(stub, "Wall_W", Vector3.new(-19, -3, -84), Vector3.new(-17, 20, PZ0), L.darkConc)
box(stub, "Wall_E", Vector3.new(17, -3, -84), Vector3.new(19, 20, PZ0), L.darkConc)
box(stub, "Roof", Vector3.new(-19, 20, -84), Vector3.new(19, 22, PZ0), L.darkConc)
box(stub, "TEMP_EndCap", Vector3.new(-19, -3, -86), Vector3.new(19, 22, -84), L.black)

-- 7. SHOP (west): board-concrete front set into the rock, counter opening with a raised shutter -------
local shop = model(hub, "Shop")
local SX = -40 -- facade face
box(shop, "Base", Vector3.new(SX - 2, 0, -16), Vector3.new(SX, 4.5, 16), L.board)
box(shop, "Flank_N", Vector3.new(SX - 2, 0, -21.5), Vector3.new(SX + 1, 18.5, -16), L.board)
box(shop, "Flank_S", Vector3.new(SX - 2, 0, 16), Vector3.new(SX + 1, 18.5, 21.5), L.board)
box(shop, "Pier_S", Vector3.new(SX - 2, 4.5, 6), Vector3.new(SX, 12.5, 16), L.board)
box(shop, "Pier_N", Vector3.new(SX - 2, 4.5, -16), Vector3.new(SX, 12.5, -12), L.board)
box(shop, "Header", Vector3.new(SX - 2, 12.5, -16), Vector3.new(SX, 18, 16), L.board)
box(shop, "Counter", Vector3.new(SX - 3, 4.5, -12), Vector3.new(SX + 1.5, 5.1, 6), L.trim)
box(shop, "Shutter", Vector3.new(SX - 1.6, 10, -12), Vector3.new(SX - 1.2, 12.5, 6), L.shutter)
box(shop, "Canopy", Vector3.new(SX + 1, 16, -16), Vector3.new(SX + 4, 18.5, 16), L.trim)
box(shop, "Side_N", Vector3.new(-54, 0, -17), Vector3.new(SX - 2, 18.5, -16), L.board)
box(shop, "Side_S", Vector3.new(-54, 0, 16), Vector3.new(SX - 2, 18.5, 17), L.board)
box(shop, "Back", Vector3.new(-55, 0, -16), Vector3.new(-54, 18.5, 16), L.darkConc)
box(shop, "Roof", Vector3.new(-54, 18, -16), Vector3.new(SX - 2, 18.5, 16), L.trim)
box(shop, "InnerCeiling", Vector3.new(-54, 16.5, -16), Vector3.new(SX - 2, 17, 16), L.darkConc)
box(shop, "ShopFloor", Vector3.new(-55, -2, -17), Vector3.new(-52, 0, 17), L.floor) -- the hub floor stops at -52

-- 8. ARMOURY (east): concrete frame with cut top corners and closed double steel doors ----------------
local arm = model(hub, "Armoury")
local AX = 40
box(arm, "Jamb_N", Vector3.new(AX, 0, -12.5), Vector3.new(AX + 6, 15, -7), L.trim)
box(arm, "Jamb_S", Vector3.new(AX, 0, 7), Vector3.new(AX + 6, 15, 12.5), L.trim)
box(arm, "Lintel", Vector3.new(AX, 15, -12.5), Vector3.new(AX + 6, 20, 12.5), L.trim)
for _, s in { -1, 1 } do
	tri(arm, s < 0 and "Cut_N" or "Cut_S", Vector3.new(AX + 3, 15, 7 * s), Vector3.new(0, -1, 0), 3, Vector3.new(0, 0, -s), 3, Vector3.xAxis, 6, L.trim)
end
box(arm, "Transom", Vector3.new(AX + 3.2, 12, -4), Vector3.new(AX + 3.8, 15, 4), L.darkSteel)
box(arm, "Door_N", Vector3.new(AX + 3.2, 0, -7), Vector3.new(AX + 3.8, 12, -0.08), L.steel)
box(arm, "Door_S", Vector3.new(AX + 3.2, 0, 0.08), Vector3.new(AX + 3.8, 12, 7), L.steel)
box(arm, "DoorGap", Vector3.new(AX + 3.3, 0, -0.08), Vector3.new(AX + 3.7, 12, 0.08), L.black)
box(arm, "Back", Vector3.new(AX + 6, 0, -12.5), Vector3.new(AX + 12, 20, 12.5), L.darkConc)

-- 9. RANGE DOOR (south, behind spawn): frame with a closed corrugated shutter -------------------------
local rng = model(hub, "RangeDoor")
local RZ = 42
box(rng, "Jamb_W", Vector3.new(-13, 0, RZ), Vector3.new(-8, 18, RZ + 6), L.trim)
box(rng, "Jamb_E", Vector3.new(8, 0, RZ), Vector3.new(13, 18, RZ + 6), L.trim)
box(rng, "Lintel", Vector3.new(-8, 12, RZ), Vector3.new(8, 18, RZ + 6), L.trim)
box(rng, "Shutter", Vector3.new(-8, 0, RZ + 3), Vector3.new(8, 12, RZ + 3.5), L.shutter)
box(rng, "ShutterBar", Vector3.new(-8, 0, RZ + 2.4), Vector3.new(8, 0.8, RZ + 3), L.darkSteel)
box(rng, "Back", Vector3.new(-13, 0, RZ + 6), Vector3.new(13, 18, RZ + 8), L.darkConc)

-- 10. LIGHTS (temporary sources; real fixtures come with the dressing pass) ---------------------------
local lights = Instance.new("Folder")
lights.Name = "Lights"
lights.Parent = hub
local WARM = Color3.fromRGB(255, 190, 130)
local WHITE = Color3.fromRGB(255, 246, 232)
-- grazing lamps at the top of each rock face, aimed down the rock (the concept's wall lamps)
for k = 0, 7 do
	local th = math.rad(k * 45)
	local d = Vector3.new(math.sin(th), 0, -math.cos(th))
	local tv = Vector3.new(math.cos(th), 0, math.sin(th))
	for i, s in { -1, 1 } do
		local along = s * SIDE / 4
		spot(lights, ("Graze_%s_%d"):format(SIDE_NAMES[k], i), d * (R - 16) + tv * along + Vector3.new(0, 40, 0), d * (R - 4) + tv * along + Vector3.new(0, 4, 0), WARM, 2.5, 64, 60)
	end
end
-- low warm fill so the cave floor and rock bases are never black
for k = 0, 3 do
	local th = math.rad(45 + k * 90)
	local p = part(lights, "Fill_" .. k, Vector3.new(0.5, 0.5, 0.5), CFrame.new(O + Vector3.new(math.sin(th) * 22, 22, -math.cos(th) * 22)), look(nil, Color3.new(1, 1, 1)))
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	local pl = Instance.new("PointLight")
	pl.Color = WARM
	pl.Brightness = 0.6
	pl.Range = 48
	pl.Shadows = false
	pl.Parent = p
end
spot(lights, "Lift_W", Vector3.new(-8, 54, TZ + 2), Vector3.new(-8, 0, LZ), WHITE, 1, 70, 60)
spot(lights, "Lift_E", Vector3.new(8, 54, TZ + 2), Vector3.new(8, 0, LZ), WHITE, 1, 70, 60)
spot(lights, "ShopCanopy", Vector3.new(SX + 2.5, 15.8, 0), Vector3.new(SX + 6, 0, 0), WHITE, 2.5, 24, 120)
spot(lights, "ShopInside", Vector3.new(SX - 7, 16, -3), Vector3.new(SX - 7, 0, -3), WHITE, 3, 26, 120)
spot(lights, "Armoury", Vector3.new(AX - 2, 22, 0), Vector3.new(AX + 2, 0, 0), WHITE, 2, 26, 90)
spot(lights, "Range", Vector3.new(0, 20, RZ - 2), Vector3.new(0, 0, RZ + 2), WARM, 2, 26, 90)
spot(lights, "Tunnel_1", Vector3.new(0, 19.5, PZ0 - 6), Vector3.new(0, -1, PZ0 - 6), WHITE, 5, 36, 120)
spot(lights, "Tunnel_2", Vector3.new(0, 19.5, PZ0 - 22), Vector3.new(0, -1, PZ0 - 22), WHITE, 5, 36, 120)

-- 11. ANCHORS ---------------------------------------------------------------------------------------
local anchors = Instance.new("Folder")
anchors.Name = "Anchors"
anchors.Parent = hub
local sp = part(anchors, "Spawn", Vector3.new(6, 1, 6), CFrame.lookAt(O + Vector3.new(0, TOP + 0.5, LZ), O + Vector3.new(0, TOP + 0.5, LZ - 10)), look(nil, Color3.new(0, 1, 0)))
sp.Transparency = 1
sp.CanCollide = false

-- 12. LIGHTING (place-wide, owner 2026-11-20 "too dark", skylight). Old values: Ambient 74,74,78;
-- OutdoorAmbient 112,112,116; Brightness 3; EnvironmentDiffuseScale 0.55; ClockTime 12.3; ColorShift_Top 255,253,248.
local Lt = game:GetService("Lighting")
Lt.Ambient = Color3.fromRGB(84, 78, 72)
Lt.OutdoorAmbient = Color3.fromRGB(84, 76, 68)
Lt.Brightness = 2.4
Lt.EnvironmentDiffuseScale = 0.3
Lt.ClockTime = 14.6 -- the sun falls through the skylight onto the east rock, not straight down on the floor
Lt.ColorShift_Top = Color3.fromRGB(255, 214, 170)

local n = 0
for _, d in hub:GetDescendants() do
	if d:IsA("BasePart") then
		n += 1
	end
end
return ("hub built: %d parts (%d rock meshes)"):format(n, count)
