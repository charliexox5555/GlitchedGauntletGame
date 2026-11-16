--!strict
-- Skin preview: pick a skin line for your guns (F7 cycles, \ cycles, ; opens
-- the list). Cosmetic only: no ownership, purchases or saving. Independent of
-- shared/TestMode.
--
-- Each player's line is their own: a Player attribute (ATTRIBUTE) the server
-- sets from the REMOTE request; your camera guns and your world gun (seen by
-- everyone) follow it. Works in Studio and, with LIVE on, in live servers of
-- the match place (owner 2026-11-14: "check out skins out of Studio").
return table.freeze({
	PLACE_ID = 133387545285290,
	LIVE = true, -- also outside Studio (live servers of PLACE_ID)
	-- Live servers: UserIds allowed to use it; empty = every player.
	USER_IDS = table.freeze({} :: { number }),
	ATTRIBUTE = "PreviewSkinLine",
	REMOTE = "PreviewSkinLine",
	RATE = table.freeze({ 1, 3 }), -- requests per second, burst (Util/RateLimit): a few quick presses, then 1 / s
	LINES = table.freeze({
		"Stock",
		"Prism",
		"Redline",
		"Nitrous",
		"PopCircuit",
		"Moltframe",
		"Giltfold",
		"Inkshift",
		"Sealwork",
		"Payload",
		"Oilwake",
		"Misprint",
		"Faultline",
		"Playback",
		"Breakwater",
		"Sundial",
	}),
	KEY = Enum.KeyCode.F7,
	CYCLE_KEY = Enum.KeyCode.BackSlash,
	MENU_KEY = Enum.KeyCode.Semicolon,
	-- Moltframe chamber motion (camera guns only; world models keep the static map).
	-- Each chamber part carries two flow Texture layers tagged with the Layer attribute.
	CHAMBER_FLOW = table.freeze({
		TAG_ATTRIBUTE = "MoltframeFlowLayer", -- 1 or 2 on each flow Texture
		LAYERS = table.freeze({
			table.freeze({ speedU = 0.045, speedV = 0.012 }), -- broad drift (studs / s)
			table.freeze({ speedU = -0.03, speedV = -0.018 }), -- finer counter-drift
		}),
		PULSE_ATTRIBUTE = "MoltframeChamberPulse", -- on the chamber SurfaceAppearance
		PULSE_PERIOD = 6, -- seconds, matches the Blender loop
		PULSE_TINT = Color3.fromRGB(232, 214, 255), -- peak multiplier on the base map
		MAX_STEP = 0.1, -- clamp dt after a hitch
	}),
})
