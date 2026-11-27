--!strict
-- The power deck (vault/01 Design/Loadout and Power Deck.md): which powers a player owns and which of them
-- are equipped (the deck the draft deals from, at most Config/Mods DECK_SIZE). One saved and replicated
-- record (Shared/PlayerData `mods`, published as LockerMods).
--
-- Every save owns and equips Config/Mods STARTER_DECK: `starter` is the STARTER_VERSION a save last got,
-- and `clean` hands an older save (or none) the starters once, so a starter a player unequips stays off.

local Config = require(script.Parent.Config.Mods)

export type Loadout = {
	owned: { [string]: boolean },
	equipped: { [string]: boolean },
	starter: number, -- the STARTER_VERSION this loadout has had (0: never)
}

local ModLoadout = {}
ModLoadout.MAX_ID_LENGTH = 32
local MAX_OWNED = 64

function ModLoadout.equippedCount(loadout: Loadout): number
	local n = 0
	for _ in loadout.equipped do
		n += 1
	end
	return n
end

-- Owned and room in the deck (or already in it).
function ModLoadout.canEquip(loadout: Loadout, id: string): boolean
	return loadout.owned[id] == true
		and (loadout.equipped[id] == true or ModLoadout.equippedCount(loadout) < Config.DECK_SIZE)
end

-- In the deck and the deck keeps at least Config/Mods DECK_MIN without it.
function ModLoadout.canUnequip(loadout: Loadout, id: string): boolean
	return loadout.equipped[id] == true and ModLoadout.equippedCount(loadout) > Config.DECK_MIN
end

-- A new power (a case, the battle pass, an admin): owned, and in the deck while it has room.
-- False when it was already owned.
function ModLoadout.grant(loadout: Loadout, id: string): boolean
	if loadout.owned[id] then
		return false
	end
	loadout.owned[id] = true
	if ModLoadout.equippedCount(loadout) < Config.DECK_SIZE then
		loadout.equipped[id] = true
	end
	return true
end

function ModLoadout.clean(raw: unknown): Loadout
	local out: Loadout = { owned = {}, equipped = {}, starter = 0 }
	local source = if typeof(raw) == "table" then raw :: { [string]: unknown } else {}
	local equipped = if typeof(source.equipped) == "table"
		then source.equipped :: { [string]: unknown }
		else {}
	local wanted: { string } = {}
	if typeof(source.owned) == "table" then
		-- Keep unknown IDs so a server with an older catalog never drops an unlock.
		local count = 0
		for id, owned in source.owned :: { [unknown]: unknown } do
			if
				typeof(id) == "string"
				and #id <= ModLoadout.MAX_ID_LENGTH
				and owned == true
				and count < MAX_OWNED
			then
				count += 1
				out.owned[id] = true
				if equipped[id] == true then
					table.insert(wanted, id)
				end
			end
		end
	end
	-- A full deck keeps the same powers on every server: starters first, then by name.
	table.sort(wanted, function(a: string, b: string): boolean
		local sa, sb =
			table.find(Config.STARTER_DECK, a) ~= nil, table.find(Config.STARTER_DECK, b) ~= nil
		if sa ~= sb then
			return sa
		end
		return a < b
	end)
	for _, id in wanted do
		if ModLoadout.equippedCount(out) < Config.DECK_SIZE then
			out.equipped[id] = true
		end
	end
	local version = source.starter
	out.starter = if typeof(version) == "number" and version == version
		then math.floor(version)
		else 0
	if out.starter < Config.STARTER_VERSION then
		for _, id in Config.STARTER_DECK do
			ModLoadout.grant(out, id)
		end
		out.starter = Config.STARTER_VERSION
	end
	return out
end

-- In this player's draft: in the deck (owned and equipped), or a `free` power.
function ModLoadout.eligible(id: string, loadout: Loadout?): boolean
	local def = Config.defs[id]
	return def ~= nil
		and (
			def.free == true
			or (loadout ~= nil and loadout.owned[id] == true and loadout.equipped[id] == true)
		)
end

return ModLoadout
