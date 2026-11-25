--!strict
-- What a case can give and the roll (vault/01 Design/Skin Tiers and Cases.md), from
-- Config/Skins (tiers, case odds) and the skin models that exist (Shared/Locker: a pair
-- is in the game only if its WeaponSkins model is SkinReady). Both sides use it: the
-- Shop's CONTENTS odds on the client, the roll on the server (Lobby ShopService).
--
-- Odds (owner 2026-11-20, round 5): a case has SECTIONS by type (gun skins, knife
-- skins) and TIERS, each with a chance (Config/Skins.CASES). The roll: a section by
-- weight, then a tier by weight, then a line (every line in the tier the same chance,
-- Playback = Giltfold), then a gun in the line, each among what the player doesn't own
-- yet. A tier or section with nothing left drops out and the rest scale up
-- (ShopCatalog.ODDS_NOTE).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Locker = require(ReplicatedStorage.Shared.Locker)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local Skins = require(ReplicatedStorage.Shared.Config.Skins)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

export type Pair = { gun: string, line: string, tier: Skins.TierId, section: Skins.SectionId }
export type Entry = Pair & { odds: number } -- percentage for the next opening

local SkinCases = {}

-- The tier of one skin (the line's, or its per-gun override), or nil if the line has
-- no tier yet. Knives follow their line like any gun (owner 2026-11-20, round 6).
function SkinCases.tierOf(gunId: string, line: string): Skins.TierId?
	local def = Skins.LINES[line]
	if not def then
		return nil
	end
	return if def.guns and def.guns[gunId] then def.guns[gunId] else def.tier
end

-- Which section of a case a skin is in.
function SkinCases.sectionOf(gunId: string): Skins.SectionId
	return if gunId == "Knife" then "Knives" else "Guns"
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
				table.insert(
					out,
					{ gun = gun, line = line, tier = tier, section = SkinCases.sectionOf(gun) }
				)
			end
		end
	end
	return out
end

-- Every skin cases can hold (bundle-only tiers left out): the daily shop's pool too.
function SkinCases.all(): { Pair }
	return allPairs()
end

-- The skins a case can give, by section (only sections the case has a chance for,
-- only tiers it holds).
function SkinCases.pool(caseId: string): { [Skins.SectionId]: { Pair } }
	local def = Skins.CASES[caseId]
	local out: { [Skins.SectionId]: { Pair } } = {}
	if not def then
		return out
	end
	for _, p in allPairs() do
		if (def.sections[p.section] or 0) > 0 and (def.tiers[p.tier] or 0) > 0 then
			local list = out[p.section] or {}
			table.insert(list, p)
			out[p.section] = list
		end
	end
	return out
end

local function sectionOrder(): { Skins.SectionId }
	local ids: { Skins.SectionId } = {}
	for id in Skins.SECTIONS do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return Skins.SECTIONS[a].order < Skins.SECTIONS[b].order
	end)
	return ids
end

local function tierOrder(): { Skins.TierId }
	return Skins.ORDER
end

-- Split a section's pairs by tier, then by line (lines sorted, so a seed always rolls
-- the same).
type Lines = { names: { string }, byLine: { [string]: { Pair } } }
local function availableTiers(list: { Pair }, owned: PlayerData.Skins): { [Skins.TierId]: Lines }
	local out: { [Skins.TierId]: Lines } = {}
	for _, p in list do
		if PlayerData.owns(owned, p.gun, p.line) then
			continue
		end
		local l = out[p.tier]
		if not l then
			l = { names = {}, byLine = {} }
			out[p.tier] = l
		end
		local guns = l.byLine[p.line]
		if not guns then
			guns = {}
			l.byLine[p.line] = guns
			table.insert(l.names, p.line)
		end
		table.insert(guns, p)
	end
	for _, l in out do
		table.sort(l.names)
	end
	return out
end

