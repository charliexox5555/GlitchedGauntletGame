--!strict
-- The task Path's state and rules (vault/01 Design/Tasks and Rewards.md; the list in Config/Tasks). Pure: no
-- services, both sides use it. The server applies match and range stats inside a PlayerData write
-- (ProgressionService for matches, LobbyServer TaskService for the range), so a task pays exactly once.
--
-- Saved in PlayerData as `tasks` (2026-11-26, no version bump: older saves get new()):
--   set    the set showing (1..#SETS; #SETS + 1 = the Path is done)
--   part   the part showing in that set
--   n      progress of the showing part's tasks, by task id (capped at the task's target)
--   seen   the ids counted by "distinct" tasks (powers, maps), by task id
--   title  the title the Path gave (Champion), if any
-- Only the showing part counts (owner 2026-11-26): finishing it clears `n` and `seen` and shows the next part.
-- Published on the player as the StringValue "Tasks" (JSON of the state).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tasks = require(ReplicatedStorage.Shared.Config.Tasks)

export type State = {
	set: number,
	part: number,
	n: { [string]: number },
	seen: { [string]: { string } },
	title: string?,
}

-- One player's finished (or left) match, as the match server counted it (StatsService.taskStats).
export type MatchStats = {
	played: boolean, -- finished it (a leaver: false)
	won: boolean,
	flawless: boolean, -- won without losing a round
	glitchWin: boolean, -- won after picking a Glitched power
	teamSize: number,
	map: string,
	roundsWon: number,
	roundsNoDeath: number, -- rounds won without dying
	clutches: number, -- rounds won as the team's last player alive
	aces: number, -- rounds where they eliminated the whole enemy team alone
	elims: number,
	headshotElims: number,
	doubles: number, -- double eliminations (a triple counts as one too)
	triples: number,
	tierElims: { number }, -- [weapon tier] = eliminations with a gun of that tier
	tierSweep: boolean, -- an elimination with every weapon tier the match dealt
	drafted: number, -- powers drafted (new powers and upgrades)
	uses: number, -- power uses
	powersUsed: { string }, -- the different powers they used
	powerLevels: { number }, -- [level] = powers they took to at least that level
}

-- Range counts since the last range write (LobbyServer TaskService). Downed Range bots also count for
-- "eliminations" tasks (owner 2026-11-26: "it might actually make players play longer"); `botTiers` = bots
-- downed by weapon tier, for tier-only elimination tasks.
export type RangeStats = { visit: number, targets: number, bots: number, botTiers: { number } }

export type Done = { id: string, text: string, coins: number }
export type Payout = {
	coins: number,
	tickets: number,
	title: string?,
	done: { Done }, -- tasks finished by this change, in order
	parts: number, -- parts finished
	sets: { string }, -- sets finished (ids)
}

local TaskPath = {}

local MAX_ID = 40
local MAX_SEEN = 32

function TaskPath.new(): State
	return { set = 1, part = 1, n = {}, seen = {} }
end

local function whole(n: unknown, min: number, max: number): number?
	if typeof(n) ~= "number" or n ~= n or n == math.huge or n == -math.huge then
		return nil
	end
	return math.clamp(math.floor(n), min, max)
end

-- The set and part showing (nil when the Path is done).
function TaskPath.current(s: State): (Tasks.TaskSet?, Tasks.Part?)
	local set = Tasks.SETS[s.set]
	if not set then
		return nil, nil
	end
	return set, set.parts[s.part]
end

-- Is the Path open for a player with this many finished matches?
function TaskPath.open(matches: number): boolean
	return matches >= Tasks.START_AFTER_MATCHES
end

