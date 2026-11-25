-- Draft Duels / Edit. Build saved looks from the owner's approved backup users.
assert(game.PlaceId == 71551303511506 and not game:GetService("RunService"):IsRunning())
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local MatchBody = require(game.ReplicatedStorage.Shared.MatchBody)
local config = require(game.ServerScriptService.Server.Bots.AppearanceConfig)

local folder = ServerStorage:FindFirstChild("BotAvatarBackups") or Instance.new("Folder")
folder.Name = "BotAvatarBackups"
folder.Parent = ServerStorage
local results = {}
for _, id in config.BACKUP_USER_IDS do
	if #folder:GetChildren() >= 4 then
		break
	end
	local name = "Avatar_" .. id
	if folder:FindFirstChild(name) then
		continue
	end
	local ok, model, expectedHead = pcall(function()
		local own = Players:GetHumanoidDescriptionFromUserIdAsync(id)
		local description = MatchBody.description(own)
		own:Destroy()
		local wanted = description.Head
		local rig = Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15)
		description:Destroy()
		return rig, wanted
	end)
	if not ok then
		results[name] = tostring(model)
		continue
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local applied = humanoid and humanoid:GetAppliedDescription()
	local valid = humanoid
		and model:FindFirstChild("HumanoidRootPart")
		and model:FindFirstChild("Head")
		and #MatchBody.missingParts(model) == 0
		and (expectedHead == 0 or (applied and applied.Head == expectedHead))
	if applied then
		applied:Destroy()
	end
	if not valid then
		model:Destroy()
		results[name] = "incomplete"
		continue
	end
	for _, instance in model:GetDescendants() do
		if instance:IsA("LuaSourceContainer") then
			instance:Destroy()
		end
	end
	model.Name = name
	model:SetAttribute("BackupUserId", id)
	model.Parent = folder
	results[name] = "stored"
end
return { stored = #folder:GetChildren(), checks = results }
