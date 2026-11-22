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
-- Every device; Shared/UiLayout sizes it (the Fit scales on Canvas, PopupCanvas, Top).

local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiRoot = require(ReplicatedStorage.Shared.UiRoot)
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local UserInputService = game:GetService("UserInputService")

local ShopCatalog = require(ReplicatedStorage.Lobby.ShopCatalog)
local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local UiSfx = require(ReplicatedStorage.Shared.UiSfx)
local RunService = game:GetService("RunService")
local Locker = require(ReplicatedStorage.Shared.Locker)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Skins = require(ReplicatedStorage.Shared.Config.Skins)
local SkinArt = require(ReplicatedStorage.Shared.SkinArt)
local SkinCases = require(ReplicatedStorage.Shared.SkinCases)
local ItemStage = require(script.Parent.Parent.Util.ItemStage)
local OddsList = require(script.Parent.Parent.Util.OddsList)
local Pivot = require(script.Parent.Parent.Util.Pivot)
local Thumb = require(script.Parent.Parent.Util.Thumb)
local Plates = require(script.Parent.Parent.Util.Plates)
local CloseButton = require(script.Parent.Parent.Util.CloseButton)
local Router = require(script.Parent.Parent.Util.Router)
local Release = require(game:GetService("ReplicatedStorage").Shared.Config.Release)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Inventory = require(ReplicatedStorage.Shared.Config.Inventory)
local LoginRewards = require(ReplicatedStorage.Shared.LoginRewards)
local LobbyHud = require(script.Parent.LobbyHud)
local UiMotion = require(game:GetService("ReplicatedStorage").Shared.UiMotion) -- the one motion module
local KM = UiMotion.M

local ShopController = {}

local player = Players.LocalPlayer
local QUINT = Enum.EasingStyle.Quint
local IN, OUT = Enum.EasingDirection.In, Enum.EasingDirection.Out
local WHITE, INK = Color3.new(1, 1, 1), Color3.fromHex("1A1A1D")
local CARD = Color3.fromHex("141417")
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
local casePanel: Frame
local oddsPanel: Frame
local itemCard: Frame
local coinsGui: ScreenGui
local coinsTop: Frame
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
local counterShown = false -- starts off-screen (y -80); placeCounter brings it in
local openCase: ShopCatalog.Case? = nil
local casesRestricted = true -- until PolicyService says otherwise (fail closed)
local resetClose: () -> () = function() end
local openToken = 0

local tween = UiMotion.tween

local function child<T>(parent: Instance, name: string): T
	return (parent:WaitForChild(name) :: any) :: T
end

local function pop(obj: Instance): UIScale?
	local p = obj:FindFirstChild("Pop")
	return if p and p:IsA("UIScale") then p else nil
end

local function rest(p: UIScale?, scale: number)
	if p then
		UiMotion.rest(p, scale)
	end
end

local function press(p: UIScale?, _low: number?)
	if p then
		UiMotion.press(p)
	end
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
-- Coin counter

local function coins(): number
	local v = StateValues.get(player, "Coins")
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

-- The counter is the HUD's currency (owner: "a coin section ... at the top
-- middle of the screen like rivals does with its keys"): on whenever no other
-- page is open, and in the shop. It reads 0 until the economy gives Coins.
local function hudCounter(): boolean
	local page = Router.current()
	return page == nil or page == "Shop"
