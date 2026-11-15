--!strict
-- Builds the Locker v4 (vault/02 Art/UI Locker.md) in the LOBBY place, Edit mode:
--   StarterGui.Locker              the screen (off; Controllers/LockerController opens it)
--   ReplicatedStorage.LockerStage  stage values: GunSpot, CameraCFrame, Background
--                                  (the controller draws the gun in a full-screen
--                                  ViewportFrame on flat RIVALS-style blue)
--   UiTemplates.Lobby.GunCard / GunGroup / SkinTile
-- Re-running replaces it all.
--
-- v4 (owner on v3: "too much UI... when you click skin it opens a separate
-- menu... your call"): two views.
--   Main: the gun list (left), the big gun centred, its name on top, and three
--         tiles at the bottom: SKIN (filled with the equipped skin's colour),
--         CHARM, FINISHER (soon). No skins column, no EQUIP button.
--   Skins (SKIN tile): the list and tiles slide away, the gun lifts, a tray
--         slides up from the bottom: « BACK and a strip of big skin tiles, each
--         filled with its skin's colour with a live picture; clicking one equips
--         it (a check on the equipped one), like RIVALS.
-- Still: no pills, outlines, glows or edge strips; sharp slants only on the
-- active thing; Builder Extended.

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
local CARD = hex("0B1236") -- dark see-through plate over the blue
local CARD_T = 0.35
local ALLY, GREEN = hex("3FE0F2"), hex("3FD68A")
local MUTED, INK, WHITE = hex("AEB8D6"), hex("141A26"), Color3.new(1, 1, 1)
local CAP_R = "rbxassetid://130377997107460" -- slant cap (rotated 180 for the left end)
local CENTRE = Vector2.new(0.5, 0.5)

-- stage values ------------------------------------------------------------------------
for _, where in { workspace, RS } do
	local old = where:FindFirstChild("LockerStage")
	if old then
		old:Destroy()
	end
end
local stage = make("Model", { Name = "LockerStage" })
make("CFrameValue", { Name = "GunSpot", Value = CFrame.new() }, stage)
-- the camera looks straight at the gun's centre, so it turns about the middle
make("CFrameValue", {
	Name = "CameraCFrame",
	Value = CFrame.lookAt(Vector3.new(0, 0.5, 12), Vector3.new(0, 0, 0)),
}, stage)
stage:SetAttribute("Background", hex("2340D8"))
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

local canvas = make("Frame", {
	Name = "Canvas",
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(1920, 1080),
	BackgroundTransparency = 1,
	ZIndex = 1,
}, gui)
make("UIScale", { Name = "Fit" }, canvas)

-- the stage area: drag here to turn the gun
make("TextButton", {
	Name = "DragArea",
	Position = UDim2.fromOffset(600, 240),
	Size = UDim2.fromOffset(1280, 620),
	BackgroundTransparency = 1,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 1,
}, canvas)

-- top left: LOCKER and the tabs
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

-- left: the guns by class
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

-- top centre (over the stage): the gun's name and the skin on it
local nameX = 1240 -- the middle of the stage area (right of the list)
text(
	canvas,
	"GunName",
	"VANDAL",
	84,
	WHITE,
	{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(nameX, 52) }
)
local skinTag = make("Frame", {
	Name = "SkinTag",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromOffset(nameX, 150),
	Size = UDim2.fromOffset(0, 40),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	ZIndex = 3,
}, canvas)
make("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, skinTag)
slant(skinTag, WHITE, 40, 14)
text(
	skinTag,
	"Label",
	"DEFAULT  ·  RIFLE",
	18,
	INK,
	{ Size = UDim2.fromOffset(0, 40), ZIndex = 5 }
)

-- bottom centre of the stage: SKIN / CHARM / FINISHER tiles
local kinds = make("Frame", {
	Name = "Kinds",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromOffset(nameX, 1040),
	Size = UDim2.fromOffset(0, 130),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
}, canvas)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Bottom,
	Padding = UDim.new(0, 18),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, kinds)
for i, k in { "SKIN", "CHARM", "FINISHER" } do
	local on = i == 1
	local tile = make("TextButton", {
		Name = k,
		LayoutOrder = i,
		Size = UDim2.fromOffset(200, 130),
		BackgroundColor3 = if on then WHITE else CARD,
		BackgroundTransparency = if on then 0 else CARD_T,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 3,
	}, kinds)
	corner(tile)
	text(tile, "Label", k, 24, if on then INK else WHITE, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -12),
		TextTransparency = if on then 0 else 0.4,
		ZIndex = 5,
	})
	text(tile, "Value", if on then "DEFAULT" else "SOON", 13, if on then INK else ALLY, {
		Position = UDim2.fromOffset(16, 14),
		TextTransparency = if on then 0.25 else 0,
		ZIndex = 5,
	})
