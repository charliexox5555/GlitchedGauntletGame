--!strict
-- Every gun's sounds, one entry per gun. Change a sound here and it changes
-- everywhere: AudioController plays these, and the reload / draw / inspect
-- foley lands on the gun's own animation beats (mag out, mag in, rack).
--
-- HOW TO CHANGE A SOUND
--   1. Upload the sound to Roblox (Creator Dashboard → Development Items →
--      Audio, or tools/opencloud/upload_asset.py --type Audio).
--   2. Paste its id over the placeholder: id = "rbxassetid://1234567890".
--   3. Adjust `volume` (0..10, ~0.6 is a normal foley level) and `pitch`
--      ({ min, max } playback speed, picked at random each play; { 1, 1 } = none).
--   4. Save; Rojo syncs it into Studio. Play to hear it.
--   Ids starting with "atlas:" are PLACEHOLDERS: slices of the shared gun
--   sound atlas (Config/SoundAtlas). Replace them with a plain rbxassetid.
--   Leave an optional sound out (or set it to nil) to play nothing.
--   Gunshot placeholders in the atlas (real recordings; add "_Far" for the
--   enemy version): PPQ (9mm pistol), Revolver (.38), M1911 (.45), Bersa
--   (.380), Ruger22 (.22, quiet), SwedishK and PPSh (SMGs), PPShBurst, AR15,
--   AK47Suppressed, AKBurst (AK full auto), Marlin (.30-30 lever), SKS,
--   Springfield / Tikka / Mosin (bolt rifles), Nova / Model12 / Mossberg
--   (shotguns). Foley: DryFire.
--
-- A NEW GUN: copy the Vandal's entry, rename it to the gun's id (the same
-- name as in Config/Weapons and ReplicatedStorage.Weapons) and swap the ids.
-- Guns without an entry use DEFAULT.

export type GunSound = {
	id: string, -- "rbxassetid://…" (or an "atlas:" placeholder)
	volume: number,
	pitch: { number }?, -- { min, max } random playback speed per play
}

export type GunSoundSet = {
	fire: GunSound, -- your own shot (2D, every shot)
	fireFar: GunSound, -- what other players hear when this gun fires (3D, at the muzzle)
	tail: GunSound?, -- optional: an echo / tail after each shot (2D)
	dryFire: GunSound, -- trigger pulled on an empty mag
	magOut: GunSound, -- reloads: the mag leaves the gun (when the Mag starts moving)
	magIn: GunSound, -- reloads: the mag seats (when the Mag stops moving)
	rack: GunSound?, -- charging handle / bolt / pump / slide / break-action shut: empty reloads, first draw, pump & bolt shots
	open: GunSound?, -- break-action / revolver: the action opens on a reload
	shellIn: GunSound?, -- shotguns / revolvers: each round loaded
	draw: GunSound, -- pulling the gun out (every equip)
	inspect: GunSound?, -- start of an inspect (Y)
}

local FOLEY = 0.6 -- normal handling loudness
local PITCH = { 0.97, 1.03 } -- a little variation so repeats never sound looped

local function id(n: number): string
	return "rbxassetid://" .. tostring(n)
end

-- Handling placeholders (Audioscape foley, Roblox-licensed), shared by every gun until replaced.
local MAG_OUT = id(101803348893194) -- AS_gun_foley-01
local MAG_IN = id(92321876028160) -- AS_gun_foley-02
local RACK = id(135901981148051) -- AS_gun_foley-03
local DRAW = id(73599108833500) -- AS_gun_foley-04

local DEFAULT: GunSoundSet = {
	fire = { id = "atlas:AR15", volume = 0.75, pitch = PITCH },
	fireFar = { id = "atlas:AR15_Far", volume = 0.9, pitch = PITCH },
	dryFire = { id = "atlas:DryFire", volume = FOLEY },
	magOut = { id = MAG_OUT, volume = FOLEY, pitch = PITCH },
	magIn = { id = MAG_IN, volume = FOLEY, pitch = PITCH },
	rack = { id = RACK, volume = FOLEY, pitch = PITCH },
	draw = { id = DRAW, volume = FOLEY, pitch = PITCH },
}

