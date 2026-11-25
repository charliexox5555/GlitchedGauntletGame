--!strict
-- Builds the real draft screen (vault/02 Art/UI Draft Screen.md, v4 look) in the
-- match place as StarterGui.DraftScreen. Studio owns it; this is its backup.
-- Paste into the Studio command bar (Edit mode); refuses to run if it exists.
-- Behaviour: src/client/Util/DraftScreen.luau (fed by DraftController).
-- Desktop only for now: phones keep DraftController's own layout.
--
-- Every slot is fixed (3 guns, 3 columns, up to 3 paths per column), so the
-- script only fills and shows them. Each pickable thing is a transparent
-- TextButton (the hit area, never scaled) holding a centred CanvasGroup "Card"
-- with a "Pop" UIScale, so lifts and pops move from the middle.

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

local BX = "rbxassetid://12187365977" -- Rubik (UI Match Overhaul: was Builder Extended)
local XB, BD, SB = Enum.FontWeight.ExtraBold, Enum.FontWeight.Bold, Enum.FontWeight.SemiBold
local NAVY, PANEL = hex("262629"), hex("131316")
local CYAN, GOLD, BODY, MUTED, INK =
	hex("3FE0F2"), hex("FFC83D"), hex("D7DDE6"), hex("97979A"), hex("1A1A1D")
local WHITE = Color3.new(1, 1, 1)
local SHADOW = "rbxassetid://121253415859134"
local CAP_R, CAP_L = "rbxassetid://130377997107460", "rbxassetid://75584308608588"
local PREVIEW_ART = "rbxassetid://104192200505705" -- Updraft, replaced in play
local CENTRE = Vector2.new(0.5, 0.5)

local COL_W, GAP = 400, 28
local X0 = (1920 - (COL_W * 3 + GAP * 2)) / 2
local GUN_Y, GUN_H = 140, 96
local CARD_Y, CARD_H = 304, 500

assert(not SG:FindFirstChild("DraftScreen"), "StarterGui.DraftScreen already exists")

local function colX(i: number): number
	return X0 + (i - 1) * (COL_W + GAP)
end

local function label(
	p: Instance,
	name: string,
	s: string,
	size: number,
	color: Color3,
	weight: Enum.FontWeight,
	props: { [string]: any }?
): TextLabel
	local t = make("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, size + 4),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = s,
		FontFace = Font.new(BX, weight),
		TextSize = size,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 6,
	}, p)
	for k, v in props or {} do
		(t :: any)[k] = v
	end
	return t
end

