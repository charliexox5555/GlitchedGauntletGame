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
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ServerRole = require(Shared:WaitForChild("ServerRole") :: ModuleScript)
local PlayZone = require(Shared:WaitForChild("PlayZone") :: ModuleScript)
local UiRoot = require(Shared:WaitForChild("UiRoot") :: ModuleScript)
local MapLighting = require(Shared:WaitForChild("MapLighting") :: ModuleScript)
local CoreUi = require(Shared:WaitForChild("CoreUi") :: ModuleScript)
local MovementSim =
	require(Shared:WaitForChild("Simulation"):WaitForChild("Movement") :: ModuleScript)
local PoseSim = require(Shared:WaitForChild("Simulation"):WaitForChild("Poses") :: ModuleScript)

-- The player's settings on this client (the lobby client starts it in lobby servers).
if ServerRole.isMatch() then
	require(Shared:WaitForChild("SettingsApply") :: ModuleScript).start()
end

local RUNNER = "MatchClientRunner"
local LOBBY_MODE = "LobbyOnly" -- runner attribute: start only LOBBY_CONTROLLERS
local READY = "ControllersReady"
-- What runs for a player walking the lobby (their dependencies are loaded, not started).
local LOBBY_CONTROLLERS: { [string]: boolean } = {
	FloorHoldController = true, -- held still until floor arrives under a (re)spawn
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

	script:SetAttribute(READY, true)
	for _, controller in loaded do
		if typeof(controller.start) == "function" then
			task.spawn(controller.start)
		end
	end
end

if script:GetAttribute(RUNNER) ~= true then
	-- The host owns the movement and pose loops so neither drops when ClientRunner restarts across zones.
	MovementSim.initialize()
	PoseSim.initialize()
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
local lobbyPlayerList: boolean? = nil

-- What the match client may leave behind: its screens, the camera setup, the
-- mouse lock, the viewmodel and effects under the camera.
local function cleanUp()
	CoreUi.menuMode(false)
	if lobbyPlayerList ~= nil then
		pcall(
			StarterGui.SetCoreGuiEnabled,
			StarterGui,
			Enum.CoreGuiType.PlayerList,
			lobbyPlayerList
		)
	end
	for _, gui in playerGui:GetChildren() do
		if
			not guisBefore[gui]
			and gui:IsA("LayerCollector")
			and gui.Name ~= "ModState"
			and gui.Name ~= "SkinDelivery"
			and gui.Name ~= "TouchGui"
			and gui:GetAttribute("LobbyGui") ~= true
			and gui:GetAttribute("KeepGui") ~= true
		then
			gui:Destroy()
		end
	end
	local settingsGui = playerGui:FindFirstChild("Settings")
	if not (settingsGui and settingsGui:IsA("ScreenGui") and settingsGui.Enabled) then
		if player:GetAttribute("GameSettingsOpen") == true then
			player:SetAttribute("GameSettingsOpen", false)
		end
	end
	local ctx = player:FindFirstChild("PlayContext")
	if ctx and ctx:IsA("InputContext") then
		for _, child in ctx:GetChildren() do
			if
				child:IsA("InputAction")
				and child.Type == Enum.InputActionType.Bool
				and child:GetState() == true
			then
				child:Fire(false)
			end
		end
		if player:GetAttribute("GameSettingsOpen") ~= true then
			ctx.Enabled = true
		end
	end
	local camera = workspace.CurrentCamera
	if camera then
		for _, child in camera:GetChildren() do
			if not child:IsA("AudioListener") then
				child:Destroy()
			end
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
		if PlayZone.get(player) == "Lobby" then
			player.CameraMinZoomDistance = 0.5
		end
	end)
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	-- The match client's touch controls hid Roblox's stick and jump button
	-- (TouchController); the lobby walks on Roblox's own.
	pcall(function()
		GuiService.TouchControlsEnabled = true
	end)
	local voteBlur = Lighting:FindFirstChild("MapVoteBlur")
	if voteBlur then
		voteBlur:Destroy()
	end
end

local function stop()
	local old = runner
	local wasArmed = runnerArmed
	runner = nil
	runnerArmed = false
	if old then
		if wasArmed then
			-- Clear focus while the old result buttons still exist.
			GuiService.SelectedObject = nil
		end
		if old:GetAttribute(READY) then
			local controllers = old:FindFirstChild("Controllers")
			if controllers then
				if wasArmed then
					require(controllers.MatchEndController).stop()
					require(controllers.TouchController).stop()
				end
				require(controllers.AudioController).stop()
			end
		end
		old:Destroy()
		-- These named bindings belong to RunService/ContextActionService.
		for _, name in
			{
				"GGMovementView",
				"GGPosePitch",
				"GGCamera",
				"GGSlideTilt",
				"GGViewmodel",
				"GGWeapons",
				"GGMods",
				"GGAutoShoot",
				"TouchControls",
			}
		do
			RunService:UnbindFromRenderStep(name)
		end
		ContextActionService:UnbindAction("SkinPreview")
		-- The lobby set changes nothing on screen; only a match client is undone.
		if wasArmed then
			cleanUp()
		end
	end
	MapLighting.restore()
end

local function start(armed: boolean)
	stop()
	if armed then
		-- Into a match: the normal follow camera, whatever a lobby screen left behind (the Locker's Scriptable
		-- camera kept a pad-duel player looking at the pad, 2026-11-26). The match client adjusts it from here.
		local camera = workspace.CurrentCamera
		if camera and camera.CameraType ~= Enum.CameraType.Custom then
			camera.CameraType = Enum.CameraType.Custom
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				camera.CameraSubject = humanoid
			end
		end
		table.clear(guisBefore)
		for _, gui in playerGui:GetChildren() do
			guisBefore[gui] = true
		end
		MapLighting.capture()
		local ok, enabled =
			pcall(StarterGui.GetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList)
		lobbyPlayerList = if ok then enabled else nil
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
local matchId: string? = nil
local function apply()
	local newZone = PlayZone.get(player)
	local newId = if newZone == "Match" then PlayZone.matchId(player) else nil
	if newZone == "Match" and not newId then
		return -- wait for both server attributes before binding match state
	end
	if zone ~= newZone or matchId ~= newId or not runner then
		zone, matchId = newZone, newId
		start(newZone ~= "Lobby")
	end
end

PlayZone.onLocalChanged(apply)
player:GetAttributeChangedSignal(PlayZone.MATCH_ID):Connect(apply)
apply()

-- Studio check that the host is the only one of its kind.
if RunService:IsStudio() then
	print("[GlitchedGauntletGame] client host ready (lobby server)")
end
