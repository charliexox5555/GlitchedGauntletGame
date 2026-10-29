--!strict
-- Lobby greybox: the Market wing (west). A long winding passage cut into rock,
-- with clean shop pavilions set into its walls and featured podiums at the
-- bends, ending in the Battle Pass cavern. Run it as a bundle:
-- `python tools/studio/lobby/bundle.py Wing_Market`.
--
-- The path starts at the ring's west throat (x -72, heading west) and is a
-- chain of straights and bends (radius 36 on the centre line), about 220 studs
-- long. The shell is 44 wide between rock walls everywhere, so straights and
-- bends join cleanly; the irregular cave look comes from rock slabs, pillars
-- and ceiling drops placed inside it. Ceiling heights step between segments
-- and a rock bulkhead closes each step.

local W = 22 -- shell half width (inner wall face)
local T = 2 -- shell wall thickness
local PATH = 10 -- oak runner half width
local R = 36 -- bend radius on the centre line
local WALL_TOP = 34 -- path walls stand above every path roof

local WARM = Color3.fromRGB(255, 206, 140) -- warm neon accent (Market light)
local ROCK_DARK = Color3.fromRGB(72, 69, 65)
local ACCENTS = {
	Color3.fromRGB(214, 92, 60),
	Color3.fromRGB(78, 160, 150),
	Color3.fromRGB(226, 186, 92),
	Color3.fromRGB(196, 120, 170),
	Color3.fromRGB(120, 150, 210),
	Color3.fromRGB(200, 200, 205),
}

-- Fresh option tables: cylinder() writes its shape into the table it gets.
local function slate(): PartOpts
	return { material = Enum.Material.Slate }
end
local function wood(): PartOpts
	return { material = Enum.Material.Wood }
end
local function neon(): PartOpts
	return { material = Enum.Material.Neon, shadow = false }
end

local function dirOf(b: number): Vector3
	local x, z = polar(1, b)
	return Vector3.new(x, 0, z)
end

-- A frame on the floor at (x, z) heading along bearing b: -Z forward, +X right.
local function frameAt(x: number, z: number, b: number): CFrame
	local p = Vector3.new(x, 0, z)
	return CFrame.lookAt(p, p + dirOf(b))
end

-- Box in a frame: x lateral (right +), y height, s distance along the frame.
local function lbox(
	f: Instance,
	name: string,
	fr: CFrame,
	x0: number,
	x1: number,
	y0: number,
	y1: number,
	s0: number,
	s1: number,
	color: Color3,
	opts: PartOpts?
): Part
	local size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(s1 - s0))
	local cf = fr * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, -(s0 + s1) / 2)
	return make(f, name, size, cf, color, opts)
end

-- An angled rock slab standing on the floor at p, its long side along dir,
-- turned by yaw and leaning by lean (degrees).
local function slab(
	f: Instance,
	name: string,
	p: Vector3,
	dir: Vector3,
	len: number,
	thick: number,
	h: number,
	yaw: number,
	lean: number,
	color: Color3?
): Part
	local base = Vector3.new(p.X, h / 2 - 0.5, p.Z)
	local cf = CFrame.lookAt(base, base + dir) * CFrame.Angles(0, math.rad(yaw), math.rad(lean))
	return make(f, name, Vector3.new(thick, h + 1, len), cf, color or C.rock, slate())
end

-- A rock drop hanging from a roof at `roof`; its tip stays at y >= 16.5, well
-- above a jumping head (12.2).
local function drop(
	f: Instance,
	name: string,
	p: Vector3,
	roof: number,
	len: number,
	w: number,
	yaw: number
)
	local l = math.min(len, roof - 17)
	local cf = CFrame.new(p.X, roof + 0.5 - l / 2, p.Z)
		* CFrame.Angles(math.rad(6), math.rad(yaw), math.rad(-4))
	make(f, name, Vector3.new(w, l + 1, w * 0.8), cf, ROCK_DARK, slate())
end

-- A rock pillar from floor to roof: a main block and a shorter crossed block.
local function pillar(f: Instance, name: string, p: Vector3, roof: number, w: number, yaw: number)
	make(
		f,
		name .. "_A",
		Vector3.new(w, roof + 2, w * 0.8),
		CFrame.new(p.X, roof / 2, p.Z) * CFrame.Angles(0, math.rad(yaw), 0),
		C.rock,
		slate()
	)
	make(
		f,
		name .. "_B",
		Vector3.new(w * 0.7, roof * 0.6, w * 1.1),
		CFrame.new(p.X, roof * 0.3, p.Z) * CFrame.Angles(0, math.rad(yaw + 37), math.rad(4)),
		ROCK_DARK,
		slate()
	)
