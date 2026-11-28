--!strict
-- Builds the Free Rewards popup in the Lobby place (vault/02 Art/Lobby Holograms.md), Studio-owned:
--   ServerStorage.LobbyUI.FreeRewards   the popup opened by the green lobby hologram: the gift (coins + a case),
--                                       JOIN THE GROUP (Roblox's own join prompt), a "like the game" ask with no
--                                       reward attached, and CLAIM (the server checks the group)
-- Same card look as the streak save (it clones ServerStorage.LobbyUI.StreakSave). Run in the Studio command bar
-- or MCP execute_luau (Edit); re-running replaces it. Code only fills it (Controllers/FreeRewardsController).

local ServerStorage = game:GetService("ServerStorage")

local LobbyUI = ServerStorage:WaitForChild("LobbyUI")
local COIN = "rbxassetid://126250416946442" -- the LobbyCoins coin
local CASE = "rbxassetid://122735078835784" -- crate_standard_wide.png (ShopCatalog.CASES Standard)
local GREEN = Color3.fromHex("46E08A")
local INK = Color3.fromHex("0F0F12")
local TILE = Color3.fromHex("1E2026")
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

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local old = LobbyUI:FindFirstChild("FreeRewards")
if old then
	old:Destroy()
end
local gui = LobbyUI:WaitForChild("StreakSave"):Clone() :: ScreenGui
gui.Name = "FreeRewards"
gui.Enabled = false
local card = gui:WaitForChild("Canvas"):WaitForChild("Card") :: Frame
for _, name in { "Flame", "Streak", "Ends", "Note", "Title", "Sub" } do
	local c = card:FindFirstChild(name)
	if c then
		c:Destroy()
	end
end
local W = 680
card.Size = UDim2.fromOffset(W, 660)

local title = label(card, "Title", "FREE REWARDS", 46, Enum.FontWeight.Heavy, Color3.new(1, 1, 1))
title.Size = UDim2.new(1, -80, 0, 56)
title.Position = UDim2.fromOffset(40, 36)
local sub =
	label(card, "Sub", "A ONE-TIME GIFT FOR JOINING OUR GROUP", 20, Enum.FontWeight.Bold, MUTED)
sub.Size = UDim2.new(1, -80, 0, 26)
sub.Position = UDim2.fromOffset(40, 94)

-- the gift: two tiles with a + between
local gift = Instance.new("Frame")
gift.Name = "Gift"
gift.BackgroundTransparency = 1
gift.Size = UDim2.fromOffset(W - 80, 190)
gift.Position = UDim2.fromOffset(40, 140)
gift.Parent = card
local function tile(name: string, x: number, image: string, imageSize: Vector2, text: string): Frame
	local t = Instance.new("Frame")
	t.Name = name
	t.BackgroundColor3 = TILE
	t.BackgroundTransparency = 0.05
	t.Size = UDim2.fromOffset(250, 190)
	t.Position = UDim2.fromOffset(x, 0)
	t.ZIndex = 3
	t.Parent = gift
	corner(t, 6)
	local img = Instance.new("ImageLabel")
	img.Name = "Art"
	img.BackgroundTransparency = 1
	img.Image = image
	img.ScaleType = Enum.ScaleType.Fit
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.Size = UDim2.fromOffset(imageSize.X, imageSize.Y)
	img.Position = UDim2.new(0.5, 0, 0, 78)
	img.ZIndex = 4
	img.Parent = t
	local l = label(t, "Amount", text, 26, Enum.FontWeight.Heavy, Color3.new(1, 1, 1))
	l.Size = UDim2.new(1, -20, 0, 32)
	l.Position = UDim2.new(0, 10, 1, -46)
	return t
end
tile("Coins", 0, COIN, Vector2.new(96, 96), "500 COINS")
tile("Case", W - 80 - 250, CASE, Vector2.new(220, 124), "STANDARD CASE")
local plus = label(gift, "Plus", "+", 54, Enum.FontWeight.Heavy, GREEN)
plus.AnchorPoint = Vector2.new(0.5, 0.5)
plus.Size = UDim2.fromOffset(60, 60)
plus.Position = UDim2.fromScale(0.5, 0.5)

-- the steps
local function step(name: string, y: number, n: string, head: string, note: string): Frame
	local row = Instance.new("Frame")
	row.Name = name
	row.BackgroundColor3 = TILE
	row.BackgroundTransparency = 0.05
	row.Size = UDim2.fromOffset(W - 80, 74)
	row.Position = UDim2.fromOffset(40, y)
	row.ZIndex = 3
	row.Parent = card
	corner(row, 6)
	local num = label(row, "Num", n, 34, Enum.FontWeight.Heavy, GREEN)
	num.Size = UDim2.fromOffset(54, 74)
	local h = label(row, "Head", head, 24, Enum.FontWeight.Heavy, Color3.new(1, 1, 1))
	h.TextXAlignment = Enum.TextXAlignment.Left
	h.Size = UDim2.new(1, -240, 0, 30)
	h.Position = UDim2.fromOffset(58, 10)
	local s = label(row, "Note", note, 16, Enum.FontWeight.Bold, MUTED)
	s.TextXAlignment = Enum.TextXAlignment.Left
	s.Size = UDim2.new(1, -240, 0, 22)
	s.Position = UDim2.fromOffset(58, 42)
	return row
end
local join = step("Join", 350, "1", "JOIN THE GROUP", "THE GIFT UNLOCKS FOR GROUP MEMBERS")
step("Like", 436, "2", "LIKE THE GAME", "ENJOYING IT? A LIKE ON THE GAME PAGE HELPS US A LOT")

local action = card:WaitForChild("Action") :: TextButton
-- the JOIN button: a smaller copy of the main button, on the right of step 1
local joinButton = action:Clone()
joinButton.Name = "JoinButton"
joinButton.Size = UDim2.fromOffset(150, 50)
joinButton.AnchorPoint = Vector2.new(1, 0.5)
joinButton.Position = UDim2.new(1, -14, 0.5, 0)
joinButton.BackgroundColor3 = GREEN
recolour(joinButton, GREEN)
local joinCoin = joinButton:FindFirstChild("Coin")
if joinCoin then
	joinCoin:Destroy()
end
local joinLabel = joinButton:WaitForChild("Label") :: TextLabel
joinLabel.Text = "JOIN"
joinLabel.TextSize = 24
joinLabel.TextColor3 = INK
joinLabel.Size = UDim2.fromScale(1, 1)
joinButton.ZIndex = 6
joinButton.Parent = join

local status = label(card, "Status", "", 18, Enum.FontWeight.Bold, MUTED)
status.Size = UDim2.new(1, -80, 0, 24)
status.Position = UDim2.fromOffset(40, 520)

action.Size = UDim2.fromOffset(340, 68)
action.AnchorPoint = Vector2.new(0.5, 0)
action.Position = UDim2.fromOffset(W / 2, 554)
action.BackgroundColor3 = GREEN
recolour(action, GREEN)
local coin = action:FindFirstChild("Coin")
if coin then
	coin:Destroy()
end
local actionLabel = action:WaitForChild("Label") :: TextLabel
actionLabel.Text = "CLAIM"
actionLabel.TextColor3 = INK
actionLabel.Size = UDim2.fromScale(1, 1)
gui.Parent = LobbyUI

return "[BuildFreeRewards] ServerStorage.LobbyUI.FreeRewards built"
