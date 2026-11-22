--!strict
-- Prepares every combatant (player characters and test dummies): the standard
-- match body (shared/MatchBody: same parts and scales for everyone, drawn as blocks,
-- vault/01 Design/Match Avatar.md), full health with no natural regen (the
-- game's own HP, HealthService: nobody truly dies), standard jump, hats that
-- bullets ignore, hitbox history. In test mode (characters auto-load) a
-- downed player comes back after RESPAWN_TIME.

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animations = require(ReplicatedStorage.Shared.Config.Animations)
local Collision = require(ReplicatedStorage.Shared.Config.Collision)
local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Health = require(ReplicatedStorage.Shared.Health)
local MatchBody = require(ReplicatedStorage.Shared.MatchBody)
local Avatar = require(ReplicatedStorage.Shared.Config.Avatar)
local Movement = require(ReplicatedStorage.Shared.Config.Movement)
local PlayZone = require(ReplicatedStorage.Shared.PlayZone)
local ServerRole = require(ReplicatedStorage.Shared.ServerRole)
local SimulationFields = require(ReplicatedStorage.Shared.Simulation.Fields)
local HealthLog = require(ReplicatedStorage.Shared.HealthLog)
local HitboxHistory = require(script.Parent.HitboxHistory)
local HealthService = require(script.Parent.HealthService)

local CharacterService = {}

-- Each player's own avatar description (only what Config/Avatar keeps is
-- copied from it), fetched once by userId on join. false = the fetch failed.
local ownDescriptions: { [Player]: HumanoidDescription | false } = {}
-- Characters spawned already wearing the standard body (loadCharacter).
local spawnedStandard: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function fetchOwn(player: Player)
	local ok, desc = pcall(function(): HumanoidDescription
		local api = Players :: any
		if api.GetHumanoidDescriptionFromUserIdAsync then
			return api:GetHumanoidDescriptionFromUserIdAsync(player.UserId)
		end
		return api:GetHumanoidDescriptionFromUserId(player.UserId)
	end)
	if player.Parent == Players then
		ownDescriptions[player] = if ok and desc then desc else false
	end
end

-- The standard body for `player`, keeping what Config/Avatar keeps from
-- their own avatar (waits up to FETCH_TIMEOUT for the fetch).
function CharacterService.standardDescription(player: Player): HumanoidDescription
	local started = os.clock()
	while ownDescriptions[player] == nil and os.clock() - started < Avatar.FETCH_TIMEOUT do
		task.wait(0.1)
	end
	local own = ownDescriptions[player]
	return MatchBody.description(if own then own else nil)
end

-- Spawns `player` already wearing the standard body (no flash of their own
-- avatar). Errors like LoadCharacterAsync does, for the caller's retry loop.
function CharacterService.loadCharacter(player: Player)
	local desc = CharacterService.standardDescription(player)
	local api = player :: any
	local loaded: Model? = nil
	local connection = player.CharacterAdded:Connect(function(character)
		spawnedStandard[character] = true
		loaded = character
	end)
	local ok, err = pcall(function()
		if api.LoadCharacterWithHumanoidDescriptionAsync then
			api:LoadCharacterWithHumanoidDescriptionAsync(desc)
		else
			api:LoadCharacterWithHumanoidDescription(desc)
		end
	end)
	connection:Disconnect()
	if not ok then
		error(err)
	end
	return loaded
end

