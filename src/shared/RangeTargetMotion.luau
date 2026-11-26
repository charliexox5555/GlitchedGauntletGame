--!strict
-- Where a range air target is at server time `t` (Config/RangeTargets): a pure function of its home and the clock,
-- so the server (hit checks) and every client (drawing it) agree without sending positions.

local RangeTargets = require(script.Parent.Config.RangeTargets)

local RangeTargetMotion = {}

local function number(target: Instance, name: string, default: number): number
	local v = target:GetAttribute(name)
	return if typeof(v) == "number" and v == v then v else default
end

function RangeTargetMotion.pose(target: Instance, home: CFrame, t: number): CFrame
	local phase = number(target, "Phase", 0)
	local drift = number(target, "Drift", 0)
	local period = math.max(number(target, "Period", RangeTargets.PERIOD), 0.5)
	local bob = math.sin((t + phase) * 2 * math.pi / RangeTargets.BOB_PERIOD) * RangeTargets.BOB
	local side = math.sin((t + phase) * 2 * math.pi / period) * drift
	local sway = math.sin((t + phase * 1.3) * 2 * math.pi / (RangeTargets.BOB_PERIOD * 1.7))
		* math.rad(RangeTargets.SWAY)
	return home * CFrame.new(side, bob, 0) * CFrame.Angles(0, sway, 0)
end

return RangeTargetMotion
