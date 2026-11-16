--!strict
-- Builds the draft screen mockup (vault/02 Art/UI Draft Screen.md, v4) in the
-- match place as StarterGui.DraftMockup with two canvases: CanvasRound1 (three
-- new abilities) and CanvasRound3 (an upgrade column with a glitched path + two
-- new abilities). Replaces an existing DraftMockup. Paste into the Studio
-- command bar (Edit mode). Layout only: nothing drives it yet.
--
-- One 3-column grid (400 wide, 28 apart) holds the guns, the cards and LOCK IN.
-- Picked = lifted, full brightness, gold keycap; the rest dim slightly.

local SG = game:GetService("StarterGui")
local RS = game:GetService("ReplicatedStorage")
local Theme = require(RS:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Theme")) :: any
local Defs = (require(RS.Shared.Config.Mods) :: any).defs

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
local XB, BD, SB = Enum.FontWeight.ExtraBold, Enum.FontWeight.Bold, Enum.FontWeight.SemiBold
local NAVY, NAVY_HI, PANEL = hex("1C2740"), hex("2B3A5A"), hex("0E1320")
local CYAN, GOLD, BODY, MUTED, INK, MAGENTA =
	hex("3FE0F2"), hex("FFC83D"), hex("D7DDE6"), hex("8E98A8"), hex("141A26"), hex("E0249F")
local WHITE = Color3.new(1, 1, 1)
local DIM = Color3.fromRGB(150, 155, 166) -- unpicked: a little darker, never muddy
local SHADOW = "rbxassetid://121253415859134"
local CAP_R, CAP_L = "rbxassetid://130377997107460", "rbxassetid://75584308608588"

-- the grid
local COL_W, GAP = 400, 28
local X0 = (1920 - (COL_W * 3 + GAP * 2)) / 2
local GUN_Y, GUN_H = 140, 96
local CARD_Y, CARD_H = 304, 500
local LIFT = 10

local function colX(i: number): number
	return X0 + (i - 1) * (COL_W + GAP)
end

local function text(
	p: Instance,
	s: string,
	x: number,
	y: number,
	size: number,
	color: Color3,
	weight: Enum.FontWeight?,
	props: { [string]: any }?
): TextLabel
	local t = make("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(0, size + 4),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = s,
		FontFace = Font.new(BX, weight or BD),
		TextSize = size,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 5,
	}, p)
	for k, v in props or {} do
		(t :: any)[k] = v
	end
	return t
end

local function keycap(
	p: Instance,
	s: string,
	w: number,
	h: number,
	picked: boolean,
	props: { [string]: any }
): Frame
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
	make("UICorner", { CornerRadius = UDim.new(0, 5) }, k)
	local f = make("Frame", {
		Name = "Face",
		Size = UDim2.new(1, 0, 1, -4),
		BackgroundColor3 = if picked then GOLD else hex("E9EDF3"),
		BorderSizePixel = 0,
		ZIndex = 9,
	}, k)
	make("UICorner", { CornerRadius = UDim.new(0, 5) }, f)
	make("TextLabel", {
		Name = "Label",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = s,
		FontFace = Font.new(BX, XB),
		TextSize = math.floor(h * 0.46),
		TextColor3 = INK,
		ZIndex = 10,
	}, f)
	return k
end

local function shadow(p: Instance, x: number, y: number, w: number, h: number)
	make("ImageLabel", {
		Name = "Shadow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x + w / 2, y + h / 2 + 10),
		Size = UDim2.fromOffset(w + 70, h + 70),
		BackgroundTransparency = 1,
		Image = SHADOW,
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 0.35,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(48, 48, 80, 80),
		ZIndex = 0,
	}, p)
end

-- a slanted band: a rotated frame clipped by its CanvasGroup
local function band(card: Instance, color: Color3, top: number)
	make("Frame", {
		Name = "Band",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, top),
		Size = UDim2.fromOffset(COL_W * 2, 260),
		Rotation = -4,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, card)
end

local function gun(canvas: Instance, i: number, id: string, shield: number, picked: boolean)
	local x, y = colX(i), GUN_Y + (if picked then -6 else 0)
	shadow(canvas, x, y, COL_W, GUN_H)
	local c = make("CanvasGroup", {
		Name = "Gun" .. i,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(COL_W, GUN_H),
		BackgroundColor3 = if picked then NAVY_HI else NAVY,
		BorderSizePixel = 0,
		GroupColor3 = if picked then WHITE else DIM,
		ZIndex = 1,
	}, canvas)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, c)
	make("ImageLabel", {
		Name = "Gun",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 20, 0.5, -2),
		Size = UDim2.fromOffset(250, 70),
		BackgroundTransparency = 1,
		Image = Theme.GUN[id] or "",
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 3,
	}, c)
	text(c, string.upper(id), 18, GUN_H - 30, 15, WHITE, XB)
	if shield > 0 then
		text(c, "+" .. shield .. " SHIELD", 0, GUN_H - 29, 12, CYAN, XB, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromOffset(COL_W - 16, GUN_H - 28),
		})
	end
	keycap(c, tostring(i), 24, 26, picked, { Position = UDim2.fromOffset(12, 12) })
