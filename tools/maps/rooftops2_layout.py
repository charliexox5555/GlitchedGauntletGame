#!/usr/bin/env python3
"""Rooftops2 map layout (the 2026-11-05 redesign of Rooftops; tools/maps/rooftops_layout.py is the old map, untouched): the plan as 3D boxes, its checks, its SVG and the generated Studio data.

Run: python tools/maps/rooftops2_layout.py [--write]
Prints the coplanar (z-fighting) check, prop clipping, gaps, sightlines between standing players,
spawn safety, cover spread, route times, time to first sight, jumps and heights, and writes
vault/02 Art/References/maps/rooftops2/rooftops2-layout.svg. With --write it also regenerates the
LAYOUT block of tools/studio/maps/Rooftops2/Greybox.luau and the PLACE block of
tools/studio/maps/Rooftops2/Art.luau (placements from tools/maps/rooftops_art.py), so Studio always
builds the layout that passed these checks.

Map space (MapKit.luau): studs, origin on the team roofs' surface at the map centre, +X across,
+Z along (team A spawns at -Z, team B at +Z), +Y up. 180-degree rotational symmetry: CENTER solids
are their own partners, HALF holds team B's half (and pieces whose partner is their rotation); the
A half is HALF rotated about the Y axis.

Every solid is an axis-aligned box (a wedge is its box with a slope). Kinds:
  body      building body, street to under the roof slab (hidden by the art: facades replace it)
  roof      roof slab (visible: the membrane you walk on)
  parapet   brick parapet run (visible Part); coping (its stone cap); pier and piercap
  ledge     1-high concrete curb along an alley (visible); sill (opening threshold, top flush)
  bridge    walkway deck over an alley (hidden by the art: catwalk / plank)
  stair     WedgePart stair (hidden by the art); rail (thin collision rail, hidden by the art)
  hut, ac, cond, sky, tank, leg, bb, bbleg   roof furniture (hidden by the art)
"""

from __future__ import annotations

import heapq
import math
import re
import sys
from dataclasses import dataclass, field, replace
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]

STREET = -72.0  # street level (map space)
KILL_DEPTH = 24.0  # MapService KillDepth: anyone below y = -24 dies
EYE = 5.0
BODY_H = 5.4
WALK = 16.0
SPRINT = 22.0
JUMP = 7.2
GRAVITY = 196.2
UPDRAFT = (14.0, 28.0)
DASH = (12.0, 24.0)
STEP = 1.2  # highest step you walk up
CLEAR = 1.4  # body clearance from walls for the walk grid
PIT = -8.0  # the Pit's roof level

BOUND_X = 60.0
BOUND_Z = 92.0


@dataclass
class S:
	"""A solid: an axis-aligned box in map space (a wedge when `up` is set: it rises toward up)."""

	name: str
	kind: str
	x0: float
	x1: float
	y0: float
	y1: float
	z0: float
	z1: float
	up: tuple[float, float] | None = None  # wedges: the (x, z) direction the top rises toward
	art: str = ""  # kit piece that replaces it (Art.luau hides it when that piece is installed)
	look: str = ""  # Part look for visible parts (Greybox.luau LOOK)
	tag: str = ""  # building or group id
	slope: tuple[float, float] | None = None  # rails along a stair: bottom y at the z0 end and the z1 end

	@property
	def cx(self):
		return (self.x0 + self.x1) / 2

	@property
	def cz(self):
		return (self.z0 + self.z1) / 2

	@property
	def sx(self):
		return self.x1 - self.x0

	@property
	def sz(self):
		return self.z1 - self.z0

	@property
	def h(self):
		return self.y1 - self.y0

	def rotated(self) -> "S":
		up = (-self.up[0], -self.up[1]) if self.up else None
		slope = (self.slope[1], self.slope[0]) if self.slope else None
		name = self.name[:-1] if self.name.endswith("'") else self.name + "'"
		return replace(self, name=name, x0=-self.x1, x1=-self.x0, z0=-self.z1, z1=-self.z0, up=up, slope=slope)

	def top_at(self, px, pz):
		"""Top surface height at (px, pz) (wedges slope)."""
		if self.up is None:
			return self.y1 + 0 * np.asarray(px, float)
		ux, uz = self.up
		half = (abs(ux) * self.sx + abs(uz) * self.sz) / 2
		t = ((np.asarray(px, float) - self.cx) * ux + (np.asarray(pz, float) - self.cz) * uz) / half
		return self.y0 + self.h * (np.clip(t, -1, 1) + 1) / 2

	def bottom_at(self, pz):
		"""Bottom height (sloped rails follow the stair)."""
		if self.slope is None:
			return self.y0 + 0 * np.asarray(pz, float)
		t = np.clip((np.asarray(pz, float) - self.z0) / self.sz, 0, 1)
		return self.slope[0] + (self.slope[1] - self.slope[0]) * t


FLOOR_KINDS = ("body", "roof", "sill", "ledge", "bridge", "stair", "flue")
PROP_KINDS = ("hut", "ac", "cond", "sky", "tank", "leg", "bb", "bbleg")
HIDDEN_BY_ART = ("body", "bridge", "stair", "rail", "flue") + PROP_KINDS
NO_SIGHT = ("rail", "leg", "bbleg")  # thin: ignored by the sight model
FULL_COVER = 7.0

BRICK_TOP = 2.7  # parapet brick top (relative to the roof); coping to 3.0
COPING = 0.1  # coping overhang
PIER = 1.4  # pier width along the edge; 0.2 proud of the parapet on both faces
PIER_TOP = 3.3
CAP = 0.1  # pier cap overhang
CAP_TOP = 3.5
LEDGE_TOP = 1.0


# ---------------------------------------------------------------- buildings and their edges

@dataclass
class Building:
	name: str
	x0: float
	x1: float
	z0: float
	z1: float
	roof: float  # roof surface level
	tone: str  # facade tint key (Art.luau)
	# Edge segments per side: (t0, t1, type). The X sides (S at z0, N at z1) run x0..x1 and own the corners;
	# the Z sides (W at x0, E at x1) run z0+1..z1-1. Types: parapet (piers at its ends and on the 8-grid),
	# parapet_flush (no piers, no inner coping overhang: beside a stair), ledge, sill.
	edges: dict = field(default_factory=dict)
	no_pier: tuple = ()  # corners ("NE", ...) that get no corner pier


def building_solids(b: Building) -> list[S]:
	R = b.roof
	out = [
		S(b.name + " body", "body", b.x0, b.x1, STREET, R - 1, b.z0, b.z1, art="Facade", tag=b.name),
		S(b.name + " roof", "roof", b.x0 + 1, b.x1 - 1, R - 1, R, b.z0 + 1, b.z1 - 1, look="Roof" if R == 0 else "RoofPit", tag=b.name),
	]
	corner_pier: dict = {}
	for side in ("S", "N", "W", "E"):  # X sides first: they own the corners
		out += side_solids(b, side, corner_pier)
	return out


def corner_of(b: Building, side: str, t: float) -> str:
	if side in ("S", "N"):
		return side + ("W" if t == b.x0 else "E") if t in (b.x0, b.x1) else ""
	if t == b.z0 + 1:
		return "S" + side
	if t == b.z1 - 1:
		return "N" + side
	return ""


