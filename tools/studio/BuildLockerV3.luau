--!strict
-- Locker v3 MOCKUP (vault/01 Design/Loadout and Power Deck.md -> "Locker v3 mockup"). Owner 2026-11-26:
-- "much more like RIVALS" for guns, and powers as cards you can move around like a real card.
-- Run in the place's Edit mode (Studio command bar or MCP execute_luau). Re-running replaces it.
--
-- What it builds:
--   StarterGui.LockerV3 (Enabled = false): the screen. Side columns over a live 3D stage, chunky gradient
--     buttons with a shine, translucent dark panels, round bottom buttons. Our art only: gun renders
--     (Theme.GUN), power card art (Theme.CARD_ART), the Power Duels logo and our own icons
--     (art-source/ui/locker-v3/icons, tools/ui/make_locker_icons.py).
--   ReplicatedStorage.LockerV3Stage: the 3D bits. Showcase (our guns in their equipped skins) and PowerCard (a real card:
--     the draft card's face on the front, the logo on the back, a coloured edge).
--   LockerV3.Preview (LocalScript): only when workspace attribute LockerV3Preview = true, in Play it
--     opens the mockup in the lobby's Locker room (camera at FOV 20 + depth of field, like RIVALS' locker),
--     lets you click through guns and powers, and drag the gun or the card to turn it.
--     The real build would use an off-world copy of the room so other players never walk through it.
-- Nothing here is wired to data: levels, prices, decks and stats are placeholders.

local SG = game:GetService("StarterGui")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

local Theme = require(RS.Shared.Config.Theme)
local ModsConfig = require(RS.Shared.Config.Mods)
local UiPlates = require(RS.Shared.Config.UiPlates)

-- clean up earlier test bits
for _, n in { "_LockerTest", "LockerV3Stage" } do
	local o = workspace:FindFirstChild(n)
	if o then
		o:Destroy()
	end
end
local cam0 = workspace.CurrentCamera
local testDof = cam0:FindFirstChild("_LockerTestDOF")
if testDof then
	testDof:Destroy()
end
cam0.FieldOfView = 70

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
local MED = Font.new("rbxassetid://12187365977", Enum.FontWeight.Medium)
local WHITE = Color3.new(1, 1, 1)
local INK = hex("17130A")
local PANEL = hex("07080B")
local MUTED = hex("B4B9C4")
local DIM = hex("7D828D")
local CYAN = hex("3FE0F2")
local GLITCH = ModsConfig.COLORS.glitch
local CARD_PANEL = hex("141418")

-- image ids (the uploads' Decal ids resolved to their Image ids)
local ICON = {
	arrow = "rbxassetid://102173957816100",
	card = "rbxassetid://99236455638399",
	charm = "rbxassetid://75794447432603",
	close = "rbxassetid://117187485232361",
	contracts = "rbxassetid://101531329757279",
	eye = "rbxassetid://91802754659062",
	levelup = "rbxassetid://128719395035781",
	play = "rbxassetid://125272113160140",
	reward = "rbxassetid://140146003963464",
	skin = "rbxassetid://125498883768070",
	star = "rbxassetid://133407654022359",
	stats = "rbxassetid://77348327642736",
	target = "rbxassetid://123471470418465",
	lock = Theme.ICON.Lock,
	skull = Theme.ICON.Skull,
	coin = "rbxassetid://122645025340088",
	logo = "rbxassetid://71296115628525",
}

-- button colours: top -> bottom
local GOLD = { hex("FFE066"), hex("F2A51C") }
local BLUE = { hex("4D9BFF"), hex("1E5FE0") }
local RED = { hex("FF6A5C"), hex("D2312A") }
local DARK = { hex("41444E"), hex("24262D") }
local LIGHT = { hex("FFFFFF"), hex("C9CED8") }

-- mock data -------------------------------------------------------------------------------------------
type Gun = {
	id: string,
	name: string,
	role: string,
	blurb: string,
	owned: boolean,
	level: number,
	price: number,
	skin: string?,
	equipped: boolean,
}
local function gun(id, name, role, blurb, owned, level, price, skin, equipped): Gun
	return {
		id = id,
		name = name,
		role = role,
		blurb = blurb,
		owned = owned,
		level = level,
		price = price,
		skin = skin,
		equipped = equipped,
	}
end
local PRIMARY: { Gun } = {
	gun(
		"Vandal",
		"Havoc",
		"RIFLE · ALL-ROUNDER",
		"Steady at every range. The honest pick that always works.",
		true,
		12,
		0,
		"Redline",
		true
	),
	gun(
		"Spectre",
		"Prowler",
		"SMG · RUN AND GUN",
		"Fastest on the move. Wins the close fights.",
		true,
		5,
		0,
		"Nitrous",
		false
	),
	gun(
		"Bucky",
		"Pump",
		"SHOTGUN · CLOSE BURST",
		"One big burst up close. Pick your corners.",
		true,
		3,
		0,
		"Poolside",
		false
	),
	gun(
		"Bulldog",
		"Lancer",
		"BURST RIFLE · PRECISE",
		"Three-round bursts that stay on target.",
		false,
		0,
		750,
		nil,
		false
	),
	gun(
		"Guardian",
		"Marksman",
		"DMR · TWO-TAP",
		"Two taps at mid range. Slow, sure, deadly.",
		false,
		0,
		900,
		nil,
		false
	),
	gun(
		"Phantom",
		"Spirit",
		"SILENCED RIFLE · QUIET",
		"No tracers. They never see where it came from.",
		false,
		0,
		1000,
		nil,
		false
	),
	gun(
		"Odin",
		"Mauler",
		"LMG · SUPPRESS",
		"A huge magazine that takes a moment to spin up.",
		false,
		0,
		1200,
		nil,
		false
	),
	gun(
		"Operator",
		"Deadeye",
		"SNIPER · ONE-SHOT",
		"One headshot ends it. Miss and you're exposed.",
		false,
		0,
		1500,
		nil,
		false
	),
}
local SECONDARY: { Gun } = {
	gun(
		"Classic",
		"Classic",
		"PISTOL · RELIABLE",
		"Quick to draw, easy to land. Never a bad call.",
		true,
		8,
		0,
		"Prism",
		true
	),
	gun(
		"Sheriff",
		"Sheriff",
		"REVOLVER · HEAVY",
		"Slow, loud, and one tap to the head at close range.",
		true,
		2,
		0,
		"Oilwake",
		false
	),
	gun(
		"Shorty",
		"Shorty",
		"POCKET SHOTGUN",
		"Two shells for when they get too close.",
		false,
		0,
		400,
		nil,
		false
	),
	gun(
		"Ghost",
		"Hush",
		"SILENCED PISTOL",
		"Quiet and accurate. Finish what your primary started.",
		false,
		0,
		500,
		nil,
		false
	),
}
local POWERS = {
	{ id = "Dash", owned = true, deck = true, level = 4 },
	{ id = "Updraft", owned = true, deck = true, level = 3 },
	{ id = "Molly", owned = true, deck = true, level = 2 },
	{ id = "Frost", owned = true, deck = true, level = 2 },
	{ id = "Recon", owned = true, deck = false, level = 1 },
	{ id = "HealOrb", owned = true, deck = false, level = 1 },
	{ id = "Firewall", owned = false, deck = false, level = 0 },
	{ id = "Stim", owned = false, deck = false, level = 0 },
	{ id = "Recall", owned = false, deck = false, level = 0 },
	{ id = "ShockDart", owned = false, deck = false, level = 0 },
	{ id = "Flash", owned = false, deck = false, level = 0 },
	{ id = "Roller", owned = false, deck = false, level = 0 },
}

-- helpers ---------------------------------------------------------------------------------------------
local CUT = UiPlates.cut1
local CELL = UiPlates.cell

local function grad(p: Instance, top: Color3, bottom: Color3)
	make("UIGradient", {
		Name = "Fill",
		Rotation = 90,
		Color = ColorSequence.new(top, bottom),
	}, p)
end
local function corner(p: Instance, r: number)
	make("UICorner", { CornerRadius = UDim.new(0, r) }, p)
end
local function text(
	p: Instance,
	name: string,
	t: string,
	size: number,
	font: Font,
	color: Color3,
	props: { [string]: any }?
): TextLabel
	local l = make("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Text = t,
		FontFace = font,
		TextSize = size,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromOffset(300, size + 4),
		ZIndex = 5,
	}, p)
	for k, v in props or {} do
		(l :: any)[k] = v
	end
	return l
