--!strict
-- Settings v2 (vault/02 Art/UI Settings.md), LOBBY place, Edit mode. Extends
-- the Studio-built StarterGui.Settings (tools/studio/BuildSettings.luau, then
-- MigratePlates' PlateArt) instead of rebuilding it, so owner edits and the
-- plate art stay:
--   * Tabs: VIDEO / AUDIO / GAMEPLAY / CROSSHAIR / KEYBINDS (clones of the
--     first tab plate),
--   * Inspect.Note: "saved to your profile",
--   * Canvas.ColorPicker (RGB boxes, hex plate, hue / saturation wheel,
--     brightness bar), Canvas.Confirm (Force Controls: KEEP within 10 s),
--     Canvas.Dropdown (the open dropdown list),
--   * templates in ReplicatedStorage.UiTemplates.Lobby: SettingSection,
--     SettingDropdown, DropOption, SettingColor, SettingKeys, SettingKeyHeader,
--     SettingReset; SettingRow gets a Note line; SettingSlider's value becomes
--     a typed box.
-- Re-running replaces only what it made.

local SG = game:GetService("StarterGui")
local RS = game:GetService("ReplicatedStorage")

local WHEEL = "rbxassetid://78198355622759" -- image of Decal 107999486088868 (tools/ui/make_color_wheel.py)

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

local FONT = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy) -- Rubik
local BODY = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold)
local WHITE = Color3.new(1, 1, 1)
local NAVY = hex("141417")
local NAVY_HI = hex("252528")
local INK = hex("0F0F12")
local MUTED = hex("9F9FA2")
local RED = hex("FF4D5E")
local CENTRE = Vector2.new(0.5, 0.5)

local function corner(p: Instance, r: number?)
	make("UICorner", { CornerRadius = UDim.new(0, r or 8) }, p)
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
local function box(p: Instance, name: string, props: { [string]: any }): TextBox
	local b = make("TextBox", {
		Name = name,
		BackgroundColor3 = NAVY_HI,
		BorderSizePixel = 0,
		Text = "",
		PlaceholderText = "",
		FontFace = FONT,
		TextSize = 24,
		TextColor3 = WHITE,
		ClearTextOnFocus = false,
		ZIndex = 6,
	}, p)
	for k, v in props do
		(b :: any)[k] = v
	end
	corner(b, 6)
	return b
end
-- a down chevron drawn from two bars (no font glyphs)
local function chevron(p: Instance, color: Color3, z: number): Frame
	local g = make("Frame", {
		Name = "Arrow",
		AnchorPoint = CENTRE,
		Size = UDim2.fromOffset(18, 12),
		BackgroundTransparency = 1,
		ZIndex = z,
	}, p)
	for i, r in { 40, -40 } do
		make("Frame", {
			Name = if i == 1 then "A" else "B",
			AnchorPoint = CENTRE,
			Position = UDim2.new(0.5, if i == 1 then -4 else 4, 0.5, 0),
			Size = UDim2.fromOffset(12, 4),
			Rotation = r,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = z,
		}, g)
	end
	return g
end
local function drawX(p: Instance, size: number, thick: number, color: Color3)
	local glyph = make("Frame", {
		Name = "Glyph",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex = 12,
	}, p)
	for _, r in { 45, -45 } do
		local bar = make("Frame", {
			AnchorPoint = CENTRE,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(size, thick),
			Rotation = r,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = 12,
		}, glyph)
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, bar)
	end
end

-- a child that must exist (run tools/studio/BuildSettings.luau first)
local function need(parent: Instance, name: string): any
	local c = parent:FindFirstChild(name)
	assert(c, `{parent:GetFullName()}.{name} missing: run tools/studio/BuildSettings.luau first`)
	return c
end

