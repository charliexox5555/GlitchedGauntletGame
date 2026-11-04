# preview_map_greenhouse.py: the whole Greenhouse map assembled offline the way Studio builds it, its z-fight check, and
# preview renders.
#
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
#       art-source/maps/Greenhouse/Kit_Greenhouse.blend --python tools/blender/preview_map_greenhouse.py -- \
#       [--samples N] [--views a,b] [--no-render]
#
# Reads art-source/maps/Greenhouse/plan.json (written by tools/maps/greenhouse_layout.py --write): every kit placement
# becomes a collection instance of its Map_<Piece>, every greybox Part Art.luau leaves visible becomes a box with its
# finish colour, plus the plain decor Parts. Roblox map space (x, y, z) is Blender (x, -z, y); a Roblox yaw is a
# rotation about Blender +Z. The A half shows blue accents too (no tint offline).
#
# Z-FIGHT CHECK (the user's rule; the Studio audit tests real mesh triangles too): every world triangle of every placed
# kit mesh and every visible Part box is bucketed by plane (facing the same way, within 0.02); triangles of a bucket
# whose projections overlap by more than 0.01 square studs are a z-fight, unless the overlap's centre, nudged 0.03
# off the plane, is inside a collision solid (a face buried in a wall or a floor, which nobody sees) or the faces sit
# on the floor facing down. Prints GREENHOUSE_ZFIGHT <n> and the worst pairs. The file is not saved.

import json, math, os, sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
import lobbykit as K  # noqa: E402
from gunkit import box  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PLAN = os.path.join(K.ROOT, "art-source", "maps", "Greenhouse", "plan.json")
REF = os.path.join(K.ROOT, "vault", "02 Art", "References", "maps", "greenhouse")

COLOR = {
	"Limestone": 0.85, "Pavement": 0.9, "Pebble": 0.95, "WoodPlanks": 0.8, "Brick": 0.9, "Plaster": 0.95, "Grass": 0.95,
}


def mat(name, color, rough=0.9):
	m = bpy.data.materials.get(name)
	if m:
		return m
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	b = m.node_tree.nodes.get("Principled BSDF")
	b.inputs["Base Color"].default_value = (*K.lin(color), 1)
	b.inputs["Roughness"].default_value = rough
	return m


def rbx_box(col, name, lo, hi, m):
	x0, y0, z0 = lo
	x1, y1, z1 = hi
	bm = box(x0, x1, -z1, -z0, y0, y1)
	return K.add_obj(name, bm, [m], col, smooth_angle=0, uvs=None)


def placement_matrix(p):
	return Matrix.Translation((p["x"], -p["z"], p["y"])) @ Matrix.Rotation(math.radians(p["yaw"]), 4, "Z")


# ---------------------------------------------------------------- solids (map space) for the buried test

class Solids:
	def __init__(self, solids):
		self.s = solids
		self.cell = 8.0
		self.grid = defaultdict(list)
		for i, s in enumerate(solids):
			lo, hi = self.bounds(s)
			for gx in range(int(math.floor(lo[0] / self.cell)), int(math.floor(hi[0] / self.cell)) + 1):
				for gy in range(int(math.floor(lo[1] / self.cell)), int(math.floor(hi[1] / self.cell)) + 1):
					for gz in range(int(math.floor(lo[2] / self.cell)), int(math.floor(hi[2] / self.cell)) + 1):
						self.grid[(gx, gy, gz)].append(i)

	@staticmethod
	def bounds(s):
		c, sz = s["c"], s["s"]
		if s["axes"]:
			h = [sum(abs(s["axes"][k][i]) * sz[k] / 2 for k in range(3)) for i in range(3)]
		elif s["shape"] == "ramp" and s["up"] in ("+x", "-x"):
			h = [sz[2] / 2, sz[1] / 2, sz[0] / 2]
		else:
			h = [v / 2 for v in sz]
		return [c[i] - h[i] for i in range(3)], [c[i] + h[i] for i in range(3)]

	def inside(self, p):
		key = tuple(int(math.floor(p[i] / self.cell)) for i in range(3))
		for i in self.grid.get(key, ()):
			s = self.s[i]
			c, sz = s["c"], s["s"]
			d = [p[k] - c[k] for k in range(3)]
			if s["axes"]:
				if all(abs(sum(d[j] * s["axes"][k][j] for j in range(3))) < sz[k] / 2 for k in range(3)):
					return True
				continue
			if s["shape"] == "cyl":
				if abs(d[1]) < sz[1] / 2 and d[0] * d[0] + d[2] * d[2] < (sz[0] / 2) ** 2:
					return True
				continue
			lo, hi = self.bounds(s)
			if not all(lo[k] < p[k] < hi[k] for k in range(3)):
				continue
			if s["shape"] == "ramp":
				ax, sgn = (0, 1) if s["up"][1] == "x" else (2, 1)
				t = (p[ax] - lo[ax]) / (hi[ax] - lo[ax])
				if s["up"][0] == "-":
					t = 1 - t
				if p[1] > lo[1] + (hi[1] - lo[1]) * t:
					continue
			return True
		return False


