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
	icon: string?, -- Backpack / Shop picture (rendered from the 3D crate: tools/blender/crates/render_icons.py)
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
		icon = "rbxassetid://106773240441152",
	},
	CaseElite = {
		id = "CaseElite",
		kind = "Case",
		name = "ELITE CASE",
		tier = 2,
		case = "Elite",
		maxStack = 999,
		icon = "rbxassetid://81160532398415",
	},
	CaseApex = {
		id = "CaseApex",
		kind = "Case",
		name = "APEX CASE",
		tier = 3,
		case = "Apex",
		maxStack = 999,
		icon = "rbxassetid://129794608887439",
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

	-- Wallet. PLACEHOLDER until coins are earned in matches: a new player
	-- starts with enough to try the Shop.
	STARTING_COINS = 2500,
	MAX_COINS = 10_000_000,

	-- Studio only: the dev "add coins" button grants this much.
	STUDIO_GRANT = 1000,

	-- How many purchase ids a save remembers, so a retried write never
	-- charges or grants twice.
	TX_MEMORY = 25,
})
