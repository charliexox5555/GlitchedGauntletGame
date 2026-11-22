--!strict
-- Touch controls mockup (vault/02 Art/UI Mobile Controls.md).
-- Builds StarterGui.TouchMockup (parked for editing; tools/studio/UiEdit.luau
-- "store" moves it to StarterPlayerScripts.UI.Mockups).
--
-- Layout rules (vault/04 Tech/UI Architecture.md §5-6): corner clusters are
-- squares sized off the screen height (SizeConstraint RelativeYY), so a
-- cluster keeps its shape on any aspect ratio; everything inside is Scale;
-- text is TextScaled with a minimum size. Icons: tools/ui/make_touch_icons.py.
--
-- PREVIEW = a device size draws the screen at that size, scaled up to fill
-- the Studio viewport, for captures. PREVIEW = nil builds the real
-- full-screen version.

local PREVIEW: Vector2? = Vector2.new(844, 390)

local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")

-- Image ids (the uploads are Decals; InsertService:LoadAsset(id) → Decal.Texture).
local ICON = {
	fire = "rbxassetid://135726244460812",
	aim = "rbxassetid://107415217985792",
	jump = "rbxassetid://131982850781889",
	sprint = "rbxassetid://104005329078038", -- the » chevrons: the stick's sprint-lock hint
	run = "rbxassetid://79053604029217", -- the Sprint button
	slide = "rbxassetid://104983316016957",
	reload = "rbxassetid://126053863629496",
	scoreboard = "rbxassetid://129842333470941",
	settings = "rbxassetid://104414575492598",
	melee = "rbxassetid://109206289996649",
}
local MOD = { -- Config/Mods icons
	Dash = "rbxassetid://140468016168978",
	Updraft = "rbxassetid://109401404845816",
	Molly = "rbxassetid://115604306101761",
}
local GUN = { -- Config/Theme.GUN
	Vandal = "rbxassetid://108427985127422",
	Sheriff = "rbxassetid://122134937133172",
	Knife = "rbxassetid://113310955014391",
}

local PLATE = Color3.fromHex("10141B")
local TEXT = Color3.fromHex("F4F6F9")
local GOLD = Color3.fromHex("FFC83D")
local ALLY = Color3.fromHex("2FD3E6")
local ENEMY = Color3.fromHex("FF5A4E")
local REST = 0.45 -- a resting button: dark plate at 55%
local FONT = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy) -- Rubik (UiStyle.FONT.display)
local MIN_TEXT = 12

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

local function round(parent: Instance)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, parent)
end

local function text(
	parent: Instance,
	name: string,
	value: string,
	props: { [string]: any }
): TextLabel
	local t = make("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		FontFace = FONT,
		Text = value,
		TextColor3 = TEXT,
		TextScaled = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
	}, parent)
	for k, v in props do
		(t :: any)[k] = v
	end
	make("UITextSizeConstraint", { MinTextSize = MIN_TEXT, MaxTextSize = 60 }, t)
	return t
end

-- A square cluster anchored to a screen corner, `side` x screen height.
local function cluster(parent: Instance, name: string, anchor: Vector2, side: number): Frame
	return make("Frame", {
		Name = name,
		AnchorPoint = anchor,
		Position = UDim2.fromScale(anchor.X, anchor.Y),
		Size = UDim2.fromScale(side, side),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundTransparency = 1,
	}, parent)
end

type ButtonOpts = { icon: string?, on: boolean?, gold: boolean?, iconScale: number? }

-- A round touch button centred at (x, y) in its cluster, `d` = diameter.
local function button(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	d: number,
	o: ButtonOpts
): Frame
	local b = make("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(d, d),
		BackgroundColor3 = if o.on then TEXT else PLATE,
		BackgroundTransparency = if o.on then 0.06 else REST,
		BorderSizePixel = 0,
	}, parent)
	round(b)
	make("UIAspectRatioConstraint", { AspectRatio = 1 }, b)
	if o.icon then
		local s = o.iconScale or 0.56
		make("ImageLabel", {
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(s, s),
			BackgroundTransparency = 1,
			Image = o.icon,
			ImageColor3 = if o.on then PLATE elseif o.gold then GOLD else TEXT,
			ScaleType = Enum.ScaleType.Fit,
		}, b)
	end
	return b
end

-- Remove older builds (parked or stored).
for _, where in { StarterGui, StarterPlayer.StarterPlayerScripts:FindFirstChild("UI") } do
	if where then
		for _, d in where:GetDescendants() do
			if d.Name == "TouchMockup" and d:IsA("ScreenGui") then
				d:Destroy()
			end
		end
	end
end

