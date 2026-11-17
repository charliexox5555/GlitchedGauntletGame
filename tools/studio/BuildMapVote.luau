--!strict
-- Builds the map vote screen, v2 (2026-11-16, owner: "doesn't fit the theme,
-- no circle timer, no player cards like these, better animations"; plan and
-- RIVALS study in vault/05 Production/Playtests/2026-11-16 Match Fixes Round
-- 1.md → 7) in the match place:
--   StarterGui.MapVote                     <- Controllers/MapVoteController
--   ReplicatedStorage.UiTemplates.MapVote  (Slot = a grid cell holding the Card, Chip = a voter)
-- Studio owns them; this is their backup. Run in Edit (command bar or MCP).
-- An existing v1 screen and its templates are moved to ServerStorage.UiBackups
-- first (nothing is deleted).
--
-- Look: the lobby's chunky one-piece art (the same sliced images as lobby
-- Util/Cards and Util/Plates), Rubik Heavy / Bold, neutral charcoal, one gold
-- thing (your pick). Layout after RIVALS' vote: wide 2:1 map cards, 3 a row
-- (2 x 2 for four). No circle timer: a slanted bar that drains under the
-- title plate, the seconds at its end. No head cards: each card's foot is its
-- vote share (a fill + the %), voters are small square team-coloured chips.
-- A card is a fixed grid cell ("Slot") holding a centred "Card" CanvasGroup
-- (fades as one) with a "Pop" UIScale (pops from the centre).

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
local MUTED = hex("9F9FA2")
local NAVY = hex("141417")
local DEEP = hex("0B0B0D")
local CENTRE = Vector2.new(0.5, 0.5)
local DESIGN = Vector2.new(1920, 1080)
local CELL = Vector2.new(470, 210)
local GAP = 26
local FOOT_H = 54

-- The lobby's one-piece art (art-source/ui/plates): a rounded card (64 px,
-- 16 px corners, slice 24..40) and its bevel; a slanted plate (128 x 96, 32 px
-- slanted ends) and its gloss.
local CARD_BASE = "rbxassetid://93845956518960"
local CARD_OVER = "rbxassetid://123951162018563"
local PLATE_BASE = "rbxassetid://106196536481675"
local PLATE_GLOSS = "rbxassetid://93037486307954"
local CARD_SLICE = Rect.new(24, 24, 40, 40)
local PLATE_SLICE = Rect.new(32, 0, 96, 96)

-- Move a v1 screen out of the way (kept, not deleted).
local backups = SS:FindFirstChild("UiBackups") or make("Folder", { Name = "UiBackups" }, SS)
local old = SG:FindFirstChild("MapVote")
if old then
	old.Name = "MapVote_v1"
	old.Parent = backups
end
local folder = RS:FindFirstChild("UiTemplates") or make("Folder", { Name = "UiTemplates" }, RS)
local oldT = folder:FindFirstChild("MapVote")
if oldT then
	oldT.Name = "MapVoteTemplates_v1"
	oldT.Parent = backups
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

-- A dark outline on big white words (RIVALS' headings), so they hold over art.
local function outline(t: TextLabel, transparency: number)
	make("UIStroke", {
		Name = "Outline",
		Color = DEEP,
		Transparency = transparency,
		Thickness = 2,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, t)
end

-- A sliced image filling its parent.
local function skin(
	parent: Instance,
	name: string,
	image: string,
	slice: Rect,
	scale: number,
	color: Color3,
	z: number
): ImageLabel
	return make("ImageLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Image = image,
		ImageColor3 = color,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = slice,
		SliceScale = scale,
		ZIndex = z,
	}, parent)
end

-- A slanted plate `w` x `h` (its slanted ends inside that width).
local function plate(
	parent: Instance,
	name: string,
	w: number,
	h: number,
	color: Color3,
	z: number
): Frame
	local f = make("Frame", {
		Name = name,
		Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1,
		ZIndex = z,
	}, parent)
	skin(f, "Skin", PLATE_BASE, PLATE_SLICE, h / 96, color, z)
	local gloss = skin(f, "Gloss", PLATE_GLOSS, PLATE_SLICE, h / 96, WHITE, z + 1)
	gloss.ImageTransparency = 0.55
	return f
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
-- Over the blurred world (the controller blurs it): dark at the top and foot.
local backdrop = make("Frame", {
	Name = "Backdrop",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = hex("0E0E11"),
	BackgroundTransparency = 0.12,
	BorderSizePixel = 0,
	ZIndex = 1,
}, gui)
make("UIGradient", {
	Name = "Wash",
	Rotation = 90,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0.25),
		NumberSequenceKeypoint.new(1, 0),
	}),
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

