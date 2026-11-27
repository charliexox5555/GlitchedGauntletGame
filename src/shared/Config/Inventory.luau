--!strict
-- The player's saved inventory (vault/01 Design/Inventory and Crates.md): every
-- item a player can hold in their Backpack, plus the wallet numbers. Data only;
-- the Lobby's PlayerDataService saves it and Shared/PlayerData reads it.
--
-- Items are stacks: the save holds { [itemId] = count }. An id that isn't in
-- ITEMS is dropped on load, so retiring an item is a data change here (keep the
-- old id with `retired = true` if players may still hold it).
--
-- Kinds: "Case" now (a crate bought in the Shop, opened later). Keys, spins and
-- packs from the owner's Backpack reference slot in as new kinds.

export type Kind = "Case"

export type ItemDef = {
	id: string,
	kind: Kind,
	name: string, -- display name
	tier: number, -- 1 = lowest; sorts the Backpack and picks the crate colour
	case: string?, -- Case: the ShopCatalog case id it opens
	maxStack: number, -- the most one player can hold
	icon: string?, -- Backpack picture: the end-on crate render (tools/blender/crates/render_cards.py, art-source/ui/shop/crates/crate_<tier>_card.png), shared with the Shop cards
	retired: boolean?, -- no longer sold or granted; still shown if held
}

local ITEMS: { [string]: ItemDef } = {
	CaseStandard = {
		id = "CaseStandard",
		kind = "Case",
		name = "STANDARD CASE",
		tier = 1,
		case = "Standard",
		maxStack = 999,
		icon = "rbxassetid://133624978874225",
	},
	-- The free case for finishing match 1 (Config/Onboarding FIRST_MATCH_CASE): a skin for a gun they hold in match 2
	-- (Config/Skins CASES.Starter).
	-- Gift only: no ticket price (Economy.CASE_TICKETS) and no Shop card, so it can't be bought.
	CaseStarter = {
		id = "CaseStarter",
		kind = "Case",
		name = "STARTER CASE",
		tier = 2, -- the Elite crate look
		case = "Starter",
		maxStack = 1,
		icon = "rbxassetid://103320622297328", -- the Elite crate card until it has its own render
	},
	CaseElite = {
		id = "CaseElite",
		kind = "Case",
		name = "ELITE CASE",
		tier = 2,
		case = "Elite",
		maxStack = 999,
		icon = "rbxassetid://103320622297328",
	},
	CaseApex = {
		id = "CaseApex",
		kind = "Case",
		name = "APEX CASE",
		tier = 3,
		case = "Apex",
		maxStack = 999,
		icon = "rbxassetid://93123564652737",
	},
	-- knives only (owner 2026-11-20: knives got their own case)
	CaseKnife = {
		id = "CaseKnife",
		kind = "Case",
		name = "KNIFE CASE",
		tier = 4,
		case = "Knife",
		maxStack = 999,
		icon = "rbxassetid://111410900647363",
	},
	-- the first power pack (vault/01 Design/Loadout and Power Deck.md -> Power cases): a power you don't own yet,
	-- never a duplicate (Shared/PowerCases); coins or Robux (Config/Economy.POWER_PACK), Tickets where paid random
	-- items are restricted
	CasePower = {
		id = "CasePower",
		kind = "Case",
		name = "SURGE PACK",
		tier = 7, -- Config/Crates [7]: the SURGE power pack (a card pack that rips open, owner 2026-11-26)
		case = "Power",
		maxStack = 999,
		icon = "rbxassetid://88263832595455", -- art-source/ui/pack/pack_power.png
	},
}

-- the item each Shop case puts in the inventory
local BY_CASE: { [string]: string } = {}
for id, def in ITEMS do
	if def.case then
		BY_CASE[def.case] = id
	end
end

return table.freeze({
	ITEMS = table.freeze(ITEMS),
	BY_CASE = table.freeze(BY_CASE),
	BATCH_OPEN_COUNT = 3,

	-- Wallet: a new player's coins (owner 2026-11-22: "too free"; coins now come from login
	-- rewards and match pay, vault/01 Design/Shop Economy and Art v1.md).
	STARTING_COINS = 500,
	MAX_COINS = 10_000_000,

	-- Studio only: the dev "add coins" button grants this much.
	STUDIO_GRANT = 1000,

	-- How many purchase ids a save remembers, so a retried write never
	-- charges or grants twice.
	TX_MEMORY = 25,
})
