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
-- tracks: the Config/Viewmodel tracks to use (nil = the gun's stock track);
-- roll: inspect barrel-roll window (track progress); reloadSpin: the reload
--        track rolls the gun after the seat (Vandal's own reload only).
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
	pulse: { x0: number, x1: number, z: number, size0: number, size1: number },
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
	tracks: { draw: string?, reload: string?, inspect: string? },
	reloadSpin: boolean,
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
	},
	-- SMG: short shroud and brake ahead of a long receiver; mag under the receiver front.
	Stinger = {
		helix = {
			x0 = 0.42,
			x1 = 1.04,
			ry0 = 0.1,
			ry1 = 0.066,
			rz0 = 0.15,
			rz1 = 0.09,
			z0 = 0.29,
			z1 = 0.3,
		},
		arcs = { v(0.0, 0.09, 0.37), v(0.55, 0, 0.44), v(0.75, 0.09, 0.26) },
		glow = v(0.5, 0.05, 0.36),
		pulse = { x0 = 0.35, x1 = 1.12, z = 0.294, size0 = 0.32, size1 = 0.15 },
		bore = 0.29,
		drawRing = { x0 = 1.08, x1 = 0.3, r0 = 0.09, r1 = 0.16 },
		inspectRun = { x0 = 1.0, x1 = 0.2, r0 = 0.13, r1 = 0.19 },
		roll = { x = 0.35, z = 0.28, r = 0.3, rollIn = 0.44, catch = 0.59 },
		lock = v(0.4, 0, 0.3),
		sweep = {
			v(-0.5, 0.22, 0.27),
			v(0.3, 0.21, 0.27),
			v(0.31, 0.16, 0.29),
			v(0.9, 0.16, 0.29),
			v(0.91, 0.1, 0.29),
			v(1.1, 0.1, 0.29),
		},
		-- the crescent is the Vandal's at 0.84 scale (same pips), on the Stinger's AimPoint
		sight = { x = -0.408, tipY = 0.034, tipZ = 0.528, apexZ = 0.549 },
		well = Vector3.new(0, 0.05, 0.06),
		load = nil,
		flaps = VENTS,
		spinners = { "TS_Crescent" },
		gate = nil,
		tracks = { draw = "DrawTempest", reload = "ReloadTempestLite", inspect = "InspectTempest" },
		reloadSpin = false,
	},
	-- Lever-action scoped rifle: long thin barrel, scope over the receiver, rounds go in at the side gate.
	Marshal = {
		helix = {
			x0 = 1.95,
			x1 = 3.05,
			ry0 = 0.062,
			ry1 = 0.05,
			rz0 = 0.075,
			rz1 = 0.062,
			z0 = 0.2,
			z1 = 0.205,
		},
		arcs = { v(0.5, 0.07, 0.38), v(1.5, 0, 0.22), v(2.4, 0.05, 0.25) },
		glow = v(0.8, 0.05, 0.25),
		pulse = { x0 = 1.2, x1 = 3.15, z = 0.205, size0 = 0.28, size1 = 0.13 },
		bore = 0.2,
		drawRing = { x0 = 3.1, x1 = 1.2, r0 = 0.08, r1 = 0.14 },
		inspectRun = { x0 = 3.0, x1 = 1.0, r0 = 0.1, r1 = 0.2 },
		roll = { x = 1.0, z = 0.15, r = 0.36, rollIn = 0.44, catch = 0.59 },
		lock = v(0.9, 0, 0.2),
		sweep = {
			v(0.1, 0.27, 0.12),
			v(1.15, 0.27, 0.12),
			v(1.16, 0.15, 0.1),
			v(1.95, 0.15, 0.1),
			v(1.96, 0.1, 0.2),
			v(3.15, 0.1, 0.2),
		},
		sight = nil, -- scoped: the scope overlay is the sight picture
		well = nil,
		load = v(0.396, -0.055, 0.043),
		flaps = {},
		spinners = { "TS_ScopeRingRear", "TS_ScopeRingFront" },
		gate = "TS_Gate",
		tracks = { draw = "DrawTempest", reload = nil, inspect = "InspectTempest" },
		reloadSpin = false,
	},
	-- Pump shotgun: wrapped pump on the barrel, shells in at the loading port. No ADS.
	Bucky = {
		helix = {
			x0 = 2.15,
			x1 = 2.75,
			ry0 = 0.08,
			ry1 = 0.07,
			rz0 = 0.09,
			rz1 = 0.08,
			z0 = 0.37,
			z1 = 0.37,
		},
		arcs = { v(0.4, 0.09, 0.42), v(1.0, 0, 0.44), v(2.4, 0.06, 0.43) },
		glow = v(1.0, 0.05, 0.36),
		pulse = { x0 = 1.0, x1 = 2.8, z = 0.37, size0 = 0.34, size1 = 0.18 },
		bore = 0.33,
		drawRing = { x0 = 2.75, x1 = 1.0, r0 = 0.11, r1 = 0.2 },
		inspectRun = { x0 = 2.7, x1 = 0.9, r0 = 0.13, r1 = 0.22 },
		roll = { x = 1.0, z = 0.25, r = 0.36, rollIn = 0.44, catch = 0.59 },
		lock = v(1.0, 0, 0.3),
		sweep = {
			v(-0.05, 0.23, 0.2),
			v(1.15, 0.23, 0.2),
			v(1.16, 0.2, 0.22),
			v(2.1, 0.2, 0.22),
			v(2.11, 0.11, 0.37),
			v(2.8, 0.11, 0.37),
		},
		sight = nil, -- noAds: the crescent is cosmetic
		well = nil,
		load = v(0.747, 0, 0.114),
		flaps = { { name = "TS_PlateL", side = 1 }, { name = "TS_PlateR", side = -1 } },
		spinners = {},
		gate = nil,
		tracks = { draw = "DrawTempest", reload = nil, inspect = "InspectTempest" },
		reloadSpin = false,
	},
	-- Revolver (two-handed): fluted barrel with a top rib, 12-sided cylinder, side plates.
	-- Keeps its own twirl inspect (InspectSheriff: two turns at 0.44-0.64).
	Sheriff = {
		helix = {
			x0 = 0.84,
			x1 = 1.42,
			ry0 = 0.075,
			ry1 = 0.062,
			rz0 = 0.11,
			rz1 = 0.09,
			z0 = 0.285,
			z1 = 0.28,
		},
		arcs = { v(0.2, 0.07, 0.37), v(1.1, 0, 0.44), v(0.63, 0.12, 0.2) },
		glow = v(0.6, 0.05, 0.3),
		pulse = { x0 = 0.8, x1 = 1.48, z = 0.278, size0 = 0.26, size1 = 0.14 },
		bore = 0.27,
		drawRing = { x0 = 1.45, x1 = 0.7, r0 = 0.09, r1 = 0.15 },
		inspectRun = { x0 = 1.4, x1 = 0.3, r0 = 0.11, r1 = 0.18 },
		roll = { x = 0.6, z = 0.22, r = 0.28, rollIn = 0.44, catch = 0.64 },
		lock = v(0.6, 0, 0.25),
		sweep = {
			v(-0.05, 0.22, 0.12),
			v(0.8, 0.22, 0.12),
			v(0.81, 0.13, 0.28),
			v(1.48, 0.12, 0.28),
		},
		-- the Vandal's crescent at 0.78 scale, on the Sheriff's AimPoint
		sight = { x = 0.26, tipY = 0.032, tipZ = 0.465, apexZ = 0.484 },
		well = nil,
		load = v(0.3172, 0, 0.1898),
		flaps = { { name = "TS_SidePlateL", side = 1 }, { name = "TS_SidePlateR", side = -1 } },
		spinners = {},
		gate = nil,
		tracks = { draw = "DrawTempest", reload = nil, inspect = nil },
		reloadSpin = false,
	},
}

return table.freeze(profiles)
