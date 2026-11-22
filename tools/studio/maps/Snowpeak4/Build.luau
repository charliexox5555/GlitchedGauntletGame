--!strict
-- Snowpeak4 (regular map, 1v1-2v2), the whole build (2026-11-20). Plan, RIVALS Village study, layout and build log:
-- vault/01 Design/Maps/Snowpeak4.md. Layout rows mirror tools/maps/snowpeak4_layout.py (the A half is turned 180
-- degrees for team B). Match place only, edit mode. Returns a function; run it with require(<a clone>)().
--
-- Snowpeak2's whole vibe (a timber ski lodge, the gondola station with red cabins, a frozen pond, the snowcat, pines,
-- big mountains) with an open middle (owner 2026-11-20: Snowpeak's middle was "too congested"), a modelled snowcat
-- (MapKit.Snowpeak4), pines the RIVALS way (LeafyGrass foliage + a Snow cap), no spawn nooks (the ghost hold keeps
-- players at the spawn), clean mountains. Buildings are Parts on the 5-stud module with Snowpeak2's own textures
-- (Snow2_*), carved ends and snow on every roof. No text signs (icons only).
-- Collision: layout boxes (invisible) for buildings, rocks, the snowcat, pine clumps and low cover; floors, decks,
-- stairs, railings are their own collision. Contract: Spawns (ArenaSpawn_A/B), Barriers (empty), Bounds,
-- KillDepth + Lighting (authored data 415 / 416), LightingFx, WinnerStage.

local CollectionService = game:GetService("CollectionService")
local MaterialService = game:GetService("MaterialService")
local ServerStorage = game:GetService("ServerStorage")

local ORIGIN = CFrame.new(6000, 200, 19000) -- the snow floor at the pond centre
local ROT = CFrame.Angles(0, math.pi, 0)

local function hex(h: string): Color3
	return Color3.fromHex(h)
end
local C = {
	snow = hex("E9EEF5"),
	snowShade = hex("DCE4EE"),
	ice = hex("B9D6E6"),
	timber = hex("8A5E3C"),
	timberDark = hex("5A3C28"),
	timberLight = hex("A8805A"),
	plank = hex("9A7450"),
	stone = hex("9A9388"),
	stoneDark = hex("6E6962"),
	roof = hex("4A535E"),
	steel = hex("5E656D"),
	steelDark = hex("3E444B"),
	concrete = hex("A7A39B"),
	concreteDark = hex("7F7B74"),
	red = hex("A8262E"),
	glow = hex("B07A48"),
	glass = hex("2B323C"),
	cable = hex("2F3338"),
	shutter = hex("4A6650"),
	landFar = hex("DCE3EC"),
}
local SIDE = {
	A = { paint = hex("C9962E") }, -- Snowpeak2's end paint: A gold
	B = { paint = hex("3D63A8") }, -- B blue
}
-- Snowpeak2's own textures (tools/textures/make_snowpeak2_textures.py), re-created here if missing
local VARIANTS = {
	Snow2_Plank = { "WoodPlanks", 8, "72356380118675", "113823686655015" },
	Snow2_Rock = { "Rock", 28, "72465231073227", "133592237709177" },
	Snow2_Roof = { "Plastic", 8, "80711795927408", "74968368388868" },
	Snow2_Snow = { "Snow", 16, "114271398131937", "111098192335248" },
	Snow2_Stone = { "Cobblestone", 8, "117006718223711", "123215852189966" },
	Snow2_Timber = { "WoodPlanks", 8, "132419806158171", "127590838417035" },
	Wharf_Concrete = { "Concrete", 10, "98131730598502", "101527228918911" },
	Wharf_Plate = { "DiamondPlate", 5, "116955307704363", "89970433895475" },
}

type Look = { color: Color3, mat: Enum.Material?, variant: string? }
local function look(color: Color3, variant: string?, mat: Enum.Material?): Look
	return { color = color, variant = variant, mat = mat }
end
local L = {
	snow = look(C.snow, "Snow2_Snow", Enum.Material.Snow),
	snowShade = look(C.snowShade, "Snow2_Snow", Enum.Material.Snow),
	ice = look(C.ice, nil, Enum.Material.Ice),
	timber = look(C.timber, "Snow2_Timber", Enum.Material.WoodPlanks),
	timberDark = look(C.timberDark, "Snow2_Timber", Enum.Material.WoodPlanks),
	timberLight = look(C.timberLight, "Snow2_Timber", Enum.Material.WoodPlanks),
	trim = look(C.timberDark),
	plank = look(C.plank, "Snow2_Plank", Enum.Material.WoodPlanks),
	stone = look(C.stone, "Snow2_Stone", Enum.Material.Cobblestone),
	stoneDark = look(C.stoneDark, "Snow2_Stone", Enum.Material.Cobblestone),
	roof = look(C.roof, "Snow2_Roof", Enum.Material.Plastic),
	steel = look(C.steel),
	steelDark = look(C.steelDark),
	concrete = look(C.concrete, "Wharf_Concrete", Enum.Material.Concrete),
	concreteDark = look(C.concreteDark, "Wharf_Concrete", Enum.Material.Concrete),
	plate = look(C.steel, "Wharf_Plate", Enum.Material.DiamondPlate),
	red = look(C.red),
	glow = look(C.glow, nil, Enum.Material.Neon),
	glass = look(C.glass),
	cable = look(C.cable),
	shutter = look(C.shutter),
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
			mv.BaseMaterial = (Enum.Material :: any)[v[1]]
			mv.StudsPerTile = v[2]
			mv.ColorMap = "rbxassetid://" .. v[3]
			mv.NormalMap = "rbxassetid://" .. v[4]
			mv.MaterialPattern = Enum.MaterialPattern.Regular
		end
	end
end

-- RIVALS texture pass (2026-11-21, see the map note): every surface look onto RIVALS' map MaterialVariants
-- (MaterialService.ExtraTextures, found by name), keyed by "Material|Variant" as built. Applied once the map is built.
local RIVALS_REMAP: { [string]: { any } } = {
	["Snow|Snow2_Snow"] = { Enum.Material.Snow, "Snow_01a" },
	["Snow|"] = { Enum.Material.Snow, "Snow_01a" },
	["Ice|"] = { Enum.Material.Ice, "Ice_01b" },
	["WoodPlanks|Snow2_Timber"] = { Enum.Material.WoodPlanks, "WoodPlank01a_Big" },
	["WoodPlanks|Snow2_Plank"] = { Enum.Material.WoodPlanks, "WoodPlank01a" },
	["Wood|"] = { Enum.Material.Wood, "Wood01a" },
	["Concrete|Wharf_Concrete"] = { Enum.Material.Concrete, "Concrete-01a" },
	["DiamondPlate|Wharf_Plate"] = { Enum.Material.DiamondPlate, "Diamond Plate 2022" },
}

return function(): string
	assert(game.PlaceId == 133387545285290, "Snowpeak4: not the match place")
	ensureVariants()
	local old = workspace:FindFirstChild("Snowpeak4")
	if old then
		old:Destroy()
	end
	local map = Instance.new("Model")
	map.Name = "Snowpeak4"
	map.WorldPivot = ORIGIN
	CollectionService:AddTag(map, "GGAsset_MatchMaps_415")
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
	local function beam(
		parent: Instance,
		name: string,
		a: Vector3,
		b: Vector3,
		w: number,
		h: number,
		lk: Look,
		T: CFrame?
	)
		local mid = (a + b) / 2
		return part(
			parent,
			name,
			Vector3.new(w, h, (b - a).Magnitude),
			(T or CFrame.identity) * CFrame.lookAt(mid, b),
			lk
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
			{ color = C.stone, mat = mat },
			true
		)
		p.Transparency = 1
		p.CastShadow = false
		return p
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
	-- a gable roof on a rectangle (ridge along X): planes on the true slope from the eave line, a ridge cap, snow on
	-- each plane, gable triangles (two wedges per end) in `gableLk`, fascia boards along the eaves
	local function gableRoof(
		parent: Instance,
		x0: number,
		x1: number,
		z0: number,
		z1: number,
		eave: number,
		ridge: number,
		over: number,
		T: CFrame,
		gableLk: Look
	)
		local half = (z1 - z0) / 2
		local zc = (z0 + z1) / 2
		local rise = ridge - eave
		local th = math.atan2(rise, half)
		local t = 0.6
		local run = half + over
		local len = run / math.cos(th)
		local xl = x1 - x0 + 2 * over
		for _, s in { -1, 1 } do
			local d = run / 2
			local top = ridge - (d - 0.0) * math.tan(th)
			local cf = T * CFrame.new((x0 + x1) / 2, top, zc + s * d) * CFrame.Angles(s * th, 0, 0)
			part(
				parent,
				"Roof",
				Vector3.new(xl - (if s > 0 then 0.1 else 0), t, len),
				cf * CFrame.new(0, -t / 2, 0),
				L.roof
			)
			part(
				parent,
				"Roof snow",
				Vector3.new(xl - 0.4, 0.35, len - 0.5),
				cf * CFrame.new(0, 0.17, -0.0),
				L.snow
			)
			box(
				parent,
				"Fascia",
				Vector3.new(
					x0 - over - 0.05,
					eave - over * math.tan(th) - 0.75,
					zc + s * (run + 0.0) - 0.15
				),
				Vector3.new(
					x1 + over + 0.05,
					eave - over * math.tan(th) - 0.05,
					zc + s * (run + 0.0) + 0.15
				),
				L.trim,
				false,
				T
			)
		end
		box(
			parent,
			"Ridge cap",
			Vector3.new(x0 - over, ridge - 0.1, zc - 0.7),
			Vector3.new(x1 + over, ridge + 0.55, zc + 0.7),
			L.snow,
			false,
			T
		)
		for _, gx in { x0 + 0.25, x1 - 0.25 } do
			for _, s in { -1, 1 } do
				local c = Vector3.new(gx, eave + rise / 2, zc + s * half / 2)
				wedge(
					parent,
					"Gable",
					Vector3.new(0.5, rise, half),
					T * CFrame.lookAt(c, c + Vector3.new(0, 0, s)),
					gableLk
				)
			end
		end
	end
	-- a framed, lit window on a wall face: face "N" (+Z), "S" (-Z), "E" (+X), "W" (-X) at coordinate `w`
	local function window(
		parent: Instance,
		face: string,
		w: number,
		u: number,
		y0: number,
		ww: number,
		wh: number,
		T: CFrame
	)
		local out = if face == "N" or face == "E" then 1 else -1
		local function r(
			a0: number,
			a1: number,
			b0: number,
			b1: number,
			d0: number,
			d1: number,
			lk: Look
		)
			if face == "N" or face == "S" then
				box(
					parent,
					"Window",
					Vector3.new(a0, b0, w + out * d0),
					Vector3.new(a1, b1, w + out * d1),
					lk,
					false,
					T
				)
			else
				box(
					parent,
					"Window",
					Vector3.new(w + out * d0, b0, a0),
					Vector3.new(w + out * d1, b1, a1),
					lk,
					false,
					T
				)
			end
		end
		r(u - ww / 2 - 0.3, u + ww / 2 + 0.3, y0 - 0.3, y0 + wh + 0.3, -0.02, 0.18, L.trim) -- frame
		r(u - ww / 2, u + ww / 2, y0, y0 + wh, -0.04, 0.24, L.glow) -- lit pane, in front of the frame
		r(u - 0.08, u + 0.08, y0 - 0.01, y0 + wh + 0.01, -0.06, 0.3, L.trim) -- mullion
		r(
			u - ww / 2 + 0.01,
			u + ww / 2 - 0.01,
			y0 + wh / 2 - 0.08,
			y0 + wh / 2 + 0.08,
			-0.08,
			0.28,
			L.trim
		) -- transom
		r(u - ww / 2 - 0.45, u + ww / 2 + 0.45, y0 - 0.55, y0 - 0.32, -0.03, 0.42, L.timberLight) -- sill
		r(u - ww / 2 - 0.7, u - ww / 2 - 0.35, y0 - 0.2, y0 + wh + 0.2, -0.05, 0.22, L.shutter) -- shutters
		r(u + ww / 2 + 0.35, u + ww / 2 + 0.7, y0 - 0.2, y0 + wh + 0.2, -0.05, 0.22, L.shutter)
	end
	local function drift(
		parent: Instance,
		x0: number,
		x1: number,
		z: number,
		out: number,
		T: CFrame
	)
		-- a snow drift against a wall running along X (out = +1 drifts toward +Z)
		local c = Vector3.new((x0 + x1) / 2, 0.6, z + out * 0.9)
		wedge(
			parent,
			"Drift",
			Vector3.new(x1 - x0, 1.2, 1.8),
			T * CFrame.lookAt(c, c + Vector3.new(0, 0, out)),
			L.snowShade
		)
	end
	local function crate(
		parent: Instance,
		name: string,
		cx: number,
		cz: number,
		sx: number,
		sz: number,
		y0: number,
		hh: number,
		T: CFrame
	)
		local body = part(
			parent,
			name,
			Vector3.new(sx, hh, sz),
			T * CFrame.new(cx, y0 + hh / 2, cz),
			L.plank,
			true
		)
		body.Transparency = 1
		body.CastShadow = false
		local key = ({ [3.5] = "35", [4.25] = "425", [5] = "5", [6] = "6" })[hh]
		assert(key, "no crate height " .. hh)
		local nx, nz = math.max(1, math.round(sx / 5)), math.max(1, math.round(sz / 5))
		for i = 1, nx do
			for j = 1, nz do
				kit(
					"Props",
					"CrateA_" .. key,
					parent,
					T
						* CFrame.new(
							cx - sx / 2 + (i - 0.5) * sx / nx + (i - (nx + 1) / 2) * 0.06,
							y0,
							cz - sz / 2 + (j - 0.5) * sz / nz + (j - (nz + 1) / 2) * 0.06
						),
					"Crate"
				)
			end
		end
	end

	local halves =
		{ { T = CFrame.identity, tag = "", side = SIDE.A }, { T = ROT, tag = "'", side = SIDE.B } }

	------------------------------------------------------------------------------------------------ ground
	local ground = folder(secStructure, "Ground")
	box(ground, "Snow", Vector3.new(-75, -4, -95), Vector3.new(75, 0, 95), L.snow, true)
	for _, h in halves do
		-- the long sides fall away to the valley (fence on the edge); the ends rise into the ridge behind the spawns
		local c = Vector3.new(105, -20, 0) -- 75 .. 135: meets the floor slab
		wedge(
			ground,
			"Drop",
			Vector3.new(190, 40, 60),
			h.T * CFrame.lookAt(c, c + Vector3.new(1, 0, 0)),
			L.snow,
			true
		)
		local e = Vector3.new(0, 22.5, 137.5)
		wedge(
			ground,
			"Ridge slope",
			Vector3.new(420, 45, 85),
			h.T * CFrame.lookAt(e, e + Vector3.new(0, 0, -1)),
			L.snow,
			true
		)
		box(
			ground,
			"Ridge",
			Vector3.new(-210, -4, 180),
			Vector3.new(210, 45, 260),
			L.snow,
			false,
			h.T
		)
		-- the snow berm along the spawn end (inside the bound line: a low lip, not a nook)
		local b = Vector3.new(0, 1.0, 93.5)
		wedge(
			ground,
			"Berm",
			Vector3.new(150, 2, 3),
			h.T * CFrame.lookAt(b, b + Vector3.new(0, 0, -1)),
			L.snowShade
		)
		-- timber fence on the drop-off edge: posts every 5 with a snow cap, two rails
		local fence = folder(ground, "Fence" .. h.tag)
		for z = -90, 90, 5 do
			box(
				fence,
				"Post",
				Vector3.new(75.4, -0.6, z - 0.3),
				Vector3.new(76, 4.2, z + 0.3),
				L.timberDark,
				false,
				h.T
			)
			box(
				fence,
				"Post cap",
				Vector3.new(75.3, 4.2, z - 0.4),
				Vector3.new(76.1, 4.5, z + 0.4),
				L.snow,
				false,
				h.T
			)
		end
		for _, y in { 1.6, 3.2 } do
			box(
				fence,
				"Rail",
				Vector3.new(76, y - 0.25, -90.3),
				Vector3.new(76.25, y + 0.25, 90.3),
				L.timber,
				false,
				h.T
			)
		end
	end
	-- the valley far below the saddle
	for i = -1, 1 do
		for j = -1, 1 do
			local p = part(
				secWorld,
				"Valley",
				Vector3.new(2048, 1, 2048),
				CFrame.new(i * 2048, -40.5, j * 2048),
				L.snow
			)
			p.CastShadow = false
		end
	end
	task.wait()

	------------------------------------------------------------------------------------------------ pond
	local pond = folder(secStructure, "Pond")
	box(pond, "Ice", Vector3.new(-18, -0.6, -13), Vector3.new(18, 0.04, 13), L.ice, true)
	for _, s in { -1, 1 } do
		box(
			pond,
			"Lip",
			Vector3.new(-18.6, 0, s * 13),
			Vector3.new(18.6, 0.35, s * 13 + s * 0.6),
			L.snowShade,
			false
		)
		box(
			pond,
			"Lip",
			Vector3.new(s * 18, 0, -13),
			Vector3.new(s * 18 + s * 0.6, 0.35, 13),
			L.snowShade,
			false
		)
	end
	col("Pond rock", 0, 0, 12, 9, 12, 0, CFrame.identity, Enum.Material.Slate)
	kit("Snowpeak4", "Outcrop", pond, CFrame.new(0, 0, 0))
	kit("Snowpeak4", "BoulderA", pond, CFrame.new(-4.6, 0, 2.6) * CFrame.Angles(0, 0.7, 0))
	kit("Snowpeak4", "BoulderA", pond, CFrame.new(4.2, 0, -2.8) * CFrame.Angles(0, 2.4, 0))
	task.wait()

	------------------------------------------------------------------------------------------------ the two halves
	for _, h in halves do
		local T = h.T
		local paint = look(h.side.paint)
		local f = folder(secStructure, "Half" .. h.tag)

		-- LODGE (x -65..-39, z 38..62): stone base course, timber walls with log corner posts, lit windows with
		-- shutters, a door to the spawn side, a gable roof (eave 10, ridge 20) with snow, a stone chimney
		local lo = folder(f, "Lodge")
		-- collision: walls to the eave, the roof's true gable (two solid wedges, bullets hit the roof you see) and a
		-- player-only blocker over the roof to the ceiling (owner rule: no unplanned perches; the deck railing is 13.2)
		col("Lodge", -52, 50, 26, 24, 10, 0, T, Enum.Material.Wood)
		for _, s2 in { -1, 1 } do
			local gc = Vector3.new(-52, 15, 50 + s2 * 6.8)
			local gw = part(
				secCollision,
				"Lodge roof" .. h.tag,
				Vector3.new(29.2, 10, 13.6),
				T * CFrame.lookAt(gc, gc + Vector3.new(0, 0, s2)),
				{ color = C.roof, mat = Enum.Material.Plastic },
				true,
				"WedgePart"
			)
			gw.Transparency = 1
			gw.CastShadow = false
		end
		local nb = box(
			secCollision,
			"Lodge roof blocker" .. h.tag,
			Vector3.new(-66.7, 10, 36.3),
			Vector3.new(-37.3, 45, 63.7),
			{ color = C.roof },
			true,
			T
		)
		nb.Transparency = 1
		nb.CanQuery = false
		nb.CastShadow = false
		box(
			lo,
			"Base",
			Vector3.new(-65.3, 0, 37.7),
			Vector3.new(-38.7, 1.6, 62.3),
			L.stone,
			false,
			T
		)
		box(lo, "Walls", Vector3.new(-65, 1.6, 38), Vector3.new(-39, 9.5, 62), L.timber, false, T)
		for _, cx in { -65, -39 } do
			for _, cz in { 38, 62 } do
				box(
					lo,
					"Corner post",
					Vector3.new(cx - 0.5, 1.6, cz - 0.5),
					Vector3.new(cx + 0.5, 10, cz + 0.5),
					L.timberDark,
					false,
					T
				)
			end
		end
		box(
			lo,
			"Sill beam",
			Vector3.new(-65.2, 1.6, 37.8),
			Vector3.new(-38.8, 2.1, 62.2),
			L.timberDark,
			false,
			T
		)
		box(
			lo,
			"Wall plate",
			Vector3.new(-65.2, 9.5, 37.8),
			Vector3.new(-38.8, 10, 62.2),
			L.timberDark,
			false,
			T
		)
		for _, u in { -59, -52, -45 } do
			window(lo, "S", 38, u, 4, 3, 3.5, T)
		end
		for _, u in { -60.5, -44 } do -- the door takes the middle of the north face
			window(lo, "N", 62, u, 4, 3, 3.5, T)
		end
		for _, u in { 44, 56 } do
			window(lo, "W", -65, u, 4, 3, 3.5, T)
		end
		window(lo, "E", -39, 56, 4, 3, 3.5, T) -- the deck side (a door further along)
		gableRoof(lo, -65, -39, 38, 62, 10, 20, 1.6, T, L.timber)
		box(lo, "Chimney", Vector3.new(-60, 10, 43), Vector3.new(-57, 23, 46), L.stone, false, T)
		box(
			lo,
			"Chimney cap",
			Vector3.new(-60.4, 23, 42.6),
			Vector3.new(-56.6, 23.6, 46.4),
			L.stoneDark,
			false,
			T
		)
		-- front door (to the spawn side) under a small porch roof, and the deck door
		box(
			lo,
			"Door frame",
			Vector3.new(-54.2, 1.6, 62),
			Vector3.new(-49.8, 8.2, 62.25),
			L.timberDark,
			false,
			T
		)
		box(
			lo,
			"Door",
			Vector3.new(-53.7, 1.6, 62.1),
			Vector3.new(-50.3, 7.7, 62.35),
			L.red,
			false,
			T
		)
		box(
			lo,
			"Porch roof",
			Vector3.new(-55.5, 8.6, 62),
			Vector3.new(-48.5, 9.0, 65),
			L.roof,
			false,
			T
		)
		box(
			lo,
			"Porch snow",
			Vector3.new(-55.3, 9.0, 62.1),
			Vector3.new(-48.7, 9.3, 64.8),
			L.snow,
			false,
			T
		)
		for _, x in { -55.2, -48.8 } do
			box(
				lo,
				"Porch post",
				Vector3.new(x - 0.25, 0, 64.5),
				Vector3.new(x + 0.25, 8.6, 65),
				L.timberDark,
				true,
				T
			)
		end
		drift(lo, -65, -39, 37.7, -1, T)
		drift(lo, -65, -55.5, 62.3, 1, T)

		-- DECK (+10, x -39..-29, z 38..62) on posts and joists, plank floor, railing with an opening at the stair
		local dk = folder(f, "Lodge deck")
		box(dk, "Deck", Vector3.new(-38.8, 9.4, 38), Vector3.new(-29, 10, 62), L.plank, true, T)
		box(
			dk,
			"Deck snow",
			Vector3.new(-38.8, 10, 38.4),
			Vector3.new(-35.5, 10.15, 61.6),
			L.snowShade,
			false,
			T
		)
		box(
			dk,
			"Edge beam",
			Vector3.new(-29.4, 8.8, 38),
			Vector3.new(-29, 9.4, 62),
			L.timberDark,
			false,
			T
		)
		for z = 38.4, 61.6, 5.8 do
			box(
				dk,
				"Post",
				Vector3.new(-29.8, 0, z - 0.4),
				Vector3.new(-29.0, 8.8, z + 0.4),
				L.timberDark,
				true,
				T
			)
			box(
				dk,
				"Post foot",
				Vector3.new(-30.1, 0, z - 0.7),
				Vector3.new(-28.7, 0.5, z + 0.7),
				L.stone,
				false,
				T
			)
			box(
				dk,
				"Joist",
				Vector3.new(-38.9, 8.8, z - 0.25),
				Vector3.new(-29.4, 9.4, z + 0.25),
				L.timberDark,
				false,
				T
			)
		end
		-- railing: the outer side (x -29) and the south end; the north end is open to the stair
		box(
			dk,
			"Rail",
			Vector3.new(-29.3, 12.8, 38),
			Vector3.new(-28.9, 13.2, 62),
			L.timber,
			true,
			T
		)
		box(
			dk,
			"Rail",
			Vector3.new(-38.8, 12.82, 37.9),
			Vector3.new(-29.3, 13.18, 38.3),
			L.timber,
			true,
			T
		)
		for z = 38.6, 61.4, 1.6 do
			box(
				dk,
				"Baluster",
				Vector3.new(-29.25, 10, z - 0.12),
				Vector3.new(-28.95, 12.8, z + 0.12),
				L.timberDark,
				false,
				T
			)
		end
		for x = -38.4, -29.6, 1.6 do
			box(
				dk,
				"Baluster",
				Vector3.new(x - 0.12, 10, 37.95),
				Vector3.new(x + 0.12, 12.8, 38.25),
				L.timberDark,
				false,
				T
			)
		end
		-- the stair (x -36.5..-31.5, z 62..78, 10 down to 0, 32 degrees): a wedge for the walk, treads, stringers, rails
		local ramp = wedge(
			secCollision,
			"Lodge stair" .. h.tag,
			Vector3.new(5, 10, 16),
			T * CFrame.new(-34, 5, 70) * CFrame.Angles(0, math.pi, 0),
			{ color = C.plank },
			true
		)
		ramp.Transparency = 1
		ramp.CastShadow = false
		for k = 1, 16 do
			local z1 = 78 - (k - 1)
			box(
				dk,
				"Tread",
				Vector3.new(-36.3, k * 10 / 16 - 0.35, z1 - 0.97),
				Vector3.new(-31.7, k * 10 / 16 - 0.02, z1),
				L.plank,
				false,
				T
			)
		end
		local ang = math.atan2(10, 16)
		local slen = math.sqrt(10 * 10 + 16 * 16)
		for _, x in { -36.5, -31.5 } do
			part(
				dk,
				"Stringer",
				Vector3.new(0.35, 1, slen),
				T * CFrame.new(x, 4.6, 70) * CFrame.Angles(ang, 0, 0),
				L.timberDark
			)
			part(
				dk,
				"Handrail",
				Vector3.new(0.3, 0.3, slen - 1.0),
				T * CFrame.new(x, 8.2, 70) * CFrame.Angles(ang, 0, 0),
				L.timber
			)
			for k = 0, 3 do
				local z = 62.45 + k * 15.1 / 3
				local y = (78 - z) * 10 / 16
				box(
					dk,
					"Handrail post",
					Vector3.new(x - 0.19, y - 0.1, z - 0.2),
					Vector3.new(x + 0.19, y + 3.6, z + 0.2),
					L.timberDark,
					false,
					T
				)
			end
		end
		task.wait()

		-- GONDOLA STATION (x 39..61, z 27..45, deck +10): concrete base with a garage door, a plate deck, railings, a
		-- steel canopy on four columns over the bullwheel, the parked red cabin; the cable runs out over the edge
		local st = folder(f, "Station")
		col("Station", 50, 36, 22, 18, 9.4, 0, T, Enum.Material.Concrete)
		box(
			st,
			"Plinth",
			Vector3.new(38.7, 0, 26.7),
			Vector3.new(61.3, 1.0, 45.3),
			L.concreteDark,
			false,
			T
		)
		box(st, "Base", Vector3.new(39, 1.0, 27), Vector3.new(61, 9.0, 45), L.concrete, false, T)
		for _, x in { 39, 61 } do
			for _, z in { 27, 45 } do
				box(
					st,
					"Pier",
					Vector3.new(x - 0.6, 1.0, z - 0.6),
					Vector3.new(x + 0.6, 9.0, z + 0.6),
					L.concreteDark,
					false,
					T
				)
			end
		end
		box(
			st,
			"Garage door",
			Vector3.new(44, 1.0, 26.8),
			Vector3.new(56, 7.5, 27),
			L.steel,
			false,
			T
		)
		for k = 0, 7 do
			local y = 1.6 + k * 0.8
			box(
				st,
				"Door slat",
				Vector3.new(44.1, y, 26.72),
				Vector3.new(55.9, y + 0.1, 26.8),
				L.steelDark,
				false,
				T
			)
		end
		box(
			st,
			"Door lintel",
			Vector3.new(43.4, 7.5, 26.6),
			Vector3.new(56.6, 8.3, 27),
			L.concreteDark,
			false,
			T
		)
		box(st, "Deck", Vector3.new(38.6, 9.0, 26.6), Vector3.new(61.4, 10, 45.4), L.plate, true, T)
		box(
			st,
			"Deck edge",
			Vector3.new(38.5, 9.0, 26.5),
			Vector3.new(61.5, 9.3, 45.5),
			L.steelDark,
			false,
			T
		)
		-- railings: the east (cable) side, the south side and the north side; the west side is open to the stair
		-- and the steps
		box(
			st,
			"Rail",
			Vector3.new(60.9, 12.8, 26.8),
			Vector3.new(61.3, 13.2, 45.2),
			L.steel,
			true,
			T
		)
		box(
			st,
			"Rail",
			Vector3.new(38.9, 12.82, 26.8),
			Vector3.new(60.9, 13.18, 27.2),
			L.steel,
			true,
			T
		)
		box(
			st,
			"Rail",
			Vector3.new(38.9, 12.82, 44.8),
			Vector3.new(60.9, 13.18, 45.2),
			L.steel,
			true,
			T
		)
		for z = 27.6, 44.4, 2.1 do
			box(
				st,
				"Rail post",
				Vector3.new(60.95, 10, z - 0.1),
				Vector3.new(61.25, 12.8, z + 0.1),
				L.steelDark,
				false,
				T
			)
		end
		for x = 39.6, 60.4, 2.6 do
			box(
				st,
				"Rail post",
				Vector3.new(x - 0.1, 10, 26.85),
				Vector3.new(x + 0.1, 12.8, 27.15),
				L.steelDark,
				false,
				T
			)
			box(
				st,
				"Rail post",
				Vector3.new(x - 0.1, 10, 44.85),
				Vector3.new(x + 0.1, 12.8, 45.15),
				L.steelDark,
				false,
				T
			)
		end
		for _, x in { 43, 59 } do
			for _, z in { 29, 43 } do
				box(
					st,
					"Canopy column",
					Vector3.new(x - 0.5, 10, z - 0.5),
					Vector3.new(x + 0.5, 20, z + 0.5),
					L.steel,
					true,
					T
				)
			end
		end
		box(
			st,
			"Canopy beam",
			Vector3.new(42.4, 20, 28.4),
			Vector3.new(59.6, 21, 43.6),
			L.steelDark,
			true, -- solid: covers the column tops (no perch under the canopy)
			T
		)
		box(
			st,
			"Canopy roof",
			Vector3.new(41.5, 21, 27.5),
			Vector3.new(60.5, 21.6, 44.5),
			L.roof,
			true,
			T
		)
		box(
			st,
			"Canopy snow",
			Vector3.new(41.8, 21.6, 27.8),
			Vector3.new(60.2, 21.95, 44.2),
			L.snow,
			false,
			T
		)
		kit("Snowpeak4", "Bullwheel", st, T * CFrame.new(53, 17, 36))
		box(
			st,
			"Bullwheel mount",
			Vector3.new(52.6, 17.4, 35.6),
			Vector3.new(53.4, 20, 36.4),
			L.steelDark,
			false,
			T
		)
		kit(
			"Snowpeak4",
			"GondolaCabin",
			st,
			T * CFrame.new(46, 9.95, 36) * CFrame.Angles(0, math.pi / 2, 0)
		)
		box(
			st,
			"Cabin rail",
			Vector3.new(44, 19.0, 35.7),
			Vector3.new(53, 19.4, 36.3),
			L.steelDark,
			false,
			T
		)
		-- the cable pair out east: to a tower down the slope, then up the far mountain; cabins on it
		for _, dz in { -4.6, 4.6 } do
			local a = Vector3.new(58, 17, 36 + dz)
			local b = Vector3.new(170, 24, 36 + dz)
			local c = Vector3.new(560, 190, 36 + dz)
			beam(st, "Cable", a, b, 0.25, 0.25, L.cable, T)
			beam(st, "Cable", b, c, 0.25, 0.25, L.cable, T)
		end
		box(st, "Tower", Vector3.new(169, -40, 34.5), Vector3.new(171, 24, 37.5), L.steel, false, T)
		box(
			st,
			"Tower head",
			Vector3.new(168.5, 24, 30.4),
			Vector3.new(171.5, 25, 41.6),
			L.steelDark,
			false,
			T
		)
		for i, t in { 0.32, 0.72 } do
			local p = Vector3.new(170, 24, 0):Lerp(Vector3.new(560, 190, 0), t)
			local z = if i == 1 then 36 + 4.6 else 36 - 4.6
			kit(
				"Snowpeak4",
				"GondolaCabin",
				st,
				T * CFrame.new(p.X, p.Y - 10, z) * CFrame.Angles(0, math.pi / 2, 0),
				"Hanging cabin"
			)
		end
		local p1 = Vector3.new(58, 17, 0):Lerp(Vector3.new(170, 24, 0), 0.55)
		kit(
			"Snowpeak4",
			"GondolaCabin",
			st,
			T * CFrame.new(p1.X, p1.Y - 10, 36 - 4.6) * CFrame.Angles(0, math.pi / 2, 0),
			"Hanging cabin"
		)
		-- the stair (x 34..39, z 43..59, 10 down to 0, 32 degrees) and the stone steps (3.5 -> 7) on the west side
		local sramp = wedge(
			secCollision,
			"Station stair" .. h.tag,
			Vector3.new(5, 10, 16),
			T * CFrame.new(36.5, 5, 51) * CFrame.Angles(0, math.pi, 0),
			{ color = C.steel },
			true
		)
		sramp.Transparency = 1
		sramp.CastShadow = false
		for k = 1, 16 do
			local z1 = 59 - (k - 1)
			box(
				st,
				"Tread",
				Vector3.new(34.2, k * 10 / 16 - 0.3, z1 - 0.97),
				Vector3.new(38.8, k * 10 / 16 - 0.02, z1),
				L.plate,
				false,
				T
			)
		end
		for _, x in { 34, 39 } do
			part(
				st,
				"Stringer",
				Vector3.new(0.35, 1, slen),
				T * CFrame.new(x, 4.6, 51) * CFrame.Angles(ang, 0, 0),
				L.steelDark
			)
		end
		part(
			st,
			"Handrail",
			Vector3.new(0.25, 0.25, slen - 1.0),
			T * CFrame.new(34, 8.2, 51) * CFrame.Angles(ang, 0, 0),
			L.steel
		)
		for k = 0, 3 do
			local z = 43.45 + k * 15.1 / 3
			local y = (59 - z) * 10 / 16
			box(
				st,
				"Handrail post",
				Vector3.new(33.85, y - 0.1, z - 0.2),
				Vector3.new(34.15, y + 3.6, z + 0.2),
				L.steelDark,
				false,
				T
			)
		end
		for _, s in { { 34, 39, 7, "Step high" }, { 29, 34, 3.5, "Step low" } } do
			box(
				st,
				s[4],
				Vector3.new(s[1], 0, 27.5),
				Vector3.new(s[2] - (if s[2] == 39 then 0.4 else 0), s[3] - 0.3, 32.5),
				L.stone,
				true,
				T
			)
			box(
				st,
				s[4] .. " cap",
				Vector3.new(s[1] - 0.15, s[3] - 0.3, 27.35),
				Vector3.new(s[2] - (if s[2] == 39 then 0.4 else 0.05), s[3], 32.65),
				L.stoneDark,
				true,
				T
			)
			box(
				st,
				s[4] .. " snow",
				Vector3.new(s[1] + 0.2, s[3], 27.6),
				Vector3.new(s[2] - 0.6, s[3] + 0.12, 32.4),
				L.snowShade,
				false,
				T
			)
		end
		drift(st, 39, 61, 45.3, 1, T)
		task.wait()

		-- SNOWCAT (the modelled kit, 95%) on the east flank of the pond, blade toward the middle
		local sc = kit(
			"Snowpeak4",
			"Snowcat",
			f,
			T * CFrame.new(30, 0, 12 - 1.05) * CFrame.Angles(0, 0, 0)
		)
		sc:ScaleTo(0.95)
		col("Snowcat", 30, 12, 8, 15, 9, 0, T, Enum.Material.Metal)

		-- WARMING HUT (x -27..-15, z 13.5..22.5): timber on a stone base, a gable roof, a stovepipe, door + windows
		local wh = folder(f, "Warming hut")
		col("Warming hut", -21, 18, 12, 9, 10, 0, T, Enum.Material.Wood)
		box(
			wh,
			"Base",
			Vector3.new(-27.2, 0, 13.3),
			Vector3.new(-14.8, 1.0, 22.7),
			L.stone,
			false,
			T
		)
		box(
			wh,
			"Walls",
			Vector3.new(-27, 1.0, 13.5),
			Vector3.new(-15, 6.6, 22.5),
			L.timberLight,
			false,
			T
		)
		for _, cx in { -27, -15 } do
			for _, cz in { 13.5, 22.5 } do
				box(
					wh,
					"Corner post",
					Vector3.new(cx - 0.4, 1.0, cz - 0.4),
					Vector3.new(cx + 0.4, 6.6, cz + 0.4),
					L.timberDark,
					false,
					T
				)
			end
		end
		window(wh, "S", 13.5, -23.5, 3, 2.4, 2.4, T)
		window(wh, "N", 22.5, -18.5, 3, 2.4, 2.4, T)
		box(
			wh,
			"Door",
			Vector3.new(-15, 1.0, 16.2),
			Vector3.new(-14.75, 6.0, 19.8),
			L.red,
			false,
			T
		)
		box(
			wh,
			"Door frame",
			Vector3.new(-15.0, 1.0, 15.8),
			Vector3.new(-14.85, 6.4, 20.2),
			L.timberDark,
			false,
			T
		)
		gableRoof(wh, -27, -15, 13.5, 22.5, 6.6, 10, 1.0, T, L.timberLight)
		box(
			wh,
			"Stovepipe",
			Vector3.new(-24.3, 8, 19.2),
			Vector3.new(-23.7, 11.5, 19.8),
			L.steelDark,
			false,
			T
		)
		drift(wh, -27, -15, 13.3, -1, T)

		-- PATROL HUT (x -15..15, z 66.5..73.5, the spawn screen): timber with the side's paint on the end boards, a
		-- shed roof falling to the spawn side, windows toward the middle, the patrol cross (an icon) by the door
		local ph = folder(f, "Patrol hut")
		col("Patrol hut", 0, 70, 30, 7, 10, 0, T, Enum.Material.Wood)
		box(
			ph,
			"Base",
			Vector3.new(-15.2, 0, 66.3),
			Vector3.new(15.2, 1.0, 73.7),
			L.stone,
			false,
			T
		)
		box(
			ph,
			"Walls",
			Vector3.new(-15, 1.0, 66.5),
			Vector3.new(15, 8.4, 73.5),
			L.timber,
			false,
			T
		)
		for _, x in { -15, 15 } do
			box(
				ph,
				"End board",
				Vector3.new(x - 0.5, 0.95, 66.3),
				Vector3.new(x + 0.5, 8.5, 73.7),
				paint,
				false,
				T
			)
		end
		for _, u in { -9, -3, 3, 9 } do
			window(ph, "S", 66.5, u, 3.4, 3, 2.6, T)
		end
		for _, u in { -9, 9 } do -- the spawn side too (it is the first thing you see)
			window(ph, "N", 73.5, u, 3.4, 3, 2.6, T)
		end
		local rc = Vector3.new(0, 9.2, 70)
		-- the roof falls toward the spawn (+Z); a timber fill under its high (middle-side) edge closes the wall head
		part(
			ph,
			"Roof",
			Vector3.new(31.6, 0.5, 9.0),
			T * CFrame.new(rc) * CFrame.Angles(math.rad(9), 0, 0),
			L.roof
		)
		part(
			ph,
			"Roof snow",
			Vector3.new(31.2, 0.3, 8.6),
			T * CFrame.new(rc) * CFrame.Angles(math.rad(9), 0, 0) * CFrame.new(0, 0.38, 0),
			L.snow
		)
		local fc = Vector3.new(0, 8.95, 70)
		wedge(
			ph,
			"Roof fill",
			Vector3.new(30, 1.1, 7),
			T * CFrame.lookAt(fc, fc + Vector3.new(0, 0, 1)),
			L.timber
		)
		box(ph, "Door", Vector3.new(-2, 1.0, 73.5), Vector3.new(2, 7, 73.75), L.red, false, T)
		box(
			ph,
			"Cross panel",
			Vector3.new(3.2, 4.4, 73.5),
			Vector3.new(5.8, 7.0, 73.62),
			L.red,
			false,
			T
		)
		box(
			ph,
			"Cross",
			Vector3.new(4.25, 4.75, 73.62),
			Vector3.new(4.75, 6.65, 73.7),
			look(C.snow),
			false,
			T
		)
		box(
			ph,
			"Cross",
			Vector3.new(3.55, 5.45, 73.62),
			Vector3.new(5.45, 5.95, 73.74),
			look(C.snow),
			false,
			T
		)
		drift(ph, -15, 15, 66.3, -1, T)

		-- TICKET BOOTH (x -14..-8, z 51.5..56.5): a small timber booth with a counter window and a gable roof
		local tb = folder(f, "Ticket booth")
		col("Ticket booth", -11, 54, 6, 5, 9, 0, T, Enum.Material.Wood)
		box(
			tb,
			"Base",
			Vector3.new(-14.15, 0, 51.35),
			Vector3.new(-7.85, 0.6, 56.65),
			L.stone,
			false,
			T
		)
		box(
			tb,
			"Walls",
			Vector3.new(-14, 0.6, 51.5),
			Vector3.new(-8, 6.4, 56.5),
			L.timber,
			false,
			T
		)
		box(tb, "Hatch", Vector3.new(-13, 3.2, 51.35), Vector3.new(-9, 5.6, 51.5), L.glow, false, T)
		box(
			tb,
			"Hatch frame",
			Vector3.new(-13.3, 5.6, 51.25),
			Vector3.new(-8.7, 5.95, 51.5),
			L.timberDark,
			false,
			T
		)
		box(
			tb,
			"Counter",
			Vector3.new(-13.4, 2.9, 50.9),
			Vector3.new(-8.6, 3.2, 51.5),
			L.timberDark,
			false,
			T
		)
		gableRoof(tb, -14, -8, 51.5, 56.5, 6.4, 9, 0.8, T, L.timber)

		-- PINE CLUMPS (trunk-height collision, foliage above)
		for _, pc in { { -50, 84, 12, 8 }, { 31, 80, 12, 10 } } do
			col("Pines", pc[1], pc[2], pc[3] - 3, pc[4] - 3, 25, 0, T, Enum.Material.Wood)
			kit(
				"Snowpeak4",
				"PineA",
				f,
				T * CFrame.new(pc[1] - 2.5, 0, pc[2] - 1.5) * CFrame.Angles(0, 0.4, 0)
			)
			kit(
				"Snowpeak4",
				"PineB",
				f,
				T * CFrame.new(pc[1] + 3, 0, pc[2] + 1.5) * CFrame.Angles(0, 1.9, 0)
			)
			local small = kit(
				"Snowpeak4",
				"PineB",
				f,
				T * CFrame.new(pc[1] - 0.5, 0, pc[2] + 3.4) * CFrame.Angles(0, 3.1, 0)
			)
			small:ScaleTo(0.75)
		end

		-- WOODSHED (x -75..-68, z 68..80, against the west fence beside the lodge): open toward the map (+X), stacked
		-- timber inside, a mono-pitch roof falling to the fence
		local ws = folder(f, "Woodshed")
		col("Woodshed", -71.5, 74, 7, 12, 9, 0, T, Enum.Material.Wood)
		box(
			ws,
			"Back wall",
			Vector3.new(-75, 0, 68.25),
			Vector3.new(-74.5, 8, 79.75),
			L.timberDark,
			false,
			T
		)
		for _, z in { 68, 80 } do
			box(
				ws,
				"Side wall",
				Vector3.new(-75, 0, z - 0.25),
				Vector3.new(-68, 8, z + 0.25),
				L.timberDark,
				false,
				T
			)
			local wc = Vector3.new(-71.5, 8.45, z)
			wedge(
				ws,
				"Wall rake",
				Vector3.new(0.5, 0.9, 7),
				T * CFrame.lookAt(wc, wc + Vector3.new(-1, 0, 0)) * CFrame.Angles(0, 0, 0),
				L.timberDark
			)
		end
		for row = 0, 4 do
			for k = 0, 3 do
				local z0 = 68.4 + k * 2.85
				box(
					ws,
					"Timber",
					Vector3.new(-74.4, row * 1.2, z0),
					Vector3.new(-68.9 - (row % 2) * 0.3, row * 1.2 + 1.2, z0 + 2.75),
					if (row + k) % 2 == 0 then L.timberLight else L.timber,
					false,
					T
				)
			end
		end
		local wr = Vector3.new(-71.5, 8.6, 74)
		part(
			ws,
			"Roof",
			Vector3.new(8.4, 0.5, 13.2),
			T * CFrame.new(wr) * CFrame.Angles(0, 0, math.rad(8)),
			L.roof
		)
		part(
			ws,
			"Roof snow",
			Vector3.new(8.0, 0.3, 12.8),
			T * CFrame.new(wr) * CFrame.Angles(0, 0, math.rad(8)) * CFrame.new(0, 0.38, 0),
			L.snow
		)

		-- low cover: a lumber stack, a snowbank, supply crates, the crate stack by the station, a ski rack, sleds
		local lc = folder(f, "Low cover")
		col("Log pile", -38, 28, 9, 3.5, 3.5, 0, T, Enum.Material.Wood)
		for row = 0, 2 do
			for k = 0, 2 do
				local z0 = 26.35 + k * 1.1
				box(
					lc,
					"Lumber",
					Vector3.new(-42.4 + (row % 2) * 0.3, row * 1.15, z0),
					Vector3.new(-33.6 + (row % 2) * 0.3, row * 1.15 + 1.15, z0 + 1.05),
					if (row + k) % 2 == 0 then L.timberLight else L.timber,
					false,
					T
				)
			end
		end
		for _, x in { -41.5, -34.5 } do
			box(
				lc,
				"Bearer",
				Vector3.new(x - 0.3, 3.45, 26.2),
				Vector3.new(x + 0.3, 3.6, 29.8),
				L.snow,
				false,
				T
			)
		end
		col("Snowbank", 14, 34, 10, 4, 3, 0, T, Enum.Material.Snow)
		box(
			lc,
			"Snowbank",
			Vector3.new(9.5, 0, 33),
			Vector3.new(18.5, 2.4, 35),
			L.snowShade,
			false,
			T
		)
		for _, s in { -1, 1 } do
			local c = Vector3.new(14, 1.2, 34 + s * 1.5)
			wedge(
				lc,
				"Snowbank side",
				Vector3.new(9, 2.4, 1),
				T * CFrame.lookAt(c, c + Vector3.new(0, 0, s)),
				L.snowShade
			)
		end
		box(
			lc,
			"Snowbank top",
			Vector3.new(9.8, 2.4, 33.4),
			Vector3.new(18.2, 3.0, 34.6),
			L.snow,
			false,
			T
		)
		crate(lc, "Supply crates", 22, 56, 10, 5, 0, 3.5, T)
		crate(lc, "Crate stack", 60, 60, 5, 5, 0, 6, T)
		crate(lc, "Crate stack top", 60, 60, 5, 5, 6, 6, T)
		-- ski rack and sleds (owner playtest 2026-11-21: the coloured-brick skis "ruin the map"): the modelled kit
		-- pieces (timber rack with skis, bindings and poles; wooden toboggans stacked crosswise)
		col("Ski rack", -1, 44, 9, 2, 3.5, 0, T, Enum.Material.Wood)
		kit("Snowpeak4", "SkiRack", lc, T * CFrame.new(-1, 0, 44.2))
		col("Sled stack", 47, 84, 6, 3, 3.5, 0, T, Enum.Material.Wood)
		for k = 0, 3 do
			kit(
				"Snowpeak4",
				"Sled",
				lc,
				T
					* CFrame.new(47 + (k % 2) * 0.25, k * 0.66, 84)
					* CFrame.Angles(0, math.pi / 2 + math.rad(if k % 2 == 0 then 3 else -4), 0)
			)
		end

		-- CHARACTER (owner playtest 2026-11-21: "it needs more character")
		local ch = folder(f, "Character")
		-- lantern posts on the routes (warm lit cores), the trail sign by the spawn (run icons, no text)
		for _, lp in { { 8, 58, 0.3 }, { -21, 60, 1.1 }, { 44, 64, 2.2 } } do
			col("Lamp", lp[1], lp[2], 0.9, 0.9, 9.6, 0, T, Enum.Material.Metal)
			local m = kit(
				"Snowpeak4",
				"LampPost",
				ch,
				T * CFrame.new(lp[1], 0, lp[2]) * CFrame.Angles(0, lp[3], 0)
			)
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") and string.find(d.Name, "LampGlow") then
					d.Material = Enum.Material.Neon
				end
			end
		end
		col("Trail sign", -36, 86, 0.8, 0.8, 7.5, 0, T, Enum.Material.Wood)
		kit("Snowpeak4", "TrailSign", ch, T * CFrame.new(-36, 0, 86) * CFrame.Angles(0, math.pi, 0))
		-- the fire pit west of the lodge porch, with smoke and a warm light
		col("Fire pit", -50, 71, 4.6, 4.6, 1.0, 0, T, Enum.Material.Slate)
		local fp = kit("Snowpeak4", "FirePit", ch, T * CFrame.new(-50, 0, 71))
		for _, d in fp:GetDescendants() do
			if d:IsA("BasePart") and string.find(d.Name, "Glow") then
				d.Material = Enum.Material.Neon
				local pl = Instance.new("PointLight")
				pl.Color = Color3.fromRGB(255, 150, 80)
				pl.Range = 14
				pl.Brightness = 1.2
				pl.Parent = d
				-- the flames: a fire ParticleEmitter over the embers (the logs stand round it), then smoke above
				local fire = Instance.new("ParticleEmitter")
				fire.Name = "Flames"
				fire.Texture = "rbxasset://textures/particles/fire_main.dds"
				fire.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 214, 120)),
					ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 140, 50)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 60, 30)),
				})
				fire.LightEmission = 0.9
				fire.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.2),
					NumberSequenceKeypoint.new(0.7, 0.45),
					NumberSequenceKeypoint.new(1, 1),
				})
				fire.Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1.1),
					NumberSequenceKeypoint.new(1, 0.25),
				})
				fire.Lifetime = NumberRange.new(0.5, 0.9)
				fire.Rate = 26
				fire.Speed = NumberRange.new(1.6, 2.8)
				fire.SpreadAngle = Vector2.new(8, 8)
				fire.RotSpeed = NumberRange.new(-40, 40)
				fire.Rotation = NumberRange.new(0, 360)
				fire.EmissionDirection = Enum.NormalId.Top
				fire.Parent = d
				local sm = Instance.new("ParticleEmitter")
				sm.Name = "Smoke"
				sm.Texture = "rbxasset://textures/particles/smoke_main.dds"
				sm.Color = ColorSequence.new(Color3.fromRGB(120, 118, 115))
				sm.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.6),
					NumberSequenceKeypoint.new(1, 1),
				})
				sm.Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1.2),
					NumberSequenceKeypoint.new(1, 4.5),
				})
				sm.Lifetime = NumberRange.new(3, 5)
				sm.Rate = 4
				sm.Speed = NumberRange.new(4, 6)
				sm.SpreadAngle = Vector2.new(12, 12)
				sm.EmissionDirection = Enum.NormalId.Top
				sm.Parent = d
			end
		end
		-- benches on the lodge deck against the wall, facing the middle
		for _, bz in { 44, 56 } do
			kit(
				"Snowpeak4",
				"Bench",
				ch,
				T * CFrame.new(-37.6, 10, bz) * CFrame.Angles(0, -math.pi / 2, 0)
			)
		end
		-- icicles under the lodge's long eaves and the warming hut's (pairs of wedges pointing down)
		local ice = { color = hex("C9DDEA"), mat = Enum.Material.Ice }
		local function icicles(x0: number, x1: number, z: number, y: number, seed: number)
			local rnd = Random.new(seed)
			local x = x0 + 0.4
			while x < x1 - 0.4 do
				local len = rnd:NextNumber(0.5, 1.7)
				local w = rnd:NextNumber(0.22, 0.34)
				for _, s2 in { -1, 1 } do
					local c = Vector3.new(x + s2 * w / 4, y - len / 2, z)
					local p = part(
						ch,
						"Icicle",
						Vector3.new(0.14, len, w / 2),
						T
							* CFrame.new(c)
							* CFrame.Angles(
								0,
								if s2 > 0 then math.pi / 2 else -math.pi / 2,
								math.pi
							),
						ice,
						false,
						"WedgePart"
					)
					p.Transparency = 0.15
					p.CastShadow = false
				end
				x += rnd:NextNumber(0.6, 1.1)
			end
		end
		local lodgeFascia = 10 - 1.6 * math.tan(math.atan2(10, 12)) - 0.75
		icicles(-66.4, -37.6, 36.4 - 0.15 + 0.3, lodgeFascia + 0.02, 11)
		icicles(-66.4, -37.6, 63.6 + 0.15 - 0.3, lodgeFascia + 0.02, 12)
		local hutFascia = 6.6 - 1.0 * math.tan(math.atan2(3.4, 4.5)) - 0.75
		icicles(-27.8, -14.2, 12.5 - 0.15 + 0.3, hutFascia + 0.02, 13)
		-- string lights along the lodge deck railing and over the porch: a dark cable with warm bulbs
		local wire = { color = hex("2A2724") }
		local bulbCols = { hex("F2C46A"), hex("E8875A"), hex("F2C46A"), hex("9CC8E6") }
		local function lights(a: Vector3, b: Vector3, sag: number)
			local n = math.max(2, math.floor((b - a).Magnitude / 1.3))
			local prev = a
			for i = 1, n do
				local t = i / n
				local q = a:Lerp(b, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
				beam(ch, "Light wire", prev, q, 0.06, 0.06, wire, T)
				if i < n then
					local bulb = part(
						ch,
						"Light bulb",
						Vector3.new(0.22, 0.3, 0.22),
						T * CFrame.new(q - Vector3.new(0, 0.2, 0)),
						{ color = bulbCols[i % 4 + 1], mat = Enum.Material.Neon }
					)
					bulb.CastShadow = false
				end
				prev = q
			end
		end
		lights(Vector3.new(-29.1, 13.3, 38.2), Vector3.new(-29.1, 13.3, 50), 0.5)
		lights(Vector3.new(-29.1, 13.3, 50), Vector3.new(-29.1, 13.3, 61.8), 0.5)
		lights(Vector3.new(-55.2, 8.55, 64.75), Vector3.new(-48.8, 8.55, 64.75), 0.35)
		-- trodden snow: paths from the spawn to the lodge porch, the lodge stair and the station stair
		local trod = { color = hex("D4DCE6"), variant = "Snow2_Snow", mat = Enum.Material.Snow }
		local pathN = 0
		local function path(pts: { Vector3 }, w: number)
			for i = 1, #pts - 1 do
				pathN += 1 -- each segment a hair higher than the last: overlapping joints never share a plane
				local a2, b2 = pts[i], pts[i + 1]
				local mid = (a2 + b2) / 2
				local len = (b2 - a2).Magnitude + w * 0.6
				part(
					ch,
					"Trodden snow",
					Vector3.new(w, 0.05, len),
					T * CFrame.lookAt(mid, b2) * CFrame.new(0, 0, 0)
						+ Vector3.new(0, 0.003 + pathN * 0.012, 0),
					trod
				).CastShadow =
					false
			end
		end
		path({
			Vector3.new(-6, 0, 82),
			Vector3.new(-20, 0, 76),
			Vector3.new(-30, 0, 70),
			Vector3.new(-48, 0, 66),
		}, 3.6)
		path({ Vector3.new(-20, 0, 76), Vector3.new(-34, 0, 79) }, 3.0)
		path({ Vector3.new(6, 0, 82), Vector3.new(22, 0, 76), Vector3.new(36.5, 0, 61) }, 3.6)
		task.wait()
		task.wait()

		-- the ridge behind the spawns and the slopes below the fence: pines (no collision, out of reach)
		local forest = folder(secWorld, "Forest" .. h.tag)
		local rnd = Random.new(7)
		local placed: { Vector3 } = {}
		local function clear(x: number, z: number): boolean
			for _, q in placed do
				if (q - Vector3.new(x, 0, z)).Magnitude < 6 then
					return false
				end
			end
			table.insert(placed, Vector3.new(x, 0, z))
			return true
		end

		for _ = 1, 22 do
			local x, z = rnd:NextNumber(-180, 180), rnd:NextNumber(102, 170)
			local y = (z - 95) / 85 * 45
			if not clear(x, z) then
				continue
			end
			local pk = kit(
				"Snowpeak4",
				if rnd:NextNumber() < 0.5 then "PineA" else "PineB",
				forest,
				T * CFrame.new(x, y - 0.5, z) * CFrame.Angles(0, rnd:NextNumber(0, 6.28), 0)
			)
			pk:ScaleTo(rnd:NextNumber(0.85, 1.3))
		end
		for _ = 1, 16 do
			local x, z = rnd:NextNumber(86, 132), rnd:NextNumber(-90, 90)
			local y = -(x - 75) / 60 * 40
			if not clear(x, z) then
				continue
			end
			local pk = kit(
				"Snowpeak4",
				if rnd:NextNumber() < 0.5 then "PineA" else "PineB",
				forest,
				T * CFrame.new(x, y - 0.6, z) * CFrame.Angles(0, rnd:NextNumber(0, 6.28), 0)
			)
			pk:ScaleTo(rnd:NextNumber(0.9, 1.3))
		end
		task.wait()
	end

	-- smoke from the chimneys and gentle snowfall (map life, cheap rates)
	local life = folder(secWorld, "Life")
	for _, h in halves do
		for _, c in { { Vector3.new(-58.5, 23.8, 44.5), 4 }, { Vector3.new(-24, 11.6, 19.5), 2 } } do
			local src = part(
				life,
				"Smoke source",
				Vector3.new(0.4, 0.4, 0.4),
				h.T * CFrame.new(c[1]),
				{ color = C.stone }
			)
			src.Transparency = 1
			src.CastShadow = false
			local sm = Instance.new("ParticleEmitter")
			sm.Texture = "rbxasset://textures/particles/smoke_main.dds"
			sm.Color = ColorSequence.new(Color3.fromRGB(196, 198, 204))
			sm.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.45),
				NumberSequenceKeypoint.new(1, 1),
			})
			sm.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1.5),
				NumberSequenceKeypoint.new(1, 7),
			})
			sm.Lifetime = NumberRange.new(5, 8)
			sm.Rate = c[2]
			sm.Speed = NumberRange.new(3, 5)
			sm.Acceleration = Vector3.new(1.5, 0.4, 0)
			sm.SpreadAngle = Vector2.new(10, 10)
			sm.EmissionDirection = Enum.NormalId.Top
			sm.Parent = src
		end
	end
	local sky =
		part(life, "Snowfall", Vector3.new(170, 1, 210), CFrame.new(0, 55, 0), { color = C.snow })
	sky.Transparency = 1
	sky.CastShadow = false
	local snow = Instance.new("ParticleEmitter")
	snow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	snow.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	snow.LightEmission = 0.2
	snow.Size = NumberSequence.new(0.18)
	snow.Lifetime = NumberRange.new(14, 18)
	snow.Rate = 45
	snow.Speed = NumberRange.new(3, 4.5)
	snow.SpreadAngle = Vector2.new(18, 18)
	snow.Acceleration = Vector3.new(0.6, 0, 0.3)
	snow.EmissionDirection = Enum.NormalId.Bottom
	snow.Parent = sky

	------------------------------------------------------------------------------------------------ mountains
	local mtn = folder(secWorld, "Mountains")
	for _, m in
		{
			{ "MountainA", 0, 900, 0 },
			{ "MountainB", -700, 650, 0.6 },
			{ "MountainC", 650, 600, 2.0 },
			{ "MountainA", 120, -950, 3.1 },
			{ "MountainB", 760, -600, 3.8 },
			{ "MountainC", -640, -620, 5.0 },
			{ "MountainB", 980, 120, 1.4 },
			{ "MountainB", -1000, -80, 4.4 },
		}
	do
		kit("Snowpeak4", m[1], mtn, CFrame.new(m[2], -40, m[3]) * CFrame.Angles(0, m[4], 0))
	end
	task.wait()

	------------------------------------------------------------------------------------------- spawns, bounds, stage
	local SPAWNS = { { -12, 89 }, { 0, 91 }, { 12, 89 }, { -6, 85 }, { 6, 85 } }
	for team, h in halves do
		local letter = if team == 1 then "A" else "B"
		for i, s in SPAWNS do
			local sp = Instance.new("SpawnLocation")
			sp.Name = "Spawn_" .. letter .. i
			sp.Size = Vector3.new(4, 0.2, 4)
			sp.CFrame = ORIGIN * h.T * CFrame.new(s[1], 0.1, s[2]) * CFrame.Angles(0, 0, 0)
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
		local p = box(secBounds, "Bound", a, b, { color = C.stone }, true)
		p.Transparency = 1
		p.CanQuery = false
		p.CastShadow = false
	end
	bound(Vector3.new(75, -6, -96), Vector3.new(77, 45, 96))
	bound(Vector3.new(-77, -6, -96), Vector3.new(-75, 45, 96))
	bound(Vector3.new(-77, -6, 95), Vector3.new(77, 45, 97))
	bound(Vector3.new(-77, -6, -97), Vector3.new(77, 45, -95))
	bound(Vector3.new(-77, 45, -97), Vector3.new(77, 47, 97))
	local stage = part(
		map,
		"WinnerStage",
		Vector3.new(4, 0.2, 4),
		CFrame.new(0, 0.1, 60) * CFrame.Angles(0, 0, 0),
		{ color = C.snow }
	)
	stage.Transparency = 1
	stage.CastShadow = false
	CollectionService:AddTag(stage, "WinnerStage")

	------------------------------------------------------------------------------------------- lighting
	local light = Instance.new("Configuration")
	light.Name = "Lighting"
	CollectionService:AddTag(light, "GGAsset_MatchMaps_416")
	CollectionService:AddTag(light, "GauntletAuthoredData")
	light.Parent = map
	local fx = folder(map, "LightingFx")
	local atm = Instance.new("Atmosphere")
	atm.Density = 0.32
	atm.Offset = 0.12
	atm.Haze = 1.6
	atm.Glare = 0.15
	atm.Color = Color3.fromRGB(214, 224, 238)
	atm.Decay = Color3.fromRGB(150, 166, 196)
	atm.Parent = fx
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "Grade"
	cc.Contrast = 0.06
	cc.Saturation = 0.02
	cc.TintColor = Color3.fromRGB(252, 252, 255)
	cc.Parent = fx

	-- RIVALS texture pass
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
	return string.format("Snowpeak4 built: %d parts", count)
end
