"""Sunwell Works hub upgrade (2026-11-12, vault/02 Art/Sunwell Hub Upgrade.md): the Sun Well at the middle of the hall,
the two hall boards over the bench bays, and the pipe racks that run along both haunches on the crossbeams.

Faceted to the owner's hard rules (gauntlet-build-style §0): octagons instead of circles, 8-sided pipes with a flat on top,
chamfered ends, a transition at every joint.
"""
from math import cos, sin, pi, radians
from mathutils import Matrix, Vector

import lv3_core as C
import sw_core as S
import sw_doors as DR

AREA = "Hub"
WS = 1.15  # Well scale (pass A2: larger, still clear of the walk lines)
WY = 53.0  # Sun Well centre (between the bench bays, under the second skylight)
DECK = 1.3  # grate deck height (players stand here)
DATUM = 25.0  # top of the crossbeams: the pipes sit on this level everywhere (beams, trapeze hangers)
PIPES = ((28.6, 0.8, "Petrol"), (26.6, 0.45, "PipeOchre"))  # (x from the centre line, radius, material)


def oct_pts(a, cx=0.0, cy=0.0):
	"""Regular octagon with apothem a, flats facing the axes."""
	R = a / cos(pi / 8)
	return [(cx + R * cos(pi / 8 + k * pi / 4), cy + R * sin(pi / 8 + k * pi / 4)) for k in range(8)]


def star_pts(r_out, r_in, n=8, rot=0.0):
	pts = []
	for k in range(2 * n):
		r = r_out if k % 2 == 0 else r_in
		a = rot + k * pi / n
		pts.append((r * cos(a), r * sin(a)))
	return pts


def pipe6(b, p0, p1, r):
	"""6-sided pipe with a flat on top (loose props: the facets read from across the hall)."""
	p0, p1 = Vector(p0), Vector(p1)
	d = (p1 - p0).normalized()
	up = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
	u = d.cross(up).normalized()
	v = d.cross(u)
	R = r / cos(pi / 6)
	a = [p0 + u * (R * cos(k * pi / 3)) + v * (R * sin(k * pi / 3)) for k in range(6)]
	return b.solid(a, [p + (p1 - p0) for p in a])


def pipe8(b, p0, p1, r):
	"""8-sided pipe with a flat on top and underneath (sits flat on a saddle)."""
	p0, p1 = Vector(p0), Vector(p1)
	d = (p1 - p0).normalized()
	up = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
	u = d.cross(up).normalized()
	v = d.cross(u)
	R = r / cos(pi / 8)
	a = [p0 + u * (R * cos(pi / 8 + k * pi / 4)) + v * (R * sin(pi / 8 + k * pi / 4)) for k in range(8)]
	return b.solid(a, [p + (p1 - p0) for p in a])


# ---------------------------------------------------------------- the Sun Well
def sun_well(K):
	"""A stepped octagonal well you can stand on: dark shoe, cast kerb with a gunmetal coping to sit on, a warm light
	channel under the coping lip, a radial grate over a glowing floor, a hub plate with the ochre Sunwell star."""
	with S.grp("SunWell", Matrix.Translation((0, WY, 0))):
		W = S.FK(K, Matrix.Translation((0, WY, 0)))
		o = lambda a: oct_pts(a * WS)
		W["WallBase"].solid([(x, y, 0.0) for x, y in o(6.55)], [(x, y, 0.4) for x, y in o(6.35)])  # battered shoe = the well base
		S.ring_prism(W["CastTrim"], o(6.2), o(4.95), 0.4, 1.3)  # kerb
		S.ring_prism(W["Petrol"], o(6.32), o(4.85), 1.3, 1.5)  # coping (the seat), 0.12 over the kerb face
		S.bolts(W["Steel"], [(5.6 * WS * cos(k * pi / 4), 5.6 * WS * sin(k * pi / 4)) for k in range(8)], r=0.13, z0=1.5, h=0.06)
		S.ring_prism(W["Graphite"], o(4.95), o(4.35), 0.4, 0.9)  # liner ledge inside the kerb
		S.ring_prism(W["E_Sun"], o(4.95), o(4.55), 0.9, 0.96)  # light channel under the coping lip
		W["E_Sun"].prism(o(4.35), 0.4, 0.46)  # the glowing floor of the well
		S.ring_prism(W["Graphite"], o(4.55), o(4.2), 0.9, DECK)  # grate frame on the liner
		# hub pedestal and plate
		W["Graphite"].prism(o(1.15), 0.46, 1.0)
		W["Petrol"].prism(o(1.75), 1.0, DECK + 0.05)
		W["Stripe"].prism(star_pts(1.35 * WS, 0.62 * WS, 8, pi / 8), DECK + 0.05, DECK + 0.1)  # the Sunwell star, ochre like the walk lines
		W["Charcoal"].prism(o(0.42), DECK + 0.1, DECK + 0.14)
		# 16 radial ribs from the hub to the frame, a middle ring across them
		for k in range(16):
			a = k * pi / 8
			Rm = W.at(Matrix.Rotation(a, 4, "Z"))
			Rm["Graphite"].prism([(1.7 * WS, -0.17), (4.25 * WS, -0.17), (4.25 * WS, 0.17), (1.7 * WS, 0.17)], 1.02, DECK)
		S.ring_prism(W["Graphite"], o(3.05), o(2.8), 1.02, DECK + 0.03)
		# colliders: deck you can stand on (two crossed squares = the octagon), invisible so the glow shows through the grate
		for rot in (0.0, pi / 4):
			S.collider(AREA, Matrix.Translation((0, WY, 0)) @ Matrix.Rotation(rot, 4, "Z"), -6.25 * WS, 6.25 * WS, -6.25 * WS, 6.25 * WS, 0.0, DECK + 0.1, kind="Y")
		S.light(Matrix.Translation((0, WY, 0)), 0, 0, 2.4, "#FFC98A", 1.1, 18)
		S.light(Matrix.Translation((0, WY, 0)), 0, 0, 0.7, "#FFB866", 0.8, 9)
		# a flush inlay ring on the floor round the well (dark, 0.04 proud)
		S.ring_prism(W["Graphite"], o(7.75), o(7.45), 0.0, 0.04)
		S.ring_prism(W["Floor"], o(7.45), o(6.56), 0.0, 0.025)  # dark apron round the foot: the Well sits on its own ground


