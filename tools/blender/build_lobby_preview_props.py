# build_lobby_preview_props.py: the Lobby kit PROPS preview (vault/02 Art/Lobby Kit.md, "Preview renders", step 3).
#
# Three small sets, each built from real kit pieces at stud scale and rendered from third-person height:
#   props-duels.jpg    the 2V2 section of the Duels hall from the west aisle edge, across to the hero bay and down the
#                      aisle: DuelsBayShell_15 chapel bays with QueuePad_15 and BaySign (live bays have their own cool
#                      pool, dormant ones the grey ring), a QueueTerminal on a divider nose with a mannequin at it, a
#                      mannequin on the hero deck, and the 3V3 DuelsArch (red tally lamps) with the 3V3 bays beyond.
#   props-market.jpg   a ShopPavilion (18 wide x 10 deep x 12, "SKINS") set into faceted rock on the Market street;
#                      warm light, a mannequin at the counter.
#   props-weapons.jpg  a GunChapel bay of the Armoury with a GunTurntable and a display-scale rifle stand-in (16 long)
#                      under the TrophyWall (a frieze of six real-size stand-ins); neutral museum light.
#
# KIT PIECES are built once, in kit space and with the conventions of lobbykit.py, into their own collections
# Lobby_<Piece> under "Kit" (excluded from the view layer), and the sets place them as collection instances, so the
# .blend holds exactly one clean copy of every piece:
#   straight pieces (DuelsBayShell_15, DuelsArch, BaySign, ShopPavilion, TrophyWall): origin on the floor at the centre
#     of the back face, facing +X, width along Y (BaySign: origin at the bottom centre of its back face).
#   round pieces (GunChapel): origin at the Armoury centre on the floor; the bay runs from bearing 0 to 33.75.
#   props (QueuePad_15, QueueTerminal, GunTurntable): origin on the floor at the centre, front facing +X.
# Objects are <Piece>_<Part>; Neon parts are separate *_Glow objects. Text objects and anything flagged
# preview_only (SurfaceGui text and pips, the stand-in rifles, the shop's placeholder item, mannequins) are not kit
# geometry and are left out of the triangle counts. Recoloured copies (a dormant pad, a dormant sign) live in
# "KitVariants": they share the kit meshes and only swap the Neon material per object, as the game recolours the
# *_Glow parts at runtime. Each set's context (floors, rock, piers, trusses) lives in Set_<Zone>.
#
# LIGHT: Neon lights nothing (lobbykit._emissive emits to camera rays only). Every wash is a K.rbx_light() (shadowless,
# with its Roblox class, Range and Angle), counted per zone at the end of the run (PROPS_LIGHTS lines). Big soft
# "*_Ambient" lights stand in for Lighting.Ambient / OutdoorAmbient and are not dynamic lights.
#
# Run (headless):
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
#       --python tools/blender/build_lobby_preview_props.py -- [--no-render] [--samples N] [--only duels|market|weapons]
#       [--cam x y z tx ty tz [lens] --out <jpg>]   (a close-up check in the --only set, coordinates relative to it)
# Writes art-source/lobby/PreviewProps.blend and vault/02 Art/References/lobby/kit/props-<zone>.jpg, and prints
# the triangle count of every kit piece and the dynamic light budget.

import json, math, os, sys, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
import lobbykit as K  # noqa: E402
import gunkit  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []

SET_OFFSETS = {"duels": Vector((0, 0, 0)), "market": Vector((600, 0, 0)), "weapons": Vector((1200, 0, 0))}
TEXT_X = (90, 0, 90)  # K.text rotation that faces +X (kit front), reading along +Y
FACE_X = Matrix.Rotation(math.radians(90), 4, "Z") @ Matrix.Rotation(math.radians(90), 4, "X")  # same, as a matrix


# ---------------------------------------------------------------- small helpers

def frame(origin, x_axis, z_axis):
	# Matrix whose local X / Z map to the given world directions (Y completes a right-handed frame).
	x = Vector(x_axis).normalized()
	z = Vector(z_axis).normalized()
	y = z.cross(x).normalized()
	z = x.cross(y).normalized()
	m = Matrix.Identity(4)
	for i in range(3):
		m[i][0], m[i][1], m[i][2], m[i][3] = x[i], y[i], z[i], Vector(origin)[i]
	return m


def bay_frame(b):
	# Plan frame of a radial direction: local X = tangent (clockwise, the viewer's right when looking out from the
	# centre), local Y = radial out along bearing b, Z up.
	return frame((0, 0, 0), K.bearing_dir(b + 90), (0, 0, 1))


def heading(v):
	# Blender heading (degrees, 0 = +X, 90 = +Y) of a plan vector, for K.avatar / K.facing.
	return math.degrees(math.atan2(v[1], v[0]))


def cyl_x(x0, x1, r, z, segs=12):
	return K.mat_all(gunkit.cyl_x(x0, x1, r, z, segs=segs), 0)


def cyl_y(x, z, r, y0, y1, segs=8):
	return K.mat_all(gunkit.cyl_y(x, z, r, y0, y1, segs=segs), 0)


def hide(bm, down=True, up=False):
	# Deletes faces nobody sees (on the floor / under a lid), to keep the kit inside its triangle budget.
	if down:
		gunkit.drop(bm, 2, -1)
	if up:
		gunkit.drop(bm, 2, 1)
	return bm


def drop_feet(bm, z=0.0):
	# Deletes only the downward faces lying on the floor (keeps soffits and other undersides).
	bm.normal_update()
	bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.normal.z < -0.99 and f.calc_center_median().z < z + 0.01], context="FACES")
	return bm


def lbox(m, x0, x1, y0, y1, z0, z1, ch=0.0, mat=0):
	bm = K.cbox(x0, x1, y0, y1, z0, z1, ch=ch, mat=mat) if ch > 0 else K.mat_all(K.box(x0, x1, y0, y1, z0, z1), mat)
	return K.place(bm, m)


def poly_prism(pts, z0, z1, mat=0):
	# Vertical prism of a plan polygon (x, y) points, CCW or CW.
	return K.mat_all(K.prism(pts, "Z", z0, z1), mat)


def arc_pts(r, b0, b1, steps):
	return [tuple(K.polar(r, b0 + (b1 - b0) * i / steps).to_2d()) for i in range(steps + 1)]


def opening_prism(inner, outer, x0, x1, ch=0.25):
	# A frame around an opening, extruded along X (x0 back face .. x1 front face): `inner` and `outer` are matching
	# (y, z) polylines from one foot round to the other. Only the convex edges get the 0.25 chamfer, so inside corners
	# stay crisp and outside corners mitre cleanly (no pointed "capitals").
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
	bmesh.ops.bevel(bm, geom=edges, offset=ch, offset_type="OFFSET", segments=1, profile=0.5, affect="EDGES", clamp_overlap=True)
	return bm


def preview(ob):
	ob["preview_only"] = True
	return ob


def text_at(body, size, m, col, mat, font=K.FONT_HEAVY, align="CENTER", spacing=1.0, name=None):
	ob = K.text(body, size, (0, 0, 0), col, mat, font=font, align=align, spacing=spacing, name=name)
	ob.matrix_world = m
	return ob


def ui_text(body, size, m, loc, col, mat, **kw):
	# SurfaceGui text on a +X facing face of a piece placed at `m` (loc in the piece's local space).
	return text_at(body, size, m @ Matrix.Translation(loc) @ FACE_X, col, mat, **kw)


def instance(name, piece, matrix, col):
	e = bpy.data.objects.new(name, None)
	e.instance_type = "COLLECTION"
	e.instance_collection = piece
	e.matrix_world = matrix
	e.empty_display_size = 2
	col.objects.link(e)
	return e


def variant(piece, suffix, swaps, parent):
	# A recoloured copy of a kit piece (a dormant pad or sign): its objects share the piece's mesh data, and only the
	# swapped materials are linked per object, the way the game recolours *_Glow parts at runtime.
	col = K.collection("%s__%s" % (piece.name, suffix), parent)
	col["preview_variant"] = True
	for ob in piece.objects:
		o2 = ob.copy()
		o2.name = "%s__%s" % (ob.name, suffix)
		col.objects.link(o2)
		if ob.type == "MESH" and len(o2.material_slots):
			m = o2.material_slots[0].material
			if m is not None and m.name in swaps:
				o2.material_slots[0].link = "OBJECT"
				o2.material_slots[0].material = swaps[m.name]
	return col


def rlight(rbx_class, name, loc, energy, color, zone, rng, angle=None, spread=None, **kw):
	# K.rbx_light plus the Roblox Range as the light's cutoff distance and the SurfaceLight Angle as the area spread,
	# so a preview light reaches no further than the real one would.
	ob = K.rbx_light(rbx_class, name, loc, energy, color, zone=zone, rbx_range=rng, angle=angle, **kw)
	ld = ob.data
	try:
		ld.use_custom_distance = True
		ld.cutoff_distance = rng
	except AttributeError:
		pass
	if spread is not None and ld.type == "AREA":
		ld.spread = math.radians(spread)
	return ob


def ambient(name, loc, energy, color, target, size, col):
	# Big soft panel standing in for Lighting.Ambient / OutdoorAmbient (not a dynamic light, not counted).
	ob = K.light("AREA", name + "_Ambient", loc, energy, color, target=target, size=size, shadow=False, col=col)
	ob["rbx_light"] = "Ambient (stand-in)"
	return ob


def tri_count(col):
	per, total = {}, 0
	for ob in col.all_objects:
		if ob.type != "MESH" or ob.get("preview_only"):
			continue
		n = sum(len(p.vertices) - 2 for p in ob.data.polygons)
		per[ob.name] = n
		total += n
	return total, per


# ---------------------------------------------------------------- DUELS pieces

