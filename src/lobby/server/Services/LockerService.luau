--!strict
-- The Locker's equips (vault/02 Art/UI Locker.md): one skin line per gun,
-- saved so the Match puts it on your guns (Shared/Locker, read by the match's
-- SkinPreviewService). Only OWNED skins (Shared/PlayerData skins, granted by
-- case openings; Stock is always owned) can be equipped, and the published
-- LockerSkins only ever lists owned pairs, so an old save that equipped a skin
-- the player doesn't own shows Stock (2026-11-20: "wipe out all gun skins").
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
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Lobby.Config)
local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local Locker = require(ReplicatedStorage.Shared.Locker)
local ModLoadout = require(ReplicatedStorage.Shared.ModLoadout)
local Mods = require(ReplicatedStorage.Shared.Mods)
local PlayZone = require(ReplicatedStorage.Shared.PlayZone)
local RateLimit = require(ReplicatedStorage.Shared.Util.RateLimit)
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local Validate = require(ReplicatedStorage.Shared.Util.Validate)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local PlayerDataService = require(script.Parent.PlayerDataService)
local Telemetry = require(script.Parent.Parent.Telemetry)

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
local savingMods: { [Player]: boolean } = {}

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

-- The equips this player may wear: owned pairs only (nothing but Stock until
-- their save loads).
local function owned(player: Player, skins: { [string]: string }): { [string]: string }
	local data = PlayerDataService.get(player)
	local out: { [string]: string } = {}
	for gunId, line in skins do
		if data and PlayerData.owns(data.skins, gunId, line) then
			out[gunId] = line
		end
	end
	return out
end

local function publish(player: Player)
	local rec = records[player]
	if rec then
		Locker.publish(player, owned(player, rec.skins))
	end
end

local function isFreshOnboarding(): boolean
	return RunService:IsStudio() and workspace:GetAttribute("FreshOnboarding") == true
end

local function load(player: Player)
	local rec: Record =
		{ skins = {}, loaded = false, dirty = false, token = 0, saving = false, lastSave = 0 }
	records[player] = rec
	if isFreshOnboarding() then
		publish(player)
		return
	end
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
	publish(player)
end

local function equip(player: Player, gunId: string, line: string)
	local rec = records[player]
	if not rec or rec.skins[gunId] == line then
		return
	end
	rec.skins[gunId] = line
	publish(player)
	rec.dirty = true
	rec.token += 1
	local token = rec.token
	task.delay(SAVE_DELAY, function()
		if records[player] == rec and rec.token == token then
			save(player)
		end
	end)
	if line ~= "Stock" then
		local data = PlayerDataService.get(player)
		if data and data.onb.caseGift and not data.onb.skinEquipped then
			task.spawn(function()
				local ok = PlayerDataService.transact(
					player,
					PlayerDataService.newTxId(),
					function(latest)
						if latest.onb.skinEquipped then
							return false, "nothing"
						end
						latest.onb.skinEquipped = true
						return true
					end,
					true
				)
				if ok then
					Telemetry.onboarding(player, 16)
					Telemetry.caseOnboarding(player, 4, "Skin equipped")
				end
			end)
		end
	end
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
	local data = PlayerDataService.get(player)
	if not (data and PlayerData.owns(data.skins, gunId :: string, line :: string)) then
		reject("notOwned")
		return
	end
	equip(player, gunId :: string, line :: string)
end

function LockerService.isSavingMods(player: Player): boolean
	return savingMods[player] == true
end

local function saveModChoice(player: Player, idArg: unknown, equippedArg: unknown): boolean
	local id = Validate.string(idArg, ModLoadout.MAX_ID_LENGTH)
	local equipped = Validate.boolean(equippedArg)
	local def = id and Mods.def(id)
	local queueStatus = StateValues.get(player, "QueueStatus")
	if
		not id
		or equipped == nil
		or not def
		or def.free
		or not Mods.isBuilt(id)
		or savingMods[player]
		or PlayZone.get(player) ~= "Lobby"
		or queueStatus == "found"
		or queueStatus == "teleporting"
	then
		return false
	end
	local data = PlayerDataService.get(player)
	if not data or not data.mods.owned[id] then
		return false
	end
	local allowed = if equipped
		then ModLoadout.canEquip(data.mods, id)
		else ModLoadout.canUnequip(data.mods, id)
	if not allowed then
		return false
	end

	-- The power deck (vault/01 Design/Loadout and Power Deck.md): owned powers only, between
	-- Config/Mods DECK_MIN and DECK_SIZE equipped, checked again on the latest save.
	savingMods[player] = true
	local saved = PlayerDataService.transact(player, PlayerDataService.newTxId(), function(latest)
		if not latest.mods.owned[id] then
			return false, "notOwned"
		end
		if equipped and not ModLoadout.canEquip(latest.mods, id) then
			return false, "deckFull"
		elseif not equipped and not ModLoadout.canUnequip(latest.mods, id) then
			return false, "deckMin"
		end
		latest.mods.equipped[id] = if equipped then true else nil
		return true
	end)
	savingMods[player] = nil
	return saved
end

function LockerService.reset(player: Player)
	local rec = records[player]
	if not rec then
		return
	end
	local hadAny = false
	for gunId, line in rec.skins do
		if line ~= "Stock" then
			rec.skins[gunId] = "Stock"
			hadAny = true
		end
	end
	publish(player)
	if hadAny and rec.loaded then
		rec.dirty = true
		rec.token += 1
		local token = rec.token
		task.delay(SAVE_DELAY, function()
			if records[player] == rec and rec.token == token then
				save(player)
			end
		end)
	end
end

function LockerService.init() end

function LockerService.start()
	LobbyNet.event("LockerRequest").OnServerEvent:Connect(onRequest)
	local modRequest = LobbyNet.event("LockerModRequest")
	modRequest.OnServerEvent:Connect(function(player, id, equipped)
		local saved = limiter:allow(player, "LockerModRequest")
			and saveModChoice(player, id, equipped)
		if player.Parent == Players then
			modRequest:FireClient(player, saved)
		end
	end)
	-- skins loaded or granted: re-filter what this player wears
	PlayerDataService.changed:Connect(publish)
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
