--!strict
-- Buying from the Shop (vault/01 Design/Inventory and Crates.md, Shop Economy and Art v1.md).
-- Cases cost Tickets (earn-only, Config/Economy.CASE_TICKETS) and go into the inventory
-- unopened; the player's own daily shop sells Common / Rare skins for coins. Robux
-- purchases (developer products, ProcessReceipt) come next.
--
-- ShopRequest (client -> server):
--   ("buyCase", caseId)  pay the case's Ticket price, +1 of its inventory item
--   ("buyPack", 1|3, "coins"|"tickets")  SURGE power packs: coins where paid random items are
--                        allowed, else Tickets (Config/Economy.POWER_PACK); the currency the
--                        popup showed must match, so it never charges what it didn't show;
--                        never more packs than the powers unowned
--   ("buyDaily", slot)   buy slot 1..8 of the player's saved daily shop (coin tiers)
--   ("claimFree", slot)  the one free daily skin (Shared/DailyShop.freeSlot must be slot)
--   ("openCase", itemId, count?, requestId?) use one or three held cases and
--                        grant unowned skins (Shared/SkinCases) or refund Tickets
--   ("devCoins")         Studio only: + Inventory.STUDIO_GRANT coins
--   ("devSkins")         Studio only: own every skin (testing the Locker)
-- ShopEvent (server -> that client): ShopEventPayload in LobbyNet.
--
-- The client sends only what it wants; the price, the item and the balance
-- check all come from the server's own tables and the stored save, inside one
-- atomic write (PlayerDataService.transact). Type-checked and rate-limited.
-- Skin cases are bought only with Tickets, which are earned and never sold for Robux, so a
-- case is not a paid random item (LihFolk: Paid Random Items and Odds Disclosure) and
-- needs no PolicyService gate. A case inside a Robux pack will be gated where it's granted.
-- The power pack costs coins, which ARE sold, so its coin price is a paid random item: offered
-- only where PolicyService allows (LobbyServer/PaidRandom, fail closed), Tickets elsewhere.
-- The daily shop is rolled here (Shared/DailyRoll) at the player's first data of the UTC
-- day, and again for anyone still online after midnight, and saved before it's shown.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Lobby.Config)
local OpeningConfig = require(ReplicatedStorage.Shared.Config.CaseOpening)
local Inventory = require(ReplicatedStorage.Shared.Config.Inventory)
local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local RateLimit = require(ReplicatedStorage.Shared.Util.RateLimit)
local ShopCatalog = require(ReplicatedStorage.Lobby.ShopCatalog)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local SkinCases = require(ReplicatedStorage.Shared.SkinCases)
local PowerCases = require(ReplicatedStorage.Shared.PowerCases)
local ModLoadout = require(ReplicatedStorage.Shared.ModLoadout)
local Mods = require(ReplicatedStorage.Shared.Mods)
local Locker = require(ReplicatedStorage.Shared.Locker)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local DailyRoll = require(ReplicatedStorage.Shared.DailyRoll)
local DailyShop = require(ReplicatedStorage.Shared.DailyShop)
local PlayerDataService = require(script.Parent.PlayerDataService)
local Telemetry = require(script.Parent.Parent.Telemetry)
local PlayZone = require(ReplicatedStorage.Shared.PlayZone)
local SkinStoreService = require(script.Parent.SkinStoreService)
local PaidRandom = require(script.Parent.Parent.PaidRandom)

local ShopService = {}

local limiter = RateLimit.new(Config.RATE)
local shopVisits: { [Player]: boolean } = {}
local rejects: { [string]: number } = {}
local shopEvent: RemoteEvent
local caseShow: RemoteEvent

local REASON_TEXT: { [string]: string } = {
	coins = "Not enough coins",
	tickets = "Not enough Tickets",
	expired = "The daily shop just changed, take another look",
	bought = "You already bought that one",
	owned = "You already own that skin",
	robux = "Buy that one with Robux",
	freeUsed = "You already claimed your free skin",
	full = "Your Backpack can't hold more of those",
	busy = "Still finishing your last purchase",
	saving = "Couldn't reach your save, try again",
	update = "The game updated, rejoin to keep buying",
	invalid = "Purchase failed",
	slow = "Slow down a little",
	noCase = "You don't have that case",
	ownAll = "You own every skin that case has for your guns",
	ownAllPowers = "You already own every power (or hold packs for the rest)",
	policy = "Couldn't check the shop rules for your region, try again",
	priceChanged = "That price changed, take another look",
}

