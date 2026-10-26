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
-- by their sight (AimPoint) at their grip's depth and point straight ahead
-- (RIVALS references 6 and 7), low on the right.
local RIFLE_VM = Vector3.new(0.31, -0.3, -0.65)
-- Pistols are placed by their grip: big, low and just right of centre, held
-- in both hands.
local SIDEARM_VM = Vector3.new(0.33, -1.06, -1.47)
local SIDEARM_SCALE = 1.1

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
		reloadTime = 2.3, -- tactical: mag swap only
		emptyReloadTime = 2.8, -- mag swap, then rack the charging handle
		equipTime = 0.5,
		firstEquipTime = 0.9, -- first draw of a life: raise and rack the charging handle
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
		adsTime = 0.2,
		moveMultiplier = 0.95,
		adsMoveMultiplier = 0.76,
		penetration = "ThinWall",
		viewmodelOffset = RIFLE_VM,
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
		firstEquipTime = 0.8,
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
		adsTime = 0.2,
		moveMultiplier = 0.97,
		adsMoveMultiplier = 0.76,
		penetration = "ThinWall",
		suppressed = true, -- no tracer for enemies, quieter shot, small flash
		viewmodelOffset = RIFLE_VM,
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
		firstEquipTime = 0.6,
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
		firstEquipTime = 0.55,
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
		firstEquipTime = 0.55,
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
		firstEquipTime = 0.9,
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
		firstEquipTime = 0.8,
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
		adsTime = 0.16,
		moveMultiplier = 1,
		adsMoveMultiplier = 0.8,
		penetration = "None",
		viewmodelOffset = RIFLE_VM,
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
		firstEquipTime = 0.8,
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
		adsTime = 0.17,
		moveMultiplier = 1,
		adsMoveMultiplier = 0.8,
		penetration = "None",
		viewmodelOffset = RIFLE_VM,
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
		firstEquipTime = 1.0, -- racks the pump
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
		viewmodelOffset = Vector3.new(0.36, -0.42, -0.95), -- no sight to place it by, like the Judge
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
		firstEquipTime = 0.65, -- cylinder spin
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
		firstEquipTime = 0.9,
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
		adsTime = 0.2,
		moveMultiplier = 0.95,
		adsMoveMultiplier = 0.76,
		penetration = "ThinWall",
		viewmodelOffset = RIFLE_VM,
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
		firstEquipTime = 1.0,
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
		adsTime = 0.25,
		moveMultiplier = 0.9,
		adsMoveMultiplier = 0.76,
		penetration = "ThinWall",
		viewmodelOffset = RIFLE_VM,
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
		firstEquipTime = 0.45, -- the twirl
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
		melee = { range = 7, backDamage = 100, lunge = 6 },
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
