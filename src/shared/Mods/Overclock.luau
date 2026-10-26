--!strict
-- Overclock (Weapon buff, SelfBuff): instant. Your guns fire 25% faster for
-- 5 s. The server sets the FireRateMult player attribute (WeaponService), and
-- both sides divide the fire interval by it (Util/FireRate), so the client
-- fires exactly as fast as the server accepts. Everyone sees the gun glow.

local Types = require(script.Parent.Types)

local Overclock = {}

local module: Types.ModModule = {}

module.apply = function(ctx: Types.ServerCtx, _req: Types.Request)
	local stats = ctx.stats
	ctx.fireRate(stats.fireRate, stats.duration)
	ctx.fx("Overclock", { duration = stats.duration })
	ctx.active(stats.duration)
end

Overclock.module = module

return Overclock
