--!strict
-- The combat mix (AudioController). Loudness per gun class is baked into the
-- atlas (tools/audio/build_sound_atlas.py), so these are mix levels, not
-- per-gun fixes. Volumes are Sound.Volume; gains in dB.

export type Group = "Gun" | "Enemy" | "Feedback" | "Foley"

return table.freeze({
	-- SoundGroups under SoundService.Combat (the master bus).
	GROUP_VOLUME = table.freeze({
		Master = 1,
		Gun = 0.9, -- your own shots
		Enemy = 0.8, -- everyone else's shots (3D)
		Feedback = 1, -- hit ticks, headshot, kill, damage taken
		Foley = 0.75, -- reload, equip, dry fire, low ammo, swing
	} :: { [string]: number }),

	-- Your gun ducks a little under hit feedback so ticks always cut through.
	GUN_DUCK = table.freeze({ threshold = -26, ratio = 2.5, attack = 0.002, release = 0.12 }),
	-- Stacked automatic fire stays punchy instead of piling up.
	GUN_GLUE = table.freeze({ threshold = -14, ratio = 3, attack = 0.004, release = 0.09 }),
	-- Enemy shots: a touch duller than the baked far versions already are.
	ENEMY_EQ = table.freeze({ low = 0, mid = -1, high = -3 }),
	-- Master safety limiter.
	MASTER_LIMIT = table.freeze({ threshold = -4, ratio = 10, attack = 0.001, release = 0.1 }),

	-- Default volumes per kind of sound (before the group volume).
	SHOT_VOLUME = 0.75,
	ENEMY_SHOT_VOLUME = 0.9,
	FOLEY_VOLUME = 0.6,
	HIT_VOLUME = 0.6,
	HEAD_VOLUME = 0.65,
	KILL_VOLUME = 0.7,
	DAMAGE_VOLUME = 0.55,
	LOW_AMMO_VOLUME = 0.5,

	-- Random pitch per play (+/- fraction), so repeats never sound like a loop.
	PITCH_JITTER = table.freeze({
		Gun = 0.03,
		Enemy = 0.04,
		Feedback = 0.02,
		Foley = 0.04,
	} :: { [string]: number }),

	-- Voices. A name plays at most this many times at once (the oldest is
	-- cut), and the pools never grow past their size.
	VOICES_PER_SOUND = 4,
	VOICES_2D = 24,
	VOICES_3D = 32,

	-- 3D roll-off for other players' shots (studs).
	ROLLOFF_MIN = 14,
	ROLLOFF_MAX = 320,

	-- Low-ammo tick: plays on each shot once the mag is at or under this
	-- share (mags of at least LOW_AMMO_MIN_MAG rounds; louder as it empties).
	LOW_AMMO_FRACTION = 0.25,
	LOW_AMMO_MIN_MAG = 5,

	-- Pump and bolt guns cycle after each shot, this share of fireInterval later.
	CYCLE_DELAY = 0.35,

	-- Damage-taken thud: at most one per this many seconds.
	DAMAGE_MIN_GAP = 0.08,
})
