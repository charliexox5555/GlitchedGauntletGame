--!strict
-- The real touch controls screen: StarterPlayerScripts.UI.Match.Touch
-- (vault/02 Art/UI Mobile Controls.md, mockup v2; vault/04 Tech/UI Architecture.md).
-- Studio owns the layout; client/Controllers/TouchController and
-- client/Util/TouchHud bind it. Buttons are ImageButtons named after the touch
-- names in Config/Input, so InputController.bindTouchButtons links them.
-- Aim, Sprint and Slide are toggles driven by TouchController; Jump too.
--
-- Run in the Command Bar of the Lobby place. Replaces an older Touch screen.

local StarterPlayer = game:GetService("StarterPlayer")

local ICON = { -- Image ids (tools/ui/make_touch_icons.py; Decal → Texture)
	fire = "rbxassetid://135726244460812",
	aim = "rbxassetid://107415217985792",
	jump = "rbxassetid://131982850781889",
	chevrons = "rbxassetid://104005329078038",
	run = "rbxassetid://79053604029217",
	slide = "rbxassetid://104983316016957",
	reload = "rbxassetid://126053863629496",
	scoreboard = "rbxassetid://129842333470941",
	settings = "rbxassetid://104414575492598",
	melee = "rbxassetid://109206289996649",
	inspect = "rbxassetid://81954128010874",
}
local PLATE = Color3.fromHex("10141B")
local TEXT = Color3.fromHex("F4F6F9")
local MUTED = Color3.fromHex("A9B2BF")
local GOLD = Color3.fromHex("FFC83D")
local REST = 0.45
local HEAVY = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy)
local BOLD = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold)

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

local function round(o: Instance)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, o)
end

local function label(parent: Instance, name: string, props: { [string]: any }): TextLabel
	local t = make("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		FontFace = HEAVY,
		Text = "",
		TextColor3 = TEXT,
		TextScaled = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.6, 0.5),
		ZIndex = 3,
	}, parent)
	for k, v in props do
		(t :: any)[k] = v
	end
	make("UITextSizeConstraint", { MinTextSize = 12, MaxTextSize = 60 }, t)
	return t
end

local function cluster(parent: Instance, name: string, anchor: Vector2, side: number): Frame
	local f = make("Frame", {
		Name = name,
		AnchorPoint = anchor,
		Position = UDim2.fromScale(anchor.X, anchor.Y),
		Size = UDim2.fromScale(side, side),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, parent)
	f:SetAttribute("PhoneSide", side) -- TouchController: tablets × 0.78
	return f
end

-- A round touch button: an ImageButton (the hit area) with a Press UIScale on
-- an inner Face (motion never scales the hit area), an Icon and a Label.
local function button(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	d: number,
	icon: string?,
	iconScale: number?
): ImageButton
	local b = make("ImageButton", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(d, d),
		BackgroundTransparency = 1,
		Image = "",
		AutoButtonColor = false,
		ZIndex = 2,
	}, parent)
	make("UIAspectRatioConstraint", { AspectRatio = 1 }, b)
	local face = make("Frame", {
		Name = "Face",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = PLATE,
		BackgroundTransparency = REST,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, b)
	round(face)
	make("UIScale", { Name = "Press" }, face)
	local s = iconScale or 0.56
	make("ImageLabel", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(s, s),
		BackgroundTransparency = 1,
		Image = icon or "",
		ImageColor3 = TEXT,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 3,
	}, face)
	return b
end

local ui = StarterPlayer.StarterPlayerScripts:FindFirstChild("UI")
assert(ui, "StarterPlayerScripts.UI is missing")
local match = ui:FindFirstChild("Match")
assert(match, "UI.Match is missing")
local old = match:FindFirstChild("Touch")
if old then
	old:Destroy()
end

