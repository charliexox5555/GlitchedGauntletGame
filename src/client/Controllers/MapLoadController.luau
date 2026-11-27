--!strict
-- Map loading on this client (vault/04 Tech/Loading and Performance 2026-11-27.md). Two jobs, no remotes:
--  * Preloads the map vote's pictures as soon as the match client starts (they used to start downloading only
--    when the vote screen showed them, so a slow phone saw blank cards).
--  * Watches this match's map arrive (Services/MapService stamps `MapId` and the server time `LoadedAt` before it
--    sends it) and logs, in the F9 client console:
--      [Health] C map here <map> +<s> <arrival seconds after the server sent it>, <n> instances
--      [Health] C map content <map> ... <seconds> (or a warning with the meshes or images that failed)
--    so a live "the map didn't load" report can be traced to the stage that stalled. The content pass preloads
--    one instance per unique mesh or image, which is what the map needs on screen.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HealthLog = require(ReplicatedStorage.Shared.HealthLog)
local MatchConfig = require(ReplicatedStorage.Shared.Config.Match)
local PlayZone = require(ReplicatedStorage.Shared.PlayZone)
local ServerRole = require(ReplicatedStorage.Shared.ServerRole)

local MapLoadController = {}

local player = Players.LocalPlayer
local MAX_LISTED = 3 -- failed ids written into a warning
local seen: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function preloadVotePictures()
	local images: { string } = {}
	for _, entry in MatchConfig.MAPS do
		local image = (entry :: any).image
		if typeof(image) == "string" and image ~= "" then
			table.insert(images, image)
		end
	end
	if #images > 0 then
		pcall(ContentProvider.PreloadAsync, ContentProvider, images)
	end
end

-- One instance per unique mesh / image in the map (PreloadAsync loads an instance's own content; content id
-- strings would be fetched as images, so meshes must go in as their MeshParts).
local function contentOf(map: Instance): { Instance }
	local keys: { [string]: boolean } = {}
	local list: { Instance } = {}
	local function add(key: string, inst: Instance)
		if key ~= "" and not keys[key] then
			keys[key] = true
			table.insert(list, inst)
		end
	end
	for _, d in map:GetDescendants() do
		if d:IsA("MeshPart") then
			add(d.MeshId .. "|" .. d.TextureID, d)
		elseif d:IsA("Decal") then -- Textures too
			add(d.Texture, d)
		end
	end
	return list
end

local function onMap(map: Model)
	if seen[map] then
		return
	end
	seen[map] = true
	local mapId = map:GetAttribute("MapId")
	local name = if typeof(mapId) == "string" then mapId else map.Name
	local sentAt = map:GetAttribute("LoadedAt")
	local arrival = if typeof(sentAt) == "number"
		then workspace:GetServerTimeNow() - sentAt
		else nil
	local count = #map:GetDescendants()
	HealthLog.stage(
		"map here",
		player,
		string.format(
			"%s %s, %d instances",
			name,
			if arrival
				then string.format("%.1fs after the server sent it", arrival)
				else "(no stamp)",
			count
		)
	)
	local started = os.clock()
	local content = contentOf(map)
	local failed: { string } = {}
	pcall(
		ContentProvider.PreloadAsync,
		ContentProvider,
		content,
		function(id: string, status: Enum.AssetFetchStatus)
			if status ~= Enum.AssetFetchStatus.Success then
				table.insert(failed, id)
			end
		end
	)
	if not map.Parent then
		return -- replaced while it loaded
	end
	local took = os.clock() - started
	if #failed > 0 then
		HealthLog.problem(
			"map content failed",
			player,
			string.format(
				"%s %d of %d in %.1fs: %s",
				name,
				#failed,
				#content,
				took,
				table.concat(failed, " ", 1, math.min(#failed, MAX_LISTED))
			)
		)
	else
		HealthLog.stage(
			"map content",
			player,
			string.format("%s %d assets in %.1fs", name, #content, took)
		)
	end
end

local function watch(holder: Instance, isMap: (Instance) -> boolean)
	holder.ChildAdded:Connect(function(child)
		if isMap(child) then
			task.defer(onMap, child :: Model)
		end
	end)
	for _, child in holder:GetChildren() do
		if isMap(child) then
			task.spawn(onMap, child :: Model)
		end
	end
end

function MapLoadController.start()
	if ServerRole.isMatch() then
		task.spawn(preloadVotePictures)
		watch(workspace, function(child)
			return child:IsA("Model") and child.Name == "ActiveMap"
		end)
		return
	end
	local id = PlayZone.matchId(player)
	if PlayZone.get(player) ~= "Match" or not id then
		return -- the range, or a lobby-only start
	end
	task.spawn(preloadVotePictures)
	local matches = workspace:WaitForChild("Matches", 30)
	local world = matches and matches:WaitForChild(id, 30)
	if not world then
		HealthLog.problem("map folder missing", player, id)
		return
	end
	watch(world, function(child)
		return child:IsA("Model") and child:GetAttribute("MatchId") == id
	end)
end

return MapLoadController
