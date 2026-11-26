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
--     ("case", caseId, 1|3)  cases for Robux (only where paid random items are allowed)
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
local ShopService = require(script.Parent.ShopService)
local PlayZone = require(ReplicatedStorage.Shared.PlayZone)
local Telemetry = require(script.Parent.Parent.Telemetry)

local RobuxService = {}

local limiter = RateLimit.new(Config.RATE)
-- A shared product owns its saved target until receipt or confirmed cancellation.
type SkinPrompt = { productId: number, token: string }
local skinPromptOpen: { [Player]: SkinPrompt } = {}
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
	notHere = "Cases can't be bought with Robux where you are: use Tickets",
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
-- (answered, allowed): answered = false when the policy call failed (the request side
-- treats that as not allowed; a receipt waits and Roblox sends it again).
local function casesAllowed(player: Player): (boolean, boolean)
	local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
	if not ok or typeof(info) ~= "table" then
		return false, false
	end
	return true, (info :: any).ArePaidRandomItemsRestricted == false
end

local function prompt(player: Player, product: Products.Product)
	MarketplaceService:PromptProductPurchase(player, product.id)
end

local function cancelSkinPrompt(player: Player, current: SkinPrompt)
	local productKey = tostring(current.productId)
	local ok = PlayerDataService.transact(player, PlayerDataService.newTxId(), function(data)
		local intent = data.buys.intents[productKey]
		if not intent or intent.token ~= current.token then
			return false, "nothing"
		end
		data.buys.intents[productKey] = nil
		return true
	end, true)
	if skinPromptOpen[player] == current then
		skinPromptOpen[player] = nil
	end
	if not ok then
		local pending = PlayerDataService.get(player)
		local intent = pending and pending.buys.intents[productKey]
		if intent and intent.token == current.token then
			warn("[Robux] Could not save a confirmed skin-prompt cancellation")
		end
	end
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

-- A bundle's items the player doesn't own yet, as opening results (its display names).
local function newBundleSkins(
	data: PlayerData.Data,
	bundle: ShopCatalog.Bundle
): { LobbyNet.CaseReward }
	local out: { LobbyNet.CaseReward } = {}
	for _, item in bundle.items do
		local gun, line = item.gun, item.line
		if item.kind == "Skin" and gun and line and not PlayerData.owns(data.skins, gun, line) then
			table.insert(out, {
				gun = gun,
				line = line,
				tier = SkinCases.tierOf(gun, line) or item.rarity or "Exclusive",
				name = item.name,
			})
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
	if skinPromptOpen[player] then
		fail(player, "promptOpen")
		return
	end
	if not limiter:allow(player, "ShopWrite") then
		fail(player, "busy")
		return
	end
	local txId = PlayerDataService.newTxId()
	local current: SkinPrompt = { productId = product.id, token = txId }
	skinPromptOpen[player] = current
	local productKey = tostring(product.id)
	local ok, why = PlayerDataService.transact(player, txId, function(data)
		if PlayerData.owns(data.skins, gun, line) then
			return false, "owned"
		end
		if data.buys.intents[productKey] then
			return false, "busy"
		end
		data.buys.intents[productKey] = {
			product = product.id,
			gun = gun,
			line = line,
			slot = slot,
			at = os.time(),
			token = txId,
		}
		return true
	end)
	if ok then
		if not pcall(prompt, player, product) then
			cancelSkinPrompt(player, current)
			fail(player, "saving")
		end
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
	if PlayZone.get(player) ~= "Lobby" then
		reject("notLobby")
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
		local product = if item.productId
			then Products.BY_ID[item.productId]
			elseif price then Products.SKIN_BY_PRICE[price]
			else nil
		if
			item.kind ~= "Skin"
			or not item.gun
			or not item.line
			or not product
			or product.kind ~= "skin"
		then
			fail(player, "notSold")
			return
		end
		if PlayerData.owns(known.skins, item.gun, item.line) then
			fail(player, "owned")
			return
		end
		if item.productId then
			local skin = product.skin
			if not skin or skin.gun ~= item.gun or skin.line ~= item.line then
				fail(player, "notSold")
				return
			end
			prompt(player, product)
		else
			promptSkin(player, product, item.gun, item.line, nil)
		end
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
	elseif what == "case" then
		local byCount = if typeof(a) == "string" and #a <= 24
			then Products.CASES[a :: string]
			else nil
		local product = if byCount and (b == 1 or b == 3) then byCount[b :: number] else nil
		if not product then
			reject("badArgs")
			return
		end
		local _, allowed = casesAllowed(player)
		if not allowed then
			fail(player, "notHere")
			return
		end
		prompt(player, product)
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

local function skinTarget(
	data: PlayerData.Data,
	product: Products.Product
): (string?, string?, number?)
	local skin = product.skin
	if skin then
		return skin.gun, skin.line, nil
	end
	local intent = data.buys.intents[tostring(product.id)]
	if intent and intent.product == product.id then
		return intent.gun, intent.line, intent.slot
	end
	return nil, nil, nil
end

