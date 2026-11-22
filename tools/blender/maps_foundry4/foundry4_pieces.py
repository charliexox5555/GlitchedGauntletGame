"""Foundry4 kit (2026-11-21): a steel works at night in the RIVALS style (vault/01 Design/Maps/Foundry4.md).

RIVALS build study (Museum, Docks): chunky hard-surface meshes with big flat chamfers, clean silhouettes, simple stepped
details (bands, ribs, flanges) instead of noise, flat colours. So every piece here is a few big masses with 1-segment
chamfers (0.06-0.14), round forms are 8-12 flat facets, nothing photo-real. Every part overlaps the part that carries it
and never shares a plane with it. Pieces that are placed in both halves are symmetric in local X (the map mirrors
z -> -z; Studio mirrors a piece by turning it, so only X-symmetric pieces mirror exactly).

    python tools/blender/lobby_v4/send.py tools/blender/maps_foundry4/run_foundry4.py --port 9897 --pid <pid>

Pieces (Map_<Piece>, export group Kit of map Foundry4). Units: studs; +X right, +Y front (Roblox -Z), +Z up; origin
bottom centre unless noted.
  F4Furnace    the blast furnace (landmark): 12-facet hearth, bosh and tapering stack with bands and stave seams,
               the bustle pipe and tuyeres, the hot blast mains to both stoves (+-Y) on trestles, the top platform with
               rails, four uptakes, the downcomer (-X), the tap block and spout (+X, runner side).
  F4Stove      a hot blast stove (r 6, 37.6 tall): plinth, banded shell, faceted dome, a platform ring, manholes.
  F4Ladle      the ladle: tapered 12-facet bucket, bands, trunnions, lip spout (+X), molten top.
  F4LadleCar   the ladle car (track along Y, gauge 5.2): chassis, outriggers, cradle arms, seat, 8 wheels, buffers.
  F4Crane      the overhead crane (span along Y, 58): two yellow box girders with ribs, end trucks, trolley, hoist,
               hook block + hook, operator cab (+X), cross beams and hangers carrying the walkway (x -6..-2, z 12).
               Origin = runway rail top centre at z 0 (Studio puts it at +21.4).
  F4Stair12    a steel stair rising 12 over 20 toward +Y, 4 wide: channel stringers, 16 treads, posts, rails (3.2).
  F4Rail4      a 4-long catwalk railing (along X, no posts): top rail 3.2, mid rail, toe plate.  F4Post: its post.
  F4Coil       a steel coil, axis along X (2.6 wide, 4.8 across), two straps.
  F4IngotCart  a rail car (track along X) with three ingot moulds (8 tall).
  F4Loco       the shunting loco (along Y, 7.2 x 16 x 11): hood, cab with windows, frame, wheels, rails, buffers.
               Its body paint is F4_Paint (team colour in Studio).
  F4OxyTanks   three gas cylinders (the cage is Parts in Studio).
  F4Chimney    a background stack (60 tall), banded, with a red-and-white top.
  F4SlabPile2 / F4SlabPile6   slab piles on concrete footings and steel cradles (3.22 / 8.02 tall).
  F4RollerDoor a roller shutter door for an 11.2 x 11.5 opening (frame, coil housing, cut-in slats, control box).
Our own designs (RIVALS meshes used in Studio are listed in the map note).
"""
from math import cos, pi, sin

import bmesh
import bpy
from mathutils import Matrix, Vector

import arena_kit as A
import greenhouse4_pieces as G
import snowcat_model as SC

cube, prism, bar, cyl, ngon2 = SC.cube, SC.prism, SC.bar, SC.cyl, SC.ngon2
loft, ring, cone, slab, obj, box_uv = G.loft, G.ring, G.cone, G.slab, G.obj, G.box_uv

ROOT = "Foundry4Kit"
A.PAL.update(
	{
		"F4_Steel": ("#4B525C", 0.7),
		"F4_SteelDark": ("#30353C", 0.75),
		"F4_SteelLight": ("#A6AEB7", 0.5),
		"F4_Pipe": ("#5D6F7A", 0.7),
		"F4_Yellow": ("#E2A62C", 0.6),
		"F4_Black": ("#25272B", 0.8),
		"F4_Rust": ("#9A5734", 0.8),
		"F4_Glow": ("#FF7A1F", 0.3),
		"F4_GlowHot": ("#FFC05A", 0.3),
		"F4_Refractory": ("#6E4A3C", 0.9),
		"F4_Concrete": ("#8C8A85", 0.9),
		"F4_Grate": ("#5A6169", 0.7),
		"F4_Glass": ("#26323C", 0.2),
		"F4_Rubber": ("#2A2A2A", 0.9),
		"F4_Paint": ("#C4553A", 0.6),
		"F4_White": ("#D8D6D0", 0.6),
		"F4_Red": ("#B7402F", 0.6),
		"F4_Lamp": ("#F2C98A", 0.4),
		"F4_Wood": ("#8A6A48", 0.85),
		"F4_Marking": ("#C98A2E", 0.6),
	}
)
RBX = {
	"F4_Glow": "Neon",
	"F4_GlowHot": "Neon",
	"F4_Lamp": "Neon",
	"F4_Grate": "DiamondPlate",
	"F4_Glass": "Glass",
	"F4_Concrete": "Concrete",
	"F4_Wood": "Wood",
}
TRANSPARENT = {}

N = 12  # facets for round forms (flat faces at 0, 30, 60 ... degrees, so +X is a flat face)
ROT12 = pi / 12


def fr(r):
	"""Flat (apothem) radius of a 12-gon with vertex radius r."""
	return r * cos(pi / 12)


def bands(b, prof_r, zs, h, out, mi, n=N):
	"""Protruding bands round a faceted body; prof_r(z) gives the body's vertex radius at z."""
	for z in zs:
		r = max(prof_r(z), prof_r(z + h))
		ring(b, r + out, r - 0.4, z, z + h, n, mi, rot=pi / n)


def ringx(b, r_out, r_in, x0, x1, n, mi, cy=0.0, cz=0.0, rot=None):
	"""A ring about the X axis (in the YZ plane)."""
	rot = pi / n if rot is None else rot
	o, i = ngon2(cy, cz, r_out, n, rot), ngon2(cy, cz, r_in, n, rot)
	for k in range(n):
		prism(b, [o[k], o[(k + 1) % n], i[(k + 1) % n], i[k]], "x", x0, x1, mi)


def tube_ring(b, R, z, r, n_seg, mi, start=0.0, n_pipe=8):
	"""A faceted pipe ring (bustle pipe): n_seg straight tubes between points on a circle of radius R."""
	pts = [Vector((R * cos(start + 2 * pi * k / n_seg), R * sin(start + 2 * pi * k / n_seg), z)) for k in range(n_seg)]
	for k in range(n_seg):
		a, c = pts[k], pts[(k + 1) % n_seg]
		d = (c - a).normalized()
		cyl(b, a - d * r * 0.45, c + d * r * 0.45, r, n_pipe, mi)
	return pts