def side_solids(b: Building, side: str, corner_pier: dict) -> list[S]:
	"""Edge parts of one side, in the 1-wide band inside the face."""
	R = b.roof
	xside = side in ("S", "N")
	if xside:
		face = b.z0 if side == "S" else b.z1
		inward = 1 if side == "S" else -1
	else:
		face = b.x0 if side == "W" else b.x1
		inward = 1 if side == "W" else -1
	a0, a1 = min(face, face + inward), max(face, face + inward)
	out = []
	n = b.name + " " + side

	def box(name, kind, t0, t1, c0, c1, y0, y1, look):
		if xside:
			return S(name, kind, t0, t1, y0, y1, c0, c1, look=look, tag=b.name)
		return S(name, kind, c0, c1, y0, y1, t0, t1, look=look, tag=b.name)

	def cut(t):
		# a Z side keeps 0.2 back from an X side's corner pier
		c = corner_of(b, side, t)
		return 0.2 if (not xside and c and corner_pier.get(c)) else 0.0

	for t0, t1, typ in b.edges.get(side, []):
		s0, s1 = t0 + cut(t0), t1 - cut(t1)
		if typ in ("ledge", "sill"):
			top = LEDGE_TOP if typ == "ledge" else 0.0
			out.append(box(n + " " + typ, typ, s0, s1, a0, a1, R - 1, R + top, "Ledge"))
			continue
		piers = []
		if typ == "parapet":
			for end, d in ((t0, 1), (t1, -1)):
				c = corner_of(b, side, end)
				if xside and c:
					if c in b.no_pier:
						continue
					corner_pier[c] = True
					piers.append(end + d * 0.5)
				elif cut(end) > 0:
					continue  # the X side's corner pier ends this run
				else:
					p = (s0 if d > 0 else s1) + d * (PIER / 2 + CAP)
					piers.append(p)
			grid0 = b.x0 if xside else b.z0
			k = math.ceil((t0 - grid0) / 8)
			while grid0 + 8 * k < t1:
				c = grid0 + 8 * k
				if all(abs(c - p) >= 4 for p in piers):
					piers.append(c)
				k += 1
			piers.sort()
		pts = [s0]
		for p in piers:
			pts += [p - PIER / 2, p + PIER / 2]
		pts.append(s1)
		inner = 0.0 if typ == "parapet_flush" else COPING
		c0, c1 = (a0 - inner, a1 + COPING) if inward < 0 else (a0 - COPING, a1 + inner)
		for i in range(0, len(pts), 2):
			r0, r1 = max(pts[i], s0), min(pts[i + 1], s1)
			if r1 - r0 > 0.3:
				out.append(box(n + " parapet", "parapet", r0, r1, a0, a1, R - 1, R + BRICK_TOP, "Brick"))
				out.append(box(n + " coping", "coping", r0, r1, c0, c1, R + BRICK_TOP, R + 3.0, "Coping"))
		for p in piers:
			out.append(box(n + " pier", "pier", p - PIER / 2, p + PIER / 2, a0 - 0.2, a1 + 0.2, R - 0.9, R + PIER_TOP, "Brick"))
			out.append(box(n + " pier cap", "piercap", p - PIER / 2 - CAP, p + PIER / 2 + CAP, a0 - 0.2 - CAP, a1 + 0.2 + CAP, R + PIER_TOP, R + CAP_TOP, "Coping"))
	return out


def rails_along_z(name, x0, x1, z0, z1, deck, slope=None):
	"""Collision rails (mid 1.5-1.8, top 3.2-3.5 above the deck) on both long sides of a walkway along Z."""
	out = []
	for r0, r1 in ((x0, x0 + 0.3), (x1 - 0.3, x1)):
		for h0 in (1.5, 3.2):
			if slope:
				sl = (slope[0] + h0, slope[1] + h0)
				out.append(S(name, "rail", r0, r1, min(sl) , max(sl) + 0.3, z0, z1, art="Rail", slope=sl))
			else:
				out.append(S(name, "rail", r0, r1, deck + h0, deck + h0 + 0.3, z0, z1, art="Rail"))
	return out


def water_tank(name, cx, cz, y=0.0, legs=7.0):
	"""Wooden tank (box stand-in for the drum, 9 wide and 10 tall) on four steel legs."""
	out = [S(name, "tank", cx - 4.5, cx + 4.5, y + legs, y + legs + 10, cz - 4.5, cz + 4.5, art="WaterTank")]
	for dx in (-3.5, 3.5):
		for dz in (-3.5, 3.5):
			out.append(S(name + " leg", "leg", cx + dx - 0.4, cx + dx + 0.4, y, y + legs, cz + dz - 0.4, cz + dz + 0.4, art="WaterTank"))
	return out


# ---------------------------------------------------------------- the layout

# Team B's building (A's is it rotated): 96 x 48, roof 0. The south edge runs along the alleys: openings
# for the west catwalk (x -44..-36), the Pit footbridge (x 11..19) and the east plank (x 32..40), a ledge
# elsewhere; parapets on the outer edges.
# Rooftops2 change 1: the team roofs are 56 deep (were 48); the extra 8 goes to the middle and back rows, so the
# spawns sit 8 further back and the first look across the Pit comes later.
TEAM = Building(
	"B Block", -48, 48, 24, 80, 0.0, "teamB",
	edges={
		"S": [(-48, -44, "ledge"), (-44, -36, "sill"), (-36, 5, "ledge"), (5, 13, "sill"), (13, 32, "ledge"), (32, 40, "sill"), (40, 48, "ledge")],
		"N": [(-48, 48, "parapet")],
		"W": [(25, 79, "parapet")],
		"E": [(25, 79, "parapet")],
	},
)
# The west tower (the east one is it rotated): 20 x 16, roof +8, the high ground of the side lanes. North:
# B's gangway lands (x -44..-36); south: A's plank ramp (B's east plank rotated, x -40..-32); east: a ledge
# over the Pit alley (a 16 drop to the Pit).
TOWER = Building(
	"West Tower", -48, -28, -8, 8, 8.0, "tower",
	edges={
		"S": [(-48, -40, "ledge"), (-40, -32, "sill"), (-32, -28, "ledge")],
		"N": [(-48, -44, "ledge"), (-44, -36, "sill"), (-36, -28, "ledge")],
		"W": [(-7, 7, "parapet")],
		"E": [(-7, 7, "ledge")],
	},
)
# The Pit (self-symmetric): 40 x 32, roof -8, parapet all round. B's stair climbs along the east parapet
# (x 11..19) to the north edge; A's (rotated) along the west parapet to the south edge.
# Rooftops2 change 3: the Pit stairs stand 6 nearer the middle (x 5..13, against the lift tower, free of the
# parapet), so the Pit is no longer the slow way across. The Pit condenser goes (it left slits round the stair).
PIT_B = Building(
	"Pit", -20, 20, -16, 16, PIT, "pit",
	edges={
		"S": [(-20, -13, "parapet"), (-13, -5, "sill"), (-5, 20, "parapet")],
		"N": [(-20, 5, "parapet"), (5, 13, "sill"), (13, 20, "parapet")],
		"W": [(-15, 15, "parapet")],
		"E": [(-15, 15, "parapet")],
	},
)
TOWER_Y = TOWER.roof

