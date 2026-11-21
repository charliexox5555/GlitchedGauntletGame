"""Snowpeak4 kit (2026-11-20): the pieces Parts can't do well. Everything else on the map is Parts.

    python tools/blender/lobby_v4/send.py tools/blender/maps_snowpeak4/run_snowpeak4.py --port 9897 --pid <pid>

Pieces (Map_<Piece> collections at the origin, for tools/blender/export_lobby_kit.py --maps Snowpeak4 Kit):
  Snowcat        the hero prop (owner: the old snowcats "aren't good"): two track units (belt runs, carved
                 ends, four big road wheels and a sprocket each, grousers), a chassis, fenders, a sloped engine hood
                 with a grille, a glazed cab with a raked windscreen, roof with work lights and an amber beacon, a
                 three-plate front blade on push arms, a rear tiller with its comb flap, exhaust, steps, mirrors.
                 Body in gondola red (*Paint* parts can be recoloured).
  PineA / PineB  pines the RIVALS way (Village, read-only 2026-11-20): a foliage mesh in LeafyGrass and a separate
                 snow mesh in Snow over the tiers' tops. Seven / five drooping star tiers with ragged tips, smooth
                 normals, a timber trunk. 24 / 17 tall. Not low-poly cones (owner 2026-11-20).
  GondolaCabin   the red cabin parked on the station deck: chamfered body, window band, doors, roof, hanger arm
                 and grip. Bullwheel: the station's return wheel (16-sided rim, spokes, hub).
  Outcrop / BoulderA / BoulderB   rocks (Slate) with snow (Snow) on the up-facing faces.
  MountainA/B/C  snowy faceted mountains for the horizon (far: faceted is fine, owner 2026-11-20).
Meshes that use textured Roblox materials (LeafyGrass, Snow, Slate, Wood) get box-projected UVs (8 studs a tile).
Rules: gauntlet-build-style (no round shapes in hard surfaces: wheels and posts are 8 / 12 / 16-sided prisms; edges
bevelled or carved; members end in joints). Units: studs; +X east, +Y north, +Z up; Roblox = (x, z, -y); a piece's
front toward Roblox -Z is Blender +Y. Origin = bottom centre. Our own designs (nothing taken from RIVALS).
"""
from math import cos, pi, radians, sin, sqrt
import random

import arena_kit as A
import bmesh
from mathutils import Vector

import metro4_pieces as K

ROOT = "Snowpeak4Kit"
bbox, bar, ngon, disc_y, extrude_x = K.bbox, K.bar, K.ngon, K.disc_y, K.extrude_x

A.PAL.update(
	{
		"S_Paint": ("#A8262E", 0.6),  # gondola / snowcat red (Snowpeak2's hero accent)
		"S_PaintDark": ("#7A1C22", 0.6),
		"S_Steel": ("#4A4F57", 0.6),
		"S_SteelLight": ("#8E949B", 0.5),
		"S_Rubber": ("#26282C", 0.8),
		"S_Glass": ("#26303A", 0.3),
		"S_Lamp": ("#E9E4D2", 0.4),
		"S_Amber": ("#D08A2A", 0.4),
		"S_Leaf": ("#2C4A35", 0.9),
		"S_Snow": ("#E4EBF2", 0.9),
		"S_Bark": ("#5E4636", 0.9),
		"S_Rock": ("#7A8088", 0.9),
		"S_RockDark": ("#5E646C", 0.9),
		"S_MtnSnow": ("#E6ECF3", 0.9),
		"S_MtnShade": ("#C9D4E0", 0.9),
		"S_Stripe": ("#E6E1D6", 0.6),
		"S_Chrome": ("#B9BEC4", 0.3),
	}
)
RBX = {
	"S_Leaf": "LeafyGrass",
	"S_Snow": "Snow",
	"S_Bark": "Wood",
	"S_Rock": "Slate",
	"S_RockDark": "Slate",
	"S_Glass": "Glass",
}
TRANSPARENT = {"S_Glass": 0.25}
TEXTURED = {"S_Leaf", "S_Snow", "S_Bark", "S_Rock", "S_RockDark"}


