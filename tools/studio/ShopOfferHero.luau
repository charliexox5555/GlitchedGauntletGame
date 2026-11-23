--!strict
-- Adds the HOME special offer card's Hero picture (the coin pile on the right of the
-- Starter banner; ShopController fills it with ShopCatalog.ART.coinStack). 2026-11-22.
-- Run in Studio (Edit) through the MCP, then save the place.
local shop = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("UI")
assert(shop, "UI folder missing")
local offer = (shop :: Instance):FindFirstChild("Offer", true)
assert(offer, "Offer missing")
local found = offer:FindFirstChild("Card")
assert(found and found:IsA("GuiObject"), "Offer.Card missing")
local card: GuiObject = found
local h = card:FindFirstChild("Hero") :: ImageLabel? -- lihfolk-ignore: findfirstchild-chain (optional, nil-checked below)
local hero: ImageLabel = h or Instance.new("ImageLabel")
hero.Name = "Hero"
hero.BackgroundTransparency = 1
hero.AnchorPoint = Vector2.new(1, 0)
hero.Position = UDim2.new(1, -40, 0, 14)
hero.Size = UDim2.fromOffset(300, 224)
hero.ScaleType = Enum.ScaleType.Fit
hero.ZIndex = 4
hero.Image = "rbxassetid://77893326046955"
hero.Parent = card
return "ok"
