--!strict
-- The match place's side of the loading screen (vault/02 Art/UI Lobby
-- Overhaul.md → Play / queue / party). The lobby hands Roblox a copy of its
-- StarterGui.LobbyLoading (mode, LOADING MATCH, three dots, a tip) with
-- TeleportService:SetTeleportGui; here, first thing, we take that gui, drop
-- Roblox's default loading screen, keep the dots pulsing and fade the screen
-- out once the match has loaded and your character is in. Arriving without
-- it (Studio, a direct join) changes nothing.
-- Self-contained on purpose: ReplicatedFirst runs before Shared replicates.

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")

local SWELL = 0.42 -- the dots' wave (same as MATCH FOUND)
local PERIOD = 1.2
local FADE = 0.35
local MAX_WAIT = 12 -- seconds: never hold the screen longer than this
local SETTLE = 0.4 -- after the character arrives, so the HUD can draw

local arriving = TeleportService:GetArrivingTeleportGui()
if not (arriving and arriving:IsA("ScreenGui")) then
	return
end
local player = Players.LocalPlayer
local gui = arriving :: ScreenGui
gui.Enabled = true
gui.DisplayOrder = 1000
gui.Parent = player:WaitForChild("PlayerGui")
ReplicatedFirst:RemoveDefaultLoadingScreen()

-- the dots ride one wave, drawn every frame
local pops: { UIScale } = {}
local center = gui:FindFirstChild("Center")
local dots = center and center:FindFirstChild("Dots")
if dots then
	for i = 1, 3 do
		local holder = dots:FindFirstChild("Dot" .. i)
		local circle = holder and holder:FindFirstChild("Circle")
		local pop = circle and circle:FindFirstChild("Pop")
		if pop and pop:IsA("UIScale") then
			table.insert(pops, pop)
		end
	end
end
local fit = center and center:FindFirstChild("Fit")
local started = os.clock()
local wave = RunService.RenderStepped:Connect(function()
	local t = os.clock() - started
	for i, pop in pops do
		local c = 0.5 - 0.5 * math.cos(((t / PERIOD - (i - 1) / 3) % 1) * 2 * math.pi)
		pop.Scale = 1 + SWELL * c * c
	end
	if fit and fit:IsA("UIScale") then
		local size = gui.AbsoluteSize
		if size.X > 0 and size.Y > 0 then
			fit.Scale = math.clamp(math.min(size.X / 1920, size.Y / 1080), 0.5, 1.5)
		end
	end
end)

-- wait for the match, but never forever
local deadline = os.clock() + MAX_WAIT
if not game:IsLoaded() then
	game.Loaded:Wait()
end
while not player.Character and os.clock() < deadline do
	task.wait(0.1)
end
task.wait(SETTLE)

-- fade everything out, then clean up
local info = TweenInfo.new(FADE, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
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
			TweenService:Create(d, info, goal):Play()
		end
	end
end
task.wait(FADE + 0.05)
wave:Disconnect()
gui:Destroy()
