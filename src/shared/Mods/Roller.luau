--!strict
-- Roller (Damage, Placeable; vault/01 Design/Abilities/Roller.md). A held
-- placement: LMB sets the bot down just ahead (Blocks/Placeable, like the
-- Recall anchor) facing the aim, and it rolls off.
--
-- The server owns the bot: an anchored, shootable Mod object
-- (ModEntities, `hp`) that this module moves every Heartbeat. It rolls along
-- the floor at `speed`, climbs steps up to `stepUp`, turns back from drops
-- deeper than `dropDown`, and bounces off walls (the heading reflected off
-- the wall). Every SEEK_EVERY s it looks for the nearest enemy within
-- `lockRange` inside the `lockAngle` cone ahead with a clear line; found, it
-- locks on (attribute LockedAt) and chases at `lockSpeed`. Within `trigger`
-- studs of them (or `chase` s after the lock) it warns (WarnAt) for `warn`
-- s, then explodes: `damage` at the centre down to `edgeDamage` at `radius`,
-- line of sight, none to the caster, FRIENDLY_FIRE to their team. Nobody
-- locked by `life`: it fizzles. Shot down: it breaks, no blast.
--
-- Clients draw it from the part (Util/RollerFx: the finished model follows
-- the part smoothly; the eye lights on LockedAt and blinks on WarnAt).
--
-- Upgrades (Upgrade Paths.md → 12. Roller): More Bots (A) and Faster (B) are
-- numbers only. Remote (G, `behaviour = "Remote"`): pressing the key again
-- while it rolls (ModTrigger → module.trigger) blows it up where it is.

local StateValues = require(game:GetService("ReplicatedStorage").Shared.StateValues)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Parent.Config.Mods)
local Placeable = require(script.Parent.Blocks.Placeable)
local Target = require(script.Parent.Blocks.Target)
local Teams = require(script.Parent.Teams)
local Types = require(script.Parent.Types)

local Roller = {}

local SEEK_EVERY = 0.1 -- seconds between lock-on searches
local TURN_RATE = math.rad(540) -- radians/s the heading turns toward a locked target
local GROUND = 0.7 -- a surface this flat (normal.Y) is floor
local STOP_GAP = 1.2 -- studs (flat) from a locked target's centre where it stops

function Roller.size(stats: Types.Stats): Vector3
	return Vector3.new(stats.width, stats.height, stats.length)
end

