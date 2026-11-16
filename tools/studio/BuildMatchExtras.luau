--!strict
-- Builds the match UI extras (vault/02 Art/UI Match Extras.md) in the match place:
--   StarterGui.StatusTray        your effects + the Mod hint   <- Util/StatusTray
--   StarterGui.Scoreboard        hold Tab                      <- ScoreboardController
--   ReplicatedStorage.UiTemplates.Status.Entry, Scoreboard.{Header, Row, Chip},
--   Replay.FinalKill (cloned by ReplayController)
-- Studio owns them; this is their backup. Paste into the command bar (Edit
-- mode); refuses to run if they exist. Desktop only for now.
--
-- Same rule as the rest of the match UI: team-colour / gold blocks with a
-- slanted end joining navy, dark ink on bright blocks, Builder Extended,
-- keycaps; lists keep things from overlapping; pops scale from the centre.

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

local BX = "rbxassetid://12187365977" -- Rubik (UI Match Overhaul: was Builder Extended)
local XB = Enum.FontWeight.ExtraBold
local NAVY = hex("262629")
local ALLY, ENEMY = hex("3FE0F2"), hex("FF6B57")
local ALLY_CELL = hex("0D5C7A")
local GOLD, MUTED, INK, WHITE = hex("FFC83D"), hex("97979A"), hex("1A1A1D"), Color3.new(1, 1, 1)
local CAP_R = "rbxassetid://130377997107460"
local BOT_HEAD = "rbxassetid://119185654291939"
local SHARD = "rbxassetid://76745392849672"
local SKULL = "rbxassetid://113224984089670"
local SEG = "rbxassetid://82471388539509" -- status_seg.png: one of 24 ring segments
local CENTRE = Vector2.new(0.5, 0.5)
local SEGMENTS = 24

assert(not SG:FindFirstChild("StatusTray"), "StarterGui.StatusTray already exists")
assert(not SG:FindFirstChild("Scoreboard"), "StarterGui.Scoreboard already exists")

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

local function corner(p: Instance, r: number?)
	make("UICorner", { CornerRadius = UDim.new(0, r or 6) }, p)
end

local function circle(p: Instance)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, p)
end

local function hlist(p: Instance, pad: number, h: Enum.HorizontalAlignment?)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = h or Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, pad),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, p)
end

local function gap(p: Instance, order: number, w: number)
	make("Frame", {
		Name = "Gap" .. order,
		LayoutOrder = order,
		Size = UDim2.fromOffset(w, 2),
		BackgroundTransparency = 1,
	}, p)
end

local function strip(p: Instance, h: number, props: { [string]: any }): CanvasGroup
	local g = make("CanvasGroup", {
		Name = "Strip",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, h),
		BackgroundColor3 = NAVY,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, p)
	for k, v in props do
		(g :: any)[k] = v
	end
	corner(g)
	hlist(g, 0)
	return g
end

local function screen(name: string, order: number, enabled: boolean): ScreenGui
	return make("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = order,
		Enabled = enabled,
	})
end

-- Templates ---------------------------------------------------------------------
local templates = RS:FindFirstChild("UiTemplates") or make("Folder", { Name = "UiTemplates" }, RS)
for _, n in { "Status", "Scoreboard", "Replay" } do
	local old = templates:FindFirstChild(n)
	if old then
		old:Destroy()
	end
end

do -- Status.Entry: an icon in a navy disc, a 24-segment ring that drains, a tag
	local folder = make("Folder", { Name = "Status" }, templates)
	local holder = make(
		"Frame",
		{ Name = "Entry", Size = UDim2.fromOffset(76, 88), BackgroundTransparency = 1 },
		folder
	)
	local body = make("Frame", {
		Name = "Body",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(64, 64),
		BackgroundTransparency = 1,
	}, holder)
	make("UIScale", { Name = "Pop" }, body)
	local ring = make(
		"Frame",
		{ Name = "Ring", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 },
		body
	)
	for i = 1, SEGMENTS do
		make("ImageLabel", {
			Name = "Seg" .. i,
			AnchorPoint = CENTRE,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			Rotation = (i - 1) * (360 / SEGMENTS),
			BackgroundTransparency = 1,
			Image = SEG,
			ImageColor3 = ENEMY,
			ZIndex = 1,
		}, ring)
	end
	local disc = make("Frame", {
		Name = "Disc",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(48, 48),
		BackgroundColor3 = NAVY,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, body)
	circle(disc)
	make("ImageLabel", {
		Name = "Icon",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(30, 30),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, disc)
	local count = make("Frame", {
		Name = "Count",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 6, 1, 4),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
		ZIndex = 4,
		Visible = false,
	}, body)
	corner(count, 4)
	text(
		count,
		"Label",
		"2",
		11,
		INK,
		{ AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.fromScale(1, 1), ZIndex = 5 }
	)
	local tag = make("Frame", {
		Name = "Tag",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 68),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 18),
		BackgroundColor3 = NAVY,
		BorderSizePixel = 0,
	}, holder)
	corner(tag, 4)
	make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, tag)
	text(tag, "Label", "HINDERED", 10, WHITE, { Size = UDim2.fromOffset(0, 18) })
