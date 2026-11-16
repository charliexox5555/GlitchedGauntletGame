--!strict
-- Builds the lobby's Settings screen in the LOBBY place, Edit mode
-- (vault/02 Art/UI Lobby Overhaul.md → Missing screens): StarterGui.Settings
-- (off; Controllers/SettingsController opens it) and its row templates in
-- ReplicatedStorage.UiTemplates.Lobby (SettingRow, SettingToggle,
-- SettingSlider, SettingSwatches). Re-running replaces them.
--
-- Layout from RIVALS' Settings page (studied, not copied): tabs on top, the
-- settings list on the left, an INSPECT panel on the right that explains the
-- picked setting (and, on the crosshair tab, shows it live). Our look: the
-- violet wash over the blurred lobby, slanted tab plates, chunky cells
-- (Util/Plates, Util/Cards at runtime), Fredoka One, the drawn-X close.

local SG = game:GetService("StarterGui")
local RS = game:GetService("ReplicatedStorage")

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
local function hex(h: string): Color3
	return Color3.fromHex(h)
end

local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local WHITE = Color3.new(1, 1, 1)
local NAVY = hex("0B1236")
local MUTED = hex("8FA0C8")
local CYAN = hex("3FE0F2")
local CENTRE = Vector2.new(0.5, 0.5)
local CAP_R = "rbxassetid://130377997107460" -- slant cap (rotated 180 for the left end)

local function corner(p: Instance, r: number?)
	make("UICorner", { CornerRadius = UDim.new(0, r or 8) }, p)
end
local function round(p: Instance)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, p)
end
local function text(
	p: Instance,
	name: string,
	t: string,
	size: number,
	color: Color3,
	props: { [string]: any }?
): TextLabel
	local l = make("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Text = t,
		FontFace = FONT,
		TextSize = size,
		TextColor3 = color,
		ZIndex = 5,
	}, p)
	for k, v in props or {} do
		(l :: any)[k] = v
	end
	return l
end
-- slanted ends (Util/Plates turns body + caps into one sliced plate)
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
local function drawX(p: Instance, size: number, thick: number, color: Color3)
	local glyph = make("Frame", {
		Name = "Glyph",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex = 5,
	}, p)
	for _, r in { 45, -45 } do
		local bar = make("Frame", {
			Name = if r > 0 then "A" else "B",
			AnchorPoint = CENTRE,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(size, thick),
			Rotation = r,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = 5,
		}, glyph)
		round(bar)
	end
end

------------------------------------------------------------------------------
-- The screen

local old = SG:FindFirstChild("Settings")
if old then
	old:Destroy()
end
local gui = make("ScreenGui", {
	Name = "Settings",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ScreenInsets = Enum.ScreenInsets.None,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 30,
	Enabled = false,
})
local wash = make("Frame", {
	Name = "Wash",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.3,
	BorderSizePixel = 0,
	Active = true,
	ZIndex = 0,
}, gui)
make("UIGradient", {
	Rotation = 35,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, hex("3B1D63")),
		ColorSequenceKeypoint.new(0.55, hex("161A44")),
		ColorSequenceKeypoint.new(1, hex("0A1230")),
	}),
}, wash)

local canvas = make("Frame", {
	Name = "Canvas",
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(1920, 1080),
	BackgroundTransparency = 1,
	ZIndex = 1,
}, gui)
make("UIScale", { Name = "Fit" }, canvas)

text(canvas, "Title", "SETTINGS", 64, WHITE, {
	Position = UDim2.fromOffset(160, 40),
	Size = UDim2.fromOffset(0, 70),
	AutomaticSize = Enum.AutomaticSize.X,
	TextXAlignment = Enum.TextXAlignment.Left,
})
local close = make("TextButton", {
	Name = "Close",
	AnchorPoint = CENTRE,
	Position = UDim2.fromOffset(1830, 76),
	Size = UDim2.fromOffset(72, 72),
	BackgroundColor3 = NAVY,
	BackgroundTransparency = 0.1,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 3,
}, canvas)
round(close)
make("UIScale", { Name = "Pop" }, close)
drawX(close, 30, 5, WHITE)

-- tabs: slanted plates, the picked one white (LobbyKit.tabs)
local tabs = make("Frame", {
	Name = "Tabs",
	Position = UDim2.fromOffset(170, 140),
	Size = UDim2.fromOffset(700, 56),
	BackgroundTransparency = 1,
	ZIndex = 2,
}, canvas)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 30),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, tabs)
for i, name in { "GENERAL", "CROSSHAIR" } do
	local tab = make("TextButton", {
		Name = name,
		LayoutOrder = i,
		Size = UDim2.fromOffset(230, 56),
		BackgroundColor3 = if i == 1 then WHITE else NAVY,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 3,
	}, tabs)
	slant(tab, tab.BackgroundColor3, 56, 18)
	text(tab, "Label", name, 26, if i == 1 then hex("0B0E1F") else MUTED, {
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
	})
end

