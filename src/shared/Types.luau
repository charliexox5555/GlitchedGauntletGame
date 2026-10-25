--!strict
-- Shared type definitions. Types that cross the client/server boundary
-- (remote payloads, profile schema, config shapes) live here so both sides agree.

export type PlayerProfile = {
	version: number,
	level: number,
	xp: number,
}

-- Weapons ------------------------------------------------------------------

export type Slot = "Primary" | "Secondary" | "Melee"
export type FireMode =
	"Semi"
	| "Auto"
	| "Burst"
	| "Pump"
	| "Bolt"
	| "Charge"
	| "Melee"
	| "Projectile"
	| "Beam"
export type WeaponClass =
	"Sidearm"
	| "SMG"
	| "Shotgun"
	| "Rifle"
	| "Sniper"
	| "MachineGun"
	| "Wildcard"
	| "Melee"
export type Penetration = "None" | "ThinWall" | "All"
export type HitZone = "Head" | "Body" | "Legs"

-- Damage multiplier by distance: full damage until `start`, then a straight
-- line down to `minMultiplier` at `finish`.
export type Falloff = { start: number, finish: number, minMultiplier: number }

export type Recoil = {
	up: number, -- degrees of camera kick per shot
	side: number, -- +/- random sideways degrees per shot
	recover: number, -- share of the kick that recovers on its own (0..1)
}

export type SpinUp = { startInterval: number, endInterval: number, time: number }

export type MeleeStats = { range: number, backDamage: number, lunge: number }

-- Burst guns: `count` shots `interval` apart, then the gun's fireInterval.
export type BurstStats = { count: number, interval: number, singleWhenAiming: boolean? }

-- Server-simulated projectile (Loopback discs).
export type ProjectileStats = { speed: number, radius: number, bounces: number, lifetime: number }

-- Continuous beam (Null): damage per second ramps while it stays on the same
-- target; a battery drains while firing and recharges after a pause.
export type BeamStats = {
	dpsStart: number,
	dpsEnd: number,
	rampTime: number,
	tick: number, -- seconds between damage ticks (each tick is one "shot")
	battery: number, -- seconds of beam
	rechargeDelay: number,
	rechargeRate: number, -- battery seconds regained per second
}

-- A holographic sight added to the viewmodel gun: a glass pane with a dot and
-- ring, centred at `center` (gun space, world-size studs). Aiming looks through
-- it. `frame = false` draws only the reticle (inside a low-power optic whose
-- own lens is hidden while aiming).
export type Reticle = { center: Vector3, size: Vector2, color: Color3, frame: boolean? }

export type WeaponSounds = {
	fire: string,
	fireVolume: number?,
	firePitch: number?,
	reload: string?,
	equip: string?,
	charge: string?,
}

export type WeaponConfig = {
	id: string,
	displayName: string,
	class: WeaponClass,
	tier: number, -- 1..4, 0 = melee
	slot: Slot,
	fireMode: FireMode,
	damage: { body: number, head: number, legs: number? },
	pellets: number,
	pelletSpread: number, -- degrees, cone for pellets
	fireInterval: number, -- seconds between shots
	burst: BurstStats?,
	projectile: ProjectileStats?,
	beam: BeamStats?,
	spinUp: SpinUp?,
	chargeTime: number?,
	magSize: number,
	reloadTime: number,
	emptyReloadTime: number,
	equipTime: number,
	range: number,
	falloff: Falloff?,
	hipSpread: number, -- degrees
	adsSpreadMultiplier: number,
	bloomPerShot: number,
	maxBloom: number,
	recoil: Recoil,
	adsFov: number,
	adsTime: number,
	scope: boolean?,
	moveMultiplier: number,
	adsMoveMultiplier: number,
	penetration: Penetration,
	pierceCharacters: boolean?,
	suppressed: boolean?,
	melee: MeleeStats?,
	moveSpreadMultiplier: number?, -- scales movement spread (Flicker: big, Dual Boot: small)
	crouchSpreadMultiplier: number?, -- Overflow is steadier crouched
	noAds: boolean?, -- Dual Boot
	-- Models to hold: by default the model named like the id. Dual Boot holds two.
	models: { right: string, left: string? }?,
	sounds: WeaponSounds,
	-- Viewmodel placement at the hip: where the sight (AimPoint) sits relative
	-- to the camera (melee: the grip), and an optional cant in degrees around
	-- it (default none: the barrel points straight down the view).
	viewmodelOffset: Vector3,
	viewmodelRotation: Vector3?,
	viewmodelScale: number?, -- default Viewmodel.SCALE
	-- Sight picture: camera-to-AimPoint distance (default Viewmodel.ADS_DISTANCE),
	-- a camera-space nudge, and parts faded out while aiming so they don't block the sight.
	adsDistance: number?,
	adsOffset: Vector3?,
	adsHide: { string }?,
	adsReticle: Reticle?,
	tracerColor: Color3,
}

-- Remote payloads ----------------------------------------------------------

export type HitClaim = {
	part: BasePart,
	position: Vector3,
	pellet: number,
}

export type WeaponSlotState = { id: string, ammo: number }

export type WeaponState = {
	slots: { [Slot]: WeaponSlotState },
	equipped: Slot?,
	seedBase: number, -- spread seeds come from this + the shot counter
	shotIndex: number, -- last shot counter the server accepted
}

export type HitConfirm = {
	damage: number,
	zone: HitZone,
	killed: boolean,
	position: Vector3,
}

return nil
