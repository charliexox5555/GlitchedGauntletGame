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
from build_lobby_kit_stylized import finish, merge, xform, T, RX, RZ, rrect  # noqa: E402
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


# ---------------------------------------------------------------- concept pass v2 (2026-11-05)
# Rebuilt from the approved concepts (art-source/maps/Rooftops2/concepts, vault/01 Design/Maps/Rooftops2.md ->
# Concept board): arched windows in stone surrounds with keystones and louvred shutters, quoined corners, corbelled
# cornices, a terracotta hip-roof Penthouse (A) and a slate mansard one (B), a timber water tank on a splayed, braced
# steel stand with a railed platform and a sign arm, chunky fire-escape steel, stone Pit stairs with cheek walls, a
# plank bridge on a steel truss, and props in story groups. LihFolk rules applied: steel bevels 0.12-0.2, stone and
# plaster 0.3-0.45 (Hard-Surface Modeling); nothing thinner than 0.2, posts >= 0.35 (Proportion Exaggeration and
# Gameplay Distance); primary / secondary / tertiary masses with one focal feature per piece (Shape Language and
# Silhouette Testing); stacked props tilted a few degrees (Low-Poly and Stylized Modeling); undersides modelled
# (first person sees them); detail concentrated at eye height (Spending Triangles Where the Camera Looks).

BST = 0.16  # steel bevel
BSN = 0.35  # stone / plaster bevel


def rb(x, y, z):
	# Roblox (x, y, z) -> Blender co
	return (x, -z, y)


def beam(p0, p1, w, h=None, up=(0.0, 1.0, 0.0), r=0.0):
	"""Square-section bar from p0 to p1 (Roblox coords), w wide, h tall, rounded by r."""
	h = h or w
	a, b = Vector(p0), Vector(p1)
	d = (b - a).normalized()
	u = Vector(up)
	if abs(d.dot(u)) > 0.95:
		u = Vector((1.0, 0.0, 0.0))
	s = d.cross(u).normalized()
	u2 = s.cross(d).normalized()
	bm = bmesh.new()
	vs = []
	for p in (a, b):
		for i, j in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
			q = p + s * (i * w / 2) + u2 * (j * h / 2)
			vs.append(bm.verts.new(rb(q.x, q.y, q.z)))
	for ids in ((0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)):
		bm.faces.new([vs[i] for i in ids])
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	return finish(bm, r, 1) if r > 0 else bm


def frustum(x0, x1, z0, z1, y0, y1, ix, iz, r=0.0):
	"""A box whose top is inset by ix (X) and iz (Z): hip roofs, caps, plinths."""
	bm = bmesh.new()
	bot = [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]
	top = [(x0 + ix, z0 + iz), (x1 - ix, z0 + iz), (x1 - ix, z1 - iz), (x0 + ix, z1 - iz)]
	vs = [bm.verts.new(rb(x, y0, z)) for x, z in bot] + [bm.verts.new(rb(x, y1, z)) for x, z in top]
	for ids in ((0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)):
		bm.faces.new([vs[i] for i in ids])
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	return finish(bm, r, 1) if r > 0 else bm


def arch_pts(w, h, v0, cu=0.0, n=7):
	"""CCW outline in (u, v): flat sill at v0, straight jambs, a semicircular head; h tall overall."""
	r = w / 2
	vs = v0 + h - r
	pts = [(cu - r, v0), (cu + r, v0)]
	for k in range(n + 1):
		a = math.pi * k / n
		pts.append((cu + r * math.cos(a), vs + r * math.sin(a)))
	return pts


def arch_ring_x(w, h, t, v0, x0, x1, cz=0.0):
	# Stone surround on a wall facing +X (plane Y-Z), extruded x0..x1.
	o = arch_pts(w, h, v0, cz)
	i = arch_pts(w - 2 * t, h - 2 * t, v0 + t, cz)
	o = [(-u, v) for u, v in o][::-1]
	i = [(-u, v) for u, v in i][::-1]
	return finish(ring_prism(o, i, x0, x1, "X"), 0.0, 1)


def arch_ring_z(w, h, t, v0, z0, z1, cx=0.0):
	# Stone surround on a wall facing +-Z (plane X-Y), extruded over Roblox z0..z1.
	o = arch_pts(w, h, v0, cx)
	i = arch_pts(w - 2 * t, h - 2 * t, v0 + t, cx)
	return finish(ring_prism(o, i, -max(z0, z1), -min(z0, z1), "Y"), 0.0, 1)


def window_x(cz, v0, w, h, out, parts, shutters=True, sides=(-1, 1), edge=None):
	"""An arched window on a +X facing wall at x 0: recessed glass, stone surround, keystone, sill on corbels,
	louvred shutter leaves (open, flat to the wall). parts: dict role -> list of bmeshes."""
	parts["Window"].append(RPX(arch_pts(w - 0.04, h - 0.47, v0 + 0.46, cz), 0.01, 0.05))  # fills the surround's opening, 0.23 behind its face
	parts["Stone"].append(arch_ring_x(w + 0.9, h + 0.45, 0.45, v0 - 0.0, -0.04, 0.28, cz))
	top = v0 + h + 0.45
	parts["Stone"].append(RPX([(cz - 0.45, top - 0.75), (cz + 0.45, top - 0.75), (cz + 0.6, top + 0.15), (cz - 0.6, top + 0.15)], -0.07, 0.42, BT, ST))
	parts["Stone"].append(RB(-0.09, 0.5, v0 - 0.5, v0 - 0.05, cz - w / 2 - 0.65, cz + w / 2 + 0.65, BT, ST))
	for s in (-1, 1):
		parts["Stone"].append(RB(0.0, 0.38, v0 - 1.05, v0 - 0.5, cz + s * (w / 2 + 0.15) - 0.25, cz + s * (w / 2 + 0.15) + 0.25, BT, ST))
	if shutters and out:
		sh = h - w / 2 + 0.2
		lw = w / 2 + 0.15
		for s in sides:
			z0 = cz + s * (w / 2 + 0.5)
			if edge is not None:  # keep the leaf inside the module (neighbouring modules have their own)
				lw = min(lw, edge - 0.08 - abs(z0))
				if lw < 0.5:
					continue
			z1 = z0 + s * lw
			a, b = sorted((z0, z1))
			parts["Shutter"].append(RB(0.0, 0.16, v0, v0 + sh, a, b, BT, ST))
			for k in range(6):
				y = v0 + 0.45 + k * (sh - 0.9) / 5
				parts["Shutter"].append(RB(0.12, 0.26, y - 0.12, y + 0.12, a + 0.12, b - 0.12))


def window_z(cx, v0, w, h, face, parts, shutters=True):
	"""The same window on a wall facing +Z (face > 0) or -Z, wall plane at z = face."""
	sg = 1 if face > 0 else -1
	z = lambda d: tuple(sorted((face + sg * d[0], face + sg * d[1])))  # noqa: E731  (depth range out of the wall)
	parts["Window"].append(RPZ(arch_pts(w - 0.04, h - 0.47, v0 + 0.46, cx), *z((0.01, 0.05))))
	parts["Stone"].append(arch_ring_z(w + 0.9, h + 0.45, 0.45, v0, *z((-0.04, 0.28)), cx=cx))
	top = v0 + h + 0.45
	parts["Stone"].append(RPZ([(cx - 0.45, top - 0.75), (cx + 0.45, top - 0.75), (cx + 0.6, top + 0.15), (cx - 0.6, top + 0.15)], *z((-0.07, 0.42)), BT, ST))
	parts["Stone"].append(RB(cx - w / 2 - 0.65, cx + w / 2 + 0.65, v0 - 0.5, v0 - 0.05, *z((-0.09, 0.5)), BT, ST))
	if shutters:
		sh = h - w / 2 + 0.2
		lw = w / 2 + 0.15
		for s in (-1, 1):
			x0 = cx + s * (w / 2 + 0.5)
			a, b = sorted((x0, x0 + s * lw))
			parts["Shutter"].append(RB(a, b, v0, v0 + sh, *z((0.0, 0.16)), BT, ST))
			for k in range(6):
				y = v0 + 0.45 + k * (sh - 0.9) / 5
				parts["Shutter"].append(RB(a + 0.12, b - 0.12, y - 0.12, y + 0.12, *z((0.12, 0.26))))


def roles():
	return {k: [] for k in ("Paver", "Tar", "Poster", "Appliance", "Wall", "Stone", "Trim", "Window", "Shutter", "Charcoal", "Metal", "Accent", "AccentSoft", "Wood", "Brick", "RoofTile", "RoofSlate", "Pot", "Plant", "Door", "GlowWarm", "Plinth", "Glass", "Cloth")}


def emit(c, parts, prefix=""):
	for role, bms in parts.items():
		if bms:
			obj(c, prefix + role, merge(*bms), role, smooth=0 if role in ("Shutter", "Stone") else 35)


def quoins_corner(px, pz, sx, sz, y0, y1, parts, long=1.1):
	"""Alternating long / short stone blocks on a building corner at (px, pz), faces toward sx (X) and sz (Z).
	Maps v4: one size smaller (1.1 x 0.7 x 0.62, was 1.6 x 0.9 x 0.8), 0.1 proud."""
	y, k = y0, 0
	while y + 0.64 <= y1:
		lx, lz = (long, 0.7) if k % 2 == 0 else (0.7, long)
		x0, x1 = sorted((px + sx * 0.1, px - sx * lx))
		z0, z1 = sorted((pz + sz * 0.1, pz - sz * lz))
		parts["Stone"].append(RB(x0, x1, y + 0.03, y + 0.65, z0, z1, BT, ST))
		y += 0.68
		k += 1


# ---- facades (top storey detailed, lower storeys simpler: the roofs see the top one up close)

def facade2(name, W, variant):
	c = piece(name, width=W)
	h = W / 2
	P = roles()
	P["Wall"].append(open_box(RB(-0.6, 0.0, -72.3, -1.0, -h, h), drop_y=True))
	# cornice on corbels under the parapet line, a cobalt string course, storey bands
	P["Stone"].append(open_box(RB(0.0, 0.7, -2.4, -1.05, -h, h), drop_back=True))
	P["Stone"].append(open_box(RB(0.0, 0.32, -3.0, -2.4, -h, h), drop_back=True))
	for zc in [(-h + 1.0) + 2.0 * k for k in range(int(W / 2))]:
		P["Stone"].append(RB(0.0, 0.55, -3.55, -2.98, zc - 0.32, zc + 0.32, BT, ST))
	P["AccentSoft"].append(open_box(RB(0.0, 0.18, -4.1, -3.6, -h, h), drop_back=True))
	P["Plinth"].append(open_box(RB(0.0, 0.2, -72.25, -69.2, -h, h), drop_back=True))
	for k in range(6):
		y0 = -72.0 + 12.0 * k
		if 0 < k < 5:
			P["Stone"].append(open_box(RB(0.0, 0.14, y0 - 0.25, y0 + 0.25, -h, h), drop_back=True))
		top = k == 5
		cols = [0.0] if W == 4 else ([-1.6, 1.6] if variant == "B" else [0.0])
		ww = 1.6 if (W == 4 or variant == "B") else 2.4
		v0, hh = (y0 + 2.4, 4.6) if top else (y0 + 3.0, 5.6)  # the top storey stops under the string course
		for zc in cols:
			window_x(zc, v0, ww, hh, top, P, shutters=top and variant != "C", sides=((1 if zc > 0 else -1),) if len(cols) > 1 else (-1, 1), edge=h)
	if variant == "B":  # a downpipe with a hopper head
		P["Charcoal"].append(RPY(octo(0.35, h - 0.6, 0.2, 0.06), -72.0, -4.4, BT, ST))
		P["Charcoal"].append(RB(0.1, 0.75, -4.6, -3.9, h - 0.95, h - 0.25, BT, ST))
	emit(c, P)


