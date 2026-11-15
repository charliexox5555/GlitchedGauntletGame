--!strict
-- Mockup v3: the lobby main HUD (vault/02 Art/UI Lobby HUD.md). The owner
-- wants it "more like Rivals... bottom bar looking things" (not a copy): a
-- bottom bar of big coloured icons breaking out of its top edge, with names,
-- hotkeys and red badges; PLAY on top of the bar with your party slots; a
-- callout pointing at something new; daily tasks on the left (a proposal:
-- there's no tasks system yet); a compact profile and coins at the top.
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
local RED, PURPLE, TEAL = hex("FF4D5E"), hex("B58CFF"), hex("2BD9A8")
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
	local p = make("Frame", {
		Name = "Profile",
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = NAVY,
		BorderSizePixel = 0,
	}, c)
	corner(p)
	local cell = make("Frame", {
		Name = "Cell",
		Size = UDim2.fromOffset(h, h),
		BackgroundColor3 = ALLY_CELL,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, p)
	corner(cell)
	make("ImageLabel", {
		Name = "Headshot",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = "rbxthumb://type=AvatarHeadShot&id=1&w=150&h=150",
		ZIndex = 3,
	}, cell)
	text(p, "PlayerName", "CHARLIE", 16, WHITE, { Position = UDim2.fromOffset(h + 12, 11) })
	local bar = make("Frame", {
		Name = "Bar",
		Position = UDim2.fromOffset(h + 12, 36),
		Size = UDim2.fromOffset(150, 5),
		BackgroundTransparency = 1,
	}, p)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, bar)
	for i = 1, 10 do
		make("Frame", {
			Name = "Seg" .. i,
			LayoutOrder = i,
			Size = UDim2.fromOffset(13.2, 5),
			BackgroundColor3 = ALLY,
			BackgroundTransparency = if i <= 6 then 0 else 0.82,
			BorderSizePixel = 0,
		}, bar)
	end
	local lvW = 56
	make("ImageLabel", {
		Name = "CapL",
		Position = UDim2.fromOffset(w - lvW - 22, 0),
		Size = UDim2.fromOffset(24, h),
		BackgroundTransparency = 1,
		Image = CAP_L,
		ImageColor3 = GOLD,
		ZIndex = 2,
	}, p)
	local lv = make("Frame", {
		Name = "Level",
		Position = UDim2.fromOffset(w - lvW, 0),
		Size = UDim2.fromOffset(lvW, h),
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, p)
	corner(lv)
	text(lv, "Kicker", "LV", 10, INK, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(lvW / 2 - 2, 8),
		TextTransparency = 0.3,
	})
	text(
		lv,
		"Value",
		"4",
		24,
		INK,
		{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(lvW / 2 - 2, 20) }
	)
end

-- Coins (top right).
local function wallet(c: Instance)
	local right, y, h, w = 1880, 68, 56, 190
	local x = right - w
	shadow(c, x, y, w, h)
	local coins = make("Frame", {
		Name = "Coins",
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = NAVY,
		BorderSizePixel = 0,
	}, c)
	corner(coins)
	make("ImageLabel", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(28, 28),
		BackgroundTransparency = 1,
		Image = ICON.Coin,
		ZIndex = 3,
	}, coins)
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

-- A red count badge (circles are part of the theme).
local function badge(p: Instance, n: number, x: number, y: number)
	local b = make("Frame", {
		Name = "Badge",
		AnchorPoint = CENTRE,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = RED,
		BorderSizePixel = 0,
		ZIndex = 7,
	}, p)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, b)
	text(
		b,
		"N",
		tostring(n),
		14,
		WHITE,
		{ AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.fromScale(1, 1), ZIndex = 8 }
	)
end

