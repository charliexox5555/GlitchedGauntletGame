--!strict
-- Studio plugin: one toolbar button that flips the place between a real
-- match (the Whitebox map, drafts, the test opponent) and the test range
-- (dummies, the F8 ability dev panel). It sets the Workspace attribute
-- "TestMode" that shared/TestMode reads when a playtest starts, so flip it
-- before pressing Play. The button stays lit while test mode is on.
--
-- Install: copy this file into %LOCALAPPDATA%\Roblox\Plugins (Studio picks it
-- up on its own). Save the place afterwards if you want the setting kept.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ATTRIBUTE = "TestMode"

local toolbar = plugin:CreateToolbar("Glitched Gauntlet")
local button = toolbar:CreateButton(
	"TestModeToggle",
	"Switch between the test range (on) and a real match (off). Flip it before Play.",
	"rbxasset://textures/StudioToolbox/AssetPreview/play_button.png",
	"Test Mode"
)
button.ClickableWhenViewportHidden = true

local function isOn(): boolean
	return Workspace:GetAttribute(ATTRIBUTE) == true
end

local function refresh()
	button:SetActive(isOn())
end

button.Click:Connect(function()
	if RunService:IsRunning() then
		warn("[Test Mode] Stop the playtest first: test mode is chosen when a playtest starts.")
		refresh()
		return
	end
	local recording = ChangeHistoryService:TryBeginRecording("Toggle Test Mode")
	Workspace:SetAttribute(ATTRIBUTE, not isOn())
	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
	print(
		if isOn()
			then "[Test Mode] ON: Play starts the test range (F8 = ability dev panel)."
			else "[Test Mode] OFF: Play starts a real match on the map."
	)
	refresh()
end)

Workspace:GetAttributeChangedSignal(ATTRIBUTE):Connect(refresh)
refresh()
