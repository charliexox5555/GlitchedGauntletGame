--!strict
-- Locker v2 MOCKUP (vault/01 Design/Loadout and Power Deck.md → "Locker design from the RIVALS study").
-- Run in the place's Edit mode (Studio command bar or MCP execute_luau). Builds StarterGui.LockerV2: a static
-- layout for the owner to review and edit in Studio, no code wired yet. Re-running replaces it.
--
-- Three states, switched by hand in Explorer (only one Right.* and one Left.* visible at a time):
--   gun, owned   Left.Guns   + Center.Gun   + Right.GunOwned
--   gun, locked  Left.Guns   + Center.Gun   + Right.GunLocked (and Center.Lock)
--   power        Left.Powers + Center.Power + Right.Power
-- The workspace attribute LockerV2State ("owned" | "locked" | "power") is what this script shows on build.
--
-- Style (gauntlet-ui-style, the approved Backpack / Shop look): dark plates (radius 8), white Rubik Heavy
-- words, one gold act-now button per state with slant caps, cyan for "yours", no pills, outlines or glow.
-- Art is ours only: gun side renders (Config/Theme.GUN), power card art and icons (Theme.CARD_ART,
-- Config/Mods). In game the middle is the 3D Locker stage; Backdrop stands in for it here.

local SG = game:GetService("StarterGui")
local RS = game:GetService("ReplicatedStorage")

local Theme = require(RS.Shared.Config.Theme)
local ModsConfig = require(RS.Shared.Config.Mods)

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

local HEAVY = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy)
local BOLD = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold)
local WHITE = Color3.new(1, 1, 1)
local INK = hex("0F0F12")
local PANEL = hex("111114")
local NAVY = hex("1A1A1E")
local NAVY_HI = hex("2A2A2F")
local MUTED = hex("9F9FA2")
local DIM = hex("6A6A6E")
local GOLD = hex("FFC83D")
local ALLY = hex("3FE0F2")
local GLITCH = ModsConfig.COLORS.glitch
local CAP_R = "rbxassetid://130377997107460" -- the slant cap (Backpack / Shop buttons)
local COIN = "rbxassetid://122645025340088"
local LOCK = Theme.ICON.Lock
local CENTRE = Vector2.new(0.5, 0.5)

local COL_W = 460 -- each side column (design px, 1920 x 1080)
local LEFT_X, RIGHT_X, TOP_Y = 48, 1920 - 48 - 460, 128

local function corner(p: Instance, r: number?)
	make("UICorner", { CornerRadius = UDim.new(0, r or 8) }, p)
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
		FontFace = HEAVY,
		TextSize = size,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 5,
	}, p)
	for k, v in props or {} do
		(l :: any)[k] = v
	end
	return l
end
local function box(
	p: Instance,
	name: string,
	x: number,
	y: number,
	w: number,
	h: number,
	color: Color3,
	props: { [string]: any }?
): Frame
	local f = make("Frame", {
		Name = name,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, p)
	for k, v in props or {} do
		(f :: any)[k] = v
	end
	return f
end
local function image(
	p: Instance,
	name: string,
	img: string,
	x: number,
	y: number,
	w: number,
	h: number,
	props: { [string]: any }?
): ImageLabel
	local i = make("ImageLabel", {
		Name = name,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1,
		Image = img,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 4,
	}, p)
	for k, v in props or {} do
		(i :: any)[k] = v
	end
	return i
end
-- A plate button with slanted ends (the lobby's button shape). `gold` = the one act-now thing.
local function button(
	p: Instance,
	name: string,
	label: string,
	x: number,
	y: number,
	w: number,
	h: number,
	gold: boolean
): TextButton
	local fill = if gold then GOLD else NAVY_HI
	local b = make("TextButton", {
		Name = name,
		Position = UDim2.fromOffset(x + 18, y),
		Size = UDim2.fromOffset(w - 36, h),
		BackgroundColor3 = fill,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 4,
	}, p)
	for _, cap in
		{
			{ "CapL", 180, UDim2.new(0, 1, 0, 0), Vector2.new(1, 0) },
			{ "CapR", 0, UDim2.new(1, -1, 0, 0), Vector2.new(0, 0) },
		}
	do
		make("ImageLabel", {
			Name = cap[1],
			AnchorPoint = cap[4],
			Position = cap[3],
			Size = UDim2.fromOffset(18, h),
			BackgroundTransparency = 1,
			Image = CAP_R,
			Rotation = cap[2],
			ImageColor3 = fill,
			ZIndex = 4,
		}, b)
	end
	if label == "" then
		return b -- the caller draws its own words
	end
	text(b, "Label", label, math.floor(h * 0.42), if gold then INK else WHITE, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 6,
	})
	return b
end
-- A short tag in a colour (role, EQUIPPED, ...): a small dark plate, coloured words.
-- Sized to its words (AutomaticSize), so long tags never clip.
local function tag(p: Instance, name: string, t: string, x: number, y: number, color: Color3): Frame
	local f =
		box(p, name, x, y, 0, 26, NAVY_HI, { ZIndex = 4, AutomaticSize = Enum.AutomaticSize.X })
	corner(f, 4)
	make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, f)
	text(f, "Label", t, 14, color, {
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = BOLD,
		ZIndex = 5,
	})
	return f
