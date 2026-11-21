"""Snowpeak4 snowcat, modelled (2026-11-20). Replaces the script-assembled v1 the owner rejected ("those scripted
just rounded parts"). Method from the blender-director / hard-surface / vehicle-artist skills:

  proportions locked first (8 wide over the tracks, ~16.5 long with blade and tiller, ~8.6 to the beacon) ->
  track loops (stadium path, cleats with grousers following it, 4 road wheels, toothed sprocket, idler) ->
  hull and track covers -> the cab as one mesh: lower body, glasshouse, window faces inset into frames and the glass
  pushed back, door panel lines -> engine housing with chamfered top, louvre banks and a rear grille -> roof light
  bar and beacon, mirrors, handrails, steps -> front blade (faceted concave moldboard, ribs, wings, cutting edge,
  push arms, hydraulic rams) -> rear tiller (faceted housing, side plates, comb fingers, arm).
  Bevel modifiers (angle-limited, 2 segments) on the main shells, smooth faces with sharp edges over 35 degrees, so
  chamfers catch light and flats stay crisp. Everything is baked (modifiers applied) into Map_Snowcat for export.

Units: studs; +X right, +Y front (Roblox -Z), +Z up; origin = bottom centre. Our own design.
"""
from math import atan2, cos, pi, radians, sin

import bmesh
import bpy
from mathutils import Matrix, Vector

import arena_kit as A

MAT = {}


def m(name):
	if name not in MAT:
		MAT[name] = A.mat(name)
	return MAT[name]


def new_obj(name, bm, mats, coll):
	me = bpy.data.meshes.new(name)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])  # every solid faces out (Roblox meshes are one-sided)
	bm.to_mesh(me)
	bm.free()
	for mt in mats:
		me.materials.append(m(mt))
	o = bpy.data.objects.new(name, me)
	coll.objects.link(o)
	return o


def bevel(o, width, segs=2, angle=35):
	md = o.modifiers.new("Bevel", "BEVEL")
	md.width = width
	md.segments = segs
	md.limit_method = "ANGLE"
	md.angle_limit = radians(angle)
	md.harden_normals = False
	return md


def cube(bm, x0, x1, y0, y1, z0, z1, mi=0):
	r = bmesh.ops.create_cube(bm, size=1.0)
	vs = r["verts"]
	for v in vs:
		v.co = Vector(((x0 + x1) / 2 + v.co.x * (x1 - x0), (y0 + y1) / 2 + v.co.y * (y1 - y0), (z0 + z1) / 2 + v.co.z * (z1 - z0)))
	fs = list({f for v in vs for f in v.link_faces})
	for f in fs:
		f.material_index = mi
	return vs, fs


def prism(bm, pts, axis, a0, a1, mi=0):
	"""Extrude a closed polygon `pts` (2D) along `axis` ('x' | 'y' | 'z') from a0 to a1. Returns faces."""
	def P(u, v, a):
		if axis == "x":
			return Vector((a, u, v))
		if axis == "y":
			return Vector((u, a, v))
		return Vector((u, v, a))

	r0 = [bm.verts.new(P(u, v, a0)) for u, v in pts]
	r1 = [bm.verts.new(P(u, v, a1)) for u, v in pts]
	n = len(pts)
	fs = [bm.faces.new(r0), bm.faces.new(list(reversed(r1)))]
	for i in range(n):
		fs.append(bm.faces.new((r0[i], r1[i], r1[(i + 1) % n], r0[(i + 1) % n])))
	for f in fs:
		f.material_index = mi
	return fs


def ngon2(cu, cv, r, n, rot=0.0):
	return [(cu + r * cos(rot + 2 * pi * k / n), cv + r * sin(rot + 2 * pi * k / n)) for k in range(n)]


def bar(bm, p0, p1, w, h, mi=0, up=Vector((0, 0, 1))):
	p0, p1 = Vector(p0), Vector(p1)
	d = (p1 - p0).normalized()
	if abs(d.dot(up)) > 0.95:
		up = Vector((1, 0, 0))
	s = d.cross(up).normalized()
	u = s.cross(d).normalized()
	sec = [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)]
	r0 = [bm.verts.new(p0 + s * a + u * b) for a, b in sec]
	r1 = [bm.verts.new(p1 + s * a + u * b) for a, b in sec]
	fs = [bm.faces.new(list(reversed(r0))), bm.faces.new(r1)]
	for i in range(4):
		fs.append(bm.faces.new((r0[i], r0[(i + 1) % 4], r1[(i + 1) % 4], r1[i])))
	for f in fs:
		f.material_index = mi


