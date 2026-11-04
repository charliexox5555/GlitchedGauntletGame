"""Rooftops art placement: turns the checked layout (rooftops_layout.py) into kit placements and art Parts.

Used by `python tools/maps/rooftops_layout.py --write` (writes the PLACE block of
tools/studio/maps/Rooftops/Art.luau) and by tools/blender/build_map_kit_rooftops.py (the offline previews and
the mesh-level z-fighting check place exactly the same list). Run alone for a summary:
    python tools/maps/rooftops_art.py

Kit pieces (tools/blender/build_map_kit_rooftops.py documents their origins). Yaw is MapKit's at(x, y, z, yaw):
local +X turns toward (cos yaw, -sin yaw) in (x, z), so a piece facing +X / -Z / -X / +Z has yaw 0 / 90 / 180 / 270.

What gets placed:
- every face of every building: facade columns (8 wide, windows on every 12-stud storey, three lit patterns) and
  4-wide fillers, skipping where a flue stands against the wall; a quoin and cornice corner on every corner; a
  stone plinth under the taller towers;
- the flues, stairs, gangway, plank ramp, footbridges;
- a kit prop on every piece of cover (huts, AC units, condensers, skylights, tank houses, water tanks, billboards,
  roof signs), the team letters on the Penthouses;
- the street (Parts), street lamps, the neighbouring blocks and the skyline (the sign tower and the radio mast).
"""

from __future__ import annotations

import hashlib
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rooftops_layout as L  # noqa: E402

S = L.S

# Facade / brick tones per building (Art.luau tints the *_Wall parts with these).
TONES = {
	"teamA": "#8E4E3C",  # warm red-brown brick
	"teamB": "#5F6F82",  # cool slate-blue painted brick
	"tower": "#A99173",  # sandstone
	"pit": "#9C8A72",  # darker sandstone
}
# Neon per side of the map (x < 0 west: pink, x > 0 east: amber). Team colours (cyan, orange-red) stay free.
SIDE_GLOW = {"west": "#FF4FA3", "east": "#FFB238"}

FACE_YAW = {(1, 0): 0.0, (0, -1): 90.0, (-1, 0): 180.0, (0, 1): 270.0}
STREET = L.STREET
BLOCK_X, BLOCK_Z = 48.0, 72.0  # the map's city block
WALK_W = 6.0  # sidewalk
ROAD_W = 24.0
NEIGHBOUR_X = BLOCK_X + WALK_W + ROAD_W + WALK_W  # 84: the facing blocks start here
NEIGHBOUR_Z = BLOCK_Z + WALK_W + ROAD_W + WALK_W  # 108


def h01(*key) -> float:
	d = hashlib.md5(repr(key).encode()).digest()
	return d[0] / 255.0


def tone_of(s: S) -> str:
	if s.tag == "B Block" or s.kind == "flue":
		return "teamB" if s.cz > 0 else "teamA"
	if s.tag == "West Tower":
		return "tower"
	if s.tag == "Pit":
		return "pit"
	return ""