def sun_ring(K):
	"""The Sun Well's lamp: an octagonal ring luminaire hung over the well from two spreader bars under the crossbeams
	either side (y 46.6 and 59.4). Gunmetal ring, a downlight strip under it, eight fins, a warm white light. It sits
	above the sightline from the spawn to the top of the turbine, so it frames the landmark instead of hiding it."""
	with S.grp("SunRing", Matrix.Translation((0, WY, 0))):
		z0, z1 = 19.35, 20.45
		R = S.FK(K, Matrix.Translation((0, WY, 0)))
		S.ring_prism(R["Petrol"], oct_pts(6.0), oct_pts(5.2), z0 + 0.12, z1)  # ring body
		S.ring_prism(R["PetrolDark"], oct_pts(6.1), oct_pts(5.1), z1 - 0.18, z1 + 0.04)  # top lip, 0.1 over the body
		S.ring_prism(R["PetrolDark"], oct_pts(5.95), oct_pts(5.25), z0, z0 + 0.12)  # bottom frame round the strip
		S.ring_prism(R["E_Sun"], oct_pts(5.82), oct_pts(5.38), z0 - 0.02, z0 + 0.04)  # downlight strip, set in the frame
		for k in range(8):  # fins on the outer facets
			F = R.at(Matrix.Rotation(k * pi / 4, 4, "Z"))
			F["PetrolDark"].prism([(6.0, -0.09), (6.45, -0.09), (6.45, 0.09), (6.0, 0.09)], z0 + 0.3, z1 - 0.18)
		for sx in (-1, 1):  # spreader bars under the beams, and the hanger rods
			R["PetrolDark"].box(sx * 3.5 - 0.22, sx * 3.5 + 0.22, -7.5, 7.5, 21.7, 22.4)
			for sy in (-1, 1):
				R["Steel"].box(sx * 3.5 - 0.3, sx * 3.5 + 0.3, sy * 6.4 - 1.18, sy * 6.4 + 1.18, 22.3, 22.9)  # clamp wrapping the beam's bottom flange
				R["SteelDark"].box(sx * 3.5 - 0.1, sx * 3.5 + 0.1, sy * 4.4 - 0.1, sy * 4.4 + 0.1, z1, 21.7)  # rod
				R["Steel"].box(sx * 3.5 - 0.2, sx * 3.5 + 0.2, sy * 4.4 - 0.2, sy * 4.4 + 0.2, z1, z1 + 0.14)  # rod foot
		S.light(Matrix.Translation((0, WY, 0)), 0, 0, 18.4, "#FFE9CC", 1.7, 24, angle=90)


