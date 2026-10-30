# build_lobby_kit_weapons.py: the Lobby kit group "Weapons" (vault/02 Art/Lobby Kit.md, "Weapons + Locker"; step 4).
#
# Every piece is a Lobby_<Piece> collection built at the world origin with the Lobby Kit origin conventions:
#   straight pieces: origin on the floor at the centre of the back face, front facing +X, width along Y
#   round pieces:    origin at the circle centre on the floor; the segment spans the bearings given below,
#                    clockwise from north (Blender +Y), bearing b pointing to (sin b, cos b)
#   props:           origin on the floor at the centre, front +X
# 1 unit = 1 stud. Objects are <Piece>_<Part>; Neon parts are separate *_Glow objects. Text is never kit geometry
# (signs become SurfaceGuis in Studio).
#
# The pieces are sized to the greybox (tools/studio/lobby/Wing_Weapons.luau), which stays the collision:
#   ArmouryPier_R42   round, centred on bearing 0: board-formed pier (r 40..42.5, 30 tall), steel shoe, rib to R16
#   ArmouryDrum_R42   round, bearings 0..11.25: drum head r 42..44, y 18..30, with an uplight cornice (ceiling wash)
#   LanternRing_R16   round, full ring: the lantern drum r 14..16, y 30..37, steel rims and a cove glow
#   GunChapel         round, bearings 0..33.75: deep bay to the R56 chord (stage, smoked walls, roof, light slot)
#   GunChapel_R50     round, bearings 0..33.75: the shallow pistol bay (back on three R50 facets)
#   TrophyWall / TrophyWall_10   straight: framed panel for real-size guns, 20 / 10 wide
#   TrophyTab         straight: name tab under a trophy gun (2.4 wide, brushed top lip)
#   GunTurntable / GunTurntable_7   props: display turntables, deck 2.9 above the stage (greybox top y 3.4)
#   DisplayRod        prop: brushed rod, 1 tall (scaled in Studio to reach each gun), with a black saddle
#   GunPlaque         prop: sloped name plaque 6 wide (front +X)
#   HeroDais          round, full: the two-step dais (R13 / R10), floor light ring
#   HeroPylon         prop: black steel pylon 1.2 x 1.2, 1 tall (scaled in Studio to the hero gun)
#   HeroLectern       straight: steel lectern 9 wide with a sign face
#   SteelFrame_14 / SteelFrame_135   straight: the corridor squeeze frames (26.54 wide, beam soffit 14 / 13.5)
#   LockerApse_R16    round, bearings 0..11.25: oak slat apse wall (R16) on a honed plinth, cove at the top
#   LockerCheek       straight: oak slat wall 8 wide for the apse cheeks
#   LockerBacklight   straight: back-lit panel (9 x 13 light field in a steel frame)
#   LockerPedestal    prop: brass pedestal Ø8, glow toe
#   Mannequin         prop: matte block avatar (5 tall) for the locker pedestal, front +X
#   LoadoutTerminal   prop: console 3 wide with an angled screen, front +X
#   SignFrame_20x2 / _16x3 / _16x6 / _5x1   straight: sign frames (bezel, charcoal panel, neutral strip)
#   FloorRing_R20     round, full: brushed inlay ring on the armoury floor (r 19.8..20.2)
#
# Run (headless):
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
#       --python tools/blender/build_lobby_kit_weapons.py -- [--no-render] [--samples N]
#   ... -- --gun-profiles Vandal Phantom ...   writes art-source/lobby/Exports/GunProfiles.json (underside of each
#       gun along its length, from art-source/weapons/Exports/<Id>.fbx) for the display stands; nothing else.
# Writes art-source/lobby/Kit_Weapons.blend and vault/02 Art/References/lobby/kit/contact-weapons.jpg.

import json, math, os, sys, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
import lobbykit as K  # noqa: E402
import gunkit  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SEG = K.SEG


# ---------------------------------------------------------------- helpers

def frame(origin, x_axis, z_axis):
	x = Vector(x_axis).normalized()
	z = Vector(z_axis).normalized()
	y = z.cross(x).normalized()
	z = x.cross(y).normalized()
	m = Matrix.Identity(4)
	for i in range(3):
		m[i][0], m[i][1], m[i][2], m[i][3] = x[i], y[i], z[i], Vector(origin)[i]
	return m


def bay_frame(b):
	# Local X = tangent (clockwise: the viewer's right looking out from the centre), local Y = radial out, Z up.
	return frame((0, 0, 0), K.bearing_dir(b + 90), (0, 0, 1))


def hide(bm, down=True, up=False):
	if down:
		gunkit.drop(bm, 2, -1)
	if up:
		gunkit.drop(bm, 2, 1)
	return bm


def lbox(m, x0, x1, y0, y1, z0, z1, ch=0.0, mat=0):
	bm = K.cbox(x0, x1, y0, y1, z0, z1, ch=ch, mat=mat) if ch > 0 else K.mat_all(K.box(x0, x1, y0, y1, z0, z1), mat)
	return K.place(bm, m)


def poly_prism(pts, z0, z1, mat=0):
	return K.mat_all(K.prism(pts, "Z", z0, z1), mat)


def arc_pts(r, b0, b1, steps):
	return [tuple(K.polar(r, b0 + (b1 - b0) * i / steps).to_2d()) for i in range(steps + 1)]


def p2(r, b):
	return tuple(K.polar(r, b).to_2d())


def piece(kit, name):
	return K.collection("Lobby_" + name, kit)


def tri_count(col):
	n = 0
	for ob in col.all_objects:
		if ob.type == "MESH" and not ob.get("preview_only"):
			n += sum(len(p.vertices) - 2 for p in ob.data.polygons)
	return n


