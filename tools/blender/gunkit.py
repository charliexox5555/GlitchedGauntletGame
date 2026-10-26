# gunkit.py: shared helpers for the scripted gun builds (tools/blender/build_<gun>.py).
#
# Same conventions as build_vandal.py (where these helpers come from), so every gun in the family matches:
#   +X muzzle, +Z up, +Y gun-left (the side seen in first person), 1 unit = 1 stud, origin at the pistol grip.
#   Material slots Body_Panel / Body_Dark / Metal / Neon (one shared palette, rbx_* looks for the export).
#   One armature, bones point along +Y with no roll; mesh parts are parented to their bone; locators are empties.
#   All parts share ONE UV atlas so tools/blender/bake_textures.py bakes a single texture set per gun.
#
# A build script imports this, makes its parts with the helpers and calls assemble(). Run it inside Blender with
#   g = {"__name__": "build", "__file__": path}; exec(compile(open(path).read(), path, "exec"), g); g["build"]()

import bpy, bmesh, math
from mathutils import Matrix, Vector

# Material slots, same order on every part.
MAT_NAMES = ["Body_Panel", "Body_Dark", "Metal", "Neon"]
PANEL, DARK, METAL, NEON = range(4)


# ---------------------------------------------------------------- materials

def make_materials():
	def principled(name, color, metallic, rough, rough_var, bump=0.0, emission=None):
		m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
		# Roblox look for the export (the baked SurfaceAppearance covers everything but Neon).
		m["rbx_material"] = "Neon" if emission is not None else ("Metal" if metallic > 0.5 else "SmoothPlastic")
		m["rbx_color"] = "%06X" % color
		m.use_nodes = True
		nt = m.node_tree
		nt.nodes.clear()
		out = nt.nodes.new("ShaderNodeOutputMaterial")
		bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
		nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
		bsdf.inputs["Metallic"].default_value = metallic
		c = [((color >> 16) & 255) / 255, ((color >> 8) & 255) / 255, (color & 255) / 255]
		c = [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c]
		if emission is not None:
			bsdf.inputs["Base Color"].default_value = (0.01, 0.01, 0.012, 1)
			bsdf.inputs["Emission Color"].default_value = (*c, 1)
			bsdf.inputs["Emission Strength"].default_value = emission
			bsdf.inputs["Roughness"].default_value = 0.3
			m.diffuse_color = (*c, 1)
			return m
		# Subtle colour and roughness breakup so surfaces don't read as flat Roblox plastic.
		tc = nt.nodes.new("ShaderNodeTexCoord")
		noise = nt.nodes.new("ShaderNodeTexNoise")
		noise.inputs["Scale"].default_value = 9.0
		noise.inputs["Detail"].default_value = 6.0
		nt.links.new(tc.outputs["Object"], noise.inputs["Vector"])
		ramp = nt.nodes.new("ShaderNodeValToRGB")
		ramp.color_ramp.elements[0].position = 0.3
		ramp.color_ramp.elements[0].color = (*[v * 0.85 for v in c], 1)
		ramp.color_ramp.elements[1].position = 0.7
		ramp.color_ramp.elements[1].color = (*[v * 1.12 for v in c], 1)
		nt.links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
		nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
		rr = nt.nodes.new("ShaderNodeMapRange")
		rr.inputs["To Min"].default_value = rough - rough_var
		rr.inputs["To Max"].default_value = rough + rough_var
		nt.links.new(noise.outputs["Fac"], rr.inputs["Value"])
		nt.links.new(rr.outputs["Result"], bsdf.inputs["Roughness"])
		if bump > 0:
			fine = nt.nodes.new("ShaderNodeTexNoise")
			fine.inputs["Scale"].default_value = 420.0
			fine.inputs["Detail"].default_value = 2.0
			nt.links.new(tc.outputs["Object"], fine.inputs["Vector"])
			bp = nt.nodes.new("ShaderNodeBump")
			bp.inputs["Strength"].default_value = bump
			bp.inputs["Distance"].default_value = 0.002
			nt.links.new(fine.outputs["Fac"], bp.inputs["Height"])
			nt.links.new(bp.outputs["Normal"], bsdf.inputs["Normal"])
		m.diffuse_color = (*c, 1)
		return m

	return [
		principled("Body_Panel", 0x3C3F46, 0.3, 0.5, 0.06),  # matte charcoal receiver / handguard
		principled("Body_Dark", 0x222327, 0.0, 0.6, 0.08, bump=0.12),  # black polymer: mag, grip, buttpad
		principled("Metal", 0x303237, 0.85, 0.34, 0.05),  # barrel, pins, moving steel
		principled("Neon", 0x1A5CFF, 0, 0, 0, emission=2.5),  # restrained blue glow
	]


