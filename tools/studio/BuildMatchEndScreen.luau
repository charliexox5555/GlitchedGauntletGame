--!strict
-- Builds the match end screen (vault/02 Art/UI Match End.md) in the match place:
--   StarterGui.MatchEndScreen                 <- Util/MatchEndScreen
--   ReplicatedStorage.UiTemplates.MatchEnd    (Header, Row, Tier, Chip, Plate)
-- Studio owns them; this is their backup. Paste into the command bar (Edit
-- mode); refuses to run if they exist. Desktop only for now.
--
-- Layout: the result + round history on top; the scoreboard bottom-left and
-- the right column (your build, PLAY AGAIN, REMATCH / LEAVE) bottom-right, both
-- stacked by UIListLayouts so nothing can overlap; the middle stays clear for
-- the victory scene (name plates over the winners). Animated pieces are fixed
-- holders with a centred inner part carrying a "Pop" UIScale.

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
local NAVY = hex("1C2740")
local ALLY, ENEMY = hex("3FE0F2"), hex("FF6B57")
local ALLY_CELL = hex("0D5C7A")
local GOLD, MUTED, INK, WHITE = hex("FFC83D"), hex("8E98A8"), hex("141A26"), Color3.new(1, 1, 1)
local SHADOW = "rbxassetid://121253415859134"
local CAP_R = "rbxassetid://130377997107460"
local BOT_HEAD = "rbxassetid://119185654291939"
local SHARD = "rbxassetid://76745392849672"
local CENTRE = Vector2.new(0.5, 0.5)
local COLS = { 360, 420, 480, 548 } -- E, D, A, DMG column centres in a 620 row
local ROW_W = 620
local RIGHT_W = 400

assert(not SG:FindFirstChild("MatchEndScreen"), "StarterGui.MatchEndScreen already exists")

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

local function shadow(p: Instance, name: string)
	make("ImageLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Image = SHADOW,
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 0.45,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(48, 48, 80, 80),
		ZIndex = 0,
	}, p)
end

local function corner(p: Instance, r: number?)
	make("UICorner", { CornerRadius = UDim.new(0, r or 6) }, p)
end

local function keycap(p: Instance, s: string, w: number, h: number, props: { [string]: any }): Frame
	local k = make("Frame", {
		Name = "Key",
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = hex("0B0F17"),
		BorderSizePixel = 0,
		ZIndex = 8,
	}, p)
	for kk, v in props do
		(k :: any)[kk] = v
	end
	corner(k, 5)
	local f = make("Frame", {
		Name = "Face",
		Size = UDim2.new(1, 0, 1, -4),
		BackgroundColor3 = hex("E9EDF3"),
		BorderSizePixel = 0,
		ZIndex = 9,
	}, k)
	corner(f, 5)
	text(
		f,
		"Label",
		s,
		math.floor(h * 0.42),
		INK,
		{ AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.fromScale(1, 1), ZIndex = 10 }
	)
	return k
end

local function hlist(p: Instance, pad: number)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, pad),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, p)
end

local function gap(p: Instance, order: number, w: number)
	make("Frame", {
		Name = "Gap" .. order,
		LayoutOrder = order,
		Size = UDim2.fromOffset(w, 2),
		BackgroundTransparency = 1,
	}, p)
end

local function strip(p: Instance, h: number, props: { [string]: any }): CanvasGroup
	local g = make("CanvasGroup", {
		Name = "Strip",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, h),
		BackgroundColor3 = NAVY,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, p)
	for k, v in props do
		(g :: any)[k] = v
	end
	corner(g)
	hlist(g, 0)
	return g
end

