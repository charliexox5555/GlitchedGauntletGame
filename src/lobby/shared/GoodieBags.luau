--!strict
-- Rolling and paying a goodie bag (Config/GoodieBags). `roll` + `grant` run inside one PlayerDataService change
-- on the server (ShopService openCase), so a bag pays exactly once. `odds` feeds the CONTENTS list (Util/OddsList).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.GoodieBags)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Inventory = require(ReplicatedStorage.Shared.Config.Inventory)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local SeasonRewards = require(script.Parent.SeasonRewards)

export type Won = {
	prize: string, -- the Config prize id
	kind: "Coins" | "Ticket" | "Item" | "Skin",
	amount: number, -- coins / Tickets paid (1 for an item or skin)
	item: string?, -- Item: the Inventory item added
	gun: string?, -- Skin: the gun rolled
	line: string?,
	name: string, -- what the reveal card says
}

local GoodieBags = {}

function GoodieBags.isBag(caseId: string): boolean
	return Config.BAGS[caseId] ~= nil
end

function GoodieBags.bag(caseId: string): Config.Bag?
	return Config.BAGS[caseId]
end

-- { prize id = chance 0..1 }, in the config's order through `bag.prizes`
function GoodieBags.odds(caseId: string): { [string]: number }
	local bag = Config.BAGS[caseId]
	local out: { [string]: number } = {}
	if not bag then
		return out
	end
	local total = 0
	for _, p in bag.prizes do
		total += math.max(p.weight, 0)
	end
	for _, p in bag.prizes do
		out[p.id] = if total > 0 then math.max(p.weight, 0) / total else 0
	end
	return out
end

local function rollAmount(p: Config.Prize, rng: Random): number
	local lo, hi = math.floor(p.min or 1), math.floor(p.max or p.min or 1)
	if hi < lo then
		hi = lo
	end
	local step = math.max(math.floor(p.step or 1), 1)
	local steps = (hi - lo) // step
	return lo + rng:NextInteger(0, steps) * step
end

-- Rolls one prize and pays it into `data`. Nil only for an unknown bag.
function GoodieBags.open(data: PlayerData.Data, caseId: string, rng: Random): Won?
	local bag = Config.BAGS[caseId]
	if not bag or #bag.prizes == 0 then
		return nil
	end
	local total = 0
	for _, p in bag.prizes do
		total += math.max(p.weight, 0)
	end
	local pick = rng:NextNumber() * total
	local prize = bag.prizes[#bag.prizes]
	for _, p in bag.prizes do
		pick -= math.max(p.weight, 0)
		if pick < 0 then
			prize = p
			break
		end
	end

	local function payCoins(n: number, name: string?): Won
		data.coins = math.min(data.coins + n, Inventory.MAX_COINS)
		return { prize = prize.id, kind = "Coins", amount = n, name = name or `{n} COINS` }
	end

	if prize.kind == "Coins" then
		return payCoins(rollAmount(prize, rng))
	elseif prize.kind == "Ticket" then
		local n = rollAmount(prize, rng)
		data.tickets = math.min(data.tickets + n, Economy.MAX_TICKETS)
		return {
			prize = prize.id,
			kind = "Ticket",
			amount = n,
			name = if n == 1 then "1 TICKET" else `{n} TICKETS`,
		}
	elseif prize.kind == "Item" then
		local def = prize.item and Inventory.ITEMS[prize.item]
		if not def then
			return payCoins(Config.SKIN_FALLBACK_COINS)
		end
		data.items[def.id] = math.min((data.items[def.id] or 0) + 1, def.maxStack)
		return { prize = prize.id, kind = "Item", amount = 1, item = def.id, name = def.name }
	end
	-- Skin: a random gun the player owns without the line, else one they'll unlock later
	local line = prize.line or ""
	local gun = SeasonRewards.rollGun(data, line, rng)
	if not gun then
		return payCoins(Config.SKIN_FALLBACK_COINS)
	end
	PlayerData.grantSkin(data, gun, line)
	return {
		prize = prize.id,
		kind = "Skin",
		amount = 1,
		gun = gun,
		line = line,
		name = string.upper(line) .. " " .. string.upper(Weapons.nameOf(gun)),
	}
end

return GoodieBags
