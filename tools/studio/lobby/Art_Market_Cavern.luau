--!strict
-- Lobby art: the Battle Pass cavern at the end of the Market (phase 1 step 5). Rock walls, upper
-- bands and ceiling, the corner and wall slabs, the two big pillars and the drops, the BattlePassWall
-- (LED bezel, dais, reward plinths and rewards), the CODES and PREMIUM kiosks, the TO HUB lintel and
-- the cavern's three dynamic lights (the LED wall key light casts the wing's only shadows). Bundle
-- with `python tools/studio/lobby/bundle.py Art_Market_Cavern`; it rebuilds Art.Market_Cavern.
--
-- Fix pass (art review 2026-10-29): the LED wall shows season key art (warm gold-to-orange gradient,
-- title, TIER 0 / 50 progress bar, a row of reward tier tiles) and washes the dais in warm light; the
-- runner is the MarketRunner kit floor with two warm downlight pools to the dais; the centre reward is a
-- real game gun; the TO HUB frame gets a warm under-glow.

local MARKET = grey("Wing_Market")
assert(MARKET, "no Greybox.Wing_Market (run Wing_Market first)")

local rng = Random.new(9277)
local WARM = Color3.fromHex("FFD9A8") -- L_MARKET
local X0, X1, ZN, ZS, ROOF = -332, -264, -46, 46, 40 -- inner faces of the cavern walls

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

local function gpart(name: string): BasePart?
	local p = MARKET:FindFirstChild(name)
	if p and p:IsA("BasePart") then
		return p
	end
	return nil
end

-- A straight wall run from a to b (points on the wall face), its rock facing `front`.
local function wallLine(f: Instance, a: Vector3, b: Vector3, front: Vector3)
	local L = (b - a).Magnitude
	local n = math.max(1, math.ceil(L / 12.5 - 1e-6))
	local w = L / n
	for i = 1, n do
		local pos = a:Lerp(b, (i - 0.5) / n)
		scaled(f, pick("wall", WALLS), faceCF(pos, front), Vector3.new(1, 1, w / 12))
	end
end

local function band(f: Instance, pos: Vector3, front: Vector3, w: number, h: number, depth: number?)
	scaled(f, pick("ceil", CEILS), faceCF(pos, front), Vector3.new(depth or 0.7, h / 24, w / 24))
end

-- An upper rock band along a wall from a to b (at the wall face), centred at height y.
local function bandLine(
	f: Instance,
	a: Vector3,
	b: Vector3,
	front: Vector3,
	y: number,
	h: number,
	inset: number
)
	local L = (b - a).Magnitude
	local n = math.max(1, math.ceil(L / 22 - 1e-6))
	local w = L / n
	for i = 1, n do
		local pos = a:Lerp(b, (i - 0.5) / n) + front * inset + Vector3.new(0, y, 0)
		band(f, pos, front, w + 1.5, h, 0.8)
	end
end

local function ceil(f: Instance, pos: Vector3)
	local q = rng:NextInteger(0, 3) * math.pi / 2
	local cf =
		CFrame.fromMatrix(pos, Vector3.new(0, -1, 0), Vector3.new(math.cos(q), 0, math.sin(q)))
	local sc = rng:NextNumber(1.0, 1.12)
	scaled(f, pick("ceil", CEILS), cf, Vector3.new(1, sc, sc))
end

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

local function make1(f: Instance, name: string, size: Vector3, cf: CFrame): Part
	return make(
		f,
		name,
		size,
		cf,
		LOOK.SteelBlack.color,
		{ collide = false, shadow = false, transparency = 1 }
	)
end

local function showItem(f: Instance, piece: string, cf: CFrame, scale: number, skin: Color3?): Model
	local m = scaled(f, piece, cf, Vector3.one * scale)
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

