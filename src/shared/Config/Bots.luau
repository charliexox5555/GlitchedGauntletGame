--!strict
-- AI bots (vault/01 Design/Bots.md). Difficulty profiles and behaviour
-- tuning; starting values from the 2026-11-04 research pass, tune in
-- playtests. Replicated (nothing secret): the server owns every decision.

export type Profile = {
	perception: {
		reaction: number, -- seconds an enemy must be in sight before the bot reacts
		hearing: number, -- studs: gunshots inside this give a rough position
		memory: number, -- seconds it keeps hunting a last-known position
		fov: number, -- degrees: vision cone (full width)
	},
	aim: {
		aimSmooth: number, -- seconds: the aim spring's lag (lower = snappier)
		errorStart: number, -- degrees of aim error on a fresh target
		errorFloor: number, -- degrees it settles toward while tracking
		errorSettle: number, -- seconds (time constant) for the error to settle
		trackLag: number, -- seconds behind the target's real position it aims (strafing beats it)
		firstMisses: number, -- shots at a fresh target that miss on purpose (a fair warning)
		maxHitsPerSec: number, -- hits per second any one target can take from bots of this level
		easeLowHealth: number, -- aim error multiplier on a target below LOW_HEALTH
		headChance: number, -- chance per target pick to aim at the head
		recoilControl: number, -- share of recoil kick it pulls back down (0..1)
	},
	tactics: {
		aggression: number, -- 0..1: how readily it pushes instead of holding
		coverHealth: number, -- health + shield share that favors breaking contact
		coverPatience: number, -- seconds behind cover before re-peeking
		flankChance: number, -- biases the round's opening style toward flanking
	},
	mods: {
		abilityUse: number, -- 0..1: chance a true "when to use" rule casts this think
		interval: number, -- seconds between utility evaluations
		minScore: number, -- minimum score to commit a charge
	},
	movement: {
		strafePause: number, -- chance to pause a strafe leg to shoot
		slideChance: number, -- chance to slide when entering a clear fight
		slideJumpChance: number, -- chance to chain a jump out of a slide
		zoneLead: number, -- seconds of lead time before rotating for the boundary
	},
}

-- Competitive but beatable is Normal. All levels use the same health,
-- movement and combat rules. Hard punishes sustained exposure while still
-- using delayed vision and aim with error.
local profiles: { [string]: Profile } = {
	Easy = {
		perception = {
			reaction = 0.42,
			hearing = 55,
			memory = 5.5,
			fov = 120,
		},
		aim = {
			aimSmooth = 0.18,
			errorStart = 5.5,
			errorFloor = 1.6,
			errorSettle = 0.45,
			trackLag = 0.16,
			firstMisses = 1,
			maxHitsPerSec = 2,
			easeLowHealth = 1.3,
			headChance = 0.06,
			recoilControl = 0.65,
		},
		tactics = {
			aggression = 0.58,
			coverHealth = 0.24,
			coverPatience = 0.65,
			flankChance = 0.25,
		},
		mods = {
			abilityUse = 0.35,
			interval = 1.8,
			minScore = 0.68,
		},
		movement = {
			strafePause = 0.28,
			slideChance = 0.20,
			slideJumpChance = 0,
			zoneLead = 1.15,
		},
	},
	Normal = {
		perception = {
			reaction = 0.30,
			hearing = 50,
			memory = 5,
			fov = 140,
		},
		aim = {
			aimSmooth = 0.13,
			errorStart = 4.8,
			errorFloor = 1.2,
			errorSettle = 0.34,
			trackLag = 0.12,
			firstMisses = 0,
			maxHitsPerSec = 3,
			easeLowHealth = 1.15,
			headChance = 0.15,
			recoilControl = 0.78,
		},
		tactics = {
			aggression = 0.68,
			coverHealth = 0.28,
			coverPatience = 0.55,
			flankChance = 0.55,
		},
		mods = {
			abilityUse = 0.6,
			interval = 1.15,
			minScore = 0.55,
		},
		movement = {
			strafePause = 0.15,
			slideChance = 0.55,
			slideJumpChance = 0.15,
			zoneLead = 1.5,
		},
	},
	Hard = {
		perception = {
			reaction = 0.18,
			hearing = 65,
			memory = 8,
			fov = 150,
		},
		aim = {
			aimSmooth = 0.095,
			errorStart = 3.4,
			errorFloor = 0.85,
			errorSettle = 0.22,
			trackLag = 0.08,
			firstMisses = 0,
			maxHitsPerSec = 5,
			easeLowHealth = 1,
			headChance = 0.42,
			recoilControl = 0.92,
		},
		tactics = {
			aggression = 0.86,
			coverHealth = 0.32,
			coverPatience = 0.40,
			flankChance = 0.8,
		},
		mods = {
			abilityUse = 0.92,
			interval = 0.6,
			minScore = 0.64,
		},
		movement = {
			strafePause = 0.08,
			slideChance = 0.8,
			slideJumpChance = 0.35,
			zoneLead = 2,
		},
	},
}

