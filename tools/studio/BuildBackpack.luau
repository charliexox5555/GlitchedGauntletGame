--!strict
-- Builds the Backpack screen in the LOBBY place, Edit mode (vault/01 Design/Inventory and
-- Crates.md → Backpack). Re-running replaces it; the owner edits the result in Studio.
--   StarterGui.Backpack                  header (icon, title, line), the item grid, a note,
--                                        OPEN SHOP for an empty backpack (Controllers/BackpackController)
--   UiTemplates.Lobby.BackpackCell       one stack: the item art and its ×count
-- Layout studied from the owner's RIVALS Backpack screenshot (header plate, 6-wide grid of
-- big items with ×counts, dark empty slots), rebuilt in our look: wash over the blurred
-- lobby, chunky cells (Util/Cards), Rubik, the drawn-X close, one gold act-now button.

local SG = game:GetService("StarterGui")
local RS = game:GetService("ReplicatedStorage")

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
local function hex(h: string): Color3
	return Color3.fromHex(h)
end

local FONT = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy) -- Rubik
local WHITE = Color3.new(1, 1, 1)
local INK = hex("0F0F12")
local NAVY = hex("141417")
local NAVY_HI = hex("252528")
local MUTED = hex("9F9FA2")
local GOLD = hex("FFC83D")
local CENTRE = Vector2.new(0.5, 0.5)
local CAP_R = "rbxassetid://130377997107460"
-- the bar's backpack icon (art-source/ui/lobby-icons/backpack_v2_bar.png)
local ICON = "rbxassetid://83907686297008"

local COLS, CELL_W, CELL_H, GAP = 6, 156, 176, 18
local GRID_W = COLS * CELL_W + (COLS - 1) * GAP + 16

local function corner(p: Instance, r: number?)
	make("UICorner", { CornerRadius = UDim.new(0, r or 8) }, p)
end
local function round(p: Instance)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, p)
end
local function text(
	p: Instance,
	name: string,
	t: string,
	size: number,
	color: Color3,
	props: { [string]: any }?
): TextLabel
	local l = make("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Text = t,
		FontFace = FONT,
		TextSize = size,
		TextColor3 = color,
		ZIndex = 5,
	}, p)
	for k, v in props or {} do
		(l :: any)[k] = v
	end
	return l
end
local function slant(body: GuiObject, color: Color3, h: number, capW: number)
	make("ImageLabel", {
		Name = "CapL",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(0, 1, 0, 0),
		Size = UDim2.fromOffset(capW, h),
		BackgroundTransparency = 1,
		Image = CAP_R,
		Rotation = 180,
		ImageColor3 = color,
		ZIndex = body.ZIndex,
	}, body)
	make("ImageLabel", {
		Name = "CapR",
		Position = UDim2.new(1, -1, 0, 0),
		Size = UDim2.fromOffset(capW, h),
		BackgroundTransparency = 1,
		Image = CAP_R,
		ImageColor3 = color,
		ZIndex = body.ZIndex,
	}, body)
end
local function drawX(p: Instance, size: number, thick: number, color: Color3)
	local glyph = make("Frame", {
		Name = "Glyph",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex = 5,
	}, p)
	for _, r in { 45, -45 } do
		local bar = make("Frame", {
			Name = if r > 0 then "A" else "B",
			AnchorPoint = CENTRE,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(size, thick),
			Rotation = r,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = 5,
		}, glyph)
		round(bar)
	end
end

------------------------------------------------------------------------------
-- The screen

local old = SG:FindFirstChild("Backpack")
if old then
	old:Destroy()
end
local gui = make("ScreenGui", {
	Name = "Backpack",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ScreenInsets = Enum.ScreenInsets.None,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 30,
	Enabled = false,
})
local wash = make("Frame", {
	Name = "Wash",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.3,
	BorderSizePixel = 0,
	Active = true,
	ZIndex = 0,
}, gui)
make("UIGradient", {
	Rotation = 35,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, hex("2E2E31")),
		ColorSequenceKeypoint.new(0.55, hex("1E1E21")),
		ColorSequenceKeypoint.new(1, hex("131316")),
	}),
}, wash)
local canvas = make("Frame", {
	Name = "Canvas",
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(1920, 1080),
	BackgroundTransparency = 1,
	ZIndex = 1,
}, gui)
make("UIScale", { Name = "Fit" }, canvas)
local close = make("TextButton", {
	Name = "Close",
	AnchorPoint = CENTRE,
	Position = UDim2.fromOffset(1830, 76),
	Size = UDim2.fromOffset(72, 72),
	BackgroundColor3 = NAVY,
	BackgroundTransparency = 0.1,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 3,
}, canvas)
round(close)
make("UIScale", { Name = "Pop" }, close)
drawX(close, 30, 5, WHITE)

