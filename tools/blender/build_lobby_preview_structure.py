# build_lobby_preview_structure.py: the Lobby kit STRUCTURE preview (vault/02 Art/Lobby Kit.md, "Preview renders").
#
# A believable slice of the Sunwell Bunker hub at real scale, built from kit-ready pieces. Every piece is modelled ONCE
# in its own collection Lobby_<Piece> (under "Kit", excluded from the view layer) with the origin the importer expects:
#   round pieces    at the circle's centre on the floor, segment from bearing 0 to 11.25 (plan radii R44 / R68 / R16)
#   straight pieces on the floor at the centre of the back face, facing +X (PortalFrame_26, RotundaPier)
#   wall-mounted    TitleBand: bottom centre of the back face (it hangs at y 17 in the portal's title slot)
#   props           on the floor at the centre (RotundaColumn)
# and the "Preview" collection places them the way the game will: collection instances rotated in 11.25 degree steps
# (shared meshes, like MeshParts sharing a MeshId), so the whole round core shows from a handful of meshes.
#
# Pieces (Lobby Kit, Structure):
#   RotundaPier, RotundaColumn, RingBeam_R44, Drum_R44 (+ cornice cove: a 0.6 steel lip hiding the Neon), DomeCoffer_R44
#   (3 stepped coffers, darker insides), OculusRim_R16 (knife-edge steel lip, 8 spokes, Neon halo ring), SpawnDais
#   (brass compass rose, north arrow to Duels, oak band, steel rim), RotundaFloor (polished disc + sun hot-spot inlay),
#   RingFloor_R44_68 (honed dark + oak slide band R54-58 between brushed steel strips), RingCeiling_R44_68 (one plain
#   coffer per segment in the shade colour, perimeter slot lid), RockWall_R68 (variants A/B/C: two-scale faceted rock
#   with 5 strata benches above a honed plinth and the glowing shadow gap), PortalFrame_26 (deep board-formed frame
#   with a title slot and a soffit cove behind a pelmet) and TitleBand_26 (steel-framed charcoal band; the text is a
#   SurfaceGui stand-in).
#
# Light (Lobby Art Plan + art review): Neon only glows (lobbykit emits it to camera rays only), and only two Neon lines
# stay visible: the oculus halo and the rock shadow gap. Every wash is a named, shadowless Roblox
# light (K.rbx_light; the build prints the count): the rim SpotLight on the dais, a SurfaceLight bounce from the dais,
# 8 cornice SurfaceLights on the coffers, 16 slot SurfaceLights on the rock, 1 soffit SurfaceLight per portal. The sun
# is the only shadow caster; it falls through the oculus onto the dais, with 4 fake Beam ribbons from the oculus.
# Preview stand-ins: the lifted world light (Roblox Ambient must be raised to match) and the detail sheet's fill keys.
# A 5-stud mannequin stands on the dais and one on the oak band.
#
# Run (headless):
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
#       --python tools/blender/build_lobby_preview_structure.py -- [--no-render] [--samples N] [--quick]
#       [--only hero|detail] [--out <jpg>] [--out-detail <jpg>] [--cam bearing r z aim lens shift]
#       [--amb/--bounce/--beam/--wash/--cornice/--soffit/--fill-detail <energy>] [--avatar-b <bearing>]
# Writes art-source/lobby/PreviewStructure.blend, vault/02 Art/References/lobby/kit/structure.jpg and
# structure-detail.jpg (three close-ups: pier base, plinth + shadow gap, portal jamb meeting the rock).

import math, os, sys, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
import lobbykit as K  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default, cast=float):
	return cast(ARGS[ARGS.index(name) + 1]) if name in ARGS else default


AMB_WORLD = arg("--amb", 4.0)
AMB_KEY = arg("--key", 1.0)
AMB_FILL = arg("--fill", 1.0)
BOUNCE = arg("--bounce", 20000.0)
BEAM = arg("--beam", 0.24)
WASH = arg("--wash", 1400.0)
CORNICE = arg("--cornice", 1500.0)
SOFFIT = arg("--soffit", 600.0)
HERO = tuple(float(v) for v in ARGS[ARGS.index("--cam") + 1:ARGS.index("--cam") + 7]) if "--cam" in ARGS else (164.0, 64.0, 6.5, 14.0, 19.0, 0.2)
FILL_DETAIL = arg("--fill-detail", 900.0)  # detail sheet: preview fill key per close-up (no exposure lift)
SEG = K.SEG  # 11.25

# Plan numbers (Lobby Art Plan, Zones; greybox Hub.luau).
R_ROT = 44.0  # rotunda / colonnade radius
R_RING_OUT = 68.0  # ring rock wall face
R_OCULUS = 16.0
Y_COLONNADE = 28.0  # ring beam bottom = ring ceiling soffit
Y_BEAM_TOP = 31.0
Y_DRUM_TOP = 46.0
Y_RIM = 54.0  # dome meets the oculus rim
Y_SKY = 60.0
PLINTH_H, GAP_H = 1.5, 0.6
ROCK_TOP = 31.5  # rock runs up behind the ceiling slot to the slot lid
CEIL_EDGE = 66.5  # ring ceiling stops here: the perimeter slot is 66.5..68
PORTAL_CLEAR = 2 * R_RING_OUT * math.sin(math.radians(SEG))  # 26.53: chord of two segments at R68
PORTAL_H = 16.0
# The frame front stands 2 in front of the chord (66.70): the rock bulges up to 0.7 in front of R68, and at the
# jambs' outer edge the arc is already 0.7 in front of the chord, so this keeps the frame proud of every facet.
PORTAL_FRONT = R_RING_OUT * math.cos(math.radians(SEG)) - 2.0  # 64.70
FRAME_T, FRAME_D = 3.0, 6.0  # Lobby Kit trims: portal frames 3 thick x 6 deep
PELMET_X = FRAME_D - 1.2  # portal soffit cove: the pelmet's front face (kit x), 1.2 behind the frame's front
WEAPONS_B = 90.0  # the portal in this slice (bearing)
AVATAR_BAND_B = arg("--avatar-b", 112.0)  # bearing of the scale mannequin on the oak band


def deg_at(width, r):
	# Angle (degrees) a width in studs takes at radius r.
	return math.degrees(width / r)


# ---------------------------------------------------------------- UV helpers (studs)

