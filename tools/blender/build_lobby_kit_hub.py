# build_lobby_kit_hub.py: the Lobby kit group "Hub" (vault/02 Art/Lobby Kit.md, Structure (hub)), phase 1 step 4.
#
# Every piece is a collection Lobby_<Piece> built at the world origin with the Lobby Kit origin conventions:
#   round pieces    circle centre on the floor, segment from bearing 0 to 11.25 (Alcove_R68: 0 to 22.5) clockwise from
#                   north (Blender +Y; bearing b points to (sin b, cos b))
#   straight pieces on the floor at the centre of the back face, facing +X (RotundaPier, PortalFrame_26/_52, PierPlaque)
#   wall-mounted    TitleBand_26/_40: bottom centre of the back face (hangs in the portal's title slot)
#   props           on the floor at the centre, front +X (RotundaColumn, LeaderboardFrame; the board centre is at x 0)
# The piece builders are ported from build_lobby_preview_structure.py (the approved preview), with the changes the
# real greybox needs (see each builder): the rock sits 0.4 further back so its peaks stay near the collision face, the
# portal frames reach the wing boundary and narrow 0.17 so their faces never coincide with a wing's wall, every
# portal gets a threshold sill 0.05 proud (it covers the ring floor / wing floor overlap), a visible cove line on the
# drum (Roblox Neon lights nothing, so the coves read as lines), a glowing perimeter slot on the ring ceiling, and new
# pieces: RockPlinth_R68 (shared by every rock segment), Alcove_R68, PortalFrame_52, TitleBand_40, LeaderboardFrame,
# PierPlaque. Text is never part of the kit (signs are SurfaceGuis in Studio).
#
# Run (headless):
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
#       --python tools/blender/build_lobby_kit_hub.py -- [--no-render] [--samples N]
# Writes art-source/lobby/Kit_Hub.blend and vault/02 Art/References/lobby/kit/contact-hub.jpg.
# Then: export_lobby_kit.py -- Hub, upload_models.py --lobby Hub, kit_bundle.py Hub (tools/studio/lobby).

import math, os, sys, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
import lobbykit as K  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SEG = K.SEG  # 11.25

# Plan numbers (Lobby Art Plan, Zones; greybox Hub.luau).
R_ROT = 44.0
R_RING_OUT = 68.0
R_OCULUS = 16.0
Y_COLONNADE = 28.0
Y_DRUM_TOP = 46.0
Y_RIM = 54.0
Y_SKY = 60.0
PLINTH_H, GAP_H = 1.5, 0.6
ROCK_TOP = 31.5
CEIL_EDGE = 66.5
FRAME_T = 3.0
PORTAL_H = 15.85  # head soffit 0.15 under the greybox throat roof (16), so a wing soffit at 16 never z-fights it
SLOT = (16.6, 27.25, 0.6)  # title slot z0, z1, depth
WING_X = 72.0  # wing boundary: side portal frames run back to it
# Side portals: two segments' chord at R68 is 26.53; the jambs stand 0.17 inside it (13.1) so a wing wall on the
# greybox line (13.27) is always behind them.
CLEAR_26 = 26.2
FRONT_26 = R_RING_OUT * math.cos(math.radians(SEG)) - 2.0  # 64.69
DEEP_26 = WING_X - FRONT_26  # 7.31: front at R64.69, back on the wing boundary
# Duels: four segments' chord at R68 is 52.05; jambs 0.2 inside the Duels entry walls (x +-26).
CLEAR_52 = 51.6
FRONT_52 = R_RING_OUT * math.cos(math.radians(2 * SEG)) - 2.0  # 60.82
DEEP_52 = 6.0
# The Duels sill stops exactly where the Duels entry floor starts (z -64.6, its top also 0.05), so the two never overlap;
# beyond it the Duels floor covers the ring floor's R70 edge.
SILL_BACK_52 = DEEP_52 - (64.6 - FRONT_52)


def deg_at(width, r):
	return math.degrees(width / r)


# ---------------------------------------------------------------- UV helpers (studs), ported

def polar_uvs(u_per_seg=None, v_of=None, floor_v_of=None):
	v_of = v_of or (lambda z: z)
	floor_v_of = floor_v_of or (lambda r, f: r)

	def fn(bm):
		layer = bm.loops.layers.uv.verify()
		bm.normal_update()
		for f in bm.faces:
			n = f.normal
			c = f.calc_center_median()
			radial = Vector((c.x, c.y, 0.0))
			rn = radial.normalized() if radial.length > 1e-6 else Vector((0, 1, 0))
			horiz = Vector((n.x, n.y, 0.0))
			for lp in f.loops:
				p = lp.vert.co
				r = math.hypot(p.x, p.y)
				b = math.degrees(math.atan2(p.x, p.y))
				if b < -90:
					b += 360
				u = b / SEG * u_per_seg if u_per_seg else math.radians(b) * r
				if abs(n.z) > 0.55:
					lp[layer].uv = (u, floor_v_of(r, f))
				elif horiz.length > 1e-6 and abs(horiz.normalized().dot(rn)) > 0.6:
					lp[layer].uv = (u, v_of(p.z))
				else:
					lp[layer].uv = (r, v_of(p.z))
		return bm
	return fn


def panel_uvs(width=None, center_faces=False, v_shift=0.0, pu=3.2):
	def fn(bm):
		K.stud_uvs(bm)
		layer = bm.loops.layers.uv.verify()
		for f in bm.faces:
			n = f.normal
			if abs(n.z) > 0.7:
				continue
			us = [lp[layer].uv.x for lp in f.loops]
			shift = 0.0
			scale = 1.0
			if width and abs(n.x) >= abs(n.y):
				k = max(1, round(width / pu))
				scale = k * pu / width
				shift = width / 2 * scale
			elif center_faces:
				cu = sum(us) / len(us)
				shift = pu / 2 - (cu % pu)
			for lp in f.loops:
				uv = lp[layer].uv
				lp[layer].uv = (uv.x * scale + shift, uv.y + v_shift)
		return bm
	return fn


def rotz(bm, deg):
	# Turns a bmesh about Z by `deg` degrees CLOCKWISE seen from above (a bearing step).
	K.place(bm, Matrix.Rotation(-math.radians(deg), 4, "Z"))
	return bm


# ---------------------------------------------------------------- rotunda

