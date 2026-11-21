--!strict
-- Rooftops4 (regular map, 1v1-2v2), the whole build (2026-11-21). Concept, layout and build log:
-- vault/01 Design/Maps/Rooftops4.md. Layout rows mirror tools/maps/rooftops4_layout.py; the A half (+Z) is turned
-- 180 degrees for team B. Match place only, edit mode. Returns a function; run it with require(<a clone>)().
--
-- A city block at blue hour: three buildings in a row split by two alleys (the fall). Each team owns a roof (level 0)
-- with a front row of roof structures along its alley (lift room, stair hut, shed, plant room, chimney, vent stack),
-- open only at the three crossings: a plank bridge, a steel catwalk and a fire-escape bridge. Behind the front row:
-- a +8 fire-escape deck, the spawn penthouse (the baffle), a skylight, AC units. The middle building has a sunken
-- roof court (-6) round the brick pump house that carries the water tank (the landmark), and two wings: a +8
-- billboard deck (stair + step) and a +3.5 skylight roof with a glass lantern, staggered by the turn.
-- Buildings are Parts with soft MaterialVariants (no normal maps): brick masses, tar roof skins, stone copings.
-- Kit pieces (ServerStorage.MapKit.Rooftops4, tools/blender/maps_rooftops4): the tank, AC units, condensers,
-- skylights, the lantern, vents, dishes, billboards, neon icon signs (no text), stairs, bridges, windows, doors,
-- fire escapes, city towers. Team colours: A red brick + amber neon, B buff brick + pink neon.
-- Collision: masses are their own collision; kit props get invisible boxes; rails get invisible guards (shots
-- pass) so nobody stands on them. Contract: Spawns (ArenaSpawn_A/B), Barriers (empty), Bounds, KillDepth + Lighting
-- (authored data 419 / 420), LightingFx, WinnerStage. Joins never share a plane: touching pieces overlap or keep a
-- hairline gap.

local CollectionService = game:GetService("CollectionService")
local MaterialService = game:GetService("MaterialService")
local PhysicsService = game:GetService("PhysicsService")
local ServerStorage = game:GetService("ServerStorage")

local ORIGIN = CFrame.new(6000, 200, 33000) -- the team roofs' level at the map centre
local ROT = CFrame.Angles(0, math.pi, 0)
local V = Vector3.new
local STREET = -60

local function hex(h: string): Color3
	return Color3.fromHex(h)
end
local C = {
	tar = hex("7A7D83"),
	tarLight = hex("888B91"),
	paver = hex("B0AA9F"),
	stone = hex("C9BFAE"),
	stoneDark = hex("A39A8A"),
	render = hex("C7AE8C"),
	renderDark = hex("A88F70"),
	midBrick = hex("7D5546"),
	steel = hex("3D4450"),
	steelLight = hex("7C8691"),
	galv = hex("A9B0B7"),
	glassDark = hex("1F2B38"),
	glow = hex("C99052"),
	leaf = hex("4F6E3A"),
	soil = hex("4A3A2C"),
	asphalt = hex("2F3236"),
	walk = hex("6E6D69"),
	doorPaint = hex("58606B"),
	copper = hex("9A6A43"),
	terracotta = hex("A55A3A"),
}
type Side = {
	brick: Color3,
	brickDark: Color3,
	neon: Color3,
	bill: Color3,
	stripe: Color3,
	door: Color3,
	hutIcon: string,
	billIcon: string,
}
local SIDE: { [string]: Side } = {
	A = {
		brick = hex("9A4A36"),
		brickDark = hex("7A3829"),
		neon = hex("FFB347"),
		bill = hex("C8462E"),
		stripe = hex("F2C14E"),
		door = hex("7A2E26"),
		hutIcon = "R4NeonCup",
		billIcon = "R4NeonStar",
	},
	B = {
		brick = hex("B7895C"),
		brickDark = hex("94683F"),
		neon = hex("FF5FA8"),
		bill = hex("5B3C8C"),
		stripe = hex("FF8FC4"),
		door = hex("4A3A78"),
		hutIcon = "R4NeonCup",
		billIcon = "R4NeonBolt",
	},
}
-- soft variants (owner 2026-11-21: not too much texture): colour maps only, no normal maps
local VARIANTS = {
	R4_Brick = { "Brick", 7, "107246436113114" },
	R4_Tar = { "Slate", 10, "76772826954213" },
	R4_Render = { "Concrete", 14, "119615065244839" },
	R4_Concrete = { "Concrete", 12, "98131730598502" },
	R4_Asphalt = { "Asphalt", 10, "129833585742683" },
	R4_Plate = { "DiamondPlate", 5, "116955307704363" },
	R4_Stone = { "Limestone", 10, "73274454631456" },
}

type Look = { color: Color3, mat: Enum.Material?, variant: string? }
local function look(color: Color3, variant: string?, mat: Enum.Material?): Look
	return { color = color, variant = variant, mat = mat }
end
local L = {
	tar = look(C.tar, "R4_Tar", Enum.Material.Slate),
	paver = look(C.paver, "R4_Concrete", Enum.Material.Concrete),
	stone = look(C.stone, "R4_Stone", Enum.Material.Limestone),
	stoneDark = look(C.stoneDark, "R4_Stone", Enum.Material.Limestone),
	render = look(C.render, "R4_Render", Enum.Material.Concrete),
	renderDark = look(C.renderDark, "R4_Render", Enum.Material.Concrete),
	midBrick = look(C.midBrick, "R4_Brick", Enum.Material.Brick),
	steel = look(C.steel, nil, Enum.Material.Metal),
	steelLight = look(C.steelLight, nil, Enum.Material.Metal),
	galv = look(C.galv, nil, Enum.Material.Metal),
	plate = look(C.steelLight, "R4_Plate", Enum.Material.DiamondPlate),
	glassDark = look(C.glassDark),
	glow = look(C.glow, nil, Enum.Material.Neon),
	leaf = look(C.leaf, nil, Enum.Material.LeafyGrass),
	soil = look(C.soil, nil, Enum.Material.Ground),
	asphalt = look(C.asphalt, "R4_Asphalt", Enum.Material.Asphalt),
	walk = look(C.walk, "R4_Concrete", Enum.Material.Concrete),
	door = look(C.doorPaint, nil, Enum.Material.Metal),
	copper = look(C.copper, nil, Enum.Material.Metal),
	terracotta = look(C.terracotta, nil, Enum.Material.Brick),
	none = look(C.stone),
	line = look(hex("C9A03A")),
	crateWood = look(hex("8A6A44"), nil, Enum.Material.Wood),
	crateFrame = look(hex("5E4630"), nil, Enum.Material.Wood),
}
local function brick(c: Color3): Look
	return look(c, "R4_Brick", Enum.Material.Brick)
end

-- invisible map blockers stop bodies, not shots (Config/Collision MAP_BLOCKERS; CharacterService sets it up at
-- runtime too)
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
			mv.MaterialPattern = Enum.MaterialPattern.Regular
			mv.Parent = MaterialService
		end
	end
end