-- Team block (dark-ink name, optional glitch split copies) + its slanted end.
local function teamBlock(
	p: Instance,
	s: string,
	size: number,
	color: Color3,
	h: number,
	padL: number,
	split: boolean
)
	local b = make("Frame", {
		Name = "Team",
		LayoutOrder = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, h),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, p)
	make("UIPadding", { PaddingLeft = UDim.new(0, padL), PaddingRight = UDim.new(0, 6) }, b)
	text(
		b,
		"Label",
		s,
		size,
		INK,
		{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), ZIndex = 5 }
	)
	if split then
		local d = math.max(3, math.floor(size / 18))
		text(b, "SplitA", s, size, hex("00E5FF"), {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, -d, 0.5, 0),
			ZIndex = 3,
			Visible = false,
		})
		text(b, "SplitB", s, size, hex("FF8BE0"), {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, d, 0.5, 0),
			ZIndex = 4,
			Visible = false,
		})
	end
	make("ImageLabel", {
		Name = "Cap",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(math.floor(h * 0.42), h),
		BackgroundTransparency = 1,
		Image = CAP_R,
		ImageColor3 = color,
		ZIndex = 2,
	}, p)
end

-- Templates ---------------------------------------------------------------------
local templates = RS:FindFirstChild("UiTemplates") or make("Folder", { Name = "UiTemplates" }, RS)
local old = templates:FindFirstChild("MatchEnd")
if old then
	old:Destroy()
end
local folder = make("Folder", { Name = "MatchEnd" }, templates)

