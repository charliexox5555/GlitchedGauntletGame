--!strict
-- The kill sounds (2026-11-09) and the assist count. The kill feed and the
-- kill pop are the Studio-built KillFeed screen (KillFeedController) on every
-- device now; the old code-built feed, ELIMINATED banner and assist pop-up
-- are gone (owner 2026-11-22: "get rid of all old and unused UI").
-- Your own kills play the kill tone, a step higher for every kill in the
-- round (Config/Audio KILL_LADDER, Valorant-style); spectating, the one you
-- watch climbs their own ladder.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Audio = require(ReplicatedStorage.Shared.Config.Audio)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)

local AudioController = require(script.Parent.Parent.Controllers.AudioController)
local Watched = require(script.Parent.Watched)

local KillFeed = {}

local player = Players.LocalPlayer

-- Your kills this round (back to 0 when the round changes).
local roundKills = 0
-- Each watched fighter's kills this round.
local watchedKills: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any

pcall(function() -- the range has no match state
	MatchState.changed("Round"):Connect(function()
		roundKills = 0
		table.clear(watchedKills)
	end)
end)

-- The "Killed" event's assist list → how many assisted and whether you did.
function KillFeed.assistInfo(payload: unknown): (number, boolean)
	local count, mine = 0, false
	if typeof(payload) == "table" then
		for _, id in payload do
			if typeof(id) == "number" then
				count += 1
				mine = mine or (id ~= 0 and id == player.UserId)
			end
		end
	end
	return count, mine
end

-- The server's "Killed" event: plays the kill tone for your kills (and the
-- watched fighter's).
function KillFeed.kill(
	victim: unknown,
	attacker: unknown,
	_sourceId: unknown,
	headshot: unknown,
	_assistIds: unknown
)
	local v = if typeof(victim) == "Instance" then victim else nil
	local a = if typeof(attacker) == "Instance" then attacker else nil
	local head = headshot == true
	local kills: number? = nil
	if a == player then
		roundKills += 1
		kills = roundKills
	elseif a and Watched.is(a) and not Watched.is(v) then
		local holder = Watched.get()
		if holder then
			kills = (watchedKills[holder] or 0) + 1
			watchedKills[holder] = kills
		end
	end
	if kills then
		local step = math.min(kills, #Audio.KILL_LADDER)
		-- A learned signature cue: its pitch is the ladder step, never jittered.
		AudioController.play(if head then Sounds.KillHead else Sounds.Kill, {
			group = "Feedback",
			volume = Audio.KILL_VOLUME,
			pitch = Audio.KILL_LADDER[step],
			jitter = false,
		})
	end
end

return KillFeed
