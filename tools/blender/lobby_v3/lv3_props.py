"""Lobby V3 props, signs and the hub centrepiece. Real objects built from the same builder as the shell.
Every wing gets its own sign type: Duels = big cream letters with chevrons on the blast gate, Shop = brass letters
on the stone arch and round the shop apse, Locker = steel letters set into the vault collar, Range = stencil-style
white letters with a target roundel, Gauntlet = steel letters over the sealed gate."""
import glob
import os
from math import sin, cos, pi, radians, sqrt, atan2
import bpy
import bmesh
from mathutils import Vector, Matrix
import lv3_core as C
import lv3_hub as H

D = radians
_FONTS = {}


def font(name):
	if name not in _FONTS:
		hits = sorted(glob.glob(os.path.join(os.environ.get("LOCALAPPDATA", ""), "Roblox", "Versions", "*", "content", "fonts", name)))
		_FONTS[name] = bpy.data.fonts.load(hits[-1], check_existing=True)
	return _FONTS[name]


def mats():
	S = C.surface
	S("SignCream", "#E6E1D4", 0.5, var=0.04, bump=0.03, ao=0.3)
	S("CaseOlive", "#4E5B45", 0.6, var=0.08, bump=0.15, ao=0.5)
	S("CaseSand", "#9A8A66", 0.6, var=0.08, bump=0.15, ao=0.5)
	S("CaseDark", "#2E3338", 0.55, var=0.06, bump=0.12, ao=0.5)
	S("Sack", "#8C7B5A", 0.95, var=0.12, bump=0.5, grain=2.5, ao=0.6)
	S("ClothRed", "#B23A2E", 0.9, var=0.08, bump=0.35, grain=4.0, ao=0.4)
	S("ClothBlue", "#2F5F86", 0.9, var=0.08, bump=0.35, grain=4.0, ao=0.4)
	S("ClothGold", "#C79A3A", 0.9, var=0.08, bump=0.35, grain=4.0, ao=0.4)
	S("Leaf", "#3F7A45", 0.6, var=0.15, bump=0.1, ao=0.4)
	S("Pot", "#A65F3E", 0.8, var=0.1, bump=0.2, ao=0.5)
	S("BottleG", "#2F5D3A", 0.15, var=0.05, bump=0.0, ao=0.2)
	S("BottleA", "#9A5A1E", 0.15, var=0.05, bump=0.0, ao=0.2)
	S("Crate", "#8A6B45", 0.75, var=0.12, bump=0.35, grain=3.0, ao=0.6)
	C.BEVEL.update({"SignCream": 0.0, "HazardBlack": 0.0, "CaseOlive": 0.12, "CaseSand": 0.12, "CaseDark": 0.12, "Sack": 0.26,
		"ClothRed": 0.0, "ClothBlue": 0.0, "ClothGold": 0.0, "Leaf": 0.0, "Pot": 0.06, "BottleG": 0.0, "BottleA": 0.0, "Crate": 0.06})
	S("SignPlate", "#15181D", 0.5, var=0.03, bump=0.0, ao=0.2)
	S("SignFace", "#EFE8D8", 0.5, var=0.03, bump=0.0, ao=0.2)
	C.BEVEL["SignFace"] = 0.0
	C.NO_COLLIDE.add("SignFace")
	S("GGold", "#EDB23A", 0.35, metal=0.6, var=0.04, bump=0.03, ao=0.35)
	S("GSteel", "#6F8296", 0.4, metal=0.6, var=0.04, bump=0.03, ao=0.35)
	S("GDark", "#2A313A", 0.6, var=0.04, bump=0.03, ao=0.3)
	S("BenchBase", "#3A4654", 0.6, var=0.04, bump=0.03, ao=0.4)
	S("BenchPad", "#3F86B5", 0.7, var=0.05, bump=0.08, ao=0.4)
	for nm, colr in (("N_Duels", "#FF6A3D"), ("N_Market", "#FFC233"), ("N_Vault", "#45DCFF"), ("N_Range", "#5CFF8A"), ("N_White", "#FFF1DC"), ("E_Trophy", "#FFC65A")):
		C.emission(nm, colr, 9.0)
		C.BEVEL[nm] = 0.0
		C.NO_COLLIDE.add(nm)
	C.BEVEL.update({"SignPlate": 0.1, "GGold": 0.3, "GSteel": 0.14, "GDark": 0.12, "BenchBase": 0.25, "BenchPad": 0.22,
		"CaseOlive": 0.2, "CaseSand": 0.2, "CaseDark": 0.2})
	C.NO_COLLIDE.add("SignPlate")
	C.NO_COLLIDE.update({"HazardBlack", "SignCream", "ClothRed", "ClothBlue", "ClothGold", "Leaf", "BottleG", "BottleA"})


# ---------------------------------------------------------------- text
def _tb(K, matname):
	key = "T:" + matname
	if key not in K.b:
		b = C.B(f"{K.prefix}_Text_{matname}", K.col, C.mat(matname), K.rot, bevel=0.0)
		b.collide = False
		K.b[key] = b
	return K.b[key].reset()


def text(K, matname, body, fnt, h, depth, origin, right, up, spacing=1.0, offset=0.0, outline=0.0, shear=0.0):
	"""Solid letters. origin = centre of the text on its backing surface; letters stand `depth` proud of it."""
	b = _tb(K, matname)
	cu = bpy.data.curves.new("_t", "FONT")
	cu.body = body
	cu.font = font(fnt)
	cu.size = h / 0.72
	cu.extrude = depth / 2
	cu.resolution_u = 3
	cu.align_x = "CENTER"
	cu.space_character = spacing
	cu.offset = offset
	cu.shear = shear
	if outline > 0:  # neon tube letters: the outline only, as round tubes
		cu.fill_mode = "NONE"
		cu.extrude = 0.0
		cu.bevel_depth = outline
		cu.bevel_resolution = 1
	ob = bpy.data.objects.new("_t", cu)
	bpy.context.scene.collection.objects.link(ob)
	bpy.context.view_layer.update()
	me = bpy.data.meshes.new_from_object(ob.evaluated_get(bpy.context.evaluated_depsgraph_get()))
	r, u = Vector(right).normalized(), Vector(up).normalized()
	n = r.cross(u)
	R = Matrix((r, u, n)).transposed().to_4x4()
	T = Matrix.Translation(Vector(origin)) @ R @ Matrix.Translation((0, -h / 2, depth if outline > 0 else depth / 2))
	tmp = bmesh.new()  # weld each letter into a closed solid before it joins the builder
	tmp.from_mesh(me)
	bmesh.ops.transform(tmp, matrix=b.M @ T, verts=tmp.verts[:])
	bmesh.ops.remove_doubles(tmp, verts=tmp.verts[:], dist=0.0005)
	tmp.to_mesh(me)
	tmp.free()
	b.bm.from_mesh(me)
	bpy.data.objects.remove(ob, do_unlink=True)
	bpy.data.curves.remove(cu)
	bpy.data.meshes.remove(me)


