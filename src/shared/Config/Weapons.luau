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
		adsFov = 80,
		adsTime = 0.2,
		moveMultiplier = 1,
		adsMoveMultiplier = 1,
		penetration = "None",
		viewmodelOffset = SIDEARM_VM,
		viewmodelScale = SIDEARM_SCALE,
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
}) :: { [Types.Slot]: string }

-- Hit-zone multipliers used when a gun doesn't set its own head/legs damage
-- (Gunplay.md §3: rifles kill with two headshots).
Weapons.HEAD_MULTIPLIER = 2.25
Weapons.LEGS_MULTIPLIER = 0.85

function Weapons.get(id: string): WeaponConfig?
	return weapons[id]
end

return table.freeze(Weapons)