def piece_pier(mats, col):
	# RotundaPier 3 x 3 x 28: board-formed shaft (0.25 chamfers) on a black-steel shoe with a recessed reveal, plus
	# two V-groove reveals (formwork lifts at y 10.6 and 17.0, the 6.4 module) that read without the texture variant.
	shoe = K.cbox(-0.12, 3.12, -1.62, 1.62, 0.0, 0.9, ch=0.06)
	reveal = K.box(0.15, 2.85, -1.35, 1.35, 0.9, 1.05)
	parts = [K.cbox(0.0, 3.0, -1.5, 1.5, 1.05, 10.5, ch=0.25), K.cbox(0.0, 3.0, -1.5, 1.5, 10.7, 16.9, ch=0.25), K.cbox(0.0, 3.0, -1.5, 1.5, 17.1, Y_COLONNADE, ch=0.25)]
	core = K.box(0.12, 2.88, -1.38, 1.38, 10.4, 17.2)  # the groove floors
	K.add_obj("RotundaPier_Shaft", K.group(*parts, core), [mats["ConcreteBoard"]], col, uvs=panel_uvs(center_faces=True, v_shift=4.0 - 1.05))
	K.add_obj("RotundaPier_Shoe", K.group(shoe, reveal), [mats["SteelBlack"]], col)


def piece_column(mats, col):
	# RotundaColumn: slim black-steel column (dia 1.2) with a brushed base ring and the two leaderboard brackets
	# (y 12 and 25.5, arms toward the rotunda, +X).
	c = K.cyl(0, 0, 0.6, 0.0, Y_COLONNADE, segs=16)
	base = K.cyl(0, 0, 0.85, 0.0, 0.5, segs=16, ch=0.05)
	cap = K.cyl(0, 0, 0.8, Y_COLONNADE - 0.4, Y_COLONNADE, segs=16, ch=0.05)
	br = bmesh.new()
	for z in (12.0, 25.5):
		K.merge(br, K.cbox(0.4, 1.6, -0.15, 0.15, z - 0.5, z, ch=0.04))
	K.add_obj("RotundaColumn_Shaft", K.group(c, cap, br), [mats["SteelBlack"]], col)
	K.add_obj("RotundaColumn_Base", base, [mats["SteelBrushed"]], col)


def piece_ring_beam(mats, col):
	prof = [(45.8, 31.0), (45.8, 27.75), (42.75, 27.75), (42.5, 28.0), (42.5, 31.6), (42.8, 31.6), (42.8, 31.0), (45.8, 31.0)]
	bm = K.lathe(prof, 0.0, SEG)
	uv = polar_uvs(u_per_seg=9.6, v_of=lambda z: z - 28.0 + 1.6)
	K.add_obj("RingBeam_R44_Beam", bm, [mats["ConcreteBoard"]], col, uvs=uv)


CORNICE_TOP = 44.9
CORNICE_LIP = 0.6
CORNICE_IN = 42.7


def piece_drum(mats, col):
	# Drum_R44 (y 31-46): board-formed, with two 0.12-deep V reveals (formwork lifts at y 35.9 and 40.6) and the
	# cornice cove under the dome's springing. Roblox Neon lights nothing, so the cove strip rises 0.4 above the steel
	# lip: from the floor it reads as one warm line under the dome (the coffers get no wash).
	ct, ci = CORNICE_TOP, CORNICE_IN
	g = 0.12
	prof = [(44.0, 31.0), (44.0, 35.8), (44.0 + g, 35.9), (44.0, 36.0), (44.0, 40.5), (44.0 + g, 40.6), (44.0, 40.7),
			(44.0, ct - 0.6), (ci, ct - 0.6), (ci, ct), (44.0, ct), (44.0, Y_DRUM_TOP + 0.6)]
	bm = K.lathe(prof, 0.0, SEG)
	uv = polar_uvs(u_per_seg=9.6, v_of=lambda z: z - 31.0 + 5.3)
	K.add_obj("Drum_R44_Wall", bm, [mats["ConcreteBoard"]], col, uvs=uv)
	lip = K.arc(ci, ci + 0.15, 0.0, SEG, ct, ct + CORNICE_LIP)
	K.add_obj("Drum_R44_CoveLip", lip, [mats["SteelBlack"]], col, smooth_angle=0)
	K.add_glow("Drum_R44_Cove", K.arc(ci + 0.2, ci + 0.42, 0.0, SEG, ct, ct + CORNICE_LIP + 0.4), mats["Glow_Cove"], col)


def dome_z(r):
	t = max(0.0, min(1.0, (r - R_OCULUS) / (R_ROT - R_OCULUS)))
	return Y_RIM - (Y_RIM - Y_DRUM_TOP) * t ** 1.6


def dome_up(r):
	t = max(1e-4, min(1.0, (r - R_OCULUS) / (R_ROT - R_OCULUS)))
	dz = -(Y_RIM - Y_DRUM_TOP) * 1.6 * t ** 0.6 / (R_ROT - R_OCULUS)
	v = Vector((-dz, 1.0))
	v.normalize()
	return v


def coffer_shell(rs, rows, h, z_of, up_of, thick, steps, b0=0.0, b1=SEG):
	# Ported unchanged from build_lobby_preview_structure.py: a coffered wedge as one closed solid.
	bm = bmesh.new()
	bmid = (b0 + b1) / 2

	def P(r, b, up):
		u = up_of(r)
		d = K.bearing_dir(b)
		return Vector((d.x * (r + u.x * up), d.y * (r + u.x * up), z_of(r) + u.y * up))

	def bstations(r, inset=0.0):
		a = deg_at(h + inset, r)
		return [b0, b0 + a, bmid, b1 - a, b1]

	V = [[bm.verts.new(P(r, b, 0.0)) for b in bstations(r)] for r in rs]
	T = [[bm.verts.new(P(r, b, thick)) for b in bstations(r)] for r in rs]
	shade = []
	board = []
	n = len(rs)
	for i in range(n - 1):
		for j in range(4):
			if (rs[i], rs[i + 1]) in rows and j in (1, 2):
				continue
			board.append(bm.faces.new((V[i][j], V[i][j + 1], V[i + 1][j + 1], V[i + 1][j])))
	for (ra, rb) in rows:
		ia, ib = rs.index(ra), rs.index(rb)
		loop = [V[ia][1], V[ia][2], V[ia][3], V[ib][3], V[ib][2], V[ib][1]]
		up = 0.0
		ins = 0.0
		first = True
		for inset, depth in steps:
			up += depth
			a0, a1 = ra + ins, rb - ins

			def ring(a0=a0, a1=a1, ins=ins, up=up):
				sa, sb = bstations(a0, ins), bstations(a1, ins)
				return [bm.verts.new(P(a0, sa[1], up)), bm.verts.new(P(a0, sa[2], up)), bm.verts.new(P(a0, sa[3], up)),
						bm.verts.new(P(a1, sb[3], up)), bm.verts.new(P(a1, sb[2], up)), bm.verts.new(P(a1, sb[1], up))]
			top = ring()
			for k in range(6):
				f = bm.faces.new((loop[k], loop[(k + 1) % 6], top[(k + 1) % 6], top[k]))
				(board if first else shade).append(f)
			loop = top
			if inset > 0:
				ins += inset
				a0, a1 = ra + ins, rb - ins
				inner = ring(a0, a1, ins, up)
				for k in range(6):
					shade.append(bm.faces.new((loop[k], loop[(k + 1) % 6], inner[(k + 1) % 6], inner[k])))
				loop = inner
			first = False
		shade.append(bm.faces.new(loop))
	for i in range(n - 1):
		for j in range(4):
			board.append(bm.faces.new((T[i][j], T[i][j + 1], T[i + 1][j + 1], T[i + 1][j])))
	for j in (0, 4):
		for i in range(n - 1):
			board.append(bm.faces.new((V[i][j], V[i + 1][j], T[i + 1][j], T[i][j])))
	for i in (0, n - 1):
		for j in range(4):
			board.append(bm.faces.new((V[i][j], V[i][j + 1], T[i][j + 1], T[i][j])))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	for f in board:
		f.material_index = 0
	for f in shade:
		f.material_index = 1
	return bm