-- Beyond Hard, for the owner's admin panel (owner 2026-11-22: "even past hard ... ultra hard").
-- Not used by matchmaking. Reaction can't go under REACTION_FLOOR (0.15 s) whatever the profile says.
profiles.Insane = {
	perception = { reaction = 0.16, hearing = 80, memory = 10, fov = 170 },
	aim = {
		aimSmooth = 0.07,
		errorStart = 2.2,
		errorFloor = 0.5,
		errorSettle = 0.15,
		trackLag = 0.04,
		firstMisses = 0,
		maxHitsPerSec = 8,
		easeLowHealth = 1,
		headChance = 0.55,
		recoilControl = 0.97,
	},
	tactics = { aggression = 0.92, coverHealth = 0.5, coverPatience = 0.35, flankChance = 0.85 },
	mods = { abilityUse = 0.96, interval = 0.45, minScore = 0.6 },
	movement = { strafePause = 0.05, slideChance = 0.88, slideJumpChance = 0.5, zoneLead = 2.2 },
}
profiles.Ultra = {
	perception = { reaction = 0.15, hearing = 100, memory = 14, fov = 200 },
	aim = {
		aimSmooth = 0.045,
		errorStart = 1.2,
		errorFloor = 0.2,
		errorSettle = 0.09,
		trackLag = 0.01,
		firstMisses = 0,
		maxHitsPerSec = 15,
		easeLowHealth = 0.9,
		headChance = 0.75,
		recoilControl = 1,
	},
	tactics = { aggression = 1, coverHealth = 0.5, coverPatience = 0.25, flankChance = 0.9 },
	mods = { abilityUse = 1, interval = 0.3, minScore = 0.55 },
	movement = { strafePause = 0.02, slideChance = 0.95, slideJumpChance = 0.65, zoneLead = 2.5 },
}

