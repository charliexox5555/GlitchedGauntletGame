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

-- Each match's SpectateService `watching` table (several matches can run in
-- one server since the place merge), by match id.
local byMatch: { [string]: { [Player]: Instance } } = {}

-- Rebuilds the index from a SpectateService's `watching` (a handful of entries).
function Spectated.sync(watching: { [Player]: Instance }, matchId: string?)
	byMatch[matchId or "server"] = table.clone(watching)
	table.clear(watched)
	for _, each in byMatch do
		for spectator, target in each do
			local list = watched[target]
			if not list then
				list = {}
				watched[target] = list
			end
			table.insert(list, spectator)
		end
	end
end

-- A match ended: forget its spectators.
function Spectated.forget(matchId: string)
	byMatch[matchId] = nil
	Spectated.sync({}, matchId)
	byMatch[matchId] = nil
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
