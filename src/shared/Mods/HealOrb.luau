--!strict
-- Heal Orb (Sustain, Target; was Patch Up; vault/01 Design/Abilities/Heal
-- Orb.md): Sage's healing orb. Held: an orb of light forms in your palm. LMB
-- sends it to the ally in your crosshair (within `range`, in sight), RMB
-- presses it into your chest; with no ally in the crosshair, LMB heals you. An
-- ally gets `heal` over `duration`, you `selfHeal` (half), as server ticks
-- that keep going while they take damage. A new orb on someone already
-- healing replaces the rest of the old heal (no stacking). A target at full
-- health is refused (nothing spent).

local Target = require(script.Parent.Blocks.Target)
local Types = require(script.Parent.Types)

local HealOrb = {}

-- Extra room the server allows on the client's target (latency, aim).
local RANGE_SLACK = 3
local ANGLE_SLACK = 8

local function full(model: Model): boolean
	local h = model:FindFirstChildOfClass("Humanoid")
	return h == nil or h.Health >= h.MaxHealth
end

-- Who LMB would heal right now, as the client sees it: the ally in the
-- crosshair, else yourself.
function HealOrb.primaryTarget(
	player: Player,
	origin: Vector3,
	dir: Vector3,
	stats: Types.Stats,
	params: RaycastParams
): Model?
	local allies = HealOrb.allies(player)
	if #allies == 0 then
		return player.Character
	end
	return Target.pick(origin, dir, stats.range, stats.aimAngle, allies, params) or player.Character
end

function HealOrb.allies(player: Player): { Model }
	return Target.allies(player)
end

HealOrb.full = full

local module: Types.ModModule = {}

module.validate = function(ctx: Types.ServerCtx, req: Types.Request): (boolean, string?)
	local stats = ctx.stats
	if req.mode == "Alt" then
		req.target = ctx.character
	else
		local allies = Target.allies(ctx.player)
		if #allies == 0 or req.target == nil or req.target == ctx.character then
			-- No ally aimed at: LMB heals you. (A named ally that fails the
			-- checks below is refused, not turned into a self-heal.)
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
			-- Against the server's own camera, so the request's aim tolerance
			-- doesn't stack on top of the crosshair cone.
			if Target.angle(from, ctx.cameraLook, t) > stats.aimAngle + ANGLE_SLACK then
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
	local self = target == ctx.character
	local amount = if self then ctx.stats.selfHeal else ctx.stats.heal
	ctx.heal(target, amount, ctx.stats.duration)
	ctx.fx("Heal", {
		target = target,
		duration = ctx.stats.duration,
		amount = amount,
		self = self,
	})
end

HealOrb.module = module

return HealOrb
