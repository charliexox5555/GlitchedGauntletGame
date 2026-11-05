# build_lobby_kit_bunker2.py: the "Sunwell Bunker, redone" kit (Lobby rebuild 2026-11-04).
#
#   blender --background --factory-startup --python tools/blender/build_lobby_kit_bunker2.py [-- --render]
#
# Writes art-source/lobby/Kit_Bunker2.blend, one Lobby_<Piece> collection per piece, front facing Blender -Y
# (= Roblox +Z), origin at the bottom centre unless noted (hub pieces: the hub centre; room pieces: the room centre).
# Look (vault/02 Art/Lobby Rebuild 2026-11-04.md): stylized, grounded bunker, lower poly but structured. Every piece
# has a designed profile (notched shafts, stepped plinths, cornices, reveals, picture-frame rings with rounded inner
# corners), a bevel hierarchy (primary 0.3-0.8 / secondary 0.1-0.15 / tertiary 0.05), textured concrete, floor, metal
# and grate where they help (Bunker_* MaterialVariants), clean SmoothPlastic elsewhere, Neon only on thin accents.
# Rule: no two faces of a piece share a plane facing the same way; bases sit 0.1 below the floor.
# Next: export_lobby_kit.py -- Bunker2, upload_models.py --lobby Bunker2, then the Studio build.

import bpy, bmesh, glob, math, os, sys
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
	sys.path.insert(0, HERE)
from lobbykit import collection, add_obj, _flat, _emissive, lathe, ROOT  # noqa: E402
from build_lobby_kit_stylized import prism, finish, rbox, rcyl, annulus, rrect, u_frame, star, xform, T, RX, RZ, merge, _fix  # noqa: E402

BLEND = os.path.join(ROOT, "art-source", "lobby", "Kit_Bunker2.blend")
RENDER_DIR = os.path.join(ROOT, "vault", "02 Art", "References", "lobby", "rebuild-20261104")

M = {}


def tex(name, rbx, variant, color, rough=0.7, metallic=0.0):
	m = _flat("B_" + name, color, rough, metallic=metallic, rbx=rbx)
	m["rbx_variant"] = variant
	return m


def materials():
	M["Concrete"] = tex("Concrete", "Concrete", "Bunker_Concrete", 0xA39787)
	M["ConcreteLight"] = tex("ConcreteLight", "Concrete", "Bunker_Concrete", 0xC9BEAE)
	M["ConcreteDark"] = tex("ConcreteDark", "Concrete", "Bunker_Concrete", 0x625C55)
	M["Floor"] = tex("Floor", "Slate", "Bunker_Floor", 0x8C8070)
	M["Metal"] = tex("Metal", "Metal", "Bunker_Metal", 0x34495A, 0.45, 0.6)
	M["Grate"] = tex("Grate", "DiamondPlate", "Bunker_Grate", 0x3A434C, 0.5, 0.5)
	M["Slate"] = _flat("B_Slate", 0x2F4250, 0.5)
	M["Ochre"] = _flat("B_Ochre", 0xB8672E, 0.5)
	M["Dark"] = _flat("B_Dark", 0x1E2329, 0.6)
	M["Screen"] = _flat("B_Screen", 0x121822, 0.3)
	M["White"] = _flat("B_White", 0xF2F0EA, 0.4)
	M["Panel"] = _flat("B_Panel", 0xE6EBEE, 0.4)
	M["Glass"] = _flat("B_Glass", 0xA8DCEB, 0.1, rbx="Glass", rbx_transparency=0.55)
	for k, c in {"GlowWarm": 0xFFB45A, "GlowWhite": 0xFFF1DC, "GlowAccent": 0xFFFFFF, "GlowBlue": 0x4FC8FF}.items():
		M[k] = _emissive("B_" + k, c, 5.0)


# ---------------------------------------------------------------- helpers

def ring_prism(outer, inner, a0, a1, axis="Z"):
	# Picture-frame solid between two closed outlines (same point count, both CCW), extruded a0..a1.
	bm = bmesh.new()

	def co(p, w):
		if axis == "Y":
			return (p[0], w, p[1])
		if axis == "X":
			return (w, p[0], p[1])
		return (p[0], p[1], w)

	o0 = [bm.verts.new(co(p, a0)) for p in outer]
	o1 = [bm.verts.new(co(p, a1)) for p in outer]
	i0 = [bm.verts.new(co(p, a0)) for p in inner]
	i1 = [bm.verts.new(co(p, a1)) for p in inner]
	n = len(outer)
	for k in range(n):
		j = (k + 1) % n
		bm.faces.new((o1[k], o1[j], i1[j], i1[k]))
		bm.faces.new((o0[k], i0[k], i0[j], o0[j]))
		bm.faces.new((o0[k], o0[j], o1[j], o1[k]))
		bm.faces.new((i0[j], i0[k], i1[k], i1[j]))
	return _fix(bm)


def frame(w_out, h_out, r_out, w_in, h_in, r_in, a0, a1, axis="Y", cz=0.0, cz_in=None, bev=0.12):
	n = 5
	o = rrect(w_out, h_out, r_out, n, 0, cz)
	i = rrect(w_in, h_in, r_in, n, 0, cz if cz_in is None else cz_in)
	return finish(ring_prism(o, i, a0, a1, axis), bev, 2)


def chamfer_path(pts, c):
	# Cut every interior corner of an open (r, z) polyline by c: lathe profiles get crisp secondary bevels.
	out = [pts[0]]
	for k in range(1, len(pts) - 1):
		p, a, b = Vector(pts[k]), Vector(pts[k - 1]), Vector(pts[k + 1])
		da, db = (a - p), (b - p)
		ca, cb = min(c, da.length * 0.45), min(c, db.length * 0.45)
		out.append(tuple(p + da.normalized() * ca))
		out.append(tuple(p + db.normalized() * cb))
	out.append(pts[-1])
	return out


def lath(profile, c=0.12, b0=0.0, b1=360.0, steps=None):
	# lathe() already faces each surface the right way (left of the profile direction); recalculating normals on an
	# open shell can flip it inside out, so don't.
	return lathe(chamfer_path(profile, c), b0, b1, steps)


def font(name):
	hits = sorted(glob.glob(os.path.join(os.environ.get("LOCALAPPDATA", ""), "Roblox", "Versions", "*", "content", "fonts", name)))
	return hits[-1] if hits else "C:/Windows/Fonts/seguibl.ttf"


