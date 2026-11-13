"""Sunwell Works phase 1 (main hall and four thresholds): shared helpers.

Run inside the owner's live Blender through Blender MCP:
    import sys; sys.path[:0] = [r"<repo>/tools/blender/sunwell_p1", r"<repo>/tools/blender/lobby_v3"]
    import sw_run; sw_run.build_all()
Reuses the Lobby V3 solid builder (lv3_core.B / Kit) and its collider records.
Units: 1 Blender unit = 1 stud. X east, Y = forward from the entry (Roblox -Z), Z up.
Hall interior: x -34..34, y 0..112, floor z 0. Plan: vault/02 Art/Sunwell Works Phase 1.md
"""
import bpy
import bmesh
from math import sin, cos, pi, radians, sqrt, atan2
from mathutils import Vector, Matrix
from mathutils.geometry import tessellate_polygon

import lv3_core as C

ROOT = "SunwellP1"
D = radians
I4 = Matrix.Identity(4)

# ---------------------------------------------------------------- dimensions (studs)
HX = 34.0  # half width of the hall
LEN = 112.0  # hall length
WT = 4.0  # wall thickness
ZW = 22.0  # wall top (the haunch starts here)
ZC = 28.0  # ceiling
DOORS = {"Duels": (-1, 34.0), "Locker": (1, 34.0), "Range": (-1, 72.0), "Shop": (1, 72.0)}
BEAMS = (21.4, 46.6, 59.4, 84.6, 97.4)  # on the pilasters that frame each doorway and the bench bay
PROS = (13.5, 16.5)  # the SUNWELL WORKS frame
LAND = 3.0  # arrival landing height
COURSES = (1.5, 7.25, 13.0, 17.5, 22.0)

# ---------------------------------------------------------------- palette
# name: (hex, roughness, metal, bevel)
PAL = {
	"Cast": ("#C9C0B0", 0.85, 0.0, 0.12),  # hero concrete: frames, corbels, cheeks
	"CastTrim": ("#C9C0B0", 0.85, 0.0, 0.12),  # smaller cast pieces: corbels, cheeks, newels
	"Wall": ("#BFB6A6", 0.88, 0.0, 0.09),  # wall blocks (the bevel makes the joints)
	"WallLow": ("#A49C8E", 0.88, 0.0, 0.09),
	"WallShade": ("#ADA597", 0.88, 0.0, 0.09),  # wainscot: the lower wall, one value darker
	"Belt": ("#5A554E", 0.7, 0.0, 0.05),  # belt rail and crown
	"WallBase": ("#4A4744", 0.8, 0.0, 0.09),
	"Ceil": ("#ADA597", 0.9, 0.0, 0.09),
	"Floor": ("#857E74", 0.6, 0.0, 0.03),
	"Walk": ("#ACA496", 0.55, 0.0, 0.03),
	"Walk2": ("#A39B8D", 0.55, 0.0, 0.03),  # every other slab of the walk, a shade darker
	"Stripe": ("#B48A3C", 0.5, 0.0, 0.03),
	"Rubber": ("#26282B", 0.75, 0.0, 0.04),
	"Petrol": ("#3E4347", 0.45, 0.2, 0.06),
	"PetrolDark": ("#2B2F33", 0.45, 0.2, 0.05),
	"Charcoal": ("#26282B", 0.5, 0.1, 0.05),
	"Graphite": ("#3B3E42", 0.5, 0.1, 0.04),
	"Steel": ("#868C92", 0.4, 0.6, 0.035),
	"SteelDark": ("#5E666D", 0.45, 0.5, 0.035),
	"Blade": ("#74797E", 0.45, 0.5, 0.08),
	"BlastDoor": ("#3F4348", 0.5, 0.4, 0.05),
	"Dark": ("#15171A", 0.9, 0.0, 0.0),
	"Cream": ("#EDE2CA", 0.6, 0.0, 0.05),
	"Olive": ("#7D8558", 0.8, 0.0, 0.06),
	"Bronze": ("#B07E3A", 0.35, 1.0, 0.04),
	"ShopSlat": ("#7B6349", 0.5, 0.2, 0.05),
	"LockerSlat": ("#93A3AF", 0.4, 0.5, 0.05),
	"RangePanel": ("#8E9682", 0.6, 0.1, 0.06),
	"RangeLining": ("#5F6B5A", 0.6, 0.1, 0.06),
	"LockerFloor": ("#85888A", 0.5, 0.0, 0.03),
	"BayBack": ("#BDB9B0", 0.7, 0.0, 0.0),
	"ShopFloor": ("#A2957F", 0.5, 0.0, 0.03),
	"Timber": ("#6B4B32", 0.5, 0.0, 0.05),
	"CaseShell": ("#34383C", 0.5, 0.1, 0.08),
	"DuelFloor": ("#6E6C68", 0.5, 0.0, 0.03),
	"PadDark": ("#1B1D20", 0.6, 0.0, 0.04),
	"PadOff": ("#4A4E53", 0.6, 0.0, 0.04),
	"HoloPane": ("#1F6FA8", 0.3, 0.0, 0.0),
	"P_Blue": ("#5AA9D6", 0.5, 0.0, 0.03),
	"P_TeamA": ("#F0762A", 0.5, 0.0, 0.04),
	"P_TeamB": ("#2F86E8", 0.5, 0.0, 0.04),
	"P_Violet": ("#A66BD9", 0.5, 0.0, 0.03),
	"P_Orange": ("#F08A24", 0.5, 0.0, 0.04),
	"P_Mint": ("#7FD8A8", 0.5, 0.0, 0.03),
	"P_Cream": ("#E6DCC6", 0.6, 0.0, 0.03),
	"PipeOchre": ("#8E6E35", 0.55, 0.1, 0.05),
	"SeatPad": ("#4F4237", 0.8, 0.0, 0.05),
}
GLOW = {  # name: (hex, strength in Blender)
	"E_Amber": ("#FFB54A", 9.0),
	"E_Opal": ("#FFF0DC", 9.0),
	"E_Cool": ("#DDEBFF", 9.0),
	"E_Blue": ("#7CCBFF", 9.0),
	"E_Mint": ("#86EDB4", 8.0),
	"E_Orange": ("#FF6A2A", 9.0),
	"E_Holo": ("#7FD4FF", 6.0),
	"E_TeamA": ("#FF6A3D", 7.0),
	"E_TeamB": ("#2A86FF", 7.0),
	"E_Sun": ("#FFE6C4", 7.0),
	"E_Intake": ("#E8A860", 5.0),
}

