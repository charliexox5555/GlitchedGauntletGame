--!strict
-- Robux purchases (developer products, Config/Products; vault/01 Design/Shop Economy and
-- Art v1.md → Step 3). LihFolk: Developer Products and ProcessReceipt, Purchase Data and
-- Receipts, Paid Random Items and Odds Disclosure.
--   RobuxRequest (client -> server):
--     ("pack", n)            coin pack n (1..#Products.PACKS)
--     ("bundle", bundleId)   a whole bundle
--     ("item", bundleId, i)  item i of a bundle on its own
--     ("daily", slot)        a Robux-priced slot of the player's saved daily shop
--     ("starter")            the Starter Bundle (once per player)
--   The server checks the ask against its own tables and the player's save, then prompts.
--   For the shared skin products (one per price) it first saves WHICH skin in the player's
--   data (`buys.intents`, one per product), so the receipt always knows what was paid
--   for; while that prompt is open no other skin can be asked for.
-- ProcessReceipt: the ONLY owner of MarketplaceService.ProcessReceipt in the lobby. One
-- PlayerDataService write per receipt with txId "r:<PurchaseId>" (a retried receipt finds
-- it and is granted once); PurchaseGranted only after the write; NotProcessedYet when the
-- player or their data isn't here (Roblox sends it again later). Never grants from
-- PromptProductPurchaseFinished.
-- Cases inside a Robux purchase (coin packs 4-6, the Starter Bundle) are paid random
-- items: granted only where PolicyService allows (checked at grant, fail closed), extra
-- coins otherwise. Anything that can't be granted (a lost intent, a skin already owned)
-- pays its Robux price back as coins (Economy.ROBUX_TO_COINS each).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Lobby.Config)
local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local ShopCatalog = require(ReplicatedStorage.Lobby.ShopCatalog)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Inventory = require(ReplicatedStorage.Shared.Config.Inventory)
local Products = require(ReplicatedStorage.Shared.Config.Products)
local DailyRoll = require(ReplicatedStorage.Shared.DailyRoll)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local SkinCases = require(ReplicatedStorage.Shared.SkinCases)
local RateLimit = require(ReplicatedStorage.Shared.Util.RateLimit)
local PlayerDataService = require(script.Parent.PlayerDataService)

local RobuxService = {}

local limiter = RateLimit.new(Config.RATE)
-- A skin prompt that is open (security review 2026-11-22): while it is, no other skin can
-- be asked for, so the saved choice can't change under the dialog. Cleared when Roblox
-- says the prompt closed (never a grant) or after PROMPT_LOCK seconds.
local PROMPT_LOCK = 120
local skinPromptOpen: { [Player]: number } = {}
local shopEvent: RemoteEvent
local rejects: { [string]: number } = {}

local REASON_TEXT: { [string]: string } = {
	owned = "You already own that",
	ownAll = "You already own everything in that bundle",
	starter = "You already have the Starter Bundle",
	expired = "The daily shop just changed, take another look",
	saving = "Couldn't reach your save, try again",
	busy = "Still finishing your last purchase",
	notSold = "That isn't sold for Robux",
	promptOpen = "Finish the purchase that's open first",
}

local function reject(reason: string)
	rejects[reason] = (rejects[reason] or 0) + 1
end

local function send(player: Player, payload: LobbyNet.ShopEventPayload)
	if player.Parent then
		shopEvent:FireClient(player, payload)
	end
end

local function fail(player: Player, why: string)
	send(player, { kind = "failed", text = REASON_TEXT[why] or REASON_TEXT.saving })
end

local function compensation(product: Products.Product): number
	return product.robux * Economy.ROBUX_TO_COINS
end

-- Paid random items allowed for this player? Fails closed (an error = no).
local function casesAllowed(player: Player): boolean
	local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
	return ok and typeof(info) == "table" and (info :: any).ArePaidRandomItemsRestricted == false
end

local function prompt(player: Player, product: Products.Product)
	MarketplaceService:PromptProductPurchase(player, product.id)
end

-- Every skin of a bundle as { gun, line } (Item entries without both are skipped).
local function bundleSkins(bundle: ShopCatalog.Bundle): { { gun: string, line: string } }
	local out = {}
	for _, item in bundle.items do
		if item.kind == "Skin" and item.gun and item.line then
			table.insert(out, { gun = item.gun, line = item.line })
		end
	end
	return out
end

