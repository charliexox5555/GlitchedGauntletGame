--!strict
-- The range's air targets (vault/01 Design/Range v5.md). Owner 2026-11-26: "red circle targets [in the air] that you
-- can shoot down. They break, like they shatter". Our own target: a 16-sided bullseye (dark rim, red / white rings,
-- `ServerStorage.V5Kit.AirTarget`, built in Studio with solid modelling), floating over the yard, some drifting.
-- Per player (owner 2026-11-26: "completely client-sided ... separate per player"): the server decides each break
-- from the shot's own rays and tells only the shooter (LobbyServer Range/RangeTargets, LobbyNet RangeTargetEvent);
-- each client draws the motion from the server clock (shared/RangeTargetMotion), turns every target to face its
-- camera, and plays its own shatters (Controllers/RangeTargetsController). The server never moves them.
-- Times are seconds, distances studs, angles degrees.

return table.freeze({
	TAG = "RangeTarget", -- on each target Model (Workspace.LobbyV5.Range.Targets)
	RESPAWN = 3.5, -- s a broken target stays gone (for the player who broke it: targets are per player)
	-- The server's hit test (each player sees every target turned to face them, so the server treats it as a ball):
	-- a ray that passes within RADIUS of the centre, before anything solid, breaks it.
	RADIUS = 2.15,
	LAG_SLACK = 0.2, -- s: the centre is also tried this far in the past (the shooter saw it a ping ago)
	-- Facing (client): each target turns to face your camera at this rate (1/s, eased).
	TURN = 7,

	-- Motion (attributes on a target override these): it bobs, sways a little on its axis, and may drift along its
	-- own right (`Drift` studs either way) with `Period` seconds per sweep.
	BOB = 0.35,
	BOB_PERIOD = 3.2,
	PERIOD = 5,

	-- The shatter (client).
	SHARDS = 26, -- pieces (scaled by the player's VFX setting)
	SHARD_SIZE = { 0.45, 1.05 }, -- first look (0.25-0.75, 0.12 thick) read as dust at 15 studs
	SHARD_THICK = 0.18,
	SHARD_SPEED = { 8, 22 }, -- studs/s outwards from the hit
	PUSH = 10, -- studs/s along the shot
	SHARD_LIFE = 0.9,
	FLASH_TIME = 0.14, -- the white pop at the hit
	FLASH_SIZE = 6,
	-- Coming back: it grows in from this share of its size.
	RETURN_FROM = 0.2,
	RETURN_TIME = 0.32,
})