end
-- a soft dark edge on words that sit on the 3D scene (RIVALS' 88 % stroke; reads as a shadow, not an outline)
local function soft(l: TextLabel, t: number?)
	make("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2, Transparency = t or 0.8 }, l)
end
local function icon(
	p: Instance,
	name: string,
	img: string,
	x: number,
	y: number,
	s: number,
	props: { [string]: any }?
): ImageLabel
	local i = make("ImageLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Image = img,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(s, s),
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 5,
	}, p)
	for k, v in props or {} do
		(i :: any)[k] = v
	end
	return i
end
-- a sliced plate image behind its parent (the one-cut corner plate, or the small-chamfer cell)
local function plate(
	p: Instance,
	art: any,
	color: Color3,
	transparency: number,
	z: number,
	scale: number?
): ImageLabel
	return make("ImageLabel", {
		Name = "Bg",
		BackgroundTransparency = 1,
		Image = art.image,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = art.slice,
		SliceScale = scale or 0.6,
		ImageColor3 = color,
		ImageTransparency = transparency,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z,
	}, p)
end
-- a translucent dark panel (Active so drags on it don't turn the stage)
local function panel(p: Instance, name: string, w: number, h: number, order: number?): Frame
	local f = make("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(w, h),
		Active = true,
		LayoutOrder = order or 0,
	}, p)
	plate(f, CUT, PANEL, 0.22, 1)
	return f
end
-- a chunky button: gradient plate, a shine on its top half, then an icon and/or words
local function button(
	p: Instance,
	name: string,
	x: number,
	y: number,
	w: number,
	h: number,
	colors: { Color3 },
	label: string?,
	img: string?,
	ink: boolean?
): ImageButton
	local b = make("ImageButton", {
		Name = name,
		BackgroundTransparency = 1,
		Image = "",
		AutoButtonColor = false,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		ZIndex = 4,
	}, p)
	local bg = plate(b, CUT, WHITE, 0, 4, 0.7)
	grad(bg, colors[1], colors[2])
	local shine = make("ImageLabel", {
		Name = "Shine",
		BackgroundTransparency = 1,
		Image = CUT.image,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = CUT.slice,
		SliceScale = 0.6,
		ImageTransparency = 0.72,
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(1, -8, 0.5, -4),
		ZIndex = 5,
	}, b)
	make("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, shine)
	local fg = if ink then INK else WHITE
	local iconSize = math.floor(h * 0.56)
	if img and label then
		icon(b, "Icon", img, 0, 0, iconSize, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 18, 0.5, 0),
			ImageColor3 = fg,
			ZIndex = 6,
		})
	elseif img then
		icon(b, "Icon", img, 0, 0, iconSize, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ImageColor3 = fg,
			ZIndex = 6,
		})
	end
	if label then
		local l = text(b, "Label", label, math.floor(h * 0.42), HEAVY, fg, {
			Size = UDim2.new(1, if img then -iconSize - 18 else 0, 1, 0),
			Position = UDim2.fromOffset(if img then iconSize + 18 else 0, 0),
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 6,
		})
		if not ink then
			make("UIStroke", {
				Color = colors[2]:Lerp(Color3.new(0, 0, 0), 0.6),
				Thickness = 2,
				Transparency = 0.35,
			}, l)
		end
	end
	return b
