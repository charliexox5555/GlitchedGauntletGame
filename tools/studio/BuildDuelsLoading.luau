--!strict
-- Builds ReplicatedFirst.DuelsLoading, the loading screen v2 (vault/05 Production/Handoff - Stability, Loading and
-- Preload.md → Phase 2; v2.1 look 2026-11-22 after the owner's "better look and improved animation"). Run in Studio
-- (Edit) through the command bar or MCP; it replaces an older copy. The screen is Studio data from then on: the
-- owner edits it in Studio, src/first/LoadingScreen.client.luau drives it.
-- Layers, back to front:
--   Backdrop (navy to black) → Stripes (thin diagonal slashes the script drifts) → Shade (dark top / bottom edges)
--   → Canvas (1920 × 1080 design, scaled by src/first/LoadingLayout): the brand slash band, the title sprites (+ a
--   white mask the shine sweeps over), the mode line, four progress segments, the stage word, a count, a ring
--   spinner and the tip line.
-- Look: gauntlet-ui-style (plates 10141B / fades 06080C, one gold thing, Rubik, circles with rings, slash marks).

local ReplicatedFirst = game:GetService("ReplicatedFirst")

-- Image ids (Open Cloud "Decal" uploads give a decal id; an ImageLabel needs the image inside it).
local IMG = {
	ticket = "rbxassetid://132974051905154", -- decal 109503101136989: draft-ticket-lobby-gold/ui/draft-ticket.png
	duels = "rbxassetid://76082588029379", -- decal 88104206748404: ui/duels.png
	full = "rbxassetid://92494712417530", -- decal 101115191066295: ui/full.png (reduced motion)
	shine = "rbxassetid://121355472687347", -- decal 104304303307452: art-source/ui/loading/title-shine-mask.png
}
local RUBIK = "rbxassetid://12187365977"
local INK = Color3.fromHex("F4F6F9")
local MUTED = Color3.fromHex("A9B2BF")
local GOLD = Color3.fromHex("FFC83D")
local SEGMENTS = 4

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

local function seq(points: { { number } }): NumberSequence
	local keys = {}
	for _, p in points do
		table.insert(keys, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(keys)
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

-- Backdrop: deep navy to black, top to bottom. "Tone" also carries the close wipe (the script sets its
-- Transparency and Offset).
local backdrop = make("Frame", {
	Name = "Backdrop",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
	ZIndex = 1,
}, gui)
make("UIGradient", {
	Name = "Tone",
	Rotation = 90,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("18202F")),
		ColorSequenceKeypoint.new(0.5, Color3.fromHex("0C1018")),
		ColorSequenceKeypoint.new(1, Color3.fromHex("040508")),
	}),
}, backdrop)

-- Stripes: thin diagonal slashes over the whole screen; the script scrolls "Scroll" by one gap and wraps.
local stripes = make("Frame", {
	Name = "Stripes",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ClipsDescendants = true,
	ZIndex = 2,
}, gui)
local scroll = make("Frame", {
	Name = "Scroll",
	Size = UDim2.fromScale(1.25, 1),
	BackgroundTransparency = 1,
	ZIndex = 2,
}, stripes)
local BARS = 30
scroll:SetAttribute("Bars", BARS)
for i = 0, BARS - 1 do
	make("Frame", {
		Name = "Bar" .. i,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale((i + 0.5) / BARS, 0.5),
		Size = UDim2.new(0, 14, 1.9, 0),
		Rotation = 24,
		BackgroundColor3 = Color3.fromHex("2A3448"),
		BackgroundTransparency = if i % 3 == 0 then 0.55 else 0.8,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, scroll)
end

-- Shade: darker top and bottom edges, so the middle (the title) reads brightest.
local shade = make("Frame", {
	Name = "Shade",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromHex("020305"),
	BorderSizePixel = 0,
	ZIndex = 3,
}, gui)
make("UIGradient", {
	Rotation = 90,
	Transparency = seq({ { 0, 0.15 }, { 0.32, 0.92 }, { 0.62, 0.92 }, { 1, 0.05 } }),
}, shade)

-- The design canvas, centred and scaled by src/first/LoadingLayout.
local canvas = make("Frame", {
	Name = "Canvas",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = px(1920, 1080),
	BackgroundTransparency = 1,
	ZIndex = 4,
}, gui)
make("UIScale", { Name = "Fit" }, canvas)

-- The brand slash behind the title: one soft diagonal band that sweeps in first.
local slash = make("Frame", {
	Name = "Slash",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = px(960, 430),
	Size = px(2800, 230),
	Rotation = -8,
	BackgroundColor3 = Color3.fromHex("1C2434"),
	BorderSizePixel = 0,
	ZIndex = 4,
}, canvas)
make("UIGradient", {
	Name = "Wipe",
	Transparency = seq({ { 0, 1 }, { 0.3, 0.25 }, { 0.7, 0.25 }, { 1, 1 } }),
}, slash)
-- A thin gold edge along the band's top (the slash mark).
make("Frame", {
	Name = "Edge",
	Position = UDim2.fromScale(0, 0),
	Size = UDim2.new(1, 0, 0, 3),
	BackgroundColor3 = GOLD,
	BackgroundTransparency = 0.55,
	BorderSizePixel = 0,
	ZIndex = 4,
}, slash)

-- The title: one 1000 / 410 container, every sprite full size on the shared origin.
local logo = make("Frame", {
	Name = "Logo",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = px(960, 430),
	Size = px(900, 369),
	BackgroundTransparency = 1,
	ZIndex = 5,
}, canvas)
make("UIScale", { Name = "Pop" }, logo)
for _, spec in
	{
		{ "Ticket", IMG.ticket, 6 },
		{ "Duels", IMG.duels, 7 },
		{ "Full", IMG.full, 8 },
		{ "Shine", IMG.shine, 9 },
	}
do
	local image = make("ImageLabel", {
		Name = spec[1],
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = spec[2],
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = spec[3],
		Visible = spec[1] == "Ticket" or spec[1] == "Duels",
	}, logo)
	make("UIScale", { Name = "Pop" }, image)
	if spec[1] == "Shine" then
		-- A narrow bright band the script sweeps across (Offset.X -1 → 1).
		make("UIGradient", {
			Name = "Band",
			Rotation = 20,
			Offset = Vector2.new(-1, 0),
			Transparency = seq({ { 0, 1 }, { 0.42, 1 }, { 0.5, 0.35 }, { 0.58, 1 }, { 1, 1 } }),
		}, image)
	end
end

local function text(name: string, props: { [string]: any }): TextLabel
	local label = make("TextLabel", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		FontFace = Font.new(RUBIK, Enum.FontWeight.Bold),
		TextColor3 = MUTED,
		TextSize = 26,
		ZIndex = 6,
	}, canvas)
	for k, v in props do
		(label :: any)[k] = v
	end
	return label
