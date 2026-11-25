--!strict
-- Builds the Locker v5 (vault/02 Art/UI Locker.md) in the LOBBY place, Edit mode:
--   StarterGui.Locker              the screen (off; Controllers/LockerController opens it)
--   ReplicatedStorage.LockerStage  stage values: GunSpot, CameraCFrame, Background
--                                  (the controller draws the gun in a transparent
--                                  full-screen ViewportFrame over Backdrop)
--   UiTemplates.Lobby.GunCard / GunGroup / SkinTile / SkinEmblem
-- Re-running replaces it all.
--
-- v5 (owner: "a bit unprofessional"; skins need an identity besides colour,
-- and the skins list looked off): a backdrop with depth (shade top and bottom,
-- a floor shadow under the gun), a dark side panel to the screen edges, gun
-- cards sized by class with the equipped skin's emblem and name, a header of
-- class / name / skin emblem, a real SKIN tile, and dark skin tiles with a
-- big picture, the line's emblem and name (the previewed one fills with the
-- line's colour). Each skin line has an emblem (Shared/Locker.EMBLEMS).
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

local BX = "rbxassetid://12187365977" -- Rubik (owner pick 2026-11-16, after RIVALS): Heavy headings, Bold words
local XB = Enum.FontWeight.Heavy
local CARD = hex("141417") -- dark see-through plate over the blue

local ALLY = hex("3FE0F2")
local MUTED, INK, WHITE = hex("B8B8BB"), hex("1A1A1D"), Color3.new(1, 1, 1)
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

local BOLD = Enum.FontWeight.Bold
local SIDE = hex("121215") -- the left panel

-- behind the gun: the stage colour, a soft shade top and bottom, and a floor
-- shadow under the gun (the controller draws the gun in a transparent
-- ViewportFrame at ZIndex 1, between this and the Canvas)
local backdrop = make("Frame", {
	Name = "Backdrop",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.3, -- the blurred lobby shows through (owner: "less flat blue")
	BorderSizePixel = 0,
	ZIndex = 0,
}, gui)
make("UIGradient", {
	Rotation = 35,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, hex("2E2E31")),
		ColorSequenceKeypoint.new(0.55, hex("1E1E21")),
		ColorSequenceKeypoint.new(1, hex("131316")),
	}),
}, backdrop)
local shade = make("Frame", {
	Name = "Shade",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = hex("0D0D10"),
	BorderSizePixel = 0,
	ZIndex = 0,
}, backdrop)
make("UIGradient", {
	Rotation = 90,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.3, 1),
		NumberSequenceKeypoint.new(0.62, 1),
		NumberSequenceKeypoint.new(1, 0.35),
	}),
}, shade)
local backCanvas = make("Frame", {
	Name = "BackCanvas",
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(1920, 1080),
	BackgroundTransparency = 1,
	ZIndex = 0,
}, backdrop)
make("UIScale", { Name = "Fit" }, backCanvas)
-- the room's light behind the gun: a soft radial (art-source/ui/plates/
-- radial_light.png), tinted with the skin line's colour by the controller
make("ImageLabel", {
	Name = "Light",
	AnchorPoint = CENTRE,
	Position = UDim2.fromOffset(1240, 440),
	Size = UDim2.fromOffset(1500, 1000),
	BackgroundTransparency = 1,
	Image = "rbxassetid://111400909546922",
	ImageColor3 = hex("C8C8D0"),
	ImageTransparency = 0.84,
	ZIndex = 0,
}, backCanvas)
local floor = make("Frame", {
	Name = "Floor",
	AnchorPoint = CENTRE,
	Position = UDim2.fromOffset(1240, 720),
	Size = UDim2.fromOffset(520, 44),
	BackgroundColor3 = hex("0D0D10"),
	BackgroundTransparency = 0.62,
	BorderSizePixel = 0,
	ZIndex = 0,
}, backCanvas)
make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, floor)
make("UIGradient", {
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0.55),
		NumberSequenceKeypoint.new(0.5, 0.2),
		NumberSequenceKeypoint.new(0.75, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	}),
}, floor)

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
			{ "Shadow", Color3.fromHex("0F0F12"), 0.45, math.max(3, d // 22) },
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

local canvas = make("Frame", {
	Name = "Canvas",
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(1920, 1080),
	BackgroundTransparency = 1,
	ZIndex = 2,
}, gui)
make("UIScale", { Name = "Fit" }, canvas)

-- the stage area: drag here to turn the gun
make("TextButton", {
	Name = "DragArea",
	Position = UDim2.fromOffset(620, 230),
	Size = UDim2.fromOffset(1240, 600),
	BackgroundTransparency = 1,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 1,
}, canvas)

-- left: a dark panel, edge to edge top and bottom (and off the left edge on
-- wide screens), behind the title, tabs and guns
local PW = 580
make("Frame", {
	Name = "Side",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, -400, 0.5, 0),
	Size = UDim2.new(0, PW + 400, 1, 400),
	BackgroundColor3 = SIDE,
	BackgroundTransparency = 0.3,
	BorderSizePixel = 0,
	ZIndex = 1,
}, canvas)
text(canvas, "Title", "LOCKER", 64, WHITE, { Position = UDim2.fromOffset(52, 36) })
local tabs = make("Frame", {
	Name = "Tabs",
	Position = UDim2.fromOffset(64, 118),
	Size = UDim2.fromOffset(0, 52),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
}, canvas)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 30),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, tabs)
for i, t in { "WEAPONS", "ABILITIES", "EMOTES" } do
	local on = i == 1
	local tab = make("TextButton", {
		Name = t,
		LayoutOrder = i,
		Size = UDim2.fromOffset(0, 52),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = ALLY,
		BackgroundTransparency = if on then 0 else 1,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 3,
	}, tabs)
	make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, tab)
	slant(tab, ALLY, 52, 17)
	for _, c in tab:GetChildren() do
		if c:IsA("ImageLabel") then
			c.ImageTransparency = if on then 0 else 1
		end
	end
	text(
		tab,
		"Label",
		t,
		22,
		if on then INK else MUTED,
		{ Size = UDim2.fromOffset(0, 52), ZIndex = 5 }
	)