local left = (1920 - GRID_W) / 2

-- header: a dark plate with the icon, the title and one line
local head = make("Frame", {
	Name = "Header",
	Position = UDim2.fromOffset(left, 120),
	Size = UDim2.fromOffset(GRID_W, 150),
	BackgroundColor3 = NAVY,
	BackgroundTransparency = 0.15,
	BorderSizePixel = 0,
	ZIndex = 2,
}, canvas)
corner(head, 10)
make("ImageLabel", {
	Name = "Icon",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 22, 0.5, 0),
	Size = UDim2.fromOffset(120, 120),
	BackgroundTransparency = 1,
	Image = ICON,
	ScaleType = Enum.ScaleType.Fit,
	ZIndex = 4,
}, head)
text(head, "Title", "BACKPACK", 60, WHITE, {
	Position = UDim2.fromOffset(164, 26),
	Size = UDim2.fromOffset(700, 64),
	TextXAlignment = Enum.TextXAlignment.Left,
})
text(head, "Sub", "YOUR CASES AND EXTRA LOOT LIVE HERE.", 22, MUTED, {
	Position = UDim2.fromOffset(168, 94),
	Size = UDim2.fromOffset(820, 28),
	TextXAlignment = Enum.TextXAlignment.Left,
})

-- the grid of stacks
local grid = make("ScrollingFrame", {
	Name = "Grid",
	Position = UDim2.fromOffset(left, 300),
	Size = UDim2.fromOffset(GRID_W, 3 * CELL_H + 2 * GAP + 24),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 0, -- no visible bar (owner, 2026-11-16)
	ScrollBarImageTransparency = 1,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ZIndex = 2,
}, canvas)
make("UIGridLayout", {
	CellSize = UDim2.fromOffset(CELL_W, CELL_H),
	CellPadding = UDim2.fromOffset(GAP, GAP),
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
}, grid)
make("UIPadding", {
	PaddingLeft = UDim.new(0, 8),
	PaddingRight = UDim.new(0, 8),
	PaddingTop = UDim.new(0, 8),
	PaddingBottom = UDim.new(0, 8),
}, grid)

