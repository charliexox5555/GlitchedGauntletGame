--!strict
-- Lobby place client entry. Same two-phase bootstrap as the match client:
-- init() every controller in ./Controllers, then start() each in its own thread.

-- In a Match server (shared/ServerRole) the lobby UI doesn't run at all: the
-- match client (StarterPlayerScripts.Client) has the screen.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ServerRole = require(Shared:WaitForChild("ServerRole") :: ModuleScript)
if ServerRole.isMatch() then
	return
end

-- The player's settings on this client (Shared/SettingsApply; the match
-- client starts it in match servers).
require(Shared:WaitForChild("SettingsApply") :: ModuleScript).start()

-- The lobby's Studio-built screens (PlayerScripts.UI.Lobby) into PlayerGui,
-- before any controller looks for them (Shared/UiRoot; vault/04 Tech/UI Architecture.md).
local UiRoot = require(Shared:WaitForChild("UiRoot") :: ModuleScript)
local player = game:GetService("Players").LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
UiRoot.mount("Lobby", playerGui)

-- the chunky cell look on every screen + re-measured self-sizing text
-- (first, so templates are marked before any controller clones them)
local LobbyLook = require(script.Util.LobbyLook)
LobbyLook.apply(playerGui)

local Controllers = script:FindFirstChild("Controllers")

local loaded: { [string]: any } = {}
if Controllers then
	for _, child in Controllers:GetChildren() do
		if child:IsA("ModuleScript") then
			loaded[child.Name] = require(child) :: any
		end
	end
end

for _, controller in loaded do
	if typeof(controller.init) == "function" then
		controller.init()
	end
end

for _, controller in loaded do
	if typeof(controller.start) == "function" then
		task.spawn(controller.start)
	end
end

print("[Lobby] client ready")
require(Shared:WaitForChild("HealthLog") :: ModuleScript).stage("lobby client ready", player)