# Roblox looks (Material, variant, colour, extras) read by sw_export
def _L(material, color, **kw):
	d = {"m": material, "v": "", "c": color}
	d.update(kw)
	return d


# Subtle painted textures: our own SW_* MaterialVariants (tools/textures/make_sunwell_textures.py). A PBR texture pack was
# tried on 2026-11-12 and read too realistic.
MATERIALS = {"SW_Plaster": 16, "SW_Floor": 20, "SW_Steel": 10}  # MaterialVariant -> studs per tile
LOOKS = {  # clean stylized colour blocks (owner 2026-11-11: no concrete texture, no blue-teal steel)
	"Cast": _L("SmoothPlastic", "#C2BEB5", v="SW_Plaster"),
	"CastTrim": _L("SmoothPlastic", "#C2BEB5", v="SW_Plaster"),
	"Wall": _L("SmoothPlastic", "#A5A29B", v="SW_Plaster"),  # hub upgrade pass D: infill a step under the cast pilasters
	"WallLow": _L("SmoothPlastic", "#6E675D", v="SW_Plaster"),
	"WallShade": _L("SmoothPlastic", "#8E8B85", v="SW_Plaster"),  # the spawn alcove: one step under the hall walls
	"Belt": _L("SmoothPlastic", "#5E5952", v="SW_Plaster"),
	"WallBase": _L("SmoothPlastic", "#45423F", v="SW_Plaster"),
	"Ceil": _L("SmoothPlastic", "#7D7B77", v="SW_Plaster"),  # neutral grey: not brown (dead), not cool (the Locker read off-family)
	"Floor": _L("SmoothPlastic", "#5C5751", v="SW_Floor"),  # side fields darker than the walk: a lit lane
	"Walk": _L("SmoothPlastic", "#97938B", v="SW_Floor"),  # pass E: a step deeper so the sun patches carry the light
	"Walk2": _L("SmoothPlastic", "#8F8B84", v="SW_Floor"),
	"Stripe": _L("SmoothPlastic", "#A8802F"),
	"Rubber": _L("SmoothPlastic", "#26282B"),
	"Petrol": _L("SmoothPlastic", "#4A4C4D", v="SW_Steel"),  # neutral gunmetal (read navy at #434A4F)
	"PetrolDark": _L("SmoothPlastic", "#363737", v="SW_Steel"),
	"Charcoal": _L("SmoothPlastic", "#2E2D2B"),  # warm charcoal (near-black masses read as holes)
	"Graphite": _L("SmoothPlastic", "#42403D"),
	"Steel": _L("SmoothPlastic", "#868C92", r=0.06),
	"SteelDark": _L("SmoothPlastic", "#5E666D", r=0.04),
	"Blade": _L("SmoothPlastic", "#4F555B", r=0.05),  # dark vanes against the warm intake (hub upgrade)
	"BlastDoor": _L("SmoothPlastic", "#33373C", r=0.03),
	"Dark": _L("SmoothPlastic", "#15171A"),
	"Cream": _L("SmoothPlastic", "#EDE2CA"),
	"Olive": _L("SmoothPlastic", "#6F7650"),  # flat colour (Fabric read realistic)
	"Bronze": _L("Metal", "#B07E3A", r=0.08),
	"ShopSlat": _L("SmoothPlastic", "#7B6349"),
	"LockerSlat": _L("SmoothPlastic", "#5F6C77", r=0.05),
	"RangePanel": _L("SmoothPlastic", "#7F8775"),
	"RangeLining": _L("SmoothPlastic", "#4C504D"),
	"LockerFloor": _L("SmoothPlastic", "#8A847B", v="SW_Floor"),  # warm neutral, the hall family
	"BayBack": _L("SmoothPlastic", "#6C6862"),  # mid grey: the bays read as lit cases, not empty white windows
	"ShopFloor": _L("SmoothPlastic", "#9C9890", v="SW_Floor"),
	"Timber": _L("SmoothPlastic", "#6B4B32"),  # flat colour (Wood grain read realistic)
	"CaseShell": _L("SmoothPlastic", "#34383C"),
	"DuelFloor": _L("SmoothPlastic", "#6E6C69", v="SW_Floor"),
	"PadDark": _L("SmoothPlastic", "#1B1D20"),
	"PadOff": _L("SmoothPlastic", "#4A4E53"),
	"HoloPane": _L("Neon", "#1F6FA8", t=0.8, glow=True),
	"P_Blue": _L("SmoothPlastic", "#5AA9D6"),
	"P_TeamA": _L("SmoothPlastic", "#E8702A"),
	"P_TeamB": _L("SmoothPlastic", "#2F86E8"),
	"P_Violet": _L("SmoothPlastic", "#A66BD9"),
	"P_Orange": _L("SmoothPlastic", "#E0701A"),
	"P_Mint": _L("SmoothPlastic", "#7FD8A8"),
	"P_Cream": _L("SmoothPlastic", "#E6DCC6"),
	"Glass": _L("Glass", "#E2E4E2", t=0.74, r=0.04),  # neutral (the blue tint cast the Locker bays cyan)
	"E_Amber": _L("Neon", "#EA7A0A", glow=True),
	"E_Opal": _L("Neon", "#7E7870", glow=True),  # lighting pass: Roblox Neon clips anything lighter to white
	"E_Cool": _L("Neon", "#DDEBFF", glow=True),
	"E_Blue": _L("Neon", "#6FC4FF", glow=True),
	"E_Mint": _L("Neon", "#7FE8B0", glow=True),
	"E_Orange": _L("Neon", "#FF5A1F", glow=True),
	"E_Holo": _L("Neon", "#6A5E4E", glow=True),  # terminal faces: lit, not a cyan-white blowout
	"E_TeamA": _L("Neon", "#FF6A3D", glow=True),
	"E_TeamB": _L("Neon", "#2A86FF", glow=True),
	"E_Sun": _L("Neon", "#9C8666", glow=True),  # warm sun glow (the Well, the sun ring), the same as the turbine intake
	"E_Intake": _L("Neon", "#9E8768", glow=True),  # the turbine is the brightest thing in the hall  # the turbine intake: warm and dim so the vanes read against it
	"PipeOchre": _L("SmoothPlastic", "#8A6A32", v="SW_Steel"),
	"SeatPad": _L("SmoothPlastic", "#4A3E33"),  # dark warm leather (benches); Fabric read busy and realistic
}

