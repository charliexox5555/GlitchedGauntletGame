--!strict
-- Rolling and pricing the per-player daily shop (Shared/DailyShop is the saved shape).
-- Server: ShopService rolls with it; client: ShopController prices the cards with it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DailyShop = require(ReplicatedStorage.Shared.DailyShop)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local SkinCases = require(ReplicatedStorage.Shared.SkinCases)

local DailyRoll = {}

-- A fresh list for `day`: one skin per Economy.DAILY_SLOTS entry, no repeats, skins
-- the player doesn't own first. Only skins that cases can hold (no bundle-only lines).
function DailyRoll.roll(owned: PlayerData.Skins, day: number, rng: Random): DailyShop.Daily
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
	local function free(tier: string, wantOwned: boolean): { SkinCases.Pair }
		local out: { SkinCases.Pair } = {}
		for _, p in byTier[tier] or {} do
			if
				not taken[p.gun .. "/" .. p.line]
				and PlayerData.owns(owned, p.gun, p.line) == wantOwned
			then
				table.insert(out, p)
			end
		end
		return out
	end
	local function pickFrom(tiers: { string }): DailyShop.Pick?
		for _, wantOwned in { false, true } do
			-- several tiers: one of them at random among those with something left
			local order = table.clone(tiers)
			for i = #order, 2, -1 do
				local j = rng:NextInteger(1, i)
				order[i], order[j] = order[j], order[i]
			end
			for _, tier in order do
				local options = free(tier, wantOwned)
				if #options > 0 then
					local p = options[rng:NextInteger(1, #options)]
					taken[p.gun .. "/" .. p.line] = true
					return { gun = p.gun, line = p.line }
				end
			end
		end
		return nil
	end
	local d: DailyShop.Daily = { day = day, picks = {}, bought = {} }
	for _, slot in Economy.DAILY_SLOTS do
		local p = pickFrom(if slot == "EpicOrLegendary" then { "Epic", "Legendary" } else { slot })
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
