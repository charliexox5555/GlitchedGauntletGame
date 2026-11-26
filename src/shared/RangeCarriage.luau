--!strict
-- Where the range's moving dummy carriage is (vault/01 Design/Range v5.md): a
-- pure function of the server clock, so the server (hit checks) and every
-- client (drawing it smoothly) agree without sending positions. It waits
-- `pause` seconds at each end and eases in and out of every run.

local RangeDummies = require(script.Parent.Config.RangeDummies)

local RangeCarriage = {}

-- World X of a carriage running between `from` and `to` at an average
-- `speed` studs/s, at server time `t`.
function RangeCarriage.x(from: number, to: number, speed: number, t: number): number
	local distance = math.abs(to - from)
	if distance < 1e-3 or speed <= 0 or speed ~= speed then
		return from
	end
	local pause = RangeDummies.CARRIAGE.pause
	local run = distance / speed
	local half = run + pause
	local u = t % (2 * half)
	local outbound = u < half
	local s = if outbound then u else u - half
	local k = math.clamp((s - pause) / run, 0, 1)
	local eased = (1 - math.cos(math.pi * k)) / 2
	return if outbound then from + (to - from) * eased else to + (from - to) * eased
end

return RangeCarriage
