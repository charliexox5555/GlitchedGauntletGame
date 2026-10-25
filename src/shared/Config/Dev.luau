--!strict
-- Development helpers. Everything here only runs inside Studio
-- (RunService:IsStudio()), never in a live server.

return table.freeze({
	-- Spawn target dummies, cover and a thin wall in front of the spawn.
	TEST_RANGE = true,
	-- P opens the weapon menu (every gun); T / Y cycle the primary / secondary.
	WEAPON_PICKER = true,

	-- Dummy layout: distance in studs from the spawn, the gun it holds, and
	-- whether it strafes left/right.
	DUMMIES = {
		{ distance = 20, side = -6, weapon = "Bitrate", strafe = false },
		{ distance = 35, side = 6, weapon = "HardReset", strafe = true },
		{ distance = 55, side = -10, weapon = "LongPoll", strafe = false },
		{ distance = 80, side = 10, weapon = "Flood", strafe = false },
	},
	DUMMY_RESPAWN = 3,
})
