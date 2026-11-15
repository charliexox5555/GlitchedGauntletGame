--!strict
-- The Locker's equips (vault/02 Art/UI Locker.md): one skin line per gun,
-- saved so the Match puts it on your guns (Shared/Locker, read by the match's
-- SkinPreviewService). Every skin is free while testing; ownership comes with
-- the economy.
--
-- LockerRequest (client -> server): ("equip", gunId, line). Type-checked,
-- rate-limited, and only pairs whose skin model exists (Shared/Locker.valid).
-- The server sets the Player attribute Skin_<gunId>; clients only read it.
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

local SAVE_DELAY = 3 -- seconds after the last equip

type Record = {
	skins: { [string]: string },
	loaded: boolean, -- false: the load failed, so never save
	dirty: boolean,
	token: number,
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

local function save(player: Player)
	local rec = records[player]
	if not rec or not rec.loaded or not rec.dirty then
		return
	end
	rec.dirty = false
	local skins = table.clone(rec.skins)
	local ok = retry("save " .. player.UserId, function()
		return store:UpdateAsync(Locker.key(player.UserId), function()
			return { v = Locker.VERSION, skins = skins }
		end)
	end)
	if not ok then
		rec.dirty = true -- try again on the next change or on leave
	end
end

local function load(player: Player)
	local rec: Record = { skins = {}, loaded = false, dirty = false, token = 0 }
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
				player:SetAttribute(Locker.attr(gunId), line)
			end
		end
	end
	player:SetAttribute("LockerLoaded", ok)
end

local function equip(player: Player, gunId: string, line: string)
	local rec = records[player]
	if not rec or rec.skins[gunId] == line then
		return
	end
	rec.skins[gunId] = line
	player:SetAttribute(Locker.attr(gunId), line)
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
		save(p)
		records[p] = nil
		limiter:forget(p)
	end)
	game:BindToClose(function()
		local waiting = 0
		for p in records do
			waiting += 1
			task.spawn(function()
				save(p)
				waiting -= 1
			end)
		end
		local t = os.clock()
		while waiting > 0 and os.clock() - t < 25 do
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
