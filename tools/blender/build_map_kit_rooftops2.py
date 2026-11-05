# build_map_kit_rooftops2.py: the Rooftops2 map kit (vault/01 Design/Maps/Rooftops2.md), one kit group "Kit".
#
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
#       --python tools/blender/build_map_kit_rooftops2.py -- [--render] [--preview]
#
# The Lobby kit language (vault/02 Art/Lobby Style Guide.md) as built for Dockyard2, applied to a sunny city block:
# plaster facades with picture-frame windows, storey bands and a deep cornice; designed roof furniture; a cobalt
# water tank as the landmark; signage plates and painted words for wayfinding. Helpers (RB / RPX / RPY / RPZ, the
# piece and material plumbing, the coplanar audit, renders) come from build_map_kit_dockyard2.py; every material is
# a ROLE (R2_<Role>) from tools/maps/rooftops2_style.py, re-applied in Studio by role.
#
# Piece names and origins are the old Rooftops kit's (tools/blender/build_map_kit_rooftops.py), so the checked
# placements (tools/maps/rooftops2_art.py) drop in. Roblox piece-local coordinates, +Y up:
#   Facade8A/B/C, Facade4   top centre of the wall's front face (y 0 = the roof level), facing +X, 8 / 4 wide along
#                           Z, 72 tall (6 storeys of 12). The wall stops 1 under the roof (the greybox parapet shows
#                           above it); no end caps: columns butt.
#   Plinth8 / Plinth4       street storey of the taller towers: origin at the street, 8 tall, front 0.35 proud.
#   Quoin                   building corner (outward +X and +Z) at the roof level, runs 80 down.
#   Flue                    top centre of an 8 (Z) x 6 (X) shaft, 82 tall.
#   Stair16, Gangway16, PlankRamp16   floor centre of an 8 x 16 footprint, rising 8 toward +Z.
#   Catwalk8                deck top centre of an 8 x 8 flat footbridge (along Z).
#   ACUnit 8x4x7.5 (long along X), Condenser 4x4x3, Skylight 8x4x3, Planter 6x3x7.5, Penthouse 40x8x11 (door +Z),
#   StairHut 6x6x9, LiftHouse 8x8x10, LiftTower 10x8x16, TankHouse 10x10x8, CoolingTower 10x10x8 (doors +X): floor centre.
#   WaterTank               base centre of the 4 legs (4 tall), drum 4.4-14, cap to 16.
#   Billboard22             floor centre between its legs (legs at x +-7), panel 22 x 10 at 9-19, advert on +Z.
#   RoofSign                hut roof centre; legs at z +-2.2, panel 14 (Z) x 10 at 4-14, words on both faces.
#   LetterA / LetterB       letter with its back on z = 0, standing out toward -Z.
#   SpawnSignA / SpawnSignB plate on z = 0 facing +Z (the Penthouse's spawn-court face).
#   DeckWordPIT / WEST / EAST   painted on the roof (top 0.07), letters' tops toward local -Z.
#   StreetLamp              base on the sidewalk, head toward +X. CityA/B/C: base centre, facing +X.

import math, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
for p in (HERE, os.path.join(HERE, "..", "maps")):
	if p not in sys.path:
		sys.path.insert(0, p)
import bpy, bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
import build_map_kit_dockyard2 as D  # noqa: E402
from build_map_kit_dockyard2 import RB, RPX, RPY, RPZ, rcylX, octo, arrow  # noqa: E402
from lobbykit import collection, _flat, _emissive, lathe, ROOT  # noqa: E402
from build_lobby_kit_stylized import finish, merge, xform, T, RZ, rrect  # noqa: E402
from build_lobby_kit_bunker2 import text_mesh, chamfer_path, ring_prism  # noqa: E402
import rooftops2_style as S  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ART = os.path.join(ROOT, "art-source", "maps", "Rooftops2")
BLEND = os.path.join(ART, "Kit_Rooftops2.blend")
RENDER_DIR = os.path.join(ROOT, "vault", "02 Art", "References", "maps", "rooftops2")
BP, BS, BT = S.BEVEL["primary"], S.BEVEL["secondary"], S.BEVEL["tertiary"]
SP, SS, ST = S.SEGMENTS["primary"], S.SEGMENTS["secondary"], S.SEGMENTS["tertiary"]
STREET = -72.0

D.S = S  # D.obj reads S.PALETTE for the Neon check
D.ART = ART
D.RENDER_DIR = RENDER_DIR
M = D.M
piece = D.piece
obj = D.obj


def materials():
	M.clear()
	for role, (hx, rbx, var) in S.PALETTE.items():
		c = int(hx, 16)
		if rbx == "Neon":
			M[role] = _emissive("R2_" + role, c, 6.0)
			continue
		extra = {"rbx_transparency": 0.45} if rbx == "Glass" else {}
		m = _flat("R2_" + role, c, 0.35 if rbx in ("SmoothPlastic", "Glass") else 0.7, rbx=rbx, **extra)
		m["rbx_variant"] = var
		M[role] = m


