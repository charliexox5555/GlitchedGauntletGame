--!strict
-- Builds the Locker (vault/02 Art/UI Locker.md) in the LOBBY place, Edit mode.
-- Approved as mockup v2 (owner: "Looks good, wire it"), then made live:
--   StarterGui.Locker              the screen (off; LockerController opens it)
--   ReplicatedStorage.LockerStage  the hidden 3D stage (no gun: the client
--                                  clones the stage and puts the gun on it)
--   UiTemplates.Lobby.GunCard / SkinCard / GunGroup
-- It first builds the full v2 mockup (placeholder cards with real thumbnails),
-- then strips it to the live structure at the end. Re-running replaces it all.
-- v1 was "too AI, pilly and boring": no panels-in-panels, picture cards, the
-- skin's colour as its block, sharp slants only on the active thing, gold
-- only on EQUIP.

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
local NAVY, NAVY_HI = hex("1C2740"), hex("2B3A5A")
local ALLY, GOLD = hex("3FE0F2"), hex("FFC83D")
local MUTED, INK, WHITE = hex("8E98A8"), hex("141A26"), Color3.new(1, 1, 1)
local CAP_R = "rbxassetid://130377997107460" -- slant cap (rotated 180 for the left end)
local CENTRE = Vector2.new(0.5, 0.5)

-- Skin lines with a ready Vandal, and a swatch colour each (placeholders).
local LINES = {
	{ "DEFAULT", "BASE MODEL", hex("8E98A8"), "" },
	{ "PRISM", "STRUCTURAL", hex("B58CFF"), "Prism" },
	{ "REDLINE", "STRUCTURAL", hex("FF4D5E"), "Redline" },
	{ "NITROUS", "STRUCTURAL", hex("3FE0F2"), "Nitrous" },
	{ "POPCIRCUIT", "STRUCTURAL", hex("FF7AD9"), "PopCircuit" },
	{ "MOLTFRAME", "STRUCTURAL", hex("FF7A3D"), "Moltframe" },
	{ "GILTFOLD", "STRUCTURAL", hex("E8C46A"), "Giltfold" },
	{ "SEALWORK", "STRUCTURAL", hex("2BD9A8"), "Sealwork" },
	{ "PAYLOAD", "STRUCTURAL", hex("9AA36B"), "Payload" },
	{ "INKSHIFT", "STRUCTURAL", hex("E9ECF2"), "Inkshift" },
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
for _, where in { workspace, RS } do
	local old = where:FindFirstChild("LockerStage")
	if old then
		old:Destroy()
	end
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

-- screen v2 ------------------------------------------------------------------------
-- Owner on v1: "too AI, pilly and boring". So: no panels-in-panels or rows of
-- grey bars; every gun and skin is a picture (a ViewportFrame of the real
-- model); colour means something (a skin's colour is its block, like the bar's
-- name tags); big chunky type; sharp slanted plates only where they mark the
-- active thing; gold only on EQUIP; no pills, outlines, glows or edge strips.
for _, n in { "Locker" } do
	local g = SG:FindFirstChild(n)
	if g then
		g:Destroy()
	end
end
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
	make("UICorner", { CornerRadius = UDim.new(0, 3) }, p)
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

-- A picture of a real model: a ViewportFrame looking at its side, muzzle to
-- the right, a touch from above and behind, framed to fit.
local function thumb(parent: Instance, model: Model, w: number, h: number, pos: UDim2, z: number)
	local vf = make("ViewportFrame", {
		Name = "Thumb",
		Position = pos,
		Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1,
		Ambient = hex("CDD3DF"),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-0.6, -1, -0.4),
		ZIndex = z,
	}, parent)
	local m = model:Clone()
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	m:PivotTo(CFrame.new())
	local cf, size = m:GetBoundingBox()
	m.Parent = vf
	local cam = make("Camera", { FieldOfView = 20 }, vf)
	vf.CurrentCamera = cam
	local half = math.max(size.Y, size.Z / (w / h)) / 2 * 0.98
	local dist = half / math.tan(math.rad(10)) + size.X / 2
	cam.CFrame =
		CFrame.lookAt(cf.Position + Vector3.new(dist, dist * 0.12, dist * 0.16), cf.Position)
