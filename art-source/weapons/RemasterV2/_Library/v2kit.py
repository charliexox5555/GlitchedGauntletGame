# v2kit.py: shared helpers for the RemasterV2 weapon rebuild (fresh library, 2026-11-07).
# Not derived from the rejected Remaster/_Library/remaster.py. Each weapon owns its own builder and
# silhouette; this module only holds geometry primitives, the shared material roles, the review
# lighting/camera kit and the rig/locator helpers.
#
# Runs ONLY inside the visible interactive Blender session through Blender MCP:
#   exec(compile(open(path).read(), path, "exec"), ns)
# Every build goes into its own named scene so the user's own scenes and data are never touched.
#
# Axes (game contract): +X muzzle, +Z up, +Y gun-left (the side seen in first person), 1 unit = 1 stud,
# origin at the pistol grip.

import bpy, bmesh, math
from mathutils import Matrix, Vector

ROLES = ["Body", "Panel", "Dark", "Metal", "Grip", "Accent", "Neon", "Brass", "Glass"]
BODY, PANEL, DARK, METAL, GRIP, ACCENT, NEON, BRASS, GLASS = range(9)
TAG = "rv2"  # custom property on every datablock this kit creates


# ---------------------------------------------------------------- materials

def _lin(hexv):
	c = [((hexv >> 16) & 255) / 255, ((hexv >> 8) & 255) / 255, (hexv & 255) / 255]
	return [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c]


# role: (hex, metallic, roughness, roblox material, extra)
# v03 palette (2026-11-08): more separation between the roles for polish without textures: cooler graphite
# body, clearly lighter inset panels, brighter satin steel, a richer steel-blue accent. Skins swap these per role.
ROLE_SPEC = {
	"Body": (0x383D48, 0.12, 0.44, "SmoothPlastic", "coat"),  # graphite cerakote-style coating
	"Panel": (0x555C69, 0.12, 0.48, "SmoothPlastic", "coat"),  # lighter inset panels, plates
	"Dark": (0x1C1E23, 0.0, 0.6, "SmoothPlastic", "poly"),  # dark polymer: mag, stock pad, guard
	"Metal": (0x62676F, 0.85, 0.32, "Metal", "satin"),  # satin steel: barrel, bolt, pins
	"Grip": (0x25272D, 0.0, 0.70, "SmoothPlastic", "grip"),  # textured grip polymer
	# Final pass 2026-11-11 (owner: "the blue actions ... I want to change that"): the controls are bright satin
	# nickel, so the stock gun is neutral and the only colour left is the neon. Was steel-blue 3C66B8.
	"Accent": (0xAEB4BC, 0.9, 0.3, "Metal", "satin"),  # bright nickel: charging handles, selectors, releases
	"Neon": (0x2A6BFF, 0.0, 0.3, "Neon", "neon"),
	"Brass": (0xA8844E, 0.9, 0.34, "Metal", "satin"),  # cartridge cases and shell heads only (v02)
	"Glass": (0x16202C, 0.0, 0.08, "Glass", "poly"),  # scope lenses (final pass; they were Accent)
}


def materials():
	# Returns the 7 shared role materials (created once, reused by every RemasterV2 weapon).
	out = []
	for role in ROLES:
		m = bpy.data.materials.get(role)
		if m is not None and not m.get(TAG):
			raise RuntimeError("material name clash with non-kit material: " + role)
		if m is None:
			m = bpy.data.materials.new(role)
			m[TAG] = True
		_setup(m, role)
		out.append(m)
	return out