end

-- the guns by class: a scrolling list down to the bottom edge
local GW, GH, GAP = 248, 150, 12 -- 150 tall: room for the gun pictures (shared/ItemIcons)
local guns = make("ScrollingFrame", {
	Name = "Guns",
	Position = UDim2.fromOffset(40, 196),
	Size = UDim2.fromOffset(2 * GW + GAP + 24, 1080 - 196),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 0, -- no visible bar (owner, 2026-11-16)
	ScrollBarImageColor3 = WHITE,
	ScrollBarImageTransparency = 1, -- Thickness 0 still drew a hairline
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ZIndex = 2,
}, canvas)
make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingBottom = UDim.new(0, 40) }, guns)
make("UIListLayout", { Padding = UDim.new(0, 20), SortOrder = Enum.SortOrder.LayoutOrder }, guns)

-- the stage: the gun's class, its name, and the skin it wears (emblem + name)
local nameX = 1240 -- the middle of the stage area (right of the panel)
text(canvas, "GunClass", "RIFLE", 18, ALLY, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromOffset(nameX, 44),
	ZIndex = 4,
})
text(canvas, "GunName", "HAVOC", 84, WHITE, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromOffset(nameX, 66),
})
local skinRow = make("Frame", {
	Name = "SkinTag",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromOffset(nameX, 162),
	Size = UDim2.fromOffset(0, 34),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
	ZIndex = 3,
}, canvas)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 10),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, skinRow)
text(
	skinRow,
	"Label",
	"INKSHIFT",
	22,
	WHITE,
	{ LayoutOrder = 2, Size = UDim2.fromOffset(0, 34), ZIndex = 5 }
)

-- bottom of the stage: SKIN (the equipped skin; opens the skins), CHARM, FINISHER
local kinds = make("Frame", {
	Name = "Kinds",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromOffset(nameX, 1036),
	Size = UDim2.fromOffset(0, 120),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
}, canvas)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Bottom,
	Padding = UDim.new(0, 14),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, kinds)
