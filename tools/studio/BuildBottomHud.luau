--!strict
-- Rebuilds the match's bottom combat HUD (health + shield, ammo, weapon hotbar,
-- key hints, Mod slots) in the match place, as it is after the de-AI pass
-- (vault/02 Art/UI Notifications.md, UI Combat HUD Mockup.md). Regenerated from
-- the saved place, 2026-11-14. Studio owns StarterGui.BottomHud; this is its
-- backup in git. Paste into the Studio command bar (Edit mode). It refuses to
-- run if StarterGui.BottomHud exists.
-- Behaviour: src/client/Util/BottomHud.luau (fed by HudController,
-- ModHudController, WeaponController). Desktop only for now.
-- Look: flat navy faces, no gradients, glows, chips or outlines; Mods are flat
-- role-colour blocks with a darker lip; keycaps are a raised face on a darker
-- base. Pieces that pop scale from their centre (Mod Face, hotbar Cell).

local StarterGui = game:GetService("StarterGui")

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
local PREVIEW_MODS = { -- icon, role colour (Theme.ROLE); replaced in play
	{ "rbxassetid://140468016168978", Color3.fromHex("2BD9A8") },
	{ "rbxassetid://115604306101761", Color3.fromHex("FF7A3D") },
	{ "rbxassetid://104088410327059", Color3.fromHex("C15CFF") },
}
local PREVIEW_LOADOUT = {
	{ "Primary", "rbxassetid://108427985127422", "18" },
	{ "Secondary", "rbxassetid://91264904103058", "13" },
	{ "Melee", "rbxassetid://113310955014391", "" },
}
local NAVY = Color3.fromHex("1C2740")
local CYAN = Color3.fromHex("3FE0F2")
local WHITE = Color3.new(1, 1, 1)
local TEXT = Color3.fromHex("F4F6F9")
local MUTED = Color3.fromHex("9AA4B2")
local INK = Color3.fromHex("06080C")
local CENTRE = Vector2.new(0.5, 0.5)
local FILL = UDim2.fromScale(1, 1)

assert(not StarterGui:FindFirstChild("BottomHud"), "StarterGui.BottomHud already exists")

-- A number with a soft drop shadow: Frame → Shadow + Value labels.
local function number(
	parent: Instance,
	name: string,
	text: string,
	size: number,
	props: { [string]: any }
): Frame
	local f = make("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, size + 6),
	}, parent)
	for k, v in props do
		(f :: any)[k] = v
	end
	for _, part in { "Shadow", "Value" } do
		make("TextLabel", {
			Name = part,
			Position = UDim2.fromOffset(0, if part == "Shadow" then 3 else 0),
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			ZIndex = if part == "Shadow" then 4 else 5,
			Text = text,
			FontFace = Font.new(BX, Enum.FontWeight.ExtraBold),
			TextSize = size,
			TextColor3 = if part == "Shadow" then INK else WHITE,
			TextTransparency = if part == "Shadow" then 0.6 else 0,
		}, f)
	end
	return f
end

local function softShadow(parent: Instance, w: number, h: number, y: UDim2, transparency: number)
	make("ImageLabel", {
		Name = "Shadow",
		AnchorPoint = CENTRE,
		Position = y,
		Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1,
		ZIndex = 0,
		Image = SHADOW,
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = transparency,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(48, 48, 80, 80),
	}, parent)
end

-- A keycap: a raised face on a darker base, the key on the face.
local function keycap(
	parent: Instance,
	text: string,
	w: number,
	h: number,
	props: { [string]: any }
): Frame
	local key = make("Frame", {
		Name = "Key",
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = Color3.fromHex("0B0F17"),
		BorderSizePixel = 0,
		ZIndex = 3,
	}, parent)
	for k, v in props do
		(key :: any)[k] = v
	end
	make("UICorner", { CornerRadius = UDim.new(0, 4) }, key)
	local face = make("Frame", {
		Name = "Face",
		Size = UDim2.new(1, 0, 1, -3),
		BackgroundColor3 = Color3.fromHex("3A4766"),
		BorderSizePixel = 0,
		ZIndex = 4,
	}, key)
	make("UICorner", { CornerRadius = UDim.new(0, 4) }, face)
	make("TextLabel", {
		Name = "Label",
		Size = FILL,
		BackgroundTransparency = 1,
		ZIndex = 5,
		Text = text,
		FontFace = Font.new(BX, Enum.FontWeight.ExtraBold),
		TextSize = math.floor(h * 0.5),
		TextColor3 = WHITE,
	}, face)
	return key