end

local function gunModel(name: string): Model
	local id = string.sub(name, 1, 1) .. string.lower(string.sub(name, 2))
	return RS.Weapons:WaitForChild(id) :: Model
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
-- the side columns sit on a dark fade (no boxes), the stage stays open
for i, side in { 0, 1 } do
	local f = make("Frame", {
		Name = if i == 1 then "FadeL" else "FadeR",
		AnchorPoint = Vector2.new(side, 0),
		Position = UDim2.fromScale(side, 0),
		Size = UDim2.fromOffset(640, 1080),
		BackgroundColor3 = hex("06080C"),
		BorderSizePixel = 0,
		ZIndex = 0,
	}, canvas)
	make("UIGradient", {
		Rotation = if side == 0 then 0 else 180,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.12),
			NumberSequenceKeypoint.new(0.55, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, f)
end

-- top left: LOCKER and the three tabs (the active one on a cyan slab)
text(canvas, "Title", "LOCKER", 60, WHITE, { Position = UDim2.fromOffset(64, 40) })
local tabs = make("Frame", {
	Name = "Tabs",
	Position = UDim2.fromOffset(78, 120),
	Size = UDim2.fromOffset(0, 50),
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
		Size = UDim2.fromOffset(0, 50),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = ALLY,
		BackgroundTransparency = if on then 0 else 1,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 3,
	}, tabs)
	make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, tab)
	if on then
		slant(tab, ALLY, 50, 16)
	end
	text(
		tab,
		"Label",
		t,
		20,
		if on then INK else MUTED,
		{ Size = UDim2.fromOffset(0, 50), ZIndex = 5 }
	)
end
-- top right: a round close (circles are for things you touch)
local close = make("TextButton", {
	Name = "Close",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromOffset(1856, 48),
	Size = UDim2.fromOffset(60, 60),
	BackgroundColor3 = NAVY,
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
	22,
	WHITE,
	{ AnchorPoint = CENTRE, Position = UDim2.fromScale(0.5, 0.5), ZIndex = 5 }
)

-- left: every gun as a picture card, grouped by class
local GW, GH, GAP = 204, 112, 10
local list = make("ScrollingFrame", {
	Name = "Guns",
	Position = UDim2.fromOffset(64, 196),
	Size = UDim2.fromOffset(2 * GW + GAP + 14, 840),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = MUTED,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ZIndex = 2,
}, canvas)
make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)
for gi, g in GROUPS do
	local group = make("Frame", {
		Name = g[1],
		LayoutOrder = gi,
		Size = UDim2.fromOffset(2 * GW + GAP, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, list)
	make(
		"UIListLayout",
		{ Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder },
		group
	)
	text(group, "Head", g[1], 13, ALLY, { LayoutOrder = 0, ZIndex = 3 })
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
	for i, name in g[2] do
		local selected = name == "VANDAL"
		local card = make("TextButton", {
			Name = name,
			LayoutOrder = i,
			BackgroundColor3 = if selected then ALLY else NAVY,
			BackgroundTransparency = if selected then 0 else 0.08,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 3,
		}, grid)
		corner(card)
		thumb(card, gunModel(name), GW - 16, 74, UDim2.fromOffset(8, 4), 4)
		text(card, "Name", name, 14, if selected then INK else WHITE, {
			Position = UDim2.fromOffset(12, GH - 30),
			ZIndex = 5,
		})
		-- the equipped skin's colour as a slanted block in the corner
		local eq = EQUIPPED[name]
		if eq then
			local c = LINES[eq][3]
			local chip = make("Frame", {
				Name = "Skin",
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -14, 1, -8),
				Size = UDim2.fromOffset(26, 18),
				BackgroundColor3 = c,
				BorderSizePixel = 0,
				ZIndex = 5,
			}, card)
			slant(chip, c, 18, 6)
		end
	end
end

-- centre top: the gun's name, and the skin on it in the skin's colour
local SEL = LINES[2]
text(
	canvas,
	"GunName",
	"VANDAL",
	84,
	WHITE,
	{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(960, 168) }
)
local skinTag = make("Frame", {
	Name = "SkinTag",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromOffset(960, 268),
	Size = UDim2.fromOffset(0, 36),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = SEL[3],
	BorderSizePixel = 0,
	ZIndex = 3,
}, canvas)
make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, skinTag)
slant(skinTag, SEL[3], 36, 12)
text(
	skinTag,
	"Label",
	SEL[1] .. "  ·  RIFLE",
	16,
	INK,
	{ Size = UDim2.fromOffset(0, 36), ZIndex = 5 }
)
text(
	canvas,
	"Hint",
	"DRAG TO TURN  ·  SCROLL TO ZOOM",
	12,
	MUTED,
	{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(960, 912) }
)