-- the hovered stack's name, under the grid
text(canvas, "Detail", "", 26, WHITE, {
	Position = UDim2.fromOffset(left + 8, 900),
	Size = UDim2.fromOffset(GRID_W - 16, 34),
	TextXAlignment = Enum.TextXAlignment.Left,
})
text(
	canvas,
	"Note",
	"CLICK A CASE TO SEE WHAT'S IN IT OR OPEN IT. YOU NEVER GET A SKIN YOU ALREADY OWN.",
	18,
	MUTED,
	{
		Position = UDim2.fromOffset(left + 8, 940),
		Size = UDim2.fromOffset(GRID_W - 16, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTransparency = 0.15,
	}
)

-- an empty backpack: one line and the act-now button (gold) to the Shop
local empty = make("Frame", {
	Name = "Empty",
	AnchorPoint = CENTRE,
	Position = UDim2.fromOffset(960, 560),
	Size = UDim2.fromOffset(700, 200),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 4,
}, canvas)
text(empty, "Line", "NOTHING HERE YET", 40, WHITE, {
	Position = UDim2.fromOffset(0, 10),
	Size = UDim2.fromOffset(700, 48),
	ZIndex = 6,
})
local shop = make("TextButton", {
	Name = "OpenShop",
	AnchorPoint = CENTRE,
	Position = UDim2.fromOffset(350, 130),
	Size = UDim2.fromOffset(300, 72),
	BackgroundColor3 = GOLD,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 6,
}, empty)
slant(shop, GOLD, 72, 23)
make("UIScale", { Name = "Pop" }, shop)
text(shop, "Label", "OPEN SHOP", 32, INK, { Size = UDim2.fromScale(1, 1), ZIndex = 7 })

------------------------------------------------------------------------------
-- Opening (2026-11-20): the reveal panel after OPEN
-- (the cinematic crate opening replaces the panel's entrance later).

local shade = make("Frame", {
	Name = "RevealShade",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.35,
	BorderSizePixel = 0,
	Active = true,
	Visible = false,
	ZIndex = 18,
}, canvas)
local reveal = make("Frame", {
	Name = "Reveal",
	AnchorPoint = CENTRE,
	Position = UDim2.fromOffset(960, 540),
	Size = UDim2.fromOffset(760, 640),
	BackgroundColor3 = NAVY,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 20,
}, canvas)
corner(reveal, 10)
make("UIScale", { Name = "Pop" }, reveal)
text(reveal, "Kicker", "NEW SKIN", 24, MUTED, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 34),
	Size = UDim2.fromOffset(600, 30),
	ZIndex = 22,
})
make("ImageLabel", {
	Name = "Art",
	AnchorPoint = CENTRE,
	Position = UDim2.new(0.5, 0, 0, 230),
	Size = UDim2.fromOffset(460, 290),
	BackgroundTransparency = 1,
	ScaleType = Enum.ScaleType.Fit,
	ZIndex = 22,
}, reveal)
make("ImageLabel", {
	Name = "Emblem",
	AnchorPoint = CENTRE,
	Position = UDim2.new(0.5, 0, 0, 230),
	Size = UDim2.fromOffset(180, 180),
	BackgroundTransparency = 1,
	ScaleType = Enum.ScaleType.Fit,
	Visible = false,
	ZIndex = 22,
}, reveal)
text(reveal, "Name", "PRISM VANDAL", 52, WHITE, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 392),
	Size = UDim2.fromOffset(700, 60),
	ZIndex = 22,
})
local tierPlate = make("Frame", {
	Name = "Tier",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 458),
	Size = UDim2.fromOffset(170, 34),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	ZIndex = 22,
}, reveal)
slant(tierPlate, WHITE, 34, 11)
text(tierPlate, "Label", "COMMON", 20, INK, { Size = UDim2.fromScale(1, 1), ZIndex = 23 })
local equip = make("TextButton", {
	Name = "Equip",
	AnchorPoint = CENTRE,
	Position = UDim2.new(0.5, -140, 1, -58),
	Size = UDim2.fromOffset(240, 64),
	BackgroundColor3 = GOLD,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 22,
}, reveal)
slant(equip, GOLD, 64, 20)
make("UIScale", { Name = "Pop" }, equip)
text(equip, "Label", "EQUIP", 28, INK, { Size = UDim2.fromScale(1, 1), ZIndex = 23 })
local ok = make("TextButton", {
	Name = "Done",
	AnchorPoint = CENTRE,
	Position = UDim2.new(0.5, 140, 1, -58),
	Size = UDim2.fromOffset(240, 64),
	BackgroundColor3 = NAVY_HI,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 22,
}, reveal)
slant(ok, NAVY_HI, 64, 20)
make("UIScale", { Name = "Pop" }, ok)
text(ok, "Label", "NICE", 28, WHITE, { Size = UDim2.fromScale(1, 1), ZIndex = 23 })

------------------------------------------------------------------------------
-- Item popup (owner 2026-11-20, after RIVALS' Backpack): click a stack → its name,
-- picture and ×count, CONTENTS (the grouped odds, Util/OddsList) and OPEN.

local function closeX(parent: Instance, z: number): TextButton
	local b = make("TextButton", {
		Name = "Close",
		AnchorPoint = CENTRE,
		Position = UDim2.new(1, -46, 0, 46),
		Size = UDim2.fromOffset(60, 60),
		BackgroundColor3 = NAVY_HI,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = z,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, b)
	make("UIScale", { Name = "Pop" }, b)
	local glyph = make("Frame", {
		Name = "Glyph",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(24, 24),
		BackgroundTransparency = 1,
		ZIndex = z + 1,
	}, b)
	for _, r in { 45, -45 } do
		local bar = make("Frame", {
			Name = if r > 0 then "A" else "B",
			AnchorPoint = CENTRE,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(24, 4),
			Rotation = r,
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			ZIndex = z + 1,
		}, glyph)
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, bar)
	end
	return b
end

make("Frame", {
	Name = "ItemShade",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.35,
	BorderSizePixel = 0,
	Active = true,
	Visible = false,
	ZIndex = 18,
}, canvas)
local item = make("Frame", {
	Name = "ItemPanel",
	AnchorPoint = CENTRE,
	Position = UDim2.fromOffset(960, 540),
	Size = UDim2.fromOffset(820, 560),
	BackgroundColor3 = NAVY,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 20,
}, canvas)
corner(item, 10)
make("UIScale", { Name = "Pop" }, item)
text(item, "Title", "ELITE CASE", 44, WHITE, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 28),
	Size = UDim2.fromOffset(600, 50),
	ZIndex = 22,
})
closeX(item, 22)
make("ImageLabel", {
	Name = "Art",
	AnchorPoint = CENTRE,
	Position = UDim2.new(0.5, 0, 0, 230),
	Size = UDim2.fromOffset(400, 250),
	BackgroundTransparency = 1,
	ScaleType = Enum.ScaleType.Fit,
	ZIndex = 22,
}, item)
text(item, "CountShadow", "×1", 52, INK, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 3, 0, 343),
	Size = UDim2.fromOffset(300, 58),
	TextTransparency = 0.25,
	ZIndex = 22,
})
text(item, "Count", "×1", 52, WHITE, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 340),
	Size = UDim2.fromOffset(300, 58),
	ZIndex = 23,
})
local contentsB = make("TextButton", {
	Name = "Contents",
	AnchorPoint = CENTRE,
	Position = UDim2.new(0.5, -165, 1, -70),
	Size = UDim2.fromOffset(260, 72),
	BackgroundColor3 = NAVY_HI,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 22,
}, item)
slant(contentsB, NAVY_HI, 72, 23)
make("UIScale", { Name = "Pop" }, contentsB)
text(contentsB, "Label", "CONTENTS", 30, WHITE, { Size = UDim2.fromScale(1, 1), ZIndex = 23 })
local openB = make("TextButton", {
	Name = "Open",
	AnchorPoint = CENTRE,
	Position = UDim2.new(0.5, 165, 1, -70),
	Size = UDim2.fromOffset(260, 72),
	BackgroundColor3 = GOLD,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 22,
}, item)
slant(openB, GOLD, 72, 23)
make("UIScale", { Name = "Pop" }, openB)
text(openB, "Label", "OPEN", 32, INK, { Size = UDim2.fromScale(1, 1), ZIndex = 23 })

