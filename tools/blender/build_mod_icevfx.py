# build_mod_icevfx.py: the stylized ice kit (collection "IceVFX"): faceted crystal meshes the ice effects are built
# from (Frost burst, Freeze Frame ice blocks, Frost Wall). Art Direction -> "Ability VFX: stylized, mesh-first".
#   blender --background --factory-startup --python tools/blender/build_mod_icevfx.py -- [--render]
# Output: art-source/abilities/IceVFX/IceVFX.blend; --render writes vault/02 Art/References/mods/icevfx.jpg.
#
# Untextured, flat-shaded (every edge sharp: the facets catch the light). The game sets colour, material and
# transparency in code (src/client/Util/IceKit.luau), so one mesh serves the pale ice, the deep core and the magenta
# glitch copy. Origins (where code places each mesh; Blender +X forward, +Z up, as every Mod):
#   Shard1  tall slender hex crystal, 1 tall, origin at its base       } spikes, wall-foot crystals,
#   Shard2  stubby 5-sided crystal, 1 tall, base                       } crystals stuck to a hindered body
#   Shard3  flat blade crystal, 1 tall, base                           }
#   Cluster five crystals fanning out of one base, ~1 tall, base (burst core, wall foot)
#   SlabA / SlabB  a wall segment: four packed crystal columns with a jagged top, 4 wide (X) x 1.2 thick (Y)
#                  x 10 tall, origin on the floor at its centre (one per 4-stud Firewall piece)
#   Shell   the ice block around a frozen body: a faceted octagonal block with a crystal crown and side spikes,
#           origin at the CORE's centre; the core (without spikes) is 4.0 wide (Y) x 2.4 deep (X) x 5.6 tall
#   Fragment1..3  angular chips for shattering, ~1 across, origin at the centre
#   Ring_Energy   the snap-freeze ring: a flat crown with sawtooth crystal teeth, r 0.8 -> 1, origin on the floor
#   Floor         a faceted star-shaped frost patch, r 1, 0.05 high, origin on the floor (top face only)
#   Cracks_Energy seven jagged radial cracks for the Floor (r ~0.95, just above it), origin on the floor
#   Pixels_Energy a scatter of pixel cubes (glitch accent), ~1 x 1, 0.25 deep, origin at the centre
#   Scanlines_Energy five thin horizontal slivers (glitch accent), ~1 x 1, 0.04 deep, origin at the centre
# Energy parts are Neon in the game; Pixels / Scanlines are magenta #FF3DCB there, Ring / Cracks ice white or team.

import os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import math, random
from modkit import *  # noqa: F401,F403

MOD = "IceVFX"
ICE_COL = 0xBFE8FF
ICE_IDX = len(MAT_NAMES)  # the extra material slot after modkit's six


def ice_material():
	m = bpy.data.materials.new("Ice")
	m["rbx_material"] = "SmoothPlastic"
	m["rbx_color"] = "%06X" % ICE_COL
	m["rbx_transparency"] = 0.2
	m.use_nodes = True
	nt = m.node_tree
	nt.nodes.clear()
	out = nt.nodes.new("ShaderNodeOutputMaterial")
	bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
	nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
	c = (*lin(ICE_COL), 1)
	bsdf.inputs["Base Color"].default_value = c
	bsdf.inputs["Roughness"].default_value = 0.2
	bsdf.inputs["Emission Color"].default_value = c
	bsdf.inputs["Emission Strength"].default_value = 0.25
	bsdf.inputs["Alpha"].default_value = 0.8
	m.surface_render_method = "BLENDED"
	m.diffuse_color = c
	return m


# ---------------------------------------------------------------- crystal geometry

