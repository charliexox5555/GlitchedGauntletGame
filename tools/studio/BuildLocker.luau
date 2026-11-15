--!strict
-- Builds the Locker v3 (vault/02 Art/UI Locker.md) in the LOBBY place, Edit mode:
--   StarterGui.Locker              the screen (off; Controllers/LockerController opens it)
--   ReplicatedStorage.LockerStage  the stage values: GunSpot, CameraCFrame (the
--                                  controller draws the gun in a full-screen
--                                  ViewportFrame on flat RIVALS-style blue)
--   UiTemplates.Lobby.GunCard / SkinCard / GunGroup
-- Re-running replaces it all.
--
-- v3 (owner on the wired v2: "it should all be larger and look nicer like
-- Rivals... the selection should just be a coloured background... the guns
-- like in the game, the grey / white version... no wraps"): flat saturated
-- blue, no floor or plinth, a big gun on a diagonal; bigger cards on dark
-- see-through plates; the gun cards use the in-game gun icons (Theme.GUN); a
-- selected card is a solid colour (cyan for a gun, the skin's own colour for a
-- skin); SKIN / CHARM / FINISHER (no wraps). Still: no pills, outlines, glows
-- or edge strips; sharp slants only on the active thing; gold only on EQUIP.

local SG = game:GetService("StarterGui")
local RS = game:GetService("ReplicatedStorage")

local Theme = require(RS:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Theme"))

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
local CARD = hex("0B1236") -- dark see-through card plate over the blue
local CARD_T = 0.35
local ALLY, GOLD = hex("3FE0F2"), hex("FFC83D")
local MUTED, INK, WHITE = hex("AEB8D6"), hex("141A26"), Color3.new(1, 1, 1)
local CAP_R = "rbxassetid://130377997107460" -- slant cap (rotated 180 for the left end)
local CENTRE = Vector2.new(0.5, 0.5)

-- stage: just where the gun sits and where the camera looks from ---------------------
for _, where in { workspace, RS } do
	local old = where:FindFirstChild("LockerStage")
	if old then
		old:Destroy()
	end
end
local stage = make("Model", { Name = "LockerStage" })
make("CFrameValue", { Name = "GunSpot", Value = CFrame.new() }, stage)
make("CFrameValue", {
	Name = "CameraCFrame",
	-- looking a little above the gun, so it sits below the name
	Value = CFrame.lookAt(Vector3.new(0, 0.95, 11.5), Vector3.new(0, 0.45, 0)),
}, stage)
stage:SetAttribute("Background", hex("2340D8")) -- the flat blue behind the gun
stage.Parent = RS

-- screen ------------------------------------------------------------------------------
for _, n in { "Locker", "LockerMockup" } do
	local g = SG:FindFirstChild(n)
	if g then
		g:Destroy()
	end
end
local gui = make("ScreenGui", {
	Name = "Locker",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ScreenInsets = Enum.ScreenInsets.None,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 30,
	Enabled = false,
})

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
	make("UICorner", { CornerRadius = UDim.new(0, r or 4) }, p)
end
-- both ends lean the same way (the bar's parallelogram)
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

-- one design-size canvas (1920x1080), scaled to fit and centred
local canvas = make("Frame", {
	Name = "Canvas",
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(1920, 1080),
	BackgroundTransparency = 1,
	ZIndex = 1,
}, gui)
make("UIScale", { Name = "Fit" }, canvas)

-- the stage area: drag here to turn the gun (a button so it takes the click)
make("TextButton", {
	Name = "DragArea",
	Position = UDim2.fromOffset(560, 300),
	Size = UDim2.fromOffset(800, 600),
	BackgroundTransparency = 1,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 1,
}, canvas)

-- top left: LOCKER and the tabs (the active one on a cyan slab)
text(canvas, "Title", "LOCKER", 68, WHITE, { Position = UDim2.fromOffset(56, 34) })
local tabs = make("Frame", {
	Name = "Tabs",
	Position = UDim2.fromOffset(70, 122),
	Size = UDim2.fromOffset(0, 56),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
}, canvas)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 34),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, tabs)
for i, t in { "WEAPONS", "ABILITIES", "EMOTES" } do
	local on = i == 1
	local tab = make("TextButton", {
		Name = t,
		LayoutOrder = i,
		Size = UDim2.fromOffset(0, 56),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = ALLY,
		BackgroundTransparency = if on then 0 else 1,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 3,
	}, tabs)
	make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, tab)
	slant(tab, ALLY, 56, 18)
	for _, c in tab:GetChildren() do
		if c:IsA("ImageLabel") then
			c.ImageTransparency = if on then 0 else 1
		end
	end
	text(
		tab,
		"Label",
		t,
		24,
		if on then INK else MUTED,
		{ Size = UDim2.fromOffset(0, 56), ZIndex = 5 }
	)
