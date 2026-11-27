--!strict
-- Robux developer products (vault/01 Design/Shop Economy and Art v1.md → Step 3). Created
-- 2026-11-22 through Open Cloud on universe 10772880160; prices live on Roblox too, so a
-- price change is made on the Creator Dashboard AND here (the shop shows these numbers).
-- LobbyServer/Services/RobuxService prompts and grants them (ProcessReceipt).
--   kind "coins"   a coin pack: `coins`, plus `case` (a Config/Inventory item) where paid
--                  random items are allowed, else `caseCoins` more coins
--   kind "bundle"  a ShopCatalog bundle by `bundle` id: all its skins
--   kind "starter" the Starter Bundle, once per player: `coins`, plus `caseCount` x `case` and
--                  `tickets` where paid random items are allowed, else `fallbackCoins` more
--                  (Tickets bought with Robux would make Ticket cases paid random too)
--   kind "case"    `count` x `case` (a Config/Inventory item) for shop case `caseId`; only
--                  prompted where paid random items are allowed (owner 2026-11-22: case
--                  prices show Robux first, Tickets as the second option). caseId "Power" is
--                  the SURGE power pack: never more packs than the powers still unowned
--                  (a pack it can't give pays Economy.POWER_PACK.coins back)
-- id 0 = NOT CREATED YET on Roblox: never prompted, its Shop button stays hidden, and it isn't
-- in BY_ID. The owner creates it on the Creator Dashboard and puts the real id here.
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
		coins = 1500, -- owner 2026-11-22: 2 cases + 1,500 coins + 3 Tickets
		case = "CaseStandard",
		caseCount = 2,
		tickets = 3,
		fallbackCoins = 1100, -- instead of the cases and Tickets where they can't be sold
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
	-- the SURGE power pack (owner 2026-11-27; vault/01 Design/Loadout and Power Deck.md -> Launch
	-- plan): priced from the coin packs' best rate (32,000 for 1,999 = 16 coins a Robux), so Robux is
	-- never cheaper than coins: 1,500 coins = 94 R$ -> 99; 4,500 coins = 281 R$ -> 289 (not 279).
	table.freeze({
		id = 0, -- not created yet (owner: Creator Dashboard, "SURGE PACK", 99 R$)
		kind = "case",
		robux = 99,
		name = "SURGE PACK",
		case = "CasePower",
		caseId = "Power",
		count = 1,
	}),
	table.freeze({
		id = 0, -- not created yet (owner: Creator Dashboard, "3 SURGE PACKS", 289 R$)
		kind = "case",
		robux = 289,
		name = "3 SURGE PACKS",
		case = "CasePower",
		caseId = "Power",
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
Products.CASES = {} :: { [string]: { [number]: Product } } -- [caseId][count]; check `id ~= 0` before selling
for _, p in Products.LIST do
	if p.id ~= 0 then -- 0 = not created on Roblox yet
		Products.BY_ID[p.id] = p
	end
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