# ---- penthouses: A terracotta hip roof, B slate mansard. 40 x 8 x 11, door +Z (spawn court), balcony side -Z.

def penthouse2(team):
	c = piece("Penthouse" + team, width=40, depth=8, height=11)
	P = roles()
	hx, hz = 20.0, 4.0
	P["Plinth"].append(RB(-hx - 0.25, hx + 0.25, -0.1, 0.9, -hz - 0.25, hz + 0.25, BSN, 1))
	P["Wall"].append(RB(-hx, hx, 0.9, 8.0, -hz, hz, BT, ST))
	for sx in (1, -1):
		for sz in (1, -1):
			quoins_corner(sx * hx, sz * hz, sx, sz, 0.9, 7.9, P)
	# eaves: a stone cornice on corbels
	P["Stone"].append(RB(-hx - 0.55, hx + 0.55, 7.85, 8.55, -hz - 0.55, hz + 0.55, BT, ST))
	for x in [-19.0 + 2.0 * k for k in range(20)]:
		for s in (1, -1):
			a, b = sorted((s * hz, s * (hz + 0.45)))
			P["Stone"].append(RB(x - 0.28, x + 0.28, 7.35, 7.86, a, b, BT, ST))
	if team == "A":
		P["RoofTile"].append(frustum(-hx - 0.7, hx + 0.7, -hz - 0.7, hz + 0.7, 8.55, 10.9, 2.6, 2.6, BT))
		P["Stone"].append(RB(-hx + 1.95, hx - 1.95, 10.88, 11.0, -hz + 1.95, hz - 1.95))
		P["Trim"].append(RB(-hx + 2.0, hx - 2.0, 10.95, 11.3, -0.25, 0.25, BT, ST))  # ridge
	else:
		P["RoofSlate"].append(frustum(-hx - 0.55, hx + 0.55, -hz - 0.55, hz + 0.55, 8.55, 10.3, 0.9, 0.9, BT))
		P["RoofSlate"].append(frustum(-hx + 0.35, hx - 0.35, -hz + 0.35, hz - 0.35, 10.3, 10.9, 1.4, 1.4, BT))
		P["Trim"].append(RB(-hx + 0.3, hx - 0.3, 10.22, 10.42, -hz + 0.3, hz - 0.3, BT, ST))  # mansard break
		P["Stone"].append(RB(-hx + 1.7, hx - 1.7, 10.88, 11.0, -hz + 1.7, hz - 1.7))
		# dormers on the mansard's long faces
		for x in (-12.0, 12.0):
			for s in (1, -1):
				a, b = sorted((s * (hz + 0.15), s * (hz - 1.0)))
				P["Wall"].append(RB(x - 1.1, x + 1.1, 8.6, 10.6, a, b, BT, ST))
				P["RoofSlate"].append(frustum(x - 1.4, x + 1.4, min(a, b) - 0.1, max(a, b) + 0.1, 10.55, 11.05, 0.0, 0.0))
				wa, wb = sorted((s * (hz + 0.16), s * (hz + 0.05)))
				P["Window"].append(RB(x - 0.6, x + 0.6, 8.9, 10.2, wa, wb))
	# chimneys: brick stacks with a stone cap and two pots
	for x in (-13.5, 13.5):
		P["Brick"].append(RB(x - 1.0, x + 1.0, 9.0, 13.2, 0.4, 2.2, BT, ST))
		P["Stone"].append(RB(x - 1.2, x + 1.2, 13.2, 13.6, 0.2, 2.4, BT, ST))
		for dx in (-0.45, 0.45):
			P["Pot"].append(lathe_at(x + dx, 1.3, [(0.32, 14.5), (0.36, 14.3), (0.4, 13.6)], 10))
	# +Z: arched door with surround, keystone, lamps; arched windows with shutters
	P["Door"].append(RPZ(arch_pts(2.9, 5.6, 0.95), 3.82, 4.02))
	P["Stone"].append(arch_ring_z(4.2, 6.2, 0.6, 0.92, 3.95, 4.35))
	P["Stone"].append(RPZ([(-0.5, 6.4), (0.5, 6.4), (0.65, 7.35), (-0.65, 7.35)], 3.93, 4.5, BT, ST))
	for x in (-2.9, 2.9):
		P["Charcoal"].append(RB(x - 0.32, x + 0.32, 4.7, 5.9, 4.0, 4.6, BT, ST))
		P["GlowWarm"].append(RB(x - 0.22, x + 0.22, 4.85, 5.75, 4.6, 4.68))
	for x in (8.5, 15.0):  # the spawn sign hangs at local x -11 on this face (rooftops2_art.py)
		window_z(x, 2.6, 2.0, 4.4, hz, P, shutters=True)
	# -Z (Pit side, along the fire-escape balcony): low windows under the deck, short arched ones above it
	for x in (-15.0, -8.0, -4.0, 4.0, 8.0, 12.0, 16.0):  # between the balcony's knee braces (x -10, -6, ... 18)
		window_z(x, 1.6, 1.4, 2.4, -hz, P, shutters=False)
		window_z(x, 5.6, 1.4, 1.9, -hz, P, shutters=False)
	# ends: one window each, downpipes
	for sx in (1, -1):
		P["Window"].append(RPX(arch_pts(1.6, 3.6, 3.0), *sorted((sx * 19.85, sx * 20.03))))
		for sz in (1, -1):
			a, b = sorted((sx * (hx + 0.05), sx * (hx + 0.45)))
			P["Charcoal"].append(RB(a, b, 0.9, 8.0, sz * (hz - 0.6) - 0.18, sz * (hz - 0.6) + 0.18, BT, ST))
	emit(c, P)


# ---- fire escape: stair (8 run along +Z, 3 wide, rising 5) and balcony (32 long along X, deck top at 0)

def fire_stair(name="FireStair", run=8.0, rise=5.0, width=3.0):
	c = piece(name)
	P = roles()
	hw = width / 2
	n = max(2, math.ceil(rise / 0.85))
	for k in range(n):
		z0 = -run / 2 + run * k / n
		top = rise * (k + 1) / n - 0.02
		P["Metal"].append(RB(-hw + 0.3, hw - 0.3, top - 0.22, top, z0 + 0.05, z0 + run / n - 0.05, BT, ST))
		P["Charcoal"].append(RB(-hw + 0.3, hw - 0.3, top - 0.38, top - 0.22, z0 + run / n - 0.25, z0 + run / n - 0.05))
	strg = [(-run / 2, -0.15), (-run / 2 + 0.9, -0.15), (run / 2, rise - 0.6), (run / 2, rise + 0.15), (-run / 2, 0.55)]

	def side(a, b, sg):
		return tuple(sorted((sg * a, sg * b)))

	for sg in (1, -1):
		P["Charcoal"].append(RPX(strg, *side(hw - 0.32, hw + 0.05, sg), BST, 1))
		# posts and a chunky handrail 3.3 over the nosings
		for zp in (-run / 2 + 0.4, 0.0, run / 2 - 0.4):
			yb = rise * (zp + run / 2) / run
			P["Charcoal"].append(RB(*side(hw - 0.29, hw + 0.01, sg), yb, yb + 3.3, zp - 0.18, zp + 0.18, BT, ST))
		P["Charcoal"].append(beam((sg * (hw - 0.14), 3.3, -run / 2), (sg * (hw - 0.14), rise + 3.3, run / 2), 0.26, 0.3))
		P["Charcoal"].append(beam((sg * (hw - 0.14), 1.7, -run / 2), (sg * (hw - 0.14), rise + 1.7, run / 2), 0.2, 0.2))
	emit(c, P)


def fire_balcony():
	c = piece("FireBalcony")
	P = roles()
	L, d = 16.0, 1.5
	P["Metal"].append(RB(-L, L, -0.4, 0.0, -d, d, BT, ST))
	# grating ribs on top (opaque), edge channels, joists underneath, knee braces to the wall
	for x in [-L + 1.0 + 2.0 * k for k in range(16)]:
		P["Charcoal"].append(RB(x - 0.12, x + 0.12, 0.0, 0.06, -d + 0.1, d - 0.1))
	P["Charcoal"].append(RB(-L + 0.02, L - 0.02, -1.0, 0.05, -d - 0.6, -d + 0.05, BST, 1))
	P["Charcoal"].append(RB(-L + 0.04, L - 0.04, -0.9, -0.4, d - 0.35, d, BT, ST))
	for x in [-L + 2.0 + 4.0 * k for k in range(8)]:
		P["Charcoal"].append(RB(x - 0.18, x + 0.18, -0.9, -0.4, -d - 0.55, d - 0.3))
		P["Charcoal"].append(beam((x, -0.6, -d - 0.2), (x, -3.2, d - 0.05), 0.3, 0.3))
		P["Charcoal"].append(RB(x - 0.4, x + 0.4, -3.6, -2.6, d - 0.15, d, BT, ST))
	# the parapet: a steel panel wall (low cover, 3 tall) with posts and a cream top rail
	z0, z1 = -d - 0.6, -d
	P["Charcoal"].append(RB(-L + 0.06, L - 0.06, 0.03, 2.75, z0 + 0.1, z1 - 0.1, BT, ST))
	for x in [-L + 0.2 + 2.0 * k for k in range(17)]:
		x = min(x, L - 0.2)
		P["Charcoal"].append(RB(x - 0.2, x + 0.2, 0.0, 2.8, z0, z1, BT, ST))
	for x in [-L + 1.2 + 2.0 * k for k in range(16)]:
		P["Metal"].append(RB(x - 0.6, x + 0.6, 0.6, 2.2, z0 + 0.02, z0 + 0.1, BT, ST))
	P["Trim"].append(RB(-L - 0.1, L + 0.1, 2.75, 3.0, z0 - 0.08, z1 + 0.08, BT, ST))
	emit(c, P)