local skinTile = make("TextButton", {
	Name = "SKIN",
	LayoutOrder = 1,
	Size = UDim2.fromOffset(380, 120),
	BackgroundColor3 = CARD,
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 3,
}, kinds)
corner(skinTile, 8)
text(
	skinTile,
	"Label",
	"SKIN",
	14,
	MUTED,
	{ Position = UDim2.fromOffset(112, 26), FontFace = Font.new(BX, BOLD) }
)
text(skinTile, "Value", "INKSHIFT", 28, WHITE, { Position = UDim2.fromOffset(112, 50) })
text(skinTile, "Go", "»", 34, WHITE, {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -24, 0.5, -2),
})
for i, k in { "CHARM", "FINISHER" } do
	local tile = make("TextButton", {
		Name = k,
		LayoutOrder = 1 + i,
		Size = UDim2.fromOffset(190, 120),
		BackgroundColor3 = CARD,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 3,
	}, kinds)
	corner(tile, 8)
	text(
		tile,
		"Value",
		"SOON",
		13,
		ALLY,
		{ Position = UDim2.fromOffset(20, 22), FontFace = Font.new(BX, BOLD) }
	)
	text(tile, "Label", k, 22, WHITE, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -20),
		TextTransparency = 0.45,
	})
end
text(canvas, "Hint", "DRAG TO TURN  ·  SCROLL TO ZOOM", 15, WHITE, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromOffset(nameX, 892),
	TextTransparency = 0.45,
	FontFace = Font.new(BX, BOLD),
})

-- the round close button: a drawn X (Util/CloseButton animates it; same as
-- tools/studio/BuildLobbyMenus.luau)
local close = make("TextButton", {
	Name = "Close",
	AnchorPoint = CENTRE,
	Position = UDim2.fromOffset(1830, 76),
	Size = UDim2.fromOffset(72, 72),
	BackgroundColor3 = CARD,
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 3,
}, canvas)
make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, close)
make("UIScale", { Name = "Pop" }, close)
local glyph = make("Frame", {
	Name = "Glyph",
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(30, 30),
	BackgroundTransparency = 1,
	ZIndex = 5,
}, close)
for _, r in { 45, -45 } do
	local bar = make("Frame", {
		Name = if r > 0 then "A" else "B",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(30, 5),
		Rotation = r,
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, glyph)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, bar)
end

-- the skins view (SKIN): « BACK, the title and a row of big skin tiles along
-- the bottom, straight on the blue (no box around them)
local TW, TH = 216, 232
local tray = make("Frame", {
	Name = "Tray",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromOffset(960, 1044),
	Size = UDim2.fromOffset(1840, 350),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 2,
}, canvas)
local back = make("TextButton", {
	Name = "Back",
	Position = UDim2.fromOffset(16, 0),
	Size = UDim2.fromOffset(176, 58),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 3,
}, tray)
slant(back, WHITE, 58, 19)
text(
	back,
	"Label",
	"«  BACK",
	22,
	INK,
	{ AnchorPoint = CENTRE, Position = UDim2.fromScale(0.5, 0.5), ZIndex = 5 }
)
text(tray, "Head", "SKINS", 30, WHITE, { Position = UDim2.fromOffset(232, 10), ZIndex = 4 })
text(tray, "Count", "10 OWNED", 16, WHITE, {
	Position = UDim2.fromOffset(372, 20),
	TextTransparency = 0.45,
	FontFace = Font.new(BX, BOLD),
	ZIndex = 4,
})
local strip = make("ScrollingFrame", {
	Name = "Strip",
	Position = UDim2.fromOffset(0, 72),
	Size = UDim2.fromOffset(1840, TH + 26),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 0, -- no visible bar (owner, 2026-11-16)
	ScrollBarImageColor3 = WHITE,
	ScrollBarImageTransparency = 1, -- Thickness 0 still drew a hairline
	ScrollingDirection = Enum.ScrollingDirection.X,
	AutomaticCanvasSize = Enum.AutomaticSize.X,
	CanvasSize = UDim2.new(),
	ZIndex = 2,
}, tray)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 14),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, strip)
make("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, strip)

-- the other tabs until they're built
text(canvas, "Soon", "SOON", 44, WHITE, {
	AnchorPoint = CENTRE,
	Position = UDim2.fromOffset(1240, 540),
	Visible = false,
	ZIndex = 6,
})

-- templates -----------------------------------------------------------------------------
local folder = RS:WaitForChild("UiTemplates"):WaitForChild("Lobby")
for _, n in { "GunCard", "SkinCard", "GunGroup", "SkinTile", "SkinEmblem" } do
	local t = folder:FindFirstChild(n)
	if t then
		t:Destroy()
	end
end

-- SkinEmblem: a skin line's mark. `Art` shows the line's emblem image once it
-- exists (Shared/Locker.EMBLEMS); until then a diamond in the line's colour
-- with its first letter. The controller tints and sizes it.
local emblem = make("Frame", {
	Name = "SkinEmblem",
	Size = UDim2.fromOffset(34, 34),
	BackgroundTransparency = 1,
	ZIndex = 5,
}, folder)
make("ImageLabel", {
	Name = "Art",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Image = "",
	ScaleType = Enum.ScaleType.Fit,
	Visible = false,
	ZIndex = 6,
}, emblem)
local diamond = make("Frame", {
	Name = "Diamond",
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.7, 0.7),
	Rotation = 45,
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	ZIndex = 5,
}, emblem)
make("UICorner", { CornerRadius = UDim.new(0.12, 0) }, diamond)
local letter = make("TextLabel", {
	Name = "Letter",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "P",
	FontFace = Font.new(BX, XB),
	TextScaled = true,
	TextColor3 = INK,
	ZIndex = 6,
}, emblem)
make("UIPadding", {
	PaddingTop = UDim.new(0.3, 0),
	PaddingBottom = UDim.new(0.28, 0),
}, letter)