def materials():
	mats = K.make_materials()
	mats["ConcreteBoardSmoked"] = K._concrete_board("ConcreteBoardSmoked", 0x5A5955)  # Weapons chapels
	mats["TrophyPanel"] = K._concrete_polished("TrophyPanel", 0x6F6C67)  # mid-dark, so the guns read against it
	mats["LightPanel"] = K._flat("LightPanel", 0xEEECE6, 0.35)  # back-lit field (SmoothPlastic, near white)
	mats["MannequinMatte"] = K._flat("MannequinMatte", 0xD9D7D2, 0.7)
	# Fix pass: the locker form is a light satin figure (it was a black block against a white light box).
	mats["MannequinSatin"] = K._flat("MannequinSatin", 0xB9B4AA, 0.45)
	mats["LightPanel"] = K._flat("LightPanel", 0xCFCAC2, 0.35)  # toned down so the figure's edges read against it
	return mats


# ---------------------------------------------------------------- armoury structure

R_PIER = (40.0, 42.5)
WALL_TOP = 30.0


def piece_pier(kit, mats):
	col = piece(kit, "ArmouryPier_R42")
	bf = bay_frame(0.0)
	parts = {
		"Pier": (hide(lbox(bf, -1.5, 1.5, R_PIER[0], R_PIER[1], 0, WALL_TOP, ch=0.25), up=True), "ConcreteBoard"),
		"Shoe": (hide(lbox(bf, -1.62, 1.62, R_PIER[0] - 0.12, R_PIER[1], 0, 1.2, ch=0.06)), "SteelBlack"),
		# Rib: from the pier head to the lantern ring, its soffit stepping up toward the centre.
		"Rib": (hide(K.place(K.prism([(16.2, 30.0), (40.0, 30.0), (40.0, 27.0), (30.0, 27.6), (16.2, 28.6)], "X", -0.75, 0.75), bf), down=False, up=True), "ConcreteBoard"),
	}
	K.bevel(parts["Rib"][0], 0.15, segs=1, angle=30)
	K.build("ArmouryPier_R42", parts, mats, col)
	return col


def piece_drum(kit, mats):
	# 11.25 degree drum head over the chapels: board-formed face r 42..44 from y 18 to 30, a black steel soffit band
	# at its foot and an uplight cornice at the top that washes the ceiling.
	col = piece(kit, "ArmouryDrum_R42")
	parts = {
		"Head": (hide(K.arc(42.0, 44.0, 0, SEG, 18.6, WALL_TOP, steps=2), up=True), "ConcreteBoard"),
		"Soffit": (K.arc(41.9, 44.0, 0, SEG, 18.0, 18.6, steps=2), "SteelBlack"),
	}
	parts["Shelf"] = (K.arc(41.0, 42.0, 0, SEG, 28.4, 28.7, steps=2), "SteelBlack")
	parts["Lip"] = (hide(K.arc(41.0, 41.15, 0, SEG, 28.7, 29.25, steps=2)), "SteelBlack")
	parts["Cornice_Glow"] = (hide(K.arc(41.2, 41.5, 0, SEG, 28.7, 28.85, steps=2)), "Glow_Neutral")
	K.build("ArmouryDrum_R42", parts, mats, col)
	return col


def piece_lantern(kit, mats):
	# The glazed lantern: a smooth concrete drum r 14..16 (y 30..37), a black steel bottom ring with a cove that
	# washes the drum, and a knife-edge steel rim under the glass.
	col = piece(kit, "LanternRing_R16")
	parts = {
		"Drum": (K.lathe([(14.0, 30.6), (14.0, 36.6)], steps=48), "ConcretePolished"),
		"BaseRing": (K.lathe([(16.2, 29.94), (13.4, 29.94), (13.4, 30.6), (14.0, 30.6)], steps=48), "SteelBlack"),  # just under the roof soffit (y 30): no z-fighting
		"Lip": (K.lathe([(13.4, 30.6), (13.4, 31.05), (13.55, 31.05), (13.55, 30.6)], steps=48), "SteelBlack"),
		"Cove_Glow": (K.arc(13.6, 13.85, 0, 360, 30.6, 30.75, steps=48), "Glow_Neutral"),
		"Rim": (K.lathe([(14.0, 36.6), (13.7, 36.6), (13.7, 37.0), (16.5, 37.0)], steps=48), "SteelBlack"),
	}
	K.build("LanternRing_R16", parts, mats, col)
	return col


def piece_floor_ring(kit, mats):
	col = piece(kit, "FloorRing_R20")
	parts = {"Ring": (hide(K.arc(19.8, 20.2, 0, 360, 0.0, 0.065, steps=64)), "SteelBrushed")}
	K.build("FloorRing_R20", parts, mats, col)
	return col


# ---------------------------------------------------------------- chapels

CH_SPAN = 33.75
CH_TOP = 18.0
SLOT_R = (44.3, 45.7)


def chapel_common(parts, b0, b1, back_pts, wall_out):
	# Roof with a light slot in front of the gun: soffit r 42..44.3, the slot, then the back roof to the wall.
	roof = K.arc(42.0, SLOT_R[0], b0, b1, CH_TOP, CH_TOP + 1.0, steps=6)
	back = arc_pts(SLOT_R[1], b0, b1, 6)[::-1] + back_pts
	K.merge(roof, poly_prism(back, CH_TOP, CH_TOP + 1.0))
	K.merge(roof, K.arc(SLOT_R[0] - 0.2, SLOT_R[1] + 0.2, b0, b1, CH_TOP + 1.0, CH_TOP + 1.6, steps=6))
	parts["Roof"] = (hide(roof, down=False, up=True), "ConcreteBoardSmoked")
	parts["Pelmet"] = (hide(K.arc(SLOT_R[0] - 0.15, SLOT_R[0], b0 + 0.6, b1 - 0.6, CH_TOP - 0.5, CH_TOP + 0.02, steps=6), down=False, up=True), "SteelBlack")
	parts["Slot_Glow"] = (hide(K.arc(SLOT_R[0], SLOT_R[0] + 0.12, b0 + 1.0, b1 - 1.0, CH_TOP + 0.7, CH_TOP + 0.85, steps=6), up=True), "Glow_Neutral")
	# Half side walls (the neighbour's half makes the 2-thick fin over the greybox Fin).
	walls = bmesh.new()
	for b, x0, x1 in ((b0, 0.0, 1.0), (b1, -1.0, 0.0)):
		K.merge(walls, lbox(bay_frame(b), x0, x1, 42.5, wall_out, 0, CH_TOP, ch=0.2))
	return walls


