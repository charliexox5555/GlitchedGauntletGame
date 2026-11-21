--!strict
-- The player's settings (vault/02 Art/UI Settings.md): loaded with their save
-- (PlayerDataService, field `settings` of PlayerDataV1), published in the
-- player's "Settings" StringValue, changed by the Settings screen.
--
-- SettingsRequest (client -> server): ("save", values). Rate-limited, the
-- table's JSON size capped, then cleaned against Config/Settings by
-- Shared/PlayerSettings (unknown ids drop, numbers finite + clamped, choices
-- and key names from fixed lists), so a client can only ever store valid
-- values. Refused until the save has loaded, so defaults never overwrite a
-- real save. Only the rows changed this session are written, merged into the
-- stored field (a stale load or an older server can't wipe newer rows).
-- Written after SAVE_DELAY of quiet, at most once per SAVE_MIN_GAP (the key is
-- shared with purchases), and on leave and shutdown (LihFolk: DataStore
-- Fundamentals, ~1 write per key per 6 s; security review 2026-11-21).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Lobby.Config)
local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local PlayerSettings = require(ReplicatedStorage.Shared.PlayerSettings)
local RateLimit = require(ReplicatedStorage.Shared.Util.RateLimit)
local Settings = require(ReplicatedStorage.Shared.Config.Settings)
local PlayerDataService = require(script.Parent.PlayerDataService)

local SettingsService = {}

type Record = {
	values: PlayerSettings.Values,
	userId: number,
	changed: { [string]: boolean }, -- rows changed since the last write
	token: number,
	saving: boolean,
	lastWrite: number, -- os.clock() of the last write (0: none yet)
}

local records: { [Player]: Record } = {}
local pendingWrites = 0
local limiter = RateLimit.new(Config.RATE)
local rejects: { [string]: number } = {}

local function reject(reason: string)
	rejects[reason] = (rejects[reason] or 0) + 1
end

local function same(a: any, b: any): boolean
	if typeof(a) == "table" and typeof(b) == "table" then
		return PlayerSettings.encode(a) == PlayerSettings.encode(b)
	end
	return a == b
end

-- Writes the changed rows. One write at a time; a change that lands while
-- writing is picked up by a second pass. `now` (leave, shutdown) skips the
-- minimum gap.
local flush: (rec: Record, now: boolean?) -> ()
flush = function(rec: Record, now: boolean?)
	if rec.saving or next(rec.changed) == nil then
		return
	end
	local wait = rec.lastWrite + Settings.SAVE_MIN_GAP - os.clock()
	if not now and rec.lastWrite > 0 and wait > 0 then
		local token = rec.token
		task.delay(wait, function()
			if rec.token == token then
				flush(rec)
			end
		end)
		return
	end
	rec.saving = true
	pendingWrites += 1
	while next(rec.changed) ~= nil do
		local changes: { [string]: any } = {}
		for id in rec.changed do
			changes[id] = rec.values[id]
		end
		table.clear(rec.changed)
		rec.lastWrite = os.clock()
		if not PlayerDataService.writeSettings(rec.userId, changes) then
			for id in changes do -- try again on the next change / leave
				rec.changed[id] = true
			end
			break
		end
	end
	pendingWrites -= 1
	rec.saving = false
end

-- The save loaded (or a purchase read it first): publish the settings once.
local function onData(player: Player)
	if records[player] then
		return
	end
	local loaded, raw = PlayerDataService.loadedSettings(player)
	if not loaded or player.Parent ~= Players then
		return
	end
	local rec: Record = {
		values = PlayerSettings.clean(raw),
		userId = player.UserId,
		changed = {},
		token = 0,
		saving = false,
		lastWrite = 0,
	}
	records[player] = rec
	PlayerSettings.publish(player, rec.values)
end

local function onRequest(player: Player, action: unknown, values: unknown)
	if not limiter:allow(player, "SettingsRequest") then
		reject("rate")
		return
	end
	if typeof(action) ~= "string" or action ~= "save" or typeof(values) ~= "table" then
		reject("badArgs")
		return
	end
	local rec = records[player]
	if not rec then
		reject("notLoaded")
		return
	end
	-- size cap before cleaning (JSONEncode fails on mixed / cyclic tables)
	local ok, json = pcall(HttpService.JSONEncode, HttpService, values)
	if not ok or #json > Settings.MAX_BYTES then
		reject("size")
		return
	end
	local clean = PlayerSettings.clean(values)
	local any = false
	for id, v in clean do
		if not same(v, rec.values[id]) then
			rec.changed[id] = true
			any = true
		end
	end
	if not any then
		return
	end
	rec.values = clean
	PlayerSettings.publish(player, clean)
	rec.token += 1
	local token = rec.token
	task.delay(Settings.SAVE_DELAY, function()
		if rec.token == token then
			flush(rec)
		end
	end)
end

function SettingsService.init() end

function SettingsService.start()
	LobbyNet.event("SettingsRequest").OnServerEvent:Connect(onRequest)
	PlayerDataService.changed:Connect(onData)
	for _, p in Players:GetPlayers() do
		onData(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		limiter:forget(p)
		local rec = records[p]
		records[p] = nil
		if rec then
			rec.token += 1 -- the debounce is overtaken by this write
			task.spawn(flush, rec, true)
		end
	end)
	game:BindToClose(function()
		for _, rec in records do
			rec.token += 1
			task.spawn(flush, rec, true)
		end
		local t = os.clock()
		while pendingWrites > 0 and os.clock() - t < 25 do
			task.wait(0.1)
		end
	end)
end

-- Debug: refused requests by reason.
function SettingsService.rejects(): { [string]: number }
	return table.clone(rejects)
end

return SettingsService