end

-- A flat navy panel whose end toward the screen centre is a slanted cap.
local function panel(parent: Instance, name: string, slantRight: boolean): (Frame, Frame)
	local holder = make(
		"Frame",
		{ Name = name, Size = UDim2.fromOffset(416, 96), BackgroundTransparency = 1 },
		parent
	)
	softShadow(holder, 472, 144, UDim2.new(0.5, 0, 0, 54), 0.5)
	local body = make("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(if slantRight then 0 else 20, 0),
		Size = UDim2.fromOffset(396, 96),
		BackgroundColor3 = NAVY,
		BorderSizePixel = 0,
	}, holder)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, body)
	make("ImageLabel", {
		Name = "Slant",
		Position = UDim2.fromOffset(if slantRight then 388 else 0, 0),
		Size = UDim2.fromOffset(28, 96),
		BackgroundTransparency = 1,
		Image = if slantRight then CAP_R else CAP_L,
		ImageColor3 = NAVY,
	}, holder)
	make("UIScale", { Name = "Fit" }, holder)
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
local root = make("Frame", { Name = "Root", Size = FILL, BackgroundTransparency = 1 }, gui)

-- HEALTH (bottom-left) -------------------------------------------------------
local hpHolder, hp = panel(root, "Health", true)
hpHolder.AnchorPoint = Vector2.new(0, 1)
hpHolder.Position = UDim2.new(0.024, 0, 0.965, 0)
make("ImageLabel", {
	Name = "Icon",
	Position = UDim2.fromOffset(18, 16),
	Size = UDim2.fromOffset(26, 26),
	BackgroundTransparency = 1,
	ZIndex = 2,
	Image = ICON_HP,
}, hp)
number(hp, "HP", "100", 46, { Position = UDim2.fromOffset(54, 4), ZIndex = 2 })
-- shield: an icon and a cyan number, no chip box
local chip = make("Frame", {
	Name = "ShieldChip",
	Position = UDim2.fromOffset(214, 10),
	Size = UDim2.fromOffset(84, 34),
	BackgroundTransparency = 1,
	ZIndex = 2,
}, hp)
make("ImageLabel", {
	Name = "Icon",
	Position = UDim2.fromOffset(0, 5),
	Size = UDim2.fromOffset(24, 24),
	BackgroundTransparency = 1,
	ZIndex = 3,
	Image = ICON_SHIELD,
	ImageColor3 = CYAN,
}, chip)
local shield = number(
	chip,
	"Value",
	"25",
	24,
	{ Position = UDim2.fromOffset(30, 0), Size = UDim2.fromOffset(0, 26), ZIndex = 3 }
)
local shieldValue = shield:FindFirstChild("Value")
if shieldValue and shieldValue:IsA("TextLabel") then
	shieldValue.TextColor3 = CYAN
end
local segs = make("Frame", {
	Name = "Segments",
	Position = UDim2.fromOffset(18, 66),
	Size = UDim2.fromOffset(350, 12),
	BackgroundTransparency = 1,
	ZIndex = 2,
}, hp)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 3),
	SortOrder = Enum.SortOrder.LayoutOrder,
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
		BackgroundColor3 = CYAN,
		BackgroundTransparency = if i <= 2 then 0 else 0.86,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, segs)
	make("UICorner", { CornerRadius = UDim.new(0, 2) }, s)
end

