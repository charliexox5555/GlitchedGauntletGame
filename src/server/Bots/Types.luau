--!strict
-- The bot record shared by the bot modules (vault/01 Design/Bots.md).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BotsConfig = require(ReplicatedStorage.Shared.Config.Bots)
local Zone = require(script.Parent.Parent.Zone)
local BotGun = require(script.Parent.BotGun)

export type Memory = {
	model: Model,
	lastPos: Vector3,
	seenAt: number, -- os.clock() last seen (or heard)
	visibleSince: number?, -- os.clock() it came into sight (nil: not in sight)
	visible: boolean,
	visibleAt: number, -- last confirmed line of sight, separate from noises
	firedAt: number, -- last shot heard from this opponent
	heard: boolean, -- the position is a rough heard one
	headVisible: boolean, -- its head showed on the last look
	bodyVisible: boolean,
	headOffset: Vector3,
	bodyOffset: Vector3,
	aimPart: string, -- "Head" or "UpperTorso": where this bot aims at it
	-- Where it was over the last second (ring buffer at THINK_RATE), for
	-- aiming behind it by the profile's trackLag.
	trailPos: { Vector3 },
	trailT: { number },
	trailHead: number,
	groundPos: Vector3, -- last position it stood on the ground (a path goal)
	unreachableAt: number?, -- os.clock() a path to it failed
}

export type Nav = {
	goal: Vector3?,
	waypoints: { PathWaypoint },
	index: number,
	computedAt: number,
	computedFor: Vector3?,
	computing: boolean,
	failedFor: Vector3?, -- the goal the last compute found no path to
	bestDist: number, -- closest it got to the current waypoint (progress check)
	bestAt: number,
	progressIndex: number,
	lastSamplePos: Vector3,
	lastSampleAt: number,
	stuck: number,
	revision: number,
	params: RaycastParams,
	shortcutAt: number,
	steerAt: number,
	steerFrom: Vector3,
	steerDir: Vector3,
	steerJump: boolean,
}

export type Bot = {
	key: { name: string }, -- the draft seat key (MatchService / DraftService)
	name: string,
	team: number,
	profile: BotsConfig.Profile,
	avatar: Model?, -- undressed clone template, fixed for the bot seat
	avatarPending: boolean,
	seat: Configuration, -- public roster fields, available before the bot body
	portraitUserId: number?,
	skins: { [string]: string },
	starterSkin: boolean,
	owner: Configuration, -- stands in for a Player (Simulation/Pawns)
	inputs: { [string]: InputAction },
	model: Model?,
	humanoid: Humanoid?,
	root: BasePart?,
	head: BasePart?,
	life: number, -- bumped every spawn / despawn: stale threads stop
	fighting: boolean,
	postRound: boolean,
	idleUntil: number,
	gun: BotGun.GunState,
	loadout: { [any]: string },
	-- Brain.
	memory: { [Model]: Memory },
	sightCursor: number,
	target: Memory?,
	targetSince: number,
	goal: string,
	goalSince: number,
	nextThink: number,
	strafeDir: number, -- -1, 0, 1
	strafeUntil: number,
	crouchUntil: number,
	moveDir: Vector3, -- world, flat (what act steers)
	steerInput: Vector3, -- smoothed intent, checked against the world before applying
	wantSprint: boolean,
	wantCrouch: boolean,
	lookAt: Vector3?, -- where to face when not aiming at a target
	roamGoal: Vector3?, -- the patrol point it's heading for with no information
	openingLane: number?,
	openingStyle: "Flanker" | "Controller" | "Holder",
	openingOffset: Vector3,
	lastRoam: Vector3?,
	roamBlocked: { [Vector3]: number },
	coverGoal: Vector3?,
	peekGoal: Vector3?,
	coverAt: number,
	coverUntil: number,
	peekUntil: number,
	zone: Zone.State?,
	slideCheckAt: number,
	-- Aim (Bots/Aim).
	yaw: number,
	pitch: number,
	yawVel: number,
	pitchVel: number,
	aimError: Vector2, -- degrees, decays toward the profile floor
	aimWobble: Vector2, -- degrees: the drifting point at the floor it settles toward
	recoil: Vector2, -- degrees of kick not yet pulled back
	triggerAt: number, -- os.clock() the trigger may first go
	missLeft: number, -- fair misses left on the current target
	burstLeft: number,
	burstRestUntil: number,
	-- Mods (Bots/BotMods).
	kit: { string }, -- Mod id per slot ("" = none)
	levels: { string },
	modReadyAt: { number }, -- server Mods: os.clock() a charge is back
	modCharges: { number },
	modRetryAt: { number }, -- wait before retrying a cast that failed its release checks
	nextModTry: number,
	lastHurtAt: number,
	lastHealth: number,
	nav: Nav,
	connections: { RBXScriptConnection },
}

return nil
