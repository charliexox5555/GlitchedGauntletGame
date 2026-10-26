--!strict
-- Pure damage maths, shared so the HUD can preview what the server computes.
-- The server is the only side that applies damage.

local Types = require(script.Parent.Parent.Types)
local Weapons = require(script.Parent.Parent.Config.Weapons)

type WeaponConfig = Types.WeaponConfig
type HitZone = Types.HitZone

local Damage = {}

function Damage.zoneOf(partName: string): HitZone
	if partName == "Head" then
		return "Head"
	end
	if string.find(partName, "Leg") or string.find(partName, "Foot") then
		return "Legs"
	end
	return "Body"
end

-- Step falloff: the multiplier of the last step whose distance is reached.
function Damage.falloff(config: WeaponConfig, distance: number): number
	local steps = config.falloff
	local multiplier = 1
	if steps then
		for _, step in steps do
			if distance >= step.from then
				multiplier = step.multiplier
			end
		end
	end
	return multiplier
end

-- Head and legs use the gun's own numbers when it has them, else the defaults
-- (head ×2.25, legs ×0.85).
function Damage.base(config: WeaponConfig, zone: HitZone): number
	if zone == "Head" then
		return config.damage.head or config.damage.body * Weapons.HEAD_MULTIPLIER
	elseif zone == "Legs" then
		return config.damage.legs or config.damage.body * Weapons.LEGS_MULTIPLIER
	end
	return config.damage.body
end

function Damage.compute(config: WeaponConfig, zone: HitZone, distance: number): number
	return Damage.base(config, zone) * Damage.falloff(config, distance)
end

return Damage
