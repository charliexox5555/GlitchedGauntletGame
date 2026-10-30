--!strict
-- Lobby art pass: the Duels wing (phase 1 step 5). Dresses Greybox.Wing_Duels with the
-- "Duels" kit group (tools/blender/build_lobby_kit_duels.py) and rebuilds three Art folders:
--   Art.DuelsHall     entry vestibule, section arches, nave trusses, clerestory rock, the
--                     section light rigs (6 SurfaceLights, shadowless)
--   Art.DuelsBays     chapel bay shells, queue pads and bay sign frames (16 bays)
--   Art.DuelsChamber  the GAUNTLET chamber: walls, apse, rock, trusses, pads, dais and gate
-- The greybox stays the collision: parts the kit replaces are hidden (they keep CanCollide),
-- the rest get a finished look. Signs keep their greybox panels (phase-2 hooks) and get
-- restyled SurfaceGuis inside kit bezels. Re-runnable: publishArt replaces the folders and
-- hide/finish/restyle are idempotent.
-- Run: python tools/studio/lobby/bundle.py Art_Duels -o art_duels.luau

local W = grey("Wing_Duels")
assert(W, "no Greybox.Wing_Duels (run Wing_Duels first)")

local AISLE = 11
local BAY_X = 12
local ARCH_DEPTH = 4
local DIVIDER = 2