# ---------------------------------------------------------------- boards over the bench bays
def boards(K):
	"""Two big wall displays (SurfaceGui in Studio) facing the Sun Well: the weekly leaderboard on the Duels side and the
	season board on the Shop side. The quiet display case from the fixture kit."""
	DR.display(S.FK(K, S.wall_face(-1, WY)), 0.0, 12.35, 8.7, 5.7, "leader", "TOP DUELISTS", "THIS WEEK")
	DR.display(S.FK(K, S.wall_face(1, WY)), 0.0, 12.35, 8.7, 5.7, "season", "SEASON 1", "THE GAUNTLET OPENS")


# ---------------------------------------------------------------- pipe racks on the haunches
def _strap(b, x, y, z, r):
	"""A band round a pipe: an 8-sided collar 0.24 long and 0.07 proud."""
	pipe8(b, (x, y - 0.12, z), (x, y + 0.12, z), r + 0.07)


def _flange(b, x, y, z, r):
	pipe8(b, (x, y - 0.16, z), (x, y + 0.16, z), r + 0.2)


def pipes(K):
	spans = [0.0] + list(S.BEAMS) + [S.LEN]
	trapeze = []  # y of the hangers between beams
	for a, bb in zip(spans, spans[1:]):
		if bb - a > 10:
			y = (a + bb) / 2
			if S.PROS[0] - 2 < y < S.PROS[1] + 2:  # keep the hanger off the SUNWELL frame
				y = S.PROS[0] - 6.5
			trapeze.append(y)
	for sx in (-1, 1):
		with S.grp(f"PipeRack_{'W' if sx < 0 else 'E'}", reuse=True):
			for x, r, mat in PIPES:
				xs = sx * x
				z = DATUM + 0.15 + r
				b = K[mat]
				pipe8(b, (xs, 0.0, z), (xs, S.LEN, z), r)  # runs wall to wall, into the entry and turbine walls
				for y in (0.0, S.LEN):  # wall flange plates where it enters the end walls
					yy = 0.16 if y == 0 else S.LEN - 0.16
					_flange(K["PetrolDark"], xs, yy, z, r)
				for y in (S.PROS[0] - 0.16, S.PROS[1] + 0.16):  # collars where it passes through the SUNWELL frame
					_flange(K["PetrolDark"], xs, y, z, r)
				for y in (31.0, 72.0, 102.0):  # joint flanges along the run
					_flange(K["PetrolDark"], xs, y, z, r)
				for y in list(S.BEAMS) + trapeze:
					K["Steel"].box(xs - r * 0.75, xs + r * 0.75, y - 0.22, y + 0.22, DATUM, DATUM + 0.15)  # saddle
					_strap(K["SteelDark"], xs, y, z, r)
			# trapeze hangers between beams: an angle bar under both pipes on two rods (one to the ceiling, one to the haunch)
			for y in trapeze:
				x0, x1 = sorted((sx * 25.5, sx * 30.0))
				K["PetrolDark"].box(x0, x1, y - 0.2, y + 0.2, DATUM - 0.22, DATUM)
				hz = lambda ax: S.ZW + (S.HX - ax)  # haunch height at |x| = ax
				for xr in (25.75, 29.75):
					xx = sx * xr
					if xr < 28:  # to the flat ceiling: a square fixing plate
						top = S.ZC - 0.12
						K["PetrolDark"].box(xx - 0.3, xx + 0.3, y - 0.3, y + 0.3, top, S.ZC + 0.02)
					else:  # to the haunch: a wedge bracket whose top follows the slope and whose underside is level
						a, b = xr - 0.3, xr + 0.3
						top = hz(b) - 0.25
						prof = [(a, top), (b, top), (b, hz(b) + 0.05), (a, hz(a) + 0.05)]
						K["PetrolDark"].ext_y([(sx * px, pz) for px, pz in prof] if sx > 0 else [(sx * px, pz) for px, pz in prof][::-1], y - 0.3, y + 0.3)
					K["SteelDark"].box(xx - 0.1, xx + 0.1, y - 0.1, y + 0.1, DATUM, top)
					K["Steel"].box(xx - 0.16, xx + 0.16, y - 0.16, y + 0.16, DATUM - 0.32, DATUM - 0.22)  # nut under the bar
	# a valve on each big pipe near the turbine: a faceted hand wheel on a stem, facing down into the hall
	for sx in (-1, 1):
		with S.grp(f"PipeRack_{'W' if sx < 0 else 'E'}", reuse=True), S.grp("Valve"):
			x, r, _ = PIPES[0]
			xs, z = sx * x, DATUM + 0.15 + r
			y = 106.5
			pipe8(K["PetrolDark"], (xs, y - 0.65, z), (xs, y + 0.65, z), 0.98)  # valve body: an 8-sided collar round the pipe
			K["SteelDark"].box(xs - 0.14, xs + 0.14, y - 0.14, y + 0.14, z - 1.75, z - 0.95)  # stem
			if sx < 0:  # this one's wheel is off for servicing: it lies by the maintenance cart below
				K["SteelDark"].prism([(xs - 0.22, y - 0.22), (xs + 0.22, y - 0.22), (xs + 0.22, y + 0.22), (xs - 0.22, y + 0.22)], z - 1.9, z - 1.75)
				continue
			V = S.FK(K, Matrix.Translation((xs, y, z - 1.75)))
			S.ring_prism(V["PipeOchre"], oct_pts(0.95), oct_pts(0.72), -0.14, 0.0)  # hand wheel (octagon)
			for k in range(4):
				V.at(Matrix.Rotation(k * pi / 4, 4, "Z"))["PipeOchre"].box(-0.75, 0.75, -0.07, 0.07, -0.12, -0.02)


