--!strict
-- The player's saved wallet and inventory (vault/01 Design/Inventory and
-- Crates.md). One DataStore key per player in STORE:
--   { v = 1, coins = number, items = { [itemId] = count }, tx = { purchaseId },
--     skins = { [gunId] = { line, ... } } }   owned skin lines per gun ("Stock" is always
--                                            owned and never stored; 2026-11-20)
-- Written only by the Lobby's PlayerDataService, one UpdateAsync per change.
--
-- Both sides read it from the player:
--   StateValues "Coins"  the balance (the Shop's counter already reads it)
--   StringValue "Inventory"  JSON { [itemId] = count }
--   StateValues "DataReady"  true once the save loaded (buying waits for it)
--   StringValue "Skins"  JSON { [gunId] = { line } }, the owned skins (Locker, Backpack)

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Inventory = require(ReplicatedStorage.Shared.Config.Inventory)
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local HealthLog = require(ReplicatedStorage.Shared.HealthLog)

export type Items = { [string]: number }
export type Skins = { [string]: { string } }
export type Data = {
	v: number,
	coins: number,
	items: Items,
	tx: { string },
	skins: Skins,
}

local PlayerData = {}

-- Studio play (API access on) saves to its own store, so test coins and test
-- purchases never land in a live save.
PlayerData.STORE = if RunService:IsStudio() then "PlayerDataV1_Studio" else "PlayerDataV1"
PlayerData.VERSION = 1
PlayerData.REPLICA = "Inventory"
PlayerData.SKINS = "Skins"
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
	}
	if typeof(raw) ~= "table" then
		return data
	end
	local t = raw :: { [string]: unknown }
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
	if not whole(data.coins, Inventory.MAX_COINS) then
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
	local was = StateValues.get(player, "DataReady") == true
	if data and not was then
		HealthLog.stage("data ready", player)
	elseif was and not data then
		HealthLog.problem("data lost", player)
	end
	StateValues.set(player, "DataReady", data ~= nil)
	local shown: Items = {}
	if data then
		for id, n in data.items do
			if Inventory.ITEMS[id] and n > 0 then
				shown[id] = n
			end
		end
	end
	setJson(player, PlayerData.SKINS, if data then data.skins else {})
	-- Inventory last: clients listen to it, and the skins must already be there
	setJson(player, PlayerData.REPLICA, shown)
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

function PlayerData.coins(player: Player): number
	local v = StateValues.get(player, "Coins")
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