def polar_uvs(u_per_seg=None, v_of=None, floor_v_of=None):
	# UVs for round pieces built at bearing 0..11.25. Walls facing the axis: U along the arc, V = height (v_of(z)).
	# Floors/soffits: U along the arc, V = radius (floor_v_of(r)). Other faces (segment ends, radial walls): (r, z).
	# u_per_seg: if set, U = (bearing / 11.25) * u_per_seg (so a grid lines up with the segment); else true arc length.
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
	# Box UVs (stud_uvs) in kit space, then line the formwork up with the piece:
	#   width: U on X-facing faces is stretched so a whole number of 3.2 panels spans `width` (seams on its edges)
	#   center_faces: every wall face gets one panel centred on it (narrow piers: one panel per face, tie holes
	#   inside); v_shift moves the 6.4 rows so a seam lands where it should.
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


# ---------------------------------------------------------------- pieces (kit space)

def piece_pier(mats, col):
	# RotundaPier 3 x 3 x 28: board-formed shaft with 0.25 chamfers on a black-steel base shoe (0.12 proud) and a
	# recessed steel reveal between them. Straight piece: origin at the floor centre of the back face, faces +X.
	shoe = K.cbox(-0.12, 3.12, -1.62, 1.62, 0.0, 0.9, ch=0.06)
	reveal = K.box(0.15, 2.85, -1.35, 1.35, 0.9, 1.05)
	shaft = K.cbox(0.0, 3.0, -1.5, 1.5, 1.05, Y_COLONNADE, ch=0.25)
	K.add_obj("RotundaPier_Shaft", shaft, [mats["ConcreteBoard"]], col, uvs=panel_uvs(center_faces=True, v_shift=4.0 - 1.05))
	K.add_obj("RotundaPier_Shoe", K.group(shoe, reveal), [mats["SteelBlack"]], col)


def piece_column(mats, col):
	# RotundaColumn: slim black-steel column (dia 1.2) with a brushed base ring and the leaderboard brackets.
	c = K.cyl(0, 0, 0.6, 0.0, Y_COLONNADE, segs=16, ch=0.0)
	base = K.cyl(0, 0, 0.85, 0.0, 0.5, segs=16, ch=0.05)
	cap = K.cyl(0, 0, 0.8, Y_COLONNADE - 0.4, Y_COLONNADE, segs=16, ch=0.05)
	br = bmesh.new()
	for z in (12.0, 25.5):  # leaderboard hangers (y 12-25.5), arms toward the rotunda (+X)
		K.merge(br, K.cbox(0.4, 1.6, -0.15, 0.15, z - 0.5, z, ch=0.04))
	K.add_obj("RotundaColumn_Shaft", K.group(c, cap, br), [mats["SteelBlack"]], col)
	K.add_obj("RotundaColumn_Base", base, [mats["SteelBrushed"]], col)


def piece_ring_beam(mats, col):
	# RingBeam_R44 (R42.5-45.8, y 27.75-31.6): a closed section, so no seam can show from behind. It drops 0.25
	# below the ring ceiling soffit (a crisp reveal) and runs 0.3 on under the ceiling slab, so the slab's faceted
	# inner edge always lands on it. Chamfered soffit edge and a 0.6 upstand along its top. No Neon (art review:
	# the soffit line was one of six parallel light lines that read sci-fi).
	prof = [(45.8, 31.0), (45.8, 27.75), (42.75, 27.75), (42.5, 28.0), (42.5, 31.6), (42.8, 31.6), (42.8, 31.0), (45.8, 31.0)]
	bm = K.lathe(prof, 0.0, SEG)
	uv = polar_uvs(u_per_seg=9.6, v_of=lambda z: z - 28.0 + 1.6, floor_v_of=lambda r, f: r)
	K.add_obj("RingBeam_R44_Beam", bm, [mats["ConcreteBoard"]], col, uvs=uv)


# Drum cornice cove (Drum_R44): a shelf under the dome's springing with a black-steel lip; the Neon lies behind
# the lip (hidden from every eye below) and the wash on the coffers comes from CORNICE_LIGHTS SurfaceLights.
CORNICE_TOP = 44.9  # shelf top
CORNICE_LIP = 0.6
CORNICE_IN = 42.7  # shelf front (lip outer face)
CORNICE_LIGHTS = 8  # one SurfaceLight per pier bay, centred on the piers


def piece_drum(mats, col):
	# Drum_R44 (y 31-46): board-formed, 3 formwork panels per segment (U stretched 8.64 -> 9.6, so seams land on
	# the segment joints) with the rows centred on the drum. Cornice cove under the dome's springing (y 46): a
	# board-formed shelf (y 44.3-44.9) projecting to R42.7 with a 0.6 black-steel lip; the warm Neon lies on the
	# shelf behind the lip, so from the floor you see the wash on the lowest coffers, never the tube.
	# The wall runs 0.6 on up behind the dome wedges' springing edge (hidden in their shell), closing that seam.
	ct, ci = CORNICE_TOP, CORNICE_IN
	prof = [(44.0, 31.0), (44.0, ct - 0.6), (ci, ct - 0.6), (ci, ct), (44.0, ct), (44.0, Y_DRUM_TOP + 0.6)]
	bm = K.lathe(prof, 0.0, SEG)
	uv = polar_uvs(u_per_seg=9.6, v_of=lambda z: z - 31.0 + 5.3)
	K.add_obj("Drum_R44_Wall", bm, [mats["ConcreteBoard"]], col, uvs=uv)
	lip = K.arc(ci, ci + 0.15, 0.0, SEG, ct, ct + CORNICE_LIP)
	K.add_obj("Drum_R44_CoveLip", lip, [mats["SteelBlack"]], col, smooth_angle=0)
	K.add_glow("Drum_R44_Cove", K.arc(ci + 0.2, ci + 0.45, 0.0, SEG, ct, ct + 0.15), mats["Glow_Cove"], col)


def dome_z(r):
	t = max(0.0, min(1.0, (r - R_OCULUS) / (R_ROT - R_OCULUS)))
	return Y_RIM - (Y_RIM - Y_DRUM_TOP) * t ** 1.6


