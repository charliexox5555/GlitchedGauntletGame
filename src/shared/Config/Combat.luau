--!strict
-- Combat rules shared by the server (authoritative) and the client (feel).

return table.freeze({
	MAX_HEALTH = 100,
	RESPAWN_TIME = 3,

	-- Spread added on top of a gun's hip spread (Gunplay.md §2), degrees.
	MOVE_SPREAD = {
		Idle = 0,
		Walk = 0.4,
		Sprint = 0.6,
		Slide = 0.8,
		Air = 2.5,
	},
	BLOOM_RECOVERY = 6, -- degrees per second once you stop firing
	BLOOM_RECOVERY_DELAY = 0.12,

	-- Server validation tolerances. Generous enough for ~250 ms ping,
	-- tight enough that hits through walls / across the map are rejected.
	ORIGIN_TOLERANCE = 7, -- studs between claimed muzzle origin and server head
	HIT_POSITION_TOLERANCE = 6, -- studs between claimed hit and the part's recent positions
	DIRECTION_TOLERANCE = 4, -- extra degrees allowed on top of the gun's max spread
	FIRE_INTERVAL_TOLERANCE = 0.75, -- shots may arrive this share of the interval early (jitter)
	HISTORY_SECONDS = 1, -- how far back hitbox history goes
	MAX_HITS_PER_SHOT = 12,

	-- Lag-tolerant melee reach on the server, on top of the weapon's range.
	MELEE_TOLERANCE = 3,
	BACKSTAB_DOT = 0.45, -- target facing away by more than this counts as a backstab

	-- Remote budgets (per player): rate per second, burst.
	RATE = {
		Fire = { 30, 40 },
		Equip = { 10, 10 },
		Reload = { 5, 5 },
		Aim = { 20, 30 },
		Charge = { 5, 5 },
		Dev = { 5, 5 },
	},

	-- Parts tagged with this can be shot through by guns with penetration = "ThinWall".
	THIN_WALL_TAG = "ThinWall",
})
