--!strict
-- The in-world case opening (vault/01 Design/Case Opening.md), RIVALS-style (owner
-- 2026-11-20): the crate is tossed out in front of you, shakes, the latches flip, the
-- lid bursts open in the tier colour, the skin rises with its name card, then flies
-- into you. Everyone nearby sees it. Timings studied from RIVALS' skin case (reveal
-- 2.0 s after landing, ~4.9 s total, 7 studs out, card ~8 studs up) and rebuilt with
-- our crate (Shared/CrateLook) and effects. Numbers only; Util/CaseOpening plays it.

-- cut = play only this many seconds, then fade out (a slice of a longer recording)
local function s(id: number, volume: number, pitch: number?, cut: number?)
	return table.freeze({
		id = "rbxassetid://" .. tostring(id),
		volume = volume,
		pitch = pitch or 1,
		cut = cut,
	})
end

return table.freeze({
	SCALE = 1.6, -- the crate model is 3.1 studs; RIVALS' skin case is ~6.4
	DISTANCE = 6.5, -- studs in front of the player it lands
	TRY_ANGLES = { 0, 35, -35, 70, -70, 110, -110, 180 }, -- degrees off the facing when blocked

	TOSS = 1.0, -- s, from the chest to the floor, ~1.5 bounces
	TOSS_HEIGHT = 3.2, -- studs of the first arc
	TOSS_SPIN = 50, -- degrees of yaw it turns while flying

	SHAKE_EVERY = 0.55, -- s between shakes while waiting / building up
	SHAKES = 2, -- at least this many before the latches (more for higher tiers: TIER_SHAKES)
	SHAKE_ANGLES = { 4, 6, 8, 10, 12 }, -- degrees, growing
	-- the build-up scales with what's inside (owner 2026-11-20: "people are paying,
	-- it needs to be satisfying"): more shakes, and the seams glow in the tier colour
	-- from the second-to-last shake
	TIER_SHAKES = table.freeze({ Common = 2, Rare = 3, Epic = 4, Legendary = 5, Exclusive = 5 }),
	TEASE_GLOW = 1.4, -- seam light brightness while teasing
	WAIT_LIMIT = 10, -- s without the server's answer → it sinks away

	LATCH_GAP = 0.1, -- s between the two latches
	LATCH_TIME = 0.18,
	LATCH_ANGLE = 130,
	COIL = 0.32, -- s after the latches: the crate dips (anticipation)
	LID_AT = 0.5, -- s after the latches: the lid bursts
	LID_TIME = 0.24,
	LID_ANGLE = 105, -- positive X = open (tools/studio/BuildCrate.luau)
	LID_OVERSHOOT = 14,

	RISE_DELAY = 0.12, -- s after the lid: the skin starts rising
	RISE_TIME = 0.9,
	RISE_HEIGHT = 2.9, -- studs above the crate top (scaled)
	SKIN_LENGTH = 4.4, -- the revealed skin is fitted to this (studs)
	SPIN_SPEED = 40, -- degrees / s after the first turn
	CARD_UP = 1.9, -- studs above the skin
	CARD_SIZE = Vector2.new(7.4, 2.3), -- studs (BillboardGui), with the portrait tile

	HOLD = 3.2, -- s the skin and card stay
	FLY_TIME = 0.85, -- s into the player
	SINK_TIME = 0.6, -- s the crate takes to sink away

	LIGHT_RANGE = 16,
	LIGHT_PEAK = 2.2, -- 6 washed the player out white (playtest 2026-11-20)

	-- the lid burst
	RING_SIZE = 16, -- studs: the floor shockwave grows to this
	RING_TIME = 0.55,
	BEAM_HEIGHT = 9, -- studs: the light beam out of the crate
	BEAM_TIME = 1.1,
	CAMERA_KICK = 0.35, -- studs of camera shake on the burst (yours only)
	FOV_PUNCH = 5, -- degrees the camera FOV pulls in and springs back
	-- the hold
	SPARKLES = 6, -- per second around the skin
	-- the fly-in: an arc up and into your chest, spinning, shrinking
	FLY_ARC = 3.5, -- studs the arc rises above the straight line
	FLY_SPIN = 720, -- degrees over the flight
	-- the card: the portrait on its tier tile beside the name
	CARD_TILE = 0.32, -- of the card's width

	-- Licensed sounds (Pro Sound Effects, Roblox UI packs, APM). Owner picks 2026-11-20
	-- (F4 board, CASE tab): Land, Latch, Lid and Collect kept; the lid got a boom under it
	-- ("more umph") and each shake a rattle ("a nice feel of opening a case").
	SOUNDS = table.freeze({
		Toss = s(15675028888, 0.25, 1.2), -- Roblox Whoosh_02
		Land = s(9117456325, 0.6), -- PSE "Plastic Cooler Hits 3": a hollow hard case
		Shake = s(9117456325, 0.35, 1.25),
		-- PSE "Metal Lid Movements Over Box 6", a short slice: the case rattles in your hands
		Rattle = s(9116822963, 0.4, 1.1, 0.4),
		Latch = s(9119727934, 0.9), -- PSE "Plastic Switch 14"
		Lid = s(15675028888, 0.45, 0.9),
		LidBoom = s(1837830213, 0.5), -- APM "Deep Boom 06": weight under the burst
		Swell = s(9043336050, 0.3), -- APM "SWELL 22"
		Collect = s(17208323435, 0.6), -- Roblox "GUI - Equip"
		CollectSpark = s(17208361335, 0.25, 1.25), -- Roblox "GUI - Notification High", up a little
		Fly = s(15675012262, 0.3, 1.15), -- Roblox Whoosh_04
		Burst = s(9117456325, 0.55, 0.8), -- the case hit, low: weight under the lid
		Tease = s(9043336050, 0.18, 1.3), -- the swell, short: the seams light up
		Sink = s(15675046931, 0.2, 0.9), -- Roblox Sweep
	}),
	-- one reveal stinger per tier (owner picks 2026-11-20; Legendary must be short)
	REVEAL = table.freeze({
		Common = s(17208323435, 0.6), -- Roblox "GUI - Equip"
		Rare = s(9042542887, 0.35), -- APM "Universal Flip - Hit"
		Epic = s(9043151109, 0.35), -- APM "Get Up And Go - Hit"
		Legendary = s(15675043410, 0.6), -- Roblox "UI Tonal Stinger" (1.5 s), layered below
		Exclusive = s(15675043410, 0.6),
	}),
	-- How hard each tier hits (owner 2026-11-20: "more intense sounds + VFX for a higher
	-- rarity"). hold = s the lid strains (trembling, glow ramping, a riser) before it
	-- bursts; sparks / waves = spark count and extra waves; rings = floor shockwaves;
	-- beam = light beam scale (0 = none); kick = camera kick scale; flash = screen flash
	-- (yours only, 0 = none); extra = sounds layered on the lid.
	TIER_FX = table.freeze({
		Common = table.freeze({
			hold = 0,
			sparks = 30,
			waves = 0,
			rings = 1,
			beam = 0,
			kick = 0.6,
			flash = 0,
			extra = {},
		}),
		Rare = table.freeze({
			hold = 0.15,
			sparks = 50,
			waves = 0,
			rings = 1,
			beam = 0.8,
			kick = 0.85,
			flash = 0,
			extra = {},
		}),
		Epic = table.freeze({
			hold = 0.45,
			sparks = 75,
			waves = 1,
			rings = 2,
			beam = 1.2,
			kick = 1.15,
			flash = 0.35,
			extra = {},
		}),
		Legendary = table.freeze({
			hold = 0.8,
			sparks = 110,
			waves = 2,
			rings = 3,
			beam = 1.6,
			kick = 1.5,
			flash = 0.5,
			-- the Legendary sting, built short: a booming hit (PSE "Truck Tailgate 1", low)
			-- and a bright sparkle (Roblox "GUI - Notification High", up) on the stinger
			extra = { s(9113433423, 0.5, 0.85), s(17208361335, 0.3, 1.2) },
		}),
		Exclusive = table.freeze({
			hold = 0.8,
			sparks = 110,
			waves = 2,
			rings = 3,
			beam = 1.6,
			kick = 1.5,
			flash = 0.5,
			extra = { s(9113433423, 0.5, 0.85), s(17208361335, 0.3, 1.2) },
		}),
	}),
	RISER = s(9043336050, 0.35, 1.5), -- the swell, up: plays through the held beat

	OTHERS_VOLUME = 0.5, -- someone else's opening is quieter (RIVALS does the same)
	ROLLOFF = Vector2.new(8, 70), -- studs: full volume / silent
})
