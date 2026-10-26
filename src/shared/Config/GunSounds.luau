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

	-- Stinger: Uzi-type SMG.
	Stinger = {
		fire = { id = "atlas:SwedishK", volume = 0.7, pitch = { 1.02, 1.08 } }, -- PLACEHOLDER: Carl Gustav M45 SMG
		fireFar = { id = "atlas:SwedishK_Far", volume = 0.85, pitch = PITCH }, -- PLACEHOLDER
		tail = nil,
		dryFire = { id = "atlas:DryFire", volume = FOLEY }, -- PLACEHOLDER
		magOut = { id = MAG_OUT, volume = FOLEY, pitch = { 1.04, 1.1 } }, -- PLACEHOLDER: mag out of the grip
		magIn = { id = MAG_IN, volume = FOLEY, pitch = { 1.04, 1.1 } }, -- PLACEHOLDER
		rack = { id = RACK, volume = FOLEY, pitch = { 1.05, 1.1 } }, -- PLACEHOLDER: side knob
		draw = { id = DRAW, volume = FOLEY, pitch = PITCH }, -- PLACEHOLDER
		inspect = { id = DRAW, volume = FOLEY * 0.6, pitch = { 1.05, 1.1 } }, -- PLACEHOLDER
	},

	-- Spectre: suppressed SMG.
	Spectre = {
		fire = { id = "atlas:AK47Suppressed", volume = 0.65, pitch = { 1.08, 1.14 } }, -- PLACEHOLDER: filtered AK, pitched up
		fireFar = { id = "atlas:AK47Suppressed_Far", volume = 0.8, pitch = { 1.06, 1.12 } }, -- PLACEHOLDER
		tail = nil,
		dryFire = { id = "atlas:DryFire", volume = FOLEY }, -- PLACEHOLDER
		magOut = { id = MAG_OUT, volume = FOLEY, pitch = { 1.04, 1.1 } }, -- PLACEHOLDER
		magIn = { id = MAG_IN, volume = FOLEY, pitch = { 1.04, 1.1 } }, -- PLACEHOLDER
		rack = { id = RACK, volume = FOLEY, pitch = { 1.02, 1.08 } }, -- PLACEHOLDER: HK-style cocking handle slap
		draw = { id = DRAW, volume = FOLEY, pitch = PITCH }, -- PLACEHOLDER
		inspect = { id = DRAW, volume = FOLEY * 0.6, pitch = { 1.05, 1.1 } }, -- PLACEHOLDER
	},

	-- Bucky: pump shotgun, loads shell by shell.
	Bucky = {
		fire = { id = "atlas:Nova", volume = 0.85, pitch = PITCH }, -- PLACEHOLDER: Benelli Nova 12ga
		fireFar = { id = "atlas:Nova_Far", volume = 0.95, pitch = PITCH }, -- PLACEHOLDER
		tail = nil,
		dryFire = { id = "atlas:DryFire", volume = FOLEY }, -- PLACEHOLDER
		magOut = { id = MAG_OUT, volume = FOLEY, pitch = PITCH }, -- unused (tube magazine)
		magIn = { id = MAG_IN, volume = FOLEY, pitch = PITCH }, -- unused
		shellIn = { id = MAG_IN, volume = FOLEY * 0.85, pitch = { 1.18, 1.25 } }, -- PLACEHOLDER: shell into the tube
		rack = { id = RACK, volume = FOLEY, pitch = { 0.85, 0.9 } }, -- PLACEHOLDER: the pump, after each shot and on an empty reload
		draw = { id = DRAW, volume = FOLEY, pitch = PITCH }, -- PLACEHOLDER
		inspect = { id = DRAW, volume = FOLEY * 0.6, pitch = { 1.05, 1.1 } }, -- PLACEHOLDER
	},

	-- Sheriff: six-shot revolver with a speedloader.
	Sheriff = {
		fire = { id = "atlas:Revolver", volume = 0.85, pitch = PITCH }, -- PLACEHOLDER: S&W .38 revolver
		fireFar = { id = "atlas:Revolver_Far", volume = 0.95, pitch = PITCH }, -- PLACEHOLDER
		tail = nil,
		dryFire = { id = "atlas:DryFire", volume = FOLEY }, -- PLACEHOLDER (hammer on an empty chamber)
		open = { id = MAG_OUT, volume = FOLEY, pitch = { 1.15, 1.2 } }, -- PLACEHOLDER: cylinder swings out
		magOut = { id = RACK, volume = FOLEY * 0.8, pitch = { 1.2, 1.28 } }, -- PLACEHOLDER: ejector rod, cases out
		magIn = { id = MAG_IN, volume = FOLEY, pitch = PITCH }, -- unused (no mag)
		shellIn = { id = MAG_IN, volume = FOLEY, pitch = { 1.1, 1.15 } }, -- PLACEHOLDER: speedloader seats the rounds
		rack = { id = RACK, volume = FOLEY, pitch = { 1.15, 1.22 } }, -- PLACEHOLDER: cylinder flicked shut
		draw = { id = DRAW, volume = FOLEY, pitch = { 1.05, 1.1 } }, -- PLACEHOLDER
		inspect = { id = DRAW, volume = FOLEY * 0.6, pitch = { 1.1, 1.15 } }, -- PLACEHOLDER
	},

	-- Bulldog: bullpup rifle.
	Bulldog = {
		fire = { id = "atlas:AR15", volume = 0.75, pitch = PITCH }, -- PLACEHOLDER: AR-15
		fireFar = { id = "atlas:AR15_Far", volume = 0.9, pitch = PITCH }, -- PLACEHOLDER
		tail = nil,
		dryFire = { id = "atlas:DryFire", volume = FOLEY }, -- PLACEHOLDER
		magOut = { id = MAG_OUT, volume = FOLEY, pitch = PITCH }, -- PLACEHOLDER: mag out of the stock
		magIn = { id = MAG_IN, volume = FOLEY, pitch = PITCH }, -- PLACEHOLDER
		rack = { id = RACK, volume = FOLEY, pitch = PITCH }, -- PLACEHOLDER: charging handle
		draw = { id = DRAW, volume = FOLEY, pitch = PITCH }, -- PLACEHOLDER
		inspect = { id = DRAW, volume = FOLEY * 0.6, pitch = { 1.05, 1.1 } }, -- PLACEHOLDER
	},

	-- Guardian: semi-auto marksman rifle.
	Guardian = {
		fire = { id = "atlas:SKS", volume = 0.85, pitch = PITCH }, -- PLACEHOLDER: SKS
		fireFar = { id = "atlas:SKS_Far", volume = 0.95, pitch = PITCH }, -- PLACEHOLDER
		tail = nil,
		dryFire = { id = "atlas:DryFire", volume = FOLEY }, -- PLACEHOLDER
		magOut = { id = MAG_OUT, volume = FOLEY, pitch = PITCH }, -- PLACEHOLDER
		magIn = { id = MAG_IN, volume = FOLEY, pitch = PITCH }, -- PLACEHOLDER
		rack = { id = RACK, volume = FOLEY, pitch = { 0.95, 1.0 } }, -- PLACEHOLDER: charging handle
		draw = { id = DRAW, volume = FOLEY, pitch = PITCH }, -- PLACEHOLDER
		inspect = { id = DRAW, volume = FOLEY * 0.6, pitch = { 1.05, 1.1 } }, -- PLACEHOLDER
	},

	-- Knife: `fire` is the swing (fireFar: what others hear).
	Knife = {
		fire = { id = id(9125620110), volume = 0.7, pitch = { 0.95, 1.05 } }, -- PLACEHOLDER: ProSoundEffects knife swoosh
		fireFar = { id = id(9125620110), volume = 0.6, pitch = { 0.95, 1.05 } }, -- PLACEHOLDER
		tail = nil,
		dryFire = { id = id(9125620110), volume = 0 }, -- unused (no ammo)
		magOut = { id = MAG_OUT, volume = 0 }, -- unused
		magIn = { id = MAG_IN, volume = 0 }, -- unused
		draw = { id = DRAW, volume = FOLEY, pitch = { 1.2, 1.3 } }, -- PLACEHOLDER: the twirl
		inspect = { id = DRAW, volume = FOLEY * 0.6, pitch = { 1.2, 1.3 } }, -- PLACEHOLDER
	},

	-- Marshal: lever-action rifle.
	Marshal = {
		fire = { id = "atlas:Marlin", volume = 0.85, pitch = PITCH }, -- PLACEHOLDER: Marlin .30-30 lever-action
		fireFar = { id = "atlas:Marlin_Far", volume = 0.95, pitch = PITCH }, -- PLACEHOLDER
		dryFire = { id = "atlas:DryFire", volume = FOLEY }, -- PLACEHOLDER
		magOut = { id = MAG_OUT, volume = FOLEY, pitch = PITCH }, -- PLACEHOLDER (unused: no mag)
		magIn = { id = MAG_IN, volume = FOLEY, pitch = PITCH }, -- PLACEHOLDER (unused: no mag)
		rack = { id = RACK, volume = FOLEY, pitch = { 1.05, 1.12 } }, -- PLACEHOLDER: the lever
		shellIn = { id = MAG_IN, volume = 0.5, pitch = { 1.2, 1.3 } }, -- PLACEHOLDER: a round through the gate
		draw = { id = DRAW, volume = FOLEY, pitch = PITCH }, -- PLACEHOLDER
	},

	-- Outlaw: twin-barrel break-action rifle.
	Outlaw = {
		fire = { id = "atlas:Mosin", volume = 0.9, pitch = { 0.92, 0.97 } }, -- PLACEHOLDER: Mosin-Nagant, pitched down
		fireFar = { id = "atlas:Mosin_Far", volume = 1.0, pitch = PITCH }, -- PLACEHOLDER
		dryFire = { id = "atlas:DryFire", volume = FOLEY }, -- PLACEHOLDER
		magOut = { id = MAG_OUT, volume = FOLEY, pitch = PITCH }, -- PLACEHOLDER (unused: no mag)
		magIn = { id = MAG_IN, volume = FOLEY, pitch = PITCH }, -- PLACEHOLDER (unused: no mag)
		rack = { id = RACK, volume = FOLEY, pitch = { 0.9, 0.95 } }, -- PLACEHOLDER: the action snaps shut
		open = { id = MAG_OUT, volume = FOLEY, pitch = { 0.85, 0.9 } }, -- PLACEHOLDER: the barrels drop
		shellIn = { id = MAG_IN, volume = 0.5, pitch = { 1.15, 1.25 } }, -- PLACEHOLDER: a round into its chamber
		draw = { id = DRAW, volume = FOLEY, pitch = PITCH }, -- PLACEHOLDER
	},

	-- Operator: heavy bolt-action sniper.
	Operator = {
		fire = { id = "atlas:Tikka", volume = 0.95, pitch = { 0.88, 0.93 } }, -- PLACEHOLDER: Tikka bolt rifle, pitched down
		fireFar = { id = "atlas:Tikka_Far", volume = 1.0, pitch = { 0.9, 0.95 } }, -- PLACEHOLDER
		dryFire = { id = "atlas:DryFire", volume = FOLEY }, -- PLACEHOLDER
		magOut = { id = MAG_OUT, volume = FOLEY, pitch = { 0.9, 0.95 } }, -- PLACEHOLDER
		magIn = { id = MAG_IN, volume = FOLEY, pitch = { 0.9, 0.95 } }, -- PLACEHOLDER
		rack = { id = RACK, volume = 0.7, pitch = { 0.85, 0.9 } }, -- PLACEHOLDER: the bolt
		draw = { id = DRAW, volume = FOLEY, pitch = PITCH }, -- PLACEHOLDER
	},

	-- Ares: drum-fed light machine gun.
	Ares = {
		fire = { id = "atlas:PPSh", volume = 0.75, pitch = { 0.86, 0.9 } }, -- PLACEHOLDER: PPSh-41, pitched down (heavier)
		fireFar = { id = "atlas:PPSh_Far", volume = 0.9, pitch = { 0.86, 0.9 } }, -- PLACEHOLDER
		dryFire = { id = "atlas:DryFire", volume = FOLEY }, -- PLACEHOLDER
		magOut = { id = MAG_OUT, volume = 0.7, pitch = { 0.85, 0.9 } }, -- PLACEHOLDER: the drum
		magIn = { id = MAG_IN, volume = 0.7, pitch = { 0.85, 0.9 } }, -- PLACEHOLDER
		rack = { id = RACK, volume = FOLEY, pitch = PITCH }, -- PLACEHOLDER: charging handle
		draw = { id = DRAW, volume = FOLEY, pitch = PITCH }, -- PLACEHOLDER
	},

	-- Odin: belt-fed heavy machine gun.
	Odin = {
		fire = { id = "atlas:AKBurst", volume = 0.8, pitch = { 0.82, 0.86 } }, -- PLACEHOLDER: AK full auto, pitched well down
		fireFar = { id = "atlas:AKBurst_Far", volume = 0.95, pitch = { 0.82, 0.86 } }, -- PLACEHOLDER
		dryFire = { id = "atlas:DryFire", volume = FOLEY }, -- PLACEHOLDER
		magOut = { id = MAG_OUT, volume = 0.7, pitch = { 0.8, 0.85 } }, -- PLACEHOLDER: the ammo box
		magIn = { id = MAG_IN, volume = 0.7, pitch = { 0.8, 0.85 } }, -- PLACEHOLDER
		rack = { id = RACK, volume = 0.7, pitch = { 0.88, 0.92 } }, -- PLACEHOLDER: charging handle
		open = { id = MAG_OUT, volume = FOLEY, pitch = { 1.1, 1.15 } }, -- PLACEHOLDER: the feed cover lifts
		shellIn = { id = RACK, volume = 0.55, pitch = { 1.2, 1.3 } }, -- PLACEHOLDER: the feed cover latches
		draw = { id = DRAW, volume = FOLEY, pitch = PITCH }, -- PLACEHOLDER
	},

	-- Akimbo: two compact automatic pistols.
	Akimbo = {
		fire = { id = "atlas:Bersa", volume = 0.7, pitch = { 1.02, 1.08 } }, -- PLACEHOLDER: Bersa .380, pitched up
		fireFar = { id = "atlas:Bersa_Far", volume = 0.85, pitch = PITCH }, -- PLACEHOLDER
		dryFire = { id = "atlas:DryFire", volume = FOLEY }, -- PLACEHOLDER
		magOut = { id = MAG_OUT, volume = FOLEY, pitch = { 1.08, 1.14 } }, -- PLACEHOLDER
		magIn = { id = MAG_IN, volume = FOLEY, pitch = { 1.08, 1.14 } }, -- PLACEHOLDER
		rack = { id = RACK, volume = FOLEY, pitch = { 1.15, 1.22 } }, -- PLACEHOLDER: the slide
		draw = { id = DRAW, volume = FOLEY, pitch = PITCH }, -- PLACEHOLDER
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
