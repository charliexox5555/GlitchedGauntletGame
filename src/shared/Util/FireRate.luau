--!strict
-- Fire interval for a gun right now, including Flood-style spin-up and burst
-- cadence. Shared so the client fires at exactly the rate the server accepts.

local Types = require(script.Parent.Parent.Types)

local FireRate = {}

-- Firing stops counting as "continuous" (spin resets) after this gap.
FireRate.SPIN_RESET = 0.35

-- `burstShots`: shots fired so far in the current burst (0 = none yet).
function FireRate.interval(
	config: Types.WeaponConfig,
	spinStart: number?,
	lastFire: number,
	now: number,
	burstShots: number?
): number
	local burst = config.burst
	if burst then
		local shots = burstShots or 0
		if shots > 0 and shots < burst.count then
			return burst.interval
		end
		return config.fireInterval
	end
	local spin = config.spinUp
	if not spin then
		return config.fireInterval
	end
	if not spinStart or now - lastFire > FireRate.SPIN_RESET then
		return spin.startInterval
	end
	local t = math.clamp((now - spinStart) / spin.time, 0, 1)
	return spin.startInterval + (spin.endInterval - spin.startInterval) * t
end

-- Burst counter after a shot at `now` that followed one at `lastFire`.
function FireRate.nextBurstCount(
	config: Types.WeaponConfig,
	burstShots: number,
	lastFire: number,
	now: number
): number
	local burst = config.burst
	if not burst then
		return 0
	end
	if burstShots >= burst.count or now - lastFire >= config.fireInterval - 0.05 then
		return 1
	end
	return burstShots + 1
end

return FireRate
