--!strict
-- The Locker's equips (vault/02 Art/UI Locker.md): one skin line per gun,
-- saved so the Match puts it on your guns (Shared/Locker, read by the match's
-- SkinPreviewService). Every skin is free while testing; ownership comes with
-- the economy.
--
-- LockerRequest (client -> server): ("equip", gunId, line). Type-checked,
-- rate-limited, and only pairs whose skin model exists (Shared/Locker.valid).
-- The server publishes the equipped choices in LockerSkins; clients read it.
--
-- Saving (LihFolk: DataStore Fundamentals; Session Locking and Data Loss):
-- loaded once on join with retries; if the load fails the player can still
-- equip but nothing is written, so a failed read never overwrites saved data.
-- Changes save after a short debounce, on leave and on shutdown, through
-- UpdateAsync with retry and backoff.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Lobby.Config)
local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local Locker = require(ReplicatedStorage.Shared.Locker)
local RateLimit = require(ReplicatedStorage.Shared.Util.RateLimit)

local LockerService = {}

local SAVE_DELAY = 6 -- seconds after the last equip (Roblox: ~1 write per key per 6 s)
local MIN_GAP = 6 -- seconds between two writes of one player's key

type Record = {
	skins: { [string]: string },
	loaded: boolean, -- false: the load failed, so never save
	dirty: boolean,
	token: number,
	saving: boolean, -- one write at a time per player
	lastSave: number,
}

local store = DataStoreService:GetDataStore(Locker.STORE)
local records: { [Player]: Record } = {}
local limiter = RateLimit.new(Config.RATE)
local rejects: { [string]: number } = {}

local function reject(reason: string)
	rejects[reason] = (rejects[reason] or 0) + 1
end

local function retry<T>(what: string, fn: () -> T): (boolean, T?)
	local delay = 1
	for attempt = 1, 4 do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(`[Locker] {what} failed ({attempt}/4): {result}`)
		if attempt < 4 then
			task.wait(delay)
			delay *= 2
		end
	end
	return false, nil
end

-- One write at a time per player; it loops while new equips arrived during
-- a write. The write merges into what's stored (only this session's changes
-- replace their guns), so a pair this Lobby's synced copy doesn't know about
-- is never dropped from the save.
local function save(player: Player)
	local rec = records[player]
	if not rec or not rec.loaded or rec.saving then
		return
	end
	rec.saving = true
	while rec.dirty do
		local wait = MIN_GAP - (os.clock() - rec.lastSave)
		if wait > 0 then
			task.wait(wait)
		end
		rec.dirty = false
		local changes = table.clone(rec.skins)
		local ok = retry("save " .. player.UserId, function()
			return store:UpdateAsync(Locker.key(player.UserId), function(old: any)
				local skins = if typeof(old) == "table" and typeof(old.skins) == "table"
					then table.clone(old.skins)
					else {}
				for gunId, line in changes do
					skins[gunId] = line
				end
				return { v = Locker.VERSION, skins = skins }
			end)
		end)
		rec.lastSave = os.clock()
		if not ok then
			rec.dirty = true -- try again on the next change or on leave
			break
		end
	end
	rec.saving = false
end

-- Saves now (no debounce): MATCH FOUND calls this so the write lands before
-- the teleport and the match reads the new skins.
function LockerService.flush(player: Player)
	task.spawn(save, player)
end

local function load(player: Player)
	local rec: Record =
		{ skins = {}, loaded = false, dirty = false, token = 0, saving = false, lastSave = 0 }
	records[player] = rec
	local ok, data = retry("load " .. player.UserId, function()
		return store:GetAsync(Locker.key(player.UserId))
	end)
	if records[player] ~= rec then
		return -- left while loading
	end
	if ok then
		rec.loaded = true
		for gunId, line in Locker.clean(data) do
			-- an equip made while loading wins over the saved value
			if rec.skins[gunId] == nil then
				rec.skins[gunId] = line
			end
		end
	end
	Locker.publish(player, rec.skins)
end

local function equip(player: Player, gunId: string, line: string)
	local rec = records[player]
	if not rec or rec.skins[gunId] == line then
		return
	end
	rec.skins[gunId] = line
	Locker.publish(player, rec.skins)
	rec.dirty = true
	rec.token += 1
	local token = rec.token
	task.delay(SAVE_DELAY, function()
		if records[player] == rec and rec.token == token then
			save(player)
		end
	end)
end

local function onRequest(player: Player, action: unknown, gunId: unknown, line: unknown)
	if not limiter:allow(player, "LockerRequest") then
		reject("rate")
		return
	end
	if typeof(action) ~= "string" or action ~= "equip" then
		reject("badAction")
		return
	end
	if typeof(gunId) ~= "string" or typeof(line) ~= "string" or #gunId > 24 or #line > 32 then
		reject("badArgs")
		return
	end
	if not Locker.valid(gunId, line) then -- a real gun, a known line, a ready model
		reject("badPair")
		return
	end
	equip(player, gunId :: string, line :: string)
end

function LockerService.init() end

function LockerService.start()
	LobbyNet.event("LockerRequest").OnServerEvent:Connect(onRequest)
	Players.PlayerAdded:Connect(load)
	for _, p in Players:GetPlayers() do
		task.spawn(load, p)
	end
	Players.PlayerRemoving:Connect(function(p)
		local rec = records[p]
		limiter:forget(p)
		if rec then
			save(p) -- returns at once if a write is already running; it finishes on its own
			while rec.saving do
				task.wait(0.1)
			end
		end
		records[p] = nil
	end)
	game:BindToClose(function()
		for p in records do
			task.spawn(save, p)
		end
		-- wait for every write in flight (including ones already running)
		local t = os.clock()
		while os.clock() - t < 25 do
			local busy = false
			for _, rec in records do
				if rec.saving or (rec.loaded and rec.dirty) then
					busy = true
				end
			end
			if not busy then
				break
			end
			task.wait(0.1)
		end
	end)
	while true do
		task.wait(Config.rejectLogInterval)
		if next(rejects) then
			local parts = {}
			for reason, n in rejects do
				table.insert(parts, `{reason}={n}`)
			end
			warn(
				`[Locker] rejected LockerRequest in the last {Config.rejectLogInterval} s: {table.concat(
					parts,
					", "
				)}`
			)
			table.clear(rejects)
		end
	end
end

return LockerService
