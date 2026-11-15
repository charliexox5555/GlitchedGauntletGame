--!strict
-- Builds the kill feed, the kill pop, the killed-by card and the spectate bar
-- (vault/02 Art/UI Feed and Spectate.md) in the match place:
--   ReplicatedStorage.UiTemplates.KillFeed.Row  (one feed row)
--   StarterGui.KillFeed     (Feed list + KillPop)      <- KillFeedController
--   StarterGui.DeathScreen  (KilledBy + Spectate)      <- Util/DeathScreen
-- Studio owns them; this is their backup. Paste into the command bar (Edit
-- mode); refuses to run if they exist. Desktop only for now.
--
-- One rule: a team-colour block with a slanted end joining a navy plate, dark
-- ink on the bright block, Builder Extended ExtraBold. Strips size to their
-- content (UIListLayout + AutomaticSize); the scripts size each Shadow from
-- its Strip. Animated holders are centre-anchored with a "Pop" UIScale.

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
local SHADOW = "rbxassetid://121253415859134"
local CAP_R = "rbxassetid://130377997107460"
local SKULL = "rbxassetid://113224984089670"
local BOT_HEAD = "rbxassetid://119185654291939"
local SHARD = "rbxassetid://76745392849672"
local RING_SEG = "rbxassetid://136514326667794"
local WAVE = "rbxassetid://128750671180422" -- kill_wave.png: the shockwave ring
local PREVIEW_GUN = "" -- filled in play
local CENTRE = Vector2.new(0.5, 0.5)

assert(not SG:FindFirstChild("KillFeed"), "StarterGui.KillFeed already exists")
assert(not SG:FindFirstChild("DeathScreen"), "StarterGui.DeathScreen already exists")

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

local function shadow(p: Instance)
	make("ImageLabel", {
		Name = "Shadow",
		BackgroundTransparency = 1,
		Image = SHADOW,
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 0.4,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(48, 48, 80, 80),
		ZIndex = 0,
	}, p)
end

local function keycap(
	p: Instance,
	name: string,
	s: string,
	w: number,
	h: number,
	order: number
): TextButton
	local k = make("TextButton", {
		Name = name,
		LayoutOrder = order,
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = hex("0B0F17"),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 8,
	}, p)
	make("UICorner", { CornerRadius = UDim.new(0, 5) }, k)
	local f = make("Frame", {
		Name = "Face",
		Size = UDim2.new(1, 0, 1, -4),
		BackgroundColor3 = hex("E9EDF3"),
		BorderSizePixel = 0,
		ZIndex = 9,
	}, k)
	make("UICorner", { CornerRadius = UDim.new(0, 5) }, f)
	make("TextLabel", {
		Name = "Label",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = s,
		FontFace = Font.new(BX, XB),
		TextSize = math.floor(h * 0.46),
		TextColor3 = INK,
		ZIndex = 10,
	}, f)
	return k
end

-- A navy strip whose items sit in a row (it sizes to them).
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
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, g)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, g)
	return g
end

-- The team-colour block (kicker + name in dark ink) and its slanted end.
local function teamBlock(
	p: Instance,
	order: number,
	s: string,
	size: number,
	color: Color3,
	h: number,
	padL: number,
	kicker: string?
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
	make("UIPadding", { PaddingLeft = UDim.new(0, padL), PaddingRight = UDim.new(0, 4) }, b)
	if kicker then
		text(
			b,
			"Kicker",
			kicker,
			11,
			INK,
			{ Position = UDim2.new(0, 0, 0.5, -size / 2 - 12), TextTransparency = 0.25 }
		)
	end
	text(b, "Label", s, size, INK, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, if kicker then 7 else 0),
	})
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

local function gap(p: Instance, name: string, order: number, w: number)
	make("Frame", {
		Name = name,
		LayoutOrder = order,
		Size = UDim2.fromOffset(w, 2),
		BackgroundTransparency = 1,
	}, p)
end

local function cell(p: Instance, size: number, color: Color3)
	local f = make("Frame", {
		Name = "Cell",
		LayoutOrder = 0,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, p)
	make("ImageLabel", {
		Name = "Headshot",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = BOT_HEAD,
		ZIndex = 3,
	}, f)
end

local function screen(name: string, order: number): (ScreenGui, Frame)
	local gui = make("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = order,
	})
	local c = make("Frame", {
		Name = "Canvas",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(1920, 1080),
		BackgroundTransparency = 1,
	}, gui)
	make("UIScale", { Name = "Fit" }, c)
	return gui, c