# ---------------------------------------------------------------- geometry helpers

def prism(pts, axis, w0, w1, mat=PANEL):
	# Extrudes a 2D profile. axis "Y": pts are (x, z); "X": (y, z); "Z": (x, y).
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


def box(x0, x1, y0, y1, z0, z1, mat=PANEL):
	return prism([(x0, z0), (x1, z0), (x1, z1), (x0, z1)], "Y", y0, y1, mat)


def ring_pts(cx, cy, r, segs, rot=0.0):
	return [(cx + r * math.cos(rot + 2 * math.pi * i / segs), cy + r * math.sin(rot + 2 * math.pi * i / segs)) for i in range(segs)]


def cyl_x(x0, x1, r, z, segs=12, y=0.0, mat=METAL, rot=None):
	rot = math.pi / segs if rot is None else rot
	return prism(ring_pts(y, z, r, segs, rot), "X", x0, x1, mat)


def cyl_y(x, z, r, y0, y1, segs=8, mat=METAL, rot=None):
	rot = math.pi / segs if rot is None else rot
	return prism(ring_pts(x, z, r, segs, rot), "Y", y0, y1, mat)


def stadium(x0, x1, zc, h, segs=4):
	# Pill outline in XZ (slots, vents). The ends may come in either order.
	x0, x1 = min(x0, x1), max(x0, x1)
	r = h / 2
	pts = []
	for i in range(segs + 1):
		a = -math.pi / 2 + math.pi * i / segs
		pts.append((x1 - r + r * math.cos(a), zc + r * math.sin(a)))
	for i in range(segs + 1):
		a = math.pi / 2 + math.pi * i / segs
		pts.append((x0 + r + r * math.cos(a), zc + r * math.sin(a)))
	return pts


def drop(bm, axis, sign):
	# Deletes faces facing one way (caps and undersides buried inside other parts), to save triangles.
	bm.normal_update()
	bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.normal[axis] * sign > 0.99], context="FACES")
	return bm


def mirror_y(bm):
	# Adds a Y-mirrored copy of every face (for features that sit on both sides).
	tmp = bpy.data.meshes.new("_m")
	bm.to_mesh(tmp)
	other = bmesh.new()
	other.from_mesh(tmp)
	bmesh.ops.scale(other, vec=(1, -1, 1), verts=other.verts[:])
	bmesh.ops.reverse_faces(other, faces=other.faces[:])
	other.to_mesh(tmp)
	bm.from_mesh(tmp)
	other.free()
	bpy.data.meshes.remove(tmp)
	return bm


def merge(dst, src):
	tmp = bpy.data.meshes.new("_t")
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


def bevel(bm, width, segs=2, angle=30):
	bm.edges.ensure_lookup_table()
	edges = [e for e in bm.edges if e.is_manifold and e.calc_face_angle(0) > math.radians(angle)]
	if edges and width > 0:
		bmesh.ops.bevel(bm, geom=edges, offset=width, offset_type="OFFSET", segments=segs, profile=0.5, affect="EDGES", clamp_overlap=True, material=-1)  # -1: bevel faces keep the neighbouring material
	return bm


_scratch = None


def _obj(bm, name, mats):
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	for m in mats:
		me.materials.append(m)
	ob = bpy.data.objects.new(name, me)
	_scratch.objects.link(ob)
	return ob


def cut(bm, cutter, mats, cut_mat=DARK, bw=0.008, segs=2):
	# Exact boolean difference; faces left by the cutter (pocket floors, hole walls) get cut_mat.
	# The target is bevelled first (bw, segs) so the cut rims stay crisp and cheap; add the result with width 0.
	bevel(bm, bw, segs)
	for f in cutter.faces:
		f.material_index = cut_mat
	t = _obj(bm, "_target", mats)
	c = _obj(cutter, "_cutter", mats)
	c.hide_render = True
	mod = t.modifiers.new("cut", "BOOLEAN")
	mod.operation = "DIFFERENCE"
	mod.solver = "EXACT"
	mod.object = c
	mod.material_mode = "INDEX"
	mod.use_self = True  # cutters may be several overlapping pockets
	dg = bpy.context.evaluated_depsgraph_get()
	dg.update()
	out = bmesh.new()
	out.from_object(t, dg)
	for o in (t, c):
		me = o.data
		bpy.data.objects.remove(o)
		bpy.data.meshes.remove(me)
	return out