do -- Header: a team block and the column labels
	local h = make("Frame", {
		Name = "Header",
		Size = UDim2.fromOffset(ROW_W, 34),
		BackgroundColor3 = NAVY,
		BorderSizePixel = 0,
	}, folder)
	corner(h)
	local block = make("Frame", {
		Name = "Team",
		Size = UDim2.fromOffset(170, 34),
		BackgroundColor3 = ALLY,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, h)
	corner(block)
	text(block, "Label", "YOUR TEAM", 14, INK, { Position = UDim2.fromOffset(14, 8) })
	make("ImageLabel", {
		Name = "Cap",
		Position = UDim2.fromOffset(166, 0),
		Size = UDim2.fromOffset(14, 34),
		BackgroundTransparency = 1,
		Image = CAP_R,
		ImageColor3 = ALLY,
		ZIndex = 2,
	}, h)
	for i, l in { "E", "D", "A", "DMG" } do
		text(
			h,
			"Col" .. i,
			l,
			11,
			MUTED,
			{ AnchorPoint = CENTRE, Position = UDim2.fromOffset(COLS[i], 17) }
		)
	end
end

do -- Row: a fixed holder; the Body slides in (your row: the script makes it 58 tall)
	local holder = make(
		"Frame",
		{ Name = "Row", Size = UDim2.fromOffset(ROW_W, 46), BackgroundTransparency = 1 },
		folder
	)
	local body = make("CanvasGroup", {
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = NAVY,
		BorderSizePixel = 0,
	}, holder)
	corner(body)
	local cell = make("Frame", {
		Name = "Cell",
		Size = UDim2.new(0, 46, 1, 0),
		BackgroundColor3 = ALLY_CELL,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, body)
	corner(cell)
	make("ImageLabel", {
		Name = "Headshot",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = BOT_HEAD,
		ZIndex = 3,
	}, cell)
	local line = make("Frame", {
		Name = "NameLine",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 60, 0.5, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 26),
		BackgroundTransparency = 1,
	}, body)
	hlist(line, 8)
	text(
		line,
		"PlayerName",
		"PLAYER",
		16,
		ALLY,
		{ LayoutOrder = 1, TextTruncate = Enum.TextTruncate.AtEnd }
	)
	make("ImageLabel", {
		Name = "Shard",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(22, 22),
		BackgroundTransparency = 1,
		Image = SHARD,
		ImageColor3 = GOLD,
		ZIndex = 3,
		Visible = false,
	}, line)
	text(line, "Mvp", "MVP", 12, GOLD, { LayoutOrder = 3, Visible = false })
	for i = 1, 4 do
		text(
			body,
			"Stat" .. i,
			"0",
			17,
			WHITE,
			{ AnchorPoint = CENTRE, Position = UDim2.new(0, COLS[i], 0.5, 0) }
		)
	end
end

do -- Tier: a gun tier's label over its round chips
	local g = make("Frame", {
		Name = "Tier",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 58),
		BackgroundTransparency = 1,
	}, folder)
	text(g, "Label", "SIDEARM", 10, MUTED, { Position = UDim2.fromOffset(0, 6) })
	local chips = make("Frame", {
		Name = "Chips",
		Position = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 28),
		BackgroundTransparency = 1,
	}, g)
	hlist(chips, 4)
	local chip = make("Frame", {
		Name = "Chip",
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = ALLY,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, folder)
	corner(chip, 4)
	text(
		chip,
		"N",
		"1",
		12,
		INK,
		{ AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.fromScale(1, 1) }
	)
end

do -- Plate: a name plate over a cheering winner in the scene
	local bb = make("BillboardGui", {
		Name = "Plate",
		Size = UDim2.fromOffset(260, 40),
		StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 80,
		ResetOnSpawn = false,
	}, folder)
	local s = strip(bb, 34, { AnchorPoint = CENTRE, Position = UDim2.fromScale(0.5, 0.5) })
	teamBlock(s, "PLAYER", 15, ALLY, 34, 12, false)
	gap(s, 3, 8)
	make("ImageLabel", {
		Name = "Shard",
		LayoutOrder = 4,
		Size = UDim2.fromOffset(22, 22),
		BackgroundTransparency = 1,
		Image = SHARD,
		ImageColor3 = GOLD,
		ZIndex = 3,
		Visible = false,
	}, s)
	text(s, "Mvp", "MVP", 12, GOLD, { LayoutOrder = 5, Visible = false })
	gap(s, 6, 8)
end

-- StarterGui.MatchEndScreen -----------------------------------------------------
local gui = make("ScreenGui", {
	Name = "MatchEndScreen",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ScreenInsets = Enum.ScreenInsets.None,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 15,
	Enabled = false,
})
make(
	"TextButton",
	{ Name = "Modal", Modal = true, BackgroundTransparency = 1, Text = "", Size = UDim2.new() },
	gui
) -- frees the mouse
local c = make("Frame", {
	Name = "Canvas",
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(1920, 1080),
	BackgroundTransparency = 1,
}, gui)
make("UIScale", { Name = "Fit" }, c)

do -- the result: VICTORY / DEFEAT + the final score
	local holder = make("Frame", {
		Name = "Result",
		AnchorPoint = CENTRE,
		Position = UDim2.fromOffset(960, 104),
		Size = UDim2.fromOffset(900, 96),
		BackgroundTransparency = 1,
	}, c)
	make("UIScale", { Name = "Pop" }, holder)
	shadow(holder, "Shadow")
	local s = strip(holder, 96, { AnchorPoint = CENTRE, Position = UDim2.fromScale(0.5, 0.5) })
	teamBlock(s, "VICTORY", 64, ALLY, 96, 30, true)
	gap(s, 3, 22)
	text(s, "Us", "0", 56, ALLY, { LayoutOrder = 4 })
	gap(s, 5, 16)
	text(s, "Dash", "·", 40, MUTED, { LayoutOrder = 6 })
	gap(s, 7, 16)
	text(s, "Them", "0", 56, ENEMY, { LayoutOrder = 8 })
	gap(s, 9, 30)
end

do -- the round history (the script fills Tier groups)
	local holder = make("Frame", {
		Name = "Rounds",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(960, 166),
		Size = UDim2.fromOffset(900, 58),
		BackgroundTransparency = 1,
	}, c)
	local s =
		strip(holder, 58, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0) })
	make("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, s)
	local layout = s:FindFirstChildOfClass("UIListLayout")
	if layout then
		layout.Padding = UDim.new(0, 18)
	end
end

do -- the scoreboard: headers and rows in one list, bottom-aligned, growing up
	shadow(c, "BoardShadow")
	local board = make("Frame", {
		Name = "Board",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromOffset(60, 924),
		Size = UDim2.fromOffset(ROW_W, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, c)
	make(
		"UIListLayout",
		{ Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder },
		board
	)
end

do -- the right column: your build, PLAY AGAIN, REMATCH / LEAVE
	shadow(c, "RightShadow")
	local right = make("Frame", {
		Name = "Right",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromOffset(1860, 924),
		Size = UDim2.fromOffset(RIGHT_W, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, c)
	make(
		"UIListLayout",
		{ Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder },
		right
	)
	local head = make("Frame", {
		Name = "BuildHeader",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(RIGHT_W, 30),
		BackgroundColor3 = NAVY,
		BorderSizePixel = 0,
	}, right)
	corner(head)
	text(head, "Label", "YOUR BUILD", 12, MUTED, { Position = UDim2.fromOffset(12, 7) })
	local build = make("Frame", {
		Name = "Build",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(RIGHT_W, 150),
		BackgroundTransparency = 1,
	}, right)
	hlist(build, 8)
	local cw = (RIGHT_W - 16) / 3
	for i = 1, 3 do
		local holder = make("Frame", {
			Name = "Mod" .. i,
			LayoutOrder = i,
			Size = UDim2.fromOffset(cw, 150),
			BackgroundTransparency = 1,
		}, build)
		local card = make("CanvasGroup", {
			Name = "Card",
			AnchorPoint = CENTRE,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = NAVY,
			BorderSizePixel = 0,
		}, holder)
		corner(card)
		make("UIScale", { Name = "Pop" }, card)
		make("ImageLabel", {
			Name = "Art",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Crop,
			ZIndex = 1,
		}, card)
		make("Frame", {
			Name = "Band",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(cw / 2, 100),
			Size = UDim2.fromOffset(cw * 2, 120),
			Rotation = -6,
			BackgroundColor3 = ALLY,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, card)
		text(card, "Path", "PATH", 12, INK, {
			Position = UDim2.fromOffset(10, 110),
			ZIndex = 4,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		text(
			card,
			"Level",
			"LV 1",
			11,
			INK,
			{ Position = UDim2.fromOffset(10, 128), ZIndex = 4, TextTransparency = 0.3 }
		)
	end
	-- PLAY AGAIN: the gold primary, the column's full width
	local playHolder = make("Frame", {
		Name = "PlayAgain",
		LayoutOrder = 3,
		Size = UDim2.fromOffset(RIGHT_W, 76),
		BackgroundTransparency = 1,
	}, right)
	local play = make("TextButton", {
		Name = "Button",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 2,
	}, playHolder)
	corner(play)
	make("UIScale", { Name = "Pop" }, play)
	text(
		play,
		"Label",
		"PLAY AGAIN",
		30,
		INK,
		{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 24, 0.5, 0) }
	)
	keycap(
		play,
		"ENTER",
		62,
		28,
		{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -18, 0.5, 0) }
	)
	-- REMATCH (votes, R) and LEAVE (the lobby countdown)
	local choices = make("Frame", {
		Name = "Choices",
		LayoutOrder = 4,
		Size = UDim2.fromOffset(RIGHT_W, 56),
		BackgroundTransparency = 1,
	}, right)
	hlist(choices, 8)
	local bw = (RIGHT_W - 8) / 2
	for i, spec in
		{ { "Rematch", "REMATCH", "0 / 0 VOTES", "R" }, { "Leave", "LEAVE", "LOBBY IN 20", nil } }
	do
		local holder = make("Frame", {
			Name = spec[1],
			LayoutOrder = i,
			Size = UDim2.fromOffset(bw, 56),
			BackgroundTransparency = 1,
		}, choices)
		local b = make("TextButton", {
			Name = "Button",
			AnchorPoint = CENTRE,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = NAVY,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			ZIndex = 2,
		}, holder)
		corner(b)
		make("UIScale", { Name = "Pop" }, b)
		text(b, "Label", spec[2], 17, WHITE, { Position = UDim2.fromOffset(16, 9) })
		text(b, "Sub", spec[3], 11, ALLY, { Position = UDim2.fromOffset(16, 32) })
		if spec[4] then
			keycap(
				b,
				spec[4],
				30,
				30,
				{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0) }
			)
		end
	end
end

gui.Parent = SG
print("MatchEndScreen built")