# ---- the landmark: timber water tank on a braced steel stand (base centre of the stand, 4 tall), drum 4.4-14

def water_tank2():
	c = piece("WaterTank")
	P = roles()
	# stand (maps v5 float audit: the old feet at +-4.3 stood in the air past the tower's edge). Four legs from feet at
	# +-2.4 (inside the 10 x 8 tower top at the 1.35x placement) up to +-2.8, bolted foot plates, ring beams, X
	# bracing on each face, and raking outriggers under the platform's overhang.
	for dx in (-1, 1):
		for dz in (-1, 1):
			P["Charcoal"].append(beam((dx * 2.4, 0.0, dz * 2.4), (dx * 2.8, 4.45, dz * 2.8), 0.62, 0.62, r=BT))
			P["Charcoal"].append(RB(dx * 2.4 - 0.5, dx * 2.4 + 0.5, -0.05, 0.3, dz * 2.4 - 0.5, dz * 2.4 + 0.5, BT, ST))
			for ox, oz in ((0.33, 0.33), (-0.33, -0.33), (0.33, -0.33), (-0.33, 0.33)):
				P["Metal"].append(RB(dx * 2.4 + ox - 0.07, dx * 2.4 + ox + 0.07, 0.29, 0.4, dz * 2.4 + oz - 0.07, dz * 2.4 + oz + 0.07))
			ow = 0.24 if dx > 0 else 0.22  # opposite outriggers share a diagonal plane: unequal widths
			P["Charcoal"].append(beam((dx * 2.7, 3.1, dz * 2.7), (dx * 3.85, 4.4, dz * 3.85), ow, ow))
	for s in (1, -1):
		P["Charcoal"].append(RB(-3.15, 3.15, 3.95, 4.42, s * 2.8 - 0.26, s * 2.8 + 0.26, BT, ST))
		P["Charcoal"].append(RB(s * 2.8 - 0.24, s * 2.8 + 0.24, 3.97, 4.4, -2.54, 2.54, BT, ST))
		P["Charcoal"].append(beam((-2.3, 0.45, s * 2.42), (2.55, 3.9, s * 2.74), 0.22, 0.22))
		P["Charcoal"].append(beam((2.3, 0.45, s * 2.46), (-2.55, 3.9, s * 2.78), 0.22, 0.22))
		P["Charcoal"].append(beam((s * 2.42, 0.45, -2.3), (s * 2.74, 3.9, 2.55), 0.22, 0.22))
		P["Charcoal"].append(beam((s * 2.46, 0.45, 2.3), (s * 2.78, 3.9, -2.55), 0.22, 0.22))
	# platform with a railing round the drum's foot
	P["Charcoal"].append(lathe([(5.6, 4.62), (5.6, 4.42), (0.0, 4.42)], steps=24))  # steel underside
	P["Metal"].append(lathe([(0.0, 4.64), (5.6, 4.64)], steps=24))
	for k in range(12):
		a = 2 * math.pi * k / 12
		P["Charcoal"].append(RB(5.35 * math.cos(a) - 0.16, 5.35 * math.cos(a) + 0.16, 4.62, 7.6, 5.35 * math.sin(a) - 0.16, 5.35 * math.sin(a) + 0.16))
	P["Charcoal"].append(lathe([(5.5, 7.85), (5.5, 7.55)], steps=24))
	P["Charcoal"].append(lathe([(5.2, 7.55), (5.2, 7.85)], steps=24))
	# drum: 24 timber staves round a dark core, two steel hoops
	P["Charcoal"].append(lathe([(4.15, 13.7), (4.15, 4.65)], steps=24))
	for k in range(23):  # an odd count: no two staves' chamfers share a plane (90-degree symmetry)
		bm = RB(3.95, 4.45, 4.65, 13.75, -0.52, 0.52, BT, ST)
		xform(bm, RZ(360.0 * k / 23))
		P["Wood"].append(bm)
	for y in (6.6, 11.4):
		P["Charcoal"].append(lathe([(4.45, y + 0.4), (4.6, y + 0.4), (4.6, y), (4.45, y)], steps=24))
	# conical cap with a lip and a finial
	cap = [(4.85, 13.6), (4.85, 14.0), (0.5, 16.2), (0.0, 16.3)][::-1] + [(4.15, 13.6)]
	P["Charcoal"].append(lathe(cap, steps=24))
	P["Charcoal"].append(lathe([(0.0, 17.4), (0.22, 17.1), (0.3, 16.6), (0.18, 16.2)], steps=10))
	# maps v5: Codex's caged ladder (platform to cap) and the valve wheel on its overflow pipe (R3, kit scale, drum
	# bottom axis origin; +0.3 up to our drum). The floating sign loop off the drum is cut (the user's v4 review).
	P["Charcoal"] += codex_tank_parts()
	emit(c, P)


def codex_tank_parts():
	"""R3 TankDetailKit: keep the caged ladder above the platform and the valve, pipe and its brackets; drop Codex's
	railing, hoops and cap (ours stay). Returns bmeshes in Blender coords (Roblox x, -z, y)."""
	before = set(bpy.data.objects)
	bpy.ops.import_scene.gltf(filepath=os.path.join(PROPS, "TankDetailKit.glb"))
	new = [o for o in bpy.data.objects if o not in before]
	bpy.context.view_layer.update()
	src = [o for o in new if o.type == "MESH" and o.name.endswith("Charcoal")][0]
	bm = bmesh.new()
	bm.from_mesh(src.data)
	bm.transform(src.matrix_world)
	for o in new:
		bpy.data.objects.remove(o)
	# islands on a welded copy (Codex splits every face for flat shading); the faces keep their order
	wb = bm.copy()
	bmesh.ops.remove_doubles(wb, verts=wb.verts, dist=0.0005)
	wb.faces.ensure_lookup_table()
	bm.faces.ensure_lookup_table()
	keep = set()
	seen = set()
	for f0 in wb.faces:
		if f0.index in seen:
			continue
		stack, isl = [f0], []
		seen.add(f0.index)
		while stack:
			f = stack.pop()
			isl.append(f.index)
			for e in f.edges:
				for g in e.link_faces:
					if g.index not in seen:
						seen.add(g.index)
						stack.append(g)
		vs = [v.co for i in isl for v in wb.faces[i].verts]
		x0, x1 = min(v.x for v in vs), max(v.x for v in vs)
		y0, y1 = min(v.y for v in vs), max(v.y for v in vs)
		ladder = x0 > -0.95 and x1 < 0.95 and y1 < -4.3
		valve = x0 >= 4.38 and y0 >= -0.45 and y1 <= 0.65
		if ladder or valve:
			keep.update(isl)
	wb.free()
	bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index not in keep], context="FACES")
	bmesh.ops.translate(bm, verts=bm.verts, vec=(0.0, 0.0, 0.3))
	# the ladder starts on the platform: cut the stiles inside the platform slab (4.42-4.64)
	bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0.0, 0.0, 4.55), plane_no=(0.0, 0.0, 1.0), clear_inner=True)
	bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
	return [bm]


# ---- stone Pit stair (8 wide, 16 run, rising 8 toward +Z) with cheek walls and cobalt caps

def stone_stair(name="Stair16"):
	c = piece(name)
	P = roles()
	for k in range(1, 10):
		z0 = -8 + 1.6 * k
		z1 = min(z0 + 1.6, 7.97)
		top = 0.8 * k - 0.03
		P["Stone"].append(RB(-3.3, 3.3, top - 0.8, top, z0, z1, 0.08, 1))
	cheek = [(-7.98, -0.15), (-5.4, -0.15), (7.97, 7.2), (7.97, 10.3), (-7.98, 2.9)]
	for s in (1, -1):
		P["Wall"].append(RPX(cheek, s * 3.3, s * 4.0, BSN, 1))
		cop = [(-7.98, 2.85), (7.97, 10.25), (7.97, 10.65), (-7.98, 3.25)]
		P["Stone"].append(RPX(cop, s * 3.2, s * 4.12, BT, ST))
		for zc, yc in ((-7.2, 3.3), (7.2, 10.6)):
			a, b = sorted((s * 3.1, s * 4.2))
			P["Stone"].append(RB(a, b, yc - 3.4, yc + 0.3, zc - 0.55, zc + 0.55, BT, ST))
			P["Accent"].append(frustum(a - 0.12, b + 0.12, zc - 0.67, zc + 0.67, yc + 0.3, yc + 0.75, 0.12, 0.12, BT))
	emit(c, P)


# ---- plank bridge on steel trusses (8 wide, 16 run, rising 8 toward +Z) and the flat footbridge (8 x 8)

def truss_side(P, x, z0, z1, y0f, y1f, h):
	# a Warren truss along Z on side x: bottom chord on the deck line, top chord h above, diagonals
	n = 4
	P["Charcoal"].append(beam((x, y0f - 0.2, z0), (x, y1f - 0.2, z1), 0.4, 0.5))
	P["Charcoal"].append(beam((x, y0f + h, z0), (x, y1f + h, z1), 0.4, 0.4))
	for k in range(n + 1):
		zz = z0 + (z1 - z0) * k / n
		yy = y0f + (y1f - y0f) * k / n
		P["Charcoal"].append(beam((x, yy - 0.2, zz), (x, yy + h, zz), 0.35, 0.35))
		if k < n:
			z2 = z0 + (z1 - z0) * (k + 1) / n
			y2 = y0f + (y1f - y0f) * (k + 1) / n
			a, b = ((yy - 0.1, zz), (y2 + h, z2)) if k % 2 == 0 else ((yy + h, zz), (y2 - 0.1, z2))
			P["Charcoal"].append(beam((x, a[0], a[1]), (x, b[0], b[1]), 0.26 if k % 2 == 0 else 0.22, 0.26))


def plank_bridge(name, rise):
	c = piece(name)
	P = roles()
	run = 16.0 if rise else 8.0
	z0, z1 = -run / 2 + 0.02, run / 2 - 0.03
	n = int(run / 1.0)
	for k in range(n):
		za = z0 + (z1 - z0) * k / n + 0.04
		zb = z0 + (z1 - z0) * (k + 1) / n - 0.04
		ym = (rise * ((za + zb) / 2 - z0) / (z1 - z0)) if rise else 0.0
		bm = RB(-3.55, 3.55, ym - 0.32, ym - 0.03, za, zb, BT, ST)
		xform(bm, T(0, 0, 0) @ RZ(((k * 37) % 5 - 2) * 0.4))  # small yaw jitter, planks laid by hand
		P["Wood"].append(bm)
	for s in (1, -1):
		truss_side(P, s * 3.85, z0, z1, 0.0, float(rise), 3.3)
		P["Charcoal"].append(beam((s * 2.0, -0.55, z0), (s * 2.0, rise - 0.55, z1), 0.35, 0.5))
	emit(c, P)


