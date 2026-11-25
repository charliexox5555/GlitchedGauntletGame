--!strict
-- Builds two lobby screens in the LOBBY place, Edit mode (vault/02 Art/UI
-- Lobby Overhaul.md → Missing screens). Re-running replaces them.
--   StarterGui.Profile  a player's card (Controllers/ProfileController),
--                       opened from their row in the player list
--   StarterGui.Rewards  reward rows (Controllers/RewardsController)
--   UiTemplates.Lobby.ProfileSkin / RewardRow  their slots
-- Structure studied from RIVALS' ViewProfile and Rewards pages (not copied);
-- our look: wash over the blurred lobby, chunky cells, slanted plates,
-- Fredoka One, the drawn-X close.

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

local FONT = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy) -- Rubik
local WHITE = Color3.new(1, 1, 1)
local INK = hex("0F0F12")
local NAVY = hex("141417")
local NAVY_HI = hex("252528")
local MUTED = hex("9F9FA2")
local CYAN = hex("3FE0F2")
local GOLD = hex("FFC83D")
local CENTRE = Vector2.new(0.5, 0.5)
local CAP_R = "rbxassetid://130377997107460"
local COIN = "rbxassetid://126250416946442"

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
-- a slanted plate button with words (white = the act-now thing here)
local function plateButton(
	p: Instance,
	name: string,
	label: string,
	pos: UDim2,
	size: Vector2,
	fill: Color3,
	ink: Color3
): TextButton
	local b = make("TextButton", {
		Name = name,
		AnchorPoint = CENTRE,
		Position = pos,
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = fill,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 4,
	}, p)
	slant(b, fill, size.Y, math.floor(size.Y * 0.32))
	make("UIScale", { Name = "Pop" }, b)
	text(
		b,
		"Label",
		label,
		math.floor(size.Y * 0.45),
		ink,
		{ Size = UDim2.fromScale(1, 1), ZIndex = 7 }
	)
	return b
end
local function screen(name: string): (ScreenGui, Frame)
	local old = SG:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local gui = make("ScreenGui", {
		Name = name,
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
			ColorSequenceKeypoint.new(0, hex("2E2E31")),
			ColorSequenceKeypoint.new(0.55, hex("1E1E21")),
			ColorSequenceKeypoint.new(1, hex("131316")),
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
	return gui, canvas
end

------------------------------------------------------------------------------
-- Profile: one card in the middle

local profile, pc = screen("Profile")
local card = make("Frame", {
	Name = "Card",
	AnchorPoint = CENTRE,
	Position = UDim2.fromOffset(960, 560),
	Size = UDim2.fromOffset(980, 700),
	BackgroundColor3 = NAVY,
	BackgroundTransparency = 0.15,
	BorderSizePixel = 0,
	ZIndex = 2,
}, pc)
corner(card)
local shotHolder = make("Frame", {
	Name = "Portrait",
	Position = UDim2.fromOffset(56, 56),
	Size = UDim2.fromOffset(170, 170),
	BackgroundColor3 = NAVY_HI,
	BorderSizePixel = 0,
	ZIndex = 4,
}, card)
round(shotHolder)
local headshot = make("ImageLabel", {
	Name = "Headshot",
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.94, 0.94),
	BackgroundTransparency = 1,
	ZIndex = 5,
}, shotHolder)
round(headshot)
text(card, "DisplayName", "PLAYER", 54, WHITE, {
	Position = UDim2.fromOffset(260, 66),
	Size = UDim2.fromOffset(660, 62),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
})
text(card, "Username", "@player", 24, MUTED, {
	Position = UDim2.fromOffset(262, 130),
	Size = UDim2.fromOffset(660, 30),
	TextXAlignment = Enum.TextXAlignment.Left,
})
-- level and streak tags (slanted plates)
local tags = make("Frame", {
	Name = "Tags",
	Position = UDim2.fromOffset(276, 176),
	Size = UDim2.fromOffset(600, 44),
	BackgroundTransparency = 1,
	ZIndex = 4,
}, card)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 34),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, tags)
for i, spec in { { "Level", "LV 1", GOLD, INK }, { "Streak", "STREAK 0", NAVY_HI, WHITE } } do
	local tag = make("Frame", {
		Name = spec[1],
		LayoutOrder = i,
		Size = UDim2.fromOffset(170, 44),
		BackgroundColor3 = spec[3],
		BorderSizePixel = 0,
		ZIndex = 4,
	}, tags)
	slant(tag, spec[3], 44, 14)
	text(tag, "Label", spec[2], 22, spec[4], { Size = UDim2.fromScale(1, 1), ZIndex = 7 })