def sign(K, body, fnt, h, origin, right, up, face="SignCream", back="Steel", spacing=1.0, d_back=0.2, d_face=0.14):
	"""Channel-style letters: a dark, slightly larger back layer with a bright face on top."""
	n = Vector(right).normalized().cross(Vector(up).normalized())
	text(K, back, body, fnt, h, d_back, origin, right, up, spacing, offset=0.035 * h)
	text(K, face, body, fnt, h, d_face, Vector(origin) + n * d_back, right, up, spacing)


def sign_lamp(K, x, zt):
	"""Small hooded lamp on an arm above a gate sign (gate frame: the face is at y = H.GF)."""
	K["Steel"].pipe((x, H.GF, zt + 0.5), (x, H.GF - 1.5, zt + 0.5), 0.09, 8)
	K["Steel"].box(x - 0.95, x + 0.95, H.GF - 2.05, H.GF - 1.1, zt + 0.3, zt + 0.62)
	K["E_Warm"].box(x - 0.8, x + 0.8, H.GF - 1.95, H.GF - 1.2, zt + 0.24, zt + 0.3)


def arc_text(K, matname, body, fnt, h, depth, centre, r, mid, U, V, step=None, wall=False, offset=0.0):
	"""One letter at a time round an arc in the plane (U, V). wall=False: letters point outward (collars, floors).
	wall=True: letters stand upright on the inside of a round wall whose axis is U x V."""
	U, V = Vector(U), Vector(V)
	W = U.cross(V)
	step = step or (h * 1.02) / r
	n = len(body)
	for i, ch in enumerate(body):
		if ch == " ":
			continue
		a = mid + (n - 1) / 2 * step - i * step
		rad = U * cos(a) + V * sin(a)
		tan = U * sin(a) - V * cos(a)
		if wall:
			text(K, matname, ch, fnt, h, depth, Vector(centre) + rad * r, tan, W, 1.0, offset)
		else:
			text(K, matname, ch, fnt, h, depth, Vector(centre) + rad * r, tan, rad, 1.0, offset)


# ---------------------------------------------------------------- objects (base at the frame origin)
def bench(K, x, y, z, ang, length=7.0, legs="ConcreteDark", slats="OakDark"):
	hl = length / 2
	for sx in (-1, 1):
		K[legs].frame(ang, x, y, z).taper((sx * (hl - 0.9) - 0.3, sx * (hl - 0.9) + 0.3, -0.85, 0.85), 0, (sx * (hl - 0.9) - 0.24, sx * (hl - 0.9) + 0.24, -0.75, 0.75), 1.45)
	K["Steel"].frame(ang, x, y, z).box(-hl + 0.9, hl - 0.9, -0.12, 0.12, 0.55, 0.8)
	for k in range(4):
		y0 = -0.82 + k * 0.43
		K[slats].frame(ang, x, y, z).box(-hl, hl, y0, y0 + 0.36, 1.45, 1.63)


def case(K, x, y, z, ang, w=3.0, d=2.0, h=1.5, m="CaseOlive"):
	b = K[m].frame(ang, x, y, z)
	b.box(-w / 2, w / 2, -d / 2, d / 2, 0.08, h)
	K["CaseDark"].frame(ang, x, y, z).box(-w / 2 - 0.05, w / 2 + 0.05, -d / 2 - 0.05, d / 2 + 0.05, h * 0.62, h * 0.62 + 0.14)  # lid seam
	for sx in (-1, 1):
		for sy in (-1, 1):
			K["CaseDark"].frame(ang, x, y, z).box(sx * w / 2 - 0.16, sx * w / 2 + 0.16, sy * d / 2 - 0.16, sy * d / 2 + 0.16, 0, h + 0.05)
		K["Brushed"].frame(ang, x, y, z).box(sx * w * 0.28 - 0.18, sx * w * 0.28 + 0.18, -d / 2 - 0.1, -d / 2, h * 0.5, h * 0.8)  # latches
	K["CaseDark"].frame(ang, x, y, z).box(-0.5, 0.5, -d / 2 - 0.22, -d / 2, h * 0.3, h * 0.42)  # handle


def crate(K, x, y, z, ang, s=2.0, h=None):
	h = h or s
	a = s / 2
	K["Crate"].frame(ang, x, y, z).box(-a + 0.08, a - 0.08, -a + 0.08, a - 0.08, 0.05, h - 0.05)
	c = K["OakDark"].frame(ang, x, y, z)
	for sx in (-1, 1):
		for sy in (-1, 1):
			c.box(sx * a - 0.14 * (sx > 0), sx * a + 0.14 * (sx < 0), sy * a - 0.14 * (sy > 0), sy * a + 0.14 * (sy < 0), 0.24, h - 0.24)
	for z0 in (0.0, h - 0.24):
		c.box(-a, a, -a, -a + 0.14, z0, z0 + 0.24)
		c.box(-a, a, a - 0.14, a, z0, z0 + 0.24)
		c.box(-a, -a + 0.14, -a, a, z0, z0 + 0.24)
		c.box(a - 0.14, a, -a, a, z0, z0 + 0.24)


def barrel(K, x, y, z):
	b = K["Crate"].frame(0, x, y, z)
	b.lathe([(0.05, 0), (0.95, 0), (1.12, 0.7), (1.18, 1.4), (1.12, 2.1), (0.95, 2.8), (0.05, 2.8)], n=14)
	for zz, r in ((0.45, 1.07), (1.4, 1.19), (2.35, 1.07)):
		K["Steel"].frame(0, x, y, z).ring(r - 0.04, r + 0.05, zz - 0.11, zz + 0.11, n=14)


def bottle(K, x, y, z, m="BottleG", s=1.0):
	K[m].frame(0, x, y, z).lathe([(0.02, 0), (0.2 * s, 0), (0.2 * s, 0.5 * s), (0.08 * s, 0.72 * s), (0.08 * s, 0.95 * s), (0.02, 0.95 * s)], n=8)


