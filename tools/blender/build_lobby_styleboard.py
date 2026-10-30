# build_lobby_styleboard.py: the Lobby kit STYLE BOARD (vault/02 Art/Lobby Kit.md, "Preview renders").
#
# A small gallery under the rotunda lights: a back wall of four trim bays (labelled on the charcoal cap band), a row
# of material samples in front of it and a row of floor finishes at the front, each with a numbered placard. The sun
# patch and the fake Beam ribbons live in the structure render, so every sample here is judged under the same neutral
# light (one gallery spot, one floor key, the cove washes). Neon lights nothing (as in
# Roblox): each wash is a named rbx_light. Two 5-stud mannequins (by T2 and T4) give scale. Real stud scale throughout.
#
# Numbered samples (placards in the render):
#   back row, left to right
#     01 Board-formed concrete (a 6.4 x 6.4 slab = two formwork panels)   06 Granite rock   07 Duels rock (both as
#     4.4 x 5.2 rock_face slabs with benches, the way the rock is used)
#     08 Black steel   09 Brushed steel   10 Warm oak   11 Brass   12 Glass
#     13 Neon, left to right: cove, cool, Duels red, 1V1, 2V2, 3V3, 4V4, Gauntlet, dormant
#   front row (floor finishes), left to right
#     02 Sun hot-spot inlay   03 Polished concrete   04 Honed dark concrete   05 Terrazzo
#     T5 queue pad (2V2)
#   The gallery floor itself is 04 (saw cuts every 5 studs); the T3/T4 wall is 01.
# Trims, left to right on the back wall (named on the cap band above each bay):
#   T1 plinth + glowing shadow gap under rock   T2 portal frame corner (Duels: red edge, title band)
#   T3 sign frame with a mode edge strip (1V1)  T4 oak slat panel (1 wide on 1.5) with a warm cove
#   T5 (front row) queue pad: light deck, brushed-steel channel, ring Neon 0.1 below the deck
#
# Run (headless):
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
#       --python tools/blender/build_lobby_styleboard.py -- [--no-render] [--samples N] [--detail --out <jpg>]
# Writes art-source/lobby/StyleBoard.blend and vault/02 Art/References/lobby/kit/style-board.jpg.

import math, os, sys, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
import lobbykit as K  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []

WALL_BACK = 12.0  # back face of the gallery wall (y)
WALL_FACE = 11.0  # its finished face
WALL_H = 16.0
CAP_H = 1.3  # charcoal title band on top of the trim bays
UPPER_H = 30.0  # the wall carries on above the band up to here
BAY = 16.0
BAYS = [-24.0, -8.0, 8.0, 24.0]  # bay centres (x)
FACE_ROOM = -90  # kit pieces face +X; turn them to face the camera (-Y)
TRIM_NAMES = ["T1  PLINTH + SHADOW GAP", "T2  PORTAL FRAME", "T3  SIGN FRAME", "T4  OAK SLATS + COVE"]


def kit_at(x, y_back, z=0.0):
	return K.facing(FACE_ROOM, (x, y_back, z))


def placard(num, name, x, y, cols, mats, w=4.6):
	# A small charcoal wedge on the floor, its face tilted to the camera, with the number and the name.
	d, hb, hf = 1.8, 1.2, 0.12
	bm = K.prism([(y - d / 2, 0), (y + d / 2, 0), (y + d / 2, hb), (y - d / 2, hf)], "X", x - w / 2, x + w / 2)
	K.bevel(bm, 0.05, segs=1, angle=30)
	K.add_obj("Placard_%s" % num, bm, [mats["SignPanel"]], cols["labels"])
	ang = math.degrees(math.atan2(hb - hf, d))
	n = Vector((0, -(hb - hf), d)).normalized()
	up = Vector((0, d, hb - hf)).normalized()
	mid = Vector((x, y, (hb + hf) / 2)) + n * 0.02
	rot = (ang, 0, 0)  # lay the text on the slope
	K.text(num, 0.8, mid + up * 0.42, cols["labels"], mats["SignText"], rot=rot, name="Label_%s_num" % num)
	K.text(name, 0.52, mid - up * 0.45, cols["labels"], mats["SignTextDim"], rot=rot, font=K.FONT_LABEL, name="Label_%s_name" % num)


