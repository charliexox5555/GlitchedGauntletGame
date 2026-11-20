--!strict
-- Shared round supply and reload arithmetic.

local Combat = require(script.Parent.Parent.Config.Combat)
local Types = require(script.Parent.Parent.Types)

local Ammo = {}

function Ammo.roundReserve(config: Types.WeaponConfig): number
	if config.magSize <= 0 then
		return 0
	end
	local mags = if config.class == "MachineGun"
		then Combat.AMMO.machineGunReserveMags
		else Combat.AMMO.reserveMags
	return math.max(config.magSize * mags, Combat.AMMO.minimumReserve)
end

-- nil reserve means the Studio practice range has an unlimited supply.
function Ammo.toLoad(magSize: number, loaded: number, reserve: number?): number
	local space = math.max(magSize - loaded, 0)
	return if reserve == nil then space else math.min(space, reserve)
end

function Ammo.load(
	magSize: number,
	loaded: number,
	reserve: number?,
	limit: number?
): (number, number?)
	local count = math.min(Ammo.toLoad(magSize, loaded, reserve), limit or math.huge)
	return loaded + count, if reserve ~= nil then reserve - count else nil
end

return Ammo
