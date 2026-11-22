--!strict
-- Foundry4 (regular map, 1v1-2v2), the whole build (2026-11-21). RIVALS study, layout and build log:
-- vault/01 Design/Maps/Foundry4.md. Layout rows mirror tools/maps/foundry4_layout.py. Match place only, edit mode.
-- Returns a function; run it with require(<a clone>)().
--
-- A steel works at night, built to the RIVALS look (Museum / Docks study): plain Part masses with chunky stepped trims,
-- a reused MeshPart kit (tools/blender/maps_foundry4, ServerStorage.MapKit.Foundry4), flat colours with soft variants
-- (no normal maps), one structural accent (safety yellow), warm lamps and molten glow against a cool night.
-- Mirror symmetry across the midline (z -> -z): the furnace (west) and the ladle (east) sit on the midline. A half is
-- built once and mirrored by mir(): a piece's local X is flipped by the turn, so mirrored pieces are X-symmetric.
-- The middle: the melt shop (x -48..48, z -32..32), steel portal frames, clad walls with three doors a side, a roof
-- with a monitor. The blast furnace (the landmark) closes the west end; the molten runner runs east along z = 0 into
-- the pour pit; the ladle on its car stands on the ladle track beside the pit. Two plate bridges cross the runner, the
-- skimmer gate straddles it. Catwalks (+12) along both long walls, stairs at both ends, joined by the walkway hung from
-- the overhead crane. Each yard: the hot blast stove and valve house, a skip, coil stacks, slab piles, the spare ladle
-- on its stand, the shunting loco on a spur (team colour), the pump house (spawn baffle), gas cylinders, drums.
-- The works round the bounds: mill sheds (clad, lit high windows), the cast house, more stoves and stacks beyond.
-- The runner and the pour pit are a kill zone: the glowing surface doesn't collide and the map's KillDepth (6, authored
-- data 423) downs anyone who falls in. Railings are low and jumpable (owner 2026-11-21); blockers only on roofs.
-- RIVALS meshes (Docks: drum, power box, jersey barrier, cone, water tank) in ServerStorage.MapKit.Foundry4Rivals.
-- Contract: Spawns (ArenaSpawn_A/B), Barriers (empty), Bounds, KillDepth + Lighting (authored data 423 / 424),
-- LightingFx, WinnerStage. Joins never share a plane: touching pieces overlap or step 0.03+.

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local ServerStorage = game:GetService("ServerStorage")

local ORIGIN = CFrame.new(6000, 200, 47000) -- ground level at the map centre
local I = CFrame.identity
local V = Vector3.new

local function hex(h: string): Color3
	return Color3.fromHex(h)
end

type Look = { color: Color3, mat: Enum.Material?, variant: string?, alpha: number? }
local function look(color: Color3, variant: string?, mat: Enum.Material?, alpha: number?): Look
	return { color = color, variant = variant, mat = mat, alpha = alpha }
