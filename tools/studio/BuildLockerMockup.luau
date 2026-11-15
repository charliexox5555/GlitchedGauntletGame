--!strict
-- Locker mockup v1 (vault/02 Art/UI Locker.md) in the LOBBY place, Edit mode:
--   Workspace.LockerStage     the hidden studio stage: a faceted backdrop, an
--                             octagonal plinth, three lights, the gun (Prism Vandal)
--   StarterGui.LockerMockup   the screen: tabs, the weapon list (left), the gun's
--                             skins + EQUIP (right), SKIN / CHARM / WRAP / FINISHER
--                             tabs and the drag hint (bottom)
-- Static placeholder data; the owner edits it in Studio, then it gets wired.
-- Re-running replaces both. Same look as the lobby HUD v6: navy plates, sharp
-- slanted tags (no pills), Builder Extended, gold only on EQUIP.

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

local BX = "rbxasset://fonts/families/BuilderExtended.json"
local XB = Enum.FontWeight.ExtraBold
local NAVY, NAVY_HI, NAVY_LO = hex("1C2740"), hex("2B3A5A"), hex("141C30")
local ALLY, GOLD = hex("3FE0F2"), hex("FFC83D")
local MUTED, INK, WHITE = hex("8E98A8"), hex("141A26"), Color3.new(1, 1, 1)
local SHADOW = "rbxassetid://121253415859134"
local CAP_R = "rbxassetid://130377997107460" -- slant cap (rotated 180 for the left end)
local CENTRE = Vector2.new(0.5, 0.5)

-- Skin lines with a ready Vandal, and a swatch colour each (placeholders).
local LINES = {
	{ "DEFAULT", "BASE MODEL", hex("8E98A8") },
	{ "PRISM", "STRUCTURAL", hex("B58CFF") },
	{ "REDLINE", "STRUCTURAL", hex("FF4D5E") },
	{ "NITROUS", "STRUCTURAL", hex("3FE0F2") },
	{ "POPCIRCUIT", "STRUCTURAL", hex("FF7AD9") },
	{ "MOLTFRAME", "STRUCTURAL", hex("FF7A3D") },
	{ "GILTFOLD", "STRUCTURAL", hex("E8C46A") },
	{ "SEALWORK", "STRUCTURAL", hex("2BD9A8") },
	{ "PAYLOAD", "STRUCTURAL", hex("9AA36B") },
	{ "INKSHIFT", "STRUCTURAL", hex("E9ECF2") },
}
local GROUPS = {
	{ "SIDEARMS", { "CLASSIC", "SHORTY", "GHOST", "SHERIFF" } },
	{ "SMGS", { "STINGER", "SPECTRE" } },
	{ "SHOTGUNS", { "BUCKY", "JUDGE" } },
	{ "RIFLES", { "BULLDOG", "GUARDIAN", "PHANTOM", "VANDAL" } },
	{ "SNIPERS", { "MARSHAL", "OUTLAW", "OPERATOR" } },
	{ "HEAVY", { "ARES", "ODIN" } },
	{ "MELEE", { "KNIFE" } },
}
-- equipped skin per gun in the mockup (shows the tags)
local EQUIPPED: { [string]: number } =
	{ VANDAL = 2, SHERIFF = 3, PHANTOM = 4, KNIFE = 6, OPERATOR = 5 }

-- 3D stage ------------------------------------------------------------------------
local STAGE = CFrame.new(0, 600, -3000) -- far from the map; the client will clone it
local old = workspace:FindFirstChild("LockerStage")
if old then
	old:Destroy()
end
local stage = make("Model", { Name = "LockerStage" }, workspace)

local function block(
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	parent: Instance?
): Part
	return make("Part", {
		Name = name,
		Size = size,
		CFrame = cf,
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		Anchored = true,
		CanCollide = false,
		CastShadow = true,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
	}, parent or stage)
end

-- backdrop: a faceted arc of flat plates behind the gun (no curves)
local BACK, FLOOR = hex("2A3F8F"), hex("1B2757")
local R, H = 15, 18
for i = -4, 4 do
	local a = math.rad(i * 15)
	local cf = STAGE * CFrame.Angles(0, a, 0) * CFrame.new(0, H / 2 - 4, -R)
	block("Back" .. i, Vector3.new(2 * R * math.tan(math.rad(7.5)) + 0.4, H, 0.6), cf, BACK)
end
-- floor: a big octagon from two rotated slabs
for i = 0, 1 do
	block(
		"Floor" .. i,
		Vector3.new(34, 0.6, 34),
		STAGE * CFrame.new(0, -4, -3) * CFrame.Angles(0, math.rad(45 * i), 0),
		FLOOR
	)
