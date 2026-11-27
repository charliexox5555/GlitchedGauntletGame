--!strict
-- Power cases (vault/01 Design/Loadout and Power Deck.md -> Power cases; owner 2026-11-26): a power case always
-- gives a power the player doesn't own yet (never a duplicate); once every power in it is owned it can't be bought
-- or opened. Powers are ranked in tiers (Config/PowerCases): a tier is rolled first by its weight among the tiers
-- that still hold an unowned power, then each unowned power in it has the same chance. The pool: every built
-- power outside the starter deck. The skin cases roll through Shared/SkinCases; ShopService picks this module for a
-- case listed in CASES.

local Config = require(script.Parent.Config.PowerCases)
local Mods = require(script.Parent.Mods)
local ModsConfig = require(script.Parent.Config.Mods)
local ModLoadout = require(script.Parent.ModLoadout)
local Season = require(script.Parent.Config.Season)

local PowerCases = {}

-- The case ids that hold powers (ShopCatalog / Config/Inventory `case`).
PowerCases.CASES = table.freeze({ Power = true } :: { [string]: boolean })
-- Rarest last (the skin tiers' order).
PowerCases.TIER_ORDER = table.freeze({ "Common", "Rare", "Epic", "Legendary" })

function PowerCases.isPowerCase(caseId: string): boolean
	return PowerCases.CASES[caseId] == true
end

-- A power's tier id (Config/Skins TIERS key).
function PowerCases.tierOf(id: string): string
	return Config.TIER_OF[id] or Config.DEFAULT_TIER
end

-- Every power the case can give, in Config/Mods order. Battle pass powers (Config/Season POWER_UNLOCKS) never
-- roll, so a pack can't make a pass tier pointless.
function PowerCases.pool(_caseId: string): { string }
	local out: { string } = {}
	for _, id in ModsConfig.ORDER do
		local def = Mods.def(id)
		if
			def
			and Mods.isBuilt(id)
			and not def.free
			and not table.find(ModsConfig.STARTER_DECK, id)
			and Season.POWER_UNLOCKS[id] == nil
		then
			table.insert(out, id)
		end
	end
	return out
end

-- The powers it can still give this player.
function PowerCases.unowned(caseId: string, mods: ModLoadout.Loadout): { string }
	local out: { string } = {}
	for _, id in PowerCases.pool(caseId) do
		if mods.owned[id] ~= true then
			table.insert(out, id)
		end
	end
	return out
end

-- This player's chance of each power in the case (0..1; owned ones 0) and of each tier.
function PowerCases.odds(
	caseId: string,
	mods: ModLoadout.Loadout
): ({ [string]: number }, { [string]: number })
	local byTier: { [string]: { string } } = {}
	for _, id in PowerCases.unowned(caseId, mods) do
		local t = PowerCases.tierOf(id)
		byTier[t] = byTier[t] or {}
		table.insert(byTier[t], id)
	end
	local total = 0
	for t in byTier do
		total += Config.WEIGHTS[t] or 0
	end
	local powers: { [string]: number } = {}
	local tiers: { [string]: number } = {}
	for _, id in PowerCases.pool(caseId) do
		powers[id] = 0
	end
	if total <= 0 then
		return powers, tiers
	end
	for t, list in byTier do
		local chance = (Config.WEIGHTS[t] or 0) / total
		tiers[t] = chance
		for _, id in list do
			powers[id] = chance / #list
		end
	end
	return powers, tiers
end

-- One power: a tier by weight among the tiers with something left, then equal odds inside it; nil when the player
-- owns them all.
function PowerCases.roll(caseId: string, mods: ModLoadout.Loadout, rng: Random): string?
	local _, tiers = PowerCases.odds(caseId, mods)
	local pick = rng:NextNumber()
	local chosen: string? = nil
	for _, t in PowerCases.TIER_ORDER do
		local chance = tiers[t]
		if chance then
			chosen = t
			if pick < chance then
				break
			end
			pick -= chance
		end
	end
	if not chosen then
		return nil
	end
	local inTier: { string } = {}
	for _, id in PowerCases.unowned(caseId, mods) do
		if PowerCases.tierOf(id) == chosen then
			table.insert(inTier, id)
		end
	end
	if #inTier == 0 then
		return nil
	end
	return inTier[rng:NextInteger(1, #inTier)]
end

return PowerCases
