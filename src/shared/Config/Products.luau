--!strict
-- Robux developer products (vault/01 Design/Shop Economy and Art v1.md → Step 3). Created
-- 2026-11-22 through Open Cloud on universe 10772880160; prices live on Roblox too, so a
-- price change is made on the Creator Dashboard AND here (the shop shows these numbers).
-- LobbyServer/Services/RobuxService prompts and grants them (ProcessReceipt).
--   kind "coins"   a coin pack: `coins`, plus `case` (a Config/Inventory item) where paid
--                  random items are allowed, else `caseCoins` more coins
--   kind "bundle"  a ShopCatalog bundle by `bundle` id: all its skins
--   kind "starter" the Starter Bundle, once per player (owner 2026-11-27: a gun now): `coins`,
--                  the gun `gun` (its unlock price in coins if already owned), the skin
--                  `starterSkin` (`skinCoins` if already owned), plus `caseCount` x `case` and
--                  `boxCount` x `box` where paid random items are allowed, else `fallbackCoins`.
--                  (Old fields, kept for the type:) `caseCount` x `case` and
--                  `tickets` where paid random items are allowed, else `fallbackCoins` more
--                  (Tickets bought with Robux would make Ticket cases paid random too)
--   kind "case"    `count` x `case` (a Config/Inventory item) for shop case `caseId`; only
--                  prompted where paid random items are allowed (owner 2026-11-22: case
--                  prices show Robux first, Tickets as the second option)
--   kind "skin"    one skin from a fixed `skin` target or a saved purchase intent
--                  (daily shop slot / bundle item sharing a price-based product)
--   kind "season"      the season pass premium track + its title (Config/Season), once
--                      per season (2026-11-27, vault/04 Tech/Battle Pass Build Plan.md)
--   kind "seasonSkip"  Season.SKIP_TIERS more pass tiers, stopping at the last one
export type Kind = "coins" | "bundle" | "starter" | "skin" | "case" | "season" | "seasonSkip"
export type Product = {
	id: number,
	kind: Kind,
	robux: number,
	name: string,
	coins: number?,
	case: string?,
	caseCoins: number?,
	caseCount: number?,
	tickets: number?,
	fallbackCoins: number?,
	count: number?,
	caseId: string?,
	bundle: string?,
	skin: { gun: string, line: string }?,
	gun: string?,
	starterSkin: { gun: string, line: string }?,
	skinCoins: number?,
	box: string?,
	boxCount: number?,
}

local Season = require(script.Parent.Season)

local Products = {}

-- The season pass products (created 2026-11-27; prices from Config/Season).
Products.SEASON = table.freeze({
	id = 3736724862,
	kind = "season",
	robux = Season.PREMIUM_ROBUX,
	name = "PREMIUM PASS",
}) :: Product
Products.SEASON_SKIP = table.freeze({
	id = 3736724879,
	kind = "seasonSkip",
	robux = Season.SKIP_ROBUX,
	name = `+{Season.SKIP_TIERS} LEVELS`,
}) :: Product

Products.RUINED_REAVER = table.freeze({
	id = 3735030099,
	kind = "skin",
	robux = 449,
	name = "RUINED REAVER",
	skin = table.freeze({ gun = "Knife", line = "RuinBlighted" }),
}) :: Product