def dome_up(r):
	# Unit normal of the dome soffit pointing up into the shell, as (radial, z).
	t = max(1e-4, min(1.0, (r - R_OCULUS) / (R_ROT - R_OCULUS)))
	dz = -(Y_RIM - Y_DRUM_TOP) * 1.6 * t ** 0.6 / (R_ROT - R_OCULUS)
	v = Vector((-dz, 1.0))
	v.normalize()
	return v


def coffer_shell(rs, rows, h, z_of, up_of, thick, steps, b0=0.0, b1=SEG):
	# A coffered wedge as one closed solid: soffit grid (radial stations rs x 5 bearing stations), stepped coffers in
	# the `rows` (r_a, r_b) cells, a top surface `thick` above, and end/inner/outer faces. Returns (bm, faces by role).
	# h: half rib width (studs) at the segment edges; steps: [(inset, depth)...] of the stepped coffer profile.
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
			# wall up `depth`, then a ledge in by `inset`
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
	# top, ends, inner and outer faces
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
	# DomeCoffer_R44: wedge R16-44 of the shallow dome (y 46 at R44 rising to 54 at R16), 3 rows of two-step coffers
	# (outer cells nearly square), 1.2 radial ribs (0.6 per wedge) and ring ribs. Coffer insides use the shade colour.
	rs = [R_OCULUS, 20.0, 25.0, 26.6, 33.4, 35.0, 42.8, R_ROT]
	rows = [(20.0, 25.0), (26.6, 33.4), (35.0, 42.8)]
	bm = coffer_shell(rs, rows, 0.6, dome_z, dome_up, 2.4, [(0.45, 0.6), (0.0, 0.75)], 0.0, SEG)
	uv = polar_uvs(v_of=lambda z: z)
	K.add_obj("DomeCoffer_R44_Shell", bm, [mats["ConcreteBoard"], mats["ConcreteBoardShade"]], col, uvs=uv, smooth_angle=20)


def piece_oculus(mats, col):
	# OculusRim_R16 (one ring, y 54-60): board-formed shaft, a black-steel knife-edge lip (a 2.7-wide black ring
	# on the soffit tapering up to a sharp edge, so the sky reads as a crisp disc), 8 thin spokes to a small hub at
	# the top, and a warm Neon cove ring on the lip that lights the shaft.
	# The dome wedges' inner faces form the shaft's lower 2.4; this piece carries it on to the sky at y 60.
	shaft = K.lathe([(R_OCULUS, 56.35), (R_OCULUS, Y_SKY)], 0, 360, steps=32)
	lip = K.lathe([(18.6, 53.78), (15.75, 53.78), (16.0, 54.3)], 0, 360, steps=32)
	glow = K.lathe([(15.9, 54.38), (15.9, 54.56)], 0, 360, steps=32)  # a halo ring just above the lip, facing the axis
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
	# SpawnDais dia 24 x 0.5: light hot-spot concrete top, a brass compass rose (alternating brass and black steel
	# points, the long north point aims at Duels), a brass ring, an oak band and a chamfered brushed-steel rim.
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
			vs = [bmt.verts.new(ctr), bmt.verts.new(tip), bmt.verts.new(base)]
			f = bmt.faces.new(vs)
			f.normal_update()
			if f.normal.z < 0:
				f.normal_flip()
	def ring_uv(bm):
		return polar_uvs()(bm)
	K.add_obj("SpawnDais_Top", top, [mats["ConcretePolishedInlay"]], col, smooth_angle=0)
	K.add_obj("SpawnDais_OakBand", oak, [mats["Oak"]], col, uvs=ring_uv, smooth_angle=0)
	K.add_obj("SpawnDais_Rim", rim, [mats["SteelBrushed"]], col, uvs=ring_uv, smooth_angle=50)
	K.add_obj("SpawnDais_CompassRing", ring, [mats["Brass"]], col, smooth_angle=0)
	K.add_obj("SpawnDais_CompassBrass", rose_b, [mats["Brass"]], col, smooth_angle=0)
	K.add_obj("SpawnDais_CompassSteel", rose_d, [mats["SteelBlack"]], col, smooth_angle=0)


def piece_rotunda_floor(mats, col):
	# RotundaFloor (one disc, R44) and the sun hot-spot inlay (R16 around plan (0, -10), Blender (0, 10)), 0.02 proud.
	disc = K.arc(0.0, R_ROT, 0, 360, -1.0, 0.0, steps=64)
	inlay = K.lathe([(0.0, 0.02), (16.0, 0.02)], 0, 360, steps=48, center=(0.0, 10.0))
	K.add_obj("RotundaFloor_Disc", disc, [mats["ConcretePolished"]], col)
	K.add_obj("RotundaFloor_SunInlay", inlay, [mats["ConcretePolishedInlay"]], col, smooth_angle=0)


def piece_ring_floor(mats, col):
	# RingFloor_R44_68: honed dark concrete (saw cuts on a polar grid: radial at the segment joint and mid-segment,
	# rings every 5 from the rotunda edge and from the band), the oak slide band R54-58 (concentric 1-stud boards)
	# between 0.12 brushed-steel strips. The outer band runs on under the plinth to R70.
	bands = [(R_ROT, 54.0, 0), (54.0, 54.12, 2), (54.12, 57.88, 1), (57.88, 58.0, 2), (58.0, 70.0, 0)]
	bm = bmesh.new()
	for r0, r1, m in bands:
		K.merge(bm, K.arc(r0, r1, 0.0, SEG, -1.0, 0.0, mat=m))

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
				if f.material_index == 1:  # oak: grain along the arc, 1-stud boards across
					lp[layer].uv = (math.radians(b) * r, r)
				elif abs(f.normal.z) > 0.7:
					v0 = R_ROT if rc < 54 else 58.0
					lp[layer].uv = (b / SEG * 10.0, r - v0)
				else:
					lp[layer].uv = (math.radians(b) * r, p.z)
		return bm
	K.add_obj("RingFloor_R44_68_Floor", bm, [mats["ConcreteDark"], mats["Oak"], mats["SteelBrushed"]], col, uvs=uv, smooth_angle=0)


