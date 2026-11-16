--!strict
-- Flash (Control, Projectile; vault/01 Design/Abilities/Flash.md). A held
-- throw: LMB throws it (it pops `fuse` s after leaving the hand, in the air
-- or wherever it rolled to), RMB tosses it a step ahead and it pops after
-- `quickFuse` s (round a corner). The flight is the shared Projectile path
-- (walls bounce it).
--
-- The pop: the server decides who is blinded. For every live combatant
-- within `range` with a clear line from the pop to their head (through up
-- to `walls` walls), the angle between where they look (ctx.lookOf: the
-- server's camera copy, else body yaw and AimPitch) and the pop sets the
-- time: `blindMax` straight on, falling to `blindSide` at `sideAngle`, held
-- to `maxAngle`, none past it. Enemies, teammates and the thrower alike.
--
-- Upgrades (Upgrade Paths.md → 11. Flash): More Flashes (A) and Recharge (B)
-- are numbers only. Exposure (G, `behaviour = "Exposure"`): no blind; every
-- enemy who would have been blinded is revealed to the thrower's team for
-- `reveal` s (Recon's reveal path: outline for them, DETECTED for the
-- victim). G3 reaches through one wall (`walls`).

local Projectile = require(script.Parent.Blocks.Projectile)
local Target = require(script.Parent.Blocks.Target)
local Teams = require(script.Parent.Teams)
local Types = require(script.Parent.Types)

local Flash = {}

Flash.throw = Projectile.throw -- (bots aim with the Mod's own flight)

local WALL_DEPTH = 6 -- studs: the thickest wall a "through one wall" flash crosses

function Flash.options(stats: Types.Stats, quick: boolean): Projectile.Options
	return {
		gravity = stats.gravity,
		size = stats.size,
		bounces = stats.bounces,
		restitution = stats.restitution,
		friction = stats.friction,
		duration = if quick then stats.quickFuse else stats.fuse,
	}
end

-- Seconds of blind (and strength 0..1) for a viewer at `head` looking
-- along `look` when the flash pops at `at`: on their screen, blindMax in the
-- middle down to blindEdge at the edge; off screen but within glanceAngle, a
-- short glance; behind them, nothing.
function Flash.blindFor(
	stats: Types.Stats,
	head: Vector3,
	look: Vector3,
	at: Vector3
): (number, number)
	local to = at - head
	if to.Magnitude < 1e-3 or look.Magnitude < 1e-3 then
		return stats.blindMax, 1
	end
	local f = look.Unit
	local side = f:Cross(Vector3.yAxis)
	side = if side.Magnitude > 1e-3 then side.Unit else Vector3.xAxis
	local up = side:Cross(f)
	local z = to:Dot(f)
	local angle = math.deg(math.acos(math.clamp(to.Unit:Dot(f), -1, 1)))
	if z > 0 then
		local ax = math.deg(math.atan2(math.abs(to:Dot(side)), z))
		local ay = math.deg(math.atan2(math.abs(to:Dot(up)), z))
		local edge = math.max(ax / stats.screenX, ay / stats.screenY)
		if edge <= 1 then
			local seconds = stats.blindMax + (stats.blindEdge - stats.blindMax) * edge
			return seconds, seconds / stats.blindMax
		end
	end
	if angle <= stats.glanceAngle then
		return stats.glance, stats.glance / stats.blindMax
	end
	return 0, 0
end

-- A line from `from` to `to` that crosses at most `walls` world surfaces.
function Flash.reaches(from: Vector3, to: Vector3, params: RaycastParams, walls: number): boolean
	local at = from
	for _ = 0, walls do
		local delta = to - at
		if delta.Magnitude < 1e-3 then
			return true
		end
		local hit = workspace:Raycast(at, delta, params)
		if not hit then
			return true
		end
		-- Through this wall: find where the line comes out (a cast back from
		-- up to WALL_DEPTH past the entry finds the far face; a thicker wall
		-- blocks), and go on from there.
		local dir = delta.Unit
		local reach = math.min(WALL_DEPTH, (to - hit.Position).Magnitude)
		local probe = hit.Position + dir * reach
		local back = workspace:Raycast(probe, hit.Position - probe, params)
		if not back then
			if reach < WALL_DEPTH then
				return true -- the target is inside the wall's far side: through
			end
			return false -- thicker than a wall
		end
		at = back.Position + dir * 0.05
	end
	return false
end

local function headOf(model: Model): Vector3?
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.Position
	end
	return Target.aimPoint(model)
end

local function pop(ctx: Types.ServerCtx, at: Vector3)
	local stats = ctx.stats
	local params = ctx.worldParams()
	local exposure = stats.behaviour == "Exposure"
	local revealed: { Model } = {}
	local blinded = 0
	for _, model in Target.combatants() do
		if not Target.alive(model) then
			continue
		end
		local head = headOf(model)
		if not head or (head - at).Magnitude > stats.range then
			continue
		end
		if not Flash.reaches(at, head, params, stats.walls or 0) then
			continue
		end
		local seconds, strength = Flash.blindFor(stats, head, ctx.lookOf(model), at)
		if seconds <= 0 then
			continue
		end
		if exposure then
			local own = model == ctx.character or Teams.isAlly(ctx.player, model)
			if not own then
				table.insert(revealed, model)
			end
		else
			ctx.blind(model, seconds, strength, at)
			blinded += 1
		end
	end
	if exposure and #revealed > 0 then
		ctx.reveal(revealed, stats.reveal, "Exposure")
	end
	ctx.fx("FlashPop", {
		at = at,
		range = stats.range,
		exposure = exposure,
		hits = if exposure then #revealed else blinded,
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
	local quick = req.mode == "Alt"
	local origin, velocity =
		Projectile.throw(ctx.head.Position, req.direction, req.mode, stats, params)
	local path = Projectile.simulate(origin, velocity, Flash.options(stats, quick), params)
	local fuse: number = if quick then stats.quickFuse else stats.fuse
	local at = Projectile.positionAt(path, fuse)
	ctx.fx("FlashThrow", {
		path = Projectile.pack(path),
		land = fuse,
		start = ctx.now,
		lob = quick,
	})
	ctx.schedule(fuse, function()
		pop(ctx, at)
	end)
end

Flash.module = module

return Flash