-- A keycap: a face on a darker base; the script turns the face gold when picked.
local function keycap(p: Instance, s: string, w: number, h: number, props: { [string]: any }): Frame
	local k = make("Frame", {
		Name = "Key",
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = hex("0F0F12"),
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

local function shadow(p: Instance, w: number, h: number)
	make("ImageLabel", {
		Name = "Shadow",
		AnchorPoint = CENTRE,
		Position = UDim2.new(0.5, 0, 0.5, 10),
		Size = UDim2.new(1, 70, 1, 70),
		BackgroundTransparency = 1,
		Image = SHADOW,
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 0.35,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(48, 48, 80, 80),
		ZIndex = 0,
	}, p)
end

-- A pickable holder: the TextButton hit area + a centred CanvasGroup "Card".
local function holder(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	w: number,
	h: number,
	fill: Color3
): (TextButton, CanvasGroup)
	local b = make("TextButton", {
		Name = name,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 1,
	}, parent)
	shadow(b, w, h)
	local c = make("CanvasGroup", {
		Name = "Card",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = fill,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, b)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, c)
	make("UIScale", { Name = "Pop" }, c)
	return b, c
end

-- A slanted band: a rotated frame clipped by its CanvasGroup.
local function band(card: Instance, color: Color3, top: number)
	make("Frame", {
		Name = "Band",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, top),
		Size = UDim2.fromOffset(COL_W * 2, 260),
		Rotation = -4,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, card)
end

-- gui ---------------------------------------------------------------------------
local gui = make("ScreenGui", {
	Name = "DraftScreen",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ScreenInsets = Enum.ScreenInsets.None,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 8, -- under the top bar (9) and notifications (10)
	Enabled = false, -- DraftScreen shows it while the draft is open
})
make("TextButton", {
	Name = "Backdrop", -- Modal while open: frees the mouse in first person
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = hex("0A0A0D"),
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
	AutoButtonColor = false,
	Text = "",
}, gui)
local canvas = make("Frame", {
	Name = "Canvas",
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(1920, 1080),
	BackgroundTransparency = 1,
}, gui)
make("UIScale", { Name = "Fit" }, canvas)

-- guns
for i = 1, 3 do
	local b, c = holder(canvas, "Gun" .. i, colX(i), GUN_Y, COL_W, GUN_H, NAVY)
	make("ImageLabel", {
		Name = "Gun",
		AnchorPoint = CENTRE,
		Position = UDim2.new(0.5, 20, 0.5, -2),
		Size = UDim2.fromOffset(250, 70),
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 3,
	}, c)
	label(c, "GunName", "GUN", 15, WHITE, XB, { Position = UDim2.fromOffset(18, GUN_H - 30) })
	label(
		c,
		"Shield",
		"+25 SHIELD",
		12,
		CYAN,
		XB,
		{ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(COL_W - 16, GUN_H - 28) }
	)
	keycap(c, tostring(i), 24, 26, { Position = UDim2.fromOffset(12, 12) })
	b.Visible = true
end

-- ability columns
for i = 1, 3 do
	local col = make("Frame", {
		Name = "Col" .. i,
		Position = UDim2.fromOffset(colX(i), CARD_Y),
		Size = UDim2.fromOffset(COL_W, CARD_H),
		BackgroundTransparency = 1,
	}, canvas)
	-- a new ability: full-art card, slanted role band with the name
	local _, n = holder(col, "New", 0, 0, COL_W, CARD_H, PANEL)
	make("ImageLabel", {
		Name = "Art",
		Size = UDim2.fromOffset(COL_W, 330),
		BackgroundTransparency = 1,
		Image = PREVIEW_ART,
		ScaleType = Enum.ScaleType.Crop,
		ZIndex = 1,
	}, n)
	band(n, hex("2BD9A8"), 286)
	make("Frame", {
		Name = "Panel",
		Position = UDim2.fromOffset(0, 384),
		Size = UDim2.fromOffset(COL_W, 120),
		BackgroundColor3 = PANEL,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, n)
	label(n, "Title", "UPDRAFT", 36, WHITE, XB, { Position = UDim2.fromOffset(24, 306) })
	label(
		n,
		"Role",
		"MOBILITY",
		12,
		WHITE,
		XB,
		{ Position = UDim2.fromOffset(26, 350), TextTransparency = 0.2 }
	)
	label(n, "Note", "Launch straight up ~14 studs (works mid-air).", 16, BODY, SB, {
		Position = UDim2.fromOffset(24, 402),
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromOffset(COL_W - 48, 0),
		TextWrapped = true,
	})
	label(
		n,
		"Charges",
		"ONCE PER ROUND",
		12,
		MUTED,
		XB,
		{ Position = UDim2.fromOffset(24, CARD_H - 32) }
	)
	label(
		n,
		"Tag",
		"NEW",
		12,
		GOLD,
		XB,
		{ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(COL_W - 24, CARD_H - 32) }
	)
	-- upgrade paths: half-cards (the script sets their height and position)
	for p = 1, 3 do
		local h = 158
		local b, c = holder(col, "Path" .. p, 0, (p - 1) * (h + 13), COL_W, h, PANEL)
		b.Visible = false
		make("ImageLabel", {
			Name = "Art",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = PREVIEW_ART,
			ScaleType = Enum.ScaleType.Crop,
			ZIndex = 1,
		}, c)
		make("Frame", { -- the band (anchored to the card bottom, so any height works)
			Name = "Band",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 156),
			Size = UDim2.fromOffset(COL_W * 2, 260),
			Rotation = -4,
			BackgroundColor3 = hex("2BD9A8"),
			BorderSizePixel = 0,
			ZIndex = 2,
		}, c)
		make("Frame", {
			Name = "Panel",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = PANEL,
			BorderSizePixel = 0,
			ZIndex = 3,
		}, c)
		local function bottom(dy: number): UDim2
			return UDim2.new(0, 0, 1, dy)
		end
		label(c, "GlitchA", "PATH", 30, hex("00E5FF"), XB, {
			Position = bottom(-85) + UDim2.fromOffset(21, 0),
			TextTransparency = 0.1,
			ZIndex = 5,
			Visible = false,
		})
		label(c, "GlitchB", "PATH", 30, hex("FF8BE0"), XB, {
			Position = bottom(-83) + UDim2.fromOffset(27, 0),
			TextTransparency = 0.1,
			ZIndex = 5,
			Visible = false,
		})
		label(
			c,
			"Title",
			"PATH",
			30,
			WHITE,
			XB,
			{ Position = bottom(-84) + UDim2.fromOffset(24, 0) }
		)
		label(c, "Tag", "UPDRAFT  LV 2", 11, WHITE, XB, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -20, 1, -74),
			TextTransparency = 0.15,
		})
		label(c, "Stat", "PEAK  14 → 21 STUDS", 14, hex("2BD9A8"), XB, {
			Position = bottom(-29) + UDim2.fromOffset(24, 0),
			AutomaticSize = Enum.AutomaticSize.None,
			Size = UDim2.fromOffset(COL_W - 48, 18),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		if p < 3 then
			label(col, "Or" .. p, "OR", 11, MUTED, XB, {
				AnchorPoint = CENTRE,
				Position = UDim2.fromOffset(COL_W / 2, p * (h + 13) - 6),
				Visible = false,
			})
		end
	end
	-- MAXED: nothing left to upgrade in this slot
	local maxed = make("Frame", {
		Name = "Maxed",
		Size = UDim2.fromOffset(COL_W, CARD_H),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Visible = false,
	}, col)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, maxed)
	make("ImageLabel", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(COL_W / 2, 160),
		Size = UDim2.fromOffset(84, 84),
		BackgroundTransparency = 1,
		ImageColor3 = MUTED,
	}, maxed)
	label(
		maxed,
		"Title",
		"MAXED",
		34,
		WHITE,
		XB,
		{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(COL_W / 2, 262) }
	)
	label(
		maxed,
		"Sub",
		"UPDRAFT  ·  HIGH RISE LV 3",
		12,
		MUTED,
		XB,
		{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(COL_W / 2, 310) }
	)
	-- the column's key tab, centred on its top edge
	keycap(
		col,
		({ "Q", "E", "T" })[i],
		44,
		36,
		{ AnchorPoint = CENTRE, Position = UDim2.fromOffset(COL_W / 2, -2), ZIndex = 12 }
	)
