--!strict
-- The match: timers, the round win, weapon phases and the draft
-- (vault/01 Design/Match Flow.md). Replicated: nothing secret here.

-- flatShield: everyone's shield this phase. Without it, your gun's `shield` decides.
export type Phase = { name: string, tier: number, fromRound: number, flatShield: number? }
export type MapEntry = { id: string, minTeam: number, maxTeam: number }

return table.freeze({
	MAP = "Whitebox", -- the default map: a Model in ServerStorage.Maps (or still in Workspace)
	-- The map pool (vault/01 Design/Maps/00 Maps.md → Roster): before each match one
	-- installed map is picked at random among those that fit the bigger team
	-- (minTeam..maxTeam players), not the last one when there's a choice. Big
	-- maps take over from 3v3 (like RIVALS). In Studio the Workspace attribute
	-- "ForceMap" (a map id) overrides the pick, to test one map.
	MAPS = {
		{ id = "Whitebox", minTeam = 1, maxTeam = 2 },
		{ id = "Rooftops", minTeam = 1, maxTeam = 2 },
		{ id = "Bunker", minTeam = 1, maxTeam = 3 },
		{ id = "Dockyard", minTeam = 1, maxTeam = 4 },
		{ id = "Metro", minTeam = 2, maxTeam = 4 },
		{ id = "OldTown", minTeam = 2, maxTeam = 4 },
		{ id = "BigWhitebox", minTeam = 3, maxTeam = 4 },
		{ id = "Greenhouse", minTeam = 2, maxTeam = 4 },
		{ id = "Snowpeak", minTeam = 1, maxTeam = 3 },
		-- Dockyard2 (redesign, 2026-11-05) is installed but left out on purpose: ForceMap only until approved.
	} :: { MapEntry },

	ROUNDS_TO_WIN = 5,

	-- Seconds (vault/05 Production/Match Structure Revamp.md). The select
	-- screen opens as soon as the first player is in. Its time includes the
	-- 3-2-1 at the end (guns in hand, barrier up). Round 1 always runs its full
	-- time so everyone can arrive; later selects skip to the 3-2-1 once
	-- everyone has locked in.
	FIRST_SELECT_TIME = 30,
	SELECT_TIME = 15,
	COUNTDOWN_TIME = 3,
	ROUND_TIME = 50, -- then sudden death
	ROUND_END_TIME = 5,
	MATCH_END_TIME = 8,

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
		after = 0.3,
		slowFrom = 0.4,
		slowSpeed = 0.3,
		delay = 0.3,
		hold = 0.6,
		beat = 0.8,
		buffer = 6,
		rate = 30,
		recentKill = 1, -- seconds: the losing side's last down must be this recent (elimination ends the round within 0.1 s)
	},

	-- Gun offers by round. Each phase offers GUN_OFFERS guns of its tier, filled
	-- up from the tiers below when the tier is short.
	PHASES = {
		{ name = "Sidearm", tier = 1, fromRound = 1 },
		{ name = "Light", tier = 2, fromRound = 2 },
		{ name = "Heavy", tier = 3, fromRound = 4, flatShield = 50 },
		{ name = "Elite", tier = 4, fromRound = 7, flatShield = 50 },
	} :: { Phase },
	GUN_OFFERS = 3,
	ABILITY_LEVEL = "L1", -- a newly drafted ability's level
	-- Upgrades (vault/01 Design/Abilities/Upgrade Paths.md): every filled slot's
	-- column offers that ability's next level (empty slots offer a new ability).
	-- At level 1 that is path A and path B, plus the glitch path with this chance
	-- per ability, rising by `step` every draft that offered none (capped).
	GLITCH = { chance = 0.08, step = 0.03, cap = 0.25 },

	-- Studio: with nobody on the other team, a bot plays it (Config/Bots).

	-- Remote budget per player: rate per second, burst.
	RATE = {
		DraftPick = { 8, 12 },
		Spectate = { 4, 6 },
	},
})