local function reject(reason: string)
	rejects[reason] = (rejects[reason] or 0) + 1
end

local function send(player: Player, payload: LobbyNet.ShopEventPayload)
	if player.Parent then
		shopEvent:FireClient(player, payload)
	end
end

-- How many skins (or, from a power case, powers: Shared/PowerCases) this case can still give a player.
-- Skins: only for guns they own (Shared/SkinCases.unowned, owner 2026-11-27).
local function unownedIn(caseId: string, data: PlayerData.Data): number
	if PowerCases.isPowerCase(caseId) then
		return #PowerCases.unowned(caseId, data.mods)
	end
	return SkinCases.unowned(caseId, data.skins, data.guns)
end

-- The SURGE power pack (vault/01 Design/Loadout and Power Deck.md -> Launch plan, owner 2026-11-27): one or
-- three for coins where paid random items are allowed, else for earn-only Tickets (Config/Economy.POWER_PACK).
-- Never more held packs than the powers still unowned, so every pack bought can give a new power.
local POWER_CASE = "Power"
local function buyPowerPack(player: Player, count: number, shown: string)
	local itemId = Inventory.BY_CASE[POWER_CASE]
	local def = if itemId then Inventory.ITEMS[itemId] else nil
	if not def or def.retired then
		reject("badCase")
		return
	end
	local known = PlayerDataService.get(player)
	if not known then
		send(player, { kind = "failed", text = REASON_TEXT.saving })
		return
	end
	local held = known.items[def.id] or 0
	local room = unownedIn(POWER_CASE, known) - held
	if room < count then
		send(player, {
			kind = "failed",
			text = if room <= 0
				then REASON_TEXT.ownAllPowers
				else `Only {room} more pack{if room == 1 then "" else "s"}: that's every power left`,
		})
		return
	end
	if held + count > def.maxStack then
		send(player, { kind = "failed", text = REASON_TEXT.full })
		return
	end
	if not limiter:allow(player, "ShopWrite") then
		send(player, { kind = "failed", text = REASON_TEXT.slow })
		return
	end
	local answered, allowed = PaidRandom.check(player)
	if not answered then
		send(player, { kind = "failed", text = REASON_TEXT.policy })
		return
	end
	if shown ~= (if allowed then "coins" else "tickets") then
		send(player, { kind = "failed", text = REASON_TEXT.priceChanged })
		return
	end
	local coins = if allowed then Economy.POWER_PACK.coins * count else 0
	local tickets = if allowed then 0 else Economy.POWER_PACK.restrictedTickets * count
	if known.coins < coins or known.tickets < tickets then
		send(
			player,
			{ kind = "failed", text = if allowed then REASON_TEXT.coins else REASON_TEXT.tickets }
		)
		return
	end
	local ok, why = PlayerDataService.transact(player, PlayerDataService.newTxId(), function(data)
		if data.coins < coins then
			return false, "coins"
		end
		if data.tickets < tickets then
			return false, "tickets"
		end
		local have = data.items[def.id] or 0
		if have + count > def.maxStack then
			return false, "full"
		end
		if unownedIn(POWER_CASE, data) - have < count then
			return false, "ownAllPowers"
		end
		data.coins -= coins
		data.tickets -= tickets
		data.items[def.id] = have + count
		return true
	end)
	if ok then
		Telemetry.event(
			player,
			if allowed then "Power pack coin purchase" else "Power pack ticket purchase",
			count
		)
		send(player, {
			kind = "bought",
			item = def.id,
			count = count,
			text = if count == 1 then def.name else `{count} {def.name}S`,
		})
	else
		send(player, { kind = "failed", text = REASON_TEXT[why or ""] or "Purchase failed" })
	end
end

