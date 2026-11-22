--!strict
-- Shop release layout (owner 2026-11-22, vault/02 Art/UI Shop.md → Release layout). Patches the
-- Studio-owned Shop screen (StarterPlayerScripts.UI.Lobby.Shop) in place. Re-runnable. Lobby
-- place, Edit mode; save the place after.
-- It deletes nothing: it marks parts with attributes that ShopController reads against
-- Config/Release.SHOP_FULL_LAYOUT (false = launch layout):
--   FullOnly = true        hidden in the launch layout
--   LaunchOnly = true      shown only in the launch layout
--   LaunchSize (UDim2)     size in the launch layout (the saved Size is the full layout's)
--   LaunchCellPadding      a UIGridLayout's padding in the launch layout
--   LaunchMaxCells         a UIGridLayout's FillDirectionMaxCells in the launch layout
-- Launch layout:
--   HOME:    CASES as one row of four across the page, SPECIAL OFFERS full width; charms and
--            emotes (Mid.Cosmetics) hidden. The Season Pass stays behind BATTLE_PASS_OPEN.
--   BUNDLES: FEATURED (Ruin-Blighted, Tempest-Strike), then STARTER (the Starter Bundle,
--            full width, new Row3). LIMITED TIME (Thanksgiving) hidden.

local shop = (game:GetService("StarterPlayer") :: any).StarterPlayerScripts.UI.Lobby.Shop
local scroll = shop.Canvas.Scroll

local TILE, W = 208, 1280

local function need(parent: Instance, name: string): any
	local c = parent:FindFirstChild(name)
	assert(c, `Shop release layout: {parent:GetFullName()} has no {name}`)
	return c
end

-- HOME
local home = need(scroll, "Home")
local top = need(home, "Top")
local cases = need(top, "Cases")
local grid = cases:FindFirstChildOfClass("UIGridLayout")
if not grid then
	error("Shop release layout: Cases has no UIGridLayout")
end
local gapX = math.floor((W - 4 * TILE) / 3) -- 149: four tiles spread over the page
top:SetAttribute("LaunchSize", UDim2.fromOffset(W, TILE))
cases:SetAttribute("LaunchSize", UDim2.fromOffset(W, TILE))
grid:SetAttribute("LaunchCellPadding", UDim2.fromOffset(gapX, grid.CellPadding.Y.Offset))
grid:SetAttribute("LaunchMaxCells", 4)
local mid = need(home, "Mid")
need(mid, "Offer"):SetAttribute("LaunchSize", UDim2.fromOffset(W, 330))
need(mid, "Cosmetics"):SetAttribute("FullOnly", true)

-- BUNDLES
local bundles = need(scroll, "Bundles")
local headLimited = need(bundles, "Head_LIMITED")
local row2 = need(bundles, "Row2")
headLimited:SetAttribute("FullOnly", true)
row2:SetAttribute("FullOnly", true)

local head = bundles:FindFirstChild("Head_STARTER")
if not head then
	head = headLimited:Clone()
	head.Name = "Head_STARTER"
	head.Parent = bundles
end
head:SetAttribute("FullOnly", nil)
head:SetAttribute("LaunchOnly", true)
head.LayoutOrder = 5
need(head, "Label").Text = "STARTER"

local row3 = bundles:FindFirstChild("Row3")
if not row3 then
	row3 = row2:Clone()
	row3.Name = "Row3"
	row3.Parent = bundles
	local holder = need(row3, "Bundle_Thanksgiving")
	holder.Name = "Bundle_Starter"
end
row3:SetAttribute("FullOnly", nil)
row3:SetAttribute("LaunchOnly", true)
row3.LayoutOrder = 6
-- the card's words and price come from ShopCatalog.BUNDLES ("Starter") at runtime; these are
-- only the edit-time preview
local card = need(need(row3, "Bundle_Starter"), "Card")
local green = Color3.fromHex("2E7D5B")
card.BackgroundColor3 = green
local art = card:FindFirstChild("Art")
if art and art:IsA("ImageLabel") and art.Image == "" then
	art.BackgroundColor3 = green
end
need(card, "Title").Text = "STARTER BUNDLE"
need(card, "Sub").Text = "CONTENTS COMING SOON"
need(need(card, "Tag"), "Label").Text = "NEW PLAYERS"
need(need(need(card, "Price"), "Row"), "Amount").Text = "99"

return "Shop release layout applied"