LIGHTS = {}  # area -> [["P"|"S", x, y, z, colour, brightness, range, (angle)]] in Blender coordinates
AREA = "Hall"  # the area that lights made now belong to (a wing module sets this in its build)


def root():
	return C.coll(ROOT)


def make_materials():
	C.ROOT = ROOT
	C.MATS.clear()
	for name, (color, rough, metal, bevel) in PAL.items():
		C.surface(name, color, rough, metal=metal, var=0.035, bump=0.03, ao=0.35)
		C.BEVEL[name] = bevel
	for name, (color, strength) in GLOW.items():
		C.emission(name, color, strength)
		C.BEVEL[name] = 0.0
	C.glass("Glass", "#CFE6F2")
	C.BEVEL["Glass"] = 0.0
	C.surface("Dummy", "#E8E2D6", 0.7, var=0.0, bump=0.0, ao=0.3)
	C.BEVEL["Dummy"] = 0.12


# ---------------------------------------------------------------- frames
def face(origin, xdir, zdir):
	"""Elevation frame of a wall face: local X = the viewer's right, Y = up, Z = out of the wall."""
	x, z = Vector(xdir), Vector(zdir)
	y = z.cross(x)
	return Matrix(((x.x, y.x, z.x, origin[0]), (x.y, y.y, z.y, origin[1]), (x.z, y.z, z.z, origin[2]), (0, 0, 0, 1)))


def wall_face(side, yc, z=0.0):
	"""Face frame on a side wall (side -1 = west / left from the entry, +1 = east), centred at y = yc."""
	if side < 0:
		return face((-HX, yc, z), (0, 1, 0), (1, 0, 0))
	return face((HX, yc, z), (0, -1, 0), (-1, 0, 0))


F_END = face((0, LEN, 0), (1, 0, 0), (0, -1, 0))  # turbine wall, seen from the hall
F_ENTRY = face((0, 0, 0), (-1, 0, 0), (0, 1, 0))  # entry wall, seen from the hall
F_PROS_S = face((0, PROS[0], 0), (1, 0, 0), (0, -1, 0))  # SUNWELL frame, spawn side
F_PROS_N = face((0, PROS[1], 0), (-1, 0, 0), (0, 1, 0))  # SUNWELL frame, hall side


class FK:
	"""A Kit seen through one frame: FK(K, M)['Petrol'].box(...) builds in M's coordinates."""

	def __init__(self, K, M):
		self.K, self.M = K, M

	def __getitem__(self, m):
		return self.K[m].framem(self.M)

	def at(self, M2):
		return FK(self.K, self.M @ M2)


def kit(name, nocol=True, ceil=False):
	col = C.coll(name, root())
	C.clear(name)
	K = C.Kit(col)
	K.nocol = nocol
	return K


def collider(area, M, x0, x1, y0, y1, z0, z1, kind="B"):
	"""Hand-placed collider in frame M. 'B' is opaque and must hide inside a visible solid; 'Y' is invisible."""
	C.collider_box(area, M, min(x0, x1), max(x0, x1), min(y0, y1), max(y0, y1), min(z0, z1), max(z0, z1), kind)


def light(M, x, y, z, color, brightness, rng, angle=None):
	w = M @ Vector((x, y, z))
	row = ["S" if angle else "P", round(w.x, 2), round(w.y, 2), round(w.z, 2), color, brightness, rng, angle or 0, C.cur_group() or ""]
	LIGHTS.setdefault(AREA, []).append(row)


grp = C.grp  # pieces: `with S.grp("Lamp", M, inst=True):` (see lv3_core.grp)


def gun_row(row):
	"""A real gun on display, recorded with the piece it belongs to (it moves with that piece in Studio)."""
	GUNS.append(row + [C.cur_group() or ""])


# ---------------------------------------------------------------- outline helpers
def fillet(pts, style="cham", n=4):
	"""[(x, y[, r])] -> [(x, y)] with every tagged corner cut ('cham') or rounded ('round')."""
	out = []
	m = len(pts)
	for i in range(m):
		p = Vector(pts[i][:2])
		r = pts[i][2] if len(pts[i]) > 2 else 0.0
		if r <= 1e-6:
			out.append((p.x, p.y))
			continue
		ea = Vector(pts[i - 1][:2]) - p
		eb = Vector(pts[(i + 1) % m][:2]) - p
		rr = min(r, ea.length * 0.5, eb.length * 0.5)
		a, b = p + ea.normalized() * rr, p + eb.normalized() * rr
		if style == "cham":
			out += [(a.x, a.y), (b.x, b.y)]
		else:
			for k in range(n + 1):
				t = k / n
				q = a * (1 - t) ** 2 + p * (2 * t * (1 - t)) + b * (t * t)
				out.append((q.x, q.y))
	return out


def u_pts(hw, h, r=0.0, cham=0.0, n=6, y0=0.0):
	"""Open-bottom outline from (-hw, y0) up, across the top and down to (hw, y0)."""
	pts = [(-hw, y0)]
	if r > 0:
		for k in range(n + 1):
			a = pi - (pi / 2) * k / n
			pts.append((-hw + r + r * cos(a), h - r + r * sin(a)))
		for k in range(n + 1):
			a = pi / 2 - (pi / 2) * k / n
			pts.append((hw - r + r * cos(a), h - r + r * sin(a)))
	elif cham > 0:
		pts += [(-hw, h - cham), (-hw + cham, h), (hw - cham, h), (hw, h - cham)]
	else:
		pts += [(-hw, h), (hw, h)]
	pts.append((hw, y0))
	return pts


