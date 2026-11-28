--!strict
-- Rolling and pricing the per-player daily shop (Shared/DailyShop is the saved shape).
-- Server: ShopService rolls with it; client: ShopController prices the cards with it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DailyShop = require(ReplicatedStorage.Shared.DailyShop)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local GunLoadout = require(ReplicatedStorage.Shared.GunLoadout)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local SkinCases = require(ReplicatedStorage.Shared.SkinCases)

local DailyRoll = {}

-- A daily skin the player can buy and use: the knife's, or one for an active gun they own
-- (owner 2026-11-28: "if you don't own a gun ... you won't be able to purchase it").
function DailyRoll.usable(p: DailyShop.Pick, guns: GunLoadout.Loadout): boolean
	return SkinCases.usable(p.gun, guns)
end

-- A fresh list for `day`: one skin per Economy.DAILY_SLOTS entry, no repeats. Most slots
-- are for guns the player owns; up to Economy.DAILY_TEASES random slots are for guns they
-- haven't unlocked (a tease, shown GUN LOCKED). Within a slot, skins the player doesn't
-- own come first. Only skins that cases can hold (no bundle-only lines, active guns only).
function DailyRoll.roll(
	owned: PlayerData.Skins,
	guns: GunLoadout.Loadout,
	day: number,
	rng: Random
): DailyShop.Daily
	local byTier: { [string]: { SkinCases.Pair } } = {}
	for _, p in SkinCases.all() do
		-- ids longer than Shared/DailyShop.clean keeps would wipe the saved list on load
		if #p.gun > 24 or #p.line > 32 then
			continue
		end
		local list = byTier[p.tier] or {}
		table.insert(list, p)
		byTier[p.tier] = list
	end
	local taken: { [string]: boolean } = {}
	local function free(tier: string, wantUsable: boolean, wantOwned: boolean): { SkinCases.Pair }
		local out: { SkinCases.Pair } = {}
		for _, p in byTier[tier] or {} do
			if
				not taken[p.gun .. "/" .. p.line]
				and SkinCases.usable(p.gun, guns) == wantUsable
				and PlayerData.owns(owned, p.gun, p.line) == wantOwned
			then
				table.insert(out, p)
			end
		end
		return out
	end
	-- what a slot tries, in order: { usable gun?, skin owned? }
	local USABLE_FIRST = { { true, false }, { false, false }, { true, true }, { false, true } }
	local TEASE_FIRST = { { false, false }, { true, false }, { true, true }, { false, true } }
	local function pickFrom(tiers: { string }, tease: boolean): DailyShop.Pick?
		for _, want in if tease then TEASE_FIRST else USABLE_FIRST do
			-- several tiers: one of them at random among those with something left
			local order = table.clone(tiers)
			for i = #order, 2, -1 do
				local j = rng:NextInteger(1, i)
				order[i], order[j] = order[j], order[i]
			end
			for _, tier in order do
				local options = free(tier, want[1], want[2])
				if #options > 0 then
					local p = options[rng:NextInteger(1, #options)]
					taken[p.gun .. "/" .. p.line] = true
					return { gun = p.gun, line = p.line }
				end
			end
		end
		return nil
	end
	-- which slots are teases: DAILY_TEASES of them, at random
	local slots = Economy.DAILY_SLOTS
	local order: { number } = {}
	for i = 1, #slots do
		order[i] = i
	end
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	local teases: { [number]: boolean } = {}
	for k = 1, math.min(Economy.DAILY_TEASES, #order) do
		teases[order[k]] = true
	end
	local d: DailyShop.Daily = { day = day, picks = {}, bought = {} }
	for i, slot in slots do
		local p = pickFrom(
			if slot == "EpicOrLegendary" then { "Epic", "Legendary" } else { slot },
			teases[i] == true
		)
		if p then
			table.insert(d.picks, p)
		end
	end
	return d
end

-- The tier of one pick (Common when the line has none).
function DailyRoll.tier(p: DailyShop.Pick): string
	return SkinCases.tierOf(p.gun, p.line) or "Common"
end

-- Price of one pick: (coins, nil) or (nil, robux).
function DailyRoll.price(p: DailyShop.Pick): (number?, number?)
	local tier = DailyRoll.tier(p)
	local coins = Economy.DAILY_COINS[tier]
	if coins then
		return coins, nil
	end
	return nil, Economy.SKIN_ROBUX[tier]
end

return DailyRoll