-- Neon pushes colour toward white and cyan, so the green ring is pulled toward pure green to
-- read as 1V1 green (#3DDC84 itself blooms teal). Text keeps the plan colours.
local RING = {
	["1v1"] = Color3.fromHex("1FD254"),
	["2v2"] = Color3.fromHex("2050FF"),
	["3v3"] = Color3.fromHex("9150FF"),
	["4v4"] = C.m4v4,
}
local DORMANT = Color3.fromHex("5A5C60")
local DIM_TEXT = Color3.fromRGB(150, 154, 162)
local DUELS_LIGHT = Color3.fromHex("B8D4FF")
local WALL = Color3.fromHex("2C2D30") -- Lobby_ConcreteDark, the Duels wall tone (kit ConcreteDuels)
local AISLE_TONE = Color3.fromHex("242528")
local NORTH_V = Vector3.new(0, 0, -1)
local SOUTH_V = Vector3.new(0, 0, 1)

type Section = {
	key: string,
	title: string,
	color: Color3,
	live: boolean,
	party: number,
	depth: number,
	len: number,
	perSide: number,
}

local SECTIONS: { Section } = {
	{
		key = "1v1",
		title = "1V1",
		color = C.m1v1,
		live = true,
		party = 2,
		depth = 12,
		len = 12,
		perSide = 3,
	},
	{
		key = "2v2",
		title = "2V2",
		color = C.m2v2,
		live = true,
		party = 4,
		depth = 15,
		len = 15,
		perSide = 2,
	},
	{
		key = "3v3",
		title = "3V3",
		color = C.m3v3,
		live = true,
		party = 6,
		depth = 16,
		len = 17,
		perSide = 2,
	},
	{
		key = "4v4",
		title = "4V4",
		color = C.m4v4,
		live = false,
		party = 8,
		depth = 17,
		len = 18,
		perSide = 1,
	},
}

local hall = artSection("DuelsHall")
local bays = artSection("DuelsBays")
local chamber = artSection("DuelsChamber")

local stats = { hidden = 0, finished = 0, lights = 0 }

local function hideP(p: Instance)
	hide(p)
	stats.hidden += 1
end

local function finishP(p: Instance, look: string, color: Color3?)
	finish(p, look)
	if color and p:IsA("BasePart") then
		p.Color = color
	end
	stats.finished += 1
end

local function atomic(m: Model)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
end

-- Rock panels (8 wide x 12 tall) along a wall face from a to b (y ignored), front-most facet
-- 0.2 proud of the face.
local ROCKS = { "DuelsRock_A", "DuelsRock_B", "DuelsRock_C" }
local rockN = 0
local function rockRun(parent: Instance, a: Vector3, b: Vector3, y: number, front: Vector3)
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local len = flat.Magnitude
	local dir = flat.Unit
	local n = math.max(1, math.ceil(len / 8 - 0.05))
	for k = 0, n - 1 do
		local t = if n == 1 then len / 2 else 4 + (len - 8) * k / (n - 1)
		local p = Vector3.new(a.X, y, a.Z) + dir * t - front * 1.4
		rockN += 1
		put(parent, ROCKS[rockN % 3 + 1], faceCF(p, front), "Rock")
	end
end

-- Shadow gap trims (12 long) along a wall face, band from y to y + 0.72.
local function gapRun(parent: Instance, a: Vector3, b: Vector3, y: number, front: Vector3)
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local len = flat.Magnitude
	local dir = flat.Unit
	local n = math.max(1, math.ceil(len / 12 - 0.05))
	for k = 0, n - 1 do
		local t = if n == 1 then len / 2 else 6 + (len - 12) * k / (n - 1)
		local p = Vector3.new(a.X, y, a.Z) + dir * t
		put(parent, "DuelsGap_12", faceCF(p, front), "Gap")
	end
end

-- An invisible emitter for a shadowless SurfaceLight (the section light pools). Keep the
-- emitter out of solid geometry: a light inside the soffit mesh lights nothing, even with
-- Shadows off, so the pools hang just under the 14 soffit.
local function surfaceLight(
	parent: Instance,
	name: string,
	cf: CFrame,
	size: Vector3,
	range: number,
	bright: number,
	angle: number
)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	p.CFrame = cf
	local l = Instance.new("SurfaceLight")
	l.Face = Enum.NormalId.Bottom
	l.Color = DUELS_LIGHT
	l.Range = range
	l.Brightness = bright
	l.Angle = angle
	l.Shadows = false
	l.Parent = p
	p.Parent = parent
	stats.lights += 1
	return p
end

-- ---------------------------------------------------------------- sign restyle

local function clearGuis(p: Instance)
	for _, d in p:GetChildren() do
		if d:IsA("SurfaceGui") then
			d:Destroy()
		end
	end
end

type SignLine = { name: string, text: string, cap: number, color: Color3, font: Enum.Font }

-- Rebuilds a sign's front SurfaceGui: GothamBlack title, GothamBold sub lines, optional slot
-- pips (outlined squares in the mode colour, filled when queued; phase 2 drives them).
local function signGui(p: BasePart, lines: { SignLine }, pips: number?, pipColor: Color3?)
	clearGuis(p)
	local h = p.Size.Y
	local stack = 0
	for _, l in lines do
		stack += l.cap / 0.72 * 1.12
	end
	if pips and pips > 0 then
		stack += 1.0
	end
	local k = math.min(1, h * 0.86 / stack)
	local maxFont = 0
	for _, l in lines do
		maxFont = math.max(maxFont, l.cap / 0.72 * k)
	end
	local pps = math.clamp(math.floor(95 / maxFont), 4, 50)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pps
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.MaxDistance = 250
	gui.ClipsDescendants = true
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = gui
	for i, l in lines do
		local font = l.cap / 0.72 * k
		local t = Instance.new("TextLabel")
		t.Name = l.name
		t.LayoutOrder = i
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(0.92, 0, 0, math.ceil(font * pps * 1.12))
		t.Font = l.font
		t.TextColor3 = l.color
		t.Text = l.text
		t.TextScaled = true
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = math.floor(font * pps)
		limit.Parent = t
		t.Parent = gui
	end
	if pips and pips > 0 then
		local size = math.floor(0.62 * pps)
		local row = Instance.new("Frame")
		row.Name = "Pips"
		row.LayoutOrder = #lines + 1
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, math.floor(1.0 * pps))
		local rl = Instance.new("UIListLayout")
		rl.FillDirection = Enum.FillDirection.Horizontal
		rl.HorizontalAlignment = Enum.HorizontalAlignment.Center
		rl.VerticalAlignment = Enum.VerticalAlignment.Center
		rl.Padding = UDim.new(0, math.floor(0.3 * pps))
		rl.Parent = row
		for i = 1, pips do
			local pip = Instance.new("Frame")
			pip.Name = "Pip" .. i
			pip.LayoutOrder = i
			pip.Size = UDim2.new(0, size, 0, size)
			pip.BackgroundColor3 = pipColor or C.white
			pip.BackgroundTransparency = 1
			local stroke = Instance.new("UIStroke")
			stroke.Color = pipColor or C.white
			stroke.Thickness = math.max(2, math.floor(0.09 * pps))
			stroke.Parent = pip
			pip.Parent = row
		end
		row.Parent = gui
	end
	gui.Parent = p