end
-- top right: a round close
local close = make("TextButton", {
	Name = "Close",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromOffset(1866, 40),
	Size = UDim2.fromOffset(72, 72),
	BackgroundColor3 = CARD,
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 3,
}, canvas)
make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, close)
text(
	close,
	"X",
	"X",
	26,
	WHITE,
	{ AnchorPoint = CENTRE, Position = UDim2.fromScale(0.5, 0.5), ZIndex = 5 }
)

-- left: the guns, by class (cards are built from the templates by the controller)
local GW, GH, GAP = 236, 128, 12
local guns = make("ScrollingFrame", {
	Name = "Guns",
	Position = UDim2.fromOffset(56, 206),
	Size = UDim2.fromOffset(2 * GW + GAP + 16, 846),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 5,
	ScrollBarImageColor3 = WHITE,
	ScrollBarImageTransparency = 0.5,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ZIndex = 2,
}, canvas)
make("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, guns)

-- centre: the gun's name, the skin on it, the drag hint
text(canvas, "GunName", "VANDAL", 104, WHITE, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromOffset(960, 150),
	TextStrokeTransparency = 0.85,
})
local skinTag = make("Frame", {
	Name = "SkinTag",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromOffset(960, 270),
	Size = UDim2.fromOffset(0, 42),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	ZIndex = 3,
}, canvas)
make("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, skinTag)
slant(skinTag, WHITE, 42, 14)
text(
	skinTag,
	"Label",
	"DEFAULT  ·  RIFLE",
	19,
	INK,
	{ Size = UDim2.fromOffset(0, 42), ZIndex = 5 }
)
text(canvas, "Hint", "DRAG TO TURN  ·  SCROLL TO ZOOM", 14, MUTED, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromOffset(960, 924),
})

-- right: the skins of the selected gun
local SW, SH = 236, 184
text(canvas, "SkinsHead", "SKINS", 22, WHITE, { Position = UDim2.fromOffset(1356, 152) })
text(canvas, "SkinsCount", "10 OWNED", 15, MUTED, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromOffset(1864, 158),
})
local skins = make("ScrollingFrame", {
	Name = "Skins",
	Position = UDim2.fromOffset(1356, 196),
	Size = UDim2.fromOffset(2 * SW + GAP + 16, 662),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 5,
	ScrollBarImageColor3 = WHITE,
	ScrollBarImageTransparency = 0.5,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ZIndex = 2,
}, canvas)
make("UIGridLayout", {
	CellSize = UDim2.fromOffset(SW, SH),
	CellPadding = UDim2.fromOffset(GAP, GAP),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, skins)

-- EQUIP: the one gold thing, big, with the » that says "go"
local equip = make("TextButton", {
	Name = "Equip",
	Position = UDim2.fromOffset(1384, 880),
	Size = UDim2.fromOffset(2 * SW + GAP - 44, 100),
	BackgroundColor3 = GOLD,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 3,
}, canvas)
slant(equip, GOLD, 100, 28)
text(
	equip,
	"Label",
	"EQUIP",
	42,
	INK,
	{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 20, 0.5, -10), ZIndex = 5 }
)
text(
	equip,
	"Sub",
	"PRISM VANDAL",
	14,
	INK,
	{ Position = UDim2.new(0, 22, 0.5, 16), TextTransparency = 0.3, ZIndex = 5 }
)
text(
	equip,
	"Go",
	"»",
	66,
	INK,
	{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, -6), ZIndex = 5 }
)

