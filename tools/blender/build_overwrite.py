# build_overwrite.py: builds the redesigned Overwrite rifle (Vandal-style, 2026-10 concept) in the open
# Blender scene. Re-running it replaces the gun, so tweak numbers here rather than by hand.
#
#   Run inside Blender (Text Editor, or the Blender MCP):
#     exec(compile(open(path).read(), path, "exec"), {"__name__": "__main__"})
#
# Axes match the export pipeline (tools/blender/export_weapons.py): +X muzzle, +Z up, +Y gun-left (the side
# the player sees in first person), 1 unit = 1 stud, origin at the pistol grip. Shapes are traced from the
# concept's side view (vault/02 Art/References/overwrite-concept.webp) in image pixels: P(px, py) converts.

import bpy, bmesh, math
from mathutils import Matrix, Vector

GUN = "Overwrite"
PRE = GUN + "_"

# Concept side view -> studs. Muzzle tip (px 94) to buttpad (px 1352) = 3.9 studs; grip centre at (948, 900).
S = 0.0031
OX, OY = 948, 900


def X(px):
	return (OX - px) * S


def Z(py):
	return (OY - py) * S


def P(pts):
	return [(X(a), Z(b)) for a, b in pts]


BORE_Z = Z(808)
SIGHT_Z = 0.515

# Material slots, same order on every part. Names are the export pipeline's slot names.
MAT_NAMES = ["Body_Panel", "Body_Dark", "Metal", "Neon"]
PANEL, DARK, METAL, NEON = range(4)


# ---------------------------------------------------------------- materials

def make_materials():
	def principled(name, color, metallic, rough, rough_var, bump=0.0, emission=None):
		m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
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


def cyl_x(x0, x1, r, segs=12, y=0.0, z=None, mat=METAL, rot=None):
	z = BORE_Z if z is None else z
	rot = math.pi / segs if rot is None else rot
	return prism(ring_pts(y, z, r, segs, rot), "X", x0, x1, mat)


def cyl_y(x, z, r, y0, y1, segs=8, mat=METAL, rot=None):
	rot = math.pi / segs if rot is None else rot
	return prism(ring_pts(x, z, r, segs, rot), "Y", y0, y1, mat)


def stadium(x0, x1, zc, h, segs=4):
	# Pill outline in XZ (slots, vents).
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
		bmesh.ops.bevel(bm, geom=edges, offset=width, offset_type="OFFSET", segments=segs, profile=0.5, affect="EDGES", clamp_overlap=True)
	return bm


SCRATCH = None


def _obj(bm, name, mats):
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	for m in mats:
		me.materials.append(m)
	ob = bpy.data.objects.new(name, me)
	SCRATCH.objects.link(ob)
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


# ---------------------------------------------------------------- parts

class Part:
	def __init__(self, name, bone="Root"):
		self.name = name
		self.bone = bone
		self.bm = bmesh.new()

	def add(self, bm, width=0.008, segs=2, angle=30):
		merge(self.bm, bevel(bm, width, segs, angle))