# ---------------------------------------------------------------- story groups (odd counts, at the walls, never in the walk)
def _at(x, y, yaw=0.0, sc=1.0):
	return Matrix.Translation((x, y, 0)) @ Matrix.Rotation(radians(yaw), 4, "Z") @ Matrix.Scale(sc, 4)


def _col(M, x0, x1, y0, y1, z0, z1):
	"""Invisible collider in a (possibly scaled) prop frame: the collider builder ignores scale, so apply it here."""
	loc, rot, sc = M.decompose()
	k = sc.x
	S.collider(AREA, Matrix.Translation(loc) @ rot.to_matrix().to_4x4(), x0 * k, x1 * k, y0 * k, y1 * k, z0 * k, z1 * k, kind="Y")


def _cbox(b, x0, x1, y0, y1, z0, z1, c):
	"""A box with chamfered vertical edges (plan outline cut at the four corners)."""
	b.prism(S.cham_rect(x0, x1, y0, y1, c), z0, z1)


def _wheel(b, x, y, r, w, axis="x"):
	"""A castor wheel: an 8-sided tyre on its axle (axis along x)."""
	pipe8(b, (x - w / 2, y, r), (x + w / 2, y, r), r)


def maintenance(K, M):
	"""Turbine maintenance: a service cart carrying a spare pipe spool, a tool case and the hand wheel taken off a valve.
	(What happened here: someone is halfway through servicing the intake valves.)"""
	with S.grp("Cart", M):
		F = S.FK(K, M)
		# cart: tray with a raised lip, lower shelf, four square legs, castors, a push handle at one end
		_cbox(F["Petrol"], -1.7, 1.7, -0.95, 0.95, 2.0, 2.22, 0.18)
		S.ring_prism(F["PetrolDark"], S.cham_rect(-1.7, 1.7, -0.95, 0.95, 0.18), S.cham_rect(-1.5, 1.5, -0.75, 0.75, 0.1), 2.22, 2.42)
		_cbox(F["Petrol"], -1.55, 1.55, -0.8, 0.8, 0.72, 0.9, 0.12)
		for sx in (-1, 1):
			for sy in (-1, 1):
				F["SteelDark"].box(sx * 1.45 - 0.12, sx * 1.45 + 0.12, sy * 0.7 - 0.12, sy * 0.7 + 0.12, 0.62, 2.0)
				F["PetrolDark"].box(sx * 1.45 - 0.2, sx * 1.45 + 0.2, sy * 0.7 - 0.2, sy * 0.7 + 0.2, 0.5, 0.62)  # castor fork plate
				_wheel(F["Rubber"], sx * 1.45, sy * 0.7, 0.25, 0.22)
		for sy in (-1, 1):  # handle uprights and grip
			F["SteelDark"].box(1.62, 1.86, sy * 0.62 - 0.11, sy * 0.62 + 0.11, 2.2, 3.55)
		F["Rubber"].box(1.58, 1.9, -0.75, 0.75, 3.45, 3.7)
		# spare pipe spool on two chocks, flanged at both ends
		for x in (-0.9, 0.9):  # V chocks standing on the tray
			F.at(Matrix.Translation((x, 0, 0)))["Graphite"].ext_x([(-0.6, 2.22), (0.6, 2.22), (0.6, 3.0), (0.25, 3.0), (0.0, 2.76), (-0.25, 3.0), (-0.6, 3.0)], -0.15, 0.15)
		pipe6(F["PipeOchre"], (-1.35, 0, 3.15), (1.35, 0, 3.15), 0.42)
		for x in (-1.35, 1.35):
			pipe8(F["PetrolDark"], (x - 0.12 if x > 0 else x, 0, 3.15), (x if x > 0 else x + 0.12, 0, 3.15), 0.62)
		# tool case on the lower shelf
		_cbox(F["CaseShell"], -1.25, -0.05, -0.55, 0.45, 0.9, 1.45, 0.1)
		F["Steel"].box(-0.85, -0.45, -0.6, -0.55, 1.15, 1.32)  # latch
		F["Charcoal"].box(-0.95, -0.35, -0.08, 0.08, 1.45, 1.62)  # handle
		# the valve's hand wheel leaning on the cart's side
		W = F.at(Matrix.Translation((0.5, -2.05, 0.0)) @ Matrix.Rotation(radians(17), 4, "Z"))  # lying on the floor by the cart
		S.ring_prism(W["PipeOchre"], oct_pts(0.95), oct_pts(0.72), 0.0, 0.14)
		for k in range(4):
			W.at(Matrix.Rotation(k * pi / 4, 4, "Z"))["PipeOchre"].box(-0.75, 0.75, -0.07, 0.07, 0.02, 0.12)
		W["SteelDark"].prism(oct_pts(0.2), 0.0, 0.2)
		_col(M, -1.9, 1.95, -1.0, 1.0, 0.0, 3.6)
		_col(M, -0.55, 1.55, -3.1, -1.0, 0.0, 0.25)