local gui = make("ScreenGui", {
	Name = "TouchMockup",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
	SafeAreaCompatibility = Enum.SafeAreaCompatibility.None,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 15,
})
gui:SetAttribute("Layer", "Touch")
gui:SetAttribute("UiEditFrom", "Mockups") -- parked: UiEdit "store" puts it in UI.Mockups

local root = make("Frame", {
	Name = "Root",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1, 1),
	ClipsDescendants = true,
}, gui)
if PREVIEW then
	local vp = workspace.CurrentCamera.ViewportSize
	root.Size = UDim2.fromOffset(PREVIEW.X, PREVIEW.Y)
	make("UIScale", {
		Name = "PreviewScale",
		Scale = math.min(vp.X * 0.97 / PREVIEW.X, vp.Y * 0.95 / PREVIEW.Y),
	}, root)
	make("UIStroke", { Name = "PreviewEdge", Color = Color3.new(0, 0, 0), Thickness = 2 }, root)
	gui:SetAttribute("PreviewDevice", `{PREVIEW.X}x{PREVIEW.Y}`)
end

-- Right cluster (0.8 H square, bottom-right): Jump, Fire, Aim, Slide, Reload, Mods.
local right = cluster(root, "RightCluster", Vector2.new(1, 1), 0.8)
button(right, "Jump", 0.776, 0.763, 0.276, { icon = ICON.jump })
button(right, "Fire", 0.474, 0.506, 0.256, { icon = ICON.fire, gold = true, iconScale = 0.6 })
button(right, "Aim", 0.814, 0.353, 0.212, { icon = ICON.aim })
button(right, "Slide", 0.462, 0.853, 0.212, { icon = ICON.slide })
button(right, "Reload", 0.167, 0.686, 0.147, { icon = ICON.reload })
local mods = make(
	"Frame",
	{ Name = "Mods", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) },
	right
)
for i, m in
	{
		{ "Dash", 0.192, 0.436, nil },
		{ "Updraft", 0.301, 0.237, "4" },
		{ "Molly", 0.506, 0.122, nil },
	}
do
	local b = button(
		mods,
		"Mod" .. i,
		m[2] :: number,
		m[3] :: number,
		0.173,
		{ icon = MOD[m[1] :: string], iconScale = 0.74 }
	)
	if m[4] then
		local cool = make("Frame", {
			Name = "Cooldown",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = PLATE,
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, b)
		round(cool)
		text(cool, "Seconds", m[4] :: string, {
			Position = UDim2.fromScale(0.5, 0.52),
			Size = UDim2.fromScale(0.6, 0.5),
			ZIndex = 3,
		})
	end
end

-- Left cluster (0.8 H square, bottom-left): the stick where the thumb landed, Sprint (on).
local left = cluster(root, "LeftCluster", Vector2.new(0, 1), 0.8)
local stick = make("Frame", {
	Name = "Stick",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.43, 0.66),
	Size = UDim2.fromScale(0.34, 0.34),
	BackgroundColor3 = PLATE,
	BackgroundTransparency = 0.6,
	BorderSizePixel = 0,
}, left)
round(stick)
make("ImageLabel", { -- the sprint lock: push the stick up past the ring
	Name = "SprintLock",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromScale(0.5, -0.06),
	Size = UDim2.fromScale(0.26, 0.26),
	Rotation = -90,
	BackgroundTransparency = 1,
	Image = ICON.sprint,
	ImageColor3 = TEXT,
	ImageTransparency = 0.35,
}, stick)
local nub = make("Frame", {
	Name = "Nub",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.62, 0.36),
	Size = UDim2.fromScale(0.42, 0.42),
	BackgroundColor3 = TEXT,
	BackgroundTransparency = 0.12,
	BorderSizePixel = 0,
}, stick)
round(nub)
button(left, "Sprint", 0.22, 0.34, 0.16, { icon = ICON.run, on = true, iconScale = 0.62 })

-- Health, bottom-left on a fade-free bar (the stick zone can pass over it).
local health = make("Frame", {
	Name = "Health",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0.012, 0.975),
	Size = UDim2.fromScale(0.6, 0.06),
	SizeConstraint = Enum.SizeConstraint.RelativeYY,
	BackgroundColor3 = PLATE,
	BackgroundTransparency = 0.35,
	BorderSizePixel = 0,
}, root)
make("UICorner", { CornerRadius = UDim.new(0.25, 0) }, health)
local fill = make("Frame", {
	Name = "Fill",
	Position = UDim2.fromScale(0.03, 0.2),
	Size = UDim2.fromScale(0.72 * 0.85, 0.6),
	BackgroundColor3 = TEXT,
	BorderSizePixel = 0,
}, health)
make("UICorner", { CornerRadius = UDim.new(0.25, 0) }, fill)
text(health, "Value", "85", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.fromScale(0.95, 0.5),
	Size = UDim2.fromScale(0.3, 0.7),
	TextXAlignment = Enum.TextXAlignment.Right,
	ZIndex = 2,
})