def box_uv(o, tile=8.0):
	"""Box-projected UVs (world studs / tile) on every face: textured Roblox materials need UVs on a MeshPart."""
	me = o.data
	if not me.uv_layers:
		me.uv_layers.new(name="UVMap")
	uv = me.uv_layers.active.data
	for p in me.polygons:
		n = p.normal
		ax = max(range(3), key=lambda i: abs(n[i]))
		for li in p.loop_indices:
			co = me.vertices[me.loops[li].vertex_index].co
			a, b = [(co.y, co.z), (co.x, co.z), (co.x, co.y)][ax]
			uv[li].uv = (a / tile, b / tile)


def smooth(o):
	"""Smooth normals on every face (foliage reads soft, not faceted)."""
	for p in o.data.polygons:
		p.use_smooth = True
	o.data.update()


# ------------------------------------------------------------------------------------------------ snowcat
def snowcat(name, collection):
	"""8 wide, ~14.5 long (blade at +Y = the front), ~8.6 tall."""
	M = A.Mesh(name, collection)
	P, PD, St, SL, Rb, Gl, Lp, Am = (
		A.mat(k) for k in ("S_Paint", "S_PaintDark", "S_Steel", "S_SteelLight", "S_Rubber", "S_Glass", "S_Lamp", "S_Amber")
	)
	# --- track units: belt runs (top, bottom, carved ends) round four road wheels and a raised sprocket
	for s in (-1, 1):
		x0, x1 = sorted((s * 1.8, s * 4.0))
		belt = [
			(-5.0, 0.0), (4.6, 0.0), (5.6, 0.7), (5.9, 1.7), (5.4, 2.9), (4.6, 3.25), (-4.4, 3.25), (-5.4, 2.6), (-5.8, 1.4),
		]
		# the belt as a ring: outer outline extruded, the inner face hidden by the wheels' side plates
		extrude_x(M, Rb, belt, x0, x1)
		wx0, wx1 = sorted((s * 1.7, s * 4.1))
		for wy in (-3.6, -1.2, 1.2, 3.6):
			disc_y_x(M, St, wy, 1.25, 1.15, 12, wx0, wx1)  # road wheel faces proud of the belt both sides
			disc_y_x(M, SL, wy, 1.25, 0.45, 8, *sorted((s * 4.1, s * 4.25)))  # hub
		disc_y_x(M, SL, 4.9, 1.7, 0.95, 10, wx0, wx1)  # drive sprocket at the front
		# grousers across the top run
		for k in range(12):
			y = -4.2 + k * 0.78
			bbox(M, St, x0 - 0.02, x1 + 0.02, y - 0.12, y + 0.12, 3.2, 3.42, 0.03)
		# fender over the track, carved ends
		fx0, fx1 = sorted((s * 1.7, s * 4.15))
		M.loft(
			[
				[(fx0, -5.6, 3.35), (fx1, -5.6, 3.35), (fx1, 6.0, 3.35), (fx0, 6.0, 3.35)],
				[(fx0, -5.3, 3.7), (fx1, -5.3, 3.7), (fx1, 5.7, 3.7), (fx0, 5.7, 3.7)],
			],
			PD,
		)
	# chassis between the tracks
	bbox(M, St, -1.85, 1.85, -5.2, 5.4, 0.9, 3.4, 0.1)
	# --- engine hood (front), sloping to the blade, grille, exhaust
	M.loft(
		[
			[(-3.2, 0.2, 3.7), (3.2, 0.2, 3.7), (3.2, 6.0, 3.7), (-3.2, 6.0, 3.7)],
			[(-3.1, 0.2, 5.0), (3.1, 0.2, 5.0), (3.1, 5.4, 5.0), (-3.1, 5.4, 5.0)],
			[(-2.8, 0.2, 5.6), (2.8, 0.2, 5.6), (2.8, 4.4, 5.6), (-2.8, 4.4, 5.6)],
		],
		P,
	)
	# grille on the hood's front slope (a dark plate with bars, set just proud of the slope)
	for k in range(4):
		z = 3.95 + k * 0.26
		yf = 6.0 - (z + 0.08 - 3.7) * (0.6 / 1.3)  # the slope's face at this bar
		bbox(M, Rb, -2.3, 2.3, yf - 0.1, yf + 0.06, z, z + 0.16, 0.02)
	M.loft([A.ring_at(ngon(-2.2, 1.0, 0.22, 8), 5.4), A.ring_at(ngon(-2.2, 1.0, 0.22, 8), 7.6)], St)  # exhaust
	bbox(M, Rb, -2.45, -1.95, 0.75, 1.25, 7.55, 7.7, 0.03)  # rain cap
	# --- cab
	bbox(M, P, -3.3, 3.3, -4.4, 0.4, 3.7, 5.2, 0.1)  # lower cab
	cab_bot = [(-3.3, -4.4), (3.3, -4.4), (3.3, 0.4), (-3.3, 0.4)]
	cab_top = [(-3.1, -4.2), (3.1, -4.2), (3.1, -0.7), (-3.1, -0.7)]
	# the glass house: four corner posts in red, glass panes set in, a raked windscreen
	M.loft([A.ring_at([(x * 0.97, y) for x, y in cab_bot], 5.2), A.ring_at([(x * 0.97, y) for x, y in cab_top], 7.7)], Gl)
	for (xa, ya), (xb, yb) in zip(cab_bot, cab_top):
		bar(M, P, (xa, ya, 5.15), (xb, yb, 7.75), 0.34, 0.34)
	bbox(M, P, -3.3, 3.3, -4.4, 0.4, 5.1, 5.35, 0.05)  # sill band
	# roof with overhang, work lights, beacon, a rack
	bbox(M, P, -3.45, 3.45, -4.55, -0.45, 7.7, 8.15, 0.12)
	for x in (-2.4, -0.8, 0.8, 2.4):
		bbox(M, Rb, x - 0.35, x + 0.35, -0.7, -0.35, 7.8, 8.25, 0.04)
		bbox(M, Lp, x - 0.27, x + 0.27, -0.38, -0.3, 7.88, 8.17, 0.02)
	M.loft([A.ring_at(ngon(0, -2.4, 0.32, 8), 8.15), A.ring_at(ngon(0, -2.4, 0.28, 8), 8.6)], Am)
	for x in (-2.6, 2.6):
		bbox(M, SL, x - 0.08, x + 0.08, -4.2, -1.0, 8.15, 8.4, 0.02)
	# mirrors on arms, door handle and a step on each side
	for s in (-1, 1):
		bar(M, St, (s * 3.3, 0.0, 6.6), (s * 4.0, 0.4, 6.8), 0.1, 0.1)
		bbox(M, Rb, *sorted((s * 3.95, s * 4.15)), 0.2, 0.75, 6.3, 7.1, 0.04)
		bbox(M, SL, *sorted((s * 3.3, s * 3.38)), -2.4, -1.7, 4.4, 4.55, 0.01)
		bbox(M, St, *sorted((s * 4.15, s * 4.6)), -3.4, -2.2, 2.4, 2.6, 0.03)
	# --- front blade: three angled plates (a faceted moldboard), side plates, push arms
	mold = [(6.9, 0.05), (7.7, 0.05), (7.55, 0.6), (7.1, 1.6), (6.6, 2.5), (6.15, 2.9), (5.95, 2.55), (6.4, 1.6), (6.75, 0.6)]
	M.loft([[(-4.4, y, z) for y, z in mold], [(4.4, y, z) for y, z in mold]], SL)
	bbox(M, St, -4.45, 4.45, 7.4, 7.75, 0.0, 0.25, 0.04)  # cutting edge
	for s in (-1, 1):
		bar(M, St, (s * 1.3, 5.3, 1.8), (s * 1.3, 6.5, 1.5), 0.45, 0.45)
		xa, xb = sorted((s * 4.4, s * 4.5))
		bbox(M, St, xa, xb, 6.0, 7.7, 0.05, 2.7, 0.03)
	bbox(M, St, -1.6, 1.6, 6.25, 6.6, 1.0, 2.1, 0.05)  # blade frame
	# --- rear tiller with its comb flap
	for s in (-1, 1):
		bar(M, St, (s * 1.2, -5.0, 2.0), (s * 1.2, -6.4, 1.4), 0.4, 0.4)
	bbox(M, SL, -3.9, 3.9, -7.6, -6.3, 0.35, 1.6, 0.12)
	bbox(M, St, -3.95, 3.95, -7.65, -6.25, 1.55, 1.75, 0.05)
	bbox(M, Rb, -3.9, 3.9, -8.3, -7.55, 0.0, 0.18, 0.02)  # comb finisher
	bbox(M, Rb, -3.8, 3.8, -7.6, -7.5, 0.15, 0.5, 0.0)
	o = M.finish()
	return o