def piece_ring_ceiling(mats, col):
	# RingCeiling_R44_68 (soffit y 28, R45.5-66.5): ONE plain 1.5-deep coffer per segment between 2-wide radial ribs
	# (1 per wedge side) and 1.2 ring ribs, all in ConcreteBoardShade so the ring ceiling stays darker and quieter
	# than the dome (art review: two stepped coffers read as stacked beams). A lid closes the perimeter slot (66.5 to
	# the rock); the slot holds the rock-wash SurfaceLights, no Neon.
	rs = [45.5, 46.7, 65.3, CEIL_EDGE]
	rows = [(46.7, 65.3)]
	bm = coffer_shell(rs, rows, 1.0, lambda r: Y_COLONNADE, lambda r: Vector((0.0, 1.0)), 3.5, [(0.0, 1.5)], 0.0, SEG)
	K.merge(bm, K.arc(CEIL_EDGE, 70.5, 0.0, SEG, ROCK_TOP, ROCK_TOP + 0.5, mat=1))
	uv = polar_uvs(v_of=lambda z: z)
	K.add_obj("RingCeiling_R44_68_Slab", bm, [mats["ConcreteBoardShade"], mats["ConcreteBoardShade"]], col, uvs=uv, smooth_angle=0)


def piece_rock_wall(mats, parent):
	# RockWall_R68: plinth 1.5 (front at R68.25, 0.25 behind the wall face) with a brushed nosing, the 0.6 x 0.5
	# shadow gap (black-steel channel, warm Neon tucked into its top back corner), and faceted rock from y 2.1 to the
	# slot lid at 31.5, bent onto R68. The rock's side edges and foot sit exactly on R68, so variants A/B/C tile.
	# The plinth is one continuous honed band (ConcreteHoned) with saw cuts every ~6.7 studs on the segment joints and
	# mid-segment, and a 0.1 x 0.1 brushed nosing standing proud on its top edge, catching the slot wash.
	# The rock (art review): two facet scales (2.4 cells, chips), relief 2.0 and 5 strata breaks (benches catch the
	# slot wash, overhangs give dark lines), lifted albedo #625D57.
	f0 = R_RING_OUT
	h0, h1 = PLINTH_H, PLINTH_H + GAP_H
	# Open lathes: only the faces anyone can see (the backs are buried in the rock), so the tris go to the rock.
	plinth = K.lathe([(f0 + 0.25, 0.0), (f0 + 0.25, h0), (f0 + 0.5, h0)], 0.0, SEG)
	nosing = K.lathe([(f0 + 0.25, h0 - 0.1), (f0 + 0.17, h0 - 0.1), (f0 + 0.17, h0), (f0 + 0.25, h0)], 0.0, SEG)
	liner = K.lathe([(f0 + 0.5, h0), (f0 + 0.5, h1 - 0.05), (f0, h1 - 0.05)], 0.0, SEG)
	glow = K.lathe([(f0 + 0.42, h1 - 0.16), (f0 + 0.42, h1 - 0.04)], 0.0, SEG)
	width = math.radians(SEG) * f0  # 13.35: arc length at R68
	depth, relief = 2.6, 2.0
	r_back = f0 + depth - relief / 2  # foot / edges (held at mid depth) land on R68
	uvp = polar_uvs(v_of=lambda z: z)
	shared = {}
	for v, seed in (("A", 68), ("B", 71), ("C", 75)):
		col = K.collection("RockWall_R68_" + v, parent)
		if not shared:
			shared["Plinth"] = K.add_obj("RockWall_R68_Plinth", plinth, [mats["ConcreteHoned"]], col, uvs=polar_uvs(u_per_seg=10.0, v_of=lambda z: z + 1.75), smooth_angle=0)
			shared["Nosing"] = K.add_obj("RockWall_R68_Nosing", nosing, [mats["SteelBrushed"]], col, uvs=uvp, smooth_angle=0)
			shared["Liner"] = K.add_obj("RockWall_R68_GapLiner", liner, [mats["SteelBlack"]], col, uvs=uvp, smooth_angle=0)
			shared["Glow"] = K.add_glow("RockWall_R68_Gap", glow, mats["Glow_Cove"], col)
		else:
			for ob in shared.values():
				col.objects.link(ob)
		rock = K.rock_face(width, ROCK_TOP - h1, seed, cell=2.0, depth=depth, relief=relief, ledges=5, chips=0.15, row=2.6)
		for vt in rock.verts:
			x, y, z = vt.co
			b = SEG / 2 + y / width * SEG
			r = r_back - x
			p = K.polar(r, b, z + h1)
			vt.co = p
		K.add_obj("RockWall_R68_%s_Rock" % v, rock, [mats["Rock"]], col, smooth_angle=0)


def frame_mesh(clear, height, thick, deep, top, slot):
	# Deep portal frame as one closed solid: jambs `thick` wide each side of a `clear` x `height` opening, a head
	# up to `top`, and a recessed title slot (slot = (half width, z0, z1, depth)) in the head's front face.
	# Kit space: back face x = 0, front face x = deep, centred on y, floor z = 0.
	bm = bmesh.new()
	hw, ow = clear / 2, clear / 2 + thick
	sw, sz0, sz1, sd = slot
	Ys = [-ow, -hw, hw, ow]
	Zs = [0.0, height, sz0, sz1, top]
	F = [[bm.verts.new((deep, y, z)) for y in Ys] for z in Zs]
	B = [[bm.verts.new((0.0, y, z)) for y in Ys] for z in Zs]
	hole = (0, 1)
	recess = (2, 1)
	faces = []
	for i in range(4):
		for j in range(3):
			if (i, j) != hole and (i, j) != recess:
				faces.append(bm.faces.new((F[i][j], F[i][j + 1], F[i + 1][j + 1], F[i + 1][j])))
			if (i, j) != hole:
				faces.append(bm.faces.new((B[i][j], B[i + 1][j], B[i + 1][j + 1], B[i][j + 1])))
	# recess (slot) - the slot spans the opening width
	R = [[bm.verts.new((deep - sd, y, z)) for y in (Ys[1], Ys[2])] for z in (Zs[2], Zs[3])]
	loopF = [F[2][1], F[2][2], F[3][2], F[3][1]]
	loopR = [R[0][0], R[0][1], R[1][1], R[1][0]]
	for k in range(4):
		faces.append(bm.faces.new((loopF[k], loopF[(k + 1) % 4], loopR[(k + 1) % 4], loopR[k])))
	faces.append(bm.faces.new(loopR))
	# outer sides, top, feet
	for i in range(4):
		faces.append(bm.faces.new((F[i][0], F[i + 1][0], B[i + 1][0], B[i][0])))
		faces.append(bm.faces.new((F[i][3], B[i][3], B[i + 1][3], F[i + 1][3])))
	for j in range(3):
		faces.append(bm.faces.new((F[4][j], F[4][j + 1], B[4][j + 1], B[4][j])))
	for j in (0, 2):
		faces.append(bm.faces.new((F[0][j], B[0][j], B[0][j + 1], F[0][j + 1])))
	# opening: jamb insides and head soffit
	faces.append(bm.faces.new((F[0][1], F[1][1], B[1][1], B[0][1])))
	faces.append(bm.faces.new((F[0][2], B[0][2], B[1][2], F[1][2])))
	faces.append(bm.faces.new((F[1][1], F[1][2], B[1][2], B[1][1])))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	# the slot back gets the shade colour
	for f in bm.faces:
		c = f.calc_center_median()
		f.material_index = 1 if (abs(c.x - (deep - sd)) < 1e-4 and f.normal.x > 0.9) else 0
	return bm


