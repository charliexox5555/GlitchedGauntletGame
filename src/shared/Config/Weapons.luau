--!strict
-- Every weapon as data (vault/01 Design/Weapons.md + Gunplay.md). Adding a gun
-- = a table entry here plus its model in ReplicatedStorage.Weapons (same id),
-- its clips in Shared/WeaponAnimations and its sounds in Config/GunSounds.
--
-- New direction (2026-10-25): guns are added one at a time, each finished
-- properly. Gun 1 is the Vandal.

local Types = require(script.Parent.Parent.Types)

type WeaponConfig = Types.WeaponConfig

-- Viewmodel: where the gun sits at the hip, camera space. Long guns are placed
-- by their sight (AimPoint) at their grip's depth and point straight ahead:
-- big and close in the lower right, so perspective turns the muzzle in
-- toward the centre and shows the gun's left side (the Valorant hold,
-- vault/02 Art/References/rivals-viewmodel/valorant-vandal-hold.webp).
local RIFLE_VM = Vector3.new(0.52, -0.3, -0.38)
-- Tall sights sit a little further out (nothing on screen nearer than 0.35
-- studs to the camera): scopes, and the Ares's raised iron sights.
local SCOPED_VM = Vector3.new(0.52, -0.3, -0.47)
-- Compact SMGs at the rifle depth fill the corner and hide their own rear:
-- further out (round 2 feedback, Stinger and Spectre "too close").
local SMG_VM = Vector3.new(0.46, -0.34, -0.92)
-- Pistols are placed by their grip: big, low and right of centre, held in
-- both hands, high enough that the fists around the grip show.
local SIDEARM_VM = Vector3.new(0.42, -0.76, -1.3)
local SIDEARM_SCALE = 1.1

-- Open iron sights (round 2, RIVALS / Hypershot style, vault/02 Art/References/
-- ads-refs): the eye close behind the rear ring, so it reads big and see-through
-- with the front post centred inside it.
local OPEN_IRONS_ADS = 0.3

local TRACER = Color3.fromHex("FFD9A0") -- warm, like a real tracer round

