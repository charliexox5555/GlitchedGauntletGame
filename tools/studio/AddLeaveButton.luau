--!strict
-- Adds the LEAVE button to the top-right match bar (UI.Match.MatchSettingsTopbar.Bar), beside Settings
-- (owner 2026-11-26: "a button to leave ... a little leave thing"). A clone of the Settings circle with an exit
-- glyph built from Frames (a door bracket and an arrow out). Run in Studio (Edit), then save the place.
-- Lobby Controllers/MatchSettingsButton shows it in the range and wires it.

local bar = game.StarterPlayer.StarterPlayerScripts.UI.Match.MatchSettingsTopbar.Bar
local settings = bar:FindFirstChild("Settings") :: TextButton
local old = bar:FindFirstChild("Leave")
if old then
	old:Destroy()
end
local leave = settings:Clone()
leave.Name = "Leave"
leave.LayoutOrder = 0
settings.LayoutOrder = 1
local face = leave:FindFirstChild("Face") :: Frame
local icon = face:FindFirstChild("Icon")
if icon then
	icon:Destroy()
end

local glyph = Instance.new("Frame")
glyph.Name = "Glyph"
glyph.BackgroundTransparency = 1
glyph.AnchorPoint = Vector2.new(0.5, 0.5)
glyph.Position = UDim2.fromScale(0.5, 0.5)
glyph.Size = UDim2.fromOffset(24, 24)
glyph.Parent = face

local WHITE = Color3.new(1, 1, 1)
local function bar_(name: string, x: number, y: number, w: number, h: number, rot: number?)
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = WHITE
	f.BorderSizePixel = 0
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, h)
	f.Rotation = rot or 0
	f.Parent = glyph
	return f
end
local T = 0.13 -- stroke
-- the door: an open bracket on the left
bar_("DoorSide", 0.14 + T / 2, 0.5, T, 0.8)
bar_("DoorTop", 0.34, 0.1 + T / 2, 0.4 + T / 2, T)
bar_("DoorFoot", 0.34, 0.9 - T / 2, 0.4 + T / 2, T)
-- the arrow out
bar_("Shaft", 0.6, 0.5, 0.52, T)
local tipX, arm = 0.9, 0.34
local d = arm / 2 * math.cos(math.rad(45))
bar_("HeadUp", tipX - d - 0.02, 0.5 - d, arm, T, 45)
bar_("HeadDown", tipX - d - 0.02, 0.5 + d, arm, T, -45)
leave.Parent = bar
return "Leave added"