def build_parts(mats):
	parts = {}

	def part(name, bone="Root"):
		parts[name] = Part(name, bone)
		return parts[name]

	hw = 0.072  # receiver half width

	# ---- Receiver (charcoal): lower receiver, dust cover, front trunnion block, rear block, stock adapter
	rec = part("Receiver")
	lower = box(X(977), X(687), -hw, hw, Z(847), Z(788))
	port = box(X(838), X(745), -hw - 0.02, -hw + 0.03, Z(806) - 0.012, Z(788) + 0.004)  # ejection port (right side)
	ch_slot = box(X(790), X(696), hw - 0.012, hw + 0.02, Z(809), Z(794))  # charging handle track (left side)
	rec.add(cut(lower, group(port, ch_slot), mats), 0)

	dust = prism(P([(688, 775), (701, 762), (880, 762), (880, 790), (688, 790)]), "Y", -0.068, 0.068)
	neon_pocket = mirror_y(box(X(739), X(701), 0.068 - 0.006, 0.09, Z(783.5), Z(777)))
	rec.add(cut(dust, neon_pocket, mats), 0)
	rec.add(prism(P([(880, 767), (961, 767), (973, 778), (973, 790), (880, 790)]), "Y", -0.07, 0.07), 0.008, 1)
	rec.add(prism(P([(600, 775), (676, 775), (688, 789), (688, 847), (606, 847), (600, 841)]), "Y", -0.08, 0.08), 0.01)
	rec.add(box(X(633), X(605), -0.06, 0.06, Z(775) - 0.004, Z(752)), 0.006, 1)  # rail clamp
	rec.add(box(X(797), X(717), -0.062, 0.062, Z(858), Z(845)), 0.006, 1)  # magwell lip
	rec.add(prism(P([(781, 847), (794, 831), (843, 831), (855, 847)]), "Y", -0.079, 0.079), 0.005, 1)  # trigger housing plate
	rec.add(prism(P([(977, 777), (999, 777), (1005, 784), (1005, 847), (977, 847)]), "Y", -0.082, 0.082), 0.008, 1)  # stock adapter
	rec.add(box(X(1003), X(983), -0.088, 0.088, Z(838), Z(788)), 0.005, 1)  # adapter hinge plate
	parts["Receiver"].add(box(X(808), X(797), -0.02, 0.02, Z(868), Z(846), DARK), 0.004, 1)  # mag release paddle

	# ---- Handguard (charcoal, M-LOK style slots on both sides)
	hg = part("Handguard")
	gw, top, bot = 0.075, Z(767), Z(845)
	sect = [(-gw + 0.02, top), (gw - 0.02, top), (gw, top - 0.02), (gw, bot + 0.034), (gw - 0.034, bot), (-gw + 0.034, bot), (-gw, bot + 0.034), (-gw, top - 0.02)]
	body = prism(sect, "X", X(610), X(447))
	slots = bmesh.new()
	for x0, x1 in ((530, 481), (592, 547)):
		for zc in (Z(787), Z(819.5)):
			merge(slots, prism(stadium(X(x1), X(x0), zc, 0.03, 3), "Y", gw - 0.022, gw + 0.03))
	mirror_y(slots)
	hg.add(cut(body, slots, mats, bw=0.01), 0)
	cap = [(y * 0.9, z) for y, z in sect]
	cap = [(y, min(max(z, bot + 0.008), top - 0.008)) for y, z in cap]
	hg.add(prism(cap, "X", X(447), X(422)), 0.008, 1)
	hg.add(cyl_x(X(422), X(405), 0.052, 12), 0.004, 1)  # barrel nut

	# ---- Rail (black): base, teeth, front stop
	rail = part("Rail")
	rail.add(box(X(880), X(432), -0.04, 0.04, Z(763), Z(752), DARK), 0.003, 1)
	rail.add(drop(box(X(880), X(432), -0.033, 0.033, Z(768), Z(763) + 0.001, DARK), 2, 1), 0)  # foot, buried in the receiver
	teeth = bmesh.new()
	x = X(880) + 0.012
	while x + 0.026 < X(436):
		merge(teeth, drop(box(x, x + 0.026, -0.04, 0.04, Z(752) - 0.001, Z(745), DARK), 2, -1))
		x += 0.054
	rail.add(teeth, 0)
	rail.add(box(X(480), X(452), -0.046, 0.046, Z(767) - 0.004, Z(749), DARK), 0.005)  # front stop

	# ---- Rear sight (black): base block and flip-up aperture
	rs = part("RearSight")
	rs.add(prism(P([(880, 767), (880, 750), (887, 743), (946, 743), (953, 750), (953, 767)]), "Y", -0.05, 0.05, DARK), 0.006, 1)
	tower = prism([(X(940), Z(745)), (X(940), Z(728)), (X(934), Z(722)), (X(913), Z(722)), (X(907), Z(728)), (X(907), Z(745))], "Y", -0.034, 0.034, DARK)
	rs.add(cut(tower, cyl_x(X(945), X(902), 0.016, 10, z=SIGHT_Z), mats, bw=0.004, segs=1), 0)
	rs.add(cyl_y(X(918), Z(758), 0.011, 0.05, 0.058, 6, METAL), 0)
	rs.add(cyl_y(X(934), Z(758), 0.011, 0.05, 0.058, 6, METAL), 0)

	# ---- Barrel group (metal): barrel, gas tube, muzzle brake + collar
	bar = part("Barrel")
	bar.add(drop(drop(cyl_x(X(612), X(178), 0.036, 16), 0, 1), 0, -1), 0)
	bar.add(drop(drop(cyl_x(X(430), X(318), 0.026, 10, z=Z(788)), 0, 1), 0, -1), 0)
	collar = cyl_x(X(179), X(153), 0.058, 8, rot=math.pi / 8)
	bar.add(collar, 0.008, 1)
	brake = cyl_x(X(153), X(94), 0.054, 8, rot=math.pi / 8)
	vents = group(
		prism(stadium(X(142), X(105), Z(797), 0.018, 3), "Y", -0.08, 0.08),
		prism(stadium(X(142), X(105), Z(812), 0.026, 3), "Y", -0.08, 0.08),
		cyl_x(X(97), X(90), 0.024, 12),
	)
	bar.add(cut(brake, vents, mats, bw=0.007, segs=1), 0)

	# ---- Gas block and front sight (charcoal)
	fs = part("FrontSight")
	fs.add(prism(P([(272, 789), (283, 775), (319, 775), (319, 837), (283, 837), (272, 826)]), "Y", -0.05, 0.05), 0.007, 1)
	ears = group(
		prism(P([(287, 745), (297, 732), (319, 732), (319, 776), (287, 776)]), "Y", 0.028, 0.048),
		prism(P([(287, 745), (297, 732), (319, 732), (319, 776), (287, 776)]), "Y", -0.048, -0.028),
	)
	fs.add(cut(ears, cyl_y(X(303), Z(753), 0.019, -0.06, 0.06, 8), mats, bw=0.004, segs=1), 0)
	fs.add(box(X(306), X(300), -0.0065, 0.0065, Z(776), SIGHT_Z, METAL), 0.002, 1)  # front post
	fs.add(cyl_y(X(304), Z(815), 0.012, 0.05, 0.058, 6, METAL), 0.002, 1)

	# ---- Grip and trigger guard (black polymer)
	grip = part("Grip")
	grip.add(prism(P([(903, 846), (977, 846), (975, 872), (990, 888), (1008, 990), (1001, 997), (946, 999), (940, 987), (928, 972), (932, 959), (922, 946), (928, 932), (916, 918)]), "Y", -0.052, 0.052, DARK), 0.012, 1)
	guard = group(
		prism(P([(818, 885), (903, 885), (903, 897), (829, 897), (818, 891)]), "Y", -0.028, 0.028, DARK),
		prism(P([(809, 846), (833, 846), (833, 887), (818, 891), (809, 873)]), "Y", -0.028, 0.028, DARK),
	)
	grip.add(guard, 0.005)

	# ---- Stock (charcoal body, black buttpad)
	st = part("Stock")
	st.add(box(X(1080), X(1003), -0.043, 0.043, Z(833), Z(778)), 0.014, 1)  # buffer tube
	st.add(prism(P([(1058, 772), (1068, 765), (1290, 765), (1302, 772), (1302, 836), (1098, 838)]), "Y", -0.058, 0.058), 0.011)
	st.add(prism(P([(1186, 834), (1228, 834), (1294, 916), (1294, 948), (1276, 948)]), "Y", -0.046, 0.046), 0.009, 1)
	st.add(prism(P([(1276, 834), (1305, 834), (1305, 951), (1276, 951)]), "Y", -0.05, 0.05), 0.008, 1)
	st.add(box(X(1198), X(1138), -0.034, 0.034, Z(857), Z(836), DARK), 0.005, 1)
	st.add(prism(P([(1303, 773), (1310, 766), (1345, 766), (1352, 775), (1352, 948), (1345, 957), (1310, 957), (1303, 950)]), "Y", -0.068, 0.068, DARK), 0.01, 1)

	# ---- Pins and bolts (metal, both sides unless noted)
	pins = part("Pins")
	for px, py, r, segs in ((740, 823, 0.012, 6), (857, 830, 0.011, 6), (963, 797, 0.013, 6), (963, 833, 0.013, 6), (620, 766, 0.012, 6), (811, 840, 0.008, 6)):
		yb = 0.06 if px == 620 else (0.079 if px == 811 else hw)
		pins.add(mirror_y(drop(cyl_y(X(px), Z(py), r, yb - 0.002, yb + 0.008, segs), 1, -1)), 0)
	pins.add(cyl_y(X(466), Z(758), 0.01, 0.046, 0.053, 6), 0)

	# ---- Neon (restrained: dust cover bars both sides, one dash by the selector)
	neon = part("Neon")
	neon.add(mirror_y(box(X(737), X(703), 0.068 - 0.006, 0.068 - 0.0015, Z(782.5), Z(778), NEON)), 0)
	neon.add(box(X(920), X(903), hw - 0.002, hw + 0.0025, Z(838.5), Z(834.5), NEON), 0)

	# ---- Charm (buddy) mount: QD-style loop on the left side of the front block
	charm = part("CharmLoop")
	cx, cz, cy = X(654), Z(813), 0.08
	charm.add(box(cx - 0.021, cx + 0.021, cy - 0.004, cy + 0.012, cz - 0.012, cz + 0.014, METAL), 0.004, 1)  # lug
	# Torus-ish loop: sweep a small square section around a circle hanging below the boss.
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
	charm.add(tor, 0)

	# ---- Moving parts
	mag = part("Mag", "Mag")
	# Long AK-style banana mag; its bottom hangs below the grip like the concept.
	mag_back = [(797, 858), (791, 887), (778, 920), (760, 955), (739, 990), (718, 1022)]
	mag_front = [(720, 853), (713, 876), (700, 908), (681, 944), (657, 980), (630, 1012)]
	mag_pts = P([(722, 845), (797, 845)] + mag_back + mag_front[::-1])
	mbody = prism(mag_pts, "Y", -0.047, 0.047, DARK)
	windows = bmesh.new()
	def back_x(py):
		for (ax, ay), (bx, by) in zip(mag_back, mag_back[1:]):
			if ay <= py <= by:
				return ax + (bx - ax) * (py - ay) / (by - ay)
		return mag_back[-1][0]

	centres = [(back_x(py) - 18, py) for py in range(892, 1006, 14)]
	for i, (px, py) in enumerate(centres):
		a = centres[max(i - 1, 0)]
		b = centres[min(i + 1, len(centres) - 1)]
		ang = math.atan2(Z(b[1]) - Z(a[1]), X(b[0]) - X(a[0])) + math.pi / 2
		w = box(X(px) - 0.014, X(px) + 0.014, 0.047 - 0.005, 0.07, Z(py) - 0.0145, Z(py) + 0.0145)
		rotate_y(w, -ang, (X(px), 0, Z(py)))
		merge(windows, w)
	mirror_y(windows)
	mag.add(cut(mbody, windows, mats, DARK, bw=0.008), 0)
	mag.add(prism(P([(626, 1007), (722, 1016), (720, 1030), (624, 1021)]), "Y", -0.054, 0.054, DARK), 0.006)  # base plate
	mag.add(mirror_y(prism(P([(725, 858), (733, 858), (728, 879), (720, 879)]), "Y", 0.047 - 0.003, 0.0485, NEON)), 0)

	chh = part("ChargingHandle", "ChargingHandle")
	chh.add(box(X(772), X(700), hw - 0.01, hw + 0.012, Z(808), Z(795), METAL), 0.003, 1)
	chh.add(prism(P([(758, 792), (772, 792), (772, 811), (758, 811)]), "Y", hw + 0.01, hw + 0.032, METAL), 0.004, 1)

	bolt = part("Bolt", "Bolt")
	bolt.add(box(X(834), X(749), -hw + 0.004, -hw + 0.024, Z(805), Z(791), METAL), 0.002, 1)

	trig = part("Trigger", "Trigger")
	trig.add(prism(P([(872, 846), (887, 846), (889, 858), (886, 871), (880, 882), (872, 884), (875, 872), (877, 860)]), "Y", -0.011, 0.011, METAL), 0.003, 1)

	sel = part("FireSelector", "FireSelector")
	pv = Vector((X(922), Z(808)))
	tip = Vector((X(941), Z(838)))
	d = (tip - pv).normalized()
	nrm = Vector((-d.y, d.x))
	pts = []
	for i in range(5):
		a = math.atan2(nrm.y, nrm.x) + math.pi * i / 4
		pts.append(tuple(pv + Vector((math.cos(a), math.sin(a))) * 0.019))
	pts += [tuple(tip - nrm * 0.011), tuple(tip + d * 0.004), tuple(tip + nrm * 0.011)]
	sel.add(prism(pts, "Y", hw + 0.002, hw + 0.012, METAL), 0.003, 1)
	sel.add(drop(cyl_y(pv.x, pv.y, 0.011, hw + 0.01, hw + 0.016, 6, METAL), 1, -1), 0)

	return parts


