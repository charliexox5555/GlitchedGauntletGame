--!strict
-- Movement tuning (vault/01 Design/Gunplay.md §1). Speeds in studs/s.

return table.freeze({
	WALK_SPEED = 16,
	SPRINT_SPEED = 22,
	CROUCH_SPEED = 9,

	SLIDE_START_SPEED = 30,
	SLIDE_TIME = 0.7, -- slows from SLIDE_START_SPEED to CROUCH_SPEED over this
	SLIDE_COOLDOWN = 0.6,
	SLIDE_MIN_SPEED = 12, -- must be moving at least this fast to start a slide
	SLIDE_JUMP_KEEP = 0.8, -- share of slide speed kept when jumping out of it

	JUMP_HEIGHT = 7.2,

	CROUCH_CAMERA_DROP = 1.6, -- studs the camera lowers while crouched
	SLIDE_CAMERA_DROP = 2.0,
	SLIDE_CAMERA_TILT = 6, -- degrees of roll while sliding
	CAMERA_LERP = 14, -- higher = snappier crouch camera

	-- Server sanity check on replicated movement (anti speed-hack telemetry).
	MAX_LEGIT_SPEED = 45,
})
