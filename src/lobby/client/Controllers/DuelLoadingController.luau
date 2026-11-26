--!strict
-- The loading screen's short version for pad duels (owner 2026-11-22; vault/05 Production/Handoff - Stability,
-- Loading and Preload.md → Phase 2). When this player is put in a pad duel (PlayZone "Match" with a MatchId) a copy
-- of ReplicatedFirst.DuelsLoading covers the switch: the full title, "LOADING DUEL" and the spinner, no tip or
-- progress line. It goes once the duel's match client has its screens up (local attribute MatchScreensReady =
-- the MatchId, MapVoteController), after Config/Loading.duelMin, and by duelMax whatever happens. No remotes.

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LoadingConfig = require(ReplicatedStorage.Shared.Config.Loading)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local PlayZone = require(ReplicatedStorage.Shared.PlayZone)
local LoadingLayout =
	require(ReplicatedFirst:WaitForChild("Loading"):WaitForChild("LoadingLayout") :: ModuleScript)

local DuelLoadingController = {}

local player = Players.LocalPlayer
local HIDDEN = { "Pips", "Count", "Tip", "Mode" }

local showing: ScreenGui? = nil
local activeStep: RBXScriptConnection? = nil
local token = 0

local function disconnectStep()
	if activeStep then
		activeStep:Disconnect()
		activeStep = nil
	end
end

local function close(gui: ScreenGui, step: RBXScriptConnection)
	local fade =
		TweenInfo.new(LoadingConfig.fadeOut, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	for _, d in gui:GetDescendants() do
		if d:IsA("GuiObject") then
			local goal: { [string]: any } = {}
			if d.BackgroundTransparency < 1 then
				goal.BackgroundTransparency = 1
			end
			if d:IsA("TextLabel") then
				goal.TextTransparency = 1
			elseif d:IsA("ImageLabel") then
				goal.ImageTransparency = 1
			end
			if next(goal) then
				TweenService:Create(d, fade, goal):Play()
			end
		elseif d:IsA("UIStroke") then
			TweenService:Create(d, fade, { Transparency = 1 }):Play()
		end
	end
	task.delay(LoadingConfig.fadeOut + 0.05, function()
		if activeStep == step then
			activeStep = nil
		end
		step:Disconnect()
		gui:Destroy()
		if showing == gui then
			showing = nil
			player:SetAttribute("DuelLoading", false)
		end
	end)
end

-- Shows the short loading screen with `text` until `finished(elapsed)` says so (or `maxTime`).
local function show(text: string, finished: (elapsed: number) -> boolean, maxTime: number)
	local template = ReplicatedFirst:FindFirstChild("DuelsLoading")
	local playerGui = player:FindFirstChild("PlayerGui")
	if not (template and template:IsA("ScreenGui") and playerGui) then
		return
	end
	disconnectStep()
	if showing then
		showing:Destroy()
	end
	token += 1
	local mine = token
	local gui = template:Clone()
	gui.Name = "DuelLoading"
	gui.ResetOnSpawn = false
	local canvas = gui:FindFirstChild("Canvas")
	if not canvas then
		gui:Destroy()
		showing = nil
		player:SetAttribute("DuelLoading", false)
		return
	end
	player:SetAttribute("DuelLoading", true)
	for _, name in HIDDEN do
		local item = canvas:FindFirstChild(name)
		if item and item:IsA("GuiObject") then
			item.Visible = false
		end
	end
	local stage = canvas:FindFirstChild("Stage", true)
	if stage and stage:IsA("TextLabel") then
		stage.Text = text
	end
	local spinner = canvas:FindFirstChild("Spinner")
	local stroke = spinner and spinner:FindFirstChildWhichIsA("UIStroke")
	local turn = stroke and stroke:FindFirstChild("Turn")
	local step = RunService.RenderStepped:Connect(function(dt: number)
		if turn and turn:IsA("UIGradient") then
			turn.Rotation = (turn.Rotation + dt * 300) % 360
		end
	end)
	activeStep = step
	gui.Destroying:Once(function()
		if activeStep == step then
			activeStep = nil
		end
		step:Disconnect()
	end)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		LoadingLayout.fit(gui, LoadingConfig :: any)
	end)
	gui.Enabled = true
	gui.Parent = playerGui
	LoadingLayout.fit(gui, LoadingConfig :: any)
	showing = gui
	local started = os.clock()
	task.spawn(function()
		while mine == token do
			local elapsed = os.clock() - started
			if elapsed >= maxTime or finished(elapsed) then
				break
			end
			task.wait(0.05)
		end
		if gui.Parent then
			close(gui, step)
		elseif showing == gui then
			-- destroyed under us: still clear the flag
			step:Disconnect()
			showing = nil
			player:SetAttribute("DuelLoading", false)
		end
	end)
