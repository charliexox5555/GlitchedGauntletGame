--!strict
-- First-person camera tuning (see vault/01 Design/Gunplay.md §6). The player
-- setting is clamped to MIN_FOV..MAX_FOV; ADS FOV is set per gun in Weapons.

return table.freeze({
	DEFAULT_FOV = 80,
	MIN_FOV = 70,
	MAX_FOV = 100,
	-- The camera follows a smoothed copy of the character's position, so
	-- uneven simulation steps (prediction corrections, frame hitches, a 60 Hz
	-- simulation on a faster screen) render at an even pace: predicted with a
	-- velocity measured from recent positions (rate 1/s), pulled toward the
	-- real position at FOLLOW_CORRECTION (1/s), snapped beyond FOLLOW_SNAP studs.
	FOLLOW_VELOCITY_RATE = 12,
	FOLLOW_CORRECTION = 8,
	FOLLOW_SNAP = 4,
})