def cyl(bm, p0, p1, r, n=12, mi=0):
	p0, p1 = Vector(p0), Vector(p1)
	d = (p1 - p0).normalized()
	up = Vector((0, 0, 1)) if abs(d.z) < 0.95 else Vector((1, 0, 0))
	s = d.cross(up).normalized()
	u = s.cross(d).normalized()
	r0 = [bm.verts.new(p0 + (s * cos(2 * pi * k / n) + u * sin(2 * pi * k / n)) * r) for k in range(n)]
	r1 = [bm.verts.new(p1 + (s * cos(2 * pi * k / n) + u * sin(2 * pi * k / n)) * r) for k in range(n)]
	fs = [bm.faces.new(list(reversed(r0))), bm.faces.new(r1)]
	for i in range(n):
		fs.append(bm.faces.new((r0[i], r0[(i + 1) % n], r1[(i + 1) % n], r1[i])))
	for f in fs:
		f.material_index = mi
	return fs


# ------------------------------------------------------------------------------------------------ tracks
TRACK_X = (1.5, 4.0)  # inner / outer x of each track (mirrored)
R_END = 1.45
Y_F, Y_R, Z_C = 4.0, -4.0, 1.65  # end wheel centres
BELT = 0.36


def stadium(s_total_steps):
	"""Points (y, z), tangents and outward normals along the track loop centreline (bottom run first)."""
	L = Y_F - Y_R
	arc = pi * R_END
	per = 2 * L + 2 * arc
	out = []
	for k in range(s_total_steps):
		s = per * k / s_total_steps
		if s < L:  # bottom run, going +Y
			p, t, n = (Y_R + s, Z_C - R_END), (1, 0), (0, -1)
		elif s < L + arc:  # front arc
			a = -pi / 2 + (s - L) / R_END
			p, t, n = (Y_F + R_END * cos(a), Z_C + R_END * sin(a)), (-sin(a), cos(a)), (cos(a), sin(a))
		elif s < 2 * L + arc:  # top run, going -Y
			p, t, n = (Y_F - (s - L - arc), Z_C + R_END), (-1, 0), (0, 1)
		else:
			a = pi / 2 + (s - 2 * L - arc) / R_END
			p, t, n = (Y_R + R_END * cos(a), Z_C + R_END * sin(a)), (-sin(a), cos(a)), (cos(a), sin(a))
		out.append((p, t, n))
	return out, per


def tracks(coll):
	bm = bmesh.new()
	pts, per = stadium(46)
	seg = per / 46
	for sx in (-1, 1):
		x0, x1 = sorted((sx * TRACK_X[0], sx * TRACK_X[1]))
		for (py, pz), (ty, tz), (ny, nz) in pts:
			c = Vector((0, py, pz))
			t = Vector((0, ty, tz))
			n = Vector((0, ny, nz))
			hl = seg * 0.46
			# the cleat plate (rubber) and its steel grouser bar on the outside face
			corners = []
			for a, b in ((-hl, -BELT / 2), (hl, -BELT / 2), (hl, BELT / 2), (-hl, BELT / 2)):
				corners.append(c + t * a + n * b)
			r0 = [bm.verts.new((x0, q.y, q.z)) for q in corners]
			r1 = [bm.verts.new((x1, q.y, q.z)) for q in corners]
			fs = [bm.faces.new(r0), bm.faces.new(list(reversed(r1)))]
			for i in range(4):
				fs.append(bm.faces.new((r0[i], r1[i], r1[(i + 1) % 4], r0[(i + 1) % 4])))
			for f in fs:
				f.material_index = 0
			g0 = c + n * (BELT / 2 - 0.02)
			gs = []
			for a, b in ((-0.09, 0.0), (0.09, 0.0), (0.06, 0.16), (-0.06, 0.16)):
				gs.append(g0 + t * a + n * b)
			q0 = [bm.verts.new((x0 + 0.05 * sx * 0 + 0.08, q.y, q.z)) for q in gs]
			q1 = [bm.verts.new((x1 - 0.08, q.y, q.z)) for q in gs]
			fs = [bm.faces.new(q0), bm.faces.new(list(reversed(q1)))]
			for i in range(4):
				fs.append(bm.faces.new((q0[i], q1[i], q1[(i + 1) % 4], q0[(i + 1) % 4])))
			for f in fs:
				f.material_index = 1
	o = new_obj("Snowcat_Tracks", bm, ["S_Rubber", "S_Steel"], coll)
	return o


