# build_mod_glitchvfx.py: the GlitchVFX kit, stylized meshes for the glitched upgrade levels (collection "GlitchVFX").
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
#       --python tools/blender/build_mod_glitchvfx.py -- [--render]
# Art Direction → "Ability VFX: stylized, mesh-first": bold shapes animated in code instead of piles of particles. Every
# part is one untextured mesh; code sets the colour (team / magenta glitch), Neon and transparency, scales it from its
# authored size (the installed MeshPart's Size) and pools it (src/client/Util/GlitchVfx.luau).
#
#   Crack_Energy      radial ground cracks (spiderweb), diameter 2, flat: the glowing lines
#   CrackGap          the same cracks wider and dark (Dark), drawn under Crack_Energy: the split floor
#   Rubble1..3        faceted rock chunks ~0.5-0.7 across (Shell; code gives them the floor's colour)
#   HexShell_Energy   the Barrier bubble: 92 inset hex / pent panels on a sphere r 1
#   HexEdge_Energy    the frame between those panels (thin ribbons at r 1.01)
#   HexTile_Energy    one loose hex panel (the shatter pieces), 1 across
#   ShellCrack_Energy crack lines on a cap of the r 1.02 sphere around Blender +Y (= Roblox -Z: CFrame.lookAt aims it)
#   ScanWave_Energy   a datamosh scan band: torn, stepped slabs around a ring r 1, 1 tall (Ping Spike)
#   Pixels_Energy     a tight voxel clump ~1 across (glitch static)
#   PixelSpray_Energy loose voxels spread over a 2-wide ball (static bursts)
#   Slivers_Energy    horizontal scanline slivers in a body-sized box 3 x 5.5 x 1 (glitch-outs, the crash ghost)
#   Streak_Energy     a bundle of staggered bars 4 long along Blender Y (= Roblox Z): dives, streaks home
#   HexFloor_Energy   a disc of inset hex tiles r 1, a few missing or raised (corrupted floor, Heal Zone)
#   Plus_Energy       a chunky pixel plus 1 across, 0.3 thick (Heal Zone ticks)
#   PixelRing_Energy  a stepped ring of square blocks r 1, 0.15 tall (shockwave edge, Heal Zone edge)
#
# Pivots: every mesh is centred on its bounding box (a MeshPart's CFrame is its box centre). The sphere pieces carry
# six tiny anchor triangles at +-1.02 on each axis so their box is the sphere's box (centre = sphere centre).
# Single-sided: tools/studio/make_ability_build_data.py marks the ones seen from both sides DoubleSided.
# Output: art-source/abilities/GlitchVFX/GlitchVFX.blend; --render: vault/02 Art/References/mods/glitchvfx.jpg.

import os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import math, random
from modkit import *  # noqa: F401,F403

MOD = "GlitchVFX"


# ---------------------------------------------------------------- 2D crack paths