def pipe(b, p0, p1, r, mi, flange=None, n=8, every=0.0, fmi=None):
	"""A faceted pipe with optional flange rings at both ends (and every `every` studs)."""
	p0, p1 = Vector(p0), Vector(p1)
	cyl(b, p0, p1, r, n, mi)
	if flange:
		d = (p1 - p0)
		L = d.length
		d.normalize()
		ts = [0.0, L]
		if every:
			t = every
			while t < L - 0.5:
				ts.append(t)
				t += every
		for t in ts:
			c = p0 + d * min(max(t, 0.18), L - 0.18)
			cyl(b, c - d * 0.18, c + d * 0.18, r + flange, n, fmi if fmi is not None else mi)


def hazard(b, x0, x1, y0, y1, z0, z1, n, mi_a, mi_b, axis="x"):
	"""A beam in alternating stripes along `axis`."""
	for k in range(n):
		if axis == "x":
			a = x0 + (x1 - x0) * k / n
			c = x0 + (x1 - x0) * (k + 1) / n
			cube(b, a, c, y0, y1, z0, z1, mi_a if k % 2 == 0 else mi_b)
		else:
			a = y0 + (y1 - y0) * k / n
			c = y0 + (y1 - y0) * (k + 1) / n
			cube(b, x0, x1, a, c, z0, z1, mi_a if k % 2 == 0 else mi_b)


def railing(b, x0, x1, y, z, mi, mi_toe, posts=True):
	"""A catwalk railing along X at y, floor at z: top rail 3.2, mid rail 1.65, toe plate, posts every <=4."""
	cube(b, x0, x1, y - 0.11, y + 0.11, z + 3.0, z + 3.22, mi)
	cube(b, x0, x1, y - 0.07, y + 0.07, z + 1.58, z + 1.72, mi)
	cube(b, x0, x1, y - 0.05, y + 0.05, z - 0.02, z + 0.36, mi_toe)
	if posts:
		n = max(1, int((x1 - x0) / 4.0 + 0.999))
		for k in range(n + 1):
			x = x0 + (x1 - x0) * k / n
			x = min(max(x, x0 + 0.13), x1 - 0.13)
			cube(b, x - 0.13, x + 0.13, y - 0.13, y + 0.13, z - 0.03, z + 3.18, mi)


# ------------------------------------------------------------------------------------------------ the blast furnace
def furnace(coll):
	b = bmesh.new()
	ST, SD, PI, YE, CO, GR, GL, GH, RF, BK = range(10)
	# plinth and hearth
	loft(b, [(11.6, 0.0), (11.6, 1.0), (10.9, 1.25)], N, CO, rot=ROT12)

	def shell_r(z):
		if z <= 9.0:
			return 10.0
		if z <= 15.5:
			return 10.0 + (z - 9.0) / 6.5 * 1.6
		if z <= 17.0:
			return 11.6
		if z <= 40.0:
			return 11.6 - (z - 17.0) / 23.0 * 4.0
		return 7.6

	loft(b, [(10.0, 1.1), (10.0, 9.0), (11.6, 15.5), (11.6, 17.0), (7.6, 40.0), (7.6, 42.2), (5.4, 46.0), (5.4, 46.6)], N, ST, rot=ROT12)
	bands(b, shell_r, [2.4, 5.0, 7.6], 0.7, 0.35, SD)
	bands(b, shell_r, [15.6, 21.0, 27.0, 33.0, 38.4], 0.7, 0.32, SD)
	# stave seams on the stack: bars down the facet edges
	for k in range(N):
		a = ROT12 + 2 * pi * k / N
		p0 = Vector((11.62 * cos(a), 11.62 * sin(a), 17.1))
		p1 = Vector((7.62 * cos(a), 7.62 * sin(a), 40.0))
		bar(b, p0, p1, 0.34, 0.34, SD)
	# bustle pipe and tuyeres (above head height)
	pts = tube_ring(b, 13.6, 11.8, 1.05, N, PI)
	for k, p in enumerate(pts):
		a = 2 * pi * k / N
		q = Vector((10.2 * cos(a), 10.2 * sin(a), 8.4))
		mid = Vector((13.2 * cos(a), 13.2 * sin(a), 10.6))
		cyl(b, p + Vector((0, 0, -0.6)), mid, 0.42, 6, SD)
		cyl(b, mid, q, 0.36, 6, SD)
		cube(b, q.x - 0.45, q.x + 0.45, q.y - 0.45, q.y + 0.45, q.z - 0.45, q.z + 0.45, BK)
	# hot blast mains to both stoves (+-Y), risers from the bustle pipe, trestles at |y| 36
	for s in (-1, 1):
		pipe(b, (0, s * 13.6, 12.6), (0, s * 13.6, 24.0), 1.5, PI, 0.25, every=0)
		pipe(b, (0, s * 12.4, 24.0), (0, s * 42.8, 24.0), 1.7, PI, 0.26, every=7.0, fmi=SD)
		cube(b, -1.75, 1.75, s * 13.6 - 1.75, s * 13.6 + 1.75, 22.4, 25.7, SD)  # the elbow box
		for x in (-1.7, 1.7):
			cube(b, x - 0.35, x + 0.35, s * 36 - 0.35, s * 36 + 0.35, 0.0, 22.5, YE)
		for z in (6.0, 12.0, 18.0):
			cube(b, -2.0, 2.0, s * 36 - 0.25, s * 36 + 0.25, z - 0.25, z + 0.25, YE)
		cube(b, -2.3, 2.3, s * 36 - 1.2, s * 36 + 1.2, 22.2, 22.6, SD)
		loft(b, [(0.75, 0.0), (0.75, 0.35)], 8, CO, cx=-1.7, cy=s * 36)
		loft(b, [(0.75, 0.0), (0.75, 0.35)], 8, CO, cx=1.7, cy=s * 36)
	# top platform ring with railing posts and rail
	ring(b, 10.6, 7.3, 41.7, 42.1, N, GR, rot=ROT12)
	for k in range(N):
		a = ROT12 + 2 * pi * k / N
		bar(b, (8.6 * cos(a), 8.6 * sin(a), 40.2), (7.4 * cos(a), 7.4 * sin(a), 38.0), 0.3, 0.3, SD)  # brackets
		cube(b, 10.3 * cos(a) - 0.13, 10.3 * cos(a) + 0.13, 10.3 * sin(a) - 0.13, 10.3 * sin(a) + 0.13, 42.05, 45.2, YE)
	ring(b, 10.45, 10.15, 44.95, 45.22, N, YE, rot=ROT12)
	ring(b, 10.4, 10.2, 43.5, 43.65, N, YE, rot=ROT12)
	# four uptakes, bleeder valves, the crossover and the downcomer (-X, into the dust catcher behind)
	for x, y in ((2.6, 2.6), (-2.6, 2.6), (2.6, -2.6), (-2.6, -2.6)):
		pipe(b, (x, y, 45.0), (x, y, 55.0), 0.9, PI, 0.18)
		cube(b, x - 0.75, x + 0.75, y - 0.75, y + 0.75, 55.0, 56.3, SD)
		cone(b, 0.75, 56.3, 57.2, 4, SD, rot=pi / 4, cx=x, cy=y)
	pipe(b, (-2.6, -3.5, 53.0), (-2.6, 3.5, 53.0), 1.0, PI, 0.2)
	pipe(b, (2.6, -3.5, 53.0), (2.6, 3.5, 53.0), 1.0, PI, 0.2)
	pipe(b, (3.4, 0, 53.0), (-3.6, 0, 53.0), 1.15, PI, 0.2)
	pipe(b, (-3.0, 0, 53.4), (-16.0, 0, 30.0), 1.4, PI, 0.24, every=8.0, fmi=SD)
	# the tap block and the spout (+X): the runner starts at x 13.6
	cube(b, 9.2, 11.4, -2.0, 2.0, 0.6, 4.2, BK)
	cube(b, 11.3, 11.48, -0.55, 0.55, 1.2, 2.3, GH)
	prism(b, [(11.3, -1.5), (13.7, -1.5), (13.7, 1.5), (11.3, 1.5)], "z", 0.0, 0.9, RF)
	cube(b, 11.3, 13.72, -1.5, -1.05, 0.85, 1.6, RF)
	cube(b, 11.3, 13.72, 1.05, 1.5, 0.85, 1.6, RF)
	cube(b, 11.25, 13.74, -1.08, 1.08, 0.8, 1.02, GL)
	# a hood over the tap
	prism(b, [(9.0, 4.6), (12.4, 4.6), (12.0, 6.2), (9.0, 6.6)], "y", -2.6, 2.6, SD)
	return [obj("F4Furnace", b, ["F4_Steel", "F4_SteelDark", "F4_Pipe", "F4_Yellow", "F4_Concrete", "F4_Grate", "F4_Glow", "F4_GlowHot", "F4_Refractory", "F4_Black"], coll, 0.12)]


