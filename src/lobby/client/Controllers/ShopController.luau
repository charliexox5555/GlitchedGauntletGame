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
local DailyShop = require(ReplicatedStorage.Shared.DailyShop)
local DailyRoll = require(ReplicatedStorage.Shared.DailyRoll)
local Products = require(ReplicatedStorage.Shared.Config.Products)
local ShopRewardFx = require(script.Parent.Parent.Util.ShopRewardFx)
local rewardConfig = require(ReplicatedStorage.Shared.Config.ShopFx).reward
local OfferCarousel = require(script.Parent.Parent.Util.OfferCarousel)
local LobbyHud = require(script.Parent.LobbyHud)
local UiMotion = require(game:GetService("ReplicatedStorage").Shared.UiMotion) -- the one motion module
local KM = UiMotion.M

local ShopController = {}

local player = Players.LocalPlayer
local QUINT = Enum.EasingStyle.Quint
local IN, OUT = Enum.EasingDirection.In, Enum.EasingDirection.Out
local WHITE = Color3.new(1, 1, 1)
local ShopTheme = require(ReplicatedStorage.Shared.Config.ShopTheme) -- scheme A (owner 2026-11-22)
local CARD = ShopTheme.PANEL
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
-- Robux cases are paid random items: shown only once Roblox says they're allowed here
-- (display only, fail closed; Services/RobuxService checks again)
local casesRestricted = true
local confirmPanel: Frame
local rewardPanel: Frame
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
local resetClose: () -> () = function() end
local openToken = 0
local offerCarousel: { start: () -> (), stop: () -> (), refresh: () -> () }?
local function updateOffers()
	local carousel = offerCarousel
	if carousel then
		if isOpen and tab == "HOME" and not previewBundle then
			carousel.start()
		else
			carousel.stop()
		end
	end
end

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
	cell.BackgroundColor3 = ShopTheme.INNER;
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

local function openBundle(bundle: ShopCatalog.Bundle)
	local first = 1
	for i, item in bundle.items do
		if item.kind == "Skin" then
			first = i
			break
		end
	end
	openPreview(bundle, first)
end

local function buildBundle(card: GuiButton, bundle: ShopCatalog.Bundle)
	if card:FindFirstChild("Tiles") then
		-- the card shows its items as Studio tiles (fillBundleCard): no hover row
		card.Activated:Connect(function()
			openBundle(bundle)
		end)
		return
	end
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
		c.BackgroundColor3 = ShopTheme.INNER
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
		openBundle(bundle)
	end)
end

--------------------------------------------------------------------------------
-- Popups: the case, its contents

local popupOpen: Frame? = nil
local rewardSession: ShopRewardFx.Session? = nil

local function showPanel(panel: Frame?)
	local was = popupOpen
	if rewardSession then
		rewardSession.destroy()
		rewardSession = nil
	end
	popupOpen = panel
	for _, p in { casePanel, oddsPanel, confirmPanel, rewardPanel } do
		if p ~= panel then
			p.Visible = false
		end
	end
	if panel then
		dim.Visible = true
		popCanvas.Visible = true
		if not was then
			dim.BackgroundTransparency = 1
		end
		tween(dim, if panel == rewardPanel then rewardConfig.build else 0.2, {
			BackgroundTransparency = rewardConfig.dimTransparency,
		})
		panel.Visible = true
		local sc = pop(panel)
		if sc then
			sc.Scale = if panel == rewardPanel then rewardConfig.panelStartScale else 0.92
			tween(sc, if panel == rewardPanel then rewardConfig.build else 0.24, { Scale = 1 })
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

local function ticketWords(n: number): string
	return `{n} TICKET{if n == 1 then "" else "S"}`
end

-- The icon in a price plate's row (a "Coin" frame with an "Art" image): the coin, the
-- Robux mark (read from a Studio Robux plate), the Ticket, or none.
local robuxIcon: string? = nil
local ROBUX_PLATE = ShopTheme.ROBUX -- RIVALS-like green for anything Robux
local coinPlate: Color3? = nil -- the Studio coin plate colour (read once)
local function priceIcon(button: Instance, kind: "coins" | "robux" | "tickets" | "none")
	local plate = button:FindFirstChild("Price", true)
	if plate and plate:IsA("GuiObject") then
		coinPlate = coinPlate or plate.BackgroundColor3
		plate.BackgroundColor3 = if kind == "robux" then ROBUX_PLATE else coinPlate :: Color3
	end
	local row = plate and plate:FindFirstChild("Row")
	local icon = row and row:FindFirstChild("Coin")
	if not (icon and icon:IsA("GuiObject")) then
		return
	end
	local art = icon:FindFirstChild("Art")
	icon.Visible = kind == "coins" or kind == "tickets" or (kind == "robux" and robuxIcon ~= nil)
	if art and art:IsA("ImageLabel") then
		if kind == "coins" then
			art.Image = ShopCatalog.ART.coin
		elseif kind == "tickets" then
			art.Image = ShopCatalog.ART.ticket
		elseif kind == "robux" and robuxIcon then
			art.Image = robuxIcon
		end
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
	-- Robux first (one / three), Tickets second (owner 2026-11-22); where paid random items
	-- aren't allowed only Tickets (Config/Products.CASES, Config/Economy.CASE_TICKETS)
	local byCount = Products.CASES[case.id] or {}
	local one, three = byCount[1], byCount[3]
	local robuxOk = not casesRestricted and one ~= nil
	local r1, r3 =
		child(casePanel, "BuyRobux") :: GuiObject, child(casePanel, "BuyRobux3") :: GuiObject
	r1.Visible = robuxOk
	r3.Visible = robuxOk and three ~= nil
	if one then
		setPlate(r1, commas(one.robux))
	end
	if three then
		setPlate(r3, commas(three.robux))
	end
	local buy = child(casePanel, "BuyCoins") :: GuiObject
	-- only X moves: the pop setup has re-anchored the button to its centre
	buy.Position =
		UDim2.new(0, if robuxOk then 660 else 410, buy.Position.Y.Scale, buy.Position.Y.Offset)
	setPlate(buy, ticketWords(Economy.CASE_TICKETS[case.id] or 0))
	priceIcon(buy, "tickets")
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
local askRobux: (what: string, a: any?, b: any?) -> () -- defined with the confirm popup
local function buyCase(how: string, button: GuiObject?)
	local case = openCase
	if not case then
		return
	end
	if how == "BuyRobux" or how == "BuyRobux3" then
		askRobux("case", case.id, if how == "BuyRobux3" then 3 else 1)
		return
	end
	if buying then
		return
	end
	if not PlayerData.ready(player) then
		LobbyHud.toast("Your save is still loading", "info")
		return
	end
	if PlayerData.tickets(player) < (Economy.CASE_TICKETS[case.id] or math.huge) then
		denied(button, false)
		LobbyHud.toast("Not enough Tickets: claim daily rewards to earn more", "error")
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