def piece_portal(mats, col):
	# PortalFrame_26: opening 26.53 (two segments' chord at R68) x 16, 3-thick jambs, 6 deep, the head running up
	# to the slot lid at 31.5; a 0.6-deep title slot 26.53 x 10.5 (y 16.75-27.25) takes the TitleBand.
	# A soffit cove shows the 6-deep throat (art review): a black-steel pelmet hangs 0.8 under the head soffit 1.2
	# behind the front edge, the Neon sits tight behind it (hidden from a 5-stud eye beyond ~2.3 studs, see
	# K.cove_hide_distance) and a SurfaceLight on the strip (PORTAL_SOFFIT_LIGHT) washes the jamb returns and the
	# throat floor.
	bm = frame_mesh(PORTAL_CLEAR, PORTAL_H, FRAME_T, FRAME_D, ROCK_TOP, (PORTAL_CLEAR / 2, 16.75, 27.25, 0.6))
	K.bevel(bm, 0.25, segs=1, angle=30)
	width = PORTAL_CLEAR + 2 * FRAME_T
	K.add_obj("PortalFrame_26_Frame", bm, [mats["ConcreteBoard"], mats["ConcreteBoardShade"]], col, uvs=panel_uvs(width=width, v_shift=3.2), smooth_angle=0)
	hw = PORTAL_CLEAR / 2
	px = PELMET_X
	K.add_obj("PortalFrame_26_Pelmet", K.cbox(px - 0.15, px, -hw, hw, PORTAL_H - 0.8, PORTAL_H + 0.02, ch=0.03), [mats["SteelBlack"]], col)
	K.add_glow("PortalFrame_26_Soffit", K.glow_strip(px - 0.29, px - 0.17, -hw + 0.3, hw - 0.3, PORTAL_H - 0.15, PORTAL_H), mats["Glow_Cove"], col)


def piece_title_band(mats, col, title, sub, w=26.0, h=10.0, cap=4.0):
	# TitleBand_26: 0.4 black-steel frame around a charcoal panel (the SurfaceGui face). Wall-mounted: origin at the
	# bottom centre of its back face, facing +X. Text objects are SurfaceGui stand-ins (preview_only).
	e = 0.4
	frame = bmesh.new()
	K.merge(frame, K.cbox(0, 0.5, -w / 2, w / 2, h - e, h, ch=0.08))
	K.merge(frame, K.cbox(0, 0.5, -w / 2, w / 2, 0, e, ch=0.08))
	K.merge(frame, K.cbox(0, 0.5, -w / 2, -w / 2 + e, e - 0.05, h - e + 0.05, ch=0.08))
	K.merge(frame, K.cbox(0, 0.5, w / 2 - e, w / 2, e - 0.05, h - e + 0.05, ch=0.08))
	panel = K.box(0, 0.38, -w / 2 + e, w / 2 - e, e, h - e)
	K.add_obj("TitleBand_26_Frame", frame, [mats["SteelBlack"]], col)
	K.add_obj("TitleBand_26_Panel", panel, [mats["SignPanel"]], col)
	t = K.text(title, cap / 0.72, (0.39, 0.0, h * 0.58), col, mats["SignText"], rot=(90, 0, 90), name="TitleBand_26_Title")
	s = K.text(sub, 1.2 / 0.72, (0.39, 0.0, h * 0.22), col, mats["SignTextDim"], rot=(90, 0, 90), spacing=1.15, name="TitleBand_26_Sub")
	bpy.context.view_layer.update()
	for ob, maxw in ((t, w - 4.0), (s, w - 6.0)):
		ob.data.align_y = "CENTER"
		dw = ob.dimensions.x
		if dw > maxw:
			ob.data.size *= maxw / dw


# ---------------------------------------------------------------- preview dressing (not kit)

def dressing(mats, col):
	# The Weapons corridor stub behind the portal (low, neutral light, two steel squeeze frames), the sky disc above
	# the oculus, and the sun occluder (an invisible roof that keeps the sun to the oculus).
	hw = PORTAL_CLEAR / 2
	x0 = PORTAL_FRONT
	# floor: inner edge follows the R68 arc between the jambs, so it meets RingFloor without overlap
	fl = bmesh.new()
	pts = []
	for i in range(9):
		b = WEAPONS_B - SEG + 2 * SEG * i / 8
		p = K.polar(70.0 - 0.001, b)  # RingFloor runs to R70 under the frame
		pts.append((p.x, p.y))
	pts += [(130.0, -hw - 3), (130.0, hw + 3)]
	pts = [(x, y) for x, y in pts]
	pts.sort(key=lambda q: math.atan2(q[1], q[0] - 100.0))
	top = [fl.verts.new((x, y, 0.0)) for x, y in pts]
	fl.faces.new(top)
	K.add_obj("Weapons_Floor", fl, [mats["ConcreteDark"]], col, smooth_angle=0)
	xb = x0 + FRAME_D
	for s in (-1, 1):
		K.add_obj("Weapons_Wall%+d" % s, K.box(xb - 0.5, 130.0, s * hw if s > 0 else -hw - 1.0, hw + 1.0 if s > 0 else -hw, 0.0, PORTAL_H), [mats["ConcreteBoard"]], col)
	K.add_obj("Weapons_Ceiling", K.box(xb - 0.5, 130.0, -hw - 1, hw + 1, PORTAL_H, PORTAL_H + 1.0), [mats["ConcreteBoardShade"]], col)
	for i, x in enumerate((84.0, 98.0)):
		fw, fh, t = 22.5, 13.5, 1.0
		fr = bmesh.new()
		K.merge(fr, K.cbox(x, x + 1.2, -fw / 2 - t, -fw / 2, 0, fh + t, ch=0.1))
		K.merge(fr, K.cbox(x, x + 1.2, fw / 2, fw / 2 + t, 0, fh + t, ch=0.1))
		K.merge(fr, K.cbox(x, x + 1.2, -fw / 2 - t, fw / 2 + t, fh, fh + t, ch=0.1))
		K.add_obj("Weapons_SteelFrame%d" % i, fr, [mats["SteelBlack"]], col)
	# end wall: the armoury beyond, lit by the Weapons zone light (no exposed strips: never show the source)
	K.add_obj("Weapons_EndWall", K.box(126.0, 127.0, -hw, hw, 0, PORTAL_H), [mats["ConcreteBoard"]], col)