end
local function placeCounter()
	coinsAmount.Text = commas(coins())
	local on = hudCounter()
	coinsGui.Enabled = on
	if on and not isOpen then
		showCounter(true)
	end
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
		rest(scale, KM.hoverCard) -- the card pops inside the closing brackets (RIVALS: grows on hover)
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
		rest(scale, KM.hoverCard)
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
	Thumb.item(cell, item)
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
	itemCard.AnchorPoint = Vector2.new(0.5, 0.5)
	itemCard.Position = UDim2.fromOffset(rel.X + w / 2, rel.Y - 12 - itemCard.Size.Y.Offset / 2)
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
		c.BackgroundColor3 = itemColor(item)
		Thumb.item(c, item);
		(child(c, "Kind") :: TextLabel).Text = string.upper(item.kind);
		(child(c, "Name") :: TextLabel).Text = if item.kind == "Coins"
			then "x" .. commas(item.amount or 0)
			else item.name
		c.Parent = contents
		Pivot.wrap(c)
		table.insert(cells, c)
		local sc = pop(c)
		c.MouseEnter:Connect(function()
			rest(sc, KM.hoverCard)
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
	(child(oddsPanel, "Sub") :: TextLabel).Text = case.name;
	(child(oddsPanel, "Note") :: TextLabel).Text = ShopCatalog.ODDS_NOTE
	OddsList.fill(child(oddsPanel, "List") :: ScrollingFrame, case)
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

-- A refused purchase (owner 2026-11-20: "an error denied sound"): the denied
-- cue, a short shake of the button that was pressed and a red flash of the
-- coin counter, then the toast says why.
local DENY_RED = Color3.fromHex("FF4D5E")
local lastBuyButton: GuiObject? = nil
local countColor: Color3? = nil
local function denied(button: GuiObject?, short: boolean)
	UiSfx.cue("PurchaseDenied")
	if button then
		UiMotion.nudge(button, UiMotion.home(button)) -- the shared shake (skips with reduced motion)
	end
	if short and coinsAmount then
		countColor = countColor or coinsAmount.TextColor3
		local label, back = coinsAmount, countColor
		label.TextColor3 = DENY_RED
		task.delay(0.35, function() -- hold the red a beat, then ease back
			tween(label, 0.4, { TextColor3 = back }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end)
	end
end

-- The server checks everything again (Services/ShopService); these checks only
-- save a round trip and say why. One purchase in flight at a time.
local buying = false
local function buyCase(how: string, button: GuiObject?)
	local case = openCase
	if not case then
		return
	end
	if casesRestricted then
		denied(button, false)
		LobbyHud.toast("Cases aren't available where you are", "error")
		return
	end
	if how ~= "BuyCoins" then
		soon("Buying with Robux")
		return
	end
	if buying then
		return
	end
	if not PlayerData.ready(player) then
		LobbyHud.toast("Your save is still loading", "info")
		return
	end
	if PlayerData.coins(player) < case.coins then
		denied(button, true)
		LobbyHud.toast("Not enough coins", "error")
		return
	end
	lastBuyButton = button
	buying = true
	LobbyNet.event("ShopRequest"):FireServer("buyCase", case.id)
	task.delay(8, function() -- no answer: let them try again
		buying = false
	end)
end

--------------------------------------------------------------------------------
-- The skin-bundle preview

local function plateAmount(button: Instance, amount: string)
	local plate = button:FindFirstChild("Price", true)
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
		local holder = c.Parent
		if holder and StateValues.get(holder, "PivotHolder") == true then
			holder:Destroy()
		else
			c:Destroy()
		end
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
		Thumb.item(c, item);
		(child(c, "Kind") :: TextLabel).Text = kindWord(item);
		(child(c, "Name") :: TextLabel).Text = if item.kind == "Coins"
			then "x" .. commas(item.amount or 0)
			else item.name
		c.Parent = strip
		Pivot.wrap(c)
		table.insert(previewCells, c)
		c.MouseEnter:Connect(function()
			local sc = pop(c)
			if sc and (StateValues.get(sc, "Rest") or 1) < 1.1 then
				tween(sc, 0.15, { Scale = 1.05 })
			end
		end)
		c.MouseLeave:Connect(function()
			local sc = pop(c)
			if sc then
				local r = StateValues.get(sc, "Rest")
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
		local h = StateValues.get(o, "Home")
		local home = if typeof(h) == "UDim2" then h else o.Position
		StateValues.set(o, "Home", home)
		o.Position = home - UDim2.fromOffset(0, 30)
		tween(o, 0.4, { Position = home })
	end
	for _, name in { "Actions", "Strip" } do
		local o = child(preview, name) :: GuiObject
		local h = StateValues.get(o, "Home")
		local home = if typeof(h) == "UDim2" then h else o.Position
		StateValues.set(o, "Home", home)
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

-- Login rewards board (DAILY tab; Services/LoginRewardService decides, this only draws).
-- Studio holds the look: Day1 is drawn claimed, Day4 today and Day5 still to come, so
-- their colours are read once as the three styles. Each cell has a clear "Hit" button.
type CellLook = { bg: Color3, bgT: number, day: Color3, text: Color3 }
local loginCells: { [number]: Frame } = {}
local loginLooks: { claimed: CellLook, today: CellLook, future: CellLook, grand: CellLook }? = nil
local loginNote: TextLabel? = nil

local function lookOf(cell: Frame, textName: string): CellLook
	local day = cell:FindFirstChild("Day")
	local text = cell:FindFirstChild(textName)
	return {
		bg = cell.BackgroundColor3,
		bgT = cell.BackgroundTransparency,
		day = if day and day:IsA("TextLabel") then day.TextColor3 else WHITE,
		text = if text and text:IsA("TextLabel") then text.TextColor3 else WHITE,
	}
end

local function rewardWords(r: Economy.Reward): string
	local parts: { string } = {}
	local item = if r.item then Inventory.ITEMS[r.item] else nil
	if item then
		table.insert(parts, item.name)
	end
	if r.coins then
		table.insert(parts, commas(r.coins) .. " COINS")
	end
	if r.tickets then
		table.insert(parts, `{r.tickets} TICKET{if r.tickets == 1 then "" else "S"}`)
	end
	return table.concat(parts, " + ")
end

local function rewardArt(r: Economy.Reward): string?
	local item = if r.item then Inventory.ITEMS[r.item] else nil
	if item and item.icon then
		return item.icon
	end
	if r.coins then
		return if r.coins >= 1000 then ShopCatalog.ART.coinStack else ShopCatalog.ART.coin
	end
	return nil -- Tickets: no icon until the Ticket art is made (plan step 3); the words say it
end

local function loginState(): (LoginRewards.Login, number)
	local last = StateValues.get(player, "LoginLast")
	local step = StateValues.get(player, "LoginStep")
	local login = LoginRewards.clean({ last = last, step = step })
	return login, Economy.day(math.floor(workspace:GetServerTimeNow()))
end

local function drawLogin()
	local looks = loginLooks
	if not looks then
		return
	end
	local login, today = loginState()
	local current, waiting = LoginRewards.board(login, today)
	for step, cell in loginCells do
		local reward = Economy.LOGIN[step]
		local grand = step == LoginRewards.STEPS
		local state = if step < current or (step == current and not waiting)
			then "claimed"
			elseif step == current then "today"
			else "future"
		local look = if state == "claimed"
			then looks.claimed
			elseif state == "today" then looks.today
			elseif grand then looks.grand
			else looks.future
		cell.BackgroundColor3 = look.bg
		cell.BackgroundTransparency = look.bgT
		local day = cell:FindFirstChild("Day")
		if day and day:IsA("TextLabel") then
			day.TextColor3 = look.day
		end
		local words = cell:FindFirstChild(if grand then "Prize" else "Amount")
		if words and words:IsA("TextLabel") then
			words.Text = if state == "claimed"
				then "CLAIMED"
				elseif state == "today" then "CLAIM"
				else rewardWords(reward)
			words.TextColor3 = if grand and state == "future" then words.TextColor3 else look.text
		end
		local icon = cell:FindFirstChild("Coin")
		local art = icon and icon:FindFirstChild("Art")
		local id = rewardArt(reward)
		if icon and icon:IsA("GuiObject") then
			icon.Visible = id ~= nil
		end
		if art and art:IsA("ImageLabel") and id then
			art.Image = id
		end
	end
	local note = loginNote
	if note then
		if waiting then
			note.Text = `DAY {current} OF {LoginRewards.STEPS}`
		else
			local left = Economy.DAY_SECONDS
				- (math.floor(workspace:GetServerTimeNow()) % Economy.DAY_SECONDS)
			note.Text = string.format("NEXT REWARD IN %dH %02dM", left // 3600, (left % 3600) // 60)
		end
	end
end

local function claimLogin(step: number)
	if not PlayerData.ready(player) then
		LobbyHud.toast("Still loading your data, try again", "info")
		return
	end
	local login, today = loginState()
	local current, waiting = LoginRewards.board(login, today)
	if step == current and waiting then
		UiSfx.cue("Click")
		LobbyNet.event("LoginClaim"):FireServer()
	elseif step > current then
		LobbyHud.toast(
			`Day {step}: {rewardWords(Economy.LOGIN[step])}. Log in each day to reach it`,
			"info"
		)
	elseif step == current then
		LobbyHud.toast("Already claimed today. Come back tomorrow!", "info")
	end
end

local function hookLogin()
	local login = scroll:FindFirstChild("Login", true)
	if not login then
		return
	end
	for step = 1, LoginRewards.STEPS do
		local cell = login:FindFirstChild("Day" .. step, true)
		if cell and cell:IsA("Frame") then
			loginCells[step] = cell
			local hit = cell:FindFirstChild("Hit")
			if hit and hit:IsA("GuiButton") then
				hit.Activated:Connect(function()
					claimLogin(step)
				end)
			end
		end
	end
	local c1, c4, c5, c7 =
		loginCells[1], loginCells[4], loginCells[5], loginCells[LoginRewards.STEPS]
	if c1 and c4 and c5 and c7 then
		loginLooks = {
			claimed = lookOf(c1, "Amount"),
			today = lookOf(c4, "Amount"),
			future = lookOf(c5, "Amount"),
			grand = lookOf(c7, "Prize"),
		}
	end
	local head = login.Parent and login.Parent:FindFirstChild("Head_LOGIN REWARDS")
	local note = head and head:FindFirstChild("Note")
	loginNote = if note and note:IsA("TextLabel") then note else nil
	drawLogin()
end

local function updateDaily()
	local note = dailyNote
	if not note then
		return
	end
	local left = 86400 - (os.time() % 86400)
	note.Text = string.format("NEW ITEMS IN %dH %02dM", left // 3600, (left % 3600) // 60)
	drawLogin()
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
	scroll.Position = UDim2.new(0.5, 0, 0, 36) -- the canvas is a fit canvas: centred
	tween(scroll, 0.4, { Position = UDim2.new(0.5, 0, 0, 0) })
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
	tween(scroll, 0.16, { Position = UDim2.new(0.5, 0, 0, 24) }, QUINT, IN)
	task.delay(0.18, function()
		if openToken == my and not isOpen then
			gui.Enabled = false
			placeCounter()
		end
	end)
end

--------------------------------------------------------------------------------

-- Launch vs full layout (shared/Config/Release.SHOP_FULL_LAYOUT). Studio holds both: parts marked
-- FullOnly / LaunchOnly show in one layout only, LaunchSize / LaunchCellPadding / LaunchMaxCells
-- re-lay them for launch.
-- Nothing is built here; the full layout is the Studio screen as saved.
local function applyLayout()
	local full = Release.SHOP_FULL_LAYOUT
	for _, d in scroll:GetDescendants() do
		if d:IsA("GuiObject") then
			if d:GetAttribute("FullOnly") == true and not full then
				d.Visible = false
			elseif d:GetAttribute("LaunchOnly") == true then
				d.Visible = not full
			end
			local size = d:GetAttribute("LaunchSize")
			if not full and typeof(size) == "UDim2" then
				d.Size = size
			end
		elseif d:IsA("UIGridLayout") and not full then
			local pad = d:GetAttribute("LaunchCellPadding")
			if typeof(pad) == "UDim2" then
				d.CellPadding = pad
			end
			local cells = d:GetAttribute("LaunchMaxCells")
			if typeof(cells) == "number" then
				d.FillDirectionMaxCells = cells
			end
		end
	end
end

function ShopController.init()
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
	templates = UiRoot.templates():WaitForChild("Lobby") :: Folder
	canvas = child(gui, "Canvas")
	fit = child(canvas, "Fit")
	scroll = child(canvas, "Scroll")
	dim = child(gui, "Dim")
	popCanvas = child(gui, "PopupCanvas")
	casePanel = child(popCanvas, "CasePanel")
	oddsPanel = child(popCanvas, "OddsPanel")
	itemCard = child(canvas, "ItemCard")
	coinsTop = child(coinsGui, "Top")
	local bar = child(coinsTop, "Bar") :: Frame
	coinsAmount = child(bar, "Amount")
	for _, name in TABS do
		pages[PAGE_OF[name]] = child(scroll, PAGE_OF[name])
		tabPlates[name] = child(child(child(scroll, "Tabs"), name), "Plate")
		hookTab(name, tabPlates[name])
	end
	applyLayout()

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
			-- the card's words come from the catalog (Studio holds the layout)
			local title = card:FindFirstChild("Title")
			if title and title:IsA("TextLabel") then
				title.Text = b.name
			end
			local sub = card:FindFirstChild("Sub")
			if sub and sub:IsA("TextLabel") then
				sub.Text = b.sub or ""
			end
			local tag = card:FindFirstChild("Tag")
			if tag and tag:IsA("GuiObject") then
				tag.Visible = b.tag ~= nil
				local label = tag:FindFirstChild("Label")
				if label and label:IsA("TextLabel") then
					label.Text = b.tag or ""
				end
			end
			plateAmount(card, commas(b.robux))
			if b.soon or #b.items == 0 then
				card.Activated:Connect(function()
					LobbyHud.toast("Coming soon: what's in it is still being made", "info")
				end)
			else
				buildBundle(card, b)
			end
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
	local passHolder = scroll:FindFirstChild("SeasonPass", true)
	if passHolder and passHolder:IsA("GuiObject") and not Release.BATTLE_PASS_OPEN then
		passHolder.Visible = false -- no Battle Pass card this update (shared/Config/Release)
	end
	local passCardB = passHolder and passHolder:FindFirstChild("Card")
	if passCardB and passCardB:IsA("GuiButton") then
		passCardB.Activated:Connect(function()
			Router.open("BattlePass")
		end)
	end
	soonOn("Offer", "Special offers")
	for i = 1, 6 do
		if RunService:IsStudio() then
			-- Studio test coins until coin packs are sold (Services/ShopService)
			local holder = scroll:FindFirstChild("Pack" .. i, true)
			local card = holder and holder:FindFirstChild("Card")
			if card and card:IsA("GuiButton") then
				card.Activated:Connect(function()
					LobbyNet.event("ShopRequest"):FireServer("devCoins")
				end)
			end
		else
			soonOn("Pack" .. i, "Buying coins")
		end
	end
	for i = 1, 8 do
		soonOn("Item" .. i, "The daily shop")
	end
	for _, n in { "Charm_1", "Charm_2", "Charm_3", "Emote_1", "Emote_2", "Emote_3" } do
		soonOn(n, "Buying cosmetics")
	end
	local passCard = scroll:FindFirstChild("SeasonPass", true)
	if passCard and passCard:IsA("GuiObject") and not Release.BATTLE_PASS_OPEN then
		passCard.Visible = false -- no Battle Pass card this update (shared/Config/Release)
	end
	local view = passCard and passCard:FindFirstChild("View", true)
	if view and view:IsA("GuiButton") then
		view.Activated:Connect(function()
			Router.open("BattlePass")
		end)
	end
	hookLogin()
	-- today's items: real skins (placeholder stock), the picture big and spilling over
	-- the card's top like RIVALS' shop cells, on one flat colour of the skin's tier
	local dailyItems = pages.Daily:FindFirstChild("Items", true)
	for i, d in ShopCatalog.DAILY do
		local holder = dailyItems and dailyItems:FindFirstChild("Item" .. i)
		local card = holder and holder:FindFirstChild("Card")
		if card and card:IsA("GuiButton") then
			local tier = SkinCases.tierOf(d.gun, d.line) or "Common"
			local def = Skins.TIERS[tier]
			local art = card:FindFirstChild("Art")
			if art and art:IsA("GuiObject") then
				art.BackgroundColor3 = def.color:Lerp(Color3.fromHex("0E0F13"), 0.3)
			end
			local name = card:FindFirstChild("Name")
			if name and name:IsA("TextLabel") then
				name.Text = SkinCases.name(d.gun, d.line)
			end
			local tag = card:FindFirstChild("Tag")
			local tagLabel = tag and tag:FindFirstChild("Label")
			if tagLabel and tagLabel:IsA("TextLabel") then
				tagLabel.Text = def.name .. " SKIN"
			end
			plateAmount(card, commas(ShopCatalog.DAILY_COINS[tier] or 900))
			local id = SkinArt.portrait(d.gun, d.line)
			if id then
				local pic = card:FindFirstChild("Pic") or Instance.new("ImageLabel")
				if pic:IsA("ImageLabel") then
					pic.Name = "Pic"
					pic.BackgroundTransparency = 1
					pic.Image = id
					pic.ScaleType = Enum.ScaleType.Fit
					pic.AnchorPoint = Vector2.new(0.5, 0.5)
					-- big, spilling over the top edge, clear of the name and price below
					pic.Position = UDim2.fromScale(0.56, 0.3)
					pic.Size = UDim2.fromScale(0.86, 0.95)
					pic.ZIndex = 4 -- over the colour, under the words and the price
					pic.Parent = card
				end
			end
		end
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
			rest(sc, KM.hover)
		end)
		b.MouseLeave:Connect(function()
			rest(sc, 1)
		end)
		b.Activated:Connect(function()
			press(sc)
			buyCase(n, b)
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

	-- everything that pops grows from its own centre (owner rule)
	Plates.deepen(gui)
	Pivot.fix(gui)
	Pivot.fix(coinsGui)
	Router.register("Shop", { open = open, close = close, screen = "Shop" })
end

function ShopController.start()
	if not gui then
		return
	end
	StateValues.changed(player, "Coins"):Connect(placeCounter)
	-- login rewards: redraw on every change, answer the claim, nudge once per join
	StateValues.changed(player, "LoginLast"):Connect(drawLogin)
	StateValues.changed(player, "LoginStep"):Connect(drawLogin)
	LobbyNet.event("LoginEvent").OnClientEvent:Connect(function(p: LobbyNet.LoginEventPayload)
		if typeof(p) ~= "table" then
			return
		end
		if p.kind == "claimed" then
			UiSfx.cue("Confirm")
			local step = if typeof(p.step) == "number" then Economy.LOGIN[p.step] else nil
			LobbyHud.toast(
				if step then `Claimed: {rewardWords(step)}` else "Reward claimed",
				"success"
			)
		elseif p.kind == "failed" then
			LobbyHud.toast(
				if typeof(p.text) == "string" then p.text else "Couldn't claim, try again",
				"error"
			)
		end
		drawLogin()
	end)
	task.spawn(function()
		while not PlayerData.ready(player) do
			StateValues.changed(player, "DataReady"):Wait()
		end
		drawLogin()
		local login, today = loginState()
		if LoginRewards.nextStep(login, today) then
			LobbyHud.toast("Your daily reward is ready: Shop → DAILY", "info")
		end
	end)
	LobbyNet.event("ShopEvent").OnClientEvent:Connect(function(p: LobbyNet.ShopEventPayload)
		if typeof(p) ~= "table" then
			return
		end
		local wasBuying = buying -- a failure here may be the Backpack's opening, not ours
		buying = false
		if p.kind == "bought" then
			UiSfx.cue("Confirm")
			LobbyHud.toast(`{p.text or "Item"} added to your Backpack`, "success")
		elseif p.kind == "opened" then
			return -- a case opening: the Backpack shows it (Controllers/BackpackController)
		elseif p.kind == "coins" then
			LobbyHud.toast(p.text or "Coins added", "success")
		elseif wasBuying then
			denied(lastBuyButton, p.text == "Not enough coins")
			LobbyHud.toast(p.text or "Purchase failed", "error")
		end
	end)
	Router.onChanged(function()
		placeCounter()
	end)
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
