--!strict
-- A bot's decisions (vault/01 Design/Bots.md → Brain). `think` runs at
-- Config/Bots THINK_RATE: perceive, pick a target, score the goals
-- (utility, with hysteresis) and plan the movement. `act` runs every frame
-- and is cheap: the aim spring, steering, the inputs the shared simulations
-- read (Sprint, Crouch, Aim, Fire, AimPitch) and the trigger.

local Globals =
	game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)

local BotsConfig = require(ReplicatedStorage.Shared.Config.Bots)
local Health = require(ReplicatedStorage.Shared.Health)
local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Juice = require(ReplicatedStorage.Shared.Config.Juice)
local Zone = require(script.Parent.Parent.Zone)
local RunService = game:GetService("RunService")

local STUDIO = RunService:IsStudio()

local Aim = require(script.Parent.Aim)
local BotGun = require(script.Parent.BotGun)
local BotMods = require(script.Parent.BotMods)
local BotTypes = require(script.Parent.Types)
local Nav = require(script.Parent.Nav)
local Perception = require(script.Parent.Perception)
local Spectated = require(Globals.Parent.Bots.Spectated)
local LookStream = require(Globals.LookStream)
local Tactics = require(script.Parent.Tactics)

type Bot = BotTypes.Bot

export type World = {
	enemies: { Model },
	allies: { Model }, -- teammates' characters (not this bot)
	focus: { [Model]: number }, -- how many teammates target each enemy
	roam: Vector3?, -- where to go first with no information (the enemy side)
	patrol: { Vector3 }, -- then from point to point over the map (spawns, middle, flanks)
	zone: Zone.State?,
}

local Brain = {}

