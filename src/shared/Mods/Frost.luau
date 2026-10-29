--!strict
-- Frost (Control, Projectile; was Lag Field; vault/01 Design/Abilities/
-- Frost.md): Waylay's Saturate. A held throw like the Molly: LMB a flatter,
-- faster javelin throw, RMB an underhand lob, no preview. The same flight
-- (Mods/Molly options: walls bounce it, the first floor it touches bursts
-- it, it drops after `dropTime` in the air). The burst Hinders everyone
-- within `radius` with a clear line from it (enemies, your team and you, the
-- same) for `hinder` seconds: Config/StatusEffects Hinder, applied by the
-- server's StatusService (a new hit refreshes it). No damage.

local Molly = require(script.Parent.Molly)
local Projectile = require(script.Parent.Blocks.Projectile)
local Target = require(script.Parent.Blocks.Target)
local Types = require(script.Parent.Types)

local Frost = {}

Frost.throw = Projectile.throw
Frost.options = Molly.options -- the same flight, its own numbers

local function burst(ctx: Types.ServerCtx, at: Vector3)
	local stats = ctx.stats
	local params = ctx.worldParams()
	local eye = at + Vector3.new(0, 0.5, 0)
	for _, model in Target.combatants() do
		if not Target.alive(model) then
			continue
		end
		local point = Target.aimPoint(model)
		if
			point
			and (point - at).Magnitude <= stats.radius
			and Target.visible(eye, model, params)
		then
			ctx.status(model, "Hinder", stats.hinder)
		end
	end
	ctx.fx("FrostBurst", { at = at, radius = stats.radius })
end

local module: Types.ModModule = {}

module.validate = function(_ctx: Types.ServerCtx, req: Types.Request): (boolean, string?)
	if req.mode ~= "Primary" and req.mode ~= "Alt" then
		return false, "bad mode"
	end
	return true
end

module.apply = function(ctx: Types.ServerCtx, req: Types.Request)
	local stats = ctx.stats
	local params = ctx.worldParams()
	local origin, velocity = Frost.throw(ctx.head.Position, req.direction, req.mode, stats, params)
	local path = Projectile.simulate(origin, velocity, Frost.options(stats), params)
	local last = path.segments[#path.segments]
	local landT = Projectile.endTime(path)
	ctx.fx("FrostThrow", {
		path = Projectile.pack(path),
		land = landT,
		start = ctx.now,
		lob = req.mode == "Alt",
	})
	ctx.schedule(landT, function()
		-- It only bursts on the ground (still flying at the end: nothing).
		if last.rest then
			burst(ctx, last.p)
		else
			ctx.fx("FrostFizzle", { at = Projectile.positionAt(path, landT) })
		end
	end)
end

Frost.module = module

return Frost
