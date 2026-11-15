--!strict
-- The Shop (vault/02 Art/UI Shop.md), desktop. Studio-built StarterGui.Shop and
-- StarterGui.LobbyCoins (backup tools/studio/BuildShop.luau); what it sells
-- comes from Lobby/ShopCatalog. This file is the UI only: buying waits for the
-- economy (Coins in player data, ProcessReceipt, case rolls on the server), so
-- every buy shows "coming soon" for now.
--
-- * Router "Shop" (the world blurs; arg = a tab name). Tabs HOME / BUNDLES /
--   DAILY / COINS sit in the one scrolling page and scroll away with it.
-- * The coin counter (top middle) shows while the shop is open and tweens up
--   out of the way once you scroll down; its + opens COINS.
-- * Big cards get a selection frame on hover: four corner brackets close in
--   from outside the card. Small cells just lift.
-- * A bundle shows its contents on hover (cells from the catalog); clicking a
--   cell shows the item card ("NITROUS VANDAL · SKIN · GIVEN TO VANDAL").
-- * Clicking a skin bundle opens its preview (RIVALS-style): the item big in
--   3D (Util/ItemStage: drag to turn, idle wobble), its name and emblem, «
--   BACK, BUY ITEM, BUY BUNDLE, the items-separately total struck through,
--   and the bundle's items in a strip that switches the preview (charms, Mods
--   and coins show as a big card).
-- * A case opens the case popup (case x1; buy with Coins, Robux, x3 Robux) and
--   CONTENTS lists every outcome with its odds (adding up to 100%) and the
--   note. Where PolicyService says paid random items are restricted (or the
--   check fails) the case can't be bought; the server will enforce the same.
-- Phones keep the old placeholder shop (Controllers/Panels) for now.

local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local ShopCatalog = require(ReplicatedStorage.Lobby.ShopCatalog)
local Locker = require(ReplicatedStorage.Shared.Locker)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local ItemStage = require(script.Parent.Parent.Util.ItemStage)
local CloseButton = require(script.Parent.Parent.Util.CloseButton)
local Layout = require(script.Parent.Parent.Util.Layout)
local Router = require(script.Parent.Parent.Util.Router)
local LobbyHud = require(script.Parent.LobbyHud)

local ShopController = {}

local player = Players.LocalPlayer
local DESIGN = Vector2.new(1920, 1080)
local QUINT, QUAD = Enum.EasingStyle.Quint, Enum.EasingStyle.Quad
local IN, OUT = Enum.EasingDirection.In, Enum.EasingDirection.Out
local WHITE, INK = Color3.new(1, 1, 1), Color3.fromHex("141A26")
local CARD = Color3.fromHex("0B1236")
local TAB_OFF_T = 0.2
local TABS = { "HOME", "BUNDLES", "DAILY", "COINS" }
local PAGE_OF = { HOME = "Home", BUNDLES = "Bundles", DAILY = "Daily", COINS = "Coins" }
local COUNTER_HIDE_AT = 50 -- scrolled this far (canvas px), the coin counter leaves (before the tab icons slide under it)
local BRACKET_OUT = 22 -- how far outside its home a selection bracket starts
local KIND_COLOR: { [string]: Color3 } = {
	Mod = Color3.fromHex("FFC83D"),
	Coins = Color3.fromHex("FFC83D"),
	Charm = Color3.fromHex("B58CFF"),
	Emote = Color3.fromHex("FF7AD9"),
}

local gui: ScreenGui
local canvas: Frame
local fit: UIScale
local scroll: ScrollingFrame
local pages: { [string]: Frame } = {}
local tabPlates: { [string]: GuiButton } = {}
local dim: Frame
local popCanvas: Frame
local popFit: UIScale
local casePanel: Frame
local oddsPanel: Frame
local itemCard: Frame
local coinsGui: ScreenGui
local coinsTop: Frame
local coinsFit: UIScale
local coinsAmount: TextLabel
local templates: Folder
local dailyNote: TextLabel?
local preview: Frame
local stage: ItemStage.Stage
local previewBundle: ShopCatalog.Bundle? = nil
local previewCells: { GuiButton } = {}
local openPreview: (bundle: ShopCatalog.Bundle, index: number) -> ()

local isOpen = false
local tab = "HOME"
local counterShown = true
local openCase: ShopCatalog.Case? = nil
local casesRestricted = true -- until PolicyService says otherwise (fail closed)
local resetClose: () -> () = function() end
local openToken = 0

local function tween(
	obj: Instance,
	time: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
): Tween
	local t = TweenService:Create(obj, TweenInfo.new(time, style or QUINT, dir or OUT), goal)
	t:Play()
	return t
