--!strict
-- Fire interval for a gun right now, including Flood-style spin-up.
-- Shared so the client fires at exactly the rate the server accepts.

local Types = require(script.Parent.Parent.Types)

local FireRate = {}

-- Firing stops counting as "continuous" (spin resets) after this gap.
FireRate.SPIN_RESET = 0.35

function FireRate.interval(
	config: Types.WeaponConfig,
	spinStart: number?,
	lastFire: number,
	now: number
): number
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

return FireRate
