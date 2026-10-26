--!strict
-- Reveal building block (Ping; later Traceroute marks, Sonar). Picks the live
-- enemies of a player around a point, through walls (that's the point). The
-- server sends the result only to the caster's team (ModService), so enemy
-- positions never reach the other side.

local Target = require(script.Parent.Target)
local Teams = require(script.Parent.Parent.Teams)

local Reveal = {}

function Reveal.enemiesNear(caster: Player, center: Vector3, radius: number): { Model }
	local out: { Model } = {}
	for _, model in Target.combatants() do
		if
			model ~= caster.Character
			and Target.alive(model)
			and not Teams.isAlly(caster, model)
		then
			local point = Target.aimPoint(model)
			if point and (point - center).Magnitude <= radius then
				table.insert(out, model)
			end
		end
	end
	return out
end

return Reveal