def sky(col):
	# Sky disc seen through the oculus (camera-only emissive card; Roblox: the skybox).
	m = bpy.data.materials.new("Sky_Preview")
	m["preview_only"] = True
	m.use_nodes = True
	nt = m.node_tree
	nt.nodes.clear()
	out = nt.nodes.new("ShaderNodeOutputMaterial")
	em = nt.nodes.new("ShaderNodeEmission")
	em.inputs["Color"].default_value = (*K.lin(0xBFD9F2), 1)
	em.inputs["Strength"].default_value = 2.2
	nt.links.new(em.outputs[0], out.inputs["Surface"])
	bm = K.box(-400, 400, -400, 400, 160, 161)
	ob = K.add_obj("Sky", bm, [m], col, uvs=None)
	ob.visible_shadow = False
	ob.visible_diffuse = False
	ob["preview_only"] = True
	return ob


# ---------------------------------------------------------------- assembly

def portal_matrix(b, front):
	# Straight piece facing the rotunda centre, its front face on `front` (radius) at bearing b.
	d = K.bearing_dir(b)
	back = d * (front + FRAME_D)
	return Matrix.Translation(back) @ Matrix.Rotation(math.radians(270 - b), 4, "Z")


def assemble(kit, preview):
	inst = K.place_instance
	for k in range(8):
		b = 22.5 + 45.0 * k
		d = K.bearing_dir(b)
		m = Matrix.Translation(d * (R_ROT + 1.5)) @ Matrix.Rotation(math.radians(270 - b), 4, "Z")
		inst(kit["RotundaPier"], m, "Pier_%d" % k, preview)
	for k in range(4):
		b = 45.0 + 90.0 * k
		d = K.bearing_dir(b)
		m = Matrix.Translation(d * R_ROT) @ Matrix.Rotation(math.radians(270 - b), 4, "Z")
		inst(kit["RotundaColumn"], m, "Column_%d" % k, preview)
	rocks = ["RockWall_R68_A", "RockWall_R68_B", "RockWall_R68_C"]
	for k in range(32):
		b = k * SEG
		m = K.seg_matrix(b)
		for name in ("RingBeam_R44", "Drum_R44", "DomeCoffer_R44", "RingFloor_R44_68", "RingCeiling_R44_68"):
			inst(kit[name], m, "%s_%02d" % (name, k), preview)
		mid = b + SEG / 2
		if abs(mid - WEAPONS_B) < SEG:
			continue  # the portal replaces these two rock segments
		inst(kit[rocks[k % 3]], m, "RockWall_%02d" % k, preview)
	for name in ("OculusRim_R16", "SpawnDais", "RotundaFloor"):
		inst(kit[name], Matrix.Identity(4), name, preview)
	inst(kit["PortalFrame_26"], portal_matrix(WEAPONS_B, PORTAL_FRONT), "Portal_Weapons", preview)
	band = portal_matrix(WEAPONS_B, PORTAL_FRONT) @ Matrix.Translation((FRAME_D - 0.6, 0.0, 17.0))
	inst(kit["TitleBand_26"], band, "Title_Weapons", preview)


