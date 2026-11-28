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

	-- Lobby hub third-person camera (lobby Controllers/LobbyCameraFollow,
	-- 2026-11-28): Roblox's camera tracks the root exactly, so a step up or
	-- down (the deck's one-stud step, stair runs, crate lips) pops the view.
	-- On the ground the camera height follows a low-passed copy of the root's
	-- climb (LOBBY_CLIMB_RATE 1/s), so a ramp's steady climb comes through in
	-- full after a moment; whatever the root does beyond it in a frame (a step)
	-- is soaked up and eases home at LOBBY_SETTLE_RATE. Simulated: a 1-stud
	-- step is 90% followed in 0.15 s with a 0.05-stud overshoot; starting up a
	-- 1:4 ramp at a run lags at most 0.33 studs. (Climb 6 / settle 10 followed
	-- faster but overshot 11%, a bob.) In the air it lets go fast (LOBBY_AIR_RATE), so jumps
	-- and pads aren't laggy. Never more than LOBBY_MAX_LAG studs from the root.
	LOBBY_CLIMB_RATE = 1,
	LOBBY_SETTLE_RATE = 12,
	LOBBY_AIR_RATE = 25,
	LOBBY_MAX_LAG = 1.5,
})
