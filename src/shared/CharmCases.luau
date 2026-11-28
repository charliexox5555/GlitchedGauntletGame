--!strict
-- Charm blind boxes (StrikeBox / OverdriveBox): prioritizes unowned charms
-- (0 copies) until all 12 in that box are owned, then stacks copies up to the
-- active gun count (LoadoutConfig) so players can equip a charm on every gun.

local CharmsConfig = require(script.Parent.Config.Charms)
local LoadoutConfig = require(script.Parent.Config.Loadout)
local PlayerData = require(script.Parent.PlayerData)

local CharmCases = {}

CharmCases.CASES = table.freeze({
	StrikeBox = "StrikePack",
	OverdriveBox = "OverdrivePack",
}) :: { [string]: string }

CharmCases.TIER_ORDER = table.freeze({ "Common", "Rare", "Epic", "Legendary" })

CharmCases.WEIGHTS = table.freeze({
	Common = 55,
	Rare = 30,
	Epic = 11,
	Legendary = 4,
}) :: { [string]: number }

function CharmCases.isCharmCase(caseId: string): boolean
	return CharmCases.CASES[caseId] ~= nil
end

function CharmCases.maxCopies(): number
	return math.max(1, #LoadoutConfig.PRIMARIES + #LoadoutConfig.SECONDARIES)
end

function CharmCases.pool(caseId: string): { string }
	local packId = CharmCases.CASES[caseId]
	local pack = if packId then (CharmsConfig.PACKS :: any)[packId] else nil
	return if pack and pack.charms then pack.charms else {}
end

function CharmCases.remainingSlots(caseId: string, charms: PlayerData.CharmSave): number
	local cap = CharmCases.maxCopies()
	local left = 0
	for _, id in CharmCases.pool(caseId) do
		local have = PlayerData.charmCopies(charms, id)
		if have < cap then
			left += cap - have
		end
	end
	return left
end

-- Unowned-first protection: returns all charms with 0 copies while any exist in this box,
-- otherwise all charms below `maxCopies()`. Second return is true while in unowned-first phase.
function CharmCases.eligible(caseId: string, charms: PlayerData.CharmSave): ({ string }, boolean)
	local unowned: { string } = {}
	local belowCap: { string } = {}
	local cap = CharmCases.maxCopies()
	for _, id in CharmCases.pool(caseId) do
		local copies = PlayerData.charmCopies(charms, id)
		if copies <= 0 then
			table.insert(unowned, id)
		end
		if copies < cap then
			table.insert(belowCap, id)
		end
	end
	if #unowned > 0 then
		return unowned, true
	end
	return belowCap, false
end

function CharmCases.odds(
	caseId: string,
	charms: PlayerData.CharmSave
): ({ [string]: number }, { [string]: number }, boolean)
	local candidates, unownedPhase = CharmCases.eligible(caseId, charms)
	local byTier: { [string]: { string } } = {}
	for _, id in candidates do
		local def = CharmsConfig.get(id)
		local t = if def then def.rarity else "Common"
		byTier[t] = byTier[t] or {}
		table.insert(byTier[t], id)
	end
	local total = 0
	for t in byTier do
		total += CharmCases.WEIGHTS[t] or 0
	end
	local charmOdds: { [string]: number } = {}
	local tierOdds: { [string]: number } = {}
	for _, id in CharmCases.pool(caseId) do
		charmOdds[id] = 0
	end
	if total <= 0 then
		return charmOdds, tierOdds, unownedPhase
	end
	for t, list in byTier do
		local chance = (CharmCases.WEIGHTS[t] or 0) / total
		tierOdds[t] = chance
		for _, id in list do
			charmOdds[id] = chance / #list
		end
	end
	return charmOdds, tierOdds, unownedPhase
end

function CharmCases.roll(caseId: string, charms: PlayerData.CharmSave, rng: Random): string?
	local charmOdds, tierOdds = CharmCases.odds(caseId, charms)
	local pick = rng:NextNumber()
	local chosen: string? = nil
	for _, t in CharmCases.TIER_ORDER do
		local chance = tierOdds[t]
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
	for _, id in CharmCases.pool(caseId) do
		if (charmOdds[id] or 0) > 0 then
			local def = CharmsConfig.get(id)
			if def and def.rarity == chosen then
				table.insert(inTier, id)
			end
		end
	end
	if #inTier == 0 then
		return nil
	end
	return inTier[rng:NextInteger(1, #inTier)]
end

return CharmCases