def rotate_y(bm, angle, pivot):
	bmesh.ops.rotate(bm, verts=bm.verts[:], cent=pivot, matrix=Matrix.Rotation(angle, 3, "Y"))
	return bm


def charm_loop(cx, cz, cy):
	# QD-style buddy loop on the gun's left side: a lug with a small ring hanging 0.049 below cz.
	lug = box(cx - 0.021, cx + 0.021, cy - 0.004, cy + 0.012, cz - 0.012, cz + 0.014, METAL)
	tor = bmesh.new()
	R, rr, n, m = 0.019, 0.0055, 8, 4
	cz2 = cz - 0.03
	grid = []
	for i in range(n):
		a = 2 * math.pi * i / n
		row = []
		for j in range(m):
			b = 2 * math.pi * j / m + math.pi / 4
			rad = R + rr * math.cos(b)
			row.append(tor.verts.new((cx + rad * math.cos(a), cy + 0.006 + rr * math.sin(b), cz2 + rad * math.sin(a))))
		grid.append(row)
	for i in range(n):
		for j in range(m):
			tor.faces.new((grid[i][j], grid[(i + 1) % n][j], grid[(i + 1) % n][(j + 1) % m], grid[i][(j + 1) % m]))
	bmesh.ops.recalc_face_normals(tor, faces=tor.faces[:])
	for f in tor.faces:
		f.material_index = METAL
	return lug, tor


# ---------------------------------------------------------------- parts and assembly

class Part:
	def __init__(self, name, bone="Root"):
		self.name = name
		self.bone = bone
		self.bm = bmesh.new()

	def add(self, bm, width=0.008, segs=2, angle=30):
		merge(self.bm, bevel(bm, width, segs, angle))


def begin(gun):
	# Clears the previous build of `gun` (and Blender's default cube) and opens the scratch collection.
	global _scratch
	active = getattr(bpy.context, "object", None)
	if active and active.mode != "OBJECT":
		bpy.ops.object.mode_set(mode="OBJECT")
	old = bpy.data.collections.get(gun)
	if old:
		for o in list(old.all_objects):
			data = o.data
			bpy.data.objects.remove(o)
			if data is not None and data.users == 0:
				if isinstance(data, bpy.types.Mesh):
					bpy.data.meshes.remove(data)
				elif isinstance(data, bpy.types.Armature):
					bpy.data.armatures.remove(data)
		bpy.data.collections.remove(old)
	cube = bpy.data.objects.get("Cube")
	if cube and cube.type == "MESH" and len(cube.data.vertices) == 8:
		bpy.data.objects.remove(cube)
	_scratch = bpy.data.collections.new("_scratch")
	bpy.context.scene.collection.children.link(_scratch)
	return make_materials()


AIM_ROT = Matrix(((0, 0, 1), (0, 1, 0), (-1, 0, 0))).to_4x4()
EJECT_ROT = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0))).to_4x4()