-- Hits each target took from bots in the current second (LihFolk AI
-- Difficulty Tuning: a hit budget, so three bots can't shred one player).
type HitWindow = { start: number, count: number }
local hitWindows: { [Model]: HitWindow } = setmetatable({}, { __mode = "k" }) :: any

local function overBudget(model: Model, max: number, now: number): boolean
	local w = hitWindows[model]
	return w ~= nil and now - w.start < 1 and w.count >= max
end

local function recordHit(model: Model, now: number)
	local w = hitWindows[model]
	if not w or now - w.start >= 1 then
		hitWindows[model] = { start = now, count = 1 }
	else
		w.count += 1
	end
end

local rng = Random.new()

-- What each bot last published about its aim (like a player's Aim remote:
-- on a fixed schedule, only on a real change). `pitchNext` / `gunNext` are
-- the next send slots (a schedule, not a last-sent time, so 30 Hz is 30 Hz
-- and doesn't snap to every third frame).
type AimSent = {
	pitchNext: number,
	pitch: number,
	aiming: boolean,
	gun: boolean, -- AimGunYaw / AimGunPitch are set
	gunNext: number,
	gunYaw: number,
	gunPitch: number,
	lookNext: number, -- the next look stream slot (Services/LookStream)
}
local aimSent: { [Bot]: AimSent } = setmetatable({}, { __mode = "k" }) :: any
local SPECTATE = Juice.SPECTATE

local function wrapAngle(a: number): number
	return (a + math.pi) % (2 * math.pi) - math.pi
end

-- The slot after a send at `now`: on schedule it keeps the cadence, after a
-- quiet spell it starts again one interval from now.
local function nextSlot(slot: number, now: number, interval: number): number
	return if now - slot < interval then slot + interval else now + interval
end

-- On the bot's owner (mirrored onto its model):
-- - `AimPitch` (radians) and `Aiming`, always: its intended pitch. That's
--   gameplay input too (Target.lookOf: bot Mods' aim, Flash's blind check),
--   so it stays the clean aim, at Juice SPECTATE botPitchSendHz.
-- - `AimGunYaw` / `AimGunPitch` (radians), only while someone spectates it
--   (Bots/Spectated): where the gun points (Aim.direction: the spring plus
--   aim error and recoil), so the watched crosshair kicks with each shot and
--   sits where the tracers go; a fair miss's sideways push stays out (it
--   would make the view jump). Cleared when the last viewer leaves, so no
--   one reads a stale look.
local function publishAim(bot: Bot, aiming: boolean, now: number)
	local sent = aimSent[bot]
	if not sent then
		sent = {
			pitchNext = -math.huge,
			pitch = math.huge,
			aiming = false,
			gun = false,
			gunNext = -math.huge,
			gunYaw = math.huge,
			gunPitch = math.huge,
			lookNext = -math.huge,
		}
		aimSent[bot] = sent
	end
	local owner = bot.owner
	local model = bot.model
	-- The look stream (spectators and the final-kill replay): where the gun
	-- points, on the server's clock, at Juice SPECTATE lookHz, always (the
	-- replay may need it later); relayed only to whoever watches this bot.
	if model ~= nil and now >= sent.lookNext then
		sent.lookNext = nextSlot(sent.lookNext, now, 1 / SPECTATE.lookHz)
		LookStream.push(
			model,
			workspace:GetServerTimeNow(),
			wrapAngle(bot.yaw + math.rad(bot.aimError.X + bot.recoil.X)),
			math.clamp(bot.pitch + math.rad(bot.aimError.Y + bot.recoil.Y), -1.4, 1.4)
		)
	end
	if model ~= nil and Spectated.has(model) then
		if now >= sent.gunNext then
			local yaw = wrapAngle(bot.yaw + math.rad(bot.aimError.X + bot.recoil.X))
			local pitch = math.clamp(bot.pitch + math.rad(bot.aimError.Y + bot.recoil.Y), -1.4, 1.4)
			local deadband = SPECTATE.botAimDeadband
			if
				not sent.gun
				or math.abs(pitch - sent.gunPitch) > deadband
				or math.abs(wrapAngle(yaw - sent.gunYaw)) > deadband
				or aiming ~= sent.aiming
			then
				sent.gunNext = nextSlot(sent.gunNext, now, 1 / SPECTATE.botAimSendHz)
				sent.gun, sent.gunYaw, sent.gunPitch = true, yaw, pitch
				StateValues.set(owner, "AimGunYaw", yaw)
				StateValues.set(owner, "AimGunPitch", pitch)
				if aiming ~= sent.aiming then
					sent.aiming = aiming
					StateValues.set(owner, "Aiming", aiming)
				end
			end
		end
	elseif sent.gun then
		sent.gun, sent.gunYaw, sent.gunPitch = false, math.huge, math.huge
		StateValues.set(owner, "AimGunYaw", nil)
		StateValues.set(owner, "AimGunPitch", nil)
	end
	if now >= sent.pitchNext then
		if
			math.abs(bot.pitch - sent.pitch) > SPECTATE.botPitchDeadband
			or aiming ~= sent.aiming
		then
			sent.pitchNext = nextSlot(sent.pitchNext, now, 1 / SPECTATE.botPitchSendHz)
			sent.pitch, sent.aiming = bot.pitch, aiming
			StateValues.set(owner, "AimPitch", bot.pitch)
			StateValues.set(owner, "Aiming", aiming)
		end
	end
end

local function setInput(bot: Bot, name: string, value: any)
	local action = bot.inputs[name]
	if action and action:GetState() ~= value then
		action:Fire(value)
	end
end

-- Health plus shield as a share of full health.
function Brain.healthShare(bot: Bot): number
	local humanoid = bot.humanoid
	if not humanoid then
		return 0
	end
	local shield = StateValues.get(humanoid, Combat.SHIELD_ATTRIBUTE)
	local extra = if typeof(shield) == "number" then shield else 0
	return (Health.get(humanoid) + extra) / math.max(Health.max(humanoid), 1)
end

local function rangeBand(bot: Bot): (number, number)
	local config = BotGun.config(bot.gun)
	local band = BotsConfig.RANGE[if config then config.class else "Rifle"]
		or BotsConfig.RANGE.Rifle
	return band[1], band[2]
end

local function setGoal(bot: Bot, goal: string, now: number)
	if bot.goal ~= goal then
		bot.goal = goal
		bot.goalSince = now
	end
end