end
-- a round bottom-bar button with its word under it
local function roundButton(
	p: Instance,
	name: string,
	x: number,
	label: string,
	img: string,
	colors: { Color3 }
): Frame
	local f = make("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.fromOffset(110, 128),
		Active = true,
	}, p)
	local b = make("ImageButton", {
		Name = "Button",
		AutoButtonColor = false,
		BackgroundColor3 = WHITE,
		Image = "",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(86, 86),
		ZIndex = 4,
	}, f)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, b)
	grad(b, colors[1], colors[2])
	-- no shine on the round buttons (owner 2026-11-26: the glow on Back / Flip "does not look good")
	icon(b, "Icon", img, 0, 0, 44, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 6,
	})
	local l = text(f, "Label", label, 19, HEAVY, WHITE, {
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.fromOffset(0, 94),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	soft(l, 0.55)
	return f
end
local function slash(p: Instance, x: number, y: number, h: number, color: Color3?)
	make("Frame", {
		Name = "Slash",
		BackgroundColor3 = color or WHITE,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(6, h),
		Rotation = 14,
		ZIndex = 5,
	}, p)
end
local function list(p: Instance, pad: number, bottom: boolean?)
	make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, pad),
		VerticalAlignment = if bottom
			then Enum.VerticalAlignment.Bottom
			else Enum.VerticalAlignment.Top,
	}, p)
end
local function bar(
	p: Instance,
	name: string,
	x: number,
	y: number,
	w: number,
	h: number,
	fill: number,
	colors: { Color3 }
)
	local back = make("Frame", {
		Name = name,
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.86,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		ZIndex = 4,
	}, p)
	corner(back, 3)
	local f = make("Frame", {
		Name = "Fill",
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(fill, 1),
		ZIndex = 5,
	}, back)
	corner(f, 3)
	grad(f, colors[1], colors[2])
	return back
end

local function modDef(id: string): any
	return (ModsConfig :: any).defs[id]
end
local function pathNote(def: any, p: string): string
	local best: string? = nil
	for k, v in def.levels do
		if string.sub(k, 1, 1) == p and typeof(v) == "table" and v.note then
			if not best or k < best then
				best = k
			end
		end
	end
	local note = if best then def.levels[best].note else ""
	note = string.gsub(note, "^[^:]+: ", "")
	return string.upper(string.sub(note, 1, 1)) .. string.sub(note, 2)
end

-- the gui ----------------------------------------------------------------------------------------------
local old = SG:FindFirstChild("LockerV3")
local oldPreview = old and old:FindFirstChild("Preview")
local previewSource = if oldPreview and oldPreview:IsA("LocalScript") then oldPreview.Source else ""
if old then
	old:Destroy()
end
local gui = make("ScreenGui", {
	Name = "LockerV3",
	Enabled = false,
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	ScreenInsets = Enum.ScreenInsets.None,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 20,
})
local vp = workspace.CurrentCamera.ViewportSize
local FIT = vp.Y / 1080

-- the stage drag zone (under everything), then the shades that seat the columns on the scene
make("TextButton", {
	Name = "DragZone",
	BackgroundTransparency = 1,
	Text = "",
	Size = UDim2.fromScale(1, 1),
	ZIndex = 0,
}, gui)
for _, s in
	{
		{ "ShadeL", Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(0.34, 1), 0 },
		{ "ShadeR", Vector2.new(1, 0), UDim2.fromScale(1, 0), UDim2.fromScale(0.34, 1), 180 },
		{ "ShadeB", Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.fromScale(1, 0.24), -90 },
	}
do
	local f = make("Frame", {
		Name = s[1],
		AnchorPoint = s[2],
		Position = s[3],
		Size = s[4],
		BackgroundColor3 = PANEL,
		BorderSizePixel = 0,
		ZIndex = 0,
	}, gui)
	make("UIGradient", {
		Rotation = s[5],
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, f)
end

local function column(name: string, anchor: Vector2, pos: UDim2, w: number, h: number): Frame
	local f = make("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		AnchorPoint = anchor,
		Position = pos,
		Size = UDim2.fromOffset(w, h),
	}, gui)
	make("UIScale", { Name = "Fit", Scale = FIT }, f)
	return f
end
local COL = 440
local Left = column("Left", Vector2.new(0, 0), UDim2.fromScale(0, 0), COL + 32, 1080)
local Right = column("Right", Vector2.new(1, 0), UDim2.fromScale(1, 0), COL + 32, 1080)
local Top = column("Top", Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0), 760, 110)
local TopRight = column("TopRight", Vector2.new(1, 0), UDim2.fromScale(1, 0), 300, 110)
local Bottom = column("Bottom", Vector2.new(0.5, 1), UDim2.fromScale(0.5, 1), 760, 176)
local Center = column("Center", Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), 400, 400)