-- OWNED (owner 2026-11-22: "it should say owned if it is owned and look good"): every
-- card that can be owned registers a check; they rerun when skins or the Starter change.
local ownedChecks: { () -> () } = {}
local function refreshOwned()
	for _, check in ownedChecks do
		check()
	end
end
-- a price plate as OWNED: the word, no icon, the quiet panel colour
local function plateOwned(button: Instance, owned: boolean, price: string, kind: "coins" | "robux")
	-- a Robux plate's own icon (Price.Row.Robux) hides with the price
	local robuxMark = button:FindFirstChild("Robux", true)
	if robuxMark and robuxMark:IsA("GuiObject") then
		robuxMark.Visible = not owned
	end
	if owned then
		plateAmount(button, "OWNED")
		priceIcon(button, "none")
		local plate = button:FindFirstChild("Price", true)
		if plate and plate:IsA("GuiObject") then
			plate.BackgroundColor3 = ShopTheme.INNER
		end
	else
		plateAmount(button, price)
		priceIcon(button, kind)
	end
end
local function ownsAll(bundle: ShopCatalog.Bundle): boolean
	local skins = PlayerData.skins(player)
	local any = false
	for _, item in bundle.items do
		if item.kind == "Skin" and item.gun and item.line then
			any = true
			if not PlayerData.owns(skins, item.gun, item.line) then
				return false
			end
		end
	end
	return any
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

local previewIndex = 1
local function selectPreview(index: number)
	previewIndex = index
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
		local owned = item.gun ~= nil
			and item.line ~= nil
			and PlayerData.owns(PlayerData.skins(player), item.gun, item.line)
		plateOwned(buyItem, owned, commas(itemPrice), "robux")
	end
	plateOwned(child(actions, "BuyBundle"), ownsAll(bundle), commas(bundle.robux), "robux")
	-- the strip: the open item is up and bright, the rest a touch back
	for i, c in previewCells do
		local on = i == index
		rest(pop(c), if on then 1.1 else 1)
		tween(c, 0.15, { BackgroundTransparency = if on then 0 else 0.35 })
	end
end

-- The shop is bigger on screen through the canvas's DesktopBoost / PhoneBoost / TabletBoost
-- (Shared/UiLayout; owner 2026-11-22: "the shop needs to fill more of the screen"). The
-- bundle preview sits under the tab bar, which stays on screen, scaled (Studio's
-- PreviewScale) to fit the height that's left.
-- On a bundle's page the tab bar shrinks, centres and moves up (owner 2026-11-22: "make the
-- top bar buttons more centered and smaller so the gun viewport can be larger"): Studio's
-- Tabs.TabsScale UIScale, the Tabs list centred, the scroll's top padding smaller.
local PAGE_TABS_SCALE = 0.68
local PAGE_TOP_PAD = 64 -- the scroll's top padding on a bundle page (150 on the shop)
local SHOP_TOP_PAD = 150
local PREVIEW_H = 790 -- the preview's laid-out height (tools/studio/ShopUiPass.luau)
local function relayout()
	if not (fit and canvas and scroll and (preview :: Frame?)) then
		return -- still starting up
	end
	local f = math.max(fit.Scale, 0.01)
	local h = canvas.AbsoluteSize.Y / f
	-- the page starts just under wherever the tab bar ends now
	local tabs = scroll:FindFirstChild("Tabs")
	local top = if tabs and tabs:IsA("GuiObject")
		then (tabs.AbsolutePosition.Y + tabs.AbsoluteSize.Y - canvas.AbsolutePosition.Y) / f + 10
		else 258
	local kp = math.clamp((h - top - 8) / PREVIEW_H, 0.5, 1.45)
	local previewScale = preview:FindFirstChild("PreviewScale")
	if previewScale and previewScale:IsA("UIScale") then
		previewScale.Scale = kp
		preview.Size = UDim2.new(1 / kp, 0, 0, PREVIEW_H)
		-- the pop setup may centre its anchor: place its top edge under the tabs either way
		preview.Position = UDim2.new(0.5, 0, 0, top + PREVIEW_H * kp * preview.AnchorPoint.Y)
	end
