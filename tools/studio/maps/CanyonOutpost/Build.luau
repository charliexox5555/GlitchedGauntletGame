--!strict
-- CanyonOutpost (regular map, 1v1-2v2, shown as CANYON), the whole build (2026-11-21). RIVALS study, layout and build
-- log: vault/01 Design/Maps/CanyonOutpost.md. Layout rows mirror tools/maps/canyon_layout.py. Match place only, edit
-- mode. Returns a function; run it with require(<a clone>)(upTo) where upTo is the last chunk to build (default all):
--   1 the midline and the canyon frame: ground, the strata cliffs round the bounds, the mine portal, the ore track and
--     its carts, the water tower over the track, the pump houses that fill it, the world beyond, lighting;
--   2 the east: the tipple over the track's end (deck +10, ore bin, hoist), the walkways, the loading docks (+10) with
--     their stairs, crates and jib cranes, the freight wagons, the timber stacks;
--   3 each half's middle and west: the trading post (false front, porch, trough), the assay hut, the powder shed, the
--     rock shelf (+7) and its steps, the ore bin, the pit props, the west timber stack;
--   4 the spawn end: the stores shed (spawn baffle), crates, barrels, spawns, bounds, winner stage.
--
-- A sun-baked mining outpost in a red canyon, built to the RIVALS look (Westown / Museum study): plain Part masses with
-- stepped trims (corner boards, eave bands, stacked cornices), RIVALS variants on every surface (Sand_01a/b, Slate02c,
-- WoodSiding_01a, WoodPlank_01b, Wood01a/03a, Concrete-01a, Corrugated_01a, Metal 2022), a small Blender kit for the
-- hero pieces (tools/blender/maps_canyon, ServerStorage.MapKit.CanyonOutpost) and RIVALS meshes (Westown's mesas,
-- crates, trough, hitching post) in ServerStorage.MapKit.CanyonOutpostRivals. Hot palette: red rock strata,
-- warm sand, timber browns, a barn-red trading post with cream trims, an ochre assay hut, rust carts.
-- Mirror symmetry across the midline (z -> -z): the mine (west), the water tower (middle) and the tipple (east) sit
-- on the midline. A half is built once and mirrored by mir(): a piece's local X is flipped by the turn, so mirrored
-- kit pieces are X-symmetric. Railings are low and jumpable (owner 2026-11-21); blockers only on roofs.
-- Contract: Spawns (ArenaSpawn_A/B), Barriers (empty), Bounds, Lighting (authored data 425 map / 426 lighting),
-- LightingFx, WinnerStage. Joins never share a plane: touching pieces overlap or step 0.03+.

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local ServerStorage = game:GetService("ServerStorage")

local ORIGIN = CFrame.new(6000, 200, 54000) -- ground level at the map centre
local I = CFrame.identity
local V = Vector3.new

local function hex(h: string): Color3
	return Color3.fromHex(h)
end

type Look = { color: Color3, mat: Enum.Material?, variant: string?, alpha: number? }
local function look(color: Color3, variant: string?, mat: Enum.Material?, alpha: number?): Look
	return { color = color, variant = variant, mat = mat, alpha = alpha }
