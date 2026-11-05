# build_lobby_kit_stylized.py: the stylized Lobby kit (rebuild 2026-11-04).
#
#   blender --background --factory-startup --python tools/blender/build_lobby_kit_stylized.py [-- --render]
#
# Writes art-source/lobby/Kit_Stylized.blend with one Lobby_<Piece> collection per piece, built at the origin
# (bottom centre unless noted), front facing Blender -Y (= Roblox +Z after the importer). Style: low poly with soft
# rounded bevels, flat SmoothPlastic colours (tinted per zone in Studio), Neon only on thin "_Glow" accents.
# Signs are real 3D letters (Luckiest Guy, Apache 2.0, ships with Roblox Studio) with a white face and a navy
# extrusion, on a chunky rounded panel. Layout and numbers: vault/02 Art/Lobby Rebuild 2026-11-04.md.
# No two surfaces of a piece share a plane facing the same way (checked by audit_lobby_coplanar.py).
# Next: export_lobby_kit.py -- Stylized, upload_models.py --lobby Stylized, kit_bundle.py Stylized.

import bpy, bmesh, glob, math, os, random, sys
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
	sys.path.insert(0, HERE)
from lobbykit import collection, add_obj, _flat, _emissive, ROOT  # noqa: E402
from gunkit import bevel  # noqa: E402

BLEND = os.path.join(ROOT, "art-source", "lobby", "Kit_Stylized.blend")
RENDER_DIR = os.path.join(ROOT, "vault", "02 Art", "References", "lobby", "rebuild-20261104")

# Palette (sRGB hex). Bright and saturated, one accent per zone; tinted per instance in Studio.
CREAM, CREAM2, NAVY, NAVY2 = 0xF3EEE4, 0xE4DCCD, 0x2C3558, 0x3B4675
WOOD, LEAF, TRUNK, SOIL = 0xD08F55, 0x6FCB55, 0x8B5B3A, 0x6B4A35
CORAL, SUN, BLUE, MINT, VIOLET, RED, WHITE = 0xFF6A4D, 0xFFC83D, 0x3FA9FF, 0x2FD6A0, 0x8E5CFF, 0xFF4757, 0xFFFFFF
SCREEN, GLASS = 0x1B2340, 0x7FD8FF


def font_path():
	hits = sorted(glob.glob(os.path.join(os.environ.get("LOCALAPPDATA", ""), "Roblox", "Versions", "*", "content", "fonts", "LuckiestGuy-Regular.ttf")))
	return hits[-1] if hits else "C:/Windows/Fonts/seguibl.ttf"


# ---------------------------------------------------------------- materials

M = {}


def materials():
	flat = {
		"Cream": CREAM, "Cream2": CREAM2, "Navy": NAVY, "Navy2": NAVY2, "Wood": WOOD, "Leaf": LEAF, "Trunk": TRUNK,
		"Soil": SOIL, "Coral": CORAL, "Sun": SUN, "Blue": BLUE, "Mint": MINT, "Violet": VIOLET, "Red": RED,
		"White": WHITE, "Screen": SCREEN,
	}
	for k, c in flat.items():
		M[k] = _flat("S_" + k, c, 0.45)
	M["Glass"] = _flat("S_Glass", GLASS, 0.1, rbx="Glass", rbx_transparency=0.35)
	for k, c in {"GlowWhite": 0xFFF6E0, "GlowSun": SUN, "GlowBlue": 0x5CE1FF, "GlowCoral": CORAL}.items():
		M[k] = _emissive("S_" + k, c, 6.0)


# ---------------------------------------------------------------- geometry helpers

def _fix(bm):
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	return bm


def prism(pts, axis, a0, a1, mat=0):
	# Extrudes a simple polygon (CCW) along an axis. "Y": pts are (x, z); "Z": (x, y); "X": (y, z).
	bm = bmesh.new()

	def co(p, w):
		if axis == "Y":
			return (p[0], w, p[1])
		if axis == "X":
			return (w, p[0], p[1])
		return (p[0], p[1], w)

	r0 = [bm.verts.new(co(p, a0)) for p in pts]
	r1 = [bm.verts.new(co(p, a1)) for p in pts]
	bm.faces.new(r0)
	bm.faces.new(r1[::-1])
	n = len(pts)
	for i in range(n):
		j = (i + 1) % n
		bm.faces.new((r0[i], r1[i], r1[j], r0[j]))
	for f in bm.faces:
		f.material_index = mat
	return _fix(bm)


