--!strict
-- Buying from the Shop (vault/01 Design/Inventory and Crates.md, Shop Economy and Art v1.md).
-- Cases cost Tickets (earn-only, Config/Economy.CASE_TICKETS) and go into the inventory
-- unopened; the player's own daily shop sells Common / Rare skins for coins. Robux
-- purchases (developer products, ProcessReceipt) come next.
--
-- ShopRequest (client -> server):
--   ("buyCase", caseId)  pay the case's Ticket price, +1 of its inventory item
--   ("buyDaily", slot)   buy slot 1..8 of the player's saved daily shop (coin tiers)
--   ("openCase", itemId) use one held case: roll a skin you don't own from its
--                        tier odds (Shared/SkinCases), grant it, -1 case
--   ("devCoins")         Studio only: + Inventory.STUDIO_GRANT coins
--   ("devSkins")         Studio only: own every skin (testing the Locker)
-- ShopEvent (server -> that client): ShopEventPayload in LobbyNet.
--
-- The client sends only what it wants; the price, the item and the balance
-- check all come from the server's own tables and the stored save, inside one
-- atomic write (PlayerDataService.transact). Type-checked and rate-limited.
-- Cases are bought only with Tickets, which are earned and never sold for Robux, so a
-- case is not a paid random item (LihFolk: Paid Random Items and Odds Disclosure) and
-- needs no PolicyService gate. A case inside a Robux pack will be gated where it's granted.
-- The daily shop is rolled here (Shared/DailyRoll) at the player's first data of the UTC
-- day, and again for anyone still online after midnight, and saved before it's shown.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Lobby.Config)
local Inventory = require(ReplicatedStorage.Shared.Config.Inventory)
local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local RateLimit = require(ReplicatedStorage.Shared.Util.RateLimit)
local ShopCatalog = require(ReplicatedStorage.Lobby.ShopCatalog)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local SkinCases = require(ReplicatedStorage.Shared.SkinCases)
local Locker = require(ReplicatedStorage.Shared.Locker)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local DailyRoll = require(ReplicatedStorage.Shared.DailyRoll)
local PlayerDataService = require(script.Parent.PlayerDataService)

local ShopService = {}

local limiter = RateLimit.new(Config.RATE)
local rejects: { [string]: number } = {}
local shopEvent: RemoteEvent
local caseShow: RemoteEvent

local REASON_TEXT: { [string]: string } = {
	coins = "Not enough coins",
	tickets = "Not enough Tickets",
	expired = "The daily shop just changed, take another look",
	bought = "You already bought that one",
	owned = "You already own that skin",
	robux = "Robux purchases are coming soon",
	full = "Your Backpack can't hold more of those",
	busy = "Still finishing your last purchase",
	saving = "Couldn't reach your save, try again",
	update = "The game updated, rejoin to keep buying",
	invalid = "Purchase failed",
	slow = "Slow down a little",
	noCase = "You don't have that case",
	ownAll = "You already own everything that case can give",
}

local function reject(reason: string)
	rejects[reason] = (rejects[reason] or 0) + 1
end

local function send(player: Player, payload: LobbyNet.ShopEventPayload)
	if player.Parent then
		shopEvent:FireClient(player, payload)
	end
end

-- How many skins this case can still give a player who owns `skins`.
local function unownedIn(caseId: string, skins: PlayerData.Skins): number
	local n = 0
	for _, list in SkinCases.pool(caseId) do
		for _, p in list do
			if not PlayerData.owns(skins, p.gun, p.line) then
				n += 1
			end
		end
	end
	return n
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
	if known and unownedIn(caseId, known.skins) <= (known.items[def.id] or 0) then
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
		if unownedIn(caseId, data.skins) <= held then
			return false, "ownAll"
		end
		data.tickets -= price
		data.items[def.id] = held + 1
		return true
	end)
	if ok then
		send(player, { kind = "bought", item = def.id, count = 1, text = def.name })
	else
		send(player, { kind = "failed", text = REASON_TEXT[why or ""] or "Purchase failed" })
	end
end

-- One opening. The roll runs inside the save write on the stored data, with a
-- seed fixed for this purchase id, so a retried write rolls the same skin and a
-- second server can't double-spend the case.
local function openCase(player: Player, itemId: string)
	local def = Inventory.ITEMS[itemId]
	local caseId = if def and def.kind == "Case" then def.case else nil
	if not def or not caseId then
		reject("badItem")
		return
	end
	-- cheap refusals from the loaded copy (the real checks are in the write)
	local known = PlayerDataService.get(player)
	if known and (known.items[itemId] or 0) < 1 then
		send(player, { kind = "failed", text = REASON_TEXT.noCase })
		return
	end
	if not limiter:allow(player, "ShopWrite") then
		send(player, { kind = "failed", text = REASON_TEXT.slow })
		return
	end
	local seed = Random.new():NextInteger(1, 2 ^ 30)
	-- nothing left to give (the case pools overlap, so a held case can run dry):
	-- the case is traded back for its Ticket price in the same write
	local refund = Economy.CASE_TICKETS[caseId] or 0
	local got: SkinCases.Pair? = nil
	local refunded = false
	local ok, why = PlayerDataService.transact(player, PlayerDataService.newTxId(), function(data)
		got, refunded = nil, false
		local held = data.items[itemId] or 0
		if held < 1 then
			return false, "noCase"
		end
		data.items[itemId] = if held > 1 then held - 1 else nil
		local pair = SkinCases.roll(caseId, data.skins, Random.new(seed))
		if not pair then
			data.tickets = math.min(data.tickets + refund, Economy.MAX_TICKETS)
			refunded = true
			return true
		end
		PlayerData.grantSkin(data, pair.gun, pair.line)
		got = pair
		return true
	end)
	if not ok then
		send(player, { kind = "failed", text = REASON_TEXT[why or ""] or "Couldn't open it" })
		return
	end
	if refunded then
		send(player, {
			kind = "refunded",
			item = itemId,
			count = refund,
			text = `You own everything in it: {refund} Ticket{if refund == 1 then "" else "s"} back`,
		})
		return
	end
	local pair = got
	-- everyone else in the lobby sees it open at this player (Controllers/CaseShowController)
	if pair then
		local show: LobbyNet.CaseShowPayload = {
			userId = player.UserId,
			crate = def.tier,
			gun = pair.gun,
			line = pair.line,
			tier = pair.tier,
			text = SkinCases.name(pair.gun, pair.line),
		}
		for _, other in Players:GetPlayers() do
			if other ~= player then
				caseShow:FireClient(other, show)
			end
		end
	end
	send(player, {
		kind = "opened",
		item = itemId,
		gun = if pair then pair.gun else nil,
		line = if pair then pair.line else nil,
		tier = if pair then pair.tier else nil,
		text = if pair then SkinCases.name(pair.gun, pair.line) else "A new skin is in your Locker",
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

local function onRequest(player: Player, action: unknown, arg: unknown)
	if not limiter:allow(player, "ShopRequest") then
		reject("rate")
		return
	end
	if typeof(action) ~= "string" then
		reject("badAction")
		return
	end
	if action == "buyCase" then
		if typeof(arg) ~= "string" or #arg > 24 then
			reject("badArgs")
			return
		end
		buyCase(player, arg :: string)
	elseif action == "openCase" then
		if typeof(arg) ~= "string" or #arg > 32 then
			reject("badArgs")
			return
		end
		openCase(player, arg :: string)
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
