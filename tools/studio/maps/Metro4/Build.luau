--!strict
-- Metro4 (large map, 2v2-3v3), the whole build (2026-11-20). Plan, RIVALS Big Station study, layout and build log:
-- vault/01 Design/Maps/Metro4.md. Layout rows mirror tools/maps/metro4_layout.py (the A half is turned 180 degrees
-- for team B). Match place only, edit mode. Returns a function; run it with require(<a clone of this module>)().
--
-- Built the Wharf way (owner 2026-11-20): Parts on the 5-stud module, carved ends, our own soft MaterialVariants
-- (Metro_Tile / Metro_Brick / Metro_Facade + Wharf_*), lively colours (trains striped in each half's colour: A blue,
-- B green; a yellow footbridge; brick ticket halls; cream shops), no text signs. The hall has a faceted glazed roof on
-- trusses and open ends: the tracks run out into a city with tunnel portals, mountains beyond.
-- Collision: layout boxes (invisible) for trains, blocks, low cover; floors, steps, parapets, columns, bridge are
-- their own collision. Contract: Spawns (ArenaSpawn_A/B), Barriers (empty), Bounds (+25 ceiling under the roof),
-- KillDepth + Lighting (authored data 413 / 414), LightingFx, WinnerStage.

local CollectionService = game:GetService("CollectionService")
local MaterialService = game:GetService("MaterialService")
local ServerStorage = game:GetService("ServerStorage")

local ORIGIN = CFrame.new(6000, 200, 12500) -- concourse floor at the hall centre
local ROT = CFrame.Angles(0, math.pi, 0)
local BED = -2.5

local function hex(h: string): Color3
	return Color3.fromHex(h)
end
-- Palette v2 (owner 2026-11-20 on v1: "some colours are too bright", "too cartoony"): muted, earthy, like a real
-- station dressed the RIVALS way (beige / stone / brick / charcoal, colour only in small doses); side colours dulled.
local C = {
	tile = hex("A8A296"),
	coping = hex("9C968B"),
	concrete = hex("9C978E"),
	concreteDark = hex("767169"),
	ballast = hex("6E675F"),
	sleeper = hex("8A857C"),
	rail = hex("55595F"),
	line = hex("B39545"),
	steel = hex("3D3B38"), -- the hall's painted steel, warm charcoal
	steelLight = hex("5A5752"),
	yellow = hex("B8913E"), -- the footbridge, ochre
	yellowDark = hex("8A6B2C"),
	brick = hex("9E5A45"),
	brickBase = hex("7E786F"),
	stone = hex("D3C9B4"), -- cream stone dressings (surrounds, quoins, cornices)
	render = hex("CFC4AD"),
	glass = hex("2B323C"),
	roofGlass = hex("C3D3DB"),
	trainBody = hex("C4C8C6"),
	trainSkirt = hex("4A4F57"),
	trainRoof = hex("A9AEB3"),
	rubber = hex("2B2D31"),
	timber = hex("A98762"),
	timberDark = hex("7E6447"),
	soil = hex("4F4236"),
	bush = hex("5E7F4C"),
	bushDark = hex("4C6A3E"),
	asphalt = hex("4A4D53"),
	ground = hex("A9A398"),
	land = hex("7E9468"),
}
local SIDE = {
	A = { paint = hex("4A6E9A"), dark = hex("34506F") }, -- muted blue
	B = { paint = hex("5E8A62"), dark = hex("436647") }, -- muted green
}

local VARIANTS = {
	Metro_Tile = { "Slate", 5, "71874475147084", "82534382218216" },
	Metro_Brick = { "Brick", 6, "87423292374546", "102189820953792" },
	Metro_Facade = { "Concrete", 18, "103645488773834", "77884985112296" },
	Metro_Facade2 = { "Concrete", 24, "73959586817999", "113011737919437" }, -- framed windows, 8 studs a storey
	-- the Wharf v2 set (soft), shared
	Wharf_Concrete = { "Concrete", 10, "98131730598502", "101527228918911" },
	Wharf_Asphalt = { "Asphalt", 8, "129833585742683", "87143270766313" },
	Wharf_Plank = { "WoodPlanks", 5, "93605016079302", "106545793761281" },
	Wharf_Ribbed = { "Metal", 4, "135858628433618", "72834346090990" },
	Wharf_Plate = { "DiamondPlate", 5, "116955307704363", "89970433895475" },
}

type Look = { color: Color3, mat: Enum.Material?, variant: string?, glass: boolean? }
local function look(color: Color3, variant: string?, mat: Enum.Material?): Look
	return { color = color, variant = variant, mat = mat }
end
local L = {
	tile = look(C.tile, "Metro_Tile", Enum.Material.Slate),
	coping = look(C.coping, "Wharf_Concrete", Enum.Material.Concrete),
	concrete = look(C.concrete, "Wharf_Concrete", Enum.Material.Concrete),
	concreteDark = look(C.concreteDark, "Wharf_Concrete", Enum.Material.Concrete),
	ballast = look(C.ballast, "Wharf_Asphalt", Enum.Material.Asphalt),
	asphalt = look(C.asphalt, "Wharf_Asphalt", Enum.Material.Asphalt),
	ground = look(C.ground, "Wharf_Concrete", Enum.Material.Concrete),
	sleeper = look(C.sleeper),
	rail = look(C.rail),
	line = look(C.line),
	steel = look(C.steel),
	steelLight = look(C.steelLight),
	yellow = look(C.yellow, "Wharf_Plate", Enum.Material.DiamondPlate),
	yellowFlat = look(C.yellow),
	yellowDark = look(C.yellowDark),
	brick = look(C.brick, "Metro_Brick", Enum.Material.Brick),
	brickBase = look(C.brickBase, "Wharf_Concrete", Enum.Material.Concrete),
	render = look(C.render, "Wharf_Concrete", Enum.Material.Concrete),
	stone = look(C.stone, "Wharf_Concrete", Enum.Material.Concrete),
	glass = look(C.glass),
	trainBody = look(C.trainBody),
	trainSkirt = look(C.trainSkirt),
	trainRoof = look(C.trainRoof),
	rubber = look(C.rubber),
	plank = look(C.timber, "Wharf_Plank", Enum.Material.WoodPlanks),
	plankDark = look(C.timberDark, "Wharf_Plank", Enum.Material.WoodPlanks),
	soil = look(C.soil),
	bush = look(C.bush),
	bushDark = look(C.bushDark),
	plate = look(C.steelLight, "Wharf_Plate", Enum.Material.DiamondPlate),
}

local function ensureVariants()
	for name, v in VARIANTS do
		local found = MaterialService:FindFirstChild(name)
		local mv: MaterialVariant
		if found and found:IsA("MaterialVariant") then
			mv = found
		else
			mv = Instance.new("MaterialVariant")
			mv.Name = name
			mv.Parent = MaterialService
		end
		mv.BaseMaterial = (Enum.Material :: any)[v[1]]
		mv.StudsPerTile = v[2]
		mv.ColorMap = "rbxassetid://" .. v[3]
		mv.NormalMap = "rbxassetid://" .. v[4]
		mv.RoughnessMap = ""
		mv.MaterialPattern = Enum.MaterialPattern.Regular
	end
end

