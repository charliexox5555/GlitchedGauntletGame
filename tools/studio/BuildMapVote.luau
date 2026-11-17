--!strict
-- Builds the map vote screen, v4 (2026-11-16). v3 followed the owner's notes on v2 with a
-- RIVALS screenshot: "blur most of the background, no other HUD, nothing see-
-- through; the top is our match top bar with the timer; the maps like the
-- reference; a square avatar on a voted map that still looks clean with
-- several votes") in the match place:
--   StarterGui.MapVote                     <- Controllers/MapVoteController
--   ReplicatedStorage.UiTemplates.MapVote  (Slot = a grid cell holding the Card, Voter = a vote)
-- Studio owns them; this is their backup. Run in Edit (command bar or MCP).
-- An existing screen and its templates are moved to ServerStorage.UiBackups
-- first (nothing is deleted).
--
-- v4 (owner: "add our own character so it is not exactly like RIVALS, but
-- not the bevels from before"): our Soft Edge marks instead of RIVALS'
-- striped colour band and border. Each card and voter tile has one 45-degree
-- cut on its top-right corner (a `Cut` UIGradient on the CanvasGroup; the
-- controller sets its Offset for the size); the name band is charcoal with a
-- coloured slash (1v1 maps green, team maps red), the team sizes small over
-- the uppercase name, the chance on the right; your pick turns the band gold.
-- Layout: the map's picture fills the card (Config/Match MAPS `image`);
-- voters are avatar tiles in their team colour, centred on the picture in a
-- tidy grid. The top bar (TopBarController) holds the timer. The controller
-- sizes the grid and the cells for the number of maps.

local SG = game:GetService("StarterGui")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

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
local DEEP = hex("0B0B0D")
local SLASH = hex("3E9E46") -- the controller recolours it per map
local CHARCOAL = hex("141417")
local MUTED = hex("9F9FA2")
local CENTRE = Vector2.new(0.5, 0.5)
local DESIGN = Vector2.new(1920, 1080)
-- One 45-degree cut on the top-right corner, `a` px on a `w` x `h` box: the
-- gradient's hard step sits on the corner's diagonal (Offset moves it there).
local function cut(parent: Instance, a: number, w: number, h: number)
	make("UIGradient", {
		Name = "Cut",
		Rotation = -45,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(0.5001, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Offset = Vector2.new(0.5 - a / w / 2, -(0.5 - a / h / 2)),
	}, parent)
end

-- Move the old screen out of the way (kept, not deleted).
local backups = SS:FindFirstChild("UiBackups") or make("Folder", { Name = "UiBackups" }, SS)
local function park(item: Instance?, as: string)
	if item then
		local name, n = as, 2
		while backups:FindFirstChild(name) do
			name = as .. "_" .. n
			n += 1
		end
		item.Name = name
		item.Parent = backups
	end
end
park(SG:FindFirstChild("MapVote"), "MapVote_v3")
local folder = RS:FindFirstChild("UiTemplates") or make("Folder", { Name = "UiTemplates" }, RS)
park(folder:FindFirstChild("MapVote"), "MapVoteTemplates_v3")

-- Screen ----------------------------------------------------------------------
local gui = make("ScreenGui", {
	Name = "MapVote",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 40, -- over every HUD screen; the top bar goes above it (41) while voting
	Enabled = false,
})
-- Over the blurred world: dark enough that nothing reads through.
local backdrop = make("Frame", {
	Name = "Backdrop",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = hex("101014"),
	BackgroundTransparency = 0.1,
	BorderSizePixel = 0,
	ZIndex = 1,
}, gui)
make("UIGradient", {
	Name = "Wash",
	Rotation = 90,
	Color = ColorSequence.new(hex("1B1A22"), hex("0A0A0D")),
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

local cards = make("Frame", {
	Name = "Cards",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromOffset(DESIGN.X / 2, 150),
	Size = UDim2.fromOffset(1800, 880),
	BackgroundTransparency = 1,
	ZIndex = 3,
}, canvas)
make("UIGridLayout", {
	Name = "Grid",
	CellSize = UDim2.fromOffset(560, 330),
	CellPadding = UDim2.fromOffset(18, 18),
	FillDirectionMaxCells = 3,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Top,
	SortOrder = Enum.SortOrder.LayoutOrder,
}, cards)
-- The picked card moves here, over everything (the controller re-parents it).
make("Frame", {
	Name = "Stage",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ZIndex = 20,
}, canvas)

-- Templates -------------------------------------------------------------------
local tf = make("Folder", { Name = "MapVote" }, folder)

local slot = make("Frame", {
	Name = "Slot",
	Size = UDim2.fromOffset(560, 330),
	BackgroundTransparency = 1,
}, tf)
-- The card fades as one (CanvasGroup) and pops from its centre (Pop).
local card = make("CanvasGroup", {
	Name = "Card",
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = hex("1A1A1F"),
	BorderSizePixel = 0,
	ZIndex = 4,
}, slot)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, card)
make("UIScale", { Name = "Pop" }, card)
cut(card, 34, 560, 330)
-- The click target, over the whole card.
make("TextButton", {
	Name = "Hit",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 30,
}, card)
make("ImageLabel", {
	Name = "Picture",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ScaleType = Enum.ScaleType.Crop,
	Image = "",
	ZIndex = 5,
}, card)
-- Random (no picture): a big mark in the middle.
make("TextLabel", {
	Name = "Glyph",
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0.4),
	Size = UDim2.fromScale(0.5, 0.5),
	BackgroundTransparency = 1,
	Text = "?",
	TextScaled = true,
	FontFace = HEAVY,
	TextColor3 = WHITE,
	Visible = false,
	ZIndex = 6,
}, card)
-- The name band: charcoal, a coloured slash, the team sizes over the name,
-- the chance on the right.
local band = make("Frame", {
	Name = "Band",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.fromScale(1, 0.22),
	BackgroundColor3 = CHARCOAL,
	BackgroundTransparency = 0.06,
	BorderSizePixel = 0,
	ZIndex = 8,
}, card)
make("Frame", {
	Name = "Slash",
	AnchorPoint = CENTRE,
	Position = UDim2.new(0, 26, 0.5, 0),
	Size = UDim2.new(0, 9, 0.62, 0),
	Rotation = 18,
	BackgroundColor3 = SLASH,
	BorderSizePixel = 0,
	ZIndex = 9,
}, band)
local title = make("TextLabel", {
	Name = "Title",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 46, 1, -9),
	Size = UDim2.new(0.62, 0, 0.5, 0),
	BackgroundTransparency = 1,
	Text = "ARENA",
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	FontFace = HEAVY,
	TextColor3 = WHITE,
	ZIndex = 9,
}, band)
make("UITextSizeConstraint", { MaxTextSize = 44, MinTextSize = 12 }, title)
make("UIStroke", {
	Name = "Outline", -- off: plain words on the charcoal band
	Color = DEEP,
	Thickness = 2,
	Transparency = 0.45,
	LineJoinMode = Enum.LineJoinMode.Round,
	Enabled = false,
}, title)
make("TextLabel", {
	Name = "Teams",
	Position = UDim2.new(0, 47, 0, 9),
	Size = UDim2.new(0.6, 0, 0.26, 0),
	BackgroundTransparency = 1,
	Text = "1V1 – 2V2",
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	FontFace = BOLD,
	TextColor3 = MUTED,
	ZIndex = 9,
}, band)
make("TextLabel", {
	Name = "Chance",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -18, 0.5, 0),
	Size = UDim2.new(0.22, 0, 0.55, 0),
	BackgroundTransparency = 1,
	Text = "",
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Right,
	FontFace = HEAVY,
	TextColor3 = WHITE,
	ZIndex = 9,
}, band)
-- The votes: square tiles centred on the picture (the controller sizes them).
local votes = make("Frame", {
	Name = "Votes",
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0.42),
	Size = UDim2.fromScale(0.9, 0.7),
	BackgroundTransparency = 1,
	ZIndex = 10,
}, card)
make("UIGridLayout", {
	Name = "Grid",
	CellSize = UDim2.fromOffset(84, 84),
	CellPadding = UDim2.fromOffset(10, 10),
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
}, votes)

-- A vote: their head on a tile in their team colour (lit top, deeper foot),
-- with the card's cut corner; a CanvasGroup so the cut clips the face too.
local voter = make("CanvasGroup", {
	Name = "Voter",
	Size = UDim2.fromOffset(84, 84),
	BackgroundTransparency = 1,
	ZIndex = 10,
}, tf)
cut(voter, 12, 84, 84)
make("UIScale", { Name = "Pop" }, voter)
local fill = make("Frame", {
	Name = "Fill",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = hex("7B4DFF"),
	BorderSizePixel = 0,
	ZIndex = 10,
}, voter)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, fill)
make("UIGradient", {
	Name = "Shade",
	Rotation = 90,
	Color = ColorSequence.new(WHITE, hex("8C8C96")),
}, fill)
local face = make("ImageLabel", {
	Name = "Face",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Image = "",
	ZIndex = 11,
}, voter)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, face)

gui.Parent = SG
return "MapVote v4 built (older screens kept in ServerStorage.UiBackups)"