end

local function restyleTitle(p: Instance, title: string, titleColor: Color3, sub: string?)
	if not p:IsA("BasePart") then
		return
	end
	finishP(p, "Sign")
	local lines: { SignLine } = {
		{
			name = "Title",
			text = title,
			cap = p.Size.Y >= 7 and 4 or 2.2,
			color = titleColor,
			font = Enum.Font.GothamBlack,
		},
	}
	if sub then
		table.insert(
			lines,
			{ name = "Sub", text = sub, cap = 1.15, color = DIM_TEXT, font = Enum.Font.GothamBold }
		)
	end
	signGui(p, lines)
end

-- ---------------------------------------------------------------- greybox pass

local function child(name: string): { BasePart }
	local out = {}
	for _, d in W:GetChildren() do
		if d.Name == name and d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out
end

local HIDE_SUFFIX = {
	"_Header",
	"_Shoulder",
	"_RedEdge",
	"_Soffit",
	"_SoffitEdge",
	"_Clerestory",
	"_BackWall",
	"_TrussRail",
	"_Deck",
	"_RingN",
	"_RingS",
	"_RingE",
	"_RingW",
	"_LightDeck",
	"_SignEdge",
	"_Divider",
	"_Kerb",
}
local HIDE_NAME = {
	Entry_Terminal = true,
	Entry_TerminalScreen = true,
	Chamber_WallRock = true,
	Dais_Apron = true,
	Dais_Low = true,
	Dais_High = true,
	Gate_Column = true,
	Gate_Lintel = true,
}

