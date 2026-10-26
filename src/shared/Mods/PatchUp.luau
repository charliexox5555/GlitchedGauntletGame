--!strict
-- Patch Up (Sustain, Target + SelfBuff): Sage-style heal. Held: LMB heals the
-- ally in your crosshair (within `range`, in sight), RMB heals you. With no
-- live allies (1v1), LMB heals you too. 40 HP over 2 s as server ticks; you go
-- back to the gun right after, so you can move and shoot while it heals.
-- A target already at full health is refused (no cooldown spent).

local Target = require(script.Parent.Blocks.Target)
local Types = require(script.Parent.Types)

local PatchUp = {}

-- Extra room the server allows on the client's target (latency, aim).
local RANGE_SLACK = 3
local ANGLE_SLACK = 8

local function full(model: Model): boolean
	local h = model:FindFirstChildOfClass("Humanoid")
	return h == nil or h.Health >= h.MaxHealth
end

-- Who LMB would heal right now, as the client sees it: the ally in the
-- crosshair, yourself when you have no allies, or nil (allies, none aimed at).
function PatchUp.primaryTarget(
	player: Player,
	origin: Vector3,
	dir: Vector3,
	stats: Types.Stats,
	params: RaycastParams
): Model?
	local allies = PatchUp.allies(player)
	if #allies == 0 then
		return player.Character
	end
	return Target.pick(origin, dir, stats.range, stats.aimAngle, allies, params)
end

function PatchUp.allies(player: Player): { Model }
	return Target.allies(player)
end

PatchUp.full = full

local module: Types.ModModule = {}

module.validate = function(ctx: Types.ServerCtx, req: Types.Request): (boolean, string?)
	local stats = ctx.stats
	if req.mode == "Alt" then
		req.target = ctx.character
	else
		local allies = Target.allies(ctx.player)
		if #allies == 0 then
			req.target = ctx.character
		else
			local t = req.target
			if not t or not table.find(allies, t) then
				return false, "no ally targeted"
			end
			local from = ctx.head.Position
			local point = Target.aimPoint(t)
			if not point or (point - from).Magnitude > stats.range + RANGE_SLACK then
				return false, "out of range"
			end
			if Target.angle(from, req.direction, t) > stats.aimAngle + ANGLE_SLACK then
				return false, "not in the crosshair"
			end
			if not Target.visible(from, t, ctx.worldParams()) then
				return false, "no line of sight"
			end
		end
	end
	local target = req.target :: Model
	if full(target) then
		return false, "full health"
	end
	return true
end

module.apply = function(ctx: Types.ServerCtx, req: Types.Request)
	local target = req.target :: Model
	ctx.heal(target, ctx.stats.heal, ctx.stats.duration)
	ctx.fx("Heal", {
		target = target,
		duration = ctx.stats.duration,
		amount = ctx.stats.heal,
	})
end

PatchUp.module = module

return PatchUp