def plant(K, x, y, z, s=1.0):
	K["Pot"].frame(0, x, y, z).lathe([(0.05, 0), (0.75 * s, 0), (0.95 * s, 1.3 * s), (0.8 * s, 1.3 * s), (0.7 * s, 1.1 * s), (0.05, 1.1 * s)], n=12)
	for k in range(7):
		a = D(51 * k + 9)
		lean = 0.18 + 0.1 * (k % 3)
		hh = (2.6 + 0.5 * (k % 3)) * s
		r0 = 0.28 * s
		px, py = r0 * cos(a), r0 * sin(a)
		tx, ty = px + lean * hh * cos(a), py + lean * hh * sin(a)
		w = 0.3 * s
		nx, ny = -sin(a) * w, cos(a) * w
		K["Leaf"].frame(0, x, y, z).solid(
			[(px - nx, py - ny, 1.1 * s), (px + nx, py + ny, 1.1 * s), (px + nx * 1.2 + cos(a) * 0.06, py + ny * 1.2 + sin(a) * 0.06, 1.1 * s)],
			[(tx - nx * 0.15, ty - ny * 0.15, 1.1 * s + hh), (tx + nx * 0.15, ty + ny * 0.15, 1.1 * s + hh), (tx + cos(a) * 0.04, ty + sin(a) * 0.04, 1.1 * s + hh)])


def sandbags(K, x, y, z, ang, n=4):
	row = 0
	while n > 0:
		for i in range(n):
			xx = (i - (n - 1) / 2) * 2.25
			K["Sack"].frame(ang, x, y, z).box(xx - 1.08, xx + 1.08, -0.55, 0.55, row * 0.62, row * 0.62 + 0.66)
		n -= 1
		row += 1


def trophy(K, x, y, z):
	b = K["Brass"].frame(0, x, y, z)
	b.lathe([(0.05, 0), (0.9, 0), (0.9, 0.25), (0.35, 0.5), (0.22, 1.3), (0.5, 1.55), (1.15, 2.6), (1.25, 3.3), (1.05, 3.3), (0.95, 2.7), (0.35, 1.75), (0.05, 1.75)], n=20)
	for sx in (-1, 1):
		pts = [(sx * 1.1, 0, 3.0), (sx * 1.75, 0, 2.9), (sx * 1.8, 0, 2.3), (sx * 1.0, 0, 1.95)]
		for p, q in zip(pts, pts[1:]):
			b.pipe(p, q, 0.11, 8)


def banner(K, x, y, ztop, nx, w=5.0, h=9.0, cloth="ClothRed"):
	"""Hangs flat against a wall whose face looks along (nx, 0, 0)."""
	K["Steel"].pipe((x + nx * 0.25, y - w / 2 - 0.5, ztop), (x + nx * 0.25, y + w / 2 + 0.5, ztop), 0.14, 8)
	for sy in (-1, 1):
		K["Steel"].box(min(x, x + nx * 0.3), max(x, x + nx * 0.3), y + sy * (w / 2 + 0.3) - 0.1, y + sy * (w / 2 + 0.3) + 0.1, ztop - 0.12, ztop + 0.12)
	x0, x1 = sorted((x + nx * 0.17, x + nx * 0.29))
	K[cloth].ext_x([(y - w / 2, ztop + 0.1), (y + w / 2, ztop + 0.1), (y + w / 2, ztop - h), (y, ztop - h + 1.3), (y - w / 2, ztop - h)], x0, x1)
	xa, xb = sorted((x + nx * 0.29, x + nx * 0.34))
	zc = ztop - h * 0.4
	K["SignCream"].ext_x([(y - 1.3, zc - 0.22), (y + 1.3, zc - 0.22), (y + 1.3, zc + 0.22), (y - 1.3, zc + 0.22)], xa, xb)
	K["SignCream"].ext_x([(y - 0.22, zc - 1.3), (y + 0.22, zc - 1.3), (y + 0.22, zc - 0.24), (y - 0.22, zc - 0.24)], xa, xb)
	K["SignCream"].ext_x([(y - 0.22, zc + 0.24), (y + 0.22, zc + 0.24), (y + 0.22, zc + 1.3), (y - 0.22, zc + 1.3)], xa, xb)


ANIM = {}  # group name -> {"pivot": (x, y, z) in world Blender coords, "spin": deg/s, "bob": (amp, hz)}


def anim_kit(col, rot, name, pivot_local, spin, bob=None):
	"""A kit whose objects become one spinning Model in Studio (existing LobbySpin ambience tag). No colliders."""
	K = C.Kit(col, rot, prefix=name)
	K.nocol = True
	px, py = pivot_local[0] * cos(rot) - pivot_local[1] * sin(rot), pivot_local[0] * sin(rot) + pivot_local[1] * cos(rot)
	ANIM[name] = {"pivot": (round(px, 3), round(py, 3), pivot_local[2]), "spin": spin, "bob": bob}
	return K


def no_collide(K):
	for b in K.b.values():
		b.collide = False


def rifle(K, x0, x1, yc, zc, skin, s=1.0, flip=1):
	"""Rifle silhouette on a wall display: layered plates in the (y, z) plane, extruded from x0 to x1 (x1 is the front)."""
	f = lambda pts: [(yc + flip * a * s, zc + b * s) for a, b in pts]
	xm = x0 + (x1 - x0) * 0.55
	K["Steel"].ext_x(f([(-0.4, 0.05), (3.4, 0.05), (3.4, 0.32), (-0.4, 0.32)]), x0, xm)  # barrel
	K[skin].ext_x(f([(-1.6, -0.25), (1.2, -0.25), (1.2, 0.5), (-1.6, 0.5)]), x0, x1)  # receiver
	K[skin].ext_x(f([(1.2, -0.12), (2.6, -0.12), (2.6, 0.42), (1.2, 0.42)]), x0, x1)  # handguard
	K["Steel"].ext_x(f([(-3.3, -0.55), (-1.6, -0.2), (-1.6, 0.45), (-2.2, 0.45), (-3.3, 0.1)]), x0, xm)  # stock
	K["Steel"].ext_x(f([(-1.2, -0.25), (-0.6, -0.25), (-0.95, -1.15), (-1.5, -1.05)]), x0, xm)  # grip
	K["Steel"].ext_x(f([(-0.2, -0.25), (0.55, -0.25), (0.85, -1.35), (0.15, -1.45)]), x0, xm)  # magazine
	K["Steel"].ext_x(f([(-0.6, 0.5), (0.5, 0.5), (0.5, 0.78), (-0.6, 0.78)]), x0, xm)  # sight