# ------------------------------------------------------------------------------------------------ hot blast stove
def stove(coll):
	b = bmesh.new()
	ST, SD, CO, GR, YE, BK = range(6)
	loft(b, [(6.7, 0.0), (6.7, 1.0), (6.2, 1.2)], N, CO, rot=ROT12)
	loft(b, [(6.0, 1.1), (6.0, 32.0), (5.6, 34.0), (4.5, 35.8), (2.7, 37.0), (0.9, 37.6)], N, ST, rot=ROT12)
	bands(b, lambda z: 6.0, [6.5, 12.5, 18.5, 24.5], 0.6, 0.32, SD)
	ring(b, 6.25, 5.6, 31.4, 32.2, N, SD, rot=ROT12)
	# the platform ring at 26.6 with a rail
	ring(b, 8.0, 5.8, 26.2, 26.6, N, GR, rot=ROT12)
	for k in range(N):
		a = ROT12 + 2 * pi * k / N
		bar(b, (7.0 * cos(a), 7.0 * sin(a), 26.25), (6.0 * cos(a), 6.0 * sin(a), 24.6), 0.28, 0.28, SD)
		cube(b, 7.75 * cos(a) - 0.12, 7.75 * cos(a) + 0.12, 7.75 * sin(a) - 0.12, 7.75 * sin(a) + 0.12, 26.55, 29.7, YE)
	ring(b, 7.9, 7.6, 29.5, 29.75, N, YE, rot=ROT12)
	# manholes (+-X) and the burner box (-X)
	for s in (-1, 1):
		cube(b, s * 5.75, s * 6.25, -1.1, 1.1, 2.4, 5.0, SD)
		cube(b, s * 6.2, s * 6.34, -0.7, 0.7, 2.8, 4.6, BK)
	cube(b, 5.5, 8.2, -1.8, 1.8, 1.0, 5.6, SD)
	return [obj("F4Stove", b, ["F4_Pipe", "F4_SteelDark", "F4_Concrete", "F4_Grate", "F4_Yellow", "F4_Black"], coll, 0.1)]


# ------------------------------------------------------------------------------------------------ ladle and car
# Owner 2026-11-21 (first kit look): the ladle, ladle car and loco read as "curved boxes" with parts that don't line up
# or sit flush. Rebuilt: flat-shaded facets (every facet a plane), bands and lips revolved from one profile so they
# follow the body exactly, pads lying on their facet, pins seated in saddles, panels and louvres cut into the body
# (recessed), rails running stanchion to stanchion, buffer beams one piece below the deck line.
def revolve(b, prof, n, mi, rot=None, cx=0.0, cy=0.0):
	"""A closed ring solid: the closed (r, z) profile `prof` swept round n flat facets."""
	rot = pi / n if rot is None else rot
	rings = [[b.verts.new((cx + r * cos(rot + 2 * pi * k / n), cy + r * sin(rot + 2 * pi * k / n), z)) for k in range(n)] for r, z in prof]
	m = len(prof)
	for i in range(m):
		a, c = rings[i], rings[(i + 1) % m]
		for k in range(n):
			b.faces.new((a[k], a[(k + 1) % n], c[(k + 1) % n], c[k])).material_index = mi


def loop_prism(b, inner, outer, mi):
	"""A solid between two matching 3-D loops (caps + sides)."""
	vi = [b.verts.new(q) for q in inner]
	vo = [b.verts.new(q) for q in outer]
	n = len(inner)
	b.faces.new(list(reversed(vi))).material_index = mi
	b.faces.new(vo).material_index = mi
	for k in range(n):
		b.faces.new((vi[k], vi[(k + 1) % n], vo[(k + 1) % n], vo[k])).material_index = mi


def cham_sq(cx, cz, hw, hh, c):
	"""A rectangle with all four corners cut (8 points)."""
	return [(cx - hw + c, cz - hh), (cx + hw - c, cz - hh), (cx + hw, cz - hh + c), (cx + hw, cz + hh - c),
		(cx + hw - c, cz + hh), (cx - hw + c, cz + hh), (cx - hw, cz + hh - c), (cx - hw, cz - hh + c)]


def yprism(b, pts, y0, y1, mi):
	prism(b, pts, "y", min(y0, y1), max(y0, y1), mi)