end

local function child<T>(parent: Instance, name: string): T
	return (parent:WaitForChild(name) :: any) :: T
end

local function pop(obj: Instance): UIScale?
	local p = obj:FindFirstChild("Pop")
	return if p and p:IsA("UIScale") then p else nil
end

local function rest(scale: UIScale?, to: number)
	if scale then
		scale:SetAttribute("Rest", to)
		tween(scale, 0.18, { Scale = to })
	end
end

local function press(scale: UIScale?)
	if not scale then
		return
	end
	local r = scale:GetAttribute("Rest")
	local home = if typeof(r) == "number" then r else 1
	local t = tween(scale, 0.07, { Scale = home * 0.95 }, QUAD)
	t.Completed:Once(function(state: Enum.PlaybackState)
		if state == Enum.PlaybackState.Completed then
			tween(scale, 0.26, { Scale = home })
		end
	end)
end

local function soon(what: string)
	LobbyHud.toast(what .. " opens with the shop economy", "info")
end

local function commas(n: number): string
	local s = tostring(math.floor(n))
	local out = string.reverse(s):gsub("(%d%d%d)", "%1,")
	out = string.reverse(out)
	return (string.gsub(out, "^,", ""))
end

--------------------------------------------------------------------------------
-- Fitting

local function refit()
	local size = gui.AbsoluteSize
	if size.X > 0 and size.Y > 0 then
		local s = math.min(size.X / DESIGN.X, size.Y / DESIGN.Y)
		fit.Scale = s
		popFit.Scale = s
	end
	local cs = coinsGui.AbsoluteSize
	if cs.X > 0 and cs.Y > 0 then
		coinsFit.Scale = math.clamp(math.min(cs.X / DESIGN.X, cs.Y / DESIGN.Y), 0.6, 1.5)
	end
end

--------------------------------------------------------------------------------
-- Coin counter

local function coins(): number
	local v = player:GetAttribute("Coins")
	return if typeof(v) == "number" and v == v then v else 0
end

local function showCounter(on: boolean)
	if on == counterShown then
		return
	end
	counterShown = on
	tween(coinsTop, if on then 0.32 else 0.22, {
		Position = if on then UDim2.new(0.5, 0, 0, 8) else UDim2.new(0.5, 0, 0, -80),
	}, QUINT, if on then OUT else IN)
end

-- The counter is on while the shop is open, and on the HUD once Coins exist.
local function placeCounter()
	coinsAmount.Text = commas(coins())
	coinsGui.Enabled = isOpen or player:GetAttribute("Coins") ~= nil
end

--------------------------------------------------------------------------------
-- Selection frames and hovers

-- A big card: on hover its four brackets close in from outside; leaving
-- sends them back out and hides them.
local function hookBig(card: GuiButton)
	local sel = card:FindFirstChild("Select")
	local brackets: { { obj: GuiObject, home: UDim2, out: UDim2 } } = {}
	if sel then
		for _, b in sel:GetChildren() do
			if b:IsA("GuiObject") then
				local home = b.Position
				local x = if home.X.Scale > 0.5 then 1 else -1
				local y = if home.Y.Scale > 0.5 then 1 else -1
				table.insert(brackets, {
					obj = b,
					home = home,
					out = home + UDim2.fromOffset(x * BRACKET_OUT, y * BRACKET_OUT),
				})
			end
		end
		(sel :: GuiObject).Visible = false
	end
	local scale = pop(card)
	local hovered = false
	card.MouseEnter:Connect(function()
		hovered = true
		rest(scale, 1.015)
		if sel and sel:IsA("GuiObject") then
			sel.Visible = true
			for _, b in brackets do
				b.obj.Position = b.out
				tween(b.obj, 0.2, { Position = b.home })
			end
		end
	end)
	card.MouseLeave:Connect(function()
		hovered = false
		rest(scale, 1)
		for _, b in brackets do
			tween(b.obj, 0.14, { Position = b.out }, QUINT, IN)
		end
		task.delay(0.14, function()
			if not hovered and sel and sel:IsA("GuiObject") then
				sel.Visible = false
			end
		end)
	end)
	card.Activated:Connect(function()
		press(scale)
	end)
end

local function hookSmall(card: GuiButton)
	local scale = pop(card)
	card.MouseEnter:Connect(function()
		rest(scale, 1.04)
	end)
	card.MouseLeave:Connect(function()
		rest(scale, 1)
	end)
	card.Activated:Connect(function()
		press(scale)
	end)
end

