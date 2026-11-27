--!strict
-- Adds the power cases to the Shop's HOME page (vault/01 Design/Loadout and Power Deck.md -> Power cases): a POWERS
-- heading and a row under the CASES block, holding the SURGE case card (Case_Power, a copy of the Knife case card
-- with the Surge render). Room in the row for the next themed power cases. ShopController finds the card by name
-- (ShopCatalog CASES id "Power") and fills its price and popup. Run in Edit mode; re-running replaces them.

local UI = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local function need(parent: Instance?, path: string): any
	local node: Instance? = parent
	for name in string.gmatch(path, "[^%.]+") do
		node = node and node:FindFirstChild(name)
		assert(node, "missing " .. name .. " in " .. path)
	end
	return node
end

local home = need(UI, "UI.Lobby.Shop.Canvas.Scroll.Home") :: Frame
for _, n in { "Head_POWERS", "Powers" } do
	local old = home:FindFirstChild(n)
	if old then
		old:Destroy()
	end
end

-- order: CASES (1), Top (2), POWERS (3), Powers (4), then the rest shifts down two
for _, c in home:GetChildren() do
	if c:IsA("GuiObject") and c.LayoutOrder >= 3 then
		c.LayoutOrder += 2
	end
end

local head = (need(home, "Head_CASES") :: Frame):Clone()
head.Name = "Head_POWERS"
head.LayoutOrder = 3
local label = head:FindFirstChild("Label")
if label and label:IsA("TextLabel") then
	label.Text = "POWERS"
end
head.Parent = home

local row = Instance.new("Frame")
row.Name = "Powers"
row.BackgroundTransparency = 1
row.Size = UDim2.fromOffset(1280, 208)
row.LayoutOrder = 4
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.Padding = UDim.new(0, 16)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = row

local card = (need(home, "Top.Cases.Case_Knife") :: Frame):Clone()
card.Name = "Case_Power"
card.LayoutOrder = 1
local button = need(card, "Card")
local art = button:FindFirstChild("CaseArt")
if art and art:IsA("ImageLabel") then
	art.Image = "rbxassetid://84988833141911" -- art-source/ui/pack/pack_power_card.png
end
local name = button:FindFirstChild("Name")
if name and name:IsA("TextLabel") then
	name.Text = "SURGE"
end
local kind = button:FindFirstChild("Kind")
if kind and kind:IsA("TextLabel") then
	kind.Text = "POWER PACK"
end
card.Parent = row
row.Parent = home
return "added Head_POWERS + Powers.Case_Power"