def disc_y_x(M, mat, y, z, r, n, x0, x1):
	"""An n-sided prism whose axis runs along X (wheels of the snowcat), centred at (y, z)."""
	pts = ngon(y, z, r, n, pi / n)
	M.loft([[(x0, a, b) for a, b in pts], [(x1, a, b) for a, b in pts]], mat)


# ------------------------------------------------------------------------------------------------ pines
def pine(name, collection, H=24.0, tiers=7, seed=1):
	rnd = random.Random(seed)
	Lf, Sn, Bk = A.mat("S_Leaf"), A.mat("S_Snow"), A.mat("S_Bark")
	F = A.Mesh(name + "_Foliage", collection)
	S = A.Mesh(name + "_Snow", collection)
	T = A.Mesh(name + "_Trunk", collection)
	T.loft([A.ring_at(ngon(0, 0, 0.75, 8), -0.6), A.ring_at(ngon(0, 0, 0.55, 8), H * 0.35)], Bk)
	R0 = H * 0.27
	for t in range(tiers):
		f = t / (tiers - 1)
		zb = H * (0.16 + 0.74 * f)  # tier underside at the tips
		r = R0 * (1.0 - 0.8 * f) + 0.6
		pts = 13 + (t % 2)
		rot = rnd.uniform(0, 2 * pi)
		# star outline: tips at r, notches at ~0.62 r; tips droop below the notches
		ring_lo, ring_tip, ring_top = [], [], []
		for k in range(pts * 2):
			a = rot + pi * k / pts + rnd.uniform(-0.07, 0.07)
			tip = k % 2 == 0
			rr = r * (rnd.uniform(0.84, 1.08) if tip else rnd.uniform(0.66, 0.74))
			droop = 0.0 if tip else 0.55
			ring_tip.append((rr * cos(a), rr * sin(a), zb + droop))
			ring_lo.append((rr * 0.45 * cos(a), rr * 0.45 * sin(a), zb + 0.35 + droop * 0.5))
			ring_top.append((rr * 0.82 * cos(a), rr * 0.82 * sin(a), zb + 0.9 + droop * 0.6))
		th = H * 0.2 * (1.0 - 0.35 * f)  # tier height (cone above the tips)
		apex = [(0.06 * cos(rot + pi * k / pts), 0.06 * sin(rot + pi * k / pts), zb + th) for k in range(pts * 2)]
		F.loft([ring_lo, ring_tip, ring_top, [(x * 0.35, y * 0.35, zb + th * 0.72) for x, y, _ in ring_top], apex], Lf)
		# the snow cap on the tier's upper face: rings taken on the foliage surface itself (between the top ring, the
		# mid ring and the apex), raised 0.15-0.18, with a 0.1 rim so it reads as a layer of snow
		mid = [(x * 0.35, y * 0.35, zb + th * 0.72) for x, y, _ in ring_top]

		def lerp(p, q, t):
			return (p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t, p[2] + (q[2] - p[2]) * t)

		cap_a = [lerp(p, q, 0.35) for p, q in zip(ring_top, mid)]
		cap_a = [(x, y, z + 0.18) for x, y, z in cap_a]
		cap_rim = [(x * 1.02, y * 1.02, z - 0.12) for x, y, z in cap_a]
		cap_b = [(x, y, z + 0.16) for x, y, z in mid]
		cap_c = [(x, y, z + 0.12) for x, y, z in apex]
		S.loft([cap_rim, cap_a, cap_b, cap_c], Sn)
	out = [T.finish(), F.finish(), S.finish()]
	for o in out[1:]:
		smooth(o)
	for o in out:
		box_uv(o, 6.0)
	return out