def lighting(mats, stage):
	world = K.lobby_world("rotunda", center=(0, 0, 0), radius=44.0)
	sun = world["sun"]
	sun.data.angle = math.radians(0.35)
	sun.data.energy = 9.0
	world["key"].data.energy *= AMB_KEY  # shadowless stand-ins for Roblox Ambient / OutdoorAmbient
	world["fill"].data.energy *= AMB_FILL
	# Roblox's Ambient is a flat add that walls don't block; EEVEE's world light is occluded by every wall, so the
	# enclosed hub went black. Lift the lighting-ray world and keep its occlusion local (AO-like), like Roblox.
	for n in bpy.context.scene.world.node_tree.nodes:
		if n.type == "BACKGROUND" and n.inputs[0].is_linked:
			n.inputs[1].default_value = AMB_WORLD
	try:
		bpy.context.scene.eevee.fast_gi_distance = 10.0
	except AttributeError:
		pass
	# Every light below is a real, named, shadowless Roblox light (K.rbx_light, counted by K.light_budget); the
	# Neon strips light nothing. Only the world lift above and the fill keys of the detail sheet are preview stand-ins.
	# Patch bounce: the sun patch is the brightest thing in the room and lights the dome from below. Roblox: a
	# SurfaceLight on the SpawnDais top face (Face Top, Angle 120, Range 60, warm).
	K.rbx_light("SurfaceLight", "SpawnDais_Bounce", (0.0, 8.0, 1.0), BOUNCE, K.L_SUN, face="Top", rbx_range=60, angle=120, target=(0.0, 8.0, 60.0), size=30, col=stage)
	# keep the sun to the oculus: an invisible roof above the shaft with a hole the size of the opening
	K.sun_occluder((0.0, 0.0), 16.3, z=Y_SKY + 0.6, col=stage)
	# Fake beam (4 Roblox Beams): from inside the oculus (y 57, just above the lip) to the patch along the real sun
	# vector (10 deg toward Duels). Two inner ribbons 16 wide at the top to 14 at the floor, brightest at the rim
	# and thinning toward the floor; two wider, fainter ribbons between them give the shaft a soft edge.
	d = K.sun_direction()
	sky_pt = Vector((0.0, 0.0, Y_SKY))
	top = sky_pt + d * ((Y_SKY - 57.0) / -d.z)
	bottom = sky_pt + d * (Y_SKY / -d.z)
	for name, strength in (("Beam_Sun", BEAM), ("Beam_SunSoft", BEAM * 0.45)):
		for n in mats[name].node_tree.nodes:
			if n.type == "MATH" and n.operation == "MULTIPLY" and min(abs(n.inputs[1].default_value - c) for c in (0.12, 0.06)) < 1e-6:
				n.inputs[1].default_value = strength
	K.sun_beam(top, bottom, 8.0, 7.0, mats["Beam_Sun"], stage, planes=2, name="SunBeam_Inner")
	K.sun_beam(top, bottom, 11.0, 10.0, mats["Beam_SunSoft"], stage, planes=2, name="SunBeam_Outer", phase=45.0)
	# Rotunda SpotLight on the rim aimed at the dais (carries the patch on phones without shadows).
	K.rbx_light("SpotLight", "Rim_SunSpot", (0.0, 2.0, Y_RIM - 1.0), 60000, K.L_SUN, rbx_range=60, angle=38, target=(0.0, 9.0, 0.0), spot=38, blend=0.7, size=4.0, col=stage)
	# Drum cornice wash: one SurfaceLight per pier bay on the hidden cove strip (Face Top, Angle 150, Range 24),
	# washing the lowest coffers in scallops centred on the piers.
	for k in range(CORNICE_LIGHTS):
		b = 22.5 + 360.0 / CORNICE_LIGHTS * k
		p = K.polar(CORNICE_IN + 0.32, b, CORNICE_TOP + 0.2)
		t = K.polar(CORNICE_IN - 6.0, b, CORNICE_TOP + 30.0)
		lt = K.rbx_light("SurfaceLight", "Drum_CoveWash_%d" % k, tuple(p), CORNICE, K.L_COVE, face="Top", rbx_range=24, angle=150, target=tuple(t), size=14.0, size_y=0.3, col=stage)
		_lay_along(lt, p, t, b, 14.0, 0.3)
	# Ring rock wash: SurfaceLights in the perimeter slot (Face Bottom of the slot lid, Angle 90, Range 30) aimed down
	# the rock, so the benches catch light. 16 around the ring (one per two segments).
	for k in range(16):
		b = 11.25 + 22.5 * k
		if abs(b - WEAPONS_B) < SEG:
			continue  # the portal stands here (its head runs up to the lid)
		p = K.polar(CEIL_EDGE + 0.6, b, ROCK_TOP - 0.3)
		t = K.polar(R_RING_OUT + 1.2, b, 6.0)
		lt = K.rbx_light("SurfaceLight", "RingSlot_Wash_%02d" % k, tuple(p), WASH, K.L_COVE, face="Bottom", rbx_range=30, angle=90, target=tuple(t), size=24.0, size_y=0.5, col=stage)
		_lay_along(lt, p, t, b, 24.0, 0.5)
	# Portal soffit cove: one SurfaceLight per portal on the hidden strip behind the pelmet (Face Bottom, Angle 120,
	# Range 18): washes the jamb returns and the throat floor so the 6-deep frame reads.
	pm = portal_matrix(WEAPONS_B, PORTAL_FRONT)
	p = pm @ Vector((PELMET_X - 0.23, 0.0, PORTAL_H - 0.2))
	t = pm @ Vector((PELMET_X - 0.23, 0.0, 0.0))
	lt = K.rbx_light("SurfaceLight", "PortalWeapons_SoffitWash", tuple(p), SOFFIT, K.L_COVE, face="Bottom", rbx_range=18, angle=120, target=tuple(t), size=PORTAL_CLEAR - 1.0, size_y=0.3, col=stage)
	_lay_along(lt, p, t, WEAPONS_B, PORTAL_CLEAR - 1.0, 0.3)
	# Weapons zone light (the Weapons wing's own budget): neutral, down the corridor.
	K.rbx_light("SurfaceLight", "Weapons_CorridorLight", (104.0, 0.0, PORTAL_H - 0.6), 3500, K.L_WEAPONS, zone="weapons", face="Bottom", rbx_range=20, angle=120, target=(104.0, 0.0, 0.0), size=30, size_y=10, col=stage)
	return world


def _lay_along(lt, p, t, b, long, short):
	# Aim an area light from p at t and lay its long side along the tangent at bearing b.
	p = Vector(p)
	lt.matrix_world = Matrix.Translation(p) @ (Vector(t) - p).to_track_quat("-Z", "Z").to_matrix().to_4x4()
	tang = K.bearing_dir(b + 90.0)
	lx = lt.matrix_world.to_3x3() @ Vector((1, 0, 0))
	lt.data.size, lt.data.size_y = (long, short) if abs(lx.dot(tang)) > 0.7 else (short, long)


def tri_report(kit_parent):
	rows = []
	for col in kit_parent.children:
		n = K.tri_count(col)
		rows.append((col.name, n))
		for sub in col.children:
			rows.append(("  " + sub.name, K.tri_count(sub)))
	return rows