local gui = make("ScreenGui", {
	Name = "Touch",
	Enabled = false, -- TouchController turns it on for touch players
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
gui:SetAttribute("Layer", "Touch") -- UiRoot: DeviceSafeInsets, DisplayOrder 15
local root =
	make("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, gui)

-- The stick: touches that start in the zone drive it (the zone is a button so
-- the camera ignores those touches). The stick rests faint where a thumb would.
make("ImageButton", {
	Name = "StickZone",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.fromScale(0.42, 0.62),
	BackgroundTransparency = 1,
	Image = "",
	AutoButtonColor = false,
	ZIndex = 1,
}, root)
local stick = make("Frame", {
	Name = "Stick",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0, 0, 1, 0),
	Size = UDim2.fromScale(0.27, 0.27),
	SizeConstraint = Enum.SizeConstraint.RelativeYY,
	BackgroundColor3 = PLATE,
	BackgroundTransparency = 0.6,
	BorderSizePixel = 0,
	Active = false,
	ZIndex = 1,
}, root)
round(stick)
make("ImageLabel", {
	Name = "SprintLock",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromScale(0.5, -0.06),
	Size = UDim2.fromScale(0.26, 0.26),
	Rotation = -90,
	BackgroundTransparency = 1,
	Image = ICON.chevrons,
	ImageColor3 = TEXT,
	ImageTransparency = 0.35,
}, stick)
local nub = make("Frame", {
	Name = "Nub",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.42, 0.42),
	BackgroundColor3 = TEXT,
	BackgroundTransparency = 0.12,
	BorderSizePixel = 0,
}, stick)
round(nub)

local left = cluster(root, "LeftCluster", Vector2.new(0, 1), 0.8)
left.Active = false
local rest = make("Frame", { -- where the stick rests (TouchController reads it)
	Name = "StickRest",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.43, 0.66),
	Size = UDim2.fromScale(0.02, 0.02),
	BackgroundTransparency = 1,
}, left)
local _ = rest
button(left, "SprintButton", 0.22, 0.34, 0.16, ICON.run, 0.62)

local right = cluster(root, "RightCluster", Vector2.new(1, 1), 0.8)
local FIRE = Vector2.new(0.53, 0.55)
local MOD_ARC = 0.245
button(right, "JumpButton", 0.776, 0.763, 0.276, ICON.jump)
local fire = button(right, "FireButton", FIRE.X, FIRE.Y, 0.256, ICON.fire, 0.6)
fire.Face.Icon.ImageColor3 = GOLD -- the one gold thing
button(right, "AimButton", 0.84, 0.45, 0.212, ICON.aim)
button(right, "SlideButton", 0.5, 0.85, 0.212, ICON.slide)
button(right, "ReloadButton", 0.31, 0.735, 0.147, ICON.reload)
local mods = make(
	"Frame",
	{ Name = "Mods", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2 },
	right
)
for i, deg in { 196, 244, 292 } do
	local a = math.rad(deg)
	local b = button(
		mods,
		"Mod" .. i .. "Button",
		FIRE.X + MOD_ARC * math.cos(a),
		FIRE.Y + MOD_ARC * math.sin(a),
		0.173,
		nil,
		0.74
	)
	b.Visible = false -- ModHudController shows a slot once it holds a Mod
	label(b.Face, "Label", {}) -- cooldown seconds / glyph (ModHudController)
end
local alt = button(mods, "ModAltButton", 0.74, 0.2, 0.15, nil)
alt.Visible = false
label(alt.Face, "Label", { Size = UDim2.fromScale(0.7, 0.4), Text = "ALT" })

-- Top-right: weapon slots (gun art spills out, angled), the ammo readout under
-- the held one, quick melee under the knife.
local weapons = cluster(root, "Weapons", Vector2.new(1, 0), 0.5)
for i, slot in { "Primary", "Secondary", "Melee" } do
	local b = button(weapons, slot .. "Button", 0.2 + (i - 1) * 0.27, 0.17, 0.23, nil)
	b:SetAttribute("Slot", slot)
	local icon = b.Face.Icon
	icon.Name = "Gun"
	icon.Size = UDim2.fromScale(1.15, 1.15)
	icon.Position = UDim2.fromScale(0.5, 0.44)
	icon.Rotation = -35
	local count = label(b.Face, "Count", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.98),
		Size = UDim2.fromScale(0.5, 0.3),
		ZIndex = 4,
	})
	make("UIStroke", { Color = PLATE, Thickness = 1.5, Transparency = 0.2 }, count)
	b.Visible = false -- shown when the loadout has that slot