-- ---------------------------------------------------------------- LED wall content
-- Season key art for the 40 x 20 LED wall (phase 2 fills in the live tier and rewards): a warm gold to
-- orange gradient with light streaks, the BATTLE PASS title, a TIER 0 / 50 progress bar and a row of ten
-- reward tier tiles. It replaces the greybox's three text lines on the same part and face, so the ambience
-- shimmer (tag Lobby_LedScreen on LEDWall) still runs over it.

local function uiFrame(
	parent: Instance,
	name: string,
	pos: UDim2,
	size: UDim2,
	color: Color3,
	alpha: number
): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Position = pos
	f.Size = size
	f.BackgroundColor3 = color
	f.BackgroundTransparency = alpha
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function uiText(
	parent: Instance,
	name: string,
	text: string,
	font: Enum.Font,
	pos: UDim2,
	size: UDim2,
	color: Color3,
	maxSize: number,
	align: Enum.TextXAlignment?,
	stroke: number?
): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.Text = text
	t.Font = font
	t.Position = pos
	t.Size = size
	t.BackgroundTransparency = 1
	t.TextColor3 = color
	t.TextScaled = true
	t.TextXAlignment = align or Enum.TextXAlignment.Center
	t.TextYAlignment = Enum.TextYAlignment.Center
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = maxSize
	c.Parent = t
	if stroke then
		local s = Instance.new("UIStroke")
		s.Color = Color3.fromHex("3A1606")
		s.Thickness = stroke
		s.Transparency = 0.15
		s.Parent = t
	end
	t.Parent = parent
	return t
end