# The middle: the Pit building's lift tower (to +8) with the water tank on it, the landmark of the map.
CENTER = building_solids(PIT_B) + [
	S("Lift tower", "hut", -5, 5, PIT, 8, -4, 4, art="LiftTower"),
	*water_tank("Water tank", 0, 0, y=8, legs=4),
]

HALF = (
	building_solids(TEAM)
	+ building_solids(TOWER)
	+ [
		# Pit (B end): the stair up the east side, the footbridge over the alley onto the B roof.
		S("Pit stair", "stair", 5, 13, PIT, 0, 0, 16, up=(0, 1), art="Stair16"),
		*rails_along_z("Pit stair rail", 5, 13, 0, 16, PIT, slope=(PIT, 0.0)),
		S("Footbridge", "bridge", 5, 13, -1, 0, 16, 24, art="Catwalk8"),
		*rails_along_z("Footbridge rail", 5, 13, 16, 24, 0.0),
		# Side lanes: a steel gangway (rails) up from the B roof to the west tower, a plank ramp (no rails) up to
		# the east tower. Both rise 8 over the 16 alley.
		S("West gangway", "stair", -44, -36, 0, TOWER_Y, 8, 24, up=(0, -1), art="Gangway16"),
		*rails_along_z("West gangway rail", -44, -36, 8, 24, 0.0, slope=(TOWER_Y, 0.0)),
		S("East plank", "stair", 32, 40, 0, TOWER_Y, 8, 24, up=(0, -1), art="PlankRamp16"),
		# Pit cover (B end): an AC unit along the west parapet, a condenser against the lift tower, and the
		# B billboard: an advert on a steel frame at the Pit's north edge, facing the B roof (panel +1..+11, so it
		# cuts the lines between the roofs at eye height; you walk under it on the Pit).
		S("Pit AC", "ac", -18.5, -10.5, PIT, PIT + 7.5, 6.5, 10.5, art="ACUnit"),
		# Rooftops2 change 2: the billboard is 22 wide (was 18), reaching x +1, 4 short of the stair: it now cuts the
		# roof-to-roof diagonals that slipped past its inner end (first sight, the 128-136 lines).
		S("Pit billboard", "bb", -21, 1, 1, 11, 13.6, 14.6, art="Billboard22"),
		S("Pit billboard leg", "bbleg", -17.4, -16.6, PIT, 1, 13.7, 14.5, art="Billboard22"),
		S("Pit billboard leg", "bbleg", -3.4, -2.6, PIT, 1, 13.7, 14.5, art="Billboard22"),
		# West tower: a stair hut in the middle, the neon roof sign on a frame over it (21-31).
		S("Tower hut", "hut", -41, -35, TOWER_Y, TOWER_Y + 9, -3, 3, art="StairHut"),
		S("Roof sign", "bb", -38.6, -37.4, TOWER_Y + 13, TOWER_Y + 23, -7, 7, art="RoofSign"),
		S("Roof sign leg", "bbleg", -38.4, -37.6, TOWER_Y + 9, TOWER_Y + 13, -2.6, -1.8, art="RoofSign"),
		S("Roof sign leg", "bbleg", -38.4, -37.6, TOWER_Y + 9, TOWER_Y + 13, 1.8, 2.6, art="RoofSign"),
		# Flues: brick ventilation shafts on the B Block's south wall, one in each alley mouth (street to +10).
		# They close the alleys between the Pit and the towers, so no line runs down an alley from roof to roof.
		S("Flue", "flue", 20, 28, STREET, 10, 18, 24, art="Flue"),
		S("Flue", "flue", -28, -20, STREET, 10, 18, 24, art="Flue"),
		# B roof, a 3 x 3 of cover between 6-wide lanes. Front row (the alley edge): a stair hut west, an AC unit
		# in the middle and one east of the footbridge, skylights as half cover. Middle row: an AC unit west, the
		# Penthouse (the spawn screen), the lift house east. Back row: the spawn court, the water tank east.
		S("Stair hut", "hut", -33, -27, 0, 9, 30, 36, art="StairHut"),
		S("Roof AC", "ac", -4, 4, 0, 7.5, 30, 34, art="ACUnit"),
		S("Roof AC", "ac", 20, 28, 0, 7.5, 29, 33, art="ACUnit"),
		S("Skylight", "sky", -18, -10, 0, 3, 30, 34, art="Skylight"),
		S("Skylight", "sky", 38.5, 46.5, 0, 3, 31, 35, art="Skylight"),
		S("Roof AC", "ac", -46.5, -38.5, 0, 7.5, 48, 52, art="ACUnit"),
		# Rooftops2 change 4: a planter screen (full cover) against the west parapet in the front row: the deeper roof
		# opened a diagonal from the west lane across the Pit to the far corner; this cuts it and covers the lane.
		S("Planter", "ac", -46.6, -40.6, 0, 7.5, 36, 39, art="Planter"),
		S("Penthouse", "hut", -20, 20, 0, 11, 52, 60, art="Penthouse"),
		S("Lift house", "hut", 26, 34, 0, 10, 46, 54, art="LiftHouse"),
		S("Condenser", "cond", 42.5, 46.5, 0, 3, 52, 56, art="Condenser"),
		# Back corners: the B water tank on its brick tank house (east) and a cooling tower (west) close the
		# spawn court on both sides, so the court has two exits past the Penthouse.
		S("Tank house", "hut", 36.5, 46.5, 0, 8, 68.5, 78.5, art="TankHouse"),
		*water_tank("Water tank", 41.5, 73.5, y=8, legs=4),
		S("Cooling tower", "hut", -46.5, -36.5, 0, 8, 68.5, 78.5, art="CoolingTower"),
	]
)

SOLIDS = CENTER + HALF + [s.rotated() for s in HALF]
BUILDINGS = [TEAM, TOWER, PIT_B]  # + rotations of TEAM and TOWER (rot_building)
SPAWNS_B = [(-6.0, 68.0), (6.0, 68.0), (-6.0, 73.0), (6.0, 73.0)]
SPAWNS_A = [(-x, -z) for x, z in SPAWNS_B]
BARRIER_Z = 64.0  # full-width barrier across the B roof behind the Penthouse
BARRIER_X = (-47.0, 47.0)


def rot_building(b: Building, name: str, tone: str) -> Building:
	return Building(name, -b.x1, -b.x0, -b.z1, -b.z0, b.roof, tone)


ALL_BUILDINGS = [TEAM, rot_building(TEAM, "A Block", "teamA"), TOWER, rot_building(TOWER, "East Tower", "tower"), PIT_B]


# ---------------------------------------------------------------- grids

CELL = 1.0
XS = np.arange(-BOUND_X + 0.5, BOUND_X, CELL)
ZS = np.arange(-BOUND_Z + 0.5, BOUND_Z, CELL)
NX, NZ = len(XS), len(ZS)
GX, GZ = np.meshgrid(XS, ZS, indexing="ij")


def to_idx(x, z):
	return int(np.clip(np.floor((x + BOUND_X) / CELL), 0, NX - 1)), int(np.clip(np.floor((z + BOUND_Z) / CELL), 0, NZ - 1))


def covers(s: S):
	return (GX > s.x0) & (GX < s.x1) & (GZ > s.z0) & (GZ < s.z1)


