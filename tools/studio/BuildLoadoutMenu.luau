--!nocheck
-- Builds the range's LOADOUT screen (vault/01 Design/Range v5.md §4) as a Studio-owned template:
-- StarterPlayer.StarterPlayerScripts.UI.Lobby.Loadout. The owner edits it in Studio (tools/studio/UiEdit.luau);
-- LobbyClient/Controllers/LoadoutController fills and runs it. Built from the Settings screen's own pieces (wash,
-- canvas with its fit rules, title, the drawn-X close, the tab plates, a plate button) so it matches the lobby.
-- Layout (1920 x 1080 design canvas, offsets from the centre):
--   title + kicker top-left, PRIMARY / SECONDARY / MELEE tabs under it, the three equipped slots in a column on the
--   left, the guns for the picked slot in a scrolling grid on the right (filled from UI.Templates.Lobby.GunGroup /
--   GunCard, like the Locker), a note and the LOCKER button along the foot. Safe to run again.

local UI = game.StarterPlayer.StarterPlayerScripts.UI
local S = UI.Lobby.Settings
local RUBIK_H = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy)
local RUBIK_B = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold)
local PLATE = Color3.fromHex("141417")
local MUTED = Color3.fromHex("A9B2BF")
local TEAL = Color3.fromHex("2BD9A8") -- the range's accent (LobbyKit K.AREA.range)
local WHITE = Color3.new(1, 1, 1)

local old = UI.Lobby:FindFirstChild("Loadout")
if old then
	old:Destroy()
end

local g = Instance.new("ScreenGui")
g.Name = "Loadout"
g.Enabled = false
g.ResetOnSpawn = false
g.DisplayOrder = S.DisplayOrder
g.IgnoreGuiInset = S.IgnoreGuiInset
g.ScreenInsets = S.ScreenInsets
g.ZIndexBehavior = S.ZIndexBehavior
for k, v in S:GetAttributes() do
	g:SetAttribute(k, v)
end
S.Wash:Clone().Parent = g

local canvas = S.Canvas:Clone()
for _, c in canvas:GetChildren() do
	if not (c.Name == "Fit" or c.Name == "Title" or c.Name == "Close" or c.Name == "Tabs") then
		c:Destroy()
	end
end
canvas.Parent = g
canvas.Title.Text = "LOADOUT"

local function text(parent, name, t, font, size, col, pos, sz)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.FontFace = font
	l.Text = t
	l.TextSize = size
	l.TextColor3 = col
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Position = pos
	l.Size = sz
	l.Parent = parent
	return l
end
local function round(obj, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = obj
end

text(canvas, "Kicker", "RANGE ARMORY  ·  EVERY GUN IS FREE HERE", RUBIK_B, 20, TEAL, UDim2.new(0.5, -798, 0.5, -528), UDim2.fromOffset(700, 24))

-- tabs: three from the Settings tab plate
local tabs = canvas.Tabs
local proto = tabs:FindFirstChildWhichIsA("TextButton")
for _, c in tabs:GetChildren() do
	if c:IsA("GuiButton") and c ~= proto then
		c:Destroy()
	end
end
for i, name in { "PRIMARY", "SECONDARY", "MELEE" } do
	local t = if i == 1 then proto else proto:Clone()
	t.Name = name
	t.LayoutOrder = i
	t.Size = UDim2.fromOffset(230, 56)
	local tabLabel = t:WaitForChild("Label") -- the Settings tab plate always has its Label
	tabLabel.Text = name
	t.Parent = tabs
end
tabs.Size = UDim2.fromOffset(740, 56)

-- the equipped slots
local slots = Instance.new("Frame")
slots.Name = "Slots"
slots.BackgroundTransparency = 1
slots.Position = UDim2.new(0.5, -800, 0.5, -318)
slots.Size = UDim2.fromOffset(470, 650)
slots.Parent = canvas
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 18)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = slots
for i, name in { "Primary", "Secondary", "Melee" } do
	local b = Instance.new("TextButton")
	b.Name = name
	b.LayoutOrder = i
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundColor3 = PLATE
	b.BackgroundTransparency = 0.2
	b.BorderSizePixel = 0
	b.Size = UDim2.fromOffset(470, 204)
	round(b, 8)
	text(b, "Kicker", string.upper(name), RUBIK_B, 18, MUTED, UDim2.fromOffset(24, 18), UDim2.fromOffset(300, 22))
	local key = Instance.new("Frame")
	key.Name = "Key"
	key.BackgroundColor3 = Color3.fromHex("252528")
	key.BorderSizePixel = 0
	key.AnchorPoint = Vector2.new(1, 0)
	key.Position = UDim2.new(1, -20, 0, 14)
	key.Size = UDim2.fromOffset(32, 32)
	round(key, 16)
	key.Parent = b
	local k = text(key, "Label", tostring(i), RUBIK_H, 18, WHITE, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))
	k.TextXAlignment = Enum.TextXAlignment.Center
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Position = UDim2.fromOffset(24, 48)
	icon.Size = UDim2.fromOffset(330, 100)
	icon.Parent = b
	text(b, "Name", "", RUBIK_H, 30, WHITE, UDim2.fromOffset(24, 148), UDim2.fromOffset(420, 32))
	text(b, "Skin", "", RUBIK_B, 16, MUTED, UDim2.fromOffset(24, 180), UDim2.fromOffset(420, 18))
	b.Parent = slots
end

-- the guns for the picked slot
local guns = Instance.new("ScrollingFrame")
guns.Name = "Guns"
guns.BackgroundTransparency = 1
guns.BorderSizePixel = 0
guns.Position = UDim2.new(0.5, -290, 0.5, -318)
guns.Size = UDim2.fromOffset(1090, 650)
guns.CanvasSize = UDim2.new()
guns.AutomaticCanvasSize = Enum.AutomaticSize.Y
guns.ScrollingDirection = Enum.ScrollingDirection.Y
guns.ScrollBarThickness = 6
guns.ScrollBarImageColor3 = WHITE
guns.ScrollBarImageTransparency = 0.6
guns.Parent = canvas
local gl = Instance.new("UIListLayout")
gl.Padding = UDim.new(0, 24)
gl.SortOrder = Enum.SortOrder.LayoutOrder
gl.Parent = guns
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 4)
pad.PaddingLeft = UDim.new(0, 4)
pad.Parent = guns

-- a note along the foot, and the LOCKER button (a plate button from the Settings confirm) on the tabs' row
text(canvas, "Note", "YOUR EQUIPPED SKINS COME WITH YOU  ·  CHANGE THEM IN THE LOCKER", RUBIK_B, 16, MUTED, UDim2.new(0.5, -290, 0.5, 354), UDim2.fromOffset(780, 20))
local locker = S.Canvas.Confirm.Keep:Clone()
locker.Name = "Locker"
locker.Position = UDim2.new(0.5, 540, 0.5, -404) -- on the tabs' row: the foot is the match HUD's (hotbar, ammo)
locker.Size = UDim2.fromOffset(260, 64)
local lockerLabel = locker:WaitForChild("Label")
lockerLabel.Text = "LOCKER"
locker.Parent = canvas

g.Parent = UI.Lobby
return "built UI.Lobby.Loadout"