local gui = need(SG, "Settings") :: ScreenGui
local canvas = need(gui, "Canvas") :: Frame
local lobby = need(need(RS, "UiTemplates"), "Lobby") :: Folder
local switchPlate = need(need(lobby, "SettingToggle"), "Switch") :: TextButton
need(switchPlate, "PlateArt")

-- a slanted plate (the toggle's, with its PlateArt), resized
local function plate(
	parent: Instance,
	name: string,
	w: number,
	h: number,
	color: Color3
): TextButton
	local p = switchPlate:Clone()
	p.Name = name
	for _, c in p:GetChildren() do
		if c.Name == "State" or c.Name == "Knob" then
			c:Destroy()
		end
	end
	p.AnchorPoint = Vector2.new(0, 0)
	p.Position = UDim2.new()
	p.Size = UDim2.fromOffset(w, h)
	p.BackgroundColor3 = color
	p.Parent = parent
	return p
end

------------------------------------------------------------------------------
-- Tabs

local tabs = need(canvas, "Tabs") :: Frame
local first: TextButton? = nil
for _, c in tabs:GetChildren() do
	if c:IsA("TextButton") and (first == nil or c.LayoutOrder < first.LayoutOrder) then
		first = c
	end
end
assert(first, "no tab plate to copy")
local tabPattern = (first :: TextButton):Clone()
for _, c in tabs:GetChildren() do
	if c:IsA("TextButton") then
		c:Destroy()
	end
end
local TAB_W, GAP = 210, 24
tabs.Size = UDim2.fromOffset(TAB_W * 5 + GAP * 4, 56)
local layout = tabs:FindFirstChildWhichIsA("UIListLayout")
if layout then
	layout.Padding = UDim.new(0, GAP)
end
for i, name in { "VIDEO", "AUDIO", "GAMEPLAY", "CROSSHAIR", "KEYBINDS" } do
	local t = tabPattern:Clone()
	t.Name = name
	t.LayoutOrder = i
	t.Size = UDim2.fromOffset(TAB_W, 56)
	t.BackgroundColor3 = if i == 1 then WHITE else NAVY
	local label = t:FindFirstChildWhichIsA("TextLabel", true)
	if label then
		label.Text = name
		label.TextSize = 24
		label.TextColor3 = if i == 1 then INK else MUTED
	end
	t.Parent = tabs
end

local inspect = need(canvas, "Inspect") :: Frame
local note = inspect:FindFirstChild("Note") :: TextLabel?
if note then
	note.Text = "SAVED TO YOUR PROFILE. MOST OF THESE START WORKING IN A LATER UPDATE."
end

------------------------------------------------------------------------------
-- Popups on the canvas

for _, n in { "ColorPicker", "Confirm", "Dropdown" } do
	local o = canvas:FindFirstChild(n)
	if o then
		o:Destroy()
	end
end

-- Colour picker (owner's RIVALS reference): boxes left, wheel middle, bar right
local picker = make("TextButton", {
	Name = "ColorPicker",
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.fromOffset(1110, 300),
	Size = UDim2.fromOffset(660, 420),
	BackgroundColor3 = hex("08080A"),
	BackgroundTransparency = 0,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	Visible = false,
	ZIndex = 10,
}, canvas)
corner(picker, 10)
make("UIScale", { Name = "Pop" }, picker)
text(picker, "Head", "COLOR", 26, WHITE, {
	Position = UDim2.fromOffset(28, 18),
	Size = UDim2.fromOffset(400, 34),
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 11,
})
local pClose = make("TextButton", {
	Name = "Close",
	AnchorPoint = CENTRE,
	Position = UDim2.new(1, -36, 0, 36),
	Size = UDim2.fromOffset(44, 44),
	BackgroundColor3 = NAVY_HI,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 11,
}, picker)
make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, pClose)
make("UIScale", { Name = "Pop" }, pClose)
drawX(pClose, 18, 4, WHITE)

local channels = { { "R", hex("FF3B3B") }, { "G", hex("3BE85A") }, { "B", hex("3B6BFF") } }
for i, ch in channels do
	local cell = make("Frame", {
		Name = ch[1],
		Position = UDim2.fromOffset(28, 74 + (i - 1) * 70),
		Size = UDim2.fromOffset(150, 58),
		BackgroundColor3 = NAVY_HI,
		BorderSizePixel = 0,
		ZIndex = 11,
	}, picker)
	corner(cell, 6)
	make("Frame", {
		Name = "Tag",
		Position = UDim2.fromOffset(8, 10),
		Size = UDim2.fromOffset(5, 38),
		BackgroundColor3 = ch[2],
		BorderSizePixel = 0,
		ZIndex = 12,
	}, cell)
	box(cell, "Box", {
		Position = UDim2.fromOffset(20, 0),
		Size = UDim2.new(1, -24, 1, 0),
		BackgroundTransparency = 1,
		TextSize = 30,
		TextColor3 = ch[2],
		Text = "255",
		ZIndex = 12,
	})
end
local hexCell = make("Frame", {
	Name = "Hex",
	Position = UDim2.fromOffset(28, 284),
	Size = UDim2.fromOffset(150, 58),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	ZIndex = 11,
}, picker)
corner(hexCell, 6)
box(hexCell, "Box", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	TextSize = 24,
	TextColor3 = WHITE,
	Text = "#FFFFFF",
	ZIndex = 12,
})
local wheel = make("ImageButton", {
	Name = "Wheel",
	Position = UDim2.fromOffset(206, 70),
	Size = UDim2.fromOffset(300, 300),
	BackgroundTransparency = 1,
	Image = WHEEL,
	AutoButtonColor = false,
	ZIndex = 11,
}, picker)
-- the dimmer over the wheel (brightness below 100 % darkens the whole wheel)
local shade = make("Frame", {
	Name = "Shade",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 12,
}, wheel)
make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, shade)
local cursor = make("Frame", {
	Name = "Cursor",
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(26, 26),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	ZIndex = 13,
}, wheel)
make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, cursor)
local ring = make("Frame", {
	Name = "Inner",
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(14, 14),
	BackgroundColor3 = INK,
	BorderSizePixel = 0,
	ZIndex = 14,
}, cursor)
make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, ring)
local bar = make("TextButton", {
	Name = "Bar",
	Position = UDim2.fromOffset(548, 74),
	Size = UDim2.fromOffset(60, 296),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 11,
}, picker)
corner(bar, 6)
make("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new(WHITE, Color3.new(0, 0, 0)),
}, bar)
local barKnob = make("Frame", {
	Name = "Knob",
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0),
	Size = UDim2.fromOffset(72, 20),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	ZIndex = 13,
}, bar)
corner(barKnob, 10)
make("Frame", {
	Name = "Line",
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(1, -16, 0, 4),
	BackgroundColor3 = INK,
	BorderSizePixel = 0,
	ZIndex = 14,
}, barKnob)
text(picker, "Hint", "DRAG ON THE WHEEL, OR TYPE A VALUE", 16, MUTED, {
	Position = UDim2.fromOffset(28, 378),
	Size = UDim2.fromOffset(600, 24),
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 11,
})

