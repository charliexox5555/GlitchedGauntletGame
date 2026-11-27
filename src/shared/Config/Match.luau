--!strict
-- The match: timers, the round win, weapon phases and the draft
-- (vault/01 Design/Match Flow.md). Replicated: nothing secret here.

-- A weapon phase: which guns a round hands out (Shared/GunLoadout.forRound) and its shield.
export type Phase = {
	name: string,
	label: string, -- the 3-2-1 banner's line ("Sidearms only")
	tier: number,
	fromRound: number,
	flatShield: number?,
	shieldByGun: { [string]: number }?,
}
export type MapEntry = { id: string, minTeam: number, maxTeam: number, name: string?, image: string? }

return table.freeze({
	MAP = "Arena", -- the default map: a Model in ServerStorage.Maps (or still in Workspace)
	-- The merged lobby and range are below the arenas. Leave enough horizontal
	-- room for two neighboring copies of the 6144-stud map backdrops.
	ARENA_Y = 800,
	ARENA_SPACING = 6600,
	-- The map pool (vault/01 Design/Maps/00 Maps.md → Roster): before each match one
	-- installed map is picked at random among those that fit the bigger team
	-- (minTeam..maxTeam players), not the last one when there's a choice. Big
	-- maps take over from 3v3 (like RIVALS). In Studio the Workspace attribute
	-- "LockMap" (a map id or its vote name, any case: "Snowpeak", "metro") plays
	-- that map every match with no vote; clear it to vote again. "ForceMap"
	-- (GauntletState, an exact id) still works too.
	-- `image`: the map vote card's picture (art-source/ui/mapvote/release, captured in
	-- Studio 2026-11-23, uploaded with tools/opencloud/upload_asset.py; these are the Image ids
	-- behind the uploaded Decals, resolved with InsertService).
	MAPS = {
		-- The release lineup (owner 2026-11-21). The legacy maps (Whitebox, Rooftops 1-3, Bunker 1-3, ...)
		-- were deleted from the place on 2026-11-21 (vault/01 Design/Maps/Release Map Audit 2026-11-21.md).
		{ id = "Arena", minTeam = 1, maxTeam = 2, image = "rbxassetid://117792603299694" },
		{ id = "Pier", minTeam = 1, maxTeam = 2, image = "rbxassetid://74497025627817" },
		{ id = "Wharf", minTeam = 1, maxTeam = 2, image = "rbxassetid://95866458500130" }, -- 2026-11-20, vault/01 Design/Maps/Wharf.md
		{
			id = "Snowpeak4",
			name = "Snowpeak",
			minTeam = 1,
			maxTeam = 2,
			image = "rbxassetid://120626848953348",
		}, -- 2026-11-21, vault/01 Design/Maps/Snowpeak4.md
		{
			id = "Rooftops4",
			name = "Rooftops",
			minTeam = 1,
			maxTeam = 2,
			image = "rbxassetid://85741001633716",
		}, -- 2026-11-21, vault/01 Design/Maps/Rooftops4.md
		{
			id = "Greenhouse4",
			name = "Greenhouse",
			minTeam = 1,
			maxTeam = 2,
			image = "rbxassetid://92559937963235",
		}, -- 2026-11-21, vault/01 Design/Maps/Greenhouse4.md
		{
			id = "Foundry4",
			name = "Foundry",
			minTeam = 1,
			maxTeam = 2,
			image = "rbxassetid://84516040520052",
		}, -- 2026-11-21, vault/01 Design/Maps/Foundry4.md
		{
			id = "CanyonOutpost",
			name = "Canyon",
			minTeam = 1,
			maxTeam = 2,
			image = "rbxassetid://90705379708487",
		}, -- 2026-11-21, vault/01 Design/Maps/CanyonOutpost.md
		{
			id = "BigArena",
			name = "Big Arena",
			minTeam = 2,
			maxTeam = 3,
			image = "rbxassetid://135241582210473",
		},
		{ id = "Dockyard", minTeam = 2, maxTeam = 3, image = "rbxassetid://98967879678346" },
		{
			id = "Metro4",
			name = "Metro",
			minTeam = 2,
			maxTeam = 3,
			image = "rbxassetid://101932680871062",
		}, -- 2026-11-20, vault/01 Design/Maps/Metro4.md
		{
			id = "OldTown4",
			name = "Old Town",
			minTeam = 2,
			maxTeam = 3,
			image = "rbxassetid://128661003913332",
		}, -- 2026-11-21, vault/01 Design/Maps/OldTown4.md
	} :: { MapEntry },

	-- The map vote before round 1 (vault/02 Art/UI Match Overhaul.md, after
	-- RIVALS' duels): every map in MAPS that fits the bigger team, plus Random.
	-- Each vote is a ticket and one is drawn (no votes = any map). Skipped when
	-- only one map fits, or in Studio with ForceMap.
	VOTE = table.freeze({
		seconds = 10, -- the vote
		allInSeconds = 1.5, -- once every player has voted, the clock cuts to this
		botDelay = { 1.2, 4.8 },
		withBotsMinSeconds = 4.5,
		chosenSeconds = 2, -- the picked map is shown, then the map loads
		random = "Random", -- the Random card's option name
	}),

	ROUNDS_TO_WIN = 5,
	ROUNDS_TO_WIN_BY_MODE = table.freeze({ beginner = 4 }) :: { [string]: number },
	-- A player's very first match (Beginner, every real player on 0 matches): shorter still (owner 2026-11-25,
	-- onboarding funnel: players left between rounds of match 1).
	FIRST_MATCH_ROUNDS_TO_WIN = 3,
	-- Onboarding matches (owner 2026-11-25, vault/05 Production/Fantasy and Retention Plan 2026-11-25.md): a Beginner
	-- match where every real player has fewer saved matches than this. It is first to FIRST_MATCH_ROUNDS_TO_WIN
	-- (match 2 lost a third of players at first to 4) and shows the better guns early: round N deals the weapon
	-- phase of round ONBOARDING_PHASE_ROUNDS[N] (later rounds: the last entry); Config/Onboarding HANDED_GUNS
	-- reads the same boosted round.
	ONBOARDING_MATCHES = 2,
	ONBOARDING_PHASE_ROUNDS = { 2, 4, 4, 7, 7 } :: { number },
	LATE_SPAWN_WAIT = 6, -- seconds a slow spawn gets past the countdown (3 until 2026-11-22: void spawns)
	-- Seconds a player's own screen gets past the countdown to show their fighter (owner 2026-11-25: "camera in
	-- the void, spectate the other bots for a second, and then finally load in"). The server can have the body while
	-- a slow device hasn't got it yet; the client says so (BodyReady, Controllers/FloorHoldController) once its own
	-- fighter is there with floor under it, and the fight waits for that. The select also won't skip early for it.
	BODY_READY_WAIT = 12,
	-- Seconds a live waiting match may stall before cancelling & requeueing everyone. 22 until 2026-11-25: a phone
	-- still loading was cancelled (Config/Bots ALL_LOADING_TIMEOUT); a missing seat is filled by a bot long before.
	LOAD_CANCEL_TIMEOUT = 45,
	MAP_LOAD_TIMEOUT = 15, -- seconds initial map load may retry with players waiting before cancelling & requeueing
	-- Floor hold (Controllers/FloorHoldController, owner 2026-11-22: "in a void ... every round ends right
	-- away in a draw"): a fighter spawned before the map reached their screen is held still (root anchored on
	-- their client) until floor shows up under them, for at most `max` seconds; `probe` studs down.
	FLOOR_HOLD = table.freeze({ probe = 60, max = 15, check = 0.1 }),
	MAX_EMPTY_ROUNDS = 3, -- rounds in a row with a side nobody could spawn on: the match ends
	MAX_ROUND_ERRORS = 3, -- rounds in a row that stopped on a script error: the match ends on the score (MatchService)
	KILL_DEPTH = 40, -- studs below a map's pivot that count as falling off (a map can set KillDepth)
	ASSIST_WINDOW = 10, -- seconds before a kill that damage still earns an assist (StatsService)

	-- Seconds (vault/05 Production/Match Structure Revamp.md). The select
	-- screen opens as soon as the first player is in. Its time includes the
	-- 3-2-1 at the end (guns in hand, barrier up). Every select skips to the
	-- 3-2-1 once everyone has locked in.
	-- Shorter gaps (owner 2026-11-26, MatchLeft: 71% of mid-match quits were between rounds, 39% on the pick
	-- screen): 22 → 16, 12 → 9, Beginner 9 → 8.
	FIRST_SELECT_TIME = 16,
	SELECT_TIME = 9,
	-- Per mode, the select after round 1 (owner 2026-11-25: the gaps between rounds lost new players). Still skips
	-- to the 3-2-1 once everyone has locked in.
	SELECT_TIME_BY_MODE = table.freeze({ beginner = 8 }) :: { [string]: number },
	COUNTDOWN_TIME = 3,
	-- Spawn hold (vault/01 Design/Spawn Hold.md, 2026-11-16): through the select
	-- and the 3-2-1 everyone stands at their spawn marker, can look but not
	-- move or jump (Simulation/Movement), and other fighters show as ghosts
	-- (SpawnHoldController). Shots and Mods are already off (CombatLocked).
	SPAWN_HOLD = table.freeze({
		ghost = 0.6, -- LocalTransparencyModifier on other fighters' bodies
		refresh = 0.25, -- seconds between passes that catch late spawns
	}),
	ROUND_TIME = 50, -- then sudden death
	ROUND_END_TIME = 2.5, -- 4 → 2.5 (2026-11-26, shorter gaps)
	ROUND_END_TIME_BY_MODE = table.freeze({ beginner = 2 }) :: { [string]: number },
	-- After the match's last kill (owner 2026-11-25: no final-kill replay): the loser's fall plays out and the
	-- winner can move about for this long, then straight into the win cutscene (MatchEnd).
	MATCH_END_PAUSE = 2.5,
	-- The match-end screen (Services/MatchEndService): `time` seconds to pick
	-- Rematch / Play Again / Leave, then everyone left goes to the Lobby.
	MATCH_END = {
		time = 20,
		-- A match with no rematch (a new player's in-server onboarding matches): the 8.15 s win cutscene, then a
		-- short look at the results before the lobby (owner 2026-11-25: the 20 s wait lost new players). 13 → 18
		-- (2026-11-26): ~10 s to press NEXT MATCH, now that the choice matters (vault/01 Design/First Ten Minutes.md).
		timeNoRematch = 18,
		botRematchChance = 0.94,
		botRematchDelay = { 0.8, 3 },
		teleportAttempts = 3,
		retryBackoff = { 1, 2, 4 },
		emptyWait = 30, -- time to retry Lobby teleports after the results screen
	},

	-- Sudden death: when the round clock runs out, a circle closes on the
	-- map's middle (a `ZoneCentre`-tagged part in the map, else halfway between
	-- the team spawns). It starts past the furthest spawn (×startScale, or the
	-- centre part's `ZoneRadius` attribute), shrinks over `shrinkTime` to
	-- `endRadius` and stays. Outside it you lose health straight away (the
	-- shield doesn't absorb it): `damage` per second, +`damageStep` every
	-- `stepEvery` seconds. Past `maxTime` the old health compare ends the round.
	SUDDEN_DEATH = {
		shrinkTime = 20,
		endRadius = 4,
		startScale = 1.6,
		damage = 10,
		damageStep = 5,
		stepEvery = 5,
		tick = 0.25,
		maxTime = 60,
	},

	-- The final-kill replay (Controllers/ReplayController): when a round's
	-- elimination wins the match, every client replays the last moments from
	-- `before` seconds before the kill to `after` after, at normal speed until
	-- `slowFrom` before the kill, then at `slowSpeed`. It starts `delay` after
	-- the server says so (all clients together) and holds `hold` at the end.
	-- `beat`: seconds after the kill before the replay phase. `buffer`: seconds
	-- each client keeps recorded, `rate`: frames per second.
	REPLAY = {
		-- Off (owner 2026-11-25): the match ends on a short beat and the win cutscene (MATCH_END_PAUSE); MatchService
		-- no longer sends a replay, and clients don't record one. The player below stays for if it comes back.
		enabled = false,
		before = 2.9,
		after = 0.55, -- seconds after the kill (the fall plays out; was 0.3)
		slowFrom = 0.4,
		slowSpeed = 0.3,
		slowRamp = 0.25, -- playback seconds the speed eases from 1 down to slowSpeed (no step into slow motion)
		-- Seen from the victim's eyes (a fall, the zone or a Mod kill), their
		-- death stays first person: over `time` recorded seconds the eye sinks
		-- `drop` studs, the view tips to `pitch` radians and rolls `roll`.
		deathView = { time = 0.45, drop = 2.4, pitch = -0.55, roll = 0.45 },
		delay = 0.3,
		hold = 0.6,
		beat = 0.8,
		buffer = 6,
		rate = 30,
		recentKill = 1, -- seconds: the losing side's last down must be this recent (elimination ends the round within 0.1 s)
	},

	-- The gun loadout (vault/01 Design/Loadout and Power Deck.md, step 2; was four tiers with a gun row in the
	-- draft): round 1 hands out only your secondary (its own shield, Config/Weapons), later rounds your primary
	-- and secondary with a flat 50 shield. Config/Loadout SECONDARY_ROUNDS says how many rounds are sidearm only;
	-- keep it in step with Loadout's fromRound.
	PHASES = {
		{ name = "Sidearm", label = "Sidearms only", tier = 1, fromRound = 1 },
		{ name = "Loadout", label = "Full loadout", tier = 2, fromRound = 2, flatShield = 50 },
	} :: { Phase },
	ABILITY_LEVEL = "L1", -- a newly drafted ability's level
	-- Upgrades (vault/01 Design/Abilities/Upgrade Paths.md): every filled slot's
	-- column offers that ability's next level (empty slots offer a new ability).
	-- At level 1 that is path A and path B. Each eligible seat can also roll
	-- one glitch card, with a higher chance after each eligible miss.
	-- `onboardingRound`: in an onboarding match a player is dealt a Glitched card (preselected) from this round's
	-- draft on, once (owner 2026-11-25: the signature moment shows in match 1).
	GLITCH = { chance = 0.15, step = 0.05, cap = 0.40, onboardingRound = 2 },

	-- Studio: with nobody on the other team, a bot plays it (Config/Bots).

	-- Remote budget per player: rate per second, burst.
	RATE = {
		DraftPick = { 8, 12 },
		Spectate = { 4, 6 },
		Look = { 40, 60 }, -- Services/LookStream (Juice.SPECTATE.lookHz, with room for jitter)
		MatchChoice = { 4, 6 },
		Scoreboard = { 2, 4 },
		MapVote = { 4, 6 },
		BodyReady = { 4, 8 }, -- Controllers/FloorHoldController: once per spawn (and per spawn spot)
	},
})