def finish(bm, r, segs=3):
	# Round every hard edge, then triangulate the remaining n-gons (concave outlines stay correct).
	if r > 0:
		bevel(bm, r, segs=segs, angle=30)
	ngons = [f for f in bm.faces if len(f.verts) > 4]
	if ngons:
		bmesh.ops.triangulate(bm, faces=ngons, quad_method="BEAUTY", ngon_method="BEAUTY")
	return _fix(bm)


def rbox(x0, x1, y0, y1, z0, z1, r=0.4, segs=3, mat=0):
	r = min(r, (x1 - x0) * 0.45, (y1 - y0) * 0.45, (z1 - z0) * 0.45)
	return finish(prism([(x0, z0), (x1, z0), (x1, z1), (x0, z1)], "Y", y0, y1, mat), r, segs)


def circle(r, n, cx=0.0, cy=0.0, rot=0.0):
	return [(cx + r * math.cos(rot + 2 * math.pi * i / n), cy + r * math.sin(rot + 2 * math.pi * i / n)) for i in range(n)]


def rcyl(r, z0, z1, n=48, bev=0.3, segs=3, cx=0.0, cy=0.0, mat=0):
	return finish(prism(circle(r, n, cx, cy), "Z", z0, z1, mat), min(bev, (z1 - z0) * 0.45), segs)