local weapons: { [string]: WeaponConfig } = {
	-- Rifle -------------------------------------------------------------
	-- Vandal v2 (Gunplay.md §3): heavy-hitting automatic rifle, no falloff.
	-- Four body shots (0.31 s) or two headshots.
	Vandal = {
		id = "Vandal",
		displayName = "Vandal",
		class = "Rifle",
		tier = 3,
		slot = "Primary",
		fireMode = "Auto",
		damage = { body = 30, head = 67, legs = 25 },
		pellets = 1,
		pelletSpread = 0,
		fireInterval = 0.103, -- 9.75 rounds/s
		magSize = 25,
		reloadTime = 2.5, -- tactical: mag swap, then a tug on the charging handle
		emptyReloadTime = 2.8, -- mag swap, then rack the charging handle
		equipTime = 0.5,
		drawTime = 0.9, -- every draw: raise and rack the charging handle
		range = 500,
		-- No falloff. Tap-accurate, three protected shots, then the cone opens
		-- to 1 degree; back to a first-shot tap after 0.375 s off the trigger.
		spread = {
			first = 0.25,
			adsMultiplier = 0.6, -- 0.15 aimed
			protected = 3,
			protectedGrowth = 0.02,
			growth = 0.12,
			max = 1.0,
			recoveryTime = 0.375,
		},
		-- Six pure-vertical kicks, then a smaller climb drifting to one side,
		-- 10% chance per shot to swap sides (at least 0.6 s apart).
		recoil = {
			up = 0.42,
			protected = 6,
			upAfter = 0.25,
			side = 0.3,
			switchChance = 0.1,
			switchMinTime = 0.6,
			recover = 0.75,
			recoverTime = 0.3,
		},
		adsFov = 68, -- 1.25x zoom from the 80 degree view
		adsDistance = OPEN_IRONS_ADS,
		adsTime = 0.2,
		moveMultiplier = 0.95,
		adsMoveMultiplier = 0.76,
		penetration = "ThinWall",
		muzzleDevice = true, -- brake / flash hider: a grey puff, no flare
		viewmodelOffset = Vector3.new(0.52, -0.266, -0.38), -- round 2 sight sits higher: raised by the same to keep the hold
		tracerColor = TRACER,
	},

	-- Phantom v2 (Gunplay.md §3): the Vandal's suppressed companion. Lighter
	-- and faster, a bigger mag, less damage, and a falloff step at 70 studs.
	-- Installed but not in the default loadout yet (gun 2, still in progress).
	Phantom = {
		id = "Phantom",
		displayName = "Phantom",
		class = "Rifle",
		tier = 3,
		slot = "Primary",
		fireMode = "Auto",
		damage = { body = 26, head = 58, legs = 22 },
		pellets = 1,
		pelletSpread = 0,
		fireInterval = 0.091, -- 11 rounds/s
		magSize = 30,
		reloadTime = 2.3,
		emptyReloadTime = 2.8,
		equipTime = 0.45,
		drawTime = 0.8,
		range = 500,
		falloff = { { from = 70, multiplier = 0.87 } },
		spread = {
			first = 0.2,
			adsMultiplier = 0.6, -- 0.12 aimed
			protected = 4,
			protectedGrowth = 0.02,
			growth = 0.1,
			max = 0.9,
			recoveryTime = 0.35,
		},
		recoil = {
			up = 0.32,
			protected = 6,
			upAfter = 0.2,
			side = 0.22,
			switchChance = 0.1,
			switchMinTime = 0.6,
			recover = 0.75,
			recoverTime = 0.28,
		},
		adsFov = 68,
		adsDistance = OPEN_IRONS_ADS,
		adsTime = 0.2,
		moveMultiplier = 0.97,
		adsMoveMultiplier = 0.76,
		penetration = "ThinWall",
		suppressed = true, -- no tracer for enemies, quieter shot, small flash
		viewmodelOffset = Vector3.new(0.52, -0.277, -0.38), -- round 2 sight sits higher: raised by the same to keep the hold
		tracerColor = TRACER,
	},

	-- Sidearm --------------------------------------------------------------
	-- Classic v2 (Gunplay.md §3): the free default pistol and the sidearm
	-- benchmark. No ADS: right mouse fires a 3-pellet close-range burst.
	Classic = {
		id = "Classic",
		displayName = "Classic",
		class = "Sidearm",
		tier = 1,
		slot = "Secondary",
		fireMode = "Semi",
		damage = { body = 26, head = 58, legs = 22 },
		pellets = 1,
		pelletSpread = 0,
		fireInterval = 0.148, -- 6.75 rounds/s
		magSize = 12,
		reloadTime = 1.6,
		emptyReloadTime = 1.9,
		equipTime = 0.35,
		drawTime = 0.6,
		range = 400,
		falloff = { { from = 105, multiplier = 0.85 } },
		spread = {
			first = 0.4,
			adsMultiplier = 1, -- no ADS
			protected = 1,
			protectedGrowth = 0.05,
			growth = 0.3,
			max = 1.8,
			recoveryTime = 0.4,
		},
		recoil = {
			up = 0.55,
			protected = 2,
			upAfter = 0.35,
			side = 0.2,
			switchChance = 0.25,
			switchMinTime = 0.3,
			recover = 0.8,
			recoverTime = 0.25,
		},
		altFire = { pellets = 3, pelletSpread = 3.4, fireInterval = 0.45, ammo = 3 },
		noAds = true,
		lockOnEmpty = true,
		adsFov = 80,
		adsTime = 0.2,
		moveMultiplier = 1,
		adsMoveMultiplier = 1,
		penetration = "None",
		viewmodelOffset = SIDEARM_VM,
		viewmodelScale = SIDEARM_SCALE,
		tracerColor = TRACER,
	},

	-- Shorty v2 (roster 01): over-under break-action pocket shotgun. Two
	-- shells, the upper barrel fires first; one-shots up close, useless far.
	Shorty = {
		id = "Shorty",
		displayName = "Shorty",
		class = "Sidearm",
		moveClass = "Shotgun",
		tier = 1,
		slot = "Secondary",
		fireMode = "Semi",
		damage = { body = 11, head = 22, legs = 9 }, -- per pellet
		pellets = 15,
		pelletSpread = 4,
		fireInterval = 0.333, -- 3 shots/s
		magSize = 2,
		reloadTime = 1.5, -- one shell
		emptyReloadTime = 1.9, -- both shells
		equipTime = 0.35,
		drawTime = 0.55,
		range = 120,
		-- 7 m and 15 m in Valorant (1 stud ~ 0.28 m).
		falloff = { { from = 25, multiplier = 0.55 }, { from = 54, multiplier = 0.27 } },
		spread = {
			first = 0, -- the pellet cone does the spreading
			adsMultiplier = 1,
			protected = 0,
			protectedGrowth = 0,
			growth = 0,
			max = 0,
			recoveryTime = 0.33,
		},
		recoil = {
			up = 2.4,
			protected = 2,
			upAfter = 2.4,
			side = 0,
			switchChance = 0,
			switchMinTime = 1,
			recover = 0.8,
			recoverTime = 0.3,
		},
		noAds = true,
		muzzles = { "Muzzle", "MuzzleLower" },
		shellsOnFire = false,
		hideBeyond = { ShellUpper = 0.35, ShellLower = 0.35 },
		adsFov = 80,
		adsTime = 0.2,
		moveMultiplier = 1,
		adsMoveMultiplier = 1,
		penetration = "None",
		viewmodelOffset = SIDEARM_VM,
		viewmodelScale = SIDEARM_SCALE,
		tracerColor = TRACER,
	},

	-- Ghost v2 (roster 02): slim suppressed pistol, accurate. No one-tap
	-- headshot (v2 keeps those for snipers, the revolver and a DMR).
	Ghost = {
		id = "Ghost",
		displayName = "Ghost",
		class = "Sidearm",
		tier = 1,
		slot = "Secondary",
		fireMode = "Semi",
		damage = { body = 30, head = 67, legs = 25 },
		pellets = 1,
		pelletSpread = 0,
		fireInterval = 0.148, -- 6.75 rounds/s
		magSize = 13,
		reloadTime = 1.5,
		emptyReloadTime = 1.75, -- slide release at the end
		equipTime = 0.35,
		drawTime = 0.55,
		range = 400,
		falloff = { { from = 105, multiplier = 0.83 } },
		spread = {
			first = 0.3,
			adsMultiplier = 1, -- no ADS
			protected = 1,
			protectedGrowth = 0.03,
			growth = 0.25,
			max = 1.65,
			recoveryTime = 0.35,
		},
		recoil = {
			up = 0.45,
			protected = 2,
			upAfter = 0.3,
			side = 0.15,
			switchChance = 0.25,
			switchMinTime = 0.3,
			recover = 0.8,
			recoverTime = 0.25,
		},
		noAds = true,
		lockOnEmpty = true,
		suppressed = true, -- no tracer for enemies, quieter shot, small flash
		adsFov = 80,
		adsTime = 0.2,
		moveMultiplier = 1,
		adsMoveMultiplier = 1,
		penetration = "None",
		viewmodelOffset = SIDEARM_VM,
		viewmodelScale = SIDEARM_SCALE,
		tracerColor = TRACER,
	},

	-- Shotguns ----------------------------------------------------------
	-- Judge v2 (roster 03): compact drum-fed automatic shotgun. No ADS.
	Judge = {
		id = "Judge",
		displayName = "Judge",
		class = "Shotgun",
		tier = 2,
		slot = "Primary",
		fireMode = "Auto",
		damage = { body = 17, head = 34, legs = 14 }, -- per pellet
		pellets = 12,
		pelletSpread = 2.5,
		fireInterval = 0.286, -- 3.5 shots/s
		magSize = 7,
		reloadTime = 2.2,
		emptyReloadTime = 2.6, -- drum, then rack
		equipTime = 0.5,
		drawTime = 0.9,
		range = 150,
		-- 10 m and 15 m in Valorant.
		falloff = { { from = 36, multiplier = 0.59 }, { from = 54, multiplier = 0.41 } },
		spread = {
			first = 0, -- the pellet cone does the spreading...
			adsMultiplier = 1,
			protected = 1,
			protectedGrowth = 0,
			growth = 0.35, -- ...and its centre wanders as you hold the trigger
			max = 1.5,
			recoveryTime = 0.45,
		},
		recoil = {
			up = 1.6,
			protected = 1,
			upAfter = 1.4,
			side = 0.4,
			switchChance = 0.3,
			switchMinTime = 0.3,
			recover = 0.75,
			recoverTime = 0.35,
		},
		noAds = true,
		adsFov = 80,
		adsTime = 0.2,
		moveMultiplier = 0.95,
		adsMoveMultiplier = 1,
		penetration = "None",
		-- No sight to place it by (no ADS) and a chunky drum: further out and
		-- lower than a rifle, so it doesn't fill the corner.
		viewmodelOffset = Vector3.new(0.36, -0.42, -0.95),
		tracerColor = TRACER,
	},

	-- SMGs --------------------------------------------------------------
	-- Stinger v2 (roster 04): Uzi-type SMG, mag in the grip. Shreds up
	-- close; slower than Valorant's 16/s so the body TTK isn't instant.
	Stinger = {
		id = "Stinger",
		displayName = "Stinger",
		class = "SMG",
		tier = 2,
		slot = "Primary",
		fireMode = "Auto",
		damage = { body = 27, head = 61, legs = 23 },
		pellets = 1,
		pelletSpread = 0,
		fireInterval = 0.075, -- 13.3 rounds/s
		magSize = 20,
		reloadTime = 2.1,
		emptyReloadTime = 2.5, -- mag, then the knob rack
		equipTime = 0.4,
		drawTime = 0.8,
		range = 400,
		falloff = { { from = 54, multiplier = 0.85 } }, -- 15 m
		spread = {
			first = 0.45,
			adsMultiplier = 0.6,
			protected = 2,
			protectedGrowth = 0.03,
			growth = 0.1,
			max = 1.4,
			recoveryTime = 0.3,
		},
		recoil = {
			up = 0.25,
			protected = 4,
			upAfter = 0.15,
			side = 0.18,
			switchChance = 0.15,
			switchMinTime = 0.4,
			recover = 0.75,
			recoverTime = 0.25,
		},
		adsFov = 72, -- 1.15x zoom
		adsDistance = OPEN_IRONS_ADS,
		adsTime = 0.16,
		moveMultiplier = 1,
		adsMoveMultiplier = 0.8,
		penetration = "None",
		muzzleDevice = true, -- brake / flash hider: a grey puff, no flare
		viewmodelOffset = Vector3.new(0.46, -0.324, -0.92), -- SMG_VM, raised by the round 2 sight's rise
		tracerColor = TRACER,
	},

	-- Spectre v2 (roster 05): suppressed run-and-gun SMG, steadier than the
	-- Stinger, a bigger mag.
	Spectre = {
		id = "Spectre",
		displayName = "Spectre",
		class = "SMG",
		tier = 2,
		slot = "Primary",
		fireMode = "Auto",
		damage = { body = 26, head = 58, legs = 22 },
		pellets = 1,
		pelletSpread = 0,
		fireInterval = 0.075, -- 13.3 rounds/s
		magSize = 30,
		reloadTime = 2.1,
		emptyReloadTime = 2.5, -- mag, then the cocking-handle rack
		equipTime = 0.4,
		drawTime = 0.8,
		range = 400,
		-- 20 m and 50 m in Valorant.
		falloff = { { from = 71, multiplier = 0.85 }, { from = 178, multiplier = 0.77 } },
		spread = {
			first = 0.4,
			adsMultiplier = 0.6,
			protected = 3,
			protectedGrowth = 0.02,
			growth = 0.09,
			max = 1.4,
			recoveryTime = 0.3,
		},
		recoil = {
			up = 0.22,
			protected = 5,
			upAfter = 0.14,
			side = 0.15,
			switchChance = 0.12,
			switchMinTime = 0.45,
			recover = 0.75,
			recoverTime = 0.25,
		},
		suppressed = true, -- no tracer for enemies, quieter shot, small flash
		adsFov = 72, -- 1.15x zoom
		adsDistance = OPEN_IRONS_ADS,
		adsTime = 0.17,
		moveMultiplier = 1,
		adsMoveMultiplier = 0.8,
		penetration = "None",
		viewmodelOffset = Vector3.new(0.46, -0.325, -0.92), -- round 2 sight sits higher: raised by the same to keep the hold
		leftHandOffset = Vector3.new(0, -0.02, -0.18), -- the mag sits close ahead of the grip
		tracerColor = TRACER,
	},

	-- Bucky v2 (roster 06): pump shotgun, one-shots up close. Loads shell by
	-- shell; firing mid-reload keeps the shells loaded so far.
	Bucky = {
		id = "Bucky",
		displayName = "Bucky",
		class = "Shotgun",
		tier = 2,
		slot = "Primary",
		fireMode = "Pump",
		damage = { body = 17, head = 34, legs = 14 }, -- per pellet
		pellets = 15,
		pelletSpread = 3,
		fireInterval = 0.91, -- 1.1 shots/s (the pump)
		magSize = 5,
		reloadTime = 2.55, -- a full load (5 shells); fallback for the clip-based timing
		emptyReloadTime = 2.55,
		shellReload = { start = 0.25, insert = 0.45, finish = 0.25 },
		equipTime = 0.5,
		drawTime = 1.0, -- racks the pump
		range = 150,
		-- 8 m and 12 m in Valorant.
		falloff = { { from = 29, multiplier = 0.65 }, { from = 43, multiplier = 0.45 } },
		spread = {
			first = 0,
			adsMultiplier = 1,
			protected = 0,
			protectedGrowth = 0,
			growth = 0,
			max = 0,
			recoveryTime = 0.5,
		},
		recoil = {
			up = 3,
			protected = 1,
			upAfter = 3,
			side = 0.3,
			switchChance = 0.5,
			switchMinTime = 0.5,
			recover = 0.8,
			recoverTime = 0.4,
		},
		noAds = true,
		adsFov = 80,
		adsTime = 0.2,
		moveMultiplier = 0.95,
		adsMoveMultiplier = 1,
		penetration = "None",
		viewmodelOffset = Vector3.new(0.48, -0.4, -0.68), -- no sight to place it by: by the grip
		tracerColor = TRACER,
	},

	-- Sheriff v2 (roster 07): six-shot revolver. The one sidearm that
	-- one-taps a head (v2 allows it for the revolver); big kick.
	Sheriff = {
		id = "Sheriff",
		displayName = "Sheriff",
		class = "Sidearm",
		tier = 1,
		slot = "Secondary",
		fireMode = "Semi",
		damage = { body = 55, head = 124, legs = 46 },
		pellets = 1,
		pelletSpread = 0,
		fireInterval = 0.25, -- 4 rounds/s
		magSize = 6,
		reloadTime = 2.25, -- speedloader, same either way
		emptyReloadTime = 2.25,
		equipTime = 0.4,
		drawTime = 0.65, -- cylinder spin
		range = 400,
		falloff = { { from = 107, multiplier = 0.91 } }, -- 30 m
		spread = {
			first = 0.25,
			adsMultiplier = 1, -- no ADS
			protected = 0,
			protectedGrowth = 0,
			growth = 0.6,
			max = 2.75,
			recoveryTime = 0.45,
		},
		recoil = {
			up = 1.8,
			protected = 1,
			upAfter = 1.5,
			side = 0.3,
			switchChance = 0.35,
			switchMinTime = 0.3,
			recover = 0.8,
			recoverTime = 0.35,
		},
		noAds = true,
		shellsOnFire = false, -- the cases leave at the reload (ejector rod)
		hideBeyond = { Rounds = 0.45, Speedloader = 0.3 },
		adsFov = 80,
		adsTime = 0.2,
		moveMultiplier = 1,
		adsMoveMultiplier = 1,
		penetration = "ThinWall",
		viewmodelOffset = SIDEARM_VM,
		viewmodelScale = SIDEARM_SCALE,
		tracerColor = TRACER,
	},

	-- Bulldog v2 (roster 08): budget bullpup rifle, mag behind the grip.
	-- A touch weaker than Valorant's so the body TTK stays in range.
	Bulldog = {
		id = "Bulldog",
		displayName = "Bulldog",
		class = "Rifle",
		tier = 2,
		slot = "Primary",
		fireMode = "Auto",
		damage = { body = 33, head = 74, legs = 28 },
		pellets = 1,
		pelletSpread = 0,
		fireInterval = 0.11, -- 9.1 rounds/s
		magSize = 24,
		reloadTime = 2.3,
		emptyReloadTime = 2.7,
		equipTime = 0.5,
		drawTime = 0.9,
		range = 500,
		spread = {
			first = 0.3,
			adsMultiplier = 0.6,
			protected = 3,
			protectedGrowth = 0.02,
			growth = 0.12,
			max = 1.25,
			recoveryTime = 0.375,
		},
		recoil = {
			up = 0.38,
			protected = 6,
			upAfter = 0.22,
			side = 0.25,
			switchChance = 0.12,
			switchMinTime = 0.6,
			recover = 0.75,
			recoverTime = 0.3,
		},
		adsFov = 68, -- 1.25x zoom
		adsDistance = OPEN_IRONS_ADS,
		adsTime = 0.2,
		moveMultiplier = 0.95,
		adsMoveMultiplier = 0.76,
		penetration = "ThinWall",
		muzzleDevice = true, -- brake / flash hider: a grey puff, no flare
		viewmodelOffset = Vector3.new(0.44, -0.278, -0.85), -- round 2 sight sits higher: raised by the same to keep the hold
		-- Bullpup: the mag sits behind the grip, under the camera. Raise the gun
		-- and push it out during reloads so the mag change is on screen.
		trackLift = {
			Reload = { pos = Vector3.new(-0.2, 0.32, -0.4) },
		},
		tracerColor = TRACER,
	},

	-- Guardian v2 (roster 09): semi-auto marksman rifle (the DMR). One-taps a
	-- head, two body shots; perfect first shot when aimed.
	Guardian = {
		id = "Guardian",
		displayName = "Guardian",
		class = "Rifle",
		tier = 3,
		slot = "Primary",
		fireMode = "Semi",
		damage = { body = 65, head = 146, legs = 49 },
		pellets = 1,
		pelletSpread = 0,
		fireInterval = 0.19, -- 5.25 rounds/s
		magSize = 12,
		reloadTime = 2.3,
		emptyReloadTime = 2.7,
		equipTime = 0.55,
		drawTime = 1.0,
		range = 600,
		spread = {
			first = 0.1,
			adsMultiplier = 0, -- aimed: the first shot goes exactly where you aim
			protected = 0,
			protectedGrowth = 0,
			growth = 0.45,
			max = 1.58,
			recoveryTime = 0.4,
		},
		recoil = {
			up = 1.2,
			protected = 1,
			upAfter = 1.0,
			side = 0.2,
			switchChance = 0.3,
			switchMinTime = 0.4,
			recover = 0.8,
			recoverTime = 0.3,
		},
		adsFov = 58, -- 1.5x zoom
		adsDistance = OPEN_IRONS_ADS,
		adsTime = 0.25,
		moveMultiplier = 0.9,
		adsMoveMultiplier = 0.76,
		penetration = "ThinWall",
		muzzleDevice = true, -- brake / flash hider: a grey puff, no flare
		viewmodelOffset = RIFLE_VM,
		tracerColor = TRACER,
	},

	-- Snipers ------------------------------------------------------------
	-- Marshal v2 (roster 11): cheap lever-action scoped rifle. One-shots a
	-- head; loads round by round through the side gate (firing mid-reload
	-- keeps the rounds loaded).
	Marshal = {
		id = "Marshal",
		displayName = "Marshal",
		class = "Sniper",
		tier = 2,
		slot = "Primary",
		fireMode = "Bolt", -- the lever cycles after every shot
		damage = { body = 101, head = 202, legs = 85 },
		pellets = 1,
		pelletSpread = 0,
		fireInterval = 0.667, -- 1.5 rounds/s
		magSize = 5,
		reloadTime = 2.5, -- a full load (5 rounds); fallback for the clip-based timing
		emptyReloadTime = 2.5,
		shellReload = { start = 0.3, insert = 0.4, finish = 0.35 },
		equipTime = 0.7,
		drawTime = 1.2, -- works the lever
		range = 800,
		spread = {
			first = 1, -- hip
			adsMultiplier = 0, -- scoped: exactly where you aim (standing)
			protected = 0,
			protectedGrowth = 0,
			growth = 0.5,
			max = 2,
			recoveryTime = 0.6,
		},
		recoil = {
			up = 2.5,
			protected = 1,
			upAfter = 2.5,
			side = 0.3,
			switchChance = 0.5,
			switchMinTime = 0.3,
			recover = 0.85,
			recoverTime = 0.35,
		},
		scope = { zoom = 3.5 },
		adsFov = 50, -- unused (the scope sets the zoom)
		adsTime = 0.25,
		moveMultiplier = 0.95,
		adsMoveMultiplier = 0.6,
		penetration = "ThinWall",
		viewmodelOffset = SCOPED_VM,
		tracerColor = TRACER,
	},

	-- Outlaw v2 (roster 12): twin-barrel break-action scoped rifle. Two quick
	-- big shots (upper barrel first), then a slow reload.
	Outlaw = {
		id = "Outlaw",
		displayName = "Outlaw",
		class = "Sniper",
		tier = 3,
		slot = "Primary",
		fireMode = "Semi",
		damage = { body = 140, head = 238, legs = 119 },
		pellets = 1,
		pelletSpread = 0,
		fireInterval = 0.364, -- 2.75 rounds/s
		magSize = 2,
		reloadTime = 2.3, -- one round (the upper barrel)
		emptyReloadTime = 3.8, -- both
		muzzles = { "Muzzle", "MuzzleLower" },
		shellsOnFire = false, -- the reload clip shows the spent rounds
		hideBeyond = { RoundUpper = 0.35, RoundLower = 0.35 },
		equipTime = 0.75,
		drawTime = 1.1, -- snaps the action
		range = 800,
		spread = {
			first = 3.5, -- hip
			adsMultiplier = 0,
			protected = 0,
			protectedGrowth = 0,
			growth = 0.5,
			max = 4,
			recoveryTime = 0.5,
		},
		recoil = {
			up = 3.6,
			protected = 1,
			upAfter = 3.6,
			side = 0.5,
			switchChance = 0.5,
			switchMinTime = 0.2,
			recover = 0.85,
			recoverTime = 0.35,
		},
		scope = { zoom = 3.5 },
		adsFov = 50, -- unused (the scope sets the zoom)
		adsTime = 0.28,
		moveMultiplier = 0.9,
		adsMoveMultiplier = 0.55,
		penetration = "ThinWall",
		viewmodelOffset = SCOPED_VM,
		tracerColor = TRACER,
	},

	-- Operator v2 (roster 13): heavy bolt-action sniper. One-shots the body;
	-- slow to scope, slow to move with while scoped. (Valorant's second 5x
	-- zoom level isn't built: one 2.5x scope.)
	Operator = {
		id = "Operator",
		displayName = "Operator",
		class = "Sniper",
		tier = 4,
		slot = "Primary",
		fireMode = "Bolt",
		damage = { body = 150, head = 255, legs = 120 },
		pellets = 1,
		pelletSpread = 0,
		fireInterval = 1.667, -- 0.6 rounds/s (the bolt)
		magSize = 5,
		reloadTime = 3.2,
		emptyReloadTime = 3.7, -- mag, then the bolt
		equipTime = 0.9,
		drawTime = 1.4,
		range = 1000,
		spread = {
			first = 5, -- hip
			adsMultiplier = 0,
			protected = 0,
			protectedGrowth = 0,
			growth = 0.5,
			max = 6,
			recoveryTime = 0.8,
		},
		recoil = {
			up = 5,
			protected = 1,
			upAfter = 5,
			side = 0.4,
			switchChance = 0.5,
			switchMinTime = 0.3,
			recover = 0.9,
			recoverTime = 0.45,
		},
		scope = { zoom = 2.5 },
		adsFov = 50, -- unused (the scope sets the zoom)
		adsTime = 0.38,
		moveMultiplier = 0.85,
		adsMoveMultiplier = 0.4,
		penetration = "All",
		muzzleDevice = true, -- brake / flash hider: a grey puff, no flare
		viewmodelOffset = SCOPED_VM,
		tracerColor = TRACER,
	},

	-- Machine guns -------------------------------------------------------
	-- Ares v2 (roster 14): drum-fed LMG. The reverse of every other gun: it
	-- tightens as it fires (1 degree down to 0.7). Iron-sight ADS.
	Ares = {
		id = "Ares",
		displayName = "Ares",
		class = "MachineGun",
		tier = 3,
		slot = "Primary",
		fireMode = "Auto",
		damage = { body = 30, head = 75, legs = 25 },
		pellets = 1,
		pelletSpread = 0,
		fireInterval = 0.077, -- 13 rounds/s
		magSize = 50,
		reloadTime = 3.25,
		emptyReloadTime = 3.8, -- drum, then the charging handle
		equipTime = 0.8,
		drawTime = 1.25,
		range = 500,
		-- 30 m in Valorant.
		falloff = { { from = 107, multiplier = 0.93 } },
		spread = {
			first = 1,
			adsMultiplier = 0.75,
			protected = 0,
			protectedGrowth = 0,
			growth = -0.03, -- tightens as it fires
			max = 0.7, -- the floor it tightens to
			recoveryTime = 0.5,
		},
		recoil = {
			up = 0.28,
			protected = 6,
			upAfter = 0.12,
			side = 0.18,
			switchChance = 0.15,
			switchMinTime = 0.5,
			recover = 0.7,
			recoverTime = 0.35,
		},
		adsFov = 70, -- 1.15x zoom
		adsDistance = OPEN_IRONS_ADS,
		adsTime = 0.3,
		moveMultiplier = 0.9,
		adsMoveMultiplier = 0.7,
		penetration = "ThinWall",
		muzzleDevice = true, -- brake / flash hider: a grey puff, no flare
		viewmodelOffset = Vector3.new(0.52, -0.291, -0.43), -- round 2 sight sits higher: raised by the same to keep the hold
		tracerColor = TRACER,
	},

	-- Odin v2 (roster 15): belt-fed HMG. Spins up from 12 to 15.6 rounds/s,
	-- a 100-round box, shoots through walls. Iron-sight ADS.
	Odin = {
		id = "Odin",
		displayName = "Odin",
		class = "MachineGun",
		tier = 4,
		slot = "Primary",
		fireMode = "Auto",
		damage = { body = 38, head = 95, legs = 32 },
		pellets = 1,
		pelletSpread = 0,
		fireInterval = 0.064, -- 15.6 rounds/s once spun up
		spinUp = { startInterval = 0.083, endInterval = 0.064, time = 1.0 },
		magSize = 100,
		reloadTime = 4.2,
		emptyReloadTime = 5, -- box, then the charging handle
		equipTime = 0.9,
		drawTime = 1.3,
		range = 500,
		-- 30 m in Valorant.
		falloff = { { from = 107, multiplier = 0.82 } },
		spread = {
			first = 0.8,
			adsMultiplier = 0.75,
			protected = 2,
			protectedGrowth = 0.02,
			growth = 0.04,
			max = 1.3,
			recoveryTime = 0.5,
		},
		recoil = {
			up = 0.3,
			protected = 4,
			upAfter = 0.16,
			side = 0.22,
			switchChance = 0.15,
			switchMinTime = 0.45,
			recover = 0.7,
			recoverTime = 0.4,
		},
		adsFov = 70, -- 1.15x zoom
		adsTime = 0.32,
		adsDistance = OPEN_IRONS_ADS,
		moveMultiplier = 0.85,
		adsMoveMultiplier = 0.65,
		penetration = "All",
		muzzleDevice = true, -- brake / flash hider: a grey puff, no flare
		viewmodelOffset = RIFLE_VM,
		tracerColor = TRACER,
	},

	-- Akimbo v2 (roster 16): a pair of compact automatic pistols, one in each
	-- hand, firing in turn. Hip fire only. (One shared mag for both guns.)
	Akimbo = {
		id = "Akimbo",
		displayName = "Akimbo",
		class = "SMG",
		tier = 2,
		slot = "Primary",
		fireMode = "Auto",
		damage = { body = 22, head = 48, legs = 19 },
		pellets = 1,
		pelletSpread = 0,
		fireInterval = 0.08, -- 12.5 rounds/s, alternating guns
		magSize = 36, -- 18 a gun
		reloadTime = 2.3,
		emptyReloadTime = 2.7, -- both slides locked back
		equipTime = 0.5,
		drawTime = 0.8,
		range = 350,
		-- 15 m and 30 m.
		falloff = { { from = 54, multiplier = 0.85 }, { from = 107, multiplier = 0.7 } },
		spread = {
			first = 0.6,
			adsMultiplier = 1, -- no ADS
			protected = 2,
			protectedGrowth = 0.03,
			growth = 0.07,
			max = 2,
			recoveryTime = 0.3,
		},
		recoil = {
			up = 0.25,
			protected = 4,
			upAfter = 0.15,
			side = 0.2,
			switchChance = 0.3,
			switchMinTime = 0.25,
			recover = 0.75,
			recoverTime = 0.25,
		},
		noAds = true,
		models = { right = "Akimbo", left = "Akimbo" },
		lockOnEmpty = true,
		adsFov = 80,
		adsTime = 0.2,
		moveMultiplier = 1,
		adsMoveMultiplier = 1,
		penetration = "None",
		viewmodelOffset = Vector3.new(0.55, -0.78, -1.3), -- each gun out toward its own side
		viewmodelScale = SIDEARM_SCALE,
		tracerColor = TRACER,
	},

	-- Melee --------------------------------------------------------------
	-- Knife v2 (roster 10): everyone's melee. Front swing 50, backstab 100,
	-- a short lunge on hit. (Valorant's heavy right-click attack isn't built.)
	Knife = {
		id = "Knife",
		displayName = "Knife",
		class = "Melee",
		tier = 0,
		slot = "Melee",
		fireMode = "Melee",
		damage = { body = 50, head = 50, legs = 50 },
		pellets = 1,
		pelletSpread = 0,
		fireInterval = 0.6,
		magSize = 0,
		reloadTime = 0,
		emptyReloadTime = 0,
		equipTime = 0.25,
		drawTime = 0.45, -- the twirl
		range = 7, -- about 2 m
		spread = {
			first = 0,
			adsMultiplier = 1,
			protected = 0,
			protectedGrowth = 0,
			growth = 0,
			max = 0,
			recoveryTime = 0.5,
		},
		recoil = {
			up = 0,
			protected = 0,
			upAfter = 0,
			side = 0,
			switchChance = 0,
			switchMinTime = 1,
			recover = 1,
			recoverTime = 0.2,
		},
		-- Valorant-style: light slashes chain 1 -> 2 -> 3; right-click is a
		-- two-handed heavy stab with its own 1 s cooldown (altFire).
		melee = {
			range = 7,
			backDamage = 100,
			lunge = 6,
			comboWindow = 0.45,
			heavy = { damage = 75, backDamage = 100, lunge = 8 },
		},
		altFire = { pellets = 1, pelletSpread = 0, fireInterval = 1.0, ammo = 1 },
		noAds = true,
		shellsOnFire = false,
		adsFov = 80,
		adsTime = 0.1,
		moveMultiplier = 1.05,
		adsMoveMultiplier = 1,
		penetration = "None",
		-- Held bigger and blade-up so the knife reads past the hand.
		viewmodelOffset = Vector3.new(0.5, -0.58, -1.15),
		viewmodelRotation = Vector3.new(28, 18, -22),
		viewmodelScale = 1.0,
		tracerColor = TRACER,
	},
}

for _, w in weapons do
	table.freeze(w)
end

local Weapons = {}

Weapons.list = table.freeze(weapons)

-- Starting loadout. Slots without a gun yet stay empty.
Weapons.DEFAULT_LOADOUT = table.freeze({
	Primary = "Vandal",
	Secondary = "Classic",
	Melee = "Knife",
}) :: { [Types.Slot]: string }

-- Hit-zone multipliers used when a gun doesn't set its own head/legs damage
-- (Gunplay.md §3: rifles kill with two headshots).
Weapons.HEAD_MULTIPLIER = 2.25
Weapons.LEGS_MULTIPLIER = 0.85

function Weapons.get(id: string): WeaponConfig?
	return weapons[id]
end

return table.freeze(Weapons)
