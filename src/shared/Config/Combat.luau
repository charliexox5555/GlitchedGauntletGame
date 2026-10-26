--!strict
-- Combat rules shared by the server (authoritative) and the client (feel).

return table.freeze({
	MAX_HEALTH = 100,
	RESPAWN_TIME = 3,

	-- Gunplay v2 (Gunplay.md §2): movement adds spread on top of the gun's
	-- own, scaled smoothly by horizontal speed. Degrees per class: crouch-walk,
	-- walk (at walk speed), sprint (firing at sprint speed), slide, air.
	MOVE_PENALTY = {
		Rifle = { crouchWalk = 0.2, walk = 0.8, sprint = 1.5, slide = 1.2, air = 3 },
		SMG = { crouchWalk = 0.1, walk = 0.3, sprint = 0.7, slide = 0.5, air = 2 },
		Sidearm = { crouchWalk = 0.1, walk = 0.35, sprint = 0.8, slide = 0.6, air = 2 },
		Shotgun = { crouchWalk = 0, walk = 0.2, sprint = 0.4, slide = 0.3, air = 1 },
		MachineGun = { crouchWalk = 0.3, walk = 1.0, sprint = 2.0, slide = 1.5, air = 3.5 },
		Sniper = { crouchWalk = 1, walk = 2.5, sprint = 5, slide = 4, air = 8 },
		Wildcard = { crouchWalk = 0.2, walk = 0.8, sprint = 1.5, slide = 1.2, air = 3 },
		Melee = { crouchWalk = 0, walk = 0, sprint = 0, slide = 0, air = 0 },
	},
	MOVE_DEADZONE = 0.3, -- share of walk speed that still counts as standing
	ADS_MOVE_PENALTY = 0.5, -- fully aimed, the movement penalty is halved
	CROUCH_SPREAD = 0.85, -- crouched (standing or walking), the gun's own spread
	CROUCH_SIDE_RECOIL = 0.85, -- crouched, sideways recoil
	LANDING_PENALTY = 1.5, -- degrees, for LANDING_TIME after touching down
	LANDING_TIME = 0.2,
	-- Spray heat doesn't cool while shots come at most this many fire
	-- intervals apart (holding the trigger); see Util/Accuracy.cool.
	SPRAY_HOLD = 1.25,
	-- Standing still (no movement penalty), shots cluster near the centre;
	-- moving, they spread evenly over the cone.
	CENTRE_BIAS = 1, -- radius = cone * u^this (0.5 would be even over the disc)

	-- Server validation tolerances. Generous enough for ~250 ms ping,
	-- tight enough that hits through walls / across the map are rejected.
	ORIGIN_TOLERANCE = 5, -- studs between the claimed shot origin (camera) and the server head
	HIT_POSITION_TOLERANCE = 2, -- studs between a claimed hit and the part's rewound surface
	-- Arms are posed (raised to hold the gun) only on clients, so the server's
	-- arm is up to ~3 studs from what the shooter saw.
	ARM_HIT_EXTRA_TOLERANCE = 3,
	DIRECTION_TOLERANCE = 1.5, -- degrees between a hit and its server-recomputed pellet ray
	FIRE_JITTER = 0.05, -- seconds of network jitter forgiven per shot
	RELOAD_LEAD = 0.1, -- reloads (and each shell of a shell-by-shell one) count this much early
	HISTORY_SECONDS = 1, -- how much hitbox history is kept
	REWIND_EXTRA = 0.15, -- rewind window = 2 x the shooter's ping + this...
	REWIND_MAX = 0.6, -- ...capped here (seconds)
	MAX_HITS_PER_SHOT = 20, -- at least the most pellets a gun fires (Shorty: 15)
	MAX_SHOT_SKIP = 3, -- shot counter may jump by at most this (lost/rejected shots)
	-- The server recomputes each shot's spread from its own state. Slack for
	-- network timing: spray heat may differ by this many shots, and movement
	-- is read from the shooter's ping + FIRE_TIME_SLACK ago up to now
	-- (WeaponService spreadBand).
	SPREAD_HEAT_SLACK = 1,
	FIRE_TIME_SLACK = 0.08,
	MOTION_HISTORY = 1, -- seconds of speed / stance samples kept per player

	-- Only these parts of a character count as hitboxes (R15, plus R6 names).
	BODY_PARTS = {
		Head = true,
		UpperTorso = true,
		LowerTorso = true,
		HumanoidRootPart = true,
		LeftUpperArm = true,
		LeftLowerArm = true,
		LeftHand = true,
		RightUpperArm = true,
		RightLowerArm = true,
		RightHand = true,
		LeftUpperLeg = true,
		LeftLowerLeg = true,
		LeftFoot = true,
		RightUpperLeg = true,
		RightLowerLeg = true,
		RightFoot = true,
		Torso = true,
		["Left Arm"] = true,
		["Right Arm"] = true,
		["Left Leg"] = true,
		["Right Leg"] = true,
	},

	-- Lag-tolerant melee reach on the server, on top of the weapon's range.
	MELEE_TOLERANCE = 3,
	MELEE_FACING_DOT = 0.34, -- target must be within ~70 degrees of where you face
	BACKSTAB_DOT = 0.45, -- target facing away by more than this counts as a backstab

	-- Remote budgets (per player): rate per second, burst.
	RATE = {
		Fire = { 30, 40 },
		Equip = { 10, 10 },
		Reload = { 5, 5 },
		PickWeapon = { 3, 5 },
		Aim = { 20, 30 },
	},

	-- Parts tagged with this can be shot through by guns with penetration = "ThinWall".
	THIN_WALL_TAG = "ThinWall",
})
