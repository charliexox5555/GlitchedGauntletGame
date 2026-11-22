--!strict
-- The one answer to "what is this player playing with?" on the client
-- (vault/02 Art/UI Settings.md → Chunk 3): Roblox's PreferredInput, unless
-- Settings FORCE CONTROLS picks a device (Keyboard / Controller / Touch).
-- UiLayout, TouchHud, InputGlyphs, Router, MatchEndScreen, Device and the aim
-- assist read this instead of UserInputService directly, and listen to
-- `changed` (fires on a real input change and on a FORCE CONTROLS change).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Settings = require(Shared:WaitForChild("Config"):WaitForChild("Settings") :: ModuleScript)
local PlayerSettings = require(Shared:WaitForChild("PlayerSettings") :: ModuleScript)

local InputMode = {}

local changedEvent = Instance.new("BindableEvent")
InputMode.changed = changedEvent.Event

local FORCED: { [string]: Enum.PreferredInput } = {
	Keyboard = Enum.PreferredInput.KeyboardAndMouse,
	Controller = Enum.PreferredInput.Gamepad,
	Touch = Enum.PreferredInput.Touch,
}

local forced: Enum.PreferredInput? = nil

local function real(): Enum.PreferredInput
	local ok, preferred = pcall(function()
		return UserInputService.PreferredInput
	end)
	if ok then
		return preferred
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return Enum.PreferredInput.Touch
	end
	return Enum.PreferredInput.KeyboardAndMouse
end

function InputMode.preferred(): Enum.PreferredInput
	return forced or real()
end

function InputMode.isForced(): boolean
	return forced ~= nil
end

function InputMode.touch(): boolean
	return InputMode.preferred() == Enum.PreferredInput.Touch
end

function InputMode.gamepad(): boolean
	return InputMode.preferred() == Enum.PreferredInput.Gamepad
end

-- Touch controls can be drawn: a touch screen (or Touch forced), unless
-- Keyboard / Controller is forced.
function InputMode.touchCapable(): boolean
	if forced then
		return forced == Enum.PreferredInput.Touch
	end
	return UserInputService.TouchEnabled
end

-- Settings FORCE CONTROLS changed (Shared/SettingsApply calls this).
function InputMode.setForced(choice: unknown)
	local want = if typeof(choice) == "string" then FORCED[choice] else nil
	if want ~= forced then
		forced = want
		changedEvent:Fire()
	end
end

local hooked = false
local function hook()
	if hooked then
		return
	end
	hooked = true
	pcall(function()
		UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
			changedEvent:Fire()
		end)
	end)
	-- the saved choice as early as possible (SettingsApply keeps it current)
	task.spawn(function()
		local player = Players.LocalPlayer
		local sv = player and player:WaitForChild(Settings.REPLICA, 30)
		if sv and sv:IsA("StringValue") and sv.Value ~= "" and forced == nil then
			local values = PlayerSettings.decode(sv.Value)
			if values then
				InputMode.setForced(values.forceControls)
			end
		end
	end)
end
hook()

return InputMode
