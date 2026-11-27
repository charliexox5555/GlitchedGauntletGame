--!strict
-- Gun levels (vault/01 Design/Gun Levels.md; owner 2026-11-27): a gun levels by playing with it (kills, rounds
-- and wins with that gun), coins can optionally buy levels, each level-up gives one small step in a stat
-- category, and a milestone comes every 5 levels. Data only: Shared/GunLevels holds the rules, used by the
-- server (ProgressionService match XP, WeaponService stats, LockerService coin levels) and the client
-- (WeaponController stats, the Locker card) alike.

-- XP per match for each gun the player carried (the server's own records: StatsService).
local XP = table.freeze({
	kill = 10, -- an elimination with that gun in hand
	killMax = 30, -- eliminations counted per gun per match
	round = 5, -- a round played with the gun in the loadout
	roundWon = 10, -- on top, a round your side took with it
	roundMax = 15, -- rounds counted per gun per match
	matchWon = 25, -- the match won: every gun carried in at least one round
	botsOnlyScale = 0.5, -- no real player on the other side: half (as player XP)
})

-- XP to go from `level` to the next: 50, 70, 90 ... (1,010 at level 49).
local CURVE = table.freeze({
	base = 50,
	step = 20,
})

-- The stat categories, in the order level-ups give them: level 2 the first, level 3 the second ...
local CATEGORIES = table.freeze({ "Handling", "Reload", "Stability", "Accuracy" })

-- Each category's whole bonus at MAX_LEVEL, split evenly over its steps. Fractions off a time or a kick
-- (Handling: draw/equip and ADS-in time; Reload: every reload time; Stability: recoil kick; Accuracy: hip
-- spread). Never damage, fire rate, magazine, range or move speed: time to kill is the same at every level.
local MAX_BONUS = table.freeze({
	Handling = 0.08,
	Reload = 0.08,
	Stability = 0.08,
	Accuracy = 0.05,
})

local LABELS = table.freeze({
	Handling = "HANDLING",
	Reload = "RELOAD",
	Stability = "STABILITY",
	Accuracy = "ACCURACY",
})

-- Buying a level with coins (the shortcut, not the main path): COIN.perXp coins per XP left in the current
-- level, rounded up to COIN.roundTo. Coins buy levels only up to COIN.maxLevel; past it, play only.
local COIN = table.freeze({
	perXp = 3,
	roundTo = 10,
	maxLevel = 30,
	rate = 1.0, -- seconds between coin level-ups per player (also the LockerGunRequest limit)
})

-- Milestone rewards, every MILESTONE_EVERY levels. Not built yet (owner 2026-11-27: levelling and the stat
-- steps ship first; the card only says "Reward at LV N"). [level] = { coins = n } etc. later.
local REWARDS: { [number]: { [string]: any } } = {}

return table.freeze({
	XP = XP,
	CURVE = CURVE,
	MAX_LEVEL = 50,
	MILESTONE_EVERY = 5,
	CATEGORIES = CATEGORIES,
	MAX_BONUS = MAX_BONUS,
	LABELS = LABELS,
	COIN = COIN,
	REWARDS = table.freeze(REWARDS),
})
