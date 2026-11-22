--!strict
-- AI bots (vault/01 Design/Bots.md). Owns every bot: its seat key for the
-- draft, its owner stand-in (a server-only Configuration holding the
-- attributes and PlayContext a Player would, so the shared movement, Mod and
-- pose simulations drive it like a player: Simulation/Pawns), its R15 rig in
-- Workspace.Dummies, and the loop: a staggered think at Config/Bots
-- THINK_RATE (Bots/Brain) and a cheap act every frame. MatchService asks
-- for bots, spawns them, and counts them for round results.

local Context = require(script.Parent.Parent.Context) -- this match (MatchKit/Context)
local Globals =
	game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local Players = Context.players
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BotsConfig = require(Shared.Config.Bots)
local Combat = require(Shared.Config.Combat)
local Health = require(Shared.Health)
local Locker = require(Shared.Locker)
local MatchBody = require(Shared.MatchBody)
local MatchState = require(script.Parent.Parent.MatchState)
local InputConfig = require(Shared.Config.Input)
local Pawns = require(Shared.Simulation.Pawns)
local SkinPreview = require(Shared.SkinPreview)
local Teams = require(Shared.Mods.Teams)
local Zone = require(script.Parent.Parent.Zone)

local Bots = script.Parent.Parent.Bots
local Aim = require(Bots.Aim)
local BotDraft = require(Bots.BotDraft)
local BotGun = require(Bots.BotGun)
local BotMods = require(Bots.BotMods)
local BotTypes = require(Bots.Types)
local Brain = require(Bots.Brain)
local Nav = require(Bots.Nav)
local Identity = require(Bots.Identity)
local Perception = require(Bots.Perception)
local Tactics = require(Bots.Tactics)

local CharacterService = require(Globals.CharacterService)
local ModWalls = require(script.Parent.ModWalls)
local WeaponService = require(Globals.WeaponService)
local HeldItem = require(Globals.Weapon.HeldItem)

type Bot = BotTypes.Bot

local BotService = {}

local bots: { Bot } = {}
local byKey: { [any]: Bot } = {}
local aligns: { [Bot]: AlignOrientation } = {}
local usedNames: { [string]: boolean } = {}
local rng = Random.new()
-- Owner attributes clients need too, copied onto the bot's model.
local MIRRORED: { [string]: boolean } = {
	ReloadAt = true,
	ReloadFor = true,
	ReloadEmpty = true, -- the reload's kind, for spectators' viewmodel (BotGun.reload)
	ReloadShells = true,
	ModHeld = true,
	ModUseAt = true,
	-- its kit, for the spectator's Mod row (BotMods.setKit)
	Mod1Id = true,
	Mod1Level = true,
	Mod2Id = true,
	Mod2Level = true,
	Mod3Id = true,
	Mod3Level = true,
	AimPitch = true, -- its intended pitch (Target.lookOf, Poses, the replay)
	AimGunYaw = true, -- where its gun points, only while spectated (Bots/Brain publishAim)
	AimGunPitch = true,
	Aiming = true,
}

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
	local wanted = StateValues.get(workspace, "BotDifficulty")
	local name = if RunService:IsStudio() and typeof(wanted) == "string"
		then wanted
		else BotsConfig.DIFFICULTY
	return BotsConfig.PROFILES[name] or BotsConfig.PROFILES[BotsConfig.DIFFICULTY]
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

local nextBotId = 0

