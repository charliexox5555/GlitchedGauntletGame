--!strict
-- The loading screen v2 (vault/05 Production/Handoff - Stability, Loading and Preload.md → Phase 2; RIVALS study:
-- vault/03 Research/Rivals Reference/Loading Screen.md). Runs first on every join, in both server roles:
--  * Shows ReplicatedFirst.DuelsLoading (Studio-built, tools/studio/BuildDuelsLoading.luau), or takes over the copy
--    Roblox showed during a teleport (MatchFoundController, or this script at a match's end) so nothing flashes.
--  * Motion (v2.1, owner 2026-11-22: "longer" and "improved animation"): the diagonal slashes drift the whole time;
--    the brand band sweeps in; the PowerDuels reveal (2026-11-25, vault/02 Art/PowerDuels Logo.md: POWER from the
--    upper left, then DUELS rises, then the sparks pop) with the sting on POWER's landing over a quiet music bed; a shine crosses the title; the title floats while
--    it waits; the stage word slides up between stages; each of the four segments fills gold as its real stage
--    finishes (the working one breathes); READY gets a second shine; the close zooms the title through and fades
--    the backdrop while the blur clears.
--  * Stages (no fake bar): Lobby = connected → data → fighter → lobby client; Match = connected → data → match
--    screens → every player in (the server leaves "Waiting"). Each stage shows at least Config/Loading.stepMin.
--  * Holds at least Config/Loading.minHold from the reveal (owner: no skip) and always closes by the watchdog.
-- Clients mark their stages with local Player attributes (LobbyClientReady, MatchScreensReady); this script sets
-- LoadingScreen while it shows (LobbyMusic waits for it). No remotes. Self-contained until Shared replicates:
-- everything from Shared is waited for with a timeout. Reduced motion: no drift, float or shine; the title fades in.

local ContentProvider = game:GetService("ContentProvider")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
player:SetAttribute("LoadingScreen", true)
local playerGui = player:WaitForChild("PlayerGui")
if playerGui:IsA("PlayerGui") then
	playerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
end
local LoadingLayout = require(script.Parent:WaitForChild("LoadingLayout") :: ModuleScript)

-- Only until Config/Loading arrives (or if it never does).
local FALLBACK = {
	minHold = 2.2,
	stepMin = 0.3,
	assetWait = 3,
	watchdogLobby = 30,
	watchdogMatch = 120,
	fadeOut = 0.8,
	fill = 0.4,
	blur = 24,
	phoneHeight = 600,
	phoneBoost = 1.3,
	phoneY = {
		Mode = 230,
		Logo = 430,
		Pips = 650,
		Spinner = 650,
		StageClip = 692,
		Count = 728,
		Tip = 905,
	},
	motion = {
		stripeSpeed = 0.012,
		floatAmp = 0.012,
		floatSpeed = 1.5,
		swayDeg = 1.2,
		shine = 0.75,
		pulse = 1.1,
	},
}
local QUINT = Enum.EasingStyle.Quint
local OUT = Enum.EasingDirection.Out
local IN = Enum.EasingDirection.In
local SEGMENTS = 4

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
		player:SetAttribute("LoadingScreen", false)
		return
	end
	gui = template:Clone()
end
gui.Name = "DuelsLoading"
gui.Enabled = true
gui.Parent = playerGui
ReplicatedFirst:RemoveDefaultLoadingScreen()
player:SetAttribute("LoadingScreen", true)

local function need<T>(parent: Instance, name: string): T
	return parent:WaitForChild(name, 5) :: any
end

local canvas = need(gui, "Canvas") :: Frame
local logo = need(canvas, "Logo") :: Frame
local logoPop = need(logo, "Pop") :: UIScale
local ticket = need(logo, "Ticket") :: ImageLabel
local duels = need(logo, "Duels") :: ImageLabel
local full = need(logo, "Full") :: ImageLabel
local shine = need(logo, "Shine") :: ImageLabel
-- Optional (PowerDuels, 2026-11-25): a copy built before the sparks has none.
local sparksFound = logo:FindFirstChild("Sparks")
local sparks: ImageLabel? = if sparksFound and sparksFound:IsA("ImageLabel")
	then sparksFound
	else nil
local shineBand = need(shine, "Band") :: UIGradient
local slash = need(canvas, "Slash") :: Frame
local slashWipe = need(slash, "Wipe") :: UIGradient
local pips = need(canvas, "Pips") :: Frame
local stageClip = need(canvas, "StageClip") :: Frame
local stageLabel = need(stageClip, "Stage") :: TextLabel
local countLabel = need(canvas, "Count") :: TextLabel
local tipLabel = need(canvas, "Tip") :: TextLabel
local spinner = need(canvas, "Spinner") :: Frame
local stripes = gui:FindFirstChild("Stripes")
local scroll = stripes and stripes:FindFirstChild("Scroll")
local spinStroke = spinner:FindFirstChildWhichIsA("UIStroke")
local turnFound = spinStroke and spinStroke:FindFirstChild("Turn")
local turn: UIGradient? = if turnFound and turnFound:IsA("UIGradient") then turnFound else nil

local pipFills: { Frame } = {}
local pipPulses: { UIGradient } = {}
for i = 1, SEGMENTS do
	local pip = pips:FindFirstChild("Pip" .. i)
	local f = pip and pip:FindFirstChild("Fill")
	local p = pip and pip:FindFirstChild("Pulse")
	if f and f:IsA("Frame") and p and p:IsA("UIGradient") then
		pipFills[i] = f
		pipPulses[i] = p
	end
end

local cfg: any = FALLBACK
local function motion(key: string): number
	local m = cfg.motion
	return if typeof(m) == "table" and typeof(m[key]) == "number"
		then m[key]
		else (FALLBACK.motion :: any)[key]
end

local function scaleCanvas()
	LoadingLayout.fit(gui, cfg)
end
scaleCanvas()
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(scaleCanvas)

local reduced = false
pcall(function()
	reduced = (GuiService :: any).ReducedMotionEnabled == true
end)

-- Every frame: the spinner, the slash drift, the title float, the working segment's breath.
local floating = false
local floatFrom = 0
local working = 0 -- the segment being worked on (0: none)
local frame = RunService.RenderStepped:Connect(function(dt: number)
	local now = os.clock()
	if turn then
		turn.Rotation = (turn.Rotation + dt * 300) % 360
	end
	if reduced then
		return
	end
	if scroll and scroll:IsA("Frame") then
		local bars = scroll:GetAttribute("Bars")
		local gap = 1.25 / (if typeof(bars) == "number" and bars > 0 then bars else 30)
		local x = (scroll.Position.X.Scale - dt * motion("stripeSpeed")) % -gap
		scroll.Position = UDim2.fromScale(if x > 0 then x - gap else x, 0)
	end
	if floating then
		local t = now - floatFrom
		local y = 0.5 + math.sin(t * motion("floatSpeed")) * motion("floatAmp")
		local rest = UDim2.fromScale(0.5, y)
		ticket.Position = UDim2.fromScale(
			0.5,
			y - motion("floatAmp") * 0.35 * math.sin(t * motion("floatSpeed") * 0.7)
		)
		duels.Position = rest
		shine.Position = rest
		full.Position = rest
		ticket.Rotation = math.sin(t * motion("floatSpeed") * 0.75) * motion("swayDeg")
		if sparks then
			-- the sparks ride with the POWER badge and twinkle a little
			sparks.Position = ticket.Position
			sparks.Rotation = ticket.Rotation
			sparks.ImageTransparency = 0.12 + 0.12 * math.sin(t * motion("floatSpeed") * 2.3)
		end
	end
	local pulse = pipPulses[working]
	if pulse then
		pulse.Offset = Vector2.new(((now / motion("pulse")) % 1) * 2 - 1, 0)
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

-- Motion helpers ----------------------------------------------------------------------

local function tween(
	inst: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
): Tween
	local t = TweenService:Create(inst, TweenInfo.new(seconds, style or QUINT, dir or OUT), goal)
	t:Play()
	return t
end

local REST = UDim2.fromScale(0.5, 0.5)

local function sweepShine()
	if reduced then
		return
	end
	shine.Visible = true
	shineBand.Offset = Vector2.new(-1, 0)
	tween(
		shineBand,
		motion("shine"),
		{ Offset = Vector2.new(1, 0) },
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.InOut
	)
end

local function hideLogo()
	shine.Visible = false
	if reduced then
		ticket.Visible, duels.Visible, full.Visible = false, false, true
		full.ImageTransparency = 1
		if sparks then
			sparks.Visible = false -- the full mark holds the sparks
		end
	else
		ticket.ImageTransparency, duels.ImageTransparency = 1, 1
		if sparks then
			sparks.ImageTransparency = 1
		end
		slashWipe.Offset = Vector2.new(-1, 0)
	end
end

-- The band sweeps in, then the PowerDuels beats (art-source/ui/powerduels/powerduels-reveal.gif, times from the
-- band's start + 0.12): POWER in from the upper left (tilted, from 92%) by 0.235 s with the sting on its landing;
-- DUELS enters at 0.185 s and rises into place by 0.5 s with a small punch; the sparks pop from 0.34 s; the whole
-- title settles from 96%; a shine; then it floats.
local function reveal(sting: Sound?)
	if reduced then
		tween(full, 0.5, { ImageTransparency = 0 })
		if sting then
			sting:Play()
		end
		return
	end
	tween(slashWipe, 0.45, { Offset = Vector2.zero })
	-- lihfolk-ignore: findfirstchild-chain (stored and nil-checked below)
	local ticketPop = ticket:FindFirstChild("Pop") :: UIScale?
	-- lihfolk-ignore: findfirstchild-chain (stored and nil-checked below)
	local duelsPop = duels:FindFirstChild("Pop") :: UIScale?
	logoPop.Scale = 0.96
	tween(logoPop, 0.9, { Scale = 1 })
	task.delay(0.12, function()
		ticket.Position = UDim2.fromScale(0.42, 0.38)
		ticket.Rotation = -7
		if ticketPop then
			ticketPop.Scale = 0.92
			tween(ticketPop, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		end
		tween(
			ticket,
			0.235,
			{ Position = REST, ImageTransparency = 0, Rotation = 0 },
			Enum.EasingStyle.Back
		)
	end)
	task.delay(0.12 + (if cfg.sting then cfg.sting.at else 0.235), function()
		if sting then
			sting:Play()
		end
	end)
	duels.Position = UDim2.fromScale(0.5, 0.63)
	task.delay(0.12 + 0.185, function()
		tween(duels, 0.315, { Position = REST, ImageTransparency = 0 })
		if duelsPop then
			duelsPop.Scale = 0.97
			task.delay(0.14, function()
				tween(duelsPop, 0.07, { Scale = 1.03 }, Enum.EasingStyle.Quad).Completed:Once(
					function()
						tween(duelsPop, 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
					end
				)
			end)
		end
	end)
	local sp = sparks
	if sp then
		-- lihfolk-ignore: findfirstchild-chain (stored and nil-checked below)
		local sparksPop = sp:FindFirstChild("Pop") :: UIScale?
		task.delay(0.12 + 0.34, function()
			sp.Position = REST
			if sparksPop then
				sparksPop.Scale = 0.7
				tween(sparksPop, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
			end
			tween(sp, 0.18, { ImageTransparency = 0 }, Enum.EasingStyle.Quad)
		end)
	end
	task.delay(0.95, function()
		sweepShine()
		floatFrom = os.clock()
		floating = true
	end)
end

-- Stages ------------------------------------------------------------------------------

local stepIndex = 0
local function stage(key: string, fallback: string)
	local words = cfg.stages
	local text = if words and typeof(words[key]) == "string" then words[key] else fallback
	if stageLabel.Text == text then
		return
	end
	if reduced then
		stageLabel.Text = text
		return
	end
	-- The old word slides up and out, the new one comes up from below.
	local outgoing = stageLabel:Clone()
	outgoing.Parent = stageClip
	tween(
		outgoing,
		0.22,
		{ Position = UDim2.fromScale(0.5, -0.6), TextTransparency = 1 },
		QUINT,
		IN
	).Completed:Once(function()
		outgoing:Destroy()
	end)
	-- The new word waits until the old one is mostly out, so the two never overlap.
	stageLabel.Text = text
	stageLabel.Position = UDim2.fromScale(0.5, 1.6)
	stageLabel.TextTransparency = 1
	TweenService:Create(
		stageLabel,
		TweenInfo.new(0.3, QUINT, OUT, 0, false, 0.16),
		{ Position = REST, TextTransparency = 0 }
	):Play()
end

local function setWorking(i: number)
	local old = pipPulses[working]
	if old then
		old.Enabled = false
	end
	working = i
	local now = pipPulses[i]
	if now and not reduced then
		now.Enabled = true
	end
end

local stepStarted = os.clock()
local function advance()
	-- Each stage is on screen at least stepMin, so the segments fill one by one.
	local left = (cfg.stepMin or FALLBACK.stepMin) - (os.clock() - stepStarted)
	if left > 0 then
		task.wait(left)
	end
	stepIndex += 1
	local fillFrame = pipFills[stepIndex]
	if fillFrame then
		tween(fillFrame, cfg.fill or FALLBACK.fill, { Size = UDim2.fromScale(1, 1) })
	end
	setWorking(stepIndex + 1)
	stepStarted = os.clock()
end

-- Until Config/Loading arrives: the longest wait for the save (s), the lobby stage's streaming wait (s) and floor
-- probe (studs).
local DATA_WAIT = 8
local SKIN_WAIT = 4
local STREAM_WAIT = 8
local GROUND_PROBE = 40

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

local hostedMatchId: string? = nil

local function matchValue(name: string): string
	local folder: Instance?
	if hostedMatchId then
		local matches = ReplicatedStorage:FindFirstChild("Matches")
		folder = matches and matches:FindFirstChild(hostedMatchId)
	else
		folder = ReplicatedStorage:FindFirstChild("MatchState")
	end
	local value = folder and folder:FindFirstChild(name)
	return if value and value:IsA("StringValue") then value.Value else ""
end

-- Shared/ServerRole attributes. Polled: they can arrive with ReplicatedStorage's first snapshot, which fires no
-- changed signal (a GetAttributeChangedSignal wait hung here, measured 2026-11-22).
local function serverInfo(): (string, boolean)
	local waitDeadline = os.clock() + 15
	local value = ReplicatedStorage:GetAttribute("ServerRole")
	while value == nil and os.clock() < waitDeadline do
		task.wait(0.05)
		value = ReplicatedStorage:GetAttribute("ServerRole")
	end
	if value == "Match" then
		return "Match", false
	end
	local hostedDeadline = math.min(waitDeadline, os.clock() + 3)
	local hosted = ReplicatedStorage:GetAttribute("HostedServer")
	while hosted == nil and os.clock() < hostedDeadline do
		task.wait(0.05)
		hosted = ReplicatedStorage:GetAttribute("HostedServer")
	end
	return "Lobby", hosted == true
end

-- Close -------------------------------------------------------------------------------

local function fadeAll(
	root: Instance,
	seconds: number,
	delay: number,
	skip: { [Instance]: boolean }
)
	local info = TweenInfo.new(seconds, QUINT, Enum.EasingDirection.InOut, 0, false, delay)
	for _, d in root:GetDescendants() do
		if skip[d] then
			continue
		end
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
				TweenService:Create(d, info, goal):Play()
			end
		elseif d:IsA("UIStroke") then
			TweenService:Create(d, info, { Transparency = 1 }):Play()
		end
	end
end

-- The words and segments drop out first, the title zooms through and fades, then the backdrop goes while the
-- blur clears.
local function close(bed: Sound?)
	local out = cfg.fadeOut or FALLBACK.fadeOut
	floating = false
	setWorking(0)
	local titleImages = { ticket, duels, full, shine }
	if sparks then
		table.insert(titleImages, sparks)
	end
	local keep: { [Instance]: boolean } = {}
	for _, image in titleImages do
		keep[image] = true
	end
	fadeAll(canvas, 0.25, 0, keep)
	if not reduced then
		tween(logoPop, out * 0.6, { Scale = 1.1 }, QUINT, OUT)
	end
	-- The title is gone before the backdrop, so it never hangs over the world.
	for _, image in titleImages do
		tween(image, out * 0.55, { ImageTransparency = 1 }, Enum.EasingStyle.Quad, OUT)
	end
	if stripes then
		fadeAll(stripes, out * 0.4, 0, {})
	end
	local backdropFade = TweenInfo.new(out, QUINT, Enum.EasingDirection.InOut, 0, false, out * 0.25)
	for _, layer in gui:GetChildren() do
		if layer:IsA("GuiObject") and layer ~= canvas and layer.BackgroundTransparency < 1 then
			TweenService:Create(layer, backdropFade, { BackgroundTransparency = 1 }):Play()
		end
	end
	tween(blur, out * 1.8, { Size = 0 })
	if bed then
		local fadeBed = typeof(cfg.bed) == "table" and cfg.bed.fadeOut or 0.6
		tween(bed, fadeBed, { Volume = 0 }).Completed:Once(function()
			bed:Destroy()
		end)
	end
	task.wait(out * 1.35 + 0.05)
	frame:Disconnect()
	gui:Destroy()
	task.delay(out, function()
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
	task.spawn(function()
		while matchValue("Phase") ~= '"MatchEnd"' do
			task.wait(1)
		end
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
	end)
end

-- Run ---------------------------------------------------------------------------------

local started = os.clock()
local serverRole, isHosted = serverInfo()
local isMatch = serverRole == "Match"
local deadline = started
	+ (if isMatch or isHosted then FALLBACK.watchdogMatch else FALLBACK.watchdogLobby)

if revealed then
	floatFrom = os.clock()
	floating = true
else
	hideLogo()
end
setWorking(1)
-- The title and the config first (capped), so the reveal and its sting land together.
task.spawn(function()
	local title: { Instance } = { ticket, duels, full, shine }
	if sparks then
		table.insert(title, sparks)
	end
	pcall(ContentProvider.PreloadAsync, ContentProvider, title)
end)
waitFor(function()
	return configReady
		and ContentProvider:GetAssetFetchStatus(ticket.Image) ~= Enum.AssetFetchStatus.Loading
		and ContentProvider:GetAssetFetchStatus(duels.Image) ~= Enum.AssetFetchStatus.Loading
end, os.clock() + (cfg.assetWait or FALLBACK.assetWait))
deadline = started + (if isMatch or isHosted then cfg.watchdogMatch else cfg.watchdogLobby)

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
		task.delay(8, function()
			sting:Destroy()
		end)
	end
end
stepStarted = os.clock()

local done = true
stage("connecting", "CONNECTING")
done = waitFor(function()
	return game:IsLoaded()
end, deadline) and done
advance()

if not isMatch and isHosted then
	local zoneDeadline = math.min(deadline, os.clock() + 6)
	while os.clock() < zoneDeadline do
		local zone = player:GetAttribute("PlayZone")
		local id = player:GetAttribute("MatchId")
		if zone == "Match" and typeof(id) == "string" then
			hostedMatchId = id
			isMatch = true
			break
		end
		local char = player.Character
		if char and char:GetAttribute("SpawnZone") == "Lobby" then
			break
		end
		task.wait(0.05)
	end
end
deadline = started
	+ (
		if isMatch
			then (cfg.watchdogMatch or FALLBACK.watchdogMatch)
			else (cfg.watchdogLobby or FALLBACK.watchdogLobby)
	)

stage("data", "LOADING YOUR DATA")
-- Capped (owner 2026-11-22: stuck on this stage, and a match started without him): the screens that need the
-- save (Shop, onboarding) wait for DataReady themselves, so a slow or failing save read never holds the player
-- here; the [Health] line says it happened.
local dataReady = waitFor(function()
	return stateValue(player, "DataReady") == "t"
end, math.min(deadline, os.clock() + ((cfg :: any).dataWait or DATA_WAIT)))
if not dataReady then
	warn("[Health] C loading: save not loaded yet, opening anyway (it keeps loading)")
end
-- Your equipped gun skins (Shared/SkinStore: delivered on demand, the server sends these on join) are here
-- before the screen opens, so no gun ever shows its stock look for a moment (owner 2026-11-22).
local jsonCache: { [Instance]: { raw: string, data: any } } = {}
local function json(v: Instance?): any
	if not (v and v:IsA("StringValue")) or v.Value == "" then
		return nil
	end
	local raw = v.Value
	local cached = jsonCache[v]
	if cached and cached.raw == raw then
		return cached.data
	end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
	local result = if ok then data else nil
	jsonCache[v] = { raw = raw, data = result }
	return result
end
local function skinsReady(): boolean
	local locker = json(player:FindFirstChild("LockerSkins"))
	if typeof(locker) ~= "table" then
		return false -- the Locker hasn't loaded yet
	end
	local manifest = json(ReplicatedStorage:FindFirstChild("SkinManifest"))
	local delivery = playerGui:FindFirstChild("SkinDelivery")
	for gun, line in locker :: { [any]: any } do
		if typeof(gun) ~= "string" or typeof(line) ~= "string" or line == "Stock" then
			continue
		end
		local name = if gun == "Knife" and line == "PopCircuit" then "Bat" else gun
		if typeof(manifest) ~= "table" then
			return false
		end
		local listed = false
		if typeof(manifest[line]) == "table" then
			listed = table.find(manifest[line], name) ~= nil
		end
		if listed then
			local folder = delivery and delivery:FindFirstChild(line)
			if not (folder and folder:FindFirstChild(name)) then
				return false
			end
		end
	end
	return true
end
if
	isMatch
	and dataReady
	and not waitFor(
		skinsReady,
		math.min(deadline, os.clock() + ((cfg :: any).skinWait or SKIN_WAIT))
	)
then
	warn("[Health] C loading: equipped skins not all here yet, opening anyway")
end
advance()

if isMatch then
	stage("match", "SETTING UP THE MATCH")
	done = waitFor(function()
		local readyId = player:GetAttribute("MatchScreensReady")
		return if hostedMatchId then readyId == hostedMatchId else readyId ~= nil
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
		if phase == '"Cancelled"' then
			stageLabel.Text = "MATCH CANCELLED — RE-QUEUEING"
			return true
		end
		return phase ~= "" and phase ~= '"Waiting"'
	end, deadline) and done
	advance()
else
	stage("body", "GETTING YOUR FIGHTER READY")
	done = waitFor(function()
		if player:GetAttribute("PlayZone") == "Match" then
			return true
		end
		local character = player.Character
		return character ~= nil and character:FindFirstChild("HumanoidRootPart") ~= nil
	end, deadline) and done
	-- The lobby around the spawn streamed in before the screen opens (owner 2026-11-22: "stuck in a void for a
	-- bit"): ask for the area, then wait for floor under the feet, up to STREAM_WAIT seconds (inside the watchdog).
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if player:GetAttribute("PlayZone") ~= "Match" and root and root:IsA("BasePart") then
		local streamFor = (cfg :: any).streamWait or STREAM_WAIT
		local probe = (cfg :: any).groundProbe or GROUND_PROBE
		local streamUntil = math.min(os.clock() + streamFor, deadline)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.RespectCanCollide = true
		params.FilterDescendantsInstances = { character :: Instance }
		local function hasFloor(): boolean
			return root.Parent ~= nil
				and workspace:Raycast(root.Position, Vector3.new(0, -probe, 0), params) ~= nil
		end
		local grounded = hasFloor()
		if not grounded then
			local position = root.Position
			task.spawn(function()
				pcall(player.RequestStreamAroundAsync, player, position, streamFor)
			end)
			grounded = waitFor(hasFloor, streamUntil)
		end
		if not grounded then
			warn("[Health] C loading: no floor under the spawn after streaming (continuing)")
		end
	end
	advance()
	stage("lobby", "OPENING THE LOBBY")
	done = waitFor(function()
		return player:GetAttribute("LobbyClientReady") == true
	end, deadline) and done
	if player:GetAttribute("PlayZone") == "Match" then
		stage("match", "SETTING UP THE MATCH")
		done = waitFor(function()
			if player:GetAttribute("PlayZone") ~= "Match" then
				return true
			end
			local id = player:GetAttribute("MatchId")
			return typeof(id) == "string" and player:GetAttribute("MatchScreensReady") == id
		end, deadline) and done
	end
	advance()
end

countLabel.Text = ""
setWorking(0)
stage("ready", "READY")
sweepShine()
local hold = (cfg.minHold or FALLBACK.minHold) - (os.clock() - revealAt)
if not revealed then
	hold = math.max(hold, motion("shine") + 0.2)
	task.wait(hold)
else
	task.wait(motion("shine") + 0.2)
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
		string.format("[Health] C loading screen done %s +%.1fs", player.Name, os.clock() - started)
	)
end
close(bed)
if serverRole == "Match" then
	armHomeTeleport()
end
