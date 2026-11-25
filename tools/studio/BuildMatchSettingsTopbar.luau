--!strict
-- Studio Edit. Reuse the Lobby's gear and safe-inset bar for match Settings.
local ui = game:GetService("StarterPlayer").StarterPlayerScripts:WaitForChild("UI")
local lobbyTopbar = ui:WaitForChild("Lobby"):WaitForChild("LobbyTopbar") :: ScreenGui
local lobbyBar = lobbyTopbar:WaitForChild("Bar")
local gift = lobbyBar:FindFirstChild("Rewards")
if gift and gift:IsA("GuiObject") then
	gift.Visible = false
	gift.Selectable = false
end

local match = ui:WaitForChild("Match")
local old = match:FindFirstChild("MatchSettingsTopbar")
if old then
	old:Destroy()
end
local topbar = lobbyTopbar:Clone()
topbar.Name = "MatchSettingsTopbar"
topbar:SetAttribute("LobbyGui", nil)
topbar.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
topbar.DisplayOrder = 32
topbar.Enabled = false
local bar = topbar:WaitForChild("Bar") :: Frame
bar.AnchorPoint = Vector2.new(1, 0.5)
bar.Position = UDim2.new(1, -12, 0.5, 0)
bar.Size = UDim2.fromOffset(44, 44)
for _, child in bar:GetChildren() do
	if child:IsA("GuiObject") and child.Name ~= "Settings" then
		child:Destroy()
	end
end
topbar.Parent = match
return "Removed the Lobby Rewards shortcut and installed the Match Settings gear."