-- Gives a character that spawned some other way (test mode, the range,
-- dev tools) the standard body. Yields.
local function applyStandard(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local desc = CharacterService.standardDescription(player)
	if not character.Parent then
		return
	end
	local ok, err = pcall(function()
		local api = humanoid :: any
		if api.ApplyDescriptionAsync then
			api:ApplyDescriptionAsync(desc)
		else
			api:ApplyDescription(desc)
		end
	end)
	if not ok then
		warn("[CharacterService] couldn't apply the match body:", err)
	end
end

-- Every skinned-body part really loaded? A part asset that fails comes back as a default limb with no error
-- (MatchBody.missingParts): apply the body again a couple of times. Yields only when something is missing.
local function verifyBody(player: Player, character: Model)
	if not MatchBody.usesSkinnedBody() then
		return
	end
	local missing = MatchBody.missingParts(character)
	if #missing == 0 then
		HealthLog.stage("character", player, "body ok")
		return
	end
	for attempt, wait in Avatar.BODY_RETRY do
		HealthLog.problem(
			"body parts missing",
			player,
			`{table.concat(missing, ",")}, retry {attempt}`
		)
		task.wait(wait)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if
			not character.Parent
			or player.Character ~= character
			or not humanoid
			or humanoid.Health <= 0
		then
			return
		end
		applyStandard(player, character)
		missing = MatchBody.missingParts(character)
		if #missing == 0 then
			HealthLog.stage("character", player, `body ok after retry {attempt}`)
			return
		end
	end
	HealthLog.problem("body parts failed", player, table.concat(missing, ","))
end

-- An accessory on a combatant: the rule in Config/Avatar decides whether it
-- stays (size, type, no layered clothing) and strips its effects
-- (MatchBody.filterAccessory); one that stays is never part of a hit.
local function ignoreAccessory(accessory: Instance)
	if accessory:IsA("Accessory") and MatchBody.filterAccessory(accessory) then
		for _, d in accessory:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
		end
	end
end

-- Registers the Bodies group once (idempotent): no collision with itself,
-- collision with Default kept so walls, floors and raycasts still work. Also the
-- MapBlockers group: invisible map blockers that stop bodies but not shots.
local function registerCollision()
	local ok, err = pcall(function()
		if not PhysicsService:IsCollisionGroupRegistered(Collision.BODIES) then
			PhysicsService:RegisterCollisionGroup(Collision.BODIES)
		end
		PhysicsService:CollisionGroupSetCollidable(Collision.BODIES, Collision.BODIES, false)
		PhysicsService:CollisionGroupSetCollidable(Collision.BODIES, Collision.DEFAULT, true)
		if not PhysicsService:IsCollisionGroupRegistered(Collision.MAP_BLOCKERS) then
			PhysicsService:RegisterCollisionGroup(Collision.MAP_BLOCKERS)
		end
		PhysicsService:CollisionGroupSetCollidable(Collision.MAP_BLOCKERS, Collision.DEFAULT, false)
		PhysicsService:CollisionGroupSetCollidable(
			Collision.MAP_BLOCKERS,
			Collision.MAP_BLOCKERS,
			false
		)
		PhysicsService:CollisionGroupSetCollidable(Collision.MAP_BLOCKERS, Collision.BODIES, true)
	end)
	if not ok then
		warn("[CharacterService] couldn't set up the Bodies collision group:", err)
	end
end

local function setBodyGroup(part: Instance)
	if part:IsA("BasePart") and part.CollisionGroup ~= Collision.BODIES then
		part.CollisionGroup = Collision.BODIES
	end
end

-- Characters already tracked, and their connections (dropped with the model).
local bodyTracked: { [Model]: RBXScriptConnection } = {}

-- Puts a combatant in the Bodies group: every part now and every part added
-- later (accessories, a rebuilt body, held props, respawned limbs).
-- Idempotent; the connection goes when the model leaves the world.
local function trackBody(model: Model)
	if bodyTracked[model] then
		return
	end
	for _, d in model:GetDescendants() do
		setBodyGroup(d)
	end
	local added = model.DescendantAdded:Connect(setBodyGroup)
	bodyTracked[model] = added
	local ancestry: RBXScriptConnection? = nil
	ancestry = model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			added:Disconnect()
			bodyTracked[model] = nil
			if ancestry then
				ancestry:Disconnect()
			end
		end
	end)
end
CharacterService.trackBody = trackBody

-- Shared setup for anything that can be shot.
function CharacterService.prepare(model: Model)
	SimulationFields.prepare(model)
	trackBody(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	HealthService.prepare(humanoid)
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = Movement.JUMP_HEIGHT

	-- No natural regen (Gunplay.md §3): heals only come from Mods.
	local regen = model:FindFirstChild("Health")
	if regen and regen:IsA("Script") then
		regen:Destroy()
	end

	for _, child in model:GetChildren() do
		ignoreAccessory(child)
	end
	model.ChildAdded:Connect(function(child)
		-- Deferred: an instance can't be removed while it is still being added.
		task.defer(function()
			if child.Parent == model then
				ignoreAccessory(child)
			end
		end)
	end)

	-- Lost its root (the engine deleted it in the void, or a script did):
	-- down it, since a Humanoid doesn't die on its own any more.
	local root = model:FindFirstChild("HumanoidRootPart")
	if root then
		root.AncestryChanged:Connect(function()
			if not root:IsDescendantOf(model) and model.Parent and Health.isAlive(humanoid) then
				HealthService.down(humanoid)
			end
		end)
	end

	HitboxHistory.track(model)
	model.Destroying:Connect(function()
		HitboxHistory.untrack(model)
	end)
end

-- Roblox's Animate plays our idle / jump / fall, and an empty walk / run (the
-- direction-blended run set in Simulation/Poses carries the legs). Animate
-- reloads a set when one of its Animation ids changes.
function CharacterService.useOurAnimations(character: Model)
	local animate = character:FindFirstChild("Animate")
	if not animate then
		return
	end
	for name, animationId in Animations.ANIMATE do
		local holder = animate:FindFirstChild(name)
		if holder then
			for _, a in holder:GetChildren() do
				if a:IsA("Animation") and a.AnimationId ~= animationId then
					a.AnimationId = animationId
				end
			end
		end
	end