def frame_ring(w, h, t, cy, x0, x1, r=0.35):
	# A picture-frame ring in the facade plane (Y-Z), extruded along X from x0 to x1, centred z 0, y cy.
	o = rrect(w, h, r, 2, 0.0, cy)
	i = rrect(w - 2 * t, h - 2 * t, max(0.05, r - t * 0.6), 2, 0.0, cy)
	# ring_prism axis "X": pts (y_blender, z) = (-z_roblox, y); rrect gives (u, v) = (z, y) -> mirror u
	o = [(-u, v) for u, v in o][::-1]
	i = [(-u, v) for u, v in i][::-1]
	return finish(ring_prism(o, i, x0, x1, "X"), 0.0, 1)


def shift_z(bm, dz):
	return xform(bm, T(0, -dz, 0))


def open_box(bm, drop_z=True, drop_y=False, drop_back=False):
	# Facade runs butt column to column (and meet the next face under a quoin), so their end caps (Roblox +-Z) never
	# show; dropping them keeps corner columns from sharing planes. drop_y also drops the top and bottom.
	kill = [f for f in bm.faces if (drop_z and abs(f.normal.y) > 0.99) or (drop_y and abs(f.normal.z) > 0.99) or (drop_back and f.normal.x < -0.99)]
	bmesh.ops.delete(bm, geom=kill, context="FACES")
	return bm


# ---------------------------------------------------------------- facades

def facade(name, W, variant):
	c = piece(name, width=W)
	h = W / 2
	# Wall ends 0.01 in (corner facades meet without sharing planes) and 0.3 into the street (under the sidewalk).
	wall = [open_box(RB(-0.6, 0.0, -72.3, -1.0, -h, h), drop_y=True)]
	trim, glass, frames, accent, dark = [], [], [], [], []
	# Overlays sink into the wall, each kind to its own depth, so no two back faces share a plane.
	# Run-long overlays start on the wall face with no back face, so at a corner the two faces' cornices meet on a
	# line instead of overlapping a sliver.
	trim.append(open_box(RB(0.0, 0.55, -2.6, -1.05, -h, h), drop_back=True))  # cornice
	trim.append(open_box(RB(0.0, 0.25, -3.2, -2.6, -h, h), drop_back=True))  # cornice step
	dark.append(open_box(RB(0.0, 0.2, -72.25, -69.2, -h, h), drop_back=True))  # base band
	for k in range(6):
		y0 = -72.0 + 12.0 * k
		if k > 0:
			trim.append(open_box(RB(0.0, 0.12, y0 - 0.25, y0 + 0.25, -h, h), drop_back=True))  # storey band
		cy = y0 + 6.2
		if W == 4 or variant == "B":
			cols = [0.0] if W == 4 else [-1.7, 1.7]
			ww = 1.7 if W == 4 else 1.9
		else:
			cols, ww = [0.0], 3.6
		for zc in cols:
			glass.append(shift_z(RB(-0.11, 0.06, cy - 2.9, cy + 2.9, -ww / 2, ww / 2), zc))
			frames.append(shift_z(frame_ring(ww + 0.7, 6.5, 0.35, cy, -0.08, 0.2), zc))
			trim.append(shift_z(RB(-0.05, 0.35, cy - 3.6, cy - 3.25, -ww / 2 - 0.5, ww / 2 + 0.5), zc))  # sill
			if variant == "C" and k % 2 == 1:
				# a cobalt awning over every other window (the accent, small)
				prof = [(-0.17, cy + 3.5), (1.3, cy + 2.9), (1.3, cy + 3.2), (-0.17, cy + 3.95)]
				accent.append(shift_z(RPZ(prof, -ww / 2 - 0.4, ww / 2 + 0.4, BT, ST), zc))
	obj(c, "Wall", merge(*wall), "Wall")
	obj(c, "Trim", merge(*trim), "Trim")
	obj(c, "Frames", merge(*frames), "Trim")
	obj(c, "Glass", merge(*glass), "Window")
	obj(c, "Base", merge(*dark), "Plinth")
	if accent:
		obj(c, "Awnings", merge(*accent), "Accent")


def p_plinth(name, W):
	c = piece(name, width=W)
	h = W / 2
	# Up to 7.72: the tower facade above starts at 7.7 (its base band at 7.75), so they meet without shared planes.
	obj(c, "Slab", open_box(RB(0.0, 0.35, -0.3, 7.72, -h, h), drop_back=True), "Plinth")
	obj(c, "Cap", open_box(RB(0.05, 0.5, 7.3, 7.69, -h, h)), "Trim")


def p_quoin():
	c = piece("Quoin")
	obj(c, "Pilaster", RB(-0.55, 0.42, -80.0, -3.2, -0.55, 0.42), "Trim")
	obj(c, "Corner", RB(-0.5, 0.62, -3.25, -1.1, -0.5, 0.62), "Trim")


def p_flue():
	c = piece("Flue")
	obj(c, "Wall", RB(-3.0, 3.0, -82.0, -0.8, -4.0, 4.0), "Wall")
	cap = [RB(-3.3, 3.3, -0.85, -0.25, -4.3, 4.3, BS, SS), RB(-2.6, 2.6, -0.3, 0.0, -3.6, 3.6, BT, ST)]
	obj(c, "Cap", merge(*cap), "Trim")
	vents = [RB(-3.08, 3.08, -2.6, -1.6, z - 0.9, z + 0.9, BT, ST) for z in (-2.0, 2.0)]
	obj(c, "Vents", merge(*vents), "Charcoal")
	obj(c, "Band", RB(-3.12, 3.12, -6.0, -5.5, -4.12, 4.12), "Trim")