-- Keep owned rows in the list at 0%. The available skins split their line's odds
-- evenly, and empty lines, tiers and sections drop out of the roll.
function SkinCases.contents(caseId: string, owned: PlayerData.Skins?): { Entry }
	local def = Skins.CASES[caseId]
	if not def then
		return {}
	end
	local pool = SkinCases.pool(caseId)
	local available: { [Skins.SectionId]: { [Skins.TierId]: Lines } } = {}
	local total = 0
	local skins = owned or {}
	for id, list in pool do
		local tiers = availableTiers(list, skins)
		available[id] = tiers
		if next(tiers) then
			total += def.sections[id] or 0
		end
	end
	local out: { Entry } = {}
	for id, list in pool do
		local tiers = available[id]
		local share = if total > 0 then (def.sections[id] or 0) / total * 100 else 0
		local tierTotal = 0
		for tier in tiers do
			tierTotal += def.tiers[tier] or 0
		end
		for _, p in list do
			local odds = 0
			local lines = tiers[p.tier]
			local guns = lines and lines.byLine[p.line]
			if lines and guns and not PlayerData.owns(skins, p.gun, p.line) then
				local tierShare = share * (def.tiers[p.tier] or 0) / tierTotal
				odds = tierShare / #lines.names / #guns
			end
			table.insert(out, {
				gun = p.gun,
				line = p.line,
				tier = p.tier,
				section = p.section,
				odds = odds,
			})
		end
	end
	table.sort(out, function(a, b)
		local sa, sb = Skins.SECTIONS[a.section].order, Skins.SECTIONS[b.section].order
		if sa ~= sb then
			return sa < sb
		end
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

export type Group = { line: string, tier: Skins.TierId, odds: number, entries: { Entry } }
export type TierBlock = { tier: Skins.TierId, odds: number, groups: { Group } }
export type Section = { id: Skins.SectionId, name: string, odds: number, tiers: { TierBlock } }

-- The CONTENTS: each section with its chance, inside it each tier with its chance
-- (highest first), inside that one group per skin line (the line's combined odds,
-- its skins with their own). Knives are one skin per line, so each is its own group.
function SkinCases.sections(caseId: string, owned: PlayerData.Skins?): { Section }
	local out: { Section } = {}
	local bySection: { [string]: Section } = {}
	local byTierKey: { [string]: TierBlock } = {}
	local byGroup: { [string]: Group } = {}
	for _, e in SkinCases.contents(caseId, owned) do
		local sec = bySection[e.section]
		if not sec then
			sec = { id = e.section, name = Skins.SECTIONS[e.section].name, odds = 0, tiers = {} }
			bySection[e.section] = sec
			table.insert(out, sec)
		end
		sec.odds += e.odds
		local tk = e.section .. "|" .. e.tier
		local tb = byTierKey[tk]
		if not tb then
			tb = { tier = e.tier, odds = 0, groups = {} }
			byTierKey[tk] = tb
			table.insert(sec.tiers, tb)
		end
		tb.odds += e.odds
		local key = tk .. "|" .. e.line
		local g = byGroup[key]
		if not g then
			g = { line = e.line, tier = e.tier, odds = 0, entries = {} }
			byGroup[key] = g
			table.insert(tb.groups, g)
		end
		g.odds += e.odds
		table.insert(g.entries, e)
	end
	return out
end

-- Pick one key of `weights` among `keys` (in that order) by weight; nil if none.
local function weighted<K>(keys: { K }, weights: { [K]: number }, rng: Random): K?
	local total = 0
	for _, k in keys do
		total += weights[k] or 0
	end
	if total <= 0 then
		return nil
	end
	local pick = rng:NextNumber() * total
	local last: K? = nil
	for _, k in keys do
		local w = weights[k] or 0
		if w > 0 then
			last = k
			pick -= w
			if pick <= 0 then
				return k
			end
		end
	end
	return last
end

-- One roll for a player who owns `owned`, with `rng` (seeded per purchase so a
-- retried save write rolls the same). nil = the case has nothing left for them.
function SkinCases.roll(caseId: string, owned: PlayerData.Skins, rng: Random): Pair?
	local def = Skins.CASES[caseId]
	if not def then
		return nil
	end
	local pool = SkinCases.pool(caseId)
	-- what's left, by section then tier
	local open: { [Skins.SectionId]: { [Skins.TierId]: Lines } } = {}
	local sectionW: { [Skins.SectionId]: number } = {}
	local sections = sectionOrder()
	for _, id in sections do
		local tiers = availableTiers(pool[id] or {}, owned)
		if next(tiers) then
			open[id] = tiers
			sectionW[id] = def.sections[id] or 0
		end
	end
	local section = weighted(sections, sectionW, rng)
	if not section then
		return nil
	end
	local tiers = open[section]
	local tierW: { [Skins.TierId]: number } = {}
	for tier in tiers do
		tierW[tier] = def.tiers[tier] or 0
	end
	local tier = weighted(tierOrder(), tierW, rng)
	if not tier then
		return nil
	end
	local l = tiers[tier]
	local guns = l.byLine[l.names[rng:NextInteger(1, #l.names)]]
	return guns[rng:NextInteger(1, #guns)]
end

-- "PRISM VANDAL" ("BAT" for the PopCircuit knife, like the Locker).
function SkinCases.name(gunId: string, line: string): string
	local gun = if gunId == "Knife" and line == "PopCircuit"
		then "BAT"
		else string.upper(Weapons.nameOf(gunId))
	return string.upper(line) .. " " .. gun
end

return SkinCases