local function buyCase(player: Player, caseId: string)
	local case = ShopCatalog.case(caseId)
	local itemId = Inventory.BY_CASE[caseId]
	local def = if itemId then Inventory.ITEMS[itemId] else nil
	local price = Economy.CASE_TICKETS[caseId]
	if not case or not def or def.retired or not price or price <= 0 then
		reject("badCase")
		return
	end
	-- Cheap refusals from the loaded copy, so a click that can't succeed costs
	-- no DataStore request. The real check is inside the write.
	local known = PlayerDataService.get(player)
	if known and known.tickets < price then
		send(player, { kind = "failed", text = REASON_TEXT.tickets })
		return
	end
	if known and (known.items[def.id] or 0) >= def.maxStack then
		send(player, { kind = "failed", text = REASON_TEXT.full })
		return
	end
	-- never sell a case that has nothing left for them (each held one needs a skin)
	if known and unownedIn(caseId, known) <= (known.items[def.id] or 0) then
		send(player, { kind = "failed", text = REASON_TEXT.ownAll })
		return
	end
	if not limiter:allow(player, "ShopWrite") then
		send(player, { kind = "failed", text = REASON_TEXT.slow })
		return
	end
	local ok, why = PlayerDataService.transact(player, PlayerDataService.newTxId(), function(data)
		if data.tickets < price then
			return false, "tickets"
		end
		local held = data.items[def.id] or 0
		if held >= def.maxStack then
			return false, "full"
		end
		if unownedIn(caseId, data) <= held then
			return false, "ownAll"
		end
		data.tickets -= price
		data.items[def.id] = held + 1
		return true
	end)
	if ok then
		Telemetry.event(player, "Ticket case purchased", 1, caseId)
		send(player, { kind = "bought", item = def.id, count = 1, text = def.name })
	else
		send(player, { kind = "failed", text = REASON_TEXT[why or ""] or "Purchase failed" })
	end
end

-- Roll the whole batch on the stored data. Each retry starts with the same seed,
-- and each successful roll joins the owned set before the next case is rolled.
-- An opening's audience: the reward models go to the opener and everyone near them, then the
-- others get CaseShow to play it at the opener (a case from the Backpack, or a bought bundle:
-- RobuxService). `crate` is the Config/Crates look, `count` the crates thrown.
function ShopService.showOpening(
	player: Player,
	crate: number,
	count: number,
	rewards: { LobbyNet.CaseReward }
)
	local viewers = { player }
	local character = player.Character
	local origin = character and character:FindFirstChild("HumanoidRootPart")
	if origin and origin:IsA("BasePart") then
		for _, other in Players:GetPlayers() do
			if other == player then
				continue
			end
			local otherCharacter = other.Character
			local root = otherCharacter and otherCharacter:FindFirstChild("HumanoidRootPart")
			if
				root
				and root:IsA("BasePart")
				and (root.Position - origin.Position).Magnitude <= OpeningConfig.VIEW_DISTANCE
			then
				table.insert(viewers, other)
			end
		end
	end
	for _, reward in rewards do
		if not reward.power then -- a power is a card, no model to deliver
			SkinStoreService.sendTo(viewers, reward.gun, reward.line)
		end
	end
	local show: LobbyNet.CaseShowPayload = {
		userId = player.UserId,
		crate = crate,
		count = count,
		results = rewards,
	}
	for i = 2, #viewers do
		caseShow:FireClient(viewers[i], show)
	end
end

