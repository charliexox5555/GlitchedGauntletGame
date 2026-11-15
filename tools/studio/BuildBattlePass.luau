--!strict
-- Builds the Season Pass screen (vault/02 Art/UI Battle Pass.md) in the LOBBY
-- place, Edit mode: StarterGui.BattlePass (off; Controllers/BattlePassController
-- opens it as Router "BattlePass" and fills it from Lobby/SeasonCatalog).
-- Re-running replaces it. RIVALS-style layout, our look (the Shop's: Builder
-- Extended, dark navy see-through plates, slanted price plates, a drawn-X
-- close, the violet wash over the blurred world):
--   top     the picked reward big (a 3D skin, an image, or a card), its tier,
--           name and line; CONTENTS / CLAIM / UNLOCK PREMIUM / +5 LEVELS
--   middle  your season level, the bar to the next with what levels you up,
--           page arrows
--   bottom  the FREE and PREMIUM track badges and 7 tiers per page (a cell per
--           track), tier numbers with a bar each (filled when reached)

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
local XB, BOLD = Enum.FontWeight.ExtraBold, Enum.FontWeight.Bold
local CARD = hex("0B1236")
local CARD_T = 0.2
local GOLD, GREEN = hex("FFC83D"), hex("3FD45C")
local ALLY = hex("3FE0F2")
local MUTED, INK, WHITE = hex("AEB8D6"), hex("141A26"), Color3.new(1, 1, 1)
local PREMIUM_CELL = hex("3A3016") -- a dark gold plate for the premium track
local CAP_R = "rbxassetid://130377997107460"
local ROBUX = "rbxasset://textures/ui/common/robux.png"
local CENTRE = Vector2.new(0.5, 0.5)
local X0, W = 160, 1600 -- content left and width

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
		ZIndex = 5,
	}, p)
	for k, v in props or {} do
		(t :: any)[k] = v
	end
	return t
end
local function corner(p: Instance, r: number?)
	make("UICorner", { CornerRadius = UDim.new(0, r or 8) }, p)
