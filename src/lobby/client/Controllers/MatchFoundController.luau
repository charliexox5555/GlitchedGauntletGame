--!strict
-- MATCH FOUND (vault/02 Art/UI Play and Party Menus.md → Match found), on
-- every device: when the server finds your match (QueueEvent "found") the
-- screen dims and blurs and three white dots pulse in turn in the middle,
-- like RIVALS, until the teleport. No teams or names (owner 2026-11-15: "just
-- a little overlay"). Studio-built StarterGui.LobbyMatchFound (backup
-- tools/studio/BuildMatchFound.luau); this only shows and animates it.
--
-- Also turns QueueEvent "failed" / "info" into toasts, and blocks menus while
-- it's up. It closes when the server puts you back to idle (a failed
-- teleport, or Studio's skipped one).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local LoadingConfig = require(game:GetService("ReplicatedStorage").Shared.Config.Loading)
local UiSfx = require(game:GetService("ReplicatedStorage").Shared.UiSfx)
local LobbyNet = require(game:GetService("ReplicatedStorage").Lobby.LobbyNet)
local QueueState = require(script.Parent.Parent.Util.QueueState)
local Router = require(script.Parent.Parent.Util.Router)
local LobbyHud = require(script.Parent.LobbyHud)
local MatchLift = require(script.Parent.Parent.Util.MatchLift)
local UiMotion = require(game:GetService("ReplicatedStorage").Shared.UiMotion) -- the one motion module

local MatchFoundController = {}

local player = Players.LocalPlayer
local QUINT = Enum.EasingStyle.Quint
local IN = Enum.EasingDirection.In
local SCRIM_T = 0.2 -- the scrim's see-through when shown
local BLUR = 20
-- The dots ride one continuous wave, drawn every frame (no chained tweens,
-- so nothing steps): each swells to 1 + SWELL and back over PERIOD seconds,
-- a third of a cycle after the one before it.
local SWELL = 0.42
local PERIOD = 1.2
local EASE_IN = 0.45 -- the wave fades in over this after the dots pop in

local gui: ScreenGui
local scrim: Frame
local studioLabel: TextLabel
local pops: { UIScale } = {}
local blur: BlurEffect
local isOpen = false
local token = 0

local tween = UiMotion.tween

local function child<T>(parent: Instance, name: string): T
	return (parent:WaitForChild(name) :: any) :: T
end

local waveConn: RBXScriptConnection? = nil

-- A smooth, peaked bump in [0, 1] for a phase in [0, 1): rest, swell, rest.
local function bump(phase: number): number
	local c = 0.5 - 0.5 * math.cos(phase * 2 * math.pi)
	return c * c
end

local function startWave(my: number)
	local started = os.clock() + 0.46 -- once the last dot has popped in (0.12 + 0.32)
	if waveConn then
		waveConn:Disconnect()
	end
	waveConn = RunService.RenderStepped:Connect(function()
		if token ~= my then
			return
		end
		local t = os.clock() - started
		if t < 0 then
			return
		end
		local amount = math.clamp(t / EASE_IN, 0, 1)
		amount = amount * amount * (3 - 2 * amount) -- smoothstep
		for i, pop in pops do
			local phase = (t / PERIOD - (i - 1) / 3) % 1
			pop.Scale = 1 + SWELL * amount * bump(phase)
		end
	end)
end

local function stopWave()
	if waveConn then
		waveConn:Disconnect()
		waveConn = nil
	end
end