local function ledContent(led: BasePart)
	local face = Enum.NormalId.Front
	for _, g in led:GetChildren() do
		if g:IsA("SurfaceGui") then
			face = g.Face
			g:Destroy()
		end
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SurfaceGui"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0
	gui.Brightness = 1
	gui.MaxDistance = 140
	gui.ClipsDescendants = true

	local white = Color3.fromHex("FFF6E8")
	local ink = Color3.fromHex("2A1206")
	local gold = Color3.fromHex("FFC83D")

	-- Key art: gold top-left to deep orange, darkening to ember at the bottom right.
	local bg =
		uiFrame(gui, "KeyArt", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), Color3.new(1, 1, 1), 0)
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("FFD45A")),
		ColorSequenceKeypoint.new(0.45, Color3.fromHex("F58A1F")),
		ColorSequenceKeypoint.new(1, Color3.fromHex("7A2810")),
	})
	grad.Rotation = 28
	grad.Parent = bg
	-- Light streaks (diagonal bands) for energy.
	for i, sx in { 0.52, 0.64, 0.71, 0.86 } do
		local w = ({ 0.07, 0.025, 0.12, 0.04 })[i]
		local st = uiFrame(
			bg,
			"Streak" .. i,
			UDim2.fromScale(sx, -0.3),
			UDim2.fromScale(w, 1.6),
			Color3.fromHex("FFF1C8"),
			({ 0.78, 0.7, 0.86, 0.74 })[i]
		)
		st.Rotation = 24
	end
	-- Lower shade so the progress bar and the tiles read.
	local shade = uiFrame(bg, "Shade", UDim2.fromScale(0, 0.42), UDim2.fromScale(1, 0.58), ink, 0)
	local sg = Instance.new("UIGradient")
	sg.Rotation = 90
	sg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.35, 0.55),
		NumberSequenceKeypoint.new(1, 0.25),
	})
	sg.Parent = shade

	-- Top line.
	uiText(
		bg,
		"Season",
		"SEASON 1",
		Enum.Font.GothamBlack,
		UDim2.fromScale(0.04, 0.04),
		UDim2.fromScale(0.3, 0.07),
		white,
		60,
		Enum.TextXAlignment.Left,
		2
	)
	uiText(
		bg,
		"Ends",
		"ENDS IN 42 DAYS",
		Enum.Font.GothamBold,
		UDim2.fromScale(0.66, 0.045),
		UDim2.fromScale(0.3, 0.06),
		white,
		50,
		Enum.TextXAlignment.Right,
		2
	)
	-- Title.
	uiText(
		bg,
		"Title",
		"BATTLE PASS",
		Enum.Font.GothamBlack,
		UDim2.fromScale(0.04, 0.11),
		UDim2.fromScale(0.92, 0.22),
		white,
		200,
		Enum.TextXAlignment.Left,
		5
	)
	uiText(
		bg,
		"Sub",
		"50 TIERS  \u{00B7}  SKINS  \u{00B7}  WRAPS  \u{00B7}  CHARMS  \u{00B7}  EMOTES",
		Enum.Font.GothamBold,
		UDim2.fromScale(0.04, 0.33),
		UDim2.fromScale(0.62, 0.065),
		white,
		48,
		Enum.TextXAlignment.Left,
		2
	)

	-- Progress bar: TIER 0 / 50.
	uiText(
		bg,
		"Tier",
		"TIER 0 / 50",
		Enum.Font.GothamBlack,
		UDim2.fromScale(0.04, 0.43),
		UDim2.fromScale(0.22, 0.08),
		white,
		64,
		Enum.TextXAlignment.Left,
		2
	)
	local track = uiFrame(
		bg,
		"Track",
		UDim2.fromScale(0.27, 0.455),
		UDim2.fromScale(0.69, 0.035),
		Color3.fromHex("1A0B04"),
		0.25
	)
	local ts = Instance.new("UIStroke")
	ts.Color = gold
	ts.Thickness = 2
	ts.Parent = track
	uiFrame(track, "Fill", UDim2.fromScale(0, 0), UDim2.fromScale(0.02, 1), gold, 0)
	for k = 1, 9 do
		uiFrame(track, "Tick" .. k, UDim2.fromScale(k / 10, 0), UDim2.new(0, 2, 1, 0), gold, 0.55)
	end

	-- Reward tiles: tiers 1-10.
	local RARITY = {
		common = Color3.fromHex("A7ABB0"),
		rare = Color3.fromHex("3B8CFF"),
		epic = Color3.fromHex("9B5CFF"),
		legend = gold,
	}
	local TILES = {
		{ "SPRAY", "common" },
		{ "CHARM", "rare" },
		{ "COINS", "common" },
		{ "WRAP", "rare" },
		{ "EMOTE", "epic" },
		{ "CRATE", "common" },
		{ "CHARM", "rare" },
		{ "SKIN", "epic" },
		{ "COINS", "rare" },
		{ "VANDAL", "legend" },
	}
	local row = uiFrame(
		bg,
		"Tiles",
		UDim2.fromScale(0.04, 0.55),
		UDim2.fromScale(0.92, 0.24),
		Color3.new(0, 0, 0),
		1
	)
	local gap = 0.012
	local tw = (1 - gap * 9) / 10
	for i, t in TILES do
		local tile = uiFrame(
			row,
			"Tier" .. i,
			UDim2.fromScale((i - 1) * (tw + gap), 0),
			UDim2.fromScale(tw, 1),
			Color3.fromHex("170A04"),
			0.2
		)
		local stroke = Instance.new("UIStroke")
		stroke.Color = if i == 1 then white else RARITY[t[2]]
		stroke.Thickness = if i == 1 then 3 else 1.5
		stroke.Transparency = if i == 1 then 0 else 0.35
		stroke.Parent = tile
		uiText(
			tile,
			"Num",
			tostring(i),
			Enum.Font.GothamBlack,
			UDim2.fromScale(0.08, 0.04),
			UDim2.fromScale(0.5, 0.26),
			white,
			40,
			Enum.TextXAlignment.Left
		)
		uiText(
			tile,
			"Item",
			t[1],
			Enum.Font.GothamBold,
			UDim2.fromScale(0.06, 0.38),
			UDim2.fromScale(0.88, 0.26),
			white,
			30
		)
		uiFrame(tile, "Rarity", UDim2.fromScale(0, 0.86), UDim2.fromScale(1, 0.14), RARITY[t[2]], 0)
		if i > 1 then
			uiText(
				tile,
				"Lock",
				"LOCKED",
				Enum.Font.Gotham,
				UDim2.fromScale(0.1, 0.66),
				UDim2.fromScale(0.8, 0.16),
				Color3.fromHex("CFC3B4"),
				20
			)
		end
	end
	uiText(
		bg,
		"Free",
		"FREE + PREMIUM TRACKS",
		Enum.Font.GothamBold,
		UDim2.fromScale(0.04, 0.81),
		UDim2.fromScale(0.4, 0.05),
		Color3.fromHex("FFE2B8"),
		36,
		Enum.TextXAlignment.Left
	)
	gui.Parent = led