def pistol(K, x0, x1, yc, zc, skin, s=1.0):
	f = lambda pts: [(yc + a * s, zc + b * s) for a, b in pts]
	xm = x0 + (x1 - x0) * 0.55
	K[skin].ext_x(f([(-0.9, 0.0), (1.1, 0.0), (1.1, 0.5), (-0.9, 0.5)]), x0, x1)
	K["Steel"].ext_x(f([(-0.85, 0.0), (-0.2, 0.0), (-0.45, -1.0), (-1.1, -0.9)]), x0, xm)
	K["Steel"].ext_x(f([(-0.15, 0.0), (0.25, 0.0), (0.25, -0.3), (-0.15, -0.3)]), x0, xm)


def rarity_case(K, x, y, z, ang, band, w=2.2, d=1.5, h=1.0):
	K["CaseDark"].frame(ang, x, y, z).box(-w / 2, w / 2, -d / 2, d / 2, 0, h)
	K[band].frame(ang, x, y, z).box(-w / 2 - 0.04, w / 2 + 0.04, -d / 2 - 0.04, d / 2 + 0.04, h * 0.38, h * 0.62)
	K["Brushed"].frame(ang, x, y, z).box(-0.22, 0.22, -d / 2 - 0.1, -d / 2, h * 0.3, h * 0.7)
	K["Brushed"].frame(ang, x, y, z).box(-0.22, 0.22, d / 2, d / 2 + 0.1, h * 0.3, h * 0.7)


# ---------------------------------------------------------------- areas
def tube(b, pts, r, w=None):
	"""Neon tube along a 2D polyline in the builder's current frame, standing w proud of the plate."""
	w = 0.41 + r if w is None else w  # sits on the plate front (0.42)
	for (u0, v0), (u1, v1) in zip(pts, pts[1:]):
		d = Vector((u1 - u0, v1 - v0))
		if d.length < 1e-6:
			continue
		e = d.normalized() * r * 0.6
		b.pipe((u0 - e.x, v0 - e.y, w), (u1 + e.x, v1 + e.y, w), r, 8)


def arc(cu, cv, r, a0, a1, n=14):
	return [(cu + r * cos(a0 + (a1 - a0) * k / n), cv + r * sin(a0 + (a1 - a0) * k / n)) for k in range(n + 1)]


def neon_sign(K, wing, label, plates, zc, y_face, text_u, h, shear=0.22, spacing=1.1, strokes=(), icon=()):
	"""Gate sign: coloured rim, dark shaped plate, slanted outlined tube letters in the wing colour, white icon tubes.
	plates = list of CCW outlines in sign coordinates (u right, v up); strokes and icon are polylines."""
	M = Matrix.Translation((0, y_face, zc)) @ Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
	for poly in plates:
		K["Trim_" + wing].framem(M).prism([tuple(q) for q in C._inset_poly(poly, -0.3)], 0.0, 0.24)
		K["SignPlate"].framem(M).prism(poly, 0.0, 0.42)
	text(K, "N_" + wing, label, "Montserrat-Black.ttf", h, 0.495, M @ Vector((text_u, 0, 0)), (1, 0, 0), (0, 0, 1), spacing, outline=0.085, shear=shear)
	b = K["N_" + wing].framem(M)
	for pts in strokes:
		tube(b, pts, 0.085)
	b = K["N_White"].framem(M)
	for pts in icon:
		tube(b, pts, 0.07)


def halo_sign(K, wing, label, plate, zc, y_face, text_u, h, stripes_u, shear=0.2, spacing=1.08, fnt="Montserrat-Black.ttf", cap=0.8):
	"""Gate sign: steel-framed dark plate, solid slanted letters with a glowing halo behind them, a light bar under the
	word and three slanted paint stripes. Plate outline and stripe side differ per wing. No pictograms."""
	M = Matrix.Translation((0, y_face, zc)) @ Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
	K["Steel"].framem(M).prism([tuple(q) for q in C._inset_poly(plate, -0.22)], 0.0, 0.3)
	K["SignPlate"].framem(M).prism(plate, 0.0, 0.42)
	hp = h / cap  # capitals are `cap` of the nominal height text() works in (0.8 for Montserrat Black)
	o = M @ Vector((text_u, 0.12 + 0.1 * hp, 0.42))
	text(K, "N_" + wing, label, fnt, hp, 0.1, o, (1, 0, 0), (0, 0, 1), spacing, offset=0.045 * h, shear=shear)
	text(K, "SignFace", label, fnt, hp, 0.2, o + Vector((0, -0.1, 0)), (1, 0, 0), (0, 0, 1), spacing, shear=shear)
	bar = K["N_" + wing].framem(M)
	v0 = -h / 2 - 0.36
	bar.prism([(text_u - 2.1 * h, v0), (text_u + 2.1 * h, v0), (text_u + 2.1 * h + 0.05, v0 + 0.17), (text_u - 2.1 * h + 0.05, v0 + 0.17)], 0.42, 0.5)
	st = K["P_" + wing].framem(M)
	for k in range(3):
		u0 = stripes_u + k * 0.78
		st.prism([(u0, -1.05), (u0 + 0.44, -1.05), (u0 + 0.9, 1.05), (u0 + 0.46, 1.05)], 0.42, 0.52)


def bench2(K, x, y, z, ang, length=6.0):
	"""Chunky rounded bench: two block legs, a thick padded seat and a low back (the back is on local -y)."""
	hl = length / 2
	for sx in (-1, 1):
		K["BenchBase"].frame(ang, x, y, z).box(sx * (hl - 0.95) - 0.5, sx * (hl - 0.95) + 0.5, -0.8, 0.8, 0, 1.0)
	K["BenchBase"].frame(ang, x, y, z).box(-hl, hl, -0.95, 0.95, 0.9, 1.25)
	K["BenchPad"].frame(ang, x, y, z).box(-hl + 0.15, hl - 0.15, -0.6, 0.9, 1.2, 1.7)
	K["BenchBase"].frame(ang, x, y, z).box(-hl, hl, -0.95, -0.55, 1.25, 2.5)
	K["BenchPad"].frame(ang, x, y, z).box(-hl + 0.3, hl - 0.3, -0.68, -0.5, 1.8, 2.35)