return function(): string
	assert(game.PlaceId == 133387545285290, "Rooftops4: not the match place")
	ensureVariants()
	ensureBlockerGroup()
	local old = workspace:FindFirstChild("Rooftops4")
	if old then
		old:Destroy()
	end
	local map = Instance.new("Model")
	map.Name = "Rooftops4"
	map.WorldPivot = ORIGIN
	CollectionService:AddTag(map, "GGAsset_MatchMaps_419")
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
	local secWorld = folder(map, "World")
	local secSpawns = folder(map, "Spawns")
	folder(map, "Barriers")
	local secBounds = folder(map, "Bounds")
	local count = 0
	local rng = Random.new(41921)

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
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = solid == true
		p.CanQuery = solid == true
		p.CanTouch = false
		p.CastShadow = math.max(size.X, size.Y, size.Z) >= 4
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
		return part(
			parent,
			name,
			hi - lo,
			(T or CFrame.identity) * CFrame.new((lo + hi) / 2),
			lk,
			solid
		)
	end
	-- invisible collision box (blocks players and shots)
	local function col(name: string, a: Vector3, b: Vector3, T: CFrame): BasePart
		local p = box(secCollision, name, a, b, L.none, true, T)
		p.Transparency = 1
		p.CastShadow = false
		return p
	end
	-- invisible player blocker (shots pass): keeps players off perches and rails
	local function blocker(name: string, a: Vector3, b: Vector3, T: CFrame): BasePart
		local p = col(name, a, b, T)
		p.CanQuery = false
		p.CollisionGroup = BLOCKERS
		return p
	end
	local function kit(
		piece: string,
		parent: Instance,
		cf: CFrame,
		scale: number?,
		side: Side?
	): Model
		local libF = ServerStorage.MapKit:FindFirstChild("Rooftops4")
		local src = libF and libF:FindFirstChild(piece)
		assert(src and src:IsA("Model"), "missing kit piece Rooftops4." .. piece)
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
				if side then
					if string.find(d.Name, "NeonPaint") then
						d.Color = side.neon
					elseif string.find(d.Name, "BillPaint") then
						d.Color = side.bill
					elseif string.find(d.Name, "BillStripe") then
						d.Color = side.stripe
					elseif string.find(d.Name, "DoorPaint") then
						d.Color = side.door
					end
				end
				count += 1
			end
		end
		m.Parent = parent
		return m
	end
	-- a kit piece on a wall: its back just inside the wall plane, its front out along n
	local function onWall(
		piece: string,
		parent: Instance,
		p: Vector3,
		n: Vector3,
		T: CFrame,
		scale: number?,
		side: Side?
	): Model
		local q = p - n * 0.02
		return kit(piece, parent, T * CFrame.lookAt(q, q + n), scale, side)
	end
	local function light(
		parent: Instance,
		cls: string,
		range: number,
		bright: number,
		color: Color3,
		face: Enum.NormalId?
	)
		local l = Instance.new(cls) :: any
		l.Range = range
		l.Brightness = bright
		l.Color = color
		l.Shadows = false
		if face then
			l.Face = face
			l.Angle = 100
		end
		l.Parent = parent
	end
	local function addLamp(m: Model, range: number, bright: number)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and string.find(d.Name, "Lamp") then
				light(d, "PointLight", range, bright, hex("FFD9A0"))
				return
			end
		end
	end
	-- the window panes of a kit window: lit warm or dark glass
	local function paneLook(m: Model, lit: boolean)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and string.find(d.Name, "WinPane") then
				if lit then
					d.Material = Enum.Material.Neon
					d.Color = if rng:NextNumber() < 0.5 then C.glow else hex("B9844B")
				else
					d.Material = Enum.Material.Glass
					d.Color = C.glassDark
					d.Transparency = 0
					d.Reflectance = 0.15
				end
			end
		end
	end

	--------------------------------------------------------------------------------------------- shared builders
	-- a mass with a tar roof skin (the walking surface, 0.04 above the mass top) and a stone coping ring
	local function skin(
		parent: Instance,
		x0: number,
		x1: number,
		z0: number,
		z1: number,
		y: number,
		T: CFrame,
		lk: Look?
	)
		return box(
			parent,
			"Roof",
			V(x0 + 0.08, y - 0.3, z0 + 0.08),
			V(x1 - 0.08, y + 0.04, z1 - 0.08),
			lk or L.tar,
			true,
			T
		)
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
		T: CFrame
	)
		local ins = 0.1
		box(parent, name, V(x0 - out, y0, z0 - out), V(x1 + out, y1, z0 + ins), lk, false, T)
		box(parent, name, V(x0 - out, y0, z1 - ins), V(x1 + out, y1, z1 + out), lk, false, T)
		local o2 = out - 0.05
		box(
			parent,
			name,
			V(x0 - o2, y0 + 0.04, z0 - o2),
			V(x0 + ins, y1 - 0.04, z1 + o2),
			lk,
			false,
			T
		)
		box(
			parent,
			name,
			V(x1 - ins, y0 + 0.04, z0 - o2),
			V(x1 + o2, y1 - 0.04, z1 + o2),
			lk,
			false,
			T
		)
	end
	-- a roof structure: a mass from the floor y0 to y0 + h, a stone coping that overhangs, a base course
	local function hut(
		parent: Instance,
		name: string,
		x0: number,
		x1: number,
		z0: number,
		z1: number,
		y0: number,
		h: number,
		lk: Look,
		T: CFrame
	): BasePart
		local m = box(parent, name, V(x0, y0 - 0.05, z0), V(x1, y0 + h - 0.35, z1), lk, true, T)
		ring(parent, name .. "Coping", x0, x1, z0, z1, y0 + h - 0.42, y0 + h, 0.22, L.stone, T)
		box(
			parent,
			name .. "Cap",
			V(x0 + 0.05, y0 + h - 0.38, z0 + 0.05),
			V(x1 - 0.05, y0 + h - 0.06, z1 - 0.05),
			L.tar,
			false,
			T
		)
		ring(parent, name .. "Base", x0, x1, z0, z1, y0 - 0.05, y0 + 0.55, 0.1, L.stoneDark, T)
		return m
	end
	-- a steel guard rail along a line at floor y (posts, top and mid rail), with an invisible guard (shots pass); the
	-- guard stands 9 tall so its own top is out of jump reach
	local postSeen: { [string]: boolean } = {}
	local function rail(parent: Instance, a: Vector3, b: Vector3, T: CFrame)
		local d = b - a
		local len = d.Magnitude
		local dir = d.Unit
		local n = math.max(1, math.floor(len / 4 + 0.5))
		-- rails along X sit 0.02 lower than rails along Z, so tops that cross at a corner never share a plane
		local lift = if math.abs(dir.X) > 0.5 then 0 else 0.02
		for i = 0, n do
			local p = a + dir * (len * i / n)
			local w = (ORIGIN * T):PointToWorldSpace(p)
			local key = string.format("%.1f,%.1f,%.1f", w.X, w.Y, w.Z)
			if postSeen[key] then
				continue -- a corner post the previous rail already set
			end
			postSeen[key] = true
			box(
				parent,
				"RailPost",
				p + V(-0.11, -0.05, -0.11),
				p + V(0.11, 3.35, 0.11),
				L.steel,
				false,
				T
			)
		end
		local mid = (a + b) / 2
		local cf = CFrame.lookAt(mid, b)
		part(
			parent,
			"RailTop",
			V(0.18, 0.18, len + 0.1),
			T * cf * CFrame.new(0, 3.3 + lift, 0),
			L.steelLight
		)
		part(
			parent,
			"RailMid",
			V(0.14, 0.14, len - 0.05),
			T * cf * CFrame.new(0, 1.75 + lift, 0),
			L.steelLight
		)
		local g = part(
			secCollision,
			"RailGuard",
			V(0.4, 9, len + 0.2),
			T * cf * CFrame.new(0, 4.45, 0),
			L.none,
			true
		)
		g.Transparency = 1
		g.CanQuery = false
		g.CollisionGroup = BLOCKERS
		g.CastShadow = false
	end
	-- windows on a wall: kit windows (rows listed in kitRows) or Part windows (cheap) along u at sill heights
	-- face: a point on the wall plane `p0`, the run direction `ud`, the outward normal `n`
	local function windowRow(
		parent: Instance,
		p0: Vector3,
		ud: Vector3,
		n: Vector3,
		u0: number,
		u1: number,
		step: number,
		y: number,
		useKit: boolean,
		skips: { { number } },
		T: CFrame,
		litShare: number
	)
		local u = u0
		while u <= u1 + 0.01 do
			local skip = false
			for _, s in skips do
				if u > s[1] - 2 and u < s[2] + 2 then
					skip = true
				end
			end
			if not skip then
				local p = p0 + ud * u + V(0, y, 0)
				local lit = rng:NextNumber() < litShare
				if useKit then
					local m = onWall("R4Window", parent, p, n, T)
					paneLook(m, lit)
				else
					-- sill, pane, lintel as Parts (far rows)
					local w = 1.6
					local a = p - ud * w + n * 0.05
					box(
						parent,
						"Pane",
						a - V(0, 0.05, 0),
						p + ud * w + V(0, 4.45, 0) - n * 0.03,
						if lit then L.glow else L.glassDark,
						false,
						T
					)
					box(
						parent,
						"Sill",
						p - ud * (w + 0.2) - V(0, 0.35, 0) - n * 0.03,
						p + ud * (w + 0.2) + n * 0.4,
						L.stone,
						false,
						T
					)
					box(
						parent,
						"Lintel",
						p - ud * (w + 0.25) + V(0, 4.4, 0) - n * 0.03,
						p + ud * (w + 0.25) + V(0, 5.0, 0) + n * 0.22,
						L.stone,
						false,
						T
					)
				end
			end
			u += step
		end
	end
	-- a parapet run along x (z fixed) or along z (x fixed): brick wall + stone coping; `inset` keeps the runs
	-- that meet at a corner off each other's planes
	local function parapetX(
		parent: Instance,
		x0: number,
		x1: number,
		zIn: number,
		zOut: number,
		h: number,
		lk: Look,
		T: CFrame
	)
		box(parent, "Parapet", V(x0, -0.05, zIn), V(x1, h - 0.3, zOut), lk, true, T)
		local s = if zOut > zIn then 1 else -1
		box(
			parent,
			"Coping",
			V(x0 - 0.15, h - 0.36, zIn - s * 0.15),
			V(x1 + 0.15, h, zOut + s * 0.15),
			L.stone,
			true,
			T
		) -- nobody stands on the coping (it would lift a jump onto the roof plant)
		blocker("ParapetGuard", V(x0, h, zIn - s * 0.2), V(x1, h + 14, zOut + s * 0.2), T)
	end
	local function parapetZ(
		parent: Instance,
		z0: number,
		z1: number,
		xIn: number,
		xOut: number,
		h: number,
		lk: Look,
		T: CFrame
	)
		local s = if xOut > xIn then 1 else -1
		box(parent, "Parapet", V(xIn, -0.04, z0), V(xOut - s * 0.04, h - 0.32, z1), lk, true, T)
		box(
			parent,
			"Coping",
			V(xIn - s * 0.13, h - 0.38, z0 + 0.03),
			V(xOut + s * 0.1, h - 0.02, z1 - 0.03),
			L.stone,
			true,
			T
		)
		blocker("ParapetGuard", V(xIn - s * 0.2, h - 0.02, z0), V(xOut + s * 0.2, h + 14, z1), T)
	end

	-- a wooden crate (low cover): a body, corner battens and two bands, nothing sharing the body's planes
	local function crate(
		parent: Instance,
		cx: number,
		cz: number,
		y: number,
		sx: number,
		sz: number,
		h: number,
		T: CFrame
	)
		local x0, x1, z0, z1 = cx - sx / 2, cx + sx / 2, cz - sz / 2, cz + sz / 2
		box(parent, "Crate", V(x0, y - 0.03, z0), V(x1, y + h, z1), L.crateWood, true, T)
		for _, c in { { x0, z0 }, { x1, z0 }, { x1, z1 }, { x0, z1 } } do
			box(
				parent,
				"CrateBatten",
				V(c[1] - 0.16, y + 0.02, c[2] - 0.16),
				V(c[1] + 0.16, y + h - 0.03, c[2] + 0.16),
				L.crateFrame,
				false,
				T
			)
		end
		ring(parent, "CrateBand", x0, x1, z0, z1, y + 0.03, y + 0.35, 0.07, L.crateFrame, T)
		ring(parent, "CrateBand", x0, x1, z0, z1, y + h - 0.38, y + h - 0.05, 0.07, L.crateFrame, T)
	end

	-- painted wall bands in the side's colours on a blank face: three bands, 0.04 proud, inside the face's edges
	-- (F: E = +X face at x = c, W = -X, N = +Z face at z = c; u0..u1 along the face, y0..y1 up)
	local function wallBands(
		parent: Instance,
		F: string,
		c: number,
		u0: number,
		u1: number,
		y0: number,
		y1: number,
		sd: Side,
		T: CFrame
	)
		local hgt = y1 - y0
		local bands = { { 0, 0.42, sd.bill }, { 0.42, 0.58, sd.stripe }, { 0.58, 1, sd.bill } }
		for i, b in bands do
			local ya, yb = y0 + hgt * (b[1] :: number), y0 + hgt * (b[2] :: number)
			-- the middle band overlaps its neighbours and stands a little prouder (no shared planes)
			local o = if i == 2 then 0.06 else 0.04
			if i == 2 then
				ya, yb = ya - 0.05, yb + 0.05
			end
			local lk = look(b[3] :: Color3)
			if F == "E" then
				box(parent, "WallPaint", V(c - 0.02, ya, u0), V(c + o, yb, u1), lk, false, T)
			elseif F == "W" then
				box(parent, "WallPaint", V(c - o, ya, u0), V(c + 0.02, yb, u1), lk, false, T)
			else
				box(parent, "WallPaint", V(u0, ya, c - 0.02), V(u1, yb, c + o), lk, false, T)
			end
		end
	end
	-- a lamp post marking a way up or down (thin, no collision), in a colour
	local function wayLamp(parent: Instance, x: number, z: number, tint: Color3, T: CFrame)
		box(
			parent,
			"WayPost",
			V(x - 0.16, -0.03, z - 0.16),
			V(x + 0.16, 6.2, z + 0.16),
			L.steel,
			false,
			T
		)
		local head = box(
			parent,
			"WayLamp",
			V(x - 0.42, 6.15, z - 0.42),
			V(x + 0.42, 6.75, z + 0.42),
			look(tint, nil, Enum.Material.Neon),
			false,
			T
		)
		box(
			parent,
			"WayCap",
			V(x - 0.5, 6.7, z - 0.5),
			V(x + 0.5, 6.88, z + 0.5),
			L.steel,
			false,
			T
		)
		light(head, "PointLight", 15, 1.5, tint)
	end

	--------------------------------------------------------------------------------------------- the halves
	local halves = {
		{ letter = "A", T = CFrame.identity, side = SIDE.A },
		{ letter = "B", T = ROT, side = SIDE.B },
	}
	for _, hf in halves do
		local T, sd = hf.T, hf.side
		local f = folder(secStructure, "Half" .. hf.letter)
		local pf = folder(secProps, "Half" .. hf.letter)
		local bk, bkD = brick(sd.brick), brick(sd.brickDark)

		------------------------------------------------------------------------- the team building (z 48..96)
		box(f, "TeamBuilding", V(-70, STREET - 0.5, 48), V(70, -0.6, 96), bk, true, T)
		skin(f, -70, 70, 48, 96, -0.04, T) -- top at 0
		ring(f, "Cornice", -70, 70, 48, 96, -1.25, -0.3, 0.4, L.stone, T)
		ring(f, "StringCourse", -70, 70, 48, 96, -7.7, -7.15, 0.18, L.stoneDark, T)
		ring(f, "BaseCourse", -70, 70, 48, 96, STREET - 0.5, STREET + 4, 0.25, bkD, T)
		-- parapets: sides and back (brick 3 tall, coping); the back run takes the corners
		parapetX(f, -70.15, 70.15, 95.1, 96.15, 3.1, bk, T)
		parapetZ(f, 48.95, 95.08, 69.0, 70.15, 3.1, bk, T)
		parapetZ(f, 48.95, 95.08, -69.0, -70.15, 3.1, bk, T)
		-- alley curb (1 tall, you can step off) with gaps at the three crossings
		local crossA = { { -49.2, -42.8 }, { 9.8, 18.2 }, { 54.8, 61.2 } }
		local function alleyCurb(zFace: number, zIn: number, gaps: { { number } }, lk: Look)
			local s = if zIn > zFace then 1 else -1
			local x = -68.95
			local runs = {}
			for _, g in gaps do
				table.insert(runs, { x, g[1] })
				x = g[2]
			end
			table.insert(runs, { x, 68.95 })
			for _, r in runs do
				box(f, "Curb", V(r[1], -0.35, zFace - s * 0.1), V(r[2], 0.95, zIn), lk, true, T)
				box(
					f,
					"CurbCap",
					V(r[1] - 0.1, 0.9, zFace - s * 0.22),
					V(r[2] + 0.1, 1.2, zIn + s * 0.12),
					L.stone,
					true,
					T
				)
			end
		end
		alleyCurb(48, 48.9, crossA, bk)
		-- roof finish: paver walkways along the lanes, a few membrane seams
		for _, w in
			{
				{ -50, -42, 49, 62 },
				{ 9, 19, 49, 66 },
				{ 52, 62, 49, 64 },
				{ -21, -16, 66, 86 },
				{ 16, 21, 66, 86 },
				{ -42.1, 52.1, 62.2, 65.9, 0.01 },
			}
		do
			local lift = w[5] or 0 -- the cross strip sits a hair higher where strips cross
			box(
				f,
				"Pavers",
				V(w[1], -0.02 - lift, w[3]),
				V(w[2], 0.09 + lift, w[4]),
				L.paver,
				false,
				T
			)
			local alongZ = (w[2] - w[1]) < (w[4] - w[3])
			for _, e in { 0, 1 } do
				if alongZ then
					local x = if e == 0 then w[1] + 0.35 else w[2] - 0.35
					box(
						f,
						"WalkLine",
						V(x - 0.15, 0.0, w[3] + 0.4),
						V(x + 0.15, 0.12, w[4] - 0.6),
						L.line,
						false,
						T
					)
				else
					local z = if e == 0 then w[3] + 0.35 else w[4] - 0.35
					box(
						f,
						"WalkLine",
						V(w[1] + 0.4, 0.0, z - 0.15),
						V(w[2] - 0.4, 0.14, z + 0.15),
						L.line,
						false,
						T
					)
				end
			end
		end
		for gx = -64, 64, 16 do
			box(
				f,
				"SeamX",
				V(gx - 0.15, -0.01, 57.4),
				V(gx + 0.15, 0.08, 94.6),
				look(C.tarLight, "R4_Tar", Enum.Material.Slate),
				false,
				T
			)
		end
		for _, zs in { 70, 82 } do
			box(
				f,
				"Seam",
				V(-68.5, -0.02, zs),
				V(68.5, 0.07, zs + 0.3),
				look(C.tarLight, "R4_Tar", Enum.Material.Slate),
				false,
				T
			)
		end

		-- front row (z 49..57): each out of jump reach (10+), each with its own character
		hut(f, "LiftRoom", -68.95, -52, 49.1, 57, 0, 12, bk, T)
		ring(f, "LiftBand", -69, -52, 49.1, 57, 7.2, 7.8, 0.12, L.stone, T)
		onWall("R4Door", pf, V(-60, 0.0, 57), V(0, 0, 1), T, 1, sd)
		for _, x in { -66, -56 } do -- louvre panels on the alley face
			box(f, "Louvre", V(x - 1.5, 3, 49.0), V(x + 1.5, 6, 49.12), L.steel, false, T)
			for k = 0, 5 do
				box(
					f,
					"LouvreSlat",
					V(x - 1.4, 3.25 + k * 0.45, 48.92),
					V(x + 1.4, 3.45 + k * 0.45, 49.05),
					L.galv,
					false,
					T
				)
			end
		end
		kit("R4Gooseneck", pf, T * CFrame.new(-56, 11.94, 52) * CFrame.Angles(0, math.pi / 2, 0))
		kit("R4Vent", pf, T * CFrame.new(-64, 11.94, 53))
		kit("R4Dish", pf, T * CFrame.new(-66.5, 11.94, 55) * CFrame.Angles(0, math.rad(200), 0))

		hut(f, "StairHut", -40, -12, 49.1, 57, 0, 10, L.render, T)
		onWall("R4Door", pf, V(-33, 0.0, 57), V(0, 0, 1), T, 1, sd)
		onWall("R4Door", pf, V(-17, 0.0, 57), V(0, 0, 1), T, 1, sd)
		onWall(sd.hutIcon, pf, V(-26, 1.6, 49.1), V(0, 0, -1), T, 1, sd) -- the side's neon on its alley face
		kit("R4Condenser", pf, T * CFrame.new(-36, 9.94, 53))
		kit("R4Vent", pf, T * CFrame.new(-20, 9.94, 53))

		-- the shed: corrugated steel, vertical ribs
		-- the shed: painted corrugated steel, ribs on every open face (a plain face read as a slab)
		local shedLk = look(hex("66756C"), nil, Enum.Material.Metal)
		box(f, "Shed", V(-11.95, -0.05, 49.1), V(6, 9.6, 56), shedLk, true, T)
		box(f, "ShedRoof", V(-12.25, 9.5, 48.8), V(6.3, 9.92, 56.3), L.steel, true, T)
		for x = -11, 5, 2 do
			box(f, "Rib", V(x - 0.12, 0, 48.95), V(x + 0.12, 9.55, 49.15), shedLk, false, T)
			if x ~= -3 then -- the door
				box(f, "Rib", V(x - 0.12, 0, 55.95), V(x + 0.12, 9.55, 56.15), shedLk, false, T)
			end
		end
		for z = 50.0, 55.3, 1.75 do
			box(f, "Rib", V(5.95, 0, z - 0.12), V(6.15, 9.55, z + 0.12), shedLk, false, T)
		end
		onWall("R4Door", pf, V(-3, 0.0, 56.15), V(0, 0, 1), T, 1, sd)

		hut(f, "PlantRoom", 22, 34, 49.1, 57, 0, 10, L.render, T)
		for _, x in { 25, 31 } do
			box(f, "Louvre", V(x - 2, 2.5, 48.97), V(x + 2, 7, 49.12), L.steel, false, T)
			for k = 0, 8 do
				box(
					f,
					"LouvreSlat",
					V(x - 1.9, 2.7 + k * 0.48, 48.9),
					V(x + 1.9, 2.9 + k * 0.48, 49.03),
					L.galv,
					false,
					T
				)
			end
		end
		kit("R4Condenser", pf, T * CFrame.new(25, 9.94, 53))
		kit("R4Condenser", pf, T * CFrame.new(31, 9.94, 53))
		-- chimney breast with three flues
		hut(f, "Chimney", 34.05, 48, 50.0, 55, 0, 12, bkD, T)
		for _, x in { 37, 41, 45 } do
			box(f, "Flue", V(x - 0.8, 11.9, 51.7), V(x + 0.8, 13.4, 53.3), L.terracotta, false, T)
			box(
				f,
				"FlueCap",
				V(x - 1.0, 13.35, 51.5),
				V(x + 1.0, 13.6, 53.5),
				L.stoneDark,
				false,
				T
			)
		end
		-- vent stack: a galvanised exhaust riser with seam bands and a louvred hood
		box(f, "VentStack", V(62, -0.05, 49.1), V(68.95, 9.2, 57), L.galv, true, T)
		for _, y in { 2, 4.5, 7 } do
			box(f, "VentSeam", V(61.88, y, 48.98), V(68.9, y + 0.25, 57.12), L.steelLight, false, T)
		end
		box(f, "VentHood", V(61.7, 9.15, 48.8), V(68.9, 10.0, 57.3), L.steel, true, T)
		kit("R4Gooseneck", pf, T * CFrame.new(64, 9.98, 54))

		-- fire-escape deck (+8) at the west, its stair from the back, a cabinet as the step
		box(f, "DeckBlock", V(-68.95, -0.05, 64), V(-50, 7.7, 78), bk, true, T)
		skin(f, -68.95, -50, 64, 78, 7.96, T, L.plate)
		ring(f, "DeckCornice", -68.95, -50, 64, 78, 6.9, 7.6, 0.25, L.stone, T)
		windowRow(f, V(-50, 0, 64), V(0, 0, 1), V(1, 0, 0), 10.5, 10.5, 7, 1.6, true, {}, T, 0.7)
		kit("R4Stair8", pf, T * CFrame.new(-60, 0.0, 94)) -- climbs toward -Z to the deck edge at z 78
		wayLamp(f, -56.3, 94.2, sd.neon, T)
		local sw = Instance.new("WedgePart")
		sw.Name = "StairRamp"
		sw.Anchored = true
		sw.Size = V(5, 8, 16)
		sw.CFrame = ORIGIN * T * CFrame.new(-60, 4.04, 86) * CFrame.Angles(0, math.pi, 0) -- rises toward -Z
		sw.Transparency = 1
		sw.CastShadow = false
		sw.Parent = secCollision
		count += 1
		rail(f, V(-68.6, 8.0, 64.4), V(-50.4, 8.0, 64.4), T)
		rail(f, V(-50.4, 8.0, 64.4), V(-50.4, 8.0, 77.6), T)
		rail(f, V(-68.6, 8.0, 77.6), V(-62.8, 8.0, 77.6), T)
		rail(f, V(-57.2, 8.0, 77.6), V(-50.4, 8.0, 77.6), T)
		box(f, "Cabinet", V(-50.0 + 0.0, -0.05, 64.5), V(-45, 3.5, 69.5), L.door, true, T)
		box(f, "CabinetTop", V(-50.15, 3.45, 64.35), V(-44.85, 3.62, 69.65), L.steel, true, T)
		for _, z in { 65.8, 68.2 } do
			box(
				f,
				"CabinetDoor",
				V(-45.08, 0.5, z - 1.0),
				V(-44.9, 3.1, z + 1.0),
				L.steelLight,
				false,
				T
			)
		end
		kit("R4Condenser", pf, T * CFrame.new(-55, 7.96, 70) * CFrame.Angles(0, math.pi / 2, 0))
		crate(f, -62, 71, 8.0, 3, 3, 3.5, T)
		crate(f, -62.2, 74.3, 8.0, 2.6, 2.6, 2.2, T)

		-- tank house (a brick pump room) and the spawn penthouse (the baffle)
		hut(f, "TankHouse", -42, -34, 68, 76, 0, 11, bkD, T)
		onWall("R4Door", pf, V(-38, 0.0, 76), V(0, 0, 1), T, 1, sd)
		kit("R4Vent", pf, T * CFrame.new(-38, 10.94, 72))

		hut(f, "Penthouse", -15, 15, 69.5, 78.5, 0, 12, bk, T)
		ring(f, "PenthouseBand", -15, 15, 69.5, 78.5, 8.6, 9.2, 0.15, L.stone, T)
		windowRow(
			f,
			V(-15, 0, 78.5),
			V(1, 0, 0),
			V(0, 0, 1),
			4,
			26,
			5.5,
			1.5,
			true,
			{ { 13, 17 } },
			T,
			0.8
		)
		windowRow(f, V(-15, 0, 69.5), V(1, 0, 0), V(0, 0, -1), 4, 26, 5.5, 1.5, true, {}, T, 0.6)
		onWall("R4Door", pf, V(0, 0.0, 78.5), V(0, 0, 1), T, 1, sd)
		for _, x in { -9, 9 } do -- brick planters with clipped hedges by the door
			box(f, "Planter", V(x - 3.5, -0.05, 78.6), V(x + 3.5, 1.4, 80.6), bkD, true, T)
			box(
				f,
				"PlanterCap",
				V(x - 3.65, 1.35, 78.45),
				V(x + 3.65, 1.6, 80.75),
				L.stone,
				true,
				T
			)
			box(f, "Hedge", V(x - 3.2, 1.5, 78.85), V(x + 3.2, 3.0, 80.35), L.leaf, false, T)
		end
		kit("R4Condenser", pf, T * CFrame.new(-10.5, 11.94, 72) * CFrame.Angles(0, math.pi / 2, 0))
		kit(
			"R4Condenser",
			pf,
			T * CFrame.new(-10.5, 11.94, 76.2) * CFrame.Angles(0, math.pi / 2, 0)
		)
		-- the home landmark: the side's neon icon back to back on a steel frame on the penthouse roof, seen from the
		-- spawn and from the middle (out of reach)
		for _, px in { -3.2, 3.2 } do
			box(
				f,
				"SignPost",
				V(px - 0.21, 11.9, 73.79),
				V(px + 0.21, 21.6, 74.21),
				L.steel,
				false,
				T
			)
		end
		box(f, "SignBeam", V(-4.9, 21.4, 73.75), V(4.9, 21.8, 74.25), L.steel, false, T)
		for _, dir in { 1, -1 } do
			local q = V(0, 12.3, 74 + dir * 0.2)
			kit(sd.billIcon, pf, T * CFrame.lookAt(q, q + V(0, 0, dir)), 1.25, sd)
		end
		kit("R4Dish", pf, T * CFrame.new(10, 11.94, 72) * CFrame.Angles(0, math.rad(20), 0))
		-- the spawn roof, lived in: string lights from the penthouse to two masts on the back parapet (inside its
		-- guard, so nobody stands on them), planters with clipped hedges behind the spawns, tar patches
		for _, mx in { -14, 14 } do
			box(
				f,
				"LightMast",
				V(mx - 0.15, 3.0, 95.45),
				V(mx + 0.15, 7.4, 95.75),
				L.steel,
				false,
				T
			)
			box(
				f,
				"MastCap",
				V(mx - 0.22, 7.35, 95.38),
				V(mx + 0.22, 7.55, 95.82),
				L.steel,
				false,
				T
			)
			local a, b = V(mx * 0.55, 9.0, 78.6), V(mx, 7.3, 95.6)
			local n = 9
			for k = 0, n - 1 do
				local t0, t1 = k / n, (k + 1) / n
				local sag0, sag1 = 4 * t0 * (1 - t0) * 1.2, 4 * t1 * (1 - t1) * 1.2
				local p0 = a:Lerp(b, t0) - V(0, sag0, 0)
				local p1 = a:Lerp(b, t1) - V(0, sag1, 0)
				local mid = (p0 + p1) / 2
				part(
					f,
					"LightWire",
					V(0.05, 0.05, (p1 - p0).Magnitude + 0.04),
					T * CFrame.lookAt(mid, p1),
					L.steel
				)
				if k > 0 then
					box(
						f,
						"Bulb",
						p0 - V(0.16, 0.42, 0.16),
						p0 + V(0.16, 0.01, 0.16),
						L.glow,
						false,
						T
					)
				end
			end
		end
		for _, px in { -42, 50 } do
			box(f, "Planter", V(px - 4, -0.05, 92.9), V(px + 4, 1.4, 94.9), bkD, true, T)
			box(
				f,
				"PlanterCap",
				V(px - 4.15, 1.35, 92.75),
				V(px + 4.15, 1.6, 95.05),
				L.stone,
				true,
				T
			)
			box(f, "Hedge", V(px - 3.7, 1.5, 93.15), V(px + 3.7, 3.1, 94.65), L.leaf, false, T)
		end
		for _, tp in { { -60, -48, 84, 92 }, { 40, 52, 58, 61.5 }, { -22, -14, 60, 66 } } do
			box(
				f,
				"TarPatch",
				V(tp[1], -0.02, tp[3]),
				V(tp[2], 0.05, tp[4]),
				look(hex("44474D"), "R4_Tar", Enum.Material.Slate),
				false,
				T
			)
		end
		-- conduit runs along the side parapets on small stands
		for _, sx in { -1, 1 } do
			local x = sx * 67.6
			local z0 = if sx < 0 then 80 else 59 -- the west run starts past the fire-escape deck
			box(f, "Conduit", V(x - 0.22, 0.55, z0), V(x + 0.22, 0.99, 93), L.galv, false, T)
			for z = z0 + 1, 92, 4 do
				box(
					f,
					"ConduitStand",
					V(x - 0.3, -0.03, z - 0.12),
					V(x + 0.3, 0.6, z + 0.12),
					L.steel,
					false,
					T
				)
			end
		end

		-- low cover: skylight, AC unit, roof vents (two condensers on a curb); water heater (cooling tower)
		kit("R4Skylight", pf, T * CFrame.new(-28, 0.0, 86))
		col("SkylightCol", V(-34, 0, 82.5), V(-22, 2.5, 89.5), T)
		kit("R4AC", pf, T * CFrame.new(28, 0.0, 68))
		col("ACCol", V(23, 0, 65.5), V(33, 3.5, 70.5), T)
		box(f, "VentCurb", V(32, -0.05, 85), V(40, 0.5, 89), L.paver, true, T)
		kit("R4Condenser", pf, T * CFrame.new(34, 0.5, 87))
		kit("R4Condenser", pf, T * CFrame.new(38, 0.5, 87))
		col("VentCol", V(32, 0, 85), V(40, 3.5, 89), T)
		box(f, "CoolingTower", V(53, -0.05, 71), V(59, 8.8, 77), L.galv, true, T)
		for _, y in { 1.5, 4, 6.5 } do
			box(
				f,
				"TowerBand",
				V(52.88, y, 70.88),
				V(59.12, y + 0.3, 77.12),
				L.steelLight,
				false,
				T
			)
		end
		box(f, "TowerTop", V(52.7, 8.75, 70.7), V(59.3, 10.0, 77.3), L.steel, true, T)
		kit("R4Condenser", pf, T * CFrame.new(56, 9.98, 74), 1.2)
		kit("R4Vent", pf, T * CFrame.new(-8, 0.0, 92.5))
		kit("R4Gooseneck", pf, T * CFrame.new(20, 0.0, 93) * CFrame.Angles(0, math.pi, 0))

		-- alley facade of the team building: kit windows on the top two storeys, Part windows below, fire escapes
		local feA = { { -66, -64 }, { 36, 38 } }
		local function alleyFacade(zFace: number, n: Vector3, gaps: { { number } })
			local skips = {}
			for _, g in gaps do
				table.insert(skips, g)
			end
			for _, fe in feA do
				table.insert(skips, { fe[1] - 3, fe[2] + 3 })
			end
			windowRow(f, V(0, 0, zFace), V(1, 0, 0), n, -64, 64, 7, -6.55, true, skips, T, 0.45)
			windowRow(f, V(0, 0, zFace), V(1, 0, 0), n, -64, 64, 7, -12.55, true, skips, T, 0.4)
			windowRow(f, V(0, 0, zFace), V(1, 0, 0), n, -64, 64, 7, -18.55, false, skips, T, 0.35)
			windowRow(f, V(0, 0, zFace), V(1, 0, 0), n, -64, 64, 7, -24.55, false, skips, T, 0.3)
			windowRow(f, V(0, 0, zFace), V(1, 0, 0), n, -64, 64, 7, -30.55, false, skips, T, 0.25)
			for _, fe in feA do
				local x = (fe[1] + fe[2]) / 2
				for k = 0, 3 do
					onWall("R4FireEsc", pf, V(x, -6.6 - 6 * k, zFace), n, T)
					paneLook(
						onWall("R4Window", pf, V(x - 2.0, -6.55 - 6 * k, zFace), n, T),
						rng:NextNumber() < 0.5
					)
				end
			end
		end
		alleyFacade(48, V(0, 0, -1), crossA)
		-- outer facades: Part windows, two storeys
		for _, y in { -6.55, -12.55 } do
			windowRow(f, V(70, 0, 48), V(0, 0, 1), V(1, 0, 0), 4, 44, 8, y, false, {}, T, 0.4)
			windowRow(f, V(-70, 0, 48), V(0, 0, 1), V(-1, 0, 0), 4, 44, 8, y, false, {}, T, 0.4)
			windowRow(f, V(-70, 0, 96), V(1, 0, 0), V(0, 0, 1), 6, 134, 8, y, false, {}, T, 0.4)
		end

		------------------------------------------------------------------------- the alley crossings (z 37..49)
		kit("R4Plank6", pf, T * CFrame.new(-46, 0.0, 43))
		box(secCollision, "BridgeDeck", V(-49, -0.3, 36.5), V(-43, 0.15, 49.5), L.none, true, T).Transparency =
			1
		blocker("PlankGuard", V(-43.65, 0.15, 37), V(-43.15, 9.3, 49), T) -- over the pipe rail (+X side)
		kit("R4Catwalk8", pf, T * CFrame.new(14, 0.0, 43))
		box(secCollision, "BridgeDeck", V(10, -0.3, 36.5), V(18, 0.12, 49.5), L.none, true, T).Transparency =
			1
		blocker("CatwalkGuard", V(9.6, 0.12, 37), V(10.1, 9.3, 49), T)
		blocker("CatwalkGuard", V(17.9, 0.12, 37), V(18.4, 9.3, 49), T)
		local fe = kit("R4Catwalk6", pf, T * CFrame.new(58, 0.0, 43))
		for _, d in fe:GetDescendants() do
			if d:IsA("BasePart") and string.find(d.Name, "_R4_Steel") then
				d.Color = hex("7E2B24")
			end
		end
		-- crossing lamps, one colour per crossing so each route reads from afar: amber plank, white catwalk,
		-- red fire-escape bridge (thin posts, no collision)
		for _, c in { { -50.4, "FFB866" }, { 9.0, "DCE8FF" }, { 54.2, "FF5A4A" } } do
			for _, zl in { 49.7, 36.3 } do
				local x = c[1] :: number
				local tint = hex(c[2] :: string)
				box(
					f,
					"LampPost",
					V(x - 0.17, -0.03, zl - 0.17),
					V(x + 0.17, 7.2, zl + 0.17),
					L.steel,
					false,
					T
				)
				box(
					f,
					"LampArm",
					V(x - 0.12, 6.95, zl - 0.12),
					V(x + 1.4, 7.15, zl + 0.12),
					L.steel,
					false,
					T
				)
				local head = box(
					f,
					"LampHead",
					V(x + 0.9, 6.55, zl - 0.35),
					V(x + 1.6, 7.0, zl + 0.35),
					look(tint, nil, Enum.Material.Neon),
					false,
					T
				)
				light(head, "PointLight", 16, 1.6, tint)
			end
		end
		box(secCollision, "BridgeDeck", V(55, -0.3, 36.5), V(61, 0.12, 49.5), L.none, true, T).Transparency =
			1
		blocker("FireBridgeGuard", V(54.6, 0.12, 37), V(55.1, 9.3, 49), T)
		blocker("FireBridgeGuard", V(60.9, 0.12, 37), V(61.4, 9.3, 49), T)
		for _, c in secCollision:GetChildren() do
			if c.Name == "BridgeDeck" and c:IsA("BasePart") then
				c.CastShadow = false
			end
		end

		------------------------------------------------------------------------- the middle building, this half
		local crossM = { { -49.2, -42.8 }, { 9.8, 18.2 }, { 54.8, 61.2 } }
		-- north ledge (z 28..38, x -30..30, level 0) over the middle body
		box(f, "Ledge", V(-29.94, -6.65, 28), V(29.94, -0.3, 37.96), L.midBrick, true, T)
		skin(f, -29.94, 29.94, 28, 37.96, -0.04, T)
		box(f, "LedgeCornice", V(-29.95, -1.22, 37.86), V(29.95, -0.38, 38.28), L.stone, false, T)
		-- the alley curb on the middle building's side
		do
			local x = -69.0
			for _, g in crossM do
				box(f, "Curb", V(x, -0.35, 37.0), V(g[1], 0.95, 38.1), L.midBrick, true, T)
				box(
					f,
					"CurbCap",
					V(x - 0.1, 0.9, 36.88),
					V(g[1] + 0.1, 1.2, 38.22),
					L.stone,
					true,
					T
				)
				x = g[2]
			end
			box(f, "Curb", V(x, -0.35, 37.0), V(69.0, 0.95, 38.1), L.midBrick, true, T)
			box(f, "CurbCap", V(x - 0.1, 0.9, 36.88), V(69.1, 1.2, 38.22), L.stone, true, T)
		end
		-- middle facade on the alley (z 38)
		for _, y in { -6.55, -12.55 } do
			windowRow(
				f,
				V(0, 0, 38),
				V(1, 0, 0),
				V(0, 0, 1),
				-63,
				63,
				7,
				y,
				y > -10,
				crossM,
				T,
				0.4
			)
		end
		for _, y in { -18.55, -24.55, -30.55 } do
			windowRow(f, V(0, 0, 38), V(1, 0, 0), V(0, 0, 1), -63, 63, 7, y, false, crossM, T, 0.3)
		end
		for k = 0, 3 do
			onWall("R4FireEsc", pf, V(-23, -6.6 - 6 * k, 38), V(0, 0, 1), T)
		end
		-- court edge: a low curb you can step off, along the ledge (z 28), gap at the steps
		box(f, "CourtCurb", V(-29.9, -0.12, 27.7), V(-2.6, 0.62, 28.55), L.stone, true, T)
		box(f, "CourtCurb", V(8.6, -0.12, 27.7), V(29.9, 0.62, 28.55), L.stone, true, T)
		box(f, "RimLine", V(-29.8, 0.5, 27.97), V(-2.7, 0.66, 28.28), L.line, false, T)
		box(f, "RimLine", V(8.7, 0.5, 27.97), V(29.8, 0.66, 28.28), L.line, false, T)
		-- court steps (0 down to -6 over 10), cheeks and rails
		for k = 1, 8 do
			local top = -6 + 0.75 * k
			box(
				f,
				"Step",
				V(-2, -6.05, 18 + 1.25 * (k - 1)),
				V(8, top, if k == 8 then 27.97 else 18 + 1.25 * k + 0.02),
				L.paver,
				true,
				T
			)
		end
		for _, x in { -2.6, 8.0 } do
			box(f, "StepCheek", V(x, -6.05, 17.7), V(x + 0.6, -5.2, 28.3), L.stone, true, T)
			local cheek = Instance.new("WedgePart")
			cheek.Name = "StepCheekSlope"
			cheek.Anchored = true
			cheek.Size = V(0.6, 6.1, 10.3)
			cheek.CFrame = ORIGIN * T * CFrame.new(x + 0.3, -5.2 + 3.05 - 0.02, 23.15) -- a wedge rises toward +Z, like the steps
			cheek.Material = Enum.Material.Limestone
			cheek.MaterialVariant = "R4_Stone"
			cheek.Color = C.stoneDark
			cheek.Parent = f
			count += 1
		end

		-- billboard deck (+8) on the west wing: brick upper storey, windows to the court, a stair and a landing
		box(f, "BillDeckBlock", V(-69.9, -0.05, 3), V(-36, 7.96, 25), L.midBrick, true, T)
		skin(f, -69.9, -36, 3, 25, 7.96, T, L.plate)
		ring(f, "BillDeckCornice", -69.9, -36, 3, 25, 6.9, 7.6, 0.22, L.stone, T)
		windowRow(f, V(-36, 0, 3), V(0, 0, 1), V(1, 0, 0), 3.5, 18.5, 15, 1.6, true, {}, T, 0.6)
		windowRow(f, V(-69.9, 0, 3), V(1, 0, 0), V(0, 0, -1), 5, 30, 8, 1.6, true, {}, T, 0.5)
		kit("R4Stair8", pf, T * CFrame.new(-33, 0.0, 30)) -- foot at z 30, top at z 14
		wayLamp(f, -36.7, 30.9, sd.neon, T)
		local w2 = Instance.new("WedgePart")
		w2.Name = "StairRamp"
		w2.Anchored = true
		w2.Size = V(5, 8, 16)
		w2.CFrame = ORIGIN * T * CFrame.new(-33, 4.04, 22) * CFrame.Angles(0, math.pi, 0) -- rises toward -Z
		w2.Transparency = 1
		w2.CastShadow = false
		w2.Parent = secCollision
		count += 1
		box(f, "Landing", V(-36.05, 7.84, 10), V(-30.4, 8.04, 14.05), L.plate, true, T)
		for _, p in { { -30.65, 10.25 }, { -30.65, 13.8 }, { -35.6, 10.25 } } do
			box(
				f,
				"LandingPost",
				V(p[1] - 0.15, -0.02, p[2] - 0.15),
				V(p[1] + 0.15, 7.86, p[2] + 0.15),
				L.steel,
				true,
				T
			)
		end
		rail(f, V(-35.9, 8.04, 10.2), V(-30.6, 8.04, 10.2), T)
		rail(f, V(-30.6, 8.04, 10.2), V(-30.6, 8.04, 13.85), T)
		rail(f, V(-69.4, 8.0, 3.4), V(-36.4, 8.0, 3.4), T)
		rail(f, V(-36.4, 8.0, 3.4), V(-36.4, 8.0, 9.9), T)
		rail(f, V(-36.4, 8.0, 14.2), V(-36.4, 8.0, 24.6), T)
		rail(f, V(-50.3, 8.0, 24.6), V(-36.4, 8.0, 24.6), T)
		rail(f, V(-69.4, 8.0, 24.6), V(-55.7, 8.0, 24.6), T)
		-- the billboard on the deck's outer edge, face to the court, the side's neon icon on its face
		local bb = kit(
			"R4Billboard",
			pf,
			T * CFrame.new(-67.2, 7.96, 14) * CFrame.Angles(0, -math.pi / 2, 0),
			1,
			sd
		)
		local bcf = bb:GetPivot()
		local icon = kit(sd.billIcon, pf, CFrame.new(), 1, sd)
		icon:PivotTo(bcf * CFrame.new(4.5, 3.8, -0.25))
		for _, d in bb:GetDescendants() do
			if d:IsA("BasePart") and string.find(d.Name, "Lamp") then
				light(d, "SurfaceLight", 22, 2.2, hex("FFE6C0"), Enum.NormalId.Bottom)
			end
		end
		blocker("BillboardGuard", V(-69.9, 7.96, 3.5), V(-63.5, 22, 24.5), T)
		crate(f, -48, 12, 8.0, 3, 3, 3.5, T)
		crate(f, -48.3, 15.4, 8.0, 2.6, 2.6, 2.2, T)
		crate(f, -44.6, 12.2, 8.0, 2.4, 2.4, 1.8, T)
		-- the step: an electrical cabinet north of the deck
		box(f, "Cabinet", V(-55.5, -0.05, 25.05), V(-50.5, 3.5, 30), L.door, true, T)
		box(f, "CabinetTop", V(-55.65, 3.45, 24.95), V(-50.35, 3.62, 30.15), L.steel, true, T)
		for _, x in { -54.2, -51.8 } do
			box(
				f,
				"CabinetDoor",
				V(x - 1.0, 0.5, 30.0),
				V(x + 1.0, 3.1, 30.16),
				L.steelLight,
				false,
				T
			)
		end
		-- skylight roof (+3.5) on the east wing: render storey, the glass lantern, an elevator overrun with plant
		box(f, "SkyRoofBlock", V(36, -0.05, 4), V(69.9, 3.46, 32), L.render, true, T)
		skin(f, 36, 69.9, 4, 32, 3.46, T)
		ring(f, "SkyRoofCoping", 36, 69.9, 4, 32, 3.1, 3.62, 0.18, L.stone, T)
		kit("R4Lantern", pf, T * CFrame.new(52, 3.48, 18))
		kit("R4Vent", pf, T * CFrame.new(64, 3.47, 8))
		blocker("LanternGuard", V(45.8, 3.5, 12.8), V(58.2, 16, 23.2), T)
		col("LanternCol", V(46, 3.5, 13), V(58, 9, 23), T)
		hut(f, "Overrun", 36.05, 46, 26.5, 31.5, 3.46, 7.6, bk, T)
		kit("R4AC", pf, T * CFrame.new(41, 11.0, 29))
		-- court pieces on this half: the stair bulkhead, the fan housing, the pipe chase, the roof access hut
		hut(f, "Bulkhead", -22.5, -11.5, 17, 25, -6, 10, L.render, T)
		wallBands(f, "E", -11.5, 17.8, 24.2, -4.6, 1.6, sd, T)
		wallBands(f, "N", 25, -21.7, -12.3, -4.6, 1.6, sd, T)
		wallBands(f, "W", -22.5, 17.8, 24.2, -4.6, 1.6, sd, T)
		wayLamp(f, -3.3, 29.0, hex("FFD9A0"), T)
		wayLamp(f, 9.3, 29.0, hex("FFD9A0"), T)
		onWall("R4Door", pf, V(-17, -6.0, 17), V(0, 0, -1), T, 1, sd)
		blocker("BulkheadGuard", V(-22.8, 4.0, 16.7), V(-11.2, 12, 25.3), T)
		box(f, "FanHousing", V(21, -6.05, -4), V(27, 2.6, 18), L.galv, true, T)
		box(f, "FanHousingTop", V(20.8, 2.55, -4.2), V(27.2, 3.0, 18.2), L.steel, true, T)
		for _, z in { -1, 5, 11 } do
			box(f, "Louvre", V(20.85, -4, z), V(21.02, -0.5, z + 4), L.steel, false, T)
			for k = 0, 6 do
				box(
					f,
					"LouvreSlat",
					V(20.78, -3.8 + k * 0.48, z + 0.1),
					V(20.92, -3.6 + k * 0.48, z + 3.9),
					L.galv,
					false,
					T
				)
			end
		end
		kit("R4Condenser", pf, T * CFrame.new(24, 3.0, 0) * CFrame.Angles(0, math.pi / 2, 0))
		kit("R4Condenser", pf, T * CFrame.new(24, 3.0, 12) * CFrame.Angles(0, math.pi / 2, 0))
		blocker("FanGuard", V(20.7, 3.0, -4.3), V(27.3, 12, 18.3), T)
		hut(f, "PipeChase", 19, 25, 28.3, 34.3, 0, 10, bkD, T)
		for _, x in { 19.6, 21.2 } do
			box(f, "Pipe", V(x - 0.3, -6.0, 27.9), V(x + 0.3, 9.0, 28.5), L.copper, false, T)
		end
		hut(f, "AccessHut", -32, -24, 31.5, 37.4, 0, 10, L.midBrick, T)
		wallBands(f, "E", -24, 32.3, 36.6, 1.4, 7.6, sd, T)
		-- a washing line across the alley, hut wall to stair-hut wall, out of reach (8 up)
		do
			local x = -28 + 0.0
			box(
				f,
				"WashLine",
				V(x - 0.04, 7.96, 37.35),
				V(x + 0.04, 8.04, 49.15),
				L.steel,
				false,
				T
			)
			local cloths = {
				{ 39.5, "E8E2D6", 2.0 },
				{ 41.8, "C8462E", 1.6 },
				{ 44.2, "7FA0C8", 2.2 },
				{ 46.6, "F2C14E", 1.4 },
			}
			for i, c in cloths do
				local z = c[1] :: number
				local tint = hex(c[2] :: string)
				local hgt = c[3] :: number
				box(
					f,
					"Cloth",
					V(x - 0.05, 8.0 - hgt, z - 0.8),
					V(x + 0.05, 8.02, z + 0.8),
					look(tint, nil, Enum.Material.Fabric),
					false,
					T
				)
				box(
					f,
					"Peg",
					V(x - 0.09, 7.9, z - 0.6),
					V(x + 0.09, 8.12, z - 0.5 + (i % 2) * 0.01),
					L.door,
					false,
					T
				)
			end
		end
		onWall("R4Door", pf, V(-28, 0.0, 31.5), V(0, 0, -1), T, 1, sd)
	end
	task.wait()

	--------------------------------------------------------------------------------------------- the middle (both halves)
	local mf = folder(secStructure, "Middle")
	local mp = folder(secProps, "Middle")
	local I = CFrame.identity
	box(mf, "MiddleBody", V(-70, STREET - 0.5, -38), V(70, -6.6, 38), L.midBrick, true, I)
	ring(mf, "MidCornice", -70, 70, -38, 38, -7.75, -7.05, 0.3, L.stone, I)
	ring(mf, "MidBase", -70, 70, -38, 38, STREET - 0.5, STREET + 4, 0.25, L.midBrick, I)
	-- the wings (x 30..70 both sides, level 0), the court floor (-6)
	for _, s in { -1, 1 } do
		local x0, x1 = if s < 0 then -69.96 else 29.97, if s < 0 then -29.97 else 69.96
		box(mf, "Wing", V(x0, -6.65, -37.96), V(x1, -0.3, 37.96), L.midBrick, true, I)
		skin(mf, x0, x1, -37.96, 37.96, -0.04, I)
		ring(mf, "WingCornice", x0, x1, -37.96, 37.96, -1.25, -0.35, 0.35, L.stone, I)
		-- outer parapet
		local xo = if s < 0 then -69.96 else 69.96
		parapetZ(mf, -36.95, 36.95, xo - s * 1.0, xo + s * 0.12, 3.1, L.midBrick, I)
		-- court-side curb on the wing edge (x = +-30), step-off height
		box(mf, "CourtCurb", V(s * 29.4, -0.1, -27.95), V(s * 30.6, 0.6, 27.95), L.stone, true, I)
		box(mf, "RimLine", V(s * 29.85, 0.48, -27.85), V(s * 30.15, 0.64, 27.85), L.line, false, I)
		-- the court wall face: brick with a stone band
		box(
			mf,
			"CourtWallBand",
			V(s * 29.87, -3.4, -27.9),
			V(s * 30.0, -2.9, 27.9),
			L.stone,
			false,
			I
		)
	end
	box(mf, "CourtFloor", V(-29.9, -6.65, -27.9), V(29.9, -6.0, 27.9), L.paver, true, I)
	-- the games court: a painted surface with white lines (straight only) and a wall hoop per side, so the sunken
	-- court is a place you can name; drains and puddles sit on the paint
	box(
		mf,
		"CourtPaint",
		V(-26.9, -6.02, -25),
		V(26.9, -5.93, 25),
		look(hex("6E3B30"), "R4_Concrete", Enum.Material.Concrete),
		false,
		I
	)
	local white = look(hex("D9D4C8"))
	for _, sz in { -1, 1 } do
		box(
			mf,
			"CourtLine",
			V(-26.4, -5.96, sz * 24.4 - 0.15),
			V(26.4, -5.9, sz * 24.4 + 0.15),
			white,
			false,
			I
		)
		box(
			mf,
			"CourtLine",
			V(sz * 26.4 - 0.15, -5.96, -24.2),
			V(sz * 26.4 + 0.15, -5.91, 24.2),
			white,
			false,
			I
		)
	end
	box(mf, "CourtLine", V(-26.2, -5.96, -0.15), V(26.2, -5.915, 0.15), white, false, I)
	for _, hf in halves do
		-- a hoop on the west wing wall (this half's side, z 12), braced to the wall, out of reach and non-colliding
		local T = hf.T
		local z0 = 12
		box(
			mf,
			"HoopBracket",
			V(-29.98, -0.9, z0 - 1.1),
			V(-28.75, -0.6, z0 - 0.8),
			L.steel,
			false,
			T
		)
		box(
			mf,
			"HoopBracket",
			V(-29.98, -0.9, z0 + 0.8),
			V(-28.75, -0.6, z0 + 1.1),
			L.steel,
			false,
			T
		)
		box(
			mf,
			"HoopBracket",
			V(-29.98, 0.95, z0 - 0.15),
			V(-28.75, 1.25, z0 + 0.15),
			L.steel,
			false,
			T
		)
		box(
			mf,
			"Backboard",
			V(-28.8, -1.4, z0 - 2.0),
			V(-28.55, 1.6, z0 + 2.0),
			look(hex("E8E6E0")),
			false,
			T
		)
		box(
			mf,
			"BackboardMark",
			V(-28.6, -1.0, z0 - 0.8),
			V(-28.48, 0.1, z0 + 0.8),
			look(hf.side.bill),
			false,
			T
		)
		box(
			mf,
			"RimArm",
			V(-28.6, -0.78, z0 - 0.12),
			V(-28.0, -0.62, z0 + 0.12),
			look(hex("D9622B"), nil, Enum.Material.Metal),
			false,
			T
		)
		local c = V(-27.25, -0.7, z0)
		local r = 0.78
		for k = 0, 7 do
			local a0, a1 = k * math.pi / 4 + math.pi / 8, (k + 1) * math.pi / 4 + math.pi / 8
			local p0 = c + V(math.cos(a0) * r, 0, math.sin(a0) * r)
			local p1 = c + V(math.cos(a1) * r, 0, math.sin(a1) * r)
			local mid = (p0 + p1) / 2 + V(0, (k % 2) * 0.02, 0) -- neighbours off each other's planes
			part(
				mf,
				"Rim",
				V(0.12, 0.12, (p1 - p0).Magnitude + 0.1),
				T * CFrame.lookAt(mid, p1 + V(0, (k % 2) * 0.02, 0)),
				look(hex("D9622B"), nil, Enum.Material.Metal)
			)
			local q = p0 * 0.75 + c * 0.25 - V(0, 0.9, 0)
			local mid2 = (p0 + q) / 2
			part(mf, "Net", V(0.05, 0.05, (q - p0).Magnitude), T * CFrame.lookAt(mid2, q), white)
		end
	end
	for _, dp in { { -20, 3 }, { 20, -3 }, { -6, 22 }, { 6, -22 } } do
		box(
			mf,
			"Drain",
			V(dp[1] - 0.7, -6.03, dp[2] - 0.7),
			V(dp[1] + 0.7, -5.905, dp[2] + 0.7),
			L.steel,
			false,
			I
		)
	end
	for _, pd in
		{ { -22.5, 9, 5, 3 }, { 22.5, -9, 5, 3 }, { 12, 20, 3.5, 2.2 }, { -12, -20, 3.5, 2.2 } }
	do
		local puddle = box(
			mf,
			"Puddle",
			V(pd[1] - pd[3] / 2, -6.02, pd[2] - pd[4] / 2),
			V(pd[1] + pd[3] / 2, -5.908, pd[2] + pd[4] / 2),
			look(hex("2A3340")),
			false,
			I
		)
		puddle.Reflectance = 0.35
	end
	for _, z in { -14, 0, 14 } do
		box(
			mf,
			"CourtJoint",
			V(-29.85, -6.02, z - 0.1),
			V(29.85, -5.96, z + 0.1),
			L.stoneDark,
			false,
			I
		)
	end
	for _, x in { -14, 14 } do
		box(
			mf,
			"CourtJoint",
			V(x - 0.1, -6.03, -27.85),
			V(x + 0.1, -5.97, 27.85),
			L.stoneDark,
			false,
			I
		)
	end
	-- windows on the middle building's outer facades (x = +-70)
	for _, y in { -12.55, -18.55, -24.55 } do
		windowRow(mf, V(70, 0, -38), V(0, 0, 1), V(1, 0, 0), 5, 71, 8, y, false, {}, I, 0.35)
		windowRow(mf, V(-70, 0, -38), V(0, 0, 1), V(-1, 0, 0), 5, 71, 8, y, false, {}, I, 0.35)
	end

	-- the pump house (20 x 20, court floor to +5) and the water tank on it
	hut(mf, "PumpHouse", -10, 10, -10, 10, -6, 11, L.midBrick, I)
	ring(mf, "PumpBand", -10, 10, -10, 10, -0.6, 0.0, 0.18, L.stone, I)
	ring(mf, "PumpPlinth", -10, 10, -10, 10, -6.05, -5.0, 0.2, L.stoneDark, I)
	for _, d in { V(0, 0, 1), V(0, 0, -1), V(1, 0, 0), V(-1, 0, 0) } do
		local p = d * 10 + V(0, -6.0, 0)
		onWall("R4Door", mp, p + (if d.X ~= 0 then V(0, 0, 4) else V(4, 0, 0)), d, I)
	end
	kit("R4Tank", mp, CFrame.new(0, 4.94, 0) * CFrame.Angles(0, math.rad(15), 0), 1.6)
	blocker("PumpRoofGuard", V(-10.4, 5.0, -10.4), V(10.4, 18, 10.4), I)
	col("TankCol", V(-8.4, 5.0, -8.4), V(8.4, 50, 8.4), I)
	-- the tank's neon: both sides' icons on the pump house cap, facing each team's roof
	for _, hf in halves do
		kit(
			hf.side.hutIcon,
			mp,
			hf.T * CFrame.lookAt(V(-6.5, -4.9, 9.98), V(-6.5, -4.9, 11)),
			0.55,
			hf.side
		)
	end
	task.wait()

	--------------------------------------------------------------------------------------------- the city round the block
	local wf = folder(secWorld, "City")
	box(wf, "Street", V(-420, STREET - 1.5, -420), V(420, STREET, 420), L.asphalt, true, I)
	-- sidewalks round the block
	for _, r in
		{
			{ -78, 78, 104, 112 },
			{ -78, 78, -112, -104 },
			{ 78, 86, -104, 104 },
			{ -86, -78, -104, 104 },
		}
	do
		box(
			wf,
			"Sidewalk",
			V(r[1], STREET - 0.04, r[3]),
			V(r[2], STREET + 0.4, r[4]),
			L.walk,
			true,
			I
		)
	end
	box(wf, "Sidewalk", V(-78, STREET - 0.04, -104), V(78, STREET + 0.4, -96.3), L.walk, true, I)
	box(wf, "Sidewalk", V(-78, STREET - 0.04, 96.3), V(78, STREET + 0.4, 104), L.walk, true, I)
	box(wf, "Sidewalk", V(70.3, STREET - 0.04, -96.3), V(78, STREET + 0.4, 96.3), L.walk, true, I)
	box(wf, "Sidewalk", V(-78, STREET - 0.04, -96.3), V(-70.3, STREET + 0.4, 96.3), L.walk, true, I)
	-- neighbour buildings across the streets: varied heights, lit windows facing the block, roof dressing
	local NB = {
		-- x0, x1, z0, z1, top, colour, roof kit
		{ -150, -96, 40, 102, 14, "8C4F3C", "tank" },
		{ -150, -96, -34, 34, -10, "B59873", "bill" },
		{ -150, -96, -104, -40, 24, "5E6470", "ac" },
		{ 96, 140, 50, 112, -6, "A8784F", "ac" },
		{ 96, 156, -24, 44, 30, "6B4A3E", "tank" },
		{ 96, 150, -110, -30, 6, "C4B49A", "bill" },
		{ -92, -12, 120, 170, 18, "6E5A4C", "ac" },
		{ -6, 60, 120, 176, 0, "9B6B4A", "tank" },
		{ 66, 140, 120, 168, 36, "4F5866", "ac" },
		{ -140, -66, -170, -120, 32, "57616D", "tank" },
		{ -60, 6, -176, -120, -2, "A48563", "bill" },
		{ 12, 92, -170, -120, 16, "7E4A3A", "ac" },
	}
	for i, nb in NB do
		local x0, x1, z0, z1, top =
			nb[1] :: number, nb[2] :: number, nb[3] :: number, nb[4] :: number, nb[5] :: number
		local lk = brick(hex(nb[6] :: string))
		box(wf, "Neighbour", V(x0, STREET - 0.05, z0), V(x1, top - 0.3, z1), lk, true, I)
		box(
			wf,
			"NeighbourRoof",
			V(x0 + 0.08, top - 0.6, z0 + 0.08),
			V(x1 - 0.08, top + 0.04, z1 - 0.08),
			L.tar,
			true,
			I
		)
		ring(wf, "NeighbourCornice", x0, x1, z0, z1, top - 1.2, top + 0.9, 0.35, L.stone, I)
		-- lit windows on the face toward the block
		local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
		local faceX = math.abs(cx) > math.abs(cz) * 0.9
		local y = top - 6
		while y > STREET + 6 and y > top - 26 do
			if faceX then
				local xf = if cx > 0 then x0 else x1
				local n = V(if cx > 0 then -1 else 1, 0, 0)
				windowRow(wf, V(xf, 0, z0), V(0, 0, 1), n, 5, z1 - z0 - 5, 7, y, false, {}, I, 0.45)
			else
				local zf = if cz > 0 then z0 else z1
				local n = V(0, 0, if cz > 0 then -1 else 1)
				windowRow(wf, V(x0, 0, zf), V(1, 0, 0), n, 5, x1 - x0 - 5, 7, y, false, {}, I, 0.45)
			end
			y -= 6
		end
		local rx, rz = cx, cz
		if nb[7] == "tank" then
			kit(
				"R4Tank",
				wf,
				CFrame.new(rx + (if i % 2 == 0 then 8 else -8), top, rz) * CFrame.Angles(0, i, 0),
				0.7
			)
		elseif nb[7] == "ac" then
			kit("R4AC", wf, CFrame.new(rx, top, rz) * CFrame.Angles(0, (i % 2) * math.pi / 2, 0))
			kit(
				"R4AC",
				wf,
				CFrame.new(rx + 9, top, rz + 6) * CFrame.Angles(0, (i % 2) * math.pi / 2, 0)
			)
		else
			-- a billboard on the roof facing the block, in a side's colours
			local toward = V(-cx, 0, -cz).Unit
			local sdN = if cz > 0 or cx > 0 then SIDE.A else SIDE.B
			local pos = V(rx, top, rz)
			local b = kit("R4Billboard", wf, CFrame.lookAt(pos, pos + toward), 1.2, sdN)
			local ic =
				kit(if sdN == SIDE.A then "R4NeonCup" else "R4NeonStar", wf, CFrame.new(), 1.2, sdN)
			ic:PivotTo(b:GetPivot() * CFrame.new(5.4, 4.6, -0.3))
		end
	end
	-- city towers further out, recoloured, lit
	local TOWERS = {
		{ "R4TowerA", -260, -40, 1.0, "4C5566" },
		{ "R4TowerB", -300, 140, 1.2, "5A4E58" },
		{ "R4TowerC", -230, 260, 1.3, "605A52" },
		{ "R4TowerA", -60, 330, 1.3, "47505E" },
		{ "R4TowerB", 120, 300, 1.0, "584B44" },
		{ "R4TowerA", 300, 190, 1.15, "4A5361" },
		{ "R4TowerC", 270, 30, 1.2, "5D5650" },
		{ "R4TowerB", 320, -150, 1.4, "4E5866" },
		{ "R4TowerA", 150, -320, 1.25, "564A47" },
		{ "R4TowerC", -40, -300, 1.4, "4B5462" },
		{ "R4TowerB", -220, -260, 1.1, "5C534E" },
		{ "R4TowerA", -380, -160, 1.5, "48505C" },
		{ "R4TowerA", 420, 360, 1.7, "4A4F5A" },
		{ "R4TowerB", -420, 380, 1.6, "534A52" },
	}
	for _, t in TOWERS do
		local m = kit(
			t[1] :: string,
			wf,
			CFrame.new(t[2] :: number, STREET, t[3] :: number)
				* CFrame.Angles(0, (t[2] :: number) * 0.01, 0),
			t[4] :: number
		)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.CastShadow = false
				if string.find(d.Name, "TowerBody") then
					d.Color = hex(t[5] :: string)
				end
			end
		end
	end
	-- street lamps along the alleys' street ends (glow down there in the dark)
	for _, z in { -43, 43 } do
		for _, x in { -76, 76 } do
			box(
				wf,
				"LampPost",
				V(x - 0.2, STREET, z - 0.2),
				V(x + 0.2, STREET + 9, z + 0.2),
				L.steel,
				false,
				I
			)
			local lp = box(
				wf,
				"LampHead",
				V(x - 0.6, STREET + 9, z - 0.6),
				V(x + 0.6, STREET + 9.5, z + 0.6),
				L.glow,
				false,
				I
			)
			light(lp, "PointLight", 24, 1.6, hex("FFCF8A"))
		end
	end
	task.wait()

	--------------------------------------------------------------------------------------------- practical lights on the map
	for _, d in secProps:GetDescendants() do
		if d:IsA("Model") and d.Name == "R4Door" then
			addLamp(d, 18, 1.3) -- a warm pool on the roof round every door
		elseif d:IsA("BasePart") and string.find(d.Name, "RoomGlow") then
			light(d, "SurfaceLight", 10, 0.8, hex("F0B070"), Enum.NormalId.Top)
		end
	end

	--------------------------------------------------------------------------------------------- spawns, bounds, stage
	local SPAWNS = { { -12, 89 }, { 0, 91 }, { 12, 89 }, { -6, 85 }, { 6, 85 } }
	for _, hf in halves do
		for i, s in SPAWNS do
			local sp = Instance.new("SpawnLocation")
			sp.Name = "Spawn_" .. hf.letter .. i
			sp.Size = V(4, 0.2, 4)
			sp.CFrame = ORIGIN * hf.T * CFrame.new(s[1], 0.15, s[2])
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
	bound(V(70.2, -24, -97), V(72.2, 50, 97))
	bound(V(-72.2, -24, -97), V(-70.2, 50, 97))
	bound(V(-72.2, -24, 96.2), V(72.2, 50, 98.2))
	bound(V(-72.2, -24, -98.2), V(72.2, 50, -96.2))
	bound(V(-72.2, 50, -98.2), V(72.2, 52, 98.2))
	local stage = part(map, "WinnerStage", V(4, 0.2, 4), CFrame.new(0, 0.15, 33), L.paver)
	stage.Transparency = 1
	stage.CastShadow = false
	stage.CanCollide = false
	stage.CanQuery = false
	CollectionService:AddTag(stage, "WinnerStage")

	--------------------------------------------------------------------------------------------- lighting
	local lightCfg = Instance.new("Configuration")
	lightCfg.Name = "Lighting"
	CollectionService:AddTag(lightCfg, "GGAsset_MatchMaps_420")
	CollectionService:AddTag(lightCfg, "GauntletAuthoredData")
	lightCfg.Parent = map
	local fx = folder(map, "LightingFx")
	local atm = Instance.new("Atmosphere")
	atm.Density = 0.34
	atm.Offset = 0.08
	atm.Haze = 1.8
	atm.Glare = 0.2
	atm.Color = Color3.fromRGB(150, 140, 190)
	atm.Decay = Color3.fromRGB(96, 78, 128)
	atm.Parent = fx
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.4
	bloom.Size = 26
	bloom.Threshold = 1.8
	bloom.Parent = fx
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "Grade"
	cc.Contrast = 0.1
	cc.Saturation = 0.12
	cc.TintColor = Color3.fromRGB(252, 246, 255)
	cc.Parent = fx

	map.Parent = workspace
	return string.format("Rooftops4 built: %d parts", count)
end
