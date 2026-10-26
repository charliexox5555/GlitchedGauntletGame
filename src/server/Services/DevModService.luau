--!strict
-- Backend of the Mod dev test panel (DevModController, F8). The draft
-- doesn't exist yet, so this is how Mods get tested. Gated on the server:
-- only in Studio, or for the game's owner (group Config/Mods DEV_GROUP at rank
-- DEV_RANK). Allowed players get the player attribute "DevMods" = true; the
-- panel only opens for them, and every request is checked again here.
--
-- DevMod(action, ...):
--   "SetSlot", slot, id, level   any built Mod at any level in any slot
--   "ClearSlot", slot
--   "ResetCooldowns"
--   "NoCooldown", on
--   "SpawnDummy", "Ally" | "Enemy"   a dummy prepared like a player, in front of you
--   "ClearDummies"
-- (Quick-cast is a client setting: the panel toggles it locally.)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.Mods)
local Mods = require(Shared.Mods)
local Net = require(Shared.Net)
local RateLimit = require(Shared.Util.RateLimit)
local Teams = require(Shared.Mods.Teams)
local Validate = require(Shared.Util.Validate)

local CharacterService = require(script.Parent.CharacterService)
local ModService = require(script.Parent.ModService)

local DevModService = {}

local ACTIONS: { [string]: boolean } = {
	SetSlot = true,
	ClearSlot = true,
	ResetCooldowns = true,
	NoCooldown = true,
	SpawnDummy = true,
	ClearDummies = true,
}
local SIDES: { [string]: boolean } = { Ally = true, Enemy = true }
local LEVELS: { [string]: boolean } = {}
for _, level in Config.LEVELS do
	LEVELS[level] = true
end

local SKIN = Color3.fromHex("A3A5A8")
local CLOTH = Color3.fromHex("4A4D52")
local RESPAWN = 3
local DUMMY_TAG = "RangeDummy" -- RangeController draws the health bar

local limiter = RateLimit.new(Config.RATE)
local allowed: { [Player]: boolean } = {}
local dummies: { Model } = {}

local function isAllowed(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	local ok, rank = pcall(function()
		return player:GetRankInGroup(Config.DEV_GROUP)
	end)
	return ok and typeof(rank) == "number" and rank >= Config.DEV_RANK
end

local function dummyFolder(): Folder
	local existing = workspace:FindFirstChild("Dummies")
	if existing and existing:IsA("Folder") then
		return existing
	end
	-- WeaponService's wall checks and Mod line of sight skip this folder.
	local f = Instance.new("Folder")
	f.Name = "Dummies"
	f.Parent = workspace
	return f
end

local spawnDummy: (team: number, label: string, at: CFrame) -> ()

spawnDummy = function(team: number, label: string, at: CFrame)
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = SKIN
	desc.TorsoColor = CLOTH
	desc.LeftArmColor = SKIN
	desc.RightArmColor = SKIN
	desc.LeftLegColor = CLOTH
	desc.RightLegColor = CLOTH
	local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	model.Name = "DevDummy_" .. label
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.AutoRotate = false
	model:PivotTo(at)
	root.Anchored = true -- stays on its mark: shove-proof, easy to aim at
	model:SetAttribute(Teams.ATTRIBUTE, team)
	model:SetAttribute("DevDummy", label)
	model:SetAttribute("DummyLabel", string.upper(label) .. " DUMMY")
	CollectionService:AddTag(model, DUMMY_TAG)
	model.Parent = dummyFolder()
	CharacterService.prepare(model)
	table.insert(dummies, model)

	humanoid.Died:Connect(function()
		task.delay(RESPAWN, function()
			local index = table.find(dummies, model)
			if index then
				table.remove(dummies, index)
				model:Destroy()
				spawnDummy(team, label, at)
			end
		end)
	end)
end

-- A standing spot `distance` studs in front of the player, facing them.
local function spotInFront(player: Player): CFrame?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root or not root:IsA("BasePart") then
		return nil
	end
	local flat = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if flat.Magnitude < 0.1 then
		return nil
	end
	local side = (#dummies % 3 - 1) * 5 -- spread a few side by side
	local right = flat.Unit:Cross(Vector3.yAxis)
	local spot = root.Position + flat.Unit * Config.DEV_DUMMY_DISTANCE + right * side
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, dummyFolder() }
	local ground = workspace:Raycast(spot + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0), params)
	local floor = if ground then ground.Position else spot - Vector3.new(0, 3, 0)
	-- R15 default rig: root centre ~3 studs above the floor.
	local position = floor + Vector3.new(0, 3, 0)
	return CFrame.lookAt(position, position - flat.Unit)
end

local function clearDummies()
	for _, model in dummies do
		model:Destroy()
	end
	table.clear(dummies)
end

local function onDevMod(player: Player, actionArg: unknown, a: unknown, b: unknown, c: unknown)
	if not limiter:allow(player, "DevMod") then
		return
	end
	if not allowed[player] then
		return
	end
	local action = Validate.enum(actionArg, ACTIONS)
	if not action then
		return
	end
	if action == "SetSlot" then
		local slot = Validate.integer(a, 1, Config.SLOTS)
		local id = Validate.string(b, 32)
		local level = Validate.enum(c, LEVELS)
		if slot and id and level and Mods.def(id) and Mods.isBuilt(id) then
			ModService.setSlot(player, slot, id, level)
		end
	elseif action == "ClearSlot" then
		local slot = Validate.integer(a, 1, Config.SLOTS)
		if slot then
			ModService.setSlot(player, slot, nil, "L1")
		end
	elseif action == "ResetCooldowns" then
		ModService.resetCooldowns(player)
	elseif action == "NoCooldown" then
		local on = Validate.boolean(a)
		if on ~= nil then
			ModService.setNoCooldown(player, on)
		end
	elseif action == "SpawnDummy" then
		local side = Validate.enum(a, SIDES)
		if not side or #dummies >= Config.DEV_MAX_DUMMIES then
			return
		end
		local spot = spotInFront(player)
		local mine = Teams.of(player) or 1
		if spot then
			-- Your team for an ally, the other team for an enemy.
			spawnDummy(if side == "Ally" then mine else (if mine == 1 then 2 else 1), side, spot)
		end
	elseif action == "ClearDummies" then
		clearDummies()
	end
end

local function onPlayer(player: Player)
	task.spawn(function()
		local ok = isAllowed(player)
		if player.Parent == Players then
			allowed[player] = ok
			player:SetAttribute("DevMods", ok)
		end
	end)
end

function DevModService.init()
	Net.event("DevMod").OnServerEvent:Connect(onDevMod)
end

function DevModService.start()
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		allowed[player] = nil
		limiter:forget(player)
	end)
end

return DevModService
