--!strict
-- GlitchedGauntletGame client entry point. Same two-phase bootstrap as the server.
--
-- One place, two roles (shared/ServerRole, vault/04 Tech/Place Merge Plan.md):
--  * Match server: the controllers run from the start, for the whole session.
--  * Lobby server: this script is a host. While the player is armed
--    (shared/PlayZone: the range or a pad duel) it runs a copy of itself
--    marked as the runner, so every controller starts with fresh state; back
--    in the lobby it destroys that copy (Roblox stops its threads and
--    connections) and undoes what the match client changed on screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ServerRole = require(Shared:WaitForChild("ServerRole") :: ModuleScript)
local PlayZone = require(Shared:WaitForChild("PlayZone") :: ModuleScript)
local MatchScreens = require(Shared:WaitForChild("MatchScreens") :: ModuleScript)
local MapLighting = require(Shared:WaitForChild("MapLighting") :: ModuleScript)

local RUNNER = "MatchClientRunner"
local LOBBY_ZOOM = 12 -- studs: the lobby camera distance after leaving first person

local function runControllers()
	-- The match's screens (ReplicatedStorage.MatchScreens in the merged place).
	MatchScreens.install(Players.LocalPlayer:WaitForChild("PlayerGui"))

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
end

if ServerRole.isMatch() or script:GetAttribute(RUNNER) == true then
	runControllers()
	print("[GlitchedGauntletGame] client started")
	return
end

-- Lobby host ------------------------------------------------------------------

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local runner: LocalScript? = nil
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
end

local function stop()
	local old = runner
	runner = nil
	if old then
		old:Destroy()
		cleanUp()
	end
	if lobbyLighting then
		MapLighting.restore(lobbyLighting)
		lobbyLighting = nil
	end
end

local function start()
	stop()
	table.clear(guisBefore)
	for _, gui in playerGui:GetChildren() do
		guisBefore[gui] = true
	end
	if not lobbyLighting then
		lobbyLighting = MapLighting.capture()
	end
	local copy = script:Clone()
	copy.Name = "ClientRunner"
	copy:SetAttribute(RUNNER, true)
	runner = copy
	copy.Parent = script.Parent
end

local zone: PlayZone.Zone = PlayZone.get(player)
local function apply(newZone: PlayZone.Zone)
	local previous = zone
	zone = newZone
	if newZone == "Lobby" then
		stop()
	elseif previous ~= newZone or not runner then
		start()
	end
end

PlayZone.onLocalChanged(apply)
if zone ~= "Lobby" then
	start()
end

-- Studio check that the host is the only one of its kind.
if RunService:IsStudio() then
	print("[GlitchedGauntletGame] client host ready (lobby server)")
end
