--!strict
-- Types for the Mod (ability) system (vault/04 Tech/Mod System.md). Data
-- lives in Config/Mods; code only ever reads stats resolved by Mods.stats.

-- Instant: press and it happens. Held*: press to hold it (gun lowered),
-- LMB / RMB to use it (Mods.md → Controls and activation). HeldSteer: the use
-- keeps going while you steer it (Firewall: hold LMB, turn to curve).
-- HeldCharge: hold LMB to charge, release to use; RMB sets an option (Recon:
-- the shot's power and its bounces).
export type Activation =
	"Instant"
	| "HeldThrow"
	| "HeldPlace"
	| "HeldTarget"
	| "HeldSteer"
	| "HeldCharge"

-- Simulation: predicted inside shared/Simulation/Abilities (no remote).
-- Server: requested with ModUse; ModService validates and applies.
export type Authority = "Simulation" | "Server"

-- L1, then path A (A2 → A3), path B (B2 → B3) or the glitch path (G2 → G3).
export type LevelId = "L1" | "A2" | "A3" | "B2" | "B3" | "G2" | "G3"

-- One level's numbers. A level only lists what changes from the level before
-- it on its path; `note` describes the level for the dev panel.
export type Level = { [string]: any }

-- Resolved stats for one (id, level): every key from L1 up to that level.
-- Every Mod has at least `charges` (per round) and `cooldown` (seconds per
-- charge; 0 = no recharge until the next round), see Mods/Charges.
export type Stats = { [string]: any }

export type UseMode = "Primary" | "Alt"

export type ModDef = {
	id: string,
	name: string,
	role: string,
	-- The one slot this ability lives in (1 = Q, 2 = E, 3 = T for now).
	slot: number,
	-- Names of path A, path B and the glitch path (draft cards, dev panel).
	paths: { A: string, B: string, G: string },
	block: string, -- shared building block (Mods/Blocks)
	activation: Activation,
	authority: Authority,
	icon: string, -- rbxassetid, "" until the icon is uploaded
	glyph: string, -- placeholder icon text while `icon` is empty
	-- Held-mode hint words for LMB / RMB (nil: that button does nothing).
	hint: { primary: string?, alt: string? },
	-- What quick-cast (and a mobile tap) does on press, for held Mods.
	quickCast: UseMode?,
	-- The third-person clip a use plays (Simulation/Poses), when it isn't
	-- the activation's own (Stim: "Place").
	useKind: string?,
	levels: { [string]: Level },
}

-- A slot of a loadout.
export type SlotLoadout = { id: string, level: LevelId }

-- Mod modules (shared/Mods/<Id>.luau) ------------------------------------------

-- Inside the simulation (Simulation/Abilities): a predicted cast.
export type SimCtx = {
	player: Player,
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	stats: Stats,
	slot: number,
	now: number, -- time()
}

-- A use request after ModService checked its types.
export type Request = {
	mode: UseMode,
	origin: Vector3, -- the client's camera position
	direction: Vector3, -- unit camera look
	target: Model?, -- Patch Up: the ally the client aimed at
	placement: CFrame?, -- placed Mods: the spot `validate` found (server's own check)
	charge: number?, -- HeldCharge: 0..1 (validate clamps it to how long it was held)
	bounces: number?, -- Recon: 0..2 wall bounces
}

-- What ModService hands a Mod's validate / apply. Everything that changes the
-- world goes through these functions, so Mods never touch other services.
export type ServerCtx = {
	player: Player,
	character: Model,
	humanoid: Humanoid,
	head: BasePart,
	slot: number,
	id: string,
	level: string,
	stats: Stats,
	now: number, -- workspace:GetServerTimeNow()
	heldFor: number, -- seconds the server has had this Mod held (0 for Instant)
	-- Fresh line-of-sight params: world only (no bodies, no effects). A call,
	-- so a delayed effect (a fuse) sees who exists when it goes off.
	worldParams: () -> RaycastParams,
	-- Where the server's copy of the camera looks (else the claimed aim).
	cameraLook: Vector3,
	damage: (victim: Model, amount: number, at: Vector3) -> (),
	-- `amount` over `duration` seconds (0 = at once), from the caster. A new
	-- heal on the same target replaces what's left of the old one.
	heal: (target: Model, amount: number, duration: number) -> (),
	-- `amount` at once, without touching a heal over time already running
	-- (a heal zone's ticks).
	restore: (target: Model, amount: number) -> (),
	fx: (kind: string, data: { [string]: any }) -> (),
	-- Runs `fn` after `delay` seconds unless the caster leaves first.
	schedule: (delay: number, fn: () -> ()) -> (),
	-- A world object owned by the caster (ModEntities): `life` seconds, `hp`,
	-- at most `maxActive` of this kind at once (the oldest goes).
	place: (kind: string, part: BasePart, life: number, hp: number, maxActive: number) -> (),
	-- Puts a shared status effect (Config/StatusEffects: "Hinder") on
	-- `model` for `duration` seconds (a refresh: no stacking).
	status: (model: Model, name: string, duration: number) -> (),
	-- Shows `targets` to the caster's team only, for `duration` seconds.
	-- `style` (an upgrade's own look, Recon's "Spike") reaches the clients'
	-- UpgradeFx with the caster and level, and the revealed players' warning.
	reveal: (targets: { Model }, duration: number, style: string?) -> (),
	-- The caster's guns fire `mult` times as fast for `duration` seconds.
	fireRate: (mult: number, duration: number) -> (),
	-- The HUD shows the slot's effect running for `duration` seconds.
	active: (duration: number) -> (),
	-- Mod objects near a point, and damage to one (not the caster's team's).
	objectsNear: (at: Vector3, radius: number) -> { BasePart },
	damageObject: (part: BasePart, amount: number) -> (),
	-- Starts building a wall from the caster's feet (HeldSteer): the hold
	-- lasts until it's built.
	wall: (spec: WallSpec) -> (),
	-- Recall: the anchor just placed (Services/ModRecall keeps it), and
	-- whether one is already down.
	anchor: (part: BasePart) -> (),
	anchorDown: boolean,
}

-- A wall to build (Firewall → Services/ModWalls): the way it starts going,
-- and whether it ignores steering.
export type WallSpec = {
	heading: Vector3, -- flat unit
	straight: boolean,
}

-- What a Mod module's `server` hook gets once, when ModService starts: for
-- effects that aren't a use (a passive, a landing in the simulation, a
-- damage rule). Damage guards and modifiers run for every hit in the game,
-- so keep them cheap and return the amount unchanged when they don't apply.
export type ServerApi = {
	-- The slot and level `player` has this Mod in (nil: not slotted).
	slotOf: (player: Player, id: string) -> (number?, string?),
	-- Damage from `attacker`'s Mod `id` (kill feed, hit confirm, as ctx.damage).
	damage: (attacker: Player, victim: Model, amount: number, at: Vector3, id: string) -> (),
	status: (model: Model, name: string, duration: number) -> (),
	-- ModFx to every client (kind, data); data.caster / team / id are filled in.
	fx: (caster: Player, id: string, kind: string, data: { [string]: any }) -> (),
	-- Every hit on a combatant passes through each guard first (WeaponService.hurt):
	-- return the amount to deal (0 blocks it). `attacker` is nil for damage
	-- with no player behind it (the test opponent).
	guard: (
		fn: (victim: Model, humanoid: Humanoid, amount: number, attacker: Player?) -> number
	) -> (),
	-- Player-on-player damage (guns and Mods) passes through each modifier
	-- before the guards: return the new amount.
	modifier: (
		fn: (attacker: Player, victim: Model, amount: number, sourceId: string) -> number
	) -> (),
	-- Called at every round start (ModService.refillCharges), per player.
	onRefill: (fn: (player: Player) -> ()) -> (),
	-- World-only raycast params (as ctx.worldParams).
	worldParams: () -> RaycastParams,
	-- Server time (workspace:GetServerTimeNow()).
	now: () -> number,
}

export type ModModule = {
	-- Simulation Mods: returns true when it cast (spends a charge).
	simCast: ((ctx: SimCtx) -> boolean)?,
	-- Server Mods: Mod-specific checks, then the effect. `validate` may fill
	-- in `req.target`. Returns false and a reason to reject.
	validate: ((ctx: ServerCtx, req: Request) -> (boolean, string?))?,
	apply: ((ctx: ServerCtx, req: Request) -> ())?,
	-- Whether this use spends a charge (nil: it does). Recall's planting
	-- doesn't: its charge is the teleport.
	spends: ((ctx: ServerCtx, req: Request) -> boolean)?,
	-- Server only, once at start (see ServerApi).
	server: ((api: ServerApi) -> ())?,
}

return nil