for _, p in W:GetChildren() do
	if not p:IsA("BasePart") then
		continue
	end
	local n = p.Name
	local done = false
	if HIDE_NAME[n] or string.match(n, "^Apse_%d+$") or string.match(n, "_Truss%d+$") then
		hideP(p)
		done = true
	else
		for _, s in HIDE_SUFFIX do
			if string.sub(n, -#s) == s then
				hideP(p)
				done = true
				break
			end
		end
	end
	if done then
		continue
	end
	if n == "Aisle" then
		finishP(p, "ConcreteDark", AISLE_TONE)
	elseif string.sub(n, -6) == "_Floor" then
		finishP(p, "ConcreteDark")
	elseif string.sub(n, -12) == "_NaveCeiling" or n == "Entry_Ceiling" or n == "Chamber_Roof" then
		finishP(p, "SteelBlack")
	elseif string.sub(n, -5) == "_Pier" or n == "Entry_Wall" or n == "Chamber_Wall" then
		finishP(p, "ConcreteDark", WALL)
	elseif n == "Entry_Pilaster" or n == "Chamber_Column" then
		finishP(p, "SteelBlack")
	end
end

-- ---------------------------------------------------------------- hall: entry vestibule

for _, side in { -1, 1 } do
	local face = Vector3.new(-side, 0, 0)
	for _, zc in { -68.3, -75 } do
		local m = put(
			hall,
			"QueueTerminal",
			faceCF(Vector3.new(side * 24.5, 0, zc), face),
			"QueueTerminal"
		)
		atomic(m)
		-- The screen: kit-local centre (0.675, 4.225) and normal (0.660, 0.751), from the Blender build.
		local n = Vector3.new(0.66, 0.751, 0).Unit
		local c = Vector3.new(0.675, 4.225, 0) + n * 0.1
		local scr = Instance.new("Part")
		scr.Name = "TerminalScreen"
		scr.Anchored = true
		scr.CanCollide = false
		scr.CanQuery = false
		scr.CanTouch = false
		scr.CastShadow = false
		scr.Material = Enum.Material.SmoothPlastic
		scr.Color = C.screen
		scr.Size = Vector3.new(2.45, 1.55, 0.02)
		scr.CFrame = m:GetPivot() * CFrame.lookAt(c, c + n, Vector3.yAxis)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.LightInfluence = 0
		gui.Brightness = 1.3
		gui.MaxDistance = 120
		gui.ClipsDescendants = true
		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = Color3.fromHex("0E1A2C")
		bg.BorderSizePixel = 0
		bg.Parent = gui
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.BackgroundTransparency = 1
		title.Position = UDim2.fromScale(0.06, 0.05)
		title.Size = UDim2.fromScale(0.88, 0.24)
		title.Font = Enum.Font.GothamBlack
		title.Text = "QUEUE"
		title.TextColor3 = C.white
		title.TextScaled = true
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Parent = bg
		for i, row in { { "1V1", RING["1v1"] }, { "2V2", RING["2v2"] }, { "3V3", RING["3v3"] } } do
			local y = 0.33 + (i - 1) * 0.21
			local lab = Instance.new("TextLabel")
			lab.BackgroundTransparency = 1
			lab.Position = UDim2.fromScale(0.06, y)
			lab.Size = UDim2.fromScale(0.26, 0.16)
			lab.Font = Enum.Font.GothamBold
			lab.Text = row[1] :: string
			lab.TextColor3 = C.white
			lab.TextScaled = true
			lab.TextXAlignment = Enum.TextXAlignment.Left
			lab.Parent = bg
			local bar = Instance.new("Frame")
			bar.BorderSizePixel = 0
			bar.BackgroundColor3 = row[2] :: Color3
			bar.Position = UDim2.fromScale(0.36, y + 0.04)
			bar.Size = UDim2.fromScale(0.56, 0.08)
			bar.Parent = bg
		end
		gui.Parent = scr
		scr.Parent = m
	end
	-- Queue sign (11 x 3 on the pilaster) in a kit bezel with a red strip.
	put(
		hall,
		"SignFrame_11x3",
		faceCF(Vector3.new(side * 24.5, 8.25, -71.25), face),
		"QueueSignFrame"
	)
	-- Rock high on the vestibule walls, over a shadow gap at 14.
	gapRun(hall, Vector3.new(side * 26, 0, -65.2), Vector3.new(side * 26, 0, -78), 14, face)
	rockRun(hall, Vector3.new(side * 26, 0, -64.6), Vector3.new(side * 26, 0, -78), 14.7, face)
	-- Arch 1's south face beside the opening (seen from spawn): concrete below, gap, rock above.
	gapRun(hall, Vector3.new(side * 15.3, 0, -78), Vector3.new(side * 27.5, 0, -78), 16, SOUTH_V)
	rockRun(hall, Vector3.new(side * 15, 0, -78), Vector3.new(side * 26, 0, -78), 16.7, SOUTH_V)
end
for _, p in child("Entry_QueueSign") do
	finishP(p, "Sign")
	signGui(p, {
		{
			name = "Title",
			text = "QUEUE TERMINALS",
			cap = 1.2,
			color = C.white,
			font = Enum.Font.GothamBlack,
		},
		{
			name = "Sub",
			text = "OR JUST PRESS PLAY",
			cap = 0.85,
			color = DIM_TEXT,
			font = Enum.Font.GothamBold,
		},
	})
end

-- ---------------------------------------------------------------- hall + bays: sections

local function archAt(i: number, zN: number, tint: Color3)
	local m = put(hall, "DuelsArch", faceCF(Vector3.new(0, 0, zN), SOUTH_V), "Arch" .. i)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "DuelsArch_Strip_Glow" then
			d.Color = tint
		end
	end
	return m
end

local z = -78
for i, s in SECTIONS do
	local zN = z - ARCH_DEPTH
	local ring = if s.live then RING[s.key] else DORMANT
	local titleTint = if s.live then s.color else s.color:Lerp(C.unpowered, 0.6)
	archAt(i, zN, if s.live then ring else DORMANT)
	for _, p in child("Arch" .. i .. "_Title") do
		restyleTitle(
			p,
			s.title,
			titleTint,
			if s.live then string.format("%d PLAYERS", s.party) else "COMING SOON"
		)
	end

	local sS = zN
	local sN = sS - (s.perSide * s.len + (s.perSide - 1) * DIVIDER)
	local xb = BAY_X + s.depth
	local xo = xb + 2
	for _, side in { -1, 1 } do
		local face = Vector3.new(-side, 0, 0)
		-- Clerestory rock above the bays, the length of the section, over a lit shadow gap on
		-- the soffit nose: one cool line per side runs the length of the hall.
		gapRun(hall, Vector3.new(side * AISLE, 0, sS), Vector3.new(side * AISLE, 0, sN), 15.3, face)
		rockRun(hall, Vector3.new(side * AISLE, 0, sS), Vector3.new(side * AISLE, 0, sN), 16, face)
		for b = 1, s.perSide do
			local b1 = sS - (b - 1) * (s.len + DIVIDER)
			local b0 = b1 - s.len
			local zc = (b0 + b1) / 2
			local tag = string.format("%s_Bay%s%d", s.key, side < 0 and "W" or "E", b)
			put(
				bays,
				"DuelsBayShell_" .. s.len,
				faceCF(Vector3.new(side * xo, 0, zc), face),
				tag .. "_Shell"
			)
			local pad = put(
				bays,
				"QueuePad_" .. s.len,
				faceCF(Vector3.new(side * (BAY_X + s.depth / 2), 0, zc), face),
				tag .. "_Pad"
			)
			tint(pad, ring)
			atomic(pad)
			local sg = put(
				bays,
				"BaySign_" .. (s.len - 3),
				faceCF(Vector3.new(side * xb, 5.75, zc), face),
				tag .. "_SignFrame"
			)
			tint(sg, ring)
			atomic(sg)
			for _, p in child(tag .. "_Sign") do
				finishP(p, "Sign")
				signGui(p, {
					{
						name = "Mode",
						text = s.title,
						cap = 2.3,
						color = if s.live then s.color else C.unpowered,
						font = Enum.Font.GothamBlack,
					},
					{
						name = "Count",
						text = if s.live then string.format("0 / %d QUEUED", s.party) else "SOON",
						cap = 1.0,
						color = if s.live then C.white else C.unpowered,
						font = Enum.Font.GothamBold,
					},
				}, if s.live then s.party else nil, s.color)
			end
			if side > 0 then
				put(
					hall,
					"DuelsTruss_22",
					faceCF(Vector3.new(0, 0, zc), SOUTH_V),
					s.key .. "_Truss" .. b
				)
			end
		end
		-- One cool pool per live section side: a long SurfaceLight over the coffers. The far
		-- 3V3 section shares one light across the aisle, so the GAUNTLET gate gets the sixth.
		if s.live and s.key ~= "3v3" then
			surfaceLight(
				hall,
				string.format("%s_Light%s", s.key, side < 0 and "W" or "E"),
				CFrame.new(side * (BAY_X + s.depth / 2), 13.7, (sS + sN) / 2),
				Vector3.new(s.depth - 4, 0.2, sS - sN - 4),
				18,
				2.5,
				90
			)
		end
	end
	if s.key == "3v3" then
		surfaceLight(
			hall,
			"3v3_Light",
			CFrame.new(0, 13.7, (sS + sN) / 2),
			Vector3.new(2 * (xb - 3), 0.2, sS - sN - 4),
			18,
			2,
			100
		)
	end
	z = sN
end

-- The chamber arch: same kit, gold title strip (dormant).
local gTint = C.gauntlet:Lerp(C.unpowered, 0.35)
archAt(5, z - ARCH_DEPTH, gTint)
for _, p in child("ArchGauntlet_Title") do
	restyleTitle(p, "GAUNTLET", gTint, "COMING SOON")
end
for _, p in child("HubSign") do
	restyleTitle(p, "HUB", C.white, "BACK TO SPAWN")
end
put(hall, "SignFrame_14x45", faceCF(Vector3.new(0, 16.0, -82.05), NORTH_V), "HubSignFrame")

-- ---------------------------------------------------------------- GAUNTLET chamber

local zS = z - ARCH_DEPTH -- -224: the chamber's south wall (the arch's north face)
local CZ, R = -260, 36
for _, side in { -1, 1 } do
	local face = Vector3.new(-side, 0, 0)
	-- South wall either side of the arch: gap at 16, rock above (and above the arch head).
	gapRun(chamber, Vector3.new(side * 15.3, 0, zS), Vector3.new(side * 36, 0, zS), 16, NORTH_V)
	rockRun(chamber, Vector3.new(side * 15, 0, zS), Vector3.new(side * 36, 0, zS), 16.7, NORTH_V)
	rockRun(chamber, Vector3.new(side * 15, 0, zS), Vector3.new(side * 36, 0, zS), 23, NORTH_V)
	-- Side walls: concrete to 16, gap, two rock rows to the roof.
	gapRun(chamber, Vector3.new(side * R, 0, zS), Vector3.new(side * R, 0, CZ), 16, face)
	rockRun(chamber, Vector3.new(side * R, 0, zS), Vector3.new(side * R, 0, CZ), 16.7, face)
	rockRun(chamber, Vector3.new(side * R, 0, zS), Vector3.new(side * R, 0, CZ), 23, face)
	-- Dormant GAUNTLET pads and their signs.
	local pad = put(
		chamber,
		"QueuePad_G18",
		faceCF(Vector3.new(side * 21, 0, -239), face),
		"Gauntlet" .. (side < 0 and "W" or "E") .. "_Pad"
	)
	tint(pad, DORMANT)
	atomic(pad)
	local sg = put(
		chamber,
		"BaySign_12",
		faceCF(Vector3.new(side * R, 5.75, -239), face),
		"GauntletSignFrame"
	)
	tint(sg, DORMANT)
	atomic(sg)