end

do -- Scoreboard: header, row, build chip
	local folder = make("Folder", { Name = "Scoreboard" }, templates)
	local W = 1040
	local COLS = { 470, 540, 610, 690 }
	local h = make("Frame", {
		Name = "Header",
		Size = UDim2.fromOffset(W, 34),
		BackgroundColor3 = NAVY,
		BorderSizePixel = 0,
	}, folder)
	corner(h)
	local block = make("Frame", {
		Name = "Team",
		Size = UDim2.fromOffset(170, 34),
		BackgroundColor3 = ALLY,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, h)
	corner(block)
	text(block, "Label", "YOUR TEAM", 14, INK, { Position = UDim2.fromOffset(14, 8) })
	make("ImageLabel", {
		Name = "Cap",
		Position = UDim2.fromOffset(166, 0),
		Size = UDim2.fromOffset(14, 34),
		BackgroundTransparency = 1,
		Image = CAP_R,
		ImageColor3 = ALLY,
		ZIndex = 2,
	}, h)
	for i, l in { "E", "D", "A", "DMG" } do
		text(
			h,
			"Col" .. i,
			l,
			11,
			MUTED,
			{ AnchorPoint = CENTRE, Position = UDim2.fromOffset(COLS[i], 17) }
		)
	end
	text(
		h,
		"ColBuild",
		"BUILD",
		11,
		MUTED,
		{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(770, 17) }
	)

	local holder = make(
		"Frame",
		{ Name = "Row", Size = UDim2.fromOffset(W, 46), BackgroundTransparency = 1 },
		folder
	)
	local body = make("CanvasGroup", {
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = NAVY,
		BorderSizePixel = 0,
	}, holder)
	corner(body)
	local cell = make("Frame", {
		Name = "Cell",
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = ALLY_CELL,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, body)
	corner(cell)
	make("ImageLabel", {
		Name = "Headshot",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = BOT_HEAD,
		ZIndex = 3,
	}, cell)
	local line = make("Frame", {
		Name = "NameLine",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 60, 0.5, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 26),
		BackgroundTransparency = 1,
	}, body)
	hlist(line, 8)
	text(line, "PlayerName", "PLAYER", 16, ALLY, { LayoutOrder = 1 })
	make("ImageLabel", {
		Name = "Shard",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(22, 22),
		BackgroundTransparency = 1,
		Image = SHARD,
		ImageColor3 = GOLD,
		ZIndex = 3,
		Visible = false,
	}, line)
	make("ImageLabel", {
		Name = "Dead",
		LayoutOrder = 3,
		Size = UDim2.fromOffset(18, 18),
		BackgroundTransparency = 1,
		Image = SKULL,
		ImageColor3 = MUTED,
		ZIndex = 3,
		Visible = false,
	}, line)
	for i = 1, 4 do
		text(
			body,
			"Stat" .. i,
			"0",
			17,
			WHITE,
			{ AnchorPoint = CENTRE, Position = UDim2.new(0, COLS[i], 0.5, 0) }
		)
	end
	local build = make("Frame", {
		Name = "Build",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 770, 0.5, 0),
		Size = UDim2.fromOffset(250, 36),
		BackgroundTransparency = 1,
	}, body)
	hlist(build, 6)

	local chip = make("Frame", {
		Name = "Chip",
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = ALLY,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, folder)
	corner(chip)
	make("ImageLabel", {
		Name = "Icon",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(24, 24),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, chip)
	text(
		chip,
		"Level",
		"1",
		10,
		INK,
		{ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -2, 1, 1), ZIndex = 4 }
	)
end

do -- Replay.FinalKill: the gold FINAL KILL block, killer, weapon, victim
	local folder = make("Folder", { Name = "Replay" }, templates)
	local holder = make("Frame", {
		Name = "FinalKill",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.95),
		Size = UDim2.fromOffset(900, 60),
		BackgroundTransparency = 1,
	}, folder)
	local s = strip(holder, 56, { AnchorPoint = CENTRE, Position = UDim2.fromScale(0.5, 0.5) })
	local b = make("Frame", {
		Name = "Kicker",
		LayoutOrder = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 56),
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, s)
	make("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 6) }, b)
	text(
		b,
		"Label",
		"FINAL KILL",
		18,
		INK,
		{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5) }
	)
	make("ImageLabel", {
		Name = "Cap",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(24, 56),
		BackgroundTransparency = 1,
		Image = CAP_R,
		ImageColor3 = GOLD,
		ZIndex = 2,
	}, s)
	gap(s, 3, 18)
	text(s, "Killer", "KILLER", 22, ALLY, { LayoutOrder = 4 })
	gap(s, 5, 16)
	make("ImageLabel", {
		Name = "Weapon",
		LayoutOrder = 6,
		Size = UDim2.fromOffset(96, 30),
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 3,
	}, s)
	gap(s, 7, 12)
	make("ImageLabel", {
		Name = "Head",
		LayoutOrder = 8,
		Size = UDim2.fromOffset(20, 20),
		BackgroundTransparency = 1,
		Image = SKULL,
		ImageColor3 = GOLD,
		ZIndex = 3,
		Visible = false,
	}, s)
	gap(s, 9, 12)
	text(s, "Victim", "VICTIM", 22, ENEMY, { LayoutOrder = 10 })
	gap(s, 11, 22)
