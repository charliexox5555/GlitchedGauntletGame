--!strict
-- Level-up rewards (vault/01 Design/Level Rewards.md, owner 2026-11-28): a reward on every player level-up
-- (Config/Progression.LEVEL_REWARDS) and at every gun milestone (Config/GunLevels.REWARDS). Rules only, no
-- saving: the server pays inside the save write that made the level (ProgressionService match write,
-- LockerService coin level). Levels only go up, so a level crossed in one write is never crossed again: no
-- new save field, and the write's txId already stops a repeated report paying twice.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Progression = require(ReplicatedStorage.Shared.Config.Progression)
local GunConfig = require(ReplicatedStorage.Shared.Config.GunLevels)
local Inventory = require(ReplicatedStorage.Shared.Config.Inventory)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)

local LevelRewards = {}

-- One level's reward. `item` is a Config/Inventory item id (one of it).
export type Reward = { level: number, coins: number, tickets: number, item: string? }
-- What a write paid, summed (for the screen and telemetry).
export type Paid = { coins: number, tickets: number, items: { [string]: number }, levels: { Reward } }

local function isItem(id: string?): boolean
	return id ~= nil and Inventory.ITEMS[id] ~= nil
end

-- The reward for reaching player level `level` (nil for level 1 or below).
function LevelRewards.player(level: number): Reward?
	if level < 2 then
		return nil
	end
	local c = Progression.LEVEL_REWARDS
	local coins = math.min(c.coinsBase + c.coinsPerLevel * level, c.coinsMax)
	local tickets = 0
	local item: string? = nil
	if level % c.bigBoxEvery == 0 then
		item = c.bigBox
	elseif level % c.boxEvery == 0 then
		item = c.box
	elseif level % c.ticketEvery == 0 then
		tickets = 1
	end
	return {
		level = level,
		coins = math.floor(coins),
		tickets = tickets,
		item = if isItem(item) then item else nil,
	}
end

-- The reward for reaching gun level `level` (nil off a milestone).
function LevelRewards.gun(level: number): Reward?
	local r = GunConfig.REWARDS[level]
	if not r then
		return nil
	end
	return {
		level = level,
		coins = math.floor(r.coins or 0),
		tickets = math.floor(r.tickets or 0),
		item = if isItem(r.item) then r.item else nil,
	}
end

function LevelRewards.empty(): Paid
	return { coins = 0, tickets = 0, items = {}, levels = {} }
end

-- Pays every level in (from, to] into `data` (in place, inside the save write) and adds it to `paid`.
-- `coinsOnly`: a level reached with coins pays only the coins (Tickets and boxes come from play).
function LevelRewards.grant(
	data: PlayerData.Data,
	paid: Paid,
	kind: "player" | "gun",
	from: number,
	to: number,
	coinsOnly: boolean?
)
	local last = math.min(to, from + Progression.LEVEL_REWARDS.maxPerWrite)
	for level = from + 1, last do
		local r = if kind == "player" then LevelRewards.player(level) else LevelRewards.gun(level)
		if not r then
			continue
		end
		local coins = math.clamp(r.coins, 0, Inventory.MAX_COINS - data.coins)
		local tickets = if coinsOnly
			then 0
			else math.clamp(r.tickets, 0, Economy.MAX_TICKETS - data.tickets)
		local item = if coinsOnly then nil else r.item
		data.coins += coins
		data.tickets += tickets
		if item then
			local have = data.items[item] or 0
			local max = Inventory.ITEMS[item].maxStack
			if have < max then
				data.items[item] = have + 1
				paid.items[item] = (paid.items[item] or 0) + 1
			else
				item = nil
			end
		end
		paid.coins += coins
		paid.tickets += tickets
		table.insert(paid.levels, { level = level, coins = coins, tickets = tickets, item = item })
	end
end

-- "150 COINS · 1 TICKET · STRIKE BOX" (the screen's line for one reward or a sum).
function LevelRewards.label(coins: number, tickets: number, items: { [string]: number }?): string
	local parts = {}
	if coins > 0 then
		table.insert(parts, `{coins} COINS`)
	end
	if tickets > 0 then
		table.insert(parts, if tickets == 1 then "1 TICKET" else `{tickets} TICKETS`)
	end
	if items then
		local ids = {}
		for id in items do
			table.insert(ids, id)
		end
		table.sort(ids)
		for _, id in ids do
			local n = items[id]
			local name = Inventory.ITEMS[id] and Inventory.ITEMS[id].name or id
			table.insert(parts, if n > 1 then `{n} {name}ES` else name)
		end
	end
	return table.concat(parts, " · ")
end

return table.freeze(LevelRewards)