end
local function frame(p: Instance, name: string, props: { [string]: any }): Frame
	local f = make("Frame", { Name = name, BackgroundTransparency = 1, BorderSizePixel = 0 }, p)
	for k, v in props do
		(f :: any)[k] = v
	end
	return f
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
-- the chunky tick (owner, style board): two thick bright-green bars over a
-- dark shadow copy, no circle
local function chunkyTick(p: Instance, d: number, z: number, anchor: Vector2, pos: UDim2): Frame
	local c = make("Frame", {
		Name = "Check",
		AnchorPoint = anchor,
		Position = pos,
		Size = UDim2.fromOffset(d, d),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = z,
	}, p)
	for i, layer in
		{
			{ "Shadow", Color3.fromHex("0B0E1F"), 0.45, math.max(3, d // 22) },
			{ "Face", Color3.fromHex("5BE36C"), 0, 0 },
		}
	do
		local f = make("Frame", {
			Name = layer[1] :: string,
			Position = UDim2.fromOffset(0, layer[4] :: number),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = z + i,
		}, c)
		for _, bar in { { "Short", 0.3, 0.62, 0.42, 45 }, { "Long", 0.6, 0.48, 0.78, -50 } } do
			local b = make("Frame", {
				Name = bar[1] :: string,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(bar[2] :: number, bar[3] :: number),
				Size = UDim2.new(bar[4] :: number, 0, 0.17, 0),
				Rotation = bar[5] :: number,
				BackgroundColor3 = layer[2] :: Color3,
				BackgroundTransparency = layer[3] :: number,
				BorderSizePixel = 0,
				ZIndex = z + i,
			}, f)
			make("UICorner", { CornerRadius = UDim.new(0, math.max(3, d // 24)) }, b)
		end
	end
	return c
end

-- a button holding a slanted price plate (Robux), a kicker over it
local function priceButton(
	p: Instance,
	name: string,
	kicker: string,
	amount: string,
	order: number
): TextButton
	local b = make("TextButton", {
		Name = name,
		LayoutOrder = order,
		Size = UDim2.fromOffset(230, 96),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 6,
	}, p)
	make("UIScale", { Name = "Pop" }, b)
	local plate = make("Frame", {
		Name = "Price",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(0, 62),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = GREEN,
		BorderSizePixel = 0,
		ZIndex = 7,
	}, b)
	slant(plate, GREEN, 62, 21)
	local row = frame(plate, "Row", {
		Size = UDim2.fromOffset(0, 62),
		AutomaticSize = Enum.AutomaticSize.X,
		ZIndex = 7,
	})
	make("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 6) }, row)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)
	make("ImageLabel", {
		Name = "Robux",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(36, 36),
		BackgroundTransparency = 1,
		Image = ROBUX,
		ImageColor3 = WHITE,
		ZIndex = 8,
	}, row)
	text(
		row,
		"Amount",
		amount,
		30,
		WHITE,
		{ LayoutOrder = 2, Size = UDim2.fromOffset(0, 62), ZIndex = 8 }
	)
	text(b, "Kicker", kicker, 15, WHITE, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -68),
		FontFace = Font.new(BX, BOLD),
		ZIndex = 8,
	})
	return b
end

local old = SG:FindFirstChild("BattlePass")
if old then
	old:Destroy()
end
local gui = make("ScreenGui", {
	Name = "BattlePass",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ScreenInsets = Enum.ScreenInsets.None,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 30,
	Enabled = false,
})
-- the coloured wash over the blurred world (the Shop's)
local wash = make("Frame", {
	Name = "Wash",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.3,
	BorderSizePixel = 0,
	ZIndex = 0,
}, gui)
make("UIGradient", {
	Rotation = 35,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, hex("3B1D63")),
		ColorSequenceKeypoint.new(0.55, hex("161A44")),
		ColorSequenceKeypoint.new(1, hex("0A1230")),
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

-- header + the round drawn-X close (Util/CloseButton)
text(canvas, "Title", "SEASON PASS", 60, WHITE, { Position = UDim2.fromOffset(X0, 34) })
text(canvas, "Sub", "SEASON 1  ·  ENDS IN 24D 6H", 16, ALLY, {
	Position = UDim2.fromOffset(X0 + 4, 100),
	FontFace = Font.new(BX, BOLD),
})
local close = make("TextButton", {
	Name = "Close",
	AnchorPoint = CENTRE,
	Position = UDim2.fromOffset(1830, 76),
	Size = UDim2.fromOffset(72, 72),
	BackgroundColor3 = CARD,
	BackgroundTransparency = 0.1,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 20,
}, canvas)
make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, close)
make("UIScale", { Name = "Pop" }, close)
local glyph = frame(close, "Glyph", {
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(30, 30),
	ZIndex = 21,
})
for _, r in { 45, -45 } do
	local bar = make("Frame", {
		Name = if r > 0 then "A" else "B",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(30, 5),
		Rotation = r,
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = 21,
	}, glyph)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, bar)
end

------------------------------------------------------------------- DETAIL
local detail = frame(canvas, "Detail", {
	Position = UDim2.fromOffset(X0, 140),
	Size = UDim2.fromOffset(W, 330),
	ZIndex = 2,
})
-- the picture: the controller puts an ItemStage in Stage for a skin, an image
-- in Art, or the coloured Card for a charm / emote
local show = frame(detail, "Show", { Size = UDim2.fromOffset(560, 300), ZIndex = 3 })
frame(show, "Stage", { Size = UDim2.fromScale(1, 1), ZIndex = 3 })
make("ImageLabel", {
	Name = "Art",
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(400, 260),
	BackgroundTransparency = 1,
	Image = "",
	ScaleType = Enum.ScaleType.Fit,
	ZIndex = 4,
}, show)
local card = make("Frame", {
	Name = "Card",
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(240, 240),
	BackgroundColor3 = hex("B58CFF"),
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 4,
}, show)
corner(card, 10)
text(card, "Kind", "CHARM", 20, INK, { Position = UDim2.fromOffset(20, 18), ZIndex = 5 })
make("UIScale", { Name = "Pop" }, show)
make("TextButton", {
	Name = "DragArea",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 6,
}, show)
-- the words
local tierChip = make("Frame", {
	Name = "Tier",
	Position = UDim2.fromOffset(592, 92),
	Size = UDim2.fromOffset(0, 32),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = ALLY,
	BorderSizePixel = 0,
	ZIndex = 4,
}, detail)
make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, tierChip)
slant(tierChip, ALLY, 32, 11)
text(tierChip, "Label", "TIER 2  ·  FREE", 15, INK, { Size = UDim2.fromOffset(0, 32), ZIndex = 5 })
text(
	detail,
	"Name",
	"STANDARD CASE",
	52,
	WHITE,
	{ Position = UDim2.fromOffset(588, 134), ZIndex = 4 }
)
text(detail, "Desc", "x1  ·  A CASE OF SKINS. SEE ITS CONTENTS FOR THE ODDS.", 18, MUTED, {
	Position = UDim2.fromOffset(592, 200),
	FontFace = Font.new(BX, BOLD),
	ZIndex = 4,
})
-- the actions, right-aligned; the controller shows the ones that apply
local actions = frame(detail, "Actions", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 200),
	Size = UDim2.fromOffset(0, 96),
	AutomaticSize = Enum.AutomaticSize.X,
	ZIndex = 5,
})
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	VerticalAlignment = Enum.VerticalAlignment.Bottom,
	Padding = UDim.new(0, 52),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, actions)
local contents = make("TextButton", {
	Name = "Contents",
	LayoutOrder = 1,
	Size = UDim2.fromOffset(180, 62),
	BackgroundColor3 = ALLY,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 7,
}, actions)
slant(contents, ALLY, 62, 21)
make("UIScale", { Name = "Pop" }, contents)
text(
	contents,
	"Label",
	"CONTENTS",
	22,
	INK,
	{ AnchorPoint = CENTRE, Position = UDim2.fromScale(0.5, 0.5), ZIndex = 8 }
)
priceButton(actions, "Skip", "+5 LEVELS", "499", 2)
priceButton(actions, "Unlock", "UNLOCK PREMIUM", "689", 3)
local claim = make("TextButton", {
	Name = "Claim",
	LayoutOrder = 4,
	Size = UDim2.fromOffset(200, 62),
	BackgroundColor3 = GOLD,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 7,
}, actions)
slant(claim, GOLD, 62, 21)
make("UIScale", { Name = "Pop" }, claim)
text(
	claim,
	"Label",
	"CLAIM",
	28,
	INK,
	{ AnchorPoint = CENTRE, Position = UDim2.fromScale(0.5, 0.5), ZIndex = 8 }
)

------------------------------------------------------------------- LEVEL ROW
local levelRow = frame(
	canvas,
	"Level",
	{ Position = UDim2.fromOffset(X0, 488), Size = UDim2.fromOffset(W, 100), ZIndex = 2 }
)
local box = make("Frame", {
	Name = "Box",
	Size = UDim2.fromOffset(150, 100),
	BackgroundColor3 = CARD,
	BackgroundTransparency = CARD_T,
	BorderSizePixel = 0,
	ZIndex = 3,
}, levelRow)
corner(box)
text(
	box,
	"Value",
	"2",
	56,
	WHITE,
	{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), ZIndex = 4 }
)
text(box, "Label", "LEVEL", 16, MUTED, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -10),
	FontFace = Font.new(BX, BOLD),
	ZIndex = 4,
})
-- what levels you up, over the bar
local tip = make("Frame", {
	Name = "Tip",
	Position = UDim2.fromOffset(170, 0),
	Size = UDim2.fromOffset(0, 40),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	ZIndex = 3,
}, levelRow)
corner(tip, 6)
make("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, tip)
text(tip, "Text", "WIN 9 / 25 ROUNDS OR PLAY 6.9 / 20 MINUTES TO LEVEL UP", 16, INK, {
	Size = UDim2.fromOffset(0, 40),
	ZIndex = 4,
})
local track = make("Frame", {
	Name = "Bar",
	Position = UDim2.fromOffset(170, 58),
	Size = UDim2.fromOffset(700, 30),
	BackgroundColor3 = CARD,
	BackgroundTransparency = 0.1,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	ZIndex = 3,
}, levelRow)
corner(track, 6)
local fill = make("Frame", {
	Name = "Fill",
	Size = UDim2.fromScale(0.36, 1),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	ZIndex = 4,
}, track)
corner(fill, 6)
text(track, "Next", "LEVEL 3", 15, MUTED, {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -12, 0.5, 0),
	FontFace = Font.new(BX, BOLD),
	ZIndex = 5,
})
-- page arrows
for i, n in { "Prev", "Next" } do
	local b = make("TextButton", {
		Name = n,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, if i == 1 then -112 else 0, 0, 58),
		Size = UDim2.fromOffset(100, 70),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 3,
	}, levelRow)
	corner(b)
	make("UIScale", { Name = "Pop" }, b)
	text(b, "Glyph", if i == 1 then "«" else "»", 44, INK, {
		AnchorPoint = CENTRE,
		Position = UDim2.new(0.5, 0, 0.5, -3),
		ZIndex = 4,
	})