def running_gear(coll):
	bm = bmesh.new()
	for sx in (-1, 1):
		x0, x1 = sorted((sx * 1.65, sx * 3.85))
		xo = sx * 3.85  # outer face
		# road wheels: steel dish, rubber tyre band, inset rim, hub boss and six bolts on the outer face
		for wy in (-2.55, -0.85, 0.85, 2.55):
			wz = Z_C - R_END + BELT / 2 + 0.95
			tyre = ngon2(wy, wz, 0.95, 14, pi / 14)
			prism(bm, tyre, "x", x0, x1, 1)
			dish = ngon2(wy, wz, 0.72, 14, pi / 14)
			a, b = sorted((xo, xo + sx * 0.06))
			prism(bm, dish, "x", a, b, 2)
			hub = ngon2(wy, wz, 0.3, 8, pi / 8)
			a, b = sorted((xo + sx * 0.06, xo + sx * 0.22))
			prism(bm, hub, "x", a, b, 0)
			for k in range(6):
				bu, bv = wy + 0.47 * cos(k * pi / 3), wz + 0.47 * sin(k * pi / 3)
				a, b = sorted((xo + sx * 0.06, xo + sx * 0.13))
				prism(bm, ngon2(bu, bv, 0.07, 6), "x", a, b, 0)
		# drive sprocket (front): a 14-tooth outline, a hub; idler (rear): plain dish
		teeth = []
		for k in range(28):
			a = k * pi / 14
			rr = 1.1 if k % 2 == 0 else 0.98
			teeth.append((Y_F + rr * cos(a), Z_C + rr * sin(a)))
		a, b = sorted((sx * 2.2, sx * 3.3))
		prism(bm, teeth, "x", a, b, 2)
		a, b = sorted((sx * 3.3, sx * 3.5))
		prism(bm, ngon2(Y_F, Z_C, 0.45, 8, pi / 8), "x", a, b, 0)
		a, b = sorted((sx * 1.7, sx * 3.8))
		prism(bm, ngon2(Y_R, Z_C, 1.05, 14, pi / 14), "x", a, b, 1)
		a, b = sorted((sx * 3.8, sx * 3.95))
		prism(bm, ngon2(Y_R, Z_C, 0.45, 8, pi / 8), "x", a, b, 0)
		# axles into the hull
		for wy in (-2.55, -0.85, 0.85, 2.55, Y_F, Y_R):
			wz = Z_C if wy in (Y_F, Y_R) else Z_C - R_END + BELT / 2 + 0.95
			cyl(bm, (sx * 1.4, wy, wz), (sx * 1.75, wy, wz), 0.22, 8, 0)
	return new_obj("Snowcat_Wheels", bm, ["S_Steel", "S_Rubber", "S_SteelLight"], coll)


# ------------------------------------------------------------------------------------------------ hull + body
def hull(coll):
	bm = bmesh.new()
	cube(bm, -1.5, 1.5, -5.0, 5.2, 0.85, 3.1, 0)  # chassis between the tracks
	for sx in (-1, 1):  # track covers: flat run, sloped front and back
		x0, x1 = sorted((sx * 1.35, sx * 4.2))
		prof = [(-5.9, 3.05), (-5.3, 3.4), (5.2, 3.4), (6.0, 3.0), (6.0, 2.85), (5.15, 3.22), (-5.2, 3.22), (-5.75, 2.9)]
		prism(bm, prof, "x", x0, x1, 1)
	o = new_obj("Snowcat_Hull", bm, ["S_Steel", "S_PaintDark"], coll)
	bevel(o, 0.06, 2)
	return o