def gauntlet(A):
	"""The game's namesake: a chunky armoured fist raised on its cuff. Built in a 1.35x frame on the hub plinth."""
	M = Matrix.Translation((0, 0, 0.1)) @ Matrix.Scale(1.35, 4)
	g = lambda m: A[m].framem(M)
	g("GGold").lathe([(0.05, 0), (2.45, 0), (2.55, 0.3), (2.2, 0.9), (2.0, 2.6), (2.4, 3.6), (2.7, 4.15), (2.7, 4.45), (2.25, 4.45), (0.05, 4.45)], n=28)
	g("GSteel").ring(2.08, 2.36, 1.2, 1.7, n=28)
	g("E_Trophy").ring(1.98, 2.2, 2.05, 2.3, n=28)
	g("GSteel").ring(2.6, 2.9, 3.98, 4.45, n=28)
	g("GDark").disc(1.75, 4.45, 5.1, n=20)
	Mf = M @ Matrix.Translation((0, 0, 4.9)) @ Matrix.Scale(1.2, 4) @ Matrix.Translation((0, 0, -4.9))  # a bigger fist on the cuff
	g = lambda m: A[m].framem(Mf)
	g("GGold").box(-1.95, 1.95, -1.2, 1.3, 4.95, 7.5)  # hand
	g("GDark").box(-1.8, 1.8, -1.85, 0.4, 5.6, 8.25)  # shows in the gaps between the fingers
	g("GSteel").box(-1.5, 1.5, 1.3, 1.62, 5.3, 7.25)  # plate on the back of the hand
	g("GSteel").pipe((0, 1.62, 6.3), (0, 1.74, 6.3), 0.7, 8)
	g("E_Trophy").pipe((0, 1.62, 6.3), (0, 1.86, 6.3), 0.48, 8)
	for xi in (-1.44, -0.48, 0.48, 1.44):
		g("GGold").box(xi - 0.44, xi + 0.44, -1.45, 0.55, 7.5, 8.35)  # knuckle
		g("GGold").box(xi - 0.44, xi + 0.44, -1.95, -1.2, 6.2, 8.2)  # finger, curled down the front
		g("GGold").box(xi - 0.42, xi + 0.42, -1.72, -1.0, 5.55, 6.3)  # fingertip tucked under
		g("GSteel").taper((xi - 0.3, xi + 0.3, -0.85, -0.2), 8.35, (xi - 0.1, xi + 0.1, -0.6, -0.45), 8.95)  # stud
	g("GGold").box(-2.55, -1.9, -1.5, 0.3, 5.2, 6.7)  # thumb
	g("GGold").box(-2.4, 0.15, -2.5, -1.9, 5.75, 6.65)


def hub():
	col = C.coll("Hub", C.root())
	K = C.Kit(col, 0.0, prefix="PropsHub")
	K["Brass"].box(-2.7, 2.7, -5.72, -4.9, -0.78, -0.18)
	text(K, "Steel", "SEASON 1", "Montserrat-Black.ttf", 0.4, 0.06, (0, -5.72, -0.48), (1, 0, 0), (0, 0, 1), 1.15)
	# stencilled wing names on the ring walk in front of each gate, read on the way out from the centre
	for name, label in (("Duels", "DUELS"), ("Market", "SHOP"), ("Vault", "LOCKER"), ("Range", "RANGE")):
		a = H.AXIS[name]
		text(K, "P_White", label, "Oswald-Bold.ttf", 2.1, 0.025, (30.05 * cos(a), 30.05 * sin(a), 0.0), (sin(a), -cos(a), 0), (cos(a), sin(a), 0), 1.2)
		K["P_White"].frame(a).prism([(31.5, -1.5), (32.2, 0), (31.5, 1.5), (31.5, 0.85), (31.85, 0), (31.5, -0.85)], 0.0, 0.025)
	for a in (D(45), D(135), D(225), D(315)):  # benches under the future leaderboards, backs to the wall
		bench2(K, 35.9 * cos(a), 35.9 * sin(a), 0.0, a + pi / 2, 6.0)
	for a, m in ((D(35.4), "CaseOlive"), (D(215.4), "CaseSand")):
		cx, cy = 35.4 * cos(a), 35.4 * sin(a)
		case(K, cx, cy, 0, a + pi / 2, 2.8, 1.9, 1.5, m)
		case(K, cx, cy, 1.55, a + pi / 2 + 0.25, 1.9, 1.3, 1.0, "CaseDark")
	K.done()
	# centrepiece: the gauntlet turns slowly in the light well; a hidden static core stops players walking through it
	A = anim_kit(col, 0.0, "AnimGauntlet", (0, 0, 6.0), 8)
	gauntlet(A)
	A.done()
	C.collider_cyl("Hub", 0.0, 0.0, 2.4, 0.15, 6.2)
	# gate signs: solid halo-lit letters on steel-framed plates; each wing has its own plate outline and colour
	yf = H.GF
	G = C.Kit(col, H.ROT["Duels"], prefix="SignDuels")
	halo_sign(G, "Duels", "DUELS", [(-8.7, -2.0), (7.7, -2.0), (8.7, 2.0), (-7.7, 2.0)], 17.35, yf, 1.4, 2.1, -7.2)
	G.done()
	G = C.Kit(col, H.ROT["Market"], prefix="SignMarket")
	halo_sign(G, "Market", "SHOP", [(-7.9, -0.95), (-7.2, -1.65), (7.2, -1.65), (7.9, -0.95), (7.9, 0.95), (7.2, 1.65), (-7.2, 1.65), (-7.9, 0.95)],
		17.85, yf, -1.2, 1.9, 4.3)
	G.done()
	G = C.Kit(col, H.ROT["Vault"], prefix="SignVault")
	halo_sign(G, "Vault", "LOCKER", [(-7.7, -0.95), (-6.9, -1.7), (6.9, -1.7), (7.7, -0.95), (7.7, 0.95), (6.9, 1.7), (-6.9, 1.7), (-7.7, 0.95)],
		17.75, yf - 1.0, 0.85, 1.6, -7.2)
	G.done()
	G = C.Kit(col, H.ROT["Range"], prefix="SignRange")
	halo_sign(G, "Range", "RANGE", [(-8.4, -1.9), (7.6, -1.9), (8.4, 0), (7.6, 1.9), (-8.4, 1.9), (-7.5, 0)], 17.2, yf, 1.75, 1.95, -6.6)
	G.done()


TECH = "BuilderExtended-Bold.otf"  # wide, squared "scoreboard" face for the Duels hall


