"""Lobby V4 ("Gauntlet Bunker", the RIVALS feel in our own pieces): theme palette and the shared kit.

Run in the owner's live Blender (the Lobby V4 instance, MCP bridge on port 9999) through tools/blender/lobby_v4/send.py:
    import sys; sys.path[:0] = [r"<repo>/tools/blender/lobby_v4", r"<repo>/tools/blender/sunwell_p1", r"<repo>/tools/blender/lobby_v3"]
    import v4_run as R; R.build_all()
Reuses the Sunwell builder (sw_core: frames, pieces, lights, screens, anchors) and the V3 solid builder (lv3_core.B).
Units: 1 Blender unit = 1 stud. X east, Y north (= towards Duels, Roblox -Z), Z up. Origin = the spawn dais centre.
Theme: vault/02 Art/Lobby V4 Theme.md. Plan: vault/02 Art/Lobby V4 Plan.md.
"""
from math import cos, sin, radians, pi, atan2, degrees

from mathutils import Matrix, Vector

import lv3_core as C
import sw_core as S

ROOT = "LobbyV4"
D = radians

# ---------------------------------------------------------------- palette: name -> (Blender hex, roughness, metal, bevel)
PAL = {
	"V_Wall": ("#4E5359", 0.85, 0.0, 0.07),  # graphite shell
	"V_Panel": ("#5A5F66", 0.8, 0.0, 0.05),  # big inset wall panels, one step lighter
	"V_Low": ("#383C41", 0.85, 0.0, 0.05),  # battered wainscot
	"V_Base": ("#26292D", 0.85, 0.0, 0.05),  # plinth, pier feet
	"V_Trim": ("#8A8F96", 0.6, 0.0, 0.04),  # the light grey contrast line: belts, bezels, sign rims
	"V_Ceil": ("#33363A", 0.9, 0.0, 0.04),
	"V_Beam": ("#41454A", 0.85, 0.0, 0.08),
	"V_Slab": ("#17191B", 0.9, 0.0, 0.0),  # the dark floor under the plates (shows in the gaps)
	"V_Floor": ("#4A4E54", 0.7, 0.0, 0.03),
	"V_Floor2": ("#41454A", 0.7, 0.0, 0.03),
	"V_Lane": ("#62666C", 0.65, 0.0, 0.03),
	"V_Steel": ("#5E646B", 0.45, 0.4, 0.03),
	"V_Dark": ("#16171A", 0.6, 0.0, 0.03),  # sign plates, TV cases
	"V_Paint": ("#D9D9D4", 0.6, 0.0, 0.0),  # floor stencils
	"V_Crate": ("#3D4347", 0.75, 0.0, 0.05),
	"V_Gold": ("#E3AC2C", 0.35, 0.6, 0.03),
	"V_Strap": ("#1B1D20", 0.7, 0.0, 0.05),
	"V_GoldPaint": ("#E3AC2C", 0.6, 0.0, 0.03),
	"V_Seat": ("#2E3135", 0.8, 0.0, 0.04),
	"V_TeamA": ("#C9602A", 0.6, 0.0, 0.02),
	"V_TeamB": ("#2F6FC0", 0.6, 0.0, 0.02),
	"G_PadA": ("#FF8A5C", 0.1, 0.0, 0.0),  # Duels pad glass (Studio: Glass, see-through over the lit well)
	"G_PadB": ("#5AA0FF", 0.1, 0.0, 0.0),
	"G_Screen": ("#16161C", 0.1, 0.0, 0.0),  # a TV's dark glass face (blank until the pad UI)
	"V_Violet": ("#6539D7", 0.6, 0.0, 0.02),
	"V_Pink": ("#B8406A", 0.6, 0.0, 0.02),
	"V_Lime": ("#86A830", 0.6, 0.0, 0.02),
	"V_ThDeep": ("#401C99", 0.6, 0.0, 0.02),
	"V_ThViolet": ("#6539D7", 0.6, 0.0, 0.02),
	"V_ThLilac": ("#C5B7D9", 0.6, 0.0, 0.02),
	"V_Rock": ("#55585C", 0.9, 0.0, 0.0),
	"V_Rock2": ("#63676B", 0.9, 0.0, 0.0),
}
GLOW = {
	"E_White": ("#F4F1EA", 9.0),  # lamp lenses and sign letters
	"E_Gold": ("#7A4CF0", 9.0),  # studio violet (owner 2026-11-16)
	"E_Violet": ("#7A4CF0", 9.0),
	"E_Coral": ("#FF5C8A", 9.0),
	"E_Lime": ("#B4E04A", 9.0),
	"E_Panel": ("#DCE4EA", 3.0),  # frosted clerestory panels
	"E_Alarm": ("#FF3348", 8.0),
	# studio theme (owner 2026-11-16: deep violet, violet, lilac; exact codes to come: placeholders until then)
	"E_ThViolet": ("#7A4CF0", 9.0),
	"E_ThLilac": ("#C5B7D9", 8.0),
	"H_Item": ("#6539D7", 7.0),
	"H_Ghost": ("#C5B7D9", 4.0),
	"H_Cone": ("#C5B7D9", 2.0),
	"H_Ring": ("#C5B7D9", 6.0),
	"H_Figure": ("#6539D7", 3.0),
}
_L = S._L
LOOKS = {  # Roblox look per material (SW_* are our faint painted MaterialVariants)
	"V_Wall": _L("SmoothPlastic", "#4E5359"),
	"V_Panel": _L("SmoothPlastic", "#5A5F66"),
	"V_Low": _L("SmoothPlastic", "#383C41"),
	"V_Base": _L("SmoothPlastic", "#26292D"),
	"V_Trim": _L("SmoothPlastic", "#8A8F96"),
	"V_Ceil": _L("SmoothPlastic", "#4C5056"),  # round 4: lighter, the coffers read
	"V_Beam": _L("SmoothPlastic", "#5A5F66"),
	"V_Slab": _L("SmoothPlastic", "#17191B"),
	"V_Floor": _L("SmoothPlastic", "#4A4E54", r=0.03),
	"V_Floor2": _L("SmoothPlastic", "#45494F", r=0.03),
	"V_Lane": _L("SmoothPlastic", "#62666C"),
	"V_Steel": _L("SmoothPlastic", "#5E646B", r=0.04),
	"V_Dark": _L("SmoothPlastic", "#16171A"),
	"V_Paint": _L("SmoothPlastic", "#CFCFCA"),
	"V_Crate": _L("SmoothPlastic", "#3D4347"),
	"V_Gold": _L("SmoothPlastic", "#E0A830", r=0.12),
	"V_Strap": _L("SmoothPlastic", "#1B1D20"),
	"V_GoldPaint": _L("SmoothPlastic", "#E3AC2C"),
	"V_Seat": _L("SmoothPlastic", "#2E3135"),
	"V_TeamA": _L("SmoothPlastic", "#C9602A"),
	"V_TeamB": _L("SmoothPlastic", "#2F6FC0"),
	"G_PadA": _L("Neon", "#B4552E", t=0.78, glow=True),  # see-through glowing glass: Neon takes no shadows (the plastic caught jagged ones) and the emblem shows
	"G_PadB": _L("Neon", "#2F5FB4", t=0.78, glow=True),
	"G_Screen": _L("Glass", "#141418", t=0.05, r=0.02),
	"V_Violet": _L("SmoothPlastic", "#6539D7"),
	"V_Pink": _L("SmoothPlastic", "#B8406A"),
	"V_Lime": _L("SmoothPlastic", "#86A830"),
	"V_ThDeep": _L("SmoothPlastic", "#401C99"),
	"V_ThViolet": _L("SmoothPlastic", "#6539D7"),
	"V_ThLilac": _L("SmoothPlastic", "#C5B7D9"),
	"V_Rock": _L("SmoothPlastic", "#55585C"),
	"V_Rock2": _L("SmoothPlastic", "#63676B"),
	"E_White": _L("Neon", "#8F8E8A", glow=True),  # Neon lighter than ~#8C877F clips to white: this reads clean white
	"E_Gold": _L("Neon", "#6539D7", glow=True),  # studio violet replaces gold (owner 2026-11-16)
	"E_Violet": _L("Neon", "#6539D7", glow=True),
	"E_Coral": _L("Neon", "#D9406E", glow=True),
	"E_Lime": _L("Neon", "#7CAA1C", glow=True),
	"E_Panel": _L("Neon", "#6E7378", glow=True),
	"E_Alarm": _L("Neon", "#B21E30", glow=True),
	"E_ThViolet": _L("Neon", "#6539D7", glow=True),
	"E_ThLilac": _L("Neon", "#9F8FC0", glow=True),  # lilac #C5B7D9, a step darker: lighter Neon clips to white
	"H_Item": _L("Neon", "#6539D7", t=0.08, glow=True),  # hologram silhouette
	"H_Ghost": _L("Neon", "#9F8FC0", t=0.55, glow=True),  # its offset ghost copy
	"H_Cone": _L("Neon", "#9F8FC0", t=0.82, glow=True),  # the projection cone
	"H_Ring": _L("Neon", "#9F8FC0", t=0.3, glow=True),  # the floor ring
	"H_Figure": _L("ForceField", "#7A4CF0"),  # stage hologram figures: Roblox's shimmering force field, no bloom
	"Glass": _L("SmoothPlastic", "#DDE2E4", t=0.9, r=0.04),
}
WHITE = "#F4F1EA"  # lamp light
THEME = {"deep": "#401C99", "violet": "#6539D7", "lilac": "#C5B7D9", "pale": "#E5DDEF", "white": "#FFFDFE"}  # studio palette (owner 2026-11-16)
PAINT = {"E_Gold": "V_ThViolet", "E_Violet": "V_Violet", "E_Coral": "V_Pink", "E_Lime": "V_Lime", "E_ThViolet": "V_ThViolet", "E_ThLilac": "V_ThLilac"}  # accent -> painted twin


def register():
	"""Add the V4 materials to the Sunwell tables (called after sw_core is reloaded)."""
	S.ROOT = ROOT
	S.PAL.update(PAL)
	S.GLOW.update(GLOW)
	S.LOOKS.update(LOOKS)


# ---------------------------------------------------------------- geometry helpers
def oct_pts(r, rot=D(22.5), n=8):
	"""Regular polygon with inradius r whose flat faces face the axes (vertices at 22.5 + 45k for n = 8)."""
	rc = r / cos(pi / n)
	return [(rc * cos(rot + 2 * pi * k / n), rc * sin(rot + 2 * pi * k / n)) for k in range(n)]


def face_at(theta_deg, r, z=0.0):
	"""Frame on the inner face of a wall whose outward direction is theta: X = right (seen from inside), Y = up, Z = into the room."""
	t = D(theta_deg)
	c, s = cos(t), sin(t)
	return S.face((r * c, r * s, z), (s, -c, 0), (-c, -s, 0))


def T(x=0.0, y=0.0, z=0.0):
	return Matrix.Translation((x, y, z))


def RX(a):
	return Matrix.Rotation(D(a), 4, "X")


def RY(a):
	return Matrix.Rotation(D(a), 4, "Y")


def inset(poly, d):
	"""Inset a convex CCW polygon by d (uniform)."""
	return [(p.x, p.y) for p in C._inset_poly([(x, y) for x, y in poly], d)]


def ccw(poly):
	a = sum(poly[i - 1][0] * poly[i][1] - poly[i][0] * poly[i - 1][1] for i in range(len(poly)))
	return poly if a > 0 else poly[::-1]


# ---------------------------------------------------------------- RIVALS-style word sign (our own build)
def _rot(pts, a, cx=0.0, cy=0.0):
	c, s_ = cos(a), sin(a)
	return [(cx + x * c - y * s_, cy + x * s_ + y * c) for x, y in pts]


def plate_shape(shape, w, h):
	"""Sign plate outlines (owner 2026-11-16: every sign different, with character): one per sign family."""
	if shape == "badge":  # pointed both ends, like a blade
		return ccw([(-w / 2, h / 2), (-w / 2 + h * 0.45, 0), (w / 2 - h * 0.45, 0), (w / 2, h / 2), (w / 2 - h * 0.45, h), (-w / 2 + h * 0.45, h)])
	if shape == "tag":  # a price tag: pointed left, cut corners right
		c = h * 0.18
		return ccw([(-w / 2, h / 2), (-w / 2 + h * 0.5, 0), (w / 2 - c, 0), (w / 2, c), (w / 2, h - c), (w / 2 - c, h), (-w / 2 + h * 0.5, h)])
	if shape == "arrow":  # notched tail, pointed head
		return ccw([(-w / 2, 0), (w / 2 - h * 0.5, 0), (w / 2, h / 2), (w / 2 - h * 0.5, h), (-w / 2, h), (-w / 2 + h * 0.32, h / 2)])
	if shape == "ribbon":  # notched both ends
		return ccw([(-w / 2, 0), (w / 2, 0), (w / 2 - h * 0.3, h / 2), (w / 2, h), (-w / 2, h), (-w / 2 + h * 0.3, h / 2)])
	lean = h * 0.28  # "lean": the plate leans forward like motion
	return ccw([(-w / 2, 0.0), (w / 2 - lean, 0.0), (w / 2, h * 0.5), (w / 2 - h * 0.08, h), (-w / 2 + lean, h), (-w / 2, h * 0.62)])


def _icon_shapes(icon, s):
	"""Icon polygons centred on (0, 0), size s (about its height). Faceted, chunky, ours."""
	out = []
	if icon == "blades":  # two crossed blades with guards and grips
		L, t = s * 1.25, s * 0.12
		blade = [(-L / 2 + s * 0.28, -t), (L / 2 - s * 0.22, -t), (L / 2, 0), (L / 2 - s * 0.22, t), (-L / 2 + s * 0.28, t)]
		guard = [(-L / 2 + s * 0.24, -t * 2.6), (-L / 2 + s * 0.31, -t * 2.6), (-L / 2 + s * 0.31, t * 2.6), (-L / 2 + s * 0.24, t * 2.6)]
		grip = [(-L / 2, -t * 0.8), (-L / 2 + s * 0.24, -t * 0.8), (-L / 2 + s * 0.24, t * 0.8), (-L / 2, t * 0.8)]
		for a in (radians(40), radians(140)):
			for p in (blade, guard, grip):
				out.append(_rot(p, a))
	elif icon == "sparkle":  # a four-point star with a small twin
		for cx, cy, r in ((0, 0, s * 0.55), (s * 0.5, s * 0.42, s * 0.22)):
			pts = []
			for k in range(8):
				rr = r if k % 2 == 0 else r * 0.3
				a = radians(90 + 45 * k)
				pts.append((cx + rr * cos(a), cy + rr * sin(a)))
			out.append(pts)
	elif icon == "reticle":  # octagon ring, four ticks, a centre dot
		R, t = s * 0.42, s * 0.1
		o, i_ = oct_pts(R), oct_pts(R - t)
		for k in range(8):
			j = (k + 1) % 8
			out.append([i_[k], i_[j], o[j], o[k]])
		for a in range(4):
			out.append(_rot([(R - t * 0.5, -t * 0.5), (R + s * 0.18, -t * 0.5), (R + s * 0.18, t * 0.5), (R - t * 0.5, t * 0.5)], radians(90 * a)))
		out.append(oct_pts(t * 0.9))
	elif icon == "target":  # rings and a dart through them
		for R, t in ((s * 0.45, s * 0.09), (s * 0.24, s * 0.08)):
			o, i_ = oct_pts(R), oct_pts(R - t)
			for k in range(8):
				j = (k + 1) % 8
				out.append([i_[k], i_[j], o[j], o[k]])
		out.append(oct_pts(s * 0.07))
		out.append(_rot([(-s * 0.05, -s * 0.035), (s * 0.62, -s * 0.035), (s * 0.62, s * 0.035), (-s * 0.05, s * 0.035)], radians(-25)))
		out.append(_rot([(s * 0.5, -s * 0.14), (s * 0.72, -s * 0.02), (s * 0.72, s * 0.02), (s * 0.5, s * 0.14)], radians(-25)))
	elif icon == "crown":  # three points on a band
		w = s * 1.1
		out.append([(-w / 2, 0), (w / 2, 0), (w / 2, s * 0.22), (-w / 2, s * 0.22)])
		for cx, hh in ((-w / 2 + s * 0.16, s * 0.62), (0.0, s * 0.8), (w / 2 - s * 0.16, s * 0.62)):
			out.append([(cx - s * 0.17, s * 0.2), (cx + s * 0.17, s * 0.2), (cx + s * 0.04, hh), (cx - s * 0.04, hh)])
	elif icon == "star":  # five points
		pts = []
		for k in range(10):
			rr = s * 0.5 if k % 2 == 0 else s * 0.21
			a = radians(90 + 36 * k)
			pts.append((rr * cos(a), rr * sin(a)))
		out.append(pts)
	return [ccw(p) for p in out]