local function newBot(team: number): Bot
	local name = Identity.name(usedNames)
	usedNames[name] = true
	local level, skins, starterSkin, device = Identity.profile()
	local owner = Instance.new("Configuration")
	owner.Name = name
	nextBotId += 1
	StateValues.set(owner, "BotId", nextBotId) -- stats key (names are reused)
	StateValues.set(owner, Teams.ATTRIBUTE, team)
	StateValues.set(owner, "ModHeld", 0)
	StateValues.set(owner, "IsBot", true)
	StateValues.set(owner, "Level", level)
	-- Which match this bot plays in (several can run in a lobby server: MatchKit/Context).
	if not Context.ownsServer then
		owner:SetAttribute("MatchId", Context.id)
	end
	local seatsParent = MatchState.seatsParent()
	local folder = seatsParent:FindFirstChild(MatchState.BOT_SEATS)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = MatchState.BOT_SEATS
		folder.Parent = seatsParent
	end
	local seat = Instance.new("Configuration")
	seat.Name = name
	StateValues.set(seat, "BotId", nextBotId)
	StateValues.set(seat, "Level", level)
	StateValues.set(seat, "Device", device)
	StateValues.set(seat, Teams.ATTRIBUTE, team)
	seat.Parent = folder
	local inputs = buildInputs(owner)
	owner.Parent = ownerFolder()
	local bot: Bot = {
		key = table.freeze({ name = name }),
		name = name,
		team = team,
		profile = profile(),
		avatar = nil,
		avatarPending = true,
		seat = seat,
		portraitUserId = nil,
		skins = skins,
		starterSkin = starterSkin,
		owner = owner,
		inputs = inputs,
		model = nil,
		humanoid = nil,
		root = nil,
		head = nil,
		life = 0,
		fighting = false,
		postRound = false,
		idleUntil = 0,
		gun = BotGun.new(),
		loadout = {},
		memory = {},
		sightCursor = 0,
		target = nil,
		targetSince = 0,
		goal = "Roam",
		goalSince = 0,
		openingLane = nil,
		openingStyle = "Controller",
		openingOffset = Vector3.zero,
		nextThink = 0,
		strafeDir = 0,
		strafeUntil = 0,
		crouchUntil = 0,
		moveDir = Vector3.zero,
		steerInput = Vector3.zero,
		wantSprint = false,
		wantCrouch = false,
		lookAt = nil,
		roamGoal = nil,
		lastRoam = nil,
		roamBlocked = {},
		coverGoal = nil,
		peekGoal = nil,
		coverAt = 0,
		coverUntil = 0,
		peekUntil = 0,
		zone = nil,
		slideCheckAt = 0,
		yaw = 0,
		pitch = 0,
		yawVel = 0,
		pitchVel = 0,
		aimError = Vector2.zero,
		aimWobble = Vector2.zero,
		recoil = Vector2.zero,
		triggerAt = 0,
		missLeft = 0,
		burstLeft = 4,
		burstRestUntil = 0,
		kit = { "", "", "" },
		levels = { "", "", "" },
		modReadyAt = { 0, 0, 0 },
		modCharges = { 0, 0, 0 },
		modRetryAt = { 0, 0, 0 },
		nextModTry = 0,
		lastHurtAt = -math.huge,
		lastHealth = 0,
		nav = Nav.new(),
		connections = {},
	}
	return bot
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
	BotMods.clear(bot, bot.model)
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
	if bot.avatar then
		bot.avatar:Destroy()
	end
	usedNames[bot.name] = nil
	byKey[bot.key] = nil
	aligns[bot] = nil
	bot.seat:Destroy()
	bot.owner:Destroy()
	local i = table.find(bots, bot)
	if i then
		table.remove(bots, i)
	end
end

local function prepareAvatar(bot: Bot)
	local base, appearance, portraitUserId = Identity.avatar(bot.name, function()
		return byKey[bot.key] == bot
	end)
	bot.avatarPending = false
	if not byKey[bot.key] then
		if base then
			base:Destroy()
		end
		return
	end
	bot.avatar = base
	bot.portraitUserId = portraitUserId
	StateValues.set(bot.seat, "PortraitUserId", portraitUserId)
	if RunService:IsStudio() then
		StateValues.set(bot.owner, "AvatarSource", appearance)
		local ready, attempts, pending = Identity.poolStatus()
		StateValues.set(bot.owner, "AvatarPoolReady", ready)
		StateValues.set(bot.owner, "AvatarPoolAttempts", attempts)
		StateValues.set(bot.owner, "AvatarPoolPending", pending)
	end
end