def piece_dome(mats, col):
	rs = [R_OCULUS, 20.0, 25.0, 26.6, 33.4, 35.0, 42.8, R_ROT]
	rows = [(20.0, 25.0), (26.6, 33.4), (35.0, 42.8)]
	bm = coffer_shell(rs, rows, 0.6, dome_z, dome_up, 2.4, [(0.45, 0.6), (0.0, 0.75)], 0.0, SEG)
	K.add_obj("DomeCoffer_R44_Shell", bm, [mats["ConcreteBoard"], mats["ConcreteBoardShade"]], col, uvs=polar_uvs(), smooth_angle=20)


def piece_oculus(mats, col):
	# OculusRim_R16: board-formed shaft to the sky (y 60), knife-edge black-steel lip, 8 thin spokes to a hub, and a
	# warm Neon halo ring just above the lip. The sky stays open (the beam rig is step 6).
	shaft = K.lathe([(R_OCULUS, 56.35), (R_OCULUS, Y_SKY)], 0, 360, steps=32)
	lip = K.lathe([(18.6, 53.78), (15.75, 53.78), (16.0, 54.3)], 0, 360, steps=32)
	glow = K.lathe([(15.9, 54.38), (15.9, 54.56)], 0, 360, steps=32)
	spokes = bmesh.new()
	for k in range(8):
		b = 22.5 + 45.0 * k
		s = K.box(1.3, 16.5, -0.25, 0.25, Y_SKY - 0.7, Y_SKY)
		K.place(s, Matrix.Rotation(math.radians(90 - b), 4, "Z"))
		K.merge(spokes, s)
	hub = K.cyl(0, 0, 1.4, Y_SKY - 0.7, Y_SKY, segs=8)
	uv = polar_uvs(u_per_seg=9.6 * 16.4 / 44.0, v_of=lambda z: z - 54.0)
	K.add_obj("OculusRim_R16_Shaft", shaft, [mats["ConcreteBoard"]], col, uvs=uv)
	K.add_obj("OculusRim_R16_Lip", lip, [mats["SteelBlack"]], col, smooth_angle=30)
	K.add_obj("OculusRim_R16_Spokes", K.group(spokes, hub), [mats["SteelBlack"]], col)
	K.add_glow("OculusRim_R16_Cove", glow, mats["Glow_Cove"], col)


def piece_dais(mats, col):
	# SpawnDais dia 24 x 0.5 (ported): hot-spot concrete top, brass compass rose whose long north point aims at Duels,
	# a brass ring, an oak band and a chamfered brushed-steel rim.
	top = K.lathe([(0.0, 0.5), (10.0, 0.5)], 0, 360, steps=32)
	oak = K.lathe([(10.0, 0.5), (11.6, 0.5)], 0, 360, steps=32)
	rim = K.lathe([(11.6, 0.5), (11.92, 0.5), (12.0, 0.42), (12.0, 0.0)], 0, 360, steps=32)
	ring = K.lathe([(9.55, 0.53), (9.95, 0.53)], 0, 360, steps=32)
	rose_b, rose_d = bmesh.new(), bmesh.new()
	zc = 0.535
	for k in range(8):
		b = 45.0 * k
		r_tip = 11.3 if k == 0 else (8.6 if k % 2 == 0 else 5.0)
		w = 0.9 if k % 2 == 0 else 0.6
		tip = K.polar(r_tip, b, zc)
		for side in (-1, 1):
			base = K.polar(w, b + side * 90, zc)
			ctr = Vector((0, 0, zc + 0.01))
			bmt = rose_b if (side == 1) == (k % 2 == 0) else rose_d
			f = bmt.faces.new([bmt.verts.new(ctr), bmt.verts.new(tip), bmt.verts.new(base)])
			f.normal_update()
			if f.normal.z < 0:
				f.normal_flip()
	ring_uv = polar_uvs()
	K.add_obj("SpawnDais_Top", top, [mats["ConcretePolishedSun"]], col, smooth_angle=0)
	K.add_obj("SpawnDais_OakBand", oak, [mats["Oak"]], col, uvs=ring_uv, smooth_angle=0)
	K.add_obj("SpawnDais_Rim", rim, [mats["SteelBrushed"]], col, uvs=ring_uv, smooth_angle=50)
	K.add_obj("SpawnDais_CompassRing", ring, [mats["Brass"]], col, smooth_angle=0)
	K.add_obj("SpawnDais_CompassBrass", rose_b, [mats["Brass"]], col, smooth_angle=0)
	K.add_obj("SpawnDais_CompassSteel", rose_d, [mats["SteelBlack"]], col, smooth_angle=0)


def flat_strip(r0, r1, b, w, z):
	# One up-facing quad from radius r0 to r1 along bearing b, w wide, at height z (an inlay line on a floor).
	bm = bmesh.new()
	d = K.bearing_dir(b)
	n = K.bearing_dir(b + 90)
	pts = [d * r0 - n * (w / 2), d * r1 - n * (w / 2), d * r1 + n * (w / 2), d * r0 + n * (w / 2)]
	f = bm.faces.new([bm.verts.new((p.x, p.y, z)) for p in pts])
	f.normal_update()
	if f.normal.z < 0:
		f.normal_flip()
	return bm


def flat_ring(r0, r1, z, steps=64, center=(0.0, 0.0)):
	return K.lathe([(r0, z), (r1, z)], 0, 360, steps=steps, center=center)


R_DAIS_RING = 13.3
R_BRASS_MID = (26.85, 27.15)
R_FIELD = 39.4
R_BORDER = 39.6