def crate(F, x0, x1, y0, y1, z0, z1, mat="Olive"):
	"""An olive supply crate: chamfered body, upright battens near each corner, foot and lid bands, a stencil block on the front."""
	c = 0.16
	_cbox(F[mat], x0, x1, y0, y1, z0, z1, c)
	t = 0.08
	for xx in (x0 + 0.22, x1 - 0.5):  # battens on the front and back faces
		F["Graphite"].box(xx, xx + 0.28, y0 - t, y0, z0 + 0.2, z1 - 0.2)
		F["Graphite"].box(xx, xx + 0.28, y1, y1 + t, z0 + 0.2, z1 - 0.2)
	for yy in (y0 + 0.22, y1 - 0.5):  # and on the sides
		F["Graphite"].box(x0 - t, x0, yy, yy + 0.28, z0 + 0.2, z1 - 0.2)
		F["Graphite"].box(x1, x1 + t, yy, yy + 0.28, z0 + 0.2, z1 - 0.2)
	for zz in (z0, z1 - 0.22):  # bands round the foot and the lid
		S.ring_prism(F["Graphite"], S.cham_rect(x0 - 0.05, x1 + 0.05, y0 - 0.05, y1 + 0.05, c), S.cham_rect(x0 + 0.02, x1 - 0.02, y0 + 0.02, y1 - 0.02, c), zz, zz + 0.22)
	w = min(1.2, (x1 - x0) * 0.4)
	F["P_Cream"].box((x0 + x1) / 2 - w / 2, (x0 + x1) / 2 + w / 2, y0 - 0.03, y0, (z0 + z1) / 2 - 0.12, (z0 + z1) / 2 + 0.12)  # stencil bar


def deliveries(K, M):
	"""Supplies left at the arrival: a pallet with a big crate, a smaller crate set on top a few degrees off square, and
	a small one on the floor beside it."""
	with S.grp("Crates", M):
		F = S.FK(K, M)
		for y in (-1.35, 0.0, 1.35):  # pallet deck boards on three runners
			F["Timber"].box(-1.65, 1.65, y - 0.42, y + 0.42, 0.32, 0.46)
		for x in (-1.4, 0.0, 1.4):
			F["Timber"].box(x - 0.22, x + 0.22, -1.75, 1.75, 0.0, 0.32)
		crate(F, -1.5, 1.5, -1.6, 1.6, 0.46, 2.6)
		crate(F.at(Matrix.Translation((0.1, 0.15, 0)) @ Matrix.Rotation(radians(4), 4, "Z")), -1.0, 1.0, -0.95, 0.95, 2.6, 3.95)
		crate(F.at(Matrix.Translation((2.6, -0.6, 0)) @ Matrix.Rotation(radians(-7), 4, "Z")), -0.65, 0.65, -0.6, 0.6, 0.0, 1.2)
		_col(M, -1.7, 1.7, -1.8, 1.8, 0.0, 2.6)
		_col(M, -0.95, 1.15, -0.85, 1.15, 2.6, 3.95)
		_col(M, 1.9, 3.3, -1.3, 0.1, 0.0, 1.2)


