--!strict
-- Greenhouse4 (regular map, 1v1-2v2), the whole build (2026-11-21). Concept, layout and build log:
-- vault/01 Design/Maps/Greenhouse4.md. Layout rows mirror tools/maps/greenhouse4_layout.py; the A half (+Z) is turned
-- 180 degrees for team B. Match place only, edit mode. Returns a function; run it with require(<a clone>)().
--
-- A Victorian iron-and-glass conservatory in a walled garden, late morning. The middle: the Palm House (88 x 72),
-- glass on a stone dwarf wall under a hipped glass roof with an octagonal lantern; inside, the lily pond with a palm
-- on its island (the landmark), planting beds, a rockery inside each grand door, and an iron gallery (+10) along both
-- side walls on cast-iron columns, four iron stairs up. Each half: a paved apron with flower borders, a gravel
-- parterre with lawn panels, box hedges, topiary and a sundial, the brick potting house (the spawn baffle), the
-- paved spawn court with palms in Versailles tubs. One flank holds the team's Fern House (a glass hall), the other an
-- open walk with the boiler house (its chimney a landmark), a garden shed, a yew alcove and a raised rock garden (+4).
-- Parts carry soft MaterialVariants (colour maps only, no normal maps). Kit pieces: ServerStorage.MapKit.Greenhouse4
-- (tools/blender/maps_greenhouse4). Plants: RIVALS meshes in ServerStorage.MapKit.Greenhouse4Rivals (owner
-- 2026-11-21: RIVALS map meshes allowed, no logos) and LeafyGrass Part hedges. Sash windows: MapKit.Rooftops4.
-- Team colours: A coral flowers / red doors and awnings, B violet flowers / plum doors and awnings.
-- Collision: masses are their own collision; glass walls collide (they block shots); plants get invisible boxes and a
-- roof guard (MapBlockers, shots pass) so nobody stands on them; railings get hop-over strips. Contract: Spawns
-- (ArenaSpawn_A/B), Barriers (empty), Bounds, KillDepth + Lighting (authored data 421 / 422), LightingFx, WinnerStage.
-- Joins never share a plane: touching pieces overlap or step 0.03+; ground skins sit at distinct heights.

local CollectionService = game:GetService("CollectionService")
local MaterialService = game:GetService("MaterialService")
local PhysicsService = game:GetService("PhysicsService")
local ServerStorage = game:GetService("ServerStorage")

local ORIGIN = CFrame.new(6000, 200, 40000) -- ground level at the map centre
local ROT = CFrame.Angles(0, math.pi, 0)
local I = CFrame.identity
local V = Vector3.new

local function hex(h: string): Color3
	return Color3.fromHex(h)
end
type Side = { flower: Color3, door: Color3, awning: Color3 }
local SIDE: { [string]: Side } = {
	A = { flower = hex("E0735A"), door = hex("8A2E2A"), awning = hex("C8513E") },
	B = { flower = hex("9470C8"), door = hex("4E3A78"), awning = hex("7A55B0") },
}
-- soft variants (owner 2026-11-21: not too much texture): colour maps only, no normal maps
local VARIANTS = {
	G4_Lawn = { "Grass", 16, "78039573039009" },
	G4_Gravel = { "Ground", 10, "122983174308364" },
	G4_Tile = { "Slate", 8, "106370306993211" },
	G4_Brick = { "Brick", 7, "107246436113114" },
	G4_Stone = { "Limestone", 10, "73274454631456" },
	G4_Paving = { "Limestone", 10, "130608433991662" },
	G4_Slate = { "Slate", 8, "132940063953152" },
	G4_Plate = { "DiamondPlate", 5, "116955307704363" },
	-- stylised foliage: the RIVALS maps' PineFoliage_01a maps (map textures allowed, owner 2026-11-21; polish pass:
	-- the plain LeafyGrass leaf litter read too realistic)
	G4_Foliage = { "LeafyGrass", 10, "88927716299506", "128869074617524" },
}

type Look = { color: Color3, mat: Enum.Material?, variant: string?, alpha: number? }
local function look(color: Color3, variant: string?, mat: Enum.Material?, alpha: number?): Look
	return { color = color, variant = variant, mat = mat, alpha = alpha }
end
local L = {
	lawn = look(hex("7FA05A"), "G4_Lawn", Enum.Material.Grass),
	lawnPark = look(hex("789A55"), "G4_Lawn", Enum.Material.Grass),
	gravel = look(hex("C2AE8A"), "G4_Gravel", Enum.Material.Ground), -- warmer than the paving so paths read
	tile = look(hex("C27456"), "G4_Tile", Enum.Material.Slate),
	paving = look(hex("CDC3AE"), "G4_Paving", Enum.Material.Limestone),
	stone = look(hex("D9CAAA"), "G4_Stone", Enum.Material.Limestone),
	stoneDark = look(hex("B3A07E"), "G4_Stone", Enum.Material.Limestone),
	brick = look(hex("A2583F"), "G4_Brick", Enum.Material.Brick),
	brickDark = look(hex("86452F"), "G4_Brick", Enum.Material.Brick),
	slate = look(hex("5E646A"), "G4_Slate", Enum.Material.Slate),
	iron = look(hex("E2DED3"), nil, Enum.Material.SmoothPlastic),
	ironDark = look(hex("33493D"), nil, Enum.Material.Metal),
	glass = look(hex("CFE3D8"), nil, Enum.Material.Glass, 0.6),
	plate = look(hex("6C7468"), "G4_Plate", Enum.Material.DiamondPlate),
	soil = look(hex("4A3A2C"), nil, Enum.Material.Ground),
	hedge = look(hex("4E7A3C"), "G4_Foliage", Enum.Material.LeafyGrass),
	yew = look(hex("3C6232"), "G4_Foliage", Enum.Material.LeafyGrass),
	leafy = look(hex("5A8A42"), "G4_Foliage", Enum.Material.LeafyGrass),
	wood = look(hex("8C6845"), nil, Enum.Material.Wood),
	shed = look(hex("7E8F6A"), nil, Enum.Material.WoodPlanks),
	cream = look(hex("EDE6D6"), nil, Enum.Material.Fabric),
	glassDark = look(hex("2B3A3C")),
	basin = look(hex("4C5A50"), nil, Enum.Material.Slate),
	none = look(hex("FFFFFF")),
}

local BLOCKERS = "MapBlockers"
local function ensureBlockerGroup()
	if not PhysicsService:IsCollisionGroupRegistered(BLOCKERS) then
		PhysicsService:RegisterCollisionGroup(BLOCKERS)
	end
	PhysicsService:CollisionGroupSetCollidable(BLOCKERS, "Default", false)
	PhysicsService:CollisionGroupSetCollidable(BLOCKERS, BLOCKERS, false)
	if PhysicsService:IsCollisionGroupRegistered("Bodies") then
		PhysicsService:CollisionGroupSetCollidable(BLOCKERS, "Bodies", true)
	end
end

local function ensureVariants()
	for name, v in VARIANTS do
		if not MaterialService:FindFirstChild(name) then
			local mv = Instance.new("MaterialVariant")
			mv.Name = name
			mv.BaseMaterial = (Enum.Material :: any)[v[1]]
			mv.StudsPerTile = v[2]
			mv.ColorMap = "rbxassetid://" .. v[3]
			if v[4] then
				mv.NormalMap = "rbxassetid://" .. v[4]
			end
			mv.MaterialPattern = Enum.MaterialPattern.Regular
			mv.Parent = MaterialService
		end
	end
end

-- RIVALS texture pass (2026-11-21, see the map note): every surface look onto RIVALS' map MaterialVariants
-- (MaterialService.ExtraTextures, found by name), keyed by "Material|Variant" as built. Applied once the map is built.
local RIVALS_REMAP: { [string]: { any } } = {
	["Brick|G4_Brick"] = { Enum.Material.Brick, "RV_Brick10" },
	["Limestone|G4_Stone"] = { Enum.Material.Concrete, "Concrete-01a" },
	["Limestone|"] = { Enum.Material.Concrete, "Concrete-01a" },
	["Limestone|G4_Paving"] = { Enum.Material.Pavement, "Paver_01a" },
	["Slate|G4_Tile"] = { Enum.Material.Pavement, "Paver_01b" },
	["Slate|G4_Slate"] = { Enum.Material.Slate, "Slate02c" },
	["Grass|G4_Lawn"] = { Enum.Material.Grass, "Grass_01b" },
	["Ground|G4_Gravel"] = { Enum.Material.Sand, "Sand_01b" },
	["Ground|"] = { Enum.Material.Ground, "Ground_01b" },
	["DiamondPlate|G4_Plate"] = { Enum.Material.DiamondPlate, "Diamond Plate 2022" },
	["DiamondPlate|"] = { Enum.Material.DiamondPlate, "Diamond Plate 2022" },
	["Metal|"] = { Enum.Material.Metal, "Metal 2022" },
	["Wood|"] = { Enum.Material.Wood, "Wood01a" },
	["WoodPlanks|"] = { Enum.Material.WoodPlanks, "WoodSiding_01a" },
	["Fabric|"] = { Enum.Material.Fabric, "Fabric2022" },
}

