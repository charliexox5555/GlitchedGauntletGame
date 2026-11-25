--!strict
-- The in-world case opening (vault/01 Design/Case Opening.md), RIVALS-style (owner
-- 2026-11-20): the crate is tossed out in front of you, shakes, the latches flip, the
-- lid bursts open in the tier colour, the skin rises with its name card, then flies
-- into you. Everyone nearby sees it. Timings studied from RIVALS' skin case (reveal
-- 2.0 s after landing, ~4.9 s total, 7 studs out, card ~8 studs up) and rebuilt with
-- our crate (Shared/CrateLook) and effects. Numbers only; Util/CaseOpening plays it.

-- cut = play only this many seconds, then fade out (a slice of a longer recording)
-- start = optional TimePosition (seconds) to begin playback inside a longer clip
local function s(id: number, volume: number, pitch: number?, cut: number?, start: number?)
	return table.freeze({
		id = "rbxassetid://" .. tostring(id),
		volume = volume,
		pitch = pitch or 1,
		cut = cut,
		start = start,
	})
end

return table.freeze({
	ANSWER_TIMEOUT = 30,
	BATCH_BUTTON_WIDTH = 188,
	BATCH_BUTTON_STEP = 215,
	SCALE = 1.6, -- the crate model is 3.1 studs; RIVALS' skin case is ~6.4
	DISTANCE = 6.5, -- studs in front of the player it lands
	TRY_ANGLES = {
		0,
		22.5,
		-22.5,
		45,
		-45,
		67.5,
		-67.5,
		90,
		-90,
		112.5,
		-112.5,
		135,
		-135,
		157.5,
		-157.5,
		180,
	},
	TRY_DISTANCES = { 8, 14, 18, 24, 4.5 }, -- alternate rings when the preferred one is blocked
	HOVER_HEIGHT = 3, -- relative to the opener's root when there's no usable floor
	BATCH_ANGLES = { 0, 48, -48 }, -- centre, left, right
	BATCH_DISTANCE = 11, -- larger arc gives the crates and reward cards room
	BATCH_MIN_SPACING = 7.5,
	BATCH_CARD_SCALE = 0.82,
	VIEW_DISTANCE = 140,

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
	SKIN_WAIT = 6, -- real seconds from the result to allow skin model delivery

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

	-- Licensed sounds (Pro Sound Effects, Roblox UI packs, APM).
	-- Land / Shake / Rattle / Latch / Strain / RISER upgraded (2026-11-23) with
	-- crisp metallic weapon-case rattles, sharp toggle clasps, and suckback riser.
	SOUNDS = table.freeze({
		Toss = s(15675028888, 0.25, 1.2), -- Roblox Whoosh_02
		Land = s(9119075953, 0.55, 1.0, 0.4), -- PSE "Shield Impacts 18": crunchy hard tactical case drop
		Shake = s(9119110904, 0.8, 1.05, 0.4), -- PSE "Shotgun Drop 10": heavy gear shifting inside crate
		-- every shake also knocks the case on the floor (owner 2026-11-25: "the shakes should have
		-- better sounds"): a hollow case thump and a low resonant boom under it
		Knock = s(9117456565, 0.55, 1.0, 0.35), -- PSE "Plastic Cooler Hits 8": hollow case thump
		ShakeBoom = s(9113433534, 0.4, 0.75, 0.55), -- PSE "Bicycle Tire Impact Truck Tailgate 3", low
		Rattle = s(9114895481, 0.6, 1.12, 0.38), -- PSE "Junk Rattle Box Of Miscellaneous Items 1": brisk hardware rattle
		Latch = s(9117028600, 0.9, 1.08, 0.28), -- PSE "Moviola Toggle Switch Single Clicks Sharp 8": metallic clasp snap
		Strain = s(9116341721, 0.55, 1.08, 0.6), -- PSE "Machine Gun 7": metallic ratchet tension while lid strains
		Lid = s(15675028888, 0.48, 0.92),
		LidBoom = s(1837830213, 0.8), -- APM "Deep Boom 06": weight under the burst
		Swell = s(9043336050, 0.3), -- APM "SWELL 22"
		Collect = s(17208323435, 0.95), -- Roblox "GUI - Equip"
		CollectSpark = s(17208361335, 0.45, 1.25), -- Roblox "GUI - Notification High", up a little
		Fly = s(15675012262, 0.3, 1.15), -- Roblox Whoosh_04
		Burst = s(9119075953, 0.75, 0.88, 0.45), -- PSE "Shield Impacts 18", low: crisp metal case punch on lid open
		Tease = s(9043336050, 0.2, 1.3), -- the swell, short: the seams light up
		Sink = s(15675046931, 0.2, 0.9), -- Roblox Sweep
	}),
	-- one reveal stinger per tier (owner picks 2026-11-20). Legendary must be a music
	-- stinger like Epic's but bigger, never less (owner); Hustler Sting 2 picked
	REVEAL = table.freeze({
		-- louder and a real music hit for Common too (owner 2026-11-25: "louder and more fun")
		Common = s(9038919815, 0.45), -- APM "Totally Go For It - Hit4"
		Rare = s(9042542887, 0.55), -- APM "Universal Flip - Hit"
		Epic = s(9043151109, 0.55), -- APM "Get Up And Go - Hit"
		Legendary = s(9047100306, 0.65), -- APM "Hustler Sting 2" (4.4 s, sports brass)
		Exclusive = s(9047100306, 0.65),
	}),
	-- How hard each tier hits (owner 2026-11-20: "more intense sounds + VFX for a higher
	-- rarity"). hold = s the lid strains (trembling, glow ramping, a riser) before it
	-- bursts; sparks / waves = spark count and extra waves; rings = floor shockwaves;
	-- beam = light beam scale (0 = none); kick = camera kick scale; flash = screen flash
	-- (yours only, 0 = none); extra = sounds layered on the lid.
	TIER_FX = table.freeze({
		Common = table.freeze({
			hold = 0,
			sparks = 32,
			waves = 0,
			rings = 1,
			beam = 0,
			kick = 0.55,
			flash = 0,
			extra = {},
		}),
		Rare = table.freeze({
			hold = 0.2,
			sparks = 55,
			waves = 0,
			rings = 2,
			beam = 0.9,
			kick = 0.85,
			flash = 0.14,
			extra = { s(9114369623, 0.45, 1.1, 1.6) }, -- PSE "Fairy Dust 1": a short sparkle
		}),
		Epic = table.freeze({
			hold = 0.5,
			sparks = 85,
			waves = 1,
			rings = 2,
			beam = 1.35,
			kick = 1.25,
			flash = 0.38,
			extra = { s(17208361335, 0.4, 1.05), s(9114369623, 0.6, 1.0, 2.4) }, -- chime + sparkle
		}),
		Legendary = table.freeze({
			hold = 0.85,
			sparks = 130,
			waves = 2,
			rings = 3,
			beam = 1.85,
			kick = 1.65,
			flash = 0.52,
			-- a booming hit under the stinger (PSE "Truck Tailgate 1", low) + crisp chime, the sparkle,
			-- and a crowd roar (PSE "Wrestling Crowd 3", crowd surge)
			extra = {
				s(9113433423, 0.75, 0.85),
				s(17208361335, 0.45, 1.15),
				s(9114369623, 0.7, 1.0, 3),
				s(9120974378, 0.45, 1.0, 3),
			},
		}),
		Exclusive = table.freeze({
			hold = 0.85,
			sparks = 130,
			waves = 2,
			rings = 3,
			beam = 1.85,
			kick = 1.65,
			flash = 0.52,
			extra = {
				s(9113433423, 0.75, 0.85),
				s(17208361335, 0.45, 1.15),
				s(9114369623, 0.7, 1.0, 3),
				s(9120974378, 0.45, 1.0, 3),
			},
		}),
	}),
	RISER = s(9039693361, 0.6, 1.15, 0.95, 1.75), -- APM "Gobstopper Sucker": tight sub-heavy suckback to lid burst

	LOCAL_VOLUME = 1.35, -- your own opening, on top of the volumes above (owner 2026-11-25: louder)
	OTHERS_VOLUME = 0.5, -- someone else's opening is quieter (RIVALS does the same)
	ROLLOFF = Vector2.new(16, 80), -- studs: full volume / silent (16: the camera behind you stays at full)
})
