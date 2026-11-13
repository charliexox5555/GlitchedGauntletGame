"""Sunwell Works: the Locker (crew gallery). Seven glass-front class bays round a chamfered room, all 18 real
gun models by class, a low projector on a stepped platform with the Vandal turning over it.
Entered from the hall's east wall at y = 34 through the ribbed collar (no door: owner 2026-11-11)."""
import json
import os
from math import radians, pi
from mathutils import Matrix, Vector

import lv3_core as C
import sw_core as S
import sw_doors as DR

AREA = "Locker"
H = 16.0
X0 = 43.4  # interior face of the wall the doorway comes through
CX, CY = 66.0, 34.0
PTS = [(X0, 14), (77.4, 14), (87.4, 24), (87.4, 44), (77.4, 54), (X0, 54)]  # 40 wide: the Shop sits against its north wall
BUILD_DATA = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "studio", "rojo", "BuildData"))
TOP = 13.0  # top of every wall opening (doorway and bays)
SILL, WIN = 3.6, 11.3  # glass opening inside the casing

# edge index, offset along the wall, bay width, label, [(gun, offset, rest height)]
BAYS = [
	(4, -8.5, 13.0, "SIDEARMS", [("Classic", -3.0, 4.7), ("Ghost", 3.0, 4.7), ("Sheriff", -3.0, 8.3), ("Shorty", 3.0, 8.3)]),
	(4, 8.5, 13.0, "HEAVY", [("Odin", 0, 4.7), ("Ares", 0, 8.3)]),
	(3, 0.0, 12.0, "SHOTGUNS", [("Judge", 0, 4.7), ("Bucky", 0, 8.3)]),
	(2, 0.0, 17.0, "RIFLES", [("Vandal", -4.0, 4.7), ("Phantom", 4.0, 4.7), ("Bulldog", -4.0, 8.3), ("Guardian", 4.0, 8.3)]),
	(1, 0.0, 12.0, "SMGS", [("Spectre", 0, 4.7), ("Stinger", 0, 8.3)]),
	(0, -8.5, 13.0, "SNIPERS", [("Operator", 0, 4.3), ("Marshal", 0, 6.7), ("Outlaw", 0, 9.1)]),
	(0, 8.5, 13.0, "MELEE", [("Knife", 0, 6.9)]),
]


def gun_box(gid):
	d = json.load(open(os.path.join(BUILD_DATA, gid + ".json")))
	x0 = z0 = 1e9
	x1 = z1 = -1e9
	for q in d["parts"]:
		if q.get("option"):
			continue
		x0, x1 = min(x0, q["center"][0] - q["size"][0] / 2), max(x1, q["center"][0] + q["size"][0] / 2)
		z0, z1 = min(z0, q["center"][2] - q["size"][2] / 2), max(z1, q["center"][2] + q["size"][2] / 2)
	return x1 - x0, z1 - z0