def text_mesh(body, height, depth=0.45, fnt="Montserrat-Black.ttf", spacing=1.0):
	# 3D letters, upright, facing -Y, baseline at z 0, centred on x; front face at y -depth, back at y 0.
	cu = bpy.data.curves.new("T_" + body, "FONT")
	cu.body = body
	cu.font = bpy.data.fonts.load(font(fnt), check_existing=True)
	cu.align_x, cu.align_y = "CENTER", "BOTTOM"
	cu.size = 1.0
	cu.extrude = depth / 2
	cu.bevel_depth = 0.0
	cu.resolution_u = 3
	cu.space_character = spacing
	ob = bpy.data.objects.new("T_" + body, cu)
	bpy.context.scene.collection.objects.link(ob)
	for _ in range(2):
		dg = bpy.context.evaluated_depsgraph_get()
		me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
		ys = [v.co.y for v in me.vertices]
		h = max(ys) - min(ys)
		bpy.data.meshes.remove(me)
		cu.size *= height / h
	dg = bpy.context.evaluated_depsgraph_get()
	me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
	bpy.data.objects.remove(ob)
	bm = bmesh.new()
	bm.from_mesh(me)
	bpy.data.meshes.remove(me)
	bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-4)
	xs = [v.co.x for v in bm.verts]
	ys = [v.co.y for v in bm.verts]
	cx, y0 = (min(xs) + max(xs)) / 2, min(ys)
	xform(bm, T(0, -depth / 2, 0) @ RX(90) @ T(-cx, -y0, 0))
	bm = finish(bm, 0.0, 1)
	return bm, max(xs) - min(xs)


PIECES = {}


def piece(name, **props):
	col = collection("Lobby_" + name, KIT)
	for k, v in props.items():
		col[k] = v
	PIECES[name] = col
	return col


def obj(col, part, bm, mat, smooth=35):
	name = col.name[6:] + "_" + part
	if mat.startswith("Glow"):
		name = name if name.endswith("_Glow") else name + "_Glow"
		ob = add_obj(name, bm, [M[mat]], col, smooth_angle=0)
		ob["glow"] = True
		ob.visible_shadow = False
		return ob
	return add_obj(name, bm, [M[mat]], col, smooth_angle=smooth)


# ---------------------------------------------------------------- hub: rotunda

def p_pier():
	c = piece("Pier", height=20)
	n = 0.7
	sec = [(-3 + n, -3), (-0.5, -3), (-0.5, -2.65), (0.5, -2.65), (0.5, -3), (3 - n, -3), (3 - n, -3 + n), (3, -3 + n), (3, 3 - n),
		(3 - n, 3 - n), (3 - n, 3), (-3 + n, 3), (-3 + n, 3 - n), (-3, 3 - n), (-3, -3 + n), (-3 + n, -3 + n)]
	obj(c, "Shaft", finish(prism(sec, "Z", 1.6, 18.0), 0.12, 2), "Concrete")
	obj(c, "Plinth", rbox(-3.6, 3.6, -3.6, 3.6, -0.1, 1.8, 0.3), "ConcreteDark")
	obj(c, "Collar", rbox(-3.3, 3.3, -3.3, 3.3, 17.8, 18.8, 0.2, 2), "Metal")
	octo = [(3.7 - 1.1, -3.7), (3.7, -3.7 + 1.1), (3.7, 3.7 - 1.1), (3.7 - 1.1, 3.7), (-3.7 + 1.1, 3.7), (-3.7, 3.7 - 1.1), (-3.7, -3.7 + 1.1), (-3.7 + 1.1, -3.7)]
	obj(c, "Cap", finish(prism(octo, "Z", 18.6, 20.0), 0.15, 2), "Slate")
	obj(c, "Slot", rbox(-0.3, 0.3, -2.9, -2.72, 4.0, 15.0, 0.06, 1), "GlowWarm")


def p_drum():
	c = piece("Drum", radius=28)
	prof = [(31.6, 22.0), (31.6, 20.0), (28.0, 20.0), (28.0, 20.9), (28.7, 20.9), (28.7, 25.0), (27.4, 25.0), (27.4, 26.0), (27.9, 26.0), (27.9, 27.0), (31.6, 27.0)]
	obj(c, "Body", lath(prof, 0.12), "Concrete")
	obj(c, "Cove", lath([(28.7, 24.45), (28.58, 24.45), (28.58, 24.9)], 0.0), "GlowWarm")


def p_dome():
	c = piece("Dome", oculus=11.6)
	prof = [(31.6, 27.0), (24.6, 27.0), (24.6, 30.2), (18.2, 30.2), (18.2, 33.6), (12.6, 33.6), (12.6, 36.6), (11.6, 36.6), (11.6, 40.0), (32.0, 40.0)]
	obj(c, "Shell", lath(prof, 0.3), "ConcreteLight")
	c = piece("DomeRib")
	# Hangs under the treads and hugs each riser on its inner side (a simple stair band, never self-crossing).
	fin = [(31.2, 26.3), (23.75, 26.3), (23.75, 29.4), (17.35, 29.4), (17.35, 32.8), (12.55, 32.8), (12.55, 33.65), (18.15, 33.65),
		(18.15, 30.25), (24.55, 30.25), (24.55, 27.05), (31.2, 27.05)]
	obj(c, "Fin", finish(prism(fin, "X", -0.55, 0.55), 0.12, 2), "Metal")
	c = piece("OculusRim")
	obj(c, "Rim", lath([(13.4, 36.4), (11.2, 36.4), (11.0, 36.7), (11.0, 40.2), (13.4, 40.2)], 0.05), "Slate")
	obj(c, "Glow", annulus(11.7, 12.7, 36.18, 36.3, n=64, bev=0.04), "GlowWarm")


def p_dais():
	c = piece("SpawnDais", radius=9)
	obj(c, "Base", lath([(9.6, -0.1), (9.6, 0.45), (9.2, 0.55), (8.2, 0.55)], 0.1), "ConcreteDark")
	obj(c, "Deck", lath([(8.3, 0.4), (8.3, 1.0), (7.9, 1.1), (6.0, 1.1), (6.0, 0.8)], 0.08), "Slate")
	obj(c, "Hub", rcyl(2.6, 0.4, 1.12, 32, 0.2), "Metal")
	slats = []
	for k in range(20):
		s = rbox(-0.22, 0.22, 2.75, 5.85, 0.7, 0.98, 0.06, 1)
		xform(s, RZ(k * 18))
		slats.append(s)
	obj(c, "Grate", merge(*slats), "Metal")
	obj(c, "Under", annulus(2.6, 6.0, 0.45, 0.55, n=48, bev=0.0), "GlowBlue")


def p_floor_ring():
	c = piece("RotundaFloorRing", radius=30)
	obj(c, "Band", annulus(26.4, 29.0, -0.1, 0.08, n=96, bev=0.04), "Slate")
	obj(c, "Line", annulus(25.6, 26.0, -0.1, 0.1, n=96, bev=0.03), "Ochre")


def p_guide():
	c = piece("GuideLine", length=12)
	obj(c, "Strip", finish(prism(rrect(1.0, 12.0, 0.45, 4), "Z", -0.1, 0.09), 0.03, 1), "GlowAccent")