# ------------------------------------------------------------------------------------------------ gondola
def gondola_cabin(name, collection):
	"""5 x 4.4 x 6 cabin (origin = floor centre), hanger arm to a grip at +9.6."""
	M = A.Mesh(name, collection)
	P, PD, St, SL, Gl = (A.mat(k) for k in ("S_Paint", "S_PaintDark", "S_Steel", "S_SteelLight", "S_Glass"))
	bbox(M, PD, -2.4, 2.4, -2.1, 2.1, 0.0, 0.5, 0.15)  # floor pan
	bbox(M, P, -2.5, 2.5, -2.2, 2.2, 0.45, 2.6, 0.2)  # lower body
	M.loft([A.ring_at(A.cham(-2.45, 2.45, -2.15, 2.15, 0.35), 2.6), A.ring_at(A.cham(-2.35, 2.35, -2.05, 2.05, 0.4), 4.9)], Gl)
	for x, y in ((-2.4, -2.1), (2.4, -2.1), (2.4, 2.1), (-2.4, 2.1)):
		bar(M, P, (x, y, 2.55), (x * 0.96, y * 0.96, 4.95), 0.32, 0.32)
	bbox(M, P, -2.5, 2.5, -2.2, 2.2, 4.85, 5.6, 0.25)  # roof band
	M.loft([A.ring_at(A.cham(-2.4, 2.4, -2.1, 2.1, 0.5), 5.55), A.ring_at(A.cham(-1.2, 1.2, -1.0, 1.0, 0.35), 6.2)], PD)
	bbox(M, P, -0.08, 0.08, 2.18, 2.26, 0.6, 4.8, 0.0)  # door seam
	bbox(M, St, -0.3, 0.3, -0.3, 0.3, 6.1, 9.0, 0.06)  # hanger
	bbox(M, St, -0.9, 0.9, -0.35, 0.35, 8.9, 9.6, 0.1)  # grip
	disc_y(M, SL, 0.0, 9.9, 0.35, 8, -0.4, 0.4)
	return M.finish()