-- Saves which skin a shared skin product is for, then prompts.
local function promptSkin(
	player: Player,
	product: Products.Product,
	gun: string,
	line: string,
	slot: number?
)
	local open = skinPromptOpen[player]
	if open and os.clock() - open < PROMPT_LOCK then
		fail(player, "promptOpen")
		return
	end
	if not limiter:allow(player, "ShopWrite") then
		fail(player, "busy")
		return
	end
	skinPromptOpen[player] = os.clock()
	local ok, why = PlayerDataService.transact(player, PlayerDataService.newTxId(), function(data)
		if PlayerData.owns(data.skins, gun, line) then
			return false, "owned"
		end
		data.buys.intents[tostring(product.id)] =
			{ product = product.id, gun = gun, line = line, slot = slot, at = os.time() }
		return true
	end)
	if ok then
		prompt(player, product)
	else
		skinPromptOpen[player] = nil
		fail(player, why or "saving")
	end
end

local function onRequest(player: Player, what: unknown, a: unknown, b: unknown)
	if not limiter:allow(player, "RobuxRequest") then
		reject("rate")
		return
	end
	if typeof(what) ~= "string" then
		reject("badAction")
		return
	end
	local known = PlayerDataService.get(player)
	if not known then
		fail(player, "saving")
		return
	end
	if what == "pack" then
		if
			typeof(a) ~= "number"
			or a ~= a
			or a ~= math.floor(a)
			or a < 1
			or a > #Products.PACKS
		then
			reject("badArgs")
			return
		end
		prompt(player, Products.PACKS[a :: number])
	elseif what == "bundle" then
		local bundle = if typeof(a) == "string" and #a <= 32
			then ShopCatalog.bundle(a :: string)
			else nil
		local product = bundle and Products.BUNDLE[bundle.id]
		if not bundle or not product or bundle.soon then
			reject("badArgs")
			return
		end
		local missing = 0
		for _, s in bundleSkins(bundle) do
			if not PlayerData.owns(known.skins, s.gun, s.line) then
				missing += 1
			end
		end
		if missing == 0 then
			fail(player, "ownAll")
			return
		end
		prompt(player, product)
	elseif what == "item" then
		local bundle = if typeof(a) == "string" and #a <= 32
			then ShopCatalog.bundle(a :: string)
			else nil
		if
			not bundle
			or typeof(b) ~= "number"
			or b ~= b
			or b ~= math.floor(b)
			or b < 1
			or b > #bundle.items
		then
			reject("badArgs")
			return
		end
		local item = bundle.items[b :: number]
		local price = ShopCatalog.itemRobux(item)
		local product = if price then Products.SKIN_BY_PRICE[price] else nil
		if item.kind ~= "Skin" or not item.gun or not item.line or not product then
			fail(player, "notSold")
			return
		end
		if PlayerData.owns(known.skins, item.gun, item.line) then
			fail(player, "owned")
			return
		end
		promptSkin(player, product, item.gun, item.line, nil)
	elseif what == "daily" then
		if typeof(a) ~= "number" or a ~= a or a ~= math.floor(a) or a < 1 or a > 16 then
			reject("badArgs")
			return
		end
		local slot = a :: number
		local pick = known.daily.picks[slot]
		if known.daily.day ~= Economy.day(os.time()) or not pick then
			fail(player, "expired")
			return
		end
		local coins, robux = DailyRoll.price(pick)
		local product = if robux then Products.SKIN_BY_PRICE[robux] else nil
		if coins or not product then
			fail(player, "notSold")
			return
		end
		if
			table.find(known.daily.bought, slot)
			or PlayerData.owns(known.skins, pick.gun, pick.line)
		then
			fail(player, "owned")
			return
		end
		promptSkin(player, product, pick.gun, pick.line, slot)
	elseif what == "starter" then
		local product = Products.STARTER
		if not product then
			return
		end
		if known.buys.starter then
			fail(player, "starter")
			return
		end
		prompt(player, product)
	else
		reject("badAction")
	end
end