-- The bottom bar: a navy plate with big coloured icons sitting on its top
-- edge (they break out of it), the name under each, a hotkey keycap, and red
-- badges for what's new. The hovered one lifts and its name turns gold.
local BAR_TOP = 984
local ITEM_W = 132
local ITEMS = {
	{ "L", "Locker", "LOCKER", ALLY, 2 },
	{ "B", "Shop", "SHOP", GOLD, 0 },
	{ "P", "BattlePass", "PASS", PURPLE, 1 },
	{ "R", "Range", "RANGE", TEAL, 0 },
	{ "O", "Settings", "SETTINGS", WHITE, 0 },
}
local function itemX(i: number): number
	return 960 + (i - (#ITEMS + 1) / 2) * ITEM_W
end
local function bottomBar(c: Instance, hovered: number?)
	local w = #ITEMS * ITEM_W + 40
	local x = 960 - w / 2
	local h = 80
	shadow(c, x, BAR_TOP, w, h)
	local bar = make("Frame", {
		Name = "Bar",
		Position = UDim2.fromOffset(x, BAR_TOP),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = NAVY,
		BorderSizePixel = 0,
	}, c)
	corner(bar, 8)
	for i, it in ITEMS do
		local on = i == hovered
		local cx = itemX(i)
		local lift = if on then 8 else 0
		local size = if on then 76 else 68
		make("ImageLabel", {
			Name = it[2],
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromOffset(cx, BAR_TOP + 40 - lift),
			Size = UDim2.fromOffset(size, size),
			BackgroundTransparency = 1,
			Image = ICON[it[2]],
			ImageColor3 = it[4],
			ZIndex = 5,
		}, c)
		-- the hotkey sits beside the name, under the icon: "[L] LOCKER"
		local row = make("Frame", {
			Name = it[2] .. "Label",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(cx, BAR_TOP + 44),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 24),
			BackgroundTransparency = 1,
			ZIndex = 5,
		}, c)
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, row)
		keycap(row, it[1], 20, 22, { LayoutOrder = 1, ZIndex = 9 })
		text(row, "Label", it[3], 13, if on then GOLD else WHITE, { LayoutOrder = 2, ZIndex = 5 })
		if it[5] > 0 then
			badge(c, it[5], cx + 30, BAR_TOP - 22 - lift)
		end
	end
end

-- PLAY sits on top of the bar, your party slots beside it (you + invite).
local function playCluster(c: Instance, searching: boolean)
	local w, h = 320, 84
	local x, y = 960 - w / 2, BAR_TOP - 44 - h
	shadow(c, x + 20, y, w - 40, h)
	local b = make("Frame", {
		Name = "Play",
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1,
	}, c)
	local fill = if searching then NAVY_HI else GOLD
	make("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(26, 0),
		Size = UDim2.new(1, -52, 1, 0),
		BackgroundColor3 = fill,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, b)
	make("ImageLabel", {
		Name = "CapL",
		Size = UDim2.fromOffset(28, h),
		BackgroundTransparency = 1,
		Image = CAP_L,
		ImageColor3 = fill,
		ZIndex = 2,
	}, b)
	make("ImageLabel", {
		Name = "CapR",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(28, h),
		BackgroundTransparency = 1,
		Image = CAP_R,
		ImageColor3 = fill,
		ZIndex = 2,
	}, b)
	if searching then
		text(b, "Label", "SEARCHING", 22, WHITE, { Position = UDim2.fromOffset(44, 14) })
		text(b, "Sub", "2V2  ·  0:23", 14, ALLY, { Position = UDim2.fromOffset(46, 46) })
		keycap(
			b,
			"ESC",
			46,
			30,
			{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -40, 0.5, 0) }
		)
	else
		text(b, "Label", "PLAY", 40, INK, { Position = UDim2.fromOffset(44, 8) })
		text(
			b,
			"Sub",
			"1V1  ·  2V2  ·  3V3",
			11,
			INK,
			{ Position = UDim2.fromOffset(46, 56), TextTransparency = 0.3 }
		)
		keycap(
			b,
			"ENTER",
			62,
			28,
			{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -40, 0.5, 0) }
		)
	end
	-- party: your portrait and an invite slot, circles with rings
	local px = x + w + 16
	for i = 1, 2 do
		local cx = px + (i - 1) * 66 + 30
		local cy = y + h / 2
		local ring = make("Frame", {
			Name = "PartyRing" .. i,
			AnchorPoint = CENTRE,
			Position = UDim2.fromOffset(cx, cy),
			Size = UDim2.fromOffset(60, 60),
			BackgroundColor3 = if i == 1 then ALLY else NAVY_HI,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, c)
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, ring)
		local disc = make("Frame", {
			Name = "Disc",
			AnchorPoint = CENTRE,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(52, 52),
			BackgroundColor3 = NAVY,
			BorderSizePixel = 0,
			ZIndex = 3,
		}, ring)
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, disc)
		if i == 1 then
			local img = make("ImageLabel", {
				Name = "Headshot",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Image = "rbxthumb://type=AvatarHeadShot&id=1&w=150&h=150",
				ZIndex = 4,
			}, disc)
			make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, img)
		else
			text(
				disc,
				"Plus",
				"+",
				26,
				WHITE,
				{ AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.fromScale(1, 1) }
			)
		end
	end
end