def bay(F, u, w, label, guns):
	"""A display bay set into the wall. The cabinet and the casing stand 0.5 proud on one front plane, split by a shadow
	gap; the casing (sill, cheeks and header) is one continuous piece, with the glass set back inside it."""
	B = F.at(Matrix.Translation((u, 0, 0)))
	with S.grp(f"Bay_{label.title()}", B.M):
		hw = w / 2
		B["Charcoal"].box(-hw, hw, -1.5, TOP, -4.0, -2.6)  # seals the wall opening
		B["Graphite"].box(-hw, hw, -1.5, 2.86, -2.6, 0.5)  # cabinet
		for s in (-1, 1):  # cabinet doors with pulls
			B["Charcoal"].box(*sorted((s * 0.12, s * (hw - 0.4))), 0.55, 2.5, 0.5, 0.54)
			B["Steel"].box(s * 0.5 - 0.06, s * 0.5 + 0.06, 1.2, 1.9, 0.54, 0.64)
		B["PetrolDark"].box(-hw, hw, 0.0, 0.32, 0.5, 0.56)  # kick strip
		B["Dark"].box(-hw + 0.05, hw - 0.05, 2.86, 3.0, -2.6, 0.4)  # shadow gap
		S.ring_prism(B["Charcoal"], S.rect_loop(-hw, hw, 3.0, TOP), S.rect_loop(-hw + 0.6, hw - 0.6, SILL, WIN), -2.6, 0.5)
		B["BayBack"].box(-hw + 0.6, hw - 0.6, SILL, WIN, -2.6, -2.4)
		B["E_Opal"].box(-hw + 1.4, hw - 1.4, WIN - 0.12, WIN, -1.7, -0.9)
		B["E_Sun"].box(-hw + 0.9, hw - 0.9, SILL, SILL + 0.06, -0.3, -0.12)  # warm sill light (the cyan strips read off-palette; blue stays on the floor ring and projector)
		B["Glass"].box(-hw + 0.6, hw - 0.6, SILL, WIN, 0.06, 0.18)
		for s in (-1, 1):
			B["E_Amber"].box(s * (hw - 1.3) - 0.09, s * (hw - 1.3) + 0.09, WIN + 0.45, TOP - 0.45, 0.5, 0.55)
		S.add_text(B["Cream"], label, 1.0, 0.2, y0=WIN + 0.35, z0=0.45, s=0.2, c=0.06, ci=0.02, track=0.17)
		S.collider(AREA, B.M, -hw + 0.1, hw - 0.1, -1.5, 2.8, -2.5, 0.38)
		S.collider(AREA, B.M, -hw, hw, -1.5, TOP, -3.85, -2.75)
		S.collider(AREA, B.M, -hw, hw, 2.86, TOP, -0.3, 0.45, kind="Y")  # casing and glass
		S.light(B.M, 0, 10.0, -0.9, "#FFF1DE", 0.9, 9)
		rows = sorted({g[2] for g in guns})
		cols = max(sum(1 for g in guns if g[2] == r) for r in rows)
		cw = (w - 1.6) / cols
		ch = (WIN - SILL) / len(rows)
		R = B.M.to_3x3()
		t = R @ Vector((1, 0, 0))
		for gid, du, rest in guns:
			ln, ht = gun_box(gid)
			sc = round(min(cw * 0.86 / ln, ch * 0.6 / ht, 3.6), 2)
			B["Steel"].box(du - ln * sc * 0.36, du + ln * sc * 0.36, rest - 0.14, rest, -2.4, -0.95)  # rail the gun rests on
			p = B.M @ Vector((du, rest, -1.5))
			S.gun_row([gid, sc, round(p.x, 3), round(p.y, 3), round(p.z, 3), round(t.x, 4), round(t.y, 4), 0, 0])


def centre(K, KC):
	"""Stepped platform, the projector with a glowing lens, the hero gun turning in a cyan orbit, a big opal light above."""
	with S.grp("Projector", Matrix.Translation((CX, CY, 0))):
		K["WallBase"].disc(9.0, 0.0, 0.5, n=8, cx=CX, cy=CY)
		K["Graphite"].disc(7.0, 0.5, 1.0, n=8, cx=CX, cy=CY)
		K["P_Blue"].ring(10.3, 10.65, -0.15, 0.05, n=8, cx=CX, cy=CY)  # floor line round the platform
		K["E_Blue"].ring(6.1, 6.3, 0.9, 1.05, n=8, cx=CX, cy=CY)
		K["Charcoal"].disc(2.9, 1.0, 2.3, n=8, cx=CX, cy=CY, r1=2.35)
		K["Petrol"].ring(2.0, 2.35, 2.3, 2.5, n=8, cx=CX, cy=CY)
		K["E_Blue"].disc(1.9, 2.3, 2.4, n=8, cx=CX, cy=CY)
		K["E_Blue"].framem(Matrix.Translation((CX, CY, 6.3)) @ Matrix.Rotation(radians(12), 4, "X")).ring(4.0, 4.14, -0.045, 0.045, n=8)
		C.collider_cyl(AREA, CX, CY, 8.15, 0.05, 0.45)
		C.collider_cyl(AREA, CX, CY, 6.3, 0.4, 0.95)
		C.collider_cyl(AREA, CX, CY, 3.2, 1.0, 10.0, kind="X")  # keeps players out of the hologram
		S.gun_row(["Vandal", 2.2, CX, CY, 5.6, 0.0, 1.0, 1, 16])  # side-on to the doorway
		S.light(S.I4, CX, CY, 3.2, "#DCE8FF", 0.6, 10)
		S.light(S.I4, CX, CY, 12.0, "#EAF6FF", 2.2, 14, angle=70)
	with S.grp("ProjectorLight", Matrix.Translation((CX, CY, H))):
		rr = lambda hx, hy, r: S.fillet([(CX - hx, CY - hy, r), (CX + hx, CY - hy, r), (CX + hx, CY + hy, r), (CX - hx, CY + hy, r)], "cham")
		S.ring_prism(KC["Petrol"], rr(6.2, 9.2, 4.6), rr(5.2, 8.2, 3.9), H - 0.7, H)
		KC["E_Opal"].prism(rr(5.2, 8.2, 3.9), H - 0.45, H - 0.3)
		for dx in (-4.0, -2.0, 0.0, 2.0, 4.0):  # louvre fins along the long axis, clipped to the octagon
			ext = 8.2 - max(0.0, abs(dx) - 1.3)
			KC["Graphite"].box(CX + dx - 0.07, CX + dx + 0.07, CY - ext + 0.05, CY + ext - 0.05, H - 0.85, H - 0.45)
		KC["Graphite"].box(CX - 5.15, CX + 5.15, CY - 0.07, CY + 0.07, H - 0.85, H - 0.45)
		S.ring_prism(KC["Petrol"], rr(5.25, 8.25, 3.9), rr(5.1, 8.1, 3.85), H - 0.95, H - 0.7)  # lip round the louvres
		for dy in (-5, 5):
			S.light(S.I4, CX, CY + dy, H - 1.0, "#FFEED6", 1.3, 22, angle=90)  # pools round the platform


