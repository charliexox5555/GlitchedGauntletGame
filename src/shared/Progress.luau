--!strict
-- The `prog` field of a player's save (vault/01 Design/Progression.md): level, XP, win
-- streak and the lost-streak offer. Pure functions, run inside PlayerDataService changes
-- (UpdateAsync transforms: no yields, no side effects). Numbers: Config/Progression.
--   prog = { level, xp (into this level), total, streak, best, saves (in a row),
--            matches, wins, kills (lifetime, for the profile card),
--            lost = { value, expires (os.time) } | nil,
--            vs = { day, ids = { [userId] = wins today } } }

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Progression)

export type Lost = { value: number, expires: number }
export type Prog = {
	level: number,
	xp: number,
	total: number,
	streak: number,
	best: number,
	saves: number,
	matches: number,
	wins: number,
	kills: number,
	lost: Lost?,
	vs: { day: number, ids: { [string]: number } },
}

-- What one finished (or left) match means for one player.
export type Result = {
	won: boolean,
	left: boolean, -- left before the end: a loss, no XP
	counts: boolean, -- a real player on the other side (streaks move only then)
	roundsWon: number,
	kills: number,
	opponents: { number }, -- real opponents' UserIds
}

-- What a change did, for the match end screen and the level-up pop.
export type Gain = {
	xp: number,
	levelFrom: number,
	levelTo: number,
	streakFrom: number,
	streakTo: number,
	lostOffer: number?, -- a streak this loss put on offer
}

local Progress = {}

local BIG = 1_000_000_000

local function whole(n: unknown, max: number): number?
	if typeof(n) ~= "number" or n ~= n or n == math.huge or n == -math.huge then
		return nil
	end
	return math.clamp(math.floor(n), 0, max)
end

local function day(now: number): number
	return math.floor(now / 86400)
end

function Progress.new(): Prog
	return {
		level = 1,
		xp = 0,
		total = 0,
		streak = 0,
		best = 0,
		saves = 0,
		matches = 0,
		wins = 0,
		kills = 0,
		lost = nil,
		vs = { day = 0, ids = {} },
	}
end

-- Any stored value (nil for an older save, a hand edit) to a valid Prog.
function Progress.clean(raw: unknown): Prog
	local p = Progress.new()
	if typeof(raw) ~= "table" then
		return p
	end
	local t = raw :: { [string]: unknown }
	p.level = math.max(whole(t.level, Config.MAX_LEVEL) or 1, 1)
	p.xp = math.min(whole(t.xp, BIG) or 0, Config.xpToNext(p.level) - 1)
	p.total = whole(t.total, BIG) or 0
	p.streak = whole(t.streak, Config.STREAK.max) or 0
	p.best = math.max(whole(t.best, Config.STREAK.max) or 0, p.streak)
	p.saves = whole(t.saves, 64) or 0
	p.matches = whole(t.matches, BIG) or 0
	p.wins = math.min(whole(t.wins, BIG) or 0, p.matches)
	p.kills = whole(t.kills, BIG) or 0
	if typeof(t.lost) == "table" then
		local l = t.lost :: { [string]: unknown }
		local value, expires = whole(l.value, Config.STREAK.max), whole(l.expires, 2 ^ 40)
		if value and expires and value > 0 then
			p.lost = { value = value, expires = expires }
		end
	end
	if typeof(t.vs) == "table" then
		local v = t.vs :: { [string]: unknown }
		p.vs.day = whole(v.day, BIG) or 0
		if typeof(v.ids) == "table" then
			local n = 0
			for id, wins in v.ids :: { [unknown]: unknown } do
				local w = whole(wins, 1000)
				if
					typeof(id) == "string"
					and #id <= 20
					and w
					and w > 0
					and n < Config.STREAK.opponentMemory
				then
					p.vs.ids[id] = w
					n += 1
				end
			end
		end
	end
	return p
end

-- A live offer (nil once it ran out).
function Progress.offer(p: Prog, now: number): Lost?
	local l = p.lost
	if l and l.expires > now then
		return l
	end
	return nil
end