def bullwheel(name, collection, R=5.0):
	"""The station's horizontal return wheel (origin = hub centre): a 16-sided rim, 8 spokes, hub, shaft."""
	M = A.Mesh(name, collection)
	St, SL, Pd = A.mat("S_Steel"), A.mat("S_SteelLight"), A.mat("S_Paint")
	outer = ngon(0, 0, R, 16, pi / 16)
	inner = ngon(0, 0, R - 0.5, 16, pi / 16)
	for i in range(16):
		a0, a1 = outer[i], outer[(i + 1) % 16]
		b0, b1 = inner[i], inner[(i + 1) % 16]
		M.loft([[(*a0, -0.35), (*a1, -0.35), (*b1, -0.35), (*b0, -0.35)], [(*a0, 0.35), (*a1, 0.35), (*b1, 0.35), (*b0, 0.35)]], Pd)
	for k in range(8):
		a = k * pi / 4
		bar(M, St, (0.5 * cos(a), 0.5 * sin(a), 0.0), ((R - 0.45) * cos(a), (R - 0.45) * sin(a), 0.0), 0.3, 0.3)
	M.loft([A.ring_at(ngon(0, 0, 0.7, 8), -0.5), A.ring_at(ngon(0, 0, 0.7, 8), 0.5)], SL)
	M.loft([A.ring_at(ngon(0, 0, 0.35, 8), -3.0), A.ring_at(ngon(0, 0, 0.35, 8), -0.5)], St)
	return M.finish()


