--!strict
-- The player's saved wallet and inventory (vault/01 Design/Inventory and
-- Crates.md). One DataStore key per player in STORE:
--   { v = 1, coins = number, items = { [itemId] = count }, tx = { purchaseId },
--     skins = { [gunId] = { line, ... } },   owned skin lines per gun ("Stock" is always
--                                            owned and never stored; 2026-11-20)
--     prog = Shared/Progress (level, XP, win streak, lost-streak offer; 2026-11-22),
--     tickets = number (earn-only case currency, Config/Economy; 2026-11-22),
--     login = Shared/LoginRewards { last = UTC day, step } (2026-11-22),
--     daily = Shared/DailyShop { day, picks = { { gun, line } }, bought = { slot } },
--     earn = { day = UTC day, coins = match coins earned that day } (2026-11-22),
--     onb = Shared/Onboarding { fav, favDone, seen } (new-player flow; 2026-11-22),
--     tasks = Shared/TaskPath { set, part, n, seen, title } (the task Path; 2026-11-26),
--     buys = { starter = bool (Starter Bundle bought), free = bool (the one free daily
--              skin used), intents = { [productId] = { product, gun, line, slot?, at } }
--              (the skin each shared "skin" product pays for, saved before its prompt;
--              slot = its daily shop slot), receipts = { PurchaseId } (the last 100
--              Robux receipts granted, apart from `tx`; 2026-11-22) } }
-- Older saves have no `prog`: it starts at level 1 with no streak (no version bump:
-- every write keeps the fields it doesn't know, so older servers never drop it).
-- Written only by the Lobby's PlayerDataService, one UpdateAsync per change.
--
-- Both sides read it from the player:
--   StateValues "Coins"  the balance (the Shop's counter already reads it)
--   StringValue "Inventory"  JSON { [itemId] = count }
--   StateValues "DataReady"  true once the save loaded (buying waits for it)
--   StringValue "Skins"  JSON { [gunId] = { line } }, the owned skins (Locker, Backpack)
--   StateValues "Level", "XpShare" (0..1), "Xp", "XpNeed", "WinStreak", "BestStreak",
--               "Matches", "Wins", "Kills" (the profile card)
--   StateValues "StreakSaveValue", "StreakSaveEnds" (os.time), "StreakSavePrice": the
--               live lost-streak offer (0 / nil when there is none)
--   StateValues "Tickets" the Ticket balance; "LoginLast", "LoginStep" the login board
--   StringValue "DailyShop"  JSON of `daily` (the player's own daily shop)
--   StateValues "FreeDailyUsed", "StarterBought" (buys.free, buys.starter)
--   StateValues "OnbFav", "OnbFavDone", "OnbSeen" (onb: favorite asks, NEW pops seen)
--   StringValue "Tasks"  JSON of `tasks` (the task Path panel)

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Inventory = require(ReplicatedStorage.Shared.Config.Inventory)
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local HealthLog = require(ReplicatedStorage.Shared.HealthLog)
local Progress = require(ReplicatedStorage.Shared.Progress)
local ProgressionConfig = require(ReplicatedStorage.Shared.Config.Progression)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local LoginRewards = require(ReplicatedStorage.Shared.LoginRewards)
local DailyShop = require(ReplicatedStorage.Shared.DailyShop)
local Onboarding = require(ReplicatedStorage.Shared.Onboarding)
local ModLoadout = require(ReplicatedStorage.Shared.ModLoadout)
local TaskPath = require(ReplicatedStorage.Shared.TaskPath)

export type Items = { [string]: number }
export type Skins = { [string]: { string } }
export type Data = {
	v: number,
	coins: number,
	items: Items,
	tx: { string },
	skins: Skins,
	mods: ModLoadout.Loadout,
	prog: Progress.Prog,
	tickets: number,
	login: LoginRewards.Login,
	daily: DailyShop.Daily,
	earn: { day: number, coins: number },
	buys: Buys,
	onb: Onboarding.Onb,
	tasks: TaskPath.State,
}
-- `intent`: the skin a shared skin product pays for (Services/RobuxService)
export type Intent = {
	product: number,
	gun: string,
	line: string,
	slot: number?,
	at: number,
	token: string?,
}
export type Buys = {
	starter: boolean,
	free: boolean,
	intents: { [string]: Intent },
	receipts: { string },
}

local PlayerData = {}

-- How many Robux receipt ids `buys.receipts` keeps (Services/RobuxService).
PlayerData.RECEIPT_MEMORY = 100

-- Studio play (API access on) saves to its own store, so test coins and test
-- purchases never land in a live save.
-- Owner 2026-11-22: "reset all player data" = new store names (V1 -> V2). The V1 stores are left as
-- they were, so switching these names back restores every old save.
PlayerData.STORE = if RunService:IsStudio() then "PlayerDataV2_Studio" else "PlayerDataV2"
PlayerData.VERSION = 1
PlayerData.REPLICA = "Inventory"
PlayerData.SKINS = "Skins"
PlayerData.MODS = "LockerMods"
PlayerData.DAILY = "DailyShop"
PlayerData.TASKS = "Tasks"
local MAX_LINES_PER_GUN = 64

function PlayerData.key(userId: number): string
	return "u_" .. tostring(userId)
end

local function count(n: unknown, max: number): number?
	if typeof(n) ~= "number" or n ~= n or n == math.huge or n == -math.huge then
		return nil
	end
	return math.clamp(math.floor(n), 0, max)
end

local UNKNOWN_CAP = 1_000_000 -- an item a newer build added: kept, never shown

-- True when the stored value was written by a newer build (this server must
-- not write it: it could drop what it doesn't understand).
function PlayerData.newer(raw: unknown): boolean
	if typeof(raw) ~= "table" then
		return false
	end
	local v = (raw :: { [string]: unknown }).v
	return typeof(v) == "number" and v > PlayerData.VERSION
end

function PlayerData.cleanBuys(raw: unknown): Buys
	local out: Buys = { starter = false, free = false, intents = {}, receipts = {} }
	if typeof(raw) ~= "table" then
		return out
	end
	local t = raw :: { [string]: any }
	out.starter = t.starter == true
	out.free = t.free == true
	if typeof(t.intents) == "table" then
		local n = 0
		for key, i in t.intents do
			if n >= 8 or typeof(key) ~= "string" or #key > 20 or typeof(i) ~= "table" then
				continue
			end
			local product, at = count(i.product, 1e12), count(i.at, 1e10)
			local slot = if i.slot ~= nil then count(i.slot, 16) else nil
			local gun = if typeof(i.gun) == "string" and #i.gun <= 24 then i.gun else nil
			local line = if typeof(i.line) == "string" and #i.line <= 32 then i.line else nil
			local token = if typeof(i.token) == "string" and #i.token <= 64 then i.token else nil
			if product and at and gun and line and tostring(product) == key then
				out.intents[key] = {
					product = product,
					at = at,
					gun = gun,
					line = line,
					slot = slot,
					token = token,
				}
				n += 1
			end
		end
	end
	if typeof(t.receipts) == "table" then
		for _, id in t.receipts do
			if
				typeof(id) == "string"
				and #id <= 64
				and #out.receipts < PlayerData.RECEIPT_MEMORY
			then
				table.insert(out.receipts, id)
			end
		end
	end
	return out
end

-- Any stored value (nil, an old version, a hand edit) to a valid Data. A new
-- player (nil) starts with STARTING_COINS. Bad counts drop. Item ids this
-- build doesn't know drop too, unless keepUnknown (the save path keeps them,
-- so an older server never deletes a newer item).
function PlayerData.clean(raw: unknown, keepUnknown: boolean?): Data
	local data: Data = {
		v = PlayerData.VERSION,
		coins = Inventory.STARTING_COINS,
		items = {},
		tx = {},
		skins = {},
		mods = ModLoadout.clean(nil),
		prog = Progress.new(),
		tickets = Economy.STARTING_TICKETS,
		login = LoginRewards.new(),
		daily = DailyShop.new(),
		earn = { day = 0, coins = 0 },
		buys = { starter = false, free = false, intents = {}, receipts = {} },
		onb = Onboarding.new(),
		tasks = TaskPath.new(),
	}
	if typeof(raw) ~= "table" then
		data.onb.analytics = if raw == nil then true else nil
		return data
	end
	data.prog = Progress.clean((raw :: any).prog)
	data.login = LoginRewards.clean((raw :: any).login)
	data.daily = DailyShop.clean((raw :: any).daily)
	data.buys = PlayerData.cleanBuys((raw :: any).buys)
	data.onb = Onboarding.clean((raw :: any).onb)
	data.tasks = TaskPath.clean((raw :: any).tasks)
	local earn = (raw :: any).earn
	if typeof(earn) == "table" then
		local day, got = count(earn.day, 1e7), count(earn.coins, Inventory.MAX_COINS)
		if day and got then
			data.earn = { day = day, coins = got }
		end
	end
	-- a save from before Tickets existed gets the starting Tickets too
	data.tickets = if (raw :: any).tickets == nil
		then Economy.STARTING_TICKETS
		else count((raw :: any).tickets, Economy.MAX_TICKETS) or 0
	local t = raw :: { [string]: unknown }
	data.mods = ModLoadout.clean(t.mods)
	data.coins = count(t.coins, Inventory.MAX_COINS) or 0
	if typeof(t.items) == "table" then
		for id, n in t.items :: { [unknown]: unknown } do
			if typeof(id) ~= "string" or #id > 40 then
				continue
			end
			local def = Inventory.ITEMS[id]
			local c = if def
				then count(n, def.maxStack)
				elseif keepUnknown then count(n, UNKNOWN_CAP)
				else nil
			if c and c > 0 then
				data.items[id] = c
			end
		end
	end
	if typeof(t.skins) == "table" then
		for gunId, lines in t.skins :: { [unknown]: unknown } do
			if typeof(gunId) ~= "string" or #gunId > 24 or typeof(lines) ~= "table" then
				continue
			end
			local list: { string } = {}
			for _, line in lines :: { unknown } do
				if
					typeof(line) == "string"
					and #line <= 32
					and line ~= "Stock"
					and not table.find(list, line)
					and #list < MAX_LINES_PER_GUN
				then
					table.insert(list, line)
				end
			end
			if #list > 0 then
				data.skins[gunId] = list
			end
		end
	end
	if typeof(t.tx) == "table" then
		for _, id in t.tx :: { unknown } do
			if typeof(id) == "string" and #id <= 64 and #data.tx < Inventory.TX_MEMORY then
				table.insert(data.tx, id)
			end
		end
	end
	return data
end

local function whole(n: unknown, max: number): boolean
	return typeof(n) == "number" and n == math.floor(n) and n >= 0 and n <= max
end

-- After a change: every number whole and in range. A change that breaks this
-- is refused, never saved clamped.
function PlayerData.valid(data: Data): boolean
	if
		not whole(data.coins, Inventory.MAX_COINS) or not whole(data.tickets, Economy.MAX_TICKETS)
	then
		return false
	end
	if
		not LoginRewards.valid(data.login)
		or not DailyShop.valid(data.daily)
		or not Onboarding.valid(data.onb)
		or not TaskPath.valid(data.tasks)
	then
		return false
	end
	if not whole(data.earn.day, 1e7) or not whole(data.earn.coins, Inventory.MAX_COINS) then
		return false
	end
	for id, n in data.items do
		local def = Inventory.ITEMS[id]
		if not whole(n, if def then def.maxStack else UNKNOWN_CAP) then
			return false
		end
	end
	for _, list in data.skins do
		if #list > MAX_LINES_PER_GUN then
			return false
		end
	end
	local p = data.prog
	if
		not whole(p.level, ProgressionConfig.MAX_LEVEL)
		or p.level < 1
		or not whole(p.xp, ProgressionConfig.xpToNext(p.level) - 1)
		or not whole(p.streak, ProgressionConfig.STREAK.max)
		or not whole(p.best, ProgressionConfig.STREAK.max)
	then
		return false
	end
	return true
end

-- Owned skins. "Stock" is always owned.
function PlayerData.owns(skins: Skins, gunId: string, line: string): boolean
	if line == "Stock" then
		return true
	end
	local list = skins[gunId]
	return list ~= nil and table.find(list, line) ~= nil
end

-- Adds a line to a gun's owned list (inside a PlayerDataService change).
-- Returns false if it was already owned.
function PlayerData.grantSkin(data: Data, gunId: string, line: string): boolean
	if PlayerData.owns(data.skins, gunId, line) then
		return false
	end
	local list = data.skins[gunId] or {}
	table.insert(list, line)
	data.skins[gunId] = list
	return true
end

local function setJson(player: Player, name: string, value: any)
	local encoded = HttpService:JSONEncode(value)
	local v = player:FindFirstChild(name)
	if v and v:IsA("StringValue") then
		v.Value = encoded
		return
	end
	local replica = Instance.new("StringValue")
	replica.Name = name
	replica.Value = encoded
	replica.Parent = player
end

-- Server: mirror a player's data onto them for every client to read (known
-- items only).
function PlayerData.publish(player: Player, data: Data?)
	StateValues.set(player, "Coins", if data then data.coins else 0)
	StateValues.set(player, "Tickets", if data then data.tickets else 0)
	StateValues.set(player, "LoginLast", if data then data.login.last else 0)
	StateValues.set(player, "LoginStep", if data then data.login.step else 0)
	StateValues.set(player, "FreeDailyUsed", if data then data.buys.free else true)
	StateValues.set(player, "StarterBought", if data then data.buys.starter else true)
	-- before data loads: as if every ask and pop is done (nothing pops on a missing save)
	StateValues.set(player, "OnbFav", if data then data.onb.fav else 0)
	StateValues.set(player, "OnbFavDone", if data then data.onb.favDone else true)
	StateValues.set(player, "OnbSeen", if data then data.onb.seen else 0)
	StateValues.set(player, "OnbCaseGift", if data then data.onb.caseGift == true else false)
	StateValues.set(player, "OnbCaseOpened", if data then data.onb.caseOpened == true else false)
	StateValues.set(
		player,
		"OnbSkinEquipped",
		if data then data.onb.skinEquipped == true else false
	)
	local was = StateValues.get(player, "DataReady") == true
	if data and not was then
		HealthLog.stage("data ready", player)
	elseif was and not data then
		HealthLog.problem("data lost", player)
	end
	StateValues.set(player, "DataReady", data ~= nil)
	PlayerData.publishProgress(player, if data then data.prog else nil)
	local shown: Items = {}
	if data then
		for id, n in data.items do
			if Inventory.ITEMS[id] and n > 0 then
				shown[id] = n
			end
		end
	end
	setJson(player, PlayerData.SKINS, if data then data.skins else {})
	setJson(player, PlayerData.MODS, if data then data.mods else {})
	setJson(player, PlayerData.DAILY, if data then data.daily else DailyShop.new())
	setJson(player, PlayerData.TASKS, if data then data.tasks else TaskPath.new())
	-- Inventory last: clients listen to it, and the skins must already be there
	setJson(player, PlayerData.REPLICA, shown)
end

-- Level, XP and streak onto the player (lobby list, profile, match tags read them).
function PlayerData.publishProgress(player: Player, prog: Progress.Prog?)
	local now = os.time()
	local p = prog or Progress.new()
	StateValues.set(player, "Level", p.level)
	StateValues.set(player, "Xp", p.xp)
	StateValues.set(player, "XpNeed", ProgressionConfig.xpToNext(p.level))
	StateValues.set(player, "XpShare", Progress.share(p))
	StateValues.set(player, "WinStreak", p.streak)
	StateValues.set(player, "BestStreak", p.best)
	StateValues.set(player, "Matches", p.matches)
	StateValues.set(player, "Wins", p.wins)
	StateValues.set(player, "Kills", p.kills)
	local offer = if prog then Progress.offer(p, now) else nil
	StateValues.set(player, "StreakSaveValue", if offer then offer.value else 0)
	StateValues.set(player, "StreakSaveEnds", if offer then offer.expires else 0)
	StateValues.set(player, "StreakSavePrice", if offer then Progress.price(p, now) else 0)
end

-- The published owned skins (empty until the save loads).
function PlayerData.skins(player: Player): Skins
	local value = player:FindFirstChild(PlayerData.SKINS)
	if not (value and value:IsA("StringValue")) or value.Value == "" then
		return {}
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, value.Value)
	if not ok then
		return {}
	end
	return PlayerData.clean({ coins = 0, skins = decoded }).skins
end

function PlayerData.mods(player: Player): ModLoadout.Loadout
	local value = player:FindFirstChild(PlayerData.MODS)
	if value and value:IsA("StringValue") then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, value.Value)
		if ok then
			return ModLoadout.clean(decoded)
		end
	end
	return ModLoadout.clean(nil)