-- CONTENTS: the grouped odds list (rows: UiTemplates.Lobby.ShopOddsRow)
local odds = make("Frame", {
	Name = "ContentsPanel",
	AnchorPoint = CENTRE,
	Position = UDim2.fromOffset(960, 540),
	Size = UDim2.fromOffset(860, 760),
	BackgroundColor3 = NAVY,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 30,
}, canvas)
corner(odds, 10)
make("UIScale", { Name = "Pop" }, odds)
text(odds, "Title", "CONTENTS", 40, WHITE, {
	Position = UDim2.fromOffset(40, 26),
	Size = UDim2.fromOffset(600, 44),
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 34,
})
text(odds, "Sub", "ELITE CASE", 18, MUTED, {
	Position = UDim2.fromOffset(42, 76),
	Size = UDim2.fromOffset(600, 22),
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 34,
})
closeX(odds, 34)
local oddsList = make("ScrollingFrame", {
	Name = "List",
	Position = UDim2.fromOffset(30, 118),
	Size = UDim2.new(1, -60, 1, -230),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 0,
	ScrollBarImageTransparency = 1,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ZIndex = 33,
}, odds)
make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, oddsList)
text(odds, "Note", "", 13, MUTED, {
	Position = UDim2.new(0, 40, 1, -96),
	Size = UDim2.new(1, -80, 0, 76),
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 34,
})

gui.Parent = SG

------------------------------------------------------------------------------
-- Template: one stack

local folder = RS:FindFirstChild("UiTemplates") or make("Folder", { Name = "UiTemplates" }, RS)
local lobby = folder:FindFirstChild("Lobby") or make("Folder", { Name = "Lobby" }, folder)
local oldCell = lobby:FindFirstChild("BackpackCell")
if oldCell then
	oldCell:Destroy()
end
local cell = make("TextButton", {
	Name = "BackpackCell",
	Size = UDim2.fromOffset(CELL_W, CELL_H),
	BackgroundColor3 = NAVY_HI,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 3,
})
corner(cell, 12)
make("ImageLabel", {
	Name = "Art",
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0.41),
	Size = UDim2.fromOffset(138, 128), -- the tight end-on crate renders
	BackgroundTransparency = 1,
	ScaleType = Enum.ScaleType.Fit,
	ZIndex = 6,
}, cell)
-- the count: big white with a hard shadow (readable on any art, no outline glow)
text(cell, "CountShadow", "×1", 44, INK, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 3, 1, -3),
	Size = UDim2.new(1, 0, 0, 48),
	TextTransparency = 0.25,
	ZIndex = 7,
})
text(cell, "Count", "×1", 44, WHITE, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -6),
	Size = UDim2.new(1, 0, 0, 48),
	ZIndex = 8,
})
cell.Parent = lobby

print("[BuildBackpack] StarterGui.Backpack and UiTemplates.Lobby.BackpackCell built")