end

-- LOCK IN: a gold block with slanted ends that names your picks
local lw, lh = COL_W + 40, 78
local lock = make("TextButton", {
	Name = "LockIn",
	Position = UDim2.fromOffset(colX(2) - 20, CARD_Y + CARD_H + 36),
	Size = UDim2.fromOffset(lw, lh),
	BackgroundTransparency = 1,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 2,
}, canvas)
local face = make("Frame", {
	Name = "Face",
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
}, lock)
make("UIScale", { Name = "Pop" }, face)
make("ImageLabel", {
	Name = "Shadow",
	AnchorPoint = CENTRE,
	Position = UDim2.new(0.5, 0, 0.5, 10),
	Size = UDim2.new(1, 30, 1, 70),
	BackgroundTransparency = 1,
	Image = SHADOW,
	ImageColor3 = Color3.new(0, 0, 0),
	ImageTransparency = 0.35,
	ScaleType = Enum.ScaleType.Slice,
	SliceCenter = Rect.new(48, 48, 80, 80),
	ZIndex = 0,
}, face)
make("Frame", {
	Name = "Body",
	Position = UDim2.fromOffset(26, 0),
	Size = UDim2.new(1, -52, 1, 0),
	BackgroundColor3 = GOLD,
	BorderSizePixel = 0,
	ZIndex = 2,
}, face)
make("ImageLabel", {
	Name = "CapL",
	Size = UDim2.fromOffset(28, lh),
	BackgroundTransparency = 1,
	Image = CAP_L,
	ImageColor3 = GOLD,
	ZIndex = 2,
}, face)
make("ImageLabel", {
	Name = "CapR",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.fromOffset(28, lh),
	BackgroundTransparency = 1,
	Image = CAP_R,
	ImageColor3 = GOLD,
	ZIndex = 2,
}, face)
label(
	face,
	"Title",
	"LOCK IN",
	30,
	INK,
	XB,
	{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(lw / 2, 12) }
)
label(face, "Picks", "PROWLER  +  HIGH RISE", 12, INK, XB, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromOffset(lw / 2, 48),
	TextTransparency = 0.3,
})
keycap(
	face,
	"ENTER",
	62,
	28,
	{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromOffset(lw - 40, lh / 2) }
)

-- the hint line under LOCK IN
label(canvas, "Hint", "Pick a gun (1, 2, 3) and one card (Q, E, T).", 14, MUTED, SB, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromOffset(960, CARD_Y + CARD_H + 36 + lh + 14),
})

-- the enemy's kit, right-aligned to the grid
local enemy = make("Frame", {
	Name = "Enemy",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromOffset(colX(3) + COL_W, CARD_Y + CARD_H + 52),
	Size = UDim2.fromOffset(0, 46),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
}, canvas)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, enemy)
label(enemy, "Label", "ENEMY", 12, MUTED, XB, { LayoutOrder = 0, Position = UDim2.new() })
for i = 1, 3 do
	local t = make("Frame", {
		Name = "E" .. i,
		LayoutOrder = i,
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = hex("2BD9A8"),
		BorderSizePixel = 0,
		Visible = false,
	}, enemy)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, t)
	make("ImageLabel", {
		Name = "Icon",
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(30, 30),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, t)
	label(
		t,
		"Level",
		"1",
		12,
		INK,
		XB,
		{ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -4, 1, 0), ZIndex = 3 }
	)
end

gui.Parent = SG
print("DraftScreen built")