-- AMMO (bottom-right) --------------------------------------------------------
local amHolder, am = panel(root, "Ammo", false)
amHolder.AnchorPoint = Vector2.new(1, 1)
amHolder.Position = UDim2.new(0.976, 0, 0.965, 0)
make("ImageLabel", {
	Name = "Gun",
	Position = UDim2.fromOffset(28, 14),
	Size = UDim2.fromOffset(150, 46),
	BackgroundTransparency = 1,
	ZIndex = 2,
	Image = PREVIEW_GUN,
	ScaleType = Enum.ScaleType.Fit,
}, am)
number(
	am,
	"Mag",
	"18",
	46,
	{ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(318, 4), ZIndex = 2 }
)
make("TextLabel", {
	Name = "MagSize", -- not "Size": that is a GuiObject property
	Position = UDim2.fromOffset(322, 22),
	Size = UDim2.fromOffset(60, 24),
	BackgroundTransparency = 1,
	ZIndex = 2,
	Text = "/25",
	FontFace = Font.new(BX, Enum.FontWeight.Bold),
	TextSize = 18,
	TextColor3 = MUTED,
	TextXAlignment = Enum.TextXAlignment.Left,
}, am)
make("TextLabel", {
	Name = "GunName",
	Position = UDim2.fromOffset(28, 62),
	Size = UDim2.fromOffset(160, 18),
	BackgroundTransparency = 1,
	ZIndex = 2,
	Text = "VANDAL",
	FontFace = Font.new(BX, Enum.FontWeight.Bold),
	TextSize = 13,
	TextColor3 = MUTED,
	TextXAlignment = Enum.TextXAlignment.Left,
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
	local tick = make("Frame", {
		Name = "Preview" .. i,
		LayoutOrder = i,
		Size = UDim2.fromOffset(5, 12),
		BackgroundColor3 = TEXT,
		BackgroundTransparency = if i <= 7 then 0.86 else 0,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, rounds)
	tick:SetAttribute("Preview", true)
end
local reload = make("Frame", {
	Name = "ReloadBar",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 4),
	BackgroundTransparency = 1,
	ZIndex = 3,
	Visible = false,
}, am)
make("Frame", {
	Name = "Fill",
	Size = UDim2.fromScale(0.6, 1),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	ZIndex = 3,
}, reload)

-- MODS (bottom-centre): only drafted slots show; the row centres on them --------
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
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 12),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, mods)
for i, m in PREVIEW_MODS do
	local slot = make("Frame", {
		Name = "Slot" .. i,
		LayoutOrder = i,
		Size = UDim2.fromOffset(80, 104),
		BackgroundTransparency = 1,
	}, mods)
	softShadow(slot, 136, 128, UDim2.new(0.5, 0, 0, 46), 0.5)
	local face = make("Frame", {
		Name = "Face",
		AnchorPoint = CENTRE,
		Position = UDim2.new(0.5, 0, 0, 40), -- BottomHud FACE_Y
		Size = UDim2.fromOffset(80, 80),
		BackgroundTransparency = 1,
	}, slot)
	make("UIScale", { Name = "Pop" }, face)
	local cell = make(
		"CanvasGroup",
		{ Name = "Cell", Size = FILL, BackgroundColor3 = m[2], BorderSizePixel = 0 },
		face
	)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, cell)
	make("ImageLabel", {
		Name = "IconShadow",
		AnchorPoint = CENTRE,
		Position = UDim2.new(0.5, 0, 0.5, 3),
		Size = UDim2.fromOffset(46, 46),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Image = m[1],
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 0.65,
	}, cell)
	make("ImageLabel", {
		Name = "Icon",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(46, 46),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Image = m[1],
	}, cell)
	make("Frame", {
		Name = "Lip",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.72,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, cell)
	-- cooling: a dark curtain over the colour, the seconds on top
	make("Frame", {
		Name = "Cooldown",
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, cell)
	local seconds = number(cell, "Seconds", "", 30, {
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 5,
	})
	for _, label in seconds:GetChildren() do
		if label:IsA("TextLabel") then
			label.ZIndex = if label.Name == "Shadow" then 5 else 6
		end
	end
	make("Frame", {
		Name = "ActiveBar", -- not "Active": that is a GuiObject property
		Size = UDim2.fromOffset(0, 3),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = 6,
	}, cell)
	local pips = make("Frame", {
		Name = "Charges",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 7),
		Size = UDim2.fromOffset(0, 4),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		ZIndex = 6,
	}, cell)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 3),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, pips)
	for c = 1, 3 do
		make("Frame", {
			Name = "Pip" .. c,
			LayoutOrder = c,
			Size = UDim2.fromOffset(14, 4),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			ZIndex = 6,
			Visible = false,
		}, pips)
	end
	make("TextLabel", {
		Name = "Level",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -5, 0, 4),
		Size = UDim2.fromOffset(24, 14),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Text = "",
		FontFace = Font.new(BX, Enum.FontWeight.Bold),
		TextSize = 11,
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, cell)
	make("UIStroke", {
		Name = "Edge",
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = WHITE,
		Thickness = 2,
		Transparency = 1,
	}, cell)
	local glint = make("Frame", {
		Name = "Glint",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(-0.6, 0.5),
		Size = UDim2.fromScale(0.32, 1.8),
		Rotation = 22,
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = 7,
	}, cell)
	make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, glint)
	keycap(slot, ({ "Q", "E", "T" })[i], 26, 25, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 84),
	})
