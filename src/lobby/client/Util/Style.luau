--!strict
-- Lobby UI v2 theme (vault/01 Design/Lobby UI and Queue.md section 8; Figma
-- "Lobby v2 · Tokens"). EVERY colour, font, size, radius, stroke, shadow and
-- look flag the lobby UI uses lives here, so restyling is a data change: edit a
-- value, re-sync, done. Builders (Util/Kit) and controllers read these tokens
-- and never hold their own hex values.
-- Sizes are design px: the desktop canvas is 1920 x 1080, the phone canvas
-- 800 x 420 (Util/Layout scales each cluster); top-bar chips are real px so
-- they match Roblox's own 44 px top-bar buttons.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local function hex(h: string): Color3
	return Color3.fromHex(h)
end

local function font(family: string, weight: Enum.FontWeight): Font
	return Font.new("rbxasset://fonts/families/" .. family .. ".json", weight)
end

export type TextStyle = { font: Font, size: number }

local Style = {}

-- Look switches.
Style.FLAGS = table.freeze({
	-- Full-screen menus hide Roblox's chat window and player list while open
	-- (restored on close), so nothing in a menu sits under them.
	hideCoreUiInMenus = true,
	-- Soft stacked shadow under panels, tiles and cards.
	shadows = true,
	-- Light sweep across tiles and buttons on hover.
	shine = true,
})

Style.COLOR = table.freeze({
	-- Surfaces: the fill colour is the TOP of the panel; a gradient darkens it
	-- toward the bottom by `SHADE.bottom`.
	surface = hex("1C2531"),
	surfaceHover = hex("2A3647"),
	surfaceSelected = hex("243246"),
	surfaceDeep = hex("0B0F15"), -- key chips, tracks, sunken wells
	scrim = hex("070A0F"),
	stroke = hex("FFFFFF"), -- used at ALPHA.stroke
	shadow = hex("000000"),

	text = hex("FFFFFF"),
	textSecondary = hex("C8D0DB"), -- about 11:1 on the surface
	textMuted = hex("A6B0BE"), -- about 7.5:1 on the surface (never below 4.5:1)

	-- The one "act now" colour: PLAY, FIND MATCH, the level, the coin.
	primary = hex("FFC83D"),
	primaryTop = hex("FFD95E"),
	primaryBottom = hex("FFB01A"),
	primaryLip = hex("B37709"),
	onPrimary = hex("1A1200"),

	success = hex("3FD68A"),
	danger = hex("FF4D5E"),
	info = hex("27B7FF"),

	-- Teams (match colours) and the rare glitch accent.
	ally = Theme.COLORS.ally,
	enemy = Theme.COLORS.enemy,
	glitch = Theme.COLORS.glitch,
	white = Color3.new(1, 1, 1),
})

-- Mode accents, taken from the Lobby world's pad colours (Lobby Style Guide).
Style.MODE = table.freeze({
	["1v1"] = hex("FF7A2F"),
	["2v2"] = hex("27B7FF"),
	["3v3"] = hex("A15CFF"),
} :: { [string]: Color3 })

-- Transparency values (0 = solid).
Style.ALPHA = table.freeze({
	surface = 0.06,
	chip = 0.1, -- top-bar chips over the world
	stroke = 0.86, -- 2 px white at 14%: a clean light edge on dark glass
	strokeHover = 0.55,
	strokeOnPrimary = 0.55,
	scrim = 0.38,
	deep = 0.35,
})

-- Gradients: multiply the fill from white (top) to this colour (bottom).
Style.SHADE = table.freeze({
	bottom = hex("A3ACB8"), -- 1C2531 top → about 121922 bottom
})

Style.FONT = table.freeze({
	-- Montserrat Heavy matches the Lobby's Montserrat Black 3D signs.
	display = font("Montserrat", Enum.FontWeight.Heavy),
	-- Builder Sans for labels and body (LihFolk: Gotham is retired).
	label = font("BuilderSans", Enum.FontWeight.ExtraBold),
	bodyBold = font("BuilderSans", Enum.FontWeight.Bold),
	body = font("BuilderSans", Enum.FontWeight.SemiBold),
})