end

-- The published daily shop (empty until the server rolls it).
function PlayerData.daily(player: Player): DailyShop.Daily
	local value = player:FindFirstChild(PlayerData.DAILY)
	if not (value and value:IsA("StringValue")) or value.Value == "" then
		return DailyShop.new()
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, value.Value)
	return if ok then DailyShop.clean(decoded) else DailyShop.new()
end

function PlayerData.coins(player: Player): number
	local v = StateValues.get(player, "Coins")
	return if typeof(v) == "number" and v == v then v else 0
end

function PlayerData.tickets(player: Player): number
	local v = StateValues.get(player, "Tickets")
	return if typeof(v) == "number" and v == v then v else 0
end

function PlayerData.ready(player: Player): boolean
	return StateValues.get(player, "DataReady") == true
end

-- The published inventory, only known items with a positive count.
function PlayerData.items(player: Player): Items
	local value = player:FindFirstChild(PlayerData.REPLICA)
	if not (value and value:IsA("StringValue")) or value.Value == "" then
		return {}
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, value.Value)
	if not ok then
		return {}
	end
	return PlayerData.clean({ coins = 0, items = decoded }).items
end

-- Client: the published inventory value, waiting for the server to create it
-- (nil after `timeout`). Listen to its Changed for inventory updates; coins
-- change through StateValues.changed(player, "Coins").
function PlayerData.replica(player: Player, timeout: number?): StringValue?
	local value = player:WaitForChild(PlayerData.REPLICA, timeout or 30)
	return if value and value:IsA("StringValue") then value else nil
end

return PlayerData
