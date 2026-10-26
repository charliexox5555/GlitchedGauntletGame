--!strict
-- Combat rules shared by the server (authoritative) and the client (feel).

return table.freeze({
	MAX_HEALTH = 100,
	RESPAWN_TIME = 3,

	-- Spread added on top of a gun's hip spread (Gunplay.md §2), degrees.
	MOVE_SPREAD = {
		Idle = 0,
		Walk = 0.4,
		Sprint = 0.6,
		Slide = 0.8,
		Air = 2.5,
	},
	BLOOM_RECOVERY = 6, -- degrees per second once you stop firing
	BLOOM_RECOVERY_DELAY = 0.12,

	-- Server validation tolerances. Generous enough for ~250 ms ping,
	-- tight enough that hits through walls / across the map are rejected.
	ORIGIN_TOLERANCE = 5, -- studs between the claimed shot origin (camera) and the server head
	HIT_POSITION_TOLERANCE = 2, -- studs between a claimed hit and the part's rewound surface
	-- Arms are posed (raised to hold the gun) only on clients, so the server's
	-- arm is up to ~3 studs from what the shooter saw.
	ARM_HIT_EXTRA_TOLERANCE = 3,
	DIRECTION_TOLERANCE = 1.5, -- degrees between a hit and its server-recomputed pellet ray
	FIRE_JITTER = 0.05, -- seconds of network jitter forgiven per shot
	HISTORY_SECONDS = 1, -- how much hitbox history is kept
	REWIND_EXTRA = 0.15, -- rewind window = 2 x the shooter's ping + this...
	REWIND_MAX = 0.6, -- ...capped here (seconds)
	MAX_HITS_PER_SHOT = 12,
	MAX_SHOT_SKIP = 3, -- shot counter may jump by at most this (lost/rejected shots)

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
		Aim = { 20, 30 },
	},

	-- Parts tagged with this can be shot through by guns with penetration = "ThinWall".
	THIN_WALL_TAG = "ThinWall",
})
