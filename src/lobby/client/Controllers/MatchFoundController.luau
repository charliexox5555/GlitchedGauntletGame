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
local fit: UIScale
local studioLabel: TextLabel
local pops: { UIScale } = {}
local blur: BlurEffect
local isOpen = false
local token = 0

local tween = UiMotion.tween

local function child<T>(parent: Instance, name: string): T
	return (parent:WaitForChild(name) :: any) :: T
end

local function refit()
	local size = gui.AbsoluteSize
	if size.X > 0 and size.Y > 0 then
		fit.Scale = math.clamp(math.min(size.X / 1920, size.Y / 1080), 0.6, 1.5)
	end
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

-- The loading screen Roblox shows during the teleport (StarterGui.LobbyLoading,
-- tools/studio/BuildLoading.luau): the mode as the hero word and a tip; the
-- match place's ReplicatedFirst script keeps it up until the match loads.
local function setTeleportGui()
	local src = player:FindFirstChild("PlayerGui")
		and player.PlayerGui:FindFirstChild("LobbyLoading")
	if not (src and src:IsA("ScreenGui")) then
		return
	end
	local copy = src:Clone()
	local center = copy:FindFirstChild("Center")
	local mode = center and center:FindFirstChild("Mode")
	local id = QueueState.mode()
	if mode and mode:IsA("TextLabel") and typeof(id) == "string" then
		mode.Text = string.upper(id)
	end
	-- the mode's art from its Play menu tile, faint behind the words
	local art = copy:FindFirstChild("Art")
	local menu = player.PlayerGui:FindFirstChild("PlayMenu")
	local modes = menu and menu:FindFirstChild("Modes", true)
	local tile = modes and typeof(id) == "string" and modes:FindFirstChild(id, true)
	local tileArt = tile and tile:FindFirstChild("Art")
	if art and art:IsA("ImageLabel") and tileArt and tileArt:IsA("ImageLabel") then
		art.Image = tileArt.Image
	end
	local tip = copy:FindFirstChild("Tip")
	local tips = LoadingConfig.tips
	if tip and tip:IsA("TextLabel") and #tips > 0 then
		tip.Text = "TIP  ·  " .. tips[math.random(1, #tips)]
	end
	copy.Enabled = true
	local ok, err = pcall(function()
		TeleportService:SetTeleportGui(copy)
	end)
	if not ok then
		warn("[MatchFound] SetTeleportGui failed: " .. tostring(err))
	end
end

local function open()
	if isOpen then
		return
	end
	setTeleportGui()
	isOpen = true
	token += 1
	local my = token
	Router.close()
	gui.Enabled = true
	refit()
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

local function onQueueEvent(payload: unknown)
	if typeof(payload) ~= "table" then
		return
	end
	local data = payload :: { [string]: unknown }
	local kind = data.kind
	if kind == "found" then
		open()
	elseif kind == "studio" then
		if isOpen then
			studioLabel.Visible = true
		end
	elseif kind == "failed" and typeof(data.text) == "string" then
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
	fit = child(center, "Fit")
	studioLabel = child(center, "Studio")
	local dots = child(center, "Dots") :: Frame
	for i = 1, 3 do
		table.insert(pops, child(child(child(dots, "Dot" .. i), "Circle"), "Pop") :: UIScale)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
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
			open() -- also covers a rejoin mid-found, before the event lands
		elseif isOpen then
			close()
		end
	end)
end

return MatchFoundController