def duels():
	import lv3_duels as DU
	C.emission("HoloGate", "#7FD4FF", 5.0)
	C.BEVEL["HoloGate"] = 0.0
	C.NO_COLLIDE.add("HoloGate")
	col = C.coll("Duels", C.root())
	K = C.Kit(col, 0.0, prefix="PropsDuels")
	up = (0, 0, 1)
	for side, yc, mode, letter, live in DU.STATIONS:
		W, Dp, n = DU.MODES[mode]
		M = DU.local(side, yc)
		right = (0, 1, 0) if side < 0 else (0, -1, 0)
		# station name on the header beam: the mode in solid letters with a soft blue glow behind, the letter at the end
		o = M @ Vector((0.6, 1.3, 15.5))
		text(K, "HoloLine", mode.upper(), TECH, 1.5, 0.08, o, right, up, 1.2, offset=0.04)
		text(K, "SignFace", mode.upper(), TECH, 1.5, 0.16, o + Vector(right).cross(Vector(up)) * 0.08, right, up, 1.2)
		text(K, "SignFace", letter, TECH, 0.8, 0.1, M @ Vector((-10.8, 1.3, 15.5)), right, up)
		for i, sgn in enumerate((1, -1)):
			cx = sgn * (W / 2 + 0.9)
			Wb = W - 1.0
			count = f"0/{n}" if live else "SOON"
			text(K, "HoloLine", count, TECH, 0.85, 0.05, M @ Vector((cx + Wb / 2 - 1.75, 1.0, 8.72)), right, up)
			text(K, "HoloLine", "TEAM " + "AB"[i], TECH, 0.34, 0.04, M @ Vector((cx - Wb / 2 + 1.75, 1.0, 8.72)), right, up, 1.1)
			text(K, "HoloLine", "WAITING" if live else "LOCKED", TECH, 0.3, 0.04, M @ Vector((cx, 1.0, 3.06)), right, up, 1.25)
	# Gauntlet portal: a lit sign over the frame and a hologram emblem floating in front of the sealed panel
	halo_sign(K, "Duels", "GAUNTLET", [(-11.6, -1.9), (10.6, -1.9), (11.6, 1.9), (-10.6, 1.9)], 16.3, DU.YE, 1.5, 1.9, -10.0, fnt=TECH, cap=0.72)
	zc = DU.ZS + 8.4
	Me = Matrix.Translation((0, DU.YE + 1.0, zc)) @ Matrix.Rotation(D(90), 4, "X")
	K["HoloGate"].framem(Me @ Matrix.Rotation(D(22.5), 4, "Z")).ring(3.5, 4.0, -0.05, 0.05, n=8)
	K["HoloGate"].framem(Me @ Matrix.Rotation(D(22.5), 4, "Z")).ring(4.5, 4.62, -0.05, 0.05, n=8)
	K["HoloGate"].framem(Me).prism([(1.9, 0), (0, 1.9), (-1.9, 0), (0, -1.9)], -0.05, 0.05)
	text(K, "HoloGate", "COMING SOON", TECH, 0.8, 0.06, (0, DU.YE + 1.0, DU.ZS + 2.6), (1, 0, 0), up, 1.2)
	# win-streak corner beside the ramp: board, sign, trophy on a plinth
	K["Steel"].box(DU.X0, DU.X0 + 0.45, 55.5, 68.5, -2.6, 7.6)
	K["Screen"].box(DU.X0 + 0.45, DU.X0 + 0.6, 56.1, 67.9, -2.0, 7.0)
	o = Vector((DU.X0 + 0.45, 62, 8.7))
	text(K, "HoloLine", "WIN STREAKS", TECH, 0.8, 0.06, o, (0, 1, 0), up, 1.3, offset=0.03)
	text(K, "SignFace", "WIN STREAKS", TECH, 0.8, 0.12, o + Vector((0.06, 0, 0)), (0, 1, 0), up, 1.3)
	K["DuelPier"].frame(0, -18.5, 62, DU.ZF).box(-2.4, 2.4, -2.4, 2.4, 0, 0.9)
	K["DuelPier"].frame(0, -18.5, 62, DU.ZF).taper((-1.8, 1.8, -1.8, 1.8), 0.9, (-1.5, 1.5, -1.5, 1.5), 2.0)
	K["Brass"].frame(0, -18.5, 62, DU.ZF).box(-1.6, 1.6, -1.6, 1.6, 2.0, 2.12)
	trophy(K, -18.5, 62, DU.ZF + 2.12)
	# seats: by the ramp and in the two east nooks
	bench2(K, 18.0, 54.3, DU.ZF, 0.0, 7.0)
	bench2(K, 23.6, 87.5, DU.ZF, D(90), 7.0)
	bench2(K, 23.6, 222.5, DU.ZF, D(90), 7.0)
	K.done()


