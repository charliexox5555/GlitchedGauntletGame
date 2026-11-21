--!strict
-- Builds the winner card for the match end screen (vault/02 Art/Win
-- Cutscene.md → Results UI; owner 2026-11-20: a card with stats under each
-- winning player, a bigger MVP card): ReplicatedStorage.UiTemplates.MatchEnd.Card
-- (Util/MatchEndScreen clones it per winner). Studio owns it; this is its
-- backup. Paste into the command bar (Edit mode) in the match place; it
-- replaces an old Card. Same look as the rest of the screen
-- (tools/studio/BuildMatchEndScreen.luau): a charcoal plate, the team-colour
-- name block with its slanted cap, Rubik.
--
-- Card (Frame 260 x 190, fixed holder; the code scales the MVP's up)
--   Pop (UIScale)
--   Badge (CanvasGroup, above the card, MVP only): shard + "MVP"
--   Body (CanvasGroup): the plate
--     Top: Team block (Portrait, Name) + Cap
--     Stats: E / D / A cells (Value, Label)
--     Damage: dealt / taken (Value, Label)

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

local RUBIK = "rbxassetid://12187365977"
local XB, BOLD = Enum.FontWeight.ExtraBold, Enum.FontWeight.Bold
local CHARCOAL, CELL = hex("262629"), hex("1C1C1F")
local ALLY, GOLD, MUTED, INK, WHITE =
	hex("3FE0F2"), hex("FFC83D"), hex("97979A"), hex("1A1A1D"), Color3.new(1, 1, 1)
local CAP_R = "rbxassetid://130377997107460"
local SHARD = "rbxassetid://76745392849672"
local SHADOW = "rbxassetid://121253415859134"
local W, H = 260, 190

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
		Size = UDim2.fromOffset(0, size + 4),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = s,
		FontFace = Font.new(RUBIK, XB),
		TextSize = size,
		TextColor3 = color,
		ZIndex = 4,
	}, p)
	for k, v in props or {} do
		(t :: any)[k] = v
	end
	return t
end

local folder = RS:WaitForChild("UiTemplates"):WaitForChild("MatchEnd")
local old = folder:FindFirstChild("Card")
if old then
	old:Destroy()
end

local card = make("Frame", {
	Name = "Card",
	AnchorPoint = Vector2.new(0.5, 1),
	Size = UDim2.fromOffset(W, H),
	BackgroundTransparency = 1,
}, folder)
make("UIScale", { Name = "Pop" }, card)
make("ImageLabel", {
	Name = "Shadow",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(1, 40, 1, 40),
	BackgroundTransparency = 1,
	Image = SHADOW,
	ImageColor3 = Color3.new(0, 0, 0),
	ImageTransparency = 0.45,
	ScaleType = Enum.ScaleType.Slice,
	SliceCenter = Rect.new(48, 48, 80, 80),
	ZIndex = 0,
}, card)

-- the MVP badge over the card
local badge = make("CanvasGroup", {
	Name = "Badge",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 0, -8),
	AutomaticSize = Enum.AutomaticSize.X,
	Size = UDim2.fromOffset(0, 30),
	BackgroundColor3 = GOLD,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 5,
}, card)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, badge)
make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 12) }, badge)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, badge)
make("ImageLabel", {
	Name = "Shard",
	LayoutOrder = 1,
	Size = UDim2.fromOffset(20, 20),
	BackgroundTransparency = 1,
	Image = SHARD,
	ImageColor3 = INK,
	ZIndex = 6,
}, badge)
text(badge, "Label", "MVP", 16, INK, { LayoutOrder = 2, ZIndex = 6 })

-- the plate
local body = make("CanvasGroup", {
	Name = "Body",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = CHARCOAL,
	BackgroundTransparency = 0.06,
	BorderSizePixel = 0,
	ZIndex = 1,
}, card)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, body)

-- top: the team-colour name block (portrait + name) and its slanted cap
local top = make("Frame", {
	Name = "Top",
	Size = UDim2.new(1, 0, 0, 46),
	BackgroundTransparency = 1,
	ZIndex = 2,
}, body)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
}, top)
local team = make("Frame", {
	Name = "Team",
	LayoutOrder = 1,
	Size = UDim2.new(1, -20, 1, 0),
	BackgroundColor3 = ALLY,
	BorderSizePixel = 0,
	ZIndex = 2,
}, top)
make("ImageLabel", {
	Name = "Portrait",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 6, 0.5, 0),
	Size = UDim2.fromOffset(36, 36),
	BackgroundColor3 = INK,
	BackgroundTransparency = 0.6,
	BorderSizePixel = 0,
	Image = "",
	ZIndex = 3,
}, team)
text(team, "Name", "PLAYER", 19, INK, {
	AutomaticSize = Enum.AutomaticSize.None,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 50, 0.5, 0),
	Size = UDim2.new(1, -56, 0, 24),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
})
make("ImageLabel", {
	Name = "Cap",
	LayoutOrder = 2,
	Size = UDim2.fromOffset(20, 46),
	BackgroundTransparency = 1,
	Image = CAP_R,
	ImageColor3 = ALLY,
	ZIndex = 2,
}, top)

-- E / D / A
local stats = make("Frame", {
	Name = "Stats",
	Position = UDim2.fromOffset(12, 56),
	Size = UDim2.new(1, -24, 0, 70),
	BackgroundTransparency = 1,
	ZIndex = 2,
}, body)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, stats)
for i, label in { "ELIMS", "DEATHS", "ASSISTS" } do
	local cell = make("Frame", {
		Name = "Cell" .. i,
		LayoutOrder = i,
		Size = UDim2.new(1 / 3, -6, 1, 0),
		BackgroundColor3 = CELL,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, stats)
	make("UICorner", { CornerRadius = UDim.new(0, 5) }, cell)
	text(cell, "Value", "0", 30, WHITE, {
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 34),
	})
	text(cell, "Label", label, 11, MUTED, {
		AutomaticSize = Enum.AutomaticSize.None,
		FontFace = Font.new(RUBIK, BOLD),
		Position = UDim2.new(0, 0, 1, -22),
		Size = UDim2.new(1, 0, 0, 14),
	})
end

-- damage dealt / taken
local dmg = make("Frame", {
	Name = "Damage",
	Position = UDim2.new(0, 12, 1, -54),
	Size = UDim2.new(1, -24, 0, 44),
	BackgroundTransparency = 1,
	ZIndex = 2,
}, body)
for i, label in { "DAMAGE DEALT", "DAMAGE TAKEN" } do
	local col = make("Frame", {
		Name = if i == 1 then "Dealt" else "Taken",
		Position = UDim2.fromScale((i - 1) * 0.5, 0),
		Size = UDim2.fromScale(0.5, 1),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, dmg)
	text(col, "Value", "0", 20, WHITE, {
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.new(1, 0, 0, 24),
	})
	text(col, "Label", label, 10, MUTED, {
		AutomaticSize = Enum.AutomaticSize.None,
		FontFace = Font.new(RUBIK, BOLD),
		Position = UDim2.fromOffset(0, 25),
		Size = UDim2.new(1, 0, 0, 13),
	})
end

print("UiTemplates.MatchEnd.Card built")
