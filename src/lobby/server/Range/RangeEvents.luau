--!strict
-- What a player did in the Range, for the task Path (Services/TaskService). Only server code fires these, from
-- server decisions: RangeService (walked in), Range/RangeTargets (an air target broke), Range/RangeBots (a
-- training bot went down, with the loadout slot of the gun that did it, if a primary or secondary). No remote.

export type Kind = "visit" | "target" | "bot"
export type Slot = "Primary" | "Secondary"
type Listener = (player: Player, kind: Kind, slot: Slot?) -> ()

local RangeEvents = {}

local listeners: { Listener } = {}

function RangeEvents.connect(fn: Listener)
	table.insert(listeners, fn)
end

function RangeEvents.fire(player: Player, kind: Kind, slot: Slot?)
	for _, fn in listeners do
		local ok, err = pcall(fn, player, kind, slot)
		if not ok then
			warn("[RangeEvents] listener failed:", err)
		end
	end
end

return RangeEvents