-- Where it would be set down (the client's hologram runs the same).
function Roller.find(
	head: Vector3,
	aim: Vector3,
	stats: Types.Stats,
	params: RaycastParams,
	overlap: OverlapParams?
): Placeable.Spot
	return Placeable.find(
		head,
		aim,
		stats.placeRange,
		Roller.size(stats),
		params,
		overlap or Placeable.overlap(false)
	)
end

-- Damage at `distance` from the centre.
function Roller.damageAt(stats: Types.Stats, distance: number): number
	local u = math.clamp(distance / stats.radius, 0, 1)
	return stats.damage + (stats.edgeDamage - stats.damage) * u
end

type Bot = {
	ctx: Types.ServerCtx,
	part: BasePart,
	pos: Vector3, -- centre
	dir: Vector3, -- flat unit heading
	endsAt: number, -- os.clock(): fizzles then unless locked
	nextSeek: number,
	target: Model?,
	lockedAt: number?,
	explodeAt: number?,
	remote: boolean,
}

local bots: { Bot } = {}

local function flat(v: Vector3): Vector3
	local f = v * Vector3.new(1, 0, 1)
	return if f.Magnitude > 1e-4 then f.Unit else Vector3.zero
end

local function rootOf(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- World-only casts that don't hit the bot's own (queryable) part.
local function paramsFor(bot: Bot): RaycastParams
	local params = bot.ctx.worldParams()
	params:AddToFilter(bot.part)
	return params
end

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function explode(bot: Bot)
	local ctx = bot.ctx
	local stats = ctx.stats
	local at = bot.pos
	local params = paramsFor(bot)
	local hits = 0
	for _, model in Target.combatants() do
		if model == ctx.character or not Target.alive(model) then
			continue
		end
		local point = Target.aimPoint(model)
		if not point then
			continue
		end
		local root = rootOf(model)
		local body = if root then root.Position else point
		local distance = math.min((point - at).Magnitude, (body - at).Magnitude)
		if
			distance > stats.radius
			or not Target.visible(at + Vector3.new(0, 0.5, 0), model, params)
		then
			continue
		end
		local amount = Roller.damageAt(stats, distance)
		if Teams.isAlly(ctx.player, model) then
			amount *= Config.FRIENDLY_FIRE
		end
		ctx.damage(model, amount, point)
		hits += 1
	end
	for _, part in ctx.objectsNear(at, stats.radius) do
		if part ~= bot.part then
			ctx.damageObject(part, stats.damage)
		end
	end
	ctx.fx("RollerBoom", { at = at, radius = stats.radius, hits = hits })
	ctx.remove(bot.part, "Used")
end

-- The nearest enemy in the cone ahead with a clear line (nil: none).
local function seek(bot: Bot): Model?
	local ctx = bot.ctx
	local stats = ctx.stats
	local params = paramsFor(bot)
	local eye = bot.pos + Vector3.new(0, 0.3, 0)
	local half = math.rad(stats.lockAngle / 2)
	local best: Model? = nil
	local bestDist = math.huge
	for _, model in Target.combatants() do
		if model == ctx.character or not Target.alive(model) or Teams.isAlly(ctx.player, model) then
			continue
		end
		local root = rootOf(model)
		if not root then
			continue
		end
		local to = root.Position - bot.pos
		local dist = to.Magnitude
		if dist > stats.lockRange or dist >= bestDist then
			continue
		end
		local along = flat(to)
		if along == Vector3.zero or math.acos(math.clamp(along:Dot(bot.dir), -1, 1)) > half then
			continue
		end
		if Target.sees(eye, model, params) then -- it can't find you through smoke unless it's in it
			best, bestDist = model, dist
		end
	end
	return best
end

-- One step of rolling: walls reflect the heading, steps are climbed, drops
-- turn it back. Returns the new centre (or the old one when it turned).
local function roll(bot: Bot, dt: number, speed: number): Vector3
	local stats = bot.ctx.stats
	local params = paramsFor(bot)
	local half = stats.height / 2
	local move = speed * dt
	-- Walls: a cast along the heading from the middle of the bot.
	local ahead = workspace:Raycast(bot.pos, bot.dir * (move + stats.length / 2), params)
	if ahead and ahead.Normal.Y < GROUND then
		local n = flat(ahead.Normal)
		if n ~= Vector3.zero then
			local reflected = flat(bot.dir - 2 * bot.dir:Dot(n) * n)
			bot.dir = if reflected ~= Vector3.zero then reflected else -bot.dir
		else
			bot.dir = -bot.dir
		end
		return bot.pos
	end
	local want = bot.pos + bot.dir * move
	local floorY = bot.pos.Y - half
	local from = Vector3.new(want.X, floorY + stats.stepUp + 0.05, want.Z)
	local down =
		workspace:Raycast(from, Vector3.new(0, -(stats.stepUp + stats.dropDown + 0.1), 0), params)
	if not down or down.Normal.Y < GROUND then
		bot.dir = -bot.dir -- a ledge: back the way it came
		return bot.pos
	end
	return Vector3.new(want.X, down.Position.Y + half, want.Z)
end

local function step(dt: number)
	local clock = os.clock()
	for i = #bots, 1, -1 do
		local bot = bots[i]
		local part = bot.part
		if not part.Parent then
			table.remove(bots, i) -- shot down, expired or the caster died
			continue
		end
		local stats = bot.ctx.stats
		-- Locked: the target may have died or gone.
		local target = bot.target
		if target and (not target.Parent or not Target.alive(target)) then
			target = nil
			bot.target = nil
			if not bot.explodeAt then
				bot.lockedAt = nil
				StateValues.set(part, "LockedAt", nil)
			end
		end
		if not target and not bot.explodeAt and clock >= bot.nextSeek then
			bot.nextSeek = clock + SEEK_EVERY
			local found = seek(bot)
			if found then
				bot.target = found
				bot.lockedAt = clock
				target = found
				StateValues.set(part, "LockedAt", serverNow())
				bot.ctx.fx("RollerLock", { at = bot.pos })
			end
		end
		if target then
			local root = rootOf(target)
			if root then
				local want = flat(root.Position - bot.pos)
				if want ~= Vector3.zero then
					-- Turn toward them at TURN_RATE.
					local angle = math.acos(math.clamp(bot.dir:Dot(want), -1, 1))
					local turn = math.min(angle, TURN_RATE * dt)
					if angle > 1e-3 then
						local axis = bot.dir:Cross(want)
						local sign = if axis.Y >= 0 then 1 else -1
						bot.dir = flat(CFrame.Angles(0, sign * turn, 0):VectorToWorldSpace(bot.dir))
					end
				end
				local near = (root.Position - bot.pos).Magnitude <= stats.trigger
				local lockedAt = bot.lockedAt
				local long = lockedAt ~= nil and clock - lockedAt >= stats.chase
				if not bot.explodeAt and (near or long) then
					bot.explodeAt = clock + stats.warn
					StateValues.set(part, "WarnAt", serverNow())
				end
			end
		end
		local explodeAt = bot.explodeAt
		if explodeAt and clock >= explodeAt then
			table.remove(bots, i)
			explode(bot)
			continue
		end
		if not target and not explodeAt and clock >= bot.endsAt then
			table.remove(bots, i)
			bot.ctx.fx("RollerFizzle", { at = bot.pos })
			bot.ctx.remove(part, "Expired")
			continue
		end
		local speed = if target or explodeAt then stats.lockSpeed else stats.speed
		-- At their feet it stops and beeps (it never rolls through them).
		local root = target and rootOf(target)
		if root then
			local gap = ((root.Position - bot.pos) * Vector3.new(1, 0, 1)).Magnitude
			speed *= math.clamp((gap - STOP_GAP) / 2, 0, 1)
		end
		bot.pos = roll(bot, dt, speed)
		part.CFrame = CFrame.lookAt(bot.pos, bot.pos + bot.dir)
	end
end

local module: Types.ModModule = {}

module.validate = function(ctx: Types.ServerCtx, req: Types.Request): (boolean, string?)
	if req.mode ~= "Primary" then
		return false, "bad mode"
	end
	local spot = Roller.find(ctx.head.Position, req.direction, ctx.stats, ctx.worldParams())
	if not spot.valid then
		return false, spot.reason
	end
	req.placement = spot.cframe
	return true
end

module.apply = function(ctx: Types.ServerCtx, req: Types.Request)
	local stats = ctx.stats
	local placement = req.placement
	if not placement then
		return
	end
	local part = Instance.new("Part")
	part.Name = "Roller"
	part.Size = Roller.size(stats)
	part.CFrame = placement
	part.Transparency = 1 -- clients draw the finished model (Util/RollerFx)
	part.CanCollide = false
	part.CanQuery = true -- shootable (WeaponService hits on Mod objects)
	part.CanTouch = false
	StateValues.set(part, "Remote", stats.behaviour == "Remote" or nil)
	StateValues.set(part, "Moving", true) -- shots get the moving-object slack (Weapon/Hits)
	-- Its own end decides (fizzle / blast); this is only a backstop.
	local life = stats.life + stats.chase + stats.warn + 1
	ctx.place("Roller", part, life, stats.hp, stats.maxActive)
	if not part.Parent then
		return -- the caster died first
	end
	local dir = flat(placement.LookVector)
	table.insert(bots, {
		ctx = ctx,
		part = part,
		pos = placement.Position,
		dir = if dir ~= Vector3.zero then dir else Vector3.new(0, 0, -1),
		endsAt = os.clock() + stats.life,
		nextSeek = os.clock() + 0.15, -- not the instant it lands
		target = nil,
		lockedAt = nil,
		explodeAt = nil,
		remote = stats.behaviour == "Remote",
	})
	ctx.fx("RollerPlaced", { at = placement.Position })
end

-- Remote: blow up every Roller of `player`'s that's rolling (the newest
-- first; with maxActive 1 that's the one).
module.trigger = function(player: Player, _level: string): boolean
	local any = false
	for i = #bots, 1, -1 do
		local bot = bots[i]
		if bot.ctx.player == player and bot.remote and bot.part.Parent then
			table.remove(bots, i)
			explode(bot)
			any = true
		end
	end
	return any
end

-- Every match's kit (and the range's) calls module.server, all on the one shared `bots` list, so
-- only the oldest live connection steps it: N kits stepping it would roll N times as fast. A torn-down
-- kit's connection disconnects with its runner and drops out.
local steppers: { RBXScriptConnection } = {}

module.server = function(_api: Types.ServerApi)
	if not RunService:IsServer() then
		return
	end
	local mine: RBXScriptConnection
	mine = RunService.Heartbeat:Connect(function(dt: number)
		while steppers[1] and not steppers[1].Connected do
			table.remove(steppers, 1)
		end
		if steppers[1] == mine then
			step(dt)
		end
	end)
	for i = #steppers, 1, -1 do
		if not steppers[i].Connected then
			table.remove(steppers, i) -- kits gone since (the list stays as long as the live kits)
		end
	end
	table.insert(steppers, mine)
	Players.PlayerRemoving:Connect(function(player: Player)
		for i = #bots, 1, -1 do
			if bots[i].ctx.player == player then
				table.remove(bots, i)
			end
		end
	end)
end

Roller.module = module

return Roller