-- Weapon upkeep: swap to the sidearm when dry in a fight, reload when safe,
-- back to the primary after.
local function manageGun(bot: Bot, inFight: boolean)
	local model = bot.model
	if not model then
		return
	end
	local gun = bot.gun
	local slot = gun.equipped
	local current = BotGun.current(gun)
	if not current then
		BotGun.equip(gun, model, bot.owner, if gun.slots.Primary then "Primary" else "Secondary")
		return
	end
	local empty = current.config.magSize > 0 and current.ammo < 1
	if empty and not current.reloadEnd then
		local otherSlot = if slot == "Primary" then "Secondary" else "Primary"
		local other = gun.slots[otherSlot]
		if
			other
			and (
				other.ammo > 0 and inFight
				or current.reserve == 0 and other.ammo + other.reserve > 0
			)
		then
			BotGun.equip(gun, model, bot.owner, otherSlot)
		elseif current.reserve == 0 then
			BotGun.equip(gun, model, bot.owner, "Melee")
		else
			BotGun.reload(gun, model, bot.owner)
		end
		return
	end
	if not inFight then
		local primary = gun.slots.Primary
		if slot ~= "Primary" and primary and primary.ammo + primary.reserve > 0 then
			BotGun.equip(gun, model, bot.owner, "Primary")
		elseif BotGun.ammoShare(gun) < 0.6 then
			BotGun.reload(gun, model, bot.owner)
		end
	end
end

-- Teammates closer than TEAM_SPACING push this bot away (no clumping).
local function spacing(bot: Bot, allies: { Model }): Vector3
	local root = bot.root
	if not root then
		return Vector3.zero
	end
	local push = Vector3.zero
	for _, ally in allies do
		local other = ally:FindFirstChild("HumanoidRootPart")
		if other and other:IsA("BasePart") then
			local away = (root.Position - other.Position) * Vector3.new(1, 0, 1)
			local d = away.Magnitude
			if d > 0.1 and d < BotsConfig.TEAM_SPACING then
				push += away.Unit * (1 - d / BotsConfig.TEAM_SPACING)
			end
		end
	end
	return push
end

local function newStrafe(bot: Bot, now: number)
	local pause = rng:NextNumber() < bot.profile.movement.strafePause
	bot.strafeDir = if pause
		then 0
		elseif rng:NextNumber() < 0.25 or bot.strafeDir == 0 then (if rng:NextNumber()
				< 0.5
			then -1
			else 1)
		else -bot.strafeDir
	bot.strafeUntil = now
		+ BotsConfig.STRAFE_MIN
		+ rng:NextNumber() * (BotsConfig.STRAFE_MAX - BotsConfig.STRAFE_MIN)
end