-- Header: the title plate, the match line, the clock (a draining bar + seconds)
local head = make("Frame", {
	Name = "Head",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromOffset(DESIGN.X / 2, 78),
	Size = UDim2.fromOffset(760, 170),
	BackgroundTransparency = 1,
	ZIndex = 3,
}, canvas)
local titlePlate = plate(head, "TitlePlate", 620, 78, NAVY, 3)
titlePlate.AnchorPoint = Vector2.new(0.5, 0)
titlePlate.Position = UDim2.fromScale(0.5, 0)
local title = text(titlePlate, "Title", "VOTE FOR A MAP", HEAVY, 46, WHITE, {
	AutomaticSize = Enum.AutomaticSize.None,
	AnchorPoint = CENTRE,
	Position = UDim2.new(0.5, 0, 0.5, -1),
	Size = UDim2.new(1, -60, 1, 0),
	TextScaled = false,
	TextTruncate = Enum.TextTruncate.AtEnd,
	ZIndex = 6,
})
outline(title, 0.35)
text(head, "Sub", "1V1  ·  FIRST TO 5", BOLD, 20, MUTED, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 90),
})
-- The clock: a slanted track, a fill that drains (clipped by its holder), and
-- the seconds at the right end.
local clock = make("Frame", {
	Name = "Clock",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, -28, 0, 128),
	Size = UDim2.fromOffset(500, 14),
	BackgroundTransparency = 1,
	ZIndex = 4,
}, head)
local track = plate(clock, "Track", 500, 14, hex("26262B"), 4)
track.Size = UDim2.fromScale(1, 1)
local fillClip = make("Frame", {
	Name = "FillClip",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ClipsDescendants = true,
	ZIndex = 6,
}, clock)
local fill = plate(fillClip, "Fill", 500, 14, WHITE, 6)
fill.Size = UDim2.fromOffset(500, 14) -- full width: the clip drains it
text(clock, "Seconds", "12", HEAVY, 34, WHITE, {
	AutomaticSize = Enum.AutomaticSize.None,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(1, 16, 0.5, 0),
	Size = UDim2.fromOffset(70, 40),
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 6,
})