return function(): string
	assert(game.PlaceId == 133387545285290, "Greenhouse4: not the match place")
	ensureVariants()
	ensureBlockerGroup()
	local old = workspace:FindFirstChild("Greenhouse4")
	if old then
		old:Destroy()
	end
	local map = Instance.new("Model")
	map.Name = "Greenhouse4"
	map.WorldPivot = ORIGIN
	CollectionService:AddTag(map, "GGAsset_MatchMaps_421")
	CollectionService:AddTag(map, "GauntletAuthoredData")

	local function folder(parent: Instance, name: string): Folder
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
		return f
	end
	local secCollision = folder(map, "Collision")
	local secStructure = folder(map, "Structure")
	local secProps = folder(map, "Props")
	local secPlants = folder(map, "Plants")
	local secWorld = folder(map, "World")
	local secSpawns = folder(map, "Spawns")
	folder(map, "Barriers")
	local secBounds = folder(map, "Bounds")
	local count = 0
	local rng = Random.new(42121)

	local function part(
		parent: Instance,
		name: string,
		size: Vector3,
		cf: CFrame,
		lk: Look,
		solid: boolean?,
		class: string?
	): BasePart
		local p = Instance.new(class or "Part") :: BasePart
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = ORIGIN * cf
		p.Color = lk.color
		p.Material = lk.mat or Enum.Material.SmoothPlastic
		if lk.variant then
			p.MaterialVariant = lk.variant
		end
		if lk.alpha then
			p.Transparency = lk.alpha
		end
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = solid == true
		p.CanQuery = solid == true
		p.CanTouch = false
		p.CastShadow = math.max(size.X, size.Y, size.Z) >= 4 and (lk.alpha or 0) < 0.5
		p.Parent = parent
		count += 1
		return p
	end
	local function box(
		parent: Instance,
		name: string,
		a: Vector3,
		b: Vector3,
		lk: Look,
		solid: boolean?,
		T: CFrame?
	): BasePart
		local lo, hi = a:Min(b), a:Max(b)
		return part(parent, name, hi - lo, (T or I) * CFrame.new((lo + hi) / 2), lk, solid)
	end
	-- invisible collision box (blocks players and shots)
	local function col(name: string, a: Vector3, b: Vector3, T: CFrame): BasePart
		local p = box(secCollision, name, a, b, L.none, true, T)
		p.Transparency = 1
		p.CastShadow = false
		return p
	end
	-- invisible player blocker (shots pass)
	local function blocker(name: string, a: Vector3, b: Vector3, T: CFrame): BasePart
		local p = col(name, a, b, T)
		p.CanQuery = false
		p.CollisionGroup = BLOCKERS
		return p
	end
	local function fromLib(
		lib: string,
		piece: string,
		parent: Instance,
		cf: CFrame,
		scale: number?
	): Model
		local libF = ServerStorage.MapKit:FindFirstChild(lib)
		local src = libF and libF:FindFirstChild(piece)
		assert(src and src:IsA("Model"), "missing kit piece " .. lib .. "." .. piece)
		local m = src:Clone()
		if scale and scale ~= 1 then
			m:ScaleTo(scale)
		end
		m:PivotTo(ORIGIN * cf)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				count += 1
			end
		end
		m.Parent = parent
		return m
	end
	local function kit(piece: string, parent: Instance, cf: CFrame, scale: number?): Model
		return fromLib("Greenhouse4", piece, parent, cf, scale)
	end
	-- a RIVALS plant (pivot = bottom centre)
	local function plant(piece: string, parent: Instance, cf: CFrame, scale: number?): Model
		local m = fromLib("Greenhouse4Rivals", piece, parent, cf, scale)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.CastShadow = true
				if d.Material == Enum.Material.LeafyGrass or d.Material == Enum.Material.Grass then
					d.Material = Enum.Material.LeafyGrass
					d.MaterialVariant = "G4_Foliage"
				end
			end
		end
		return m
	end
	local function light(parent: Instance, range: number, bright: number, color: Color3)
		local l = Instance.new("PointLight")
		l.Range = range
		l.Brightness = bright
		l.Color = color
		l.Shadows = false
		l.Parent = parent
	end
	local function yaw(deg: number): CFrame
		return CFrame.Angles(0, math.rad(deg), 0)
	end
	-- a ground skin: a slab whose top is at `top` (distinct heights wherever two skins overlap)
	local function skin(
		parent: Instance,
		name: string,
		x0: number,
		x1: number,
		z0: number,
		z1: number,
		top: number,
		lk: Look,
		T: CFrame
	): BasePart
		return box(parent, name, V(x0, top - 0.3, z0), V(x1, top, z1), lk, true, T)
	end
	-- a band round a rectangle: N/S pieces full length, E/W pieces inside them (no shared corner planes)
	local function ring(
		parent: Instance,
		name: string,
		x0: number,
		x1: number,
		z0: number,
		z1: number,
		y0: number,
		y1: number,
		out: number,
		lk: Look,
		T: CFrame,
		solid: boolean?
	)
		local ins = 0.1
		box(parent, name, V(x0 - out, y0, z0 - out), V(x1 + out, y1, z0 + ins), lk, solid, T)
		box(parent, name, V(x0 - out, y0, z1 - ins), V(x1 + out, y1, z1 + out), lk, solid, T)
		local o2 = out - 0.05
		box(
			parent,
			name,
			V(x0 - o2, y0 + 0.04, z0 - o2),
			V(x0 + ins, y1 - 0.04, z1 + o2),
			lk,
			solid,
			T
		)
		box(
			parent,
			name,
			V(x1 - ins, y0 + 0.04, z0 - o2),
			V(x1 + o2, y1 - 0.04, z1 + o2),
			lk,
			solid,
			T
		)
	end

	--------------------------------------------------------------------------------------------- glass walls
	-- a glazed wall on a stone dwarf wall along the floor line a -> b (wall centre): base course, dwarf wall, sill,
	-- glass in bays between iron mullions, transoms, wall plate and gutter at the eaves H. Openings {u0, u1, head}
	-- along the run (clear width; the jambs stand outside it). `lift` staggers the horizontal pieces of runs that meet
	-- at a corner so their faces never coincide (the corner pier hides the join).
	local function wall(
		parent: Instance,
		a: Vector3,
		b: Vector3,
		H: number,
		opens: { { number } },
		transoms: { number },
		lift: number,
		T: CFrame
	)
		local len = (b - a).Magnitude
		local base = CFrame.lookAt(a, b)
		local function seg(
			name: string,
			u0: number,
			u1: number,
			y0: number,
			y1: number,
			depth: number,
			lk: Look,
			solid: boolean?
		): BasePart
			return part(
				parent,
				name,
				V(depth, y1 - y0, u1 - u0),
				T * base * CFrame.new(0, (y0 + y1) / 2, -(u0 + u1) / 2),
				lk,
				solid
			)
		end
		local spans = {}
		local prev = 0
		for _, o in opens do
			table.insert(spans, { prev, o[1] - 0.3 })
			prev = o[2] + 0.3
		end
		table.insert(spans, { prev, len })
		for _, s in spans do
			local s0, s1 = s[1], s[2]
			if s1 - s0 < 0.05 then
				continue
			end
			local e0 = if s0 > 0 then 0.06 else 0 -- at an opening the base course, dwarf wall and sill end 0.06 apart
			local e1 = if s1 < len then 0.06 else 0
			seg("BaseCourse", s0 - e0, s1 + e1, -0.15 - lift, 0.62 + lift, 1.5, L.stoneDark)
			seg("DwarfWall", s0, s1, -0.18 - lift, 2.6 + lift, 1.2, L.stone, true)
			seg("Sill", s0 + e0, s1 - e1, 2.55 + lift, 2.98 + lift, 1.5, L.stone)
			seg("Glass", s0, s1, 2.96 + lift, H - 0.05, 0.2, L.glass, true)
			local n = math.max(1, math.floor((s1 - s0) / 4 + 0.5))
			for i = 1, n - 1 do
				local u = s0 + (s1 - s0) * i / n
				seg("Mullion", u - 0.22, u + 0.22, 2.94 + lift, H + 0.02, 0.6, L.iron)
			end
		end
		for _, o in opens do
			local u0, u1, head = o[1], o[2], o[3]
			seg("Jamb", u0 - 0.6, u0, -0.12, H + 0.02, 0.8, L.iron, true)
			seg("Jamb", u1, u1 + 0.6, -0.12, H + 0.02, 0.8, L.iron, true)
			seg("DoorHead", u0 - 0.7, u1 + 0.7, head + lift, head + 0.6 + lift, 0.9, L.iron, true)
			seg("Glass", u0 - 0.3, u1 + 0.3, head + 0.55 + lift, H - 0.05, 0.2, L.glass, true)
			seg("Threshold", u0 - 0.62, u1 + 0.62, -0.2, 0.2 + lift, 1.56, L.stone, true)
		end
		for _, y in transoms do
			seg("Transom", 0, len, y + lift, y + 0.32 + lift, 0.5, L.iron)
		end
		seg("WallPlate", 0, len, H - 0.1 + lift, H + 0.6 + lift, 1.1, L.iron)
		seg("Gutter", 0, len, H + 0.35 + lift, H + 0.85 + lift, 1.7, L.iron)
	end
	-- an iron-clad corner pier on a stone plinth
	local function pier(parent: Instance, x: number, z: number, H: number, T: CFrame)
		box(
			parent,
			"PierPlinth",
			V(x - 1.3, -0.2, z - 1.3),
			V(x + 1.3, 0.85, z + 1.3),
			L.stoneDark,
			true,
			T
		)
		box(
			parent,
			"Pier",
			V(x - 1.1, 0.8, z - 1.1),
			V(x + 1.1, H + 0.95, z + 1.1),
			L.iron,
			true,
			T
		)
		box(
			parent,
			"PierCap",
			V(x - 1.3, H + 0.9, z - 1.3),
			V(x + 1.3, H + 1.25, z + 1.3),
			L.iron,
			false,
			T
		)
		box(
			parent,
			"PierFinial",
			V(x - 0.5, H + 1.2, z - 0.5),
			V(x + 0.5, H + 1.9, z + 0.5),
			L.iron,
			false,
			T
		)
	end

	--------------------------------------------------------------------------------------------- brick buildings
	-- a building with a pitched slate roof, ridge along local X; cf = ground centre (ridge axis = cf's X)
	local function house(
		parent: Instance,
		name: string,
		cf: CFrame,
		lx: number,
		lz: number,
		eave: number,
		rise: number,
		walls: Look,
		T: CFrame,
		over: number?
	): BasePart
		local ov = over or 0.5
		local W = T * cf
		local hx, hz = lx / 2, lz / 2
		local body = box(parent, name, V(-hx, -0.2, -hz), V(hx, eave, hz), walls, true, W)
		ring(parent, name .. "Base", -hx, hx, -hz, hz, -0.2, 0.8, 0.15, L.stoneDark, W)
		ring(parent, name .. "Cornice", -hx, hx, -hz, hz, eave - 0.5, eave + 0.05, 0.3, L.stone, W)
		-- the attic: two wedges (identity WedgePart rises toward +Z)
		local w1 = part(
			parent,
			name .. "Gable",
			V(lx, rise + 0.05, hz + 0.025),
			W * CFrame.new(0, eave - 0.05 + (rise + 0.05) / 2, -hz / 2 + 0.0125),
			walls,
			true,
			"WedgePart"
		)
		local w2 = part(
			parent,
			name .. "Gable",
			V(lx - 0.06, rise + 0.05, hz + 0.025),
			W * CFrame.new(0, eave - 0.05 + (rise + 0.05) / 2, hz / 2 - 0.0125) * ROT,
			walls,
			true,
			"WedgePart"
		)
		w1.CastShadow, w2.CastShadow = true, true
		local th = math.atan2(rise, hz)
		local sl = math.sqrt(rise * rise + hz * hz)
		for _, s in { -1, 1 } do
			local nrm = V(0, math.cos(th), s * math.sin(th))
			local dUp = V(0, math.sin(th), -s * math.cos(th)) -- eave to ridge
			local mid = V(0, eave + rise / 2, s * hz / 2) + nrm * (0.05 + 0.175) - dUp * 0.3
			part(
				parent,
				name .. "Roof",
				V(lx + 2 * ov, 0.35, sl + 0.6),
				W * CFrame.fromMatrix(mid, Vector3.xAxis, nrm),
				L.slate,
				true
			)
		end
		part(
			parent,
			name .. "Ridge",
			V(lx + 2 * ov + 0.1, 0.42, 0.42),
			W * CFrame.new(0, eave + rise + 0.22, 0) * CFrame.Angles(math.rad(45), 0, 0),
			L.stoneDark
		)
		blocker(
			name .. "RoofGuard",
			V(-hx - 0.8, eave, -hz - 0.8),
			V(hx + 0.8, eave + rise + 9, hz + 0.8),
			W
		)
		return body
	end
	-- a kit sash window on a wall: p on the wall face, n the outward normal
	local function window(parent: Instance, p: Vector3, n: Vector3, T: CFrame)
		local q = p - n * 0.02
		local m = fromLib("Rooftops4", "R4Window", parent, T * CFrame.lookAt(q, q + n))
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and string.find(d.Name, "WinPane") then
				d.Material = Enum.Material.Glass
				d.Color = L.glassDark.color
				d.Reflectance = 0.15
			end
		end
	end
	-- a plank door with a stone surround on a wall: p = bottom centre on the wall face, n outward
	local function door(
		parent: Instance,
		p: Vector3,
		n: Vector3,
		w: number,
		h: number,
		paint: Color3,
		T: CFrame
	)
		local cf = T * CFrame.lookAt(p, p + n)
		local function b(
			name: string,
			x0: number,
			x1: number,
			y0: number,
			y1: number,
			z0: number,
			z1: number,
			lk: Look
		)
			part(
				parent,
				name,
				V(x1 - x0, y1 - y0, z1 - z0),
				cf * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, -(z0 + z1) / 2),
				lk
			)
		end
		b("DoorSurround", -w / 2 - 0.5, -w / 2 + 0.02, 0.22, h + 0.5, -0.05, 0.3, L.stone)
		b("DoorSurround", w / 2 - 0.02, w / 2 + 0.5, 0.22, h + 0.5, -0.05, 0.3, L.stone)
		b("DoorLintel", -w / 2 - 0.65, w / 2 + 0.65, h + 0.45, h + 1.05, -0.05, 0.37, L.stone)
		b(
			"DoorLeaf",
			-w / 2 + 0.01,
			w / 2 - 0.01,
			0.22,
			h + 0.48,
			-0.1,
			0.22,
			look(paint, nil, Enum.Material.WoodPlanks)
		)
		b(
			"DoorRail",
			-w / 2 + 0.05,
			w / 2 - 0.05,
			h * 0.45,
			h * 0.45 + 0.3,
			0.2,
			0.28,
			look(paint, nil, Enum.Material.Wood)
		)
		b("DoorStep", -w / 2 - 0.52, w / 2 + 0.52, -0.15, 0.25, -0.05, 0.8, L.stone)
	end
	-- a striped canvas awning on brackets over a door (stripes alternate the side colour and cream)
	local function awning(
		parent: Instance,
		p: Vector3,
		n: Vector3,
		w: number,
		colour: Color3,
		T: CFrame
	)
		local cf = T * CFrame.lookAt(p, p + n)
		local stripes = math.floor(w / 0.8 + 0.5)
		local sw = w / stripes
		local drop, depth = 1.1, 2.2
		local th = math.atan2(drop, depth)
		local sl = math.sqrt(drop * drop + depth * depth)
		for i = 0, stripes - 1 do
			local x = -w / 2 + sw * (i + 0.5)
			local lk = if i % 2 == 0 then look(colour, nil, Enum.Material.Fabric) else L.cream
			part(
				parent,
				"Awning",
				V(sw + 0.002 * (i % 2), 0.08 + 0.01 * (i % 2), sl),
				cf * CFrame.new(x, -drop / 2, -depth / 2) * CFrame.Angles(-th, 0, 0),
				lk
			)
			part(
				parent,
				"AwningValance",
				V(sw + 0.002 * (i % 2), 0.5, 0.06 + 0.01 * (i % 2)),
				cf * CFrame.new(x, -drop - 0.2, -depth - 0.02),
				lk
			)
		end
		for _, s in { -1, 1 } do
			part(
				parent,
				"AwningArm",
				V(0.1, 0.1, sl),
				cf
					* CFrame.new(s * (w / 2 - 0.1), -drop / 2 - 0.08, -depth / 2)
					* CFrame.Angles(-th, 0, 0),
				L.ironDark
			)
		end
		part(parent, "AwningRoll", V(w + 0.2, 0.3, 0.3), cf * CFrame.new(0, 0.1, -0.1), L.ironDark)
	end

	--------------------------------------------------------------------------------------------- planting
	-- a stone-kerbed raised bed: kerb walls to 2.2, coping, soil at 2.0; plants on top; collision + roof guard
	local function bed(
		parent: Instance,
		x0: number,
		x1: number,
		z0: number,
		z1: number,
		plantTop: number,
		T: CFrame
	)
		box(parent, "BedKerb", V(x0, -0.18, z0), V(x1, 2.2, z1), L.stoneDark, true, T)
		ring(
			parent,
			"BedCoping",
			x0 + 0.12,
			x1 - 0.12,
			z0 + 0.12,
			z1 - 0.12,
			2.15,
			2.45,
			0.2,
			L.stone,
			T
		)
		box(
			parent,
			"BedSoil",
			V(x0 + 0.5, 2.0, z0 + 0.5),
			V(x1 - 0.5, 2.28, z1 - 0.5),
			L.soil,
			false,
			T
		)
		col("BedPlants", V(x0 + 0.4, 2.2, z0 + 0.4), V(x1 - 0.4, plantTop, z1 - 0.4), T)
		blocker("BedGuard", V(x0 - 0.3, 2.45, z0 - 0.3), V(x1 + 0.3, plantTop + 9, z1 + 0.3), T)
	end
	-- a clipped LeafyGrass hedge with a narrower top course (square-cut, a soft step at the top)
	local function hedge(
		parent: Instance,
		x0: number,
		x1: number,
		z0: number,
		z1: number,
		y0: number,
		h: number,
		lk: Look,
		T: CFrame,
		guard: boolean?
	)
		box(parent, "Hedge", V(x0, y0 - 0.05, z0), V(x1, y0 + h - 0.45, z1), lk, true, T)
		box(
			parent,
			"HedgeTop",
			V(x0 + 0.25, y0 + h - 0.5, z0 + 0.25),
			V(x1 - 0.25, y0 + h, z1 - 0.25),
			lk,
			true,
			T
		)
		if guard then
			blocker(
				"HedgeGuard",
				V(x0 - 0.3, y0 + h, z0 - 0.3),
				V(x1 + 0.3, y0 + h + 9, z1 + 0.3),
				T
			)
		end
	end
	-- a flower border: a low stone kerb with LeafyGrass foliage and a flowering top in the side colour
	-- a RIVALS shrub mesh stretched to a box (flowering patches in the borders)
	local function shrub(parent: Instance, size: Vector3, cf: CFrame, colour: Color3)
		local src = ServerStorage.MapKit.Greenhouse4Rivals.G4R_Bush01c:FindFirstChildWhichIsA(
			"MeshPart",
			true
		)
		assert(src, "missing G4R_Bush01c mesh")
		local p = src:Clone()
		p.Size = size
		p.CFrame = ORIGIN * cf
		p.Color = colour
		p.MaterialVariant = "G4_Foliage"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Parent = parent
		count += 1
	end
	-- a flower border: a low stone kerb, soil, and a row of flowering shrub patches (every third one green)
	local function flowers(
		parent: Instance,
		x0: number,
		x1: number,
		z0: number,
		z1: number,
		colour: Color3,
		T: CFrame
	)
		ring(parent, "BorderKerb", x0, x1, z0, z1, -0.15, 0.32, 0.15, L.stone, T)
		box(
			parent,
			"BorderSoil",
			V(x0 + 0.1, 0.0, z0 + 0.1),
			V(x1 - 0.1, 0.28, z1 - 0.1),
			L.soil,
			false,
			T
		)
		col("BorderCol", V(x0, 0, z0), V(x1, 0.9, z1), T)
		-- one continuous green bed, flowering clumps of varied width on top
		shrub(
			parent,
			V(x1 - x0 - 0.3, 0.55, z1 - z0 - 0.3),
			T * CFrame.new((x0 + x1) / 2, 0.47, (z0 + z1) / 2),
			L.leafy.color
		)
		local x = x0 + 0.5
		while x < x1 - 1.2 do
			local w = 1.2 + rng:NextNumber() * 1.4
			local x2 = math.min(x + w, x1 - 0.4)
			local h = 0.3 + rng:NextNumber() * 0.15
			local dz = (rng:NextNumber() - 0.5) * 0.3
			local c = colour:Lerp(hex("F2E2D6"), rng:NextNumber() * 0.3)
			shrub(
				parent,
				V(x2 - x, h, z1 - z0 - 0.75),
				T * CFrame.new((x + x2) / 2, 0.62 + h / 2, (z0 + z1) / 2 + dz),
				c
			)
			x = x2 + 0.35 + rng:NextNumber() * 0.5
		end
	end
	-- a kit rail run along a line at floor y (posts at every joint) with a hop-over collision strip
	local postSeen: { [string]: boolean } = {}
	local function railRun(parent: Instance, a: Vector3, b: Vector3, T: CFrame)
		local d = b - a
		local len = d.Magnitude
		local dir = d.Unit
		local n = math.max(1, math.floor(len / 4 + 0.5))
		local seg = len / n
		local ry = math.atan2(-dir.Z, dir.X)
		-- runs along X sit 0.025 lower, so rails that meet at a corner never share a top plane
		local drop = if math.abs(dir.X) > 0.5 then V(0, 0.025, 0) else Vector3.zero -- kit rail runs along X
		for i = 0, n do
			local p = a + dir * (seg * i)
			local w = (ORIGIN * T):PointToWorldSpace(p)
			local key = string.format("%.1f,%.1f,%.1f", w.X, w.Y, w.Z)
			if not postSeen[key] then
				postSeen[key] = true
				kit("G4Post", parent, T * CFrame.new(p - V(0, 0.03, 0)) * CFrame.Angles(0, ry, 0))
			end
			if i < n then
				local m = kit(
					"G4Rail4",
					parent,
					T * CFrame.new(p + dir * (seg / 2) - drop) * CFrame.Angles(0, ry, 0)
				)
				for _, q in m:GetDescendants() do
					if q:IsA("BasePart") then
						local cf = q.CFrame
						q.Size = V(q.Size.X * (seg - 0.1) / 4.1, q.Size.Y, q.Size.Z) -- runs end inside the posts
						q.CFrame = cf
					end
				end
			end
		end
		local mid = (a + b) / 2
		local g = part(
			secCollision,
			"RailGuard",
			V(0.4, 3.45, len + 0.2),
			T * CFrame.lookAt(mid, b) * CFrame.new(0, 1.7, 0),
			L.none,
			true
		)
		g.Transparency = 1
		g.CanQuery = false
		g.CollisionGroup = BLOCKERS
		g.CastShadow = false
	end
	local function lampPost(parent: Instance, x: number, z: number, T: CFrame)
		local m = kit("G4LampPost", parent, T * CFrame.new(x, -0.02, z))
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and string.find(d.Name, "_G4_Lamp") then
				d.Color = hex("B09270") -- a warm glow (lighter lenses clip to white)
				light(d, 14, 0.8, hex("FFD9A0"))
			end
		end
		col("LampCol", V(x - 0.35, 0, z - 0.35), V(x + 0.35, 9.5, z + 0.35), T)
	end
	local function urn(parent: Instance, x: number, y: number, z: number, T: CFrame, solid: boolean)
		kit("G4Urn", parent, T * CFrame.new(x, y - 0.03, z))
		plant(
			"G4R_Topiary",
			secPlants,
			T * CFrame.new(x, y + 3.55, z) * yaw(rng:NextNumber() * 360),
			0.42
		)
		if solid then
			col("UrnCol", V(x - 0.8, y, z - 0.8), V(x + 0.8, y + 3.7, z + 0.8), T)
			blocker("UrnGuard", V(x - 0.9, y + 3.7, z - 0.9), V(x + 0.9, y + 12, z + 0.9), T)
		end
	end
	-- a garden bench from Parts (polish pass: the kit bench's iron arms didn't line up): two cast-iron end frames
	-- (front leg into the arm post, back post, seat rail, a wide armrest), wood slats over them. Faces +Z.
	local function bench(
		parent: Instance,
		x: number,
		z: number,
		facing: number,
		T: CFrame,
		y: number?
	)
		local cf = T * CFrame.new(x, y or 0, z) * yaw(facing)
		local function b(name: string, a: Vector3, c: Vector3, lk: Look)
			box(parent, name, a, c, lk, false, cf)
		end
		for _, s in { -1, 1 } do
			local x0, x1 = math.min(s * 2.63, s * 2.87), math.max(s * 2.63, s * 2.87)
			b("BenchLeg", V(x0, 0, 0.62), V(x1, 2.32, 0.86), L.ironDark)
			b("BenchPost", V(x0, 0, -0.86), V(x1, 3.25, -0.62), L.ironDark)
			b("BenchRail", V(x0 + 0.02, 1.35, -0.84), V(x1 - 0.02, 1.55, 0.84), L.ironDark)
			b("BenchArm", V(x0 - 0.03, 2.3, -0.84), V(x1 + 0.03, 2.48, 1.02), L.ironDark)
			b("BenchFoot", V(x0 - 0.04, 0, 0.56), V(x1 + 0.04, 0.14, 0.92), L.ironDark)
			b("BenchFoot", V(x0 - 0.04, 0, -0.92), V(x1 + 0.04, 0.14, -0.56), L.ironDark)
		end
		b("BenchRail", V(-0.1, 1.35, -0.84), V(0.1, 1.55, 0.84), L.ironDark)
		for k = 0, 4 do
			local zc = -0.66 + k * 0.33
			b(
				"BenchSlat",
				V(-2.95, 1.53, zc - 0.13),
				V(2.95, 1.68 + (k % 2) * 0.01, zc + 0.13),
				L.wood
			)
		end
		for k = 0, 2 do
			local y = 1.95 + k * 0.42
			b("BenchBack", V(-2.75, y, -0.64), V(2.75, y + 0.26, -0.52), L.wood) -- ends inside the posts
		end
		col("BenchCol", V(-3, 0, -1), V(3, 1.7, 1.05), cf)
	end

	--------------------------------------------------------------------------------------------- the middle (both halves)
	local mid = folder(secStructure, "PalmHouse")
	local midP = folder(secProps, "PalmHouse")
	-- the lily pond: kit kerb, lining, water; basin floor; collision
	kit("G4Pond", mid, I)
	box(mid, "PondFloor", V(-12.6, -2.2, -12.6), V(12.6, -1.5, 12.6), L.basin, true)
	for k = 0, 7 do
		local a = math.rad(45 * k)
		col(
			"PondKerbCol",
			V(-5.45, -1.6, -0.6),
			V(5.45, 0.95, 0.6),
			CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -12.4)
		)
	end
	col("IslandCol", V(-2.9, -1.6, -2.9), V(2.9, 0.8, 2.9), I)
	col("IslandCol", V(-2.9, -1.6, -2.9), V(2.9, 0.78, 2.9), yaw(45))
	-- the palm on the island, ferns round it
	plant("G4R_Palm", secPlants, CFrame.new(0, 0.45, 0) * yaw(20), 0.82)
	col("PalmTrunk", V(-1.1, 0.5, -1.1), V(1.1, 30, 1.1), I)
	for k = 0, 3 do
		plant(
			"G4R_Hedge03a",
			secPlants,
			yaw(45 + 90 * k) * CFrame.new(0, 0.42 - 0.04 * k, -1.75 - 0.03 * k) * yaw(90),
			0.58
		)
	end
	col("IslandFerns", V(-2.6, 0.5, -2.6), V(2.6, 4.2, 2.6), yaw(45))
	blocker("IslandGuard", V(-3.2, 4.2, -3.2), V(3.2, 14, 3.2), I)
	-- lily pads and lilies on the water (top -0.35)
	local pads: { { number } } = {}
	for i = 1, 26 do
		local r, a, s = 0, 0, 0
		for _ = 1, 30 do -- pads never overlap (their tops would share a plane)
			r = 4.6 + rng:NextNumber() * 6.4
			a = rng:NextNumber() * math.pi * 2
			s = 0.7 + rng:NextNumber() * 0.6
			local clear = true
			for _, q in pads do
				if
					math.sqrt((math.cos(a) * r - q[1]) ^ 2 + (math.sin(a) * r - q[2]) ^ 2)
					< 1.45 * (s + q[3])
				then
					clear = false
					break
				end
			end
			if clear then
				break
			end
		end
		local free = true
		for _, q in pads do
			if
				math.sqrt((math.cos(a) * r - q[1]) ^ 2 + (math.sin(a) * r - q[2]) ^ 2)
				< 1.45 * (s + q[3])
			then
				free = false
			end
		end
		if not free then
			continue -- no clear spot found: skip this pad
		end
		table.insert(pads, { math.cos(a) * r, math.sin(a) * r, s })
		kit(
			"G4LilyPad",
			midP,
			CFrame.new(math.cos(a) * r, -0.33 + (i % 3) * 0.008, math.sin(a) * r)
				* yaw(rng:NextNumber() * 360),
			s
		)
		if i % 4 == 0 then
			kit(
				"G4Lily",
				midP,
				CFrame.new(math.cos(a) * r, -0.29 + (i % 3) * 0.008, math.sin(a) * r)
					* yaw(rng:NextNumber() * 360),
				s
			)
		end
	end
	-- side walls (full length, both sides; doors under the galleries) and the apron strips outside them
	for _, s in { -1, 1 } do
		wall(
			mid,
			V(s * 44, 0, -36.5),
			V(s * 44, 0, 36.5),
			20,
			{ { 14.5, 22.5, 8.6 }, { 50.5, 58.5, 8.6 } },
			{ 13.5, 17 },
			0.04,
			I
		)
		skin(
			mid,
			"Apron",
			math.min(s * 44.45, s * 48.6),
			math.max(s * 44.45, s * 48.6),
			-36.35,
			36.35,
			0.1,
			L.paving,
			I
		)
	end
	-- the galleries (+10) along both side walls, full length
	for _, s in { -1, 1 } do
		local function gx(a: number, b: number): (number, number)
			return math.min(s * a, s * b), math.max(s * a, s * b)
		end
		local x0, x1 = gx(36.0, 43.35)
		box(mid, "GalleryDeck", V(x0, 9.7, -35.3), V(x1, 10.0, 35.3), L.plate, true)
		x0, x1 = gx(35.85, 36.4)
		box(mid, "GalleryFascia", V(x0, 9.0, -35.25), V(x1, 9.95, 35.25), L.iron, true)
		x0, x1 = gx(42.85, 43.35)
		box(mid, "GalleryBearer", V(x0, 9.1, -35.25), V(x1, 9.68, 35.25), L.iron)
		for z = -33, 33, 6 do
			x0, x1 = gx(36.35, 42.9)
			box(mid, "GalleryJoist", V(x0, 9.15, z - 0.2), V(x1, 9.71, z + 0.2), L.iron)
		end
		railRun(midP, V(s * 36.15, 10.0, -30.1), V(s * 36.15, 10.0, 30.1), I)
	end
	-- the roof and the lantern
	kit("G4PalmRoof", mid, CFrame.new(0, 20.6, 0))
	kit("G4Lantern", mid, CFrame.new(0, 30.65, 0))
	-- the base ground's east/west pieces under the pond band (z -13.25..13.25), per half below

	--------------------------------------------------------------------------------------------- the halves
	local halves = {
		{ letter = "A", T = I, side = SIDE.A },
		{ letter = "B", T = ROT, side = SIDE.B },
	}
	for _, hf in halves do
		local T, sd = hf.T, hf.side
		local f = folder(secStructure, "Half" .. hf.letter)
		local pf = folder(secProps, "Half" .. hf.letter)

		------------------------------------------------------------------------- ground
		box(f, "Ground", V(-71.5, -4, 13.2), V(71.5, -0.05, 99.5), L.soil, true, T)
		box(f, "Ground", V(13.2, -4.03, -13.25), V(71.5, -0.09, 13.25), L.soil, true, T)
		-- Palm House floor (quarry tiles) round the pond
		skin(f, "Floor", -43.5, 43.5, 13.15, 35.5, 0.03, L.tile, T)
		skin(f, "Floor", 13.15, 43.5, -13.2, 13.2, 0.065, L.tile, T)
		for _, dg in { 45, -45 } do -- along the pond's diagonal kerb faces (13 from the centre)
			part(
				f,
				"Floor",
				V(11, 0.3, 5.5),
				T * yaw(dg) * CFrame.new(0, 0.1 - 0.15, 13.1 + 2.75),
				L.tile,
				true
			)
		end
		-- outside: the apron, the gravel parterre court, the spawn court, the flank lawns and paths
		skin(f, "Apron", -48.65, 48.65, 36.3, 40.6, 0.135, L.paving, T)
		skin(f, "Gravel", -48.6, 48.6, 40.55, 78.05, 0.065, L.gravel, T)
		skin(f, "SpawnCourt", -70, 70, 78, 98.7, 0.1, L.paving, T)
		skin(f, "Lawn", 48.55, 70.25, -0.05, 78.05, 0.03, L.lawn, T) -- east flank
		skin(f, "Path", 48.65, 57, -0.05, 51, 0.065, L.gravel, T)
		skin(f, "Lawn", -70.3, -48.55, 57.95, 78.05, 0.03, L.lawn, T) -- west, north of the Fern House
		skin(f, "Path", -52, -48.55, -0.05, 58.05, 0.17, L.gravel, T) -- west corridor
		skin(f, "Path", -70.3, -51.9, -0.08, 10.2, 0.1, L.gravel, T) -- south of the Fern House
		skin(f, "Floor", -69.5, -52.5, 10.5, 57.5, 0.03, L.tile, T) -- Fern House floor

		------------------------------------------------------------------------- the Palm House end wall
		wall(
			f,
			V(-44.5, 0, 36),
			V(44.5, 0, 36),
			20,
			{ { 28.5, 35.5, 10 }, { 38.5, 50.5, 10 }, { 53.5, 60.5, 10 } },
			{ 13.5, 17 },
			0,
			T
		)
		pier(f, -44, 36, 20, T)
		pier(f, 44, 36, 20, T)
		-- the grand door's pediment (two wedges rising to the middle)
		local pa = part(
			f,
			"Pediment",
			V(0.5, 2.2, 6.75),
			T * CFrame.new(-3.325, 10.6 + 1.1, 36) * yaw(90),
			L.iron,
			false,
			"WedgePart"
		)
		local pb = part(
			f,
			"Pediment",
			V(0.46, 2.2, 6.75),
			T * CFrame.new(3.325, 10.6 + 1.1, 36) * yaw(-90),
			L.iron,
			false,
			"WedgePart"
		)
		pa.CastShadow, pb.CastShadow = true, true
		box(f, "Keystone", V(-0.5, 10.5, 35.6), V(0.5, 11.4, 36.4), L.stone, false, T)
		-- flower borders along the end wall outside
		flowers(pf, 17.2, 42.4, 36.95, 38.45, sd.flower, T)
		flowers(pf, -42.4, -17.2, 36.95, 38.45, sd.flower, T)

		------------------------------------------------------------------------- inside: stairs, columns, beds
		for _, s in { -1, 1 } do
			kit("G4Stair10", f, T * CFrame.new(s * 18, 0.0, 32.6) * yaw(-90 * s))
			local wdg = part(
				secCollision,
				"StairCol",
				V(5, 10, 18),
				T * CFrame.new(s * 27, 5, 32.6) * yaw(90 * s),
				L.none,
				true,
				"WedgePart"
			)
			wdg.Transparency = 1
			wdg.CastShadow = false
			for _, z in { 6, 17, 28 } do
				kit("G4Column", f, T * CFrame.new(s * 36.1, -0.02, z))
				col("ColumnCol", V(s * 36.1 - 0.5, 0, z - 0.5), V(s * 36.1 + 0.5, 9, z + 0.5), T)
			end
		end
		bed(f, 10, 22, 12, 20, 7.6, T)
		plant("G4R_Bush01a", secPlants, T * CFrame.new(15, 2.2, 16) * yaw(90), 0.8)
		plant("G4R_Palm", secPlants, T * CFrame.new(20, 2.2, 17.5) * yaw(140), 0.42)
		bed(f, -22, -10, 12, 20, 7.6, T)
		plant("G4R_Bush01a", secPlants, T * CFrame.new(-15, 2.2, 16) * yaw(-90), 0.8)
		plant("G4R_Palm", secPlants, T * CFrame.new(-20, 2.2, 14.5) * yaw(250), 0.42)
		bed(f, -4.5, 4.5, 23.5, 28.5, 8.2, T)
		plant("G4R_Hedge04a", secPlants, T * CFrame.new(0, 2.2, 26.4) * yaw(90), 0.86)
		plant("G4R_Bush01b", secPlants, T * CFrame.new(0, 2.2, 24.8) * yaw(90), 0.45)

		------------------------------------------------------------------------- the parterre
		for _, s in { -1, 1 } do
			local x0, x1 = math.min(s * 17, s * 39), math.max(s * 17, s * 39)
			ring(pf, "PanelKerb", x0, x1, 45, 67, -0.1, 0.24, 0.2, L.stone, T)
			skin(pf, "Panel", x0 + 0.05, x1 - 0.05, 45.05, 66.95, 0.17, L.lawn, T)
			local hx0, hx1 = math.min(s * 21, s * 33), math.max(s * 21, s * 33)
			hedge(pf, hx0, hx1, 48.5, 51.5, 0.17, 3, L.hedge, T)
			hedge(pf, hx0, hx1, 60.5, 63.5, 0.17, 3, L.hedge, T)
			flowers(pf, hx0 + 0.5, hx1 - 0.5, 53.6, 58.4, sd.flower, T)
			urn(pf, s * 37.6, 0.17, 46.4, T, true)
			urn(pf, s * 37.6, 0.17, 65.6, T, true)
			-- topiary on a stone plinth
			box(
				pf,
				"TopiaryPlinth",
				V(s * 12 - 1.7, -0.1, 54.3),
				V(s * 12 + 1.7, 0.9, 57.7),
				L.stone,
				true,
				T
			)
			plant(
				"G4R_Topiary",
				secPlants,
				T * CFrame.new(s * 12, 0.88, 56) * yaw(rng:NextNumber() * 90),
				1.1
			)
			col("TopiaryCol", V(s * 12 - 1.3, 0.9, 54.7), V(s * 12 + 1.3, 9, 57.3), T)
			blocker("TopiaryGuard", V(s * 12 - 1.6, 9, 54.4), V(s * 12 + 1.6, 18, 57.6), T)
			lampPost(pf, s * 46.8, 42.4, T)
		end
		-- the sundial bed
		ring(pf, "SundialKerb", -3.5, 3.5, 52.5, 59.5, -0.1, 0.42, 0.2, L.stone, T)
		skin(pf, "SundialLawn", -3.45, 3.45, 52.55, 59.45, 0.3, L.lawn, T)
		kit("G4Sundial", pf, T * CFrame.new(0, 0.28, 56))
		col("SundialCol", V(-0.7, 0, 55.3), V(0.7, 3.5, 56.7), T)

		------------------------------------------------------------------------- the potting house (spawn baffle)
		house(f, "PottingHouse", CFrame.new(0, 0, 74), 22, 8, 9, 3, L.brick, T)
		box(f, "Chimney", V(5.2, 9, 73.2), V(6.8, 14.6, 74.8), L.brickDark, true, T)
		box(f, "ChimneyCap", V(4.95, 14.5, 72.95), V(7.05, 14.95, 75.05), L.stone, false, T)
		door(f, V(0, 0, 70), V(0, 0, -1), 3.6, 6.6, sd.door, T)
		door(f, V(0, 0, 78), V(0, 0, 1), 3.6, 6.6, sd.door, T)
		awning(f, V(0, 8.0, 78), V(0, 0, 1), 6.4, sd.awning, T)
		awning(f, V(0, 8.0, 70), V(0, 0, -1), 6.4, sd.awning, T)
		for _, x in { -7, 7 } do
			window(pf, V(x, 2.6, 70), V(0, 0, -1), T)
		end
		window(pf, V(-7, 2.6, 78), V(0, 0, 1), T)
		kit("G4PottingBench", pf, T * CFrame.new(6.2, 0.07, 79.45))
		col("PottingBenchCol", V(2.1, 0, 78.15), V(10.3, 3.1, 80.75), T)
		kit("G4Barrow", pf, T * CFrame.new(-9.5, 0.08, 81) * yaw(200))
		kit("G4PotStack", pf, T * CFrame.new(-4.2, 0.08, 79.5) * yaw(30))

		------------------------------------------------------------------------- the spawn court
		for _, s in { -1, 1 } do
			kit("G4Tub", pf, T * CFrame.new(s * 40, 0.08, 87))
			plant(
				"G4R_Palm",
				secPlants,
				T * CFrame.new(s * 40, 3.3, 87) * yaw(rng:NextNumber() * 360),
				0.6
			)
			col("TubCol", V(s * 40 - 3.5, 0, 83.5), V(s * 40 + 3.5, 3.7, 90.5), T)
			col("TubPalm", V(s * 40 - 0.9, 3.7, 86.1), V(s * 40 + 0.9, 26, 87.9), T)
			blocker("TubGuard", V(s * 40 - 3.8, 3.7, 83.2), V(s * 40 + 3.8, 14, 90.8), T)
			bench(pf, s * 20, 96.6, 180, T)
			lampPost(pf, s * 30, 96.5, T)
		end

		------------------------------------------------------------------------- east flank: boiler house, shed, yew alcove, rock garden
		house(f, "BoilerHouse", CFrame.new(49.6, 0, 31) * yaw(90), 11, 9.8, 10, 2.6, L.brickDark, T)
		box(f, "BoilerChimney", V(50.2, 9, 26.4), V(53, 27.5, 29.2), L.brick, true, T)
		box(f, "BoilerChimneyBand", V(49.95, 24.5, 26.15), V(53.25, 25.1, 29.45), L.stone, false, T)
		box(f, "BoilerChimneyCap", V(49.85, 27.4, 26.05), V(53.35, 28.1, 29.55), L.stone, false, T)
		box(f, "BoilerFlue", V(50.9, 28.0, 27.1), V(52.3, 29.4, 28.5), L.ironDark, false, T)
		door(f, V(50, 0, 36.5), V(0, 0, 1), 3.4, 6.8, sd.door, T)
		window(pf, V(54.5, 3, 31), V(1, 0, 0), T)
		window(pf, V(48.4, 3, 25.5), V(0, 0, -1), T)
		-- the garden shed (painted timber, slate roof)
		house(f, "Shed", CFrame.new(66, 0, 10) * yaw(90), 12, 8, 8.4, 2.2, L.shed, T)
		door(f, V(62, 0, 10), V(-1, 0, 0), 3.2, 6.4, sd.door, T)
		window(pf, V(62, 2.6, 5.4), V(-1, 0, 0), T)
		window(pf, V(62, 2.6, 14.6), V(-1, 0, 0), T)
		-- the yew alcove with a bench
		hedge(f, 66.5, 70.3, 25, 35, 0.03, 8.5, L.yew, T, true) -- a U of clipped yew round a bench
		hedge(f, 62, 66.6, 25.1, 27.6, 0.03, 8.4, L.yew, T, true)
		hedge(f, 62, 66.6, 32.4, 34.9, 0.03, 8.4, L.yew, T, true)
		bench(pf, 64.6, 30, -90, T)
		-- the rock garden (+4): ashlar mass, coping, gravel top, rails, steps on its south side
		box(f, "RockGarden", V(54, -0.18, 51), V(70.3, 3.7, 73), L.stone, true, T)
		ring(f, "RockGardenBase", 54, 70.3, 51, 73, -0.18, 0.7, 0.15, L.stoneDark, T)
		ring(f, "RockGardenBand", 54, 70.3, 51, 73, 2.3, 2.62, 0.1, L.stoneDark, T)
		ring(f, "RockGardenCoping", 54.4, 70.3, 51.4, 72.6, 3.65, 4.05, 0.55, L.stoneDark, T, true)
		skin(f, "RockGardenTop", 54.6, 70.2, 51.6, 72.4, 4.0, L.gravel, T)
		for k = 0, 7 do
			box(
				f,
				"Step",
				V(58 + 0.03 * k, -0.18 - 0.03 * k, 39 + 1.5 * k),
				V(66 - 0.03 * k, 0.5 * (k + 1), 51.05),
				L.stone,
				true,
				T
			)
		end
		for _, x in { 57.62, 66.38 } do
			local ch = part(
				f,
				"StepCheek",
				V(0.7, 4.55, 12),
				T * CFrame.new(x, -0.18 + 4.55 / 2, 45),
				L.stoneDark,
				true,
				"WedgePart"
			)
			ch.CastShadow = true
		end
		railRun(pf, V(54.3, 4.0, 51.5), V(54.3, 4.0, 72.7), T)
		railRun(pf, V(54.3, 4.0, 72.7), V(70, 4.0, 72.7), T)
		railRun(pf, V(54.3, 4.0, 51.5), V(57.3, 4.0, 51.5), T)
		railRun(pf, V(66.7, 4.0, 51.5), V(70, 4.0, 51.5), T)
		for _, b in { { 59.5, 64, 0 }, { 65.5, 58, 70 } } do
			plant("G4R_Bush01c", secPlants, T * CFrame.new(b[1], 4.0, b[2]) * yaw(b[3]), 0.42)
		end
		urn(pf, 66, 4.0, 68, T, true)
		bench(pf, 68.2, 61, -90, T, 4.0)
		lampPost(pf, 56.4, 76, T)

		------------------------------------------------------------------------- west flank: the Fern House
		wall(f, V(-70, 0, 9.5), V(-70, 0, 58.5), 11, {}, { 9.1 }, 0.04, T)
		wall(f, V(-52, 0, 9.5), V(-52, 0, 58.5), 11, { { 4.5, 12, 8.2 } }, { 9.1 }, 0.04, T)
		wall(f, V(-70.5, 0, 10), V(-51.5, 0, 10), 11, { { 6, 13, 8.2 } }, { 9.1 }, 0, T)
		wall(f, V(-70.5, 0, 58), V(-51.5, 0, 58), 11, { { 10, 16.6, 8.2 } }, { 9.1 }, 0, T)
		for _, c in { { -70, 10 }, { -52, 10 }, { -70, 58 }, { -52, 58 } } do
			pier(f, c[1], c[2], 11, T)
		end
		kit("G4FernRoof", f, T * CFrame.new(-61, 11.6, 34))
		-- staging bench with pots
		for _, z in { 19.4, 26, 32.6 } do
			box(pf, "StagingLeg", V(-69.2, 0, z - 0.15), V(-68.9, 2.9, z + 0.15), L.wood, false, T)
			box(pf, "StagingLeg", V(-66.1, 0, z - 0.15), V(-65.8, 2.9, z + 0.15), L.wood, false, T)
		end
		for k = 0, 4 do
			box(
				pf,
				"StagingSlat",
				V(-69.3 + 0.7 * k, 2.88, 19.0),
				V(-68.72 + 0.7 * k, 3.02, 33.0),
				L.wood,
				false,
				T
			)
		end
		col("StagingCol", V(-69.4, 0, 19), V(-65.6, 3.0, 33), T)
		kit("G4PotStack", pf, T * CFrame.new(-67.6, 3.0, 22) * yaw(80))
		kit("G4PotStack", pf, T * CFrame.new(-67.2, 3.0, 29.5) * yaw(250))
		bed(f, -70, -65, 40, 50, 7.4, T)
		plant("G4R_Hedge02a", secPlants, T * CFrame.new(-67.5, 2.2, 45), 0.66)
		plant("G4R_Bush01d", secPlants, T * CFrame.new(-66.6, 2.2, 45), 0.38)
		bed(f, -58.5, -52.5, 30, 38, 7.4, T)
		plant("G4R_Bush01a", secPlants, T * CFrame.new(-55.5, 2.2, 34), 0.62)
		plant("G4R_Palm", secPlants, T * CFrame.new(-55.6, 2.2, 36.5) * yaw(60), 0.2)
		-- outside the Fern House
		lampPost(pf, -50.4, 60.5, T)
		urn(pf, -66, 0.03, 66, T, true)
		bench(pf, -68.6, 72, 90, T)

		------------------------------------------------------------------------- the garden walls (bounds line) and gate
		local gw = folder(secWorld, "GardenWall" .. hf.letter)
		local tk = if hf.letter == "A" then 0 else 0.06 -- the side walls of the two halves overlap at z 0
		local function gardenWall(a: Vector3, b: Vector3, lift: number, th: number)
			local len = (b - a).Magnitude
			local cf = CFrame.lookAt(a, b)
			part(
				gw,
				"GardenWall",
				V(1.4 + th, 8.6 + lift, len),
				T * cf * CFrame.new(0, -0.2 + (8.6 + lift) / 2, -len / 2),
				L.brick,
				true
			)
			part(
				gw,
				"WallCoping",
				V(1.8 + th, 0.55, len),
				T * cf * CFrame.new(0, 8.4 + lift + 0.275, -len / 2),
				L.stone
			)
			part(
				gw,
				"WallPlinth",
				V(1.7 + th, 1.16, len + 0.12),
				T * cf * CFrame.new(0, 0.2 - lift * 1.5, -len / 2),
				L.stoneDark
			)
		end
		local function wallPier(x: number, z: number, withUrn: boolean)
			box(
				gw,
				"WallPier",
				V(x - 1.2, -0.25, z - 1.2),
				V(x + 1.2, 9.4, z + 1.2),
				L.brickDark,
				true,
				T
			)
			box(
				gw,
				"WallPierCap",
				V(x - 1.4, 9.35, z - 1.4),
				V(x + 1.4, 9.8, z + 1.4),
				L.stone,
				false,
				T
			)
			if withUrn then
				urn(gw, x, 9.8, z, T, false)
			end
		end
		gardenWall(V(-71.3, 0, 99.3), V(-5.4, 0, 99.3), 0, 0)
		gardenWall(V(5.4, 0, 99.3), V(71.3, 0, 99.3), 0, 0)
		kit("G4Gate", gw, T * CFrame.new(0, -0.05, 99.3))
		for _, x in { -71.3, -59, -47, -35, -23, -11.9, 11.9, 23, 35, 47, 59, 71.3 } do
			wallPier(x, 99.3, math.abs(x) > 70 or math.abs(x) == 35)
		end
		for _, x in { -71.3, 71.3 } do
			gardenWall(V(x, 0, -0.05), V(x, 0, 99.3), 0.05 + tk, tk)
			for _, z in { 12, 24, 36, 48, 60, 72, 86 } do
				if not (x < 0 and z > 9 and z < 59) then -- none behind the Fern House
					wallPier(x, z, false)
				end
			end
			if hf.letter == "A" then
				wallPier(x, 0, false)
			end
		end

		------------------------------------------------------------------------- the world: park, trees, town
		local wf = folder(secWorld, "Park" .. hf.letter)
		skin(wf, "Park", -420, 420, 99.9, 420, -0.1, L.lawnPark, T)
		skin(wf, "Park", 72, 419, -0.05, 100.05, -0.13, L.lawnPark, T)
		skin(wf, "Park", -418, -72.6, 0, 100.05, -0.16, L.lawnPark, T)
		-- a gravel avenue past the gate
		skin(wf, "Avenue", -6, 6, 100.5, 175, -0.06, L.gravel, T)
		skin(wf, "Avenue", -150, 150, 128, 138, -0.03, L.gravel, T)
		for i = 0, 15 do
			local x = -135 + i * 18 + rng:NextNumber() * 6
			if math.abs(x) > 12 then
				plant(
					"G4R_Pine",
					wf,
					T
						* CFrame.new(x, -0.1, 116 + rng:NextNumber() * 8)
						* yaw(rng:NextNumber() * 360),
					0.42 + rng:NextNumber() * 0.15
				)
			end
			plant(
				"G4R_PineFar",
				wf,
				T
					* CFrame.new(x + 7, -0.1, 150 + rng:NextNumber() * 20)
					* yaw(rng:NextNumber() * 360),
				0.6 + rng:NextNumber() * 0.25
			)
		end
		for i = 0, 6 do
			local z = 6 + i * 14
			plant(
				"G4R_Pine",
				wf,
				T * CFrame.new(86 + rng:NextNumber() * 8, -0.13, z) * yaw(rng:NextNumber() * 360),
				0.42 + rng:NextNumber() * 0.15
			)
			plant(
				"G4R_PineFar",
				wf,
				T
					* CFrame.new(-112 - rng:NextNumber() * 14, -0.16, z + 5)
					* yaw(rng:NextNumber() * 360),
				0.55 + rng:NextNumber() * 0.2
			)
		end
		-- a row of brick town houses facing the park (gabled, slate roofs, windows in rows)
		local tf = folder(secWorld, "Town" .. hf.letter)
		local x = -160
		while x < 160 do
			local w = 22 + rng:NextInteger(0, 3) * 4
			local h = 26 + rng:NextInteger(0, 3) * 6
			local lk = look(
				hex("A2583F"):Lerp(hex("C9B28C"), rng:NextNumber() * 0.6),
				"G4_Brick",
				Enum.Material.Brick
			)
			house(tf, "TownHouse", CFrame.new(x + w / 2, 0, 205), w - 0.6, 18, h, 6, lk, T, 0.2)
			for row = 0, math.floor((h - 8) / 7) do
				local cols = math.floor((w - 4) / 5.5)
				for c = 0, cols - 1 do
					local wx = x + w / 2 + (c - (cols - 1) / 2) * 5.5
					local wy = 4 + row * 7
					box(
						tf,
						"TownWindow",
						V(wx - 1.0, wy, 195.9),
						V(wx + 1.0, wy + 3.4, 196.05),
						L.glassDark,
						false,
						T
					)
					box(
						tf,
						"TownSill",
						V(wx - 1.3, wy - 0.35, 195.7),
						V(wx + 1.3, wy + 0.02, 196.05),
						L.stone,
						false,
						T
					)
				end
			end
			x += w
		end
	end

	--------------------------------------------------------------------------------------------- spawns, bounds, stage
	local SPAWNS = { { -12, 90 }, { 0, 92 }, { 12, 90 }, { -6, 86 }, { 6, 86 } }
	for _, hf in halves do
		for i, s in SPAWNS do
			local sp = Instance.new("SpawnLocation")
			sp.Name = "Spawn_" .. hf.letter .. i
			sp.Size = V(4, 0.2, 4)
			sp.CFrame = ORIGIN * hf.T * CFrame.new(s[1], 0.2, s[2])
			sp.Anchored = true
			sp.Transparency = 1
			sp.CanCollide = false
			sp.CanQuery = false
			sp.CanTouch = false
			sp.Neutral = true
			sp.Enabled = false
			sp.Duration = 0
			sp:ClearAllChildren()
			CollectionService:AddTag(sp, "ArenaSpawn_" .. hf.letter)
			sp.Parent = secSpawns
		end
	end
	local function bound(a: Vector3, b: Vector3)
		local p = box(secBounds, "Bound", a, b, L.none, true, I)
		p.Transparency = 1
		p.CanQuery = false
		p.CastShadow = false
	end
	bound(V(70.2, -10, -99), V(72.2, 50, 99))
	bound(V(-72.2, -10, -99), V(-70.2, 50, 99))
	bound(V(-72.2, -10, 98.6), V(72.2, 50, 100.6))
	bound(V(-72.2, -10, -100.6), V(72.2, 50, -98.6))
	bound(V(-72.2, 50, -100.6), V(72.2, 52, 100.6))
	local stage = part(map, "WinnerStage", V(4, 0.2, 4), CFrame.new(0, 0.25, 44), L.paving)
	stage.Transparency = 1
	stage.CastShadow = false
	stage.CanCollide = false
	stage.CanQuery = false
	CollectionService:AddTag(stage, "WinnerStage")

	--------------------------------------------------------------------------------------------- lighting
	local lightCfg = Instance.new("Configuration")
	lightCfg.Name = "Lighting"
	CollectionService:AddTag(lightCfg, "GGAsset_MatchMaps_422")
	CollectionService:AddTag(lightCfg, "GauntletAuthoredData")
	lightCfg.Parent = map
	local fx = folder(map, "LightingFx")
	local atm = Instance.new("Atmosphere")
	atm.Density = 0.3
	atm.Offset = 0.12
	atm.Haze = 1.1
	atm.Glare = 0.25
	atm.Color = Color3.fromRGB(214, 222, 206)
	atm.Decay = Color3.fromRGB(150, 172, 150)
	atm.Parent = fx
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.3
	bloom.Size = 24
	bloom.Threshold = 2
	bloom.Parent = fx
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "Grade"
	cc.Contrast = 0.06
	cc.Saturation = 0.08
	cc.TintColor = Color3.fromRGB(255, 251, 242)
	cc.Parent = fx

	-- RIVALS texture pass
	-- RV_Brick10: Roblox's 2022 brick (RIVALS' "Brick 2022") at 10 studs a tile, so courses read at building scale
	if not MaterialService:FindFirstChild("RV_Brick10") then
		local mv = Instance.new("MaterialVariant")
		mv.Name = "RV_Brick10"
		mv.BaseMaterial = Enum.Material.Brick
		mv.StudsPerTile = 10
		mv.ColorMap = "rbxassetid://9920482813"
		mv.NormalMap = "rbxassetid://9438453152"
		mv.RoughnessMap = "rbxassetid://9438453413"
		mv.MaterialPattern = Enum.MaterialPattern.Regular
		mv.Parent = MaterialService
	end
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") then
			local r = RIVALS_REMAP[d.Material.Name .. "|" .. d.MaterialVariant]
			if r then
				d.Material = r[1]
				d.MaterialVariant = r[2]
			end
		end
	end

	map.Parent = workspace
	return string.format("Greenhouse4 built: %d parts", count)
end
