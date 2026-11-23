--!strict
-- Paid ownership and equip choices share one saved and replicated record.
-- Free abilities are granted by the catalog and need no entry in a save.

local Config = require(script.Parent.Config.Mods)

export type Loadout = {
	owned: { [string]: boolean },
	equipped: { [string]: boolean },
}

local ModLoadout = {}
ModLoadout.MAX_ID_LENGTH = 32

function ModLoadout.clean(raw: unknown): Loadout
	local out: Loadout = { owned = {}, equipped = {} }
	if typeof(raw) ~= "table" then
		return out
	end
	local source = raw :: { [string]: unknown }
	if typeof(source.owned) ~= "table" then
		return out
	end
	local equipped = if typeof(source.equipped) == "table"
		then source.equipped :: { [string]: unknown }
		else {}
	-- Keep unknown paid IDs so a server with an older catalog preserves purchases.
	for id, owned in source.owned :: { [unknown]: unknown } do
		if typeof(id) == "string" and #id <= ModLoadout.MAX_ID_LENGTH and owned == true then
			out.owned[id] = true
			if equipped[id] == true then
				out.equipped[id] = true
			end
		end
	end
	return out
end

function ModLoadout.eligible(id: string, loadout: Loadout?): boolean
	local def = Config.defs[id]
	return def ~= nil
		and (
			def.free == true
			or (loadout ~= nil and loadout.owned[id] == true and loadout.equipped[id] == true)
		)
end

return ModLoadout