# ---------------------------------------------------------------- hub: ring

def p_ring():
	c = piece("RingCeiling", radius=44)
	prof = [(44.6, 22.0), (42.2, 22.0), (42.2, 22.6), (34.0, 22.6), (34.0, 22.0), (31.6, 22.0)]
	obj(c, "Soffit", lath(prof, 0.12), "Concrete")
	obj(c, "Cove", lath([(42.2, 22.08), (42.08, 22.08), (42.08, 22.5)], 0.0), "GlowWarm")
	c = piece("RingRib")
	pts = [(31.8, 22.05), (31.8, 21.2), (32.4, 20.6), (41.8, 20.6), (43.0, 19.4), (44.45, 19.4), (44.45, 22.05)]
	obj(c, "Beam", finish(prism(pts, "X", -0.7, 0.7), 0.12, 2), "Metal")
	for span, name in ((44.4, "RingWall_444"), (52.8, "RingWall_528")):
		c = piece(name, span=span)
		obj(c, "Plinth", lath([(42.9, -0.1), (42.9, 1.3), (43.2, 1.6), (43.6, 1.6)], 0.06, 0, span), "ConcreteDark")
		obj(c, "Wall", lath([(43.6, 1.6), (43.6, 2.2), (43.35, 2.2), (43.35, 19.6)], 0.04, 0, span), "Concrete")
		obj(c, "Cornice", lath([(43.35, 19.6), (42.8, 20.2), (42.8, 22.0)], 0.05, 0, span), "Metal")
		obj(c, "Gap", lath([(43.5, 1.65), (43.5, 2.15)], 0.0, 0, span), "GlowWarm")
	c = piece("RingPilaster")
	sec = [(-1.2, -0.95), (-0.25, -0.95), (-0.25, -0.75), (0.25, -0.75), (0.25, -0.95), (1.2, -0.95), (1.2, 0.0), (-1.2, 0.0)]
	sec = [(-1.2, -0.65), (-0.9, -0.95)] + sec[1:5] + [(0.9, -0.95), (1.2, -0.65), (1.2, 0.05), (-1.2, 0.05)]
	obj(c, "Shaft", finish(prism(sec, "Z", -0.1, 19.6), 0.08, 1), "ConcreteDark")
	c = piece("VentFan", radius=2.6)
	obj(c, "Housing", lath([(2.9, 0.6), (2.9, -0.2), (2.6, -0.45), (2.3, -0.45), (2.3, 0.6)], 0.06), "Metal")
	obj(c, "Back", rcyl(2.35, 0.25, 0.5, 32, 0.0), "Dark")
	c = piece("FanBlades", radius=2.2)
	blades = []
	for k in range(5):
		b = rbox(0.2, 2.15, -0.38, 0.38, -0.06, 0.06, 0.05, 1)
		xform(b, RZ(k * 72) @ RX(18))
		blades.append(b)
	blades.append(rcyl(0.45, -0.15, 0.15, 16, 0.08))
	obj(c, "Blades", merge(*blades), "Slate")


def p_portals():
	for W in (28, 40):
		c = piece("Portal_%d" % W, opening=W, height=14)
		h = W / 2
		jr = [(h, -1.5), (h + 0.6, -1.5), (h + 0.6, -2.1), (h + 2.2, -2.1), (h + 3.4, -0.9), (h + 3.4, 2.1), (h, 2.1)]
		jl = [(-x, y) for x, y in jr][::-1]
		obj(c, "Jambs", merge(finish(prism(jr, "Z", -0.1, 14.6), 0.15, 2), finish(prism(jl, "Z", -0.1, 14.6), 0.15, 2)), "Concrete")
		side = [(2.0, 14.0), (-1.5, 14.0), (-2.3, 14.8), (-2.3, 19.0), (-1.9, 19.6), (2.0, 19.6)]
		obj(c, "Header", finish(prism(side, "X", -(h + 3.6), h + 3.6), 0.2, 2), "ConcreteDark")
		obj(c, "Reveal", finish(prism(u_frame(W - 0.6, 13.7, 0.3, 0.8, 1.1), "Y", -1.4, 1.6), 0.06, 1), "Metal")
		strips = [rbox(s * (h + 0.1) - 0.125 + s * 0.125, s * (h + 0.1) + 0.125 + s * 0.125, -1.75, -1.45, 0.6, 13.4, 0.05, 1) for s in (-1, 1)]
		strips.append(rbox(-h - 0.3, h + 0.3, -1.75, -1.45, 13.7, 13.95, 0.05, 1))
		obj(c, "Edge", merge(*strips), "GlowAccent")
		obj(c, "Kick", merge(rbox(h + 0.7, h + 2.1, -2.25, -2.0, 0.3, 1.3, 0.06, 1), rbox(-h - 2.1, -h - 0.7, -2.25, -2.0, 0.3, 1.3, 0.06, 1)), "Ochre")


# ---------------------------------------------------------------- Duels hall

def steps(W, n, name):
	c = piece(name, width=W, steps=n)
	prof = [(-0.6, 0.0)]
	for k in range(n):
		prof += [(2.0 * k, -float(k)), (2.0 * k, -float(k + 1))]
	prof += [(2.0 * n + 0.4, -float(n)), (2.0 * n + 0.4, -float(n) - 0.6), (-0.6, -float(n) - 0.6)]
	pts = []
	for p in prof:
		if not pts or (abs(pts[-1][0] - p[0]) > 1e-6 or abs(pts[-1][1] - p[1]) > 1e-6):
			pts.append(p)
	pts = [(y, z) for y, z in pts][::-1]
	obj(c, "Body", finish(prism(pts, "X", -W / 2 + 0.8, W / 2 - 0.8), 0.1, 2), "ConcreteDark")
	strips = [rbox(-W / 2 + 1.6, W / 2 - 1.6, 2.0 * k + 0.2, 2.0 * k + 0.6, -k - 1 - 0.05, -k - 1 + 0.05, 0.03, 1) for k in range(n)]
	obj(c, "Nosing", merge(*strips), "Ochre")
	cheek = [(-0.6, 0.5), (-0.6, -n - 0.6), (2.0 * n + 0.4, -n - 0.6), (2.0 * n + 0.4, -n + 0.5)]
	obj(c, "Cheeks", merge(finish(prism(cheek, "X", -W / 2, -W / 2 + 0.8), 0.15, 2), finish(prism(cheek, "X", W / 2 - 0.8, W / 2), 0.15, 2)), "Metal")


