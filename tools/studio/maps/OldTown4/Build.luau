--!strict
-- OldTown4 "Collina" (large map, 2v2-3v3), the whole build (2026-11-21). Concept, layout and build log:
-- vault/01 Design/Maps/OldTown4.md. Layout rows mirror tools/maps/oldtown4_layout.py (HILL); the A half is turned
-- 180 degrees for team B. Match place only, edit mode. Returns a function; run it with require(<a clone>)().
--
-- A Tuscan hill town at golden hour: a raised piazza (+7) round a brick clock tower, climbed by a stepped street and
-- a cobbled ramp from each half. Each half has a fountain square with a market stall and a well, a loggia house with
-- an arcade and a +12 roof terrace (stair + stone steps), a long house, a kiosk, a wall shrine, house bridges over the
-- flank alleys, a town gate screening the spawn, and a spawn terrace that looks over the lower town to the hills.
-- Houses are Parts with RIVALS' map textures (MaterialService.ExtraTextures, pass of 2026-11-21): rusticated ground
-- storeys, string courses, cornices, quoins,
-- terracotta gable roofs, chimneys. Windows, doors, the arcade, balustrades, the belfry, the clock faces, the fountain,
-- the well, the stall, the cart, cafe sets, planters, lanterns, cypress and the hills are Blender kit pieces
-- (ServerStorage.MapKit.OldTown4, tools/blender/maps_oldtown4). No text signs.
-- Collision: building bodies, walls and stairs are their own collision; kit props get invisible boxes. Contract:
-- Spawns (ArenaSpawn_A/B), Barriers (empty), Bounds, KillDepth + Lighting (authored data 417 / 418), LightingFx,
-- WinnerStage. Joins never share a plane (the z-fight audit): touching pieces overlap or keep a hairline gap.

local CollectionService = game:GetService("CollectionService")
local MaterialService = game:GetService("MaterialService")
local ServerStorage = game:GetService("ServerStorage")

local ORIGIN = CFrame.new(6000, 200, 26000) -- the street floor under the clock tower
local ROT = CFrame.Angles(0, math.pi, 0)
local V = Vector3.new

local function hex(h: string): Color3
	return Color3.fromHex(h)
end
local C = {
	cream = hex("EADBB8"),
	ochre = hex("DDA862"),
	rose = hex("D99A82"),
	sienna = hex("C97E58"),
	yellow = hex("E7C982"),
	stone = hex("D8CBB0"),
	stoneDark = hex("B9A887"),
	ashlar = hex("CDBE9E"),
	brick = hex("A9573D"),
	terracotta = hex("B95A31"),
	terraDark = hex("8F432A"),
	cobble = hex("A99B87"),
	paving = hex("D2C5A9"),
	wood = hex("7A5233"),
	woodDark = hex("553722"),
	iron = hex("2E2B28"),
	leaf = hex("5A7A40"),
	leafDark = hex("46622F"),
	grass = hex("8A9E57"),
	valley = hex("9AA05C"),
	glow = hex("F0B868"),
	cloth = hex("E9DFC8"),
	dark = hex("2A2622"),
	niche = hex("3E5E86"),
	water = hex("5FA2B8"),
	rope = hex("CBB994"),
}
local SIDE = {
	A = { paint = hex("4F7A4E"), cloth = hex("B8463A") }, -- green shutters, red awnings
	B = { paint = hex("4A6F93"), cloth = hex("3C6A9C") }, -- blue shutters, blue awnings
}
type Side = { paint: Color3, cloth: Color3 }
-- RIVALS' map MaterialVariants (MaterialService.ExtraTextures, found by name; texture pass 2026-11-21, see the map note)
local RIVALS = {
	render = "Concrete-02a", -- stucco walls
	stone = "Concrete-01a", -- dressed stone: trims, cornices, quoins, steps, the kit's stone
	ashlar = "StoneBlock_01a", -- rusticated ground storeys, retaining walls
	brick = "Brick 2022",
	cobble = "Paver_01a", -- the streets
	paving = "Paver_01b", -- squares, piazza, terraces
	plank = "WoodPlank01a",
	timber = "Wood01a",
	metal = "Metal 2022",
	grass = "Grass_01b",
	fabric = "Fabric2022",
}
-- everything else (kit meshes, inline looks) by material, applied once the map is built
local REMAP: { [string]: { any } } = {
	["Limestone|"] = { Enum.Material.Concrete, RIVALS.stone },
	["Brick|"] = { Enum.Material.Brick, RIVALS.brick },
	["WoodPlanks|"] = { Enum.Material.WoodPlanks, RIVALS.plank },
	["Wood|"] = { Enum.Material.Wood, RIVALS.timber },
	["Metal|"] = { Enum.Material.Metal, RIVALS.metal },
	["Grass|"] = { Enum.Material.Grass, RIVALS.grass },
	["Fabric|"] = { Enum.Material.Fabric, RIVALS.fabric },
}

type Look = { color: Color3, mat: Enum.Material?, variant: string? }
local function look(color: Color3, variant: string?, mat: Enum.Material?): Look
	return { color = color, variant = variant, mat = mat }
end
local function stucco(c: Color3): Look
	return look(c, RIVALS.render, Enum.Material.Concrete)
end
local L = {
	cream = stucco(C.cream),
	ochre = stucco(C.ochre),
	rose = stucco(C.rose),
	sienna = stucco(C.sienna),
	yellow = stucco(C.yellow),
	ashlar = look(C.ashlar, RIVALS.ashlar, Enum.Material.Brick),
	stone = look(C.stone, RIVALS.stone, Enum.Material.Concrete),
	stoneDark = look(C.stoneDark, RIVALS.stone, Enum.Material.Concrete),
	brick = look(C.brick, RIVALS.brick, Enum.Material.Brick),
	-- roofs keep Roblox's own clay tiles: RIVALS has no tile variant, and Slate02c read as swirls up close
	roof = look(C.terracotta, nil, Enum.Material.ClayRoofTiles),
	roofDark = look(C.terraDark, nil, Enum.Material.ClayRoofTiles),
	cobble = look(C.cobble, RIVALS.cobble, Enum.Material.Pavement),
	paving = look(C.paving, RIVALS.paving, Enum.Material.Pavement),
	wood = look(C.wood, RIVALS.plank, Enum.Material.WoodPlanks),
	woodDark = look(C.woodDark, RIVALS.plank, Enum.Material.WoodPlanks),
	iron = look(C.iron, RIVALS.metal, Enum.Material.Metal),
	leaf = look(C.leaf, nil, Enum.Material.LeafyGrass),
	leafDark = look(C.leafDark, nil, Enum.Material.LeafyGrass),
	grass = look(C.grass, RIVALS.grass, Enum.Material.Grass),
	valley = look(C.valley, RIVALS.grass, Enum.Material.Grass),
	glow = look(C.glow, nil, Enum.Material.Neon),
	dark = look(C.dark),
	niche = look(C.niche),
	water = look(C.water, nil, Enum.Material.Glass),
	rope = look(C.rope, RIVALS.fabric, Enum.Material.Fabric),
	cloth = look(C.cloth, RIVALS.fabric, Enum.Material.Fabric),
}
local STUCCO = { L.cream, L.ochre, L.rose, L.sienna, L.yellow }

local function ensureVariants()
	local extra = MaterialService:FindFirstChild("ExtraTextures")
	assert(
		extra and extra:FindFirstChild(RIVALS.render, true),
		"OldTown4: RIVALS textures missing (MaterialService.ExtraTextures)"
	)
end

type Rect = { x0: number, x1: number, z0: number, z1: number }
local function R(a: number, b: number, c: number, d: number): Rect
	return { x0 = math.min(a, b), x1 = math.max(a, b), z0 = math.min(c, d), z1 = math.max(c, d) }
end
-- a face of a rectangle: N (+Z), S (-Z), E (+X), W (-X); u runs along the face, d out from it
local function faceNormal(F: string): Vector3
	if F == "N" then
		return V(0, 0, 1)
	elseif F == "S" then
		return V(0, 0, -1)
	elseif F == "E" then
		return V(1, 0, 0)
	end
	return V(-1, 0, 0)
end
local function facePoint(F: string, b: Rect, u: number, y: number, d: number): Vector3
	if F == "N" then
		return V(u, y, b.z1 + d)
	elseif F == "S" then
		return V(u, y, b.z0 - d)
	elseif F == "E" then
		return V(b.x1 + d, y, u)
	end
	return V(b.x0 - d, y, u)
end
local function faceRange(F: string, b: Rect): (number, number)
	if F == "N" or F == "S" then
		return b.x0, b.x1
	end
	return b.z0, b.z1
end