local sets: { [string]: GunSoundSet } = {
	-- Vandal: heavy AK-style rifle.
	Vandal = {
		fire = { id = "atlas:AKBurst", volume = 0.75, pitch = PITCH }, -- PLACEHOLDER: real AK-47 full-auto shot
		fireFar = { id = "atlas:AKBurst_Far", volume = 0.9, pitch = PITCH }, -- PLACEHOLDER
		tail = nil,
		dryFire = { id = "atlas:DryFire", volume = FOLEY }, -- PLACEHOLDER (synthesized click)
		magOut = { id = MAG_OUT, volume = FOLEY, pitch = PITCH }, -- PLACEHOLDER
		magIn = { id = MAG_IN, volume = FOLEY, pitch = PITCH }, -- PLACEHOLDER
		rack = { id = RACK, volume = FOLEY, pitch = PITCH }, -- PLACEHOLDER: charging handle
		draw = { id = DRAW, volume = FOLEY, pitch = PITCH }, -- PLACEHOLDER
		inspect = { id = DRAW, volume = FOLEY * 0.6, pitch = { 1.05, 1.1 } }, -- PLACEHOLDER
	},

	-- Phantom: suppressed rifle (quiet shot, no loud tail).
	Phantom = {
		fire = { id = "atlas:AK47Suppressed", volume = 0.75, pitch = PITCH }, -- PLACEHOLDER: filtered AK-47
		fireFar = { id = "atlas:AK47Suppressed_Far", volume = 0.9, pitch = PITCH }, -- PLACEHOLDER
		tail = nil,
		dryFire = { id = "atlas:DryFire", volume = FOLEY }, -- PLACEHOLDER
		magOut = { id = MAG_OUT, volume = FOLEY, pitch = PITCH }, -- PLACEHOLDER
		magIn = { id = MAG_IN, volume = FOLEY, pitch = PITCH }, -- PLACEHOLDER
		rack = { id = RACK, volume = FOLEY, pitch = PITCH }, -- PLACEHOLDER: charging handle
		draw = { id = DRAW, volume = FOLEY, pitch = PITCH }, -- PLACEHOLDER
		inspect = { id = DRAW, volume = FOLEY * 0.6, pitch = { 1.05, 1.1 } }, -- PLACEHOLDER
	},

	-- Classic: default 9 mm pistol. `fire` also plays for the 3-pellet alt-fire.
	Classic = {
		fire = { id = "atlas:PPQ", volume = 0.7, pitch = PITCH }, -- PLACEHOLDER: Walther PPQ 9mm
		fireFar = { id = "atlas:PPQ_Far", volume = 0.85, pitch = PITCH }, -- PLACEHOLDER
		tail = nil,
		dryFire = { id = "atlas:DryFire", volume = FOLEY }, -- PLACEHOLDER
		magOut = { id = MAG_OUT, volume = FOLEY, pitch = { 1.08, 1.14 } }, -- PLACEHOLDER (pitched up: smaller mag)
		magIn = { id = MAG_IN, volume = FOLEY, pitch = { 1.08, 1.14 } }, -- PLACEHOLDER
		rack = { id = RACK, volume = FOLEY, pitch = { 1.1, 1.16 } }, -- PLACEHOLDER: slide racked / released
		draw = { id = DRAW, volume = FOLEY, pitch = { 1.05, 1.1 } }, -- PLACEHOLDER
		inspect = { id = DRAW, volume = FOLEY * 0.6, pitch = { 1.1, 1.15 } }, -- PLACEHOLDER
	},

	-- Shorty: over-under break-action pocket shotgun.
	Shorty = {
		fire = { id = "atlas:Mossberg", volume = 0.8, pitch = PITCH }, -- PLACEHOLDER: Mossberg 190 shotgun
		fireFar = { id = "atlas:Mossberg_Far", volume = 0.9, pitch = PITCH }, -- PLACEHOLDER
		tail = nil,
		dryFire = { id = "atlas:DryFire", volume = FOLEY }, -- PLACEHOLDER (hammer falls on an empty chamber)
		magOut = { id = MAG_OUT, volume = FOLEY, pitch = PITCH }, -- unused (no mag); kept for the type
		magIn = { id = MAG_IN, volume = FOLEY, pitch = PITCH }, -- unused (no mag)
		open = { id = MAG_OUT, volume = FOLEY, pitch = { 0.85, 0.9 } }, -- PLACEHOLDER: barrels break open
		shellIn = { id = MAG_IN, volume = FOLEY * 0.8, pitch = { 1.15, 1.2 } }, -- PLACEHOLDER: shell into a chamber
		rack = { id = RACK, volume = FOLEY, pitch = { 0.9, 0.95 } }, -- PLACEHOLDER: barrels snap shut
		draw = { id = DRAW, volume = FOLEY, pitch = PITCH }, -- PLACEHOLDER
		inspect = { id = DRAW, volume = FOLEY * 0.6, pitch = { 1.05, 1.1 } }, -- PLACEHOLDER
	},

	-- Ghost: suppressed pistol.
	Ghost = {
		fire = { id = "atlas:Ruger22", volume = 0.7, pitch = { 0.95, 1.0 } }, -- PLACEHOLDER: Ruger .22, filtered (quiet)
		fireFar = { id = "atlas:Ruger22_Far", volume = 0.75, pitch = PITCH }, -- PLACEHOLDER
		tail = nil,
		dryFire = { id = "atlas:DryFire", volume = FOLEY }, -- PLACEHOLDER
		magOut = { id = MAG_OUT, volume = FOLEY, pitch = { 1.08, 1.14 } }, -- PLACEHOLDER
		magIn = { id = MAG_IN, volume = FOLEY, pitch = { 1.08, 1.14 } }, -- PLACEHOLDER
		rack = { id = RACK, volume = FOLEY, pitch = { 1.1, 1.16 } }, -- PLACEHOLDER: slide released / racked
		draw = { id = DRAW, volume = FOLEY, pitch = { 1.05, 1.1 } }, -- PLACEHOLDER
		inspect = { id = DRAW, volume = FOLEY * 0.6, pitch = { 1.1, 1.15 } }, -- PLACEHOLDER
	},

	-- Judge: drum-fed automatic shotgun.
	Judge = {
		fire = { id = "atlas:Model12", volume = 0.8, pitch = PITCH }, -- PLACEHOLDER: Winchester Model 12 shotgun
		fireFar = { id = "atlas:Model12_Far", volume = 0.9, pitch = PITCH }, -- PLACEHOLDER
		tail = nil,
		dryFire = { id = "atlas:DryFire", volume = FOLEY }, -- PLACEHOLDER
		magOut = { id = MAG_OUT, volume = FOLEY, pitch = { 0.85, 0.9 } }, -- PLACEHOLDER: drum out (heavier)
		magIn = { id = MAG_IN, volume = FOLEY, pitch = { 0.85, 0.9 } }, -- PLACEHOLDER: drum slapped home
		rack = { id = RACK, volume = FOLEY, pitch = { 0.92, 0.97 } }, -- PLACEHOLDER: charging handle
		draw = { id = DRAW, volume = FOLEY, pitch = PITCH }, -- PLACEHOLDER
		inspect = { id = DRAW, volume = FOLEY * 0.6, pitch = { 1.05, 1.1 } }, -- PLACEHOLDER
	},
}

local GunSounds = {}

GunSounds.DEFAULT = DEFAULT

-- The sound set for a gun id (DEFAULT if it has none).
function GunSounds.get(weaponId: string): GunSoundSet
	return sets[weaponId] or DEFAULT
end

-- Every sound id, for preloading.
function GunSounds.allIds(): { string }
	local out = {}
	for _, set in sets do
		for _, sound in set :: { [string]: GunSound } do
			table.insert(out, sound.id)
		end
	end
	return out
end

return GunSounds