end

local function keyTab(canvas: Instance, i: number, key: string, picked: boolean, lifted: boolean)
	keycap(canvas, key, 44, 36, picked, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(colX(i) + COL_W / 2, CARD_Y + (if lifted then -LIFT else 0)),
		ZIndex = 12,
	})
end

local function chargeLine(L1: any): string
	if (L1.cooldown or 0) > 0 then
		return (L1.charges or 1) .. " CHARGE  ·  " .. L1.cooldown .. "S COOLDOWN"
	end
	return "ONCE PER ROUND"
end

local function newCard(canvas: Instance, i: number, id: string, key: string, picked: boolean)
	local m = Defs[id]
	local L1 = m.levels.L1
	local x, y = colX(i), CARD_Y + (if picked then -LIFT else 0)
	shadow(canvas, x, y, COL_W, CARD_H)
	local c = make("CanvasGroup", {
		Name = "Card" .. key,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(COL_W, CARD_H),
		BackgroundColor3 = PANEL,
		BorderSizePixel = 0,
		GroupColor3 = if picked then WHITE else DIM,
		ZIndex = 1,
	}, canvas)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, c)
	make("ImageLabel", {
		Name = "Art",
		Size = UDim2.fromOffset(COL_W, 330),
		BackgroundTransparency = 1,
		Image = Theme.CARD_ART[id] or "",
		ScaleType = Enum.ScaleType.Crop,
		ZIndex = 1,
	}, c)
	band(c, Theme.ROLE[m.role], 286)
	make("Frame", {
		Name = "Panel",
		Position = UDim2.fromOffset(0, 384),
		Size = UDim2.fromOffset(COL_W, 120),
		BackgroundColor3 = PANEL,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, c)
	text(c, string.upper(m.name), 24, 306, 36, WHITE, XB, { ZIndex = 6 })
	text(c, string.upper(m.role), 26, 350, 12, WHITE, XB, { TextTransparency = 0.2, ZIndex = 6 })
	text(c, L1.note .. ".", 24, 402, 16, BODY, SB, {
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromOffset(COL_W - 48, 0),
		TextWrapped = true,
		ZIndex = 6,
	})
	text(c, chargeLine(L1), 24, CARD_H - 32, 12, MUTED, XB, { ZIndex = 6 })
	text(c, "NEW", 0, CARD_H - 32, 12, GOLD, XB, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromOffset(COL_W - 24, CARD_H - 32),
		ZIndex = 6,
	})
	keyTab(canvas, i, key, picked, picked)
end

-- an upgrade column: one half-card per path (Valorant: smaller copies of the card)
local function upgradeColumn(
	canvas: Instance,
	i: number,
	id: string,
	key: string,
	paths: { any },
	pickedPath: number?
)
	local m = Defs[id]
	local role = Theme.ROLE[m.role]
	local gap = 26
	local h = math.floor((CARD_H - gap * (#paths - 1)) / #paths)
	for p, o in paths do
		local picked = p == pickedPath
		local x = colX(i)
		local y = CARD_Y + (p - 1) * (h + gap) + (if picked then -LIFT else 0)
		shadow(canvas, x, y, COL_W, h)
		local c = make("CanvasGroup", {
			Name = "Path" .. key .. p,
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(COL_W, h),
			BackgroundColor3 = PANEL,
			BorderSizePixel = 0,
			GroupColor3 = if picked then WHITE else DIM,
			ZIndex = 1,
		}, canvas)
		make("UICorner", { CornerRadius = UDim.new(0, 8) }, c)
		make("ImageLabel", {
			Name = "Art",
			Size = UDim2.fromOffset(COL_W, h),
			BackgroundTransparency = 1,
			Image = Theme.CARD_ART[id] or "",
			ScaleType = Enum.ScaleType.Crop,
			ZIndex = 1,
		}, c)
		band(c, if o.glitch then MAGENTA else role, h - 104)
		make("Frame", {
			Name = "Panel",
			Position = UDim2.fromOffset(0, h - 40),
			Size = UDim2.fromOffset(COL_W, 40),
			BackgroundColor3 = PANEL,
			BorderSizePixel = 0,
			ZIndex = 3,
		}, c)
		if o.glitch then
			text(
				c,
				o.name,
				21,
				h - 85,
				30,
				hex("00E5FF"),
				XB,
				{ TextTransparency = 0.1, ZIndex = 5 }
			)
			text(
				c,
				o.name,
				27,
				h - 83,
				30,
				hex("FF8BE0"),
				XB,
				{ TextTransparency = 0.1, ZIndex = 5 }
			)
		end
		text(c, o.name, 24, h - 84, 30, WHITE, XB, { ZIndex = 6 })
		text(c, o.tag, 0, h - 74, 11, WHITE, XB, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromOffset(COL_W - 20, h - 74),
			TextTransparency = 0.15,
			ZIndex = 6,
		})
		text(
			c,
			o.stat,
			24,
			h - 29,
			14,
			if o.glitch then hex("FF8BE0") else role,
			XB,
			{ ZIndex = 6 }
		)
		if p < #paths then
			text(canvas, "OR", 0, 0, 11, MUTED, XB, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(x + COL_W / 2, CARD_Y + p * (h + gap) - gap / 2),
			})
		end
	end
	keyTab(canvas, i, key, pickedPath ~= nil, pickedPath == 1)
end

local function lockIn(canvas: Instance, pick: string)
	local w, h = COL_W + 40, 78
	local x, y = colX(2) - 20, CARD_Y + CARD_H + 36
	shadow(canvas, x + 20, y, w - 40, h)
	local lock = make("Frame", {
		Name = "LockIn",
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, canvas)
	make("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(26, 0),
		Size = UDim2.fromOffset(w - 52, h),
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
	}, lock)
	make("ImageLabel", {
		Name = "CapL",
		Size = UDim2.fromOffset(28, h),
		BackgroundTransparency = 1,
		Image = CAP_L,
		ImageColor3 = GOLD,
	}, lock)
	make("ImageLabel", {
		Name = "CapR",
		Position = UDim2.fromOffset(w - 28, 0),
		Size = UDim2.fromOffset(28, h),
		BackgroundTransparency = 1,
		Image = CAP_R,
		ImageColor3 = GOLD,
	}, lock)
	text(
		lock,
		"LOCK IN",
		0,
		0,
		30,
		INK,
		XB,
		{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(w / 2, 12) }
	)
	text(lock, pick, 0, 0, 12, INK, XB, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(w / 2, 48),
		TextTransparency = 0.3,
	})
	keycap(
		lock,
		"ENTER",
		62,
		28,
		false,
		{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromOffset(w - 40, h / 2) }
	)
