--!strict
-- Builds UI.Lobby.TouchEditor, the touch layout editor's bar (vault/02 Art/UI
-- Mobile Controls.md → Build plan v1). Run in the Lobby place's command bar;
-- the buttons are copies of the Settings tab plates so they match.
-- Code: lobby/client/Util/TouchEditor.

local ui = game:GetService("StarterPlayer").StarterPlayerScripts:WaitForChild("UI")
local lobby = ui:WaitForChild("Lobby")
local plate = lobby.Settings.Canvas.Tabs.VIDEO :: TextButton

local old = lobby:FindFirstChild("TouchEditor")
if old then
	old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "TouchEditor"
gui.Enabled = false
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 95 -- over the preview (90)

-- the bar: top centre, under Roblox's top bar; a 1080p design scaled by UiLayout
local bar = Instance.new("Frame")
bar.Name = "Bar"
bar.AnchorPoint = Vector2.new(0.5, 0)
bar.Position = UDim2.new(0.5, 0, 0, 62)
bar.Size = UDim2.fromOffset(1240, 110)
bar.BackgroundTransparency = 1
bar:SetAttribute("PhoneBoost", 1.25)
bar:SetAttribute("TabletBoost", 1.1)
bar.Parent = gui
local fit = Instance.new("UIScale")
fit.Name = "Fit"
fit.Parent = bar
local row = Instance.new("Frame")
row.Name = "Row"
row.AnchorPoint = Vector2.new(0.5, 0)
row.Position = UDim2.fromScale(0.5, 0)
row.Size = UDim2.fromOffset(1240, 64)
row.BackgroundTransparency = 1
row.Parent = bar
local list = Instance.new("UIListLayout")
list.FillDirection = Enum.FillDirection.Horizontal
list.HorizontalAlignment = Enum.HorizontalAlignment.Center
list.VerticalAlignment = Enum.VerticalAlignment.Center
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Padding = UDim.new(0, 10)
list.Parent = row

local function button(name: string, text: string, width: number, order: number): TextButton
	local b = plate:Clone()
	b.Name = name
	b.LayoutOrder = order
	b.Size = UDim2.fromOffset(width, 64)
	local label = b:WaitForChild("Label") :: TextLabel
	label.Text = text
	label.TextSize = 26
	b.Parent = row
	return b
end

local function gap(order: number, width: number)
	local f = Instance.new("Frame")
	f.Name = "Gap" .. order
	f.LayoutOrder = order
	f.Size = UDim2.fromOffset(width, 64)
	f.BackgroundTransparency = 1
	f.Parent = row
end

button("Cancel", "CANCEL", 150, 1)
gap(2, 6)
button("P1", "1", 64, 3)
button("P2", "2", 64, 4)
button("P3", "3", 64, 5)
button("Reset", "RESET", 130, 6)
gap(7, 14)
button("Smaller", "−", 64, 8)
local sizeLabel = Instance.new("TextLabel")
sizeLabel.Name = "Size"
sizeLabel.LayoutOrder = 9
sizeLabel.Size = UDim2.fromOffset(110, 64)
sizeLabel.BackgroundTransparency = 1
sizeLabel.FontFace = (plate:WaitForChild("Label") :: TextLabel).FontFace
sizeLabel.TextColor3 = Color3.new(1, 1, 1)
sizeLabel.TextSize = 26
sizeLabel.Text = "100%"
sizeLabel.Parent = row
button("Bigger", "+", 64, 10)
button("Hide", "HIDE", 130, 11)
gap(12, 14)
button("Done", "DONE", 150, 13)

-- under the bar: what's selected, and how it works
local hint = Instance.new("TextLabel")
hint.Name = "Hint"
hint.AnchorPoint = Vector2.new(0.5, 0)
hint.Position = UDim2.new(0.5, 0, 0, 74)
hint.Size = UDim2.fromOffset(900, 30)
hint.BackgroundTransparency = 1
hint.FontFace = sizeLabel.FontFace
hint.TextColor3 = Color3.fromHex("B8B8BB")
hint.TextSize = 20
hint.Text = "TAP A BUTTON, THEN DRAG IT"
hint.Parent = bar

-- the ring drawn round the picked button (placed by code)
local ring = Instance.new("Frame")
ring.Name = "Selection"
ring.AnchorPoint = Vector2.new(0.5, 0.5)
ring.BackgroundTransparency = 1
ring.Visible = false
ring.ZIndex = 5
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromHex("FFC83D")
stroke.Thickness = 3
stroke.Parent = ring
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0.5, 0)
corner.Parent = ring
ring.Parent = gui

gui.Parent = lobby
return "built UI.Lobby.TouchEditor"
