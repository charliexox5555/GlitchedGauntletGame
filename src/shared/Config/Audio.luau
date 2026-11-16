--!strict
-- The combat mix (AudioController). Loudness per gun class is baked into the
-- atlas (tools/audio/build_pro_atlas.py), so these are mix levels, not
-- per-gun fixes. Volumes are Sound.Volume; gains in dB.

export type Group = "Gun" | "Enemy" | "Feedback" | "Foley" | "Ui" | "Ambience" | "Room"

return table.freeze({
	-- SoundGroups under SoundService.Combat (the master bus).
	GROUP_VOLUME = table.freeze({
		Master = 1,
		Gun = 1, -- your own shots (2026-11-13: up from 0.9, the owner found them quiet)
		Enemy = 0.8, -- everyone else's shots (3D)
		Feedback = 1, -- hit ticks, headshot, kill, damage taken
		Foley = 0.65, -- reload, equip, dry fire, low ammo, swing (2026-11-13: 0.75 -> 0.65, shots sit ~10-13 dB over)
		Ui = 0.7, -- menus, draft, banners, countdown (Config/UiSounds)
		Ambience = 0.8, -- map beds and emitters outdoors (Config/Ambience); muffled indoors
		Room = 0.8, -- indoor room tone (Config/Ambience)
	} :: { [string]: number }),

	-- The outdoor ambience ducks a few dB under your own shots (sidechain),
	-- so firefights read over the bed (LihFolk Combat Sound Design: duck
	-- ambience 3-6 dB, 250-500 ms release).
	AMBIENCE_DUCK = table.freeze({ threshold = -30, ratio = 3, attack = 0.01, release = 0.35 }),
	-- Master safety limiter.
	MASTER_LIMIT = table.freeze({ threshold = -2, ratio = 10, attack = 0.001, release = 0.1 }), -- was -4 (flattened shots)

	-- Default volumes per kind of sound (before the group volume).
	-- Keep the contact ticks and kill pop under the shot report.
	-- 2026-11-15 (owner: "I can't really hear" the regular hit sound). Checked
	-- in play: it did play, but at 0.42 against the shot's two layers at 1.26
	-- and 1.99, and on the very frame of the shot (13 ms after the trigger),
	-- so the report covered a 66 ms click. In his RIVALS clip the tick lands
	-- 80-150 ms after the shot. Now louder (0.42 -> 0.8) and HIT_DELAY later.
	HIT_VOLUME = 0.8,
	-- Seconds after your shot that its predicted hit sound plays (body tick
	-- and headshot): clear of the shot's own crack.
	HIT_DELAY = 0.05,
	HEAD_VOLUME = 0.45,
	-- 0.5 since 2026-11-15 (was 0.36): the owner's kill pick (kill_F) is levelled
	-- 3 dB under the old kills, so this plays it about as loud as they were.
	KILL_VOLUME = 0.5,
	-- The kill tone climbs with every kill you get in a round (Util/KillFeed),
	-- Valorant-style: playback speeds for kills 1..5 (0, +2, +4, +5, +7
	-- semitones). The 5th and later all play the top step.
	KILL_LADDER = table.freeze({ 1, 1.122, 1.26, 1.335, 1.498 }),
	DAMAGE_VOLUME = 0.55,
	-- Hit sounds play on our own shot's hit; a server confirm inside this many
	-- seconds of one is the same hit and stays quiet.
	HIT_PREDICT_WINDOW = 0.5,
	LOW_AMMO_VOLUME = 0.5,

	-- Random pitch per play (+/- fraction), so repeats never sound like a loop.
	PITCH_JITTER = table.freeze({
		Gun = 0.03,
		Enemy = 0.04,
		Feedback = 0.02,
		Foley = 0.04,
		Ui = 0.02,
		Ambience = 0.03,
		Room = 0,
	} :: { [string]: number }),

	-- Small random level per play (+/- dB), on top of the varied recordings.
	VOLUME_JITTER_DB = table.freeze({
		Gun = 0.75,
		Enemy = 0.75,
		Foley = 1.5,
	} :: { [string]: number }),

	-- Ordinary atlas cue budgets. Gunfire can overlap beyond these limits.
	VOICES_PER_SOUND = 4,
	VOICES_2D = 24,
	VOICES_3D = 32,
	PRELOAD_BATCH_SIZE = 16,

	-- 3D roll-off for other players' shots (studs).
	ROLLOFF_MIN = 14,
	ROLLOFF_MAX = 320,
	-- Suppressed guns carry a shorter way (Riot does the same for Valorant's).
	SUPPRESSED_RANGE = 180,

	-- Low-ammo tick: plays on each shot once the mag is at or under this
	-- share (mags of at least LOW_AMMO_MIN_MAG rounds; louder as it empties).
	LOW_AMMO_FRACTION = 0.25,
	LOW_AMMO_MIN_MAG = 5,

	-- Pump and bolt guns cycle after each shot, this share of fireInterval later.
	CYCLE_DELAY = 0.35,

	-- Gun sound logic (Util/GunAudio, 2026-11-13, the pro pack's guide):
	-- every shot starts the gun's tail (Config/GunSounds `tail`) with it, and
	-- the next shot fades the last tail out over `share` of the fire interval
	-- (kept between `min` and `max` s), so only the final tail rings on.
	TAIL_FADE = table.freeze({ share = 0.8, min = 0.03, max = 0.12 }),
	-- A sequence's first shot (Config/GunSounds `fireFirst`): no shot came for
	-- one fire interval plus this many seconds.
	FIRST_SHOT_GAP = 0.12,

	-- Damage-taken thud: at most one per this many seconds.
	DAMAGE_MIN_GAP = 0.08,

	-- Footsteps (Controllers/FootstepController, 2026-11-05): one step every
	-- `stride` studs travelled on the ground (16 studs/s -> ~3.2 steps/s, the
	-- run cycle's), real recordings per surface (Config/Sounds STEPS). Yours
	-- play 2D, everyone else's 3D at their feet so you can hear them coming;
	-- crouch-walking is much quieter (RIVALS-style sneaking), sprinting a bit
	-- louder. Nothing below `minSpeed` (studs/s) or in a slide.
	-- 2026-11-14 (owner: "revert it back to default Roblox sounds ... I just want
	-- the regular sounds"): Roblox's own character sounds (RbxCharacterSounds)
	-- play the running loop, jump and landing for every character, and the
	-- game's own steps (FootstepController) and jump / land (Config/Juice) stay
	-- quiet. Roblox's "uuhhh" death sound stays muted either way. Set false to
	-- go back to the game's steps (per surface, quieter crouch-walking).
	ROBLOX_CHARACTER_SOUNDS = true,

	STEPS = table.freeze({
		stride = 5,
		sprintStride = 6.2,
		crouchStride = 3.6,
		minSpeed = 3,
		ownVolume = 0.32,
		otherVolume = 0.75,
		crouchScale = 0.3,
		sprintScale = 1.25,
		range = 80, -- studs: others' steps fade out by here
		hearRange = 90, -- studs: characters further away aren't tracked
	}),
})
