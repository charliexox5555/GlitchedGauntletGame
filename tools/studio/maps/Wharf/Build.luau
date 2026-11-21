--!strict
-- Wharf (regular map, 1v1-2v2), the whole build (2026-11-20). Plan, measurements and build log:
-- vault/01 Design/Maps/Wharf.md. Layout rows mirror tools/maps/wharf_layout.py (the `half` rows are turned
-- 180 degrees for team B). Match place only, edit mode. Returns a function; run it with
--   require(<a clone of this module>)()
-- (the Studio MCP clones it so edits are picked up). Rebuilds Workspace.Wharf from scratch every run.
--
-- How it's built (owner 2026-11-20, RIVALS Docks studied, never copied):
--   * mostly Parts on the 5-stud module; every exposed end carved (WedgePart chamfers, battered plinths,
--     members that end in a joint); no round shapes;
--   * Blender only for the quay crane, mountains, ship (ServerStorage.MapKit.Wharf) and the port kit
--     containers + bollards (ServerStorage.MapKit.Port, recoloured here);
--   * our own MaterialVariants Wharf_* (tools/textures/make_wharf_textures.py), faint; one accent: crane yellow;
--   * Collision = invisible boxes from the layout (the play truth, with an impact material); visuals don't
--     collide or take queries, except floors, steps, roofs and parapets, which are their own collision.
-- Map contract: Spawns (ArenaSpawn_A/B), Barriers (empty: ghost hold), Bounds (invisible walls + ceiling),
-- KillDepth (authored data: the water kills), Lighting (Configuration, authored data) + LightingFx,
-- a WinnerStage part, Config/Match MAPS entry.

local CollectionService = game:GetService("CollectionService")
local MaterialService = game:GetService("MaterialService")
local ServerStorage = game:GetService("ServerStorage")

local ORIGIN = CFrame.new(6000, 200, 6000) -- deck top at the pier centre
local ROT = CFrame.Angles(0, math.pi, 0) -- team B's half