def _setup(m, role):
	hexv, metallic, rough, rbx, kind = ROLE_SPEC[role]
	c = _lin(hexv)
	m["rbx_material"] = rbx
	m["rbx_color"] = "%06X" % hexv
	m.use_nodes = True
	nt = m.node_tree
	nt.nodes.clear()
	out = nt.nodes.new("ShaderNodeOutputMaterial")
	bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
	nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
	bsdf.inputs["Metallic"].default_value = metallic
	bsdf.inputs["Roughness"].default_value = rough
	bsdf.inputs["Base Color"].default_value = (*c, 1)
	m.diffuse_color = (*c, 1)
	m.metallic = metallic
	m.roughness = rough
	if kind == "neon":
		bsdf.inputs["Base Color"].default_value = (0.01, 0.012, 0.02, 1)
		bsdf.inputs["Emission Color"].default_value = (*c, 1)
		bsdf.inputs["Emission Strength"].default_value = 6.0
		return
	tc = nt.nodes.new("ShaderNodeTexCoord")
	if kind in ("coat", "poly", "satin"):
		# Very low-frequency tonal drift only (no grime, no speckle): keeps big flats from looking dead.
		nz = nt.nodes.new("ShaderNodeTexNoise")
		nz.inputs["Scale"].default_value = 2.2
		nz.inputs["Detail"].default_value = 1.0
		nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
		ramp = nt.nodes.new("ShaderNodeValToRGB")
		ramp.color_ramp.elements[0].position = 0.35
		ramp.color_ramp.elements[0].color = (*[v * 0.94 for v in c], 1)
		ramp.color_ramp.elements[1].position = 0.65
		ramp.color_ramp.elements[1].color = (*[v * 1.06 for v in c], 1)
		nt.links.new(nz.outputs["Fac"], ramp.inputs["Fac"])
		nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
		rr = nt.nodes.new("ShaderNodeMapRange")
		rr.inputs["To Min"].default_value = rough - 0.03
		rr.inputs["To Max"].default_value = rough + 0.03
		nt.links.new(nz.outputs["Fac"], rr.inputs["Value"])
		nt.links.new(rr.outputs["Result"], bsdf.inputs["Roughness"])
	if kind == "satin":
		# Brushed direction along X for exposed steel: anisotropic-looking streaks via stretched noise.
		mp = nt.nodes.new("ShaderNodeMapping")
		mp.inputs["Scale"].default_value = (6.0, 160.0, 160.0)
		nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
		br = nt.nodes.new("ShaderNodeTexNoise")
		br.inputs["Scale"].default_value = 1.0
		br.inputs["Detail"].default_value = 2.0
		nt.links.new(mp.outputs["Vector"], br.inputs["Vector"])
		rr2 = nt.nodes.new("ShaderNodeMapRange")
		rr2.inputs["To Min"].default_value = rough - 0.05
		rr2.inputs["To Max"].default_value = rough + 0.05
		nt.links.new(br.outputs["Fac"], rr2.inputs["Value"])
		nt.links.new(rr2.outputs["Result"], bsdf.inputs["Roughness"])
	if kind == "grip":
		# Designed grip texture: a regular raised diamond stipple (bump only, clean and even).
		mp = nt.nodes.new("ShaderNodeMapping")
		mp.inputs["Rotation"].default_value = (0.0, 0.0, 0.0)
		nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
		wa = nt.nodes.new("ShaderNodeTexWave")
		wa.wave_type = "BANDS"
		wa.bands_direction = "DIAGONAL"
		wa.inputs["Scale"].default_value = 70.0
		wb = nt.nodes.new("ShaderNodeTexWave")
		wb.wave_type = "BANDS"
		wb.bands_direction = "DIAGONAL"
		wb.inputs["Scale"].default_value = 70.0
		mp2 = nt.nodes.new("ShaderNodeMapping")
		mp2.inputs["Scale"].default_value = (-1.0, 1.0, 1.0)
		nt.links.new(tc.outputs["Object"], mp2.inputs["Vector"])
		nt.links.new(mp.outputs["Vector"], wa.inputs["Vector"])
		nt.links.new(mp2.outputs["Vector"], wb.inputs["Vector"])
		mul = nt.nodes.new("ShaderNodeMath")
		mul.operation = "MULTIPLY"
		nt.links.new(wa.outputs["Fac"], mul.inputs[0])
		nt.links.new(wb.outputs["Fac"], mul.inputs[1])
		bp = nt.nodes.new("ShaderNodeBump")
		bp.inputs["Strength"].default_value = 0.35
		bp.inputs["Distance"].default_value = 0.002
		nt.links.new(mul.outputs["Value"], bp.inputs["Height"])
		nt.links.new(bp.outputs["Normal"], bsdf.inputs["Normal"])


# ---------------------------------------------------------------- 2D profile helpers