end

-- The tab bar's two looks: the shop's (full size, left) and a bundle page's (small, centred).
local function pageTabs(onPage: boolean)
	local tabs = scroll:FindFirstChild("Tabs")
	if not tabs then
		return
	end
	local scale = tabs:FindFirstChild("TabsScale")
	if scale and scale:IsA("UIScale") then
		scale.Scale = if onPage then PAGE_TABS_SCALE else 1
	end
	local list = tabs:FindFirstChildOfClass("UIListLayout")
	if list then
		list.HorizontalAlignment = if onPage
			then Enum.HorizontalAlignment.Center
			else Enum.HorizontalAlignment.Left
	end
	local pad = scroll:FindFirstChildOfClass("UIPadding")
	if pad then
		pad.PaddingTop = UDim.new(0, if onPage then PAGE_TOP_PAD else SHOP_TOP_PAD)
	end
end

openPreview = function(bundle: ShopCatalog.Bundle, index: number)
	previewBundle = bundle
	updateOffers()
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
		c.BackgroundColor3 = ShopTheme.INNER
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
	local wasLabel = was:FindFirstChild("Amount", true) :: TextLabel -- Plate.Row.Amount
	wasLabel.Text = commas(separately)

	-- the page steps aside (the tab bar stays, like RIVALS); the preview comes in
	for _, page in pages do
		page.Visible = false
	end
	scroll.CanvasPosition = Vector2.zero
	scroll.ScrollingEnabled = false
	showCounter(false)
	pageTabs(true)
	task.defer(relayout) -- after the tab bar has moved
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
	pageTabs(false)
	pages[PAGE_OF[tab]].Visible = true
	scroll.ScrollingEnabled = true
	updateOffers()
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
		BackgroundColor3 = if on then ShopTheme.GOLD else CARD,
		BackgroundTransparency = if on then 0 else TAB_OFF_T,
	})
	local label = plate:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		tween(label, 0.15, { TextColor3 = if on then ShopTheme.ON_GOLD else ShopTheme.MUTED })
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
	updateOffers()
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
		closePreview() -- a tab press from a bundle's page goes back to the shop
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
	if r.tickets then
		return ShopCatalog.ART.ticket
	end
	return nil
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