-- the list (rows are SettingRow slots)
local list = make("ScrollingFrame", {
	Name = "List",
	Position = UDim2.fromOffset(140, 222),
	Size = UDim2.fromOffset(940, 740),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 0, -- no visible bar (owner, 2026-11-16)
	ScrollBarImageTransparency = 1, -- Thickness 0 still drew a hairline
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ZIndex = 2,
}, canvas)
make("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder }, list)
-- room for a row's hover pop (1.04) inside the clip
make("UIPadding", {
	PaddingLeft = UDim.new(0, 30),
	PaddingRight = UDim.new(0, 30),
	PaddingTop = UDim.new(0, 8),
	PaddingBottom = UDim.new(0, 20),
}, list)

-- INSPECT: what the picked setting does; the crosshair, live
local inspect = make("Frame", {
	Name = "Inspect",
	Position = UDim2.fromOffset(1110, 230),
	Size = UDim2.fromOffset(660, 720),
	BackgroundColor3 = NAVY,
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
	ZIndex = 2,
}, canvas)
corner(inspect)
text(inspect, "Kicker", "INSPECT", 18, CYAN, {
	Position = UDim2.fromOffset(36, 30),
	Size = UDim2.fromOffset(300, 22),
	TextXAlignment = Enum.TextXAlignment.Left,
})
text(inspect, "Head", "REDUCED MOTION", 40, WHITE, {
	Position = UDim2.fromOffset(36, 60),
	Size = UDim2.fromOffset(590, 48),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
})
text(inspect, "Desc", "", 22, MUTED, {
	Position = UDim2.fromOffset(36, 120),
	Size = UDim2.fromOffset(590, 120),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextWrapped = true,
})
local preview = make("Frame", {
	Name = "Preview",
	Position = UDim2.fromOffset(36, 256),
	Size = UDim2.fromOffset(588, 340),
	BackgroundColor3 = WHITE, -- the gradient below carries the colours
	BorderSizePixel = 0,
	ClipsDescendants = true,
	ZIndex = 3,
}, inspect)
corner(preview)
-- a soft lit backdrop so a white or dark crosshair both read
make("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, hex("5A6FA8")),
		ColorSequenceKeypoint.new(0.55, hex("2A386A")),
		ColorSequenceKeypoint.new(1, hex("141C3C")),
	}),
}, preview)
make("Frame", {
	Name = "Crosshair",
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(0, 0),
	BackgroundTransparency = 1,
	ZIndex = 5,
}, preview)
text(
	inspect,
	"Note",
	"YOUR CHOICES LAST THIS SESSION. SAVING THEM TO YOUR PROFILE COMES WITH THE PROFILE SYSTEM.",
	16,
	MUTED,
	{
		Position = UDim2.fromOffset(36, 620),
		Size = UDim2.fromOffset(590, 70),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		TextTransparency = 0.15,
	}
)

gui.Parent = SG

------------------------------------------------------------------------------
-- Templates (RIVALS' Slot pattern: one template, the controller clones it)

local folder = RS:FindFirstChild("UiTemplates") or make("Folder", { Name = "UiTemplates" }, RS)
local lobby = folder:FindFirstChild("Lobby") or make("Folder", { Name = "Lobby" }, folder)
for _, n in { "SettingRow", "SettingToggle", "SettingSlider", "SettingSwatches" } do
	local o = lobby:FindFirstChild(n)
	if o then
		o:Destroy()
	end
end

-- a row: the name on the left, a control on the right (filled by code)
local row = make("TextButton", {
	Name = "SettingRow",
	Size = UDim2.fromOffset(860, 90),
	BackgroundColor3 = NAVY,
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 3,
}, lobby)
corner(row)
make("UIScale", { Name = "Pop" }, row)
text(row, "Name", "SETTING", 26, WHITE, {
	Position = UDim2.fromOffset(30, 0),
	Size = UDim2.fromOffset(420, 90),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
})
make("Frame", {
	Name = "Control",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -28, 0.5, 0),
	Size = UDim2.fromOffset(380, 56),
	BackgroundTransparency = 1,
	ZIndex = 4,
}, row)

-- a toggle: one slanted plate reading ON (white) or OFF (dark)
local toggle = make("Frame", {
	Name = "SettingToggle",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ZIndex = 4,
}, lobby)
local switch = make("TextButton", {
	Name = "Switch",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -16, 0.5, 0),
	Size = UDim2.fromOffset(130, 48),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 5,
}, toggle)
slant(switch, WHITE, 48, 15)
make("UIScale", { Name = "Pop" }, switch)
text(switch, "State", "ON", 24, hex("0B0E1F"), { Size = UDim2.fromScale(1, 1), ZIndex = 7 })

-- a slider: a track, its fill, a round knob and the value
local slider = make("Frame", {
	Name = "SettingSlider",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ZIndex = 4,
}, lobby)
text(slider, "Value", "1.0", 24, WHITE, {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, 0, 0.5, 0),
	Size = UDim2.fromOffset(70, 40),
	TextXAlignment = Enum.TextXAlignment.Right,
})
local track = make("TextButton", {
	Name = "Track",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 10, 0.5, 0),
	Size = UDim2.fromOffset(270, 12),
	BackgroundColor3 = hex("060A22"),
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 5,
}, slider)
round(track)
local fill = make("Frame", {
	Name = "Fill",
	Size = UDim2.fromScale(0.5, 1),
	BackgroundColor3 = CYAN,
	BorderSizePixel = 0,
	ZIndex = 6,
}, track)
round(fill)
local knob = make("Frame", {
	Name = "Knob",
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(32, 32),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	ZIndex = 7,
}, track)
round(knob)
make("UIScale", { Name = "Pop" }, knob)

-- colour swatches: small squares, the picked one rests bigger
local swatches = make("Frame", {
	Name = "SettingSwatches",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ZIndex = 4,
}, lobby)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 14),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, swatches)
local sw = make("TextButton", {
	Name = "Swatch",
	Size = UDim2.fromOffset(44, 44),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 5,
	Visible = false, -- the pattern; code clones one per colour
}, swatches)
corner(sw, 6)
make("UIScale", { Name = "Pop" }, sw) -- the picked swatch rests bigger (no strips)

print("[BuildSettings] StarterGui.Settings + UiTemplates.Lobby.Setting* built")