-- Spawns (or respawns) a bot at `at`, guns from its loadout.
local function spawnBot(bot: Bot, at: CFrame)
	dropLife(bot)
	local life = bot.life
	while bot.avatarPending and bot.life == life and byKey[bot.key] do
		task.wait()
	end
	if bot.life ~= life or not byKey[bot.key] then
		return
	end
	local base = bot.avatar
	if not base then
		warn("[BotService] Could not build a bot avatar")
		return
	end
	local model = base:Clone()
	model.Name = bot.name
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	StateValues.set(model, Teams.ATTRIBUTE, bot.team)
	StateValues.set(model, "IsBot", true)
	StateValues.set(model, "BotId", StateValues.get(bot.owner, "BotId"))
	StateValues.set(model, "Level", StateValues.get(bot.owner, "Level"))
	StateValues.set(model, "Device", StateValues.get(bot.seat, "Device"))
	StateValues.set(model, "PortraitUserId", bot.portraitUserId)
	Locker.publish(model, bot.skins, SkinPreview.BOT_LOCKER)
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
	humanoid.DisplayName = bot.name
	humanoid.AutoRotate = false
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	-- States a bot never needs (LihFolk Physics Performance: cheaper
	-- humanoids, and no tripping into FallingDown mid-fight).
	for _, state in
		{
			Enum.HumanoidStateType.Climbing,
			Enum.HumanoidStateType.Seated,
			Enum.HumanoidStateType.FallingDown,
			Enum.HumanoidStateType.Ragdoll,
			Enum.HumanoidStateType.Flying,
		}
	do
		humanoid:SetStateEnabled(state, false)
	end
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

	if not Context.ownsServer then
		model:SetAttribute("MatchId", Context.id)
	end
	model.Parent = dummyFolder()
	-- The block body, this bot's own (its skinned limbs live in
	-- Workspace.GGBodyLimbs and go with its parts).
	MatchBody.dress(model)
	pcall(function()
		root:SetNetworkOwner(nil) -- the server simulates bots
	end)
	CharacterService.prepare(model)
	CharacterService.useOurAnimations(model)
	bot.model, bot.humanoid, bot.root, bot.head = model, humanoid, root, head
	bot.lastHealth = Health.get(humanoid)
	bot.aimError, bot.recoil = Vector2.zero, Vector2.zero
	bot.goal, bot.goalSince = "Roam", 0
	bot.sightCursor, bot.steerInput = 0, Vector3.zero
	bot.moveDir = Vector3.zero
	bot.lookAt = nil
	bot.wantSprint, bot.wantCrouch = false, false
	bot.strafeUntil, bot.crouchUntil = 0, 0
	bot.roamGoal = nil
	bot.lastRoam = nil
	table.clear(bot.roamBlocked)
	bot.coverGoal, bot.peekGoal = nil, nil
	bot.coverAt, bot.coverUntil, bot.peekUntil = 0, 0, 0
	bot.zone, bot.slideCheckAt = nil, 0
	Nav.updateFilter(bot)
	bot.nextThink = os.clock() + rng:NextNumber() / BotsConfig.THINK_RATE
	Pawns.add(bot.owner, model)

	-- The owner lives in ServerStorage; clients read these off the model
	-- (lane D's GripController lets go of the gun during reloads and Mods).
	for name in MIRRORED do
		StateValues.set(model, name, StateValues.get(bot.owner, name))
	end
	table.insert(
		bot.connections,
		StateValues.anyChanged(bot.owner):Connect(function(name: string)
			if MIRRORED[name] then
				StateValues.set(model, name, StateValues.get(bot.owner, name))
			end
			-- Like a player's (ModService): the Mod comes out in its right
			-- hand in third person and the gun goes away while it's held.
			if name == "ModHeld" and model.Parent then
				local slot = StateValues.get(bot.owner, "ModHeld")
				local id = if typeof(slot) == "number" and slot ~= 0 then bot.kit[slot] else nil
				local shown = HeldItem.show(model, if id and id ~= "" then id else nil)
				WeaponService.setCharacterGunHidden(model, shown)
			end
		end)
	)

	-- Hurt: the flinch others see (Poses: HitAt) and the brain's "under fire".
	local changed = Health.changed(humanoid)
	if changed then
		table.insert(
			bot.connections,
			changed:Connect(function()
				local h = Health.get(humanoid)
				if h < bot.lastHealth then
					bot.lastHurtAt = os.clock()
					StateValues.set(bot.owner, "HitAt", workspace:GetServerTimeNow())
					Aim.disturb(bot, 0.25)
				end
				bot.lastHealth = h
			end)
		)
	end
	local downed = Health.onDowned(humanoid, function()
		Pawns.remove(model)
		ModWalls.stop(model)
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

-- Roam targets per team and the patrol points (BotService.setRoamPoints).
local roamPoints: { [number]: Vector3 } = {}
local patrol: { Vector3 } = {}

local function worldFor(bot: Bot): Brain.World
	local zone = Zone.read()
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
			local t = StateValues.get(model, Teams.ATTRIBUTE)
			if model ~= bot.model and model:IsA("Model") and typeof(t) == "number" then
				if Health.isAlive(model:FindFirstChildOfClass("Humanoid")) then
					table.insert(if t ~= bot.team then enemyScratch else allyScratch, model)
				end
			end
		end
	end
	for _, other in bots do
		if
			other ~= bot
			and other.team == bot.team
			and other.fighting
			and other.target
			and other.target.visible
			and Health.isAlive(other.humanoid)
		then
			focusScratch[other.target.model] = (focusScratch[other.target.model] or 0) + 1
		end
	end
	return {
		enemies = enemyScratch,
		allies = allyScratch,
		focus = focusScratch,
		roam = BotService.roamPoint(bot.team),
		patrol = patrol,
		zone = zone,
	}
end

-- Where a bot with no information heads: the enemy side (set by
-- MatchService per map), else the middle of the map.
function BotService.setRoamPoints(forTeam1: Vector3?, forTeam2: Vector3?)
	table.clear(roamPoints)
	table.clear(patrol)
	if forTeam1 then
		roamPoints[1] = forTeam1
		table.insert(patrol, forTeam1)
	end
	if forTeam2 then
		roamPoints[2] = forTeam2
		table.insert(patrol, forTeam2)
	end
	-- The middle and both flanks between the two ends.
	if forTeam1 and forTeam2 then
		local mid = (forTeam1 + forTeam2) / 2
		local axis = (forTeam1 - forTeam2) * Vector3.new(1, 0, 1)
		local side = Vector3.new(-axis.Z, 0, axis.X) * 0.3
		table.insert(patrol, mid)
		table.insert(patrol, mid + side)
		table.insert(patrol, mid - side)
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

-- Cost of the bots on the server (LihFolk: Script Performance, MicroProfiler
-- Guide): MicroProfiler labels on think and act, and in Studio a rolling
-- average / worst step in ms on ServerStorage.BotOwners (StepMsAvg,
-- StepMsMax), with a warning when the average goes over BUDGET_MS.
local STUDIO = RunService:IsStudio()
local statFrames, statSum, statMax, budgetWarned = 0, 0, 0, false

-- Studio only: with the Workspace attribute BotDebug on, a label over each
-- bot shows its goal, target, health and hits/shots (LihFolk: Visual AI
-- Debugging - State Labels, Path Lines and Perception Gizmos).
local function debugLabel(bot: Bot)
	local head = bot.head
	if not head then
		return
	end
	local gui = head:FindFirstChild("BotDebug")
	if StateValues.get(workspace, "BotDebug") ~= true then
		if gui then
			gui:Destroy()
		end
		return
	end
	local text: TextLabel
	if gui and gui:IsA("BillboardGui") then
		text = gui:FindFirstChildOfClass("TextLabel") :: TextLabel
	else
		local board = Instance.new("BillboardGui")
		board.Name = "BotDebug"
		board.Size = UDim2.fromOffset(220, 40)
		board.StudsOffset = Vector3.new(0, 2.6, 0)
		board.AlwaysOnTop = true
		board.LightInfluence = 0
		text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.TextColor3 = Color3.new(1, 1, 1)
		text.TextStrokeTransparency = 0.3
		text.Font = Enum.Font.Code
		text.TextScaled = true
		text.Parent = board
		board.Parent = head
	end
	if not text then
		return
	end
	local o = bot.owner
	text.Text = string.format(
		"%s %s>%s\nhp %d  %s/%s",
		bot.name,
		bot.goal,
		if bot.target then bot.target.model.Name else "-",
		math.floor(Brain.healthShare(bot) * 100),
		tostring(StateValues.get(o, "BotHits") or 0),
		tostring(StateValues.get(o, "BotShots") or 0)
	)
end

local function step(dt: number)
	local started = os.clock()
	local now = started
	for _, bot in bots do
		local model = bot.model
		if not model or not model.Parent then
			continue
		end
		if now >= bot.nextThink then
			bot.nextThink = now + 1 / BotsConfig.THINK_RATE
			debug.profilebegin("BotThink")
			Brain.think(bot, worldFor(bot), now)
			debug.profileend()
			if STUDIO then
				debugLabel(bot)
			end
		end
		debug.profilebegin("BotAct")
		local fired = Brain.act(bot, dt, aligns[bot])
		debug.profileend()
		if fired then
			local head = bot.head
			if head then
				hearShot(model, head.Position)
			end
		end
	end
	if STUDIO and #bots > 0 then
		local ms = (os.clock() - started) * 1000
		statFrames += 1
		statSum += ms
		statMax = math.max(statMax, ms)
		if statFrames >= 120 then
			local avg = statSum / statFrames
			local folder = ownerFolder()
			StateValues.set(folder, "StepMsAvg", math.round(avg * 1000) / 1000)
			StateValues.set(folder, "StepMsMax", math.round(statMax * 1000) / 1000)
			StateValues.set(folder, "BotCount", #bots)
			if avg > BotsConfig.BUDGET_MS and not budgetWarned then
				budgetWarned = true
				warn(
					string.format(
						"[BotService] %d bots average %.2f ms per step (budget %.2f)",
						#bots,
						avg,
						BotsConfig.BUDGET_MS
					)
				)
			end
			statFrames, statSum, statMax = 0, 0, 0
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
		task.spawn(prepareAvatar, bot)
	end
	return keys
end

-- Spawns one bot at `at` (a bot that took a leaver's seat mid-select).
function BotService.spawnOne(key: any, at: CFrame)
	local bot = byKey[key]
	if bot then
		local taken = {}
		for _, other in bots do
			if other ~= bot and other.team == bot.team and other.openingLane then
				taken[other.openingLane] = true
			end
		end
		Tactics.assignOpening(bot, taken)
		task.spawn(spawnBot, bot, at)
	end
end

-- Takes one bot out (a late player took its seat).
function BotService.remove(key: any)
	local bot = byKey[key]
	if bot then
		removeBot(bot)
	end
end

function BotService.clear()
	for i = #bots, 1, -1 do
		removeBot(bots[i])
	end
	Identity.releaseLooks()
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

-- A bot's Mod row for its spectators (ModService.snapshot's shape), by model.
function BotService.modsOf(model: Model): { { [string]: any } }
	local out: { { [string]: any } } = {}
	for _, bot in bots do
		if bot.model == model then
			for slot, id in bot.kit do
				out[slot] = {
					id = if id ~= "" then id else nil,
					level = bot.levels[slot] or "L1",
					charges = bot.modCharges[slot] or 0,
					rechargeAt = bot.modReadyAt[slot],
				}
			end
			break
		end
	end
	return out
end

function BotService.modelOf(key: any): Model?
	local bot = byKey[key]
	return bot and bot.model
end

-- Spawns every bot on `team` on the spawns given, from `startIndex` on
-- (players take the first ones).
function BotService.spawnTeam(team: number, spawns: { SpawnLocation }, startIndex: number)
	local i = startIndex
	local taken = {}
	for _, bot in bots do
		if bot.team == team then
			local spot = spawns[(i - 1) % math.max(#spawns, 1) + 1]
			i += 1
			if spot then
				Tactics.assignOpening(bot, taken)
				if STUDIO then
					StateValues.set(bot.owner, "OpeningStyle", bot.openingStyle)
					StateValues.set(bot.owner, "OpeningLane", bot.openingLane)
				end
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
			local shield = StateValues.get(humanoid, Combat.SHIELD_ATTRIBUTE)
			health += Health.get(humanoid) + (if typeof(shield) == "number" then shield else 0)
		end
	end
	return alive, health
end

function BotService.isAlive(key: any): boolean
	local bot = byKey[key]
	return bot ~= nil and Health.isAlive(bot.humanoid)
end

-- Only fights during live rounds. Survivors can move during RoundEnd.
function BotService.setFighting(on: boolean, postRound: boolean?)
	for _, bot in bots do
		bot.fighting = on
		bot.postRound = postRound == true
		if not on then
			bot.target = nil
			bot.zone = nil
			bot.idleUntil = 0
			Nav.clear(bot.nav)
		end
	end
end

-- The draft: picks from the seat's offers (DraftService's seat table).
function BotService.draft(key: any, seat: BotDraft.SeatView)
	local bot = byKey[key]
	BotDraft.pick(seat, if bot then bot.profile.tactics.aggression else 0.5, rng)
end

-- What the draft decided: guns and Mods, applied at the next spawn (and now
-- when alive).
function BotService.applyDraft(
	key: any,
	loadout: { [any]: string },
	kit: { string },
	levels: { string },
	drafted: boolean?
)
	local bot = byKey[key]
	if not bot then
		return
	end
	bot.loadout = loadout
	local sidearm = loadout.Secondary
	if drafted and bot.starterSkin and typeof(sidearm) == "string" then
		bot.starterSkin = false
		local line = Identity.starterSkin(sidearm)
		if line then
			bot.skins[sidearm] = line
			if bot.model then
				Locker.publish(bot.model, bot.skins, SkinPreview.BOT_LOCKER)
			end
		end
	end
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
		StateValues.set(humanoid, Combat.SHIELD_ATTRIBUTE, amount)
	end
end

function BotService.refillCharges()
	for _, bot in bots do
		BotMods.refill(bot)
	end
end

-- Config/Bots is consistent (LihFolk system builder: assert config at
-- startup). A bad edit fails loudly here, not as odd behaviour mid-match.
local function checkConfig()
	assert(BotsConfig.PROFILES[BotsConfig.DIFFICULTY], "Config/Bots DIFFICULTY names no profile")
	for name, level in BotsConfig.PROFILES do
		for category, knobs in level :: any do
			for field, value in knobs do
				assert(
					typeof(value) == "number" and value < math.huge and value >= 0,
					`Config/Bots {name}.{category}.{field} must be finite and >= 0`
				)
			end
		end
		local aim = level.aim
		assert(
			aim.aimSmooth > 0 and aim.errorSettle > 0 and aim.errorFloor <= aim.errorStart,
			`Config/Bots {name}.aim has invalid settling or error bounds`
		)
		local probabilities = {
			headChance = aim.headChance,
			recoilControl = aim.recoilControl,
			abilityUse = level.mods.abilityUse,
			minScore = level.mods.minScore,
			flankChance = level.tactics.flankChance,
			aggression = level.tactics.aggression,
			strafePause = level.movement.strafePause,
			slideChance = level.movement.slideChance,
			slideJumpChance = level.movement.slideJumpChance,
		}
		for field, value in probabilities do
			assert(value <= 1, `Config/Bots {name}.{field} must be between 0 and 1`)
		end
		assert(level.mods.interval > 0, `Config/Bots {name}.mods.interval must be positive`)
		assert(level.perception.fov <= 360, `Config/Bots {name}.perception.fov exceeds 360°`)
	end
	for _, class in { "Sidearm", "SMG", "Shotgun", "Rifle", "Sniper", "MachineGun", "Melee" } do
		local band = BotsConfig.RANGE[class]
		assert(band and band[1] <= band[2], `Config/Bots RANGE.{class} missing or reversed`)
	end
	assert(
		BotsConfig.THINK_RATE > 0 and BotsConfig.THINK_RATE <= 30,
		"Config/Bots THINK_RATE out of range"
	)
end

function BotService.init()
	checkConfig()
end

function BotService.start()
	Players.PlayerAdded:Connect(Identity.collect)
	for _, player in Players:GetPlayers() do
		Identity.collect(player)
	end
	Identity.prefetch()
	WeaponService.onShot(Context.filtered(1, function(player: Player)
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		if character and head and head:IsA("BasePart") then
			hearShot(character, head.Position)
		end
	end))
	RunService.Heartbeat:Connect(step)
	-- A teammate's Recon: every bot on that team learns where they are.
	BotMods.setRevealListener(function(team: number, targets: { Model })
		local now = os.clock()
		for _, bot in bots do
			if bot.team == team and bot.model then
				for _, model in targets do
					local root = model:FindFirstChild("HumanoidRootPart")
					if root and root:IsA("BasePart") then
						Perception.reveal(bot, model, root.Position, now)
					end
				end
			end
		end
	end)
end

return BotService