class World:
	def __init__(self, solids):
		self.solids = solids
		self.floor = np.full(GX.shape, -np.inf)
		blockers = []
		lists = [[[] for _ in range(NZ)] for _ in range(NX)]
		for s in solids:
			m = covers(s)
			if not m.any():
				continue
			top = s.top_at(GX, GZ)
			bot = s.bottom_at(GZ)
			if s.kind in FLOOR_KINDS:
				self.floor = np.where(m, np.maximum(self.floor, top), self.floor)
			if s.kind not in NO_SIGHT:
				for i, j in zip(*np.nonzero(m)):
					lists[i][j].append((bot[i, j] if s.slope else s.y0, top[i, j]))
			if s.kind not in FLOOR_KINDS:
				blockers.append((s, m, bot, top))
		K = max(len(c) for row in lists for c in row)
		self.lo = np.full((K, NX, NZ), np.nan)
		self.hi = np.full((K, NX, NZ), np.nan)
		for i in range(NX):
			for j in range(NZ):
				for k, (a, b) in enumerate(lists[i][j]):
					self.lo[k, i, j] = a
					self.hi[k, i, j] = b
		self.stand = self.floor > -KILL_DEPTH
		# Blocked for walking: a blocker (or a rail) in the body's height range, dilated by the clearance.
		hard = np.zeros(GX.shape, bool)
		for s, m, bot, top in blockers:
			# rails count even though the sight model ignores them; the box footprint is dilated so thin parts count
			mm = (GX > s.x0 - CLEAR) & (GX < s.x1 + CLEAR) & (GZ > s.z0 - CLEAR) & (GZ < s.z1 + CLEAR)
			b0 = s.bottom_at(GZ) if s.slope else s.y0
			t1 = s.y1 if not s.slope else b0 + 0.3
			hit = mm & (b0 < self.floor + BODY_H) & (t1 > self.floor + 0.05)
			hard |= hit
		self.walk = self.stand & ~hard

	def tallest(self):
		"""Highest solid top per cell (any kind)."""
		return np.nanmax(np.where(np.isnan(self.hi), -np.inf, self.hi), axis=0)

	def clear_many(self, a: np.ndarray, b: np.ndarray, step=0.5) -> np.ndarray:
		"""a, b: (n, 3) points (x, z, y). True where the straight line is unblocked."""
		n = len(a)
		if n == 0:
			return np.zeros(0, bool)
		d = np.linalg.norm((b - a)[:, :2], axis=1)
		steps = int(max(2, math.ceil(d.max() / step)))
		t = np.linspace(0.0, 1.0, steps + 1)[None, :]
		px = a[:, 0:1] + (b[:, 0:1] - a[:, 0:1]) * t
		pz = a[:, 1:2] + (b[:, 1:2] - a[:, 1:2]) * t
		py = a[:, 2:3] + (b[:, 2:3] - a[:, 2:3]) * t
		ix = np.clip(np.floor((px + BOUND_X) / CELL).astype(int), 0, NX - 1)
		iz = np.clip(np.floor((pz + BOUND_Z) / CELL).astype(int), 0, NZ - 1)
		blocked = np.zeros(px.shape, bool)
		for k in range(self.lo.shape[0]):
			lo = self.lo[k][ix, iz]
			hi = self.hi[k][ix, iz]
			blocked |= (py >= lo) & (py <= hi)
		blocked[:, :2] = False
		blocked[:, -2:] = False
		return ~blocked.any(axis=1)

	def clear(self, a, b):
		return bool(self.clear_many(np.array([a], float), np.array([b], float))[0])


# ---------------------------------------------------------------- checks

def faces(s: S):
	"""Axis faces of a box: (axis, sign, plane, (u0, u1), (v0, v1)) with u, v the other two axes in order."""
	lo = (s.x0, s.y0, s.z0)
	hi = (s.x1, s.y1, s.z1)
	out = []
	for ax in range(3):
		u, v = [a for a in range(3) if a != ax]
		for sign, plane in ((-1, lo[ax]), (1, hi[ax])):
			if s.up is not None and ax == 1 and sign == 1:
				continue  # a wedge's top is the slope
			if s.up is not None and ax == 2 and sign == (1 if s.up[1] < 0 else -1) and s.up[1] != 0:
				continue  # the low end of a wedge has no face
			if s.up is not None and ax == 0 and sign == (1 if s.up[0] < 0 else -1) and s.up[0] != 0:
				continue
			out.append((ax, sign, plane, (lo[u], hi[u]), (lo[v], hi[v])))
	return out


def coplanar_pairs(parts: list[S], tol=0.02, min_overlap=0.05):
	"""Pairs of boxes with two faces in the same plane, facing the same way, whose rectangles overlap:
	the renderer flickers between them (z-fighting). Mirrors tools/studio/maps/Audit.luau."""
	buckets = {}
	for idx, s in enumerate(parts):
		if s.slope:
			continue  # sloped rails are rotated Parts
		for ax, sign, plane, uu, vv in faces(s):
			buckets.setdefault((ax, sign), []).append((plane, idx, uu, vv))
	bad = []
	for key, items in buckets.items():
		items.sort()
		for i in range(len(items)):
			p, a, ua, va = items[i]
			for j in range(i + 1, len(items)):
				q, b, ub, vb = items[j]
				if q - p > tol:
					break
				if a == b:
					continue
				du = min(ua[1], ub[1]) - max(ua[0], ub[0])
				dv = min(va[1], vb[1]) - max(va[0], vb[0])
				if du > min_overlap and dv > min_overlap:
					bad.append((parts[a], parts[b], key, p, du * dv))
	return bad


def overlap_volume(a: S, b: S):
	dx = min(a.x1, b.x1) - max(a.x0, b.x0)
	dy = min(a.y1, b.y1) - max(a.y0, b.y0)
	dz = min(a.z1, b.z1) - max(a.z0, b.z0)
	return dx * dy * dz if dx > 0.01 and dy > 0.01 and dz > 0.01 else 0.0


def gap(a: S, b: S) -> float:
	dx = max(a.x0 - b.x1, b.x0 - a.x1, 0.0)
	dz = max(a.z0 - b.z1, b.z0 - a.z1, 0.0)
	return math.hypot(dx, dz)


def dijkstra(world: World, starts):
	dist = np.full(GX.shape, np.inf)
	q = []
	for s in starts:
		i = to_idx(*s)
		dist[i] = 0.0
		q.append((0.0, i))
	heapq.heapify(q)
	nbr = [(dx, dz, math.hypot(dx, dz) * CELL) for dx in (-1, 0, 1) for dz in (-1, 0, 1) if dx or dz]
	F, Wk = world.floor, world.walk
	while q:
		c, (i, j) = heapq.heappop(q)
		if c > dist[i, j]:
			continue
		for dx, dz, st in nbr:
			a, b = i + dx, j + dz
			if not (0 <= a < NX and 0 <= b < NZ) or not Wk[a, b]:
				continue
			if F[a, b] - F[i, j] > STEP:
				continue
			if dx and dz and not (Wk[i + dx, j] and Wk[i, j + dz]):
				continue
			nc = c + st
			if nc < dist[a, b]:
				dist[a, b] = nc
				heapq.heappush(q, (nc, (a, b)))
	return dist


