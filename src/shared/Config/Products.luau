--!strict
-- Robux developer products (vault/01 Design/Shop Economy and Art v1.md → Step 3). Created
-- 2026-11-22 through Open Cloud on universe 10772880160; prices live on Roblox too, so a
-- price change is made on the Creator Dashboard AND here (the shop shows these numbers).
-- LobbyServer/Services/RobuxService prompts and grants them (ProcessReceipt).
--   kind "coins"   a coin pack: `coins`, plus `case` (a Config/Inventory item) where paid
--                  random items are allowed, else `caseCoins` more coins
--   kind "bundle"  a ShopCatalog bundle by `bundle` id: all its skins
--   kind "starter" the Starter Bundle, once per player: `coins` + `case` (as packs)
--   kind "skin"    one skin at this price; WHICH skin is the intent the server saved in
--                  the player's data before the prompt (daily shop slot / bundle item)
export type Kind = "coins" | "bundle" | "starter" | "skin"
export type Product = {
	id: number,
	kind: Kind,
	robux: number,
	name: string,
	coins: number?,
	case: string?,
	caseCoins: number?,
	bundle: string?,
}

local Products = {}

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
		coins = 1000,
		case = "CaseStandard",
		caseCoins = 400,
	}),
	-- one skin, by price
	table.freeze({ id = 3734910801, kind = "skin", robux = 349, name = "WEAPON SKIN" }),
	table.freeze({ id = 3734910821, kind = "skin", robux = 449, name = "WEAPON SKIN" }),
	table.freeze({ id = 3734910842, kind = "skin", robux = 649, name = "WEAPON SKIN" }),
}) :: { Product }

Products.BY_ID = {} :: { [number]: Product }
Products.PACKS = {} :: { Product }
Products.SKIN_BY_PRICE = {} :: { [number]: Product }
Products.BUNDLE = {} :: { [string]: Product }
Products.STARTER = nil :: Product?
for _, p in Products.LIST do
	Products.BY_ID[p.id] = p
	if p.kind == "coins" then
		table.insert(Products.PACKS, p)
	elseif p.kind == "skin" then
		Products.SKIN_BY_PRICE[p.robux] = p
	elseif p.kind == "bundle" and p.bundle then
		Products.BUNDLE[p.bundle] = p
	elseif p.kind == "starter" then
		Products.STARTER = p
	end
end

-- A bundle skin bought on its own (owner 2026-11-22: "more expensive", the bundle shows
-- the sum struck out): guns 349, the knife-slot item 449. Must match a "skin" product.
Products.BUNDLE_ITEM_ROBUX = table.freeze({ gun = 349, knife = 449 })

return table.freeze(Products)
