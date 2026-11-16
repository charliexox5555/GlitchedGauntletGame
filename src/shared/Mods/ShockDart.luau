--!strict
-- Shock Dart (Damage, Projectile; vault/01 Design/Abilities/Shock Dart.md):
-- Recon's bow and flight (HeldCharge: hold LMB to charge, RMB picks 0-2 wall
-- bounces), but the bolt explodes where it lands instead of sticking. The
-- server computes the path (Recon.launch / Recon.options), and when the bolt
-- comes to rest (or its flight runs out) everyone within `radius` the impact
-- can see takes `damage` at the centre down to `edgeDamage` at the edge: none
-- to the caster, Config/Mods FRIENDLY_FIRE of it to their team.
--
-- Upgrades (Upgrade Paths.md → 10. Shock Dart): Recharge (A) and More Darts
-- (B) are numbers only. Static (G, `behaviour = "Static"`): no damage, the
-- same people are Hindered for `hinder` s (Config/StatusEffects).

local Config = require(script.Parent.Parent.Config.Mods)
local Projectile = require(script.Parent.Blocks.Projectile)
local Recon = require(script.Parent.Recon)
local Target = require(script.Parent.Blocks.Target)
local Teams = require(script.Parent.Teams)
local Types = require(script.Parent.Types)

local ShockDart = {}

-- Damage at `distance` from the centre (linear from `damage` to `edgeDamage`).
function ShockDart.damageAt(stats: Types.Stats, distance: number): number
	local u = math.clamp(distance / stats.radius, 0, 1)
	return stats.damage + (stats.edgeDamage - stats.damage) * u
end

-- The bolt's arrival direction at the last segment (for pulling the blast's
-- line-of-sight point off the surface it hit).
local function arrival(path: Projectile.Path): Vector3
	local n = #path.segments
	local prev = path.segments[n - 1]
	local seg = path.segments[n]
	if not prev then
		return seg.v
	end
	return prev.v + Vector3.new(0, -path.gravity * (seg.t - prev.t), 0)
end

local function blast(ctx: Types.ServerCtx, at: Vector3, normal: Vector3)
	local stats = ctx.stats
	local params = ctx.worldParams()
	-- The impact point sits on the surface: see from a little in front of it.
	local eye = at + normal * 0.4
	local static = stats.behaviour == "Static"
	local hits = 0
	for _, model in Target.combatants() do
		if model == ctx.character or not Target.alive(model) then
			continue
		end
		local point = Target.aimPoint(model)
		if not point then
			continue
		end
		local root = model:FindFirstChild("HumanoidRootPart")
		local body = if root and root:IsA("BasePart") then root.Position else point
		-- The nearer of the chest and the feet-to-chest line counts: a blast
		-- on the floor next to someone reaches them.
		local distance = math.min((point - at).Magnitude, (body - at).Magnitude)
		if distance > stats.radius or not Target.visible(eye, model, params) then
			continue
		end
		hits += 1
		if static then
			ctx.status(model, "Hinder", stats.hinder)
		else
			local amount = ShockDart.damageAt(stats, distance)
			if Teams.isAlly(ctx.player, model) then
				amount *= Config.FRIENDLY_FIRE
			end
			ctx.damage(model, amount, point)
		end
	end
	-- Mod objects in the blast (an enemy Recon dart, a Roller) take the
	-- centre damage (none from Static).
	if not static then
		for _, part in ctx.objectsNear(at, stats.radius) do
			ctx.damageObject(part, stats.damage)
		end
	end
	ctx.fx("ShockBurst", {
		at = at,
		normal = normal,
		radius = stats.radius,
		static = static,
		hits = hits,
	})
end

local module: Types.ModModule = {}

module.validate = function(ctx: Types.ServerCtx, req: Types.Request): (boolean, string?)
	if req.mode ~= "Primary" then
		return false, "bad mode"
	end
	-- No more charge than the server saw the hold last (Recon's rule).
	local most = (ctx.heldFor - 0.1) / ctx.stats.chargeTime + 0.25
	req.charge = math.clamp(math.min(req.charge or 1, most), 0, 1)
	req.bounces = math.clamp(math.floor(req.bounces or 0), 0, ctx.stats.maxBounces)
	return true
end

module.apply = function(ctx: Types.ServerCtx, req: Types.Request)
	local stats = ctx.stats
	local params = ctx.worldParams()
	local origin, velocity =
		Recon.launch(ctx.head.Position, req.direction, req.charge or 1, stats, params)
	local path =
		Projectile.simulate(origin, velocity, Recon.options(stats, req.bounces or 0), params)
	local landT = Projectile.endTime(path)
	local at = Projectile.positionAt(path, landT)
	ctx.fx("ShockThrow", { path = Projectile.pack(path), land = landT, start = ctx.now })
	local dir = arrival(path)
	local back = if dir.Magnitude > 1e-3 then -dir.Unit else Vector3.new(0, 1, 0)
	-- The surface it hit (the blast lies on it): a short cast back along the
	-- flight; in the air (flight ran out) the blast faces back the way it came.
	local surface = workspace:Raycast(at + back * 0.6, -back * 1.2, params)
	local normal = if surface then surface.Normal else back
	ctx.schedule(landT, function()
		blast(ctx, at, normal)
	end)
end

ShockDart.module = module

return ShockDart
