--!strict
-- The loading screen v2 (vault/05 Production/Handoff - Stability, Loading and Preload.md → Phase 2; RIVALS study:
-- vault/03 Research/Rivals Reference/Loading Screen.md). Runs first on every join, in both server roles:
--  * Shows ReplicatedFirst.DuelsLoading (Studio-built, tools/studio/BuildDuelsLoading.luau), or takes over the copy
--    Roblox showed during a teleport (MatchFoundController, or this script at a match's end) so nothing flashes.
--  * Plays the Draft Duels two-beat reveal (vault/02 Art/Draft Duels Logo.md → Title motion) with the sting, under
--    a quiet music bed; both on SoundService.SettingsMusic.
--  * The progress line follows real stages (no fake bar): Lobby = connected → data → fighter → lobby client;
--    Match = connected → data → match screens → every player in (the server leaves "Waiting").
--  * Holds at least Config/Loading.minHold (owner: no skip), closes with a fade and a blur that clears, and always
--    closes by the watchdog.
-- Clients mark their stages with local Player attributes (LobbyClientReady, MatchScreensReady); this script sets
-- LoadingScreen while it shows (LobbyMusic waits for it). No remotes.
-- Self-contained until Shared replicates: everything from Shared is waited for with a timeout.

local ContentProvider = game:GetService("ContentProvider")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Only until Config/Loading arrives (or if it never does).
local FALLBACK = {
	minHold = 2.2,
	assetWait = 3,
	watchdogLobby = 30,
	watchdogMatch = 120,
	fadeOut = 0.45,
	fill = 0.35,
	blur = 24,
	phoneHeight = 600,
	phoneBoost = 1.3,
	phoneY = {
		Mode = 230,
		Logo = 430,
		Progress = 650,
		Spinner = 650,
		Stage = 692,
		Count = 728,
		Tip = 905,
	},
}
local LoadingLayout = require(script.Parent:WaitForChild("LoadingLayout") :: ModuleScript)
local QUINT_OUT = Enum.EasingStyle.Quint

-- The screen ------------------------------------------------------------------------

local arriving = TeleportService:GetArrivingTeleportGui()
local gui: ScreenGui
local revealed = false
if arriving and arriving:IsA("ScreenGui") and arriving:FindFirstChild("Canvas") then
	gui = arriving
	revealed = true -- the teleport already showed the full title
else
	if arriving then
		arriving:Destroy() -- an older teleport screen (LobbyLoading)
	end
	local template = ReplicatedFirst:WaitForChild("DuelsLoading", 10)
	if not (template and template:IsA("ScreenGui")) then
		warn("[Loading] no ReplicatedFirst.DuelsLoading: Roblox's own loading screen stays")
		return
	end
	gui = template:Clone()
end
gui.Name = "DuelsLoading"
gui.Enabled = true
gui.Parent = playerGui
ReplicatedFirst:RemoveDefaultLoadingScreen()
player:SetAttribute("LoadingScreen", true)

local canvas = gui:WaitForChild("Canvas") :: Frame
local fit = canvas:WaitForChild("Fit") :: UIScale
local logo = canvas:WaitForChild("Logo") :: Frame
local ticket = logo:WaitForChild("Ticket") :: ImageLabel
local duels = logo:WaitForChild("Duels") :: ImageLabel
local full = logo:WaitForChild("Full") :: ImageLabel
local fill = (canvas:WaitForChild("Progress") :: Frame):WaitForChild("Fill") :: Frame
local stageLabel = canvas:WaitForChild("Stage") :: TextLabel
local countLabel = canvas:WaitForChild("Count") :: TextLabel
local tipLabel = canvas:WaitForChild("Tip") :: TextLabel
local spinner = canvas:WaitForChild("Spinner") :: Frame
local spinStroke = spinner:FindFirstChildWhichIsA("UIStroke")
local turnFound = spinStroke and spinStroke:FindFirstChild("Turn")
local turn: UIGradient? = if turnFound and turnFound:IsA("UIGradient") then turnFound else nil

local cfg: any = FALLBACK

local function scaleCanvas()
	LoadingLayout.fit(gui, cfg)
end
scaleCanvas()
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(scaleCanvas)

local frame = RunService.RenderStepped:Connect(function(dt: number)
	if turn then
		turn.Rotation = (turn.Rotation + dt * 300) % 360
	end
end)

-- The world behind blurs until the screen has gone.
local blur = Instance.new("BlurEffect")
blur.Name = "DuelsLoadingBlur"
blur.Size = FALLBACK.blur
blur.Parent = Lighting

-- Shared, the config and the sound group (all with a timeout) -------------------------

local function waitPath(root: Instance, path: { string }, timeout: number): Instance?
	local node: Instance? = root
	local deadline = os.clock() + timeout
	for _, name in path do
		if not node then
			return nil
		end
		node = node:WaitForChild(name, math.max(deadline - os.clock(), 0.01))
	end
	return node
end

local configReady = false
task.spawn(function()
	local module = waitPath(ReplicatedStorage, { "Shared", "Config", "Loading" }, 10)
	if module and module:IsA("ModuleScript") then
		local ok, loaded = pcall(require, module)
		if ok and typeof(loaded) == "table" then
			cfg = loaded
			scaleCanvas()
			local tips = cfg.tips
			if not revealed and tips and #tips > 0 then
				tipLabel.Text = "TIP  /  " .. tips[math.random(1, #tips)]
			end
		end
	end
	configReady = true
end)

local function musicGroup(): SoundGroup
	local name = "SettingsMusic" -- Config/SettingsApply.MUSIC_GROUP (Shared may not be here yet)
	local g = SoundService:FindFirstChild(name)
	if g and g:IsA("SoundGroup") then
		return g
	end
	local made = Instance.new("SoundGroup")
	made.Name = name
	made.Parent = SoundService
	return made
end

local function sound(spec: any, looped: boolean): Sound?
	if typeof(spec) ~= "table" or typeof(spec.id) ~= "string" then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = if looped then "LoadingBed" else "LoadingSting"
	s.SoundId = spec.id
	s.Looped = looped
	s.Volume = if looped then 0 else spec.volume or 0.6
	s.SoundGroup = musicGroup()
	s.Parent = SoundService
	return s
end

-- The reveal (Draft Duels Logo → Title motion) ----------------------------------------

local function tween(
	inst: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
): Tween
	local t = TweenService:Create(
		inst,
		TweenInfo.new(seconds, style or QUINT_OUT, dir or Enum.EasingDirection.Out),
		goal
	)
	t:Play()
	return t
end

local REST = UDim2.fromScale(0.5, 0.5)
local reduced = (GuiService :: any).ReducedMotionEnabled == true

local function hideLogo()
	if reduced then
		ticket.Visible, duels.Visible, full.Visible = false, false, true
		full.ImageTransparency = 1
	else
		ticket.ImageTransparency, duels.ImageTransparency = 1, 1
	end
end

local function reveal(sting: Sound?)
	if reduced then
		tween(full, 0.4, { ImageTransparency = 0 })
		if sting then
			sting:Play()
		end
		return
	end
	-- lihfolk-ignore: findfirstchild-chain (stored and nil-checked below)
	local ticketPop = ticket:FindFirstChild("Pop") :: UIScale?
	-- lihfolk-ignore: findfirstchild-chain (stored and nil-checked below)
	local duelsPop = duels:FindFirstChild("Pop") :: UIScale?
	-- DRAFT from the upper left, easing up from 95%.
	ticket.Position = UDim2.fromScale(0.44, 0.42)
	if ticketPop then
		ticketPop.Scale = 0.95
		tween(ticketPop, 0.23, { Scale = 1 })
	end
	tween(ticket, 0.23, { Position = REST, ImageTransparency = 0 })
	task.delay(cfg.sting and cfg.sting.at or 0.21, function()
		if sting then
			sting:Play()
		end
	end)
	-- DUELS rises from 11% below at 215 ms, with a 2.5% punch around 360 ms.
	duels.Position = UDim2.fromScale(0.5, 0.61)
	task.delay(0.215, function()
		tween(duels, 0.285, { Position = REST, ImageTransparency = 0 })
		if duelsPop then
			duelsPop.Scale = 1
			task.delay(0.12, function()
				tween(duelsPop, 0.06, { Scale = 1.025 }, Enum.EasingStyle.Quad).Completed:Once(
					function()
						tween(duelsPop, 0.2, { Scale = 1 })
					end
				)
			end)
		end
	end)
end

-- Stages ------------------------------------------------------------------------------

local stepIndex, stepCount = 0, 1
local function stage(key: string, fallback: string)
	local words = cfg.stages
	stageLabel.Text = if words and typeof(words[key]) == "string" then words[key] else fallback
end
local function advance()
	stepIndex += 1
	tween(fill, cfg.fill, { Size = UDim2.fromScale(math.clamp(stepIndex / stepCount, 0, 1), 1) })
end

local function waitFor(check: () -> boolean, deadline: number): boolean
	while not check() do
		if os.clock() >= deadline then
			return false
		end
		task.wait(0.1)
	end
	return true
end

local function stateValue(owner: Instance?, name: string): string?
	local folder = owner and owner:FindFirstChild("GauntletState")
	local v = folder and folder:FindFirstChild(name)
	return if v and v:IsA("StringValue") then v.Value else nil
end

local function matchValue(name: string): string
	local folder = ReplicatedStorage:FindFirstChild("MatchState")
	local value = folder and folder:FindFirstChild(name)
	return if value and value:IsA("StringValue") then value.Value else ""
end

-- Shared/ServerRole's attribute. Polled: it can arrive with ReplicatedStorage's first snapshot, which fires no
-- changed signal (a GetAttributeChangedSignal wait hung here, measured 2026-11-22).
local function role(): string
	local deadline = os.clock() + 15
	local value = ReplicatedStorage:GetAttribute("ServerRole")
	while value == nil and os.clock() < deadline do
		task.wait(0.05)
		value = ReplicatedStorage:GetAttribute("ServerRole")
	end
	return if value == "Match" then "Match" else "Lobby"
end

-- Close -------------------------------------------------------------------------------

local function close(bed: Sound?)
	local fade = TweenInfo.new(cfg.fadeOut, QUINT_OUT, Enum.EasingDirection.In)
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
	tween(
		fit,
		cfg.fadeOut,
		{ Scale = fit.Scale * 1.03 },
		Enum.EasingStyle.Quint,
		Enum.EasingDirection.In
	)
	tween(blur, cfg.fadeOut * 2, { Size = 0 })
	if bed then
		local out = typeof(cfg.bed) == "table" and cfg.bed.fadeOut or 0.6
		tween(bed, out, { Volume = 0 }).Completed:Once(function()
			bed:Destroy()
		end)
	end
	task.wait(cfg.fadeOut + 0.05)
	frame:Disconnect()
	gui:Destroy()
	task.delay(cfg.fadeOut, function()
		blur:Destroy()
	end)
	player:SetAttribute("LoadingScreen", false)
end

-- At a match's end the next teleport (back to the lobby) shows this screen too.
local function armHomeTeleport()
	local template = ReplicatedFirst:FindFirstChild("DuelsLoading")
	if not (template and template:IsA("ScreenGui")) then
		return
	end
	local armed = false
	local function check()
		if armed or matchValue("Phase") ~= '"MatchEnd"' then
			return
		end
		armed = true
		local copy = template:Clone()
		local c = copy:FindFirstChild("Canvas")
		local mode = c and c:FindFirstChild("Mode")
		if mode and mode:IsA("TextLabel") then
			mode.Text = if typeof(cfg.homeLine) == "string"
				then cfg.homeLine
				else "BACK TO THE LOBBY"
			mode.Visible = true
		end
		local tips = cfg.tips
		local tip = c and c:FindFirstChild("Tip")
		if tip and tip:IsA("TextLabel") and tips and #tips > 0 then
			tip.Text = "TIP  /  " .. tips[math.random(1, #tips)]
		end
		local camera = workspace.CurrentCamera
		if camera then
			LoadingLayout.fit(copy, cfg, camera.ViewportSize) -- the teleport shows it as it is
		end
		copy.Enabled = true
		local ok, err = pcall(TeleportService.SetTeleportGui, TeleportService, copy)
		if not ok then
			warn("[Loading] SetTeleportGui failed: " .. tostring(err))
		end
	end
	task.spawn(function()
		while true do
			check()
			if armed then
				return
			end
			task.wait(1)
		end
	end)
end

-- Run ---------------------------------------------------------------------------------

local started = os.clock()
local isMatch = role() == "Match"
local deadline = started + (if isMatch then FALLBACK.watchdogMatch else FALLBACK.watchdogLobby)
stepCount = 4

if not revealed then
	hideLogo()
end
-- The logo and the config first (capped), so the reveal and its sting land together.
task.spawn(function()
	pcall(ContentProvider.PreloadAsync, ContentProvider, { ticket, duels, full })
end)
waitFor(function()
	return configReady
		and ContentProvider:GetAssetFetchStatus(ticket.Image) ~= Enum.AssetFetchStatus.Loading
		and ContentProvider:GetAssetFetchStatus(duels.Image) ~= Enum.AssetFetchStatus.Loading
end, os.clock() + (cfg.assetWait or FALLBACK.assetWait))
deadline = started + (if isMatch then cfg.watchdogMatch else cfg.watchdogLobby)

local bed = sound(cfg.bed, true)
if bed then
	bed:Play()
	tween(bed, cfg.bed.fadeIn or 1.2, { Volume = cfg.bed.volume or 0.18 }, Enum.EasingStyle.Sine)
end
local revealAt = os.clock()
if not revealed then
	local sting = sound(cfg.sting, false)
	reveal(sting)
	if sting then
		task.delay(6, function()
			sting:Destroy()
		end)
	end
end

local done = true
stage("connecting", "CONNECTING")
done = waitFor(function()
	return game:IsLoaded()
end, deadline) and done
advance()

stage("data", "LOADING YOUR DATA")
done = waitFor(function()
	return stateValue(player, "DataReady") == "t"
end, deadline) and done
advance()

if isMatch then
	stage("match", "SETTING UP THE MATCH")
	done = waitFor(function()
		return player:GetAttribute("MatchScreensReady") ~= nil
	end, deadline) and done
	advance()
	stage("players", "WAITING FOR PLAYERS")
	done = waitFor(function()
		local expected = tonumber(matchValue("ExpectedPlayers"))
		local ready = tonumber(matchValue("ReadyPlayers")) or 0
		countLabel.Text = if expected and expected > 0
			then string.format("%d / %d", ready, expected)
			else ""
		local phase = matchValue("Phase")
		return phase ~= "" and phase ~= '"Waiting"'
	end, deadline) and done
	advance()
else
	stage("body", "GETTING YOUR FIGHTER READY")
	done = waitFor(function()
		local character = player.Character
		return character ~= nil and character:FindFirstChild("HumanoidRootPart") ~= nil
	end, deadline) and done
	advance()
	stage("lobby", "OPENING THE LOBBY")
	done = waitFor(function()
		return player:GetAttribute("LobbyClientReady") == true
	end, deadline) and done
	advance()
end

countLabel.Text = ""
stage("ready", "READY")
local hold = (cfg.minHold or FALLBACK.minHold) - (os.clock() - revealAt)
if hold > 0 and not revealed then
	task.wait(hold)
end
if not done then
	warn(
		string.format(
			"[Health] C loading screen closed by the watchdog after %.1fs (%s)",
			os.clock() - started,
			stageLabel.Text
		)
	)
else
	print(
		string.format(
			"[Health] C loading screen done %s+%.1fs",
			player.Name .. " ",
			os.clock() - started
		)
	)
end
close(bed)
if isMatch then
	armHomeTeleport()
end
