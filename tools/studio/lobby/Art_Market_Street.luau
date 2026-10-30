--!strict
-- Lobby art: the Market street (phase 1 step 5). Dresses Greybox.Wing_Market from the portal to the
-- cavern neck with the "Market" kit group (tools/blender/build_lobby_kit_market.py): faceted rock on
-- every wall, ceiling and bulkhead, the rock slabs, pillars and drops, the six shop pavilions with
-- their display items and rock hoods, the three featured podiums, the deep portal, the runner edges,
-- the finished floors and the street's warm lights. The greybox stays the collision: parts the art
-- replaces are hidden, floors and signs get a finished look. Bundle with
-- `python tools/studio/lobby/bundle.py Art_Market_Street`; it rebuilds Art.Market_Street.
--
-- Fix pass (art review 2026-10-29): the runner is one kit floor (MarketRunner tiles on the straights,
-- MarketRunnerBend + MarketBendFloor sectors on the bends) instead of overlapping greybox chords; it is
-- darker oak with brass inlays. Dome pendants with warm pools hang along the street, each featured podium
-- has its own spot and shows a real game gun (the GunDisplay Trophy_* models), and the SKINS / WRAPS
-- vitrines show real guns too. It re-applies the ambience turntable tags on the podiums (AmbienceSetup
-- does the same), and caps the Market SurfaceGuis at 25 pixels per stud with sightline MaxDistance.

local CollectionService = game:GetService("CollectionService")

local MARKET = grey("Wing_Market")
assert(MARKET, "no Greybox.Wing_Market (run Wing_Market first)")

local W = 22 -- inner wall face (half width)
local R = 36 -- bend radius on the centre line
local PATH = 10 -- oak runner half width
local rng = Random.new(5150)

local WARM = Color3.fromHex("FFD9A8") -- L_MARKET

-- Clones a kit piece scaled along its own axes (x depth/front, y up, z width) and puts its origin at cf.
local function scaled(parent: Instance, piece: string, cf: CFrame, s: Vector3, name: string?): Model
	local m = kit(piece):Clone()
	m.Name = name or piece
	if s ~= Vector3.one then
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				local rel = d.CFrame
				d.Size = Vector3.new(d.Size.X * s.X, d.Size.Y * s.Y, d.Size.Z * s.Z)
				d.CFrame = CFrame.new(rel.Position * s) * rel.Rotation
			end
		end
	end
	m:PivotTo(cf)
	m.Parent = parent
	return m
end

