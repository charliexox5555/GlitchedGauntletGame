--!strict
-- Tempest-Strike: where each gun's effects sit and which of its parts move
-- (Util/TempestIdle). Points are Blender units of the gun's export (X down the
-- bore, Y to the gun's left, Z up, origin at the grip), from each gun's stock
-- contract and measured cross-sections (vault 02 Art/Skins/TempestStrike/Line
-- Build Ledger.md). Shared looks and timings stay in SkinPreview.TEMPEST.
--
-- helix: two water ribbons wrapping the fore-end (x0 -> x1, radii and centre
--        height at each end); arcs: lightning anchors; glow: the rim light;
-- pulse: the per-shot ring, receiver front -> muzzle (ring sizes at each end);
-- bore: the height of the bore line for the rings; drawRing / inspectRun: the
--        ring's run (x and radius at each end); roll: the wide ring for the
--        inspect roll; lock: the draw-lock splash;
-- sweep: the band of rings along the gun ({ x, radius, centre z } stations);
-- sight: the crescent's plane and tips (nil = no iron sight on the aim line);
-- well: magwell mouth (Handle space, mag guns); load: where rounds go in (shell guns);
-- flaps: plates that flare like vents (1 = gun's left, -1 = right);
-- spinners: rings that turn about the bore (crescent, scope rings); gate: a loading gate;
-- tracks: the Config/Viewmodel tracks to use (nil = the gun's stock track, or none);
-- roll: inspect barrel-roll window (track progress); reloadSpin: the reload
--        track rolls the gun after the seat (Vandal's own reload only);
-- fit: the rings and the shot pulse follow the sweep stations as a measured
--        outline (stations every ~0.1 from Blender ray casts of the export,
--        radius = the bigger half-extent + 0.03, centre = mid height; mag,
--        grip and lever ignored). Measured 2026-11-22 (Line Build Ledger).
export type Station = { number }
export type Profile = {
	helix: {
		x0: number,
		x1: number,
		ry0: number,
		ry1: number,
		rz0: number,
		rz1: number,
		z0: number,
		z1: number,
	},
	arcs: { Station },
	glow: Station,
	pulse: { x0: number, x1: number, z: number, size0: number?, size1: number? },
	bore: number,
	drawRing: { x0: number, x1: number, r0: number, r1: number },
	inspectRun: { x0: number, x1: number, r0: number, r1: number },
	roll: { x: number, z: number, r: number, rollIn: number, catch: number },
	lock: Station,
	sweep: { Station },
	sight: { x: number, tipY: number, tipZ: number, apexZ: number }?,
	well: Vector3?,
	load: Station?,
	flaps: { { name: string, side: number } },
	spinners: { string },
	gate: string?,
	tracks: {
		draw: string?,
		reload: string?,
		inspect: string?,
		reloadStart: string?, -- shell-by-shell reloads, one track per clip part
		reloadInsert: string?,
		reloadEnd: string?,
		cycle: string?, -- over every shot's Fire clip (the Marshal's lever)
	},
	reloadSpin: boolean,
	fit: boolean,
}

local function v(x: number, y: number, z: number): Station
	return { x, y, z }
end

local VENTS = { { name = "TS_VentL", side = 1 }, { name = "TS_VentR", side = -1 } }

local profiles: { [string]: Profile } = {
	Vandal = {
		helix = {
			x0 = 1.08,
			x1 = 2.02,
			ry0 = 0.114,
			ry1 = 0.068,
			rz0 = 0.152,
			rz1 = 0.094,
			z0 = 0.3,
			z1 = 0.314,
		},
		arcs = { v(0.55, 0.098, 0.378), v(1.3, 0, 0.418), v(1.55, 0.084, 0.24) },
		glow = v(1.2, 0.05, 0.36),
		pulse = { x0 = 1.05, x1 = 2.6, z = 0.3, size0 = 0.38, size1 = 0.18 },
		bore = 0.3,
		drawRing = { x0 = 2.55, x1 = 1.0, r0 = 0.1, r1 = 0.17 },
		inspectRun = { x0 = 2.35, x1 = 1.05, r0 = 0.15, r1 = 0.21 },
		roll = { x = 1.2, z = 0.3, r = 0.34, rollIn = 0.44, catch = 0.59 },
		lock = v(1.2, 0, 0.32),
		sweep = {
			v(0.0, 0.25, 0.26),
			v(1.05, 0.25, 0.26),
			v(1.06, 0.18, 0.3),
			v(1.9, 0.18, 0.3),
			v(1.91, 0.11, 0.3),
			v(2.55, 0.11, 0.3),
		},
		sight = { x = 0.078, tipY = 0.041, tipZ = 0.62, apexZ = 0.645 },
		well = Vector3.new(0, 0.12, -0.6),
		load = nil,
		flaps = VENTS,
		spinners = { "TS_Crescent" },
		gate = nil,
		tracks = { draw = "DrawTempest", reload = "ReloadTempest", inspect = "InspectTempest" },
		reloadSpin = true,
		fit = false,
	},
	-- SMG: receiver to 0.46, shroud 0.46-0.82, thin barrel and brake to the muzzle at 1.14 (bore 0.294).
	-- No vent flaps (owner 2026-11-22: the flaring plates looked odd).
	Stinger = {
		helix = {
			x0 = 0.5,
			x1 = 0.8,
			ry0 = 0.1,
			ry1 = 0.097,
			rz0 = 0.163,
			rz1 = 0.154,
			z0 = 0.268,
			z1 = 0.248,
		},
		arcs = { v(0.0, 0.095, 0.37), v(0.65, 0, 0.405), v(0.7, 0.1, 0.16) },
		glow = v(0.4, 0, 0.3),
		pulse = { x0 = 0.48, x1 = 1.14, z = 0.28 },
		bore = 0.294,
		drawRing = { x0 = 1.12, x1 = 0.45, r0 = 0.06, r1 = 0.17 },
		inspectRun = { x0 = 1.08, x1 = 0.3, r0 = 0.08, r1 = 0.19 },
		roll = { x = 0.3, z = 0.28, r = 0.3, rollIn = 0.44, catch = 0.59 },
		lock = v(0.6, 0, 0.26),
		sweep = {
			v(-0.54, 0.15, 0.278),
			v(-0.45, 0.178, 0.286),
			v(-0.15, 0.19, 0.28),
			v(0.35, 0.19, 0.28),
			v(0.5, 0.18, 0.27),
			v(0.8, 0.17, 0.262),
			v(0.86, 0.15, 0.295),
			v(0.92, 0.085, 0.298),
			v(1.14, 0.08, 0.294),
		},
		-- the crescent is the Vandal's at 0.84 scale (same pips), on the Stinger's AimPoint
		sight = { x = -0.408, tipY = 0.034, tipZ = 0.528, apexZ = 0.549 },
		well = Vector3.new(0, 0.05, 0.06),
		load = nil,
		flaps = {},
		spinners = { "TS_Crescent" },
		gate = nil,
		tracks = {
			draw = "DrawTempest",
			reload = "ReloadTempestStinger",
			inspect = "InspectTempestStinger",
		},
		reloadSpin = false,
		fit = true,
	},
	-- Lever-action scoped rifle: receiver + scope 0.2-1.13, wood forend to 1.9, barrel over a tube
	-- magazine (0.077-0.24) to the crown at 3.2 (bore 0.205); rounds go in at the side gate.
	Marshal = {
		helix = {
			x0 = 2.0,
			x1 = 2.92,
			ry0 = 0.052,
			ry1 = 0.05,
			rz0 = 0.093,
			rz1 = 0.092,
			z0 = 0.16,
			z1 = 0.158,
		},
		arcs = { v(0.6, 0.078, 0.2), v(1.5, 0, 0.256), v(2.4, 0.05, 0.12) },
		glow = v(0.9, 0, 0.2),
		pulse = { x0 = 1.95, x1 = 3.18, z = 0.17 },
		bore = 0.205,
		drawRing = { x0 = 3.15, x1 = 1.2, r0 = 0.05, r1 = 0.15 },
		inspectRun = { x0 = 3.0, x1 = 1.2, r0 = 0.08, r1 = 0.17 },
		roll = { x = 1.0, z = 0.15, r = 0.36, rollIn = 0.44, catch = 0.59 },
		lock = v(0.9, 0, 0.17),
		sweep = {
			v(0.22, 0.24, 0.188),
			v(1.1, 0.24, 0.19),
			v(1.17, 0.162, 0.115),
			v(1.85, 0.16, 0.117),
			v(1.95, 0.115, 0.16),
			v(2.95, 0.112, 0.158),
			v(3.05, 0.075, 0.205),
			v(3.18, 0.076, 0.205),
		},
		sight = nil, -- scoped: the scope overlay is the sight picture
		well = nil,
		load = v(0.396, -0.055, 0.043),
		flaps = {},
		spinners = { "TS_ScopeRingRear", "TS_ScopeRingFront" },
		gate = "TS_Gate",
		tracks = {
			draw = "DrawTempest",
			inspect = "InspectTempestMarshal",
			reloadStart = "ReloadStartTempestMarshal",
			reloadInsert = "ReloadInsertTempestMarshal",
			reloadEnd = "ReloadEndTempest",
			cycle = "CycleTempestMarshal",
		},
		reloadSpin = false,
		fit = true,
	},
	-- Pump shotgun: receiver to 0.95, barrel over a tube magazine (0.164-0.42), pump 1.3-2.05,
	-- muzzle at 2.83 (bore 0.369); shells in at the loading port. No ADS.
	Bucky = {
		helix = {
			x0 = 2.12,
			x1 = 2.72,
			ry0 = 0.063,
			ry1 = 0.078,
			rz0 = 0.139,
			rz1 = 0.147,
			z0 = 0.291,
			z1 = 0.296,
		},
		arcs = { v(0.4, 0.093, 0.33), v(1.6, 0.095, 0.2), v(2.3, 0.062, 0.37) },
		glow = v(1.0, 0, 0.3),
		pulse = { x0 = 1.0, x1 = 2.83, z = 0.28 },
		bore = 0.369,
		drawRing = { x0 = 2.8, x1 = 1.0, r0 = 0.08, r1 = 0.17 },
		inspectRun = { x0 = 2.7, x1 = 0.9, r0 = 0.1, r1 = 0.19 },
		roll = { x = 1.0, z = 0.25, r = 0.36, rollIn = 0.44, catch = 0.59 },
		lock = v(1.0, 0, 0.29),
		sweep = {
			v(-0.17, 0.18, 0.24),
			v(0.5, 0.195, 0.26),
			v(0.68, 0.178, 0.275),
			v(1.0, 0.16, 0.29),
			v(1.25, 0.16, 0.29),
			v(1.3, 0.192, 0.257),
			v(2.05, 0.192, 0.257),
			v(2.12, 0.16, 0.291),
			v(2.72, 0.168, 0.296),
			v(2.78, 0.097, 0.369),
			v(2.84, 0.088, 0.369),
		},
		sight = nil, -- noAds: the crescent is cosmetic
		well = nil,
		load = v(0.747, 0, 0.114),
		flaps = { { name = "TS_PlateL", side = 1 }, { name = "TS_PlateR", side = -1 } },
		spinners = {},
		gate = nil,
		tracks = {
			draw = "DrawTempest",
			inspect = "InspectTempestBucky",
			reloadStart = "ReloadStartTempestBucky",
			reloadInsert = "ReloadInsertTempestBucky",
			reloadEnd = "ReloadEndTempest",
		},
		reloadSpin = false,
		fit = true,
	},
	-- Revolver (two-handed): frame and 12-sided cylinder 0.3-0.6, barrel with a top rib over an
	-- underlug to 1.2, bare barrel to the muzzle at 1.5 (bore 0.278), side plates.
	Sheriff = {
		helix = {
			x0 = 0.84,
			x1 = 1.18,
			ry0 = 0.063,
			ry1 = 0.063,
			rz0 = 0.13,
			rz1 = 0.13,
			z0 = 0.231,
			z1 = 0.231,
		},
		arcs = { v(0.45, 0.145, 0.21), v(1.0, 0, 0.36), v(1.0, 0.062, 0.15) },
		glow = v(0.6, 0, 0.25),
		pulse = { x0 = 0.8, x1 = 1.5, z = 0.25 },
		bore = 0.278,
		drawRing = { x0 = 1.48, x1 = 0.7, r0 = 0.06, r1 = 0.15 },
		inspectRun = { x0 = 1.4, x1 = 0.3, r0 = 0.08, r1 = 0.17 },
		-- the ring runs round the open cylinder (InspectTempestSheriff: out 0.56, flicked shut 0.86)
		roll = { x = 0.47, z = 0.21, r = 0.26, rollIn = 0.56, catch = 0.86 },
		lock = v(0.6, 0, 0.25),
		sweep = {
			v(0.14, 0.15, 0.17),
			v(0.24, 0.2, 0.215),
			v(0.6, 0.195, 0.21),
			v(0.78, 0.17, 0.245),
			v(0.84, 0.15, 0.231),
			v(1.17, 0.15, 0.231),
			v(1.26, 0.105, 0.27),
			v(1.5, 0.098, 0.279),
		},
		-- the Vandal's crescent at 0.78 scale, on the Sheriff's AimPoint
		sight = { x = 0.26, tipY = 0.032, tipZ = 0.465, apexZ = 0.484 },
		well = nil,
		load = v(0.3172, 0, 0.1898),
		flaps = { { name = "TS_SidePlateL", side = 1 }, { name = "TS_SidePlateR", side = -1 } },
		spinners = {},
		gate = nil,
		tracks = {
			draw = "DrawTempest",
			reload = "ReloadTempestSheriff",
			inspect = "InspectTempestSheriff",
		},
		reloadSpin = false,
		fit = true,
	},
}

return table.freeze(profiles)
