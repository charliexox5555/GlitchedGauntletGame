--!strict
-- Where players spawn in the lobby (owner 2026-11-21: "lobby v5 is going to be your actual lobby ... make sure we
-- spawn there. Keep all the other lobbies, though"). At server start it switches off every SpawnLocation outside
-- Workspace.LobbyV5 (the older lobbies stay in the place, untouched in the saved file) and puts an invisible,
-- non-solid SpawnLocation on the V5 hub's spawn anchor (LobbyV5.Shell.Hub.Anchors.Spawn). Runtime only: nothing in
-- the place file changes.

local LobbySpawnService = {}

local LOBBY_ROOT = "LobbyV5"
local ANCHOR_PATH = { "LobbyV5", "Shell", "Hub", "Anchors", "Spawn" }
local SPAWN_SIZE = Vector3.new(14, 1, 14)

local function findAnchor(): BasePart?
	local node: Instance? = workspace
	for _, name in ANCHOR_PATH do
		node = if node then node:WaitForChild(name, 10) else nil
	end
	return if node and node:IsA("BasePart") then node else nil
end

function LobbySpawnService.start()
	local root = workspace:FindFirstChild(LOBBY_ROOT)
	local anchor = findAnchor()
	if not root or not anchor then
		warn("[LobbySpawn] LobbyV5 spawn anchor missing: keeping the place's own spawns")
		return
	end
	for _, d in workspace:GetDescendants() do
		if d:IsA("SpawnLocation") and not d:IsDescendantOf(root) then
			d.Enabled = false
		end
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbyV5Spawn"
	spawn.Size = SPAWN_SIZE
	-- Top face flush with the anchor's top, so players stand on the hub floor.
	spawn.CFrame = anchor.CFrame * CFrame.new(0, anchor.Size.Y / 2 - SPAWN_SIZE.Y / 2, 0)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.CanTouch = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Enabled = true
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	spawn.Parent = root
end

return LobbySpawnService
