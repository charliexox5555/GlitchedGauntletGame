--!strict
-- Builds the Shop mockup (vault/02 Art/UI Shop.md) in the LOBBY place, Edit mode:
--   StarterGui.Shop         the shop (off; the controller opens it as Router "Shop")
--   StarterGui.LobbyCoins   the coin counter, top middle of the screen (HUD)
-- Re-running replaces both. Placeholder art until the ChatGPT set lands
-- (art-source/ui/shop/); every picture is an ImageLabel named "Art" whose
-- Image gets the uploaded id later.
--
-- v1.1 (owner, 2026-11-16): a flat, bright, no-gradient v2 was tried and
-- rejected ("the bright colours are a bit too much... let's go back... maybe
-- it was just missing the icons"), so this is v1's dark look plus RIVALS-style
-- icon tabs and slanted price plates (no pills).
-- Layout (1920 x 1080 canvas, fitted): no back panel. The world blurs (Router)
-- under a violet-to-navy wash. One ScrollingFrame holds the tab row and the
-- page, so the tabs scroll away with it; the close button and the coin
-- counter stay put (the counter tweens up once you scroll far).
-- Look: the Locker / Play menu language (Builder Extended ExtraBold, dark
-- navy see-through plates, cyan selection, drawn-X close). Prices sit in
-- solid plates: Coins = gold with the coin mark, Robux = green with the Robux
-- mark. Big cards get a selection frame (four corner brackets) on hover.

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
local XB, BOLD = Enum.FontWeight.ExtraBold, Enum.FontWeight.Bold
local CARD = hex("0B1236")
local CARD_T = 0.2
local ALLY, GOLD, GREEN = hex("3FE0F2"), hex("FFC83D"), hex("3FD68A")
local MUTED, INK, WHITE = hex("AEB8D6"), hex("141A26"), Color3.new(1, 1, 1)
local CAP_R = "rbxassetid://130377997107460" -- slant cap (rotated 180 for the left end)
local ROBUX = "rbxasset://textures/ui/common/robux.png"
local CENTRE = Vector2.new(0.5, 0.5)
local W = 1280 -- content width

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
		ZIndex = 5,
	}, p)
	for k, v in props or {} do
		(t :: any)[k] = v
	end
	return t
end
local function corner(p: Instance, r: number?)
	make("UICorner", { CornerRadius = UDim.new(0, r or 8) }, p)
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
local function frame(p: Instance, name: string, props: { [string]: any }): Frame
	local f = make("Frame", { Name = name, BackgroundTransparency = 1, BorderSizePixel = 0 }, p)
	for k, v in props do
		(f :: any)[k] = v
	end
	return f
end

-- Placeholder coin mark (until coin.png): a gold diamond with a darker core.
local function coinMark(p: Instance, d: number, pos: UDim2, anchor: Vector2?): Frame
	local holder = frame(p, "Coin", {
		AnchorPoint = anchor or Vector2.new(0, 0.5),
		Position = pos,
		Size = UDim2.fromOffset(d, d),
		ZIndex = 6,
	})
	make("ImageLabel", {
		Name = "Art",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = "",
		Visible = false,
		ZIndex = 8,
	}, holder)
	local outer = make("Frame", {
		Name = "Outer",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.72, 0.72),
		Rotation = 45,
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
		ZIndex = 6,
	}, holder)
	make("UICorner", { CornerRadius = UDim.new(0.18, 0) }, outer)
	local inner = make("Frame", {
		Name = "Inner",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.42, 0.42),
		Rotation = 45,
		BackgroundColor3 = hex("C98A12"),
		BorderSizePixel = 0,
		ZIndex = 7,
	}, holder)
	make("UICorner", { CornerRadius = UDim.new(0.18, 0) }, inner)
	return holder
end