def room(cols, mats):
	c = cols["room"]
	x0, x1 = BAYS[0] - BAY / 2, BAYS[-1] + BAY / 2
	# Gallery floor: honed dark concrete (saw cuts every 5 studs come from the material, in world studs).
	K.add_obj("Floor", K.box(-80, 80, -70, 45, -1, 0), [mats["ConcreteDark"]], c)
	# Mullions between bays and the charcoal title band along the top, with the trim names.
	for i, x in enumerate([x0] + [b + BAY / 2 for b in BAYS]):
		K.add_obj("Mullion_%d" % i, K.cbox(x - 0.25, x + 0.25, WALL_FACE - 0.6, WALL_BACK, 0, WALL_H, ch=0.1), [mats["SteelBlack"]], c)
	K.add_obj("Cap", K.cbox(x0 - 0.6, x1 + 0.6, WALL_FACE - 0.7, WALL_BACK + 0.5, WALL_H, WALL_H + CAP_H, ch=0.1), [mats["SignPanel"]], c)
	K.add_obj("CapEdge", K.box(x0 - 0.6, x1 + 0.6, WALL_FACE - 0.72, WALL_FACE - 0.6, WALL_H, WALL_H + 0.12), [mats["SteelBlack"]], c)
	# Warm cove on top of the band (the ring beam's cove lip): an upstand hides most of the strip from eye level.
	zt = WALL_H + CAP_H
	K.add_obj("CoveUpstand", K.cbox(x0 - 0.6, x1 + 0.6, WALL_FACE - 0.7, WALL_FACE - 0.5, zt, zt + 0.45, ch=0.04), [mats["SteelBlack"]], c)
	K.add_glow("Cove", K.glow_strip(x0 - 0.3, x1 + 0.3, WALL_FACE - 0.4, WALL_FACE - 0.15, zt, zt + 0.15), mats["Glow_Cove"], c)
	K.rbx_light("SurfaceLight", "CapCove_Wash", (0, WALL_FACE - 1.2, zt + 0.3), 600, K.L_COVE, face="Top", rbx_range=16, angle=120, target=(0, WALL_FACE + 0.6, zt + 6), size=x1 - x0, size_y=0.4, col=c)
	for b, label in zip(BAYS, TRIM_NAMES):
		K.text(label, 0.62, (b, WALL_FACE - 0.72, WALL_H + CAP_H / 2 + 0.04), c, mats["SignText"], rot=(90, 0, 0), name="CapLabel_" + label[:2])
	# Board-formed concrete wall behind T3 and T4, on a plinth set 0.25 in from the wall face.
	wx0 = BAYS[2] - BAY / 2
	K.add_obj("Wall_Board", K.box(wx0, x1, WALL_FACE, WALL_BACK, 1.5, WALL_H), [mats["ConcreteBoard"]], c)
	K.add_obj("Wall_Plinth", K.cbox(wx0, x1, WALL_FACE + 0.25, WALL_BACK, 0, 1.5, ch=0.12), [mats["ConcreteBoard"]], c)
	K.add_obj("Wall_PlinthNosing", K.box(wx0, x1, WALL_FACE + 0.2, WALL_FACE + 0.27, 1.38, 1.5), [mats["SteelBrushed"]], c)
	# The wall carries on above the title band (like the rotunda drum over the colonnade): rock over T1/T2,
	# board-formed concrete over T3/T4.
	z0 = WALL_H + CAP_H
	upper = K.rock_face(wx0 - (x0 - 0.6), UPPER_H - z0, seed=41, cell=2.4, depth=2.4, relief=1.6)
	K.place(upper, kit_at((x0 - 0.6 + wx0) / 2, WALL_BACK + 1.0, z0))
	K.add_obj("Upper_Rock", upper, [mats["Rock"]], c, smooth_angle=0)
	K.add_obj("Upper_Board", K.box(wx0, x1 + 0.6, WALL_FACE, WALL_BACK + 0.5, z0, UPPER_H), [mats["ConcreteBoard"]], c)
	# Return walls at both ends so the gallery reads as a room, not a cut-out.
	for s, x in ((-1, x0 - 0.6), (1, x1 + 0.6)):
		K.add_obj("Return_%d" % s, K.box(min(x, x + 3.2 * s), max(x, x + 3.2 * s), -45, WALL_BACK + 0.5, 0, UPPER_H), [mats["ConcreteBoard"]], c)