function Progress.xpFor(r: Result): number
	if r.left then
		return 0
	end
	local X = Config.XP
	local xp = X.finish
		+ (if r.won then X.win else 0)
		+ math.min(r.roundsWon * X.roundWon, X.roundWonMax)
		+ math.min(r.kills * X.kill, X.killMax)
	if not r.counts then
		xp = math.floor(xp * X.botsOnlyScale)
	end
	return xp
end

function Progress.addXp(p: Prog, amount: number)
	p.total = math.min(p.total + amount, BIG)
	p.xp += amount
	while p.level < Config.MAX_LEVEL and p.xp >= Config.xpToNext(p.level) do
		p.xp -= Config.xpToNext(p.level)
		p.level += 1
	end
	if p.level >= Config.MAX_LEVEL then
		p.xp = 0
	end
end

-- An offer that ran out unsaved: gone, and the save price starts over.
function Progress.tidy(p: Prog, now: number)
	if p.lost and p.lost.expires <= now then
		p.lost = nil
		p.saves = 0
	end
end

-- Applies one match to `p` (in place) and says what changed.
function Progress.apply(p: Prog, r: Result, now: number): Gain
	Progress.tidy(p, now)
	local gain: Gain = {
		xp = Progress.xpFor(r),
		levelFrom = p.level,
		levelTo = p.level,
		streakFrom = p.streak,
		streakTo = p.streak,
		lostOffer = nil,
	}
	Progress.addXp(p, gain.xp)
	gain.levelTo = p.level
	p.matches = math.min(p.matches + 1, BIG)
	if r.won and not r.left then
		p.wins = math.min(p.wins + 1, p.matches)
	end
	p.kills = math.min(p.kills + math.max(math.floor(r.kills), 0), BIG)
	-- Wins add to the streak only against a real opponent (no farming bots); any loss or leave breaks it,
	-- bots or not (owner 2026-11-22: losing must end the streak and offer the save).
	if r.counts and r.won then
		if p.vs.day ~= day(now) then
			p.vs = { day = day(now), ids = {} }
		end
		do
			-- Every real opponent under today's cap: the win adds to the streak.
			local fresh = true
			for _, id in r.opponents do
				if (p.vs.ids[tostring(id)] or 0) >= Config.STREAK.sameOpponentPerDay then
					fresh = false
				end
			end
			for _, id in r.opponents do
				local key = tostring(id)
				if
					not p.vs.ids[key]
					and Progress.count(p.vs.ids) >= Config.STREAK.opponentMemory
				then
					-- full: drop the opponent beaten least today (never the cap-reached ones first)
					local drop, least = nil, math.huge
					for k, n in p.vs.ids do
						if n < least then
							drop, least = k, n
						end
					end
					if drop then
						p.vs.ids[drop] = nil
					end
				end
				p.vs.ids[key] = (p.vs.ids[key] or 0) + 1
			end
			if fresh then
				p.streak = math.min(p.streak + 1, Config.STREAK.max)
				p.best = math.max(p.best, p.streak)
			end
		end
	elseif not r.won then
		if p.streak > 0 then
			local live = Progress.offer(p, now)
			if p.streak >= Config.SAVE.minStreak and (not live or p.streak >= live.value) then
				p.lost = { value = p.streak, expires = now + Config.SAVE.seconds }
				gain.lostOffer = p.streak
			end
			if not live and not gain.lostOffer then
				p.saves = 0 -- a loss with nothing to save: the price starts over
			end
			p.streak = 0
		end
	end
	gain.streakTo = p.streak
	return gain
end

function Progress.count(t: { [string]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

-- The price of the live offer, or nil (none / ran out).
function Progress.price(p: Prog, now: number): number?
	if not Progress.offer(p, now) then
		return nil
	end
	return Config.savePrice(p.saves)
end

-- Restores the offered streak (plus wins since the loss). False when there is none.
function Progress.restore(p: Prog, now: number): boolean
	local l = Progress.offer(p, now)
	if not l then
		return false
	end
	p.streak = math.min(l.value + p.streak, Config.STREAK.max)
	p.best = math.max(p.best, p.streak)
	p.saves = math.min(p.saves + 1, 64)
	p.lost = nil
	return true
end

-- 0..1 of the way to the next level.
function Progress.share(p: Prog): number
	return p.xp / Config.xpToNext(p.level)
end

return Progress