end

-- Into a match (a pad duel, a hosted match): until its match screens are up
-- and the arena floor under the character has streamed in.
local function showDuel(matchId: string)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	show(LoadingConfig.stages.duel, function(elapsed: number): boolean
		local ready = player:GetAttribute("MatchScreensReady") == matchId
		local gone = PlayZone.get(player) ~= "Match" or PlayZone.matchId(player) ~= matchId
		if gone then
			return true
		end
		if not ready or elapsed < LoadingConfig.duelMin then
			return false
		end
		local phase = MatchState.phase()
		if phase == "Vote" then
			return true
		end
		if phase == nil or phase == "Waiting" then
			return false
		end
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if
			not (char and root and root:IsA("BasePart") and char:GetAttribute("MatchId") == matchId)
		then
			return false
		end
		params.FilterDescendantsInstances = { char :: Instance }
		return workspace:Raycast(
			root.Position,
			Vector3.new(0, -LoadingConfig.groundProbe, 0),
			params
		) ~= nil
	end, LoadingConfig.duelMax)
end

local function animated(character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return false
	end

	for _, track in animator:GetPlayingAnimationTracks() do
		if track.Length > 0 then
			return true
		end
	end
	return false
end

-- Give the respawned body a brief head start while the local floor streams in.
local function showHome()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	show(LoadingConfig.stages.home, function(elapsed: number): boolean
		if PlayZone.get(player) == "Match" then
			return true -- straight into another match: its own screen takes over
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if
			not (character and root and root:IsA("BasePart"))
			or character:GetAttribute("SpawnZone") ~= "Lobby"
			or elapsed < LoadingConfig.homeMin
		then
			return false
		end
		if elapsed < LoadingConfig.homeMin + 1.25 and not animated(character) then
			return false
		end
		params.FilterDescendantsInstances = { character :: Instance }
		return workspace:Raycast(
			root.Position,
			Vector3.new(0, -LoadingConfig.groundProbe, 0),
			params
		) ~= nil
	end, LoadingConfig.homeMax)
end

function DuelLoadingController.start()
	local shownFor: string? = nil
	local function refresh()
		local id = PlayZone.matchId(player)
		if PlayZone.get(player) == "Match" and id and id ~= shownFor then
			if player:GetAttribute("LoadingScreen") == true then
				return
			end
			shownFor = id
			if player:GetAttribute("MatchScreensReady") ~= id then
				showDuel(id)
			end
		elseif PlayZone.get(player) ~= "Match" then
			if shownFor ~= nil and PlayZone.get(player) == "Lobby" then
				showHome()
			end
			shownFor = nil
		end
	end
	player:GetAttributeChangedSignal(PlayZone.ATTRIBUTE):Connect(refresh)
	player:GetAttributeChangedSignal(PlayZone.MATCH_ID):Connect(refresh)
	player:GetAttributeChangedSignal("LoadingScreen"):Connect(refresh)
	refresh()
	-- Self-heal: "DuelLoading" on with no cover on screen (seen 2026-11-26 after a match: the flag stayed on and
	-- the lobby's onboarding, which waits for it, never opened the free case).
	task.spawn(function()
		while true do
			task.wait(1)
			local gui = showing
			if player:GetAttribute("DuelLoading") == true and not (gui and gui.Parent) then
				showing = nil
				player:SetAttribute("DuelLoading", false)
			end
		end
	end)
end

return DuelLoadingController
