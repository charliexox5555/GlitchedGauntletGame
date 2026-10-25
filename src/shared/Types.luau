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
export type FireMode = "Semi" | "Auto" | "Pump" | "Bolt" | "Charge" | "Melee"
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
	burstInterval: number?,
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
	sounds: WeaponSounds,
	-- Viewmodel placement: where the grip sits relative to the camera.
	viewmodelOffset: Vector3,
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
