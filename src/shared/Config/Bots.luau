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
	headChance: number, -- chance per target pick to aim at the head
	recoilControl: number, -- share of recoil kick it pulls back down (0..1)
	aggression: number, -- 0..1: how readily it pushes instead of holding
	hearing: number, -- studs: gunshots inside this give a rough position
	memory: number, -- seconds it keeps hunting a last-known position
	abilityUse: number, -- 0..1: chance a true "when to use" rule casts this think
	fov: number, -- degrees: vision cone (full width)
}

local profiles: { [string]: Profile } = {
	Easy = {
		reaction = 0.55,
		aimSmooth = 0.26,
		errorStart = 7,
		errorFloor = 1.6,
		errorSettle = 0.6,
		headChance = 0.08,
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
		errorStart = 5,
		errorFloor = 0.9,
		errorSettle = 0.42,
		headChance = 0.2,
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
		errorStart = 3.5,
		errorFloor = 0.45,
		errorSettle = 0.28,
		headChance = 0.38,
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
	MAX_RAYS_PER_THINK = 3,

	-- Perception.
	EYE_HEIGHT = 1.5, -- studs above the root its eyes / muzzle sit (≈ head)
	NEAR_SENSE = 8, -- studs: felt even outside the vision cone
	REACQUIRE_WINDOW = 1, -- seconds: re-seeing someone this soon halves the reaction
	HEAR_ERROR = 6, -- studs of noise on a heard position

	-- Choosing goals (utility): a new goal must beat the current one by this,
	-- and a goal is kept at least this long.
	SWITCH_MARGIN = 0.15,
	COMMIT_TIME = 0.6,
	RETREAT_HEALTH = 0.35, -- share of health+shield below which retreat scores high
	TARGET_STICK = 1, -- seconds before switching to a better target

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
	REPATH_MOVE = 6, -- studs the goal must move to force a recompute
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