def chamfer(pts, r):
	# Cuts each corner of a closed polygon. r: one size for all corners or a list per vertex (0 = keep).
	n = len(pts)
	rs = r if isinstance(r, (list, tuple)) else [r] * n
	out = []
	for i in range(n):
		p = Vector(pts[i])
		ri = rs[i]
		if ri <= 0:
			out.append(tuple(p))
			continue
		a = Vector(pts[i - 1])
		b = Vector(pts[(i + 1) % n])
		da = (a - p)
		db = (b - p)
		ra = min(ri, da.length * 0.45)
		rb = min(ri, db.length * 0.45)
		out.append(tuple(p + da.normalized() * ra))
		out.append(tuple(p + db.normalized() * rb))
	return out


def rect(x0, x1, z0, z1, r=0.0):
	return chamfer([(x0, z0), (x1, z0), (x1, z1), (x0, z1)], r)


def section(hw, z0, z1, ct, cb):
	# Chamfered cross-section (y, z): ct top chamfer, cb bottom chamfer.
	return chamfer([(-hw, z0), (hw, z0), (hw, z1), (-hw, z1)], [cb, cb, ct, ct])


def circle(cx, cy, r, segs, rot=None):
	rot = math.pi / segs if rot is None else rot
	return [(cx + r * math.cos(rot + 2 * math.pi * i / segs), cy + r * math.sin(rot + 2 * math.pi * i / segs)) for i in range(segs)]


def stadium(x0, x1, zc, h, segs=3):
	r = h / 2
	pts = []
	for i in range(segs + 1):
		a = -math.pi / 2 + math.pi * i / segs
		pts.append((x1 - r + r * math.cos(a), zc + r * math.sin(a)))
	for i in range(segs + 1):
		a = math.pi / 2 + math.pi * i / segs
		pts.append((x0 + r + r * math.cos(a), zc + r * math.sin(a)))
	return pts


# ---------------------------------------------------------------- bmesh builders