end
-- the plinth: two octagon tiers (each two rotated slabs, so no curves) right
-- under the gun, which hovers just above it
local PLINTH, CAP = hex("1E2A52"), hex("26355F")
for i = 0, 1 do
	local rot = CFrame.Angles(0, math.rad(45 * i), 0)
	block(
		"PlinthBase" .. i,
		Vector3.new(3.6, 2.2, 3.6),
		STAGE * CFrame.new(0, -2.9, 0) * rot,
		PLINTH
	)
	block("PlinthTop" .. i, Vector3.new(3, 0.3, 3), STAGE * CFrame.new(0, -1.65, 0) * rot, CAP)
end
-- lights: key (front left, above), rim (behind), fill (front right, low)
local function light(name: string, offset: Vector3, kind: string, props: { [string]: any })
	local p = make("Part", {
		Name = name,
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = CFrame.lookAt((STAGE * CFrame.new(offset)).Position, STAGE.Position),
		Transparency = 1,
		Anchored = true,
		CanCollide = false,
		CastShadow = false,
	}, stage)
	make(kind, props, p)
end
-- (the Lobby's lighting is a dark night set, so the stage carries its own light)
light(
	"Key",
	Vector3.new(-6, 7, 7),
	"SpotLight",
	{ Brightness = 6, Range = 30, Angle = 55, Face = Enum.NormalId.Front, Shadows = true }
)
light(
	"Rim",
	Vector3.new(2, 5, -6),
	"SpotLight",
	{ Brightness = 5, Range = 18, Angle = 60, Face = Enum.NormalId.Front, Color = hex("BFE9FF") }
)
light(
	"Fill",
	Vector3.new(5, 1, 8),
	"PointLight",
	{ Brightness = 2, Range = 20, Color = hex("FFE7C2") }
)
light(
	"Wash",
	Vector3.new(0, -2, 10),
	"SpotLight",
	{ Brightness = 2.5, Range = 40, Angle = 90, Face = Enum.NormalId.Front, Color = hex("8FB0FF") }
)

-- the gun: a skin model, anchored, centred over the plinth at a hero angle
local GUN_SPOT = STAGE * CFrame.new(0, 0, 0)
local gun = RS:WaitForChild("WeaponSkins"):WaitForChild("Prism"):WaitForChild("Vandal"):Clone()
gun.Name = "Gun"
for _, d in gun:GetDescendants() do
	if d:IsA("BasePart") then
		d.Anchored = true
		d.CanCollide = false
	end
end
gun:ScaleTo(1.2)
-- muzzle to the right, turned a little toward the camera, nose slightly up
gun:PivotTo(GUN_SPOT * CFrame.Angles(0, math.rad(-90 + 22), 0) * CFrame.Angles(math.rad(-8), 0, 0))
local center = gun:GetBoundingBox()
gun:PivotTo(gun:GetPivot() + (GUN_SPOT.Position - center.Position))
gun.Parent = stage
-- the Locker camera (FOV 30): far enough that the whole gun sits between the panels
make("CFrameValue", {
	Name = "CameraCFrame",
	Value = CFrame.lookAt(
		(STAGE * CFrame.new(0, 0.9, 11.5)).Position,
		(STAGE * CFrame.new(0, -0.35, 0)).Position
	),
}, stage)

-- screen --------------------------------------------------------------------------
local oldGui = SG:FindFirstChild("LockerMockup")
if oldGui then
	oldGui:Destroy()
end
local gui = make("ScreenGui", {
	Name = "LockerMockup",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ScreenInsets = Enum.ScreenInsets.None,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 30,
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
local function corner(p: Instance)
	make("UICorner", { CornerRadius = UDim.new(0, 2) }, p)
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
local function shadow(p: Instance, x: number, y: number, w: number, h: number)
	make("ImageLabel", {
		Name = "Shadow",
		Position = UDim2.fromOffset(x - 30, y - 22),
		Size = UDim2.fromOffset(w + 60, h + 60),
		BackgroundTransparency = 1,
		Image = SHADOW,
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 0.45,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(48, 48, 80, 80),
		ZIndex = 0,
	}, p)
end
-- one design-size canvas (1920x1080), scaled to fit and centred
local canvas = make("Frame", {
	Name = "Canvas",
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(1920, 1080),
	BackgroundTransparency = 1,
}, gui)
make("UIScale", { Name = "Fit" }, canvas)
-- a soft dark fade at the left and right edges so the panels sit on calm ground
for i, side in { 0, 1 } do
	local f = make("Frame", {
		Name = if i == 1 then "FadeL" else "FadeR",
		AnchorPoint = Vector2.new(side, 0),
		Position = UDim2.fromScale(side, 0),
		Size = UDim2.fromOffset(560, 1080),
		BackgroundColor3 = hex("06080C"),
		BorderSizePixel = 0,
		ZIndex = 0,
	}, canvas)
	make("UIGradient", {
		Rotation = if side == 0 then 0 else 180,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, f)
end

-- top: title, tabs, close
text(canvas, "Kicker", "LOBBY", 12, ALLY, { Position = UDim2.fromOffset(60, 72) })
text(canvas, "Title", "LOCKER", 44, WHITE, { Position = UDim2.fromOffset(60, 86) })
local tabs = make("Frame", {
	Name = "Tabs",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromOffset(960, 84),
	Size = UDim2.fromOffset(0, 44),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
}, canvas)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 26),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, tabs)
for i, t in { "WEAPONS", "ABILITIES", "EMOTES" } do
	local on = i == 1
	local tab = make("TextButton", {
		Name = t,
		LayoutOrder = i,
		Size = UDim2.fromOffset(170, 44),
		BackgroundColor3 = if on then ALLY else NAVY,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 3,
	}, tabs)
	slant(tab, if on then ALLY else NAVY, 44, 14)
	text(
		tab,
		"Label",
		t,
		16,
		if on then INK else WHITE,
		{ AnchorPoint = CENTRE, Position = UDim2.fromScale(0.5, 0.5), ZIndex = 5 }
	)
end
local close = make("TextButton", {
	Name = "Close",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromOffset(1860, 84),
	Size = UDim2.fromOffset(130, 44),
	BackgroundColor3 = NAVY,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 3,
}, canvas)
slant(close, NAVY, 44, 14)
text(
	close,
	"Label",
	"X  CLOSE",
	14,
	WHITE,
	{ AnchorPoint = CENTRE, Position = UDim2.fromScale(0.5, 0.5), ZIndex = 5 }
)

-- left: the weapon list, grouped by class
local LX, LY, LW, LH = 60, 168, 340, 800
shadow(canvas, LX, LY, LW, LH)
local left = make("Frame", {
	Name = "Weapons",
	Position = UDim2.fromOffset(LX, LY),
	Size = UDim2.fromOffset(LW, LH),
	BackgroundColor3 = NAVY,
	BorderSizePixel = 0,
	ZIndex = 1,
}, canvas)
corner(left)
local leftHead = make("Frame", {
	Name = "Head",
	Size = UDim2.fromOffset(LW, 40),
	BackgroundColor3 = NAVY_HI,
	BorderSizePixel = 0,
	ZIndex = 2,
}, left)
corner(leftHead)
text(
	leftHead,
	"Label",
	"WEAPONS",
	14,
	WHITE,
	{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 0.5, 0), ZIndex = 3 }
)
text(
	leftHead,
	"Count",
	"18",
	12,
	MUTED,
	{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), ZIndex = 3 }
)
local list = make("ScrollingFrame", {
	Name = "List",
	Position = UDim2.fromOffset(0, 46),
	Size = UDim2.new(1, 0, 1, -52),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = MUTED,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ZIndex = 2,
}, left)
make("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, list)
make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 12) }, list)
local order = 0
for _, g in GROUPS do
	order += 1
	text(list, "Group", g[1], 10, ALLY, {
		LayoutOrder = order,
		Size = UDim2.fromOffset(0, 22),
		TextYAlignment = Enum.TextYAlignment.Bottom,
		ZIndex = 3,
	})
	for _, name in g[2] do
		order += 1
		local selected = name == "VANDAL"
		local row = make("TextButton", {
			Name = name,
			LayoutOrder = order,
			Size = UDim2.fromOffset(LW - 22, 34),
			BackgroundColor3 = if selected then ALLY else NAVY_LO,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 3,
		}, list)
		corner(row)
		text(
			row,
			"Name",
			name,
			13,
			if selected then INK else WHITE,
			{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), ZIndex = 4 }
		)
		local eq = EQUIPPED[name]
		if eq then
			local line = LINES[eq]
			local tag = make("Frame", {
				Name = "Skin",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -16, 0.5, 0),
				Size = UDim2.fromOffset(0, 20),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = line[3],
				BorderSizePixel = 0,
				ZIndex = 4,
			}, row)
			make("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, tag)
			slant(tag, line[3], 20, 6)
			text(tag, "Label", line[1], 9, INK, { Size = UDim2.fromOffset(0, 20), ZIndex = 5 })
		end
	end
end

-- right: the selected gun and its skins
local RX, RY, RW = 1520, 168, 340
local head = make("Frame", {
	Name = "Gun",
	Position = UDim2.fromOffset(RX, RY),
	Size = UDim2.fromOffset(RW, 84),
	BackgroundTransparency = 1,
}, canvas)
text(head, "Class", "RIFLE  ·  TIER 3", 12, ALLY, { Position = UDim2.fromOffset(0, 0) })
text(head, "Name", "VANDAL", 42, WHITE, { Position = UDim2.fromOffset(0, 18) })
local SY, SH = RY + 92, 600
shadow(canvas, RX, SY, RW, SH)
local skins = make("Frame", {
	Name = "Skins",
	Position = UDim2.fromOffset(RX, SY),
	Size = UDim2.fromOffset(RW, SH),
	BackgroundColor3 = NAVY,
	BorderSizePixel = 0,
	ZIndex = 1,
}, canvas)
corner(skins)
local skinHead = make("Frame", {
	Name = "Head",
	Size = UDim2.fromOffset(RW, 40),
	BackgroundColor3 = NAVY_HI,
	BorderSizePixel = 0,
	ZIndex = 2,
}, skins)
corner(skinHead)
text(
	skinHead,
	"Label",
	"SKINS",
	14,
	WHITE,
	{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 0.5, 0), ZIndex = 3 }
)
text(
	skinHead,
	"Count",
	"10 OWNED",
	12,
	MUTED,
	{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), ZIndex = 3 }
)
local slist = make("Frame", {
	Name = "List",
	Position = UDim2.fromOffset(10, 48),
	Size = UDim2.new(1, -20, 1, -56),
	BackgroundTransparency = 1,
	ZIndex = 2,
}, skins)
make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, slist)
for i, line in LINES do
	local previewing = i == 2 -- PRISM is on the stand
	local row = make("TextButton", {
		Name = line[1],
		LayoutOrder = i,
		Size = UDim2.fromOffset(RW - 20, 50),
		BackgroundColor3 = if previewing then NAVY_HI else NAVY_LO,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 3,
	}, slist)
	corner(row)
	local sw = make("Frame", {
		Name = "Swatch",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(40, 50),
		BackgroundColor3 = line[3],
		BorderSizePixel = 0,
		ZIndex = 4,
	}, row)
	make("ImageLabel", {
		Name = "Cap",
		Position = UDim2.new(1, -1, 0, 0),
		Size = UDim2.fromOffset(14, 50),
		BackgroundTransparency = 1,
		Image = CAP_R,
		ImageColor3 = line[3],
		ZIndex = 4,
	}, sw)
	text(row, "Name", line[1], 15, WHITE, { Position = UDim2.fromOffset(66, 8), ZIndex = 5 })
	text(row, "Kind", line[2], 10, MUTED, { Position = UDim2.fromOffset(66, 28), ZIndex = 5 })
	if i == EQUIPPED.VANDAL then
		text(
			row,
			"Equipped",
			"EQUIPPED",
			10,
			ALLY,
			{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), ZIndex = 5 }
		)
	elseif previewing then
		text(
			row,
			"Viewing",
			"»",
			22,
			WHITE,
			{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), ZIndex = 5 }
		)
	end
