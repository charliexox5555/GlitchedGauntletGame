--!strict
-- Shop UI pass (owner 2026-11-22 with RIVALS refs; vault/01 Design/Shop Economy and Art
-- v1.md → UI pass). Patches the Studio-owned Shop screen in place. Re-runnable. Lobby
-- place, Edit mode; save the place after.
--   * The canvas gets DesktopBoost 1.3 (the whole shop ~1.3x on PC); Preview gets a UIScale
--     "PreviewScale" that ShopController sets so the preview fits under the tab bar.
--   * Preview: centred on the screen (X by scale, not 960 px), laid out from its own top
--     (ShopController puts that top under the tab bar, which stays on screen).
--   * Preview price buttons in RIVALS' manner: the whole button is the coloured plate,
--     "BUY ITEM" inside it on top, the price under it; SEPARATELY is a fixed red plate.
--   * BUNDLES: Ruin-Blighted and Tempest-Strike are full-width cards (1280 x 420), one
--     above the other, each with a big "Hero" picture and up to six item "Tiles"; the
--     Starter card gets a Hero picture too.

local shop = (game:GetService("StarterPlayer") :: any).StarterPlayerScripts.UI.Lobby.Shop
local canvas = shop.Canvas
local scroll = canvas.Scroll
local preview = canvas.Preview

local function scaleIn(parent: Instance, name: string)
	local s = parent:FindFirstChild(name) or Instance.new("UIScale")
	s.Name = name
	s.Parent = parent
end
-- bigger on desktop too (Shared/UiLayout reads DesktopBoost; PhoneBoost / TabletBoost exist)
canvas:SetAttribute("DesktopBoost", 1.3)
local old = scroll:FindFirstChild("ShopScale")
if old then
	old:Destroy() -- an earlier try: a UIScale on the ScrollingFrame clips wrongly
end
scaleIn(preview, "PreviewScale")

-- the tab bar shrinks on a bundle page (ShopController.pageTabs): a UIScale on Tabs,
-- marked PivotOk so Util/Pivot leaves it scaling from its top-left (no holder wrap)
local tabs = scroll.Tabs
local tabsScale = tabs:FindFirstChild("TabsScale") or Instance.new("UIScale")
tabsScale.Name = "TabsScale"
tabsScale.Scale = 1
tabsScale.Parent = tabs
local state = tabs:FindFirstChild("GauntletState") or Instance.new("Folder")
state.Name = "GauntletState"
state.Parent = tabs
local pivotOk = state:FindFirstChild("PivotOk") or Instance.new("StringValue")
pivotOk.Name = "PivotOk"
pivotOk.Value = "t" -- StateValues' true
pivotOk.Parent = state

-- room for a hovered card's pop (1.04) and its selection brackets: the scroll was 1340
-- wide with the pages left-aligned 30 px in, so the full-width bundle cards' brackets were
-- clipped (owner 2026-11-22). Now 1420 wide, pages centred (70 px each side).
scroll.Size = UDim2.new(0, 1420, 1, 0)
local scrollList = scroll:FindFirstChildOfClass("UIListLayout")
if scrollList then
	scrollList.HorizontalAlignment = Enum.HorizontalAlignment.Center
end
local scrollPad = scroll:FindFirstChildOfClass("UIPadding")
if scrollPad then
	scrollPad.PaddingLeft = UDim.new(0, 0)
	scrollPad.PaddingRight = UDim.new(0, 0)
end

-- Preview layout (y from the preview's top; the controller places that top)
preview.AnchorPoint = Vector2.new(0.5, 0)
preview.Position = UDim2.new(0.5, 0, 0, 250)
preview.Size = UDim2.new(1, 0, 0, 790)
local function at(name: string, y: number)
	local o = preview[name]
	o.Position = UDim2.new(0.5, 0, 0, y)
end
at("Head", 0)
at("For", 64)
preview.StageBox.Size = UDim2.fromOffset(1600, 420) -- the gun big (owner: "the gun viewport can be larger")
at("StageBox", 310)
at("Hint", 524)
at("Actions", 546)
preview.Actions.Size = UDim2.new(0, 0, 0, 104)
at("Strip", 660)
preview.Strip.Size = UDim2.new(0, 0, 0, 124)

-- Price buttons: the button is the plate
local actions = preview.Actions
local list = actions:FindFirstChildOfClass("UIListLayout")
if list then
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 44) -- the slanted plate ends reach past the button box
end
local GREEN = Color3.fromHex("3FD45C")
local DEEP_GREEN = Color3.fromHex("14531F")
for _, n in { "BuyItem", "BuyBundle" } do
	local b = actions[n]
	b.Size = UDim2.fromOffset(270, 104)
	local price = b.Price
	price.AutomaticSize = Enum.AutomaticSize.None
	price.AnchorPoint = Vector2.new(0.5, 0.5)
	price.Position = UDim2.fromScale(0.5, 0.5)
	price.Size = UDim2.fromScale(1, 1)
	price.BackgroundColor3 = GREEN
	local row = price.Row
	row.AnchorPoint = Vector2.new(0.5, 1)
	row.Position = UDim2.new(0.5, 0, 1, -4)
	row.Size = UDim2.new(0, 0, 0, 64)
	local kicker = b.Kicker
	kicker.AnchorPoint = Vector2.new(0.5, 0)
	kicker.Position = UDim2.new(0.5, 0, 0, 10)
	kicker.TextColor3 = DEEP_GREEN
	kicker.TextSize = 22
	kicker.ZIndex = price.ZIndex + 6
	kicker.Text = if n == "BuyItem" then "BUY ITEM" else "BUY BUNDLE"