-- bottom centre: what you're changing (no wraps), the active one on a white slab
local kinds = make("Frame", {
	Name = "Kinds",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromOffset(960, 964),
	Size = UDim2.fromOffset(0, 58),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
}, canvas)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 40),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, kinds)
for i, k in { "SKIN", "CHARM", "FINISHER" } do
	local on = i == 1
	local b = make("TextButton", {
		Name = k,
		LayoutOrder = i,
		Size = UDim2.fromOffset(0, 58),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = WHITE,
		BackgroundTransparency = if on then 0 else 1,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 3,
	}, kinds)
	make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, b)
	if on then
		slant(b, WHITE, 58, 18)
	end
	text(b, "Label", k, 24, if on then INK else WHITE, {
		Size = UDim2.fromOffset(0, 58),
		TextTransparency = if on then 0 else 0.4,
		ZIndex = 5,
	})
	if not on then
		text(
			b,
			"Soon",
			"SOON",
			11,
			ALLY,
			{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, -8), ZIndex = 5 }
		)
	end
end
-- the other tabs until they're built
text(
	canvas,
	"Soon",
	"SOON",
	44,
	WHITE,
	{ AnchorPoint = CENTRE, Position = UDim2.fromOffset(960, 540), Visible = false, ZIndex = 6 }
)

-- templates -----------------------------------------------------------------------------
local folder = RS:WaitForChild("UiTemplates"):WaitForChild("Lobby")
for _, n in { "GunCard", "SkinCard", "GunGroup" } do
	local t = folder:FindFirstChild(n)
	if t then
		t:Destroy()
	end
end
-- GunGroup: a class header and a 2-wide grid
local group = make("Frame", {
	Name = "GunGroup",
	Size = UDim2.fromOffset(2 * GW + GAP, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
}, folder)
make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, group)
text(group, "Head", "RIFLES", 16, WHITE, { LayoutOrder = 0, TextTransparency = 0.25, ZIndex = 3 })
local grid = make("Frame", {
	Name = "Grid",
	LayoutOrder = 1,
	Size = UDim2.fromOffset(2 * GW + GAP, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
}, group)
make("UIGridLayout", {
	CellSize = UDim2.fromOffset(GW, GH),
	CellPadding = UDim2.fromOffset(GAP, GAP),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, grid)
-- GunCard: the in-game gun icon (grey / white render), the name, and a small
-- block in the equipped skin's colour; selected = a solid cyan card
local gunCard = make("TextButton", {
	Name = "GunCard",
	BackgroundColor3 = CARD,
	BackgroundTransparency = CARD_T,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 3,
}, folder)
corner(gunCard)
make("ImageLabel", {
	Name = "Icon",
	Position = UDim2.fromOffset(14, 8),
	Size = UDim2.fromOffset(GW - 28, 84),
	BackgroundTransparency = 1,
	Image = Theme.GUN.Vandal,
	ScaleType = Enum.ScaleType.Fit,
	ZIndex = 4,
}, gunCard)
text(gunCard, "Name", "VANDAL", 17, WHITE, { Position = UDim2.fromOffset(16, GH - 34), ZIndex = 5 })
local chip = make("Frame", {
	Name = "Skin",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -16, 1, -12),
	Size = UDim2.fromOffset(30, 20),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 5,
}, gunCard)
slant(chip, WHITE, 20, 7)
-- SkinCard: a live picture of the skin (the controller adds it), the name with
-- a small block in the skin's colour; selected = the whole card in its colour
local skinCard = make("TextButton", {
	Name = "SkinCard",
	BackgroundColor3 = CARD,
	BackgroundTransparency = CARD_T,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 3,
}, folder)
corner(skinCard)
local swatch = make("Frame", {
	Name = "Swatch",
	Position = UDim2.fromOffset(18, SH - 38),
	Size = UDim2.fromOffset(26, 22),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	ZIndex = 5,
}, skinCard)
slant(swatch, WHITE, 22, 7)
text(skinCard, "Name", "PRISM", 17, WHITE, { Position = UDim2.fromOffset(56, SH - 40), ZIndex = 5 })
local eq = make("Frame", {
	Name = "Equipped",
	Position = UDim2.fromOffset(16, 12),
	Size = UDim2.fromOffset(0, 24),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 7,
}, skinCard)
make("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) }, eq)
slant(eq, WHITE, 24, 7)
text(eq, "Label", "EQUIPPED", 12, INK, { Size = UDim2.fromOffset(0, 24), ZIndex = 8 })

gui.Parent = SG
print("Locker v3 built (StarterGui.Locker off, ReplicatedStorage.LockerStage, templates)")