def piece_gun_chapel(kit, mats):
	# Deep chapel (bearings 0..33.75): stage front on the greybox chord (r 44 at the bay edges), back wall face on the
	# R56 chord (53.59 on the centre line), roof soffit at 18 with one hidden light slot over the turntable.
	col = piece(kit, "GunChapel")
	b0, b1 = 0.0, CH_SPAN
	bf = bay_frame(b0 + CH_SPAN / 2)
	face = 56.0 * math.cos(math.radians(CH_SPAN / 2))
	half = face * math.tan(math.radians(CH_SPAN / 2))
	front = 44.0 * math.cos(math.radians(CH_SPAN / 2))
	fhalf = 44.0 * math.sin(math.radians(CH_SPAN / 2))
	stage = [p2(44.0, b0), p2(44.0, b1), p2(56.0, b1), p2(56.0, b0)]
	parts = {"Stage": (hide(poly_prism(stage, 0, 0.5)), "ConcretePolished")}
	parts["Nosing"] = (hide(lbox(bf, -fhalf + 1.2, fhalf - 1.2, front - 0.02, front + 0.14, 0.0, 0.5)), "SteelBrushed")
	parts["Toe_Glow"] = (hide(lbox(bf, -half + 1.2, half - 1.2, face - 0.32, face - 0.2, 0.5, 0.62), up=False), "Glow_Neutral")
	walls = chapel_common(parts, b0, b1, [p2(56.0, b0), p2(56.0, b1)], 56.6)
	K.merge(walls, lbox(bf, -half - 0.6, half + 0.6, face, face + 1.5, 0, CH_TOP + 1.6, ch=0.2))
	parts["Walls"] = (hide(walls, up=True), "ConcreteBoardSmoked")
	K.build("GunChapel", parts, mats, col)
	return col


def piece_gun_chapel_r50(kit, mats):
	# Shallow pistol chapel (bearings 0..33.75): the stage front and back wall follow the greybox's 11.25 degree
	# facets (front corners on R44, back wall faces on R50).
	col = piece(kit, "GunChapel_R50")
	b0, b1 = 0.0, CH_SPAN
	front = [p2(44.0, b0 + SEG * k) for k in range(4)]
	back = [p2(50.0, b0 + SEG * k) for k in range(4)][::-1]
	parts = {"Stage": (hide(poly_prism(front + back, 0, 0.5)), "ConcretePolished")}
	nose = bmesh.new()
	toe = bmesh.new()
	walls = chapel_common(parts, b0, b1, [p2(50.0, b0 + SEG * k) for k in range(4)], 50.6)
	for k in range(3):
		bm_c = b0 + SEG * (k + 0.5)
		f = bay_frame(bm_c)
		fr = 44.0 * math.cos(math.radians(SEG / 2))
		fh = 44.0 * math.sin(math.radians(SEG / 2))
		K.merge(nose, lbox(f, -fh + (1.2 if k == 0 else 0.0), fh - (1.2 if k == 2 else 0.0), fr - 0.02, fr + 0.14, 0.0, 0.5))
		bk = 50.0 * math.cos(math.radians(SEG / 2))
		bh = 50.0 * math.sin(math.radians(SEG / 2))
		K.merge(walls, lbox(f, -bh - 0.3, bh + 0.3, bk, bk + 1.5, 0, CH_TOP + 1.6, ch=0.2))
		K.merge(toe, lbox(f, -bh + (1.2 if k == 0 else 0.15), bh - (1.2 if k == 2 else 0.15), bk - 0.32, bk - 0.2, 0.5, 0.62))
	parts["Nosing"] = (hide(nose), "SteelBrushed")
	parts["Toe_Glow"] = (toe, "Glow_Neutral")
	parts["Walls"] = (hide(walls, up=True), "ConcreteBoardSmoked")
	K.build("GunChapel_R50", parts, mats, col)
	return col


def trophy_wall(kit, mats, name, hw, z0=8.6, z1=16.4):
	# Framed panel for two rows of real-size guns (straight: back on the wall, facing +X; y 8.6..16.4 above the
	# stage floor plane): a mid-grey polished panel set 0.25
	# back inside a black steel frame 0.52 deep, with a downlight glow tucked behind the top frame.
	col = piece(kit, name)
	fb, rv = 0.3, 0.25
	parts = {"Tray": (hide(K.box(0, 0.12, -hw, hw, z0, z1), up=True), "SteelBlack")}
	parts["Panel"] = (hide(K.cbox(0.12, 0.4, -hw + rv, hw - rv, z0 + rv, z1 - rv, ch=0.04), up=True), "TrophyPanel")
	frm = bmesh.new()
	for y0, y1, za, zb in ((-hw - fb, hw + fb, z1, z1 + fb), (-hw - fb, hw + fb, z0 - fb, z0), (-hw - fb, -hw, z0, z1), (hw, hw + fb, z0, z1)):
		K.merge(frm, K.cbox(0, 0.52, y0, y1, za, zb, ch=0.04))
	K.merge(frm, K.cbox(0.4, 0.75, -hw, hw, z1 - 0.14, z1, ch=0.02))  # pelmet under the top frame
	parts["Frame"] = (frm, "SteelBlack")
	parts["Down_Glow"] = (K.box(0.42, 0.6, -hw + 0.3, hw - 0.3, z1 - 0.2, z1 - 0.14), "Glow_Neutral")
	K.build(name, parts, mats, col)
	return col


def piece_trophy_tab(kit, mats):
	col = piece(kit, "TrophyTab")
	# The name tab under a trophy gun (its name is a SurfaceGui); a brushed lip along its top edge.
	parts = {
		"Tab": (K.cbox(0.0, 0.12, -1.2, 1.2, 0.0, 0.4, ch=0.02), "SignPanel"),
		"Lip": (K.box(0.0, 0.16, -1.2, 1.2, 0.4, 0.45), "SteelBrushed"),
	}
	K.build("TrophyTab", parts, mats, col)
	return col


TT_TOP = 2.9  # deck top above the stage (greybox turntable top y 3.4 on the 0.5 stage)