end

------------------------------------------------------------------- TRACKS
local tracks = frame(
	canvas,
	"Tracks",
	{ Position = UDim2.fromOffset(X0, 604), Size = UDim2.fromOffset(W, 450), ZIndex = 2 }
)
local CW, CH, G = 192, 178, 14
local cellsX = 166 -- after the badges
local function badge(name: string, label: string, y: number, fillC: Color3, ink: Color3)
	local b = make("TextButton", {
		Name = name,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.fromOffset(150, CH),
		BackgroundColor3 = fillC,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 3,
	}, tracks)
	corner(b)
	make("UIScale", { Name = "Pop" }, b)
	text(
		b,
		"Label",
		label,
		24,
		ink,
		{ AnchorPoint = CENTRE, Position = UDim2.fromScale(0.5, 0.42), ZIndex = 4 }
	)
	text(b, "Sub", "TRACK", 14, ink, {
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.62),
		TextTransparency = 0.35,
		FontFace = Font.new(BX, BOLD),
		ZIndex = 4,
	})
	return b
end
badge("FreeBadge", "FREE", 0, WHITE, INK)
local prem = badge("PremiumBadge", "PREMIUM", CH + G, GOLD, INK)
-- a small drawn lock on the premium badge while it isn't owned
local lock = frame(prem, "Lock", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -14),
	Size = UDim2.fromOffset(24, 30),
	ZIndex = 4,
})
local shackle = make("Frame", {
	Name = "Shackle",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0),
	Size = UDim2.fromOffset(16, 22),
	BackgroundTransparency = 1,
	ZIndex = 4,
}, lock)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, shackle)
make("UIStroke", { Thickness = 4, Color = INK }, shackle)
local lb = make("Frame", {
	Name = "Body",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromScale(0.5, 1),
	Size = UDim2.fromOffset(24, 18),
	BackgroundColor3 = INK,
	BorderSizePixel = 0,
	ZIndex = 5,
}, lock)
corner(lb, 4)

