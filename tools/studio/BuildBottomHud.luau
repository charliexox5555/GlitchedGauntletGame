--!strict
-- Rebuilds the match's bottom combat HUD (health + shield, ammo, Mod slots) in
-- the match place (vault/02 Art/UI Combat HUD Mockup.md). Studio owns
-- StarterGui.BottomHud; this is its backup in git. Paste into the Studio
-- command bar (Edit mode). It refuses to run if StarterGui.BottomHud exists.
-- Behaviour: src/client/Util/BottomHud.luau (fed by HudController and
-- ModHudController). Desktop only for now; phones keep the old HUD.
-- Images: tools/ui/make_topbar_v22_images.py (caps, shadow), tools/ui/make_hud_icons.py.

local StarterGui = game:GetService("StarterGui")

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
local CAP_R, CAP_L = "rbxassetid://130377997107460", "rbxassetid://75584308608588"
local SHADOW = "rbxassetid://121253415859134"
local ICON_HP, ICON_SHIELD = "rbxassetid://118284450466320", "rbxassetid://122576084707248"
local PREVIEW_GUN = "rbxassetid://108427985127422" -- Vandal, replaced in play
local PREVIEW_MODS = {
	{ icon = "rbxassetid://140468016168978", role = hex("2BD9A8") },
	{ icon = "rbxassetid://115604306101761", role = hex("FF7A3D") },
	{ icon = "rbxassetid://104088410327059", role = hex("C15CFF") },
}
local PLATE = hex("1A202A")
local DARK_SHADE = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(140, 140, 140))
local ALLY_TOP = hex("3FE0F2")
local ALLY_SHADE = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.41, 0.63, 0.76))
local WHITE = Color3.new(1, 1, 1)
local TEXT = hex("F4F6F9")
local MUTED = hex("9AA4B2")

assert(not StarterGui:FindFirstChild("BottomHud"), "StarterGui.BottomHud already exists")

-- A number with a soft drop shadow: Frame → Shadow + Value labels.
local function number(
	parent: Instance,
	name: string,
	text: string,
	size: number,
	props: { [string]: any }?
): Frame
	local f = make("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, size + 6),
	}, parent)
	for k, v in props or {} do
		(f :: any)[k] = v
	end
	for _, part in { "Shadow", "Value" } do
		make("TextLabel", {
			Name = part,
			Position = UDim2.fromOffset(0, if part == "Shadow" then 3 else 0),
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Text = text,
			FontFace = Font.new(BX, Enum.FontWeight.ExtraBold),
			TextSize = size,
			TextColor3 = if part == "Shadow" then hex("06080C") else WHITE,
			TextTransparency = if part == "Shadow" then 0.6 else 0,
			ZIndex = if part == "Shadow" then 4 else 5,
		}, f)
	end
	return f
end

local function softShadow(parent: Instance, w: number, h: number, y: number): ImageLabel
	return make("ImageLabel", {
		Name = "Shadow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, y),
		Size = UDim2.fromOffset(w + 56, h + 48),
		BackgroundTransparency = 1,
		Image = SHADOW,
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 0.5,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(48, 48, 80, 80),
		ZIndex = 0,
	}, parent)
end