end
local MET = Enum.Material.Metal
local L = {
	-- RIVALS variants (owner 2026-11-21: MaterialService.ExtraTextures; the ones RIVALS' own maps use)
	yard = look(hex("74726D"), "ConcretePanels-02a", Enum.Material.Concrete),
	concrete = look(hex("7C7A75"), "Concrete-01a", Enum.Material.Concrete),
	castFloor = look(hex("635F5B"), "Concrete-02a", Enum.Material.Concrete),
	render = look(hex("8C8982"), "Concrete-01a", Enum.Material.Concrete),
	renderDark = look(hex("67645F"), "Concrete-01a", Enum.Material.Concrete),
	refractory = look(hex("6E4636"), "CinderBlock_01a", Enum.Material.Brick),
	plate = look(hex("7C848E"), "Diamond Plate 2022", Enum.Material.DiamondPlate),
	steel = look(hex("525A64"), "Metal 2022", MET),
	steelDark = look(hex("353A42"), "Metal 2022", MET),
	steelLight = look(hex("98A1AB"), "Metal 2022", MET),
	roofUnder = look(hex("2C3036")),
	roof = look(hex("424750"), "Corrugated_01a", MET),
	clad = look(hex("56606B"), "Corrugated_01a", MET),
	yellow = look(hex("E2A62C")),
	black = look(hex("25272B")),
	paintY = look(hex("C9962E")),
	paintW = look(hex("A9A69E")),
	molten = look(hex("9A3410"), nil, Enum.Material.Neon),
	moltenHot = look(hex("B85416"), nil, Enum.Material.Neon),
	crust = look(hex("3A2B25")),
	lens = look(hex("8C6E4C"), nil, Enum.Material.Neon),
	window = look(hex("30261D"), nil, Enum.Material.Neon),
	glass = look(hex("1E2830"), nil, Enum.Material.Glass),
	wood = look(hex("8A6A48"), "Wood01a", Enum.Material.Wood),
	rust = look(hex("8E5232"), "Metal 2022", MET),
	rail = look(hex("7D848C"), "Metal 2022", MET),
	sleeper = look(hex("5A4A3E"), "Wood03a", Enum.Material.Wood),
	none = look(hex("FFFFFF")),
}
type Side = { team: Color3, letter: string }
local SIDE: { [string]: Side } = {
	A = { team = hex("C4553A"), letter = "A" },
	B = { team = hex("3F6FB0"), letter = "B" },
}
-- building clad colours (one per building, all cool or neutral greys; the hall a blue-grey)
local CLAD = {
	hall = hex("56606B"),
	castHouse = hex("5E5650"),
	mill = hex("4F5A57"),
	back = hex("5A5560"),
	pump = hex("6A6E72"),
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

-- the mirror across the midline (z -> -z) as a proper rotation: S * R * Sx (the piece's local X flips)
local function mir(cf: CFrame): CFrame
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return CFrame.new(x, y, -z, -r00, r01, r02, -r10, r11, r12, r20, -r21, -r22)
end

return function(): string
	assert(game.PlaceId == 133387545285290, "Foundry4: not the match place")
	ensureBlockerGroup()
	local old = workspace:FindFirstChild("Foundry4")
	if old then
		old:Destroy()
	end
	local map = Instance.new("Model")
	map.Name = "Foundry4"
	map.WorldPivot = ORIGIN
	CollectionService:AddTag(map, "GGAsset_MatchMaps_423")
	CollectionService:AddTag(map, "GauntletAuthoredData")

	local function folder(parent: Instance, name: string): Folder
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
		return f
	end
	local secCollision = folder(map, "Collision")
	local secGround = folder(map, "Ground")
	local secHall = folder(map, "MeltShop")
	local secFurnace = folder(map, "Furnace")
	local secRunner = folder(map, "Runner")
	local secYard = folder(map, "Yard")
	local secLights = folder(map, "Lights")
	local secWorld = folder(map, "World")
	local secSpawns = folder(map, "Spawns")
	folder(map, "Barriers")
	local secBounds = folder(map, "Bounds")
	local count = 0
	local rng = Random.new(42123)

	-- a half: M maps a local CFrame (team A, +Z) to its place; the centre uses I
	type Half = { M: (CFrame) -> CFrame, side: Side }
	local CENTRE: Half = {
		M = function(cf: CFrame): CFrame
			return cf
		end,
		side = SIDE.A,
	}
	local halves: { Half } = {
		{
			M = function(cf: CFrame): CFrame
				return cf
			end,
			side = SIDE.A,
		},
		{ M = mir, side = SIDE.B },
	}

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
		p.CastShadow = math.max(size.X, size.Y, size.Z) >= 4
			and (lk.alpha or 0) < 0.5
			and p.Material ~= Enum.Material.Neon
		p.Parent = parent
		count += 1
		return p
	end
	-- an axis-aligned box between two corners, placed by the half H (and an optional local transform T)
	local function box(
		parent: Instance,
		name: string,
		a: Vector3,
		b: Vector3,
		lk: Look,
		solid: boolean?,
		H: Half?,
		T: CFrame?
	): BasePart
		local lo, hi = a:Min(b), a:Max(b)
		local cf = (T or I) * CFrame.new((lo + hi) / 2)
		return part(parent, name, hi - lo, (H or CENTRE).M(cf), lk, solid)
	end
	local function col(name: string, a: Vector3, b: Vector3, H: Half?, T: CFrame?): BasePart
		local p = box(secCollision, name, a, b, L.none, true, H, T)
		p.Transparency = 1
		p.CastShadow = false
		return p
	end
	local function blocker(name: string, a: Vector3, b: Vector3, H: Half?, T: CFrame?): BasePart
		local p = col(name, a, b, H, T)
		p.CanQuery = false
		p.CollisionGroup = BLOCKERS
		return p
	end
	local function yaw(deg: number): CFrame
		return CFrame.Angles(0, math.rad(deg), 0)
	end
	local function fromLib(
		lib: string,
		piece: string,
		parent: Instance,
		cf: CFrame,
		H: Half?,
		scale: number?
	): Model
		local libF = ServerStorage.MapKit:FindFirstChild(lib)
		local src = libF and libF:FindFirstChild(piece)
		assert(src and src:IsA("Model"), "missing kit piece " .. lib .. "." .. piece)
		local m = src:Clone()
		if scale and scale ~= 1 then
			m:ScaleTo(scale)
		end
		m:PivotTo(ORIGIN * (H or CENTRE).M(cf))
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
	local function kit(piece: string, parent: Instance, cf: CFrame, H: Half?, scale: number?): Model
		return fromLib("Foundry4", piece, parent, cf, H, scale)
	end
	local function rivals(
		piece: string,
		parent: Instance,
		cf: CFrame,
		H: Half?,
		scale: number?
	): Model
		return fromLib("Foundry4Rivals", piece, parent, cf, H, scale)
	end
	local function recolor(m: Instance, from: string, to: Color3)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d.Name:find(from, 1, true) then
				d.Color = to
			end
		end
	end
	local function lightAt(
		parent: Instance,
		name: string,
		pos: Vector3,
		H: Half?,
		kind: string,
		range: number,
		bright: number,
		color: Color3,
		face: Enum.NormalId?
	)
		local a =
			box(parent, name, pos - V(0.1, 0.1, 0.1), pos + V(0.1, 0.1, 0.1), L.none, false, H)
		a.Transparency = 1
		a.CastShadow = false
		local l: Light
		if kind == "spot" then
			local s = Instance.new("SpotLight")
			s.Angle = 110
			s.Face = face or Enum.NormalId.Bottom
			l = s
		else
			l = Instance.new("PointLight")
		end
		l.Range = range
		l.Brightness = bright
		l.Color = color
		l.Shadows = false
		l.Parent = a
	end
	-- corrugated cladding on a wall face, RIVALS-style: plain Parts with the Corrugated_01a variant (owner 2026-11-21;
	-- the mesh panels sat 0.05 apart and shimmered at distance). The run is cut into 6-wide columns of 8-tall rows;
	-- `skip` drops cells (doors). Columns with the same rows merge into one sheet; neighbouring sheets overlap 0.02
	-- and step 0.04 in depth and 0.03 at the top, so no two faces share a plane. `face` +1 = sheet on the +Z side of
	-- the core face zf (before the half's mirror).
	local function sheets(
		n: number,
		rows: number,
		y0: number,
		skip: (number, number) -> boolean,
		at: (number) -> number
	)
		local out = {}
		local last: { number }? = nil
		for c = 0, n - 1 do
			local lo, hi = math.huge, -math.huge
			for r = 0, rows - 1 do
				if not skip(at(c), y0 + r * 8) then
					lo = math.min(lo, r)
					hi = math.max(hi, r)
				end
			end
			if lo > hi then
				last = nil
				continue
			end
			if last and last[3] == lo and last[4] == hi and last[2] == c - 1 then
				last[2] = c
			else
				last = { c, c, lo, hi }
				table.insert(out, last)
			end
		end
		return out
	end
	local function noSkip(_a: number, _b: number): boolean
		return false
	end
	local function cladRun(
		parent: Instance,
		x0: number,
		x1: number,
		y0: number,
		rows: number,
		zf: number,
		face: number,
		colr: Color3,
		H: Half?,
		skip: ((number, number) -> boolean)?
	)
		local n = math.floor((x1 - x0) / 6 + 0.5)
		local lk = look(colr, "Corrugated_01a", MET)
		for i, rc in
			sheets(n, rows, y0, skip or noSkip, function(c: number): number
				return x0 + 3 + c * 6
			end)
		do
			local d = (i % 2) * 0.04
			local a = V(x0 + rc[1] * 6 - 0.02, y0 + rc[3] * 8 - 0.03, zf - face * 0.05)
			local b = V(
				x0 + (rc[2] + 1) * 6 + 0.02,
				y0 + (rc[4] + 1) * 8 - (i % 2) * 0.03,
				zf + face * (0.22 + d)
			)
			box(parent, "Cladding", a, b, lk, false, H)
		end
	end
	local function cladRunZ(
		parent: Instance,
		z0: number,
		z1: number,
		y0: number,
		rows: number,
		xf: number,
		face: number,
		colr: Color3,
		H: Half?,
		skip: ((number, number) -> boolean)?
	)
		local n = math.floor((z1 - z0) / 6 + 0.5)
		local lk = look(colr, "Corrugated_01a", MET)
		for i, rc in
			sheets(n, rows, y0, skip or noSkip, function(c: number): number
				return z0 + 3 + c * 6
			end)
		do
			local d = (i % 2) * 0.04
			local a = V(xf - face * 0.05, y0 + rc[3] * 8 - 0.03, z0 + rc[1] * 6 - 0.02)
			local b = V(
				xf + face * (0.22 + d),
				y0 + (rc[4] + 1) * 8 - (i % 2) * 0.03,
				z0 + (rc[2] + 1) * 6 + 0.02
			)
			box(parent, "Cladding", a, b, lk, false, H)
		end
	end
	-- a run of the kit railing (F4Rail4 scaled to fit, F4Post at every joint) along X at z, floor y
	local function railX(parent: Instance, x0: number, x1: number, z: number, y: number, H: Half?)
		local n = math.max(1, math.ceil((x1 - x0) / 4 - 0.01))
		local seg = (x1 - x0) / n
		for k = 0, n - 1 do
			local m = kit("F4Rail4", parent, CFrame.new(x0 + (k + 0.5) * seg, y, z), H)
			for _, p in m:GetChildren() do
				if p:IsA("BasePart") then
					p.Size = V(seg + 0.02, p.Size.Y, p.Size.Z)
				end
			end
		end
		for k = 0, n do
			kit("F4Post", parent, CFrame.new(x0 + k * seg, y - 0.02, z), H)
		end
	end
	local function railZ(parent: Instance, z0: number, z1: number, x: number, y: number, H: Half?)
		local n = math.max(1, math.ceil((z1 - z0) / 4 - 0.01))
		local seg = (z1 - z0) / n
		for k = 0, n - 1 do
			local m = kit("F4Rail4", parent, CFrame.new(x, y, z0 + (k + 0.5) * seg) * yaw(90), H)
			for _, p in m:GetChildren() do
				if p:IsA("BasePart") then
					p.Size = V(seg + 0.02, p.Size.Y, p.Size.Z)
				end
			end
		end
		for k = 0, n do
			kit("F4Post", parent, CFrame.new(x, y - 0.02, z0 + k * seg), H)
		end
	end
	-- a square steel column with a base plate and a cap (one design for every post in the map)
	local function column(
		parent: Instance,
		x: number,
		z: number,
		y0: number,
		y1: number,
		w: number,
		lk: Look,
		H: Half?
	)
		box(parent, "Column", V(x - w / 2, y0, z - w / 2), V(x + w / 2, y1, z + w / 2), lk, true, H)
		box(
			parent,
			"BasePlate",
			V(x - w / 2 - 0.35, y0 - 0.05, z - w / 2 - 0.35),
			V(x + w / 2 + 0.35, y0 + 0.3, z + w / 2 + 0.35),
			L.steelDark,
			false,
			H
		)
	end
	-- the slab pile (one design, owner 2026-11-21: "still don't look professional"): the kit's F4SlabPile2 (low cover,
	-- 3.22) or F4SlabPile6 (8.02): concrete footings, steel cradles, identical chamfered slabs with painted ends,
	-- timber spacers on the cradle lines
	local function slabPile(
		parent: Instance,
		x: number,
		z: number,
		tall: boolean,
		H: Half?,
		rot: number?
	)
		local T = CFrame.new(x, 0, z) * yaw(rot or 0)
		kit(if tall then "F4SlabPile6" else "F4SlabPile2", parent, T, H)
		col("Slab pile", V(-4.0, 0, -2.15), V(4.0, if tall then 8.02 else 3.22, 2.15), H, T)
	end
	-- the skip (one design): a steel bin 9.6 x 4.8 on two skids, an enclosing top rim, evenly spaced ribs that stop
	-- under the rim, lifting lugs at the ends, a level fill of scrap plates inside the rim
	local function skipBin(parent: Instance, x: number, z: number, H: Half?, rot: number?)
		local T = CFrame.new(x, 0, z) * yaw(rot or 0)
		for _, sz in { -1, 1 } do
			box(
				parent,
				"Skid",
				V(-4.6, -0.02, sz * 1.5),
				V(4.6, 0.4, sz * 2.1),
				L.steelDark,
				false,
				H,
				T
			)
		end
		box(parent, "Skip body", V(-4.8, 0.38, -2.4), V(4.8, 3.0, 2.4), L.rust, false, H, T)
		for _, sz in { -1, 1 } do
			box(
				parent,
				"Skip rim",
				V(-5.0, 2.95, sz * 2.3),
				V(5.0, 3.3, sz * 2.6),
				L.steelDark,
				false,
				H,
				T
			)
			for _, rx in { -3.6, -1.2, 1.2, 3.6 } do
				box(
					parent,
					"Skip rib",
					V(rx - 0.15, 0.4, sz * 2.38),
					V(rx + 0.15, 2.97, sz * 2.55),
					L.rust,
					false,
					H,
					T
				)
			end
		end
		for _, sx in { -1, 1 } do
			box(
				parent,
				"Skip rim",
				V(sx * 4.7, 2.94, -2.32),
				V(sx * 5.0, 3.28, 2.32),
				L.steelDark,
				false,
				H,
				T
			)
			box(
				parent,
				"Skip lug",
				V(sx * 4.78, 1.8, -0.55),
				V(sx * 5.3, 2.6, 0.55),
				L.steelDark,
				false,
				H,
				T
			)
		end
		box(
			parent,
			"Skip fill",
			V(-4.72, 2.4, -2.32),
			V(4.72, 2.72, 2.32),
			L.steelDark,
			false,
			H,
			T
		)
		box(
			parent,
			"Scrap plate",
			V(-4.2, 2.66, -1.9),
			V(-0.2, 2.98, 0.4),
			L.steelLight,
			false,
			H,
			T
		)
		box(parent, "Scrap plate", V(0.4, 2.64, -0.6), V(4.1, 3.06, 1.8), L.steel, false, H, T)
		col("Skip", V(-5.0, 0, -2.6), V(5.0, 3.3, 2.6), H, T)
	end
	-- a coil stack (one design): two coils side by side along their axis (X), two bottom rows + one on top,
	-- on timber chocks; footprint 5.4 (X) x 9.8 (Z), 8.9 tall
	local function coilStack(parent: Instance, x: number, z: number, H: Half?, rot: number?)
		local T = CFrame.new(x, 0, z) * yaw(rot or 0)
		for _, cx in { -1.33, 1.33 } do
			for _, cz in { -2.45, 2.45 } do
				kit("F4Coil", parent, T * CFrame.new(cx, 0.3, cz), H)
				box(
					parent,
					"Chock",
					V(cx - 1.2, -0.02, cz - 2.4),
					V(cx + 1.2, 0.34, cz + 2.4),
					L.wood,
					false,
					H,
					T
				)
			end
			kit("F4Coil", parent, T * CFrame.new(cx, 0.3 + 4.15, 0), H)
		end
		col("Coil stack", V(-2.7, 0, -4.9), V(2.7, 8.9, 4.9), H, T)
	end
	-- a mast lamp (one design for the yard): square post, a bracket arm, a box head with a warm lens
	local function mastLamp(parent: Instance, x: number, z: number, armDir: number, H: Half?)
		column(parent, x, z, 0, 14, 0.6, L.steelDark, H)
		local T = CFrame.new(x, 0, z) * yaw(armDir)
		box(parent, "LampArm", V(-0.2, 13.4, -0.2), V(0.2, 13.8, -3.2), L.steelDark, false, H, T)
		box(parent, "LampHead", V(-1.0, 12.9, -4.4), V(1.0, 13.9, -2.4), L.steelDark, false, H, T)
		box(parent, "LampHood", V(-1.15, 13.85, -4.55), V(1.15, 14.15, -2.25), L.steel, false, H, T)
		box(parent, "LampLens", V(-0.8, 12.82, -4.2), V(0.8, 12.92, -2.6), L.lens, false, H, T)
		local pos = (T * CFrame.new(0, 12.3, -3.4)).Position
		lightAt(secLights, "YardLamp", pos, H, "spot", 30, 0.8, Color3.fromRGB(255, 200, 140))
	end
	-- a hall pendant lamp (one design): drop rod, housing, skirt, lens, spot light down
	local function pendant(parent: Instance, x: number, z: number, H: Half?)
		box(
			parent,
			"PendantRod",
			V(x - 0.12, 25.6, z - 0.12),
			V(x + 0.12, 28.6, z + 0.12),
			L.steelDark,
			false,
			H
		)
		box(
			parent,
			"PendantHousing",
			V(x - 0.8, 24.6, z - 0.8),
			V(x + 0.8, 25.7, z + 0.8),
			L.steelDark,
			false,
			H
		)
		box(
			parent,
			"PendantSkirt",
			V(x - 1.4, 24.1, z - 1.4),
			V(x + 1.4, 24.65, z + 1.4),
			L.steel,
			false,
			H
		)
		box(
			parent,
			"PendantLens",
			V(x - 1.15, 24.02, z - 1.15),
			V(x + 1.15, 24.12, z + 1.15),
			L.lens,
			false,
			H
		)
		lightAt(
			secLights,
			"HallLamp",
			V(x, 23.6, z),
			H,
			"spot",
			26,
			0.55,
			Color3.fromRGB(255, 196, 140)
		)
	end

	--------------------------------------------------------------------------------------------- ground
	-- Thick slabs (y -16..0) so the floor reaches down; the runner trench (x -46.6..44, z -4..4) and the pour pit
	-- (x 44..50) are holes, floored at -16..-14.
	box(secGround, "Ground W", V(-75, -16, -4), V(-46.6, 0, 4), L.concrete, true)
	box(secGround, "Ground E", V(50, -16, -4), V(75, 0, 4), L.concrete, true)
	box(secGround, "Trench floor", V(-46.6, -16, -4.05), V(50, -14, 4.05), L.refractory, true)
	for _, H in halves do
		box(secGround, "Cast floor", V(-48, -16, 4), V(48, 0, 31.6), L.castFloor, true, H)
		box(secGround, "Ground W", V(-75, -16, 4), V(-48, 0, 31.6), L.concrete, true, H)
		box(secGround, "Ground E", V(48, -16, 4), V(75, 0, 31.6), L.concrete, true, H)
		box(secGround, "Yard", V(-75, -16, 31.6), V(75, 0, 96), L.yard, true, H)
	end

	--------------------------------------------------------------------------------------------- the runner
	-- lining (refractory) on the trench walls, kerbs (0.6 lip, walkable) except at the bridges, the glowing surface
	-- (no collision: the kill zone), cooled crust floating on it, the pour into the pit, glow lights
	local BRIDGES = { { -28, -20 }, { 14, 22 } }
	for _, s in { -1, 1 } do
		box(
			secRunner,
			"Lining",
			V(-46.6, -14.05, s * 3.55),
			V(50, -0.25, s * 4.05),
			L.refractory,
			true
		)
		box(
			secRunner,
			"Pit lining",
			V(44, -14.05, s * 3.5),
			V(50, -0.3, s * 3.56),
			L.refractory,
			true
		)
		local x = -46.5
		for _, br in BRIDGES do
			box(secRunner, "Kerb", V(x, -0.4, s * 3.5), V(br[1], 0.6, s * 5.3), L.refractory, true)
			x = br[2]
		end
		box(secRunner, "Kerb", V(x, -0.4, s * 3.5), V(44, 0.6, s * 5.3), L.refractory, true)
		-- the pit's kerb steps up a little (it carries the ladle side)
		box(
			secRunner,
			"Pit kerb",
			V(43.98, -0.4, s * 3.45),
			V(50.4, 0.9, s * 5.35),
			L.steelDark,
			true
		)
		-- painted safety lines along the edges
		box(
			secRunner,
			"Edge line",
			V(-45.5, -0.05, s * 6.0),
			V(50, 0.06, s * 6.35),
			L.paintY,
			false
		)
	end
	box(secRunner, "Pit end", V(49.95, -14.05, -4.05), V(50.45, -0.3, 4.05), L.refractory, true)
	box(secRunner, "Pit kerb end", V(50.35, -0.4, -5.4), V(51.2, 0.95, 5.4), L.steelDark, true)
	local surf = box(secRunner, "Molten", V(-46.4, -1.3, -3.6), V(44.2, -1.0, 3.6), L.molten, false)
	surf.CastShadow = false
	box(secRunner, "Molten pit", V(44.1, -3.8, -3.55), V(49.98, -3.5, 3.55), L.molten, false)
	box(secRunner, "Pour", V(43.9, -3.6, -2.2), V(44.25, -0.96, 2.2), L.moltenHot, false)
	box(secRunner, "Pour lip", V(43.6, -1.05, -2.4), V(44.3, -0.6, 2.4), L.refractory, false)
	-- the hot core of the stream (a brighter band down the middle)
	box(secRunner, "Molten core", V(-46.3, -0.99, -1.1), V(43.9, -0.94, 1.1), L.moltenHot, false)
	for k = 0, 13 do
		local x = -42 + k * 6.3 + rng:NextNumber(-1.2, 1.2)
		local w = rng:NextNumber(1.2, 2.6)
		local zc = (if k % 2 == 0 then 1 else -1) * rng:NextNumber(1.4, 2.4)
		local p = box(
			secRunner,
			"Crust",
			V(-w, -0.96, -0.6),
			V(w, -0.88, 0.6),
			L.crust,
			false,
			nil,
			CFrame.new(x, 0, zc) * yaw(rng:NextNumber(-25, 25))
		)
		p.CastShadow = false
	end
	for k = 0, 6 do
		lightAt(
			secLights,
			"RunnerGlow",
			V(-42 + k * 14, 1.0, 0),
			nil,
			"point",
			13,
			0.9,
			Color3.fromRGB(255, 112, 44)
		)
	end
	lightAt(
		secLights,
		"PitGlow",
		V(47, 0.5, 0),
		nil,
		"point",
		14,
		1.0,
		Color3.fromRGB(255, 130, 50)
	)
	-- plate bridges (top 0.3, girders under, low rails along both sides)
	for _, br in BRIDGES do
		local a, b = br[1], br[2]
		box(secRunner, "Bridge plate", V(a, -0.1, -5.6), V(b, 0.3, 5.6), L.plate, true)
		for _, gx in { a + 1.0, b - 1.0 } do
			box(
				secRunner,
				"Bridge girder",
				V(gx - 0.35, -1.6, -4.6),
				V(gx + 0.35, -0.08, 4.6),
				L.steelDark,
				false
			)
		end
		box(
			secRunner,
			"Bridge edge",
			V(a - 0.12, -0.6, -5.65),
			V(a + 0.2, 0.42, 5.65),
			L.yellow,
			false
		)
		box(
			secRunner,
			"Bridge edge",
			V(b - 0.2, -0.6, -5.65),
			V(b + 0.12, 0.42, 5.65),
			L.yellow,
			false
		)
		railZ(secRunner, -4.6, 4.6, a + 0.35, 0.3, nil)
		railZ(secRunner, -4.6, 4.6, b - 0.35, 0.3, nil)
	end
	-- the skimmer gate at x 5: legs outside the kerbs, a yellow beam, the skimmer plate dipping into the runner
	for _, s in { -1, 1 } do
		box(secRunner, "Skimmer leg", V(4.0, 0, s * 5.4), V(6.0, 9.2, s * 7.0), L.steelDark, true)
		box(secRunner, "Skimmer foot", V(3.6, -0.05, s * 5.0), V(6.4, 0.5, s * 7.4), L.steel, false)
		box(
			secRunner,
			"Skimmer collar",
			V(3.92, 0.45, s * 5.32),
			V(6.08, 1.55, s * 7.08),
			L.yellow,
			false
		)
	end
	box(secRunner, "Skimmer beam", V(3.8, 9.1, -7.2), V(6.2, 10.4, 7.2), L.yellow, true)
	box(secRunner, "Skimmer plate", V(4.75, -1.6, -3.3), V(5.25, 1.3, 3.3), L.steelDark, false)
	box(secRunner, "Skimmer frame", V(4.6, 1.25, -3.5), V(5.4, 1.9, 3.5), L.steel, false)
	for _, zr in { -2.4, 2.4 } do
		box(
			secRunner,
			"Skimmer rod",
			V(4.85, 1.85, zr - 0.15),
			V(5.15, 9.15, zr + 0.15),
			L.steelDark,
			false
		)
	end
	box(secRunner, "Counterweight", V(4.2, 10.35, -1.2), V(5.8, 11.8, 1.2), L.steelDark, false)
	blocker("Skimmer guard", V(3.8, 10.4, -7.2), V(6.2, 20, 7.2), nil)

	--------------------------------------------------------------------------------------------- the furnace
	kit("F4Furnace", secFurnace, CFrame.new(-58, 0, 0), nil)
	col("Furnace", V(-68.2, 0, -10.2), V(-47.8, 46, 10.2), nil)
	col("Furnace", V(-10.2, 0, -10.2), V(10.2, 46, 10.2), nil, CFrame.new(-58, 0, 0) * yaw(45))
	col("Tap block", V(-49, 0, -2.4), V(-44.2, 4.4, 2.4), nil)
	for _, H in halves do
		for _, x in { -59.7, -56.3 } do
			col("Trestle leg", V(x - 0.36, 0, 35.6), V(x + 0.36, 22.5, 36.4), H)
		end
	end
	-- the cast house behind the furnace (x -75..-66.5): clad shed on a concrete plinth, roof, a lit door
	box(secFurnace, "Cast house", V(-75, 0, -16), V(-66.5, 19, 16), L.renderDark, true)
	box(
		secFurnace,
		"Cast house plinth",
		V(-75.2, -0.05, -16.3),
		V(-66.2, 3.0, 16.3),
		L.render,
		false
	)
	box(secFurnace, "Cast house roof", V(-75.4, 18.95, -16.5), V(-65.9, 20.0, 16.5), L.roof, false)
	box(
		secFurnace,
		"Cast house fascia",
		V(-66.15, 18.3, -16.6),
		V(-65.7, 20.1, 16.6),
		L.steelDark,
		false
	)
	cladRunZ(
		secFurnace,
		-16,
		16,
		3,
		2,
		-66.5,
		1,
		CLAD.castHouse,
		nil,
		function(zc: number, _yb: number): boolean
			return math.abs(zc) < 12
		end
	)
	for _, H in halves do
		cladRun(secFurnace, -75, -69, 3, 2, 16, 1, CLAD.castHouse, H)
		cladRun(secFurnace, -69, -66.5, 3, 0, 16, 1, CLAD.castHouse, H)
		box(
			secFurnace,
			"Cast house side",
			V(-69.05, 3, 15.95),
			V(-66.55, 18.9, 16.3),
			L.renderDark,
			false,
			H
		)
	end
	blocker("Roof guard", V(-75, 20, -16.6), V(-65.7, 40, 16.6), nil)

	--------------------------------------------------------------------------------------------- the crane and walkway
	kit("F4Crane", secHall, CFrame.new(6, 21.65, 0), nil)
	box(secHall, "Walkway deck", V(0, 11.4, -23.45), V(4, 12, 23.45), L.plate, true)
	for _, x in { -0.1, 3.7 } do
		box(
			secHall,
			"Walkway stringer",
			V(x, 10.6, -23.4),
			V(x + 0.4, 11.45, 23.4),
			L.yellow,
			false
		)
	end
	railZ(secHall, -23.4, 23.4, 0.25, 12, nil)
	railZ(secHall, -23.4, 23.4, 3.75, 12, nil)
	blocker("Crane guard", V(1, 21.4, -30.5), V(11, 40, 30.5), nil)

	--------------------------------------------------------------------------------------------- ladle track, ladle car
	for _, rx in { 55.4, 60.6 } do
		box(secYard, "Ladle rail", V(rx - 0.25, -0.05, -40), V(rx + 0.25, 0.28, 40), L.rail, false)
	end
	for k = 0, 26 do
		local z = -39 + k * 3
		box(secYard, "Sleeper", V(53.6, -0.06, z - 0.5), V(62.4, 0.08, z + 0.5), L.sleeper, false)
	end
	for _, s in { -1, 1 } do
		box(secYard, "Track stop", V(54.4, 0, s * 40), V(61.6, 2.4, s * 41.2), L.yellow, true)
		box(
			secYard,
			"Track stop plate",
			V(54.2, 1.6, s * 39.9),
			V(61.8, 2.6, s * 40.05),
			L.black,
			false
		)
	end
	kit("F4LadleCar", secYard, CFrame.new(58, 0.28, 0), nil)
	local ladle = kit("F4Ladle", secYard, CFrame.new(58, 3.23, 0) * yaw(180), nil)
	col("Ladle car", V(53.5, 0, -8.0), V(62.5, 3.2, 8.0), nil)
	col("Ladle", V(52.6, 3.2, -6.2), V(63.4, 11.35, 6.2), nil)
	blocker("Ladle guard", V(52.6, 11.35, -8.0), V(63.4, 30, 8.0), nil)
	lightAt(
		secLights,
		"LadleGlow",
		V(58, 14, 0),
		nil,
		"point",
		12,
		0.8,
		Color3.fromRGB(255, 140, 60)
	)
	local _ = ladle

	--------------------------------------------------------------------------------------------- the halves
	for _, H in halves do
		local side = H.side
		------------------------------------------------------------------ melt shop: wall, columns, catwalk, stairs
		local DOORS = { { -36, -24 }, { 0, 12 }, { 24, 36 } }
		local WALLS = { { -48, -36 }, { -24, 0 }, { 12, 24 }, { 36, 48 } }
		local function inDoor(x: number): boolean
			for _, d in DOORS do
				if x > d[1] and x < d[2] then
					return true
				end
			end
			return false
		end
		-- wall core: lower segments to 14.05, the band above 14 continuous
		for _, w in WALLS do
			box(
				secHall,
				"Wall",
				V(w[1] + 0.03, 0, 31.5),
				V(w[2] - 0.03, 14.05, 32.5),
				L.steelDark,
				true,
				H
			)
			box(secHall, "Plinth", V(w[1], -0.05, 31.1), V(w[2], 6.0, 32.9), L.render, true, H)
			box(
				secHall,
				"Plinth trim",
				V(w[1] - 0.05, 5.9, 30.95),
				V(w[2] + 0.05, 6.35, 33.05),
				L.steelDark,
				false,
				H
			)
		end
		box(secHall, "Wall band", V(-48, 14, 31.45), V(48, 30, 32.55), L.steelDark, true, H)
		cladRun(
			secHall,
			-48,
			48,
			6,
			3,
			32.5,
			1,
			CLAD.hall,
			H,
			function(xc: number, yb: number): boolean
				return yb < 14 and inDoor(xc)
			end
		)
		cladRun(
			secHall,
			-48,
			48,
			6,
			3,
			31.5,
			-1,
			CLAD.hall,
			H,
			function(xc: number, yb: number): boolean
				return yb < 14 and inDoor(xc)
			end
		)
		box(
			secHall,
			"Eave fascia",
			V(-48.4, 29.8, 30.85),
			V(48.4, 31.1, 33.15),
			L.steelDark,
			false,
			H
		)
		for _, d in DOORS do
			box(secHall, "Lintel", V(d[1], 13.6, 30.95), V(d[2], 14.45, 33.05), L.yellow, false, H)
			-- the door threshold: a steel plate flush with the floors across the wall line
			box(
				secHall,
				"Threshold",
				V(d[1] + 0.05, -0.1, 31.0),
				V(d[2] - 0.05, 0.07, 33.0),
				L.plate,
				false,
				H
			)
		end
		-- portal columns (inside, against the wall) every 12, runway brackets and the crane runway beam
		for k = 0, 8 do
			local x = -48 + k * 12
			box(
				secHall,
				"Portal column",
				V(x - 0.7, 0, 29.9),
				V(x + 0.7, 30.05, 31.45),
				L.steel,
				true,
				H
			)
			box(
				secHall,
				"Column base",
				V(x - 1.05, -0.05, 29.55),
				V(x + 1.05, 0.35, 31.5),
				L.steelDark,
				false,
				H
			)
			box(
				secHall,
				"Column collar",
				V(x - 0.78, 0.3, 29.82),
				V(x + 0.78, 1.4, 31.46),
				L.yellow,
				false,
				H
			)
			box(
				secHall,
				"Runway bracket",
				V(x - 0.55, 19.4, 28.2),
				V(x + 0.55, 20.25, 29.95),
				L.steel,
				false,
				H
			)
		end
		box(secHall, "Runway beam", V(-48, 20.2, 28.35), V(48, 21.4, 29.65), L.steelDark, false, H)
		box(secHall, "Crane rail", V(-48, 21.38, 28.75), V(48, 21.66, 29.25), L.rail, false, H)
		-- catwalk (+12) x -41..25, z 23.5..31.2: plate deck, edge channel, posts with knee braces, railing
		box(secHall, "Catwalk deck", V(-41, 11.4, 23.5), V(25, 12, 31.2), L.plate, true, H)
		box(
			secHall,
			"Catwalk edge",
			V(-41.05, 10.5, 23.4),
			V(25.05, 11.45, 23.9),
			L.yellow,
			false,
			H
		)
		for _, x in { -36, -24, -12, 12, 24 } do
			column(secHall, x, 24.2, 0, 11.42, 0.8, L.steel, H)
			box(
				secHall,
				"Catwalk joist",
				V(x - 0.3, 10.6, 23.9),
				V(x + 0.3, 11.42, 29.9),
				L.steelDark,
				false,
				H
			)
		end
		railX(secHall, -41, -0.35, 23.7, 12, H)
		railX(secHall, 4.35, 25, 23.7, 12, H)
		-- stairs: west (x -61..-41) rising east, east (x 25..45) rising west; tilted plate colliders
		kit("F4Stair12", secHall, CFrame.new(-51, 0, 26) * yaw(-90), H)
		kit("F4Stair12", secHall, CFrame.new(35, 0, 26) * yaw(90), H)
		local slope = math.atan2(12, 20)
		local len = math.sqrt(12 * 12 + 20 * 20)
		col(
			"Stair",
			V(-len / 2, -0.5, -2.0),
			V(len / 2, 0, 2.0),
			H,
			CFrame.new(-51, 6, 26) * CFrame.Angles(0, 0, slope)
		)
		col(
			"Stair",
			V(-len / 2, -0.5, -2.0),
			V(len / 2, 0, 2.0),
			H,
			CFrame.new(35, 6, 26) * CFrame.Angles(0, 0, -slope)
		)
		box(
			secHall,
			"Stair landing W",
			V(-62.2, -0.05, 23.6),
			V(-60.6, 0.3, 28.4),
			L.plate,
			false,
			H
		)
		box(secHall, "Stair landing E", V(44.6, -0.05, 23.6), V(46.2, 0.3, 28.4), L.plate, false, H)
		-- pendant lamps
		for _, x in { -36, -12, 12, 36 } do
			pendant(secLights, x, 14, H)
		end
		------------------------------------------------------------------ the roof (this half), trusses and monitor
		box(secHall, "Roof", V(-48.5, 30.6, 0), V(48.5, 31.3, 33.3), L.roof, false, H)
		box(
			secHall,
			"Roof underside",
			V(-48.45, 30.3, 0.05),
			V(48.45, 30.62, 31.45),
			L.roofUnder,
			false,
			H
		)
		box(secHall, "Roof edge", V(-48.6, 30.9, 33.2), V(48.6, 31.6, 33.5), L.steelDark, false, H)
		for k = 0, 8 do
			local x = -48 + k * 12
			box(
				secHall,
				"Truss chord",
				V(x - 0.45, 28.2, 0.1),
				V(x + 0.45, 28.9, 29.9),
				L.steelDark,
				false,
				H
			)
			for kk = 0, 4 do
				local z = 3 + kk * 6
				box(
					secHall,
					"Truss strut",
					V(x - 0.2, 28.85, z - 0.2),
					V(x + 0.2, 30.35, z + 0.2),
					L.steelDark,
					false,
					H
				)
			end
		end
		for kk = 0, 4 do
			local z = 4 + kk * 6
			box(
				secHall,
				"Purlin",
				V(-48.4, 29.7, z - 0.25),
				V(48.4, 30.32, z + 0.25),
				L.steel,
				false,
				H
			)
		end
		box(secHall, "Monitor wall", V(-42, 31.2, 5.9), V(42, 35.2, 6.3), L.steelDark, false, H)
		box(secHall, "Monitor glass", V(-41.6, 31.6, 6.25), V(41.6, 34.4, 6.4), L.window, false, H)
		box(secHall, "Monitor roof", V(-42.5, 35.1, 0), V(42.5, 35.7, 7.0), L.roof, false, H)
		blocker("Roof guard", V(-48.6, 31.3, 0), V(48.6, 45, 33.5), H)

		------------------------------------------------------------------ cast floor cover
		slabPile(secHall, -20, 15, false, H)
		-- the ingot cart on its spur (rails along X at z 14 / 18)
		for _, rz in { 14.0, 18.0 } do
			box(
				secHall,
				"Spur rail",
				V(-10, -0.05, rz - 0.22),
				V(14, 0.26, rz + 0.22),
				L.rail,
				false,
				H
			)
		end
		for k = 0, 7 do
			local x = -9 + k * 3.2
			box(
				secHall,
				"Sleeper",
				V(x - 0.45, -0.06, 12.9),
				V(x + 0.45, 0.08, 19.1),
				L.sleeper,
				false,
				H
			)
		end
		kit("F4IngotCart", secHall, CFrame.new(2, 0.26, 16) * yaw(90), H)
		col("Ingot cart", V(-4.6, 0, 13.5), V(8.6, 8.1, 18.5), H)
		blocker("Ingot guard", V(-4.6, 8.1, 13.5), V(8.6, 20, 18.5), H)
		coilStack(secHall, 30, 15, H)
		-- painted walk lines along the wall
		box(secHall, "Wall line", V(-47, -0.05, 22.0), V(47, 0.06, 22.3), L.paintW, false, H)

		------------------------------------------------------------------ the yard
		-- the hot blast stove (its main comes from the furnace kit) and its valve house
		kit("F4Stove", secYard, CFrame.new(-58, 0, 48.2), H)
		col("Stove", V(-63.8, 0, 42.4), V(-52.2, 38, 54.0), H)
		col("Stove", V(-5.8, 0, -5.8), V(5.8, 38, 5.8), H, CFrame.new(-58, 0, 48.2) * yaw(45))
		box(secYard, "Valve house", V(-66.5, 0, 54.6), V(-57.5, 9, 61.6), L.render, true, H)
		box(secYard, "Valve house roof", V(-66.9, 8.9, 54.3), V(-57.1, 9.7, 61.9), L.roof, false, H)
		box(
			secYard,
			"Valve house door",
			V(-63.4, 0, 61.55),
			V(-60.6, 6.4, 61.75),
			look(side.team),
			false,
			H
		)
		box(
			secYard,
			"Valve house plinth",
			V(-66.7, -0.05, 54.4),
			V(-57.3, 1.0, 61.8),
			L.renderDark,
			false,
			H
		)
		box(
			secYard,
			"Valve house band",
			V(-66.65, 7.4, 54.45),
			V(-57.35, 8.95, 61.75),
			L.steelDark,
			false,
			H
		)
		box(
			secYard,
			"Valve house vent",
			V(-57.45, 3.2, 56.0),
			V(-57.3, 5.6, 58.6),
			L.steelDark,
			false,
			H
		)
		for k = 0, 3 do
			box(
				secYard,
				"Vent slat",
				V(-57.36, 3.45 + k * 0.55, 56.15),
				V(-57.2, 3.7 + k * 0.55, 58.45),
				L.steel,
				false,
				H
			)
		end
		blocker("Roof guard", V(-66.9, 9.7, 54.3), V(-57.1, 30, 61.9), H)
		-- skip, coil stacks, slab piles
		skipBin(secYard, -36, 46, H)
		slabPile(secYard, -26, 60, true, H, 90)
		coilStack(secYard, -6, 48, H, 90)
		coilStack(secYard, 20, 54, H)
		slabPile(secYard, 50, 60, false, H)
		-- the spare ladle on its stand (east flank)
		local LS = CFrame.new(66, 0, 46)
		for _, dx in { -4.2, 4.2 } do
			for _, dz in { -4.2, 4.2 } do
				box(
					secYard,
					"Stand leg",
					V(dx - 0.5, -0.02, dz - 0.5),
					V(dx + 0.5, 4.4, dz + 0.5),
					L.yellow,
					false,
					H,
					LS
				)
				box(
					secYard,
					"Stand foot",
					V(dx - 0.75, -0.03, dz - 0.75),
					V(dx + 0.75, 0.3, dz + 0.75),
					L.steelDark,
					false,
					H,
					LS
				)
			end
			box(
				secYard,
				"Stand beam",
				V(dx - 0.4, 4.3, -4.6),
				V(dx + 0.4, 5.1, 4.6),
				L.steelDark,
				false,
				H,
				LS
			)
		end
		for _, dz in { -3.4, 3.4 } do
			box(
				secYard,
				"Stand rail",
				V(-4.5, 5.05, dz - 0.4),
				V(4.5, 5.5, dz + 0.4),
				L.steel,
				false,
				H,
				LS
			)
		end
		kit("F4Ladle", secYard, LS * CFrame.new(0, 5.48, 0) * yaw(90), H)
		col("Ladle stand", V(-5.5, 0, -5.5), V(5.5, 13.6, 5.5), H, LS)
		blocker("Ladle guard", V(-5.8, 13.6, -5.8), V(5.8, 30, 5.8), H, LS)
		-- the shunting loco on its spur (team colour)
		for _, rx in { 33.4, 38.6 } do
			box(
				secYard,
				"Spur rail",
				V(rx - 0.25, -0.05, 58),
				V(rx + 0.25, 0.28, 92),
				L.rail,
				false,
				H
			)
		end
		for k = 0, 11 do
			local z = 59 + k * 3
			box(
				secYard,
				"Sleeper",
				V(31.6, -0.06, z - 0.5),
				V(40.4, 0.08, z + 0.5),
				L.sleeper,
				false,
				H
			)
		end
		box(secYard, "Buffer stop", V(32.4, 0, 92), V(39.6, 2.6, 93.4), L.yellow, true, H)
		box(secYard, "Buffer plate", V(32.2, 1.7, 91.85), V(39.8, 2.7, 92.05), L.black, false, H)
		local loco = kit("F4Loco", secYard, CFrame.new(36, 0.28, 74) * yaw(180), H)
		recolor(loco, "F4_Paint", side.team)
		col("Loco frame", V(32.7, 0, 66.2), V(39.3, 2.6, 81.8), H)
		col("Loco hood", V(33.6, 2.6, 66.7), V(38.4, 7.3, 76.6), H)
		col("Loco cab", V(32.9, 2.6, 76.6), V(39.1, 10.7, 81.6), H)
		blocker("Loco guard", V(32.5, 7.3, 66.0), V(39.5, 30, 82.0), H)
		-- the pump house (spawn baffle, x -11..11, z 68..76): plinth, clad walls, roof, a team door, the water tank
		box(secYard, "Pump house", V(-11, 0, 68), V(11, 12, 76), L.steelDark, true, H)
		box(
			secYard,
			"Pump plinth",
			V(-11.35, -0.05, 67.65),
			V(11.35, 2.0, 76.35),
			L.render,
			false,
			H
		)
		box(
			secYard,
			"Pump plinth trim",
			V(-11.4, 1.9, 67.6),
			V(11.4, 2.3, 76.4),
			L.steelDark,
			false,
			H
		)
		cladRun(
			secYard,
			-9,
			9,
			2.1,
			1,
			76,
			1,
			CLAD.pump,
			H,
			function(xc: number, _yb: number): boolean
				return math.abs(xc) < 3.1
			end
		)
		cladRun(secYard, -9, 9, 2.1, 1, 68, -1, CLAD.pump, H)
		cladRunZ(secYard, 69, 75, 2.1, 1, 11, 1, CLAD.pump, H)
		cladRunZ(secYard, 69, 75, 2.1, 1, -11, -1, CLAD.pump, H)
		-- L-shaped steel corner pilasters cover the clad ends on both faces
		for _, sx in { -1, 1 } do
			for _, zz in { { 75.56, 76.44, 74.95 }, { 67.56, 68.44, 69.05 } } do
				local zLo, zHi = math.min(zz[1], zz[3]), math.max(zz[2], zz[3])
				box(
					secYard,
					"Pump corner",
					V(sx * 8.95, -0.05, zz[1]),
					V(sx * 11.45, 10.4, zz[2]),
					L.steel,
					false,
					H
				)
				box(
					secYard,
					"Pump corner",
					V(sx * 10.55, -0.04, zLo - 0.02),
					V(sx * 11.48, 10.35, zHi + 0.02),
					L.steel,
					false,
					H
				)
			end
		end
		box(secYard, "Pump band", V(-11.5, 10.1, 67.5), V(11.5, 12.3, 76.5), L.steel, false, H)
		box(secYard, "Pump roof", V(-11.8, 12.2, 67.2), V(11.8, 12.9, 76.8), L.roof, false, H)
		box(
			secYard,
			"Pump door frame",
			V(-3.06, 0, 76.0),
			V(3.06, 7.6, 76.42),
			L.steelDark,
			false,
			H
		)
		box(
			secYard,
			"Pump door header",
			V(-3.04, 7.55, 75.98),
			V(3.04, 10.15, 76.2),
			L.render,
			false,
			H
		)
		box(
			secYard,
			"Pump door",
			V(-2.4, 0.05, 76.38),
			V(2.4, 7.1, 76.55),
			look(side.team),
			false,
			H
		)
		box(
			secYard,
			"Pump door band",
			V(-2.4, 3.4, 76.52),
			V(2.4, 3.8, 76.62),
			L.steelDark,
			false,
			H
		)
		box(secYard, "Pump lamp", V(-0.7, 8.0, 76.12), V(0.7, 8.6, 77.2), L.steelDark, false, H)
		box(
			secYard,
			"Pump lamp lens",
			V(-0.55, 7.92, 76.55),
			V(0.55, 8.02, 77.05),
			L.lens,
			false,
			H
		)
		lightAt(
			secLights,
			"DoorLamp",
			V(0, 7.5, 77.2),
			H,
			"spot",
			16,
			0.6,
			Color3.fromRGB(255, 200, 140)
		)
		rivals("R_WaterTank", secYard, CFrame.new(0, 12.85, 72), H, 0.95)
		blocker("Roof guard", V(-11.8, 12.9, 67.2), V(11.8, 30, 76.8), H)
		-- gas cylinders, drums, the jersey barrier and cones
		-- the gas cage (owner 2026-11-21): a plinth, four posts, three rail levels on all four sides; each rail runs
		-- between the posts' inner faces and buries 0.05 into them; the kit's cylinders stand on the plinth
		local GC = CFrame.new(-40, 0, 76)
		box(
			secYard,
			"Cage plinth",
			V(-3.3, -0.05, -3.3),
			V(3.3, 0.4, 3.3),
			L.concrete,
			false,
			H,
			GC
		)
		for _, px in { -3.0, 3.0 } do
			for _, pz in { -3.0, 3.0 } do
				box(
					secYard,
					"Cage post",
					V(px - 0.18, 0.35, pz - 0.18),
					V(px + 0.18, 9.0, pz + 0.18),
					L.yellow,
					false,
					H,
					GC
				)
			end
		end
		for _, ry in { 3.0, 6.0, 8.7 } do
			for _, sd in { -3.0, 3.0 } do
				box(
					secYard,
					"Cage rail",
					V(sd - 0.1, ry - 0.1, -2.87),
					V(sd + 0.1, ry + 0.1, 2.87),
					L.yellow,
					false,
					H,
					GC
				)
				box(
					secYard,
					"Cage rail",
					V(-2.87, ry - 0.12, sd - 0.1),
					V(2.87, ry + 0.12, sd + 0.1),
					L.yellow,
					false,
					H,
					GC
				)
			end
		end
		kit("F4OxyTanks", secYard, GC * CFrame.new(0, 0.4, 0), H)
		col("Gas cage", V(-3.3, 0, -3.3), V(3.3, 9, 3.3), H, GC)
		-- four drums, each a different height so no two lids share a plane
		for i, p in
			{
				{ -25.6, 77.0, 0.8 },
				{ -22.4, 77.3, 0.84 },
				{ -25.4, 80.1, 0.77 },
				{ -22.2, 79.9, 0.82 },
			}
		do
			local d = rivals("R_Barrel", secYard, CFrame.new(p[1], 0, p[2]) * yaw(i * 37), H, p[3])
			for _, bp in d:GetDescendants() do
				if bp:IsA("BasePart") then
					bp.Color = if i % 2 == 0 then hex("8E3B2E") else hex("4D6A86")
				end
			end
		end
		col("Drums", V(-26.8, 0, 75.6), V(-21.0, 3.3, 81.2), H)
		rivals("R_Roadblock", secYard, CFrame.new(58, 0, 84), H)
		col("Barrier", V(53, 0, 82.75), V(63, 4.2, 85.25), H)
		-- painted lines: walkway along the hall wall, the spawn band (team colour)
		box(secYard, "Walk line", V(-46, -0.05, 35.0), V(46, 0.06, 35.3), L.paintY, false, H)
		box(
			secYard,
			"Spawn band",
			V(-20, -0.05, 81.0),
			V(20, 0.06, 81.6),
			look(side.team),
			false,
			H
		)
		-- yard mast lamps
		mastLamp(secYard, -46, 38, 0, H)
		mastLamp(secYard, 46, 38, 0, H)
		mastLamp(secYard, -50, 90, 180, H)
		mastLamp(secYard, 50, 90, 180, H)

		------------------------------------------------------------------ the works round the bounds (this half)
		-- the back mill shed along z 96 (x -75..75): plinth, clad, high lit windows, closed roller doors, roof
		box(secWorld, "Back shed", V(-81, 0, 96.5), V(81, 26, 130), L.steelDark, true, H)
		-- plinth and trim in runs between the two roller doors (x 30 and -36, openings 12 on the cladding grid)
		local BACK_DOORS = { -36, 30 }
		local bx = -80.95
		for _, dx in BACK_DOORS do
			box(
				secWorld,
				"Back plinth",
				V(bx, -0.05, 96.1),
				V(dx - 6.45, 4.0, 97.0),
				L.render,
				false,
				H
			)
			box(
				secWorld,
				"Back plinth trim",
				V(bx - 0.1, 3.9, 95.95),
				V(dx - 6.42, 4.3, 97.05),
				L.steelDark,
				false,
				H
			)
			bx = dx + 6.45
		end
		box(secWorld, "Back plinth", V(bx, -0.05, 96.1), V(80.95, 4.0, 97.0), L.render, false, H)
		box(
			secWorld,
			"Back plinth trim",
			V(bx + 0.03, 3.9, 95.95),
			V(81.05, 4.3, 97.05),
			L.steelDark,
			false,
			H
		)
		cladRun(
			secWorld,
			-78,
			78,
			4.1,
			2,
			96.5,
			-1,
			CLAD.back,
			H,
			function(xc: number, yb: number): boolean
				return yb < 12 and (math.abs(xc - 30) < 6 or math.abs(xc + 36) < 6)
			end
		)
		box(secWorld, "Back windows", V(-76, 20.3, 96.1), V(76, 23.5, 96.3), L.window, false, H)
		box(
			secWorld,
			"Back window sill",
			V(-76.3, 19.9, 95.9),
			V(76.3, 20.35, 96.45),
			L.steelDark,
			false,
			H
		)
		box(
			secWorld,
			"Back window head",
			V(-76.3, 23.45, 95.9),
			V(76.3, 23.9, 96.45),
			L.steelDark,
			false,
			H
		)
		box(
			secWorld,
			"Back clad top",
			V(-80.9, 23.85, 96.25),
			V(80.9, 25.95, 96.6),
			look(CLAD.back),
			false,
			H
		)
		for _, dx in BACK_DOORS do
			kit("F4RollerDoor", secWorld, CFrame.new(dx, 0, 96.5), H)
		end
		box(secWorld, "Back roof", V(-81.5, 25.9, 96.1), V(81.5, 26.8, 130.4), L.roof, false, H)
		kit("F4Chimney", secWorld, CFrame.new(42, 26, 116), H)
		kit("F4Chimney", secWorld, CFrame.new(-52, 26, 120), H, 1.15)
		-- the east mill along x 75 (z 32..96): clad wall with columns, roof
		cladRunZ(secWorld, 32, 92, 4.1, 2, 75.5, -1, CLAD.mill, H)
		for k = 0, 5 do
			local z = 32 + k * 12
			box(
				secWorld,
				"Mill column",
				V(74.6, -0.05, z - 0.6),
				V(75.6, 24.2, z + 0.6),
				L.steel,
				false,
				H
			)
		end
		-- the west yard wall along x -75 (z 16..96): concrete wall with piers and a coping; stoves beyond
		box(secWorld, "West wall", V(-77, 0, 16), V(-75, 7, 96.5), L.render, true, H)
		box(
			secWorld,
			"West coping",
			V(-77.2, 6.9, 15.8),
			V(-74.7, 7.6, 96.6),
			L.renderDark,
			false,
			H
		)
		for k = 0, 6 do
			local z = 20 + k * 12
			box(
				secWorld,
				"West pier",
				V(-75.6, -0.05, z - 0.8),
				V(-74.6, 8.2, z + 0.8),
				L.renderDark,
				false,
				H
			)
		end
		kit("F4Stove", secWorld, CFrame.new(-96, 0, 34), H, 1.25)
		kit("F4Stove", secWorld, CFrame.new(-98, 0, 66), H, 1.25)
		kit("F4Chimney", secWorld, CFrame.new(-112, 0, 50), H, 1.3)
		box(secWorld, "Outer ground", V(-140, -16, 0), V(-75, 0, 140), L.yard, false, H)
		box(secWorld, "Outer ground", V(-75, -16, 96), V(140, 0, 140), L.yard, false, H)
		box(secWorld, "Outer ground", V(75, -16, 0), V(140, 0, 96), L.yard, false, H)
	end
	-- the east mill's middle (z -31.6..31.6) behind the ladle track, and its doors
	box(secWorld, "East mill", V(75.5, 0, -96.4), V(110, 24, 96.4), L.steelDark, true)
	for _, sz in { -1, 1 } do
		box(
			secWorld,
			"East plinth",
			V(75.1, -0.05, sz * 6.45),
			V(76.0, 3.9, sz * 96.0),
			L.render,
			false
		)
	end
	cladRunZ(
		secWorld,
		-30,
		30,
		4.1,
		2,
		75.5,
		-1,
		CLAD.mill,
		nil,
		function(zc: number, yb: number): boolean
			return yb < 12 and math.abs(zc) < 6
		end
	)
	kit("F4RollerDoor", secWorld, CFrame.new(75.5, 0, 0) * yaw(90), nil)
	box(secWorld, "Mill windows", V(75.1, 20.3, -95), V(75.55, 22.8, 95), L.window, false)
	box(secWorld, "Mill roof", V(74.8, 23.9, -96.7), V(110.4, 24.8, 96.7), L.roof, false)
	box(secWorld, "West wall", V(-77, 0, -16), V(-75.2, 3, 16), L.render, false)

	--------------------------------------------------------------------------------------------- spawns, bounds, stage
	local SPAWNS = { { -12, 88 }, { 0, 90 }, { 12, 88 }, { -6, 84 }, { 6, 84 } }
	for _, H in halves do
		for i, s in SPAWNS do
			local sp = Instance.new("SpawnLocation")
			sp.Name = "Spawn_" .. H.side.letter .. i
			sp.Size = V(4, 0.2, 4)
			sp.CFrame = ORIGIN * H.M(CFrame.new(s[1], 0.2, s[2]))
			sp.Anchored = true
			sp.Transparency = 1
			sp.CanCollide = false
			sp.CanQuery = false
			sp.CanTouch = false
			sp.Neutral = true
			sp.Enabled = false
			sp.Duration = 0
			sp:ClearAllChildren()
			CollectionService:AddTag(sp, "ArenaSpawn_" .. H.side.letter)
			sp.Parent = secSpawns
		end
	end
	local function bound(a: Vector3, b: Vector3)
		local p = box(secBounds, "Bound", a, b, L.none, true)
		p.Transparency = 1
		p.CanQuery = false
		p.CastShadow = false
	end
	bound(V(75.0, -10, -97), V(77.0, 50, 97))
	bound(V(-77.0, -10, -97), V(-75.0, 50, 97))
	bound(V(-77, -10, 96.0), V(77, 50, 98.0))
	bound(V(-77, -10, -98.0), V(77, 50, -96.0))
	bound(V(-77, 50, -98), V(77, 52, 98))
	local stage = part(map, "WinnerStage", V(4, 0.2, 4), CFrame.new(-20, 0.25, 40), L.none)
	stage.Transparency = 1
	stage.CastShadow = false
	stage.CanCollide = false
	stage.CanQuery = false
	CollectionService:AddTag(stage, "WinnerStage")

	--------------------------------------------------------------------------------------------- lighting
	local lightCfg = Instance.new("Configuration")
	lightCfg.Name = "Lighting"
	CollectionService:AddTag(lightCfg, "GGAsset_MatchMaps_424")
	CollectionService:AddTag(lightCfg, "GauntletAuthoredData")
	lightCfg.Parent = map
	local fx = folder(map, "LightingFx")
	local atm = Instance.new("Atmosphere")
	atm.Density = 0.34
	atm.Offset = 0.1
	atm.Haze = 1.6
	atm.Glare = 0
	atm.Color = Color3.fromRGB(78, 88, 118)
	atm.Decay = Color3.fromRGB(70, 56, 72)
	atm.Parent = fx
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.55
	bloom.Size = 26
	bloom.Threshold = 1.4
	bloom.Parent = fx
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "Grade"
	cc.Contrast = 0.1
	cc.Saturation = 0.12
	cc.Brightness = 0.02
	cc.TintColor = Color3.fromRGB(250, 248, 255)
	cc.Parent = fx

	-- kit glows and lenses in the map's colours (Neon brighter than these clips to yellow-white)
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") then
			if string.find(d.Name, "F4_GlowHot", 1, true) then
				d.Color = L.moltenHot.color
			elseif string.find(d.Name, "F4_Glow", 1, true) then
				d.Color = L.molten.color
			elseif string.find(d.Name, "F4_Lamp", 1, true) then
				d.Color = L.lens.color
			elseif
				string.match(d.Name, "_F4_Steel")
				or string.match(d.Name, "_F4_Pipe")
				or string.match(d.Name, "_F4_Rust")
			then
				d.Material = MET
				d.MaterialVariant = "Metal 2022"
			elseif string.match(d.Name, "_F4_Concrete") then
				d.MaterialVariant = "Concrete-01a"
			elseif string.match(d.Name, "_F4_Grate") then
				d.MaterialVariant = "Diamond Plate 2022"
			end
		end
	end

	map.Parent = workspace
	return string.format("Foundry4 built: %d parts", count)
end
