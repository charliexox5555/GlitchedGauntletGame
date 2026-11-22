--!strict
-- Builds ReplicatedFirst.DuelsLoading, the loading screen v2 (vault/05 Production/Handoff - Stability, Loading and
-- Preload.md → Phase 2). Run in Studio (Edit) through the command bar or MCP; it replaces an older copy. The screen
-- is Studio data from then on: the owner edits it in Studio, src/first/LoadingScreen.client.luau drives it.
-- Layout: a 1920 × 1080 design canvas scaled by the script (UIScale "Fit"); dark backdrop, the Draft Duels logo
-- sprites (two-beat reveal), one gold progress fill, a stage word, a ring spinner, a tip line, a mode line.
-- Look: gauntlet-ui-style (plates 10141B / fades 06080C, one gold thing, Rubik, circles with rings).

local ReplicatedFirst = game:GetService("ReplicatedFirst")

-- Image ids (Open Cloud "Decal" uploads give a decal id; an ImageLabel needs the image inside it).
local IMG = {
	ticket = "rbxassetid://132974051905154", -- image of decal 109503101136989: art-source/ui/draft-duels/draft-ticket-lobby-gold/ui/draft-ticket.png
	duels = "rbxassetid://76082588029379", -- image of decal 88104206748404: ui/duels.png
	full = "rbxassetid://92494712417530", -- image of decal 101115191066295: ui/full.png (reduced motion)
}
local RUBIK = "rbxassetid://12187365977"
local INK = Color3.fromHex("F4F6F9")
local MUTED = Color3.fromHex("A9B2BF")
local GOLD = Color3.fromHex("FFC83D")

local old = ReplicatedFirst:FindFirstChild("DuelsLoading")
if old then
	old:Destroy()
end

local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(class)
	for k, v in props do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function px(x: number, y: number): UDim2
	return UDim2.fromOffset(x, y)
end

local gui = make("ScreenGui", {
	Name = "DuelsLoading",
	Enabled = false,
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	DisplayOrder = 1000,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	ScreenInsets = Enum.ScreenInsets.None,
})

-- Backdrop: deep navy to black, top to bottom.
local backdrop = make("Frame", {
	Name = "Backdrop",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
	ZIndex = 1,
}, gui)
make("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("161C29")),
		ColorSequenceKeypoint.new(0.55, Color3.fromHex("0B0E15")),
		ColorSequenceKeypoint.new(1, Color3.fromHex("040508")),
	}),
}, backdrop)

-- The design canvas, centred and scaled by the script.
local canvas = make("Frame", {
	Name = "Canvas",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = px(1920, 1080),
	BackgroundTransparency = 1,
	ZIndex = 2,
}, gui)
make("UIScale", { Name = "Fit" }, canvas)

-- The brand slash behind the logo: one soft diagonal band.
local slash = make("Frame", {
	Name = "Slash",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = px(960, 430),
	Size = px(2800, 220),
	Rotation = -8,
	BackgroundColor3 = Color3.fromHex("1A2130"),
	BorderSizePixel = 0,
	ZIndex = 2,
}, canvas)
make("UIGradient", {
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.35),
		NumberSequenceKeypoint.new(0.7, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	}),
}, slash)

-- The logo: one 1000 / 410 container, every sprite full size on the shared origin.
local logo = make("Frame", {
	Name = "Logo",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = px(960, 430),
	Size = px(860, 353),
	BackgroundTransparency = 1,
	ZIndex = 3,
}, canvas)
for _, spec in { { "Ticket", IMG.ticket, 4 }, { "Duels", IMG.duels, 5 }, { "Full", IMG.full, 6 } } do
	local image = make("ImageLabel", {
		Name = spec[1],
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = spec[2],
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = spec[3],
		Visible = spec[1] ~= "Full",
	}, logo)
	make("UIScale", { Name = "Pop" }, image)
end

local function text(name: string, props: { [string]: any }): TextLabel
	local label = make("TextLabel", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		FontFace = Font.new(RUBIK, Enum.FontWeight.Bold),
		TextColor3 = MUTED,
		TextSize = 26,
		ZIndex = 4,
	}, canvas)
	for k, v in props do
		(label :: any)[k] = v
	end
	return label
end

-- Teleports: the mode as a line over the logo (MatchFoundController fills it).
text("Mode", {
	Position = px(960, 170),
	Size = px(1400, 56),
	Text = "1V1  /  LOADING MATCH",
	TextColor3 = INK,
	TextSize = 44,
	FontFace = Font.new(RUBIK, Enum.FontWeight.Heavy),
	Visible = false,
})

-- Progress: a thin track, one gold fill, the stage word under it.
local track = make("Frame", {
	Name = "Progress",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = px(960, 700),
	Size = px(560, 6),
	BackgroundColor3 = Color3.fromHex("252D3C"),
	BorderSizePixel = 0,
	ZIndex = 4,
}, canvas)
make("UICorner", { CornerRadius = UDim.new(0, 3) }, track)
local fill = make("Frame", {
	Name = "Fill",
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = GOLD,
	BorderSizePixel = 0,
	ZIndex = 5,
}, track)
make("UICorner", { CornerRadius = UDim.new(0, 3) }, fill)

text("Stage", {
	Position = px(960, 746),
	Size = px(1200, 34),
	Text = "CONNECTING",
	TextColor3 = INK,
	TextSize = 26,
})
text("Count", {
	Position = px(960, 786),
	Size = px(600, 30),
	Text = "",
	TextSize = 26, -- 12 px on a phone (LoadingLayout)
})

-- A ring spinner at the track's left end (circle + ring, the turning part a stroke gradient).
local spinner = make("Frame", {
	Name = "Spinner",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = px(960 - 280 - 34, 700),
	Size = px(26, 26),
	BackgroundTransparency = 1,
	ZIndex = 4,
}, canvas)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, spinner)
local stroke = make("UIStroke", { Thickness = 3, Color = INK }, spinner)
make("UIGradient", {
	Name = "Turn",
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0.15),
		NumberSequenceKeypoint.new(0.52, 1),
		NumberSequenceKeypoint.new(1, 1),
	}),
}, stroke)

-- The tip line along the bottom.
text("Tip", {
	Position = px(960, 1012),
	Size = px(1500, 34),
	Text = "TIP  /  DRAFT A NEW MOD EVERY ROUND",
	TextSize = 26, -- 12 px on a phone (LoadingLayout)
})

gui.Parent = ReplicatedFirst
return "built " .. gui:GetFullName()