end
-- a tag pinned to the right edge of its parent
local function tagRight(
	p: Instance,
	name: string,
	t: string,
	inset: number,
	y: number,
	color: Color3
)
	local f = tag(p, name, t, 0, y, color)
	f.AnchorPoint = Vector2.new(1, 0)
	f.Position = UDim2.new(1, -inset, 0, y)
end
local function coinPrice(p: Instance, amount: string, x: number, y: number, color: Color3)
	image(p, "Coin", COIN, x, y, 24, 24, { ZIndex = 6 })
	text(
		p,
		"Price",
		amount,
		20,
		color,
		{ Position = UDim2.fromOffset(x + 30, y), Size = UDim2.fromOffset(120, 24), ZIndex = 6 }
	)
end
local function header(p: Instance, t: string, right: string?, y: number)
	text(
		p,
		"Header_" .. t,
		t,
		15,
		MUTED,
		{ Position = UDim2.fromOffset(20, y), Size = UDim2.fromOffset(240, 20), FontFace = BOLD }
	)
	if right then
		text(p, "Count_" .. t, right, 15, DIM, {
			Position = UDim2.fromOffset(COL_W - 220, y),
			Size = UDim2.fromOffset(200, 20),
			FontFace = BOLD,
			TextXAlignment = Enum.TextXAlignment.Right,
		})
	end
end
local function card(p: Instance, name: string, y: number, h: number): Frame
	local f = box(p, name, 0, y, COL_W, h, PANEL, { BackgroundTransparency = 0.08 })
	corner(f)
	return f
end

------------------------------------------------------------------------------
-- The screen

local old = SG:FindFirstChild("LockerV2")
if old then
	old:Destroy()
end
local gui = make("ScreenGui", {
	Name = "LockerV2",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ScreenInsets = Enum.ScreenInsets.None,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 30,
	-- off, so a published place never shows the mockup; tick Enabled in Studio to look at it
	Enabled = false,
})
gui:SetAttribute(
	"Mockup",
	"Locker v2 layout for review (tools/studio/BuildLockerV2.luau); not wired to code yet"
)
-- stand-in for the 3D Locker stage
local backdrop = make("Frame", {
	Name = "Backdrop",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = hex("1B1D24"),
	BorderSizePixel = 0,
	ZIndex = 0,
}, gui)
make("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, hex("23262F")),
		ColorSequenceKeypoint.new(0.6, hex("15171C")),
		ColorSequenceKeypoint.new(1, hex("0C0D10")),
	}),
}, backdrop)

local canvas = make("Frame", {
	Name = "Canvas",
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(1920, 1080),
	BackgroundTransparency = 1,
	ZIndex = 1,
}, gui)
local cam = workspace.CurrentCamera
local view = if cam then cam.ViewportSize else Vector2.new(1920, 1080)
make("UIScale", { Name = "Fit", Scale = math.min(view.X / 1920, view.Y / 1080) }, canvas)

