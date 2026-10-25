--!strict
-- Every weapon as data (vault/01 Design/Weapons.md + Gunplay.md). Starting
-- values for playtesting, not final balance. Adding a gun = a table entry here
-- plus its model in ReplicatedStorage.Weapons (same id).
--
-- Wave 1 is enabled; wave 2/3 guns have models but no stats yet.

local Types = require(script.Parent.Parent.Types)
local Sounds = require(script.Parent.Sounds)

type WeaponConfig = Types.WeaponConfig

local NEON = Color3.fromHex("00E5FF")
local MAGENTA = Color3.fromHex("FF3DCB")

-- Class defaults (Gunplay.md §2): hip spread and ADS.
local SIDEARM_VM = Vector3.new(0.5, -0.55, -1.3)
local RIFLE_VM = Vector3.new(0.55, -0.62, -1.4)

local weapons: { [string]: WeaponConfig } = {
	-- Sidearms ----------------------------------------------------------
	Byte = {
		id = "Byte",
		displayName = "Byte",
		class = "Sidearm",
		tier = 1,
		slot = "Secondary",
		fireMode = "Semi",
		damage = { body = 25, head = 38 },
		pellets = 1,
		pelletSpread = 0,
		fireInterval = 0.16,
		magSize = 12,
		reloadTime = 1.3,
		emptyReloadTime = 1.6,
		equipTime = 0.2,
		range = 400,
		falloff = { start = 40, finish = 80, minMultiplier = 0.75 },
		hipSpread = 0.8,
		adsSpreadMultiplier = 0.35,
		bloomPerShot = 0.15,
		maxBloom = 1.2,
		recoil = { up = 0.9, side = 0.12, recover = 0.7 },
		adsFov = 70,
		adsTime = 0.15,
		moveMultiplier = 1,
		adsMoveMultiplier = 0.75,
		penetration = "None",
		sounds = { fire = Sounds.ShotPistol, reload = Sounds.MagIn, equip = Sounds.Equip },
		viewmodelOffset = SIDEARM_VM,
		tracerColor = NEON,
	},
	Root = {
		id = "Root",
		displayName = "Root",
		class = "Sidearm",
		tier = 1,
		slot = "Secondary",
		fireMode = "Semi",
		damage = { body = 50, head = 105 },
		pellets = 1,
		pelletSpread = 0,
		fireInterval = 0.45,
		magSize = 6,
		reloadTime = 2.0,
		emptyReloadTime = 2.3,
		equipTime = 0.2,
		range = 400,
		-- One-tap headshot inside 25 studs, then it drops off.
		falloff = { start = 25, finish = 60, minMultiplier = 0.65 },
		hipSpread = 0.8,
		adsSpreadMultiplier = 0.35,
		bloomPerShot = 0.5,
		maxBloom = 1.5,
		recoil = { up = 2.6, side = 0.3, recover = 0.7 },
		adsFov = 68,
		adsTime = 0.17,
		moveMultiplier = 1,
		adsMoveMultiplier = 0.75,
		penetration = "None",
		sounds = {
			fire = Sounds.ShotHeavyPistol,
			fireVolume = 0.9,
			reload = Sounds.MagIn,
			equip = Sounds.Equip,
		},
		viewmodelOffset = SIDEARM_VM,
		tracerColor = NEON,
	},

	-- SMG ---------------------------------------------------------------
	Bandwidth = {
		id = "Bandwidth",
		displayName = "Bandwidth",
		class = "SMG",
		tier = 2,
		slot = "Primary",
		fireMode = "Auto",
		damage = { body = 20, head = 30 },
		pellets = 1,
		pelletSpread = 0,
		fireInterval = 0.075,
		magSize = 30,
		reloadTime = 1.8,
		emptyReloadTime = 2.2,
		equipTime = 0.3,
		range = 300,
		-- Drops to 16 damage after 25 studs.
		falloff = { start = 25, finish = 27, minMultiplier = 0.8 },
		hipSpread = 1.2,
		adsSpreadMultiplier = 0.35,
		bloomPerShot = 0.12,
		maxBloom = 1.4,
		recoil = { up = 0.32, side = 0.14, recover = 0.7 },
		adsFov = 70,
		adsTime = 0.15,
		moveMultiplier = 1,
		adsMoveMultiplier = 0.8,
		penetration = "None",
		sounds = {
			fire = Sounds.ShotSmg,
			fireVolume = 0.7,
			reload = Sounds.MagIn,
			equip = Sounds.Equip,
		},
		viewmodelOffset = RIFLE_VM,
		tracerColor = NEON,
	},

	-- Shotgun -----------------------------------------------------------
	HardReset = {
		id = "HardReset",
		displayName = "Hard Reset",
		class = "Shotgun",
		tier = 2,
		slot = "Primary",
		fireMode = "Pump",
		damage = { body = 11, head = 16 },
		pellets = 10,
		pelletSpread = 5,
		fireInterval = 0.85,
		magSize = 5,
		reloadTime = 2.4,
		emptyReloadTime = 2.8,
		equipTime = 0.3,
		range = 120,
		falloff = { start = 10, finish = 30, minMultiplier = 0.3 },
		hipSpread = 0,
		adsSpreadMultiplier = 0.8,
		bloomPerShot = 0,
		maxBloom = 0,
		recoil = { up = 3.2, side = 0.5, recover = 0.75 },
		adsFov = 72,
		adsTime = 0.18,
		moveMultiplier = 0.95,
		adsMoveMultiplier = 0.75,
		penetration = "None",
		sounds = { fire = Sounds.ShotShotgun, reload = Sounds.Cycle, equip = Sounds.Equip },
		viewmodelOffset = RIFLE_VM,
		tracerColor = NEON,
	},

	-- Sniper ------------------------------------------------------------
	LongPoll = {
		id = "LongPoll",
		displayName = "Long Poll",
		class = "Sniper",
		tier = 2,
		slot = "Primary",
		fireMode = "Bolt",
		damage = { body = 75, head = 150 },
		pellets = 1,
		pelletSpread = 0,
		fireInterval = 1.1,
		magSize = 5,
		reloadTime = 2.4,
		emptyReloadTime = 2.9,
		equipTime = 0.35,
		range = 800,
		hipSpread = 4,
		adsSpreadMultiplier = 0,
		bloomPerShot = 0,
		maxBloom = 0,
		recoil = { up = 4, side = 0.4, recover = 0.8 },
		adsFov = 32, -- 2.5x zoom
		adsTime = 0.2,
		scope = true,
		moveMultiplier = 0.95,
		adsMoveMultiplier = 0.55,
		penetration = "None",
		sounds = { fire = Sounds.ShotSniper, reload = Sounds.Cycle, equip = Sounds.Equip },
		viewmodelOffset = RIFLE_VM,
		tracerColor = NEON,
	},

	-- Rifle -------------------------------------------------------------
	Bitrate = {
		id = "Bitrate",
		displayName = "Bitrate",
		class = "Rifle",
		tier = 3,
		slot = "Primary",
		fireMode = "Auto",
		damage = { body = 22, head = 33 },
		pellets = 1,
		pelletSpread = 0,
		fireInterval = 0.095,
		magSize = 30,
		reloadTime = 2.0,
		emptyReloadTime = 2.5,
		equipTime = 0.3,
		range = 500,
		falloff = { start = 40, finish = 80, minMultiplier = 0.85 },
		hipSpread = 1.4,
		adsSpreadMultiplier = 0.35,
		bloomPerShot = 0.15,
		maxBloom = 1.5,
		recoil = { up = 0.35, side = 0.12, recover = 0.7 },
		adsFov = 62,
		adsTime = 0.18,
		moveMultiplier = 1,
		adsMoveMultiplier = 0.75,
		penetration = "None",
		suppressed = true,
		sounds = {
			fire = Sounds.ShotRifle,
			fireVolume = 0.55,
			reload = Sounds.MagIn,
			equip = Sounds.Equip,
		},
		viewmodelOffset = RIFLE_VM,
		tracerColor = NEON,
	},

	-- Machine gun -------------------------------------------------------
	Flood = {
		id = "Flood",
		displayName = "Flood",
		class = "MachineGun",
		tier = 3,
		slot = "Primary",
		fireMode = "Auto",
		damage = { body = 28, head = 42 },
		pellets = 1,
		pelletSpread = 0,
		fireInterval = 0.06,
		spinUp = { startInterval = 0.12, endInterval = 0.06, time = 1.2 },
		magSize = 100,
		reloadTime = 4.0,
		emptyReloadTime = 4.5,
		equipTime = 0.45,
		range = 500,
		falloff = { start = 40, finish = 90, minMultiplier = 0.8 },
		hipSpread = 2.0,
		adsSpreadMultiplier = 0.4,
		bloomPerShot = 0.08,
		maxBloom = 1.6,
		recoil = { up = 0.3, side = 0.18, recover = 0.7 },
		adsFov = 66,
		adsTime = 0.25,
		moveMultiplier = 0.75,
		adsMoveMultiplier = 0.7,
		penetration = "ThinWall",
		sounds = {
			fire = Sounds.ShotMachineGun,
			fireVolume = 0.65,
			reload = Sounds.MagIn,
			equip = Sounds.Equip,
		},
		viewmodelOffset = RIFLE_VM,
		tracerColor = NEON,
	},

	-- Wildcard ----------------------------------------------------------
	RayTrace = {
		id = "RayTrace",
		displayName = "Ray Trace",
		class = "Wildcard",
		tier = 4,
		slot = "Primary",
		fireMode = "Charge",
		damage = { body = 100, head = 200 },
		pellets = 1,
		pelletSpread = 0,
		fireInterval = 0.9,
		chargeTime = 0.5,
		magSize = 4,
		reloadTime = 2.8,
		emptyReloadTime = 3.2,
		equipTime = 0.35,
		range = 800,
		hipSpread = 0.3,
		adsSpreadMultiplier = 0,
		bloomPerShot = 0,
		maxBloom = 0,
		recoil = { up = 3.5, side = 0.3, recover = 0.8 },
		adsFov = 55,
		adsTime = 0.2,
		moveMultiplier = 0.9,
		adsMoveMultiplier = 0.7,
		penetration = "All",
		pierceCharacters = true,
		sounds = {
			fire = Sounds.ShotRail,
			reload = Sounds.MagIn,
			equip = Sounds.Equip,
			charge = Sounds.RailCharge,
		},
		viewmodelOffset = RIFLE_VM,
		tracerColor = MAGENTA,
	},

	-- Melee -------------------------------------------------------------
	Cutter = {
		id = "Cutter",
		displayName = "Cutter",
		class = "Melee",
		tier = 0,
		slot = "Melee",
		fireMode = "Melee",
		damage = { body = 40, head = 40, legs = 40 },
		pellets = 1,
		pelletSpread = 0,
		fireInterval = 0.6,
		magSize = 0,
		reloadTime = 0,
		emptyReloadTime = 0,
		equipTime = 0.2,
		range = 7,
		hipSpread = 0,
		adsSpreadMultiplier = 1,
		bloomPerShot = 0,
		maxBloom = 0,
		recoil = { up = 0, side = 0, recover = 1 },
		adsFov = 80,
		adsTime = 0.1,
		moveMultiplier = 1.05,
		adsMoveMultiplier = 1,
		penetration = "None",
		melee = { range = 7, backDamage = 100, lunge = 6 },
		sounds = { fire = Sounds.Swing, equip = Sounds.Equip },
		viewmodelOffset = Vector3.new(0.65, -0.7, -1.2),
		tracerColor = NEON,
	},
}

for _, w in weapons do
	table.freeze(w)
end

local Weapons = {}

Weapons.list = table.freeze(weapons)

-- Wave 1 starting loadout (Gunplay build order: Byte first, Bitrate second).
Weapons.DEFAULT_LOADOUT = table.freeze({
	Primary = "Bitrate",
	Secondary = "Byte",
	Melee = "Cutter",
})

-- Order used by the dev weapon picker (Studio only).
Weapons.DEV_CYCLE = table.freeze({
	Primary = { "Bitrate", "Bandwidth", "HardReset", "LongPoll", "Flood", "RayTrace" },
	Secondary = { "Byte", "Root" },
})

-- Hit-zone multipliers used when a gun doesn't set its own head/legs damage.
Weapons.LEGS_MULTIPLIER = 0.85

function Weapons.get(id: string): WeaponConfig?
	return weapons[id]
end

return table.freeze(Weapons)