def assemble(gun, parts, mats, bones, locators, props):
	# Turns the parts into mesh objects on an armature, adds the locators and packs one shared UV atlas.
	# bones: [(name, parent, head)]; locators: [(name, bone, position, rotation matrix or None)].
	global _scratch
	scene = bpy.context.scene
	bpy.data.collections.remove(_scratch)
	_scratch = None
	pre = gun + "_"
	col = bpy.data.collections.new(gun)
	scene.collection.children.link(col)
	col["weapon_name"] = gun
	for k, v in props.items():
		col[k] = v

	arm = bpy.data.armatures.new(pre + "Rig")
	rig = bpy.data.objects.new(pre + "Rig", arm)
	col.objects.link(rig)
	arm.display_type = "STICK"
	rig.show_in_front = True
	for o in bpy.context.view_layer.objects:
		o.select_set(False)
	bpy.context.view_layer.objects.active = rig
	rig.select_set(True)
	bpy.ops.object.mode_set(mode="EDIT")
	for name, parent, head in bones:
		eb = arm.edit_bones.new(name)
		eb.head = head
		eb.tail = Vector(head) + Vector((0, 0.08, 0))
		eb.roll = 0
		if parent:
			eb.parent = arm.edit_bones[parent]
	bpy.ops.object.mode_set(mode="OBJECT")
	bpy.context.view_layer.update()

	report = {}
	for p in parts.values():
		bm = p.bm
		bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-6)
		bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="BEAUTY")
		me = bpy.data.meshes.new(pre + p.name)
		bm.to_mesh(me)
		bm.free()
		for m in mats:
			me.materials.append(m)
		me.shade_smooth()
		me.set_sharp_from_angle(angle=math.radians(38))
		ob = bpy.data.objects.new(pre + p.name, me)
		col.objects.link(ob)
		wn = ob.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
		wn.keep_sharp = True
		wn.weight = 60
		ob.parent = rig
		ob.parent_type = "BONE"
		ob.parent_bone = p.bone
		report[p.name] = len(me.polygons)
	bpy.context.view_layer.update()
	for o in col.objects:
		if o.type == "MESH":
			o.matrix_world = Matrix.Identity(4)

	for name, bone, pos, rot in locators:
		e = bpy.data.objects.new(pre + name, None)
		e.empty_display_type = "ARROWS" if rot is not None else "PLAIN_AXES"
		e.empty_display_size = 0.06
		col.objects.link(e)
		e.parent = rig
		e.parent_type = "BONE"
		e.parent_bone = bone
		bpy.context.view_layer.update()
		e.matrix_world = Matrix.Translation(pos) @ (rot if rot is not None else Matrix.Identity(4))

	# UVs: smart project, then every part packed into ONE shared atlas at an even texel density.
	meshes = [o for o in col.objects if o.type == "MESH"]
	for o in bpy.context.view_layer.objects:
		o.select_set(False)
	for o in meshes:
		o.select_set(True)
	bpy.context.view_layer.objects.active = meshes[0]
	bpy.ops.object.mode_set(mode="EDIT")
	bpy.ops.mesh.select_all(action="SELECT")
	bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.01, scale_to_bounds=False)
	bpy.ops.uv.select_all(action="SELECT")
	bpy.ops.uv.average_islands_scale()
	bpy.ops.uv.pack_islands(rotate=True, scale=True, margin_method="FRACTION", margin=0.004, shape_method="CONCAVE")
	bpy.ops.object.mode_set(mode="OBJECT")
	for o in meshes:
		o.select_set(False)
	for o in col.objects:
		if o.type in ("ARMATURE", "EMPTY"):
			o.hide_render = True

	report["_total_tris"] = sum(v for k, v in report.items())
	return report


# ---------------------------------------------------------------- preview stage (check renders)

