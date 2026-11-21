--!strict
-- Shop layout v2 (owner 2026-11-20, vault/02 Art/UI Shop.md → Layout v2): patches the
-- Studio-owned StarterGui.Shop in place (so hand edits elsewhere survive; BuildShop.luau
-- is the older full builder). Re-runnable. Lobby place, Edit mode; save the place after.
--   HOME:    the four cases as square tiles in a 2 x 2 grid; the Season Pass fills the rest
--   BUNDLES: FEATURED (Ruin-Blighted, Tempest-Strike side by side), LIMITED TIME
--            (the Thanksgiving bundle, full width). Words and prices come from
--            ShopCatalog.BUNDLES at runtime (ShopController).

local SG = game:GetService("StarterGui")
local scroll = (SG:WaitForChild("Shop") :: any).Canvas.Scroll

local TILE, GAP, W = 208, 16, 1280

-- a child that must exist (this patch fails loudly, naming what's missing)
local function need(parent: Instance, name: string): any
	local c = parent:FindFirstChild(name)
	assert(c, `Shop layout v2: {parent:GetFullName()} has no {name}`)
	return c
end

------------------------------------------------------------------ HOME
local home = scroll.Home
local top = home.Top
local cases = top.Cases
local caseBlock = TILE * 2 + GAP
top.Size = UDim2.fromOffset(W, caseBlock)
cases.Size = UDim2.fromOffset(caseBlock, caseBlock)
local list = cases:FindFirstChildWhichIsA("UIListLayout")
if list then
	list:Destroy()
end
local grid = cases:FindFirstChildWhichIsA("UIGridLayout") or Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(TILE, TILE)
grid.CellPadding = UDim2.fromOffset(GAP, GAP)
grid.FillDirectionMaxCells = 2
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = cases
for i, id in { "Standard", "Elite", "Apex", "Knife" } do
	local holder = cases:FindFirstChild("Case_" .. id)
	if holder then
		holder.LayoutOrder = i
		holder.Size = UDim2.fromOffset(TILE, TILE)
		local card = holder.Card
		local name = need(card, "Name") :: TextLabel
		name.AnchorPoint = Vector2.new(0.5, 0)
		name.Position = UDim2.new(0.5, 0, 0, 12)
		local kind = need(card, "Kind") :: TextLabel
		kind.Visible = false
		local art = need(card, "CaseArt") :: ImageLabel
		art.AnchorPoint = Vector2.new(0.5, 0.5)
		art.Position = UDim2.new(0.5, 0, 0, 100)
		art.Size = UDim2.fromOffset(200, 140) -- no card behind it, so it can be big
		local price = need(card, "Price") :: Frame
		price.AnchorPoint = Vector2.new(0.5, 1)
		price.Position = UDim2.new(0.5, 0, 1, -12)
	end
end
top.SeasonPass.Size = UDim2.fromOffset(W - caseBlock - 24, caseBlock)

------------------------------------------------------------------ BUNDLES
local bundles = scroll.Bundles
local row1, row2 = bundles.Row1, bundles.Row2
local found = bundles:FindFirstChild("Bundle_RuinBlighted", true)
	or bundles:FindFirstChild("Bundle_Heavy", true)
local template: any
if found then
	template = found:Clone()
else
	-- no bundle card left: the Coins pack card is the same card (art, shade, words, a Robux plate)
	template = need(need(scroll, "Coins"), "Packs"):FindFirstChild("Pack1")
	assert(template, "no card to copy")
	template = template:Clone()
	local c = need(template, "Card")
	local packArt = c:FindFirstChild("PackArt")
	if packArt then
		packArt:Destroy()
	end
	local title = need(c, "Amount") :: TextLabel
	title.Name = "Title"
	title.TextSize = 34
	title.Position = UDim2.fromOffset(22, 18)
	local sub = need(c, "Kind") :: TextLabel
	sub.Name = "Sub"
	sub.TextSize = 18
	sub.Position = UDim2.fromOffset(24, 58)
	sub.TextColor3 = Color3.fromHex("DDE3EA") -- gold is the act-now colour
	need(c, "Art").Image = "" -- flat colour until the owner's bundle banners land
end

local function card(id: string, parent: Instance, size: Vector2, order: number)
	local old = parent:FindFirstChild("Bundle_" .. id)
	if old then
		old:Destroy()
	end
	local b = template:Clone()
	b.Name = "Bundle_" .. id
	b.Size = UDim2.fromOffset(size.X, size.Y)
	b.LayoutOrder = order
	local c = b.Card
	-- a line under the name (what's in it), the tag under that
	local title = need(c, "Title") :: TextLabel
	if not c:FindFirstChild("Sub") then
		local s = title:Clone()
		s.Name = "Sub"
		s.TextSize = 18
		s.Size = UDim2.fromOffset(0, 22)
		s.Position = UDim2.fromOffset(24, 58)
		s.TextTransparency = 0.1
		s.Parent = c
	end
	-- the tag: a small slanted plate made from the card's own price plate
	-- lihfolk-ignore: findfirstchild-chain (nil-checked on the next line; the cast confuses the check)
	local tag = c:FindFirstChild("Tag") :: Frame?
	if not tag then
		local t = (need(c, "Price") :: Frame):Clone()
		t.Name = "Tag"
		local row = need(t, "Row")
		local icon = row:FindFirstChild("Robux")
		if icon then
			icon:Destroy()
		end
		local label = need(row, "Amount") :: TextLabel
		label.Name = "Label"
		label.Parent = t
		row:Destroy()
		label.TextSize = 16
		label.Size = UDim2.fromOffset(0, 28)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 14), UDim.new(0, 14)
		pad.Parent = t
		t.Size = UDim2.fromOffset(0, 28)
		t.AnchorPoint = Vector2.zero
		t.BackgroundColor3 = Color3.fromHex("FF3B3B")
		-- lihfolk-ignore: findfirstchild-chain (nil-checked on the next line)
		local skin = t:FindFirstChild("Skin", true) :: ImageLabel?
		if skin then
			skin.ImageColor3 = Color3.fromHex("FF4F4F")
		end
		t.Parent = c
		tag = t
	end
	(tag :: Frame).Position = UDim2.fromOffset(22, 90)
	b.Parent = parent
	return b
end

for _, r in { row1, row2 } do
	for _, ch in r:GetChildren() do
		if ch:IsA("Frame") and string.sub(ch.Name, 1, 7) == "Bundle_" then
			ch:Destroy()
		end
	end
end
row1.Size = UDim2.fromOffset(W, 340)
card("RuinBlighted", row1, Vector2.new((W - 24) / 2, 340), 1)
card("TempestStrike", row1, Vector2.new((W - 24) / 2, 340), 2)
row2.Size = UDim2.fromOffset(W, 240)
row2.LayoutOrder = 4
card("Thanksgiving", row2, Vector2.new(W, 240), 1)

local head = bundles:FindFirstChild("Head_BUNDLES") or bundles:FindFirstChild("Head_FEATURED")
assert(head, "no bundles header")
head.Name = "Head_FEATURED"
head.LayoutOrder = 1;
(need(head, "Label") :: TextLabel).Text = "FEATURED"
local limited = bundles:FindFirstChild("Head_LIMITED")
if not limited then
	limited = head:Clone()
	limited.Name = "Head_LIMITED"
	limited.Parent = bundles
end
limited.LayoutOrder = 3;
(need(limited, "Label") :: TextLabel).Text = "LIMITED TIME"
row1.LayoutOrder = 2

-- each card's colour (its art backdrop is tinted with it)
local COLORS = {
	RuinBlighted = Color3.fromHex("2A6F6A"),
	TempestStrike = Color3.fromHex("2F5DB8"),
	Thanksgiving = Color3.fromHex("C9822B"),
}
for id, col in COLORS do
	local b = need(id == "Thanksgiving" and row2 or row1, "Bundle_" .. id)
	local art = need(need(b, "Card"), "Art") :: ImageLabel
	art.BackgroundColor3 = col
	art.ImageColor3 = col
end
template:Destroy()

------------------------------------------------------------------ LOOK
-- Owner 2026-11-20 ("I don't like the gradients on the item list"; RIVALS shop refs):
-- cases float with no card behind them; item cards are one flat, deep colour (no shade
-- gradient), the item's picture big on it (ShopController fills Daily from ShopCatalog).
local StateValues = require(game:GetService("ReplicatedStorage").Shared.StateValues)
local INK = Color3.fromHex("0E0F13")
local function flat(c: Instance)
	if StateValues.get(c, "Flat") == true then
		return -- already done (re-runs don't deepen it twice)
	end
	StateValues.set(c, "Flat", true)
	local shade = c:FindFirstChild("Shade")
	if shade and shade:IsA("GuiObject") then
		shade.Visible = false
	end
	local art = c:FindFirstChild("Art")
	if art and art:IsA("GuiObject") then
		art.BackgroundColor3 = art.BackgroundColor3:Lerp(INK, 0.3)
		art.BackgroundTransparency = 0
	end
end
for _, holder in cases:GetChildren() do
	local c = holder:FindFirstChild("Card")
	if c and c:IsA("GuiButton") then
		StateValues.set(c, "NoCard", true) -- Util/Cards skips it: no plate skin behind the case
		c.BackgroundTransparency = 1
		local art = c:FindFirstChild("Art")
		if art and art:IsA("ImageLabel") then
			art.BackgroundTransparency = 1
			art.Image = ""
		end
		local shade = c:FindFirstChild("Shade")
		if shade and shade:IsA("GuiObject") then
			shade.Visible = false
		end
	end
end
for _, parent in
	{ need(need(home, "Mid"), "Cosmetics"), need(need(scroll, "Daily"), "Items"), row1, row2 }
do
	for _, holder in parent:GetChildren() do
		local c = holder:FindFirstChild("Card")
		if c then
			flat(c)
		end
	end
end
return "shop layout v2 applied"