def first_sight(world, dist_a, dist_b, speed, grid=2):
	pts = []
	for i in range(0, NX, grid):
		for j in range(0, NZ, grid):
			if world.walk[i, j] and np.isfinite(dist_a[i, j]) and np.isfinite(dist_b[i, j]):
				pts.append((XS[i], ZS[j], world.floor[i, j] + EYE, dist_a[i, j] / speed, dist_b[i, j] / speed))
	P = np.array(pts)
	ta, tb = P[:, 3], P[:, 4]
	T = 0.0
	prevA = np.zeros(len(P), bool)
	prevB = np.zeros(len(P), bool)
	while T < 20:
		T += 0.1
		A, B = ta <= T, tb <= T
		newA, newB = A & ~prevA, B & ~prevB
		ia, ib = np.nonzero(newA)[0], np.nonzero(B)[0]
		pairs = [(i, j) for i in ia for j in ib]
		ia2, ib2 = np.nonzero(prevA)[0], np.nonzero(newB)[0]
		pairs += [(i, j) for i in ia2 for j in ib2]
		prevA, prevB = A, B
		if not pairs:
			continue
		pr = np.array(pairs)
		for k in range(0, len(pr), 4000):
			ch = pr[k : k + 4000]
			a = P[ch[:, 0]][:, :3]
			b = P[ch[:, 1]][:, :3]
			ok = world.clear_many(a, b)
			if ok.any():
				h = np.nonzero(ok)[0][0]
				return T, a[h], b[h]
	return None, None, None


def perches(world: World):
	"""Tops of solids a player can stand on with Updraft (not walk-reachable): (x, z, y, name)."""
	out = []
	for s in world.solids:
		if s.kind not in ("hut", "ac", "tank", "cond", "sky"):
			continue
		for x in np.arange(s.x0 + 0.5, s.x1, 2.0):
			for z in np.arange(s.z0 + 0.5, s.z1, 2.0):
				y = s.y1
				over = [o for o in world.solids if o is not s and o.x0 < x < o.x1 and o.z0 < z < o.z1 and o.y0 >= y - 0.01 and o.y0 < y + BODY_H and o.kind not in NO_SIGHT]
				if over:
					continue
				out.append((x, z, y, s.name))
	return out