local function openCase(player: Player, itemId: string, count: number, requestId: number?)
	local function refuse(reason: string)
		send(player, { kind = "failed", item = itemId, openRequest = requestId, text = reason })
	end

	local def = Inventory.ITEMS[itemId]
	local caseId = if def and def.kind == "Case" then def.case else nil
	if not def or not caseId then
		reject("badItem")
		refuse(REASON_TEXT.noCase)
		return
	end
	local short = if count == 1 then REASON_TEXT.noCase else `You need {count} of that case`
	local known = PlayerDataService.get(player)
	if known and (known.items[itemId] or 0) < count then
		refuse(short)
		return
	end
	if not limiter:allow(player, "ShopWrite") then
		refuse(REASON_TEXT.slow)
		return
	end
	local seed = Random.new():NextInteger(1, 2 ^ 30)
	local refund = Economy.CASE_TICKETS[caseId] or 0
	local rewards: { LobbyNet.CaseReward } = {}
	local ticketsBack = 0
	local coinsBack = 0 -- a power pack with no power left pays Economy.POWER_PACK.coins back
	local txId = PlayerDataService.newTxId()
	local firstOnbOpen = false
	Telemetry.funnel(player, "Case opening", txId, 1, "Eligible request", caseId)
	local ok, why = PlayerDataService.transact(player, txId, function(data)
		table.clear(rewards)
		ticketsBack = 0
		coinsBack = 0
		firstOnbOpen = false
		local held = data.items[itemId] or 0
		if held < count then
			return false, "noCase"
		end
		data.items[itemId] = if held > count then held - count else nil
		if data.onb.caseGift and not data.onb.caseOpened then
			data.onb.caseOpened = true
			firstOnbOpen = true
		end
		local rng = Random.new(seed)
		local before = data.tickets
		for _ = 1, count do
			if PowerCases.isPowerCase(caseId) then
				-- a power case: a power they don't own yet, never a duplicate (vault: Power cases)
				local id = PowerCases.roll(caseId, data.mods, rng)
				local mod = id and Mods.def(id)
				if id and mod then
					ModLoadout.grant(data.mods, id)
					table.insert(rewards, {
						gun = "",
						line = "",
						power = id,
						tier = PowerCases.tierOf(id), -- Config/PowerCases: the opening grows with it
						name = string.upper(mod.name),
					})
				else
					local coinsBefore = data.coins
					data.coins =
						math.min(data.coins + Economy.POWER_PACK.coins, Inventory.MAX_COINS)
					coinsBack += data.coins - coinsBefore
				end
				continue
			end
			local pair = SkinCases.roll(caseId, data.skins, data.guns, rng)
			if pair then
				PlayerData.grantSkin(data, pair.gun, pair.line)
				table.insert(rewards, {
					gun = pair.gun,
					line = pair.line,
					tier = pair.tier,
					name = SkinCases.name(pair.gun, pair.line),
				})
			else
				data.tickets = math.min(data.tickets + refund, Economy.MAX_TICKETS)
			end
		end
		ticketsBack = data.tickets - before
		return true
	end)

	if not ok then
		refuse(if why == "noCase" then short else REASON_TEXT[why or ""] or "Couldn't open it")
		return
	end
	local first = rewards[1]
	Telemetry.funnel(player, "Case opening", txId, 2, "Opening saved", caseId)
	Telemetry.event(player, "Cases opened", count, caseId)
	for _, r in rewards do
		if r.power then
			Telemetry.event(player, "Power granted", 1, r.power)
		end
	end
	if firstOnbOpen then
		Telemetry.onboarding(player, 15)
		Telemetry.caseOnboarding(player, 3, "Case opened")
	end
	if not first and PowerCases.isPowerCase(caseId) then
		send(player, {
			kind = "refunded",
			item = itemId,
			openRequest = requestId,
			count = 0,
			text = `You own every power already: {coinsBack} coins back`,
		})
		return
	end
	if not first then
		send(player, {
			kind = "refunded",
			item = itemId,
			openRequest = requestId,
			count = ticketsBack,
			ticketsBack = ticketsBack,
			text = if ticketsBack > 0
				then `You own every skin in it for your guns: {ticketsBack} Ticket{if ticketsBack
						== 1
					then ""
					else "s"} back`
				else "You own every skin in it for your guns",
		})
		return
	end

	ShopService.showOpening(player, def.tier, count, rewards)
	send(player, {
		kind = "opened",
		item = itemId,
		count = count,
		openRequest = requestId,
		gun = first.gun,
		line = first.line,
		tier = first.tier,
		text = first.name,
		results = rewards,
		ticketsBack = ticketsBack,
	})
end

-- The daily shop ------------------------------------------------------------

-- Rolls and saves a player's daily shop when theirs is from an earlier UTC day. The roll
-- happens inside the write, on the stored skins, so it always matches what they own.
local rolling: { [Player]: boolean } = {}
local function ensureDaily(player: Player)
	local known = PlayerDataService.get(player)
	local today = Economy.day(os.time())
	if not known or known.daily.day >= today or rolling[player] then
		return
	end
	rolling[player] = true
	local seed = Random.new():NextInteger(1, 2 ^ 30)
	PlayerDataService.transact(player, PlayerDataService.newTxId(), function(data)
		local day = Economy.day(os.time())
		-- another server rolled it first (or its clock is a little ahead): keep theirs
		if data.daily.day >= day then
			return false, "same"
		end
		data.daily = DailyRoll.roll(data.skins, day, Random.new(seed))
		return true
	end)
	rolling[player] = nil
end

