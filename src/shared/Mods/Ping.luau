--!strict
-- Ping (Info, Reveal): instant. A pulse from where you stand reveals every
-- live enemy within 30 studs through walls for 2 s. Only your team is told
-- who (ModService sends ModReveal to them alone); everyone sees and hears the
-- pulse itself (ModFx "PingPulse"), which is the counter-play.

local Reveal = require(script.Parent.Blocks.Reveal)
local Types = require(script.Parent.Types)

local Ping = {}

local module: Types.ModModule = {}

module.apply = function(ctx: Types.ServerCtx, _req: Types.Request)
	local stats = ctx.stats
	local root = ctx.character:FindFirstChild("HumanoidRootPart")
	local center = if root and root:IsA("BasePart") then root.Position else ctx.head.Position
	ctx.reveal(Reveal.enemiesNear(ctx.player, center, stats.radius), stats.duration)
	ctx.fx("PingPulse", { at = center, radius = stats.radius })
	ctx.active(stats.duration)
end

Ping.module = module

return Ping