def prism(pts, axis, w0, w1, mat=BODY):
	# Extrudes a closed 2D profile. axis "Y": pts (x, z); "X": (y, z); "Z": (x, y).
	bm = bmesh.new()

	def co(a, b, w):
		if axis == "Y":
			return (a, w, b)
		if axis == "X":
			return (w, a, b)
		return (a, b, w)

	r0 = [bm.verts.new(co(a, b, w0)) for a, b in pts]
	r1 = [bm.verts.new(co(a, b, w1)) for a, b in pts]
	n = len(pts)
	bm.faces.new(r0[::-1])
	bm.faces.new(r1)
	for i in range(n):
		j = (i + 1) % n
		bm.faces.new((r0[i], r0[j], r1[j], r1[i]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	for f in bm.faces:
		f.material_index = mat
	return bm


def loft_x(sections, mat=BODY):
	# sections: [(x, [(y, z), ...]), ...] all with the same vertex count. Closed caps.
	bm = bmesh.new()
	rings = [[bm.verts.new((x, y, z)) for y, z in pts] for x, pts in sections]
	bm.faces.new(rings[0][::-1])
	bm.faces.new(rings[-1])
	for a, b in zip(rings, rings[1:]):
		n = len(a)
		for i in range(n):
			j = (i + 1) % n
			bm.faces.new((a[i], a[j], b[j], b[i]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	for f in bm.faces:
		f.material_index = mat
	return bm


def box(x0, x1, y0, y1, z0, z1, mat=BODY):
	return prism([(x0, z0), (x1, z0), (x1, z1), (x0, z1)], "Y", y0, y1, mat)


def cyl_x(x0, x1, r, y, z, segs=12, mat=METAL, rot=None):
	return prism(circle(y, z, r, segs, rot), "X", x0, x1, mat)


def cyl_y(x, z, r, y0, y1, segs=8, mat=METAL, rot=None):
	return prism(circle(x, z, r, segs, rot), "Y", y0, y1, mat)


def annulus_x(x0, x1, cy, cz, r_out, r_in, segs, mat=DARK, rot=None):
	# Flat ring facing X (sight rings), open centre.
	rot = math.pi / segs if rot is None else rot
	bm = bmesh.new()
	o0, o1, i0, i1 = [], [], [], []
	for k in range(segs):
		a = rot + 2 * math.pi * k / segs
		ca, sa = math.cos(a), math.sin(a)
		o0.append(bm.verts.new((x0, cy + r_out * ca, cz + r_out * sa)))
		o1.append(bm.verts.new((x1, cy + r_out * ca, cz + r_out * sa)))
		i0.append(bm.verts.new((x0, cy + r_in * ca, cz + r_in * sa)))
		i1.append(bm.verts.new((x1, cy + r_in * ca, cz + r_in * sa)))
	for j in range(segs):
		k = (j + 1) % segs
		bm.faces.new((o0[j], o0[k], o1[k], o1[j]))
		bm.faces.new((i0[k], i0[j], i1[j], i1[k]))
		bm.faces.new((o0[k], o0[j], i0[j], i0[k]))
		bm.faces.new((o1[j], o1[k], i1[k], i1[j]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	for f in bm.faces:
		f.material_index = mat
	return bm


def annulus_y(x, z, r_out, r_in, y0, y1, segs, mat=METAL, rot=None):
	bm = annulus_x(y0, y1, x, z, r_out, r_in, segs, mat, rot)
	# annulus_x built with (X=w, Y=a, Z=b); swap X<->Y.
	for v in bm.verts:
		v.co = Vector((v.co.y, v.co.x, v.co.z))
	bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
	return bm


def torus(center, axis, R, r, n=10, m=4, mat=METAL):
	# Ring of square-ish section. axis: "X", "Y" or "Z" is the ring's normal.
	bm = bmesh.new()
	cx, cy, cz = center
	grid = []
	for i in range(n):
		a = 2 * math.pi * i / n
		row = []
		for j in range(m):
			b = 2 * math.pi * j / m + math.pi / 4
			rad = R + r * math.cos(b)
			u, v, w = rad * math.cos(a), rad * math.sin(a), r * math.sin(b)
			if axis == "Y":
				p = (cx + u, cy + w, cz + v)
			elif axis == "X":
				p = (cx + w, cy + u, cz + v)
			else:
				p = (cx + u, cy + v, cz + w)
			row.append(bm.verts.new(p))
		grid.append(row)
	for i in range(n):
		for j in range(m):
			bm.faces.new((grid[i][j], grid[(i + 1) % n][j], grid[(i + 1) % n][(j + 1) % m], grid[i][(j + 1) % m]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	for f in bm.faces:
		f.material_index = mat
	return bm


def merge(dst, src):
	tmp = bpy.data.meshes.new("_rv2_tmp")
	src.to_mesh(tmp)
	dst.from_mesh(tmp)
	bpy.data.meshes.remove(tmp)
	src.free()
	return dst


def group(*bms):
	out = bmesh.new()
	for b in bms:
		merge(out, b)
	return out


def copy(bm):
	tmp = bpy.data.meshes.new("_rv2_tmp")
	bm.to_mesh(tmp)
	out = bmesh.new()
	out.from_mesh(tmp)
	bpy.data.meshes.remove(tmp)
	return out


def mirror_y(bm, keep=True):
	other = copy(bm)
	bmesh.ops.scale(other, vec=(1, -1, 1), verts=other.verts[:])
	bmesh.ops.reverse_faces(other, faces=other.faces[:])
	if keep:
		return merge(bm, other)
	bm.free()
	return other


def xform(bm, mat):
	bmesh.ops.transform(bm, matrix=mat, verts=bm.verts[:])
	return bm


def rot_y(bm, angle, pivot):
	bmesh.ops.rotate(bm, verts=bm.verts[:], cent=pivot, matrix=Matrix.Rotation(angle, 3, "Y"))
	return bm


def set_mat(bm, mat):
	for f in bm.faces:
		f.material_index = mat
	return bm


def drop(bm, axis, sign, thresh=0.99):
	# Deletes faces facing one way (buried caps), to save triangles.
	bm.normal_update()
	bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.normal[axis] * sign > thresh], context="FACES")
	return bm


def bevel(bm, width, segs=1, angle=30, profile=0.5):
	if width <= 0:
		return bm
	bm.edges.ensure_lookup_table()
	edges = [e for e in bm.edges if e.is_manifold and e.calc_face_angle(0) > math.radians(angle)]
	if edges:
		bmesh.ops.bevel(bm, geom=edges, offset=width, offset_type="OFFSET", segments=segs, profile=profile, affect="EDGES", clamp_overlap=True, material=-1)
	return bm


# ---------------------------------------------------------------- booleans (exact solver)

_SCRATCH = {"col": None, "mats": None}


def _obj(bm, name):
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	for m in _SCRATCH["mats"]:
		me.materials.append(m)
	ob = bpy.data.objects.new(name, me)
	_SCRATCH["col"].objects.link(ob)
	return ob


def boolean(bm, other, op, cut_mat=None, mode=0):
	# op: "DIFFERENCE", "INTERSECT", "UNION". Faces produced by `other` take cut_mat when given.
	# mode 0: EXACT + self + hole tolerant (default); 1: EXACT plain; 2: MANIFOLD (fallbacks used by cut()).
	if cut_mat is not None:
		set_mat(other, cut_mat)
	t = _obj(bm, "_rv2_target")
	c = _obj(other, "_rv2_cutter")
	mod = t.modifiers.new("b", "BOOLEAN")
	mod.operation = op
	mod.solver = "MANIFOLD" if mode == 2 else "EXACT"  # Blender 5.x solvers: FLOAT, EXACT, MANIFOLD
	mod.object = c
	mod.material_mode = "INDEX"
	if mode == 0:
		mod.use_self = True  # cutters may overlap each other (grouped cutters)
		mod.use_hole_tolerant = True
	dg = bpy.context.evaluated_depsgraph_get()
	dg.update()
	out = bmesh.new()
	out.from_object(t, dg)
	for o in (t, c):
		me = o.data
		bpy.data.objects.remove(o)
		bpy.data.meshes.remove(me)
	bmesh.ops.remove_doubles(out, verts=out.verts[:], dist=1e-6)
	return out


CUT_CHECK = True  # v03: verify every cut really removed material (cuts into bevelled solids can fail silently)
CUT_LOG = []  # [(caller "file:line", expected volume, removed volume, healed by mode or None)]


def _vol(b):
	try:
		return abs(b.calc_volume(signed=True))
	except Exception:
		return 0.0


def cut(bm, cutter, cut_mat=None):
	if not CUT_CHECK:
		return boolean(bm, cutter, "DIFFERENCE", cut_mat)
	import traceback
	expect = _vol(boolean(copy(bm), copy(cutter), "INTERSECT"))
	src, cut_src = copy(bm), copy(cutter)
	v0 = _vol(bm)
	out = boolean(bm, cutter, "DIFFERENCE", cut_mat)
	if expect < 1e-7 or v0 - _vol(out) >= 0.5 * expect:
		src.free()
		cut_src.free()
		return out
	fr = traceback.extract_stack()[-2]
	where = "%s:%d" % (fr.filename.replace("\\", "/").split("/")[-1], fr.lineno)
	for mode in (1, 2):
		alt = boolean(copy(src), copy(cut_src), "DIFFERENCE", cut_mat, mode)
		if v0 - _vol(alt) >= 0.5 * expect:
			CUT_LOG.append((where, round(expect, 7), round(v0 - _vol(alt), 7), mode))
			out.free()
			src.free()
			cut_src.free()
			return alt
		alt.free()
	CUT_LOG.append((where, round(expect, 7), round(v0 - _vol(out), 7), None))
	src.free()
	cut_src.free()
	return out


def intersect(bm, other):
	return boolean(bm, other, "INTERSECT")


# ---------------------------------------------------------------- parts, rig, locators

class Part:
	# Keeps its closed pieces separate until the end so hidden faces can be culled between pieces.
	def __init__(self, name, bone="Root"):
		self.name = name
		self.bone = bone
		self.pieces = []

	def add(self, bm, width=0.0, segs=1, angle=30):
		self.pieces.append(bevel(bm, width, segs, angle))
		return self

	def merged(self):
		out = bmesh.new()
		for pc in self.pieces:
			merge(out, pc)
		self.pieces = []
		return out


def remove_hidden(occluders, targets, eps=0.0007):
	# Deletes faces of `targets` that lie completely inside (or flat against) another closed piece in
	# `occluders`. A face goes only if every sample (corners pulled 6% to the centre, plus the centre),
	# pushed eps along the face normal, is inside the same other piece. Returns the number removed.
	from mathutils.bvhtree import BVHTree
	data = []
	for bm in occluders:
		bm.normal_update()
		bm.verts.ensure_lookup_table()
		bm.faces.ensure_lookup_table()
		if not bm.verts:
			continue
		xs = [v.co for v in bm.verts]
		lo = Vector((min(v.x for v in xs), min(v.y for v in xs), min(v.z for v in xs)))
		hi = Vector((max(v.x for v in xs), max(v.y for v in xs), max(v.z for v in xs)))
		data.append((bm, BVHTree.FromBMesh(bm), lo, hi, [f.normal.copy() for f in bm.faces]))

	def inside(entry, p):
		bm, tree, lo, hi, normals = entry
		if not (lo.x - 1e-4 <= p.x <= hi.x + 1e-4 and lo.y - 1e-4 <= p.y <= hi.y + 1e-4 and lo.z - 1e-4 <= p.z <= hi.z + 1e-4):
			return False
		loc, nrm, idx, dist = tree.find_nearest(p)
		if loc is None:
			return False
		fn = normals[idx]
		return (p - loc).dot(fn) < -1e-7

	removed = 0
	kill = []  # decide everything first (trees index the untouched meshes), delete afterwards
	for bm in targets:
		bm.normal_update()
		dead = []
		for f in bm.faces:
			c = f.calc_center_median()
			n = f.normal
			pts = [c + n * eps] + [v.co.lerp(c, 0.06) + n * eps for v in f.verts]
			for entry in data:
				if entry[0] is bm:
					continue
				if all(inside(entry, p) for p in pts):
					dead.append(f)
					break
		kill.append((bm, dead))
	for bm, dead in kill:
		if dead:
			bmesh.ops.delete(bm, geom=dead, context="FACES")
			removed += len(dead)
	return removed


def tri_count(me):
	return sum(len(p.vertices) - 2 for p in me.polygons)


def new_scene(name):
	# Separate scene with its own world and render settings; returns (scene, collection root).
	sc = bpy.data.scenes.get(name)
	if sc is None:
		sc = bpy.data.scenes.new(name)
		sc[TAG] = True
	elif not sc.get(TAG):
		raise RuntimeError("scene exists and is not a kit scene: " + name)
	return sc


def clear_collection(col):
	for o in list(col.all_objects):
		data = o.data
		bpy.data.objects.remove(o)
		if data is not None and data.users == 0:
			if isinstance(data, bpy.types.Mesh):
				bpy.data.meshes.remove(data)
			elif isinstance(data, bpy.types.Armature):
				bpy.data.armatures.remove(data)
			elif isinstance(data, bpy.types.Camera):
				bpy.data.cameras.remove(data)
			elif isinstance(data, bpy.types.Light):
				bpy.data.lights.remove(data)
	for c in list(col.children_recursive):
		bpy.data.collections.remove(c)


def finish_mesh(bm, name, mats, sharp=34):
	# v03: merge within 0.0004 studs (bevel corner slivers; the smallest real detail is 0.0015).
	bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=4e-4)
	bmesh.ops.dissolve_degenerate(bm, dist=1e-6, edges=bm.edges[:])
	# Merge the coplanar splits booleans leave behind (same material only), then triangulate.
	bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(0.3), verts=bm.verts[:], edges=bm.edges[:], delimit={"MATERIAL", "SHARP"})
	bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="BEAUTY")
	# v03 export hygiene: an n-gon with a straight-through (T-junction) vertex triangulates into a zero-area sliver.
	# Flip each sliver's longest edge with its neighbour until none are left (clean shading, clean Roblox import).
	for _ in range(6):
		slivers = [f for f in bm.faces if f.calc_area() < 1e-9]
		if not slivers:
			break
		edges = {max(f.edges, key=lambda e: e.calc_length()) for f in slivers}
		edges = [e for e in edges if len(e.link_faces) == 2]
		if not edges:
			break
		bmesh.ops.rotate_edges(bm, edges=edges, use_ccw=False)
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	for m in mats:
		me.materials.append(m)
	me.shade_smooth()
	me.set_sharp_from_angle(angle=math.radians(sharp))
	return me


def build_rig(col, prefix, bones):
	arm = bpy.data.armatures.new(prefix + "Rig")
	rig = bpy.data.objects.new(prefix + "Rig", arm)
	col.objects.link(rig)
	arm.display_type = "STICK"
	rig.show_in_front = True
	win = bpy.context.window
	sc = win.scene
	vl = sc.view_layers[0]
	vl.update()
	for o in list(vl.objects):
		if o is not None:
			o.select_set(False, view_layer=vl)
	vl.objects.active = rig
	rig.select_set(True, view_layer=vl)
	with bpy.context.temp_override(window=win, scene=sc, view_layer=vl, active_object=rig, object=rig, selected_objects=[rig]):
		bpy.ops.object.mode_set(mode="EDIT")
		for name, parent, head in bones:
			eb = arm.edit_bones.new(name)
			eb.head = head
			eb.tail = Vector(head) + Vector((0, 0.08, 0))
			eb.roll = 0
			if parent:
				eb.parent = arm.edit_bones[parent]
		bpy.ops.object.mode_set(mode="OBJECT")
	vl.update()
	# The original rigs (and their clips) use Euler XYZ on every pose bone; quaternion would ignore rotation_euler keys.
	for pb in rig.pose.bones:
		pb.rotation_mode = "XYZ"
	return rig


def parent_to_bone(ob, rig, bone, world):
	ob.parent = rig
	ob.parent_type = "BONE"
	ob.parent_bone = bone
	bpy.context.window.scene.view_layers[0].update()
	ob.matrix_world = world


def uv_pack(col_name, margin=0.004):
	# One shared atlas per weapon: smart project, equalise texel density across every part, pack (all inside 0-1).
	# Returns per-part density (UV units per stud) and the packed coverage.
	import bmesh as _bm
	win = bpy.context.window
	sc = win.scene
	vl = sc.view_layers[0]
	meshes = [o for o in bpy.data.collections[col_name].objects if o.type == "MESH"]
	for o in list(vl.objects):
		if o is not None:
			o.select_set(False, view_layer=vl)
	for o in meshes:
		o.select_set(True, view_layer=vl)
	vl.objects.active = meshes[0]
	with bpy.context.temp_override(window=win, scene=sc, view_layer=vl, active_object=meshes[0], object=meshes[0], selected_objects=meshes, selected_editable_objects=meshes):
		bpy.ops.object.mode_set(mode="EDIT")
		bpy.ops.mesh.select_all(action="SELECT")
		bpy.ops.uv.smart_project(angle_limit=math.radians(55), island_margin=margin, scale_to_bounds=False)
		bpy.ops.uv.select_all(action="SELECT")
		bpy.ops.uv.average_islands_scale()
		bpy.ops.uv.pack_islands(rotate=True, scale=True, margin_method="FRACTION", margin=margin, shape_method="CONCAVE")
		bpy.ops.object.mode_set(mode="OBJECT")
	for o in meshes:
		o.select_set(False, view_layer=vl)
	dens, cov, inside = {}, 0.0, True
	for o in meshes:
		b = _bm.new()
		b.from_mesh(o.data)
		lay = b.loops.layers.uv.active
		a3 = sum(f.calc_area() for f in b.faces)
		auv = 0.0
		for f in b.faces:
			pts = [l[lay].uv for l in f.loops]
			for p in pts:
				if not (-1e-4 <= p.x <= 1.0001 and -1e-4 <= p.y <= 1.0001):
					inside = False
			s = 0.0
			for i in range(len(pts)):
				j = (i + 1) % len(pts)
				s += pts[i].x * pts[j].y - pts[j].x * pts[i].y
			auv += abs(s) / 2
		b.free()
		cov += auv
		dens[o.name] = round(math.sqrt(auv / a3), 3) if a3 else 0
	return {"density": dens, "coverage": round(cov, 3), "inside_0_1": inside}


def write_blend(path, scene, gun):
	# Writes ONLY this weapon's review scene (and its actions) to a new .blend; the live session keeps its own
	# file path and unsaved state.
	import os
	if os.path.exists(path):
		raise RuntimeError("exists: " + path)
	acts = {a for a in bpy.data.actions if a.name.startswith(gun + "_") and a.get("rv2")}
	bpy.data.libraries.write(path, {scene} | acts, path_remap="NONE", fake_user=True, compress=True)
	with bpy.data.libraries.load(path, link=False) as (src, dst):
		chk = {"scenes": list(src.scenes), "objects": len(src.objects), "actions": sorted(src.actions), "materials": sorted(src.materials)}
	chk["size_kb"] = round(os.path.getsize(path) / 1024)
	return chk