-- Any stored value to a valid State (bad fields fall back to defaults; progress of tasks no longer showing is dropped).
function TaskPath.clean(raw: unknown): State
	local s = TaskPath.new()
	if typeof(raw) ~= "table" then
		return s
	end
	local t = raw :: { [string]: unknown }
	s.set = whole(t.set, 1, #Tasks.SETS + 1) or 1
	local set = Tasks.SETS[s.set]
	s.part = if set then whole(t.part, 1, #set.parts) or 1 else 1
	if typeof(t.title) == "string" and #t.title <= MAX_ID then
		s.title = t.title
	end
	local _, part = TaskPath.current(s)
	if not part then
		return s
	end
	local n = if typeof(t.n) == "table" then t.n :: { [unknown]: unknown } else {}
	local seen = if typeof(t.seen) == "table" then t.seen :: { [unknown]: unknown } else {}
	for _, task in part.tasks do
		local v = whole(n[task.id], 0, task.target)
		if v and v > 0 then
			s.n[task.id] = v
		end
		local list = seen[task.id]
		if typeof(list) == "table" then
			local ids: { string } = {}
			for _, id in list :: { unknown } do
				if
					typeof(id) == "string"
					and #id <= MAX_ID
					and not table.find(ids, id)
					and #ids < MAX_SEEN
				then
					table.insert(ids, id)
				end
			end
			if #ids > 0 then
				s.seen[task.id] = ids
			end
		end
	end
	return s
end

function TaskPath.valid(s: State): boolean
	local set = Tasks.SETS[s.set]
	if s.set < 1 or s.set > #Tasks.SETS + 1 or s.set ~= math.floor(s.set) then
		return false
	end
	if set and (s.part < 1 or s.part > #set.parts or s.part ~= math.floor(s.part)) then
		return false
	end
	for _, v in s.n do
		if typeof(v) ~= "number" or v < 0 or v ~= math.floor(v) then
			return false
		end
	end
	for _, list in s.seen do
		if #list > MAX_SEEN then
			return false
		end
	end
	return true
end

-- What a task shows: its progress, capped at its target. `level` tasks read the player's level.
function TaskPath.progress(s: State, task: Tasks.Task, level: number): number
	if task.kind == "level" then
		return math.min(level, task.target)
	end
	return math.min(s.n[task.id] or 0, task.target)
end

-- The task's text with its number in.
function TaskPath.text(task: Tasks.Task): string
	return string.format(task.text, task.target)
end

local function fits(task: Tasks.Task, teamSize: number): boolean
	return task.teamSize == nil or task.teamSize == teamSize
end

local function addSeen(s: State, task: Tasks.Task, ids: { string })
	local list = s.seen[task.id] or {}
	for _, id in ids do
		if #list >= math.min(task.target, MAX_SEEN) then
			break
		end
		if typeof(id) == "string" and id ~= "" and #id <= MAX_ID and not table.find(list, id) then
			table.insert(list, id)
		end
	end
	s.seen[task.id] = list
	s.n[task.id] = #list
end

-- How far one match moves a task (a count to add; distinct and streak tasks write their own value).
local function matchGain(s: State, task: Tasks.Task, m: MatchStats): number
	local k = task.kind
	local wonIt = m.played and m.won
	if not fits(task, m.teamSize) then
		return 0
	end
	if k == "matchPlay" then
		return if m.played then 1 else 0
	elseif k == "matchWin" then
		return if wonIt then 1 else 0
	elseif k == "matchFlawless" then
		return if wonIt and m.flawless then 1 else 0
	elseif k == "glitchWin" then
		return if wonIt and m.glitchWin then 1 else 0
	elseif k == "winStreak" then
		s.n[task.id] = if wonIt then (s.n[task.id] or 0) + 1 else 0
		return 0
	elseif k == "roundWin" then
		return m.roundsWon
	elseif k == "roundNoDeath" then
		return m.roundsNoDeath
	elseif k == "roundClutch" then
		return m.clutches
	elseif k == "roundAce" then
		return m.aces
	elseif k == "elims" then
		return if task.tier then m.tierElims[task.tier] or 0 else m.elims
	elseif k == "headshotElims" then
		return m.headshotElims
	elseif k == "multiElim" then
		return if task.level == 3 then m.triples else m.doubles
	elseif k == "tierSweep" then
		return if m.tierSweep then 1 else 0
	elseif k == "powerDraft" then
		return m.drafted
	elseif k == "powerUse" then
		return m.uses
	elseif k == "powerLevel" then
		return m.powerLevels[task.level or 2] or 0
	elseif k == "powerDistinct" then
		addSeen(s, task, m.powersUsed)
	elseif k == "mapDistinct" then
		if m.played and m.map ~= "" then
			addSeen(s, task, { m.map })
		end
	elseif k == "mapWinDistinct" then
		if wonIt and m.map ~= "" then
			addSeen(s, task, { m.map })
		end
	end
	return 0
end

local function rangeGain(task: Tasks.Task, r: RangeStats): number
	if task.kind == "rangeVisit" then
		return r.visit
	elseif task.kind == "rangeTargets" then
		return r.targets
	elseif task.kind == "rangeBots" then
		return r.bots
	elseif task.kind == "elims" then
		return if task.tier then r.botTiers[task.tier] or 0 else r.bots
	end
	return 0
end

-- Moves the showing part with `gain` (per task: an amount to add, or 0 after writing its own value), pays every
-- task it finishes, and moves on through finished parts and sets. Level tasks are checked on every part shown.
local function run(s: State, level: number, gain: (Tasks.Task) -> number): Payout
	local pay: Payout = { coins = 0, tickets = 0, done = {}, parts = 0, sets = {} }
	local first = true
	while true do
		local set, part = TaskPath.current(s)
		if not set or not part then
			break
		end
		local allDone = true
		for _, task in part.tasks do
			local before = s.n[task.id] or 0
			if before >= task.target then
				continue -- done earlier: never moves again
			end
			local after = before
			if task.kind == "level" then
				after = level
			elseif first then
				local add = gain(task)
				after = (s.n[task.id] or 0) + math.max(add, 0)
			end
			after = math.min(after, task.target)
			if after > 0 then
				s.n[task.id] = after
			else
				s.n[task.id] = nil
			end
			if after >= task.target then
				pay.coins += set.coins
				table.insert(
					pay.done,
					{ id = task.id, text = TaskPath.text(task), coins = set.coins }
				)
			else
				allDone = false
			end
		end
		first = false -- a part shown by this change starts empty: the same match doesn't count twice
		if not allDone then
			break
		end
		pay.coins += set.partBonus
		pay.parts += 1
		s.n, s.seen = {}, {}
		if s.part < #set.parts then
			s.part += 1
		else
			local r = set.reward
			pay.coins += r.coins or 0
			pay.tickets += r.tickets or 0
			if r.title then
				pay.title = r.title
				s.title = r.title
			end
			table.insert(pay.sets, set.id)
			s.set += 1
			s.part = 1
		end
	end
	return pay
end

-- One match into the Path (call only when the Path is open for the player before this match).
function TaskPath.applyMatch(s: State, m: MatchStats, level: number): Payout
	return run(s, level, function(task: Tasks.Task): number
		return matchGain(s, task, m)
	end)
end

-- Range counts into the Path.
function TaskPath.applyRange(s: State, r: RangeStats, level: number): Payout
	return run(s, level, function(task: Tasks.Task): number
		return rangeGain(task, r)
	end)
end

-- Would these range counts move a showing task? (TaskService writes at once when one would finish.)
function TaskPath.rangeFinishes(s: State, r: RangeStats): boolean
	local _, part = TaskPath.current(s)
	if not part then
		return false
	end
	for _, task in part.tasks do
		local add = rangeGain(task, r)
		local have = s.n[task.id] or 0
		if add > 0 and have < task.target and have + add >= task.target then
			return true
		end
	end
	return false
end

-- Does the showing part count range events at all? (Range tasks, and eliminations: Range bots count)
function TaskPath.wantsRange(s: State): boolean
	local _, part = TaskPath.current(s)
	if not part then
		return false
	end
	for _, task in part.tasks do
		if
			(
				task.kind == "rangeVisit"
				or task.kind == "rangeTargets"
				or task.kind == "rangeBots"
				or task.kind == "elims"
			) and (s.n[task.id] or 0) < task.target
		then
			return true
		end
	end
	return false
end

local function list(raw: unknown, max: number, maxLen: number): { string }
	local out: { string } = {}
	if typeof(raw) ~= "table" then
		return out
	end
	for _, v in raw :: { unknown } do
		if #out >= max then
			break
		end
		if typeof(v) == "string" and #v > 0 and #v <= maxLen and not table.find(out, v) then
			table.insert(out, v)
		end
	end
	return out
end

local function counts(raw: unknown, size: number): { number }
	local out: { number } = {}
	for i = 1, size do
		out[i] = if typeof(raw) == "table" then whole((raw :: any)[i], 0, 1000) or 0 else 0
	end
	return out
end

-- Server-made stats, still checked (they cross module boundaries and a bad value must not reach a save).
function TaskPath.cleanMatch(raw: unknown): MatchStats?
	if typeof(raw) ~= "table" then
		return nil
	end
	local t = raw :: { [string]: unknown }
	local function n(v: unknown): number
		return whole(v, 0, 1000) or 0
	end
	return {
		played = t.played == true,
		won = t.won == true,
		flawless = t.flawless == true,
		glitchWin = t.glitchWin == true,
		teamSize = whole(t.teamSize, 0, 8) or 0,
		map = if typeof(t.map) == "string" and #t.map <= MAX_ID then t.map else "",
		roundsWon = n(t.roundsWon),
		roundsNoDeath = n(t.roundsNoDeath),
		clutches = n(t.clutches),
		aces = n(t.aces),
		elims = n(t.elims),
		headshotElims = n(t.headshotElims),
		doubles = n(t.doubles),
		triples = n(t.triples),
		tierElims = counts(t.tierElims, 4),
		tierSweep = t.tierSweep == true,
		drafted = n(t.drafted),
		uses = n(t.uses),
		powersUsed = list(t.powersUsed, Tasks.POWER_COUNT + 8, MAX_ID),
		powerLevels = counts(t.powerLevels, 3),
	}
end

return TaskPath