def u_frame(b, hwo, ho, hwi, hi, z0, z1, ro=0.0, ri=0.0, co=0.0, ci=0.0, y0=0.0, n=6):
	"""A door surround: outer outline minus the inner opening, both standing on y0, extruded z0..z1."""
	poly = u_pts(hwo, ho, ro, co, n, y0) + u_pts(hwi, hi, ri, ci, n, y0)[::-1]
	return b.prism(poly, z0, z1)


def corner_fill(b, hw, h, z0, z1, r=0.0, cham=0.0, n=6):
	"""Fills the two top corners of a square opening so it reads rounded or chamfered."""
	for s in (-1, 1):
		if r > 0:
			pts = [(s * hw, h)]
			for k in range(n + 1):
				a = (pi / 2) * k / n
				pts.append((s * (hw - r + r * sin(a)), h - r + r * cos(a)))
		else:
			pts = [(s * hw, h), (s * (hw - cham), h), (s * hw, h - cham)]
		b.prism(pts, z0, z1)
	return b


def ring_prism(b, outer, inner, z0, z1, plane="xy"):
	"""Closed frame between two loops with the same point count, extruded z0..z1 (plane 'yz' extrudes along x)."""
	n = len(outer)
	assert n == len(inner)
	mk = (lambda p, t: Vector((p[0], p[1], t))) if plane == "xy" else (lambda p, t: Vector((t, p[0], p[1])))
	V = lambda p, t: b.bm.verts.new(b.M @ mk(p, t))
	o0, o1 = [V(p, z0) for p in outer], [V(p, z1) for p in outer]
	i0, i1 = [V(p, z0) for p in inner], [V(p, z1) for p in inner]
	f = b.bm.faces.new
	for k in range(n):
		j = (k + 1) % n
		f((o0[k], o0[j], o1[j], o1[k]))
		f((i0[j], i0[k], i1[k], i1[j]))
		f((o1[k], o1[j], i1[j], i1[k]))
		f((o0[j], o0[k], i0[k], i0[j]))
	return b


def rect_loop(x0, x1, y0, y1):
	return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


def bolts(b, pts, r=0.17, z0=0.0, h=0.13):
	"""Hex bolt heads on a face (axis = the frame's Z)."""
	for x, y in pts:
		b.disc(r, z0, z0 + h, n=6, cx=x, cy=y)
	return b


# ---------------------------------------------------------------- block lettering (our own parametric face)
GW = {"A": 0.84, "B": 0.78, "C": 0.76, "D": 0.80, "E": 0.68, "F": 0.66, "G": 0.80, "H": 0.80, "I": 0.24, "K": 0.80, "L": 0.64,
	"M": 1.14, "N": 0.84, "O": 0.82, "P": 0.74, "R": 0.78, "S": 0.74, "T": 0.72, "U": 0.80, "V": 0.84, "W": 1.14, "Y": 0.80,
	"1": 0.5, "2": 0.74, "3": 0.74, "4": 0.8}