local group = make("Frame", {
	Name = "GunGroup",
	Size = UDim2.fromOffset(2 * GW + GAP, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
}, folder)
make("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, group)
local head = make("Frame", {
	Name = "HeadRow",
	LayoutOrder = 0,
	Size = UDim2.fromOffset(2 * GW + GAP, 22),
	BackgroundTransparency = 1,
}, group)
text(head, "Head", "RIFLES", 16, WHITE, { Size = UDim2.fromOffset(0, 22), ZIndex = 3 })
text(head, "Count", "4", 16, WHITE, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.fromOffset(0, 22),
	TextTransparency = 0.55,
	ZIndex = 3,
})
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

-- GunCard: the gun's icon in a fixed box (the controller narrows it for
-- pistols and melee so every gun reads at a similar size), its name, and the
-- equipped skin (emblem + name) underneath
local gunCard = make("TextButton", {
	Name = "GunCard",
	BackgroundColor3 = CARD,
	BackgroundTransparency = 0.25,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 3,
}, folder)
corner(gunCard)
make("ImageLabel", {
	Name = "Icon",
	AnchorPoint = CENTRE,
	Position = UDim2.fromOffset(GW / 2, 55),
	Size = UDim2.fromOffset(GW - 16, 86),
	BackgroundTransparency = 1,
	Image = Theme.GUN.Vandal,
	ScaleType = Enum.ScaleType.Fit,
	ZIndex = 4,
}, gunCard)
text(gunCard, "Name", "HAVOC", 16, WHITE, { Position = UDim2.fromOffset(16, GH - 42), ZIndex = 5 })
local skinLine = make("Frame", {
	Name = "Skin",
	Position = UDim2.fromOffset(16, GH - 22),
	Size = UDim2.fromOffset(GW - 32, 16),
	BackgroundTransparency = 1,
	ZIndex = 5,
}, gunCard)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, skinLine)
text(skinLine, "Label", "DEFAULT", 12, MUTED, {
	LayoutOrder = 2,
	Size = UDim2.fromOffset(0, 16),
	FontFace = Font.new(BX, BOLD),
	ZIndex = 6,
})

-- SkinTile: a dark plate with a big live picture of the skinned gun, the
-- line's emblem and name; the previewed one fills with the line's colour and
-- a round check marks the equipped one
local tile = make("TextButton", {
	Name = "SkinTile",
	Size = UDim2.fromOffset(TW, TH),
	BackgroundColor3 = CARD,
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 3,
}, folder)
corner(tile)
text(tile, "Name", "PRISM", 20, WHITE, {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 18, 1, -18),
	ZIndex = 6,
})
chunkyTick(tile, 52, 7, Vector2.new(1, 0), UDim2.new(1, -8, 0, 6))

gui.Parent = SG
print("Locker v5 built (StarterGui.Locker off, ReplicatedStorage.LockerStage, templates)")
