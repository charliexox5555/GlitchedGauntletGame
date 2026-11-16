--!strict
-- Every gun's sounds (2026-11-13, v5): all from the pro sound pack the owner
-- bought (vault/06 Assets/NewGunSounds), matched to our guns by type (pistol
-- set on the pistols, revolver on the revolver, rifle sets on the rifles, ...)
-- and using EVERY numbered take of each sound, so no shot, cock, mag or dry
-- fire is the same twice in a row. The table is in vault/02 Art/Sound Library
-- Pick.md §13.
--
-- Each slot names recordings from Config/GunSoundAssets. A slot plays
-- one of its files at random, never the same
-- twice running, with a small random pitch (`pitch`) and level (Config/Audio
-- VOLUME_JITTER_DB). `takes(prefix, first, last)` is shorthand for numbered
-- files: takes(P .. "shot_", 1, 5) = gun_pistol_shot_01 .. _05.
--
-- Audition the complete takes in art-source/audio/ProPack/standalone/ and
-- update a slot's cue names to select any existing uploaded recording.
--
-- How a shot plays (Util/GunAudio, the pack's guide): `fireFirst` opens a
-- sequence, then random `fire` takes; `tail` starts with every shot and the
-- next shot fades it; the shot that empties the mag plays `fireLast` (the
-- pack's last shot with its own tail). Other players hear `fireFar` (3D) with
-- the same first / tail / fade logic. Handling plays on the gun's clip beats
-- (gg_markers MagOut, MagIn, Open, RoundOut, RoundIn, Close, ShellIn, or the
-- moving joints).

export type GunSound = {
	id: string, -- "gun:<cue>|<cue>…" or a plain Roblox SoundId
	volume: number,
	pitch: { number }?, -- { min, max } random playback speed per play
}

export type GunSoundSet = {
	fire: GunSound, -- your own shot (2D, every shot)
	fireFar: GunSound, -- what other players hear when this gun fires (3D, at the muzzle)
	fireFirst: GunSound?, -- the first shot of a sequence (Config/Audio FIRST_SHOT_GAP)
	fireLast: GunSound?, -- the shot that empties the mag (with its own tail)
	tail: GunSound?, -- the room, started with every shot, faded by the next (Config/Audio TAIL_FADE)
	dryFire: GunSound?, -- trigger pulled on an empty mag
	magOut: GunSound?, -- the mag (or ammo box) leaves the gun
	magIn: GunSound?, -- the mag seats
	rack: GunSound?, -- charging handle / bolt / pump / slide / lever / hammer: empty reloads, every draw, pump & bolt shots
	open: GunSound?, -- barrels drop, a cylinder swings out, a feed cover lifts
	eject: GunSound?, -- spent cases out
	shellIn: GunSound?, -- each shell / round loaded
	close: GunSound?, -- the action shut again
	draw: GunSound, -- pulling the gun out (every equip)
	drawWhoosh: GunSound?, -- a small whoosh under every equip (defaults to EQUIP_WHOOSH)
	inspect: GunSound?, -- start of an inspect (Y)
	aimIn: GunSound?, -- aiming down sights (defaults to AIM_IN; scoped guns: the scope lens)
	aimOut: GunSound?, -- leaving the sights
	-- Melee only: the heavy attack's whoosh, and the blade striking a wall or a body.
	heavy: GunSound?,
	hitWall: GunSound?, -- stone, concrete, brick, plastic (any surface without its own)
	hitMetal: GunSound?,
	hitWood: GunSound?,
	hitSoft: GunSound?, -- grass, dirt, sand, snow, fabric
	hitBody: GunSound?,
	inspectFlip: GunSound?, -- each flip inside the inspect
}

-- Default volumes per kind of slot.
local FIRE = 1 -- 2026-11-13: up from 0.85 (the owner found the shots quiet)
local TAIL = 1
local FAR = 0.9
local FOLEY = 0.8
local DRAW = 0.7
local INSPECT = 0.6

local SHOT_PITCH = { 0.98, 1.02 } -- +/- 2 %
local FOLEY_PITCH = { 0.97, 1.03 } -- +/- 3 %
local SOURCE_PITCH = { 1, 1 }
-- Keep the Vandal's split recording at its original pitch and bring the
-- recorded ambience up ~4 dB so the end of a tap or spray reads.
local VANDAL_TAIL = 1.6

-- A slot: these pack files (one picked per play), at this volume and pitch.
local function S(files: { string }, volume: number, pitch: { number }?): GunSound
	return { id = "gun:" .. table.concat(files, "|"), volume = volume, pitch = pitch or FOLEY_PITCH }
end

-- Numbered takes: takes("gun_pistol_shot_", 1, 5) = { "gun_pistol_shot_01", ... "_05" }.
local function takes(prefix: string, first: number, last: number): { string }
	local out = {}
	for i = first, last do
		table.insert(out, prefix .. string.format("%02d", i))
	end
	return out
end

-- Several lists as one.
local function join(...: { string }): { string }
	local out = {}
	for _, list in { ... } do
		for _, name in list do
			table.insert(out, name)
		end
	end
	return out
end

-- Pack families (file name prefixes).
local P = "gun_pistol_"
local R = "gun_revolver_pistol_"
local SG = "gun_shotgun_"
local M = "gun_submachine_auto_"
local A = "gun_semi_auto_rifle_"
local RF = "gun_rifle_"
local SN = "gun_rifle_sniper_"
local H = "gun_machinegun_auto_heavy_"
local GEAR = "foley_soldier_gear_equipment_"

-- A small whoosh under every gun's equip, and the aim-down-sights sounds
-- (2026-11-13, owner): a short cloth flick in and out.
local EQUIP_WHOOSH: GunSound
local AIM_IN: GunSound
local AIM_OUT: GunSound

-- Shared pools.
local PISTOL_DRAW = takes(P .. "general_handling_", 5, 10) -- the short handling takes (0.3-0.4 s)
local LONG_GUN_DRAW = { RF .. "grab_pickup_01", SG .. "pickup_01", SG .. "pickup_02" }
local HEAVY_DRAW = takes(GEAR .. "metal_cloth_heavy_movement_strong_", 1, 4)

-- Match the reports at about -12 LUFS over their loudest 100 ms. Apply the
-- same trim to first, repeat, last and tail to keep each family's balance.
local REPORT_LEVEL: { [string]: number } = {
	Classic = 0.77,
	Ghost = 1.13,
	Sheriff = 0.60,
	Shorty = 0.59,
	Stinger = 1.28,
	Spectre = 1.28,
	Bucky = 0.59,
	Judge = 0.59,
	Vandal = 1.34, -- +2.2 dB so the report reads above the rest of the mix
	Phantom = 1.04,
	Bulldog = 1.04,
	Guardian = 0.54,
	Marshal = 0.54,
	Outlaw = 0.48,
	Operator = 0.48,
	Ares = 0.62,
	Odin = 0.62,
}

local sets: { [string]: GunSoundSet } = {
	-- Pistols: the pack's pistol ------------------------------------------------
	Classic = {
		fire = S(takes(P .. "shot_", 1, 5), FIRE, SHOT_PITCH),
		fireFar = S(takes(P .. "shot_", 1, 5), FAR, SHOT_PITCH),
		draw = S(PISTOL_DRAW, DRAW),
		rack = S(takes(P .. "cock_", 1, 7), FOLEY),
		magOut = S(takes(P .. "remove_mag_", 1, 6), FOLEY),
		magIn = S(takes(P .. "insert_mag_", 1, 5), FOLEY),
		inspect = S(takes(P .. "slide_slow_", 1, 6), INSPECT),
		dryFire = S(takes(P .. "dry_fire_", 1, 6), FOLEY),
	},
	-- The pack's suppressed pistol shots, the pistol's handling.
	Ghost = {
		fire = S(takes(P .. "shot_silenced_", 1, 4), FIRE, SHOT_PITCH),
		fireFar = S(takes(P .. "shot_silenced_", 1, 4), FAR, SHOT_PITCH),
		draw = S(PISTOL_DRAW, DRAW),
		rack = S(takes(P .. "slide_fast_", 1, 6), FOLEY),
		magOut = S(takes(P .. "remove_mag_", 1, 6), FOLEY),
		magIn = S(takes(P .. "insert_mag_", 1, 5), FOLEY),
		inspect = S(takes(P .. "general_handling_", 2, 4), INSPECT),
		dryFire = S(takes(P .. "dry_fire_", 1, 6), FOLEY),
	},
	-- Revolver: the pack's revolver.
	Sheriff = {
		fire = S(takes(R .. "shot_", 1, 4), FIRE, SHOT_PITCH),
		fireFar = S(takes(R .. "shot_", 1, 4), FAR, SHOT_PITCH),
		draw = S(PISTOL_DRAW, DRAW),
		rack = S(takes(R .. "cock_", 1, 5), FOLEY),
		open = S(takes(R .. "cylinder_open_", 1, 3), FOLEY),
		eject = S(takes(P .. "load_bullet_", 1, 7), FOLEY), -- loose rounds clinking out
		shellIn = S(takes(R .. "load_bullet_", 1, 5), FOLEY),
		close = S(takes(R .. "cylinder_close_", 1, 4), FOLEY),
		inspect = S(takes(R .. "cylinder_spin_", 1, 2), INSPECT),
		dryFire = S(takes(R .. "dry_fire_", 1, 5), FOLEY),
	},
	-- Sawn-off: the pack's shotgun. Its break action has no recording in the
	-- pack, so the barrels open and shut on the revolver's hinge sounds.
	Shorty = {
		fire = S(takes(SG .. "shot_", 1, 4), FIRE, SHOT_PITCH),
		fireFar = S(takes(SG .. "shot_", 1, 4), FAR, SHOT_PITCH),
		draw = S(takes(SG .. "pickup_", 1, 2), DRAW),
		open = S(takes(R .. "cylinder_open_", 1, 3), FOLEY),
		shellIn = S(takes(SG .. "load_bullet_", 1, 8), FOLEY),
		close = S(takes(R .. "cylinder_close_", 1, 4), FOLEY),
		rack = S(takes(R .. "cock_", 1, 5), FOLEY), -- the hammers
		inspect = S(takes(SG .. "safety_switch_", 1, 4), INSPECT),
		dryFire = S(takes(SG .. "dry_fire_", 1, 2), FOLEY),
	},

	-- SMGs: the pack's automatic SMG ----------------------------------------------
	Stinger = {
		fire = S(takes(M .. "shot_", 1, 9), FIRE, SHOT_PITCH),
		fireFirst = S({ M .. "shot_00_first_01" }, FIRE, SHOT_PITCH),
		fireLast = S({ M .. "shot_00_last_with_tail_01" }, FIRE, SHOT_PITCH),
		tail = S({ M .. "shot_00_tail_only_01" }, TAIL, SHOT_PITCH),
		fireFar = S(takes(M .. "shot_", 1, 9), FAR, SHOT_PITCH),
		draw = S(LONG_GUN_DRAW, DRAW),
		magOut = S(takes(M .. "magazine_unload_", 1, 3), FOLEY),
		magIn = S(takes(M .. "magazine_load_", 1, 4), FOLEY),
		rack = S(takes(M .. "cock_", 1, 4), FOLEY),
		inspect = S(takes(M .. "magazine_safety_switch_", 1, 2), INSPECT),
		dryFire = S(takes(M .. "dry_fire_", 1, 3), FOLEY),
	},
	-- The same SMG set (the pack has no suppressed SMG); a quieter room tail.
	Spectre = {
		fire = S(takes(M .. "shot_", 1, 9), FIRE, SHOT_PITCH),
		fireFirst = S({ M .. "shot_00_first_01" }, FIRE, SHOT_PITCH),
		fireLast = S({ M .. "shot_00_last_with_tail_01" }, FIRE * 0.8, SHOT_PITCH),
		tail = S({ M .. "shot_00_tail_only_01" }, TAIL * 0.5, SHOT_PITCH),
		fireFar = S(takes(M .. "shot_", 1, 9), FAR * 0.8, SHOT_PITCH),
		draw = S(LONG_GUN_DRAW, DRAW),
		magOut = S(takes(M .. "magazine_unload_", 1, 3), FOLEY),
		magIn = S(takes(M .. "magazine_load_", 1, 4), FOLEY),
		rack = S(takes(M .. "cock_", 1, 4), FOLEY),
		inspect = S(takes(M .. "load_bullet_", 1, 4), INSPECT),
		dryFire = S(takes(M .. "dry_fire_", 1, 3), FOLEY),
	},

	-- Shotguns: the pack's shotgun -------------------------------------------------
	Bucky = {
		fire = S(takes(SG .. "shot_", 1, 4), FIRE, SHOT_PITCH),
		fireFar = S(takes(SG .. "shot_", 1, 4), FAR, SHOT_PITCH),
		draw = S(takes(SG .. "pickup_", 1, 2), DRAW),
		rack = S(takes(SG .. "cock_", 1, 5), FOLEY), -- the pump, after every shot
		shellIn = S(takes(SG .. "load_bullet_", 1, 8), FOLEY),
		inspect = S(takes(SG .. "safety_switch_", 1, 4), INSPECT),
		dryFire = S(takes(SG .. "dry_fire_", 1, 2), FOLEY),
	},
	-- Drum shotgun: shotgun shots and pump; the pack's shotgun has no mag, so
	-- the drum comes out and in on the semi-auto rifle's mag takes.
	Judge = {
		fire = S(takes(SG .. "shot_", 1, 4), FIRE, SHOT_PITCH),
		fireFar = S(takes(SG .. "shot_", 1, 4), FAR, SHOT_PITCH),
		draw = S(takes(SG .. "pickup_", 1, 2), DRAW),
		magOut = S(takes(A .. "magazine_unload_", 1, 4), FOLEY),
		magIn = S(takes(A .. "magazine_load_", 1, 5), FOLEY),
		rack = S(takes(SG .. "cock_", 1, 5), FOLEY),
		inspect = S(takes(SG .. "load_bullet_", 1, 8), INSPECT),
		dryFire = S(takes(SG .. "dry_fire_", 1, 2), FOLEY),
	},

	-- Rifles: the pack's (automatic) semi-auto rifle set ------------------------------
	Vandal = {
		fire = S(takes(A .. "shot_", 1, 8), FIRE, SOURCE_PITCH),
		fireFirst = S({ A .. "shot_00_first_01" }, FIRE, SOURCE_PITCH),
		fireLast = S({ A .. "shot_00_last_with_tail_01" }, FIRE, SOURCE_PITCH),
		tail = S({ A .. "shot_00_tail_only_01" }, VANDAL_TAIL, SOURCE_PITCH),
		fireFar = S(takes(A .. "shot_", 1, 8), FAR, SOURCE_PITCH),
		draw = S(LONG_GUN_DRAW, DRAW),
		magOut = S(takes(A .. "magazine_unload_", 1, 4), FOLEY),
		magIn = S(takes(A .. "magazine_load_", 1, 5), FOLEY),
		rack = S(takes(A .. "cock_", 1, 5), FOLEY),
		inspect = S(takes(A .. "safety_switch_", 1, 3), INSPECT),
		dryFire = S(takes(A .. "dry_fire_", 1, 4), FOLEY),
	},
	-- The same rifle set (the pack has no suppressed rifle); a quieter room tail.
	Phantom = {
		fire = S(takes(A .. "shot_", 1, 8), FIRE, SHOT_PITCH),
		fireFirst = S({ A .. "shot_00_first_01" }, FIRE, SHOT_PITCH),
		fireLast = S({ A .. "shot_00_last_with_tail_01" }, FIRE * 0.8, SHOT_PITCH),
		tail = S({ A .. "shot_00_tail_only_01" }, TAIL * 0.5, SHOT_PITCH),
		fireFar = S(takes(A .. "shot_", 1, 8), FAR * 0.8, SHOT_PITCH),
		draw = S(LONG_GUN_DRAW, DRAW),
		magOut = S(takes(A .. "magazine_unload_", 1, 4), FOLEY),
		magIn = S(takes(A .. "magazine_load_", 1, 5), FOLEY),
		rack = S(takes(A .. "cock_", 1, 5), FOLEY),
		inspect = S(takes(A .. "safety_switch_", 1, 3), INSPECT),
		dryFire = S(takes(A .. "dry_fire_", 1, 4), FOLEY),
	},
	Bulldog = {
		fire = S(takes(A .. "shot_", 1, 8), FIRE, SHOT_PITCH),
		fireFirst = S({ A .. "shot_00_first_01" }, FIRE, SHOT_PITCH),
		fireLast = S({ A .. "shot_00_last_with_tail_01" }, FIRE, SHOT_PITCH),
		tail = S({ A .. "shot_00_tail_only_01" }, TAIL, SHOT_PITCH),
		fireFar = S(takes(A .. "shot_", 1, 8), FAR, SHOT_PITCH),
		draw = S(LONG_GUN_DRAW, DRAW),
		magOut = S(takes(A .. "magazine_unload_", 1, 4), FOLEY),
		magIn = S(takes(A .. "magazine_load_", 1, 5), FOLEY),
		rack = S(takes(A .. "cock_", 1, 5), FOLEY),
		inspect = S(takes(A .. "load_bullet_", 1, 7), INSPECT),
		dryFire = S(takes(A .. "dry_fire_", 1, 4), FOLEY),
	},
	-- The semi-automatic DMR uses the rifle's four complete shot recordings.
	-- Its magazine and charging handle still use the magazine-fed rifle set.
	Guardian = {
		fire = S(takes(RF .. "shot_", 1, 4), FIRE, SHOT_PITCH),
		fireFar = S(takes(RF .. "shot_", 1, 4), FAR, SHOT_PITCH),
		draw = S(LONG_GUN_DRAW, DRAW),
		magOut = S(takes(A .. "magazine_unload_", 1, 4), FOLEY),
		magIn = S(takes(A .. "magazine_load_", 1, 5), FOLEY),
		rack = S(takes(A .. "cock_", 1, 5), FOLEY),
		inspect = S(takes(A .. "load_bullet_", 1, 7), INSPECT),
		dryFire = S(takes(A .. "dry_fire_", 1, 4), FOLEY),
	},

	-- Snipers -------------------------------------------------------------------
	-- Lever gun: the pack's (bolt / lever) rifle.
	Marshal = {
		fire = S(takes(RF .. "shot_", 1, 4), FIRE, SHOT_PITCH),
		fireFar = S(takes(RF .. "shot_", 1, 4), FAR, SHOT_PITCH),
		draw = S({ RF .. "grab_pickup_01" }, DRAW),
		rack = S(takes(RF .. "cock_", 1, 4), FOLEY), -- the action, after every shot
		shellIn = S(takes(RF .. "load_bullet_", 1, 8), FOLEY),
		inspect = S(takes(RF .. "safety_switch_", 1, 2), INSPECT),
		dryFire = S(takes(RF .. "dry_fire_", 1, 4), FOLEY),
	},
	-- Double rifle: the pack's sniper shots; its break action opens and shuts on
	-- the revolver's hinge sounds (no break-action recording in the pack).
	Outlaw = {
		fire = S(takes(SN .. "shot_", 1, 4), FIRE, SHOT_PITCH),
		fireFar = S(takes(SN .. "shot_", 1, 4), FAR, SHOT_PITCH),
		draw = S({ RF .. "grab_pickup_01" }, DRAW),
		open = S(takes(R .. "cylinder_open_", 1, 3), FOLEY),
		eject = S(takes(SN .. "load_bullet_", 1, 5), FOLEY),
		shellIn = S(takes(RF .. "load_bullet_", 1, 8), FOLEY),
		close = S(takes(R .. "cylinder_close_", 1, 4), FOLEY),
		rack = S(takes(SN .. "cock_", 1, 4), FOLEY),
		inspect = S(takes(RF .. "safety_switch_", 1, 2), INSPECT),
		dryFire = S(takes(SN .. "dry_fire_", 1, 2), FOLEY),
	},
	-- Bolt sniper: the pack's sniper.
	Operator = {
		fire = S(takes(SN .. "shot_", 1, 4), FIRE, SHOT_PITCH),
		fireFar = S(takes(SN .. "shot_", 1, 4), FAR, SHOT_PITCH),
		draw = S({ RF .. "grab_pickup_01" }, DRAW),
		rack = S(takes(SN .. "cock_", 1, 4), FOLEY), -- the bolt, after every shot
		magOut = S(takes(RF .. "magazine_unload_", 1, 5), FOLEY),
		magIn = S(takes(RF .. "magazine_load_", 1, 4), FOLEY),
		shellIn = S(takes(SN .. "load_bullet_", 1, 5), FOLEY),
		inspect = S(takes(SN .. "scope_zoom_lens_", 1, 7), INSPECT),
		aimIn = S(takes(SN .. "scope_zoom_lens_", 1, 7), 0.5),
		dryFire = S(takes(SN .. "dry_fire_", 1, 2), FOLEY),
	},

	-- Machine guns: the pack's heavy machine gun -----------------------------------
	Ares = {
		fire = S(takes(H .. "shot_", 1, 8), FIRE, SHOT_PITCH),
		fireFirst = S({ H .. "shot_00_first_01" }, FIRE, SHOT_PITCH),
		fireLast = S({ H .. "shot_00_last_with_tail_01" }, FIRE, SHOT_PITCH),
		tail = S({ H .. "shot_00_tail_only_01" }, TAIL, SHOT_PITCH),
		fireFar = S(takes(H .. "shot_", 1, 8), FAR, SHOT_PITCH),
		draw = S(HEAVY_DRAW, DRAW),
		magOut = S(takes(A .. "magazine_unload_", 1, 4), FOLEY),
		magIn = S(takes(H .. "reload_", 1, 2), FOLEY), -- the pack's full MG reloads
		rack = S(takes(A .. "cock_", 1, 5), FOLEY),
		inspect = S(takes(GEAR .. "rattle_movement_med_", 1, 3), INSPECT),
		dryFire = S(takes(RF .. "dry_fire_", 1, 4), FOLEY),
	},
	Odin = {
		fire = S(takes(H .. "shot_", 1, 8), FIRE, SHOT_PITCH),
		fireFirst = S({ H .. "shot_00_first_01" }, FIRE, SHOT_PITCH),
		fireLast = S({ H .. "shot_00_last_with_tail_01" }, FIRE, SHOT_PITCH),
		tail = S({ H .. "shot_00_tail_only_01" }, TAIL, SHOT_PITCH),
		fireFar = S(takes(H .. "shot_", 1, 8), FAR, SHOT_PITCH),
		draw = S(HEAVY_DRAW, DRAW),
		open = S(takes(GEAR .. "rattle_movement_med_", 1, 3), FOLEY), -- the feed cover
		magOut = S(takes(A .. "magazine_unload_", 1, 4), FOLEY),
		magIn = S(takes(H .. "reload_", 1, 2), FOLEY),
		close = S(takes(A .. "cock_", 1, 5), FOLEY),
		rack = S(takes(A .. "cock_", 1, 5), FOLEY),
		inspect = S(takes(GEAR .. "movement_grab_item_", 1, 7), INSPECT),
		dryFire = S(takes(RF .. "dry_fire_", 1, 4), FOLEY),
	},

	-- Knife: `fire` is a light slash's whoosh (WeaponController times its peak
	-- onto the strike; each step of a 1-2-3 chain climbs a semitone), `heavy`
	-- the two-handed stab. The whooshes are pure air (cloth swishes, no hit at
	-- the start); the hit sounds play only when the blade lands. Built slices
	-- from the pack (tools/audio/build_pro_atlas.py).
	-- 2026-11-13 (owner): every knife move is one of the pack's whoosh_swish
	-- files (small for slashes, the pull-out, the inspect and its flips; high
	-- fast for the heavy stab). The cloth swishes are knife_whoosh_cloth /
	-- knife_whoosh_cloth_heavy.
	Knife = {
		fire = S({ "knife_whoosh" }, 0.75, { 0.97, 1.05 }),
		heavy = S({ "knife_whoosh_heavy" }, 0.85, { 0.94, 1.0 }),
		fireFar = S({ "knife_whoosh" }, 0.6, { 0.95, 1.05 }),
		hitBody = S(join(takes("punch_grit_wet_impact_", 1, 5)), 0.85),
		hitWall = S({ "impact_hard" }, 0.85),
		hitMetal = S({ "impact_metal" }, 0.75),
		hitWood = S({ "impact_wood" }, 0.85),
		hitSoft = S({ "impact_soft" }, 0.7),
		draw = S(takes("whoosh_swish_small_", 1, 4), DRAW),
		drawWhoosh = S(takes("whoosh_swish_high_fast_", 1, 4), 0.45),
		inspect = S(takes("whoosh_swish_small_", 1, 4), 0.55),
		inspectFlip = S(takes("whoosh_swish_small_", 1, 4), 0.45),
	},
}

-- Beats a set has no sound for fall back to the nearest one it has: the
-- action shutting to the rack, the cases coming out to the mag out. Every
-- equip gets the small whoosh.
EQUIP_WHOOSH = S(takes("whoosh_swish_small_", 1, 4), 0.35)
AIM_IN = S({ "foley_cloth_light_fast_movement_13", "foley_cloth_light_fast_movement_14" }, 0.3)
AIM_OUT = S({ "foley_cloth_light_fast_movement_06", "foley_cloth_light_fast_movement_15" }, 0.22)
-- The scoped guns' scope ring (Marshal, Outlaw; the Operator's is set above).
for _, gun in { "Marshal", "Outlaw" } do
	(sets[gun] :: any).aimIn = S(takes(SN .. "scope_zoom_lens_", 1, 7), 0.5)
end
for id, set in sets do
	local s = set :: any
	local level = REPORT_LEVEL[id]
	if level then
		for _, sound in { set.fire, set.fireFar, set.fireFirst, set.fireLast, set.tail } do
			if sound then
				sound.volume *= level
			end
		end
	end
	s.close = s.close or s.rack
	s.eject = s.eject or s.magOut
	s.drawWhoosh = s.drawWhoosh or EQUIP_WHOOSH
	s.aimIn = s.aimIn or AIM_IN
	s.aimOut = s.aimOut or AIM_OUT
end

-- A gun without its own set uses the Vandal's.
local DEFAULT: GunSoundSet = sets.Vandal

local GunSounds = {}

GunSounds.DEFAULT = DEFAULT

-- The sound set for a gun id (DEFAULT if it has none).
function GunSounds.get(weaponId: string): GunSoundSet
	return sets[weaponId] or DEFAULT
end

return GunSounds