-- The loading screen Roblox shows during the teleport: a copy of the loading screen v2
-- (ReplicatedFirst.DuelsLoading, tools/studio/BuildDuelsLoading.luau) with the mode line and a tip; the arriving
-- server's ReplicatedFirst script (src/first/LoadingScreen.client.luau) takes it over until the match is ready.
local function setTeleportGui()
	local template = game:GetService("ReplicatedFirst"):FindFirstChild("DuelsLoading")
	if not (template and template:IsA("ScreenGui")) then
		return
	end
	local copy = template:Clone()
	local canvas = copy:FindFirstChild("Canvas")
	local mode = canvas and canvas:FindFirstChild("Mode")
	local id = QueueState.mode()
	if mode and mode:IsA("TextLabel") and typeof(id) == "string" then
		mode.Text = string.format(LoadingConfig.modeLine, QueueState.label(id))
		mode.Visible = true
	end
	local stage = canvas and canvas:FindFirstChild("Stage", true)
	if stage and stage:IsA("TextLabel") then
		stage.Text = LoadingConfig.stages.connecting
	end
	local tip = canvas and canvas:FindFirstChild("Tip")
	local tips = LoadingConfig.tips
	if tip and tip:IsA("TextLabel") and #tips > 0 then
		tip.Text = "TIP  /  " .. tips[math.random(1, #tips)]
	end
	-- The canvas at this screen's scale (the teleport shows it as it is).
	local layout = game:GetService("ReplicatedFirst"):FindFirstChild("LoadingLayout", true)
	local camera = workspace.CurrentCamera
	if layout and layout:IsA("ModuleScript") and camera then
		require(layout).fit(copy, LoadingConfig :: any, camera.ViewportSize)
	end
	copy.Enabled = true
	local ok, err = pcall(function()
		TeleportService:SetTeleportGui(copy)
	end)
	if not ok then
		warn("[MatchFound] SetTeleportGui failed: " .. tostring(err))
	end
end

-- Handed to Roblox once per "found", the moment it arrives (see openAfterLift).
local teleportGuiSet = false

local function open()
	if isOpen then
		return
	end
	if not teleportGuiSet then
		teleportGuiSet = true
		setTeleportGui()
	end
	isOpen = true
	token += 1
	local my = token
	Router.close()
	gui.Enabled = true
	studioLabel.Visible = false
	scrim.BackgroundTransparency = 1
	tween(scrim, 0.3, { BackgroundTransparency = SCRIM_T })
	blur.Enabled = true
	tween(blur, 0.3, { Size = BLUR })
	for i, pop in pops do
		pop.Scale = 0
		task.delay((i - 1) * 0.06, function()
			if token == my then
				tween(pop, 0.32, { Scale = 1 })
			end
		end)
	end
	startWave(my)
end

local function close()
	teleportGuiSet = false
	if not isOpen then
		return
	end
	isOpen = false
	token += 1
	local my = token
	stopWave()
	tween(scrim, 0.25, { BackgroundTransparency = 1 }, QUINT, IN)
	tween(blur, 0.25, { Size = 0 }, QUINT, IN)
	for _, pop in pops do
		tween(pop, 0.2, { Scale = 0 }, QUINT, IN)
	end
	task.delay(0.26, function()
		if token == my then
			gui.Enabled = false
			blur.Enabled = false
		end
	end)
end

-- Standing on a Lobby V5 queue bay: the lift (Util/MatchLift) plays first and the overlay comes in after it.
local pendingOpen = false
local liftToken = 0
local function openAfterLift()
	if isOpen or pendingOpen then
		return
	end
	-- The teleport screen goes to Roblox now, not after the lift: the server teleports Config.matchFoundDelay
	-- (2 s) after "found", sooner than the lift's hold ends, and a teleport that starts before SetTeleportGui shows
	-- Roblox's plain screen instead of ours (vault/04 Tech/Loading and Performance 2026-11-27.md).
	if not teleportGuiSet then
		teleportGuiSet = true
		setTeleportGui()
	end
	local hold = MatchLift.play()
	if hold <= 0 then
		open()
		return
	end
	pendingOpen = true
	liftToken += 1
	local my = liftToken
	task.delay(hold, function()
		if pendingOpen and my == liftToken then
			pendingOpen = false
			open()
		end
	end)
end

-- The queue left "found" without a teleport: cancel a pending overlay and put the lift back.
local function cancelLift()
	teleportGuiSet = false
	pendingOpen = false
	liftToken += 1
	MatchLift.stop()
end

local function onQueueEvent(payload: unknown)
	if typeof(payload) ~= "table" then
		return
	end
	local data = payload :: { [string]: unknown }
	local kind = data.kind
	if kind == "found" then
		openAfterLift()
	elseif kind == "studio" then
		if isOpen then
			studioLabel.Visible = true
		end
	elseif kind == "failed" and typeof(data.text) == "string" then
		cancelLift()
		close()
		LobbyHud.toast(data.text :: string, "error")
	elseif kind == "info" and typeof(data.text) == "string" then
		LobbyHud.toast(data.text :: string, "info")
	end
end

function MatchFoundController.init()
	local g = player:WaitForChild("PlayerGui"):WaitForChild("LobbyMatchFound", 15)
	if not g or not g:IsA("ScreenGui") then
		warn("[MatchFound] StarterGui.LobbyMatchFound missing (tools/studio/BuildMatchFound.luau)")
		return
	end
	gui = g
	gui.Enabled = false
	scrim = child(gui, "Scrim")
	local center = child(gui, "Center") :: Frame
	studioLabel = child(center, "Studio")
	local dots = child(center, "Dots") :: Frame
	for i = 1, 3 do
		table.insert(pops, child(child(child(dots, "Dot" .. i), "Circle"), "Pop") :: UIScale)
	end
	blur = Instance.new("BlurEffect")
	blur.Name = "LobbyFoundBlur"
	blur.Size = 0
	blur.Enabled = false
	blur.Parent = Lighting
end

function MatchFoundController.start()
	if not gui then
		return
	end
	Router.setBlocked(function()
		return isOpen
	end)
	LobbyNet.event("QueueEvent").OnClientEvent:Connect(onQueueEvent)
	-- the queue's sounds (vault/02 Art/UI Polish Pass.md → Sounds): searching
	-- starts / stops, the match is found
	local was = QueueState.status()
	QueueState.onChanged(function()
		local s = QueueState.status()
		if s ~= was then
			if s == "searching" and was == "idle" then
				UiSfx.play("QueueJoin")
			elseif s == "idle" and was == "searching" then
				UiSfx.play("QueueLeave")
			elseif s == "found" and was ~= "teleporting" then
				UiSfx.play("MatchFound")
			end
			was = s
		end
		if s == "found" or s == "teleporting" then
			openAfterLift() -- also covers a rejoin mid-found, before the event lands
		else
			if pendingOpen or MatchLift.isActive() then
				cancelLift()
			end
			if isOpen then
				close()
			end
		end
	end)
end

return MatchFoundController
