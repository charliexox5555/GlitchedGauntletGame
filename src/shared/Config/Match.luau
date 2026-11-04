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
	} :: { MapEntry },

	ROUNDS_TO_WIN = 5,

	-- Seconds.
	READY_TIME = 5, -- "get ready" before the first draft
	OPENING_DRAFT_TIME = 25,
	DRAFT_TIME = 15,
	COUNTDOWN_TIME = 3, -- guns in hand, barrier still up
	ROUND_TIME = 50,
	ROUND_END_TIME = 4,
	MATCH_END_TIME = 8,

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

	-- Studio only: with nobody on the other team, a test opponent plays it.
	TEST_OPPONENT = {
		enabled = true,
		joinGrace = 3, -- seconds to wait for a second player first
		walkSpeed = 12,
		weapon = "Classic", -- what it holds (looks and tracers only)
		fireEvery = 0.55, -- seconds between shots while it can see you
		hitChance = 0.4,
		damage = 12,
		range = 90, -- studs
		-- Its route in map space (X across, Z along), written for its spawn end
		-- at Z < 0: out of the alcove, then back and forth across its half.
		route = {
			Vector3.new(-12, 0, -50),
			Vector3.new(-14, 0, -30),
			Vector3.new(16, 0, -14),
			Vector3.new(30, 0, -22),
			Vector3.new(-16, 0, -14),
			Vector3.new(-14, 0, -30),
		},
	},

	-- Remote budget per player: rate per second, burst.
	RATE = {
		DraftPick = { 8, 12 },
	},
})
