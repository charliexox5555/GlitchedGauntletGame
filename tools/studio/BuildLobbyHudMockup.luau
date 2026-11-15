--!strict
-- Mockup: the lobby main HUD redesign (vault/02 Art/UI Lobby HUD.md), layout B
-- (owner's pick): PLAY in the bottom-right corner with the mode card above
-- it, the menus as a list on the left, the profile top-left, coins and
-- settings top-right; the middle stays clear for your character and the hub.
-- Same language as the match UI: navy plates, slanted gold blocks, Builder
-- Extended, keycaps, soft shadows; no pills, glows or gradients.
-- Paste into the Studio command bar of the LOBBY place (Edit mode). Builds
-- StarterGui.LobbyHudMockup (Enabled off): CanvasIdle and CanvasSearching.

local SG = game:GetService("StarterGui")

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
local XB, SB = Enum.FontWeight.ExtraBold, Enum.FontWeight.SemiBold
local NAVY, NAVY_HI = hex("1C2740"), hex("2B3A5A")
local ALLY, ALLY_CELL = hex("3FE0F2"), hex("0D5C7A")
local GOLD, MUTED, INK, WHITE = hex("FFC83D"), hex("8E98A8"), hex("141A26"), Color3.new(1, 1, 1)
local SHADOW = "rbxassetid://121253415859134"
local CAP_R, CAP_L = "rbxassetid://130377997107460", "rbxassetid://75584308608588"
local ICON = {
	Shop = "rbxassetid://134974442051869",
	Locker = "rbxassetid://73637059723267",
	BattlePass = "rbxassetid://133121960419132",
	Range = "rbxassetid://82357119585599",
	Settings = "rbxassetid://85379480378289",
	Coin = "rbxassetid://122645025340088",
}
local CENTRE = Vector2.new(0.5, 0.5)

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

local function shadow(p: Instance, x: number, y: number, w: number, h: number)
	make("ImageLabel", {
		Name = "Shadow",
		Position = UDim2.fromOffset(x - 30, y - 22),
		Size = UDim2.fromOffset(w + 60, h + 60),
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
	local k = make(
		"Frame",
		{
			Name = "Key",
			Size = UDim2.fromOffset(w, h),
			BackgroundColor3 = hex("0B0F17"),
			BorderSizePixel = 0,
			ZIndex = 8,
		},
		p
	)
	for kk, v in props do
		(k :: any)[kk] = v
	end
	corner(k, 5)
	local f = make(
		"Frame",
		{
			Name = "Face",
			Size = UDim2.new(1, 0, 1, -4),
			BackgroundColor3 = hex("E9EDF3"),
			BorderSizePixel = 0,
			ZIndex = 9,
		},
		k
	)
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

local function canvas(gui: Instance, name: string): Frame
	local c = make(
		"Frame",
		{
			Name = name,
			AnchorPoint = CENTRE,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(1920, 1080),
			BackgroundTransparency = 1,
		},
		gui
	)
	make("UIScale", { Name = "Fit" }, c)
	return c
end

-- Profile (top-left, under Roblox's buttons): portrait cell, name, segmented
-- XP bar, and the level on a gold block.
local function profile(c: Instance)
	local x, y, w, h = 60, 76, 420, 72
	shadow(c, x, y, w, h)
	local p = make(
		"Frame",
		{
			Name = "Profile",
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, h),
			BackgroundColor3 = NAVY,
			BorderSizePixel = 0,
		},
		c
	)
	corner(p)
	local cell = make(
		"Frame",
		{
			Name = "Cell",
			Size = UDim2.fromOffset(h, h),
			BackgroundColor3 = ALLY_CELL,
			BorderSizePixel = 0,
			ZIndex = 2,
		},
		p
	)
	corner(cell)
	make(
		"ImageLabel",
		{
			Name = "Headshot",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = "rbxthumb://type=AvatarHeadShot&id=1&w=150&h=150",
			ZIndex = 3,
		},
		cell
	)
	text(p, "PlayerName", "CHARLIE", 20, WHITE, { Position = UDim2.fromOffset(h + 16, 12) })
	text(p, "Xp", "1,240 / 2,000 XP", 11, MUTED, { Position = UDim2.fromOffset(h + 16, 50) })
	local bar = make(
		"Frame",
		{
			Name = "Bar",
			Position = UDim2.fromOffset(h + 16, 40),
			Size = UDim2.fromOffset(220, 6),
			BackgroundTransparency = 1,
		},
		p
	)
	make(
		"UIListLayout",
		{
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
		},
		bar
	)
	for i = 1, 10 do
		make(
			"Frame",
			{
				Name = "Seg" .. i,
				LayoutOrder = i,
				Size = UDim2.fromOffset(20.2, 6),
				BackgroundColor3 = ALLY,
				BackgroundTransparency = if i <= 6 then 0 else 0.82,
				BorderSizePixel = 0,
			},
			bar
		)
	end
	-- the level: a gold block with a slanted start
	local lvW = 76
	make(
		"ImageLabel",
		{
			Name = "CapL",
			Position = UDim2.fromOffset(w - lvW - 26, 0),
			Size = UDim2.fromOffset(30, h),
			BackgroundTransparency = 1,
			Image = CAP_L,
			ImageColor3 = GOLD,
			ZIndex = 2,
		},
		p
	)
	local lv = make(
		"Frame",
		{
			Name = "Level",
			Position = UDim2.fromOffset(w - lvW, 0),
			Size = UDim2.fromOffset(lvW, h),
			BackgroundColor3 = GOLD,
			BorderSizePixel = 0,
			ZIndex = 2,
		},
		p
	)
	corner(lv)
	text(
		lv,
		"Kicker",
		"LV",
		11,
		INK,
		{
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(lvW / 2 - 4, 12),
			TextTransparency = 0.3,
		}
	)
	text(
		lv,
		"Value",
		"4",
		30,
		INK,
		{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(lvW / 2 - 4, 26) }
	)
end

-- Coins and settings (top-right)
local function wallet(c: Instance)
	local right, y = 1860, 76
	local sW = 64
	shadow(c, right - sW, y, sW, 64)
	local settings = make(
		"Frame",
		{
			Name = "Settings",
			Position = UDim2.fromOffset(right - sW, y),
			Size = UDim2.fromOffset(sW, 64),
			BackgroundColor3 = NAVY,
			BorderSizePixel = 0,
		},
		c
	)
	corner(settings)
	make(
		"ImageLabel",
		{
			Name = "Icon",
			AnchorPoint = CENTRE,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(32, 32),
			BackgroundTransparency = 1,
			Image = ICON.Settings,
			ZIndex = 3,
		},
		settings
	)
	local w = 230
	local x = right - sW - 10 - w
	shadow(c, x, y, w, 64)
	local coins = make(
		"Frame",
		{
			Name = "Coins",
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, 64),
			BackgroundColor3 = NAVY,
			BorderSizePixel = 0,
		},
		c
	)
	corner(coins)
	make(
		"ImageLabel",
		{
			Name = "Icon",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 14, 0.5, 0),
			Size = UDim2.fromOffset(34, 34),
			BackgroundTransparency = 1,
			Image = ICON.Coin,
			ZIndex = 3,
		},
		coins
	)
	text(
		coins,
		"Amount",
		"1,200",
		26,
		WHITE,
		{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 58, 0.5, 0) }
	)
	keycap(
		coins,
		"+",
		38,
		40,
		{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0) }
	)
