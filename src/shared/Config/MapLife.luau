--!strict
-- Map life (Controllers/MapLifeController), 2026-11-05, lane F: client-only
-- ambient motion on the maps. Fans turn, the crane's load sways, gulls
-- circle, pigeons take off when someone walks up, steam rises from vents,
-- signs flicker, banners and flags move in the wind, a ship drifts far out.
-- Purely cosmetic: no remotes, nothing the server sees.
--
-- How it works: per-map scripts (tools/studio/maps/<Map>/Life.luau) build
-- a "Life" folder in the map and tag what should move. Every tagged part
-- must be CanCollide false (the controller refuses any other, so nothing in
-- play ever moves collision). Each kind's own numbers sit on the tagged
-- instance as attributes; the shared ones are here.
--
-- Tags and their attributes:
--   LifeSpin    BasePart/Model: SpinSpeed (deg/s), Axis (Vector3, world; default the part's up)
--   LifeSway    BasePart/Model: Pivot (Vector3, world), SwayDeg, SwayHz, SwayAxis (Vector3, world),
--               optional Sway2Deg / Sway2Axis (a second, slower wobble)
--   LifePulse   BasePart: PulseMin, PulseMax (Transparency), PulseHz
--   LifeFlicker BasePart: FlickerTo (Transparency while off), FlickerGap ({min, max} s as Vector2)
--   LifeGull    Model (Body, Wing*): Center (Vector3), Radius, Speed (deg/s), Phase (deg)
--   LifePigeon  Model (Body, Head, Wing*): FleeDir (Vector3)
--   LifeDrift   Model: From, To (Vector3), Speed (studs/s)
--   LifeEmitter ParticleEmitter: Range (studs; default EMITTER_RANGE)
-- Any tagged instance may also carry Wake (studs): it sleeps beyond that.
--
-- Parts of a map's own art (lane G's meshes) are never tagged or edited.
-- A RULE (a Configuration tagged LifeRule inside the map's Life folder)
-- moves them instead: Kind ("Spin", "Sway", "Flicker", "Rotor"), Target (the
-- parts' or models' Name), optional Only (the first N matches), plus that
-- kind's attributes; for Sway, PivotY (world Y) pivots each match about its
-- own centre at that height. Rotor puts client copies of Template (a model in
-- the Life folder) at Offset1..Offset4 on each match and spins them (Spin
-- attributes). The rules survive a rebuild of the art.
-- LifeGull models may override FlapHz, FlapDeg (circling pigeons use them).
-- LifePigeon models may override FlapHz, FlapDeg, Away, Rise, Sound, Volume
-- (perched gulls on Dockyard2 use the same take-off code as the pigeons).
-- Wing parts are named WingL* / WingR* and hinge at the Model's HingeX
-- (studs from the body's centre, along the body's right).

return table.freeze({
	RULE = "LifeRule",
	TAG = table.freeze({
		Spin = "LifeSpin",
		Sway = "LifeSway",
		Pulse = "LifePulse",
		Flicker = "LifeFlicker",
		Gull = "LifeGull",
		Pigeon = "LifePigeon",
		Drift = "LifeDrift",
		Emitter = "LifeEmitter",
	}),
	-- Asleep beyond this many studs from the camera (LihFolk "VFX Performance
	-- Budgets and Culling": decoration drops beyond about 160 studs).
	WAKE = 170,
	EMITTER_RANGE = 140,
	TICK = 0.25, -- seconds between wake checks
	-- At or below this graphics quality level (1-10), emitters run at half rate.
	LOW_QUALITY = 4,
	GULL = table.freeze({
		wake = 450,
		flapHz = 2.4,
		flapDeg = 32,
		bank = 14, -- degrees of roll into the turn
		bob = 1.2, -- studs up and down along the circle
	}),
	PIGEON = table.freeze({
		scare = 15, -- a character this close (studs) sends the flock up
		calm = 32, -- they come back only when nobody is this close
		flyTime = 4.2, -- seconds from the perch to gone
		rise = 28,
		away = 110, -- out over the street, past the parapets, before they fade
		back = { 22, 40 }, -- seconds away before they return
		flapHz = 8,
		flapDeg = 55,
		sound = "atlas:AmbFlap",
		volume = 0.5,
		range = 70,
	}),
})