def annulus(r0, r1, z0, z1, a0=0.0, a1=360.0, n=None, bev=0.08, mat=0):
	# Flat ring (or ring segment between angles a0..a1, degrees CCW from +X) with a small bevel.
	n = n or max(3, int(abs(a1 - a0) / 6))
	outer = [(r1 * math.cos(math.radians(a0 + (a1 - a0) * i / n)), r1 * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]
	inner = [(r0 * math.cos(math.radians(a0 + (a1 - a0) * i / n)), r0 * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]
	bm = bmesh.new()
	full = abs(abs(a1 - a0) - 360) < 1e-6
	if full:
		outer, inner = outer[:-1], inner[:-1]
	m = len(outer)
	ob = [bm.verts.new((x, y, z0)) for x, y in outer]
	ot = [bm.verts.new((x, y, z1)) for x, y in outer]
	ib = [bm.verts.new((x, y, z0)) for x, y in inner]
	it = [bm.verts.new((x, y, z1)) for x, y in inner]
	rng = range(m) if full else range(m - 1)
	for i in rng:
		j = (i + 1) % m
		bm.faces.new((ot[i], ot[j], it[j], it[i]))
		bm.faces.new((ob[i], ib[i], ib[j], ob[j]))
		bm.faces.new((ob[i], ob[j], ot[j], ot[i]))
		bm.faces.new((ib[i], it[i], it[j], ib[j]))
	if not full:
		bm.faces.new((ob[0], ot[0], it[0], ib[0]))
		bm.faces.new((ob[-1], ib[-1], it[-1], ot[-1]))
	for f in bm.faces:
		f.material_index = mat
	return finish(_fix(bm), bev, 2)


def rrect(w, h, r, n=4, cx=0.0, cz=0.0):
	# Rounded rectangle outline, CCW, centred.
	pts = []
	for k, (sx, sz) in enumerate(((1, -1), (1, 1), (-1, 1), (-1, -1))):
		ccx, ccz = cx + sx * (w / 2 - r), cz + sz * (h / 2 - r)
		a0 = -90 + 90 * k
		for i in range(n + 1):
			a = math.radians(a0 + 90 * i / n)
			pts.append((ccx + r * math.cos(a), ccz + r * math.sin(a)))
	return pts


def u_frame(w_in, h_in, t, r_in, r_out, n=6):
	# Arch outline (U, open at the bottom), CCW in (x, z): outer path up and over, inner path back.
	W, H = w_in / 2, h_in
	pts = [(-W - t, 0.0), (-W, 0.0)]
	for i in range(n + 1):  # inner left corner -> inner right corner (goes over the top, CW in x,z order)
		a = math.radians(180 - 90 * i / n)
		pts.append((-W + r_in + r_in * math.cos(a), H - r_in + r_in * math.sin(a)))
	for i in range(n + 1):
		a = math.radians(90 - 90 * i / n)
		pts.append((W - r_in + r_in * math.cos(a), H - r_in + r_in * math.sin(a)))
	pts += [(W, 0.0), (W + t, 0.0)]
	for i in range(n + 1):
		a = math.radians(0 + 90 * i / n)
		pts.append((W + t - r_out + r_out * math.cos(a), H + t - r_out + r_out * math.sin(a)))
	for i in range(n + 1):
		a = math.radians(90 + 90 * i / n)
		pts.append((-W - t + r_out + r_out * math.cos(a), H + t - r_out + r_out * math.sin(a)))
	return pts[::-1]  # make it CCW


def star(r_out, r_in, n=5):
	return [((r_out if i % 2 == 0 else r_in) * math.cos(math.pi / 2 + math.pi * i / n), (r_out if i % 2 == 0 else r_in) * math.sin(math.pi / 2 + math.pi * i / n)) for i in range(2 * n)][::-1]


def xform(bm, m):
	bmesh.ops.transform(bm, matrix=m, verts=bm.verts[:])
	return _fix(bm)


def T(x=0.0, y=0.0, z=0.0):
	return Matrix.Translation((x, y, z))


def RX(deg):
	return Matrix.Rotation(math.radians(deg), 4, "X")


def RZ(deg):
	return Matrix.Rotation(math.radians(deg), 4, "Z")


def merge(*bms):
	out = bmesh.new()
	for b in bms:
		tmp = bpy.data.meshes.new("_m")
		b.to_mesh(tmp)
		out.from_mesh(tmp)
		bpy.data.meshes.remove(tmp)
		b.free()
	return out


# ---------------------------------------------------------------- pieces

PIECES = {}


def piece(name, **props):
	col = collection("Lobby_" + name, KIT)
	for k, v in props.items():
		col[k] = v
	PIECES[name] = col
	return col


def obj(col, part, bm, mat, smooth=40):
	name = col.name[6:] + "_" + part
	if mat.startswith("Glow"):
		name = name if name.endswith("_Glow") else name + "_Glow"
		ob = add_obj(name, bm, [M[mat]], col, smooth_angle=0)
		ob["glow"] = True
		ob.visible_shadow = False
		return ob
	return add_obj(name, bm, [M[mat]], col, smooth_angle=smooth)


def p_wall():
	c = piece("WallPanel", width=16, height=28.4)
	obj(c, "Base", rbox(-8, 8, -1.3, 0.9, 0, 3.2, 0.45), "Navy")
	obj(c, "Body", rbox(-7.9, 7.9, -0.9, 0.85, 3.0, 27.4, 0.6), "Cream")
	obj(c, "Inset", rbox(-6.2, 6.2, -1.08, -0.7, 6.0, 24.0, 0.45), "Cream2")
	obj(c, "Cap", rbox(-8, 8, -1.2, 1.1, 27.2, 28.4, 0.45), "Navy")
	obj(c, "Strip", rbox(-7.4, 7.4, -1.45, -1.15, 2.45, 2.75, 0.1, 1), "GlowWhite")


def p_pillar():
	c = piece("Pillar", height=30)
	obj(c, "Base", rbox(-3, 3, -3, 3, 0, 3.4, 0.6), "Navy")
	obj(c, "Shaft", rbox(-2.4, 2.4, -2.4, 2.4, 3.2, 27.0, 0.8, 4), "Cream")  # 3 segments self-overlap at this size
	obj(c, "Cap", rbox(-3, 3, -3, 3, 26.8, 30, 0.6), "Navy")
	obj(c, "Ring", rbox(-2.65, 2.65, -2.65, 2.65, 23.6, 24.2, 0.22, 2), "GlowWhite")


def p_arch():
	# Range doorway: 16 x 16 opening, 3 thick frame, 4 deep, rounded corners, a glow line on the front face.
	c = piece("Arch", opening_w=16, opening_h=16)
	obj(c, "Frame", finish(prism(u_frame(16, 16, 3, 4, 7), "Y", -2, 2), 0.5), "Navy")
	obj(c, "Line", finish(prism(u_frame(17.2, 16.6, 0.5, 4.6, 5.1), "Y", -2.25, -1.85), 0.12, 1), "GlowCoral")


def p_beams():
	for L in (88, 40, 28):
		c = piece("GateBeam_%d" % L, length=L)
		obj(c, "Body", rbox(-L / 2, L / 2, -2, 2, 0, 5, 0.8), "Navy")
		obj(c, "Strip", rbox(-L / 2 + 1.5, L / 2 - 1.5, -0.5, 0.5, -0.18, 0.2, 0.12, 1), "GlowWhite")
	c = piece("RoofBeam_106", length=106)
	obj(c, "Body", rbox(-53, 53, -1.5, 1.5, 0, 4, 0.7), "Cream2")


def pad_ring(R):
	segs = []
	for k in range(8):
		segs.append(annulus(R - 1.15, R - 0.45, 0.7, 0.95, k * 45 + 6, k * 45 + 39, bev=0.06))
	return merge(*segs)


def p_pads():
	for D in (10, 13, 16):
		R = D / 2
		c = piece("QueuePad_%d" % D, diameter=D)
		obj(c, "Base", rcyl(R, 0, 0.8, 48, 0.3), "Navy")
		obj(c, "Top", rcyl(R - 1.4, 0.6, 1.05, 48, 0.2), "White")
		obj(c, "Mark", annulus(1.6, 2.3, 0.9, 1.12, bev=0.05), "Navy2")
		obj(c, "Ring", pad_ring(R), "GlowWhite")


def p_dais():
	c = piece("SpawnDais", radius=11)
	obj(c, "Step", rcyl(11, 0, 0.7, 64, 0.3), "Navy")
	obj(c, "Top", rcyl(9.2, 0.5, 1.3, 64, 0.3), "Cream")
	obj(c, "Ring", annulus(9.45, 10.4, 0.55, 0.85, n=64, bev=0.06), "GlowSun")
	obj(c, "Star", finish(prism(star(4.4, 2.0), "Z", 1.1, 1.45), 0.08, 1), "Sun")


def gem(scale=1.0):
	bm = bmesh.new()
	top = bm.verts.new((0, 0, 6 * scale))
	bot = bm.verts.new((0, 0, -5 * scale))
	up = [bm.verts.new((3 * scale * math.cos(math.radians(60 * i)), 3 * scale * math.sin(math.radians(60 * i)), 1.2 * scale)) for i in range(6)]
	lo = [bm.verts.new((2.7 * scale * math.cos(math.radians(60 * i + 30)), 2.7 * scale * math.sin(math.radians(60 * i + 30)), -0.8 * scale)) for i in range(6)]
	for i in range(6):
		j = (i + 1) % 6
		bm.faces.new((up[i], up[j], top))
		bm.faces.new((up[j], up[i], lo[i]))
		bm.faces.new((lo[i], lo[j], up[j]))
		bm.faces.new((lo[j], lo[i], bot))
	return _fix(bm)


def p_hero():
	# Floating "Gauntlet Core" over spawn: a faceted glass crystal with a glowing core, two orbit rings (separate
	# pieces so they spin on their own). Origin at the gem centre.
	c = piece("HeroCore")
	obj(c, "Shell", gem(1.0), "Glass", smooth=0)
	obj(c, "Core", gem(0.55), "GlowBlue")
	c = piece("HeroRingA")
	obj(c, "Ring", annulus(6.6, 7.2, -0.3, 0.3, n=72, bev=0.12), "GlowSun")
	c = piece("HeroRingB")
	parts = []
	for k in range(6):
		parts.append(annulus(8.4, 9.4, -0.5, 0.5, k * 60 + 4, k * 60 + 52, bev=0.2))
	obj(c, "Band", merge(*parts), "Navy")


def letters(body, height=6.0):
	cu = bpy.data.curves.new("T_" + body, "FONT")
	cu.body = body
	cu.font = bpy.data.fonts.load(font_path(), check_existing=True)
	cu.align_x, cu.align_y = "CENTER", "BOTTOM"
	cu.size = 8.0
	cu.extrude = 0.6
	cu.bevel_depth = 0.12
	cu.bevel_resolution = 1
	cu.resolution_u = 4
	cu.space_character = 1.05
	ob = bpy.data.objects.new("T_" + body, cu)
	bpy.context.scene.collection.objects.link(ob)
	dg = bpy.context.evaluated_depsgraph_get()
	me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
	ys = [v.co.y for v in me.vertices]
	h = max(ys) - min(ys)
	cu.size = 8.0 * height / h
	bpy.data.meshes.remove(me)
	dg = bpy.context.evaluated_depsgraph_get()
	me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
	bpy.data.objects.remove(ob)
	bm = bmesh.new()
	bm.from_mesh(me)
	bpy.data.meshes.remove(me)
	bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-4)
	ys = [v.co.y for v in bm.verts]
	xs = [v.co.x for v in bm.verts]
	cx, y0 = (min(xs) + max(xs)) / 2, min(ys)
	# Upright (curve +Y -> +Z), front (curve +Z) -> -Y, base on z = 0, then pushed forward of the panel.
	xform(bm, T(0, -1.1, 0) @ RX(90) @ T(-cx, -y0, 0))
	w = max(xs) - min(xs)
	face = bm.copy()
	side = bm
	for b, keep_front in ((face, True), (side, False)):
		kill = [f for f in b.faces if (f.normal.y < -0.95) != keep_front]
		bmesh.ops.delete(b, geom=kill, context="FACES")
	return face, side, w


def p_signs():
	for word, key, panel in (
		("DUELS", "DUELS", "Coral"), ("SHOP", "SHOP", "Sun"), ("BATTLE PASS", "BATTLEPASS", "Violet"),
		("LOCKER", "LOCKER", "Mint"), ("RANGE", "RANGE", "Red"), ("1V1", "1V1", "Coral"), ("2V2", "2V2", "Blue"),
		("3V3", "3V3", "Violet"),
	):
		face, side, w = letters(word)
		c = piece("Sign_" + key, text=word, width=round(w + 5, 2), height=10.4)
		obj(c, "Face", face, "White", smooth=0)
		obj(c, "Side", side, "Navy", smooth=60)
		pw, ph = w + 5.0, 10.4
		obj(c, "Panel", finish(prism(rrect(pw, ph, 3.0, 5, 0, 3.0), "Y", -0.4, 0.7), 0.35, 2), panel)
		obj(c, "Rim", finish(prism(rrect(pw + 1.2, ph + 1.2, 3.5, 5, 0, 3.0), "Y", -0.2, 1.1), 0.35, 2), "Navy")


def p_arrow():
	c = piece("Arrow")
	pts = [(-1.3, 4.2), (-1.3, 9.5), (1.3, 9.5), (1.3, 4.2), (3.4, 4.2), (0, 0), (-3.4, 4.2)][::-1]
	obj(c, "Body", finish(prism(pts, "Y", -0.6, 0.6), 0.3, 2), "Sun")


def p_leaderboard():
	c = piece("Leaderboard", width=18, height=12)
	obj(c, "Frame", rbox(-9, 9, -0.8, 0.8, 0, 12, 0.6), "Navy")
	obj(c, "Screen", rbox(-8, 8, -1.0, -0.6, 0.8, 9.4, 0.3, 2), "Screen")
	obj(c, "Header", rbox(-8, 8, -1.05, -0.6, 9.9, 11.3, 0.3, 2), "Sun")


def stripe_awning(x0, x1, n, depth_front=-4.6, depth_back=2.2, z_front=11.6, z_back=14.6):
	# Striped canopy: n alternating stripes along X, sloped up to the back wall, each with a scalloped valance tab.
	ang = math.degrees(math.atan2(z_back - z_front, depth_back - depth_front))
	L = math.hypot(z_back - z_front, depth_back - depth_front)
	w = (x1 - x0) / n
	a, b = [], []
	for i in range(n):
		sx0, sx1 = x0 + i * w, x0 + (i + 1) * w
		s = rbox(sx0, sx1, 0, L, -0.25, 0.25, 0.18, 2)
		xform(s, T(0, depth_front, z_front) @ RX(ang))
		tab = finish(prism([((sx0 + sx1) / 2 + (w / 2) * math.cos(math.radians(180 + 180 * k / 8)), (w / 2) * 0.8 * math.sin(math.radians(180 + 180 * k / 8))) for k in range(9)][::-1], "Y", -0.2, 0.2), 0.08, 1)
		xform(tab, T(0, depth_front + 0.05, z_front))
		(a if i % 2 == 0 else b).extend([s, tab])
	return merge(*a), merge(*b)


def p_shop():
	c = piece("ShopKiosk", width=16)
	obj(c, "Counter", rbox(-7, 7, -3, 0, 0, 3.6, 0.5), "Cream")
	obj(c, "CounterTop", rbox(-7.4, 7.4, -3.4, 0.3, 3.5, 4.1, 0.3), "Wood")
	obj(c, "CounterBand", rbox(-6.6, 6.6, -3.2, -2.9, 1.0, 2.4, 0.15, 2), "Coral")
	obj(c, "Back", rbox(-7.5, 7.5, 1.0, 2.4, 0, 14.4, 0.6), "Coral")
	obj(c, "Shelves", merge(rbox(-6.4, 6.4, 0.2, 1.1, 6.0, 6.5, 0.15, 2), rbox(-6.4, 6.4, 0.2, 1.1, 9.4, 9.9, 0.15, 2)), "Navy")
	obj(c, "Posts", merge(rcyl(0.5, 4.0, 12.1, 16, 0.15, cx=-6.9, cy=-3.0), rcyl(0.5, 4.0, 12.1, 16, 0.15, cx=6.9, cy=-3.0)), "Navy")
	sa, sb = stripe_awning(-8, 8, 7)
	obj(c, "AwningA", sa, "Cream")
	obj(c, "AwningB", sb, "Coral")


def p_giftbox():
	c = piece("GiftBox", size=2)
	obj(c, "Box", rbox(-1, 1, -1, 1, 0, 2, 0.25), "Coral")
	obj(c, "Ribbon", merge(rbox(-1.06, 1.06, -0.25, 0.25, -0.06, 2.06, 0.08, 1), rbox(-0.25, 0.25, -1.08, 1.08, -0.04, 2.04, 0.08, 1)), "Sun")
	bow = []
	for s in (-1, 1):
		b = rcyl(0.45, -0.18, 0.18, 12, 0.08)
		xform(b, T(0.42 * s, 0, 2.3) @ RZ(90) @ RX(90) @ Matrix.Diagonal((1.0, 0.7, 1.0, 1.0)))
		bow.append(b)
	obj(c, "Bow", merge(*bow), "Sun")


def p_battlepass():
	c = piece("BattlePassStand", width=16)
	obj(c, "Base", rbox(-8, 8, -4, 2, 0, 1.2, 0.5), "Navy")
	obj(c, "Frame", rbox(-7, 7, -0.8, 0.8, 1.0, 19, 1.0), "Violet")
	obj(c, "Screen", rbox(-6, 6, -1.05, -0.6, 2.4, 16.6, 0.4, 2), "Screen")
	obj(c, "Strips", merge(rbox(-6.75, -6.3, -1.0, -0.7, 2.0, 17.0, 0.1, 1), rbox(6.3, 6.75, -1.0, -0.7, 2.0, 17.0, 0.1, 1)), "GlowSun")
	c = piece("Star")
	obj(c, "Body", finish(prism([(x, z) for x, z in star(3.0, 1.4)], "Y", -0.6, 0.6), 0.3, 2), "Sun")
	c = piece("Podium")
	obj(c, "Body", rcyl(1.8, 0, 3.0, 24, 0.3), "Cream")
	obj(c, "Ring", annulus(1.85, 2.1, 2.3, 2.6, n=24, bev=0.05), "GlowSun")


def p_locker():
	c = piece("LockerUnit", width=4)
	obj(c, "Body", rbox(-2, 2, -1.5, 1.5, 0, 11, 0.4), "Mint")
	obj(c, "Door", rbox(-1.6, 1.6, -1.7, -1.3, 0.8, 10.2, 0.25, 2), "Cream")
	obj(c, "Vents", merge(*[rbox(-1.0, 1.0, -1.85, -1.6, 8.2 + 0.6 * i, 8.5 + 0.6 * i, 0.1, 1) for i in range(3)]), "Navy")
	obj(c, "Handle", rbox(0.9, 1.2, -2.0, -1.6, 4.8, 6.4, 0.1, 1), "Navy")
	c = piece("Turntable", radius=4)
	obj(c, "Base", rcyl(4, 0, 0.8, 48, 0.3), "Navy")
	obj(c, "Top", rcyl(3.4, 0.6, 1.0, 48, 0.2), "Cream")
	obj(c, "Ring", pad_ring(4.0), "GlowWhite")
	c = piece("Mannequin", height=5.6)
	body = [
		rbox(-0.9, 0.9, -0.5, 0.5, 2.6, 4.6, 0.35),  # torso
		rbox(-0.85, -0.1, -0.4, 0.4, 0.2, 2.65, 0.3),  # legs
		rbox(0.1, 0.85, -0.4, 0.4, 0.2, 2.65, 0.3),
		rbox(-1.75, -1.0, -0.38, 0.38, 2.5, 4.5, 0.3),  # arms
		rbox(1.0, 1.75, -0.38, 0.38, 2.5, 4.5, 0.3),
		rbox(-0.55, 0.55, -0.55, 0.55, 4.75, 5.85, 0.4),  # head
	]
	obj(c, "Body", merge(*body), "Cream2")
	obj(c, "Stand", merge(rcyl(0.18, 1.0, 2.7, 10, 0.05)), "Navy")


def p_target():
	c = piece("TargetEmblem", radius=4)
	for i, (r, y, m) in enumerate(((4.0, 0.3, "White"), (3.1, 0.55, "Red"), (2.2, 0.8, "White"), (1.2, 1.05, "Red"))):
		d = rcyl(r, -0.3 + 0.08 * i, y, 40, 0.15)  # staggered backs: no shared plane
		xform(d, RX(90))
		obj(c, "Ring%d" % i, d, m)


def blob(radius, seed, subdiv=2):
	rnd = random.Random(seed)
	bm = bmesh.new()
	bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius)
	for v in bm.verts:
		v.co *= 1.0 + rnd.uniform(-0.09, 0.09)
		v.co.z *= 0.85
	return _fix(bm)