def p_hall():
	c = piece("HallBay", length=19, height=28)
	obj(c, "Plinth", rbox(-9.5, 9.5, -1.0, 0.6, -0.1, 1.6, 0.25), "ConcreteDark")
	obj(c, "Frame", frame(19.0, 10.6, 0.3, 15.0, 8.0, 0.8, -0.5, 0.6, "Y", 6.7, 6.6), "Concrete")
	obj(c, "Recess", rbox(-7.6, 7.6, 0.0, 0.7, 2.5, 10.7, 0.05, 1), "Slate")
	obj(c, "Upper", rbox(-9.47, 9.47, -0.2, 0.55, 11.8, 28.1, 0.12, 2), "Concrete")
	obj(c, "Ribs", merge(*[rbox(-9.5, 9.5, -0.55, -0.1, z, z + 0.6, 0.12, 2) for z in (14.0, 18.0, 22.0)]), "Metal")
	obj(c, "Cove", rbox(-9.4, 9.4, -0.45, -0.25, 12.2, 12.45, 0.05, 1), "GlowWarm")
	c = piece("Buttress", height=20)
	side = [(-3.2, -0.1), (-3.2, 1.6), (-2.6, 2.2), (-1.6, 16.0), (-1.6, 19.0), (-0.9, 19.8), (0.4, 19.8), (0.4, -0.1)][::-1]
	obj(c, "Body", finish(prism([(y, z) for y, z in side], "X", -1.5, 1.5), 0.2, 2), "ConcreteDark")
	obj(c, "Cap", rbox(-1.75, 1.75, -1.9, 0.5, 19.7, 20.3, 0.15, 2), "Metal")
	obj(c, "Band", rbox(-1.62, 1.62, -3.32, -2.4, 0.3, 1.3, 0.05, 1), "Ochre")
	c = piece("HallTruss", span=44)
	obj(c, "Beam", rbox(-22.0, 22.0, -0.8, 0.8, 22.0, 24.0, 0.3, 2), "Metal")
	gus = [(19.2, 22.05), (22.0, 22.05), (22.0, 19.8)]
	g = [finish(prism(gus, "Y", -0.5, 0.5), 0.08, 1) for _ in range(2)]
	xform(g[1], Matrix.Diagonal((-1, 1, 1, 1)))
	obj(c, "Gussets", merge(*g), "Metal")
	c = piece("Pendant")
	obj(c, "Rod", rcyl(0.12, -4.0, 0.05, 8, 0.0), "Dark")
	obj(c, "Shade", lath([(0.0, -3.9), (0.5, -3.9), (2.3, -5.0), (2.3, -5.3), (2.0, -5.3)], 0.08), "Slate")
	obj(c, "Lamp", rcyl(1.95, -5.42, -5.3, 32, 0.0), "GlowWarm")


def p_pads():
	for S in (12, 14, 16):
		c = piece("DuelPad_%d" % S, size=S)
		obj(c, "Frame", finish(ring_prism(rrect(S, S, 1.6, 5), rrect(S - 1.6, S - 1.6, 1.0, 5), -0.1, 0.25), 0.1, 2), "Metal")
		obj(c, "Edge", ring_prism(rrect(S - 1.6, S - 1.6, 1.0, 5), rrect(S - 2.1, S - 2.1, 0.75, 5), -0.05, 0.18), "GlowAccent")
		obj(c, "Plate", finish(prism(rrect(S - 2.1, S - 2.1, 0.75, 5), "Z", -0.1, 0.1), 0.0, 1), "Grate")
		rings = [annulus(S * 0.33, S * 0.33 + 0.5, 0.05, 0.16, n=64, bev=0.02), annulus(S * 0.18, S * 0.18 + 0.45, 0.05, 0.16, n=48, bev=0.02),
			rcyl(0.8, 0.05, 0.16, 24, 0.02)]
		obj(c, "Rings", merge(*rings), "GlowAccent")
	c = piece("PadScreen", width=14.6)
	obj(c, "Bezel", frame(14.6, 7.6, 0.6, 13.4, 6.4, 0.35, -0.45, 0.0, "Y", 3.8), "Metal")
	obj(c, "Face", rbox(-6.75, 6.75, -0.25, 0.0, 0.65, 6.95, 0.05, 1), "Screen")
	obj(c, "Status", rbox(-2.0, 2.0, -0.6, -0.4, 7.15, 7.4, 0.05, 1), "GlowAccent")
	for mode in ("1V1", "2V2", "3V3"):
		c = piece("ModeTab_" + mode, mode=mode)
		obj(c, "Plate", finish(prism(rrect(6.4, 2.8, 0.8, 5), "Y", -0.3, 0.3), 0.0, 1), "White")
		obj(c, "Rim", finish(ring_prism(rrect(6.9, 3.3, 1.05, 5), rrect(6.4, 2.8, 0.8, 5), -0.4, 0.4, "Y"), 0.08, 1), "Slate")
		t, w = text_mesh(mode, 1.7, 0.35, spacing=1.12)
		xform(t, T(0, -0.25, -0.85))
		obj(c, "Text", t, "Dark", smooth=0)
		obj(c, "Hangers", merge(rcyl(0.08, 1.6, 4.5, 8, 0.0, cx=-2.4), rcyl(0.08, 1.6, 4.5, 8, 0.0, cx=2.4)), "Dark")
	c = piece("Chevron")
	obj(c, "Body", finish(prism([(-2.2, 0.0), (0.0, 1.6), (2.2, 0.0), (2.2, -0.9), (0.0, 0.7), (-2.2, -0.9)][::-1], "Z", -0.1, 0.1), 0.04, 1), "White")


def p_blastdoor():
	c = piece("BlastDoor", opening=12, height=14)
	obj(c, "Frame", finish(prism(u_frame(12, 14, 1.6, 1.2, 2.0), "Y", -1.0, 1.0), 0.15, 2), "Metal")
	leaves = [rbox(-5.95, -0.1, -0.4, 0.4, 0.0, 13.9, 0.15, 2), rbox(0.1, 5.95, -0.4, 0.4, 0.0, 13.9, 0.15, 2)]
	obj(c, "Leaves", merge(*leaves), "Slate")
	ribs = [rbox(s0, s1, -0.6, -0.35, z, z + 0.5, 0.08, 1) for s0, s1 in ((-5.6, -0.5), (0.5, 5.6)) for z in (4.0, 7.0, 10.0, 12.6)]
	obj(c, "Ribs", merge(*ribs), "Metal")
	obj(c, "HazardBase", merge(rbox(-5.7, -0.4, -0.55, -0.35, 0.6, 2.4, 0.05, 1), rbox(0.4, 5.7, -0.55, -0.35, 0.6, 2.4, 0.05, 1)), "Dark")
	stripes = []
	for k in range(-6, 6):
		x0 = k * 1.0 + 0.1
		quad = [(x0, 0.7), (x0 + 0.5, 0.7), (x0 + 0.5 + 1.5, 2.3), (x0 + 1.5, 2.3)]
		if quad[0][0] < -5.6 or quad[2][0] > 5.6 or (quad[0][0] < 0.45 and quad[2][0] > -0.45):
			continue
		stripes.append(finish(prism(quad, "Y", -0.68, -0.5), 0.0, 1))
	obj(c, "Stripes", merge(*stripes), "Ochre")
	obj(c, "Lock", rbox(-1.2, 1.2, -0.95, -0.4, 6.2, 7.6, 0.2, 2), "Metal")
	obj(c, "Beacon", rbox(-0.9, 0.9, -1.4, -0.95, 15.0, 15.45, 0.15, 2), "GlowWarm")