def trims(cols, mats):
	c = cols["trims"]
	# T1: rock above a plinth with the glowing shadow gap where the finished work meets the rock.
	x = BAYS[0]
	K.build("T1", K.trim_plinth_gap(BAY - 0.5, wall_t=1.75), mats, c, kit_at(x, WALL_BACK))
	rock = K.rock_face(BAY - 0.5, WALL_H - 2.1, seed=11, cell=2.0, depth=2.3, relief=1.4)
	K.place(rock, kit_at(x, WALL_BACK, 2.1))
	K.add_obj("T1_Rock", rock, [mats["Rock"]], c, smooth_angle=0)

	# T2: corner of a deep portal frame cut into rock, looking into the dark Duels hall.
	x = BAYS[1]
	jamb_x = x - BAY / 2 + 1.75
	back = WALL_FACE + 6.5  # frame back face; its front stands 0.5 proud of the wall line
	open_h = 10.0
	parts = K.trim_portal_corner(height=open_h, span=BAY - 2.0, thick=3.0, deep=6.0, edge_glow="Glow_DuelsRed")
	K.build("T2", parts, mats, c, kit_at(jamb_x, back))
	K.text("DUELS", 1.55, (jamb_x + 1.5 + (BAY - 3.5) / 2, back - 6.17, open_h + 1.5), c, mats["SignText"], rot=(90, 0, 0), name="T2_Title")
	rock = K.rock_face(BAY - 0.5, WALL_H - open_h - 3.0 + 0.6, seed=23, cell=1.6, depth=2.0, relief=0.9, ledges=1)
	K.place(rock, kit_at(x, back - 4.6, open_h + 3.0 - 0.4))
	K.add_obj("T2_RockAbove", rock, [mats["Rock"]], c, smooth_angle=0)
	# The dark hall beyond: Duels rock walls, red floor edge strips and a red light slit far back.
	hall = K.rock_face(BAY + 14, open_h + 4, seed=31, cell=2.4, depth=2.5, relief=1.6)
	K.place(hall, kit_at(x - 2, back + 14))
	K.add_obj("T2_HallRock", hall, [mats["RockDuels"]], c, smooth_angle=0)
	side = K.rock_face(16, open_h + 4, seed=37, cell=2.4, depth=2.5, relief=1.6)
	K.place(side, K.facing(0, (x - BAY / 2 - 3.5, back + 7, 0)))
	K.add_obj("T2_HallSide", side, [mats["RockDuels"]], c, smooth_angle=0)
	# One red jamb strip only (art review: strips on the jamb AND the floor read as Tron); a far slit gives depth.
	K.add_glow("T2_HallSlit", K.glow_strip(x - 5, x + 7, back + 11.0, back + 11.2, 6.5, 6.75), mats["Glow_DuelsRed"], c)
	K.rbx_light("SpotLight", "T2_HallPool", (x + 1, back + 6, 13), 900, K.L_DUELS, zone="duels", rbx_range=20, angle=50, target=(x + 1, back + 6, 0), spot=50, blend=0.8, size=1.0, col=c)
	K.avatar((-6.4, back - 5.0, 0.0), facing=-100.0, col=c, name="Avatar_T2")  # on the portal threshold

	# T3: sign frame (12 x 6) with the mode edge strip, on the board-formed wall.
	x = BAYS[2]
	sw, sh, sz = 12.0, 6.0, 5.6
	K.build("T3", K.trim_sign_frame(sw, sh, mode_glow="Glow_1v1"), mats, c, kit_at(x, WALL_FACE, sz))
	K.text("1V1", 2.6, (x, WALL_FACE - 0.47, sz + 3.65), c, mats["Glow_1v1"], rot=(90, 0, 0), name="T3_Mode")
	K.text("0 / 2 QUEUED", 0.8, (x, WALL_FACE - 0.47, sz + 1.55), c, mats["SignText"], rot=(90, 0, 0), name="T3_Count")

	# T4: oak slat panel (1 wide on a 1.5 pitch) under a black-steel cove hood with a warm glow.
	x = BAYS[3]
	pw = BAY - 2.5
	sl, bk = K.slat_panel(pw, 10.0, z0=2.6)
	K.place(sl, kit_at(x, WALL_FACE))
	K.place(bk, kit_at(x, WALL_FACE))
	K.add_obj("T4_Slats", sl, [mats["Oak"]], c, uv_rotate=True)
	K.add_obj("T4_Backing", bk, [mats["SteelBlack"]], c)
	hood = K.cbox(0, 1.2, -(pw + 0.6) / 2, (pw + 0.6) / 2, 12.6, 13.2, ch=0.08)
	K.place(hood, kit_at(x, WALL_FACE))
	K.add_obj("T4_Hood", hood, [mats["SteelBlack"]], c)
	fascia = K.cbox(1.05, 1.2, -(pw + 0.6) / 2, (pw + 0.6) / 2, 12.15, 12.65, ch=0.04)  # hides the cove strip
	K.place(fascia, kit_at(x, WALL_FACE))
	K.add_obj("T4_Fascia", fascia, [mats["SteelBlack"]], c)
	cove = K.glow_strip(0.7, 1.0, -pw / 2, pw / 2, 12.45, 12.6)
	K.place(cove, kit_at(x, WALL_FACE))
	K.add_glow("T4_Cove", cove, mats["Glow_Cove"], c)
	low = K.glow_strip(0.25, 0.4, -pw / 2, pw / 2, 2.35, 2.55)
	K.place(low, kit_at(x, WALL_FACE))
	K.add_glow("T4_Under", low, mats["Glow_Cove"], c)
	# The wash on the slats is a real light (Neon lights nothing): a SurfaceLight on the hidden cove strip.
	K.rbx_light("SurfaceLight", "T4_CoveWash", (x, WALL_FACE - 0.85, 12.4), 900, K.L_COVE, face="Bottom", rbx_range=12, angle=90, target=(x, WALL_FACE + 0.3, 4.0), size=pw, size_y=0.3, col=c)
	K.avatar((30.6, WALL_FACE - 1.4, 0.0), facing=-110.0, col=c, name="Avatar_T4")


