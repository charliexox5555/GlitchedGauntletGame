--!strict
-- A pad duel's lighting (place merge 2026-11-21, vault/04 Tech/Place Merge Plan.md). In a lobby server the server
-- keeps the lobby's lighting for everyone; a player in a pad duel lights their own view instead: the match baseline
-- plus their map's own lighting (shared/MapLighting), as soon as their duel's map (Workspace.Matches[MatchId], the
-- model carrying that MatchId) arrives. The client host (client/init.client.luau) puts the lobby's lighting back
-- when the player leaves. A whole-server match is lit by the server (MapService), so this does nothing there.
-- In the range the player's view gets the range's profile (Config/RangeLighting, owner 2026-11-26).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapLighting = require(ReplicatedStorage.Shared.MapLighting)
local RangeLighting = require(ReplicatedStorage.Shared.Config.RangeLighting)
local PlayZone = require(ReplicatedStorage.Shared.PlayZone)

local MatchLightingController = {}

local player = Players.LocalPlayer

local function isMatchMap(instance: Instance, id: string): boolean
	return instance:IsA("Model") and instance:GetAttribute("MatchId") == id
end

function MatchLightingController.start()
	if PlayZone.get(player) == "Range" then
		MapLighting.applyProfile(RangeLighting.props, RangeLighting.suspend)
		return
	end
	local id = PlayZone.matchId(player)
	if PlayZone.get(player) ~= "Match" or not id then
		return -- a whole-server match, or the range
	end
	local matches = workspace:WaitForChild("Matches", 30)
	local world = matches and matches:WaitForChild(id, 30)
	if not world then
		return
	end
	local function onChild(child: Instance)
		if
			PlayZone.get(player) == "Match"
			and PlayZone.matchId(player) == id
			and isMatchMap(child, id)
		then
			MapLighting.applyMatch(child :: Model)
		end
	end
	world.ChildAdded:Connect(onChild)
	for _, child in world:GetChildren() do
		onChild(child)
	end
end

return MatchLightingController
