--!strict
-- Smoke (Control, Projectile; battle pass free tier 10; vault/01 Design/Abilities/Smoke.md): a held throw like
-- the Molly (LMB overhand, RMB underhand lob; the same flight, Mods/Molly options). Where the canister comes to
-- rest it pops `popDelay` s later into a dome (Mods/Blocks/Smoke) of `radius` for `duration` s that blocks sight
-- both ways for players, bots, aim assist and auto shoot. Bullets pass through. Still flying when its flight runs
-- out: it fizzles. Clients replay the throw ("SmokeThrow") and dress the dome ("SmokePop", Util/SmokeFx).
--
-- Upgrades: Recharge (A) and Big Smoke (B) are numbers only. Toxic (G, `behaviour = "Toxic"`): every `tick` the
-- enemies inside are Hindered for `hinder` s; G3 also burns them `dps` (none to the thrower's side).

local Molly = require(script.Parent.Molly)
local Projectile = require(script.Parent.Blocks.Projectile)
local SmokeBlock = require(script.Parent.Blocks.Smoke)
local Target = require(script.Parent.Blocks.Target)
local Teams = require(script.Parent.Teams)
local Types = require(script.Parent.Types)

local Smoke = {}

Smoke.throw = Projectile.throw
Smoke.options = Molly.options -- the same flight, its own numbers

-- Toxic: one check of who stands in the smoke.
local function poison(ctx: Types.ServerCtx, center: Vector3, radius: number)
	local stats = ctx.stats
	for _, model in Target.combatants() do
		if not Target.alive(model) or model == ctx.character or Teams.isAlly(ctx.player, model) then
			continue
		end
		local point = Target.aimPoint(model)
		if point and (point - center).Magnitude <= radius then
			ctx.status(model, "Hinder", stats.hinder)
			local dps = stats.dps or 0
			if dps > 0 then
				ctx.damage(model, dps * stats.tick, point)
			end
		end
	end
end

local function pop(ctx: Types.ServerCtx, at: Vector3)
	local stats = ctx.stats
	local team = Teams.of(ctx.player)
	local part = SmokeBlock.spawn(
		at,
		stats.radius,
		stats.duration,
		stats.grow,
		stats.fade,
		team,
		if ctx.player:IsA("Player") then ctx.player.UserId else 0 -- a bot's character owns its things
	)
	ctx.fx("SmokePop", {
		at = at,
		radius = stats.radius,
		duration = stats.duration,
		grow = stats.grow,
		fade = stats.fade,
		start = workspace:GetServerTimeNow(),
		toxic = stats.behaviour == "Toxic",
	})
	ctx.active(stats.duration)
	if stats.behaviour == "Toxic" then
		local ticks = math.floor((stats.duration - stats.fade) / stats.tick)
		for i = 1, ticks do
			ctx.schedule(i * stats.tick, function()
				if part.Parent then
					poison(ctx, at, SmokeBlock.radiusAt(part, workspace:GetServerTimeNow()))
				end
			end)
		end
	end
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
	local origin, velocity = Smoke.throw(ctx.head.Position, req.direction, req.mode, stats, params)
	local path = Projectile.simulate(origin, velocity, Smoke.options(stats), params)
	local last = path.segments[#path.segments]
	local landT = Projectile.endTime(path)
	ctx.fx("SmokeThrow", {
		path = Projectile.pack(path),
		land = landT,
		start = ctx.now,
		lob = req.mode == "Alt",
	})
	ctx.schedule(landT + stats.popDelay, function()
		if last.rest then
			pop(ctx, last.p)
		else
			ctx.fx("SmokeFizzle", { at = Projectile.positionAt(path, landT) })
		end
	end)
end

Smoke.module = module

return Smoke