def glyph(ch, s, c, ci, ws):
	"""Unit-height glyph: (width, [loops]); loop = [(x, y[, corner radius])], first loop is the outline."""
	w = GW[ch] * ws
	sb = s * 0.92
	m0, m1 = 0.5 - sb / 2, 0.5 + sb / 2
	if ch == "O":
		return w, [[(0, 0, c), (w, 0, c), (w, 1, c), (0, 1, c)], [(s, s, ci), (w - s, s, ci), (w - s, 1 - s, ci), (s, 1 - s, ci)]]
	if ch == "D":
		return w, [[(0, 0), (w, 0, c), (w, 1, c), (0, 1)], [(s, s), (w - s, s, ci), (w - s, 1 - s, ci), (s, 1 - s)]]
	if ch == "U":
		return w, [[(0, 1), (0, 0, c), (w, 0, c), (w, 1), (w - s, 1), (w - s, s, ci), (s, s, ci), (s, 1)]]
	if ch == "L":
		return w, [[(0, 0), (w, 0), (w, s), (s, s), (s, 1), (0, 1)]]
	if ch == "E":
		e = w * 0.86
		return w, [[(0, 0), (w, 0), (w, s), (s, s), (s, m0), (e, m0), (e, m1), (s, m1), (s, 1 - s), (w, 1 - s), (w, 1), (0, 1)]]
	if ch == "T":
		a, b = w / 2 - s / 2, w / 2 + s / 2
		return w, [[(a, 0), (b, 0), (b, 1 - s), (w, 1 - s), (w, 1), (0, 1), (0, 1 - s), (a, 1 - s)]]
	if ch == "H":
		return w, [[(0, 0), (s, 0), (s, m0), (w - s, m0), (w - s, 0), (w, 0), (w, 1), (w - s, 1), (w - s, m1), (s, m1), (s, 1), (0, 1)]]
	if ch == "N":
		tv = s * 1.55
		return w, [[(0, 0), (s, 0), (s, 1 - tv), (w - s, 0), (w, 0), (w, 1), (w - s, 1), (w - s, tv), (s, 1), (0, 1)]]
	if ch == "K":
		ad, p = s * 1.25, s * 0.85
		yl = (w - ad - s) * 0.5 / (w - s - p)
		return w, [[(0, 0), (s, 0), (s, yl), (w - ad, 0), (w, 0), (s + p, 0.5), (w, 1), (w - ad, 1), (s, 1 - yl), (s, 1), (0, 1)]]
	if ch in "RP":
		bm = 0.40 if ch == "R" else 0.36
		hole = [(s, bm + sb), (w - s, bm + sb, ci), (w - s, 1 - s, ci), (s, 1 - s)]
		if ch == "P":
			return w, [[(0, 0), (s, 0), (s, bm), (w, bm, c), (w, 1, c), (0, 1)], hole]
		ad = s * 1.2
		lx = max(s + 0.02, w - c - ad - 0.02)
		return w, [[(0, 0), (s, 0), (s, bm), (lx, bm), (w - ad * 0.95, 0), (w, 0), (lx + ad, bm), (w, bm, c), (w, 1, c), (0, 1)], hole]
	if ch == "A":
		ab = 0.2
		return w, [[(0, 0), (s, 0), (s, ab), (w - s, ab), (w - s, 0), (w, 0), (w, 1, c * 1.3), (0, 1, c * 1.3)],
			[(s, ab + sb), (w - s, ab + sb), (w - s, 1 - s, ci), (s, 1 - s, ci)]]
	if ch == "C":
		g0, g1 = 0.34, 0.66
		return w, [[(0, 0, c), (w, 0, c), (w, g0), (w - s, g0), (w - s, s, ci), (s, s, ci), (s, 1 - s, ci), (w - s, 1 - s, ci),
			(w - s, g1), (w, g1), (w, 1, c), (0, 1, c)]]
	if ch == "G":
		gm, gx, g1 = 0.54, w * 0.48, 0.70
		return w, [[(0, 0, c), (w, 0, c), (w, gm), (gx, gm), (gx, gm - sb), (w - s, gm - sb), (w - s, s, ci), (s, s, ci), (s, 1 - s, ci),
			(w - s, 1 - s, ci), (w - s, g1), (w, g1), (w, 1, c), (0, 1, c)]]
	if ch == "S":
		tl = max(0.30, s + 0.09)
		tr = 1 - tl
		return w, [[(0, 0, c), (w, 0, c), (w, m1, c), (s, m1, ci), (s, 1 - s, ci), (w - s, 1 - s), (w - s, tr), (w, tr), (w, 1, c), (0, 1, c),
			(0, m0, c), (w - s, m0, ci), (w - s, s, ci), (s, s), (s, tl), (0, tl)]]
	if ch in "WM":
		dw, pk1, v1 = s * 1.35, 0.80, 0.30
		pk0 = (pk1 - v1) / (w / 2 - s) * (w / 2 - dw)
		pts = [(0, 0), (dw, 0), (w / 2, pk0), (w - dw, 0), (w, 0), (w, 1), (w - s, 1), (w - s, v1), (w / 2, pk1), (s, v1), (s, 1), (0, 1)]
		return w, [pts if ch == "W" else [(x, 1 - y) for x, y in pts][::-1]]
	if ch == "I":
		w = s * 1.05
		return w, [[(0, 0), (w, 0), (w, 1), (0, 1)]]
	if ch == "F":
		e = w * 0.84
		return w, [[(0, 0), (s, 0), (s, m0), (e, m0), (e, m1), (s, m1), (s, 1 - s), (w, 1 - s), (w, 1), (0, 1)]]
	if ch == "V":
		ad, hb = s * 1.25, s * 0.62
		vb = 1 - (w / 2 - ad) / (w / 2 - hb)
		return w, [[(0, 1), (w / 2 - hb, 0), (w / 2 + hb, 0), (w, 1), (w - ad, 1), (w / 2, vb), (ad, 1)]]
	if ch == "B":
		n = 0.07
		return w, [[(0, 0), (w, 0, c), (w, 0.5 - n), (w - n, 0.5), (w, 0.5 + n), (w, 1, c), (0, 1)],
			[(s, s), (w - s, s, ci), (w - s, m0, ci), (s, m0)], [(s, m1), (w - s, m1, ci), (w - s, 1 - s, ci), (s, 1 - s)]]
	if ch == "1":
		return w, [[(0.22, 0), (0.22 + s, 0), (0.22 + s, 1), (0.24, 1), (0, 0.80), (0, 0.60), (0.22, 0.72)]]
	if ch in "23":
		tl = max(0.30, s + 0.09)
		tr = 1 - tl
		if ch == "2":
			return w, [[(0, 0), (w, 0), (w, s), (s, s), (s, m0, ci), (w, m0, c), (w, 1, c), (0, 1, c), (0, tr), (s, tr), (s, 1 - s),
				(w - s, 1 - s, ci), (w - s, m1, ci), (0, m1, c)]]
		return w, [[(0, 0, c), (w, 0, c), (w, 1, c), (0, 1, c), (0, tr), (s, tr), (s, 1 - s), (w - s, 1 - s, ci), (w - s, m1, ci), (w * 0.3, m1),
			(w * 0.3, m0), (w - s, m0, ci), (w - s, s, ci), (s, s), (s, tl), (0, tl)]]
	if ch == "4":
		h4 = 0.34
		return w, [[(w - s, 0), (w, 0), (w, 1), (w - s, 1), (w - s, h4 + sb), (s, h4 + sb), (s, 1), (0, 1), (0, h4), (w - s, h4)]]
	if ch == "Y":
		ym, ad = 0.44, s * 1.25
		rise = (1 - ym) / (w / 2 - s / 2) * (w / 2 - ad)
		return w, [[(w / 2 - s / 2, 0), (w / 2 + s / 2, 0), (w / 2 + s / 2, ym), (w, 1), (w - ad, 1), (w / 2, 1 - rise), (ad, 1), (0, 1), (w / 2 - s / 2, ym)]]
	raise KeyError(ch)


def stencil_cuts(ch, s, w, g=0.075):
	"""Bridges for the stencil face: rectangles (x0, x1, y0, y1) in glyph units."""
	if ch in "RE":
		return [(s + 0.015, s + 0.015 + g, -0.1, 1.1)]
	if ch == "A":
		return [(w / 2 - g / 2, w / 2 + g / 2, 1 - s - 0.02, 1.1)]
	if ch == "N":
		return [(s, s + g, 0.42, 1.1), (w - s - g, w - s, -0.1, 0.58)]
	if ch == "G":
		return [(w / 2 - g / 2 - 0.06, w / 2 + g / 2 - 0.06, 1 - s - 0.02, 1.1), (w / 2 - g / 2 - 0.06, w / 2 + g / 2 - 0.06, -0.1, s + 0.02)]
	return []


def text_width(txt, h, s=0.21, ws=1.0, track=0.13, space=0.42, **_):
	x = 0.0
	for ch in txt:
		x += space if ch == " " else (s * 1.05 if ch == "I" else GW[ch] * ws) + track
	return (x - track) * h