end
rockRun(chamber, Vector3.new(-15, 0, zS), Vector3.new(15, 0, zS), 27, NORTH_V)
for _, p in child("Gauntlet_Sign") do
	finishP(p, "Sign")
	signGui(p, {
		{
			name = "Mode",
			text = "GAUNTLET",
			cap = 2.3,
			color = C.unpowered,
			font = Enum.Font.GothamBlack,
		},
		{
			name = "Count",
			text = "SOON",
			cap = 1.0,
			color = C.unpowered,
			font = Enum.Font.GothamBold,
		},
	})
end

-- Apse: 16 chords of R36 round (0, -260), bearings 270..90 through north.
local apo = R * math.cos(math.rad(SEG / 2))
for k = 0, 15 do
	local b = 270 + SEG * k + SEG / 2
	put(chamber, "DuelsApseWall", ringCF(apo + 0.4, b, 0, 0, CZ), "ApseWall")
	for _, y in { 16.7, 23 } do
		rockN += 1
		put(chamber, ROCKS[rockN % 3 + 1], ringCF(apo - 0.2 + 1.6, b, y, 0, CZ), "Rock")
	end
end

-- Roof trusses bearing on the steel columns.
for _, tz in { -228, -250 } do
	put(chamber, "DuelsTruss_76", faceCF(Vector3.new(0, 0, tz), SOUTH_V), "Truss")