def sign(K, M, text, w, h, accent="E_Gold", tilt=13.0, lh=None, standoff=1.0, name="Sign", light=True, chevrons=True,
		shape="lean", icon=None, icon_at="left", icon_size=None, letters="E_White"):
	"""A glowing word sign over a doorway, in its own shape (plate_shape) with its own icon (_icon_shapes) that breaks
	the plate's outline on a dark backing. M: frame on the wall face at the sign's bottom centre (X right, Y up,
	Z out of the wall). Built tilted down at the viewer: dark plate, light grey rim, accent frame line, thick solid
	glowing letters, brackets back to the wall."""
	with C.grp(name, M, inst=False):
		F = S.FK(K, M)
		Mt = M @ T(0, 0, standoff) @ RX(tilt)
		P = S.FK(K, Mt)
		plate = plate_shape(shape, w, h)
		P["V_Dark"].prism(plate, 0, 0.7)
		S.ring_prism(P["V_Trim"], plate, inset(plate, 0.45), 0.7, 1.05)
		S.ring_prism(P[accent], inset(plate, 0.75), inset(plate, 0.98), 0.7, 0.82)
		isz = icon_size or h * 1.05
		ishift = 0.0
		if icon:
			ix = {"left": -w / 2 + isz * 0.35, "right": w / 2 - isz * 0.35, "top": 0.0}[icon_at]
			iy = h * 0.92 if icon_at == "top" else h * 0.5
			ishift = {"left": isz * 0.42, "right": -isz * 0.42, "top": 0.0}[icon_at]
			for k, poly in enumerate(_icon_shapes(icon, isz)):
				pts = [(x + ix, y + iy) for x, y in poly]
				P["V_Dark"].prism(inset(pts, -0.28) if len(pts) > 2 else pts, -0.05, 1.04)  # backing: the icon breaks the outline
				steel = icon == "blades" and k % 3 == 0  # blades read as steel with gold guards and grips
				P["V_Trim" if steel else accent].prism(ccw(pts), 1.04, 1.3)
		lh = lh or h * 0.5
		room = w - 2 * (h * 0.4 + 1.0) - (isz * 0.85 if icon and icon_at != "top" else 0.0)
		while S.text_width(text, lh, s=0.25) > room and lh > 0.5:
			lh *= 0.95
		tw = S.text_width(text, lh, s=0.25)
		S.add_text(P[letters], text, lh, 0.32, y0=(h - lh) / 2 - (h * 0.06 if icon_at == "top" and icon else 0.0), z0=0.7, x0=-tw / 2 + ishift, s=0.25, c=0.12, ci=0.05)
		for bx in (-w * 0.3, w * 0.3):
			top_out = standoff + h * sin(D(tilt))
			F["V_Steel"].ext_x(ccw([(h * 0.15, -0.6), (h * 0.15, standoff + 0.05), (h * 0.85, top_out - 0.1), (h * 0.95, -0.6)]), bx - 0.35, bx + 0.35)
		if light:
			S.light(M, 0, h * 0.3, standoff + 2.2, GLOW.get(accent, (WHITE,))[0], 0.8, 9)


# ---------------------------------------------------------------- fixtures
def bar_lamp(K, M, length=9.0, name="BarLamp", feed=3.0):
	"""Caged wall lamp (our take on RIVALS' bar lamps, built to read as a made object, not a pill): bolted steel back
	plate, a trapezoid housing, one long lens set behind a steel cage (two rails, four bars), angled end caps, a conduit
	from the top cap up into a junction box. A spot under it throws a pool on the floor. M: mount face, bottom centre."""
	L = length
	with C.grp(name, M, inst=True):
		F = S.FK(K, M)
		F["V_Steel"].prism(ccw(S.cut_rect(-1.3, 1.3, -0.6, L + 0.6, 0.5, 0.12)), 0, 0.2)
		for bx in (-0.95, 0.95):
			for by in (-0.3, L + 0.3):
				F["V_Trim"].box(bx - 0.14, bx + 0.14, by - 0.14, by + 0.14, 0.2, 0.32)
		F["V_Dark"].ext_y(ccw([(-1.0, 0.2), (-0.72, 0.95), (0.72, 0.95), (1.0, 0.2)]), 0.55, L - 0.55)
		for y0, y1 in ((0.0, 0.6), (L - 0.6, L)):
			F["V_Trim"].ext_y(ccw([(-1.12, 0.2), (-0.84, 1.12), (0.84, 1.12), (1.12, 0.2)]), y0, y1)
		F["E_White"].ext_y(ccw([(-0.5, 0.9), (-0.44, 1.0), (0.44, 1.0), (0.5, 0.9)]), 0.6, L - 0.6)
		for rx in (-0.62, 0.62):
			F["V_Steel"].box(rx - 0.09, rx + 0.09, 0.6, L - 0.6, 0.95, 1.16)
		for k in range(4):
			by = 0.6 + (L - 1.2) * (k + 0.5) / 4
			F["V_Steel"].box(-0.66, 0.66, by - 0.09, by + 0.09, 1.0, 1.18)
		if feed > 0:
			F["V_Steel"].pipe((0, L - 0.1, 0.6), (0, L + feed, 0.6), 0.2, n=8)
			F["V_Dark"].prism(ccw(S.cut_rect(-0.55, 0.55, L + feed, L + feed + 1.1, 0.25, 0.06)), 0.0, 1.0)
			F["V_Trim"].box(-0.3, 0.3, L + feed - 0.05, L + feed + 0.05, 0.3, 0.9)  # gland
	S.light(M, 0, -0.4, 1.8, WHITE, 1.5, 18, 110)


def gusset(K, M, x, y, z, depth=3.6, height=2.6, t=0.35):
	"""A steel knee brace in frame M: a cut triangle plate under a beam end (y = beam bottom, z = start), with bolts."""
	F = S.FK(K, M)
	F["V_Steel"].ext_x(ccw([(y - height, z), (y, z), (y, z + depth), (y - 0.5, z + depth), (y - height, z + 0.6)]), x - t / 2, x + t / 2)
	for by, bz in ((y - 0.6, z + 0.6), (y - 0.5, z + depth - 0.8)):
		F["V_Trim"].box(x - t / 2 - 0.08, x + t / 2 + 0.08, by - 0.14, by + 0.14, bz - 0.14, bz + 0.14)