def preview_stage(target=(0.6, 0, 0.25), center_on=None):
	# Cameras and lights matching the Vandal's check renders, in a "Preview" collection (never exported).
	# center_on: a gun collection name; the cameras then slide along X so that gun sits where the Vandal sits.
	sc = bpy.context.scene
	dx = 0.0
	if center_on and bpy.data.collections.get(center_on):
		xs = [(o.matrix_world @ Vector(c)).x for o in bpy.data.collections[center_on].all_objects if o.type == "MESH" for c in o.bound_box]
		dx = (min(xs) + max(xs)) / 2 - 0.7  # the Vandal's centre is X 0.7
	target = (target[0] + dx, target[1], target[2])
	for n in ("Light", "Camera"):
		o = bpy.data.objects.get(n)
		if o:
			bpy.data.objects.remove(o)
	pv = bpy.data.collections.get("Preview")
	if not pv:
		pv = bpy.data.collections.new("Preview")
		sc.collection.children.link(pv)
	for o in list(pv.objects):
		bpy.data.objects.remove(o)

	def look(o, t):
		o.rotation_euler = (Vector(t) - o.location).to_track_quat("-Z", "Y").to_euler()

	def cam(name, loc, t, lens=50, ortho=None):
		loc = (loc[0] + dx, loc[1], loc[2])
		t = (t[0] + dx, t[1], t[2])
		c = bpy.data.cameras.new(name)
		if ortho:
			c.type = "ORTHO"
			c.ortho_scale = ortho
		else:
			c.lens = lens
		o = bpy.data.objects.new(name, c)
		pv.objects.link(o)
		o.location = loc
		look(o, t)

	def light(name, loc, energy, color=(1, 1, 1)):
		loc = (loc[0] + dx, loc[1], loc[2])
		l = bpy.data.lights.new(name, "AREA")
		l.energy = energy
		l.size = 1.5
		l.color = color
		o = bpy.data.objects.new(name, l)
		pv.objects.link(o)
		o.location = loc
		look(o, target)

	cam("Cam_34", (3.2, 4.6, 1.9), (0.55, 0, 0.22))
	cam("Cam_Side", (0.7, 6, 0.2), (0.7, 0, 0.2), ortho=4.3)
	cam("Cam_FP", (-0.55, 0.18, 0.62), (2.5, -0.1, 0.25), lens=30)
	cam("Cam_Close", (1.6, 1.9, 0.75), (0.9, 0, 0.3))
	light("Key", (1.5, 3.5, 4), 420)
	light("Fill", (-3, 4, 0.5), 90, (0.85, 0.9, 1))
	light("Rim", (1, -4, 2.5), 420, (0.8, 0.88, 1))
	light("Under", (0.6, 2, -2.5), 40)
	w = sc.world or bpy.data.worlds.new("World")
	sc.world = w
	w.use_nodes = True
	bg = w.node_tree.nodes.get("Background")
	bg.inputs[0].default_value = (0.012, 0.014, 0.018, 1)
	sc.render.engine = "BLENDER_EEVEE"
	sc.render.resolution_x, sc.render.resolution_y = 1600, 1000
	sc.view_settings.view_transform = "AgX"
	sc.view_settings.look = "AgX - Medium High Contrast"
	sc.eevee.taa_render_samples = 48
	sc.camera = bpy.data.objects["Cam_34"]


# ---------------------------------------------------------------- animation clips (NLA tracks the exporter samples)

class Clip:
	# Keyframes one clip on the gun's rig: key(bone, frame, loc, rot_degrees). Bone-local axes are the gun's
	# +X (muzzle) / +Y (left) / +Z (up); a negative Y rotation lifts the muzzle, a positive one pulls a trigger back.
	def __init__(self, gun, name, last):
		self.gun = gun
		self.name = name
		self.last = last
		self.keys = {}  # bone -> {frame: (loc, rot_deg)}

	def key(self, bone, frame, loc=(0, 0, 0), rot=(0, 0, 0)):
		self.keys.setdefault(bone, {})[frame] = (loc, rot)

	def bake(self):
		r = bpy.data.objects[self.gun + "_Rig"]
		old = bpy.data.actions.get(self.gun + "_" + self.name)
		if old:
			bpy.data.actions.remove(old)
		act = bpy.data.actions.new(self.gun + "_" + self.name)
		ad = r.animation_data or r.animation_data_create()
		ad.action = act
		bones = r.pose.bones
		for b in bones:
			b.rotation_mode = "XYZ"
		for bone, frames in self.keys.items():
			pb = bones[bone]
			# Rest at both ends so the clip starts and ends on the rest pose.
			frames.setdefault(1, ((0, 0, 0), (0, 0, 0)))
			frames.setdefault(self.last, ((0, 0, 0), (0, 0, 0)))
			for f, (loc, rot) in sorted(frames.items()):
				pb.location = loc
				pb.rotation_euler = tuple(math.radians(a) for a in rot)
				pb.keyframe_insert("location", frame=f, group=bone)
				pb.keyframe_insert("rotation_euler", frame=f, group=bone)
		for b in bones:
			b.location = (0, 0, 0)
			b.rotation_euler = (0, 0, 0)
		ad.action = None
		track = next((t for t in ad.nla_tracks if t.name == self.name), None)
		if track:
			ad.nla_tracks.remove(track)
		track = ad.nla_tracks.new()
		track.name = self.name
		track.strips.new(self.name, 1, act)
		track.mute = True  # strips are only for the exporter; keep the rig at rest in the viewport
		return act