end

-- Teleports: the mode as a line over the title (MatchFoundController / the match end fill it).
text("Mode", {
	Position = px(960, 170),
	Size = px(1400, 56),
	Text = "1V1  /  LOADING MATCH",
	TextColor3 = INK,
	TextSize = 44,
	FontFace = Font.new(RUBIK, Enum.FontWeight.Heavy),
	Visible = false,
})

-- Progress: four segments, one per real stage; each fills gold (the screen's one gold thing besides the title).
local pips = make("Frame", {
	Name = "Pips",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = px(960, 700),
	Size = px(560, 10),
	BackgroundTransparency = 1,
	ZIndex = 6,
}, canvas)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 12),
	SortOrder = Enum.SortOrder.Name,
}, pips)
local width = (560 - 12 * (SEGMENTS - 1)) / SEGMENTS
for i = 1, SEGMENTS do
	local pip = make("Frame", {
		Name = "Pip" .. i,
		Size = px(width, 10),
		BackgroundColor3 = Color3.fromHex("252D3C"),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 6,
	}, pips)
	make("UICorner", { CornerRadius = UDim.new(0, 3) }, pip)
	local fill = make("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
		ZIndex = 7,
	}, pip)
	make("UICorner", { CornerRadius = UDim.new(0, 3) }, fill)
	-- The segment being worked on breathes (the script moves this band).
	make("UIGradient", {
		Name = "Pulse",
		Offset = Vector2.new(-1, 0),
		Transparency = seq({ { 0, 1 }, { 0.4, 1 }, { 0.5, 0.6 }, { 0.6, 1 }, { 1, 1 } }),
		Enabled = false,
	}, pip)
end

-- The stage word sits in a clipping strip so it can slide up between stages.
local stageClip = make("Frame", {
	Name = "StageClip",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = px(960, 748),
	Size = px(1200, 40),
	BackgroundTransparency = 1,
	ClipsDescendants = true,
	ZIndex = 6,
}, canvas)
make("TextLabel", {
	Name = "Stage",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	FontFace = Font.new(RUBIK, Enum.FontWeight.Bold),
	Text = "CONNECTING",
	TextColor3 = INK,
	TextSize = 26,
	ZIndex = 6,
}, stageClip)
text("Count", {
	Position = px(960, 788),
	Size = px(600, 30),
	Text = "",
	TextSize = 26, -- 12 px on a phone (LoadingLayout)
})

-- A ring spinner at the segments' left end (circle + ring, the turning part a stroke gradient).
local spinner = make("Frame", {
	Name = "Spinner",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = px(960 - 280 - 34, 700),
	Size = px(26, 26),
	BackgroundTransparency = 1,
	ZIndex = 6,
}, canvas)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, spinner)
local stroke = make("UIStroke", { Thickness = 3, Color = INK }, spinner)
make("UIGradient", {
	Name = "Turn",
	Transparency = seq({ { 0, 0 }, { 0.5, 0.15 }, { 0.52, 1 }, { 1, 1 } }),
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