def gangway2():
	# the side-lane fire-escape stair: steel, 8 wide, 16 run, rising 8 toward +Z
	c = piece("Gangway16")
	P = roles()
	for k in range(1, 10):
		z0 = -8 + 1.6 * k
		z1 = min(z0 + 1.6, 7.97)
		top = 0.8 * k - 0.03
		P["Metal"].append(RB(-3.3, 3.3, top - 0.22, top, z0, z1, BT, ST))
		P["Charcoal"].append(RB(-3.3, 3.3, top - 0.6, top - 0.22, z0 + 1.2, z1))
	strg = [(-7.98, -0.1), (-6.4, -0.1), (7.97, 7.0), (7.97, 8.3), (-7.98, 0.9)]
	for s in (1, -1):
		P["Charcoal"].append(RPX(strg, s * 3.3, s * 3.85, BST, 1))
		for zp in (-7.4, -2.5, 2.5, 7.4):
			yb = (zp + 8) / 2
			P["Charcoal"].append(RB(s * 3.45 - 0.2, s * 3.45 + 0.2, yb, yb + 3.4, zp - 0.2, zp + 0.2, BT, ST))
		P["Charcoal"].append(beam((s * 3.45, 3.4, -7.9), (s * 3.45, 11.35, 7.9), 0.32, 0.34))
		P["Charcoal"].append(beam((s * 3.45, 1.7, -7.9), (s * 3.45, 9.65, 7.9), 0.24, 0.24))
	emit(c, P)


# ---- small buildings: huts with quoins, arched doors and a low hip roof inside their height

def hut2(name, W, Dp, H, door="+X", vent=False, roof=True, roof_role="RoofTile", windows=False):
	c = piece(name, width=W, depth=Dp, height=H)
	P = roles()
	hx, hz = W / 2, Dp / 2
	wall_top = H - 1.3 if roof else H - 0.6
	ql = 0.9 if min(W, Dp) <= 6 else 1.1  # quoin length: the door surround fits between the corners
	P["Plinth"].append(RB(-hx - 0.25, hx + 0.25, -0.1, 0.9, -hz - 0.25, hz + 0.25, BSN, 1))
	P["Wall"].append(RB(-hx, hx, 0.9, wall_top, -hz, hz, BT, ST))
	for sx in (1, -1):
		for sz in (1, -1):
			quoins_corner(sx * hx, sz * hz, sx, sz, 0.9, wall_top - 0.1, P, ql)
	P["Stone"].append(RB(-hx - 0.45, hx + 0.45, wall_top - 0.1, wall_top + 0.45, -hz - 0.45, hz + 0.45, BT, ST))
	if roof:
		P[roof_role].append(frustum(-hx - 0.5, hx + 0.5, -hz - 0.5, hz + 0.5, wall_top + 0.45, H - 0.03, min(hx, hz) * 0.55, min(hx, hz) * 0.55, BT))
		P["Stone"].append(RB(-hx * 0.45, hx * 0.45, H - 0.1, H, -hz * 0.45, hz * 0.45))
	else:  # flat top (the tank stand sits on it): a stone deck inside the cornice
		P["Stone"].append(RB(-hx - 0.1, hx + 0.1, wall_top + 0.45, H, -hz - 0.1, hz + 0.1, BT, ST))
	# Maps v4 scale audit: doors 3.2 x 6.6 where the hut has room (was 2.3 x 5.7 on the 6-wide huts; R15 is 5)
	dw = min(3.2, (Dp if door == "+X" else W) - 2 * ql - 1.2)
	dh = min(6.6, wall_top - 1.25)
	if windows:  # arched windows on the two faces beside the door face (door +X)
		for sg in (1, -1):
			window_z(0.0, 2.4, 1.6, 3.4, sg * hz, P, shutters=min(W, Dp) >= 10)
	if door == "+X":
		P["Door"].append(RPX(arch_pts(dw - 0.1, dh, 0.95), hx - 0.18, hx + 0.02))
		P["Stone"].append(arch_ring_x(dw + 1.1, dh + 0.55, 0.55, 0.92, hx - 0.05, hx + 0.3))
	else:
		P["Door"].append(RPZ(arch_pts(dw - 0.1, dh, 0.95), hz - 0.18, hz + 0.02))
		P["Stone"].append(arch_ring_z(dw + 1.1, dh + 0.55, 0.55, 0.92, hz - 0.05, hz + 0.3))
	if vent:
		P["Metal"].append(RB(-0.9, 0.9, H - 0.05, H + 1.0, -0.9, 0.9, BT, ST))
	emit(c, P)
	return c


def lift_tower2():
	c = hut2("LiftTower", 10, 8, 16, door="+X", roof=False)
	P = roles()
	for s in (1, -1):
		window_z(0.0, 8.4, 1.8, 3.6, s * 4.0, P, shutters=True)
	# maps v5 round 2: windows on the X faces too (upper over the door; both rows on the blank -X face), string
	# courses under each row, and a downpipe off the cornice
	X = roles()
	window_x(0.0, 8.4, 1.8, 3.6, True, X, shutters=True)
	for role, bms in X.items():
		for bm in bms:
			b2 = bm.copy()
			xform(bm, T(5.0, 0.0, 0.0))
			xform(b2, T(-5.0, 0.0, 0.0) @ RZ(180.0))
			P[role] += [bm, b2]
	Y = roles()
	window_x(0.0, 2.2, 1.8, 3.4, True, Y, shutters=True)
	for role, bms in Y.items():
		for bm in bms:
			xform(bm, T(-5.0, 0.0, 0.0) @ RZ(180.0))
			P[role].append(bm)
	for y in (6.97, 13.12):
		P["Stone"].append(RB(-5.16, 5.16, y, y + 0.36, -4.16, 4.16, 0.05, 1))
	downpipe(P, -3.4, -4.0, 0.9, 15.2, (0, -1))
	emit(c, P, "Upper")


def downpipe(P, x, z, y0, y1, corner):
	"""A cast downpipe down a wall (Roblox coords): hopper head under the cornice, pipe, wall brackets, a kicked
	shoe at the foot. corner = (sx, sz) the wall's outward normal (one of them 0); the pipe sits 0.3 off it."""
	sx, sz = corner
	px, pz = x + sx * 0.3, z + sz * 0.3
	P["Charcoal"].append(RB(px - 0.42, px + 0.42, y1 - 0.9, y1 - 0.2, pz - 0.42, pz + 0.42, 0.06, 1))
	P["Charcoal"].append(RB(px - 0.3, px + 0.3, y1 - 1.25, y1 - 0.9, pz - 0.3, pz + 0.3, 0.05, 1))
	P["Charcoal"].append(RB(px - 0.17, px + 0.17, y0 + 0.5, y1 - 1.25, pz - 0.17, pz + 0.17, 0.05, 1))
	P["Charcoal"].append(beam((px, y0 + 0.62, pz), (px + sx * 0.55, y0 + 0.1, pz + sz * 0.55), 0.34, 0.34))
	k = 0
	y = y0 + 2.0
	while y < y1 - 2.0:
		w = 0.24 if k % 2 == 0 else 0.22
		P["Metal"].append(RB(px - w, px + w, y, y + 0.16, pz - w, pz + w))
		for d in ((-sx, 0), (0, -sz)):
			a, b = sorted((px, px + d[0] * 0.42)) if d[0] else (px - 0.05, px + 0.05)
			c0, c1 = sorted((pz, pz + d[1] * 0.42)) if d[1] else (pz - 0.05, pz + 0.05)
			P["Metal"].append(RB(a, b, y + 0.02, y + 0.14, c0, c1))
		y += 3.2
		k += 1


# ---- props

def ac2():
	c = piece("ACUnit")
	P = roles()
	P["Charcoal"].append(RB(-4.0, 4.0, -0.1, 0.5, -2.0, 2.0, BT, ST))
	for sx in (-3.4, 3.4):
		P["Charcoal"].append(RB(sx - 0.25, sx + 0.25, 0.5, 1.0, -1.9, 1.9, BT, ST))
	for y0, y1 in ((1.0, 3.95), (4.15, 7.2)):
		P["Appliance"].append(RB(-3.8, 3.8, y0, y1, -1.8, 1.8, 0.22, 1))
		for s in (1, -1):
			fz = s * 1.8
			disc = lathe([(0.0, 0.0), (1.05, 0.0)], steps=16)
			xform(disc, T(-1.5, -(fz + s * 0.06), (y0 + y1) / 2) @ RX(90 * s))
			P["Metal"].append(disc)
			yc = (y0 + y1) / 2
			a2, b2 = sorted((fz + s * 0.07, fz + s * 0.2))
			P["Charcoal"].append(RB(-1.6 - 0.1, -1.6 + 0.1 + 0.2, yc - 1.0, yc + 1.0, a2, b2))  # grille bars
			P["Charcoal"].append(RB(-2.5, -0.5, yc - 0.1, yc + 0.1, *sorted((fz + s * 0.08, fz + s * 0.18))))
			hub = lathe([(0.0, 0.0), (0.3, 0.0)], steps=10)
			xform(hub, T(-1.5, -(fz + s * 0.22), yc) @ RX(90 * s))
			P["Charcoal"].append(hub)
			ring = lathe([(1.25, 0.0), (1.05, 0.0)], steps=16)
			xform(ring, T(-1.5, -(fz + s * 0.1), (y0 + y1) / 2) @ RX(90 * s))
			P["Stone"].append(ring)
			for k in range(5):
				y = y0 + 0.5 + k * (y1 - y0 - 1.0) / 4
				a, b = sorted((fz, fz + s * 0.12))
				P["Charcoal"].append(RB(0.4, 3.3, y - 0.07, y + 0.07, a, b))
	emit(c, P)


def skylight2():
	c = piece("Skylight")
	P = roles()
	P["Stone"].append(RB(-4.0, 4.0, -0.1, 1.1, -2.0, 2.0, BSN, 1))
	P["Glass"].append(frustum(-3.6, 3.6, -1.6, 1.6, 1.1, 2.9, 2.2, 1.35))
	for sx in (-1, 1):
		for sz in (-1, 1):
			P["Charcoal"].append(beam((sx * 3.6, 1.1, sz * 1.6), (sx * 1.4, 2.9, sz * 0.25), 0.18, 0.18))
	P["Charcoal"].append(RB(-1.5, 1.5, 2.85, 3.0, -0.3, 0.3, BT, ST))
	for x in (-1.2, 1.2):
		for s in (1, -1):
			P["Charcoal"].append(beam((x * 1.5, 1.1, s * 1.6), (x * 0.9, 2.9, s * 0.25), 0.12, 0.12))
	emit(c, P)