# ---------------------------------------------------------------- routes

def slope(z):
	return (z + 8.0) / 2.0


def stairs(name, rails=True, rail_role="White", tread_role="Metal"):
	c = piece(name)
	treads, noses = [], []
	for k in range(1, 10):
		z0 = -8 + 1.6 * k
		z1 = min(z0 + 1.6, 7.97)
		top = 0.8 * k - 0.03
		treads.append(RB(-3.3, 3.3, top - 0.28, top, z0, z1, BT, ST))
		noses.append(RB(-3.2, 3.2, top - 0.2, top + 0.02, z0 + 0.04, z0 + 0.3, BT, ST))
	obj(c, "Treads", merge(*treads), tread_role)  # Metal role: lighter than the old charcoal, reads as a walkway
	obj(c, "Nosing", merge(*noses), "Hazard")
	cheek = [(-7.98, -0.1), (-5.4, -0.1), (7.97, 7.2), (7.97, 8.45), (-7.98, 0.5)]
	obj(c, "Stringers", merge(*[RPX(cheek, s * 3.35, s * 3.85, BS, SS) for s in (1, -1)]), "Charcoal")
	if rails:
		rl = []
		for s in (1, -1):
			x0, x1 = s * 3.5, s * 3.72
			pts = [(-7.4, slope(-7.4) + 3.2), (7.9, slope(7.9) + 3.2), (7.9, slope(7.9) + 3.5), (-7.4, slope(-7.4) + 3.5)]
			rl.append(RPX(pts, x0, x1, BT, ST))
			for zp in (-7.0, -1.0, 5.0):
				rl.append(RB(x0, x1, slope(zp) + 0.4, slope(zp) + 3.25, zp - 0.12, zp + 0.12, BT, ST))
		obj(c, "Rails", merge(*rl), rail_role)


def p_plank_ramp():
	c = piece("PlankRamp16")
	planks = []
	for k in range(10):
		z0 = -8 + 1.6 * k + 0.05
		z1 = z0 + 1.5
		y = slope((z0 + z1) / 2) - 0.05
		for s in (-1, 1):
			planks.append(RB(s * 0.1 if s > 0 else -3.6, 3.6 if s > 0 else -0.1, y - 0.3, y - 0.02, z0, min(z1, 7.97), BT, ST))
	obj(c, "Planks", merge(*planks), "Wood")
	beam = [(-7.98, -0.2), (-6.6, -0.2), (7.97, 7.0), (7.97, 7.6), (-7.98, 0.3)]
	obj(c, "Beams", merge(*[RPX(beam, s * 2.4, s * 3.0, BT, ST) for s in (1, -1)]), "Charcoal")


def p_catwalk():
	c = piece("Catwalk8")
	obj(c, "Deck", RB(-3.6, 3.6, -0.32, -0.03, -3.98, 3.98, BT, ST), "Wood")  # round 4: grey deck read unfinished
	beams = [RB(s * 3.6, s * 4.0, -1.0, -0.03, -3.98, 3.98, BT, ST) for s in (1, -1)]
	obj(c, "Beams", merge(*beams), "Charcoal")
	rails = []
	for s in (1, -1):
		rails.append(RB(s * 3.7, s * 3.95, 3.25, 3.5, -3.98, 3.98, BT, ST))
		rails.append(RB(s * 3.7, s * 3.95, 1.55, 1.75, -3.98, 3.98, BT, ST))
		for z in (-3.6, 0.0, 3.6):
			rails.append(RB(s * 3.72, s * 3.93, -0.03, 3.25, z - 0.12, z + 0.12, BT, ST))
	obj(c, "Rails", merge(*rails), "Hazard")


# ---------------------------------------------------------------- roof furniture

def hut(name, W, Dp, H, door="+X", role="Wall", vent=False):
	c = piece(name, width=W, depth=Dp, height=H)
	hx, hz = W / 2, Dp / 2
	obj(c, "Plinth", RB(-hx - 0.25, hx + 0.25, -0.1, 0.9, -hz - 0.25, hz + 0.25, BS, SS), "Plinth")
	obj(c, "Wall", RB(-hx, hx, 0.9, H - 0.9, -hz, hz, BT, ST), role)
	obj(c, "Cornice", merge(RB(-hx - 0.35, hx + 0.35, H - 0.9, H - 0.35, -hz - 0.35, hz + 0.35, BS, SS), RB(-hx - 0.1, hx + 0.1, H - 0.35, H - 0.03, -hz - 0.1, hz + 0.1, BT, ST)), "Trim")
	# a door with a picture frame on the door face
	dw = min(3.2, (Dp if door == "+X" else W) - 1.4)
	if door == "+X":
		obj(c, "Door", RB(hx - 0.05, hx + 0.08, 0.95, 7.0, -dw / 2, dw / 2, BT, ST), "Door")
		obj(c, "DoorFrame", RPZ([(hx, 0.9), (hx + 0.25, 0.9), (hx + 0.25, 7.6), (hx, 7.6)], -dw / 2 - 0.5, dw / 2 + 0.5, BT, ST) if False else frame_door_x(hx, dw), "Trim")
	else:
		obj(c, "Door", RB(-dw / 2, dw / 2, 0.95, 7.0, hz - 0.05, hz + 0.08, BT, ST), "Door")
		obj(c, "DoorFrame", frame_door_z(hz, dw), "Trim")
	if vent:
		obj(c, "Vent", RB(-hx * 0.5, hx * 0.5, H - 0.03, H + 1.2, -hz * 0.5, hz * 0.5, BS, SS), "Metal")
	# Round 2: corner pilasters and a mid band (Trim) so no hut face is one flat plane.
	pil = [RB(sx * hx - 0.45 * (sx > 0) - 0.12 * (sx < 0), sx * hx + 0.12 * (sx > 0) + 0.45 * (sx < 0), 0.95, H - 0.95, sz * hz - 0.45 * (sz > 0) - 0.12 * (sz < 0), sz * hz + 0.12 * (sz > 0) + 0.45 * (sz < 0)) for sx in (1, -1) for sz in (1, -1)]  # square-edged: 45-deg chamfers of opposite corners shared a plane
	obj(c, "Pilasters", merge(*pil), "Trim")
	return c