-- Top-right: weapon slots with the gun art spilling out, ammo on the slot; quick melee under the knife.
local weapons = cluster(root, "Weapons", Vector2.new(1, 0), 0.5)
for i, w in
	{
		{ "Vandal", 0.2, "25", true },
		{ "Sheriff", 0.47, "6", false },
		{ "Knife", 0.74, nil, false },
	}
do
	local slot = button(weapons, "Slot" .. i, w[2] :: number, 0.17, 0.23, {})
	if w[4] then
		slot.BackgroundColor3 = TEXT
		slot.BackgroundTransparency = 0.72
	end
	make("ImageLabel", {
		Name = "Gun",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.44),
		Size = UDim2.fromScale(1.15, 1.15),
		Rotation = -35, -- long guns sit inside the circle on the diagonal
		BackgroundTransparency = 1,
		Image = GUN[w[1] :: string],
		ScaleType = Enum.ScaleType.Fit,
	}, slot)
	if w[3] then
		text(slot, "Ammo", w[3] :: string, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1.02),
			Size = UDim2.fromScale(0.7, 0.38),
			ZIndex = 2,
		})
	end
end
button(weapons, "QuickMelee", 0.74, 0.42, 0.22, { icon = ICON.melee, iconScale = 0.55 }) -- 44 px at 390

-- Top-left: Roblox's own buttons (placeholder, drawn faint) and ours beside them in the top-bar row.
local topLeft = cluster(root, "TopLeft", Vector2.new(0, 0), 0.6)
local roblox = make(
	"Frame",
	{ Name = "RobloxPlaceholder", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) },
	topLeft
)
local logo = make("Frame", {
	Name = "Logo",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.1, 0.11),
	Size = UDim2.fromScale(0.16, 0.16),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.6,
	BorderSizePixel = 0,
}, roblox)
round(logo)
local menu = make("Frame", {
	Name = "Menu",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.fromScale(0.2, 0.11),
	Size = UDim2.fromScale(0.3, 0.16),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.6,
	BorderSizePixel = 0,
}, roblox)
round(menu)
button(topLeft, "Settings", 0.61, 0.11, 0.16, { icon = ICON.settings, iconScale = 0.6 })
button(topLeft, "Scoreboard", 0.8, 0.11, 0.16, { icon = ICON.scoreboard, iconScale = 0.52 })

-- Top-centre: compact scorebug in the top-bar row (placeholder for the phone TopBar).
local score = cluster(root, "Scorebug", Vector2.new(0.5, 0), 0.62)
local function plate(
	name: string,
	x: number,
	w: number,
	color: Color3,
	value: string,
	transparency: number
)
	local p = make("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(x, 0.025),
		Size = UDim2.fromScale(w, 0.15),
		BackgroundColor3 = PLATE,
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
	}, score)
	make("UICorner", { CornerRadius = UDim.new(0.18, 0) }, p)
	text(p, "Value", value, {
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.72),
		TextColor3 = color, -- dark plate, coloured number (white on cyan didn't read)
	})
end
plate("Ally", 0.2, 0.26, ALLY, "2", 0.2)
plate("Timer", 0.5, 0.3, TEXT, "1:22", 0.2)
plate("Enemy", 0.8, 0.26, ENEMY, "1", 0.2)

-- Centre: crosshair (context only).
local cross = make("Frame", {
	Name = "Crosshair",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.05, 0.05),
	SizeConstraint = Enum.SizeConstraint.RelativeYY,
	BackgroundTransparency = 1,
}, root)
for _, r in
	{
		{ 0.5, 0.12, 0.08, 0.28 },
		{ 0.5, 0.88, 0.08, 0.28 },
		{ 0.12, 0.5, 0.28, 0.08 },
		{ 0.88, 0.5, 0.28, 0.08 },
	}
do
	make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(r[1], r[2]),
		Size = UDim2.fromScale(r[3], r[4]),
		BackgroundColor3 = TEXT,
		BorderSizePixel = 0,
	}, cross)
end

gui.Parent = StarterGui
StarterGui.ShowDevelopmentGui = true
print(
	"[BuildTouchMockup] StarterGui.TouchMockup built"
		.. (if PREVIEW then ` (preview {PREVIEW.X}x{PREVIEW.Y})` else "")
)
return "ok"
