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

function Damage.falloff(config: WeaponConfig, distance: number): number
	local f = config.falloff
	if not f or distance <= f.start then
		return 1
	end
	if distance >= f.finish then
		return f.minMultiplier
	end
	local t = (distance - f.start) / (f.finish - f.start)
	return 1 + (f.minMultiplier - 1) * t
end

function Damage.base(config: WeaponConfig, zone: HitZone): number
	if zone == "Head" then
		return config.damage.head
	elseif zone == "Legs" then
		return config.damage.legs or config.damage.body * Weapons.LEGS_MULTIPLIER
	end
	return config.damage.body
end

function Damage.compute(config: WeaponConfig, zone: HitZone, distance: number): number
	return Damage.base(config, zone) * Damage.falloff(config, distance)
end

return Damage
