--!strict
-- Lobby numbers (vault/01 Design/Lobby UI and Queue.md): queue modes, bot
-- backfill, the match-found beat, teleport retries and remote rate limits.
-- Lobby-only, so it lives in ReplicatedStorage.Lobby rather than Shared/Config.

export type Mode = "1v1" | "2v2" | "3v3"

export type ModeInfo = {
	id: Mode,
	teamSize: number,
	title: string,
	blurb: string,
	enabled: boolean,
}

local MODES: { ModeInfo } = {
	{
		id = "1v1",
		teamSize = 1,
		title = "1V1",
		blurb = "Pure aim duel. Nowhere to hide.",
		enabled = true,
	},
	{
		id = "2v2",
		teamSize = 2,
		title = "2V2",
		blurb = "Trade, peek, cover your partner.",
		enabled = true,
	},
	{
		id = "3v3",
		teamSize = 3,
		title = "3V3",
		blurb = "Full squads. Combo your Mods.",
		enabled = true,
	},
}

local BY_ID: { [string]: ModeInfo } = {}
for _, m in MODES do
	BY_ID[m.id] = m
end

return table.freeze({
	MATCH_PLACE_ID = 71551303511506,
	TEAMDATA_VERSION = 1,

	MODES = MODES,
	MODE_BY_ID = BY_ID,

	-- Seconds the oldest player in a mode waits before the match starts with
	-- bots in the empty slots. Studio uses the short value so the flow is testable.
	botFillAfter = 30,
	botFillAfterStudio = 5,

	-- The "match found" beat before the teleport (no cancel once found).
	matchFoundDelay = 3.5,
	-- How often the server re-checks queues for bot fill.
	tickInterval = 0.5,

	-- Reserving a Match server and teleporting: attempts and backoff (seconds).
	reserveAttempts = 3,
	teleportAttempts = 3,
	retryBackoff = { 1, 2, 4 },
	-- A player still here this long after their teleport started is returned
	-- to the lobby state with a message.
	teleportTimeout = 25,
	-- Studio: how long the "would teleport" card stays before resetting.
	studioHold = 6,

	-- Remote token buckets { perSecond, burst } (Shared/Util/RateLimit).
	RATE = {
		QueueRequest = { 2, 4 },
	},
})
