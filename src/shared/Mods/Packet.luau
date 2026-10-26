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

local HAND_FORWARD = 1.5 -- studs in front of the head the throw starts
local HAND_DROP = 0.35

-- Where the throw starts and its velocity, from a head position and the aim.
-- `params` (world only) keeps the start out of a wall you're facing.
function Packet.throw(
	head: Vector3,
	aim: Vector3,
	mode: Types.UseMode,
	stats: Types.Stats,
	params: RaycastParams
): (Vector3, Vector3)
	local offset = aim * HAND_FORWARD - Vector3.new(0, HAND_DROP, 0)
	local hit = workspace:Raycast(head, offset, params)
	local origin = if hit
		then head + offset.Unit * math.max(hit.Distance - stats.size, 0)
		else head + offset
	local lob = mode == "Alt"
	local speed = if lob then stats.lobSpeed else stats.throwSpeed
	local lift = if lob then stats.lobLift else stats.throwLift
	return origin, Projectile.launch(aim, speed, lift)
end

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
		if distance <= stats.radius and Target.visible(at, model, ctx.worldParams) then
			ctx.damage(model, Packet.damageAt(stats, distance), point)
		end
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
	local origin, velocity =
		Packet.throw(ctx.head.Position, req.direction, req.mode, stats, ctx.worldParams)
	local path = Projectile.simulate(origin, velocity, Packet.options(stats), ctx.worldParams)
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