# ---------------------------------------------------------------- rig and locators

BONES = [
	# name, parent, head
	("Root", None, (0.0, 0.0, 0.15)),
	("Mag", "Root", (X(760), 0.0, Z(850))),
	("ChargingHandle", "Root", (X(736), 0.08, Z(801))),
	("Bolt", "Root", (X(790), -0.06, Z(798))),
	("Trigger", "Root", (X(880), 0.0, Z(848))),
	("FireSelector", "Root", (X(922), 0.08, Z(808))),
	("Flash", "Root", (X(94) + 0.01, 0.0, BORE_Z)),
	("Charm", "Root", (X(654), 0.092, Z(813) - 0.049)),
]

AIM_ROT = Matrix(((0, 0, 1), (0, 1, 0), (-1, 0, 0))).to_4x4()
EJECT_ROT = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0))).to_4x4()
LOCATORS = [
	# name, bone, position, rotation
	("Muzzle", "Root", (X(94), 0.0, BORE_Z), None),
	("RightGrip", "Root", (0.0, 0.0, 0.0), None),
	("LeftGrip", "Root", (X(520), 0.0, Z(845)), None),
	("AimPoint", "Root", (X(923), 0.0, SIGHT_Z), AIM_ROT),
	("Eject", "Root", (X(792), -0.072, Z(798)), EJECT_ROT),
	("CharmPoint", "Charm", (X(654), 0.092, Z(813) - 0.049), None),
]


