--!strict
-- Electric Shock (Damage, Projectile; battle pass premium tier 20, the LEGENDARY power; vault/01 Design/Abilities/
-- Electric Shock.md; owner 2026-11-27: "a big lightning strike down, like a smite ... an OP utility, but it's fine").
-- A held throw (LMB fast and flat, RMB a lob) of an orb that flies like a canister (Mods/Molly options, its own
-- numbers). Every `scan` s the server checks the orb's place on its path: the first enemy whose body is within
-- `lockRange` with a clear line latches it. Landing without one, it sits charged for `beacon` s and latches the
-- first enemy who comes within `beaconRange`. Latched ("ShockLatch"): a marked ring follows them for `warning` s,
-- then a smite lands on them wherever they are ("ShockStrike"): `damage`, `hinder` s of Hinder, and
-- `splashDamage` to every other enemy within `splashRadius`. Nobody: it fizzles ("ShockFizzle"). Only enemies.
--
-- Upgrades: Recharge (A) numbers only. Chain Lightning (B, `behaviour = "Chain"`): the smite arcs to the nearest
-- other enemy within `chainRange` (clear line), `chains` times, `chainDamage` each. Storm Call (G, glitched,
-- `behaviour = "Storm"`): a storm cell stays over the smite and strikes `bolts` more times over `storm` s at random
-- spots within `stormRadius` of it, `boltDamage` to enemies within `boltRadius` of each ("ShockStormBolt").

local Molly = require(script.Parent.Molly)
local Projectile = require(script.Parent.Blocks.Projectile)
local Target = require(script.Parent.Blocks.Target)
local Teams = require(script.Parent.Teams)
local Types = require(script.Parent.Types)

local ElectricShock = {}

ElectricShock.throw = Projectile.throw
ElectricShock.options = Molly.options

local rng = Random.new()

local function enemy(ctx: Types.ServerCtx, model: Model): boolean
	return model ~= ctx.character and Target.alive(model) and not Teams.isAlly(ctx.player, model)
end

-- the distance from `at` to a body: the nearer of the chest and the feet-to-chest line
local function reach(model: Model, at: Vector3): (number, Vector3?)
	local point = Target.aimPoint(model)
	if not point then
		return math.huge, nil
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	local body = if root and root:IsA("BasePart") then root.Position else point
	local feet = body - Vector3.new(0, 2.5, 0)
	return math.min((point - at).Magnitude, (body - at).Magnitude, (feet - at).Magnitude), point
end

-- The enemy the orb at `at` latches onto (nearest within `range` with a clear line), or nil.
local function latchTarget(
	ctx: Types.ServerCtx,
	at: Vector3,
	range: number,
	params: RaycastParams
): Model?
	local best: Model? = nil
	local bestD = math.huge
	for _, model in Target.combatants() do
		if not enemy(ctx, model) then
			continue
		end
		local d = reach(model, at)
		-- the orb can't find someone through smoke unless it's in that smoke too (Blocks/Smoke)
		if d <= range and d < bestD and Target.sees(at, model, params) then
			best, bestD = model, d
		end
	end
	return best
end

local function hit(ctx: Types.ServerCtx, model: Model, amount: number): Vector3?
	local point = Target.aimPoint(model)
	if not point or not Target.alive(model) then
		return nil
	end
	ctx.damage(model, amount, point)
	ctx.status(model, "Hinder", ctx.stats.hinder)
	return point
end

-- Damage to every enemy (but `skip`) within `radius` of `at` with a clear line; their chest points.
local function blast(
	ctx: Types.ServerCtx,
	at: Vector3,
	radius: number,
	amount: number,
	skip: Model?
): { Vector3 }
	local out: { Vector3 } = {}
	if radius <= 0 or amount <= 0 then
		return out
	end
	local params = ctx.worldParams()
	local eye = at + Vector3.new(0, 1, 0)
	for _, model in Target.combatants() do
		if model == skip or not enemy(ctx, model) then
			continue
		end
		local d, point = reach(model, at)
		if point and d <= radius and Target.visible(eye, model, params) then
			ctx.damage(model, amount, point)
			table.insert(out, point)
		end
	end
	return out
end