def report(verbose=True):
	world = World(SOLIDS)
	out = {"world": world}
	P = print if verbose else (lambda *a, **k: None)
	P(f"Solids: {len(SOLIDS)}  (greybox Parts, both halves; {sum(1 for s in SOLIDS if s.kind in HIDDEN_BY_ART)} hidden by the art)")

	# --- z-fighting: every visible box, at the greybox stage and with the art (art plain parts included)
	import rooftops2_art as A  # noqa: E402

	art_parts = A.plain_parts()
	grey_bad = coplanar_pairs(SOLIDS)
	art_vis = [s for s in SOLIDS if s.kind not in HIDDEN_BY_ART] + art_parts
	art_bad = coplanar_pairs(art_vis)
	P(f"\nCoplanar faces (z-fighting), box faces in the same plane (< 0.02) facing the same way, overlapping:")
	P(f"  greybox stage ({len(SOLIDS)} parts): {len(grey_bad)}")
	P(f"  with the art ({len(art_vis)} visible parts incl. {len(art_parts)} art Parts): {len(art_bad)}")
	for a, b, key, p, area in (grey_bad + art_bad)[:20]:
		P(f"    {a.name} / {b.name}: axis {'xyz'[key[0]]}{'+' if key[1] > 0 else '-'} at {p:.2f}, {area:.2f} sq")
	out["coplanar"] = (len(grey_bad), len(art_bad))

	# --- props clipping anything (they may only touch)
	clips = []
	for i, a in enumerate(SOLIDS):
		if a.kind not in PROP_KINDS + ("stair", "bridge"):
			continue
		for b in SOLIDS:
			if b is a or (b.kind in ("leg", "bbleg") and a.kind in ("tank", "bb", "hut")) or (a.kind in ("leg", "bbleg") and b.kind in ("tank", "bb", "hut")):
				continue
			if b.kind == "rail" and a.kind in ("stair", "bridge"):
				continue
			if overlap_volume(a, b) > 0:
				clips.append((a.name, b.name))
	P(f"\nProps / bridges / stairs clipping another part: {len(clips)}")
	for a, b in clips[:12]:
		P(f"    {a} / {b}")
	out["clips"] = len(clips)

	# --- narrow gaps between things standing on the same roof
	# Props either stand against each other or an edge (gap under 0.6: the parapet's coping and piers
	# overhang 0.1-0.3) or leave a walkable lane (6+ between props, 4+ to an edge). Anything between is a
	# slit: a stuck spot and an unnatural gap.
	P("\nSlits between props, and between props and edges (should touch or leave a lane):")
	props = [s for s in SOLIDS if s.kind in ("hut", "ac", "cond", "sky", "stair")]
	edge_groups: dict = {}
	for s in SOLIDS:
		if s.kind in ("parapet", "ledge"):
			edge_groups.setdefault(s.name.split(" parapet")[0].split(" ledge")[0], []).append(s)
	narrow = 0
	seen = set()
	found = []
	for i, a in enumerate(props):
		for b in props[i + 1 :]:
			if abs(a.y0 - b.y0) < 1.5:
				found.append((a.name, b.name, gap(a, b), 6.0))
		if a.kind == "stair":
			continue  # stairs run along their edges on purpose
		for side, parts in edge_groups.items():
			if abs(a.y0 - (parts[0].y0 + 1)) > 0.2:
				continue
			found.append((a.name, side, min(gap(a, b) for b in parts), 4.0))
	for an, bn, g, lane in found:
		if 0.6 <= g < lane:
			key = tuple(sorted((an.rstrip("'"), bn.rstrip("'"))))
			if key in seen:
				continue
			seen.add(key)
			narrow += 1
			P(f"  {an} - {bn}: {g:.1f}")
	if not narrow:
		P("  none")

	# --- spawn safety
	P("\nSpawn safety:")
	F = world.floor
	sb = [(x, z, 0 + EYE) for x, z in SPAWNS_B]
	sa = [(x, z, 0 + EYE) for x, z in SPAWNS_A]
	cross = any(world.clear(a, b) for a in sa for b in sb)
	P("  any spawn A sees any spawn B:", cross)
	cells = [(XS[i], ZS[j], F[i, j] + EYE) for i in range(0, NX, 2) for j in range(0, NZ, 2) if world.walk[i, j]]
	enemy = [p for p in cells if p[1] < 20]  # everywhere team A can be before it reaches the B roof
	Aa = np.array([p for p in enemy for _ in sb])
	Bb = np.array([s for _ in enemy for s in sb])
	seen_m = world.clear_many(Aa, Bb).reshape(len(enemy), len(sb)).any(axis=1)
	P(f"  floor south of the B roof (z < 20) that sees a B spawn point: {100 * seen_m.mean():.1f}%")
	out["spawn_seen_from"] = [p for p, s in zip(enemy, seen_m) if s]
	tops = perches(world)
	et = [t for t in tops if t[1] < 20]
	Aa = np.array([(t[0], t[1], t[2] + EYE) for t in et for _ in sb])
	Bb = np.array([s for _ in et for s in sb])
	seen_t = world.clear_many(Aa, Bb).reshape(len(et), len(sb)).any(axis=1)
	hit = sorted({t[3] for t, s in zip(et, seen_t) if s})
	P(f"  Updraft perches south of the B roof that see a B spawn: {100 * seen_t.mean():.1f}% ({', '.join(hit) if hit else 'none'})")

	# --- sightlines between standing players
	pts = np.array([(XS[i], ZS[j], F[i, j] + EYE) for i in range(0, NX, 3) for j in range(0, NZ, 3) if world.walk[i, j]])
	ii, jj = np.triu_indices(len(pts), 1)
	dist = np.linalg.norm(pts[ii, :2] - pts[jj, :2], axis=1)
	vis = np.zeros(len(ii), bool)
	for k in range(0, len(ii), 20000):
		vis[k : k + 20000] = world.clear_many(pts[ii[k : k + 20000]], pts[jj[k : k + 20000]])
	vd = dist[vis]
	P(f"\nSightlines between standing players ({len(pts)} spots, {vis.sum()} of {len(vis)} pairs see each other):")
	P(f"  over 70 studs: {100 * (vd > 70).mean():.1f}% of visible pairs; over 100: {100 * (vd > 100).mean():.1f}%; longest {vd.max():.0f}")
	order = np.argsort(-dist * vis)
	shown, keys = 0, []
	longest = []
	for o in order:
		if not vis[o]:
			break
		a, b = pts[ii[o]], pts[jj[o]]
		key = (round(a[0] / 12), round(a[1] / 12), round(b[0] / 12), round(b[1] / 12))
		rkey = (-key[2], -key[3], -key[0], -key[1])
		if key in keys or rkey in keys or (key[2], key[3], key[0], key[1]) in keys:
			continue
		keys.append(key)
		longest.append((dist[o], a, b))
		P(f"  {dist[o]:.0f} studs  ({a[0]:.0f},{a[1]:.0f}, y{a[2] - EYE:.0f}) -> ({b[0]:.0f},{b[1]:.0f}, y{b[2] - EYE:.0f})")
		shown += 1
		if shown == 8:
			break
	out["longest"] = longest

	# --- cover spread
	tall = world.tallest()
	full = np.zeros(GX.shape, bool)
	dists = []
	worst, worst_at = 0.0, None
	for (x, z, y) in [c for c in cells if c[2] - EYE < 9][::2]:  # not the flue tops (perches)
		f = y - EYE
		r = 20
		m = (np.abs(GX - x) <= r) & (np.abs(GZ - z) <= r)
		# a cell is full cover for this floor when one solid there spans floor+1 .. floor+7
		cov = np.zeros(GX.shape, bool)
		for k in range(world.lo.shape[0]):
			cov |= (world.lo[k] <= f + 1) & (world.hi[k] >= f + FULL_COVER)
		cov &= m
		if not cov.any():
			d = r
		else:
			d = np.min(np.hypot(GX[cov] - x, GZ[cov] - z))
		dists.append(d)
		if d > worst:
			worst, worst_at = d, (x, z)
	P("\nCover spread (distance to the nearest full cover, 7+ above your floor):")
	P(f"  average {sum(dists) / len(dists):.1f}, furthest {worst:.1f} at ({worst_at[0]:.0f},{worst_at[1]:.0f})")

	# --- routes
	dist_a = dijkstra(world, SPAWNS_A)
	dist_b = dijkstra(world, SPAWNS_B)

	def at(d, p):
		return d[to_idx(*p)]

	pit_cells = (np.abs(GX) < 19) & (np.abs(GZ) < 15) & world.walk & (np.abs(F - PIT) < 0.1)
	routes = {
		"spawn to the Pit": float(np.min(dist_a[pit_cells])),
		"spawn to the Pit (8, -8)": at(dist_a, (8.5, -8.5)),
		"spawn to enemy spawn": at(dist_a, SPAWNS_B[0]),
		"spawn to enemy spawn via the west tower": at(dist_a, (-38.5, 5.5)) + at(dist_b, (-38.5, 5.5)),
		"spawn to enemy spawn via the Pit": at(dist_a, (8.5, -8.5)) + at(dist_b, (8.5, -8.5)),
		"spawn to enemy spawn via the east tower": at(dist_a, (38.5, -5.5)) + at(dist_b, (38.5, -5.5)),
		"spawn to own tower (west, plank)": at(dist_a, (-38.5, -5.5)),
		"spawn to own tower (east, catwalk)": at(dist_a, (38.5, -5.5)),
	}
	P("\nRoutes on foot (no jumps across gaps; from spawn A, sprinting 22 / walking 16):")
	for name, d in routes.items():
		P(f"  {name}: {d:.0f} studs, {d / SPRINT:.1f} s sprint / {d / WALK:.1f} s walk")
	both = np.isfinite(dist_a) & np.isfinite(dist_b)
	meet = np.min(np.maximum(dist_a, dist_b)[both])
	P(f"  both teams sprinting meet after {meet / SPRINT:.1f} s (walking {meet / WALK:.1f} s)")
	flue_top = np.zeros(GX.shape, bool)
	for s in SOLIDS:
		if s.kind == "flue":
			flue_top |= covers(s)
	unreach = world.walk & ~np.isfinite(dist_a) & ~flue_top
	P(f"  standable cells you can't walk to from spawn A: {int(unreach.sum())}")
	out["routes"] = routes
	out["unreach"] = int(unreach.sum())

	P("\nTime to first sight (both teams leave spawn at t = 0 on their shortest routes):")
	for label, speed in (("sprint", SPRINT), ("walk", WALK)):
		t, pa, pb = first_sight(world, dist_a, dist_b, speed)
		if t is None:
			P(f"  {label}: none within 20 s")
			continue
		P(f"  {label}: {t:.1f} s, A at ({pa[0]:.0f},{pa[1]:.0f}) sees B at ({pb[0]:.0f},{pb[1]:.0f})")
		out["first_" + label] = (t, pa, pb)

	# --- jumps and heights
	air = 2 * math.sqrt(2 * JUMP / GRAVITY)
	P("\nGaps (alleys) and how to cross them:")
	P(f"  standing jump airtime {air:.2f} s: walking jump {WALK * air:.1f} studs, sprinting jump {SPRINT * air:.1f}")
	P("  Pit <-> team roof: 8 across, 8 down (a sprint jump or a Dash; the stairs and footbridges on foot)")
	P("  Pit <-> tower: 8 across, 16 down (drop from the tower; Updraft back up)")
	P("  tower <-> team roof: 16 across, 8 up (the gangway or the plank ramp, or a Dash 16+)")
	reach = max(s.y1 for s in SOLIDS if s.kind in ("hut", "tank", "flue")) + JUMP + UPDRAFT[1]
	tops = sorted({(s.name.rstrip("'"), s.y1) for s in SOLIDS if s.kind in ("hut", "flue", "ac", "tank")}, key=lambda t: t[1])
	P(f"\nHeights: Pit {PIT:.0f}, team roofs 0, towers +{TOWER_Y:.0f} (three layers 8 apart)")
	P("  Updraft-only tops: " + ", ".join(f"{n} +{y:.0f}" for n, y in tops if y > 0))
	P(f"  highest reach {reach:.1f}; kill height y {-KILL_DEPTH:.0f} (KillDepth {KILL_DEPTH:.0f}): {PIT + KILL_DEPTH:.0f} below the Pit, {-KILL_DEPTH - STREET:.0f} above the street")
	t_fall = math.sqrt(2 * KILL_DEPTH / GRAVITY)
	P(f"  falling from a roof (0) dies after {t_fall:.2f} s; from the Pit after {math.sqrt(2 * (KILL_DEPTH + PIT) / GRAVITY):.2f} s")
	out["dist_a"] = dist_a
	return out