-- Buys one slot of the player's own saved daily shop. Coin tiers only for now.
local function buyDaily(player: Player, slot: number)
	local known = PlayerDataService.get(player)
	if not known then
		send(player, { kind = "failed", text = REASON_TEXT.saving })
		return
	end
	local today = Economy.day(os.time())
	local pick = known.daily.picks[slot]
	if known.daily.day ~= today or not pick then
		send(player, { kind = "failed", text = REASON_TEXT.expired })
		task.spawn(ensureDaily, player)
		return
	end
	local coins = DailyRoll.price(pick)
	if not coins then
		send(player, { kind = "failed", text = REASON_TEXT.robux })
		return
	end
	if known.coins < coins then
		send(player, { kind = "failed", text = REASON_TEXT.coins })
		return
	end
	if not limiter:allow(player, "ShopWrite") then
		send(player, { kind = "failed", text = REASON_TEXT.slow })
		return
	end
	local got: { gun: string, line: string }? = nil
	local ok, why = PlayerDataService.transact(player, PlayerDataService.newTxId(), function(data)
		got = nil
		local d = data.daily
		local p = d.picks[slot]
		if d.day ~= Economy.day(os.time()) or not p then
			return false, "expired"
		end
		if table.find(d.bought, slot) then
			return false, "bought"
		end
		if PlayerData.owns(data.skins, p.gun, p.line) then
			return false, "owned"
		end
		local price = DailyRoll.price(p)
		if not price then
			return false, "robux"
		end
		if data.coins < price then
			return false, "coins"
		end
		data.coins -= price
		PlayerData.grantSkin(data, p.gun, p.line)
		table.insert(d.bought, slot)
		got = { gun = p.gun, line = p.line }
		return true
	end)
	local g = got
	if ok and g then
		Telemetry.event(player, "Daily skin purchased", 1)
		send(player, {
			kind = "skin",
			gun = g.gun,
			line = g.line,
			text = SkinCases.name(g.gun, g.line),
		})
	elseif not ok then
		send(player, { kind = "failed", text = REASON_TEXT[why or ""] or "Purchase failed" })
	end
end

-- The one free daily skin (owner 2026-11-22: once per player, ever): the first coin-priced
-- pick of today's list they don't own (Shared/DailyShop.freeSlot), claimed in one write.
local function claimFree(player: Player, slot: number)
	if not limiter:allow(player, "ShopWrite") then
		send(player, { kind = "failed", text = REASON_TEXT.slow })
		return
	end
	local got: { gun: string, line: string }? = nil
	local ok, why = PlayerDataService.transact(player, PlayerDataService.newTxId(), function(data)
		got = nil
		if data.buys.free then
			return false, "freeUsed"
		end
		local d = data.daily
		if d.day ~= Economy.day(os.time()) then
			return false, "expired"
		end
		local free = DailyShop.freeSlot(d, function(gun, line)
			return PlayerData.owns(data.skins, gun, line)
		end, function(p)
			return (DailyRoll.price(p)) ~= nil
		end)
		if free ~= slot then
			return false, "expired"
		end
		local p = d.picks[slot]
		PlayerData.grantSkin(data, p.gun, p.line)
		table.insert(d.bought, slot)
		data.buys.free = true
		got = { gun = p.gun, line = p.line }
		return true
	end)
	local g = got
	if ok and g then
		Telemetry.event(player, "Free daily skin claimed", 1)
		send(player, {
			kind = "free",
			gun = g.gun,
			line = g.line,
			text = SkinCases.name(g.gun, g.line),
		})
	elseif not ok then
		send(player, { kind = "failed", text = REASON_TEXT[why or ""] or "Couldn't claim it" })
	end
end

-- Studio only: own every skin that exists here (Locker testing).
local function devSkins(player: Player)
	if not RunService:IsStudio() then
		reject("devOutsideStudio")
		return
	end
	if not limiter:allow(player, "ShopWrite") then
		send(player, { kind = "failed", text = REASON_TEXT.slow })
		return
	end
	local ok = PlayerDataService.transact(player, PlayerDataService.newTxId(), function(data)
		for gun in Weapons.list do
			for _, line in Locker.linesFor(gun) do
				if line ~= "Stock" then
					PlayerData.grantSkin(data, gun, line)
				end
			end
		end
		return true
	end)
	send(
		player,
		if ok
			then { kind = "coins", text = "Every skin unlocked (Studio)" }
			else {
				kind = "failed",
				text = "Couldn't unlock skins",
			}
	)
