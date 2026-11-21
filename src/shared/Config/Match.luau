--!strict
-- The match: timers, the round win, weapon phases and the draft
-- (vault/01 Design/Match Flow.md). Replicated: nothing secret here.

-- One installed gun is drawn per pool. Shield overrides apply to the chosen gun.
export type Phase = {
	name: string,
	tier: number,
	fromRound: number,
	flatShield: number?,
	shieldByGun: { [string]: number }?,
	gunPools: { { string } }?,
}
export type MapEntry = { id: string, minTeam: number, maxTeam: number, name: string?, image: string? }

return table.freeze({
	MAP = "Arena", -- the default map: a Model in ServerStorage.Maps (or still in Workspace)
	-- The map pool (vault/01 Design/Maps/00 Maps.md → Roster): before each match one
	-- installed map is picked at random among those that fit the bigger team
	-- (minTeam..maxTeam players), not the last one when there's a choice. Big
	-- maps take over from 3v3 (like RIVALS). In Studio the Workspace attribute
	-- "ForceMap" (a map id) overrides the pick, to test one map.
	-- `image`: the map vote card's picture (art-source/ui/mapvote, captured in
	-- Studio 2026-11-16, uploaded with tools/opencloud/upload_asset.py; these are the Image ids
	-- behind the uploaded Decals, resolved with InsertService).
	MAPS = {
		-- Owner 2026-11-20: only the simple maps play (vault/04 Tech/Prompts/2026-11-20 Docks Map Build.md).
		-- Every other map stays installed in the place (ForceMap still loads it) but is out of the rotation
		-- and the vote: Whitebox, BigWhitebox, Rooftops(2/3), Courtyard, Bunker(2/3), Foundry, Snowpeak(2/3),
		-- ModelKit, OldTown(2/3), Metro(2/3), Greenhouse(2/3), Dockyard2.
		{ id = "Arena", minTeam = 1, maxTeam = 2 },
		{ id = "Pier", minTeam = 1, maxTeam = 2 },
		{ id = "Wharf", minTeam = 1, maxTeam = 2 }, -- 2026-11-20, vault/01 Design/Maps/Wharf.md
		{ id = "BigArena", name = "Big Arena", minTeam = 2, maxTeam = 3 },
		{ id = "Dockyard", minTeam = 2, maxTeam = 3 },
	} :: { MapEntry },

	-- The map vote before round 1 (vault/02 Art/UI Match Overhaul.md, after
	-- RIVALS' duels): every map in MAPS that fits the bigger team, plus Random.
	-- Each vote is a ticket and one is drawn (no votes = any map). Skipped when
	-- only one map fits, or in Studio with ForceMap.
	VOTE = table.freeze({
		seconds = 12, -- the vote
		allInSeconds = 1.5, -- once every player has voted, the clock cuts to this
		botDelay = { 1.2, 4.8 },
		withBotsMinSeconds = 6,
		chosenSeconds = 2.5, -- the picked map is shown, then the map loads
		random = "Random", -- the Random card's option name
	}),

	ROUNDS_TO_WIN = 5,
	LATE_SPAWN_WAIT = 3, -- seconds a slow spawn gets past the countdown
	MAX_EMPTY_ROUNDS = 3, -- rounds in a row with a side nobody could spawn on: the match ends
	MAX_ROUND_ERRORS = 3, -- rounds in a row that stopped on a script error: the match ends on the score (MatchService)
	KILL_DEPTH = 40, -- studs below a map's pivot that count as falling off (a map can set KillDepth)
	ASSIST_WINDOW = 10, -- seconds before a kill that damage still earns an assist (StatsService)

	-- Seconds (vault/05 Production/Match Structure Revamp.md). The select
	-- screen opens as soon as the first player is in. Its time includes the
	-- 3-2-1 at the end (guns in hand, barrier up). Every select skips to the
	-- 3-2-1 once everyone has locked in.
	FIRST_SELECT_TIME = 30,
	SELECT_TIME = 15,
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
	ROUND_END_TIME = 5,
	-- The match-end screen (Services/MatchEndService): `time` seconds to pick
	-- Rematch / Play Again / Leave, then everyone left goes to the Lobby.
	MATCH_END = {
		time = 20,
		botRematchChance = 0.94,
		botRematchDelay = { 0.8, 3 },
		lobbyPlaceId = 71551303511506, -- the Lobby place (this match place is 133387545285290)
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

	-- One shared offer per round. Pools mix weapon roles, with installed guns
	-- from this tier or lower filling any vacancies.
	PHASES = {
		{ name = "Sidearm", tier = 1, fromRound = 1 },
		{
			name = "Light",
			tier = 2,
			fromRound = 2,
			shieldByGun = { Sheriff = 50 },
			gunPools = { { "Spectre", "Stinger" }, { "Bucky", "Judge" }, { "Bulldog", "Marshal" } },
		},
		{
			name = "Heavy",
			tier = 3,
			fromRound = 4,
			flatShield = 50,
			gunPools = { { "Vandal", "Phantom" }, { "Guardian", "Outlaw" }, { "Ares" } },
		},
		{
			name = "Elite",
			tier = 4,
			fromRound = 7,
			flatShield = 50,
			gunPools = { { "Vandal", "Phantom", "Guardian" }, { "Odin" }, { "Operator" } },
		},
	} :: { Phase },
	GUN_POOLS_BY_ROUND = {
		[2] = {
			{ "Bulldog", "Spectre" },
			{ "Stinger", "Bucky", "Judge", "Marshal" },
			{ "Sheriff" },
		},
	} :: { [number]: { { string } } },
	GUN_OFFERS = 3,
	ABILITY_LEVEL = "L1", -- a newly drafted ability's level
	-- Upgrades (vault/01 Design/Abilities/Upgrade Paths.md): every filled slot's
	-- column offers that ability's next level (empty slots offer a new ability).
	-- At level 1 that is path A and path B. Each eligible seat can also roll
	-- one glitch card, with a higher chance after each eligible miss.
	GLITCH = { chance = 0.15, step = 0.05, cap = 0.40 },

	-- Studio: with nobody on the other team, a bot plays it (Config/Bots).

	-- Remote budget per player: rate per second, burst.
	RATE = {
		DraftPick = { 8, 12 },
		Spectate = { 4, 6 },
		Look = { 40, 60 }, -- Services/LookStream (Juice.SPECTATE.lookHz, with room for jitter)
		MatchChoice = { 4, 6 },
		Scoreboard = { 2, 4 },
		MapVote = { 4, 6 },
	},
})
