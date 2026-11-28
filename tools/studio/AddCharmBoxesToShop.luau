--!strict
-- Idempotently adds the CHARM BOXES row (Case_StrikeBox + Case_OverdriveBox)
-- to ServerStorage.LobbyUI.Shop.Canvas.Scroll.Home, cloning Head_POWERS / Powers / Case_Power.
-- Run in Studio Edit; save the place afterwards.

local ServerStorage = game:GetService("ServerStorage")

local STRIKE_ART = "rbxassetid://78675473607803"
local OVERDRIVE_ART = "rbxassetid://73906343187873"

local lobbyUi = ServerStorage:WaitForChild("LobbyUI")
local shop = lobbyUi:WaitForChild("Shop")
local home = shop:WaitForChild("Canvas"):WaitForChild("Scroll"):WaitForChild("Home")

local headPowers = home:WaitForChild("Head_POWERS") :: Frame
local powers = home:WaitForChild("Powers") :: Frame
local templateCard = powers:WaitForChild("Case_Power") :: Frame

for _, oldName in { "Head_CHARMS", "Charms" } do
	local old = home:FindFirstChild(oldName)
	if old then
		old:Destroy()
	end
end

-- Place CHARM BOXES right below POWERS (before SPECIAL OFFERS if present).
local headSpecial = home:FindFirstChild("Head_SPECIAL OFFERS")
local mid = home:FindFirstChild("Mid")
if headSpecial and headSpecial:IsA("GuiObject") then
	headSpecial.LayoutOrder = 7
end
if mid and mid:IsA("GuiObject") then
	mid.LayoutOrder = 8
end

local headCharms = headPowers:Clone()
headCharms.Name = "Head_CHARMS"
headCharms.LayoutOrder = 5
headCharms.Visible = true
headCharms:SetAttribute("FullOnly", nil)
headCharms:SetAttribute("LaunchOnly", nil)
for _, d in headCharms:GetDescendants() do
	if d:IsA("TextLabel") then
		d.Text = "CHARM BOXES"
	end
end
headCharms.Parent = home

local charmsRow = powers:Clone()
charmsRow.Name = "Charms"
charmsRow.LayoutOrder = 6
charmsRow.Visible = true
charmsRow:SetAttribute("FullOnly", nil)
charmsRow:SetAttribute("LaunchOnly", nil)
for _, c in charmsRow:GetChildren() do
	if c:IsA("GuiObject") then
		c:Destroy()
	end
end
charmsRow.Parent = home

local SPECS = {
	{
		holder = "Case_StrikeBox",
		order = 1,
		name = "STRIKE",
		kind = "CHARM BOX",
		art = STRIKE_ART,
		accent = Color3.fromHex("F5C238"),
	},
	{
		holder = "Case_OverdriveBox",
		order = 2,
		name = "OVERDRIVE",
		kind = "CHARM BOX",
		art = OVERDRIVE_ART,
		accent = Color3.fromHex("3FE0F2"),
	},
}

for _, spec in SPECS do
	local item = templateCard:Clone()
	item.Name = spec.holder
	item.LayoutOrder = spec.order
	item.Visible = true
	local card = item:FindFirstChild("Card")
	if card then
		local caseArt = card:FindFirstChild("CaseArt")
		if caseArt and caseArt:IsA("ImageLabel") then
			caseArt.Image = spec.art
		end
		local nameLbl = card:FindFirstChild("Name")
		if nameLbl and nameLbl:IsA("TextLabel") then
			nameLbl.Text = spec.name
		end
		local kindLbl = card:FindFirstChild("Kind")
		if kindLbl and kindLbl:IsA("TextLabel") then
			kindLbl.Text = spec.kind
		end
		local ph = card:FindFirstChild("Placeholder")
		if ph and ph:IsA("GuiObject") then
			ph.Visible = false
		end
	end
	item.Parent = charmsRow
end

return "Added Head_CHARMS + Charms (Case_StrikeBox, Case_OverdriveBox) to ServerStorage.LobbyUI.Shop"