-- 7 columns: a free cell, a premium cell, the tier number and its bar
for col = 1, 7 do
	local x = cellsX + (col - 1) * (CW + G)
	for _, t in { { "Free", 0, CARD, CARD_T }, { "Premium", CH + G, PREMIUM_CELL, 0.1 } } do
		local cell = make("TextButton", {
			Name = t[1] .. col,
			Position = UDim2.fromOffset(x, t[2] :: number),
			Size = UDim2.fromOffset(CW, CH),
			BackgroundColor3 = t[3] :: Color3,
			BackgroundTransparency = t[4] :: number,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 3,
		}, tracks)
		corner(cell)
		make("UIScale", { Name = "Pop" }, cell)
		make("ImageLabel", {
			Name = "Art",
			AnchorPoint = CENTRE,
			Position = UDim2.fromScale(0.5, 0.44),
			Size = UDim2.fromOffset(150, 110),
			BackgroundTransparency = 1,
			Image = "",
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 4,
		}, cell)
		local swatch = make("Frame", {
			Name = "Swatch", -- charms / emotes / Mods until they have art
			AnchorPoint = CENTRE,
			Position = UDim2.fromScale(0.5, 0.42),
			Size = UDim2.fromOffset(96, 96),
			BackgroundColor3 = hex("B58CFF"),
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 4,
		}, cell)
		corner(swatch, 8)
		text(swatch, "Kind", "CHARM", 12, INK, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			ZIndex = 5,
		})
		text(cell, "Name", "x100", 17, WHITE, {
			AutomaticSize = Enum.AutomaticSize.None,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.new(1, -12, 0, 22),
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 5,
		})
		-- reached but not taken
		local claimTag = make("Frame", {
			Name = "ClaimTag",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 0),
			Size = UDim2.fromOffset(0, 30),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = GOLD,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 7,
		}, cell)
		make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, claimTag)
		slant(claimTag, GOLD, 30, 10)
		text(claimTag, "Label", "CLAIM", 15, INK, { Size = UDim2.fromOffset(0, 30), ZIndex = 8 })
		-- taken: dimmed with a tick
		make("Frame", {
			Name = "Dim",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = hex("05060E"),
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 6,
		}, cell)
		local dimCorner = make("UICorner", { CornerRadius = UDim.new(0, 8) })
		dimCorner.Parent = cell:FindFirstChild("Dim")
		chunkyTick(cell, 118, 7, CENTRE, UDim2.fromScale(0.5, 0.46))
		-- the selection frame (four corner brackets), shown on the picked cell
		local sel =
			frame(cell, "Select", { Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 9 })
		for _, c in { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } do
			local bx, by = c[1], c[2]
			local br = frame(sel, string.format("C%d%d", bx, by), {
				AnchorPoint = Vector2.new(bx, by),
				Position = UDim2.new(bx, if bx == 0 then -8 else 8, by, if by == 0 then -8 else 8),
				Size = UDim2.fromOffset(28, 28),
				ZIndex = 9,
			})
			make("Frame", {
				Name = "H",
				AnchorPoint = Vector2.new(bx, by),
				Position = UDim2.fromScale(bx, by),
				Size = UDim2.fromOffset(28, 5),
				BackgroundColor3 = WHITE,
				BorderSizePixel = 0,
				ZIndex = 9,
			}, br)
			make("Frame", {
				Name = "V",
				AnchorPoint = Vector2.new(bx, by),
				Position = UDim2.fromScale(bx, by),
				Size = UDim2.fromOffset(5, 28),
				BackgroundColor3 = WHITE,
				BorderSizePixel = 0,
				ZIndex = 9,
			}, br)
		end
	end
	-- the tier number and its bar
	local num = frame(tracks, "Tier" .. col, {
		Position = UDim2.fromOffset(x, 2 * CH + G + 14),
		Size = UDim2.fromOffset(CW, 44),
		ZIndex = 3,
	})
	text(
		num,
		"Number",
		tostring(col),
		22,
		WHITE,
		{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), ZIndex = 4 }
	)
	local bar = make("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 8),
		BackgroundColor3 = hex("2A3156"),
		BorderSizePixel = 0,
		ZIndex = 4,
	}, num)
	corner(bar, 4)