def cable_works(K, M):
	"""Cable work by the entry: a cable drum on two cradle stands and a striped A-frame barrier in front of it."""
	with S.grp("CableDrum", M):
		F = S.FK(K, M)
		Rr = 1.55
		for sx in (-1, 1):  # drum flanges (octagons) and the cradle stands
			x = sx * 0.85
			pipe8(F["Petrol"], (x - 0.09, 0, Rr + 0.2), (x + 0.09, 0, Rr + 0.2), Rr)
			F["SteelDark"].ext_x([(-0.9, 0.0), (0.9, 0.0), (0.18, Rr + 0.05), (-0.18, Rr + 0.05)], x + sx * 0.12, x + sx * 0.32)
			F["PetrolDark"].box(*sorted((x + sx * 0.05, x + sx * 0.4)), -1.0, 1.0, 0.0, 0.12)  # stand foot plate
		pipe8(F["Charcoal"], (-0.76, 0, Rr + 0.2), (0.76, 0, Rr + 0.2), 1.12)  # wound cable
		pipe8(F["SteelDark"], (-1.3, 0, Rr + 0.2), (1.3, 0, Rr + 0.2), 0.16)  # axle
		F["Charcoal"].box(-0.12, 0.12, -1.1, -0.98, 0.0, 1.45)  # the cable end running down to the floor
		F["Charcoal"].box(-0.12, 0.12, -2.4, -0.98, 0.0, 0.12)
		# A-frame barrier: two splayed leg frames and a striped board
		B = F.at(Matrix.Translation((0.0, -2.9, 0)))
		for sy in (-1, 1):
			B["SteelDark"].ext_x([(sy * 0.55, 0.0), (sy * 0.55 + sy * -0.12, 0.0), (sy * 0.04, 1.6), (sy * 0.16, 1.6)], -1.3, -1.12)
			B["SteelDark"].ext_x([(sy * 0.55, 0.0), (sy * 0.55 + sy * -0.12, 0.0), (sy * 0.04, 1.6), (sy * 0.16, 1.6)], 1.12, 1.3)
		B["SteelDark"].box(-1.3, 1.3, -0.1, 0.1, 1.55, 1.72)  # top bar
		for k in range(7):  # board stripes, charcoal and ochre
			x0 = -1.12 + k * 2.24 / 7
			B["Stripe" if k % 2 == 0 else "Charcoal"].box(x0, x0 + 2.24 / 7, -0.32, -0.2, 1.0, 1.45)
		_col(M, -1.4, 1.4, -1.4, 1.4, 0.0, 3.4)
		_col(M, -1.35, 1.35, -3.55, -2.25, 0.0, 1.75)


def pipe_stock(K, M):
	"""Spare pipe lengths on a two-stand rack by the turbine, two loose flanges leaning on the rack's foot, a tool box."""
	with S.grp("PipeStock", M):
		F = S.FK(K, M)
		for x in (-2.2, 2.2):  # stands: a splayed frame with two cradle arms
			F["SteelDark"].ext_x([(-1.1, 0.0), (1.1, 0.0), (0.25, 2.9), (-0.25, 2.9)], x - 0.14, x + 0.14)
			F["PetrolDark"].box(x - 0.3, x + 0.3, -1.25, 1.25, 0.0, 0.14)  # foot plate
			for z in (1.2, 2.3):
				F["PetrolDark"].box(x - 0.16, x + 0.16, -0.95, 0.95, z - 0.12, z)  # cradle arm
		pipe6(F["Petrol"], (-3.2, 0.45, 1.2 + 0.55), (3.2, 0.45, 1.2 + 0.55), 0.55)
		pipe6(F["PipeOchre"], (-3.0, -0.5, 1.2 + 0.42), (3.0, -0.5, 1.2 + 0.42), 0.42)
		pipe6(F["Petrol"], (-3.1, 0.0, 2.3 + 0.48), (3.1, 0.0, 2.3 + 0.48), 0.48)
		for k, yaw in enumerate((0, 11)):  # two loose flanges stacked flat on the floor in front of the rack
			W = F.at(Matrix.Translation((0.2, -2.0, 0.2 * k)) @ Matrix.Rotation(radians(yaw), 4, "Z"))
			S.ring_prism(W["PetrolDark"], oct_pts(0.78), oct_pts(0.42), 0.0, 0.2)
		_cbox(F["CaseShell"], 3.0, 4.3, -1.6, -0.75, 0.0, 0.65, 0.1)
		F["Steel"].box(3.45, 3.85, -1.65, -1.6, 0.3, 0.48)
		_col(M, -3.3, 3.3, -1.3, 1.3, 0.0, 3.3)
		_col(M, -0.65, 1.05, -2.85, -1.15, 0.0, 0.4)
		_col(M, 2.95, 4.35, -1.65, -0.7, 0.0, 0.65)


