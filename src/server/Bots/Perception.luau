--!strict
-- What a bot knows about its enemies (vault/01 Design/Bots.md → Brain).
-- Sight: a vision cone (plus a small all-round sense) and a line-of-sight
-- raycast, a few rays per think at most. Memory per enemy: last position,
-- when it was seen, how long it has been in sight. An enemy is only
-- engageable after the profile's reaction time in sight (half when it was
-- seen a moment ago). Gunshots inside the hearing radius give a rough
-- position.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BotsConfig = require(ReplicatedStorage.Shared.Config.Bots)
local Health = require(ReplicatedStorage.Shared.Health)
local BotTypes = require(script.Parent.Types)

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
local function lineOfSight(bot: Bot, eye: Vector3, enemy: Model, part: BasePart): boolean
	local model = bot.model :: Model
	exclude[1] = model
	params.FilterDescendantsInstances = exclude
	local to = part.Position - eye
	local result = workspace:Raycast(eye, to * 1.02, params)
	return result == nil or result.Instance:IsDescendantOf(enemy)
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
			heard = false,
			headVisible = false,
			aimPart = "UpperTorso",
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
	local cosHalf = math.cos(math.rad(bot.profile.fov / 2))
	local rays = BotsConfig.MAX_RAYS_PER_THINK

	-- Forget the dead and the gone, and memories older than the profile's.
	for model, m in bot.memory do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if
			not model.Parent
			or not Health.isAlive(humanoid)
			or now - m.seenAt > bot.profile.memory * 2
		then
			bot.memory[model] = nil
			if bot.target == m then
				bot.target = nil
			end
		end
	end

	-- Those already in sight first (keep tracking them), then nearest.
	table.sort(enemies, function(a: Model, b: Model): boolean
		local ma, mb = bot.memory[a], bot.memory[b]
		local va = ma ~= nil and ma.visible
		local vb = mb ~= nil and mb.visible
		if va ~= vb then
			return va
		end
		local ra, rb = partOf(a, "HumanoidRootPart"), partOf(b, "HumanoidRootPart")
		if not ra or not rb then
			return ra ~= nil
		end
		return (ra.Position - eye).Magnitude < (rb.Position - eye).Magnitude
	end)

	for _, enemy in enemies do
		local enemyRoot = partOf(enemy, "HumanoidRootPart")
		if not enemyRoot then
			continue
		end
		local offset = enemyRoot.Position - eye
		local distance = offset.Magnitude
		local inCone = distance <= BotsConfig.NEAR_SENSE
			or (distance > 0 and look:Dot(offset / distance) >= cosHalf)
		local seen = false
		local aimPart = "UpperTorso"
		if inCone and rays > 0 then
			local headPart = partOf(enemy, "Head")
			if headPart then
				rays -= 1
				seen = lineOfSight(bot, eye, enemy, headPart)
				aimPart = "Head"
			end
			if not seen and rays > 0 then
				local chest = partOf(enemy, "UpperTorso")
				if chest then
					rays -= 1
					seen = lineOfSight(bot, eye, enemy, chest)
					aimPart = "UpperTorso"
				end
			end
		end
		local m = bot.memory[enemy]
		if seen then
			m = memoryFor(bot, enemy, enemyRoot.Position)
			if not m.visible then
				-- Back in sight: someone seen just now is quicker to react to.
				local recent = now - m.seenAt < BotsConfig.REACQUIRE_WINDOW
				local reaction = bot.profile.reaction * (if recent then 0.5 else 1)
				m.visibleSince = now
					+ reaction * (0.8 + rng:NextNumber() * 0.4)
					- bot.profile.reaction
			end
			m.visible = true
			m.heard = false
			m.lastPos = enemyRoot.Position
			m.seenAt = now
			m.headVisible = aimPart == "Head"
		elseif m then
			m.visible = false
			m.visibleSince = nil
		end
	end
end

-- In sight long enough to react to.
function Perception.engageable(bot: Bot, m: Memory, now: number): boolean
	return m.visible and m.visibleSince ~= nil and now - m.visibleSince >= bot.profile.reaction
end

-- A gunshot (or another loud thing) at `at` by `source`.
function Perception.hear(bot: Bot, source: Model, at: Vector3, now: number)
	local root = bot.root
	if not root or (at - root.Position).Magnitude > bot.profile.hearing then
		return
	end
	local m = memoryFor(bot, source, at)
	if m.visible then
		return
	end
	local noise = rng:NextUnitVector() * Vector3.new(1, 0, 1) * BotsConfig.HEAR_ERROR
	m.lastPos = at + noise
	m.seenAt = now
	m.heard = true
end

-- Picks the target: engageable enemies scored by distance, a teammate's
-- target (focus fire) and how hurt they are; sticks for a moment.
function Perception.pickTarget(bot: Bot, now: number, focus: { [Model]: number }): Memory?
	local root = bot.root
	if not root then
		return nil
	end
	local current = bot.target
	if
		current
		and Perception.engageable(bot, current, now)
		and now - bot.targetSince < BotsConfig.TARGET_STICK
	then
		return current
	end
	local best: Memory? = nil
	local bestScore = -math.huge
	for model, m in bot.memory do
		if not Perception.engageable(bot, m, now) then
			continue
		end
		local distance = (m.lastPos - root.Position).Magnitude
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local share = if humanoid
			then Health.get(humanoid) / math.max(Health.max(humanoid), 1)
			else 1
		local score = 40 / math.max(distance, 4) + (1 - share) * 0.6 + (focus[model] or 0) * 0.3
		if m == current then
			score *= 1.3
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
					and rng:NextNumber() < bot.profile.headChance
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
		if not m.visible and now - m.seenAt <= bot.profile.memory then
			if not best or m.seenAt > best.seenAt then
				best = m
			end
		end
	end
	return best
end

return Perception