end

-- The menus, a list down the left: keycap, icon, label. The hovered one is
-- the brighter navy and slides out a little.
local function menu(c: Instance, hovered: number?)
	local items = {
		{ "L", "Locker", "LOCKER", "Skins, sprays, banners" },
		{ "B", "Shop", "SHOP", "Today's deals" },
		{ "P", "BattlePass", "BATTLE PASS", "Tier 12 of 50" },
		{ "R", "Range", "RANGE", "Warm up on the dummies" },
	}
	local x, y0, w, h, g = 60, 360, 400, 72, 10
	for i, it in items do
		local on = i == hovered
		local y = y0 + (i - 1) * (h + g)
		local dx = if on then 14 else 0
		shadow(c, x + dx, y, w, h)
		local b = make(
			"Frame",
			{
				Name = it[2],
				Position = UDim2.fromOffset(x + dx, y),
				Size = UDim2.fromOffset(w, h),
				BackgroundColor3 = if on then NAVY_HI else NAVY,
				BorderSizePixel = 0,
			},
			c
		)
		corner(b)
		keycap(
			b,
			it[1],
			34,
			36,
			{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 0.5, 0) }
		)
		make(
			"ImageLabel",
			{
				Name = "Icon",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 66, 0.5, 0),
				Size = UDim2.fromOffset(34, 34),
				BackgroundTransparency = 1,
				Image = ICON[it[2]],
				ImageColor3 = if on then GOLD else WHITE,
				ZIndex = 3,
			},
			b
		)
		text(
			b,
			"Label",
			it[3],
			22,
			if on then GOLD else WHITE,
			{ Position = UDim2.fromOffset(116, 14) }
		)
		text(
			b,
			"Sub",
			it[4],
			12,
			MUTED,
			{ Position = UDim2.fromOffset(116, 44), FontFace = Font.new(BX, SB) }
		)
	end