# ---------------------------------------------------------------- Market

def p_market():
	c = piece("NicheFrame", opening=14, height=11)
	obj(c, "Frame", finish(prism(u_frame(14, 11, 1.4, 2.0, 2.6), "Y", -0.6, 0.9), 0.15, 2), "Metal")
	obj(c, "Back", rbox(-7.0, 7.0, 3.0, 3.4, -0.1, 11.0, 0.05, 1), "ConcreteLight")
	obj(c, "Sides", merge(rbox(-7.4, -7.0, 0.8, 3.4, -0.1, 11.0, 0.05, 1), rbox(7.0, 7.4, 0.8, 3.4, -0.1, 11.0, 0.05, 1)), "Concrete")
	obj(c, "Top", rbox(-7.4, 7.4, 0.8, 3.4, 11.0, 11.4, 0.05, 1), "Concrete")
	obj(c, "Sill", rbox(-6.8, 6.8, 0.2, 3.0, -0.1, 1.2, 0.15, 2), "ConcreteDark")
	obj(c, "Cove", rbox(-6.8, 6.8, 0.9, 1.15, 10.6, 10.85, 0.05, 1), "GlowWarm")
	c = piece("ShopCounter", width=15)
	obj(c, "Kick", finish(prism(rrect(13.4, 2.6, 0.8, 4), "Z", -0.1, 0.6), 0.0, 1), "Dark")
	obj(c, "Body", finish(prism(rrect(14.0, 3.2, 1.0, 4), "Z", 0.5, 3.4), 0.12, 2), "Metal")
	obj(c, "Panels", merge(*[rbox(x - 1.9, x + 1.9, -1.75, -1.55, 1.0, 2.9, 0.12, 2) for x in (-4.4, 0.0, 4.4)]), "ConcreteLight")
	obj(c, "Top", finish(prism(rrect(14.8, 4.0, 1.3, 4), "Z", 3.3, 3.75), 0.12, 2), "ConcreteLight")
	obj(c, "Glow", rbox(-6.6, 6.6, -1.85, -1.7, 3.0, 3.22, 0.04, 1), "GlowAccent")
	c = piece("ShopBackdrop", width=16)
	obj(c, "Frame", frame(16.0, 12.0, 0.8, 14.4, 10.4, 0.5, -0.4, 0.6, "Y", 6.0), "Metal")
	obj(c, "Back", rbox(-7.3, 7.3, 0.0, 0.5, 0.75, 11.25, 0.05, 1), "Slate")
	obj(c, "Shelves", merge(*[rbox(-7.0, 7.0, -1.2, 0.05, z, z + 0.3, 0.08, 1) for z in (3.4, 6.4, 9.2)]), "ConcreteLight")
	items = []
	for z in (3.7, 6.7):
		for x in (-5.4, -2.2, 1.0, 4.4):
			items.append(rbox(x - 1.0, x + 1.0, -1.0, -0.1, z, z + 1.7, 0.3, 2))
	obj(c, "Crates", merge(*items), "Ochre")
	obj(c, "Strip", rbox(-7.0, 7.0, -1.25, -1.05, 9.05, 9.3, 0.04, 1), "GlowWarm")
	c = piece("SeasonCrest", height=14)
	shield = [(-4.5, 4.0), (4.5, 4.0), (4.5, -1.0), (0.0, -6.0), (-4.5, -1.0)]
	sh = finish(prism([(x, z + 7.0) for x, z in shield][::-1], "Y", -0.5, 0.5), 0.35, 2)
	obj(c, "Shield", sh, "Metal")
	inner = [(-3.4, 3.1), (3.4, 3.1), (3.4, -0.6), (0.0, -4.5), (-3.4, -0.6)]
	obj(c, "Inner", finish(prism([(x, z + 7.0) for x, z in inner][::-1], "Y", -0.85, -0.4), 0.15, 2), "Slate")
	chev = [(-2.4, 6.2), (0.0, 8.0), (2.4, 6.2), (2.4, 5.0), (0.0, 6.8), (-2.4, 5.0)][::-1]
	st = finish(prism([(x, z + 1.3) for x, z in star(1.4, 0.6)][::-1], "Y", -1.15, -0.8), 0.06, 1)
	xform(st, T(0, 0, 8.9))
	obj(c, "Emblem", merge(finish(prism(chev, "Y", -1.15, -0.8), 0.06, 1), st), "GlowAccent")
	wing = [(4.4, 10.6), (9.6, 12.4), (8.4, 10.6), (10.4, 10.0), (8.8, 8.6), (9.8, 7.6), (7.6, 7.2), (4.4, 7.0)]
	wl = finish(prism(wing, "Y", -0.3, 0.3), 0.15, 2)
	wr = finish(prism([(-x, z) for x, z in wing][::-1], "Y", -0.3, 0.3), 0.15, 2)
	obj(c, "Wings", merge(wl, wr), "Ochre")
	obj(c, "Bracket", rbox(-2.0, 2.0, -0.3, 0.6, 0.0, 1.4, 0.2, 2), "ConcreteDark")


# ---------------------------------------------------------------- Armoury + Locker