def crystal(rng, n, rx, ry, h, tip=0.3, jit=0.12, base=0.85, mat=ICE_IDX, chisel=0.18):
	# An n-sided crystal standing on z = 0: a narrower foot, a body, then a faceted point at z = h, slightly off centre.
	bm = bmesh.new()
	a0 = rng.uniform(0, 2 * math.pi)
	angles = [a0 + 2 * math.pi * i / n + rng.uniform(-0.12, 0.12) for i in range(n)]
	radii = [1 + rng.uniform(-jit, jit) for _ in range(n)]

	def ring(scale, z):
		return [bm.verts.new((rx * scale * radii[i] * math.cos(a), ry * scale * radii[i] * math.sin(a), z)) for i, a in enumerate(angles)]

	rings = [ring(base, 0.0), ring(1.0, h * 0.12), ring(0.94 + rng.uniform(-0.04, 0.04), h * (1 - tip))]
	# chisel: how far off centre the point sits (a big value cuts the top at a slant, like a cleaved crystal).
	apex = bm.verts.new((rx * rng.uniform(-chisel, chisel), ry * rng.uniform(-0.18, 0.18), h))
	bm.faces.new(rings[0][::-1])
	for a, b in zip(rings, rings[1:]):
		for i in range(n):
			j = (i + 1) % n
			bm.faces.new((a[i], a[j], b[j], b[i]))
	for i in range(n):
		bm.faces.new((rings[-1][i], rings[-1][(i + 1) % n], apex))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	for f in bm.faces:
		f.material_index = mat
	return bm


def tilt(bm, at, out_angle=0.0, side_angle=0.0, spin=0.0):
	# Spin about Z, lean `out_angle` about Y (toward +X) and `side_angle` about X, then move the base to `at`.
	m = Matrix.Translation(at) @ Matrix.Rotation(side_angle, 4, "X") @ Matrix.Rotation(out_angle, 4, "Y") @ Matrix.Rotation(spin, 4, "Z")
	return place(bm, m)


def lean_toward(bm, at, direction, angle, spin=0.0):
	# Leans a crystal built along +Z by `angle` toward the horizontal `direction` (x, y), base at `at`.
	d = Vector((direction[0], direction[1], 0)).normalized()
	axis = Vector((0, 0, 1)).cross(d)
	m = Matrix.Translation(at) @ Matrix.Rotation(angle, 4, axis) @ Matrix.Rotation(spin, 4, "Z")
	return place(bm, m)


def hull(rng, n, sx, sy, sz, mat=ICE_IDX):
	# An angular chip: the convex hull of points on a squashed ellipsoid.
	bm = bmesh.new()
	for _ in range(n):
		v = Vector((rng.gauss(0, 1), rng.gauss(0, 1), rng.gauss(0, 1))).normalized()
		bm.verts.new((v.x * sx, v.y * sy, v.z * sz))
	bmesh.ops.convex_hull(bm, input=bm.verts[:])
	bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	for f in bm.faces:
		f.material_index = mat
	return bm


# ---------------------------------------------------------------- kit pieces

def shard1():
	return crystal(random.Random(11), 6, 0.16, 0.16, 1.0, tip=0.3)


def shard2():
	return crystal(random.Random(12), 5, 0.28, 0.26, 1.0, tip=0.38, jit=0.15)


def shard3():
	return crystal(random.Random(13), 4, 0.22, 0.075, 1.0, tip=0.45, jit=0.05, base=0.7)


def cluster():
	rng = random.Random(21)
	out = bmesh.new()
	merge(out, lean_toward(crystal(rng, 6, 0.17, 0.16, 1.0, tip=0.3), (0, 0, 0), (1, 0.3), math.radians(6)))
	for k in range(4):
		a = math.pi / 2 * k + rng.uniform(-0.35, 0.35)
		d = (math.cos(a), math.sin(a))
		h = rng.uniform(0.45, 0.75)
		r = rng.uniform(0.1, 0.14)
		at = (d[0] * 0.1, d[1] * 0.1, 0)
		merge(out, lean_toward(crystal(rng, rng.choice((5, 6)), r, r * rng.uniform(0.85, 1), h, tip=0.32), at, d, math.radians(rng.uniform(24, 40)), rng.uniform(0, 6)))
	return out