def frame_door_x(hx, dw):
	parts = [RB(hx, hx + 0.22, 0.9, 7.55, z0, z1, BT, ST) for z0, z1 in ((-dw / 2 - 0.45, -dw / 2), (dw / 2, dw / 2 + 0.45))]
	parts.append(RB(hx, hx + 0.22, 7.0, 7.55, -dw / 2, dw / 2, BT, ST))
	return merge(*parts)


def frame_door_z(hz, dw):
	parts = [RB(x0, x1, 0.9, 7.55, hz, hz + 0.22, BT, ST) for x0, x1 in ((-dw / 2 - 0.45, -dw / 2), (dw / 2, dw / 2 + 0.45))]
	parts.append(RB(-dw / 2, dw / 2, 7.0, 7.55, hz, hz + 0.22, BT, ST))
	return merge(*parts)


def p_penthouse():
	c = hut("Penthouse", 40, 8, 11, door="+Z")
	# a row of picture-frame windows on both long faces, and a cobalt band under the cornice
	win, frames = [], []
	for x in (-15.0, -8.0, 8.0, 15.0):
		for s in (1, -1):
			win.append(RB(x - 1.5, x + 1.5, 3.4, 8.2, s * 3.9, s * 4.06))
			z0, z1 = s * 3.85, s * 4.22
			frames.append(RB(x - 1.85, x + 1.85, 2.95, 3.4, z0, z1, BT, ST))
			frames.append(RB(x - 1.85, x + 1.85, 8.2, 8.65, z0, z1, BT, ST))
			frames.append(RB(x - 1.85, x - 1.5, 3.4, 8.2, z0, z1, BT, ST))
			frames.append(RB(x + 1.5, x + 1.85, 3.4, 8.2, z0, z1, BT, ST))
	obj(c, "Windows", merge(*win), "Window")
	obj(c, "WinFrames", merge(*frames), "Trim")
	obj(c, "Band", RB(-20.08, 20.08, 9.4, 10.0, -4.08, 4.08), "AccentSoft")  # round 6: softer than the tank
	# Round 2: pilasters between the bays, a downpipe at each end and wall vents, so the long faces aren't bare.
	det, pipes = [], []
	for x in (-18.0, -11.5, -4.5, 4.5, 11.5, 18.0):
		for s in (1, -1):
			det.append(RB(x - 0.3, x + 0.3, 0.9, 9.4, s * 3.95, s * 4.3, BT, ST))
	for x in (-19.2, 19.2):
		for s in (1, -1):
			pipes.append(RB(x - 0.18, x + 0.18, 0.9, 9.9, s * 4.05, s * 4.45, BT, ST))
	obj(c, "Pilasters", merge(*det), "Trim")
	# Round 8: a darker wainscot band (0.9-2.6) with a trim cap and a warm glow strip under the cornice along both long
	# faces, so the Penthouse reads in layers from the spawn court (all three round-7 reviewers: blank long faces).
	wain, cap, glow = [], [], []
	for s in (1, -1):
		mids = ((-4.2, -2.4), (2.4, 4.2)) if s > 0 else ((-4.2, 4.2),)  # the +Z face has the door (x +-1.6, frame to 2.05)
		for x0, x1 in ((-17.7, -11.8), (-11.2, -4.8)) + mids + ((4.8, 11.2), (11.8, 17.7)):
			wz0, wz1 = sorted((s * 3.95, s * 4.14))
			wain.append(RB(x0, x1, 0.95, 2.6, wz0, wz1))
			cz0, cz1 = sorted((s * 3.95, s * 4.24))
			cap.append(RB(x0, x1, 2.6, 2.85, cz0, cz1, BT, ST))
		gz0, gz1 = sorted((s * 4.08, s * 4.2))
		glow.append(RB(-17.7, 17.7, 9.05, 9.3, gz0, gz1))
	obj(c, "Wainscot", merge(*wain), "Plinth")
	obj(c, "WainscotCap", merge(*cap), "Trim")
	obj(c, "CoveGlow", merge(*glow), "GlowWarm")
	obj(c, "Pipes", merge(*pipes), "Charcoal")
	vents = [RB(x - 1.2, x + 1.2, 3.1, 4.1, -4.32, -4.05, BT, ST) for x in (-15.0, -8.0, 8.0, 15.0)]  # round 8: above the wainscot
	obj(c, "Vents", merge(*vents), "Metal")
	# Round 5: a cobalt awning over the door (+Z face) and a warm wall lamp each side, so the spawn view has a doorway.
	aw = [(0.0, 8.0), (1.6, 7.5), (1.6, 7.75), (0.0, 8.4)]
	obj(c, "Awning", RPX([(4.0 + z, y) for z, y in aw], -2.6, 2.6, BT, ST), "AccentSoft")
	# Round 6: the end faces (x +-20) were bare: a window pair with frames and a vent on each.
	endw, endf = [], []
	for sx in (1, -1):
		x0, x1 = sorted((sx * 19.96, sx * 20.06))
		for zc in (-1.6, 1.6):
			endw.append(RB(x0, x1, 4.0, 7.6, zc - 1.0, zc + 1.0))
			fx0, fx1 = sorted((sx * 19.9, sx * 20.2))
			endf.append(RB(fx0, fx1, 3.6, 4.0, zc - 1.35, zc + 1.35, BT, ST))
			endf.append(RB(fx0, fx1, 7.6, 8.0, zc - 1.35, zc + 1.35, BT, ST))
			endf.append(RB(fx0, fx1, 4.0, 7.6, zc - 1.35, zc - 1.0, BT, ST))
			endf.append(RB(fx0, fx1, 4.0, 7.6, zc + 1.0, zc + 1.35, BT, ST))
	obj(c, "EndWindows", merge(*endw), "Window")
	obj(c, "EndFrames", merge(*endf), "Trim")
	lamps, glow = [], []
	for x in (-2.6, 2.6):
		lamps.append(RB(x - 0.3, x + 0.3, 5.6, 6.6, 4.05, 4.45, BT, ST))
		glow.append(RB(x - 0.2, x + 0.2, 5.75, 6.45, 4.45, 4.55))
	obj(c, "WallLamps", merge(*lamps), "Charcoal")
	obj(c, "WallLampGlow", merge(*glow), "GlowWarm")


