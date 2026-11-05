--!strict
-- AI bots (vault/01 Design/Bots.md). Owns every bot: its seat key for the
-- draft, its owner stand-in (a server-only Configuration holding the
-- attributes and PlayContext a Player would, so the shared movement, Mod and
-- pose simulations drive it like a player: Simulation/Pawns), its R15 rig in
-- Workspace.Dummies, and the loop: a staggered think at Config/Bots
-- THINK_RATE (Bots/Brain) and a cheap act every frame. MatchService asks
-- for bots, spawns them, and counts them for round results.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BotsConfig = require(Shared.Config.Bots)
local Combat = require(Shared.Config.Combat)
local Health = require(Shared.Health)
local InputConfig = require(Shared.Config.Input)
local Pawns = require(Shared.Simulation.Pawns)
local Teams = require(Shared.Mods.Teams)

local Bots = script.Parent.Parent.Bots
local Aim = require(Bots.Aim)
local BotDraft = require(Bots.BotDraft)
local BotGun = require(Bots.BotGun)
local BotMods = require(Bots.BotMods)
local BotTypes = require(Bots.Types)
local Brain = require(Bots.Brain)
local Nav = require(Bots.Nav)
local Perception = require(Bots.Perception)

local CharacterService = require(script.Parent.CharacterService)
local WeaponService = require(script.Parent.WeaponService)

type Bot = BotTypes.Bot

local BotService = {}

local bots: { Bot } = {}
local byKey: { [any]: Bot } = {}
local aligns: { [Bot]: AlignOrientation } = {}
local templates: { [number]: Model } = {}
local usedNames: { [string]: boolean } = {}
local rng = Random.new()

-- Per-think scratch, reused (no allocations per frame).
local enemyScratch: { Model } = {}
local allyScratch: { Model } = {}
local focusScratch: { [Model]: number } = {}

local function dummyFolder(): Instance
	local folder = workspace:FindFirstChild("Dummies")
	if folder then
		return folder
	end
	-- WeaponService's wall checks skip Workspace.Dummies (bodies aren't walls),
	-- and clients treat what's in it as combatants.
	local made = Instance.new("Folder")
	made.Name = "Dummies"
	made.Parent = workspace
	return made
end

local function ownerFolder(): Instance
	local folder = ServerStorage:FindFirstChild("BotOwners")
	if folder then
		return folder
	end
	local made = Instance.new("Folder")
	made.Name = "BotOwners"
	made.Parent = ServerStorage
	return made
end

local function profile(): BotsConfig.Profile
	local wanted = workspace:GetAttribute("BotDifficulty")
	local name = if RunService:IsStudio() and typeof(wanted) == "string"
		then wanted
		else BotsConfig.DIFFICULTY
	return BotsConfig.PROFILES[name] or BotsConfig.PROFILES.Normal
end

local function pickName(): string
	local free: { string } = {}
	for _, n in BotsConfig.NAMES do
		if not usedNames[n] then
			table.insert(free, n)
		end
	end
	local name = if #free > 0 then free[rng:NextInteger(1, #free)] else "Bot" .. tostring(#bots + 1)
	usedNames[name] = true
	return name
end

-- The owner's PlayContext: the same actions a player's has (Config/Input),
-- driven by the brain through InputAction:Fire.
local function buildInputs(owner: Instance): { [string]: InputAction }
	local ctx = Instance.new("InputContext")
	ctx.Name = "PlayContext"
	local inputs: { [string]: InputAction } = {}
	for name, b in InputConfig do
		local action = Instance.new("InputAction")
		action.Name = name
		action.Type = if b.kind == "Direction1D"
			then Enum.InputActionType.Direction1D
			else Enum.InputActionType.Bool
		action.Parent = ctx
		inputs[name] = action
	end
	ctx.Parent = owner
	return inputs
end

