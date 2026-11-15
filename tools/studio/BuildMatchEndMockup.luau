--!strict
-- Mockup: the match end screen (vault/02 Art/UI Match End.md, the starred
-- picks) in the match UI style: team-colour blocks with a slanted end joining a
-- navy plate, dark ink on bright blocks, Builder Extended, keycaps, the glitch
-- split on DEFEAT. Paste into the Studio command bar (Edit mode). Builds
-- StarterGui.MatchEndMockup (Enabled off) with CanvasVictory (2v2) and
-- CanvasDefeat (4v4). The middle of the screen stays clear for the victory
-- scene on the map (name plates over the winners).

local SG = game:GetService("StarterGui")
local RS = game:GetService("ReplicatedStorage")

local function hex(h: string): Color3
	return Color3.fromHex(h)
end
local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local i = Instance.new(class)
	for k, v in props do
		(i :: any)[k] = v
	end
	if parent then
		i.Parent = parent
	end
	return i
end

local BX = "rbxasset://fonts/families/BuilderExtended.json"
local XB = Enum.FontWeight.ExtraBold
local NAVY, NAVY_HI = hex("1C2740"), hex("2B3A5A")
local ALLY, ENEMY = hex("3FE0F2"), hex("FF6B57")
local ALLY_CELL, ENEMY_CELL = hex("0D5C7A"), hex("8A1C24")
local GOLD, MUTED, INK, WHITE = hex("FFC83D"), hex("8E98A8"), hex("141A26"), Color3.new(1, 1, 1)
local CYAN_SPLIT, PINK_SPLIT = hex("00E5FF"), hex("FF8BE0")
local SHADOW = "rbxassetid://121253415859134"
local CAP_R, CAP_L = "rbxassetid://130377997107460", "rbxassetid://75584308608588"
local BOT_HEAD = "rbxassetid://119185654291939"
local SHARD = "rbxassetid://76745392849672"
local CENTRE = Vector2.new(0.5, 0.5)

local ART: { [string]: string } = {}
local ROLE: { [string]: Color3 } = {}
pcall(function()
	local Theme = require(RS.Shared.Config.Theme) :: any
	ART = Theme.CARD_ART
	ROLE = Theme.ROLE
end)

local function text(
	p: Instance,
	name: string,
	s: string,
	size: number,
	color: Color3,
	props: { [string]: any }?
): TextLabel
	local t = make("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, size + 4),
		Text = s,
		FontFace = Font.new(BX, XB),
		TextSize = size,
		TextColor3 = color,
		ZIndex = 4,
	}, p)
	for k, v in props or {} do
		(t :: any)[k] = v
	end
	return t
end

local function shadow(p: Instance, x: number, y: number, w: number, h: number)
	make("ImageLabel", {
		Name = "Shadow",
		Position = UDim2.fromOffset(x - 30, y - 22),
		Size = UDim2.fromOffset(w + 60, h + 60),
		BackgroundTransparency = 1,
		Image = SHADOW,
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 0.45,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(48, 48, 80, 80),
		ZIndex = 0,
	}, p)
end

local function keycap(p: Instance, s: string, w: number, h: number, props: { [string]: any }): Frame
	local k = make("Frame", {
		Name = "Key",
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = hex("0B0F17"),
		BorderSizePixel = 0,
		ZIndex = 8,
	}, p)
	for kk, v in props do
		(k :: any)[kk] = v
	end
	make("UICorner", { CornerRadius = UDim.new(0, 5) }, k)
	local f = make("Frame", {
		Name = "Face",
		Size = UDim2.new(1, 0, 1, -4),
		BackgroundColor3 = hex("E9EDF3"),
		BorderSizePixel = 0,
		ZIndex = 9,
	}, k)
	make("UICorner", { CornerRadius = UDim.new(0, 5) }, f)
	text(
		f,
		"Label",
		s,
		math.floor(h * 0.42),
		INK,
		{ AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.fromScale(1, 1), ZIndex = 10 }
	)
	return k
end

