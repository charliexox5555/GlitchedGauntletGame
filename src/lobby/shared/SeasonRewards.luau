--!strict
-- Paying season pass rewards into a save (vault/04 Tech/Battle Pass Build Plan.md, phase 1).
-- Every function here runs inside a PlayerDataService change on the server (claims,
-- premium and skips come in phases 3 and 4; season-end leftovers in phase 9), so a claim
-- pays exactly once. Pure: no services.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local SeasonPass = require(ReplicatedStorage.Shared.SeasonPass)
local Season = require(ReplicatedStorage.Shared.Config.Season)
local Inventory = require(ReplicatedStorage.Shared.Config.Inventory)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local SeasonCatalog = require(script.Parent.SeasonCatalog)

export type Claimed = { tier: number, track: SeasonPass.Track, rewards: { SeasonCatalog.Reward } }

local SeasonRewards = {}

local function amount(r: SeasonCatalog.Reward): number
	local n = r.amount or 1
	return if n == n and n >= 1 then math.floor(n) else 1
end

-- Pays one reward. A reward already owned (a skin, charm, title, power) pays nothing more;
-- coins, Tickets and cases stop at their caps. Returns false for a reward it can't pay.
function SeasonRewards.grant(data: PlayerData.Data, r: SeasonCatalog.Reward): boolean
	if r.kind == "Coins" then
		data.coins = math.min(data.coins + amount(r), Inventory.MAX_COINS)
	elseif r.kind == "Ticket" then
		data.tickets = math.min(data.tickets + amount(r), Economy.MAX_TICKETS)
	elseif r.kind == "Case" then
		local id = if r.case then "Case" .. r.case else ""
		local def = Inventory.ITEMS[id]
		if not def then
			return false
		end
		data.items[id] = math.min((data.items[id] or 0) + amount(r), def.maxStack)
	elseif r.kind == "Skin" then
		if not (r.gun and r.line) then
			return false
		end
		PlayerData.grantSkin(data, r.gun, r.line)
	elseif r.kind == "Charm" then
		PlayerData.grantOwned(data.charms, r.name)
	elseif r.kind == "Title" then
		PlayerData.grantOwned(data.titles, r.title or r.name)
	elseif r.kind == "Mod" then
		-- a pass power: owned and in the draft (Shared/ModLoadout.eligible)
		if not r.mod then
			return false
		end
		data.mods.owned[r.mod] = true
		data.mods.equipped[r.mod] = true
	else
		return false
	end
	return true
end

-- Claims one (tier, track): pays every reward it has and marks it. Nil when it can't be
-- claimed (tier not reached, no premium, already claimed, or nothing there).
function SeasonRewards.claim(data: PlayerData.Data, tier: number, track: SeasonPass.Track): Claimed?
	local s = data.season
	local rewards = SeasonCatalog.rewards(tier, track)
	if #rewards == 0 or not SeasonPass.canClaim(s, tier, track) then
		return nil
	end
	for _, r in rewards do
		if not SeasonRewards.grant(data, r) then
			warn(`[SeasonRewards] tier {tier} {track}: can't pay {r.kind} {r.name}`)
		end
	end
	SeasonPass.markClaimed(s, tier, track)
	return { tier = tier, track = track, rewards = rewards }
end

-- Every claimable reward reached so far, free then premium per tier.
function SeasonRewards.claimAll(data: PlayerData.Data): { Claimed }
	local out: { Claimed } = {}
	for tier = 1, data.season.tier do
		for _, track: SeasonPass.Track in { "free", "premium" } :: { SeasonPass.Track } do
			local c = SeasonRewards.claim(data, tier, track)
			if c then
				table.insert(out, c)
			end
		end
	end
	return out
end

-- Buys premium: the track opens (tiers already reached become claimable) and the premium
-- title is given. False if it was already bought.
function SeasonRewards.setPremium(data: PlayerData.Data): boolean
	if data.season.premium then
		return false
	end
	data.season.premium = true
	PlayerData.grantOwned(data.titles, Season.PREMIUM_TITLE)
	return true
end

return SeasonRewards