-- Force Controls: keep or go back
local confirm = make("Frame", {
	Name = "Confirm",
	AnchorPoint = CENTRE,
	Position = UDim2.fromOffset(960, 540),
	Size = UDim2.fromOffset(720, 300),
	BackgroundColor3 = hex("08080A"),
	BackgroundTransparency = 0.02,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 20,
}, canvas)
corner(confirm, 10)
make("UIScale", { Name = "Pop" }, confirm)
text(confirm, "Head", "KEEP THESE CONTROLS?", 40, WHITE, {
	Position = UDim2.fromOffset(40, 34),
	Size = UDim2.fromOffset(640, 50),
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 21,
})
text(confirm, "Body", "GOING BACK IN 10", 24, RED, {
	Position = UDim2.fromOffset(40, 96),
	Size = UDim2.fromOffset(640, 70),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextWrapped = true,
	FontFace = BODY,
	ZIndex = 21,
})
local keep = plate(confirm, "Keep", 250, 64, WHITE)
keep.Position = UDim2.fromOffset(40, 196)
keep.ZIndex = 21
text(keep, "Label", "KEEP", 28, INK, { Size = UDim2.fromScale(1, 1), ZIndex = 23 })
local back = plate(confirm, "Revert", 250, 64, NAVY_HI)
back.Position = UDim2.fromOffset(330, 196)
back.ZIndex = 21
text(back, "Label", "GO BACK", 28, WHITE, { Size = UDim2.fromScale(1, 1), ZIndex = 23 })

