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
local TweenService = game:GetService("TweenService")

local LobbyNet = require(game:GetService("ReplicatedStorage").Lobby.LobbyNet)
local QueueState = require(script.Parent.Parent.Util.QueueState)
local Router = require(script.Parent.Parent.Util.Router)
local LobbyHud = require(script.Parent.LobbyHud)

local MatchFoundController = {}

local player = Players.LocalPlayer
local QUINT, SINE = Enum.EasingStyle.Quint, Enum.EasingStyle.Sine
local IN, OUT, INOUT = Enum.EasingDirection.In, Enum.EasingDirection.Out, Enum.EasingDirection.InOut
local SCRIM_T = 0.2 -- the scrim's see-through when shown
local BLUR = 20
local PULSE = 1.45 -- the pulsing dot's scale
local BEAT = 0.22 -- seconds between one dot's pulse and the next

local gui: ScreenGui
local scrim: Frame
local fit: UIScale
local studioLabel: TextLabel
local pops: { UIScale } = {}
local blur: BlurEffect
local isOpen = false
local token = 0

local function tween(
	obj: Instance,
	time: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
): Tween
	local t = TweenService:Create(obj, TweenInfo.new(time, style or QUINT, dir or OUT), goal)
	t:Play()
	return t
end

local function child<T>(parent: Instance, name: string): T
	return (parent:WaitForChild(name) :: any) :: T
end

local function refit()
	local size = gui.AbsoluteSize
	if size.X > 0 and size.Y > 0 then
		fit.Scale = math.clamp(math.min(size.X / 1920, size.Y / 1080), 0.6, 1.5)
	end
end

-- The dots pulse one after another: each grows quickly and eases back.
local function pulse(my: number)
	task.spawn(function()
		task.wait(0.3) -- after they've popped in
		while token == my do
			for _, pop in pops do
				if token ~= my then
					return
				end
				local up = tween(pop, 0.26, { Scale = PULSE })
				up.Completed:Once(function(state: Enum.PlaybackState)
					if state == Enum.PlaybackState.Completed and token == my then
						tween(pop, 0.38, { Scale = 1 }, SINE, INOUT)
					end
				end)
				task.wait(BEAT)
			end
			task.wait(0.36)
		end
	end)
end

local function open()
	if isOpen then
		return
	end
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
	pulse(my)
end

local function close()
	if not isOpen then
		return
	end
	isOpen = false
	token += 1
	local my = token
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
	QueueState.onChanged(function()
		local s = QueueState.status()
		if s == "found" or s == "teleporting" then
			open() -- also covers a rejoin mid-found, before the event lands
		elseif isOpen then
			close()
		end
	end)
end

return MatchFoundController