def p_ac():
	c = piece("ACUnit")
	obj(c, "Curb", RB(-4.0, 4.0, -0.1, 0.6, -2.0, 2.0, BS, SS), "Charcoal")
	obj(c, "Body", RB(-3.8, 3.8, 0.6, 7.2, -1.8, 1.8, 0.3, SS), "Metal")
	# Round 2: a charcoal seam at mid height and corner posts, so the unit reads as two stacked machines, not a wall.
	obj(c, "Seam", merge(RB(-3.86, 3.86, 3.7, 4.1, -1.86, 1.86), *[RB(sx * 3.8 - 0.2, sx * 3.8 + 0.2, 0.6, 7.25, sz * 1.8 - 0.2, sz * 1.8 + 0.2) for sx in (1, -1) for sz in (1, -1)]), "Charcoal")
	ribs = [RB(x - 0.35, x + 0.35, y0, y1, s * 1.8 - 0.08, s * 1.8 + 0.08, BT, ST) for x in (-2.6, -1.3, 0.0, 1.3, 2.6) for s in (1, -1) for y0, y1 in ((1.2, 3.4), (4.4, 6.6))]
	obj(c, "Louvres", merge(*ribs), "Trim")
	fans = []
	for x in (-1.9, 1.9):
		fans.append(lathe_at(x, 0.0, [(0.0, 7.45), (1.2, 7.45), (1.35, 7.3), (1.35, 7.15)]))
	obj(c, "Fans", merge(*fans), "Charcoal")


def lathe_at(x, z, prof, steps=16):
	return xform(lathe(chamfer_path(prof, 0.05), steps=steps), T(x, -z, 0))


def p_condenser():
	c = piece("Condenser")
	obj(c, "Body", RB(-1.9, 1.9, 0.0, 2.8, -1.9, 1.9, 0.25, SS), "Metal")
	obj(c, "Fan", lathe_at(0, 0, [(0.0, 3.0), (1.3, 3.0), (1.45, 2.85), (1.45, 2.7)]), "Charcoal")


def p_skylight():
	c = piece("Skylight")
	obj(c, "Curb", RB(-4.0, 4.0, -0.1, 1.2, -2.0, 2.0, BS, SS), "Trim")
	hip = [(-3.7, 1.15), (3.7, 1.15), (2.2, 2.9), (-2.2, 2.9)]
	obj(c, "Glass", RPZ(hip, -1.75, 1.75, BT, ST), "Glass")
	obj(c, "Ridge", RB(-2.3, 2.3, 2.85, 3.0, -0.12, 0.12, BT, ST), "Charcoal")


def p_planter():
	c = piece("Planter")
	obj(c, "Box", RB(-3.0, 3.0, -0.1, 2.6, -1.5, 1.5, BS, SS), "Wood")
	obj(c, "Rim", RB(-3.1, 3.1, 2.45, 2.75, -1.6, 1.6, BT, ST), "Trim")
	obj(c, "Hedge", RB(-2.75, 2.75, 2.6, 7.45, -1.25, 1.25, 0.6, SP), "Plant")


