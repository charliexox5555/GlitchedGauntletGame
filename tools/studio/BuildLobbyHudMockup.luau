--!strict
-- Mockup v5 (v4 with sharp slanted shapes instead of rounded "pills"; owner): the lobby main HUD (vault/02 Art/UI Lobby HUD.md). The owner
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
	make("UICorner", { CornerRadius = UDim.new(0, r or 2) }, p)
end

-- Angled ends on a plate: a slant cap outside each side, in its colour, so the
-- plate reads as a sharp parallelogram (the top bar's slanted cut) not a pill.
local function slant(body: GuiObject, color: Color3, h: number, capW: number, parallel: boolean?)
	-- parallel: both ends lean the same way (a parallelogram tag); otherwise
	-- they mirror (a centred slab, like LOCK IN / PLAY).
	make("ImageLabel", {
		Name = "CapL",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(0, 1, 0, 0),
		Size = UDim2.fromOffset(capW, h),
		BackgroundTransparency = 1,
		Image = if parallel then CAP_R else CAP_L,
		Rotation = if parallel then 180 else 0,
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

-- The player list (top right, owner: "a custom player list... like the
-- leaderboard"): everyone in the lobby with their portrait, name, where they
-- are, and their level on a gold block. Columns can be added later.
local function playerList(c: Instance)
	local right, y, w = 1880, 68, 340
	local x = right - w
	local players = {
		{ "CHARLIE", "IN LOBBY", 4, true },
		{ "BYTE", "IN MATCH", 27, false },
		{ "NOVA", "IN LOBBY", 12, false },
		{ "JINX", "QUEUED  ·  2V2", 9, false },
		{ "RIVET", "IN MATCH", 41, false },
		{ "KAI", "IN LOBBY", 3, false },
	}
	local rowH, gap, headH = 44, 4, 40
	local h = headH + 6 + #players * (rowH + gap) - gap
	shadow(c, x, y, w, h)
	local list = make("Frame", {
		Name = "PlayerList",
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1,
	}, c)
	local head = make("Frame", {
		Name = "Head",
		Size = UDim2.fromOffset(w, headH),
		BackgroundColor3 = NAVY,
		BorderSizePixel = 0,
	}, list)
	corner(head)
	local block = make("Frame", {
		Name = "Team",
		Size = UDim2.fromOffset(130, headH),
		BackgroundColor3 = ALLY,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, head)
	corner(block)
	make("ImageLabel", {
		Name = "Cap",
		Position = UDim2.fromOffset(126, 0),
		Size = UDim2.fromOffset(18, headH),
		BackgroundTransparency = 1,
		Image = CAP_R,
		ImageColor3 = ALLY,
		ZIndex = 2,
	}, head)
	text(
		block,
		"Label",
		"PLAYERS",
		15,
		INK,
		{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0) }
	)
	text(
		head,
		"Count",
		"12 ONLINE",
		11,
		MUTED,
		{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0) }
	)
	for i, pl in players do
		local ry = headH + 6 + (i - 1) * (rowH + gap)
		local mine = pl[4]
		local row = make("Frame", {
			Name = "Row" .. i,
			Position = UDim2.fromOffset(0, ry),
			Size = UDim2.fromOffset(w, rowH),
			BackgroundColor3 = if mine then NAVY_HI else NAVY,
			BorderSizePixel = 0,
		}, list)
		corner(row)
		local cell = make("Frame", {
			Name = "Cell",
			Size = UDim2.fromOffset(rowH, rowH),
			BackgroundColor3 = ALLY_CELL,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, row)
		corner(cell)
		make("ImageLabel", {
			Name = "Headshot",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = "rbxthumb://type=AvatarHeadShot&id=1&w=150&h=150",
			ZIndex = 3,
		}, cell)
		text(
			row,
			"PlayerName",
			pl[1],
			14,
			if mine then ALLY else WHITE,
			{ Position = UDim2.fromOffset(rowH + 12, 6) }
		)
		local where = pl[2]
		text(
			row,
			"Where",
			where,
			10,
			if string.sub(where, 1, 6) == "QUEUED"
				then GOLD
				elseif where == "IN MATCH" then MUTED
				else ALLY,
			{ Position = UDim2.fromOffset(rowH + 12, 25) }
		)
		local lv = make("Frame", {
			Name = "Level",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -18, 0.5, 0),
			Size = UDim2.fromOffset(36, 28),
			BackgroundColor3 = GOLD,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, row)
		slant(lv, GOLD, 28, 10, true)
		text(
			lv,
			"Value",
			tostring(pl[3]),
			14,
			INK,
			{ AnchorPoint = CENTRE, Position = UDim2.fromScale(0.5, 0.5) }
		)
	end
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
-- edge (they break out of it), the name under each, and red
-- badges for what's new. The hovered one lifts and its name turns gold.
local BAR_TOP = 984
local ITEM_W = 140
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
	slant(bar, NAVY, h, 34)
	for i, it in ITEMS do
		local on = i == hovered
		local cx = itemX(i)
		local lift = if on then 10 else 0
		local size = if on then 84 else 74
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
		text(c, it[2] .. "Label", it[3], 14, if on then GOLD else WHITE, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(cx, BAR_TOP + 48),
			ZIndex = 5,
		})
		if it[5] > 0 then
			badge(c, it[5], cx + 32, BAR_TOP - 26 - lift)
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
		text(
			b,
			"Label",
			"SEARCHING",
			24,
			WHITE,
			{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(w / 2, 14) }
		)
		text(
			b,
			"Sub",
			"2V2  ·  0:23  ·  CLICK TO CANCEL",
			12,
			ALLY,
			{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(w / 2, 50) }
		)
	else
		text(
			b,
			"Label",
			"PLAY",
			44,
			INK,
			{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(w / 2, 6) }
		)
		text(b, "Sub", "1V1  ·  2V2  ·  3V3", 11, INK, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(w / 2, 58),
			TextTransparency = 0.3,
		})
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
	slant(p, RED, h, 14, true)
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
	corner(p)
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
tasks(idle)
playerList(idle)
bottomBar(idle, 2)
playCluster(idle, false)
callout(idle)

local searching = canvas(gui, "CanvasSearching")
searching.Visible = false
profile(searching)
tasks(searching)
playerList(searching)
bottomBar(searching, nil)
playCluster(searching, true)

gui.Parent = SG
print("LobbyHudMockup v5 built")