def planter2():
	c = piece("Planter")
	P = roles()
	P["Pot"].append(frustum(-3.0, 3.0, -1.5, 1.5, -0.1, 2.5, -0.15, -0.1, BT))
	P["Stone"].append(RB(-3.25, 3.25, 2.45, 2.75, -1.75, 1.75, BT, ST))
	# a clipped hedge of three overlapping lumps (full cover to 7.5), not one box
	for x, w, top in ((-1.6, 2.6, 7.0), (0.2, 2.9, 7.45), (1.9, 2.3, 6.6)):
		P["Plant"].append(RB(x - w / 2, x + w / 2, 2.6, top, -1.25, 1.25, 0.7, 2))
	emit(c, P)


def crate(name="Crate", s=3.0):
	c = piece(name)
	P = roles()
	h = s / 2
	P["Wood"].append(RB(-h + 0.12, h - 0.12, 0.05, s - 0.05, -h + 0.12, h - 0.12, BT, ST))
	for a in (-1, 1):
		for b in (-1, 1):
			P["Charcoal"].append(RB(min(a * h, a * (h - 0.32)), max(a * h, a * (h - 0.32)), 0.0, s, min(b * h, b * (h - 0.32)), max(b * h, b * (h - 0.32)), BT, ST))
	for f in (-1, 1):  # diagonal braces on two faces
		zf = f * (h - 0.06)
		P["Wood"].append(beam((-h + 0.4, 0.4, zf), (h - 0.4, s - 0.4, zf), 0.35, 0.18))
		xf = f * (h - 0.06)
		P["Wood"].append(beam((xf, 0.4, h - 0.4), (xf, s - 0.4, -h + 0.4), 0.18, 0.35, up=(0.0, 0.0, 1.0)))
	emit(c, P)


def barrel():
	c = piece("Barrel")
	P = roles()
	P["Wood"].append(lathe([(0.0, 2.6), (0.85, 2.6), (1.0, 1.9), (1.05, 1.3), (1.0, 0.7), (0.85, 0.0)][::-1][::-1], steps=14))
	for y in (0.45, 2.15):
		P["Charcoal"].append(lathe([(1.03 if y > 1 else 0.95, y + 0.2), (1.03 if y > 1 else 0.95, y)], steps=14))
	emit(c, P)


def party_corner():
	# a rooftop party left half-set: an awning on posts, string lights, two folding chairs, a table, a cooler
	c = piece("PartyCorner")
	P = roles()
	for x, z in ((-3.4, -2.2), (3.4, -2.2), (-3.4, 2.2), (3.4, 2.2)):
		P["Wood"].append(RB(x - 0.2, x + 0.2, 0.0, 7.2 if z > 0 else 6.4, z - 0.2, z + 0.2, BT, ST))
	P["Cloth"].append(RPX([(-2.5, 6.25), (2.5, 7.05), (2.5, 7.25), (-2.5, 6.45)], -3.75, 3.75, BT, ST))
	for k in range(9):
		x = -3.4 + 6.8 * k / 8
		sag = 0.35 * math.sin(math.pi * k / 8)
		P["GlowWarm"].append(RB(x - 0.12, x + 0.12, 6.0 - sag - 0.12, 6.0 - sag + 0.12, -2.25, -2.1))
	P["Wood"].append(lathe([(0.0, 2.3), (1.1, 2.3), (1.1, 2.1), (0.15, 2.1), (0.15, 0.0)], steps=12))
	for x, yaw in ((-1.9, 15), (1.9, -20)):
		ch = merge(RB(-0.6, 0.6, 1.3, 1.45, -0.6, 0.6, BT, ST), RB(-0.6, 0.6, 1.45, 2.9, 0.5, 0.65, BT, ST), beam((-0.55, 0.0, -0.55), (-0.55, 1.35, 0.55), 0.14), beam((0.55, 0.0, -0.55), (0.55, 1.35, 0.55), 0.14), beam((-0.55, 0.0, 0.55), (-0.55, 1.35, -0.55), 0.14), beam((0.55, 0.0, 0.55), (0.55, 1.35, -0.55), 0.14))
		xform(ch, T(x, 0, 0) @ RZ(yaw))
		P["Cloth"].append(ch)
	P["AccentSoft"].append(RB(1.0, 3.0, 0.0, 1.4, 0.9, 2.0, 0.15, 1))
	P["Stone"].append(RB(1.05, 2.95, 1.4, 1.6, 0.95, 1.95, BT, ST))
	emit(c, P)




# ---- fix round 1 (2026-11-05 evening): modelled pier caps, blank trestle billboards, city blocks with silhouettes

def pier_cap():
	# Origin: bottom centre of the greybox cap (1.6 square, 0.2 tall at pier top). A chunky cobalt cap: a chamfered
	# slab and a hipped top, 0.75 tall (above the collision; visual only), as on the concept's parapets.
	c = piece("PierCap")
	P = roles()
	# maps v5: a size smaller (was 1.84 square, 0.76 tall; read heavy along the parapets)
	P["Accent"].append(RB(-0.87, 0.87, -0.02, 0.22, -0.87, 0.87, 0.06, 1))
	P["Accent"].append(frustum(-0.78, 0.78, -0.78, 0.78, 0.22, 0.46, 0.34, 0.34, 0.04))
	emit(c, P)


def billboard3():
	# Billboard22 (floor centre between the legs, legs at x +-7, panel 22 x 10 at 9-19, face +Z): toned down after
	# the v2 side by side so the tank stays the one landmark: a blank cream panel in a charcoal frame on two braced
	# steel trestles with a service catwalk, cobalt caps on the trestle tops (the concept's language). No words.
	c = piece("Billboard22")
	P = roles()
	for x in (-7.0, 7.0):
		for dz in (-0.9, 0.9):
			P["Charcoal"].append(beam((x - 0.9, 0.0, dz), (x - 0.7, 19.6, dz * 0.6), 0.36, 0.36))
			P["Charcoal"].append(beam((x + 0.9, 0.0, dz), (x + 0.7, 19.6, dz * 0.6), 0.36, 0.36))
		for y0, y1 in ((0.6, 4.6), (4.6, 8.6)):
			P["Charcoal"].append(beam((x - 0.85, y0, 0.0), (x + 0.8, y1, 0.0), 0.2, 0.2))
			P["Charcoal"].append(beam((x + 0.85, y0, 0.0), (x - 0.8, y1, 0.0), 0.18, 0.2))
		P["Charcoal"].append(RB(x - 1.2, x + 1.2, -0.05, 0.35, -1.2, 1.2, BT, ST))
		P["Accent"].append(frustum(x - 1.0, x + 1.0, -0.75, 0.75, 19.6, 20.25, 0.3, 0.2, 0.06))
	# service catwalk along the front under the panel, with a rail
	P["Metal"].append(RB(-10.8, 10.8, 8.3, 8.6, 0.4, 2.0, BT, ST))
	for x in [-10.4 + 2.6 * k for k in range(9)]:
		P["Charcoal"].append(RB(x - 0.16, x + 0.16, 8.6, 10.9, 1.7, 2.0))
	P["Charcoal"].append(RB(-10.8, 10.8, 10.9, 11.15, 1.65, 2.05, BT, ST))
	ring = ring_prism(rrect(22.0, 10.0, 0.4, 2, 0.0, 14.0), rrect(21.0, 9.0, 0.25, 2, 0.0, 14.0), -0.5, 0.5, "Y")
	P["Charcoal"].append(finish(ring, BT, 1))
	P["Cloth"].append(RB(-10.55, 10.55, 9.5, 18.5, -0.32, 0.32))
	for x in (-6.0, 0.0, 6.0):
		P["Charcoal"].append(RB(x - 0.1, x + 0.1, 18.9, 19.9, 0.3, 1.4))
		P["Charcoal"].append(RB(x - 0.5, x + 0.5, 19.6, 20.0, 1.0, 1.8, BT, ST))
		P["GlowWarm"].append(RB(x - 0.4, x + 0.4, 19.5, 19.62, 1.1, 1.7))
	emit(c, P)


def city2(name, W, Dp, H, seed):
	# Backdrop block (base centre, front +X): a plinth, a main shaft with recessed window rows and pier strips, a
	# cornice, a setback upper storey, and roof furniture (a small tank, a stair hut, an antenna), so the skyline
	# reads as buildings, not striped slabs (LihFolk Spending Triangles Where the Camera Looks: simple, but real
	# silhouettes). Colour by tone (Wall role) and the map's haze.
	c = piece(name, height=H)
	P = roles()
	hx, hz = W / 2, Dp / 2
	top = H * 0.82
	P["Wall"].append(RB(-hx, hx, 0.0, top, -hz, hz))
	P["Stone"].append(RB(-hx - 0.4, hx + 0.4, -0.05, 6.0, -hz - 0.4, hz + 0.4))
	P["Stone"].append(RB(-hx - 0.9, hx + 0.9, top - 0.2, top + 1.4, -hz - 0.9, hz + 0.9))
	for y in range(9, int(top) - 4, 8):
		P["Window"].append(RB(hx - 0.05, hx + 0.02, y, y + 4.0, -hz + 1.5, hz - 1.5))
		P["Window"].append(RB(-hx + 1.5, hx - 1.5, y, y + 4.0, hz - 0.02, hz + 0.05))
		P["Window"].append(RB(-hx + 1.5, hx - 1.5, y, y + 4.0, -hz - 0.05, -hz + 0.02))
		P["Window"].append(RB(-hx - 0.02, -hx + 0.05, y, y + 4.0, -hz + 1.5, hz - 1.5))
	for t in [-hz + 1.5 + 3.0 * k for k in range(int((Dp - 3) / 3) + 1)]:
		P["Wall"].append(RB(hx - 0.01, hx + 0.35, 6.0, top - 0.2, t - 0.45, t + 0.45))
		P["Wall"].append(RB(-hx - 0.35, -hx + 0.01, 6.0, top - 0.2, t - 0.45, t + 0.45))
	for t in [-hx + 1.5 + 3.0 * k for k in range(int((W - 3) / 3) + 1)]:
		P["Wall"].append(RB(t - 0.45, t + 0.45, 6.0, top - 0.2, hz - 0.01, hz + 0.35))
		P["Wall"].append(RB(t - 0.45, t + 0.45, 6.0, top - 0.2, -hz - 0.35, -hz + 0.01))
	# setback storey and its cornice
	sx, sz = hx * (0.55 + 0.15 * (seed % 2)), hz * 0.7
	P["Wall"].append(RB(-sx, sx, top + 1.4, H - 0.8, -sz, sz))
	P["Stone"].append(RB(-sx - 0.5, sx + 0.5, H - 0.8, H, -sz - 0.5, sz + 0.5))
	# roof furniture
	tx, tz = (hx * 0.6, -hz * 0.55) if seed % 2 else (-hx * 0.55, hz * 0.5)
	for dx in (-1.2, 1.2):
		for dz in (-1.2, 1.2):
			P["Charcoal"].append(RB(tx + dx - 0.15, tx + dx + 0.15, top + 1.3, top + 4.0, tz + dz - 0.15, tz + dz + 0.15))
	P["Wood"].append(lathe_at(tx, tz, [(0.0, top + 9.2), (1.9, top + 8.0), (1.9, top + 4.0)], 12))
	if seed % 3 == 0:
		P["Charcoal"].append(RB(-0.2, 0.2, H, H + 9.0, -0.2, 0.2))
		P["Charcoal"].append(RB(-1.6, 1.6, H + 5.0, H + 5.2, -0.1, 0.1))
	emit(c, P)