BAY_PITCH = 17.0  # 15 clear + a 2-thick divider shared by neighbours (each piece carries one half)
BAY_CLEAR = 15.0
BAY_WALL = 2.0  # back wall thickness: the bay floor runs x 2..17
BAY_FRONT = 18.0  # aisle line (nose of the dividers); the 1-stud kerb is x 17..18
SOFFIT = 14.0
SOFFIT_TOP = 15.5
SOFFIT_LID = 16.0  # Duels rock starts here
PAD_X = BAY_WALL + BAY_CLEAR / 2  # pad centre in the shell's kit space
AISLE = 11.0  # half width of the 22 aisle: bay noses stand on x = +-11


def piece_duels_bay_shell(kit, mats):
	# DuelsBayShell_15, a chapel bay of the Duels hall (15 clear): ALL honed dark concrete (ConcreteDark, 5-stud saw
	# cuts): the back wall over a recessed black toe, two half dividers with a 0.25 chamfer on the nose, a 14 soffit
	# with a 0.6 downstand beam on the aisle (hides the coffer), a deep dark coffer over the pad (its SpotLight hides
	# there) and a grazer slot along the back wall. The grazer Neon sits on the slot's aisle-side face, looking at the
	# wall, so from the aisle you see the wash, never the strip. Brushed kerb and the red floor edge in the aisle.
	col = K.collection("Lobby_DuelsBayShell_15", kit)
	hw = BAY_PITCH / 2
	cw = BAY_CLEAR / 2
	F = BAY_FRONT
	shell = bmesh.new()
	K.merge(shell, K.cbox(0, BAY_WALL, -cw, cw, 0.45, SOFFIT, ch=0.12))
	for s in (-1, 1):
		a, b, c = s * cw, s * hw, 0.25
		K.merge(shell, poly_prism([(0, a), (F - c, a), (F, a + s * c), (F, b), (0, b)], 0, SOFFIT))
	# Soffit: slabs round the coffer (x 4..15, y +-5.5) and the grazer slot (x 2..2.7), a lid, the downstand beam.
	cx0, cx1, cy = 4.0, 15.0, 5.5
	K.merge(shell, K.box(0, 2.0, -hw, hw, SOFFIT, SOFFIT_TOP))
	K.merge(shell, K.box(2.7, cx0, -hw, hw, SOFFIT, SOFFIT_TOP))
	K.merge(shell, K.box(cx1, F - 0.8, -hw, hw, SOFFIT, SOFFIT_TOP))
	for s in (-1, 1):
		K.merge(shell, K.box(cx0, cx1, min(s * cy, s * hw), max(s * cy, s * hw), SOFFIT, SOFFIT_TOP))
	K.merge(shell, K.box(0, F, -hw, hw, SOFFIT_TOP, SOFFIT_LID))
	K.merge(shell, K.prism([(F - 0.8, SOFFIT - 0.6), (F - 0.2, SOFFIT - 0.6), (F, SOFFIT - 0.4), (F, SOFFIT_TOP), (F - 0.8, SOFFIT_TOP)], "Y", -hw, hw))
	parts = {"Shell": (hide(shell, up=True), "ConcreteDark")}
	parts["Toe"] = (hide(K.box(0, 1.85, -cw, cw, 0, 0.45)), "SteelBlack")  # shadow line at the floor
	parts["Kerb"] = (hide(K.box(F - 1.0, F - 0.4, -cw, cw, 0, 0.3)), "SteelBrushed")
	parts["FloorEdge_Glow"] = (K.glow_strip(F + 0.15, F + 0.35, -hw, hw, 0, 0.03), "Glow_DuelsRed")
	parts["Grazer_Glow"] = (K.glow_strip(2.56, 2.69, -cw + 0.4, cw - 0.4, SOFFIT_TOP - 0.35, SOFFIT_TOP - 0.2), "Glow_Cool")
	K.build("DuelsBayShell_15", parts, mats, col)
	return col


def piece_queue_pad(kit, mats, size=15.0, glow="Glow_2v2"):
	# QueuePad_15: the trim_pad family (deck, brushed channel, Ring_Glow 0.1 below the deck) with a mid-grey deck
	# (#9A968F, so the pool reads as a lit floor, not a lit tray) and a thin black steel "stand here" inlay 1 stud
	# inside the deck edge.
	name = "QueuePad_%d" % size
	col = K.collection("Lobby_" + name, kit)
	parts = K.trim_pad(size, size, mode_glow=glow)
	parts["Deck"] = (parts["Deck"][0], "PadDeck")
	inlay = bmesh.new()
	a = size / 2 - 2.0
	t = 0.12
	for s in (-1, 1):
		K.merge(inlay, K.box(-a, a, s * a - t / 2, s * a + t / 2, 0.47, 0.505))
		K.merge(inlay, K.box(s * a - t / 2, s * a + t / 2, -a + t / 2, a - t / 2, 0.47, 0.505))
	parts["Inlay"] = (inlay, "SteelBlack")
	K.build(name, parts, mats, col)
	return col


def piece_bay_sign(kit, mats, glow="Glow_2v2"):
	# BaySign 14 x 7: trim_sign_frame with the mode edge strip. Its text, count and slot pips are a SurfaceGui, put on
	# per bay by sign_ui() (not kit geometry).
	col = K.collection("Lobby_BaySign", kit)
	K.build("BaySign", K.trim_sign_frame(14.0, 7.0, mode_glow=glow), mats, col)
	return col


def sign_ui(prefix, m, col, mats, mode, glow, queued, slots, live=True):
	# The BaySign SurfaceGui (preview): mode in its colour, "N / M QUEUED", and one 0.8 square pip per player slot,
	# outlined in the mode colour and filled when that slot is queued. Dormant: all dim grey.
	gm = mats[glow] if live else mats["SignTextDim"]
	ui_text(mode, 3.6, m, (0.47, 0, 4.6), col, gm, name=prefix + "_Mode")
	ui_text("%d / %d QUEUED" % (queued, slots), 0.95, m, (0.47, 0, 2.75), col, mats["SignText"] if live else mats["SignTextDim"], name=prefix + "_Count")
	outline, fill = bmesh.new(), bmesh.new()
	size, gap, t, z, x = 0.8, 0.4, 0.1, 1.2, 0.47
	y0 = -(slots * size + (slots - 1) * gap) / 2
	for i in range(slots):
		a = y0 + i * (size + gap)
		b = a + size
		if i < queued:
			K.merge(fill, K.box(x - 0.02, x, a, b, z, z + size))
		else:
			K.merge(outline, K.box(x - 0.02, x, a, b, z, z + t))
			K.merge(outline, K.box(x - 0.02, x, a, b, z + size - t, z + size))
			K.merge(outline, K.box(x - 0.02, x, a, a + t, z + t, z + size - t))
			K.merge(outline, K.box(x - 0.02, x, b - t, b, z + t, z + size - t))
	for nm, bm in (("Outline", outline), ("Fill", fill)):
		if len(bm.faces):
			preview(K.add_glow(prefix + "_Pips" + nm, K.place(bm, m), gm, col))
		else:
			bm.free()


TERM_SCREEN = None  # (centre, normal) of the terminal screen in its kit space, set by piece_queue_terminal


def piece_queue_terminal(kit, mats):
	# QueueTerminal 3 x 3 x 5 (prop, front +X): a black steel lectern on a recessed toe with a cool under-glow, an
	# angled 2.5 x 1.6 screen (centre 4.2 up, so it meets a 5-stud avatar's face) in a brushed bezel, a brushed hand
	# ledge and a red tally lamp. The screen is a SurfaceGui (preview UI here) and its SurfaceLight is the light on
	# your face.
	global TERM_SCREEN
	col = K.collection("Lobby_QueueTerminal", kit)
	prof = [(-1.5, 0.35), (0.55, 0.35), (0.55, 3.1), (1.5, 3.5), (-0.15, 4.95), (-1.5, 4.95)]
	body = K.prism(prof, "Y", -1.5, 1.5)
	K.bevel(body, 0.1, segs=1, angle=30)
	parts = {"Body": (hide(body), "SteelBlack")}
	parts["Toe"] = (hide(K.box(-1.35, 0.3, -1.35, 1.35, 0, 0.36)), "SteelBlack")
	parts["Toe_Glow"] = (K.glow_strip(0.22, 0.32, -1.3, 1.3, 0.02, 0.1), "Glow_Cool")
	a, b = Vector((1.5, 0, 3.5)), Vector((-0.15, 0, 4.95))
	s = (b - a).normalized()
	n = Vector((-s.z, 0, s.x))
	if n.x < 0:
		n = -n
	mid = (a + b) / 2
	m = frame(mid, Vector((0, 1, 0)), n)  # local X = +Y (reads left to right from the front), Z = out
	if m.col[1].to_3d().dot(s) < 0:  # local Y up the slope
		m = frame(mid, Vector((0, -1, 0)), n)
	TERM_SCREEN = (mid.copy(), n.copy())
	parts["Bezel"] = (lbox(m, -1.4, 1.4, -0.95, 0.95, 0.0, 0.06, ch=0.03), "SteelBrushed")
	parts["Screen"] = (lbox(m, -1.25, 1.25, -0.8, 0.8, 0.06, 0.09), "Screen")
	parts["Ledge"] = (K.cbox(0.4, 1.75, -1.35, 1.35, 3.18, 3.36, ch=0.05), "SteelBrushed")
	parts["Tally_Glow"] = (K.glow_strip(-1.2, -0.8, 1.5, 1.56, 4.55, 4.75), "Glow_DuelsRed")
	K.build("QueueTerminal", parts, mats, col)

	def at(u, v, w=0.1):
		mm = m.copy()
		mm.translation = (m @ Vector((u, v, w)).to_4d()).to_3d()
		return mm

	# Screen UI stand-in: a lit navy page, a title and three mode rows with their colour bars.
	preview(K.add_glow("QueueTerminal_UI_Page", lbox(m, -1.22, 1.22, -0.77, 0.77, 0.09, 0.095), mats["TerminalUI"], col))
	text_at("QUEUE", 0.36, at(0, 0.5), col, mats["SignText"], name="QueueTerminal_UI_Title")
	for i, (mode, g) in enumerate((("1V1", "Glow_1v1"), ("2V2", "Glow_2v2"), ("3V3", "Glow_3v3"))):
		v = 0.1 - i * 0.36
		text_at(mode, 0.26, at(-0.75, v), col, mats["SignText"], name="QueueTerminal_UI_%s" % mode)
		bar = lbox(m, -0.35, 0.95, v - 0.08, v + 0.08, 0.095, 0.105)
		preview(K.add_glow("QueueTerminal_UI_Bar%d" % i, bar, mats[g], col))
	return col


