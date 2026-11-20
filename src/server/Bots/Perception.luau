--!strict
-- What a bot knows about its enemies (vault/01 Design/Bots.md → Brain).
-- Sight: a vision cone (plus a small all-round sense) and a line-of-sight
-- raycast, a few rays per think at most. Memory per enemy: last position,
-- when it was seen, how long it has been in sight. An enemy is only
-- engageable after the profile's reaction time in sight (half when it was
-- seen a moment ago). Gunshots inside the hearing radius give a rough
-- position.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)

local BotsConfig = require(ReplicatedStorage.Shared.Config.Bots)
local Health = require(ReplicatedStorage.Shared.Health)
local StatusEffects = require(ReplicatedStorage.Shared.Config.StatusEffects)
local BotTypes = require(script.Parent.Types)
local ModWalls = require(script.Parent.Parent.Services.ModWalls)

type Bot = BotTypes.Bot
type Memory = BotTypes.Memory

local Perception = {}

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
local exclude: { Instance } = {}
local rng = Random.new()

local function partOf(model: Model, name: string): BasePart?
	local part = model:FindFirstChild(name)
	if part and part:IsA("BasePart") then
		return part
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Can `bot` see `part` of `enemy` from its eyes? One ray.
local function lineOfSight(
	bot: Bot,
	eye: Vector3,
	enemy: Model,
	part: BasePart,
	now: number
): boolean
	local model = bot.model :: Model
	exclude[1] = model
	params.FilterDescendantsInstances = exclude
	local to = part.Position - eye
	local result = workspace:Raycast(eye, to * 1.02, params)
	return (result == nil or result.Instance:IsDescendantOf(enemy))
		and not ModWalls.blocksSight(eye, part.Position, now)
end

function Perception.isBlinded(bot: Bot): boolean
	local expiry = bot.model and StateValues.get(bot.model, StatusEffects.blinded.attribute)
	return typeof(expiry) == "number" and expiry > workspace:GetServerTimeNow()
end

local function memoryFor(bot: Bot, enemy: Model, pos: Vector3): Memory
	local m = bot.memory[enemy]
	if not m then
		m = {
			model = enemy,
			lastPos = pos,
			seenAt = -math.huge,
			visibleSince = nil,
			visible = false,
			visibleAt = -math.huge,
			firedAt = -math.huge,
			heard = false,
			headVisible = false,
			bodyVisible = false,
			headOffset = Vector3.zero,
			bodyOffset = Vector3.zero,
			aimPart = "UpperTorso",
			trailPos = table.create(BotsConfig.TRAIL, pos),
			trailT = table.create(BotsConfig.TRAIL, -math.huge),
			trailHead = 1,
			groundPos = pos,
			unreachableAt = nil,
		}
		bot.memory[enemy] = m
	end
	return m
end