def p_water_tank(name="WaterTank"):
	c = piece(name)
	legs = []
	for dx in (-3.5, 3.5):
		for dz in (-3.5, 3.5):
			legs.append(RPY(octo(dx, dz, 0.42, 0.12), 0.0, 4.5, BT, ST))
	for s in (1, -1):
		legs.append(RB(-3.9, 3.9, 3.9, 4.45, s * 3.5 - 0.25, s * 3.5 + 0.25, BT, ST))
		legs.append(RB(s * 3.5 - 0.25, s * 3.5 + 0.25, 3.95, 4.4, -3.9, 3.9, BT, ST))
	obj(c, "Stand", merge(*legs), "Charcoal")
	# lathe() faces the left of the profile direction: walls run DOWN to face outward.
	obj(c, "Drum", lathe([(4.4, 13.8), (4.4, 4.62)], steps=32), "Accent")
	obj(c, "Base", lathe([(4.5, 4.64), (4.5, 4.42), (0.0, 4.42)], steps=32), "Accent")
	hoops = [lathe([(4.52, y + 0.35), (4.52, y)], steps=32) for y in (6.0, 9.0, 12.0)]
	obj(c, "Hoops", merge(*hoops), "White")
	cap = [(4.7, 13.8), (4.7, 14.2), (0.6, 15.8), (0.0, 16.0)][::-1]
	obj(c, "Cap", lathe(cap, steps=32), "White")
	lad = [RB(4.5, 4.62, 0.0, 13.5, z - 0.08, z + 0.08) for z in (-0.6, 0.6)]
	lad += [RB(4.48, 4.66, y, y + 0.12, -0.6, 0.6) for y in [1.0 + 1.1 * k for k in range(11)]]
	obj(c, "Ladder", merge(*lad), "Charcoal")


def p_lift_tower():
	c = hut("LiftTower", 10, 8, 16, door="+X")
	obj(c, "Sign", RB(-5.08, -4.98, 10.0, 12.6, -3.0, 3.0), "Accent")
	# Round 5: a "TANK" name plate on each long face (toward each team's Pit stair): the middle's ground-level callout.
	plates, rims, words = [], [], []
	for s in (1, -1):
		z0, z1 = sorted((s * 4.0, s * 4.22))
		plates.append(RB(-3.4, 3.4, 9.4, 11.6, z0, z1, BT, ST))
		rz0, rz1 = sorted((s * 3.96, s * 4.34))
		rims.append(RB(-3.7, 3.7, 9.1, 9.4, rz0, rz1, BT, ST))
		rims.append(RB(-3.7, 3.7, 11.6, 11.9, rz0, rz1, BT, ST))
		bm, w = text_mesh("TANK", 1.4, depth=0.1)
		# text_mesh faces Roblox +Z with its back at z 0: put it on the +Z plate, or turn it for the -Z one.
		if s > 0:
			xform(bm, T(0.0, -4.22, 9.8))
		else:
			xform(bm, T(0.0, 4.22, 9.8) @ RZ(180))
		words.append(bm)
	obj(c, "Plate", merge(*plates), "Charcoal")
	obj(c, "PlateRim", merge(*rims), "Trim")
	obj(c, "PlateWord", merge(*words), "White", smooth=0)
	# Round 6: low vent pairs and a band under the plates, so the faces facing the stairs aren't one slab.
	vents, band = [], []
	for s in (1, -1):
		vz0, vz1 = sorted((s * 3.96, s * 4.25))
		for x in (-2.6, 2.6):
			vents.append(RB(x - 1.0, x + 1.0, 2.2, 3.6, vz0, vz1, BT, ST))
		bz0, bz1 = sorted((s * 3.98, s * 4.15))
		band.append(RB(-4.3, 4.3, 6.2, 6.7, bz0, bz1))
	obj(c, "Vents", merge(*vents), "Metal")
	obj(c, "MidBand", merge(*band), "Trim")


def p_cooling():
	c = piece("CoolingTower")
	obj(c, "Plinth", RB(-5.25, 5.25, -0.1, 0.9, -5.25, 5.25, BS, SS), "Plinth")
	obj(c, "Body", RB(-5.0, 5.0, 0.9, 7.3, -5.0, 5.0, 0.3, SS), "Metal")
	ribs = []
	for s in (1, -1):
		for t in (-3.0, -1.5, 0.0, 1.5, 3.0):
			ribs.append(RB(s * 5.0 - 0.1, s * 5.0 + 0.1, 1.8, 6.6, t - 0.35, t + 0.35, BT, ST))
		for t in (-2.25, -0.75, 0.75, 2.25):
			ribs.append(RB(t - 0.35, t + 0.35, 1.9, 6.5, s * 5.0 - 0.12, s * 5.0 + 0.12, BT, ST))
	obj(c, "Louvres", merge(*ribs), "Trim")
	obj(c, "Fan", lathe_at(0, 0, [(0.0, 7.4), (3.6, 7.4), (3.9, 7.7), (3.9, 8.0)], 24), "Charcoal")


