--!strict
-- Rounds, shells and speedloaders the support hand carries in during a
-- reload clip (config `carry`, owner 2026-11-08: "the bullets just appear out
-- of nowhere"). One joint per round does both trips in the Blender clips: out
-- with the spent round, a turnaround far from the gun, back in with a fresh
-- one. This reads that path from the clip and answers, for a moment of the
-- clip, whether the round shows (never at the turnaround, where the spent one
-- would visibly reverse into the fresh one) and when the hand carries it in.

local RoundCarry = {}

type Clip = { frames: number, bones: { [string]: { number } }, markers: { [string]: number }? }

-- Fractions (0..1) of a clip: the turnaround (`farFrom`..`farTo`: hidden),
-- the fresh round's trip in (`farTo`..`arrive`: the hand carries it) and when
-- the joint leaves again after arriving (`leave`, 1 if it stays).
export type Timing = { farFrom: number, farTo: number, arrive: number, leave: number }

local FAR_SHARE = 0.72 -- of the furthest distance: the turnaround zone
local HOME = 0.02 -- studs from rest: arrived
local LEAVE = 0.05 -- studs from rest after arriving: leaving again

local cache: { [Clip]: { [string]: Timing | false } } = {}

local function distance(data: { number }, f: number): number
	local i = f * 7
	return Vector3.new(data[i + 1], data[i + 2], data[i + 3]).Magnitude
end

function RoundCarry.timing(clip: Clip, bone: string): Timing?
	local perClip = cache[clip]
	if not perClip then
		perClip = {}
		cache[clip] = perClip
	end
	local cached = perClip[bone]
	if cached ~= nil then
		return cached or nil
	end
	local data = clip.bones[bone]
	local result: Timing | false = false
	local n = clip.frames
	if data and n > 1 then
		-- The first trip out: its peak and the zone around it.
		local peak, peakFrame = 0, 0
		local f = 0
		while f < n and distance(data, f) <= HOME do
			f += 1
		end
		while f < n do
			local d = distance(data, f)
			if d > peak then
				peak, peakFrame = d, f
			elseif d < peak * 0.5 then
				break -- on its way back in
			end
			f += 1
		end
		if peak > HOME * 5 then
			local far = peak * FAR_SHARE
			local farFrom, farTo = peakFrame, peakFrame
			while farFrom > 0 and distance(data, farFrom - 1) >= far do
				farFrom -= 1
			end
			while farTo < n - 1 and distance(data, farTo + 1) >= far do
				farTo += 1
			end
			local arrive = farTo
			while arrive < n - 1 and distance(data, arrive) > HOME do
				arrive += 1
			end
			local leave = n - 1
			for g = arrive + 1, n - 1 do
				if distance(data, g) > LEAVE then
					leave = g
					break
				end
			end
			local last = n - 1
			result = {
				farFrom = farFrom / last,
				farTo = farTo / last,
				arrive = arrive / last,
				leave = leave / last,
			}
		end
	end
	perClip[bone] = result
	return result or nil
end

-- Does a carried joint show at clip progress `t`? `show`: "both" (the spent
-- round on its way out, and the fresh one in) or "in" (only the fresh one).
function RoundCarry.visible(timing: Timing, show: string, t: number): boolean
	if t >= timing.farFrom and t < timing.farTo then
		return false
	end
	if t < timing.farFrom then
		return show == "both"
	end
	return t < timing.leave or timing.leave >= 1
end

return RoundCarry
