--!strict
-- Aim assist and auto shoot for controllers and phones (never mouse):
-- Controllers/AimAssistController, Settings AIM ASSIST (+ STRENGTH) and AUTO
-- SHOOT. Plan, research and sources: vault/02 Art/UI Settings.md → Chunk 3.
-- Fair, not a lock: a slowdown near enemies plus a light pull that only
-- works while the player is moving their aim; no snap on aim-down-sights.
-- Every shot is still checked by the server.

return table.freeze({
	-- Targets ------------------------------------------------------------------
	-- Half-angle of the cone around the crosshair (degrees) at the base FOV;
	-- the cone narrows with the zoom (RIVALS: a 15 degree field).
	CONE = 7.5,
	-- Inside this half-angle the assist is at full weight, fading to 0 at CONE.
	INNER = 2.5,
	-- No assist this close (studs): point-blank fights are the player's own.
	MIN_DISTANCE = 4,
	-- Never past this (studs), whatever the gun's range.
	MAX_DISTANCE = 300,
	-- How often the target is picked (per second); its position updates every frame.
	PICK_RATE = 20,

	-- Assist -------------------------------------------------------------------
	-- Friction: the turn slows by up to this share near a target (x strength).
	FRICTION = 0.4,
	-- Pull: while the aim moves, this share of that frame's turn bends toward
	-- the target (hip, fully aimed; blended by the zoom), x strength.
	PULL_HIP = 0.15,
	PULL_ADS = 0.3,
	-- Tracking: while the aim moves, this share of a strafing target's motion
	-- (as seen from the camera) is followed, x strength.
	TRACK = 0.35,
	-- A turn smaller than this (radians a frame) is not "moving the aim".
	MOVING_TURN = 0.0004,

	-- Auto shoot ---------------------------------------------------------------
	-- DYNAMIC: base + share of the gun's shot interval, clamped (seconds).
	-- (RIVALS clamps 25-125 ms; a little slower here, nearer human reaction.)
	DYNAMIC_BASE = 0.05,
	DYNAMIC_SHARE = 0.1,
	DYNAMIC_MIN = 0.05,
	DYNAMIC_MAX = 0.15,
	-- CUSTOM never goes under this (seconds), whatever the slider says.
	CUSTOM_MIN = 0.025,
})
