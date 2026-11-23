--!strict
-- Case popup buttons (vault/01 Design/Shop Economy and Art v1.md). 2026-11-22 owner: case
-- prices show Robux first, Tickets as the second option: BuyRobux (x1) | BuyRobux3 (x3) |
-- BuyCoins (Tickets; the name is kept, ShopController reads it). Each gets a kicker above.
-- Where paid random items aren't allowed ShopController hides the two Robux buttons and
-- centres the Tickets one. Also builds PopupCanvas.RewardPanel, the "YOU GOT" popup after
-- a purchase, from a copy of ConfirmPanel (Title, Art, ItemName, Collect, Close).
-- Re-runnable. Lobby place, Edit mode; save the place after.

local pop = (game:GetService("StarterPlayer") :: any).StarterPlayerScripts.UI.Lobby.Shop.PopupCanvas
local cp = pop.CasePanel

cp.BuyRobux.Visible = true
cp.BuyRobux3.Visible = true
cp.BuyRobux:SetAttribute("HiddenSince", nil)
cp.BuyRobux3:SetAttribute("HiddenSince", nil)
cp.BuyRobux.Position = UDim2.new(0, 160, 1, -40)
cp.BuyRobux3.Position = UDim2.new(0, 410, 1, -40)
cp.BuyCoins.Position = UDim2.new(0, 660, 1, -40)
local function kicker(button: Instance, text: string)
	local k = button:FindFirstChild("Kicker") or cp.BuyRobux3.Kicker:Clone()
	k.Text = text
	k.Parent = button
end
kicker(cp.BuyRobux, "BUY x1")
kicker(cp.BuyRobux3, "BUY x3")
kicker(cp.BuyCoins, "WITH TICKETS")

local old = pop:FindFirstChild("RewardPanel")
if old then
	old:Destroy()
end
local rp = pop.ConfirmPanel:Clone()
rp.Name = "RewardPanel"
rp.Visible = false
rp.Title.Text = "YOU GOT"
rp.ItemName.Text = "ITEM NAME"
rp.Buy.Name = "Collect"
local amount = rp.Collect:FindFirstChild("Amount", true)
assert(amount and amount:IsA("TextLabel"), "ShopTicketCases: the Collect button has no Amount label")
amount.Text = "COLLECT"
local coin = rp.Collect:FindFirstChild("Coin", true)
if coin then
	coin.Visible = false
end
rp.Parent = pop
return "case popup + RewardPanel ready"