-- Easiest to hardest (the admin panel's buttons).
local ORDER = { "Easy", "Normal", "Hard", "Insane", "Ultra" }

return table.freeze({
	PROFILES = profiles,
	ORDER = table.freeze(ORDER),
	-- Dynamic difficulty (Bots/AutoDifficulty; owner 2026-11-22: "default difficulty is still hard ... not dynamic
	-- based on the player"). One difficulty for all of a match's bots, picked from its real players at the match
	-- start and again each round; the admin panel overrides it. Never above Hard on its own.
	AUTO = table.freeze({
		steps = table.freeze({ "Easy", "Normal", "Hard" }),
		-- the real players' average level: below `below` → that step (1 = Easy); above every row → Hard
		levelSteps = table.freeze({
			table.freeze({ below = 5, step = 1 }),
			table.freeze({ below = 20, step = 2 }),
		}),
		beginnerMax = 1, -- Beginner 2v2 never goes above Easy (a first win likely, not free)
		mobileShare = 0.5, -- this share of the real players on phones / tablets: one step easier
		streakUp = 3, -- the players' average win streak at least this: one step harder
		scoreMargin = 2, -- in the match, the real players' side ahead by this: one step harder; behind: easier
	}),
	DIFFICULTY = "Hard", -- testing default for every mode until difficulty selection is wired

	-- Lobby → Match (vault/05 Production/Overnight 2026-11-04.md → contracts).
	-- "beginner" = Beginner 2v2 (new players; vault/05 Production/Handoff - Onboarding and Bots.md)
	MODES = { ["1v1"] = 1, ["2v2"] = 2, ["3v3"] = 3, beginner = 2 } :: { [string]: number },
	-- Seconds from the first arrival to wait for an absent teleport seat before a bot fills in (20 until 2026-11-22:
	-- a phone teleport can take longer; LihFolk Parties and Group Teleports uses 45).
	JOIN_GRACE = 15,
	JOIN_GRACE_STUDIO = 3,
	-- Seconds a seat that is here may go without its client's ready signal before the match starts anyway (a client
	-- that broke while loading must not hold everyone on the loading screen; it is dealt in when it catches up).
	READY_TIMEOUT = 12,
	READY_TIMEOUT_STUDIO = 15,
	-- Seconds before a match where NO client has sent its ready signal is cancelled and everyone requeued
	-- (MatchPlan.allWaived). A lone player on a phone is "every client": at READY_TIMEOUT (12 s) their match was
	-- cancelled while they were still loading (live log 2026-11-24/25: "match load cancelled 12.5s ... all present
	-- clients timed out waiting for MatchReady"). A client that is here is loading, not broken: give it time.
	ALL_LOADING_TIMEOUT = 45,
	-- Studio with no BotMatch attribute: a lone player still gets one bot.
	STUDIO_SOLO_BOT = true,

	-- Timing. Thinks are staggered so bots don't all think on one frame.
	THINK_RATE = 10, -- decisions per second
	-- Server ms per Heartbeat for every bot together (think + act). Studio
	-- warns past it (LihFolk Script Performance: server scripts under ~5 ms
	-- per heartbeat in total; bots get a fifth of that).
	BUDGET_MS = 1,
	MAX_RAYS_PER_THINK = 6, -- torso and head for up to three opponents
	SIGHT_FRESHNESS = 0.22,

	-- Perception.
	NEAR_SENSE = 8, -- studs: felt even outside the vision cone
	REACQUIRE_WINDOW = 1, -- seconds: re-seeing someone this soon halves the reaction
	REACTION_FLOOR = 0.15, -- seconds: no reaction is ever faster (LihFolk AI Difficulty Tuning)
	TRAIL = 12, -- position samples kept per enemy (at THINK_RATE: 1.2 s, for trackLag)
	HEAR_ERROR = 6, -- studs of noise on a heard position

	-- Choosing goals (utility): a new goal must beat the current one by this,
	-- and a goal is kept at least this long.
	SWITCH_MARGIN = 0.15,
	COMMIT_TIME = 0.6,
	COVER_RADIUS = 9,
	COVER_RETRY = 3.5,
	PEEK_TIME = 0.85,
	HUNT_MEMORY = 3.5,
	MOD_RETRY = 3, -- pause before retrying a Mod whose plan failed at release
	ZONE_MARGIN = 4,
	ZONE_RUN_SPEED = 15, -- conservative travel estimate for the shrinking circle
	TARGET_COMMIT = 0.35, -- brief extra preference for the current threat
	THREAT_NEAR = 12, -- a nearby enemy can override squad focus
	MAX_ON_TARGET = 2, -- above this, favor an available alternative
	SHOT_ATTENTION_TIME = 1.2,
	LOW_HEALTH = 0.3, -- target health share below which aim eases (easeLowHealth)
	FAIR_MISS_ANGLE = 1.5, -- degrees past the target's edge a fair miss goes

	-- Range band by gun class (studs): where it likes to fight.
	RANGE = {
		Sidearm = { 12, 35 },
		SMG = { 8, 28 },
		Shotgun = { 4, 9 },
		Rifle = { 18, 55 },
		Sniper = { 40, 110 },
		MachineGun = { 15, 50 },
		Melee = { 0, 4 },
	} :: { [string]: { number } },

	-- Movement in a fight.
	STRAFE_MIN = 0.34, -- seconds per strafe leg
	STRAFE_MAX = 0.9,
	MOVE_RESPONSE = 0.065, -- seconds: ramp movement intent before clearance checks
	CROUCH_AT = 40, -- studs: beyond this it may crouch for steadier shots
	CROUCH_CHANCE = 0.35,
	SLIDE_RANGE = { 10, 26 }, -- studs to the target: slide in when sprinting into this
	TEAM_SPACING = 8, -- studs between teammates (soft push apart)

	-- Navigation (PathfindingService).
	OPENING_JITTER = 4, -- studs of offset sampled once for the whole opening
	OPENING_REPEAT_WEIGHT = 0.3, -- weight applied to the previous round's lane
	AGENT = { radius = 2.5, height = 5, canJump = true, spacing = 4 },
	STEER_EVERY = 0.075,
	STEER_LOOKAHEAD = 4,
	MAX_STEP_DOWN = 5,
	SLIDE_CLEARANCE = 10,
	REPATH_EVERY = 0.8, -- seconds between path computes at most
	REPATH_MOVE = 3, -- studs the goal must move to force a recompute (at least)...
	REPATH_SHARE = 0.2, -- ...or this share of the distance left (LihFolk Pathfinding)
	PROGRESS_WINDOW = 1.5, -- seconds without getting 1 stud closer to the waypoint = stuck
	WAYPOINT_REACHED = 1.4,
	STUCK_CHECK = 0.5, -- seconds between stuck samples
	STUCK_DISTANCE = 1, -- studs moved below which a sample counts as stuck
	ROAM_RETRY = 9, -- don't retry a patrol point that just stalled

	-- Firing discipline.
	FIRE_CONE_SLACK = 2.2, -- fires when aim error is under (gun cone + this) degrees
	TAP_RANGE = 45, -- studs: beyond this auto guns fire short bursts
	BURST_SHOTS = { 3, 6 },
	BURST_REST = { 0.18, 0.35 },
	TRIGGER_DELAY = { 0.04, 0.12 }, -- seconds between "on target" and the first shot
	AIM_TURN_SPEED = 480, -- degrees per second, including when swapping targets

	-- Bot-only escalation (Services/BotService): when every real player in a round is dead
	-- and bots remain on both teams, weaker bots ramp up cleanly after `grace` seconds so
	-- spectators aren't stuck watching slow bot-vs-bot stalemates.
	BOT_DUEL = table.freeze({
		grace = 0.5, -- seconds before ramping begins
		ramp = 3.5, -- seconds to reach full target stats
		seekJitter = 12, -- studs of offset when hunting an unseen enemy bot
		target = table.freeze({
			perception = table.freeze({ reaction = 0.22, hearing = 90, memory = 10, fov = 165 }),
			aim = table.freeze({
				aimSmooth = 0.12,
				errorStart = 4.0,
				errorFloor = 1.1,
				errorSettle = 0.28,
				trackLag = 0.10,
				firstMisses = 0,
				maxHitsPerSec = 4,
				easeLowHealth = 1.0,
				headChance = 0.25,
				recoilControl = 0.85,
			}),
			tactics = table.freeze({
				aggression = 0.88,
				coverHealth = 0.14,
				coverPatience = 0.40,
				flankChance = 0.70,
			}),
			mods = table.freeze({ abilityUse = 0.75, interval = 0.80, minScore = 0.55 }),
			movement = table.freeze({
				strafePause = 0.12,
				slideChance = 0.65,
				slideJumpChance = 0.20,
				zoneLead = 1.5,
			}),
		}) :: Profile,
	}),
})