def cab(coll):
	"""One mesh: lower body + glasshouse; side / front / back faces of the glasshouse are inset into a frame and the
	glass pushed back; door panel lines and a roof with overhang."""
	bm = bmesh.new()
	# lower body (paint) with a white stripe band
	cube(bm, -2.95, 2.95, 0.3, 4.75, 3.4, 4.9, 0)
	cube(bm, -3.0, 3.0, 0.25, 4.8, 4.05, 4.4, 3)  # stripe band
	# glasshouse: bottom ring at 4.9, top ring at 7.55, raked front
	bot = [(-2.95, 0.3), (2.95, 0.3), (2.95, 4.75), (-2.95, 4.75)]
	top = [(-2.75, 0.45), (2.75, 0.45), (2.75, 3.75), (-2.75, 3.75)]
	vb = [bm.verts.new((x, y, 4.9)) for x, y in bot]
	vt = [bm.verts.new((x, y, 7.55)) for x, y in top]
	sides = []
	for i in range(4):
		f = bm.faces.new((vb[i], vb[(i + 1) % 4], vt[(i + 1) % 4], vt[i]))
		f.material_index = 0
		sides.append(f)
	ftop = bm.faces.new(list(vt))
	ftop.material_index = 0
	fbot = bm.faces.new(list(reversed(vb)))
	fbot.material_index = 0
	bm.normal_update()
	# window frames: inset each side face, then push the inner face back and make it glass
	res = bmesh.ops.inset_individual(bm, faces=sides, thickness=0.26, depth=0.0, use_even_offset=True)
	for f in sides:
		f.material_index = 1
		nrm = f.normal.copy()
		for v in f.verts:
			v.co -= nrm * 0.12
	# split the front pane with a centre post and the side panes with a B-pillar (bars across the glass)
	bar(bm, (0, 4.62, 5.0), (0, 3.86, 7.45), 0.22, 0.16, 0)
	for sx in (-1, 1):
		bar(bm, (sx * 2.92, 2.1, 5.0), (sx * 2.78, 2.1, 7.45), 0.16, 0.24, 0)
	# roof with overhang, a sun visor lip at the front
	cube(bm, -3.05, 3.05, 0.2, 4.0, 7.5, 7.95, 0)
	cube(bm, -2.9, 2.9, 3.9, 4.35, 7.55, 7.75, 2)
	# door panel lines (thin dark strips just proud of the lower body) and handles
	for sx in (-1, 1):
		a, b = sorted((sx * 2.95, sx * 2.99))
		cube(bm, a, b, 2.0, 2.08, 3.45, 4.85, 2)
		cube(bm, a, b, 4.2, 4.28, 3.45, 4.85, 2)
		a, b = sorted((sx * 3.0, sx * 3.07))
		cube(bm, a, b, 3.5, 3.95, 4.55, 4.68, 2)
	o = new_obj("Snowcat_Cab", bm, ["S_Paint", "S_Glass", "S_Steel", "S_Stripe"], coll)
	bevel(o, 0.07, 2, 40)
	return o


def engine(coll):
	"""Engine housing behind the cab: chamfered top, louvre banks on both sides, a rear grille, exhaust."""
	bm = bmesh.new()
	prof = [(-2.9, 3.35), (2.9, 3.35), (2.9, 5.0), (2.3, 5.7), (-2.3, 5.7), (-2.9, 5.0)]
	prism(bm, prof, "y", -5.1, 0.35, 0)
	# louvre banks: slats proud on each side
	for sx in (-1, 1):
		for k in range(5):
			z = 3.8 + k * 0.24
			a, b = sorted((sx * 2.9, sx * 2.98))
			cube(bm, a, b, -4.3, -1.3, z, z + 0.09, 1)
		a, b = sorted((sx * 2.88, sx * 2.92))
		cube(bm, a, b, -4.45, -1.15, 3.6, 5.0, 1)
	# rear grille and lights
	cube(bm, -2.2, 2.2, -5.18, -5.1, 3.6, 5.2, 1)
	for k in range(7):
		z = 3.75 + k * 0.2
		cube(bm, -2.1, 2.1, -5.24, -5.16, z, z + 0.08, 2)
	for sx in (-1, 1):
		a, b = sorted((sx * 2.35, sx * 2.8))
		cube(bm, a, b, -5.2, -5.1, 4.6, 5.0, 3)
	# exhaust stack with a rain cap, an air intake box
	cyl(bm, (-1.8, -3.6, 5.6), (-1.8, -3.6, 7.4), 0.2, 12, 1)
	cube(bm, -2.05, -1.55, -3.85, -3.35, 7.35, 7.5, 1)
	cube(bm, 0.9, 2.1, -2.8, -1.4, 5.6, 6.2, 0)
	cube(bm, 0.95, 2.05, -1.46, -1.38, 5.7, 6.1, 1)
	o = new_obj("Snowcat_Engine", bm, ["S_Paint", "S_Steel", "S_SteelLight", "S_Amber"], coll)
	bevel(o, 0.08, 2, 40)
	return o