# ---------------------------------------------------------------- reusable clip building blocks
# Frame numbers are at 24 fps. Reload-type clips are stretched to their game time, so only proportions matter.
# Hand-follow rule (Config/Viewmodel + ViewmodelController): in a reload/draw/inspect the left hand follows the
# first part the clip moves from RELOAD_FOLLOW (Mag, Cylinder, Barrels, Pump, Bolt, ChargingHandle), then a later
# one only if their windows, each widened by 0.14 of the clip, don't overlap.

def swing(c, events, bone="Charm", tilt=0.35):
	# Buddy swings: events = [(frame, degrees)] (swing about Y, a little outward about X).
	for f, a in events:
		c.key(bone, f, rot=(a * tilt, a, 0))


def kick(c, back=0.05, climb=3.5, roll=0.4, last=12):
	# Whole-gun recoil for a Fire clip: back and muzzle up on f2-3, settle with a small overshoot.
	c.key("Root", 2, (-back * 0.8, 0, back * 0.15), (0, -climb * 0.8, roll * 0.8))
	c.key("Root", 3, (-back, 0, back * 0.2), (0, -climb, roll))
	c.key("Root", 5, (-back * 0.55, 0, back * 0.1), (0, -climb * 0.55, roll * 0.4))
	c.key("Root", 7, (-back * 0.15, 0, back * 0.02), (0, -climb * 0.15, 0))
	c.key("Root", 9, (back * 0.06, 0, 0), (0, climb * 0.06, 0))
	c.key("Root", last - 1)
	swing(c, [(3, 3 * climb), (5, -2 * climb), (7, 1.1 * climb), (9, -0.5 * climb), (last - 1, 0.15 * climb)])


def trigger_pull(c, deg=15, bone="Trigger"):
	c.key(bone, 2, rot=(0, deg, 0))
	c.key(bone, 4, rot=(0, deg, 0))
	c.key(bone, 6, rot=(0, deg * 0.25, 0))
	c.key(bone, 7)


def cycle(c, bones=("Bolt",), travel=0.13):
	# Action cycling on a shot (f2-f6).
	for b in bones:
		c.key(b, 2, (-travel * 0.85, 0, 0))
		c.key(b, 3, (-travel, 0, 0))
		c.key(b, 4, (-travel * 0.65, 0, 0))
		c.key(b, 5, (-travel * 0.2, 0, 0))
		c.key(b, 6)


def mag_swap(c, f0, drop=0.65, fwd=0.05, tilt=-10, bone="Mag", rock=0.0):
	# Detachable mag/drum: release (optionally rocking forward off the catch), drop out of view, come back up and
	# seat with a slap. Occupies f0 .. f0 + 40. Returns the frame it ends on.
	c.key(bone, f0)
	c.key(bone, f0 + 3, (0.004 + rock * 0.012, 0, -0.02), (0, tilt * 0.2 - rock * 9, 0))
	c.key(bone, f0 + 9, (fwd * 0.6, 0, -drop * 0.45), (0, tilt * 0.7 - rock * 14, 0))
	c.key(bone, f0 + 14, (fwd, 0, -drop), (0, tilt - rock * 18, 0))
	c.key(bone, f0 + 22, (fwd * 0.8, 0, -drop * 1.08), (0, tilt * 0.85 - rock * 14, 0))
	c.key(bone, f0 + 29, (fwd * 0.4, 0, -drop * 0.37), (0, tilt * 0.5 - rock * 9, 0))
	c.key(bone, f0 + 34, (0.006, 0, -0.035), (0, tilt * 0.15 - rock * 6, 0))
	c.key(bone, f0 + 37, (0, 0, 0.007), (0, 0.6, 0))  # slapped home
	c.key(bone, f0 + 40)
	return f0 + 40


def reload_root(c, f0, roll=10, pitch=-5, yaw=2.5, lift=0.018):
	# Whole-gun motion around a mag swap that starts at f0: roll the feed side toward the player, lift the muzzle,
	# jolt when the mag is slapped home (f0 + 37).
	c.key("Root", f0 - 1, (0, 0, lift * 0.55), (roll * 0.8, pitch * 0.8, yaw * 0.8))
	c.key("Root", f0 + 11, (0, 0, lift), (roll, pitch, yaw))
	c.key("Root", f0 + 33, (0, 0, lift * 0.8), (roll * 0.95, pitch, yaw * 0.8))
	c.key("Root", f0 + 37, (0, 0, lift * 1.6), (roll * 1.2, pitch * 1.4, yaw))
	c.key("Root", f0 + 40, (0, 0, lift * 0.65), (roll * 0.9, pitch * 0.9, yaw * 0.8))
	swing(c, [(f0 + 3, 5), (f0 + 7, -4), (f0 + 12, 2.5), (f0 + 17, -1), (f0 + 37, 8), (f0 + 41, -5), (f0 + 45, 2.5), (f0 + 49, -1)])


