--!strict
-- Mockup v2: the lobby main HUD (vault/02 Art/UI Lobby HUD.md). The lobby is
-- a hub you walk around, so this is a light in-game HUD, not a menu screen
-- (owner): a compact profile and wallet, a slim rail of icon buttons on the
-- left edge (hotkey keycaps; the label slides out on hover), a small PLAY
-- shortcut in the corner (the Duels pads still queue you), and while
-- searching a small queue strip at the top.
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
local XB = Enum.FontWeight.ExtraBold
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

local function canvas(gui: Instance, name: string): Frame
	local c = make("Frame", {
		Name = name,
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(1920, 1080),
		BackgroundTransparency = 1,
	}, gui)
	make("UIScale", { Name = "Fit" }, c)
	return c
end

-- Profile (top left, under Roblox's buttons): small portrait, name, a thin
-- segmented XP bar, the level on a gold block.
local function profile(c: Instance)
	local x, y, w, h = 40, 68, 300, 56
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
	text(p, "PlayerName", "CHARLIE", 16, WHITE, { Position = UDim2.fromOffset(h + 12, 11) })
	local bar = make(
		"Frame",
		{
			Name = "Bar",
			Position = UDim2.fromOffset(h + 12, 36),
			Size = UDim2.fromOffset(150, 5),
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
				Size = UDim2.fromOffset(13.2, 5),
				BackgroundColor3 = ALLY,
				BackgroundTransparency = if i <= 6 then 0 else 0.82,
				BorderSizePixel = 0,
			},
			bar
		)
	end
	local lvW = 56
	make(
		"ImageLabel",
		{
			Name = "CapL",
			Position = UDim2.fromOffset(w - lvW - 22, 0),
			Size = UDim2.fromOffset(24, h),
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
		10,
		INK,
		{
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(lvW / 2 - 2, 8),
			TextTransparency = 0.3,
		}
	)
	text(
		lv,
		"Value",
		"4",
		24,
		INK,
		{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(lvW / 2 - 2, 20) }
	)
end

-- Coins and settings (top right), the same height as the profile.
local function wallet(c: Instance)
	local right, y, h = 1880, 68, 56
	shadow(c, right - h, y, h, h)
	local settings = make(
		"Frame",
		{
			Name = "Settings",
			Position = UDim2.fromOffset(right - h, y),
			Size = UDim2.fromOffset(h, h),
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
			Size = UDim2.fromOffset(28, 28),
			BackgroundTransparency = 1,
			Image = ICON.Settings,
			ZIndex = 3,
		},
		settings
	)
	local w = 190
	local x = right - h - 8 - w
	shadow(c, x, y, w, h)
	local coins = make(
		"Frame",
		{
			Name = "Coins",
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, h),
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
			Position = UDim2.new(0, 12, 0.5, 0),
			Size = UDim2.fromOffset(28, 28),
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
		20,
		WHITE,
		{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 48, 0.5, 0) }
	)
	keycap(
		coins,
		"+",
		30,
		32,
		{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0) }
	)
end

-- The rail (left edge, vertically centred): square icon buttons with a
-- hotkey keycap in the corner. Hovering one slides its name out beside it.
local function rail(c: Instance, hovered: number?)
	local items = {
		{ "L", "Locker", "LOCKER" },
		{ "B", "Shop", "SHOP" },
		{ "P", "BattlePass", "BATTLE PASS" },
		{ "R", "Range", "RANGE" },
	}
	local x, size, g = 40, 72, 10
	local y0 = 540 - (#items * size + (#items - 1) * g) / 2
	for i, it in items do
		local on = i == hovered
		local y = y0 + (i - 1) * (size + g)
		if on then
			-- the label slides out: a navy plate joined to the button
			local lw = 170
			shadow(c, x + size - 6, y + 14, lw, size - 28)
			local tag = make(
				"Frame",
				{
					Name = it[2] .. "Label",
					Position = UDim2.fromOffset(x + size - 6, y + 14),
					Size = UDim2.fromOffset(lw, size - 28),
					BackgroundColor3 = NAVY_HI,
					BorderSizePixel = 0,
				},
				c
			)
			corner(tag)
			text(
				tag,
				"Label",
				it[3],
				16,
				GOLD,
				{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 20, 0.5, 0) }
			)
		end
		shadow(c, x, y, size, size)
		local b = make(
			"Frame",
			{
				Name = it[2],
				Position = UDim2.fromOffset(x, y),
				Size = UDim2.fromOffset(size, size),
				BackgroundColor3 = if on then NAVY_HI else NAVY,
				BorderSizePixel = 0,
				ZIndex = 2,
			},
			c
		)
		corner(b)
		make(
			"ImageLabel",
			{
				Name = "Icon",
				AnchorPoint = CENTRE,
				Position = UDim2.new(0.5, 4, 0.5, 4),
				Size = UDim2.fromOffset(34, 34),
				BackgroundTransparency = 1,
				Image = ICON[it[2]],
				ImageColor3 = if on then GOLD else WHITE,
				ZIndex = 3,
			},
			b
		)
		keycap(b, it[1], 22, 24, { Position = UDim2.fromOffset(6, 6) })
	end