def turntable(kit, mats, name, r):
	# Display turntable (prop): black steel drum on a recessed toe with the white under-glow, a brushed rim and a
	# light polished deck. r = outer radius (greybox plinth radius).
	col = piece(kit, name)
	k = r / 5.0
	segs = 40
	parts = {
		"Toe": (hide(K.cyl(0, 0, r - 0.7 * k, 0, 0.3, segs=segs), up=True), "SteelBlack"),
		"Drum": (hide(K.cyl(0, 0, r - 0.35 * k, 0.3, TT_TOP - 0.35, segs=segs, ch=0.08), up=True), "SteelBlack"),
		"Band": (hide(K.arc(r - 0.34 * k, r - 0.3 * k, 0, 360, 1.2, 1.32, steps=segs), up=True), "SteelBrushed"),
		"Rim": (hide(K.arc(r - 0.45 * k, r, 0, 360, TT_TOP - 0.4, TT_TOP, steps=segs)), "SteelBrushed"),
		"Deck": (hide(K.cyl(0, 0, r - 0.45 * k, TT_TOP - 0.3, TT_TOP, segs=segs, ch=0.05)), "ConcretePolished"),
		"Under_Glow": (hide(K.arc(r - 0.68 * k, r - 0.5 * k, 0, 360, 0.02, 0.2, steps=segs), up=True), "Glow_Neutral"),
	}
	K.build(name, parts, mats, col)
	return col


def piece_display_rod(kit, mats):
	# 1 stud tall: Studio scales the MeshPart's height to reach each gun. The saddle is its own piece.
	col = piece(kit, "DisplayRod")
	parts = {"Rod": (K.cyl(0, 0, 0.13, 0.0, 1.0, segs=10), "SteelBrushed")}
	K.build("DisplayRod", parts, mats, col)
	col2 = piece(kit, "DisplaySaddle")
	parts2 = {
		"Saddle": (K.cbox(-0.35, 0.35, -0.28, 0.28, 0.0, 0.16, ch=0.03), "SteelBlack"),
		"Foot": (hide(K.cyl(0, 0, 0.32, -0.06, 0.02, segs=12)), "SteelBrushed"),
	}
	K.build("DisplaySaddle", parts2, mats, col2)
	return col, col2


def piece_plaque(kit, mats):
	# Sloped name plaque (prop, front +X): low front edge 0.3, high back 0.9, 6 wide, on a brushed foot.
	col = piece(kit, "GunPlaque")
	pl = K.prism([(-0.6, 0.12), (0.6, 0.12), (0.6, 0.42), (-0.6, 1.02)], "Y", -3.0, 3.0)
	K.bevel(pl, 0.04, segs=1, angle=30)
	parts = {
		"Body": (pl, "SignPanel"),
		"Foot": (hide(K.cbox(-0.5, 0.5, -2.8, 2.8, 0.0, 0.12, ch=0.03)), "SteelBrushed"),
	}
	K.build("GunPlaque", parts, mats, col)
	return col


# ---------------------------------------------------------------- hero island

def piece_hero_dais(kit, mats):
	col = piece(kit, "HeroDais")
	s = 64
	parts = {
		"Lower": (hide(K.cyl(0, 0, 12.85, 0.0, 0.62, segs=s)), "ConcreteHoned"),
		"LowerTop": (hide(K.arc(10.0, 12.85, 0, 360, 0.62, 0.8, steps=s)), "ConcretePolished"),
		"LowerNosing": (hide(K.arc(12.85, 13.0, 0, 360, 0.0, 0.8, steps=s)), "SteelBrushed"),
		"Upper": (hide(K.cyl(0, 0, 9.85, 0.8, 1.42, segs=s)), "ConcreteHoned"),
		"UpperTop": (hide(K.cyl(0, 0, 9.85, 1.42, 1.6, segs=s)), "ConcretePolished"),
		"UpperNosing": (hide(K.arc(9.85, 10.0, 0, 360, 0.8, 1.6, steps=s)), "SteelBrushed"),
		# Shadow gap under the upper step's nosing, glowing.
		"Gap_Glow": (hide(K.arc(10.0, 10.08, 0, 360, 0.82, 0.9, steps=s)), "Glow_Neutral"),
		"Channel": (hide(K.arc(13.0, 13.55, 0, 360, 0.0, 0.25, steps=s)), "SteelBlack"),
		"Ring_Glow": (hide(K.arc(13.12, 13.38, 0, 360, 0.0, 0.2, steps=s)), "Glow_Neutral"),
	}
	K.build("HeroDais", parts, mats, col)
	return col


def piece_hero_pylon(kit, mats):
	# Museum mount for the hero rifle (fix pass): a slim round brushed-steel column (1 tall master, scaled in Studio;
	# r 0.45 stays within 0.5 of the 1.2 square greybox pylon), a black plinth with a brushed collar at its foot, a
	# brushed collar under the cradle, and a brushed V-cradle with a black pad.
	col = piece(kit, "HeroPylon")
	parts = {"Column": (hide(K.cyl(0, 0, 0.45, 0.0, 1.0, segs=20), up=True), "SteelBrushed")}
	K.build("HeroPylon", parts, mats, col)
	colb = piece(kit, "HeroPylonBase")
	partsb = {
		"Plinth": (hide(K.cbox(-0.85, 0.85, -0.85, 0.85, 0.0, 0.35, ch=0.06)), "SteelBlack"),
		"Collar": (hide(K.cyl(0, 0, 0.62, 0.35, 0.6, segs=20, ch=0.04)), "SteelBrushed"),
	}
	K.build("HeroPylonBase", partsb, mats, colb)
	colc = piece(kit, "HeroPylonCollar")
	partsc = {
		"Collar": (K.cyl(0, 0, 0.6, -0.45, 0.0, segs=20, ch=0.04), "SteelBrushed"),
		"Ring": (hide(K.cyl(0, 0, 0.64, -0.3, -0.18, segs=20), up=True), "SteelBlack"),
	}
	K.build("HeroPylonCollar", partsc, mats, colc)
	col2 = piece(kit, "HeroCradle")
	cr = K.prism([(-0.9, 0.0), (0.9, 0.0), (0.9, 0.5), (0.5, 0.5), (0.0, 0.2), (-0.5, 0.5), (-0.9, 0.5)], "X", -0.75, 0.75)
	K.bevel(cr, 0.04, segs=1, angle=30)
	pad = K.prism([(-0.48, 0.5), (0.0, 0.21), (0.48, 0.5), (0.44, 0.53), (0.0, 0.26), (-0.44, 0.53)], "X", -0.7, 0.7)
	K.build("HeroCradle", {"Cradle": (cr, "SteelBrushed"), "Pad": (pad, "SteelBlack")}, mats, col2)
	return col, col2, colb, colc


