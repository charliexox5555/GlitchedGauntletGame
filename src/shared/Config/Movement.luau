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

	-- 2026-11-04: was 7.2 (over a standing head: "jumps too high"). Whitebox's
	-- 7-tall perches are ramp-only now.
	JUMP_HEIGHT = 5.6,
	-- Extra gravity on the way down only: same peak, a quicker, less floaty
	-- landing (1 = plain Workspace.Gravity).
	FALL_GRAVITY = 1.3,

	CROUCH_CAMERA_DROP = 1.4, -- studs the camera lowers while crouched
	SLIDE_CAMERA_DROP = 1.9,
	SLIDE_CAMERA_TILT = 3, -- degrees of roll while sliding (was 5: small for comfort, Config/Juice)
	CAMERA_STIFFNESS = 140, -- crouch/slide camera spring
	CAMERA_DAMPING_RATIO = 0.9, -- 1 = no overshoot, lower = a little bounce
	SPRINT_FOV_KICK = 4, -- extra degrees of FOV while sprinting
	SLIDE_FOV_KICK = 8, -- ...and while sliding

	-- Server sanity check on replicated movement (anti speed-hack telemetry).
	MAX_LEGIT_SPEED = 45,
})