end

-- StarterGui.StatusTray: the Mod hint over a centred row of effects, just above
-- the Mod cells (the script anchors it to the bottom like the bottom HUD).
do
	local gui = screen("StatusTray", 6, true)
	local holder = make("Frame", {
		Name = "Holder",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.965, -114),
		Size = UDim2.fromOffset(900, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, gui)
	make("UIScale", { Name = "Fit" }, holder)
	make("UIListLayout", {
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, holder)
	local hint = make("Frame", {
		Name = "Hint",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(900, 32),
		BackgroundTransparency = 1,
		Visible = false,
	}, holder)
	local plate = make("Frame", {
		Name = "Plate",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 32),
		BackgroundColor3 = NAVY,
		BorderSizePixel = 0,
	}, hint)
	corner(plate)
	make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, plate)
	text(
		plate,
		"Label",
		"HOLD TO AIM",
		14,
		WHITE,
		{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5) }
	)
	local row = make("Frame", {
		Name = "Row",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(900, 88),
		BackgroundTransparency = 1,
		Visible = false,
	}, holder)
	hlist(row, 10, Enum.HorizontalAlignment.Center)
	gui.Parent = SG
end

-- StarterGui.Scoreboard: hold Tab. A centred panel: the round and score, then
-- each team's header and rows (the script fills them).
do
	local gui = screen("Scoreboard", 12, false)
	make("Frame", {
		Name = "Dim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = hex("0A0A0D"),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
	}, gui)
	local c = make("Frame", {
		Name = "Canvas",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(1920, 1080),
		BackgroundTransparency = 1,
	}, gui)
	make("UIScale", { Name = "Fit" }, c)
	local panel = make("Frame", {
		Name = "Panel",
		AnchorPoint = CENTRE,
		Position = UDim2.fromOffset(960, 540),
		Size = UDim2.fromOffset(1040, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, c)
	make("UIScale", { Name = "Pop" }, panel)
	make(
		"UIListLayout",
		{ Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder },
		panel
	)
	local top = make("Frame", {
		Name = "Top",
		LayoutOrder = 0,
		Size = UDim2.fromOffset(1040, 56),
		BackgroundColor3 = NAVY,
		BorderSizePixel = 0,
	}, panel)
	corner(top)
	text(
		top,
		"Title",
		"SCOREBOARD",
		22,
		WHITE,
		{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 20, 0.5, 0) }
	)
	text(
		top,
		"Round",
		"ROUND 1  ·  SIDEARM",
		12,
		MUTED,
		{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 260, 0.5, 2) }
	)
	local score = make("Frame", {
		Name = "Score",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -20, 0.5, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 40),
		BackgroundTransparency = 1,
	}, top)
	hlist(score, 12)
	text(score, "Us", "0", 30, ALLY, { LayoutOrder = 1 })
	text(score, "Dash", "·", 22, MUTED, { LayoutOrder = 2 })
	text(score, "Them", "0", 30, ENEMY, { LayoutOrder = 3 })
	make("Frame", {
		Name = "TopGap",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(10, 8),
		BackgroundTransparency = 1,
	}, panel)
	gui.Parent = SG
end

print("Match extras built")
