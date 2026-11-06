# build_map_kit_snowpeak2.py: the Snowpeak2 map kit (vault/01 Design/Maps/Snowpeak2.md; a copy of build_map_kit_snowpeak.py raised to
# the Map Quality Standard: role materials with our own MaterialVariants, warm amber windows, icicles, rendered-font
# sign decals instead of SurfaceGui text). Kit group "Kit".
#
# Every piece is a collection Map_<Piece> built at the world origin, authored in ROBLOX map-local coordinates
# (studs, +Y up) through rb()/RB() and converted to Blender (x, -z, y), so a vertex at Roblox (x, y, z) lands back
# at (x, y, z) after export (kit_bundle.py maps Blender (x, y, z) -> Roblox (x, z, -y)). Pieces that sit where the
# greybox has collision are built ON the collision boxes of tools/maps/snowpeak_layout.py (imported here), so the
# look matches what you can stand on and shoot.
#
# Origins (Roblox local):
#   Lodge, Fireplace, Cliffs, Range   map origin (placed once at (0, 0, 0))
#   LodgeInside       map origin, the B half (z > 0) of the interior; placed at yaw 0 and 180
#   Station, Line     the B station's footprint centre (-52, 0, 42); the A one is the same turned 180
#   Cabin             floor centre of a 6 x 6 x 8 gondola cabin (hanger arm above 8)
#   *Stair            floor centre of a 6 x 16 footprint rising 10 toward +Z (the greybox WedgePart's own axes)
#   huts, piles, rocks, props    floor centre of their greybox box
#   Parapet8          an 8-long piece of the 2-thick, 3-tall edge wall, centre of its footprint
#   PondRim           centre of the pond (B: (46, 0, 32)), the ice 0.4 below the snow
# Parts named *_Paint take the end colour per instance (Art.luau: B blue, A gold); *_Glow are Neon.
#
# The same script writes the PLACEMENTS block of tools/studio/maps/Snowpeak2/Art.luau (one source for the art pass
# and the offline preview), renders the contact sheet and the assembled previews, and runs a coplanar (z-fighting)
# check over every triangle of the assembled map plus the greybox Parts that stay visible.
#
# Run (headless):
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
#       --python tools/blender/build_map_kit_snowpeak2.py -- [--no-render] [--samples N] [--shots a,b]
# Export: blender --background --factory-startup art-source/maps/Snowpeak2/Kit_Snowpeak2.blend
#         --python tools/blender/export_lobby_kit.py -- --maps Snowpeak2 Kit

import json, math, os, random, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "maps"))
import bpy, bmesh  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
import lobbykit as K  # noqa: E402
from gunkit import prism, box, merge, group, ring_pts, bevel  # noqa: E402
import snowpeak2_layout as L  # noqa: E402
import snowpeak2_style as S  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
K.ART_DIR = os.path.join(K.ROOT, "art-source", "maps", "Snowpeak2")
K.RENDER_DIR = os.path.join(K.ROOT, "vault", "02 Art", "References", "maps", "snowpeak2")

STATION_O = (-52.0, 42.0)  # B station footprint centre (map x, z)
POND_O = (46.0, 32.0)
END_B, END_A = S.END["B"], S.END["A"]


# ---------------------------------------------------------------- Roblox-space geometry helpers

def rb(p):
	return Vector((p[0], -p[2], p[1]))


def RB(x0, x1, y0, y1, z0, z1, ch=0.0):
	bm = box(min(x0, x1), max(x0, x1), -max(z0, z1), -min(z0, z1), min(y0, y1), max(y0, y1))
	if ch > 0:
		bevel(bm, ch, segs=1, angle=30)
	return bm


def pZ(pts, z0, z1):
	# polygon in Roblox (x, y), extruded along Roblox z0..z1
	return prism(pts, "Y", -z1, -z0)


def pX(pts, x0, x1):
	# polygon in Roblox (z, y), extruded along Roblox x0..x1
	return prism([(-z, y) for z, y in pts], "X", x0, x1)


def pY(pts, y0, y1):
	# polygon in Roblox (x, z), extruded along Roblox y0..y1
	return prism([(x, -z) for x, z in pts], "Z", y0, y1)


def frame_to(a, b, up=(0, 1, 0)):
	A, Bv = rb(a), rb(b)
	d = Bv - A
	x = d.normalized()
	u = rb(up)
	if abs(x.dot(u.normalized())) > 0.99:
		u = Vector((1, 0, 0)) if abs(x.x) < 0.9 else Vector((0, 1, 0))
	y = u.cross(x).normalized()
	z = x.cross(y)
	return Matrix(((x.x, y.x, z.x, A.x), (x.y, y.y, z.y, A.y), (x.z, y.z, z.z, A.z), (0, 0, 0, 1))), d.length


def beam(a, b, w, h, up=(0, 1, 0)):
	m, Ln = frame_to(a, b, up)
	return K.place(box(0, Ln, -w / 2, w / 2, -h / 2, h / 2), m)


def rod(a, b, r, segs=6):
	m, Ln = frame_to(a, b)
	return K.place(prism(ring_pts(0, 0, r, segs, math.pi / segs), "X", 0, Ln), m)


def tube(pts, r, segs=5):
	# One continuous tube along a polyline (Roblox points): shared rings, no overlapping joints.
	bm = bmesh.new()
	rings = []
	for k, p in enumerate(pts):
		a = Vector(pts[max(k - 1, 0)])
		b = Vector(pts[min(k + 1, len(pts) - 1)])
		d = (b - a).normalized()
		u = Vector((0, 1, 0)) if abs(d.y) < 0.9 else Vector((1, 0, 0))
		s1 = d.cross(u).normalized()
		s2 = d.cross(s1).normalized()
		ring = []
		for i in range(segs):
			ang = 2 * math.pi * i / segs
			q = Vector(p) + (s1 * math.cos(ang) + s2 * math.sin(ang)) * r
			ring.append(bm.verts.new(rb(q)))
		rings.append(ring)
	for ra, rb_ in zip(rings, rings[1:]):
		for i in range(segs):
			j = (i + 1) % segs
			bm.faces.new((ra[i], ra[j], rb_[j], rb_[i]))
	bm.faces.new(rings[0][::-1])
	bm.faces.new(rings[-1])
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	return bm


def vcyl(x, z, r, y0, y1, segs=12):
	return K.cyl(x, -z, r, y0, y1, segs=segs)


def ry(bm, deg):
	# rotate about the Roblox Y axis (a CFrame.Angles(0, deg, 0) turn)
	return K.place(bm, Matrix.Rotation(math.radians(deg), 4, "Z"))


def mv(bm, x, y, z):
	return K.place(bm, Matrix.Translation(rb((x, y, z))))


def cp(bm):
	return K.copy(bm)


class Acc:
	def __init__(self):
		self.d = {}

	def add(self, part, mat, *bms):
		for bm in bms:
			if part in self.d:
				merge(self.d[part][0], bm)
			else:
				self.d[part] = [bm, mat]

	def parts(self):
		return {k: (v[0], v[1]) for k, v in self.d.items()}


def tidy(bm):
	ngons = [f for f in bm.faces if len(f.verts) > 4]
	if ngons:
		bmesh.ops.triangulate(bm, faces=ngons, quad_method="BEAUTY", ngon_method="EAR_CLIP")
	return bm


def piece(name, acc, mats, kit):
	col = K.collection("Map_" + name, kit)
	parts = acc.parts()
	for _, (bm, _) in parts.items():
		tidy(bm)
	K.build(name, parts, mats, col)
	return col


def smooth(a, b, x):
	t = min(1.0, max(0.0, (x - a) / (b - a)))
	return t * t * (3 - 2 * t)


# ---------------------------------------------------------------- noise and the mountains (one function for kit and placements)

def _hash(i, j, seed):
	h = (i * 374761393 + j * 668265263 + seed * 1442695041) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


def vnoise(x, z, seed=1):
	i, j = math.floor(x), math.floor(z)
	fx, fz = x - i, z - j
	sx, sz = fx * fx * (3 - 2 * fx), fz * fz * (3 - 2 * fz)
	a, b = _hash(i, j, seed), _hash(i + 1, j, seed)
	c, d = _hash(i, j + 1, seed), _hash(i + 1, j + 1, seed)
	return (a + (b - a) * sx) + ((c + (d - c) * sx) - (a + (b - a) * sx)) * sz


def ridged(x, z, seed=3, octaves=4):
	v, amp, f, tot = 0.0, 1.0, 1.0, 0.0
	for o in range(octaves):
		n = 1 - abs(2 * vnoise(x * f, z * f, seed + o) - 1)
		v += n * n * amp
		tot += amp
		amp *= 0.5
		f *= 2.1
	return v / tot


def _plateau_dist(x, z):
	dx = max(abs(x) - 66, 0)
	dz = max(abs(z) - 80, 0)
	return math.hypot(dx, dz)


def _h(x, z):
	ax, az = abs(x), abs(z)
	ridge = 0.0 if az < 80 else min(74 + 2.0 * (az - 80), 470)
	h = ridge * (1 - smooth(70, 950, ax))
	h += (-280 * smooth(66, 240, ax) + 700 * smooth(420, 1150, ax)) * (1 - smooth(80, 320, az))
	d = _plateau_dist(x, z)
	h += (ridged(x / 180, z / 180) - 0.45) * (8 + 0.32 * d)
	return h


_GRID = None


def range_surface(x, z):
	# Height of the triangulated Range mesh: the lowest of bilinear and both diagonal splits (props sink, never float).
	global _GRID
	if _GRID is None:
		g = range_grid()
		_GRID = (g, {(a, b): range_h(a, b) for a in g for b in g})
	g, H = _GRID
	i = max(0, min(len(g) - 2, next((k for k in range(len(g) - 1) if g[k] <= x <= g[k + 1]), 0)))
	j = max(0, min(len(g) - 2, next((k for k in range(len(g) - 1) if g[k] <= z <= g[k + 1]), 0)))
	x0, x1, z0, z1 = g[i], g[i + 1], g[j], g[j + 1]
	tx, tz = (x - x0) / (x1 - x0), (z - z0) / (z1 - z0)
	h00, h10, h01, h11 = H[(x0, z0)], H[(x1, z0)], H[(x0, z1)], H[(x1, z1)]
	bil = h00 * (1 - tx) * (1 - tz) + h10 * tx * (1 - tz) + h01 * (1 - tx) * tz + h11 * tx * tz
	if tx > tz:
		d1 = h00 + (h10 - h00) * tx + (h11 - h10) * tz
	else:
		d1 = h00 + (h01 - h00) * tz + (h11 - h01) * tx
	if tx + tz < 1:
		d2 = h00 + (h10 - h00) * tx + (h01 - h00) * tz
	else:
		d2 = h11 + (h01 - h11) * (1 - tx) + (h10 - h11) * (1 - tz)
	return min(bil, d1, d2)


def range_h(x, z):
	# Centrally symmetric (both lines and both ends match), the drop starts right at the fence.
	h = 0.5 * (_h(x, z) + _h(-x, -z))
	if abs(z) < 80 and 66 <= abs(x) < 90:
		h = min(h, -0.6 - (abs(x) - 66) * 4.0 * (1 - smooth(56, 80, abs(z))))
	if abs(z) >= 80 and abs(x) < 120:
		h = max(h, (74.0 + 0.2 * (abs(z) - 80)) * (1 - smooth(66, 120, abs(x))))
	if abs(x) <= 28 and 80 <= abs(z) <= 106:
		h = min(h, 76.5)  # Snowpeak2 r2: a col over each spawn alcove (the ridge stood 114 over 76-tall alcove walls: a see-through notch)
	return h


# ---------------------------------------------------------------- materials

def make_mats():
	mats = K.begin()
	add = {}
	for name, (hx, rbx, var) in S.MATS.items():
		m = K._flat("S2_" + name, int(hx, 16), 0.6 if rbx != "Metal" else 0.35, metallic=0.7 if rbx == "Metal" else 0.0, rbx=rbx)
		m["rbx_variant"] = var
		add[name] = m
	add["Paint"] = K._flat("S2_EndPaint", int(END_B, 16), 0.55, rbx="SmoothPlastic")
	add["Paint"]["rbx_variant"] = ""
	for name, hx in S.GLASS.items():
		g = K._glass("S2_" + name, int(hx, 16))
		g["rbx_variant"] = ""
		add[name] = g
	for name, hx in S.GLOW.items():
		g = K._emissive("S2_" + name, int(hx, 16), 2.4)
		g["rbx_variant"] = ""
		add[name] = g
	mats.update(add)
	return mats


# ---------------------------------------------------------------- layout access

