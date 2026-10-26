--!strict
-- Every weapon as data (vault/01 Design/Weapons.md + Gunplay.md). Adding a gun
-- = a table entry here plus its model in ReplicatedStorage.Weapons (same id)
-- and its clips in Shared/WeaponAnimations.
--
-- New direction (2026-10-25): guns are added one at a time, each finished
-- properly. Gun 1 is the Vandal.

local Types = require(script.Parent.Parent.Types)
local Sounds = require(script.Parent.Sounds)

type WeaponConfig = Types.WeaponConfig

-- Viewmodel: where the gun sits at the hip, camera space. Long guns are placed
-- by their sight (AimPoint) at their grip's depth and point straight ahead
-- (RIVALS references 6 and 7), low on the right.
local RIFLE_VM = Vector3.new(0.31, -0.3, -0.65)

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
		hipSpread = 0.25,
		adsSpreadMultiplier = 0.6,
		bloomPerShot = 0.12,
		maxBloom = 0.75, -- 1.0 degrees at most, standing
		recoil = { up = 0.42, side = 0.15, recover = 0.75 },
		adsFov = 68, -- 1.25x zoom from the 80 degree view
		adsTime = 0.2,
		moveMultiplier = 0.95,
		adsMoveMultiplier = 0.76,
		penetration = "ThinWall",
		sounds = {
			fire = Sounds.ShotMachineGun, -- real AK-47 full-auto shots
			reload = Sounds.MagIn,
			equip = Sounds.Equip,
			cycle = Sounds.Rack,
		},
		viewmodelOffset = RIFLE_VM,
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

-- Hit-zone multipliers used when a gun doesn't set its own head/legs damage.
Weapons.LEGS_MULTIPLIER = 0.85

function Weapons.get(id: string): WeaponConfig?
	return weapons[id]
end

return table.freeze(Weapons)