end

-- A shop pavilion set into the wall on one side (+1 right, -1 left) of a frame,
-- from s0 to s1, 10 deep from the wall face at `wall`. Concrete frame, oak slat
-- back, oak counter, one display stand and a charcoal header sign.
local function shop(
	f: Instance,
	name: string,
	fr: CFrame,
	side: number,
	s0: number,
	s1: number,
	wall: number,
	label: string,
	accent: Color3
)
	local front, back = side * (wall - 10), side * wall
	local sm = (s0 + s1) / 2
	lbox(f, name .. "_Plinth", fr, front, back, -0.2, 0.4, s0, s1, C.concrete)
	lbox(f, name .. "_FinA", fr, front, back, 0, 14, s0, s0 + 1, C.concrete)
	lbox(f, name .. "_FinB", fr, front, back, 0, 14, s1 - 1, s1, C.concrete)
	lbox(f, name .. "_Header", fr, front, front + side * 2, 11, 14, s0, s1, C.concrete)
	lbox(f, name .. "_Canopy", fr, front, back, 14, 14.6, s0, s1, C.concrete)
	lbox(f, name .. "_Slats", fr, back - side, back, 0.4, 14, s0 + 1, s1 - 1, C.oak, wood())
	lbox(
		f,
		name .. "_Counter",
		fr,
		front + side * 3,
		front + side * 5.5,
		0.4,
		3.6,
		s0 + 3,
		s1 - 3,
		C.oak,
		wood()
	)
	lbox(
		f,
		name .. "_Display",
		fr,
		back - side * 3.5,
		back - side * 1.5,
		0.4,
		6,
		sm - 1.5,
		sm + 1.5,
		accent
	)
	lbox(f, name .. "_Glow", fr, front, front + side * 0.3, 10.7, 11, s0 + 1, s1 - 1, WARM, neon())
	local pos = (fr * CFrame.new(front - side * 0.2, 12.5, -sm)).Position
	sign(
		f,
		name .. "_Sign",
		s1 - s0 - 3,
		2.8,
		pos,
		fr.RightVector * -side,
		{ { text = label, cap = 2.2 } }
	)
end

-- A featured display podium: neon ring, concrete base, glass case, item, cap,
-- and a small label on the wall behind it, all facing (cx, cz).
local function podium(
	f: Instance,
	name: string,
	px: number,
	pz: number,
	lx: number,
	lz: number,
	accent: Color3
)
	cylinder(f, name .. "_Ring", px, pz, 5, -0.2, 0.12, WARM, neon())
	cylinder(f, name .. "_Base", px, pz, 4.5, 0, 1.2, C.concrete)
	cylinder(f, name .. "_Case", px, pz, 3, 1.2, 7.2, C.glass, { transparency = 0.7 })
	box(
		f,
		name .. "_Item",
		px - 0.9,
		px + 0.9,
		2,
		5,
		pz - 0.9,
		pz + 0.9,
		accent,
		{ collide = false }
	)
	cylinder(f, name .. "_Cap", px, pz, 3.2, 7.2, 7.6, C.steel, { material = Enum.Material.Metal })
	local pos = Vector3.new(lx, 11.5, lz)
	local look = Vector3.new(px - lx, 0, pz - lz).Unit
	sign(f, name .. "_Label", 10, 2.4, pos, look, { { text = "FEATURED", cap = 1.5 } })
end

type Straight = { fr: CFrame, len: number, roof: number }
type Bend = { cx: number, cz: number, lo: number, hi: number, roof: number }
type Step = { len: number?, turn: number?, roof: number }

-- The path: straights (len) and bends (turn, + = right), with roof heights.
local PLAN: { Step } = {
	{ len = 40, roof = 24 }, -- S1 entry street: SKINS, WRAPS
	{ turn = -45, roof = 30 }, -- B1 (left)
	{ len = 30, roof = 22 }, -- S2: CHARMS, EMOTES
	{ turn = 90, roof = 32 }, -- B2 (right), the high point
	{ len = 30, roof = 24 }, -- S3: BUNDLES, CURRENCY
	{ turn = -45, roof = 28 }, -- B3 (left)
	{ len = 6, roof = 20 }, -- S4 low neck before the cavern
}