def p_armoury():
	gap = math.degrees(math.asin(14.0 / 22.0)) + 1.0
	span = 360 - 2 * gap
	c = piece("RoomWall_R22", span=span, gap=gap)
	obj(c, "Plinth", lath([(21.4, -0.1), (21.4, 1.2), (21.7, 1.5), (22.0, 1.5)], 0.06, 0, span), "ConcreteDark")
	obj(c, "Wall", lath([(22.0, 1.5), (22.0, 2.1), (21.8, 2.1), (21.8, 19.0)], 0.04, 0, span), "Concrete")
	obj(c, "Cornice", lath([(21.8, 19.0), (21.2, 19.6), (21.2, 22.0)], 0.05, 0, span), "Metal")
	obj(c, "Gap", lath([(21.92, 1.55), (21.92, 2.05)], 0.0, 0, span), "GlowWarm")
	c = piece("RoomCeiling_R22")
	obj(c, "Soffit", lath([(22.4, 22.0), (17.0, 22.0), (17.0, 23.0), (8.0, 23.0), (8.0, 24.5), (0.0, 24.5)], 0.15), "ConcreteLight")
	obj(c, "Light", rcyl(7.7, 24.25, 24.4, 48, 0.0), "GlowWhite")
	c = piece("HeroPlinth")
	obj(c, "Body", lath([(5.6, -0.1), (5.6, 0.7), (5.2, 0.9), (4.6, 0.9), (4.6, 1.8), (4.3, 2.0), (3.8, 2.0), (3.8, 2.4), (0.0, 2.4)], 0.1), "ConcreteDark")
	obj(c, "Ring", annulus(4.7, 5.1, 0.85, 1.0, n=48, bev=0.02), "GlowAccent")
	c = piece("GunPedestal")
	obj(c, "Body", lath([(2.4, -0.1), (2.4, 0.5), (1.6, 0.9), (1.4, 3.0), (1.9, 3.2), (1.9, 3.5), (0.0, 3.5)], 0.08), "Metal")
	obj(c, "Ring", annulus(1.95, 2.15, 3.2, 3.4, n=32, bev=0.02), "GlowAccent")
	c = piece("LockerBackdrop", width=18)
	obj(c, "Frame", frame(18.0, 14.0, 1.4, 15.6, 11.6, 0.9, -0.5, 0.6, "Y", 7.0), "Metal")
	obj(c, "Panel", rbox(-7.9, 7.9, 0.0, 0.5, 1.1, 12.9, 0.05, 1), "Panel")
	obj(c, "Outline", frame(15.2, 11.2, 0.75, 14.6, 10.6, 0.5, -0.15, 0.05, "Y", 7.0, bev=0.03), "GlowAccent")
	c = piece("LockerPlatform", radius=4.2)
	obj(c, "Body", lath([(4.2, -0.1), (4.2, 0.55), (3.9, 0.8), (0.0, 0.8)], 0.08), "Slate")
	obj(c, "Ring", annulus(3.3, 3.6, 0.75, 0.88, n=48, bev=0.02), "GlowAccent")
	c = piece("LockerCabinet", width=4.4)
	obj(c, "Body", finish(prism(rrect(4.4, 2.6, 0.45, 4), "Z", -0.1, 10.0), 0.12, 2), "Metal")
	obj(c, "Doors", merge(rbox(-2.0, -0.08, -1.5, -1.25, 0.6, 9.4, 0.15, 2), rbox(0.08, 2.0, -1.5, -1.25, 0.6, 9.4, 0.15, 2)), "Slate")
	obj(c, "Vents", merge(*[rbox(s * 1.04 - 0.6, s * 1.04 + 0.6, -1.62, -1.45, z, z + 0.18, 0.05, 1) for s in (-1, 1) for z in (7.8, 8.2, 8.6)]), "Dark")
	obj(c, "Handles", merge(rbox(-0.5, -0.25, -1.8, -1.45, 4.2, 5.8, 0.08, 1), rbox(0.25, 0.5, -1.8, -1.45, 4.2, 5.8, 0.08, 1)), "Ochre")
	obj(c, "Top", finish(prism(rrect(4.8, 3.0, 0.6, 4), "Z", 9.9, 10.5), 0.15, 2), "ConcreteDark")
	obj(c, "Status", rbox(-1.0, 1.0, -1.42, -1.3, 9.55, 9.75, 0.04, 1), "GlowAccent")


# ---------------------------------------------------------------- Range room

def p_range():
	c = piece("ModelPlinth", width=20)
	obj(c, "Body", finish(prism(rrect(20.0, 14.0, 2.0, 5), "Z", -0.1, 2.0), 0.2, 2), "ConcreteDark")
	obj(c, "Top", finish(ring_prism(rrect(20.6, 14.6, 2.3, 5), rrect(18.6, 12.6, 1.5, 5), 1.9, 2.3), 0.08, 1), "Metal")
	obj(c, "Glow", ring_prism(rrect(18.6, 12.6, 1.5, 5), rrect(18.2, 12.2, 1.3, 5), 1.95, 2.18), "GlowBlue")
	obj(c, "Deck", prism(rrect(18.2, 12.2, 1.3, 5), "Z", 1.9, 2.05), "Grate")
	c = piece("CageCorner", height=12)
	obj(c, "Post", finish(prism(rrect(0.5, 0.5, 0.15, 2), "Z", 0.0, 12.0), 0.05, 1), "GlowBlue")
	c = piece("WallModule", width=8, height=22)
	obj(c, "Plinth", rbox(-4.0, 4.0, -0.9, 0.6, -0.1, 1.4, 0.2, 2), "ConcreteDark")
	obj(c, "Panel", rbox(-3.95, 3.95, -0.45, 0.6, 1.2, 19.6, 0.12, 2), "Concrete")
	obj(c, "Seam", rbox(-4.0, 4.0, -0.6, -0.3, 8.8, 9.2, 0.08, 1), "Metal")
	obj(c, "Cornice", rbox(-4.0, 4.0, -1.0, 0.6, 19.5, 22.0, 0.25, 2), "Metal")
	obj(c, "Cove", rbox(-3.9, 3.9, -0.62, -0.47, 1.5, 1.72, 0.04, 1), "GlowWarm")


# ---------------------------------------------------------------- signs (neon-outline sign boxes)