-- The confirm popup (Studio ConfirmPanel, tools/studio/ShopConfirmPanel.luau; owner
-- 2026-11-22: every buy opens it first, like RIVALS' emote popup). Coins short → the COINS
-- tab with the pack that covers it pointed at. Robux → the server prompts (RobuxService).
type Confirm = {
	title: string,
	name: string,
	art: string?,
	price: number,
	currency: "coins" | "robux" | "free",
	go: () -> (),
}
local confirmOpen: Confirm? = nil
local goToPack: (short: number) -> () -- set in init (needs the tabs)

local function openConfirm(c: Confirm)
	confirmOpen = c;
	(child(confirmPanel, "Title") :: TextLabel).Text = c.title;
	(child(confirmPanel, "ItemName") :: TextLabel).Text = c.name
	local art = child(confirmPanel, "Art") :: ImageLabel
	art.Image = c.art or ""
	local buy = child(confirmPanel, "Buy")
	if c.currency == "free" then
		setPlate(buy, "FREE")
		priceIcon(buy, "none")
	else
		setPlate(buy, commas(c.price))
		priceIcon(buy, c.currency)
	end
	showPanel(confirmPanel)
end

local function confirmBuy(button: GuiObject)
	local c = confirmOpen
	if not c then
		return
	end
	if c.currency == "coins" and PlayerData.coins(player) < c.price then
		denied(button, true)
		local short = c.price - PlayerData.coins(player)
		showPanel(nil)
		confirmOpen = nil
		goToPack(short)
		return
	end
	confirmOpen = nil
	showPanel(nil)
	c.go()
end

-- A Robux buy: the server checks it and opens Roblox's purchase prompt.
local lastAsk = -math.huge
askRobux = function(what: string, a: any?, b: any?)
	if not PlayerData.ready(player) then
		LobbyHud.toast("Your save is still loading", "info")
		return
	end
	lastAsk = os.clock()
	LobbyNet.event("RobuxRequest"):FireServer(what, a, b)
end

-- Case tiles on HOME: the Robux price first where cases can be sold for Robux, else Tickets.
local caseCards: { { card: GuiButton, case: ShopCatalog.Case } } = {}
local function drawCasePrices()
	for _, cc in caseCards do
		local one = (Products.CASES[cc.case.id] or {})[1]
		if one and not casesRestricted then
			plateAmount(cc.card, commas(one.robux))
			priceIcon(cc.card, "robux")
		else
			plateAmount(cc.card, ticketWords(Economy.CASE_TICKETS[cc.case.id] or 0))
			priceIcon(cc.card, "tickets")
		end
	end
end

-- The YOU GOT popup after a purchase (owner 2026-11-22: "much better feedback and fun for
-- somebody who buys a bundle so it feels satisfying"): the picture pops in with a light
-- sweep, the case reveal's stinger for its tier plays (Config/UiSounds Reward*), COLLECT.
local function celebrate(reward: ShopRewardFx.Reveal)
	if not isOpen then
		Router.open("Shop", tab)
	end
	if not isOpen then
		LobbyHud.toast(
			if reward.coins then string.format(reward.name, commas(reward.coins)) else reward.name,
			"success"
		)
		return
	end
	if reward.coins then
		showCounter(true)
	end
	showPanel(rewardPanel)
	rewardSession = ShopRewardFx.play(rewardPanel, reward, commas)
end

local function celebrateSkin(gun: string, line: string)
	local tier = SkinCases.tierOf(gun, line)
	celebrate({
		name = SkinCases.name(gun, line),
		image = SkinArt.portrait(gun, line),
		tier = tier,
		color = ShopCatalog.RARITY_COLOR[tier or "Common"] or WHITE,
	})
end

local function addRewardItem(items: { ShopRewardFx.Item }, image: string?, isCoin: boolean?)
	if image and image ~= "" then
		table.insert(items, { image = image, coins = isCoin })
	end
end

local function celebrateCoins(
	amount: number,
	art: string?,
	tier: string,
	items: { ShopRewardFx.Item }?,
	suffix: string?
)
	celebrate({
		name = "+%s COINS" .. (suffix or ""),
		image = art or ShopCatalog.ART.coinStack,
		coins = amount,
		tier = tier,
		color = ShopTheme.GOLD,
		items = items,
	})
end

local function celebrateLogin(p: LobbyNet.LoginEventPayload)
	local reward: Economy.Reward = { coins = p.coins, tickets = p.tickets, item = p.item }
	local art = rewardArt(reward)
	local amount = reward.coins
	if amount then
		local remainder: Economy.Reward = { tickets = p.tickets, item = p.item }
		local suffix = rewardWords(remainder)
		local items: { ShopRewardFx.Item }? = nil
		if suffix ~= "" then
			local row: { ShopRewardFx.Item } = {}
			addRewardItem(row, art, true)
			addRewardItem(row, if p.tickets then ShopCatalog.ART.ticket else nil)
			local def = if p.item then Inventory.ITEMS[p.item] else nil
			addRewardItem(row, def and def.icon)
			items = row
		end
		celebrateCoins(amount, art, "Rare", items, if suffix ~= "" then " + " .. suffix else nil)
	else
		local words = rewardWords(reward)
		celebrate({
			name = if words ~= "" then words else "REWARD CLAIMED",
			image = art,
			tier = "Rare",
			color = ShopTheme.GOLD,
		})
	end
end

local function celebrateProduct(p: LobbyNet.ShopEventPayload)
	local product = if typeof(p.product) == "number" then Products.BY_ID[p.product] else nil
	local message = p.text or "Purchase complete"
	-- The receipt's existing text identifies substitutions (including duplicate purchases).
	local compensation = if product and product.kind ~= "coins"
		then tonumber(string.match(message, "%+(%d+) coins"))
		else nil
	if compensation then
		celebrateCoins(compensation, nil, "Rare")
	elseif product and product.kind == "skin" and p.gun and p.line then
		celebrateSkin(p.gun, p.line)
	elseif product and product.kind == "bundle" then
		local bundle = if product.bundle then ShopCatalog.bundle(product.bundle) else nil
		local items: { ShopRewardFx.Item } = {}
		if bundle then
			for _, item in bundle.items do
				if item.gun and item.line then
					addRewardItem(items, SkinArt.portrait(item.gun, item.line))
				end
			end
		end
		celebrate({
			name = if bundle then `{bundle.name} BUNDLE · {#bundle.items} SKINS` else product.name,
			image = bundle and bundle.hero,
			tier = "Legendary",
			color = ShopTheme.GOLD,
			items = items,
		})
	elseif product and product.kind == "case" then
		local case = if product.caseId then ShopCatalog.case(product.caseId) else nil
		celebrate({
			name = message,
			image = case and case.art,
			tier = "Rare",
			color = case and case.color or ShopTheme.GOLD,
		})
	elseif product and product.kind == "starter" then
		local caseCount, base, ticketCount =
			string.match(message, "^Starter Bundle: (%d+) cases, (%d+) coins and (%d+) Tickets$")
		local fallback = tonumber(string.match(message, "^Starter Bundle: (%d+) coins$"))
		if fallback then
			celebrateCoins(fallback, nil, "Epic")
		elseif caseCount and base and ticketCount then
			local items: { ShopRewardFx.Item } = {}
			local def = if product.case then Inventory.ITEMS[product.case] else nil
			if tonumber(caseCount) ~= 0 then
				addRewardItem(items, def and def.icon)
			end
			addRewardItem(items, ShopCatalog.PACK_ART[3], true)
			addRewardItem(items, ShopCatalog.ART.ticket)
			celebrate({
				name = `+%s COINS · {caseCount} CASES · {ticketCount} TICKETS`,
				image = ShopCatalog.ART.coinStack,
				tier = "Epic",
				color = ShopTheme.GOLD,
				coins = tonumber(base),
				items = items,
			})
		else
			celebrate({
				name = message,
				image = ShopCatalog.ART.coinStack,
				tier = "Epic",
				color = ShopTheme.GOLD,
			})
		end
	elseif product and product.kind == "coins" and product.coins then
		local art: string? = nil
		for i, pack in Products.PACKS do
			if pack.id == product.id then
				art = ShopCatalog.PACK_ART[i]
				break
			end
		end
		local hasCase = string.find(message, " and a case", 1, true) ~= nil
		local def = if hasCase and product.case then Inventory.ITEMS[product.case] else nil
		local items: { ShopRewardFx.Item }? = nil
		if def then
			local row: { ShopRewardFx.Item } = {}
			addRewardItem(row, art or ShopCatalog.ART.coinStack, true)
			addRewardItem(row, def.icon)
			items = row
		end
		local amount = product.coins + (if hasCase then 0 else product.caseCoins or 0)
		celebrateCoins(
			amount,
			art,
			if product.case then "Epic" else "Rare",
			items,
			if def then " + " .. string.upper(def.name) else nil
		)
	else
		celebrate({ name = message, tier = "Rare", color = ShopTheme.GOLD })
	end
end

-- The daily shop cards (DAILY tab, Item1..Item8): the player's own saved list, priced by
-- tier (coins for Common / Rare, Robux above), OWNED once theirs. The picture big and
-- spilling over the card's top like RIVALS' cells, on one flat colour of the tier.
local dailyItems: Instance? = nil

-- The one free daily skin (once per player, ever; Services/ShopService.claimFree).
local function freeSlot(daily: DailyShop.Daily, owned: PlayerData.Skins): number?
	if StateValues.get(player, "FreeDailyUsed") ~= false then
		return nil
	end
	return DailyShop.freeSlot(daily, function(gun, line)
		return PlayerData.owns(owned, gun, line)
	end, function(p)
		return (DailyRoll.price(p)) ~= nil
	end)
end

local function drawDaily()
	local items = dailyItems
	if not items then
		return
	end
	local daily = PlayerData.daily(player)
	local owned = PlayerData.skins(player)
	local free = freeSlot(daily, owned)
	for i = 1, DailyShop.SIZE do
		local holder = items:FindFirstChild("Item" .. i)
		local card = holder and holder:FindFirstChild("Card")
		local pick = daily.picks[i]
		if holder and holder:IsA("GuiObject") then
			holder.Visible = pick ~= nil
		end
		if not (card and card:IsA("GuiButton") and pick) then
			continue
		end
		local tier = DailyRoll.tier(pick)
		local def = (Skins.TIERS :: any)[tier] or Skins.TIERS.Common
		local art = card:FindFirstChild("Art")
		if art and art:IsA("GuiObject") then
			art.BackgroundColor3 = ShopTheme.INNER -- the tier shows on the tag only (scheme A)
		end
		local name = card:FindFirstChild("Name")
		if name and name:IsA("TextLabel") then
			name.Text = SkinCases.name(pick.gun, pick.line)
		end
		local tag = card:FindFirstChild("Tag")
		local tagLabel = tag and tag:FindFirstChild("Label")
		if tagLabel and tagLabel:IsA("TextLabel") then
			tagLabel.Text = def.name .. " SKIN"
			tagLabel.TextColor3 = def.color -- the tier shows here only (scheme A)
		end
		local coinPrice, robux = DailyRoll.price(pick)
		if table.find(daily.bought, i) or PlayerData.owns(owned, pick.gun, pick.line) then
			plateAmount(card, "OWNED")
			priceIcon(card, "none")
		elseif i == free then
			plateAmount(card, "FREE")
			priceIcon(card, "none")
		elseif coinPrice then
			plateAmount(card, commas(coinPrice))
			priceIcon(card, "coins")
		else
			plateAmount(card, commas(robux or 0))
			priceIcon(card, "robux")
		end
		local id = SkinArt.portrait(pick.gun, pick.line)
		local pic = card:FindFirstChild("Pic") or Instance.new("ImageLabel")
		if pic:IsA("ImageLabel") then
			pic.Name = "Pic"
			pic.BackgroundTransparency = 1
			pic.Image = id or ""
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

local function buyDaily(slot: number, button: GuiObject)
	local daily = PlayerData.daily(player)
	local pick = daily.picks[slot]
	if not PlayerData.ready(player) or not pick then
		LobbyHud.toast("Today's shop is still loading", "info")
		return
	end
	if
		table.find(daily.bought, slot)
		or PlayerData.owns(PlayerData.skins(player), pick.gun, pick.line)
	then
		LobbyHud.toast("You already own that skin", "info")
		return
	end
	local coinPrice, robux = DailyRoll.price(pick)
	local name = SkinCases.name(pick.gun, pick.line)
	local art = SkinArt.portrait(pick.gun, pick.line)
	if slot == freeSlot(daily, PlayerData.skins(player)) then
		openConfirm({
			title = "FREE SKIN",
			name = name,
			art = art,
			price = 0,
			currency = "free",
			go = function()
				LobbyNet.event("ShopRequest"):FireServer("claimFree", slot)
			end,
		})
		return
	end
	if not coinPrice then
		openConfirm({
			title = "SKIN",
			name = name,
			art = art,
			price = robux or 0,
			currency = "robux",
			go = function()
				askRobux("daily", slot)
			end,
		})
		return
	end
	openConfirm({
		title = "SKIN",
		name = name,
		art = art,
		price = coinPrice,
		currency = "coins",
		go = function()
			if buying then
				return
			end
			lastBuyButton = button
			buying = true
			LobbyNet.event("ShopRequest"):FireServer("buyDaily", slot)
			task.delay(8, function()
				buying = false
			end)
		end,
	})
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
	relayout()
	placeCounter()
	counterShown = false
	coinsTop.Position = UDim2.new(0.5, 0, 0, -80)
	showCounter(true)
	local wash = gui:FindFirstChild("Wash")
	if wash and wash:IsA("Frame") then
		wash.BackgroundTransparency = 1
		tween(wash, 0.25, { BackgroundTransparency = ShopTheme.WASH_T })
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
	updateOffers()
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

-- A skin bundle card (owner 2026-11-22, RIVALS' Skins tab): the hero picture (the line's
-- Vandal, side-on) big on the left, one tile per item on the right; hovering a tile shows
-- the item, clicking it opens the bundle's page on that item.
local function fillBundleCard(card: GuiButton, bundle: ShopCatalog.Bundle)
	-- the banner art behind everything, when it exists (else the flat theme colour)
	local back = card:FindFirstChild("Art")
	if bundle.banner and back and back:IsA("ImageLabel") then
		back.Image = bundle.banner
		back.ScaleType = Enum.ScaleType.Crop
		back.ImageColor3 = WHITE -- the Studio tint was for the old grey placeholder
	end
	local heroPic = card:FindFirstChild("Hero")
	local first = bundle.items[1]
	if heroPic and heroPic:IsA("ImageLabel") and first and first.line then
		local guns: { string } = {}
		for _, item in bundle.items do
			if item.gun then
				table.insert(guns, item.gun)
			end
		end
		local id = bundle.hero
			or SkinArt.side("Vandal", first.line)
			or SkinArt.line(first.line, guns)
		heroPic.Image = id or ""
		if not id then
			-- no picture yet (plan: Blender hero renders): the 3D view of its Vandal
			Thumb.item(heroPic, { kind = "Skin", gun = guns[1] or "Vandal", line = first.line })
		end
	end
	local tiles = card:FindFirstChild("Tiles")
	if not tiles then
		return
	end
	for i = 1, 6 do
		local t = tiles:FindFirstChild("Tile" .. i)
		if not (t and t:IsA("GuiButton")) then
			continue
		end
		local item = bundle.items[i]
		t.Visible = item ~= nil
		if not item then
			continue
		end
		t.BackgroundColor3 = ShopTheme.DEEP
		local pic = t:FindFirstChild("Pic")
		local id = if item.gun and item.line then SkinArt.portrait(item.gun, item.line) else nil
		if pic and pic:IsA("ImageLabel") then
			pic.Image = id or ""
		end
		if not id then
			Thumb.item(t, item) -- no portrait yet: its picture or a 3D view
		end
		local sc = pop(t)
		t.MouseEnter:Connect(function()
			rest(sc, 1.06)
			showItemCard(item, t)
		end)
		t.MouseLeave:Connect(function()
			rest(sc, 1)
			hideItemCard()
		end)
		t.Activated:Connect(function()
			press(sc)
			hideItemCard()
			openPreview(bundle, i)
		end)
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
	canvas:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		relayout()
	end)
	fit:GetPropertyChangedSignal("Scale"):Connect(function()
		relayout()
	end)
	scroll = child(canvas, "Scroll")
	dim = child(gui, "Dim")
	popCanvas = child(gui, "PopupCanvas")
	casePanel = child(popCanvas, "CasePanel")
	confirmPanel = child(popCanvas, "ConfirmPanel")
	rewardPanel = child(popCanvas, "RewardPanel")
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

	-- cases (prices drawn by drawCasePrices, again once the paid-random-items check is back)
	local home = pages.Home
	for _, c in ShopCatalog.CASES do
		local holder = home:FindFirstChild("Case_" .. c.id, true)
		local card = holder and holder:FindFirstChild("Card")
		if card and card:IsA("GuiButton") then
			table.insert(caseCards, { card = card, case = c })
			card.Activated:Connect(function()
				openCasePopup(c)
			end)
		end
	end
	drawCasePrices()
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
			priceIcon(card, "robux")
			fillBundleCard(card, b)
			if b.slot ~= "Starter" then
				local c = card
				table.insert(ownedChecks, function()
					plateOwned(c, ownsAll(b), commas(b.robux), "robux")
				end)
			end
			if b.slot == "Starter" then
				local heroPic = card:FindFirstChild("Hero")
				if heroPic and heroPic:IsA("ImageLabel") then
					heroPic.Image = ShopCatalog.ART.coinStack
				end
			end
			-- the Starter is bought through Products.STARTER below (buyStarter)
			if b.slot ~= "Starter" and (b.soon or #b.items == 0) then
				card.Activated:Connect(function()
					LobbyHud.toast("Coming soon: what's in it is still being made", "info")
				end)
			elseif b.slot ~= "Starter" then
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
	-- the Starter Bundle: Home's special offer card and the BUNDLES row (once per player)
	local starter = Products.STARTER
	local function buyStarter()
		if not starter then
			return
		end
		if StateValues.get(player, "StarterBought") ~= false then
			LobbyHud.toast("You already have the Starter Bundle", "info")
			return
		end
		openConfirm({
			title = "STARTER BUNDLE",
			name = `{starter.caseCount or 0} CASES + {commas(starter.coins or 0)} COINS + {starter.tickets or 0} TICKETS`,
			art = ShopCatalog.ART.coinStack,
			price = starter.robux,
			currency = "robux",
			go = function()
				askRobux("starter")
			end,
		})
	end
	local offer = pages.Home:FindFirstChild("Offer", true)
	local offerCard = offer and offer:FindFirstChild("Card")
	if offerCard and offerCard:IsA("GuiButton") then
		local featured: { ShopCatalog.Bundle } = {}
		local starterBundle = ShopCatalog.bundle("Starter")
		if starter and starterBundle and not starterBundle.soon then
			table.insert(featured, starterBundle)
		end
		for _, bundle in ShopCatalog.BUNDLES do
			if
				not bundle.soon
				and #bundle.items > 0
				and (
					bundle.slot == "Featured"
					or (Release.SHOP_FULL_LAYOUT and bundle.slot == "Limited")
				)
			then
				table.insert(featured, bundle)
			end
		end
		offerCard.Visible = #featured > 0
		local title = child(offerCard, "Title") :: TextLabel
		local sub = child(offerCard, "Sub") :: TextLabel
		local back = child(offerCard, "Art") :: ImageLabel
		local hero = child(offerCard, "Hero") :: ImageLabel
		back.ScaleType = Enum.ScaleType.Crop
		back.ImageColor3 = WHITE
		local function renderSlide(index: number)
			local bundle = featured[index]
			if not bundle then
				return
			end
			local isStarter = bundle.slot == "Starter"
			title.Text = bundle.name
			sub.Text = bundle.sub or ""
			back.Image = bundle.banner or ""
			hero.Image = if isStarter then ShopCatalog.ART.coinStack else bundle.hero or ""
			local owned = if isStarter
				then StateValues.get(player, "StarterBought") == true
				else ownsAll(bundle)
			plateOwned(offerCard, owned, commas(bundle.robux), "robux")
		end
		local carousel = OfferCarousel.new(offerCard, #featured, renderSlide, function(index)
			local bundle = featured[index]
			if bundle.slot == "Starter" then
				buyStarter()
			else
				openBundle(bundle)
			end
		end, function()
			return popupOpen ~= nil or not offerCard.Visible
		end)
		offerCarousel = carousel
		table.insert(ownedChecks, carousel.refresh)
	end
	local starterRow = pages.Bundles:FindFirstChild("Bundle_Starter", true)
	local starterCard = starterRow and starterRow:FindFirstChild("Card")
	if starter and starterCard and starterCard:IsA("GuiButton") then
		starterCard.Activated:Connect(buyStarter)
		table.insert(ownedChecks, function()
			plateOwned(
				starterCard,
				StateValues.get(player, "StarterBought") == true,
				commas(starter.robux),
				"robux"
			)
		end)
	end
	-- coin packs (Config/Products.PACKS, in Pack1..Pack6 order)
	for i, pack in Products.PACKS do
		local holder = scroll:FindFirstChild("Pack" .. i, true)
		local card = holder and holder:FindFirstChild("Card")
		if card and card:IsA("GuiButton") then
			local packArt = card:FindFirstChild("PackArt")
			if packArt and packArt:IsA("ImageLabel") and ShopCatalog.PACK_ART[i] then
				packArt.Image = ShopCatalog.PACK_ART[i]
			end
			local back = card:FindFirstChild("Art")
			if back and back:IsA("ImageLabel") and ShopCatalog.PACK_BACKDROP ~= "" then
				back.Image = ShopCatalog.PACK_BACKDROP
				back.ScaleType = Enum.ScaleType.Crop
				back.ImageColor3 = WHITE
			end
			local amount = card:FindFirstChild("Amount")
			if amount and amount:IsA("TextLabel") then
				amount.Text = "+" .. commas(pack.coins or 0)
			end
			local kind = card:FindFirstChild("Kind")
			if kind and kind:IsA("TextLabel") then
				kind.Text = if pack.case then "COINS + CASE" else "COINS"
			end
			plateAmount(card, commas(pack.robux))
			card.Activated:Connect(function()
				openConfirm({
					title = "COINS",
					name = pack.name .. (if pack.case then " + A CASE" else ""),
					art = ShopCatalog.ART.coinStack,
					price = pack.robux,
					currency = "robux",
					go = function()
						askRobux("pack", i)
					end,
				})
			end)
		end
	end
	goToPack = function(short: number)
		setTab("COINS", true)
		local best: number? = nil
		for i, pack in Products.PACKS do
			if (pack.coins or 0) >= short then
				best = i
				break
			end
		end
		best = best or #Products.PACKS
		local holder = scroll:FindFirstChild("Pack" .. best, true)
		local card = holder and holder:FindFirstChild("Card")
		LobbyHud.toast(`You need {commas(short)} more coins: this pack covers it`, "info")
		if card and card:IsA("GuiObject") then
			task.delay(0.35, function()
				UiMotion.nudge(card, UiMotion.home(card))
			end)
		end
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
	-- today's items: the player's own saved list (Services/ShopService rolls it)
	dailyItems = pages.Daily:FindFirstChild("Items", true)
	for _, d in scroll:GetDescendants() do
		if d:IsA("ImageLabel") and d.Name == "Robux" and d.Image ~= "" then
			robuxIcon = d.Image
			break
		end
	end
	for i = 1, DailyShop.SIZE do
		local holder = dailyItems and dailyItems:FindFirstChild("Item" .. i)
		local card = holder and holder:FindFirstChild("Card")
		if card and card:IsA("GuiButton") then
			card.Activated:Connect(function()
				buyDaily(i, card)
			end)
		end
	end
	drawDaily()
	local head = scroll:FindFirstChild("Head_TODAY'S ITEMS", true)
	local note = head and head:FindFirstChild("Note")
	dailyNote = if note and note:IsA("TextLabel") then note else nil

	-- popups
	CloseButton.hook(child(casePanel, "Close") :: GuiButton, function()
		showPanel(nil)
	end)
	CloseButton.hook(child(confirmPanel, "Close") :: GuiButton, function()
		confirmOpen = nil
		showPanel(nil)
	end)
	CloseButton.hook(child(rewardPanel, "Close") :: GuiButton, function()
		showPanel(nil)
	end)
	do
		local collect = child(rewardPanel, "Collect") :: GuiButton
		collect.Activated:Connect(function()
			if rewardSession then
				rewardSession.collect(canvas, coinsAmount)
			end
			showPanel(nil)
		end)
		UserInputService.InputBegan:Connect(function(input: InputObject)
			if popupOpen ~= rewardPanel then
				return
			end
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				local point = Vector2.new(input.Position.X, input.Position.Y)
				local lo = rewardPanel.AbsolutePosition
				local hi = lo + rewardPanel.AbsoluteSize
				if point.X < lo.X or point.X > hi.X or point.Y < lo.Y or point.Y > hi.Y then
					showPanel(nil)
				end
			end
		end)
	end
	do
		local buy = child(confirmPanel, "Buy") :: GuiButton
		local sc = pop(buy)
		buy.MouseEnter:Connect(function()
			rest(sc, KM.hover)
		end)
		buy.MouseLeave:Connect(function()
			rest(sc, 1)
		end)
		buy.Activated:Connect(function()
			press(sc)
			confirmBuy(buy)
		end)
	end
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
			local bundle = previewBundle
			if not bundle then
				return
			end
			if n == "BuyBundle" and ownsAll(bundle) then
				LobbyHud.toast("You already own this whole bundle", "info")
				return
			end
			local cur = bundle.items[previewIndex]
			if
				n == "BuyItem"
				and cur
				and cur.gun
				and cur.line
				and PlayerData.owns(PlayerData.skins(player), cur.gun, cur.line)
			then
				LobbyHud.toast("You already own this skin", "info")
				return
			end
			if n == "BuyBundle" then
				openConfirm({
					title = "BUNDLE",
					name = bundle.name,
					art = SkinArt.line(
						bundle.items[1] and bundle.items[1].line or "",
						{ "Vandal" }
					),
					price = bundle.robux,
					currency = "robux",
					go = function()
						askRobux("bundle", bundle.id)
					end,
				})
			else
				local index = previewIndex
				local item = bundle.items[index]
				local price = item and ShopCatalog.itemRobux(item)
				if not item or not price then
					return
				end
				openConfirm({
					title = "SKIN",
					name = item.name,
					art = if item.gun and item.line
						then SkinArt.portrait(item.gun, item.line)
						else nil,
					price = price,
					currency = "robux",
					go = function()
						askRobux("item", bundle.id, index)
					end,
				})
			end
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
	-- the daily shop redraws when the server publishes a new list or a purchase
	task.spawn(function()
		for _, name in { PlayerData.DAILY, PlayerData.SKINS } do
			local v = player:WaitForChild(name, 60)
			if v and v:IsA("StringValue") then
				v.Changed:Connect(drawDaily)
			end
		end
		drawDaily()
	end)
	-- login rewards: redraw on every change, answer the claim, nudge once per join
	StateValues.changed(player, "LoginLast"):Connect(drawLogin)
	StateValues.changed(player, "FreeDailyUsed"):Connect(drawDaily)
	StateValues.changed(player, "StarterBought"):Connect(refreshOwned)
	task.spawn(function()
		local skins = player:WaitForChild(PlayerData.SKINS, 60)
		if skins and skins:IsA("StringValue") then
			skins.Changed:Connect(function()
				refreshOwned()
				if previewBundle then
					selectPreview(previewIndex) -- BUY ITEM / BUY BUNDLE turn OWNED
				end
			end)
		end
		refreshOwned()
	end)
	-- Robux cases: fail closed until Roblox says paid random items are allowed here
	task.spawn(function()
		local ok, info = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(player)
		end)
		casesRestricted = not (
			ok
			and typeof(info) == "table"
			and info.ArePaidRandomItemsRestricted == false
		)
		drawCasePrices()
	end)
	StateValues.changed(player, "LoginStep"):Connect(drawLogin)
	LobbyNet.event("LoginEvent").OnClientEvent:Connect(function(p: LobbyNet.LoginEventPayload)
		if typeof(p) ~= "table" then
			return
		end
		if p.kind == "claimed" then
			celebrateLogin(p)
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
			local def = if p.item then Inventory.ITEMS[p.item] else nil
			celebrate({
				name = `{p.text or "Item"} · IN YOUR BACKPACK`,
				image = def and def.icon,
				tier = "Rare",
				color = ShopTheme.GOLD,
			})
		elseif p.kind == "opened" then
			return -- a case opening: the Backpack shows it (Controllers/BackpackController)
		elseif p.kind == "coins" then
			LobbyHud.toast(p.text or "Coins added", "success")
		elseif (p.kind == "skin" or p.kind == "free") and p.gun and p.line then
			celebrateSkin(p.gun, p.line)
		elseif p.kind == "robux" then
			celebrateProduct(p)
		elseif wasBuying or (p.kind == "failed" and os.clock() - lastAsk < 6) then
			denied(lastBuyButton, p.text == "Not enough coins")
			LobbyHud.toast(p.text or "Purchase failed", "error")
		end
	end)
	Router.onChanged(function()
		placeCounter()
	end)
	placeCounter()
end

return ShopController
