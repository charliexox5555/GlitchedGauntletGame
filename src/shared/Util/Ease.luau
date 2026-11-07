--!strict
-- Easing and smoothing helpers, one copy for everyone (they used to be
-- redefined in a dozen controllers).

local Ease = {}

-- Smoothstep: eases in and out. `t` is clamped to 0..1.
function Ease.smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- Cubic ease-out: fast start, gentle stop. `t` is clamped to 0..1.
function Ease.out(t: number): number
	t = math.clamp(t, 0, 1)
	return 1 - (1 - t) ^ 3
end

function Ease.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Frame-rate independent approach of `current` toward `goal` at `rate` (1/s).
function Ease.approach(current: number, goal: number, rate: number, dt: number): number
	return current + (goal - current) * (1 - math.exp(-rate * dt))
end

-- The same for an angle in radians, the short way round.
function Ease.approachAngle(current: number, goal: number, rate: number, dt: number): number
	local delta = (goal - current + math.pi) % (2 * math.pi) - math.pi
	return current + delta * (1 - math.exp(-rate * dt))
end

return Ease
