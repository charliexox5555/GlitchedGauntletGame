--!strict
-- A pad duel's lighting (place merge 2026-11-21, vault/04 Tech/Place Merge Plan.md). In a lobby server the server
-- keeps the lobby's lighting for everyone; a player in a pad duel lights their own view instead: the match baseline
-- plus their map's own lighting (shared/MapLighting), as soon as their duel's map (Workspace.Matches[MatchId], the
-- model carrying that MatchId) arrives. The client host (client/init.client.luau) puts the lobby's lighting back
-- when the player leaves. A whole-server match is lit by the server (MapService), so this does nothing there.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapLighting = require(ReplicatedStorage.Shared.MapLighting)
local PlayZone = require(ReplicatedStorage.Shared.PlayZone)

local MatchLightingController = {}

local player = Players.LocalPlayer

local function isMatchMap(instance: Instance, id: string): boolean
	return instance:IsA("Model") and instance:GetAttribute("MatchId") == id
end

function MatchLightingController.start()
	local id = PlayZone.matchId(player)
	if not id then
		return -- a whole-server match, or the range
	end
	local matches = workspace:WaitForChild("Matches", 30)
	local world = matches and matches:WaitForChild(id, 30)
	if not world then
		return
	end
	local function onChild(child: Instance)
		if isMatchMap(child, id) then
			MapLighting.apply(MapLighting.matchBaseline(), child)
		end
	end
	for _, child in world:GetChildren() do
		onChild(child)
	end
	world.ChildAdded:Connect(onChild)
end

return MatchLightingController