def hatch(K, x, y, yaw=0.0, w=2.6):
	"""A flush steel floor hatch (service access): chamfered frame, a recessed plate with two lift slots and four bolts."""
	M = Matrix.Translation((x, y, 0)) @ Matrix.Rotation(radians(yaw), 4, "Z")
	with S.grp("FloorHatch", M, inst=True):
		F = S.FK(K, M)
		h = w / 2
		S.ring_prism(F["PetrolDark"], S.cham_rect(-h, h, -h, h, 0.35), S.cham_rect(-h + 0.22, h - 0.22, -h + 0.22, h - 0.22, 0.25), 0.0, 0.05)
		F["Petrol"].prism(S.cham_rect(-h + 0.24, h - 0.24, -h + 0.24, h - 0.24, 0.24), 0.0, 0.035)
		for u in (-0.45, 0.45):
			F["Dark"].box(u - 0.28, u + 0.28, -0.07, 0.07, 0.035, 0.045)
		S.bolts(F["Steel"], [(sx * (h - 0.11), sy * (h - 0.11)) for sx in (-1, 1) for sy in (-1, 1)], r=0.07, z0=0.05, h=0.03)


def drain(K, side, y0, y1):
	"""A slotted drain channel along the foot of a side wall, in front of the battered base."""
	x = side * 32.6
	with S.grp("Drain", Matrix.Translation((x, (y0 + y1) / 2, 0)), inst=True):
		K["PetrolDark"].box(x - 0.35, x + 0.35, y0, y1, 0.0, 0.04)
		n = int((y1 - y0) / 0.7)
		for k in range(n):
			yy = y0 + 0.25 + k * 0.7
			K["Dark"].box(x - 0.2, x + 0.2, yy, yy + 0.3, 0.04, 0.05)


def floor_joints(K):
	"""The walk as laid slabs: joints across where its slabs meet and one down the middle (dark, 0.03 proud), clear of
	the Well's inlay; a steel threshold plate with tread ribs and a hazard edge where the ramp lands."""
	with S.grp("WalkMarks", reuse=True):
		for k in range(1, 7):
			y = 20 + 81 * k / 7
			if abs(y - WY) < 10.5:
				continue
			K["Graphite"].box(-10.9, 10.9, y - 0.06, y + 0.06, 0.0, 0.03)
		for ya, yb in ((23.4, WY - 10.5), (WY + 10.5, 101.0)):
			K["Graphite"].box(-0.06, 0.06, ya, yb, 0.0, 0.03)
		# threshold plate at the foot of the ramp (y 20 to 23.4)
		K["PetrolDark"].prism(S.cham_rect(-10.9, 10.9, 20.0, 23.4, 0.3), 0.0, 0.06)
		x = -10.3
		while x < 10.2:
			K["Graphite"].box(x, x + 0.16, 20.4, 22.5, 0.06, 0.1)  # tread ribs
			x += 0.62
		k = 0
		x = -10.6
		while x < 10.4:  # hazard edge: slanted ochre and charcoal blocks
			w = 0.9
			K["Stripe" if k % 2 == 0 else "Charcoal"].prism([(x, 22.7), (x + w, 22.7), (x + w + 0.45, 23.25), (x + 0.45, 23.25)], 0.06, 0.09)
			x += w
			k += 1


WING_PAINT = {"Duels": "P_Orange", "Locker": "P_Blue", "Range": "P_Mint", "Shop": "Stripe"}


def route_cues(K):
	"""Each doorway gets its route across the side field: three flush chevrons in the wing's colour (floor cues are where
	the wing colours belong), pointing from the walk's edge to the sill. Floor panel joints frame each approach band."""
	for wing, (side, yc) in S.DOORS.items():
		with S.grp(f"RouteMarks_{wing}"):
			paint = WING_PAINT[wing]
			for k, x in enumerate((16.0, 21.0, 26.0)):
				xs = side * x
				d = side  # points toward the wall
				pts = [(xs - d * 0.9, yc - 2.1), (xs + d * 0.3, yc), (xs - d * 0.9, yc + 2.1), (xs - d * 0.05, yc + 2.1), (xs + d * 1.15, yc), (xs - d * 0.05, yc - 2.1)]
				K[paint].prism(pts if side > 0 else pts[::-1], 0.0, 0.04)
	with S.grp("FieldJoints"):
		for sx in (-1, 1):  # joints at the edges of each approach band and across the side fields
			for y in (24.0, 44.0, 62.0, 82.0):
				x0, x1 = sorted((sx * 12.1, sx * 32.9))
				K["Graphite"].box(x0, x1, y - 0.06, y + 0.06, 0.0, 0.03)
			for y0, y1 in ((1.2, 24.0), (82.0, 110.8)):  # one joint down the middle of each end field
				x0, x1 = sorted((sx * 22.94, sx * 23.06))
				K["Graphite"].box(x0, x1, y0, y1, 0.0, 0.03)