def slab(seed):
	# Three chunky crystal columns packed edge to edge (4 wide along X, 1.2 thick along Y, up to 10 tall) with cleaved,
	# slanted tops, plus crystals leaning off the foot on both faces so the wall sits in the floor rather than on it.
	rng = random.Random(seed)
	out = bmesh.new()
	heights = [rng.uniform(8.4, 9.6) for _ in range(3)]
	heights[rng.randrange(3)] = 10.0  # the tallest column always reaches the wall's full height
	for i, h in enumerate(heights):
		x = -1.3 + 1.3 * i + rng.uniform(-0.08, 0.08)
		col = crystal(rng, 6, rng.uniform(0.84, 0.92), rng.uniform(0.55, 0.6), h, tip=rng.uniform(0.09, 0.13), jit=0.07, base=0.94, chisel=0.55)
		merge(out, tilt(col, (x, rng.uniform(-0.04, 0.04), 0), out_angle=math.radians(rng.uniform(-3, 3)), side_angle=math.radians(rng.uniform(-2, 2)), spin=rng.uniform(-0.08, 0.08)))
	for side in (-1, 1):
		for k in range(2):
			x = -0.8 + 1.6 * k + rng.uniform(-0.4, 0.4)
			h = rng.uniform(2.0, 3.4)
			r = rng.uniform(0.3, 0.4)
			c = crystal(rng, 5, r, r * 0.85, h, tip=0.3, chisel=0.3)
			merge(out, lean_toward(c, (x, side * 0.3, 0), (rng.uniform(-0.4, 0.4), side), math.radians(rng.uniform(24, 36)), rng.uniform(0, 6)))
	return out


SHELL_W, SHELL_D, SHELL_H = 4.0, 2.4, 5.6  # the core's width (Y), depth (X) and height (Z); IceKit.luau has these too


def shell():
	rng = random.Random(31)
	bm = bmesh.new()
	n = 7
	angles = [2 * math.pi * (i + 0.5) / n + rng.uniform(-0.12, 0.12) for i in range(n)]
	# n-gon "radii" whose flat extents come out about SHELL_D x SHELL_W.
	rx, ry = SHELL_D / 2 / math.cos(math.pi / n), SHELL_W / 2 / math.cos(math.pi / n)
	half = SHELL_H / 2
	# Straight faceted sides, a cleaved, slanted top (no dome: crystals are cut flat).
	prof = [(0.95, -half), (1.0, -half * 0.45), (0.97, half * 0.45), (0.86, half * 0.9)]
	rings = []
	for s, z in prof:
		ring = []
		for a in angles:
			k = s * (1 + rng.uniform(-0.07, 0.07))
			ring.append(bm.verts.new((rx * k * math.cos(a), ry * k * math.sin(a), z + rng.uniform(-0.15, 0.15))))
		rings.append(ring)
	top = []
	for a in angles:
		x, y = rx * 0.6 * math.cos(a), ry * 0.6 * math.sin(a)
		top.append(bm.verts.new((x, y, half + 0.12 * y + rng.uniform(-0.05, 0.05))))
	rings.append(top)
	bm.faces.new(rings[0][::-1])
	for a, b in zip(rings, rings[1:]):
		for i in range(n):
			j = (i + 1) % n
			bm.faces.new((a[i], a[j], b[j], b[i]))
	bm.faces.new(rings[-1])
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	for f in bm.faces:
		f.material_index = ICE_IDX
	# Crown: three big crystals out of the top, leaning apart.
	for y, h, ang in ((-0.7, 1.7, -24), (0.2, 1.35, 10), (0.95, 1.0, 34)):
		c = crystal(rng, 5, 0.42, 0.36, h, tip=0.35, chisel=0.35)
		merge(bm, tilt(c, (rng.uniform(-0.2, 0.2), y, half - 0.45), side_angle=math.radians(ang), out_angle=math.radians(rng.uniform(-10, 10)), spin=rng.uniform(0, 6)))
	# Side spikes: crystals jutting out and up from the faces and corners.
	for a, z, h in ((0.3, 1.0, 1.4), (1.5, -0.5, 1.1), (2.6, 1.7, 1.2), (3.4, -1.2, 1.15), (4.3, 0.3, 1.35), (5.3, 1.3, 1.0), (5.9, -1.7, 0.95)):
		d = (math.cos(a), math.sin(a))
		at = (rx * 0.82 * d[0], ry * 0.82 * d[1], z)
		c = crystal(rng, 5, 0.28, 0.24, h, tip=0.4, chisel=0.3)
		merge(bm, lean_toward(c, at, d, math.radians(rng.uniform(46, 62)), rng.uniform(0, 6)))
	# Feet: crystals splayed out at the bottom.
	for a in (0.9, 2.7, 4.6):
		d = (math.cos(a), math.sin(a))
		c = crystal(rng, 5, 0.3, 0.26, 1.2, tip=0.4)
		merge(bm, lean_toward(c, (rx * 0.85 * d[0], ry * 0.85 * d[1], -half), d, math.radians(58), rng.uniform(0, 6)))
	return bm


