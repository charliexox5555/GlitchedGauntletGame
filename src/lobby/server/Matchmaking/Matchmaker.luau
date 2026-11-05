--!strict
-- Pure matchmaking rules (no services, so they're easy to reason about and test):
-- when a mode's queue should launch a match, and how humans split into teams.

export type Entry = {
	player: Player,
	since: number, -- os.clock() when they joined this queue
}

local Matchmaker = {}

-- The entries to launch now (oldest first), or nil to keep waiting:
-- a full match as soon as 2 x teamSize are queued, otherwise everyone waiting
-- once the oldest has waited `fillAfter` seconds (bots take the empty slots).
function Matchmaker.pick(
	queue: { Entry },
	teamSize: number,
	now: number,
	fillAfter: number
): { Entry }?
	local full = teamSize * 2
	if #queue >= full then
		return table.move(queue, 1, full, 1, {})
	end
	if #queue > 0 and now - queue[1].since >= fillAfter then
		return table.clone(queue)
	end
	return nil
end

-- Alternate humans across the two teams (A, B, A, B ...) so real players face
-- each other first and bots fill whatever is left on each side.
function Matchmaker.teams(userIds: { number }): { { number } }
	local a: { number }, b: { number } = {}, {}
	for i, id in userIds do
		table.insert(if i % 2 == 1 then a else b, id)
	end
	return { a, b }
end

return Matchmaker
