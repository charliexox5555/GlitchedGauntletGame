--!strict
-- GlitchedGauntletGame client entry point. Same two-phase bootstrap as the server.
--
-- One place, two roles (shared/ServerRole, vault/04 Tech/Place Merge Plan.md):
--  * Match server: the controllers run from the start, for the whole session.
--  * Lobby server: this script is a host. It always runs a copy of itself
--    marked as the runner, fresh for each PlayZone. Armed (the range, a pad
--    duel): every controller. In the lobby: only the movement set
--    (LOBBY_CONTROLLERS: run, crouch, slide, the third-person poses, footsteps;
--    owner 2026-11-21: "people in the lobby ... running and the sliding").
--    Leaving an armed zone destroys that copy (Roblox stops its threads and
--    connections) and undoes what the match client changed on screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ServerRole = require(Shared:WaitForChild("ServerRole") :: ModuleScript)
local PlayZone = require(Shared:WaitForChild("PlayZone") :: ModuleScript)
local UiRoot = require(Shared:WaitForChild("UiRoot") :: ModuleScript)
local MapLighting = require(Shared:WaitForChild("MapLighting") :: ModuleScript)

local RUNNER = "MatchClientRunner"
local LOBBY_MODE = "LobbyOnly" -- runner attribute: start only LOBBY_CONTROLLERS
-- What runs for a player walking the lobby (their dependencies are loaded, not started).
local LOBBY_CONTROLLERS: { [string]: boolean } = {
	AudioController = true,
	CharacterFxController = true,
	FootstepController = true,
	InputController = true,
	MovementController = true,
	PoseController = true,
}
local LOBBY_ZOOM = 12 -- studs: the lobby camera distance after leaving first person

local function runControllers(lobbyOnly: boolean)
	-- The match's screens (PlayerScripts.UI.Match, Shared/UiRoot).
	if not lobbyOnly then
		UiRoot.mount("Match", Players.LocalPlayer:WaitForChild("PlayerGui"))
	end

	local Controllers = script:FindFirstChild("Controllers")

	local loaded: { [string]: any } = {}
	if Controllers then
		for _, child in Controllers:GetChildren() do
			if child:IsA("ModuleScript") and (not lobbyOnly or LOBBY_CONTROLLERS[child.Name]) then
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
end

if ServerRole.isMatch() or script:GetAttribute(RUNNER) == true then
	local lobbyOnly = script:GetAttribute(LOBBY_MODE) == true
	runControllers(lobbyOnly)
	print(`[GlitchedGauntletGame] client started{if lobbyOnly then " (lobby movement)" else ""}`)
	return
end

-- Lobby host ------------------------------------------------------------------

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local runner: LocalScript? = nil
local runnerArmed = false -- the running copy is a full match client (else the lobby set)
local guisBefore: { [Instance]: boolean } = {}
local lobbyLighting: MapLighting.Baseline? = nil -- the lobby's, while a pad duel lights this view

-- What the match client may leave behind: its screens, the camera setup, the
-- mouse lock, the viewmodel and effects under the camera.
local function cleanUp()
	for _, gui in playerGui:GetChildren() do
		if not guisBefore[gui] and gui:IsA("LayerCollector") then
			gui:Destroy()
		end
	end
	local camera = workspace.CurrentCamera
	if camera then
		for _, child in camera:GetChildren() do
			child:Destroy()
		end
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
	-- Camera mode and zoom limits come back from the server (PlayZone), but the
	-- camera keeps its first-person distance: push it back out to a normal
	-- third-person view for a moment, then free the zoom again.
	player.CameraMinZoomDistance = LOBBY_ZOOM
	task.delay(0.2, function()
		if not runner then
			player.CameraMinZoomDistance = 0.5
		end
	end)
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	-- The match client's touch controls hid Roblox's stick and jump button
	-- (TouchController); the lobby walks on Roblox's own.
	pcall(function()
		game:GetService("GuiService").TouchControlsEnabled = true
	end)
end

local function stop()
	local old = runner
	local wasArmed = runnerArmed
	runner = nil
	runnerArmed = false
	if old then
		old:Destroy()
		-- The lobby set changes nothing on screen; only a match client is undone.
		if wasArmed then
			cleanUp()
		end
	end
	if lobbyLighting then
		MapLighting.restore(lobbyLighting)
		lobbyLighting = nil
	end
end

local function start(armed: boolean)
	stop()
	if armed then
		table.clear(guisBefore)
		for _, gui in playerGui:GetChildren() do
			guisBefore[gui] = true
		end
		if not lobbyLighting then
			lobbyLighting = MapLighting.capture()
		end
	end
	local copy = script:Clone()
	copy.Name = "ClientRunner"
	copy:SetAttribute(RUNNER, true)
	copy:SetAttribute(LOBBY_MODE, not armed)
	runner = copy
	runnerArmed = armed
	copy.Parent = script.Parent
end

local zone: PlayZone.Zone = PlayZone.get(player)
local function apply(newZone: PlayZone.Zone)
	local previous = zone
	zone = newZone
	if previous ~= newZone or not runner then
		start(newZone ~= "Lobby")
	end
end

PlayZone.onLocalChanged(apply)
start(zone ~= "Lobby")

-- Studio check that the host is the only one of its kind.
if RunService:IsStudio() then
	print("[GlitchedGauntletGame] client host ready (lobby server)")
end
