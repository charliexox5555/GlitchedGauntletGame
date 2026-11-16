--!strict
-- Builds the map vote screen (vault/02 Art/UI Match Overhaul.md) in the match place:
--   StarterGui.MapVote                     <- Controllers/MapVoteController
--   ReplicatedStorage.UiTemplates.MapVote  (Slot = a grid cell holding the Card, Head = a voter)
-- Studio owns them; this is their backup. Run in Edit (command bar or MCP);
-- refuses to run if they exist.
--
-- Look: the new theme (Rubik Heavy / Bold, neutral charcoal, one gold thing).
-- Layout after RIVALS' vote (Random first, a grid of map cards, voters'
-- heads on each card, % chance), our own art. A card is a fixed grid cell
-- ("Slot") with a centred inner Card carrying a "Pop" UIScale, so pops
-- scale from the centre. Cards have a Picture slot for map art later (hidden
-- while a map has none).

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

local RUBIK = "rbxassetid://12187365977"
local HEAVY = Font.new(RUBIK, Enum.FontWeight.Heavy)
local BOLD = Font.new(RUBIK, Enum.FontWeight.Bold)
local WHITE = Color3.new(1, 1, 1)
local MUTED = hex("A9A9B0")
local CARD = hex("1E1E24")
local FOOT = hex("2A2A31")
local GOLD = hex("FFD700")
local CENTRE = Vector2.new(0.5, 0.5)
local DESIGN = Vector2.new(1920, 1080)
local CELL = Vector2.new(360, 216)
local GAP = 24

assert(not SG:FindFirstChild("MapVote"), "StarterGui.MapVote already exists")

local function outline(t: TextLabel, transparency: number)
	make("UIStroke", {
		Name = "Outline",
		Color = Color3.new(0, 0, 0),
		Transparency = transparency,
		Thickness = 2.5,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, t)
end

local function text(
	p: Instance,
	name: string,
	s: string,
	font: Font,
	size: number,
	color: Color3,
	props: { [string]: any }?
): TextLabel
	local t = make("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, size + 6),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = s,
		FontFace = font,
		TextSize = size,
		TextColor3 = color,
		ZIndex = 5,
	}, p)
	for k, v in props or {} do
		(t :: any)[k] = v
	end
	return t
end

-- Screen ----------------------------------------------------------------------
local gui = make("ScreenGui", {
	Name = "MapVote",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 40,
	Enabled = false,
})
local backdrop = make("Frame", {
	Name = "Backdrop",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = hex("101013"),
	BorderSizePixel = 0,
	ZIndex = 1,
}, gui)
make("UIGradient", {
	Name = "Vignette",
	Rotation = 90,
	Color = ColorSequence.new(hex("1A1A1F"), hex("0B0B0D")),
}, backdrop)

local canvas = make("Frame", {
	Name = "Canvas",
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(DESIGN.X, DESIGN.Y),
	BackgroundTransparency = 1,
	ZIndex = 2,
}, gui)
make("UIScale", { Name = "Fit" }, canvas)

-- Header: title, the match line, the clock
local head = make("Frame", {
	Name = "Head",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromOffset(DESIGN.X / 2, 92),
	Size = UDim2.fromOffset(1200, 150),
	BackgroundTransparency = 1,
	ZIndex = 3,
}, canvas)
local title = text(head, "Title", "VOTE FOR A MAP", HEAVY, 56, WHITE, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0),
})
outline(title, 0.45)
text(head, "Sub", "1V1  ·  FIRST TO 5", BOLD, 20, MUTED, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 70),
})
local clock = make("Frame", {
	Name = "Clock",
	AnchorPoint = CENTRE,
	Position = UDim2.new(0.5, 0, 0, 142),
	Size = UDim2.fromOffset(64, 64),
	BackgroundColor3 = CARD,
	ZIndex = 4,
}, head)
make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, clock)
make("UIStroke", { Name = "Ring", Color = WHITE, Thickness = 3, Transparency = 0.15 }, clock)
text(clock, "Seconds", "12", HEAVY, 28, WHITE, {
	AutomaticSize = Enum.AutomaticSize.None,
	Size = UDim2.fromScale(1, 1),
})