return function(): string
	assert(game.PlaceId == 133387545285290, "Metro4: not the match place")
	ensureVariants()
	local old = workspace:FindFirstChild("Metro4")
	if old then
		old:Destroy()
	end
	local map = Instance.new("Model")
	map.Name = "Metro4"
	map.WorldPivot = ORIGIN
	CollectionService:AddTag(map, "GGAsset_MatchMaps_413")
	CollectionService:AddTag(map, "GauntletAuthoredData")

	local function folder(parent: Instance, name: string): Folder
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
		return f
	end
	local secCollision = folder(map, "Collision")
	local secStructure = folder(map, "Structure")
	local secTrains = folder(map, "Trains")
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
		p.CastShadow = math.max(size.X, size.Y, size.Z) >= 6
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
	local function col(
		name: string,
		x: number,
		z: number,
		sx: number,
		sz: number,
		h: number,
		base: number,
		T: CFrame,
		mat: Enum.Material
	): BasePart
		local p = part(
			secCollision,
			name,
			Vector3.new(sx, h - base, sz),
			T * CFrame.new(x, (base + h) / 2, z),
			{ color = C.concrete, mat = mat },
			true
		)
		p.Transparency = 1
		p.CastShadow = false
		return p
	end
	local function beam(
		parent: Instance,
		name: string,
		a: Vector3,
		b: Vector3,
		w: number,
		h: number,
		lk: Look,
		solid: boolean?
	)
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		return part(parent, name, Vector3.new(w, h, len), CFrame.lookAt(mid, b), lk, solid)
	end
	local function kit(
		lib: string,
		piece: string,
		parent: Instance,
		cf: CFrame,
		name: string?
	): Model
		local src = ServerStorage.MapKit:FindFirstChild(lib)
			and ServerStorage.MapKit[lib]:FindFirstChild(piece)
		assert(src and src:IsA("Model"), "missing kit piece " .. lib .. "." .. piece)
		local m = src:Clone()
		m.Name = name or piece
		m:PivotTo(ORIGIN * cf)
		m.Parent = parent
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				count += 1
			end
		end
		return m
	end

	local halves =
		{ { T = CFrame.identity, tag = "", side = SIDE.A }, { T = ROT, tag = "'", side = SIDE.B } }

	------------------------------------------------------------------------------------------------ floors
	local floors = folder(secStructure, "Floors")
	for _, h in halves do
		-- concourse tiles, the platform coping (with a small lip over the bed), the yellow line
		box(
			floors,
			"Concourse",
			Vector3.new(-115, -4, 17.2),
			Vector3.new(115, 0, 105),
			L.tile,
			true,
			h.T
		)
		box(
			floors,
			"Coping",
			Vector3.new(-115, -0.6, 15.6),
			Vector3.new(115, 0, 17.2),
			L.coping,
			true,
			h.T
		)
		box(
			floors,
			"Platform face",
			Vector3.new(-115, -4, 16),
			Vector3.new(115, -0.6, 17.2),
			L.concreteDark,
			true,
			h.T
		)
		box(
			floors,
			"Safety line",
			Vector3.new(-115, -0.02, 18.4),
			Vector3.new(115, 0.04, 19),
			L.line,
			false,
			h.T
		)
	end
	-- the bed (ballast), running out of the hall to the tunnel portals
	box(
		floors,
		"Track bed",
		Vector3.new(-420, -5, -15.6),
		Vector3.new(420, BED, 15.6),
		L.ballast,
		true
	)
	-- the city ground round the hall (the tracks run in a cutting between)
	for _, h in halves do
		box(
			floors,
			"City ground",
			Vector3.new(-700, -4, 105),
			Vector3.new(700, 0, 700),
			L.ground,
			true,
			h.T
		)
		box(
			floors,
			"City ground",
			Vector3.new(115, -4, 16),
			Vector3.new(700, 0, 105),
			L.ground,
			true,
			h.T
		)
		box(
			floors,
			"City ground",
			Vector3.new(-700, -4, 16),
			Vector3.new(-115, 0, 105),
			L.ground,
			true,
			h.T
		)
		box(
			floors,
			"Street",
			Vector3.new(-700, -0.02, 150),
			Vector3.new(700, 0.04, 175),
			L.asphalt,
			false,
			h.T
		)
		box(
			floors,
			"Cutting wall",
			Vector3.new(115, -4, 15.6),
			Vector3.new(420, 0, 16),
			L.concreteDark,
			true,
			h.T
		)
		box(
			floors,
			"Cutting wall",
			Vector3.new(-420, -4, 15.6),
			Vector3.new(-115, 0, 16),
			L.concreteDark,
			true,
			h.T
		)
	end
	-- rails and sleepers (two tracks at z +-11)
	local track = folder(secStructure, "Track")
	for _, tc in { 11, -11 } do
		for _, rz in { tc - 2.2, tc + 2.2 } do
			box(
				track,
				"Rail",
				Vector3.new(-420, BED + 0.35, rz - 0.25),
				Vector3.new(420, BED + 0.95, rz + 0.25),
				L.rail
			)
		end
		for x = -200, 200, 5 do
			box(
				track,
				"Sleeper",
				Vector3.new(x - 0.6, BED, tc - 3.6),
				Vector3.new(x + 0.6, BED + 0.35, tc + 3.6),
				L.sleeper
			)
		end
	end
	task.wait()

	------------------------------------------------------------------------------------------------ trains
	-- a metro car (v3, owner: "the wheel section and the front made in Blender"): Blender bogies (Metro4 kit) on the
	-- rails carrying a Parts body (white, window band, stripe, doors in the side's paint, chamfered roof, AC), a sill
	-- skirt with underframe boxes between the bogies, and a Blender cab front at a driving end (the Parts body stops
	-- 2 short of the end there and the cab's joint plane meets it) or a gangway. Collision: the layout box (+ the nose).
	local function recolor(m: Instance, key: string, c: Color3)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and string.find(d.Name, key, 1, true) then
				d.Color = c
			end
		end
	end
	local RAIL_TOP = BED + 0.95
	local function car(
		name: string,
		cx: number,
		tc: number,
		len: number,
		side: { paint: Color3, dark: Color3 },
		T: CFrame,
		noseWest: boolean,
		noseEast: boolean
	)
		local f = folder(secTrains, name)
		local hx = len / 2
		col(name, cx, tc, len, 10, 10, BED, T, Enum.Material.Metal)
		local paint = look(side.paint)
		local dark = look(side.dark)
		local xw = cx - hx + (if noseWest then 2 else 0) -- the Parts body's ends
		local xe = cx + hx - (if noseEast then 2 else 0)
		for _, bx in { cx - hx + 8, cx + hx - 8 } do
			kit("Metro4", "Bogie", f, T * CFrame.new(bx, RAIL_TOP, tc))
		end
		-- sill and underframe equipment between the bogies (the bogies stay in view)
		box(
			f,
			"Sill",
			Vector3.new(cx - hx + 12.3, -0.25, tc - 4.5),
			Vector3.new(cx + hx - 12.3, 0.3, tc + 4.5),
			L.trainSkirt,
			false,
			T
		)
		for _, e in
			{
				{ -9.5, 4.6, 3.4, L.trainSkirt },
				{ -2.5, 6, 3.0, L.rubber },
				{ 5.5, 5, 3.6, L.trainSkirt },
			}
		do
			box(
				f,
				"Underframe box",
				Vector3.new(cx + e[1] - e[2] / 2, -1.35, tc - e[3]),
				Vector3.new(cx + e[1] + e[2] / 2, -0.25, tc + e[3]),
				e[4],
				false,
				T
			)
		end
		box(
			f,
			"Body",
			Vector3.new(xw, 0.3, tc - 4.8),
			Vector3.new(xe, 9.4, tc + 4.8),
			L.trainBody,
			false,
			T
		)
		box(
			f,
			"Roof",
			Vector3.new(xw + (if noseWest then 0 else 0.4), 9.4, tc - 4.2),
			Vector3.new(xe - (if noseEast then 0 else 0.4), 10, tc + 4.2),
			L.trainRoof,
			false,
			T
		)
		local rx0 = xw + (if noseWest then 0 else 0.4)
		local rx1 = xe - (if noseEast then 0 else 0.4)
		for _, s in { -1, 1 } do
			-- roof edge chamfer (a wedge on the body top, sloping out)
			wedge(
				f,
				"Roof chamfer",
				Vector3.new(rx1 - rx0, 0.6, 0.6),
				T
					* CFrame.new((rx0 + rx1) / 2, 9.7, tc + s * 4.5)
					* CFrame.Angles(0, if s > 0 then math.pi else 0, 0),
				L.trainRoof
			)
			local zf = tc + s * 4.8
			box(
				f,
				"Window band",
				Vector3.new(xw + 1.5, 4.4, zf),
				Vector3.new(xe - 1.5, 7.2, zf + 0.08 * s),
				L.glass,
				false,
				T
			)
			box(
				f,
				"Stripe",
				Vector3.new(xw + (if noseWest then 0 else 0.2), 1.8, zf),
				Vector3.new(xe - (if noseEast then 0 else 0.2), 2.8, zf + 0.1 * s),
				paint,
				false,
				T
			)
			for _, dx in { -14, 0, 14 } do
				local x = cx + dx
				box(
					f,
					"Door",
					Vector3.new(x - 2, 0.6, zf),
					Vector3.new(x + 2, 8.2, zf + 0.16 * s),
					paint,
					false,
					T
				)
				box(
					f,
					"Door glass",
					Vector3.new(x - 1.5, 4.6, zf),
					Vector3.new(x + 1.5, 7.2, zf + 0.24 * s),
					L.glass,
					false,
					T
				)
				box(
					f,
					"Door seam",
					Vector3.new(x - 0.06, 0.7, zf),
					Vector3.new(x + 0.06, 8.1, zf + 0.26 * s),
					dark,
					false,
					T
				)
			end
		end
		box(
			f,
			"AC unit",
			Vector3.new(cx - 5, 10, tc - 3),
			Vector3.new(cx + 5, 11, tc + 3),
			L.trainRoof,
			false,
			T
		)
		box(
			f,
			"AC grille",
			Vector3.new(cx - 4.4, 11, tc - 2.4),
			Vector3.new(cx + 4.4, 11.15, tc + 2.4),
			L.trainSkirt,
			false,
			T
		)
		-- ends: the Blender cab (nose beyond the collision box gets its own) or a gangway bellows
		for _, e in { { -1, noseWest }, { 1, noseEast } } do
			local s, nose = e[1], e[2]
			local xend = cx + s * hx
			if nose then
				local joint = xend - s * 2
				local cab = kit(
					"Metro4",
					"CabFront",
					f,
					T
						* CFrame.new(joint, 0.3, tc)
						* CFrame.Angles(0, if s > 0 then 0 else math.pi, 0)
				)
				recolor(cab, "Paint", side.paint)
				col(name .. " nose", xend + s * 0.6, tc, 1.2, 9.6, 10, BED, T, Enum.Material.Metal)
			else
				box(
					f,
					"Gangway",
					Vector3.new(math.min(xend, xend + s * 0.8), 1, tc - 2.8),
					Vector3.new(math.max(xend, xend + s * 0.8), 8.2, tc + 2.8),
					L.rubber,
					false,
					T
				)
				box(
					f,
					"End skirt",
					Vector3.new(math.min(xend - s * 3.6, xend), -0.25, tc - 4.5),
					Vector3.new(math.max(xend - s * 3.6, xend), 0.3, tc + 4.5),
					L.trainSkirt,
					false,
					T
				)
			end
		end
	end
	for _, h in halves do
		car("Car 1" .. h.tag, -83, 11, 48, h.side, h.T, true, false)
		car("Car 2" .. h.tag, -28, 11, 48, h.side, h.T, false, true)
		-- the yellow work wagon on the open stretch of the track
		local f = folder(secTrains, "Work wagon" .. h.tag)
		col("Work wagon" .. h.tag, 75, 11, 15, 10, 10, BED, h.T, Enum.Material.Metal)
		box(
			f,
			"Frame",
			Vector3.new(67.5, -0.25, 6.4),
			Vector3.new(82.5, 0.3, 15.6),
			L.trainSkirt,
			false,
			h.T
		)
		for _, bx in { 71, 79 } do
			kit("Metro4", "Bogie", f, h.T * CFrame.new(bx, RAIL_TOP, 11))
		end
		box(
			f,
			"Van",
			Vector3.new(67.5, 0.3, 6),
			Vector3.new(82.5, 9.4, 16),
			look(C.yellow, "Wharf_Ribbed", Enum.Material.Metal),
			false,
			h.T
		)
		box(
			f,
			"Van roof",
			Vector3.new(67.9, 9.4, 6.6),
			Vector3.new(82.1, 10, 15.4),
			L.yellowDark,
			false,
			h.T
		)
		for _, s in { -1, 1 } do
			wedge(
				f,
				"Roof chamfer",
				Vector3.new(14.2, 0.6, 0.6),
				h.T
					* CFrame.new(75, 9.7, 11 + s * 4.7)
					* CFrame.Angles(0, if s > 0 then math.pi else 0, 0),
				L.yellowDark
			)
			box(
				f,
				"Hazard band",
				Vector3.new(67.7, 0.8, 11 + s * 5),
				Vector3.new(82.3, 1.6, 11 + s * 5.1),
				L.rubber,
				false,
				h.T
			)
		end
	end
	task.wait()

	-------------------------------------------------------------------------------------------- footbridge
	local bridge = folder(secStructure, "Footbridge")
	box(bridge, "Deck", Vector3.new(-3, 13, -38), Vector3.new(3, 14, 38), L.yellow, true)
	-- v3 (owner: "floating columns under the bridge"): plate girders (web + bottom flange + stiffeners) that sit on
	-- crossheads, and each crosshead sits on its column cap with knee braces, so every member carries the next
	for _, sx in { -1, 1 } do
		local wa, wb = if sx > 0 then 2.45 else -2.75, if sx > 0 then 2.75 else -2.45
		box(
			bridge,
			"Girder web",
			Vector3.new(wa, 11.25, -38),
			Vector3.new(wb, 13, 38),
			L.yellowDark,
			false
		)
		local fa, fb = if sx > 0 then 2.0 else -3.2, if sx > 0 then 3.2 else -2.0
		box(
			bridge,
			"Girder flange",
			Vector3.new(fa, 10.95, -38),
			Vector3.new(fb, 11.25, 38),
			L.yellowDark,
			false
		)
		for z = -36, 36, 6 do
			local ta, tb = if sx > 0 then 2.75 else -2.95, if sx > 0 then 2.95 else -2.75
			box(
				bridge,
				"Stiffener",
				Vector3.new(ta, 11.25, z - 0.12),
				Vector3.new(tb, 12.96, z + 0.12),
				L.yellowDark,
				false
			)
		end
	end
	-- side parapets (once, for both halves): the east side is open where A's stair leaves (z 32..38), the west
	-- side where B's does (z -38..-32); the rail caps stop short of the end caps
	local ribY = look(C.yellow, "Wharf_Ribbed", Enum.Material.Metal)
	box(bridge, "Parapet", Vector3.new(3, 14, -37.6), Vector3.new(3.4, 17.5, 32), ribY, true)
	box(bridge, "Parapet", Vector3.new(-3.4, 14, -32), Vector3.new(-3, 17.5, 37.6), ribY, true)
	box(
		bridge,
		"Rail cap",
		Vector3.new(2.9, 17.5, -37.5),
		Vector3.new(3.5, 17.8, 32),
		L.yellowDark,
		false
	)
	box(
		bridge,
		"Rail cap",
		Vector3.new(-3.5, 17.5, -32),
		Vector3.new(-2.9, 17.8, 37.5),
		L.yellowDark,
		false
	)
	-- glazed upper sides to +21 and a light roof (owner rule: no unplanned perches): without them a player hops the
	-- 3.5 parapet and drops onto the train roofs. The glass blocks players, not bullets (CanQuery off).
	local function glassSide(a0: Vector3, b0: Vector3)
		local g = box(
			bridge,
			"Side glass",
			a0,
			b0,
			{ color = C.roofGlass, mat = Enum.Material.Glass },
			true
		)
		g.CanQuery = false
		g.Transparency = 0.5
		g.CastShadow = false
	end
	glassSide(Vector3.new(3.05, 17.8, -37.6), Vector3.new(3.35, 21, 32))
	glassSide(Vector3.new(-3.35, 17.8, -32), Vector3.new(-3.05, 21, 37.6))
	for z = -36, 36, 6 do
		if z < 32 then
			box(
				bridge,
				"Glazing post",
				Vector3.new(3, 17.8, z - 0.15),
				Vector3.new(3.4, 21, z + 0.15),
				L.yellowDark,
				false
			)
		end
		if z > -32 then
			box(
				bridge,
				"Glazing post",
				Vector3.new(-3.4, 17.8, z - 0.15),
				Vector3.new(-3, 21, z + 0.15),
				L.yellowDark,
				false
			)
		end
	end
	box(
		bridge,
		"Roof",
		Vector3.new(-3.8, 21, -38.4),
		Vector3.new(3.8, 21.6, 38.4),
		look(C.steelLight, "Wharf_Ribbed", Enum.Material.Metal),
		true
	)
	for _, x in { -3.6, 3.6 } do
		wedge(
			bridge,
			"Roof edge",
			Vector3.new(76.8, 0.4, 0.4),
			CFrame.new(x, 21.8, 0)
				* CFrame.Angles(0, if x > 0 then -math.pi / 2 else math.pi / 2, 0)
				* CFrame.Angles(0, if x > 0 then 0 else 0, 0),
			L.steelLight
		)
	end
	for _, h in halves do
		-- columns (on the platform, under the deck and the landing): foot, column, cap, crosshead under both girder
		-- flanges, knee braces between column and crosshead; then parapets and the stair down into the concourse
		for _, c in { { 25, 1.0 }, { 37, 0.8 } } do
			local cz, r = c[1], c[2]
			box(
				bridge,
				"Column foot",
				Vector3.new(-r - 0.6, 0, cz - r - 0.6),
				Vector3.new(r + 0.6, 0.6, cz + r + 0.6),
				L.concreteDark,
				false,
				h.T
			)
			box(
				bridge,
				"Column",
				Vector3.new(-r, 0.6, cz - r),
				Vector3.new(r, 9.6, cz + r),
				L.yellowDark,
				true,
				h.T
			)
			box(
				bridge,
				"Column cap",
				Vector3.new(-r - 0.3, 9.6, cz - r - 0.3),
				Vector3.new(r + 0.3, 10.0, cz + r + 0.3),
				L.yellowDark,
				false,
				h.T
			)
			box(
				bridge,
				"Crosshead",
				Vector3.new(-3.4, 10.0, cz - r),
				Vector3.new(3.4, 10.95, cz + r),
				L.yellow,
				false,
				h.T
			)
			for _, sx in { -1, 1 } do
				-- knee: flat top under the crosshead, vertical face on the column, sloping away underneath
				local p = Vector3.new(sx * (r + 0.8), 9.2, cz)
				part(
					bridge,
					"Knee",
					Vector3.new(2 * r - 0.2, 1.6, 1.6),
					h.T * CFrame.lookAt(p, p + Vector3.new(sx, 0, 0)) * CFrame.Angles(0, 0, math.pi),
					L.yellowDark,
					false,
					"WedgePart"
				)
			end
		end
		box(
			bridge,
			"Parapet",
			Vector3.new(-3, 14, 37.6),
			Vector3.new(3, 17.5, 38),
			look(C.yellow, "Wharf_Ribbed", Enum.Material.Metal),
			true,
			h.T
		)
		box(
			bridge,
			"Rail cap",
			Vector3.new(-3.1, 17.5, 37.5),
			Vector3.new(3.1, 17.8, 38.1),
			L.yellowDark,
			false,
			h.T
		)
		local eg = box(
			bridge,
			"End glass",
			Vector3.new(-3.05, 17.8, 37.65),
			Vector3.new(3.05, 21, 37.95),
			{ color = C.roofGlass, mat = Enum.Material.Glass },
			true,
			h.T
		)
		eg.CanQuery = false
		eg.Transparency = 0.5
		eg.CastShadow = false
		-- the stair opening keeps its glass up to the roof too (a door-high gap, 3.4 wide, under a lintel)
		-- stair: x 3 -> 31 at z 32..38, 14 down to 0 (a smooth wedge for the walk, treads, stringers, handrails)
		local ramp = wedge(
			secCollision,
			"Bridge stair" .. h.tag,
			Vector3.new(6, 14, 28),
			h.T * CFrame.new(17, 7, 35) * CFrame.Angles(0, -math.pi / 2, 0),
			{ color = C.steel, mat = Enum.Material.Metal },
			true
		)
		ramp.Transparency = 1
		ramp.CastShadow = false
		for k = 1, 14 do
			local x1 = 31 - 2 * (k - 1)
			box(
				bridge,
				"Tread",
				Vector3.new(x1 - 2, k - 0.8, 32.3),
				Vector3.new(x1, k - 0.4, 37.7),
				L.plate,
				false,
				h.T
			)
			box(
				bridge,
				"Riser",
				Vector3.new(x1 - 0.12, math.max(0, k - 1.4), 32.3),
				Vector3.new(x1, k - 0.8, 37.7),
				L.yellowDark,
				false,
				h.T
			)
		end
		local ang = math.atan2(14, 28)
		local slen = math.sqrt(28 * 28 + 14 * 14)
		for _, zz in { 32.15, 37.85 } do
			part(
				bridge,
				"Stringer",
				Vector3.new(slen - 0.6, 1, 0.3),
				h.T * CFrame.new(17, 7 - 0.3, zz) * CFrame.Angles(0, 0, -ang),
				L.yellowDark
			)
			part(
				bridge,
				"Handrail",
				Vector3.new(slen - 0.8, 0.3, 0.24),
				h.T * CFrame.new(17, 7 + 3.3, zz) * CFrame.Angles(0, 0, -ang),
				L.yellowDark
			)
			for k = 0, 3 do
				local xx = 29.5 - k * 8.5
				local yy = (31 - xx) / 2
				box(
					bridge,
					"Handrail post",
					Vector3.new(xx - 0.1, yy, zz - 0.1),
					Vector3.new(xx + 0.1, yy + 3.2, zz + 0.1),
					L.yellowDark,
					false,
					h.T
				)
			end
		end
	end
	task.wait()

	------------------------------------------------------------------------------------------ hall structure
	local hall = folder(secStructure, "Hall")
	-- the faceted roof profile across the hall (z, y): a train shed's arch made of straight segments
	local P =
		{ { -105, 26 }, { -75, 32 }, { -40, 37 }, { 0, 39 }, { 40, 37 }, { 75, 32 }, { 105, 26 } }
	local function roofY(z: number): number
		for i = 1, #P - 1 do
			local a, b = P[i], P[i + 1]
			if z >= a[1] and z <= b[1] then
				return a[2] + (b[2] - a[2]) * (z - a[1]) / (b[1] - a[1])
			end
		end
		return 26
	end
	local TRUSS = { -114, -90, -60, -30, 0, 30, 60, 90, 114 } -- the end trusses stand over the end columns (v3)
	for _, x in TRUSS do
		for i = 1, #P - 1 do
			local a, b = P[i], P[i + 1]
			local wTop = if i % 2 == 0 then 1.3 else 1.2
			local wBot = if i % 2 == 0 then 0.9 else 0.8
			beam(
				hall,
				"Top chord",
				Vector3.new(x, a[2], a[1]),
				Vector3.new(x, b[2], b[1]),
				wTop,
				1.6,
				L.steel
			)
			beam(
				hall,
				"Bottom chord",
				Vector3.new(x, a[2] - 2.6, a[1]),
				Vector3.new(x, b[2] - 2.6, b[1]),
				wBot,
				0.8,
				L.steel
			)
		end
		for i = 2, #P - 1 do
			box(
				hall,
				"Post",
				Vector3.new(x - 0.35, P[i][2] - 2.2, P[i][1] - 0.35),
				Vector3.new(x + 0.35, P[i][2] - 0.8, P[i][1] + 0.35),
				L.steelLight
			)
		end
	end
	-- glazing: one panel per bay per segment, resting on the chords (pale glass)
	for t = 1, #TRUSS - 1 do
		local xa, xb = TRUSS[t], TRUSS[t + 1]
		for i = 1, #P - 1 do
			local a, b = P[i], P[i + 1]
			local A = Vector3.new((xa + xb) / 2, a[2], a[1])
			local B = Vector3.new((xa + xb) / 2, b[2], b[1])
			local cf = CFrame.lookAt((A + B) / 2, B)
			local g = part(
				hall,
				"Roof glass",
				Vector3.new(xb - xa - 1.2, 0.3, (B - A).Magnitude),
				cf * CFrame.new(0, 0.95, 0),
				{ color = C.roofGlass, mat = Enum.Material.Glass }
			)
			g.Transparency = 0.45
			g.CastShadow = false
		end
	end
	-- purlins along the hall at the roof joints
	for i = 2, #P - 1 do
		box(
			hall,
			"Purlin",
			Vector3.new(-114.75, P[i][2] + 0.8, P[i][1] - 0.4),
			Vector3.new(114.75, P[i][2] + 1.4, P[i][1] + 0.4),
			L.steelLight
		)
	end
	for _, h in halves do
		-- platform columns (z 25) up to the bottom chord, with foot and capital (solid: they're cover)
		for _, x in { -114, -90, -60, -30, 30, 60, 90, 114 } do
			local top = roofY(25) - 2.6
			box(
				hall,
				"Column",
				Vector3.new(x - 1, 0, 24),
				Vector3.new(x + 1, top, 26),
				L.steel,
				true,
				h.T
			)
			box(
				hall,
				"Column foot",
				Vector3.new(x - 1.5, 0, 23.5),
				Vector3.new(x + 1.5, 0.7, 26.5),
				L.concreteDark,
				false,
				h.T
			)
			box(
				hall,
				"Column cap",
				Vector3.new(x - 1.5, top - 0.7, 23.5),
				Vector3.new(x + 1.5, top + 0.1, 26.5),
				L.steelLight,
				false,
				h.T
			)
		end
		-- the long walls: brick to 12 on a base course, glazed above to the roof, pilasters on the truss lines
		box(
			hall,
			"Wall base",
			Vector3.new(-115, 0, 105),
			Vector3.new(115, 1.5, 107),
			L.brickBase,
			true,
			h.T
		)
		box(
			hall,
			"Wall",
			Vector3.new(-115, 1.5, 105.4),
			Vector3.new(115, 12, 107),
			L.brick,
			true,
			h.T
		)
		box(
			hall,
			"Wall cornice",
			Vector3.new(-115, 12, 104.9),
			Vector3.new(115, 12.8, 107),
			L.concreteDark,
			false,
			h.T
		)
		local gl = part(
			hall,
			"Wall glass",
			Vector3.new(230, 13.6, 0.3),
			h.T * CFrame.new(0, 19.6, 106.2), -- 12.8 .. 26.4: its top runs into the eave beam
			{ color = C.roofGlass, mat = Enum.Material.Glass }
		)
		gl.Transparency = 0.45
		gl.CastShadow = false
		for x = -110, 110, 10 do
			if x % 30 == 0 then
				continue -- a pilaster stands there
			end
			box(
				hall,
				"Mullion",
				Vector3.new(x - 0.25, 12.8, 105.9),
				Vector3.new(x + 0.25, 26.2, 106.5),
				L.steelLight,
				false,
				h.T
			)
		end
		for _, x in TRUSS do
			-- the end pilasters reach 0.2 past the wall ends (no shared end face)
			local xa, xb = x - 1, x + 1
			if x >= 114 then
				xa, xb = 113, 115.2
			elseif x <= -114 then
				xa, xb = -115.2, -113
			end
			box(
				hall,
				"Pilaster",
				Vector3.new(xa, 0, 104.6),
				Vector3.new(xb, 26.2, 107.4),
				L.steel,
				false,
				h.T
			)
		end
		-- v4 (owner: "holes in the glass and connection"): an eave beam along the wall head closes the joint between
		-- the wall glazing and the roof glass (both run into it), with a cap plate and a gutter lip outside
		box(
			hall,
			"Eave beam",
			Vector3.new(-115.3, 25.6, 104.5),
			Vector3.new(115.3, 27.6, 107.9),
			L.steel,
			false,
			h.T
		)
		box(
			hall,
			"Eave cap",
			Vector3.new(-115.4, 27.6, 104.3),
			Vector3.new(115.4, 27.9, 108.1),
			L.steelLight,
			false,
			h.T
		)
		box(
			hall,
			"Gutter lip",
			Vector3.new(-115.35, 26.9, 107.9),
			Vector3.new(115.35, 27.6, 108.3),
			L.steelLight,
			false,
			h.T
		)
	end
	task.wait()

	--------------------------------------------------------------------------------------- concourse blocks
	local blocks = folder(secStructure, "Concourse")
	-- crates (v3): the shared Blender crate kit (Props: CrateA / CrateB, 5 x 5 units in four heights) set square to
	-- the grid (owner: "organised, even, lined up", so no random tilts); the invisible body is the collision
	local CRATE_KEY = { [3.5] = "35", [4.25] = "425", [5] = "5", [6] = "6" }
	local crateN = 0
	local function crate(
		parent: Instance,
		name: string,
		cx: number,
		cz: number,
		sx: number,
		sz: number,
		y0: number,
		hh: number,
		T: CFrame,
		_tilt: number?
	)
		local cf = T * CFrame.new(cx, y0 + hh / 2, cz)
		local body = part(parent, name, Vector3.new(sx, hh, sz), cf, L.plank, true)
		body.Transparency = 1
		body.CastShadow = false
		local key = CRATE_KEY[hh]
		assert(key, "no crate kit height " .. hh)
		local nx, nz = math.max(1, math.round(sx / 5)), math.max(1, math.round(sz / 5))
		local ux, uz = sx / nx, sz / nz
		for i = 1, nx do
			for j = 1, nz do
				crateN += 1
				local style = "A" -- v4: one style, one orientation everywhere
				local m = kit(
					"Props",
					"Crate" .. style .. "_" .. key,
					parent,
					T
						* CFrame.new(
							cx - sx / 2 + (i - 0.5) * ux + (i - (nx + 1) / 2) * 0.06,
							y0,
							cz - sz / 2 + (j - 0.5) * uz + (j - (nz + 1) / 2) * 0.06
						)
						* CFrame.Angles(0, 0, 0),
					"Crate"
				)
				local sc = math.min(ux, uz) / 5
				if sc < 0.9 then -- (4.8 footprints keep the full 5-stud crate: 0.1 overhang beats a lower top)
					m:ScaleTo(sc)
				end
			end
		end
	end
	for _, h in halves do
		local T = h.T
		local paint = look(h.side.paint)
		local paintDark = look(h.side.dark)
		-- ticket hall: brick on a base course, a cornice, tall windows and a door to the platform, a roof deck at
		-- +10 with a parapet (openings at the stair and over the crate steps)
		local th = folder(blocks, "Ticket hall" .. h.tag)
		local x0, x1, z0, z1 = -90, -50, 45, 80
		col(
			"Ticket hall" .. h.tag,
			(x0 + x1) / 2,
			(z0 + z1) / 2,
			x1 - x0,
			z1 - z0,
			10,
			0,
			T,
			Enum.Material.Brick
		)
		-- v2: a stone base, brick walls, cream stone quoins at the corners, framed windows on every face that shows,
		-- a framed door, a stepped stone cornice under the roof deck (gauntlet-build-style: every joint a transition)
		box(
			th,
			"Base",
			Vector3.new(x0 - 0.3, 0, z0 - 0.3),
			Vector3.new(x1 + 0.2, 1.2, z1 + 0.3),
			L.brickBase,
			false,
			T
		)
		box(th, "Walls", Vector3.new(x0, 1.2, z0), Vector3.new(x1, 9.2, z1), L.brick, false, T)
		for _, cx in { x0, x1 } do
			for _, cz in { z0, z1 } do
				local ax, bx =
					if cx == x0 then x0 - 0.25 else x1 - 1.4,
					if cx == x0 then x0 + 1.4 else x1 + 0.25
				local az, bz =
					if cz == z0 then z0 - 0.25 else z1 - 1.4,
					if cz == z0 then z0 + 1.4 else z1 + 0.25
				box(
					th,
					"Quoin",
					Vector3.new(ax, 1.2, az),
					Vector3.new(bx, 9.2, bz),
					L.stone,
					false,
					T
				)
			end
		end
		box(
			th,
			"Cornice",
			Vector3.new(x0 - 0.45, 9.2, z0 - 0.45),
			Vector3.new(x1 + 0.45, 9.6, z1 + 0.45),
			L.stone,
			false,
			T
		)
		box(
			th,
			"Cornice top",
			Vector3.new(x0 - 0.25, 9.6, z0 - 0.25),
			Vector3.new(x1 + 0.25, 10, z1 + 0.25),
			L.stone,
			false,
			T
		)
		box(
			th,
			"Roof deck",
			Vector3.new(x0, 9.96, z0),
			Vector3.new(x1, 10.02, z1),
			L.plate,
			false,
			T
		)
		-- a framed opening on a face: face "S" (z0, out -Z), "N" (z1, out +Z), "W" (x0, out -X); u along the face
		local function opening(
			face: string,
			u: number,
			w: number,
			y0: number,
			y1: number,
			fill: Look
		)
			local function rect(
				a0: number,
				a1: number,
				ya: number,
				yb: number,
				d0: number,
				d1: number,
				lk: Look
			)
				if face == "S" then
					box(
						th,
						"Surround",
						Vector3.new(a0, ya, z0 - d1),
						Vector3.new(a1, yb, z0 - d0),
						lk,
						false,
						T
					)
				elseif face == "N" then
					box(
						th,
						"Surround",
						Vector3.new(a0, ya, z1 + d0),
						Vector3.new(a1, yb, z1 + d1),
						lk,
						false,
						T
					)
				else
					box(
						th,
						"Surround",
						Vector3.new(x0 - d1, ya, a0),
						Vector3.new(x0 - d0, yb, a1),
						lk,
						false,
						T
					)
				end
			end
			rect(u - w / 2, u + w / 2, y0, y1, -0.02, 0.05, fill) -- the glass / door leaf, just proud of the brick
			rect(u - w / 2 - 0.6, u - w / 2, y0 - 0.1, y1 + 0.1, -0.02, 0.25, L.stone) -- jambs
			rect(u + w / 2, u + w / 2 + 0.6, y0 - 0.1, y1 + 0.1, -0.02, 0.25, L.stone)
			rect(u - w / 2 - 0.9, u + w / 2 + 0.9, y1 + 0.1, y1 + 0.9, -0.02, 0.35, L.stone) -- head
			if y0 > 1.5 then
				rect(u - w / 2 - 0.9, u + w / 2 + 0.9, y0 - 0.5, y0 - 0.1, -0.02, 0.45, L.stone) -- sill
			end
		end
		for _, wx in { -84, -76, -66 } do
			opening("S", wx, 4, 2.6, 7.8, L.glass)
			opening("N", wx, 4, 2.6, 7.8, L.glass)
		end
		opening("N", -58, 4, 2.6, 7.8, L.glass)
		opening("W", 68, 4, 2.6, 7.8, L.glass)
		opening("W", 75, 4, 2.6, 7.8, L.glass)
		opening("S", -56, 5, 1.2, 7.4, paint) -- the door to the platform
		local function parapet(a: Vector3, b: Vector3, ca: Vector3, cb: Vector3)
			box(th, "Parapet", a, b, L.brick, true, T)
			box(
				th,
				"Parapet coping",
				Vector3.new(ca.X, 13, ca.Z),
				Vector3.new(cb.X, 13.3, cb.Z),
				L.concreteDark,
				false,
				T
			)
		end
		parapet(
			Vector3.new(x0, 10, z0),
			Vector3.new(x1, 13, z0 + 0.8),
			Vector3.new(x0 - 0.15, 0, z0 - 0.15),
			Vector3.new(x1 + 0.15, 0, z0 + 0.95)
		) -- south
		parapet(
			Vector3.new(x0, 10, z1 - 0.8),
			Vector3.new(x1 - 5, 13, z1),
			Vector3.new(x0 - 0.15, 0, z1 - 0.95),
			Vector3.new(x1 - 4.85, 0, z1 + 0.15)
		) -- north (open over the stair top)
		parapet(
			Vector3.new(x0, 10, z0 + 0.8),
			Vector3.new(x0 + 0.8, 13, 48),
			Vector3.new(x0 - 0.15, 0, z0 + 0.95),
			Vector3.new(x0 + 0.95, 0, 48.15)
		) -- west, south of the crate opening
		parapet(
			Vector3.new(x0, 10, 57),
			Vector3.new(x0 + 0.8, 13, z1 - 0.8),
			Vector3.new(x0 - 0.15, 0, 56.85),
			Vector3.new(x0 + 0.95, 0, z1 - 0.95)
		) -- west, north of it
		parapet(
			Vector3.new(x1 - 0.8, 10, z0 + 0.8),
			Vector3.new(x1, 13, 72),
			Vector3.new(x1 - 0.95, 0, z0 + 0.95),
			Vector3.new(x1 + 0.15, 0, 72.15)
		) -- east, to the stair landing
		-- the outside stair (x -50..-45, z 60 -> 80, 0 -> 10), steel with yellow nosings
		local sr = wedge(
			secCollision,
			"Hall stair" .. h.tag,
			Vector3.new(5, 10, 20),
			T * CFrame.new(-47.5, 5, 70),
			{ color = C.steel, mat = Enum.Material.Metal },
			true
		)
		sr.Transparency = 1
		sr.CastShadow = false
		for k = 1, 10 do
			local zt = 60 + 2 * k
			box(
				th,
				"Tread",
				Vector3.new(-49.5, k - 0.8, zt - 2),
				Vector3.new(-45.3, k - 0.4, zt),
				L.plate,
				false,
				T
			)
		end
		local ang = math.atan2(10, 20)
		local slen = math.sqrt(500)
		for _, xx in { -49.85, -45.15 } do
			part(
				th,
				"Stringer",
				Vector3.new(0.3, 1, slen - 0.6),
				T * CFrame.new(xx, 4.7, 70) * CFrame.Angles(-ang, 0, 0),
				L.steel
			)
		end
		part(
			th,
			"Handrail",
			Vector3.new(0.24, 0.3, slen - 0.8),
			T * CFrame.new(-45.15, 8.2, 70) * CFrame.Angles(-ang, 0, 0),
			L.yellowDark
		)
		for k = 0, 3 do
			local zz = 61 + k * 6
			local yy = (zz - 60) / 2
			box(
				th,
				"Handrail post",
				Vector3.new(-45.25, yy, zz - 0.1),
				Vector3.new(-45.05, yy + 3.4, zz + 0.1),
				L.yellowDark,
				false,
				T
			)
		end
		-- v4: the west steps up to the deck are a two-level brick terrace built onto the hall (3.5 -> 7 -> deck 10),
		-- in the hall's own brick, base course and stone coping (owner: props must belong to something)
		for _, t in { { -100, -95, 3.5, "Terrace low" }, { -95, -90, 7, "Terrace high" } } do
			local x0, x1, ht, nm = t[1], t[2], t[3], t[4]
			box(th, nm, Vector3.new(x0, 0, 50), Vector3.new(x1, ht - 0.3, 55), L.brick, true, T)
			box(
				th,
				nm .. " base",
				Vector3.new(x0 - (if x0 < -99 then 0.1 else 0), 0, 49.9),
				Vector3.new(x1, 0.8, 55.1),
				L.brickBase,
				false,
				T
			)
			box(
				th,
				nm .. " coping",
				Vector3.new(x0 - 0.15, ht - 0.3, 49.85),
				Vector3.new(x1 + (if x1 == -90 then 0 else -0.05), ht, 55.15),
				L.stone,
				true,
				T
			)
		end

		-- shop block: cream render, shopfronts (dark glass) under sloped awnings in the side's paint, a flat roof
		local sh = folder(blocks, "Shops" .. h.tag)
		local sx0, sx1, sz0, sz1 = 57.5, 87.5, 32.5, 57.5
		col(
			"Shops" .. h.tag,
			(sx0 + sx1) / 2,
			(sz0 + sz1) / 2,
			sx1 - sx0,
			sz1 - sz0,
			10,
			0,
			T,
			Enum.Material.Concrete
		)
		-- v2: stone base, rendered walls, stone pilasters at the corners and between bays, a dark fascia over the
		-- shopfronts, framed shop windows (mullions + transom), awnings under the fascia, a stepped cornice
		box(
			sh,
			"Base",
			Vector3.new(sx0 - 0.3, 0, sz0 - 0.3),
			Vector3.new(sx1 + 0.3, 1, sz1 + 0.3),
			L.brickBase,
			false,
			T
		)
		box(sh, "Walls", Vector3.new(sx0, 1, sz0), Vector3.new(sx1, 9.3, sz1), L.render, false, T)
		box(
			sh,
			"Cornice",
			Vector3.new(sx0 - 0.45, 9.3, sz0 - 0.45),
			Vector3.new(sx1 + 0.45, 9.7, sz1 + 0.45),
			L.stone,
			false,
			T
		)
		box(
			sh,
			"Cornice top",
			Vector3.new(sx0 - 0.25, 9.7, sz0 - 0.25),
			Vector3.new(sx1 + 0.25, 10, sz1 + 0.25),
			L.stone,
			false,
			T
		)
		local fasciaLook = look(hex("3F3D3A"))
		box(
			sh,
			"Fascia",
			Vector3.new(sx0 + 1.2, 6.8, sz0 - 0.3),
			Vector3.new(sx1 - 1.2, 7.8, sz0),
			fasciaLook,
			false,
			T
		)
		box(
			sh,
			"Fascia",
			Vector3.new(sx0 - 0.3, 6.8, sz0 + 1.2),
			Vector3.new(sx0, 7.8, sz1 - 1.2),
			fasciaLook,
			false,
			T
		)
		for _, px in { sx0, 71, sx1 } do
			local a0, a1 = px - 0.6, px + 0.6
			local zb = sz0 + 0.02
			if px == sx0 then
				a0, a1 = sx0 - 0.4, sx0 + 1.2
				zb = sz0 + 1.2 -- the corner block wraps onto the west face
			elseif px == sx1 then
				a0, a1 = sx1 - 1.2, sx1 + 0.4
			end
			box(
				sh,
				"Pilaster",
				Vector3.new(a0, 1, sz0 - 0.4),
				Vector3.new(a1, 9.3, zb),
				L.stone,
				false,
				T
			)
		end
		for _, pz in { 45.5, sz1 - 0.6 } do
			box(
				sh,
				"Pilaster",
				Vector3.new(sx0 - 0.4, 1, pz - 0.6),
				Vector3.new(sx0 + 0.02, 9.3, pz + 0.6),
				L.stone,
				false,
				T
			)
		end
		local function shopfront(a0: number, a1: number, alongZ: boolean)
			local function r(
				u0: number,
				u1: number,
				ya: number,
				yb: number,
				d0: number,
				d1: number,
				lk: Look
			)
				if alongZ then
					box(
						sh,
						"Shopfront",
						Vector3.new(sx0 - d1, ya, u0),
						Vector3.new(sx0 - d0, yb, u1),
						lk,
						false,
						T
					)
				else
					box(
						sh,
						"Shopfront",
						Vector3.new(u0, ya, sz0 - d1),
						Vector3.new(u1, yb, sz0 - d0),
						lk,
						false,
						T
					)
				end
			end
			r(a0, a1, 1.4, 6.6, -0.02, 0.06, L.glass)
			r(a0 + 0.05, a1 - 0.05, 5.2, 5.45, -0.02, 0.16, fasciaLook) -- transom
			r(a0, a1, 1.0, 1.4, -0.02, 0.2, fasciaLook) -- stall riser
			local n = math.max(2, math.floor((a1 - a0) / 3.5))
			for k = 1, n - 1 do
				local u = a0 + (a1 - a0) * k / n
				r(u - 0.12, u + 0.12, 1.45, 6.55, -0.02, 0.14, fasciaLook) -- mullions
			end
		end
		shopfront(59.2, 69.8, false)
		shopfront(72.2, 86.2, false)
		shopfront(34.4, 44.3, true)
		shopfront(46.7, 55.6, true)
		wedge(
			sh,
			"Awning",
			Vector3.new(10.4, 0.9, 1.8),
			T * CFrame.new(64.5, 6.35, sz0 - 1.2),
			paint
		)
		wedge(
			sh,
			"Awning",
			Vector3.new(9, 0.9, 1.8),
			T * CFrame.new(sx0 - 1.2, 6.35, 39.35) * CFrame.Angles(0, math.pi / 2, 0),
			paintDark
		)
		wedge(
			sh,
			"Awning",
			Vector3.new(8.6, 0.9, 1.8),
			T * CFrame.new(sx0 - 1.2, 6.35, 51.15) * CFrame.Angles(0, math.pi / 2, 0),
			paint
		)
		-- kiosk (spawn screen), v3: stone plinth and corner posts, walls in the side's paint with framed lower panels,
		-- a framed serving hatch (shutter box, mullions, counter on brackets), side windows, a framed back door with a
		-- kick plate, a louvred vent, a stone string course, the render fascia, a canopy with chamfered edges
		local ki = folder(blocks, "Kiosk" .. h.tag)
		col("Kiosk" .. h.tag, 0, 77.5, 20, 6, 10, 0, T, Enum.Material.Wood)
		local stone = L.stone
		box(
			ki,
			"Plinth",
			Vector3.new(-10.25, 0, 74.25),
			Vector3.new(10.25, 0.6, 80.75),
			L.brickBase,
			false,
			T
		)
		box(ki, "Body", Vector3.new(-10, 0.6, 74.5), Vector3.new(10, 7.5, 80.5), paint, false, T)
		for _, cx in { -1, 1 } do
			for _, cz in { -1, 1 } do
				local x0 = if cx > 0 then 9.15 else -10.15
				local z0 = if cz > 0 then 79.65 else 74.35
				box(
					ki,
					"Corner post",
					Vector3.new(x0, 0.6, z0),
					Vector3.new(x0 + 1, 7.5, z0 + 1),
					stone,
					false,
					T
				)
			end
		end
		box(
			ki,
			"String course",
			Vector3.new(-10.2, 7.5, 74.3),
			Vector3.new(10.2, 7.8, 80.7),
			stone,
			false,
			T
		)
		box(
			ki,
			"Upper",
			Vector3.new(-10, 7.8, 74.5),
			Vector3.new(10, 9.4, 80.5),
			L.render,
			false,
			T
		)
		-- front: hatch (dark interior behind a stone frame), shutter box, mullions, counter on three brackets
		box(ki, "Hatch", Vector3.new(-7, 3.6, 74.42), Vector3.new(7, 6.6, 74.5), L.glass, false, T)
		box(
			ki,
			"Hatch jamb",
			Vector3.new(-7.5, 3.3, 74.2),
			Vector3.new(-7, 7.0, 74.5),
			stone,
			false,
			T
		)
		box(
			ki,
			"Hatch jamb",
			Vector3.new(7, 3.3, 74.2),
			Vector3.new(7.5, 7.0, 74.5),
			stone,
			false,
			T
		)
		box(
			ki,
			"Shutter box",
			Vector3.new(-7.6, 6.6, 74.05),
			Vector3.new(7.6, 7.3, 74.5),
			paintDark,
			false,
			T
		)
		for _, mx in { -7 / 3, 7 / 3 } do
			box(
				ki,
				"Mullion",
				Vector3.new(mx - 0.12, 3.6, 74.32),
				Vector3.new(mx + 0.12, 6.6, 74.5),
				paintDark,
				false,
				T
			)
		end
		box(
			ki,
			"Counter",
			Vector3.new(-7.7, 3.25, 73.5),
			Vector3.new(7.7, 3.6, 74.5),
			L.plankDark,
			false,
			T
		)
		for _, bx in { -6, 0, 6 } do
			local p = Vector3.new(bx, 2.65, 74.0)
			part(
				ki,
				"Counter bracket",
				Vector3.new(0.3, 1.2, 1.0),
				T * CFrame.lookAt(p, p + Vector3.new(0, 0, -1)) * CFrame.Angles(0, 0, math.pi),
				paintDark
			)
		end
		for i, px in { { -9, -3.4 }, { -2.6, 2.6 }, { 3.4, 9 } } do
			box(
				ki,
				"Panel",
				Vector3.new(px[1], 1.1, 74.42),
				Vector3.new(px[2], 2.75, 74.5),
				paintDark,
				false,
				T
			)
			local _ = i
		end
		-- side windows (x faces)
		for _, sx in { -1, 1 } do
			-- the frame stands 0.12 proud, the glass 0.2 (in front of it, smaller: the frame shows round it)
			local xa, xb = if sx > 0 then 10 else -10.12, if sx > 0 then 10.12 else -10
			local ga, gb = if sx > 0 then 10 else -10.2, if sx > 0 then 10.06 else -10
			box(
				ki,
				"Window frame",
				Vector3.new(xa, 3.7, 76),
				Vector3.new(xb, 6.8, 79),
				stone,
				false,
				T
			)
			box(
				ki,
				"Window",
				Vector3.new(ga, 4.0, 76.3),
				Vector3.new(gb + (if sx > 0 then 0.14 else 0), 6.5, 78.7), -- +x: 10 .. 10.2
				L.glass,
				false,
				T
			)
		end
		-- back: framed door with a light and a kick plate, louvred vent
		box(
			ki,
			"Door frame",
			Vector3.new(-6.5, 0.6, 80.5),
			Vector3.new(-1.5, 7.2, 80.7),
			stone,
			false,
			T
		)
		box(
			ki,
			"Door",
			Vector3.new(-6, 0.6, 80.55),
			Vector3.new(-2, 6.8, 80.85),
			paintDark,
			false,
			T
		)
		box(
			ki,
			"Door light",
			Vector3.new(-5.2, 4.4, 80.85),
			Vector3.new(-2.8, 6.0, 80.92),
			L.glass,
			false,
			T
		)
		box(
			ki,
			"Kick plate",
			Vector3.new(-5.9, 0.7, 80.85),
			Vector3.new(-2.1, 1.5, 80.9),
			L.steelLight,
			false,
			T
		)
		box(
			ki,
			"Vent frame",
			Vector3.new(2, 4.3, 80.5),
			Vector3.new(7, 6.7, 80.68),
			L.steelLight,
			false,
			T
		)
		for k = 0, 4 do
			local y = 4.6 + k * 0.42
			box(
				ki,
				"Louvre",
				Vector3.new(2.3, y, 80.68),
				Vector3.new(6.7, y + 0.18, 80.8),
				L.steel,
				false,
				T
			)
		end
		box(
			ki,
			"Canopy",
			Vector3.new(-10.5, 9.4, 73.8),
			Vector3.new(10.5, 9.8, 81.2),
			paintDark,
			false,
			T
		)
		-- carved canopy edges (chamfers along the long sides)
		wedge(ki, "Canopy edge", Vector3.new(21, 0.4, 0.6), T * CFrame.new(0, 10, 74.1), paintDark)
		wedge(
			ki,
			"Canopy edge",
			Vector3.new(21, 0.4, 0.6),
			T * CFrame.new(0, 10, 80.9) * CFrame.Angles(0, math.pi, 0),
			paintDark
		)
		-- (no kick strip: the plinth is the foot)
		-- v4 (owner: "parts just placed, they don't fit; structure it like a real map"): every piece has a station job.
		-- Vending is built in (stone cheeks and a canopy; a back wall where it stands free), the gate line is built
		-- off the ticket hall under a portal frame, the old crate towers are a lift tower and an underpass stair
		-- house, the loose crates are seating (a bench island, benches along the back), shop deliveries stay crates.
		local pr = folder(secProps, "Concourse" .. h.tag)
		local function bench(cx: number, cz: number, face: number)
			-- slatted bench on steel end frames; seat toward -Z local (face = 1 turns it to +Z)
			local B = T
				* CFrame.new(cx, 0, cz)
				* CFrame.Angles(0, if face > 0 then math.pi else 0, 0)
			for _, zz in { -1.0, -0.1 } do
				box(
					pr,
					"Seat slat",
					Vector3.new(-4.8, 1.5, zz - 0.4),
					Vector3.new(4.8, 1.8, zz + 0.4),
					L.plank,
					false,
					B
				)
			end
			for _, yy in { 2.2, 2.75 } do
				box(
					pr,
					"Back slat",
					Vector3.new(-4.4, yy - 0.2, 0.55),
					Vector3.new(4.4, yy + 0.2, 0.85),
					L.plank,
					false,
					B
				)
			end
			for _, lx in { -4.4, 4.4 } do
				box(
					pr,
					"End frame",
					Vector3.new(lx - 0.15, 0.4, -1.3),
					Vector3.new(lx + 0.15, 1.5, 0.4),
					L.steel,
					false,
					B
				)
				box(
					pr,
					"End frame",
					Vector3.new(lx - 0.15, 0.4, 0.4),
					Vector3.new(lx + 0.15, 3.1, 0.95),
					L.steel,
					false,
					B
				)
				box(
					pr,
					"Foot",
					Vector3.new(lx - 0.3, 0, -1.4),
					Vector3.new(lx + 0.3, 0.4, 1.05),
					L.steel,
					false,
					B
				)
			end
		end
		local function bin(cx: number, cz: number)
			box(
				pr,
				"Bin",
				Vector3.new(cx - 0.45, 0, cz - 0.45),
				Vector3.new(cx + 0.45, 2.4, cz + 0.45),
				L.steel,
				false,
				T
			)
			box(
				pr,
				"Bin lid",
				Vector3.new(cx - 0.55, 2.4, cz - 0.55),
				Vector3.new(cx + 0.55, 2.7, cz + 0.55),
				L.steelLight,
				false,
				T
			)
		end
		for _, v in { { -15, 30, true }, { 75, 31, false } } do
			col("Vending", v[1], v[2], 6, 3, 9, 0, T, Enum.Material.Metal)
			for i, dx in { -1.5, 1.5 } do
				local m = kit("Props", "Vending", pr, T * CFrame.new(v[1] + dx, 0, v[2]))
				if i == 2 then
					recolor(m, "Paint", h.side.paint)
				end
			end
			local x0, x1, zf, zb = v[1] - 3, v[1] + 3, v[2] - 1.5, v[2] + 1.5
			for _, sx in { -1, 1 } do
				local a = if sx < 0 then x0 - 0.45 else x1 + 0.05
				box(
					pr,
					"Vending cheek",
					Vector3.new(a, 0, zf - 0.3),
					Vector3.new(a + 0.4, 9.6, zb),
					L.stone,
					false,
					T
				)
			end
			box(
				pr,
				"Vending canopy",
				Vector3.new(x0 - 0.65, 9.6, zf - 0.5),
				Vector3.new(x1 + 0.65, 10.1, zb),
				L.steel,
				false,
				T
			)
			if v[3] then
				box(
					pr,
					"Vending back",
					Vector3.new(x0 - 0.45, 0, zb),
					Vector3.new(x1 + 0.45, 10.1, zb + 0.5),
					L.stone,
					false,
					T
				)
			end
		end
		for _, bx in { -45, 45 } do
			col("Bench", bx, 30, 10, 2.5, 3, 0, T, Enum.Material.Wood)
			-- v2: slatted seat and back on two steel end frames (carved: the frames taper to their feet)
			for k, zz in { 29.0, 29.9 } do
				box(
					pr,
					"Seat slat",
					Vector3.new(bx - 4.8, 1.5, zz - 0.4),
					Vector3.new(bx + 4.8, 1.8, zz + 0.4),
					L.plank,
					false,
					T
				)
				local _ = k
			end
			for _, yy in { 2.2, 2.75 } do
				box(
					pr,
					"Back slat",
					Vector3.new(bx - 4.4, yy - 0.2, 30.55),
					Vector3.new(bx + 4.4, yy + 0.2, 30.85),
					L.plank,
					false,
					T
				)
			end
			for _, lx in { bx - 4.4, bx + 4.4 } do
				box(
					pr,
					"End frame",
					Vector3.new(lx - 0.15, 0.4, 28.7),
					Vector3.new(lx + 0.15, 1.5, 30.4),
					L.steel,
					false,
					T
				)
				box(
					pr,
					"End frame",
					Vector3.new(lx - 0.15, 0.4, 30.4),
					Vector3.new(lx + 0.15, 3.1, 30.95),
					L.steel,
					false,
					T
				)
				box(
					pr,
					"Foot",
					Vector3.new(lx - 0.3, 0, 28.6),
					Vector3.new(lx + 0.3, 0.4, 31.05),
					L.steel,
					false,
					T
				)
			end
		end
		-- the gate line runs from the ticket hall's east wall (x -50) to an end post, under a steel portal frame
		col("Ticket gates", -42.5, 45, 15, 3, 3.5, 0, T, Enum.Material.Metal)
		for k = 0, 3 do
			local gx = -48.95 + k * 13 / 3 -- clear of the hall corner quoin
			recolor(
				kit("Metro4", "TicketGate", pr, T * CFrame.new(gx, 0, 45)),
				"Paint",
				h.side.paint
			)
			if k < 3 then
				kit("Metro4", "GatePaddles", pr, T * CFrame.new(gx + 13 / 6, 0, 45))
			end
		end
		box(
			pr,
			"Gate post",
			Vector3.new(-35.3, 0, 44.3),
			Vector3.new(-34.3, 9.4, 45.7),
			L.steel,
			true,
			T
		)
		box(
			pr,
			"Gate post foot",
			Vector3.new(-35.6, 0, 44),
			Vector3.new(-34.0, 0.5, 46),
			L.concreteDark,
			false,
			T
		)
		box(
			pr,
			"Gate lintel",
			Vector3.new(-49.7, 8.6, 44.5),
			Vector3.new(-34.4, 9.3, 45.5),
			L.steel,
			false,
			T
		)
		box(
			pr,
			"Gate light",
			Vector3.new(-49.4, 8.4, 44.7),
			Vector3.new(-35.4, 8.6, 45.3),
			L.render,
			false,
			T
		)
		col("Planter", 30, 75, 10, 10, 3.5, 0, T, Enum.Material.Concrete)
		-- planter (v3, the RIVALS recipe: a Pavement body with a Concrete cap ring, LeafyGrass hedge)
		local pave = { color = hex("A29C91"), mat = Enum.Material.Pavement }
		local capL = { color = hex("C2BCB0"), mat = Enum.Material.Concrete }
		box(pr, "Planter wall", Vector3.new(25, 0, 70), Vector3.new(35, 3.1, 70.8), pave, false, T)
		box(pr, "Planter wall", Vector3.new(25, 0, 79.2), Vector3.new(35, 3.1, 80), pave, false, T)
		box(
			pr,
			"Planter wall",
			Vector3.new(25, 0, 70.8),
			Vector3.new(25.8, 3.1, 79.2),
			pave,
			false,
			T
		)
		box(
			pr,
			"Planter wall",
			Vector3.new(34.2, 0, 70.8),
			Vector3.new(35, 3.1, 79.2),
			pave,
			false,
			T
		)
		box(
			pr,
			"Planter cap",
			Vector3.new(24.85, 3.1, 69.85),
			Vector3.new(35.15, 3.5, 70.95),
			capL,
			false,
			T
		)
		box(
			pr,
			"Planter cap",
			Vector3.new(24.85, 3.1, 79.05),
			Vector3.new(35.15, 3.5, 80.15),
			capL,
			false,
			T
		)
		box(
			pr,
			"Planter cap",
			Vector3.new(24.85, 3.1, 70.95),
			Vector3.new(25.95, 3.5, 79.05),
			capL,
			false,
			T
		)
		box(
			pr,
			"Planter cap",
			Vector3.new(34.05, 3.1, 70.95),
			Vector3.new(35.15, 3.5, 79.05),
			capL,
			false,
			T
		)
		box(pr, "Soil", Vector3.new(25.8, 0, 70.8), Vector3.new(34.2, 2.9, 79.2), L.soil, false, T)
		-- a clipped box hedge (owner 2026-11-20: the faceted low-poly tree and bush "don't look good"): Parts in
		-- LeafyGrass (a real leaf texture), square-cut sides, a slightly narrower top course with chamfered edges
		local leaf = { color = hex("5C7A4A"), mat = Enum.Material.LeafyGrass }
		local leafTop = { color = hex("688A52"), mat = Enum.Material.LeafyGrass }
		box(
			pr,
			"Hedge",
			Vector3.new(25.95, 2.8, 70.95),
			Vector3.new(34.05, 5.3, 79.05),
			leaf,
			false,
			T
		)
		box(
			pr,
			"Hedge top",
			Vector3.new(26.4, 5.3, 71.4),
			Vector3.new(33.6, 5.9, 78.6),
			leafTop,
			false,
			T
		)
		for _, e in
			{
				{ 30, 71.15, 7.2, 0 },
				{ 30, 78.85, 7.2, math.pi },
				{ 26.15, 75, 7.2, math.pi / 2 },
				{ 33.85, 75, 7.2, -math.pi / 2 },
			}
		do
			wedge(
				pr,
				"Hedge edge",
				Vector3.new(e[3], 0.6, 0.5),
				T * CFrame.new(e[1], 5.6, e[2]) * CFrame.Angles(0, e[4], 0),
				leafTop
			)
		end
		-- lift tower (x -27.5..-22.5, z 45..55, 12 tall): steel frame, panelled base, glazed shaft, roof and motor room,
		-- doors and a call panel on its east face. The layout box is the collision.
		col("Lift tower", -25, 50, 5, 10, 12, 0, T, Enum.Material.Metal)
		local lt = folder(pr, "Lift tower")
		box(
			lt,
			"Plinth",
			Vector3.new(-27.7, 0, 44.8),
			Vector3.new(-22.3, 0.6, 55.2),
			L.concreteDark,
			false,
			T
		)
		box(
			lt,
			"Panels",
			Vector3.new(-27.4, 0.6, 45.1),
			Vector3.new(-22.6, 7.6, 54.9),
			L.steelLight,
			false,
			T
		)
		box(
			lt,
			"Shaft glass",
			Vector3.new(-27.3, 7.6, 45.2),
			Vector3.new(-22.7, 11, 54.8),
			L.glass,
			false,
			T
		)
		for _, c in { { -27.5, 45 }, { -22.5, 45 }, { -27.5, 55 }, { -22.5, 55 } } do
			box(
				lt,
				"Frame post",
				Vector3.new(c[1] - 0.3, 0.6, c[2] - 0.3),
				Vector3.new(c[1] + 0.3, 11, c[2] + 0.3),
				L.steel,
				false,
				T
			)
		end
		box(
			lt,
			"Band",
			Vector3.new(-27.55, 7.5, 44.95),
			Vector3.new(-22.45, 7.9, 55.05),
			L.steel,
			false,
			T
		)
		box(
			lt,
			"Roof",
			Vector3.new(-27.9, 11, 44.6),
			Vector3.new(-22.1, 11.5, 55.4),
			L.steel,
			false,
			T
		)
		box(
			lt,
			"Motor room",
			Vector3.new(-26.8, 11.5, 46.5),
			Vector3.new(-23.2, 12, 53.5),
			L.steelLight,
			false,
			T
		)
		box(
			lt,
			"Door frame",
			Vector3.new(-22.4, 0.55, 47.9),
			Vector3.new(-22.2, 7.4, 52.1),
			L.stone,
			false,
			T
		)
		box(
			lt,
			"Doors",
			Vector3.new(-22.3, 0.6, 48.3),
			Vector3.new(-22.1, 7.0, 51.7),
			L.steel,
			false,
			T
		)
		box(
			lt,
			"Door seam",
			Vector3.new(-22.12, 0.7, 49.95),
			Vector3.new(-22.05, 6.9, 50.05),
			L.rubber,
			false,
			T
		)
		box(
			lt,
			"Call panel",
			Vector3.new(-22.6, 3.4, 52.5),
			Vector3.new(-22.35, 4.6, 53.1),
			L.rubber,
			false,
			T
		)

		-- underpass stair house (x 32.5..37.5, z 40..50, 12 tall): brick on a base course, stone quoins and band, a
		-- glazed clerestory, roof with a coping; the stair opening (stone surround, dark stairwell) faces the platform
		col("Stair house", 35, 45, 5, 10, 12, 0, T, Enum.Material.Brick)
		local sh2 = folder(pr, "Stair house")
		box(
			sh2,
			"Base",
			Vector3.new(32.3, 0, 39.8),
			Vector3.new(37.7, 1.0, 50.2),
			L.brickBase,
			false,
			T
		)
		box(sh2, "Walls", Vector3.new(32.5, 1.0, 40), Vector3.new(37.5, 8.6, 50), L.brick, false, T)
		for _, c in { { 32.5, 40 }, { 37.5, 40 }, { 32.5, 50 }, { 37.5, 50 } } do
			local ax = if c[1] < 35 then 32.35 else 36.55
			local az = if c[2] < 45 then 39.85 else 49.05
			box(
				sh2,
				"Quoin",
				Vector3.new(ax, 1.0, az),
				Vector3.new(ax + 1.1, 8.6, az + 1.1),
				L.stone,
				false,
				T
			)
		end
		box(
			sh2,
			"Band",
			Vector3.new(32.3, 8.6, 39.8),
			Vector3.new(37.7, 9.0, 50.2),
			L.stone,
			false,
			T
		)
		box(
			sh2,
			"Clerestory",
			Vector3.new(32.6, 9.0, 40.1),
			Vector3.new(37.4, 11.0, 49.9),
			L.glass,
			false,
			T
		)
		for _, c in { { 32.5, 40 }, { 37.5, 40 }, { 32.5, 50 }, { 37.5, 50 } } do
			box(
				sh2,
				"Mullion",
				Vector3.new(c[1] - 0.25, 9.0, c[2] - 0.25),
				Vector3.new(c[1] + 0.25, 11.0, c[2] + 0.25),
				L.steel,
				false,
				T
			)
		end
		box(
			sh2,
			"Roof",
			Vector3.new(32.1, 11.0, 39.6),
			Vector3.new(37.9, 11.6, 50.4),
			L.steel,
			false,
			T
		)
		box(
			sh2,
			"Coping",
			Vector3.new(32.4, 11.6, 39.9),
			Vector3.new(37.6, 12.0, 50.1),
			L.steelLight,
			false,
			T
		)
		box(
			sh2,
			"Opening surround",
			Vector3.new(33.3, 1.0, 39.75),
			Vector3.new(36.7, 7.6, 40),
			L.stone,
			false,
			T
		)
		box(
			sh2,
			"Stairwell",
			Vector3.new(33.8, 1.0, 39.65),
			Vector3.new(36.2, 7.1, 39.75),
			L.rubber,
			false,
			T
		)
		box(
			sh2,
			"Hand rail",
			Vector3.new(33.9, 3.2, 39.55),
			Vector3.new(36.1, 3.4, 39.65),
			L.steelLight,
			false,
			T
		)

		-- seating: a bench island (back to back round a hedge strip) and a row of benches along the back, with bins
		col("Bench island", 15, 52.5, 10, 5, 3.5, 0, T, Enum.Material.Wood)
		bench(15, 51.05, -1)
		bench(15, 53.95, 1)
		box(
			pr,
			"Island planter",
			Vector3.new(10.4, 0, 52.1),
			Vector3.new(19.6, 1.8, 52.9),
			{ color = hex("A29C91"), mat = Enum.Material.Pavement },
			false,
			T
		)
		box(
			pr,
			"Island hedge",
			Vector3.new(10.6, 1.8, 52.15),
			Vector3.new(19.4, 3.0, 52.85),
			{ color = hex("5C7A4A"), mat = Enum.Material.LeafyGrass },
			false,
			T
		)
		crate(pr, "Shop delivery", 45, 65, 5, 10, 0, 3.5, T)
		for _, bx in { -65, -40 } do
			col("Back benches", bx, 92.5, 10, 5, 3.5, 0, T, Enum.Material.Wood)
			bench(bx, 92.5, -1)
			bin(bx + 6, 92.9)
		end
	end
	task.wait()

	---------------------------------------------------------------------------------------------- world
	local city = folder(secWorld, "City")
	local rnd = Random.new(20261121)
	-- v2 (owner: v1 buildings "dull, not professional"; RIVALS' buildings are layered, muted, trimmed): each near
	-- building is a stone base storey with shop glass, a string course, a framed-window facade (Metro_Facade2,
	-- 8 studs a storey), corner pilasters, a stepped cornice, a parapet with coping and roof plant. Muted colours.
	local facades =
		{ "C9BBA0", "B8826A", "9AA3AD", "D8CFBF", "A26D5A", "A3AE98", "BFB2A4", "C2A88A" }
	local stoneLook = look(hex("8E877C"), "Wharf_Concrete", Enum.Material.Concrete)
	local creamLook = look(hex("D6CCB8"), "Wharf_Concrete", Enum.Material.Concrete)
	local glassLook = look(hex("2E343C"))
	local function building2(
		x: number,
		z: number,
		w: number,
		d: number,
		floors: number,
		full: boolean
	)
		local c = hex(facades[rnd:NextInteger(1, #facades)])
		local hw, hd = w / 2, d / 2
		local H = 8 + 8 * floors
		box(
			city,
			"Base storey",
			Vector3.new(x - hw - 0.3, 0, z - hd - 0.3),
			Vector3.new(x + hw + 0.3, 8, z + hd + 0.3),
			stoneLook
		)
		if full then
			box(
				city,
				"Shop glass",
				Vector3.new(x - hw + 2, 1.2, z - hd - 0.42),
				Vector3.new(x + hw - 2, 6.2, z - hd - 0.3),
				glassLook
			)
			box(
				city,
				"Shop glass",
				Vector3.new(x - hw + 2, 1.2, z + hd + 0.3),
				Vector3.new(x + hw - 2, 6.2, z + hd + 0.42),
				glassLook
			)
			box(
				city,
				"Shop glass",
				Vector3.new(x - hw - 0.42, 1.2, z - hd + 2),
				Vector3.new(x - hw - 0.3, 6.2, z + hd - 2),
				glassLook
			)
			box(
				city,
				"Shop glass",
				Vector3.new(x + hw + 0.3, 1.2, z - hd + 2),
				Vector3.new(x + hw + 0.42, 6.2, z + hd - 2),
				glassLook
			)
		end
		box(
			city,
			"String course",
			Vector3.new(x - hw - 0.5, 8, z - hd - 0.5),
			Vector3.new(x + hw + 0.5, 8.8, z + hd + 0.5),
			creamLook
		)
		local body = box(
			city,
			"Facade",
			Vector3.new(x - hw, 8.8, z - hd),
			Vector3.new(x + hw, H, z + hd),
			look(c, "Metro_Facade2", Enum.Material.Concrete)
		)
		body.CastShadow = H > 40
		local trim =
			look(c:Lerp(Color3.new(0, 0, 0), 0.22), "Wharf_Concrete", Enum.Material.Concrete)
		if full then
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local ax, bx =
						if sx < 0 then x - hw - 0.25 else x + hw - 1.6,
						if sx < 0 then x - hw + 1.6 else x + hw + 0.25
					local az, bz =
						if sz < 0 then z - hd - 0.25 else z + hd - 1.6,
						if sz < 0 then z - hd + 1.6 else z + hd + 0.25
					box(city, "Pilaster", Vector3.new(ax, 8.8, az), Vector3.new(bx, H, bz), trim)
				end
			end
		end
		box(
			city,
			"Cornice",
			Vector3.new(x - hw - 0.6, H, z - hd - 0.6),
			Vector3.new(x + hw + 0.6, H + 0.8, z + hd + 0.6),
			creamLook
		)
		-- the roof: a dark roof slab inside a parapet; the coping is a ring on the parapet only (a full cream cap read
		-- like snow from above)
		box(
			city,
			"Parapet",
			Vector3.new(x - hw, H + 0.8, z - hd),
			Vector3.new(x + hw, H + 2.6, z + hd),
			trim
		)
		box(
			city,
			"Roof",
			Vector3.new(x - hw + 0.8, H + 2.6, z - hd + 0.8),
			Vector3.new(x + hw - 0.8, H + 2.62, z + hd - 0.8),
			look(hex("5F5C57"))
		)
		box(
			city,
			"Coping",
			Vector3.new(x - hw - 0.2, H + 2.6, z - hd - 0.2),
			Vector3.new(x + hw + 0.2, H + 2.9, z - hd + 0.8),
			creamLook
		)
		box(
			city,
			"Coping",
			Vector3.new(x - hw - 0.2, H + 2.6, z + hd - 0.8),
			Vector3.new(x + hw + 0.2, H + 2.9, z + hd + 0.2),
			creamLook
		)
		box(
			city,
			"Coping",
			Vector3.new(x - hw - 0.2, H + 2.6, z - hd + 0.8),
			Vector3.new(x - hw + 0.8, H + 2.9, z + hd - 0.8),
			creamLook
		)
		box(
			city,
			"Coping",
			Vector3.new(x + hw - 0.8, H + 2.6, z - hd + 0.8),
			Vector3.new(x + hw + 0.2, H + 2.9, z + hd - 0.8),
			creamLook
		)
		if full then
			local px, pz = x + rnd:NextNumber(-hw / 3, hw / 3), z + rnd:NextNumber(-hd / 3, hd / 3)
			box(
				city,
				"Roof plant",
				Vector3.new(px - 4, H + 2.62, pz - 3),
				Vector3.new(px + 4, H + 6.4, pz + 3),
				L.concreteDark
			)
			box(
				city,
				"Plant cap",
				Vector3.new(px - 4.3, H + 6.4, pz - 3.3),
				Vector3.new(px + 4.3, H + 6.8, pz + 3.3),
				L.steelLight
			)
		end
	end
	for _, s in { -1, 1 } do
		-- the row across the street from the hall (full detail), and a taller row behind it (simpler)
		for x = -320, 320, 58 do
			building2(
				x + rnd:NextNumber(-3, 3),
				s * 205,
				rnd:NextInteger(9, 10) * 5,
				40,
				rnd:NextInteger(3, 6),
				true
			)
			building2(
				x + 29 + rnd:NextNumber(-3, 3),
				s * 272,
				rnd:NextInteger(8, 10) * 5,
				50,
				rnd:NextInteger(7, 12),
				false
			)
		end
		-- along the cutting beyond the hall ends (kept clear of the tracks)
		for x = 150, 390, 60 do
			for _, zz in { 72, -72 } do
				building2(
					s * (x + rnd:NextNumber(-3, 3)),
					zz,
					rnd:NextInteger(7, 9) * 5,
					34,
					rnd:NextInteger(2, 5),
					true
				)
			end
		end
	end
	-- far towers in the haze (silhouettes)
	for _, s in { -1, 1 } do
		for x = -420, 420, 84 do
			building2(
				x + rnd:NextNumber(-10, 10),
				s * rnd:NextNumber(380, 430),
				rnd:NextInteger(8, 11) * 5,
				45,
				rnd:NextInteger(10, 16),
				false
			)
		end
	end
	task.wait()
	-- tunnel portals where the tracks leave (a faceted concrete portal with a dark mouth)
	for _, s in { -1, 1 } do
		local x = s * 420
		box(
			city,
			"Portal wall",
			Vector3.new(x - 4, -4.8, -45),
			Vector3.new(x + 4, 34, -14),
			L.concrete
		)
		box(
			city,
			"Portal wall",
			Vector3.new(x - 4, -4.8, 14),
			Vector3.new(x + 4, 34, 45),
			L.concrete
		)
		box(
			city,
			"Portal lintel",
			Vector3.new(x - 4, 14, -14),
			Vector3.new(x + 4, 34, 14),
			L.concrete
		)
		box(
			city,
			"Portal mouth",
			Vector3.new(x + s * 4, -5, -14),
			Vector3.new(x + s * 4.2, 14, 14),
			look(hex("1C1F24"))
		)
		box(
			city,
			"Portal coping",
			Vector3.new(x - 5, 34, -46),
			Vector3.new(x + 5, 36, 46),
			L.concreteDark
		)
		for _, zz in { -13, 13 } do
			box(
				city,
				"Mouth chamfer",
				Vector3.new(x - 3.9, 12.5, zz - 1),
				Vector3.new(x + 3.9, 13.9, zz + 1),
				L.concreteDark
			)
		end
		box(
			city,
			"Hill over portal",
			Vector3.new(x + s * 4.2, -5, -260),
			Vector3.new(x + s * 260, 40, 260),
			look(C.land)
		)
	end
	-- mountains (two depth layers)
	local hills = folder(secWorld, "Mountains")
	kit(
		"Wharf",
		"MountainA",
		hills,
		CFrame.new(-500, -10, -1500) * CFrame.Angles(0, 0.5, 0),
		"MountainA"
	)
	kit(
		"Wharf",
		"MountainB",
		hills,
		CFrame.new(600, -10, -1300) * CFrame.Angles(0, -0.4, 0),
		"MountainB"
	)
	kit(
		"Wharf",
		"MountainA",
		hills,
		CFrame.new(400, -10, 1600) * CFrame.Angles(0, 2.1, 0),
		"MountainA north"
	)
	kit(
		"Wharf",
		"MountainB",
		hills,
		CFrame.new(-700, -10, 1350) * CFrame.Angles(0, 2.9, 0),
		"MountainB north"
	)
	kit(
		"Wharf",
		"MountainC",
		hills,
		CFrame.new(1500, -10, 200) * CFrame.Angles(0, 1.2, 0),
		"MountainC east"
	)
	kit(
		"Wharf",
		"MountainC",
		hills,
		CFrame.new(-1500, -10, -150) * CFrame.Angles(0, -1.2, 0),
		"MountainC west"
	)
	for _, d in hills:GetDescendants() do
		if d:IsA("BasePart") then
			d.CastShadow = false
			if d.Name:match("_R_Grass$") then
				d.Color = hex("6E8A58")
			elseif d.Name:match("_R_RockDark$") then
				d.Color = hex("6C706B")
			elseif d.Name:match("_R_Rock$") then
				d.Color = hex("858880")
			end
		end
	end
	-- the land under the far world (so nothing floats): one wide green plain round the city
	for i = -1, 1 do
		for j = -1, 1 do
			local p = part(
				secWorld,
				"Land",
				Vector3.new(2048, 1, 2048),
				CFrame.new(i * 2048, -10.5, j * 2048),
				look(C.land)
			)
			p.CastShadow = false
		end
	end
	task.wait()

	--------------------------------------------------------------------------------- spawns, bounds, stage
	local SPAWNS = { { -12, 98 }, { 0, 100 }, { 12, 98 }, { -6, 93 }, { 6, 93 } }
	for team, h in halves do
		local letter = if team == 1 then "A" else "B"
		for i, s in SPAWNS do
			local sp = Instance.new("SpawnLocation")
			sp.Name = "Spawn_" .. letter .. i
			sp.Size = Vector3.new(4, 0.2, 4)
			sp.CFrame = ORIGIN * h.T * CFrame.new(s[1], 0.1, s[2])
			sp.Anchored = true
			sp.Transparency = 1
			sp.CanCollide = false
			sp.CanQuery = false
			sp.CanTouch = false
			sp.Neutral = true
			sp.Enabled = false
			sp.Duration = 0
			sp:ClearAllChildren()
			CollectionService:AddTag(sp, "ArenaSpawn_" .. letter)
			sp.Parent = secSpawns
		end
	end
	local function bound(a: Vector3, b: Vector3)
		local p = box(secBounds, "Bound", a, b, { color = C.concrete }, true)
		p.Transparency = 1
		p.CanQuery = false
		p.CastShadow = false
	end
	bound(Vector3.new(115, -6, -105), Vector3.new(117, 25, 105)) -- east end (open)
	bound(Vector3.new(-117, -6, -105), Vector3.new(-115, 25, 105)) -- west end (open)
	bound(Vector3.new(-117, -6, 104.4), Vector3.new(117, 25, 106.4)) -- north wall line
	bound(Vector3.new(-117, -6, -106.4), Vector3.new(117, 25, -104.4)) -- south wall line
	bound(Vector3.new(-117, 25, -106.4), Vector3.new(117, 27, 106.4)) -- ceiling under the roof
	-- winners' stage: on A's platform between two columns, the blue train behind them
	local stage = part(
		map,
		"WinnerStage",
		Vector3.new(4, 0.2, 4),
		CFrame.new(-75, 0.1, 22) * CFrame.Angles(0, math.pi, 0),
		{ color = C.tile }
	)
	stage.Transparency = 1
	stage.CastShadow = false
	CollectionService:AddTag(stage, "WinnerStage")

	------------------------------------------------------------------------------------------- lighting
	local light = Instance.new("Configuration")
	light.Name = "Lighting"
	CollectionService:AddTag(light, "GGAsset_MatchMaps_414")
	CollectionService:AddTag(light, "GauntletAuthoredData")
	light.Parent = map
	local fx = folder(map, "LightingFx")
	local atm = Instance.new("Atmosphere")
	atm.Density = 0.3
	atm.Offset = 0.1
	atm.Haze = 1.4
	atm.Glare = 0.1
	atm.Color = Color3.fromRGB(212, 220, 230)
	atm.Decay = Color3.fromRGB(160, 170, 192)
	atm.Parent = fx
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "Grade"
	cc.Contrast = 0.05
	cc.Saturation = -0.05
	cc.TintColor = Color3.fromRGB(255, 251, 244)
	cc.Parent = fx

	map.Parent = workspace
	return string.format("Metro4 built: %d parts", count)
end
