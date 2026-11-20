--!strict
-- Who is spectating whom right now (bots' models and players). SpectateService fills it
-- from its spectator → target table; Brain reads it so a bot publishes its
-- 30 Hz gun look (`AimGunYaw` / `AimGunPitch`) only while it has a viewer
-- (vault/05 Production/Spectate Replay Fix Plan.md, A review fixes). Its own
-- module so Brain doesn't need SpectateService (that requires BotService,
-- which requires Brain).

local Spectated = {}

-- target (a Player or a bot's model) → the players spectating it
local watched: { [Instance]: { Player } } = {}
local NONE: { Player } = table.freeze({})

-- Rebuilds the index from SpectateService's `watching` (a handful of entries).
function Spectated.sync(watching: { [Player]: Instance })
	table.clear(watched)
	for spectator, target in watching do
		local list = watched[target]
		if not list then
			list = {}
			watched[target] = list
		end
		table.insert(list, spectator)
	end
end

-- Whether anyone is spectating this target (a bot's model, or a Player).
function Spectated.has(target: Instance): boolean
	return watched[target] ~= nil
end

-- Who is spectating this target (Services/LookStream relays to them). Read
-- only: the list is rebuilt on the next sync.
function Spectated.watchersOf(target: Instance): { Player }
	return watched[target] or NONE
end

return Spectated
