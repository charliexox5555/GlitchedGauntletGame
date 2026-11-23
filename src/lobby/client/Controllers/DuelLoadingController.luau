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

local Animations = require(ReplicatedStorage.Shared.Config.Animations)
local ContentProvider = game:GetService("ContentProvider")
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

-- Shows the short loading screen with `text` until `finished(elapsed)` says so (or `maxTime`).
local function show(text: string, finished: (elapsed: number) -> boolean, maxTime: number)
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
		end
	end)
end

-- Into a match (a pad duel, a hosted match): until its match screens are up.
local function showDuel(matchId: string)
	show(LoadingConfig.stages.duel, function(elapsed: number): boolean
		local ready = player:GetAttribute("MatchScreensReady") == matchId
		local gone = PlayZone.get(player) ~= "Match" or PlayZone.matchId(player) ~= matchId
		return gone or (ready and elapsed >= LoadingConfig.duelMin)
	end, LoadingConfig.duelMax)
end

-- The third-person body's animations (Config/Animations: poses, locomotion, the Animate set), as Animation
-- instances for ContentProvider (made once; a second preload is served from the device's cache).
local bodyAnimations: { Instance }? = nil
local function animationList(): { Instance }
	local list = bodyAnimations
	if list then
		return list
	end
	local made: { Instance } = {}
	for _, group in { Animations.POSES, Animations.LOCOMOTION, Animations.ANIMATE } do
		for _, animId in group :: { [string]: any } do
			if typeof(animId) == "string" then
				local a = Instance.new("Animation")
				a.AnimationId = animId
				table.insert(made, a)
			end
		end
	end
	bodyAnimations = made
	return made
end

-- The lobby character moves with loaded animations: its Animator plays tracks and each has a length (a track
-- still downloading has none and the body stands stiff).
local function animated(character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return false
	end
	local tracks = animator:GetPlayingAnimationTracks()
	if #tracks == 0 then
		return false
	end
	for _, t in tracks do
		if t.Length <= 0 then
			return false
		end
	end
	return true
end

-- Back to this server's lobby after a match (owner 2026-11-23: "go through the loading screen again just for that
-- transition", and the lobby's 3D animations loaded before you're in): until the body animations are preloaded,
-- the lobby character's are playing, and it stands on streamed-in floor.
local function showHome()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local preloaded = false
	task.spawn(function()
		pcall(ContentProvider.PreloadAsync, ContentProvider, animationList())
		preloaded = true
	end)
	show(LoadingConfig.stages.home, function(elapsed: number): boolean
		if PlayZone.get(player) == "Match" then
			return true -- straight into another match: its own screen takes over
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not (character and root and root:IsA("BasePart")) or elapsed < LoadingConfig.homeMin then
			return false
		end
		if not preloaded or not animated(character) then
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
			shownFor = id
			showDuel(id)
		elseif PlayZone.get(player) ~= "Match" then
			if shownFor ~= nil and PlayZone.get(player) == "Lobby" then
				showHome()
			end
			shownFor = nil
		end
	end
	player:GetAttributeChangedSignal(PlayZone.ATTRIBUTE):Connect(refresh)
	player:GetAttributeChangedSignal(PlayZone.MATCH_ID):Connect(refresh)
	refresh()
end

return DuelLoadingController