end
local chip = make("Frame", {
	Name = "AmmoReadout",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.2, 0.3),
	Size = UDim2.fromScale(0.3, 0.12),
	BackgroundColor3 = PLATE,
	BackgroundTransparency = 0.25,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 2,
}, weapons)
make("UICorner", { CornerRadius = UDim.new(0.18, 0) }, chip)
label(chip, "Mag", {
	AnchorPoint = Vector2.zero,
	Position = UDim2.fromScale(0.08, 0.06),
	Size = UDim2.fromScale(0.44, 0.66),
	TextXAlignment = Enum.TextXAlignment.Right,
})
label(chip, "Reserve", {
	AnchorPoint = Vector2.zero,
	Position = UDim2.fromScale(0.55, 0.22),
	Size = UDim2.fromScale(0.38, 0.46),
	TextColor3 = MUTED,
	FontFace = BOLD,
	TextXAlignment = Enum.TextXAlignment.Left,
})
local magBar = make("Frame", {
	Name = "MagBar",
	Position = UDim2.fromScale(0.08, 0.8),
	Size = UDim2.fromScale(0.84, 0.09),
	BackgroundColor3 = TEXT,
	BackgroundTransparency = 0.8,
	BorderSizePixel = 0,
	ZIndex = 3,
}, chip)
make("Frame", {
	Name = "Fill",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = TEXT,
	BorderSizePixel = 0,
	ZIndex = 4,
}, magBar)
button(weapons, "QuickMeleeButton", 0.74, 0.42, 0.22, ICON.melee, 0.55)

-- Health: the mockup's simple bar, bottom-left under the stick (Util/TouchHud
-- fills it; the old CombatHud panel hides on touch).
local health = make("Frame", {
	Name = "Health",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0.012, 0.975),
	Size = UDim2.fromScale(0.6, 0.06),
	SizeConstraint = Enum.SizeConstraint.RelativeYY,
	BackgroundColor3 = PLATE,
	BackgroundTransparency = 0.35,
	BorderSizePixel = 0,
	ZIndex = 1,
}, root)
make("UICorner", { CornerRadius = UDim.new(0.25, 0) }, health)
local hpFill = make("Frame", {
	Name = "Fill",
	Position = UDim2.fromScale(0.03, 0.22),
	Size = UDim2.fromScale(0.68, 0.56),
	BackgroundColor3 = TEXT,
	BorderSizePixel = 0,
	ZIndex = 2,
}, health)
make("UICorner", { CornerRadius = UDim.new(0.25, 0) }, hpFill)
make("Frame", {
	Name = "Shield",
	Position = UDim2.fromScale(0.03, 0.06),
	Size = UDim2.fromScale(0, 0.1),
	BackgroundColor3 = Color3.fromHex("2FD3E6"),
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 2,
}, health)
label(health, "Value", {
	Text = "100",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.fromScale(0.96, 0.5),
	Size = UDim2.fromScale(0.22, 0.72),
	TextXAlignment = Enum.TextXAlignment.Right,
})

-- Top-left: Settings beside Roblox's buttons (TouchController places it from
-- GuiService.TopbarInset); Scoreboard and Inspect in a row under them.
local topLeft = cluster(root, "TopLeft", Vector2.new(0, 0), 0.6)
local settings = button(topLeft, "SettingsButton", 0.615, 0.11, 0.16, ICON.settings, 0.6)
settings.Visible = false -- no match settings screen yet
button(topLeft, "ScoreboardButton", 0.1, 0.31, 0.16, ICON.scoreboard, 0.52)
button(topLeft, "InspectButton", 0.305, 0.31, 0.16, ICON.inspect, 0.58)

gui.Parent = match
print("[BuildTouchScreen] UI.Match.Touch built")
return "ok"
