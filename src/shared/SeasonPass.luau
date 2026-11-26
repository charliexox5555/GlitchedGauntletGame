--!strict
-- One player's season pass state and the tier maths (vault/01 Design/Battle Pass Season 1
-- Contents.md; rules in Config/Season). Pure: no services, both sides use it. The server
-- changes it only inside a PlayerData write (match progress: ProgressionService; claims and
-- purchases: Lobby/SeasonRewards), so a tier or a claim counts exactly once.
--
-- Saved in PlayerData as `season` (2026-11-26, no version bump: older saves get new()):
--   id       the season this state is for (a different id = start again)
--   premium  the premium track is bought
--   tier     tiers reached (0..Config/Season.TIERS)
--   secs     seconds in live rounds toward the next tier
--   rounds   rounds won toward the next tier
--   free     claimed free-track tiers (sorted)
--   prem     claimed premium-track tiers (sorted)
--   winDay   UTC day of the last first-win bonus

local Season = require(script.Parent.Config.Season)

export type Track = "free" | "premium"
export type State = {
	id: number,
	premium: boolean,
	tier: number,
	secs: number,
	rounds: number,
	free: { number },
	prem: { number },
	winDay: number,
}

-- One finished (or left) match as the match server counted it.
export type Match = {
	liveSeconds: number, -- seconds this player spent in live rounds
	roundsWon: number,
	won: boolean,
	left: boolean, -- leavers keep their time and rounds, but get no first-win bonus
	botsOnly: boolean, -- no real player on the other side
}

local SeasonPass = {}

function SeasonPass.new(): State
	return {
		id = Season.ID,
		premium = false,
		tier = 0,
		secs = 0,
		rounds = 0,
		free = {},
		prem = {},
		winDay = 0,
	}
end

local function whole(n: unknown, min: number, max: number): number?
	if typeof(n) ~= "number" or n ~= n or n == math.huge or n == -math.huge then
		return nil
	end
	return math.clamp(math.floor(n), min, max)
end

local function tierList(raw: unknown, max: number): { number }
	local out: { number } = {}
	if typeof(raw) ~= "table" then
		return out
	end
	for _, v in raw :: { unknown } do
		local t = whole(v, 1, max)
		if t and t == v and not table.find(out, t) then
			table.insert(out, t)
		end
	end
	table.sort(out)
	return out
end

-- Any stored value to a valid State. A state from another season starts again (the old
-- season's leftovers are paid before the id changes, Build Plan phase 9).
function SeasonPass.clean(raw: unknown): State
	local s = SeasonPass.new()
	if typeof(raw) ~= "table" then
		return s
	end
	local t = raw :: { [string]: unknown }
	if t.id ~= Season.ID then
		return s
	end
	s.premium = t.premium == true
	s.tier = whole(t.tier, 0, Season.TIERS) or 0
	if s.tier < Season.TIERS then
		s.secs = whole(t.secs, 0, Season.TIER_SECONDS - 1) or 0
		s.rounds = whole(t.rounds, 0, Season.TIER_ROUNDS - 1) or 0
	end
	s.free = tierList(t.free, s.tier)
	s.prem = tierList(t.prem, s.tier)
	s.winDay = whole(t.winDay, 0, 1e7) or 0
	return s
end

local function validList(list: { number }, tier: number): boolean
	local last = 0
	for _, v in list do
		if typeof(v) ~= "number" or v ~= math.floor(v) or v <= last or v > tier then
			return false
		end
		last = v
	end
	return true
end

-- After a change: everything whole and in range, claims only for tiers reached.
function SeasonPass.valid(s: State): boolean
	local function ok(n: number, max: number): boolean
		return typeof(n) == "number" and n == math.floor(n) and n >= 0 and n <= max
	end
	return s.id == Season.ID
		and ok(s.tier, Season.TIERS)
		and ok(s.secs, Season.TIER_SECONDS - 1)
		and ok(s.rounds, Season.TIER_ROUNDS - 1)
		and ok(s.winDay, 1e7)
		and validList(s.free, s.tier)
		and validList(s.prem, s.tier)
		and (s.tier < Season.TIERS or (s.secs == 0 and s.rounds == 0))
end

-- Moves the meters, going up a tier each time one fills: the meter that filled keeps its
-- overflow, the other starts again at 0. Stops at the last tier. Returns tiers gained.
local function advance(s: State, secs: number, rounds: number): number
	local before = s.tier
	s.secs += secs
	s.rounds += rounds
	while s.tier < Season.TIERS do
		if s.secs >= Season.TIER_SECONDS then
			s.secs -= Season.TIER_SECONDS
			s.rounds = 0
		elseif s.rounds >= Season.TIER_ROUNDS then
			s.rounds -= Season.TIER_ROUNDS
			s.secs = 0
		else
			break
		end
		s.tier += 1
	end
	if s.tier >= Season.TIERS then
		s.secs, s.rounds = 0, 0
	end
	return s.tier - before
end

-- A match's progress (inside the match-end write). `day` = the UTC day (Economy.day).
-- Returns tiers gained and whether this match took the day's first-win bonus.
function SeasonPass.applyMatch(s: State, m: Match, day: number): (number, boolean)
	local scale = if m.botsOnly then Season.BOT_SCALE else 1
	local secs = (whole(m.liveSeconds, 0, Season.MAX_MATCH_SECONDS) or 0) * scale
	local rounds = (whole(m.roundsWon, 0, Season.MAX_MATCH_ROUNDS) or 0) * scale
	local bonus = false
	if m.won and not m.left and s.winDay ~= day then
		s.winDay = day
		rounds += Season.FIRST_WIN_ROUNDS * scale
		bonus = true
	end
	return advance(s, math.floor(secs), math.floor(rounds)), bonus
end

-- Bought tiers (+5 LEVELS): straight up, capped at the last tier. Returns tiers gained.
function SeasonPass.skip(s: State, tiers: number): number
	local before = s.tier
	s.tier = math.min(s.tier + math.max(math.floor(tiers), 0), Season.TIERS)
	if s.tier >= Season.TIERS then
		s.secs, s.rounds = 0, 0
	end
	return s.tier - before
end

local function listOf(s: State, track: Track): { number }
	return if track == "free" then s.free else s.prem
end

function SeasonPass.claimed(s: State, tier: number, track: Track): boolean
	return table.find(listOf(s, track), tier) ~= nil
end

-- May (tier, track) be claimed now? (The caller checks the tier has a reward.)
function SeasonPass.canClaim(s: State, tier: number, track: Track): boolean
	return tier == math.floor(tier)
		and tier >= 1
		and tier <= s.tier
		and (track == "free" or s.premium)
		and not SeasonPass.claimed(s, tier, track)
end

function SeasonPass.markClaimed(s: State, tier: number, track: Track)
	local list = listOf(s, track)
	if not table.find(list, tier) then
		table.insert(list, tier)
		table.sort(list)
	end
end

-- The progress shown on the pass: what's left on each meter.
function SeasonPass.left(s: State): (number, number)
	if s.tier >= Season.TIERS then
		return 0, 0
	end
	return Season.TIER_SECONDS - s.secs, Season.TIER_ROUNDS - s.rounds
end

return SeasonPass
