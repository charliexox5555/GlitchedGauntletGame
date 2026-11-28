--!strict
-- The look of one DAILY card (Item1..Item8 in the Shop's Daily page; owner 2026-11-28:
-- "make it look better ... more epic and legendary"). ShopController writes the words and
-- the price plate; style() then colours the card for its tier and state:
--   * the back leans toward the tier colour (Config/ShopTheme.DAILY.wash: none for Common,
--     clear for Epic and Legendary), top to bottom, no outline or glow,
--   * "owned": the picture dims a little, the plate goes quiet (OWNED),
--   * "locked" (a skin for a gun the player hasn't unlocked, a tease): the picture goes
--     dark, a GUN LOCKED plate sits on it, the plate says UNLOCK <GUN> FIRST,
--   * "price" / "free": full colour.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopTheme = require(ReplicatedStorage.Shared.Config.ShopTheme)
local Plates = require(script.Parent.Plates)

export type State = "price" | "free" | "owned" | "locked"

local DailyCard = {}

local LOOK = ShopTheme.DAILY
local HEAVY = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy) -- Rubik (Config/Theme)
local WHITE = Color3.new(1, 1, 1)

local function wash(art: GuiObject, tier: string, color: Color3)
	local k = LOOK.wash[tier] or 0
	local top = ShopTheme.INNER:Lerp(color, k)
	local bottom = ShopTheme.INNER:Lerp(color, k * LOOK.washBottom)
	art.BackgroundColor3 = WHITE -- the gradient carries the colour
	local g = art:FindFirstChild("TierWash")
	if not (g and g:IsA("UIGradient")) then
		local made = Instance.new("UIGradient")
		made.Name = "TierWash"
		made.Rotation = 90 -- top to bottom
		made.Parent = art
		g = made
	end
	(g :: UIGradient).Color = ColorSequence.new(top, bottom)
end

-- The GUN LOCKED plate over the picture (made once per card, slanted like every plate).
local function badge(card: GuiObject): GuiObject
	local found = card:FindFirstChild("Locked")
	if found and found:IsA("GuiObject") then
		return found
	end
	local plate = Instance.new("Frame")
	plate.Name = "Locked"
	plate.AnchorPoint = Vector2.new(0.5, 0.5)
	plate.Position = UDim2.fromScale(0.5, 0.4)
	plate.Size = UDim2.fromOffset(150, 32)
	plate.BackgroundColor3 = LOOK.badge
	plate.BorderSizePixel = 0
	plate.ZIndex = 6 -- over the picture (4), under the words
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = HEAVY
	label.Text = "GUN LOCKED"
	label.TextSize = 18
	label.TextColor3 = LOOK.badgeText
	label.ZIndex = 8
	label.Parent = plate
	Plates.build(plate, 10, 6)
	plate.Parent = card
	Plates.finish(plate)
	return plate
end

function DailyCard.style(card: GuiObject, tier: string, color: Color3, state: State)
	local art = card:FindFirstChild("Art")
	if art and art:IsA("GuiObject") then
		wash(art, tier, color)
	end
	local pic = card:FindFirstChild("Pic")
	if pic and pic:IsA("ImageLabel") then
		pic.ImageColor3 = if state == "locked"
			then LOOK.lockedPic
			elseif state == "owned" then LOOK.ownedPic
			else WHITE
	end
	if state == "locked" then
		badge(card).Visible = true
	else
		local b = card:FindFirstChild("Locked")
		if b and b:IsA("GuiObject") then
			b.Visible = false
		end
	end
	-- the price plate: quiet and light words when it isn't a price
	local plate = card:FindFirstChild("Price", true)
	local row = plate and plate:FindFirstChild("Row")
	local amount = row and row:FindFirstChild("Amount")
	if amount and amount:IsA("TextLabel") then
		local base = amount:GetAttribute("DailyBaseColor")
		if typeof(base) ~= "Color3" then
			base = amount.TextColor3
			amount:SetAttribute("DailyBaseColor", base)
		end
		local quiet = state == "owned" or state == "locked"
		amount.TextColor3 = if quiet then LOOK.badgeText else base :: Color3
		if quiet and plate and plate:IsA("GuiObject") then
			plate.BackgroundColor3 = LOOK.quietPlate
		end
	end
end

return DailyCard
