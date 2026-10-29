--!strict
-- Status effects on a character (Config/StatusEffects): read on both sides
-- from the character's expiry attributes (server time, written only by the
-- server's StatusService), so the client predicts what the server enforces.
--
--   Status.mults(model, serverNow)   the combined multipliers right now
--   Status.until_(model, name)       when `name` ends (0 = not on)
--   Status.active(model, name, now)  whether `name` is on

local Config = require(script.Parent.Parent.Config.StatusEffects)

export type Mults = {
	move: number,
	jump: number,
	gravity: number,
	fireRate: number,
	reload: number,
	equip: number,
	recoil: number,
}

local Status = {}

local NONE: Mults = table.freeze({
	move = 1,
	jump = 1,
	gravity = 1,
	fireRate = 1,
	reload = 1,
	equip = 1,
	recoil = 1,
})
Status.NONE = NONE

function Status.until_(model: Instance?, name: string): number
	local effect = Config.effects[name]
	local v = model and effect and model:GetAttribute(effect.attribute)
	return if typeof(v) == "number" then v else 0
end

function Status.active(model: Instance?, name: string, serverNow: number): boolean
	return serverNow < Status.until_(model, name)
end

-- Every active effect's multipliers, multiplied together.
function Status.mults(model: Instance?, serverNow: number): Mults
	if not model then
		return NONE
	end
	local out: Mults? = nil
	for name, e in Config.effects do
		if serverNow < Status.until_(model, name) then
			local m = out or table.clone(NONE) :: Mults
			m.move *= e.move
			m.jump *= e.jump
			m.gravity *= e.gravity
			m.fireRate *= e.fireRate
			m.reload *= e.reload
			m.equip *= e.equip
			m.recoil *= e.recoil
			out = m
		end
	end
	return out or NONE
end

-- The most lenient multiplier for `field` the other side might be using at
-- `serverNow` (the server's checks): a slowdown that started less than
-- `grace` ago (`startedAt`, server time, kept by the server) doesn't count
-- yet; a speedup that ended less than `grace` ago still does.
function Status.lenient(
	model: Instance?,
	serverNow: number,
	grace: number,
	startedAt: { [string]: number }?,
	field: "move" | "fireRate" | "reload" | "equip"
): number
	if not model then
		return 1
	end
	local mult = 1
	for name, e in Config.effects do
		local value = (e :: any)[field] :: number
		local untilT = Status.until_(model, name)
		if value < 1 then
			local started = startedAt and startedAt[name]
			if serverNow < untilT and (not started or serverNow - started >= grace) then
				mult *= value
			end
		elseif value > 1 and serverNow - grace < untilT then
			mult *= value
		end
	end
	return mult
end

return Status