end

local function onCharacter(character: Model)
	-- Everyone wears the match body, lobby players too (owner 2026-11-21: the
	-- lobby runs and slides like a match); only armed players get guns
	-- (WeaponService, PlayZone).
	-- Non-solid to other bodies from the first frame (prepare runs later).
	trackBody(character)
	-- No name or health tags over players (owner, 2026-11-08); bots and
	-- dummies already hide theirs.
	local humanoid = character:FindFirstChildOfClass("Humanoid")
		or character:WaitForChild("Humanoid", 5)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	-- The Health script and accessories arrive with the character; wait a frame.
	task.defer(function()
		if character.Parent then
			character:WaitForChild("HumanoidRootPart", 5)
			-- The standard body first: applying a description rebuilds the
			-- body parts, so it has to come before hitbox history and health.
			local player = Players:GetPlayerFromCharacter(character)
			if player and not spawnedStandard[character] then
				applyStandard(player, character)
				if not character.Parent then
					return
				end
			end
			if player then
				verifyBody(player, character)
				if not character.Parent then
					return
				end
			end
			MatchBody.dress(character)
			CharacterService.prepare(character)
			character:WaitForChild("Animate", 5)
			CharacterService.useOurAnimations(character)
		end
	end)
end

local function onPlayer(player: Player)
	HealthLog.joined(player)
	task.spawn(fetchOwn, player)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

function CharacterService.init()
	Players.RespawnTime = Combat.RESPAWN_TIME
	registerCollision()
	-- Skinned limb meshes live in Workspace.GGBodyLimbs, outside the character.
	local function onLimb(limb: Instance)
		setBodyGroup(limb)
	end
	for _, limb in CollectionService:GetTagged(Avatar.LIMB_TAG) do
		onLimb(limb)
	end
	CollectionService:GetInstanceAddedSignal(Avatar.LIMB_TAG):Connect(onLimb)
	-- The body blocks' meshes, ahead of the first spawn.
	task.spawn(MatchBody.preload)
	HealthService.onDowned(function(humanoid)
		local character = humanoid.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end
		if ServerRole.isLobby() then
			-- The lobby and the range bring a downed player straight back (a
			-- fall into the void); a pad duel respawns its own at each round.
			if PlayZone.get(player) == "Match" then
				return
			end
			task.delay(Combat.RESPAWN_TIME, function()
				if player.Parent == Players and player.Character == character then
					CharacterService.spawn(player)
				end
			end)
			return
		end
		if not Players.CharacterAutoLoads then
			return -- a match respawns everyone at the next round
		end
		task.delay(Combat.RESPAWN_TIME, function()
			if player.Parent == Players and player.Character == character then
				player:LoadCharacter()
			end
		end)
	end)
end

-- Spawns `player` in the match body, retrying a failed load a few times
-- (lobby servers: everyone, on join and whenever they come back to the lobby).
function CharacterService.spawn(player: Player)
	-- The lobby's own spawn first (LobbySpawnService sets this when its spawn
	-- is up), so nobody lands in an older lobby kept in the place.
	local started = os.clock()
	while
		ServerRole.isLobby()
		and ReplicatedStorage:GetAttribute("LobbySpawnReady") ~= true
		and os.clock() - started < 5
	do
		task.wait(0.1)
	end
	-- With CharacterAutoLoads off a player whose every try fails never gets a character (a join that "doesn't
	-- load"), so the tries back off and the last failure is logged.
	for attempt, wait in Avatar.SPAWN_RETRY do
		if player.Parent ~= Players then
			return
		end
		local ok, err = pcall(CharacterService.loadCharacter, player)
		if ok then
			return
		end
		HealthLog.problem("spawn failed", player, `try {attempt}: {err}`)
		task.wait(wait)
	end
	HealthLog.problem("spawn gave up", player, `{#Avatar.SPAWN_RETRY} tries`)
end

function CharacterService.start()
	-- A lobby server spawns everyone itself, already in the match body (no
	-- flash of their own avatar first); a match server's MatchService does.
	local lobby = ServerRole.isLobby()
	if lobby then
		Players.CharacterAutoLoads = false
	end
	local function joined(player: Player)
		onPlayer(player)
		if lobby and not player.Character then
			task.spawn(CharacterService.spawn, player)
		end
	end
	Players.PlayerAdded:Connect(joined)
	Players.PlayerRemoving:Connect(function(player)
		ownDescriptions[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		joined(player)
	end
end

return CharacterService
