--!strict
-- Tells the server what this player plays on (DeviceService → the Player
-- attribute "Device", shown as a device mark; Config/PlayerTags). Sent once,
-- and again if the main input changes family (a pad plugged into a PC stays
-- "PC": keyboards win).

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local VRService = game:GetService("VRService")

local Net = require(ReplicatedStorage.Shared.Net)

local DeviceController = {}

local function detect(): string
	if VRService.VREnabled then
		return "VR"
	elseif GuiService:IsTenFootInterface() then
		return "Console"
	elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Mobile"
	end
	return "PC"
end

function DeviceController.start()
	local sent = ""
	local function send()
		local device = detect()
		if device ~= sent then
			sent = device
			Net.event("Device"):FireServer(device)
		end
	end
	send()
	UserInputService.LastInputTypeChanged:Connect(function()
		task.delay(0.5, send)
	end)
end

return DeviceController