local lastPick: { [string]: string } = {}
local function pick(kind: string, list: { string }): string
	local p = list[rng:NextInteger(1, #list)]
	if p == lastPick[kind] then
		p = list[(table.find(list, p) :: number) % #list + 1]
	end
	lastPick[kind] = p
	return p
end

local WALLS = {
	"MarketRockWall_A",
	"MarketRockWall_B",
	"MarketRockWall_C",
	"MarketRockWall_D",
	"MarketRockWall_E",
}
local CEILS = { "MarketRockCeiling_A", "MarketRockCeiling_B" }
local SLABS = { "MarketRockSlab_A", "MarketRockSlab_B", "MarketRockSlab_C" }
local PILLARS = { "MarketRockPillar_A", "MarketRockPillar_B" }
local DROPS = { "MarketRockDrop_A", "MarketRockDrop_B" }
local CORES = { "MarketRockCore_A", "MarketRockCore_B" }

local function dirOf(b: number): Vector3
	local x, z = polar(1, b)
	return Vector3.new(x, 0, z)
end

local function frameAt(x: number, z: number, b: number): CFrame
	local p = Vector3.new(x, 0, z)
	return CFrame.lookAt(p, p + dirOf(b))
end

local function gpart(name: string): BasePart?
	local p = MARKET:FindFirstChild(name)
	if p and p:IsA("BasePart") then
		return p
	end
	return nil
end

-- A rock wall run along a frame's side (+1 right, -1 left) from s0 to s1.
local function wallRun(f: Instance, fr: CFrame, side: number, s0: number, s1: number)
	local L = s1 - s0
	local n = math.max(1, math.ceil(L / 12.5 - 1e-6))
	local w = L / n
	for i = 1, n do
		local s = s0 + (i - 0.5) * w
		local pos = (fr * CFrame.new(side * W, 0, -s)).Position
		scaled(
			f,
			pick("wall", WALLS),
			faceCF(pos, -side * fr.RightVector),
			Vector3.new(1, 1, w / 12)
		)
	end
end

-- A rock ceiling panel facing down, its mid plane at pos, squared to `along` (a horizontal axis)
-- and turned by a random quarter turn, so neighbours always overlap (no gaps to the void).
local function ceil(f: Instance, pos: Vector3, along: Vector3)
	local q = rng:NextInteger(0, 3) * math.pi / 2
	local a = CFrame.fromAxisAngle(Vector3.yAxis, q):VectorToWorldSpace(along.Unit)
	local cf = CFrame.fromMatrix(pos, Vector3.new(0, -1, 0), a)
	local sc = rng:NextNumber(1.0, 1.12)
	scaled(f, pick("ceil", CEILS), cf, Vector3.new(1, sc, sc))
end

-- A vertical rock band (a ceiling panel stood up) centred at pos, facing `front`.
local function band(f: Instance, pos: Vector3, front: Vector3, w: number, h: number, depth: number?)
	scaled(f, pick("ceil", CEILS), faceCF(pos, front), Vector3.new(depth or 0.7, h / 24, w / 24))
end

-- Dresses a greybox slab box with 1..n kit slabs along its length.
local function slabOver(f: Instance, p: BasePart)
	local sz = p.Size
	local n = math.max(1, math.ceil(sz.Z / 10 - 1e-6))
	local len = sz.Z / n
	for i = 1, n do
		local zoff = -sz.Z / 2 + (i - 0.5) * len
		local flip = if rng:NextNumber() < 0.5
			then CFrame.Angles(0, math.pi, 0)
			else CFrame.identity
		local cf = p.CFrame * CFrame.new(0, -sz.Y / 2, zoff) * flip
		scaled(f, pick("slab", SLABS), cf, Vector3.new(sz.X / 4, sz.Y / 32, len / 8))
	end
	hide(p)
end

local function pillarOver(f: Instance, a: BasePart, b: BasePart?)
	local roof = a.Size.Y - 2
	local w = a.Size.X
	local cf = CFrame.new(a.Position.X, 0, a.Position.Z) * a.CFrame.Rotation
	scaled(f, pick("pillar", PILLARS), cf, Vector3.new(w / 5, roof / 30, w / 5))
	hide(a)
	if b then
		hide(b)
	end
end

local function dropOver(f: Instance, p: BasePart)
	local sz = p.Size
	local cf = p.CFrame * CFrame.new(0, sz.Y / 2, 0)
	scaled(f, pick("drop", DROPS), cf, Vector3.new(sz.X / 5, sz.Y / 12, sz.Z / 4))
	hide(p)
end

-- Runner floors never cast shadows (they sit 0.06 above the floor).
local function flat(m: Model): Model
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CastShadow = false
		end
	end
	return m
end

-- Runner tiles along a straight from s0 to s1 (each tile 10 long, stretched to fit), the oak's grain and the
-- brass inlays running with the path. Its top is the greybox path top (0.06).
local function runnerStraight(f: Instance, fr: CFrame, s0: number, s1: number)
	local L = s1 - s0
	local n = math.max(1, math.ceil(L / 10 - 1e-6))
	local w = L / n
	for k = 0, n - 1 do
		local pos = (fr * CFrame.new(0, 0, -(s0 + k * w))).Position
		flat(scaled(f, "MarketRunner", faceCF(pos, fr.LookVector), Vector3.new(w / 10, 1, 1)))
	end
end

-- Real game guns (ServerStorage.LobbyKit Trophy_*, KitGroup GunDisplay): scaled to `length`, the lowest
-- point resting at `base`, the muzzle along `muzzle`.
local function showGun(
	parent: Instance,
	gun: string,
	base: Vector3,
	muzzle: Vector3,
	length: number,
	name: string,
	tint: Color3?
): Model?
	if not hasKit(gun) then
		table.insert(REPORT, "MISSING gun " .. gun)
		return nil
	end
	local m = kit(gun):Clone()
	local L = m:GetAttribute("Length")
	local low = m:GetAttribute("Low")
	local k = if typeof(L) == "number" and L > 0 then length / L else 1
	m:ScaleTo(k)
	local drop = if typeof(low) == "number" then math.abs(low) * k else 0.5
	local up = Vector3.yAxis
	local mz = Vector3.new(muzzle.X, 0, muzzle.Z).Unit
	m:PivotTo(CFrame.fromMatrix(base + Vector3.new(0, drop, 0), mz:Cross(up), up))
	m.Name = name
	if tint then
		for _, d in m:GetDescendants() do
			if d:IsA("SurfaceAppearance") then
				(d :: any).Color = tint
			end
		end
	end
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m.Parent = parent
	return m
end

-- Ambience turntable (art-source/lobby/scripts/AmbienceSetup.luau sets the same on its runs).
local function spinTag(inst: Instance, center: Vector3, period: number, phase: number)
	CollectionService:AddTag(inst, "Lobby_Turntable")
	inst:SetAttribute("SpinCenter", center)
	inst:SetAttribute("SpinPeriod", period)
	inst:SetAttribute("SpinPhase", phase)
	if inst:IsA("Model") then
		inst.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end
end

-- A small invisible anchor carrying one dynamic light.
local function lightAt(f: Instance, name: string, pos: Vector3, light: Light)
	local a = make(f, name, Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos), LOOK.SteelBlack.color, {
		collide = false,
		shadow = false,
		transparency = 1,
	})
	light.Parent = a
	return a
end

local function pointLight(range: number, brightness: number): PointLight
	local l = Instance.new("PointLight")
	l.Color = WARM
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	return l
end

-- Display item for a shop or a podium, placed with its origin at cf.
local function showItem(f: Instance, kind: string, cf: CFrame, scale: number, skin: Color3?)
	local piece = ({
		rifle = "MarketShowRifle",
		crate = "MarketShowCrate",
		coins = "MarketShowCoins",
		charm = "MarketShowCharm",
		figure = "MarketShowFigure",
	})[kind]
	local m = scaled(f, piece, cf, Vector3.one * scale, "Show_" .. kind)
	if skin then
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and string.sub(d.Name, -5) == "_Skin" then
				d.Color = skin
			end
		end
	end
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	return m
end

local SHOP_PARTS =
	{ "Canopy", "FinA", "FinB", "Header", "Plinth", "Slats", "Counter", "Display", "Glow" }
local SHOP_ITEMS: { [string]: { any } } = {
	SKINS = { "gun", "Trophy_Vandal" },
	WRAPS = { "gun", "Trophy_Bulldog" },
	CHARMS = { "charm", 0.85 },
	EMOTES = { "figure", 0.9 },
	BUNDLES = { "crate", 1.15 },
	CURRENCY = { "coins", 1.0 },
}

local function shopAt(
	f: Instance,
	label: string,
	fr: CFrame,
	side: number,
	s0: number,
	s1: number,
	roof: number
)
	local sm = (s0 + s1) / 2
	local pos = (fr * CFrame.new(side * W, 0, -sm)).Position
	local cf = faceCF(pos, -side * fr.RightVector)
	local shop = put(f, "ShopPavilion", cf, "Shop_" .. label)
	local it = SHOP_ITEMS[label]
	if it and it[1] == "gun" then
		-- Across the vitrine (2.9 wide inside), seen side-on from the street.
		local base = (cf * CFrame.new(2.5, 3.62, 0)).Position
		showGun(shop, it[2], base, cf.LookVector, 2.75, "Show_gun")
	elseif it then
		showItem(
			shop,
			it[1],
			cf * CFrame.new(2.5, 3.6, 0) * CFrame.Angles(0, math.rad(-20), 0),
			it[2],
			it[3]
		)
	end
	scaled(
		f,
		"MarketRockHood",
		cf * CFrame.new(0, 14.6, 0),
		Vector3.new(1, (roof - 14.6) / 12, 1),
		"Hood_" .. label
	)
	for _, suffix in SHOP_PARTS do
		local p = gpart("Shop_" .. label .. "_" .. suffix)
		if p then
			hide(p)
		end
	end
	local sg = gpart("Shop_" .. label .. "_Sign")
	if sg then
		finish(sg, "Sign")
	end
end

-- Frames a greybox sign (w x h panel) with the kit bezel; keeps the sign and its SurfaceGui.
local function frameSign(f: Instance, sg: BasePart)
	finish(sg, "Sign")
	local cf = faceCF(sg.Position, sg.CFrame.LookVector)
	scaled(
		f,
		"MarketSignFrame",
		cf,
		Vector3.new(1, sg.Size.Y / 2.4, sg.Size.X / 10),
		sg.Name .. "_Frame"
	)
end

-- ---------------------------------------------------------------- the path (same plan as Wing_Market)

type Step = { len: number?, turn: number?, roof: number }
type Straight = { fr: CFrame, len: number, roof: number }
type Bend = { cx: number, cz: number, lo: number, hi: number, roof: number, n: number }
type Bulk = { fr: CFrame, lo: number, hi: number, forward: boolean }

local PLAN: { Step } = {
	{ len = 40, roof = 24 },
	{ turn = -45, roof = 30 },
	{ len = 30, roof = 22 },
	{ turn = 90, roof = 32 },
	{ len = 30, roof = 24 },
	{ turn = -45, roof = 28 },
	{ len = 6, roof = 20 },
}

local straights: { Straight } = {}
local bends: { Bend } = {}
local bulks: { Bulk } = {}
do
	local x, z, b = -72, 0, 270
	local prev: number? = nil
	local bn = 0
	for _, step in PLAN do
		local fr = frameAt(x, z, b)
		if prev and prev ~= step.roof then
			table.insert(bulks, {
				fr = fr,
				lo = math.min(prev, step.roof),
				hi = math.max(prev, step.roof),
				forward = step.roof > prev,
			})
		end
		prev = step.roof
		local len, turn = step.len, step.turn
		if len then
			table.insert(straights, { fr = fr, len = len, roof = step.roof })
			local d = dirOf(b)
			x += d.X * len
			z += d.Z * len
		elseif turn then
			bn += 1
			local sideB = if turn > 0 then b + 90 else b - 90
			local ox, oz = polar(R, sideB)
			local cx, cz = x + ox, z + oz
			local p0 = sideB + 180
			local p1 = p0 + turn
			table.insert(bends, {
				cx = cx,
				cz = cz,
				lo = math.min(p0, p1),
				hi = math.max(p0, p1),
				roof = step.roof,
				n = bn,
			})
			local ex, ez = polar(R, p1)
			x, z = cx + ex, cz + ez
			b += turn
		end
	end
end

-- Shops on the straights (Wing_Market DRESS).
local SHOPS = {
	{ 1, 1, 15, 31, "SKINS" },
	{ 1, -1, 17, 33, "WRAPS" },
	{ 2, 1, 4, 20, "CHARMS" },
	{ 2, -1, 10, 26, "EMOTES" },
	{ 3, 1, 8, 24, "BUNDLES" },
	{ 3, -1, 4, 20, "CURRENCY" },
}

-- ---------------------------------------------------------------- build

local street = artSection("Market_Street")
local rock = Instance.new("Folder")
rock.Name = "Rock"
rock.Parent = street
local built = Instance.new("Folder")
built.Name = "Built"
built.Parent = street

-- Portal: the deep concrete frame from x -70 to -82.
do
	put(built, "MarketPortal", faceCF(Vector3.new(-70, 0, 0), WEST), "Portal")
	for _, n in { "PortalJambN", "PortalJambS", "PortalHead" } do
		local p = gpart(n)
		if p then
			hide(p)
		end
	end
end

-- Straights: walls, ceilings, floors, runner edges.
for i, st in straights do
	local fr = st.fr
	local s0 = if i == 1 then 10 else 0
	local s1 = st.len
	if i == #straights then
		s1 = st.len + 2.6 -- the neck rock wraps 0.8 past the cavern's east wall face (x -264)
	end
	wallRun(rock, fr, 1, s0, s1)
	wallRun(rock, fr, -1, s0, s1)
	local L = s1 - s0
	local n = math.max(1, math.ceil(L / 20 - 1e-6))
	for k = 1, n do
		local s = s0 + (k - 0.5) * L / n
		for _, lat in { -11.5, 11.5 } do
			local pos = (fr * CFrame.new(lat, st.roof - 0.4, -s)).Position
			if i == #straights then
				-- The short neck: one panel cut to the neck's length, so no rock reaches into the
				-- cavern in front of the TO HUB sign.
				local cf = CFrame.fromMatrix(pos, Vector3.new(0, -1, 0), fr.LookVector)
				scaled(rock, pick("ceil", CEILS), cf, Vector3.new(1, (L + 1) / 24, 1))
			else
				ceil(rock, pos, fr.LookVector)
			end
		end
	end
	local seg = "Seg" .. (2 * i - 1)
	for _, n2 in { "_WallL", "_WallR", "_Roof" } do
		local p = gpart(seg .. n2)
		if p then
			hide(p)
		end
	end
	local floor = gpart(seg .. "_Floor")
	if floor then
		finish(floor, "Terrazzo")
	end
	local path = gpart(seg .. "_Path")
	if path then
		hide(path)
		runnerStraight(built, fr, 0, st.len)
	end
end

-- Bends: outer chord walls (a feature panel pair behind each podium), inner rock cores, ceilings.
for _, bd in bends do
	local span = bd.hi - bd.lo
	local pieces = math.floor(span / SEG + 0.5)
	local mid = (bd.lo + bd.hi) / 2
	for k = 0, pieces - 1 do
		local b0 = bd.lo + k * SEG
		local bm = b0 + SEG / 2
		local half = math.rad(SEG / 2)
		local face = 58 * math.cos(half)
		local chord = 2 * 58 * math.sin(half)
		local x, z = polar(face, bm)
		local pos = Vector3.new(bd.cx + x, 0, bd.cz + z)
		local front = Vector3.new(-x, 0, -z)
		local feature = math.abs(bm - mid) < SEG
		local piece = if feature then "MarketRockWall_Feature" else pick("wall", WALLS)
		-- Feature panels run 4% past each end, under the rock beside them (no see-through sliver).
		local wide = if feature then chord * 1.08 else chord
		scaled(rock, piece, faceCF(pos, front), Vector3.new(1, 1, wide / 12))
	end
	local cores = math.floor(span / 22.5 + 0.5)
	for k = 0, cores - 1 do
		scaled(rock, pick("core", CORES), segCF(bd.lo + k * 22.5, 0, bd.cx, bd.cz), Vector3.one)
	end
	for _, row in { { 24, 36 }, { 47, 60 } } do
		local r, edge = row[1], row[2]
		local n = math.max(2, math.ceil(math.rad(span) * edge / 19))
		for k = 1, n do
			local bb = bd.lo + (k - 0.5) * span / n
			local x, z = polar(r, bb)
			ceil(rock, Vector3.new(bd.cx + x, bd.roof - 0.4, bd.cz + z), Vector3.new(x, 0, z))
		end
	end
	local seg = "Seg" .. (2 * bd.n)
	for _, d in MARKET:GetChildren() do
		if d:IsA("BasePart") and string.sub(d.Name, 1, #seg + 1) == seg .. "_" then
			local rest = string.sub(d.Name, #seg + 2)
			if
				string.find(rest, "^Wall")
				or string.find(rest, "^Roof")
				or string.find(rest, "^Floor")
				or string.find(rest, "^Path")
			then
				hide(d)
			end
		end
	end
	-- The floor: 45 degree terrazzo and runner sectors (one mesh each, no overlapping chords).
	for k = 0, math.floor(span / 45 + 0.5) - 1 do
		local cf = segCF(bd.lo + k * 45, 0, bd.cx, bd.cz)
		flat(put(built, "MarketRunnerBend", cf, "RunnerBend" .. bd.n))
		flat(put(built, "MarketBendFloor", cf, "BendFloor" .. bd.n))
	end
end

-- Bulkheads: a rock band on the face you can see (the high side).
for i, bk in bulks do
	local h = bk.hi - bk.lo + 1.6
	local s = if bk.forward then 1.0 else -1.0
	local front = if bk.forward then bk.fr.LookVector else -bk.fr.LookVector
	for _, lat in { -11.5, 11.5 } do
		local pos = (bk.fr * CFrame.new(lat, (bk.lo + bk.hi) / 2 + 0.2, -s)).Position
		band(rock, pos, front, 24, h, 0.7)
	end
	local p = gpart("Seg" .. (i + 1) .. "_Bulkhead")
	if p then
		hide(p)
	end
end

-- Slabs, pillars and drops.
for _, d in MARKET:GetChildren() do
	if d:IsA("BasePart") then
		local n = d.Name
		if string.find(n, "^Rock%d") or string.find(n, "^BendRock") then
			slabOver(rock, d)
		elseif string.find(n, "^Pillar%d+_%d+_A$") then
			pillarOver(rock, d, gpart(string.sub(n, 1, -2) .. "B"))
		elseif string.find(n, "^Drop%d") or string.find(n, "^BendDrop") then
			dropOver(rock, d)
		end
	end
end

-- Shops: pavilion, display item, rock hood above.
for _, sh in SHOPS do
	local st = straights[sh[1]]
	shopAt(built, sh[5], st.fr, sh[2], sh[3], sh[4], st.roof)
end

-- Featured podiums at the bends, with a slowly-not-turning hero item each (turning is phase 2).
for i = 1, 3 do
	local base = gpart("Podium" .. i .. "_Base")
	if base then
		local pos = Vector3.new(base.Position.X, 0, base.Position.Z)
		local m = put(
			built,
			"FeaturedPodium",
			CFrame.new(pos) * CFrame.Angles(0, math.rad(30 * i), 0),
			"Podium" .. i
		)
		local gun = ({ "Trophy_Vandal", "Trophy_Outlaw", "Trophy_Ares" })[i]
		-- Side-on to the street at rest (the ambience turntable spins it in game).
		local bd = bends[i]
		local toward = (Vector3.new(bd.cx, 0, bd.cz) - pos).Unit
		showGun(m, gun, pos + Vector3.new(0, 3.14, 0), toward:Cross(Vector3.yAxis), 5.3, "Show_gun")
		for _, d in m:GetChildren() do
			if
				d.Name == "FeaturedPodium_Turntable"
				or d.Name == "FeaturedPodium_Cradle"
				or string.find(d.Name, "^Show_")
			then
				spinTag(d, pos, 24, i * 8)
			end
		end
		for _, sfx in { "_Ring", "_Base", "_Case", "_Cap", "_Item" } do
			local p = gpart("Podium" .. i .. sfx)
			if p then
				hide(p)
			end
		end
	end
	local label = gpart("Podium" .. i .. "_Label")
	if label then
		frameSign(built, label)
	end
end

-- The hanging BATTLE PASS sign: frame and two steel hangers to the roof.
do
	local sg = gpart("Sign_Ahead")
	if sg then
		frameSign(built, sg)
		local roof = straights[1].roof
		for _, dx in { -6, 6 } do
			local top = sg.CFrame * CFrame.new(dx, sg.Size.Y / 2 + 0.6, 0)
			local h = roof - top.Position.Y + 0.6
			local p = make(
				built,
				"Hanger",
				Vector3.new(0.18, h, 0.18),
				CFrame.new(top.Position + Vector3.new(0, h / 2, 0)),
				LOOK.SteelBlack.color,
				{ material = Enum.Material.Metal, collide = false, shadow = false }
			)
			finish(p, "SteelBlack")
		end
	end
end

-- Warm light pooling from each facing pair of shops.
for i, s in { 24, 15, 14 } do
	local st = straights[i]
	lightAt(built, "ShopLight" .. i, (st.fr * CFrame.new(0, 11, -s)).Position, pointLight(28, 3))
end

-- Each featured podium: a narrow warm spot from the rock above, a hot pool on the case and the floor ring.
for i = 1, 3 do
	local base = gpart("Podium" .. i .. "_Base")
	local bd = bends[i]
	if base and bd then
		local p = Vector3.new(base.Position.X, 0, base.Position.Z)
		local toward = (Vector3.new(bd.cx, 0, bd.cz) - p).Unit
		local from = p + toward * 7 + Vector3.new(0, math.min(bd.roof - 6, 17), 0)
		local a = make(
			built,
			"PodiumSpot" .. i,
			Vector3.new(0.2, 0.2, 0.2),
			CFrame.lookAt(from, p + Vector3.new(0, 2.5, 0)),
			LOOK.SteelBlack.color,
			{ collide = false, shadow = false, transparency = 1 }
		)
		local l = Instance.new("SpotLight")
		l.Face = Enum.NormalId.Front
		l.Color = WARM
		l.Angle = 50
		l.Range = 26
		l.Brightness = 3.2
		l.Shadows = false
		l.Parent = a
	end
end

-- Pendants: black steel domes on rods to the rock, a warm pool every ~22 studs of the street centre line
-- (between and beyond the shop-pair lights). Each is { kind, index, s or bearing fraction, light, lateral }.
-- On the first straight they hang off-axis so no rod crosses the hanging BATTLE PASS sign seen from the hub.
local PENDANTS: { { any } } = {
	{ "s", 1, 10, true, 9.5 },
	{ "s", 1, 36, false, -9.5 },
	{ "b", 1, 0.5, true },
	{ "s", 2, 4, false },
	{ "s", 2, 26, true },
	{ "b", 2, 0.25, true },
	{ "b", 2, 0.75, true },
	{ "s", 3, 4, false },
	{ "s", 3, 26, true },
	{ "b", 3, 0.5, true },
}
local PENDANT_Y = 13
local pendants = Instance.new("Folder")
pendants.Name = "Pendants"
pendants.Parent = built
for k, pd in PENDANTS do
	local pos: Vector3, roof: number
	if pd[1] == "s" then
		local st = straights[pd[2] :: number]
		pos = (st.fr * CFrame.new((pd[5] or 0) :: number, 0, -(pd[3] :: number))).Position
		roof = st.roof
	else
		local bd = bends[pd[2] :: number]
		local x, z = polar(R, bd.lo + (bd.hi - bd.lo) * (pd[3] :: number))
		pos = Vector3.new(bd.cx + x, 0, bd.cz + z)
		roof = bd.roof
	end
	local m = put(pendants, "MarketPendant", CFrame.new(pos.X, PENDANT_Y, pos.Z), "Pendant" .. k)
	local rod = m:FindFirstChild("MarketPendant_Rod")
	if rod and rod:IsA("BasePart") then
		local y0 = PENDANT_Y + 1.75
		local h = roof - 0.2 - y0
		rod.Size = Vector3.new(rod.Size.X, h, rod.Size.Z)
		rod.CFrame = CFrame.new(pos.X, y0 + h / 2, pos.Z) * rod.CFrame.Rotation
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CastShadow = false
		end
	end
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	if pd[4] then
		lightAt(
			pendants,
			"PendantLight" .. k,
			Vector3.new(pos.X, PENDANT_Y - 0.4, pos.Z),
			pointLight(20, 1.1)
		)
	end
end

-- The cavern mouth (Seg6 / Seg7) around the TO HUB sign.
lightAt(built, "MouthLight", Vector3.new(-252, 14, 4), pointLight(22, 1.2))

-- SurfaceGuis in the wing: 25 pixels per stud at most, drawn only within their sightline.
for _, d in MARKET:GetDescendants() do
	if d:IsA("SurfaceGui") then
		if d.SizingMode == Enum.SurfaceGuiSizingMode.PixelsPerStud and d.PixelsPerStud > 25 then
			d.PixelsPerStud = 25
		end
		local host = d.Parent
		local name = if host then host.Name else ""
		d.MaxDistance = if string.find(name, "TitleBand")
			then 250
			elseif string.find(name, "Podium") then 80
			else 120
	end
end

-- Shadow lid: the greybox roofs are hidden (fully transparent parts neither cast shadows nor block
-- sky light), so an opaque slab above every roof keeps the noon sun and the sky out of the cave.
-- It sits above the walls (34) and every street roof (<= 33), out of reach and out of sight; it is 8
-- thick and snapped to the 4-stud lighting voxels so low graphics levels see it as solid too.
do
	local lid = make(
		built,
		"ShadowLid",
		Vector3.new(196, 8, 104),
		CFrame.new(-170, 40, 20),
		LOOK.ConcreteDark.color,
		{ collide = false }
	)
	finish(lid, "ConcreteDark")
end

-- Every rock piece gets a slightly different shade, so repeats never read as copies.
for _, m in rock:GetChildren() do
	local k = rng:NextNumber(0.86, 1.08)
	local warm = rng:NextNumber(-0.02, 0.02)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and string.sub(d.Name, -5) == "_Rock" then
			local c = d.Color
			d.Color = Color3.new(
				math.clamp(c.R * k * (1 + warm), 0, 1),
				math.clamp(c.G * k, 0, 1),
				math.clamp(c.B * k * (1 - warm), 0, 1)
			)
		end
	end
end

publishArt(street)
