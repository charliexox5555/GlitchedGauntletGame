--!strict
-- The bot record shared by the bot modules (vault/01 Design/Bots.md).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BotsConfig = require(ReplicatedStorage.Shared.Config.Bots)
local BotGun = require(script.Parent.BotGun)

export type Memory = {
	model: Model,
	lastPos: Vector3,
	seenAt: number, -- os.clock() last seen (or heard)
	visibleSince: number?, -- os.clock() it came into sight (nil: not in sight)
	visible: boolean,
	heard: boolean, -- the position is a rough heard one
	headVisible: boolean, -- its head showed on the last look
	aimPart: string, -- "Head" or "UpperTorso": where this bot aims at it
}

export type Nav = {
	goal: Vector3?,
	waypoints: { PathWaypoint },
	index: number,
	computedAt: number,
	computedFor: Vector3?,
	computing: boolean,
	lastSamplePos: Vector3,
	lastSampleAt: number,
	stuck: number,
}

export type Bot = {
	key: { name: string }, -- the draft seat key (MatchService / DraftService)
	name: string,
	team: number,
	profile: BotsConfig.Profile,
	owner: Configuration, -- stands in for a Player (Simulation/Pawns)
	inputs: { [string]: InputAction },
	model: Model?,
	humanoid: Humanoid?,
	root: BasePart?,
	head: BasePart?,
	life: number, -- bumped every spawn / despawn: stale threads stop
	fighting: boolean,
	gun: BotGun.GunState,
	loadout: { [any]: string },
	-- Brain.
	memory: { [Model]: Memory },
	target: Memory?,
	targetSince: number,
	goal: string,
	goalSince: number,
	nextThink: number,
	strafeDir: number, -- -1, 0, 1
	strafeUntil: number,
	crouchUntil: number,
	moveDir: Vector3, -- world, flat (what act steers)
	wantSprint: boolean,
	wantCrouch: boolean,
	lookAt: Vector3?, -- where to face when not aiming at a target
	-- Aim (Bots/Aim).
	yaw: number,
	pitch: number,
	yawVel: number,
	pitchVel: number,
	aimError: Vector2, -- degrees, decays toward the profile floor
	aimWobble: Vector2, -- degrees: the drifting point at the floor it settles toward
	recoil: Vector2, -- degrees of kick not yet pulled back
	triggerAt: number, -- os.clock() the trigger may first go
	burstLeft: number,
	burstRestUntil: number,
	-- Mods (Bots/BotMods).
	kit: { string }, -- Mod id per slot ("" = none)
	levels: { string },
	modReadyAt: { number }, -- server Mods: os.clock() a charge is back
	modCharges: { number },
	nextModTry: number,
	lastHurtAt: number,
	lastHealth: number,
	nav: Nav,
	connections: { RBXScriptConnection },
}

return nil
