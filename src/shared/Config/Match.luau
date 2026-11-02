--!strict
-- The match: timers, the round win, weapon phases and the draft
-- (vault/01 Design/Match Flow.md). Replicated: nothing secret here.

export type Phase = { name: string, tier: number, fromRound: number }

return table.freeze({
	MAP = "Whitebox", -- a Model in ServerStorage.Maps (or still in Workspace)

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
		{ name = "Heavy", tier = 3, fromRound = 4 },
		{ name = "Elite", tier = 4, fromRound = 7 },
	} :: { Phase },
	GUN_OFFERS = 3,
	ABILITY_OFFERS = 3,
	ABILITY_LEVEL = "L1", -- upgrades come later

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