def add_text(b, txt, h, depth, y0=0.0, z0=0.0, x0=None, s=0.21, c=0.13, ci=0.05, ws=1.0, track=0.13, space=0.42,
		shear=0.0, style="cham", stencil=False):
	"""Solid block letters in the builder's current frame: baseline y0, back face z0, centred on x = 0 (or left at x0)."""
	width = text_width(txt, h, s, ws, track, space)
	ox = (-width / 2 - shear * h / 2) if x0 is None else x0
	x = 0.0
	M = b.M
	for ch in txt:
		if ch == " ":
			x += space
			continue
		w, loops = glyph(ch, s, c, ci, ws)
		tmp = bmesh.new()
		polys = [[Vector((px, py, 0.0)) for px, py in fillet(lp, style)] for lp in loops]
		flat = [v for lp in polys for v in lp]
		vs = [tmp.verts.new(v) for v in flat]
		for t in tessellate_polygon(polys):
			try:
				tmp.faces.new([vs[i] for i in t])
			except ValueError:
				pass
		if stencil:
			for cx0, cx1, cy0, cy1 in stencil_cuts(ch, s, w):
				for co, no in (((cx0, 0, 0), (1, 0, 0)), ((cx1, 0, 0), (1, 0, 0)), ((0, cy0, 0), (0, 1, 0)), ((0, cy1, 0), (0, 1, 0))):
					bmesh.ops.bisect_plane(tmp, geom=tmp.verts[:] + tmp.edges[:] + tmp.faces[:], plane_co=co, plane_no=no, dist=1e-5)
				dead = [f for f in tmp.faces if cx0 < f.calc_center_median().x < cx1 and cy0 < f.calc_center_median().y < cy1]
				bmesh.ops.delete(tmp, geom=dead, context="FACES")
		bmesh.ops.dissolve_limit(tmp, angle_limit=radians(0.5), verts=tmp.verts[:], edges=tmp.edges[:])
		bmesh.ops.dissolve_degenerate(tmp, dist=1e-4, edges=tmp.edges[:])
		dead = [f for f in tmp.faces if f.calc_area() < 1e-6]
		if dead:
			bmesh.ops.delete(tmp, geom=dead, context="FACES")
		loose = [v for v in tmp.verts if not v.link_faces]
		if loose:
			bmesh.ops.delete(tmp, geom=loose, context="VERTS")
		tmp.verts.index_update()
		P = lambda v, zz: M @ Vector((ox + (x + v.co.x + shear * v.co.y) * h, y0 + v.co.y * h, zz))
		lo = [b.bm.verts.new(P(v, z0)) for v in tmp.verts]
		hi = [b.bm.verts.new(P(v, z0 + depth)) for v in tmp.verts]
		for f in tmp.faces:
			idx = [v.index for v in f.verts]
			b.bm.faces.new([hi[i] for i in idx])
			b.bm.faces.new([lo[i] for i in idx][::-1])
		for e in tmp.edges:
			if e.is_boundary:
				i, j = e.verts[0].index, e.verts[1].index
				b.bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
		tmp.free()
		x += w + track
	return width


def slash(b, x, y0, h, w, lean, z0, z1):
	"""A slanted paint bar (parallelogram), bottom-left at (x, y0)."""
	return b.prism([(x, y0), (x + w, y0), (x + w + lean, y0 + h), (x + lean, y0 + h)], z0, z1)


# ---------------------------------------------------------------- wing rooms
OPEN = set()  # doorways whose wing is built (no temporary closure): {"Locker", "Shop", "Duels"}
GUNS = []  # real gun displays: [id, scale, x, y, z, muzzle x, muzzle y, mode (0 rest on z, 1 centre at z), spin deg/s]
ANCHORS = []  # gameplay hooks for Studio: [name, tag, x, y, z, sx, sy, sz, {attributes}] (Blender coordinates, size x/y/z)


ANIM = {}  # moving groups: name -> {"pivot": [x, y, z], "spin": deg/s, "axis": [x, y, z]} (Blender coordinates)
SOUNDS = []  # looping 3D sounds: [name, x, y, z, asset id, volume, playback speed, min distance, max distance]
SCREENS = []  # SurfaceGui screens for Studio: [kind, title, sub, x, y, z, width, height, normal x, normal y]


def screen(kind, title, sub, M, x, y, z, w, h):
	"""A live-looking display: recorded here, built in Studio as a SurfaceGui on a thin part at (x, y, z) of frame M."""
	c = M @ Vector((x, y, z))
	n = M.to_3x3() @ Vector((0, 0, 1))
	SCREENS.append([kind, title, sub, round(c.x, 3), round(c.y, 3), round(c.z, 3), w, h, round(n.x, 4), round(n.y, 4), C.cur_group() or ""])


def taper_y(b, r0, y0, r1, y1):
	"""Tapered block in an elevation frame: rectangles r = (x0, x1, z0, z1) at heights y0 and y1."""
	q = lambda r, y: [(r[0], y, r[2]), (r[1], y, r[2]), (r[1], y, r[3]), (r[0], y, r[3])]
	return b.solid(q(r0, y0), q(r1, y1))


def cut_rect(x0, x1, y0, y1, big, small=0.25):
	"""Rectangle with a big cut at the top-left and bottom-right corners and small cuts at the other two (a leaning read)."""
	return [(x0 + small, y0), (x1 - big, y0), (x1, y0 + big), (x1, y1 - small), (x1 - small, y1), (x0 + big, y1), (x0, y1 - big), (x0, y0 + small)]


def cham_rect(x0, x1, y0, y1, c):
	return [(x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1 - c), (x1 - c, y1), (x0 + c, y1), (x0, y1 - c), (x0, y0 + c)]


def anchor(name, tag, x, y, z, sx, sy, sz, **attrs):
	ANCHORS.append([name, tag, round(x, 2), round(y, 2), round(z, 2), sx, sy, sz, attrs])


def edge_frame(p, q, zf=0.0):
	"""Elevation frame of the interior wall on edge p -> q of a counter-clockwise room outline, and its length."""
	p, q = Vector(p), Vector(q)
	d = (q - p).normalized()
	mid = (p + q) / 2
	return face((mid.x, mid.y, zf), (-d.x, -d.y, 0), (-d.y, d.x, 0)), (q - p).length


def wall_seg(F, area, L, H, openings=(), t=4.0, joint=11.0, ext=(0.0, 0.0), courses=None, mat="Wall", base="WallBase", base_h=1.5,
		low=1, belt=True, crown=True, batter=0.45, top_trim=0.0, name=None):
	"""See _wall_seg. With a name, every stretch between openings is its own piece (name_1, name_2, ...) with its
	colliders, and the crown is a piece of its own."""
	if not name:
		return _wall_seg(F, area, L, H, openings, t, joint, ext, courses, mat, base, base_h, low, belt, crown, batter, top_trim)
	return _wall_seg(F, area, L, H, openings, t, joint, ext, courses, mat, base, base_h, low, belt, crown, batter, top_trim, name)