local function newBot(team: number): Bot
	local name = pickName()
	local owner = Instance.new("Configuration")
	owner.Name = name
	owner:SetAttribute(Teams.ATTRIBUTE, team)
	owner:SetAttribute("ModHeld", 0)
	owner:SetAttribute("IsBot", true)
	local inputs = buildInputs(owner)
	owner.Parent = ownerFolder()
	local bot: Bot = {
		key = table.freeze({ name = name }),
		name = name,
		team = team,
		profile = profile(),
		owner = owner,
		inputs = inputs,
		model = nil,
		humanoid = nil,
		root = nil,
		head = nil,
		life = 0,
		fighting = false,
		gun = BotGun.new(),
		loadout = {},
		memory = {},
		target = nil,
		targetSince = 0,
		goal = "Roam",
		goalSince = 0,
		nextThink = 0,
		strafeDir = 0,
		strafeUntil = 0,
		crouchUntil = 0,
		moveDir = Vector3.zero,
		wantSprint = false,
		wantCrouch = false,
		lookAt = nil,
		yaw = 0,
		pitch = 0,
		yawVel = 0,
		pitchVel = 0,
		aimError = Vector2.zero,
		aimWobble = Vector2.zero,
		recoil = Vector2.zero,
		triggerAt = 0,
		burstLeft = 4,
		burstRestUntil = 0,
		kit = { "", "", "" },
		levels = { "", "", "" },
		modReadyAt = { 0, 0, 0 },
		modCharges = { 0, 0, 0 },
		nextModTry = 0,
		lastHurtAt = -math.huge,
		lastHealth = 0,
		nav = Nav.new(),
		connections = {},
	}
	return bot
end

-- A rig per team colour, built once (CreateHumanoidModelFromDescription
-- yields), then cloned for every spawn.
local function template(team: number): Model?
	local cached = templates[team]
	if cached then
		return cached
	end
	local desc = Instance.new("HumanoidDescription")
	local cloth = BotsConfig.TEAM_CLOTH[team] or BotsConfig.TEAM_CLOTH[1]
	desc.HeadColor = BotsConfig.SKIN
	desc.LeftArmColor = BotsConfig.SKIN
	desc.RightArmColor = BotsConfig.SKIN
	desc.TorsoColor = cloth
	desc.LeftLegColor = cloth:Lerp(Color3.new(0, 0, 0), 0.35)
	desc.RightLegColor = cloth:Lerp(Color3.new(0, 0, 0), 0.35)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[BotService] couldn't build a bot rig:", model)
		return nil
	end
	templates[team] = model
	return model
end

local function dropLife(bot: Bot)
	bot.life += 1
	for _, c in bot.connections do
		c:Disconnect()
	end
	table.clear(bot.connections)
	local align = aligns[bot]
	if align then
		align:Destroy()
		aligns[bot] = nil
	end
	if bot.model then
		Pawns.remove(bot.model)
		bot.model:Destroy()
	end
	bot.model, bot.humanoid, bot.root, bot.head = nil, nil, nil, nil
	bot.target = nil
	table.clear(bot.memory)
	Nav.clear(bot.nav)
	for _, action in bot.inputs do
		if action.Type == Enum.InputActionType.Bool then
			if action:GetState() == true then
				action:Fire(false)
			end
		elseif action:GetState() ~= 0 then
			action:Fire(0)
		end
	end
end

local function removeBot(bot: Bot)
	dropLife(bot)
	usedNames[bot.name] = nil
	byKey[bot.key] = nil
	aligns[bot] = nil
	bot.owner:Destroy()
	local i = table.find(bots, bot)
	if i then
		table.remove(bots, i)
	end
end

