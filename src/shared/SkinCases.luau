--!strict
-- What a case can give and the roll (vault/01 Design/Skin Tiers and Cases.md), from
-- Config/Skins (tiers, case odds) and the skin models that exist (Shared/Locker: a pair
-- is in the game only if its WeaponSkins model is SkinReady). Both sides use it: the
-- Shop's CONTENTS odds on the client, the roll on the server (Lobby ShopService).
--
-- The roll: pick a tier by the case's weights among tiers that still have a skin the
-- player doesn't own, then one of those skins at random. Owned skins are re-rolled
-- (they drop out), so the odds of the rest go up (ShopCatalog.ODDS_NOTE).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Locker = require(ReplicatedStorage.Shared.Locker)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local Skins = require(ReplicatedStorage.Shared.Config.Skins)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

export type Pair = { gun: string, line: string, tier: Skins.TierId }
export type Entry = Pair & { odds: number } -- odds in % before re-rolls

local SkinCases = {}

-- The tier of one skin (the line's, or its per-gun override), or nil if the line
-- has no tier yet.
function SkinCases.tierOf(gunId: string, line: string): Skins.TierId?
	local def = Skins.LINES[line]
	if not def then
		return nil
	end
	return if def.guns and def.guns[gunId] then def.guns[gunId] else def.tier
end

-- Every skin in the game a case could hold (models present, tier in cases).
local function allPairs(): { Pair }
	local out: { Pair } = {}
	local guns: { string } = {}
	for id in Weapons.list do
		table.insert(guns, id)
	end
	table.sort(guns)
	for _, gun in guns do
		for _, line in Locker.linesFor(gun) do
			local tier = if line ~= "Stock" then SkinCases.tierOf(gun, line) else nil
			if tier and Skins.TIERS[tier].inCases then
				table.insert(out, { gun = gun, line = line, tier = tier })
			end
		end
	end
	return out
end

-- The skins a case can give, grouped by tier (only tiers the case has odds for).
function SkinCases.pool(caseId: string): { [Skins.TierId]: { Pair } }
	local odds = Skins.CASE_ODDS[caseId]
	local out: { [Skins.TierId]: { Pair } } = {}
	if not odds then
		return out
	end
	for _, p in allPairs() do
		if (odds[p.tier] or 0) > 0 then
			local list = out[p.tier] or {}
			table.insert(list, p)
			out[p.tier] = list
		end
	end
	return out
end

-- The CONTENTS list: every skin with its odds in % (tiers with nothing in them
-- drop out and the rest scale), highest tier first, then gun and line.
function SkinCases.contents(caseId: string): { Entry }
	local odds = Skins.CASE_ODDS[caseId] or {}
	local pool = SkinCases.pool(caseId)
	local total = 0
	for tier, list in pool do
		if #list > 0 then
			total += odds[tier] or 0
		end
	end
	local out: { Entry } = {}
	for tier, list in pool do
		for _, p in list do
			local pct = if total > 0 then (odds[tier] or 0) / total / #list * 100 else 0
			table.insert(out, { gun = p.gun, line = p.line, tier = p.tier, odds = pct })
		end
	end
	table.sort(out, function(a, b)
		local ta, tb = Skins.TIERS[a.tier].order, Skins.TIERS[b.tier].order
		if ta ~= tb then
			return ta > tb
		end
		if a.line ~= b.line then
			return a.line < b.line
		end
		return a.gun < b.gun
	end)
	return out
end

-- One roll for a player who owns `owned`, with `rng` (seeded per purchase so a
-- retried save write rolls the same). nil = the case has nothing left for them.
function SkinCases.roll(caseId: string, owned: PlayerData.Skins, rng: Random): Pair?
	local odds = Skins.CASE_ODDS[caseId]
	if not odds then
		return nil
	end
	local pool = SkinCases.pool(caseId)
	local open: { [Skins.TierId]: { Pair } } = {}
	local total = 0
	for _, tier in Skins.ORDER do
		local list: { Pair } = {}
		for _, p in (pool[tier] or {}) do
			if not PlayerData.owns(owned, p.gun, p.line) then
				table.insert(list, p)
			end
		end
		if #list > 0 and (odds[tier] or 0) > 0 then
			open[tier] = list
			total += odds[tier]
		end
	end
	if total <= 0 then
		return nil
	end
	local pick = rng:NextNumber() * total
	for _, tier in Skins.ORDER do
		local list = open[tier]
		if list then
			pick -= odds[tier]
			if pick <= 0 then
				return list[rng:NextInteger(1, #list)]
			end
		end
	end
	-- float edge: the last open tier
	for i = #Skins.ORDER, 1, -1 do
		local list = open[Skins.ORDER[i]]
		if list then
			return list[rng:NextInteger(1, #list)]
		end
	end
	return nil
end

-- "PRISM VANDAL" ("BAT" for the PopCircuit knife, like the Locker).
function SkinCases.name(gunId: string, line: string): string
	local gun = if gunId == "Knife" and line == "PopCircuit" then "BAT" else string.upper(gunId)
	return string.upper(line) .. " " .. gun
end

return SkinCases