-- The grant for one receipt, run inside the save write. Returns the toast line.
local function grant(data: PlayerData.Data, product: Products.Product, allowCase: boolean): string
	local function addCoins(n: number)
		data.coins = math.min(data.coins + n, Inventory.MAX_COINS)
	end
	-- `n` cases where allowed and there's room in the stack, `insteadEach` coins for any not given
	-- `n` cases where allowed and there's room in the stack; for any not given, their share
	-- of `insteadTotal` coins (all of it when none were given)
	local function addCases(itemId: string?, n: number, insteadTotal: number): number
		local def = if itemId then Inventory.ITEMS[itemId] else nil
		local given = 0
		if def and allowCase and n > 0 then
			local held = data.items[def.id] or 0
			given = math.clamp(def.maxStack - held, 0, n)
			if given > 0 then
				data.items[def.id] = held + given
			end
		end
		if n > 0 and given < n then
			addCoins(
				if given == 0 then insteadTotal else math.floor(insteadTotal * (n - given) / n)
			)
		end
		return given
	end
	if product.kind == "coins" then
		addCoins(product.coins or 0)
		local got = addCases(product.case, if product.case then 1 else 0, product.caseCoins or 0)
		return `+{product.coins} coins` .. (if got > 0 then " and a case" else "")
	elseif product.kind == "starter" then
		if data.buys.starter then
			addCoins(compensation(product))
			return `Starter Bundle already bought: +{compensation(product)} coins`
		end
		data.buys.starter = true
		addCoins(product.coins or 0)
		if allowCase then
			local n = product.caseCount or 0
			local got = addCases(product.case, n, product.fallbackCoins or 0)
			data.tickets = math.min(data.tickets + (product.tickets or 0), Economy.MAX_TICKETS)
			return `Starter Bundle: {got} cases, {product.coins} coins and {product.tickets} Tickets`
		end
		addCoins(product.fallbackCoins or 0)
		return `Starter Bundle: {(product.coins or 0) + (product.fallbackCoins or 0)} coins`
	elseif product.kind == "case" then
		local n = math.max(product.count or 1, 1)
		local got = addCases(product.case, n, compensation(product))
		return if got == n
			then `{product.name} added to your Backpack`
			elseif
				got > 0
			then `{got} of {n} cases added (your Backpack is full); coins for the rest`
			else `+{compensation(product)} coins (cases can't be sold here)`
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
	else -- one skin
		local gun, line, slot = skinTarget(data, product)
		if not product.skin then
			data.buys.intents[tostring(product.id)] = nil
		end
		if not gun or not line then
			addCoins(compensation(product))
			return `+{compensation(product)} coins (we couldn't tell which skin)`
		end
		if not PlayerData.grantSkin(data, gun, line) then
			addCoins(compensation(product))
			return `You already owned it: +{compensation(product)} coins`
		end
		if slot and data.daily.picks[slot] and not table.find(data.daily.bought, slot) then
			local p = data.daily.picks[slot]
			if p.gun == gun and p.line == line then
				table.insert(data.daily.bought, slot)
			end
		end
		local name = if product.skin then product.name else SkinCases.name(gun, line)
		return `{name} is yours: equip it in the Locker`
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
	local allowCase = false
	if product.case ~= nil then
		local answered, allowed = casesAllowed(player)
		if not answered then
			-- don't turn a paid case into coins because the policy call hiccuped: retry later
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		allowCase = allowed
	end
	local text = ""
	local gotGun: string?, gotLine: string? = nil, nil
	local gotBundle: { LobbyNet.CaseReward } = {}
	local bundleDef = if product.kind == "bundle" and product.bundle
		then ShopCatalog.bundle(product.bundle)
		else nil
	local purchaseId = string.sub(tostring(info.PurchaseId), 1, 62)
	local txId = "r:" .. purchaseId
	local promptAtReceipt = skinPromptOpen[player]
	local ok, why = PlayerDataService.transact(player, txId, function(data)
		-- receipts have their own memory (the shared `tx` list only keeps the last few writes)
		if table.find(data.buys.receipts, purchaseId) then
			return false, "granted"
		end
		gotGun, gotLine = nil, nil
		gotBundle = if bundleDef then newBundleSkins(data, bundleDef) else {}
		if product.kind == "skin" then
			local gun, line = skinTarget(data, product)
			if gun and line and not PlayerData.owns(data.skins, gun, line) then
				gotGun, gotLine = gun, line
			end
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
	if text ~= "" then
		Telemetry.event(
			player,
			"Robux receipt granted",
			tonumber(info.CurrencySpent) or 0,
			product.kind
		)
		if
			promptAtReceipt
			and promptAtReceipt.productId == product.id
			and skinPromptOpen[player] == promptAtReceipt
		then
			skinPromptOpen[player] = nil
		end
	end
	-- A bundle with its own crates: the opening plays for the buyer and everyone near
	-- (owner 2026-11-25); the models go out first, like a case.
	local crate = bundleDef and bundleDef.crate
	local results: { LobbyNet.CaseReward }? = nil
	if crate and #gotBundle > 0 then
		results = gotBundle
		ShopService.showOpening(player, crate, #gotBundle, gotBundle)
	end
	send(player, {
		kind = "robux",
		text = if text ~= "" then text else "Purchase complete",
		product = product.id,
		gun = gotGun,
		line = gotLine,
		results = results,
		crate = if results then crate else nil,
	})
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function RobuxService.init() end

function RobuxService.start()
	shopEvent = LobbyNet.event("ShopEvent")
	LobbyNet.event("RobuxRequest").OnServerEvent:Connect(onRequest)
	MarketplaceService.ProcessReceipt = processReceipt
	-- A successful prompt can finish before the receipt callback arrives.
	MarketplaceService.PromptProductPurchaseFinished:Connect(
		function(userId: number, productId: number, purchased: boolean)
			local p = Players:GetPlayerByUserId(userId)
			local current = p and skinPromptOpen[p]
			if p and current and current.productId == productId and not purchased then
				cancelSkinPrompt(p, current)
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
