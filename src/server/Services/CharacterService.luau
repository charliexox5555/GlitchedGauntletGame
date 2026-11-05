--!strict
-- Prepares every combatant (player characters and test dummies): the standard
-- match body (shared/MatchBody: same parts, scales and slim arms for everyone,
-- vault/01 Design/Match Avatar.md), full health with no natural regen (the
-- game's own HP, HealthService: nobody truly dies), standard jump, hats that
-- bullets ignore, hitbox history. In test mode (characters auto-load) a
-- downed player comes back after RESPAWN_TIME.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animations = require(ReplicatedStorage.Shared.Config.Animations)
local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Health = require(ReplicatedStorage.Shared.Health)
local MatchBody = require(ReplicatedStorage.Shared.MatchBody)
local Avatar = require(ReplicatedStorage.Shared.Config.Avatar)
local Movement = require(ReplicatedStorage.Shared.Config.Movement)
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

local function ignoreAccessory(accessory: Instance)
	if accessory:IsA("Accessory") then
		for _, d in accessory:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanQuery = false
				d.CanTouch = false
			end
		end
	end
end

-- Shared setup for anything that can be shot.
function CharacterService.prepare(model: Model)
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
	model.ChildAdded:Connect(ignoreAccessory)

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
			MatchBody.slimArms(character)
			CharacterService.prepare(character)
			character:WaitForChild("Animate", 5)
			CharacterService.useOurAnimations(character)
		end
	end)
end

local function onPlayer(player: Player)
	task.spawn(fetchOwn, player)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

function CharacterService.init()
	Players.RespawnTime = Combat.RESPAWN_TIME
	HealthService.onDowned(function(humanoid)
		local character = humanoid.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player or not Players.CharacterAutoLoads then
			return -- a match respawns everyone at the next round
		end
		task.delay(Combat.RESPAWN_TIME, function()
			if player.Parent == Players and player.Character == character then
				player:LoadCharacter()
			end
		end)
	end)
end

function CharacterService.start()
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(player)
		ownDescriptions[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return CharacterService
