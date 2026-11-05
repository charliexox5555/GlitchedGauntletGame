--!strict
-- AI bots (vault/01 Design/Bots.md). Difficulty profiles and behaviour
-- tuning; starting values from the 2026-11-04 research pass, tune in
-- playtests. Replicated (nothing secret): the server owns every decision.

export type Profile = {
	reaction: number, -- seconds an enemy must be in sight before the bot reacts
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
	aggression: number, -- 0..1: how readily it pushes instead of holding
	hearing: number, -- studs: gunshots inside this give a rough position
	memory: number, -- seconds it keeps hunting a last-known position
	abilityUse: number, -- 0..1: chance a true "when to use" rule casts this think
	fov: number, -- degrees: vision cone (full width)
}

-- Aim numbers (2026-11-05 LihFolk pass): start / floor / track lag / fair
-- misses / hit budget follow "AI Difficulty Tuning - Reaction Time, Aim
-- Error and Fair Misses" (Normal floor 2.5 there; ours 2.0 because our
-- hitboxes are R15 parts and the spring already adds lag).
local profiles: { [string]: Profile } = {
	Easy = {
		reaction = 0.55,
		aimSmooth = 0.26,
		errorStart = 9,
		errorFloor = 3.2,
		errorSettle = 0.6,
		trackLag = 0.35,
		firstMisses = 2,
		maxHitsPerSec = 1,
		easeLowHealth = 1.6,
		headChance = 0.06,
		recoilControl = 0.4,
		aggression = 0.35,
		hearing = 35,
		memory = 3,
		abilityUse = 0.35,
		fov = 120,
	},
	Normal = {
		reaction = 0.36,
		aimSmooth = 0.16,
		errorStart = 7,
		errorFloor = 2,
		errorSettle = 0.42,
		trackLag = 0.2,
		firstMisses = 1,
		maxHitsPerSec = 2,
		easeLowHealth = 1.3,
		headChance = 0.15,
		recoilControl = 0.65,
		aggression = 0.55,
		hearing = 50,
		memory = 5,
		abilityUse = 0.6,
		fov = 140,
	},
	Hard = {
		reaction = 0.24,
		aimSmooth = 0.1,
		errorStart = 4.5,
		errorFloor = 1.2,
		errorSettle = 0.28,
		trackLag = 0.12,
		firstMisses = 0,
		maxHitsPerSec = 3,
		easeLowHealth = 1,
		headChance = 0.3,
		recoilControl = 0.85,
		aggression = 0.75,
		hearing = 65,
		memory = 8,
		abilityUse = 0.85,
		fov = 150,
	},
}

return table.freeze({
	PROFILES = profiles,
	DIFFICULTY = "Normal", -- default; Studio: Workspace attribute "BotDifficulty" wins

	NAMES = {
		"Byte",
		"Patch",
		"Rook",
		"Vex",
		"Kilo",
		"Nova",
		"Echo",
		"Jinx",
		"Rift",
		"Bolt",
		"Pixel",
		"Static",
	},
	SKIN = Color3.fromHex("A3A5A8"),
	-- Shirt colour per team (team 1, team 2).
	TEAM_CLOTH = { Color3.fromHex("3E6FB0"), Color3.fromHex("B0473E") },

	-- Lobby → Match (vault/05 Production/Overnight 2026-11-04.md → contracts).
	MODES = { ["1v1"] = 1, ["2v2"] = 2, ["3v3"] = 3 } :: { [string]: number },
	JOIN_GRACE = 8, -- seconds to wait for listed players before bots fill in
	JOIN_GRACE_STUDIO = 3,
	-- Studio with no BotMatch attribute: a lone player still gets one bot.
	STUDIO_SOLO_BOT = true,

	-- Timing. Thinks are staggered so bots don't all think on one frame.
	THINK_RATE = 10, -- decisions per second
	-- Server ms per Heartbeat for every bot together (think + act). Studio
	-- warns past it (LihFolk Script Performance: server scripts under ~5 ms
	-- per heartbeat in total; bots get a fifth of that).
	BUDGET_MS = 1,
	MAX_RAYS_PER_THINK = 3,

	-- Perception.
	EYE_HEIGHT = 1.5, -- studs above the root its eyes / muzzle sit (≈ head)
	NEAR_SENSE = 8, -- studs: felt even outside the vision cone
	REACQUIRE_WINDOW = 1, -- seconds: re-seeing someone this soon halves the reaction
	REACTION_FLOOR = 0.15, -- seconds: no reaction is ever faster (LihFolk AI Difficulty Tuning)
	TRAIL = 12, -- position samples kept per enemy (at THINK_RATE: 1.2 s, for trackLag)
	HEAR_ERROR = 6, -- studs of noise on a heard position

	-- Choosing goals (utility): a new goal must beat the current one by this,
	-- and a goal is kept at least this long.
	SWITCH_MARGIN = 0.15,
	COMMIT_TIME = 0.6,
	RETREAT_HEALTH = 0.35, -- share of health+shield below which retreat scores high
	TARGET_STICK = 1, -- seconds before switching to a better target
	MAX_ON_TARGET = 2, -- bots that gang up on one enemy before a third looks elsewhere
	LOW_HEALTH = 0.3, -- target health share below which aim eases (easeLowHealth)
	FAIR_MISS_ANGLE = 1.5, -- degrees past the target's edge a fair miss goes

	-- Range band by gun class (studs): where it likes to fight.
	RANGE = {
		Sidearm = { 12, 35 },
		SMG = { 8, 28 },
		Shotgun = { 4, 14 },
		Rifle = { 18, 55 },
		Sniper = { 40, 110 },
		MachineGun = { 15, 50 },
		Melee = { 0, 4 },
	} :: { [string]: { number } },

	-- Movement in a fight.
	STRAFE_MIN = 0.25, -- seconds per strafe leg
	STRAFE_MAX = 0.7,
	STRAFE_PAUSE = 0.15, -- chance a leg is a stop (to shoot steady)
	CROUCH_AT = 40, -- studs: beyond this it may crouch for steadier shots
	CROUCH_CHANCE = 0.35,
	JUMP_CHANCE = 0.06, -- per think in a fight (Hard doubles)
	SLIDE_RANGE = { 10, 26 }, -- studs to the target: slide in when sprinting into this
	TEAM_SPACING = 8, -- studs between teammates (soft push apart)

	-- Navigation (PathfindingService).
	AGENT = { radius = 2, height = 5, canJump = true, spacing = 4 },
	REPATH_EVERY = 0.8, -- seconds between path computes at most
	REPATH_MOVE = 3, -- studs the goal must move to force a recompute (at least)...
	REPATH_SHARE = 0.2, -- ...or this share of the distance left (LihFolk Pathfinding)
	PROGRESS_WINDOW = 1.5, -- seconds without getting 1 stud closer to the waypoint = stuck
	WAYPOINT_REACHED = 2.5,
	STUCK_CHECK = 0.5, -- seconds between stuck samples
	STUCK_DISTANCE = 1, -- studs moved below which a sample counts as stuck

	-- Firing discipline.
	FIRE_CONE_SLACK = 1.2, -- fires when aim error is under (gun cone + this) degrees
	TAP_RANGE = 45, -- studs: beyond this auto guns fire short bursts
	BURST_SHOTS = { 3, 6 },
	BURST_REST = { 0.18, 0.35 },
	TRIGGER_DELAY = { 0.04, 0.12 }, -- seconds between "on target" and the first shot
})