end
local M = Enum.Material
local L = {
	-- ground (RIVALS Westown: Sand_01a / Sand_01b sand, Slate02c canyon floor)
	sand = look(hex("C4925F"), "Sand_01b", M.Sand),
	path = look(hex("A8744C"), "Sand_01a", M.Sand),
	ballast = look(hex("8E7462"), "Slate02c", M.Slate),
	-- rock strata (Westown's rocks wear Concrete-01a in reds)
	rockDark = look(hex("8A4A32"), "Concrete-01a", M.Concrete),
	rockRed = look(hex("A75A3C"), "Concrete-01a", M.Concrete),
	rockOrange = look(hex("BC6E42"), "Concrete-01a", M.Concrete),
	rockCream = look(hex("D2A47A"), "Concrete-01a", M.Concrete),
	rockTop = look(hex("B4774E"), "Sand_01a", M.Sand),
	ledge = look(hex("AA7049"), "Slate02c", M.Slate),
	-- timber
	wood = look(hex("8C6344"), "Wood01a", M.Wood),
	woodDark = look(hex("5A3A26"), "Wood01a", M.Wood),
	woodLight = look(hex("AB795C"), "Wood01a", M.Wood),
	sleeper = look(hex("5A4632"), "Wood03a", M.Wood),
	plank = look(hex("8A6446"), "WoodPlank_01b", M.WoodPlanks),
	-- buildings
	stone = look(hex("B08A6A"), "StoneBlock_01a", M.Brick),
	stoneWall = look(hex("C29A72"), "StoneBlock_01a", M.Brick),
	sidingRed = look(hex("9C3B2A"), "WoodSiding_01a", M.WoodPlanks),
	sidingOchre = look(hex("B8862E"), "WoodSiding_01a", M.WoodPlanks),
	sidingWood = look(hex("8C6344"), "WoodSiding_01a", M.WoodPlanks),
	sidingGreen = look(hex("617A52"), "WoodSiding_01a", M.WoodPlanks),
	sidingDark = look(hex("6E4A30"), "WoodSiding_01a", M.WoodPlanks),
	trim = look(hex("D8C8A2")),
	doorWood = look(hex("5A3A26"), "Wood01a", M.Wood),
	glass = look(hex("3A3431")),
	tin = look(hex("7E848C"), "Corrugated_01a", M.Metal),
	tinRust = look(hex("8E5A3E"), "Corrugated_01a", M.Metal),
	-- metal
	iron = look(hex("3A3B3F"), "Metal 2022", M.Metal),
	rail = look(hex("6E7178"), "Metal 2022", M.Metal),
	concrete = look(hex("A39482"), "Concrete-01a", M.Concrete),
	rope = look(hex("9C8462")),
	ore = look(hex("5A443A"), "Slate02c", M.Slate),
	none = look(hex("FFFFFF")),
}
type Side = { team: Color3, letter: string }
local SIDE: { [string]: Side } = {
	A = { team = hex("C4553A"), letter = "A" },
	B = { team = hex("3F6FB0"), letter = "B" },
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

return function(upTo: number?): string
	local UPTO = upTo or 99
	assert(game.PlaceId == 133387545285290, "CanyonOutpost: not the match place")
	ensureBlockerGroup()
	local old = workspace:FindFirstChild("CanyonOutpost")
	if old then
		old:Destroy()
	end
	local map = Instance.new("Model")
	map.Name = "CanyonOutpost"
	map.WorldPivot = ORIGIN
	CollectionService:AddTag(map, "GGAsset_MatchMaps_425")
	CollectionService:AddTag(map, "GauntletAuthoredData")

	local function folder(parent: Instance, name: string): Folder
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
		return f
	end
	local secCollision = folder(map, "Collision")
	local secGround = folder(map, "Ground")
	local secCliffs = folder(map, "Cliffs")
	local secMine = folder(map, "Mine")
	local secTrack = folder(map, "Track")
	local secTower = folder(map, "WaterTower")
	local secTipple = folder(map, "Tipple")
	local secDocks = folder(map, "Docks")
	local secTown = folder(map, "Outpost")
	local secWest = folder(map, "West")
	local secSpawnEnd = folder(map, "SpawnEnd")
	local secWorld = folder(map, "World")
	local secSpawns = folder(map, "Spawns")
	folder(map, "Barriers")
	local secBounds = folder(map, "Bounds")
	local count = 0
	local rng = Random.new(54021)

	type Half = { M: (CFrame) -> CFrame, side: Side }
	local CENTRE: Half = {
		M = function(cf: CFrame): CFrame
			return cf
		end,
		side = SIDE.A,
	}
	local halves: { Half } = { CENTRE, { M = mir, side = SIDE.B } }

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
	-- a timber from p0 to p1 (section w across, t deep; local X stays horizontal)
	local function beam(
		parent: Instance,
		name: string,
		p0: Vector3,
		p1: Vector3,
		w: number,
		t: number,
		lk: Look,
		H: Half?,
		solid: boolean?
	): BasePart
		local cf = CFrame.lookAt((p0 + p1) / 2, p1)
		if math.abs((p1 - p0).Unit.Y) > 0.98 then
			cf = CFrame.lookAt((p0 + p1) / 2, p1, Vector3.xAxis)
		end
		return part(parent, name, V(w, t, (p1 - p0).Magnitude), (H or CENTRE).M(cf), lk, solid)
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
		return fromLib("CanyonOutpost", piece, parent, cf, H, scale)
	end
	local function rivals(
		piece: string,
		parent: Instance,
		cf: CFrame,
		H: Half?,
		scale: number?
	): Model
		return fromLib("CanyonOutpostRivals", piece, parent, cf, H, scale)
	end

	-- a wall-face helper: boxes on one face of a block (x0..x1, z0..z1). u runs along the face, d outward from it.
	type Block = { x0: number, x1: number, z0: number, z1: number }
	local function faceAB(
		bk: Block,
		face: string,
		u0: number,
		u1: number,
		y0: number,
		y1: number,
		d0: number,
		d1: number
	): (Vector3, Vector3)
		if face == "+z" then
			return V(u0, y0, bk.z1 + d0), V(u1, y1, bk.z1 + d1)
		elseif face == "-z" then
			return V(u0, y0, bk.z0 - d0), V(u1, y1, bk.z0 - d1)
		elseif face == "+x" then
			return V(bk.x1 + d0, y0, u0), V(bk.x1 + d1, y1, u1)
		end
		return V(bk.x0 - d0, y0, u0), V(bk.x0 - d1, y1, u1)
	end
	local function onFace(
		parent: Instance,
		name: string,
		bk: Block,
		face: string,
		u0: number,
		u1: number,
		y0: number,
		y1: number,
		d0: number,
		d1: number,
		lk: Look,
		H: Half?,
		solid: boolean?
	)
		local a, b = faceAB(bk, face, u0, u1, y0, y1, d0, d1)
		return box(parent, name, a, b, lk, solid, H)
	end
	-- one door design: jambs and a header proud of the wall, a plank panel with two battens
	local function door(
		parent: Instance,
		bk: Block,
		face: string,
		at: number,
		lk: Look,
		trim: Look,
		H: Half?,
		w: number?,
		h: number?
	)
		local W, Hh = w or 3.6, h or 7.2
		onFace(
			parent,
			"Jamb",
			bk,
			face,
			at - W / 2 - 0.45,
			at - W / 2 + 0.02,
			0.53,
			Hh + 0.1,
			-0.1,
			0.24,
			trim,
			H
		)
		onFace(
			parent,
			"Jamb",
			bk,
			face,
			at + W / 2 - 0.02,
			at + W / 2 + 0.45,
			0.53,
			Hh + 0.1,
			-0.1,
			0.24,
			trim,
			H
		)
		onFace(
			parent,
			"Header",
			bk,
			face,
			at - W / 2 - 0.6,
			at + W / 2 + 0.6,
			Hh,
			Hh + 0.55,
			-0.1,
			0.3,
			trim,
			H
		)
		onFace(parent, "Door", bk, face, at - W / 2, at + W / 2, 0.53, Hh + 0.05, -0.1, 0.08, lk, H)
		for _, y in { 1.6, 5.4 } do
			onFace(
				parent,
				"Strap",
				bk,
				face,
				at - W / 2 + 0.15,
				at + W / 2 - 0.6,
				y,
				y + 0.32,
				0.05,
				0.16,
				L.iron,
				H
			)
		end
	end
	-- one window design: a trim frame, a sill, dark glass set back, a cross mullion
	local function window(
		parent: Instance,
		bk: Block,
		face: string,
		at: number,
		y: number,
		trim: Look,
		H: Half?,
		w: number?,
		hh: number?
	)
		local W, Hh = w or 3.0, hh or 3.0
		onFace(
			parent,
			"Frame",
			bk,
			face,
			at - W / 2 - 0.35,
			at - W / 2 + 0.05,
			y - Hh / 2 - 0.35,
			y + Hh / 2 + 0.35,
			-0.1,
			0.2,
			trim,
			H
		)
		onFace(
			parent,
			"Frame",
			bk,
			face,
			at + W / 2 - 0.05,
			at + W / 2 + 0.35,
			y - Hh / 2 - 0.35,
			y + Hh / 2 + 0.35,
			-0.1,
			0.2,
			trim,
			H
		)
		onFace(
			parent,
			"Frame",
			bk,
			face,
			at - W / 2 - 0.05,
			at + W / 2 + 0.05,
			y + Hh / 2 - 0.05,
			y + Hh / 2 + 0.38,
			-0.1,
			0.17,
			trim,
			H
		)
		onFace(
			parent,
			"Sill",
			bk,
			face,
			at - W / 2 - 0.6,
			at + W / 2 + 0.6,
			y - Hh / 2 - 0.45,
			y - Hh / 2 + 0.02,
			-0.1,
			0.38,
			trim,
			H
		)
		onFace(
			parent,
			"Glass",
			bk,
			face,
			at - W / 2,
			at + W / 2,
			y - Hh / 2,
			y + Hh / 2,
			-0.1,
			0.05,
			L.glass,
			H
		)
		onFace(
			parent,
			"Mullion",
			bk,
			face,
			at - 0.12,
			at + 0.12,
			y - Hh / 2,
			y + Hh / 2,
			-0.05,
			0.12,
			trim,
			H
		)
		onFace(
			parent,
			"Mullion",
			bk,
			face,
			at - W / 2,
			at + W / 2,
			y - 0.12,
			y + 0.12,
			-0.05,
			0.1,
			trim,
			H
		)
	end
	-- a gable roof over x0..x1, z0..z1 from the wall top h: an attic of two wedges (wall look), two plates (rlk),
	-- a ridge cap; `ridge` = "x" or "z" is the ridge direction
	local function roof(
		parent: Instance,
		bk: Block,
		h: number,
		rise: number,
		ridge: string,
		wall: Look,
		rlk: Look,
		H: Half?,
		ov: number?
	)
		local OV = ov or 0.9
		local hm = (H or CENTRE).M
		if ridge == "x" then
			local zc, w, len = (bk.z0 + bk.z1) / 2, (bk.z1 - bk.z0) / 2, bk.x1 - bk.x0 + 0.08
			local xc = (bk.x0 + bk.x1) / 2
			for _, s in { -1, 1 } do
				local cf = CFrame.new(xc, h - 0.05 + (rise + 0.05) / 2, zc + s * (w - 0.05) / 2)
					* yaw(if s < 0 then 0 else 180)
				part(
					parent,
					"Attic",
					V(len - (if s > 0 then 0.06 else 0), rise + 0.05, w + 0.05),
					hm(cf),
					wall,
					false,
					"WedgePart"
				)
				local Ls = math.sqrt(w * w + rise * rise)
				local d = V(0, -rise, s * w) / Ls
				local n = V(0, w, s * rise) / Ls
				local t0, t1 = -0.2, Ls + OV
				local c = V(xc, h + rise, zc) + d * ((t0 + t1) / 2) + n * (0.15 - 0.04)
				part(
					parent,
					"Roof",
					V(bk.x1 - bk.x0 + 1.2 - (if s > 0 then 0.06 else 0), 0.3, t1 - t0),
					hm(CFrame.fromMatrix(c, Vector3.xAxis, n)),
					rlk,
					false
				)
			end
			box(
				parent,
				"Ridge",
				V(bk.x0 - 0.62, h + rise + 0.1, zc - 0.45),
				V(bk.x1 + 0.62, h + rise + 0.48, zc + 0.45),
				L.woodDark,
				false,
				H
			)
		else
			local xc, w, len = (bk.x0 + bk.x1) / 2, (bk.x1 - bk.x0) / 2, bk.z1 - bk.z0 + 0.08
			local zc = (bk.z0 + bk.z1) / 2
			for _, s in { -1, 1 } do
				local cf = CFrame.new(xc + s * (w - 0.05) / 2, h - 0.05 + (rise + 0.05) / 2, zc)
					* yaw(if s < 0 then 90 else -90)
				part(
					parent,
					"Attic",
					V(len - (if s > 0 then 0.06 else 0), rise + 0.05, w + 0.05),
					hm(cf),
					wall,
					false,
					"WedgePart"
				)
				local Ls = math.sqrt(w * w + rise * rise)
				local d = V(s * w, -rise, 0) / Ls
				local n = V(s * rise, w, 0) / Ls
				local t0, t1 = -0.2, Ls + OV
				local c = V(xc, h + rise, zc) + d * ((t0 + t1) / 2) + n * (0.15 - 0.04)
				part(
					parent,
					"Roof",
					V(bk.z1 - bk.z0 + 1.2 - (if s > 0 then 0.06 else 0), 0.3, t1 - t0),
					hm(CFrame.fromMatrix(c, Vector3.zAxis, n)),
					rlk,
					false
				)
			end
			box(
				parent,
				"Ridge",
				V(xc - 0.45, h + rise + 0.1, bk.z0 - 0.62),
				V(xc + 0.45, h + rise + 0.48, bk.z1 + 0.62),
				L.woodDark,
				false,
				H
			)
		end
	end
	-- one building design: a stone plinth, the wall block, corner boards, an eave band, gable-end bands, a roof.
	-- Doors and windows are added by the caller with door() / window().
	local function building(
		parent: Instance,
		name: string,
		bk: Block,
		h: number,
		rise: number,
		ridge: string,
		wall: Look,
		trim: Look,
		rlk: Look,
		H: Half?
	): Folder
		local f = folder(parent, name)
		box(
			f,
			"Plinth",
			V(bk.x0 - 0.35, -0.3, bk.z0 - 0.35),
			V(bk.x1 + 0.35, 0.55, bk.z1 + 0.35),
			L.stone,
			true,
			H
		)
		box(f, "Walls", V(bk.x0, 0.5, bk.z0), V(bk.x1, h, bk.z1), wall, true, H)
		for _, c in
			{
				{ bk.x0, bk.z0, -1, -1 },
				{ bk.x1, bk.z0, 1, -1 },
				{ bk.x1, bk.z1, 1, 1 },
				{ bk.x0, bk.z1, -1, 1 },
			}
		do
			local cx, cz = c[1] + c[3] * 0.1, c[2] + c[4] * 0.1
			box(
				f,
				"Corner board",
				V(cx - 0.3, 0.5, cz - 0.3),
				V(cx + 0.3, h - 0.02, cz + 0.3),
				trim,
				false,
				H
			)
		end
		-- the eave band on the two eave sides, a gable band across the two gable ends (covers the attic join)
		if ridge == "x" then
			for _, z in { bk.z0, bk.z1 } do
				local s = if z == bk.z0 then -1 else 1
				box(
					f,
					"Eave band",
					V(bk.x0 - 0.25, h - 0.7, z - s * 0.15),
					V(bk.x1 + 0.25, h - 0.08, z + s * 0.22),
					trim,
					false,
					H
				)
			end
			for _, x in { bk.x0, bk.x1 } do
				local s = if x == bk.x0 then -1 else 1
				box(
					f,
					"Gable band",
					V(x - s * 0.15, h - 0.35, bk.z0 - 0.18),
					V(x + s * 0.26, h + 0.25, bk.z1 + 0.18),
					trim,
					false,
					H
				)
			end
		else
			for _, x in { bk.x0, bk.x1 } do
				local s = if x == bk.x0 then -1 else 1
				box(
					f,
					"Eave band",
					V(x - s * 0.15, h - 0.7, bk.z0 - 0.25),
					V(x + s * 0.22, h - 0.08, bk.z1 + 0.25),
					trim,
					false,
					H
				)
			end
			for _, z in { bk.z0, bk.z1 } do
				local s = if z == bk.z0 then -1 else 1
				box(
					f,
					"Gable band",
					V(bk.x0 - 0.18, h - 0.35, z - s * 0.15),
					V(bk.x1 + 0.18, h + 0.25, z + s * 0.26),
					trim,
					false,
					H
				)
			end
		end
		roof(f, bk, h, rise, ridge, wall, rlk, H)
		return f
	end
	-- one railing design (posts every <= 4, top rail, mid rail; top 3.25, jumpable) along X or Z at floor y; the
	-- collider stops walking through but lets shots pass
	local postSeen: { [string]: boolean } = {}
	local function railing(parent: Instance, a: Vector3, b: Vector3, H: Half?)
		local y = a.Y
		local alongX = math.abs(b.X - a.X) > math.abs(b.Z - a.Z)
		local len = if alongX then math.abs(b.X - a.X) else math.abs(b.Z - a.Z)
		local n = math.max(1, math.ceil(len / 4 - 0.01))
		for k = 0, n do
			local p = a:Lerp(b, k / n)
			local w = (H or CENTRE).M(CFrame.new(p)).Position
			local key = string.format("%.1f,%.1f,%.1f", w.X, w.Y, w.Z)
			if postSeen[key] then
				continue
			end
			postSeen[key] = true
			box(
				parent,
				"Rail post",
				V(p.X - 0.22, y - 0.05, p.Z - 0.22),
				V(p.X + 0.22, y + 3.0, p.Z + 0.22),
				L.woodDark,
				false,
				H
			)
		end
		local lo, hi = a:Min(b), a:Max(b)
		if alongX then
			box(
				parent,
				"Top rail",
				V(lo.X - 0.25, y + 2.95, lo.Z - 0.28),
				V(hi.X + 0.25, y + 3.25, hi.Z + 0.28),
				L.wood,
				false,
				H
			)
			box(
				parent,
				"Mid rail",
				V(lo.X, y + 1.45, lo.Z - 0.12),
				V(hi.X, y + 1.7, hi.Z + 0.12),
				L.wood,
				false,
				H
			)
			local c =
				col("Rail", V(lo.X - 0.2, y, lo.Z - 0.25), V(hi.X + 0.2, y + 3.25, hi.Z + 0.25), H)
			c.CanQuery = false
		else
			box(
				parent,
				"Top rail",
				V(lo.X - 0.28, y + 2.92, lo.Z - 0.25),
				V(hi.X + 0.28, y + 3.22, hi.Z + 0.25),
				L.wood,
				false,
				H
			)
			box(
				parent,
				"Mid rail",
				V(lo.X - 0.12, y + 1.42, lo.Z),
				V(hi.X + 0.12, y + 1.67, hi.Z),
				L.wood,
				false,
				H
			)
			local c =
				col("Rail", V(lo.X - 0.25, y, lo.Z - 0.2), V(hi.X + 0.25, y + 3.25, hi.Z + 0.2), H)
			c.CanQuery = false
		end
	end
	-- one timber deck design: a plank deck (top y), fascia boards on the open edges, joists, cap beams on post rows,
	-- posts on concrete pads, knee braces toward the deck's middle
	type Edges = { x0: boolean?, x1: boolean?, z0: boolean?, z1: boolean? }
	local function deck(
		parent: Instance,
		name: string,
		bk: Block,
		y: number,
		pxs: { number },
		pzs: { number },
		edges: Edges,
		H: Half?,
		top: number?
	)
		local f = folder(parent, name)
		local yt = top or y
		box(f, "Deck", V(bk.x0, yt - 0.3, bk.z0), V(bk.x1, yt, bk.z1), L.plank, true, H)
		if edges.z0 then
			box(
				f,
				"Fascia",
				V(bk.x0 - 0.16, y - 0.85, bk.z0 - 0.16),
				V(bk.x1 + 0.16, y - 0.12, bk.z0 + 0.05),
				L.woodDark,
				false,
				H
			)
		end
		if edges.z1 then
			box(
				f,
				"Fascia",
				V(bk.x0 - 0.16, y - 0.85, bk.z1 - 0.05),
				V(bk.x1 + 0.16, y - 0.12, bk.z1 + 0.16),
				L.woodDark,
				false,
				H
			)
		end
		if edges.x0 then
			box(
				f,
				"Fascia",
				V(bk.x0 - 0.12, y - 0.83, bk.z0 - 0.1),
				V(bk.x0 + 0.05, y - 0.14, bk.z1 + 0.1),
				L.woodDark,
				false,
				H
			)
		end
		if edges.x1 then
			box(
				f,
				"Fascia",
				V(bk.x1 - 0.05, y - 0.83, bk.z0 - 0.1),
				V(bk.x1 + 0.12, y - 0.14, bk.z1 + 0.1),
				L.woodDark,
				false,
				H
			)
		end
		local zz = bk.z0 + 0.7
		while zz < bk.z1 - 0.4 do
			box(
				f,
				"Joist",
				V(bk.x0 + 0.1, y - 0.8, zz - 0.25),
				V(bk.x1 - 0.1, y - 0.28, zz + 0.25),
				L.wood,
				false,
				H
			)
			zz += 2.4
		end
		for _, px in pxs do
			box(
				f,
				"Cap",
				V(px - 0.45, y - 1.6, bk.z0 + 0.1),
				V(px + 0.45, y - 0.78, bk.z1 - 0.1),
				L.woodDark,
				false,
				H
			)
			for _, pz in pzs do
				box(
					f,
					"Pad",
					V(px - 0.9, -0.15, pz - 0.9),
					V(px + 0.9, 0.35, pz + 0.9),
					L.concrete,
					true,
					H
				)
				box(
					f,
					"Post",
					V(px - 0.6, 0.3, pz - 0.6),
					V(px + 0.6, y - 1.55, pz + 0.6),
					L.wood,
					true,
					H
				)
				for _, s in { -1, 1 } do
					local tz = pz + s * 2.2
					if tz > bk.z0 + 0.5 and tz < bk.z1 - 0.5 then
						beam(
							f,
							"Brace",
							V(px, y - 4.2, pz + s * 0.45),
							V(px, y - 1.65, tz),
							0.42,
							0.55,
							L.wood,
							H
						)
					end
				end
			end
		end
		return f
	end
	-- one stair design rising along +X from x0 (ground y0) to x1 (deck y1): channel stringers, open treads, a rail
	-- each side; an invisible wedge ramp carries the walk
	local function stairX(
		parent: Instance,
		x0: number,
		x1: number,
		z0: number,
		z1: number,
		y0: number,
		y1: number,
		H: Half?,
		T: CFrame?
	)
		local f = folder(parent, "Stair")
		local TT = T or I
		local function tp(p: Vector3): Vector3
			return (TT * CFrame.new(p)).Position
		end
		local n = math.floor((y1 - y0) / 1.25 + 0.5)
		local rise, run = (y1 - y0) / n, (x1 - x0) / (n - 1)
		for k = 1, n - 1 do
			box(
				f,
				"Tread",
				V(x0 + (k - 1) * run - 0.08, y0 + k * rise - 0.3, z0 + 0.35),
				V(x0 + k * run + 0.02, y0 + k * rise, z1 - 0.35),
				L.plank,
				false,
				H,
				TT
			)
		end
		for _, z in { z0 + 0.2, z1 - 0.2 } do
			beam(
				f,
				"Stringer",
				tp(V(x0 - run, y0 - 0.35, z)),
				tp(V(x1, y1 - 1.05, z)),
				0.4,
				0.95,
				L.woodDark,
				H
			)
		end
		box(
			f,
			"Foot",
			V(x0 - run - 0.6, -0.12, z0 - 0.1),
			V(x0 - run + 0.9, 0.3, z1 + 0.1),
			L.concrete,
			false,
			H,
			TT
		)
		for _, z in { z0 + 0.2, z1 - 0.2 } do
			local pts = {
				V(x0 - run * 0.4, y0 + 0.2, z),
				V((x0 + x1) / 2, (y0 + y1) / 2 + rise * 0.3, z),
				V(x1 - 0.3, y1 - 0.3, z),
			}
			for _, p in pts do
				box(
					f,
					"Rail post",
					V(p.X - 0.22, p.Y, z - 0.22),
					V(p.X + 0.22, p.Y + 3.3, z + 0.22),
					L.woodDark,
					false,
					H,
					TT
				)
			end
			beam(
				f,
				"Hand rail",
				tp(pts[1] + V(-0.25, 3.25, 0)),
				tp(pts[3] + V(0.25, 3.25, 0)),
				0.5,
				0.3,
				L.wood,
				H
			)
			local c = beam(
				secCollision,
				"Rail",
				tp(pts[1] + V(0, 1.7, 0)),
				tp(pts[3] + V(0, 1.7, 0)),
				0.5,
				3.3,
				L.none,
				H,
				true
			)
			c.Transparency = 1
			c.CanQuery = false
		end
		-- the walk: a wedge from the foot to the deck edge
		local ramp = part(
			secCollision,
			"Stair ramp",
			V(z1 - z0, y1 - y0, x1 - (x0 - run)),
			(H or CENTRE).M(
				TT * CFrame.new((x0 - run + x1) / 2, (y0 + y1) / 2 - 0.01, (z0 + z1) / 2) * yaw(90)
			),
			L.none,
			true,
			"WedgePart"
		)
		ramp.Transparency = 1
		ramp.CastShadow = false
	end
	-- the timber stack (one design: stacked sawn beams on bearers, ends staggered layer to layer, corner stakes)
	local function timberStack(
		parent: Instance,
		cx: number,
		cz: number,
		len: number,
		wid: number,
		layers: number,
		alongX: boolean,
		H: Half?
	)
		local f = folder(parent, "Timber stack")
		local T = CFrame.new(cx, 0, cz) * (if alongX then I else yaw(90))
		for _, s in { -1, 1 } do
			box(
				f,
				"Bearer",
				V(s * (len / 2 - 0.35) - 0.45, -0.05, -wid / 2 - 0.3),
				V(s * (len / 2 - 0.35) + 0.45, 0.63, wid / 2 + 0.3),
				L.sleeper,
				false,
				H,
				T
			)
		end
		local nb = math.floor((wid + 0.1) / 1.0)
		local top = 0
		for k = 0, layers - 1 do
			local y0 = 0.58 + k * 0.88
			local l2 = len / 2 - (k % 2) * 0.2
			for j = 0, nb - 1 do
				local z = -wid / 2 + 0.45 + j * 1.0 + (k % 2) * 0.04
				box(
					f,
					"Beam",
					V(-l2, y0, z - 0.45),
					V(l2, y0 + 0.9, z + 0.45),
					L.woodLight,
					false,
					H,
					T
				)
			end
			top = y0 + 0.9
		end
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local x = sx * (len / 2 - 2.0)
				local z = sz * (wid / 2 + 0.3)
				box(
					f,
					"Stake",
					V(x - 0.25, -0.1, z - 0.25),
					V(x + 0.25, top + 0.4, z + 0.25),
					L.woodDark,
					false,
					H,
					T
				)
			end
		end
		col("Timber stack", V(-len / 2, 0, -wid / 2 - 0.5), V(len / 2, top, wid / 2 + 0.5), H, T)
		return top
	end

	--------------------------------------------------------------------------------------------- 1. the midline
	-- the canyon floor and the far ground
	box(secGround, "Canyon floor", V(-112, -2, -132), V(112, 0, 132), L.sand, true)
	box(
		secGround,
		"Far ground",
		V(-1400, -1.33, -1400),
		V(1400, -0.2, 1400),
		look(hex("B8784C"), "Sand_01a", M.Sand),
		false
	)
	-- worn paths from each spawn yard to the middle, and along the trading post front
	for _, H in halves do
		box(secGround, "Path", V(-5.5, -0.1, 24), V(5.5, 0.05, 66), L.path, false, H)
		box(secGround, "Path", V(-28, -0.1, 38.5), V(-5.6, 0.04, 43.6), L.path, false, H)
		box(secGround, "Path", V(-3.6, -0.1, 79.5), V(3.6, 0.07, 96), L.path, false, H)
	end
	-- the ore track: a ballast bed, sleepers, two rails (gauge 2.7), from inside the mine to the tipple's buffer
	local TRACK_X0, TRACK_X1 = -77.2, 54.6
	box(
		secTrack,
		"Ballast",
		V(TRACK_X0, -0.1, -2.9),
		V(TRACK_X1 + 0.6, 0.06, 2.9),
		L.ballast,
		false
	)
	do
		local x = TRACK_X0 + 0.6
		while x < TRACK_X1 - 0.2 do
			box(
				secTrack,
				"Sleeper",
				V(x - 0.45, -0.04, -2.3),
				V(x + 0.45, 0.22, 2.3),
				L.sleeper,
				false
			)
			x += 2.2
		end
		for _, z in { -1.35, 1.35 } do
			box(
				secTrack,
				"Rail foot",
				V(TRACK_X0, 0.2, z - 0.3),
				V(TRACK_X1, 0.3, z + 0.3),
				L.rail,
				false
			)
			box(
				secTrack,
				"Rail",
				V(TRACK_X0, 0.28, z - 0.14),
				V(TRACK_X1, 0.5, z + 0.14),
				L.rail,
				false
			)
		end
	end
	-- three ore carts (low cover, 3.7)
	for _, x in { -42, -20, 20 } do
		kit("CNOreCart", secTrack, CFrame.new(x, 0.5, 0) * yaw(90), nil, 0.9)
		col("Ore cart", V(x - 3.2, 0, -2.0), V(x + 3.2, 3.75, 2.0))
	end
	-- the mine portal in the west cliff (faces +X)
	kit("CNMinePortal", secMine, CFrame.new(-68.5, 0, 0) * yaw(-90))
	col("Mine post", V(-68.6, 0, -6.8), V(-66.8, 12, -5.0))
	col("Mine post", V(-68.6, 0, 5.0), V(-66.8, 12, 6.8))
	col("Mine wall", V(-78, 0, -6.6), V(-68.6, 13, -5.1))
	col("Mine wall", V(-78, 0, 5.1), V(-68.6, 13, 6.6))
	col("Mine back", V(-78.5, 0, -6.6), V(-76.9, 13, 6.6))
	col("Mine ceiling", V(-78, 12.2, -6.6), V(-66.8, 14, 6.6))
	box(secMine, "Mine floor", V(-78.2, -0.4, -5.3), V(-68.4, 0.03, 5.3), L.ballast, false)
	-- the water tower over the track (the landmark), its pipe covers to the pump houses
	kit("CNWaterTower", secTower, CFrame.new(0, 0, 0))
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			col(
				"Tower leg",
				V(sx * 6.9 - 0.85, 0, sz * 6.9 - 0.85),
				V(sx * 6.9 + 0.85, 9, sz * 6.9 + 0.85)
			)
		end
	end
	for _, H in halves do
		col("Riser pit", V(2.1, 0, 5.85), V(3.9, 0.5, 7.55), H)
		col("Riser", V(2.5, 0, 6.2), V(3.5, 9, 7.2), H)
	end
	-- the pump houses (fill the tower; full cover between the tower and the trading post)
	if UPTO >= 1 then
		for _, H in halves do
			local bk: Block = { x0 = -1, x1 = 9, z0 = 15, z1 = 21 }
			local f =
				building(secTown, "Pump house", bk, 7.5, 2.4, "x", L.sidingWood, L.trim, L.tin, H)
			door(f, bk, "+x", 18, L.doorWood, L.trim, H, 3.2, 6.4)
			window(f, bk, "+z", 4, 4.4, L.trim, H)
			window(f, bk, "-x", 18, 4.4, L.trim, H, 2.4, 2.4)
			-- the vent stack and the plank pipe cover to the riser pit
			box(f, "Vent", V(5.7, 8.6, 17.2), V(6.5, 11.6, 18.0), L.iron, false, H)
			box(f, "Vent cap", V(5.45, 11.55, 16.95), V(6.75, 11.9, 18.25), L.iron, false, H)
			box(f, "Pipe cover", V(2.3, -0.1, 7.5), V(3.7, 0.32, 14.7), L.sleeper, false, H)
			for _, z in { 9.0, 11.3, 13.6 } do
				box(
					f,
					"Cover batten",
					V(2.2, 0.0, z - 0.2),
					V(3.8, 0.38, z + 0.2),
					L.woodDark,
					false,
					H
				)
			end
		end
	end
	-- the strata cliffs round the bounds: global strata (same bands everywhere, so they read continuous), each segment
	-- steps back a random amount per band and stops at a random band (skyline), a sand cap on its top band
	local STRATA = {
		{ -1.0, 7.0, L.rockDark },
		{ 7.0, 15.0, L.rockRed },
		{ 15.0, 18.5, L.rockCream },
		{ 18.5, 28.0, L.rockOrange },
		{ 28.0, 34.5, L.rockRed },
		{ 34.5, 38.0, L.rockCream },
		{ 38.0, 46.0, L.rockRed },
	}
	-- a run of cliff along `axis` ("z": the face is x = face, rising toward `out` = -1 / +1 in x; "x": face z = face)
	-- Heights and depths sit on a 0.2 grid with a 0.1 offset on every other segment, bands seat 0.15 into the band
	-- below, the cap's top is 0.8 over its band: neighbouring segments never put two faces in one plane.
	local segCount = 0
	local function cliffRun(
		axis: string,
		face: number,
		out: number,
		from: number,
		to: number,
		minBands: number?
	)
		local a = from
		while a < to - 0.5 do
			local b = math.min(to, a + rng:NextNumber(11, 19))
			if to - b < 6 then
				b = to
			end
			segCount += 1
			local P = 0.1 * (segCount % 2)
			local front = face + out * (0.4 + 0.2 * rng:NextInteger(0, 8) + P)
			local bands = rng:NextInteger(minBands or 5, #STRATA)
			local ytop = 0
			for i = 1, bands do
				local s = STRATA[i]
				local y0 = if i == 1 then -1.0 - 0.2 * rng:NextInteger(0, 2) - P else ytop - 0.15
				local y1 = s[2] + 0.2 * rng:NextInteger(-2, 2) + P
				local e = 0.05 * (i % 3)
				if i > 1 then
					front += out * (0.6 + 0.2 * rng:NextInteger(0, 8))
				end
				local back = face + out * (44 + 0.37 * i + 0.11 * (segCount % 3))
				if axis == "z" then
					box(
						secCliffs,
						"Rock",
						V(front, y0, a - 0.3 - e),
						V(back + out * e, y1, b + 0.3 + e),
						s[3],
						true
					)
				else
					box(
						secCliffs,
						"Rock",
						V(a - 0.3 - e, y0, front),
						V(b + 0.3 + e, y1, back + out * e),
						s[3],
						true
					)
				end
				ytop = y1
			end
			local capF = front + out * 0.55
			if axis == "z" then
				box(
					secCliffs,
					"Rock cap",
					V(capF, ytop - 0.15, a + 0.02),
					V(face + out * (43.5 + 0.11 * (segCount % 3)), ytop + 0.8, b - 0.02),
					L.rockTop,
					true
				)
			else
				box(
					secCliffs,
					"Rock cap",
					V(a + 0.02, ytop - 0.15, capF),
					V(b - 0.02, ytop + 0.8, face + out * (43.5 + 0.11 * (segCount % 3))),
					L.rockTop,
					true
				)
			end
			a = b
		end
	end
	cliffRun("z", -70.4, -1, -104, -14)
	cliffRun("z", -70.4, -1, 14, 104)
	cliffRun("z", 70.4, 1, -104, 104)
	cliffRun("x", 96.4, 1, -72, 72)
	cliffRun("x", -96.4, -1, -72, 72)
	-- round the mine portal: jambs and a lintel set in front of the portal's plank surround
	for _, s in { -1, 1 } do
		local function zr(a: number, b: number): (number, number)
			return math.min(s * a, s * b), math.max(s * a, s * b)
		end
		local za, zb = zr(9.2, 14.3)
		box(secCliffs, "Rock", V(-68.2, -1.05, za), V(-110.13, 7.0, zb), L.rockDark, true)
		za, zb = zr(9.25, 14.36)
		box(secCliffs, "Rock", V(-68.6, 6.85, za), V(-110.26, 15.2, zb), L.rockRed, true)
		za, zb = zr(9.3, 14.42)
		box(secCliffs, "Rock", V(-69.0, 15.05, za), V(-110.39, 18.6, zb), L.rockCream, true)
	end
	box(secCliffs, "Rock", V(-68.2, 16.7, -9.4), V(-110.52, 18.4, 9.4), L.rockCream, true)
	box(secCliffs, "Rock", V(-69.6, 18.35, -14.6), V(-110.65, 28.3, 14.6), L.rockOrange, true)
	box(secCliffs, "Rock", V(-71.0, 28.25, -14.4), V(-110.78, 34.2, 14.4), L.rockRed, true)
	box(secCliffs, "Rock", V(-72.3, 34.15, -14.2), V(-110.91, 37.7, 14.2), L.rockCream, true)
	box(secCliffs, "Rock cap", V(-72.8, 37.55, -14.1), V(-111.04, 38.35, 14.1), L.rockTop, true)
	-- the world beyond: Westown's mesas (RIVALS rock + sand-cap meshes), scaled, round the canyon
	for _, m in
		{
			{ "R_Mesa1", -330, 120, 0.5, 20 },
			{ "R_Mesa2", -300, -200, 0.45, 160 },
			{ "R_Mesa3", -280, -20, 0.9, 80 },
			{ "R_Mesa2", 320, 160, 0.5, -30 },
			{ "R_Mesa1", 360, -150, 0.45, 200 },
			{ "R_Mesa3", 290, 30, 0.85, 250 },
			{ "R_Mesa1", 60, 380, 0.5, 95 },
			{ "R_Mesa3", -150, 300, 0.9, 10 },
			{ "R_Mesa2", -40, -390, 0.5, 120 },
			{ "R_Mesa3", 170, -300, 0.9, 300 },
		}
	do
		local mm = rivals(m[1], secWorld, CFrame.new(m[2], -6, m[3]) * yaw(m[5]), nil, m[4])
		for _, d in mm:GetDescendants() do
			if d:IsA("BasePart") then
				d.CastShadow = false
			end
		end
	end

	--------------------------------------------------------------------------------------------- 2. the east
	if UPTO >= 2 then
		-- the tipple: deck +10 over the track's end, the ore bin with its roof, the chute, the hoist, the buffer stop
		local tb: Block = { x0 = 46.4, x1 = 62.4, z0 = -10.4, z1 = 10.4 }
		deck(
			secTipple,
			"Tipple deck",
			tb,
			10,
			{ 47, 54.5, 61.5 },
			{ -9.6, 9.6 },
			{ x0 = true, x1 = true, z0 = true, z1 = true }
		)
		box(secTipple, "Pad", V(60.6, -0.15, -0.9), V(62.4, 0.35, 0.9), L.concrete, true)
		box(secTipple, "Post", V(60.9, 0.3, -0.6), V(62.1, 8.45, 0.6), L.wood, true)
		local bin: Block = { x0 = 53, x1 = 61, z0 = -5, z1 = 5 }
		box(secTipple, "Ore bin", V(53, 9.95, -5), V(61, 19.0, 5), L.sidingDark, true)
		for _, c in { { 53, -5 }, { 61, -5 }, { 61, 5 }, { 53, 5 } } do
			local cx, cz =
				c[1] + (if c[1] > 57 then 0.1 else -0.1), c[2] + (if c[2] > 0 then 0.1 else -0.1)
			box(
				secTipple,
				"Bin post",
				V(cx - 0.45, 9.97, cz - 0.45),
				V(cx + 0.45, 19.3, cz + 0.45),
				L.woodDark,
				false
			)
		end
		for _, y in { 12.4, 15.9 } do
			box(
				secTipple,
				"Bin batten",
				V(53.2, y, -5.17),
				V(60.8, y + 0.36, 5.17),
				L.woodDark,
				false
			)
			box(
				secTipple,
				"Bin batten",
				V(52.83, y + 0.03, -4.8),
				V(61.17, y + 0.39, 4.8),
				L.woodDark,
				false
			)
		end
		local rim: Block = { x0 = 52.7, x1 = 61.3, z0 = -5.3, z1 = 5.3 }
		box(secTipple, "Bin rim", V(52.7, 18.9, -5.3), V(61.3, 19.5, 5.3), L.woodDark, false)
		roof(secTipple, rim, 19.5, 3.0, "x", L.sidingDark, L.tinRust)
		box(secTipple, "Chute", V(54.0, 5.6, -1.5), V(57.0, 9.75, 1.5), L.woodDark, true)
		box(secTipple, "Chute gate", V(53.8, 5.35, -1.7), V(57.2, 5.65, 1.7), L.iron, false)
		box(secTipple, "Chute band", V(53.88, 7.4, -1.62), V(57.12, 7.75, 1.62), L.iron, false)
		box(secTipple, "Hoist beam", V(48.4, 18.6, -0.45), V(53.2, 19.35, 0.45), L.woodDark, false)
		beam(secTipple, "Hoist strut", V(53.1, 15.8, 0), V(50.2, 18.65, 0), 0.5, 0.6, L.wood)
		box(secTipple, "Pulley", V(48.75, 17.9, -0.34), V(49.65, 18.65, 0.34), L.iron, false)
		box(secTipple, "Hoist rope", V(49.14, 12.6, -0.06), V(49.26, 17.95, 0.06), L.rope, false)
		box(secTipple, "Hook block", V(48.9, 12.0, -0.3), V(49.5, 12.65, 0.3), L.iron, false)
		-- buffer stop at the track's end
		for _, z in { -1.35, 1.35 } do
			box(
				secTipple,
				"Buffer post",
				V(55.2, -0.1, z - 0.4),
				V(56.0, 2.9, z + 0.4),
				L.woodDark,
				false
			)
			beam(secTipple, "Buffer strut", V(55.6, 2.4, z), V(58.3, 0.0, z), 0.5, 0.5, L.wood)
		end
		box(secTipple, "Buffer beam", V(54.6, 1.4, -2.2), V(55.3, 2.6, 2.2), L.woodDark, false)
		box(secTipple, "Buffer plate", V(54.45, 1.6, -0.9), V(54.65, 2.4, 0.9), L.iron, false)
		col("Buffer stop", V(54.4, 0, -2.2), V(58.3, 2.9, 2.2))
		-- tipple deck railings (west and east edges; the north / south edges are done per half round the walkways)
		railing(secTipple, V(46.6, 10, -10.2), V(46.6, 10, 10.2))
		railing(secTipple, V(62.2, 10, -10.2), V(62.2, 10, 10.2))
		blocker("Bin roof", V(52, 19.5, -6.5), V(62, 30, 6.5))
		for _, H in halves do
			railing(secTipple, V(46.6, 10, 10.2), V(53.5, 10, 10.2), H)
			railing(secTipple, V(58.5, 10, 10.2), V(62.2, 10, 10.2), H)
			-- the walkway to the dock (+10), joined under the decks' planks (its top 0.03 lower)
			local wb: Block = { x0 = 53.5, x1 = 58.5, z0 = 10.3, z1 = 30.1 }
			deck(
				secDocks,
				"Walkway",
				wb,
				10,
				{ 54.1, 57.9 },
				{ 17.0, 23.6 },
				{ x0 = true, x1 = true },
				H,
				9.97
			)
			railing(secDocks, V(53.7, 10, 10.4), V(53.7, 10, 30.0), H)
			railing(secDocks, V(58.3, 10, 10.4), V(58.3, 10, 30.0), H)
			-- the loading dock (+10) and its stair from the middle
			local db: Block = { x0 = 38, x1 = 62, z0 = 30, z1 = 46 }
			deck(
				secDocks,
				"Dock",
				db,
				10,
				{ 38.6, 50, 61.4 },
				{ 30.6, 45.4 },
				{ x0 = true, x1 = true, z0 = true, z1 = true },
				H
			)
			railing(secDocks, V(38.2, 10, 30.2), V(53.5, 10, 30.2), H)
			railing(secDocks, V(58.5, 10, 30.2), V(61.8, 10, 30.2), H)
			railing(secDocks, V(61.8, 10, 30.2), V(61.8, 10, 45.8), H)
			railing(secDocks, V(38.2, 10, 45.8), V(61.8, 10, 45.8), H)
			railing(secDocks, V(38.2, 10, 30.2), V(38.2, 10, 39.4), H)
			stairX(secDocks, 20.5, 38, 39.5, 44.5, 0, 10, H)
			-- freight on the dock: crates and barrels (cover on the deck)
			rivals("R_Crate6", secDocks, CFrame.new(43.5, 10, 34.2), H)
			rivals("R_Crate4", secDocks, CFrame.new(43.0, 13.97, 34.2) * yaw(8), H)
			rivals("R_Crate4", secDocks, CFrame.new(48.6, 10, 34.4), H)
			col("Dock crates", V(40.5, 10, 32.2), V(50.6, 14, 36.4), H)
			col("Dock crate top", V(41.0, 14, 32.2), V(45.0, 18, 36.2), H)
			kit("CNBarrel", secDocks, CFrame.new(57.0, 9.98, 37.6) * yaw(10), H)
			kit("CNBarrel", secDocks, CFrame.new(57.6, 9.98, 40.5) * yaw(35), H)
			col("Dock barrels", V(55.6, 10, 36.2), V(59.0, 13.45, 41.9), H)
			-- the jib crane: hoists freight from the wagon below onto the dock
			box(secDocks, "Jib foot", V(50.2, 9.97, 43.2), V(51.8, 10.5, 44.8), L.iron, false, H)
			box(secDocks, "Jib mast", V(50.5, 10.0, 43.5), V(51.5, 18.6, 44.5), L.woodDark, true, H)
			box(secDocks, "Jib boom", V(50.65, 17.5, 43.8), V(51.35, 18.25, 54.4), L.wood, false, H)
			beam(secDocks, "Jib strut", V(51, 14.2, 44.45), V(51, 17.55, 48.6), 0.5, 0.6, L.wood, H)
			box(secDocks, "Jib pulley", V(50.6, 16.8, 53.4), V(51.4, 17.55, 54.2), L.iron, false, H)
			box(
				secDocks,
				"Jib rope",
				V(50.94, 12.2, 53.74),
				V(51.06, 16.85, 53.86),
				L.rope,
				false,
				H
			)
			box(secDocks, "Jib hook", V(50.7, 11.6, 53.5), V(51.3, 12.25, 54.1), L.iron, false, H)
			-- the freight wagon under the jib (full cover), the east timber stack
			kit("CNWagon", secDocks, CFrame.new(51.3, 0, 57) * yaw(90), H)
			col("Wagon", V(42.5, 0, 53.4), V(57.6, 8.0, 60.6), H)
			timberStack(secDocks, 28, 66, 14, 5, 9, true, H)
		end
	end

	--------------------------------------------------------------------------------------------- 3. each half's middle and west
	if UPTO >= 3 then
		for _, H in halves do
			-- the trading post: a false front on the middle side with a stacked cornice, a gable roof behind it,
			-- a porch (+1) with posts and a lean-to roof, the trough and hitching rail in front
			local tp: Block = { x0 = -27, x1 = -1, z0 = 47, z1 = 61 }
			local f =
				building(secTown, "Trading post", tp, 11, 4.2, "z", L.sidingRed, L.trim, L.tin, H)
			box(f, "False front", V(-27.5, 0.44, 46.35), V(-0.5, 16, 47.12), L.sidingRed, true, H)
			box(f, "Front pediment", V(-19, 15.9, 46.42), V(-9, 17.6, 47.05), L.sidingRed, false, H)
			box(f, "Cornice", V(-27.9, 15.4, 45.9), V(-0.1, 16.05, 47.6), L.trim, false, H)
			box(f, "Cornice", V(-27.75, 14.85, 46.05), V(-0.25, 15.45, 47.45), L.woodDark, false, H)
			box(f, "Cornice", V(-27.62, 14.4, 46.18), V(-0.38, 14.9, 47.3), L.trim, false, H)
			box(f, "Pediment cap", V(-19.4, 17.55, 46.0), V(-8.6, 18.1, 47.5), L.trim, false, H)
			box(f, "Front corner", V(-27.85, 0.47, 46.0), V(-27.15, 14.45, 46.7), L.trim, false, H)
			box(f, "Front corner", V(-0.85, 0.47, 46.0), V(-0.15, 14.45, 46.7), L.trim, false, H)
			local ff: Block = { x0 = -27.5, x1 = -0.5, z0 = 46.35, z1 = 47.12 }
			door(f, ff, "-z", -14, L.doorWood, L.trim, H, 4.4, 7.4)
			window(f, ff, "-z", -22.5, 4.6, L.trim, H, 4.0, 3.6)
			window(f, ff, "-z", -5.5, 4.6, L.trim, H, 4.0, 3.6)
			window(f, ff, "-z", -20, 12.5, L.trim, H, 3.0, 2.6)
			window(f, ff, "-z", -8, 12.5, L.trim, H, 3.0, 2.6)
			window(f, tp, "+x", 52.5, 4.6, L.trim, H)
			window(f, tp, "+x", 57.5, 4.6, L.trim, H)
			window(f, tp, "-x", 54, 4.6, L.trim, H)
			door(f, tp, "+z", -14, L.doorWood, L.trim, H)
			-- the porch: a plank deck (+1) on the plinth line, a step, posts, a beam and a lean-to roof
			box(f, "Porch", V(-27.4, -0.1, 42.6), V(-0.6, 1.0, 46.4), L.plank, true, H)
			box(
				f,
				"Porch fascia",
				V(-27.55, 0.1, 42.45),
				V(-0.45, 0.85, 42.8),
				L.woodDark,
				false,
				H
			)
			box(f, "Porch step", V(-18.5, -0.1, 41.2), V(-9.5, 0.5, 42.65), L.plank, true, H)
			for _, x in { -26.8, -19.6, -8.4, -1.2 } do
				box(
					f,
					"Porch post",
					V(x - 0.3, 0.95, 42.95),
					V(x + 0.3, 9.05, 43.55),
					L.trim,
					true,
					H
				)
			end
			box(f, "Porch beam", V(-27.6, 9.0, 42.8), V(-0.4, 9.72, 43.7), L.woodDark, false, H)
			do
				local p0, p1 = V(-14, 10.2, 46.3), V(-14, 9.4, 42.2)
				local n = (V(0, 4.1, -0.8)).Unit
				local c = (p0 + p1) / 2 + n * 0.11
				part(
					f,
					"Porch roof",
					V(28.4, 0.3, (p1 - p0).Magnitude + 0.3),
					H.M(CFrame.fromMatrix(c, Vector3.xAxis, n)),
					L.tin,
					false
				)
			end
			rivals("R_Trough", f, CFrame.new(-14, 0, 35.6), H)
			rivals("R_HitchPost", f, CFrame.new(-14, 0, 38.8), H)
			col("Trough", V(-22.4, 0, 33.8), V(-5.6, 3.4, 37.4), H)
			col("Hitching rail", V(-21.3, 0, 38.2), V(-6.7, 4.0, 39.4), H)
			blocker("Trading post roof", V(-28, 16, 45.5), V(0, 30, 62), H)
			blocker("Porch roof", V(-28, 9.0, 42), V(0, 16, 46.4), H)
			-- the assay hut (ochre), door to the middle
			local ah: Block = { x0 = 19.5, x1 = 28.5, z0 = 20.5, z1 = 27.5 }
			local fa =
				building(secTown, "Assay hut", ah, 8, 2.6, "z", L.sidingOchre, L.trim, L.tin, H)
			door(fa, ah, "-x", 24, L.doorWood, L.trim, H, 3.2, 6.6)
			window(fa, ah, "-z", 24, 4.6, L.trim, H)
			window(fa, ah, "+z", 24, 4.6, L.trim, H)
			box(fa, "Stack", V(25.6, 9.2, 22.0), V(26.4, 12.6, 22.8), L.iron, false, H)
			box(fa, "Stack cap", V(25.35, 12.55, 21.75), V(26.65, 12.9, 23.05), L.iron, false, H)
			-- the powder shed (stone, by the mine), the ore bin, the pit props, the west timber stack
			local ps: Block = { x0 = -53, x1 = -43, z0 = 24, z1 = 32 }
			local fp =
				building(secWest, "Powder shed", ps, 8.5, 2.6, "x", L.stoneWall, L.stone, L.tin, H)
			door(fp, ps, "+x", 28, look(hex("8E3326"), "Wood01a", M.Wood), L.trim, H, 3.2, 6.6)
			window(fp, ps, "-z", -48, 5.2, L.trim, H, 1.6, 1.6)
			-- the ore bin: corner posts, plank walls with battens, an ore heap in the rim
			local ob = folder(secWest, "Ore bin")
			box(ob, "Bin", V(-26.8, -0.1, 31.2), V(-21.2, 7.6, 36.8), L.sidingDark, true, H)
			for _, c in { { -26.8, 31.2 }, { -21.2, 31.2 }, { -21.2, 36.8 }, { -26.8, 36.8 } } do
				local cx, cz =
					c[1] + (if c[1] > -24 then 0.08 else -0.08),
					c[2] + (if c[2] > 34 then 0.08 else -0.08)
				box(
					ob,
					"Bin post",
					V(cx - 0.4, -0.1, cz - 0.4),
					V(cx + 0.4, 8.2, cz + 0.4),
					L.woodDark,
					false,
					H
				)
			end
			for _, y in { 2.2, 5.0 } do
				box(
					ob,
					"Bin batten",
					V(-26.62, y, -0) + V(0, 0, 31.03),
					V(-21.38, y + 0.36, 36.97),
					L.woodDark,
					false,
					H
				)
				box(
					ob,
					"Bin batten",
					V(-26.97, y + 0.03, 31.38),
					V(-21.03, y + 0.39, 36.62),
					L.woodDark,
					false,
					H
				)
			end
			box(ob, "Bin rim", V(-27.0, 7.55, 31.0), V(-21.0, 8.0, 37.0), L.woodDark, false, H)
			box(ob, "Ore", V(-26.6, 7.6, 31.4), V(-21.4, 7.95, 36.6), L.ore, false, H)
			part(
				ob,
				"Ore heap",
				V(5.0, 0.9, 2.5),
				H.M(CFrame.new(-24, 8.38, 32.8)),
				L.ore,
				false,
				"WedgePart"
			)
			part(
				ob,
				"Ore heap",
				V(4.94, 0.86, 2.5),
				H.M(CFrame.new(-24, 8.36, 35.2) * yaw(180)),
				L.ore,
				false,
				"WedgePart"
			)
			timberStack(secWest, -28, 20, 10, 4, 3, true, H)
			timberStack(secWest, -38, 46, 14, 7, 9, false, H)
			-- the rock shelf (+7) under the west cliff, a timber stair up from the middle
			local rs = folder(secWest, "Rock shelf")
			box(rs, "Shelf", V(-71, -1, 45), V(-50, 3.6, 67), L.rockDark, true, H)
			box(rs, "Shelf", V(-71.2, 3.55, 45.6), V(-50.6, 6.7, 66.4), L.rockRed, true, H)
			box(rs, "Shelf top", V(-71.4, 6.65, 45.9), V(-50.9, 7.0, 66.1), L.ledge, true, H)
			stairX(rs, 36.5, 50.9, -65, -59, 0, 7, H, yaw(180))
		end
	end

	--------------------------------------------------------------------------------------------- 4. the spawn end
	if UPTO >= 4 then
		for _, H in halves do
			local sb: Block = { x0 = -12, x1 = 12, z0 = 71, z1 = 79 }
			local f = building(
				secSpawnEnd,
				"Stores shed",
				sb,
				10,
				3.2,
				"x",
				L.sidingGreen,
				L.trim,
				L.tin,
				H
			)
			local team = look(H.side.team, "Wood01a", M.Wood)
			door(f, sb, "+z", -5, team, L.trim, H, 3.8, 7.4)
			door(f, sb, "+z", 5, team, L.trim, H, 3.8, 7.4)
			window(f, sb, "-z", -6, 5.2, L.trim, H)
			window(f, sb, "-z", 6, 5.2, L.trim, H)
			window(f, sb, "-x", 75, 5.2, L.trim, H, 2.4, 2.4)
			window(f, sb, "+x", 75, 5.2, L.trim, H, 2.4, 2.4)
			rivals("R_Crate6", secSpawnEnd, CFrame.new(20.6, 0, 80), H)
			rivals("R_Crate4", secSpawnEnd, CFrame.new(26.4, 0, 80.2) * yaw(12), H)
			col("Crates", V(17.6, 0, 77.8), V(28.6, 4, 82.4), H)
			for i, p in { { -39.6, 73.0 }, { -36.9, 73.5 }, { -38.4, 75.7 } } do
				kit("CNBarrel", secSpawnEnd, CFrame.new(p[1], -0.02, p[2]) * yaw(i * 25), H)
			end
			col("Barrels", V(-41.0, 0, 71.6), V(-35.5, 3.45, 77.1), H)
		end
		local SPAWNS = { { -12, 88 }, { 0, 90 }, { 12, 88 }, { -6, 85 }, { 6, 85 } }
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
		bound(V(70.3, -10, -97), V(72.3, 60, 97))
		bound(V(-72.3, -10, 5.1), V(-70.3, 60, 97))
		bound(V(-72.3, -10, -97), V(-70.3, 60, -5.1))
		bound(V(-72.3, 13, -5.1), V(-70.3, 60, 5.1))
		bound(V(-72, -10, 96.3), V(72, 60, 98.3))
		bound(V(-72, -10, -98.3), V(72, 60, -96.3))
		bound(V(-72, 60, -98), V(72, 62, 98))
		local stage = part(map, "WinnerStage", V(4, 0.2, 4), CFrame.new(-14, 1.1, 44.6), L.none)
		stage.Transparency = 1
		stage.CastShadow = false
		stage.CanCollide = false
		stage.CanQuery = false
		CollectionService:AddTag(stage, "WinnerStage")
	end

	--------------------------------------------------------------------------------------------- lighting
	local lightCfg = Instance.new("Configuration")
	lightCfg.Name = "Lighting"
	CollectionService:AddTag(lightCfg, "GGAsset_MatchMaps_426")
	CollectionService:AddTag(lightCfg, "GauntletAuthoredData")
	lightCfg:SetAttribute("Ambient", Color3.fromRGB(138, 112, 96))
	lightCfg:SetAttribute("Brightness", 3)
	lightCfg:SetAttribute("ClockTime", 14.2)
	lightCfg:SetAttribute("ColorShift_Top", Color3.fromRGB(255, 226, 190))
	lightCfg:SetAttribute("EnvironmentDiffuseScale", 0.45)
	lightCfg:SetAttribute("EnvironmentSpecularScale", 0.1)
	lightCfg:SetAttribute("ExposureCompensation", 0.05)
	lightCfg:SetAttribute("GeographicLatitude", 30)
	lightCfg:SetAttribute("OutdoorAmbient", Color3.fromRGB(176, 146, 124))
	lightCfg:SetAttribute("ShadowSoftness", 0.2)
	lightCfg.Parent = map
	map:SetAttribute("KillDepth", 20)
	map:SetAttribute(
		"LayoutVersion",
		"v1 2026-11-21 sun-baked mining outpost in a red canyon, RIVALS style"
	)
	local fx = folder(map, "LightingFx")
	local atm = Instance.new("Atmosphere")
	atm.Density = 0.28
	atm.Offset = 0.15
	atm.Haze = 1.4
	atm.Glare = 0.25
	atm.Color = Color3.fromRGB(236, 196, 156)
	atm.Decay = Color3.fromRGB(196, 120, 88)
	atm.Parent = fx
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.4
	bloom.Size = 24
	bloom.Threshold = 1.6
	bloom.Parent = fx
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "Grade"
	cc.Contrast = 0.08
	cc.Saturation = 0.14
	cc.Brightness = 0.02
	cc.TintColor = Color3.fromRGB(255, 246, 236)
	cc.Parent = fx

	-- kit parts wear the Parts' RIVALS variants (Westown: meshes and Parts share variants so joins don't show)
	for _, d in map:GetDescendants() do
		if d:IsA("MeshPart") then
			local n = d.Name
			if string.match(n, "_CN_WoodLight") then
				d.Material = M.WoodPlanks
				d.MaterialVariant = "WoodPlank_01b"
				d.Color = hex("8A6446")
			elseif string.match(n, "_CN_Wood") then
				d.Material = M.Wood
				d.MaterialVariant = "Wood01a"
			elseif string.match(n, "_CN_Iron") or string.match(n, "_CN_Steel") then
				d.Material = M.Metal
				d.MaterialVariant = "Metal 2022"
			elseif string.match(n, "_CN_Concrete") then
				d.MaterialVariant = "Concrete-01a"
			elseif string.match(n, "_CN_Lamp") then
				d.Color = hex("B08A55")
			end
		end
	end

	map.Parent = workspace
	return string.format("CanyonOutpost built (chunks <= %d): %d parts", UPTO, count)
end