end
-- stats: three cells
local stats = make("Frame", {
	Name = "Stats",
	Position = UDim2.fromOffset(56, 266),
	Size = UDim2.fromOffset(868, 140),
	BackgroundTransparency = 1,
	ZIndex = 3,
}, card)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 20),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, stats)
for i, name in { "MATCHES", "WINS", "ELIMS" } do
	local cell = make("Frame", {
		Name = "Stat" .. i,
		LayoutOrder = i,
		Size = UDim2.fromOffset(276, 140),
		BackgroundColor3 = NAVY_HI,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, stats)
	corner(cell)
	text(cell, "Value", "-", 54, WHITE, {
		Position = UDim2.fromOffset(0, 18),
		Size = UDim2.new(1, 0, 0, 62),
		ZIndex = 6,
	})
	text(cell, "Label", name, 20, MUTED, {
		Position = UDim2.fromOffset(0, 88),
		Size = UDim2.new(1, 0, 0, 26),
		ZIndex = 6,
	})
end
text(card, "StatsNote", "MATCH STATS COME WITH THE PROFILE SYSTEM", 16, MUTED, {
	Position = UDim2.fromOffset(56, 414),
	Size = UDim2.fromOffset(868, 22),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTransparency = 0.2,
})
text(card, "SkinsTitle", "EQUIPPED SKINS", 24, CYAN, {
	Position = UDim2.fromOffset(56, 452),
	Size = UDim2.fromOffset(600, 30),
	TextXAlignment = Enum.TextXAlignment.Left,
})
local skins = make("Frame", {
	Name = "Skins",
	Position = UDim2.fromOffset(56, 492),
	Size = UDim2.fromOffset(868, 104),
	BackgroundTransparency = 1,
	ZIndex = 3,
}, card)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 16),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, skins)
text(skins, "None", "NOTHING EQUIPPED YET", 20, MUTED, {
	Size = UDim2.fromOffset(600, 104),
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 99,
})
-- the action: INVITE TO PARTY (others) or OPEN LOCKER (you)
plateButton(
	card,
	"Action",
	"INVITE TO PARTY",
	UDim2.fromOffset(490, 650),
	Vector2.new(360, 64),
	WHITE,
	INK
)
profile.Parent = SG

------------------------------------------------------------------------------
-- Rewards: a title and a list of reward rows