-- right: the skins as big picture cards; each card's foot is its colour
local SW, SHH = 204, 152
text(canvas, "SkinsHead", "SKINS", 16, WHITE, { Position = UDim2.fromOffset(1438, 150) })
text(
	canvas,
	"SkinsCount",
	"10 OWNED",
	12,
	MUTED,
	{ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(1856, 154) }
)
local skins = make("ScrollingFrame", {
	Name = "Skins",
	Position = UDim2.fromOffset(1438, 190),
	Size = UDim2.fromOffset(2 * SW + GAP + 14, 680),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = MUTED,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ZIndex = 2,
}, canvas)
make("UIGridLayout", {
	CellSize = UDim2.fromOffset(SW, SHH),
	CellPadding = UDim2.fromOffset(GAP, GAP),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, skins)
for i, line in LINES do
	local onStage = i == 2
	local card = make("TextButton", {
		Name = line[1],
		LayoutOrder = i,
		BackgroundColor3 = if onStage then NAVY_HI else NAVY,
		BackgroundTransparency = if onStage then 0 else 0.08,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 3,
	}, skins)
	corner(card)
	local model = if line[4] == ""
		then gunModel("VANDAL")
		else RS.WeaponSkins:WaitForChild(line[4]):WaitForChild("Vandal")
	thumb(card, model :: Model, SW - 12, 100, UDim2.fromOffset(6, 4), 4)
	local foot = make("Frame", {
		Name = "Foot",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = line[3],
		BorderSizePixel = 0,
		ZIndex = 4,
	}, card)
	corner(foot)
	text(
		foot,
		"Name",
		line[1],
		15,
		INK,
		{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), ZIndex = 5 }
	)
	if onStage then
		text(
			foot,
			"On",
			"»",
			24,
			INK,
			{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, -1), ZIndex = 5 }
		)
	end
	if i == EQUIPPED.VANDAL then
		local eq = make("Frame", {
			Name = "Equipped",
			Position = UDim2.fromOffset(12, 10),
			Size = UDim2.fromOffset(0, 20),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			ZIndex = 6,
		}, card)
		make("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, eq)
		slant(eq, WHITE, 20, 6)
		text(eq, "Label", "EQUIPPED", 10, INK, { Size = UDim2.fromOffset(0, 20), ZIndex = 7 })
	end
end

-- EQUIP: the one gold thing, big, with the » that says "go"
local equip = make("TextButton", {
	Name = "Equip",
	Position = UDim2.fromOffset(1458, 900),
	Size = UDim2.fromOffset(2 * SW + GAP - 40, 80),
	BackgroundColor3 = GOLD,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 3,
}, canvas)
slant(equip, GOLD, 80, 24)
text(
	equip,
	"Label",
	"EQUIP",
	34,
	INK,
	{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 18, 0.5, -8), ZIndex = 5 }
)
text(
	equip,
	"Sub",
	"PRISM VANDAL",
	11,
	INK,
	{ Position = UDim2.new(0, 20, 0.5, 14), TextTransparency = 0.3, ZIndex = 5 }
)
text(
	equip,
	"Go",
	"»",
	54,
	INK,
	{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, -4), ZIndex = 5 }
)