-- top: tabs and coins
local tabs =
	make("Frame", { Name = "Tabs", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, Top)
for i, t in { "GUNS", "POWERS", "KNIFE" } do
	local active = i == 1
	local b = button(
		tabs,
		"Tab" .. t,
		128 + (i - 1) * 172,
		30,
		162,
		58,
		if active then LIGHT else DARK,
		t,
		nil,
		active
	)
	b:SetAttribute("Tab", t)
	local bgi = b:FindFirstChild("Bg")
	if not active and bgi and bgi:IsA("ImageLabel") then
		bgi.ImageTransparency = 0.3
	end
end
local coins = panel(TopRight, "Coins", 210, 58)
coins.Position = UDim2.fromOffset(62, 30)
icon(coins, "Coin", ICON.coin, 14, 9, 40)
soft(
	text(
		coins,
		"Amount",
		"1,250",
		30,
		HEAVY,
		WHITE,
		{ Position = UDim2.fromOffset(62, 12), Size = UDim2.fromOffset(136, 34) }
	)
)

-- LEFT: GUNS ---------------------------------------------------------------------------------------------
local title = text(
	Left,
	"Title",
	"LOCKER",
	46,
	HEAVY,
	WHITE,
	{ Position = UDim2.fromOffset(32, 30), Size = UDim2.fromOffset(300, 52) }
)
soft(title, 0.6)

local guns =
	make("Frame", { Name = "Guns", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, Left)
-- loadout card
local loadout = panel(guns, "Loadout", COL, 168)
loadout.Position = UDim2.fromOffset(32, 96)
slash(loadout, 18, 14, 18)
text(loadout, "Head", "LOADOUT", 17, HEAVY, MUTED, { Position = UDim2.fromOffset(34, 12) })
for i, s in { { "Primary", "PRIMARY", PRIMARY[1] }, { "Secondary", "SECONDARY", SECONDARY[1] } } do
	local g = s[3] :: Gun
	local slot = make("ImageButton", {
		Name = s[1],
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Image = "",
		Position = UDim2.fromOffset(14 + (i - 1) * 208, 44),
		Size = UDim2.fromOffset(200, 110),
		ZIndex = 3,
	}, loadout)
	plate(slot, CELL, WHITE, 0.9, 2, 0.6)
	text(slot, "Slot", s[2], 13, BOLD, DIM, { Position = UDim2.fromOffset(12, 8) })
	icon(slot, "Render", Theme.GUN[g.id] or "", 20, 26, 160, {
		Size = UDim2.fromOffset(170, 54),
		Position = UDim2.fromOffset(15, 26),
	})
	text(
		slot,
		"Name",
		string.upper(g.name),
		20,
		HEAVY,
		WHITE,
		{ Position = UDim2.fromOffset(12, 82) }
	)
end

-- the gun list
local gunList = make("ScrollingFrame", {
	Name = "List",
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(32, 276),
	Size = UDim2.fromOffset(COL + 8, 1080 - 276 - 24),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = WHITE,
	ScrollBarImageTransparency = 0.6,
	Active = true,
}, guns)
list(gunList, 8)
local order = 0
local function section(parent: Instance, label: string, count: string): Frame
	order += 1
	local f = make("Frame", {
		Name = "Head" .. label,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(COL, 42),
		LayoutOrder = order,
	}, parent)
	slash(f, 6, 10, 22)
	soft(
		text(
			f,
			"Label",
			label,
			24,
			HEAVY,
			WHITE,
			{ Position = UDim2.fromOffset(24, 8), Size = UDim2.fromOffset(250, 28) }
		),
		0.6
	)
	soft(
		text(f, "Count", count, 16, BOLD, MUTED, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromOffset(COL - 8, 14),
			Size = UDim2.fromOffset(200, 20),
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
		0.6
	)
	return f
end
local function gunRow(g: Gun, slotName: string)
	order += 1
	local r = make("ImageButton", {
		Name = "Row" .. g.id,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Image = "",
		Size = UDim2.fromOffset(COL, 68),
		LayoutOrder = order,
		ZIndex = 3,
	}, gunList)
	for k, v in
		{
			Gun = g.id,
			GunName = g.name,
			Role = g.role,
			Blurb = g.blurb,
			Owned = g.owned,
			Level = g.level,
			Price = g.price,
			Equipped = g.equipped,
			SlotName = slotName,
		}
	do
		r:SetAttribute(k, v)
	end
	local selected = g.id == "Vandal"
	local bg =
		plate(r, CELL, if selected then WHITE else PANEL, if selected then 0.8 else 0.3, 2, 0.6)
	bg.Name = "Bg"
	make("Frame", {
		Name = "Sel",
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(6, 14),
		Size = UDim2.fromOffset(5, 40),
		Rotation = 14,
		Visible = selected,
		ZIndex = 5,
	}, r)
	icon(r, "Render", Theme.GUN[g.id] or "", 18, 8, 120, {
		Size = UDim2.fromOffset(124, 52),
		ImageTransparency = if g.owned then 0 else 0.55,
		ImageColor3 = if g.owned then WHITE else hex("9A9EA8"),
	})
	local n =
		text(r, "Name", string.upper(g.name), 25, HEAVY, if g.owned then WHITE else hex("A3A7B0"), {
			Position = UDim2.fromOffset(156, 12),
			Size = UDim2.fromOffset(190, 30),
		})
	soft(n, 0.75)
	if g.owned then
		text(r, "Level", "LV " .. g.level, 18, HEAVY, WHITE, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromOffset(COL - 18, 23),
			Size = UDim2.fromOffset(80, 22),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextTransparency = 0.15,
		})
		text(r, "Equipped", "EQUIPPED", 13, HEAVY, CYAN, {
			Position = UDim2.fromOffset(157, 42),
			Size = UDim2.fromOffset(120, 16),
			Visible = g.equipped,
		})
	else
		icon(r, "Lock", ICON.lock, 128, 22, 22, { ImageColor3 = hex("C8CCD4") })
		text(
			r,
			"Sub",
			"LOCKED",
			13,
			HEAVY,
			DIM,
			{ Position = UDim2.fromOffset(157, 42), Size = UDim2.fromOffset(120, 16) }
		)
		icon(r, "Coin", ICON.coin, COL - 118, 20, 28)
		text(
			r,
			"Price",
			string.format("%d,%03d", g.price // 1000, g.price % 1000):gsub("^0,", ""),
			21,
			HEAVY,
			WHITE,
			{
				Position = UDim2.fromOffset(COL - 86, 22),
				Size = UDim2.fromOffset(72, 24),
				TextXAlignment = Enum.TextXAlignment.Right,
			}
		)
	end
end
section(gunList, "PRIMARY", "3 / 8 OWNED")
for _, g in PRIMARY do
	gunRow(g, "Primary")
end
section(gunList, "SECONDARY", "2 / 4 OWNED")
for _, g in SECONDARY do
	gunRow(g, "Secondary")
end

-- LEFT: POWERS -------------------------------------------------------------------------------------------
local powers = make(
	"Frame",
	{ Name = "Powers", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false },
	Left
)
local deck = panel(powers, "Deck", COL, 286)
deck.Position = UDim2.fromOffset(32, 96)
slash(deck, 18, 14, 18)
text(deck, "Head", "YOUR DECK", 17, HEAVY, MUTED, { Position = UDim2.fromOffset(34, 12) })
text(deck, "Count", "4 / 10", 17, HEAVY, WHITE, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromOffset(COL - 18, 12),
	Size = UDim2.fromOffset(100, 20),
	TextXAlignment = Enum.TextXAlignment.Right,
})
text(
	deck,
	"Hint",
	"The draft deals your powers from these cards",
	14,
	MED,
	DIM,
	{ Position = UDim2.fromOffset(18, 256), Size = UDim2.fromOffset(COL - 36, 18) }
)
for i = 1, 10 do
	local col, row = (i - 1) % 5, (i - 1) // 5
	local s = make("Frame", {
		Name = "Slot" .. i,
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.92,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(18 + col * 82, 44 + row * 104),
		Size = UDim2.fromOffset(74, 96),
		ClipsDescendants = true,
		ZIndex = 3,
	}, deck)
	corner(s, 6)
	make("ImageLabel", {
		Name = "Art",
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Crop,
		Size = UDim2.fromOffset(74, 70),
		ZIndex = 3,
		Image = "",
	}, s)
	make("Frame", {
		Name = "Band",
		BorderSizePixel = 0,
		BackgroundColor3 = WHITE,
		Position = UDim2.fromOffset(0, 70),
		Size = UDim2.fromOffset(74, 26),
		ZIndex = 4,
		Visible = false,
	}, s)
	text(s, "Name", "", 11, HEAVY, WHITE, {
		Position = UDim2.fromOffset(0, 72),
		Size = UDim2.fromOffset(74, 22),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 5,
	})
	text(s, "Plus", "+", 30, HEAVY, WHITE, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 0.75,
	})
end

local powerList = make("ScrollingFrame", {
	Name = "List",
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(32, 394),
	Size = UDim2.fromOffset(COL + 8, 1080 - 394 - 24),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = WHITE,
	ScrollBarImageTransparency = 0.6,
	Active = true,
}, powers)
list(powerList, 8)
order = 0
section(powerList, "ALL POWERS", "6 / 12 OWNED")
order += 1
local grid = make("Frame", {
	Name = "Grid",
	BackgroundTransparency = 1,
	Size = UDim2.fromOffset(COL, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	LayoutOrder = order,
}, powerList)
make("UIGridLayout", {
	CellSize = UDim2.fromOffset(140, 178),
	CellPadding = UDim2.fromOffset(10, 10),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, grid)
for i, pw in POWERS do
	local def = modDef(pw.id)
	local roleColor = Theme.ROLE[def.role] or WHITE
	local t = make("ImageButton", {
		Name = "Tile" .. pw.id,
		BackgroundColor3 = CARD_PANEL,
		AutoButtonColor = false,
		Image = "",
		LayoutOrder = i,
		ClipsDescendants = true,
		ZIndex = 3,
	}, grid)
	corner(t, 8)
	for k, v in { Power = pw.id, Owned = pw.owned, InDeck = pw.deck, Level = pw.level } do
		t:SetAttribute(k, v)
	end
	make("ImageLabel", {
		Name = "Art",
		BackgroundTransparency = 1,
		Image = Theme.CARD_ART[pw.id] or "",
		ScaleType = Enum.ScaleType.Crop,
		Size = UDim2.fromOffset(140, 116),
		ImageTransparency = if pw.owned then 0 else 0.5,
		ZIndex = 3,
	}, t)
	make("Frame", {
		Name = "Band",
		BorderSizePixel = 0,
		BackgroundColor3 = if pw.owned then roleColor else hex("3A3C44"),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(70, 104),
		Size = UDim2.fromOffset(220, 120),
		Rotation = -5,
		ZIndex = 4,
	}, t)
	make("Frame", {
		Name = "Panel",
		BorderSizePixel = 0,
		BackgroundColor3 = CARD_PANEL,
		Position = UDim2.fromOffset(0, 146),
		Size = UDim2.fromOffset(140, 32),
		ZIndex = 5,
	}, t)
	text(
		t,
		"Name",
		string.upper(def.name),
		18,
		HEAVY,
		WHITE,
		{ Position = UDim2.fromOffset(10, 116), Size = UDim2.fromOffset(124, 22), ZIndex = 6 }
	)
	if pw.owned then
		text(
			t,
			"Sub",
			string.upper(def.role),
			11,
			HEAVY,
			roleColor,
			{ Position = UDim2.fromOffset(10, 154), Size = UDim2.fromOffset(90, 14), ZIndex = 6 }
		)
		text(t, "Level", "LV " .. pw.level, 12, HEAVY, WHITE, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromOffset(130, 154),
			Size = UDim2.fromOffset(50, 14),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextTransparency = 0.2,
			ZIndex = 6,
		})
		local tag = make("Frame", {
			Name = "InDeck",
			BackgroundColor3 = hex("0B0C10"),
			BackgroundTransparency = 0.15,
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.fromOffset(70, 22),
			Visible = pw.deck,
			ZIndex = 6,
		}, t)
		corner(tag, 4)
		text(tag, "L", "IN DECK", 11, HEAVY, CYAN, {
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 7,
		})
	else
		icon(t, "Lock", ICON.lock, 10, 153, 14, { ImageColor3 = hex("C8CCD4"), ZIndex = 6 })
		text(
			t,
			"Sub",
			"POWER CASE",
			11,
			HEAVY,
			DIM,
			{ Position = UDim2.fromOffset(28, 154), Size = UDim2.fromOffset(100, 14), ZIndex = 6 }
		)
	end
	make("Frame", {
		Name = "Sel",
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 6),
		Visible = pw.id == "Dash",
		ZIndex = 8,
	}, t)
end

-- RIGHT -------------------------------------------------------------------------------------------------
local stack = make("Frame", {
	Name = "Stack",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 0),
	Size = UDim2.new(0, COL, 1, -28),
}, Right)
list(stack, 10, true)

