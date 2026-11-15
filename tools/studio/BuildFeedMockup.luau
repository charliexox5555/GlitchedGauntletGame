--!strict
-- Mockup: kill feed, ELIMINATED pop, killed-by card and spectate bar in the
-- match UI style (top bar / draft: team-colour blocks with a slanted end that
-- joins a navy plate, Builder Extended, keycaps, soft shadows; no outlines,
-- edge strips, pills, glows or gradients). vault/02 Art/UI Feed and Spectate.md
-- Paste into the Studio command bar (Edit mode). Builds StarterGui.FeedMockup
-- (Enabled off) with two canvases: CanvasDeath (feed + killed-by) and
-- CanvasSpectate (feed + spectate bar), and CanvasKill (the kill pop options).

local SG = game:GetService("StarterGui")

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
local XB, SB = Enum.FontWeight.ExtraBold, Enum.FontWeight.SemiBold
local NAVY, NAVY_HI = hex("1C2740"), hex("2B3A5A")
local ALLY, ENEMY = hex("3FE0F2"), hex("FF6B57")
local ALLY_CELL, ENEMY_CELL = hex("0D5C7A"), hex("8A1C24")
local GOLD, MUTED, INK, WHITE = hex("FFC83D"), hex("8E98A8"), hex("141A26"), Color3.new(1, 1, 1)
local SHADOW = "rbxassetid://121253415859134"
local CAP_R = "rbxassetid://130377997107460"
local SKULL = "rbxassetid://113224984089670"
local BOT_HEAD = "rbxassetid://119185654291939"
local GUN = {
	Sheriff = "rbxassetid://0",
}
do
	local ok, Theme = pcall(function()
		return require(game.ReplicatedStorage.Shared.Config.Theme) :: any
	end)
	if ok then
		GUN = Theme.GUN
	end
end
local MOLLY_ICON = ""
do
	local ok, Mods = pcall(function()
		return require(game.ReplicatedStorage.Shared.Config.Mods) :: any
	end)
	if ok then
		MOLLY_ICON = Mods.defs.Molly.icon
	end
end
local CENTRE = Vector2.new(0.5, 0.5)

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