def wheelset(b, ys, gauge, r, mi_w, mi_h, mi_a):
	"""Wheels (12 flat facets) with an inboard flange, hubs, axles; centres at z = r."""
	for y in ys:
		for s in (-1, 1):
			x = s * gauge / 2
			cyl(b, (x - 0.25, y, r), (x + 0.25, y, r), r, 12, mi_w)
			xf = x - s * 0.25
			cyl(b, (min(xf, xf - s * 0.08), y, r), (max(xf, xf - s * 0.08), y, r), r + 0.12, 12, mi_w)
			cyl(b, (x - 0.33, y, r), (x + 0.33, y, r), 0.36, 8, mi_h)
		bar(b, (-gauge / 2 + 0.2, y, r), (gauge / 2 - 0.2, y, r), 0.28, 0.28, mi_a)


LR0, LR1, LZ0, LZ1 = 3.75, 4.85, 0.6, 7.35  # ladle body: vertex radius 3.75 at z 0.6 to 4.85 at z 7.35


def lad_r(z):
	return LR0 + (z - LZ0) * (LR1 - LR0) / (LZ1 - LZ0)


def ladle(coll):
	b = bmesh.new()
	SD, RU, GL, BK = range(4)
	c15 = cos(pi / 12)
	revolve(b, [(3.25, 0.0), (3.75, 0.0), (3.92, 0.17), (3.92, 0.52), (3.75, 0.7), (3.25, 0.7)], N, BK, rot=ROT12)
	loft(b, [(LR0, LZ0), (LR1, LZ1)], N, SD, rot=ROT12)
	# the lip: one revolved ring, chamfered outside; the molten metal 0.35 below its top
	revolve(b, [(4.55, 7.22), (5.12, 7.22), (5.42, 7.48), (5.42, 7.92), (5.22, 8.1), (4.55, 8.1)], N, SD, rot=ROT12)
	loft(b, [(4.6, 7.3), (4.6, 7.75)], N, GL, rot=ROT12)
	# two bands that follow the taper (inner face inside the body, chamfered outer edges)
	for z0, z1 in ((1.75, 2.55), (6.25, 6.95)):
		t = 0.26
		revolve(b, [(lad_r(z0) - 0.15, z0), (lad_r(z0) + 0.14, z0), (lad_r(z0 + 0.12) + t, z0 + 0.12),
			(lad_r(z1 - 0.12) + t, z1 - 0.12), (lad_r(z1) + 0.14, z1), (lad_r(z1) - 0.15, z1)], N, RU, rot=ROT12)
	# trunnion pads lying on the +-Y facets (between the bands), pins with a collar and a cut end
	outline = [(-0.95, 3.05), (0.95, 3.05), (0.95, 5.55), (0.6, 5.95), (-0.6, 5.95), (-0.95, 5.55)]
	for s in (-1, 1):
		inner = [Vector((x, s * (lad_r(z) * c15 - 0.06), z)) for x, z in outline]
		outer = [Vector((x, s * (lad_r(z) * c15 + 0.3), z)) for x, z in outline]
		if s < 0:
			inner, outer = list(reversed(inner)), list(reversed(outer))
		loop_prism(b, inner, outer, RU)
		y0 = lad_r(5.0) * c15 + 0.25
		cyl(b, (0, s * y0, 5.0), (0, s * 6.0, 5.0), 0.72, 8, BK)
		cyl(b, (0, s * 5.0, 5.0), (0, s * 5.28, 5.0), 0.98, 8, BK)
		cyl(b, (0, s * 5.98, 5.0), (0, s * 6.16, 5.0), 0.52, 8, BK)
	# the lip spout (+X): a U channel flush with the lip top, its underside cut back into the body
	sp = [(4.9, 6.95), (5.35, 7.22), (6.95, 7.92), (6.95, 8.1), (4.95, 8.1)]
	fl = [(4.9, 6.95), (5.35, 7.22), (6.95, 7.72), (6.95, 7.9), (4.95, 7.9)]
	for s in (-1, 1):
		yprism(b, sp, s * 0.45, s * 0.98, SD)
	yprism(b, fl, -0.47, 0.47, SD)
	cube(b, 4.7, 6.9, -0.46, 0.46, 7.86, 7.94, GL)
	return [obj("F4Ladle", b, ["F4_SteelDark", "F4_Rust", "F4_Glow", "F4_Black"], coll, 0.04)]


def ladle_car(coll):
	"""The ladle car (track along Y, gauge 5.2, rail top z 0). Deck top 2.95; the ladle stands on the deck inside
	the seat ring; its pins (z 7.95, |y| 5.6-6.0) lie in the trestle saddles."""
	b = bmesh.new()
	YE, SD, BK, RB = range(4)
	wheelset(b, (-4.6, -1.8, 1.8, 4.6), 5.2, 1.0, RB, SD, SD)
	for s in (-1, 1):
		sole = [(s * 3.0, 1.2), (s * 3.35, 1.2), (s * 3.55, 1.45), (s * 3.55, 2.5), (s * 3.0, 2.5)]
		yprism(b, sole if s > 0 else list(reversed(sole)), -6.6, 6.6, SD)
		for y in (-4.6, -1.8, 1.8, 4.6):
			# the axle box: one cut-cornered cap on the hub line, its top seated in the solebar
			prism(b, cham_sq(y, 1.0, 0.45, 0.42, 0.14), "x", min(s * 2.84, s * 3.12), max(s * 2.84, s * 3.12), BK)
	yprism(b, [(-4.3, 2.45), (4.3, 2.45), (4.3, 2.75), (4.05, 2.95), (-4.05, 2.95), (-4.3, 2.75)], -6.6, 6.6, SD)
	for s in (-1, 1):
		hazard(b, -4.3, 4.3, min(s * 6.6, s * 7.2), max(s * 6.6, s * 7.2), 1.3, 2.8, 8, YE, BK, axis="x")
		for x in (-2.6, 2.6):
			cyl(b, (x, s * 7.15, 2.05), (x, s * 7.75, 2.05), 0.36, 8, SD)
			yprism(b, cham_sq(x, 2.05, 0.62, 0.62, 0.2), s * 7.7, s * 7.95, BK)
	# the seat ring the ladle's foot stands in
	revolve(b, [(3.85, 2.9), (4.45, 2.9), (4.45, 3.25), (4.25, 3.45), (3.85, 3.45)], N, YE, rot=ROT12)
	# trestles with saddles for the pins (|y| 5.58..6.0), cheeks either side of the pin, a foot plate
	for s in (-1, 1):
		ya, yb = s * 5.58, s * 6.0
		yprism(b, [(-1.5, 2.9), (1.5, 2.9), (0.95, 7.285), (-0.95, 7.285)], ya, yb, YE)
		for c in (-1, 1):
			ch = [(c * 0.75, 7.25), (c * 1.0, 7.25), (c * 1.0, 8.15), (c * 0.85, 8.3), (c * 0.75, 8.3)]
			yprism(b, ch if c > 0 else list(reversed(ch)), ya, yb, YE)
		cube(b, -1.7, 1.7, min(ya, yb) - 0.25, max(ya, yb) + 0.25, 2.9, 3.15, SD)
	return [obj("F4LadleCar", b, ["F4_Yellow", "F4_SteelDark", "F4_Black", "F4_Rubber"], coll, 0.04)]