class Art:
	def __init__(self):
		self.place = []  # (section, piece, x, y, z, yaw, tint, glow, scale)

	def put(self, section, piece, x, y, z, yaw=0.0, tint="", glow="", scale=1.0):
		self.place.append((section, piece, round(x, 3), round(y, 3), round(z, 3), round(yaw % 360, 3), tint, glow, scale))

	# ------------------------------------------------------------ buildings

	def facades(self):
		flues = [s for s in L.SOLIDS if s.kind == "flue"]
		for b in L.ALL_BUILDINGS:
			tone = TONES[b.tone]
			R = b.roof
			faces = [
				((1, 0), b.x1, (b.z0, b.z1)),
				((-1, 0), b.x0, (b.z0, b.z1)),
				((0, 1), b.z1, (b.x0, b.x1)),
				((0, -1), b.z0, (b.x0, b.x1)),
			]
			for n, plane, (t0, t1) in faces:
				# segments of the face not covered by a flue standing against it
				blocked = []
				for f in flues:
					if n[0] and abs((f.x0 if n[0] > 0 else f.x1) - plane) < 0.01:
						blocked.append((f.z0, f.z1))
					if n[1] and abs((f.z0 if n[1] > 0 else f.z1) - plane) < 0.01:
						blocked.append((f.x0, f.x1))
				segs, cur = [], t0
				for a, c in sorted(blocked):
					if a > cur and a < t1:
						segs.append((cur, a))
					cur = max(cur, c)
				if cur < t1:
					segs.append((cur, t1))
				for s0, s1 in segs:
					self.facade_run(n, plane, s0, s1, R, tone, b)
			# quoins on the four corners (outward normals (nx, nz) -> yaw)
			for cx, cz, yaw in ((b.x1, b.z1, 0.0), (b.x1, b.z0, 90.0), (b.x0, b.z0, 180.0), (b.x0, b.z1, 270.0)):
				self.put("Facades", "Quoin", cx, R, cz, yaw, tint=tone)

	def facade_run(self, n, plane, s0, s1, R, tone, b):
		L_ = s1 - s0
		n8 = int(L_ // 8)
		rest = L_ - 8 * n8
		widths = [8.0] * n8
		if abs(rest - 4) < 0.01:
			widths.insert(len(widths) // 2, 4.0)  # the narrow bay in the middle of the run
		elif rest > 0.01:
			raise ValueError(f"{b.name}: facade run {L_} is not a multiple of 4")
		t = s0
		yaw = FACE_YAW[n]
		for w in widths:
			c = t + w / 2
			x, z = (plane, c) if n[0] else (c, plane)
			if w == 8:
				k = h01(b.name, n, round(c, 2))
				piece = "Facade8A" if k < 0.34 else ("Facade8B" if k < 0.67 else "Facade8C")
			else:
				piece = "Facade4"
			self.put("Facades", piece, x, R, z, yaw, tint=tone)
			if R > 0.5:  # the towers stand 8 taller: a stone plinth fills the street storey
				self.put("Facades", "Plinth8" if w == 8 else "Plinth4", x, STREET, z, yaw)
			t += w

	# ------------------------------------------------------------ gameplay pieces

	def pieces(self):
		for s in L.SOLIDS:
			side = "west" if s.cx < 0 else "east"
			if s.kind == "flue":
				# the flue stands against the B (or A) Block: its back is toward the block
				yaw = 270.0 if s.cz > 0 else 90.0  # local +X faces away from the block
				self.put("Structure", "Flue", s.cx, s.y1, s.cz, yaw, tint=TONES[tone_of(s)])
			elif s.kind == "stair":
				ux, uz = s.up
				yaw = {(0, 1): 0.0, (0, -1): 180.0, (1, 0): 90.0, (-1, 0): 270.0}[(ux, uz)]
				# kit stairs rise toward local +Z, like the WedgePart; yaw 180 turns them to rise toward -Z
				self.put("Structure", s.art, s.cx, s.y0, s.cz, yaw)
			elif s.kind == "bridge":
				self.put("Structure", s.art, s.cx, s.y1, s.cz, 0.0 if s.cz > 0 else 180.0)
			elif s.kind in ("hut", "ac", "cond", "sky"):
				along_x = s.sx >= s.sz
				if s.art == "Penthouse":
					yaw = 0.0 if s.cz > 0 else 180.0  # its door faces the spawn court
					self.put("Props", "Penthouse", s.cx, s.y0, s.cz, yaw, tint=TONES[tone_of_roof(s)])
					# the team letter on the face toward the middle
					face = s.z0 if s.cz > 0 else s.z1
					self.put("Props", "LetterB" if s.cz > 0 else "LetterA", s.cx, s.y0, face, yaw)
					continue
				yaw = 0.0 if along_x else 90.0
				if s.art in ("StairHut", "LiftHouse", "LiftTower", "TankHouse", "CoolingTower"):
					# doors face the middle of the roof they stand on (huts) or the open side
					yaw = door_yaw(s)
				self.put("Props", s.art, s.cx, s.y0, s.cz, yaw, tint=TONES.get(tone_of_roof(s), ""))
			elif s.kind == "tank":
				self.put("Props", "WaterTank", s.cx, s.y0 - 4, s.cz, 0.0 if s.cz >= 0 else 180.0)
			elif s.kind == "bb" and s.art == "Billboard":
				# advert faces the team roof it overlooks: B's faces +Z
				self.put("Props", "Billboard", s.cx, L.PIT, s.cz, 0.0 if s.cz > 0 else 180.0)
			elif s.kind == "bb" and s.art == "RoofSign":
				self.put("Props", "RoofSign", s.cx, s.y0 - 4, s.cz, 0.0 if s.cx < 0 else 180.0, glow=SIDE_GLOW[side])

	# ------------------------------------------------------------ street and skyline

	def street(self):
		# lamps along the block's sidewalks, every 24 / 20 studs, heads over the road
		for z in range(-60, 61, 24):
			for sx in (1, -1):
				self.put("Street", "StreetLamp", sx * (BLOCK_X + WALK_W - 1), STREET + 0.4, z, 0.0 if sx > 0 else 180.0)
		for x in range(-36, 37, 24):
			for sz in (1, -1):
				self.put("Street", "StreetLamp", x, STREET + 0.4, sz * (BLOCK_Z + WALK_W - 1), 270.0 if sz > 0 else 90.0)

	def skyline(self):
		# The landmark: the sign tower west of the map (its vertical HOTEL sign faces the map), and the radio mast
		# far to the north-east. Both stand outside the play space and have no collision.
		self.put("Skyline", "SignTower", -122, STREET, 18, 0.0, glow=SIDE_GLOW["west"])
		self.put("Skyline", "RadioMast", 210, STREET, -150, 0.0)
		# The neighbouring blocks across the streets: a ring of buildings, some under the roofs (you look down on
		# them), some over them. (piece, x, z, yaw, scale, face toward the map)
		ring = []
		for i, x in enumerate((-60, -20, 20, 60)):
			for sz in (1, -1):
				ring.append((x, sz * (NEIGHBOUR_Z + 14), 270.0 if sz > 0 else 90.0, i * 2 + (sz > 0)))
		for i, z in enumerate((-80, -40, 0, 40, 80)):
			for sx in (1, -1):
				if sx < 0 and abs(z - 18) < 30:
					continue  # the sign tower stands there
				ring.append((sx * (NEIGHBOUR_X + 14), z, 180.0 if sx > 0 else 0.0, 20 + i * 2 + (sx > 0)))
		for x, z, yaw, k in ring:
			# mostly at or under the roofs, so the sky stays open over the map and the landmark reads; one in
			# four a little taller (CityB at 0.7-0.8: tops about +5..+16)
			if h01("city", k) < 0.25:
				piece, scale = "CityB", 0.7 + 0.1 * h01("scale", k)
			else:
				piece, scale = "CityA", 0.75 + 0.45 * h01("scale", k)
			self.put("Skyline", piece, x, STREET + 0.4, z, yaw, scale=round(scale, 2))
		# the far skyline: taller towers further out
		for i in range(14):
			a = i / 14 * 2 * math.pi + 0.2
			r = 230 + 60 * h01("far", i)
			x, z = r * math.cos(a), r * math.sin(a)
			if abs(math.atan2(z - 18, x + 122)) < 0.2 and x < 0:
				continue
			piece = ("CityB", "CityC")[i % 2]
			self.put("Skyline", piece, x, STREET, z, (math.degrees(-a) + 180) % 360, scale=round(0.9 + 0.5 * h01("farscale", i), 2))

	def build(self):
		self.facades()
		self.pieces()
		self.street()
		self.skyline()
		return self


def tone_of_roof(s: S) -> str:
	"""Tone of the building a prop stands on."""
	if abs(s.cz) >= 24 and abs(s.cx) <= 48:
		return "teamB" if s.cz > 0 else "teamA"
	if abs(s.cx) >= 28:
		return "tower"
	return "pit"


def door_yaw(s: S) -> float:
	"""Huts: the door (local +X face) toward the open middle of their roof."""
	if s.art == "StairHut" and abs(s.cx) >= 28 and abs(s.cz) < 8:
		return 0.0 if s.cx < 0 else 180.0  # tower huts: the door toward the Pit, under the sign
	if s.art == "LiftTower":
		return 0.0
	cx = 0.0
	dx = cx - s.cx
	dz = (36.0 if s.cz > 0 else -36.0) - s.cz
	if abs(dx) > abs(dz):
		return 0.0 if dx > 0 else 180.0
	return 270.0 if dz > 0 else 90.0


def plain_parts():
	"""Art Parts (no collision): the street, sidewalks and road lines. Map space boxes; look = Greybox LOOK key."""
	out = [S("Street", "street", -400, 400, STREET - 2, STREET, -420, 420, look="Asphalt")]
	bx, bz, w = BLOCK_X, BLOCK_Z, WALK_W
	# the block's sidewalk ring (N/S own the corners)
	out += [
		S("Sidewalk", "walk", -bx - w, bx + w, STREET, STREET + 0.4, bz, bz + w, look="Sidewalk"),
		S("Sidewalk", "walk", -bx - w, bx + w, STREET, STREET + 0.4, -bz - w, -bz, look="Sidewalk"),
		S("Sidewalk", "walk", bx, bx + w, STREET, STREET + 0.4, -bz, bz, look="Sidewalk"),
		S("Sidewalk", "walk", -bx - w, -bx, STREET, STREET + 0.4, -bz, bz, look="Sidewalk"),
	]
	# the facing blocks' sidewalks (one band per side, broken at the crossings)
	nx, nz = NEIGHBOUR_X, NEIGHBOUR_Z
	for sgn in (1, -1):
		a, c = sorted((sgn * (nx - w), sgn * nx))
		out.append(S("Far sidewalk", "walk", a, c, STREET, STREET + 0.4, -nz + w, nz - w, look="Sidewalk"))
		a, c = sorted((sgn * (nz - w), sgn * nz))
		out.append(S("Far sidewalk", "walk", -nx - 60, nx + 60, STREET, STREET + 0.4, a, c, look="Sidewalk"))
	# road centre lines (0.05 proud) between the crossings (none inside a crossing, so no two lines overlap)
	lx, lz = bx + w + ROAD_W / 2, bz + w + ROAD_W / 2
	for sgn in (1, -1):
		out.append(S("Road line", "line", sgn * lx - 0.15, sgn * lx + 0.15, STREET, STREET + 0.05, -bz - w, bz + w, look="RoadLine"))
		out.append(S("Road line", "line", -bx - w, bx + w, STREET, STREET + 0.05, sgn * lz - 0.15, sgn * lz + 0.15, look="RoadLine"))
	return out


def luau_place() -> str:
	art = Art().build()
	lines = ["local PLACE: { Place } = {"]
	for sec, piece, x, y, z, yaw, tint, glow, scale in art.place:
		extra = ""
		if tint:
			extra += f', tint = "{tint[1:]}"'
		if glow:
			extra += f', glow = "{glow[1:]}"'
		if scale != 1.0:
			extra += f", scale = {L.num(scale)}"
		lines.append(f'\t{{ sec = "{sec}", piece = "{piece}", x = {L.num(x)}, y = {L.num(y)}, z = {L.num(z)}, yaw = {L.num(yaw)}{extra} }},')
	lines.append("}")
	lines.append("local PARTS: { { any } } = {")
	for s in plain_parts():
		lines.append(f'\t{{ "{s.name}", "{s.look}", {L.num(s.x0)}, {L.num(s.x1)}, {L.num(s.y0)}, {L.num(s.y1)}, {L.num(s.z0)}, {L.num(s.z1)} }},')
	lines.append("}")
	return "\n".join(lines)


if __name__ == "__main__":
	art = Art().build()
	from collections import Counter

	c = Counter(p[1] for p in art.place)
	print(f"{len(art.place)} placements, {len(plain_parts())} art Parts")
	for k, v in sorted(c.items()):
		print(f"  {k}: {v}")