end

-- Feed row template -------------------------------------------------------------
local templates = RS:FindFirstChild("UiTemplates") or make("Folder", { Name = "UiTemplates" }, RS)
local folder = templates:FindFirstChild("KillFeed")
	or make("Folder", { Name = "KillFeed" }, templates)
local oldRow = folder:FindFirstChild("Row")
if oldRow then
	oldRow:Destroy()
end
do
	-- A fixed full-width holder in the list; the Strip is right-aligned in it
	-- and slides in from the right.
	local holder = make(
		"Frame",
		{ Name = "Row", Size = UDim2.fromOffset(560, 38), BackgroundTransparency = 1 },
		folder
	)
	local row =
		strip(holder, 38, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5) })
	teamBlock(row, 1, "KILLER", 14, ALLY, 38, 14)
	gap(row, "Gap1", 3, 6)
	make("ImageLabel", {
		Name = "Weapon",
		LayoutOrder = 4,
		Size = UDim2.fromOffset(78, 26),
		BackgroundTransparency = 1,
		Image = PREVIEW_GUN,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 3,
	}, row)
	gap(row, "Gap2", 5, 10)
	make("ImageLabel", {
		Name = "Head",
		LayoutOrder = 6,
		Size = UDim2.fromOffset(18, 18),
		BackgroundTransparency = 1,
		Image = SKULL,
		ImageColor3 = GOLD,
		ZIndex = 3,
		Visible = false,
	}, row)
	gap(row, "Gap3", 7, 10)
	text(row, "Victim", "VICTIM", 14, ENEMY, { LayoutOrder = 8 })
	gap(row, "Gap4", 9, 14)
end