# ------------------------------------------------------------------------------------------------ rocks
def rock(name, collection, sx, sy, sz, seed, snow_up=0.55, subdiv=5):
	"""A natural rock (v2, owner 2026-11-20: the jittered-cube blob read low-poly): a level-3 icosphere pushed by
	layered noise (big masses, then breaks and ledges), a flattened, sunk foot, strata-like terraces from a stepped
	height term; smooth shading with sharp creases over 38 degrees, Slate texture (box UVs, 6 studs a tile), snow on
	the up-facing upper faces, a darker rock tone on the undercut faces."""
	import bpy
	from mathutils import noise

	rnd = random.Random(seed)
	off = Vector((rnd.uniform(0, 100), rnd.uniform(0, 100), rnd.uniform(0, 100)))
	bm = bmesh.new()
	bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
	for v in bm.verts:
		d = v.co.normalized()
		q = d * 1.3 + off
		big = noise.fractal(q, 0.55, 2.0, 3)  # the masses
		brk = noise.ridged_multi_fractal(q * 2.2, 0.6, 2.1, 3, 1.0, 2.0)  # breaks and ledges
		fine = noise.fractal(q * 6.0, 0.5, 2.0, 2)  # chips
		r = 1.0 + 0.22 * big + 0.07 * (brk - 1.0) + 0.025 * fine
		p = Vector((d.x * sx / 2, d.y * sy / 2, d.z * sz / 2)) * r
		# terraces: a soft step on the height, so the faces read as bedding planes
		h = p.z
		step = 1.1
		p.z = h - 0.35 * (h - step * round(h / step))
		if p.z < -sz * 0.18:  # a flat, sunk foot
			p.z = -sz * 0.18 + (p.z + sz * 0.18) * 0.15
		p.z += sz * 0.18 - 0.6
		v.co = p
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	o = bpy.data.objects.new(name, me)
	collection.objects.link(o)
	for nm in ("S_Rock", "S_Snow", "S_RockDark"):
		me.materials.append(A.mat(nm))
	top = max(v.co.z for v in me.vertices)
	for p in me.polygons:
		p.use_smooth = True
		if p.normal.z > snow_up and p.center.z > top * 0.45:
			p.material_index = 1
		elif p.normal.z < -0.25:
			p.material_index = 2
	bm = bmesh.new()
	bm.from_mesh(me)
	for e in bm.edges:
		if len(e.link_faces) == 2 and e.calc_face_angle(0) > radians(38):
			e.smooth = False
	bm.to_mesh(me)
	bm.free()
	box_uv(o, 6.0)
	return o


# ------------------------------------------------------------------------------------------------ mountains
def mountain(name, collection, rx, ry, peak, seed, n=22, ridge=0.0, sink=40.0):
	"""Faceted snowy mountain (heightfield): snow on the gentler faces and the upper slopes, rock on the steep
	ones. Every face up, no loose vertices (the Wharf fixes)."""
	rnd = random.Random(seed)
	M = A.Mesh(name, collection)
	snow, shade, rk, rkd = A.mat("S_MtnSnow"), A.mat("S_MtnShade"), A.mat("S_Rock"), A.mat("S_RockDark")
	bumps = [(rnd.uniform(-0.6, 0.6), rnd.uniform(-0.6, 0.6), rnd.uniform(0.15, 0.35), rnd.uniform(0.2, 0.45)) for _ in range(6)]
	H = {}
	for i in range(n + 1):
		for j in range(n + 1):
			u, v = -1 + 2 * i / n, -1 + 2 * j / n
			r = sqrt(u * u + v * v)
			if ridge:
				r = sqrt((u * (1 - ridge)) ** 2 + v * v * (1 + ridge))
			h = max(0.0, 1 - r) ** 0.85 * 0.8
			for bx, by, br, bh in bumps:
				d = sqrt((u - bx) ** 2 + (v - by) ** 2)
				h += bh * max(0.0, 1 - d / br) * max(0.0, 1 - r) ** 0.5
			h = h * peak + rnd.uniform(-0.05, 0.05) * peak * max(0.0, 1 - r)
			h -= sink * min(1.0, max(0.0, (r - 0.7) / 0.3)) ** 1.5
			if r >= 1.0:
				h = -sink
			jx = rnd.uniform(-0.3, 0.3) * rx / n if 0 < i < n else 0
			jy = rnd.uniform(-0.3, 0.3) * ry / n if 0 < j < n else 0
			H[(i, j)] = (u * rx + jx, v * ry + jy, h)
	bm = M.bm
	vs = {k: bm.verts.new(p) for k, p in H.items()}
	tops = []
	for i in range(n):
		for j in range(n):
			a, b, c, d = vs[(i, j)], vs[(i + 1, j)], vs[(i + 1, j + 1)], vs[(i, j + 1)]
			for tri in ((a, b, c), (a, c, d)) if (i + j) % 2 == 0 else ((a, b, d), (b, c, d)):
				if max(t.co.z for t in tri) <= -sink + 0.01:
					continue
				tops.append(bm.faces.new(tri))
	bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
	bm.normal_update()
	for f in tops:
		nz = abs(f.normal.z)
		zc = sum(v.co.z for v in f.verts) / 3
		if nz > 0.72 or zc > peak * 0.55:
			f.material_index = M._slot(snow if rnd.random() < 0.8 else shade)
		elif nz > 0.5:
			f.material_index = M._slot(shade)
		else:
			f.material_index = M._slot(rkd if rnd.random() < 0.4 else rk)
	o = M.finish()
	for p in o.data.polygons:
		if p.normal.z < 0:
			p.flip()
	o.data.update()
	return o


