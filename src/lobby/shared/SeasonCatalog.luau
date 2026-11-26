--!strict
-- The season pass rewards (vault/01 Design/Battle Pass Season 1 Contents.md, owner-approved
-- 2026-11-26; the screen: vault/02 Art/UI Battle Pass.md): a free track everyone gets and a
-- premium track bought once per season, at most one reward per track per tier. The rules
-- (tier pace, prices, power unlocks) are Config/Season; the saved state and maths
-- Shared/SeasonPass; paying a reward Lobby/SeasonRewards.
--
-- Rewards reuse the shop's kinds (Lobby/ShopCatalog.Item) plus Ticket and Title. A "Mod"
-- reward unlocks that power for the draft (Config/Season.POWER_UNLOCKS). Roblox rules
-- (LihFolk: Battle Pass and Season Design): everyone is on the free track; a late premium
-- buyer gets the tiers already reached; unclaimed rewards are paid when the season ends.
-- Names of the new lines, charms and titles are placeholders (owner picks them later).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopCatalog = require(script.Parent.ShopCatalog)
local Season = require(ReplicatedStorage.Shared.Config.Season)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

-- case = a ShopCatalog case id; mod = a Config/Mods id; title = the title text
export type Reward = ShopCatalog.Item & { case: string?, mod: string?, title: string? }

export type Tier = {
	free: Reward?,
	premium: Reward?,
}

local SeasonCatalog = {}

SeasonCatalog.SEASON = Season.ID
SeasonCatalog.NAME = Season.NAME
SeasonCatalog.PREMIUM_ROBUX = Season.PREMIUM_ROBUX
SeasonCatalog.SKIP_ROBUX = Season.SKIP_ROBUX
SeasonCatalog.SKIP_LEVELS = Season.SKIP_TIERS
SeasonCatalog.PER_PAGE = 7
-- what the premium pass adds, shown on its card
SeasonCatalog.PREMIUM_PERKS =
	{ "THE PREMIUM TRACK", `THE {Season.PREMIUM_TITLE} TITLE`, "A GOLD NAME IN THE LOBBY" }

-- The two pass skin lines (never in cases): Arcade (Rare), Frostbite (Legendary).
local ARCADE = "Arcade"
local FROSTBITE = "Frostbite"

local function coins(n: number): Reward
	return { kind = "Coins", name = "COINS", amount = n }
end
local function tickets(n: number): Reward
	return { kind = "Ticket", name = if n == 1 then "TICKET" else "TICKETS", amount = n }
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
local function power(mod: string, name: string): Reward
	return { kind = "Mod", name = name, mod = mod, rarity = "Epic" }
end
local function title(text: string): Reward
	return { kind = "Title", name = text, title = text, rarity = "Legendary" }
end

-- Every premium tier has a reward; the free track about every third tier.
SeasonCatalog.TIERS = {
	{ free = coins(100), premium = skin("Vandal", ARCADE, "Rare") }, -- 1
	{ free = nil, premium = charm("JOYSTICK", "Rare") },
	{ free = case("Standard"), premium = coins(250) },
	{ free = nil, premium = tickets(1) },
	{ free = nil, premium = skin("Sheriff", ARCADE, "Rare") }, -- 5
	{ free = charm("ARCADE TOKEN", "Common"), premium = case("Standard") },
	{ free = nil, premium = coins(300) },
	{ free = tickets(1), premium = charm("PIXEL HEART", "Rare") },
	{ free = nil, premium = skin("Spectre", ARCADE, "Rare") },
	{ free = power("Smoke", "SMOKE"), premium = case("Elite") }, -- 10
	{ free = nil, premium = coins(350) },
	{ free = coins(150), premium = charm("GAME CARTRIDGE", "Epic") },
	{ free = nil, premium = skin("Ghost", ARCADE, "Rare") },
	{ free = nil, premium = tickets(2) },
	{ free = skin("Classic", ARCADE, "Rare"), premium = skin("Phantom", FROSTBITE, "Legendary") }, -- 15
	{ free = nil, premium = coins(400) },
	{ free = nil, premium = charm("SNOWFLAKE SHARD", "Rare") },
	{ free = case("Standard"), premium = skin("Bulldog", ARCADE, "Rare") },
	{ free = nil, premium = case("Elite") },
	{ free = coins(200), premium = power("ElectricShock", "ELECTRIC SHOCK") }, -- 20
	{ free = nil, premium = skin("Marshal", ARCADE, "Rare") },
	{ free = tickets(1), premium = coins(450) },
	{ free = nil, premium = charm("THUNDER ORB", "Epic") },
	{ free = nil, premium = skin("Outlaw", FROSTBITE, "Legendary") },
	{ free = charm("ICE CUBE", "Rare"), premium = case("Apex") }, -- 25
	{ free = nil, premium = skin("Operator", ARCADE, "Rare") },
	{ free = nil, premium = coins(500) },
	{ free = coins(250), premium = charm("HIGH SCORE", "Legendary") },
	{ free = nil, premium = skin("Vandal", FROSTBITE, "Legendary") },
	{ free = coins(300), premium = skin("Knife", FROSTBITE, "Legendary") }, -- 30
} :: { Tier }

-- Tier 30's premium track also gives the chase title (one claim pays both).
SeasonCatalog.EXTRA = {
	[30] = { premium = title("FROSTBITTEN") },
} :: { [number]: Tier }

assert(#SeasonCatalog.TIERS == Season.TIERS, "SeasonCatalog.TIERS must match Config/Season.TIERS")

-- The rewards a claim of (tier, track) pays: the tier's reward, then any EXTRA.
function SeasonCatalog.rewards(tier: number, track: "free" | "premium"): { Reward }
	local out: { Reward } = {}
	local t = SeasonCatalog.TIERS[tier]
	local main = t and t[track]
	if main then
		table.insert(out, main)
		local extra = SeasonCatalog.EXTRA[tier]
		local more = extra and extra[track]
		if more then
			table.insert(out, more)
		end
	end
	return out
end

-- PLACEHOLDER progress for the UI until phase 4 wires the server's state: level 2, part of
-- the way to 3, tier 1's free reward taken, tier 2's waiting.
SeasonCatalog.PREVIEW_PROGRESS = {
	level = 2,
	rounds = 9,
	roundsNeeded = Season.TIER_ROUNDS,
	minutes = 6.9,
	minutesNeeded = Season.TIER_SECONDS / 60,
	premium = false,
	claimed = { free = { [1] = true }, premium = {} },
}

return SeasonCatalog
