--!strict
-- First-person camera tuning (see vault/01 Design/Gunplay.md §6). The player
-- setting is clamped to MIN_FOV..MAX_FOV; ADS FOV is set per gun in Weapons.

return table.freeze({
	DEFAULT_FOV = 80,
	MIN_FOV = 70,
	MAX_FOV = 100,
	-- Server Authority's predicted character moves in uneven steps (0.07-0.53
	-- studs per frame at a steady 16 studs/s), so the camera follows a smoothed
	-- copy of its position: predicted with its velocity, pulled toward the real
	-- one at this rate (1/s), snapped back if it ever drifts this far (teleports).
	FOLLOW_CORRECTION = 8,
	FOLLOW_SNAP = 4,
})