local function buildShell(f: Instance): ({ Straight }, { Bend })
	local straights: { Straight } = {}
	local bends: { Bend } = {}
	local x, z, b = -72, 0, 270
	local prevRoof: number? = nil
	for i, step in PLAN do
		local n = "Seg" .. i
		if prevRoof and prevRoof ~= step.roof then
			local lo, hi = math.min(prevRoof, step.roof), math.max(prevRoof, step.roof)
			lbox(
				f,
				n .. "_Bulkhead",
				frameAt(x, z, b),
				-W - T,
				W + T,
				lo,
				hi + 1,
				-1,
				1,
				C.rock,
				slate()
			)
		end
		prevRoof = step.roof
		local len, turn = step.len, step.turn
		if len then
			local fr = frameAt(x, z, b)
			lbox(f, n .. "_Floor", fr, -W - T, W + T, -2, 0, -1, len + 1, C.marketFloor)
			lbox(f, n .. "_Path", fr, -PATH, PATH, -0.2, 0.06, 0, len, C.oak, wood())
			lbox(f, n .. "_WallL", fr, -W - T, -W, 0, WALL_TOP, -1, len + 1, C.rock, slate())
			lbox(f, n .. "_WallR", fr, W, W + T, 0, WALL_TOP, -1, len + 1, C.rock, slate())
			lbox(
				f,
				n .. "_Roof",
				fr,
				-W - T,
				W + T,
				step.roof,
				step.roof + 1,
				-1,
				len + 1,
				C.rock,
				slate()
			)
			table.insert(straights, { fr = fr, len = len, roof = step.roof })
			local d = dirOf(b)
			x += d.X * len
			z += d.Z * len
		elseif turn then
			-- The centre sits on the inside of the turn; bearings below are seen
			-- from that centre.
			local sideB = if turn > 0 then b + 90 else b - 90
			local ox, oz = polar(R, sideB)
			local cx, cz = x + ox, z + oz
			local p0 = sideB + 180
			local p1 = p0 + turn
			local lo, hi = math.min(p0, p1), math.max(p0, p1)
			local rIn, rOut = R - W - T, R + W + T
			arc(f, n .. "_Floor", rIn, rOut, lo, hi, -2, 0, C.marketFloor, nil, nil, cx, cz)
			arc(f, n .. "_Path", R - PATH, R + PATH, lo, hi, -0.2, 0.06, C.oak, wood(), nil, cx, cz)
			arc(f, n .. "_WallIn", rIn, R - W, lo, hi, 0, WALL_TOP, C.rock, slate(), nil, cx, cz)
			arc(f, n .. "_WallOut", R + W, rOut, lo, hi, 0, WALL_TOP, C.rock, slate(), nil, cx, cz)
			arc(
				f,
				n .. "_Roof",
				rIn,
				rOut,
				lo,
				hi,
				step.roof,
				step.roof + 1,
				C.rock,
				slate(),
				nil,
				cx,
				cz
			)
			table.insert(bends, { cx = cx, cz = cz, lo = lo, hi = hi, roof = step.roof })
			local ex, ez = polar(R, p1)
			x, z = cx + ex, cz + ez
			b += turn
		end
	end
	return straights, bends
end

-- Rock slabs, drops and shops for each straight, in its own frame.
-- slabs: { side, s, len, yaw }; drops: { x, s, len }.
type Dressing = {
	shops: { { side: number, s0: number, s1: number, label: string } },
	slabs: { { number } },
	drops: { { number } },
}
local DRESS: { Dressing } = {
	{
		shops = {
			{ side = 1, s0 = 15, s1 = 31, label = "SKINS" },
			{ side = -1, s0 = 17, s1 = 33, label = "WRAPS" },
		},
		slabs = { { 1, 35.5, 6, 20 }, { -1, 37, 5, -25 }, { 1, 12.5, 4, 10 } },
		drops = { { -8, 22, 6 }, { 9, 35, 6 } },
	},
	{
		shops = {
			{ side = 1, s0 = 4, s1 = 20, label = "CHARMS" },
			{ side = -1, s0 = 10, s1 = 26, label = "EMOTES" },
		},
		slabs = { { -1, 5, 9, 15 }, { 1, 25, 9, -20 } },
		drops = { { 7, 8, 5 }, { -9, 22, 5 } },
	},
	{
		shops = {
			{ side = 1, s0 = 8, s1 = 24, label = "BUNDLES" },
			{ side = -1, s0 = 4, s1 = 20, label = "CURRENCY" },
		},
		slabs = { { 1, 3.5, 6, 25 }, { 1, 27, 6, -15 }, { -1, 25, 9, 20 } },
		drops = { { -6, 10, 6 }, { 10, 24, 6 } },
	},
	{
		shops = {},
		slabs = { { 1, 3, 5, 15 }, { -1, 3, 5, -15 } },
		drops = {},
	},
}