def piece_rotunda_floor(mats, col):
	# RotundaFloor (fix pass): a patterned floor instead of one flat disc. Flush rings (top z 0; placed 0.02 up on
	# the greybox floor top): a dark honed ring round the dais, the polished inner field, a flush brass ring at R27, a
	# warm terrazzo outer band, a flush brass line at R39.5 and a honed border (R39.6-43.85) with a saw joint per kit
	# segment, then the brushed-steel edge strip at R44. Inlay lines 0.012 proud: four brass cardinal lines from the
	# dais to the four portals (Duels, Weapons, Range, Market) and twelve dark saw joints between them. The sun inlay
	# (R16 round plan (0, -10), 0.02 proud, the greybox inlay's top) is a toned-down cream (#D6CEC0, the art review:
	# #F2EADB clipped to white under the beam) inside a 0.025-proud brass rim. Under the dais (R < 11.9) is left open.
	K.add_obj("RotundaFloor_Field", flat_ring(R_DAIS_RING, R_BRASS_MID[0], 0.0), [mats["ConcretePolished"]], col, smooth_angle=0)
	K.add_obj("RotundaFloor_Band", flat_ring(R_BRASS_MID[1], R_FIELD, 0.0), [mats["Terrazzo"]], col, smooth_angle=0)
	K.add_obj("RotundaFloor_Border", flat_ring(R_BORDER, R_ROT - 0.15, 0.0), [mats["ConcreteHoned"]], col, smooth_angle=0)
	dark = flat_ring(11.9, R_DAIS_RING, 0.0, steps=48)
	for k in range(16):
		b = 22.5 * k
		if k % 4:
			K.merge(dark, flat_strip(R_DAIS_RING, R_FIELD, b, 0.07, 0.012))
	for k in range(32):
		K.merge(dark, flat_strip(R_BORDER, R_ROT - 0.15, k * SEG, 0.07, 0.012))
	K.add_obj("RotundaFloor_Joints", dark, [mats["ConcreteDark"]], col, smooth_angle=0)
	brass = flat_ring(*R_BRASS_MID, 0.0)
	K.merge(brass, flat_ring(R_FIELD, R_BORDER, 0.0))
	for k in range(4):
		K.merge(brass, flat_strip(R_DAIS_RING, R_FIELD, 90.0 * k, 0.3, 0.012))
	K.merge(brass, K.lathe([(16.0, 0.02), (16.0, 0.025), (16.3, 0.025)], 0, 360, steps=48, center=(0.0, 10.0)))
	K.add_obj("RotundaFloor_Brass", brass, [mats["Brass"]], col, smooth_angle=0)
	# A thin light line along each brass cardinal (wayfinding from the dais to the four portals; recoloured per
	# wing in Studio: N Duels, E Weapons, S Range, W Market).
	for k, d in enumerate("NESW"):
		K.add_glow("RotundaFloor_Line%s" % d, flat_strip(R_DAIS_RING + 0.6, R_FIELD - 0.6, 90.0 * k, 0.1, 0.016), mats["Glow_Cove"], col)
	inlay = K.lathe([(0.0, 0.02), (16.0, 0.02)], 0, 360, steps=48, center=(0.0, 10.0))
	K.add_obj("RotundaFloor_SunInlay", inlay, [mats["ConcretePolishedSun"]], col, smooth_angle=0)
	edge = K.lathe([(R_ROT - 0.15, 0.005), (R_ROT, 0.005), (R_ROT, -0.6)], 0, 360, steps=64)
	K.add_obj("RotundaFloor_Edge", edge, [mats["SteelBrushed"]], col, smooth_angle=0)


# ---------------------------------------------------------------- ring

def piece_ring_floor(mats, col):
	# RingFloor_R44_68 (ported): honed dark concrete, the oak slide band R54-58 between brushed steel strips; the outer
	# band runs on to R70 under the plinth (and under the portal sills).
	bands = [(R_ROT, 54.0, 0), (54.0, 54.12, 2), (54.12, 57.88, 1), (57.88, 58.0, 2), (58.0, 70.0, 0)]
	bm = bmesh.new()
	for r0, r1, m in bands:
		K.merge(bm, K.arc(r0, r1, 0.0, SEG, -0.6, 0.0, mat=m))

	def uv(bm):
		layer = bm.loops.layers.uv.verify()
		bm.normal_update()
		for f in bm.faces:
			c = f.calc_center_median()
			rc = math.hypot(c.x, c.y)
			for lp in f.loops:
				p = lp.vert.co
				r = math.hypot(p.x, p.y)
				b = math.degrees(math.atan2(p.x, p.y))
				if f.material_index == 1:
					lp[layer].uv = (math.radians(b) * r, r)
				elif abs(f.normal.z) > 0.7:
					v0 = R_ROT if rc < 54 else 58.0
					lp[layer].uv = (b / SEG * 10.0, r - v0)
				else:
					lp[layer].uv = (math.radians(b) * r, p.z)
		return bm
	K.add_obj("RingFloor_R44_68_Floor", bm, [mats["ConcreteDark"], mats["Oak"], mats["SteelBrushed"]], col, uvs=uv, smooth_angle=0)


def piece_ring_ceiling(mats, col):
	# RingCeiling_R44_68 (ported): one plain 1.5-deep coffer per segment in the shade colour, the perimeter slot lid
	# (66.5 to the rock), plus a warm Neon line on the lid's underside at the rock: the "glowing perimeter slot".
	rs = [45.5, 46.7, 65.3, CEIL_EDGE]
	rows = [(46.7, 65.3)]
	bm = coffer_shell(rs, rows, 1.0, lambda r: Y_COLONNADE, lambda r: Vector((0.0, 1.0)), 3.5, [(0.0, 1.5)], 0.0, SEG)
	K.merge(bm, K.arc(CEIL_EDGE, 70.5, 0.0, SEG, ROCK_TOP, ROCK_TOP + 0.5))
	K.mat_all(bm, 0)  # one material: the slab exports as one part
	K.add_obj("RingCeiling_R44_68_Slab", bm, [mats["ConcreteBoardShade"]], col, uvs=polar_uvs(), smooth_angle=0)
	K.add_glow("RingCeiling_R44_68_Slot", K.arc(67.0, 67.3, 0.0, SEG, ROCK_TOP - 0.12, ROCK_TOP - 0.02), mats["Glow_Cove"], col)


def bend_rock(rock, width, span, r_back, z0, flip_ready=True, height=None):
	# Bends a K.rock_face (kit space: back plane x = 0, width along y, height along z) onto an arc spanning `span`
	# degrees from bearing 0, its back plane at r_back. flip_ready also holds the top row at mid depth, so the piece
	# can be placed upside down (turned 180 degrees about its mid radial line) and still meet its neighbours.
	if flip_ready and height is not None:
		xs = [v.co.x for v in rock.verts if abs(v.co.y) >= width / 2 - 1e-4]
		mid = sum(xs) / len(xs) if xs else None
		for v in rock.verts:
			if abs(v.co.z - height) < 1e-4 and mid is not None:
				v.co.x = mid
	for vt in rock.verts:
		x, y, z = vt.co
		b = span / 2 + y / width * span
		vt.co = K.polar(r_back - x, b, z + z0)
	return rock


ROCK_DEPTH, ROCK_RELIEF = 2.6, 2.4
# Peaks on R67.7 (the greybox rock collision chord runs R67.67-68, so no facet stands more than 0.33 in front of
# it), foot / edges on R68.9.
R_ROCK_BACK = 67.7 + ROCK_DEPTH