-- bottom centre: what you're changing; big words, the active one on a white slab
local kinds = make("Frame", {
	Name = "Kinds",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromOffset(960, 960),
	Size = UDim2.fromOffset(0, 50),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
}, canvas)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 34),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, kinds)
for i, k in { "SKIN", "CHARM", "WRAP", "FINISHER" } do
	local on = i == 1
	local b = make("TextButton", {
		Name = k,
		LayoutOrder = i,
		Size = UDim2.fromOffset(0, 50),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = WHITE,
		BackgroundTransparency = if on then 0 else 1,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 3,
	}, kinds)
	make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, b)
	if on then
		slant(b, WHITE, 50, 16)
	end
	text(b, "Label", k, 20, if on then INK else WHITE, {
		Size = UDim2.fromOffset(0, 50),
		TextTransparency = if on then 0 else 0.45,
		ZIndex = 5,
	})
	if not on then
		text(
			b,
			"Soon",
			"SOON",
			9,
			ALLY,
			{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, -6), ZIndex = 5 }
		)
	end
end

-- live ------------------------------------------------------------------------------
-- Strip the mockup to the live structure: templates out, lists empty, the
-- screen off, the stage into ReplicatedStorage without its gun.
gui.Name = "Locker"
gui.Enabled = false
local folder = RS:WaitForChild("UiTemplates"):WaitForChild("Lobby")
for _, n in { "GunCard", "SkinCard", "GunGroup" } do
	local t = folder:FindFirstChild(n)
	if t then
		t:Destroy()
	end
end
local function noThumb(card: Instance)
	local t = card:FindFirstChild("Thumb")
	if t then
		t:Destroy()
	end
end
local guns = canvas:FindFirstChild("Guns") :: ScrollingFrame
local sidearms = guns:FindFirstChild("SIDEARMS") :: Frame
local gunCard = (sidearms:FindFirstChild("Grid") :: Frame)
		:FindFirstChild("SHERIFF")
		:Clone() :: TextButton
noThumb(gunCard)
gunCard.Name = "GunCard"
gunCard.BackgroundColor3 = NAVY
gunCard.BackgroundTransparency = 0.08
gunCard.Parent = folder
local skinCard = (canvas:FindFirstChild("Skins") :: ScrollingFrame)
		:FindFirstChild("PRISM")
		:Clone() :: TextButton
noThumb(skinCard)
skinCard.Name = "SkinCard"
skinCard.Parent = folder
local group = sidearms:Clone()
group.Name = "GunGroup"
for _, c in (group:FindFirstChild("Grid") :: Frame):GetChildren() do
	if not c:IsA("UIGridLayout") then
		c:Destroy()
	end
end
group.Parent = folder
for _, scroller in { guns, canvas:FindFirstChild("Skins") :: ScrollingFrame } do
	for _, c in scroller:GetChildren() do
		if not c:IsA("UIGridLayout") and not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
end
-- other tabs (Abilities = the Mod collection, Emotes) until they're built
text(canvas, "Soon", "SOON", 40, WHITE, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromOffset(960, 540),
	Visible = false,
	ZIndex = 6,
})
local gunNow = stage:FindFirstChild("Gun")
if gunNow then
	gunNow:Destroy()
end
make("CFrameValue", { Name = "GunSpot", Value = GUN_SPOT }, stage)
stage.Parent = RS
gui.Parent = SG
print("Locker built (StarterGui.Locker off, ReplicatedStorage.LockerStage, templates)")
