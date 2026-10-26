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

-- Damage falloff in steps (Gunplay.md §3): from `from` studs on, damage is
-- multiplied by `multiplier`. Sorted by distance; the last step that applies wins.
export type FalloffStep = { from: number, multiplier: number }

-- Spread (Gunplay.md §2, v2), degrees. A spray builds "heat" (+1 per shot,
-- cooling to 0 over `recoveryTime` without firing); the first `protected`
-- shots add `protectedGrowth` each, later ones `growth`, up to `max`.
export type SpreadStats = {
	first: number, -- first-shot cone, standing, hip
	adsMultiplier: number, -- fully aimed
	protected: number,
	protectedGrowth: number,
	growth: number,
	max: number, -- first + growth never exceeds this (movement adds on top)
	recoveryTime: number,
}

-- Camera recoil with a learnable pattern (Gunplay.md §2, v2), degrees per shot:
-- `up` for the first `protected` shots of a spray (pure vertical), then
-- `upAfter` plus `side` in one direction, which swaps with `switchChance` per
-- shot (at least `switchMinTime` apart). Once you stop, `recover` of the climb
-- returns over `recoverTime`.
export type Recoil = {
	up: number,
	protected: number,
	upAfter: number,
	side: number,
	switchChance: number,
	switchMinTime: number,
	recover: number,
	recoverTime: number,
}

-- Alt-fire on the Aim input, for guns with no ADS (Valorant's Classic: a
-- 3-pellet close-range burst). Each pellet does the gun's normal damage.
export type AltFire = {
	pellets: number,
	pelletSpread: number, -- degrees, cone for the pellets
	fireInterval: number, -- no shot of either kind until this long after an alt shot
	ammo: number, -- rounds one alt shot uses
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

export type WeaponConfig = {
	id: string,
	displayName: string,
	class: WeaponClass,
	tier: number, -- 1..4, 0 = melee
	slot: Slot,
	fireMode: FireMode,
	damage: { body: number, head: number?, legs: number? }, -- head/legs default: Weapons multipliers
	pellets: number,
	pelletSpread: number, -- degrees, cone for pellets
	fireInterval: number, -- seconds between shots
	burst: BurstStats?,
	altFire: AltFire?, -- needs noAds (it uses the Aim input)
	-- Muzzle attachments the shots come from in turn, by round in the mag
	-- (a double barrel: { "Muzzle", "MuzzleLower" }). Default { "Muzzle" }.
	muzzles: { string }?,
	-- false: no casing per shot (break-action, revolver); the reload clip
	-- shows the spent shells instead. Default true.
	shellsOnFire: boolean?,
	-- Viewmodel props hidden once their rig joint is this far (studs, model
	-- size) from rest: a spent shell vanishes as it's pulled clear of the gun
	-- and the fresh one appears as it nears the chamber.
	hideBeyond: { [string]: number }?,
	-- After the last round the action stays open (a pistol's slide locked
	-- back: the first frame of its ReloadEmpty clip) until the reload.
	lockOnEmpty: boolean?,
	spinUp: SpinUp?,
	magSize: number,
	reloadTime: number,
	emptyReloadTime: number,
	equipTime: number,
	-- The first draw of a life (racks the action, client-side only); default equipTime.
	firstEquipTime: number?,
	range: number,
	falloff: { FalloffStep }?, -- nil = no falloff
	spread: SpreadStats,
	recoil: Recoil,
	adsFov: number,
	adsTime: number,
	moveMultiplier: number,
	adsMoveMultiplier: number,
	penetration: Penetration,
	pierceCharacters: boolean?,
	suppressed: boolean?,
	melee: MeleeStats?,
	-- Row of Config/Combat MOVE_PENALTY (default: the gun's class).
	moveClass: string?,
	noAds: boolean?, -- akimbo guns
	-- Models to hold: by default the model named like the id. Akimbo guns hold two.
	models: { right: string, left: string? }?,
	-- Sounds live in Config/GunSounds (one entry per gun id).
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