def rack(c, f0, travel=0.2, bone="ChargingHandle", jolt=1.0):
	# Pull the charging handle (f0 .. f0 + 4), hold, release so it slams home (f0 + 8) with a small bounce,
	# turning the left side toward the player. Occupies about f0 - 10 .. f0 + 13.
	c.key(bone, f0)
	c.key(bone, f0 + 4, (-travel, 0, 0))
	c.key(bone, f0 + 6, (-travel, 0, 0))
	c.key(bone, f0 + 8)
	c.key(bone, f0 + 9, (-travel * 0.03, 0, 0))
	c.key(bone, f0 + 10)
	c.key("Root", f0 - 10, (0, 0, 0.01), (4, -3, -2))
	c.key("Root", f0, (0, 0, 0.008), (3, -3, -3))
	c.key("Root", f0 + 4, (-0.02 * jolt, 0, 0.01), (4.5, -4, -3.5))
	c.key("Root", f0 + 8, (0.015 * jolt, 0, 0.004), (2, -1, -2))
	c.key("Root", f0 + 13, (0, 0, 0), (0.4, 0, -0.3))
	swing(c, [(f0 + 5, -6), (f0 + 9, 9 * jolt), (f0 + 12, -4.5), (f0 + 15, 2)])


def draw_rack(c, travel=0.2, bone="ChargingHandle", selector="FireSelector", jolt=1.0):
	# First draw (31 frames, stretched to firstEquipTime): selector off safe (if any), rack (pulled 36-48%).
	if selector:
		c.key(selector, 3)
		c.key(selector, 6, rot=(0, 14, 0))
		c.key(selector, 7, rot=(0, 12, 0))
		c.key(selector, 9)
	c.key("Root", 8, (0, 0, 0), (6, 0, -5))
	c.key("Root", 12, (0, 0, 0.005), (9, -1, -7))
	c.key("Root", 15, (-0.03 * jolt, 0, 0.008), (10, -2, -8))
	c.key("Root", 17, (0.02 * jolt, 0, 0.004), (6, 1.5, -5))
	c.key("Root", 19, (0, 0, 0.002), (4, -0.5, -3.5))
	c.key("Root", 25, (0, 0, 0), (0.8, 0, -0.6))
	c.key(bone, 12)
	c.key(bone, 15, (-travel, 0, 0))
	c.key(bone, 16, (-travel, 0, 0))
	c.key(bone, 17)
	c.key(bone, 18, (-travel * 0.04, 0, 0))
	c.key(bone, 19)
	swing(c, [(5, -5), (9, 4), (13, -3), (16, 8 * jolt), (19, -6), (22, 3.5), (26, -1.2)])


def inspect_tap_check(c, mag="Mag", check="ChargingHandle", check_travel=0.085):
	# Inspect (67 frames, alongside the viewmodel's 2.8 s track: right side 16-42%, left side 60-82%): a tap on the
	# mag, then a press check (the charging handle / bolt half back).
	if mag:
		c.key(mag, 13)
		c.key(mag, 15, (0, 0, -0.025), (0, -2, 0))
		c.key(mag, 16, (0, 0, 0.004), (0, 0.4, 0))
		c.key(mag, 18)
		c.key("Root", 15, (0, 0, 0.004), (0.6, 0, 0))
		c.key("Root", 17)
	if check:
		c.key(check, 42)
		c.key(check, 45, (-check_travel, 0, 0))
		c.key(check, 50, (-check_travel, 0, 0))
		c.key(check, 52)
		c.key(check, 53, (-check_travel * 0.06, 0, 0))
		c.key(check, 54)
		c.key("Root", 52, (0.006, 0, 0), (0, 0.4, 0))
		c.key("Root", 54)
	swing(c, [(6, 9), (11, -7), (16, 6), (21, -3), (28, 2), (36, -9), (41, 11), (46, -6), (52, 5), (57, -3), (62, 1.5)])
