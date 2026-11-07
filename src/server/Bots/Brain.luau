--!strict
-- A bot's decisions (vault/01 Design/Bots.md → Brain). `think` runs at
-- Config/Bots THINK_RATE: perceive, pick a target, score the goals
-- (utility, with hysteresis) and plan the movement. `act` runs every frame
-- and is cheap: the aim spring, steering, the inputs the shared simulations
-- read (Sprint, Crouch, Aim, Fire, AimPitch) and the trigger.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BotsConfig = require(ReplicatedStorage.Shared.Config.Bots)
local Health = require(ReplicatedStorage.Shared.Health)
local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local RunService = game:GetService("RunService")

local STUDIO = RunService:IsStudio()

local Aim = require(script.Parent.Aim)
local BotGun = require(script.Parent.BotGun)
local BotMods = require(script.Parent.BotMods)
local BotTypes = require(script.Parent.Types)
local Nav = require(script.Parent.Nav)
local Perception = require(script.Parent.Perception)

type Bot = BotTypes.Bot

export type World = {
	enemies: { Model },
	allies: { Model }, -- teammates' characters (not this bot)
	focus: { [Model]: number }, -- how many teammates target each enemy
	roam: Vector3?, -- where to go first with no information (the enemy side)
	patrol: { Vector3 }, -- then from point to point over the map (spawns, middle, flanks)
	lane: number, -- -1, 0, 1: this bot's flank offset (team play)
	zone: Vector3?, -- sudden death: the circle's centre (nil: no circle)
	zoneRadius: number, -- its radius now
}

-- Sudden death: a bot this close to the circle's edge (or past it) heads in.
local ZONE_MARGIN = 6

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

-- What each bot last told spectators about its aim (like a player's Aim
-- remote: at most 10 times a second, only on a real change).
type AimSent = { at: number, pitch: number, aiming: boolean }
local aimSent: { [Bot]: AimSent } = setmetatable({}, { __mode = "k" }) :: any
local AIM_SEND_EVERY = 0.1
local AIM_SEND_DELTA = 0.03 -- radians