def p_planter():
	c = piece("Planter", radius=4.3)
	obj(c, "Body", rcyl(4, 0, 2.4, 8, 0.5, 2), "Cream")
	obj(c, "Rim", annulus(3.4, 4.35, 2.2, 2.95, n=8, bev=0.15), "Navy")
	obj(c, "Soil", rcyl(3.5, 2.2, 2.75, 8, 0.1), "Soil")
	trunk = prism(circle(0.85, 7), "Z", 2.5, 9.5)
	for v in trunk.verts:
		if v.co.z > 5:
			v.co.x *= 0.6
			v.co.y *= 0.6
	obj(c, "Trunk", finish(trunk, 0.1, 1), "Trunk", smooth=0)
	can = blob(4.6, 7)
	xform(can, T(0, 0, 12.2))
	obj(c, "Canopy", can, "Leaf", smooth=0)


def p_bench():
	c = piece("Bench", length=8)
	obj(c, "Seat", rbox(-4, 4, -1.1, 1.1, 1.6, 2.2, 0.3), "Wood")
	obj(c, "Legs", merge(rbox(-3.4, -2.6, -0.8, 0.8, 0, 1.7, 0.2), rbox(2.6, 3.4, -0.8, 0.8, 0, 1.7, 0.2)), "Navy")


