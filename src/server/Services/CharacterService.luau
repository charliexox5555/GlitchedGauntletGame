--!strict
-- Prepares every combatant (player characters and test dummies): full health with
-- no natural regen (the game's own HP, HealthService: nobody truly dies),
-- standard jump, hats that bullets ignore, hitbox history. In test mode
-- (characters auto-load) a downed player comes back after RESPAWN_TIME.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animations = require(ReplicatedStorage.Shared.Config.Animations)
local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Health = require(ReplicatedStorage.Shared.Health)
local Movement = require(ReplicatedStorage.Shared.Config.Movement)
local HitboxHistory = require(script.Parent.HitboxHistory)
local HealthService = require(script.Parent.HealthService)

local CharacterService = {}

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
			CharacterService.prepare(character)
			character:WaitForChild("Animate", 5)
			CharacterService.useOurAnimations(character)
		end
	end)
end

local function onPlayer(player: Player)
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
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return CharacterService