-- the open dropdown's list (filled with DropOption at run time)
local drop = make("Frame", {
	Name = "Dropdown",
	Size = UDim2.fromOffset(260, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = NAVY,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 30,
}, canvas)
corner(drop, 8)
make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, drop)
make("UIPadding", {
	PaddingTop = UDim.new(0, 6),
	PaddingBottom = UDim.new(0, 6),
	PaddingLeft = UDim.new(0, 6),
	PaddingRight = UDim.new(0, 6),
}, drop)

------------------------------------------------------------------------------
-- Templates

for _, n in
	{
		"SettingSection",
		"SettingDropdown",
		"DropOption",
		"SettingColor",
		"SettingKeys",
		"SettingKeyHeader",
		"SettingReset",
	}
do
	local o = lobby:FindFirstChild(n)
	if o then
		o:Destroy()
	end
end

-- a section header between rows
local section = make("Frame", {
	Name = "SettingSection",
	Size = UDim2.fromOffset(860, 70),
	BackgroundTransparency = 1,
	ZIndex = 3,
}, lobby)
text(section, "Title", "SECTION", 30, WHITE, {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 8, 1, -6),
	Size = UDim2.fromOffset(700, 40),
	TextXAlignment = Enum.TextXAlignment.Left,
})

-- the row's small second line (device note / warning)
local row = need(lobby, "SettingRow") :: TextButton
local oldNote = row:FindFirstChild("Note")
if oldNote then
	oldNote:Destroy()
end
text(row, "Note", "", 16, MUTED, {
	Position = UDim2.fromOffset(30, 54),
	Size = UDim2.fromOffset(440, 22),
	TextXAlignment = Enum.TextXAlignment.Left,
	FontFace = BODY,
	Visible = false,
})

-- the slider's value: a box you can type in
local slider = need(lobby, "SettingSlider") :: Frame
local oldValue = slider:FindFirstChild("Value")
if oldValue then
	oldValue:Destroy()
end
box(slider, "Value", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, 0, 0.5, 0),
	Size = UDim2.fromOffset(96, 44),
	Text = "50%",
})
local track = need(slider, "Track") :: GuiObject
track.Size = UDim2.fromOffset(240, 12)

-- dropdown: a white plate with the value and a chevron
local dd = make("Frame", {
	Name = "SettingDropdown",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ZIndex = 4,
}, lobby)
local ddPlate = plate(dd, "Plate", 250, 48, WHITE)
ddPlate.AnchorPoint = Vector2.new(1, 0.5)
ddPlate.Position = UDim2.new(1, -16, 0.5, 0)
text(ddPlate, "Label", "DISABLED", 22, INK, {
	Position = UDim2.fromOffset(22, 0),
	Size = UDim2.new(1, -70, 1, 0),
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 7,
})
local arrow = chevron(ddPlate, INK, 7)
arrow.Position = UDim2.new(1, -34, 0.5, 0)
for _, c in arrow:GetChildren() do
	(c :: Frame).BackgroundColor3 = INK
end