-- Palette v2 (owner 2026-11-20: v1 was "dull and boring"): warm light concrete, dark asphalt, a bright sea,
-- port colours on the containers (like a real yard, and like RIVALS Docks' clarity), each half's buildings in
-- its own paint so the sides read by colour (A blue, B green; never the team cyan / orange-red), crane yellow.
local C = {
	deck = Color3.fromHex("C2BDB2"),
	deckDark = Color3.fromHex("8F8A80"),
	asphalt = Color3.fromHex("4E525A"),
	line = Color3.fromHex("F0BE2E"),
	lineWhite = Color3.fromHex("ECEBE5"),
	steel = Color3.fromHex("3E4654"),
	steelLight = Color3.fromHex("5C6676"),
	officeWall = Color3.fromHex("E6DFCF"),
	officeBase = Color3.fromHex("6B6E74"),
	glass = Color3.fromHex("2A3446"),
	timber = Color3.fromHex("C39A64"),
	timberDark = Color3.fromHex("94704A"),
	rubber = Color3.fromHex("2B2D31"),
	water = Color3.fromHex("2A62AE"),
	pile = Color3.fromHex("8A857B"),
	yellow = Color3.fromHex("EBB531"),
	yellowDark = Color3.fromHex("B98A22"),
	slate = Color3.fromHex("737D89"),
	slateDark = Color3.fromHex("5B636D"),
}
-- container paints: body, frame
local PAINT: { [string]: { Color3 } } = {
	blue = { Color3.fromHex("3F72BE"), Color3.fromHex("2D5491") },
	green = { Color3.fromHex("4E9E58"), Color3.fromHex("3A7843") },
	red = { Color3.fromHex("C4473B"), Color3.fromHex("962F27") },
	orange = { Color3.fromHex("E58A2E"), Color3.fromHex("B46A1F") },
	yellow = { Color3.fromHex("EBB531"), Color3.fromHex("B98A22") },
	white = { Color3.fromHex("DADDDE"), Color3.fromHex("A9AEB3") },
	grey = { Color3.fromHex("8C919B"), Color3.fromHex("6F747E") },
}
-- each half's building paint: cladding, trim (columns, eaves, frames), roof, doors
local SIDE = {
	A = {
		wall = Color3.fromHex("4F82C4"),
		trim = Color3.fromHex("27416B"),
		roof = Color3.fromHex("3C4656"),
		door = Color3.fromHex("E6DFCF"),
	},
	B = {
		wall = Color3.fromHex("5AA368"),
		trim = Color3.fromHex("2D5A37"),
		roof = Color3.fromHex("3E4A44"),
		door = Color3.fromHex("E6DFCF"),
	},
}

-- v2 textures (2026-11-20, owner: "a bit much"): half the contrast and bump of v1
local VARIANTS = {
	Wharf_Concrete = { "Concrete", 10, "98131730598502", "101527228918911" },
	Wharf_Asphalt = { "Asphalt", 8, "129833585742683", "87143270766313" },
	Wharf_Plank = { "WoodPlanks", 5, "93605016079302", "106545793761281" },
	Wharf_Ribbed = { "Metal", 4, "135858628433618", "72834346090990" },
	Wharf_Plate = { "DiamondPlate", 5, "116955307704363", "89970433895475" },
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

type Look = { color: Color3, mat: Enum.Material?, variant: string? }
local L = {
	concrete = { color = C.deck, mat = Enum.Material.Concrete, variant = "Wharf_Concrete" },
	concreteDark = { color = C.deckDark, mat = Enum.Material.Concrete, variant = "Wharf_Concrete" },
	asphalt = { color = C.asphalt, mat = Enum.Material.Asphalt, variant = "Wharf_Asphalt" },
	plank = { color = C.timber, mat = Enum.Material.WoodPlanks, variant = "Wharf_Plank" },
	plankDark = { color = C.timberDark, mat = Enum.Material.WoodPlanks, variant = "Wharf_Plank" },
	ribbedDoor = { color = C.slate, mat = Enum.Material.Metal, variant = "Wharf_Ribbed" },
	plate = { color = C.steel, mat = Enum.Material.DiamondPlate, variant = "Wharf_Plate" },
	plateLight = { color = C.steelLight, mat = Enum.Material.DiamondPlate, variant = "Wharf_Plate" },
	steel = { color = C.steel },
	steelLight = { color = C.steelLight },
	render = { color = C.officeWall, mat = Enum.Material.Concrete, variant = "Wharf_Concrete" },
	base = { color = C.officeBase, mat = Enum.Material.Concrete, variant = "Wharf_Concrete" },
	glass = { color = C.glass },
	rubber = { color = C.rubber },
	line = { color = C.line },
	lineWhite = { color = C.lineWhite },
	water = { color = C.water },
	pile = { color = C.pile, mat = Enum.Material.Concrete, variant = "Wharf_Concrete" },
	yellow = { color = C.yellow },
	yellowDark = { color = C.yellowDark },
}

return function(): string
	assert(game.PlaceId == 133387545285290, "Wharf: not the match place")
	ensureVariants()
	local old = workspace:FindFirstChild("Wharf")
	if old then
		old:Destroy()
	end
	local map = Instance.new("Model")
	map.Name = "Wharf"
	map.WorldPivot = ORIGIN
	CollectionService:AddTag(map, "GGAsset_MatchMaps_411")
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
	folder(map, "Barriers") -- ghost hold: no spawn walls
	local secBounds = folder(map, "Bounds")
	local count = 0

	-- one Part. cf is in map space (relative to ORIGIN). solid = collides + takes shots.
	local function part(
		parent: Instance,
		name: string,
		size: Vector3,
		cf: CFrame,
		look: Look,
		solid: boolean?,
		class: string?
	): BasePart
		local p = Instance.new(class or "Part") :: BasePart
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = ORIGIN * cf
		p.Color = look.color
		p.Material = look.mat or Enum.Material.SmoothPlastic
		if look.variant then
			p.MaterialVariant = look.variant
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
		look: Look,
		solid: boolean?
	): BasePart
		return part(parent, name, size, cf, look, solid, "WedgePart")
	end
	-- an axis box from corner a to corner b (map space)
	local function box(
		parent: Instance,
		name: string,
		a: Vector3,
		b: Vector3,
		look: Look,
		solid: boolean?,
		T: CFrame?
	): BasePart
		local lo, hi = a:Min(b), a:Max(b)
		return part(
			parent,
			name,
			hi - lo,
			(T or CFrame.identity) * CFrame.new((lo + hi) / 2),
			look,
			solid
		)
	end
	-- the collision truth from the layout (invisible), with an impact material
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
			{ color = C.deck, mat = mat },
			true
		)
		p.Transparency = 1
		p.CastShadow = false
		return p
	end
	-- a chamfer strip along an edge: a WedgePart lying on `top` along X (len), sloping toward -Z by default
	local function chamferX(
		parent: Instance,
		name: string,
		len: number,
		size: number,
		cf: CFrame,
		look: Look
	)
		return wedge(parent, name, Vector3.new(len, size, size), cf, look)
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
	local function paint(m: Model, name: string)
		local c = PAINT[name]
		if not c or name == "grey" then
			return
		end
		local body, frame = c[1], c[2]
		for _, p in m:GetDescendants() do
			if p:IsA("MeshPart") then
				if p.Name:match("_C_Grey$") then
					p.Color = body
				elseif p.Name:match("_C_GreyDark$") then
					p.Color = frame
				end
			end
		end
	end

	local halves = { { T = CFrame.identity, tag = "" }, { T = ROT, tag = "'" } }

	------------------------------------------------------------------------------------------------- deck
	local deck = folder(secStructure, "Deck")
	-- concrete pier x -40..65, asphalt yard x -65..-40, a sunken landing cut in each outer lane (x 55..65 /
	-- -65..-55, z -7.5..7.5). Slabs 4 thick (top 0); their faces line the pits.
	box(deck, "Slab", Vector3.new(-40, -4, -92.5), Vector3.new(55, 0, 92.5), L.concrete, true)
	box(deck, "Slab", Vector3.new(55, -4, 7.5), Vector3.new(65, 0, 92.5), L.concrete, true)
	box(deck, "Slab", Vector3.new(55, -4, -92.5), Vector3.new(65, 0, -7.5), L.concrete, true)
	box(deck, "Yard", Vector3.new(-55, -4, -92.5), Vector3.new(-40, 0, 92.5), L.asphalt, true)
	box(deck, "Yard", Vector3.new(-65, -4, 7.5), Vector3.new(-55, 0, 92.5), L.asphalt, true)
	box(deck, "Yard", Vector3.new(-65, -4, -92.5), Vector3.new(-55, 0, -7.5), L.asphalt, true)
	-- the yard runs on past the west bound to the stacks and the far shore
	box(deck, "Yard apron", Vector3.new(-240, -4, -160), Vector3.new(-65, 0, 160), L.asphalt, true)
	box(deck, "Yard apron", Vector3.new(-65, -4, 92.5), Vector3.new(-40, 0, 160), L.asphalt, true)
	box(deck, "Yard apron", Vector3.new(-65, -4, -160), Vector3.new(-40, 0, -92.5), L.asphalt, true)
	-- kerb between asphalt and concrete: a low concrete strip, 0.15 proud, its two top edges chamfered

	-- pits: the landing (team A, east: timber, steps at its north end) and the loading pit (team B, west:
	-- concrete, steps at its south end). Built in A's frame, turned for B.
	for i, h in halves do
		local pit = folder(deck, "Pit" .. h.tag)
		local floorLook = if i == 1 then L.plank else L.concreteDark
		box(
			pit,
			"Pit floor",
			Vector3.new(55, -4.5, -7.5),
			Vector3.new(65, -3, 7.5),
			floorLook,
			true,
			h.T
		)
		box(
			pit,
			"Pit step",
			Vector3.new(55, -3, 3.75),
			Vector3.new(65, -2, 7.5),
			L.concreteDark,
			true,
			h.T
		)
		box(
			pit,
			"Pit step",
			Vector3.new(55, -2, 5.75),
			Vector3.new(65, -1, 7.5),
			L.concreteDark,
			true,
			h.T
		)
		-- nosing on each step (a steel angle, proud)
		box(
			pit,
			"Step nosing",
			Vector3.new(55, -2, 3.6),
			Vector3.new(65, -1.85, 3.9),
			L.steel,
			false,
			h.T
		)
		box(
			pit,
			"Step nosing",
			Vector3.new(55, -1, 5.6),
			Vector3.new(65, -0.85, 5.9),
			L.steel,
			false,
			h.T
		)
		-- the pit's wall lining (a darker band where the slab is cut), set 0.06 proud of the slab face
		box(
			pit,
			"Pit lining",
			Vector3.new(55, -3, -7.45),
			Vector3.new(55.06, -0.3, 7.45),
			L.concreteDark,
			false,
			h.T
		)
		-- the edge of the pit is painted (accent): a stripe on the deck along the cut
		box(
			pit,
			"Pit edge line",
			Vector3.new(53.8, -0.02, -7.5),
			Vector3.new(54.6, 0.04, 7.5),
			L.line,
			false,
			h.T
		)
		for _, zz in { -7.5, 7.5 } do
			box(
				pit,
				"Pit edge line",
				Vector3.new(54.6, -0.02, zz - 0.4),
				Vector3.new(65, 0.04, zz + 0.4),
				L.line,
				false,
				h.T
			)
		end
	end

	-- floor cues: a yellow safety line 2.5 in from the water edges, white bay lines in the yard
	local cues = folder(deck, "Lines")
	box(
		cues,
		"Edge line",
		Vector3.new(61.8, -0.02, 8.3),
		Vector3.new(62.3, 0.04, 92.5 - 2.8),
		L.line
	)
	box(
		cues,
		"Edge line",
		Vector3.new(61.8, -0.02, -92.5 + 2.8),
		Vector3.new(62.3, 0.04, -8.3),
		L.line
	)
	box(cues, "Edge line", Vector3.new(-38.6, -0.02, 89.7), Vector3.new(61.8, 0.04, 90.2), L.line)
	box(cues, "Edge line", Vector3.new(-61.8, -0.02, -90.2), Vector3.new(38.6, 0.04, -89.7), L.line)
	for _, z in { -82.5, -67.5, -52.5, -37.5, 22.5, 37.5, 52.5 } do
		box(
			cues,
			"Bay line",
			Vector3.new(-64, -0.02, z - 0.25),
			Vector3.new(-56, 0.04, z + 0.25),
			L.lineWhite
		)
	end
	box(
		cues,
		"Lane line",
		Vector3.new(-48.25, -0.02, 20),
		Vector3.new(-47.75, 0.04, 60),
		L.lineWhite
	)

	-- pier edge: fascia beam (0.6 proud, top chamfered) round the water edges, rubber fenders, piles
	local edge = folder(secStructure, "Edge")
	local function edgeRun(x0: number, z0: number, x1: number, z1: number, out: Vector3)
		-- out: unit vector pointing to the water
		local len = math.max(math.abs(x1 - x0), math.abs(z1 - z0))
		local along = if math.abs(x1 - x0) > 0.1 then Vector3.xAxis else Vector3.zAxis
		local mid = Vector3.new((x0 + x1) / 2, 0, (z0 + z1) / 2)
		local yaw = math.atan2(-out.X, -out.Z) -- CFrame looks along -Z; face the water
		local cf = CFrame.new(mid) * CFrame.Angles(0, yaw, 0)
		-- in this frame: X along the edge, -Z toward the water
		part(
			edge,
			"Fascia",
			Vector3.new(len, 3.4, 0.6),
			cf * CFrame.new(0, -1.7 - 0.0, -0.3),
			L.concreteDark
		)
		wedge(
			edge,
			"Fascia cap",
			Vector3.new(len, 0.3, 0.6),
			cf * CFrame.new(0, 0.15, -0.3),
			L.concreteDark
		)
		-- fenders every 10 (rubber, carved: a chamfered block with sloped top/bottom)
		local n = math.floor(len / 10)
		for k = 0, n - 1 do
			local t = -len / 2 + 5 + k * 10
			part(
				edge,
				"Fender",
				Vector3.new(1.4, 2.2, 0.7),
				cf * CFrame.new(t, -1.9, -0.95),
				L.rubber
			)
			wedge(
				edge,
				"Fender cap",
				Vector3.new(1.4, 0.4, 0.7),
				cf * CFrame.new(t, -0.6, -0.95),
				L.rubber
			)
			-- pile under every fender: a square pile with a cap collar
			part(edge, "Pile", Vector3.new(1.8, 9, 1.8), cf * CFrame.new(t, -8.5, 1.4), L.pile)
			part(
				edge,
				"Pile collar",
				Vector3.new(2.4, 0.8, 2.4),
				cf * CFrame.new(t, -4.45, 1.4),
				L.concreteDark
			)
		end
		local _ = along
	end
	edgeRun(65, -92.5, 65, -7.5, Vector3.xAxis)
	edgeRun(65, 7.5, 65, 92.5, Vector3.xAxis)
	edgeRun(-39.4, 92.5, 65, 92.5, Vector3.zAxis)
	edgeRun(-39.4, -92.5, 40, -92.5, -Vector3.zAxis)
	-- the far shore edge of the yard apron
	edgeRun(-240, -160, -240, 160, -Vector3.xAxis)
	edgeRun(-240, 160, -40, 160, Vector3.zAxis)
	edgeRun(-240, -160, -40, -160, -Vector3.zAxis)
	-- apron ends at x -40 beyond the pier ends (z 92.5..160 / -160..-92.5): fascia toward +x
	edgeRun(-40, 92.5, -40, 160, Vector3.xAxis)
	edgeRun(-40, -160, -40, -92.5, Vector3.xAxis)
	task.wait()

	-- railings on the water edges (gunmetal posts every 5, two rails; rail ends die into end posts)
	local rail = folder(secProps, "Railing")
	local function railRun(x0: number, z0: number, x1: number, z1: number, skipEnds: boolean?)
		local a, b = Vector3.new(x0, 0, z0), Vector3.new(x1, 0, z1)
		local len = (b - a).Magnitude
		local dir = (b - a).Unit
		local cf = CFrame.lookAt(a, b) -- -Z along the run
		local n = math.max(1, math.floor(len / 5 + 0.5))
		for k = 0, n do
			if skipEnds and (k == 0 or k == n) then
				continue
			end
			local p = a + dir * (len * k / n)
			part(
				rail,
				"Post",
				Vector3.new(0.45, 3.1, 0.45),
				CFrame.new(p + Vector3.new(0, 1.75, 0)) * (cf - cf.Position),
				L.steel
			)
			part(
				rail,
				"Post foot",
				Vector3.new(0.9, 0.22, 0.9),
				CFrame.new(p + Vector3.new(0, 0.1, 0)) * (cf - cf.Position),
				L.steel
			)
		end
		for _, y in { 1.6, 3.1 } do
			part(
				rail,
				"Rail",
				Vector3.new(0.35, 0.35, len),
				cf * CFrame.new(0, y, -len / 2),
				L.steelLight
			)
		end
	end
	railRun(64.6, -88.4, 64.6, -7.5)
	railRun(64.6, 7.5, 64.6, 88.4)
	railRun(64.6, -7.5, 64.6, 7.5, true) -- across the open side of the landing (end posts are the quay runs')
	railRun(-34.4, 92.1, 64.6, 92.1)
	railRun(-39.4, -92.1, 34.4, -92.1)
	railRun(-64.6, -7.5, -64.6, 7.5) -- loading pit's yard side (no quay runs on this side)
	task.wait()

	------------------------------------------------------------------------------------------------ sheds
	local function shed(
		T: CFrame,
		tag: string,
		side: { wall: Color3, trim: Color3, roof: Color3, door: Color3 }
	)
		local s = folder(secStructure, "Shed" .. tag)
		local wallLook = { color = side.wall, mat = Enum.Material.Metal, variant = "Wharf_Ribbed" }
		local roofLook = { color = side.roof, mat = Enum.Material.Metal, variant = "Wharf_Ribbed" }
		local trimLook = { color = side.trim }
		local doorLook = { color = side.door, mat = Enum.Material.Metal, variant = "Wharf_Ribbed" }
		local x0, x1, z0, z1 = 17.5, 37.5, -10, 50
		local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
		local W, D = x1 - x0, z1 - z0
		col("Shed" .. tag, cx, cz, W, D, 14, 0, T, Enum.Material.Metal)
		-- Layered depths so every piece sits on the one below (owner 2026-11-20: "the pillars don't line up with the
		-- supports"): plinth 0.6 proud > eave beam 0.55 > columns 0.45 > cladding. Columns stand on the plinth and tuck
		-- under the eave; the corner columns wrap the corner.
		box(
			s,
			"Plinth",
			Vector3.new(x0 - 0.6, 0, z0 - 0.6),
			Vector3.new(x1 + 0.6, 1.5, z1 + 0.6),
			L.concreteDark,
			false,
			T
		)
		for _, side in { { x0, -1 }, { x1, 1 } } do
			wedge(
				s,
				"Plinth chamfer",
				Vector3.new(D + 1.2, 0.4, 0.4),
				T
					* CFrame.new(side[1] + side[2] * 0.4, 1.7, cz)
					* CFrame.Angles(0, if side[2] > 0 then -math.pi / 2 else math.pi / 2, 0),
				L.concreteDark
			)
		end
		for _, side in { { z0, -1 }, { z1, 1 } } do
			wedge(
				s,
				"Plinth chamfer",
				Vector3.new(W + 1.2, 0.4, 0.4),
				T
					* CFrame.new(cx, 1.7, side[1] + side[2] * 0.4)
					* CFrame.Angles(0, if side[2] > 0 then math.pi else 0, 0),
				L.concreteDark
			)
		end
		box(s, "Cladding", Vector3.new(x0, 1.5, z0), Vector3.new(x1, 13.4, z1), wallLook, false, T)
		for z = z0, z1, 10 do
			local za, zb = z - 0.5, z + 0.5
			if z == z0 then
				za = z0 - 0.45
			elseif z == z1 then
				zb = z1 + 0.45
			end
			box(
				s,
				"Column",
				Vector3.new(x0 - 0.45, 1.5, za),
				Vector3.new(x0, 13.4, zb),
				trimLook,
				false,
				T
			)
			box(
				s,
				"Column",
				Vector3.new(x1, 1.5, za),
				Vector3.new(x1 + 0.45, 13.4, zb),
				trimLook,
				false,
				T
			)
		end
		for x = x0 + 10, x1 - 10, 10 do
			box(
				s,
				"Column",
				Vector3.new(x - 0.5, 1.5, z0 - 0.45),
				Vector3.new(x + 0.5, 13.4, z0),
				trimLook,
				false,
				T
			)
			box(
				s,
				"Column",
				Vector3.new(x - 0.5, 1.5, z1),
				Vector3.new(x + 0.5, 13.4, z1 + 0.45),
				trimLook,
				false,
				T
			)
		end
		box(
			s,
			"Eave",
			Vector3.new(x0 - 0.55, 13.4, z0 - 0.55),
			Vector3.new(x1 + 0.55, 14.2, z1 + 0.55),
			trimLook,
			true,
			T
		)
		-- gable roof (owner 2026-11-20: "the roofs don't line up, there are holes"): the roof planes now lie exactly on
		-- the gables' slope (rise 7 over the half-width 10, from the eave top at 14.2), run 1.2 past the walls, and
		-- cross 0.3 past the ridge under a bigger ridge cap, so there is no gap anywhere
		local rise, half, over, t = 7, W / 2, 1.2, 0.6
		local k = rise / half
		local ang = math.atan(k)
		local run = half + over + 0.3
		local slope = run / math.cos(ang)
		local hc = (half + over - 0.3) / 2 -- horizontal distance of the plane centre from the ridge
		local under = 14.2 + k * (half - hc)
		local yc = under + (t / 2) / math.cos(ang)
		for _, sgn in { -1, 1 } do
			part(
				s,
				"Roof",
				Vector3.new(slope, t, D + 2.4),
				T * CFrame.new(cx + sgn * hc, yc, cz) * CFrame.Angles(0, 0, -sgn * ang),
				roofLook,
				true
			)
			-- fascia board over the roof plane's lower end
			box(
				s,
				"Fascia",
				Vector3.new(cx + sgn * (half + over - 0.1), 13.1, cz - D / 2 - 1.4),
				Vector3.new(cx + sgn * (half + over + 0.35), 14.2, cz + D / 2 + 1.4),
				trimLook,
				false,
				T
			)
		end
		part(
			s,
			"Ridge",
			Vector3.new(1.6, 1.6, D + 2.6),
			T
				* CFrame.new(cx, 14.2 + rise + t / math.cos(ang) - 0.05, cz)
				* CFrame.Angles(0, 0, math.pi / 4),
			trimLook
		)
		-- gable ends: two wedges fill each triangle exactly under the roof planes
		for _, side in { { z0, -1 }, { z1, 1 } } do
			for _, sgn in { -1, 1 } do
				wedge(
					s,
					"Gable",
					Vector3.new(0.6, rise, half),
					T
						* CFrame.new(cx + sgn * half / 2, 14.2 + rise / 2, side[1] - side[2] * 0.3)
						* CFrame.Angles(0, -sgn * math.pi / 2, 0),
					wallLook,
					true
				)
			end
		end
		-- roller doors: one on the mid-lane face, two on the dock face; each a darker ribbed panel 0.15 proud
		-- inside a steel frame (head + two jambs, 0.3 proud), with a kick plate
		local function door(xFace: number, outward: number, zc: number, w: number, h: number)
			local xo = xFace + outward * 0.08
			box(
				s,
				"Door",
				Vector3.new(xo - 0.08, 1.5, zc - w / 2),
				Vector3.new(xo + 0.08, 1.5 + h, zc + w / 2),
				doorLook,
				false,
				T
			)
			local xf = xFace + outward * 0.15
			box(
				s,
				"Door head",
				Vector3.new(xf - 0.15, 1.5 + h, zc - w / 2 - 0.6),
				Vector3.new(xf + 0.15, 2.3 + h, zc + w / 2 + 0.6),
				trimLook,
				false,
				T
			)
			for _, sgn in { -1, 1 } do
				box(
					s,
					"Door jamb",
					Vector3.new(xf - 0.15, 1.5, zc + sgn * (w / 2 + 0.3) - 0.3),
					Vector3.new(xf + 0.15, 1.5 + h, zc + sgn * (w / 2 + 0.3) + 0.3),
					trimLook,
					false,
					T
				)
			end
			box(
				s,
				"Kick plate",
				Vector3.new(xo - 0.12, 1.5, zc - w / 2),
				Vector3.new(xo + 0.12, 2.3, zc + w / 2),
				trimLook,
				false,
				T
			)
		end
		door(x0, -1, 25, 7, 8.5) -- between the columns at 20 and 30
		door(x1, 1, 15, 7, 6.5)
		door(x1, 1, 35, 7, 6.5)
		-- clerestory windows on both long sides (dark glass 0.1 proud inside a frame 0.25 proud)
		for _, side in { { x0, -1 }, { x1, 1 } } do
			for _, zc in { 5, 45 } do
				local xg = side[1] + side[2] * 0.05
				box(
					s,
					"Glass",
					Vector3.new(xg - 0.05, 10.2, zc - 3),
					Vector3.new(xg + 0.05, 12.2, zc + 3),
					L.glass,
					false,
					T
				)
				local xf = side[1] + side[2] * 0.12
				box(
					s,
					"Window frame",
					Vector3.new(xf - 0.12, 9.8, zc - 3.4),
					Vector3.new(xf + 0.12, 10.2, zc + 3.4),
					trimLook,
					false,
					T
				)
				box(
					s,
					"Window frame",
					Vector3.new(xf - 0.12, 12.2, zc - 3.4),
					Vector3.new(xf + 0.12, 12.6, zc + 3.4),
					trimLook,
					false,
					T
				)
			end
		end
		-- loading dock (+3.5) on the quay side: concrete, steel nosing, rubber bumpers, steps at both ends
		col("Shed dock" .. tag, 40, 22.5, 5, 35, 3.5, 0, T, Enum.Material.Concrete)
		box(s, "Dock", Vector3.new(37.5, 0, 5), Vector3.new(42.5, 3.5, 40), L.concrete, false, T)
		box(
			s,
			"Dock nosing",
			Vector3.new(42.3, 3.2, 4.9),
			Vector3.new(42.65, 3.55, 40.1),
			trimLook,
			false,
			T
		)
		for z = 9, 37, 7 do
			box(
				s,
				"Dock bumper",
				Vector3.new(42.5, 1.2, z - 0.7),
				Vector3.new(43.1, 2.9, z + 0.7),
				L.rubber,
				false,
				T
			)
		end
		-- steps: three per end, 1.17 rise, 1.25 deep (solid: they are the walk)
		for k = 1, 3 do
			local top = 3.5 * k / 4
			box(
				s,
				"Dock step",
				Vector3.new(37.5, 0, 5 - (4 - k) * 1.25),
				Vector3.new(42.5, top, 5 - (3 - k) * 1.25),
				L.concreteDark,
				true,
				T
			)
			box(
				s,
				"Dock step",
				Vector3.new(37.5, 0, 40 + (3 - k) * 1.25),
				Vector3.new(42.5, top, 40 + (4 - k) * 1.25),
				L.concreteDark,
				true,
				T
			)
		end
	end
	shed(CFrame.identity, "", SIDE.A)
	shed(ROT, "'", SIDE.B)
	task.wait()

	----------------------------------------------------------------------------------------------- office
	local function office(
		T: CFrame,
		tag: string,
		side: { wall: Color3, trim: Color3, roof: Color3, door: Color3 }
	)
		local o = folder(secStructure, "Office" .. tag)
		local trimLook = { color = side.trim }
		local paintLook =
			{ color = side.wall, mat = Enum.Material.Concrete, variant = "Wharf_Concrete" }
		local x0, x1, z0, z1 = -65, -40, 72.5, 92.5
		col(
			"Office" .. tag,
			(x0 + x1) / 2,
			(z0 + z1) / 2,
			x1 - x0,
			z1 - z0,
			12,
			0,
			T,
			Enum.Material.Concrete
		)
		-- plinth (dark, battered by a chamfer strip), render walls, a belt course at the floor line, the roof slab
		box(o, "Plinth", Vector3.new(x0, 0, z0), Vector3.new(x1, 1.2, z1), L.base, false, T)
		box(o, "Plinth", Vector3.new(-45, 0, z0 - 0.3), Vector3.new(x1, 1.2, z0), L.base, false, T)
		wedge(
			o,
			"Plinth chamfer",
			Vector3.new(5, 0.3, 0.3),
			T * CFrame.new(-42.5, 1.35, z0 - 0.15),
			L.base
		)
		box(o, "Walls", Vector3.new(x0, 1.2, z0), Vector3.new(x1, 11.2, z1), L.render, false, T)
		box(
			o,
			"Belt",
			Vector3.new(x0 - 0.25, 5.8, z0 + 0.02),
			Vector3.new(x1 + 0.25, 6.4, z1 + 0.25),
			paintLook,
			false,
			T
		)
		box(
			o,
			"Belt",
			Vector3.new(-44.95, 5.8, z0 - 0.25),
			Vector3.new(x1 + 0.25, 6.4, z0 + 0.02),
			paintLook,
			false,
			T
		)
		box(
			o,
			"Roof slab",
			Vector3.new(x0, 11.2, z0 - 0.4),
			Vector3.new(x1, 12, z1),
			L.concreteDark,
			true,
			T
		)
		box(o, "Roof deck", Vector3.new(x0, 12, z0), Vector3.new(x1, 12.05, z1), L.plate, false, T)
		-- parapet (3 above the deck: low cover), open where the stair lands (east, z 86..92.5) and over the
		-- container (south, x -60..-47.5); every parapet end is cut back by a wedge
		-- (each wall carries its own coping run; runs abut, never overlap)
		local function parapet(a: Vector3, b: Vector3, ca: Vector3, cb: Vector3)
			box(o, "Parapet", a, b, L.render, true, T)
			box(
				o,
				"Parapet coping",
				Vector3.new(ca.X, 15, ca.Z),
				Vector3.new(cb.X, 15.3, cb.Z),
				L.concreteDark,
				false,
				T
			)
		end
		parapet(
			Vector3.new(x0, 12, z1 - 0.8),
			Vector3.new(x1, 15, z1),
			Vector3.new(x0 - 0.15, 0, z1 - 0.95),
			Vector3.new(x1 + 0.15, 0, z1 + 0.15)
		) -- north
		parapet(
			Vector3.new(x0, 12, z0),
			Vector3.new(x0 + 0.8, 15, z1 - 0.8),
			Vector3.new(x0 - 0.15, 0, z0 - 0.15),
			Vector3.new(x0 + 0.95, 0, z1 - 0.95)
		) -- west
		parapet(
			Vector3.new(x1 - 0.8, 12, z0),
			Vector3.new(x1, 15, 85.5),
			Vector3.new(x1 - 0.95, 0, z0 - 0.15),
			Vector3.new(x1 + 0.15, 0, 85.65)
		) -- east, to the stair opening
		parapet(
			Vector3.new(x0 + 0.8, 12, z0),
			Vector3.new(-60, 15, z0 + 0.8),
			Vector3.new(x0 + 0.95, 0, z0 - 0.15),
			Vector3.new(-59.85, 0, z0 + 0.95)
		) -- south, west of the opening
		parapet(
			Vector3.new(-47.5, 12, z0),
			Vector3.new(x1 - 0.8, 15, z0 + 0.8),
			Vector3.new(-47.65, 0, z0 - 0.15),
			Vector3.new(x1 - 0.95, 0, z0 + 0.95)
		) -- south, east of the opening
		-- windows: ground floor on the east and south, upper on the east (dark glass in a frame, sill wedge)
		local function window(face: string, u: number, y: number, w: number, h: number)
			if face == "E" then
				box(
					o,
					"Glass",
					Vector3.new(x1, y, u - w / 2),
					Vector3.new(x1 + 0.1, y + h, u + w / 2),
					L.glass,
					false,
					T
				)
				box(
					o,
					"Window frame",
					Vector3.new(x1, y + h, u - w / 2 - 0.3),
					Vector3.new(x1 + 0.3, y + h + 0.35, u + w / 2 + 0.3),
					trimLook,
					false,
					T
				)
				box(
					o,
					"Window sill",
					Vector3.new(x1, y - 0.35, u - w / 2 - 0.3),
					Vector3.new(x1 + 0.4, y, u + w / 2 + 0.3),
					L.base,
					false,
					T
				)
			else
				box(
					o,
					"Glass",
					Vector3.new(u - w / 2, y, z0 - 0.1),
					Vector3.new(u + w / 2, y + h, z0),
					L.glass,
					false,
					T
				)
				box(
					o,
					"Window frame",
					Vector3.new(u - w / 2 - 0.3, y + h, z0 - 0.3),
					Vector3.new(u + w / 2 + 0.3, y + h + 0.35, z0),
					trimLook,
					false,
					T
				)
				box(
					o,
					"Window sill",
					Vector3.new(u - w / 2 - 0.3, y - 0.35, z0 - 0.4),
					Vector3.new(u + w / 2 + 0.3, y, z0),
					L.base,
					false,
					T
				)
			end
		end
		-- (the stair runs up the east face and the container covers most of the south: windows where they show)
		window("E", 75, 7.2, 3, 2.4)
		window("S", -42.5, 2.5, 3, 2.4)
		window("S", -42.5, 7.2, 3, 2.4)
		-- a door on the east face under the stair landing, with a steel hood
		box(o, "Door", Vector3.new(x1, 1.2, 84), Vector3.new(x1 + 0.12, 7, 88), paintLook, false, T)
		box(
			o,
			"Door hood",
			Vector3.new(x1, 7.2, 83.4),
			Vector3.new(x1 + 1.2, 7.6, 88.6),
			L.steel,
			false,
			T
		)

		-- outside steel stair (x -40..-35, z 67.5 -> 86 rising 0 -> 12, landing 86..92.5): a smooth wedge for
		-- the walk, treads, two stringers, a handrail on the open side; carved stringer feet
		local sx0, sx1, sz0, sz1 = -40, -35, 67.5, 86
		local run = sz1 - sz0
		local ramp = wedge(
			secCollision,
			"Office stair" .. tag,
			Vector3.new(sx1 - sx0, 12, run),
			T * CFrame.new((sx0 + sx1) / 2, 6, (sz0 + sz1) / 2),
			{ color = C.steel, mat = Enum.Material.Metal },
			true
		)
		ramp.Transparency = 1
		ramp.CastShadow = false
		box(
			o,
			"Stair landing",
			Vector3.new(sx0, 11.4, sz1),
			Vector3.new(sx1, 12, 92.5),
			L.plate,
			true,
			T
		)
		local steps = 12
		for k = 1, steps do
			local zc = sz0 + (k - 0.5) * run / steps
			box(
				o,
				"Tread",
				Vector3.new(sx0 + 0.3, k - 0.8, zc - run / steps / 2),
				Vector3.new(sx1 - 0.3, k - 0.4, zc + run / steps / 2),
				L.plateLight,
				false,
				T
			)
		end
		local ang = math.atan2(12, run)
		local slen = math.sqrt(run * run + 144)
		for _, xx in { sx0 + 0.15, sx1 - 0.15 } do
			part(
				o,
				"Stringer",
				Vector3.new(0.3, 1.0, slen - 0.5),
				T * CFrame.new(xx, 6 - 0.3, (sz0 + sz1) / 2) * CFrame.Angles(-ang, 0, 0),
				L.steel
			)
		end
		-- handrail (open east side): sloped rail on posts; it dies into the landing post at the top
		part(
			o,
			"Handrail",
			Vector3.new(0.24, 0.3, slen - 0.4),
			T * CFrame.new(sx1 - 0.15, 6 + 3.2, (sz0 + sz1) / 2) * CFrame.Angles(-ang, 0, 0),
			L.steelLight
		)
		for k = 0, 3 do
			local zz = sz0 + 1 + k * (run - 2) / 3
			local yy = (zz - sz0) / run * 12
			part(
				o,
				"Handrail post",
				Vector3.new(0.35, 3.2, 0.35),
				T * CFrame.new(sx1 - 0.15, yy + 1.6, zz),
				L.steel
			)
		end
		box(
			o,
			"Landing post",
			Vector3.new(sx1 - 0.35, 12, sz1),
			Vector3.new(sx1, 15.3, sz1 + 0.35),
			L.steel,
			false,
			T
		)
		box(
			o,
			"Landing post",
			Vector3.new(sx1 - 0.35, 12, 92.15),
			Vector3.new(sx1, 15.3, 92.5),
			L.steel,
			false,
			T
		)
		box(
			o,
			"Landing rail",
			Vector3.new(sx1 - 0.28, 14.85, sz1 + 0.35),
			Vector3.new(sx1 - 0.07, 15.15, 92.15),
			L.steelLight,
			false,
			T
		)
		-- the landing sits on two steel legs
		for _, zz in { 86.5, 92 } do
			box(
				o,
				"Landing leg",
				Vector3.new(sx1 - 0.7, 0, zz - 0.35),
				Vector3.new(sx1 - 0.0, 11.4, zz + 0.35),
				L.steel,
				false,
				T
			)
		end
	end
	office(CFrame.identity, "", SIDE.A)
	office(ROT, "'", SIDE.B)
	task.wait()

	--------------------------------------------------------------------------------------- containers
	local props = secProps
	local cont = folder(props, "Containers")
	-- name, x, z, along_z, length, base, colour ("grey" | "slate" | "yellow"), flip
	local CONTAINERS = {
		{ "Spawn container", 5, 62.5, false, 20, 0, "red", false },
		{ "Mid cross", -5, 37.5, false, 20, 0, "blue", true },
		{ "Mid stack", -7.5, 37.5, false, 15, 10, "orange", false },
		{ "Yard container", -40, 37.5, true, 30, 0, "green", false },
		{ "Yard reefer", -57.5, 12.5, false, 15, 0, "white", true },
		{ "Quay container", 50, 62.5, true, 20, 0, "yellow", true },
		{ "Quay box", 52.5, 27.5, true, 15, 0, "red", false },
		{ "Office container", -55, 67.5, false, 20, 0, "blue", false },
	}
	local function placeContainer(
		name: string,
		x: number,
		z: number,
		alongZ: boolean,
		len: number,
		base: number,
		colour: string,
		flip: boolean,
		T: CFrame,
		solidOnly: boolean?
	)
		local piece = "ContainerGrey" .. len
		local yaw = (if alongZ then math.pi / 2 else 0) + (if flip then math.pi else 0)
		local cf = T * CFrame.new(x, base, z) * CFrame.Angles(0, yaw, 0)
		local m = kit("Port", piece, cont, cf, name)
		paint(m, colour)
		local sx, sz = if alongZ then 10 else len, if alongZ then len else 10
		col(name, x, z, sx, sz, base + 10, base, T, Enum.Material.Metal)
		local _ = solidOnly
	end
	for _, h in halves do
		for _, r in CONTAINERS do
			placeContainer(r[1] .. h.tag, r[2], r[3], r[4], r[5], r[6], r[7], r[8], h.T)
		end
	end
	placeContainer("Mid container", 0, 0, true, 20, 0, "white", false, CFrame.identity)
	task.wait()

	------------------------------------------------------------------------------------------- crates
	-- a crate unit: plank body (it is the collision), four corner battens and a lid rim, both 0.1 proud;
	-- a skid under it. Stacks are units on top of each other, the upper one turned a few degrees.
	local crates = folder(props, "Crates")
	local function crate(
		name: string,
		cx: number,
		cz: number,
		sx: number,
		sz: number,
		y0: number,
		h: number,
		T: CFrame,
		tilt: number?
	)
		local cf = T * CFrame.new(cx, y0 + h / 2, cz) * CFrame.Angles(0, math.rad(tilt or 0), 0)
		local body = part(crates, name, Vector3.new(sx, h, sz), cf, L.plank, true)
		body.Material = Enum.Material.WoodPlanks
		for _, cx2 in { -1, 1 } do
			for _, cz2 in { -1, 1 } do
				part(
					crates,
					"Batten",
					Vector3.new(0.7, h - 0.04, 0.7),
					cf * CFrame.new(cx2 * (sx / 2 - 0.2), 0, cz2 * (sz / 2 - 0.2)),
					L.plankDark
				)
			end
		end
		part(
			crates,
			"Lid rim",
			Vector3.new(sx + 0.1, 0.32, sz + 0.1),
			cf * CFrame.new(0, h / 2 - 0.22, 0),
			L.plankDark
		)
		part(
			crates,
			"Band",
			Vector3.new(sx + 0.1, 0.32, sz + 0.1),
			cf * CFrame.new(0, -h / 2 + 0.6, 0),
			L.plankDark
		)
	end
	for _, h in halves do
		local t = h.tag
		crate("Dock crate" .. t, 40, 12.5, 5, 5, 3.5, 4.25, h.T, 4) -- on the dock: the stack reaches 12, 8.5 over the dock (not climbable: no perch chain to the quay box)
		crate("Dock crate top" .. t, 40, 12.5, 5, 5, 7.75, 4.25, h.T, -3)
		col("Dock crate stack" .. t, 40, 12.5, 5, 5, 12, 0, h.T, Enum.Material.Wood)
		crate("Office step high" .. t, -42.5, 62.5, 5, 5, 0, 3.5, h.T)
		crate("Office step high top" .. t, -42.5, 62.5, 5, 5, 3.5, 3.5, h.T, 3)
		crate("Office step low" .. t, -42.5, 57.4, 4.8, 4.8, 0, 3.5, h.T, -2)
		crate("Mid crates" .. t, 0, 20, 10, 5, 0, 3.5, h.T)
		crate("Mid crate stack" .. t, -15, 27.5, 5, 10, 0, 5, h.T)
		crate("Mid crate stack top" .. t, -15, 27.5, 5, 10, 5, 5, h.T, 2)
		crate("Yard crates" .. t, -22.5, 57.5, 10, 5, 0, 3.5, h.T, -1)
	end
	task.wait()

	-- bollards along the quay edges (kit, with a small collision box) and a few pallets by the shed doors
	local boll = folder(props, "Bollards")
	for i, h in halves do
		for _, z in { 22.5, 45, 77.5 } do
			if i == 1 then
				kit("Port", "Bollard", boll, h.T * CFrame.new(63.3, 0, z), "Bollard")
			else
				-- the same footprint on the yard side is a wheel stop (a chamfered concrete block)
				box(
					boll,
					"Wheel stop",
					Vector3.new(62.5, 0, z - 0.8),
					Vector3.new(64.1, 1.6, z + 0.8),
					L.concreteDark,
					false,
					h.T
				)
				wedge(
					boll,
					"Wheel stop cap",
					Vector3.new(1.6, 0.5, 0.8),
					h.T * CFrame.new(63.3, 1.85, z - 0.4) * CFrame.Angles(0, math.pi, 0),
					L.concreteDark
				)
				wedge(
					boll,
					"Wheel stop cap",
					Vector3.new(1.6, 0.5, 0.8),
					h.T * CFrame.new(63.3, 1.85, z + 0.4),
					L.concreteDark
				)
			end
			col("Bollard", 63.3, z, 1.6, 1.6, 2.4, 0, h.T, Enum.Material.Metal)
		end
	end
	local pallets = folder(props, "Pallets")
	for _, h in halves do
		for i, p in { { 13.5, 23, 0 }, { 13.5, 23, 0.6 } } do
			local cf = h.T * CFrame.new(p[1], p[3], p[2]) * CFrame.Angles(0, math.rad(4 * i), 0)
			for _, dz in { -1.6, 0, 1.6 } do
				part(
					pallets,
					"Pallet runner",
					Vector3.new(3.6, 0.4, 0.5),
					cf * CFrame.new(0, 0.2, dz),
					L.plankDark
				)
			end
			part(
				pallets,
				"Pallet deck",
				Vector3.new(3.6, 0.2, 3.8),
				cf * CFrame.new(0, 0.5, 0),
				L.plank
			)
		end
	end
	task.wait()

	--------------------------------------------------------------------------------------------- world
	-- the ocean: one blue plane (a 3 x 3 of 2048 tiles: a Part can't be bigger), its top at -7, no collision
	local sea = folder(secWorld, "Ocean")
	for i = -1, 1 do
		for j = -1, 1 do
			local p = part(
				sea,
				"Ocean",
				Vector3.new(2048, 1, 2048),
				CFrame.new(i * 2048, -7.5, j * 2048),
				L.water
			)
			p.CastShadow = false
		end
	end
	-- the outer berth east of the pier (a 10-stud channel between), the quay crane on it, a ship alongside
	local berth = folder(secWorld, "Berth")
	box(berth, "Berth slab", Vector3.new(75, -4, -75), Vector3.new(118, 0, 75), L.concrete)
	edgeRun(75, -75, 75, 75, -Vector3.xAxis)
	edgeRun(118, -75, 118, 75, Vector3.xAxis)
	edgeRun(75, 75, 118, 75, Vector3.zAxis)
	edgeRun(75, -75, 118, -75, -Vector3.zAxis)
	for _, x in { 80, 110 } do
		box(
			berth,
			"Crane rail",
			Vector3.new(x - 0.4, 0, -75),
			Vector3.new(x + 0.4, 0.3, 75),
			L.steel
		)
	end
	box(berth, "Berth line", Vector3.new(76.5, -0.02, -74), Vector3.new(77, 0.04, 74), L.line)
	kit("Wharf", "QuayCrane", berth, CFrame.new(95, 0, -8), "Quay crane")
	kit(
		"Wharf",
		"Ship",
		berth,
		CFrame.new(152, -6, -5) * CFrame.Angles(0, math.pi / 2, 0),
		"Ship alongside"
	)
	-- yard stacks past the west bound: the near row is the port kit (stacks of two), further rows simple
	local yard = folder(secWorld, "Yard stacks")
	local rnd = Random.new(20261120)
	local colours = { "blue", "red", "green", "orange", "yellow", "white", "blue", "red", "grey" }
	for z = -82.5, 82.5, 33 do
		for tier = 0, 1 do
			if not (tier == 1 and rnd:NextNumber() < 0.25) then
				local m = kit(
					"Port",
					"ContainerGrey30",
					yard,
					CFrame.new(-75, tier * 10, z + rnd:NextNumber(-0.6, 0.6))
						* CFrame.Angles(
							0,
							math.pi / 2 + (if rnd:NextNumber() < 0.5 then math.pi else 0),
							0
						),
					"Yard stack"
				)
				paint(m, colours[rnd:NextInteger(1, #colours)])
			end
		end
	end
	-- far rows: ribbed boxes 10 x 10 x 30, stacked 1-3, in the yard colours (distant, so plain is fine)
	local farLooks = {}
	for _, n in { "blue", "red", "green", "orange", "yellow", "white", "grey" } do
		table.insert(
			farLooks,
			{ color = PAINT[n][1], mat = Enum.Material.Metal, variant = "Wharf_Ribbed" }
		)
	end
	for x = -100, -200, -22 do
		for z = -140, 140, 32 do
			local tiers = rnd:NextInteger(1, 3)
			for k = 0, tiers - 1 do
				local shrink = if k == 0 then 0 else 0.2 * k -- upper boxes sit on the lower ones, a touch smaller (no shared faces)
				local p = part(
					yard,
					"Far stack",
					Vector3.new(10 - shrink, 9.8, 30 - shrink),
					CFrame.new(x, k * 9.8 + 4.9, z),
					farLooks[rnd:NextInteger(1, #farLooks)]
				)
				p.CastShadow = k == tiers - 1
			end
		end
		task.wait()
	end
	-- mountains (two depth layers) and a ship on the horizon
	local hills = folder(secWorld, "Mountains")
	kit(
		"Wharf",
		"MountainA",
		hills,
		CFrame.new(-420, -7, -1250) * CFrame.Angles(0, 0.6, 0),
		"MountainA"
	)
	kit(
		"Wharf",
		"MountainB",
		hills,
		CFrame.new(380, -7, -1050) * CFrame.Angles(0, -0.3, 0),
		"MountainB"
	)
	kit(
		"Wharf",
		"MountainC",
		hills,
		CFrame.new(900, -7, -380) * CFrame.Angles(0, 1.1, 0),
		"MountainC"
	)
	kit(
		"Wharf",
		"MountainB",
		hills,
		CFrame.new(-1350, -7, 150) * CFrame.Angles(0, 1.5, 0),
		"MountainB far"
	)
	kit(
		"Wharf",
		"MountainA",
		hills,
		CFrame.new(300, -7, 1400) * CFrame.Angles(0, 2.2, 0),
		"MountainA north"
	)
	kit(
		"Wharf",
		"MountainC",
		hills,
		CFrame.new(-600, -7, 1000) * CFrame.Angles(0, -0.8, 0),
		"MountainC north"
	)
	kit(
		"Wharf",
		"MountainC",
		hills,
		CFrame.new(1250, -7, 700) * CFrame.Angles(0, 0.4, 0),
		"MountainC east"
	)
	kit(
		"Wharf",
		"Ship",
		secWorld,
		CFrame.new(1400, -6, 300) * CFrame.Angles(0, 0.35, 0),
		"Ship horizon"
	)
	for _, d in hills:GetDescendants() do
		if d:IsA("BasePart") then
			d.CastShadow = false
			if d.Name:match("_R_Grass$") then
				d.Color = Color3.fromHex("6FA352")
			elseif d.Name:match("_R_RockDark$") then
				d.Color = Color3.fromHex("7A7F7A")
			elseif d.Name:match("_R_Rock$") then
				d.Color = Color3.fromHex("9A9C94")
			end
		end
	end
	task.wait()

	--------------------------------------------------------------------------------- spawns, bounds, stage
	local SPAWNS = { { -2.5, 80 }, { 7.5, 80 }, { -2.5, 75 }, { 7.5, 75 } }
	for team, h in halves do
		local letter = if team == 1 then "A" else "B"
		for i, s in SPAWNS do
			local sp = Instance.new("SpawnLocation")
			sp.Name = "Spawn_" .. letter .. i
			sp.Size = Vector3.new(4, 0.2, 4)
			sp.CFrame = ORIGIN * h.T * CFrame.new(s[1], 0.1, s[2]) -- A faces -Z (toward B)
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
		local p = box(secBounds, "Bound", a, b, { color = C.deck }, true)
		p.Transparency = 1
		p.CanQuery = false
		p.CastShadow = false
	end
	bound(Vector3.new(64.4, -10, -94.5), Vector3.new(66.4, 60, 94.5)) -- east (the rail line)
	bound(Vector3.new(-67, -10, -94.5), Vector3.new(-65, 60, 94.5)) -- west (the yard)
	bound(Vector3.new(-67, -10, 92.1), Vector3.new(66.4, 60, 94.1)) -- north
	bound(Vector3.new(-67, -10, -94.1), Vector3.new(66.4, 60, -92.1)) -- south
	bound(Vector3.new(-67, 60, -94.5), Vector3.new(66.4, 62, 94.5)) -- ceiling
	-- west bound dressing: a run of concrete barrier blocks with a yellow-black band (the yard edge)
	local barrier = folder(secProps, "Yard barrier")
	for z = -90, 90, 4 do
		part(
			barrier,
			"Barrier block",
			Vector3.new(1.4, 2.2, 3.7),
			CFrame.new(-65.9, 1.1, z),
			L.concrete
		)
		wedge(
			barrier,
			"Barrier taper",
			Vector3.new(3.7, 0.5, 0.35),
			CFrame.new(-65.375, 2.45, z) * CFrame.Angles(0, -math.pi / 2, 0),
			L.concrete
		)
		part(
			barrier,
			"Barrier band",
			Vector3.new(0.08, 0.5, 3.7),
			CFrame.new(-65.16, 1.5, z),
			L.yellow
		)
	end
	for x = -63, -42, 4 do
		part(
			barrier,
			"Barrier block",
			Vector3.new(3.7, 2.2, 1.4),
			CFrame.new(x, 1.1, -92.9),
			L.concrete
		)
		wedge(
			barrier,
			"Barrier taper",
			Vector3.new(3.7, 0.5, 0.35),
			CFrame.new(x, 2.45, -92.375) * CFrame.Angles(0, math.pi, 0),
			L.concrete
		)
		part(
			barrier,
			"Barrier band",
			Vector3.new(3.7, 0.5, 0.08),
			CFrame.new(x, 1.5, -92.16),
			L.yellow
		)
	end
	-- floodlight masts outside the play box (the yard behind the barrier, the berth): tall silhouettes that
	-- frame the lanes. Plinth with a chamfered top, a square pole, a carved head frame, two lamp housings.
	local masts = folder(secWorld, "Masts")
	local function mast(x: number, z: number, yaw: number)
		local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
		part(
			masts,
			"Mast plinth",
			Vector3.new(2.4, 1.2, 2.4),
			cf * CFrame.new(0, 0.6, 0),
			L.concreteDark
		)
		part(
			masts,
			"Mast plinth step",
			Vector3.new(1.7, 0.4, 1.7),
			cf * CFrame.new(0, 1.4, 0),
			L.concreteDark
		) -- stepped top
		part(
			masts,
			"Mast pole",
			Vector3.new(0.9, 21, 0.9),
			cf * CFrame.new(0, 11.7, 0),
			{ color = C.steel }
		)
		part(
			masts,
			"Mast collar",
			Vector3.new(1.3, 0.6, 1.3),
			cf * CFrame.new(0, 1.85, 0),
			{ color = C.steel }
		)
		part(
			masts,
			"Mast head",
			Vector3.new(5.2, 0.6, 0.7),
			cf * CFrame.new(0, 22.4, 0),
			{ color = C.steel }
		)
		for _, hx in { -1.8, 1.8 } do
			part(
				masts,
				"Lamp",
				Vector3.new(1.5, 0.9, 1.1),
				cf * CFrame.new(hx, 21.75, 0.2) * CFrame.Angles(math.rad(-20), 0, 0),
				{ color = C.officeBase }
			)
			part(
				masts,
				"Lamp lens",
				Vector3.new(1.2, 0.2, 0.8),
				cf * CFrame.new(hx, 21.27, 0.35) * CFrame.Angles(math.rad(-20), 0, 0),
				{ color = C.lineWhite }
			)
		end
	end
	mast(-68, 30, math.pi / 2)
	mast(-68, -40, math.pi / 2)
	mast(77.8, 45, -math.pi / 2)
	mast(77.8, -55, -math.pi / 2)
	-- the winners' stage: on the quay by A's spawn, the crane behind them (they face west, the camera east)
	local stage = part(
		map,
		"WinnerStage",
		Vector3.new(4, 0.2, 4),
		CFrame.new(50, 0.1, 80) * CFrame.Angles(0, math.pi / 2, 0),
		{ color = C.deck }
	)
	stage.Transparency = 1
	stage.CastShadow = false
	CollectionService:AddTag(stage, "WinnerStage")

	------------------------------------------------------------------------------------------- lighting
	local light = Instance.new("Configuration")
	light.Name = "Lighting"
	CollectionService:AddTag(light, "GGAsset_MatchMaps_412")
	CollectionService:AddTag(light, "GauntletAuthoredData")
	light.Parent = map
	local fx = folder(map, "LightingFx")
	local atm = Instance.new("Atmosphere")
	atm.Density = 0.28
	atm.Offset = 0.12
	atm.Haze = 1.6
	atm.Glare = 0.15
	atm.Color = Color3.fromRGB(205, 216, 228)
	atm.Decay = Color3.fromRGB(150, 165, 190)
	atm.Parent = fx
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "Grade"
	cc.Contrast = 0.08
	cc.Saturation = 0.08
	cc.TintColor = Color3.fromRGB(255, 252, 246)
	cc.Parent = fx

	map.Parent = workspace
	return string.format("Wharf built: %d parts", count)
end