def samples(cols, mats):
	c = cols["samples"]
	y0, y1 = 0.0, 2.2  # back row footprint (y)
	yc = (y0 + y1) / 2
	gap = 2.0
	x = -32.0  # a multiple of 3.2, so the board slab shows whole formwork panels
	items = []

	def slot(width):
		nonlocal x
		x0 = x
		x += width + gap
		return x0, x0 + width

	# 01 board-formed concrete: two 3.2 x 6.4 panels.
	a, b = slot(6.4)
	K.add_obj("S01_ConcreteBoard", K.box(a, b, y0 + 0.4, y1 - 0.4, 0, 6.4), [mats["ConcreteBoard"]], c)
	items.append(("01", "BOARD CONCRETE", (a + b) / 2))
	# 06 / 07 granite and Duels rock: rock_face slabs (two facet scales, benches) on a steel shoe, as used.
	for num, name, mname, seed in (("06", "GRANITE ROCK", "Rock", 5), ("07", "DUELS ROCK", "RockDuels", 9)):
		a, b = slot(4.4)
		slab = K.rock_face(4.4, 5.2, seed, cell=0.9, depth=1.1, relief=0.9, ledges=2, chips=0.25, row=1.1)
		K.place(slab, kit_at((a + b) / 2, y1 - 0.2, 0.35))
		K.add_obj("S%s_%s" % (num, mname), slab, [mats[mname]], c, smooth_angle=0)
		K.add_obj("S%s_Back" % num, K.box(a, b, y1 - 0.4, y1 - 0.2, 0.35, 5.55), [mats["SteelBlack"]], c)
		K.add_obj("S%s_Shoe" % num, K.cbox(a - 0.1, b + 0.1, yc - 1.0, y1, 0, 0.35, ch=0.06), [mats["SteelBlack"]], c)
		items.append((num, name, (a + b) / 2))
	# 08 black steel: a block with 0.1 bevels.
	a, b = slot(3.4)
	K.add_obj("S08_SteelBlack", K.cbox(a, b, yc - 1.7, yc + 1.7, 0, 3.4, ch=0.1), [mats["SteelBlack"]], c)
	items.append(("08", "BLACK STEEL", (a + b) / 2))
	# 09 brushed steel: a rail-like cylinder.
	a, b = slot(3.2)
	K.add_obj("S09_SteelBrushed", K.cyl((a + b) / 2, yc, 1.6, 0, 4.6, segs=40, ch=0.08), [mats["SteelBrushed"]], c)
	items.append(("09", "BRUSHED STEEL", (a + b) / 2))
	# 10 warm oak: three stacked boards (grain along X).
	a, b = slot(5.0)
	oak = bmesh.new()
	for i in range(3):
		K.merge(oak, K.cbox(a, b, yc - 1.3, yc + 1.3, i * 1.0, i * 1.0 + 0.96, ch=0.06))
	K.add_obj("S10_Oak", oak, [mats["Oak"]], c)
	items.append(("10", "WARM OAK", (a + b) / 2))
	# 11 brass: the locker pedestal drum.
	a, b = slot(3.4)
	K.add_obj("S11_Brass", K.cyl((a + b) / 2, yc, 1.7, 0, 2.6, segs=48, ch=0.1), [mats["Brass"]], c)
	items.append(("11", "BRASS", (a + b) / 2))
	# 12 glass: one pane in a black-steel shoe.
	a, b = slot(4.4)
	K.add_obj("S12_Shoe", K.cbox(a, b, yc - 0.45, yc + 0.45, 0, 0.5, ch=0.08), [mats["SteelBlack"]], c)
	K.add_obj("S12_Glass", K.box(a + 0.15, b - 0.15, yc - 0.08, yc + 0.08, 0.45, 5.6), [mats["Glass"]], c)
	items.append(("12", "GLASS", (a + b) / 2))
	# 13 Neon: nine thin bars in a black-steel rack.
	names = ["COVE", "COOL", "RED", "1V1", "2V2", "3V3", "4V4", "GNTLT", "DORM"]
	glows = ["Glow_Cove", "Glow_Cool", "Glow_DuelsRed", "Glow_1v1", "Glow_2v2", "Glow_3v3", "Glow_4v4", "Glow_Gauntlet", "Glow_Dormant"]
	pitch = 1.3
	w = pitch * len(glows) + 0.6
	a, b = slot(w)
	K.add_obj("S13_Rack", K.cbox(a, b, yc - 0.2, yc + 0.6, 0, 5.0, ch=0.1), [mats["SteelBlack"]], c)
	K.add_obj("S13_Foot", K.cbox(a, b, yc - 1.0, yc + 0.6, 0, 0.35, ch=0.08), [mats["SteelBlack"]], c)
	for i, (gname, label) in enumerate(zip(glows, names)):
		gx = a + 0.3 + pitch * (i + 0.5)
		K.add_glow("S13_Bar%d_%s" % (i, gname[5:]), K.glow_strip(gx - 0.15, gx + 0.15, yc - 0.32, yc - 0.18, 1.2, 4.6), mats[gname], c)
		K.text(label, 0.36, (gx, yc - 0.23, 0.78), c, mats["SignTextDim"], rot=(90, 0, 0), font=K.FONT_LABEL, name="S13_Label_%d" % i)
	items.append(("13", "NEON", (a + b) / 2))
	for num, name, cx in items:
		placard(num, name, cx, -2.0, cols, mats)

	# Front row: floor finishes as raised tiles, then the T5 queue pad.
	tiles = [("02", "HOT-SPOT INLAY", "ConcretePolishedInlay"), ("03", "POLISHED", "ConcretePolished"), ("04", "HONED DARK", "ConcreteDark"), ("05", "TERRAZZO", "Terrazzo")]
	tw, tg, pw, pd = 6.0, 3.0, 10.0, 8.0
	total = len(tiles) * tw + len(tiles) * tg + pw
	tx0 = -total / 2
	centres = {}
	for i, (num, name, mname) in enumerate(tiles):
		a = tx0 + i * (tw + tg)
		K.add_obj("S%s_%s" % (num, mname), K.cbox(a, a + tw, -12.0, -6.0, 0, 0.6, ch=0.15), [mats[mname]], c)
		placard(num, name, a + tw / 2, -14.0, cols, mats)
		centres[num] = (a + tw / 2, -9.0, 0.6)
	px = tx0 + len(tiles) * (tw + tg) + pw / 2
	K.build("T5", K.trim_pad(pw, pd, mode_glow="Glow_2v2"), mats, cols["trims"], Matrix.Translation((px, -9.0, 0)))
	placard("T5", "PAD RING", px, -14.0, cols, mats)
	return centres


