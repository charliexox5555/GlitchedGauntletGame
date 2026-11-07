--!strict
-- Molly (Damage, Projectile; was Packet; vault/01 Design/Abilities/Molly.md):
-- an incendiary canister. Held: LMB throws overhand (long), RMB lobs
-- underhand (short); no trajectory preview. The server computes the whole
-- path from its own head (Blocks/Projectile): it bounces off walls, bursts
-- the moment it touches the ground, and after `dropTime` in the air drops
-- straight down. Clients replay the path (ModFx "MollyThrow").
--
-- On landing a fire patch (`radius` studs, `duration` s) burns everyone
-- standing in it every `tick` seconds: `dps` to enemies, Config/Mods
-- FRIENDLY_FIRE of that to the thrower and their team; no afterburn. Only
-- through a clear line from the fire (it doesn't burn through a wall). The
-- fire's ticks are owner timers: it keeps burning if the thrower dies.
-- Burning characters get the attribute BurningUntil (server time) for the
-- client's flames and sizzle.
--
-- Upgrades (Molly.md → Upgrades): Recharge (A) and Bigger Fire (B) are
-- numbers only. Fork Fire (G, `behaviour` "Fork"): the canister makes no
-- fire of its own (G3: it hops off the floor first, `hops`). Where it comes
-- to rest it splits into `forks` bomblets, scattered by the server's own
-- RNG and simulated like the canister ("MollyFork" sends their paths); each
-- one hops (`forkHops`) and bursts into a `forkRadius` fire with the same
-- dps and duration that burns the thrower's side at `selfFire`. A body in
-- two of these fires at once still burns at one fire's rate.

local Config = require(script.Parent.Parent.Config.Mods)
local Projectile = require(script.Parent.Blocks.Projectile)
local Target = require(script.Parent.Blocks.Target)
local Teams = require(script.Parent.Teams)
local Types = require(script.Parent.Types)
local Zone = require(script.Parent.Blocks.Zone)

local Molly = {}

local GROUND_SEARCH = 6 -- studs below the landing point a floor is looked for
local SPLIT_LIFT = 0.4 -- studs above the resting canister the bomblets start

local rng = Random.new()

-- Where the throw starts and its velocity (shared with Frost).
Molly.throw = Projectile.throw

function Molly.options(stats: Types.Stats): Projectile.Options
	return {
		gravity = stats.gravity,
		size = stats.size,
		bounces = stats.bounces,
		restitution = stats.restitution,
		friction = stats.friction,
		duration = stats.maxFlight,
		groundStop = true,
		dropAfter = stats.dropTime,
		groundHops = stats.hops,
	}
end

-- A bomblet's flight (Fork Fire).
local function forkOptions(stats: Types.Stats): Projectile.Options
	return {
		gravity = stats.gravity,
		size = stats.forkSize,
		bounces = stats.forkBounces,
		restitution = stats.restitution,
		friction = stats.friction,
		duration = stats.forkFlight,
		groundStop = true,
		groundHops = stats.forkHops,
	}
end

-- The fire's centre on the floor under `at` (nil: nothing to burn on).
local function floorUnder(at: Vector3, params: RaycastParams): Vector3?
	local hit =
		workspace:Raycast(at + Vector3.new(0, 0.5, 0), Vector3.new(0, -GROUND_SEARCH, 0), params)
	return if hit then hit.Position else nil
end

-- One fire: its size, the share its thrower's side takes, and (Fork Fire)
-- when each body was last burnt by any fire of the same throw.
type Fire = {
	radius: number,
	friendly: number,
	lastHit: { [Model]: number }?,
}

-- One tick of the fire: everyone inside with a clear line from the flames.
local function burn(ctx: Types.ServerCtx, zone: Zone.Zone, fire: Fire, until_: number)
	local stats = ctx.stats
	local caster = ctx.player
	local params = ctx.worldParams()
	local eye = zone.center + Vector3.new(0, 1, 0)
	local amount = stats.dps * stats.tick
	local lastHit = fire.lastHit
	local now = os.clock()
	for _, model in Target.combatants() do
		if not Target.alive(model) then
			continue
		end
		local root = model:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") or not Zone.contains(zone, root.Position) then
			continue
		end
		-- Already burnt this tick by a sibling fire (overlapping forks).
		if lastHit then
			local at = lastHit[model]
			if at and now - at < stats.tick * 0.9 then
				continue
			end
		end
		if not Target.visible(eye, model, params) then
			continue
		end
		if lastHit then
			lastHit[model] = now
		end
		local friendly = model == Teams.characterOf(caster) or Teams.isAlly(caster, model)
		ctx.damage(model, if friendly then amount * fire.friendly else amount, root.Position)
		model:SetAttribute("BurningUntil", until_)
	end
end

-- Lights `fire` on the floor under `at` (a fizzle when there's none).
local function ignite(ctx: Types.ServerCtx, at: Vector3, fire: Fire, extra: { [string]: any }?)
	local stats = ctx.stats
	local center = floorUnder(at, ctx.worldParams())
	if not center then
		ctx.fx("MollyFizzle", { at = at, fork = if extra then extra.fork else nil })
		return
	end
	local fireCenter: Vector3 = center
	local data: { [string]: any } = {
		at = fireCenter,
		radius = fire.radius,
		duration = stats.duration,
		start = workspace:GetServerTimeNow(),
	}
	if extra then
		for k, v in extra do
			data[k] = v
		end
	end
	ctx.fx("MollyBurst", data)
	local zone: Zone.Zone = { center = fireCenter, radius = fire.radius, height = stats.height }
	local ticks = math.floor(stats.duration / stats.tick + 0.5)
	for i = 0, ticks - 1 do
		ctx.schedule(i * stats.tick, function()
			-- Burning shows a little past the tick, so it doesn't flicker.
			burn(ctx, zone, fire, workspace:GetServerTimeNow() + stats.tick + 0.1)
		end)
	end
end

-- Fork Fire: the scatter velocities, one per bomblet. Evenly spread around
-- a random start angle, each jittered, so they never all go one way.
local function scatter(stats: Types.Stats): { Vector3 }
	local n = stats.forks
	local out = {}
	local base = rng:NextNumber(0, math.pi * 2)
	local share = math.pi * 2 / n
	for i = 1, n do
		local a = base + (i - 1) * share + rng:NextNumber(-0.35, 0.35) * share
		local lift = stats.forkLift + rng:NextNumber(-1, 1) * stats.forkLiftJitter
		local speed = stats.forkSpeed * (1 + rng:NextNumber(-1, 1) * stats.forkSpeedJitter)
		local dir = Vector3.new(math.cos(a), math.max(lift, 0.1), math.sin(a))
		table.insert(out, dir.Unit * speed)
	end
	return out
end

-- Fork Fire: the canister at rest at `at` splits; every bomblet bursts
-- where it comes to rest.
local function fork(ctx: Types.ServerCtx, at: Vector3)
	local stats = ctx.stats
	local params = ctx.worldParams()
	local origin = at + Vector3.new(0, SPLIT_LIFT, 0)
	local options = forkOptions(stats)
	local fire: Fire = { radius = stats.forkRadius, friendly = stats.selfFire, lastHit = {} }
	local packed = {}
	local paths: { Projectile.Path } = {}
	for _, velocity in scatter(stats) do
		local path = Projectile.simulate(origin, velocity, options, params)
		table.insert(paths, path)
		table.insert(packed, Projectile.pack(path))
	end
	ctx.fx("MollyFork", { at = at, paths = packed, start = workspace:GetServerTimeNow() })
	for i, path in paths do
		local last = path.segments[#path.segments]
		local landT = Projectile.endTime(path)
		ctx.schedule(landT, function()
			if last.rest then
				ignite(ctx, last.p, fire, { fork = i })
			else
				ctx.fx("MollyFizzle", { at = Projectile.positionAt(path, landT), fork = i })
			end
		end)
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
	local origin, velocity = Molly.throw(ctx.head.Position, req.direction, req.mode, stats, params)
	local path = Projectile.simulate(origin, velocity, Molly.options(stats), params)
	local last = path.segments[#path.segments]
	local landT = Projectile.endTime(path)
	ctx.fx("MollyThrow", {
		path = Projectile.pack(path),
		land = landT,
		start = ctx.now,
		lob = req.mode == "Alt",
	})
	local forking = stats.behaviour == "Fork"
	ctx.schedule(landT, function()
		if not last.rest then
			ctx.fx("MollyFizzle", { at = Projectile.positionAt(path, landT) })
		elseif forking then
			fork(ctx, last.p)
		else
			ignite(ctx, last.p, { radius = stats.radius, friendly = Config.FRIENDLY_FIRE })
		end
	end)
end

Molly.module = module

return Molly
