--!strict
-- Pure matchmaking rules (no services, so they're easy to reason about and test):
-- when a mode's queue should launch a match, and how its groups split into
-- teams. A queue entry is a group: one player, or a Roblox party that queued
-- together (Matchmaking/Parties). A group is never split across teams.

export type Entry = {
	players: { Player }, -- leader first
	since: number, -- os.clock() when the group joined this queue
	ticket: string?, -- its global-queue ticket (Matchmaking/GlobalQueue), once written
}

export type Pick = {
	entries: { Entry },
	teams: { { Player } },
}

local Matchmaker = {}

-- Packs groups, oldest first, into two teams of teamSize: each group goes to
-- the team with fewer players that still has room for all of it, so real
-- players face each other first and bots fill whatever is left on each side.
function Matchmaker.pack(queue: { Entry }, teamSize: number): Pick
	local teams: { { Player } } = { {}, {} }
	local entries: { Entry } = {}
	local total = 0
	for _, entry in queue do
		local n = #entry.players
		local first = if #teams[1] <= #teams[2] then 1 else 2
		local second = 3 - first
		local t = if #teams[first] + n <= teamSize
			then first
			elseif #teams[second] + n <= teamSize then second
			else nil
		if t then
			for _, p in entry.players do
				table.insert(teams[t], p)
			end
			table.insert(entries, entry)
			total += n
			if total >= teamSize * 2 then
				break
			end
		end
	end
	return { entries = entries, teams = teams }
end

-- The groups to launch now, or nil to keep waiting: a full match as soon as
-- the queue can fill both teams, otherwise everyone who fits once the oldest
-- group has waited `fillAfter` seconds (bots take the empty slots).
function Matchmaker.pick(queue: { Entry }, teamSize: number, now: number, fillAfter: number): Pick?
	if #queue == 0 then
		return nil
	end
	local pick = Matchmaker.pack(queue, teamSize)
	if #pick.teams[1] + #pick.teams[2] >= teamSize * 2 then
		return pick
	end
	if now - queue[1].since >= fillAfter and #pick.entries > 0 then
		return pick
	end
	return nil
end

-- How many players are waiting in a queue.
function Matchmaker.count(queue: { Entry }): number
	local n = 0
	for _, entry in queue do
		n += #entry.players
	end
	return n
end

return Matchmaker