end

local function devCoins(player: Player)
	if not RunService:IsStudio() then
		reject("devOutsideStudio")
		return
	end
	if not limiter:allow(player, "ShopWrite") then
		send(player, { kind = "failed", text = REASON_TEXT.slow })
		return
	end
	local grant = Inventory.STUDIO_GRANT
	local ok, why = PlayerDataService.transact(player, PlayerDataService.newTxId(), function(data)
		data.coins = math.min(data.coins + grant, Inventory.MAX_COINS)
		return true
	end)
	send(
		player,
		if ok
			then { kind = "coins", text = `+{grant} coins (Studio)` }
			else {
				kind = "failed",
				text = REASON_TEXT[why or ""] or "Couldn't add coins",
			}
	)
end

local function onRequest(
	player: Player,
	action: unknown,
	arg: unknown,
	count: unknown,
	requestId: unknown
)
	if not limiter:allow(player, "ShopRequest") then
		reject("rate")
		return
	end
	if PlayZone.get(player) ~= "Lobby" then
		reject("notLobby")
		return
	end
	if typeof(action) ~= "string" then
		reject("badAction")
		return
	end
	if action == "visit" then
		if not shopVisits[player] then
			shopVisits[player] = true
			Telemetry.event(
				player,
				"Shop opened",
				1,
				if arg == "Display" then "Display" else "Menu"
			)
		end
	elseif action == "buyCase" then
		if typeof(arg) ~= "string" or #arg > 24 then
			reject("badArgs")
			return
		end
		buyCase(player, arg :: string)
	elseif action == "buyPack" then
		if arg ~= 1 and arg ~= Inventory.BATCH_OPEN_COUNT then
			reject("badCount")
			return
		end
		if count ~= "coins" and count ~= "tickets" then
			reject("badArgs")
			return
		end
		buyPowerPack(player, arg :: number, count :: string)
	elseif action == "openCase" then
		if typeof(arg) ~= "string" or #arg > 32 then
			reject("badArgs")
			return
		end
		local amount = if count == nil then 1 else count
		if amount ~= 1 and amount ~= Inventory.BATCH_OPEN_COUNT then
			reject("badCount")
			return
		end
		if
			requestId ~= nil
			and (
				typeof(requestId) ~= "number"
				or requestId < 1
				or requestId > 2 ^ 31
				or requestId ~= math.floor(requestId)
			)
		then
			reject("badRequestId")
			return
		end
		openCase(player, arg :: string, amount :: number, requestId :: number?)
	elseif action == "buyDaily" then
		if
			typeof(arg) ~= "number"
			or arg ~= arg
			or arg ~= math.floor(arg)
			or arg < 1
			or arg > 16
		then
			reject("badArgs")
			return
		end
		buyDaily(player, arg :: number)
	elseif action == "claimFree" then
		if
			typeof(arg) ~= "number"
			or arg ~= arg
			or arg ~= math.floor(arg)
			or arg < 1
			or arg > 16
		then
			reject("badArgs")
			return
		end
		claimFree(player, arg :: number)
	elseif action == "devCoins" then
		devCoins(player)
	elseif action == "devSkins" then
		devSkins(player)
	else
		reject("badAction")
	end
end

function ShopService.init() end

function ShopService.start()
	shopEvent = LobbyNet.event("ShopEvent")
	caseShow = LobbyNet.event("CaseShow")
	LobbyNet.event("ShopRequest").OnServerEvent:Connect(onRequest)
	-- the daily shop: rolled when a player's data arrives, and after each UTC midnight
	PlayerDataService.changed:Connect(function(p: Player)
		task.spawn(ensureDaily, p)
	end)
	task.spawn(function()
		while true do
			task.wait(30)
			for _, p in Players:GetPlayers() do
				task.spawn(ensureDaily, p)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		limiter:forget(p)
		rolling[p] = nil
		shopVisits[p] = nil
	end)
	while true do
		task.wait(Config.rejectLogInterval)
		if next(rejects) then
			local parts = {}
			for reason, n in rejects do
				table.insert(parts, `{reason}={n}`)
			end
			warn(
				`[Shop] rejected ShopRequest in the last {Config.rejectLogInterval} s: {table.concat(
					parts,
					", "
				)}`
			)
			table.clear(rejects)
		end
	end
end

return ShopService