end

-- PLAY (bottom-right) with the mode card above it.
local function play(c: Instance, searching: boolean)
	local right, w = 1860, 440
	local x = right - w
	-- mode card
	local my, mh = 760, 80
	shadow(c, x, my, w, mh)
	local mode = make(
		"Frame",
		{
			Name = "Mode",
			Position = UDim2.fromOffset(x, my),
			Size = UDim2.fromOffset(w, mh),
			BackgroundColor3 = NAVY,
			BorderSizePixel = 0,
		},
		c
	)
	corner(mode)
	if searching then
		text(mode, "Title", "SEARCHING", 26, WHITE, { Position = UDim2.fromOffset(24, 12) })
		text(mode, "Sub", "2V2  ·  TEAM DUEL", 12, MUTED, { Position = UDim2.fromOffset(24, 48) })
		text(
			mode,
			"Time",
			"0:23",
			34,
			ALLY,
			{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -24, 0.5, 0) }
		)
	else
		keycap(
			mode,
			"<",
			36,
			38,
			{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 0.5, 0) }
		)
		keycap(
			mode,
			">",
			36,
			38,
			{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0) }
		)
		text(
			mode,
			"Title",
			"2V2",
			30,
			WHITE,
			{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(w / 2, 10) }
		)
		text(
			mode,
			"Sub",
			"TEAM DUEL  ·  FIRST TO 5",
			12,
			MUTED,
			{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(w / 2, 50) }
		)
	end
	-- PLAY / CANCEL
	local py, ph = my + mh + 12, 108
	shadow(c, x + 20, py, w - 40, ph)
	local b = make(
		"Frame",
		{
			Name = "Play",
			Position = UDim2.fromOffset(x, py),
			Size = UDim2.fromOffset(w, ph),
			BackgroundTransparency = 1,
		},
		c
	)
	local fill = if searching then NAVY_HI else GOLD
	make(
		"Frame",
		{
			Name = "Body",
			Position = UDim2.fromOffset(28, 0),
			Size = UDim2.new(1, -56, 1, 0),
			BackgroundColor3 = fill,
			BorderSizePixel = 0,
			ZIndex = 2,
		},
		b
	)
	make(
		"ImageLabel",
		{
			Name = "CapL",
			Size = UDim2.fromOffset(30, ph),
			BackgroundTransparency = 1,
			Image = CAP_L,
			ImageColor3 = fill,
			ZIndex = 2,
		},
		b
	)
	make(
		"ImageLabel",
		{
			Name = "CapR",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(30, ph),
			BackgroundTransparency = 1,
			Image = CAP_R,
			ImageColor3 = fill,
			ZIndex = 2,
		},
		b
	)
	text(
		b,
		"Label",
		if searching then "CANCEL" else "PLAY",
		if searching then 36 else 56,
		if searching then WHITE else INK,
		{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 56, 0.5, 0) }
	)
	keycap(
		b,
		if searching then "ESC" else "ENTER",
		if searching then 52 else 70,
		32,
		{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -52, 0.5, 0) }
	)
end

-- gui -----------------------------------------------------------------------------
local old = SG:FindFirstChild("LobbyHudMockup")
if old then
	old:Destroy()
end
local gui = make(
	"ScreenGui",
	{
		Name = "LobbyHudMockup",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 25,
		Enabled = false,
	}
)

local idle = canvas(gui, "CanvasIdle")
profile(idle)
wallet(idle)
menu(idle, 2)
play(idle, false)

local searching = canvas(gui, "CanvasSearching")
searching.Visible = false
profile(searching)
wallet(searching)
menu(searching, nil)
play(searching, true)

gui.Parent = SG
print("LobbyHudMockup built")
