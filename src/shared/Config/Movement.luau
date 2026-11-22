--!strict
-- Movement tuning (vault/01 Design/Gunplay.md §1). Speeds in studs/s.

return table.freeze({
	WALK_SPEED = 16,
	SPRINT_SPEED = 22,
	-- 2026-11-11 (owner: "I don't think we should have a shift to sprint... you
	-- first start walking, and then as you walk longer, you run"): you run by
	-- yourself (it's there for mobile players). Keep moving forward for
	-- RUN_DELAY seconds and you break into the run, building from walk to
	-- sprint speed over RUN_RAMP. Aiming, crouching, firing, stopping or
	-- backing up drops you to a walk again.
	-- Later the same day: "the run up time is too slow, it's hard to get
	-- going": 0.4 / 0.35 → 0.05 / 0.12, so it starts almost at once.
	-- The Sprint key (Shift on PC) stays for one thing: held while you move,
	-- it overrides crouch, so you stand up and run without letting go of C.
	RUN_DELAY = 0.05,
	RUN_RAMP = 0.12,
	CROUCH_SPEED = 9,

	-- Slide (2026-11-10, owner: "a tap on C does the full slide, jump cancels
	-- it"): one press while sprinting commits the whole slide; holding C is no
	-- longer needed (C still held at the end = you stay crouched). It was 0.7 s
	-- down to crouch speed and stopped the moment C was released.
	-- 2026-11-11 (owner: "the way you can move after you slide is a bit
	-- off"): it slowed to 12 and then jumped back to 22, a dip and a lurch as
	-- you stood up. It now slows to the speed you'll have next: sprint if
	-- you're still sprinting forward, walk otherwise, crouch if C is held.
	SLIDE_START_SPEED = 30,
	SLIDE_TIME = 0.85, -- slows from SLIDE_START_SPEED to that next speed over this
	-- Sliding into something: under this speed (after SLIDE_STALL_GRACE s) the
	-- slide ends instead of holding the pose against a wall.
	-- 2026-11-11 (owner: "you should just slide in that direction... you can
	-- rotate your camera, but you don't slide where your camera moves; maybe
	-- a mixture"): a slide holds the line it started on. Your move keys (and so
	-- the camera, with W held) can only bend it by this many degrees a second,
	-- about 20 degrees over a whole slide (measured: the Humanoid's own pull
	-- toward the keys adds a little on top). 0 = fully locked, like RIVALS.
	SLIDE_STEER = 12,
	SLIDE_STALL_SPEED = 5,
	SLIDE_STALL_GRACE = 0.15,
	SLIDE_COOLDOWN = 0.6,
	SLIDE_MIN_SPEED = 12, -- must be moving at least this fast to start a slide
	SLIDE_BUFFER = 0.25, -- seconds a held crouch press still starts a slide (no "just crouched" misses)
	SLIDE_JUMP_KEEP = 0.8, -- share of slide speed kept when jumping out of it

	-- 2026-11-04: was 7.2 (over a standing head: "jumps too high"). Whitebox's
	-- 7-tall perches are ramp-only now.
	-- 2026-11-11 (owner: "the jump is way too high... more fun, more
	-- game-like"): 5.6 → 4.4, with a faster fall below, so a jump is a quick
	-- hop, not a float.
	JUMP_HEIGHT = 4.4,
	-- Extra gravity on the way down only: same peak, a quicker, less floaty
	-- landing (1 = plain Workspace.Gravity).
	FALL_GRAVITY = 1.6, -- 1.3 until 2026-11-11
	-- 2026-11-12 (LihFolk "Input Responsiveness, Buffering and Coyote Time"):
	-- a jump pressed up to JUMP_BUFFER seconds before you land happens on
	-- landing, and you can still jump COYOTE_TIME seconds after running off
	-- an edge. Neither changes how high or far a jump goes.
	JUMP_BUFFER = 0.12,
	COYOTE_TIME = 0.1,
	AIR_FOV_KICK = 1.5, -- degrees on top of what you had when you left the ground

	CROUCH_CAMERA_DROP = 1.4, -- studs the camera lowers while crouched
	-- 2026-11-15 (RIVALS pass: RIVALS drops 3 studs on a slide, 2 on a crouch,
	-- and rolls 5 degrees on a springy roll, Config/Juice SLIDE.rollSpeed):
	-- a deeper drop and 4 degrees (was 3 for comfort; the spring adds a short
	-- swing past it).
	SLIDE_CAMERA_DROP = 2.2,
	SLIDE_CAMERA_TILT = 4, -- degrees of roll while sliding
	CAMERA_STIFFNESS = 140, -- crouch/slide camera spring
	CAMERA_DAMPING_RATIO = 0.9, -- 1 = no overshoot, lower = a little bounce
	SPRINT_FOV_KICK = 4, -- extra degrees of FOV while sprinting
	SLIDE_FOV_KICK = 8, -- ...and while sliding

	-- Server sanity check on replicated movement (anti speed-hack telemetry).
})
