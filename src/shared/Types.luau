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
export type FireMode = "Semi" | "Auto" | "Burst" | "Pump" | "Bolt" | "Melee"
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

-- A holographic sight added to the viewmodel gun: a glass pane with a dot and
-- ring, centred at `center` (gun space, world-size studs). Aiming looks through
-- it. `frame = false` draws only the reticle (inside a low-power optic whose
-- own lens is hidden while aiming).
export type Reticle = { center: Vector3, size: Vector2, color: Color3, frame: boolean? }

export type WeaponSounds = {
	fire: string,
	fireVolume: number?, -- multiplier on Audio.SHOT_VOLUME (loudness per class is baked)
	firePitch: number?,
	reload: string?,
	equip: string?,
	cycle: string?, -- bolt / pump / charging handle: after each Pump/Bolt shot, empty reloads and the first draw
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
	spinUp: SpinUp?,
	magSize: number,
	reloadTime: number,
	emptyReloadTime: number,
	equipTime: number,
	-- The first draw of a life (racks the action, client-side only); default equipTime.
	firstEquipTime: number?,
	range: number,
	falloff: Falloff?,
	hipSpread: number, -- degrees
	adsSpreadMultiplier: number,
	bloomPerShot: number,
	maxBloom: number,
	recoil: Recoil,
	adsFov: number,
	adsTime: number,
	moveMultiplier: number,
	adsMoveMultiplier: number,
	penetration: Penetration,
	pierceCharacters: boolean?,
	suppressed: boolean?,
	melee: MeleeStats?,
	moveSpreadMultiplier: number?, -- scales movement spread
	crouchSpreadMultiplier: number?, -- < 1: steadier crouched
	noAds: boolean?, -- akimbo guns
	-- Models to hold: by default the model named like the id. Akimbo guns hold two.
	models: { right: string, left: string? }?,
	sounds: WeaponSounds,
	-- Viewmodel placement at the hip, camera space: long guns put their sight
	-- height at this point at their grip's depth; sidearms, melee and akimbo guns
	-- put their grip here. Optional cant in degrees (default none: the barrel
	-- points straight down the view).
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
