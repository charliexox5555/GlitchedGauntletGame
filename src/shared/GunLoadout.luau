--!strict
-- The gun loadout (vault/01 Design/Loadout and Power Deck.md → "Step 2 plan"): which guns a player owns and
-- which primary + secondary they take into matches. One saved and replicated record (Shared/PlayerData `guns`,
-- published as LockerGuns). Config/Loadout holds the active set, the starter pair and the prices.

local Config = require(script.Parent.Config.Loadout)

export type Slot = "Primary" | "Secondary"
export type Loadout = {
	owned: { [string]: boolean },
	primary: string,
	secondary: string,
}

local GunLoadout = {}
GunLoadout.MAX_ID_LENGTH = 24
local MAX_OWNED = 64

-- "Primary" / "Secondary" for a gun in the active set, nil for any other id (parked guns, the knife).
function GunLoadout.slotOf(id: string): Slot?
	if table.find(Config.PRIMARIES, id) then
		return "Primary"
	elseif table.find(Config.SECONDARIES, id) then
		return "Secondary"
	end
	return nil
end

function GunLoadout.price(id: string): number?
	return Config.PRICES[id]
end

-- Owned and in the active set.
function GunLoadout.canEquip(loadout: Loadout, id: string): boolean
	return loadout.owned[id] == true and GunLoadout.slotOf(id) ~= nil
end

-- In the active set, for sale, and not owned yet.
function GunLoadout.canUnlock(loadout: Loadout, id: string): boolean
	return GunLoadout.slotOf(id) ~= nil and Config.PRICES[id] ~= nil and loadout.owned[id] ~= true
end

-- Puts an owned gun into its slot. False when it can't be equipped.
function GunLoadout.equip(loadout: Loadout, id: string): boolean
	if not GunLoadout.canEquip(loadout, id) then
		return false
	end
	if GunLoadout.slotOf(id) == "Primary" then
		loadout.primary = id
	else
		loadout.secondary = id
	end
	return true
end

-- A clean loadout from anything (a save, a replica, nil): the starters are always owned, unknown ids are kept
-- (a server with an older catalog never drops an unlock), and an equipped gun that isn't owned or isn't in
-- the active set falls back to the starter for its slot.
function GunLoadout.clean(raw: unknown): Loadout
	local out: Loadout = {
		owned = { [Config.STARTER.Primary] = true, [Config.STARTER.Secondary] = true },
		primary = Config.STARTER.Primary,
		secondary = Config.STARTER.Secondary,
	}
	local source = if typeof(raw) == "table" then raw :: { [string]: unknown } else {}
	if typeof(source.owned) == "table" then
		local count = 0
		for id, owned in source.owned :: { [unknown]: unknown } do
			if
				typeof(id) == "string"
				and #id <= GunLoadout.MAX_ID_LENGTH
				and owned == true
				and count < MAX_OWNED
			then
				count += 1
				out.owned[id] = true
			end
		end
	end
	local p, s = source.primary, source.secondary
	if typeof(p) == "string" and out.owned[p] and GunLoadout.slotOf(p) == "Primary" then
		out.primary = p
	end
	if typeof(s) == "string" and out.owned[s] and GunLoadout.slotOf(s) == "Secondary" then
		out.secondary = s
	end
	return out
end

-- The guns a round hands out: rounds 1..SECONDARY_ROUNDS only the secondary (primary nil).
function GunLoadout.forRound(loadout: Loadout, round: number): (string?, string)
	if round <= Config.SECONDARY_ROUNDS then
		return nil, loadout.secondary
	end
	return loadout.primary, loadout.secondary
end

-- A random owned-anything loadout from the active set (bots).
function GunLoadout.random(rng: Random?): Loadout
	local r = rng or Random.new()
	local p = Config.PRIMARIES[r:NextInteger(1, #Config.PRIMARIES)]
	local s = Config.SECONDARIES[r:NextInteger(1, #Config.SECONDARIES)]
	return { owned = { [p] = true, [s] = true }, primary = p, secondary = s }
end

return GunLoadout
