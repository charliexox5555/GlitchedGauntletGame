--!strict
-- The player's wallet and inventory (vault/01 Design/Inventory and Crates.md),
-- saved in DataStore PlayerDataV1 (Shared/PlayerData has the shape).
--
-- Every change is one atomic UpdateAsync on the player's key that reads the
-- stored value, checks it (enough coins, room in the stack) and writes the
-- result. Nothing is held in memory and written later, so a crash, a teleport
-- or a second server can never save an old copy over a purchase (LihFolk:
-- DataStore Fundamentals; Data Loss Prevention and Recovery; Trading Systems
-- Without Duplication, "single-key write is atomic").
--
-- Each change carries a purchase id. The save remembers the last few ids, so a
-- write retried after an error that actually landed is not applied twice
-- (LihFolk: Purchase Data and Receipts, "grants must be idempotent").
--
-- The server publishes the result on the player (Shared/PlayerData.publish);
-- clients only read it. Other services call transact(); there is no remote here.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Inventory = require(ReplicatedStorage.Shared.Config.Inventory)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)

type Data = PlayerData.Data

-- A change to apply to a fresh copy of the stored data: edit `data` in place and
-- return true, or return false and a reason to write nothing. It may run more
-- than once (UpdateAsync retries it), so it must not touch anything else.
export type Change = (data: Data) -> (boolean, string?)

type Record = {
	data: Data?, -- the last loaded or written copy (nil until the load lands)
	busy: boolean, -- one change at a time per player
	settings: any, -- the save's raw `settings` field (SettingsService cleans it)
	settingsSeen: boolean, -- a load or a change has read the stored value
}

local PlayerDataService = {}

-- Fires (player) after a load or a change published new data (the Locker
-- re-filters equips when skins arrive or are granted).
local changedEvent = Instance.new("BindableEvent")
PlayerDataService.changed = changedEvent.Event

local store = DataStoreService:GetDataStore(PlayerData.STORE)
local records: { [Player]: Record } = {}
local inFlight = 0

local function retry<T>(what: string, fn: () -> T): (boolean, T?)
	local delay = 1
	for attempt = 1, 4 do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(`[PlayerData] {what} failed ({attempt}/4): {result}`)
		if attempt < 4 then
			task.wait(delay)
			delay *= 2
		end
	end
	return false, nil
end

-- A copy of the player's current data, or nil while it hasn't loaded.
function PlayerDataService.get(player: Player): Data?
	local rec = records[player]
	return if rec and rec.data then table.clone(rec.data) else nil
end

function PlayerDataService.newTxId(): string
	return HttpService:GenerateGUID(false)
end

