--!strict
-- Builds the streak save UI in the Lobby place (vault/01 Design/Progression.md), Studio-owned:
--   UI.Lobby.LobbyBar.Bottom.SaveStreak   the bar item that stands in for Settings while an offer is live
--   UI.Lobby.StreakSave                   the buy popup (same card look as Profile)
-- Run once in the Studio command bar (or MCP execute_luau, Edit). Re-running replaces both.
-- Code only fills them (Lobby client Controllers/StreakSaveController).

local UI = game:GetService("StarterPlayer").StarterPlayerScripts:WaitForChild("UI")
local Lobby = UI:WaitForChild("Lobby")

local FLAME = "rbxassetid://73282136637340" -- art-source/ui/streak/streak_icon.png (image of decal 126136866536517)
local COIN = "rbxassetid://126250416946442" -- the LobbyCoins coin
local ORANGE = Color3.fromHex("FF7026")
local INK = Color3.fromHex("0F0F12")
local MUTED = Color3.fromHex("9F9FA2")
local RUBIK = "rbxassetid://12187365977"

local function font(weight: Enum.FontWeight): Font
	return Font.new(RUBIK, weight, Enum.FontStyle.Normal)
end

local function label(
	parent: Instance,
	name: string,
	text: string,
	size: number,
	weight: Enum.FontWeight,
	color: Color3
): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextSize = size
	l.FontFace = font(weight)
	l.TextColor3 = color
	l.ZIndex = 5
	l.Parent = parent
	return l
end

local function recolour(item: Instance, color: Color3)
	for _, d in item:GetDescendants() do
		if d.Name == "Skin" and d:IsA("ImageLabel") then
			d.ImageColor3 = color
		end
	end
end

-- 1. The bar item ---------------------------------------------------------------------------
local bottom = Lobby:WaitForChild("LobbyBar"):WaitForChild("Bottom")
local old = bottom:FindFirstChild("SaveStreak")
if old then
	old:Destroy()
end
local settings = bottom:WaitForChild("Settings") :: GuiObject
local item = settings:Clone() :: TextButton
item.Name = "SaveStreak"
item.Visible = false
local icon = item:WaitForChild("Icon") :: ImageLabel
icon.Image = FLAME
local tag = item:WaitForChild("Tag") :: Frame
tag.BackgroundColor3 = ORANGE
tag.Size = UDim2.fromOffset(150, 28)
recolour(tag, ORANGE)
local tagLabel = tag:WaitForChild("Label") :: TextLabel
tagLabel.Text = "SAVE WINSTREAK"
tagLabel.TextColor3 = INK
local plate = item:WaitForChild("Plate") :: Frame
plate.BackgroundColor3 = ORANGE
recolour(plate, ORANGE)
-- the countdown sits over the icon's top right, where badges go
local badge = item:FindFirstChild("Badge")
if badge then
	badge:Destroy()
end
local timer = Instance.new("Frame")
timer.Name = "Timer"
timer.AnchorPoint = Vector2.new(0.5, 0.5)
timer.Position = UDim2.new(0.5, 34, 0, 12)
timer.Size = UDim2.fromOffset(66, 24)
timer.BackgroundColor3 = INK
timer.BackgroundTransparency = 0.1
timer.ZIndex = 9
timer.Parent = item
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 4)
corner.Parent = timer
local time = label(timer, "Value", "15:00", 16, Enum.FontWeight.Heavy, ORANGE)
time.Size = UDim2.fromScale(1, 1)
time.ZIndex = 10
item.Parent = bottom

-- 2. The popup -------------------------------------------------------------------------------
local oldGui = Lobby:FindFirstChild("StreakSave")
if oldGui then
	oldGui:Destroy()
end
local gui = Lobby:WaitForChild("Profile"):Clone() :: ScreenGui
gui.Name = "StreakSave"
gui.Enabled = false
local card = gui:WaitForChild("Canvas"):WaitForChild("Card") :: Frame
for _, name in
	{ "Portrait", "DisplayName", "Username", "Tags", "Stats", "StatsNote", "SkinsTitle", "Skins" }
do
	local c = card:FindFirstChild(name)
	if c then
		c:Destroy()
	end
end
card.Size = UDim2.fromOffset(620, 520)
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.5)

local title = label(card, "Title", "WINSTREAK LOST", 46, Enum.FontWeight.Heavy, Color3.new(1, 1, 1))
title.Size = UDim2.new(1, -80, 0, 56)
title.Position = UDim2.fromOffset(40, 40)
title.TextXAlignment = Enum.TextXAlignment.Center

local sub = label(card, "Sub", "SAVE IT BEFORE THE TIMER RUNS OUT", 20, Enum.FontWeight.Bold, MUTED)
sub.Size = UDim2.new(1, -80, 0, 26)
sub.Position = UDim2.fromOffset(40, 98)

local flame = Instance.new("ImageLabel")
flame.Name = "Flame"
flame.BackgroundTransparency = 1
flame.Image = FLAME
flame.AnchorPoint = Vector2.new(0.5, 0.5)
flame.Size = UDim2.fromOffset(150, 150)
flame.Position = UDim2.fromOffset(310, 222)
flame.ZIndex = 4
flame.Parent = card
local pop = Instance.new("UIScale")
pop.Name = "Pop"
pop.Parent = flame

local streak = label(card, "Streak", "0", 72, Enum.FontWeight.Heavy, Color3.new(1, 1, 1))
streak.AnchorPoint = Vector2.new(0.5, 0.5)
streak.Size = UDim2.fromOffset(300, 80)
streak.Position = UDim2.fromOffset(310, 240)
streak.ZIndex = 6
local stroke = Instance.new("UIStroke")
stroke.Color = INK
stroke.Thickness = 3
stroke.Parent = streak

local timeLeft = label(card, "Ends", "ENDS IN 15:00", 26, Enum.FontWeight.Heavy, ORANGE)
timeLeft.Size = UDim2.new(1, -80, 0, 32)
timeLeft.Position = UDim2.fromOffset(40, 318)

local note = label(card, "Note", "", 18, Enum.FontWeight.Bold, MUTED)
note.Size = UDim2.new(1, -80, 0, 24)
note.Position = UDim2.fromOffset(40, 356)

local action = card:WaitForChild("Action") :: TextButton
action.Size = UDim2.fromOffset(340, 68)
action.AnchorPoint = Vector2.new(0.5, 0)
action.Position = UDim2.fromOffset(310, 404)
action.BackgroundColor3 = ORANGE
recolour(action, ORANGE)
local actionLabel = action:WaitForChild("Label") :: TextLabel
actionLabel.Text = "SAVE FOR 100"
actionLabel.TextColor3 = INK
actionLabel.Size = UDim2.new(1, -56, 1, 0)
local coin = Instance.new("ImageLabel")
coin.Name = "Coin"
coin.BackgroundTransparency = 1
coin.Image = COIN
coin.AnchorPoint = Vector2.new(1, 0.5)
coin.Size = UDim2.fromOffset(40, 40)
coin.Position = UDim2.new(1, -18, 0.5, 0)
coin.ZIndex = 8
coin.Parent = action
gui.Parent = Lobby

print("[BuildStreakSave] SaveStreak bar item + StreakSave popup built")
