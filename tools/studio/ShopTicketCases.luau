--!strict
-- Case popup for Ticket-only cases (vault/01 Design/Shop Economy and Art v1.md, step 2,
-- 2026-11-22): the two Robux buttons are hidden (kept, attribute HiddenSince) and the
-- Ticket button (still named BuyCoins, ShopController reads it) moves to the middle; its
-- old position is kept in the OldPosition attribute. Re-runnable. Lobby place, Edit
-- mode; save the place after.

local panel = (game:GetService("StarterPlayer") :: any).StarterPlayerScripts.UI.Lobby.Shop.PopupCanvas.CasePanel

for _, n in { "BuyRobux", "BuyRobux3" } do
	panel[n].Visible = false
	panel[n]:SetAttribute("HiddenSince", "2026-11-22 cases cost Tickets only")
end
if panel.BuyCoins:GetAttribute("OldPosition") == nil then
	panel.BuyCoins:SetAttribute("OldPosition", panel.BuyCoins.Position)
end
panel.BuyCoins.Position = UDim2.new(0, 410, 1, -40)
return "Ticket case popup applied"