ARCH_W = 22.0
ARCH_H = 16.0
ARCH_PIER = 4.0
ARCH_TOP = 20.0
ARCH_D = 4.0
ARCH_SHOULDER = 3.0


def arch_outlines():
	hw, sh = ARCH_W / 2, ARCH_SHOULDER
	inner = [(-hw, 0), (-hw, ARCH_H - sh), (-hw + sh, ARCH_H), (hw - sh, ARCH_H), (hw, ARCH_H - sh), (hw, 0)]
	ow = hw + ARCH_PIER
	outer = [(-ow, 0), (-ow, ARCH_TOP), (-hw + sh, ARCH_TOP), (hw - sh, ARCH_TOP), (ow, ARCH_TOP), (ow, 0)]
	return inner, outer


def piece_duels_arch(kit, mats):
	# DuelsArch: the section arch over the 22 aisle, 16 clear, 45-degree chamfered shoulders, 4 deep, 4-wide piers and
	# a lintel to 20 (rock above), honed dark concrete. A charcoal title slot sits on both lintel faces (the mode title
	# is a SurfaceGui) and a pair of short red TALLY LAMPS sits on the jambs just under the shoulders, near the back
	# face (x = 0, which faces spawn), each in a black steel housing. No continuous edge line (it read as Tron).
	col = K.collection("Lobby_DuelsArch", kit)
	inner, outer = arch_outlines()
	parts = {"Frame": (opening_prism(inner, outer, 0, ARCH_D), "ConcreteDark")}
	slot = bmesh.new()
	K.merge(slot, K.cbox(-0.12, 0.02, -7.0, 7.0, ARCH_H + 0.55, ARCH_TOP - 0.55, ch=0.04))
	K.merge(slot, K.cbox(ARCH_D - 0.02, ARCH_D + 0.12, -7.0, 7.0, ARCH_H + 0.55, ARCH_TOP - 0.55, ch=0.04))
	parts["TitleSlot"] = (slot, "SignPanel")
	hw = ARCH_W / 2
	z1 = ARCH_H - ARCH_SHOULDER - 0.35
	housing, lamp = bmesh.new(), bmesh.new()
	for s in (-1, 1):
		K.merge(housing, K.cbox(0.35, 1.05, min(s * hw, s * (hw - 0.06)), max(s * hw, s * (hw - 0.06)), z1 - 1.9, z1, ch=0.02))
		K.merge(lamp, K.box(0.55, 0.85, min(s * (hw - 0.06), s * (hw - 0.1)), max(s * (hw - 0.06), s * (hw - 0.1)), z1 - 1.7, z1 - 0.2))
	parts["TallyHousing"] = (housing, "SteelBlack")
	parts["Tally_Glow"] = (lamp, "Glow_DuelsRed")
	K.build("DuelsArch", parts, mats, col)
	return col


# ---------------------------------------------------------------- MARKET pieces

PAV_W, PAV_D, PAV_H = 18.0, 10.0, 12.0
PAV_CEIL = 9.0  # clear height inside (header and roof slab above)
PAV_STAGE = 0.4
PAV_FIN = 1.0
SLAT_BK, SLAT_D = 0.2, 0.35  # slat backing and slat depth
SLAT_SIDE_X1 = 8.0  # side-return slats stop here (the last 2 studs of the fin stay concrete)
VIT = (5.8, -5.3)  # vitrine centre (beside the counter, on the viewer's left)
COUNTER = (4.6, 7.0, -2.4, 5.4)  # x0, x1, y0, y1
COUNTER_TOP = 3.7  # 3.3 above the stage: about a 5-stud avatar's elbow


def slat(c, z0, z1, wall, sign=1):
	# One oak slat 1 wide x 0.35 deep with 0.06 chamfered front edges, as a prism of only the faces you can see (no
	# back, top or bottom: 10 triangles). wall "X": on the back wall (width along Y at y = c, front facing +X);
	# wall "Y": on a side return at y = sign * (inner face), width along X at x = c, front facing -sign * Y.
	t = 0.06
	if wall == "X":
		xb, xf = SLAT_BK, SLAT_BK + SLAT_D
		pts = [(xb, c - 0.5), (xf - t, c - 0.5), (xf, c - 0.5 + t), (xf, c + 0.5 - t), (xf - t, c + 0.5), (xb, c + 0.5)]
	else:
		yb = sign * (PAV_W / 2 - PAV_FIN - SLAT_BK)
		yf = yb - sign * SLAT_D
		pts = [(c - 0.5, yb), (c - 0.5, yf + sign * t), (c - 0.5 + t, yf), (c + 0.5 - t, yf), (c + 0.5, yf + sign * t), (c + 0.5, yb)]
	bm = poly_prism(pts, z0, z1)
	gunkit.drop(bm, 2, -1)
	gunkit.drop(bm, 2, 1)
	if wall == "X":
		gunkit.drop(bm, 0, -1)
	else:
		gunkit.drop(bm, 1, sign)
	return bm


