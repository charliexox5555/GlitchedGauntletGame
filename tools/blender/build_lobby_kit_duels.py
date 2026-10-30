# build_lobby_kit_duels.py: the Duels kit group of the Lobby (vault/02 Art/Lobby Kit.md, "Duels hall", step 4).
#
# Every piece is a Lobby_<Piece> collection built at the world origin with the Lobby Kit conventions (1 unit = 1 stud,
# +X = the piece's front, +Z up):
#   straight pieces (DuelsBayShell_*, BaySign_*, SignFrame_*, DuelsArch, DuelsTruss_*, GauntletGate, DuelsRock_*,
#     DuelsApseWall, DuelsGap_12): origin on the floor at the centre of the back face, front +X, width along Y.
#   props (QueuePad_*, QueueTerminal, GauntletDais): origin on the floor at the centre, front +X.
# Objects are <Piece>_<Part> (unique over the group); Neon parts are separate *_Glow objects (the game tints pad rings,
# sign strips and arch strips per mode, grey when dormant). Every part has ONE material (index 0), so the exporter
# never splits it.
#
# The pieces fit the greybox in tools/studio/lobby/Wing_Duels.luau (the collision stays the greybox):
#   bays: back wall 2 thick, bay floor D deep, 1-stud kerb, aisle line at |x| = 11. Bay length L along the aisle,
#     2-stud dividers (each shell carries one half). L -> D: 12 -> 12, 15 -> 15, 17 -> 16, 18 -> 17.
#   pads: the full bay (D x L), deck top 0.52 (the greybox deck), ring 1 wide in a brushed channel.
#   signs: a bezel round the greybox sign panels (W x 6, their SurfaceGui stays live), mode strip underneath.
#   arches: 22 x 16 opening with 45-degree shoulders, piers to |x| = 15, lintel to 27 (the nave ceiling), 4 deep.
#
# Run (headless):
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
#       --python tools/blender/build_lobby_kit_duels.py -- [--no-render] [--samples N]
# Writes art-source/lobby/Kit_Duels.blend and vault/02 Art/References/lobby/kit/contact-duels.jpg, and prints the
# triangle count of every piece (KIT_TRIS).

import json, math, os, sys, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
import lobbykit as K  # noqa: E402
import gunkit  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []

SOFFIT = 14.0
SOFFIT_TOP = 15.5
SOFFIT_LID = 16.0
BAY_WALL = 2.0
DEPTH = {12: 12.0, 15: 15.0, 17: 16.0, 18: 17.0}  # bay length -> bay depth (Wing_Duels SECTIONS)
MODE_GLOW = {12: "Glow_1v1", 15: "Glow_2v2", 17: "Glow_3v3", 18: "Glow_4v4"}
ARCH_HW = 10.95  # 0.05 inside the greybox pier faces (no z-fighting with the collision box)
ARCH_OW = 15.0
ARCH_H = 16.0
ARCH_SH = 3.0
ARCH_TOP = 27.0
ARCH_D = 4.0


# ---------------------------------------------------------------- helpers (ported from build_lobby_preview_props.py)

def frame(origin, x_axis, z_axis):
	x = Vector(x_axis).normalized()
	z = Vector(z_axis).normalized()
	y = z.cross(x).normalized()
	z = x.cross(y).normalized()
	m = Matrix.Identity(4)
	for i in range(3):
		m[i][0], m[i][1], m[i][2], m[i][3] = x[i], y[i], z[i], Vector(origin)[i]
	return m


def drop_feet(bm, z=0.0):
	# Deletes the downward faces lying on the floor (nobody sees them).
	bm.normal_update()
	bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.normal.z < -0.99 and f.calc_center_median().z < z + 0.01], context="FACES")
	return bm


def drop_top(bm, z):
	# Deletes the upward faces at or above z (lids nobody sees from below).
	bm.normal_update()
	bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.normal.z > 0.99 and f.calc_center_median().z > z - 0.01], context="FACES")
	return bm


def drop_back(bm, x=0.0):
	# Deletes the faces lying on the back plane x = 0 facing -X (they sit against a wall).
	bm.normal_update()
	bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.normal.x < -0.99 and f.calc_center_median().x < x + 0.01], context="FACES")
	return bm


def B(x0, x1, y0, y1, z0, z1):
	return K.mat_all(K.box(x0, x1, y0, y1, z0, z1), 0)