def market():
	ZM, HW = -1.2, 28.0
	col = C.coll("Market", C.root())
	K = C.Kit(col, D(90), prefix="PropsMarket")
	cy = 115.0
	# shop sign round the apse: timber board, brass frame, layered letters
	K["OakDark"].ring(14.28, 14.42, 12.75, 16.05, D(68.5), D(111.5), cx=0, cy=cy)
	for z0, z1 in ((12.6, 12.82), (15.98, 16.2)):
		K["Brass"].ring(14.2, 14.42, z0, z1, D(68), D(112), cx=0, cy=cy)
	arc_text(K, "Brass", "SHOP", "Oswald-Bold.ttf", 2.1, 0.2, (0, cy, 14.4), 14.28, pi / 2, (1, 0, 0), (0, 1, 0), step=D(9.5), wall=True, offset=0.07)
	arc_text(K, "SignCream", "SHOP", "Oswald-Bold.ttf", 2.1, 0.14, (0, cy, 14.4), 14.08, pi / 2, (1, 0, 0), (0, 1, 0), step=D(9.5), wall=True)
	sign(K, "BATTLE PASS", "Oswald-Bold.ttf", 0.9, (-(HW + 9.72), 82, ZM + 12.3), (0, 1, 0), (0, 0, 1), "SignCream", "Brass", 1.2, 0.1, 0.07)
	sign(K, "EVENT", "Oswald-Bold.ttf", 0.7, (-(HW + 9.72), 103.5, ZM + 6.4), (0, 1, 0), (0, 0, 1), "SignCream", "Brass", 1.2, 0.09, 0.06)
	xb = HW + 9.72  # back wall of the three shop alcoves
	# alcove 1: weapon skins on a steel display wall
	yc = 64.0
	K["SignCream"].box(xb - 0.16, xb, yc - 5.3, yc + 5.3, ZM + 3.4, ZM + 11.2)  # pale display board so the guns read
	K["Brushed"].box(xb - 0.24, xb, yc - 5.45, yc + 5.45, ZM + 3.25, ZM + 3.4)
	K["Brushed"].box(xb - 0.24, xb, yc - 5.45, yc + 5.45, ZM + 11.2, ZM + 11.35)
	for zc, skin in ((ZM + 9.6, "P_Duels"), (ZM + 7.2, "P_Vault"), (ZM + 4.9, "P_3v3")):
		rifle(K, xb - 0.16, xb - 0.42, yc - 0.6, zc, skin, 1.05)
	sign(K, "SKINS", "Oswald-Bold.ttf", 0.75, (xb, yc, ZM + 12.3), (0, -1, 0), (0, 0, 1), "SignCream", "Brass", 1.25, 0.09, 0.06)
	# alcove 2: cases by rarity on the shelves
	yc = 82.0
	for k, zs in enumerate((ZM + 5.28, ZM + 7.68)):
		for i2, band in enumerate(("P_2v2", "P_3v3", "P_Market", "P_2v2") if k == 0 else ("P_3v3", "P_Market", "P_2v2", "P_3v3")):
			rarity_case(K, HW + 9.1, yc - 3.9 + i2 * 2.6, zs, pi / 2 + 0.05 * (i2 - 1.5), band, 2.0, 1.0, 0.9)
	sign(K, "CASES", "Oswald-Bold.ttf", 0.75, (xb, yc, ZM + 12.3), (0, -1, 0), (0, 0, 1), "SignCream", "Brass", 1.25, 0.09, 0.06)
	# alcove 3: sidearms on the wall and a stack of crates
	yc = 100.0
	K["SignCream"].box(xb - 0.16, xb, yc - 5.3, yc + 5.3, ZM + 3.4, ZM + 11.2)  # pale display board so the guns read
	K["Brushed"].box(xb - 0.24, xb, yc - 5.45, yc + 5.45, ZM + 3.25, ZM + 3.4)
	K["Brushed"].box(xb - 0.24, xb, yc - 5.45, yc + 5.45, ZM + 11.2, ZM + 11.35)
	for (dy, zc), skin in zip(((-3.2, ZM + 9.3), (0.2, ZM + 9.3), (3.4, ZM + 9.3), (-1.6, ZM + 6.4), (1.9, ZM + 6.4)), ("P_Market", "P_Duels", "P_Vault", "P_3v3", "P_Range")):
		pistol(K, xb - 0.16, xb - 0.4, yc + dy, zc, skin, 1.15)
	sign(K, "SIDEARMS", "Oswald-Bold.ttf", 0.75, (xb, yc, ZM + 12.3), (0, -1, 0), (0, 0, 1), "SignCream", "Brass", 1.25, 0.09, 0.06)
	for yc in (64, 100):  # a few cases on the counters under the weapon walls
		rarity_case(K, HW + 8.6, yc - 3.2, ZM + 2.6, 0.12, "P_Market", 2.0, 1.2, 0.9)
		rarity_case(K, HW + 8.6, yc + 2.9, ZM + 2.6, -0.1, "P_3v3", 1.7, 1.1, 0.8)
	crate(K, HW + 8.6, 82 - 3.0, ZM + 2.6, 0.1, 1.2, 1.0)
	crate(K, HW + 8.6, 82 + 2.8, ZM + 2.6, -0.12, 1.1, 0.9)
	# stock on the hall floor: hard cases and crates, kept to the wall line
	case(K, HW - 2.6, 73.0 - 2.9, ZM, pi / 2, 3.0, 2.0, 1.5, "CaseOlive")
	case(K, HW - 2.6, 73.0 - 2.9, ZM + 1.55, pi / 2 + 0.3, 2.0, 1.4, 1.0, "CaseSand")
	crate(K, HW - 2.7, 91.0 + 2.6, ZM, 0.2, 2.2)
	crate(K, HW - 2.7, 91.0 + 2.6, ZM + 2.2, -0.3, 1.5)
	crate(K, HW - 5.2, 91.0 + 2.9, ZM, -0.1, 1.7)
	case(K, -(HW - 2.6), 99.0 - 2.6, ZM, pi / 2, 2.8, 1.9, 1.5, "CaseDark")
	crate(K, -(HW - 2.8), 66.5 - 2.6, ZM, 0.15, 2.0)
	for x, y in ((-15.8, 58), (15.8, 58), (-15.8, 109), (15.8, 109)):
		plant(K, x, y, ZM, 1.15)
	# shop counter: a brass till, cases and a crate
	for a, kind in ((D(50), 0), (D(74), 1), (D(110), 2), (D(132), 0)):
		px, py = 8.4 * cos(a), cy + 8.4 * sin(a)
		if kind == 0:
			rarity_case(K, px, py, 2.8, a, "P_3v3" if a < 1.5 else "P_2v2", 1.7, 1.0, 0.8)
		elif kind == 1:
			crate(K, px, py, 2.8, a, 1.1, 0.9)
		else:
			K["Brass"].frame(a, px, py, 2.8).box(-0.7, 0.7, -0.5, 0.5, 0, 0.5)
			K["Brass"].frame(a, px, py, 2.8).box(-0.5, 0.5, -0.35, 0.2, 0.5, 1.0)
	K.done()
	# island: the featured case turns slowly on a brass turntable under the lantern
	A = anim_kit(col, D(90), "AnimFeatured", (0, 82, ZM + 2.0), 16)
	A["Brass"].frame(0, 0, 82, ZM + 1.24).disc(2.4, 0.0, 0.2, n=32, r1=2.2)
	rarity_case(A, 0, 82, ZM + 1.44, 0.0, "P_Market", 3.0, 2.0, 1.5)
	A["Brass"].frame(0, 0, 82, ZM + 1.44).box(-1.56, 1.56, -1.06, 1.06, 1.5, 1.58)
	no_collide(A)
	A.done()