# ---------------------------------------------------------------- triangles

def clip(poly, a, b):
	# Keeps the part of polygon `poly` on the left of the directed edge a->b (2D).
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
			out.append((p[0] + t * (q[0] - p[0]), p[1] + t * (q[1] - p[1])))
	return out


def area(poly):
	return 0.5 * sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1] for i in range(len(poly)))


def ccw(t):
	return t if area(t) >= 0 else [t[0], t[2], t[1]]


def zfight(tris, solids):
	# tris: list of (owner, (v0, v1, v2) in map space). Returns [(owner_a, owner_b, area, centre)].
	buckets = defaultdict(list)
	data = []
	for owner, (a, b, c) in tris:
		n = (b - a).cross(c - a)
		if n.length < 1e-9:
			continue
		ar = n.length / 2
		n.normalize()
		d = n.dot(a)
		if n.y < -0.95 and abs(d + 0.0) < 0.06 and a.y < 0.06:
			continue  # floor contact, facing down
		key = (round(n.x, 3), round(n.y, 3), round(n.z, 3))
		i = len(data)
		data.append((owner, a, b, c, n, d))
		buckets[key + (int(round(d / 0.02)),)].append(i)
	found = {}
	for key, idx in list(buckets.items()):
		if len(idx) < 1:
			continue
		near = list(idx) + buckets.get(key[:3] + (key[3] + 1,), [])
		if len(near) < 2:
			continue
		n = data[near[0]][4]
		ref = Vector((1, 0, 0)) if abs(n.x) < 0.9 else Vector((0, 1, 0))
		u = n.cross(ref).normalized()
		v = n.cross(u)
		proj = {}
		grid = defaultdict(list)
		for i in near:
			_, a, b, c, _, _ = data[i]
			t = ccw([(p.dot(u), p.dot(v)) for p in (a, b, c)])
			proj[i] = t
			x0, x1 = min(q[0] for q in t), max(q[0] for q in t)
			y0, y1 = min(q[1] for q in t), max(q[1] for q in t)
			for gx in range(int(math.floor(x0 / 4)), int(math.floor(x1 / 4)) + 1):
				for gy in range(int(math.floor(y0 / 4)), int(math.floor(y1 / 4)) + 1):
					grid[(gx, gy)].append(i)
		seen = set()
		home = set(idx)
		for cell, members in grid.items():
			for ii in range(len(members)):
				for jj in range(ii + 1, len(members)):
					i, j = members[ii], members[jj]
					if i not in home and j not in home:
						continue
					pr = (min(i, j), max(i, j))
					if pr in seen:
						continue
					seen.add(pr)
					if abs(data[i][5] - data[j][5]) > 0.02:
						continue
					poly = proj[i]
					tj = proj[j]
					for k in range(3):
						poly = clip(poly, tj[k], tj[(k + 1) % 3])
						if len(poly) < 3:
							break
					if len(poly) < 3:
						continue
					ar = area(poly)
					if ar < 0.01:
						continue
					cu = sum(q[0] for q in poly) / len(poly)
					cv = sum(q[1] for q in poly) / len(poly)
					ni = data[i][4]
					centre = u * cu + v * cv + ni * data[i][5]
					probe = centre + ni * 0.03
					if solids.inside((probe.x, probe.y, probe.z)):
						continue
					oa, ob = data[i][0], data[j][0]
					k2 = tuple(sorted((oa, ob)))
					prev = found.get(k2)
					if not prev or ar > prev[0]:
						found[k2] = (ar, centre)
	return [(a, b, ar, c) for (a, b), (ar, c) in found.items()]