def piece_rock_plinth(mats, col):
	# RockPlinth_R68 (one per rock segment, under every RockWall variant): honed plinth 1.5 (front R68.25) with a
	# brushed nosing, the 0.6 x 0.5 shadow gap (black-steel liner, warm Neon tucked in its top back corner); the rock's
	# foot (R68.9) sits on the gap.
	f0 = R_RING_OUT
	h0, h1 = PLINTH_H, PLINTH_H + GAP_H
	plinth = K.lathe([(f0 + 0.25, 0.0), (f0 + 0.25, h0), (f0 + 1.1, h0)], 0.0, SEG)  # top runs back under the gap liner
	nosing = K.lathe([(f0 + 0.25, h0 - 0.1), (f0 + 0.17, h0 - 0.1), (f0 + 0.17, h0), (f0 + 0.25, h0)], 0.0, SEG)
	liner = K.lathe([(f0 + 1.05, h0), (f0 + 1.05, h1 - 0.05), (f0, h1 - 0.05)], 0.0, SEG)
	glow = K.lathe([(f0 + 0.96, h1 - 0.2), (f0 + 0.96, h1 - 0.06)], 0.0, SEG)
	uvp = polar_uvs()
	K.add_obj("RockPlinth_R68_Plinth", plinth, [mats["ConcreteHoned"]], col, uvs=polar_uvs(u_per_seg=10.0, v_of=lambda z: z + 1.75), smooth_angle=0)
	K.add_obj("RockPlinth_R68_Nosing", nosing, [mats["SteelBrushed"]], col, uvs=uvp, smooth_angle=0)
	K.add_obj("RockPlinth_R68_GapLiner", liner, [mats["SteelBlack"]], col, uvs=uvp, smooth_angle=0)
	K.add_glow("RockPlinth_R68_Gap", glow, mats["Glow_Cove"], col)


def piece_rock_wall(mats, v, seed):
	# RockWall_R68_<v>: faceted two-scale granite (5 strata benches) from the shadow gap (y 2.1) to the slot lid (31.5),
	# bent onto R68 (peaks R67.7, edges and foot R68.9), with its top row held too so it can be placed upside down.
	col = K.collection("Lobby_RockWall_R68_" + v)
	h1 = PLINTH_H + GAP_H
	width = math.radians(SEG) * R_RING_OUT
	height = ROCK_TOP - h1
	rock = K.rock_face(width, height, seed, cell=2.0, depth=ROCK_DEPTH, relief=ROCK_RELIEF, ledges=5, chips=0.17, row=2.6)
	bend_rock(rock, width, SEG, R_ROCK_BACK, h1, height=height)
	K.add_obj("RockWall_R68_%s_Rock" % v, rock, [mats["Rock"]], col, smooth_angle=0)
	return col


def piece_alcove(mats, col):
	# Alcove_R68: one seating alcove spanning two segments (bearings 0..22.5), dressing the greybox exactly:
	#   mouth: board-formed jambs (front R67.4, 0.25 inside the greybox side walls) and a head (y 12-14.2), with a
	#          glowing shadow gap above it and faceted rock (flip-ready) from 14.8 to the slot lid;
	#   inside: board-formed side walls on the greybox side faces (tangent 0.5 from the mouth edges), back wall on the
	#          R80 chords, shade soffit at y 12 with a warm reveal line along the back wall's top;
	#   tiers: three 0.4-thick oak treads (tops 1.5 / 3 / 4.5, the collision tops), 0.2 nosings over board-formed risers,
	#          a warm Neon strip under every nosing; a honed floor strip R70-71.2 in front (the ring floor runs to R70).
	A = 2 * SEG
	s = deg_at(0.5, 71.0)  # side walls stand 0.5 inside the mouth edges
	P = "Alcove_R68"
	# floor strip
	K.add_obj(P + "_Floor", K.arc(70.0, 71.2, s, A - s, -0.4, 0.0, steps=4), [mats["ConcreteDark"]], col, smooth_angle=0)
	risers, treads, glows = bmesh.new(), bmesh.new(), bmesh.new()
	prev = 0.0
	for r0, r1, top in ((71.0, 74.0, 1.5), (74.0, 77.0, 3.0), (77.0, 80.0, 4.5)):
		# The glow sits just IN FRONT of the riser face (toward the axis), 0.2 under the 0.4-thick tread's nosing.
		K.merge(risers, K.lathe([(r0, prev), (r0, top - 0.4)], s, A - s, steps=4))
		K.merge(treads, K.arc(r0 - 0.2, r1, s, A - s, top - 0.4, top, steps=4))
		K.merge(glows, K.arc(r0 - 0.1, r0 - 0.03, s, A - s, top - 0.78, top - 0.62, steps=4))
		prev = top
	K.add_obj(P + "_Risers", risers, [mats["ConcreteBoard"]], col, uvs=polar_uvs(), smooth_angle=0)
	K.add_obj(P + "_Treads", treads, [mats["Oak"]], col, uvs=polar_uvs(), smooth_angle=0, uv_rotate=False)
	K.add_glow(P + "_TierUnder", glows, mats["Glow_Cove"], col)
	# side walls: in the frame of bearing 0, tangent (clockwise) = +X, radial = +Y
	sides = bmesh.new()
	K.merge(sides, K.box(0.0, 0.55, 69.3, 80.4, 0.0, 12.0))
	right = K.box(-0.55, 0.0, 69.3, 80.4, 0.0, 12.0)
	K.merge(sides, rotz(right, A))
	K.add_obj(P + "_Sides", sides, [mats["ConcreteBoard"]], col, smooth_angle=0)
	back = K.lathe([(80.0, 4.5), (80.0, 12.0)], 0.0, A, steps=2)
	K.add_obj(P + "_Back", back, [mats["ConcreteBoard"]], col, uvs=polar_uvs(), smooth_angle=0)
	soffit = K.lathe([(80.0, 12.0), (69.4, 12.0)], 0.0, A, steps=4)
	K.add_obj(P + "_Soffit", soffit, [mats["ConcreteBoardShade"]], col, uvs=polar_uvs(), smooth_angle=0)
	K.add_glow(P + "_BackReveal", K.lathe([(79.85, 11.45), (79.85, 11.62)], s, A - s, steps=2), mats["Glow_Cove"], col)
	# mouth: jambs and head
	jambs = bmesh.new()
	K.merge(jambs, K.cbox(-1.25, 0.75, 67.4, 69.5, 0.0, 14.2, ch=0.25))
	K.merge(jambs, rotz(K.cbox(-0.75, 1.25, 67.4, 69.5, 0.0, 14.2, ch=0.25), A))
	ho = deg_at(1.25, 67.4)
	head = K.arc(67.4, 69.5, -ho, A + ho, 12.0, 14.2, steps=4)
	K.add_obj(P + "_Jambs", jambs, [mats["ConcreteBoard"]], col, uvs=panel_uvs(center_faces=True), smooth_angle=0)
	K.add_obj(P + "_Head", head, [mats["ConcreteBoard"]], col, uvs=polar_uvs(), smooth_angle=0)
	# shadow gap over the head and the rock head above it
	h0, h1 = 14.2, 14.8
	liner = K.lathe([(69.3, h0), (69.3, h1 - 0.05), (68.0, h1 - 0.05)], 0.0, A, steps=4)
	K.add_obj(P + "_GapLiner", liner, [mats["SteelBlack"]], col, smooth_angle=0)
	K.add_glow(P + "_Gap", K.lathe([(69.22, h1 - 0.2), (69.22, h1 - 0.06)], 0.0, A, steps=4), mats["Glow_Cove"], col)
	width = math.radians(A) * R_RING_OUT
	height = ROCK_TOP - h1
	rock = K.rock_face(width, height, 81, cell=2.0, depth=ROCK_DEPTH, relief=ROCK_RELIEF, ledges=3, chips=0.15, row=2.6)
	bend_rock(rock, width, A, R_ROCK_BACK, h1, height=height)
	K.add_obj(P + "_Rock", rock, [mats["Rock"]], col, smooth_angle=0)