def main():
	t0 = time.time()
	mats = K.begin()
	top = K.collection("StyleBoard")
	cols = {k: K.collection(n, top) for k, n in (("room", "Room"), ("trims", "Trims"), ("samples", "Samples"), ("labels", "Labels"))}
	room(cols, mats)
	trims(cols, mats)
	centres = samples(cols, mats)

	# Gallery light: the rotunda world preset without the sun. The sun patch and the fake Beam ribbons are judged in
	# the structure render (art review: the beam on tile 02 hid the floor-finish values), so every sample here sits
	# under the same neutral light.
	stage = K.collection("Stage")
	world = K.lobby_world("rotunda", center=(0, 0, 0), radius=34.0, sun=0.0)
	world["fill"].data.energy *= 0.3  # the gallery spot and the cove do the work here; keep the upper wall dim
	world["key"].data.energy *= 0.5
	# One neutral key over the floor-finish row, so 02 / 03 / 04 / 05 separate by their own values.
	K.light("AREA", "FloorKey", (2.0, -16.0, 24.0), 9000, 0xF2F0EA, target=(2.0, -9.0, 0.0), size=44, size_y=10, shadow=False, col=stage)

	samples_n = int(ARGS[ARGS.index("--samples") + 1]) if "--samples" in ARGS else 96
	K.render_settings(samples=samples_n)
	K.bloom()  # the kit render policy: threshold 1.2, exposure 0
	# Gallery wash: one high soft spot over the sample rows (the zone's single dynamic light, used generously so
	# the materials read), plus a low cool rim from behind the camera for metal highlights.
	K.light("SPOT", "GalleryWash", (0, -20, 46), 120000, K.L_COVE, target=(0, -2, 0), spot=72, blend=0.6, size=5.0, shadow=True, col=stage)
	K.light("AREA", "MetalRim", (18, -40, 9), 2500, K.L_RANGE, target=(0, 0, 3), size=20, size_y=6, shadow=False, col=stage)
	K.camera((0.0, -46.0, 27.0), (0.0, 11.0, 0.8), lens=28.0)
	if "--detail" in ARGS:  # close-up checks (not the published render): --detail <x> <z> looks at the wall at x
		i = ARGS.index("--detail")
		dx, dz = float(ARGS[i + 1]), float(ARGS[i + 2])
		K.camera((dx + 4.0, -12.0, dz + 4.0), (dx, WALL_FACE, dz), lens=35.0, name="CamDetail")

	K.light_budget()
	blend = K.save("StyleBoard")
	print("STYLEBOARD saved", blend, "%.1fs" % (time.time() - t0))
	if "--no-render" not in ARGS:
		path = ARGS[ARGS.index("--out") + 1] if "--out" in ARGS else os.path.join(K.RENDER_DIR, "style-board.jpg")
		out = K.render(path)
		print("STYLEBOARD render", out, "%.1fs" % (time.time() - t0))


main()