-- A navy strip whose items sit in a row (sizes to them).
local function strip(p: Instance, name: string, h: number, props: { [string]: any }): CanvasGroup
	local g = make("CanvasGroup", {
		Name = name,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, h),
		BackgroundColor3 = NAVY,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, p)
	for k, v in props do
		(g :: any)[k] = v
	end
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, g)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, g)
	return g
end

local function gap(p: Instance, order: number, w: number)
	make("Frame", {
		Name = "Gap" .. order,
		LayoutOrder = order,
		Size = UDim2.fromOffset(w, 2),
		BackgroundTransparency = 1,
	}, p)
end

-- Team block (name in dark ink, optional glitch split) + its slanted end.
local function teamBlock(
	p: Instance,
	order: number,
	s: string,
	size: number,
	color: Color3,
	h: number,
	padL: number,
	glitch: boolean?
)
	local b = make("Frame", {
		Name = "Team",
		LayoutOrder = order,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, h),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, p)
	make("UIPadding", { PaddingLeft = UDim.new(0, padL), PaddingRight = UDim.new(0, 6) }, b)
	local label = text(
		b,
		"Label",
		s,
		size,
		INK,
		{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), ZIndex = 5 }
	)
	if glitch then
		local d = math.max(3, math.floor(size / 18))
		text(
			b,
			"SplitA",
			s,
			size,
			CYAN_SPLIT,
			{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -d, 0.5, 0), ZIndex = 3 }
		)
		text(
			b,
			"SplitB",
			s,
			size,
			PINK_SPLIT,
			{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, d, 0.5, 0), ZIndex = 4 }
		)
		label.ZIndex = 5
	end
	make("ImageLabel", {
		Name = "Cap",
		LayoutOrder = order + 1,
		Size = UDim2.fromOffset(math.floor(h * 0.42), h),
		BackgroundTransparency = 1,
		Image = CAP_R,
		ImageColor3 = color,
		ZIndex = 2,
	}, p)
end

local function canvas(gui: Instance, name: string): Frame
	local c = make("Frame", {
		Name = name,
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(1920, 1080),
		BackgroundTransparency = 1,
	}, gui)
	make("UIScale", { Name = "Fit" }, c)
	return c
end

-- 1. The result headline: VICTORY / DEFEAT block + the final score ------------
local function headline(c: Instance, won: boolean, us: number, them: number)
	local s = strip(
		c,
		"Result",
		96,
		{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(960, 56) }
	)
	teamBlock(
		s,
		1,
		if won then "VICTORY" else "DEFEAT",
		64,
		if won then ALLY else ENEMY,
		96,
		30,
		not won
	)
	gap(s, 3, 22)
	text(s, "Us", tostring(us), 56, ALLY, { LayoutOrder = 4 })
	gap(s, 5, 16)
	text(s, "Dash", "·", 40, MUTED, { LayoutOrder = 6 })
	gap(s, 7, 16)
	text(s, "Them", tostring(them), 56, ENEMY, { LayoutOrder = 8 })
	gap(s, 9, 30)
end

-- 2. Round history: one chip per round in the winner's colour, by gun tier ----
local function history(c: Instance, rounds: { { tier: string, wins: { boolean } } })
	local s = strip(
		c,
		"Rounds",
		58,
		{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(960, 166) }
	)
	make("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, s)
	local n = 0
	for gi, group in rounds do
		local g = make("Frame", {
			Name = "Tier" .. gi,
			LayoutOrder = gi * 2,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 58),
			BackgroundTransparency = 1,
		}, s)
		text(g, "Label", group.tier, 10, MUTED, { Position = UDim2.fromOffset(0, 6) })
		local row = make("Frame", {
			Name = "Chips",
			Position = UDim2.fromOffset(0, 22),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 28),
			BackgroundTransparency = 1,
		}, g)
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, row)
		for _, won in group.wins do
			n += 1
			local chip = make("Frame", {
				Name = "R" .. n,
				LayoutOrder = n,
				Size = UDim2.fromOffset(28, 28),
				BackgroundColor3 = if won then ALLY else ENEMY,
				BorderSizePixel = 0,
				ZIndex = 2,
			}, row)
			make("UICorner", { CornerRadius = UDim.new(0, 4) }, chip)
			text(
				chip,
				"N",
				tostring(n),
				12,
				INK,
				{ AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.fromScale(1, 1) }
			)
		end
		if gi < #rounds then
			gap(s, gi * 2 + 1, 18)
		end
	end