GUNS = []  # [id, scale, world x, world y, z, muzzle tx, muzzle ty, mode (0 rest on z, 1 centre at z), spin deg/s]
BUILD_DATA = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "studio", "rojo", "BuildData"))
LOCKER_BAYS = [  # bay angle, label, display scale, [(gun, offset along the wall, rail height)]
	(90, "RIFLES", 1.75, [("Vandal", 0, 2.45), ("Phantom", 0, 4.7), ("Bulldog", 0, 6.95), ("Guardian", 0, 9.2)]),
	(45, "SMGS", 1.8, [("Spectre", 0, 3.3), ("Stinger", 0, 7.2)]),
	(135, "SHOTGUNS", 1.8, [("Judge", 0, 3.3), ("Bucky", 0, 7.2)]),
	(0, "SNIPERS", 1.7, [("Operator", 0, 2.7), ("Marshal", 0, 5.6), ("Outlaw", 0, 8.5)]),
	(180, "HEAVY", 1.7, [("Odin", 0, 3.3), ("Ares", 0, 7.2)]),
	(-45, "SIDEARMS", 2.0, [("Classic", -3.3, 3.3), ("Ghost", 3.3, 3.3), ("Sheriff", -3.3, 7.2), ("Shorty", 3.3, 7.2)]),
	(225, "MELEE", 3.6, [("Knife", 0, 5.9)]),
]


def gun_box(gid):
	"""(x0, x1, z0, z1) of a gun in its own frame (muzzle along +x), from the weapon build data."""
	import json
	d = json.load(open(os.path.join(BUILD_DATA, gid + ".json")))
	x0 = z0 = 1e9
	x1 = z1 = -1e9
	for q in d["parts"]:
		if q.get("option"):
			continue
		x0, x1 = min(x0, q["center"][0] - q["size"][0] / 2), max(x1, q["center"][0] + q["size"][0] / 2)
		z0, z1 = min(z0, q["center"][2] - q["size"][2] / 2), max(z1, q["center"][2] + q["size"][2] / 2)
	return x0, x1, z0, z1


def vault():
	CY, RV, RB = 76.0, 26.0, 28.3
	rot = D(-90)
	C.emission("Holo", "#45DCFF", 3.0)
	C.BEVEL["Holo"] = 0.0
	C.NO_COLLIDE.add("Holo")
	GUNS.clear()
	col = C.coll("Vault", C.root())
	K = C.Kit(col, rot, prefix="PropsVault")

	def world(lx, ly):
		return lx * cos(rot) - ly * sin(rot), lx * sin(rot) + ly * cos(rot)

	for m, label, scale, guns in LOCKER_BAYS:
		arc_text(K, "SignFace", label, "Montserrat-Black.ttf", 1.0, 0.08, (0, CY, 12.3), RV - 1.3, D(m), (1, 0, 0), (0, 1, 0), wall=True)
		for gid, off, z in guns:
			x0, x1, _z0, _z1 = gun_box(gid)
			th = D(m) + off / 27.7
			ha = (x1 - x0) * scale * 0.4 / 27.7
			K["Brushed"].ring(27.3, RB, z, z + 0.14, th - ha, th + ha, cx=0, cy=CY)  # rail the gun rests on
			wx, wy = world((RB - 0.5) * cos(th), CY + (RB - 0.5) * sin(th))
			tx, ty = world(sin(th), -cos(th))  # muzzle to the viewer's right
			GUNS.append([gid, scale, round(wx, 3), round(wy, 3), round(z + 0.14, 3), round(tx, 4), round(ty, 4), 0, 0])
	# the hero gun turns over the projector
	wx, wy = world(0, CY)
	GUNS.append(["Vandal", 2.6, round(wx, 3), round(wy, 3), 6.4, 0.0, 1.0, 1, 16])  # side-on to the door
	# stand-in hard cases by the door (the real crates come later)
	case(K, 10.6, 55.0, 0.0, 0.45, 3.0, 2.0, 1.5, "CaseDark")
	case(K, 10.6, 55.0, 1.55, 0.8, 1.9, 1.3, 1.0, "CaseOlive")
	K.done()
	# hologram rings round the hero gun, turning the other way
	A = anim_kit(col, rot, "AnimHolo", (0, CY, 6.4), -22)
	for tiltd, r0 in ((14, 3.7), (-9, 4.5)):
		A["Holo"].framem(Matrix.Translation((0, CY, 6.4)) @ Matrix.Rotation(D(tiltd), 4, "X")).ring(r0, r0 + 0.16, -0.05, 0.05, n=48)
	A.done()


def range_wing():
	ZR, HW, Y1 = -2.0, 28.0, 92.0
	col = C.coll("Range", C.root())
	K = C.Kit(col, D(180), prefix="PropsRange")
	sign(K, "FIRING RANGE", "Oswald-Bold.ttf", 1.8, (0, Y1 - 0.5, 13.5), (1, 0, 0), (0, 0, 1), "SignCream", "P_Range", 1.3, 0.16, 0.1)
	sandbags(K, -17.5, 69.0, ZR, 0.0, 4)
	sandbags(K, 16.5, 71.5, ZR, 0.15, 3)
	for i, y in enumerate((66.5, 71.5, 78.0, 83.5)):  # ammo boxes on the armoury counter
		K["CaseOlive"].frame(0.1 * (i - 1.5), HW - 0.4, y, ZR + 2.0).box(-0.45, 0.45, -0.75, 0.75, 0, 0.75)
		K["Brushed"].frame(0.1 * (i - 1.5), HW - 0.4, y, ZR + 2.0).box(-0.5, -0.45, -0.2, 0.2, 0.3, 0.55)
	case(K, HW - 2.2, 61.0, ZR, pi / 2, 3.0, 2.0, 1.5, "CaseDark")
	case(K, HW - 2.2, 88.6, ZR, pi / 2 + 0.2, 2.6, 1.8, 1.3, "CaseOlive")
	# rack of spare targets by the door
	K["Steel"].box(-26.6, -22.4, 53.0, 54.8, ZR, ZR + 0.2)
	for sx in (-26.5, -22.7):
		K["Steel"].box(sx, sx + 0.2, 53.1, 54.7, ZR + 0.2, ZR + 3.4)
	K["Steel"].box(-26.5, -22.5, 53.8, 54.0, ZR + 3.2, ZR + 3.4)
	for j, y in enumerate((53.35, 53.75, 54.3)):
		K["Target"].frame(0, -24.5 + 0.3 * (j - 1), y, ZR + 0.2).ext_y(
			[(-1.3, 0.0), (1.3, 0.0), (1.3, 2.8), (0.7, 3.4), (0.7, 4.7), (-0.7, 4.7), (-0.7, 3.4), (-1.3, 2.8)], -0.07, 0.07)
	bench(K, 16.0, 88.6, ZR, 0.0, 5.0)
	K.done()


def build():
	mats()
	hub()
	duels()
	market()
	vault()
	range_wing()