end

-- The PLAY shortcut (bottom right): a small gold block; the Duels pads in the
-- hub do the same. Hidden while searching (the queue strip takes over).
local function play(c: Instance)
	local right, bottom, w, h = 1880, 1040, 280, 76
	local x, y = right - w, bottom - h
	shadow(c, x + 20, y, w - 40, h)
	local b = make(
		"Frame",
		{
			Name = "Play",
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, h),
			BackgroundTransparency = 1,
		},
		c
	)
	make(
		"Frame",
		{
			Name = "Body",
			Position = UDim2.fromOffset(24, 0),
			Size = UDim2.new(1, -48, 1, 0),
			BackgroundColor3 = GOLD,
			BorderSizePixel = 0,
			ZIndex = 2,
		},
		b
	)
	make(
		"ImageLabel",
		{
			Name = "CapL",
			Size = UDim2.fromOffset(26, h),
			BackgroundTransparency = 1,
			Image = CAP_L,
			ImageColor3 = GOLD,
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
			Size = UDim2.fromOffset(26, h),
			BackgroundTransparency = 1,
			Image = CAP_R,
			ImageColor3 = GOLD,
			ZIndex = 2,
		},
		b
	)
	text(b, "Label", "PLAY", 34, INK, { Position = UDim2.fromOffset(40, 10) })
	text(
		b,
		"Sub",
		"1V1  ·  2V2  ·  3V3",
		11,
		INK,
		{ Position = UDim2.fromOffset(42, 48), TextTransparency = 0.3 }
	)
	keycap(
		b,
		"ENTER",
		62,
		28,
		{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -40, 0.5, 0) }
	)
end

-- While searching: a small queue strip, top centre.
local function queueStrip(c: Instance)
	local w, h = 420, 56
	local x, y = 960 - w / 2, 68
	shadow(c, x, y, w, h)
	local s = make(
		"Frame",
		{
			Name = "Queue",
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, h),
			BackgroundColor3 = NAVY,
			BorderSizePixel = 0,
		},
		c
	)
	corner(s)
	local block = make(
		"Frame",
		{
			Name = "Team",
			Size = UDim2.fromOffset(150, h),
			BackgroundColor3 = ALLY,
			BorderSizePixel = 0,
			ZIndex = 2,
		},
		s
	)
	corner(block)
	make(
		"ImageLabel",
		{
			Name = "Cap",
			Position = UDim2.fromOffset(146, 0),
			Size = UDim2.fromOffset(24, h),
			BackgroundTransparency = 1,
			Image = CAP_R,
			ImageColor3 = ALLY,
			ZIndex = 2,
		},
		s
	)
	text(
		block,
		"Kicker",
		"SEARCHING",
		10,
		INK,
		{ Position = UDim2.fromOffset(16, 9), TextTransparency = 0.25 }
	)
	text(block, "Mode", "2V2", 22, INK, { Position = UDim2.fromOffset(16, 22) })
	text(
		s,
		"Time",
		"0:23",
		24,
		WHITE,
		{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 190, 0.5, 0) }
	)
	text(
		s,
		"Cancel",
		"CANCEL",
		12,
		MUTED,
		{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -66, 0.5, 0) }
	)
	keycap(
		s,
		"ESC",
		44,
		30,
		{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0) }
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
rail(idle, 2)
play(idle)

local searching = canvas(gui, "CanvasSearching")
searching.Visible = false
profile(searching)
wallet(searching)
rail(searching, nil)
queueStrip(searching)

gui.Parent = SG
print("LobbyHudMockup v2 built")
