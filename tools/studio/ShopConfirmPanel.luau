--!strict
-- The Shop's confirm-purchase popup (owner 2026-11-22, RIVALS' emote buy popup: "when
-- clicking to buy something ... it will pop up this menu", vault/01 Design/Shop Economy
-- and Art v1.md → Step 3). Made from a copy of the case popup so it has the same look:
--   ConfirmPanel.Title    what it is ("SKIN", "BUNDLE", "COINS", "FREE SKIN")
--   ConfirmPanel.Art      the picture
--   ConfirmPanel.ItemName the item's name (the case popup's Count label)
--   ConfirmPanel.Buy      the price button (Price.Row: Coin icon + Amount)
--   ConfirmPanel.Close
-- ShopController fills and opens it. Re-runnable (replaces an older ConfirmPanel). Lobby
-- place, Edit mode; save the place after.

local pop = (game:GetService("StarterPlayer") :: any).StarterPlayerScripts.UI.Lobby.Shop.PopupCanvas
local old = pop:FindFirstChild("ConfirmPanel")
if old then
	old:Destroy()
end
local panel = pop.CasePanel:Clone()
panel.Name = "ConfirmPanel"
panel.Visible = false
for _, n in { "Contents", "BuyRobux", "BuyRobux3", "Placeholder" } do
	local c = panel:FindFirstChild(n)
	if c then
		c:Destroy()
	end
end
panel.Title.Text = "SKIN"
local itemName = panel.Count
itemName.Name = "ItemName"
itemName.Text = "ITEM NAME"
itemName.Position = UDim2.new(0.5, 0, 0, 336)
panel.BuyCoins.Name = "Buy"
panel.Buy:SetAttribute("OldPosition", nil)
panel.Buy.Position = UDim2.new(0.5, 0, 1, -40)
panel.Art.Image = ""
panel.Art.Size = UDim2.fromOffset(300, 220)
panel.Art.Position = UDim2.new(0.5, 0, 0, 210)
panel.Parent = pop
return "ConfirmPanel built"