end

local cavern = artSection("Market_Cavern")
local rock = Instance.new("Folder")
rock.Name = "Rock"
rock.Parent = cavern
local built = Instance.new("Folder")
built.Name = "Built"
built.Parent = cavern

-- Walls (plinth, shadow gap, rock to 34), a rock band above them to the roof, and the lintel.
local nw, ne = Vector3.new(X0, 0, ZN), Vector3.new(X1, 0, ZN)
local sw, se = Vector3.new(X0, 0, ZS), Vector3.new(X1, 0, ZS)
wallLine(rock, nw, Vector3.new(X0, 0, -25), EAST)
wallLine(rock, Vector3.new(X0, 0, 25), sw, EAST)
-- Behind the LED wall: a tall board-formed concrete backdrop (the feature panel stretched to 28),
-- so no rock relief ever covers the screen.
for _, z in { -50 / 3, 0, 50 / 3 } do
	scaled(
		rock,
		"MarketRockWall_Feature",
		faceCF(Vector3.new(X0, 0, z), EAST),
		Vector3.new(1, 1.8, (50 / 3 + 0.8) / 12)
	)
end
wallLine(rock, nw, ne, SOUTH)
wallLine(rock, sw, se, NORTH)
wallLine(rock, ne, Vector3.new(X1, 0, -22), WEST)
wallLine(rock, Vector3.new(X1, 0, 22), se, WEST)
bandLine(rock, nw, sw, EAST, 37.5, 8, 0.4)
bandLine(rock, nw, ne, SOUTH, 37.5, 8, 0.4)
bandLine(rock, sw, se, NORTH, 37.5, 8, 0.4)
bandLine(rock, ne, Vector3.new(X1, 0, -22), WEST, 37.5, 8, 0.4)
bandLine(rock, Vector3.new(X1, 0, 22), se, WEST, 37.5, 8, 0.4)
-- The lintel over the neck: a shallow band behind the TO HUB sign (kept clear of it).
for _, z in { -11.25, 11.25 } do
	band(rock, Vector3.new(X1 + 0.5, 30.5, z), WEST, 23.5, 21, 0.45)
end

-- Ceiling.
for _, x in { -323.5, -306.5, -289.5, -272.5 } do
	for _, z in { -38, -19, 0, 19, 38 } do
		ceil(
			rock,
			Vector3.new(x + rng:NextNumber(-1.5, 1.5), ROOF - 0.5, z + rng:NextNumber(-1.5, 1.5))
		)
	end
end

-- Slabs, pillars, drops.
for _, d in MARKET:GetChildren() do
	if d:IsA("BasePart") then
		local n = d.Name
		if n == "Cav_Corner" or n == "Cav_WallRock" then
			slabOver(rock, d)
		elseif n == "Cav_PillarN_A" or n == "Cav_PillarS_A" then
			local roof = d.Size.Y - 2
			local w = d.Size.X
			local cf = CFrame.new(d.Position.X, 0, d.Position.Z) * d.CFrame.Rotation
			scaled(rock, pick("pillar", PILLARS), cf, Vector3.new(w / 5, roof / 30, w / 5))
			hide(d)
			local b = gpart(string.sub(n, 1, -2) .. "B")
			if b then
				hide(b)
			end
		elseif string.find(n, "^Cav_Drop") then
			local sz = d.Size
			scaled(
				rock,
				pick("drop", DROPS),
				d.CFrame * CFrame.new(0, sz.Y / 2, 0),
				Vector3.new(sz.X / 5, sz.Y / 12, sz.Z / 4)
			)
			hide(d)
		end
	end