-- StarterGui.KillFeed -----------------------------------------------------------
do
	local gui, c = screen("KillFeed", 6)
	local feed = make("Frame", {
		Name = "Feed",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromOffset(1880, 112),
		Size = UDim2.fromOffset(560, 4 * 44),
		BackgroundTransparency = 1,
	}, c)
	make("UIListLayout", {
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, feed)
	-- The kill pop (low centre, above the Mod cells): a disc with the glitch
	-- shard, ringed by 5 kill segments (in "Ring", which spins in), a "Flash" on
	-- the disc and a "Wave" ring that bursts outward on impact.
	local pop = make("Frame", {
		Name = "KillPop",
		AnchorPoint = CENTRE,
		Position = UDim2.fromOffset(960, 790),
		Size = UDim2.fromOffset(150, 150),
		BackgroundTransparency = 1,
		Visible = false,
	}, c)
	make("UIScale", { Name = "Pop" }, pop)
	local group = make(
		"CanvasGroup",
		{ -- room around the ring: a CanvasGroup clips, and the new segment pops out
			Name = "Group",
			AnchorPoint = CENTRE,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1.3, 1.3),
			BackgroundTransparency = 1,
		},
		pop
	)
	make("ImageLabel", {
		Name = "Wave",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = WAVE,
		ImageTransparency = 1,
		ZIndex = 0,
	}, pop)
	local ring = make("Frame", { -- each segment spins in on its own
		Name = "Ring",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(150, 150),
		BackgroundTransparency = 1,
		ZIndex = 1,
	}, group)
	for i = 1, 5 do
		make("ImageLabel", {
			Name = "Seg" .. i,
			AnchorPoint = CENTRE,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			Rotation = (i - 1) * 72,
			BackgroundTransparency = 1,
			Image = RING_SEG,
			ImageColor3 = WHITE,
			ImageTransparency = 0.7,
			ZIndex = 1,
		}, ring)
	end
	local disc = make("Frame", {
		Name = "Disc",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(112, 112),
		BackgroundColor3 = NAVY,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, group)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, disc)
	local flash = make("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, disc)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, flash)
	for _, s in { { "SplitA", hex("00E5FF"), -4 }, { "SplitB", hex("FF8BE0"), 4 } } do
		make("ImageLabel", {
			Name = s[1],
			AnchorPoint = CENTRE,
			Position = UDim2.new(0.5, s[3], 0.5, 0),
			Size = UDim2.fromOffset(98, 98),
			BackgroundTransparency = 1,
			Image = SHARD,
			ImageColor3 = s[2],
			ZIndex = 3,
		}, disc)
	end
	make("ImageLabel", {
		Name = "Emblem",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(98, 98),
		BackgroundTransparency = 1,
		Image = SHARD,
		ImageColor3 = WHITE,
		ZIndex = 4,
	}, disc)
	gui.Parent = SG
end

-- StarterGui.DeathScreen --------------------------------------------------------
do
	local gui, c = screen("DeathScreen", 7)
	-- Killed by: during the death camera.
	local kb = make("Frame", {
		Name = "KilledBy",
		AnchorPoint = CENTRE,
		Position = UDim2.fromOffset(960, 856),
		Size = UDim2.fromOffset(800, 72),
		BackgroundTransparency = 1,
		Visible = false,
	}, c)
	make("UIScale", { Name = "Pop" }, kb)
	shadow(kb)
	local s =
		strip(kb, 72, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	cell(s, 72, ENEMY_CELL)
	teamBlock(s, 1, "KILLER", 28, ENEMY, 72, 18, "KILLED BY")
	gap(s, "Gap1", 3, 14)
	make("ImageLabel", {
		Name = "Weapon",
		LayoutOrder = 4,
		Size = UDim2.fromOffset(120, 44),
		BackgroundTransparency = 1,
		Image = PREVIEW_GUN,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 3,
	}, s)
	gap(s, "Gap2", 5, 14)
	local info = make("Frame", {
		Name = "Info",
		LayoutOrder = 6,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 72),
		BackgroundTransparency = 1,
	}, s)
	make("UIListLayout", {
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 2),
	}, info)
	text(info, "Gun", "GUN", 16, WHITE, { LayoutOrder = 1 })
	text(info, "Head", "HEADSHOT", 12, GOLD, { LayoutOrder = 2 })
	gap(s, "Gap3", 7, 22)
	local hp = make("Frame", {
		Name = "HP",
		LayoutOrder = 8,
		Size = UDim2.fromOffset(92, 72),
		BackgroundColor3 = NAVY_HI,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, s)
	text(
		hp,
		"Value",
		"100",
		28,
		WHITE,
		{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(46, 10) }
	)
	text(
		hp,
		"Unit",
		"HP LEFT",
		11,
		MUTED,
		{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(46, 44) }
	)
	-- The combat report under the card: what you did to them, and took.
	local report = make("Frame", {
		Name = "Report",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 10),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30),
		BackgroundColor3 = NAVY,
		BorderSizePixel = 0,
		Visible = false,
	}, kb)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, report)
	make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, report)
	text(report, "Label", "YOU DEALT 0  ·  TOOK 0", 13, MUTED, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		RichText = true,
	})

	-- Spectating: keycaps either side of the strip.
	local sp = make("Frame", {
		Name = "Spectate",
		AnchorPoint = CENTRE,
		Position = UDim2.fromOffset(960, 856),
		Size = UDim2.fromOffset(800, 64),
		BackgroundTransparency = 1,
		Visible = false,
	}, c)
	make("UIScale", { Name = "Pop" }, sp)
	shadow(sp)
	local row = make("Frame", {
		Name = "Row",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 64),
		BackgroundTransparency = 1,
	}, sp)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 14),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)
	keycap(row, "Prev", "<", 40, 42, 1)
	local st = strip(row, 64, { LayoutOrder = 2 })
	cell(st, 64, ALLY_CELL)
	teamBlock(st, 1, "PLAYER", 24, ALLY, 64, 16, "SPECTATING")
	gap(st, "Gap1", 3, 12)
	local health = make("Frame", {
		Name = "Health",
		LayoutOrder = 4,
		Size = UDim2.fromOffset(150, 64),
		BackgroundTransparency = 1,
	}, st)
	text(health, "Value", "100", 22, WHITE, { Position = UDim2.fromOffset(0, 10) })
	text(health, "Unit", "HP", 11, MUTED, { Position = UDim2.fromOffset(48, 19) })
	local bar = make("Frame", {
		Name = "Bar",
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.fromOffset(138, 6),
		BackgroundTransparency = 1,
	}, health)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, bar)
	for i = 1, 10 do
		make("Frame", {
			Name = "Seg" .. i,
			LayoutOrder = i,
			Size = UDim2.fromOffset(12, 6),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
		}, bar)
	end
	gap(st, "Gap2", 5, 12)
	keycap(row, "Next", ">", 40, 42, 3)
	gui.Parent = SG
end

print("KillFeed + DeathScreen built")