def p_billboard():
	c = piece("Billboard22")
	legs = [RPY(octo(x, 0.0, 0.4, 0.12), 0.0, 9.0, BT, ST) for x in (-7.0, 7.0)]
	legs += [RB(-11.2, 11.2, 8.7, 9.2, -0.55, 0.55, BT, ST)]
	obj(c, "Frame", merge(*legs), "Charcoal")
	ring = ring_prism(rrect(22.0, 10.0, 0.6, 2, 0.0, 14.0), rrect(21.0, 9.0, 0.35, 2, 0.0, 14.0), -0.5, 0.5, "Y")
	obj(c, "Border", finish(ring, BT, ST), "Charcoal")
	obj(c, "Panel", RB(-10.6, 10.6, 9.55, 18.45, -0.35, 0.35), "Poster")  # round 6: calmer than the tank
	obj(c, "Band", RB(-10.6, 10.6, 9.55, 12.0, 0.35, 0.42), "AccentSoft")
	bm, w = text_mesh("SUNSET SODA", 2.0, depth=0.14)
	xform(bm, T(0.0, -0.42, 13.7))
	bm2, w2 = text_mesh("SUNSET SODA", 2.0, depth=0.14)
	xform(bm2, T(0.0, 0.42, 13.7) @ RZ(180))  # the back reads too (seen from the far roof)
	obj(c, "Ad", merge(bm, bm2), "PosterInk", smooth=0)
	obj(c, "BandBack", RB(-10.6, 10.6, 9.55, 12.0, -0.42, -0.35), "AccentSoft")
	lamps, glow = [], []
	for x in (-6.0, 0.0, 6.0):
		lamps.append(RB(x - 0.08, x + 0.08, 18.9, 19.9, 0.3, 1.4))
		lamps.append(RB(x - 0.5, x + 0.5, 19.6, 20.0, 1.0, 1.8, BT, ST))
		glow.append(RB(x - 0.4, x + 0.4, 19.5, 19.62, 1.1, 1.7))
	obj(c, "Lamps", merge(*lamps), "Charcoal")
	obj(c, "LampGlow", merge(*glow), "GlowWarm")


def p_roof_sign():
	c = piece("RoofSign")
	legs = [RB(-0.15, 0.15, -0.05, 3.95, z - 0.15, z + 0.15, BT, ST) for z in (-2.2, 2.2)]
	obj(c, "Legs", merge(*legs), "Charcoal")
	obj(c, "Panel", RB(-0.45, 0.45, 4.0, 14.0, -7.0, 7.0, BS, SS), "Accent")
	ring = []
	for s in (1, -1):
		bm, w = text_mesh("SKY DINER", 1.5, depth=0.12)
		xform(bm, T(s * 0.45, 0.0, 7.6) @ RZ(90 * s))
		ring.append(bm)
	obj(c, "Neon", merge(*ring), "GlowWest")
	obj(c, "Trim", merge(RB(-0.55, 0.55, 3.8, 4.1, -7.2, 7.2, BT, ST), RB(-0.55, 0.55, 13.9, 14.25, -7.2, 7.2, BT, ST)), "White")


def p_letter(ch):
	c = piece("Letter" + ch)
	bm, w = text_mesh(ch, 6.0, depth=0.2)
	# faces -Y blender (+Z roblox) -> turn to face -Z (toward the middle), back on z 0
	xform(bm, T(0.0, 0.0, 2.5) @ RZ(180))
	obj(c, "Letter", bm, "White", smooth=0)


def p_spawn_sign(team):
	c = piece("SpawnSign" + team)
	left, right = ("WEST", "EAST") if team == "B" else ("EAST", "WEST")
	lrole, rrole = ("SignWest", "SignEast") if team == "B" else ("SignEast", "SignWest")
	ring = ring_prism(rrect(15.0, 5.6, 0.7, 4, 0.0, 6.6), rrect(13.9, 4.5, 0.45, 4, 0.0, 6.6), -0.42, -0.06, "Y")
	obj(c, "Frame", finish(ring, BT, ST), "Charcoal")
	obj(c, "Plate", RB(-7.05, 7.05, 4.25, 8.95, 0.0, 0.3, BT, ST), "White")
	bm, w = text_mesh("ROOF " + team, 1.7, depth=0.14)
	xform(bm, T(0.0, -0.3, 6.95))
	obj(c, "Title", bm, "Charcoal", smooth=0)
	bm, w = text_mesh(left, 0.8, depth=0.12)
	xform(bm, T(-6.2 + 1.4 + w / 2, -0.3, 4.95))
	obj(c, "Left", merge(bm, arrow(-6.3, 5.35, 0.3, 0.42, -1, 0.9, 0.85)), lrole, smooth=0)
	bm, w = text_mesh(right, 0.8, depth=0.12)
	xform(bm, T(6.2 - 1.4 - w / 2, -0.3, 4.95))
	obj(c, "Right", merge(bm, arrow(6.3, 5.35, 0.3, 0.42, 1, 0.9, 0.85)), rrole, smooth=0)


def p_chevron():
	# Round 4: a white chevron painted on the roof (top 0.07), pointing local -Z: the way out of the spawn court.
	c = piece("Chevron")
	k = 2.2  # round 7: bigger again (every round-6 reviewer still called them small)
	pts = [(-1.6 * k, 0.8 * k), (0.0, -0.8 * k), (1.6 * k, 0.8 * k), (0.75 * k, 0.8 * k), (0.0, 0.05 * k), (-0.75 * k, 0.8 * k)]
	obj(c, "Paint", RPY(pts, -0.05, 0.07), "Chevron")  # round 8: painted cream (pure cobalt read as pasted-on slabs)


def p_deck_word(word, role, text=None):
	c = piece("DeckWord" + word)
	bm, w = text_mesh(text or word, 1.6 if text else 2.6, depth=0.12)  # ROOF A/B: 1.6 fits between the lift tower and the parapet
	xform(bm, T(0.0, -1.3, 0.01) @ Matrix.Rotation(math.radians(-90), 4, "X") @ T(0.0, 0.06, 0.0))
	obj(c, "Paint", bm, role, smooth=0)