-- A price plate: Coins (gold) or Robux (green), the mark then the number.
local function price(
	p: Instance,
	kind: "coins" | "robux",
	amount: string,
	pos: UDim2,
	anchor: Vector2,
	h: number?
): Frame
	local ph = h or 44
	local fill = if kind == "coins" then GOLD else GREEN
	local plate = make("Frame", {
		Name = "Price",
		AnchorPoint = anchor,
		Position = pos,
		Size = UDim2.fromOffset(0, ph),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = fill,
		BorderSizePixel = 0,
		ZIndex = 6,
	}, p)
	slant(plate, fill, ph, math.floor(ph * 0.34))
	-- the mark and number sit in their own row so the layout never pulls the
	-- slanted ends (CapL / CapR) in
	local row = make("Frame", {
		Name = "Row",
		Size = UDim2.fromOffset(0, ph),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		ZIndex = 6,
	}, plate)
	make("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 6) }, row)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)
	local iconD = math.floor(ph * 0.58)
	if kind == "coins" then
		local c = coinMark(row, iconD, UDim2.new(), Vector2.zero)
		c.LayoutOrder = 1
		local o = c:WaitForChild("Outer") :: Frame
		o.BackgroundColor3 = INK
		local i = c:WaitForChild("Inner") :: Frame
		i.BackgroundColor3 = GOLD
	else
		make("ImageLabel", {
			Name = "Robux",
			LayoutOrder = 1,
			Size = UDim2.fromOffset(iconD, iconD),
			BackgroundTransparency = 1,
			Image = ROBUX,
			ImageColor3 = INK,
			ZIndex = 7,
		}, row)
	end
	text(
		row,
		"Amount",
		amount,
		math.floor(ph * 0.5),
		INK,
		{ LayoutOrder = 2, Size = UDim2.fromOffset(0, ph), ZIndex = 7 }
	)
	return plate
end

-- The selection frame a big card gets on hover: four thick corner brackets
-- (the controller tweens them in from outside the card). Hidden at rest.
local function selectFrame(card: GuiObject)
	local sel = frame(card, "Select", {
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 9,
	})
	local L, T = 34, 6
	for _, c in { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } do
		local x, y = c[1], c[2]
		local bracket = frame(sel, string.format("C%d%d", x, y), {
			AnchorPoint = Vector2.new(x, y),
			Position = UDim2.new(x, if x == 0 then -10 else 10, y, if y == 0 then -10 else 10),
			Size = UDim2.fromOffset(L, L),
			ZIndex = 9,
		})
		make("Frame", {
			Name = "H",
			AnchorPoint = Vector2.new(x, y),
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromOffset(L, T),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			ZIndex = 9,
		}, bracket)
		make("Frame", {
			Name = "V",
			AnchorPoint = Vector2.new(x, y),
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromOffset(T, L),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			ZIndex = 9,
		}, bracket)
	end
end

-- A card: a dark plate with an Art slot (placeholder colour wash until the
-- art exists), a shade so words read, a title. `big` cards get the
-- selection frame and pop from their centre.
local function card(
	p: Instance,
	name: string,
	size: Vector2,
	tint: Color3,
	title: string?,
	titleSize: number?,
	big: boolean?,
	order: number?
): TextButton
	local holder =
		frame(p, name, { Size = UDim2.fromOffset(size.X, size.Y), LayoutOrder = order or 0 })
	local b = make("TextButton", {
		Name = "Card",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = CARD,
		BackgroundTransparency = CARD_T,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ClipsDescendants = false,
		ZIndex = 2,
	}, holder)
	corner(b)
	make("UIScale", { Name = "Pop" }, b)
	local art = make("ImageLabel", {
		Name = "Art",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = tint,
		BackgroundTransparency = 0.25,
		Image = "",
		ScaleType = Enum.ScaleType.Crop,
		ZIndex = 2,
	}, b)
	corner(art)
	local shade = make("Frame", {
		Name = "Shade",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = hex("060B2A"),
		BorderSizePixel = 0,
		ZIndex = 3,
	}, b)
	corner(shade)
	make("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(0.45, 0.85),
			NumberSequenceKeypoint.new(1, 0.4),
		}),
	}, shade)
	if title then
		text(b, "Title", title, titleSize or 30, WHITE, { Position = UDim2.fromOffset(22, 18) })
	end
	if big then
		selectFrame(b)
	end
	return b
