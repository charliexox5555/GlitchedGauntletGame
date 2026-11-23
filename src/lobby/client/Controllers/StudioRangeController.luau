--!strict
-- Studio-only shortcut (F6 + top-right button) to jump straight into the
-- Shooting Range and back without opening the Range in live servers.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local PlayZone = require(ReplicatedStorage.Shared.PlayZone)

local StudioRangeController = {}

local REMOTE_NAME = "StudioRangeToggle"
local HOTKEY = Enum.KeyCode.F6

function StudioRangeController.start()
	if not RunService:IsStudio() then
		return
	end

	local lobbyFolder = ReplicatedStorage:WaitForChild("Lobby", 10)
	local remoteInst = lobbyFolder and lobbyFolder:WaitForChild(REMOTE_NAME, 10)
	if not remoteInst or not remoteInst:IsA("RemoteEvent") then
		return
	end
	local remote = remoteInst

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "StudioRangeShortcut"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 25

	local button = Instance.new("TextButton")
	button.Name = "RangeToggle"
	button.AnchorPoint = Vector2.new(1, 0)
	button.Position = UDim2.new(1, -18, 0, 14)
	button.Size = UDim2.fromOffset(172, 34)
	button.BackgroundColor3 = Color3.fromHex("171A22")
	button.TextColor3 = Color3.fromHex("F4F6F9")
	button.FontFace = Font.new("rbxasset://fonts/families/Rubik.json", Enum.FontWeight.Bold)
	button.TextSize = 14
	button.AutoButtonColor = true

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromHex("BA63F2")
	stroke.Thickness = 2
	stroke.Parent = button

	local function refresh(zone: PlayZone.Zone?)
		local inRange = (zone or PlayZone.get(player)) == "Range"
		button.Text = if inRange then "EXIT RANGE [F6]" else "RANGE [F6]"
		stroke.Color = if inRange then Color3.fromHex("3FA9FF") else Color3.fromHex("BA63F2")
	end

	local function trigger()
		remote:FireServer()
	end

	button.Activated:Connect(trigger)
	button.Parent = gui
	gui.Parent = playerGui

	refresh()
	PlayZone.onLocalChanged(refresh)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode == HOTKEY then
			trigger()
		end
	end)
end

return StudioRangeController