def fittings(coll):
	"""Roof light bar and beacon, mirrors on arms, handrails, steps, front lights."""
	bm = bmesh.new()
	# light bar: a rail with four lamp housings, lenses facing front
	cube(bm, -2.6, 2.6, 3.3, 3.5, 7.95, 8.1, 0)
	for x in (-2.0, -0.7, 0.7, 2.0):
		cube(bm, x - 0.38, x + 0.38, 3.35, 3.75, 8.1, 8.55, 0)
		cube(bm, x - 0.3, x + 0.3, 3.75, 3.8, 8.17, 8.48, 1)
	# beacon on a plinth
	prism(bm, ngon2(0, 1.5, 0.38, 12), "z", 7.95, 8.1, 0)
	prism(bm, ngon2(0, 1.5, 0.3, 12), "z", 8.1, 8.6, 2)
	# mirrors on arms at the front corners
	for sx in (-1, 1):
		bar(bm, (sx * 2.95, 4.5, 6.9), (sx * 3.7, 4.9, 7.0), 0.1, 0.1, 0)
		a, b = sorted((sx * 3.6, sx * 3.85))
		cube(bm, a, b, 4.7, 5.05, 6.3, 7.2, 0)
	# handrails along the engine deck (posts + rail) and the cab-side step
	for sx in (-1, 1):
		for y in (-4.6, -2.6, -0.6):  # posts stand on the flat top (|x| <= 2.3), not on the chamfer
			bar(bm, (sx * 2.15, y, 5.62), (sx * 2.15, y, 6.35), 0.1, 0.1, 3)
		bar(bm, (sx * 2.15, -4.65, 6.35), (sx * 2.15, -0.55, 6.35), 0.12, 0.12, 3)
		a, b = sorted((sx * 3.0, sx * 3.7))
		cube(bm, a, b, 2.4, 3.6, 2.6, 2.75, 0)
		bar(bm, (sx * 3.35, 2.45, 2.7), (sx * 3.05, 2.45, 3.45), 0.1, 0.1, 0)
		bar(bm, (sx * 3.35, 3.55, 2.7), (sx * 3.05, 3.55, 3.45), 0.1, 0.1, 0)
	# front work lights in the cab's lower front
	for sx in (-1, 1):
		a, b = sorted((sx * 1.6, sx * 2.6))
		cube(bm, a, b, 4.75, 4.85, 3.6, 4.0, 0)
		a, b = sorted((sx * 1.68, sx * 2.52))
		cube(bm, a, b, 4.84, 4.9, 3.66, 3.94, 1)
	return new_obj("Snowcat_Fittings", bm, ["S_Steel", "S_Lamp", "S_Amber", "S_SteelLight"], coll)