-- Type scale (design px). The text floor in Util/Layout keeps every label at
-- 14 px drawn or more.
Style.TEXT = table.freeze({
	hero = { font = Style.FONT.display, size = 120 }, -- MATCH FOUND
	mode = { font = Style.FONT.display, size = 104 }, -- 1V1 on a card
	play = { font = Style.FONT.display, size = 52 }, -- PLAY
	title = { font = Style.FONT.display, size = 56 }, -- menu titles
	action = { font = Style.FONT.display, size = 44 }, -- FIND MATCH
	number = { font = Style.FONT.display, size = 26 }, -- timers in pills
	timer = { font = Style.FONT.display, size = 56 }, -- the big queue timer
	heading = { font = Style.FONT.label, size = 24 },
	label = { font = Style.FONT.label, size = 16 },
	labelS = { font = Style.FONT.label, size = 15 },
	body = { font = Style.FONT.body, size = 18 },
	bodyS = { font = Style.FONT.body, size = 15 },
	name = { font = Style.FONT.label, size = 17 },
} :: { [string]: TextStyle })

-- Corner radii. Nested shapes use outer − gap (LihFolk UI Spec).
Style.RADIUS = table.freeze({
	xs = 6,
	sm = 10,
	md = 14,
	lg = 18,
	xl = 22,
	pill = 999, -- clamped to half the height by UICorner
})

-- Stroke widths in drawn px (snapped to whole pixels by Util/Layout).
Style.STROKE = table.freeze({
	base = 2,
	selected = 3,
	focus = 3,
})

Style.SPACE = table.freeze({ xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xxl = 32, xxxl = 48 })

-- Depth.
Style.LIP = 6 -- the darker base under primary buttons; the face sinks on press
Style.SHADOW = table.freeze({
	-- Stacked rounded layers below a surface: { grow px, drop px, transparency }.
	layers = {
		{ 2, 3, 0.72 },
		{ 6, 7, 0.86 },
		{ 12, 12, 0.93 },
	},
})

-- The breathing glow around PLAY / FIND MATCH: { grow px, transparency },
-- pulsing to `peak` times its strength every `period` seconds.
Style.GLOW = table.freeze({
	layers = {
		{ 3, 0.7 },
		{ 8, 0.85 },
		{ 14, 0.93 },
	},
	peak = 1.8,
	period = 1.4,
})

-- Roblox top-bar row (GuiService.TopbarInset). Chips are real px.
Style.TOPBAR = table.freeze({
	height = 44, -- Roblox's own button height
	gap = 8, -- between our chips
	lead = 4, -- after Roblox's buttons
	edge = 12, -- right edge margin
	fallbackTop = 12, -- console / no top bar: margin from the safe-area top
	headshot = 36,
	coin = 28,
})

-- Per-family layout sizes (design px on each family's canvas).
Style.DOCK = table.freeze({
	desktop = table.freeze({
		tileW = 128,
		tileH = 104,
		playW = 300,
		playH = 112,
		gap = 12,
		bottom = 24,
		radius = 16,
		playRadius = 18,
		icon = 40,
		pillW = 600,
		pillH = 64, -- CANCEL inside is 58: 44 px drawn at the 0.76 HUD floor
		cancelBadge = 0, -- desktop uses the pill's CANCEL
	}),
	phone = table.freeze({
		tileW = 92,
		tileH = 80,
		playW = 172,
		playH = 88,
		gap = 8,
		bottom = 10,
		radius = 14,
		playRadius = 16,
		icon = 30,
		pillW = 520,
		pillH = 60,
		cancelBadge = 60, -- the CANCEL badge on PLAY while searching (44+ px drawn)
	}),
})

-- Menu chrome.
Style.MENU = table.freeze({
	desktop = table.freeze({
		header = Vector2.new(96, 96),
		close = Vector2.new(1824, 96),
		closeSize = 64, -- 46 px drawn at 1366 x 768
	}),
	phone = table.freeze({
		header = Vector2.new(24, 6),
		close = Vector2.new(780, 4),
		closeSize = 60, -- 45 px drawn on a 667 x 375 phone
	}),
})

return table.freeze(Style)
