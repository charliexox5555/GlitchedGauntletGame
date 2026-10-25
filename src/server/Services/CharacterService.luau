--!strict
-- Prepares every combatant (player characters and test dummies): 100 HP with
-- no natural regen, standard jump, hats that bullets ignore, hitbox history.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Movement = require(ReplicatedStorage.Shared.Config.Movement)
local HitboxHistory = require(script.Parent.HitboxHistory)

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
	humanoid.MaxHealth = Combat.MAX_HEALTH
	humanoid.Health = Combat.MAX_HEALTH
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = Movement.JUMP_HEIGHT
	humanoid.BreakJointsOnDeath = false

	-- No natural regen (Gunplay.md §3): heals only come from Mods.
	local regen = model:FindFirstChild("Health")
	if regen and regen:IsA("Script") then
		regen:Destroy()
	end

	for _, child in model:GetChildren() do
		ignoreAccessory(child)
	end
	model.ChildAdded:Connect(ignoreAccessory)

	HitboxHistory.track(model)
	model.Destroying:Connect(function()
		HitboxHistory.untrack(model)
	end)
end

local function onCharacter(character: Model)
	-- The Health script and accessories arrive with the character; wait a frame.
	task.defer(function()
		if character.Parent then
			character:WaitForChild("HumanoidRootPart", 5)
			CharacterService.prepare(character)
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
end

function CharacterService.start()
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return CharacterService
