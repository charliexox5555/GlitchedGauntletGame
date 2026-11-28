--!strict
-- Skin preview: pick a skin line for your guns (F7 cycles, \ cycles, ; opens
-- the list). A dev tool: Studio, or USER_IDS in live servers. Real skins are
-- owned (Shared/PlayerData) and equipped in the Lobby's Locker.
--
-- Each player's line is their own: a Player attribute (ATTRIBUTE) the server
-- sets from the REMOTE request; your camera guns and your world gun (seen by
-- everyone) follow it. Works in Studio and, with LIVE on, in live servers of
-- the match place (owner 2026-11-14: "check out skins out of Studio").
local VFX = require(script.Parent.VfxTextures)
local ServerRole = require(script.Parent.Parent.ServerRole)

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
	"Slipframe",
	"Riftforge",
	shadowMistLine,
	"TempestStrike",
	"Arcade",
	"Frostbite",
}

return table.freeze({
	supportsPlace = function(placeId: number): boolean
		return placeId == ServerRole.LOBBY_PLACE_ID or placeId == ServerRole.LEGACY_MATCH_PLACE_ID
	end,
	LIVE = true, -- supported live places
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
		-- the Katana (Util/TempestKatana): Blender units of the knife export
		-- (s05x). BLADE is the blade's outline guard -> tip ({ x, edge z, spine
		-- z }; the edge faces -Z), measured in Blender (Line Build Ledger,
		-- Runtime numbers); the water band is the lowest 0.016-0.040 of it.
		KATANA = table.freeze({
			BLADE = {
				{ 0.272, -0.07, 0.066 },
				{ 0.7, -0.061, 0.072 },
				{ 1.05, -0.046, 0.083 },
				{ 1.4, -0.028, 0.097 },
				{ 1.75, -0.004, 0.116 },
				{ 2.1, 0.022, 0.137 },
				{ 2.42, 0.051, 0.16 },
				{ 2.68, 0.078, 0.18 },
				{ 2.86, 0.105, 0.195 },
				{ 2.98, 0.141, 0.205 },
				{ 3.1, 0.206, 0.206 },
			},
			EDGE_LIFT = 0.012, -- the band's middle above the edge line
			EXPORT_WATER = Color3.fromRGB(64, 245, 212), -- TS Water as the flat export carries it
			EDGE_COLOR = Color3.fromRGB(70, 185, 182), -- the edge burns water cyan (Neon)...
			SKIN_PAD = 0.014, -- ...under a shimmering ForceField skin
			SKIN_OPACITY = 0.3,
			SEGMENTS = 12, -- beam segments guard -> tip
			-- owner 2026-11-22: the glow "kind of covers up the knife body" and "didn't
			-- follow the knife": a slimmer sheath that hugs the edge (the blade is 0.14
			-- tall), everything locked to the blade
			HALO_WIDTH = { 0.075, 0.1 }, -- the glowing sheath over the edge (glow band), guard -> tip
			HALO_BRIGHTNESS = 1.3,
			HALO_TRANSPARENCY = 0.3,
			CORE_WIDTH = 0.022, -- the white-hot line down its middle
			CORE_BRIGHTNESS = 1.1,
			MOTE_AT = { 0.35, 0.6, 0.85 }, -- blade stations shedding sparkle motes...
			MOTE_RATE = 1.2, -- ...per second each
			DRIP_RATE = 1.2, -- water drips off the tip, per second
			ARC_TRAIL_BRIGHTNESS = 2.4, -- the bright arc the outer blade cuts
			FLARE_DECAY = 7, -- the hit flare fades at this rate (1/s)
			RIBBON_WIDTH = 0.018,
			RIBBON_OFFSET = 0.026, -- off the blade's centre plane, each side (at the guard)
			BOLT_POINTS = 7,
			BOLT_LIFT = 0.015, -- above the spine
			BOLT_WIDTH = 0.02,
			ARC_GAP = { 0.6, 1.6 }, -- seconds between spine flickers
			ARC_JITTER = 0.03,
			TRAIL_LIFE = 0.16,
			CLEAVE_SIZE = 4.2, -- the Cleave's crescent flash (studs, scaled)
			SURGE_GAIN = 1.0,
			LIGHT_AT = { 0.4, 0.85 }, -- blade stations of the two lights
			LIGHT = 0.55,
			LIGHT_SURGE = 1.4,
			LIGHT_RANGE = 2.2,
			RING_TURNS = 1, -- the pommel ring spins once into the palm on the draw...
			RING_SPIN_END = 0.2, -- ...by this much of the draw
			RING_AXIS = Vector3.yAxis, -- the ring hole's axis (bone space)
			DRAW_SURGE = { 0.3, 0.5 }, -- the surge runs guard -> tip (the wheel up into the hold)
			INSPECT_LIFT = 0.7, -- KatanaInspect: the wrist snaps it up tip-high
			-- its sounds (3.4 s): level lands 0.13, wave 0.18, lift lands 0.73, wave
			-- 0.78, back 0.95; snaps fire 0.12 s (0.035) ahead of the pose
			INSPECT_SFX = {
				{ 0.02, "inspect" },
				{ 0.095, "inspectSnap" },
				{ 0.18, "katanaWave" },
				{ 0.695, "inspectSnap" },
				{ 0.78, "katanaWave" },
				{ 0.915, "inspectSnap" },
				{ 0.975, "inspectSettle" },
			},
			DRAW_SNAP = 0.3, -- KatanaDraw: the wheel's whoosh (peaks as it passes the left, ~0.4)
			INSPECT_WAVES = { { 0.18, 0.34 }, { 0.78, 0.9 } }, -- waves down the level blade, then the raised one
			CHARM_AXIS = Vector3.new(1, 1, 0).Unit, -- the charm swings about this (bone space)
			CHARM_HANG = 0.0638, -- the charm pivot sits this far under the ring centre (rides the ring spin)
			CHARM_FREQ = 2.2,
			CHARM_DAMP = 0.22,
			CHARM_KICK = 260, -- degrees/s per move
			CHARM_IDLE = 4, -- degrees of idle sway
		}),
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
		SIGHT_ARC_WIDTH = 0.03,
		SIGHT_ARC_TIME = 0.07, -- seconds a crackle shows...
		SIGHT_ARC_GAP = { 0.35, 1.1 }, -- ...and the random gap between them
		SIGHT_SPARK = 0.035,
		SIGHT_ARC_BRIGHTNESS = 2.6,
		-- moving parts (s08 rig joints, Util/TempestIdle): springs, degrees
		VENT_ANGLE = 13, -- the handguard vents' full flare (yaw out about the rear hinge)
		VENT_ROLL = 6, -- and how far they tip out
		VENT_FREQ = 7, -- spring frequency (Hz) and damping (<1 overshoots)
		VENT_DAMP = 0.45,
		VENT_SHOT_KICK = 9, -- opening speed added per shot (open / s)
		CRESCENT_DRAW = -180, -- the crescent comes in turned half round
		CRESCENT_FREQ = 4.5,
		CRESCENT_DAMP = 0.5,
		CRESCENT_ADS_KICK = 420, -- degrees / s twist entering ADS (it springs back and locks)
		GATE_ANGLE = 55, -- the Marshal's loading gate: how far it flicks open per round...
		GATE_KICK = 14, -- ...the kick (open / s) and its spring
		GATE_FREQ = 5,
		GATE_DAMP = 0.5,
		CRESCENT_SHOT_KICK = 60, -- a small tick per hip shot, alternating
		FORM_SOLID = 0.5, -- share of MagIn -> seat the new magazine stays water
		SHOT_COAT = 0, -- no whole-gun flicker per shot (owner 2026-11-22); the pulse ring is the shot's mark
		SIGHT_FLASH = 0.8, -- the sight's shimmer entering ADS...
		SIGHT_FLASH_TIME = 0.35, -- ...fading over this
		-- the shot pulse: a ring of light shot down the barrel, receiver to muzzle
		PULSE_RING = VFX.MOD_RING,
		PULSE_ARC_RING = VFX.STIM_RING, -- now and then the ring crackles
		PULSE_TIME = 0.085, -- seconds receiver -> muzzle
		PULSE_BRIGHTNESS = 1.6,
		PULSE_ARC_CHANCE = 0.3,
		-- the sweep: a band of water rings travelling along the gun (inspect, draw)
		SWEEP_RATE = 75, -- rings per second while sweeping
		SWEEP_LIFE = 0.16,
		SHOT_PULSE = 2.4, -- extra helix brightness in the per-shot pulse
		SHOT_PULSE_TIME = 0.1, -- seconds for the pulse to run receiver to muzzle
		SHOT_ARC_CHANCE = 0.45,
		BOOST_SHOT = 0.6, -- conduit flare per shot (0..1, decays at BOOST_DECAY / s)
		BOOST_SEAT = 0.9, -- flare when the new magazine seats or the draw locks
		BOOST_DECAY = 3.5,
		RELOAD_DRAIN = 0.75, -- how far the conduits dim while the magazine is out
		DRAINED = Color3.fromRGB(28, 70, 78),
		RING_POINTS = 12,
		RING_BRIGHTNESS = 1.15,
		RING_SPIN = 5, -- radians per second
		DRAW_RING = 0.4, -- the ring reaches the receiver (DrawTempest snaps level at 0.34)
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
	-- Moltframe chamber motion + Epic first-person VFX (camera guns only; world models keep the static look).
	-- Each chamber part carries flow Texture layers tagged with TAG_ATTRIBUTE.
	CHAMBER_FLOW = table.freeze({
		TAG_ATTRIBUTE = "MoltframeFlowLayer", -- 1 or 2 on each flow Texture
		LAYERS = table.freeze({
			table.freeze({ speedU = 0.052, speedV = 0.016 }), -- broad drift (studs / s)
			table.freeze({ speedU = -0.034, speedV = -0.020 }), -- finer counter-drift
		}),
		PULSE_ATTRIBUTE = "MoltframeChamberPulse", -- on baked chamber SurfaceAppearance (fallback)
		PULSE_PERIOD = 6, -- seconds, matches the Blender loop
		PULSE_TINT = Color3.fromRGB(232, 214, 255), -- peak multiplier on the base map
		-- Flat-material breathing & reactive shot/reload surge
		BREATHE_COLOR = Color3.fromHex("5D1F96"), -- gentle idle high-water chamber color
		SURGE_COLOR = Color3.fromHex("B25CF0"), -- peak chamber color on Fire / MagIn / Draw
		TEXTURE_IDLE = Color3.fromRGB(236, 216, 255),
		TEXTURE_SURGE = Color3.fromRGB(255, 240, 255),
		BREATHE_MIX = 0.34,
		SHOT_SURGE = 0.85,
		SEAT_SURGE = 1.0,
		DRAW_SURGE = 0.65,
		INSPECT_SURGE = 0.55,
		SURGE_DECAY = 3.6, -- exponential decay rate (1 / s)
		SURGE_SPEED_BOOST = 4.2, -- extra flow speed multiplier at surge = 1
		LIGHT_COLOR = Color3.fromHex("B052F0"),
		LIGHT_IDLE = 0.24,
		LIGHT_PULSE = 0.16,
		LIGHT_SURGE = 0.85,
		LIGHT_RANGE = 1.75,
		MOTE_TEXTURE = VFX.GLOW,
		MOTE_COLOR = Color3.fromHex("D29AF5"),
		MOTE_RATE = 1.4, -- sparse ambient chamber motes per gun (first person only)
		MOTE_SIZE = 0.038,
		MOTE_BURST_SEAT = 4,
		MOTE_BURST_FIRE = 2,
		-- Violet muzzle flash palette (MuzzleFx style = "Moltframe")
		MUZZLE_CORE = Color3.fromHex("F0DDFF"),
		MUZZLE_OUTER = Color3.fromHex("B657F5"),
		MUZZLE_DEEP = Color3.fromHex("6A1DA8"),
		MUZZLE_SMOKE = Color3.fromHex("9F8AB8"),
		MUZZLE_LIGHT = Color3.fromHex("B052F0"),
		MUZZLE_LIGHT_BRIGHTNESS = 1.65,
		MUZZLE_LIGHT_RANGE = 4.8,
		MAX_STEP = 0.1, -- clamp dt after a hitch
	}),
	-- Playback Epic first-person reactive cassette reels, VU meter, deck VFX, muzzle & swipe
	PLAYBACK = table.freeze({
		LINE = "Playback",
		REEL_IDLE_FRONT = 0.72, -- rad/s gentle idle tape crawl
		REEL_IDLE_REAR = 1.05,
		REEL_FIRE_FRONT = 13.5, -- rad/s forward tape whip on shot / slash
		REEL_FIRE_REAR = 19.0,
		REEL_HEAVY_FRONT = 21.0,
		REEL_HEAVY_REAR = 28.0,
		REEL_DRAW_FRONT = 10.5,
		REEL_DRAW_REAR = 14.5,
		REEL_REWIND_FRONT = -16.5, -- brisk rewind on MagOut
		REEL_REWIND_REAR = -22.5,
		REEL_SEAT_FRONT = 12.0,
		REEL_SEAT_REAR = 17.0,
		REEL_DRAG = 4.2, -- exponential coast-down (1 / s)
		METER_IDLE_BASE = 0.12,
		METER_IDLE_AMP = 0.08,
		METER_IDLE_FREQ = 2.6,
		METER_FIRE_KICK = 0.92,
		METER_HEAVY_KICK = 1.0,
		METER_DRAW_KICK = 0.65,
		METER_SEAT_KICK = 0.85,
		METER_DECAY = 4.8,
		SURGE_DECAY = 4.0,
		LIGHT_COLOR = Color3.fromHex("8FE34E"),
		LIGHT_SURGE_COLOR = Color3.fromHex("F29B4B"),
		LIGHT_IDLE = 0.20,
		LIGHT_PULSE = 0.10,
		LIGHT_SURGE = 0.72,
		LIGHT_RANGE = 1.65,
		MOTE_TEXTURE = VFX.GLOW,
		MOTE_COLOR = Color3.fromHex("9BE65C"),
		MOTE_PEAK_COLOR = Color3.fromHex("F5A855"),
		MOTE_RATE = 1.2,
		MOTE_SIZE = 0.032,
		MOTE_BURST_FIRE = 2,
		MOTE_BURST_SEAT = 4,
		MUZZLE_CORE = Color3.fromHex("FFF4D2"),
		MUZZLE_OUTER = Color3.fromHex("F09648"),
		MUZZLE_ACCENT = Color3.fromHex("94E052"),
		MUZZLE_DEEP = Color3.fromHex("C9483B"),
		MUZZLE_SMOKE = Color3.fromHex("B5ACA4"),
		MUZZLE_LIGHT = Color3.fromHex("F29B4B"),
		MUZZLE_LIGHT_BRIGHTNESS = 1.55,
		MUZZLE_LIGHT_RANGE = 4.6,
		SWIPE_CORE = Color3.fromHex("D8FF9E"),
		SWIPE_BODY = Color3.fromHex("3E2D47"),
	}),
	-- Sundial Epic first-person horological escapement dial, solar VFX, muzzle & swipe
	SUNDIAL = table.freeze({
		LINE = "Sundial",
		DIAL_IDLE_SPEED = 0.24, -- rad/s stately horological crawl
		DIAL_FIRE_STEP = math.rad(36), -- crisp 1/10th-turn escapement notch per shot / slash
		DIAL_HEAVY_STEP = math.rad(60),
		DIAL_DRAW_STEP = math.rad(45),
		DIAL_MAGOUT_STEP = -math.rad(54), -- wind back during reload
		DIAL_SEAT_STEP = math.rad(90), -- lock forward on MagIn / Close
		DIAL_SPRING_FREQ = 11.5, -- rad/s natural frequency
		DIAL_SPRING_DAMP = 0.56, -- crisp mechanical overshoot
		SURGE_DECAY = 3.6,
		LIGHT_COLOR = Color3.fromHex("FFB84D"),
		LIGHT_SURGE_COLOR = Color3.fromHex("FFF0C4"),
		LIGHT_IDLE = 0.24,
		LIGHT_PULSE = 0.14,
		LIGHT_SURGE = 0.84,
		LIGHT_RANGE = 1.80,
		MOTE_TEXTURE = VFX.GLOW,
		MOTE_COLOR = Color3.fromHex("FFD373"),
		MOTE_PEAK_COLOR = Color3.fromHex("FFF4D1"),
		MOTE_RATE = 1.5,
		MOTE_SIZE = 0.036,
		MOTE_BURST_FIRE = 2,
		MOTE_BURST_SEAT = 5,
		MUZZLE_CORE = Color3.fromHex("FFF7DC"),
		MUZZLE_OUTER = Color3.fromHex("FFB84D"),
		MUZZLE_DEEP = Color3.fromHex("B87724"),
		MUZZLE_SMOKE = Color3.fromHex("C9BEA8"),
		MUZZLE_LIGHT = Color3.fromHex("FFB84D"),
		MUZZLE_LIGHT_BRIGHTNESS = 1.65,
		MUZZLE_LIGHT_RANGE = 5.0,
		SWIPE_CORE = Color3.fromHex("FFE8A3"),
		SWIPE_BODY = Color3.fromHex("3B2242"),
	}),
	-- Riftforge Legendary first-person reactor core, articulated armor cowls,
	-- dual counter-rotating gimbal rings, suppressor vents, scrolling plasma beams,
	-- barrel shockwave rings, custom muzzle flash & plasma impact VFX.
	RIFTFORGE = table.freeze({
		LINE = "Riftforge",
		-- Blender-space pivots (converted via bl(x, y, z) -> Handle -> Root space)
		CORE_BL = Vector3.new(0.455, 0.0, 0.296),
		COWL_L_BL = Vector3.new(0.455, 0.090, 0.296),
		COWL_R_BL = Vector3.new(0.455, -0.090, 0.296),
		VENT_TOP_BL = Vector3.new(1.785, 0.0, 0.428),
		VENT_BOT_BL = Vector3.new(1.785, 0.0, 0.276),
		MAG_WELL_BL = Vector3.new(0.687, 0.0, 0.030),
		MUZZLE_BL = Vector3.new(2.515, 0.0, 0.352),
		STOCK_BL = Vector3.new(-1.080, 0.0, 0.375),
		-- Live articulated mechanical motion (springs + gyros)
		CRYSTAL_IDLE_SPIN = 1.4, -- rad/s
		CRYSTAL_FIRE_SPIN = 16.5,
		CRYSTAL_INSPECT_SPIN = 13.0,
		CRYSTAL_LEVITATE = 0.145, -- model studs straight UP out of open bay on inspect!
		CRYSTAL_BOB_AMP = 0.006,
		CRYSTAL_BOB_FREQ = 2.8,
		RING_A_IDLE_SPIN = -1.1, -- outer steel octagonal gimbal
		RING_A_FIRE_SPIN = -12.0,
		RING_B_IDLE_SPIN = 1.75, -- inner bronze hexagonal gimbal (counter-rotates!)
		RING_B_FIRE_SPIN = 16.0,
		SPIN_DRAG = 3.4,
		HEAT_PER_SHOT = 0.26,
		HEAT_COOL = 1.55,
		-- Armor cowls (CowlLeft / CowlRight): outward pop + yaw + roll flare!
		COWL_OUT_HEAT = 0.018, -- model studs outward in +/-Y
		COWL_OUT_OPEN = 0.042,
		COWL_YAW_HEAT = math.rad(8),
		COWL_YAW_OPEN = math.rad(19),
		COWL_ROLL_HEAT = math.rad(7),
		COWL_ROLL_OPEN = math.rad(16),
		COWL_SPRING_FREQ = 18.0, -- snappy heavy industrial armor SLAM!
		COWL_SPRING_DAMP = 0.44, -- slight mechanical rebound on slam
		-- Suppressor shrouds (VentTop / VentBottom)
		VENT_ANGLE_HEAT = math.rad(10),
		VENT_ANGLE_OPEN = math.rad(19),
		-- Plasma palette (first-person focused)
		PLASMA = Color3.fromHex("B83DFF"),
		PLASMA_EDGE = Color3.fromHex("F6D6FF"),
		PLASMA_DEEP = Color3.fromHex("6B14BA"),
		PLASMA_DRAINED = Color3.fromHex("2B1540"),
		CORE_IDLE_COLOR = Color3.fromHex("7324A8"), -- darkened Neon retains rich violet hue
		CORE_HOT_COLOR = Color3.fromHex("E8B8FF"),
		LIGHT_COLOR = Color3.fromHex("C44DFF"),
		LIGHT_HOT_COLOR = Color3.fromHex("F4D1FF"),
		LIGHT_IDLE = 0.42,
		LIGHT_PULSE = 0.22,
		LIGHT_SURGE = 1.15,
		LIGHT_RANGE = 2.4,
		ADS_LIGHT_SCALE = 0.25,
		-- Scrolling surface plasma tile + volumetric flank ribbons
		TILE_SCROLL_U = 0.32,
		TILE_SCROLL_V = 0.14,
		RIBBON_TEXTURE = VFX.HEALORB_RIBBON,
		RIBBON_WIDTH = 0.042,
		RIBBON_TILE = 0.65,
		RIBBON_SPEED = 2.6,
		RIBBON_BRIGHTNESS = 1.8,
		-- Reactor bay crackling lightning arcs (Beam with STIM_BOLT)
		BOLT_TEXTURE = VFX.STIM_BOLT,
		ARC_TEXTURE = VFX.STIM_ARC_2x2,
		SPARK_TEXTURE = VFX.STIM_SPARK,
		PULSE_RING = VFX.STIM_RING,
		SWEEP_RING = VFX.MOD_RING,
		IMPACT_FLASH = VFX.RECALL_FLASH,
		STATIC_MARK = VFX.STIM_RING,
		STATIC_TIME = 0.65,
		PULSE_TIME = 0.085,
		PULSE_BRIGHTNESS = 2.1,
		SWEEP_RATE = 70,
		SWEEP_LIFE = 0.16,
		FORM_RADIUS = 0.34,
		FORM_RATE = 95,
		TRAIL_LIFE = 0.18,
		-- Dedicated multi-layer muzzle flash & plasma impact VFX (Util/RiftforgeFx)
		FLASH_FRONT = VFX.T_FLASH,
		FLASH_SIDE = VFX.FLASH_SIDE_2x2,
		FLASH_CORE = Color3.fromHex("FCEBFF"),
		FLASH_BRIGHTNESS = 2.35,
		FLASH_TIME = 0.062,
		FLASH_LIGHT = 2.25,
		FLASH_LIGHT_RANGE = 6.2,
		FLASH_LIGHT_TIME = 0.085,
		MUZZLE_RING_TIME = 0.13,
		MUZZLE_RING_SPEED = 2.6,
		MUZZLE_RING_SIZE = 0.46,
		IMPACT_LIGHT = 1.7,
		-- First-person tracer + legacy fallback color keys
		SHOT_TINT = Color3.fromHex("D26BFF"),
		TRACER_WAKE = VFX.STIM_BOLT,
		MUZZLE_CORE = Color3.fromHex("F7D9FF"),
		MUZZLE_OUTER = Color3.fromHex("C44DFF"),
		MUZZLE_DEEP = Color3.fromHex("6812A8"),
		MUZZLE_SMOKE = Color3.fromHex("9A87B0"),
		MUZZLE_LIGHT = Color3.fromHex("C44DFF"),
		MUZZLE_LIGHT_BRIGHTNESS = 1.9,
		MUZZLE_LIGHT_RANGE = 5.5,
		SURGE_DECAY = 3.4,
		FLOURISH_AFTER = { 8, 12 },
		FLOURISH_TIME = 1.4,
	}),
})
