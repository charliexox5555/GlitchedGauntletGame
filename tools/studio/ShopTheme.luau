--!strict
-- Recolours the Studio Shop screen to Config/ShopTheme (scheme A, owner 2026-11-22).
-- Only colours change: plates, buttons and layout stay. Re-runnable. Lobby place, Edit
-- mode; save the place after. (Studio caches required modules in Edit mode: after editing
-- Config/ShopTheme, reopen the place or paste the colours.)
--   * every panel that was the old card grey (141417 / 1C1C1F) → PANEL
--   * card art areas with no picture (bundles, coin packs, cosmetics) → INNER
--   * popup close buttons → INNER; item tiles → DEEP
--   * the page wash → PAGE; the popup dim → DIM
--   * login: today (Day4's look) → GOLD with ON_GOLD words; claimed stays green

local Theme = require((game:GetService("ReplicatedStorage") :: any).Shared.Config.ShopTheme)
local shop = (game:GetService("StarterPlayer") :: any).StarterPlayerScripts.UI.Lobby.Shop

local OLD_PANELS = { ["141417"] = true, ["1c1c1f"] = true }
local n = 0
for _, d in shop:GetDescendants() do
	if not d:IsA("GuiObject") then
		continue
	end
	local hex = d.BackgroundColor3:ToHex()
	if OLD_PANELS[hex] and d.BackgroundTransparency < 0.95 then
		d.BackgroundColor3 = Theme.PANEL
		n += 1
	elseif
		(
			d:IsA("ImageLabel")
			and d.Name == "Art"
			and d.Image == ""
			and d.BackgroundTransparency < 0.95
		) or (d.Name == "Close" and hex == "242427")
	then
		d.BackgroundColor3 = Theme.INNER -- art areas with no picture, popup close buttons
		n += 1
	elseif d.Name:match("^Tile%d$") then
		d.BackgroundColor3 = Theme.DEEP
		n += 1
	end
end
shop.Wash.BackgroundColor3 = Theme.PAGE
shop.Dim.BackgroundColor3 = Theme.DIM
local today = shop.Canvas.Scroll.Daily.Login:FindFirstChild("Day4", true)
today.BackgroundColor3 = Theme.GOLD
for _, name in { "Day", "Amount" } do
	local t = today:FindFirstChild(name)
	if t and t:IsA("TextLabel") then
		t.TextColor3 = Theme.ON_GOLD
	end
end
return `Shop recoloured ({n} parts)`