end

-- WEAPON HOTBAR (above the ammo) -------------------------------------------------
local loadout = make("Frame", {
	Name = "Loadout",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(0.976, -8, 0.965, -106),
	Size = UDim2.fromOffset(0, 52),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
}, root)
make("UIScale", { Name = "Fit" }, loadout)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, loadout)
for i, p in PREVIEW_LOADOUT do
	local holder = make("Frame", {
		Name = p[1],
		LayoutOrder = i,
		Size = UDim2.fromOffset(104, 52),
		BackgroundTransparency = 1,
	}, loadout)
	softShadow(holder, 144, 86, UDim2.new(0.5, 0, 0.5, 4), 0.6)
	-- the Cell is centred in its holder, so its pop scales from the middle
	local cell = make("CanvasGroup", {
		Name = "Cell",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = FILL,
		BackgroundColor3 = NAVY,
		BorderSizePixel = 0,
		GroupTransparency = if i == 1 then 0 else 0.3,
	}, holder)
	make("UICorner", { CornerRadius = UDim.new(0, 5) }, cell)
	make("ImageLabel", {
		Name = "Icon",
		AnchorPoint = CENTRE,
		Position = UDim2.new(0.5, 4, 0.5, -2),
		Size = UDim2.fromOffset(72, 30),
		BackgroundTransparency = 1,
		Image = p[2],
		ScaleType = Enum.ScaleType.Fit,
	}, cell)
	make("TextLabel", {
		Name = "Ammo",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -6, 1, -4),
		Size = UDim2.fromOffset(40, 14),
		BackgroundTransparency = 1,
		Text = p[3],
		FontFace = Font.new(BX, Enum.FontWeight.ExtraBold),
		TextSize = 12,
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, cell)
	make("Frame", {
		Name = "Equipped",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 3),
		BackgroundColor3 = CYAN,
		BorderSizePixel = 0,
		Visible = i == 1,
	}, cell)
	make("UIStroke", { -- kept for the script, never shown (no outlines)
		Name = "Edge",
		Enabled = false,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = WHITE,
		Thickness = 1.5,
		Transparency = 1,
	}, cell)
	make("UIScale", { Name = "Pop" }, cell)
	keycap(holder, tostring(i), 20, 21, { Position = UDim2.fromOffset(5, 5) })
end

-- KEY HINTS (under the ammo; the script writes the real bindings) -------------
local hints = make("Frame", {
	Name = "Hints",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(0.976, -8, 0.992, 0),
	Size = UDim2.fromOffset(0, 24),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
}, root)
make("UIScale", { Name = "Fit" }, hints)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 14),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, hints)
-- names match Config/Input actions
for i, h in
	{
		{ "QuickMelee", "V", "QUICK MELEE" },
		{ "Inspect", "Y", "INSPECT" },
		{ "Reload", "R", "RELOAD" },
	}
do
	local pair = make("Frame", {
		Name = h[1],
		LayoutOrder = i,
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
	}, hints)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, pair)
	local label = make("TextLabel", {
		Name = "Label",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Text = h[3],
		FontFace = Font.new(BX, Enum.FontWeight.Bold),
		TextSize = 13,
		TextColor3 = Color3.fromHex("C9D1DC"),
	}, pair)
	make("UIStroke", { Color = INK, Thickness = 1.5, Transparency = 0.5 }, label)
	keycap(pair, h[2], 24, 24, { LayoutOrder = 2 })
end

gui.Parent = StarterGui
print("BottomHud built")
