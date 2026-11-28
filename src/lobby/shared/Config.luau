--!strict
-- Lobby numbers (vault/01 Design/Lobby UI and Queue.md): queue modes, bot
-- backfill, the match-found beat, teleport retries and remote rate limits.
-- Lobby-only, so it lives in ReplicatedStorage.Lobby rather than Shared/Config.

local Onboarding = require(game:GetService("ReplicatedStorage").Shared.Config.Onboarding)

export type Mode = "1v1" | "2v2" | "3v3" | "beginner"

export type ModeInfo = {
	id: Mode,
	teamSize: number,
	title: string,
	blurb: string,
	enabled: boolean,
	-- the Play menu tile (StarterGui.PlayMenu.Canvas.Modes child), when not named `id`
	tile: string?,
	-- seconds before bots fill this mode (else botFillAfter / botFillAfterStudio)
	fillAfter: number?,
	fillAfterStudio: number?,
	-- only players below this level may queue it (the whole party)
	maxLevel: number?,
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
	-- New players (vault/05 Production/Handoff - Onboarding and Bots.md): 2v2 where real
	-- beginners go first and bots fill the rest after 10 s; below level 10 only
	-- (Config/Onboarding.BEGINNER_MAX_LEVEL). New players are queued here on arrival.
	{
		id = "beginner",
		teamSize = 2,
		title = "BEGINNER 2V2",
		blurb = "Your first fights. Learn the ropes.",
		enabled = true,
		tile = "Beginner2v2",
		fillAfter = 5,
		fillAfterStudio = 5,
		maxLevel = Onboarding.BEGINNER_MAX_LEVEL,
	},
}

local BY_ID: { [string]: ModeInfo } = {}
local BY_TILE: { [string]: ModeInfo } = {}
for _, m in MODES do
	BY_ID[m.id] = m
	BY_TILE[m.tile or m.id] = m
end

return table.freeze({
	TEAMDATA_VERSION = 1,

	MODES = MODES,
	MODE_BY_ID = BY_ID,
	MODE_BY_TILE = BY_TILE, -- Play menu tile name → mode

	-- Seconds the oldest player in a mode waits before the match starts with
	-- bots in the empty slots. Studio uses the short value so the flow is testable.
	botFillAfter = 30,
	botFillAfterStudio = 5,

	-- The "match found" beat before the teleport (no cancel once found).
	matchFoundDelay = 2.0,
	-- Still "found" this long after the beat (reserve retries hung, an error) →
	-- back to the lobby with a message.
	foundTimeout = 20,
	-- How often the server re-checks queues for bot fill.
	tickInterval = 0.5,

	-- Teleporting (LihFolk: Teleporting and Multi-Place Games; Error Handling and
	-- Retries): attempts per player, and the backoff after a thrown TeleportAsync.
	-- Failure / Flooded results wait 2 / 10 s instead (Matchmaking/Launcher).
	teleportAttempts = 4,
	retryBackoff = { 1, 2, 4, 8 },
	-- A player still here this long after their teleport started is returned
	-- to the lobby state with a message.
	teleportTimeout = 25,
	-- Studio: how long the "would teleport" card stays before resetting.
	studioHold = 6,

	-- The Play menu's "N SEARCHING" line and dot on each mode tile (Controllers/PlayMenuController). Off (owner
	-- 2026-11-26: "I don't want people thinking that there's 0 people queuing"); back on once there are more players.
	SHOW_QUEUE_COUNTS = false,
	-- The Locker v3 (vault/01 Design/Loadout and Power Deck.md, step 2): Controllers/LockerV3Controller owns the
	-- Locker menu; false gives it back to Locker v4 (Controllers/LockerController, skins only, no gun loadout).
	LOCKER_V3 = true,
	-- Remote token buckets { perSecond, burst } (Shared/Util/RateLimit).
	-- Remote token buckets about 2x the fastest honest use; rejects are dropped
	-- and counted, never kicked (LihFolk: Rate Limiting and Abuse Prevention).
	rejectLogInterval = 60,
	RATE = {
		QueueRequest = { 2, 4 },
		PartyRequest = { 2, 6 },
		LockerRequest = { 4, 10 }, -- equips (quick clicking through skins)
		LockerModRequest = { 2, 4 }, -- saved changes to paid Mod choices
		LockerGunRequest = { 2, 4 }, -- gun unlocks (coins) and loadout equips, each a save
		ShopRequest = { 0.5, 3 }, -- purchase clicks
		ShopWrite = { 1 / 6, 5 }, -- DataStore writes from the Shop (about 10 a minute)
		SettingsRequest = { 1, 4 }, -- the client sends 1.5 s after the last change, and on close
		StreakSave = { 0.5, 2 }, -- the popup's BUY (one purchase, maybe a retry)
		LoginClaim = { 0.5, 2 }, -- the login board's CLAIM (once a day, maybe a retry)
		GroupRewardClaim = { 0.25, 2 }, -- Free Rewards CLAIM (each one asks Roblox about the group)
		RobuxRequest = { 0.5, 3 }, -- Robux BUY buttons (each opens Roblox's purchase prompt)
		SeasonRequest = { 1, 5 }, -- pass CLAIM clicks (each one is a save write)
	},

	-- Duel pads (Services/PadDuelService, place merge 2026-11-21): a pad's two
	-- halves are the two teams; full of real players, it counts down and starts
	-- the duel in this server.
	PAD = {
		tick = 0.2, -- seconds between checks of who stands on the pads
		height = 8, -- studs above the pad that still count as standing on it
		countdown = 3, -- seconds from full to the duel starting
	},

	-- In-game party invites (Services/PartyService): biggest party (the
	-- biggest team), and how long an invite stays open.
	PARTY = {
		max = 3,
		inviteTtl = 30,
	},

	-- Lobby hologram stands (Controllers/LobbyHolograms, vault/02 Art/Lobby Holograms.md; built by
	-- tools/studio/lobby_v5/BuildLobbyHolograms.luau): how the floating items move and how close the prompt works.
	HOLOGRAM = {
		range = 90, -- studs from the camera: closer stands move, farther ones hold still
		hz = 30, -- motion updates a second
		bob = 0.22, -- studs up and down
		bobPeriod = 3.4, -- seconds
		sway = 24, -- degrees either side (bundles and emblems face the hub, so they sway instead of spinning)
		swayPeriod = 8, -- seconds
		spin = 22, -- degrees a second (offers with Motion = "spin")
		promptReach = 12, -- studs: the ProximityPrompt's MaxActivationDistance
	},
})