-- Is the mouse inside a GuiObject (both are in screen space: the shop
-- ignores the top bar inset)?
local function mouseOver(obj: GuiObject): boolean
	local m = UserInputService:GetMouseLocation()
	local p, s = obj.AbsolutePosition, obj.AbsoluteSize
	return m.X >= p.X and m.X <= p.X + s.X and m.Y >= p.Y and m.Y <= p.Y + s.Y
end

--------------------------------------------------------------------------------
-- Item card (a bundle's item, clicked)

local function itemColor(item: ShopCatalog.Item): Color3
	if item.kind == "Skin" and item.rarity then
		return ShopCatalog.RARITY_COLOR[item.rarity] or WHITE
	end
	return KIND_COLOR[item.kind]
		or (if item.rarity then ShopCatalog.RARITY_COLOR[item.rarity] else nil)
		or WHITE
end

local function itemSub(item: ShopCatalog.Item): string
	if item.kind == "Skin" then
		return string.format("SKIN  ·  GIVEN TO %s", string.upper(item.gun or ""))
	elseif item.kind == "Mod" then
		return "EXCLUSIVE MOD  ·  JOINS YOUR DRAFT POOL"
	elseif item.kind == "Coins" then
		return string.format("+%s COINS", commas(item.amount or 0))
	end
	return string.upper(item.kind)
end

local function hideItemCard()
	if itemCard.Visible then
		local s = pop(itemCard)
		if s then
			local t = tween(s, 0.12, { Scale = 0.9 }, QUINT, IN)
			t.Completed:Once(function()
				itemCard.Visible = false
			end)
		else
			itemCard.Visible = false
		end
	end
end

local function showItemCard(item: ShopCatalog.Item, at: GuiObject)
	local cell = child(itemCard, "Cell") :: Frame
	cell.BackgroundColor3 = itemColor(item);
	(child(cell, "Kind") :: TextLabel).Text = string.upper(item.kind)
	local words = child(itemCard, "Words") :: Frame;
	(child(words, "Name") :: TextLabel).Text = if item.kind == "Coins"
		then string.format("%s COINS", commas(item.amount or 0))
		else item.name;
	(child(words, "Sub") :: TextLabel).Text = itemSub(item)
	-- above the clicked cell, in canvas space
	local s = math.max(fit.Scale, 0.01)
	local rel = (at.AbsolutePosition - canvas.AbsolutePosition) / s
	local w = at.AbsoluteSize.X / s
	itemCard.Position = UDim2.fromOffset(rel.X + w / 2, rel.Y - 12)
	itemCard.Visible = true
	local sc = pop(itemCard)
	if sc then
		sc.Scale = 0.9
		tween(sc, 0.2, { Scale = 1 })
	end
end

--------------------------------------------------------------------------------
-- Bundles: contents on hover

local function buildBundle(card: GuiButton, bundle: ShopCatalog.Bundle)
	local contents = Instance.new("Frame")
	contents.Name = "Contents"
	contents.Position = UDim2.fromOffset(22, 96)
	contents.Size = UDim2.new(1, -44, 0, 88)
	contents.BackgroundTransparency = 1
	contents.Visible = false
	contents.ZIndex = 6
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = contents
	local cells: { GuiButton } = {}
	-- the cells shrink to fit the card's width (up to 84 px each)
	local holder = card.Parent
	local width = if holder and holder:IsA("GuiObject") then holder.Size.X.Offset - 44 else 360
	local n = #bundle.items
	local cellSize = math.min(84, math.floor((width - 8 * (n - 1)) / math.max(n, 1)))
	contents.Size = UDim2.new(1, -44, 0, cellSize + 4)
	for i, item in bundle.items do
		local c = (templates:WaitForChild("ShopContentCell") :: GuiButton):Clone()
		c.Name = "Item" .. i
		c.LayoutOrder = i
		c.Size = UDim2.fromOffset(cellSize, cellSize)
		c.BackgroundColor3 = itemColor(item);
		(child(c, "Kind") :: TextLabel).Text = string.upper(item.kind);
		(child(c, "Name") :: TextLabel).Text = if item.kind == "Coins"
			then "x" .. commas(item.amount or 0)
			else item.name
		c.Parent = contents
		table.insert(cells, c)
		local sc = pop(c)
		c.MouseEnter:Connect(function()
			rest(sc, 1.06)
		end)
		c.MouseLeave:Connect(function()
			rest(sc, 1)
		end)
		c.Activated:Connect(function()
			press(sc)
			showItemCard(item, c)
		end)
	end
	contents.Parent = card
	local shown = false
	local function show(on: boolean)
		if on == shown then
			return
		end
		shown = on
		if on then
			contents.Visible = true
			for i, c in cells do
				local sc = pop(c)
				if sc then
					sc.Scale = 0
					task.delay((i - 1) * 0.035, function()
						if shown then
							tween(sc, 0.22, { Scale = 1 })
						end
					end)
				end
			end
		else
			contents.Visible = false
			hideItemCard()
		end
	end
	card.MouseEnter:Connect(function()
		show(true)
	end)
	card.MouseLeave:Connect(function()
		-- moving onto one of its own cells isn't leaving
		task.defer(function()
			if not mouseOver(card) then
				show(false)
			end
		end)
	end)
	card.Activated:Connect(function()
		local first = 1
		for i, item in bundle.items do
			if item.kind == "Skin" then
				first = i
				break
			end
		end
		openPreview(bundle, first)
	end)
end

--------------------------------------------------------------------------------
-- Popups: the case, its contents

local popupOpen: Frame? = nil

local function showPanel(panel: Frame?)
	local was = popupOpen
	popupOpen = panel
	for _, p in { casePanel, oddsPanel } do
		if p ~= panel then
			p.Visible = false
		end
	end
	if panel then
		dim.Visible = true
		popCanvas.Visible = true
		if not was then
			dim.BackgroundTransparency = 1
			tween(dim, 0.2, { BackgroundTransparency = 0.35 })
		end
		panel.Visible = true
		local sc = pop(panel)
		if sc then
			sc.Scale = 0.92
			tween(sc, 0.24, { Scale = 1 })
		end
	else
		local t = tween(dim, 0.16, { BackgroundTransparency = 1 }, QUINT, IN)
		t.Completed:Once(function()
			if not popupOpen then
				dim.Visible = false
				popCanvas.Visible = false
			end
		end)
	end
end

local function fillOdds(case: ShopCatalog.Case)
	local list = child(oddsPanel, "List") :: ScrollingFrame
	for _, c in list:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	(child(oddsPanel, "Sub") :: TextLabel).Text = case.name;
	(child(oddsPanel, "Note") :: TextLabel).Text = ShopCatalog.ODDS_NOTE
	local odds = ShopCatalog.odds(case)
	for i, item in case.contents do
		local row = (templates:WaitForChild("ShopOddsRow") :: Frame):Clone()
		row.Name = "Row" .. i
		row.LayoutOrder = i
		local color = if item.rarity then ShopCatalog.RARITY_COLOR[item.rarity] else WHITE;
		(child(row, "Cell") :: Frame).BackgroundColor3 = color or WHITE
		local name = child(row, "Name") :: TextLabel
		name.Text = item.name
		name.TextColor3 = color or WHITE;
		(child(row, "Sub") :: TextLabel).Text = string.format(
			"%s %s  ·  %s",
			string.upper(item.rarity or ""),
			string.upper(item.kind),
			string.upper(item.gun or "")
		);
		(child(row, "Pct") :: TextLabel).Text = ShopCatalog.formatOdds(odds[i])
		row.Parent = list
	end
end

local function setPlate(button: Instance, amount: string)
	local plate = button:FindFirstChild("Price")
	local row = plate and plate:FindFirstChild("Row")
	local label = row and row:FindFirstChild("Amount")
	if label and label:IsA("TextLabel") then
		label.Text = amount
	end
end

local function openCasePopup(case: ShopCatalog.Case)
	openCase = case;
	(child(casePanel, "Title") :: TextLabel).Text = case.name
	local placeholder = child(casePanel, "Placeholder") :: Frame
	placeholder.BackgroundColor3 = case.color
	placeholder.Visible = case.art == nil
	local art = child(casePanel, "Art") :: ImageLabel
	art.Image = case.art or ""
	setPlate(child(casePanel, "BuyCoins"), commas(case.coins))
	setPlate(child(casePanel, "BuyRobux"), commas(case.robux))
	setPlate(child(casePanel, "BuyRobux3"), commas(case.robux3))
	showPanel(casePanel)
end

local function buyCase()
	if casesRestricted then
		LobbyHud.toast("Cases aren't available where you are", "error")
		return
	end
	soon("Buying cases")
end

--------------------------------------------------------------------------------
-- The skin-bundle preview

local function plateAmount(button: Instance, amount: string)
	local plate = button:FindFirstChild("Price")
	local row = plate and plate:FindFirstChild("Row")
	local label = row and row:FindFirstChild("Amount")
	if label and label:IsA("TextLabel") then
		label.Text = amount
	end
end

local function kindWord(item: ShopCatalog.Item): string
	return if item.kind == "Coins" then "COINS" else string.upper(item.kind)
end

local function forWords(item: ShopCatalog.Item): string
	if item.kind == "Skin" then
		local cfg = item.gun and Weapons.get(item.gun)
		return "FOR THE " .. string.upper(if cfg then cfg.displayName else (item.gun or ""))
	elseif item.kind == "Mod" then
		return "EXCLUSIVE MOD  ·  JOINS YOUR DRAFT POOL"
	elseif item.kind == "Coins" then
		return string.format("+%s COINS", commas(item.amount or 0))
	end
	return kindWord(item)
end

local function selectPreview(index: number)
	local bundle = previewBundle
	if not bundle then
		return
	end
	local item = bundle.items[index]
	if not item then
		return
	end
	local head = child(preview, "Head") :: Frame
	local emblem = child(head, "Emblem") :: ImageLabel
	local line = item.line
	local emblemId = if line then Locker.EMBLEMS[line] else nil
	emblem.Visible = emblemId ~= nil and emblemId ~= ""
	emblem.Image = emblemId or ""
	emblem.ImageColor3 = if line then (Locker.COLORS[line] or WHITE) else WHITE;
	(child(head, "Title") :: TextLabel).Text = if item.kind == "Coins"
		then string.format("%s COINS", commas(item.amount or 0))
		else item.name;
	(child(head, "Kind") :: TextLabel).Text = "·  " .. kindWord(item)
	local forChip = child(preview, "For") :: Frame;
	(child(forChip, "Label") :: TextLabel).Text = forWords(item)

	-- a skin turns in 3D; anything else is a big card
	local stageBox = child(preview, "StageBox") :: Frame
	local bigCard = child(stageBox, "Card") :: Frame
	local hint = child(preview, "Hint") :: GuiObject
	local model: Model? = nil
	if item.kind == "Skin" and item.gun then
		model = (if line then Locker.skinModel(item.gun, line) else nil)
			or Locker.gunModel(item.gun)
	end
	if model then
		local cfg = item.gun and Weapons.get(item.gun)
		stage:show(model, cfg ~= nil and cfg.class == "Melee")
		bigCard.Visible = false
		hint.Visible = true
	else
		stage:show(nil)
		bigCard.BackgroundColor3 = itemColor(item);
		(child(bigCard, "Kind") :: TextLabel).Text = kindWord(item);
		(child(bigCard, "Name") :: TextLabel).Text = if item.kind == "Coins"
			then "x" .. commas(item.amount or 0)
			else item.name
		bigCard.Visible = true
		local sc = pop(bigCard)
		if sc then
			sc.Scale = 0.85
			tween(sc, 0.3, { Scale = 1 })
		end
		hint.Visible = false
	end

	-- prices: the item alone (if it's sold alone), the bundle, the items one by one
	local actions = child(preview, "Actions") :: Frame
	local buyItem = child(actions, "BuyItem") :: GuiButton
	local itemPrice = ShopCatalog.itemRobux(item)
	buyItem.Visible = itemPrice ~= nil
	if itemPrice then
		plateAmount(buyItem, commas(itemPrice))
	end
	-- the strip: the open item is up and bright, the rest a touch back
	for i, c in previewCells do
		local on = i == index
		rest(pop(c), if on then 1.1 else 1)
		tween(c, 0.15, { BackgroundTransparency = if on then 0 else 0.35 })
	end
end

openPreview = function(bundle: ShopCatalog.Bundle, index: number)
	previewBundle = bundle
	hideItemCard()
	showPanel(nil)
	-- the strip: one cell per item
	local strip = child(preview, "Strip") :: Frame
	for _, c in previewCells do
		c:Destroy()
	end
	table.clear(previewCells)
	for i, item in bundle.items do
		local c = (templates:WaitForChild("ShopContentCell") :: GuiButton):Clone()
		c.Name = "Item" .. i
		c.LayoutOrder = i
		c.Size = UDim2.fromOffset(120, 120)
		c.BackgroundColor3 = itemColor(item)
		c.ZIndex = 12
		for _, d in c:GetDescendants() do
			if d:IsA("GuiObject") then
				d.ZIndex = 13
			end
		end
		(child(c, "Kind") :: TextLabel).Text = kindWord(item);
		(child(c, "Name") :: TextLabel).Text = if item.kind == "Coins"
			then "x" .. commas(item.amount or 0)
			else item.name
		c.Parent = strip
		table.insert(previewCells, c)
		c.MouseEnter:Connect(function()
			local sc = pop(c)
			if sc and (sc:GetAttribute("Rest") or 1) < 1.1 then
				tween(sc, 0.15, { Scale = 1.05 })
			end
		end)
		c.MouseLeave:Connect(function()
			local sc = pop(c)
			if sc then
				local r = sc:GetAttribute("Rest")
				tween(sc, 0.15, { Scale = if typeof(r) == "number" then r else 1 })
			end
		end)
		c.Activated:Connect(function()
			press(pop(c))
			selectPreview(i)
		end)
	end
	-- prices that don't change per item
	local actions = child(preview, "Actions") :: Frame
	plateAmount(child(actions, "BuyBundle"), commas(bundle.robux))
	local separately = ShopCatalog.separately(bundle)
	local was = child(actions, "Separately") :: Frame
	was.Visible = separately > bundle.robux
	local wasLabel = child(child(was, "Plate"), "Amount") :: TextLabel
	wasLabel.Text = commas(separately)

	-- the page steps aside; the preview comes in
	scroll.Visible = false
	showCounter(false)
	preview.Visible = true
	stage:run(true)
	for _, name in { "Head", "For" } do
		local o = child(preview, name) :: GuiObject
		local h = o:GetAttribute("Home")
		local home = if typeof(h) == "UDim2" then h else o.Position
		o:SetAttribute("Home", home)
		o.Position = home - UDim2.fromOffset(0, 30)
		tween(o, 0.4, { Position = home })
	end
	for _, name in { "Actions", "Strip" } do
		local o = child(preview, name) :: GuiObject
		local h = o:GetAttribute("Home")
		local home = if typeof(h) == "UDim2" then h else o.Position
		o:SetAttribute("Home", home)
		o.Position = home + UDim2.fromOffset(0, 40)
		tween(o, 0.42, { Position = home })
	end
	for i, c in previewCells do
		local sc = pop(c)
		if sc then
			sc.Scale = 0
			task.delay(0.08 + i * 0.04, function()
				if previewBundle == bundle then
					rest(sc, if i == index then 1.1 else 1)
				end
			end)
		end
	end
	selectPreview(index)
end

local function closePreview()
	if not previewBundle then
		return
	end
	previewBundle = nil
	stage:run(false)
	stage:show(nil)
	preview.Visible = false
	scroll.Visible = true
	showCounter(scroll.CanvasPosition.Y < COUNTER_HIDE_AT)
end

--------------------------------------------------------------------------------
-- Tabs and pages

local function styleTab(name: string, on: boolean)
	local plate = tabPlates[name]
	if not plate then
		return
	end
	tween(plate, 0.15, {
		BackgroundColor3 = if on then WHITE else CARD,
		BackgroundTransparency = if on then 0 else TAB_OFF_T,
	})
	local label = plate:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		tween(label, 0.15, { TextColor3 = if on then INK else WHITE })
	end
end

-- The open page's cards rise into place one after another.
local function rise(page: Frame)
	local n = 0
	for _, d in page:GetDescendants() do
		if d:IsA("GuiButton") and d.Name == "Card" then
			local sc = pop(d)
			if sc and n < 14 then
				n += 1
				sc.Scale = 0.94
				task.delay(n * 0.02, function()
					tween(sc, 0.26, { Scale = 1 })
				end)
			end
		end
	end
end

local function setTab(name: string, animate: boolean)
	if not PAGE_OF[name] then
		name = "HOME"
	end
	hideItemCard()
	tab = name
	for _, t in TABS do
		styleTab(t, t == name)
		pages[PAGE_OF[t]].Visible = t == name
	end
	scroll.CanvasPosition = Vector2.zero
	showCounter(true)
	if animate then
		rise(pages[PAGE_OF[name]])
	end
end

local function hookTab(name: string, plate: GuiButton)
	local icon = plate:FindFirstChild("Icon")
	local home = if icon and icon:IsA("GuiObject") then icon.Position else UDim2.new()
	local scale = pop(plate)
	plate.MouseEnter:Connect(function()
		if icon and icon:IsA("GuiObject") then
			tween(
				icon,
				0.18,
				{ Position = home - UDim2.fromOffset(0, 8), Size = UDim2.fromOffset(106, 106) }
			)
		end
	end)
	plate.MouseLeave:Connect(function()
		if icon and icon:IsA("GuiObject") then
			tween(icon, 0.18, { Position = home, Size = UDim2.fromOffset(96, 96) })
		end
	end)
	plate.Activated:Connect(function()
		press(scale)
		if tab ~= name then
			setTab(name, true)
		end
	end)
end

--------------------------------------------------------------------------------
-- Daily timer (display only; the server will own the rotation's end time)

local function updateDaily()
	local note = dailyNote
	if not note then
		return
	end
	local left = 86400 - (os.time() % 86400)
	note.Text = string.format("NEW ITEMS IN %dH %02dM", left // 3600, (left % 3600) // 60)
end

--------------------------------------------------------------------------------
-- Open / close

local function open(arg: any?)
	openToken += 1
	local my = openToken
	local wanted = if typeof(arg) == "string" then arg else "HOME"
	if isOpen then
		setTab(wanted, true)
		return
	end
	isOpen = true
	gui.Enabled = true
	refit()
	resetClose()
	placeCounter()
	counterShown = false
	coinsTop.Position = UDim2.new(0.5, 0, 0, -80)
	showCounter(true)
	local wash = gui:FindFirstChild("Wash")
	if wash and wash:IsA("Frame") then
		wash.BackgroundTransparency = 1
		tween(wash, 0.25, { BackgroundTransparency = 0.3 })
	end
	scroll.Position = UDim2.fromOffset(960, 36)
	tween(scroll, 0.4, { Position = UDim2.fromOffset(960, 0) })
	setTab(wanted, true)
	updateDaily()
	task.spawn(function()
		while isOpen and openToken == my do
			task.wait(20)
			updateDaily()
		end
	end)
end

local function close()
	if not isOpen then
		return
	end
	isOpen = false
	openToken += 1
	local my = openToken
	closePreview()
	showPanel(nil)
	hideItemCard()
	showCounter(false)
	local wash = gui:FindFirstChild("Wash")
	if wash and wash:IsA("Frame") then
		tween(wash, 0.16, { BackgroundTransparency = 1 }, QUINT, IN)
	end
	tween(scroll, 0.16, { Position = UDim2.fromOffset(960, 24) }, QUINT, IN)
	task.delay(0.18, function()
		if openToken == my and not isOpen then
			gui.Enabled = false
			placeCounter()
			if player:GetAttribute("Coins") ~= nil then
				showCounter(true)
			end
		end
	end)
end

--------------------------------------------------------------------------------

function ShopController.init()
	if Layout.isPhone() then
		return -- phones keep the old placeholder shop (Controllers/Panels)
	end
	local playerGui = player:WaitForChild("PlayerGui")
	local g = playerGui:WaitForChild("Shop", 15)
	local cg = playerGui:WaitForChild("LobbyCoins", 15)
	if not g or not g:IsA("ScreenGui") or not cg or not cg:IsA("ScreenGui") then
		warn("[Shop] StarterGui.Shop / LobbyCoins missing (tools/studio/BuildShop.luau)")
		return
	end
	gui = g
	gui.Enabled = false
	coinsGui = cg
	coinsGui.Enabled = false
	templates = ReplicatedStorage:WaitForChild("UiTemplates"):WaitForChild("Lobby") :: Folder
	canvas = child(gui, "Canvas")
	fit = child(canvas, "Fit")
	scroll = child(canvas, "Scroll")
	dim = child(gui, "Dim")
	popCanvas = child(gui, "PopupCanvas")
	popFit = child(popCanvas, "Fit")
	casePanel = child(popCanvas, "CasePanel")
	oddsPanel = child(popCanvas, "OddsPanel")
	itemCard = child(canvas, "ItemCard")
	coinsTop = child(coinsGui, "Top")
	coinsFit = child(coinsTop, "Fit")
	local bar = child(coinsTop, "Bar") :: Frame
	coinsAmount = child(bar, "Amount")
	for _, name in TABS do
		pages[PAGE_OF[name]] = child(scroll, PAGE_OF[name])
		tabPlates[name] = child(child(child(scroll, "Tabs"), name), "Plate")
		hookTab(name, tabPlates[name])
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
	coinsGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)

	-- every card: big ones get the selection frame, small ones lift
	for _, d in scroll:GetDescendants() do
		if d:IsA("GuiButton") and d.Name == "Card" then
			if d:FindFirstChild("Select") then
				hookBig(d)
			else
				hookSmall(d)
			end
		end
	end

	-- cases
	local home = pages.Home
	for _, c in ShopCatalog.CASES do
		local holder = home:FindFirstChild("Case_" .. c.id, true)
		local card = holder and holder:FindFirstChild("Card")
		if card and card:IsA("GuiButton") then
			card.Activated:Connect(function()
				openCasePopup(c)
			end)
		end
	end
	-- bundles
	for _, b in ShopCatalog.BUNDLES do
		local holder = pages.Bundles:FindFirstChild("Bundle_" .. b.id, true)
		local card = holder and holder:FindFirstChild("Card")
		if card and card:IsA("GuiButton") then
			buildBundle(card, b)
		end
	end
	-- everything else that sells waits for the economy
	local function soonOn(holderName: string, what: string)
		local holder = scroll:FindFirstChild(holderName, true)
		local card = holder and holder:FindFirstChild("Card")
		if card and card:IsA("GuiButton") then
			card.Activated:Connect(function()
				soon(what)
			end)
		end
	end
	soonOn("SeasonPass", "The season pass")
	soonOn("Offer", "Special offers")
	for i = 1, 6 do
		soonOn("Pack" .. i, "Buying coins")
	end
	for i = 1, 8 do
		soonOn("Item" .. i, "The daily shop")
	end
	for _, n in { "Charm_1", "Charm_2", "Charm_3", "Emote_1", "Emote_2", "Emote_3" } do
		soonOn(n, "Buying cosmetics")
	end
	local passCard = scroll:FindFirstChild("SeasonPass", true)
	local view = passCard and passCard:FindFirstChild("View", true)
	if view and view:IsA("GuiButton") then
		view.Activated:Connect(function()
			soon("The season pass")
		end)
	end
	local day4 = scroll:FindFirstChild("Day4", true)
	if day4 and day4:IsA("GuiObject") then
		day4.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				soon("Login rewards")
			end
		end)
	end
	local head = scroll:FindFirstChild("Head_TODAY'S ITEMS", true)
	local note = head and head:FindFirstChild("Note")
	dailyNote = if note and note:IsA("TextLabel") then note else nil

	-- popups
	CloseButton.hook(child(casePanel, "Close") :: GuiButton, function()
		showPanel(nil)
	end)
	CloseButton.hook(child(oddsPanel, "Close") :: GuiButton, function()
		showPanel(casePanel) -- back to the case
	end)
	local contentsB = child(casePanel, "Contents") :: GuiButton
	contentsB.Activated:Connect(function()
		press(pop(contentsB))
		local c = openCase
		if c then
			fillOdds(c)
			showPanel(oddsPanel)
		end
	end)
	for _, n in { "BuyCoins", "BuyRobux", "BuyRobux3" } do
		local b = child(casePanel, n) :: GuiButton
		local sc = pop(b)
		b.MouseEnter:Connect(function()
			rest(sc, 1.05)
		end)
		b.MouseLeave:Connect(function()
			rest(sc, 1)
		end)
		b.Activated:Connect(function()
			press(sc)
			buyCase()
		end)
	end
	-- a click anywhere off a bundle's cells hides the item card
	UserInputService.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and itemCard.Visible then
			task.defer(function()
				if not mouseOver(itemCard) then
					local over = false
					for _, d in pages.Bundles:GetDescendants() do
						if
							d:IsA("GuiButton")
							and d.Parent
							and d.Parent.Name == "Contents"
							and mouseOver(d)
						then
							over = true
						end
					end
					if not over then
						hideItemCard()
					end
				end
			end)
		end
	end)

	-- the counter: its + opens COINS; it leaves once you scroll down
	local plus = child(bar, "Plus") :: GuiButton
	plus.Activated:Connect(function()
		press(pop(plus))
		Router.open("Shop", "COINS")
	end)
	scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		if isOpen then
			showCounter(scroll.CanvasPosition.Y < COUNTER_HIDE_AT)
		end
	end)

	resetClose = CloseButton.hook(child(canvas, "Close") :: GuiButton, function()
		if popupOpen then
			showPanel(nil)
		else
			Router.close()
		end
	end)
	-- the skin-bundle preview
	preview = child(canvas, "Preview")
	local stageBox = child(preview, "StageBox") :: Frame
	stage = ItemStage.new(
		child(stageBox, "Stage") :: Frame,
		{ length = 9, height = 3.1, distance = 11 }
	)
	stage:bindDrag(child(stageBox, "DragArea") :: GuiButton)
	local actions = child(preview, "Actions") :: Frame
	local backB = child(actions, "Back") :: GuiButton
	backB.MouseEnter:Connect(function()
		rest(pop(backB), 1.04)
	end)
	backB.MouseLeave:Connect(function()
		rest(pop(backB), 1)
	end)
	backB.Activated:Connect(function()
		press(pop(backB))
		closePreview()
	end)
	for _, n in { "BuyItem", "BuyBundle" } do
		local b = child(actions, n) :: GuiButton
		b.MouseEnter:Connect(function()
			rest(pop(b), 1.05)
		end)
		b.MouseLeave:Connect(function()
			rest(pop(b), 1)
		end)
		b.Activated:Connect(function()
			press(pop(b))
			soon(if n == "BuyItem" then "Buying items" else "Buying bundles")
		end)
	end

	Router.register("Shop", { open = open, close = close })
end

function ShopController.start()
	if not gui then
		return
	end
	player:GetAttributeChangedSignal("Coins"):Connect(placeCounter)
	placeCounter()
	-- cases: fail closed until Roblox says paid random items are allowed here
	task.spawn(function()
		local ok, info = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(player)
		end)
		casesRestricted = not (
			ok
			and typeof(info) == "table"
			and info.ArePaidRandomItemsRestricted == false
		)
	end)
end

return ShopController