def p_bleacher():
	# Three seating steps facing -Y, 24 long; one stepped profile (no stacked boxes, so no coplanar ends).
	c = piece("Bleacher", length=24)
	prof = [(-6.0, 0), (3.0, 0), (3.0, 4.2), (0.0, 4.2), (0.0, 2.8), (-3.0, 2.8), (-3.0, 1.4), (-6.0, 1.4)]
	obj(c, "Body", finish(prism([(y, z) for y, z in prof], "X", -12, 12), 0.35, 2), "Cream")
	pads = [rbox(-11.2, 11.2, y0, y0 + 2.2, z - 0.1, z + 0.22, 0.12, 2) for y0, z in ((-5.6, 1.4), (-2.6, 2.8), (0.4, 4.2))]
	obj(c, "Pads", merge(*pads), "Blue")


def p_floors():
	c = piece("FloorDisc_24", radius=24)
	obj(c, "Disc", rcyl(24, -0.2, 0.25, 72, 0.18, 2), "Cream2")
	obj(c, "Ring", annulus(20.5, 21.5, 0.15, 0.35, n=72, bev=0.05), "Navy")
	c = piece("ArenaInlay", width=96, depth=50)
	obj(c, "Floor", finish(prism(rrect(96, 50, 8, 6), "Z", -0.2, 0.25), 0.18, 2), "Navy2")
	obj(c, "CenterRing", annulus(13, 14, 0.15, 0.38, n=72, bev=0.05), "White")