def _wall_seg(F, area, L, H, openings=(), t=4.0, joint=11.0, ext=(0.0, 0.0), courses=None, mat="Wall", base="WallBase", base_h=1.5,
		low=1, belt=True, crown=True, batter=0.45, top_trim=0.0, name=None):
	"""Coursed block wall in a face frame: x -L/2..L/2 (extended by ext at each end to close the corners), y 0..H, z -t..0.
	openings = [(u0, u1, top)] are left open from the floor to top. Adds the hidden collider core.
	Trim hierarchy: dark base course, the lowest `low` courses as a darker wainscot, a belt rail on top of it, a crown under the ceiling.
	Shape language (owner 2026-11-12, RIVALS as the reference): flat facets, not rounded boxes. The wainscot is battered
	(it stands `batter` proud at the foot and leans back to the wall face), the belt is a sloped ledge, the crown a facet."""
	a0, a1 = -L / 2 - ext[1], L / 2 + ext[0]
	zs = sorted(set([base_h] + list(courses or []) + [H] + [o[2] for o in openings if o[2] < H]))
	zs = [z for z in zs if base_h <= z <= H]
	cuts = sorted(set([a0, a1] + [u for o in openings for u in o[:2]]))
	from contextlib import nullcontext
	if crown:
		with (grp(f"{name}_Crown", F.M) if name else nullcontext()):
			F["Belt"].ext_x([(H - 0.8, 0.0), (H, 0.7), (H, 0.0)], -L / 2, L / 2)
	for i in range(len(cuts) - 1):
		u0, u1 = cuts[i], cuts[i + 1]
		with (grp(f"{name}_{i + 1}", F.M @ Matrix.Translation(((u0 + u1) / 2, 0, 0))) if name else nullcontext()):
			_wall_piece(F, area, L, H, openings, t, joint, zs, u0, u1, mat, base, base_h, low, belt, batter, top_trim)


def _wall_piece(F, area, L, H, openings, t, joint, zs, u0, u1, mat, base, base_h, low, belt, batter, top_trim):
	if True:
		top = max([o[2] for o in openings if o[0] <= (u0 + u1) / 2 <= o[1]] or [0.0])
		n = max(1, round((u1 - u0) / joint))
		if top <= 0 and batter > 0:
			F[base].ext_x([(-1.5, batter + 0.3), (-1.5, -t), (base_h, -t), (base_h, batter + 0.14)], u0, u1)
			F["WallLow"].ext_x([(base_h, batter), (base_h, -t), (zs[low], -t), (zs[low], 0.0)], u0, u1)
			collider(area, F.M, max(u0, -L / 2), min(u1, L / 2), 0.0, zs[low], batter + 0.12, batter + 0.3, kind="Y")  # foot of the batter
		elif top <= 0:
			F[base].box(u0, u1, -1.5, base_h, -t, 0.35)
		if top <= 0:
			collider(area, F.M, u0, u1, -1.5, base_h - 0.1, -0.3, 0.27)
			collider(area, F.M, u0, u1, -1.5, H, -t + 0.25, -0.25)
			if belt and len(zs) > low + 1:
				zb = zs[low]
				F["Belt"].ext_x([(zb - 0.3, 0.0), (zb, 0.4), (zb + 0.2, 0.4), (zb + 0.2, 0.0)], max(u0, -L / 2), min(u1, L / 2))
		elif top < H:
			collider(area, F.M, u0, u1, top + 0.25, H, -t + 0.25, -0.25)
		for k, (zl, zh) in enumerate(zip(zs, zs[1:])):
			if zl < top or (top <= 0 and batter > 0 and k < low):
				continue
			if zh >= H - 1e-6:
				zh -= top_trim  # neighbouring walls end at slightly different heights, so their tops never share a plane outside
			for j in range(n):
				F["WallLow" if k < low else mat].box(u0 + (u1 - u0) * j / n, u0 + (u1 - u0) * (j + 1) / n, zl, zh, -t, 0)


def poly_room(area, pts, zf, H, floor_mat="Walk", ceil_mat="Ceil", t=4.0, ceiling=True, slabs=None):
	"""Floor slab, ceiling slab and their colliders for a counter-clockwise room outline.
	Returns (K, KC, [(FK frame, length, (ext at +x end, ext at -x end))]) with one entry per edge."""
	from math import acos
	K, KC = kit(area), kit(area + "_Ceil")
	xs, ys = [p[0] for p in pts], [p[1] for p in pts]
	bb = (min(xs) - t, max(xs) + t, min(ys) - t, max(ys) + t)
	with grp(f"{area}_Floor"):
		K[floor_mat].prism(list(pts), zf - 1.5, zf)
		for r in (slabs or [bb]):  # slabs: rectangles that stay inside the outer wall faces of a room that is not a rectangle
			collider(area, I4, r[0], r[1], r[2], r[3], zf - 1.5, zf - 0.045)
	if ceiling:  # a wing with skylights builds its own roof
		with grp(f"{area}_Ceiling"):
			for r in (slabs or [bb]):
				KC[ceil_mat].box(r[0], r[1], r[2], r[3], zf + H, zf + H + 2)
				collider(area, I4, r[0], r[1], r[2], r[3], zf + H + 0.2, zf + H + 1.8)
	n = len(pts)
	turn = []
	for i in range(n):
		a, b, c = Vector(pts[i - 1]), Vector(pts[i]), Vector(pts[(i + 1) % n])
		d1, d2 = (b - a).normalized(), (c - b).normalized()
		ang = acos(max(-1.0, min(1.0, d1.dot(d2))))
		turn.append(t * sin(ang) if d1.x * d2.y - d1.y * d2.x > 0 else 0.0)  # convex corner: the wall running into it carries on behind the next
	edges = []
	for i in range(n):
		M, L = edge_frame(pts[i], pts[(i + 1) % n], zf)
		edges.append((FK(K, M), L, (0.0, turn[(i + 1) % n])))  # no two walls share a corner block (that z-fought on the outside)
	return K, KC, edges