end

-- A section header: the label, and an optional right-hand note.
local function header(p: Instance, label: string, note: string?, order: number): Frame
	local h = frame(p, "Head_" .. label, { Size = UDim2.fromOffset(W, 40), LayoutOrder = order })
	text(h, "Label", label, 26, WHITE, { Size = UDim2.fromOffset(0, 40) })
	if note then
		text(h, "Note", note, 16, MUTED, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(0, 40),
			FontFace = Font.new(BX, BOLD),
		})
	end
	return h
end

local function row(p: Instance, name: string, h: number, gap: number, order: number): Frame
	local r = frame(p, name, { Size = UDim2.fromOffset(W, h), LayoutOrder = order })
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, r)
	return r
end

local function page(p: Instance, name: string, visible: boolean): Frame
	local f = frame(p, name, {
		LayoutOrder = 2,
		Size = UDim2.fromOffset(W, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = visible,
	})
	make("UIListLayout", { Padding = UDim.new(0, 22), SortOrder = Enum.SortOrder.LayoutOrder }, f)
	return f
end

-- A tag chip (MOD, SKIN, CHARM...): a small slanted plate.
local function tag(p: Instance, label: string, color: Color3, pos: UDim2, anchor: Vector2?): Frame
	local c = make("Frame", {
		Name = "Tag",
		AnchorPoint = anchor or Vector2.zero,
		Position = pos,
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 7,
	}, p)
	make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, c)
	slant(c, color, 26, 10)
	text(c, "Label", label, 13, INK, { Size = UDim2.fromOffset(0, 26), ZIndex = 8 })
	return c
end