end
-- EQUIP: the one gold thing on the screen
local equip = make("TextButton", {
	Name = "Equip",
	Position = UDim2.fromOffset(RX + 20, SY + SH + 24),
	Size = UDim2.fromOffset(RW - 40, 64),
	BackgroundColor3 = GOLD,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 3,
}, canvas)
slant(equip, GOLD, 64, 20)
text(
	equip,
	"Label",
	"EQUIP",
	28,
	INK,
	{ AnchorPoint = CENTRE, Position = UDim2.fromScale(0.5, 0.42), ZIndex = 5 }
)
text(equip, "Sub", "PRISM  ·  VANDAL", 10, INK, {
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0.8),
	TextTransparency = 0.3,
	ZIndex = 5,
})

-- bottom centre: what you're changing on the gun, and the drag hint
local kinds = make("Frame", {
	Name = "Kinds",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromOffset(960, 948),
	Size = UDim2.fromOffset(0, 46),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
}, canvas)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 22),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, kinds)
for i, k in { "SKIN", "CHARM", "WRAP", "FINISHER" } do
	local on = i == 1
	local b = make("TextButton", {
		Name = k,
		LayoutOrder = i,
		Size = UDim2.fromOffset(140, 46),
		BackgroundColor3 = if on then WHITE else NAVY,
		BackgroundTransparency = if on then 0 else 0.15,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 3,
	}, kinds)
	slant(b, if on then WHITE else NAVY, 46, 14)
	text(b, "Label", k, 15, if on then INK else WHITE, {
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, if on then 0.5 else 0.38),
		ZIndex = 5,
		TextTransparency = if on then 0 else 0.35,
	})
	if not on then
		text(
			b,
			"Soon",
			"SOON",
			9,
			ALLY,
			{ AnchorPoint = CENTRE, Position = UDim2.fromScale(0.5, 0.76), ZIndex = 5 }
		)
	end
end
text(
	canvas,
	"Hint",
	"DRAG TO TURN  ·  SCROLL TO ZOOM",
	11,
	MUTED,
	{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(960, 1008) }
)

gui.Parent = SG
print("Locker mockup v1 built (Workspace.LockerStage, StarterGui.LockerMockup)")