-- A callout pointing at something new (here: the Locker).
local function callout(c: Instance)
	local tx = itemX(1)
	local w, h = 250, 40
	local x, y = tx - w + 60, BAR_TOP - 108
	shadow(c, x, y, w, h)
	local p = make("Frame", {
		Name = "Callout",
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = RED,
		BorderSizePixel = 0,
		ZIndex = 6,
	}, c)
	corner(p)
	text(
		p,
		"Label",
		"NEW SKIN UNLOCKED",
		14,
		WHITE,
		{ AnchorPoint = CENTRE, Position = UDim2.fromScale(0.5, 0.5), ZIndex = 7 }
	)
	-- the pointer: a small square turned 45 degrees, half under the plate
	make("Frame", {
		Name = "Pointer",
		AnchorPoint = CENTRE,
		Position = UDim2.fromOffset(tx, y + h),
		Size = UDim2.fromOffset(16, 16),
		Rotation = 45,
		BackgroundColor3 = RED,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, c)
end

-- Daily tasks (left): a header, three tasks with segmented progress and the
-- coin reward. (Needs a tasks system; shown here as a proposal.)
local function tasks(c: Instance)
	local x, y, w = 40, 380, 400
	local rows = {
		{ "PLAY 5 DUELS", 1, 5, 50 },
		{ "GET 15 ELIMINATIONS", 5, 15, 75 },
		{ "WIN 2 DUELS", 1, 2, 100 },
	}
	local h = 46 + #rows * 62
	shadow(c, x, y, w, h)
	local p = make("Frame", {
		Name = "Tasks",
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = NAVY,
		BorderSizePixel = 0,
	}, c)
	corner(p, 8)
	local head = make("Frame", {
		Name = "Head",
		Size = UDim2.fromOffset(190, 40),
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, p)
	corner(head)
	make("ImageLabel", {
		Name = "Cap",
		Position = UDim2.fromOffset(186, 0),
		Size = UDim2.fromOffset(18, 40),
		BackgroundTransparency = 1,
		Image = CAP_R,
		ImageColor3 = GOLD,
		ZIndex = 2,
	}, p)
	text(
		head,
		"Label",
		"DAILY TASKS",
		16,
		INK,
		{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0) }
	)
	text(
		p,
		"Reset",
		"RESETS IN 6H",
		11,
		MUTED,
		{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0, 20) }
	)
	for i, r in rows do
		local ry = 52 + (i - 1) * 62
		text(p, "Task" .. i, r[1], 15, WHITE, { Position = UDim2.fromOffset(16, ry) })
		text(
			p,
			"Count" .. i,
			string.format("%d / %d", r[2], r[3]),
			13,
			ALLY,
			{ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(w - 96, ry + 2) }
		)
		local bar = make("Frame", {
			Name = "Bar" .. i,
			Position = UDim2.fromOffset(16, ry + 28),
			Size = UDim2.fromOffset(w - 112, 6),
			BackgroundTransparency = 1,
		}, p)
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, bar)
		local segs = math.min(r[3], 15)
		local segW = (w - 112 - (segs - 1) * 2) / segs
		for s = 1, segs do
			make("Frame", {
				Name = "S" .. s,
				LayoutOrder = s,
				Size = UDim2.fromOffset(segW, 6),
				BackgroundColor3 = ALLY,
				BackgroundTransparency = if s <= r[2] * segs / r[3] then 0 else 0.82,
				BorderSizePixel = 0,
			}, bar)
		end
		make("ImageLabel", {
			Name = "Coin" .. i,
			Position = UDim2.fromOffset(w - 80, ry + 6),
			Size = UDim2.fromOffset(24, 24),
			BackgroundTransparency = 1,
			Image = ICON.Coin,
			ZIndex = 3,
		}, p)
		text(
			p,
			"Reward" .. i,
			tostring(r[4]),
			14,
			GOLD,
			{ Position = UDim2.fromOffset(w - 52, ry + 8) }
		)
	end
end

-- gui -----------------------------------------------------------------------------
local old = SG:FindFirstChild("LobbyHudMockup")
if old then
	old:Destroy()
end
local gui = make("ScreenGui", {
	Name = "LobbyHudMockup",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 25,
	Enabled = false,
})

local idle = canvas(gui, "CanvasIdle")
profile(idle)
wallet(idle)
tasks(idle)
bottomBar(idle, 2)
playCluster(idle, false)
callout(idle)

local searching = canvas(gui, "CanvasSearching")
searching.Visible = false
profile(searching)
wallet(searching)
tasks(searching)
bottomBar(searching, nil)
playCluster(searching, true)

gui.Parent = SG
print("LobbyHudMockup v3 built")