def floor_marks(K):
	"""An inlaid dark border band 1.6 to 2.0 inside the room outline, and slab joints from the platform line out to
	each corner of the room, so the floor reads as laid slabs instead of one plain sheet."""
	with S.grp("LockerFloorMarks"):
		outer = C._inset_poly([Vector(p) for p in PTS], 1.6)
		inner = C._inset_poly([Vector(p) for p in PTS], 2.0)
		S.ring_prism(K["Graphite"], [(p.x, p.y) for p in outer], [(p.x, p.y) for p in inner], 0.0, 0.03)
		for p in PTS[1:5]:  # the four far corners (the doorway wall stays clear)
			d = (Vector(p) - Vector((CX, CY))).normalized()
			n = Vector((-d.y, d.x)) * 0.06
			a = Vector((CX, CY)) + d * 10.9
			b = Vector(p) - d * 2.3
			K["Graphite"].prism([(a - n).to_tuple(), (b - n).to_tuple(), (b + n).to_tuple(), (a + n).to_tuple()], 0.0, 0.03)


def build():
	slabs = [(X0 - 4, 77.4, 10, 58), (77.4, 91.4, 24, 44)]  # floor and ceiling pieces that stay inside the chamfered corners
	for x0, x1, d in ((77.4, 80.9, 0.0), (80.9, 84.4, 3.5), (84.4, 87.9, 7.0)):
		slabs += [(x0, x1, 14 + d, 24), (x0, x1, 44, 54 - d)]
	K, KC, edges = S.poly_room(AREA, PTS, 0.0, H, floor_mat="LockerFloor", slabs=slabs)
	per = {}
	for e, u, w, label, guns in BAYS:
		per.setdefault(e, []).append((u, w, label, guns))
	for i, (F, L, ext) in enumerate(edges):
		ops = [(u - w / 2, u + w / 2, TOP) for u, w, _l, _g in per.get(i, [])]
		if i == 5:
			ops = [(-10.0, 10.0, TOP)]  # the doorway (the hall's reveal lining passes through it)
		S.wall_seg(F, AREA, L, H, ops, ext=ext, courses=[1.5, 7.25, TOP], top_trim=0.02 + 0.03 * (i % 2), name=f"LockerWall{i + 1}")
		for u, w, label, guns in per.get(i, []):
			bay(F, u, w, label, guns)
	F, L, _ = edges[5]
	with S.grp("LockerDoorCasing", F.M):
		S.u_frame(F["Petrol"], 10.6, 13.4, 7.8, 10.8, 0.0, 0.5, ro=5.8, ri=3.0, n=2)  # casing on the gallery side, same collar shape
	for s in (-1, 1):
		DR.sconce(F, s * 14.5, 10.0)
	centre(K, KC)
	floor_marks(K)
	S.soffit(KC, AREA, PTS, H, depth=0.6, width=3.0, lights=6, name="LockerSoffit")
	for y in (CY - 12.0, CY + 12.0):
		S.ceiling_beam(KC, X0 + 3.0, y, 82.4, y, H, name="LockerBeam")
	for e in (0, 4):  # between the two bays on each long wall
		S.pilaster(edges[e][0], 0.0, H - 0.6, hw=1.1, d=0.7, name="LockerPilaster")
	S.anchor("LockerZone", "LobbyLocker", CX - 9.5, CY, 4.0, 7.0, 12.0, 7.0)
	K.done()
	KC.done()