-- The grant for one receipt, run inside the save write. Returns the toast line.
local function grant(data: PlayerData.Data, product: Products.Product, allowCase: boolean): string
	local function addCoins(n: number)
		data.coins = math.min(data.coins + n, Inventory.MAX_COINS)
	end
	local function addCase(itemId: string?, instead: number?): string?
		local def = if itemId then Inventory.ITEMS[itemId] else nil
		if def and allowCase and (data.items[def.id] or 0) < def.maxStack then
			data.items[def.id] = (data.items[def.id] or 0) + 1
			return def.name
		end
		addCoins(instead or 0)
		return nil
	end
	if product.kind == "coins" then
		addCoins(product.coins or 0)
		local case = addCase(product.case, product.caseCoins)
		return `+{product.coins} coins` .. (if case then ` and a {case}` else "")
	elseif product.kind == "starter" then
		if data.buys.starter then
			addCoins(compensation(product))
			return `Starter Bundle already bought: +{compensation(product)} coins`
		end
		data.buys.starter = true
		addCoins(product.coins or 0)
		local case = addCase(product.case, product.caseCoins)
		return `Starter Bundle: +{product.coins} coins` .. (if case then ` and a {case}` else "")
	elseif product.kind == "bundle" then
		local bundle = if product.bundle then ShopCatalog.bundle(product.bundle) else nil
		local got = 0
		if bundle then
			for _, s in bundleSkins(bundle) do
				if PlayerData.grantSkin(data, s.gun, s.line) then
					got += 1
				end
			end
		end
		if got == 0 then
			addCoins(compensation(product))
			return `You owned it all: +{compensation(product)} coins`
		end
		return `{product.name} is yours: equip it in the Locker`
	else -- one skin: the saved intent says which
		local key = tostring(product.id)
		local intent = data.buys.intents[key]
		data.buys.intents[key] = nil
		if not intent or intent.product ~= product.id then
			addCoins(compensation(product))
			return `+{compensation(product)} coins (we couldn't tell which skin)`
		end
		if not PlayerData.grantSkin(data, intent.gun, intent.line) then
			addCoins(compensation(product))
			return `You already owned it: +{compensation(product)} coins`
		end
		local slot = intent.slot
		if slot and data.daily.picks[slot] and not table.find(data.daily.bought, slot) then
			local p = data.daily.picks[slot]
			if p.gun == intent.gun and p.line == intent.line then
				table.insert(data.daily.bought, slot)
			end
		end
		return `{SkinCases.name(intent.gun, intent.line)} is yours: equip it in the Locker`
	end
end

local function processReceipt(info: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local product = Products.BY_ID[info.ProductId]
	if not player or not PlayerDataService.get(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not product then
		warn(`[Robux] receipt for an unknown product {info.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local allowCase = product.case ~= nil and casesAllowed(player)
	local text = ""
	local purchaseId = string.sub(tostring(info.PurchaseId), 1, 62)
	local txId = "r:" .. purchaseId
	local ok, why = PlayerDataService.transact(player, txId, function(data)
		-- receipts have their own memory (the shared `tx` list only keeps the last few writes)
		if table.find(data.buys.receipts, purchaseId) then
			return false, "granted"
		end
		text = grant(data, product, allowCase)
		table.insert(data.buys.receipts, 1, purchaseId)
		while #data.buys.receipts > PlayerData.RECEIPT_MEMORY do
			table.remove(data.buys.receipts)
		end
		return true
	end, true)
	if not ok and why == "granted" then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- an earlier attempt already gave it
	end
	if not ok then
		warn(`[Robux] receipt {info.PurchaseId} not saved: {why}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	send(player, { kind = "robux", text = if text ~= "" then text else "Purchase complete" })
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function RobuxService.init() end

function RobuxService.start()
	shopEvent = LobbyNet.event("ShopEvent")
	LobbyNet.event("RobuxRequest").OnServerEvent:Connect(onRequest)
	MarketplaceService.ProcessReceipt = processReceipt
	-- only unlocks the skin prompt; granting is ProcessReceipt's alone
	MarketplaceService.PromptProductPurchaseFinished:Connect(
		function(userId: number, productId: number)
			local p = Players:GetPlayerByUserId(userId)
			local product = Products.BY_ID[productId]
			if p and product and product.kind == "skin" then
				skinPromptOpen[p] = nil
			end
		end
	)
	Players.PlayerRemoving:Connect(function(p)
		limiter:forget(p)
		skinPromptOpen[p] = nil
	end)
	-- Studio only: a test hook that runs a fake receipt (Studio's purchase dialog can't
	-- be clicked by tools). ServerStorage.RobuxTestReceipt:Invoke(userId, productId, purchaseId?).
	if RunService:IsStudio() then
		local hook = Instance.new("BindableFunction")
		hook.Name = "RobuxTestReceipt"
		local n = 0
		hook.OnInvoke = function(userId: number, productId: number, purchaseId: string?)
			n += 1
			return processReceipt({
				PlayerId = userId,
				ProductId = productId,
				PurchaseId = purchaseId or `studio-{os.time()}-{n}`,
			}).Name
		end
		hook.Parent = ServerStorage
	end
	while true do
		task.wait(Config.rejectLogInterval)
		if next(rejects) then
			local parts = {}
			for reason, count in rejects do
				table.insert(parts, `{reason}={count}`)
			end
			warn(`[Robux] rejected RobuxRequest: {table.concat(parts, ", ")}`)
			table.clear(rejects)
		end
	end
end

return RobuxService