--------------------------------------------------------------------------------------
-- SHOP
--------------------------------------------------------------------------------------
do
	local old = SG:FindFirstChild("Shop")
	if old then
		old:Destroy()
	end
	local gui = make("ScreenGui", {
		Name = "Shop",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 30,
		Enabled = false,
	})
	-- the coloured wash over the blurred world (owner: "not just a blur")
	local wash = make("Frame", {
		Name = "Wash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ZIndex = 0,
	}, gui)
	make("UIGradient", {
		Rotation = 35,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, hex("3B1D63")),
			ColorSequenceKeypoint.new(0.55, hex("161A44")),
			ColorSequenceKeypoint.new(1, hex("0A1230")),
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

	-- the round close button: a drawn X (Util/CloseButton)
	local close = make("TextButton", {
		Name = "Close",
		AnchorPoint = CENTRE,
		Position = UDim2.fromOffset(1830, 76),
		Size = UDim2.fromOffset(72, 72),
		BackgroundColor3 = CARD,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 20,
	}, canvas)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, close)
	make("UIScale", { Name = "Pop" }, close)
	local glyph = frame(close, "Glyph", {
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(30, 30),
		ZIndex = 21,
	})
	for _, r in { 45, -45 } do
		local bar = make("Frame", {
			Name = if r > 0 then "A" else "B",
			AnchorPoint = CENTRE,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(30, 5),
			Rotation = r,
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			ZIndex = 21,
		}, glyph)
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, bar)
	end

	-- one scrolling page: the tab row, then the open tab's page
	local scroll = make("ScrollingFrame", {
		Name = "Scroll",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(960, 0),
		Size = UDim2.fromOffset(W + 60, 1080),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = WHITE,
		ScrollBarImageTransparency = 0.6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 2,
	}, canvas)
	make("UIPadding", {
		PaddingTop = UDim.new(0, 150),
		PaddingBottom = UDim.new(0, 80),
		PaddingLeft = UDim.new(0, 30),
	}, scroll)
	make(
		"UIListLayout",
		{ Padding = UDim.new(0, 30), SortOrder = Enum.SortOrder.LayoutOrder },
		scroll
	)

	-- tabs (RIVALS-style): a plate per tab with a big icon popping out over
	-- its top and the name across the bottom; the open tab is white. Until
	-- the ChatGPT tab icons land, the lobby bar's icons stand in.
	local TAB_ICON = {
		HOME = "rbxassetid://75746609493674", -- (Shop bag) -> shop/tab_home.png
		BUNDLES = "rbxassetid://94062620763078", -- (Locker) -> shop/tab_bundles.png
		DAILY = "rbxassetid://124123984170556", -- (Pass) -> shop/tab_daily.png
		COINS = "rbxassetid://79251886607751", -- (Range) -> shop/tab_coins.png
	}
	local tabs = row(scroll, "Tabs", 100, 16, 1)
	for i, t in { "HOME", "BUNDLES", "DAILY", "COINS" } do
		local on = i == 1
		local holder = frame(tabs, t, { LayoutOrder = i, Size = UDim2.fromOffset(196, 100) })
		local b = make("TextButton", {
			Name = "Plate",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromOffset(196, 58),
			BackgroundColor3 = if on then WHITE else CARD,
			BackgroundTransparency = if on then 0 else CARD_T,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 3,
		}, holder)
		corner(b)
		make("UIScale", { Name = "Pop" }, b)
		make("ImageLabel", {
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 0, 28),
			Size = UDim2.fromOffset(78, 78),
			BackgroundTransparency = 1,
			Image = TAB_ICON[t],
			ZIndex = 6,
		}, b)
		text(b, "Label", t, 22, if on then INK else WHITE, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -7),
			ZIndex = 7,
		})
	end

	---------------------------------------------------------------- HOME
	local home = page(scroll, "Home", true)
	header(home, "CASES", nil, 1)
	local top = row(home, "Top", 360, 24, 2)
	local cases = frame(top, "Cases", { Size = UDim2.fromOffset(512, 360), LayoutOrder = 1 })
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 16),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, cases)
	for i, c in
		{
			{ "Standard", "STANDARD", hex("5D6B82"), "400" },
			{ "Elite", "ELITE", hex("6A3FC2"), "900" },
			{ "Apex", "APEX", hex("C2412F"), "2,000" },
		}
	do
		local b = card(cases, "Case_" .. c[1], Vector2.new(160, 360), c[3], nil, nil, true, i)
		-- placeholder case: a chamfered slab
		local slab = make("Frame", {
			Name = "Placeholder",
			AnchorPoint = CENTRE,
			Position = UDim2.new(0.5, 0, 0, 120),
			Size = UDim2.fromOffset(124, 70),
			BackgroundColor3 = c[3],
			BorderSizePixel = 0,
			ZIndex = 4,
		}, b)
		corner(slab, 10)
		make("Frame", {
			Name = "Lid",
			Position = UDim2.fromOffset(10, 14),
			Size = UDim2.new(1, -20, 0, 8),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.6,
			BorderSizePixel = 0,
			ZIndex = 5,
		}, slab)
		text(
			b,
			"Name",
			c[2],
			18,
			WHITE,
			{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 200) }
		)
		text(b, "Kind", "CASE", 13, MUTED, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 226),
			FontFace = Font.new(BX, BOLD),
		})
		price(b, "coins", c[4], UDim2.new(0.5, 0, 1, -18), Vector2.new(0.5, 1), 42)
	end
	local pass = card(
		top,
		"SeasonPass",
		Vector2.new(W - 512 - 24, 360),
		hex("2B3FB0"),
		"SEASON PASS",
		44,
		true,
		2
	)
	text(
		pass,
		"Sub",
		"SEASON 1  ·  TIER 1 / 30",
		18,
		ALLY,
		{ Position = UDim2.fromOffset(24, 74), FontFace = Font.new(BX, BOLD) }
	)
	local view = make("TextButton", {
		Name = "View",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -22, 1, -22),
		Size = UDim2.fromOffset(180, 60),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 6,
	}, pass)
	corner(view, 6)
	text(
		view,
		"Label",
		"VIEW  »",
		22,
		INK,
		{ AnchorPoint = CENTRE, Position = UDim2.fromScale(0.5, 0.5), ZIndex = 7 }
	)
	-- the pass card's selection frame is shown on the mockup to preview it
	local sel = pass:WaitForChild("Select") :: Frame
	sel.Visible = true

	header(home, "SPECIAL OFFERS", nil, 3)
	local mid = row(home, "Mid", 330, 24, 4)
	local offer =
		card(mid, "Offer", Vector2.new(760, 330), hex("1F9A6A"), "STARTER BUNDLE", 40, true, 1)
	text(offer, "Sub", "A CASE, 500 COINS AND A CHARM", 16, WHITE, {
		Position = UDim2.fromOffset(24, 70),
		TextTransparency = 0.2,
		FontFace = Font.new(BX, BOLD),
	})
	price(offer, "robux", "99", UDim2.new(1, -22, 1, -22), Vector2.new(1, 1), 56)
	local dots = frame(offer, "Dots", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 24, 1, -30),
		Size = UDim2.fromOffset(120, 12),
		ZIndex = 6,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, dots)
	for i = 1, 4 do
		local d = make("Frame", {
			Name = "Dot" .. i,
			LayoutOrder = i,
			Size = UDim2.fromOffset(if i == 1 then 12 else 8, if i == 1 then 12 else 8),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = if i == 1 then 0 else 0.5,
			BorderSizePixel = 0,
			ZIndex = 6,
		}, dots)
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, d)
	end
	local cos =
		frame(mid, "Cosmetics", { Size = UDim2.fromOffset(W - 760 - 24, 330), LayoutOrder = 2 })
	make("UIGridLayout", {
		CellSize = UDim2.fromOffset(154, 157),
		CellPadding = UDim2.fromOffset(15, 16),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, cos)
	for i, c in
		{
			{ "Charm_1", "CHARM", hex("B58CFF"), "250" },
			{ "Charm_2", "CHARM", hex("3FE0F2"), "250" },
			{ "Emote_1", "EMOTE", hex("FF7AD9"), "400" },
			{ "Charm_3", "CHARM", hex("FF7A3D"), "250" },
			{ "Emote_2", "EMOTE", hex("3FD68A"), "400" },
			{ "Emote_3", "EMOTE", hex("E8C46A"), "600" },
		}
	do
		local b = card(cos, c[1], Vector2.new(154, 157), c[3], nil, nil, false, i)
		tag(b, c[2], WHITE, UDim2.fromOffset(14, 12))
		price(b, "coins", c[4], UDim2.new(0.5, 0, 1, -12), Vector2.new(0.5, 1), 34)
	end

	---------------------------------------------------------------- BUNDLES
	local bundles = page(scroll, "Bundles", false)
	header(bundles, "BUNDLES", nil, 1)
	local b1 = row(bundles, "Row1", 280, 24, 2)
	local bw3 = (W - 48) / 3
	for i, c in
		{
			{ "Neon", "NEON BUNDLE", hex("2B6FE0"), "975", true },
			{ "Ember", "EMBER BUNDLE", hex("C2412F"), "649", false },
			{ "Frost", "FROST BUNDLE", hex("2BB7D9"), "289", false },
		}
	do
		local b = card(b1, "Bundle_" .. c[1], Vector2.new(bw3, 280), c[3], c[2], 30, true, i)
		price(b, "robux", c[4], UDim2.new(1, -20, 1, -20), Vector2.new(1, 1), 54)
		if c[5] then
			tag(b, "EXCLUSIVE MOD", GOLD, UDim2.fromOffset(22, 66))
		end
	end
	local b2 = row(bundles, "Row2", 280, 24, 3)
	local bw2 = (W - 24) / 2
	for i, c in
		{
			{ "Heavy", "HEAVY DUTY BUNDLE", hex("C9822B"), "1,425" },
			{ "Classic", "CLASSIC BUNDLE", hex("6A3FC2"), "865" },
		}
	do
		local b = card(b2, "Bundle_" .. c[1], Vector2.new(bw2, 280), c[3], c[2], 30, true, i)
		price(b, "robux", c[4], UDim2.new(1, -20, 1, -20), Vector2.new(1, 1), 54)
	end
	-- the contents layout a bundle shows on hover (mockup: shown on Neon)
	local neon = b1:WaitForChild("Bundle_Neon"):WaitForChild("Card") :: TextButton
	local contents = frame(neon, "Contents", {
		Position = UDim2.fromOffset(22, 104),
		Size = UDim2.fromOffset(bw3 - 44, 92),
		ZIndex = 6,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, contents)
	for i, c in
		{
			{ "SKIN", hex("2B6FE0") },
			{ "SKIN", hex("3FE0F2") },
			{ "MOD", GOLD },
			{ "CHARM", hex("B58CFF") },
		}
	do
		local cell = make("Frame", {
			Name = "Item" .. i,
			LayoutOrder = i,
			Size = UDim2.fromOffset(84, 84),
			BackgroundColor3 = c[2],
			BackgroundTransparency = 0.15,
			BorderSizePixel = 0,
			ZIndex = 6,
		}, contents)
		corner(cell, 6)
		text(cell, "Kind", c[1], 12, INK, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -6),
			ZIndex = 7,
		})
	end
	(neon:WaitForChild("Select") :: Frame).Visible = true

	---------------------------------------------------------------- DAILY
	local daily = page(scroll, "Daily", false)
	header(daily, "TODAY'S ITEMS", "NEW ITEMS IN 5H 12M", 1)
	local grid =
		frame(daily, "Items", { Size = UDim2.fromOffset(W, 2 * 230 + 16), LayoutOrder = 2 })
	make("UIGridLayout", {
		CellSize = UDim2.fromOffset((W - 48) / 4, 230),
		CellPadding = UDim2.fromOffset(16, 16),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	local kinds = {
		{ "SKIN", hex("2B6FE0"), "1,200" },
		{ "SKIN", hex("C2412F"), "900" },
		{ "SKIN", hex("6A3FC2"), "1,200" },
		{ "CHARM", hex("B58CFF"), "250" },
		{ "CHARM", hex("3FE0F2"), "250" },
		{ "EMOTE", hex("FF7AD9"), "400" },
		{ "EMOTE", hex("3FD68A"), "400" },
		{ "CHARM", hex("E8C46A"), "300" },
	}
	for i, k in kinds do
		local b = card(grid, "Item" .. i, Vector2.new((W - 48) / 4, 230), k[2], nil, nil, false, i)
		tag(b, k[1], WHITE, UDim2.fromOffset(16, 14))
		text(b, "Name", "ITEM NAME", 18, WHITE, { Position = UDim2.new(0, 18, 1, -78) })
		price(b, "coins", k[3], UDim2.new(1, -16, 1, -16), Vector2.new(1, 1), 40)
	end
	header(daily, "LOGIN REWARDS", "DAY 4 OF 7", 3)
	local login = row(daily, "Login", 380, 16, 4)
	local days =
		frame(login, "Days", { Size = UDim2.fromOffset(W - 380 - 16, 380), LayoutOrder = 1 })
	make("UIGridLayout", {
		CellSize = UDim2.fromOffset((W - 380 - 16 - 32) / 3, 182),
		CellPadding = UDim2.fromOffset(16, 16),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, days)
	for d = 1, 6 do
		local claimed, today = d <= 3, d == 4
		local cell = make("Frame", {
			Name = "Day" .. d,
			LayoutOrder = d,
			BackgroundColor3 = if claimed then hex("1C6B4A") elseif today then WHITE else CARD,
			BackgroundTransparency = if today then 0 else CARD_T,
			BorderSizePixel = 0,
			ZIndex = 3,
		}, days)
		corner(cell)
		text(cell, "Day", "DAY " .. d, 24, if today then INK else WHITE, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 16),
		})
		coinMark(cell, 56, UDim2.fromScale(0.5, 0.55), CENTRE)
		text(
			cell,
			"Amount",
			if claimed then "CLAIMED" elseif today then "CLAIM" else string.format("x%d", d * 50),
			18,
			if claimed then GREEN elseif today then INK else WHITE,
			{
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -14),
			}
		)
	end
	local grand = make("Frame", {
		Name = "Day7",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(380, 380),
		BackgroundColor3 = CARD,
		BackgroundTransparency = CARD_T,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, login)
	corner(grand)
	text(
		grand,
		"Day",
		"DAY 7",
		44,
		WHITE,
		{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 26) }
	)
	coinMark(grand, 140, UDim2.fromScale(0.5, 0.52), CENTRE)
	text(
		grand,
		"Prize",
		"GRAND PRIZE",
		26,
		GOLD,
		{ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -28) }
	)

	---------------------------------------------------------------- COINS
	local coins = page(scroll, "Coins", false)
	header(coins, "COINS", nil, 1)
	local cgrid =
		frame(coins, "Packs", { Size = UDim2.fromOffset(W, 2 * 280 + 24), LayoutOrder = 2 })
	make("UIGridLayout", {
		CellSize = UDim2.fromOffset(bw3, 280),
		CellPadding = UDim2.fromOffset(24, 24),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, cgrid)
	for i, c in
		{
			{ "500", "59" },
			{ "1,100", "119" },
			{ "2,400", "249" },
			{ "5,000", "499" },
			{ "11,000", "999" },
			{ "24,000", "1,999" },
		}
	do
		local b = card(cgrid, "Pack" .. i, Vector2.new(bw3, 280), hex("B8860B"), nil, nil, true, i)
		coinMark(b, 30 + i * 12, UDim2.new(0, 22, 0, 60), Vector2.new(0, 0.5))
		text(
			b,
			"Amount",
			"+" .. c[1],
			44,
			WHITE,
			{ Position = UDim2.fromOffset(40 + 30 + i * 12, 34) }
		)
		text(
			b,
			"Kind",
			"COINS",
			16,
			GOLD,
			{ Position = UDim2.fromOffset(42 + 30 + i * 12, 86), FontFace = Font.new(BX, BOLD) }
		)
		price(b, "robux", c[2], UDim2.new(1, -20, 1, -20), Vector2.new(1, 1), 54)
	end

	gui.Parent = SG
end

--------------------------------------------------------------------------------------
-- COIN COUNTER (HUD, top middle; also over the shop)
--------------------------------------------------------------------------------------
do
	local old = SG:FindFirstChild("LobbyCoins")
	if old then
		old:Destroy()
	end
	local gui = make("ScreenGui", {
		Name = "LobbyCoins",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 31, -- over the shop (30), under MATCH FOUND (40)
		Enabled = false, -- on once the Coins economy is wired (no fake balance)
	})
	local top = frame(gui, "Top", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(260, 52),
	})
	make("UIScale", { Name = "Fit" }, top)
	local bar = make("Frame", {
		Name = "Bar",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 46),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = CARD,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}, top)
	corner(bar, 8)
	make("UIScale", { Name = "Pop" }, bar)
	make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 6) }, bar)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, bar)
	local c = coinMark(bar, 40, UDim2.new(), Vector2.zero)
	c.LayoutOrder = 1
	text(bar, "Amount", "1,250", 26, WHITE, { LayoutOrder = 2, Size = UDim2.fromOffset(0, 46) })
	local plus = make("TextButton", {
		Name = "Plus",
		LayoutOrder = 3,
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 5,
	}, bar)
	corner(plus, 6)
	make("UIScale", { Name = "Pop" }, plus)
	for _, r in { 0, 90 } do
		local barP = make("Frame", {
			Name = if r == 0 then "H" else "V",
			AnchorPoint = CENTRE,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(18, 5),
			Rotation = r,
			BackgroundColor3 = INK,
			BorderSizePixel = 0,
			ZIndex = 6,
		}, plus)
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, barP)
	end
	gui.Parent = SG
end

print("[BuildShop] StarterGui.Shop (mockup) and StarterGui.LobbyCoins built")