def piece_hero_lectern(kit, mats):
	# Straight piece (back at x 0, front +X): 1.6 deep, 9 wide, 2 tall, with a charcoal sign face on the front
	# (the HeroLabel's SurfaceGui goes on it) and a glowing kick at its foot.
	col = piece(kit, "HeroLectern")
	parts = {
		"Body": (hide(K.cbox(0.0, 1.6, -4.5, 4.5, 0.12, 2.0, ch=0.06)), "SteelBlack"),
		"Kick": (hide(K.box(0.15, 1.45, -4.35, 4.35, 0.0, 0.12)), "SteelBlack"),
		"Face": (K.box(1.6, 1.66, -4.2, 4.2, 0.35, 1.75), "SignPanel"),
		"Kick_Glow": (K.box(1.38, 1.46, -4.3, 4.3, 0.02, 0.1), "Glow_Neutral"),
	}
	K.build("HeroLectern", parts, mats, col)
	return col


# ---------------------------------------------------------------- corridor

def steel_frame(kit, mats, name, soffit):
	# Straight (back at x 0, front +X): two 2-deep posts on y +-(11.27..13.27) and a beam from `soffit` to 16, black
	# steel with 0.1 bevels, a neutral light line down each post's inner face and along the beam soffit.
	col = piece(kit, name)
	fr = bmesh.new()
	for s in (-1, 1):
		K.merge(fr, K.cbox(0.0, 2.0, min(s * 11.27, s * 13.27), max(s * 11.27, s * 13.27), 0.0, 16.0, ch=0.1))
	K.merge(fr, K.cbox(0.0, 2.0, -11.3, 11.3, soffit, 16.0, ch=0.1))
	gl = bmesh.new()
	for s in (-1, 1):
		y = s * 11.27
		K.merge(gl, K.box(0.9, 1.1, min(y, y - s * 0.04), max(y, y - s * 0.04), 0.4, soffit - 0.1))
	K.merge(gl, K.box(0.9, 1.1, -11.1, 11.1, soffit - 0.04, soffit))
	slot = bmesh.new()
	for s in (-1, 1):
		y = s * 11.27
		K.merge(slot, K.box(0.75, 1.25, min(y, y - s * 0.02), max(y, y - s * 0.02), 0.3, soffit - 0.05))
	parts = {"Frame": (hide(fr), "SteelBlack"), "Line_Glow": (gl, "Glow_Neutral")}
	K.build(name, parts, mats, col)
	return col


# ---------------------------------------------------------------- locker

def piece_locker_apse(kit, mats):
	# 11.25 degree segment of the apse wall (circle centre = the apse centre): a honed plinth, two vertical oak slats
	# 0.3 proud of the R16 collision chord on a dark backing, and a pelmet glow washing the slats from the top.
	col = piece(kit, "LockerApse_R16")
	inner = 16.0 * math.cos(math.radians(SEG / 2))  # greybox chord face (15.92)
	parts = {
		"Backing": (hide(K.arc(inner, 16.4, 0, SEG, 1.5, 20.0, steps=2), up=True), "SteelBlack"),
		"Plinth": (hide(K.arc(inner - 0.05, 16.4, 0, SEG, 0.0, 1.5, steps=2)), "ConcreteHoned"),
		"Pelmet": (hide(K.arc(inner - 0.6, inner, 0, SEG, 19.3, 20.0, steps=2), down=False), "SteelBlack"),
	}
	sl = bmesh.new()
	for b in (SEG * 0.25, SEG * 0.75):
		K.merge(sl, lbox(bay_frame(b), -0.5, 0.5, inner - 0.3, inner, 1.5, 19.3, ch=0.06))
	parts["Slats"] = (hide(sl, up=True), "Oak")
	parts["Wash_Glow"] = (K.arc(inner - 0.42, inner - 0.32, 0.4, SEG - 0.4, 19.12, 19.3, steps=2), "Glow_Cove")
	K.build("LockerApse_R16", parts, mats, col, uv_rotate=("Slats",))
	return col


def piece_locker_cheek(kit, mats):
	# Straight oak slat wall 8 wide (back on the collision face at x 0, slats 0.3 proud), honed plinth, pelmet glow.
	col = piece(kit, "LockerCheek")
	hw = 4.0
	sl = bmesh.new()
	n = 5
	for i in range(n):
		y = -hw + 0.8 + i * (2 * hw - 1.6) / (n - 1)
		K.merge(sl, K.cbox(0.0, 0.3, y - 0.5, y + 0.5, 1.5, 19.3, ch=0.06))
	parts = {
		"Backing": (hide(K.box(-0.05, 0.02, -hw, hw, 1.5, 20.0), up=True), "SteelBlack"),
		"Plinth": (hide(K.box(-0.05, 0.05, -hw, hw, 0.0, 1.5)), "ConcreteHoned"),
		"Slats": (hide(sl, up=True), "Oak"),
		"Pelmet": (hide(K.box(0.0, 0.6, -hw, hw, 19.3, 20.0), down=False), "SteelBlack"),
		"Wash_Glow": (K.box(0.32, 0.42, -hw + 0.2, hw - 0.2, 19.12, 19.3), "Glow_Cove"),
	}
	K.build("LockerCheek", parts, mats, col, uv_rotate=("Slats",))
	return col


