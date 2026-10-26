# modkit.py: shared helpers for the scripted Mod prop builds (tools/blender/build_mod_<name>.py).
#
# The Mod look (vault/04 Tech/Mod System.md, "Art: the Mod look"): stylized, chunky, slightly cartoony shapes with a
# matte charcoal shell and big emissive energy parts in the team colour. Same axes as the guns, so one importer
# convention covers both:
#   +X forward, +Z up, +Y left, 1 unit = 1 stud.
#   Handheld props: origin at the grip (Handle locator). Thrown props: origin at the centre. Placed props: origin on
#   the floor at the centre, facing +X.
#   Material slots Shell / Dark / Trim / Energy / EnergyGlass (rbx_* properties give the Roblox look).
#   Energy parts are SEPARATE objects named <Part>_Energy that only use Energy / EnergyGlass, so the game can tint
#   them per viewer (ally cyan, enemy orange-red, magenta for glitches).
#   No armature: moving bits (lever, pin, plate, spinner) are their own parts; locators are empties.
#
# A build script makes its parts with these helpers and calls assemble(). Run it from the command line:
#   blender --background --factory-startup --python tools/blender/build_mod_<name>.py -- [--render]
# It rebuilds art-source/abilities/<Mod>/<Mod>.blend from scratch (the script is the source of truth) and, with
# --render, writes the check render to vault/02 Art/References/mods/.

import bpy, bmesh, json, math, os, sys
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
	sys.path.insert(0, HERE)
from gunkit import prism, box, ring_pts, stadium, drop, mirror_y, merge, group, bevel  # noqa: E402,F401

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
RENDER_DIR = os.path.join(ROOT, "vault", "02 Art", "References", "mods")

MAT_NAMES = ["Shell", "Dark", "Trim", "Energy", "EnergyGlass", "EnergyVFX"]
SHELL, DARK, TRIM, ENERGY, GLASS, VFX = range(6)
ENERGY_MATS = {ENERGY, GLASS, VFX}

ALLY = 0x00E5FF
ENEMY = 0xFF5A36
GLITCH = 0xFF3DCB


def lin(color):
	c = [((color >> 16) & 255) / 255, ((color >> 8) & 255) / 255, (color & 255) / 255]
	return [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c]


# ---------------------------------------------------------------- materials