local rewards, rc = screen("Rewards")
text(rc, "Title", "REWARDS", 64, WHITE, {
	Position = UDim2.fromOffset(460, 60),
	Size = UDim2.fromOffset(0, 70),
	AutomaticSize = Enum.AutomaticSize.X,
	TextXAlignment = Enum.TextXAlignment.Left,
})
text(rc, "Sub", "FREE COINS FOR HELPING THE GAME GROW", 22, CYAN, {
	Position = UDim2.fromOffset(464, 134),
	Size = UDim2.fromOffset(1000, 28),
	TextXAlignment = Enum.TextXAlignment.Left,
})
local rlist = make("ScrollingFrame", {
	Name = "List",
	Position = UDim2.fromOffset(440, 190),
	Size = UDim2.fromOffset(1040, 760),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 0, -- no visible bar (owner, 2026-11-16)
	ScrollBarImageTransparency = 1,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ZIndex = 2,
}, rc)
make("UIListLayout", { Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder }, rlist)
make("UIPadding", {
	PaddingLeft = UDim.new(0, 20),
	PaddingRight = UDim.new(0, 20),
	PaddingTop = UDim.new(0, 4),
	PaddingBottom = UDim.new(0, 8),
}, rlist)
text(
	rc,
	"Note",
	"COINS ARRIVE WITH THE ECONOMY. THE BUTTONS THAT WORK TODAY OPEN ROBLOX'S OWN PROMPTS.",
	18,
	MUTED,
	{
		Position = UDim2.fromOffset(460, 980),
		Size = UDim2.fromOffset(1000, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTransparency = 0.15,
	}
)
rewards.Parent = SG

------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- Templates

local folder = RS:FindFirstChild("UiTemplates") or make("Folder", { Name = "UiTemplates" }, RS)
local lobby = folder:FindFirstChild("Lobby") or make("Folder", { Name = "Lobby" }, folder)
for _, n in { "ProfileSkin", "RewardRow" } do
	local o = lobby:FindFirstChild(n)
	if o then
		o:Destroy()
	end
end

-- an equipped skin: the line's emblem, the gun, the line
local ps = make("Frame", {
	Name = "ProfileSkin",
	Size = UDim2.fromOffset(204, 104),
	BackgroundColor3 = NAVY_HI,
	BackgroundTransparency = 0.1,
	BorderSizePixel = 0,
	ZIndex = 4,
}, lobby)
corner(ps)
make("ImageLabel", {
	Name = "Emblem",
	Position = UDim2.fromOffset(14, 14),
	Size = UDim2.fromOffset(40, 40),
	BackgroundTransparency = 1,
	ScaleType = Enum.ScaleType.Fit,
	ZIndex = 6,
}, ps)
text(ps, "Gun", "HAVOC", 24, WHITE, {
	Position = UDim2.fromOffset(14, 58),
	Size = UDim2.fromOffset(180, 26),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	ZIndex = 6,
})
text(ps, "Line", "PRISM", 16, MUTED, {
	Position = UDim2.fromOffset(14, 82),
	Size = UDim2.fromOffset(180, 18),
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 6,
})

-- a reward row: title, what to do, the coins, the button
local rr = make("Frame", {
	Name = "RewardRow",
	Size = UDim2.fromOffset(1000, 112),
	BackgroundColor3 = NAVY,
	BackgroundTransparency = 0.15,
	BorderSizePixel = 0,
	ZIndex = 3,
}, lobby)
corner(rr)
text(rr, "Title", "JOIN THE GROUP", 32, WHITE, {
	Position = UDim2.fromOffset(34, 20),
	Size = UDim2.fromOffset(560, 38),
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 6,
})
text(rr, "Sub", "What to do", 20, MUTED, {
	Position = UDim2.fromOffset(34, 62),
	Size = UDim2.fromOffset(560, 26),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	ZIndex = 6,
})
-- the coins: a gold price plate
local reward = make("Frame", {
	Name = "Reward",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 620, 0.5, 0),
	Size = UDim2.fromOffset(120, 46),
	BackgroundColor3 = GOLD,
	BorderSizePixel = 0,
	ZIndex = 5,
}, rr)
slant(reward, GOLD, 46, 15)
make("ImageLabel", {
	Name = "Coin",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 8, 0.5, 0),
	Size = UDim2.fromOffset(32, 32),
	BackgroundTransparency = 1,
	Image = COIN,
	ZIndex = 8,
}, reward)
text(reward, "Amount", "100", 24, INK, {
	Position = UDim2.fromOffset(42, 0),
	Size = UDim2.new(1, -46, 1, 0),
	ZIndex = 8,
})
plateButton(rr, "Go", "SOON", UDim2.new(0, 880, 0.5, 0), Vector2.new(180, 56), NAVY_HI, MUTED)

print("[BuildProfileRewards] Profile, Rewards, the gift button and templates built")
