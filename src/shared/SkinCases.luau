--!strict
-- What a case can give and the roll (vault/01 Design/Skin Tiers and Cases.md), from
-- Config/Skins (tiers, case odds) and the skin models that exist (Shared/Locker: a pair
-- is in the game only if its WeaponSkins model is SkinReady). Both sides use it: the
-- Shop's CONTENTS odds on the client, the roll on the server (Lobby ShopService).
--
-- Odds (owner 2026-11-20, after RIVALS): a case has SECTIONS by type (gun skins, knife
-- skins) with a chance each; inside a section every SKIN LINE has the same chance
-- (Playback = Giltfold), split evenly across that line's guns. Knives are one per
-- line, so every knife is equal. Tiers only decide which skins a case holds
-- (Config/Skins.CASES). The roll: a section by weight, then a line, then a gun, each
-- among what the player doesn't own yet (owned skins drop out, so the rest go up;
-- ShopCatalog.ODDS_NOTE).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Locker = require(ReplicatedStorage.Shared.Locker)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local Skins = require(ReplicatedStorage.Shared.Config.Skins)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

export type Pair = { gun: string, line: string, tier: Skins.TierId, section: Skins.SectionId }
export type Entry = Pair & { odds: number } -- odds in % before re-rolls

local SkinCases = {}

-- The tier of one skin (the line's, or its per-gun override, raised to the knife
-- minimum for knives), or nil if the line has no tier yet.
function SkinCases.tierOf(gunId: string, line: string): Skins.TierId?
	local def = Skins.LINES[line]
	if not def then
		return nil
	end
	local tier: Skins.TierId = if def.guns and def.guns[gunId] then def.guns[gunId] else def.tier
	local floor = if gunId == "Knife" then Skins.KNIFE_MIN[def.kind] else nil
	if floor and Skins.TIERS[floor].order > Skins.TIERS[tier].order then
		tier = floor
	end
	return tier
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

-- The skins a case can give, by section (only sections the case has a chance for,
-- only tiers it holds).
function SkinCases.pool(caseId: string): { [Skins.SectionId]: { Pair } }
	local def = Skins.CASES[caseId]
	local out: { [Skins.SectionId]: { Pair } } = {}
	if not def then
		return out
	end
	for _, p in allPairs() do
		if (def.sections[p.section] or 0) > 0 and table.find(def.tiers, p.tier) then
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

-- Every skin with its odds in % (a section with nothing in it drops out and the
-- rest scale), sections in order, then tier (highest first), line and gun.
function SkinCases.contents(caseId: string): { Entry }
	local def = Skins.CASES[caseId]
	local pool = SkinCases.pool(caseId)
	local total = 0
	for id, list in pool do
		if #list > 0 then
			total += def.sections[id] or 0
		end
	end
	local out: { Entry } = {}
	for _, id in sectionOrder() do
		local list = pool[id]
		if list and #list > 0 then
			local share = (def.sections[id] or 0) / total * 100
			-- equal per line, then equal per gun inside the line
			local perLine: { [string]: number } = {}
			local lines = 0
			for _, p in list do
				if not perLine[p.line] then
					lines += 1
					perLine[p.line] = 0
				end
				perLine[p.line] += 1
			end
			for _, p in list do
				table.insert(out, {
					gun = p.gun,
					line = p.line,
					tier = p.tier,
					section = p.section,
					odds = share / lines / perLine[p.line],
				})
			end
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
export type Section = { id: Skins.SectionId, name: string, odds: number, groups: { Group } }

-- The CONTENTS laid out like RIVALS: each section with its chance, inside it one
-- group per skin line (the line's combined odds, its skins with their own). Knives
-- are one skin per line, so each knife is its own group.
function SkinCases.sections(caseId: string): { Section }
	local out: { Section } = {}
	local bySection: { [string]: Section } = {}
	local byGroup: { [string]: Group } = {}
	for _, e in SkinCases.contents(caseId) do
		local sec = bySection[e.section]
		if not sec then
			sec = { id = e.section, name = Skins.SECTIONS[e.section].name, odds = 0, groups = {} }
			bySection[e.section] = sec
			table.insert(out, sec)
		end
		sec.odds += e.odds
		local key = e.section .. "|" .. e.line .. "|" .. e.tier
		local g = byGroup[key]
		if not g then
			g = { line = e.line, tier = e.tier, odds = 0, entries = {} }
			byGroup[key] = g
			table.insert(sec.groups, g)
		end
		g.odds += e.odds
		table.insert(g.entries, e)
	end
	return out
end

-- One roll for a player who owns `owned`, with `rng` (seeded per purchase so a
-- retried save write rolls the same). nil = the case has nothing left for them.
function SkinCases.roll(caseId: string, owned: PlayerData.Skins, rng: Random): Pair?
	local def = Skins.CASES[caseId]
	if not def then
		return nil
	end
	local pool = SkinCases.pool(caseId)
	local open: { [Skins.SectionId]: { Pair } } = {}
	local total = 0
	local order = sectionOrder()
	for _, id in order do
		local list: { Pair } = {}
		for _, p in (pool[id] or {}) do
			if not PlayerData.owns(owned, p.gun, p.line) then
				table.insert(list, p)
			end
		end
		if #list > 0 and (def.sections[id] or 0) > 0 then
			open[id] = list
			total += def.sections[id]
		end
	end
	if total <= 0 then
		return nil
	end
	-- a section by weight
	local pick = rng:NextNumber() * total
	local chosen: { Pair }? = nil
	for _, id in order do
		local list = open[id]
		if list then
			chosen = list
			pick -= def.sections[id]
			if pick <= 0 then
				break
			end
		end
	end
	local list = chosen
	if not list then
		return nil
	end
	-- then a line (each line with something left counts once), then a gun in it
	local lines: { string } = {}
	local byLine: { [string]: { Pair } } = {}
	for _, p in list do
		if not byLine[p.line] then
			byLine[p.line] = {}
			table.insert(lines, p.line)
		end
		table.insert(byLine[p.line], p)
	end
	table.sort(lines) -- a fixed order, so a seed always rolls the same
	local guns = byLine[lines[rng:NextInteger(1, #lines)]]
	return guns[rng:NextInteger(1, #guns)]
end

-- "PRISM VANDAL" ("BAT" for the PopCircuit knife, like the Locker).
function SkinCases.name(gunId: string, line: string): string
	local gun = if gunId == "Knife" and line == "PopCircuit" then "BAT" else string.upper(gunId)
	return string.upper(line) .. " " .. gun
end

return SkinCases