# ---- maps v4 (2026-11-05 late): the weak pieces rebuilt as real models (vault/01 Design/Maps/Rooftops2.md ->
# Maps v4). The user's review: the cacti (Planter lumps), the wheelbarrow (Skylight on splayed legs), toy AC stacks,
# part-built text, oversized quoins, flat roof floors. LihFolk roblox-blender-modeling: 1-segment soft bevels,
# confident tapered silhouettes, budgets small 600/1,500 and medium 2,000/4,000; LihFolk World Composition: signs
# built into the art or cut, landmarks guide before text.

def drop_down(bm):
	# Flat floor art lies on the roof (y 0): drop the bottom faces so nothing shares the roof's top plane.
	bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.normal.z < -0.99], context="FACES")
	return bm


def blade(bx, by, bz, yaw, tilt, length, width, droop):
	"""An agave leaf: a tapered blade with a channelled top and a keeled underside, rising at tilt (deg) toward
	yaw (deg, 0 = +X) and drooping toward the tip. Roblox coordinates; ~38 triangles."""
	bm = bmesh.new()
	ca, sa = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
	sx, sz = -sa, ca
	n = 4
	rings = []
	for i in range(n):
		t = i / n
		d = length * t * math.cos(math.radians(tilt))
		y = by + length * t * math.sin(math.radians(tilt)) - droop * length * t * t
		px, pz = bx + ca * d, bz + sa * d
		w = width / 2 * (1 - t) * (1 + 0.6 * t)
		f = max(0.03, w * 0.5)
		sec = [(w, f * 0.35), (0.0, -f * 0.15), (-w, f * 0.35), (0.0, -f)]
		rings.append([bm.verts.new(rb(px + sx * u, y + v, pz + sz * u)) for u, v in sec])
	d = length * math.cos(math.radians(tilt))
	tip = bm.verts.new(rb(bx + ca * d, by + length * math.sin(math.radians(tilt)) - droop * length, bz + sa * d))
	for a, b in zip(rings, rings[1:]):
		for k in range(4):
			j = (k + 1) % 4
			bm.faces.new((a[k], a[j], b[j], b[k]))
	for k in range(4):
		bm.faces.new((rings[-1][k], rings[-1][(k + 1) % 4], tip))
	bm.faces.new(list(reversed(rings[0])))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	return bm


def agave(cx, y, cz, s, seed, parts, role="Plant"):
	# A rosette: 4 upright inner blades, 5 spreading, 4 low drooping ones, on a golden-angle spiral.
	g = 137.5
	k = seed * 31.0
	for i in range(4):
		parts[role].append(blade(cx, y, cz, k + g * i, 72, 1.45 * s, 0.42 * s, 0.05))
	for i in range(5):
		parts[role].append(blade(cx, y, cz, k + 60 + g * i, 46, 1.85 * s, 0.5 * s, 0.22))
	for i in range(4):
		parts[role].append(blade(cx, y, cz, k + 20 + g * i, 18, 1.8 * s, 0.48 * s, 0.32))


def planter3():
	# Planter 6 x 3 x 7.5 (full cover): a plaster planter box with a stone cap and cobalt corner caps, agave
	# rosettes either side of a timber slat screen on charcoal posts (so the cover box is a designed thing, and
	# the plants read as plants, not green lumps). Concept: kit sheet planters, 03-hero-spawn-a foreground.
	c = piece("Planter")
	P = roles()
	P["Stone"].append(RB(-3.0, 3.0, -0.05, 0.35, -1.5, 1.5, BT, ST))
	P["Pot"].append(RB(-2.88, 2.88, 0.3, 2.32, -1.38, 1.38, BT, ST))
	for x in (-1.45, 1.45):  # two recessed panels per long face, as on the concept's planters
		for s in (1, -1):
			a, b = sorted((s * 1.38, s * 1.44))
			P["Stone"].append(RB(x - 1.15, x + 1.15, 0.75, 1.95, a, b, BT, ST))
	P["Stone"].append(RB(-3.12, 3.12, 2.3, 2.6, -1.62, 1.62, BT, ST))
	P["Door"].append(drop_down(RB(-2.7, 2.7, 2.6, 2.7, -1.2, 1.2)))  # soil
	for sx in (-1, 1):
		for sz in (-1, 1):
			P["Accent"].append(frustum(sx * 2.85 - 0.36, sx * 2.85 + 0.36, sz * 1.35 - 0.36, sz * 1.35 + 0.36, 2.6, 3.0, 0.14, 0.14, 0.04))
	# the screen: posts, slats (alternating depth so no two share a plane), a cap rail with cobalt post caps
	for x in (-2.55, 0.0, 2.55):
		P["Charcoal"].append(RB(x - 0.17, x + 0.17, 2.62, 7.1, -0.17, 0.17, BT, ST))
	for k in range(8):
		y0 = 2.85 + k * 0.53
		o = 0.025 * (k % 2)
		P["Wood"].append(RB(-2.42, 2.42, y0, y0 + 0.46, -0.09 + o, 0.07 + o, BT, ST))
	P["Wood"].append(RB(-2.3, 2.3, 7.05, 7.3, -0.2, 0.2, BT, ST))
	for x in (-2.55, 2.55):
		P["Accent"].append(frustum(x - 0.27, x + 0.27, -0.27, 0.27, 7.1, 7.5, 0.1, 0.1, 0.03))
	for i, (x, z, s) in enumerate(((-1.45, 0.72, 1.2), (1.5, 0.75, 1.0), (-1.3, -0.74, 1.05), (1.45, -0.72, 1.22))):
		agave(x, 2.66, z, s, i + 1, P)
	emit(c, P)


def skylight3():
	# Skylight 8 x 4 x 3: the concept's hipped skylight on a stone curb: a mullioned glass hip in a charcoal frame,
	# a cream lip and cobalt corner caps. No legs (the v3 one read as a wheelbarrow).
	c = piece("Skylight")
	P = roles()
	P["Stone"].append(RB(-3.9, 3.9, -0.1, 1.0, -1.9, 1.9, BT, ST))
	P["Trim"].append(RB(-4.0, 4.0, 1.0, 1.2, -2.0, 2.0, BT, ST))
	P["Glass"].append(frustum(-3.55, 3.55, -1.55, 1.55, 1.25, 2.6, 1.7, 1.4))
	P["Charcoal"].append(ring_prism(rrect(7.3, 3.3, 0.05, 1, 0.0, 0.0), rrect(6.9, 2.9, 0.03, 1, 0.0, 0.0), 1.18, 1.36, "Z"))
	for sx in (-1, 1):
		for sz in (-1, 1):
			P["Charcoal"].append(beam((sx * 3.55, 1.3, sz * 1.55), (sx * 1.85, 2.6, sz * 0.15), 0.16, 0.16))
	P["Charcoal"].append(beam((-1.95, 2.62, 0.0), (1.95, 2.62, 0.0), 0.2, 0.2))
	for x in (-1.15, 0.0, 1.15):
		for s in (1, -1):
			P["Charcoal"].append(beam((x, 1.3, s * 1.55), (x, 2.6, s * 0.15), 0.1, 0.1))
	for sx in (-1, 1):
		for sz in (-1, 1):
			P["Accent"].append(frustum(sx * 3.75 - 0.32, sx * 3.75 + 0.32, sz * 1.75 - 0.32, sz * 1.75 + 0.32, 1.2, 1.62, 0.12, 0.12, 0.03))
	emit(c, P)


def louvre_x(x0, x1, y0, y1, face, P, n):
	# A louvre panel on a wall facing +-Z (plane z = face): a charcoal frame ring and n slanted blades.
	sg = 1 if face > 0 else -1
	a, b = sorted((face, face + sg * 0.1))
	P["Charcoal"].append(RB(x0, x1, y0, y0 + 0.16, a, b))
	P["Charcoal"].append(RB(x0, x1, y1 - 0.16, y1, a, b))
	P["Charcoal"].append(RB(x0, x0 + 0.16, y0 + 0.16, y1 - 0.16, a, b))
	P["Charcoal"].append(RB(x1 - 0.16, x1, y0 + 0.16, y1 - 0.16, a, b))
	step = (y1 - y0 - 0.32) / n
	for k in range(n):
		y = y0 + 0.16 + step * (k + 0.5)
		pts = [(face, y - step * 0.42), (face + sg * 0.13, y - step * 0.42), (face + sg * 0.03, y + step * 0.42), (face - sg * 0.02, y + step * 0.42)]
		P["Metal"].append(RPX(pts if sg > 0 else [(z, yy) for z, yy in reversed(pts)], x0 + 0.17, x1 - 0.17))


def ac3():
	# ACUnit 8 x 4 x 7.5 (full cover, long along X): one rooftop air-handler cabinet on a steel curb, not stacked
	# toy units. Louvred intake panels, bolted access doors with handles, a top fan shroud with a grille, a pipe run.
	c = piece("ACUnit")
	P = roles()
	P["Charcoal"].append(RB(-3.95, 3.95, -0.1, 0.55, -1.95, 1.95, BT, ST))
	for x in (-3.3, 0.0, 3.3):
		P["Charcoal"].append(RB(x - 0.3, x + 0.3, -0.08, 0.62, -1.98, 1.98, BT, ST))
	P["Appliance"].append(RB(-3.8, 3.8, 0.6, 6.55, -1.82, 1.82, 0.14, 1))
	P["Metal"].append(RB(-3.9, 3.9, 6.5, 6.75, -1.92, 1.92, BT, ST))  # top rim
	P["Metal"].append(RB(-3.9, 3.9, 0.55, 0.8, -1.92, 1.92, BT, ST))  # base rail
	for s in (1, -1):
		face = s * 1.82
		louvre_x(-3.5, -0.35, 1.2, 6.1, face, P, 9)
		# access door: a raised panel, hinges and two handles
		a, b = sorted((face, face + s * 0.07))
		P["Trim"].append(RB(0.05, 3.45, 1.2, 6.1, a, b, BT, ST))
		a2, b2 = sorted((face + s * 0.07, face + s * 0.2))
		for y in (3.0, 4.3):
			P["Charcoal"].append(RB(2.95, 3.1, y - 0.35, y + 0.35, a2, b2, BT, ST))
		for y in (1.7, 5.6):
			P["Charcoal"].append(RB(0.12, 0.42, y - 0.3, y + 0.3, a2, b2, BT, ST))
	for s in (1, -1):  # end faces: a service panel with a seam
		a, b = sorted((s * 3.8, s * 3.87))
		P["Trim"].append(RB(a, b, 1.2, 6.1, -1.45, 1.45, BT, ST))
	# fan shroud and grille on top (to 7.5)
	P["Metal"].append(lathe_at(1.7, 0.0, [(0.0, 7.3), (1.45, 7.3), (1.55, 7.2), (1.55, 6.75)], 18))
	gr = []
	for k in range(4):
		a = math.radians(45 * k)
		gr.append(beam((1.7 - 1.35 * math.cos(a), 7.34 + 0.013 * k, -1.35 * math.sin(a)), (1.7 + 1.35 * math.cos(a), 7.34 + 0.013 * k, 1.35 * math.sin(a)), 0.1, 0.1))
	P["Charcoal"].append(merge(*gr))
	P["Charcoal"].append(lathe_at(1.7, 0.0, [(0.0, 7.45), (0.32, 7.45), (0.32, 7.3)], 10))
	P["Metal"].append(RB(-3.4, -0.6, 6.75, 7.05, -1.4, 1.4, BT, ST))  # a filter hatch
	# pipe run down the -X end to the curb
	for z in (-0.7, 0.5):
		P["Charcoal"].append(RPY(octo(-3.98, z, 0.16, 0.05), 0.55, 5.4, BT, ST))
		P["Charcoal"].append(RB(-4.05, -3.84, 5.2, 5.55, z - 0.24, z + 0.24, BT, ST))
	emit(c, P)