local opt = make("TextButton", {
	Name = "DropOption",
	Size = UDim2.new(1, 0, 0, 46),
	BackgroundColor3 = NAVY,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 31,
}, lobby)
corner(opt, 6)
text(opt, "Label", "OPTION", 22, WHITE, {
	Position = UDim2.fromOffset(16, 0),
	Size = UDim2.new(1, -24, 1, 0),
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 32,
})

-- colour: the swatch and its hex on one plate
local col = make("Frame", {
	Name = "SettingColor",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ZIndex = 4,
}, lobby)
local colPlate = plate(col, "Plate", 200, 48, NAVY_HI)
colPlate.AnchorPoint = Vector2.new(1, 0.5)
colPlate.Position = UDim2.new(1, -16, 0.5, 0)
local swatch = make("Frame", {
	Name = "Swatch",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 14, 0.5, 0),
	Size = UDim2.fromOffset(34, 34),
	BackgroundColor3 = hex("FF3232"),
	BorderSizePixel = 0,
	ZIndex = 7,
}, colPlate)
corner(swatch, 5)
text(colPlate, "Hex", "#FF3232", 22, WHITE, {
	Position = UDim2.fromOffset(58, 0),
	Size = UDim2.new(1, -66, 1, 0),
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 7,
})

-- keybinds: three key boxes per row (keyboard, alt, controller)
local KEY_W, KEY_GAP = 170, 16
local keys = make("Frame", {
	Name = "SettingKeys",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -28, 0.5, 0),
	Size = UDim2.fromOffset(KEY_W * 3 + KEY_GAP * 2, 56),
	BackgroundTransparency = 1,
	ZIndex = 4,
}, lobby)
for i = 1, 3 do
	local k = make("TextButton", {
		Name = "Key" .. i,
		Position = UDim2.fromOffset((i - 1) * (KEY_W + KEY_GAP), 4),
		Size = UDim2.fromOffset(KEY_W, 48),
		BackgroundColor3 = NAVY_HI,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 5,
	}, keys)
	corner(k, 6)
	make("UIScale", { Name = "Pop" }, k)
	text(k, "Label", "", 22, WHITE, { Size = UDim2.fromScale(1, 1), ZIndex = 6 })
end

local header = make("Frame", {
	Name = "SettingKeyHeader",
	Size = UDim2.fromOffset(1580, 60),
	BackgroundColor3 = hex("08080A"),
	BackgroundTransparency = 0.25,
	BorderSizePixel = 0,
	ZIndex = 3,
}, lobby)
corner(header, 8)
text(header, "Action", "ACTION", 28, WHITE, {
	Position = UDim2.fromOffset(30, 0),
	Size = UDim2.fromOffset(400, 60),
	TextXAlignment = Enum.TextXAlignment.Left,
})
local cols = make("Frame", {
	Name = "Columns",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -28, 0.5, 0),
	Size = UDim2.fromOffset(KEY_W * 3 + KEY_GAP * 2, 60),
	BackgroundTransparency = 1,
	ZIndex = 4,
}, header)
for i, name in { "KEYBOARD", "ALT", "CONTROLLER" } do
	text(cols, "Col" .. i, name, 22, MUTED, {
		Position = UDim2.fromOffset((i - 1) * (KEY_W + KEY_GAP), 0),
		Size = UDim2.fromOffset(KEY_W, 60),
	})
end

-- the reset plate at the end of every tab
local resetRow = make("Frame", {
	Name = "SettingReset",
	Size = UDim2.fromOffset(860, 110),
	BackgroundTransparency = 1,
	ZIndex = 3,
}, lobby)
local reset = plate(resetRow, "Button", 300, 60, NAVY_HI)
reset.AnchorPoint = Vector2.new(0, 0.5)
reset.Position = UDim2.new(0, 16, 0.5, 0)
text(reset, "Label", "RESET TAB", 26, WHITE, { Size = UDim2.fromScale(1, 1), ZIndex = 7 })

print("[BuildSettingsV2] tabs, popups and Setting* templates built")