def boxes(pred):
	return [b for b in L.BOXES if pred(b)]


def bx(b, inset=0.0, y0=None, y1=None):
	return RB(b.x0 + inset, b.x1 - inset, b.y0 if y0 is None else y0, b.top if y1 is None else y1, b.z0 + inset, b.z1 - inset)


def board_rail(x0, x1, z0, z1, y0, y1, acc, panel="TimberLight", cap="TimberDark", post_every=4.0):
	# A chalet balustrade filling a rail box: boarded panel (inset), posts, a handrail cap on top.
	along_x = (x1 - x0) >= (z1 - z0)
	t = (z1 - z0) if along_x else (x1 - x0)
	ins = t * 0.25
	top = y1 - 0.45
	if along_x:
		acc.add("Rail", panel, RB(x0 + 0.05, x1 - 0.05, y0 + 0.15, top - 0.08, z0 + ins, z1 - ins))
		n = max(1, int(round((x1 - x0) / post_every)))
		for i in range(n + 1):
			px = x0 + (x1 - x0) * i / n
			px = min(max(px, x0 + 0.25), x1 - 0.25)
			acc.add("RailPost", cap, RB(px - 0.25, px + 0.25, y0, top, z0 + 0.02, z1 - 0.02))
	else:
		acc.add("Rail", panel, RB(x0 + ins, x1 - ins, y0 + 0.15, top - 0.08, z0 + 0.05, z1 - 0.05))
		n = max(1, int(round((z1 - z0) / post_every)))
		for i in range(n + 1):
			pz = z0 + (z1 - z0) * i / n
			pz = min(max(pz, z0 + 0.25), z1 - 0.25)
			acc.add("RailPost", cap, RB(x0 + 0.02, x1 - 0.02, y0, top, pz - 0.25, pz + 0.25))
	acc.add("RailCap", cap, RB(x0, x1, top, y1, z0, z1))


# ---------------------------------------------------------------- the Lodge (exterior, both halves)

def lodge_openings():
	# Per wall, the openings from the layout: (wall, (along0, along1, y0, y1)). Walls: E (x = 18 face), W, N (z = 22), S.
	out = []
	for b0, b1, opens in L.EAST_WALL_BAYS:
		for o0, o1 in opens:
			out.append(("E", (b0, b1, o0, o1)))
			out.append(("W", (-b1, -b0, o0, o1)))
	for b0, b1, opens in L.END_WALL_BAYS:
		for o0, o1 in opens:
			out.append(("N", (b0, b1, o0, o1)))
			out.append(("S", (-b1, -b0, o0, o1)))
	return out


def wall_box(wall, a0, a1, y0, y1, d0, d1):
	# A box on a wall face: a along the wall, d outward from the outer face (d < 0 is inside the wall).
	X, Z = L.LODGE_X, L.LODGE_Z
	if wall == "E":
		return RB(X + d0, X + d1, y0, y1, a0, a1)
	if wall == "W":
		return RB(-X - d1, -X - d0, y0, y1, a0, a1)
	if wall == "N":
		return RB(a0, a1, y0, y1, Z + d0, Z + d1)
	return RB(a0, a1, y0, y1, -Z - d1, -Z - d0)