end
text(canvas, "Hint", "DRAG TO TURN  ·  SCROLL TO ZOOM", 14, MUTED, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromOffset(nameX, 892),
})

-- the skins tray (hidden until SKIN): « BACK and a strip of skin tiles
local TW, TH = 168, 188
local tray = make("Frame", {
	Name = "Tray",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromOffset(960, 1052),
	Size = UDim2.fromOffset(1760, 300),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 2,
}, canvas)
local back = make("TextButton", {
	Name = "Back",
	Position = UDim2.fromOffset(16, 0),
	Size = UDim2.fromOffset(190, 64),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 3,
}, tray)
slant(back, WHITE, 64, 20)
text(
	back,
	"Label",
	"«  BACK",
	24,
	INK,
	{ AnchorPoint = CENTRE, Position = UDim2.fromScale(0.5, 0.5), ZIndex = 5 }
)
text(tray, "Head", "SKINS", 24, WHITE, { Position = UDim2.fromOffset(250, 18), ZIndex = 4 })
text(tray, "Count", "10 OWNED", 15, MUTED, { Position = UDim2.fromOffset(372, 24), ZIndex = 4 })
local strip = make("ScrollingFrame", {
	Name = "Strip",
	Position = UDim2.fromOffset(0, 84),
	Size = UDim2.fromOffset(1760, TH + 22),
	BackgroundColor3 = CARD,
	BackgroundTransparency = CARD_T,
	BorderSizePixel = 0,
	ScrollBarThickness = 5,
	ScrollBarImageColor3 = WHITE,
	ScrollBarImageTransparency = 0.5,
	ScrollingDirection = Enum.ScrollingDirection.X,
	AutomaticCanvasSize = Enum.AutomaticSize.X,
	CanvasSize = UDim2.new(),
	ZIndex = 2,
}, tray)
corner(strip)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 12),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, strip)
make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, strip)

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
for _, n in { "GunCard", "SkinCard", "GunGroup", "SkinTile" } do
	local t = folder:FindFirstChild(n)
	if t then
		t:Destroy()
	end
end
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
-- SkinTile: filled with the skin's colour (the controller sets it), a live
-- picture, the name; a round check on the equipped one
local tile = make("TextButton", {
	Name = "SkinTile",
	Size = UDim2.fromOffset(TW, TH),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 3,
}, folder)
corner(tile)
make("Frame", {
	Name = "Shade", -- darkens the lower part so the name reads on any colour
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 46),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.55,
	BorderSizePixel = 0,
	ZIndex = 4,
}, tile)
text(tile, "Name", "PRISM", 15, WHITE, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -13),
	ZIndex = 6,
})
local check = make("Frame", {
	Name = "Check",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -8, 0, 8),
	Size = UDim2.fromOffset(34, 34),
	BackgroundColor3 = GREEN,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 7,
}, tile)
make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, check)
-- a drawn tick (two bars), so it doesn't depend on a font glyph
make("Frame", {
	Name = "Short",
	AnchorPoint = CENTRE,
	Position = UDim2.fromOffset(12, 19),
	Size = UDim2.fromOffset(10, 4),
	Rotation = 45,
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	ZIndex = 8,
}, check)
make("Frame", {
	Name = "Long",
	AnchorPoint = CENTRE,
	Position = UDim2.fromOffset(20, 16),
	Size = UDim2.fromOffset(18, 4),
	Rotation = -50,
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	ZIndex = 8,
}, check)

gui.Parent = SG
print("Locker v4 built (StarterGui.Locker off, ReplicatedStorage.LockerStage, templates)")