local function shadow(p: Instance, pad: number)
	make("ImageLabel", {
		Name = "Shadow",
		AnchorPoint = CENTRE,
		Position = UDim2.new(0.5, 0, 0.5, 8),
		Size = UDim2.new(1, pad, 1, pad),
		BackgroundTransparency = 1,
		Image = SHADOW,
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 0.4,
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

-- A horizontal strip: navy plate (CanvasGroup) whose items sit in a row.
local function strip(
	p: Instance,
	name: string,
	h: number,
	fill: Color3,
	props: { [string]: any }
): CanvasGroup
	local g = make("CanvasGroup", {
		Name = name,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, h),
		BackgroundColor3 = fill,
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

-- A team-colour block (with its name) and the slanted end that joins the navy.
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
	-- Dark ink on the bright block (keycap rule): readable at feed size.
	if kicker then
		text(b, "Kicker", kicker, 11, INK, {
			Position = UDim2.new(0, 0, 0.5, -size / 2 - 12),
			TextTransparency = 0.25,
		})
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

local function gap(p: Instance, order: number, w: number)
	make("Frame", {
		Name = "Gap",
		LayoutOrder = order,
		Size = UDim2.fromOffset(w, 2),
		BackgroundTransparency = 1,
	}, p)
end

-- One kill feed row, right-aligned at (x, y).
local function feedRow(
	c: Instance,
	y: number,
	killer: string,
	kColor: Color3,
	weapon: string,
	isMod: boolean,
	head: boolean,
	victim: string,
	vColor: Color3,
	mine: boolean
)
	local holder = make("Frame", {
		Name = "Row",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromOffset(1880, y),
		Size = UDim2.fromOffset(560, 38),
		BackgroundTransparency = 1,
	}, c)
	local row = strip(
		holder,
		"Strip",
		38,
		if mine then NAVY_HI else NAVY,
		{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5) }
	)
	teamBlock(row, 1, killer, 14, kColor, 38, 14)
	gap(row, 3, 6)
	make("ImageLabel", {
		Name = "Weapon",
		LayoutOrder = 4,
		Size = UDim2.fromOffset(if isMod then 24 else 78, if isMod then 24 else 26),
		BackgroundTransparency = 1,
		Image = weapon,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 3,
	}, row)
	gap(row, 5, 10)
	if head then
		make("ImageLabel", {
			Name = "Head",
			LayoutOrder = 6,
			Size = UDim2.fromOffset(18, 18),
			BackgroundTransparency = 1,
			Image = SKULL,
			ImageColor3 = GOLD,
			ZIndex = 3,
		}, row)
		gap(row, 7, 10)
	end
	text(row, "Victim", victim, 14, vColor, { LayoutOrder = 8 })
	gap(row, 9, 14)
end

local function feed(c: Instance)
	local g = GUN
	feedRow(c, 112, "YOU", ALLY, g.Sheriff or "", false, true, "BYTE", ENEMY, true)
	feedRow(c, 156, "NOVA", ALLY, MOLLY_ICON, true, false, "RIVET", ENEMY, false)
	feedRow(c, 200, "BYTE", ENEMY, g.Ghost or "", false, false, "YOU", ALLY, true)
end

-- A player cell (the top bar's): team-dark square with the headshot.
local function cell(p: Instance, order: number, size: number, color: Color3)
	local f = make("Frame", {
		Name = "Cell",
		LayoutOrder = order,
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

-- gui -----------------------------------------------------------------------------
local old = SG:FindFirstChild("FeedMockup")
if old then
	old:Destroy()
end
local gui = make("ScreenGui", {
	Name = "FeedMockup",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 7,
	Enabled = false,
})
local function canvas(name: string): Frame
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

-- Death: the feed + who killed you (bottom centre, during the death camera)
local death = canvas("CanvasDeath")
feed(death)
do
	local holder = make("Frame", {
		Name = "KilledBy",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(960, 820),
		Size = UDim2.fromOffset(700, 120),
		BackgroundTransparency = 1,
	}, death)
	local s = strip(
		holder,
		"Strip",
		72,
		NAVY,
		{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(350, 24) }
	)
	cell(s, 0, 72, ENEMY_CELL)
	teamBlock(s, 1, "BYTE", 28, ENEMY, 72, 18, "KILLED BY")
	gap(s, 3, 14)
	make("ImageLabel", {
		Name = "Weapon",
		LayoutOrder = 4,
		Size = UDim2.fromOffset(120, 44),
		BackgroundTransparency = 1,
		Image = GUN.Ghost or "",
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 3,
	}, s)
	gap(s, 5, 14)
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
	text(info, "Gun", "GHOST", 16, WHITE, { LayoutOrder = 1 })
	text(info, "Head", "HEADSHOT", 12, GOLD, { LayoutOrder = 2 })
	gap(s, 7, 22)
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
		"64",
		28,
		WHITE,
		{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(46, 10), ZIndex = 4 }
	)
	text(
		hp,
		"Unit",
		"HP LEFT",
		11,
		MUTED,
		{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(46, 44), ZIndex = 4 }
	)
end

-- Spectating: the feed, your ELIMINATED pop, and the spectate bar
local spec = canvas("CanvasSpectate")
feed(spec)
do -- the spectate bar (bottom centre)
	local holder = make("Frame", {
		Name = "Spectate",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(960, 830),
		Size = UDim2.fromOffset(700, 110),
		BackgroundTransparency = 1,
	}, spec)
	local row = make("Frame", {
		Name = "Row",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(350, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 64),
		BackgroundTransparency = 1,
	}, holder)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 14),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)
	keycap(row, "<", 40, 42, { Name = "Prev", LayoutOrder = 1 })
	local s = strip(row, "Strip", 64, NAVY, { LayoutOrder = 2 })
	cell(s, 0, 64, ALLY_CELL)
	teamBlock(s, 1, "NOVA", 24, ALLY, 64, 16, "SPECTATING")
	gap(s, 3, 12)
	local hp = make("Frame", {
		Name = "Health",
		LayoutOrder = 4,
		Size = UDim2.fromOffset(150, 64),
		BackgroundTransparency = 1,
	}, s)
	text(hp, "Value", "86", 22, WHITE, { Position = UDim2.fromOffset(0, 10), ZIndex = 4 })
	text(hp, "Unit", "HP", 11, MUTED, { Position = UDim2.fromOffset(40, 19), ZIndex = 4 })
	local bar = make("Frame", {
		Name = "Bar",
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.fromOffset(136, 6),
		BackgroundTransparency = 1,
	}, hp)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, bar)
	for i = 1, 10 do
		make("Frame", {
			Name = "Seg" .. i,
			LayoutOrder = i,
			Size = UDim2.fromOffset(11.8, 6),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = if i <= 9 then 0 else 0.86,
			BorderSizePixel = 0,
		}, bar)
	end
	gap(s, 5, 12)
	keycap(row, ">", 40, 42, { Name = "Next", LayoutOrder = 3 })
	text(holder, "Hint", "CLICK FOR THE NEXT PLAYER", 11, MUTED, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(350, 96),
		FontFace = Font.new(BX, SB),
	})