return function(): string
	assert(game.PlaceId == 133387545285290, "OldTown4: not the match place")
	ensureVariants()
	local old = workspace:FindFirstChild("OldTown4")
	if old then
		old:Destroy()
	end
	local map = Instance.new("Model")
	map.Name = "OldTown4"
	map.WorldPivot = ORIGIN
	CollectionService:AddTag(map, "GGAsset_MatchMaps_417")
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
	local function wedge(
		parent: Instance,
		name: string,
		size: Vector3,
		cf: CFrame,
		lk: Look,
		solid: boolean?
	): BasePart
		return part(parent, name, size, cf, lk, solid, "WedgePart")
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
	local function beam(
		parent: Instance,
		name: string,
		a: Vector3,
		b: Vector3,
		w: number,
		h: number,
		lk: Look,
		T: CFrame?,
		solid: boolean?
	): BasePart
		local mid = (a + b) / 2
		return part(
			parent,
			name,
			V(w, h, (b - a).Magnitude),
			(T or CFrame.identity) * CFrame.lookAt(mid, b),
			lk,
			solid
		)
	end
	-- invisible collision box (blocks players and shots)
	local function col(name: string, a: Vector3, b: Vector3, T: CFrame, cfExtra: CFrame?): BasePart
		local lo, hi = a:Min(b), a:Max(b)
		local p = part(
			secCollision,
			name,
			hi - lo,
			T * CFrame.new((lo + hi) / 2) * (cfExtra or CFrame.identity),
			{ color = C.stone },
			true
		)
		p.Transparency = 1
		p.CastShadow = false
		return p
	end
	-- invisible player blocker (shots pass): keeps players off roofs and perches nobody should stand on
	local function blocker(name: string, a: Vector3, b: Vector3, T: CFrame): BasePart
		local p = col(name, a, b, T)
		p.CanQuery = false
		return p
	end
	local function kit(
		piece: string,
		parent: Instance,
		cf: CFrame,
		scale: number?,
		side: Side?,
		lib: string?
	): Model
		local libF = ServerStorage.MapKit:FindFirstChild(lib or "OldTown4")
		local src = libF and libF:FindFirstChild(piece)
		assert(
			src and src:IsA("Model"),
			"missing kit piece " .. (lib or "OldTown4") .. "." .. piece
		)
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
					if string.find(d.Name, "Paint") then
						d.Color = side.paint
					elseif string.find(d.Name, "ClothStripe") then
						d.Color = side.cloth
					end
				end
				count += 1
			end
		end
		m.Parent = parent
		return m
	end
	-- a kit piece on a wall: its back (local z = 0) just inside the wall plane, front out along n
	local function onWall(
		piece: string,
		parent: Instance,
		p: Vector3,
		n: Vector3,
		T: CFrame,
		scale: number?,
		side: Side?
	)
		local q = p - n * 0.02
		return kit(piece, parent, T * CFrame.lookAt(q, q + n), scale, side)
	end
	local function facePanel(
		parent: Instance,
		name: string,
		F: string,
		b: Rect,
		u0: number,
		u1: number,
		y0: number,
		y1: number,
		d0: number,
		d1: number,
		lk: Look,
		T: CFrame,
		solid: boolean?
	): BasePart
		return box(
			parent,
			name,
			facePoint(F, b, u0, y0, d0),
			facePoint(F, b, u1, y1, d1),
			lk,
			solid,
			T
		)
	end
	-- a band round a rectangle: N/S pieces run the full length, E/W pieces sit 0.03 / 0.02 inside them, so no two
	-- faces share a plane at the corners
	local function ring(
		parent: Instance,
		name: string,
		b: Rect,
		y0: number,
		y1: number,
		out: number,
		lk: Look,
		T: CFrame,
		inner: number?
	)
		local ins = inner or 0.1
		box(
			parent,
			name,
			V(b.x0 - out, y0, b.z0 - out),
			V(b.x1 + out, y1, b.z0 + ins),
			lk,
			false,
			T
		)
		box(
			parent,
			name,
			V(b.x0 - out, y0, b.z1 - ins),
			V(b.x1 + out, y1, b.z1 + out),
			lk,
			false,
			T
		)
		local o2 = out - 0.05
		box(
			parent,
			name,
			V(b.x0 - o2, y0 + 0.04, b.z0 - o2),
			V(b.x0 + ins, y1 - 0.04, b.z1 + o2),
			lk,
			false,
			T
		)
		box(
			parent,
			name,
			V(b.x1 - ins, y0 + 0.04, b.z0 - o2),
			V(b.x1 + o2, y1 - 0.04, b.z1 + o2),
			lk,
			false,
			T
		)
	end
	-- corner quoins (long and short stones alternating) from y0 to y1 on the listed corners
	local function quoins(
		parent: Instance,
		b: Rect,
		y0: number,
		y1: number,
		which: { string },
		T: CFrame
	)
		local corners = {
			SW = { b.x0, b.z0, -1, -1 },
			SE = { b.x1, b.z0, 1, -1 },
			NE = { b.x1, b.z1, 1, 1 },
			NW = { b.x0, b.z1, -1, 1 },
		}
		for _, k in which do
			local c = corners[k]
			local i = 0
			local y = y0
			while y + 1.0 <= y1 do
				local lx = if i % 2 == 0 then 1.25 else 0.75
				local lz = if i % 2 == 0 then 0.75 else 1.25
				box(
					parent,
					"Quoin",
					V(c[1] + c[3] * 0.12, y, c[2] + c[4] * 0.12),
					V(c[1] - c[3] * lx, y + 1.0, c[2] - c[4] * lz),
					L.stone,
					false,
					T
				)
				y += 1.15
				i += 1
			end
		end
	end
	-- a terracotta gable roof on a rectangle; the ridge runs along X, or along Z when alongZ
	local function gable(
		parent: Instance,
		b: Rect,
		eave: number,
		rise: number,
		over: number,
		alongZ: boolean,
		wallLk: Look,
		T: CFrame,
		solid: boolean?
	)
		local F = T * CFrame.new((b.x0 + b.x1) / 2, 0, (b.z0 + b.z1) / 2)
		local len, span = b.x1 - b.x0, b.z1 - b.z0
		if alongZ then
			F = F * CFrame.Angles(0, math.pi / 2, 0)
			len, span = span, len
		end
		local half = span / 2
		local th = math.atan2(rise, half)
		local t = 0.55
		local run = half + over
		local slen = run / math.cos(th)
		local ridge = eave + rise
		for _, s in { -1, 1 } do
			local d = run / 2
			local cf = F
				* CFrame.new(0, ridge - d * math.tan(th), s * d)
				* CFrame.Angles(s * th, 0, 0)
			part(
				parent,
				"Roof",
				V(len + 2 * over - (if s > 0 then 0.08 else 0), t, slen),
				cf * CFrame.new(0, -t / 2, 0),
				L.roof,
				solid ~= false
			)
		end
		part(
			parent,
			"Ridge",
			V(len + 2 * over + 0.12, 0.72, 0.72),
			F * CFrame.new(0, ridge + 0.04, 0) * CFrame.Angles(math.pi / 4, 0, 0),
			L.roofDark
		)
		for _, gx in { -len / 2 + 0.3, len / 2 - 0.3 } do
			for _, s in { -1, 1 } do
				local c = V(gx, eave + rise / 2 - 0.25, s * half / 2)
				wedge(
					parent,
					"Gable",
					V(0.5, rise, half),
					F * CFrame.lookAt(c, c + V(0, 0, s)),
					wallLk,
					solid ~= false
				)
			end
		end
	end

	-- a shop front on a wall face: a dark window with a stone frame and wood mullions, a striped awning
	local function shopfront(
		f: Instance,
		F: string,
		b: Rect,
		u: number,
		y0: number,
		gd: number,
		T: CFrame,
		side: Side
	)
		facePanel(
			f,
			"Shop window",
			F,
			b,
			u - 2.35,
			u + 2.35,
			y0 + 0.85,
			y0 + 4.35,
			gd - 0.1,
			gd + 0.06,
			L.dark,
			T
		)
		facePanel(
			f,
			"Shop frame",
			F,
			b,
			u - 2.75,
			u - 2.3,
			y0 - 0.2,
			y0 + 4.4,
			gd - 0.1,
			gd + 0.25,
			L.stone,
			T
		)
		facePanel(
			f,
			"Shop frame",
			F,
			b,
			u + 2.3,
			u + 2.75,
			y0 - 0.2,
			y0 + 4.4,
			gd - 0.1,
			gd + 0.25,
			L.stone,
			T
		)
		facePanel(
			f,
			"Shop lintel",
			F,
			b,
			u - 2.95,
			u + 2.95,
			y0 + 4.35,
			y0 + 4.85,
			gd - 0.1,
			gd + 0.32,
			L.stone,
			T
		)
		facePanel(
			f,
			"Shop sill",
			F,
			b,
			u - 2.32,
			u + 2.32,
			y0 - 0.2,
			y0 + 0.88,
			gd - 0.1,
			gd + 0.18,
			L.wood,
			T
		)
		for _, m in { -0.8, 0.8 } do
			facePanel(
				f,
				"Mullion",
				F,
				b,
				u + m - 0.07,
				u + m + 0.07,
				y0 + 0.86,
				y0 + 4.34,
				gd - 0.1,
				gd + 0.12,
				L.woodDark,
				T
			)
		end
		-- awning: five stripes sloping out from the wall, a valance on the front edge
		local nv = faceNormal(F)
		local p = facePoint(F, b, u, y0 + 4.65, gd + 0.95)
		local FF = T * CFrame.lookAt(p, p + nv)
		local phi = math.atan2(0.9, 1.9)
		for k = 0, 4 do
			local dx = -2.16 + k * 1.08
			local stripe = part(
				f,
				"Awning",
				V(1.06, 0.12, 2.1),
				FF * CFrame.new(dx, 0, 0) * CFrame.Angles(-phi, 0, 0),
				{ color = if k % 2 == 0 then side.cloth else C.cloth, mat = Enum.Material.Fabric }
			)
			stripe.CastShadow = true
		end
		part(
			f,
			"Valance",
			V(5.45, 0.55, 0.06),
			FF * CFrame.new(0, -0.72, -0.99),
			{ color = side.cloth, mat = Enum.Material.Fabric }
		)
	end
	-- a small attic window: stone frame strips round a dark pane
	local function atticWindow(f: Instance, F: string, b: Rect, u: number, y: number, T: CFrame)
		facePanel(f, "Attic pane", F, b, u - 0.8, u + 0.8, y, y + 1.1, -0.1, 0.05, L.dark, T)
		facePanel(
			f,
			"Attic frame",
			F,
			b,
			u - 1.1,
			u - 0.75,
			y - 0.25,
			y + 1.35,
			-0.1,
			0.2,
			L.stone,
			T
		)
		facePanel(
			f,
			"Attic frame",
			F,
			b,
			u + 0.75,
			u + 1.1,
			y - 0.25,
			y + 1.35,
			-0.1,
			0.2,
			L.stone,
			T
		)
		facePanel(
			f,
			"Attic frame",
			F,
			b,
			u - 0.78,
			u + 0.78,
			y - 0.25,
			y + 0.02,
			-0.1,
			0.24,
			L.stone,
			T
		)
		facePanel(
			f,
			"Attic frame",
			F,
			b,
			u - 0.78,
			u + 0.78,
			y + 1.08,
			y + 1.35,
			-0.1,
			0.24,
			L.stone,
			T
		)
	end
	-- a balustrade run between a and b along X (axis "X", line at z = c) or along Z (line at x = c): kit balustrades
	-- between kit posts, stone pedestals at both ends sized to fill
	local function balRun(
		f: Instance,
		axis: string,
		c: number,
		a: number,
		b: number,
		y: number,
		T: CFrame,
		lift: number?,
		guard: boolean?
	)
		local len = b - a
		local n = math.max(1, math.floor((len - 1.2) / 6.1))
		local w = (len - 6.1 * n + 1.2) / 2
		local dy = lift or 0
		local function at(u: number, yy: number): Vector3
			return if axis == "X" then V(u, yy, c) else V(c, yy, u)
		end
		local yaw = if axis == "X" then CFrame.identity else CFrame.Angles(0, math.pi / 2, 0)
		for _, e in { { a, a + w }, { b - w, b } } do
			local p0, p1 = at(e[1], y - 0.4), at(e[2], y + 3.3 + dy)
			local lo, hi = p0:Min(p1), p0:Max(p1)
			local side = if axis == "X" then V(0, 0, 0.65) else V(0.65, 0, 0)
			box(f, "Pedestal", lo - side, hi + side, L.stone, true, T)
			local capSide = if axis == "X" then V(0.1, 0, 0.8) else V(0.8, 0, 0.1)
			box(
				f,
				"Pedestal cap",
				V(lo.X, y + 3.25 + dy, lo.Z) - capSide,
				V(hi.X, y + 3.6 + dy, hi.Z) + capSide,
				L.stoneDark,
				false,
				T
			)
		end
		local u = a + w - 0.05
		for i = 1, n do
			local mid = u + 2.5
			kit("Balustrade5", f, T * CFrame.new(at(mid, y - 0.03)) * yaw)
			if i < n then
				kit("BalPost", f, T * CFrame.new(at(u + 5.55, y - 0.03)) * yaw)
			end
			u += 6.1
		end
		local p0, p1 = at(a + w, y), at(b - w, y + 3.5)
		local lo, hi = p0:Min(p1), p0:Max(p1)
		local side = if axis == "X" then V(0, 0, 0.6) else V(0.6, 0, 0)
		col("Balustrade", lo - side, hi + side, T)
		if guard then
			-- too high to jump onto from the deck or the landing walls (15 + 7.2), so the rail is no perch
			local g0, g1 = at(a, y + 3.2 + (lift or 0)), at(b, y + 10.5)
			local gs = if axis == "X" then V(0, 0, 0.7) else V(0.7, 0, 0)
			blocker("Rail guard", g0:Min(g1) - gs, g0:Max(g1) + gs, T)
		end
	end

	type FaceSpec = {
		ground: { string }?,
		us: { number }?,
		bays: number?,
		upper: boolean?,
		attic: number?,
		balcony: number?,
		lanterns: boolean?,
	}
	type HouseSpec = {
		name: string,
		b: Rect,
		h: number,
		y0: number?,
		lk: Look,
		faces: { [string]: FaceSpec },
		roof: string?,
		rise: number?,
		rustic: boolean?,
		string: number?,
		corniceOut: number?,
		chimneys: { { number } }?,
		floors: { number }?,
		quoins: boolean?,
		simple: boolean?,
		jit: number?,
		parent: Instance?,
	}
	local secHouses = folder(secStructure, "Houses")
	-- a town house: a solid stucco body, a rusticated ground storey or a base course, a string course, a two-step
	-- cornice, quoins on dressed corners, windows / doors / shops on the dressed faces, a gable roof, chimneys
	local function house(H: HouseSpec, T: CFrame, side: Side): Folder
		local f = folder(H.parent or secHouses, H.name)
		local b = H.b
		local y0 = H.y0 or 0
		local top = y0 + H.h
		local jit = H.jit or 0
		box(
			f,
			"Body",
			V(b.x0, y0 - (if y0 == 0 then 0.6 + jit else 0.02), b.z0),
			V(b.x1, top, b.z1),
			H.lk,
			true,
			T
		)
		local sy = H.string or (y0 + 5.2 + jit)
		if H.simple then
			ring(f, "Cornice", b, top - 0.55, top + 0.03, 0.35, L.stone, T)
		else
			if H.rustic then
				box(
					f,
					"Rustication",
					V(b.x0 - 0.2, y0 - 0.5 - jit, b.z0 - 0.2),
					V(b.x1 + 0.2, sy + 0.05, b.z1 + 0.2),
					L.ashlar,
					true,
					T
				)
			else
				ring(f, "Base course", b, y0 - 0.4 - jit, y0 + 0.7 + jit, 0.25, L.stoneDark, T)
			end
			if sy + 0.4 < top - 1.0 then
				ring(f, "String course", b, sy, sy + 0.4, 0.3, L.stone, T)
			end
			local co = H.corniceOut or 0.6
			ring(f, "Cornice", b, top - 0.9, top - 0.45, co * 0.5, L.stone, T)
			ring(f, "Cornice", b, top - 0.6, top + 0.03, co, L.stone, T, 0.2)
		end
		local gd = if H.rustic then 0.2 else 0
		local floors: { number } = {}
		if H.floors then
			floors = H.floors
		else
			local fy = sy + 1.2
			while fy + 3.51 <= top - 1.0 do
				table.insert(floors, fy)
				fy += 4.5
			end
		end
		local dressed: { [string]: boolean } = {}
		for F, spec in H.faces do
			dressed[F] = true
			local nv = faceNormal(F)
			local u0, u1 = faceRange(F, b)
			local len = u1 - u0
			local us: { number } = spec.us or {}
			if not spec.us then
				local n = spec.bays or math.max(1, math.floor((len - 4.5) / 6))
				for i = 1, n do
					table.insert(us, u0 + len * (i - 0.5) / n)
				end
			end
			for i, u in us do
				local g = if spec.ground
					then spec.ground[((i - 1) % #spec.ground) + 1]
					else (if i % 2 == 0 then "D" else "W")
				if g == "W" then
					onWall("WindowUnit", f, facePoint(F, b, u, y0 + 1.5, gd), nv, T, 0.9, side)
				elseif g == "D" then
					onWall("DoorUnit", f, facePoint(F, b, u, y0, gd), nv, T, 0.85)
					facePanel(
						f,
						"Doorstep",
						F,
						b,
						u - 1.9,
						u + 1.9,
						y0 - 0.3,
						y0 + 0.16,
						gd - 0.1,
						gd + 0.85,
						L.stone,
						T
					)
				elseif g == "S" then
					shopfront(f, F, b, u, y0, gd, T, side)
				end
				if spec.upper ~= false then
					for _, wy in floors do
						onWall("WindowUnit", f, facePoint(F, b, u, wy, 0), nv, T, 0.9, side)
					end
				end
				if spec.attic then
					atticWindow(f, F, b, u, spec.attic, T)
				end
				if spec.lanterns and i < #us then
					onWall(
						"WallLantern",
						f,
						facePoint(F, b, (u + us[i + 1]) / 2, y0 + 4.3, gd),
						nv,
						T
					)
				end
			end
			if spec.balcony and floors[1] then
				local u = us[spec.balcony]
				local by = floors[1] - 0.72
				facePanel(
					f,
					"Balcony",
					F,
					b,
					u - 3.85,
					u + 3.85,
					by - 0.35,
					by,
					-0.1,
					1.95,
					L.stone,
					T
				)
				for _, s in { -1, 1 } do
					facePanel(
						f,
						"Console",
						F,
						b,
						u + s * 3.3 - 0.3,
						u + s * 3.3 + 0.3,
						by - 1.25,
						by - 0.33,
						-0.1,
						1.2,
						L.stoneDark,
						T
					)
				end
				local FF = CFrame.lookAt(
					facePoint(F, b, u, by - 0.03, 1.4),
					facePoint(F, b, u, by - 0.03, 1.4) + nv
				)
				kit("Balustrade5", f, T * FF)
				for _, s in { -1, 1 } do
					kit("BalPost", f, T * FF * CFrame.new(s * 3.05, 0, 0))
				end
			end
		end
		if H.quoins ~= false and not H.simple then
			local which = {}
			if dressed.S or dressed.W then
				table.insert(which, "SW")
			end
			if dressed.S or dressed.E then
				table.insert(which, "SE")
			end
			if dressed.N or dressed.E then
				table.insert(which, "NE")
			end
			if dressed.N or dressed.W then
				table.insert(which, "NW")
			end
			quoins(f, b, sy + 0.55, top - 1.0, which, T)
		end
		local rise = 0
		if H.roof == "X" or H.roof == "Z" then
			local span = if H.roof == "X" then b.z1 - b.z0 else b.x1 - b.x0
			rise = H.rise or span / 2 * 0.42
			gable(f, b, top, rise, 0.8, H.roof == "Z", H.lk, T)
		end
		for _, c in H.chimneys or {} do
			local x, z = c[1], c[2]
			local ct = top + rise + 1.7
			box(
				f,
				"Chimney",
				V(x - 0.75, top - 1, z - 0.75),
				V(x + 0.75, ct, z + 0.75),
				H.lk,
				true,
				T
			)
			box(
				f,
				"Chimney cap",
				V(x - 1.0, ct - 0.05, z - 1.0),
				V(x + 1.0, ct + 0.3, z + 1.0),
				L.stone,
				false,
				T
			)
			box(
				f,
				"Chimney pot",
				V(x - 0.45, ct + 0.25, z - 0.45),
				V(x + 0.45, ct + 0.95, z + 0.45),
				L.roofDark,
				false,
				T
			)
		end
		return f
	end
	-- stone steps (visual blocks with hairline joints) over an invisible collision wedge, rising along Z
	local function steps(
		f: Instance,
		name: string,
		x0: number,
		x1: number,
		zLo: number,
		zHi: number,
		y0: number,
		y1: number,
		n: number,
		lk: Look,
		T: CFrame
	)
		local dir = if zHi < zLo then -1 else 1
		local run = math.abs(zHi - zLo) / n
		local rise = (y1 - y0) / n
		for k = 1, n do
			local za = zLo + dir * (k - 1) * run
			local zb = zLo + dir * k * run - dir * 0.04
			box(
				f,
				"Step",
				V(x0 - 0.05, y0 + k * rise - rise - 0.3, za),
				V(x1 + 0.05, y0 + k * rise, zb),
				lk,
				false,
				T
			)
		end
		local c = V((x0 + x1) / 2, (y0 + y1) / 2, (zLo + zHi) / 2)
		local w = wedge(
			secCollision,
			name,
			V(x1 - x0, y1 - y0, math.abs(zHi - zLo)),
			T * CFrame.lookAt(c, c - V(0, 0, dir)),
			lk,
			true
		)
		w.Transparency = 1
		w.CastShadow = false
	end
	-- a stair cheek wall: a base, a sloped wedge on it, a stone coping along the slope
	local function cheek(
		f: Instance,
		x0: number,
		x1: number,
		zLo: number,
		zHi: number,
		y0: number,
		y1: number,
		base: number,
		lk: Look,
		T: CFrame
	)
		local dir = if zHi < zLo then -1 else 1
		box(
			f,
			"Cheek",
			V(x0 - 0.03, y0 - 0.5, zLo + (if zHi < zLo then 0.05 else -0.05)),
			V(x1 + 0.03, y0 + base, zHi + (if zHi < zLo then -0.05 else 0.05)),
			lk,
			true,
			T
		)
		local c = V((x0 + x1) / 2, y0 + base - 0.12 + (y1 - y0) / 2, (zLo + zHi) / 2)
		wedge(
			f,
			"Cheek",
			V(x1 - x0, y1 - y0, math.abs(zHi - zLo)),
			T * CFrame.lookAt(c, c - V(0, 0, dir)),
			lk,
			true
		)
		beam(
			f,
			"Coping",
			V((x0 + x1) / 2, y0 + base + 0.01, zLo),
			V((x0 + x1) / 2, y1 + base + 0.01, zHi),
			x1 - x0 + 0.3,
			0.35,
			L.stone,
			T
		)
	end
	local function newel(
		f: Instance,
		x0: number,
		x1: number,
		zc: number,
		y0: number,
		y1: number,
		T: CFrame
	)
		box(f, "Newel", V(x0 - 0.2, y0, zc - 0.75), V(x1 + 0.2, y1, zc + 0.75), L.stone, true, T)
		box(
			f,
			"Newel cap",
			V(x0 - 0.35, y1 - 0.05, zc - 0.9),
			V(x1 + 0.35, y1 + 0.3, zc + 0.9),
			L.stoneDark,
			false,
			T
		)
	end
	-- a clipped hedge the RIVALS way: LeafyGrass boxes, two tiers turned a few degrees
	local function hedge(f: Instance, a: Vector3, b: Vector3, T: CFrame)
		local lo, hi = a:Min(b), a:Max(b)
		local c = (lo + hi) / 2
		local s = hi - lo
		part(f, "Hedge", s, T * CFrame.new(c), L.leaf, true)
		part(
			f,
			"Hedge",
			V(s.X - 0.3, 0.5, s.Z - 0.3),
			T * CFrame.new(c + V(0.05, s.Y / 2 + 0.12, -0.04)) * CFrame.Angles(0, math.rad(2.5), 0),
			L.leafDark
		)
	end
	-- a voussoir ring (an arch of angled stones) on a wall face, centred on (u, y)
	local function archRing(
		f: Instance,
		F: string,
		b: Rect,
		u: number,
		y: number,
		r: number,
		th: number,
		d0: number,
		d1: number,
		n: number,
		T: CFrame
	)
		local nv = faceNormal(F)
		local p = facePoint(F, b, u, y, (d0 + d1) / 2)
		local FF = T * CFrame.lookAt(p, p + nv)
		for i = 1, n do
			local a = math.pi * (i - 0.5) / n
			local rm = r + th / 2
			local chord = 2 * (r + th) * math.sin(math.pi / n / 2) * 0.95
			local key = i == (n + 1) / 2
			local sz = if key
				then V(chord * 1.15, th * 1.2, d1 - d0 + 0.08)
				else V(chord, th, d1 - d0 - (if i % 2 == 0 then 0.06 else 0))
			part(
				f,
				"Voussoir",
				sz,
				FF
					* CFrame.new(
						rm * math.cos(a),
						rm * math.sin(a),
						if i % 2 == 0 and not key then 0.03 else 0
					)
					* CFrame.Angles(0, 0, a - math.pi / 2),
				L.stone,
				true
			)
		end
	end
	-- a washing line between two walls: two rope spans with a sag, cloths pegged on it
	local function laundry(f: Instance, a: Vector3, b: Vector3, T: CFrame, colors: { Color3 })
		local mid = (a + b) / 2 - V(0, 1.1, 0)
		for _, s in { { a, mid }, { mid, b } } do
			local r = beam(f, "Line", s[1], s[2], 0.08, 0.08, L.rope, T)
			r.CastShadow = false
		end
		for i, c in colors do
			local t = i / (#colors + 1)
			local p = if t < 0.5 then a:Lerp(mid, t * 2) else mid:Lerp(b, t * 2 - 1)
			local dir = (b - a).Unit
			local w = if i % 2 == 0 then 1.4 else 1.9
			local h = if i % 3 == 0 then 1.4 else 2.1
			local side = dir:Cross(V(0, 1, 0)).Unit
			local q = p - V(0, h / 2 + 0.02, 0) + side * 0.1 -- pegged on the front of the line
			local cloth = part(
				f,
				"Washing",
				V(w, h, 0.06),
				T * CFrame.lookAt(q, q + side),
				{ color = c, mat = Enum.Material.Fabric }
			)
			cloth.CastShadow = true
		end
	end

	local halves = {
		{ T = CFrame.identity, side = SIDE.A, letter = "A" },
		{ T = ROT, side = SIDE.B, letter = "B" },
	}

	------------------------------------------------------------------------------------------------ ground and edges
	local ground = folder(secStructure, "Ground")
	box(ground, "Street", V(-124, -2, -111.5), V(124, 0, 111.5), L.cobble, true)
	local valley =
		box(secWorld, "Valley", V(-1020, -30, -1020), V(1020, -26.5, 1020), L.valley, false)
	valley.CastShadow = false
	for _, hf in halves do
		local T = hf.T
		-- the town ends in retaining walls dropping to the valley
		box(ground, "Retaining wall", V(-125, -27, 111.4), V(125, -0.05, 113), L.ashlar, false, T)
		box(
			ground,
			"Retaining wall",
			V(123.9, -27.03, 0.02),
			V(124.95, -0.08, 111.38),
			L.ashlar,
			false,
			T
		)
		box(
			ground,
			"Retaining wall",
			V(-124.95, -27.03, 0.02),
			V(-123.9, -0.08, 111.38),
			L.ashlar,
			false,
			T
		)
	end
	task.wait()

	------------------------------------------------------------------------------------------------ the hill piazza
	local hill = folder(secStructure, "Hill piazza")
	box(hill, "Piazza core", V(-30, -0.6, -22), V(30, 6.75, 22), L.ashlar, true)
	box(hill, "Piazza paving", V(-29.95, 6.6, -21.95), V(29.95, 7.0, 21.95), L.paving, true)
	-- paving bands: a ring of darker slabs round the tower and two cross bands
	box(hill, "Paving band", V(-9, 6.62, -9), V(9, 7.03, 9), L.stoneDark, false)
	box(hill, "Paving band", V(-29.85, 6.61, -0.6), V(-9.05, 7.02, 0.6), L.stoneDark, false)
	box(hill, "Paving band", V(9.05, 6.61, -0.6), V(29.85, 7.02, 0.6), L.stoneDark, false)

	-- the clock tower: a brick shaft on an ashlar plinth, quoins, string courses, slit windows, four clocks, the belfry
	local tw = folder(secStructure, "Clock tower")
	local tb = R(-5, 5, -5, 5)
	box(tw, "Tower plinth", V(-5.6, 6.8, -5.6), V(5.6, 9.2, 5.6), L.ashlar, true)
	box(tw, "Plinth cap", V(-5.8, 9.1, -5.8), V(5.8, 9.45, 5.8), L.stoneDark, false)
	box(tw, "Tower shaft", V(-5, 9.0, -5), V(5, 39.0, 5), L.brick, true)
	quoins(tw, tb, 9.6, 18.6, { "SW", "SE", "NE", "NW" }, CFrame.identity)
	quoins(tw, tb, 19.6, 28.2, { "SW", "SE", "NE", "NW" }, CFrame.identity)
	ring(tw, "String course", tb, 18.75, 19.35, 0.28, L.stone, CFrame.identity)
	ring(tw, "String course", tb, 28.35, 28.95, 0.28, L.stone, CFrame.identity)
	ring(tw, "String course", tb, 35.7, 36.3, 0.28, L.stone, CFrame.identity)
	ring(tw, "Tower cornice", tb, 38.4, 39.1, 0.4, L.stone, CFrame.identity)
	ring(tw, "Tower cornice", tb, 38.95, 40.0, 0.62, L.stone, CFrame.identity, 0.17)
	for _, F in { "N", "S", "E", "W" } do
		local nv = faceNormal(F)
		onWall("ClockFace", tw, facePoint(F, tb, 0, 30.4, 0), nv, CFrame.identity)
		for _, wy in { 12.4, 22.0 } do
			facePanel(
				tw,
				"Slit",
				F,
				tb,
				-0.42,
				0.42,
				wy,
				wy + 2.6,
				-0.1,
				0.05,
				L.dark,
				CFrame.identity
			)
			facePanel(
				tw,
				"Slit frame",
				F,
				tb,
				-0.75,
				-0.4,
				wy - 0.3,
				wy + 2.9,
				-0.1,
				0.16,
				L.stone,
				CFrame.identity
			)
			facePanel(
				tw,
				"Slit frame",
				F,
				tb,
				0.4,
				0.75,
				wy - 0.3,
				wy + 2.9,
				-0.1,
				0.16,
				L.stone,
				CFrame.identity
			)
			facePanel(
				tw,
				"Slit sill",
				F,
				tb,
				-0.95,
				0.95,
				wy - 0.45,
				wy - 0.05,
				-0.1,
				0.3,
				L.stone,
				CFrame.identity
			)
			facePanel(
				tw,
				"Slit head",
				F,
				tb,
				-0.95,
				0.95,
				wy + 2.55,
				wy + 3.05,
				-0.1,
				0.26,
				L.stone,
				CFrame.identity
			)
		end
	end
	kit("BelfryTop", tw, CFrame.new(0, 39.97, 0))
	col("Belfry", V(-5.5, 40, -5.5), V(5.5, 52.6, 5.5), CFrame.identity)
	task.wait()

	------------------------------------------------------------------------------------------------ the two halves
	for _, hf in halves do
		local T = hf.T
		local side = hf.side
		local half = folder(secStructure, "Half " .. hf.letter)
		local props = folder(secProps, "Half " .. hf.letter)

		-- PIAZZA EDGE (z +22 side, and the x = +-30 sides for z 0..22): ashlar plinth course, coping, pilasters
		local edge = folder(half, "Piazza edge")
		box(edge, "Plinth course", V(-30.3, -0.5, 21.9), V(30.3, 0.9, 22.3), L.stoneDark, false, T)
		for _, sx in { -1, 1 } do
			box(
				edge,
				"Plinth course",
				V(sx * 29.9, -0.48, 0.02),
				V(sx * 30.27, 0.88, 22.27),
				L.stoneDark,
				false,
				T
			)
		end
		for _, seg in { { -30.35, -25.0 }, { -11.0, 19.0 }, { 29.0, 30.35 } } do
			box(edge, "Coping", V(seg[1], 6.55, 21.9), V(seg[2], 7.02, 22.35), L.stone, true, T)
		end
		for _, sx in { -1, 1 } do
			box(
				edge,
				"Coping",
				V(sx * 29.9, 6.57, 0.02),
				V(sx * 30.32, 7.06, 22.3),
				L.stone,
				true,
				T
			)
		end
		for _, x in { -7, 13.5 } do
			box(edge, "Pilaster", V(x - 0.7, 0.6, 21.95), V(x + 0.7, 6.5, 22.22), L.stone, false, T)
		end
		for _, z in { 5.5, 17.5 } do
			for _, sx in { -1, 1 } do
				box(
					edge,
					"Pilaster",
					V(sx * 29.95, 0.6, z - 0.7),
					V(sx * 30.22, 6.5, z + 0.7),
					L.stone,
					false,
					T
				)
			end
		end
		onWall("WallLantern", edge, V(3, 5.0, 22), V(0, 0, 1), T)
		onWall("WallLantern", edge, V(30, 5.0, 14.6), V(1, 0, 0), T)
		-- a wall fountain on the east retaining wall: a niche, a spout, a stone basin
		box(edge, "Wall basin", V(29.9, -0.4, 9.0), V(31.5, 1.0, 12.0), L.stone, true, T)
		box(edge, "Basin water", V(30.0, 0.95, 9.15), V(31.3, 1.25, 11.85), L.water, false, T)
		box(edge, "Basin lip", V(31.25, 0.9, 8.85), V(31.7, 1.55, 12.15), L.stoneDark, true, T)
		box(edge, "Basin lip", V(29.95, 0.92, 8.88), V(31.28, 1.5, 9.2), L.stoneDark, true, T)
		box(edge, "Basin lip", V(29.95, 0.92, 11.8), V(31.28, 1.5, 12.12), L.stoneDark, true, T)
		box(edge, "Niche", V(29.9, 2.2, 9.75), V(30.03, 4.8, 11.25), L.niche, false, T)
		box(edge, "Niche frame", V(29.9, 2.0, 9.35), V(30.2, 5.0, 9.8), L.stone, false, T)
		box(edge, "Niche frame", V(29.9, 2.0, 11.2), V(30.2, 5.0, 11.65), L.stone, false, T)
		box(edge, "Niche head", V(29.9, 4.95, 9.2), V(30.26, 5.45, 11.8), L.stone, false, T)
		box(edge, "Spout", V(30.0, 2.75, 10.35), V(30.8, 3.0, 10.65), L.iron, false, T)

		-- STEPPED STREET (x -25..-11, z 22..38, 0 -> 7): 14 stone steps between cheek walls, newels with pots
		local st = folder(half, "Stepped street")
		steps(st, "Stepped street", -23.8, -12.2, 38, 22, 0, 7, 14, L.stone, T)
		for _, cx in { { -25, -23.8 }, { -12.2, -11 } } do
			cheek(st, cx[1], cx[2], 38, 21.95, 0, 7, 1.07, L.ashlar, T)
			newel(st, cx[1], cx[2], 38.4, -0.5, 2.3, T)
			newel(st, cx[1], cx[2], 22.9, 6.8, 8.9, T)
			kit("PotBush", props, T * CFrame.new((cx[1] + cx[2]) / 2, 2.57, 38.4), 0.8)
		end
		-- RAMP (x 19..29, z 22..38): a cobbled ramp with stone cordonata edges, cheek walls
		local rp = folder(half, "Ramp")
		do
			local c = V(24, 3.35, 29.975)
			wedge(
				rp,
				"Ramp",
				V(7.6, 7.3, 16.05),
				T * CFrame.lookAt(c, c - V(0, 0, -1)),
				L.cobble,
				true
			)
			for k = 1, 7 do
				local z = 38 - k * 2
				local y = -0.3 + (38 - z) * 7.3 / 16.05
				beam(
					rp,
					"Cordonata",
					V(20.15, y + 0.03, z),
					V(27.85, y + 0.03, z),
					0.55,
					0.22,
					L.stone,
					T
				)
			end
			for _, cx in { { 19, 20.2 }, { 27.8, 29 } } do
				cheek(rp, cx[1], cx[2], 38, 21.95, 0, 7, 1.07, L.ashlar, T)
				newel(rp, cx[1], cx[2], 38.4, -0.5, 2.3, T)
				newel(rp, cx[1], cx[2], 22.9, 6.8, 8.9, T)
			end
		end

		-- UP ON THE HILL (+7): a planter with a clipped hedge, a stone bench, the edge balustrade, the pavilion
		local top = folder(half, "Hill top")
		box(top, "Planter", V(-17, 6.9, 7), V(-11, 9.0, 13), L.ashlar, true, T)
		box(top, "Planter coping", V(-17.2, 8.85, 6.8), V(-10.8, 9.15, 13.2), L.stone, false, T)
		hedge(top, V(-16.6, 9.1, 7.4), V(-11.4, 10.5, 12.6), T)
		-- bench (x 10..18, z 11.75..14.25): legs, seat, a high back, all stone
		box(top, "Bench leg", V(10.2, 6.95, 11.85), V(11.2, 8.45, 13.4), L.stoneDark, false, T)
		box(top, "Bench leg", V(16.8, 6.95, 11.85), V(17.8, 8.45, 13.4), L.stoneDark, false, T)
		box(top, "Bench seat", V(10.0, 8.4, 11.75), V(18.0, 8.9, 13.5), L.stone, false, T)
		box(top, "Bench back", V(10.05, 6.95, 13.45), V(17.95, 9.95, 14.25), L.stone, false, T)
		box(top, "Bench back cap", V(9.9, 9.9, 13.3), V(18.1, 10.15, 14.4), L.stoneDark, false, T)
		col("Bench", V(10, 7, 11.75), V(18, 10, 14.25), T)
		-- the edge balustrade between the climbs (x -3.8..9.8)
		balRun(top, "X", 21.2, -3.8, 9.8, 7.0, T)
		kit("Pavilion", top, T * CFrame.new(20, 6.98, 4))
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				col(
					"Pavilion column",
					V(20 + sx * 2.25, 7, 4 + sz * 2.25),
					V(20 + sx * 3.0, 14.3, 4 + sz * 3.0),
					T
				)
			end
		end
		col("Pavilion roof", V(16.4, 14.3, 0.4), V(23.6, 17.6, 7.6), T)
		kit("PotBush", props, T * CFrame.new(-7.6, 6.98, 17.5), 0.9)
		kit("PotBush", props, T * CFrame.new(26.5, 6.98, 17.6), 0.9)
		task.wait()

		-- LOWER STREET: the fountain square, the stall, the well, the cart
		local sq = folder(half, "Fountain square")
		box(sq, "Square paving", V(8.05, -0.3, 41.05), V(35.95, 0.05, 66.95), L.paving, false, T)
		box(sq, "Square border", V(8, -0.2, 41), V(36, 0.08, 41.8), L.stoneDark, false, T)
		box(sq, "Square border", V(8, -0.2, 66.2), V(36, 0.08, 67), L.stoneDark, false, T)
		box(sq, "Square border", V(8, -0.2, 41.8), V(8.8, 0.08, 66.2), L.stoneDark, false, T)
		box(sq, "Square border", V(35.2, -0.2, 41.8), V(36, 0.08, 66.2), L.stoneDark, false, T)
		kit("Fountain", props, T * CFrame.new(22, 0, 54))
		col("Fountain basin", V(17.1, 0, 49.1), V(26.9, 2.7, 58.9), T)
		col(
			"Fountain basin",
			V(-4.9, -1.35, -4.9),
			V(4.9, 1.35, 4.9),
			T * CFrame.new(22, 1.35, 54) * CFrame.Angles(0, math.pi / 4, 0)
		)
		col("Fountain column", V(20.8, 2.6, 52.8), V(23.2, 9.6, 55.2), T)
		blocker("Fountain top", V(20.8, 9.55, 52.8), V(23.2, 12.5, 55.2), T)
		kit("MarketStall", props, T * CFrame.new(-22, -0.03, 54), 1, side)
		col("Stall", V(-25.9, 0, 51.7), V(-16.8, 3.3, 55.9), T)
		kit("Well", props, T * CFrame.new(-8, 0, 66))
		col("Well", V(-10.8, 0, 63.2), V(-5.2, 2.8, 68.8), T)
		col(
			"Well",
			V(-2.8, -1.4, -2.8),
			V(2.8, 1.4, 2.8),
			T * CFrame.new(-8, 1.4, 66) * CFrame.Angles(0, math.pi / 4, 0)
		)
		kit("Cart", props, T * CFrame.new(28, -0.03, 80) * CFrame.Angles(0, math.pi / 2 + 0.12, 0))
		col(
			"Cart",
			V(-2.6, -1.0, -1.7),
			V(2.6, 1.0, 1.7),
			T * CFrame.new(27.0, 1.0, 80.1) * CFrame.Angles(0, 0.12, 0)
		)
		kit(
			"CrateA_35",
			props,
			T * CFrame.new(33.2, -0.03, 80.6) * CFrame.Angles(0, 0.18, 0),
			0.8,
			nil,
			"Props"
		)
		col(
			"Crate",
			V(-2.1, -1.4, -2.1),
			V(2.1, 1.4, 2.1),
			T * CFrame.new(33.2, 1.4, 80.6) * CFrame.Angles(0, 0.18, 0)
		)

		-- KIOSK (x 36..44, z 26..34): a little shop at the ramp foot
		house({
			name = "Kiosk",
			b = R(36, 44, 26, 34),
			h = 8,
			lk = L.yellow,
			faces = {
				W = { ground = { "S" } },
				S = { ground = { "W" } },
				N = { ground = { "D" } },
				E = { ground = { "W" } },
			},
			roof = "X",
			rise = 2.2,
			corniceOut = 0.45,
			parent = half,
		}, T, side)
		blocker("Kiosk roof", V(35.1, 7.4, 25.1), V(44.9, 60, 34.9), T)

		-- SHRINE (x -58..-52, z 12.5..15.5): a votive pier with a painted niche, candles, a little roof
		local sh = folder(half, "Shrine")
		local sb = R(-58, -52, 12.5, 15.5)
		box(sh, "Shrine body", V(-58, -0.6, 12.5), V(-52, 8.2, 15.5), L.cream, true, T)
		box(sh, "Shrine plinth", V(-58.2, -0.5, 12.3), V(-51.8, 1.3, 15.7), L.ashlar, true, T)
		ring(sh, "Cornice", sb, 7.55, 8.23, 0.35, L.stone, T)
		facePanel(sh, "Niche", "N", sb, -56.3, -53.7, 2.6, 6.2, -0.1, 0.04, L.niche, T)
		facePanel(sh, "Niche frame", "N", sb, -56.75, -56.25, 2.4, 6.25, -0.1, 0.25, L.stone, T)
		facePanel(sh, "Niche frame", "N", sb, -53.75, -53.25, 2.4, 6.25, -0.1, 0.25, L.stone, T)
		for _, s in { -1, 1 } do
			local c = V(-55 + s * 0.8, 6.75, 15.62)
			wedge(
				sh,
				"Niche pediment",
				V(0.36, 1.1, 1.6),
				T
					* CFrame.lookAt(c, c + V(s, 0, 0))
					* CFrame.Angles(0, math.pi / 2, 0)
					* CFrame.Angles(0, -math.pi / 2, 0),
				L.stone
			)
		end
		box(sh, "Niche shelf", V(-56.5, 2.25, 15.4), V(-53.5, 2.6, 16.2), L.stone, false, T)
		kit("PotBush", sh, T * CFrame.new(-55, 2.57, 15.85), 0.42)
		for _, x in { -56.05, -53.95 } do
			local cdl = box(
				sh,
				"Candle",
				V(x - 0.09, 2.58, 15.8),
				V(x + 0.09, 2.95, 15.98),
				L.glow,
				false,
				T
			)
			local pl = Instance.new("PointLight")
			pl.Color = C.glow
			pl.Range = 7
			pl.Brightness = 0.6
			pl.Shadows = false
			pl.Parent = cdl
		end
		gable(sh, sb, 8.2, 1.3, 0.55, false, L.cream, T)
		kit("PotBush", props, T * CFrame.new(-59.6, -0.03, 16.2), 0.8)

		-- LOGGIA HOUSE (x -75..-45, z 32..60): an arcade portico, a +12 roof terrace with balustrades, a pergola, a
		-- roof hut, its stair (east side) and stone steps (west side)
		local lg = folder(half, "Loggia")
		house({
			name = "Loggia house",
			b = R(-75, -45, 36, 60),
			h = 11.45,
			lk = L.rose,
			rustic = true,
			string = 7.95,
			corniceOut = 0.25,
			faces = {
				S = {
					us = { -70.4, -65.2, -60, -54.8, -49.6 },
					ground = { "W", "D", "W", "D", "W" },
					attic = 8.85,
				},
				N = { ground = { "W", "S", "D", "W" }, attic = 8.85, lanterns = true },
				W = { ground = { "W", "-", "W" }, attic = 8.85 },
				E = { us = { 56.9 }, ground = { "W" }, attic = 8.85 },
			},
			parent = lg,
		}, T, side)
		for i = 1, 5 do
			kit("ArcadeBay", lg, T * CFrame.new(-60 + (i - 3) * 5.2, -0.03, 32.0))
		end
		box(lg, "End pier", V(-75, -0.6, 31.4), V(-72.93, 11.42, 36.02), L.ashlar, true, T)
		box(lg, "End pier", V(-47.07, -0.6, 31.4), V(-45, 11.42, 36.02), L.ashlar, true, T)
		box(lg, "Frieze", V(-72.95, 7.95, 31.45), V(-47.05, 11.43, 32.55), L.rose, true, T)
		box(lg, "Portico floor", V(-72.9, -0.3, 32.72), V(-47.1, 0.06, 35.75), L.paving, false, T)
		for k = 0, 9 do
			local x = -71.6 + k * 2.6
			box(
				lg,
				"Ceiling beam",
				V(x - 0.25, 10.78, 32.5),
				V(x + 0.25, 11.42, 35.85),
				L.woodDark,
				false,
				T
			)
		end
		box(lg, "Terrace", V(-75.3, 11.4, 31.2), V(-44.7, 12.0, 60.3), L.paving, true, T)
		-- terrace balustrades: south edge full, east from the stair opening, north from the roof hut, west up to the steps
		balRun(lg, "X", 31.9, -75.25, -44.75, 12.0, T)
		balRun(lg, "Z", -45.4, 36.2, 60.2, 12.0, T, -0.04)
		balRun(lg, "X", 59.55, -67.0, -46.1, 12.0, T, -0.08)
		balRun(lg, "Z", -74.6, 32.6, 47.3, 12.0, T, -0.04)
		house({
			name = "Roof hut",
			b = R(-75.25, -67.0, 53.4, 60.25),
			y0 = 12,
			h = 8.4, -- eave above the deck's jump reach
			lk = L.ochre,
			faces = { S = { ground = { "D" } }, E = { ground = { "W" } } },
			roof = "X",
			rise = 1.8,
			corniceOut = 0.4,
			jit = 0.06,
			parent = lg,
		}, T, side)
		-- the terrace railing is a hop-over (owner 2026-11-21: railings jumpable), so its neighbouring roofs get blockers
		blocker("Roof hut roof", V(-76.4, 19.6, 52.3), V(-65.9, 60, 61.3), T)
		-- pergola with a vine over the middle of the terrace (plain timber: the plank texture read as stacked boards)
		local TIMBER: Look = { color = C.wood, mat = Enum.Material.Wood }
		local TIMBER_DARK: Look = { color = C.woodDark, mat = Enum.Material.Wood }
		for _, x in { -65.5, -56.5 } do
			for _, z in { 38.5, 45.5 } do
				box(
					lg,
					"Pergola post",
					V(x - 0.3, 11.95, z - 0.3),
					V(x + 0.3, 16.6, z + 0.3),
					TIMBER,
					false,
					T
				)
			end
		end
		for _, z in { 38.5, 45.5 } do
			box(
				lg,
				"Pergola beam",
				V(-66.3, 16.3, z - 0.25),
				V(-55.7, 16.9, z + 0.25),
				TIMBER_DARK,
				false,
				T
			)
		end
		for k = 0, 4 do
			local x = -65.0 + k * 2.25
			box(
				lg,
				"Pergola rafter",
				V(x - 0.15, 16.85, 38.3),
				V(x + 0.15, 17.22, 45.7),
				TIMBER,
				false,
				T
			)
		end
		-- the vine: runs draped across the rafters (a single leafy slab read as a carpet)
		for k = 0, 3 do
			local x = -63.875 + k * 2.25
			local run = part(
				lg,
				"Vine",
				V(2.4, 0.22, if k % 2 == 0 then 7.0 else 6.2),
				T * CFrame.new(x, 17.2 + (k % 2) * 0.04, 42 + (k % 2) * 0.3),
				if k % 2 == 0 then L.leaf else L.leafDark
			)
			run:SetAttribute("AllowFloat", true) -- foliage laid over the rafters
		end
		kit("CafeSet", props, T * CFrame.new(-51, 11.97, 52.5) * CFrame.Angles(0, 0.4, 0), 1, side)
		kit(
			"CafeSet",
			props,
			T * CFrame.new(-51.5, 11.97, 42.5) * CFrame.Angles(0, -0.3, 0),
			1,
			side
		)
		kit("PotBush", props, T * CFrame.new(-60.5, 11.97, 33.6), 0.85)
		kit("PotBush", props, T * CFrame.new(-47.2, 11.97, 58.0), 0.85)
		-- the stair (x -45..-40.8, z 55.5 -> 35.5, 0 -> 12), its landing and the outer wall
		steps(lg, "Loggia stair", -45.0, -40.8, 55.5, 35.5, 0, 11.97, 24, L.stone, T)
		box(lg, "Landing", V(-44.95, -0.6, 31.32), V(-39.65, 11.97, 35.55), L.ashlar, true, T)
		box(lg, "Landing paving", V(-45.0, 11.85, 31.27), V(-40.9, 12.03, 35.5), L.paving, true, T)
		cheek(lg, -40.8, -39.6, 55.5, 35.45, 0, 11.97, 2.27, L.ashlar, T)
		box(lg, "Landing wall", V(-40.86, 11.9, 31.4), V(-39.55, 14.2, 35.6), L.ashlar, true, T)
		box(lg, "Landing wall", V(-44.95, 11.88, 31.36), V(-40.91, 14.17, 32.45), L.ashlar, true, T)
		box(lg, "Landing coping", V(-41.0, 14.15, 31.08), V(-39.4, 14.5, 35.75), L.stone, false, T)
		box(lg, "Landing coping", V(-45.0, 14.12, 31.05), V(-41.03, 14.47, 32.6), L.stone, false, T)
		newel(lg, -40.8, -39.6, 56.2, -0.5, 3.6, T)
		kit("PotBush", props, T * CFrame.new(-40.2, 3.87, 56.2), 0.75)
		-- the stone steps up the west side: 3.5 -> 7 -> 12
		box(lg, "Step block", V(-80, -0.6, 47.5), V(-75.15, 6.8, 52.5), L.ashlar, true, T)
		box(lg, "Step cap", V(-80.15, 6.75, 47.35), V(-75.12, 7.05, 52.65), L.stone, true, T)
		box(lg, "Step block", V(-85, -0.6, 47.65), V(-79.95, 3.3, 52.35), L.ashlar, true, T)
		box(lg, "Step cap", V(-85.15, 3.25, 47.55), V(-79.9, 3.55, 52.45), L.stone, true, T)
		-- the cafe on the north street
		kit(
			"CafeSet",
			props,
			T * CFrame.new(-66.5, -0.03, 65.5) * CFrame.Angles(0, 0.2, 0),
			1,
			side
		)
		kit(
			"CafeSet",
			props,
			T * CFrame.new(-57.5, -0.03, 66.2) * CFrame.Angles(0, -0.5, 0),
			1,
			side
		)
		kit("PlanterBox", props, T * CFrame.new(-52.6, -0.03, 61.5), 1, side)
		task.wait()

		-- LONG HOUSE (x 52..76, z 35..69, h 16), its garden wall and garden
		house({
			name = "Long house",
			b = R(52, 76, 35, 69),
			h = 16,
			lk = L.ochre,
			rustic = true,
			roof = "Z",
			rise = 4.6,
			faces = {
				W = { ground = { "S", "D", "W", "D", "S" }, lanterns = true, balcony = 3 },
				S = { ground = { "W", "D", "W" } },
				N = { ground = { "W", "D", "W" } },
				E = { ground = { "W", "W", "D", "W", "W" } },
			},
			chimneys = { { 58, 42 }, { 70, 62 } },
			parent = half,
		}, T, side)
		local gw = folder(half, "Garden")
		box(gw, "Garden wall", V(38.75, -0.6, 65), V(41.25, 3.2, 79), L.ashlar, true, T)
		box(gw, "Wall coping", V(38.6, 3.15, 64.85), V(41.4, 3.55, 79.15), L.stone, true, T)
		for _, z in { 64.4, 79.6 } do
			box(gw, "Wall pier", V(38.5, -0.6, z - 0.75), V(41.5, 4.2, z + 0.75), L.ashlar, true, T)
			box(
				gw,
				"Pier cap",
				V(38.35, 4.15, z - 0.9),
				V(41.65, 4.45, z + 0.9),
				L.stoneDark,
				false,
				T
			)
			kit("PotBush", gw, T * CFrame.new(40, 4.42, z), 0.7)
		end
		box(gw, "Garden grass", V(41.3, -0.3, 65), V(51.75, 0.04, 79), L.grass, false, T)
		hedge(gw, V(41.6, -0.2, 78.4), V(51.5, 2.3, 79.7), T)
		kit("Bush", gw, T * CFrame.new(44.2, 0, 68.5) * CFrame.Angles(0, 0.7, 0), 1.2)
		kit("Bush", gw, T * CFrame.new(48.8, 0, 73.8) * CFrame.Angles(0, 2.1, 0), 1.4)
		kit("Bush", gw, T * CFrame.new(44.5, 0, 75.8) * CFrame.Angles(0, 4.0, 0), 1.0)

		-- HOUSE BRIDGES over the flank alleys (base 8): an ashlar pier, stone lintels, a timber ceiling, a room above
		for _, br in { { sx = 1, zc = 14, lk = L.sienna }, { sx = -1, zc = 22, lk = L.cream } } do
			local sx, zc = br.sx, br.zc
			local bf = folder(half, if sx > 0 then "Bridge east" else "Bridge west")
			box(
				bf,
				"Bridge pier",
				V(sx * 76, -0.6, zc - 5),
				V(sx * 78.5, 8.25, zc + 5),
				L.ashlar,
				true,
				T
			)
			box(
				bf,
				"Pier cap",
				V(sx * 75.7, 7.6, zc - 5.3),
				V(sx * 78.6, 8.28, zc + 5.3),
				L.stone,
				false,
				T
			)
			for _, s in { -1, 1 } do
				box(
					bf,
					"Lintel",
					V(sx * 78.4, 7.4, zc + s * 4.35),
					V(sx * 100.7, 8.3, zc + s * 5.15),
					L.stone,
					true,
					T
				)
			end
			box(
				bf,
				"Ceiling",
				V(sx * 78.45, 8.13, zc - 4.55),
				V(sx * 100.7, 8.35, zc + 4.55),
				L.wood,
				false,
				T
			)
			for k = 0, 6 do
				local x = sx * (80.5 + k * 3)
				box(
					bf,
					"Ceiling beam",
					V(x - 0.3, 7.55, zc - 4.55),
					V(x + 0.3, 8.16, zc + 4.55),
					L.woodDark,
					false,
					T
				)
			end
			house({
				name = "Bridge room",
				b = R(sx * 76, sx * 100.8, zc - 5, zc + 5),
				y0 = 8.2,
				h = 5.8,
				lk = br.lk,
				string = 30,
				floors = { 9.4 },
				faces = {
					S = { us = { sx * 84, sx * 92 }, ground = { "-" } },
					N = { us = { sx * 84, sx * 92 }, ground = { "-" } },
				},
				roof = "X",
				rise = 2.4,
				corniceOut = 0.4,
				quoins = false,
				jit = 0.11,
				parent = bf,
			}, T, side)
			onWall("WallLantern", bf, V(sx * 78.5, 6.0, zc), V(sx, 0, 0), T)
			blocker("Bridge roof", V(sx * 75.1, 13.0, zc - 5.9), V(sx * 100, 60, zc + 5.9), T)
		end
		task.wait()

		-- GATEHOUSE (x -17..17, z 84..92, h 12): the town gate with closed doors, screening the spawn
		local gh = folder(half, "Gatehouse")
		local gb = R(-17, 17, 84, 92)
		box(gh, "Gate body", V(-17, -0.6, 84), V(17, 12, 92), L.brick, true, T)
		box(gh, "Gate rustication", V(-17.2, -0.5, 83.8), V(17.2, 3.2, 92.2), L.ashlar, true, T)
		quoins(gh, gb, 3.5, 10.3, { "SW", "SE", "NE", "NW" }, T)
		ring(gh, "Gate band", gb, 10.4, 10.9, 0.35, L.stone, T)
		for k = 0, 13 do
			local x = -16.25 + k * 2.5
			box(gh, "Merlon", V(x - 0.7, 11.9, 83.9), V(x + 0.7, 13.6, 85.0), L.brick, true, T)
			box(gh, "Merlon", V(x - 0.7, 11.9, 91.0), V(x + 0.7, 13.6, 92.1), L.brick, true, T)
		end
		for _, z in { 86.6, 89.4 } do
			for _, sx in { -1, 1 } do
				box(
					gh,
					"Merlon",
					V(sx * 15.9, 11.9, z - 0.7),
					V(sx * 17.1, 13.6, z + 0.7),
					L.brick,
					true,
					T
				)
			end
		end
		for _, F in { "S", "N" } do
			facePanel(gh, "Gate door", F, gb, -2.95, -0.06, -0.02, 6.2, -0.1, 0.32, L.wood, T)
			facePanel(gh, "Gate door", F, gb, 0.06, 2.95, -0.02, 6.2, -0.1, 0.32, L.wood, T)
			for _, sy in { 1.3, 4.6 } do
				facePanel(gh, "Gate strap", F, gb, -2.85, -0.16, sy, sy + 0.35, 0.2, 0.4, L.iron, T)
				facePanel(gh, "Gate strap", F, gb, 0.16, 2.85, sy, sy + 0.35, 0.2, 0.4, L.iron, T)
			end
			facePanel(gh, "Gate jamb", F, gb, -4.0, -2.9, -0.3, 6.25, -0.1, 0.45, L.stone, T)
			facePanel(gh, "Gate jamb", F, gb, 2.9, 4.0, -0.3, 6.25, -0.1, 0.45, L.stone, T)
			facePanel(gh, "Gate lintel", F, gb, -3.0, 3.0, 6.15, 6.6, -0.1, 0.38, L.stone, T)
			archRing(gh, F, gb, 0, 6.2, 3.0, 0.9, -0.1, 0.5, 9, T)
			for _, s in { -1, 1 } do
				onWall("WallLantern", gh, facePoint(F, gb, s * 6.0, 5.4, 0), faceNormal(F), T)
			end
		end
		kit("PotBush", props, T * CFrame.new(-7.2, -0.03, 93.6), 0.9)
		kit("PotBush", props, T * CFrame.new(7.2, -0.03, 93.6), 0.9)
		kit("PotBush", props, T * CFrame.new(-19.5, -0.03, 83.0), 0.9)

		-- CORNER HOUSES round the spawn yard (facades step 0.5 between neighbours)
		house({
			name = "Corner house E1",
			b = R(50, 70.05, 88, 109.9),
			h = 16,
			lk = L.cream,
			rustic = true,
			roof = "Z",
			faces = {
				S = { ground = { "W", "D", "W" } },
				W = { ground = { "W", "D", "W" }, lanterns = true },
			},
			chimneys = { { 56, 104 } },
			jit = 0.0,
			parent = half,
		}, T, side)
		house({
			name = "Corner house E2",
			b = R(70, 100, 87.5, 110.1),
			h = 20.5,
			lk = L.rose,
			rustic = true,
			roof = "X",
			faces = { S = { ground = { "S", "D", "W", "S" }, lanterns = true, balcony = 2 } },
			chimneys = { { 92, 104 } },
			jit = 0.13,
			parent = half,
		}, T, side)
		house({
			name = "Corner house W1",
			b = R(-100, -74, 87.5, 110),
			h = 20.5,
			lk = L.sienna,
			rustic = true,
			roof = "X",
			faces = { S = { ground = { "W", "S", "D", "W" }, lanterns = true } },
			chimneys = { { -80, 103 } },
			jit = 0.07,
			parent = half,
		}, T, side)
		house({
			name = "Corner house W2",
			b = R(-74.05, -50, 88, 109.9),
			h = 16,
			lk = L.yellow,
			rustic = true,
			roof = "Z",
			faces = {
				S = { ground = { "D", "W", "D" } },
				E = { ground = { "W", "D", "W" }, lanterns = true },
			},
			chimneys = { { -58, 98 } },
			jit = 0.18,
			parent = half,
		}, T, side)

		-- SPAWN TERRACE: paving, a balustrade over the drop to the lower town, planters
		local sp = folder(half, "Spawn terrace")
		box(sp, "Spawn paving", V(-49.75, -0.3, 92.3), V(49.75, 0.05, 111.4), L.paving, false, T)
		balRun(sp, "X", 111.0, -49.7, 49.7, 0.05, T)
		for _, p in { { -32, 107.8 }, { 32, 107.8 }, { -42.5, 105 }, { 42.5, 105 } } do
			kit("PotBush", props, T * CFrame.new(p[1], 0.02, p[2]), 0.95)
		end
		kit("PlanterBox", props, T * CFrame.new(-24, 0.02, 93.4), 1)
		kit("PlanterBox", props, T * CFrame.new(24, 0.02, 93.4), 1)

		-- LAUNDRY over the flank alleys (out of the lanes, no collision)
		laundry(
			props,
			V(-75.05, 10.3, 42),
			V(-100.15, 13.0, 42),
			T,
			{ C.cloth, side.cloth, hex("9DB7CF"), hex("F2EEE4") }
		)
		laundry(
			props,
			V(76.05, 12.6, 55.4),
			V(100.55, 14.2, 55.4),
			T,
			{ hex("F2EEE4"), hex("D9B26A"), side.cloth }
		)
		task.wait()

		------------------------------------------------------------------------------------- the town past the bounds
		local town = folder(secWorld, "Town " .. hf.letter)
		-- the side rows facing the flank alleys
		local rows = {
			{ x0 = 100.6, z0 = 0.02, z1 = 24, h = 18, lk = L.cream, F = "W", us = { 5, 19.5 } },
			{ x0 = 100.2, z0 = 24, z1 = 44, h = 22, lk = L.ochre, F = "W" },
			{ x0 = 100.6, z0 = 44, z1 = 66, h = 16, lk = L.rose, F = "W" },
			{ x0 = 100.2, z0 = 66, z1 = 87.44, h = 21.5, lk = L.yellow, F = "W" },
			{ x0 = -100.2, z0 = 0.02, z1 = 14, h = 19.5, lk = L.sienna, F = "E" },
			{ x0 = -100.6, z0 = 14, z1 = 36, h = 17, lk = L.yellow, F = "E", us = { 31.5 } },
			{ x0 = -100.2, z0 = 36, z1 = 62, h = 22, lk = L.cream, F = "E" },
			{ x0 = -100.6, z0 = 62, z1 = 87.44, h = 16, lk = L.ochre, F = "E" },
		}
		for i, rw in rows do
			local x1 = (if rw.x0 > 0 then 1 else -1)
				* (118 + (i % 2) * 0.9 + (if hf.letter == "B" then 0.45 else 0))
			local zz1 = if rw.z1 < 87 then rw.z1 + 0.05 else rw.z1
			house({
				name = "Row house",
				b = R(rw.x0, x1, rw.z0, zz1),
				h = rw.h,
				lk = rw.lk,
				rustic = i % 2 == 0,
				roof = "Z",
				faces = {
					[rw.F] = {
						ground = if i % 3 == 0
							then { "S", "D" }
							elseif i == 4 or i == 8 then { "W", "D", "W" }
							else { "W", "D", "S" },
						us = (rw :: any).us,
						lanterns = i % 2 == 1,
					},
				},
				chimneys = {
					{ (rw.x0 + x1) / 2 + (if rw.x0 > 0 then 4 else -4), (rw.z0 + rw.z1) / 2 },
				},
				jit = i * 0.09 + (if hf.letter == "B" then 0.045 else 0),
				parent = town,
			}, T, side)
		end
		house({
			name = "Row house",
			b = R(101.0, 118, 87.53, 111.3),
			h = 18,
			lk = L.ochre,
			faces = {},
			roof = "Z",
			simple = true,
			parent = town,
		}, T, side)
		house({
			name = "Row house",
			b = R(-118, -100.6, 87.53, 111.3),
			h = 19,
			lk = L.rose,
			faces = {},
			roof = "Z",
			simple = true,
			parent = town,
		}, T, side)
		-- the lower town below the spawn terrace (ground -26.5), simple houses in rows, cypress
		local seed = if hf.letter == "A" then 17 else 53
		local function rnd(): number
			seed = (seed * 1103515245 + 12345) % 2147483648
			return seed / 2147483648
		end
		local lowT = folder(town, "Lower town")
		for row = 0, 2 do
			local z = 126 + row * 24
			local x = -210 + rnd() * 10
			while x < 210 do
				local w = 10 + rnd() * 7
				local d = 9 + rnd() * 6
				local h = 9 + rnd() * 6 + row * 1.5
				if rnd() > 0.15 then
					local zz = z + (rnd() - 0.5) * 6
					house({
						name = "House",
						b = R(x, x + w, zz, zz + d),
						y0 = -26.5,
						h = h,
						lk = STUCCO[1 + math.floor(rnd() * #STUCCO)],
						faces = {},
						roof = if rnd() > 0.5 then "X" else "Z",
						simple = true,
						parent = lowT,
					}, T, side)
				end
				x += w + 3 + rnd() * 6
			end
			task.wait()
		end
		for i = 1, 12 do
			local cx = -190 + i * 30 + rnd() * 10
			local cz = 118 + rnd() * 80
			kit(
				if i % 2 == 0 then "CypressA" else "CypressB",
				town,
				T * CFrame.new(cx, -26.6, cz) * CFrame.Angles(0, rnd() * 6.28, 0),
				1.1 + rnd() * 0.5
			)
		end
		-- fields on the valley floor (a patchwork of greens and wheat), cypress lines along the lanes
		local FIELD = {
			hex("8FA35A"),
			hex("A7AE62"),
			hex("C8A75C"),
			hex("7E9150"),
			hex("B9B06A"),
			hex("6E7E4A"),
		}
		for k = 1, 18 do
			local fx = -560 + rnd() * 1120
			local fz = 250 + rnd() * 560
			local w = 70 + rnd() * 110
			local d = 50 + rnd() * 90
			-- stacked tops (no shared plane); every bottom sunk into the valley so none floats
			local top, bottom = -26.32 + k * 0.025, -26.6 - k * 0.01
			local fp = part(
				town,
				"Field",
				V(w, top - bottom, d),
				T * CFrame.new(fx, (top + bottom) / 2, fz) * CFrame.Angles(0, rnd() * 0.6 - 0.3, 0),
				{ color = FIELD[1 + (k % #FIELD)], mat = Enum.Material.Grass }
			)
			fp.CastShadow = false
		end
		for k = 1, 14 do
			kit(
				if k % 2 == 0 then "CypressA" else "CypressB",
				town,
				T
					* CFrame.new(-300 + k * 34, -26.6, 236 + (k % 3) * 2)
					* CFrame.Angles(0, rnd() * 6.28, 0),
				1.3 + rnd() * 0.3
			)
		end
		-- the hills round the valley
		for _, hl in
			{
				{ "HillA", 0, -58, 820, 0, 1.0 },
				{ "HillB", -780, -52, 420, 0.4, 1.0 },
				{ "HillC", 760, -48, 360, -0.5, 1.1 },
				{ "HillB", 470, -46, 860, 2.6, 0.9 },
				{ "HillC", -470, -44, 900, 1.2, 1.2 },
				{ "HillA", -1080, -60, 60, 1.57, 1.3 },
				{ "HillC", 1000, -50, -80, 0.9, 1.4 },
				{ "HillA", 260, -40, 1250, 0.3, 1.6 },
			}
		do
			local m = kit(
				hl[1] :: string,
				town,
				T
					* CFrame.new(hl[2] :: number, hl[3] :: number, hl[4] :: number)
					* CFrame.Angles(0, hl[5] :: number, 0),
				hl[6] :: number
			)
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					d:SetAttribute("AllowFloat", true)
					d.CastShadow = false
				end
			end
		end
	end
	task.wait()

	------------------------------------------------------------------------------------------- spawns, bounds, stage
	local SPAWNS = { { -12, 101 }, { 0, 103 }, { 12, 101 }, { -6, 97 }, { 6, 97 } }
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
		local p = box(secBounds, "Bound", a, b, { color = C.stone }, true)
		p.Transparency = 1
		p.CanQuery = false
		p.CastShadow = false
	end
	bound(V(100, -6, -111), V(102, 60, 111))
	bound(V(-102, -6, -111), V(-100, 60, 111))
	bound(V(-102, -6, 110), V(102, 60, 112))
	bound(V(-102, -6, -112), V(102, 60, -110))
	bound(V(-102, 60, -112), V(102, 62, 112))
	local stage =
		part(map, "WinnerStage", V(4, 0.2, 4), CFrame.new(0, 7.1, 13), { color = C.paving })
	stage.Transparency = 1
	stage.CastShadow = false
	stage.CanCollide = false
	stage.CanQuery = false
	CollectionService:AddTag(stage, "WinnerStage")

	------------------------------------------------------------------------------------------- lighting
	local light = Instance.new("Configuration")
	light.Name = "Lighting"
	CollectionService:AddTag(light, "GGAsset_MatchMaps_418")
	CollectionService:AddTag(light, "GauntletAuthoredData")
	light.Parent = map
	local fx = folder(map, "LightingFx")
	local atm = Instance.new("Atmosphere")
	atm.Density = 0.3
	atm.Offset = 0.15
	atm.Haze = 1.4
	atm.Glare = 0.35
	atm.Color = Color3.fromRGB(238, 206, 168)
	atm.Decay = Color3.fromRGB(186, 140, 110)
	atm.Parent = fx
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "Grade"
	cc.Contrast = 0.08
	cc.Saturation = 0.08
	cc.TintColor = Color3.fromRGB(255, 248, 238)
	cc.Parent = fx

	-- RIVALS texture pass: kit meshes and inline looks onto the same variants as the Parts
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") then
			local r = REMAP[d.Material.Name .. "|" .. d.MaterialVariant]
			if r then
				d.Material = r[1]
				d.MaterialVariant = r[2]
			end
		end
	end

	map.Parent = workspace
	return string.format("OldTown4 built: %d parts", count)
end
