--!strict
-- Where a range air target is at server time `t` (Config/RangeTargets): a pure function of its home and the clock,
-- so the server (hit checks) and every client (drawing it) agree without sending positions.

local RangeTargets = require(script.Parent.Config.RangeTargets)

local RangeTargetMotion = {}

local function number(target: Instance, name: string, default: number): number
	local v = target:GetAttribute(name)
	return if typeof(v) == "number" and v == v then v else default
end

-- The centre at server time `t` (bob and drift; the facing is each client's own).
function RangeTargetMotion.position(target: Instance, home: CFrame, t: number): Vector3
	local phase = number(target, "Phase", 0)
	local drift = number(target, "Drift", 0)
	local period = math.max(number(target, "Period", RangeTargets.PERIOD), 0.5)
	local bob = math.sin((t + phase) * 2 * math.pi / RangeTargets.BOB_PERIOD) * RangeTargets.BOB
	local side = math.sin((t + phase) * 2 * math.pi / period) * drift
	return (home * CFrame.new(side, bob, 0)).Position
end

return RangeTargetMotion