def icon(kind, s):
	# Neon icon polygons centred at 0, about s tall, lying in XZ (front -Y), returned as bmesh at y -0.72..-0.42.
	def P(pts, y0=-0.72, y1=-0.42):
		return finish(prism([(x * s, z * s) for x, z in pts], "Y", y0, y1), 0.03, 1)
	if kind == "target":
		parts = [annulus(0.42 * s, 0.5 * s, -0.72, -0.42, n=40, bev=0.02), annulus(0.22 * s, 0.3 * s, -0.72, -0.42, n=32, bev=0.02),
			rcyl(0.08 * s, -0.72, -0.42, 16, 0.02)]
		for b in parts:
			xform(b, RX(90))
			xform(b, T(0, -1.14, 0))
		for k in range(4):
			t = P([(-0.035, 0.36), (0.035, 0.36), (0.035, 0.62), (-0.035, 0.62)], -0.66, -0.48)
			xform(t, RZ(0) @ Matrix.Rotation(math.radians(90 * k), 4, "Y"))
			parts.append(t)
		return merge(*parts)
	if kind == "star":
		return P([(x * 0.55, z * 0.55) for x, z in star(1.0, 0.45)][::-1])
	if kind == "bag":
		body = P([(-0.4, -0.45), (0.4, -0.45), (0.45, 0.2), (-0.45, 0.2)])
		handle = P([(-0.25, 0.2), (-0.25, 0.4), (-0.15, 0.5), (0.15, 0.5), (0.25, 0.4), (0.25, 0.2), (0.17, 0.2), (0.17, 0.37), (0.12, 0.42), (-0.12, 0.42), (-0.17, 0.37), (-0.17, 0.2)][::-1])
		return merge(body, handle)
	if kind == "rifle":
		pts = [(-0.8, -0.15), (-0.8, 0.15), (-0.45, 0.12), (-0.3, 0.2), (0.4, 0.2), (0.45, 0.1), (0.85, 0.1), (0.85, 0.02), (0.45, 0.02), (0.3, -0.06),
			(0.15, -0.06), (0.18, -0.28), (0.06, -0.28), (0.0, -0.06), (-0.18, -0.06), (-0.25, -0.32), (-0.38, -0.32), (-0.35, -0.06), (-0.5, -0.06)]
		return P(pts[::-1])
	if kind == "arrows":
		a = P([(-0.6, 0.0), (-0.15, 0.35), (-0.15, 0.18), (-0.38, 0.0), (-0.15, -0.18), (-0.15, -0.35)])
		b = P([(0.6, 0.0), (0.15, -0.35), (0.15, -0.18), (0.38, 0.0), (0.15, 0.18), (0.15, 0.35)])
		return merge(a, b)
	if kind == "hanger":
		return P([(-0.6, -0.25), (0.6, -0.25), (0.05, 0.15), (0.05, 0.3), (0.15, 0.4), (0.0, 0.5), (-0.12, 0.42), (-0.05, 0.38), (0.0, 0.42), (0.04, 0.38), (-0.05, 0.3),
			(-0.05, 0.12), (-0.48, -0.17), (-0.6, -0.17)][::-1])
	return None


def p_signs():
	for key, label, ico in (("DUELS", "DUELS", "arrows"), ("SHOP", "SHOP", "bag"), ("BATTLEPASS", "BATTLE PASS", "star"), ("EVENT", "EVENT", "star"),
			("ARMOURY", "ARMOURY", "rifle"), ("LOCKER", "LOCKER", "hanger"), ("RANGE", "RANGE", "target")):
		H = 2.4
		t, w = text_mesh(label, H, 0.5, spacing=1.08)
		iw = 2.6 if ico else 0.0
		W = w + iw + 3.2
		c = piece("Sign_" + key, text=label, width=round(W, 2), height=4.8)
		xform(t, T(iw / 2, -0.38, -H / 2))
		obj(c, "Text", t, "White", smooth=0)
		obj(c, "Plate", finish(prism(rrect(W, 4.8, 1.2, 5), "Y", -0.3, 0.5), 0.0, 1), "Slate")
		obj(c, "Rim", finish(ring_prism(rrect(W + 0.9, 5.7, 1.6, 5), rrect(W, 4.8, 1.2, 5), -0.5, 0.6, "Y"), 0.12, 2), "Metal")
		obj(c, "Tube", ring_prism(rrect(W - 0.7, 4.1, 0.85, 5), rrect(W - 1.15, 3.65, 0.62, 5), -0.62, -0.42, "Y"), "GlowAccent")
		if ico:
			ic = icon(ico, 2.2)
			xform(ic, T(-w / 2 - 0.2, 0, 0))
			obj(c, "Icon", ic, "GlowAccent")


# ---------------------------------------------------------------- build

def p_dressing():
	# Set dressing in the kit style (core review 2026-11-05: "too empty"): cases, vents, cable trays, racks, glass cases,
	# benches, barriers. Busy edges, clear walking paths.
	for name, L, W, H in (("HardCase_S", 4.0, 2.4, 2.0), ("HardCase_L", 6.0, 3.0, 3.0)):
		c = piece(name)
		obj(c, "Body", rbox(-L / 2, L / 2, -W / 2, W / 2, -0.1, H, 0.3), "Slate")
		obj(c, "Seam", rbox(-L / 2 - 0.06, L / 2 + 0.06, -W / 2 - 0.06, W / 2 + 0.06, H * 0.55, H * 0.55 + 0.22, 0.06, 1), "Dark")
		obj(c, "Ribs", merge(*[rbox(x - 0.15, x + 0.15, -W / 2 - 0.12, W / 2 + 0.12, 0.25, H - 0.25, 0.06, 1) for x in (-L * 0.32, L * 0.32)]), "Metal")
		obj(c, "Latches", merge(*[rbox(x - 0.3, x + 0.3, -W / 2 - 0.22, -W / 2 + 0.05, H * 0.45, H * 0.75, 0.06, 1) for x in (-L * 0.18, L * 0.18)]), "Ochre")
		obj(c, "Handle", rbox(-0.7, 0.7, -0.15, 0.15, H - 0.05, H + 0.3, 0.1, 1), "Dark")
	c = piece("WallVent")
	obj(c, "Frame", frame(4.0, 3.0, 0.45, 3.3, 2.3, 0.25, -0.3, 0.05, "Y", 1.5), "Metal")
	obj(c, "Grille", rbox(-1.7, 1.7, -0.05, 0.1, 0.3, 2.7, 0.03, 1), "Grate")
	c = piece("CableTray_16")
	obj(c, "Tray", merge(rbox(-8, 8, -1.3, 0.0, 0.0, 0.18, 0.05, 1), rbox(-8, 8, -1.3, -1.12, 0.1, 0.7, 0.05, 1)), "Metal")
	cables = []
	for k, (y, r) in enumerate(((-0.35, 0.18), (-0.72, 0.2))):
		cables.append(finish(prism([(y + r * math.cos(a * math.pi / 4), 0.18 + r + r * math.sin(a * math.pi / 4)) for a in range(8)], "X", -7.98, 7.98), 0.0, 1))
	obj(c, "Cables", merge(*cables), "Dark")
	obj(c, "Cable2", finish(prism([(-0.98 + 0.13 * math.cos(a * math.pi / 4), 0.31 + 0.13 * math.sin(a * math.pi / 4)) for a in range(8)], "X", -7.98, 7.98), 0.0, 1), "Ochre")
	obj(c, "Brackets", merge(*[rbox(x - 0.2, x + 0.2, -0.3, 0.05, -0.7, 0.05, 0.05, 1) for x in (-6, 0, 6)]), "Dark")
	c = piece("WeaponRack", width=8)
	obj(c, "Board", rbox(-4, 4, -0.35, 0.05, 0.0, 6.0, 0.2, 2), "Slate")
	obj(c, "Rails", merge(*[rbox(-3.7, 3.7, -0.7, -0.3, z, z + 0.25, 0.06, 1) for z in (1.4, 3.2, 5.0)]), "Metal")
	obj(c, "Strip", rbox(-3.6, 3.6, -0.5, -0.33, 5.65, 5.8, 0.03, 1), "GlowAccent")
	c = piece("GlassCase")
	obj(c, "Base", rbox(-1.5, 1.5, -1.5, 1.5, -0.1, 3.0, 0.2, 2), "Metal")
	obj(c, "Glass", rbox(-1.28, 1.28, -1.28, 1.28, 3.0, 5.4, 0.05, 1), "Glass")
	obj(c, "Posts", merge(*[rbox(sx * 1.3 - 0.09, sx * 1.3 + 0.09, sy * 1.3 - 0.09, sy * 1.3 + 0.09, 2.95, 5.45, 0.03, 1) for sx in (-1, 1) for sy in (-1, 1)]), "Metal")
	obj(c, "Cap", rbox(-1.5, 1.5, -1.5, 1.5, 5.4, 5.75, 0.12, 2), "Metal")
	obj(c, "Light", rbox(-1.0, 1.0, -1.0, 1.0, 5.18, 5.32, 0.03, 1), "GlowWhite")
	obj(c, "Band", rbox(-1.2, 1.2, -1.58, -1.5, 1.2, 1.5, 0.03, 1), "GlowAccent")
	c = piece("BunkerBench", length=6)
	obj(c, "Frame", merge(rbox(-2.8, -2.3, -0.8, 0.8, -0.1, 1.5, 0.12, 1), rbox(2.3, 2.8, -0.8, 0.8, -0.1, 1.5, 0.12, 1), rbox(-2.6, 2.6, -0.15, 0.15, 0.5, 0.8, 0.08, 1)), "Metal")
	obj(c, "Seat", rbox(-3.0, 3.0, -0.95, 0.95, 1.45, 2.05, 0.28, 2), "Slate")
	c = piece("Barrier", length=6)
	obj(c, "Body", finish(prism([(-0.8, -0.1), (0.8, -0.1), (0.45, 2.2), (-0.45, 2.2)], "X", -3, 3), 0.15, 2), "ConcreteDark")
	stripes = [finish(prism([(x0, 1.0), (x0 + 0.5, 1.0), (x0 + 1.1, 1.7), (x0 + 0.6, 1.7)], "Y", -0.72, -0.62), 0.0, 1) for x0 in (-2.4, -1.4, -0.4, 0.6, 1.6)]
	obj(c, "Stripes", merge(*stripes), "Ochre")
	c = piece("LockerAlcove", radius=6.6)
	obj(c, "Shell", lath([(6.6, -0.1), (6.6, 11.6), (6.1, 12.5), (4.8, 13.2), (0.0, 13.2)], 0.2, -70, 70), "Slate")
	obj(c, "CoveLow", lath([(6.6, 0.45), (6.48, 0.45), (6.48, 0.75)], 0.0, -66, 66), "GlowAccent")
	obj(c, "CoveTop", lath([(6.08, 12.25), (5.98, 12.25), (5.98, 12.45)], 0.0, -66, 66), "GlowAccent")
	fins = []
	for b in (-70, 70):
		f = rbox(-0.35, 0.35, 6.3, 8.2, -0.1, 13.6, 0.2, 2)
		xform(f, RZ(-b))
		fins.append(f)
	obj(c, "Fins", merge(*fins), "Metal")


