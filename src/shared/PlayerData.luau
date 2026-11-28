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
--     earn = { day = UTC day, coins = match coins earned that day, win = the day's first-win bonus paid }
--            (2026-11-22; `win` 2026-11-27),
--     onb = Shared/Onboarding { fav, favDone, seen } (new-player flow; 2026-11-22),
--     tasks = Shared/TaskPath { set, part, n, seen, title } (the task Path; 2026-11-26),
--     season = Shared/SeasonPass { id, premium, tier, secs, rounds, free, prem, winDay }
--              (the season pass; 2026-11-26),
--     guns = Shared/GunLoadout { owned = { [gunId] = true }, primary, secondary } (the gun loadout:
--            owned guns and the pair taken into matches; 2026-11-26),
--     gunxp = Shared/GunLevels { [gunId] = total XP } (gun levels; 2026-11-27: a save without it is every
--             gun at level 1, no version bump, same as `prog`),
--     charms = { owned = { name }, on = name? }, titles = { owned = { text }, on = text? }
--              (pass cosmetics; `on` = equipped, wired in Build Plan phases 5 and 6; 2026-11-26),
--     buys = { starter = bool (Starter Bundle bought), free = bool (the one free daily
--              skin used), intents = { [productId] = { product, gun, line, slot?, at } }
--              (the skin each shared "skin" product pays for, saved before its prompt;
--              slot = its daily shop slot), receipts = { PurchaseId } (the last 100
--              Robux receipts granted, apart from `tx`; 2026-11-22), group = bool (the
--              one-time Free Rewards gift for joining the group, Services/GroupRewardService;
--              2026-11-28, inside VERSION 2: release 1 was not live yet) } }
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
--   StateValues "FreeDailyUsed", "StarterBought", "GroupRewardClaimed" (buys.free, buys.starter, buys.group)
--   StateValues "OnbFav", "OnbFavDone", "OnbSeen" (onb: favorite asks, NEW pops seen)
--   StringValue "Tasks"  JSON of `tasks` (the task Path panel)
--   StringValue "LockerGuns"  JSON of `guns` (the Locker, the match draft)
--   StringValue "GunXp"  JSON of `gunxp` (Shared/GunLevels.read: the Locker card, both sides' gun stats)

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
local GunLoadout = require(ReplicatedStorage.Shared.GunLoadout)
local GunLevels = require(ReplicatedStorage.Shared.GunLevels)
local TaskPath = require(ReplicatedStorage.Shared.TaskPath)
local SeasonPass = require(ReplicatedStorage.Shared.SeasonPass)
local CharmsConfig = require(ReplicatedStorage.Shared.Config.Charms)
local LoadoutConfig = require(ReplicatedStorage.Shared.Config.Loadout)

export type Items = { [string]: number }
export type Skins = { [string]: { string } }
-- Owned cosmetics with one equipped (titles): names, at most MAX_OWNED.
export type Owned = { owned: { string }, on: string? }
-- Weapon charms: copy counts per charmId (capped at active gun count) + equipped charmId per gun.
export type CharmSave = {
	owned: { [string]: number },
	guns: { [string]: string },
}
export type Data = {
	v: number,
	coins: number,
	items: Items,
	tx: { string },
	skins: Skins,
	mods: ModLoadout.Loadout,
	guns: GunLoadout.Loadout,
	gunxp: GunLevels.GunXp,
	prog: Progress.Prog,
	tickets: number,
	login: LoginRewards.Login,
	daily: DailyShop.Daily,
	earn: { day: number, coins: number, win: boolean? },
	buys: Buys,
	onb: Onboarding.Onb,
	tasks: TaskPath.State,
	season: SeasonPass.State,
	charms: CharmSave,
	titles: Owned,
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
	group: boolean,
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
-- Bump VERSION whenever ANY table's shape changes, nested ones too (data-safety review 2026-11-28):
-- a server on an older build then refuses to write the save (`newer`), instead of rebuilding the
-- nested tables it knows and dropping what the newer build added. 2 = release 1 (season pass, charms,
-- titles, guns, gun levels). On publish, also shut down the old servers.
PlayerData.VERSION = 2
PlayerData.REPLICA = "Inventory"
PlayerData.SKINS = "Skins"
PlayerData.MODS = "LockerMods"
PlayerData.GUNS = "LockerGuns"
PlayerData.DAILY = "DailyShop"
PlayerData.TASKS = "Tasks"
PlayerData.SEASON = "Season" -- the season pass state (Shared/SeasonPass), JSON
PlayerData.TITLES = "Titles" -- owned titles + the one on (JSON); the one on is also the "Title" state value
PlayerData.CHARMS = "LockerCharms" -- owned charm copies + equipped per gun (JSON)
local MAX_LINES_PER_GUN = 64
local MAX_OWNED = 64
local MAX_NAME = 40
local MAX_CHARM_COPIES = math.max(1, #LoadoutConfig.PRIMARIES + #LoadoutConfig.SECONDARIES)

local CHARM_GUNS: { [string]: boolean } = {}
for _, list in { LoadoutConfig.PRIMARIES, LoadoutConfig.SECONDARIES } do
	for _, gid in list do
		CHARM_GUNS[gid] = true
	end
end

local CHARM_NAME_TO_ID: { [string]: string } = {}
for id, def in CharmsConfig.DEFS do
	CHARM_NAME_TO_ID[string.upper(id)] = id
	CHARM_NAME_TO_ID[string.upper(def.name)] = id
end

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

function PlayerData.cleanOwned(raw: unknown): Owned
	local out: Owned = { owned = {} }
	if typeof(raw) ~= "table" then
		return out
	end
	local t = raw :: { [string]: unknown }
	if typeof(t.owned) == "table" then
		for _, name in t.owned :: { unknown } do
			if
				typeof(name) == "string"
				and #name > 0
				and #name <= MAX_NAME
				and not table.find(out.owned, name)
				and #out.owned < MAX_OWNED
			then
				table.insert(out.owned, name)
			end
		end
	end
	if typeof(t.on) == "string" and table.find(out.owned, t.on) then
		out.on = t.on
	end
	return out
end

-- Adds a title (inside a PlayerDataService change). False if already owned or full.
function PlayerData.grantOwned(o: Owned, name: string): boolean
	if #name == 0 or #name > MAX_NAME or table.find(o.owned, name) or #o.owned >= MAX_OWNED then
		return false
	end
	table.insert(o.owned, name)
	return true
end

function PlayerData.cleanCharms(raw: unknown): CharmSave
	local out: CharmSave = { owned = {}, guns = {} }
	if typeof(raw) ~= "table" then
		return out
	end
	local t = raw :: { [string]: unknown }
	if typeof(t.owned) == "table" then
		for k, v in t.owned :: { [unknown]: unknown } do
			if typeof(k) == "number" and typeof(v) == "string" then
				local id = CHARM_NAME_TO_ID[string.upper(v)]
				if id then
					out.owned[id] = math.max(out.owned[id] or 0, 1)
				end
			elseif typeof(k) == "string" and typeof(v) == "number" then
				local id = if CharmsConfig.exists(k) then k else CHARM_NAME_TO_ID[string.upper(k)]
				-- a charm this build doesn't know (added by a newer build, or retired): kept as it is,
				-- never shown or equipped, so an older server's write can't delete it
				if not id and #k <= MAX_NAME and string.match(k, "^[%w_]+$") then
					id = k
				end
				local n = count(v, MAX_CHARM_COPIES)
				if id and n and n > 0 then
					out.owned[id] = math.clamp(n, 1, MAX_CHARM_COPIES)
				end
			end
		end
	end
	local used: { [string]: number } = {}
	if typeof(t.guns) == "table" then
		for gunId, charmId in t.guns :: { [unknown]: unknown } do
			if
				typeof(gunId) == "string"
				and typeof(charmId) == "string"
				and CHARM_GUNS[gunId]
				and CharmsConfig.exists(charmId)
			then
				local cap = out.owned[charmId] or 0
				local cur = used[charmId] or 0
				if cur < cap then
					out.guns[gunId] = charmId
					used[charmId] = cur + 1
				end
			end
		end
	end
	return out
end

function PlayerData.charmCopies(charms: CharmSave, charmId: string): number
	local n = charms.owned[charmId]
	return if typeof(n) == "number" and n > 0 then math.floor(n) else 0
end

function PlayerData.equippedCharm(charms: CharmSave, gunId: string): string?
	local id = charms.guns[gunId]
	return if typeof(id) == "string" and id ~= "" then id else nil
end

function PlayerData.charmGuns(charms: CharmSave, charmId: string): { string }
	local list: { string } = {}
	for gunId, eq in charms.guns do
		if eq == charmId then
			table.insert(list, gunId)
		end
	end
	table.sort(list)
	return list
end

-- Grants one copy of `charmId` (up to active gun count). Returns (granted, duplicateCoins).
function PlayerData.grantCharm(data: Data, charmId: string): (boolean, number)
	local def = CharmsConfig.get(charmId)
	if not def then
		return false, 0
	end
	local cur = data.charms.owned[charmId] or 0
	if cur >= MAX_CHARM_COPIES then
		local coins = CharmsConfig.DUPLICATE_COINS[def.rarity] or 0
		return false, coins
	end
	data.charms.owned[charmId] = cur + 1
	return true, 0
end

-- Equips or unequips (`nil`) an owned charm onto `gunId`. Moves off another gun if all copies are allocated.
function PlayerData.setCharm(data: Data, gunId: string, charmId: string?): (boolean, string?)
	if not CHARM_GUNS[gunId] then
		return false, nil
	end
	if charmId == nil or charmId == "" then
		data.charms.guns[gunId] = nil
		return true, nil
	end
	local copies = PlayerData.charmCopies(data.charms, charmId)
	if copies <= 0 or not CharmsConfig.exists(charmId) then
		return false, nil
	end
	if data.charms.guns[gunId] == charmId then
		return true, nil
	end
	local used = PlayerData.charmGuns(data.charms, charmId)
	local movedFrom: string? = nil
	if #used >= copies then
		movedFrom = used[1]
		data.charms.guns[used[1]] = nil
	end
	data.charms.guns[gunId] = charmId
	return true, movedFrom
end

-- Gives a title (the pass, the Task Path's Champion). A new title goes on by itself only
-- when no title is on (vault/04 Tech/Battle Pass Build Plan.md, phase 5); otherwise the
-- client's toast points to the profile. False if it was already owned.
function PlayerData.grantTitle(data: Data, name: string): boolean
	if not PlayerData.grantOwned(data.titles, name) then
		return false
	end
	if data.titles.on == nil then
		data.titles.on = name
	end
	return true
end

-- Equips an owned title, or takes it off with nil. False if not owned.
function PlayerData.setTitle(data: Data, name: string?): boolean
	if name ~= nil and not table.find(data.titles.owned, name) then
		return false
	end
	data.titles.on = name
	return true
end

function PlayerData.cleanBuys(raw: unknown): Buys
	local out: Buys = { starter = false, free = false, group = false, intents = {}, receipts = {} }
	if typeof(raw) ~= "table" then
		return out
	end
	local t = raw :: { [string]: any }
	out.starter = t.starter == true
	out.free = t.free == true
	out.group = t.group == true
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
		guns = GunLoadout.clean(nil),
		gunxp = {},
		prog = Progress.new(),
		tickets = Economy.STARTING_TICKETS,
		login = LoginRewards.new(),
		daily = DailyShop.new(),
		earn = { day = 0, coins = 0 },
		buys = { starter = false, free = false, group = false, intents = {}, receipts = {} },
		onb = Onboarding.new(),
		tasks = TaskPath.new(),
		season = SeasonPass.new(),
		charms = { owned = {}, guns = {} },
		titles = { owned = {} },
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
	data.season = SeasonPass.clean((raw :: any).season)
	data.charms = PlayerData.cleanCharms((raw :: any).charms)
	data.titles = PlayerData.cleanOwned((raw :: any).titles)
	-- Champion was only kept in the Task Path before titles existed (2026-11-27): move it in
	if data.tasks.title then
		PlayerData.grantTitle(data, data.tasks.title)
	end
	local earn = (raw :: any).earn
	if typeof(earn) == "table" then
		local day, got = count(earn.day, 1e7), count(earn.coins, Inventory.MAX_COINS)
		if day and got then
			data.earn = { day = day, coins = got, win = if earn.win == true then true else nil }
		end
	end
	-- a save from before Tickets existed gets the starting Tickets too
	data.tickets = if (raw :: any).tickets == nil
		then Economy.STARTING_TICKETS
		else count((raw :: any).tickets, Economy.MAX_TICKETS) or 0
	local t = raw :: { [string]: unknown }
	data.mods = ModLoadout.clean(t.mods)
	data.guns = GunLoadout.clean(t.guns)
	data.gunxp = GunLevels.clean(t.gunxp)
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
		or not SeasonPass.valid(data.season)
		or not GunLevels.valid(data.gunxp)
		or #data.titles.owned > MAX_OWNED
	then
		return false
	end
	local charmUsed: { [string]: number } = {}
	for cid, n in data.charms.owned do
		if
			typeof(cid) ~= "string"
			or #cid > MAX_NAME
			or not whole(n, MAX_CHARM_COPIES)
			or n < 1
		then
			return false
		end
	end
	for gunId, cid in data.charms.guns do
		if not CHARM_GUNS[gunId] or not CharmsConfig.exists(cid) then
			return false
		end
		charmUsed[cid] = (charmUsed[cid] or 0) + 1
		if charmUsed[cid] > (data.charms.owned[cid] or 0) then
			return false
		end
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
	StateValues.set(player, "GroupRewardClaimed", if data then data.buys.group else true)
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
	setJson(player, PlayerData.GUNS, if data then data.guns else {})
	setJson(player, GunLevels.REPLICA, if data then data.gunxp else {})
	setJson(player, PlayerData.DAILY, if data then data.daily else DailyShop.new())
	setJson(player, PlayerData.TASKS, if data then data.tasks else TaskPath.new())
	setJson(player, PlayerData.SEASON, if data then data.season else SeasonPass.new())
	setJson(player, PlayerData.TITLES, if data then data.titles else { owned = {} })
	setJson(player, PlayerData.CHARMS, if data then data.charms else { owned = {}, guns = {} })
	StateValues.set(player, "Title", if data then data.titles.on or "" else "")
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

-- The published gun loadout (the starter pair until the save loads).
function PlayerData.guns(player: Player): GunLoadout.Loadout
	local value = player:FindFirstChild(PlayerData.GUNS)
	if value and value:IsA("StringValue") and value.Value ~= "" then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, value.Value)
		if ok then
			return GunLoadout.clean(decoded)
		end
	end
	return GunLoadout.clean(nil)
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

-- The published titles (owned + on), empty until the save loads.
function PlayerData.titles(player: Player): Owned
	local value = player:FindFirstChild(PlayerData.TITLES)
	if not (value and value:IsA("StringValue")) or value.Value == "" then
		return { owned = {} }
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, value.Value)
	return if ok then PlayerData.cleanOwned(decoded) else { owned = {} }
end

local charmCache: { [StringValue]: { encoded: string, data: CharmSave } } = setmetatable(
	{},
	{ __mode = "k" }
) :: any

function PlayerData.charms(player: Player): CharmSave
	local value = player:FindFirstChild(PlayerData.CHARMS)
	if not (value and value:IsA("StringValue")) or value.Value == "" then
		return { owned = {}, guns = {} }
	end
	local hit = charmCache[value]
	if hit and hit.encoded == value.Value then
		return hit.data
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, value.Value)
	local cleaned = if ok then PlayerData.cleanCharms(decoded) else { owned = {}, guns = {} }
	charmCache[value] = { encoded = value.Value, data = cleaned }
	return cleaned
end

-- Any player's equipped title as shown (upper case), or nil. Every client can read it.
function PlayerData.title(player: Player): string?
	local v = StateValues.get(player, "Title")
	return if typeof(v) == "string" and v ~= "" then string.upper(v) else nil
end

-- The published season pass state (a fresh one until the save loads).
function PlayerData.season(player: Player): SeasonPass.State
	local value = player:FindFirstChild(PlayerData.SEASON)
	if not (value and value:IsA("StringValue")) or value.Value == "" then
		return SeasonPass.new()
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, value.Value)
	return if ok then SeasonPass.clean(decoded) else SeasonPass.new()
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
