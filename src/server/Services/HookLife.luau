--!strict
-- Hooks a match kit adds to a shared service (HealthService.onDowned, the Damage hit listeners, guards
-- and modifiers, WeaponService.onShot / onRays) outlive the kit: the lists are shared and had no way to
-- unregister, so every finished pad duel or hosted match left its closures (and the kit's whole module
-- state) in them, and every hit and down still walked them (code audit 2026-11-27).
-- MatchKit/Context.filtered marks each wrapper it makes with its match's liveness; the shared lists
-- call prune() when a hook is added, which drops the ones whose match has ended. No cost per event.

local HookLife = {}

-- wrapper -> "is its match over?" (weak keys: a wrapper nobody holds goes too)
local ended: { [any]: () -> boolean } = setmetatable({}, { __mode = "k" }) :: any

function HookLife.mark(fn: any, isOver: () -> boolean)
	ended[fn] = isOver
end

-- Removes the hooks whose match has ended, in place.
function HookLife.prune(list: { any })
	for i = #list, 1, -1 do
		local isOver = ended[list[i]]
		if isOver and isOver() then
			table.remove(list, i)
		end
	end
end

return HookLife