-- Spawns (or respawns) a bot at `at`, guns from its loadout.
local function spawnBot(bot: Bot, at: CFrame)
	dropLife(bot)
	local life = bot.life
	local base = template(bot.team)
	if not base or bot.life ~= life or not byKey[bot.key] then
		return
	end
	local model = base:Clone()
	model.Name = bot.name
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute(Teams.ATTRIBUTE, bot.team)
	model:SetAttribute("IsBot", true)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	local head = model:FindFirstChild("Head")
	if
		not humanoid
		or not root
		or not root:IsA("BasePart")
		or not head
		or not head:IsA("BasePart")
	then
		model:Destroy()
		return
	end
	humanoid.AutoRotate = false
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	model:PivotTo(at + Vector3.new(0, 3, 0))
	local _, yaw = at:ToOrientation()
	bot.yaw, bot.pitch, bot.yawVel, bot.pitchVel = yaw, 0, 0, 0
	-- Turning: an AlignOrientation on yaw (physics-friendly, unlike setting CFrame).
	local attachment = Instance.new("Attachment")
	attachment.Name = "BotAim"
	attachment.Parent = root
	local align = Instance.new("AlignOrientation")
	align.Name = "BotAim"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.Responsiveness = 60
	align.MaxTorque = math.huge
	align.CFrame = CFrame.Angles(0, yaw, 0)
	align.Parent = root
	aligns[bot] = align

	model.Parent = dummyFolder()
	pcall(function()
		root:SetNetworkOwner(nil) -- the server simulates bots
	end)
	CharacterService.prepare(model)
	CharacterService.useOurAnimations(model)
	bot.model, bot.humanoid, bot.root, bot.head = model, humanoid, root, head
	bot.lastHealth = Health.get(humanoid)
	bot.aimError, bot.recoil = Vector2.zero, Vector2.zero
	bot.goal, bot.goalSince = "Roam", 0
	bot.nextThink = os.clock() + rng:NextNumber() / BotsConfig.THINK_RATE
	Pawns.add(bot.owner, model)

	-- Hurt: the flinch others see (Poses: HitAt) and the brain's "under fire".
	local changed = Health.changed(humanoid)
	if changed then
		table.insert(
			bot.connections,
			changed:Connect(function()
				local h = Health.get(humanoid)
				if h < bot.lastHealth then
					bot.lastHurtAt = os.clock()
					bot.owner:SetAttribute("HitAt", workspace:GetServerTimeNow())
					Aim.disturb(bot, 0.25)
				end
				bot.lastHealth = h
			end)
		)
	end
	local downed = Health.onDowned(humanoid, function()
		Pawns.remove(model)
		humanoid:Move(Vector3.zero, false)
		local a = aligns[bot]
		if a then
			a.Enabled = false
		end
	end)
	if downed then
		table.insert(bot.connections, downed)
	end

	BotGun.setLoadout(bot.gun, bot.loadout :: any)
	task.defer(function()
		if bot.life == life and model.Parent then
			BotGun.equip(
				bot.gun,
				model,
				bot.owner,
				if bot.gun.slots.Primary then "Primary" else "Secondary"
			)
		end
	end)
	BotMods.onSpawn(bot)
end

-- The loop ----------------------------------------------------------------------

local function worldFor(bot: Bot): Brain.World
	table.clear(enemyScratch)
	table.clear(allyScratch)
	table.clear(focusScratch)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local t = Teams.of(player)
		if character and t and Health.isAlive(character:FindFirstChildOfClass("Humanoid")) then
			if t ~= bot.team then
				table.insert(enemyScratch, character)
			else
				table.insert(allyScratch, character)
			end
		end
	end
	local folder = workspace:FindFirstChild("Dummies")
	if folder then
		for _, model in folder:GetChildren() do
			local t = model:GetAttribute(Teams.ATTRIBUTE)
			if model ~= bot.model and model:IsA("Model") and typeof(t) == "number" then
				if Health.isAlive(model:FindFirstChildOfClass("Humanoid")) then
					table.insert(if t ~= bot.team then enemyScratch else allyScratch, model)
				end
			end
		end
	end
	local lane = 0
	local index = 0
	for _, other in bots do
		if other.team == bot.team then
			index += 1
			if other == bot then
				lane = if index == 1 then 0 elseif index % 2 == 0 then 1 else -1
			elseif other.target then
				focusScratch[other.target.model] = (focusScratch[other.target.model] or 0) + 1
			end
		end
	end
	return {
		enemies = enemyScratch,
		allies = allyScratch,
		focus = focusScratch,
		roam = BotService.roamPoint(bot.team),
		lane = lane,
	}
end

-- Where a bot with no information heads: the enemy side (set by
-- MatchService per map), else the middle of the map.
local roamPoints: { [number]: Vector3 } = {}
function BotService.setRoamPoints(forTeam1: Vector3?, forTeam2: Vector3?)
	table.clear(roamPoints)
	if forTeam1 then
		roamPoints[1] = forTeam1
	end
	if forTeam2 then
		roamPoints[2] = forTeam2
	end
end

function BotService.roamPoint(team: number): Vector3?
	return roamPoints[team]
end

local function hearShot(shooter: Model, at: Vector3)
	local now = os.clock()
	for _, bot in bots do
		if
			bot.model
			and bot.model ~= shooter
			and bot.fighting
			and Teams.of(shooter) ~= bot.team
		then
			Perception.hear(bot, shooter, at, now)
		end
	end
end

