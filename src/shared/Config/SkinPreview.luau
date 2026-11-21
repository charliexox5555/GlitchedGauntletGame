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
local VFX = require(script.Parent.VfxTextures)

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
		RIBBON_WIDTH = 0.072, -- model studs, scaled with the viewmodel
		RIBBON_SPEED = 0.9, -- water scroll (Beam.TextureSpeed)
		RIBBON_BODY = 0, -- transparency of the textured water ribbon
		RIBBON_BRIGHTNESS = 1.9,
		CORE_WIDTH = 0.35, -- solid core line, fraction of the ribbon width
		CORE_BODY = 0.5,
		RIBBON_TILE = 0.32, -- ribbon texture length (studs, scaled)
		HELIX_LIFT = 0.02, -- clearance off the fore-end surface
		HELIX_TURNS = 1.25, -- wraps around the fore-end
		HELIX_POINTS = 14,
		SPARK_RATE = 2.2, -- per arc emitter (receiver cowl, handguard top, handguard blade)
		SPARK_SIZE = 0.11,
		SPARK_LIFE = NumberRange.new(0.06, 0.11),
		ARC_CORE = Color3.fromRGB(244, 255, 255),
		LIGHT_BRIGHTNESS = 1.2,
		LIGHT_RANGE = 2.2,
		GLOW_PEAK = Color3.fromRGB(150, 255, 250), -- Neon conduits breathe toward this
		GLOW_MIX = 0.55,
		GLOW_RATE = 2.1, -- radians per second
		ADS_RIBBON = 0.2, -- ribbon opacity kept at full ADS (0.35 sat on the front post)
		ADS_SPARK_CUTOFF = 0.5, -- sparks stop above this aim weight
		-- shot (Util/TempestFx): shuriken flash, port mist, light pop, splash impacts
		SHOT_TINT = Color3.fromRGB(120, 240, 236), -- tracer colour
		TRACER_WAKE = VFX.TEMPEST_WATER_TRACER, -- the tracer's trail: a scrolling water streak
		FLASH_CORE = Color3.fromRGB(236, 255, 255),
		FLASH_TIME = 0.055, -- about three frames at 60 fps
		FLASH_FRONT = VFX.TEMPEST_FLASH_FRONT_2x2,
		FLASH_FRONT_FLIPBOOK = true,
		FLASH_SIDE = VFX.TEMPEST_FLASH_SIDE_2x2,
		DROPLETS = VFX.TEMPEST_DROPLETS_2x2,
		DROPLETS_FLIPBOOK = true,
		SPLASH = VFX.TEMPEST_SPLASH_2x2,
		SPLASH_FLIPBOOK = true,
		STATIC_MARK = VFX.TEMPEST_STATIC_MARK,
		STATIC_TIME = 0.7,
		FLASH_LIGHT = 1.6, -- stock fast-gun pop (MuzzleFx); more strobes or blooms the view
		FLASH_LIGHT_RANGE = 8,
		FLASH_BRIGHTNESS = 1.6, -- under the place Bloom threshold (2)
		FLASH_LIGHT_TIME = 0.06,
		ARC = VFX.TEMPEST_ARC_2x2,
		IMPACT_LIGHT = 1.4, -- the cyan pop where a shot lands
		MUZZLE_RING_TIME = 0.13, -- the water ring round the bore per shot
		MUZZLE_RING_SPEED = 2.2,
		MUZZLE_RING_SIZE = 0.42,
		-- actions (Util/TempestIdle): draw ring, reload dissolve + gather, inspect float
		COAT_COLOR = Color3.fromRGB(140, 240, 255), -- the water coat (Util/TempestCoat, ForceField copies)
		COAT_OPACITY = 0.62,
		COAT_SCALE = 1, -- no scale: long parts would poke out at their ends
		COAT_PAD = 0.014, -- studs added round each copy (scaled)
		COAT_MIN_PART = 0.02, -- thinner parts get no copy
		FORM_RADIUS = 0.3, -- the ball the water beads converge from (model studs)
		FORM_RATE = 90, -- beads per second while the new magazine forms
		TRAIL_LIFE = 0.16, -- water trails off the muzzle and stock (inspect, reload spin)
		SIGHT_X = 0.078, -- the crescent (Blender units): its plane...
		SIGHT_TIP_Y = 0.041, -- ...its tips (measured: the screen tips projected onto the AimPoint plane)
		SIGHT_TIP_Z = 0.62,
		SIGHT_APEX_Z = 0.645, -- ...and where the arc peaks over the window
		SIGHT_ARC_WIDTH = 0.03,
		SIGHT_ARC_TIME = 0.07, -- seconds a crackle shows...
		SIGHT_ARC_GAP = { 0.35, 1.1 }, -- ...and the random gap between them
		SIGHT_SPARK = 0.035,
		SIGHT_ARC_BRIGHTNESS = 2.6,
		FORM_SOLID = 0.5, -- share of MagIn -> seat the new magazine stays water
		SHOT_COAT = 0.22, -- a flicker of the coat per hip shot
		SIGHT_FLASH = 0.8, -- the sight's shimmer entering ADS...
		SIGHT_FLASH_TIME = 0.35, -- ...fading over this
		SHOT_PULSE = 2.4, -- extra helix brightness in the per-shot pulse
		SHOT_PULSE_TIME = 0.1, -- seconds for the pulse to run receiver to muzzle
		SHOT_ARC_CHANCE = 0.45,
		BOOST_SHOT = 0.35, -- conduit flare per shot (0..1, decays at BOOST_DECAY / s)
		BOOST_SEAT = 0.9, -- flare when the new magazine seats or the draw locks
		BOOST_DECAY = 3.5,
		RELOAD_DRAIN = 0.75, -- how far the conduits dim while the magazine is out
		DRAINED = Color3.fromRGB(28, 70, 78),
		WELL = Vector3.new(0, 0.12, -0.6), -- magwell mouth (measured: Mag bone at 0.155, -0.583) (Handle space, model studs)
		RING_POINTS = 12,
		RING_BRIGHTNESS = 1.15,
		RING_SPIN = 5, -- radians per second
		DRAW_RING = 0.4, -- the ring reaches the receiver (DrawTempest snaps level at 0.34)
		INSPECT_ROLL_IN = 0.465, -- InspectTempest toss: the barrel roll starts...
		INSPECT_CATCH = 0.61, -- ...and the hands catch it
		INSPECT_RING_X = 1.2, -- the roll ring: round the middle of the gun (Blender x)
		INSPECT_RING_R = 0.34,
		INSPECT_SPARKS = 3, -- arc rate multiplier while inspecting
		KICK_PITCH = math.rad(1.0), -- skin kick on top of the stock recoil
		KICK_ROLL = math.rad(1.2),
		KICK_BACK = 0.008,
		KICK_TIME = 0.24,
		SEAT_POP = 0.012,
		HOVER = 0.003,
		FLOURISH_AFTER = { 7, 11 }, -- seconds standing still before an idle flourish
		FLOURISH_TIME = 1.8,
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