def walk_motif(K):
	"""The walk as a framed lane: a dark border band inside each ochre line, and dark chevrons inlaid in the walk that lead
	from the threshold to the Well and from the Well to the turbine (the ramp's chevrons carried through the hall)."""
	with S.grp("WalkMarks", reuse=True):
		for sx in (-1, 1):
			for ya, yb in ((23.4, WY - 9.4), (WY + 9.4, 101.0)):
				x0, x1 = sorted((sx * 9.6, sx * 10.2))
				K["Graphite"].box(x0, x1, ya, yb, 0.0, 0.03)
		for y in (28.0, 33.5, 39.0, 67.0, 72.5, 78.0):  # chevrons pointing down the hall (+y)
			pts = [(-3.2, y), (0.0, y + 1.9), (3.2, y), (3.2, y + 0.9), (0.0, y + 2.8), (-3.2, y + 0.9)]
			K["Floor"].prism(pts, 0.0, 0.035)  # quiet: one value under the walk, not black


def wall_conduit(K):
	"""Service conduit along the side walls of the entry and turbine bays: two runs on stand-off clips at mid height, a
	junction box at each end, so the long plain bays read as a working station."""
	for side in (-1, 1):
		for y0, y1 in ((1.0, 13.2), (99.0, 111.0)):  # the entry run stops at the SUNWELL frame
			with S.grp("Conduit", S.wall_face(side, (y0 + y1) / 2)):
				F = S.FK(K, S.wall_face(side, (y0 + y1) / 2))
				L = (y1 - y0) / 2
				for zz, r in ((11.5, 0.22), (12.15, 0.16)):
					pipe8(F["SteelDark"], (-L + 1.0, zz, 0.42), (L - 1.0, zz, 0.42), r)
				u = -L + 2.0
				while u < L - 1.5:
					F["PetrolDark"].box(u - 0.14, u + 0.14, 11.15, 12.45, 0.0, 0.44)  # stand-off clip
					u += 2.6
				for u in (-L + 0.6, L - 0.6):
					F["PetrolDark"].prism(S.cham_rect(u - 0.6, u + 0.6, 10.95, 12.7, 0.12), 0.0, 0.6)  # junction box
					F["Graphite"].prism(S.cham_rect(u - 0.45, u + 0.45, 11.1, 12.55, 0.08), 0.6, 0.66)


def turbine_frame(K):
	"""A dark 12-sided frame plate round the turbine ring, so the landmark is framed against the cast surround instead of
	sitting on a plain slab."""
	F = S.FK(K, S.F_END)
	with S.grp("TurbineFrame", S.F_END):
		TC = 12.5
		n = 12
		R1, R2 = 10.95, 12.25
		outer = [(R2 * cos(2 * pi * k / n), TC + R2 * sin(2 * pi * k / n)) for k in range(n)]
		inner = [(R1 * cos(2 * pi * k / n), TC + R1 * sin(2 * pi * k / n)) for k in range(n)]
		S.ring_prism(F["PetrolDark"], outer, inner, 1.3, 1.55)
		rim = [(12.0 * cos(2 * pi * k / n), TC + 12.0 * sin(2 * pi * k / n)) for k in range(n)]
		rin = [(11.75 * cos(2 * pi * k / n), TC + 11.75 * sin(2 * pi * k / n)) for k in range(n)]
		S.ring_prism(F["E_Intake"], rim, rin, 1.55, 1.6)  # a warm rim on the frame: the landmark's outline glows
		# (four diagonal gussets were tried here and read as loose dashes on the surround: removed)


def build():
	K = S.kit(AREA)
	sun_well(K)
	sun_ring(K)
	boards(K)
	pipes(K)
	maintenance(K, _at(-20.0, 101.0, 8, 1.25))
	deliveries(K, _at(26.0, 7.6, -93, 1.6))
	cable_works(K, _at(-25.0, 7.5, 90, 1.45))
	pipe_stock(K, _at(22.0, 100.0, -6, 1.3))
	floor_joints(K)
	route_cues(K)
	turbine_frame(K)
	walk_motif(K)
	for sx in (-1, 1):  # service hatches in the end fields, drains along the end-bay walls
		hatch(K, sx * 18.0, 10.0, 0.0)
		hatch(K, sx * 18.0, 92.0, 0.0)
		drain(K, sx, 2.0, 18.8)
		drain(K, sx, 87.2, 110.0)
	wall_conduit(K)
	K.done()