def crack_paths(seed, branches=7, reach=1.0, ring=0.42):
	# Polylines [(x, y, width)] in the unit disc: jagged branches out from the centre, forks, and a broken ring.
	rng = random.Random(seed)
	paths = []
	base = rng.random() * math.tau
	for b in range(branches):
		a = base + math.tau * b / branches + rng.uniform(-0.25, 0.25)
		r, pts = 0.05, []
		length = reach * rng.uniform(0.82, 1.0)
		while r < length:
			w = 0.075 * (1 - r / length) + 0.012
			pts.append((r * math.cos(a), r * math.sin(a), w))
			r += rng.uniform(0.1, 0.17)
			a += rng.uniform(-0.28, 0.28)
		pts.append((length * math.cos(a), length * math.sin(a), 0.006))
		paths.append(pts)
		# One or two forks off the outer half.
		for _ in range(rng.choice((1, 1, 2))):
			i = rng.randrange(max(1, len(pts) // 3), len(pts) - 1)
			x, y, w = pts[i]
			fa = math.atan2(y, x) + rng.choice((-1, 1)) * rng.uniform(0.45, 0.8)
			fr = math.hypot(x, y)
			fork = [(x, y, w * 0.7)]
			steps = rng.randint(2, 3)
			for s in range(steps):
				fr += rng.uniform(0.09, 0.15)
				fa += rng.uniform(-0.2, 0.2)
				fork.append((min(fr, reach) * math.cos(fa), min(fr, reach) * math.sin(fa), w * 0.7 * (1 - (s + 1) / (steps + 1)) + 0.005))
			paths.append(fork)
	# The spiderweb ring: short arcs between neighbouring branches (some skipped).
	if ring:
		for b in range(branches):
			if rng.random() < 0.35:
				continue
			a0 = base + math.tau * b / branches + rng.uniform(0.1, 0.25)
			a1 = base + math.tau * (b + 1) / branches - rng.uniform(0.1, 0.25)
			rr = ring * rng.uniform(0.85, 1.25)
			pts = []
			for s in range(4):
				t = s / 3
				aa = a0 + (a1 - a0) * t
				q = rr + rng.uniform(-0.04, 0.04)
				pts.append((q * math.cos(aa), q * math.sin(aa), 0.022 if 0 < s < 3 else 0.008))
			paths.append(pts)
	return paths


def ribbon(bm, pts, scale_w, place_fn, mat):
	# A flat strip along a polyline [(x, y, w)]: two verts per point, offset across the local direction.
	left, right = [], []
	for i, (x, y, w) in enumerate(pts):
		x0, y0 = pts[max(i - 1, 0)][:2]
		x1, y1 = pts[min(i + 1, len(pts) - 1)][:2]
		dx, dy = x1 - x0, y1 - y0
		n = math.hypot(dx, dy) or 1
		nx, ny = -dy / n, dx / n
		hw = w * scale_w * 0.5
		left.append(bm.verts.new(place_fn(x + nx * hw, y + ny * hw, w)))
		right.append(bm.verts.new(place_fn(x - nx * hw, y - ny * hw, w)))
	for i in range(len(pts) - 1):
		f = bm.faces.new((right[i], right[i + 1], left[i + 1], left[i]))
		f.material_index = mat


def flat_up(z):
	# Wider (inner) parts of a crack sit a hair higher, so the flat mesh has some thickness for the importer.
	return lambda x, y, w: (x, y, z + w * 0.12)


def crack(seed, width, z, mat, hole=0.0):
	bm = bmesh.new()
	for p in crack_paths(seed):
		ribbon(bm, p, width, flat_up(z), mat)
	if hole:
		# A jagged star punched in the middle (the impact point).
		rng = random.Random(seed + 7)
		c = bm.verts.new((0, 0, z))
		ring = [bm.verts.new(((hole if i % 2 == 0 else hole * 0.45) * rng.uniform(0.8, 1.2) * math.cos(math.tau * i / 14), (hole if i % 2 == 0 else hole * 0.45) * rng.uniform(0.8, 1.2) * math.sin(math.tau * i / 14), z)) for i in range(14)]
		for i in range(14):
			f = bm.faces.new((c, ring[i], ring[(i + 1) % 14]))
			f.material_index = mat
	# Pin the box to +-1.01 across so its centre is the impact point.
	for x, y in ((1.01, 0), (-1.01, 0), (0, 1.01), (0, -1.01)):
		v0 = bm.verts.new((x, y, z))
		v1 = bm.verts.new((x * 0.996 + 0.004 * (y != 0), y * 0.996 + 0.004 * (x != 0), z))
		v2 = bm.verts.new((x * 0.996, y * 0.996, z))
		bm.faces.new((v0, v1, v2)).material_index = mat
	# Faces up.
	for f in bm.faces:
		f.normal_update()
		if f.normal.z < 0:
			f.normal_flip()
	return bm


# ---------------------------------------------------------------- solids

def rock(seed, size):
	# A faceted chunk: a jittered low-poly ball, flattened a little, hulled.
	rng = random.Random(seed)
	bm = bmesh.new()
	for i in range(11):
		z = 1 - 2 * (i + 0.5) / 11
		r = math.sqrt(1 - z * z)
		a = i * 2.39996 + rng.random() * 0.4
		k = rng.uniform(0.7, 1.15)
		bm.verts.new((r * math.cos(a) * k * size * 0.5, r * math.sin(a) * k * size * 0.5 * rng.uniform(0.75, 1.0), z * k * size * 0.32))
	bmesh.ops.convex_hull(bm, input=bm.verts[:])
	bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
	for f in bm.faces:
		f.material_index = SHELL
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	return bm


def cube(bm_list, cx, cy, cz, s, mat=ENERGY):
	bm_list.append(box(cx - s / 2, cx + s / 2, cy - s / 2, cy + s / 2, cz - s / 2, cz + s / 2, mat=mat))


def anchors(bm, r=1.02, mat=ENERGY):
	# Tiny triangles at +-r on each axis, so the mesh's bounding box is the sphere's box.
	e = 0.004
	for axis in range(3):
		for sgn in (-1, 1):
			p = [0.0, 0.0, 0.0]
			p[axis] = sgn * r
			o = [(e, 0, 0), (0, e, 0), (0, 0, e)]
			a, b = [o[i] for i in range(3) if i != axis]
			v0 = bm.verts.new(p)
			v1 = bm.verts.new([p[i] - sgn * 0.002 * (i == axis) + a[i] for i in range(3)])
			v2 = bm.verts.new([p[i] - sgn * 0.002 * (i == axis) + b[i] for i in range(3)])
			bm.faces.new((v0, v1, v2)).material_index = mat


# ---------------------------------------------------------------- the hex sphere (Goldberg cells of a freq-3 icosphere)

def goldberg(freq=3):
	t = (1 + math.sqrt(5)) / 2
	ico = [Vector(v).normalized() for v in [(-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0), (0, -1, t), (0, 1, t), (0, -1, -t), (0, 1, -t), (t, 0, -1), (t, 0, 1), (-t, 0, -1), (-t, 0, 1)]]
	faces = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6), (7, 1, 8), (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9), (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)]
	verts, index, tris = [], {}, []

	def vid(p):
		key = tuple(round(c, 5) for c in p)
		if key not in index:
			index[key] = len(verts)
			verts.append(p)
		return index[key]

	for a, b, c in faces:
		A, B, C = ico[a], ico[b], ico[c]
		grid = {}
		for i in range(freq + 1):
			for j in range(freq + 1 - i):
				p = (A * (freq - i - j) + B * i + C * j) / freq
				grid[i, j] = vid(p.normalized())
		for i in range(freq):
			for j in range(freq - i):
				tris.append((grid[i, j], grid[i + 1, j], grid[i, j + 1]))
				if i + j < freq - 1:
					tris.append((grid[i + 1, j], grid[i + 1, j + 1], grid[i, j + 1]))
	cent = [((verts[a] + verts[b] + verts[c]) / 3).normalized() for a, b, c in tris]
	around = {}
	for ti, tri in enumerate(tris):
		for v in tri:
			around.setdefault(v, []).append(ti)
	cells = []
	for v, tlist in around.items():
		n = verts[v]
		ref = (cent[tlist[0]] - n).normalized()
		side = n.cross(ref)
		tlist.sort(key=lambda ti: math.atan2((cent[ti] - n).dot(side), (cent[ti] - n).dot(ref)))
		cells.append((n, [cent[ti] for ti in tlist]))
	edges = set()
	for ti, tri in enumerate(tris):
		for k in range(3):
			e = tuple(sorted((tri[k], tri[(k + 1) % 3])))
			edges.add(e)
	# Each icosphere edge separates two triangles: the cell edge joins their centroids.
	edge_tris = {}
	for ti, tri in enumerate(tris):
		for k in range(3):
			edge_tris.setdefault(tuple(sorted((tri[k], tri[(k + 1) % 3]))), []).append(ti)
	cell_edges = [(cent[a], cent[b]) for a, b in edge_tris.values()]
	return cells, cell_edges


