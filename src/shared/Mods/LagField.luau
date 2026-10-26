--!strict
-- Lag Field (Control, Projectile → Zone): held, LMB throws / RMB lobs an orb
-- that opens a 10-stud zone where it first lands (or after `maxFlight`).
-- Enemies inside are slowed 40% for as long as the zone lasts (4 s): the
-- server checks who's inside every Heartbeat (ModEntities) and sets their
-- ModSpeedMult player attribute, which the movement simulation multiplies in.

local Projectile = require(script.Parent.Blocks.Projectile)
local Types = require(script.Parent.Types)

local LagField = {}

local ZONE_HEIGHT = 8

LagField.throw = Projectile.throw

function LagField.options(stats: Types.Stats): Projectile.Options
	return {
		gravity = stats.gravity,
		size = stats.size,
		bounces = 0, -- opens on the first thing it touches
		duration = stats.maxFlight,
	}
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
	local origin, velocity =
		Projectile.throw(ctx.head.Position, req.direction, req.mode, stats, params)
	local path = Projectile.simulate(origin, velocity, LagField.options(stats), params)
	local land = Projectile.endTime(path)
	ctx.fx(
		"LagThrow",
		{ path = Projectile.pack(path), land = land, start = ctx.now, radius = stats.radius }
	)
	ctx.active(land + stats.duration)
	ctx.schedule(land, function()
		local at = Projectile.positionAt(path, land)
		local opened = ctx.zone({
			center = at,
			radius = stats.radius,
			height = ZONE_HEIGHT,
			duration = stats.duration,
			slow = stats.slow,
		})
		if opened then
			ctx.fx("LagZone", { at = at, radius = stats.radius, duration = stats.duration })
		end
	end)
end

LagField.module = module

return LagField