-- Decisions, THINK_RATE times a second.
function Brain.think(bot: Bot, world: World, now: number)
	local root = bot.root
	local model = bot.model
	if not root or not model or not bot.fighting then
		return
	end
	Perception.update(bot, world.enemies, now)
	local previous = bot.target
	local low, high = rangeBand(bot)
	local weapon = BotGun.config(bot.gun)
	bot.target =
		Perception.pickTarget(bot, now, world.focus, high, if weapon then weapon.range else high)
	local switched = bot.target ~= nil and bot.target ~= previous
	if switched then
		Aim.acquire(bot)
		bot.missLeft = bot.profile.aim.firstMisses
		bot.triggerAt = now
			+ rng:NextNumber(BotsConfig.TRIGGER_DELAY[1], BotsConfig.TRIGGER_DELAY[2])
	end
	local target = bot.target
	local hp = Brain.healthShare(bot)
	local style = bot.openingStyle
	local aggression = math.clamp(
		bot.profile.tactics.aggression
			+ (if style == "Flanker" then 0.08 elseif style == "Holder" then -0.13 else 0),
		0,
		1
	)
	local glimpse = if target then nil else Perception.glimpse(bot, now)
	local known = if target then nil else glimpse or Perception.lastKnown(bot, now)
	local threat = target or known
	local zone = world.zone
	bot.zone = zone
	local rotate = zone ~= nil and Tactics.needsZone(bot, zone)
	local pos = root.Position
	local gun = BotGun.current(bot.gun)
	local lowAmmo = gun ~= nil and gun.config.magSize > 0 and gun.ammo < 1
	local underPressure = now - bot.lastHurtAt < 0.85
	local cover = bot.coverGoal
	local peeking = now < bot.peekUntil
	if
		rotate
		or not threat
		or (switched and previous ~= nil)
		or (cover and bot.nav.failedFor and (cover - bot.nav.failedFor).Magnitude < 3)
	then
		bot.coverGoal, bot.peekGoal = nil, nil
		bot.coverUntil, bot.peekUntil = 0, 0
		cover, peeking = nil, false
	elseif
		not cover
		and now >= bot.coverAt
		and not peeking
		and (lowAmmo or hp < bot.profile.tactics.coverHealth or (underPressure and not target))
	then
		bot.coverAt = now + BotsConfig.COVER_RETRY
		bot.coverGoal, bot.peekGoal = Tactics.findCover(bot, threat.lastPos, world.allies)
		cover = bot.coverGoal
	end

	-- Score the goals.
	local scores: { [string]: number } = { Roam = 0.2 }
	if target then
		local enemyHp = 1
		local h = target.model:FindFirstChildOfClass("Humanoid")
		if h then
			enemyHp = Health.get(h) / math.max(Health.max(h), 1)
		end
		scores.Engage = 0.6 + aggression * 0.3
		if hp < bot.profile.tactics.coverHealth and enemyHp > hp then
			scores.Retreat = 1.05 - aggression * 0.28
		end
	elseif known then
		scores.Hunt = 0.45 + aggression * 0.35
	end
	local best, bestScore = "Roam", -1
	for goal, score in scores do
		if score > bestScore then
			best, bestScore = goal, score
		end
	end
	local currentScore = scores[bot.goal]
	if
		currentScore
		and best ~= bot.goal
		and (
			now - bot.goalSince < BotsConfig.COMMIT_TIME
			or bestScore < currentScore + BotsConfig.SWITCH_MARGIN
		)
	then
		best = bot.goal
	end
	local peek = bot.peekGoal
	if rotate then
		best = "Rotate"
	elseif cover and threat then
		local arrived = ((cover - pos) * Vector3.new(1, 0, 1)).Magnitude < 2.4
		if bot.coverUntil == 0 and arrived then
			bot.coverUntil = now + bot.profile.tactics.coverPatience
		end
		if bot.coverUntil == 0 or now < bot.coverUntil or BotGun.reloading(bot.gun) then
			best = "Cover"
		elseif peek and (peeking or bot.peekUntil == 0) then
			if not peeking then
				bot.peekUntil = now + BotsConfig.PEEK_TIME
			end
			best = "Peek"
		else
			bot.coverGoal, bot.peekGoal = nil, nil
			bot.coverUntil, bot.peekUntil = 0, 0
			bot.coverAt = now + BotsConfig.COVER_RETRY
		end
	end
	if best ~= bot.goal or switched then
		Nav.clear(bot.nav)
	end
	if bot.goal == "Roam" and best ~= "Roam" then
		bot.lastRoam = bot.roamGoal or bot.lastRoam
		bot.roamGoal = nil
	end
	setGoal(bot, best, now)
	if STUDIO then
		-- Tuning aid (Studio only): what it is doing and who it's after.
		StateValues.set(bot.owner, "BotGoal", best)
		StateValues.set(bot.owner, "BotTarget", if target then target.model.Name else nil)
	end

	-- Plan the movement for the goal.
	bot.wantSprint = false
	bot.wantCrouch = false
	bot.moveDir = Vector3.zero
	if best == "Rotate" and zone then
		local destination = Tactics.zoneGoal(bot, zone)
		Nav.setGoal(bot, destination)
		bot.wantSprint = true
		bot.lookAt = destination
	elseif best == "Cover" and cover and threat then
		if bot.coverUntil == 0 then
			Nav.setGoal(bot, cover)
		else
			Nav.clear(bot.nav)
			bot.wantCrouch = true
		end
		bot.lookAt = threat.lastPos
	elseif best == "Peek" and peek and threat then
		Nav.setGoal(bot, peek)
		bot.lookAt = threat.lastPos
	elseif best == "Engage" and target then
		local offset = (target.lastPos - pos) * Vector3.new(1, 0, 1)
		local distance = offset.Magnitude
		local toward = if distance > 0.1 then offset.Unit else root.CFrame.LookVector
		local side = Vector3.new(-toward.Z, 0, toward.X)
		if now >= bot.strafeUntil then
			newStrafe(bot, now)
		end
		local push = math.clamp((distance - high) / (high * 0.25), 0, 1)
			- math.clamp((low - distance) / math.max(low * 0.5, 1), 0, 0.75)
		local pathThreshold = if bot.nav.goal then high * 1.12 else high * 1.25
		local shotgun = weapon and weapon.class == "Shotgun"
		local higherGround = math.abs(target.groundPos.Y - pos.Y) > 5
		if distance > pathThreshold or (shotgun and higherGround) then
			Nav.setGoal(bot, target.groundPos)
		else
			Nav.clear(bot.nav)
		end
		bot.moveDir = toward * push + side * bot.strafeDir
		bot.wantSprint = shotgun == true and (target.lastPos - pos).Magnitude > high * 1.6
		if push == 0 and distance > BotsConfig.CROUCH_AT and now >= bot.crouchUntil then
			if rng:NextNumber() < BotsConfig.CROUCH_CHANCE * 0.1 then
				bot.crouchUntil = now + 0.6 + rng:NextNumber()
			end
		end
		bot.wantCrouch = now < bot.crouchUntil
		bot.lookAt = target.lastPos
	elseif best == "Retreat" and target then
		local away = (pos - target.lastPos) * Vector3.new(1, 0, 1)
		local dir = if away.Magnitude > 0.1 then away.Unit else -root.CFrame.LookVector
		Nav.clear(bot.nav)
		bot.moveDir = dir
		bot.lookAt = target.lastPos
	elseif best == "Hunt" and known then
		-- Where it last stood (a jumping target's air position has no path).
		local goal = known.groundPos
		if not glimpse and bot.nav.failedFor and (bot.nav.failedFor - goal).Magnitude < 1 then
			known.unreachableAt = now -- no path: forget it and roam instead
		end
		if not glimpse and ((goal - pos) * Vector3.new(1, 0, 1)).Magnitude < 4 then
			known.unreachableAt = now -- searched its last known position
		end
		Nav.setGoal(bot, goal)
		bot.wantSprint = (goal - pos).Magnitude > 12
		bot.lookAt = known.lastPos
	else
		local goal = Tactics.patrol(bot, world.roam, world.patrol, now)
		if goal ~= bot.roamGoal then
			Nav.clear(bot.nav)
		end
		bot.roamGoal = goal
		if goal then
			Nav.setGoal(bot, goal)
			bot.wantSprint = true
			bot.lookAt = goal
		else
			Nav.clear(bot.nav)
		end
	end
	if best ~= "Rotate" and best ~= "Cover" and best ~= "Peek" then
		bot.moveDir += spacing(bot, world.allies)
	end

	manageGun(bot, target ~= nil and best ~= "Cover" and best ~= "Rotate")
	BotMods.think(bot, world, now)
end

local function idle(
	bot: Bot,
	root: BasePart,
	humanoid: Humanoid,
	dt: number,
	now: number,
	align: AlignOrientation?
)
	if now >= bot.idleUntil then
		bot.idleUntil = now + rng:NextNumber(0.75, 1.55)
		local action = rng:NextInteger(1, 5)
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local look = root.CFrame.LookVector
		local sideways = root.CFrame.RightVector * side
		bot.lookAt = root.Position + (look + sideways * 0.65) * 10
		bot.wantCrouch = action == 3
		bot.moveDir = if action <= 2 then (look * 0.35 + sideways).Unit * 0.55 else Vector3.zero
		if
			action == 4
			and humanoid.FloorMaterial ~= Enum.Material.Air
			and Nav.clearLine(
				bot,
				root.Position + Vector3.yAxis * 1.3,
				root.Position + Vector3.yAxis * 4.2
			)
		then
			humanoid.Jump = true
		end
	end
	local dir = Nav.avoid(bot, bot.moveDir, false, now)
	humanoid:Move(dir, false)
	Aim.step(bot, nil, dt)
	if align then
		align.CFrame = CFrame.Angles(0, bot.yaw, 0)
	end
end

-- Every frame: aim, steer, inputs, trigger. Returns true when a shot went off.
function Brain.act(bot: Bot, dt: number, align: AlignOrientation?): boolean
	local model, humanoid, root = bot.model, bot.humanoid, bot.root
	if not model or not humanoid or not root or not Health.isAlive(humanoid) then
		return false
	end
	local now = os.clock()
	BotGun.step(bot.gun, model, dt)
	if not bot.fighting then
		bot.steerInput = Vector3.zero
		if bot.postRound then
			idle(bot, root, humanoid, dt, now, align)
		else
			humanoid:Move(Vector3.zero, false)
		end
		setInput(bot, "Sprint", false)
		setInput(bot, "Crouch", bot.postRound and bot.wantCrouch)
		setInput(bot, "Fire", false)
		setInput(bot, "Aim", false)
		publishAim(bot, false, now)
		return false
	end

	local target = bot.target
	-- Blinded (a Flash): it can't see to aim or shoot until it clears.
	local blind = Perception.isBlinded(bot)
	local rotating = bot.goal == "Rotate"
	local engage = not rotating
		and not blind
		and target ~= nil
		and Perception.engageable(bot, target, now)
	-- Follow the intended route around corners, including when entering the ring.
	local requested, jump = bot.moveDir, false
	if bot.nav.goal then
		requested, jump = Nav.steer(bot, now)
		-- Keep combat strafing away from tight waypoints, where it can push
		-- the bot off the route and back toward the previous corner.
		local followingPath = bot.nav.waypoints[bot.nav.index] ~= nil
		if bot.goal == "Engage" and not followingPath then
			requested += bot.moveDir * 0.3
		elseif bot.goal == "Roam" or bot.goal == "Hunt" then
			requested += bot.moveDir * (if followingPath then 0.1 else 0.22)
		end
	end
	-- Ease between strafe legs and route headings before checking clearance.
	-- A blocked direction still stops or detours immediately.
	local moveAlpha = 1 - math.exp(-dt / BotsConfig.MOVE_RESPONSE)
	bot.steerInput = bot.steerInput:Lerp(requested, moveAlpha)
	local dir, hop = Nav.avoid(bot, bot.steerInput, jump, now)
	if
		(rotating or bot.goal == "Roam")
		and not engage
		and dir.Magnitude > 0.3
		and requested.Magnitude > 0.3
	then
		bot.lookAt = root.Position + requested.Unit * 12
	end
	local point = if engage then Aim.targetPoint(bot, now) else nil
	local lag = Aim.step(bot, point, dt)
	if align then
		align.CFrame = CFrame.Angles(0, bot.yaw, 0)
	end
	setInput(bot, "AimPitch", math.clamp(math.deg(bot.pitch) / 90, -1, 1))

	if hop then
		humanoid.Jump = true
	end
	if Nav.checkStuck(bot, requested.Magnitude > 0.2 or jump) then
		if bot.goal == "Roam" then
			local failed = bot.roamGoal
			if failed then
				bot.roamBlocked[failed] = now + BotsConfig.ROAM_RETRY
			end
		elseif bot.goal == "Cover" or bot.goal == "Peek" then
			bot.coverGoal, bot.peekGoal = nil, nil
			bot.coverUntil, bot.peekUntil = 0, 0
		end
	end
	humanoid:Move(dir, false)

	-- Sprint only forward-ish (the simulation also checks), slide in when
	-- sprinting into a fight's range.
	local facing = root.CFrame.LookVector
	local distance = if target then (target.lastPos - root.Position).Magnitude else math.huge
	local config = BotGun.config(bot.gun)
	local outsideShotgunRange = config ~= nil
		and config.class == "Shotgun"
		and distance > BotsConfig.RANGE.Shotgun[2] * 1.6
	local sprint = bot.wantSprint
		and (not engage or outsideShotgunRange)
		and dir.Magnitude > 0.5
		and facing:Dot(dir) > 0.5
	local crouch = bot.wantCrouch
	local state = StateValues.get(model, "MoveState")
	if
		engage
		and state == "Sprint"
		and distance >= BotsConfig.SLIDE_RANGE[1]
		and distance <= BotsConfig.SLIDE_RANGE[2]
		and now >= bot.slideCheckAt
	then
		bot.slideCheckAt = now + 1
		if
			rng:NextNumber() < bot.profile.movement.slideChance
			and Nav.canMove(bot, dir, BotsConfig.SLIDE_CLEARANCE)
			and Nav.zoneAllows(bot, root.Position + dir * BotsConfig.SLIDE_CLEARANCE, 0.4)
		then
			crouch = true
			bot.crouchUntil = now + 0.5
		end
	end
	if state == "Slide" then
		crouch = now < bot.crouchUntil
		if
			rng:NextNumber() < dt * bot.profile.movement.slideJumpChance * 4
			and Nav.canMove(bot, dir, BotsConfig.SLIDE_CLEARANCE, true)
			and Nav.zoneAllows(bot, root.Position + dir * BotsConfig.SLIDE_CLEARANCE, 0.4)
		then
			humanoid.Jump = true
		end
	end
	setInput(bot, "Sprint", sprint)
	setInput(bot, "Crouch", crouch)

	-- ADS for steady shots at range (guns with sights).
	local wantAds = engage
		and config ~= nil
		and not config.noAds
		and config.fireMode ~= "Melee"
		and not outsideShotgunRange
		and distance > 14
	bot.gun.aimHeld = wantAds
	setInput(bot, "Aim", wantAds)
	publishAim(bot, wantAds, now)

	-- The trigger: on target (as far as it knows), the gun ready, burst
	-- discipline at range, a human's trigger delay.
	local fired = false
	local triggerHeld = false
	if engage and config and point and not outsideShotgunRange then
		local cone = BotGun.cone(bot.gun, root)
		local onTarget = lag
			< Aim.targetSize(distance) * 2 + cone * 0.5 + BotsConfig.FIRE_CONE_SLACK
		if not onTarget then
			bot.triggerAt = now
				+ BotsConfig.TRIGGER_DELAY[1]
				+ rng:NextNumber() * (BotsConfig.TRIGGER_DELAY[2] - BotsConfig.TRIGGER_DELAY[1])
		elseif now >= bot.triggerAt and now >= bot.burstRestUntil and distance <= config.range then
			triggerHeld = true
			-- A fair miss: the first shots at a new target, or when the target
			-- already took its budget of bot hits this second.
			local fair = bot.missLeft > 0
				or overBudget(target.model, bot.profile.aim.maxHitsPerSec, now)
			local missBy = if fair
				then (Aim.targetSize(distance) * 1.3 + BotsConfig.FAIR_MISS_ANGLE) * (if rng:NextNumber()
						< 0.5
					then -1
					else 1)
				else nil
			local ok, up, side, hit = BotGun.fire(bot.gun, model, Aim.direction(bot, missBy))
			if ok then
				fired = true
				if fair and bot.missLeft > 0 then
					bot.missLeft -= 1
				end
				if hit then
					recordHit(target.model, now)
				end
				if STUDIO then
					local o = bot.owner
					StateValues.set(
						o,
						"BotShots",
						((StateValues.get(o, "BotShots") :: number?) or 0) + 1
					)
					if hit then
						StateValues.set(
							o,
							"BotHits",
							((StateValues.get(o, "BotHits") :: number?) or 0) + 1
						)
					end
				end
				Aim.kick(bot, up, side)
				-- Auto guns at range: short bursts, then a rest.
				if config.fireMode == "Auto" and distance > BotsConfig.TAP_RANGE then
					bot.burstLeft -= 1
					if bot.burstLeft <= 0 then
						bot.burstLeft =
							rng:NextInteger(BotsConfig.BURST_SHOTS[1], BotsConfig.BURST_SHOTS[2])
						bot.burstRestUntil = now
							+ BotsConfig.BURST_REST[1]
							+ rng:NextNumber()
								* (BotsConfig.BURST_REST[2] - BotsConfig.BURST_REST[1])
					end
				elseif config.fireMode ~= "Auto" then
					-- Semi-auto: a finger, not a macro.
					bot.burstRestUntil = now + rng:NextNumber() * 0.08
				end
			end
		end
	end
	-- The Fire input blocks sprinting in the simulation, like a player's.
	setInput(bot, "Fire", triggerHeld)
	return fired
end

return Brain
