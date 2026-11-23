--!strict
-- Combat rules shared by the server (authoritative) and the client (feel).

return table.freeze({
	MAX_HEALTH = 100,
	-- Shield sits on top of health and takes damage first. It comes from your
	-- gun or the weapon phase (Config/Match), lasts the round and never comes back.
	MAX_SHIELD = 50,
	SHIELD_ATTRIBUTE = "Shield", -- on the Humanoid; the server writes it
	AMMO = table.freeze({
		reserveMags = 4,
		machineGunReserveMags = 3,
		minimumReserve = 18,
	}),
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

	-- Server Authority off (shared/Authority; owner 2026-11-11: "disable the
	-- anti-cheat for now, revisit a better one later"). The server can't see a
	-- player's stance, aim or camera any more, so the checks built on them
	-- turned real hits into hit markers with no damage (worst on the scoped
	-- snipers: the server thought you were unscoped) and refused Mod throws
	-- ("aim doesn't match the camera"). While the server isn't simulating
	-- players:
	--   * a shot's cone is what the client claims, up to CLIENT_SPREAD_MAX
	--     (it was clamped into the band the server computed from its own view);
	--   * the shot / Mod origin may be CLIENT_ORIGIN_TOLERANCE from the head
	--     (your own position reaches the server a ping late, at slide speed);
	--   * a Mod's aim isn't compared with the camera or your facing.
	-- Still checked: types, rate limits, fire rate, ammo, reloads, range, that
	-- the target was really there (rewind), walls, teams.
	-- Used only if a script can't read Workspace.AuthorityMode:
	SERVER_AUTHORITY_FALLBACK = false,
	CLIENT_SPREAD_MAX = 45, -- degrees
	CLIENT_ORIGIN_TOLERANCE = 9, -- studs

	-- Server validation tolerances. Generous enough for ~250 ms ping,
	-- tight enough that hits through walls / across the map are rejected.
	ORIGIN_TOLERANCE = 5, -- studs between the claimed shot origin (camera) and the server head
	HIT_POSITION_TOLERANCE = 2, -- studs between a claimed hit and the part's rewound surface
	-- Arms are posed (raised to hold the gun) only on clients, so the server's
	-- arm is up to ~3 studs from what the shooter saw.
	ARM_HIT_EXTRA_TOLERANCE = 3,
	DIRECTION_TOLERANCE = 1.5, -- degrees between a hit and its server-recomputed pellet ray
	FIRE_JITTER = 0.05, -- seconds of network jitter forgiven per shot
	-- A shot packet arriving up to this late keeps the fire-rate schedule, so the on-time shot after a delayed one
	-- isn't rejected as too fast (WeaponService; the average rate stays capped).
	FIRE_CATCHUP = 0.2,
	HEAVY_WINDUP_MIN = 0.20,
	HEAVY_WINDUP_MAX = 0.85,
	RELOAD_LEAD = 0.1, -- reloads (and each shell of a shell-by-shell one) count this much early
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
	-- Dash (Mods/Dash): the dash reaches the server through the simulation and
	-- shots through a remote, so the server's dash can end later than the
	-- client's (its input buffer). Shots this early against the server's own
	-- end of the fire delay are still accepted (and may still be Dash Focus).
	DASH_FIRE_SLACK = 0.15,
	-- Mod objects (Firewall, Launch Pad) don't move: a hit on one may claim a
	-- point at most this many studs outside its box (bodies get the latency
	-- allowance above instead).
	OBJECT_HIT_TOLERANCE = 0.5,
	-- A Mod object that moves (attribute Moving = true: the Roller) is seen by
	-- the shooter a ping behind the server: this much more slack on its box.
	MOVING_OBJECT_TOLERANCE = 3,
	-- A Mod's fire-rate boost (WeaponService.setFireRate): the multiplier is
	-- clamped to [FIRE_BOOST_MIN, FIRE_BOOST_MAX], and shots up to
	-- FIRE_BOOST_GRACE seconds after it ends still get it (latency).
	FIRE_BOOST_MIN = 1,
	FIRE_BOOST_MAX = 3,
	FIRE_BOOST_GRACE = 0.3,

	-- Only these parts of a character count as hitboxes (R15, plus R6 names).
	BODY_PARTS = {
		Head = true,
		-- Everyone's standard head hitbox (shared/MatchBody; the visible head has CanQuery off). Missing here, every
		-- headshot was rejected after the S15 body went in: a hit marker with no damage (owner playtest 2026-11-22).
		HitboxHead = true,
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
		FireResync = { 2, 1 }, -- limit full weapon state corrections
		WeaponState = { 2, 2 }, -- a newly mounted combat client asks for its own snapshot
		Equip = { 10, 10 },
		Reload = { 5, 5 },
		PickWeapon = { 3, 5 },
		Aim = { 40, 60 }, -- Juice SPECTATE.aimSendHz (30) plus headroom
	},

	-- Wall penetration (Util/Penetration; owner 2026-11-12: "wall penetration
	-- isn't really good, not on the maps", "the Odin can penetrate through the
	-- walls an infinite"). It used to need a ThinWall tag on the part, which
	-- no map has, or be "All", which went through everything for ever. Now a
	-- gun's class gives each round a budget, measured on the wall itself:
	--   depth   studs of wall it can pass in total, along its own line
	--   walls   how many walls it can pass
	--   damage  share of its damage left after each wall
	-- Light: rifles, the DMR, the heavy pistol, the lighter snipers. Heavy: the
	-- Operator and the Odin (through one thick wall or two thin ones, at 70%
	-- then 49%, so an Operator wall-bang is no longer a certain kill).
	PENETRATION = table.freeze({
		None = table.freeze({ depth = 0, walls = 0, damage = 1 }),
		Light = table.freeze({ depth = 1.6, walls = 1, damage = 0.6 }),
		Heavy = table.freeze({ depth = 4.5, walls = 2, damage = 0.7 }),
	}),
	-- Parts tagged with this (a plywood sheet, a fence) count as this thick for
	-- any gun that penetrates, whatever their real size.
	THIN_WALL_TAG = "ThinWall",
	THIN_WALL_DEPTH = 0.5,
})