-- One think's look around. `enemies`: every live enemy combatant model.
function Perception.update(bot: Bot, enemies: { Model }, now: number)
	local root, head = bot.root, bot.head
	if not root or not head then
		return
	end
	local eye = head.Position
	local look = root.CFrame.LookVector
	local cosHalf = math.cos(math.rad(bot.profile.perception.fov / 2))
	local rays = BotsConfig.MAX_RAYS_PER_THINK

	-- Forget the dead and the gone, and memories older than the profile's.
	for model, m in bot.memory do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if
			not model.Parent
			or not Health.isAlive(humanoid)
			or now - m.seenAt > bot.profile.perception.memory * 2
		then
			bot.memory[model] = nil
			if bot.target == m then
				bot.target = nil
			end
		end
	end

	if Perception.isBlinded(bot) then
		for _, m in bot.memory do
			m.visible, m.visibleSince = false, nil
			m.bodyVisible, m.headVisible = false, false
		end
		return
	end

	-- Give every opponent a torso and head check in normal team sizes.
	-- Rotate the starting seat if a larger mode ever exhausts the ray budget.
	local count = #enemies
	if count == 0 then
		return
	end
	local start = bot.sightCursor % count
	bot.sightCursor = start + 1
	for i = 0, count - 1 do
		local enemy = enemies[(start + i) % count + 1]
		local m = bot.memory[enemy]
		local enemyRoot = partOf(enemy, "HumanoidRootPart")
		if not enemyRoot then
			if m then
				m.visible, m.visibleSince = false, nil
			end
			continue
		end
		local offset = enemyRoot.Position - eye
		local distance = offset.Magnitude
		local inCone = distance <= BotsConfig.NEAR_SENSE
			or (distance > 0 and look:Dot(offset / distance) >= cosHalf)
		if inCone and rays == 0 then
			continue -- out of budget is not the same as losing sight
		end
		local headPart = if inCone then partOf(enemy, "Head") else nil
		local chest = if inCone then partOf(enemy, "UpperTorso") else nil
		local bodyVisible, headVisible = false, false
		if chest then
			rays -= 1
			bodyVisible = lineOfSight(bot, eye, enemy, chest, now)
		end
		if headPart and rays > 0 then
			rays -= 1
			headVisible = lineOfSight(bot, eye, enemy, headPart, now)
		end
		if bodyVisible or headVisible then
			m = memoryFor(bot, enemy, enemyRoot.Position)
			if not m.visible then
				-- Back in sight: someone seen just now is quicker to react to.
				local recent = now - m.visibleAt < BotsConfig.REACQUIRE_WINDOW
				local reaction = math.max(
					bot.profile.perception.reaction
						* (if recent then 0.5 else 1)
						* (0.8 + rng:NextNumber() * 0.4),
					BotsConfig.REACTION_FLOOR
				)
				m.visibleSince = now + reaction - bot.profile.perception.reaction
			end
			m.visible = true
			m.heard = false
			m.lastPos = enemyRoot.Position
			m.seenAt = now
			m.visibleAt = now
			m.bodyVisible, m.headVisible = bodyVisible, headVisible
			if chest and bodyVisible then
				m.bodyOffset = chest.Position - enemyRoot.Position
			end
			if headPart and headVisible then
				m.headOffset = headPart.Position - enemyRoot.Position
			end
			m.unreachableAt = nil
			-- The trail (aim lag) and where it last stood (path goals).
			local slot = m.trailHead % BotsConfig.TRAIL + 1
			m.trailHead = slot
			m.trailPos[slot] = enemyRoot.Position
			m.trailT[slot] = now
			local humanoid = enemy:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
				m.groundPos = enemyRoot.Position
			end
		elseif m then
			m.visible = false
			m.visibleSince = nil
		end
	end
end

-- In sight long enough to react to.
function Perception.engageable(bot: Bot, m: Memory, now: number): boolean
	return m.visible
		and now - m.visibleAt <= BotsConfig.SIGHT_FRESHNESS
		and m.visibleSince ~= nil
		and now - m.visibleSince >= bot.profile.perception.reaction
end

-- A gunshot (or another loud thing) at `at` by `source`.
function Perception.hear(bot: Bot, source: Model, at: Vector3, now: number)
	local root = bot.root
	if not root or (at - root.Position).Magnitude > bot.profile.perception.hearing then
		return
	end
	local m = memoryFor(bot, source, at)
	m.firedAt = now
	if m.visible or now - m.visibleAt < BotsConfig.SHOT_ATTENTION_TIME then
		return
	end
	local noise = rng:NextUnitVector() * Vector3.new(1, 0, 1) * BotsConfig.HEAR_ERROR
	m.lastPos = at + noise
	m.groundPos = m.lastPos
	m.seenAt = now
	m.heard = true
end