end
for _, n in
	{
		"Cav_WallW",
		"Cav_WallN",
		"Cav_WallS",
		"Cav_WallE_N",
		"Cav_WallE_S",
		"Cav_Lintel",
		"Cav_Roof",
	}
do
	local p = gpart(n)
	if p then
		hide(p)
	end
end

-- Floor and runner.
do
	local fl = gpart("Cav_Floor")
	if fl then
		finish(fl, "Terrazzo")
	end
	local path = gpart("Cav_Path")
	if path then
		hide(path)
		-- MarketRunner tiles from the neck (east end) to the dais, 10.8 long each.
		local x1 = path.Position.X + path.Size.X / 2
		local L = path.Size.X
		local n = math.max(1, math.ceil(L / 10 - 1e-6))
		for k = 0, n - 1 do
			local m = scaled(
				built,
				"MarketRunner",
				faceCF(Vector3.new(x1 - k * L / n, 0, path.Position.Z), WEST),
				Vector3.new(L / n / 10, 1, 1)
			)
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					d.CastShadow = false
				end
			end
		end
	end
end

-- The Battle Pass wall, dais and rewards.
do
	local cf = faceCF(Vector3.new(X0, 0, 0), EAST)
	local bp = put(built, "BattlePassWall", cf, "BattlePassWall")
	if hasKit("Trophy_Vandal") then
		local g = kit("Trophy_Vandal"):Clone()
		local L = g:GetAttribute("Length")
		local low = g:GetAttribute("Low")
		local k = if typeof(L) == "number" and L > 0 then 7 / L else 1
		g:ScaleTo(k)
		local drop = if typeof(low) == "number" then math.abs(low) * k else 0.6
		local base = (cf * CFrame.new(6, 4.0, 0)).Position + Vector3.new(0, drop + 1.1, 0)
		-- Floating side-on above the centre plinth, muzzle to the viewer's right (north) from the runner;
		-- untinted, so it reads as a dark silhouette against the bright key art.
		local muzzle = NORTH
		g:PivotTo(CFrame.fromMatrix(base, muzzle:Cross(Vector3.yAxis), Vector3.yAxis))
		g.Name = "Reward_Gun"
		g.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		g.Parent = bp
	end
	showItem(
		bp,
		"MarketShowFigure",
		cf * CFrame.new(6, 4.0, -12) * CFrame.Angles(0, math.rad(-15), 0),
		1.8
	)
	showItem(
		bp,
		"MarketShowCrate",
		cf * CFrame.new(6, 4.0, 12) * CFrame.Angles(0, math.rad(20), 0),
		1.75
	)
	for _, n in
		{
			"Dais1",
			"Dais2",
			"DaisGlow",
			"LEDBezel",
			"Reward1",
			"Reward2",
			"Reward3",
			"RewardItem1",
			"RewardItem2",
			"RewardItem3",
		}
	do
		local p = gpart(n)
		if p then
			hide(p)
		end
	end
	local led = gpart("LEDWall")
	if led then
		finish(led, "Screen")
		ledContent(led)
	end
end