def p_lodge(mats, kit):
	acc = Acc()
	X, Z = L.LODGE_X, L.LODGE_Z
	# Core: exactly the greybox wall solids (timber, both faces).
	for b in boxes(lambda b: b.name.startswith("Lodge wall")):
		acc.add("Walls", "Timber", bx(b))
	opens = lodge_openings()
	ext = {"E": (-Z, Z), "W": (-Z, Z), "N": (-X, X), "S": (-X, X)}
	# Corner rule: the end walls' layers run to the corner (+- 18.x), the long walls' layers stop 0.15 short.

	def runs(wall, y0, y1, corner):
		a0, a1 = ext[wall]
		cuts = sorted((o[0], o[1]) for w, o in opens if w == wall and o[2] < y1 and o[3] > y0)
		if wall in ("E", "W"):
			a0, a1 = a0 + 0.15, a1 - 0.15
		else:
			a0, a1 = a0 - corner, a1 + corner
		segs, a = [], a0
		for c0, c1 in cuts:
			if c0 - 0.05 > a:
				segs.append((a, c0 - 0.05))
			a = max(a, c1 + 0.05)
		if a < a1:
			segs.append((a, a1))
		return segs

	# Stone plinth (0..2.6) proud 0.3, the floor band (8.7..9.7) proud 0.22.
	for w in "EWNS":
		for a0, a1 in runs(w, 0, 2.6, 0.3):
			acc.add("Plinth", "Stone", wall_box(w, a0, a1, 0, 2.6, -0.1, 0.3))
		for a0, a1 in runs(w, 8.7, 9.7, 0.22):
			acc.add("Band", "TimberDark", wall_box(w, a0, a1, 8.7, 9.7, -0.15, 0.22))
		# Corner posts (dark timber) above the plinth on the end walls' corners.
	for sx in (-1, 1):
		for sz in (-1, 1):
			acc.add("CornerPosts", "TimberDark", RB(min(sx * (X - 0.05), sx * (X + 0.26)), max(sx * (X - 0.05), sx * (X + 0.26)), 2.6, 8.7, min(sz * (Z - 0.05), sz * (Z + 0.26)), max(sz * (Z - 0.05), sz * (Z + 0.26))))
	# Openings: frames (proud 0.16), glass in the windows, open shutters beside the upper windows.
	for w, (a0, a1, y0, y1) in opens:
		door = y0 in (0, 10) and (a1 - a0) >= 6
		fr = []
		fr.append(wall_box(w, a0 - 0.4, a0 + 0.05, y0, y1 - 0.05, -0.2, 0.16))
		fr.append(wall_box(w, a1 - 0.05, a1 + 0.4, y0, y1 - 0.05, -0.2, 0.16))
		fr.append(wall_box(w, a0 - 0.4, a1 + 0.4, y1 - 0.05, y1 + 0.4, -0.2, 0.16))
		if not door:
			fr.append(wall_box(w, a0 - 0.55, a1 + 0.55, y0 - 0.3, y0 + 0.05, -0.25, 0.4))  # sill board
		acc.add("Frames", "TimberDark", *fr)
		if not door:
			acc.add("Glass", "Glass", wall_box(w, a0, a1, y0, y1, -0.53, -0.47))
			# r3: mullions (a cross in every window), between the glass and the frame face
			cm, ym = (a0 + a1) / 2, (y0 + y1) / 2
			acc.add("Mullions", "TimberDark", wall_box(w, cm - 0.12, cm + 0.12, y0, y1, -0.46, -0.08), wall_box(w, a0, cm - 0.12, ym - 0.1, ym + 0.1, -0.44, -0.1), wall_box(w, cm + 0.12, a1, ym - 0.1, ym + 0.1, -0.44, -0.1))
			sw = (a1 - a0) / 2
			acc.add("Shutters", "Shutter", wall_box(w, a0 - 0.4 - sw, a0 - 0.45, y0, y1, 0.02, 0.14), wall_box(w, a1 + 0.45, a1 + 0.4 + sw, y0, y1, 0.02, 0.14))
	# Closed shutters on the blank ground-floor bays of the end walls (the window rhythm continues).
	for a0, a1 in ((-15, -10), (10, 15)):
		for w, (b0, b1) in (("N", (a0, a1)), ("S", (-a1, -a0))):
			acc.add("Shutters", "Shutter", wall_box(w, b0, b1, 3, 8, 0.02, 0.14))
			acc.add("Frames", "TimberDark", wall_box(w, b0 - 0.4, b0 + 0.05, 3.05, 7.95, -0.2, 0.16), wall_box(w, b1 - 0.05, b1 + 0.4, 3.05, 7.95, -0.2, 0.16), wall_box(w, b0 - 0.4, b1 + 0.4, 7.95, 8.4, -0.2, 0.16), wall_box(w, b0 - 0.55, b1 + 0.55, 2.75, 3.05, -0.25, 0.4))
	# Porch walls (stone), exactly the greybox boxes, and the stone cap on the porch side of the end wall.
	for b in boxes(lambda b: b.name.startswith("Porch wall")):
		acc.add("Porch", "Stone", bx(b))
	# Balcony: deck boards on the slab (top = 10), fascia on the outer edges, joists and brackets below.
	for b in boxes(lambda b: b.name.startswith("Balcony E") or b.name.startswith("Balcony N")):
		acc.add("Deck", "Oak", bx(b, y0=9.35))
		east = b.sx < b.sz
		if east:
			s = 1 if b.x > 0 else -1
			acc.add("Fascia", "TimberDark", RB(b.x1 if s > 0 else b.x0 - 0.2, b.x1 + 0.2 if s > 0 else b.x0, 8.9, 10.05, b.z0 - 0.2, b.z1 + 0.2))
			for k in range(int(b.sz // 3)):
				zz = b.z0 + 1.5 + 3 * k
				acc.add("Joists", "TimberDark", RB(b.x0, b.x1, 8.75, 9.35, zz - 0.25, zz + 0.25))
			for zz in (-25.5, -17.0, -11.0, 0.0, 11.0, 21.0, 25.5):
				x_in, x_out = (X, X + 4.6) if s > 0 else (-X, -X - 4.6)
				acc.add("Brackets", "TimberDark", beam((x_in + s * 0.01, 5.6, zz), (x_out, 8.75, zz), 0.45, 0.45))
		else:
			s = 1 if b.z > 0 else -1
			zo = b.z1 if s > 0 else b.z0
			acc.add("Fascia", "TimberDark", RB(b.x0, b.x1, 8.9, 10.05, zo if s > 0 else zo - 0.2, zo + 0.2 if s > 0 else zo))
			for k in range(int(b.sx // 3)):
				xx = b.x0 + 1.5 + 3 * k
				if abs(xx) < 6.6:
					continue  # over the porch walls
				acc.add("Joists", "TimberDark", RB(xx - 0.25, xx + 0.25, 8.75, 9.35, b.z0, b.z1))
			for xx in (-16.0, -8.0, 8.0, 16.0):
				acc.add("Brackets", "TimberDark", beam((xx, 5.6, s * Z + s * 0.01), (xx, 8.75, s * (Z + 4.6)), 0.45, 0.45))
	for b in boxes(lambda b: b.name.startswith("Balcony rail")):
		board_rail(b.x0, b.x1, b.z0, b.z1, b.y0, b.top, acc)
	# Soffit under the roof overhang (y 19.7..20), the inside ceiling and its beams.
	for sx in (-1, 1):
		acc.add("Soffit", "Timber", RB(min(sx * X, sx * 24), max(sx * X, sx * 24), 19.7, 20, -28, 28))
	for sz in (-1, 1):
		acc.add("Soffit", "Timber", RB(-X, X, 19.7, 20, min(sz * Z, sz * 28), max(sz * Z, sz * 28)))
	acc.add("Ceiling", "TimberLight", RB(-17, 17, 19.8, 20.0, -21, 21))
	for k in range(-3, 4):
		acc.add("CeilingBeams", "TimberDark", RB(-17, 17, 19.0, 19.8, k * 6 - 0.4, k * 6 + 0.4))
	# Gable ends at z = +-28 (the boxed overhang), fascia along the eaves, bargeboards.
	for sz in (-1, 1):
		zz = sz * 28
		pts = [(-24, 20), (24, 20), (0, 30)]
		acc.add("Gable", "Timber", pZ(pts, min(zz, zz + sz * 0.12), max(zz, zz + sz * 0.12)))
		for sx in (-1, 1):
			acc.add("Barge", "TimberDark", beam((sx * 24.6, 19.75, zz + sz * 0.3), (sx * 0.35, 30.1, zz + sz * 0.3), 0.36, 0.7))
		acc.add("Finial", "TimberDark", RB(-0.4, 0.4, 29.3, 31.2, min(zz + sz * 0.05, zz + sz * 0.56), max(zz + sz * 0.05, zz + sz * 0.56)))
	for sx in (-1, 1):
		acc.add("Barge", "TimberDark", RB(min(sx * 24, sx * 24.32), max(sx * 24, sx * 24.32), 19.4, 20.25, -28.35, 28.35))
	# Roof: two slabs on the collision slope (eave 20 at x = +-24, ridge 30), standing proud of it, snow on top.
	for sx in (-1, 1):
		e = sx * 24.6
		slab = [(0, 30.0), (e, 19.75), (e, 20.35), (0, 30.62)]
		acc.add("Roof", "RoofSlate", pZ([(p[0], p[1]) for p in (slab if sx > 0 else slab[::-1])], -28.6, 28.6))
		snow = [(0, 30.62), (sx * 24.2, 20.5), (sx * 24.75, 20.75), (sx * 24.55, 21.25), (0, 31.4)]
		acc.add("RoofSnow", "Snow", pZ(snow if sx > 0 else snow[::-1], -28.3, 28.3))
	# Sign board on each gable (the name is a SurfaceGui in Art.luau), lanterns by the main doors.
	for sz in (-1, 1):
		acc.add("Sign", "TimberDark", RB(-7, 7, 22.4, 25.0, min(sz * 28.12, sz * 28.32), max(sz * 28.12, sz * 28.32)))
		for xx in (-7.2, 7.2):
			zz = sz * (Z + 6.0)
			acc.add("Lantern", "Iron", RB(min(xx - 0.4, 5.98 if xx > 0 else -7.6), max(xx + 0.4, 7.6 if xx > 0 else -5.98), 7.4, 7.6, min(zz - sz * 0.9, zz - sz * 0.05), max(zz - sz * 0.9, zz - sz * 0.05)))  # v2: bracket reaches the porch wall (0.05 off its end face)
	for sz in (-1, 1):
		for xx in (-6.6, 6.6):
			z0 = sz * (Z + 5.2)
			acc.add("Lantern_Glow", "Glow_Warm", RB(xx - 0.3, xx + 0.3, 6.5, 7.4, min(z0, z0 + sz * 0.6), max(z0, z0 + sz * 0.6)))
	# Icicles hanging from the eave fascia (y 19.75), long and short, never closer than 0.6.
	rng = random.Random(41)
	for sx in (-1, 1):
		z = -27.6
		while z < 27.6:
			ln = rng.choice((0.6, 0.9, 1.3, 1.8, 0.7, 2.2))
			acc.add("Icicles", "Ice", icicle(sx * 24.45, 19.85, z, ln, 0.16 + 0.05 * ln))
			z += rng.uniform(0.7, 1.4)
	return piece("Lodge", acc, mats, kit)


def icicle(x, y, z, ln, r):
	"""A 4-sided icicle hanging from (x, y, z): base square r, tip ln below (built in Roblox terms)."""
	bm = bmesh.new()
	b = [bm.verts.new(rb((x + dx, y, z + dz))) for dx, dz in ((r, 0), (0, r), (-r, 0), (0, -r))]
	tip = bm.verts.new(rb((x, y - ln, z)))
	bm.faces.new(b)
	for i in range(4):
		bm.faces.new((b[(i + 1) % 4], b[i], tip))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	return bm


def p_fireplace(mats, kit):
	acc = Acc()
	st = []
	# Hearth x -5..5, z -3..3, y 0..12 with a 1.2-deep firebox on both faces (x -2.5..2.5, y 1..5).
	st.append(RB(-5, -2.5, 0, 12, -3, 3))
	st.append(RB(2.5, 5, 0, 12, -3, 3))
	st.append(RB(-2.5, 2.5, 5, 12, -3, 3))
	st.append(RB(-2.5, 2.5, 0, 1, -3, 3))
	st.append(RB(-2.5, 2.5, 1, 5, -1.8, 1.8))
	acc.add("Stone", "Stone", *st)
	# Chimney 12..34 (6 x 6), a dark cap above.
	acc.add("Chimney", "Stone", RB(-3, 3, 12, 34, -3, 3))
	acc.add("Cap", "StoneDark", RB(-3.5, 3.5, 34, 34.6, -3.5, 3.5), RB(-1.2, 1.2, 34.6, 35.6, -1.2, 1.2))
	for sz in (-1, 1):
		f = sz * 3
		acc.add("Mantel", "TimberDark", RB(-4.4, 4.4, 5.9, 6.6, min(f, f + sz * 0.7), max(f, f + sz * 0.7)))
		acc.add("Firebox", "StoneDark", RB(-2.5, 2.5, 1.0, 1.08, min(sz * 1.8, sz * 3.0), max(sz * 1.8, sz * 3.0)))
		logs = [rod((-1.6, 1.4, sz * 2.4), (1.6, 1.4, sz * 2.4), 0.32, 6), rod((-1.2, 1.9, sz * 2.2), (1.4, 1.75, sz * 2.6), 0.28, 6)]
		acc.add("Logs", "Bark", *logs)
		acc.add("Fire_Glow", "Glow_Fire", RB(-1.8, 1.8, 1.08, 1.3, min(sz * 1.9, sz * 2.9), max(sz * 1.9, sz * 2.9)), K.place(prism([(-1.2, 0), (1.2, 0), (0, 2.2)], "Y", -0.15, 0.15), Matrix.Translation(rb((0, 1.6, sz * 2.3)))))
	return piece("Fireplace", acc, mats, kit)


def p_lodge_inside(mats, kit):
	# The B half (z > 0) of the interior; Art.luau places it twice (yaw 0 and 180).
	acc = Acc()
	loft = [b for b in L.HALF if b.name == "Loft"][0]
	acc.add("LoftFloor", "Oak", bx(loft, y0=9.4))
	for k in range(6):
		xx = -15 + 6 * k
		if abs(xx - 6) < 1.5 or abs(xx + 6) < 1.5:
			continue  # over the back bar / boot wall
		acc.add("LoftBeams", "TimberDark", RB(xx - 0.35, xx + 0.35, 8.6, 9.4, 13.65, 21.0))
	acc.add("LoftBeams", "TimberDark", RB(-17, 17, 8.4, 9.4, 12.95, 13.65))
	for b in [b for b in L.HALF if b.name == "Loft rail"]:
		board_rail(b.x0, b.x1, b.z0, b.z1, b.y0, b.top, acc, panel="Oak", cap="TimberDark", post_every=3)
	bb = [b for b in L.HALF if b.name == "Back bar"][0]
	# Back bar: a timber cabinet to the loft (x -7..-5), shelves of bottles on its west (bar) face.
	acc.add("BackBar", "TimberDark", bx(bb))
	for y in (3.4, 5.0, 6.6):
		acc.add("Shelves", "Oak", RB(bb.x0 - 0.45, bb.x0, y - 0.12, y, bb.z0 + 0.6, bb.z1 - 0.4))
		rnd = random.Random(int(y * 10))
		zz = bb.z0 + 0.9
		while zz < bb.z1 - 0.8:
			hgt = rnd.uniform(0.7, 1.05)
			acc.add("Bottles", "Bottle", vcyl(bb.x0 - 0.25, zz, 0.13, y, y + hgt, segs=6))
			zz += rnd.uniform(0.32, 0.5)
	acc.add("Mirror", "Glass", RB(bb.x0 - 0.06, bb.x0 - 0.02, 7.2, 8.5, bb.z0 + 1.0, bb.z1 - 1.0))
	bw = [b for b in L.HALF if b.name == "Boot wall"][0]
	acc.add("BootWall", "Timber", bx(bw))
	for k in range(4):
		zz = bw.z0 + 1.0 + k * 1.8
		acc.add("Lockers", "Steel", RB(bw.x1, bw.x1 + 0.3, 0.3, 6.2, zz, zz + 1.6))
	bc = [b for b in L.HALF if b.name == "Bar counter"][0]
	acc.add("Counter", "Oak", bx(bc, y1=3.2))
	acc.add("CounterTop", "TimberDark", RB(bc.x0 - 0.35, bc.x1 + 0.05, 3.2, 3.5, bc.z0 - 0.15, bc.z1 - 0.02))
	acc.add("FootRail", "Brass", rod((bc.x0 - 0.3, 0.6, bc.z0 + 0.2), (bc.x0 - 0.3, 0.6, bc.z1 - 0.2), 0.08), *[rod((bc.x0 - 0.3, -0.05, zz), (bc.x0 - 0.3, 0.62, zz), 0.06) for zz in (bc.z0 + 0.5, bc.z1 - 0.5)])
	for zz in (bc.z0 + 1.0, bc.z0 + 2.6, bc.z0 + 4.2):
		acc.add("Stools", "Iron", vcyl(bc.x0 - 1.3, zz, 0.08, 0, 2.3, segs=6))
		acc.add("StoolSeats", "Leather", vcyl(bc.x0 - 1.3, zz, 0.5, 2.3, 2.6, segs=10))
	so = [b for b in L.HALF if b.name == "Sofa"][0]
	# Sofa facing the fire (south): base, seat, back on the north side, arms.
	acc.add("Sofa", "Fabric", RB(so.x0 + 0.5, so.x1 - 0.5, 0.25, 1.5, so.z0, so.z1 - 0.6, ch=0.12), RB(so.x0 + 0.5, so.x1 - 0.5, 0.25, 3.0, so.z1 - 0.6, so.z1, ch=0.12), RB(so.x0, so.x0 + 0.5, 0.25, 2.2, so.z0, so.z1, ch=0.12), RB(so.x1 - 0.5, so.x1, 0.25, 2.2, so.z0, so.z1, ch=0.12))
	acc.add("SofaFeet", "TimberDark", *[RB(x - 0.15, x + 0.15, 0, 0.25, z - 0.15, z + 0.15) for x in (so.x0 + 0.3, so.x1 - 0.3) for z in (so.z0 + 0.3, so.z1 - 0.3)])
	acc.add("Rug", "Rug", RB(-6.5, 6.5, 0, 0.05, 3.4, 8.2))
	# Iron chandelier over the lounge (z 6), candles glowing.
	ring = []
	for i in range(8):
		a0, a1 = 2 * math.pi * i / 8, 2 * math.pi * (i + 1) / 8
		a0, a1 = a0 + 0.03, a1 - 0.03
		ring.append(beam((2.2 * math.cos(a0) + 9, 14.5, 2.2 * math.sin(a0) + 6), (2.2 * math.cos(a1) + 9, 14.5, 2.2 * math.sin(a1) + 6), 0.18, 0.18))
	ring.append(rod((9, 14.5, 6), (9, 19.0, 6), 0.06))
	acc.add("Chandelier", "Iron", *ring)
	acc.add("Candles_Glow", "Glow_Warm", *[RB(9 + 2.2 * math.cos(a) - 0.1, 9 + 2.2 * math.cos(a) + 0.1, 14.6, 15.1, 6 + 2.2 * math.sin(a) - 0.1, 6 + 2.2 * math.sin(a) + 0.1) for a in [2 * math.pi * k / 8 + math.pi / 8 for k in range(8)]])
	return piece("LodgeInside", acc, mats, kit)


# ---------------------------------------------------------------- stairs (6 x 16, rising 10 toward +Z)

def stair(name, tread, side, mats, kit, rail=None, n=13, nosing=None):
	acc = Acc()
	rise, run = 10.0 / n, 16.0 / n
	for sx in (-1, 1):
		x0, x1 = (-3.0, -2.75) if sx < 0 else (2.75, 3.0)
		acc.add("Stringers", side, prismX_tri(x0, x1))
	tr = []
	for i in range(n):
		z0 = -8 + i * run
		tr.append(RB(-2.75, 2.75, i * rise, (i + 1) * rise, z0, z0 + run))
	acc.add("Treads", tread, *tr)
	if nosing:
		acc.add("Nosing", nosing, *[RB(-2.7, 2.7, (i + 1) * rise - 0.12, (i + 1) * rise + 0.06, -8 + i * run - 0.06, -8 + i * run + 0.3) for i in range(n)])
	if rail:
		r = []
		for sx in (-1, 1):
			x = sx * 2.88
			for t in (0.04, 0.35, 0.66, 0.97):
				z, y = -8 + 16 * t, 10 * t + 0.6
				r.append(rod((x, y - 1.1, z), (x, y + 3.2, z), 0.08))  # v2: posts reach the stringer (they floated 1 stud)
			r.append(rod((x, 3.8, -7.4), (x, 13.4, 7.6), 0.1))
		acc.add("Rails", rail, *r)
	return piece(name, acc, mats, kit)


def prismX_tri(x0, x1):
	# Side panel of a closed stair: the triangle under the slope (z -8..8, y 0..10).
	return pX([(-8, 0), (8, 0), (8, 10)], x0, x1)


# ---------------------------------------------------------------- station, cabin, line

def st_local(b):
	ox, oz = STATION_O
	return (b.x0 - ox, b.x1 - ox, b.y0, b.top, b.z0 - oz, b.z1 - oz)


def p_station(mats, kit):
	acc = Acc()
	ox, oz = STATION_O
	B = [b for b in L.HALF if b.piece == "Station"]
	for b in B:
		x0, x1, y0, y1, z0, z1 = st_local(b)
		if b.kind in ("base", "slab"):
			acc.add("Base", "Stone", RB(x0, x1, y0, y1, z0, z1))  # r3: fieldstone base, as the concept (was plain concrete)
		elif b.name == "Bullwheel housing":
			acc.add("Housing", "Steel", RB(x0, x1, y0, y1, z0, z1))
			for y in (12.0, 14.0, 16.0):
				acc.add("Louvres", "SteelDark", RB(x1, x1 + 0.12, y, y + 0.7, z0 + 1.5, z1 - 1.5))
		elif b.kind == "rail":
			acc.add("Rails", "Steel", RB(x0, x1, y0 + 2.55, y1, z0, z1))
			along_x = (x1 - x0) > (z1 - z0)
			m = 0.18
			acc.add("RailMesh", "SteelDark", RB(x0, x1, y0, y0 + 2.55, z0 + m, z1 - m) if along_x else RB(x0 + m, x1 - m, y0, y0 + 2.55, z0, z1))
		elif b.kind == "post":
			acc.add("Columns", "TimberDark", RB(x0, x1, y0, y1, z0, z1))  # r3: timber posts (the lodge family)
		elif b.kind == "roofflat":
			acc.add("Roof", "RoofSlate", RB(x0, x1, y0, y1, z0, z1))  # r3: standing-seam roof
			acc.add("RoofSnow", "Snow", RB(x0 + 0.4, x1 - 0.4, y1, y1 + 0.8, z0 + 0.4, z1 - 0.4, ch=0.3))
			acc.add("Paint", "Paint", RB(x0 - 0.1, x1 + 0.1, y0 + 0.35, y0 + 1.15, z0 - 0.1, z0), RB(x0 - 0.1, x1 + 0.1, y0 + 0.35, y0 + 1.15, z1, z1 + 0.1), RB(x1, x1 + 0.1, y0 + 0.35, y0 + 1.15, z0, z1), RB(x0 - 0.1, x0, y0 + 0.35, y0 + 1.15, z0, z1))
	# Paint band round the concrete base (proud 0.1) and steel frames round the garage mouths.
	acc.add("Paint", "Paint", RB(-12, -6.4, 6.6, 7.4, -12.1, -12), RB(2.4, 12, 6.6, 7.4, -12.1, -12), RB(-12, 5.9, 6.6, 7.4, 12, 12.1), RB(12, 12.1, 6.6, 7.4, -12, -0.4), RB(12, 12.1, 6.6, 7.4, 6.4, 12))
	acc.add("GarageFrame", "SteelDark", RB(-6.4, -5.95, 0, 7.95, -12.3, -12), RB(1.95, 2.4, 0, 7.95, -12.3, -12), RB(-6.4, 2.4, 7.95, 8.4, -12.3, -12), RB(12, 12.3, 0, 7.95, -0.4, 0.05), RB(12, 12.3, 0, 7.95, 5.95, 6.4), RB(12, 12.3, 7.95, 8.4, -0.4, 6.4))
	acc.add("GarageRail", "SteelDark", RB(-2.3, -1.7, 7.4, 8.0, -12, 6), RB(-1.7, 12, 7.4, 8.0, 2.7, 3.3))
	# Bullwheel (horizontal, over the housing) and the overhead rail the parked cabin hangs from.
	acc.add("Bullwheel", "Red", K.place(prism(ring_pts(0, 0, 4.5, 24, 0), "Z", 18.35, 18.95), Matrix.Translation(rb((-9.5, 0, 1)))))  # r3: the concept's red bullwheel
	acc.add("BullwheelHub", "SteelDark", vcyl(-9.5, 1, 1.2, 18.95, 19.6, segs=12))
	acc.add("OverheadRail", "SteelDark", RB(-9.0, 9.5, 19.0, 19.5, -2.25, -1.75))
	acc.add("OverheadRail", "SteelDark", *[RB(x - 0.15, x + 0.15, 19.5, 20.0, -2.15, -1.85) for x in (-6.0, 0.0, 6.0)])
	# Station sign board on the roof edge (text is a SurfaceGui in Art.luau).
	acc.add("Sign", "SteelDark", RB(-8, 8, 21.5, 24.0, -13.25, -12.95), RB(-8, 8, 21.5, 24.0, 12.95, 13.25))
	acc.add("Lamps_Glow", "Glow_Warm", *[RB(x - 0.6, x + 0.6, 19.7, 19.85, z - 0.6, z + 0.6) for x in (-2.0, 7.0) for z in (-8.0, 8.0)])
	acc.add("LampHangers", "SteelDark", *[RB(x - 0.7, x + 0.7, 19.85, 20.05, z - 0.7, z + 0.7) for x in (-2.0, 7.0) for z in (-8.0, 8.0)])  # v2: lamp shades set into the roof slab (the lamps floated under it)
	return piece("Station", acc, mats, kit)


def cabin_parts(acc, m=Matrix.Identity(4), arm=True):
	def P(bm):
		return K.place(bm, m)

	acc.add("CabinBody", "Red", P(RB(-2.9, 2.9, 0.3, 6.8, -2.9, 2.9, ch=0.5)))
	acc.add("CabinRoof", "White", P(RB(-2.6, 2.6, 6.8, 7.6, -2.6, 2.6, ch=0.3)))
	win = []
	for s in (-1, 1):
		win.append(P(RB(-2.2, 2.2, 3.6, 6.2, min(s * 2.9, s * 2.96), max(s * 2.9, s * 2.96))))
		win.append(P(RB(min(s * 2.9, s * 2.96), max(s * 2.9, s * 2.96), 3.6, 6.2, -2.2, 2.2)))
	acc.add("CabinGlass", "CabGlass", *win)
	acc.add("CabinStripe", "White", *[P(RB(-2.2, 2.2, 1.3, 1.7, min(s * 2.9, s * 2.95), max(s * 2.9, s * 2.95))) for s in (-1, 1)])
	if arm:
		acc.add("CabinArm", "SteelDark", P(RB(-0.3, 0.3, 7.6, 9.2, -0.3, 0.3)), P(RB(-0.8, 0.8, 9.2, 9.8, -0.5, 0.5)))


def p_cabin(mats, kit):
	acc = Acc()
	cabin_parts(acc)
	return piece("Cabin", acc, mats, kit)


LINE_DIR = (-math.cos(math.radians(45)), math.sin(math.radians(45)))  # station local: out over the edge and up the ridge
WHEEL = (-9.5, 18.65, 1.0)


def line_supports():
	# Station-local supports along the line: (s, height). Ground from range_h at the B placement.
	ox, oz = STATION_O
	pts = [(0.0, WHEEL[1])]
	for s in (70.0, 160.0, 250.0, 340.0):
		x, z = WHEEL[0] + LINE_DIR[0] * s, WHEEL[2] + LINE_DIR[1] * s
		g = range_surface(ox + x, oz + z)
		pts.append((s, g + 30.0))
	s = 440.0
	x, z = WHEEL[0] + LINE_DIR[0] * s, WHEEL[2] + LINE_DIR[1] * s
	pts.append((s, range_surface(ox + x, oz + z) + 14.0))
	return pts


def cable_y(sup, s):
	for (s0, y0), (s1, y1) in zip(sup, sup[1:]):
		if s0 <= s <= s1:
			t = (s - s0) / (s1 - s0)
			return y0 + (y1 - y0) * t - 4 * 0.03 * (s1 - s0) * t * (1 - t)
	return sup[-1][1]


def p_line(mats, kit):
	acc = Acc()
	sup = line_supports()
	ox, oz = STATION_O
	px, pz = LINE_DIR[1], -LINE_DIR[0]  # perpendicular (x, z)
	cab = []
	for side in (-1, 1):
		pts = []
		s = 0.0
		while s <= sup[-1][0] + 1e-6:
			x = WHEEL[0] + LINE_DIR[0] * s + side * 4.5 * px
			z = WHEEL[2] + LINE_DIR[1] * s + side * 4.5 * pz
			pts.append((x, cable_y(sup, s), z))
			s += 10.0
		acc.add("Cable", "SteelDark", tube(pts, 0.14, 5))
		for k, s in enumerate(range(60, int(sup[-1][0]) - 30, 85)):
			s = s + (40 if side > 0 else 0)
			if s > sup[-1][0] - 45:
				continue
			x = WHEEL[0] + LINE_DIR[0] * s + side * 4.5 * px
			z = WHEEL[2] + LINE_DIR[1] * s + side * 4.5 * pz
			y = cable_y(sup, s) - 9.8
			yaw = math.degrees(math.atan2(LINE_DIR[0], LINE_DIR[1]))
			cab.append(Matrix.Translation(rb((x, y, z))) @ Matrix.Rotation(math.radians(yaw), 4, "Z"))
	for m in cab:
		cabin_parts(acc, m)
	# Pylons: a tapered tube, a crossarm with sheave trains at both cables.
	for s, y in sup[1:-1]:
		x, z = WHEEL[0] + LINE_DIR[0] * s, WHEEL[2] + LINE_DIR[1] * s
		g = range_surface(ox + x, oz + z)
		acc.add("Pylon", "Steel", K.place(prism(ring_pts(0, 0, 1.6, 8, 0), "Z", g - 2.5, y - 2.5), Matrix.Translation(rb((x, 0, z)))), vcyl(x, z, 2.6, g - 8, g + 1.0, segs=8))
		acc.add("Pylon", "Steel", beam((x - 5.6 * px, y - 2.5, z - 5.6 * pz), (x + 5.6 * px, y - 2.5, z + 5.6 * pz), 1.2, 1.4))
		for side in (-1, 1):
			cx, cz = x + side * 4.5 * px, z + side * 4.5 * pz
			acc.add("Sheaves", "SteelDark", beam((cx - 2.5 * LINE_DIR[0], y - 0.6, cz - 2.5 * LINE_DIR[1]), (cx + 2.5 * LINE_DIR[0], y - 0.6, cz + 2.5 * LINE_DIR[1]), 0.5, 1.0))
		acc.add("PylonPaint", "Red", K.place(prism(ring_pts(0, 0, 1.68, 8, 0), "Z", y - 6.0, y - 4.6), Matrix.Translation(rb((x, 0, z)))))
	# Summit station on the peak: a concrete hall with a roof and a lit window band.
	s, y = sup[-1]
	x, z = WHEEL[0] + LINE_DIR[0] * s, WHEEL[2] + LINE_DIR[1] * s
	g = range_surface(ox + x, oz + z)
	yaw = math.degrees(math.atan2(LINE_DIR[0], LINE_DIR[1]))
	m = Matrix.Translation(rb((x, g, z))) @ Matrix.Rotation(math.radians(yaw), 4, "Z")
	acc.add("Summit", "Concrete", K.place(RB(-11, 11, -8, 12, -9, 9), m.copy()))
	acc.add("SummitRoof", "Snow", K.place(RB(-12, 12, 12, 14, -10, 10, ch=0.5), m.copy()))
	acc.add("Summit_Glow", "Glow_Warm", K.place(RB(-9, 9, 7, 9, -9.1, -9.0), m.copy()))
	return piece("Line", acc, mats, kit)


# ---------------------------------------------------------------- huts and props

def hut(name, w, d, h, wall_h, mats, kit, door_side=1, windows=(), sign=None, logs_front=False, hatch=False):
	# A timber hut filling its greybox box: walls on the footprint, gable roof (ridge along X) up to h, snow on it.
	acc = Acc()
	hx, hz = w / 2, d / 2
	if logs_front:
		# Woodshed: three timber walls, the -Z side stacked full of logs.
		acc.add("Walls", "Timber", RB(-hx, hx, 0, wall_h, hz - 0.6, hz), RB(-hx, -hx + 0.6, 0, wall_h, -hz, hz - 0.6), RB(hx - 0.6, hx, 0, wall_h, -hz, hz - 0.6))
		acc.add("Back", "TimberDark", RB(-hx + 0.6, hx - 0.6, 0, wall_h, -hz + 1.2, hz - 0.6))
		lg = []
		r = 0.42
		y = r
		row = 0
		while y + r <= wall_h:
			x = -hx + 0.6 + r + (r if row % 2 else 0)
			while x + r <= hx - 0.6:
				lg.append(pZ(ring_pts(x, y, r, 6, row * 0.3), -hz - 0.02, -hz + 1.2))
				x += 2 * r
			y += 2 * r * 0.88
			row += 1
		acc.add("Logs", "Bark", *lg)
	else:
		acc.add("Walls", "Timber", RB(-hx, hx, 0, wall_h, -hz, hz))
		acc.add("Plinth", "Stone", RB(-hx - 0.2, hx + 0.2, 0, 1.4, -hz - 0.2, hz + 0.2))
		for sx in (-1, 1):
			for sz in (-1, 1):
				acc.add("Corners", "TimberDark", RB(min(sx * hx, sx * (hx + 0.25)), max(sx * hx, sx * (hx + 0.25)), 1.4, wall_h, min(sz * (hz - 0.35), sz * (hz + 0.25)), max(sz * (hz - 0.35), sz * (hz + 0.25))))
	# Gables and roof.
	rise = h - wall_h - 0.5
	gab = []
	for sxs in (-1, 1):
		gab.append(pX([(-hz, wall_h), (hz, wall_h), (0, wall_h + rise)], min(sxs * hx, sxs * (hx - 0.6)), max(sxs * hx, sxs * (hx - 0.6))))
	acc.add("Gables", "Timber", *gab)
	ov = 0.6
	for sz in (-1, 1):
		e = sz * (hz + ov)
		slab = [(0, wall_h + rise), (e, wall_h - ov * rise / hz), (e, wall_h - ov * rise / hz + 0.4), (0, wall_h + rise + 0.4)]
		acc.add("Roof", "RoofSlate", pX(slab if sz < 0 else slab[::-1], -hx - ov, hx + ov))
		sn = [(0, wall_h + rise + 0.4), (sz * (hz + ov - 0.3), wall_h - ov * rise / hz + 0.4), (sz * (hz + ov - 0.15), wall_h - ov * rise / hz + 0.75), (0, wall_h + rise + 1.0)]
		acc.add("RoofSnow", "Snow", pX(sn if sz < 0 else sn[::-1], -hx - ov + 0.25, hx + ov - 0.25))
	if not logs_front:
		zd = door_side * hz
		acc.add("Door", "TimberDark", RB(-1.6, 1.6, 0, 6.6 if wall_h > 7 else min(6.2, wall_h - 0.6), min(zd, zd + door_side * 0.12), max(zd, zd + door_side * 0.12)))
		for (wx, side) in windows:
			zw = side * hz
			acc.add("WinFrames", "TimberDark", RB(wx - 1.5, wx + 1.5, 2.8, 5.6, min(zw - side * 0.05, zw + side * 0.14), max(zw - side * 0.05, zw + side * 0.14)))
			acc.add("Win_Glow", "Glow_Warm", RB(wx - 1.2, wx + 1.2, 3.1, 5.3, min(zw - side * 0.1, zw + side * 0.18), max(zw - side * 0.1, zw + side * 0.18)))
			acc.add("Shutters", "Shutter", RB(wx - 2.9, wx - 1.6, 2.8, 5.6, min(zw + side * 0.02, zw + side * 0.1), max(zw + side * 0.02, zw + side * 0.1)), RB(wx + 1.6, wx + 2.9, 2.8, 5.6, min(zw + side * 0.02, zw + side * 0.1), max(zw + side * 0.02, zw + side * 0.1)))
		if hatch:
			acc.add("Hatch", "Shutter", RB(-2.6, 2.6, 3.2, 5.4, -hz - 0.14, -hz))
			acc.add("HatchLedge", "TimberDark", RB(-2.8, 2.8, 3.0, 3.2, -hz - 0.7, -hz))
			acc.add("Paint", "Paint", RB(-3.0, 3.0, 5.6, 5.9, -hz - 1.0, -hz))
	if sign:
		zs = sign * (hz + 0.03)
		acc.add("Paint", "Paint", RB(-min(4.5, hx - 1), min(4.5, hx - 1), wall_h - 0.9, wall_h - 0.15, min(zs, zs + sign * 0.18), max(zs, zs + sign * 0.18)))
	return piece(name, acc, mats, kit)


def p_woodpile(name, w, d, h, mats, kit, back_gap=0.0):
	# Logs along Z stacked full, posts and a small snowy lean-to roof. back_gap: air gap on the -Z side (a wall).
	acc = Acc()
	hx, hz = w / 2, d / 2
	zb = -hz + back_gap
	acc.add("Core", "TimberDark", RB(-hx + 0.3, hx - 0.3, 0, h - 1.0, zb + 0.3, hz - 0.3))
	lg = []
	r = 0.4
	for side in (-1, 1):
		y, row = r, 0
		while y + r <= h - 1.0:
			x = -hx + 0.35 + r + (r if row % 2 else 0)
			while x + r <= hx - 0.35:
				z0, z1 = (hz - 0.35, hz) if side > 0 else (zb, zb + 0.35)
				lg.append(pZ(ring_pts(x, y, r, 6, row * 0.4), z0, z1))
				x += 2 * r
			y += 2 * r * 0.9
			row += 1
	acc.add("Logs", "Bark", *lg)
	acc.add("Posts", "TimberDark", *[RB(sx * hx - (0.35 if sx > 0 else 0), sx * hx + (0.35 if sx < 0 else 0), 0, h - 0.6, zb, hz) for sx in (-1, 1)])
	acc.add("Roof", "TimberDark", RB(-hx, hx, h - 0.6, h - 0.3, zb, hz))
	acc.add("RoofSnow", "Snow", RB(-hx + 0.1, hx - 0.1, h - 0.3, h, zb + 0.1, hz - 0.1, ch=0.12))
	return piece(name, acc, mats, kit)


def heightfield_block(x0, x1, z0, z1, top, seed, lump=0.45, edge=1.0, cell=0.8):
	# A ploughed snow block filling x0..x1, z0..z1 up to `top`: steep blade-cut sides, a lumpy rounded top.
	nx = max(4, int((x1 - x0) / cell))
	nz = max(4, int((z1 - z0) / cell))
	bm = bmesh.new()
	grid = []
	for i in range(nx + 1):
		row = []
		for j in range(nz + 1):
			x = x0 + (x1 - x0) * i / nx
			z = z0 + (z1 - z0) * j / nz
			de = min(x - x0, x1 - x, z - z0, z1 - z)
			fall = smooth(0, edge, de)
			y = top - lump * 0.5 + lump * (vnoise(x * 0.35, z * 0.35, seed) - 0.5) * 2 * 0.5
			y = 0.55 * top + (y - 0.55 * top) * (0.35 + 0.65 * fall)
			row.append(bm.verts.new(rb((x, y, z))))
		grid.append(row)
	for i in range(nx):
		for j in range(nz):
			bm.faces.new((grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]))
	# skirt down to y = 0 and a bottom
	ring = [grid[i][0] for i in range(nx + 1)] + [grid[nx][j] for j in range(1, nz + 1)] + [grid[i][nz] for i in range(nx - 1, -1, -1)] + [grid[0][j] for j in range(nz - 1, 0, -1)]
	low = [bm.verts.new((v.co.x, v.co.y, 0.0)) for v in ring]
	n = len(ring)
	for k in range(n):
		bm.faces.new((ring[k], low[k], low[(k + 1) % n], ring[(k + 1) % n]))
	bm.faces.new(low[::-1])
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	return bm


def p_snowpile(name, w, d, mats, kit, seed):
	acc = Acc()
	acc.add("Snow", "Snow", heightfield_block(-w / 2, w / 2, -d / 2, d / 2, 8.25, seed, lump=0.9, edge=1.2))
	return piece(name, acc, mats, kit)


def rock_box(w, d, h, seed, y0=0.0):
	# A faceted rock that fills a w x d x h box (flat base), as a convex hull of jittered points on the box.
	rnd = random.Random(seed)
	bm = bmesh.new()
	vs = []
	for _ in range(46):
		u = [rnd.uniform(-1, 1) for _ in range(3)]
		k = rnd.randrange(3)
		u[k] = 1 if rnd.random() < 0.5 else -1
		if k == 1 and u[1] < 0:
			u[1] = -1
		inset = rnd.uniform(0.0, 0.22)
		x = u[0] * (w / 2) * (1 - inset * (abs(u[0]) > 0.98 or k == 0))
		z = u[2] * (d / 2) * (1 - inset * (abs(u[2]) > 0.98 or k == 2))
		y = y0 + (u[1] + 1) / 2 * h * (1 - (inset if k == 1 and u[1] > 0 else 0) * 0.6)
		x = max(-w / 2 - 0.15, min(w / 2 + 0.15, x * (1 - 0.25 * max(0, (y - y0) / h - 0.6))))
		z = max(-d / 2 - 0.15, min(d / 2 + 0.15, z * (1 - 0.25 * max(0, (y - y0) / h - 0.6))))
		vs.append(bm.verts.new(rb((x, y, z))))
	for x, z in ((-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2), (-w / 2, d / 2)):
		vs.append(bm.verts.new(rb((x * 0.92, y0, z * 0.92))))
	res = bmesh.ops.convex_hull(bm, input=vs)
	junk = list({v for v in res["geom_interior"] + res["geom_unused"] if isinstance(v, bmesh.types.BMVert) and v.is_valid})
	if junk:
		bmesh.ops.delete(bm, geom=junk, context="VERTS")
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	return bm


def snow_cap(rock, lift=0.22):
	# Snow on the upward faces of a rock: those faces, offset up, closed by a thin skirt.
	out = bmesh.new()
	rock.normal_update()
	vmap = {}
	for f in rock.faces:
		if f.normal.z > 0.55:
			vs = []
			for v in f.verts:
				if v.index not in vmap:
					vmap[v.index] = out.verts.new(v.co + Vector((0, 0, lift)))
				vs.append(vmap[v.index])
			try:
				out.faces.new(vs)
			except ValueError:
				pass
	bmesh.ops.solidify(out, geom=out.faces[:], thickness=-0.3)
	return out


def p_rock(name, w, d, h, mats, kit, seed, y0=0.0):
	acc = Acc()
	r = rock_box(w, d, h, seed, y0)
	rock_copy = K.copy(r)
	r.verts.ensure_lookup_table()
	acc.add("Rock", "Rock", r)
	acc.add("Snow", "Snow", snow_cap(rock_copy))
	rock_copy.free()
	return piece(name, acc, mats, kit)


def p_snowcat(mats, kit):
	# 8 wide (x), 14 long (z), 8 tall; blade at -Z, tiller at +Z.
	acc = Acc()
	for sx in (-1, 1):
		x0, x1 = (-4, -2.4) if sx < 0 else (2.4, 4)
		acc.add("Tracks", "Rubber", pX([(-6.2, 0.4), (-5.3, 0), (5.3, 0), (6.2, 0.4), (6.2, 2.4), (5.3, 3.0), (-5.3, 3.0), (-6.2, 2.4)], x0, x1))
		acc.add("Wheels", "SteelDark", *[K.place(prism(ring_pts(0, 0, 0.9, 10, 0), "X", 0, 0.12), Matrix.Translation(rb((x1 if sx > 0 else x0 - 0.12, 1.5, zz)))) for zz in (-4, -1.5, 1, 3.5)])
	acc.add("Body", "Red", RB(-2.4, 2.4, 1.0, 4.4, -6.0, 6.2, ch=0.2), RB(-3.9, 3.9, 3.0, 3.4, -5.8, 6.0))
	acc.add("Cab", "White", RB(-2.6, 2.6, 4.4, 7.6, -2.6, 2.4, ch=0.25))
	acc.add("CabGlass", "CabGlass", RB(-2.4, 2.4, 5.2, 7.2, -2.66, -2.6), RB(-2.66, -2.6, 5.2, 7.2, -2.2, 2.0), RB(2.6, 2.66, 5.2, 7.2, -2.2, 2.0))
	acc.add("Roof", "Red", RB(-2.7, 2.7, 7.6, 7.85, -2.7, 2.5))
	acc.add("Beacon_Glow", "Glow_Amber", RB(-0.35, 0.35, 7.85, 8.0, -0.35, 0.35))
	acc.add("Blade", "Steel", pX([(-7.0, 0.3), (-6.4, 0.3), (-6.0, 1.2), (-6.0, 3.2), (-6.6, 3.6), (-7.0, 3.6)], -3.95, 3.95))
	acc.add("Tiller", "SteelDark", RB(-3.6, 3.6, 0.5, 2.4, 6.2, 7.0, ch=0.15))
	return piece("Snowcat", acc, mats, kit)


def p_trailmap(mats, kit):
	acc = Acc()
	acc.add("Board", "TimberDark", RB(-4, 4, 0.6, 7.6, -0.45, 0.45))
	acc.add("Map", "MapBoard", RB(-3.5, 3.5, 1.4, 7.0, -0.55, -0.45), RB(-3.5, 3.5, 1.4, 7.0, 0.45, 0.55))
	acc.add("Posts", "TimberDark", RB(-4, -3.4, 0, 0.6, -0.4, 0.4), RB(3.4, 4, 0, 0.6, -0.4, 0.4))
	acc.add("Roof", "TimberDark", RB(-4.2, 4.2, 7.6, 7.8, -0.75, 0.75))
	acc.add("RoofSnow", "Snow", RB(-4.1, 4.1, 7.8, 8.05, -0.65, 0.65, ch=0.08))
	return piece("TrailMap", acc, mats, kit)


def p_skirack(mats, kit):
	# 8 x 1.5 x 3: a timber rack with skis lying across it.
	acc = Acc()
	acc.add("Frame", "TimberDark", *[RB(x - 0.2, x + 0.2, 0, 2.6, -0.75, 0.75) for x in (-3.8, 0, 3.8)])
	acc.add("Frame", "TimberDark", RB(-4, 4, 2.6, 3.0, -0.75, 0.75))
	acc.add("Rails", "Timber", RB(-3.95, 3.95, 1.0, 1.3, -0.6, 0.6))
	cols = ["Red", "Paint", "White", "Shutter"]
	for k, x in enumerate((-3.2, -2.2, -1.2, 0.8, 1.8, 2.8)):
		acc.add("Skis", cols[k % 4] if cols[k % 4] != "Paint" else "Steel", RB(x - 0.18, x + 0.18, 1.3, 1.42, -0.74, 0.74))
	return piece("SkiRack", acc, mats, kit)


def p_firepit(mats, kit):
	acc = Acc()
	acc.add("Stone", "Stone", vcyl(0, 0, 3.0, 0, 2.1, segs=16))
	acc.add("Rim", "StoneDark", vcyl(0, 0, 3.0, 2.1, 2.5, segs=16))
	acc.add("Ash", "StoneDark", vcyl(0, 0, 2.2, 2.5, 2.56, segs=12))
	acc.add("Logs", "Bark", rod((-1.3, 2.75, -0.4), (1.3, 2.75, 0.5), 0.25), rod((-0.8, 2.75, 1.1), (0.9, 2.75, -1.0), 0.25))
	acc.add("Embers_Glow", "Glow_Fire", K.place(prism([(-0.9, 0), (0.9, 0), (0, 1.6)], "Y", -0.12, 0.12), Matrix.Translation(rb((0, 2.55, 0)))))
	return piece("FirePit", acc, mats, kit)


def p_parapet(mats, kit):
	# 8 long (z), 2 thick (x), 3 tall: stone wall to 2.2, a timber cap rail, snow along the top.
	acc = Acc()
	acc.add("Wall", "Stone", RB(-1, 1, 0, 2.2, -4, 4))
	acc.add("Cap", "TimberDark", RB(-1, 1, 2.2, 2.75, -4, 4))
	acc.add("Snow", "Snow", RB(-0.85, 0.85, 2.75, 3.0, -3.98, 3.98, ch=0.1))
	return piece("Parapet8", acc, mats, kit)


def p_lamp(mats, kit):
	acc = Acc()
	acc.add("Post", "TimberDark", RB(-0.25, 0.25, 0, 8.0, -0.25, 0.25), RB(-0.45, 0.45, 0, 0.8, -0.45, 0.45))
	acc.add("Head", "Iron", RB(-0.55, 0.55, 8.0, 8.15, -0.55, 0.55), RB(-0.65, 0.65, 9.35, 9.6, -0.65, 0.65))
	acc.add("Lamp_Glow", "Glow_Warm", RB(-0.42, 0.42, 8.15, 9.35, -0.42, 0.42))
	acc.add("Snow", "Snow", RB(-0.6, 0.6, 9.6, 9.8, -0.6, 0.6, ch=0.08))
	return piece("LampPost", acc, mats, kit)


def p_pond_rim(mats, kit):
	# A snow lip round the ice (pond 28 x 40, 0.4 below the snow): rounded inner corners hide the ice rectangle.
	acc = Acc()
	hx, hz = 14.0, 20.0

	def rr(ax, az, rad, t):
		# point on a rounded rectangle (half sizes ax, az, corner radius rad) at parameter t in [0, 1)
		per = 4 * (ax - rad) + 4 * (az - rad) + 2 * math.pi * rad
		d = t * per
		segs = [("z", ax, -(az - rad), az - rad), ("c", ax - rad, az - rad, 0), ("x", az, ax - rad, -(ax - rad)), ("c", -(ax - rad), az - rad, 1), ("z-", -ax, az - rad, -(az - rad)), ("c", -(ax - rad), -(az - rad), 2), ("x-", -az, -(ax - rad), ax - rad), ("c", ax - rad, -(az - rad), 3)]
		for kind, a, b, c in segs:
			if kind == "c":
				ln = math.pi / 2 * rad
				if d <= ln:
					ang = c * math.pi / 2 + d / rad
					return (a + rad * math.cos(ang), b + rad * math.sin(ang))
				d -= ln
			else:
				ln = abs(c - b)
				if d <= ln:
					s = b + (c - b) * d / ln
					if kind in ("z", "z-"):
						return (a, s)
					return (s, a)
				d -= ln
		return (ax, -(az - rad))

	N = 112
	prof = [(13.0, 19.0, 6.0, -0.36), (14.0, 20.0, 4.5, 0.32), (15.6, 21.6, 3.0, 0.03)]
	rings = []
	bm = bmesh.new()
	for ax, az, rad, y in prof:
		ring = []
		for i in range(N):
			x, z = rr(ax, az, rad, i / N)
			ring.append(bm.verts.new(rb((x, y, z))))
		rings.append(ring)
	lows = []
	for ring, y in ((rings[2], -0.3), (rings[0], -0.55)):
		lows.append([bm.verts.new((v.co.x, v.co.y, y)) for v in ring])
	loop = [rings[0], rings[1], rings[2], lows[0], lows[1]]
	for a, b in zip(loop, loop[1:] + loop[:1]):
		for i in range(N):
			j = (i + 1) % N
			bm.faces.new((a[i], a[j], b[j], b[i]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	acc.add("Rim", "Snow", bm)
	rk = []
	rnd = random.Random(5)
	for i in range(7):
		t = rnd.random()
		x, z = rr(15.0, 21.0, 3.0, t)
		r = rock_box(rnd.uniform(1.0, 2.0), rnd.uniform(1.0, 2.0), rnd.uniform(0.6, 1.2), 40 + i)
		rk.append(mv(r, x, 0.0, z))
	acc.add("Rocks", "RockDark", *rk)
	return piece("PondRim", acc, mats, kit)


def pine_bm(acc, x, z, y, s, seed, rot=0.0):
	rnd = random.Random(seed)
	acc.add("Trunk", "Bark", vcyl(x, z, 0.45 * s, y - 1.0, y + 3.0 * s, segs=6))
	tiers = 4
	for t in range(tiers):
		r = (3.4 - t * 0.7) * s
		y0 = y + (2.2 + t * 3.4) * s
		y1 = y0 + 5.2 * s
		bm = bmesh.new()
		base = [bm.verts.new((x + r * math.cos(rot + t * 0.4 + 2 * math.pi * k / 8), -z + r * math.sin(rot + t * 0.4 + 2 * math.pi * k / 8), y0)) for k in range(8)]
		tip = bm.verts.new((x, -z, y1))
		for k in range(8):
			bm.faces.new((base[k], base[(k + 1) % 8], tip))
		bm.faces.new(base[::-1])
		bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
		acc.add("Needles", "Needles", bm)
		sn = bmesh.new()
		rs = r * 0.62
		ys0 = y0 + (y1 - y0) * 0.42
		sb = [sn.verts.new((x + rs * math.cos(rot + t * 0.4 + 0.2 + 2 * math.pi * k / 8), -z + rs * math.sin(rot + t * 0.4 + 0.2 + 2 * math.pi * k / 8), ys0 + 0.25)) for k in range(8)]
		st = sn.verts.new((x, -z, y1 + 0.18))
		for k in range(8):
			sn.faces.new((sb[k], sb[(k + 1) % 8], st))
		sn.faces.new(sb[::-1])
		bmesh.ops.recalc_face_normals(sn, faces=sn.faces[:])
		acc.add("Snow", "Snow", sn)


def p_pinegrove(mats, kit):
	acc = Acc()
	rnd = random.Random(9)
	for k, (x, z) in enumerate(((0, 0), (7, 3), (-6, 5), (3, -7), (-5, -5), (10, -4), (-10, -2))):
		s = rnd.uniform(0.85, 1.35)
		pine_bm(acc, x, z, 0.0, s, k, rot=rnd.uniform(0, 1))
	return piece("PineGrove", acc, mats, kit)


# ---------------------------------------------------------------- cliffs and the mountains

def displaced(p0, ua, va, nrm, nu, nv, du, dv, depth_fn):
	# Grid surface: p0 + ua * u + va * v + nrm * depth(u, v); returns a bmesh.
	bm = bmesh.new()
	g = []
	for i in range(nu + 1):
		row = []
		for j in range(nv + 1):
			u, v = i * du, j * dv
			d = depth_fn(u, v, i, j)
			p = [p0[k] + ua[k] * u + va[k] * v + nrm[k] * d for k in range(3)]
			row.append(bm.verts.new(rb(p)))
		g.append(row)
	for i in range(nu):
		for j in range(nv):
			bm.faces.new((g[i][j], g[i + 1][j], g[i + 1][j + 1], g[i][j + 1]))
	bm.normal_update()
	out = rb((-nrm[0], -nrm[1], -nrm[2]))
	for f in bm.faces:
		if f.normal.dot(out) < 0:
			f.normal_flip()
	bm.normal_update()
	return bm


def split_by_up(bm, acc, rock_part, snow_part, thresh=0.5):
	# Faces whose normal points up get snow, the rest rock (two parts of one surface, no overlap).
	bm.normal_update()
	snow = [f for f in bm.faces if f.normal.z > thresh]
	sb = K.copy(bm)
	bmesh.ops.delete(bm, geom=snow, context="FACES")
	sb.normal_update()
	bmesh.ops.delete(sb, geom=[f for f in sb.faces if f.normal.z <= thresh], context="FACES")
	acc.add(rock_part, "Rock", bm)
	acc.add(snow_part, "Snow", sb)


def p_cliffs(mats, kit):
	acc = Acc()
	TOP = 76.0
	cell = 2.5

	def face_depth(seed, width):
		def fn(u, v, i, j):
			edge = smooth(0, 4.0, min(u, width - u))
			strata = 0.55 + 0.45 * math.sin(v * 0.7 + vnoise(u * 0.1, v * 0.05, seed) * 3)
			n = vnoise(u * 0.18, v * 0.14, seed) * 0.7 + vnoise(u * 0.5, v * 0.45, seed + 7) * 0.3
			ledge = 0.9 if (int(v / 9.0) % 2 == 0 and (v % 9.0) < 1.2) else 0.0
			return (0.15 + 2.3 * n * strata + ledge) * edge * smooth(0, 3.0, v)
		return fn

	for s in (1, -1):
		faces = []
		# Field faces at z = 80 (x 16..66 and -66..-16), facing the field: recessed toward +z.
		for x0 in (16.0, -66.0):
			faces.append(displaced((x0, 0.0, 80.0), (1, 0, 0), (0, 1, 0), (0, 0, 1), 20, int(TOP / cell), 2.5, cell, face_depth(11 + int(x0), 50.0)))
		# Alcove sides (x = +-16, z 80..100) and back (z = 100).
		faces.append(displaced((16.0, 0.0, 80.0), (0, 0, 1), (0, 1, 0), (1, 0, 0), 8, int(TOP / cell), 2.5, cell, face_depth(31, 20.0)))
		faces.append(displaced((-16.0, 0.0, 100.0), (0, 0, -1), (0, 1, 0), (-1, 0, 0), 8, int(TOP / cell), 2.5, cell, face_depth(37, 20.0)))
		faces.append(displaced((-16.0, 0.0, 100.0), (1, 0, 0), (0, 1, 0), (0, 0, 1), 16, int(TOP / cell), 2.0, cell, face_depth(41, 32.0)))
		for f in faces:
			if s < 0:
				ry(f, 180)
			split_by_up(f, acc, "Rock", "Snow", 0.45)
	return piece("Cliffs", acc, mats, kit)


def range_grid():
	# Ends at 1000: each half is then 1000 x 2000 studs. Roblox caps a mesh at 2048 per axis and shrinks a bigger
	# one to fit on upload (the old 3000-long halves came in at 68 %, so the Range's inner edge hung in the air
	# 240 studs out and its underside showed as floating shards).
	pos = [0.0, 8.0, 16.0, 28.0, 40.0, 53.0, 66.0, 72.0, 80.0, 90.0, 100.0, 106.0, 118.0, 134.0, 154.0, 178.0, 206.0, 238.0, 274.0, 314.0, 358.0, 406.0, 458.0, 514.0, 574.0, 638.0, 706.0, 778.0, 856.0, 940.0, 1000.0]
	return sorted({-p for p in pos} | set(pos))


def p_range(mats, kit):
	acc = Acc()
	xs = range_grid()
	zs = range_grid()
	H = [[range_h(x, z) for z in zs] for x in xs]

	def skip(x0, x1, z0, z1):
		cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
		return (abs(cx) < 66 and abs(cz) < 80) or (abs(cx) < 16 and abs(cz) < 100)

	for half in (0, 1):
		bm = bmesh.new()
		vmap = {}

		def V(i, j):
			if (i, j) not in vmap:
				vmap[(i, j)] = bm.verts.new(rb((xs[i], H[i][j], zs[j])))
			return vmap[(i, j)]

		for i in range(len(xs) - 1):
			for j in range(len(zs) - 1):
				if skip(xs[i], xs[i + 1], zs[j], zs[j + 1]):
					continue
				if (xs[i] + xs[i + 1] > 0) != (half == 0):
					continue
				bm.faces.new((V(i, j), V(i + 1, j), V(i + 1, j + 1), V(i, j + 1)))
		bmesh.ops.triangulate(bm, faces=bm.faces[:])
		bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
		for f in bm.faces:
			if f.normal.z < 0:
				f.normal_flip()
		split_by_up(bm, acc, "Rock%d" % half, "Snow%d" % half, 0.62)
	return piece("Range", acc, mats, kit)


# ---------------------------------------------------------------- placements (the one list for Art.luau and the preview)

def placements():
	P = []  # (section, piece, x, y, z, yaw, paint)

	def add(sec, pc, x, y, z, yaw=0.0, paint=None):
		P.append((sec, pc, round(x, 3), round(y, 3), round(z, 3), round(yaw, 1) % 360, paint))

	add("Lodge", "Lodge", 0, 0, 0)
	add("Lodge", "Fireplace", 0, 0, 0)
	add("Lodge", "LodgeInside", 0, 0, 0, 0)
	add("Lodge", "LodgeInside", 0, 0, 0, 180)
	for b in L.BOXES:
		half = "A" if b.name.endswith("'") else "B"
		yaw = 180.0 if half == "A" else 0.0
		paint = END_A if half == "A" else END_B
		if b.kind == "ramp":
			add("Stairs", b.piece, b.x, b.y0, b.z, math.degrees(math.atan2(b.up[0], b.up[1])))
		elif b.piece in ("PatrolHut", "SkateHut", "Kiosk", "Woodshed", "Woodpile", "Firewood", "SnowPile8", "SnowPile18", "Snowcat", "TrailMap", "SkiRack", "FirePit", "Island", "Boulder6", "Boulder8"):
			add("Props", b.piece, b.x, b.y0, b.z, yaw, paint if b.piece in ("PatrolHut", "SkateHut", "Kiosk") else None)
		elif b.piece == "Cabin":
			add("Station", "Cabin", b.x, b.y0, b.z, yaw)
		elif b.piece == "Parapet8":
			for k in range(int(b.sz // 8)):
				add("Edges", "Parapet8", b.x, 0, b.z0 + 4 + 8 * k, yaw)
	for s in (1, -1):
		yaw = 0.0 if s > 0 else 180.0
		paint = END_B if s > 0 else END_A
		add("Station", "Station", s * STATION_O[0], 0, s * STATION_O[1], yaw, paint)
		add("Station", "Line", s * STATION_O[0], 0, s * STATION_O[1], yaw)
		add("Pond", "PondRim", s * POND_O[0], 0, s * POND_O[1], yaw)
		for x, z in ((26.5, 31.5), (-26.5, 31.5), (14.0, 58.0), (-38.0, 74.0), (-20.0, 56.0)):
			add("Props", "LampPost", s * x, 0, s * z, yaw)
	add("Backdrop", "Cliffs", 0, 0, 0)
	add("Backdrop", "Range", 0, 0, 0)
	rnd = random.Random(17)
	groves = 0
	tries = 0
	spots = []
	while groves < 46 and tries < 4000:
		tries += 1
		x = rnd.uniform(-520, 520)
		z = rnd.uniform(-520, 520)
		if abs(x) < 82 and abs(z) < 120:
			continue
		h = range_h(x, z)
		if not (-240 < h < 60):
			continue
		dh = abs(range_h(x + 6, z) - range_h(x - 6, z)) + abs(range_h(x, z + 6) - range_h(x, z - 6))
		if dh > 16:
			continue
		if any(math.hypot(x - gx, z - gz) < 34 or math.hypot(x + gx, z + gz) < 34 for gx, gz in spots):
			continue
		spots.append((x, z))
		for xx, zz, s in ((x, z, 1), (-x, -z, -1)):
			add("Backdrop", "PineGrove", xx, range_surface(xx, zz) - 1.2, zz, rnd.uniform(0, 360))
		groves += 2
	return P


def write_art(P):
	path = os.path.join(K.ROOT, "tools", "studio", "maps", "Snowpeak2", "Art.luau")
	with open(path, encoding="utf-8") as f:
		text = f.read()
	lines = ["local PLACEMENTS: { Placement } = {"]
	for sec, pc, x, y, z, yaw, paint in P:
		pt = ', paint = "%s"' % paint if paint else ""
		lines.append('\t{ section = "%s", piece = "%s", x = %g, y = %g, z = %g, yaw = %g%s },' % (sec, pc, x, y, z, yaw, pt))
	lines.append("}")
	block = "-- BEGIN PLACEMENTS (generated by tools/blender/build_map_kit_snowpeak2.py; edit the placements there)\n" + "\n".join(lines) + "\n-- END PLACEMENTS"
	new = re.sub(r"-- BEGIN PLACEMENTS.*?-- END PLACEMENTS", lambda m: block, text, flags=re.S)
	with open(path, "w", encoding="utf-8", newline="\n") as f:
		f.write(new)
	print("SNOWPEAK wrote placements", len(P), "->", path)


# ---------------------------------------------------------------- preview assembly and the coplanar check

def instance(col_name, cf, parent, paint=None):
	x, y, z, yaw = cf
	m = Matrix.Translation(rb((x, y, z))) @ Matrix.Rotation(math.radians(yaw), 4, "Z")
	src = bpy.data.collections["Map_" + col_name]
	out = []
	for ob in src.objects:
		if ob.type != "MESH":
			continue
		o = bpy.data.objects.new(ob.name + "_p", ob.data)
		o.matrix_world = m
		if paint and ob.name.endswith("_Paint"):
			mat = bpy.data.materials.get("Tint_" + paint) or K._flat("Tint_" + paint, int(paint, 16), 0.55)
			mat["preview_only"] = True
			o.material_slots[0].link = "OBJECT"
			o.material_slots[0].material = mat
		if ob.get("glow"):
			o.visible_shadow = False
		parent.objects.link(o)
		out.append(o)
	return out


VISIBLE_GREYBOX = ("ground", "terrace", "floor", "ice")


def assemble(P):
	col = K.collection("Preview")
	for sec, pc, x, y, z, yaw, paint in P:
		instance(pc, (x, y, z, yaw), col, paint)
	looks = {"ground": K._flat("PrevSnow", 0xE9EEF5, 0.7), "terrace": K._flat("PrevTerrace", 0x7F7468, 0.9), "floor": K._flat("PrevFloor", 0x8A6440, 0.6), "ice": K._flat("PrevIce", 0xA9CBDD, 0.08)}
	for m in looks.values():
		m["preview_only"] = True
	for b in L.BOXES:
		if b.kind in VISIBLE_GREYBOX:
			o = K.add_obj("Grey_" + b.kind, RB(b.x0, b.x1, b.y0, b.top, b.z0, b.z1), [looks[b.kind]], col)
			o["greybox"] = True
	return col


def tri_soup(col):
	tris, owner, names = [], [], []
	for ob in col.objects:
		if ob.type != "MESH":
			continue
		me = ob.data
		me.calc_loop_triangles()
		if not len(me.loop_triangles):
			continue
		co = np.array([v.co for v in me.vertices], dtype=np.float64)
		mw = np.array(ob.matrix_world)
		co = co @ mw[:3, :3].T + mw[:3, 3]
		idx = np.array([t.vertices for t in me.loop_triangles], dtype=np.int64)
		tris.append(co[idx])
		owner.append(np.full(len(idx), len(names)))
		names.append(ob.name)
	return np.concatenate(tris), np.concatenate(owner), names


def clip(poly, a, b):
	# Sutherland-Hodgman: keep the part of poly left of edge a->b (2D).
	out = []
	n = len(poly)
	for i in range(n):
		p, q = poly[i], poly[(i + 1) % n]
		sp = (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0])
		sq = (b[0] - a[0]) * (q[1] - a[1]) - (b[1] - a[1]) * (q[0] - a[0])
		if sp >= 0:
			out.append(p)
		if (sp >= 0) != (sq >= 0):
			t = sp / (sp - sq)
			out.append((p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t))
	return out


def area2(poly):
	s = 0.0
	for i in range(len(poly)):
		x0, y0 = poly[i]
		x1, y1 = poly[(i + 1) % len(poly)]
		s += x0 * y1 - x1 * y0
	return s / 2


def coplanar_check(col, tol=0.02, min_area=0.0025):
	T, own, names = tri_soup(col)
	e1 = T[:, 1] - T[:, 0]
	e2 = T[:, 2] - T[:, 0]
	n = np.cross(e1, e2)
	ln = np.linalg.norm(n, axis=1)
	ok = ln > 1e-6
	T, own, n, ln = T[ok], own[ok], n[ok], ln[ok]
	n = n / ln[:, None]
	d = np.einsum("ij,ij->i", n, T[:, 0])
	grey = [b for b in L.BOXES if b.kind in VISIBLE_GREYBOX]

	def buried(p):
		# Blender (x, y, z) -> Roblox (x, z, -y): inside a visible greybox Part (a face pressed into the snow)?
		x, y, z = p[0], p[2], -p[1]
		return any(b.x0 < x < b.x1 and b.z0 < z < b.z1 and b.y0 < y < b.top for b in grey)

	key_n = np.round(n * 400).astype(np.int64)
	key_d = np.round(d / tol).astype(np.int64)
	buckets = {}
	for i in range(len(T)):
		buckets.setdefault((key_n[i, 0], key_n[i, 1], key_n[i, 2], key_d[i]), []).append(i)
	bad = {}
	checked = set()
	for k, lst in buckets.items():
		cand = list(lst)
		for dk in (-1, 1):
			cand += buckets.get((k[0], k[1], k[2], k[3] + dk), [])
		if len(cand) < 2:
			continue
		nn = n[lst[0]]
		ax = np.argmax(np.abs(nn))
		u_ax, v_ax = [a for a in range(3) if a != ax]
		lo = T[cand][:, :, [u_ax, v_ax]].min(axis=1)
		hi = T[cand][:, :, [u_ax, v_ax]].max(axis=1)
		for ia, a in enumerate(cand):
			if a not in lst:
				continue
			for ib in range(len(cand)):
				b = cand[ib]
				if b <= a and b in lst:
					continue
				if b == a or (min(a, b), max(a, b)) in checked:
					continue
				if np.dot(n[a], n[b]) < 0.9995 or abs(d[a] - d[b]) > tol:
					continue
				if (lo[ia] > hi[ib]).any() or (lo[ib] > hi[ia]).any():
					continue
				checked.add((min(a, b), max(a, b)))
				pa = [tuple(p) for p in T[a][:, [u_ax, v_ax]]]
				pb = [tuple(p) for p in T[b][:, [u_ax, v_ax]]]
				if area2(pa) < 0:
					pa = pa[::-1]
				if area2(pb) < 0:
					pb = pb[::-1]
				poly = pa
				for i in range(3):
					poly = clip(poly, pb[i], pb[(i + 1) % 3])
					if len(poly) < 3:
						break
				if len(poly) < 3:
					continue
				ar = abs(area2(poly))
				if ar < min_area:
					continue
				cu = sum(p[0] for p in poly) / len(poly)
				cv = sum(p[1] for p in poly) / len(poly)
				c = [0.0, 0.0, 0.0]
				c[u_ax], c[v_ax] = cu, cv
				c[ax] = (d[a] - nn[u_ax] * cu - nn[v_ax] * cv) / nn[ax]
				q = [c[i] + n[a][i] * 0.05 for i in range(3)]
				if buried(q):
					continue
				pair = tuple(sorted((names[own[a]], names[own[b]])))
				bad.setdefault(pair, [0, 0.0, c])
				bad[pair][0] += 1
				bad[pair][1] += ar
	return len(T), bad


# ---------------------------------------------------------------- renders

def sheet(pieces, mats, tris):
	sc = bpy.context.scene
	stage = K.collection("Sheet")
	w = sc.world or bpy.data.worlds.new("World")
	sc.world = w
	w.use_nodes = True
	bg = w.node_tree.nodes.get("Background")
	if bg:
		bg.inputs[0].default_value = (*K.lin(0x8FA6BF), 1)
		bg.inputs[1].default_value = 1.0
	cell = 46.0
	ncol = 6
	nrow = (len(pieces) + ncol - 1) // ncol
	floor = K.add_obj("SheetFloor", box(-cell * (nrow - 0.4), cell * 0.6, -cell * 0.6, cell * (ncol - 0.4), -0.2, 0), [mats["SnowShade"]], stage)
	floor["preview_only"] = True
	for idx, (name, col) in enumerate(pieces):
		r, c = divmod(idx, ncol)
		lo = Vector((1e9, 1e9, 1e9))
		hi = -lo
		for ob in col.all_objects:
			if ob.type != "MESH":
				continue
			for v in ob.data.vertices:
				for i in range(3):
					lo[i] = min(lo[i], v.co[i])
					hi[i] = max(hi[i], v.co[i])
		size = hi - lo
		s = min(1.0, 34.0 / max(size.x, size.y, size.z, 0.01))
		ctr = (lo + hi) / 2
		px, py = -r * cell, c * cell
		m = Matrix.Translation((px, py, 0)) @ Matrix.Scale(s, 4) @ Matrix.Translation((-ctr.x, -ctr.y, -lo.z))
		e = bpy.data.objects.new("Sheet_" + name, None)
		e.instance_type = "COLLECTION"
		e.instance_collection = col
		e.matrix_world = m
		stage.objects.link(e)
		label = "%s  %d tris%s" % (name, tris[name], "" if s == 1 else "  (x%.2f)" % s)
		K.text(label, 1.8, (px + 20.0, py, 0.05), stage, mats["SignText"], rot=(0, 0, 90), font=K.FONT_LABEL)
	sun = bpy.data.lights.new("SheetSun", "SUN")
	sun.energy = 3.6
	sun.angle = math.radians(2)
	so = bpy.data.objects.new("SheetSun", sun)
	stage.objects.link(so)
	so.rotation_euler = (math.radians(42), math.radians(-25), math.radians(200))
	cx, cy = -(nrow - 1) * cell / 2, (ncol - 1) * cell / 2
	cam = K.camera((cx + 300, cy + 70, 290), (cx, cy, 4), lens=50, name="SheetCam", col=stage)
	cam.data.type = "ORTHO"
	cam.data.ortho_scale = cell * ncol * 1.08
	K.render_settings(samples=int(ARGS[ARGS.index("--samples") + 1]) if "--samples" in ARGS else 24, exposure=-0.4)
	try:
		sc.eevee.use_raytracing = False
	except AttributeError:
		pass
	K.bloom(strength=0.3)
	return stage


def morning_world():
	# Clear cold morning: blue sky gradient, a low warm-white sun from +X (37 degrees up), blue sky fill.
	sc = bpy.context.scene
	w = bpy.data.worlds.new("Morning")
	sc.world = w
	w.use_nodes = True
	nt = w.node_tree
	nt.nodes.clear()
	out = nt.nodes.new("ShaderNodeOutputWorld")
	bg = nt.nodes.new("ShaderNodeBackground")
	tc = nt.nodes.new("ShaderNodeTexCoord")
	sep = nt.nodes.new("ShaderNodeSeparateXYZ")
	nt.links.new(tc.outputs["Generated"], sep.inputs[0])
	ramp = nt.nodes.new("ShaderNodeValToRGB")
	cr = ramp.color_ramp
	cr.elements[0].position = 0.0
	cr.elements[0].color = (*K.lin(0xB7C6D8), 1)
	cr.elements[1].position = 1.0
	cr.elements[1].color = (*K.lin(0x3F78C2), 1)
	for pos, col in ((0.5, 0xDCE6F0), (0.6, 0x8FB4DE)):
		e = cr.elements.new(pos)
		e.color = (*K.lin(col), 1)
	mr = nt.nodes.new("ShaderNodeMath")
	mr.operation = "MULTIPLY_ADD"
	nt.links.new(sep.outputs["Z"], mr.inputs[0])
	mr.inputs[1].default_value = 0.5
	mr.inputs[2].default_value = 0.5
	nt.links.new(mr.outputs[0], ramp.inputs[0])
	nt.links.new(ramp.outputs[0], bg.inputs[0])
	bg.inputs[1].default_value = 1.25
	nt.links.new(bg.outputs[0], out.inputs[0])
	ld = bpy.data.lights.new("Sun", "SUN")
	ld.energy = 5.0
	ld.color = K.lin(0xFFF1E0)
	ld.angle = math.radians(1.0)
	ob = bpy.data.objects.new("Sun", ld)
	K.collection("Stage").objects.link(ob)
	el = math.radians(37)
	dvec = Vector((-math.cos(el), 0.08, -math.sin(el))).normalized()
	ob.rotation_euler = dvec.to_track_quat("-Z", "Y").to_euler()
	fill = bpy.data.lights.new("SkyFill", "SUN")
	fill.energy = 0.45
	fill.color = K.lin(0x9DB8E8)
	fill.use_shadow = False
	fo = bpy.data.objects.new("SkyFill", fill)
	K.collection("Stage").objects.link(fo)
	fo.rotation_euler = (math.radians(15), math.radians(-20), 0)


def warm(name, p, energy=2500, radius=1.0):
	ld = bpy.data.lights.new(name, "POINT")
	ld.energy = energy
	ld.color = K.lin(0xFFB070)
	ld.shadow_soft_size = radius
	ob = bpy.data.objects.new(name, ld)
	K.collection("Stage").objects.link(ob)
	ob.location = rb(p)
	return ob


def renders():
	for c in list(bpy.context.view_layer.layer_collection.children):
		if c.name in ("Sheet", "Kit"):
			c.exclude = True
	morning_world()
	for s in (1, -1):
		warm("Fire", (0, 3, s * 5), 2500)
		warm("Lounge", (s * 9, 14, s * 6), 3500, 2)
		warm("Loft", (0, 16, s * 17), 2500, 2)
	K.render_settings(samples=int(ARGS[ARGS.index("--samples") + 1]) if "--samples" in ARGS else 32, exposure=-0.15)
	K.bloom(strength=0.25, threshold=1.2)
	shots = [
		("overview", (135, 120, -70), (0, 0, 12), 30),
		("from-b-spawn", (-30, 6, 72), (2, 8, 14), 28),
		("lounge", (14, 5.5, -11), (-4, 6, 12), 20),
		("station", (-20, 14, 6), (-52, 14, 42), 26),
	]
	only = set(ARGS[ARGS.index("--shots") + 1].split(",")) if "--shots" in ARGS else None
	for name, eye, tgt, lens in shots:
		if only and name not in only:
			continue
		K.camera(tuple(rb(eye)), tuple(rb(tgt)), lens=lens, name="Cam_" + name)
		K.render(os.path.join(K.RENDER_DIR, "snowpeak2-preview-%s.jpg" % name), res=(1600, 900))


# ---------------------------------------------------------------- main

def main():
	mats = make_mats()
	kit = K.collection("Kit")
	pb = {b.piece: b for b in L.HALF}
	built = [
		("Lodge", p_lodge(mats, kit)),
		("Fireplace", p_fireplace(mats, kit)),
		("LodgeInside", p_lodge_inside(mats, kit)),
		("LodgeStair", stair("LodgeStair", "Oak", "TimberDark", mats, kit, rail="Iron")),
		("DeckStair", stair("DeckStair", "Timber", "TimberDark", mats, kit, rail="TimberDark", nosing="Snow")),
		("StationStair", stair("StationStair", "Concrete", "Concrete", mats, kit, rail="Steel", nosing="SteelDark")),
		("Station", p_station(mats, kit)),
		("Cabin", p_cabin(mats, kit)),
		("Line", p_line(mats, kit)),
		("PatrolHut", hut("PatrolHut", pb["PatrolHut"].sx, pb["PatrolHut"].sz, 10, 7.0, mats, kit, door_side=1, windows=[(x, s) for x in (-15, -8, 8, 15) for s in (-1, 1)], sign=-1)),
		("SkateHut", hut("SkateHut", pb["SkateHut"].sx, pb["SkateHut"].sz, 9, 6.5, mats, kit, door_side=1, windows=[(-3.5, -1), (3.5, -1)], sign=-1)),
		("Kiosk", hut("Kiosk", pb["Kiosk"].sx, pb["Kiosk"].sz, 8, 6.0, mats, kit, door_side=1, windows=[], sign=None, hatch=True)),
		("Woodshed", hut("Woodshed", pb["Woodshed"].sx, pb["Woodshed"].sz, 8, 6.0, mats, kit, logs_front=True)),
		("Woodpile", p_woodpile("Woodpile", pb["Woodpile"].sx, pb["Woodpile"].sz, 7, mats, kit)),
		("Firewood", p_woodpile("Firewood", pb["Firewood"].sx, pb["Firewood"].sz, 7, mats, kit, back_gap=0.5)),
		("SnowPile8", p_snowpile("SnowPile8", pb["SnowPile8"].sx, pb["SnowPile8"].sz, mats, kit, 3)),
		("SnowPile18", p_snowpile("SnowPile18", pb["SnowPile18"].sx, pb["SnowPile18"].sz, mats, kit, 4)),
		("Island", p_rock("Island", 8, 8, 7.4, mats, kit, 21)),
		("Boulder6", p_rock("Boulder6", 6, 6, 8.4, mats, kit, 22)),
		("Boulder8", p_rock("Boulder8", 8, 8, 8.0, mats, kit, 23)),
		("Snowcat", p_snowcat(mats, kit)),
		("TrailMap", p_trailmap(mats, kit)),
		("SkiRack", p_skirack(mats, kit)),
		("FirePit", p_firepit(mats, kit)),
		("Parapet8", p_parapet(mats, kit)),
		("LampPost", p_lamp(mats, kit)),
		("PondRim", p_pond_rim(mats, kit)),
		("PineGrove", p_pinegrove(mats, kit)),
		("Cliffs", p_cliffs(mats, kit)),
		("Range", p_range(mats, kit)),
	]
	tris, worst = {}, {}
	for name, col in built:
		tris[name] = K.tri_count(col)
		for ob in col.all_objects:
			if ob.type == "MESH":
				ob.data.calc_loop_triangles()
				worst[ob.name] = len(ob.data.loop_triangles)
	print("SNOWPEAK_TRIS " + json.dumps(tris))
	print("SNOWPEAK_MAX_OBJECT " + json.dumps(max(worst.items(), key=lambda kv: kv[1])))
	print("SNOWPEAK_PARTS " + json.dumps({n: len([o for o in c.all_objects if o.type == "MESH"]) for n, c in built}))
	P = placements()
	write_art(P)
	pc = {}
	for p in P:
		pc[p[1]] = pc.get(p[1], 0) + 1
	parts_per = {n: len([o for o in c.all_objects if o.type == "MESH"]) for n, c in built}
	print("SNOWPEAK_PLACED meshparts=%d tris=%d" % (sum(parts_per[k] * v for k, v in pc.items()), sum(tris[k] * v for k, v in pc.items())))
	sheet(built, mats, tris)
	bpy.context.view_layer.layer_collection.children["Kit"].exclude = True
	prev = assemble(P)
	ntri, bad = coplanar_check(prev)
	print("SNOWPEAK_COPLANAR triangles=%d pairs=%d" % (ntri, len(bad)))
	for pair, (cnt, ar, c) in sorted(bad.items(), key=lambda kv: -kv[1][1])[:80]:
		print("  ZFIGHT %s | %s  tris=%d area=%.2f at roblox (%.1f, %.1f, %.1f)" % (pair[0], pair[1], cnt, ar, c[0], c[2], -c[1]))
	os.makedirs(K.ART_DIR, exist_ok=True)
	with open(os.path.join(K.ART_DIR, "coplanar.json"), "w") as f:
		json.dump({"triangles": ntri, "pairs": [{"a": p[0], "b": p[1], "tris": v[0], "area": round(v[1], 3)} for p, v in bad.items()]}, f, indent=1)
	bpy.context.view_layer.layer_collection.children["Preview"].exclude = True
	path = K.save("Kit_Snowpeak2")
	print("SNOWPEAK saved", path)
	if "--no-render" in ARGS:
		return
	if "--no-sheet" not in ARGS:
		K.render(os.path.join(K.RENDER_DIR, "kit-contact.jpg"), res=(2400, 1500))
	bpy.context.view_layer.layer_collection.children["Preview"].exclude = False
	renders()


main()
