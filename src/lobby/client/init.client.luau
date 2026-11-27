--!strict
-- Lobby place client entry. Same two-phase bootstrap as the match client:
-- init() every controller in ./Controllers, then start() each in its own thread.

-- The dedicated match role uses the same Settings screen and its top-bar
-- control. The other lobby pages remain exclusive to the lobby client.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ServerRole = require(Shared:WaitForChild("ServerRole") :: ModuleScript)
local UiRoot = require(Shared:WaitForChild("UiRoot") :: ModuleScript)
local player = game:GetService("Players").LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
if ServerRole.isMatch() then
	UiRoot.mount("Lobby", playerGui, "Settings")
	local controllers = script.Controllers
	require(controllers.SettingsController).init()
	task.spawn(require(controllers.MatchSettingsButton).start)
	task.spawn(require(controllers.AdminPanelController).start)
	return
end

-- The player's settings on this client (Shared/SettingsApply; the match
-- client starts it in match servers).
require(Shared:WaitForChild("SettingsApply") :: ModuleScript).start()

-- The lobby's Studio-built screens (PlayerScripts.UI.Lobby) into PlayerGui,
-- before any controller looks for them (Shared/UiRoot; vault/04 Tech/UI Architecture.md).
UiRoot.mount("Lobby", playerGui)

-- the chunky cell look on every screen + re-measured self-sizing text
-- (first, so templates are marked before any controller clones them)
local LobbyLook = require(script.Util.LobbyLook)
LobbyLook.apply(playerGui)

local Controllers = script:FindFirstChild("Controllers")

local TAG = "Lobby"
-- Runs one controller's init protected, in order. An error is logged and skipped; an init still
-- yielding after INIT_WAIT s (a WaitForChild on a renamed Studio child) is left to finish on its own
-- while the rest go on, so one controller can't stop every other one from starting (code audit 2026-11-27).
local INIT_WAIT = 15
local function runInit(name: string, init: () -> ())
	local done = false
	task.spawn(function()
		local ok, err = pcall(init)
		if not ok then
			warn(`[{TAG}] {name}.init failed: {err}`)
		end
		done = true
	end)
	local t = os.clock()
	while not done do
		if os.clock() - t > INIT_WAIT then
			warn(`[{TAG}] {name}.init still waiting after {INIT_WAIT} s; starting the rest`)
			return
		end
		task.wait()
	end
end

local loaded: { [string]: any } = {}
if Controllers then
	for _, child in Controllers:GetChildren() do
		if child:IsA("ModuleScript") then
			local ok, result = pcall(require, child)
			if ok then
				loaded[child.Name] = result :: any
			else
				warn(`[Lobby] {child.Name} failed to load: {result}`)
			end
		end
	end
end

for name, controller in loaded do
	if typeof(controller.init) == "function" then
		runInit(name, controller.init)
	end
end

for _, controller in loaded do
	if typeof(controller.start) == "function" then
		task.spawn(controller.start)
	end
end

print("[Lobby] client ready")
require(Shared:WaitForChild("HealthLog") :: ModuleScript).stage("lobby client ready", player)
-- The loading screen's last lobby stage (src/first/LoadingScreen.client.luau); a local attribute, never replicated.
player:SetAttribute("LobbyClientReady", true)