end

local function enemy(canvas: Instance, kit: { any })
	local right = colX(3) + COL_W
	local y = CARD_Y + CARD_H + 52
	if #kit == 0 then
		text(
			canvas,
			"ENEMY HAS NO ABILITIES YET",
			0,
			0,
			12,
			MUTED,
			XB,
			{ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(right, y + 14) }
		)
		return
	end
	text(canvas, "ENEMY", 0, 0, 12, MUTED, XB, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromOffset(right - #kit * 54 - 4, y + 14),
	})
	for i, e in kit do
		local m = Defs[e[1]]
		local b = make("Frame", {
			Position = UDim2.fromOffset(right - (#kit - i + 1) * 54 + 8, y),
			Size = UDim2.fromOffset(46, 46),
			BackgroundColor3 = Theme.ROLE[m.role],
			BorderSizePixel = 0,
		}, canvas)
		make("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
		make("ImageLabel", {
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.fromOffset(30, 30),
			BackgroundTransparency = 1,
			Image = m.icon,
			ZIndex = 2,
		}, b)
		text(
			b,
			e[2],
			0,
			0,
			12,
			INK,
			XB,
			{ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -4, 1, 0), ZIndex = 3 }
		)
	end
end

-- build ------------------------------------------------------------------------
local old = SG:FindFirstChild("DraftMockup")
if old then
	old:Destroy()
end
local gui = make("ScreenGui", {
	Name = "DraftMockup",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 8,
	Enabled = false,
})
make("Frame", {
	Name = "Dim",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = hex("070A10"),
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
}, gui)
local function canvas(name: string): Frame
	local c = make("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(1920, 1080),
		BackgroundTransparency = 1,
		Visible = false,
	}, gui)
	make("UIScale", { Name = "Fit" }, c)
	return c
end

local r1 = canvas("CanvasRound1")
gun(r1, 1, "Ghost", 25, false)
gun(r1, 2, "Sheriff", 0, true)
gun(r1, 3, "Classic", 50, false)
newCard(r1, 1, "Updraft", "Q", true)
newCard(r1, 2, "Recall", "E", false)
newCard(r1, 3, "Frost", "T", false)
lockIn(r1, "SHERIFF  +  UPDRAFT")
enemy(r1, {})

local r3 = canvas("CanvasRound3")
r3.Visible = true
gun(r3, 1, "Spectre", 25, true)
gun(r3, 2, "Marshal", 0, false)
gun(r3, 3, "Judge", 25, false)
upgradeColumn(r3, 1, "Updraft", "Q", {
	{ name = "HIGH RISE", tag = "UPDRAFT  LV 2", stat = "PEAK  14 → 21 STUDS" },
	{ name = "SECOND WIND", tag = "UPDRAFT  LV 2", stat = "CHARGES  1 → 2" },
	{
		name = "CRASH DOWN",
		tag = "UPDRAFT  ·  GLITCHED",
		stat = "SLAM  30 DAMAGE IN 8 STUDS",
		glitch = true,
	},
}, 1)
newCard(r3, 2, "Dash", "E", false)
newCard(r3, 3, "Firewall", "T", false)
lockIn(r3, "SPECTRE  +  HIGH RISE")
enemy(r3, { { "Updraft", "2" }, { "Firewall", "1" } })

gui.Parent = SG
print("DraftMockup v4 built")