def blade(coll):
	"""Front blade: a faceted concave moldboard (6 plates), back ribs, angled wings, cutting edge; push arms and two
	hydraulic rams from the hull."""
	bm = bmesh.new()
	# (y, z) the concave face as five angled plates: the cutting edge forward, the middle set back, the top curling
	# forward again (a moldboard, not a drum)
	prof = [(6.75, 0.05), (6.4, 0.65), (6.15, 1.4), (6.18, 2.15), (6.4, 2.7), (6.7, 3.0)]
	back = [(y - 0.3, z) for y, z in reversed(prof)]
	poly = prof + back
	prism(bm, poly, "x", -4.2, 4.2, 0)
	cube(bm, -4.25, 4.25, 6.25, 6.72, 0.0, 0.22, 1)  # cutting edge
	for x in (-2.6, 0.0, 2.6):  # back ribs
		cube(bm, x - 0.12, x + 0.12, 5.3, 5.62, 0.4, 2.7, 1)
	for sx in (-1, 1):  # wings, angled forward
		bar(bm, (sx * 4.15, 5.7, 0.05), (sx * 4.75, 6.6, 0.05), 0.12, 0.1, 0)
		wing = [(5.55, 0.05), (6.75, 0.05), (6.55, 2.9), (5.45, 3.0)]
		a, b = sorted((sx * 4.15, sx * 4.3))
		prism(bm, wing, "x", a, b, 0)
	# push frame: arms from the hull front to the blade back, rams above them
	for sx in (-1, 1):
		bar(bm, (sx * 1.2, 5.1, 1.5), (sx * 1.6, 5.45, 1.2), 0.35, 0.35, 1)
		cyl(bm, (sx * 0.9, 4.9, 2.9), (sx * 1.1, 5.4, 2.1), 0.2, 10, 1)
		cyl(bm, (sx * 1.1, 5.4, 2.1), (sx * 1.2, 5.6, 1.8), 0.11, 8, 2)
	o = new_obj("Snowcat_Blade", bm, ["S_SteelLight", "S_Steel", "S_Chrome"], coll)
	bevel(o, 0.05, 1, 25)
	return o


def tiller(coll):
	"""Rear tiller: faceted housing on side plates, the comb (finger flaps) trailing it, an arm and a ram."""
	bm = bmesh.new()
	arc = []
	for k in range(6):
		a = radians(180 - k * 36)
		arc.append((-6.85 + 1.15 * cos(a), 0.55 + 1.15 * sin(a)))
	poly = arc + [(-5.7, 0.35), (-8.0, 0.35)]
	prism(bm, poly, "x", -3.85, 3.85, 0)
	for sx in (-1, 1):
		a, b = sorted((sx * 3.85, sx * 4.0))
		prism(bm, [(-8.15, 0.15), (-5.55, 0.15), (-5.55, 1.5), (-6.85, 1.9), (-8.15, 1.4)], "x", a, b, 1)
	for k in range(12):  # comb fingers
		x = -3.55 + k * (7.1 / 11)
		cube(bm, x - 0.24, x + 0.24, -8.95, -8.0, 0.02, 0.12, 2)
	cube(bm, -3.85, 3.85, -8.1, -7.95, 0.05, 0.5, 1)
	for sx in (-1, 1):  # arms to the hull, ram
		bar(bm, (sx * 1.1, -5.0, 1.6), (sx * 1.3, -5.9, 1.2), 0.35, 0.35, 1)
	cyl(bm, (0, -4.9, 2.9), (0, -6.2, 1.7), 0.2, 10, 1)
	o = new_obj("Snowcat_Tiller", bm, ["S_SteelLight", "S_Steel", "S_Rubber"], coll)
	bevel(o, 0.05, 1, 40)
	return o


# ------------------------------------------------------------------------------------------------ assemble + bake
def finalize(objs, coll, name="Snowcat"):
	"""Apply every modifier into plain meshes (smooth faces, sharp edges over 35 deg), one object per part."""
	dg = bpy.context.evaluated_depsgraph_get()
	out = []
	for o in objs:
		ev = o.evaluated_get(dg)
		me = bpy.data.meshes.new_from_object(ev)
		me.transform(o.matrix_world)  # bake the object's placement (props pose their parts by transform)
		bm = bmesh.new()
		bm.from_mesh(me)
		for f in bm.faces:
			f.smooth = True
		for e in bm.edges:
			if len(e.link_faces) == 2 and e.calc_face_angle(0) > radians(35):
				e.smooth = False
		bm.to_mesh(me)
		bm.free()
		nm = o.name
		bpy.data.objects.remove(o, do_unlink=True)
		n = bpy.data.objects.new(nm, me)
		coll.objects.link(n)
		out.append(n)
	return out


def build(coll):
	A.PAL.update({"S_Stripe": ("#E6E1D6", 0.6), "S_Chrome": ("#B9BEC4", 0.3)})
	parts = [tracks(coll), running_gear(coll), hull(coll), cab(coll), engine(coll), fittings(coll), blade(coll), tiller(coll)]
	return finalize(parts, coll)