# ---------------------------------------------------------------- SVG

FILL = {
	"roof": "#5B5F69",
	"ledge": "#A9A49A",
	"sill": "#A9A49A",
	"parapet": "#8E4B3A",
	"coping": "#C9C1B0",
	"pier": "#7A3F31",
	"piercap": "#C9C1B0",
	"bridge": "#9AA3AE",
	"stair": "#B8BCC6",
	"hut": "#6E5D52",
	"ac": "#9EA6AE",
	"cond": "#B9C0C6",
	"sky": "#8FC1D6",
	"tank": "none",
	"bb": "#E0569A",
}


def svg(res) -> str:
	scale = 5.0
	pad = 40
	W = 2 * BOUND_X * scale + 2 * pad + 330
	H = 2 * BOUND_Z * scale + 2 * pad
	ox, oz = pad + BOUND_X * scale, pad + BOUND_Z * scale

	def px(x, z):
		return ox + x * scale, oz - z * scale

	o = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W:.0f} {H:.0f}" font-family="Segoe UI, Arial, sans-serif">',
		f'<rect width="{W:.0f}" height="{H:.0f}" fill="#141A2B"/>']
	a = px(-BOUND_X, BOUND_Z)
	o.append(f'<rect x="{a[0]:.0f}" y="{a[1]:.0f}" width="{2 * BOUND_X * scale:.0f}" height="{2 * BOUND_Z * scale:.0f}" fill="#1E2740"/>')
	# floor height shading: Pit darker
	world = res["world"]
	order = ["body", "roof", "ledge", "sill", "parapet", "coping", "pier", "piercap", "bridge", "stair", "sky", "cond", "ac", "hut", "tank", "bb"]
	for kind in order:
		for s in world.solids:
			if s.kind != kind:
				continue
			if kind == "body":
				fill = "#2E3548" if s.y1 < -2 else "#3A4157"
				a = px(s.x0, s.z1)
				o.append(f'<rect x="{a[0]:.1f}" y="{a[1]:.1f}" width="{s.sx * scale:.1f}" height="{s.sz * scale:.1f}" fill="{fill}"/>')
				continue
			fill = FILL.get(kind, "#888")
			if kind == "roof":
				fill = "#4C505B" if s.y1 < -2 else FILL["roof"]
			if kind == "parapet" and "Pit" in s.tag:
				fill = "#A68A66"
			if kind == "parapet" and "Tower" in s.tag:
				fill = "#A68A66"
			if kind == "parapet" and s.tag == "B Block":
				fill = "#6F7C8A"
			if kind == "bb" and s.cx > 0:
				fill = "#F0A830"
			a = px(s.x0, s.z1)
			if kind == "tank":
				c = px(s.cx, s.cz)
				o.append(f'<circle cx="{c[0]:.1f}" cy="{c[1]:.1f}" r="{4.5 * scale:.1f}" fill="#8A6A4A" fill-opacity="0.55" stroke="#D9C2A0" stroke-width="2" stroke-dasharray="5 3"/>')
				continue
			stroke = "#111" if kind in ("hut", "ac", "cond", "sky", "stair", "bridge") else "none"
			o.append(f'<rect x="{a[0]:.1f}" y="{a[1]:.1f}" width="{s.sx * scale:.1f}" height="{s.sz * scale:.1f}" fill="{fill}" stroke="{stroke}" stroke-width="1"/>')
			if kind == "stair":
				ux, uz = s.up
				c = px(s.cx - ux * s.sz * 0.3, s.cz - uz * s.sz * 0.3)
				d = px(s.cx + ux * s.sz * 0.3, s.cz + uz * s.sz * 0.3)
				o.append(f'<line x1="{c[0]:.0f}" y1="{c[1]:.0f}" x2="{d[0]:.0f}" y2="{d[1]:.0f}" stroke="#222" stroke-width="2" marker-end="url(#arr)"/>')
	o.insert(1, '<defs><marker id="arr" markerWidth="8" markerHeight="8" refX="4" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="#222"/></marker></defs>')
	for p in res["spawn_seen_from"]:
		a = px(p[0] - 1, p[1] + 1)
		o.append(f'<rect x="{a[0]:.1f}" y="{a[1]:.1f}" width="{2 * scale}" height="{2 * scale}" fill="#D1495B" opacity="0.55"/>')
	for sgn in (1, -1):
		a, b = px(BARRIER_X[0], sgn * BARRIER_Z), px(BARRIER_X[1], sgn * BARRIER_Z)
		o.append(f'<line x1="{a[0]:.0f}" y1="{a[1]:.0f}" x2="{b[0]:.0f}" y2="{b[1]:.0f}" stroke="#3D8BFF" stroke-width="4" opacity="0.85"/>')
	if res["longest"]:
		d, a, b = res["longest"][0]
		a, b = px(a[0], a[1]), px(b[0], b[1])
		o.append(f'<line x1="{a[0]:.0f}" y1="{a[1]:.0f}" x2="{b[0]:.0f}" y2="{b[1]:.0f}" stroke="#FF6B6B" stroke-width="2.5" stroke-dasharray="8 5"/>')
	fs = res.get("first_sprint")
	if fs:
		t, pa, pb = fs
		a, b = px(pa[0], pa[1]), px(pb[0], pb[1])
		o.append(f'<line x1="{a[0]:.0f}" y1="{a[1]:.0f}" x2="{b[0]:.0f}" y2="{b[1]:.0f}" stroke="#FFD166" stroke-width="2.5"/>')
		for p in (a, b):
			o.append(f'<circle cx="{p[0]:.0f}" cy="{p[1]:.0f}" r="5" fill="#FFD166"/>')
	for spawns, colour in ((SPAWNS_A, "#00B8D4"), (SPAWNS_B, "#FF7A4D")):
		for s in spawns:
			c = px(*s)
			o.append(f'<circle cx="{c[0]:.0f}" cy="{c[1]:.0f}" r="6" fill="{colour}" stroke="#111"/>')
	labels = {
		(0, 0): "LIFT (+4)", (0, 10): "PIT (-8)", (0, -10): "PIT (-8)",
		(0, 50): "PENTHOUSE", (0, -50): "PENTHOUSE", (0, 68): "B SPAWN", (0, -68): "A SPAWN",
		(-38, -11): "WEST TOWER", (38, 11): "EAST TOWER",
		(-40, 16): "CATWALK", (40, -16): "CATWALK", (36, 16): "PLANK", (-36, -16): "PLANK",
		(38, 63): "TANK", (-38, -63): "TANK", (0, 20): "alley", (0, -20): "alley",
		(-24, 0): "alley", (24, 0): "alley", (-38, 0): "PINK SIGN", (38, 0): "AMBER SIGN",
	}
	for (x, z), text in labels.items():
		c = px(x, z)
		o.append(f'<text x="{c[0]:.0f}" y="{c[1] + 4:.0f}" text-anchor="middle" font-size="11" font-weight="700" fill="#111" stroke="#F4F1EA" stroke-width="2.5" paint-order="stroke">{text}</text>')
	kx = pad + 2 * BOUND_X * scale + 30
	y = pad + 10
	o.append(f'<text x="{kx}" y="{y}" font-size="26" font-weight="700" fill="#F4F1EA">Rooftops</text>')
	o.append(f'<text x="{kx}" y="{y + 24}" font-size="13" fill="#B9BDCB">Layout v1 (checked), 180° rotation, 1v1 / 2v2</text>')
	y += 54
	rows = [
		("#3A4157", "Building (roof 0), alleys between"),
		("#2E3548", "The Pit (roof -8)"),
		("#6F7C8A", "Parapet 3 (B block; A block brick red)"),
		(FILL["ledge"], "Ledge 1 / sill (step off into the alley)"),
		(FILL["bridge"], "Catwalk (rails) / plank (none)"),
		(FILL["stair"], "Steel stair, rises along the arrow"),
		(FILL["hut"], "Penthouse / hut / lift room (full cover)"),
		(FILL["ac"], "AC unit 7 (full cover)"),
		(FILL["cond"], "Condenser 3 (half cover)"),
		(FILL["sky"], "Skylight 3 (half cover)"),
		("#8A6A4A", "Water tank on legs (7-17, see under)"),
		(FILL["bb"], "Billboard over the tower hut (13-23)"),
	]
	for colour, text in rows:
		o.append(f'<rect x="{kx}" y="{y}" width="20" height="16" fill="{colour}" stroke="#F4F1EA" stroke-width="0.5"/>')
		o.append(f'<text x="{kx + 30}" y="{y + 13}" font-size="13" fill="#F4F1EA">{text}</text>')
		y += 26
	if res["longest"]:
		o.append(f'<line x1="{kx}" y1="{y + 8}" x2="{kx + 20}" y2="{y + 8}" stroke="#FF6B6B" stroke-width="2.5" stroke-dasharray="8 5"/>')
		o.append(f'<text x="{kx + 30}" y="{y + 13}" font-size="13" fill="#F4F1EA">Longest line, {res["longest"][0][0]:.0f} studs</text>')
		y += 26
	if fs:
		o.append(f'<line x1="{kx}" y1="{y + 8}" x2="{kx + 20}" y2="{y + 8}" stroke="#FFD166" stroke-width="2.5"/>')
		o.append(f'<text x="{kx + 30}" y="{y + 13}" font-size="13" fill="#F4F1EA">First sight, {fs[0]:.1f} s sprinting</text>')
		y += 26
	o.append(f'<rect x="{kx}" y="{y}" width="20" height="16" fill="#D1495B" opacity="0.55"/>')
	o.append(f'<text x="{kx + 30}" y="{y + 13}" font-size="13" fill="#F4F1EA">Floor that sees an enemy spawn</text>')
	y += 26
	o.append(f'<line x1="{kx}" y1="{y + 8}" x2="{kx + 20}" y2="{y + 8}" stroke="#3D8BFF" stroke-width="4"/>')
	o.append(f'<text x="{kx + 30}" y="{y + 13}" font-size="13" fill="#F4F1EA">Spawn barrier</text>')
	y += 40
	o.append(f'<rect x="{kx}" y="{y}" width="{8 * scale:.0f}" height="6" fill="#F4F1EA"/>')
	o.append(f'<text x="{kx}" y="{y + 24}" font-size="13" fill="#B9BDCB">8 studs (one facade bay)</text>')
	o.append(f'<text x="{kx}" y="{y + 44}" font-size="13" fill="#B9BDCB">Street 72 below the roofs; kill at -24</text>')
	r = res["routes"]
	o.append(f'<text x="{kx}" y="{y + 64}" font-size="13" fill="#B9BDCB">Spawn to spawn {r["spawn to enemy spawn"]:.0f} studs walked</text>')
	o.append("</svg>")
	return "\n".join(o)