end

-- 3. Scoreboard: a team header and one row per player (fixed columns) ---------
local COLS = { 360, 420, 480, 548 } -- E, D, A, DMG centres
local ROW_W = 620
local function teamHeader(c: Instance, x: number, y: number, label: string, color: Color3)
	local h = make("Frame", {
		Name = "Header",
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(ROW_W, 34),
		BackgroundColor3 = NAVY,
		BorderSizePixel = 0,
	}, c)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, h)
	local block = make("Frame", {
		Name = "Team",
		Size = UDim2.fromOffset(170, 34),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, h)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, block)
	text(block, "Label", label, 14, INK, { Position = UDim2.fromOffset(14, 8) })
	make("ImageLabel", {
		Name = "Cap",
		Position = UDim2.fromOffset(166, 0),
		Size = UDim2.fromOffset(14, 34),
		BackgroundTransparency = 1,
		Image = CAP_R,
		ImageColor3 = color,
		ZIndex = 2,
	}, h)
	for i, l in { "E", "D", "A", "DMG" } do
		text(
			h,
			"Col" .. i,
			l,
			11,
			MUTED,
			{ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(COLS[i], 17) }
		)
	end
end

local function playerRow(
	c: Instance,
	x: number,
	y: number,
	name: string,
	ally: boolean,
	stats: { number },
	mine: boolean,
	mvp: boolean
)
	local h = if mine then 58 else 46
	local r = make("Frame", {
		Name = "Row",
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(ROW_W, h),
		BackgroundColor3 = if mine then NAVY_HI else NAVY,
		BorderSizePixel = 0,
	}, c)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, r)
	local cell = make("Frame", {
		Name = "Cell",
		Size = UDim2.fromOffset(h, h),
		BackgroundColor3 = if ally then ALLY_CELL else ENEMY_CELL,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, r)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, cell)
	make("ImageLabel", {
		Name = "Headshot",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = BOT_HEAD,
		ZIndex = 3,
	}, cell)
	-- the name and the MVP tag sit in a small row (the tag follows the name)
	local line = make("Frame", {
		Name = "NameLine",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, h + 14, 0.5, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 26),
		BackgroundTransparency = 1,
	}, r)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, line)
	text(
		line,
		"PlayerName",
		name,
		if mine then 20 else 16,
		if ally then ALLY else ENEMY,
		{ LayoutOrder = 1 }
	)
	if mvp then
		make("ImageLabel", {
			Name = "Shard",
			LayoutOrder = 2,
			Size = UDim2.fromOffset(22, 22),
			BackgroundTransparency = 1,
			Image = SHARD,
			ImageColor3 = GOLD,
			ZIndex = 3,
		}, line)
		text(line, "Mvp", "MVP", 12, GOLD, { LayoutOrder = 3 })
	end
	for i, v in stats do
		text(
			r,
			"Stat" .. i,
			tostring(v),
			if mine then 22 else 17,
			WHITE,
			{ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, COLS[i], 0.5, 0) }
		)
	end
	return h
end

type P = { name: string, stats: { number }, mine: boolean?, mvp: boolean? }
local function scoreboard(c: Instance, allies: { P }, enemies: { P })
	-- Bottom-aligned with the buttons (y 924); it grows upward for bigger teams.
	local total = 0
	for _, team in { allies, enemies } do
		total += 38 + 18
		for _, p in team do
			total += (if p.mine then 58 else 46) + 4
		end
	end
	total -= 18 + 4
	local x, y = 60, 924 - total
	shadow(c, x, y, ROW_W, total)
	for t, team in { allies, enemies } do
		teamHeader(c, x, y, if t == 1 then "YOUR TEAM" else "ENEMY", if t == 1 then ALLY else ENEMY)
		y += 38
		for _, p in team do
			y += playerRow(c, x, y, p.name, t == 1, p.stats, p.mine == true, p.mvp == true) + 4
		end
		y += 18
	end
end

