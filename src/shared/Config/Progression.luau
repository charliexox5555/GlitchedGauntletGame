--!strict
-- Levels, XP, the win streak and the coin streak save (vault/01 Design/Progression.md,
-- owner's answers 2026-11-22). Data only: PlayerData stores, ProgressionService (match end)
-- and StreakSaveService (lobby) read these. Coin prices get their release pass with the Shop.

local XP = table.freeze({
	finish = 20, -- played the match to the end (leavers get nothing)
	win = 30, -- on top, for the winning side
	roundWon = 4, -- per round your side took
	roundWonMax = 20,
	kill = 2,
	killMax = 20,
	botsOnlyScale = 0.5, -- no real player on the other side: half XP
})

-- XP to go from `level` to the next: 100, 120, 140 ... flat from FLAT_FROM.
local CURVE = table.freeze({
	base = 100,
	step = 20,
	cap = 1000,
})

local function xpToNext(level: number): number
	return math.min(CURVE.base + CURVE.step * (math.max(level, 1) - 1), CURVE.cap)
end

local STREAK = table.freeze({
	-- A win against the same real opponent counts for the streak at most this
	-- many times per UTC day (stops two friends trading wins). XP still counts.
	sameOpponentPerDay = 3,
	opponentMemory = 40, -- opponents remembered per day (oldest dropped)
	max = 1_000_000,
})

local SAVE = table.freeze({
	minStreak = 3, -- smaller lost streaks aren't offered
	seconds = 15 * 60, -- the offer lasts this long (real time, keeps counting offline)
	basePrice = 100, -- coins; doubles with each save in a row
	maxPrice = 1600,
	confirmRate = 1.0, -- seconds between SaveStreak requests per player
})

local function savePrice(savesInRow: number): number
	return math.min(SAVE.basePrice * 2 ^ math.max(savesInRow, 0), SAVE.maxPrice)
end

-- A reward on every level-up (vault/01 Design/Level Rewards.md, owner 2026-11-28: "just give coins, rarely
-- tickets and maybe charm case"). Shared/LevelRewards reads it; ProgressionService pays it in the match write.
-- Coins: min(coinsBase + coinsPerLevel x level, coinsMax). On top, one extra (the first that fits): every
-- bigBoxEvery levels the bigBox, else every boxEvery levels the box, else every ticketEvery levels one Ticket.
local LEVEL_REWARDS = table.freeze({
	coinsBase = 20,
	coinsPerLevel = 5, -- level 2: 30, level 10: 70, level 20: 120
	coinsMax = 150, -- from level 26
	ticketEvery = 5, -- 5, 15, 25 ... (the tens give a box instead)
	boxEvery = 10,
	box = "CaseStrikeBox",
	bigBoxEvery = 50,
	bigBox = "CaseOverdriveBox",
	maxPerWrite = 50, -- level-ups paid in one write (an admin jump can't loop for ever)
})

return table.freeze({
	XP = XP,
	CURVE = CURVE,
	xpToNext = xpToNext,
	MAX_LEVEL = 100_000,
	STREAK = STREAK,
	SAVE = SAVE,
	savePrice = savePrice,
	LEVEL_REWARDS = LEVEL_REWARDS,
})