def pilaster(F, u, top, hw=1.2, d=0.8, name="Pilaster"):
	"""A cast pilaster on a wall face frame F at u (x along the wall), from the floor to `top`: a dark flared foot, a
	steel shoe inset in it, a tapered cast base, a straight shaft and a flared head. A piece of its own with its collider."""
	with grp(name, F.M @ Matrix.Translation((u, 0, 0)), inst=True):
		P = F.at(Matrix.Translation((u, 0, 0)))
		r = lambda w, dd: (-w, w, 0.0, dd)  # (x0, x1, z0, z1) in the face frame: x along the wall, z out of it
		taper_y(P["WallBase"], r(hw + 0.35, d + 0.45), 0.0, r(hw + 0.2, d + 0.3), 1.5)
		taper_y(P["CastTrim"], r(hw + 0.1, d + 0.2), 1.5, r(hw, d), 3.2)
		P["CastTrim"].box(-hw, hw, 3.2, top - 1.4, 0.0, d)
		taper_y(P["CastTrim"], r(hw, d), top - 1.4, r(hw + 0.3, d + 0.3), top)
		taper_y(P["PetrolDark"], r(hw + 0.26, d + 0.36), 1.5, r(hw + 0.2, d + 0.3), 2.2)  # shoe
		collider(AREA, P.M, -hw, hw, 0.0, top, 0.05, d - 0.1)


def ceiling_beam(KC, x0, y0, x1, y1, H, name="CeilingBeam"):
	"""A crossbeam under a wing ceiling, the hall's language: flanges with cut ends, a web, and a corbel bracket into the
	soffit at each end. Runs from (x0, y0) to (x1, y1) in plan, its top at the ceiling H."""
	d = Vector((x1 - x0, y1 - y0, 0))
	L = d.length
	ang = atan2(d.y, d.x)
	M = Matrix.Translation(((x0 + x1) / 2, (y0 + y1) / 2, 0)) @ Matrix.Rotation(ang, 4, "Z")
	with grp(name, M, inst=True):
		B = FK(KC, M)
		B["PetrolDark"].prism(cham_rect(-L / 2, L / 2, -0.75, 0.75, 0.35), H - 1.3, H - 1.05)  # bottom flange
		B["PetrolDark"].box(-L / 2, L / 2, -0.22, 0.22, H - 1.05, H)  # web
		B["PetrolDark"].prism(cham_rect(-L / 2, L / 2, -0.75, 0.75, 0.35), H - 0.25, H)  # top flange
		for s in (-1, 1):
			B["Steel"].box(s * (L / 2 - 1.2) - 0.08, s * (L / 2 - 1.2) + 0.08, -0.7, 0.7, H - 1.32, H - 1.3)  # fixing plate


def soffit(KC, area, pts, H, depth=0.7, width=3.0, lights=6, name="Soffit"):
	"""A dropped soffit round a room's ceiling: a ring `width` wide and `depth` deep against the walls, a lip on its
	inner edge and a warm light cove behind the lip (a lit strip and a few real lights), so the ceiling reads as a
	coffer instead of one flat slab. Faceted: it follows the room outline, chamfered corners included."""
	with grp(name):
		out = C._inset_poly([Vector(p) for p in pts], -0.1)  # tucked 0.1 into the walls (no seam at the wall face)
		mid = C._inset_poly([Vector(p) for p in pts], width - 0.35)
		inn = C._inset_poly([Vector(p) for p in pts], width)
		xy = lambda P: [(p.x, p.y) for p in P]
		ring_prism(KC["Ceil"], xy(out), xy(inn), H - depth, H)
		ring_prism(KC["Belt"], xy(mid), xy(inn), H - depth - 0.22, H - depth)  # lip
		cove = C._inset_poly([Vector(p) for p in pts], width + 0.08)
		cin = C._inset_poly([Vector(p) for p in pts], width + 0.32)
		ring_prism(KC["E_Sun"], xy(cove), xy(cin), H - 0.06, H - 0.01)  # the lit cove on the ceiling, inside the lip
		n = len(pts)
		P = [Vector(p) for p in inn]
		per = sum((P[(i + 1) % n] - P[i]).length for i in range(n))
		step, t, k = per / lights, step_start(per, lights), 0
		for i in range(n):
			a, b = P[i], P[(i + 1) % n]
			L = (b - a).length
			while t < L and k < lights:
				q = a + (b - a) * (t / L)
				light(I4, q.x, q.y, H - depth - 0.6, "#FFE2B8", 0.55, 14)
				t += step
				k += 1
			t -= L


def step_start(per, n):
	return per / n / 2


def opal_panel(KC, x, y, z, w, d, color="#FFF1DE", brightness=0.6, rng=30, glow="E_Opal"):
	"""Mounted ceiling panel: charcoal housing, opal lens, a real light under it. A piece of its own."""
	with grp("CeilingLight", Matrix.Translation((x, y, z)), inst=True):
		P = FK(KC, Matrix.Translation((x, y, z)))
		P["Charcoal"].prism(cham_rect(-w / 2 - 0.3, w / 2 + 0.3, -d / 2 - 0.3, d / 2 + 0.3, 0.25), -0.32, 0.0)
		P[glow].box(-w / 2, w / 2, -d / 2, d / 2, -0.4, -0.32)
		for u in (-w / 6, w / 6):  # louvre fins: the lens reads as a fitting with falloff, not a flat white sheet
			P["Graphite"].box(u - 0.06, u + 0.06, -d / 2, d / 2, -0.62, -0.4)
		P["Graphite"].box(-w / 2, w / 2, -0.06, 0.06, -0.62, -0.4)
		ring_prism(P["Charcoal"], cham_rect(-w / 2 - 0.3, w / 2 + 0.3, -d / 2 - 0.3, d / 2 + 0.3, 0.25), cham_rect(-w / 2 - 0.03, w / 2 + 0.03, -d / 2 - 0.03, d / 2 + 0.03, 0.02), -0.62, -0.32)  # a deeper bezel round the lens
		light(I4, x, y, z - 0.6, color, round(brightness * 3.4, 2), round(rng * 0.9, 1), angle=80)  # a spot: a pool on the floor, not a flat wash