# ------------------------------------------------------------------------------------------------ the overhead crane
def crane(coll):
	b = bmesh.new()
	YE, SD, BK, GL, RB, LP = range(6)
	SPAN = 29.0
	for x in (-2.6, 2.6):
		cube(b, x - 0.8, x + 0.8, -SPAN + 1.0, SPAN - 1.0, 1.2, 4.2, YE)
		cube(b, x - 1.0, x + 1.0, -SPAN + 1.0, SPAN - 1.0, 4.15, 4.45, YE)  # top flange
		cube(b, x - 1.0, x + 1.0, -SPAN + 1.0, SPAN - 1.0, 0.95, 1.25, YE)  # bottom flange
		y = -SPAN + 4.0
		while y < SPAN - 3.0:
			for s in (-1, 1):
				cube(b, x + s * 0.78 - 0.08, x + s * 0.78 + 0.08, y - 0.12, y + 0.12, 1.25, 4.15, YE)
			y += 4.0
	# end trucks on the runway rails (at y +-SPAN), wheels
	for s in (-1, 1):
		cube(b, -4.6, 4.6, s * SPAN - 1.4, s * SPAN + 1.4, 0.6, 4.6, YE)
		hazard(b, -4.65, 4.65, s * SPAN - 1.45, s * SPAN + 1.45, 3.7, 4.3, 8, BK, YE)
		for x in (-3.4, 3.4):
			cyl(b, (x, s * SPAN - 0.25, 0.75), (x, s * SPAN + 0.25, 0.75), 0.75, 10, SD)
		cube(b, -4.8, -4.4, s * SPAN - 1.0, s * SPAN + 1.0, 1.6, 3.8, BK)
		cube(b, 4.4, 4.8, s * SPAN - 1.0, s * SPAN + 1.0, 1.6, 3.8, BK)
	# trolley with the hoist over the runner (y 0)
	cube(b, -3.6, 3.6, -2.6, 2.6, 4.45, 5.6, SD)
	for x in (-3.4, 3.4):
		for y in (-2.0, 2.0):
			cyl(b, (x - 0.2, y, 4.9), (x + 0.2, y, 4.9), 0.5, 8, BK)
	cyl(b, (-2.4, 0, 6.6), (2.4, 0, 6.6), 1.05, 10, SD)
	ringx(b, 1.25, 0.9, -2.5, -2.2, 10, YE, cz=6.6)
	ringx(b, 1.25, 0.9, 2.2, 2.5, 10, YE, cz=6.6)
	cube(b, -1.6, 1.6, 1.4, 3.4, 5.5, 7.6, YE)  # motor
	cube(b, -1.2, 1.2, -3.2, -1.4, 5.5, 6.9, BK)
	# cables and hook block (hangs to z -7.8, i.e. +13.6 in the map)
	for x in (-0.55, 0.55):
		for y in (-0.3, 0.3):
			bar(b, (x, y, 5.6), (x * 0.9, y, -5.2), 0.08, 0.08, BK)
	cube(b, -1.0, 1.0, -0.7, 0.7, -6.8, -5.0, YE)
	cyl(b, (-1.12, 0, -5.6), (-0.95, 0, -5.6), 0.9, 8, SD)
	cyl(b, (0.95, 0, -5.6), (1.12, 0, -5.6), 0.9, 8, SD)
	hazard(b, -1.02, 1.02, -0.72, 0.72, -6.6, -5.2, 4, YE, BK)
	bar(b, (0, 0, -6.8), (0, 0, -7.6), 0.42, 0.42, SD)
	bar(b, (0, 0, -7.5), (0, 0.0, -8.9), 0.5, 0.5, SD)
	bar(b, (0, 0.0, -8.75), (0, 0.9, -9.3), 0.5, 0.5, SD)
	bar(b, (0, 0.85, -9.35), (0, 1.25, -8.5), 0.46, 0.46, SD)
	# operator cab (+X), under the girders
	cube(b, 3.2, 6.6, -1.8, 1.8, -3.0, 0.98, SD)
	cube(b, 3.1, 6.7, -1.9, 1.9, 0.9, 1.3, YE)
	cube(b, 6.55, 6.7, -1.4, 1.4, -1.9, 0.3, GL)
	for s in (-1, 1):
		cube(b, 3.6, 6.2, s * 1.75, s * 1.88, -1.9, 0.3, GL)
	cube(b, 4.2, 5.6, -1.82, 1.82, -3.2, -2.9, LP)
	# cross beams under the girders every 8 (out to x -6.4) and hangers down to the walkway (z -9.4 = map +12)
	y = -24.0
	while y <= 24.01:
		cube(b, -6.6, 3.4, y - 0.4, y + 0.4, 0.2, 1.0, SD)
		for x in (-6.15, -1.85):
			cube(b, x - 0.16, x + 0.16, y - 0.16, y + 0.16, -9.55, 0.25, YE)
		y += 8.0
	return [obj("F4Crane", b, ["F4_Yellow", "F4_SteelDark", "F4_Black", "F4_Glass", "F4_Rubber", "F4_Lamp"], coll, 0.08)]


# ------------------------------------------------------------------------------------------------ stair, rails
def stair12(coll):
	b = bmesh.new()
	YE, GR, SD = range(3)
	RISE, RUN, W, NT = 12.0, 20.0, 4.0, 16
	for s in (-1, 1):
		x = s * (W / 2 - 0.12)
		bar(b, (x, -RUN / 2 - 0.3, 0.25), (x, RUN / 2 - 0.05, RISE - 0.35), 0.26, 1.0, SD, up=Vector((0, 0, 1)))
	for k in range(NT):
		z = (k + 1) * RISE / NT
		y0 = -RUN / 2 + k * RUN / NT
		cube(b, -W / 2 + 0.24, W / 2 - 0.24, y0 + 0.02, y0 + RUN / NT + 0.04, z - 0.18, z - 0.02, GR)
	# rails: posts every 4 treads, sloped top rail 3.2 above the nosing, mid rail
	for s in (-1, 1):
		x = s * (W / 2 - 0.1)
		for k in (0, 4, 8, 12, 15):
			y = -RUN / 2 + (k + 0.5) * RUN / NT
			z = (k + 1) * RISE / NT
			cube(b, x - 0.12, x + 0.12, y - 0.12, y + 0.12, z - 0.3, z + 3.15, YE)
		ya, yb = -RUN / 2 + 0.5 * RUN / NT, -RUN / 2 + 15.5 * RUN / NT
		za, zb = RISE / NT, RISE
		bar(b, (x, ya - 0.1, za + 3.1), (x, yb + 0.1, zb + 3.1), 0.2, 0.2, YE)
		bar(b, (x, ya, za + 1.6), (x, yb, zb + 1.6), 0.13, 0.13, YE)
	return [obj("F4Stair12", b, ["F4_Yellow", "F4_Grate", "F4_SteelDark"], coll, 0.04)]