def roof_sign2():
	# RoofSign: hut roof centre, legs at z +-2.2, panel 14 (Z) x 10 at 4-14. No lettering (the user's review: no
	# part-built text): a cream panel in a charcoal frame, a soft cobalt band, lamp hoods on both faces.
	c = piece("RoofSign")
	P = roles()
	# maps v5 float audit: the legs stood on the stair hut's hip roof and touched nothing. Now two braced steel
	# posts stand on the tower roof either side of the hut (origin y 0 = hut top, the roof 9 below; hut z +-3), on
	# bolted base plates with raking kickers, and a service walkway on brackets under the panel.
	R0 = -9.0
	for z in (-5.2, 5.2):
		for dx in (-0.55, 0.55):
			P["Charcoal"].append(RB(dx - 0.16, dx + 0.16, R0 + 0.3, 4.45, z - 0.16, z + 0.16, BT, ST))
		P["Charcoal"].append(RB(-1.0, 1.0, R0 - 0.02, R0 + 0.3, z - 0.75, z + 0.75, BT, ST))
		for dx in (-0.75, 0.75):
			for dz in (-0.5, 0.5):
				P["Metal"].append(RB(dx - 0.08, dx + 0.08, R0 + 0.29, R0 + 0.42, z + dz - 0.08, z + dz + 0.08))
		for k in range(4):  # lattice between the two flanges
			y0 = R0 + 0.6 + k * 3.2
			P["Charcoal"].append(beam((-0.42, y0, z), (0.42, y0 + 3.0, z), 0.12, 0.12))
			P["Charcoal"].append(RB(-0.42, 0.42, y0 + 3.0, y0 + 3.16, z - 0.09, z + 0.09))
		P["Charcoal"].append(beam((-0.4, 2.6, z), (-3.4, R0 + 0.28, z), 0.2, 0.2))
		P["Charcoal"].append(RB(-3.9, -2.9, R0 - 0.02, R0 + 0.27, z - 0.5, z + 0.5, BT, ST))
	for s in (1, -1):
		a, b = sorted((s * 0.42, s * 1.6))
		P["Metal"].append(RB(a, b, 3.75, 3.9, -6.6, 6.6))
		for z in (-5.2, 5.2):
			P["Charcoal"].append(RB(a, b, 3.5, 3.76, z - 0.12, z + 0.12))
		P["Charcoal"].append(RB(s * 1.5 - 0.05, s * 1.5 + 0.05, 3.9, 4.35, -6.6, 6.6))
	P["Charcoal"].append(frame_ring(14.0, 10.0, 0.45, 9.0, -0.4, 0.4))
	P["Poster"].append(RB(-0.28, 0.28, 4.4, 13.6, -6.6, 6.6))
	# maps v5: the cobalt band went; Codex's artwork covers the whole panel (decals in Art.luau)
	for z in (-7.0, 7.0):
		P["Accent"].append(frustum(-0.55, 0.55, z - 0.55, z + 0.55, 14.0, 14.55, 0.2, 0.2, 0.03))
	for s in (1, -1):
		for z in (-4.0, 0.0, 4.0):
			a, b = sorted((s * 0.4, s * 1.5))
			P["Charcoal"].append(RB(a, b, 14.15, 14.32, z - 0.08, z + 0.08))
			a, b = sorted((s * 1.15, s * 1.85))
			P["Charcoal"].append(frustum(a, b, z - 0.45, z + 0.45, 13.85, 14.3, 0.12, 0.12))
			P["GlowWarm"].append(RB(a + 0.08, b - 0.08, 13.78, 13.86, z - 0.35, z + 0.35))
	emit(c, P)


def inlay(name, W, Dp):
	# Floor breakup: a paved field in a cream stone kerb, flush on the roof (0.04-0.07 proud, no collision), the
	# concept's kerbed terraces. Origin: floor centre.
	c = piece(name)
	P = roles()
	hx, hz, k = W / 2 - 0.02, Dp / 2 - 0.02, 0.38
	P["Stone"].append(drop_down(RB(-hx, hx, 0.0, 0.07, hz - k, hz)))
	P["Stone"].append(drop_down(RB(-hx, hx, 0.0, 0.07, -hz, -hz + k)))
	P["Stone"].append(drop_down(RB(hx - k, hx, 0.0, 0.07, -hz + k + 0.01, hz - k - 0.01)))
	P["Stone"].append(drop_down(RB(-hx, -hx + k, 0.0, 0.07, -hz + k + 0.01, hz - k - 0.01)))
	P["Paver"].append(drop_down(RB(-hx + k + 0.01, hx - k - 0.01, 0.0, 0.04, -hz + k + 0.01, hz - k - 0.01)))
	emit(c, P)


def drain():
	c = piece("Drain")
	P = roles()
	P["Stone"].append(drop_down(RB(-0.75, 0.75, 0.0, 0.06, -0.75, 0.75)))
	P["Charcoal"].append(drop_down(RB(-0.5, 0.5, 0.06, 0.09, -0.5, 0.5)))
	for k in range(5):
		x = -0.4 + 0.2 * k
		P["Metal"].append(drop_down(RB(x - 0.05, x + 0.05, 0.09, 0.11, -0.45, 0.45)))
	emit(c, P)


def tar_patch(name, seed):
	# a tar-sealed repair: an irregular low polygon (0.025 proud)
	c = piece(name)
	P = roles()
	pts = []
	for i in range(9):
		a = 2 * math.pi * i / 9
		r = 1.0 + 0.35 * math.sin(3.1 * i + seed) + 0.2 * math.cos(5.3 * i + 2 * seed)
		pts.append((2.2 * r * math.cos(a), 1.4 * r * math.sin(a)))
	P["Tar"].append(drop_down(RPY(pts, 0.0, 0.025)))
	emit(c, P)



def flue2():
	# Flue (top centre, 8 Z x 6 X, 82 tall; walkable top): maps v4, a brick chimney stack, not a tinted box: brick
	# shaft, stone quoins and bands over the visible top 22, a blind arched niche with a louvre on the open face
	# (+X), a stone cornice with a cobalt band, two terracotta pots at the back edge (off the standing area).
	c = piece("Flue")
	P = roles()
	P["Brick"].append(open_box(RB(-3.0, 3.0, -82.0, -1.2, -4.0, 4.0), drop_z=False, drop_y=True))
	for sx in (1, -1):
		for sz in (1, -1):
			quoins_corner(sx * 3.0, sz * 4.0, sx, sz, -22.0, -1.6, P)
	for y in (-22.6, -12.4):
		P["Stone"].append(RB(-3.14, 3.14, y, y + 0.55, -4.14, 4.14, BT, ST))
	W = roles()
	window_x(0.0, -10.6, 2.4, 6.0, False, W, shutters=False)
	for k in range(7):
		y = -10.0 + k * 0.62
		W["Charcoal"].append(RB(-0.02, 0.1, y, y + 0.32, -1.05, 1.05))
	for role, bms in W.items():
		for bm in bms:
			xform(bm, T(3.0, 0.0, 0.0))
			P["Stone" if role == "Window" else role].append(bm) if role != "Window" else P["Charcoal"].append(bm)
	P["Stone"].append(RB(-3.4, 3.4, -1.25, -0.55, -4.4, 4.4, BT, ST))
	P["AccentSoft"].append(RB(-3.28, 3.28, -1.65, -1.25, -4.28, 4.28, BT, ST))
	P["Stone"].append(RB(-3.15, 3.15, -0.55, 0.0, -4.15, 4.15, BT, ST))
	for z in (-2.6, 2.6):
		P["Brick"].append(RB(-3.0, -1.6, 0.0, 0.7, z - 0.9, z + 0.9, BT, ST))
		P["Pot"].append(lathe_at(-2.3, z, [(0.0, 2.1), (0.42, 2.1), (0.5, 1.95), (0.38, 1.85), (0.5, 0.7)], 10))
	emit(c, P)


# ---- Codex props (2026-11-05 late; vault/01 Design/Maps/Rooftops2.md -> Codex prop list): reviewed against the
# concepts by lane G and used where they beat the interim pieces: R1 agaves (with lane G's slat screen, so the
# planter stays full cover), R2 AC cabinet, R4 crates and barrel. R3 (a whole plain tank, not a detail kit for ours)
# is not used. Each GLB is 1 unit = 1 stud, Z up, one object per role (material named by role).

PROPS = os.path.join(ART, "props")


def codex_meshes(glb, group=None):
	"""Import a Codex GLB; return {role: [bmesh]} in Blender coords, the group's footprint centred, base at 0."""
	before = set(bpy.data.objects)
	bpy.ops.import_scene.gltf(filepath=glb)
	new = [o for o in bpy.data.objects if o not in before]
	meshes = [o for o in new if o.type == "MESH" and (group is None or (o.parent is not None and o.parent.name == group))]
	bpy.context.view_layer.update()
	pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
	cx = (min(p.x for p in pts) + max(p.x for p in pts)) / 2
	cy = (min(p.y for p in pts) + max(p.y for p in pts)) / 2
	z0 = min(p.z for p in pts)
	out = {}
	for o in meshes:
		bm = bmesh.new()
		bm.from_mesh(o.data)
		bm.transform(o.matrix_world)
		bmesh.ops.translate(bm, verts=bm.verts, vec=(-cx, -cy, -z0))
		role = o.data.materials[0].name.split(".")[0]
		out.setdefault(role, []).append(bm)
	for o in new:
		bpy.data.objects.remove(o)
	return out


