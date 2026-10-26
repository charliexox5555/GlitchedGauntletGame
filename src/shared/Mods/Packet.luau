--!strict
-- Packet (Damage, Projectile): a grenade. Held: LMB throws, RMB lobs. The
-- server computes the whole path from its own head (Blocks/Projectile), sends
-- it to every client (ModFx "PacketThrow") and explodes it after the fuse:
-- damageCenter → damageEdge over `radius` studs, only through line of sight,
-- no self or team damage at L1. The client's arc preview uses throw() and
-- options() too, so the preview matches what the server will do.

local Projectile = require(script.Parent.Blocks.Projectile)
local Target = require(script.Parent.Blocks.Target)
local Teams = require(script.Parent.Teams)
local Types = require(script.Parent.Types)

local Packet = {}

-- Where the throw starts and its velocity (shared with Lag Field).
Packet.throw = Projectile.throw

function Packet.options(stats: Types.Stats): Projectile.Options
	return {
		gravity = stats.gravity,
		size = stats.size,
		bounces = stats.bounces,
		restitution = stats.restitution,
		friction = stats.friction,
		duration = stats.fuse,
	}
end

-- Blast damage at `distance` studs from the centre.
function Packet.damageAt(stats: Types.Stats, distance: number): number
	local t = math.clamp(distance / stats.radius, 0, 1)
	return stats.damageCenter + (stats.damageEdge - stats.damageCenter) * t
end

-- Nearest body point of a model to `at` (root, torso or head).
local function nearestPoint(model: Model, at: Vector3): Vector3?
	local best: Vector3? = nil
	local bestDist = math.huge
	for _, name in { "HumanoidRootPart", "UpperTorso", "Torso", "Head", "LowerTorso" } do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			local d = (part.Position - at).Magnitude
			if d < bestDist then
				best, bestDist = part.Position, d
			end
		end
	end
	return best
end

local function explode(ctx: Types.ServerCtx, at: Vector3)
	local stats = ctx.stats
	local caster = ctx.player
	local params = ctx.worldParams()
	for _, model in Target.combatants() do
		if not Target.alive(model) then
			continue
		end
		local isSelf = model == caster.Character
		if isSelf and not stats.selfDamage then
			continue
		end
		if not isSelf and Teams.isAlly(caster, model) and not stats.friendlyFire then
			continue
		end
		local point = nearestPoint(model, at)
		if not point then
			continue
		end
		local distance = (point - at).Magnitude
		if distance <= stats.radius and Target.visible(at, model, params) then
			ctx.damage(model, Packet.damageAt(stats, distance), point)
		end
	end
	-- Enemy Mod objects in the blast (a Packet breaks walls and pads).
	for _, part in ctx.objectsNear(at, stats.radius) do
		ctx.damageObject(part, Packet.damageAt(stats, (part.Position - at).Magnitude))
	end
	ctx.fx("PacketBoom", { at = at, radius = stats.radius })
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
	local origin, velocity = Packet.throw(ctx.head.Position, req.direction, req.mode, stats, params)
	local path = Projectile.simulate(origin, velocity, Packet.options(stats), params)
	ctx.fx("PacketThrow", {
		path = Projectile.pack(path),
		fuse = stats.fuse,
		radius = stats.radius,
		start = ctx.now,
	})
	ctx.schedule(stats.fuse, function()
		explode(ctx, Projectile.positionAt(path, stats.fuse))
	end)
end

Packet.module = module

return Packet