-- Storm Call: more bolts around the smite (the floor point under it).
local function storm(ctx: Types.ServerCtx, at: Vector3)
	local stats = ctx.stats
	local bolts = math.max(math.floor(stats.bolts or 0), 0)
	if bolts == 0 then
		return
	end
	local params = ctx.worldParams()
	local floorHit = workspace:Raycast(at + Vector3.new(0, 2, 0), Vector3.new(0, -12, 0), params)
	local floor = if floorHit then floorHit.Position else at - Vector3.new(0, 3, 0)
	local step = stats.storm / bolts
	for i = 1, bolts do
		ctx.schedule(step * i, function()
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(1.5, stats.stormRadius)
			local spot = floor + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			local hits =
				blast(ctx, spot + Vector3.new(0, 2.5, 0), stats.boltRadius, stats.boltDamage)
			ctx.fx("ShockStormBolt", {
				at = spot,
				radius = stats.boltRadius,
				hits = hits,
				damage = stats.boltDamage,
			})
		end)
	end
end

local function strike(ctx: Types.ServerCtx, target: Model)
	local stats = ctx.stats
	local params = ctx.worldParams()
	local at = hit(ctx, target, stats.damage)
	if not at then
		ctx.fx("ShockMiss", { target = target })
		return
	end
	local struck: { Model } = { target }
	local chain: { Vector3 } = {}
	if stats.behaviour == "Chain" then
		local from = at
		for _ = 1, stats.chains or 0 do
			local nextModel: Model? = nil
			local nextD = math.huge
			for _, model in Target.combatants() do
				if not enemy(ctx, model) or table.find(struck, model) then
					continue
				end
				local d = reach(model, from)
				if d <= stats.chainRange and d < nextD and Target.visible(from, model, params) then
					nextModel, nextD = model, d
				end
			end
			if not nextModel then
				break
			end
			local point = hit(ctx, nextModel, stats.chainDamage)
			if not point then
				break
			end
			table.insert(struck, nextModel)
			table.insert(chain, point)
			from = point
		end
	end
	local splash = blast(ctx, at, stats.splashRadius or 0, stats.splashDamage or 0, target)
	-- the numbers ride along so the caster's HUD shows hit markers and damage numbers (owner 2026-11-27)
	ctx.fx("ShockStrike", {
		target = target,
		at = at,
		chain = chain,
		splash = splash,
		splashRadius = stats.splashRadius,
		storm = stats.behaviour == "Storm",
		damage = stats.damage,
		killed = not Target.alive(target),
		chainDamage = stats.chainDamage,
		splashDamage = stats.splashDamage,
	})
	if stats.behaviour == "Storm" then
		storm(ctx, at)
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
	local origin, velocity =
		ElectricShock.throw(ctx.head.Position, req.direction, req.mode, stats, params)
	local path = Projectile.simulate(origin, velocity, ElectricShock.options(stats), params)
	local landT = Projectile.endTime(path)
	local last = path.segments[#path.segments]
	local start = ctx.now
	ctx.fx("ShockOrbThrow", {
		path = Projectile.pack(path),
		land = landT,
		start = start,
		lob = req.mode == "Alt",
	})
	-- One timer walks the flight at `scan` steps, then (landed) waits as a charged beacon.
	ctx.schedule(0, function()
		local step = math.max(stats.scan, 0.02)
		local function latched(target: Model, at: Vector3): ()
			ctx.fx(
				"ShockLatch",
				{ target = target, at = at, start = start, warning = stats.warning }
			)
			task.wait(stats.warning)
			strike(ctx, target)
		end
		local t = 0
		while t < landT do
			task.wait(step)
			t = math.min(t + step, landT)
			local at = Projectile.positionAt(path, t)
			local target = latchTarget(ctx, at, stats.lockRange, ctx.worldParams())
			if target then
				latched(target, at)
				return
			end
		end
		local rest = Projectile.positionAt(path, landT)
		if last.rest and (stats.beacon or 0) > 0 then
			ctx.fx(
				"ShockBeacon",
				{ at = rest, start = start, life = stats.beacon, radius = stats.beaconRange }
			)
			local waited = 0
			while waited < stats.beacon do
				task.wait(step)
				waited += step
				local target = latchTarget(
					ctx,
					rest + Vector3.new(0, 0.5, 0),
					stats.beaconRange,
					ctx.worldParams()
				)
				if target then
					latched(target, rest)
					return
				end
			end
		end
		ctx.fx("ShockFizzle", { at = rest, start = start })
	end)
end

ElectricShock.module = module

return ElectricShock