def build():
	global SCRATCH
	scene = bpy.context.scene
	if bpy.context.object and bpy.context.object.mode != "OBJECT":
		bpy.ops.object.mode_set(mode="OBJECT")

	# Clear the previous build (and Blender's default cube).
	old = bpy.data.collections.get(GUN)
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

	col = bpy.data.collections.new(GUN)
	scene.collection.children.link(col)
	col["weapon_name"] = GUN
	col["class"] = "Assault rifle"
	col["tier"] = "T3"
	col["template_version"] = 2
	col["length_rel"] = 1.0
	col["att_positions"] = "{}"

	SCRATCH = bpy.data.collections.new("_scratch")
	scene.collection.children.link(SCRATCH)

	mats = make_materials()
	parts = build_parts(mats)
	bpy.data.collections.remove(SCRATCH)

	# Armature
	arm = bpy.data.armatures.new(PRE + "Rig")
	rig = bpy.data.objects.new(PRE + "Rig", arm)
	col.objects.link(rig)
	arm.display_type = "STICK"
	rig.show_in_front = True
	for o in bpy.context.view_layer.objects:
		o.select_set(False)
	bpy.context.view_layer.objects.active = rig
	rig.select_set(True)
	bpy.ops.object.mode_set(mode="EDIT")
	for name, parent, head in BONES:
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
		me = bpy.data.meshes.new(PRE + p.name)
		bm.to_mesh(me)
		bm.free()
		for m in mats:
			me.materials.append(m)
		me.shade_smooth()
		me.set_sharp_from_angle(angle=math.radians(38))
		ob = bpy.data.objects.new(PRE + p.name, me)
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

	for name, bone, pos, rot in LOCATORS:
		e = bpy.data.objects.new(PRE + name, None)
		e.empty_display_type = "ARROWS" if rot is not None else "PLAIN_AXES"
		e.empty_display_size = 0.06
		col.objects.link(e)
		e.parent = rig
		e.parent_type = "BONE"
		e.parent_bone = bone
		bpy.context.view_layer.update()
		e.matrix_world = Matrix.Translation(pos) @ (rot if rot is not None else Matrix.Identity(4))

	# UVs (smart project) so PBR maps can be baked onto the parts later.
	meshes = [o for o in col.objects if o.type == "MESH"]
	for o in bpy.context.view_layer.objects:
		o.select_set(False)
	for o in meshes:
		o.select_set(True)
	bpy.context.view_layer.objects.active = meshes[0]
	bpy.ops.object.mode_set(mode="EDIT")
	bpy.ops.mesh.select_all(action="SELECT")
	bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.01, scale_to_bounds=False)
	bpy.ops.object.mode_set(mode="OBJECT")
	for o in meshes:
		o.select_set(False)

	report["_total_tris"] = sum(v for k, v in report.items())
	return report


if __name__ == "__main__":
	result = build()
	print(result)