end

------------------------------------------------------------------- CONTENTS
-- a case reward's odds (the Shop's panel; rows from Util/OddsList)
make("Frame", {
	Name = "Dim",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = hex("05060E"),
	BackgroundTransparency = 0.35,
	BorderSizePixel = 0,
	Active = true,
	Visible = false,
	ZIndex = 30,
}, gui)
local pop = make("Frame", {
	Name = "PopupCanvas",
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(1920, 1080),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 31,
}, gui)
make("UIScale", { Name = "Fit" }, pop)
local odds = make("Frame", {
	Name = "OddsPanel",
	AnchorPoint = CENTRE,
	Position = UDim2.fromOffset(960, 540),
	Size = UDim2.fromOffset(860, 760),
	BackgroundColor3 = CARD,
	BorderSizePixel = 0,
	ZIndex = 32,
}, pop)
corner(odds, 10)
make("UIScale", { Name = "Pop" }, odds)
text(odds, "Title", "CONTENTS", 40, WHITE, { Position = UDim2.fromOffset(40, 26), ZIndex = 34 })
text(odds, "Sub", "STANDARD CASE", 18, MUTED, {
	Position = UDim2.fromOffset(42, 78),
	FontFace = Font.new(BX, BOLD),
	ZIndex = 34,
})
local oclose = make("TextButton", {
	Name = "Close",
	AnchorPoint = CENTRE,
	Position = UDim2.new(1, -46, 0, 46),
	Size = UDim2.fromOffset(60, 60),
	BackgroundColor3 = hex("1A2150"),
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 34,
}, odds)
make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, oclose)
make("UIScale", { Name = "Pop" }, oclose)
local og = frame(oclose, "Glyph", {
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(24, 24),
	ZIndex = 35,
})
for _, r in { 45, -45 } do
	local bar = make("Frame", {
		Name = if r > 0 then "A" else "B",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(24, 4),
		Rotation = r,
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = 35,
	}, og)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, bar)
end
local list = make("ScrollingFrame", {
	Name = "List",
	Position = UDim2.fromOffset(30, 118),
	Size = UDim2.new(1, -60, 1, -230),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = WHITE,
	ScrollBarImageTransparency = 0.5,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ZIndex = 33,
}, odds)
make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)
text(odds, "Note", "", 13, MUTED, {
	AutomaticSize = Enum.AutomaticSize.None,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 40, 1, -22),
	Size = UDim2.new(1, -80, 0, 76),
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Bottom,
	FontFace = Font.new(BX, BOLD),
	ZIndex = 34,
})

gui.Parent = SG
print("[BuildBattlePass] StarterGui.BattlePass built")
