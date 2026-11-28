--!strict
-- Goodie bags (vault/01 Design/Battle Pass Season 1 Contents.md; owner 2026-11-27): a battle pass reward kept
-- in the Backpack and opened like a case, paying ONE prize. Mostly coins, sometimes Tickets; rarer a charm box
-- or a power pack (they land in the Backpack to open); rarest a Standard Case or an Arcade skin for a random gun.
-- Weights are relative (the odds shown are weight / total). Lobby/GoodieBags rolls them; tune here.

export type Prize = {
	id: string, -- stable key (odds rows, telemetry)
	kind: "Coins" | "Ticket" | "Item" | "Skin",
	weight: number,
	min: number?, -- Coins / Ticket: the amount is rolled in [min, max] (Coins in steps of `step`)
	max: number?,
	step: number?,
	item: string?, -- Item: the Config/Inventory item id it adds to the Backpack
	line: string?, -- Skin: the line; the gun is rolled like the pass's random-gun skins (Lobby/SeasonRewards.rollGun)
	name: string, -- the odds row's name
}

export type Bag = { id: string, name: string, prizes: { Prize } }

local BAGS: { [string]: Bag } = {
	GoodieBag = {
		id = "GoodieBag",
		name = "GOODIE BAG",
		prizes = {
			{
				id = "Coins",
				kind = "Coins",
				weight = 58,
				min = 300,
				max = 800,
				step = 50,
				name = "COINS",
			},
			{ id = "Tickets", kind = "Ticket", weight = 18, min = 1, max = 2, name = "TICKETS" },
			{
				id = "CharmBox",
				kind = "Item",
				weight = 9,
				item = "CaseStrikeBox",
				name = "STRIKE BOX",
			},
			{
				id = "PowerPack",
				kind = "Item",
				weight = 7,
				item = "CasePower",
				name = "SURGE PACK",
			},
			{
				id = "Case",
				kind = "Item",
				weight = 5,
				item = "CaseStandard",
				name = "STANDARD CASE",
			},
			{ id = "Skin", kind = "Skin", weight = 3, line = "Arcade", name = "ARCADE SKIN" },
		},
	},
}

return table.freeze({
	BAGS = BAGS,
	-- a skin prize when every gun already has the line pays these coins instead
	SKIN_FALLBACK_COINS = 800,
})
