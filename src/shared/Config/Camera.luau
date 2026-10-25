--!strict
-- First-person camera tuning (see vault/01 Design/Gunplay.md §6). The player
-- setting is clamped to MIN_FOV..MAX_FOV; ADS FOV is set per gun in Weapons.

return table.freeze({
	DEFAULT_FOV = 80,
	MIN_FOV = 70,
	MAX_FOV = 100,
})
