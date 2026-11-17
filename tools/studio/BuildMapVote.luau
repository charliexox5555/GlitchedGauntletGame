--!strict
-- Builds the map vote screen, v3 (2026-11-16, owner's notes on v2 with a
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
-- Look: the map's picture fills the card (Config/Match MAPS `image`); a name
-- band along the foot in the card's colour with diagonal stripes
-- (Config/Match VOTE.stripes), the name and its chance ("ARENA [50%]");
-- voters are square avatar tiles in their team colour, centred on the
-- picture in a tidy grid. The top bar (TopBarController) holds the timer.
-- The controller sizes the grid and the cells for the number of maps.

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
local WHITE = Color3.new(1, 1, 1)
local DEEP = hex("0B0B0D")
local BAND = hex("3E9E46") -- the controller recolours it per map
local CENTRE = Vector2.new(0.5, 0.5)
local DESIGN = Vector2.new(1920, 1080)
local STRIPES = "rbxassetid://132373217041083"

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
park(SG:FindFirstChild("MapVote"), "MapVote_v2")
local folder = RS:FindFirstChild("UiTemplates") or make("Folder", { Name = "UiTemplates" }, RS)
park(folder:FindFirstChild("MapVote"), "MapVoteTemplates_v2")

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
make("UIStroke", {
	Name = "Edge", -- the card's colour round its edge (white on your pick)
	Color = BAND,
	Thickness = 2,
	Transparency = 0.15,
	ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
}, card)
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
-- The name band: the card's colour, diagonal stripes, the name and chance.
local band = make("Frame", {
	Name = "Band",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.fromScale(1, 0.2),
	BackgroundColor3 = BAND,
	BackgroundTransparency = 0.08,
	BorderSizePixel = 0,
	ZIndex = 8,
}, card)
make("ImageLabel", {
	Name = "Stripes",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Image = STRIPES,
	ImageColor3 = DEEP,
	ImageTransparency = 0.72,
	ScaleType = Enum.ScaleType.Tile,
	TileSize = UDim2.fromOffset(28, 28),
	ZIndex = 8,
}, band)
local title = make("TextLabel", {
	Name = "Title",
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0.52),
	Size = UDim2.fromScale(0.92, 0.72),
	BackgroundTransparency = 1,
	Text = "ARENA",
	TextScaled = true,
	FontFace = HEAVY,
	TextColor3 = WHITE,
	ZIndex = 9,
}, band)
make("UITextSizeConstraint", { MaxTextSize = 44, MinTextSize = 12 }, title)
make("UIStroke", {
	Name = "Outline",
	Color = DEEP,
	Thickness = 2,
	Transparency = 0.45,
	LineJoinMode = Enum.LineJoinMode.Round,
}, title)
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

-- A vote: their head on a square in their team colour (lit top, deeper foot).
local voter = make("Frame", {
	Name = "Voter",
	Size = UDim2.fromOffset(84, 84),
	BackgroundColor3 = hex("7B4DFF"),
	BorderSizePixel = 0,
	ZIndex = 10,
}, tf)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, voter)
make("UIGradient", {
	Name = "Shade",
	Rotation = 90,
	Color = ColorSequence.new(WHITE, hex("8C8C96")),
}, voter)
make("UIScale", { Name = "Pop" }, voter)
local face = make("ImageLabel", {
	Name = "Face",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Image = "",
	ZIndex = 11,
}, voter)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, face)

gui.Parent = SG
return "MapVote v3 built (older screens kept in ServerStorage.UiBackups)"