def hex_shell(inset=0.8, r=1.0):
	bm = bmesh.new()
	cells, _ = goldberg()
	for n, corners in cells:
		ring = [bm.verts.new((n + (c - n) * inset).normalized() * r) for c in corners]
		for i in range(1, len(ring) - 1):
			f = bm.faces.new((ring[0], ring[i], ring[i + 1]))
			f.material_index = ENERGY
	for f in bm.faces:
		f.normal_update()
		if f.normal.dot(f.calc_center_median()) < 0:
			f.normal_flip()
	anchors(bm)
	return bm


def hex_edges(width=0.035, r=1.01):
	bm = bmesh.new()
	_, edges = goldberg()
	for a, b in edges:
		a, b = a * r, b * r
		d = (b - a).normalized()
		n = ((a + b) / 2).normalized()
		s = n.cross(d) * width / 2
		# Run the ends a touch past the corners so the joints close.
		a2, b2 = a + (b - a) * -0.04, b + (a - b) * -0.04
		vs = [bm.verts.new(p) for p in (a2 - s, b2 - s, b2 + s, a2 + s)]
		f = bm.faces.new(vs)
		f.material_index = ENERGY
		f.normal_update()
		if f.normal.dot(n) < 0:
			f.normal_flip()
	anchors(bm)
	return bm