end

-- The kill pop (your kill, just under the crosshair; Valorant-style): a disc
-- with an emblem, ringed by 5 segments, one lit per kill this round. Gold on a
-- headshot. No words.
local SWORD, BLADES, SHARD =
	"rbxassetid://123591008906340", "rbxassetid://98763575799680", "rbxassetid://76745392849672"
local RING_SEG = "rbxassetid://136514326667794"
local function killPop(
	c: Instance,
	x: number,
	y: number,
	emblem: string,
	kills: number,
	head: boolean,
	glitch: boolean,
	caption: string
)
	local holder = make(
		"Frame",
		{
			Name = "KillPop",
			AnchorPoint = CENTRE,
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(150, 150),
			BackgroundTransparency = 1,
		},
		c
	)
	local lit = if head then GOLD else ENEMY
	for i = 1, 5 do
		make("ImageLabel", {
			Name = "Seg" .. i,
			AnchorPoint = CENTRE,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			Rotation = (i - 1) * 72,
			BackgroundTransparency = 1,
			Image = RING_SEG,
			ImageColor3 = if i <= kills then lit else WHITE,
			ImageTransparency = if i <= kills then 0 else 0.7,
			ZIndex = 1,
		}, holder)
	end
	local disc = make(
		"Frame",
		{
			Name = "Disc",
			AnchorPoint = CENTRE,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(112, 112),
			BackgroundColor3 = NAVY,
			BorderSizePixel = 0,
			ZIndex = 2,
		},
		holder
	)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, disc)
	if glitch then -- the colour split, like the glitched draft title
		for _, g in { { hex("00E5FF"), -4 }, { hex("FF8BE0"), 4 } } do
			make(
				"ImageLabel",
				{
					Name = "Split",
					AnchorPoint = CENTRE,
					Position = UDim2.new(0.5, g[2], 0.5, 0),
					Size = UDim2.fromOffset(98, 98),
					BackgroundTransparency = 1,
					Image = emblem,
					ImageColor3 = g[1],
					ZIndex = 3,
				},
				disc
			)
		end
	end
	make(
		"ImageLabel",
		{
			Name = "Emblem",
			AnchorPoint = CENTRE,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(98, 98),
			BackgroundTransparency = 1,
			Image = emblem,
			ImageColor3 = if head then GOLD else WHITE,
			ZIndex = 4,
		},
		disc
	)
	make("UIScale", { Name = "Pop" }, holder)
	text(
		c,
		"Caption",
		caption,
		12,
		WHITE,
		{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(x, y + 92) }
	)
end

local killC = canvas("CanvasKill")
killPop(killC, 660, 600, SWORD, 1, false, false, "A  SWORD  ·  1ST KILL")
killPop(killC, 960, 600, BLADES, 3, false, false, "B  CROSSED BLADES  ·  3RD KILL")
killPop(killC, 1260, 600, SHARD, 2, true, true, "C  GLITCH SHARD  ·  HEADSHOT, 2ND")

gui.Parent = SG
print("FeedMockup built")