def build():
	for o in list(bpy.data.objects):
		bpy.data.objects.remove(o)
	materials()
	global KIT
	KIT = collection("Kit_Stylized")
	for f in (p_wall, p_pillar, p_arch, p_beams, p_pads, p_dais, p_hero, p_signs, p_arrow, p_leaderboard, p_shop, p_giftbox,
			p_battlepass, p_locker, p_target, p_planter, p_bench, p_bleacher, p_floors):
		f()
	tris = {}
	for n, c in PIECES.items():
		t = 0
		for o in c.all_objects:
			o.data.calc_loop_triangles()
			t += len(o.data.loop_triangles)
		tris[n] = t
	bpy.ops.wm.save_as_mainfile(filepath=BLEND)
	return tris


def render_sheet():
	# Contact sheet: every piece laid out in a grid under a soft sun, EEVEE.
	os.makedirs(RENDER_DIR, exist_ok=True)
	sc = bpy.context.scene
	stage = collection("_Sheet")
	x = y = 0.0
	row_h = 0.0
	skip = ("RoofBeam_106", "GateBeam_88", "GateBeam_40", "GateBeam_28", "ArenaInlay", "FloorDisc_24", "WallPanel")
	order = [kv for kv in PIECES.items() if kv[0] not in skip]
	for n, c in order:
		pts = [o.matrix_world @ Vector(b) for o in c.all_objects for b in o.bound_box]
		mn = Vector((min(p.x for p in pts), min(p.y for p in pts), 0))
		w, d = max(p.x for p in pts) - mn.x, max(p.y for p in pts) - mn.y
		if x + w > 110:
			x, y, row_h = 0.0, y + row_h + 4, 0.0
		e = bpy.data.objects.new("I_" + n, None)
		e.instance_type = "COLLECTION"
		e.instance_collection = c
		e.location = (x - mn.x, y - mn.y, 6 if n == "HeroCore" else 0)
		stage.objects.link(e)
		x += w + 4
		row_h = max(row_h, d)
	extent_y = y + row_h
	for c in PIECES.values():
		bpy.context.view_layer.layer_collection.children["Kit_Stylized"].children[c.name].exclude = False
		c.hide_render = False
	ground = bpy.data.meshes.new("G")
	bmg = bmesh.new()
	bmesh.ops.create_grid(bmg, x_segments=1, y_segments=1, size=400)
	bmg.to_mesh(ground)
	g = bpy.data.objects.new("G", ground)
	g.data.materials.append(_flat("S_Ground", 0xC9CFDA, 0.8))
	stage.objects.link(g)
	sun = bpy.data.lights.new("Sun", "SUN")
	sun.energy = 3.5
	so = bpy.data.objects.new("Sun", sun)
	so.rotation_euler = (math.radians(50), 0, math.radians(30))
	stage.objects.link(so)
	sc.world = sc.world or bpy.data.worlds.new("W")
	sc.world.use_nodes = True
	sc.world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.65, 0.8, 1)
	sc.world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
	cam = bpy.data.cameras.new("Cam")
	cam.lens = 30
	co = bpy.data.objects.new("Cam", cam)
	co.location = (55, extent_y * 0.5 - 70, 75)
	co.rotation_euler = (math.radians(45), 0, 0)
	stage.objects.link(co)
	sc.camera = co
	sc.render.engine = "BLENDER_EEVEE"
	sc.render.resolution_x, sc.render.resolution_y = 1600, 1000
	sc.view_settings.view_transform = "Standard"
	sc.render.image_settings.file_format = "JPEG"
	sc.render.filepath = os.path.join(RENDER_DIR, "kit-contact.jpg")
	bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
	args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	tris = build()
	print("KIT_STYLIZED", sum(tris.values()), tris)
	if "--render" in args:
		render_sheet()
		print("RENDERED")