local function details(
	parent: Instance,
	name: string,
	role: string,
	roleColor: Color3,
	blurb: string,
	order: number
): Frame
	local d = panel(parent, "Details", COL, 140, order)
	slash(d, 20, 20, 36, roleColor)
	soft(
		text(
			d,
			"Name",
			string.upper(name),
			46,
			HEAVY,
			WHITE,
			{ Position = UDim2.fromOffset(38, 12), Size = UDim2.fromOffset(330, 52) }
		),
		0.7
	)
	text(
		d,
		"Role",
		role,
		16,
		HEAVY,
		roleColor,
		{ Position = UDim2.fromOffset(40, 64), Size = UDim2.fromOffset(330, 20) }
	)
	text(d, "Blurb", blurb, 17, MED, MUTED, {
		Position = UDim2.fromOffset(40, 88),
		Size = UDim2.fromOffset(COL - 64, 42),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	icon(d, "Favorite", ICON.star, COL - 52, 18, 32, { ImageTransparency = 0.55 })
	return d
end
local function level(
	parent: Instance,
	lv: number,
	xp: number,
	need: number,
	reward: string,
	at: number,
	colors: { Color3 },
	order: number
): Frame
	local c = panel(parent, "Level", COL, 124, order)
	text(
		c,
		"LV",
		"LV",
		18,
		HEAVY,
		MUTED,
		{ Position = UDim2.fromOffset(20, 26), Size = UDim2.fromOffset(30, 20) }
	)
	soft(
		text(
			c,
			"Number",
			tostring(lv),
			46,
			HEAVY,
			WHITE,
			{ Position = UDim2.fromOffset(48, 8), Size = UDim2.fromOffset(70, 50) }
		),
		0.7
	)
	text(c, "Xp", string.format("%d / %d XP", xp, need), 15, BOLD, MUTED, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromOffset(COL - 20, 16),
		Size = UDim2.fromOffset(200, 18),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	bar(c, "Bar", 124, 40, COL - 144, 12, xp / need, colors)
	local row = make("Frame", {
		Name = "Reward",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 68),
		Size = UDim2.fromOffset(COL, 48),
	}, c)
	icon(row, "Icon", ICON.reward, 20, 8, 30)
	text(
		row,
		"Text",
		"Reward at LV " .. at,
		19,
		HEAVY,
		WHITE,
		{ Position = UDim2.fromOffset(62, 12), Size = UDim2.fromOffset(220, 24) }
	)
	local chip = make("Frame", {
		Name = "Chip",
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.88,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromOffset(COL - 20, 9),
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		ZIndex = 4,
	}, row)
	corner(chip, 4)
	make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, chip)
	text(
		chip,
		"L",
		reward,
		15,
		HEAVY,
		WHITE,
		{ Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 5 }
	)
	return c
end
-- action rows: icon, title, subtitle, a big square button on the right (RIVALS' row pattern)
local function actions(parent: Instance, rows: { { any } }, order: number): Frame
	local c = panel(parent, "Actions", COL, 16 + #rows * 72, order)
	for i, r in rows do
		local y = 8 + (i - 1) * 72
		local row = make("Frame", {
			Name = r[1],
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.fromOffset(COL, 72),
		}, c)
		icon(row, "Icon", r[2], 20, 19, 34)
		text(
			row,
			"Title",
			r[3],
			23,
			HEAVY,
			WHITE,
			{ Position = UDim2.fromOffset(68, 12), Size = UDim2.fromOffset(220, 26) }
		)
		text(
			row,
			"Sub",
			r[4],
			15,
			MED,
			MUTED,
			{ Position = UDim2.fromOffset(68, 40), Size = UDim2.fromOffset(240, 18) }
		)
		button(row, "Button", COL - 136, 9, 120, 54, r[6] or BLUE, r[7], r[5], r[8])
		if i < #rows then
			make("Frame", {
				Name = "Line",
				BackgroundColor3 = WHITE,
				BackgroundTransparency = 0.9,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(20, 71),
				Size = UDim2.fromOffset(COL - 40, 1),
			}, row)
		end
	end
	return c
end
local function overview(parent: Instance, order: number): Frame
	local stats = {
		{ "DAMAGE", 0.62, "30 → 22" },
		{ "RANGE", 0.7, "60 studs" },
		{ "FIRE RATE", 0.6, "10 / s" },
		{ "HANDLING", 0.58, "0.6° spread" },
		{ "MOBILITY", 0.55, "100%" },
		{ "MAGAZINE", 0.5, "25" },
	}
	local c = panel(parent, "Overview", COL, 26 + #stats * 36, order)
	c.Visible = false
	for i, s in stats do
		local y = 14 + (i - 1) * 36
		text(
			c,
			"N" .. i,
			s[1],
			15,
			HEAVY,
			MUTED,
			{ Position = UDim2.fromOffset(20, y + 6), Size = UDim2.fromOffset(110, 18) }
		)
		bar(c, "B" .. i, 136, y + 10, 170, 10, s[2], { hex("F4F6F9"), hex("BFC5D0") })
		text(c, "V" .. i, s[3], 16, HEAVY, WHITE, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromOffset(COL - 20, y + 5),
			Size = UDim2.fromOffset(110, 20),
			TextXAlignment = Enum.TextXAlignment.Right,
		})
	end
	return c
end
local function bigButton(
	parent: Instance,
	name: string,
	label: string,
	colors: { Color3 },
	ink: boolean,
	order: number,
	img: string?
): Frame
	local holder = make("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(COL, 76),
		LayoutOrder = order,
		Active = true,
	}, parent)
	button(holder, "Button", 0, 0, COL, 76, colors, label, img, ink)
	return holder
end

local havoc = PRIMARY[1]
-- owned gun
local owned = make("Frame", {
	Name = "GunOwned",
	BackgroundTransparency = 1,
	Size = UDim2.fromOffset(COL, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	LayoutOrder = 1,
}, stack)
list(owned, 10)
details(owned, havoc.name, havoc.role, CYAN, havoc.blurb, 1)
level(owned, 12, 340, 500, "CHARM", 15, { hex("7CF0FF"), hex("1FB7D6") }, 2)
actions(owned, {
	{ "Contracts", ICON.contracts, "Contracts", "2 of 9 done · next: 100 elims", ICON.arrow },
	{ "OverviewRow", ICON.stats, "Overview", "Damage, range, fire rate", ICON.eye },
	{ "Statistics", ICON.target, "Statistics", "Your lifetime numbers", ICON.eye },
}, 3)
overview(owned, 4)
local equip = bigButton(owned, "Equip", "EQUIPPED", DARK, false, 5)
equip:SetAttribute("Kind", "Equip")

-- locked gun
local locked = make("Frame", {
	Name = "GunLocked",
	BackgroundTransparency = 1,
	Size = UDim2.fromOffset(COL, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	LayoutOrder = 2,
	Visible = false,
}, stack)
list(locked, 10)
local dead = PRIMARY[8]
details(locked, dead.name, dead.role, hex("C8CCD4"), dead.blurb, 1)
local unlock = panel(locked, "Unlock", COL, 160, 2)
do
	local function urow(name: string, y: number, title: string, sub: string)
		local row = make("Frame", {
			Name = name,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.fromOffset(COL, 72),
		}, unlock)
		text(
			row,
			"Title",
			title,
			23,
			HEAVY,
			WHITE,
			{ Position = UDim2.fromOffset(20, 12), Size = UDim2.fromOffset(220, 26) }
		)
		text(
			row,
			"Sub",
			sub,
			15,
			MED,
			MUTED,
			{ Position = UDim2.fromOffset(20, 40), Size = UDim2.fromOffset(220, 18) }
		)
		return row
	end
	local buy = urow("Buy", 8, "Unlock now", "Yours forever, every mode")
	local b = button(buy, "Button", COL - 196, 8, 180, 58, GOLD, "1,500", ICON.coin, true)
	local coinIcon = b:FindFirstChild("Icon")
	if coinIcon and coinIcon:IsA("ImageLabel") then
		coinIcon.ImageColor3 = WHITE -- the coin keeps its own colours
	end
	local try = urow("Try", 80, "Try it first", "Free in the Range")
	button(try, "Button", COL - 196, 8, 180, 58, BLUE, "TRY", ICON.target)
end
actions(
	locked,
	{ { "OverviewRow", ICON.stats, "Overview", "Damage, range, fire rate", ICON.eye } },
	3
)

-- power
local power = make("Frame", {
	Name = "Power",
	BackgroundTransparency = 1,
	Size = UDim2.fromOffset(COL, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	LayoutOrder = 3,
	Visible = false,
}, stack)
list(power, 10)
local dash = modDef("Dash")
details(
	power,
	dash.name,
	"MOBILITY · ONCE PER ROUND",
	Theme.ROLE.Mobility,
	dash.levels.L1.note .. ".",
	1
)
level(power, 4, 120, 200, "CARD STYLE", 5, { hex("7CF0FF"), hex("1FB7D6") }, 2)
local paths = panel(power, "Paths", COL, 52 + 3 * 64, 3)
slash(paths, 18, 14, 18)
text(
	paths,
	"Head",
	"UPGRADES IN THE DRAFT",
	17,
	HEAVY,
	MUTED,
	{ Position = UDim2.fromOffset(34, 12), Size = UDim2.fromOffset(330, 20) }
)
for i, p in { "A", "B", "G" } do
	local y = 44 + (i - 1) * 64
	local isG = p == "G"
	local col = if isG then GLITCH else Theme.ROLE.Mobility
	local row = make("Frame", {
		Name = "Path" .. p,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.fromOffset(COL, 64),
	}, paths)
	local chip = make("Frame", {
		Name = "Chip",
		BackgroundColor3 = col,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(20, 10),
		Size = UDim2.fromOffset(42, 42),
		ZIndex = 4,
	}, row)
	corner(chip, 6)
	text(
		chip,
		"L",
		p,
		24,
		HEAVY,
		INK,
		{ Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5 }
	)
	text(
		row,
		"Name",
		string.upper(dash.paths[p]),
		21,
		HEAVY,
		if isG then GLITCH else WHITE,
		{ Position = UDim2.fromOffset(76, 8), Size = UDim2.fromOffset(330, 24) }
	)
	text(row, "Note", pathNote(dash, p), 14, MED, MUTED, {
		Position = UDim2.fromOffset(76, 34),
		Size = UDim2.fromOffset(COL - 96, 18),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
end
actions(power, {
	{ "Preview", ICON.play, "See it in action", "A short clip of the power", ICON.play },
	{ "Statistics", ICON.target, "Statistics", "Rounds won with it, uses", ICON.eye },
}, 4)
local deckButton = bigButton(power, "DeckButton", "IN DECK · REMOVE", DARK, false, 5)
deckButton:SetAttribute("Kind", "Deck")

-- CENTER: the lock over a locked gun --------------------------------------------------------------------
local lockPlate = make("Frame", {
	Name = "Lock",
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.25,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(150, 150),
	Visible = false,
	ZIndex = 3,
}, Center)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, lockPlate)
icon(
	lockPlate,
	"Icon",
	ICON.lock,
	0,
	0,
	74,
	{ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) }
)

-- BOTTOM: round buttons + the drag hint -----------------------------------------------------------------
local gunBar = make("Frame", {
	Name = "GunBar",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(160, 40),
	Size = UDim2.fromOffset(440, 128),
}, Bottom)
roundButton(gunBar, "Back", 0, "Back", ICON.close, RED)
roundButton(gunBar, "Skin", 110, "Skin", ICON.skin, DARK)
roundButton(gunBar, "Charm", 220, "Charm", ICON.charm, DARK)
roundButton(gunBar, "KillFx", 330, "Kill FX", ICON.skull, DARK)
local powerBar = make("Frame", {
	Name = "PowerBar",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(270, 40),
	Size = UDim2.fromOffset(220, 128),
	Visible = false,
}, Bottom)
roundButton(powerBar, "Back", 0, "Back", ICON.close, RED)
roundButton(powerBar, "Flip", 110, "Flip", ICON.card, DARK)
local hint = text(Bottom, "Hint", "DRAG TO TURN IT", 15, HEAVY, WHITE, {
	Position = UDim2.fromOffset(0, 4),
	Size = UDim2.new(1, 0, 0, 20),
	TextXAlignment = Enum.TextXAlignment.Center,
	TextTransparency = 0.35,
})
soft(hint, 0.6)

-- STAGE ---------------------------------------------------------------------------------------------------
-- (in ReplicatedStorage: parts under a ScreenGui are dropped when StarterGui copies it into PlayerGui)
local oldStage = RS:FindFirstChild("LockerV3Stage")
if oldStage then
	oldStage:Destroy()
end
local stage = make("Folder", { Name = "LockerV3Stage" }, RS)
local showcase = make("Folder", { Name = "Showcase" }, stage)
local skins = SS:FindFirstChild("WeaponSkins")
for _, g in { PRIMARY, SECONDARY } do
	for _, gg in g :: { Gun } do
		local line = gg.skin
		local lineFolder = if line and skins then skins:FindFirstChild(line) else nil
		local src = if lineFolder then lineFolder:FindFirstChild(gg.id) else nil
		if src then
			local m = src:Clone()
			m.Name = gg.id
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanQuery = false
					d.CanTouch = false
				elseif d:IsA("Script") or d:IsA("LocalScript") then
					d:Destroy()
				end
			end
			m.Parent = showcase
		end
	end
end

-- the power card: the draft card's face (BuildDraftScreen "New", 400 x 500, drawn at 2x) on a thin card
local CW, CH, T = 2.12, 2.65, 0.045
local cardModel = make("Model", { Name = "PowerCard" }, stage)
local face = make("Part", {
	Name = "Face",
	Size = Vector3.new(CW, CH, T),
	Transparency = 1,
	Anchored = true,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
	CastShadow = false,
}, cardModel)
cardModel.PrimaryPart = face
make("Part", {
	Name = "Edge",
	Size = Vector3.new(CW - 0.05, CH - 0.05, T * 0.8),
	Color = Theme.ROLE.Mobility,
	Material = Enum.Material.SmoothPlastic,
	Anchored = true,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
	CastShadow = false,
}, cardModel)
local function surface(name: string, normal: Enum.NormalId): SurfaceGui
	return make("SurfaceGui", {
		Name = name,
		Face = normal,
		SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
		CanvasSize = Vector2.new(800, 1000),
		LightInfluence = 0,
		Brightness = 1.15,
		ClipsDescendants = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, face)
end
local front = surface("Front", Enum.NormalId.Front)
local fr = make("Frame", {
	Name = "Card",
	BackgroundColor3 = CARD_PANEL,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
}, front)
corner(fr, 18)
local art = make("ImageLabel", {
	Name = "Art",
	BackgroundTransparency = 1,
	Image = Theme.CARD_ART.Dash or "",
	ScaleType = Enum.ScaleType.Crop,
	Size = UDim2.fromOffset(800, 660),
	ZIndex = 1,
}, fr)
corner(art, 18)
make("Frame", {
	Name = "Band",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 572),
	Size = UDim2.fromOffset(1600, 520),
	Rotation = -4,
	BackgroundColor3 = Theme.ROLE.Mobility,
	BorderSizePixel = 0,
	ZIndex = 2,
}, fr)
local pnl = make("Frame", {
	Name = "Panel",
	Position = UDim2.fromOffset(0, 768),
	Size = UDim2.fromOffset(800, 232),
	BackgroundColor3 = CARD_PANEL,
	BorderSizePixel = 0,
	ZIndex = 3,
}, fr)
corner(pnl, 18)
make("Frame", {
	Name = "PanelTop",
	Position = UDim2.fromOffset(0, 768),
	Size = UDim2.fromOffset(800, 40),
	BackgroundColor3 = CARD_PANEL,
	BorderSizePixel = 0,
	ZIndex = 3,
}, fr)
text(
	fr,
	"Title",
	string.upper(dash.name),
	72,
	HEAVY,
	WHITE,
	{ Position = UDim2.fromOffset(48, 606), Size = UDim2.fromOffset(704, 80), ZIndex = 4 }
)
text(fr, "Role", "MOBILITY", 24, HEAVY, WHITE, {
	Position = UDim2.fromOffset(52, 696),
	Size = UDim2.fromOffset(400, 30),
	TextTransparency = 0.15,
	ZIndex = 4,
})
text(fr, "Note", dash.levels.L1.note .. ".", 32, MED, hex("D6DAE2"), {
	Position = UDim2.fromOffset(48, 800),
	Size = UDim2.fromOffset(704, 100),
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 4,
})
text(
	fr,
	"Charges",
	"ONCE PER ROUND",
	24,
	HEAVY,
	DIM,
	{ Position = UDim2.fromOffset(48, 936), Size = UDim2.fromOffset(400, 30), ZIndex = 4 }
)
text(fr, "Level", "LV 4", 26, HEAVY, WHITE, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromOffset(752, 934),
	Size = UDim2.fromOffset(200, 32),
	TextXAlignment = Enum.TextXAlignment.Right,
	ZIndex = 4,
})
local shineF = make("Frame", {
	Name = "Shine",
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 0,
	Size = UDim2.fromScale(1, 1),
	ZIndex = 9,
}, fr)
corner(shineF, 18)
make("UIGradient", {
	Name = "Sweep",
	Rotation = 24,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(0.5, 0.7),
		NumberSequenceKeypoint.new(0.58, 1),
		NumberSequenceKeypoint.new(1, 1),
	}),
	Offset = Vector2.new(-0.4, 0),
}, shineF)

local back = surface("Back", Enum.NormalId.Back)
local bk = make("Frame", {
	Name = "Card",
	BackgroundColor3 = CARD_PANEL,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
}, back)
corner(bk, 18)
make("Frame", {
	Name = "Band",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.56),
	Size = UDim2.fromOffset(1600, 150),
	Rotation = -12,
	BackgroundColor3 = Theme.ROLE.Mobility,
	BorderSizePixel = 0,
	ZIndex = 2,
}, bk)
make("ImageLabel", {
	Name = "Logo",
	BackgroundTransparency = 1,
	Image = ICON.logo,
	ScaleType = Enum.ScaleType.Fit,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.42),
	Size = UDim2.fromOffset(600, 420),
	ZIndex = 3,
}, bk)
text(bk, "Foot", "POWER CARD", 30, HEAVY, WHITE, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 900),
	Size = UDim2.fromOffset(600, 36),
	TextXAlignment = Enum.TextXAlignment.Center,
	TextTransparency = 0.5,
	ZIndex = 3,
})

-- the preview LocalScript: its Source is tools/studio/LockerV3Preview.luau, pasted in by a second command-bar run
-- (game.StarterGui.LockerV3.Preview.Source = [==[ <that file> ]==]); a re-build keeps the old Source.
local preview = make("LocalScript", { Name = "Preview" }, gui)
preview.Source = previewSource

gui.Parent = SG
return "LockerV3 built: " .. #showcase:GetChildren() .. " showcase guns"