def hex_tile():
	pts = [(0.5 * math.cos(math.tau * i / 6), 0.5 * math.sin(math.tau * i / 6)) for i in range(6)]
	return prism(pts, "Z", -0.03, 0.03, mat=ENERGY)


def shell_crack(seed=11, cap=0.75, r=1.02):
	# Crack paths mapped onto a cap of the sphere around +Y (azimuthal equidistant: disc radius 1 = `cap` radians).
	def on_sphere(x, y, _w):
		rho = math.hypot(x, y)
		th = rho * cap
		phi = math.atan2(y, x)
		s = math.sin(th)
		return (s * math.cos(phi) * r, math.cos(th) * r, s * math.sin(phi) * r)

	bm = bmesh.new()
	for p in crack_paths(seed, branches=6, ring=0.5):
		ribbon(bm, p, 0.7, on_sphere, ENERGY)
	for f in bm.faces:
		f.normal_update()
		if f.normal.dot(f.calc_center_median()) < 0:
			f.normal_flip()
	anchors(bm)
	return bm


def scan_wave(seed=5, segs=56):
	# Torn slabs round a ring: each segment has its own height band; some are missing, some pushed out.
	rng = random.Random(seed)
	parts = []
	for i in range(segs):
		if rng.random() < 0.16:
			continue
		a0 = math.tau * i / segs
		a1 = math.tau * (i + 1) / segs - 0.012
		r = 1.0 + (rng.choice((0, 0, 0, 0.05, 0.1)))
		lo = rng.choice((0.0, 0.0, 0.1, 0.25))
		hi = rng.choice((0.55, 0.75, 0.9, 1.0, 1.0))
		bm = bmesh.new()
		vs = [bm.verts.new((r * math.cos(a), r * math.sin(a), z)) for a, z in ((a0, lo), (a1, lo), (a1, hi), (a0, hi))]
		bm.faces.new(vs).material_index = ENERGY
		parts.append(bm)
		# A loose pixel slab floating off the band now and then.
		if rng.random() < 0.3:
			z = rng.uniform(0.2, 1.05)
			h = rng.uniform(0.05, 0.12)
			rr = r + rng.uniform(0.04, 0.12)
			b2 = bmesh.new()
			vs = [b2.verts.new((rr * math.cos(a), rr * math.sin(a), zz)) for a, zz in ((a0, z), (a1, z), (a1, z + h), (a0, z + h))]
			b2.faces.new(vs).material_index = ENERGY
			parts.append(b2)
	out = group(*parts)
	# Pin the box to 0..1.15 in height and +-1.25 across so it's centred on the ring (anchor tris).
	e = 0.004
	for x, y, z in ((1.25, 0, 0), (-1.25, 0, 0), (0, 1.25, 0), (0, -1.25, 0), (0, 0, 1.15)):
		v0 = out.verts.new((x, y, z))
		v1 = out.verts.new((x * 0.998, y * 0.998, z * 0.998 + e))
		v2 = out.verts.new((x * 0.998 + e, y * 0.998 + e, z * 0.998))
		out.faces.new((v0, v1, v2)).material_index = ENERGY
	for f in out.faces:
		f.normal_update()
		c = f.calc_center_median()
		if f.normal.dot(Vector((c.x, c.y, 0))) < 0:
			f.normal_flip()
	return out