def detail_sheet(path, cams, samples):
	# Three portrait close-ups side by side (532 x 1000 each, 2-px charcoal gutters) -> one 1600 x 1000 JPEG.
	import numpy as np
	sc = bpy.context.scene
	tiles = []
	tmp_dir = os.path.join(K.ART_DIR, "_tmp")
	os.makedirs(tmp_dir, exist_ok=True)
	fills = []
	for i, (loc, tgt, lens) in enumerate(cams):
		# A photographer's fill key (preview only, not a game light): soft, shadowless, from just above the camera.
		lv, tv = Vector(loc), Vector(tgt)
		side = (tv - lv).cross(Vector((0, 0, 1))).normalized()
		fl = K.light("AREA", "DetailFill%d" % i, tuple(lv + side * 2.0 + Vector((0, 0, 2.5))), FILL_DETAIL, 0xF4F0EA, target=tuple(tv), size=8.0, shadow=False, col=K.collection("Stage"))
		fl["preview_only"] = True
		fills.append(fl)
	for i, (loc, tgt, lens) in enumerate(cams):
		for j, fl in enumerate(fills):
			fl.hide_render = j != i
		K.camera(loc, tgt, lens=lens, name="CamDetail%d" % i)
		p = os.path.join(tmp_dir, "detail_%d.png" % i)
		sc.render.image_settings.file_format = "PNG"
		sc.render.resolution_x, sc.render.resolution_y = 532, 1000
		sc.render.resolution_percentage = 100
		sc.render.filepath = p
		bpy.ops.render.render(write_still=True)
		img = bpy.data.images.load(p)
		a = np.empty(532 * 1000 * 4, dtype=np.float32)
		img.pixels.foreach_get(a)
		a = a.reshape(1000, 532, 4)
		tiles.append(a)
		bpy.data.images.remove(img)
		os.remove(p)
	gut = np.zeros((1000, 2, 4), dtype=np.float32)
	gut[..., :3] = 0.043
	gut[..., 3] = 1.0
	sheet = np.concatenate([tiles[0], gut, tiles[1], gut, tiles[2]], axis=1)
	out = bpy.data.images.new("DetailSheet", 1600, 1000)
	out.pixels.foreach_set(np.ascontiguousarray(sheet).ravel())
	out.filepath_raw = path
	out.file_format = "JPEG"
	sc.render.image_settings.quality = 92
	out.save()
	bpy.data.images.remove(out)
	try:
		os.rmdir(tmp_dir)
	except OSError:
		pass


def main():
	t0 = time.time()
	mats = K.begin()
	kit_parent = K.collection("Kit")
	kit = {}
	builders = [
		("RotundaPier", piece_pier), ("RotundaColumn", piece_column), ("RingBeam_R44", piece_ring_beam),
		("Drum_R44", piece_drum), ("DomeCoffer_R44", piece_dome), ("OculusRim_R16", piece_oculus),
		("SpawnDais", piece_dais), ("RotundaFloor", piece_rotunda_floor), ("RingFloor_R44_68", piece_ring_floor),
		("RingCeiling_R44_68", piece_ring_ceiling), ("PortalFrame_26", piece_portal),
	]
	for name, fn in builders:
		col = K.collection("Lobby_" + name, kit_parent)
		fn(mats, col)
		kit[name] = col
	rock_parent = K.collection("Lobby_RockWall_R68", kit_parent)
	piece_rock_wall(mats, rock_parent)
	for v in "ABC":
		kit["RockWall_R68_" + v] = bpy.data.collections["RockWall_R68_" + v]
	tb = K.collection("Lobby_TitleBand_26", kit_parent)
	piece_title_band(mats, tb, "WEAPONS", "GUNS + LOCKER")
	kit["TitleBand_26"] = tb

	preview = K.collection("Preview")
	assemble(kit, preview)
	dressing(mats, K.collection("Dressing"))
	stage = K.collection("Stage")
	sky(stage)
	world = lighting(mats, stage)
	# Scale: a 5-stud R15 block mannequin on the dais and one on the oak slide band.
	K.avatar((-2.5, 4.0, 0.5), facing=-60.0, col=stage, name="Avatar_Dais")
	K.avatar(tuple(K.polar(56.0, AVATAR_BAND_B, 0.0)), facing=-90.0 - AVATAR_BAND_B + 30.0, col=stage, name="Avatar_Band")
	# Kit masters stay out of the view layer: the Preview instances show them in place.
	bpy.context.view_layer.layer_collection.children["Kit"].exclude = True

	quick = "--quick" in ARGS
	samples = int(ARGS[ARGS.index("--samples") + 1]) if "--samples" in ARGS else (24 if quick else 128)
	K.render_settings(samples=samples)
	K.bloom()  # the kit render policy: threshold 1.2, exposure 0
	# Hero: standing in the ring (eye height 7) between the Range axis and the SE column, level camera with a
	# rising front (shift) so verticals stay straight; aim bearing between the dais and the WEAPONS portal.
	cb, cr, cz, aim, lens, sh = HERO
	cp = K.polar(cr, cb, cz)
	hero = K.camera(tuple(cp), tuple(cp + K.bearing_dir(aim) * 100), lens=lens, name="CamHero", shift=(0.0, sh))
	bpy.context.scene.view_settings.exposure = arg("--exposure", 0.0)

	for name, n in tri_report(kit_parent):
		print("TRIS %-28s %5d" % (name, n))
	K.light_budget()
	blend = K.save("PreviewStructure")
	print("STRUCTURE saved", blend, "%.1fs" % (time.time() - t0))
	if "--no-render" in ARGS:
		return
	only = ARGS[ARGS.index("--only") + 1] if "--only" in ARGS else "all"
	res = (800, 500) if quick else (1600, 1000)
	if only in ("all", "hero"):
		bpy.context.scene.camera = hero
		path = ARGS[ARGS.index("--out") + 1] if "--out" in ARGS else os.path.join(K.RENDER_DIR, "structure.jpg")
		K.render(path, res=res)
		print("STRUCTURE render", path, "%.1fs" % (time.time() - t0))
	if only in ("all", "detail"):
		# 1 pier base (steel shoe, chamfers, one formwork panel per face, the polished / honed floor joint at R44)
		# 2 plinth + glowing shadow gap under the rock, looking along the curved wall
		# 3 the WEAPONS jamb standing proud of the rock, with the plinth and gap dying into its side
		p_pier = K.polar(R_ROT, 112.5, 3.4)
		p_wall = K.polar(R_RING_OUT, 122.0, 3.6)
		p_wall = K.polar(R_RING_OUT, 124.0, 10.0)
		p_jamb = Vector((PORTAL_FRONT + 1.0, -(PORTAL_CLEAR / 2), 6.5))
		cams = [
			(tuple(K.polar(54.0, 122.0, 4.6)), tuple(p_pier), 30.0),
			(tuple(K.polar(54.0, 132.0, 5.0)), tuple(p_wall), 24.0),
			(tuple(K.polar(52.0, 76.0, 5.0)), tuple(p_jamb), 26.0),
		]
		path = ARGS[ARGS.index("--out-detail") + 1] if "--out-detail" in ARGS else os.path.join(K.RENDER_DIR, "structure-detail.jpg")
		bpy.context.scene.view_settings.exposure = arg("--exposure-detail", 0.0)  # close-ups: fill key, not exposure
		detail_sheet(path, cams, samples)
		print("STRUCTURE detail", path, "%.1fs" % (time.time() - t0))


main()