-- A no-write read of the stored value (UpdateAsync skips GetAsync's cache).
local function readFresh(userId: number): (boolean, any)
	local raw: any = nil
	local ok = retry("read " .. userId, function()
		return store:UpdateAsync(PlayerData.key(userId), function(old: any)
			raw = old
			return nil
		end)
	end)
	return ok, raw
end

-- One atomic change on a UserId's key (the player may be in this server or not).
-- Returns (ok, data written or already there, refused reason, the raw settings seen).
local function write(userId: number, txId: string, change: Change): (boolean, Data?, string?, any)
	local result: Data? = nil
	local refused: string? = nil
	local seenSettings: any = nil
	inFlight += 1
	local ok = retry("change " .. userId, function()
		return store:UpdateAsync(PlayerData.key(userId), function(old: any)
			-- runs again on every internal retry: reset what it reports
			result, refused = nil, nil
			seenSettings = if typeof(old) == "table" then old.settings else nil
			if PlayerData.newer(old) then
				refused = "update"
				return nil
			end
			-- keepUnknown: items and fields a newer build added survive this write
			local data = PlayerData.clean(old, true)
			if table.find(data.tx, txId) then
				result = data -- an earlier attempt already wrote this one
				return nil
			end
			local applied, why = change(data)
			if not applied then
				refused = why or "refused"
				result = data
				return nil -- write nothing
			end
			if not PlayerData.valid(data) then
				refused = "invalid" -- never save a clamped copy
				return nil
			end
			table.insert(data.tx, 1, txId)
			while #data.tx > Inventory.TX_MEMORY do
				table.remove(data.tx)
			end
			result = data
			local out: { [string]: any } = if typeof(old) == "table" then table.clone(old) else {}
			out.v, out.coins, out.items, out.tx, out.skins, out.prog =
				data.v, data.coins, data.items, data.tx, data.skins, data.prog
			out.tickets, out.login, out.daily, out.earn, out.buys =
				data.tickets, data.login, data.daily, data.earn, data.buys
			return out, { userId }
		end)
	end)

	if not ok then
		-- The last attempt may have landed before the error: look before
		-- telling the player to try again (a retry would be a second purchase).
		result, refused = nil, nil
		local read, raw = readFresh(userId)
		if read and not PlayerData.newer(raw) then
			local data = PlayerData.clean(raw, true)
			if table.find(data.tx, txId) then
				ok, result = true, data
			end
		end
	end
	inFlight -= 1
	return ok, result, refused, seenSettings
end

-- Applies one change atomically to the player's save and publishes the result.
-- Yields. Returns (true) when it was written (or had already been written under
-- this txId), else (false, reason): the change's own reason, "busy", "saving",
-- "update" (the save is from a newer build), "invalid".
-- `queue`: wait (up to QUEUE_WAIT s) for a change in flight instead of "busy"
-- (match results must not drop because a purchase was saving).
local QUEUE_WAIT = 20
function PlayerDataService.transact(
	player: Player,
	txId: string,
	change: Change,
	queue: boolean?
): (boolean, string?)
	local rec = records[player]
	if not rec then
		return false, "saving"
	end
	if rec.busy and queue then
		inFlight += 1 -- shutdown waits for queued changes too
		local t = os.clock()
		while rec.busy and records[player] == rec and os.clock() - t < QUEUE_WAIT do
			task.wait(0.2)
		end
		inFlight -= 1
	end
	if records[player] ~= rec then
		return false, "saving"
	end
	if rec.busy then
		return false, "busy"
	end
	rec.busy = true
	local ok, result, refused, seenSettings = write(player.UserId, txId, change)
	rec.busy = false
	if ok and result and records[player] == rec then
		if not rec.settingsSeen then
			rec.settings, rec.settingsSeen = seenSettings, true
		end
		rec.data = result
		PlayerData.publish(player, result)
		changedEvent:Fire(player)
	end
	if not ok then
		return false, "saving"
	end
	if refused then
		return false, refused
	end
	return true
end

-- The same change for someone who may have left this server (match results for a
-- leaver). Uses the live record when they're still here.
function PlayerDataService.transactUserId(
	userId: number,
	txId: string,
	change: Change
): (boolean, string?)
	local player = Players:GetPlayerByUserId(userId)
	if player and records[player] then
		local ok, why = PlayerDataService.transact(player, txId, change, true)
		if ok or why ~= "saving" or records[player] then
			return ok, why
		end
		-- they left while it waited: write by UserId (the txId makes a repeat safe)
	end
	local ok, _, refused = write(userId, txId, change)
	if not ok then
		return false, "saving"
	end
	if refused then
		return false, refused
	end
	return true
end

-- Settings (vault/02 Art/UI Settings.md, Lobby SettingsService): the save's
-- raw `settings` field once the load landed (loaded = false before that).
function PlayerDataService.loadedSettings(player: Player): (boolean, any)
	local rec = records[player]
	if not (rec and rec.settingsSeen) then
		return false, nil
	end
	return true, rec.settings
end

-- Merges `changes` (cleaned rows changed this session) into the stored
-- `settings` field in one UpdateAsync: other fields (coins, items, skins),
-- rows not changed here (maybe saved by a newer session) and rows a newer
-- build added all stay. A save made by a newer build is left alone and
-- reported as not written. Works by userId, so it also runs after the player
-- left. Yields.
function PlayerDataService.writeSettings(userId: number, changes: { [string]: any }): boolean
	inFlight += 1
	local skipped = false
	local ok = retry("settings " .. userId, function()
		return store:UpdateAsync(PlayerData.key(userId), function(old: any)
			skipped = false
			if PlayerData.newer(old) then
				skipped = true
				return nil
			end
			local out: { [string]: any }
			if typeof(old) == "table" then
				out = table.clone(old)
			else
				-- no save yet: start a full one (the starting coins too)
				local data = PlayerData.clean(nil)
				out = {
					v = data.v,
					coins = data.coins,
					items = data.items,
					tx = data.tx,
					skins = data.skins,
					tickets = data.tickets,
					login = data.login,
					daily = data.daily,
					earn = data.earn,
					buys = data.buys,
				}
			end
			local merged: { [string]: any } = if typeof(out.settings) == "table"
				then table.clone(out.settings)
				else {}
			for id, v in changes do
				merged[id] = v
			end
			out.settings = merged
			return out, { userId }
		end)
	end)
	inFlight -= 1
	return ok and not skipped
end

-- A write from the server the player just left (match results, a leaver's loss)
-- can land just after this server loaded them. One fresh read a little later
-- picks it up (Progression.md, save audit gap 4).
local REFRESH_AFTER = 12
local function refresh(player: Player, rec: Record)
	if records[player] ~= rec or rec.busy or not rec.data then
		return
	end
	local before = rec.data
	local ok, raw = readFresh(player.UserId)
	-- a change that landed while this read waited is newer: keep it
	if
		not ok
		or records[player] ~= rec
		or rec.busy
		or rec.data ~= before
		or PlayerData.newer(raw)
	then
		return
	end
	local fresh = PlayerData.clean(raw, true)
	if fresh.tx[1] ~= rec.data.tx[1] then
		rec.data = fresh
		PlayerData.publish(player, fresh)
		changedEvent:Fire(player)
	end
end

-- Loads with backoff until it lands or the player leaves (the Shop waits for
-- DataReady, so a failed load must not lock it for the whole session).
local function load(player: Player)
	local rec: Record = { data = nil, busy = false, settings = nil, settingsSeen = false }
	records[player] = rec
	PlayerData.publish(player, nil)
	local pause = 10
	while records[player] == rec and not rec.data do
		local ok, raw = retry("load " .. player.UserId, function()
			return store:GetAsync(PlayerData.key(player.UserId))
		end)
		if records[player] ~= rec or rec.data then
			return -- left while loading, or a change already published fresher data
		end
		if ok then
			rec.settings = if typeof(raw) == "table" then (raw :: any).settings else nil
			rec.settingsSeen = true
			rec.data = PlayerData.clean(raw, true)
			PlayerData.publish(player, rec.data)
			changedEvent:Fire(player)
			task.delay(REFRESH_AFTER, refresh, player, rec)
			return
		end
		task.wait(pause)
		pause = math.min(pause * 2, 120)
	end
end

function PlayerDataService.init() end

function PlayerDataService.start()
	Players.PlayerAdded:Connect(load)
	for _, p in Players:GetPlayers() do
		task.spawn(load, p)
	end
	Players.PlayerRemoving:Connect(function(p)
		-- nothing to save: every change was written when it happened
		records[p] = nil
	end)
	game:BindToClose(function()
		local t = os.clock()
		while inFlight > 0 and os.clock() - t < 25 do
			task.wait(0.1)
		end
	end)
end

return PlayerDataService
