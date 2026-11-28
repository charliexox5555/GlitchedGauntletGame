--!strict
-- Electric Shock (Damage, Projectile; battle pass premium tier 20; vault/01 Design/Abilities/Electric Shock.md):
-- a held throw (LMB fast and flat, RMB a lob) of an orb that flies like a canister (Mods/Molly options, its own
-- numbers). While it flies, every `scan` s the server checks the orb's place on its path: the first enemy whose
-- body is within `lockRange` with a clear line latches it ("ShockLatch": the orb stops there and a warning ring
-- shows on them for `warning` s). Then lightning strikes them wherever they are ("ShockStrike"): `damage` and
-- `hinder` s of Hinder. Nobody in reach by the time it rests: it fizzles ("ShockFizzle"). Only enemies; the strike
-- needs the target alive and in the same match (Target.combatants).
--
-- Upgrades: Recharge (A) numbers only. Chain (B, `behaviour = "Chain"`): after the strike it jumps to the nearest
-- other enemy within `chainRange` (clear line), `chains` times, `chainDamage` each. Overload (G, `behaviour =
-- "Overload"`): a wider `lockRange`; G3 also deals `splashDamage` to every other enemy within `splashRadius` of the
-- target.

local Molly = require(script.Parent.Molly)
local Projectile = require(script.Parent.Blocks.Projectile)
local Target = require(script.Parent.Blocks.Target)
local Teams = require(script.Parent.Teams)
local Types = require(script.Parent.Types)

local ElectricShock = {}

ElectricShock.throw = Projectile.throw
ElectricShock.options = Molly.options

local function enemy(ctx: Types.ServerCtx, model: Model): boolean
	return model ~= ctx.character and Target.alive(model) and not Teams.isAlly(ctx.player, model)
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
		local point = Target.aimPoint(model)
		local root = model:FindFirstChild("HumanoidRootPart")
		if not point then
			continue
		end
		-- the nearer of the chest and the feet-to-chest line, like Shock Dart's blast
		local body = if root and root:IsA("BasePart") then root.Position else point
		local d = math.min((point - at).Magnitude, (body - at).Magnitude)
		if d <= range and d < bestD and Target.visible(at, model, params) then
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
	-- Chain: hop from the last one struck to the nearest enemy not struck yet
	if stats.behaviour == "Chain" then
		local from = at
		for _ = 1, stats.chains or 0 do
			local nextModel: Model? = nil
			local nextD = math.huge
			for _, model in Target.combatants() do
				if not enemy(ctx, model) or table.find(struck, model) then
					continue
				end
				local point = Target.aimPoint(model)
				local d = if point then (point - from).Magnitude else math.huge
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
	-- Overload G3: a splash around the target
	local splash: { Vector3 } = {}
	local splashRadius = stats.splashRadius or 0
	if stats.behaviour == "Overload" and splashRadius > 0 then
		for _, model in Target.combatants() do
			if not enemy(ctx, model) or model == target then
				continue
			end
			local point = Target.aimPoint(model)
			if
				point
				and (point - at).Magnitude <= splashRadius
				and Target.visible(at, model, params)
			then
				ctx.damage(model, stats.splashDamage, point)
				table.insert(splash, point)
			end
		end
	end
	ctx.fx("ShockStrike", {
		target = target,
		at = at,
		chain = chain,
		splash = splash,
		splashRadius = if #splash > 0 or splashRadius > 0 then splashRadius else nil,
	})
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
	local start = ctx.now
	ctx.fx("ShockOrbThrow", {
		path = Projectile.pack(path),
		land = landT,
		start = start,
		lob = req.mode == "Alt",
	})
	-- the flight: one timer that walks the path at `scan` steps until something latches or it rests
	ctx.schedule(0, function()
		local t = 0
		local step = math.max(stats.scan, 0.02)
		while t < landT do
			task.wait(step)
			t = math.min(t + step, landT)
			local at = Projectile.positionAt(path, t)
			local target = latchTarget(ctx, at, stats.lockRange, ctx.worldParams())
			if target then
				ctx.fx(
					"ShockLatch",
					{ target = target, at = at, start = start, warning = stats.warning }
				)
				task.wait(stats.warning)
				strike(ctx, target)
				return
			end
		end
		ctx.fx("ShockFizzle", { at = Projectile.positionAt(path, landT), start = start })
	end)
end

ElectricShock.module = module

return ElectricShock