def piece_locker_backlight(kit, mats):
	# Straight (back at x 0, front +X): a 9 x 13 back-lit field (y 2..15 above the floor) in a 0.5 black steel frame
	# with glow strips inside the frame edges, standing 0.4 deep.
	col = piece(kit, "LockerBacklight")
	hw, z0, z1, e = 4.5, 2.0, 15.0, 0.5
	fr = bmesh.new()
	for y0, y1, za, zb in ((-hw - e, hw + e, z1, z1 + e), (-hw - e, hw + e, z0 - e, z0), (-hw - e, -hw, z0, z1), (hw, hw + e, z0, z1)):
		K.merge(fr, K.cbox(0.0, 0.6, y0, y1, za, zb, ch=0.06))
	K.merge(fr, K.box(0.0, 0.1, -hw, hw, z0, z1))
	gl = bmesh.new()
	for y0, y1, za, zb in ((-hw, hw, z1 - 0.12, z1), (-hw, hw, z0, z0 + 0.12), (-hw, -hw + 0.12, z0, z1), (hw - 0.12, hw, z0, z1)):
		K.merge(gl, K.box(0.12, 0.3, y0, y1, za, zb))
	parts = {
		"Frame": (hide(fr), "SteelBlack"),
		"Field": (K.box(0.3, 0.4, -hw + 0.12, hw - 0.12, z0 + 0.12, z1 - 0.12), "LightPanel"),
		"Edge_Glow": (gl, "Glow_Neutral"),
		"Stand": (hide(K.cbox(0.0, 0.6, -hw - e, hw + e, 0.0, z0 - e, ch=0.06)), "SteelBlack"),
	}
	K.build("LockerBacklight", parts, mats, col)
	return col


def piece_locker_pedestal(kit, mats):
	col = piece(kit, "LockerPedestal")
	s = 48
	parts = {
		"Toe": (hide(K.cyl(0, 0, 3.75, 0.0, 0.25, segs=s), up=True), "SteelBlack"),
		"Drum": (hide(K.cyl(0, 0, 4.0, 0.25, 1.05, segs=s, ch=0.06), up=True), "Brass"),
		"Top": (hide(K.cyl(0, 0, 3.85, 1.05, 1.2, segs=s, ch=0.04)), "ConcreteHoned"),
		"Toe_Glow": (hide(K.arc(3.78, 3.95, 0, 360, 0.02, 0.16, steps=s), up=True), "Glow_Neutral"),
	}
	K.build("LockerPedestal", parts, mats, col)
	return col


def piece_mannequin(kit, mats):
	# Display mannequin (prop, feet at the origin, front +X), fix pass: a light satin default-avatar figure, 5.2 tall,
	# R15 proportions with readable joints (split shins/thighs, upper/lower arms, hands, a tapered torso and the round
	# classic head on a neck), standing on a thin brass base ring. Reads against the back-lit field by its edges.
	col = piece(kit, "Mannequin")
	body = K.group(
		# legs: lower + upper, a shadow line at the knee
		K.cbox(-0.46, 0.46, -0.95, -0.06, 0.18, 1.12, ch=0.07),
		K.cbox(-0.46, 0.46, 0.06, 0.95, 0.18, 1.12, ch=0.07),
		K.cbox(-0.5, 0.5, -0.98, -0.04, 1.17, 2.12, ch=0.08),
		K.cbox(-0.5, 0.5, 0.04, 0.98, 1.17, 2.12, ch=0.08),
		# torso: lower (hips) and upper (chest, wider), waist line between
		K.cbox(-0.5, 0.5, -0.98, 0.98, 2.16, 2.75, ch=0.08),
		K.cbox(-0.52, 0.52, -1.02, 1.02, 2.8, 4.1, ch=0.14),
		# arms: upper + lower + hand, hanging slightly off the body
		K.cbox(-0.46, 0.46, -2.0, -1.08, 3.15, 4.08, ch=0.1),
		K.cbox(-0.44, 0.44, -1.98, -1.1, 2.3, 3.1, ch=0.09),
		K.cbox(-0.4, 0.4, -1.95, -1.13, 1.95, 2.26, ch=0.08),
		K.cbox(-0.46, 0.46, 1.08, 2.0, 3.15, 4.08, ch=0.1),
		K.cbox(-0.44, 0.44, 1.1, 1.98, 2.3, 3.1, ch=0.09),
		K.cbox(-0.4, 0.4, 1.13, 1.95, 1.95, 2.26, ch=0.08),
		# neck + classic round head
		K.cyl(0, 0, 0.3, 4.08, 4.3, segs=16),
	)
	head = K.lathe([(0.0, 5.27), (0.5, 5.27), (0.6, 5.2), (0.64, 5.06), (0.64, 4.5), (0.6, 4.36), (0.5, 4.28), (0.0, 4.28)], steps=24)
	K.merge(body, head)
	base = K.group(
		K.cyl(0, 0, 1.55, 0.0, 0.06, segs=40, ch=0.02),
		K.arc(1.55, 1.62, 0, 360, 0.0, 0.1, steps=40),
	)
	feet = K.cbox(-0.55, 0.55, -1.0, 1.0, 0.06, 0.18, ch=0.04)
	K.build(
		"Mannequin",
		{"Body": (hide(body), "MannequinSatin"), "Feet": (hide(feet), "MannequinSatin"), "Base": (hide(base), "Brass")},
		mats,
		col,
	)
	return col


