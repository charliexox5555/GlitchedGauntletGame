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
local PlayZone = require(ReplicatedStorage.Shared.PlayZone)
local LoadingLayout =
	require(ReplicatedFirst:WaitForChild("Loading"):WaitForChild("LoadingLayout") :: ModuleScript)

local DuelLoadingController = {}

local player = Players.LocalPlayer
local HIDDEN = { "Pips", "Count", "Tip", "Mode" }

local showing: ScreenGui? = nil
local token = 0

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
		step:Disconnect()
		gui:Destroy()
		if showing == gui then
			showing = nil
		end
	end)
end

local function show(matchId: string)
	local template = ReplicatedFirst:FindFirstChild("DuelsLoading")
	local playerGui = player:FindFirstChild("PlayerGui")
	if not (template and template:IsA("ScreenGui") and playerGui) then
		return
	end
	if showing then
		showing:Destroy()
	end
	token += 1
	local mine = token
	local gui = template:Clone()
	gui.Name = "DuelLoading"
	local canvas = gui:FindFirstChild("Canvas")
	if not canvas then
		gui:Destroy()
		return
	end
	for _, name in HIDDEN do
		local item = canvas:FindFirstChild(name)
		if item and item:IsA("GuiObject") then
			item.Visible = false
		end
	end
	local stage = canvas:FindFirstChild("Stage", true)
	if stage and stage:IsA("TextLabel") then
		stage.Text = LoadingConfig.stages.duel
	end
	local spinner = canvas:FindFirstChild("Spinner")
	local stroke = spinner and spinner:FindFirstChildWhichIsA("UIStroke")
	local turn = stroke and stroke:FindFirstChild("Turn")
	local step = RunService.RenderStepped:Connect(function(dt: number)
		if turn and turn:IsA("UIGradient") then
			turn.Rotation = (turn.Rotation + dt * 300) % 360
		end
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
			local ready = player:GetAttribute("MatchScreensReady") == matchId
			local gone = PlayZone.get(player) ~= "Match" or PlayZone.matchId(player) ~= matchId
			if
				gone
				or elapsed >= LoadingConfig.duelMax
				or (ready and elapsed >= LoadingConfig.duelMin)
			then
				break
			end
			task.wait(0.05)
		end
		if gui.Parent then
			close(gui, step)
		end
	end)
end

function DuelLoadingController.start()
	local shownFor: string? = nil
	local function refresh()
		local id = PlayZone.matchId(player)
		if PlayZone.get(player) == "Match" and id and id ~= shownFor then
			shownFor = id
			show(id)
		elseif PlayZone.get(player) ~= "Match" then
			shownFor = nil
		end
	end
	player:GetAttributeChangedSignal(PlayZone.ATTRIBUTE):Connect(refresh)
	player:GetAttributeChangedSignal(PlayZone.MATCH_ID):Connect(refresh)
	refresh()
end

return DuelLoadingController