def rail4(coll):
	b = bmesh.new()
	YE, SD = range(2)
	railing(b, -2.0, 2.0, 0.0, 0.0, YE, SD, posts=False)
	return [obj("F4Rail4", b, ["F4_Yellow", "F4_SteelDark"], coll, 0.03)]


def post(coll):
	b = bmesh.new()
	YE = 0
	cube(b, -0.15, 0.15, -0.15, 0.15, 0.0, 3.28, YE)
	cube(b, -0.2, 0.2, -0.2, 0.2, 3.25, 3.36, YE)
	return [obj("F4Post", b, ["F4_Yellow"], coll, 0.03)]


# ------------------------------------------------------------------------------------------------ yard props
def coil(coll):
	b = bmesh.new()
	SL, SD, BL = range(3)
	R = 2.4
	cz = fr(R) + 0.0
	ringx(b, R, 0.95, -1.3, 1.3, N, SL, cz=cz)
	ringx(b, 1.0, 0.9, -1.25, 1.25, N, SD, cz=cz)
	for x in (-0.65, 0.55):
		ringx(b, R + 0.07, 0.86, x, x + 0.14, N, BL, cz=cz)
	return [obj("F4Coil", b, ["F4_SteelLight", "F4_SteelDark", "F4_Pipe"], coll, 0.06)]


def ingot_cart(coll):
	"""The ingot-mould car (track along Y, gauge 4.0, rail top z 0; Studio turns it to run along X). Three square
	moulds stand on the deck, each a tapered body with a foot flange, a top rim, lifting lugs and the glowing ingot
	set into the rim. 7.8 tall."""
	b = bmesh.new()
	SD, BK, RB, GL, YE = range(5)
	R2 = 2 ** 0.5
	wheelset(b, (-3.8, 3.8), 4.0, 0.75, RB, SD, SD)
	for s in (-1, 1):
		sole = [(s * 2.05, 0.95), (s * 2.3, 0.95), (s * 2.45, 1.15), (s * 2.45, 1.75), (s * 2.05, 1.75)]
		yprism(b, sole if s > 0 else list(reversed(sole)), -5.5, 5.5, SD)
		for y in (-3.8, 3.8):
			prism(b, cham_sq(y, 0.75, 0.38, 0.34, 0.12), "x", min(s * 2.22, s * 2.46), max(s * 2.22, s * 2.46), BK)
		hazard(b, -2.45, 2.45, min(s * 5.5, s * 6.0), max(s * 5.5, s * 6.0), 0.9, 1.85, 6, YE, BK, axis="x")
		for x in (-1.5, 1.5):
			cyl(b, (x, s * 5.95, 1.35), (x, s * 6.4, 1.35), 0.26, 8, SD)
			yprism(b, cham_sq(x, 1.35, 0.42, 0.42, 0.13), s * 6.35, s * 6.55, BK)
	yprism(b, [(-2.45, 1.7), (2.45, 1.7), (2.45, 1.85), (2.3, 2.0), (-2.3, 2.0), (-2.45, 1.85)], -5.5, 5.5, SD)
	for y in (-3.6, 0.0, 3.6):
		revolve(b, [(1.2 * R2, 1.95), (1.74 * R2, 1.95), (1.74 * R2, 2.18), (1.6 * R2, 2.32), (1.2 * R2, 2.32)], 4, SD, rot=pi / 4, cy=y)
		loft(b, [(1.52 * R2, 2.2), (1.24 * R2, 7.3)], 4, BK, rot=pi / 4, cy=y)
		revolve(b, [(1.02 * R2, 7.15), (1.42 * R2, 7.15), (1.42 * R2, 7.62), (1.3 * R2, 7.8), (1.02 * R2, 7.8)], 4, SD, rot=pi / 4, cy=y)
		loft(b, [(1.08 * R2, 7.25), (1.08 * R2, 7.58)], 4, GL, rot=pi / 4, cy=y)
		for sx in (-1, 1):
			prism(b, cham_sq(y, 5.8, 0.42, 0.36, 0.12), "x", min(sx * 1.25, sx * 1.62), max(sx * 1.25, sx * 1.62), SD)
	return [obj("F4IngotCart", b, ["F4_SteelDark", "F4_Black", "F4_Rubber", "F4_Glow", "F4_Yellow"], coll, 0.04)]