local function dressPath(f: Instance, straights: { Straight }, bends: { Bend })
	local accent = 0
	for i, st in straights do
		local d = DRESS[i]
		local fr = st.fr
		for _, sh in d.shops do
			accent = accent % #ACCENTS + 1
			shop(f, "Shop_" .. sh.label, fr, sh.side, sh.s0, sh.s1, W, sh.label, ACCENTS[accent])
		end
		for k, sl in d.slabs do
			local side, s, len, yaw = sl[1], sl[2], sl[3], sl[4]
			local p = (fr * CFrame.new(side * 18.5, 0, -s)).Position
			slab(f, "Rock" .. i .. "_" .. k, p, fr.LookVector, len, 4, st.roof, yaw, side * 5)
		end
		for k, dr in d.drops do
			local p = (fr * CFrame.new(dr[1], 0, -dr[2])).Position
			drop(f, "Drop" .. i .. "_" .. k, p, st.roof, dr[3], 4, 25 * k)
		end
	end

	-- The deep entry portal (compress, then release into the cave): jambs and
	-- head from x -70 to -82, continuing the ring's throat. Its first 2 studs
	-- are the wing's front wall.
	local s1 = straights[1]
	lbox(f, "PortalJambS", s1.fr, -W - T, -13.27, 0, s1.roof + 1, -2, 10, C.concrete)
	lbox(f, "PortalJambN", s1.fr, 13.27, W + T, 0, s1.roof + 1, -2, 10, C.concrete)
	lbox(f, "PortalHead", s1.fr, -13.27, 13.27, 16, s1.roof + 1, -2, 10, C.concrete)
	local hang = (s1.fr * CFrame.new(0, 19.5, -37)).Position
	sign(
		f,
		"Sign_Ahead",
		16,
		3.6,
		hang,
		-s1.fr.LookVector,
		-- Short, so a rock drop beside it never hides the end of the text.
		{ { text = "BATTLE PASS  >", cap = 2.0 } }
	)

	-- Bends: a featured podium in the outer bulge, rock pillars on the inside,
	-- and drops over the path.
	for i, bd in bends do
		local mid = (bd.lo + bd.hi) / 2
		local px, pz = polar(52, mid)
		local lx, lz = polar(57.6, mid)
		podium(
			f,
			"Podium" .. i,
			bd.cx + px,
			bd.cz + pz,
			bd.cx + lx,
			bd.cz + lz,
			ACCENTS[(i + 2) % #ACCENTS + 1]
		)
		local span = bd.hi - bd.lo
		local spots = if span > 60 then { -28, 0, 28 } else { -12, 12 }
		for k, o in spots do
			local x, z = polar(19.5, mid + o)
			pillar(
				f,
				"Pillar" .. i .. "_" .. k,
				Vector3.new(bd.cx + x, 0, bd.cz + z),
				bd.roof,
				5,
				30 * k + 10
			)
		end
		if span > 60 then
			-- The long bend also gets rock slabs on its outer wall.
			for k, o in { -30, 30 } do
				local x, z = polar(54.5, mid + o)
				local t = dirOf(mid + o + 90)
				slab(
					f,
					"BendRock" .. i .. "_" .. k,
					Vector3.new(bd.cx + x, 0, bd.cz + z),
					t,
					12,
					4,
					bd.roof,
					-15 * k,
					5
				)
			end
		end
		for k, o in { -span / 4, span / 4 } do
			local x, z = polar(R + (k == 1 and -6 or 7), mid + o)
			drop(
				f,
				"BendDrop" .. i .. "_" .. k,
				Vector3.new(bd.cx + x, 0, bd.cz + z),
				bd.roof,
				10,
				5,
				40 * k
			)
		end
	end
end

-- The Battle Pass cavern: x -262..-334, z -48..48, roof 40, entered from the
-- low neck through a rock lintel. The LED wall is on the west wall.
local function buildCavern(f: Instance)
	local x0, x1, zN, zS, roof = -334, -262, -48, 48, 40
	box(f, "Cav_Floor", x0, x1 + 1, -2, 0, zN, zS, C.marketFloor)
	box(f, "Cav_Path", -316, x1, -0.2, 0.06, -PATH, PATH, C.oak, wood())
	box(f, "Cav_Roof", x0, x1, roof, roof + 2, zN, zS, C.rock, slate())
	box(f, "Cav_WallW", x0, x0 + 2, 0, roof + 2, zN, zS, C.rock, slate())
	box(f, "Cav_WallN", x0, x1, 0, roof + 2, zN, zN + 2, C.rock, slate())
	box(f, "Cav_WallS", x0, x1, 0, roof + 2, zS - 2, zS, C.rock, slate())
	box(f, "Cav_WallE_N", x1 - 2, x1, 0, roof + 2, zN, -W, C.rock, slate())
	box(f, "Cav_WallE_S", x1 - 2, x1, 0, roof + 2, W, zS, C.rock, slate())
	box(f, "Cav_Lintel", x1 - 2, x1, 20, roof + 2, -W, W, C.rock, slate())
	sign(
		f,
		"Sign_Hub",
		16,
		4,
		Vector3.new(x1 - 2.3, 24, 0),
		WEST,
		{ { text = "TO HUB", cap = 2.4 } }
	)

	-- Chamfered corners, wall slabs and two big pillars break up the box.
	for _, c in { { -326, -40, 45 }, { -326, 40, -45 }, { -270, -40, -45 }, { -270, 40, 45 } } do
		slab(f, "Cav_Corner", Vector3.new(c[1], 0, c[2]), NORTH, 18, 5, roof, c[3], 0)
	end
	for _, c in { { -311, -43, 18 }, { -311, 43, -18 }, { -275, -43, -12 }, { -275, 43, 12 } } do
		slab(f, "Cav_WallRock", Vector3.new(c[1], 0, c[2]), WEST, 11, 4, roof - 6, c[3], 0)
	end
	pillar(f, "Cav_PillarN", Vector3.new(-306, 0, -29), roof, 6, 20)
	pillar(f, "Cav_PillarS", Vector3.new(-306, 0, 29), roof, 6, -25)
	for k, d in
		{ { -280, -15 }, { -290, 18 }, { -298, -26 }, { -304, 6 }, { -274, 26 }, { -318, -30 } }
	do
		drop(f, "Cav_Drop" .. k, Vector3.new(d[1], 0, d[2]), roof, 9 + (k % 3) * 2, 5, 33 * k)
	end

	-- Side kiosks along the north and south walls.
	local fr = frameAt(-262, 0, 270)
	shop(f, "Shop_CODES", fr, 1, 20, 36, -zN - 2, "CODES", ACCENTS[6])
	shop(f, "Shop_PREMIUM", fr, -1, 20, 36, zS - 2, "PREMIUM", ACCENTS[3])

	-- The destination: a two-step dais, three reward plinths and the LED wall.
	box(f, "Dais1", -331.5, -316, -0.2, 0.75, -24, 24, C.concrete)
	box(f, "Dais2", -331.5, -321, 0.75, 1.5, -20, 20, C.concrete)
	box(f, "DaisGlow", -316.3, -316, 0.15, 0.55, -24, 24, WARM, neon())
	for k, z in { -12, 0, 12 } do
		cylinder(f, "Reward" .. k, -326, z, 2.5, 1.5, 4, C.concrete)
		box(
			f,
			"RewardItem" .. k,
			-326.8,
			-325.2,
			4,
			6.4,
			z - 0.8,
			z + 0.8,
			ACCENTS[k + 2],
			{ collide = false }
		)
	end
	box(f, "LEDBezel", -332, -331.5, 4, 26, -21, 21, C.steel, { material = Enum.Material.Metal })
	sign(f, "LEDWall", 40, 20, Vector3.new(-331.3, 15, 0), EAST, {
		{ text = "BATTLE PASS", cap = 4.6 },
		{ text = "SEASON 1", cap = 2.2 },
		{ text = "TIER 0 / 50", cap = 1.6, color = Color3.fromRGB(200, 205, 212) },
	}, nil, C.screen)
end

local market = newSection("Wing_Market")
local straights, bends = buildShell(market)
dressPath(market, straights, bends)
buildCavern(market)
publish(market)