def piece_shop_pavilion(kit, mats):
	# ShopPavilion 18 wide x 10 deep x 12: a board-formed concrete frame (one inverted-U profile: 1-thick fins, a
	# 3-deep roof slab over a 9 clear opening; convex edges chamfered, corners mitred), a terrazzo stage with a brushed
	# nosing, oak slats 1 on 1.5 wrapping the back wall and both side returns (on black backing) washed from a hidden
	# cove behind a black steel pelmet (trim_cove), a symmetric black steel canopy blade (0.6 visible, 2.5 out) with a
	# warm cove behind its fascia, the header sign in the sign family (0.4 black steel edge, charcoal panel, 0.3 warm
	# zone strip), an oak counter on a black toe (warm toe glow) with a POS screen, and a floor-standing vitrine beside
	# it (1.2 black column, 3 x 3 x 3 glass, black cap, a cradle for the item).
	col = K.collection("Lobby_ShopPavilion", kit)
	hw = PAV_W / 2
	iw = hw - PAV_FIN
	inner = [(-iw, 0), (-iw, PAV_CEIL), (iw, PAV_CEIL), (iw, 0)]
	outer = [(-hw, 0), (-hw, PAV_H), (hw, PAV_H), (hw, 0)]
	parts = {"Frame": (drop_feet(opening_prism(inner, outer, 0, PAV_D)), "ConcreteBoard")}
	parts["Stage"] = (K.cbox(0, PAV_D - 0.1, -iw, iw, 0, PAV_STAGE, ch=0.05), "Terrazzo")
	parts["StageNosing"] = (K.box(PAV_D - 0.15, PAV_D + 0.02, -iw, iw, 0.0, PAV_STAGE), "SteelBrushed")
	# Oak slats on the back wall and both side returns, on black backing.
	z0, z1 = PAV_STAGE, PAV_CEIL
	yi = iw - SLAT_BK - SLAT_D  # inside face of the side slats
	sl = bmesh.new()
	n = int((2 * yi - 1.0) // 1.5) + 1
	y0 = -((n - 1) * 1.5) / 2
	for i in range(n):
		K.merge(sl, slat(y0 + i * 1.5, z0, z1, "X"))
	for sgn in (-1, 1):
		c = SLAT_BK + SLAT_D + 0.95
		while c + 0.5 <= SLAT_SIDE_X1:
			K.merge(sl, slat(c, z0, z1, "Y", sgn))
			c += 1.5
	parts["Slats"] = (sl, "Oak")
	bk = bmesh.new()
	K.merge(bk, K.box(0, SLAT_BK, -iw, iw, z0, z1))
	for sgn in (-1, 1):
		K.merge(bk, K.box(SLAT_BK, SLAT_SIDE_X1 + 0.3, min(sgn * iw, sgn * (iw - SLAT_BK)), max(sgn * iw, sgn * (iw - SLAT_BK)), z0, z1))
	gunkit.drop(bk, 0, -1)
	parts["SlatBacking"] = (hide(bk, up=True), "SteelBlack")
	# Slat cove: trim_cove downlight pelmet under the roof, in front of the back slats.
	cove = K.trim_cove(2 * yi, lip=0.75, shelf=0.8, up=False)
	for k, (bm, mname) in cove.items():
		K.place(bm, Matrix.Translation((SLAT_BK + SLAT_D, 0, PAV_CEIL)))
		parts["SlatCove_Glow" if k.endswith("_Glow") else "Pelmet"] = (bm, mname)
	# Canopy blade: symmetric, frame width + 0.5 each side, 2.5 out; 0.35 blade + a fascia hanging to 0.6 that hides
	# the cove strip under the blade.
	cw = hw + 0.5
	ct = PAV_CEIL + 0.1
	cx1 = PAV_D + 2.5
	steel = bmesh.new()
	K.merge(steel, K.cbox(PAV_D - 0.2, cx1, -cw, cw, ct - 0.35, ct, ch=0.04))
	K.merge(steel, K.cbox(cx1 - 0.15, cx1, -cw, cw, ct - 0.6, ct, ch=0.03))
	for s in (-1, 1):  # end returns, so the blade reads as a shallow tray from any angle
		K.merge(steel, K.cbox(PAV_D, cx1 - 0.1, min(s * cw, s * (cw - 0.15)), max(s * cw, s * (cw - 0.15)), ct - 0.6, ct, ch=0.03))
	parts["Canopy"] = (steel, "SteelBlack")
	parts["Canopy_Glow"] = (K.glow_strip(cx1 - 0.5, cx1 - 0.2, -cw + 0.3, cw - 0.3, ct - 0.5, ct - 0.35), "Glow_Cove")
	# Header sign (sign family) on the roof slab face, above the blade.
	sign = K.trim_sign_frame(14.4, 2.75, mode_glow="Glow_Cove")
	for k, nm in (("Frame", "SignFrame"), ("Panel", "SignPanel"), ("Strip_Glow", "SignStrip_Glow")):
		parts[nm] = (K.place(sign[k][0], Matrix.Translation((PAV_D, 0, ct + 0.08))), sign[k][1])
	# Counter: oak body on a recessed black toe (warm toe glow), black steel top, and a POS screen on a post.
	c0, c1, cy0, cy1 = COUNTER
	parts["CounterBody"] = (K.cbox(c0, c1, cy0, cy1, 0.75, COUNTER_TOP - 0.25, ch=0.06), "Oak")
	cs = bmesh.new()
	K.merge(cs, hide(K.cbox(c0 + 0.3, c1 - 0.3, cy0 + 0.3, cy1 - 0.3, PAV_STAGE, 0.76, ch=0.03)))
	K.merge(cs, K.cbox(c0 - 0.3, c1 + 0.3, cy0 - 0.3, cy1 + 0.3, COUNTER_TOP - 0.25, COUNTER_TOP, ch=0.06))
	K.merge(cs, K.cbox(c0 + 0.6, c0 + 1.0, 3.6, 4.0, COUNTER_TOP, COUNTER_TOP + 0.75, ch=0.03))  # POS post
	parts["CounterSteel"] = (cs, "SteelBlack")
	pos = frame((c0 + 0.85, 3.8, COUNTER_TOP + 1.0), Vector((0, 1, 0)), Vector((1, 0, 0.75)))
	parts["PosScreen"] = (lbox(pos, -0.6, 0.6, -0.4, 0.4, 0.0, 0.08), "Screen")
	parts["Toe_Glow"] = (K.glow_strip(c1 - 0.33, c1 - 0.25, cy0 + 0.4, cy1 - 0.4, PAV_STAGE + 0.02, PAV_STAGE + 0.1), "Glow_Cove")
	# Vitrine on the floor beside the counter.
	vx, vy = VIT
	vs = bmesh.new()
	K.merge(vs, hide(K.cbox(vx - 0.6, vx + 0.6, vy - 0.6, vy + 0.6, PAV_STAGE, 3.35, ch=0.06), up=True))
	K.merge(vs, K.cbox(vx - 1.6, vx + 1.6, vy - 1.6, vy + 1.6, 3.35, 3.5, ch=0.04))
	K.merge(vs, K.cbox(vx - 1.6, vx + 1.6, vy - 1.6, vy + 1.6, 6.5, 6.7, ch=0.04))
	K.merge(vs, hide(K.box(vx - 0.15, vx + 0.15, vy - 0.75, vy + 0.75, 3.5, 3.62)))
	for dy, top in ((0.6, 4.05), (-0.6, 4.12)):
		K.merge(vs, hide(K.box(vx - 0.12, vx + 0.12, vy + dy - 0.07, vy + dy + 0.07, 3.62, top)))
	parts["Vitrine"] = (vs, "SteelBlack")
	parts["VitrineGlass"] = (hide(K.box(vx - 1.5, vx + 1.5, vy - 1.5, vy + 1.5, 3.5, 6.5), up=True), "Glass")
	# Set into rock: a 0.45 shadow gap round the fins and roof, lined in black steel 1.7 deep, with a warm Neon strip
	# tucked into its back outer corner (a lit slot, not a tube; visible height under 0.3).
	g = 0.45
	liner = bmesh.new()
	for s in (-1, 1):
		K.merge(liner, K.box(5.0, 8.3, min(s * hw, s * (hw + g)), max(s * hw, s * (hw + g)), 0, PAV_H + g))
	K.merge(liner, K.box(5.0, 8.3, -hw - g, hw + g, PAV_H, PAV_H + g))
	parts["GapLiner"] = (hide(liner), "SteelBlack")
	gl = bmesh.new()
	for s in (-1, 1):
		K.merge(gl, K.box(8.3, 8.42, min(s * (hw + g - 0.13), s * (hw + g - 0.03)), max(s * (hw + g - 0.13), s * (hw + g - 0.03)), 0.05, PAV_H + g - 0.03))
	K.merge(gl, K.box(8.3, 8.42, -hw - g + 0.03, hw + g - 0.03, PAV_H + g - 0.13, PAV_H + g - 0.03))
	parts["Gap_Glow"] = (gl, "Glow_Cove")
	K.build("ShopPavilion", parts, mats, col, uv_rotate=("Slats", "CounterBody"))
	K.text("SKINS", 1.5, (PAV_D + 0.47, 0, ct + 0.08 + 1.53), col, mats["SignText"], rot=TEXT_X, spacing=1.1, name="ShopPavilion_Title")
	return col


# ---------------------------------------------------------------- WEAPONS pieces

CH_B0, CH_SPAN = 0.0, 33.75
CH_BC = CH_B0 + CH_SPAN / 2
CH_R_STAGE = 43.0  # stage front, just behind the piers
CH_R_BACK = 56.0  # chord ends on this radius
CH_FACE = CH_R_BACK * math.cos(math.radians(CH_SPAN / 2))  # back wall inner face along the bay centre (53.59)
CH_TOP = 18.0
TT_R = 48.0  # turntable centre radius (the 10-wide turntable spans R43..53)
SLOT_R = (44.3, 45.7)  # the light slot, in front of the gun (behind the drum head at R42..44)
COVE_Y = CH_FACE - 1.0  # the roof stops here: the back cove slot runs along the wall
TROPHY_ROWS = (11.6, 14.7)  # a frieze above the turntable gun, so the hero never hides the trophies
TROPHY_COLS = (-6.4, 0.0, 6.4)
TT_TOP = 1.8  # platter top above the stage
RIFLE_Z = TT_TOP + 0.5 + 3.2  # rifle origin above the stage: the magazine clears the platter by 0.5
PLAQUE = (37.8, 39.0, 3.4, 8.4)  # r0, r1 (3 studs in front of the piers), x0, x1 (to the viewer's right)


def piece_gun_chapel(kit, mats):
	# GunChapel (round, origin at the Armoury centre): one 33.75-degree bay from R43 to a flat back wall on the R56
	# chord. Polished stage with a brushed nosing, SMOKED board-formed concrete (#5A5955) half side walls (neighbours
	# make 2-thick fins) and back wall, and a roof at 18 with two hidden light slots. The KEY slot in front of the gun
	# holds its SpotLight (front-top on the gun and platter); its Neon sits on the slot's near face looking outward,
	# behind a 0.5 black pelmet, so from the Armoury you see the light, never the strip. The COVE along the back wall
	# (behind a black pelmet) holds a dimmer SurfaceLight that washes the trophy wall. A sloped 0.8 name plaque stands
	# on the floor 3 studs in front of the piers, to one side.
	col = K.collection("Lobby_GunChapel", kit)
	bf = bay_frame(CH_BC)
	b0, b1 = CH_B0, CH_B0 + CH_SPAN
	half = CH_FACE * math.tan(math.radians(CH_SPAN / 2))
	stage = arc_pts(CH_R_STAGE, b0, b1, 6) + [tuple(K.polar(CH_R_BACK, b1).to_2d()), tuple(K.polar(CH_R_BACK, b0).to_2d())]
	parts = {"Stage": (hide(poly_prism(stage, 0, 0.5)), "ConcretePolished")}
	parts["Nosing"] = (hide(K.arc(CH_R_STAGE - 0.02, CH_R_STAGE + 0.16, b0 + 1.0, b1 - 1.0, 0.0, 0.5, steps=6), up=True), "SteelBrushed")
	walls = bmesh.new()
	for b, x0, x1 in ((b0, 0.0, 1.0), (b1, -1.0, 0.0)):
		K.merge(walls, lbox(bay_frame(b), x0, x1, 42.5, CH_R_BACK + 0.6, 0, CH_TOP, ch=0.2))
	K.merge(walls, lbox(bf, -half - 0.6, half + 0.6, CH_FACE, CH_FACE + 1.5, 0, CH_TOP + 1.6, ch=0.2))
	parts["Walls"] = (hide(walls, up=True), "ConcreteBoardSmoked")
	roof = K.arc(42.0, SLOT_R[0], b0, b1, CH_TOP, CH_TOP + 1.0, steps=6)
	rr = COVE_Y / math.cos(math.radians(CH_SPAN / 2))
	back = arc_pts(SLOT_R[1], b0, b1, 6)[::-1] + [tuple(K.polar(rr, b0).to_2d()), tuple(K.polar(rr, b1).to_2d())]
	K.merge(roof, poly_prism(back, CH_TOP, CH_TOP + 1.0))
	K.merge(roof, K.arc(SLOT_R[0] - 0.2, SLOT_R[1] + 0.2, b0, b1, CH_TOP + 1.0, CH_TOP + 1.6, steps=6))
	K.merge(roof, lbox(bf, -half, half, COVE_Y - 0.2, CH_FACE, CH_TOP + 1.0, CH_TOP + 1.6))
	parts["Roof"] = (hide(roof, down=False, up=True), "ConcreteBoardSmoked")
	pel = K.arc(SLOT_R[0] - 0.15, SLOT_R[0], b0 + 0.6, b1 - 0.6, CH_TOP - 0.5, CH_TOP + 0.02, steps=6)
	K.merge(pel, lbox(bf, -half + 0.1, half - 0.1, COVE_Y - 0.25, COVE_Y, CH_TOP - 0.6, CH_TOP + 0.02))
	parts["Pelmet"] = (hide(pel, down=False, up=True), "SteelBlack")
	parts["Slot_Glow"] = (hide(K.arc(SLOT_R[0], SLOT_R[0] + 0.12, b0 + 1.0, b1 - 1.0, CH_TOP + 0.7, CH_TOP + 0.85, steps=6), up=True), "Glow_Neutral")
	parts["Cove_Glow"] = (lbox(bf, -half + 0.4, half - 0.4, CH_FACE - 0.2, CH_FACE - 0.02, CH_TOP + 0.65, CH_TOP + 0.85), "Glow_Neutral")
	r0, r1, x0, x1 = PLAQUE
	pl = K.prism([(r0, 0.0), (r1, 0.0), (r1, 0.8), (r0, 0.3)], "X", x0, x1)  # crisp (no bevel: keeps the chapel <= 400)
	parts["Plaque"] = (hide(K.place(pl, bf)), "SignPanel")
	K.build("GunChapel", parts, mats, col)
	# Plaque text on the slope (SurfaceGui in game).
	u = K.bearing_dir(CH_BC)
	t = K.bearing_dir(CH_BC + 90)
	slope = Vector((0, 0, 0.5)) + u * (r1 - r0)
	nrm = t.cross(slope).normalized()
	if nrm.dot(-u) < 0:
		nrm = -nrm
	mid = u * ((r0 + r1) / 2) + t * ((x0 + x1) / 2) + Vector((0, 0, 0.55))
	sl = slope.normalized()
	text_at("PULSE", 0.5, frame(mid + nrm * 0.03 + sl * 0.12, t, nrm), col, mats["SignText"], name="GunChapel_Name")
	text_at("ASSAULT RIFLE", 0.2, frame(mid + nrm * 0.03 - sl * 0.32, t, nrm), col, mats["SignTextDim"], font=K.FONT_LABEL, name="GunChapel_Class")
	return col


TW_HW, TW_Z0, TW_Z1 = 10.0, 9.4, 16.3


def piece_trophy_wall(kit, mats):
	# TrophyWall (straight piece: back face on the wall, facing +X): a #9E9A93 concrete panel (no joints) set 0.25 back inside a
	# black steel frame 0.4 deep (the reveal shows the black tray), brushed peg pairs for 6 real-size guns in 2 rows
	# and a charcoal name tab under each gun (its name is a SurfaceGui).
	col = K.collection("Lobby_TrophyWall", kit)
	hw, z0, z1, fb, rv = TW_HW, TW_Z0, TW_Z1, 0.3, 0.25
	parts = {"Tray": (hide(K.box(0, 0.12, -hw, hw, z0, z1), up=True), "SteelBlack")}
	parts["Panel"] = (hide(K.cbox(0.12, 0.4, -hw + rv, hw - rv, z0 + rv, z1 - rv, ch=0.04), up=True), "TrophyPanel")
	frm = bmesh.new()
	for y0, y1, za, zb in ((-hw - fb, hw + fb, z1, z1 + fb), (-hw - fb, hw + fb, z0 - fb, z0), (-hw - fb, -hw, z0, z1), (hw, hw + fb, z0, z1)):
		K.merge(frm, K.cbox(0, 0.52, y0, y1, za, zb, ch=0.04))
	parts["Frame"] = (frm, "SteelBlack")
	pegs, tabs = bmesh.new(), bmesh.new()
	for zr in TROPHY_ROWS:
		for yc in TROPHY_COLS:
			for dy in (-1.35, 1.35):
				K.merge(pegs, K.prism(K.ring_pts(yc + dy, zr - 0.42, 0.09, 6), "X", 0.4, 1.0))
			K.merge(tabs, gunkit.drop(K.box(0.4, 0.5, yc - 0.95, yc + 0.95, zr - 1.75, zr - 1.42), 0, -1))
	parts["Pegs"] = (pegs, "SteelBrushed")
	parts["Tabs"] = (tabs, "SignPanel")
	K.build("TrophyWall", parts, mats, col)
	return col


def piece_gun_turntable(kit, mats):
	# GunTurntable (10 across, prop, origin on the floor at the centre, front +X): a low black steel drum (1.5) on a
	# recessed toe with the white under-glow, a brushed 10-wide rim, a 0.3 light honed platter, and two slim brushed
	# rods (0.25) with black saddles that hold a display-scale rifle side-on (muzzle along +Y) with its magazine 0.5
	# above the platter.
	col = K.collection("Lobby_GunTurntable", kit)
	parts = {
		"Toe": (hide(K.cyl(0, 0, 4.3, 0, 0.3, segs=32), up=True), "SteelBlack"),
		"Drum": (hide(K.cyl(0, 0, 4.65, 0.3, TT_TOP - 0.3, segs=32, ch=0.08), up=True), "SteelBlack"),
		"Rim": (hide(K.arc(4.55, 5.0, 0, 360, TT_TOP - 0.35, TT_TOP, steps=32)), "SteelBrushed"),
		"Platter": (hide(K.cyl(0, 0, 4.5, TT_TOP - 0.3, TT_TOP, segs=32, ch=0.05)), "ConcretePolished"),
		"Under_Glow": (hide(K.arc(4.32, 4.5, 0, 360, 0.02, 0.2, steps=32), up=True), "Glow_Neutral"),
	}
	rods, sad = bmesh.new(), bmesh.new()
	for y, top in ((4.0, RIFLE_Z - 0.53), (-4.0, RIFLE_Z + 0.02)):
		K.merge(rods, hide(K.cyl(0, y, 0.125, TT_TOP, top - 0.12, segs=8), up=True))
		K.merge(rods, hide(K.cyl(0, y, 0.3, TT_TOP, TT_TOP + 0.08, segs=12)))
		K.merge(sad, hide(K.cbox(-0.36, 0.36, y - 0.3, y + 0.3, top - 0.14, top, ch=0.03)))
	parts["Rods"] = (rods, "SteelBrushed")
	parts["Saddles"] = (sad, "SteelBlack")
	K.build("GunTurntable", parts, mats, col)
	return col


def rifle(scale=1.0, lod=False, optic=True):
	# Display-scale rifle stand-in (not kit: the real guns come from the weapons pipeline). Gun space like gunkit:
	# +X muzzle, +Z up, +Y gun-left; at scale 1 it is 16.35 long (x -8.05..8.3) with the bore at z 0.2.
	# Returns {part: (bm, material name)}. lod drops the bevels and small detail (trophy-wall copies).
	P, D, M, L = "GunPolymer", "SteelBlack", "SteelBrushed", "Screen"
	bev = (lambda bm, w: K.bevel(bm, w, segs=1, angle=30)) if not lod else (lambda bm, w: bm)
	segs = 8 if lod else 14
	parts = {}

	def add(name, bm, mat):
		if name in parts:
			K.merge(parts[name][0], bm)
		else:
			parts[name] = (bm, mat)

	add("Receiver", bev(K.prism([(-2.7, -0.5), (-2.35, -0.9), (1.75, -0.9), (2.3, -0.45), (2.3, 0.8), (-2.7, 0.8)], "Y", -0.5, 0.5), 0.07), D)
	add("Receiver", bev(K.prism([(-0.05, -0.9), (1.6, -0.9), (1.5, -1.25), (0.05, -1.25)], "Y", -0.55, 0.55), 0.04), D)
	add("Receiver", bev(K.box(-2.5, 6.6, -0.33, 0.33, 0.8, 1.05), 0.03), D)  # top rail
	add("Handguard", bev(K.prism([(2.3, -0.55), (6.35, -0.55), (6.75, -0.3), (6.75, 0.8), (2.3, 0.8)], "Y", -0.46, 0.46), 0.08), P)
	add("Barrel", cyl_x(6.7, 7.7, 0.19, 0.2, segs=segs), M)
	add("Muzzle", bev(cyl_x(7.6, 8.3, 0.32, 0.2, segs=segs), 0.04), D)
	add("Receiver", K.box(6.85, 7.15, -0.26, 0.26, -0.12, 0.55), D)  # gas block
	add("Grip", bev(K.prism([(-0.5, -0.9), (-1.5, -0.9), (-2.25, -2.6), (-2.05, -2.8), (-1.3, -2.8), (-0.72, -1.45)], "Y", -0.42, 0.42), 0.09), P)
	add("Receiver", K.box(-0.8, 0.1, -0.1, 0.1, -1.5, -1.36), D)  # trigger guard
	add("Receiver", K.box(-0.55, -0.4, -0.07, 0.07, -1.36, -0.9), D)  # trigger
	add("Mag", bev(K.prism([(0.05, -1.25), (1.4, -1.25), (1.6, -2.05), (2.05, -2.95), (0.9, -3.2), (0.32, -2.15)], "Y", -0.4, 0.4), 0.07), D)
	add("Receiver", cyl_x(-4.5, -2.65, 0.3, 0.3, segs=segs), D)  # buffer tube
	add("Stock", bev(K.prism([(-4.3, 0.68), (-7.5, 0.68), (-7.8, 0.48), (-7.8, -1.12), (-7.45, -1.28), (-6.95, -1.28), (-4.3, -0.08)], "Y", -0.34, 0.34), 0.08), P)
	add("Receiver", bev(K.box(-8.02, -7.78, -0.36, 0.36, -1.25, 0.6), 0.04), D)  # butt pad
	if not lod:
		add("Receiver", K.box(-2.95, -2.6, -0.68, 0.68, 0.5, 0.75), D)  # charging handle
		add("Detail", K.box(-0.5, 1.1, -0.535, -0.49, 0.05, 0.55), M)  # ejection port cover (right side)
		for x0, x1 in ((2.9, 3.75), (4.05, 4.9), (5.2, 6.05)):  # handguard slots
			add("Receiver", K.box(x0, x1, -0.49, 0.49, -0.16, 0.2), D)
		for i in range(15):  # rail teeth
			x = -2.35 + i * 0.6
			add("Receiver", K.box(x, x + 0.3, -0.33, 0.33, 1.05, 1.15), D)
		add("Stock", K.prism([(-5.0, 0.3), (-6.95, 0.3), (-6.95, -0.72), (-6.15, -0.72)], "Y", -0.365, 0.365), D)  # cheek recess
	if optic:
		add("Optic", K.box(-0.6, 1.3, -0.3, 0.3, 1.05, 1.5), D)
		add("Optic", cyl_x(-1.2, 1.9, 0.36, 1.9, segs=segs + 2), D)
		add("Optic", bev(cyl_x(1.45, 2.2, 0.48, 1.9, segs=segs + 2), 0.04), D)
		add("Optic", bev(cyl_x(-1.55, -0.85, 0.44, 1.9, segs=segs + 2), 0.04), D)
		if not lod:
			add("Optic", K.box(0.15, 0.6, -0.2, 0.2, 2.2, 2.5), D)
			add("Optic", cyl_y(0.4, 1.9, 0.19, -0.58, 0.0, segs=8), D)
		add("Lens", cyl_x(2.2, 2.23, 0.4, 1.9, segs=segs + 2), L)
	else:
		add("Receiver", K.box(6.2, 6.5, -0.1, 0.1, 1.05, 1.6), D)  # front post
		add("Receiver", K.box(-2.0, -1.6, -0.25, 0.25, 1.05, 1.55), D)  # rear aperture
	if scale != 1.0:
		for bm, _ in parts.values():
			K.place(bm, Matrix.Scale(scale, 4))
	return parts


def build_rifle(prefix, mats, col, matrix, **kw):
	parts = rifle(**kw)
	obs = []
	for part, (bm, mname) in parts.items():
		K.place(bm, matrix)
		ob = K.add_obj("%s_%s" % (prefix, part), bm, [mats[mname]], col, smooth_angle=30)
		ob["preview_only"] = True
		obs.append(ob)
	return obs


# ---------------------------------------------------------------- stage per set

def zone_world(kind, ambient_strength=None, **over):
	z = dict(K.ZONES[kind])
	if ambient_strength is not None:
		z["ambient_strength"] = ambient_strength
	z.update(over)
	w = bpy.data.worlds.new("World_" + kind)
	K._world_nodes(w, z)
	return w


# Duels bays: (tag, side, centre y, mode, live, queued). The 2V2 section (y 0..34), then the 3V3 section beyond its
# arch (y 38..72). A live bay has its own pool; a dormant one shows the grey ring and a dim sign, no light. The 3V3
# bays reuse the 15-wide shell and pad as placeholders for DuelsBayShell_17 / QueuePad_17 (not built yet).
DUELS_BAYS = (
	("E1", 1, 8.5, "2v2", True, 1), ("E2", 1, 25.5, "2v2", True, 0), ("W1", -1, 8.5, "2v2", False, 0), ("W2", -1, 25.5, "2v2", True, 0),
	("E3", 1, 46.5, "3v3", False, 0), ("E4", 1, 63.5, "3v3", True, 2), ("W3", -1, 46.5, "3v3", False, 0), ("W4", -1, 63.5, "3v3", False, 0),
)
MODE_SLOTS = {"2v2": 4, "3v3": 6}
TERM_AT = (9.3, 17.0, 215.0)  # x, y, heading: on the east divider nose between E1 and E2, turned toward the aisle and spawn


def set_duels(cols, mats, pieces, variants):
	c = cols["duels"]
	O = SET_OFFSETS["duels"]
	T = Matrix.Translation(O)
	back = AISLE + BAY_FRONT  # back face of the bays (x = +-29)
	K.add_obj("Duels_Floor", lbox(T, -45, 45, -30, 90, -1, 0), [mats["ConcreteDark"]], c)
	for tag, side, yc, mode, live, queued in DUELS_BAYS:
		key = mode if live else "dormant"
		if side > 0:
			m = T @ K.facing(180, (back, yc, 0))
			pad = T @ Matrix.Translation((back - PAD_X, yc, 0))
		else:
			m = T @ K.facing(0, (-back, yc, 0))
			pad = T @ Matrix.Translation((-back + PAD_X, yc, 0))
		instance("Bay_" + tag, pieces["DuelsBayShell_15"], m, c)
		instance("Pad_" + tag, pieces["QueuePad_15"] if key == "2v2" else variants["QueuePad_15"][key], pad, c)
		sm = m @ Matrix.Translation((BAY_WALL, 0, 5.6))
		instance("Sign_" + tag, pieces["BaySign"] if key == "2v2" else variants["BaySign"][key], sm, c)
		sign_ui("Sign_%s_UI" % tag, sm, c, mats, mode.upper(), "Glow_" + mode, queued, MODE_SLOTS[mode], live)
	# Cross walls beside the arch piers (both arches) and the section's outer walls behind the bays.
	for s in (1, -1):
		for y0, y1 in ((-4.0, 0.0), (34.0, 38.0)):
			K.add_obj("Duels_CrossWall_%d_%d" % (s, y0), lbox(T, min(s * 15, s * 31), max(s * 15, s * 31), y0, y1, 0, 26, ch=0.2), [mats["ConcreteDark"]], c)
		K.add_obj("Duels_BackWall_%d" % s, lbox(T, min(s * 29, s * 31), max(s * 29, s * 31), -4.0, 72.0, 0, 26), [mats["ConcreteDark"]], c)
		K.add_glow("Duels_ArchFloorEdge_%d" % s, K.place(K.glow_strip(s * 10.75 - 0.1, s * 10.75 + 0.1, -4, 0, 0, 0.03), T), mats["Glow_DuelsRed"], c)
		K.add_glow("Duels_Arch2FloorEdge_%d" % s, K.place(K.glow_strip(s * 10.75 - 0.1, s * 10.75 + 0.1, 34, 38, 0, 0.03), T), mats["Glow_DuelsRed"], c)
	K.add_obj("Duels_FarEnd", lbox(T, -31, 31, 72, 74, 0, 26), [mats["ConcreteDark"]], c)
	for name, y0, title, glow in (("Arch_2v2", -4.0, "2V2", "Glow_2v2"), ("Arch_3v3", 34.0, "3V3", "Glow_3v3")):
		instance(name, pieces["DuelsArch"], T @ K.facing(90, (0, y0, 0)), c)
		K.text(title, 2.4, O + Vector((0, y0 - 0.14, 18.05)), c, mats[glow], rot=(90, 0, 0), name=name + "_TitleS")
		K.text(title, 2.4, O + Vector((0, y0 + ARCH_D + 0.14, 18.05)), c, mats[glow], rot=(90, 0, 180), name=name + "_TitleN")
		rock = K.rock_face(ARCH_W + 2 * ARCH_PIER, 6.5, seed=60 + int(y0), cell=1.8, depth=2.0, relief=1.4, ledges=2)
		K.place(rock, T @ K.facing(90, (0, y0 + ARCH_D - 2.6, ARCH_TOP - 0.3)))
		K.add_obj(name + "_RockAbove", rock, [mats["RockDuels"]], c, smooth_angle=0)
	# Duels rock above the soffit lids (y 16 up), the nave ceiling and the open black steel trusses.
	for s in (1, -1):
		rock = K.rock_face(42, 10.0, seed=71 if s > 0 else 77, cell=1.8, depth=2.4, relief=2.0, ledges=4)
		K.place(rock, T @ K.facing(180 if s > 0 else 0, (s * 13.6, 17.0, SOFFIT_LID)))
		K.add_obj("Duels_Clerestory_%d" % s, rock, [mats["RockDuels"]], c, smooth_angle=0)
		rock = K.rock_face(34, 10.0, seed=83 if s > 0 else 89, cell=1.8, depth=2.4, relief=2.0, ledges=4)
		K.place(rock, T @ K.facing(180 if s > 0 else 0, (s * 13.6, 55.0, SOFFIT_LID)))
		K.add_obj("Duels_FarRock_%d" % s, rock, [mats["RockDuels"]], c, smooth_angle=0)
	K.add_obj("Duels_Nave", lbox(T, -16, 16, -4, 74, 26, 27), [mats["SteelBlack"]], c)
	for i, yc in enumerate((8.5, 25.5, 46.5, 63.5)):
		tr = bmesh.new()
		for z0 in (21.0, 24.6):
			K.merge(tr, K.cbox(-12, 12, yc - 0.35, yc + 0.35, z0, z0 + 0.6, ch=0.06))
		for k in range(8):
			x0 = -10.5 + k * 3.0
			pts = [(x0, 21.6), (x0 + 0.6, 21.6), (x0 + 3.0, 24.6), (x0 + 2.4, 24.6)] if k % 2 == 0 else [(x0, 24.6), (x0 + 0.6, 24.6), (x0 + 3.0, 21.6), (x0 + 2.4, 21.6)]
			K.merge(tr, K.prism(pts, "Y", yc - 0.2, yc + 0.2))
		K.add_obj("Duels_Truss%d" % i, K.place(tr, T), [mats["SteelBlack"]], c)
	# Queue terminal on the divider nose between W1 and W2, with an avatar at it, plus one on the hero pad deck.
	tx, ty, th = TERM_AT
	tm = T @ K.facing(th, (tx, ty, 0))
	instance("Terminal", pieces["QueueTerminal"], tm, c)
	mid, nrm = TERM_SCREEN
	scr = (tm @ mid.to_4d()).to_3d()
	nw = (tm.to_3x3() @ nrm).normalized()
	side = Vector((nw.y, -nw.x, 0)).normalized()  # the terminal's right (toward the aisle north)
	at = scr + nw * 1.7 + side * 2.0
	at.z = 0.0
	look = scr - at
	K.avatar(at, heading(look), col=c, name="Duels_Avatar_Terminal")
	K.avatar(O + Vector((back - PAD_X - 1.5, 9.5, 0.5)), 200.0, col=c, name="Duels_Avatar_Pad")
	# Light (all shadowless): a SpotLight pool per live bay from its dark coffer, a SurfaceLight grazer per live bay
	# down its back wall, and the terminal screen's SurfaceLight (the glow on the avatar's face).
	lc = cols["duels_lights"]
	for tag, side, yc, _, live, _ in DUELS_BAYS:
		if not live:
			continue
		px = side * (back - PAD_X)
		qx = side * (back - PAD_X - 3.5)  # tilted toward the aisle, so each pool spills a tongue of light out of its bay
		rlight("SpotLight", "Duels_Pool_" + tag, O + Vector((px, yc, 15.2)), 30000, K.L_DUELS, "duels", 22, angle=70, target=O + Vector((qx, yc, 0)), spot=70, blend=0.8, size=2.0, col=lc)
		gx = side * (back - BAY_WALL - 0.35)
		rlight("SurfaceLight", "Duels_Grazer_" + tag, O + Vector((gx, yc, SOFFIT_TOP - 0.3)), 4500, K.L_DUELS, "duels", 16, angle=90, spread=110, target=O + Vector((side * (back - BAY_WALL + 0.6), yc, 0)), size=13.5, size_y=0.3, col=lc)
	rlight("SurfaceLight", "Duels_TerminalScreen", scr + nw * 0.15, 450, 0x9CC0FF, "duels", 8, angle=120, spread=130, target=scr + nw * 3 - Vector((0, 0, 0.6)), size=2.4, size_y=1.5, col=lc)
	cp, yaw = Vector((-8.5, -2.0, 8.0)), math.radians(39.0)  # west aisle edge, looking across at the hero bay (E1)
	cam = K.camera(O + cp, O + cp + Vector((math.sin(yaw), math.cos(yaw), 0)) * 20, lens=18.0, name="Cam_Duels", col=c, shift=(0.0, -0.05))
	return cam


def set_market(cols, mats, pieces):
	c = cols["market"]
	O = SET_OFFSETS["market"]
	# Everything here is laid out in the pavilion's kit frame (x out into the street, y along it), then placed so the
	# street runs north-south and the pavilion stands in its east wall.
	P = Matrix.Translation(O) @ K.facing(180, (32, 0, 0))
	instance("Pavilion", pieces["ShopPavilion"], P, c)
	K.add_obj("Market_Floor", lbox(P, 6.0, 60.0, -60, 60, -1, 0), [mats["Terrazzo"]], c)
	run = bmesh.new()
	K.merge(run, K.box(22.0, 42.0, -60, 60, 0, 0.04))
	K.add_obj("Market_Runner", K.place(run, P), [mats["Oak"]], c, uv_rotate=True)
	edge = bmesh.new()
	for x in (21.8, 42.0):
		K.merge(edge, K.box(x, x + 0.2, -60, 60, 0, 0.05))
	K.add_obj("Market_RunnerEdge", K.place(edge, P), [mats["SteelBlack"]], c)
	# Rock: the street wall either side of the pavilion on a plinth with the warm shadow gap, rock above it, a leaning
	# slab, and a rock ceiling.
	back = 8.6
	for s, seed in ((1, 3), (-1, 8)):
		w = 40.0
		yc = s * (PAV_W / 2 + 0.45 + w / 2)
		K.build("Market_Wall%d" % s, K.trim_plinth_gap(w, wall_t=1.65), mats, c, P @ Matrix.Translation((back, yc, 0)))
		rock = K.rock_face(w, 28.0, seed=seed, cell=1.4, depth=3.0, relief=2.6, ledges=5)
		K.place(rock, P @ Matrix.Translation((back - 0.8, yc, 2.1)))
		K.add_obj("Market_Rock%d" % s, rock, [mats["Rock"]], c, smooth_angle=0)
	rock = K.rock_face(PAV_W + 0.9, 18.0, seed=13, cell=1.4, depth=3.0, relief=2.6, ledges=4)
	K.place(rock, P @ Matrix.Translation((back - 0.8, 0, PAV_H + 0.45)))
	K.add_obj("Market_RockAbove", rock, [mats["Rock"]], c, smooth_angle=0)
	slab = K.rock_chunk(21, (3.2, 7.5, 15.0), (0, 0, 0), points=26, jag=0.2)
	for v in slab.verts:
		v.co.z = max(v.co.z + 7.2, 0.0)
	K.place(slab, P @ Matrix.Translation((10.6, -17.5, 0)) @ Matrix.Rotation(math.radians(-8), 4, "Y") @ Matrix.Rotation(math.radians(14), 4, "Z"))
	K.add_obj("Market_RockSlab", slab, [mats["Rock"]], c, smooth_angle=0)
	ceil = K.rock_face(120, 52, seed=29, cell=3.0, depth=3.0, relief=2.2, ledges=3)
	K.place(ceil, P @ Matrix.Translation((8.0, 0, 33.0)) @ Matrix.Rotation(math.radians(90), 4, "Y"))
	K.add_obj("Market_Ceiling", ceil, [mats["Rock"]], c, smooth_angle=0)
	far = K.rock_face(120, 30, seed=33, cell=2.4, depth=2.6, relief=2.0, ledges=4)
	K.place(far, P @ K.facing(180, (56.0, 0, 0)))
	K.add_obj("Market_FarWall", far, [mats["Rock"]], c, smooth_angle=0)
	# The display placeholder: a teal skin on a small rifle stand-in, side-on on the vitrine cradle.
	vx, vy = VIT
	build_rifle("Market_Item", mats, c, P @ Matrix.Translation((vx, vy, 4.13)) @ K.rot_z(90), scale=0.14, lod=True)
	for ob in [o for o in c.objects if o.name.startswith("Market_Item")]:
		if ob.name.endswith(("Receiver", "Handguard", "Stock", "Grip")):
			ob.data.materials[0] = mats["PreviewItem"]

	def wpos(x, y, z):
		return (P @ Vector((x, y, z, 1))).to_3d()

	# A customer at the counter (scale check: the counter top is 3.3 above the stage).
	K.avatar(wpos(COUNTER[1] + 1.0, 0.2, PAV_STAGE), heading(P.to_3x3() @ Vector((-1, -0.3, 0))), col=c, name="Market_Avatar")
	# Light (shadowless): the zone's one warm SpotLight on the pavilion front, the canopy cove and the slat cove
	# (SurfaceLights). The street key and fill stand in for the Market's warm Ambient / OutdoorAmbient.
	lc = cols["market_lights"]
	rlight("SpotLight", "Market_Spot", wpos(30, 6, 27), 36000, K.L_MARKET, "market", 45, angle=46, target=wpos(6, 0, 3), spot=46, blend=0.8, size=3.0, col=lc)
	rlight("SurfaceLight", "Market_CanopyCove", wpos(PAV_D + 2.0, 0, PAV_CEIL - 0.55), 1300, K.L_MARKET, "market", 12, angle=110, spread=120, target=wpos(PAV_D + 2.6, 0, 0), size=17.5, size_y=0.6, col=lc)
	rlight("SurfaceLight", "Market_SlatCove", wpos(1.0, 0, PAV_CEIL - 0.3), 1900, K.L_MARKET, "market", 12, angle=120, spread=130, target=wpos(0.75, 0, 0), size=15.0, size_y=0.4, col=lc)
	ambient("Market_Street", wpos(34, 0, 28), 15000, K.L_MARKET, wpos(30, 0, 0), 40, lc)
	ambient("Market_Fill", wpos(60, 10, 12), 5000, 0x3A3028, wpos(8, 0, 5), 40, lc)
	cam = K.camera(wpos(31.0, -8.5, 8.6), wpos(5.0, 1.0, 5.4), lens=26.0, name="Cam_Market", col=c)
	return cam


def set_weapons(cols, mats, pieces):
	c = cols["weapons"]
	O = SET_OFFSETS["weapons"]
	T = Matrix.Translation(O)
	K.add_obj("Weapons_Floor", K.place(K.cyl(0, 0, 44.0, -1, 0, segs=96), T), [mats["Terrazzo"]], c)
	K.add_obj("Weapons_InlayRing", K.place(K.arc(19.6, 20.0, 0, 360, -0.5, 0.01, steps=96), T), [mats["SteelBrushed"]], c, uvs=lambda bm: K.arc_uvs(bm, 20.0))
	names = ("RIFLE 01", "RIFLE 02", "RIFLE 03", "RIFLE 04", "RIFLE 05", "RIFLE 06")
	for k, rot in ((0, 0.0), (1, -CH_SPAN), (-1, CH_SPAN)):
		R = T @ Matrix.Rotation(math.radians(rot), 4, "Z")
		instance("Chapel_%d" % k, pieces["GunChapel"], R, c)
		p = K.polar(TT_R, CH_BC)
		u = K.bearing_dir(CH_BC)
		tt = R @ Matrix.Translation((p.x, p.y, 0.5)) @ Matrix.Rotation(math.atan2(-u.y, -u.x), 4, "Z")
		instance("Turntable_%d" % k, pieces["GunTurntable"], tt, c)
		build_rifle("Weapons_Rifle%d" % k, mats, c, tt @ Matrix.Translation((0, 0, RIFLE_Z)) @ K.rot_z(90))
		tw = R @ bay_frame(CH_BC) @ K.facing(-90, (0, CH_FACE, 0.5))
		instance("TrophyWall_%d" % k, pieces["TrophyWall"], tw, c)
		for zi, zr in enumerate(TROPHY_ROWS):
			for xi, yc in enumerate(TROPHY_COLS):
				m = tw @ Matrix.Translation((0.75, yc, zr - 0.25)) @ K.rot_z(90)
				build_rifle("Weapons_Trophy%d_%d%d" % (k, zi, xi), mats, c, m, scale=0.3, lod=True, optic=(xi + zi) % 2 == 0)
				if k == 0:
					ui_text(names[zi * 3 + xi], 0.2, tw, (0.51, yc, zr - 1.585), c, mats["SignTextDim"], font=K.FONT_LABEL, name="Weapons_TrophyName_%d%d" % (zi, xi))
	# Armoury context (smoked concrete): piers on the chapel bearings, the drum wall head over the chapels, a dark
	# ceiling.
	piers = bmesh.new()
	for b in (-CH_SPAN, 0.0, CH_SPAN, 2 * CH_SPAN):
		K.merge(piers, lbox(bay_frame(b), -1.5, 1.5, 40.0, 42.5, 0, 30, ch=0.25))
		K.merge(piers, lbox(bay_frame(b), -1.62, 1.62, 40.25, 42.5, 0, 1.2, ch=0.06, mat=1))
	K.add_obj("Weapons_Piers", K.place(piers, T), [mats["ConcreteBoardSmoked"], mats["SteelBlack"]], c)
	head = K.arc(42.0, 44.0, -CH_SPAN - 2, 2 * CH_SPAN + 2, CH_TOP, 30.0, steps=24)
	K.add_obj("Weapons_DrumHead", K.place(head, T), [mats["ConcreteBoardSmoked"]], c, uvs=lambda bm: K.arc_uvs(bm, 42.0))
	K.add_obj("Weapons_Ceiling", K.place(K.cyl(0, 0, 46.0, 30.0, 31.0, segs=96), T), [mats["SteelBlack"]], c)
	bf0 = T @ bay_frame(CH_BC)

	def bp(bf, x, y, z):
		return (bf @ Vector((x, y, z, 1))).to_3d()

	# A visitor beside the turntable, looking at the gun (scale: the display rifle is about 3x their height).
	at = bp(bf0, -6.6, 41.4, 0)
	K.avatar(at, heading(bp(bf0, 0, TT_R, 0) - at), col=c, name="Weapons_Avatar")
	# Light (shadowless), two per chapel: the KEY SpotLight hidden in the front slot, aimed outward and down (front-top
	# on the gun and the platter), and a dimmer COVE SurfaceLight washing the trophy wall from the back slot, so the
	# gun stays the brightest thing and the frieze sits in a soft half-light behind it. (One big SurfaceLight per
	# chapel was tried: shadowless, it washed the chapel and its neighbours flat.) The fill stands in for Ambient.
	lc = cols["weapons_lights"]
	for k, rot in ((0, 0.0), (1, -CH_SPAN), (-1, CH_SPAN)):
		bf = T @ Matrix.Rotation(math.radians(rot), 4, "Z") @ bay_frame(CH_BC)
		rlight("SurfaceLight", "Weapons_Cove%d" % k, bp(bf, 0, CH_FACE - 0.6, CH_TOP - 0.2), 1300, K.L_WEAPONS, "weapons", 18, angle=100, spread=100, target=bp(bf, 0, CH_FACE + 0.3, 6.0), size=30.0, size_y=0.5, col=lc)
		rlight("SpotLight", "Weapons_Key%d" % k, bp(bf, 0, sum(SLOT_R) / 2, CH_TOP + 0.4), 36000, K.L_WEAPONS, "weapons", 26, angle=84, target=bp(bf, 0, 48.6, 4.0), spot=84, blend=1.0, size=1.5, col=lc)
	ambient("Weapons_Fill", bp(bf0, -10, 8.0, 14.0), 5000, 0x3A3F48, bp(bf0, 0, TT_R, 6.0), 30, lc)
	cam_pos = (T @ Vector((*K.polar(16.0, CH_BC - 9.0).to_2d(), 9.0, 1))).to_3d()
	look = (T @ Vector((*K.polar(48.0, CH_BC + 1.5).to_2d(), 8.2, 1))).to_3d()
	cam = K.camera(cam_pos, look, lens=30.0, name="Cam_Weapons", col=c)
	return cam


# ---------------------------------------------------------------- main

def extra_materials(mats):
	# Same MaterialVariants as the style sheet with another Color (allowed in Roblox: Color is per part), plus
	# preview-only helpers. Named here so the props scene does not touch the library's definitions.
	mats["PadDeck"] = K._concrete_polished("PadDeck", 0x9A968F)  # Lobby_ConcretePolished, mid grey: queue pad decks
	mats["ConcreteBoardSmoked"] = K._concrete_board("ConcreteBoardSmoked", 0x5A5955)  # Lobby_ConcreteBoard: Weapons
	mats["TrophyPanel"] = K._concrete_polished("TrophyPanel", 0x9E9A93)  # Lobby_ConcretePolished, mid: trophy panel (no grid)
	for name, color, rough, metallic in (("GunPolymer", 0x4B4F56, 0.55, 0.0), ("PreviewItem", 0x23B3A2, 0.32, 0.2)):
		m = K._flat(name, color, rough, metallic=metallic)
		m["preview_only"] = True
		mats[name] = m
	mats["TerminalUI"] = K._emissive("TerminalUI", 0x12284A, 1.0, rbx="SurfaceGui", preview_only=True)


def main():
	t0 = time.time()
	mats = K.begin()
	extra_materials(mats)
	sc = bpy.context.scene
	kit = K.collection("Kit")
	pieces = {
		"DuelsBayShell_15": piece_duels_bay_shell(kit, mats),
		"QueuePad_15": piece_queue_pad(kit, mats),
		"BaySign": piece_bay_sign(kit, mats),
		"QueueTerminal": piece_queue_terminal(kit, mats),
		"DuelsArch": piece_duels_arch(kit, mats),
		"ShopPavilion": piece_shop_pavilion(kit, mats),
		"GunChapel": piece_gun_chapel(kit, mats),
		"GunTurntable": piece_gun_turntable(kit, mats),
		"TrophyWall": piece_trophy_wall(kit, mats),
	}
	kv = K.collection("KitVariants")
	variants = {}
	for piece in ("QueuePad_15", "BaySign"):
		variants[piece] = {
			"dormant": variant(pieces[piece], "Dormant", {"Glow_2v2": mats["Glow_Dormant"]}, kv),
			"3v3": variant(pieces[piece], "3v3", {"Glow_2v2": mats["Glow_3v3"]}, kv),
		}
	for name in ("Kit", "KitVariants"):
		bpy.context.view_layer.layer_collection.children[name].exclude = True
	cols = {}
	for z in ("duels", "market", "weapons"):
		top = K.collection("Set_" + z.capitalize())
		cols[z] = top
		cols[z + "_lights"] = K.collection("Lights_" + z.capitalize(), top)
	cams = {
		"duels": set_duels(cols, mats, pieces, variants),
		"market": set_market(cols, mats, pieces),
		"weapons": set_weapons(cols, mats, pieces),
	}
	worlds = {
		"duels": zone_world("duels", 5.0, ambient=0x1C2028, fill=0x2A3242),
		"market": zone_world("market", 0.9),
		"weapons": zone_world("weapons", 1.6, ambient=0x34363B, fill=0x4A4E56),
	}

	budget = {}
	for name, col in pieces.items():
		total, per = tri_count(col)
		budget[name] = {"total": total, "parts": per}
	stand = {}
	for z in ("duels", "market", "weapons"):
		for ob in cols[z].all_objects:
			if ob.type == "MESH" and ob.get("preview_only") and ("Rifle0" in ob.name or "Trophy0_00" in ob.name or "Market_Item" in ob.name):
				key = ob.name.split("_")[1]
				stand[key] = stand.get(key, 0) + sum(len(p.vertices) - 2 for p in ob.data.polygons)
	print("PROPS_TRIS " + json.dumps({k: v["total"] for k, v in budget.items()}))
	print("PROPS_TRIS_PARTS " + json.dumps(budget))
	print("PROPS_STANDIN_TRIS " + json.dumps(stand))
	K.light_budget("PROPS_LIGHTS")

	only = ARGS[ARGS.index("--only") + 1] if "--only" in ARGS else None
	samples = int(ARGS[ARGS.index("--samples") + 1]) if "--samples" in ARGS else 128

	def activate(z):
		# One render policy for every kit render (lobbykit.bloom): AgX Medium High Contrast, exposure 0, bloom 1.2.
		for k in ("duels", "market", "weapons"):
			cols[k].hide_render = k != z
			cols[k].hide_viewport = k != z
		sc.world = worlds[z]
		sc.camera = cams[z]
		K.render_settings(samples=samples)
		K.bloom()

	activate(only or "duels")
	blend = K.save("PreviewProps")
	print("PROPS saved", blend, "%.1fs" % (time.time() - t0))
	if "--no-render" in ARGS:
		return
	if "--cam" in ARGS:  # close-up check (not a published render): --only <zone> --cam x y z tx ty tz [lens] --out <jpg>
		i = ARGS.index("--cam")
		v = [float(x) for x in ARGS[i + 1:i + 7]]
		lens = float(ARGS[i + 7]) if len(ARGS) > i + 7 and not ARGS[i + 7].startswith("--") else 35.0
		z = only or "duels"
		activate(z)
		o = SET_OFFSETS[z]
		sc.camera = K.camera(o + Vector(v[:3]), o + Vector(v[3:]), lens=lens, name="CamDetail", col=cols[z])
		K.render(ARGS[ARGS.index("--out") + 1])
		return
	for z in ("duels", "market", "weapons"):
		if only and z != only:
			continue
		activate(z)
		out = K.render(os.path.join(K.RENDER_DIR, "props-%s.jpg" % z))
		print("PROPS render", out, "%.1fs" % (time.time() - t0))
	activate(only or "duels")


main()