def fragment(seed):
	rng = random.Random(seed)
	return hull(rng, 13, rng.uniform(0.45, 0.55), rng.uniform(0.3, 0.4), rng.uniform(0.38, 0.5))


def ring_energy():
	# A flat crown: an inner lip at r 0.8, a top sloping out to sawtooth teeth (valleys r 0.9, tips r 1).
	n = 48
	bm = bmesh.new()
	rng = random.Random(41)

	def r_out(i):
		return 1.0 if i % 2 == 0 else 0.88 + rng.uniform(-0.02, 0.02)

	outer = [r_out(i) for i in range(n)]
	ib = [bm.verts.new((0.8 * math.cos(2 * math.pi * i / n), 0.8 * math.sin(2 * math.pi * i / n), 0.0)) for i in range(n)]
	it = [bm.verts.new((0.8 * math.cos(2 * math.pi * i / n), 0.8 * math.sin(2 * math.pi * i / n), 0.12)) for i in range(n)]
	ot = [bm.verts.new((outer[i] * math.cos(2 * math.pi * i / n), outer[i] * math.sin(2 * math.pi * i / n), 0.04 if i % 2 == 0 else 0.09)) for i in range(n)]
	ob = [bm.verts.new((outer[i] * math.cos(2 * math.pi * i / n), outer[i] * math.sin(2 * math.pi * i / n), 0.0)) for i in range(n)]
	for i in range(n):
		j = (i + 1) % n
		bm.faces.new((it[i], ot[i], ot[j], it[j]))
		bm.faces.new((ib[j], it[j], it[i], ib[i]))
		bm.faces.new((ob[i], ob[j], ot[j], ot[i]))
		bm.faces.new((ib[i], ib[j], ob[j], ob[i]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	for f in bm.faces:
		f.material_index = ENERGY
	return bm


def floor_patch():
	# Star-shaped frost patch: a centre, a ring of uneven facets, 24 points of irregular length.
	rng = random.Random(51)
	bm = bmesh.new()
	c = bm.verts.new((0, 0, 0.045))
	inner = []
	for i in range(12):
		a = 2 * math.pi * i / 12 + rng.uniform(-0.1, 0.1)
		r = rng.uniform(0.38, 0.5)
		inner.append(bm.verts.new((r * math.cos(a), r * math.sin(a), rng.uniform(0.015, 0.045))))
	outer = []
	for i in range(24):
		a = 2 * math.pi * i / 24 + rng.uniform(-0.05, 0.05)
		r = rng.uniform(0.88, 1.0) if i % 2 == 0 else rng.uniform(0.62, 0.74)
		outer.append(bm.verts.new((r * math.cos(a), r * math.sin(a), 0.0)))
	for i in range(12):
		j = (i + 1) % 12
		bm.faces.new((c, inner[i], inner[j]))
		o0, o1, o2 = outer[2 * i], outer[2 * i + 1], outer[(2 * i + 2) % 24]
		bm.faces.new((inner[i], o0, o1))
		bm.faces.new((inner[i], o1, inner[j]))
		bm.faces.new((inner[j], o1, o2))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	for f in bm.faces:
		if f.normal.z < 0:
			f.normal_flip()
		f.material_index = ICE_IDX
	return bm


def cracks():
	# Seven jagged radial cracks, flat strips just above the Floor's top (it peaks at 0.045).
	rng = random.Random(61)
	bm = bmesh.new()
	for k in range(7):
		a = 2 * math.pi * k / 7 + rng.uniform(-0.2, 0.2)
		pts = []
		for s in range(5):
			r = 0.14 + 0.8 * s / 4
			off = 0 if s == 0 else rng.uniform(-0.14, 0.14)
			pts.append(Vector((r * math.cos(a + off), r * math.sin(a + off))))
		for s in range(4):
			p0, p1 = pts[s], pts[s + 1]
			d = (p1 - p0).normalized()
			nrm = Vector((-d.y, d.x))
			w0, w1 = 0.035 * (1 - s / 4.5), 0.035 * (1 - (s + 1) / 4.5)
			vs = [bm.verts.new((*(p0 + nrm * w0), 0.055)), bm.verts.new((*(p1 + nrm * w1), 0.055)), bm.verts.new((*(p1 - nrm * w1), 0.055)), bm.verts.new((*(p0 - nrm * w0), 0.055))]
			f = bm.faces.new(vs)
			if f.normal.z < 0:
				f.normal_flip()
			f.material_index = ENERGY
	return bm


def pixels():
	# Pixel cubes in a corrupted stair, facing +X (a face of whatever they sit on); ~1 wide (Y) x 1 tall (Z).
	rng = random.Random(71)
	bm = bmesh.new()
	cells = [(-0.4, 0.35, 0.22), (-0.15, 0.35, 0.16), (0.1, 0.12, 0.26), (0.38, 0.12, 0.14), (-0.3, -0.12, 0.12), (0.22, -0.35, 0.2), (-0.05, -0.38, 0.1), (0.42, 0.42, 0.1)]
	for y, z, s in cells:
		d = s * rng.uniform(0.6, 1.0)
		merge(bm, box(-d / 2, d / 2, y - s / 2, y + s / 2, z - s / 2, z + s / 2, mat=ENERGY))
	return bm


def scanlines():
	# Thin horizontal slivers, staggered like a torn video line; 0.04 deep (X).
	bm = bmesh.new()
	for y0, y1, z, t in ((-0.5, 0.5, 0.42, 0.05), (-0.2, 0.45, 0.22, 0.03), (-0.45, 0.15, 0.02, 0.07), (0.05, 0.5, -0.2, 0.035), (-0.5, -0.05, -0.42, 0.05)):
		merge(bm, box(-0.02, 0.02, y0, y1, z - t / 2, z + t / 2, mat=ENERGY))
	return bm


def build():
	mats = begin(MOD)
	mats.append(ice_material())
	parts = [
		Part("Shard1").add(shard1()),
		Part("Shard2").add(shard2()),
		Part("Shard3").add(shard3()),
		Part("Cluster").add(cluster()),
		Part("SlabA").add(slab(101)),
		Part("SlabB").add(slab(202)),
		Part("Shell").add(shell()),
		Part("Fragment1").add(fragment(301)),
		Part("Fragment2").add(fragment(302)),
		Part("Fragment3").add(fragment(303)),
		Part("Ring_Energy").add(ring_energy()),
		Part("Floor").add(floor_patch()),
		Part("Cracks_Energy").add(cracks()),
		Part("Pixels_Energy").add(pixels()),
		Part("Scanlines_Energy").add(scanlines()),
	]
	report = assemble(MOD, parts, mats, [], {"kind": "vfx"}, smooth_angle=1)
	over = {k: v for k, v in report.items() if not k.startswith("_") and v > 1000}
	if over:
		raise ValueError("over the 1K tris budget: %s" % over)
	return report


# ---------------------------------------------------------------- check render

def preview_material(name, color, alpha=1.0, emit=0.0, neon=False):
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	b = m.node_tree.nodes.get("Principled BSDF")
	c = (*lin(color), 1)
	b.inputs["Base Color"].default_value = c
	b.inputs["Roughness"].default_value = 0.25
	b.inputs["Emission Color"].default_value = c
	b.inputs["Emission Strength"].default_value = 4.0 if neon else emit
	if alpha < 1:
		b.inputs["Alpha"].default_value = alpha
		m.surface_render_method = "BLENDED"
	return m


def show(name, mat, loc, scale=(1, 1, 1), rot=(0, 0, 0)):
	o = bpy.data.objects[MOD + "_" + name]
	o.data.materials.clear()
	o.data.materials.append(mat)
	o.location = loc
	o.scale = scale
	o.rotation_euler = rot
	return o


def dupe(name, mat, loc, scale=(1, 1, 1), rot=(0, 0, 0)):
	src = bpy.data.objects[MOD + "_" + name]
	me = src.data.copy()
	me.materials.clear()
	me.materials.append(mat)
	o = bpy.data.objects.new(src.name + "_preview", me)
	bpy.data.collections["Staged"].objects.link(o)
	o.location, o.scale, o.rotation_euler = loc, scale, rot
	return o


def render_check():
	# A staged scene (the saved .blend keeps every mesh at the origin): a wall of SlabA / SlabB with magenta glitch
	# accents (the Frost Wall), a frozen mannequin in the Shell, the burst (Floor, Cracks, Ring, Cluster, spikes) and
	# the loose pieces in a row. Extra objects go in "Staged" (stage() empties "Preview" but frames "Staged" too).
	pv = bpy.data.collections.new("Staged")
	bpy.context.scene.collection.children.link(pv)
	ice = preview_material("PrevIce", 0xBFE8FF, 0.88, 0.35)
	deep = preview_material("PrevDeep", 0x7FD4FF, 0.9, 0.3)
	shellm = preview_material("PrevShell", 0xBFE8FF, 0.5, 0.3)
	white = preview_material("PrevWhite", 0xE8F8FF, neon=True)
	team = preview_material("PrevTeam", 0x00E5FF, neon=True)
	magenta = preview_material("PrevMagenta", GLITCH, neon=True)
	body = preview_material("PrevBody", 0x8A8F99)

	# Wall along Y at x = -6: SlabA, SlabB, SlabA (turned) with a cluster at the foot.
	show("SlabA", ice, (-6, -4, 0), rot=(0, 0, math.pi / 2))
	show("SlabB", ice, (-6, 0, 0), rot=(0, 0, math.pi / 2))
	dupe("SlabA", deep, (-6, 4, 0), rot=(0, 0, -math.pi / 2))
	show("Cluster", ice, (-5.0, 1.6, 0), scale=(1.8, 1.8, 1.8))
	dupe("Cluster", ice, (-5.1, -3.0, 0), scale=(1.4, 1.4, 1.4), rot=(0, 0, 1.3))
	show("Pixels_Energy", magenta, (-5.3, -1.2, 5.0), scale=(1.4, 1.4, 1.4))
	show("Scanlines_Energy", magenta, (-5.35, 3.2, 6.5), scale=(1, 2.2, 1.2))
	edge = bpy.data.meshes.new("Edge")
	bm = box(-0.6, 0.6, -6, 6, 0, 0.06)
	bm.to_mesh(edge)
	bm.free()
	edge.materials.append(team)
	e = bpy.data.objects.new("Edge", edge)
	e.location = (-6, 0, 0)
	pv.objects.link(e)

	# The frozen body: a grey R15-ish mannequin in the Shell (core centre 2.9 up).
	for x0, x1, y0, y1, z0, z1 in ((-0.4, 0.4, -0.9, 0.9, 2.1, 4.1), (-0.4, 0.4, -0.85, -0.05, 0.1, 2.1), (-0.4, 0.4, 0.05, 0.85, 0.1, 2.1), (-0.4, 0.4, -1.9, -1.0, 2.0, 4.1), (-0.4, 0.4, 1.0, 1.9, 2.0, 4.1), (-0.5, 0.5, -0.55, 0.55, 4.2, 5.3)):
		me = bpy.data.meshes.new("Body")
		bm = box(x0, x1, y0, y1, z0, z1)
		bm.to_mesh(me)
		bm.free()
		me.materials.append(body)
		o = bpy.data.objects.new("Body", me)
		o.location = (0, -1, 0)
		pv.objects.link(o)
	show("Shell", shellm, (0, -1, 2.9))
	dupe("Shard3", magenta, (1.0, -2.6, 3.9), scale=(1.1, 1.1, 1.1), rot=(0.5, 0.9, 0))
	slice_me = bpy.data.meshes.new("Slice")
	bm = box(-1.3, 1.3, -2.1, 2.1, 0, 0.05)
	bm.to_mesh(slice_me)
	bm.free()
	slice_me.materials.append(magenta)
	s = bpy.data.objects.new("Slice", slice_me)
	s.location = (0, -1, 3.6)
	pv.objects.link(s)

	# The burst, front right: frost patch, cracks, ring, core cluster, a few spikes.
	bx, by = 4.5, 4.0
	show("Floor", ice, (bx, by, 0), scale=(3.4, 3.4, 1))
	show("Cracks_Energy", white, (bx, by, 0), scale=(3.4, 3.4, 1))
	show("Ring_Energy", white, (bx, by, 0), scale=(4.2, 4.2, 1.2))
	dupe("Cluster", ice, (bx, by, 0), scale=(2.4, 2.4, 2.4))
	for k in range(6):
		a = 2 * math.pi * k / 6 + 0.3
		name = ("Shard1", "Shard2", "Shard3")[k % 3]
		dupe(name, ice if k % 2 else deep, (bx + 2.2 * math.cos(a), by + 2.2 * math.sin(a), 0), scale=(1.4, 1.4, 1.4 + 0.3 * (k % 2)), rot=(-0.45 * math.sin(a), 0.45 * math.cos(a), 0))

	# The loose pieces in a row, front left.
	for i, (name, mat, sc) in enumerate((("Shard1", ice, 1.6), ("Shard2", deep, 1.6), ("Shard3", ice, 1.6), ("Fragment1", ice, 0.9), ("Fragment2", deep, 0.9), ("Fragment3", ice, 0.9))):
		z = 0.5 if name.startswith("Fragment") else 0
		show(name, mat, (5.0, -5.5 + i * 1.2, z), scale=(sc, sc, sc))

	stage(look_dir=(1.0, 0.25, 0.42), hover=0.0, lens=35, zoom=0.72)
	render(os.path.join(RENDER_DIR, "icevfx.jpg"))


def main():
	args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	report = build()
	path = blend_path(MOD)
	os.makedirs(os.path.dirname(path), exist_ok=True)
	bpy.ops.wm.save_as_mainfile(filepath=path)
	if "--render" in args:
		render_check()
	print("BUILD_MOD " + json.dumps({"mod": MOD, "blend": path, "tris": report}))


if __name__ == "__main__":
	main()
