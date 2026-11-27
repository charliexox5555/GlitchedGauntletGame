--!strict
-- The per-player daily shop (vault/01 Design/Shop Economy and Art v1.md; owner 2026-11-22:
-- "not the same for everyone ... saved on server so they can't bypass it"). Saved as
-- PlayerData `daily`; the server rolls it (ShopService, Shared/DailyRoll) and sells only
-- from it. This module is the saved shape only (PlayerData requires it).
--   day     the UTC day index it was rolled for (0 = never)
--   picks   the skins on offer, in slot order: { gun, line }
--   bought  the slot numbers already bought today

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

export type Pick = { gun: string, line: string }
export type Daily = { day: number, picks: { Pick }, bought: { number } }

local DailyShop = {}

DailyShop.SIZE = #Economy.DAILY_SLOTS

function DailyShop.new(): Daily
	return { day = 0, picks = {}, bought = {} }
end

local function str(v: unknown, max: number): string?
	return if typeof(v) == "string" and #v > 0 and #v <= max then v else nil
end

-- Any stored value to a valid Daily (anything odd = not rolled yet).
function DailyShop.clean(raw: unknown): Daily
	if typeof(raw) ~= "table" then
		return DailyShop.new()
	end
	local t = raw :: { [string]: unknown }
	local day = t.day
	if typeof(day) ~= "number" or day ~= day or day < 0 or day > 1e7 or day ~= math.floor(day) then
		return DailyShop.new()
	end
	local out: Daily = { day = day, picks = {}, bought = {} }
	if typeof(t.picks) == "table" then
		for _, p in t.picks :: { unknown } do
			if #out.picks >= DailyShop.SIZE or typeof(p) ~= "table" then
				break
			end
			local gun, line = str((p :: any).gun, 24), str((p :: any).line, 32)
			-- A gun taken out of the game since the roll (the TwinShot, 2026-11-27): the day rolls again.
			if not gun or not line or not Weapons.get(gun) then
				return DailyShop.new()
			end
			table.insert(out.picks, { gun = gun, line = line })
		end
	end
	if typeof(t.bought) == "table" then
		for _, i in t.bought :: { unknown } do
			if
				typeof(i) == "number"
				and i == math.floor(i)
				and i >= 1
				and i <= #out.picks
				and not table.find(out.bought, i)
			then
				table.insert(out.bought, i)
			end
		end
	end
	return out
end

function DailyShop.valid(d: Daily): boolean
	if #d.picks > DailyShop.SIZE or #d.bought > #d.picks then
		return false
	end
	for _, i in d.bought do
		if i < 1 or i > #d.picks or i ~= math.floor(i) then
			return false
		end
	end
	return true
end

-- The slot that shows FREE for a player who hasn't used their one free daily skin: the
-- first coin-priced pick they don't own and haven't bought (`coinPriced` decides).
function DailyShop.freeSlot(
	d: Daily,
	owns: (gun: string, line: string) -> boolean,
	coinPriced: (p: Pick) -> boolean
): number?
	for i, p in d.picks do
		if coinPriced(p) and not table.find(d.bought, i) and not owns(p.gun, p.line) then
			return i
		end
	end
	return nil
end

return DailyShop
