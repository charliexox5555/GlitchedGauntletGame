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

local Config = require(script.Parent.Parent.Config.Mods)
local Projectile = require(script.Parent.Blocks.Projectile)
local Target = require(script.Parent.Blocks.Target)
local Teams = require(script.Parent.Teams)
local Types = require(script.Parent.Types)
local Zone = require(script.Parent.Blocks.Zone)

local Molly = {}

local GROUND_SEARCH = 6 -- studs below the landing point a floor is looked for

-- Where the throw starts and its velocity (shared with Lag Field).
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
	}
end

-- The fire's centre on the floor under `at` (nil: nothing to burn on).
local function floorUnder(at: Vector3, params: RaycastParams): Vector3?
	local hit =
		workspace:Raycast(at + Vector3.new(0, 0.5, 0), Vector3.new(0, -GROUND_SEARCH, 0), params)
	return if hit then hit.Position else nil
end

-- One tick of the fire: everyone inside with a clear line from the flames.
local function burn(ctx: Types.ServerCtx, zone: Zone.Zone, amount: number, until_: number)
	local caster = ctx.player
	local params = ctx.worldParams()
	local eye = zone.center + Vector3.new(0, 1, 0)
	for _, model in Target.combatants() do
		if not Target.alive(model) then
			continue
		end
		local root = model:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") or not Zone.contains(zone, root.Position) then
			continue
		end
		if not Target.visible(eye, model, params) then
			continue
		end
		local friendly = model == caster.Character or Teams.isAlly(caster, model)
		ctx.damage(model, if friendly then amount * Config.FRIENDLY_FIRE else amount, root.Position)
		model:SetAttribute("BurningUntil", until_)
	end
end

local function ignite(ctx: Types.ServerCtx, at: Vector3)
	local stats = ctx.stats
	local center = floorUnder(at, ctx.worldParams())
	if not center then
		ctx.fx("MollyFizzle", { at = at })
		return
	end
	local fireCenter: Vector3 = center
	ctx.fx("MollyBurst", {
		at = fireCenter,
		radius = stats.radius,
		duration = stats.duration,
		start = workspace:GetServerTimeNow(),
	})
	local zone: Zone.Zone = { center = fireCenter, radius = stats.radius, height = stats.height }
	local amount = stats.dps * stats.tick
	local ticks = math.floor(stats.duration / stats.tick + 0.5)
	for i = 0, ticks - 1 do
		ctx.schedule(i * stats.tick, function()
			-- Burning shows a little past the tick, so it doesn't flicker.
			burn(ctx, zone, amount, workspace:GetServerTimeNow() + stats.tick + 0.1)
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
	ctx.schedule(landT, function()
		if last.rest then
			ignite(ctx, last.p)
		else
			ctx.fx("MollyFizzle", { at = Projectile.positionAt(path, landT) })
		end
	end)
end

Molly.module = module

return Molly