def make_materials():
	def base(name, rbx_material, color):
		m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
		m["rbx_material"] = rbx_material
		m["rbx_color"] = "%06X" % color
		m.use_nodes = True
		nt = m.node_tree
		nt.nodes.clear()
		out = nt.nodes.new("ShaderNodeOutputMaterial")
		bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
		nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
		m.diffuse_color = (*lin(color), 1)
		return m, nt, bsdf

	def shell(name, color, metallic, rough, coat=0.0):
		m, nt, bsdf = base(name, "Metal" if metallic > 0.5 else "SmoothPlastic", color)
		bsdf.inputs["Base Color"].default_value = (*lin(color), 1)
		bsdf.inputs["Metallic"].default_value = metallic
		bsdf.inputs["Roughness"].default_value = rough
		bsdf.inputs["Coat Weight"].default_value = coat
		bsdf.inputs["Coat Roughness"].default_value = 0.25
		return m

	def energy(name, strength):
		m, nt, bsdf = base(name, "Neon", ALLY)
		m["energy"] = True
		bsdf.inputs["Base Color"].default_value = (*lin(ALLY), 1)
		bsdf.inputs["Emission Color"].default_value = (*lin(ALLY), 1)
		bsdf.inputs["Emission Strength"].default_value = strength
		bsdf.inputs["Roughness"].default_value = 0.2
		return m

	def glass(name, vfx=False):
		# Translucent energy (Firewall panel). The UV pattern (bright rim, grid lines) previews the in-game look: a
		# Neon part at 0.5 transparency (L1 blocks bullets, not vision) with a tinted grid Decal on both faces
		# (art-source/abilities/Textures/FirewallGrid.png, tools/vfx/make_mod_textures.py).
		m, nt, bsdf = base(name, "Neon", ALLY)
		m["energy"] = True
		m["rbx_transparency"] = 0.5
		m.surface_render_method = "BLENDED"
		m.use_backface_culling = False
		bsdf.inputs["Base Color"].default_value = (0.0, 0.0, 0.0, 1)
		bsdf.inputs["Emission Color"].default_value = (*lin(ALLY), 1)
		bsdf.inputs["Roughness"].default_value = 0.1
		L = nt.links

		def math_node(op, a, b=None):
			n = nt.nodes.new("ShaderNodeMath")
			n.operation = op
			for i, v in enumerate((a, b)):
				if v is None:
					continue
				if isinstance(v, (int, float)):
					n.inputs[i].default_value = v
				else:
					L.new(v, n.inputs[i])
			return n.outputs[0]

		tc = nt.nodes.new("ShaderNodeTexCoord")
		sep = nt.nodes.new("ShaderNodeSeparateXYZ")
		L.new(tc.outputs["UV"], sep.inputs[0])
		u, v = sep.outputs["X"], sep.outputs["Y"]
		eu = math_node("ABSOLUTE", math_node("SUBTRACT", u, 0.5))
		ev = math_node("ABSOLUTE", math_node("SUBTRACT", v, 0.5))
		# VFX meshes wrap around in U (the seam must not show), so their preview pattern only runs along V.
		rim = math_node("POWER", math_node("MULTIPLY", ev if vfx else math_node("MAXIMUM", eu, ev), 2.0), 6.0)
		if vfx:
			rim = math_node("ADD", rim, math_node("MULTIPLY", math_node("POWER", v, 3.0), 2.0))
		lines = math_node("POWER", math_node("ABSOLUTE", math_node("SINE", math_node("MULTIPLY", v, math.pi * 9))), 24.0)
		hexes = math_node("POWER", math_node("ABSOLUTE", math_node("SINE", math_node("MULTIPLY", u, math.pi * 12))), 40.0)
		glow = math_node("ADD", math_node("ADD", math_node("MULTIPLY", rim, 3.0), math_node("MULTIPLY", lines, 0.9)), math_node("MULTIPLY", hexes, 0.5))
		L.new(math_node("ADD", glow, 0.2), bsdf.inputs["Emission Strength"])
		alpha = math_node("MINIMUM", math_node("ADD", math_node("MULTIPLY", glow, 0.28), 0.08), 1.0)
		L.new(alpha, bsdf.inputs["Alpha"])
		return m

	return [
		shell("Shell", 0x2C2E35, 0.15, 0.45, coat=0.3),  # matte charcoal tactical shell
		shell("Dark", 0x16171B, 0.0, 0.55),  # near-black polymer: grips, bands, feet
		shell("Trim", 0x6E7480, 0.75, 0.3),  # light gunmetal accents
		energy("Energy", 2.0),  # team colour, Neon in game
		glass("EnergyGlass"),
		glass("EnergyVFX", vfx=True),
	]


def set_team(color):
	# Recolours every energy material (the in-game per-viewer tint, for check renders).
	c = (*lin(color), 1)
	for m in bpy.data.materials:
		if m.get("energy") and m.use_nodes:
			for n in m.node_tree.nodes:
				if n.type == "BSDF_PRINCIPLED":
					n.inputs["Emission Color"].default_value = c
					if m.name.startswith("Energy") and m.name != "EnergyGlass":
						n.inputs["Base Color"].default_value = c
			m["rbx_color"] = "%06X" % color


# ---------------------------------------------------------------- geometry helpers

def _mat(bm, mat):
	for f in bm.faces:
		f.material_index = mat
	return bm


def lathe(profile, segs=24, mat=SHELL, axis="Z", center=(0, 0, 0), rot=0.0):
	# Revolves a profile [(radius, height)] around Z (then turned onto `axis`). Points with radius 0 become poles.
	bm = bmesh.new()
	rings = []
	for r, h in profile:
		if r < 1e-6:
			rings.append([bm.verts.new((0, 0, h))])
		else:
			rings.append([bm.verts.new((r * math.cos(rot + 2 * math.pi * i / segs), r * math.sin(rot + 2 * math.pi * i / segs), h)) for i in range(segs)])
	for a, b in zip(rings, rings[1:]):
		if len(a) == 1 and len(b) == 1:
			continue
		for i in range(segs):
			j = (i + 1) % segs
			if len(a) == 1:
				bm.faces.new((a[0], b[i], b[j]))
			elif len(b) == 1:
				bm.faces.new((a[i], a[j], b[0]))
			else:
				bm.faces.new((a[i], a[j], b[j], b[i]))
	# Open ends with a full ring get a cap.
	for ring in (rings[0], rings[-1]):
		if len(ring) > 1:
			bm.faces.new(ring)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	_mat(bm, mat)
	return place(bm, axis_matrix(axis, center))


