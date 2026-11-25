--!strict
-- The season pass (vault/02 Art/UI Battle Pass.md): a free track everyone
-- gets and a premium track bought once per season, one reward per track per
-- tier. Season levels are separate from your game level and come from
-- playing this season (the rule is the owner's call later: wins or minutes).
-- PLACEHOLDER content and numbers; the economy will read this table and own
-- each player's level, progress and claims on the server.
--
-- Rewards reuse the shop's kinds (Lobby/ShopCatalog.Item): coins, cases (which
-- show their odds, like the shop's), skins (from our skin lines), charms,
-- emotes. Roblox rules (LihFolk: Battle Pass and Season Design): everyone is
-- on the free track; a late premium buyer gets the tiers already reached;
-- unclaimed rewards are granted when the season ends.

local ShopCatalog = require(script.Parent.ShopCatalog)

export type Reward = ShopCatalog.Item & { case: string? } -- case = a ShopCatalog case id

export type Tier = {
	free: Reward?,
	premium: Reward?,
}

local Weapons = require(game:GetService("ReplicatedStorage").Shared.Config.Weapons)

local SeasonCatalog = {}

SeasonCatalog.SEASON = 1
SeasonCatalog.NAME = "SEASON 1"
SeasonCatalog.PREMIUM_ROBUX = 689 -- the premium pass
SeasonCatalog.SKIP_ROBUX = 499 -- +5 levels
SeasonCatalog.SKIP_LEVELS = 5
SeasonCatalog.PER_PAGE = 7
-- what the premium pass adds, shown on its card
SeasonCatalog.PREMIUM_PERKS = { "THE PREMIUM TRACK", "A GOLD NAME IN THE LOBBY" }

local function coins(n: number): Reward
	return { kind = "Coins", name = "COINS", amount = n }
end
local function case(id: string): Reward
	local c = ShopCatalog.case(id)
	return { kind = "Case", name = if c then c.name else id, case = id, amount = 1 }
end
local function skin(gun: string, line: string, rarity: ShopCatalog.Rarity): Reward
	return {
		kind = "Skin",
		name = string.upper(line) .. " " .. string.upper(Weapons.nameOf(gun)),
		gun = gun,
		line = line,
		rarity = rarity,
	}
end
local function charm(name: string, rarity: ShopCatalog.Rarity): Reward
	return { kind = "Charm", name = name, rarity = rarity }
end
local function emote(name: string, rarity: ShopCatalog.Rarity): Reward
	return { kind = "Emote", name = name, rarity = rarity }
end

-- 30 tiers (placeholder): something on the free track every other tier,
-- something on premium every tier, a big skin every fifth.
SeasonCatalog.TIERS = {
	{ free = coins(100), premium = skin("Classic", "Redline", "Rare") },
	{ free = case("Standard"), premium = coins(250) },
	{ free = nil, premium = charm("SPARK PLUG", "Rare") },
	{ free = coins(150), premium = case("Standard") },
	{ free = nil, premium = skin("Vandal", "Nitrous", "Epic") },
	{ free = charm("BOLT", "Common"), premium = coins(300) },
	{ free = nil, premium = emote("SALUTE", "Rare") },
	{ free = coins(200), premium = case("Elite") },
	{ free = nil, premium = skin("Spectre", "PopCircuit", "Rare") },
	{ free = case("Standard"), premium = skin("Sheriff", "Giltfold", "Epic") },
	{ free = nil, premium = coins(400) },
	{ free = coins(250), premium = charm("NEON FANG", "Epic") },
	{ free = nil, premium = case("Elite") },
	{ free = emote("WAVE", "Common"), premium = skin("Bucky", "Sealwork", "Rare") },
	{ free = nil, premium = skin("Operator", "Moltframe", "Legendary") },
	{ free = coins(300), premium = coins(500) },
	{ free = nil, premium = emote("TAKE A BOW", "Epic") },
	{ free = case("Standard"), premium = case("Elite") },
	{ free = nil, premium = skin("Guardian", "Payload", "Epic") },
	{ free = coins(350), premium = skin("Vandal", "Inkshift", "Legendary") },
	{ free = nil, premium = coins(600) },
	{ free = charm("OLD COIN", "Rare"), premium = charm("CROWN", "Legendary") },
	{ free = nil, premium = case("Apex") },
	{ free = coins(400), premium = skin("Shorty", "Prism", "Epic") },
	{ free = nil, premium = skin("Phantom", "Giltfold", "Legendary") },
	{ free = case("Elite"), premium = coins(800) },
	{ free = nil, premium = emote("VICTORY LAP", "Legendary") },
	{ free = coins(500), premium = case("Apex") },
	{ free = nil, premium = charm("SEASON ONE", "Legendary") },
	{ free = case("Elite"), premium = skin("Vandal", "Prism", "Legendary") },
} :: { Tier }

-- PLACEHOLDER progress for the UI until the server owns it: level 2, part of
-- the way to 3, tier 1's free reward taken, tier 2's waiting.
SeasonCatalog.PREVIEW_PROGRESS = {
	level = 2,
	rounds = 9,
	roundsNeeded = 25,
	minutes = 6.9,
	minutesNeeded = 20,
	premium = false,
	claimed = { free = { [1] = true }, premium = {} },
}

return SeasonCatalog