# ---------------------------------------------------------------- portals and signs

def frame_mesh(clear, height, thick, deep, top, slot):
	# Ported: a deep portal frame as one closed solid with a recessed title slot spanning the opening.
	bm = bmesh.new()
	hw, ow = clear / 2, clear / 2 + thick
	sw, sz0, sz1, sd = slot
	Ys = [-ow, -hw, hw, ow]
	Zs = [0.0, height, sz0, sz1, top]
	F = [[bm.verts.new((deep, y, z)) for y in Ys] for z in Zs]
	B = [[bm.verts.new((0.0, y, z)) for y in Ys] for z in Zs]
	hole = (0, 1)
	recess = (2, 1)
	for i in range(4):
		for j in range(3):
			if (i, j) != hole and (i, j) != recess:
				bm.faces.new((F[i][j], F[i][j + 1], F[i + 1][j + 1], F[i + 1][j]))
			if (i, j) != hole:
				bm.faces.new((B[i][j], B[i + 1][j], B[i + 1][j + 1], B[i][j + 1]))
	R = [[bm.verts.new((deep - sd, y, z)) for y in (Ys[1], Ys[2])] for z in (Zs[2], Zs[3])]
	loopF = [F[2][1], F[2][2], F[3][2], F[3][1]]
	loopR = [R[0][0], R[0][1], R[1][1], R[1][0]]
	for k in range(4):
		bm.faces.new((loopF[k], loopF[(k + 1) % 4], loopR[(k + 1) % 4], loopR[k]))
	bm.faces.new(loopR)
	for i in range(4):
		bm.faces.new((F[i][0], F[i + 1][0], B[i + 1][0], B[i][0]))
		bm.faces.new((F[i][3], B[i][3], B[i + 1][3], F[i + 1][3]))
	for j in range(3):
		bm.faces.new((F[4][j], F[4][j + 1], B[4][j + 1], B[4][j]))
	for j in (0, 2):
		bm.faces.new((F[0][j], B[0][j], B[0][j + 1], F[0][j + 1]))
	bm.faces.new((F[0][1], F[1][1], B[1][1], B[0][1]))
	bm.faces.new((F[0][2], B[0][2], B[1][2], F[1][2]))
	bm.faces.new((F[1][1], F[1][2], B[1][2], B[1][1]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	for f in bm.faces:
		c = f.calc_center_median()
		f.material_index = 1 if (abs(c.x - (deep - sd)) < 1e-4 and f.normal.x > 0.9) else 0
	return bm


def piece_portal(mats, col, name, clear, deep, sill_back):
	# PortalFrame_26 / _52: deep board-formed frame (3-thick jambs, 0.25 chamfers) cut into the rock, the head running
	# up to the slot lid (31.5) with a 0.6-deep title slot; a black-steel pelmet under the head soffit 1.2 behind the
	# front with a warm Neon strip tight behind it (it carries the portal's one SurfaceLight in Studio), two V reveals
	# on the jambs' front faces, and a threshold sill: honed slab with a brushed nosing, 0.05 proud of the floors.
	z0, z1, sd = SLOT
	bm = frame_mesh(clear, PORTAL_H, FRAME_T, deep, ROCK_TOP, (clear / 2, z0, z1, sd))
	K.bevel(bm, 0.25, segs=1, angle=30)
	width = clear + 2 * FRAME_T
	K.add_obj(name + "_Frame", bm, [mats["ConcreteBoard"], mats["ConcreteBoardShade"]], col, uvs=panel_uvs(width=width, v_shift=3.2), smooth_angle=0)
	hw = clear / 2
	px = deep - 1.2
	K.add_obj(name + "_Pelmet", K.cbox(px - 0.15, px, -hw, hw, PORTAL_H - 0.8, PORTAL_H + 0.02, ch=0.03), [mats["SteelBlack"]], col)
	K.add_glow(name + "_Soffit", K.glow_strip(px - 0.29, px - 0.17, -hw + 0.3, hw - 0.3, PORTAL_H - 0.15, PORTAL_H), mats["Glow_Cove"], col)
	# Jamb reveals: a black-steel inlay line up each jamb face toward the opening (the frame's only accent line).
	rev = bmesh.new()
	for s in (-1, 1):
		y = s * (hw + 0.6)
		K.merge(rev, K.box(deep - 0.02, deep + 0.03, y - 0.06, y + 0.06, 0.3, PORTAL_H - 0.3))
	K.add_obj(name + "_Reveal", rev, [mats["SteelBlack"]], col, smooth_angle=0)
	sill = K.cbox(sill_back, deep - 0.15, -hw, hw, -0.3, 0.05, ch=0.0)
	nose = K.box(deep - 0.15, deep, -hw, hw, -0.3, 0.05)
	K.add_obj(name + "_Sill", sill, [mats["ConcreteHoned"]], col, smooth_angle=0)
	K.add_obj(name + "_SillNosing", nose, [mats["SteelBrushed"]], col, smooth_angle=0)


def sign_frame(prefix, mats, col, w, h, depth=0.5, edge=0.4, strip=0.3, back=True, glow="Glow_Cove", x0=0.0):
	# Sign frame family: 0.4 black-steel bezel around a w x h panel area, a charcoal backing plate (the SurfaceGui part
	# sits in front of it in Studio) and a 0.3 Neon edge strip along the bottom inside the bezel (zone / mode colour,
	# recoloured with tint() in Studio). Kit space: back at x = x0, faces +X, centred on y, bottom at z = 0.
	fr = bmesh.new()
	x1 = x0 + depth
	K.merge(fr, K.cbox(x0, x1, -w / 2, w / 2, h - edge, h, ch=0.08))
	K.merge(fr, K.cbox(x0, x1, -w / 2, w / 2, 0, edge, ch=0.08))
	K.merge(fr, K.cbox(x0, x1, -w / 2, -w / 2 + edge, edge - 0.05, h - edge + 0.05, ch=0.08))
	K.merge(fr, K.cbox(x0, x1, w / 2 - edge, w / 2, edge - 0.05, h - edge + 0.05, ch=0.08))
	K.add_obj(prefix + "_Frame", fr, [mats["SteelBlack"]], col)
	if back:
		K.add_obj(prefix + "_Backing", K.box(x0, x0 + 0.2, -w / 2 + edge, w / 2 - edge, edge, h - edge), [mats["SignPanel"]], col)
	if strip:
		K.add_glow(prefix + "_Strip", K.glow_strip(x0 + 0.2, x0 + 0.42, -w / 2 + edge, w / 2 - edge, edge, edge + strip), mats[glow], col)


def piece_title_band(mats, col, name, w, h=10.0):
	# TitleBand_26 / _40: wall-mounted (origin at the bottom centre of the back face, facing +X), hangs in a portal's
	# title slot. The title SurfaceGui panel goes on x 0.2-0.3, z 0.7-9.6.
	sign_frame(name, mats, col, w, h)


def piece_leaderboard_frame(mats, col):
	# LeaderboardFrame: black-steel bezel for the double-sided 18 x 13.5 x 0.3 greybox board (y 12-25.5, centred on
	# x 0): 0.45 members 0.6 deep standing 0.15 proud of both screen faces, a 0.05 lip over the screen edge, a thin
	# brushed top cap, two hanger rods up to the ring beam soffit (27.75) with clamp plates, and a cool Neon line
	# along the bottom edge on both faces (the screens' own glow).
	w, h, zb = 18.0, 13.5, 12.0
	e = 0.45
	d = 0.3
	fr = bmesh.new()
	K.merge(fr, K.cbox(-d, d, -w / 2 - e, w / 2 + e, zb + h - 0.05, zb + h + e, ch=0.08))
	K.merge(fr, K.cbox(-d, d, -w / 2 - e, w / 2 + e, zb - e, zb + 0.05, ch=0.08))
	K.merge(fr, K.cbox(-d, d, -w / 2 - e, -w / 2 + 0.05, zb, zb + h, ch=0.08))
	K.merge(fr, K.cbox(-d, d, w / 2 - 0.05, w / 2 + e, zb, zb + h, ch=0.08))
	hang = bmesh.new()
	for y in (-6.0, 6.0):
		K.merge(hang, K.cyl(0.0, y, 0.11, zb + h + e, 27.85, segs=8))
		K.merge(hang, K.cbox(-0.25, 0.25, y - 0.4, y + 0.4, zb + h + e, zb + h + e + 0.18, ch=0.04))
		K.merge(hang, K.cbox(-0.35, 0.35, y - 0.35, y + 0.35, 27.55, 27.8, ch=0.04))
	cap = K.box(-d - 0.02, d + 0.02, -w / 2 - e, w / 2 + e, zb + h + e - 0.06, zb + h + e + 0.01)
	glow = bmesh.new()
	for s in (-1, 1):
		x0, x1 = (d, d + 0.06) if s > 0 else (-d - 0.06, -d)
		K.merge(glow, K.box(x0, x1, -w / 2 + 0.6, w / 2 - 0.6, zb - 0.32, zb - 0.2))
	K.add_obj("LeaderboardFrame_Bezel", fr, [mats["SteelBlack"]], col)
	K.add_obj("LeaderboardFrame_Hangers", K.group(hang, cap), [mats["SteelBrushed"]], col)
	K.add_glow("LeaderboardFrame_Edge", glow, mats["Glow_Cool"], col)
	# Ring side (fix pass): the back face only carries the two wing arrows, so a charcoal plate covers its lower
	# 8.4 studs (two reveal lines), a black-steel mullion caps it at z 20.45-20.75, and a wing-colour line sits on the
	# mullion under each arrow (BackPosY = the ring walker's left, BackNegY = right; recoloured in Studio).
	zm = 20.45
	plate = K.box(-0.24, -0.18, -w / 2, w / 2, zb + 0.05, zm)
	K.add_obj("LeaderboardFrame_BackPlate", plate, [mats["SignPanel"]], col)
	mull = K.cbox(-0.32, -0.16, -w / 2, w / 2, zm, zm + 0.3, ch=0.03)
	for z in (15.2, 17.9):
		K.merge(mull, K.box(-0.27, -0.23, -w / 2, w / 2, z - 0.05, z + 0.05))
	K.add_obj("LeaderboardFrame_Mullion", mull, [mats["SteelBlack"]], col)
	K.add_glow("LeaderboardFrame_BackPosY", K.glow_strip(-0.38, -0.32, 1.8, w / 2 - 0.6, zm + 0.08, zm + 0.22), mats["Glow_Cool"], col)
	K.add_glow("LeaderboardFrame_BackNegY", K.glow_strip(-0.38, -0.32, -w / 2 + 0.6, -1.8, zm + 0.08, zm + 0.22), mats["Glow_Cool"], col)


def piece_pier_plaque(mats, col):
	# PierPlaque: a steel plaque frame for the 15 x 3 greybox sign (y 9-12) on a pier's inner face. Straight piece:
	# origin on the floor at the pier face, facing +X; bezel 0.5 deep (the sign sits at x 0.05-0.35 inside it), a
	# black-steel back plate where the plaque overhangs the 3-wide pier, and a Neon strip on the bottom member.
	w, h, zb = 15.0, 3.0, 9.0
	e = 0.35
	fr = bmesh.new()
	K.merge(fr, K.cbox(0.0, 0.5, -w / 2 - e, w / 2 + e, zb + h, zb + h + e, ch=0.06))
	K.merge(fr, K.cbox(0.0, 0.5, -w / 2 - e, w / 2 + e, zb - e, zb, ch=0.06))
	K.merge(fr, K.cbox(0.0, 0.5, -w / 2 - e, -w / 2, zb, zb + h, ch=0.06))
	K.merge(fr, K.cbox(0.0, 0.5, w / 2, w / 2 + e, zb, zb + h, ch=0.06))
	K.merge(fr, K.box(0.0, 0.05, -w / 2, w / 2, zb, zb + h))
	K.add_obj("PierPlaque_Frame", fr, [mats["SteelBlack"]], col)
	K.add_glow("PierPlaque_Strip", K.glow_strip(0.5, 0.54, -w / 2 + 0.2, w / 2 - 0.2, zb - 0.24, zb - 0.11), mats["Glow_Cove"], col)


# ---------------------------------------------------------------- contact sheet

def contact_sheet(pieces, path, samples=16, tile=(400, 300), cols=5):
	import numpy as np
	sc = bpy.context.scene
	K.render_settings(samples=samples)
	sc.eevee.use_raytracing = False
	w = sc.world or bpy.data.worlds.new("World")
	sc.world = w
	w.use_nodes = True
	bg = w.node_tree.nodes.get("Background")
	bg.inputs[0].default_value = (0.32, 0.34, 0.38, 1)
	bg.inputs[1].default_value = 1.0
	stage = K.collection("Stage")
	ld = bpy.data.lights.new("SheetSun", "SUN")
	ld.energy = 3.0
	ld.angle = math.radians(5)
	sun = bpy.data.objects.new("SheetSun", ld)
	stage.objects.link(sun)
	sun.rotation_euler = (math.radians(50), 0, math.radians(35))
	lc = bpy.context.view_layer.layer_collection
	tiles = []
	tmp = os.path.join(K.ART_DIR, "_tmp_contact")
	os.makedirs(tmp, exist_ok=True)
	label_mat = bpy.data.materials["SignText"]
	for idx, (name, col) in enumerate(pieces):
		for n2, c2 in pieces:
			lc.children[c2.name].exclude = c2 is not col
		pts = []
		for ob in col.all_objects:
			if ob.type == "MESH":
				pts += [ob.matrix_world @ v.co for v in ob.data.vertices]
		lo = Vector([min(p[i] for p in pts) for i in range(3)])
		hi = Vector([max(p[i] for p in pts) for i in range(3)])
		c = (lo + hi) / 2
		rad = (hi - lo).length / 2
		cxy = Vector((c.x, c.y, 0))
		if cxy.length > 8:  # round piece: look from the circle centre side
			d = -cxy.normalized()
			d = (d + K.bearing_dir(math.degrees(math.atan2(d.x, d.y)) + 90) * 0.5).normalized()
		else:
			d = Vector((1.0, -0.55, 0.0)).normalized()
		up = 0.55
		if name in ("DomeCoffer_R44", "RingCeiling_R44_68", "OculusRim_R16"):
			up = -0.6
		if name in ("RotundaFloor", "RingFloor_R44_68", "SpawnDais"):
			up = 1.2
		d = Vector((d.x, d.y, up)).normalized()
		lens = 35.0
		fov = 2 * math.atan(18.0 * tile[1] / tile[0] / lens)  # vertical field of view
		dist = rad / math.tan(fov / 2) * 1.0
		cam = K.camera(tuple(c + d * dist), tuple(c), lens=lens, name="Cam_%s" % name, col=stage)
		cam.data.clip_end = 5000
		lab = K.text("%d %s  %d tris" % (idx + 1, name, K.tri_count(col)), 0.035, (0.0, -0.33, -1.0), stage, label_mat, name="Label_%s" % name, font=K.FONT_LABEL)
		lab.parent = cam
		lab.rotation_euler = (0, 0, 0)
		for o in stage.objects:
			if o.name.startswith("Label_"):
				o.hide_render = o is not lab
		sc.camera = cam
		p = os.path.join(tmp, "t%02d.png" % idx)
		sc.render.image_settings.file_format = "PNG"
		sc.render.resolution_x, sc.render.resolution_y = tile
		sc.render.resolution_percentage = 100
		sc.render.filepath = p
		bpy.ops.render.render(write_still=True)
		img = bpy.data.images.load(p)
		a = np.empty(tile[0] * tile[1] * 4, dtype=np.float32)
		img.pixels.foreach_get(a)
		tiles.append(a.reshape(tile[1], tile[0], 4))
		bpy.data.images.remove(img)
		os.remove(p)
	for n2, c2 in pieces:
		lc.children[c2.name].exclude = False
	rows = (len(tiles) + cols - 1) // cols
	blank = np.zeros((tile[1], tile[0], 4), dtype=np.float32)
	blank[..., 3] = 1
	grid = []
	for r in range(rows):
		row = [tiles[r * cols + k] if r * cols + k < len(tiles) else blank for k in range(cols)]
		grid.append(np.concatenate(row, axis=1))
	sheet = np.concatenate(grid[::-1], axis=0)  # Blender pixel rows run bottom-up
	out = bpy.data.images.new("Contact", tile[0] * cols, tile[1] * rows)
	out.pixels.foreach_set(np.ascontiguousarray(sheet).ravel())
	out.filepath_raw = path
	out.file_format = "JPEG"
	out.save()
	try:
		os.rmdir(tmp)
	except OSError:
		pass


# ---------------------------------------------------------------- main

def main():
	t0 = time.time()
	mats = K.begin()
	# Fix pass: the sun inlay / dais top tone (#D6CEC0): #F2EADB clipped to white under the sunbeam in Studio.
	mats["ConcretePolishedSun"] = K._concrete_polished("ConcretePolishedSun", 0xD6CEC0, rough=(0.2, 0.34))
	pieces = []

	def add(name, fn, *a):
		col = K.collection("Lobby_" + name)
		fn(mats, col, *a)
		pieces.append((name, col))

	add("RotundaPier", piece_pier)
	add("RotundaColumn", piece_column)
	add("RingBeam_R44", piece_ring_beam)
	add("Drum_R44", piece_drum)
	add("DomeCoffer_R44", piece_dome)
	add("OculusRim_R16", piece_oculus)
	add("SpawnDais", piece_dais)
	add("RotundaFloor", piece_rotunda_floor)
	add("RingFloor_R44_68", piece_ring_floor)
	add("RingCeiling_R44_68", piece_ring_ceiling)
	add("RockPlinth_R68", piece_rock_plinth)
	for v, seed in (("A", 68), ("B", 71), ("C", 75)):
		pieces.append(("RockWall_R68_" + v, piece_rock_wall(mats, v, seed)))
	add("Alcove_R68", piece_alcove)
	add("PortalFrame_26", piece_portal, "PortalFrame_26", CLEAR_26, DEEP_26, 0.0)
	add("PortalFrame_52", piece_portal, "PortalFrame_52", CLEAR_52, DEEP_52, SILL_BACK_52)
	add("TitleBand_26", piece_title_band, "TitleBand_26", 26.0)
	add("TitleBand_40", piece_title_band, "TitleBand_40", 40.0)
	add("LeaderboardFrame", piece_leaderboard_frame)
	add("PierPlaque", piece_pier_plaque)

	worst = 0
	for name, col in pieces:
		n = K.tri_count(col)
		for ob in col.all_objects:
			if ob.type == "MESH":
				ob.data.calc_loop_triangles()
				worst = max(worst, len(ob.data.loop_triangles))
		print("TRIS %-22s %5d" % (name, n))
	assert worst < 10000, "a mesh object is over 10K tris"
	blend = K.save("Kit_Hub")
	print("KIT_HUB saved", blend, "%.1fs" % (time.time() - t0))
	if "--no-render" in ARGS:
		return
	samples = int(ARGS[ARGS.index("--samples") + 1]) if "--samples" in ARGS else 16
	contact_sheet(pieces, os.path.join(K.RENDER_DIR, "contact-hub.jpg"), samples=samples)
	print("KIT_HUB contact sheet %.1fs" % (time.time() - t0))


main()