def CB(x0, x1, y0, y1, z0, z1, ch=0.25):
	return K.cbox(x0, x1, y0, y1, z0, z1, ch=ch, mat=0)


def lbox(m, x0, x1, y0, y1, z0, z1, ch=0.0):
	bm = CB(x0, x1, y0, y1, z0, z1, ch) if ch > 0 else B(x0, x1, y0, y1, z0, z1)
	return K.place(bm, m)


def poly_prism(pts, z0, z1):
	return K.mat_all(K.prism(pts, "Z", z0, z1), 0)


def merge(*bms):
	out = bmesh.new()
	for b in bms:
		K.merge(out, b)
	return out


def opening_prism(inner, outer, x0, x1, ch=0.25):
	# A frame round an opening, extruded along X (x0 back .. x1 front); `inner` and `outer` are matching (y, z)
	# polylines from one foot round to the other. Convex edges get the chamfer.
	bm = bmesh.new()
	fr = [bm.verts.new((x0, y, z)) for y, z in inner]
	fo = [bm.verts.new((x0, y, z)) for y, z in outer]
	br = [bm.verts.new((x1, y, z)) for y, z in inner]
	bo = [bm.verts.new((x1, y, z)) for y, z in outer]
	n = len(inner)
	for i in range(n - 1):
		bm.faces.new((fr[i], fr[i + 1], fo[i + 1], fo[i]))
		bm.faces.new((br[i], bo[i], bo[i + 1], br[i + 1]))
		bm.faces.new((fr[i], br[i], br[i + 1], fr[i + 1]))
		bm.faces.new((fo[i], fo[i + 1], bo[i + 1], bo[i]))
	for k in (0, n - 1):
		bm.faces.new((fr[k], fo[k], bo[k], br[k]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	bm.edges.ensure_lookup_table()
	edges = [e for e in bm.edges if e.is_manifold and e.is_convex and e.calc_face_angle(0) > math.radians(30)]
	if ch > 0:
		bmesh.ops.bevel(bm, geom=edges, offset=ch, offset_type="OFFSET", segments=1, profile=0.5, affect="EDGES", clamp_overlap=True)
	return K.mat_all(bm, 0)


def build(piece, parts, mats, kit):
	# {part: (bmesh, material)} -> objects <piece>_<part> in Lobby_<piece>. Every part has one material (index 0).
	col = K.collection("Lobby_" + piece, kit)
	for part, (bm, mname) in parts.items():
		K.mat_all(bm, 0)
		name = "%s_%s" % (piece, part)
		if part.endswith("_Glow"):
			K.add_glow(name, bm, mats[mname], col)
		else:
			K.add_obj(name, bm, [mats[mname]], col)
	return col


def extra_materials(mats):
	mats["PadDeck"] = K._concrete_polished("PadDeck", 0x7A7771)  # Lobby_ConcretePolished, mid grey: pad decks under their pool
	# Dim cool Neon for hidden sources (coffer rings, grazers, shadow gaps, toes): Roblox Neon at #DDE8F2 read as
	# stark white lines in the dark hall, so these glow at about a third of the cool strip's value.
	mats["Glow_Dim"] = K._emissive("Glow_Dim", 0x5E6E86, 1.2)
	mats["ConcreteDuels"] = K._concrete_dark("ConcreteDuels", 0x2C2D30)  # Lobby_ConcreteDark, darker: Duels walls
	mats["AisleDark"] = K._concrete_dark("AisleDark", 0x242528)


# ---------------------------------------------------------------- bays

def piece_bay_shell(kit, mats, L):
	# DuelsBayShell_<L>: a chapel bay (L clear along the aisle, D deep). Honed dark concrete: back wall over a black
	# toe, two half dividers with a chamfered nose, a 14 soffit (0.6 downstand on the aisle) with a deep coffer over the
	# pad (a cool light ring tucked in its top), a grazer slot along the back wall, a black steel sign recess plate and
	# a brushed kerb.
	D = DEPTH[L]
	hw, cw, F = (L + 2) / 2, L / 2, D + 3.0
	shell = bmesh.new()
	K.merge(shell, CB(0, BAY_WALL, -cw, cw, 0.45, SOFFIT, ch=0.12))
	for s in (-1, 1):
		a, b, c = s * cw, s * hw, 0.25
		K.merge(shell, poly_prism([(0, a), (F - c, a), (F, a + s * c), (F, b), (0, b)], 0, SOFFIT))
	cx0, cx1, cy = 4.0, F - 3.0, cw - 2.0
	K.merge(shell, B(0, 2.0, -hw, hw, SOFFIT, SOFFIT_TOP))
	K.merge(shell, B(2.7, cx0, -hw, hw, SOFFIT, SOFFIT_TOP))
	K.merge(shell, B(cx1, F - 0.8, -hw, hw, SOFFIT, SOFFIT_TOP))
	for s in (-1, 1):
		K.merge(shell, B(cx0, cx1, min(s * cy, s * hw), max(s * cy, s * hw), SOFFIT, SOFFIT_TOP))
	K.merge(shell, B(0, F, -hw, hw, SOFFIT_TOP, SOFFIT_LID))
	K.merge(shell, K.mat_all(K.prism([(F - 0.8, SOFFIT - 0.6), (F - 0.2, SOFFIT - 0.6), (F, SOFFIT - 0.4), (F, SOFFIT_TOP), (F - 0.8, SOFFIT_TOP)], "Y", -hw, hw), 0))
	# The lid's top stays: Roblox casts shadows from front faces only, and the hidden greybox
	# soffit no longer casts, so without it the sun pours into the bays.
	drop_feet(shell)
	drop_back(shell)
	W = L - 3.0
	parts = {"Shell": (shell, "ConcreteDuels")}
	parts["Toe"] = (drop_feet(B(0, 1.85, -cw, cw, 0, 0.45)), "SteelBlack")
	parts["Kerb"] = (drop_feet(CB(F - 1.0, F - 0.02, -cw - 0.98, cw + 0.98, 0, 0.3, ch=0.04)), "SteelBrushed")
	parts["SignRecess"] = (drop_back(CB(BAY_WALL - 0.02, BAY_WALL + 0.06, -(W / 2 + 0.9), W / 2 + 0.9, 5.1, 13.5, ch=0.03), BAY_WALL), "SteelBlack")
	parts["Grazer_Glow"] = (K.glow_strip(2.56, 2.69, -cw + 0.4, cw - 0.4, SOFFIT_TOP - 0.35, SOFFIT_TOP - 0.2), "Glow_Dim")
	ring = bmesh.new()
	t, z0, z1 = 0.14, SOFFIT_TOP - 0.16, SOFFIT_TOP - 0.02
	K.merge(ring, B(cx0 + 0.1, cx1 - 0.1, cy - 0.1 - t, cy - 0.1, z0, z1))
	K.merge(ring, B(cx0 + 0.1, cx1 - 0.1, -cy + 0.1, -cy + 0.1 + t, z0, z1))
	K.merge(ring, B(cx0 + 0.1, cx0 + 0.1 + t, -cy + 0.24, cy - 0.24, z0, z1))
	K.merge(ring, B(cx1 - 0.1 - t, cx1 - 0.1, -cy + 0.24, cy - 0.24, z0, z1))
	parts["Coffer_Glow"] = (ring, "Glow_Dim")
	return build("DuelsBayShell_%d" % L, parts, mats, kit)


def piece_queue_pad(kit, mats, name, D, L, glow):
	# QueuePad_<L>: the trim_pad family over the whole bay (D across, L along the aisle): a mid-grey polished deck at the
	# greybox deck height (0.52), a brushed channel with the Ring_Glow 0.1 below the deck, and a thin black steel
	# "stand here" inlay 2 studs inside the deck edge.
	parts = K.trim_pad(D, L, deck_h=0.52, mode_glow=glow)
	parts["Deck"] = (parts["Deck"][0], "PadDeck")
	for k in ("Base", "Deck", "Channel", "Ring_Glow"):
		drop_feet(parts[k][0])
	inlay = bmesh.new()
	a, b, t = D / 2 - 2.0, L / 2 - 2.0, 0.12
	for s in (-1, 1):
		K.merge(inlay, B(-a, a, s * b - t / 2, s * b + t / 2, 0.49, 0.525))
		K.merge(inlay, B(s * a - t / 2, s * a + t / 2, -b + t / 2, b - t / 2, 0.49, 0.525))
	drop_feet(inlay, 0.49)
	parts["Inlay"] = (inlay, "SteelBlack")
	return build(name, parts, mats, kit)


def sign_frame(W, H, strip_glow, depth=0.6, edge=0.4, strip=0.35):
	# A bezel round a W x H greybox sign panel (its SurfaceGui stays live): 0.4 black steel edge, `depth` deep from the
	# wall (front beyond the greybox panel at 0.35), a charcoal backer, and a coloured strip under the panel. Origin at
	# the bottom centre of the back face. Bottom bezel 0..edge, strip edge..edge+strip, panel opening above.
	zp = edge + strip  # panel bottom
	zt = zp + H  # panel top
	fr = bmesh.new()
	w2 = W / 2
	K.merge(fr, CB(0, depth, -w2 - edge, w2 + edge, zt, zt + edge, ch=0.08))
	K.merge(fr, CB(0, depth, -w2 - edge, w2 + edge, 0, edge, ch=0.08))
	K.merge(fr, CB(0, depth, -w2 - edge, -w2, edge - 0.05, zt + 0.05, ch=0.08))
	K.merge(fr, CB(0, depth, w2, w2 + edge, edge - 0.05, zt + 0.05, ch=0.08))
	drop_back(fr)
	parts = {
		"Frame": (fr, "SteelBlack"),
		"Backer": (drop_back(B(0, 0.04, -w2, w2, edge, zt)), "SignPanel"),
		"Strip_Glow": (K.glow_strip(0.08, 0.34, -w2, w2, edge + 0.04, zp - 0.04), strip_glow),
	}
	return parts


def piece_bay_sign(kit, mats, W, glow):
	return build("BaySign_%d" % W, sign_frame(W, 6.0, glow), mats, kit)


def piece_sign_frame(kit, mats, name, W, H, glow):
	return build(name, sign_frame(W, H, glow), mats, kit)


# ---------------------------------------------------------------- terminal

TERM_SCREEN = None


def piece_queue_terminal(kit, mats):
	# QueueTerminal 3 x 3 x 5 (prop, front +X): a black steel lectern on a recessed toe with a cool under-glow, an
	# angled 2.5 x 1.6 screen (its SurfaceGui is an Art part in Studio), a brushed hand ledge and a red tally lamp.
	global TERM_SCREEN
	prof = [(-1.5, 0.35), (0.55, 0.35), (0.55, 3.1), (1.5, 3.5), (-0.15, 4.95), (-1.5, 4.95)]
	body = K.mat_all(K.prism(prof, "Y", -1.5, 1.5), 0)
	K.bevel(body, 0.1, segs=1, angle=30)
	parts = {"Body": (drop_back(body, -1.5), "SteelBlack")}
	parts["Toe"] = (drop_feet(B(-1.35, 0.3, -1.35, 1.35, 0, 0.36)), "SteelBlack")
	parts["Toe_Glow"] = (K.glow_strip(0.22, 0.32, -1.3, 1.3, 0.02, 0.1), "Glow_Dim")
	a, b = Vector((1.5, 0, 3.5)), Vector((-0.15, 0, 4.95))
	s = (b - a).normalized()
	n = Vector((-s.z, 0, s.x))
	if n.x < 0:
		n = -n
	mid = (a + b) / 2
	m = frame(mid, Vector((0, 1, 0)), n)
	if m.col[1].to_3d().dot(s) < 0:
		m = frame(mid, Vector((0, -1, 0)), n)
	TERM_SCREEN = (tuple(round(v, 4) for v in mid), tuple(round(v, 4) for v in n))
	parts["Bezel"] = (lbox(m, -1.4, 1.4, -0.95, 0.95, 0.0, 0.06, ch=0.03), "SteelBrushed")
	parts["Screen"] = (lbox(m, -1.25, 1.25, -0.8, 0.8, 0.06, 0.09), "Screen")
	parts["Ledge"] = (CB(0.4, 1.75, -1.35, 1.35, 3.18, 3.36, ch=0.05), "SteelBrushed")
	parts["Tally_Glow"] = (K.glow_strip(-1.2, -0.8, 1.5, 1.56, 4.55, 4.75), "Glow_DuelsRed")
	return build("QueueTerminal", parts, mats, kit)


# ---------------------------------------------------------------- arch, trusses, gate

def piece_duels_arch(kit, mats):
	# DuelsArch: the section arch over the 22 aisle, 16 clear, 45-degree chamfered shoulders, 4 deep (0.05 proud of the
	# greybox on both faces), piers out to |y| = 15 and a deep lintel up to the nave ceiling (27). Honed dark concrete.
	# Front (+X, faces spawn): a black steel bezel round the 20 x 8 mode title (greybox SurfaceGui panel, y 17..25)
	# with a mode-colour Strip_Glow under it. A red Edge_Glow along the opening's head, and a pair of red tally lamps on
	# each jamb (both faces).
	hw, sh, ow = ARCH_HW, ARCH_SH, ARCH_OW
	inner = [(-hw, 0), (-hw, ARCH_H - sh), (-hw + sh, ARCH_H), (hw - sh, ARCH_H), (hw, ARCH_H - sh), (hw, 0)]
	outer = [(-ow, 0), (-ow, ARCH_TOP), (-hw + sh, ARCH_TOP), (hw - sh, ARCH_TOP), (ow, ARCH_TOP), (ow, 0)]
	fr = opening_prism(inner, outer, -0.05, ARCH_D + 0.05)
	drop_feet(fr)  # the top stays: the arch is the hall's roof on its line (sun shadow)
	parts = {"Frame": (fr, "ConcreteDuels")}
	xf = ARCH_D + 0.05
	bez = bmesh.new()
	K.merge(bez, B(xf - 0.05, xf + 0.5, -10.4, 10.4, 25.0, 25.4))
	K.merge(bez, B(xf - 0.05, xf + 0.5, -10.4, 10.4, 16.35, 17.0))
	K.merge(bez, B(xf - 0.05, xf + 0.5, -10.4, -10.0, 17.0, 25.0))
	K.merge(bez, B(xf - 0.05, xf + 0.5, 10.0, 10.4, 17.0, 25.0))
	parts["TitleBezel"] = (bez, "SteelBlack")
	parts["TitleBacker"] = (B(xf - 0.02, xf + 0.02, -10.0, 10.0, 17.0, 25.0), "SignPanel")
	parts["Strip_Glow"] = (K.glow_strip(xf + 0.5, xf + 0.56, -9.6, 9.6, 16.55, 16.8), "Glow_1v1")
	parts["Edge_Glow"] = (K.glow_strip(ARCH_D - 0.55, ARCH_D - 0.3, -(hw - sh) + 0.1, hw - sh - 0.1, ARCH_H - 0.1, ARCH_H), "Glow_DuelsRed")
	z1 = ARCH_H - sh - 0.4
	housing, lamp = bmesh.new(), bmesh.new()
	for s in (-1, 1):
		for x0 in (ARCH_D - 1.0,):  # the face toward spawn
			K.merge(housing, CB(x0, x0 + 0.7, min(s * hw, s * (hw - 0.08)), max(s * hw, s * (hw - 0.08)), z1 - 2.2, z1, ch=0.02))
			K.merge(lamp, B(x0 + 0.2, x0 + 0.5, min(s * (hw - 0.08), s * (hw - 0.13)), max(s * (hw - 0.08), s * (hw - 0.13)), z1 - 2.0, z1 - 0.2))
	parts["TallyHousing"] = (housing, "SteelBlack")
	parts["Tally_Glow"] = (lamp, "Glow_DuelsRed")
	return build("DuelsArch", parts, mats, kit)


def truss_mesh(span, z0, depth_z, bay, chord=0.6, thick=0.7, web=0.45):
	# Open Pratt-style truss in the Y-Z plane, `span` long (y -span/2..span/2), bottom chord at z0, top chord at
	# z0 + depth_z, `bay`-stud panels with alternating diagonals and verticals, `thick` along X (centred on x = 0).
	h = thick / 2
	bm = bmesh.new()
	zt = z0 + depth_z
	K.merge(bm, CB(-h, h, -span / 2, span / 2, z0, z0 + chord, ch=0.06))
	K.merge(bm, CB(-h, h, -span / 2, span / 2, zt - chord, zt, ch=0.06))
	n = max(2, int(round(span / bay)))
	step = span / n
	hw2 = web / 2
	for k in range(n + 1):
		y = -span / 2 + k * step
		y = min(max(y, -span / 2 + hw2), span / 2 - hw2)
		K.merge(bm, B(-h * 0.7, h * 0.7, y - hw2, y + hw2, z0 + chord, zt - chord))
	for k in range(n):
		ya, yb = -span / 2 + k * step, -span / 2 + (k + 1) * step
		# Pratt: every diagonal runs down toward mid-span.
		lo, hi = (yb, ya) if k < n / 2 else (ya, yb)
		pts = [(lo - hw2, z0 + chord), (lo + hw2, z0 + chord), (hi + hw2, zt - chord), (hi - hw2, zt - chord)]
		K.merge(bm, K.mat_all(K.prism([(p[0], p[1]) for p in pts], "X", -h * 0.6, h * 0.6), 0))
	return bm


def piece_truss(kit, mats, name, span, z0, depth_z, bay):
	# DuelsTruss_<span>: open black steel truss across the hall, origin on the floor under its centre, chords along Y.
	return build(name, {"Truss": (truss_mesh(span, z0, depth_z, bay), "SteelBlack")}, mats, kit)


def piece_gauntlet_gate(kit, mats):
	# GauntletGate 42 x 30 (front +X, faces spawn): black steel columns (4 x 4) and lintel (26..30) with chamfers, a
	# ribbed dormant shutter set back between the columns, a bezel round the 34 x 12 greybox title (y 7..19) with a
	# gold Strip_Glow under it, red Edge_Glow under the lintel and dim gold column slits (tinted dormant in Studio).
	parts = {}
	cols = bmesh.new()
	for s in (-1, 1):
		K.merge(cols, CB(-0.05, 4.05, min(s * 16.95, s * 21.05), max(s * 16.95, s * 21.05), 0, 26.0, ch=0.12))
	K.merge(cols, CB(-0.05, 4.05, -21.05, 21.05, 26.0, 30.05, ch=0.12))
	drop_feet(cols)
	parts["Frame"] = (cols, "SteelBlack")
	sh = bmesh.new()
	K.merge(sh, B(0.4, 0.6, -17.0, 17.0, 0.0, 26.0))
	for i in range(17):
		z = 0.9 + i * 1.5
		K.merge(sh, CB(0.6, 0.95, -17.0, 17.0, z, z + 0.6, ch=0.04))
	drop_feet(sh)
	parts["Shutter"] = (sh, "SteelBrushed")
	bez = bmesh.new()
	xf = 4.05
	K.merge(bez, CB(xf - 0.05, xf + 0.5, -17.0, 17.0, 19.0, 19.5, ch=0.06))
	K.merge(bez, CB(xf - 0.05, xf + 0.5, -17.0, 17.0, 6.2, 7.0, ch=0.06))
	parts["TitleBezel"] = (bez, "SteelBlack")
	parts["TitleBacker"] = (B(0.95, 4.0, -17.0, 17.0, 7.0, 19.0), "SignPanel")
	parts["Strip_Glow"] = (K.glow_strip(xf + 0.5, xf + 0.56, -16.4, 16.4, 6.4, 6.75), "Glow_Gauntlet")
	parts["Edge_Glow"] = (K.glow_strip(3.2, 3.5, -16.9, 16.9, 25.85, 26.0), "Glow_DuelsRed")
	slit = bmesh.new()
	for s in (-1, 1):
		K.merge(slit, B(4.05, 4.1, min(s * 18.85, s * 19.15), max(s * 18.85, s * 19.15), 1.0, 24.5))
	parts["Slit_Glow"] = (slit, "Glow_Gauntlet")
	return build("GauntletGate", parts, mats, kit)


def piece_gauntlet_dais(kit, mats):
	# GauntletDais (prop, centre on the floor): the apron disc R20 (top 0.11), a step R16 (top 0.6) and the top R12 (top
	# 1.2), matching the greybox cylinders. Brushed nosings, a black steel top with two inset Ring_Glow rings (gold,
	# tinted dormant in Studio) and a cool riser glow under the top step.
	steps = 48
	apron = K.lathe([(0.0, 0.11), (20.0, 0.11), (20.0, 0.0)], steps=steps)
	low = K.lathe([(16.0, 0.0), (16.0, 0.52), (15.92, 0.6), (12.0, 0.6)], steps=steps)
	nose = K.lathe([(16.04, 0.42), (16.04, 0.6), (15.6, 0.6)], steps=steps)
	top = K.lathe([(12.0, 0.6), (12.0, 1.12), (11.92, 1.2), (0.0, 1.2)], steps=steps)
	rings = bmesh.new()
	for r in (10.6, 6.2):
		K.merge(rings, K.arc(r - 0.35, r, 0.0, 360.0, 1.16, 1.24, steps=32))
	drop_feet(rings, 1.16)
	riser = K.lathe([(12.02, 0.66), (12.02, 0.8)], steps=steps)
	parts = {
		"Apron": (apron, "AisleDark"),
		"Low": (low, "PadDeck"),
		"Nose": (nose, "SteelBrushed"),
		"Top": (top, "SteelBlack"),
		"Ring_Glow": (rings, "Glow_Gauntlet"),
		"Riser_Glow": (riser, "Glow_Dim"),
	}
	return build("GauntletDais", parts, mats, kit)


# ---------------------------------------------------------------- rock, apse, gap

def piece_rock(kit, mats, name, seed):
	# DuelsRock_<v>: an 8 x 12 faceted dark rock panel (rock_face), front +X: the surface lies between x = 0.2 and 1.6.
	bm = K.rock_face(8.0, 12.0, seed=seed, cell=1.7, depth=1.6, relief=1.4, ledges=3, chips=0.3)
	col = K.collection("Lobby_" + name, kit)
	K.add_obj(name + "_Rock", K.mat_all(bm, 0), [mats["RockDuels"]], col, smooth_angle=0)
	return col


def gap_parts(length, z0=0.0):
	# Shadow gap where finished concrete meets the rock (0.6 tall), as a black steel band 0.12 proud of the wall with
	# a cool Neon line tucked under its top lip. Front +X, back on x = 0, the band runs z0 .. z0 + 0.6.
	hl = length / 2
	band = drop_back(CB(0.0, 0.12, -hl, hl, z0, z0 + 0.6, ch=0.03))
	lip = drop_back(CB(0.0, 0.32, -hl, hl, z0 + 0.6, z0 + 0.72, ch=0.03))
	return {
		"Band": (merge(band, lip), "SteelBlack"),
		"Gap_Glow": (K.glow_strip(0.12, 0.24, -hl, hl, z0 + 0.48, z0 + 0.6), "Glow_Dim"),
	}


def piece_gap(kit, mats):
	return build("DuelsGap_12", gap_parts(12.0), mats, kit)


def piece_apse_wall(kit, mats):
	# DuelsApseWall: one 11.25-degree chord of the GAUNTLET apse (R36, 7.1 wide): a dark concrete wainscot 0.4 thick up
	# to 16, a black toe, and the shadow gap at 16 where the rock starts.
	w = 7.12
	hl = w / 2
	wall = drop_back(drop_feet(CB(0.0, 0.4, -hl, hl, 0.45, 16.0, ch=0.08)))
	parts = {
		"Wall": (wall, "ConcreteDuels"),
		"Toe": (drop_back(drop_feet(B(0.0, 0.3, -hl, hl, 0.0, 0.45))), "SteelBlack"),
	}
	g = gap_parts(w, 16.0)
	for k, (bm, m) in g.items():
		K.place(bm, Matrix.Translation((0.4, 0, 0)))
		parts[k] = (bm, m)
	return build("DuelsApseWall", parts, mats, kit)


# ---------------------------------------------------------------- contact sheet

def contact_sheet(kit, out, samples):
	sc = bpy.context.scene
	stage = K.collection("Contact")
	pieces = [c for c in kit.children]
	rows = [[], [], []]
	for c in pieces:
		n = c.name[6:]
		if n.startswith(("DuelsBayShell", "DuelsArch", "GauntletGate")):
			rows[0].append(c)
		elif n.startswith(("QueuePad", "GauntletDais", "QueueTerminal")):
			rows[1].append(c)
		else:
			rows[2].append(c)
	y_row = (0.0, -45.0, -80.0)
	mats = {m.name: m for m in bpy.data.materials}
	floor = B(-40, 330, -110, 30, -0.2, 0.0)
	K.add_obj("Contact_Floor", floor, [mats["ConcreteHoned"]], stage)
	for r, cols in enumerate(rows):
		x = 0.0
		for c in cols:
			lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
			for o in c.all_objects:
				if o.type != "MESH":
					continue
				for v in o.data.vertices:
					lo = Vector((min(lo[i], v.co[i]) for i in range(3)))
					hi = Vector((max(hi[i], v.co[i]) for i in range(3)))
			span_y = hi.y - lo.y
			# Lay each piece with its width along world X (turn 90 degrees), front toward the camera (-Y).
			m = Matrix.Translation((x + span_y / 2, y_row[r], 0)) @ Matrix.Rotation(math.radians(-90), 4, "Z")
			e = bpy.data.objects.new("CS_" + c.name, None)
			e.instance_type = "COLLECTION"
			e.instance_collection = c
			e.matrix_world = m
			stage.objects.link(e)
			K.text(c.name[6:], 1.6, (x + span_y / 2, y_row[r] - (hi.x - lo.x) - 3.0, 0.05), stage, mats["SignText"], rot=(0, 0, 0))
			x += span_y + 6.0
	w = bpy.data.worlds.new("ContactWorld")
	sc.world = w
	w.use_nodes = True
	bg = w.node_tree.nodes.get("Background")
	bg.inputs[0].default_value = (0.11, 0.12, 0.14, 1)
	bg.inputs[1].default_value = 1.4
	sun = bpy.data.lights.new("ContactSun", "SUN")
	sun.energy = 3.0
	so = bpy.data.objects.new("ContactSun", sun)
	so.rotation_euler = (math.radians(50), math.radians(10), math.radians(-30))
	stage.objects.link(so)
	cam = K.camera((150, -330, 110), (150, -40, 4), lens=50, col=stage)
	cam.data.type = "ORTHO"
	cam.data.ortho_scale = 330
	sc.camera = cam
	K.render_settings(samples=samples)
	K.bloom()
	K.render(out, res=(2200, 1000))


# ---------------------------------------------------------------- main

def main():
	t0 = time.time()
	mats = K.begin()
	extra_materials(mats)
	kit = K.collection("Kit")
	for L in (12, 15, 17, 18):
		piece_bay_shell(kit, mats, L)
		piece_queue_pad(kit, mats, "QueuePad_%d" % L, DEPTH[L], float(L), MODE_GLOW[L])
		piece_bay_sign(kit, mats, L - 3, MODE_GLOW[L])
	piece_queue_pad(kit, mats, "QueuePad_G18", 18.0, 18.0, "Glow_Gauntlet")
	piece_sign_frame(kit, mats, "SignFrame_11x3", 11.0, 3.0, "Glow_DuelsRed")
	piece_sign_frame(kit, mats, "SignFrame_14x45", 14.0, 4.5, "Glow_DuelsRed")
	piece_queue_terminal(kit, mats)
	piece_duels_arch(kit, mats)
	piece_truss(kit, mats, "DuelsTruss_22", 23.0, 21.0, 4.0, 2.9)
	piece_truss(kit, mats, "DuelsTruss_76", 75.6, 28.4, 5.0, 4.2)
	piece_gauntlet_gate(kit, mats)
	piece_gauntlet_dais(kit, mats)
	for v, seed in (("A", 301), ("B", 317), ("C", 333)):
		piece_rock(kit, mats, "DuelsRock_" + v, seed)
	piece_apse_wall(kit, mats)
	piece_gap(kit, mats)

	budget, worst = {}, {}
	for c in kit.children:
		n = 0
		for o in c.all_objects:
			if o.type == "MESH" and not o.get("preview_only"):
				o.data.calc_loop_triangles()
				t = len(o.data.loop_triangles)
				n += t
				worst[o.name] = t
		budget[c.name[6:]] = n
	print("KIT_TRIS " + json.dumps(budget))
	print("KIT_MAX_OBJECT " + json.dumps(max(worst.items(), key=lambda kv: kv[1])))
	print("TERM_SCREEN " + json.dumps(TERM_SCREEN))
	bpy.context.view_layer.layer_collection.children["Kit"].exclude = True
	blend = K.save("Kit_Duels")
	print("KIT saved", blend, "%.1fs" % (time.time() - t0))
	if "--no-render" in ARGS:
		return
	samples = int(ARGS[ARGS.index("--samples") + 1]) if "--samples" in ARGS else 24
	out = os.path.join(K.RENDER_DIR, "contact-duels.jpg")
	contact_sheet(kit, out, samples)
	# Keep the saved file clean: the contact stage is not part of the kit.
	print("KIT contact", out, "%.1fs" % (time.time() - t0))


main()