def loco(coll):
	"""The shunting loco (along Y, cab at +Y, rail top z 0). Body paint F4_Paint (team colour in Studio)."""
	b = bmesh.new()
	PA, SD, BK, GL, YE, RB, LP = range(7)
	wheelset(b, (-4.4, 0.0, 4.4), 5.2, 1.0, RB, SD, SD)
	for s in (-1, 1):
		sk = [(s * 2.95, 1.05), (s * 3.3, 1.05), (s * 3.45, 1.3), (s * 3.45, 1.95), (s * 2.95, 1.95)]
		yprism(b, sk if s > 0 else list(reversed(sk)), -7.4, 7.4, SD)
		for y in (-4.4, 0.0, 4.4):
			cube(b, min(s * 3.45, s * 3.53), max(s * 3.45, s * 3.53), y - 0.5, y + 0.5, 1.15, 1.85, BK)
	# walkway deck with a cut edge
	yprism(b, [(-3.4, 1.9), (3.4, 1.9), (3.4, 2.25), (3.25, 2.4), (-3.25, 2.4), (-3.4, 2.25)], -7.6, 7.6, SD)
	# buffer beams (the stripes are the beam itself), buffers, cut pilot plates under the beams
	for s in (-1, 1):
		hazard(b, -3.4, 3.4, min(s * 7.6, s * 8.2), max(s * 7.6, s * 8.2), 1.1, 2.3, 8, YE, BK, axis="x")
		for x in (-2.3, 2.3):
			cyl(b, (x, s * 8.15, 1.7), (x, s * 8.7, 1.7), 0.34, 8, SD)
			yprism(b, cham_sq(x, 1.7, 0.58, 0.58, 0.18), s * 8.65, s * 8.9, BK)
		pr = [(s * 7.6, 0.45), (s * 8.15, 0.95), (s * 8.15, 1.15), (s * 7.6, 1.15)]
		if s < 0:
			pr = list(reversed(pr))
		for x0 in (-3.1, 0.25):
			prism(b, pr, "x", x0, x0 + 2.85, SD)
	# the long hood (-Y): full section at the door frames, recessed section on the door panels, louvres in the recess
	full = [(-2.3, 2.35), (2.3, 2.35), (2.3, 6.0), (1.55, 6.85), (-1.55, 6.85), (-2.3, 6.0)]
	door = [(-2.17, 2.35), (2.17, 2.35), (2.17, 5.9), (2.3, 6.0), (1.55, 6.85), (-1.55, 6.85), (-2.3, 6.0), (-2.17, 5.9)]
	y = -6.9
	for L_, sec in ((0.35, full), (2.6, door), (0.35, full), (2.6, door), (0.35, full), (2.6, door), (0.65, full)):
		prism(b, sec, "y", y, y + L_, PA)
		if sec is door:
			for k in range(5):
				z = 3.5 + k * 0.48
				for s in (-1, 1):
					cube(b, min(s * 2.16, s * 2.27), max(s * 2.16, s * 2.27), y + 0.3, y + L_ - 0.3, z, z + 0.2, BK)
			for s in (-1, 1):
				cube(b, min(s * 2.16, s * 2.25), max(s * 2.16, s * 2.25), y + L_ / 2 - 0.08, y + L_ / 2 + 0.08, 2.9, 3.2, SD)
		y += L_
	# the nose: a radiator end one step smaller, grille bars, the headlight
	prism(b, [(-2.12, 2.35), (2.12, 2.35), (2.12, 5.85), (1.42, 6.65), (-1.42, 6.65), (-2.12, 5.85)], "y", -7.3, -6.85, SD)
	for k in range(6):
		z = 2.9 + k * 0.42
		cube(b, -1.8, 1.8, -7.36, -7.26, z, z + 0.18, BK)
	yprism(b, cham_sq(0.0, 5.45, 0.65, 0.4, 0.14), -7.5, -7.25, SD)
	yprism(b, cham_sq(0.0, 5.45, 0.48, 0.26, 0.1), -7.54, -7.45, LP)
	# exhaust stack through a flange, the fan ring on the hood top
	revolve(b, [(0.5, 6.8), (0.85, 6.8), (0.85, 6.95), (0.7, 7.05), (0.5, 7.05)], 8, SD, cx=0, cy=-4.8)
	loft(b, [(0.55, 6.8), (0.55, 8.2), (0.68, 8.35), (0.68, 8.55)], 8, BK, cx=0, cy=-4.8)
	revolve(b, [(0.75, 6.8), (1.15, 6.8), (1.15, 7.0), (1.0, 7.1), (0.75, 7.1)], 12, SD, rot=ROT12, cx=0, cy=-1.6)
	loft(b, [(0.8, 6.8), (0.8, 6.95)], 12, BK, rot=ROT12, cx=0, cy=-1.6)
	# the cab (+Y): lower body, window posts round a glass core set back, upper band, the cut roof
	cube(b, -3.1, 3.1, 2.6, 7.4, 2.35, 6.0, PA)
	cube(b, -2.98, 2.98, 2.72, 7.28, 5.95, 8.85, GL)
	for sx in (-1, 1):
		for y0, y1 in ((2.6, 3.05), (4.7, 5.3), (6.95, 7.4)):
			cube(b, min(sx * 2.62, sx * 3.1), max(sx * 2.62, sx * 3.1), y0, y1, 5.95, 8.85, PA)
	for y0, y1 in ((2.6, 3.05), (6.95, 7.4)):
		for x0, x1 in ((-3.1, -2.4), (-0.22, 0.22), (2.4, 3.1)):
			cube(b, x0, x1, y0, y1, 5.95, 8.85, PA)
	cube(b, -3.1, 3.1, 2.6, 7.4, 8.8, 9.5, PA)
	yprism(b, [(-3.35, 9.45), (3.35, 9.45), (3.35, 9.7), (2.9, 10.25), (-2.9, 10.25), (-3.35, 9.7)], 2.4, 7.6, SD)
	cube(b, -2.6, 2.6, 7.38, 7.46, 4.4, 4.8, YE)
	for s in (-1, 1):
		cube(b, min(s * 2.95, s * 3.6), max(s * 2.95, s * 3.6), 5.2, 6.6, 0.95, 1.1, SD)
		cube(b, min(s * 3.08, s * 3.18), max(s * 3.08, s * 3.18), 4.0, 4.12, 2.9, 5.6, YE)
	# handrails along the hood: stanchions on the deck, the rails exactly between the first and last stanchion
	for s in (-1, 1):
		x = s * 3.12
		for yy in (-7.2, -4.0, -0.8, 2.3):
			cube(b, x - 0.1, x + 0.1, yy - 0.1, yy + 0.1, 2.38, 5.32, YE)
		cube(b, x - 0.11, x + 0.11, -7.3, 2.4, 5.12, 5.32, YE)
		cube(b, x - 0.08, x + 0.08, -7.3, 2.4, 3.75, 3.9, YE)
	return [obj("F4Loco", b, ["F4_Paint", "F4_SteelDark", "F4_Black", "F4_Glass", "F4_Yellow", "F4_Rubber", "F4_Lamp"], coll, 0.04)]


def oxy_tanks(coll):
	"""Three gas cylinders (the cage and the plinth are Parts in Studio, owner 2026-11-21). Each one is a clean stack:
	a chamfered foot ring, the body, a white shoulder that steps 0.04 out, a faceted dome, the neck, a valve and a
	guard ring round it. Origin = the plinth top at the cage centre."""
	b = bmesh.new()
	BK, WH, SD = range(3)
	for cx, cy in ((-1.35, -1.2), (1.35, -1.2), (0.0, 1.25)):
		revolve(b, [(0.9, 0.0), (1.2, 0.0), (1.24, 0.08), (1.24, 0.24), (1.2, 0.3), (0.9, 0.3)], N, SD, rot=ROT12, cx=cx, cy=cy)
		loft(b, [(1.15, 0.25), (1.15, 6.2)], N, BK, rot=ROT12, cx=cx, cy=cy)
		loft(b, [(1.19, 6.16), (1.19, 6.8), (0.95, 7.35), (0.55, 7.7), (0.32, 7.78)], N, WH, rot=ROT12, cx=cx, cy=cy)
		loft(b, [(0.3, 7.7), (0.3, 8.2)], 8, SD, cx=cx, cy=cy)
		cube(b, cx - 0.22, cx + 0.22, cy - 0.45, cy + 0.45, 8.1, 8.45, SD)
		revolve(b, [(0.5, 7.72), (0.62, 7.72), (0.62, 8.5), (0.5, 8.5)], 8, SD, cx=cx, cy=cy)
	return [obj("F4OxyTanks", b, ["F4_Black", "F4_White", "F4_SteelDark"], coll, 0.04)]


