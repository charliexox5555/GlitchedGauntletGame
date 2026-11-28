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

local RunService = game:GetService("RunService")

local ShopCatalog = require(script.Parent.ShopCatalog)
local Release = require(ReplicatedStorage.Shared.Config.Release)
local Season = require(ReplicatedStorage.Shared.Config.Season)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

-- case = a ShopCatalog case id; mod = a Config/Mods id; title = the title text;
-- randomGun = a Skin with only a line: the gun is rolled when claimed (Lobby/SeasonRewards)
export type Reward = ShopCatalog.Item & {
	case: string?,
	mod: string?,
	charm: string?,
	title: string?,
	randomGun: boolean?,
}

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
-- A line's skin for a random gun (owner 2026-11-27, like RIVALS' wraps; guns are owned now):
-- rolled at claim from the guns the player owns without that line yet.
local function skin(line: string, rarity: ShopCatalog.Rarity): Reward
	return {
		kind = "Skin",
		name = string.upper(line) .. " SKIN",
		line = line,
		rarity = rarity,
		randomGun = true,
	}
end
-- A line's skin for one named gun (the knife).
local function gunSkin(gun: string, line: string, rarity: ShopCatalog.Rarity): Reward
	return {
		kind = "Skin",
		name = string.upper(line) .. " " .. string.upper(Weapons.nameOf(gun)),
		gun = gun,
		line = line,
		rarity = rarity,
	}
end
local function charm(id: string, name: string, rarity: ShopCatalog.Rarity): Reward
	return { kind = "Charm", name = name, charm = id, rarity = rarity }
end
local function power(mod: string, name: string): Reward
	return { kind = "Mod", name = name, mod = mod, rarity = "Epic" }
end
-- a goodie bag (Config/GoodieBags): kept in the Backpack, opened for one prize
local function bag(): Reward
	return { kind = "Case", name = "GOODIE BAG", case = "GoodieBag", amount = 1, rarity = "Epic" }
end
local function title(text: string): Reward
	return { kind = "Title", name = text, title = text, rarity = "Legendary" }
end

-- Every premium tier has a reward; the free track about every third tier.
-- Coins raised 2026-11-27 (owner: guns now cost 400-6,000): premium 5,000, free 2,000.
-- Skins go to a random gun the player owns (skin()); goodie bags: see the Contents note.
SeasonCatalog.TIERS = {
	{ free = coins(200), premium = skin(ARCADE, "Rare") }, -- 1
	{ free = nil, premium = charm("Joystick", "JOYSTICK", "Rare") },
	{ free = case("Standard"), premium = coins(500) },
	{ free = nil, premium = tickets(1) },
	{ free = nil, premium = skin(ARCADE, "Rare") }, -- 5
	{ free = charm("ArcadeToken", "ARCADE TOKEN", "Common"), premium = case("Standard") },
	{ free = nil, premium = coins(650) },
	{ free = tickets(1), premium = charm("PixelHeart", "PIXEL HEART", "Rare") },
	{ free = nil, premium = skin(ARCADE, "Rare") },
	{ free = power("Smoke", "SMOKE"), premium = case("Elite") }, -- 10
	{ free = nil, premium = coins(750) },
	{ free = coins(300), premium = charm("GameCartridge", "GAME CARTRIDGE", "Epic") },
	{ free = nil, premium = skin(ARCADE, "Rare") },
	{ free = nil, premium = bag() }, -- goodie bag (owner 2026-11-27, was 2 Tickets)
	{ free = skin(ARCADE, "Rare"), premium = skin(FROSTBITE, "Legendary") }, -- 15
	{ free = nil, premium = coins(900) },
	{ free = nil, premium = charm("SnowflakeShard", "SNOWFLAKE SHARD", "Rare") },
	{ free = bag(), premium = skin(ARCADE, "Rare") }, -- goodie bag (was a Standard Case)
	{ free = nil, premium = bag() }, -- goodie bag (was an Elite Case)
	{ free = coins(400), premium = power("ElectricShock", "ELECTRIC SHOCK") }, -- 20
	{ free = nil, premium = skin(ARCADE, "Rare") },
	{ free = tickets(1), premium = coins(1000) },
	{ free = nil, premium = charm("ThunderOrb", "THUNDER ORB", "Epic") },
	{ free = nil, premium = skin(FROSTBITE, "Legendary") },
	{ free = charm("IceCube", "ICE CUBE", "Rare"), premium = case("Apex") }, -- 25
	{ free = nil, premium = skin(ARCADE, "Rare") },
	{ free = nil, premium = coins(1200) },
	{ free = coins(500), premium = charm("HighScore", "HIGH SCORE", "Legendary") },
	{ free = nil, premium = skin(FROSTBITE, "Legendary") },
	{ free = coins(600), premium = gunSkin("Knife", FROSTBITE, "Legendary") }, -- 30
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

-- Do the pass screen and its ways in (the Shop's card, the world sign) show? In live servers
-- once Release.BATTLE_PASS_OPEN; in Studio also with the Workspace attribute
-- BattlePassTest = true, to test before launch without changing what playtests look like.
function SeasonCatalog.screenOn(): boolean
	return Release.BATTLE_PASS_OPEN
		or (RunService:IsStudio() and workspace:GetAttribute("BattlePassTest") == true)
end

return SeasonCatalog