end

-- Dais and the dormant gate at the end of the axis.
local dais = put(chamber, "GauntletDais", CFrame.new(0, 0, -270), "GauntletDais")
for _, d in dais:GetDescendants() do
	if d:IsA("BasePart") and d.Name == "GauntletDais_Ring_Glow" then
		d.Color = gTint:Lerp(DORMANT, 0.3)
	end
end
local gate = put(chamber, "GauntletGate", faceCF(Vector3.new(0, 0, -287), SOUTH_V), "GauntletGate")
for _, d in gate:GetDescendants() do
	if
		d:IsA("BasePart")
		and (d.Name == "GauntletGate_Strip_Glow" or d.Name == "GauntletGate_Slit_Glow")
	then
		d.Color = gTint
	end
end
-- The gate's key light (the sixth): a cool wash down the gate and over the dais, so the
-- end of the axis reads from the hub portal.
surfaceLight(
	chamber,
	"Gate_Light",
	CFrame.new(0, 30, -258) * CFrame.Angles(math.rad(35), 0, 0),
	Vector3.new(30, 0.2, 4),
	36,
	1.4,
	100
)
for _, p in child("Gate_Title") do
	finishP(p, "Sign")
	signGui(p, {
		{
			name = "Title",
			text = "GAUNTLET",
			cap = 5,
			color = C.gauntlet,
			font = Enum.Font.GothamBlack,
		},
		{
			name = "Sub",
			text = "COMING SOON",
			cap = 1.6,
			color = DIM_TEXT,
			font = Enum.Font.GothamBold,
		},
	})
end

publishArt(hall)
publishArt(bays)
publishArt(chamber)
table.insert(
	REPORT,
	string.format(
		"Duels greybox: %d hidden, %d finished; %d dynamic lights",
		stats.hidden,
		stats.finished,
		stats.lights
	)
)
