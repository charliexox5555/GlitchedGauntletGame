--!strict
-- SelfBuff building block: an effect spread over time (Patch Up's heal, later
-- Overclock and the glitch drains). take() returns what is due since the last
-- call, so the total is exact however unevenly the server ticks.

export type Timed = {
	start: number,
	duration: number,
	total: number,
	given: number,
}

local SelfBuff = {}

function SelfBuff.timed(start: number, duration: number, total: number): Timed
	return { start = start, duration = duration, total = total, given = 0 }
end

-- Amount due by `now` that hasn't been given yet.
function SelfBuff.take(effect: Timed, now: number): number
	local share = if effect.duration <= 0
		then 1
		else math.clamp((now - effect.start) / effect.duration, 0, 1)
	local due = effect.total * share - effect.given
	effect.given += due
	return due
end

function SelfBuff.done(effect: Timed, now: number): boolean
	return now >= effect.start + effect.duration
end

return SelfBuff