def emit_codex(c, parts):
	for role, bms in parts.items():
		obj(c, "Codex" + role, merge(*bms), role)


def codex_ac():
	# maps v5 palette: Codex's casing came in on Trim (near-white); it takes the Appliance stone-grey
	cp = codex_meshes(os.path.join(PROPS, "ACCabinet.glb"))
	cp["Appliance"] = cp.pop("Trim", []) + cp.get("Appliance", [])
	# maps v5 round 2 (scale): the cabinet is 5.6 tall on a 1.9 concrete pad (real rooftop units sit on pads), so
	# it reads machine-sized next to a player; together they still fill the 8 x 4 x 7.5 cover box.
	for bms in cp.values():
		for bm in bms:
			bmesh.ops.scale(bm, verts=bm.verts, vec=(1.0, 1.0, 5.6 / 7.5))
			bmesh.ops.translate(bm, verts=bm.verts, vec=(0.0, 0.0, 1.9))
	c = piece("ACUnit")
	emit_codex(c, cp)
	P = roles()
	P["Stone"].append(RB(-4.0, 4.0, 0.0, 1.9, -2.0, 2.0, 0.1, 1))
	P["Charcoal"].append(RB(-4.1, 4.1, 1.78, 1.92, -2.1, 2.1, 0.03, 1))
	emit(c, P, "Pad")


def codex_crates():
	for name, group in (("Crate", "Crate3"), ("CrateSmall", "Crate2"), ("Barrel", "Barrel")):
		emit_codex(piece(name), codex_meshes(os.path.join(PROPS, "CrateSet.glb"), group))


def laundry():
	# Maps v5 story prop (the concept's lived-in roofs): a washing line on two steel T-posts, 11 long along X, with
	# bolted base plates, two sagging lines and towels, shirts and a sheet pegged on, in the palette's cloth tones.
	# Origin: floor centre; the line runs x -5.5..5.5, the cloth hangs in the plane z ~0.35. No collision.
	c = piece("Laundry")
	P = roles()
	L, top, sag = 5.5, 6.2, 0.35
	for x in (-L, L):
		P["Charcoal"].append(RB(x - 0.12, x + 0.12, 0.16, top + 0.21, -0.12, 0.12, 0.03, 1))
		P["Charcoal"].append(RB(x - 0.1, x + 0.1, top + 0.05, top + 0.25, -0.6, 0.6, 0.03, 1))
		P["Charcoal"].append(RB(x - 0.45, x + 0.45, -0.02, 0.16, -0.45, 0.45, 0.04, 1))
		for ox in (-0.3, 0.3):
			for oz in (-0.3, 0.3):
				P["Metal"].append(RB(x + ox - 0.06, x + ox + 0.06, 0.15, 0.24, oz - 0.06, oz + 0.06))
		P["Charcoal"].append(beam((x, 0.16, -0.12), (x, 1.4, -0.7), 0.08, 0.08))
		P["Charcoal"].append(beam((x, 0.16, 0.12), (x, 1.4, 0.7), 0.08, 0.08))

	def line_y(x):
		return top - sag * (1.0 - (x / L) ** 2)

	n = 10
	for z in (-0.45, 0.45):
		for k in range(n):
			x0, x1 = -L + 2 * L * k / n, -L + 2 * L * (k + 1) / n
			P["Charcoal"].append(beam((x0, line_y(x0) + 0.1, z), (x1, line_y(x1) + 0.1, z), 0.05, 0.05))
	# (x centre, width, height, role, kind): towels, shirts, a sheet
	items = [
		(-4.2, 1.3, 2.0, "Cloth", "towel"),
		(-2.55, 1.5, 1.7, "AccentSoft", "shirt"),
		(-0.6, 2.3, 2.7, "Cloth", "sheet"),
		(1.45, 1.4, 1.6, "Shutter", "shirt"),
		(3.0, 1.1, 1.9, "Pot", "towel"),
		(4.45, 0.9, 1.3, "Cloth", "towel"),
	]
	for k, (xc, w, h, role, kind) in enumerate(items):
		z = 0.45 + (0.03 if k % 2 else -0.03)
		yt = line_y(xc) + 0.06
		if kind == "shirt":
			P[role].append(RB(xc - w * 0.36, xc + w * 0.36, yt - h, yt, z - 0.04, z + 0.04, 0.02, 1))
			for sx in (1, -1):
				a, b = sorted((xc + sx * w * 0.36, xc + sx * w * 0.62))
				P[role].append(RB(a, b, yt - 0.62, yt - 0.02, z - 0.035, z + 0.035, 0.02, 1))
		else:
			P[role].append(RB(xc - w / 2, xc + w / 2, yt - h, yt, z - 0.035, z + 0.035, 0.02, 1))
		for px in (xc - w * 0.3, xc + w * 0.3):
			P["Wood"].append(RB(px - 0.05, px + 0.05, yt - 0.12, yt + 0.12, z - 0.07, z + 0.07))
	emit(c, P)


def codex_pot():
	# Codex's R1 agave pot (2 x 2, foliage to 3.15): story groups by the huts and the party corner (maps v5)
	emit_codex(piece("AgavePot"), codex_meshes(os.path.join(PROPS, "AgavePot.glb")))


def codex_planter():
	# Codex's planter box and agaves, the agave row doubled either side of lane G's slat screen (full cover to 7.5).
	c = piece("Planter")
	cp = codex_meshes(os.path.join(PROPS, "AgavePlanter.glb"))
	P = roles()
	for role in ("Pot", "Stone", "Accent"):
		P[role] += cp.get(role, [])
	for k, bm in enumerate(cp.get("Plant", [])):
		for sz in (1, -1):
			b2 = bm.copy()
			# scale 0.78 about the row's base, then move it to one side of the screen (Roblox z = -Blender y)
			bmesh.ops.scale(b2, verts=b2.verts, vec=(0.78, 0.78, 0.78), space=Matrix.Translation((0.0, 0.0, -2.2)))
			bmesh.ops.translate(b2, verts=b2.verts, vec=(0.12 * sz, -sz * 0.74, 0.0))
			P["Plant"].append(b2)
	for x in (-2.55, 0.0, 2.55):
		P["Charcoal"].append(RB(x - 0.17, x + 0.17, 2.3, 7.1, -0.17, 0.17, BT, ST))
	for k in range(8):
		y0 = 2.85 + k * 0.53
		o = 0.025 * (k % 2)
		P["Wood"].append(RB(-2.42, 2.42, y0, y0 + 0.46, -0.09 + o, 0.07 + o, BT, ST))
	P["Wood"].append(RB(-2.3, 2.3, 7.05, 7.3, -0.2, 0.2, BT, ST))
	for x in (-2.55, 2.55):
		P["Accent"].append(frustum(x - 0.27, x + 0.27, -0.27, 0.27, 7.1, 7.5, 0.1, 0.1, 0.03))
	emit(c, P, "Codex")

# ---------------------------------------------------------------- build

def build():
	for o in list(bpy.data.objects):
		bpy.data.objects.remove(o)
	for col in list(bpy.data.collections):
		bpy.data.collections.remove(col)
	D.PIECES.clear()
	materials()
	D.KIT = collection("Kit_Rooftops2")
	facade2("Facade8A", 8, "A")
	facade2("Facade8B", 8, "B")
	facade2("Facade8C", 8, "C")
	facade2("Facade4", 4, "A")
	p_plinth("Plinth8", 8)
	p_plinth("Plinth4", 4)
	p_quoin()
	flue2()  # maps v4
	stone_stair("Stair16")
	gangway2()
	plank_bridge("PlankRamp16", 8)
	plank_bridge("Catwalk8", 0)
	fire_stair()
	fire_balcony()
	codex_ac()  # maps v4: Codex R2 (lane G's ac3 stays as the fallback)
	p_condenser()
	skylight3()  # maps v4
	codex_planter()  # maps v4: Codex R1 agaves + lane G's screen (planter3 stays as the fallback)
	penthouse2("A")
	penthouse2("B")
	hut2("StairHut", 6, 6, 9)
	hut2("LiftHouse", 8, 8, 10, vent=True, windows=True)
	lift_tower2()
	hut2("TankHouse", 10, 10, 8, windows=True)
	hut2("CoolingTower", 10, 10, 8, roof_role="RoofSlate", windows=True)  # maps v4: a slate-roofed house (kit sheet row 2)
	water_tank2()
	billboard3()
	pier_cap()
	roof_sign2()  # maps v4: no part-built text; the deck words, chevrons and spawn signs are cut
	inlay("Inlay8", 8, 8)
	drain()
	tar_patch("TarPatchA", 1.0)
	tar_patch("TarPatchB", 2.6)
	p_street_lamp()
	codex_crates()  # maps v4: Codex R4
	laundry()  # maps v5 story props
	codex_pot()
	party_corner()
	city2("CityA", 28, 24, 64, 1)
	city2("CityB", 24, 24, 90, 2)
	city2("CityC", 30, 30, 120, 3)
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
		stage, w = D.contact_sheet(["Facade8A", "StairHut", "LiftHouse", "CoolingTower", "ACUnit", "Skylight", "Planter", "RoofSign", "Inlay8", "Crate", "Barrel"], "a")
		D.camera((w / 2, 6, 70), (w / 2, -6, 0), 26)
		D.shot(os.path.join(RENDER_DIR, "kit-contact-a.jpg"))
		bpy.data.collections.remove(stage)
		stage, w = D.contact_sheet(["PenthouseA", "PenthouseB", "FireBalcony", "FireStair", "Stair16", "Gangway16", "PlankRamp16", "LiftTower"], "b")
		D.camera((w / 2, 22, 70), (w / 2, 6, 0), 26)
		D.shot(os.path.join(RENDER_DIR, "kit-contact-b.jpg"))
		bpy.data.collections.remove(stage)
	if "--closeups" in ARGS:  # maps v4: close 3/4 renders of the rebuilt pieces (scratch, not the vault)
		if "--render" not in ARGS:
			M["Deck"] = M["Roof"]
			D.render_settings()
			D.world(sun_el=32.0)
			for lc in bpy.context.view_layer.layer_collection.children:
				if lc.name == "Kit_Rooftops2":
					lc.exclude = True
		out = os.environ.get("CLOSEUP_DIR", RENDER_DIR)
		for tag, names in (("v4-a", ["ACUnit", "Planter", "Skylight"]), ("v4-b", ["RoofSign", "StairHut", "CoolingTower"]), ("v4-c", ["Inlay8", "Drain", "TarPatchA", "Crate"])):
			stage, w = D.contact_sheet(names, tag)
			D.camera((w * 0.5 + 4, 10, 26), (w * 0.5, 3, 0), 30)
			D.shot(os.path.join(out, "closeup-%s.jpg" % tag))
			bpy.data.collections.remove(stage)