end
local sep = actions.Separately
sep.AutomaticSize = Enum.AutomaticSize.None
sep.Size = UDim2.fromOffset(210, 104)
local plate = sep.Plate
plate.AutomaticSize = Enum.AutomaticSize.None
plate.AnchorPoint = Vector2.new(0, 1)
plate.Position = UDim2.new(0, 0, 1, -6)
plate.Size = UDim2.fromOffset(210, 64)
-- the price sits in a Row (like the other price plates), so the plate's own art isn't
-- pushed aside by the list layout
local row = plate:FindFirstChild("Row") or Instance.new("Frame")
row.Name = "Row"
row.BackgroundTransparency = 1
row.AnchorPoint = Vector2.new(0.5, 0.5)
row.Position = UDim2.fromScale(0.5, 0.5)
row.Size = UDim2.new(0, 0, 1, 0)
row.AutomaticSize = Enum.AutomaticSize.X
row.ZIndex = plate.ZIndex + 1
row.Parent = plate
for _, n in { "UIListLayout", "Robux", "Amount", "UIPadding" } do
	local c = plate:FindFirstChild(n)
	if c then
		c.Parent = row
	end
end
local pl = row:FindFirstChildOfClass("UIListLayout")
if pl then
	pl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	pl.VerticalAlignment = Enum.VerticalAlignment.Center
end
sep.Kicker.Position = UDim2.new(0, 6, 0, 4)

-- BUNDLES: full-width skin bundle cards with a hero picture and item tiles
local bundles = scroll.Bundles
local row1 = bundles.Row1
local rl = row1:FindFirstChildOfClass("UIListLayout")
if rl then
	rl.FillDirection = Enum.FillDirection.Vertical
	rl.Padding = UDim.new(0, 22)
end
local W, H = 1280, 420
row1.Size = UDim2.fromOffset(W, 2 * H + 22)
local function hero(card: GuiObject, name: string, ap: Vector2, pos: UDim2, size: UDim2)
	local h = card:FindFirstChild(name) or Instance.new("ImageLabel")
	h.Name = name
	h.BackgroundTransparency = 1
	h.ScaleType = Enum.ScaleType.Fit
	h.AnchorPoint = ap
	h.Position = pos
	h.Size = size
	h.ZIndex = 4 -- over the card's colour, under the words and the price
	h.Image = ""
	h.Parent = card
end
for _, id in { "RuinBlighted", "TempestStrike" } do
	local holder = row1["Bundle_" .. id]
	holder.Size = UDim2.fromOffset(W, H)
	local card = holder.Card
	hero(card, "Hero", Vector2.new(0, 1), UDim2.new(0, 28, 1, 20), UDim2.fromOffset(720, 390))
	local tiles = card:FindFirstChild("Tiles") or Instance.new("Frame")
	tiles.Name = "Tiles"
	tiles.BackgroundTransparency = 1
	tiles.AnchorPoint = Vector2.new(1, 0)
	tiles.Position = UDim2.new(1, -24, 0, 24)
	tiles.Size = UDim2.fromOffset(3 * 150 + 2 * 12, 2 * 150 + 12)
	tiles.ZIndex = 4
	tiles.Parent = card
	local grid = tiles:FindFirstChildOfClass("UIGridLayout") or Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(150, 150)
	grid.CellPadding = UDim2.fromOffset(12, 12)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Right
	grid.Parent = tiles
	for i = 1, 6 do
		local t = tiles:FindFirstChild("Tile" .. i) or Instance.new("TextButton")
		t.Name = "Tile" .. i
		t.LayoutOrder = i
		t.Text = ""
		t.AutoButtonColor = false
		t.BorderSizePixel = 0
		t.BackgroundColor3 = Color3.fromHex("10141B")
		t.BackgroundTransparency = 0.1
		t.ZIndex = 5
		t.Parent = tiles
		local corner = t:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = t
		local pic = t:FindFirstChild("Pic") or Instance.new("ImageLabel")
		pic.Name = "Pic"
		pic.BackgroundTransparency = 1
		pic.ScaleType = Enum.ScaleType.Fit
		pic.AnchorPoint = Vector2.new(0.5, 0.5)
		pic.Position = UDim2.fromScale(0.5, 0.5)
		pic.Size = UDim2.fromScale(0.94, 0.94)
		pic.ZIndex = 6
		pic.Parent = t
	end
end
local starter = bundles.Row3.Bundle_Starter.Card
hero(starter, "Hero", Vector2.new(1, 0.5), UDim2.new(1, -170, 0.5, 0), UDim2.fromOffset(330, 230))
return "Shop UI pass applied"