def slab_pile(n):
	"""A slab pile, built like the RIVALS barriers (chunky, flat chamfers, one colour per material): two concrete
	footings with cut tops, a steel cradle beam on each (flanges and web), `n` identical slabs 8 x 0.9 x 3.6 stacked
	exactly, timber spacers between them on the cradle lines, the slabs' end faces spray-painted (the paint is the end
	face itself, nothing stuck on). Origin = bottom centre, slabs along X."""

	def build(coll):
		b = bmesh.new()
		SL, CO, SD, WD, PA = range(5)
		for x in (-2.6, 2.6):
			prism(b, [(-2.15, 0.0), (2.15, 0.0), (2.15, 0.38), (1.95, 0.5), (-1.95, 0.5), (-2.15, 0.38)], "x", x - 0.55, x + 0.55, CO)
			cube(b, x - 0.4, x + 0.4, -2.0, 2.0, 0.48, 0.62, SD)
			cube(b, x - 0.08, x + 0.08, -1.95, 1.95, 0.6, 1.02, SD)
			cube(b, x - 0.4, x + 0.4, -2.0, 2.0, 1.0, 1.14, SD)
		z = 1.12
		for k in range(n):
			if k:
				for x in (-2.6, 2.6):
					cube(b, x - 0.28, x + 0.28, -1.95, 1.95, z - 0.31, z + 0.01, WD)
			_vs, fs = cube(b, -4.0, 4.0, -1.8, 1.8, z, z + 0.9, SL)
			for f in fs:
				if len({round(v.co.x, 4) for v in f.verts}) == 1:
					f.material_index = PA
			z += 1.2
		return [obj("F4SlabPile%d" % n, b, ["F4_SteelLight", "F4_Concrete", "F4_SteelDark", "F4_Wood", "F4_Marking"], coll, 0.07)]

	return build


def roller_door(coll):
	"""A roller shutter door for an opening 11.2 wide x 11.5 tall in a wall whose face is the plane y = 0 (the door
	faces +Y = Roblox -Z). Chamfered steel jambs with guide channels, a coil housing with a cut lower front, a slatted
	curtain whose grooves are cut in (slats in front of a recessed back sheet), a rubber bottom rail, a control box
	with a status lamp. Origin = bottom centre of the opening on the wall face."""
	b = bmesh.new()
	SD, ST, SL, BK, YE, LP = range(6)
	for s in (-1, 1):
		jamb = [(s * 5.6, -0.1), (s * 6.4, -0.1), (s * 6.4, 0.6), (s * 6.1, 0.9), (s * 5.6, 0.9)]
		prism(b, jamb if s > 0 else list(reversed(jamb)), "z", 0.0, 12.0, SD)
		cube(b, min(s * 5.3, s * 5.62), max(s * 5.3, s * 5.62), 0.05, 0.6, 0.0, 11.6, BK)
	prism(b, [(-0.1, 11.5), (1.0, 11.5), (1.4, 11.9), (1.4, 13.0), (1.1, 13.4), (-0.1, 13.4)], "x", -6.5, 6.5, ST)
	cube(b, -5.42, 5.42, 0.08, 0.3, 0.3, 11.55, SD)
	k = 0
	z = 0.35
	while z < 11.4:
		cube(b, -5.4, 5.4, 0.12, 0.46, z + 0.07, min(z + 0.7, 11.52), SL)
		z += 0.7
		k += 1
	cube(b, -5.4, 5.4, 0.06, 0.62, 0.0, 0.36, BK)
	cube(b, 6.55, 7.45, -0.05, 0.5, 3.9, 5.3, ST)
	cube(b, 6.75, 7.25, 0.48, 0.56, 4.6, 5.0, LP)
	return [obj("F4RollerDoor", b, ["F4_SteelDark", "F4_Steel", "F4_SteelLight", "F4_Black", "F4_Yellow", "F4_Lamp"], coll, 0.05)]


def chimney(coll):
	b = bmesh.new()
	CO, SD, WH, RD = range(4)
	loft(b, [(5.4, 0.0), (5.4, 2.0), (4.6, 2.2)], N, CO, rot=ROT12)

	def r(z):
		return 4.5 - (z / 60.0) * 1.5

	loft(b, [(4.5, 2.0), (3.15, 46.0)], N, CO, rot=ROT12)
	loft(b, [(r(46.0), 45.9), (r(50.0), 50.0)], N, RD, rot=ROT12)
	loft(b, [(r(50.0), 49.9), (r(54.0), 54.0)], N, WH, rot=ROT12)
	loft(b, [(r(54.0), 53.9), (r(58.0), 58.0), (3.3, 58.0), (3.3, 59.0), (2.6, 59.0)], N, RD, rot=ROT12)
	bands(b, r, [10.0, 20.0, 30.0, 40.0], 0.5, 0.2, SD)
	return [obj("F4Chimney", b, ["F4_Concrete", "F4_SteelDark", "F4_White", "F4_Red"], coll, 0.1)]


PIECES = (
	"F4Furnace", "F4Stove", "F4Ladle", "F4LadleCar", "F4Crane", "F4Stair12", "F4Rail4", "F4Post", "F4Coil",
	"F4IngotCart", "F4Loco", "F4OxyTanks", "F4Chimney", "F4SlabPile2", "F4SlabPile6", "F4RollerDoor",
)
BUILD = {
	"F4Furnace": furnace, "F4Stove": stove, "F4Ladle": ladle, "F4LadleCar": ladle_car, "F4Crane": crane,
	"F4Stair12": stair12, "F4Rail4": rail4, "F4Post": post, "F4Coil": coil,
	"F4IngotCart": ingot_cart, "F4Loco": loco, "F4OxyTanks": oxy_tanks, "F4Chimney": chimney, "F4SlabPile2": slab_pile(2), "F4SlabPile6": slab_pile(6), "F4RollerDoor": roller_door,
}


def build_all():
	for c in [c for c in bpy.data.collections if c.name.startswith("Map_") and c.name[4:] in PIECES]:
		for o in list(c.all_objects):
			me = o.data
			bpy.data.objects.remove(o, do_unlink=True)
			if me is not None and me.users == 0:
				bpy.data.meshes.remove(me)
		bpy.data.collections.remove(c)
	root = A.coll(ROOT)
	made = []
	for n in PIECES:
		col = A.coll("Map_" + n, root)
		made += SC.finalize(BUILD[n](col), col)
	for o in made:
		for q in o.data.polygons:
			q.use_smooth = False  # every facet reads as a plane (gauntlet-build-style)
		if not o.data.uv_layers:
			box_uv(o, 6.0)
	for nm, (hx, _r) in A.PAL.items():
		m = bpy.data.materials.get(nm)
		if m is not None and nm.startswith("F4_"):
			m["rbx_material"] = RBX.get(nm, "SmoothPlastic")
			m["rbx_color"] = hx.lstrip("#").upper()
			if nm in TRANSPARENT:
				m["rbx_transparency"] = TRANSPARENT[nm]
	return {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in made}