Products.LIST = table.freeze({
	-- coin packs, in the COINS tab's order (Pack1..Pack6)
	table.freeze({ id = 3734910889, kind = "coins", robux = 49, name = "500 COINS", coins = 500 }),
	table.freeze({
		id = 3734910909,
		kind = "coins",
		robux = 99,
		name = "1,200 COINS",
		coins = 1200,
	}),
	table.freeze({
		id = 3734910926,
		kind = "coins",
		robux = 199,
		name = "2,600 COINS",
		coins = 2600,
	}),
	table.freeze({
		id = 3734910948,
		kind = "coins",
		robux = 499,
		name = "7,000 COINS",
		coins = 7000,
		case = "CaseStandard",
		caseCoins = 400,
	}),
	table.freeze({
		id = 3734910980,
		kind = "coins",
		robux = 999,
		name = "15,000 COINS",
		coins = 15000,
		case = "CaseElite",
		caseCoins = 900,
	}),
	table.freeze({
		id = 3734911010,
		kind = "coins",
		robux = 1999,
		name = "32,000 COINS",
		coins = 32000,
		case = "CaseApex",
		caseCoins = 2000,
	}),
	-- bundles
	table.freeze({
		id = 3734910773,
		kind = "bundle",
		robux = 999,
		name = "RUIN-BLIGHTED",
		bundle = "RuinBlighted",
	}),
	table.freeze({
		id = 3734910786,
		kind = "bundle",
		robux = 1099,
		name = "TEMPEST-STRIKE",
		bundle = "TempestStrike",
	}),
	table.freeze({
		id = 3734910652,
		kind = "starter",
		robux = 67,
		name = "STARTER BUNDLE",
		-- owner 2026-11-27: the Lancer, a skin for it, a Standard Case, a Strike Box (charms) and
		-- 1,500 coins (was 2 cases + 1,500 coins + 3 Tickets)
		coins = 1500,
		gun = "Bulldog", -- the Lancer (2,500 coins to unlock)
		starterSkin = table.freeze({ gun = "Bulldog", line = "Payload" }), -- Rare, in the game
		skinCoins = 1000, -- instead of the skin when it's already owned
		case = "CaseStandard",
		caseCount = 1,
		box = "CaseStrikeBox",
		boxCount = 1,
		fallbackCoins = 800, -- instead of the case and the box where paid random items can't be sold
	}),
	-- cases (Robux first; Tickets in the case popup), one or three at a time
	table.freeze({
		id = 3734930052,
		kind = "case",
		robux = 99,
		name = "STANDARD CASE",
		case = "CaseStandard",
		caseId = "Standard",
		count = 1,
	}),
	table.freeze({
		id = 3734930066,
		kind = "case",
		robux = 199,
		name = "ELITE CASE",
		case = "CaseElite",
		caseId = "Elite",
		count = 1,
	}),
	table.freeze({
		id = 3734930086,
		kind = "case",
		robux = 399,
		name = "APEX CASE",
		case = "CaseApex",
		caseId = "Apex",
		count = 1,
	}),
	table.freeze({
		id = 3734930104,
		kind = "case",
		robux = 499,
		name = "KNIFE CASE",
		case = "CaseKnife",
		caseId = "Knife",
		count = 1,
	}),
	table.freeze({
		id = 3734930120,
		kind = "case",
		robux = 249,
		name = "3 STANDARD CASES",
		case = "CaseStandard",
		caseId = "Standard",
		count = 3,
	}),
	table.freeze({
		id = 3734930135,
		kind = "case",
		robux = 499,
		name = "3 ELITE CASES",
		case = "CaseElite",
		caseId = "Elite",
		count = 3,
	}),
	table.freeze({
		id = 3734930145,
		kind = "case",
		robux = 999,
		name = "3 APEX CASES",
		case = "CaseApex",
		caseId = "Apex",
		count = 3,
	}),
	table.freeze({
		id = 3734930160,
		kind = "case",
		robux = 1249,
		name = "3 KNIFE CASES",
		case = "CaseKnife",
		caseId = "Knife",
		count = 3,
	}),
	Products.RUINED_REAVER,
	-- shared skin products, by price
	table.freeze({ id = 3734910801, kind = "skin", robux = 349, name = "WEAPON SKIN" }),
	table.freeze({ id = 3734910821, kind = "skin", robux = 449, name = "WEAPON SKIN" }),
	table.freeze({ id = 3734910842, kind = "skin", robux = 649, name = "WEAPON SKIN" }),
	Products.SEASON,
	Products.SEASON_SKIP,
}) :: { Product }

Products.BY_ID = {} :: { [number]: Product }
Products.PACKS = {} :: { Product }
Products.SKIN_BY_PRICE = {} :: { [number]: Product }
Products.BUNDLE = {} :: { [string]: Product }
Products.STARTER = nil :: Product?
Products.CASES = {} :: { [string]: { [number]: Product } } -- [caseId][count]
for _, p in Products.LIST do
	Products.BY_ID[p.id] = p
	if p.kind == "coins" then
		table.insert(Products.PACKS, p)
	elseif p.kind == "skin" and not p.skin then
		Products.SKIN_BY_PRICE[p.robux] = p
	elseif p.kind == "bundle" and p.bundle then
		Products.BUNDLE[p.bundle] = p
	elseif p.kind == "starter" then
		Products.STARTER = p
	elseif p.kind == "case" and p.caseId and p.count then
		Products.CASES[p.caseId] = Products.CASES[p.caseId] or {}
		Products.CASES[p.caseId][p.count] = p
	end
end

-- A bundle skin bought on its own (owner 2026-11-22: "more expensive", the bundle shows
-- the sum struck out): guns 349, the knife-slot item 449. Must match a "skin" product.
Products.BUNDLE_ITEM_ROBUX = table.freeze({ gun = 349, knife = 449 })

return table.freeze(Products)
