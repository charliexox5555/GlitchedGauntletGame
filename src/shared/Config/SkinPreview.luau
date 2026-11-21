--!strict
-- Skin preview: pick a skin line for your guns (F7 cycles, \ cycles, ; opens
-- the list). A dev tool: Studio, or USER_IDS in live servers. Real skins are
-- owned (Shared/PlayerData) and equipped in the Lobby's Locker.
--
-- Each player's line is their own: a Player attribute (ATTRIBUTE) the server
-- sets from the REMOTE request; your camera guns and your world gun (seen by
-- everyone) follow it. Works in Studio and, with LIVE on, in live servers of
-- the match place (owner 2026-11-14: "check out skins out of Studio").
local RunService = game:GetService("RunService")

local shadowMistLine = "RuinBlighted"
local lines = {
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
	"Poolside",
	"Rootglass",
}
if RunService:IsStudio() then
	table.insert(lines, shadowMistLine)
	table.insert(lines, "TempestStrike") -- elite hero in progress (Vandal only), Studio preview
end

return table.freeze({
	PLACE_ID = 133387545285290,
	LIVE = true, -- also outside Studio (live servers of PLACE_ID)
	-- Live servers: UserIds allowed to use the F7 picker; empty = nobody (skins are
	-- owned since 2026-11-20; the Locker's owned equips still show everywhere).
	USER_IDS = table.freeze({} :: { number }),
	ATTRIBUTE = "PreviewSkinLine",
	REMOTE = "PreviewSkinLine",
	RATE = table.freeze({ 1, 3 }), -- requests per second, burst (Util/RateLimit): a few quick presses, then 1 / s
	LINES = table.freeze(lines),
	-- Tempest-Strike idle (Util/TempestIdle): laminar water ribbons along the fore-end,
	-- a circulating ring at the stock hub, sparse vent sparks. First person only.
	TEMPEST = table.freeze({
		LINE = "TempestStrike",
		WATER = Color3.fromRGB(95, 230, 224),
		WATER_EDGE = Color3.fromRGB(214, 255, 252),
		RIBBON_WIDTH = 0.022, -- model studs, scaled with the viewmodel
		RIBBON_SPEED = 1.2, -- flow scroll (Beam.TextureSpeed)
		RIBBON_BODY = 0.45, -- transparency of the continuous water line
		FLOW_TILE = 0.25, -- flow streak texture length (studs, scaled)
		HELIX_LIFT = 0.02, -- clearance off the fore-end surface
		HELIX_TURNS = 1.25, -- wraps around the fore-end
		HELIX_POINTS = 14,
		RING_SPEED = 1.4,
		RING_RADIUS = 0.058,
		SPARK_RATE = 5, -- per arc emitter (two on the handguard top)
		SPARK_SIZE = 0.05,
		SPARK_LIFE = NumberRange.new(0.10, 0.17),
		LIGHT_BRIGHTNESS = 0.9,
		LIGHT_RANGE = 1.1,
		ADS_RIBBON = 0.35, -- ribbon opacity kept at full ADS
		ADS_SPARK_CUTOFF = 0.5, -- sparks stop above this aim weight
	}),
	SHADOW_MIST = table.freeze({
		LINE = shadowMistLine,
		PERIOD = 3.35,
		SHARD_TRAVEL = 0.14, -- model studs, scaled with the viewmodel
		SHARD_TILT = math.rad(11),
		ADS_SHARD_WEIGHT = 0.32,
		ADS_SIGHT_WEIGHT = 0.82,
		TINT_PEAK = Color3.fromRGB(135, 235, 209),
		MIST_TINT = Color3.fromRGB(74, 182, 156),
		MIST_RATE = 4, -- per attachment
		LIGHT_RANGE = 1.10,
		LIGHT_BRIGHTNESS = 1.9,
		ADS_LIGHT = 0.94,
		DRAW_LOCK = 0.66,
		INSPECT_SPREAD = 0.30,
		INSPECT_CLOSE = 0.77,
		INSPECT_LOCK = 0.90,
		RELOAD_FORM = 0.36,
		RELOAD_GRAB = 0.47,
		RELOAD_THROW = 0.52,
		RELOAD_SEAT = 0.63,
		SHOT_TINT = Color3.fromRGB(81, 244, 210),
		SHOT_PREVIEW = "rbxassetid://94301133893352",
		LOCK_SOUND = "gun:impact_hard",
		COALESCE_SOUND = "gun:whoosh_swish_small_01",
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