-- The grid of cards
local cards = make("Frame", {
	Name = "Cards",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromOffset(DESIGN.X / 2, 296),
	Size = UDim2.fromOffset(CELL.X * 3 + GAP * 2, CELL.Y * 3 + GAP * 2),
	BackgroundTransparency = 1,
	ZIndex = 3,
}, canvas)
make("UIGridLayout", {
	Name = "Grid",
	CellSize = UDim2.fromOffset(CELL.X, CELL.Y),
	CellPadding = UDim2.fromOffset(GAP, GAP),
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

text(canvas, "Hint", "CLICK A MAP TO VOTE  ·  EVERY VOTE IS A TICKET", BOLD, 16, MUTED, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromOffset(DESIGN.X / 2, DESIGN.Y - 44),
	ZIndex = 3,
})

-- Templates -------------------------------------------------------------------
local tf = make("Folder", { Name = "MapVote" }, folder)

local slot = make("Frame", {
	Name = "Slot",
	Size = UDim2.fromOffset(CELL.X, CELL.Y),
	BackgroundTransparency = 1,
}, tf)
-- The card fades as one (CanvasGroup) and pops from its centre (Pop).
local card = make("CanvasGroup", {
	Name = "Card",
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ZIndex = 4,
}, slot)
make("UIScale", { Name = "Pop" }, card)
-- The click target, over the whole card.
make("TextButton", {
	Name = "Hit",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 30,
}, card)
skin(card, "Skin", CARD_BASE, CARD_SLICE, 0.5, NAVY, 4)
-- Map art (when a map has a picture): cropped, fading out into the foot.
local picture = make("ImageLabel", {
	Name = "Picture",
	Position = UDim2.fromOffset(4, 4),
	Size = UDim2.new(1, -8, 1, -8),
	BackgroundTransparency = 1,
	ScaleType = Enum.ScaleType.Crop,
	Image = "",
	Visible = false,
	ZIndex = 5,
}, card)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, picture)
make("UIGradient", {
	Name = "Fade",
	Rotation = 90,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.55, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	}),
}, picture)
-- No art: a faint big initial in the card's top-right (and "?" for Random).
text(card, "Glyph", "", HEAVY, 120, hex("232328"), {
	AutomaticSize = Enum.AutomaticSize.None,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -18, 0, -6),
	Size = UDim2.fromOffset(160, 140),
	TextXAlignment = Enum.TextXAlignment.Right,
	ZIndex = 5,
})
text(card, "Teams", "1V1 – 2V2", BOLD, 15, MUTED, {
	Position = UDim2.new(0, 20, 1, -FOOT_H - 70),
	ZIndex = 8,
})
local mapName = text(card, "MapName", "WHITEBOX", HEAVY, 36, WHITE, {
	Position = UDim2.new(0, 18, 1, -FOOT_H - 50),
	ZIndex = 8,
})
outline(mapName, 0.5)
-- The foot: the vote share (a fill from the left, its %) and the voters.
local foot = make("Frame", {
	Name = "Foot",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 4, 1, -6),
	Size = UDim2.new(1, -8, 0, FOOT_H),
	BackgroundColor3 = DEEP,
	BackgroundTransparency = 0.25,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	ZIndex = 6,
}, card)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, foot)
local share = make("Frame", {
	Name = "Share",
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = hex("2E2E34"),
	BorderSizePixel = 0,
	ZIndex = 6,
}, foot)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, share)
local voters = make("Frame", {
	Name = "Voters",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 12, 0.5, 0),
	Size = UDim2.new(1, -110, 0, 30),
	BackgroundTransparency = 1,
	ZIndex = 7,
}, foot)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, voters)
text(foot, "Chance", "", HEAVY, 28, WHITE, {
	AutomaticSize = Enum.AutomaticSize.None,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -16, 0.5, 0),
	Size = UDim2.fromOffset(90, 34),
	TextXAlignment = Enum.TextXAlignment.Right,
	ZIndex = 8,
})
skin(card, "Bevel", CARD_OVER, CARD_SLICE, 0.5, WHITE, 9)

-- A voter: a small square chip in their team colour with their head.
local chip = make("Frame", {
	Name = "Chip",
	Size = UDim2.fromOffset(30, 30),
	BackgroundColor3 = hex("3FE0F2"),
	BorderSizePixel = 0,
	ZIndex = 7,
}, tf)
make("UICorner", { CornerRadius = UDim.new(0, 4) }, chip)
local face = make("ImageLabel", {
	Name = "Face",
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(1, -4, 1, -4),
	BackgroundColor3 = hex("1E1E22"),
	Image = "",
	ZIndex = 8,
}, chip)
make("UICorner", { CornerRadius = UDim.new(0, 3) }, face)

gui.Parent = SG
return "MapVote v2 built (v1 kept in ServerStorage.UiBackups)"