-- Top: title, tabs, coins ----------------------------------------------------------------
text(
	canvas,
	"Title",
	"LOCKER",
	44,
	WHITE,
	{ Position = UDim2.fromOffset(LEFT_X, 40), Size = UDim2.fromOffset(220, 52) }
)
local tabs = box(canvas, "Tabs", LEFT_X + 230, 44, 600, 48, WHITE, { BackgroundTransparency = 1 })
local tabParts: { [string]: { plate: TextButton, label: TextLabel } } = {}
for i, t in { "GUNS", "POWERS", "KNIFE" } do
	local b = make("TextButton", {
		Name = t,
		Position = UDim2.fromOffset((i - 1) * 170, 0),
		Size = UDim2.fromOffset(160, 48),
		BackgroundColor3 = if i == 1 then WHITE else NAVY,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 3,
	}, tabs)
	corner(b, 6)
	local l = text(
		b,
		"Label",
		t,
		20,
		if i == 1 then INK else MUTED,
		{ Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center }
	)
	tabParts[t] = { plate = b, label = l }
end
local coins = box(canvas, "Coins", 1920 - 48 - 200, 46, 200, 44, NAVY)
corner(coins, 6)
image(coins, "Icon", COIN, 12, 8, 28, 28)
text(
	coins,
	"Amount",
	"1,250",
	24,
	WHITE,
	{ Position = UDim2.fromOffset(48, 0), Size = UDim2.fromOffset(140, 44) }
)

-- Left: GUNS -------------------------------------------------------------------------------
local left = box(canvas, "Left", LEFT_X, TOP_Y, COL_W, 900, PANEL, { BackgroundTransparency = 1 })
local guns = box(left, "Guns", 0, 0, COL_W, 900, PANEL, { BackgroundTransparency = 1 })

-- the loadout you take into a match
local loadout = card(guns, "Loadout", 0, 176)
header(loadout, "LOADOUT", nil, 14)
for i, slot in { { "PRIMARY", "Vandal", "HAVOC" }, { "SECONDARY", "Classic", "CLASSIC" } } do
	local s = box(loadout, slot[1], 16 + (i - 1) * 218, 44, 210, 116, NAVY)
	corner(s, 6)
	text(
		s,
		"Slot",
		slot[1],
		13,
		MUTED,
		{ Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(180, 16), FontFace = BOLD }
	)
	image(s, "Gun", Theme.GUN[slot[2]], 14, 28, 182, 56)
	text(
		s,
		"Name",
		slot[3],
		20,
		WHITE,
		{ Position = UDim2.fromOffset(12, 86), Size = UDim2.fromOffset(186, 24) }
	)
end