local function step(dt: number)
	local now = os.clock()
	for _, bot in bots do
		local model = bot.model
		if not model or not model.Parent then
			continue
		end
		if now >= bot.nextThink then
			bot.nextThink = now + 1 / BotsConfig.THINK_RATE
			Brain.think(bot, worldFor(bot), now)
		end
		if Brain.act(bot, dt, aligns[bot]) then
			local head = bot.head
			if head then
				hearShot(model, head.Position)
			end
		end
	end
end

-- The match's API -----------------------------------------------------------------

-- Adds `count` bots to `team`. Returns their keys.
function BotService.add(team: number, count: number): { any }
	local keys = {}
	for _ = 1, count do
		local bot = newBot(team)
		table.insert(bots, bot)
		byKey[bot.key] = bot
		table.insert(keys, bot.key)
	end
	return keys
end

function BotService.clear()
	for i = #bots, 1, -1 do
		removeBot(bots[i])
	end
end

function BotService.keys(): { any }
	local keys = {}
	for _, bot in bots do
		table.insert(keys, bot.key)
	end
	return keys
end

function BotService.isBot(key: any): boolean
	return byKey[key] ~= nil
end

function BotService.teamOf(key: any): number?
	local bot = byKey[key]
	return bot and bot.team
end

function BotService.count(team: number): number
	local n = 0
	for _, bot in bots do
		if bot.team == team then
			n += 1
		end
	end
	return n
end

function BotService.modelOf(key: any): Model?
	local bot = byKey[key]
	return bot and bot.model
end

-- Spawns every bot on `team` on the spawns given, from `startIndex` on
-- (players take the first ones).
function BotService.spawnTeam(team: number, spawns: { SpawnLocation }, startIndex: number)
	local i = startIndex
	for _, bot in bots do
		if bot.team == team then
			local spot = spawns[(i - 1) % math.max(#spawns, 1) + 1]
			i += 1
			if spot then
				task.spawn(spawnBot, bot, spot.CFrame)
			end
		end
	end
end

-- Alive count and health + shield on `team` (round results).
function BotService.teamState(team: number): (number, number)
	local alive, health = 0, 0
	for _, bot in bots do
		local humanoid = bot.humanoid
		if bot.team == team and humanoid and Health.isAlive(humanoid) then
			alive += 1
			local shield = humanoid:GetAttribute(Combat.SHIELD_ATTRIBUTE)
			health += Health.get(humanoid) + (if typeof(shield) == "number" then shield else 0)
		end
	end
	return alive, health
end

function BotService.isAlive(key: any): boolean
	local bot = byKey[key]
	return bot ~= nil and Health.isAlive(bot.humanoid)
end

-- Only moves and shoots while the round is live.
function BotService.setFighting(on: boolean)
	for _, bot in bots do
		bot.fighting = on
		if not on then
			bot.target = nil
			Nav.clear(bot.nav)
		end
	end
end

-- The draft: picks from the seat's offers (DraftService's seat table).
function BotService.draft(key: any, seat: BotDraft.SeatView)
	local bot = byKey[key]
	BotDraft.pick(seat, if bot then bot.profile.aggression else 0.5, rng)
end

-- What the draft decided: guns and Mods, applied at the next spawn (and now
-- when alive).
function BotService.applyDraft(
	key: any,
	loadout: { [any]: string },
	kit: { string },
	levels: { string }
)
	local bot = byKey[key]
	if not bot then
		return
	end
	bot.loadout = loadout
	BotMods.setKit(bot, kit, levels)
	local model = bot.model
	if model and Health.isAlive(bot.humanoid) then
		BotGun.setLoadout(bot.gun, loadout :: any)
		BotGun.equip(
			bot.gun,
			model,
			bot.owner,
			if bot.gun.slots.Primary then "Primary" else "Secondary"
		)
	end
end

function BotService.giveShield(key: any, amount: number)
	local bot = byKey[key]
	local humanoid = bot and bot.humanoid
	if humanoid then
		humanoid:SetAttribute(Combat.SHIELD_ATTRIBUTE, amount)
	end
end

function BotService.refillCharges()
	for _, bot in bots do
		BotMods.refill(bot)
	end
end

function BotService.start()
	WeaponService.onShot(function(player: Player)
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		if character and head and head:IsA("BasePart") then
			hearShot(character, head.Position)
		end
	end)
	RunService.Heartbeat:Connect(step)
end

return BotService
