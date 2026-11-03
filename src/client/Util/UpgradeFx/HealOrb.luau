--!strict
-- HealOrb's upgrade levels on the client (vault/01 Design/Abilities/Upgrade
-- Paths.md): what the A / B / glitch levels look and sound like. A Charges
-- and B Long Heal keep the heal's own look (Util/HealFx draws each level's
-- duration and amount). G Barrier: the hex bubble, its shatter and your
-- screen's edge and pips (Util/BarrierFx).

local BarrierFx = require(script.Parent.Parent.BarrierFx)
local Types = require(script.Parent.Types)

local handler: Types.Handler = {}

handler.onFx = function(kind: string, data: { [string]: any }): boolean
	if data.id ~= "HealOrb" then
		return false
	end
	if kind == "Barrier" then
		BarrierFx.cast(data)
		return true
	elseif kind == "BarrierBlock" then
		BarrierFx.block(data)
		return true
	end
	return false
end

handler.step = function(dt: number)
	BarrierFx.step(dt)
end

return handler