# ------------------------------------------------------------------------------------------------ build
PIECES = (
	"Snowcat", "PineA", "PineB", "GondolaCabin", "Bullwheel", "Outcrop", "BoulderA", "BoulderB",
	"MountainA", "MountainB", "MountainC",
	"SkiRack", "Sled", "LampPost", "TrailSign", "Bench", "FirePit",
)


def build_all():
	import bpy

	for c in [c for c in bpy.data.collections if c.name.startswith("Map_") and c.name[4:] in PIECES]:
		for o in list(c.all_objects):
			me = o.data
			bpy.data.objects.remove(o, do_unlink=True)
			if me is not None and me.users == 0:
				bpy.data.meshes.remove(me)
		bpy.data.collections.remove(c)
	root = A.coll(ROOT)

	def C(n):
		return A.coll("Map_" + n, root)

	import importlib

	import snowcat_model as SC

	importlib.reload(SC)
	made = list(SC.build(C("Snowcat")))  # the modelled snowcat (snowcat_model.py); snowcat() above is the rejected v1
	import snowpeak4_props as SPP

	importlib.reload(SPP)
	made += SPP.build(C)  # character props (2026-11-21): ski rack, sled, lamp post, trail sign, bench, fire pit
	made += pine("PineA", C("PineA"), 24.0, 9, 3)
	made += pine("PineB", C("PineB"), 17.0, 7, 8)
	made += [
		gondola_cabin("GondolaCabin", C("GondolaCabin")),
		bullwheel("Bullwheel", C("Bullwheel")),
		rock("Outcrop", C("Outcrop"), 13.0, 10.0, 12.6, 21),
		rock("BoulderA", C("BoulderA"), 5.0, 4.0, 3.6, 4, subdiv=4),
		rock("BoulderB", C("BoulderB"), 7.0, 5.0, 4.6, 9, subdiv=4),
		mountain("MountainA", C("MountainA"), 330, 300, 260, 11),
		mountain("MountainB", C("MountainB"), 420, 220, 170, 23, ridge=0.45),
		mountain("MountainC", C("MountainC"), 220, 200, 110, 37, n=16),
	]
	for nm, (hx, _r) in A.PAL.items():
		m = bpy.data.materials.get(nm)
		if m is not None and nm.startswith("S_"):
			m["rbx_material"] = RBX.get(nm, "SmoothPlastic")
			m["rbx_color"] = hx.lstrip("#").upper()
			if nm in TRANSPARENT:
				m["rbx_transparency"] = TRANSPARENT[nm]
	for o in made:
		if not o.data.uv_layers:
			box_uv(o, 8.0)
	return {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in made}