def conduit(K, M, x0, x1, y, z=0.62, r=0.22, every=5.0, flanges=(True, True)):
	"""A conduit run along a wall (frame M), saddle clamps back to the wall, flanges where it enters a pier."""
	F = S.FK(K, M)
	F["V_Steel"].pipe((x0, y, z), (x1, y, z), r, n=8)
	n = max(1, int(abs(x1 - x0) // every))
	for k in range(n):
		cx = x0 + (x1 - x0) * (k + 0.5) / n
		F["V_Trim"].box(cx - 0.14, cx + 0.14, y - r - 0.12, y + r + 0.12, 0.0, z + r + 0.08)
		F["V_Steel"].box(cx - 0.3, cx + 0.3, y - r - 0.3, y + r + 0.3, 0.0, 0.12)
	for x, on in ((x0, flanges[0]), (x1, flanges[1])):
		if on:
			o = [(1.55 * r * cos(radians(22.5 + 45 * q)), 1.55 * r * sin(radians(22.5 + 45 * q))) for q in range(8)]
			F["V_Trim"].ext_x(ccw([(y + b, z + a) for a, b in o]), x - 0.15 if x == x0 else x - 0.15, x + 0.15)


def hazard_strip(K, M, x0, x1, y0, y1, z, step=1.2):
	"""Gold and dark diagonal stripes on the floor (frame M floor plane): a threshold mark."""
	F = S.FK(K, M)
	F["V_Base"].box(x0, x1, y0, y1, z, z + 0.03)
	w = y1 - y0
	x = x0
	while x < x1 - 0.2:
		a, b = x, min(x + step * 0.5, x1)
		F["V_GoldPaint"].prism(ccw([(a, y0), (b, y0), (min(b + w * 0.6, x1), y1), (min(a + w * 0.6, x1), y1)]), z + 0.03, z + 0.06)
		x += step


def down_light(K, M, x, y, z, rng=24, bright=1.6, angle=80, name="DownLight"):
	"""A hooded ceiling can at (x, y, z) of frame M (world-up must be M's +Z or the ceiling plane): the spot points down."""
	S.light(M, x, y, z - 0.6, WHITE, bright, rng, angle)


def board(K, M, w, h, kind, title, sub="", name="Board", accent="E_Gold"):
	"""A dark-cased screen on a wall (TV): case with big chamfers, light grey bezel, the screen face recorded for a
	SurfaceGui, a hood lamp over it. M: frame on the wall face at the board's bottom centre."""
	with C.grp(name, M, inst=False):
		F = S.FK(K, M)
		case = ccw(S.cham_rect(-w / 2, w / 2, 0, h, 0.18))
		F["V_Dark"].prism(case, 0, 1.1)
		for sx in (-1, 1):  # side ears bolted to the wall
			F["V_Steel"].prism(ccw([(sx * (w / 2 - 0.1), h * 0.25), (sx * (w / 2 + 0.9), h * 0.32), (sx * (w / 2 + 0.9), h * 0.68), (sx * (w / 2 - 0.1), h * 0.75)]), 0, 0.8)
			for by in (h * 0.4, h * 0.6):
				F["V_Trim"].box(sx * (w / 2 + 0.5) - 0.13, sx * (w / 2 + 0.5) + 0.13, by - 0.13, by + 0.13, 0.8, 0.92)
		F["V_Steel"].pipe((w * 0.32, h - 0.3, 0.5), (w * 0.32, h + 2.8, 0.5), 0.24, n=8)  # power feed: out of the case top...
		F["V_Trim"].ext_y(ccw(oct_pts(0.36)), h - 0.05, h + 0.35) if False else F["V_Trim"].box(w * 0.32 - 0.36, w * 0.32 + 0.36, h - 0.05, h + 0.3, 0.14, 0.86)  # gland
		F["V_Dark"].prism(ccw(S.cut_rect(w * 0.32 - 0.5, w * 0.32 + 0.5, h + 2.6, h + 3.6, 0.2, 0.05)), 0.0, 0.9)  # ...into a junction box on the wall
		S.ring_prism(F["V_Trim"], inset(case, 0.25), inset(case, 0.6), 1.1, 1.3)
		S.screen(kind, title, sub, M, 0, h / 2, 1.16, w - 1.6, h - 1.6)
		# hood lamp: a steel wedge over the top edge with a white lens underneath
		F["V_Steel"].ext_x(ccw([(h + 0.2, 0.2), (h + 0.2, 2.4), (h + 1.0, 2.6), (h + 1.3, 0.2)]), -w * 0.3, w * 0.3)
		F["E_White"].ext_x(ccw([(h + 0.24, 0.6), (h + 0.24, 2.1), (h + 0.36, 2.1), (h + 0.36, 0.6)]), -w * 0.28, w * 0.28)
		S.light(M, 0, h + 0.2, 3.2, WHITE, 0.9, 12)


def crate(K, M, w=5.0, d=4.0, h=3.2, name="Crate"):
	"""Equipment crate: chamfered body, two dark straps that wrap it, corner caps, a gold stencil plate."""
	with C.grp(name, M, inst=True):
		F = S.FK(K, M)
		F["V_Crate"].ext_y(ccw(S.cham_rect(-w / 2, w / 2, 0, h, 0.18)), -d / 2, d / 2)
		for sx in (-w * 0.28, w * 0.28):
			S.ring_prism(F["V_Strap"], ccw(S.cham_rect(-d / 2 - 0.08, d / 2 + 0.08, -0.04, h + 0.08, 0.22)),
				ccw(S.cham_rect(-d / 2 + 0.02, d / 2 - 0.02, 0.02, h - 0.02, 0.15)), sx - 0.35, sx + 0.35, plane="yz")
		F["V_GoldPaint"].box(-0.9, 0.9, -d / 2 - 0.05, -d / 2 + 0.02, h * 0.42, h * 0.72)
		F["V_Strap"].box(-w / 2 + 0.25, w / 2 - 0.25, -d / 2 + 0.3, d / 2 - 0.3, h - 0.02, h + 0.12)  # lid seam plate


def floor_text(K, M, text, h, mat="V_Paint", z=0.0):
	"""Stencil text lying on the floor: M's XY plane is the floor, text baseline along X, reading towards +Y."""
	b = S.FK(K, M)[mat]
	S.add_text(b, text, h, 0.04, y0=0.0, z0=z, s=0.2)  # solid letters: the stencil breaks read as glitches


def chevron(K, M, x, y, size, mat="V_Paint", z=0.0, depth=0.04, t=0.32):
	"""A floor chevron pointing +Y at (x, y) of frame M."""
	b = S.FK(K, M)[mat]
	a = size / 2
	pts = [(x - a, y - a * 0.6), (x, y + a * 0.4), (x + a, y - a * 0.6), (x + a, y - a * 0.6 + t * size), (x, y + a * 0.4 + t * size), (x - a, y - a * 0.6 + t * size)]
	b.prism(ccw(pts), z, z + depth)


# ---------------------------------------------------------------- wall runs (shared by every room)
def spans(x0, x1, cuts):
	out = [(x0, x1)]
	for c0, c1 in cuts:
		nxt = []
		for a, b in out:
			if c1 <= a or c0 >= b:
				nxt.append((a, b))
				continue
			if c0 > a:
				nxt.append((a, c0))
			if c1 < b:
				nxt.append((c1, b))
		out = nxt
	return [(a, b) for a, b in out if b - a > 0.05]


def wall_run(K, KD, M, x0, x1, H, ops=(), panel_skip=(), panels=True, t=4.0, crown=True, dx0=None, dx1=None):
	"""A wall in face frame M from x0 to x1, height H. ops: openings (x0, x1, y0, y1). Layers: slab (collides),
	plinth, battered wainscot panels, light belt ledge, big inset upper panels with a mid rail, stepped crown."""
	F = S.FK(K, M)
	FD = S.FK(KD, M)
	ys = sorted({0.0, H} | {o[2] for o in ops} | {min(o[3], H) for o in ops})
	for ylo, yhi in zip(ys, ys[1:]):
		cuts = [(o[0], o[1]) for o in ops if o[2] < yhi - 1e-6 and o[3] > ylo + 1e-6]
		for a, b in spans(x0, x1, cuts):
			F["V_Wall"].box(a, b, ylo, yhi, -t, 0)

	x0, x1 = (x0 if dx0 is None else max(x0, dx0)), (x1 if dx1 is None else min(x1, dx1))

	def band(y0, y1):
		return spans(x0, x1, [(o[0], o[1]) for o in ops if o[2] < y1 and o[3] > y0])

	for a, b in band(0, 1.4):
		FD["V_Base"].ext_x(ccw([(0, 0), (0, 0.7), (1.0, 0.7), (1.4, 0.38), (1.4, 0)]), a, b)
	for a, b in band(1.4, 9.0):
		n = max(1, round((b - a) / 7.5))
		w = (b - a) / n
		for k in range(n):
			p0, p1 = a + k * w + (0.11 if k else 0), a + (k + 1) * w - (0.11 if k < n - 1 else 0)
			FD["V_Low"].ext_x(ccw([(1.4, 0), (1.4, 0.55), (9.0, 0.26), (9.0, 0)]), p0, p1)
	for a, b in band(9.0, 10.0):
		FD["V_Trim"].ext_x(ccw([(9.0, 0), (9.0, 0.85), (9.55, 0.85), (10.0, 0.45), (10.0, 0)]), a, b)
	top = H - 4.0
	if panels:
		cuts = [(o[0] - 0.8, o[1] + 0.8) for o in ops if o[3] > 11.0] + list(panel_skip)
		for a, b in spans(x0 + 0.8, x1 - 0.8, cuts):
			n = max(1, round((b - a) / 11.0))
			w = (b - a) / n
			for k in range(n):
				p0, p1 = a + k * w + 0.5, a + (k + 1) * w - 0.5
				if p1 - p0 < 2.0:
					continue
				FD["V_Panel"].prism(ccw(S.cut_rect(p0, p1, 11.2, top - 0.8, 1.5, 0.3)), 0, 0.32)
				ym = (11.2 + top - 0.8) / 2
				FD["V_Trim"].prism(ccw(S.cham_rect(p0 + 1.7, p1 - 1.7, ym - 0.25, ym + 0.25, 0.08)), 0.32, 0.46)
	if crown:
		for a, b in band(top, H):
			FD["V_Trim"].ext_x(ccw([(top, 0), (top, 0.55), (top + 0.8, 0.55), (top + 0.8, 0)]), a, b)
			FD["V_Wall"].ext_x(ccw([(top + 0.8, 0), (top + 0.8, 0.6), (top + 2.6, 1.8), (H, 1.8), (H, 0)]), a, b)


def pier_at(K, KD, M, H, area, lamp=True, w=3.6, d=3.1, name="Pier"):
	"""A pier standing against a wall (frame M on the wall face, Z out): flared foot, shaft, trim flare, capital,
	a channel with a bar lamp, a down-light from the head. Hand collider inside the shaft."""
	with C.grp(name, M, inst=True):
		F = S.FK(KD, M)
		S.collider(area, M, -w + 0.6, w - 0.6, 0.0, H, -1.0, d - 0.5, "B")
		F["V_Base"].ext_y(ccw(S.cham_rect(-w - 0.7, w + 0.7, -1.0, d + 0.7, 0.45)), 0, 1.8)
		F["V_Wall"].ext_y(ccw(S.cham_rect(-w, w, -1.0, d, 0.6)), 1.8, H - 5.4)
		S.taper_y(F["V_Trim"], (-w, w, -1.0, d), H - 5.4, (-w - 0.7, w + 0.7, -1.0, d + 0.8), H - 4.25)
		F["V_Wall"].ext_y(ccw(S.cham_rect(-w - 0.7, w + 0.7, -1.0, d + 0.8, 0.5)), H - 4.25, H)
		F["V_Trim"].ext_y(ccw(S.cham_rect(-w - 0.3, w + 0.3, -1.0, d + 0.3, 0.2)), 8.9, 9.9)  # collar at the belt line
		if lamp:
			F["V_Low"].ext_y(ccw(S.cham_rect(-1.5, 1.5, d - 0.2, d + 0.25, 0.08)), 10.6, 22.4)
	if lamp:
		bar_lamp(KD, M @ T(0, 11.2, d + 0.25), length=10.6, feed=max(0.0, H - 5.4 - 11.2 - 10.6 - 1.4))
	S.light(M, 0, H - 4.6, d + 2.2, WHITE, 1.3, 30, 75)


# ---------------------------------------------------------------- rooms (Locker, Shop): shell, mouth, display niches
def wframe(origin, xdir, z0=0.0):
	"""Wall face frame at origin (floor level z0): X along xdir, Z into the room (right of xdir seen from above)."""
	x = Vector(xdir).normalized()
	return S.face((origin[0], origin[1], z0), (x.x, x.y, 0), (x.y, -x.x, 0))


def cframe(p, zin, z0=0.0):
	z = Vector(zin).normalized()
	return S.face((p[0], p[1], z0), (-z.y, z.x, 0), (z.x, z.y, 0))


def room(K, KD, area, x0, x1, y0, y1, H, ops=None, skips=None, beams_x=(), z0=0.0, inset=0.0):
	"""A rectangular room: four wall runs (ops / skips per wall: 'S', 'N', 'W', 'E', in each wall's local x), corner
	piers, a ceiling slab with beams across X at beams_x and light panels between, a slab floor with plates.
	Returns the wall frames {side: (M, length)}."""
	ops, skips = ops or {}, skips or {}
	W, D = x1 - x0, y1 - y0
	walls = {"S": (wframe((x1, y0), (-1, 0), z0), W), "N": (wframe((x0, y1), (1, 0), z0), W),
		"W": (wframe((x0, y0), (0, 1), z0), D), "E": (wframe((x1, y1), (0, -1), z0), D)}
	for side, (M, L) in walls.items():
		ext = 4.0 if side in "SN" else 0.0
		run(K, KD, M, -ext, L + ext, H, ops.get(side, []), skips.get(side, []), dx0=2.0 + inset, dx1=L - 2.0 - inset)
	for p, zin in (((x0, y0), (1, 1)), ((x1, y0), (-1, 1)), ((x1, y1), (-1, -1)), ((x0, y1), (1, -1))):
		if inset <= 0.0:  # an octagon's corners are behind its diagonal walls
			pier_at(K, KD, cframe(p, zin, z0), H, area, w=2.8, d=3.0, name="CornerPier")
	z = z0 + H
	ym_, vhw = (y0 + y1) / 2, min(8.0, max((y1 - y0) / 6, 6.0))  # narrow halls still get a real vault
	slab_with_hole(K, x0 - 4, x1 + 4, y0 - 4, y1 + 4, x0 + 4.0, x1 - 4.0, ym_ - vhw, ym_ + vhw, z)
	Mv = Matrix.Translation((0.0, ym_, 0.0)) @ Matrix.Rotation(radians(-90), 4, "Z")  # local u = -world y, v = world x
	nave_vault(K, KD, Mv, vhw, x0 + 4.0, x1 - 4.0, z, rise=7.0, top=max(vhw - 4.0, 2.6), lamp=(max(vhw - 4.0, 2.6) - 1.0, 5.0), name="RoomVault")  # lamp = (across the vault, along it)
	with C.grp("Floor"):
		K["V_Slab"].box(x0 - 4, x1 + 4, y0 - 4, y1 + 4, z0 - 1.2, z0 - 0.02)
		nx, ny = max(1, round(W / 12)), max(1, round(D / 12))
		for i in range(nx):
			for j in range(ny):
				ax, bx = x0 + W * i / nx, x0 + W * (i + 1) / nx
				ay, by = y0 + D * j / ny, y0 + D * (j + 1) / ny
				KD["V_Floor" if (i + j) % 2 == 0 else "V_Floor2"].box(ax + 0.125, bx - 0.125, ay + 0.125, by - 0.125, z0, z0 + 0.12)
	xs = [x0] + list(beams_x) + [x1]
	for bx in beams_x:
		with C.grp("Beam"):
			KD["V_Beam"].ext_y(ccw([(bx - 1.4, z + 0.25), (bx - 1.4, z - 1.6), (bx - 0.8, z - 2.3), (bx + 0.8, z - 2.3), (bx + 1.4, z - 1.6), (bx + 1.4, z + 0.25)]), y0, y1)
	for a, b in zip(xs, xs[1:]):
		xm = (a + b) / 2
		hw_, ym = min(5.0, (b - a) / 2 - 3), (y0 + y1) / 2
		avail = (y1 - y0) / 2 - vhw - 2.4  # between the vault rim and the wall crown
		ly, lhd = vhw + avail / 2, max(0.8, min(1.6, avail / 2 - 0.9))
		for sy in (-1, 1):  # side lamps either side of the vault (the middle is lit from the vault top)
			ceiling_lamp(KD, xm, ym + sy * ly, z, hw_, lhd)
			S.light(Matrix.Identity(4), xm, ym + sy * ly, z - 0.4, WHITE, 1.2, 30, 85)
	for side in "NS":
		M, L = walls[side]
		conduit(KD, M, 3.4 + inset, L - 3.4 - inset, H - 4.4)
	return walls


def ceiling_lamp(KD, x, y, z, hw, hd):
	"""A housed ceiling panel: a dark stepped frame, a recessed lens, three steel grille bars (not a floating card)."""
	G = KD
	S.ring_prism(G["V_Dark"], ccw(S.cham_rect(x - hw - 0.7, x + hw + 0.7, y - hd - 0.7, y + hd + 0.7, 0.3)), ccw(S.cham_rect(x - hw, x + hw, y - hd, y + hd, 0.2)), z - 0.55, z + 0.05)
	G["E_White"].prism(ccw(S.cham_rect(x - hw, x + hw, y - hd, y + hd, 0.2)), z - 0.3, z - 0.15)
	for k in (-1, 0, 1):
		G["V_Steel"].box(x + k * hw * 0.5 - 0.1, x + k * hw * 0.5 + 0.1, y - hd, y + hd, z - 0.52, z - 0.3)


def run(K, KD, M, x0, x1, H, ops, skips, dx0=None, dx1=None):
	wall_run(K, KD, M, x0, x1, H, ops, panel_skip=skips, dx0=dx0, dx1=dx1)


def mouth(KD, M, hw, h, rings=(1.5, 1.3, 1.2), cut=2.4, depth=4.2, y0=0.0):
	"""The room side of a hub doorway: the same stepped rings, the lining carried through the room's wall."""
	a, b, c = rings
	h1, h2, h3 = hw - a, hw - a - b, hw - a - b - c
	v1, v2, v3 = h - a + 0.1, h - a - b + 0.1, h - a - b - c + 0.1
	F = S.FK(KD, M)
	S.u_frame(F["V_Trim"], hw, h, h1, v1, -1.0, 1.6, ci=cut + 0.4, y0=y0)
	S.u_frame(F["V_Wall"], h1, v1, h2, v2, -3.0, 0.9, co=cut + 0.4, ci=cut + 0.2, y0=y0)
	S.u_frame(F["V_Low"], h2, v2, h3, v3, -depth, 0.3, co=cut + 0.2, ci=cut, y0=y0)
	S.light(M, 0, v3 - 0.8, 4.5, WHITE, 1.4, 20, 80)


def niche(K, KD, M, u, w, label, guns, accent, area, sill=3.6, top=13.0, depth=3.2):
	"""A display cabinet standing against a wall (frame M, centred at u), so the wall trims run on behind it untouched:
	a base cabinet with a kick and a light lip, a lined glass case with a white wash under its cap, a light grey front
	frame, an accent strip, a label plate on the cap, real guns resting inside (S.gun_row). Returns its panel skip."""
	B = M @ T(u, 0, 0)
	hw = w / 2
	z0, z1 = 0.85, 0.85 + depth
	with C.grp("Case_" + label.title(), B):
		F, G = S.FK(K, B), S.FK(KD, B)
		F["V_Wall"].box(-hw - 0.6, hw + 0.6, 0.5, sill - 0.2, z0, z1 + 0.3)
		G["V_Base"].box(-hw - 0.4, hw + 0.4, 0.0, 0.5, z0, z1)
		G["V_Trim"].box(-hw - 0.7, hw + 0.7, sill - 0.2, sill, z0, z1 + 0.42)
		G["V_Panel"].box(-hw, hw, sill, top, z0, z0 + 0.25)  # a lighter back so the guns read
		for sx in (-1, 1):
			G["V_Dark"].box(sx * hw, sx * (hw + 0.6), sill, top, z0, z1)
		G["V_Wall"].box(-hw - 0.6, hw + 0.6, top, top + 1.1, z0, z1 + 0.3)
		G["V_Trim"].box(-hw - 0.7, hw + 0.7, top + 1.1, top + 1.3, z0, z1 + 0.42)
		G["E_White"].box(-hw + 0.4, hw - 0.4, top - 0.25, top - 0.05, z0 + 0.4, z1 - 0.3)
		S.ring_prism(G["V_Trim"], ccw(S.cham_rect(-hw - 0.6, hw + 0.6, sill, top, 0.01)), ccw(S.cham_rect(-hw + 0.15, hw - 0.15, sill + 0.15, top - 0.15, 0.25)), z1, z1 + 0.35)
		G["Glass"].box(-hw + 0.1, hw - 0.1, sill + 0.1, top - 0.1, z1 - 0.12, z1 - 0.02)
		G[PAINT.get(accent, accent)].box(-hw + 0.5, hw - 0.5, sill - 0.75, sill - 0.5, z1 + 0.3, z1 + 0.42)
		S.add_text(G["E_White"], label, 0.8, 0.08, y0=top + 0.15, z0=z1 + 0.3, s=0.22, c=0.06, ci=0.02, track=0.16)
		S.collider(area, B, -hw - 0.4, hw + 0.4, 0.0, sill - 0.4, z0 + 0.1, z1 + 0.2, "B")  # inside the base only
		S.collider(area, B, -hw - 0.4, hw + 0.4, sill - 0.4, top + 1.1, z0 + 0.1, z1 + 0.2, "Y")  # invisible keep-out over the glass
		S.light(B, 0, top - 1.2, z0 + depth / 2, WHITE, 1.6, 12)
		import sw_locker
		R = B.to_3x3()
		for gid, sc, yy in guns:  # one gun per shelf height, centred, scaled to fit the case
			L, _h = sw_locker.gun_box(gid)
			sc = min(sc, (w - 2.4) / max(L, 0.1))
			p = B @ Vector((0.0, yy, z0 + depth / 2))
			G["V_Steel"].box(-L * sc * 0.32, L * sc * 0.32, yy - 0.16, yy, z0 + depth / 2 - 0.35, z0 + depth / 2 + 0.35)  # the rail it rests on
			for rx in (-L * sc * 0.28, L * sc * 0.28):
				G["V_Steel"].box(rx - 0.12, rx + 0.12, yy - 0.16, yy - 0.04, z0 + 0.25, z0 + depth / 2 - 0.35)  # arms back to the case
			t = R @ Vector((1, 0, 0))
			S.gun_row([gid, sc, round(p.x, 3), round(p.y, 3), round(p.z, 3), round(t.x, 4), round(t.y, 4), 0, 0])
	return (u - hw - 1.4, u + hw + 1.4)


# ---------------------------------------------------------------- the little things (owner 2026-11-16: vents, warning
# signs, lights and accents are what pull RIVALS together): our own versions, faceted, bolted, connected to the wall
def vent(K, M, x, y, w=3.2, h=2.4, slats=5):
	"""A wall vent in frame M (wall face, centre x, bottom y): a body seated into the wall, a faceted frame with cut
	corners, a dark recess, angled louvre slats, four bolts."""
	F = S.FK(K, M)
	x0, x1, y0, y1 = x - w / 2, x + w / 2, y, y + h
	F["V_Wall"].box(x0 + 0.1, x1 - 0.1, y0 + 0.1, y1 - 0.1, -0.2, 0.75)
	S.ring_prism(F["V_Trim"], ccw(S.cut_rect(x0, x1, y0, y1, 0.45, 0.12)), ccw(S.cut_rect(x0 + 0.32, x1 - 0.32, y0 + 0.32, y1 - 0.32, 0.3, 0.06)), 0.6, 1.0)
	F["V_Base"].box(x0 + 0.3, x1 - 0.3, y0 + 0.3, y1 - 0.3, 0.6, 0.66)
	for k in range(slats):
		sy = y0 + 0.45 + (h - 0.9) * (k + 0.5) / slats
		F["V_Steel"].ext_x(ccw([(sy - 0.14, 0.66), (sy - 0.02, 0.66), (sy + 0.16, 0.92), (sy + 0.04, 0.92)]), x0 + 0.32, x1 - 0.32)
	for bx in (x0 + 0.2, x1 - 0.2):
		for by in (y0 + 0.2, y1 - 0.2):
			F["V_Steel"].box(bx - 0.08, bx + 0.08, by - 0.08, by + 0.08, 1.0, 1.08)


def plaque(K, M, x, y, w, h, kind, title, lines):
	"""A printed safety plaque in frame M (wall face): a thin steel backer with bolts; the print is a SurfaceGui."""
	F = S.FK(K, M)
	F["V_Steel"].prism(ccw(S.cham_rect(x - w / 2 - 0.15, x + w / 2 + 0.15, y - 0.15, y + h + 0.15, 0.08)), 0.55, 0.75)
	F["V_Wall"].box(x - w / 2 + 0.3, x + w / 2 - 0.3, y + 0.3, y + h - 0.3, -0.2, 0.56)  # seat into the wall
	for bx in (x - w / 2 + 0.05, x + w / 2 - 0.05):
		F["V_Trim"].box(bx - 0.07, bx + 0.07, y + h / 2 - 0.07, y + h / 2 + 0.07, 0.75, 0.82)
	S.screen(kind, title, "|".join(lines), M, x, y + h / 2, 0.79, w, h)


def beacon(K, M, x, y, z=0.0):
	"""An alarm beacon on a wall bracket: steel base plate, an 8-sided red lens in a cage, a light."""
	F = S.FK(K, M)
	F["V_Steel"].prism(ccw(S.cut_rect(x - 0.6, x + 0.6, y - 0.6, y + 0.6, 0.2, 0.05)), z + 0.5, z + 0.7)
	F["V_Dark"].ext_x(ccw([(y - 0.35, z + 0.7), (y - 0.35, z + 1.2), (y + 0.35, z + 1.2), (y + 0.35, z + 0.7)]), x - 0.35, x + 0.35)
	Mb = M @ T(x, y, z + 1.55) @ RX(90)
	B = S.FK(K, Mb)
	B["E_Alarm"].prism(ccw(oct_pts(0.42)), -0.45, 0.45)
	for k in range(4):
		a = radians(45 + 90 * k)
		B["V_Steel"].box(0.5 * cos(a) - 0.05, 0.5 * cos(a) + 0.05, 0.5 * sin(a) - 0.05, 0.5 * sin(a) + 0.05, -0.5, 0.5)
	B["V_Dark"].prism(ccw(oct_pts(0.36)), 0.45, 0.6)
	S.light(M, x, y, z + 2.4, "#FF4A5A", 0.6, 8)


def stage_spot(K, center, ang, r, z, aim):
	"""A stage spot hung under a truss: clamp, yoke, an 8-sided can tilted down at the aim point, a lens."""
	c, s = cos(ang), sin(ang)
	p = Vector((center[0] + r * c, center[1] + r * s, z))
	d = (Vector(aim) - p).normalized()
	F = S.FK(K, Matrix.Identity(4))
	F["V_Dark"].box(p.x - 0.25, p.x + 0.25, p.y - 0.25, p.y + 0.25, z - 0.1, z + 0.35)  # clamp
	F["V_Steel"].pipe((p.x, p.y, z - 0.1), (p.x, p.y, z - 0.6), 0.12, n=6)  # yoke stem
	can0 = p + Vector((0, 0, -1.0)) - d * 0.5
	can1 = p + Vector((0, 0, -1.0)) + d * 0.75
	F["V_Dark"].pipe(tuple(can0), tuple(can1), 0.4, n=8)
	F["V_Trim"].pipe(tuple(can1 - d * 0.05), tuple(can1 + d * 0.12), 0.47, n=8)
	F["E_White"].pipe(tuple(can1 + d * 0.1), tuple(can1 + d * 0.16), 0.32, n=8)
	for side in (-1, 1):  # yoke arms
		q = Vector((-s, c, 0)) * 0.62 * side
		F["V_Steel"].pipe((p.x + q.x, p.y + q.y, z - 0.6), (p.x + q.x, p.y + q.y, z - 1.1), 0.08, n=6)
	F["V_Steel"].pipe((p.x - s * 0.62, p.y + c * 0.62, z - 0.6), (p.x + s * 0.62, p.y - c * 0.62, z - 0.6), 0.08, n=6)


def truss_ring(K, center, r, z0, z1, ceiling, n_seg=8, diag=4):
	"""An octagonal box truss hung on rods: two chord rings, zigzag web members, hangers up to the ceiling."""
	F = S.FK(K, Matrix.Identity(4))
	pts = lambda rr, zz: [Vector((center[0] + rr * cos(radians(45 * k)), center[1] + rr * sin(radians(45 * k)), zz)) for k in range(n_seg)]  # nodes between the radial beams
	for rr in (r - 0.6, r + 0.6):
		lo, hi = pts(rr, z0), pts(rr, z1)
		for k in range(n_seg):
			j = (k + 1) % n_seg
			F["V_Dark"].pipe(tuple(lo[k]), tuple(lo[j]), 0.16, n=6)
			F["V_Dark"].pipe(tuple(hi[k]), tuple(hi[j]), 0.16, n=6)
			for q in range(diag):
				a = lo[k].lerp(lo[j], q / diag)
				b = hi[k].lerp(hi[j], (q + 0.5) / diag)
				c2 = lo[k].lerp(lo[j], (q + 1) / diag)
				F["V_Steel"].pipe(tuple(a), tuple(b), 0.07, n=6)
				F["V_Steel"].pipe(tuple(b), tuple(c2), 0.07, n=6)
	lo_in, lo_out, hi_in, hi_out = pts(r - 0.6, z0), pts(r + 0.6, z0), pts(r - 0.6, z1), pts(r + 0.6, z1)
	for k in range(n_seg):  # rungs across the box at every node, a hanger rod to the ceiling with a plate
		F["V_Steel"].pipe(tuple(lo_in[k]), tuple(lo_out[k]), 0.08, n=6)
		F["V_Steel"].pipe(tuple(hi_in[k]), tuple(hi_out[k]), 0.08, n=6)
		m = (hi_in[k] + hi_out[k]) / 2
		F["V_Steel"].pipe(tuple(m), (m.x, m.y, ceiling + 0.2), 0.1, n=6)
		F["V_Steel"].box(m.x - 0.45, m.x + 0.45, m.y - 0.45, m.y + 0.45, ceiling - 0.15, ceiling + 0.05)


def showcase(K, KD, area, x, y, gun, scale, accent="E_Gold", name="Showcase", spin=14):
	"""A display stand (our answer to RIVALS' hologram stands, with real objects): a faceted plinth with a kick, an
	accent ring, a light grey cap, a steel turntable, a real gun turning on it, a down-light. World position x, y."""
	M = Matrix.Translation((x, y, 0.0))
	with C.grp(name, M):
		F, G = S.FK(K, M), S.FK(KD, M)
		F["V_Base"].prism(ccw(oct_pts(2.9)), 0.0, 0.6)
		F["V_Wall"].solid([(a, b, 0.6) for a, b in ccw(oct_pts(2.4))], [(a, b, 2.6) for a, b in ccw(oct_pts(2.1))])
		o, i = oct_pts(2.3), oct_pts(2.05)
		for k in range(8):
			j = (k + 1) % 8
			G[PAINT.get(accent, accent)].prism(ccw([i[k], i[j], o[j], o[k]]), 1.9, 2.05)
		G["V_Trim"].prism(ccw(oct_pts(2.3)), 2.6, 2.85)
		G["V_Steel"].prism(ccw(oct_pts(1.8)), 2.85, 3.0)
		S.gun_row([gun, scale, x, y, 3.0, 1.0, 0.0, 0, spin])  # rests on the turntable
		S.light(Matrix.Identity(4), x, y, 11.0, WHITE, 3.0, 14, 34)


def arcade(K, KD, M, x, title="TARGET RUN", name="Arcade"):
	"""A standing game cabinet against a wall (frame M, centred at x): faceted side profile, a set-back screen
	(SurfaceGui), a marquee with gold letters, a control deck with buttons and a stick, side stripes, a kick plate."""
	Mx = M @ T(x, 0, 0)
	prof = ccw([(0.0, 0.9), (0.0, 3.6), (3.0, 3.6), (3.4, 3.1), (3.4, 2.6), (4.0, 2.0), (6.8, 2.0), (6.9, 2.6), (7.8, 2.6), (8.0, 2.2), (8.0, 0.9)])
	with C.grp(name, Mx):
		F, G = S.FK(K, Mx), S.FK(KD, Mx)
		F["V_Wall"].ext_x(prof, -1.45, 1.45)
		for sx in (-1, 1):
			G["V_Dark"].ext_x(ccw([(0.05, 0.85), (0.05, 3.7), (3.05, 3.7), (3.5, 3.12), (3.5, 2.55), (4.05, 1.95), (6.75, 1.95), (6.85, 2.65), (7.85, 2.65), (8.05, 2.2), (8.05, 0.85)]), sx * 1.45, sx * 1.62)
			G["E_Gold"].ext_x(ccw([(0.9, 3.1), (1.2, 3.4), (6.6, 1.25), (6.3, 0.95)]), sx * 1.62, sx * 1.66)  # side stripe
		G["V_Base"].box(-1.4, 1.4, 0.0, 0.5, 2.8, 3.66)  # kick plate
		G["V_Dark"].box(-1.3, 1.3, 4.1, 6.7, 1.9, 2.02)  # screen bezel
		S.screen("notice", title, "HIGH SCORE|00000", Mx, 0, 5.4, 2.06, 2.4, 2.4)
		G["V_Dark"].box(-1.4, 1.4, 6.95, 7.75, 2.55, 2.66)
		S.add_text(G["E_Gold"], title, 0.42, 0.06, y0=7.14, z0=2.66, s=0.22, c=0.05, ci=0.02, track=0.14)
		for k, bx in enumerate((-0.2, 0.35, 0.9)):  # buttons
			G["E_White" if k == 1 else "E_Gold"].prism(ccw([(bx + 0.18 * cos(radians(22.5 + 45 * q)), 2.4 + 0.18 * sin(radians(22.5 + 45 * q))) for q in range(8)]), 3.6, 3.72) if False else None
			Mb = Mx @ T(bx, 3.6, 2.3) @ RX(-90)
			S.FK(KD, Mb)["E_White" if k == 1 else "E_Gold"].prism(ccw(oct_pts(0.17)), 0.0, 0.12)
		S.FK(KD, Mx @ T(-0.85, 3.6, 2.2) @ RX(-90))["V_Steel"].prism(ccw(oct_pts(0.06)), 0.0, 0.55)  # stick
		S.FK(KD, Mx @ T(-0.85, 3.6, 2.2) @ RX(-90))["E_Coral"].prism(ccw(oct_pts(0.17)), 0.55, 0.8) if False else S.FK(KD, Mx @ T(-0.85, 3.6, 2.2) @ RX(-90))["V_Dark"].prism(ccw(oct_pts(0.17)), 0.55, 0.8)
		S.light(Mx, 0, 5.4, 4.0, WHITE, 0.6, 8)



def hard_case(K, M, w=4.6, d=1.6, h=0.9, name="HardCase"):
	"""A rugged gun case lying flat: ribbed shell with cut corners, a lid seam, two latches, a handle, corner guards."""
	with C.grp(name, M, inst=True):
		F = S.FK(K, M)
		F["V_Dark"].ext_y(ccw(S.cham_rect(-w / 2, w / 2, 0.0, h, 0.16)), -d / 2, d / 2)
		F["V_Strap"].ext_y(ccw(S.cham_rect(-w / 2 - 0.03, w / 2 + 0.03, h * 0.48, h * 0.56, 0.02)), -d / 2 - 0.03, d / 2 + 0.03)  # lid seam
		for lx in (-w * 0.3, w * 0.3):
			F["V_Trim"].box(lx - 0.18, lx + 0.18, -d / 2 - 0.08, -d / 2 + 0.02, h * 0.3, h * 0.75)  # latches
		F["V_Steel"].box(-0.45, 0.45, -d / 2 - 0.14, -d / 2 - 0.04, h * 0.42, h * 0.62)  # handle
		F["V_GoldPaint"].box(-w * 0.12, w * 0.12, -0.3, 0.3, h - 0.01, h + 0.02)  # stencil plate on the lid
		for cx in (-w / 2 + 0.2, w / 2 - 0.2):
			F["V_Steel"].box(cx - 0.22, cx + 0.22, -d / 2 - 0.02, d / 2 + 0.02, -0.0, 0.22)  # corner feet


def prop_group(K, M, items):
	"""An odd-numbered group of crates and hard cases against a wall (frame M on the floor, X along the wall,
	Y away from it). items: [(kind, x, y, z, yaw)]."""
	for kind, x, y, z, yaw in items:
		Mi = M @ T(x, y, z) @ Matrix.Rotation(radians(yaw), 4, "Z")
		if kind == "crate":
			crate(K, Mi)
		elif kind == "crate_s":
			crate(K, Mi, w=3.6, d=3.2, h=2.6, name="CrateSmall")
		else:
			hard_case(K, Mi)



def grate(K, M, x0, x1, y0, y1, z, pitch=0.55):
	"""A floor grate strip (frame M floor plane): a dark frame and steel ribs across it."""
	F = S.FK(K, M)
	S.ring_prism(F["V_Steel"], ccw(S.cham_rect(x0, x1, y0, y1, 0.08)), ccw(S.cham_rect(x0 + 0.25, x1 - 0.25, y0 + 0.25, y1 - 0.25, 0.04)), z, z + 0.08)
	F["V_Slab"].box(x0 + 0.25, x1 - 0.25, y0 + 0.25, y1 - 0.25, z - 0.1, z + 0.01)
	along_x = (x1 - x0) >= (y1 - y0)
	n = int(((x1 - x0) if along_x else (y1 - y0)) // pitch)
	for k in range(1, n):
		if along_x:
			c = x0 + k * (x1 - x0) / n
			F["V_Steel"].box(c - 0.07, c + 0.07, y0 + 0.25, y1 - 0.25, z, z + 0.06)
		else:
			c = y0 + k * (y1 - y0) / n
			F["V_Steel"].box(x0 + 0.25, x1 - 0.25, c - 0.07, c + 0.07, z, z + 0.06)


def drop_stand(K, KD, area, x, y, name="DailyDrop"):
	"""A supply-drop stand: a stepped plinth with gold corner lights, a big strapped crate on it, a beacon post and a
	notice plaque. Decoration now; a reward hook can be tagged on it later."""
	M = Matrix.Translation((x, y, 0.0))
	with C.grp(name, M):
		F, G = S.FK(K, M), S.FK(KD, M)
		F["V_Base"].prism(ccw(S.cham_rect(-3.6, 3.6, -3.0, 3.0, 0.6)), 0.0, 0.6)
		F["V_Wall"].prism(ccw(S.cham_rect(-3.1, 3.1, -2.5, 2.5, 0.5)), 0.6, 1.4)
		G["V_Trim"].prism(ccw(S.cham_rect(-3.2, 3.2, -2.6, 2.6, 0.5)), 1.3, 1.45)
		for cx in (-2.7, 2.7):
			for cy in (-2.1, 2.1):
				G["V_GoldPaint"].prism(ccw(oct_pts(0.22)), 1.45, 1.55)
	crate(KD, M @ T(0, 0, 1.45), w=4.4, d=3.4, h=3.0, name="DropCrate")
	S.collider(area, M, -2.0, 2.0, -1.5, 1.5, 1.6, 4.3, "B")
	with C.grp(name + "Beacon", M):
		G = S.FK(KD, M)
		G["V_Steel"].pipe((3.0, 2.2, 1.45), (3.0, 2.2, 6.2), 0.14, n=8)
		Mb = M @ T(3.0, 2.2, 6.6)
		S.FK(KD, Mb)["E_Gold"].prism(ccw(oct_pts(0.4)), -0.4, 0.4)
		S.FK(KD, Mb)["V_Dark"].prism(ccw(oct_pts(0.32)), 0.4, 0.55)
	S.light(Matrix.Identity(4), x, y, 11.0, WHITE, 2.4, 14, 40)



def gun_table(K, KD, area, M, guns, accent="E_Violet", w=9.0, d=3.6, name="GunTable"):
	"""A display table (frame M on the floor, X along the table): a faceted top with a dark mat and a painted accent
	edge, two A-frame steel legs with a cross bar, a lower shelf with ammo boxes, guns standing on little stands."""
	with C.grp(name, M):
		F, G = S.FK(K, M), S.FK(KD, M)
		top = 3.1
		F["V_Wall"].prism(ccw(S.cham_rect(-w / 2, w / 2, -d / 2, d / 2, 0.3)), top - 0.35, top)
		G["V_Trim"].prism(ccw(S.cham_rect(-w / 2 - 0.12, w / 2 + 0.12, -d / 2 - 0.12, d / 2 + 0.12, 0.32)), top - 0.5, top - 0.35)
		G["V_Dark"].prism(ccw(S.cham_rect(-w / 2 + 0.35, w / 2 - 0.35, -d / 2 + 0.35, d / 2 - 0.35, 0.2)), top, top + 0.06)
		G[PAINT.get(accent, accent)].box(-w / 2 + 0.4, w / 2 - 0.4, -d / 2 - 0.13, -d / 2 - 0.05, top - 0.45, top - 0.2)
		for lx in (-w / 2 + 0.9, w / 2 - 0.9):
			G["V_Steel"].ext_x(ccw([(-d / 2 + 0.2, 0.0), (-d / 2 + 0.75, 0.0), (-0.12, top - 0.5), (0.12, top - 0.5), (d / 2 - 0.75, 0.0), (d / 2 - 0.2, 0.0), (0.2, top - 0.2), (-0.2, top - 0.2)]), lx - 0.18, lx + 0.18)
		G["V_Steel"].box(-w / 2 + 0.9, w / 2 - 0.9, -0.15, 0.15, 1.0, 1.25)
		G["V_Base"].box(-w / 2 + 1.2, w / 2 - 1.2, -d / 2 + 0.6, d / 2 - 0.6, 1.25, 1.4)  # lower shelf
		for k, bx in enumerate((-w / 2 + 2.0, -w / 2 + 3.4, w / 2 - 2.4)):
			G["V_Crate"].box(bx - 0.55, bx + 0.55, -0.5, 0.5, 1.4, 2.2 - 0.15 * k)
			G["V_GoldPaint"].box(bx - 0.25, bx + 0.25, -0.53, -0.5, 1.6, 1.9 - 0.15 * k)
		S.collider(area, M, -w / 2 + 0.2, w / 2 - 0.2, -d / 2 + 0.2, d / 2 - 0.2, 0.0, top, "B")
		import sw_locker
		R = M.to_3x3()
		n = len(guns)
		for k, (gid, sc) in enumerate(guns):
			gx = -w / 2 + w * (k + 0.5) / n
			G["V_Steel"].prism(ccw(S.cham_rect(gx - 0.5, gx + 0.5, -0.35, 0.35, 0.12)), top + 0.06, top + 0.32)
			L, _h = sw_locker.gun_box(gid)
			sc = min(sc, (w / n - 0.6) / max(L, 0.1))
			p = M @ Vector((gx, 0.0, top + 0.32))
			t = R @ Vector((1, 0, 0))
			S.gun_row([gid, sc, round(p.x, 3), round(p.y, 3), round(p.z, 3), round(t.x, 4), round(t.y, 4), 0, 0])
		S.light(M, 0, 0, 11.0, WHITE, 1.6, 14, 50)


def poster(K, M, x, y, w, h, title, sub, name="Poster"):
	"""A printed poster on the wall: a thin dark backer with corner clips; the print is a SurfaceGui."""
	with C.grp(name, M @ T(x, y, 0)):
		F = S.FK(K, M)
		F["V_Dark"].prism(ccw(S.cham_rect(x - w / 2 - 0.15, x + w / 2 + 0.15, y - 0.15, y + h + 0.15, 0.1)), 0.55, 0.72)
		F["V_Wall"].box(x - w / 2 + 0.3, x + w / 2 - 0.3, y + 0.3, y + h - 0.3, -0.2, 0.56)
		for cx in (x - w / 2 + 0.1, x + w / 2 - 0.1):
			for cy in (y + 0.1, y + h - 0.1):
				F["V_Steel"].box(cx - 0.12, cx + 0.12, cy - 0.12, cy + 0.12, 0.72, 0.8)
		S.screen("poster", title, sub, M, x, y + h / 2, 0.76, w, h)


# ---------------------------------------------------------------- owner round 2026-11-16 (night 2): RIVALS-style life
def fx(kind, x, y, z, color="#FFC83D", to=None, name="FX", **attrs):
	"""A visual effect built in Studio (Build_V4 M.fx): kind sparkle | embers | dust | cone. World Blender coords.
	cone runs from (x, y, z) to `to` (a light cone from a spot can)."""
	a = {"Kind": kind, "Color": color}
	if to:
		a["To"] = "%.3f,%.3f,%.3f" % tuple(to)
	a.update(attrs)
	S.ANCHORS.append([name, "LobbyFX", round(x, 3), round(y, 3), round(z, 3), 1.0, 1.0, 1.0, a])


def npc(name, x, y, z, yaw, look, title, scale=1.0, talk=None):
	"""An R15 NPC built in Studio (Build_V4 M.npcs) standing at (x, y, z) (feet), facing yaw (degrees, 0 = +Y)."""
	attrs = {"Yaw": yaw, "Look": look, "Title": title, "Scale": scale}
	if talk:
		attrs["Talk"] = talk  # NpcTalk opens this NPC's lines (lobby/shared/NpcTalk)
	S.ANCHORS.append([name, "LobbyNPCSpot", round(x, 3), round(y, 3), round(z, 3), 2.0, 2.0, 5.0, attrs])


def step_pad(K, KD, area, x, y, r, accent, tag, name, emblem="ring", z0=0.0):
	"""A floor pad you step on to open a menu (WorldPrompts Trigger=Step): a low octagon with a steel rim, a lit
	accent outline, a painted emblem. The hook covers the pad."""
	M = Matrix.Translation((x, y, z0))
	with C.grp(name, M):
		F, G = S.FK(K, M), S.FK(KD, M)
		F["V_Base"].prism(ccw(oct_pts(r + 0.6)), 0.0, 0.4)
		S.ring_prism(G["V_Steel"], ccw(oct_pts(r + 0.6)), ccw(oct_pts(r + 0.1)), 0.4, 0.55)
		G["V_Dark"].prism(ccw(oct_pts(r + 0.1)), 0.4, 0.5)
		o, i = oct_pts(r - 0.2), oct_pts(r - 0.45)
		for k in range(8):
			j = (k + 1) % 8
			G[accent].prism(ccw([i[k], i[j], o[j], o[k]]), 0.5, 0.56)
		paint = PAINT.get(accent, accent)
		rings = ((r * 0.55, 0.35), (r * 0.25, 0.3)) if emblem == "ring" else ((r * 0.55, 0.35),)
		for R_, t in rings:
			o, i = oct_pts(R_), oct_pts(R_ - t)
			for k in range(8):
				j = (k + 1) % 8
				G[paint].prism(ccw([i[k], i[j], o[j], o[k]]), 0.5, 0.55)
		if emblem == "coin":
			for poly in _icon_shapes("star", r * 0.6):
				G[paint].prism(poly, 0.5, 0.55)
		S.collider(area, M, -r, r, -r * 0.4, r * 0.4, 0.0, 0.45, "B")
		S.collider(area, M, -r * 0.4, r * 0.4, -r, r, 0.0, 0.45, "B")
	S.ANCHORS.append([name + "Hook", tag, round(x, 3), round(y, 3), round(z0 + 2.5, 3), r * 1.6, r * 1.6, 4.0, {"Trigger": "Step"}])
	S.light(Matrix.Identity(4), x, y, z0 + 12.0, WHITE, 1.4, 16, 60)
	fx("sparkle", x, y, z0 + 1.0, GLOW.get(accent, ("#FFFFFF",))[0], name=name + "FX", Rate=3, Spread=round(r * 0.7, 2))


def _stand_base(K, KD, M, paint):
	F, G = S.FK(K, M), S.FK(KD, M)
	F["V_Base"].prism(ccw(oct_pts(2.9)), 0.0, 0.6)
	F["V_Wall"].solid([(a, b, 0.6) for a, b in ccw(oct_pts(2.4))], [(a, b, 2.4) for a, b in ccw(oct_pts(2.1))])
	G["V_Trim"].prism(ccw(oct_pts(2.3)), 2.4, 2.65)
	o, i = oct_pts(2.3), oct_pts(2.05)
	for k in range(8):
		j = (k + 1) % 8
		G[paint].prism(ccw([i[k], i[j], o[j], o[k]]), 1.7, 1.85)
	return F, G


def bundle_stand(K, KD, area, x, y, accent="E_Gold", name="BundleStand"):
	"""A bundle on show (RIVALS' floating pickups, our build): a stepped plinth with an accent band, a faceted gift box
	with crossing straps and a bow, a gold medal floating and turning above it, sparkles and a light cone."""
	M = Matrix.Translation((x, y, 0.0))
	paint = PAINT.get(accent, accent)
	with C.grp(name, M):
		F, G = _stand_base(K, KD, M, paint)
		G["V_Crate"].prism(ccw(S.cham_rect(-1.3, 1.3, -1.3, 1.3, 0.15)), 2.65, 4.55)
		G["V_Dark"].prism(ccw(S.cham_rect(-1.42, 1.42, -1.42, 1.42, 0.17)), 4.55, 4.95)  # lid
		for rot in (0, 90):
			S.FK(KD, M @ Matrix.Rotation(radians(rot), 4, "Z"))[paint].box(-0.28, 0.28, -1.47, 1.47, 2.7, 5.0)  # straps
		for sx in (-1, 1):  # bow: two angled plates
			G[paint].prism(ccw([(0.0, 0.0), (sx * 0.9, 0.5), (sx * 1.0, -0.1), (sx * 0.2, -0.3)]), 4.95, 5.25)
	Mm = Matrix.Translation((x, y, 7.6))
	with C.grp(name + "Medal", Mm):
		P = S.FK(KD, Mm @ RX(90))
		P["V_Gold"].prism(ccw(oct_pts(1.25)), -0.2, 0.2)
		S.ring_prism(P["V_Trim"], ccw(oct_pts(1.42)), ccw(oct_pts(1.2)), -0.16, 0.16)
		for poly in _icon_shapes("star", 1.3):
			P["E_Gold"].prism(poly, 0.2, 0.3)
			P["E_Gold"].prism(poly, -0.3, -0.2)
	S.ANIM[name + "Medal"] = {"pivot": [x, y, 7.6], "spin": 40, "axis": [0, 0, 1]}
	S.light(Matrix.Identity(4), x, y, 12.0, WHITE, 2.0, 14, 34)
	fx("sparkle", x, y, 7.6, GLOW.get(accent, ("#FFC83D",))[0], name=name + "FX", Rate=8, Spread=1.6)
	fx("cone", x, y, 16.0, "#FFF4E0", to=(x, y, 2.8), name=name + "Cone", W0=1.0, W1=6.0)


def effect_stand(K, KD, area, x, y, accent="E_Gold", name="EffectStand"):
	"""A kill-effect preview (RIVALS shows effects on stands): a plinth with a cluster of faceted crystal shards and
	rising embers, a light cone over it."""
	M = Matrix.Translation((x, y, 0.0))
	paint = PAINT.get(accent, accent)
	with C.grp(name, M):
		F, G = _stand_base(K, KD, M, paint)
		G["V_Dark"].prism(ccw(oct_pts(1.9)), 2.65, 2.8)
		shards = ((0.0, 0.0, 4.2, 0, 0.55), (0.9, 0.4, 2.8, 18, 0.4), (-0.8, 0.6, 3.1, -15, 0.42), (0.3, -0.9, 2.4, 22, 0.35), (-0.6, -0.7, 2.0, -25, 0.32))
		for k, (dx, dy, hgt, tilt, rad) in enumerate(shards):
			Mc = M @ Matrix.Translation((dx, dy, 2.75)) @ Matrix.Rotation(radians(tilt), 4, "X" if k % 2 else "Y")
			ring = ccw([(rad * cos(radians(30 + 60 * q)), rad * sin(radians(30 + 60 * q))) for q in range(6)])
			b = S.FK(KD, Mc)["E_Gold" if k == 0 else "V_Gold"]
			b.solid([(a * 0.6, c * 0.6, 0.0) for a, c in ring], [(a, c, hgt * 0.7) for a, c in ring])
			b.solid([(a, c, hgt * 0.7) for a, c in ring], [(a * 0.05, c * 0.05, hgt) for a, c in ring])
	S.light(Matrix.Identity(4), x, y, 12.0, WHITE, 1.8, 14, 34)
	S.light(Matrix.Identity(4), x, y, 4.5, GLOW.get(accent, ("#FFC83D",))[0], 0.8, 8)
	fx("embers", x, y, 3.2, GLOW.get(accent, ("#FFC83D",))[0], name=name + "FX", Rate=10, Spread=1.2)
	fx("cone", x, y, 16.0, "#FFF4E0", to=(x, y, 2.8), name=name + "Cone", W0=1.0, W1=6.0)


def holobay(K, KD, area, M, hw, h, d, title, accent, icon, name="Holobay", backdrop="V_Dark", curtains=None, figures=()):
	"""A show stage set into a wall (RIVALS' Market holobays, our build). M: wall face frame at the bay centre (X along
	the wall, Y up, Z into the room). A stepped frame, a lined recess d deep, a raised stage floor with a lit lip, a
	backdrop with a big painted slash graphic, an inner box truss with three spot cans aimed at the hero point, a tab
	sign above. Returns the hero point (world)."""
	paint = PAINT.get(accent, accent)
	iw = hw - 3.0
	tz = -d * 0.45
	with C.grp(name, M):
		F, FD = S.FK(K, M), S.FK(KD, M)
		S.u_frame(FD["V_Trim"], hw, h, hw - 1.2, h - 1.2, -1.0, 1.6, ci=2.6)
		S.u_frame(FD["V_Wall"], hw - 1.2, h - 1.2, hw - 2.2, h - 2.2, -3.0, 0.9, co=2.6, ci=2.3)
		S.u_frame(FD["V_Low"], hw - 2.2, h - 2.2, hw - 3.0, h - 3.0, -d, 0.3, co=2.3, ci=2.0)
		F["V_Wall"].box(-hw - 2.0, hw + 2.0, h - 2.2, h + 1.6, -d, -1.0)
		for sx in (-1, 1):
			F["V_Wall"].box(sx * (hw - 2.2), sx * (hw + 2.0), 0, h - 2.2, -d, -1.0)
		F["V_Wall"].box(-hw - 2.0, hw + 2.0, 0, h + 1.6, -d - 2.0, -d)
		F["V_Slab"].box(-hw - 2.0, hw + 2.0, -1.2, -0.02, -d - 2.0, -2.0)
		FD[backdrop].box(-iw, iw, 1.2, h - 3.3, -d, -d + 0.25)  # backdrop (a lit paint on the pass stage, owner 2026-11-16)
		for sx in (-iw * 0.62, -iw * 0.3):
			FD[paint].prism(ccw([(sx - 1.1, 1.8), (sx + 0.4, 1.8), (sx + 3.4, h - 4.8), (sx + 1.9, h - 4.8)]), -d + 0.25, -d + 0.3)
		FD[paint].box(-iw + 0.6, iw - 0.6, h - 4.4, h - 4.25, -d + 0.25, -d + 0.3)
		Mf = M @ RX(-90)
		P = S.FK(KD, Mf)
		P["V_Floor2"].prism(ccw(S.cham_rect(-iw + 0.05, iw - 0.05, 0.2, d - 0.05, 0.3)), 0.0, 1.2)
		P["V_Trim"].box(-iw + 0.05, iw - 0.05, 0.0, 0.35, 1.0, 1.32)
		P[accent].box(-iw + 0.4, iw - 0.4, 0.14, 0.24, 0.4, 0.7)  # lit lip, seated in the stage face
		S.collider(area, Mf, -iw + 0.3, iw - 0.3, 0.5, d - 0.3, 0.0, 1.1, "B")
		if curtains:
			with C.grp(name + "Curtains", M):
				Pc = S.FK(KD, Mf)
				for sx in (-1, 1):
					Pc[curtains].prism(_curtain(sx, iw), 1.15, h - 2.9)
					Pc["V_Steel"].box(min(sx * (iw + 0.1), sx * (iw - 3.0)), max(sx * (iw + 0.1), sx * (iw - 3.0)), 0.35, 0.55, h - 2.9, h - 2.6)  # rail
		for k, (fx_, fy, fs) in enumerate(figures):
			with C.grp(name + "Holo%d" % (k + 1), M):
				holo_figure(S.FK(KD, Mf), fx_, d * fy, 1.18, fs)
		for yy in (h - 3.7, h - 4.7):
			for zz in (tz - 0.5, tz + 0.5):
				FD["V_Dark"].pipe((-iw, yy, zz), (iw, yy, zz), 0.13, n=6)
		n = int((2 * iw) // 1.5)
		for q in range(n):
			xx = -iw + 0.3 + q * 1.5
			FD["V_Steel"].pipe((xx, h - 3.7, tz - 0.5), (xx + 0.75, h - 4.7, tz + 0.5), 0.06, n=6)
	hero = M @ Vector((0.0, 1.2, -d * 0.5))
	for k, sx in enumerate((-iw * 0.6, 0.0, iw * 0.6)):
		can = M @ Vector((sx, h - 4.7, tz))
		stage_spot(KD, (can.x, can.y), 0.0, 0.0, can.z, tuple(hero + Vector((0, 0, 1.5))))
		if k != 1:
			fx("cone", can.x, can.y, can.z - 1.3, "#FFF4E0", to=tuple(hero + Vector((0, 0, 1.0))), name=name + "Cone", W0=0.5, W1=4.5)
	S.light(M, 0, h - 4.2, -d * 0.5, WHITE, 3.2, 24, 80)
	S.light(M, 0, 4.0, -1.5, GLOW.get(accent, (WHITE,))[0], 1.4, 16)
	sign(KD, M @ T(0, h + 0.9, 0), title, hw * 1.4, 4.4, accent=accent, tilt=10, standoff=0.8, name=name + "Sign", icon=icon, icon_size=3.4, light=False)
	fx("dust", hero.x, hero.y, hero.z + 4.0, "#FFF4E0", name=name + "Dust", Spread=round(iw * 0.8, 2))
	return hero



# ---------------------------------------------------------------- structure pass (owner 2026-11-16: "improve the structure")
def slab_with_hole(K, sx0, sx1, sy0, sy1, ox0, ox1, oy0, oy1, z, t=1.5, mat="V_Ceil"):
	"""A ceiling slab (world rect s*) with a rectangular opening (o*), as four boxes."""
	K[mat].box(sx0, sx1, sy0, oy0, z, z + t)
	K[mat].box(sx0, sx1, oy1, sy1, z, z + t)
	K[mat].box(sx0, ox0, oy0, oy1, z, z + t)
	K[mat].box(ox1, sx1, oy0, oy1, z, z + t)


def nave_vault(K, KD, M, hw, v0, v1, z, rise=10.0, top=None, cl=3.2, rib_every=12.0, lamp=(6.0, 2.0), name="Vault"):
	"""A raised vault over a ceiling opening, in frame M (local u across, v along, z up; the opening is u in [-hw, hw],
	v in [v0, v1], its rim at height z). Clerestory walls with frosted panels, angled plates (faceted, no curves) up to a
	flat top, gable ends, steel ribs that follow the section, housed lamps and pools along the top."""
	thw = top if top is not None else hw - 6.0
	zt = z + rise
	with C.grp(name, M):
		F, G = S.FK(K, M), S.FK(KD, M)
		for s in (-1, 1):
			F["V_Wall"].box(*sorted((s * (hw - 0.15), s * (hw + 0.9))), v0 - 0.1, v1 + 0.1, z - 0.2, z + cl)  # proud of the slab edge
			F["V_Wall"].ext_y(ccw([(s * (hw - 0.15), z + cl - 0.25), (s * (hw + 1.2), z + cl - 0.25), (s * (thw + 0.2), zt + 1.0), (s * thw, zt)]), v0, v1)
			n = max(1, int((v1 - v0) // 6.0))
			for k in range(n):
				vc = v0 + (v1 - v0) * (k + 0.5) / n
				G["E_Panel"].box(*sorted((s * (hw - 0.21), s * (hw - 0.1))), vc - 1.9, vc + 1.9, z + 0.8, z + cl - 0.6)
				G["V_Steel"].box(*sorted((s * (hw - 0.3), s * (hw - 0.12))), vc - 0.12, vc + 0.12, z + 0.65, z + cl - 0.45)
		F["V_Ceil"].box(-thw - 0.2, thw + 0.2, v0, v1, zt, zt + 1.2)
		sec = ccw([(-hw, z), (hw, z), (hw, z + cl), (thw, zt), (-thw, zt), (-hw, z + cl)])
		for va, vb in ((v0 - 0.9, v0 + 0.15), (v1 - 0.15, v1 + 0.9)):  # gable ends, proud of the slab edge
			F["V_Wall"].ext_y(sec, va, vb)
		# ribs that follow the section (open at the bottom), on steel shoes at the rim
		band = [(hw, z), (hw, z + cl), (thw, zt), (-thw, zt), (-hw, z + cl), (-hw, z),
			(-hw + 0.7, z), (-hw + 0.7, z + cl - 0.25), (-thw + 0.45, zt - 0.7), (thw - 0.45, zt - 0.7), (hw - 0.7, z + cl - 0.25), (hw - 0.7, z)]
		n = max(1, int((v1 - v0) // rib_every))
		for k in range(1, n):
			vr = v0 + (v1 - v0) * k / n
			G["V_Beam"].ext_y(ccw(band) if False else band[::-1], vr - 0.45, vr + 0.45)
			for s in (-1, 1):
				G["V_Steel"].box(*sorted((s * (hw - 0.9), s * hw)), vr - 0.7, vr + 0.7, z - 0.25, z + 0.35)
	# lamps along the top
	n = max(1, int((v1 - v0) // 14.0))
	for k in range(n):
		vc = v0 + (v1 - v0) * (k + 0.5) / n
		w = M @ Vector((0.0, vc, zt))
		R = M.to_3x3()
		ax = R @ Vector((1, 0, 0))
		lx, ly = (lamp[0], lamp[1]) if abs(ax.x) > 0.5 else (lamp[1], lamp[0])
		ceiling_lamp(KD, w.x, w.y, zt, lx, ly)
		S.light(Matrix.Identity(4), w.x, w.y, zt - 0.4, WHITE, 1.6, 42, 80)



def gallery(K, KD, M, x0, x1, z, d=4.0, name="Gallery"):
	"""An upper gallery deck on a wall (frame M: X along the wall, Y up, Z into the room): deck, braces and railing as
	separate pieces (owner 2026-11-16: every structure its own mesh). The railing stands on the deck, inside its cut
	corners, each post on a base plate. Decorative (no access)."""
	with C.grp(name, M):
		with C.grp("Deck", M):
			F, G = S.FK(K, M), S.FK(KD, M)
			deck = ccw([(x0, 0.0), (x1, 0.0), (x1, d - 0.9), (x1 - 0.9, d), (x0 + 0.9, d), (x0, d - 0.9)])
			F["V_Steel"].solid([(a, z - 0.7, b) for a, b in deck], [(a, z, b) for a, b in deck])  # deck with cut ends
			G["V_Trim"].box(x0 + 0.9, x1 - 0.9, z - 0.85, z + 0.12, d - 0.35, d + 0.1)  # front edge
			G["V_Dark"].box(x0 + 0.4, x1 - 0.4, z, z + 0.05, 0.4, d - 1.4)  # grate field
			n = max(2, int((x1 - x0) // 0.7))
			for k in range(1, n):
				xx = x0 + (x1 - x0) * k / n
				G["V_Steel"].box(xx - 0.08, xx + 0.08, z, z + 0.09, 0.4, d - 1.4)
			G["E_White"].box(x0 + 1.0, x1 - 1.0, z - 0.8, z - 0.72, d - 0.9, d - 0.6)  # lit strip under the edge
		with C.grp("Braces", M):
			G = S.FK(KD, M)
			nb = max(2, int((x1 - x0) // 6.0) + 1)
			for k in range(nb):
				xx = x0 + 1.2 + (x1 - x0 - 2.4) * k / (nb - 1)
				G["V_Steel"].ext_x(ccw([(z - 0.7, 0.4), (z - 0.7, d - 0.9), (z - 1.2, d - 0.9), (z - 3.4, 0.4)]), xx - 0.17, xx + 0.17)  # knee brace
				G["V_Trim"].box(xx - 0.3, xx + 0.3, z - 3.6, z - 3.0, 0.34, 0.56)  # wall shoe, on the panel face
		with C.grp("Railing", M):
			G = S.FK(KD, M)
			ra, rb, rz = x0 + 1.3, x1 - 1.3, d - 1.0  # inside the cut corners, on the deck
			npost = max(2, int((rb - ra) // 3.0) + 1)
			for k in range(npost):
				xx = ra + (rb - ra) * k / (npost - 1)
				G["V_Trim"].box(xx - 0.3, xx + 0.3, z, z + 0.12, rz - 0.3, rz + 0.3)  # base plate
				G["V_Steel"].box(xx - 0.12, xx + 0.12, z + 0.12, z + 2.5, rz - 0.12, rz + 0.12)
			for zz in (z + 1.2, z + 2.35):
				G["V_Steel"].pipe((ra - 0.05, zz, rz), (rb + 0.05, zz, rz), 0.11, n=6)
	nl = max(1, int((x1 - x0) // 8.0))
	for k in range(nl):
		xx = x0 + (x1 - x0) * (k + 0.5) / nl
		S.light(M, xx, z - 0.9, d * 0.55, WHITE, 1.3, 16, 70)



# ---------------------------------------------------------------- hub pass (owner 2026-11-16, section by section: the hub)
def tv(K, KD, M, w, h, kind, title, sub="", out=3.2, tilt=7.0, glow="E_ThViolet", name="TV"):
	"""A screen that pops out of the wall like RIVALS' TVs, our build. M: wall face frame at the TV's bottom centre (X
	along the wall, Y up, Z out). A bolted wall plate, two faceted arms with an elbow, a thick chamfered case tilted down
	at the room, a light grey bezel, a glowing strip under it, a light bar on top. The screen is a SurfaceGui."""
	Mt = M @ T(0, h / 2, out) @ RX(tilt) @ T(0, -h / 2, 0)
	with C.grp(name, M):
		F, P = S.FK(KD, M), S.FK(KD, Mt)
		F["V_Steel"].prism(ccw(S.cut_rect(-w * 0.22, w * 0.22, h * 0.3, h * 0.7, 0.5, 0.12)), 0.0, 0.3)  # wall plate
		for bx in (-w * 0.18, w * 0.18):
			for by in (h * 0.34, h * 0.66):
				F["V_Trim"].box(bx - 0.15, bx + 0.15, by - 0.15, by + 0.15, 0.3, 0.42)
		for ax in (-w * 0.12, w * 0.12):  # arms: wall knuckle, a faceted beam, the case knuckle
			F["V_Dark"].prism(ccw(S.cham_rect(ax - 0.55, ax + 0.55, h * 0.42, h * 0.58, 0.18)), 0.3, 1.1)
			F["V_Steel"].ext_y(ccw(S.cham_rect(ax - 0.35, ax + 0.35, 1.1, out - 0.4, 0.12)), h * 0.46, h * 0.54)
			P["V_Dark"].prism(ccw(S.cham_rect(ax - 0.6, ax + 0.6, h * 0.42, h * 0.58, 0.18)), -0.6, 0.0)
		case = ccw(S.cham_rect(-w / 2, w / 2, 0, h, 0.3))
		P["V_Dark"].prism(case, 0.0, 1.3)
		S.ring_prism(P["V_Trim"], inset(case, 0.05), inset(case, 0.55), 1.3, 1.5)
		P[glow].box(-w * 0.36, w * 0.36, -0.12, 0.08, 0.5, 1.1)  # glow strip under the case
		P["V_Steel"].ext_x(ccw([(h - 0.1, 0.4), (h + 0.55, 0.4), (h + 0.75, 1.0), (h + 0.55, 1.6), (h - 0.1, 1.6)]), -w * 0.42, w * 0.42)  # light bar
		P["E_White"].box(-w * 0.4, w * 0.4, h + 0.05, h + 0.12, 1.5, 1.62)
		S.screen(kind, title, sub, Mt, 0, h / 2, 1.42, w - 1.2, h - 1.2)
	S.light(Mt, 0, h + 0.6, 3.2, WHITE, 1.4, 14, 75)
	S.light(Mt, 0, -0.4, 2.0, GLOW.get(glow, (WHITE,))[0], 0.6, 8)


def _open_frustum(b, r0, z0, r1, z1, n=8):
	"""The sides of an n-sided frustum only (no caps): a projection cone."""
	lo = [b.bm.verts.new(b.M @ Vector((r0 * cos(2 * pi * k / n + pi / n), r0 * sin(2 * pi * k / n + pi / n), z0))) for k in range(n)]
	hi = [b.bm.verts.new(b.M @ Vector((r1 * cos(2 * pi * k / n + pi / n), r1 * sin(2 * pi * k / n + pi / n), z1))) for k in range(n)]
	for k in range(n):
		j = (k + 1) % n
		b.bm.faces.new((lo[k], lo[j], hi[j], hi[k]))


def _holo_item(b, item, s):
	"""Placeholder hologram items, built upright in the XZ plane (Y = depth), centred on x 0, bottom at z 0, size s."""
	if item == "gift":
		b.box(-s * 0.45, s * 0.45, -s * 0.45, s * 0.45, 0.0, s * 0.62)
		b.box(-s * 0.52, s * 0.52, -s * 0.52, s * 0.52, s * 0.62, s * 0.8)
		for sx in (-1, 1):
			b.prism(ccw([(0, 0), (sx * s * 0.42, s * 0.24), (sx * s * 0.46, -s * 0.04), (sx * s * 0.1, -s * 0.12)]), s * 0.8, s * 0.92)
	elif item == "badge":
		pts = ccw([(-s * 0.42, s), (s * 0.42, s), (s * 0.5, s * 0.82), (s * 0.5, s * 0.36), (0.0, 0.0), (-s * 0.5, s * 0.36), (-s * 0.5, s * 0.82)])
		b.solid([(x, -0.2, z) for x, z in pts], [(x, 0.2, z) for x, z in pts])
	elif item == "rifle":
		prof = ccw([(-s * 0.95, s * 0.28), (-s * 0.95, s * 0.5), (-s * 0.35, s * 0.56), (-s * 0.2, s * 0.66), (s * 0.4, s * 0.66), (s * 0.45, s * 0.58),
			(s * 1.05, s * 0.58), (s * 1.05, s * 0.5), (s * 0.5, s * 0.5), (s * 0.3, s * 0.36), (s * 0.05, s * 0.36), (s * 0.12, s * 0.0),
			(-s * 0.12, s * 0.0), (-s * 0.12, s * 0.36), (-s * 0.55, s * 0.36)])
		b.solid([(x, -0.18, z) for x, z in prof], [(x, 0.18, z) for x, z in prof])
	else:  # "crate": a supply case
		b.box(-s * 0.55, s * 0.55, -s * 0.35, s * 0.35, 0.0, s * 0.55)
		b.box(-s * 0.6, s * 0.6, -s * 0.4, s * 0.4, s * 0.48, s * 0.62)


def holo_stand(K, KD, area, x, y, item, name="Holo", size=3.0, spin=24):
	"""A hologram projector (RIVALS' pickup stands, our build; owner 2026-11-16: "like a hologram, fun"): a stepped
	octagonal emitter with a glowing lens, a translucent ring on the floor, a soft projection cone widening upward, the
	item as a glowing silhouette with an offset ghost copy, turning; sparkles and light. Items are placeholders."""
	M = Matrix.Translation((x, y, 0.0))
	with C.grp(name, M):
		F, G = S.FK(K, M), S.FK(KD, M)
		F["V_Base"].prism(ccw(oct_pts(2.2)), 0.12, 0.5)
		S.ring_prism(G["V_Steel"], ccw(oct_pts(2.2)), ccw(oct_pts(1.8)), 0.5, 0.62)
		G["V_Dark"].prism(ccw(oct_pts(1.8)), 0.5, 0.58)
		o, i = oct_pts(1.5), oct_pts(1.25)
		for k in range(8):
			j = (k + 1) % 8
			G["E_ThLilac"].prism(ccw([i[k], i[j], o[j], o[k]]), 0.58, 0.64)
		G["H_Item"].prism(ccw(oct_pts(0.7)), 0.58, 0.68)  # the lens
		o, i = oct_pts(4.2), oct_pts(3.8)
		for k in range(8):
			j = (k + 1) % 8
			G["H_Ring"].prism(ccw([i[k], i[j], o[j], o[k]]), 0.13, 0.16)  # floor ring
		_open_frustum(G["H_Cone"], 0.7, 0.68, size * 1.45, size * 2.6, n=8)
	zi = size * 0.85
	Mi = Matrix.Translation((x, y, zi))
	with C.grp(name + "Item", Mi):
		P = S.FK(KD, Mi)
		_holo_item(P["H_Item"], item, size)
		Pg = S.FK(KD, Mi @ T(size * 0.18, -size * 0.12, size * 0.08))
		_holo_item(Pg["H_Ghost"], item, size)
	S.ANIM[name + "Item"] = {"pivot": [x, y, zi], "spin": spin, "axis": [0, 0, 1]}
	S.collider(area, M, -1.6, 1.6, -1.6, 1.6, 0.0, 0.6, "B")
	S.light(Matrix.Identity(4), x, y, zi + size * 0.5, GLOW["E_ThViolet"][0], 1.1, 12)
	fx("sparkle", x, y, zi + size * 0.4, "#C9B0FF", name=name + "FX", Rate=7, Spread=round(size * 0.6, 2))


def path_lane(KD, Ml, hw, y0, y1, glow="E_ThLilac", arrows=(), word=None):
	"""A walkway to a door (RIVALS' floor paths, our build): a dark inlaid lane, steel edge rails with a glowing slot
	in each, glowing chevrons near the door, the room word stencilled at the start. Frame Ml: floor plane, +Y to door."""
	F = S.FK(KD, Ml)
	F["V_Base"].box(-hw, hw, y0, y1, 0.12, 0.16)
	for sx in (-1, 1):
		F["V_Steel"].prism(ccw(S.cham_rect(*sorted((sx * hw, sx * (hw + 0.9))), y0, y1, 0.12)), 0.12, 0.24)
		F[glow].box(*sorted((sx * (hw + 0.32), sx * (hw + 0.58))), y0 + 0.4, y1 - 0.4, 0.2, 0.26)
	for y in arrows:
		chevron(KD, Ml, 0, y, hw * 0.75, mat=glow, z=0.16, depth=0.05, t=0.22)
	if word:
		floor_text(KD, Ml @ Matrix.Translation((0, y0 + 2.0, 0)), word, 2.0, z=0.16)


def gatehouse(K, KD, M, hw, h, glow="E_ThViolet", span=14.6, out=3.6, name="Gatehouse", area="Concourse", plain=()):
	"""A grand entrance (owner 2026-11-16: entrances need character like RIVALS'): a deep frame block standing out from
	the wall between the piers, built around the existing door opening (hw x h). Two columns with chamfered fronts and a
	lit slot, a stepped head with a cornice and a soffit with downlights, glowing strips up both jambs, a hazard
	threshold beside the lane. M: wall face frame at the door's bottom centre."""
	with C.grp(name, M):
		F, G = S.FK(K, M), S.FK(KD, M)
		for sx in (-1, 1):
			a, b = sorted((sx * hw, sx * span))
			inner, outer = sx * hw, sx * span
			col = ccw([(inner, 0.0), (outer, 0.0), (outer, out - 0.7), (outer - sx * 0.7, out), (inner + sx * 0.3, out), (inner, out - 0.3)])
			F["V_Wall"].solid([(p, 0.0, q) for p, q in col], [(p, h + 0.2, q) for p, q in col])
			S.collider(area, M, a + 0.15, b - 0.15, 0.0, h, 0.15, out - 0.2, "B")
			G["V_Base"].solid([(p, 0.0, q) for p, q in ccw([(a - 0.12, -0.1), (b + 0.12, -0.1), (b + 0.12, out + 0.3), (a - 0.12, out + 0.3)])],
				[(p, 1.4, q) for p, q in ccw([(a - 0.12, -0.1), (b + 0.12, -0.1), (b + 0.12, out + 0.3), (a - 0.12, out + 0.3)])])  # plinth
			cx = (a + b) / 2
			if sx not in plain:  # a column that carries a plaque has no slot
				G["V_Low"].box(cx - 0.45, cx + 0.45, 2.4, h - 1.6, out - 0.1, out + 0.02)  # slot recess
				G[glow].box(cx - 0.22, cx + 0.22, 2.8, h - 2.0, out - 0.06, out + 0.06)  # lit slot
			G[glow].box(*sorted((sx * (hw + 0.02), sx * (hw - 0.1))), 1.6, h - 1.2, 1.2, 1.5)  # jamb strip
		head = ccw([(-span, h), (span, h), (span, h + 2.2), (-span, h + 2.2)])
		F["V_Wall"].solid([(p, q, 0.0) for p, q in head], [(p, q, out) for p, q in head])
		S.collider(area, M, -span + 0.15, span - 0.15, h + 0.15, h + 2.05, 0.15, out - 0.15, "B")
		G["V_Trim"].box(-span - 0.3, span + 0.3, h + 2.2, h + 2.75, -0.1, out + 0.7)  # cornice
		G["V_Trim"].box(-span, span, h - 0.25, h, out - 0.5, out + 0.05)  # lip under the head front
		G["V_Dark"].box(-hw + 0.6, hw - 0.6, h - 0.06, h, 0.4, out - 0.6)  # soffit
		for lx in (-hw * 0.5, hw * 0.5):
			G["E_White"].box(lx - 1.4, lx + 1.4, h - 0.12, h - 0.06, out * 0.4, out * 0.65)
			S.light(M, lx, h - 0.4, out * 0.5, WHITE, 1.8, 16, 80)
	Mf = M @ RX(-90)
	for sx in (-1, 1):
		hazard_strip(KD, Mf, *sorted((sx * 7.4, sx * (hw - 0.2))), -(out + 1.6), -(out + 0.4), 0.12)



# ---------------------------------------------------------------- Shop as a Market hallway (owner 2026-11-16)
def _sole(cx, cy, s_, flip):
	"""A faceted shoe-print outline (pointing +Y), mirrored for the left foot."""
	f = -1 if flip else 1
	pts = [(-0.28, -0.6), (0.22, -0.62), (0.32, -0.3), (0.3, 0.2), (0.38, 0.5), (0.24, 0.66), (-0.12, 0.66), (-0.3, 0.42), (-0.34, 0.0), (-0.36, -0.36)]
	return ccw([(cx + f * x * s_, cy + y * s_) for x, y in pts])


def step_mark(KD, area, x, y, w, d, accent, tag, name, facing=1.0, word="STEP IN"):
	"""A walk-in floor mark in front of a show stage (RIVALS' foot emblems, our build; owner 2026-11-16: no raised
	pad): an inlaid dark field, lit corner brackets in the stage's colour, three pairs of footprints, a hazard strip
	with a stencil on the stage side. Walking onto it opens the menu (Trigger=Step). World coords; facing = +1 when the
	stage is toward +Y, -1 toward -Y."""
	M = Matrix.Translation((x, y, 0.0)) @ Matrix.Rotation(0.0 if facing > 0 else pi, 4, "Z")
	paint = PAINT.get(accent, accent)
	with C.grp(name, M):
		G = S.FK(KD, M)
		G["V_Base"].box(-w / 2, w / 2, -d / 2, d / 2, 0.12, 0.15)
		for sx in (-1, 1):
			for sy in (-1, 1):
				bx, by = sx * (w / 2 - 0.4), sy * (d / 2 - 0.4)
				G[accent].box(*sorted((bx, bx - sx * 1.8)), *sorted((by - sy * 0.12, by + sy * 0.12)), 0.15, 0.2)
				G[accent].box(*sorted((bx - sx * 0.12, bx + sx * 0.12)), *sorted((by, by - sy * 1.8)), 0.15, 0.2)
		for k, fx_ in enumerate((-w * 0.28, 0.0, w * 0.28)):
			mat = paint if k == 1 else "V_Paint"
			for sx, flip, dy in ((-0.5, True, 0.0), (0.5, False, 0.35)):
				G[mat].prism(_sole(fx_ + sx, -0.3 + dy, 1.4, flip), 0.15, 0.18)
				G[mat].prism(_heel(fx_ + sx, -0.3 + dy, 1.4, flip), 0.15, 0.18)
		hazard_strip(KD, M, -w / 2, w / 2, d / 2 + 0.2, d / 2 + 1.0, 0.12)
		floor_text(KD, M @ Matrix.Translation((0, d / 2 - 1.9, 0)), word, 0.8, mat="V_Paint", z=0.15)
	S.ANCHORS.append([name + "Hook", tag, round(x, 3), round(y, 3), 2.6, w, d, 4.0, {"Trigger": "Step"}])
	S.light(Matrix.Identity(4), x, y, 12.0, GLOW.get(accent, (WHITE,))[0], 0.7, 12)


def grouped(fn, name):
	"""Wrap a builder so everything it makes is one piece of its own (owner 2026-11-16: every structure separate)."""
	def w(*a, **k):
		with C.grp(name):
			return fn(*a, **k)
	w.__name__ = fn.__name__
	return w


wall_run = grouped(wall_run, "Wall")
conduit = grouped(conduit, "Conduit")
hazard_strip = grouped(hazard_strip, "Hazard")
ceiling_lamp = grouped(ceiling_lamp, "CeilingLamp")
path_lane = grouped(path_lane, "Path")
slab_with_hole = grouped(slab_with_hole, "Ceiling")
stage_spot = grouped(stage_spot, "StageSpot")
mouth = grouped(mouth, "Mouth")



# ---------------------------------------------------------------- props from the owner's RivalsProps templates (owner 2026-11-16)
PROP_KIND = {"crate": "Wep Crate", "crate_s": "Crate02", "case": "Ski Crate", "crate_tall": "Crate07", "container": "Container02",
	"barrel": "Barrel", "barrel_x": "Explosive Barrel", "pallet": "Pallet", "crate_long": "Crate03b"}


def prop_m(kind, M, name="Prop"):
	"""A prop spot: Studio drops a copy of the owner's RivalsProps template there (Build_V4.props). M: the prop's
	floor frame (its origin is the bottom centre, its X axis the prop's length)."""
	p = M.translation
	ax = M.to_3x3() @ Vector((1, 0, 0))
	yaw = degrees(atan2(ax.y, ax.x))
	S.ANCHORS.append([name, "LobbyPropSpot", round(p.x, 3), round(p.y, 3), round(p.z, 3), 1.0, 1.0, 1.0, {"Kind": PROP_KIND.get(kind, kind), "Yaw": round(yaw, 2)}])


def crate(K, M, w=5.0, d=4.0, h=3.2, name="Crate"):
	"""Placeholder crate: a prop spot (a RIVALS crate template) instead of our own model."""
	prop_m("crate" if w >= 4.5 else "crate_s", M, name)


def hard_case(K, M, w=4.6, d=1.6, h=0.9, name="HardCase"):
	prop_m("case", M, name)


def _sole(cx, cy, s_, flip):
	"""A footprint: the ball of the foot (faceted), one polygon; the heel is drawn by _heel."""
	f = -1 if flip else 1
	pts = [(-0.3, -0.05), (-0.18, -0.2), (0.16, -0.2), (0.32, -0.02), (0.36, 0.28), (0.28, 0.55), (0.06, 0.66), (-0.18, 0.6), (-0.32, 0.38)]
	return ccw([(cx + f * x * s_, cy + y * s_) for x, y in pts])


def _heel(cx, cy, s_, flip):
	f = -1 if flip else 1
	pts = [(-0.22, -0.62), (0.14, -0.64), (0.26, -0.5), (0.24, -0.32), (0.1, -0.26), (-0.16, -0.27), (-0.26, -0.4)]
	return ccw([(cx + f * x * s_, cy + y * s_) for x, y in pts])



# ---------------------------------------------------------------- Market stage dressing (owner 2026-11-16: the Shop is "a bit rough")
def _curtain(sx, iw, folds=5, w=2.9, y0=0.5, amp=0.7, t=0.22):
	"""A stage curtain in plan (x across the stage, y into it): a zigzag of flat folds, no curves. sx: -1 left, 1 right."""
	xs = [sx * (iw + 0.1 - w * k / folds) for k in range(folds + 1)]
	front = [(x, y0 + (amp if k % 2 else 0.0)) for k, x in enumerate(xs)]
	back = [(x, y + t) for x, y in front]
	return ccw(front + back[::-1])


def holo_figure(b, x, y, z0, s=1.0):
	"""A blocky hologram figure (RIVALS' Market shows cosmetics on glowing grid figures; ours are lilac block bodies)
	standing at (x, y) on a floor frame (z up), z0 the floor. A base disc, legs, torso, arms, head, small gaps
	between the blocks (no flush faces)."""
	b["H_Item"].prism(ccw([(x + px * 1.5 * s, y + py * 1.5 * s) for px, py in oct_pts(1.0)]), z0 - 0.03, z0 + 0.05)
	z = z0 + 0.02  # legs seated into the disc
	def blk(x0, x1, y0, y1, za, zb, c=0.14):
		b["H_Figure"].prism(ccw(S.cham_rect(x + x0 * s, x + x1 * s, y + y0 * s, y + y1 * s, c * s)), z + za * s, z + zb * s)
	for lx in (-0.95, 0.05):
		blk(lx, lx + 0.9, -0.45, 0.45, 0.0, 1.98)
	blk(-1.0, 1.0, -0.5, 0.5, 2.03, 4.0)
	for ax in (-2.0, 1.05):
		blk(ax, ax + 0.95, -0.45, 0.45, 2.08, 4.0)
	blk(-0.6, 0.6, -0.6, 0.6, 4.035, 5.2, c=0.2)



# ---------------------------------------------------------------- the Locker as a weapons room (owner 2026-11-16, after RIVALS' weapons area)
def gun_display(name, p, barrel, face, gid, scale, mount="Lay", spin=0.0, fill=0.0):
	"""A spot where the client lays the player's own skin of `gid` (LobbyGunDisplays): p the point the gun's back
	rests on (Lay / Wall) or its centre (Stand), barrel the muzzle direction, face the side that looks out (up on a
	table, out of a wall)."""
	b, f = Vector(barrel).normalized(), Vector(face).normalized()
	S.ANCHORS.append([name, "LobbyGunDisplay", round(p.x, 3), round(p.y, 3), round(p.z, 3), 1.0, 1.0, 1.0,
		{"Gun": gid, "Mount": mount, "BX": round(b.x, 4), "BY": round(b.y, 4), "BZ": round(b.z, 4), "FX": round(f.x, 4), "FY": round(f.y, 4),
			"FZ": round(f.z, 4), "Scale": round(scale, 3), "Fill": round(fill, 2), "Spin": spin}])  # Fill: the gun's length to aim for (Scale caps it)


def oct_corner_walls(K, KD, x0, x1, y0, y1, H, c, ext=3.0):
	"""The four diagonal walls that make a rectangle room an octagon (cut c on each axis). Returns their frames
	{corner: (M, length)}, Z into the room."""
	out = {}
	for key, a, b in (("SW", (x0 + c, y0), (x0, y0 + c)), ("NW", (x0, y1 - c), (x0 + c, y1)), ("NE", (x1 - c, y1), (x1, y1 - c)), ("SE", (x1, y0 + c), (x1 - c, y0))):
		d = Vector((b[0] - a[0], b[1] - a[1], 0.0))
		L = d.length
		M = wframe(a, (d.x / L, d.y / L))
		wall_run(K, KD, M, -ext, L + ext, H, dx0=1.0, dx1=L - 1.0)
		out[key] = (M, L)
	return out


def floor_emblem(KD, cx, cy, rings=((16.0, 14.6, "V_ThViolet"), (11.2, 10.4, "V_ThLilac"), (6.6, 5.8, "V_ThViolet"))):
	"""Our take on RIVALS' target floor: faceted octagon rings inlaid on the tiles, crosshair ticks between them."""
	M = Matrix.Translation((cx, cy, 0.0))
	with C.grp("FloorEmblem", M):
		G = S.FK(KD, M)
		for ro, ri, mat in rings:
			S.ring_prism(G[mat], ccw(oct_pts(ro)), ccw(oct_pts(ri)), 0.12, 0.16)
		for k in range(4):
			R = S.FK(KD, M @ Matrix.Rotation(radians(90 * k), 4, "Z"))
			R["V_ThViolet"].prism(ccw(S.cham_rect(11.6, 14.2, -0.42, 0.42, 0.12)), 0.12, 0.16)
			R2 = S.FK(KD, M @ Matrix.Rotation(radians(45 + 90 * k), 4, "Z"))
			R2["V_ThLilac"].prism(ccw(S.cham_rect(7.0, 9.8, -0.3, 0.3, 0.1)), 0.12, 0.16)


def display_table(K, KD, area, M, gid, label, accent="E_ThViolet", w=8.0, d=3.4, scale=2.3, name="DisplayTable"):
	"""A low display table (frame M on the floor, X along it, +Y toward the room's centre) for one gun: faceted top,
	dark mat, accent edge facing out, A-frame legs, a shelf with ammo boxes, a name plate on the apron facing in, and a
	LobbyGunDisplay spot on the mat (the player's own skin of the gun is laid there)."""
	paint = PAINT.get(accent, accent)
	top = 3.0
	with C.grp(name, M):
		F, G = S.FK(K, M), S.FK(KD, M)
		F["V_Wall"].prism(ccw(S.cham_rect(-w / 2, w / 2, -d / 2, d / 2, 0.3)), top - 0.35, top)
		G["V_Trim"].prism(ccw(S.cham_rect(-w / 2 - 0.12, w / 2 + 0.12, -d / 2 - 0.12, d / 2 + 0.12, 0.32)), top - 0.5, top - 0.35)
		G["V_Dark"].prism(ccw(S.cham_rect(-w / 2 + 0.35, w / 2 - 0.35, -d / 2 + 0.35, d / 2 - 0.35, 0.2)), top, top + 0.06)
		G[paint].box(-w / 2 + 0.4, w / 2 - 0.4, -d / 2 - 0.13, -d / 2 - 0.05, top - 0.45, top - 0.2)
		for lx in (-w / 2 + 0.9, w / 2 - 0.9):
			G["V_Steel"].ext_x(ccw([(-d / 2 + 0.2, 0.0), (-d / 2 + 0.75, 0.0), (-0.12, top - 0.5), (0.12, top - 0.5), (d / 2 - 0.75, 0.0), (d / 2 - 0.2, 0.0), (0.2, top - 0.2), (-0.2, top - 0.2)]), lx - 0.18, lx + 0.18)
		G["V_Steel"].box(-w / 2 + 0.9, w / 2 - 0.9, -0.15, 0.15, 1.0, 1.25)
		G["V_Base"].box(-w / 2 + 1.2, w / 2 - 1.2, -d / 2 + 0.6, d / 2 - 0.6, 1.25, 1.4)
		for k, bx in enumerate((-w / 2 + 2.0, -w / 2 + 3.3, w / 2 - 2.3)):
			G["V_Crate"].box(bx - 0.5, bx + 0.5, -0.45, 0.45, 1.4, 2.15 - 0.15 * k)
			G["V_GoldPaint"].box(bx - 0.22, bx + 0.22, 0.45, 0.48, 1.6, 1.85 - 0.15 * k)
		# the name plate hangs under the top on the side facing the centre
		Mt = M @ Matrix.Translation((0.0, d / 2 - 0.1, 0.0)) @ Matrix.Rotation(radians(180), 4, "Z") @ RX(90)
		P = S.FK(KD, Mt)
		P["V_Dark"].prism(ccw(S.cham_rect(-1.9, 1.9, top - 1.3, top - 0.52, 0.12)), 0.0, 0.1)
		S.add_text(P["E_White"], label, 0.46, 0.05, y0=top - 1.12, z0=0.1, s=0.2)
		S.collider(area, M, -w / 2 + 0.2, w / 2 - 0.2, -d / 2 + 0.2, d / 2 - 0.2, 0.0, top, "B")
		S.light(M, 0, 0, 10.0, WHITE, 1.5, 13, 50)
	gun_display(name + "Gun", M @ Vector((0.0, 0.0, top + 0.06)), M.to_3x3() @ Vector((1, 0, 0)), (0, 0, 1), gid, scale, fill=w - 1.4)


def gun_wall(K, KD, area, M, u, guns, w=22.0, y0=7.0, h=11.0, cols=(-7.0, 0.0, 7.0), rows=(2.5, 5.8, 9.1), scale=1.9, name="GunWall"):
	"""A pegboard gun wall in wall frame M (X along the wall, Y up, Z out), centred at u: a framed dark board on
	standoff brackets, a light grid, two hooks under each gun, and a LobbyGunDisplay spot per gun (the player's own
	skins hang there, barrels along the wall)."""
	B = M @ Matrix.Translation((u, 0.0, 0.0))
	z0, z1 = 0.95, 1.25
	with C.grp(name, B):
		G = S.FK(KD, B)
		G["V_Dark"].box(-w / 2, w / 2, y0, y0 + h, z0, z1)
		S.ring_prism(G["V_Trim"], ccw(S.cham_rect(-w / 2 - 0.45, w / 2 + 0.45, y0 - 0.45, y0 + h + 0.45, 0.3)), ccw(S.cham_rect(-w / 2 + 0.05, w / 2 - 0.05, y0 + 0.05, y0 + h - 0.05, 0.1)), z0 - 0.05, z1 + 0.12)
		for gx in [(-w / 2) + 2.0 * k for k in range(1, int(w / 2.0))]:
			G["V_Panel"].box(gx - 0.05, gx + 0.05, y0 + 0.1, y0 + h - 0.1, z1, z1 + 0.03)
		for gy in [y0 + 2.0 * k for k in range(1, int(h / 2.0) + 1) if 2.0 * k < h - 0.2]:
			G["V_Panel"].box(-w / 2 + 0.1, w / 2 - 0.1, gy - 0.05, gy + 0.05, z1, z1 + 0.03)
		for bx in (-w / 2 + 1.0, w / 2 - 1.0):
			for by in (y0 + 1.0, y0 + h - 1.0):
				G["V_Steel"].box(bx - 0.4, bx + 0.4, by - 0.4, by + 0.4, 0.4, z0)
		for (cx, ry) in [(cx, ry) for ry in rows for cx in cols]:
			for hx in (cx - 1.6, cx + 1.6):
				yb = y0 + ry - 0.98  # one L-shaped hook: out from the board, a lip turned up at the end
				G["V_Steel"].ext_x(ccw([(yb, z1 - 0.02), (yb + 0.16, z1 - 0.02), (yb + 0.16, z1 + 0.6), (yb + 0.36, z1 + 0.6), (yb + 0.36, z1 + 0.75), (yb, z1 + 0.75)]), hx - 0.1, hx + 0.1)
		S.light(B, 0, y0 + h + 1.5, 4.0, WHITE, 1.4, 16, 70)
	R = B.to_3x3()
	k = 0
	for ry in rows:
		for cx in cols:
			if k >= len(guns):
				break
			gid = guns[k]
			k += 1
			gun_display(name + "_" + gid, B @ Vector((cx, y0 + ry, z1)), R @ Vector((1, 0, 0)), R @ Vector((0, 0, 1)), gid, scale, mount="Wall", fill=5.9)


def hang_lamp(KD, x0, x1, y, z, ceil_z, name="HangLamp"):
	"""A hanging tube lamp (RIVALS' weapons room hangs long tubes): a faceted hex housing along X, a glowing lens
	strip under it, end caps, two rods up into the ceiling."""
	with C.grp(name):
		hx = [(y + 0.62 * cos(radians(30 + 60 * q)), z + 0.62 * sin(radians(30 + 60 * q))) for q in range(6)]
		KD["V_Dark"].ext_x(ccw(hx), x0, x1)
		KD["E_White"].box(x0 + 0.4, x1 - 0.4, y - 0.26, y + 0.26, z - 0.62, z - 0.5)
		for ex in (x0, x1):
			KD["V_Trim"].ext_x(ccw([(a, b) for a, b in [(y + 0.72 * cos(radians(30 + 60 * q)), z + 0.72 * sin(radians(30 + 60 * q))) for q in range(6)]]), ex - 0.25, ex + 0.25)
		for rx in (x0 + 1.6, x1 - 1.6):
			KD["V_Steel"].box(rx - 0.09, rx + 0.09, y - 0.09, y + 0.09, z + 0.5, ceil_z + 0.3)
	S.light(Matrix.Identity(4), (x0 + x1) / 2, y, z - 0.8, WHITE, 1.3, 30, 90)