def piece_loadout_terminal(kit, mats):
	# Console (prop, front +X): a 1.6 deep, 3 wide steel body to y 3.4, a head that holds a 2.6 x 1.8 screen facing
	# front-and-up, a brushed kick plate and a neutral glow at its foot.
	col = piece(kit, "LoadoutTerminal")
	head = K.prism([(-0.8, 3.3), (0.9, 3.3), (0.95, 3.5), (0.55, 5.4), (-0.8, 5.4)], "Y", -1.5, 1.5)
	K.bevel(head, 0.06, segs=1, angle=30)
	# Screen on the sloped front: from (0.95, 3.5) to (0.55, 5.4), inset.
	a = Vector((0.95, 0, 3.5))
	b = Vector((0.55, 0, 5.4))
	t = (b - a).normalized()
	n = Vector((t.z, 0, -t.x))  # outward normal of the slope (front-up)
	if n.x < 0:
		n = -n
	scr = bmesh.new()
	c0 = a + t * 0.15 + n * 0.005
	c1 = b - t * 0.15 + n * 0.005
	vs = []
	for p in (c0, c1):
		for y in (-1.3, 1.3):
			vs.append(scr.verts.new((p.x, y, p.z)))
	scr.faces.new((vs[0], vs[1], vs[3], vs[2]))
	bmesh.ops.recalc_face_normals(scr, faces=scr.faces[:])
	scr.normal_update()
	if scr.faces[0].normal.x < 0:
		bmesh.ops.reverse_faces(scr, faces=scr.faces[:])
	parts = {
		"Body": (hide(K.cbox(-0.8, 0.8, -1.5, 1.5, 0.15, 3.3, ch=0.06)), "SteelBlack"),
		"Head": (head, "SteelBlack"),
		"Kick": (hide(K.box(-0.7, 0.7, -1.4, 1.4, 0.0, 0.15)), "SteelBrushed"),
		"Screen": (scr, "Screen"),
		"Kick_Glow": (K.box(0.62, 0.72, -1.35, 1.35, 0.02, 0.1), "Glow_Neutral"),
	}
	K.build("LoadoutTerminal", parts, mats, col)
	return col


def sign_frame(kit, mats, name, w, h):
	# Lobby sign frame sized for a w x h text panel: 0.4 black steel bezel, charcoal panel (text goes on x 0.5),
	# a 0.3 neutral strip along the bottom.
	col = piece(kit, name)
	parts = K.trim_sign_frame(w=w + 0.8, h=h + 1.1, mode_glow="Glow_Neutral")
	K.build(name, parts, mats, col)
	return col


# ---------------------------------------------------------------- gun profiles (display stands)

def gun_profiles(ids):
	# Underside and top of each gun along its length (Blender gun space: +X muzzle, +Z up), sampled every 0.02 on the
	# 11 lines across the gun's width (lowest underside / highest top wins), from the uploaded FBX. Used to size the display rods and pylons.
	from mathutils.bvhtree import BVHTree
	src = os.path.join(K.ROOT, "art-source", "weapons", "Exports")
	out = {}
	for gid in ids:
		bpy.ops.wm.read_homefile(use_empty=True)
		bpy.ops.import_scene.fbx(filepath=os.path.join(src, gid + ".fbx"))
		dg = bpy.context.evaluated_depsgraph_get()
		verts, polys = [], []
		for ob in bpy.context.scene.objects:
			if ob.type != "MESH":
				continue
			ev = ob.evaluated_get(dg)
			me = ev.to_mesh()
			base = len(verts)
			mw = ob.matrix_world
			verts += [mw @ v.co for v in me.vertices]
			polys += [[base + i for i in p.vertices] for p in me.polygons]
			ev.to_mesh_clear()
		bvh = BVHTree.FromPolygons(verts, polys)
		lo = [min(v[i] for v in verts) for i in range(3)]
		hi = [max(v[i] for v in verts) for i in range(3)]
		under, top = [], []
		x = lo[0]
		while x <= hi[0] + 1e-6:
			bot, tp = None, None
			# Across the whole width (skeleton stocks and side plates sit off the centre line: the centre-line-only
			# sampling stood the hero pylon up through the Vandal's stock).
			for y in [lo[1] + (hi[1] - lo[1]) * k / 10 for k in range(11)]:
				h = bvh.ray_cast(Vector((x, y, lo[2] - 1)), Vector((0, 0, 1)))
				if h[0] is not None and (bot is None or h[0].z < bot):
					bot = h[0].z
				h2 = bvh.ray_cast(Vector((x, y, hi[2] + 1)), Vector((0, 0, -1)))
				if h2[0] is not None and (tp is None or h2[0].z > tp):
					tp = h2[0].z
			under.append(None if bot is None else round(bot, 4))
			top.append(None if tp is None else round(tp, 4))
			x += 0.02
		out[gid] = {"min": [round(v, 4) for v in lo], "max": [round(v, 4) for v in hi], "x0": round(lo[0], 4), "dx": 0.02, "under": under, "top": top}
		print("GUN_PROFILE", gid, [round(v, 3) for v in lo], [round(v, 3) for v in hi])
	path = os.path.join(K.ART_DIR, "Exports", "GunProfiles.json")
	os.makedirs(os.path.dirname(path), exist_ok=True)
	with open(path, "w") as f:
		json.dump(out, f)
	print("GUN_PROFILES written", path)


# ---------------------------------------------------------------- contact sheet

ROUND_FRONT = {  # round pieces: the bearing of their visible middle (turned to face the camera on the sheet)
	"ArmouryPier_R42": 0.0, "ArmouryDrum_R42": SEG / 2, "GunChapel": CH_SPAN / 2, "GunChapel_R50": CH_SPAN / 2,
	"LockerApse_R16": SEG / 2,
}