def pixels(seed, count, spread, size=(0.16, 0.34)):
	rng = random.Random(seed)
	bms = []
	for _ in range(count):
		s = rng.uniform(*size)
		x, y, z = [rng.gauss(0, spread) for _ in range(3)]
		# Snap to a coarse grid: voxels, not confetti.
		g = 0.12
		cube(bms, round(x / g) * g, round(y / g) * g, round(z / g) * g, s)
	return group(*bms)


def slivers(seed=3):
	# Horizontal scanline slivers in a 3 x 1 x 5.5 box (Blender X across, Y depth, Z up), body-sized.
	rng = random.Random(seed)
	bms = []
	z = -2.75
	while z < 2.75:
		h = rng.choice((0.05, 0.08, 0.12, 0.2))
		if z + h > 2.75:
			break
		w = rng.uniform(0.6, 2.6)
		x = rng.uniform(-1.5 + w / 2, 1.5 - w / 2)
		d = rng.uniform(0.15, 1.0)
		bms.append(box(x - w / 2, x + w / 2, -d / 2, d / 2, z, z + h, mat=ENERGY))
		z += h + rng.uniform(0.12, 0.45)
	out = group(*bms)
	return out


def streak(seed=8):
	# Bars along Blender Y (Roblox Z), 4 long overall, staggered: speed lines with pixel steps.
	rng = random.Random(seed)
	bms = [box(-0.09, 0.09, -2.0, 2.0, -0.09, 0.09, mat=ENERGY)]  # the spine, full length
	for _ in range(8):
		length = rng.uniform(0.8, 2.6)
		y0 = rng.uniform(-2.0, 2.0 - length)
		x, z = rng.uniform(-0.45, 0.45), rng.uniform(-0.45, 0.45)
		s = rng.choice((0.05, 0.08, 0.12))
		bms.append(box(x - s, x + s, y0, y0 + length, z - s, z + s, mat=ENERGY))
	return group(*bms)


def hex_floor(seed=4, r=1.0, cell=0.13, inset=0.82):
	rng = random.Random(seed)
	bm = bmesh.new()
	w = math.sqrt(3) * cell
	rows = int(r / (1.5 * cell)) + 2
	for row in range(-rows, rows + 1):
		for col in range(-rows, rows + 1):
			cx = col * w + (row % 2) * w / 2
			cy = row * 1.5 * cell
			if math.hypot(cx, cy) > r - cell * 0.8:
				continue
			if rng.random() < 0.1:
				continue  # corrupted: a missing tile
			z = 0.04 if rng.random() < 0.12 else 0.0
			ring = [bm.verts.new((cx + cell * inset * math.cos(math.pi / 6 + math.tau * i / 6), cy + cell * inset * math.sin(math.pi / 6 + math.tau * i / 6), z)) for i in range(6)]
			for i in range(1, 5):
				bm.faces.new((ring[0], ring[i], ring[i + 1])).material_index = ENERGY
	for f in bm.faces:
		f.normal_update()
		if f.normal.z < 0:
			f.normal_flip()
	return bm


def plus():
	a, b = 0.5, 0.17
	pts = [(-b, -a), (b, -a), (b, -b), (a, -b), (a, b), (b, b), (b, a), (-b, a), (-b, b), (-a, b), (-a, -b), (-b, -b)]
	return prism(pts, "Y", -0.15, 0.15, mat=ENERGY)


def pixel_ring(seed=9, segs=40, r=1.0):
	rng = random.Random(seed)
	bms = []
	for i in range(segs):
		if rng.random() < 0.1:
			continue
		a = math.tau * (i + 0.5) / segs
		s = math.tau * r / segs * 0.78
		h = rng.choice((0.1, 0.15, 0.15, 0.15))
		rr = r - s / 2 + rng.choice((0, 0, 0.03))
		bm = box(-s / 2, s / 2, -s / 2, s / 2, 0, h, mat=ENERGY)
		bmesh.ops.transform(bm, matrix=rot_z(a, (rr * math.cos(a), rr * math.sin(a), 0)), verts=bm.verts[:])
		# Drop the bottoms (never seen).
		bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().z < 1e-4 and abs(f.normal.z) > 0.5], context="FACES_ONLY")
		bms.append(bm)
	return group(*bms)