def main():
	plan = json.load(open(PLAN))
	for lc in bpy.context.view_layer.layer_collection.children:
		lc.exclude = True
	col = K.collection("Preview")
	pieces = {c.name[4:]: c for c in bpy.data.collections if c.name.startswith("Map_")}
	tris = []
	missing = set()
	total = 0
	for idx, p in enumerate(plan["place"]):
		c = pieces.get(p["piece"])
		if c is None:
			missing.add(p["piece"])
			continue
		m = placement_matrix(p)
		K.place_instance(c, m, "P_" + p["piece"], col)
		for ob in c.all_objects:
			if ob.type != "MESH" or ob.get("preview_only"):
				continue
			me = ob.data
			me.calc_loop_triangles()
			mw = m @ ob.matrix_world
			vs = [mw @ v.co for v in me.vertices]
			# Blender -> map space: (x, y, z) -> (x, z, -y)
			vm = [Vector((q.x, q.z, -q.y)) for q in vs]
			owner = "%s@%d,%d:%s" % (p["piece"], round(p["x"]), round(p["z"]), ob.name)
			for t in me.loop_triangles:
				tris.append((owner, tuple(vm[k] for k in t.vertices)))
				total += 1
	print("PREVIEW placements", len(plan["place"]), "kit triangles", total, "missing", sorted(missing))
	# Visible greybox Parts and decor Parts.
	nparts = 0
	for s in plan["solids"]:
		if not s["look"]:
			continue
		lo, hi = Solids.bounds(s)
		material, hexc = s["look"]
		rbx_box(col, "G_" + s["name"], lo, hi, mat("Part_" + hexc, int(hexc, 16), COLOR.get(material, 0.9)))
		nparts += 1
		tris += box_tris("G:" + s["name"] + "@%d,%d" % (round(s["c"][0]), round(s["c"][2])), lo, hi)
	for p in plan["parts"]:
		x0, x1, y0, y1, z0, z1 = p["box"]
		material, hexc = p["look"]
		rbx_box(col, "D_" + p["name"], (x0, y0, z0), (x1, y1, z1), mat("Part_" + hexc, int(hexc, 16)))
		tris += box_tris("D:" + p["name"] + "@%d,%d" % (round(x0), round(z0)), (x0, y0, z0), (x1, y1, z1))
		nparts += 1
	solids = Solids(plan["solids"])
	found = zfight(tris, solids)
	found.sort(key=lambda f: -f[2])
	print("GREENHOUSE_ZFIGHT %d (triangles %d, parts %d)" % (len(found), len(tris), nparts))
	for a, b, ar, c in found[:40]:
		print("  %.2f  %s  +  %s  at (%.1f, %.1f, %.1f)" % (ar, a, b, c.x, c.y, c.z))
	if "--no-render" in ARGS:
		return
	# Sun about 68 degrees up from the south-west (Lighting.luau), sky gradient.
	sc = bpy.context.scene
	w = sc.world or bpy.data.worlds.new("World")
	sc.world = w
	w.use_nodes = True
	nt = w.node_tree
	nt.nodes.clear()
	out = nt.nodes.new("ShaderNodeOutputWorld")
	bg = nt.nodes.new("ShaderNodeBackground")
	tc = nt.nodes.new("ShaderNodeTexCoord")
	sep = nt.nodes.new("ShaderNodeSeparateXYZ")
	ramp = nt.nodes.new("ShaderNodeValToRGB")
	nt.links.new(tc.outputs["Generated"], sep.inputs[0])
	nt.links.new(sep.outputs[2], ramp.inputs[0])
	ramp.color_ramp.elements[0].color = (*K.lin(0xDCE7DD), 1)
	ramp.color_ramp.elements[1].position = 0.42
	ramp.color_ramp.elements[1].color = (*K.lin(0x5C9BD8), 1)
	nt.links.new(ramp.outputs[0], bg.inputs[0])
	bg.inputs[1].default_value = 1.2
	nt.links.new(bg.outputs[0], out.inputs[0])
	ld = bpy.data.lights.new("Sun", "SUN")
	ld.energy = 4.5
	ld.color = K.lin(0xFFF3DE)
	ld.angle = math.radians(1.0)
	so = bpy.data.objects.new("Sun", ld)
	col.objects.link(so)
	el, az = math.radians(68), math.radians(-35)
	to_sun = Vector((math.cos(el) * math.cos(az), math.cos(el) * math.sin(az), math.sin(el)))
	so.rotation_euler = (-to_sun).to_track_quat("-Z", "Y").to_euler()
	samples = int(ARGS[ARGS.index("--samples") + 1]) if "--samples" in ARGS else 24
	K.render_settings(samples=samples)
	K.bloom(strength=0.2, threshold=1.6)

	def V(x, y, z):
		return (x, -z, y)

	views = {
		"overview": (V(-170, 200, 150), V(0, 0, 10), 30),
		"dome": (V(-34, 17.0, 30), V(10, 9, -12), 22),
		"terrace": (V(-70, 5.4, 46), V(-38, 14, 90), 22),
		"fern": (V(-14, 5.4, 81), V(6, 7, 44), 22),
	}
	want = ARGS[ARGS.index("--views") + 1].split(",") if "--views" in ARGS else list(views)
	for name in want:
		loc, tgt, lens = views[name]
		cam = K.camera(loc, tgt, lens=lens, name="Cam_" + name, col=col)
		sc.camera = cam
		K.render(os.path.join(REF, "preview-%s.jpg" % name), res=(1600, 900))


def box_tris(owner, lo, hi):
	x0, y0, z0 = lo
	x1, y1, z1 = hi
	P = [Vector(v) for v in ((x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0), (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1))]
	quads = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
	out = []
	for a, b, c, d in quads:
		out.append((owner, (P[a], P[b], P[c])))
		out.append((owner, (P[a], P[c], P[d])))
	return out


main()
