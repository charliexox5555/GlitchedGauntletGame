--!strict
-- Quietly fetches every gun skin this player owns once the lobby is up (Shared/SkinStore delivers skins on
-- demand), so opening the Locker or a skin preview never waits or flashes a stock gun (owner 2026-11-22: "it
-- looks bad for that part of a second"). Equipped skins already came with the loading screen; the rest follow
-- a little later in small batches so the join itself stays light. New skins (a case, a purchase) are fetched
-- as they're added.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local SkinStore = require(ReplicatedStorage.Shared.SkinStore)
local StateValues = require(ReplicatedStorage.Shared.StateValues)

local SkinPreloadController = {}

local AFTER_LOADING = 2 -- seconds after the loading screen closes
local BATCH = 12 -- skins asked for at a time
local GAP = 0.6 -- seconds between batches

local player = Players.LocalPlayer
local running = false

local function owned(): { { string } }
	local list: { { string } } = {}
	for gun, lines in PlayerData.skins(player) do
		for _, line in lines do
			table.insert(list, { line, SkinStore.modelName(gun, line) })
		end
	end
	return list
end

local function preload()
	if running then
		return
	end
	running = true
	local list = owned()
	for i = 1, #list, BATCH do
		SkinStore.want(table.move(list, i, math.min(i + BATCH - 1, #list), 1, {}))
		task.wait(GAP)
	end
	running = false
end

function SkinPreloadController.start()
	while
		player:GetAttribute("LoadingScreen") == true
		or StateValues.get(player, "DataReady") ~= true
	do
		task.wait(0.5)
	end
	task.wait(AFTER_LOADING)
	preload()
	-- skins added later (want() skips the ones already asked for)
	local value = player:WaitForChild(PlayerData.SKINS, 60)
	if value and value:IsA("StringValue") then
		value.Changed:Connect(function()
			task.spawn(preload)
		end)
	end
end

return SkinPreloadController