-- 4. Your build: the drafted Mods, their path and level -----------------------
local function build(
	c: Instance,
	mods: { { id: string, role: string, path: string, level: number } }
)
	local right = 1860
	local w, h, g = 124, 150, 10
	local total = #mods * w + (#mods - 1) * g
	local x0 = right - total
	local head = make("Frame", {
		Name = "BuildHeader",
		Position = UDim2.fromOffset(x0, 560),
		Size = UDim2.fromOffset(total, 30),
		BackgroundColor3 = NAVY,
		BorderSizePixel = 0,
	}, c)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, head)
	text(head, "Label", "YOUR BUILD", 12, MUTED, { Position = UDim2.fromOffset(12, 7) })
	shadow(c, x0, 596, total, h)
	for i, m in mods do
		local card = make("CanvasGroup", {
			Name = "Mod" .. i,
			Position = UDim2.fromOffset(x0 + (i - 1) * (w + g), 596),
			Size = UDim2.fromOffset(w, h),
			BackgroundColor3 = NAVY,
			BorderSizePixel = 0,
		}, c)
		make("UICorner", { CornerRadius = UDim.new(0, 6) }, card)
		make("ImageLabel", {
			Name = "Art",
			Size = UDim2.fromOffset(w, 104),
			BackgroundTransparency = 1,
			Image = ART[m.id] or "",
			ScaleType = Enum.ScaleType.Crop,
		}, card)
		make("Frame", {
			Name = "Band",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(w / 2, 84),
			Size = UDim2.fromOffset(w * 2, 120),
			Rotation = -6,
			BackgroundColor3 = ROLE[m.role] or ALLY,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, card)
		text(
			card,
			"Path",
			string.upper(m.path),
			12,
			INK,
			{ Position = UDim2.fromOffset(10, 104), ZIndex = 4 }
		)
		text(
			card,
			"Level",
			"LV " .. m.level,
			11,
			INK,
			{ Position = UDim2.fromOffset(10, 124), TextTransparency = 0.3, ZIndex = 4 }
		)
	end
end

-- 5. The buttons: PLAY AGAIN (gold, Enter), REMATCH (votes, R), LEAVE ---------
local function buttons(c: Instance, votes: number, needed: number)
	local right, y = 1860, 780
	local w = 400
	local play = make("Frame", {
		Name = "PlayAgain",
		Position = UDim2.fromOffset(right - w, y),
		Size = UDim2.fromOffset(w, 76),
		BackgroundTransparency = 1,
	}, c)
	shadow(c, right - w + 20, y, w - 40, 76)
	make("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(26, 0),
		Size = UDim2.new(1, -52, 1, 0),
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, play)
	make("ImageLabel", {
		Name = "CapL",
		Size = UDim2.fromOffset(28, 76),
		BackgroundTransparency = 1,
		Image = CAP_L,
		ImageColor3 = GOLD,
		ZIndex = 2,
	}, play)
	make("ImageLabel", {
		Name = "CapR",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(28, 76),
		BackgroundTransparency = 1,
		Image = CAP_R,
		ImageColor3 = GOLD,
		ZIndex = 2,
	}, play)
	text(
		play,
		"Label",
		"PLAY AGAIN",
		30,
		INK,
		{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(48, 38) }
	)
	keycap(
		play,
		"ENTER",
		62,
		28,
		{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromOffset(w - 40, 38) }
	)
	local function small(name: string, label: string, x: number, key: string?, extra: string?)
		local b = make("Frame", {
			Name = name,
			Position = UDim2.fromOffset(x, y + 88),
			Size = UDim2.fromOffset(194, 56),
			BackgroundColor3 = NAVY,
			BorderSizePixel = 0,
		}, c)
		make("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
		text(
			b,
			"Label",
			label,
			17,
			WHITE,
			{ Position = UDim2.fromOffset(16, if extra then 9 else 16) }
		)
		if extra then
			text(b, "Votes", extra, 11, ALLY, { Position = UDim2.fromOffset(16, 32) })
		end
		if key then
			keycap(
				b,
				key,
				30,
				30,
				{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromOffset(180, 28) }
			)
		end
	end
	small("Rematch", "REMATCH", right - w, "R", string.format("%d / %d VOTES", votes, needed))
	small("Leave", "LEAVE", right - 194, nil, nil)
end

-- 6. Name plates over the cheering winners (in the scene) ----------------------
local function plate(c: Instance, x: number, y: number, name: string, color: Color3, mvp: boolean)
	local s = strip(
		c,
		"Plate",
		34,
		{ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(x, y) }
	)
	teamBlock(s, 1, name, 15, color, 34, 12)
	if mvp then
		gap(s, 3, 8)
		make("ImageLabel", {
			Name = "Shard",
			LayoutOrder = 4,
			Size = UDim2.fromOffset(22, 22),
			BackgroundTransparency = 1,
			Image = SHARD,
			ImageColor3 = GOLD,
			ZIndex = 3,
		}, s)
		gap(s, 5, 4)
		text(s, "Mvp", "MVP", 12, GOLD, { LayoutOrder = 6 })
	end
	gap(s, 7, 12)
end

-- gui -----------------------------------------------------------------------------
local old = SG:FindFirstChild("MatchEndMockup")
if old then
	old:Destroy()
end
local gui = make("ScreenGui", {
	Name = "MatchEndMockup",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 9,
	Enabled = false,
})

do -- Victory, 2v2
	local c = canvas(gui, "CanvasVictory")
	headline(c, true, 5, 2)
	history(c, {
		{ tier = "SIDEARM", wins = { true, false } },
		{ tier = "LIGHT", wins = { true, true } },
		{ tier = "HEAVY", wins = { false, true, true } },
	})
	scoreboard(c, {
		{ name = "YOU", stats = { 9, 4, 3, 1720 }, mine = true, mvp = true },
		{ name = "NOVA", stats = { 6, 5, 4, 1380 } },
	}, {
		{ name = "BYTE", stats = { 6, 7, 1, 1410 } },
		{ name = "JINX", stats = { 3, 8, 2, 990 } },
	})
	build(c, {
		{ id = "Updraft", role = "Mobility", path = "High Rise", level = 3 },
		{ id = "Recall", role = "Escape", path = "Recharge", level = 2 },
		{ id = "Firewall", role = "Control", path = "Long Wall", level = 2 },
	})
	buttons(c, 2, 4)
	plate(c, 860, 470, "YOU", ALLY, true)
	plate(c, 1070, 470, "NOVA", ALLY, false)
end

do -- Defeat, 4v4
	local c = canvas(gui, "CanvasDefeat")
	c.Visible = false
	headline(c, false, 3, 5)
	history(c, {
		{ tier = "SIDEARM", wins = { true, true } },
		{ tier = "LIGHT", wins = { false, true } },
		{ tier = "HEAVY", wins = { false, false, false, false } },
	})
	scoreboard(c, {
		{ name = "YOU", stats = { 5, 6, 4, 1210 }, mine = true },
		{ name = "NOVA", stats = { 7, 5, 2, 1300 } },
		{ name = "KAI", stats = { 3, 6, 5, 870 } },
		{ name = "PATCH", stats = { 2, 7, 3, 640 } },
	}, {
		{ name = "BYTE", stats = { 10, 3, 2, 1880 }, mvp = true },
		{ name = "JINX", stats = { 6, 4, 5, 1290 } },
		{ name = "VEX", stats = { 5, 5, 3, 1100 } },
		{ name = "ORBIT", stats = { 3, 5, 6, 820 } },
	})
	build(c, {
		{ id = "Dash", role = "Mobility", path = "Long Dash", level = 2 },
		{ id = "Molly", role = "Damage", path = "Fork Fire", level = 3 },
		{ id = "Stim", role = "Team buff", path = "Quick Stims", level = 2 },
	})
	buttons(c, 1, 8)
	plate(c, 760, 470, "BYTE", ENEMY, true)
	plate(c, 920, 470, "JINX", ENEMY, false)
	plate(c, 1060, 470, "VEX", ENEMY, false)
	plate(c, 1200, 470, "ORBIT", ENEMY, false)
end

gui.Parent = SG
print("MatchEndMockup built")