-- A glimpse can turn a bot's attention before its firing reaction is ready.
function Perception.glimpse(bot: Bot, now: number): Memory?
	local root = bot.root
	if not root then
		return nil
	end
	local closest: Memory? = nil
	local distance = math.huge
	for _, m in bot.memory do
		if m.visible and now - m.visibleAt <= BotsConfig.SIGHT_FRESHNESS then
			local gap = (m.lastPos - root.Position).Magnitude
			if gap < distance then
				closest, distance = m, gap
			end
		end
	end
	return closest
end

-- A teammate's Mod revealed `model` at `at`: the exact spot, as if seen.
function Perception.reveal(bot: Bot, model: Model, at: Vector3, now: number)
	local m = memoryFor(bot, model, at)
	if m.visible then
		return
	end
	m.lastPos = at
	m.groundPos = at
	m.seenAt = now
	m.heard = false
end

-- Where `m` was `lag` seconds ago (from the trail; its last position when
-- the trail is too short).
function Perception.lagged(m: Memory, now: number, lag: number): Vector3
	local at = now - lag
	local n = BotsConfig.TRAIL
	local newer: number? = nil
	for k = 0, n - 1 do
		local i = (m.trailHead - k - 1) % n + 1
		local t = m.trailT[i]
		if t <= at then
			if not newer then
				return m.trailPos[i]
			end
			local t2 = m.trailT[newer]
			local a = if t2 > t then (at - t) / (t2 - t) else 1
			return m.trailPos[i]:Lerp(m.trailPos[newer], a)
		end
		newer = i
	end
	return m.lastPos
end

-- Rank confirmed threats by gun range, proximity, recent fire and squad
-- pressure. The current target gets a small preference instead of a lock.
function Perception.pickTarget(
	bot: Bot,
	now: number,
	focus: { [Model]: number },
	preferredRange: number,
	maxRange: number
): Memory?
	local root = bot.root
	if not root then
		return nil
	end
	local current = bot.target
	local best: Memory? = nil
	local bestScore = -math.huge
	for model, m in bot.memory do
		if not Perception.engageable(bot, m, now) then
			continue
		end
		local offset = m.lastPos - root.Position
		local distance = offset.Magnitude
		local facing = root.CFrame.LookVector:Dot(offset / math.max(distance, 0.1))
		local score = 1 / (1 + distance / preferredRange) + math.max(facing, 0) * 0.16
		if distance > maxRange then
			score -= 1
		end
		if distance < BotsConfig.THREAT_NEAR then
			score += 0.85 * (1 - distance / BotsConfig.THREAT_NEAR)
		end
		if now - m.firedAt < BotsConfig.SHOT_ATTENTION_TIME then
			score += 0.28
		end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local share = math.clamp(Health.get(humanoid) / math.max(Health.max(humanoid), 1), 0, 1)
			score += (1 - share) * 0.22
		end
		if (focus[model] or 0) >= BotsConfig.MAX_ON_TARGET then
			score -= 0.38
		end
		if m == current then
			score += if now - bot.targetSince < BotsConfig.TARGET_COMMIT then 0.23 else 0.10
		end
		if score > bestScore then
			best, bestScore = m, score
		end
	end
	if best ~= current then
		bot.targetSince = now
		if best then
			-- Chest by default, the head by chance (if it shows).
			best.aimPart = if best.headVisible
					and rng:NextNumber() < bot.profile.aim.headChance
				then "Head"
				else "UpperTorso"
		end
	end
	return best
end

-- The freshest memory not in sight (to hunt), if any is recent enough.
function Perception.lastKnown(bot: Bot, now: number): Memory?
	local best: Memory? = nil
	for _, m in bot.memory do
		local unreachable = m.unreachableAt ~= nil and m.seenAt <= m.unreachableAt
		if
			(not m.visible or now - m.visibleAt > BotsConfig.SIGHT_FRESHNESS)
			and not unreachable
			and now - m.seenAt <= bot.profile.perception.memory
		then
			if not best or m.seenAt > best.seenAt then
				best = m
			end
		end
	end
	return best
end

return Perception
