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
local Loadout = require(ReplicatedStorage.Shared.Config.Loadout)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Locker = require(ReplicatedStorage.Shared.Locker)
local SeasonCatalog = require(script.Parent.SeasonCatalog)

export type Claimed = { tier: number, track: SeasonPass.Track, rewards: { SeasonCatalog.Reward } }

local SeasonRewards = {}

-- A random-gun skin's gun: one the player owns without that line, else one they don't own
-- yet without it (the Locker shows it waiting on the locked gun), else nil (every gun has it).
-- Only guns the line has a model for (pass lines are built one gun at a time).
function SeasonRewards.rollGun(data: PlayerData.Data, line: string, rng: Random?): string?
	local mine, others = {}, {}
	for _, list in { Loadout.PRIMARIES, Loadout.SECONDARIES } do
		for _, id in list do
			if not PlayerData.owns(data.skins, id, line) and Locker.hasSkin(id, line) then
				table.insert(if data.guns.owned[id] then mine else others, id)
			end
		end
	end
	local pool = if #mine > 0 then mine else others
	if #pool == 0 then
		return nil
	end
	return pool[(rng or Random.new()):NextInteger(1, #pool)]
end

-- The reward as it will be paid: a random-gun skin gets its gun (and the gun's name), or
-- becomes coins when every gun already has the line. Other rewards come back as they are.
function SeasonRewards.resolve(
	data: PlayerData.Data,
	r: SeasonCatalog.Reward,
	rng: Random?
): SeasonCatalog.Reward
	if r.kind ~= "Skin" or not r.randomGun or not r.line then
		return r
	end
	local gun = SeasonRewards.rollGun(data, r.line, rng)
	if not gun then
		return { kind = "Coins", name = "COINS", amount = Season.SKIN_FALLBACK_COINS }
	end
	return {
		kind = "Skin",
		name = string.upper(r.line) .. " " .. string.upper(Weapons.nameOf(gun)),
		gun = gun,
		line = r.line,
		rarity = r.rarity,
	}
end

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
		PlayerData.grantTitle(data, r.title or r.name)
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
	local listed = SeasonCatalog.rewards(tier, track)
	if #listed == 0 or not SeasonPass.canClaim(s, tier, track) then
		return nil
	end
	local rewards: { SeasonCatalog.Reward } = {}
	for _, item in listed do
		local r = SeasonRewards.resolve(data, item)
		if not SeasonRewards.grant(data, r) then
			warn(`[SeasonRewards] tier {tier} {track}: can't pay {r.kind} {r.name}`)
		end
		table.insert(rewards, r)
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
	PlayerData.grantTitle(data, Season.PREMIUM_TITLE)
	return true
end

return SeasonRewards