-- A dark plate whose end toward the screen centre is slanted.
local function panel(
	parent: Instance,
	name: string,
	w: number,
	h: number,
	slantRight: boolean
): (Frame, Frame)
	local holder = make(
		"Frame",
		{ Name = name, BackgroundTransparency = 1, Size = UDim2.fromOffset(w + 20, h) },
		parent
	)
	softShadow(holder, w + 20, h, h / 2 + 6)
	local body = make("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(if slantRight then 0 else 20, 0),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = PLATE,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, holder)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, body)
	make("UIGradient", { Name = "Shade", Rotation = 90, Color = DARK_SHADE }, body)
	local cap = make("ImageLabel", {
		Name = "Slant",
		Position = UDim2.fromOffset(if slantRight then w - 8 else 0, 0),
		Size = UDim2.fromOffset(28, h),
		BackgroundTransparency = 1,
		Image = if slantRight then CAP_R else CAP_L,
		ImageColor3 = PLATE,
		ZIndex = 1,
	}, holder)
	make("UIGradient", { Name = "Shade", Rotation = 90, Color = DARK_SHADE }, cap)
	return holder, body
end

local gui = make("ScreenGui", {
	Name = "BottomHud",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
	IgnoreGuiInset = true,
	DisplayOrder = 6,
})
local root =
	make("Frame", { Name = "Root", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, gui)

-- HEALTH (bottom-left) -------------------------------------------------------
local hpHolder, hp = panel(root, "Health", 396, 96, true)
hpHolder.AnchorPoint = Vector2.new(0, 1)
hpHolder.Position = UDim2.new(0.024, 0, 0.965, 0)
make("UIScale", { Name = "Fit" }, hpHolder)
make("ImageLabel", {
	Name = "Icon",
	Position = UDim2.fromOffset(18, 16),
	Size = UDim2.fromOffset(26, 26),
	BackgroundTransparency = 1,
	Image = ICON_HP,
	ZIndex = 2,
}, hp)
number(hp, "HP", "100", 46, { Position = UDim2.fromOffset(54, 4), ZIndex = 2 })
local chip = make("Frame", {
	Name = "ShieldChip",
	Position = UDim2.fromOffset(206, 12),
	Size = UDim2.fromOffset(84, 34),
	BackgroundColor3 = ALLY_TOP,
	BorderSizePixel = 0,
	ZIndex = 2,
}, hp)
make("UICorner", { CornerRadius = UDim.new(0, 5) }, chip)
make("UIGradient", { Name = "Shade", Rotation = 90, Color = ALLY_SHADE }, chip)
make("ImageLabel", {
	Name = "Icon",
	Position = UDim2.fromOffset(8, 7),
	Size = UDim2.fromOffset(20, 20),
	BackgroundTransparency = 1,
	Image = ICON_SHIELD,
	ZIndex = 3,
}, chip)
number(chip, "Value", "25", 20, { Position = UDim2.fromOffset(36, 2), ZIndex = 3 })
local segs = make("Frame", {
	Name = "Segments",
	Position = UDim2.fromOffset(18, 66),
	Size = UDim2.fromOffset(350, 12),
	BackgroundTransparency = 1,
	ZIndex = 2,
}, hp)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 3),
	SortOrder = Enum.SortOrder.LayoutOrder,
	VerticalAlignment = Enum.VerticalAlignment.Center,
}, segs)
for i = 1, 10 do
	local s = make("Frame", {
		Name = "Hp" .. i,
		LayoutOrder = i,
		Size = UDim2.fromOffset(20, 12),
		BackgroundColor3 = TEXT,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, segs)
	make("UICorner", { CornerRadius = UDim.new(0, 2) }, s)
end
make(
	"Frame",
	{ Name = "Gap", LayoutOrder = 11, Size = UDim2.fromOffset(3, 12), BackgroundTransparency = 1 },
	segs
)
for i = 1, 5 do
	local s = make("Frame", {
		Name = "Shield" .. i,
		LayoutOrder = 11 + i,
		Size = UDim2.fromOffset(18, 12),
		BackgroundColor3 = ALLY_TOP,
		BackgroundTransparency = if i <= 2 then 0 else 0.86,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, segs)
	make("UICorner", { CornerRadius = UDim.new(0, 2) }, s)
end

-- AMMO (bottom-right) --------------------------------------------------------
local amHolder, am = panel(root, "Ammo", 396, 96, false)
amHolder.AnchorPoint = Vector2.new(1, 1)
amHolder.Position = UDim2.new(0.976, 0, 0.965, 0)
make("UIScale", { Name = "Fit" }, amHolder)
make("ImageLabel", {
	Name = "Gun",
	Position = UDim2.fromOffset(28, 14),
	Size = UDim2.fromOffset(150, 46),
	BackgroundTransparency = 1,
	Image = PREVIEW_GUN,
	ScaleType = Enum.ScaleType.Fit,
	ZIndex = 2,
}, am)
number(
	am,
	"Mag",
	"18",
	46,
	{ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(318, 4), ZIndex = 2 }
)
make("TextLabel", {
	Name = "MagSize",
	Position = UDim2.fromOffset(322, 22),
	Size = UDim2.fromOffset(60, 24),
	BackgroundTransparency = 1,
	Text = "/25",
	FontFace = Font.new(BX, Enum.FontWeight.Bold),
	TextSize = 18,
	TextColor3 = MUTED,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 2,
}, am)
make("TextLabel", {
	Name = "GunName",
	Position = UDim2.fromOffset(28, 62),
	Size = UDim2.fromOffset(160, 18),
	BackgroundTransparency = 1,
	Text = "VANDAL",
	FontFace = Font.new(BX, Enum.FontWeight.Bold),
	TextSize = 13,
	TextColor3 = MUTED,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 2,
}, am)
-- one tick per round (built by the script from the mag size)
local rounds = make("Frame", {
	Name = "Rounds",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromOffset(378, 66),
	Size = UDim2.fromOffset(200, 12),
	BackgroundTransparency = 1,
	ZIndex = 2,
}, am)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	Padding = UDim.new(0, 2),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, rounds)
for i = 1, 25 do
	make("Frame", {
		Name = "Preview" .. i,
		LayoutOrder = i,
		Size = UDim2.fromOffset(5, 12),
		BackgroundColor3 = TEXT,
		BackgroundTransparency = if i <= 7 then 0.86 else 0,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, rounds):SetAttribute("Preview", true)
end
local reload = make("Frame", {
	Name = "ReloadBar",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, 0),
	Size = UDim2.new(1, 0, 0, 4),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 3,
}, am)
make("Frame", {
	Name = "Fill",
	Size = UDim2.fromScale(0.6, 1),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	ZIndex = 3,
}, reload)

-- MODS (bottom-centre) -------------------------------------------------------
local mods = make("Frame", {
	Name = "Mods",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 0.965, 0),
	Size = UDim2.fromOffset(0, 104),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
}, root)
make("UIScale", { Name = "Fit" }, mods)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 12),
	SortOrder = Enum.SortOrder.LayoutOrder,
	VerticalAlignment = Enum.VerticalAlignment.Top,
}, mods)
for i, m in PREVIEW_MODS do
	local slot = make(
		"Frame",
		{
			Name = "Slot" .. i,
			LayoutOrder = i,
			Size = UDim2.fromOffset(80, 104),
			BackgroundTransparency = 1,
		},
		mods
	)
	softShadow(slot, 80, 80, 46)
	local face = make(
		"Frame",
		{ Name = "Face", Size = UDim2.fromOffset(80, 80), BackgroundTransparency = 1, ZIndex = 1 },
		slot
	)
	make("UIScale", { Name = "Pop" }, face)
	local cell = make("CanvasGroup", {
		Name = "Cell",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = PLATE,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, face)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, cell)
	make("UIGradient", { Name = "Shade", Rotation = 90, Color = DARK_SHADE }, cell)
	local wash = make(
		"Frame",
		{
			Name = "RoleWash",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = m.role,
			BorderSizePixel = 0,
		},
		cell
	)
	make("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.55, 0.92),
			NumberSequenceKeypoint.new(1, 0.55),
		}),
	}, wash)
	make("ImageLabel", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(46, 46),
		BackgroundTransparency = 1,
		Image = m.icon,
	}, cell)
	make("Frame", {
		Name = "Cooldown",
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = hex("06080C"),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
	}, cell)
	number(
		cell,
		"Seconds",
		"",
		30,
		{ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) }
	)
	make("Frame", {
		Name = "ReadyLine",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = m.role,
		BorderSizePixel = 0,
	}, cell)
	-- active effect (Mod<n>ActiveUntil): a bar along the top that runs down
	make("Frame", {
		Name = "Active",
		Size = UDim2.new(0, 0, 0, 3),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
	}, cell)
	local pips = make("Frame", {
		Name = "Charges",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 7),
		Size = UDim2.fromOffset(0, 4),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
	}, cell)
	make(
		"UIListLayout",
		{
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 3),
			SortOrder = Enum.SortOrder.LayoutOrder,
		},
		pips
	)
	for c = 1, 3 do
		make("Frame", {
			Name = "Pip" .. c,
			LayoutOrder = c,
			Size = UDim2.fromOffset(14, 4),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			Visible = false,
		}, pips)
	end
	make("TextLabel", {
		Name = "Level",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -5, 0, 4),
		Size = UDim2.fromOffset(24, 14),
		BackgroundTransparency = 1,
		Text = "",
		FontFace = Font.new(BX, Enum.FontWeight.Bold),
		TextSize = 11,
		TextColor3 = m.role,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, cell)
	make("UIStroke", {
		Name = "Edge",
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = WHITE,
		Thickness = 2,
		Transparency = 1,
	}, cell)
	local key = make("Frame", {
		Name = "Key",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 84),
		Size = UDim2.fromOffset(28, 20),
		BackgroundColor3 = hex("2A313D"),
		BorderSizePixel = 0,
		ZIndex = 2,
	}, slot)
	make("UICorner", { CornerRadius = UDim.new(0, 4) }, key)
	make("TextLabel", {
		Name = "Label",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = ({ "Q", "E", "T" })[i],
		FontFace = Font.new(BX, Enum.FontWeight.ExtraBold),
		TextSize = 12,
		TextColor3 = WHITE,
		ZIndex = 3,
	}, key)
end

gui.Parent = StarterGui
print("BottomHud built")
