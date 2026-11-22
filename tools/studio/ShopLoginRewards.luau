--!strict
-- Login rewards board (vault/01 Design/Shop Economy and Art v1.md, step 1, 2026-11-22):
-- gives each DAILY tab login cell (Day1..Day7) a clear full-size "Hit" button, so a tap,
-- a click or a gamepad press claims (ShopController.hookLogin). Re-runnable. Lobby place,
-- Edit mode; save the place after. Nothing else changes: the cells' colours stay the
-- Studio look the controller reads (Day1 claimed, Day4 today, Day5 to come).

local shop = (game:GetService("StarterPlayer") :: any).StarterPlayerScripts.UI.Lobby.Shop
local login = shop.Canvas.Scroll.Daily.Login

local made = 0
for step = 1, 7 do
	local cell = login:FindFirstChild("Day" .. step, true)
	assert(cell and cell:IsA("GuiObject"), `Shop login rewards: no Day{step}`)
	local hit = cell:FindFirstChild("Hit")
	if not hit then
		local b = Instance.new("TextButton")
		b.Name = "Hit"
		b.Text = ""
		b.BackgroundTransparency = 1
		b.AutoButtonColor = false
		b.Size = UDim2.fromScale(1, 1)
		b.ZIndex = cell.ZIndex + 5
		b.Selectable = true
		b.Parent = cell
		made += 1
	end
end
return `Shop login rewards: {made} Hit buttons added`