-- CODES and PREMIUM kiosks on the north and south walls.
do
	local fr = CFrame.lookAt(Vector3.new(-262, 0, 0), Vector3.new(-263, 0, 0))
	for _, k in
		{ { "CODES", 1, "MarketShowCrate", 1.15 }, { "PREMIUM", -1, "MarketShowCoins", 1.0 } }
	do
		local label, side = k[1] :: string, k[2] :: number
		local pos = (fr * CFrame.new(side * 46, 0, -28)).Position
		local cf = faceCF(pos, -side * fr.RightVector)
		local shop = put(built, "ShopPavilion", cf, "Shop_" .. label)
		showItem(
			shop,
			k[3] :: string,
			cf * CFrame.new(2.5, 3.6, 0) * CFrame.Angles(0, math.rad(-20), 0),
			k[4] :: number
		)
		scaled(
			rock,
			"MarketRockHood",
			cf * CFrame.new(0, 14.6, 0),
			Vector3.new(1, 8 / 12, 1),
			"Hood_" .. label
		)
		for _, sfx in
			{ "Canopy", "FinA", "FinB", "Header", "Plinth", "Slats", "Counter", "Display", "Glow" }
		do
			local p = gpart("Shop_" .. label .. "_" .. sfx)
			if p then
				hide(p)
			end
		end
		local sg = gpart("Shop_" .. label .. "_Sign")
		if sg then
			finish(sg, "Sign")
		end
		local l = Instance.new("PointLight")
		l.Color = WARM
		l.Range = 24
		l.Brightness = 2.6
		l.Shadows = false
		l.Parent = make1(
			built,
			"KioskLight_" .. label,
			Vector3.new(0.2, 0.2, 0.2),
			cf * CFrame.new(9, 11, 0)
		)
	end
end

-- TO HUB sign on the lintel.
do
	local sg = gpart("Sign_Hub")
	if sg then
		finish(sg, "Sign")
		local cf = faceCF(sg.Position, sg.CFrame.LookVector)
		scaled(
			built,
			"MarketSignFrame",
			cf,
			Vector3.new(1, sg.Size.Y / 2.4, sg.Size.X / 10),
			"Sign_Hub_Frame"
		)
		-- A warm 0.3 edge line above the frame as well, so it reads against the dark lintel rock.
		local top = make(
			built,
			"Sign_Hub_TopGlow",
			Vector3.new(sg.Size.X + 0.8, 0.3, 0.3),
			cf * CFrame.new(0.2, sg.Size.Y / 2 + 0.75, 0) * CFrame.Angles(0, math.rad(90), 0),
			Color3.fromHex("FFDDB0"),
			{ material = Enum.Material.Neon, collide = false, shadow = false }
		)
		top:SetAttribute("Glow", true)
	end
end

-- Key light: a warm spot from high in front of the dais onto the rewards and the LED wall (the wing's
-- one shadow caster).
do
	local pos = Vector3.new(-306, 26, 0)
	local a = make1(
		built,
		"KeyLight_BattlePass",
		Vector3.new(0.2, 0.2, 0.2),
		CFrame.lookAt(pos, Vector3.new(-328, 4, 0))
	)
	local s = Instance.new("SpotLight")
	s.Face = Enum.NormalId.Front
	s.Color = WARM
	s.Range = 40
	s.Angle = 80
	s.Brightness = 4
	s.Shadows = true
	s.Parent = a
end

-- The LED wall lights the cavern: a warm SurfaceLight (the key art's colour) on its face throws a wide wash over the dais,
-- the floor and the pillars.
do
	local a = make1(
		built,
		"LEDWash",
		Vector3.new(38, 18, 0.2),
		CFrame.lookAt(Vector3.new(-330.9, 15, 0), Vector3.new(-300, 15, 0))
	)
	local s = Instance.new("SurfaceLight")
	s.Face = Enum.NormalId.Front
	s.Color = Color3.fromHex("FFD9A8")
	s.Range = 40
	s.Angle = 75
	s.Brightness = 3
	s.Shadows = false
	s.Parent = a
end

-- Two warm downlight pools on the runner between the kiosks and the dais.
for i, x in { -278, -296 } do
	local l = Instance.new("PointLight")
	l.Color = WARM
	l.Range = 22
	l.Brightness = 1.2
	l.Shadows = false
	l.Parent = make1(built, "RunnerLight" .. i, Vector3.new(0.2, 0.2, 0.2), CFrame.new(x, 18, 0))
end

-- Shadow lid over the cavern roof (see Art_Market_Street): keeps the sun and the sky out.
do
	local lid = make(
		built,
		"ShadowLid",
		Vector3.new(76, 8, 104),
		CFrame.new(-302, 48, 0),
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

publishArt(cavern)