-- one class list: header, then a row per gun
local function gunList(p: Instance, name: string, y: number, rows: { { any } }): number
	local list = card(p, name, y, 44 + #rows * 72)
	header(
		list,
		string.upper(name),
		string.format(
			"%d / %d UNLOCKED",
			(function()
				local n = 0
				for _, r in rows do
					if not r[4] then
						n += 1
					end
				end
				return n
			end)(),
			#rows
		),
		14
	)
	for i, r in rows do
		local id, label, level, locked, state = r[1], r[2], r[3], r[4], r[5]
		local row = box(
			list,
			"Row_" .. label,
			12,
			40 + (i - 1) * 72,
			COL_W - 24,
			64,
			if state == "selected" then NAVY_HI else NAVY
		)
		corner(row, 6)
		image(
			row,
			"Gun",
			Theme.GUN[id] or "",
			10,
			6,
			132,
			52,
			{ ImageTransparency = if locked then 0.55 else 0 }
		)
		text(
			row,
			"Name",
			label,
			22,
			if locked then DIM else WHITE,
			{ Position = UDim2.fromOffset(154, 0), Size = UDim2.fromOffset(170, 64) }
		)
		if locked then
			coinPrice(row, locked, COL_W - 24 - 120, 20, MUTED)
		else
			text(row, "Level", "LV " .. level, 18, MUTED, {
				Position = UDim2.fromOffset(COL_W - 24 - 90, 0),
				Size = UDim2.fromOffset(76, 64),
				TextXAlignment = Enum.TextXAlignment.Right,
			})
			if state == "equipped" or state == "selected" then
				tagRight(row, "Equipped", "EQUIPPED", 100, 19, ALLY)
			end
		end
	end
	return y + 44 + #rows * 72 + 12
end
local secondaryY = gunList(guns, "Primary", 188, {
	{ "Vandal", "HAVOC", 12, nil, "selected" },
	{ "Spectre", "PROWLER", 5 },
	{ "Bucky", "PUMP", 3 },
	{ "Bulldog", "LANCER", nil, "750" },
	{ "Guardian", "MARKSMAN", nil, "900" },
	{ "Operator", "DEADEYE", nil, "1,500" },
})
gunList(guns, "Secondary", secondaryY, {
	{ "Classic", "CLASSIC", 8, nil, "equipped" },
	{ "Sheriff", "SHERIFF", 2 },
	{ "Shorty", "SHORTY", nil, "400" },
})

-- Left: POWERS (deck on top, then every power) ---------------------------------------------
local powers =
	box(left, "Powers", 0, 0, COL_W, 900, PANEL, { BackgroundTransparency = 1, Visible = false })
local deck = card(powers, "Deck", 0, 244)
header(deck, "YOUR DECK", "4 / 10", 14)
local inDeck = { "Dash", "Updraft", "Molly", "Frost" }
for i = 1, 10 do
	local col, rowN = (i - 1) % 5, math.floor((i - 1) / 5)
	local id = inDeck[i]
	local cell =
		box(deck, "Slot" .. i, 16 + col * 87, 44 + rowN * 96, 80, 88, if id then NAVY_HI else NAVY)
	corner(cell, 6)
	if id then
		local def = ModsConfig.defs[id]
		image(cell, "Icon", def.icon or "", 12, 8, 56, 56)
		text(cell, "Name", string.upper(def.name), 12, WHITE, {
			Position = UDim2.fromOffset(0, 66),
			Size = UDim2.fromOffset(80, 16),
			TextXAlignment = Enum.TextXAlignment.Center,
			FontFace = BOLD,
		})
	else
		text(
			cell,
			"Empty",
			"+",
			30,
			DIM,
			{ Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center }
		)
	end
end
local all = card(powers, "All", 256, 640)
header(all, "ALL POWERS", "4 / 12 OWNED", 14)
for i, id in { "Dash", "Updraft", "Molly", "Frost", "Firewall", "Recon", "Stim", "Flash" } do
	local def = ModsConfig.defs[id]
	local owned = i <= 4
	local row = box(
		all,
		"Row_" .. id,
		12,
		40 + (i - 1) * 72,
		COL_W - 24,
		64,
		if i == 1 then NAVY_HI else NAVY
	)
	corner(row, 6)
	image(
		row,
		"Icon",
		def.icon or "",
		10,
		6,
		52,
		52,
		{ ImageTransparency = if owned then 0 else 0.55 }
	)
	text(
		row,
		"Name",
		string.upper(def.name),
		22,
		if owned then WHITE else DIM,
		{ Position = UDim2.fromOffset(76, 0), Size = UDim2.fromOffset(180, 64) }
	)
	local roleColor = Theme.ROLE[def.role] or ALLY
	if owned then
		tagRight(row, "Role", string.upper(def.role), 14, 19, roleColor)
	else
		text(row, "From", "POWER CASE", 15, MUTED, {
			Position = UDim2.fromOffset(COL_W - 24 - 120, 0),
			Size = UDim2.fromOffset(110, 64),
			FontFace = BOLD,
		})
	end
end

-- Center: the stage ---------------------------------------------------------------------------
local center = box(canvas, "Center", 540, TOP_Y, 840, 820, PANEL, { BackgroundTransparency = 1 })
local gunStage = box(center, "Gun", 0, 0, 840, 820, PANEL, { BackgroundTransparency = 1 })
local shadow = box(
	gunStage,
	"FloorShadow",
	170,
	560,
	500,
	46,
	hex("000000"),
	{ BackgroundTransparency = 0.55, ZIndex = 1 }
)
corner(shadow, 23)
local render = image(gunStage, "Render", Theme.GUN.Vandal, 40, 180, 760, 380, { ZIndex = 3 })
local lockStage =
	box(center, "Lock", 0, 0, 840, 820, PANEL, { BackgroundTransparency = 1, Visible = false })
local lockPlate = box(
	lockStage,
	"Plate",
	340,
	290,
	160,
	160,
	hex("0B0B0D"),
	{ BackgroundTransparency = 0.15, ZIndex = 6 }
)
corner(lockPlate, 8)
image(lockPlate, "Icon", LOCK, 8, 8, 144, 144, { ZIndex = 7 })
local powerStage =
	box(center, "Power", 0, 0, 840, 820, PANEL, { BackgroundTransparency = 1, Visible = false })
image(powerStage, "Card", Theme.CARD_ART.Dash, 230, 120, 380, 300, { ZIndex = 3 })
image(powerStage, "Icon", ModsConfig.defs.Dash.icon or "", 360, 450, 120, 120, { ZIndex = 3 })

-- bottom of the stage: the act-now button for the state
local bottom = box(canvas, "Bottom", 540, 960, 840, 72, PANEL, { BackgroundTransparency = 1 })
local skinBtn = button(bottom, "Skin", "SKINS", 180, 4, 220, 64, false)
local equipBtn = button(bottom, "Equip", "EQUIP", 430, 4, 230, 64, true)

-- Right: one card stack per state ---------------------------------------------------------------
local right =
	box(canvas, "Right", RIGHT_X, TOP_Y, COL_W, 900, PANEL, { BackgroundTransparency = 1 })

local function details(p: Instance, name: string, role: string, roleColor: Color3, line: string)
	local d = card(p, "Details", 0, 158)
	text(
		d,
		"Name",
		name,
		52,
		WHITE,
		{ Position = UDim2.fromOffset(20, 14), Size = UDim2.fromOffset(420, 58) }
	)
	tag(d, "Role", role, 20, 76, roleColor)
	text(d, "Line", line, 18, MUTED, {
		Position = UDim2.fromOffset(20, 108),
		Size = UDim2.fromOffset(420, 44),
		FontFace = BOLD,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
end
local function level(p: Instance, y: number, lv: number, xp: number, need: number, reward: string)
	local l = card(p, "Level", y, 132)
	text(
		l,
		"Level",
		"LV " .. lv,
		36,
		WHITE,
		{ Position = UDim2.fromOffset(20, 12), Size = UDim2.fromOffset(160, 42) }
	)
	text(l, "XP", string.format("%d / %d XP", xp, need), 16, MUTED, {
		Position = UDim2.fromOffset(COL_W - 220, 20),
		Size = UDim2.fromOffset(200, 24),
		FontFace = BOLD,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local bar = box(l, "Bar", 20, 60, COL_W - 40, 12, NAVY_HI)
	corner(bar, 3)
	local fill =
		box(bar, "Fill", 0, 0, 0, 12, ALLY, { Size = UDim2.new(xp / need, 0, 1, 0), ZIndex = 3 })
	corner(fill, 3)
	text(
		l,
		"Next",
		"NEXT REWARD  ·  LV " .. (lv - lv % 5 + 5),
		16,
		MUTED,
		{ Position = UDim2.fromOffset(20, 90), Size = UDim2.fromOffset(260, 24), FontFace = BOLD }
	)
	tagRight(l, "Reward", reward, 20, 88, GOLD)
end
local function actions(p: Instance, y: number, rows: { { string } }): number
	local a = card(p, "Actions", y, 16 + #rows * 76)
	for i, r in rows do
		local row = box(a, r[1], 12, 8 + (i - 1) * 76, COL_W - 24, 68, NAVY)
		corner(row, 6)
		text(
			row,
			"Title",
			r[2],
			22,
			WHITE,
			{ Position = UDim2.fromOffset(16, 8), Size = UDim2.fromOffset(300, 28) }
		)
		text(row, "Sub", r[3], 15, MUTED, {
			Position = UDim2.fromOffset(16, 36),
			Size = UDim2.fromOffset(300, 22),
			FontFace = BOLD,
		})
		local go = box(row, "Open", COL_W - 24 - 76, 8, 64, 52, NAVY_HI, { ZIndex = 3 })
		corner(go, 6)
		text(go, "Glyph", "›", 40, WHITE, {
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, -4),
		})
	end
	return y + 16 + #rows * 76 + 12
end
local function overview(p: Instance, y: number, stats: { { any } })
	local o = card(p, "Overview", y, 52 + #stats * 40)
	header(o, "OVERVIEW", nil, 16)
	for i, s in stats do
		local ry = 48 + (i - 1) * 40
		text(o, "Stat_" .. s[1], s[1], 16, MUTED, {
			Position = UDim2.fromOffset(20, ry),
			Size = UDim2.fromOffset(130, 28),
			FontFace = BOLD,
		})
		for seg = 1, 10 do
			local on = seg <= s[2]
			local b = box(
				o,
				string.format("Seg_%s_%d", s[1], seg),
				150 + (seg - 1) * 21,
				ry + 8,
				17,
				12,
				if on then WHITE else NAVY_HI,
				{ ZIndex = 3 }
			)
			corner(b, 2)
		end
		text(o, "Value_" .. s[1], s[3], 16, WHITE, {
			Position = UDim2.fromOffset(COL_W - 120, ry),
			Size = UDim2.fromOffset(100, 28),
			TextXAlignment = Enum.TextXAlignment.Right,
		})
	end
end

-- gun, owned
local owned = box(right, "GunOwned", 0, 0, COL_W, 900, PANEL, { BackgroundTransparency = 1 })
details(
	owned,
	"HAVOC",
	"RIFLE  ·  ALL-ROUNDER",
	ALLY,
	"Steady at every range. The honest pick that always works."
)
level(owned, 170, 12, 340, 500, "CHARM")
local ny = actions(owned, 314, {
	{ "Contracts", "CONTRACTS", "2 of 9 done  ·  next: 100 eliminations" },
	{ "Statistics", "STATISTICS", "Your lifetime numbers with it" },
})
overview(owned, ny, {
	{ "DAMAGE", 6, "30 → 22" },
	{ "RANGE", 7, "60 studs" },
	{ "FIRE RATE", 6, "10 / s" },
	{ "HANDLING", 6, "0.6°" },
	{ "MOBILITY", 6, "100%" },
	{ "MAGAZINE", 5, "25" },
})

-- gun, locked
local locked = box(
	right,
	"GunLocked",
	0,
	0,
	COL_W,
	900,
	PANEL,
	{ BackgroundTransparency = 1, Visible = false }
)
details(
	locked,
	"DEADEYE",
	"SNIPER  ·  ONE-SHOT HEADS",
	hex("FF7A3D"),
	"Slow to aim, deadly to hit. A headshot ends it."
)
local unlock = card(locked, "Unlock", 170, 226)
text(
	unlock,
	"State",
	"LOCKED",
	24,
	WHITE,
	{ Position = UDim2.fromOffset(20, 16), Size = UDim2.fromOffset(200, 32) }
)
text(
	unlock,
	"How",
	"Unlock it once, keep it forever.",
	16,
	MUTED,
	{ Position = UDim2.fromOffset(20, 54), Size = UDim2.fromOffset(420, 24), FontFace = BOLD }
)
local buy = button(unlock, "Buy", "", 12, 88, COL_W - 24, 64, true)
image(buy, "Coin", COIN, 120, 16, 32, 32, { ZIndex = 7 })
text(
	buy,
	"Price",
	"UNLOCK  1,500",
	26,
	INK,
	{ Position = UDim2.fromOffset(160, 0), Size = UDim2.fromOffset(240, 64), ZIndex = 7 }
)
button(unlock, "Try", "TRY IN THE RANGE", 12, 164, COL_W - 24, 48, false)
overview(locked, 408, {
	{ "DAMAGE", 10, "150 head" },
	{ "RANGE", 10, "200 studs" },
	{ "FIRE RATE", 2, "0.8 / s" },
	{ "HANDLING", 3, "scoped" },
	{ "MOBILITY", 4, "85%" },
	{ "MAGAZINE", 2, "5" },
})

-- power
local power =
	box(right, "Power", 0, 0, COL_W, 900, PANEL, { BackgroundTransparency = 1, Visible = false })
details(
	power,
	"DASH",
	"MOBILITY",
	Theme.ROLE.Mobility,
	"Burst 16 studs the way you're moving. One per round."
)
level(power, 170, 4, 120, 250, "WRAP")
local paths = card(power, "Paths", 314, 300)
header(paths, "UPGRADE PATHS", "PICKED IN A MATCH", 16)
for i, pth in
	{
		{ "A", "LONG DASH", "Dash 22 studs", Theme.ROLE.Mobility },
		{ "B", "GHOST", "Pass through enemies", Theme.ROLE.Mobility },
		{ "G", "DESYNC", "Leave a decoy behind  ·  GLITCHED", GLITCH },
	}
do
	local row = box(paths, "Path" .. pth[1], 12, 46 + (i - 1) * 82, COL_W - 24, 74, NAVY)
	corner(row, 6)
	local letter = box(row, "Letter", 10, 10, 54, 54, pth[4], { ZIndex = 3 })
	corner(letter, 6)
	text(
		letter,
		"L",
		pth[1],
		28,
		INK,
		{ Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center }
	)
	text(
		row,
		"Name",
		pth[2],
		22,
		WHITE,
		{ Position = UDim2.fromOffset(78, 8), Size = UDim2.fromOffset(320, 28) }
	)
	text(
		row,
		"Line",
		pth[3],
		15,
		MUTED,
		{ Position = UDim2.fromOffset(78, 38), Size = UDim2.fromOffset(330, 24), FontFace = BOLD }
	)
end
actions(power, 626, { { "Statistics", "STATISTICS", "Rounds, eliminations, wins with it" } })

------------------------------------------------------------------------------
-- Show the state asked for (workspace attribute LockerV2State)
local state = workspace:GetAttribute("LockerV2State")
-- the shown gun (Havoc) is already equipped: a dark EQUIPPED (gold EQUIP is for an owned gun you haven't equipped)
local function darkEquipped()
	equipBtn.BackgroundColor3 = NAVY_HI
	for _, part in equipBtn:GetChildren() do
		if part:IsA("ImageLabel") then
			part.ImageColor3 = NAVY_HI
		elseif part:IsA("TextLabel") then
			part.Text = "EQUIPPED"
			part.TextColor3 = WHITE
		end
	end
end
if state ~= "locked" and state ~= "power" then
	darkEquipped()
end
if state == "locked" then
	owned.Visible, locked.Visible, lockStage.Visible = false, true, true
	render.Image = Theme.GUN.Operator
	render.ImageTransparency = 0.5
	equipBtn.Visible = false
	skinBtn.Position = UDim2.fromOffset(310 + 18, 4)
elseif state == "power" then
	guns.Visible, powers.Visible = false, true
	gunStage.Visible, powerStage.Visible = false, true
	owned.Visible, power.Visible = false, true
	tabParts.GUNS.plate.BackgroundColor3 = NAVY
	tabParts.GUNS.label.TextColor3 = MUTED
	tabParts.POWERS.plate.BackgroundColor3 = WHITE
	tabParts.POWERS.label.TextColor3 = INK
	-- Dash is already in the deck: a dark REMOVE (gold ADD TO DECK is only for an owned power not in it)
	equipBtn.Visible = false
	skinBtn.Size = UDim2.fromOffset(300 - 36, 64)
	skinBtn.Position = UDim2.fromOffset(270 + 18, 4)
	local words = skinBtn:FindFirstChild("Label")
	if words and words:IsA("TextLabel") then
		words.Text = "REMOVE FROM DECK"
	end
end

gui.Parent = SG
return "LockerV2 built (" .. tostring(state or "owned") .. ")"