def contact_sheet(pieces, mats, path, samples):
	sheet = K.collection("Sheet")
	labels = K.collection("SheetLabels")
	order = list(pieces.items())
	x, z, row_h = 0.0, 0.0, 0.0
	max_w = 150.0
	placed = []
	for name, col in order:
		# Orientation for the sheet: the front faces -Y (toward the camera).
		if name in ROUND_FRONT:
			rot = Matrix.Rotation(math.radians(ROUND_FRONT[name]), 4, "Z")
		elif name in ("LanternRing_R16", "HeroDais", "FloorRing_R20"):
			rot = Matrix.Identity(4)
		else:
			rot = Matrix.Rotation(math.radians(-90), 4, "Z")
		pts = []
		for ob in col.all_objects:
			if ob.type == "MESH":
				pts += [rot @ (ob.matrix_world @ Vector(c)) for c in ob.bound_box]
		lo = Vector([min(p[i] for p in pts) for i in range(3)])
		hi = Vector([max(p[i] for p in pts) for i in range(3)])
		w = hi.x - lo.x
		d = hi.y - lo.y
		if x > 0 and x + w > max_w:
			x = 0.0
			z -= row_h + 8.0
			row_h = 0.0
		off = Vector((x - lo.x, -lo.y - d / 2, z - lo.z))
		e = bpy.data.objects.new("Sheet_" + name, None)
		e.instance_type = "COLLECTION"
		e.instance_collection = col
		e.matrix_world = Matrix.Translation(off) @ rot
		sheet.objects.link(e)
		t = K.text(name, 1.1, (x + w / 2, -d / 2 - 1.0, z - 2.2), labels, mats["SignText"], rot=(90, 0, 0), font=K.FONT_LABEL)
		placed.append((name, x, z, w, hi.z - lo.z))
		row_h = max(row_h, hi.z - lo.z + 3.0)
		x += w + 6.0
	minz = z - row_h
	top = max(p[2] + p[4] for p in placed)
	cx = max_w / 2
	cz = (minz + top) / 2
	stage = K.collection("Stage")
	cam = K.camera((cx, -260, cz + 70), (cx, 0, cz), lens=50, name="SheetCam", col=stage)
	cam.data.type = "ORTHO"
	cam.data.ortho_scale = max(max_w * 1.08, (top - minz) * 1.45)
	w = bpy.data.worlds.new("SheetWorld")
	bpy.context.scene.world = w
	w.use_nodes = True
	bg = w.node_tree.nodes.get("Background")
	bg.inputs[0].default_value = (0.05, 0.055, 0.065, 1)
	bg.inputs[1].default_value = 1.0
	K.light("SUN", "SheetKey", (0, 0, 100), 3.5, 0xF2F0EA, target=(cx - 40, 60, cz - 60), shadow=True, col=stage)
	K.light("SUN", "SheetFill", (0, 0, 100), 1.0, 0xDDE8F2, target=(cx + 60, 40, cz + 30), shadow=False, col=stage)
	K.render_settings(samples=samples)
	K.bloom()
	bpy.context.scene.camera = cam
	return K.render(path, res=(2000, 1500))


# ---------------------------------------------------------------- main

def main():
	if "--gun-profiles" in ARGS:
		ids = [a for a in ARGS[ARGS.index("--gun-profiles") + 1:] if not a.startswith("--")]
		gun_profiles(ids)
		return
	t0 = time.time()
	bpy.ops.wm.read_homefile(use_empty=True)
	mats = materials()
	kit = K.collection("Kit")
	pieces = {}
	pieces["ArmouryPier_R42"] = piece_pier(kit, mats)
	pieces["ArmouryDrum_R42"] = piece_drum(kit, mats)
	pieces["LanternRing_R16"] = piece_lantern(kit, mats)
	pieces["FloorRing_R20"] = piece_floor_ring(kit, mats)
	pieces["GunChapel"] = piece_gun_chapel(kit, mats)
	pieces["GunChapel_R50"] = piece_gun_chapel_r50(kit, mats)
	pieces["TrophyWall"] = trophy_wall(kit, mats, "TrophyWall", 10.0)
	pieces["TrophyWall_10"] = trophy_wall(kit, mats, "TrophyWall_10", 4.6)
	pieces["TrophyTab"] = piece_trophy_tab(kit, mats)
	pieces["GunTurntable"] = turntable(kit, mats, "GunTurntable", 5.0)
	pieces["GunTurntable_7"] = turntable(kit, mats, "GunTurntable_7", 3.5)
	rod, saddle = piece_display_rod(kit, mats)
	pieces["DisplayRod"] = rod
	pieces["DisplaySaddle"] = saddle
	pieces["GunPlaque"] = piece_plaque(kit, mats)
	pieces["HeroDais"] = piece_hero_dais(kit, mats)
	py, cr, pb, pc = piece_hero_pylon(kit, mats)
	pieces["HeroPylon"] = py
	pieces["HeroCradle"] = cr
	pieces["HeroPylonBase"] = pb
	pieces["HeroPylonCollar"] = pc
	pieces["HeroLectern"] = piece_hero_lectern(kit, mats)
	pieces["SteelFrame_14"] = steel_frame(kit, mats, "SteelFrame_14", 14.0)
	pieces["SteelFrame_135"] = steel_frame(kit, mats, "SteelFrame_135", 13.5)
	pieces["LockerApse_R16"] = piece_locker_apse(kit, mats)
	pieces["LockerCheek"] = piece_locker_cheek(kit, mats)
	pieces["LockerBacklight"] = piece_locker_backlight(kit, mats)
	pieces["LockerPedestal"] = piece_locker_pedestal(kit, mats)
	pieces["Mannequin"] = piece_mannequin(kit, mats)
	pieces["LoadoutTerminal"] = piece_loadout_terminal(kit, mats)
	pieces["SignFrame_20x2"] = sign_frame(kit, mats, "SignFrame_20x2", 20.0, 2.4)
	pieces["SignFrame_16x3"] = sign_frame(kit, mats, "SignFrame_16x3", 16.0, 3.0)
	pieces["SignFrame_16x6"] = sign_frame(kit, mats, "SignFrame_16x6", 16.0, 6.0)
	pieces["SignFrame_5x1"] = sign_frame(kit, mats, "SignFrame_5x1", 5.0, 1.2)
	for c in pieces.values():
		c["KitGroup"] = "Weapons"
	tris = {}
	worst = 0
	for name, col in pieces.items():
		tris[name] = tri_count(col)
		for ob in col.all_objects:
			if ob.type == "MESH":
				worst = max(worst, sum(len(p.vertices) - 2 for p in ob.data.polygons))
	print("KIT_TRIS " + json.dumps(tris))
	print("KIT_TRIS total %d, worst object %d" % (sum(tris.values()), worst))
	bpy.context.view_layer.layer_collection.children["Kit"].exclude = True
	blend = K.save("Kit_Weapons")
	print("KIT saved", blend, "%.1fs" % (time.time() - t0))
	if "--no-render" in ARGS:
		return
	samples = int(ARGS[ARGS.index("--samples") + 1]) if "--samples" in ARGS else 24
	out = contact_sheet(pieces, mats, os.path.join(K.RENDER_DIR, "contact-weapons.jpg"), samples)
	print("KIT render", out, "%.1fs" % (time.time() - t0))


if __name__ == "__main__":
	main()
