--!strict
-- Rewind building block (Rollback; later Undo's health and Save State). A
-- short history of where a character was, keyed by simulation time(). Lives
-- in Luau tables inside the simulation, so on a Server Authority rollback the
-- entries newer than the rolled-back-to step are dropped (trimAfter) before
-- the steps are run again.

export type History = { times: { number }, frames: { CFrame } }

local Rewind = {}

function Rewind.new(): History
	return { times = {}, frames = {} }
end

-- Records `cf` at `t`, keeping `keep` seconds.
function Rewind.push(h: History, t: number, cf: CFrame, keep: number)
	local times, frames = h.times, h.frames
	local n = #times
	if n > 0 and t <= times[n] then
		return -- a step we already have (or older)
	end
	table.insert(times, t)
	table.insert(frames, cf)
	-- Usually one entry falls off per step.
	while #times > 0 and t - times[1] > keep do
		table.remove(times, 1)
		table.remove(frames, 1)
	end
end

-- Where it was at `t`: the newest entry at or before `t` (else the oldest).
function Rewind.sample(h: History, t: number): CFrame?
	local times = h.times
	if #times == 0 then
		return nil
	end
	for i = #times, 1, -1 do
		if times[i] <= t then
			return h.frames[i]
		end
	end
	return h.frames[1]
end

-- How far back the history reaches from `now` (0 when empty).
function Rewind.span(h: History, now: number): number
	return if #h.times > 0 then now - h.times[1] else 0
end

-- A rollback to `t`: forget everything newer.
function Rewind.trimAfter(h: History, t: number)
	local times, frames = h.times, h.frames
	while #times > 0 and times[#times] > t do
		table.remove(times)
		table.remove(frames)
	end
end

return Rewind