def build():
	for o in list(bpy.data.objects):
		bpy.data.objects.remove(o)
	materials()
	global KIT
	KIT = collection("Kit_Bunker2")
	for f in (p_pier, p_drum, p_dome, p_dais, p_floor_ring, p_guide, p_ring, p_portals, lambda: steps(40, 3, "Steps_40_3"),
			lambda: steps(24, 2, "Steps_24_2"), lambda: steps(24, 3, "Steps_24_3"), p_hall, p_pads, p_blastdoor, p_market, p_armoury, p_range, p_signs, p_dressing):
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


def render_sheet(names, out, cam_loc, cam_rot, lens=35):
	os.makedirs(RENDER_DIR, exist_ok=True)
	sc = bpy.context.scene
	stage = collection("_Sheet")
	x = 0.0
	for n in names:
		c = PIECES[n]
		pts = [Vector(b) for o in c.all_objects for b in o.bound_box]
		mnx, mxx = min(p.x for p in pts), max(p.x for p in pts)
		e = bpy.data.objects.new("I_" + n, None)
		e.instance_type = "COLLECTION"
		e.instance_collection = c
		e.location = (x - mnx, 0, 0)
		stage.objects.link(e)
		x += (mxx - mnx) + 3
	gm = bpy.data.meshes.new("G")
	bmg = bmesh.new()
	bmesh.ops.create_grid(bmg, x_segments=1, y_segments=1, size=300)
	bmg.to_mesh(gm)
	g = bpy.data.objects.new("G", gm)
	g.data.materials.append(M["Floor"])
	stage.objects.link(g)
	sun = bpy.data.lights.new("Sun", "SUN")
	sun.energy = 3.0
	sun.color = (1.0, 0.92, 0.82)
	so = bpy.data.objects.new("Sun", sun)
	so.rotation_euler = (math.radians(55), 0, math.radians(-35))
	stage.objects.link(so)
	sc.world = sc.world or bpy.data.worlds.new("W")
	sc.world.use_nodes = True
	sc.world.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.4, 0.5, 1)
	sc.world.node_tree.nodes["Background"].inputs[1].default_value = 0.6
	cam = bpy.data.cameras.new("Cam")
	cam.lens = lens
	co = bpy.data.objects.new("Cam", cam)
	co.location = (cam_loc[0] if cam_loc[0] is not None else x / 2, cam_loc[1], cam_loc[2])
	co.rotation_euler = tuple(math.radians(a) for a in cam_rot)
	stage.objects.link(co)
	sc.camera = co
	sc.render.engine = "BLENDER_EEVEE"
	sc.render.resolution_x, sc.render.resolution_y = 1600, 800
	sc.view_settings.view_transform = "AgX"
	sc.render.image_settings.file_format = "JPEG"
	sc.render.filepath = os.path.join(RENDER_DIR, out)
	bpy.ops.render.render(write_still=True)
	bpy.data.collections.remove(stage)


if __name__ == "__main__":
	args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	tris = build()
	print("KIT_BUNKER2", sum(tris.values()), tris)
	if "--render" in args:
		render_sheet(["Pier", "Portal_28", "Sign_DUELS", "DuelPad_14", "PadScreen", "ModeTab_1V1", "Buttress", "HallBay", "BlastDoor"], "bunker2-sheet-a.jpg", (None, -48, 14), (82, 0, 0), 24)
		render_sheet(["NicheFrame", "ShopCounter", "ShopBackdrop", "SeasonCrest", "LockerBackdrop", "LockerCabinet", "LockerPlatform", "HeroPlinth", "GunPedestal", "Sign_RANGE", "Sign_ARMOURY"], "bunker2-sheet-b.jpg", (None, -55, 14), (82, 0, 0), 22)
		print("RENDERED")