-- `AimPitch` (radians) and `Aiming` on the bot's owner (mirrored onto its
-- model), read by a teammate spectating it in first person.
local function publishAim(bot: Bot, aiming: boolean, now: number)
	local sent = aimSent[bot]
	if not sent then
		sent = { at = -math.huge, pitch = math.huge, aiming = false }
		aimSent[bot] = sent
	end
	if now - sent.at < AIM_SEND_EVERY then
		return
	end
	if math.abs(bot.pitch - sent.pitch) <= AIM_SEND_DELTA and aiming == sent.aiming then
		return
	end
	sent.at, sent.pitch, sent.aiming = now, bot.pitch, aiming
	bot.owner:SetAttribute("AimPitch", bot.pitch)
	bot.owner:SetAttribute("Aiming", aiming)
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
	local shield = humanoid:GetAttribute(Combat.SHIELD_ATTRIBUTE)
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
		local other = if slot == "Primary" then gun.slots.Secondary else gun.slots.Primary
		if inFight and other and other.ammo > 0 and rng:NextNumber() < 0.7 then
			BotGun.equip(
				gun,
				model,
				bot.owner,
				if slot == "Primary" then "Secondary" else "Primary"
			)
		else
			BotGun.reload(gun, model, bot.owner)
		end
		return
	end
	if not inFight then
		if slot ~= "Primary" and gun.slots.Primary then
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
	local pause = rng:NextNumber() < BotsConfig.STRAFE_PAUSE
	bot.strafeDir = if pause
		then 0
		elseif bot.strafeDir == 0 then (if rng:NextNumber() < 0.5 then -1 else 1)
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
	bot.target = Perception.pickTarget(bot, now, world.focus)
	if bot.target and bot.target ~= previous then
		Aim.acquire(bot)
		bot.missLeft = bot.profile.firstMisses
	end
	local target = bot.target
	local hp = Brain.healthShare(bot)
	local aggression = bot.profile.aggression
	local known = if target then nil else Perception.lastKnown(bot, now)

	-- Score the goals.
	local scores: { [string]: number } = { Roam = 0.2 }
	if target then
		local enemyHp = 1
		local h = target.model:FindFirstChildOfClass("Humanoid")
		if h then
			enemyHp = Health.get(h) / math.max(Health.max(h), 1)
		end
		scores.Engage = 0.6 + aggression * 0.3
		if hp < BotsConfig.RETREAT_HEALTH then
			scores.Retreat = 0.95 - aggression * 0.3 - (if enemyHp < hp then 0.3 else 0)
		end
	elseif known then
		scores.Hunt = 0.45 + aggression * 0.35
		if hp < BotsConfig.RETREAT_HEALTH and aggression < 0.6 then
			scores.Hold = 0.7 -- hurt: let them come
		end
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
	setGoal(bot, best, now)
	if STUDIO then
		-- Tuning aid (Studio only): what it is doing and who it's after.
		bot.owner:SetAttribute("BotGoal", best)
		bot.owner:SetAttribute("BotTarget", if target then target.model.Name else nil)
	end

	-- Plan the movement for the goal.
	local pos = root.Position
	bot.wantSprint = false
	bot.wantCrouch = false
	bot.moveDir = Vector3.zero
	if best == "Engage" and target then
		local low, high = rangeBand(bot)
		local offset = (target.lastPos - pos) * Vector3.new(1, 0, 1)
		local distance = offset.Magnitude
		local toward = if distance > 0.1 then offset.Unit else root.CFrame.LookVector
		local side = Vector3.new(-toward.Z, 0, toward.X)
		if now >= bot.strafeUntil then
			newStrafe(bot, now)
		end
		local push = 0
		if distance > high * 1.25 then
			push = 1
		elseif distance > high then
			push = 0.6
		elseif distance < low then
			push = -0.7
		end
		if push > 0 and distance > high * 1.25 then
			Nav.setGoal(bot, target.lastPos)
		else
			Nav.clear(bot.nav)
		end
		bot.moveDir = toward * push + side * bot.strafeDir
		if push == 0 and distance > BotsConfig.CROUCH_AT and now >= bot.crouchUntil then
			if rng:NextNumber() < BotsConfig.CROUCH_CHANCE * 0.1 then
				bot.crouchUntil = now + 0.6 + rng:NextNumber()
			end
		end
		bot.wantCrouch = now < bot.crouchUntil
		bot.lookAt = target.lastPos
		local jumpChance = BotsConfig.JUMP_CHANCE * (if bot.profile.aggression > 0.7 then 2 else 1)
		if bot.humanoid and rng:NextNumber() < jumpChance then
			bot.humanoid.Jump = true
		end
	elseif best == "Retreat" and target then
		local away = (pos - target.lastPos) * Vector3.new(1, 0, 1)
		local dir = if away.Magnitude > 0.1 then away.Unit else -root.CFrame.LookVector
		Nav.setGoal(bot, pos + dir * 25)
		bot.wantSprint = true
		bot.lookAt = target.lastPos
	elseif best == "Hunt" and known then
		-- Where it last stood (a jumping target's air position has no path).
		local goal = known.groundPos
		if bot.nav.failedFor and (bot.nav.failedFor - goal).Magnitude < 1 then
			known.unreachableAt = now -- no path: forget it and roam instead
		end
		local offset = (goal - pos) * Vector3.new(1, 0, 1)
		if world.lane ~= 0 and offset.Magnitude > 25 then
			local side = Vector3.new(-offset.Unit.Z, 0, offset.Unit.X)
			goal += side * world.lane * 10
		end
		Nav.setGoal(bot, goal)
		bot.wantSprint = offset.Magnitude > 12
		bot.lookAt = known.lastPos
	elseif best == "Hold" and known then
		Nav.clear(bot.nav)
		bot.lookAt = known.lastPos
		bot.wantCrouch = true
	else
		-- No information: the enemy side first, then point to point over
		-- the map (never parking: two bots that miss each other keep looking).
		local goal = bot.roamGoal or world.roam
		if goal and ((goal - pos) * Vector3.new(1, 0, 1)).Magnitude < 8 and #world.patrol > 0 then
			local options: { Vector3 } = {}
			for _, p in world.patrol do
				if ((p - pos) * Vector3.new(1, 0, 1)).Magnitude > 20 then
					table.insert(options, p)
				end
			end
			if #options > 0 then
				goal = options[rng:NextInteger(1, #options)]
			end
		end
		bot.roamGoal = goal
		if goal then
			Nav.setGoal(bot, goal)
			bot.wantSprint = true
			bot.lookAt = goal
		end
	end
	-- Sudden death: get inside the circle first, still shooting on the way.
	local zone = world.zone
	local zoneEdge = math.max(world.zoneRadius - ZONE_MARGIN, world.zoneRadius * 0.5)
	if zone and ((pos - zone) * Vector3.new(1, 0, 1)).Magnitude > zoneEdge then
		Nav.setGoal(bot, zone)
		bot.wantSprint = target == nil
		bot.lookAt = if target then bot.lookAt else zone
	end
	bot.moveDir += spacing(bot, world.allies)

	manageGun(bot, target ~= nil)
	BotMods.think(bot, world, now)
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
		humanoid:Move(Vector3.zero, false)
		setInput(bot, "Sprint", false)
		setInput(bot, "Crouch", false)
		setInput(bot, "Fire", false)
		setInput(bot, "Aim", false)
		publishAim(bot, false, now)
		return false
	end

	local target = bot.target
	local engage = target ~= nil and Perception.engageable(bot, target, now)
	local point = if engage then Aim.targetPoint(bot, now) else nil
	local lag = Aim.step(bot, point, dt)
	if align then
		align.CFrame = CFrame.Angles(0, bot.yaw, 0)
	end
	setInput(bot, "AimPitch", math.clamp(math.deg(bot.pitch) / 90, -1, 1))

	-- Steering: the path when there is one, else the planned direction.
	local dir = bot.moveDir
	if bot.nav.goal then
		local steer, jump = Nav.steer(bot)
		if steer.Magnitude > 0 then
			dir = steer + (if engage then dir * 0.3 else Vector3.zero)
		end
		if jump then
			humanoid.Jump = true
		end
	end
	local escalate = Nav.checkStuck(bot, dir.Magnitude > 0.2)
	if escalate == 1 then
		humanoid.Jump = true
	elseif
		bot.goal == "Roam"
		and (
			escalate == 3
			or (
				bot.nav.failedFor ~= nil
				and bot.roamGoal ~= nil
				and (bot.nav.failedFor - bot.roamGoal).Magnitude < 1
			)
		)
	then
		bot.roamGoal = root.Position -- can't get there: the next think picks another point
	elseif escalate == 2 then
		bot.strafeDir = if rng:NextNumber() < 0.5 then -1 else 1
		bot.strafeUntil = now + 0.5
		dir = Vector3.new(-dir.Z, 0, dir.X) * bot.strafeDir
	end
	if dir.Magnitude > 1 then
		dir = dir.Unit
	end
	humanoid:Move(dir, false)

	-- Sprint only forward-ish (the simulation also checks), slide in when
	-- sprinting into a fight's range.
	local facing = root.CFrame.LookVector
	local sprint = bot.wantSprint and not engage and dir.Magnitude > 0.5 and facing:Dot(dir) > 0.5
	local crouch = bot.wantCrouch
	local distance = if target then (target.lastPos - root.Position).Magnitude else math.huge
	local state = model:GetAttribute("MoveState")
	if
		target
		and state == "Sprint"
		and distance >= BotsConfig.SLIDE_RANGE[1]
		and distance <= BotsConfig.SLIDE_RANGE[2]
	then
		crouch = true -- a press while sprinting starts a slide (Simulation/Movement)
		bot.crouchUntil = now + 0.5
	end
	if state == "Slide" then
		crouch = now < bot.crouchUntil
		-- Hard bots sometimes jump out of a slide (slide-jump).
		if bot.profile.aggression > 0.7 and rng:NextNumber() < dt * 1.5 then
			humanoid.Jump = true
		end
	end
	setInput(bot, "Sprint", sprint)
	setInput(bot, "Crouch", crouch)

	-- ADS for steady shots at range (guns with sights).
	local config = BotGun.config(bot.gun)
	local wantAds = engage
		and config ~= nil
		and not config.noAds
		and config.fireMode ~= "Melee"
		and distance > 14
	bot.gun.aimHeld = wantAds
	setInput(bot, "Aim", wantAds)
	publishAim(bot, wantAds, now)

	-- The trigger: on target (as far as it knows), the gun ready, burst
	-- discipline at range, a human's trigger delay.
	local fired = false
	local triggerHeld = false
	if engage and config and point then
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
				or overBudget(target.model, bot.profile.maxHitsPerSec, now)
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
					o:SetAttribute("BotShots", ((o:GetAttribute("BotShots") :: number?) or 0) + 1)
					if hit then
						o:SetAttribute("BotHits", ((o:GetAttribute("BotHits") :: number?) or 0) + 1)
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