def build():
	mats = begin(MOD)
	parts = [
		Part("Crack_Energy").add(crack(21, 1.0, 0.012, ENERGY)),
		Part("CrackGap").add(crack(21, 2.6, 0.0, DARK, hole=0.16)),
		Part("Rubble1").add(rock(1, 0.7)),
		Part("Rubble2").add(rock(2, 0.55)),
		Part("Rubble3").add(rock(3, 0.62)),
		Part("HexShell_Energy").add(hex_shell()),
		Part("HexEdge_Energy").add(hex_edges()),
		Part("HexTile_Energy").add(hex_tile()),
		Part("ShellCrack_Energy").add(shell_crack()),
		Part("ScanWave_Energy").add(scan_wave()),
		Part("Pixels_Energy").add(pixels(12, 11, 0.22)),
		Part("PixelSpray_Energy").add(pixels(13, 18, 0.55, (0.1, 0.22))),
		Part("Slivers_Energy").add(slivers()),
		Part("Streak_Energy").add(streak()),
		Part("HexFloor_Energy").add(hex_floor()),
		Part("Plus_Energy").add(plus()),
		Part("PixelRing_Energy").add(pixel_ring()),
	]
	return assemble(MOD, parts, mats, [], {"kind": "vfx"}, smooth_angle=20)


# Where each piece sits in the check render (the saved file keeps every mesh at the origin).
LAYOUT = {
	# Front row: the small pieces.
	"Crack_Energy": (2.6, -7.0, 0.02, 2.2),
	"CrackGap": (2.6, -7.0, 0.0, 2.2),
	"Rubble1": (3.4, -3.9, 0.25, 1.2),
	"Rubble2": (2.6, -3.4, 0.2, 1.2),
	"Rubble3": (3.6, -3.0, 0.22, 1.2),
	"HexTile_Energy": (3.0, -1.4, 0.4, 1.0),
	"Pixels_Energy": (3.0, 0.4, 0.6, 1.0),
	"PixelSpray_Energy": (3.0, 2.4, 1.0, 0.9),
	"Plus_Energy": (3.0, 4.2, 0.6, 1.0),
	"Streak_Energy": (3.0, 6.6, 0.5, 0.7),
	# Back row: the big shapes.
	"HexShell_Energy": (-1.5, -4.5, 1.6, 1.5),
	"HexEdge_Energy": (-1.5, -4.5, 1.6, 1.5),
	"ShellCrack_Energy": (-1.5, -4.5, 1.6, 1.5),
	"ScanWave_Energy": (-1.5, -0.4, 0.0, 1.5),
	"Slivers_Energy": (-1.5, 3.0, 1.6, 0.6),
	"HexFloor_Energy": (-1.5, 6.6, 0.0, 1.6),
	"PixelRing_Energy": (-1.5, 6.6, 0.0, 1.75),
}


def main():
	args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	report = build()
	path = os.path.join(ROOT, "art-source", "abilities", MOD, MOD + ".blend")
	os.makedirs(os.path.dirname(path), exist_ok=True)
	bpy.ops.wm.save_as_mainfile(filepath=path)
	worst = max((v for k, v in report.items() if not k.startswith("_")))
	assert worst <= 1000, "a GlitchVFX mesh is over 1K tris: %s" % report
	if "--render" in args:
		for name, (x, y, z, s) in LAYOUT.items():
			o = bpy.data.objects[MOD + "_" + name]
			o.location = (x, y, z)
			o.scale = (s, s, s)
			if name == "ShellCrack_Energy":
				o.rotation_euler = (0, 0, math.radians(-90))  # turn the cap (+Y) toward the camera (+X)
		set_team(GLITCH)
		stage(look_dir=(1.0, 0.0, 0.9), hover=0.0, lens=40, zoom=0.6)
		render(os.path.join(RENDER_DIR, "glitchvfx.jpg"))
	print("BUILD_MOD " + json.dumps({"mod": MOD, "blend": path, "tris": report}))


if __name__ == "__main__":
	main()