def p_street_lamp():
	c = piece("StreetLamp")
	obj(c, "Pole", lathe([(0.18, 9.0), (0.3, 0.0)], steps=8), "Charcoal")
	obj(c, "Arm", RB(0.0, 2.6, 8.7, 9.0, -0.12, 0.12, BT, ST), "Charcoal")
	obj(c, "Head", RB(2.0, 3.2, 8.4, 8.8, -0.35, 0.35, BT, ST), "Charcoal")
	obj(c, "Lens", RB(2.1, 3.1, 8.3, 8.42, -0.28, 0.28), "GlowWarm")


def city(name, W, Dp, H):
	c = piece(name, height=H)
	hx, hz = W / 2, Dp / 2
	obj(c, "Wall", RB(-hx, hx, 0.0, H, -hz, hz), "Wall")
	bands = []
	for y in range(8, int(H) - 4, 10):
		bands.append(RB(hx - 0.02, hx + 0.12, y, y + 4.0, -hz + 2.0, hz - 2.0))
		bands.append(RB(-hx + 2.0, hx - 2.0, y, y + 4.0, hz - 0.02, hz + 0.12))
		bands.append(RB(-hx + 2.0, hx - 2.0, y, y + 4.0, -hz - 0.12, -hz + 0.02))
	obj(c, "Windows", merge(*bands), "Window")
	obj(c, "Cap", RB(-hx - 0.6, hx + 0.6, H, H + 1.2, -hz - 0.6, hz + 0.6), "Trim")


# ---------------------------------------------------------------- build

def build():
	for o in list(bpy.data.objects):
		bpy.data.objects.remove(o)
	for col in list(bpy.data.collections):
		bpy.data.collections.remove(col)
	D.PIECES.clear()
	materials()
	D.KIT = collection("Kit_Rooftops2")
	facade("Facade8A", 8, "A")
	facade("Facade8B", 8, "B")
	facade("Facade8C", 8, "C")
	facade("Facade4", 4, "A")
	p_plinth("Plinth8", 8)
	p_plinth("Plinth4", 4)
	p_quoin()
	p_flue()
	stairs("Stair16", rail_role="Hazard")  # round 1: every walkable route reads by its yellow rail
	stairs("Gangway16", rail_role="Hazard")
	p_plank_ramp()
	p_catwalk()
	p_ac()
	p_condenser()
	p_skylight()
	p_planter()
	p_penthouse()
	hut("StairHut", 6, 6, 9)
	hut("LiftHouse", 8, 8, 10, vent=True)
	p_lift_tower()
	hut("TankHouse", 10, 10, 8)
	p_cooling()
	p_water_tank()
	p_billboard()
	p_roof_sign()
	p_letter("A")
	p_letter("B")
	p_spawn_sign("A")
	p_spawn_sign("B")
	p_deck_word("PIT", "SignPit")
	p_deck_word("WEST", "SignWest")
	p_deck_word("EAST", "SignEast")
	p_chevron()
	p_deck_word("ROOFA", "SignPit", "ROOF A")
	p_deck_word("ROOFB", "SignPit", "ROOF B")
	p_street_lamp()
	city("CityA", 28, 24, 64)
	city("CityB", 24, 24, 90)
	city("CityC", 30, 30, 120)
	tris = {}
	for n, col in D.PIECES.items():
		t = 0
		for o in col.all_objects:
			o.data.calc_loop_triangles()
			t += len(o.data.loop_triangles)
		tris[n] = t
	os.makedirs(ART, exist_ok=True)
	bpy.ops.wm.save_as_mainfile(filepath=BLEND)
	return tris


if __name__ == "__main__":
	tris = build()
	print("ROOFTOPS2_TRIS", sum(tris.values()), tris)
	found = D.coplanar_audit()
	print("COPLANAR", len(found))
	for f in found[:30]:
		print("  ", f["piece"], f["a"], f["b"], [round(x, 3) for x in f["plane"]], f["area"])
	if "--render" in ARGS:
		M["Deck"] = M["Roof"]  # the contact-sheet floor
		D.render_settings()
		D.world(sun_el=32.0)
		for lc in bpy.context.view_layer.layer_collection.children:
			if lc.name == "Kit_Rooftops2":
				lc.exclude = True
		os.makedirs(RENDER_DIR, exist_ok=True)
		stage, w = D.contact_sheet(["Facade8A", "Facade8B", "Facade8C", "StairHut", "ACUnit", "Condenser", "Skylight", "Planter", "WaterTank", "CoolingTower"], "a")
		D.camera((w / 2, 6, 70), (w / 2, -6, 0), 26)
		D.shot(os.path.join(RENDER_DIR, "kit-contact-a.jpg"))
		bpy.data.collections.remove(stage)
		stage, w = D.contact_sheet(["Penthouse", "SpawnSignB", "Billboard22", "RoofSign", "Stair16", "Gangway16", "PlankRamp16", "Catwalk8"], "b")
		D.camera((w / 2, 22, 70), (w / 2, 6, 0), 26)
		D.shot(os.path.join(RENDER_DIR, "kit-contact-b.jpg"))
		bpy.data.collections.remove(stage)