def sphere(r, segs=20, rings=12, mat=ENERGY, axis="Z", center=(0, 0, 0)):
	prof = [(r * math.sin(math.pi * i / rings), -r * math.cos(math.pi * i / rings)) for i in range(rings + 1)]
	prof[0] = (0, -r)
	prof[-1] = (0, r)
	return lathe(prof, segs, mat, axis, center)


def capsule(r, length, segs=16, cap_rings=4, mat=ENERGY, axis="X", center=(0, 0, 0)):
	half = length / 2 - r
	prof = [(0, -half - r)]
	for i in range(1, cap_rings + 1):
		a = math.pi / 2 * i / cap_rings
		prof.append((r * math.sin(a), -half - r * math.cos(a)))
	for i in range(cap_rings - 1, 0, -1):
		a = math.pi / 2 * i / cap_rings
		prof.append((r * math.sin(a), half + r * math.cos(a)))
	prof.append((0, half + r))
	return lathe(prof, segs, mat, axis, center)


def torus(R, r, n=24, m=8, mat=TRIM, axis="Z", center=(0, 0, 0)):
	bm = bmesh.new()
	grid = []
	for i in range(n):
		a = 2 * math.pi * i / n
		row = []
		for j in range(m):
			b = 2 * math.pi * j / m
			rad = R + r * math.cos(b)
			row.append(bm.verts.new((rad * math.cos(a), rad * math.sin(a), r * math.sin(b))))
		grid.append(row)
	for i in range(n):
		for j in range(m):
			bm.faces.new((grid[i][j], grid[(i + 1) % n][j], grid[(i + 1) % n][(j + 1) % m], grid[i][(j + 1) % m]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	_mat(bm, mat)
	return place(bm, axis_matrix(axis, center))


def band(n, rin, rout, z0, z1, mat=ENERGY, rot=0.0, rin_top=None, rout_top=None):
	# A closed ring (hex channel, washer) around Z: inner/outer radius, optional different top radii (frustum).
	rin_top = rin if rin_top is None else rin_top
	rout_top = rout if rout_top is None else rout_top
	bm = bmesh.new()

	def ring(r, z):
		return [bm.verts.new((r * math.cos(rot + 2 * math.pi * i / n), r * math.sin(rot + 2 * math.pi * i / n), z)) for i in range(n)]

	ob, ib, ot, it = ring(rout, z0), ring(rin, z0), ring(rout_top, z1), ring(rin_top, z1)
	for i in range(n):
		j = (i + 1) % n
		bm.faces.new((ob[i], ob[j], ot[j], ot[i]))
		bm.faces.new((ib[j], ib[i], it[i], it[j]))
		bm.faces.new((ot[i], ot[j], it[j], it[i]))
		bm.faces.new((ib[i], ib[j], ob[j], ob[i]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	return _mat(bm, mat)


def frustum(n, r0, r1, z0, z1, mat=SHELL, rot=0.0):
	# n-sided solid with bottom radius r0 and top radius r1 (hex pad body).
	bm = bmesh.new()
	b = [bm.verts.new((r0 * math.cos(rot + 2 * math.pi * i / n), r0 * math.sin(rot + 2 * math.pi * i / n), z0)) for i in range(n)]
	t = [bm.verts.new((r1 * math.cos(rot + 2 * math.pi * i / n), r1 * math.sin(rot + 2 * math.pi * i / n), z1)) for i in range(n)]
	bm.faces.new(b[::-1])
	bm.faces.new(t)
	for i in range(n):
		j = (i + 1) % n
		bm.faces.new((b[i], b[j], t[j], t[i]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	return _mat(bm, mat)


def axis_matrix(axis, center=(0, 0, 0)):
	# Turns geometry built around Z onto another axis, then moves it to `center`.
	rot = {"Z": Matrix.Identity(4), "X": Matrix.Rotation(math.pi / 2, 4, "Y"), "Y": Matrix.Rotation(-math.pi / 2, 4, "X")}[axis]
	return Matrix.Translation(center) @ rot


def place(bm, matrix):
	bmesh.ops.transform(bm, matrix=matrix, verts=bm.verts[:])
	if matrix.determinant() < 0:
		bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
	return bm


def rot_z(angle, offset=(0, 0, 0)):
	return Matrix.Translation(offset) @ Matrix.Rotation(angle, 4, "Z")


def rot_x(angle, offset=(0, 0, 0)):
	return Matrix.Translation(offset) @ Matrix.Rotation(angle, 4, "X")


def frame(origin, u, v):
	# Matrix whose local X/Y/Z are u, v and u x v at `origin` (to stick a decal-like part onto a sloped face).
	u, v = Vector(u).normalized(), Vector(v).normalized()
	n = u.cross(v)
	m = Matrix((u, v, n)).transposed().to_4x4()
	m.translation = origin
	return m


def copy(bm):
	tmp = bpy.data.meshes.new("_c")
	bm.to_mesh(tmp)
	out = bmesh.new()
	out.from_mesh(tmp)
	bpy.data.meshes.remove(tmp)
	return out


# ---------------------------------------------------------------- parts and assembly

def KEEP(bm, layer):
	# Part.uv value for geometry that already carries its UVs (grid() below).
	pass


def grid(nu, nv, pos, mat=VFX, pole_start=False, pole_end=False):
	# A (nu x nv)-quad sheet from pos(u, v) -> (x, y, z), u and v in 0..1, with UVs = (u, v). The u = 1 column
	# duplicates u = 0 (assemble() welds the vertices, the UV seam stays), so a texture scrolls cleanly around it.
	# pole_start / pole_end: the v = 0 / v = 1 row collapses to a point (a triangle fan instead of thin quads).
	bm = bmesh.new()
	layer = bm.loops.layers.uv.verify()
	rows = [[bm.verts.new(pos(i / nu, j / nv)) for i in range(nu + 1)] for j in range(nv + 1)]
	for j in range(nv):
		for i in range(nu):
			a, b, c, d = rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]
			uvs = [(i / nu, j / nv), ((i + 1) / nu, j / nv), ((i + 1) / nu, (j + 1) / nv), (i / nu, (j + 1) / nv)]
			if pole_start and j == 0:
				vs, uv = (a, c, d), [((i + 0.5) / nu, 0), uvs[2], uvs[3]]
			elif pole_end and j == nv - 1:
				vs, uv = (a, b, c), [uvs[0], uvs[1], ((i + 0.5) / nu, 1)]
			else:
				vs, uv = (a, b, c, d), uvs
			f = bm.faces.new(vs)
			f.material_index = mat
			for loop, t in zip(f.loops, uv):
				loop[layer].uv = t
	return bm


class Part:
	def __init__(self, name, uv=None):
		# uv: None = smart project into the shared atlas; a function(bm, uv_layer) = explicit UVs (scrolling textures).
		self.name = name
		self.uv = uv
		self.bm = bmesh.new()

	@property
	def energy(self):
		return self.name.endswith("_Energy")

	def add(self, bm, width=0.0, segs=3, angle=30):
		merge(self.bm, bevel(bm, width, segs, angle) if width > 0 else bm)
		return self


def begin(mod):
	# Fresh empty file: the build script is the source of truth for the .blend.
	bpy.ops.wm.read_homefile(use_empty=True)
	return make_materials()


def assemble(mod, parts, mats, locators, props, smooth_angle=40):
	# Turns the parts into mesh objects in a collection named after the Mod, adds the locators (empties) and UVs.
	# locators: [(name, position, rotation matrix or None)]. Returns {part: triangles, "_total_tris": n}.
	scene = bpy.context.scene
	pre = mod + "_"
	col = bpy.data.collections.new(mod)
	scene.collection.children.link(col)
	col["ability_name"] = mod
	for k, v in props.items():
		col[k] = v

	report = {}
	smart = []
	for p in parts:
		bm = p.bm
		used = {f.material_index for f in bm.faces}
		if p.energy and not used <= ENERGY_MATS:
			raise ValueError("%s is an energy part but uses non-energy materials %s" % (p.name, used))
		if not p.energy and used & ENERGY_MATS:
			raise ValueError("%s uses an energy material; energy goes in a separate <Part>_Energy part" % p.name)
		bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-6)
		bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="BEAUTY")
		if p.uv:
			p.uv(bm, bm.loops.layers.uv.verify())
		me = bpy.data.meshes.new(pre + p.name)
		bm.to_mesh(me)
		bm.free()
		for m in mats:
			me.materials.append(m)
		me.shade_smooth()
		me.set_sharp_from_angle(angle=math.radians(smooth_angle))
		ob = bpy.data.objects.new(pre + p.name, me)
		col.objects.link(ob)
		if p.energy:
			ob["energy"] = True
		wn = ob.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
		wn.keep_sharp = True
		wn.weight = 60
		report[p.name] = len(me.polygons)
		if not p.uv:
			smart.append(ob)

	for name, pos, rot in locators:
		e = bpy.data.objects.new(pre + name, None)
		e.empty_display_type = "ARROWS" if rot is not None else "PLAIN_AXES"
		e.empty_display_size = 0.15
		col.objects.link(e)
		e.matrix_world = Matrix.Translation(pos) @ (rot if rot is not None else Matrix.Identity(4))
		e.hide_render = True

	if smart:
		for o in bpy.context.view_layer.objects:
			o.select_set(False)
		for o in smart:
			o.select_set(True)
		bpy.context.view_layer.objects.active = smart[0]
		bpy.ops.object.mode_set(mode="EDIT")
		bpy.ops.mesh.select_all(action="SELECT")
		bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.01, scale_to_bounds=False)
		bpy.ops.uv.select_all(action="SELECT")
		bpy.ops.uv.average_islands_scale()
		bpy.ops.uv.pack_islands(rotate=True, scale=True, margin_method="FRACTION", margin=0.004, shape_method="CONCAVE")
		bpy.ops.object.mode_set(mode="OBJECT")
		for o in smart:
			o.select_set(False)

	report["_total_tris"] = sum(report.values())
	col["tris"] = report["_total_tris"]
	return report


# ---------------------------------------------------------------- check renders

def bounds(objs):
	pts = [o.matrix_world @ Vector(c) for o in objs if o.type == "MESH" and not o.hide_render for c in o.bound_box]
	lo = Vector([min(p[i] for p in pts) for i in range(3)])
	hi = Vector([max(p[i] for p in pts) for i in range(3)])
	return lo, hi


def bloom(strength=0.8, size=0.55, threshold=0.8):
	sc = bpy.context.scene
	ng = bpy.data.node_groups.get("Bloom") or bpy.data.node_groups.new("Bloom", "CompositorNodeTree")
	ng.nodes.clear()
	if not ng.interface.items_tree:
		ng.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
	rl = ng.nodes.new("CompositorNodeRLayers")
	gl = ng.nodes.new("CompositorNodeGlare")
	for v in ("Bloom", "BLOOM"):
		try:
			gl.inputs["Type"].default_value = v
			break
		except Exception:
			pass
	try:
		gl.inputs["Quality"].default_value = "High"
	except Exception:
		pass
	gl.inputs["Threshold"].default_value = threshold
	gl.inputs["Strength"].default_value = strength
	gl.inputs["Size"].default_value = size
	go = ng.nodes.new("NodeGroupOutput")
	ng.links.new(rl.outputs["Image"], gl.inputs["Image"])
	ng.links.new(gl.outputs[0], go.inputs[0])
	sc.compositing_node_group = ng
	sc.render.use_compositing = True


def stage(look_dir=(0.8, 1.0, 0.55), floor=True, target=None, radius=None, lens=50, hover=None, zoom=1.0):
	# Dark studio for the check renders, in a "Preview" collection (never exported). Frames every visible mesh.
	sc = bpy.context.scene
	pv = bpy.data.collections.get("Preview")
	if not pv:
		pv = bpy.data.collections.new("Preview")
		sc.collection.children.link(pv)
	for o in list(pv.objects):
		bpy.data.objects.remove(o)
	bpy.context.view_layer.update()
	objs = [o for o in sc.objects if o.type == "MESH" and pv not in o.users_collection]
	lo, hi = bounds(objs)
	c = Vector(target) if target else (lo + hi) / 2
	r = radius or (hi - lo).length / 2

	def link(o):
		pv.objects.link(o)
		return o

	def look(o, t):
		o.rotation_euler = (Vector(t) - o.location).to_track_quat("-Z", "Y").to_euler()

	if floor:
		fz = lo.z - (hover if hover is not None else 0.0)
		me = bpy.data.meshes.new("Floor")
		s = r * 40
		bm = box(-s, s, -s, s, fz - 0.01, fz)
		bm.to_mesh(me)
		bm.free()
		fm = bpy.data.materials.get("Floor") or bpy.data.materials.new("Floor")
		fm.use_nodes = True
		b = fm.node_tree.nodes.get("Principled BSDF")
		b.inputs["Base Color"].default_value = (0.0025, 0.003, 0.004, 1)
		b.inputs["Roughness"].default_value = 0.5
		b.inputs["Specular IOR Level"].default_value = 0.12
		me.materials.append(fm)
		link(bpy.data.objects.new("Floor", me))

	d = Vector(look_dir).normalized()
	cd = bpy.data.cameras.new("Cam_Hero")
	cd.lens = lens
	cam = link(bpy.data.objects.new("Cam_Hero", cd))
	half_v = math.atan(18 / lens * sc.render.resolution_y / sc.render.resolution_x)
	cam.location = c + d * (r / math.sin(half_v) * 1.02 * zoom)
	look(cam, c)
	sc.camera = cam

	def light(name, offset, energy, color=(1, 1, 1), size=1.0):
		l = bpy.data.lights.new(name, "AREA")
		l.energy = energy * r * r
		l.size = size * r
		l.color = color
		o = link(bpy.data.objects.new(name, l))
		o.location = c + Vector(offset) * r
		look(o, c)

	side = Vector((d.x, d.y, 0)).normalized()
	left = Vector((-side.y, side.x, 0))
	light("Key", tuple(side * 1.4 + left * 1.6 + Vector((0, 0, 2.2))), 130, (1, 0.97, 0.94), 1.2)
	light("Fill", tuple(side * 2.2 - left * 1.8 + Vector((0, 0, 0.6))), 45, (0.85, 0.9, 1), 1.5)
	light("Rim", tuple(-side * 2.2 + left * 0.6 + Vector((0, 0, 1.6))), 150, (0.8, 0.9, 1), 0.8)
	light("Rim2", tuple(-side * 1.8 - left * 1.6 + Vector((0, 0, 1.0))), 90, (0.8, 0.9, 1), 0.8)

	w = sc.world or bpy.data.worlds.new("World")
	sc.world = w
	w.use_nodes = True
	w.node_tree.nodes.get("Background").inputs[0].default_value = (0.010, 0.012, 0.018, 1)
	sc.render.engine = "BLENDER_EEVEE"
	sc.eevee.taa_render_samples = 64
	sc.eevee.use_raytracing = True
	# Standard keeps the team colour saturated (AgX washes bright cyan out to white); closest to Roblox Neon.
	sc.view_settings.view_transform = "Standard"
	bloom()
	return cam


def render(path, res=(1600, 1000)):
	sc = bpy.context.scene
	sc.render.resolution_x, sc.render.resolution_y = res
	sc.render.resolution_percentage = 100
	sc.render.image_settings.file_format = "JPEG"
	sc.render.image_settings.quality = 92
	sc.render.filepath = path
	os.makedirs(os.path.dirname(path), exist_ok=True)
	bpy.ops.render.render(write_still=True)
	return path


def blend_path(mod):
	return os.path.join(ROOT, "art-source", "abilities", mod, mod + ".blend")


def cli(mod, build, render_name, look_dir=(0.8, 1.0, 0.55), hover=None, lens=50, zoom=1.0):
	# Command-line entry for a build script: rebuild, save the .blend, optionally render the check view.
	args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	report = build()
	stage(look_dir, hover=hover, lens=lens, zoom=zoom)
	path = blend_path(mod)
	os.makedirs(os.path.dirname(path), exist_ok=True)
	bpy.ops.wm.save_as_mainfile(filepath=path)
	if "--render" in args:
		render(os.path.join(RENDER_DIR, render_name + ".jpg"))
	print("BUILD_MOD " + json.dumps({"mod": mod, "blend": path, "tris": report}))
	return report
