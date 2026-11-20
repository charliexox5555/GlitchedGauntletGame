--!nonstrict
-- Run from Studio in Edit mode after the AssetData modules sync. Validates
-- every row before it applies tags and removes the original attributes.
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Migrate authored data in Studio Edit mode")

local scope = if game.PlaceId == 71551303511506
	then "Lobby"
	elseif game.PlaceId == 133387545285290 then "Match"
	else error("Open the Gauntlet Lobby or Match place")
local rs, ss, sg = game.ReplicatedStorage, game.ServerStorage, game.StarterGui
local groups = if scope == "Lobby"
	then {
		Settings = { workspace },
		World = { workspace:FindFirstChild("Lobby"), workspace:FindFirstChild("LobbyV4Staging") },
		Weapons = { rs:FindFirstChild("Weapons") },
		Skins = { rs:FindFirstChild("WeaponSkins") },
		Locker = { rs:FindFirstChild("LockerStage") },
		Interface = { sg },
	}
	else {
		Settings = { workspace },
		Maps = {},
		Weapons = { rs:FindFirstChild("Weapons") },
		Abilities = { rs:FindFirstChild("Abilities") },
		Skins = { rs:FindFirstChild("WeaponSkins") },
		Interface = { sg },
	}

if scope == "Match" then
	for _, folder in pairs({ ss:FindFirstChild("Maps"), workspace:FindFirstChild("Maps") }) do
		table.insert(groups.Maps, folder)
	end
	for _, child in workspace:GetChildren() do
		if child:IsA("Model") and child.Name ~= "ActiveMap" then
			for _, d in child:GetDescendants() do
				if
					d:IsA("SpawnLocation")
					and (d:HasTag("ArenaSpawn_A") or d:HasTag("ArenaSpawn_B"))
				then
					table.insert(groups.Maps, child)
					break
				end
			end
		end
	end
end

local function visit(group, fn)
	for _, root in pairs(assert(groups[group], group)) do
		fn(root)
		if group ~= "Settings" then
			for _, inst in root:GetDescendants() do
				fn(inst)
			end
		end
	end
end

local data = rs.Shared.Config.AssetData
local plan = {}
local counts = {}
local function equal(source, destination)
	for k, v in source do
		if destination[k] ~= v then
			return false
		end
	end
	for k in destination do
		if source[k] == nil then
			return false
		end
	end
	return true
end

for group in groups do
	local module = data:FindFirstChild(scope .. group)
	visit(group, function(owner)
		local original = owner:GetAttributes()
		if owner == workspace then
			original.TestMode = nil -- Studio's Play mode checkbox
		end
		-- Roblox reserves its own attributes, such as RBXRefinementScale.
		for key in original do
			if string.sub(key, 1, 3) == "RBX" then
				original[key] = nil
			end
		end
		if next(original) == nil then
			return
		end
		assert(module, "Missing AssetData for " .. owner:GetFullName())
		local matched
		for key, values in require(module) do
			if equal(original, values) then
				matched = key
				break
			end
		end
		assert(matched, "No exact AssetData row for " .. owner:GetFullName())
		table.insert(plan, { owner = owner, tag = matched, attributes = original })
		for _ in original do
			counts[group] = (counts[group] or 0) + 1
		end
	end)
end

if #plan == 0 then
	return { owners = 0, fieldsByGroup = counts }
end

local recording = ChangeHistoryService:TryBeginRecording(
	"GauntletAssetData",
	"Move Gauntlet asset data to modules"
)
-- Studio tools can wrap the command in their own recording.
local lastApplied = 0
local ok, err = pcall(function()
	for index, entry in plan do
		lastApplied = index
		entry.owner:AddTag("GauntletAuthoredData")
		entry.owner:AddTag(entry.tag)
		for key in entry.attributes do
			entry.owner:SetAttribute(key, nil)
		end
	end
end)
if recording then
	ChangeHistoryService:FinishRecording(
		recording,
		if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
	)
elseif not ok then
	for index = 1, lastApplied do
		local entry = plan[index]
		for key, value in entry.attributes do
			entry.owner:SetAttribute(key, value)
		end
		entry.owner:RemoveTag(entry.tag)
		entry.owner:RemoveTag("GauntletAuthoredData")
	end
end
assert(ok, err)
return { owners = #plan, fieldsByGroup = counts }