-- The grid of cards
local cards = make("Frame", {
	Name = "Cards",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromOffset(DESIGN.X / 2, 300),
	Size = UDim2.fromOffset(CELL.X * 3 + GAP * 2, CELL.Y * 3 + GAP * 2),
	BackgroundTransparency = 1,
	ZIndex = 3,
}, canvas)
make("UIGridLayout", {
	CellSize = UDim2.fromOffset(CELL.X, CELL.Y),
	CellPadding = UDim2.fromOffset(GAP, GAP),
	FillDirectionMaxCells = 3,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Top,
	SortOrder = Enum.SortOrder.LayoutOrder,
}, cards)

-- Hint under the grid
text(canvas, "Hint", "CLICK A MAP TO VOTE  ·  EVERY VOTE IS A TICKET", BOLD, 16, MUTED, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromOffset(DESIGN.X / 2, DESIGN.Y - 48),
	ZIndex = 3,
})

-- Templates -------------------------------------------------------------------
local folder = RS:FindFirstChild("UiTemplates") or make("Folder", { Name = "UiTemplates" }, RS)
assert(not folder:FindFirstChild("MapVote"), "UiTemplates.MapVote already exists")
local tf = make("Folder", { Name = "MapVote" }, folder)

local slot = make("Frame", {
	Name = "Slot",
	Size = UDim2.fromOffset(CELL.X, CELL.Y),
	BackgroundTransparency = 1,
}, tf)
local card = make("TextButton", {
	Name = "Card",
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = CARD,
	BorderSizePixel = 0,
	AutoButtonColor = false,
	Text = "",
	ClipsDescendants = true,
	ZIndex = 4,
}, slot)
make("UICorner", { CornerRadius = UDim.new(0, 10) }, card)
make("UIScale", { Name = "Pop" }, card)
make("UIGradient", {
	Name = "Lit", -- a lit top, darker foot (the plate rule)
	Rotation = 90,
	Color = ColorSequence.new(Color3.new(1, 1, 1), hex("B8B8BE")),
}, card)
make("ImageLabel", {
	Name = "Picture",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ScaleType = Enum.ScaleType.Crop,
	Image = "",
	Visible = false,
	ZIndex = 4,
}, card)
text(card, "Glyph", "?", HEAVY, 96, hex("3A3A42"), {
	AutomaticSize = Enum.AutomaticSize.None,
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0.4),
	Size = UDim2.fromOffset(120, 110),
	Visible = false,
	ZIndex = 5,
})
local foot = make("Frame", {
	Name = "Foot",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 74),
	BackgroundColor3 = FOOT,
	BorderSizePixel = 0,
	ZIndex = 6,
}, card)
-- the card's clip is square: the foot rounds its own bottom corners, and a
-- strip squares off its top ones
make("UICorner", { CornerRadius = UDim.new(0, 10) }, foot)
make("Frame", {
	Name = "Square",
	Size = UDim2.new(1, 0, 0, 12),
	BackgroundColor3 = FOOT,
	BorderSizePixel = 0,
	ZIndex = 6,
}, foot)
local mapName = text(foot, "Name", "WHITEBOX", HEAVY, 30, WHITE, {
	Position = UDim2.fromOffset(18, 30),
	ZIndex = 7,
})
outline(mapName, 0.6)
text(foot, "Size", "1V1 – 2V2", BOLD, 14, MUTED, {
	Position = UDim2.fromOffset(19, 10),
	ZIndex = 7,
})
text(card, "Chance", "", HEAVY, 26, GOLD, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 12),
	ZIndex = 7,
})
local voters = make("Frame", {
	Name = "Voters",
	Position = UDim2.fromOffset(14, 14),
	Size = UDim2.new(1, -100, 0, 36),
	BackgroundTransparency = 1,
	ZIndex = 7,
}, card)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, -6), -- heads overlap a little
	SortOrder = Enum.SortOrder.LayoutOrder,
}, voters)
make("Frame", {
	Name = "Dim", -- the cards that lost, after the pick
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 9,
}, card)

local headT = make("ImageLabel", {
	Name = "Head",
	Size = UDim2.fromOffset(36, 36),
	BackgroundColor3 = hex("2A2A31"),
	Image = "",
	ZIndex = 8,
}, tf)
make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, headT)
make("UIStroke", { Name = "Ring", Thickness = 2.5, Color = hex("3FE0F2") }, headT)

gui.Parent = SG
return "MapVote built"
