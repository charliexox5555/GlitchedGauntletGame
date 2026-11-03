--!strict
-- Recon (Info, Reveal; was Ping; vault/01 Design/Abilities/Recon.md): Sova's
-- recon bolt from a compact launcher. Held ("HeldCharge"): hold LMB to charge
-- the shot (`chargeTime` to full; a tap is a short shot), release to fire;
-- RMB before firing picks 0 / 1 / 2 wall bounces (sent with the use). The
-- server computes the dart's path (Blocks/Projectile: a fast dart, a slight
-- arc, bouncing `bounces` times then sticking to the next surface). Stuck, it
-- is a 1-HP Mod object (ModEntities: any bullet destroys it) that pulses
-- `pulses` times, `pulseGap` apart (the first `pulseDelay` after sticking):
-- each pulse reveals the enemies within `radius` it can see, to the caster's
-- team only, for `reveal` seconds. The pulse itself is seen and heard by all.
--
-- Upgrades (Upgrade Paths.md → 6. Recon): A Recharge and B More Pulses are
-- numbers only (`cooldown`, `pulses`). G Ping Spike (`behaviour = "Spike"`):
-- one big pulse that reveals every enemy within `radius`, through walls; at
-- G3 (`bonusDamage`) the caster deals that much more damage to them while
-- the reveal lasts (the damage modifier in `module.server`).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Projectile = require(script.Parent.Blocks.Projectile)
local Reveal = require(script.Parent.Blocks.Reveal)
local Target = require(script.Parent.Blocks.Target)
local Types = require(script.Parent.Types)

local Recon = {}

local DART_LENGTH = 0.9 -- the stuck dart's box (studs), tip at the front
local DART_WIDTH = 0.35 -- generous: it has to be shootable

-- The dart's flight from the head: `charge` 0..1 picks the speed.
function Recon.launch(
	head: Vector3,
	aim: Vector3,
	charge: number,
	stats: Types.Stats,
	params: RaycastParams
): (Vector3, Vector3)
	local origin = Projectile.handOrigin(head, aim, stats.size, params)
	local speed = stats.minSpeed + (stats.maxSpeed - stats.minSpeed) * math.clamp(charge, 0, 1)
	return origin, Projectile.launch(aim, speed, stats.lift)
end

function Recon.options(stats: Types.Stats, bounces: number): Projectile.Options
	return {
		gravity = stats.gravity,
		size = stats.size,
		bounces = bounces, -- sticks to the surface after these
		restitution = stats.restitution,
		friction = stats.friction,
		duration = stats.maxFlight,
	}
end

-- The velocity the dart arrives with at segment `i` (where it stuck).
local function arrival(path: Projectile.Path, i: number): Vector3
	local prev = path.segments[i - 1]
	local seg = path.segments[i]
	if not prev then
		return Vector3.new(0, 0, -1)
	end
	local dt = seg.t - prev.t
	return prev.v + Vector3.new(0, -path.gravity * dt, 0)
end

local function pulse(ctx: Types.ServerCtx, dart: BasePart)
	if not dart.Parent then
		return -- shot down
	end
	local stats = ctx.stats
	local at = dart.Position
	local params = ctx.worldParams()
	local seen: { Model } = {}
	for _, model in Reveal.enemiesNear(ctx.player, at, stats.radius) do
		if Target.visible(at, model, params) then
			table.insert(seen, model)
		end
	end
	ctx.reveal(seen, stats.reveal)
	ctx.fx("ReconPulse", { at = at, radius = stats.radius })
end

-- Ping Spike's marks: marks[caster][victim] = when the bonus ends (server
-- time) and how big it is. Victims are characters (or dummies).
type Mark = { untilT: number, bonus: number }
local marks: { [Player]: { [Model]: Mark } } = {}

-- Ping Spike: every enemy in range, no line-of-sight check.
local function spike(ctx: Types.ServerCtx, dart: BasePart)
	if not dart.Parent then
		return -- shot down before it went off
	end
	local stats = ctx.stats
	local at = dart.Position
	local seen = Reveal.enemiesNear(ctx.player, at, stats.radius)
	ctx.reveal(seen, stats.reveal, "Spike")
	ctx.fx("ReconPulse", { at = at, radius = stats.radius, spike = true })
	local bonus = stats.bonusDamage
	if typeof(bonus) ~= "number" or bonus <= 0 or #seen == 0 then
		return
	end
	local now = Workspace:GetServerTimeNow()
	local mine = marks[ctx.player]
	if not mine then
		mine = {}
		marks[ctx.player] = mine
	end
	for victim, mark in mine do
		if mark.untilT <= now then
			mine[victim] = nil -- over (and maybe a body that's gone)
		end
	end
	local untilT = now + stats.reveal
	for _, victim in seen do
		mine[victim] = { untilT = untilT, bonus = bonus }
	end
end

local module: Types.ModModule = {}

module.validate = function(ctx: Types.ServerCtx, req: Types.Request): (boolean, string?)
	if req.mode ~= "Primary" then
		return false, "bad mode"
	end
	-- No more charge than the server saw the hold last (plus a little slack
	-- for the remote's travel time).
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
	local n = #path.segments
	local last = path.segments[n]
	local landT = Projectile.endTime(path)
	ctx.fx("ReconThrow", { path = Projectile.pack(path), land = landT, start = ctx.now })
	if not last.rest then
		return -- flew off: nothing to stick to
	end
	local dir = arrival(path, n)
	dir = if dir.Magnitude > 1e-3 then dir.Unit else Vector3.new(0, 0, -1)
	local tip = last.p
	ctx.schedule(landT, function()
		local dart = Instance.new("Part")
		dart.Name = "ReconDart"
		dart.Size = Vector3.new(DART_WIDTH, DART_WIDTH, DART_LENGTH)
		local center = tip - dir * (DART_LENGTH / 2)
		dart.CFrame = CFrame.lookAt(center, center + dir)
		dart.Transparency = 1
		dart.CanCollide = false
		dart.CanQuery = true -- shootable (WeaponService hits on Mod objects)
		dart.CanTouch = false
		local life = stats.pulseDelay + stats.pulseGap * (stats.pulses - 1) + 0.6
		ctx.place("ReconDart", dart, life, stats.hp, 1)
		if not dart.Parent then
			return -- the caster died before it stuck
		end
		ctx.fx("ReconStick", { at = tip, dir = dir, delay = stats.pulseDelay })
		local fire = if stats.behaviour == "Spike" then spike else pulse
		for i = 0, stats.pulses - 1 do
			ctx.schedule(stats.pulseDelay + stats.pulseGap * i, function()
				fire(ctx, dart)
			end)
		end
	end)
end

-- G3: the caster's damage (guns and Mods) to enemies their Ping Spike
-- revealed, while the reveal lasts. Marks go at round start and with the
-- caster.
module.server = function(api: Types.ServerApi)
	api.modifier(
		function(attacker: Player, victim: Model, amount: number, _sourceId: string): number
			local mine = marks[attacker]
			local mark = mine and mine[victim]
			if not mine or not mark then
				return amount
			end
			if api.now() >= mark.untilT then
				mine[victim] = nil
				if next(mine) == nil then
					marks[attacker] = nil
				end
				return amount
			end
			return amount * (1 + mark.bonus)
		end
	)
	api.onRefill(function(player: Player)
		marks[player] = nil
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		marks[player] = nil
		local character = player.Character
		if character then
			for _, mine in marks do
				mine[character] = nil
			end
		end
	end)
end

Recon.module = module

return Recon