# ---------------------------------------------------------------- Studio data (Luau)

def num(v):
	v = round(float(v), 3)
	return f"{v:g}"


def luau_layout() -> str:
	import rooftops2_art as A  # noqa: E402

	lines = ["local LAYOUT: { Solid } = {"]
	for s in SOLIDS:
		extra = ""
		tone = A.tone_of(s)
		if tone and s.kind in ("parapet", "pier", "body", "flue"):
			extra += f', tone = "{tone}"'
		if s.up:
			extra += f", up = {{ {num(s.up[0])}, {num(s.up[1])} }}"
		if s.slope:
			extra += f", slope = {{ {num(s.slope[0])}, {num(s.slope[1])} }}"
		if s.art:
			extra += f', art = "{s.art}"'
		if s.look:
			extra += f', look = "{s.look}"'
		lines.append(
			f'\t{{ name = "{s.name}", kind = "{s.kind}", b = {{ {num(s.x0)}, {num(s.x1)}, {num(s.y0)}, {num(s.y1)}, {num(s.z0)}, {num(s.z1)} }}{extra} }},'
		)
	lines.append("}")
	lines.append("local SPAWNS_A = { " + ", ".join(f"{{ {num(x)}, {num(z)} }}" for x, z in SPAWNS_A) + " }")
	lines.append("local SPAWNS_B = { " + ", ".join(f"{{ {num(x)}, {num(z)} }}" for x, z in SPAWNS_B) + " }")
	lines.append(f"local BARRIER_Z = {num(BARRIER_Z)}")
	lines.append(f"local BARRIER_W = {num(BARRIER_X[1] - BARRIER_X[0])}")
	lines.append(f"local KILL_DEPTH = {num(KILL_DEPTH)}")
	return "\n".join(lines)


def write_block(path: Path, tag: str, body: str, source: str):
	if not path.exists():
		print(f"(no {path.relative_to(ROOT)} yet: skipped its {tag} block)")
		return
	text = path.read_text(encoding="utf-8")
	block = f"-- BEGIN {tag} (generated by {source}; edit there)\n" + body + f"\n-- END {tag}"
	new, n = re.subn(rf"-- BEGIN {tag}.*?-- END {tag}", lambda m: block, text, flags=re.S)
	assert n == 1, f"no {tag} block in {path}"
	path.write_text(new, encoding="utf-8", newline="\n")
	print(f"Wrote the {tag} block of {path.relative_to(ROOT)}")


if __name__ == "__main__":
	sys.path.insert(0, str(Path(__file__).resolve().parent))
	res = report()
	target = ROOT / "vault/02 Art/References/maps/rooftops2/rooftops2-layout.svg"
	target.parent.mkdir(parents=True, exist_ok=True)
	target.write_text(svg(res), encoding="utf-8", newline="\n")
	print(f"\nWrote {target.relative_to(ROOT)}")
	if "--write" in sys.argv:
		import rooftops2_art as A  # noqa: E402

		write_block(ROOT / "tools/studio/maps/Rooftops2/Greybox.luau", "LAYOUT", luau_layout(), "tools/maps/rooftops2_layout.py --write")
		write_block(ROOT / "tools/studio/maps/Rooftops2/Art.luau", "PLACE", A.luau_place(), "tools/maps/rooftops2_layout.py --write")
	g, a = res["coplanar"]
	if g or a or res["clips"]:
		sys.exit("FAIL: z-fighting or clipping (see above)")
