"""Bunker2 map layout (the 2026-11-06 rebuild of Bunker to the Map Quality Standard): a copy of tools/maps/bunker_layout.py
with a new map id and origin; the plan, its numbers and its checks are unchanged (vault/01 Design/Maps/Bunker2.md).

Bunker map layout: the plan as data, its checks, its SVG and the greybox it builds.

Run:  python tools/maps/bunker2_layout.py            checks + SVG
      python tools/maps/bunker2_layout.py --luau     ...and rewrites tools/studio/maps/Bunker2/Greybox.luau
                                                    (and Art.luau when the kit export exists)
                                                    (then: stylua tools/studio/maps/Bunker2)

The map is a list of collision blocks (boxes and ramps) in map space: studs, origin on the atrium floor at the
centre of the sunwell, +X across (east), +Z along (team B's end, the blue end), +Y up. Team A spawns at -Z. Only
one of each 180-degree pair is listed (HALF) plus the pieces that are their own partner (CENTER): team A's half is
HALF turned 180 degrees about Y, so the map is fair by construction.

Checks (all must pass; the script exits 1 otherwise):
  * no two greybox blocks overlap in volume (they only butt), so no two greybox faces can share a plane and
    overlap facing the same way;
  * the COPLANAR CHECK (z-fighting, vault/01 Design/Maps/00 Maps.md -> No z-fighting): the box faces of every
    visible placed part (the greybox parts the art keeps visible plus every kit MeshPart's box from
    art-source/maps/Bunker2/Exports/Bunker2.json, placed by bunker2_art.py) are compared pairwise: parallel, facing
    the same way, plane distance < 0.02 and overlapping rectangles (> 0.05 x 0.05) is a z-fight unless the spot is
    buried inside another visible solid box (the same rule as tools/studio/maps/Audit.luau);
  * 2.5D play checks on a 0.5-stud voxel grid (players are 5.5-stud columns that walk, step, jump up to 7 and drop):
    gaps, sealing, spawn safety, route times, first sight, first contact, long sightlines, cover spread.
Writes vault/02 Art/References/maps/bunker2/bunker2-layout.svg. Needs numpy.
"""

from __future__ import annotations

import heapq
import math
import sys
from dataclasses import dataclass
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
SVG_OUT = ROOT / "vault/02 Art/References/maps/bunker2/bunker2-layout.svg"
LUAU_OUT = ROOT / "tools/studio/maps/Bunker2/Greybox.luau"
ORIGIN = (-3000, 200, 1500)

# ------------------------------------------------------------------ numbers

EYE = 5.0  # eye above the floor
BODY = 5.5  # standing height
JUMP = 7.0  # highest ledge you can jump onto (Config/Movement JUMP_HEIGHT 7.2)
SPRINT = 22.0  # Config/Movement SPRINT_SPEED
WALK = 16.0  # Config/Movement WALK_SPEED
R = 0.5  # voxel size
XMIN, XMAX = -46.0, 46.0
ZMIN, ZMAX = -104.0, 104.0
YMIN, YMAX = -2.0, 70.0

# Key heights
FLOOR = 0.0
DECK = 12.0  # the ring catwalk and the overlooks (top of deck)
DECK_UNDER = 10.5  # underside of the decks (doors under them are 10 tall)
DOOR_H = 10.0
LOW = 12.0  # ceiling of the corridors, rooms, vestibule and spawn
HALL = 26.0  # ceiling of the sunwell and the galleries
ROOF = 28.0  # top of the tall walls and roofs
SHAFT_TOP = 64.0  # the skylight

# Plan
ATR = 20.0  # sunwell interior |x|, |z| < 20 (walls 20..22)
SHAFT = 12.0  # light shaft hole |x|, |z| < 12 (shaft walls 12..14)
RING_IN = 13.0  # ring catwalk band 13..20 (parapet 13..14, 6 clear)
GAL = 12.0  # gallery interior |x| < 12 (walls 12..14), z 22..52
GAL_Z1 = 52.0
VEST_Z0, VEST_Z1 = 54.0, 66.0  # vestibule (cross hall) z 54..66, its north wall 66..68
SPAWN_Z0, SPAWN_Z1 = 68.0, 100.0  # spawn room interior z 68..100 (back wall 100..102), |x| < 18
SPAWN_X = 18.0
COR_X0, COR_X1 = 32.0, 40.0  # flank corridors, shell 40..42
PUMP_Z = 14.0  # pump rooms |z| < 14 (walls 14..16), x 22..40


# ------------------------------------------------------------------ blocks

@dataclass
class Block:
    """A collision box. kind: floor, wall, roof, deck, low, cover, prop, glass, dais.
    art: what the art pass does with it ("hide" = the kit replaces it, else a finish name)."""

    name: str
    section: str
    x0: float
    x1: float
    y0: float
    y1: float
    z0: float
    z1: float
    kind: str = "wall"
    art: str = ""

    def rotated(self) -> "Block":
        return Block(self.name, self.section, -self.x1, -self.x0, self.y0, self.y1, -self.z1, -self.z0, self.kind, self.art)

    @property
    def cx(self) -> float:
        return (self.x0 + self.x1) / 2

    @property
    def cz(self) -> float:
        return (self.z0 + self.z1) / 2

    @property
    def lo(self):
        return (self.x0, self.y0, self.z0)

    @property
    def hi(self):
        return (self.x1, self.y1, self.z1)


@dataclass
class Ramp:
    """A wedge: its top surface rises from y0 at the `low` end to y1 at the other, along Z."""

    name: str
    section: str
    x0: float
    x1: float
    y0: float
    y1: float
    z0: float
    z1: float
    up: int  # +1: rises toward +Z, -1: rises toward -Z
    kind: str = "ramp"
    art: str = "hide"

    def rotated(self) -> "Ramp":
        return Ramp(self.name, self.section, -self.x1, -self.x0, self.y0, self.y1, -self.z1, -self.z0, -self.up, self.kind, self.art)

    def height(self, z: float) -> float:
        t = (z - self.z0) / (self.z1 - self.z0)
        t = t if self.up > 0 else 1 - t
        return self.y0 + (self.y1 - self.y0) * min(max(t, 0.0), 1.0)


def B(name, section, x0, x1, y0, y1, z0, z1, kind="wall", art=""):
    return Block(name, section, x0, x1, y0, y1, z0, z1, kind, art)


DOORS_HALF: list = []  # (kind, x0, x1, y0, y1, z0, z1): each opening's box through its wall (team B's half)


def wall_with_door(name, section, axis, a0, a1, t0, t1, y1, doors, art="", lintel_from=DOOR_H, kind="door"):
    """A wall along `axis` ("x" or "z") from a0 to a1, thickness t0..t1 across, floor to y1, with door openings
    (d0, d1) floor to `lintel_from`. Returns butt-jointed boxes: piers between doors (full height) and a lintel
    over each door. No two boxes overlap. The openings are recorded in DOORS_HALF (the art pass lines them)."""
    for d0, d1 in doors:
        if axis == "x":
            DOORS_HALF.append((kind, d0, d1, FLOOR, lintel_from, t0, t1))
        else:
            DOORS_HALF.append((kind, t0, t1, FLOOR, lintel_from, d0, d1))
    out = []
    edges = [a0]
    for d0, d1 in sorted(doors):
        edges += [d0, d1]
    edges.append(a1)

    def box(b0, b1, ya, yb, nm):
        if axis == "x":
            return B(nm, section, b0, b1, ya, yb, t0, t1, "wall", art)
        return B(nm, section, t0, t1, ya, yb, b0, b1, "wall", art)

    for i in range(0, len(edges), 2):
        if edges[i + 1] - edges[i] > 1e-6:
            out.append(box(edges[i], edges[i + 1], FLOOR, y1, name))
    for d0, d1 in doors:
        out.append(box(d0, d1, lintel_from, y1, name + "Lintel"))
    return out


# The centre: blocks that are their own 180-degree partner.
CENTER: list = [
    B("SunwellFloor", "Sunwell", -22, 22, -1, FLOOR, -22, 22, "floor", "polished"),
    # The sun dais under the light shaft: a half-stud step with the brass sun compass (kit SunDais).
    B("SunDais", "Sunwell", -8, 8, FLOOR, 0.5, -8, 8, "dais", "hide"),
    # The sun plinth: the lit landmark under the shaft and full cover that closes the gallery-to-gallery line.
    B("SunPlinth", "Sunwell", -4, 4, 0.5, 8.5, -4, 4, "cover", "hide"),
    # Skylight at the top of the shaft: visible glass (kit ShaftTop draws the frame and glazing bars).
    B("Skylight", "Shaft", -14, 14, SHAFT_TOP, SHAFT_TOP + 0.5, -14, 14, "glass", "hide"),
]

# Team B's half (+Z) and the crossing pieces of one side. Team A's half is this list rotated.
HALF: list = []

# --- Sunwell (the atrium): walls, roof, shaft, ring catwalk -------------------------------------------------
# B wall (z 20..22): a ground door to the B gallery (x 3..11), the ring deck level, an upper opening (x -8..8,
# deck to 22) from the B overlook onto the ring.
HALF += [
    B("SunwellWallB", "Sunwell", -22, 3, FLOOR, DOOR_H, ATR, ATR + 2),
    B("SunwellWallB", "Sunwell", 11, 22, FLOOR, DOOR_H, ATR, ATR + 2),
    B("SunwellWallBBand", "Sunwell", -22, 22, DOOR_H, DECK, ATR, ATR + 2),
    B("SunwellWallB", "Sunwell", -22, -4, DECK, ROOF, ATR, ATR + 2),
    B("SunwellWallB", "Sunwell", 4, 22, DECK, ROOF, ATR, ATR + 2),
    B("SunwellWallBHead", "Sunwell", -4, 4, 22, ROOF, ATR, ATR + 2),
]
DOORS_HALF += [("door", 3, 11, FLOOR, DOOR_H, ATR, ATR + 2), ("door", -4, 4, DECK, DECK + DOOR_H, ATR, ATR + 2)]
# East wall (x 20..22): a ground door into the east pump room (z -4..4).
HALF += wall_with_door("SunwellWallE", "Sunwell", "z", -ATR, ATR, ATR, ATR + 2, ROOF, [(-4, 4)])
# Roof around the shaft hole (pinwheel: N and E here, S and W by rotation).
HALF += [
    B("SunwellRoof", "Sunwell", -SHAFT, ATR, HALL, ROOF, SHAFT, ATR, "roof"),
    B("SunwellRoof", "Sunwell", SHAFT, ATR, HALL, ROOF, -ATR, SHAFT, "roof"),
    B("ShaftWall", "Shaft", -SHAFT, SHAFT + 2, ROOF, SHAFT_TOP, SHAFT, SHAFT + 2, "wall", "hide"),
    B("ShaftWall", "Shaft", SHAFT, SHAFT + 2, ROOF, SHAFT_TOP, -SHAFT - 2, SHAFT, "wall", "hide"),
]
# Ring catwalk at +12 (band 14..20 inside the sunwell walls) with a 3-tall parapet on its inner edge (half
# cover). Pinwheel strips: they butt, never overlap.
HALF += [
    B("RingDeck", "Ring", -RING_IN, ATR, DECK_UNDER, DECK, RING_IN, ATR, "deck", "ring"),
    B("RingDeck", "Ring", RING_IN, ATR, DECK_UNDER, DECK, -ATR, RING_IN, "deck", "ring"),
    B("RingParapet", "Ring", -RING_IN, RING_IN + 1, DECK, DECK + 3, RING_IN, RING_IN + 1, "low", "ring"),
    B("RingParapet", "Ring", RING_IN, RING_IN + 1, DECK, DECK + 3, -RING_IN - 1, RING_IN, "low", "ring"),
]
# Sunwell cover (one of each pair): a low console bank and a full-cover generator.
HALF += [
    B("Console", "Sunwell", -12, -4, FLOOR, 3, 10, 12, "low", "hide"),
    B("Generator", "Sunwell", 10, 14, FLOOR, 7, 2, 8, "cover", "hide"),
]

# --- Gallery (team B's middle lane) ----------------------------------------------------------------------------
HALF += [
    B("GalleryFloor", "Gallery", -GAL - 2, GAL + 2, -1, FLOOR, ATR + 2, VEST_Z0, "floor", "honed"),
    B("GalleryRoof", "Gallery", -GAL, GAL, HALL, ROOF, ATR + 2, GAL_Z1, "roof"),
    # The overlook: a balcony over the gallery's sunwell end, level with the ring.
    B("OverlookDeck", "Gallery", -GAL, GAL, DECK_UNDER, DECK, ATR + 2, 31, "deck", "ring"),
    B("OverlookParapet", "Gallery", -GAL, 6, DECK, DECK + 3, 30, 31, "low", "ring"),
    # The jammed blast door: a 16-wide frame (x -4..12) whose east leaf stuck shut; the west half is the passage.
    B("BlastLeaf", "Gallery", 4, 10, FLOOR, DECK, GAL_Z1 + 0.5, GAL_Z1 + 1.5, "cover", "hide"),
    # Cover: a generator in the open half of the gallery.
    B("Generator", "Gallery", -6, 0, FLOOR, 7, 38, 44, "cover", "hide"),
]
HALF += wall_with_door("GalleryWallE", "Gallery", "z", ATR + 2, GAL_Z1, GAL, GAL + 2, ROOF, [(23, 31)])
HALF += wall_with_door("GalleryWallW", "Gallery", "z", ATR + 2, GAL_Z1, -GAL - 2, -GAL, ROOF, [(36, 44)])
HALF += wall_with_door("GalleryBack", "Gallery", "x", -GAL - 2, GAL + 2, GAL_Z1, GAL_Z1 + 2, ROOF, [(-4, 10)], lintel_from=DECK, kind="blast")

# --- East side, team B: the locker room and the east corridor --------------------------------------------------
HALF += [
    B("EastFloor", "Lockers", GAL + 2, 42, -1, FLOOR, ATR + 2, VEST_Z0, "floor", "honed"),
    B("EastFloor", "Lockers", ATR + 2, 42, -1, FLOOR, 16, ATR + 2, "floor", "honed"),
    B("EastRoof", "Lockers", GAL + 2, 42, LOW, LOW + 1, ATR + 2, VEST_Z0, "roof"),
    B("EastRoof", "Lockers", ATR + 2, 42, LOW, LOW + 1, 16, ATR + 2, "roof"),
    B("LockerWallN", "Lockers", GAL + 2, COR_X0, FLOOR, LOW, 50, VEST_Z0),
    B("Lockers", "Lockers", GAL + 2, 30, FLOOR, 8, 48, 50, "cover", "hide"),
    B("LockerIsland", "Lockers", 20, 24, FLOOR, 8, 30, 38, "cover", "hide"),
]
HALF += wall_with_door("LockerWallE", "Lockers", "z", 16, 50, 30, COR_X0, LOW, [(39, 47)])

# --- East pump room (crosses the middle; the west one is its rotation) ----------------------------------------
HALF += [
    B("PumpFloor", "Pump", ATR + 2, 42, -1, FLOOR, -16, 16, "floor", "honed"),
    B("PumpRoof", "Pump", ATR + 2, 42, LOW, LOW + 1, -16, 16, "roof"),
    B("PumpStub", "Pump", 30, COR_X0, FLOOR, LOW, PUMP_Z, 16),
    B("PumpStub", "Pump", 30, COR_X0, FLOOR, LOW, -16, -PUMP_Z),
    # The pump: blocks the straight corridor line, so the flank weaves through the room.
    B("PumpUnit", "Pump", 30, COR_X1, FLOOR, 8, -6, 6, "cover", "hide"),
    B("Manifold", "Pump", ATR + 2, 24, FLOOR, 3, 6, 10, "low", "hide"),
    # The shell (one long wall down the east side; the west one is its rotation).
    B("ShellE", "Shell", COR_X1, 42, FLOOR, LOW, -VEST_Z1 - 2, VEST_Z1 + 2),
]

# --- West side, team B: the control room and the west corridor -------------------------------------------------
HALF += [
    B("WestFloor", "Control", -42, -GAL - 2, -1, FLOOR, ATR + 2, VEST_Z0, "floor", "honed"),
    B("WestFloor", "Control", -42, -ATR - 2, -1, FLOOR, 16, ATR + 2, "floor", "honed"),
    B("WestRoof", "Control", -42, -GAL - 2, LOW, LOW + 1, ATR + 2, VEST_Z0, "roof"),
    B("WestRoof", "Control", -42, -ATR - 2, LOW, LOW + 1, 16, ATR + 2, "roof"),
    B("ControlWallN", "Control", -COR_X0, -GAL - 2, FLOOR, LOW, 50, VEST_Z0),
    # Solid mass between the control room and the west pump room: the pump room's lockers-side opening has no
    # partner here, so no line runs from one team's lockers through both pump rooms' inner bands.
    B("ControlCore", "Control", -30, -ATR - 2, FLOOR, LOW, 16, ATR + 2),
    B("Racks", "Control", -30, -GAL - 2, FLOOR, 8, 48, 50, "cover", "hide"),
    B("ControlDesk", "Control", -24, -20, FLOOR, 3, 32, 40, "low", "hide"),
]
HALF += wall_with_door("ControlWallW", "Control", "z", 16, 50, -COR_X0, -30, LOW, [(23, 31)])

# --- Vestibule and spawn ---------------------------------------------------------------------------------------
HALF += [
    B("VestibuleFloor", "Vestibule", -42, 42, -1, FLOOR, VEST_Z0, VEST_Z1 + 2, "floor", "honed"),
    B("VestibuleRoof", "Vestibule", -42, 42, LOW, LOW + 1, VEST_Z0, VEST_Z1 + 2, "roof"),
    B("SupplyCage", "Vestibule", 18, 24, FLOOR, 7, VEST_Z0, 58, "cover", "hide"),
    B("CrateRow", "Vestibule", -26, -20, FLOOR, 3, 63, VEST_Z1, "low", "hide"),
    B("SpawnFloor", "Spawn", -SPAWN_X - 2, SPAWN_X + 2, -1, FLOOR, SPAWN_Z0, SPAWN_Z1 + 2, "floor", "honed"),
    B("SpawnRoof", "Spawn", -SPAWN_X - 2, SPAWN_X + 2, LOW, LOW + 1, SPAWN_Z0, SPAWN_Z1 + 2, "roof"),
    B("SpawnWall", "Spawn", SPAWN_X, SPAWN_X + 2, FLOOR, LOW, SPAWN_Z0, SPAWN_Z1),
    B("SpawnWall", "Spawn", -SPAWN_X - 2, -SPAWN_X, FLOOR, LOW, SPAWN_Z0, SPAWN_Z1),
    B("SpawnWallBack", "Spawn", -SPAWN_X - 2, SPAWN_X + 2, FLOOR, LOW, SPAWN_Z1, SPAWN_Z1 + 2),
]
# Vestibule north wall: two 8-wide spawn doors either side of a 12-wide baffle.
HALF += wall_with_door("VestibuleWallN", "Vestibule", "x", -COR_X1, COR_X1, VEST_Z1, VEST_Z1 + 2, LOW, [(-SPAWN_X + 1, -9), (9, SPAWN_X - 1)])

HALF_RAMPS: list = [
    # The gallery stair up to the overlook (rises toward the sunwell).
    Ramp("GalleryStair", "Gallery", 6, GAL, FLOOR, DECK, 31, 49, -1),
]

BLOCKS: list = CENTER + HALF + [b.rotated() for b in HALF]
RAMPS: list = HALF_RAMPS + [r.rotated() for r in HALF_RAMPS]
DOORS: list = DOORS_HALF + [(k, -x1, -x0, y0, y1, -z1, -z0) for k, x0, x1, y0, y1, z0, z1 in DOORS_HALF]

SPAWNS_B = [(-6.0, 88.0), (6.0, 88.0), (-6.0, 94.0), (6.0, 94.0)]
SPAWNS_A = [(-x, -z) for x, z in SPAWNS_B]
BARRIERS_B = [
    B("Barrier", "Barriers", -SPAWN_X + 1, -9, FLOOR, DOOR_H, VEST_Z1, VEST_Z1 + 2),
    B("Barrier", "Barriers", 9, SPAWN_X - 1, FLOOR, DOOR_H, VEST_Z1, VEST_Z1 + 2),
]

# Places (team A's own side; for route times from A's spawn).
WAYPOINTS = {
    "sunwell (mid)": (-10.0, 0.0, FLOOR),
    "ring": (17.0, 0.0, DECK),
    "east pump": (27.0, 0.0, FLOOR),
    "west pump": (-27.0, 0.0, FLOOR),
}


# ------------------------------------------------------------------ the coplanar (z-fighting) check

PLANE_TOL = 0.02  # same plane
MIN_SIDE = 0.05  # overlap smaller than this in either direction is an edge contact, not a z-fight
BURY_OFF = 0.03  # a spot is hidden if the point this far outside it is inside another visible solid box


def coplanar_check(boxes, solids=None, samples=5, min_hits=3, limit=40):
    """boxes: list of (label, lo(3), hi(3)) axis-aligned boxes that are visible. Faces of two boxes that are
    parallel, face the same way, lie within PLANE_TOL of one plane and overlap in a rectangle at least
    MIN_SIDE on each side are a z-fight, unless the spot is buried in another visible solid box (solids: the
    boxes that hide what is inside them; default = boxes). Returns the list of fights (label_a, label_b,
    axis, sign, plane, area)."""
    solids = boxes if solids is None else solids
    S = np.array([[*lo, *hi] for _, lo, hi in solids], dtype=float) if solids else np.zeros((0, 6))
    fights = []
    # Spatial hash on the XZ footprint (cells of 8 studs).
    cell = 8.0
    grid = {}
    for i, (_, lo, hi) in enumerate(boxes):
        for gx in range(int(math.floor((lo[0] - 0.1) / cell)), int(math.floor((hi[0] + 0.1) / cell)) + 1):
            for gz in range(int(math.floor((lo[2] - 0.1) / cell)), int(math.floor((hi[2] + 0.1) / cell)) + 1):
                grid.setdefault((gx, gz), []).append(i)
    seen = set()
    for members in grid.values():
        for ii in range(len(members)):
            for jj in range(ii + 1, len(members)):
                a, b = members[ii], members[jj]
                key = (min(a, b), max(a, b))
                if key in seen:
                    continue
                seen.add(key)
                la, loa, hia = boxes[a]
                lb, lob, hib = boxes[b]
                # boxes must touch (within the tolerance) for faces to meet
                if any(loa[k] > hib[k] + PLANE_TOL or lob[k] > hia[k] + PLANE_TOL for k in range(3)):
                    continue
                for ax in range(3):
                    u, v = [k for k in range(3) if k != ax]
                    ou0, ou1 = max(loa[u], lob[u]), min(hia[u], hib[u])
                    ov0, ov1 = max(loa[v], lob[v]), min(hia[v], hib[v])
                    if ou1 - ou0 < MIN_SIDE or ov1 - ov0 < MIN_SIDE:
                        continue
                    for sign, pa, pb in ((-1, loa[ax], lob[ax]), (1, hia[ax], hib[ax])):
                        if abs(pa - pb) >= PLANE_TOL:
                            continue
                        # Same-facing coplanar faces overlapping in (u, v): visible unless buried.
                        hits = 0
                        for i in range(samples):
                            for j in range(samples):
                                q = [0.0, 0.0, 0.0]
                                q[u] = ou0 + (ou1 - ou0) * (i + 0.5) / samples
                                q[v] = ov0 + (ov1 - ov0) * (j + 0.5) / samples
                                q[ax] = (pa + pb) / 2 + sign * BURY_OFF
                                inside = np.all((S[:, 0:3] < np.array(q) - 1e-9) & (S[:, 3:6] > np.array(q) + 1e-9), axis=1)
                                if not inside.any():
                                    hits += 1
                        if hits >= min_hits:
                            fights.append((la, lb, "xyz"[ax], sign, round((pa + pb) / 2, 3), round((ou1 - ou0) * (ov1 - ov0), 2)))
    return fights


def overlap_check(blocks):
    """Greybox blocks may touch but never overlap in volume."""
    bad = []
    for i in range(len(blocks)):
        a = blocks[i]
        for j in range(i + 1, len(blocks)):
            b = blocks[j]
            if a.x0 < b.x1 - 1e-6 and b.x0 < a.x1 - 1e-6 and a.y0 < b.y1 - 1e-6 and b.y0 < a.y1 - 1e-6 and a.z0 < b.z1 - 1e-6 and b.z0 < a.z1 - 1e-6:
                bad.append((a, b))
    return bad


def visible_greybox():
    """The greybox boxes that stay visible after the art pass (labelled), and every solid box (hidden ones
    still hide nothing: they are invisible, so only visible ones count as solids)."""
    out = []
    for b in BLOCKS:
        if b.art == "hide" or b.kind == "glass":
            continue
        out.append((f"Greybox.{b.section}.{b.name}({b.cx:g},{b.cz:g})", b.lo, b.hi))
    return out


# ------------------------------------------------------------------ voxels

NX = int(round((XMAX - XMIN) / R))
NZ = int(round((ZMAX - ZMIN) / R))
NY = int(round((YMAX - YMIN) / R))


def ix(x):
    return int(math.floor((x - XMIN) / R + 1e-6))


def iz(z):
    return int(math.floor((z - ZMIN) / R + 1e-6))


def iy(y):
    return int(math.floor((y - YMIN) / R + 1e-6))


def voxelise():
    solid = np.zeros((NX, NZ, NY), dtype=bool)
    for b in BLOCKS:
        solid[ix(b.x0): ix(b.x1), iz(b.z0): iz(b.z1), iy(b.y0): iy(b.y1)] = True
    for r in RAMPS:
        for k in range(iz(r.z0), iz(r.z1)):
            zc = ZMIN + (k + 0.5) * R
            h = r.height(zc)
            solid[ix(r.x0): ix(r.x1), k, iy(r.y0 - 1): iy(h + 0.25)] = True
    return solid


# ------------------------------------------------------------------ navigation (as metro_layout.py)

STEP = 2
H = int(round(BODY / R))
FLOORS: dict = {}


def erode_xz(free, rad):
    out = free.copy()
    for dx in range(-rad, rad + 1):
        for dz in range(-rad, rad + 1):
            if dx * dx + dz * dz > rad * rad + 1:
                continue
            shifted = np.ones_like(free)
            xs = slice(max(dx, 0), NX + min(dx, 0))
            xd = slice(max(-dx, 0), NX + min(-dx, 0))
            zs = slice(max(dz, 0), NZ + min(dz, 0))
            zd = slice(max(-dz, 0), NZ + min(-dz, 0))
            shifted[xd, zd, :] = free[xs, zs, :]
            out &= shifted
    return out


def air_run(air):
    run = np.zeros(air.shape, dtype=np.int16)
    run[:, :, -1] = air[:, :, -1]
    for k in range(NY - 2, -1, -1):
        run[:, :, k] = np.where(air[:, :, k], run[:, :, k + 1] + 1, 0)
    return run


def build_nodes(solid):
    body = air_run(erode_xz(~solid, 2))
    raw = air_run(~solid)
    lift = 2
    under = np.concatenate([np.zeros((NX, NZ, 1), bool), solid[:, :, :-1]], axis=2)
    upper = np.concatenate([body[:, :, lift:], np.zeros((NX, NZ, lift), np.int16)], axis=2)
    stand = under & (raw >= lift) & (upper >= H - lift)
    nodes = {}
    for a in range(0, NX, STEP):
        for c in range(0, NZ, STEP):
            ks = np.nonzero(stand[a, c])[0]
            if len(ks):
                FLOORS[(a, c)] = [int(k) for k in ks]
            for k in ks:
                nodes[(a, c, int(k))] = len(nodes)
    return nodes, raw


def node_xyz(key):
    a, c, k = key
    return XMIN + (a + 0.5) * R, YMIN + k * R, ZMIN + (c + 0.5) * R


RING1 = [(da, dc) for da in (-STEP, 0, STEP) for dc in (-STEP, 0, STEP) if da or dc]
RING2 = [(da, dc) for da in range(-2 * STEP, 2 * STEP + 1, STEP) for dc in range(-2 * STEP, 2 * STEP + 1, STEP)
         if max(abs(da), abs(dc)) == 2 * STEP]


def neighbours(run, key):
    a, c, k = key
    for ring, (da, dc) in [(1, d) for d in RING1] + [(2, d) for d in RING2]:
        na, nc = a + da, c + dc
        if not (0 <= na < NX and 0 <= nc < NZ):
            continue
        col = run[na, nc]
        for nk in FLOORS.get((na, nc), ()):
            if nk > k + int(JUMP / R):
                continue
            lo, hi = min(k, nk), max(k, nk)
            if ring == 2:
                if hi - lo < 3:
                    continue
                ma, mc = a + da // 2, c + dc // 2
                if run[ma, mc][hi] < H:
                    continue
            if nk < k and col[lo] < (hi - lo) + H:
                continue
            if nk > k and run[a, c][k] < (nk - k) + H:
                continue
            dist = math.hypot(da, dc) * R
            rise = (nk - k) * R
            cost = dist + (4.0 if rise > 1.2 else 0.0)
            yield (na, nc, nk), cost


def dijkstra(run, starts):
    dist = {}
    q = []
    for s in starts:
        dist[s] = 0.0
        q.append((0.0, s))
    heapq.heapify(q)
    while q:
        d, cur = heapq.heappop(q)
        if d > dist.get(cur, math.inf):
            continue
        for nxt, cost in neighbours(run, cur):
            nd = d + cost
            if nd < dist.get(nxt, math.inf):
                dist[nxt] = nd
                heapq.heappush(q, (nd, nxt))
    return dist


def nearest_node(nodes, x, z, y=None):
    best, bd = None, math.inf
    a0, c0 = ix(x), iz(z)
    for key in nodes:
        a, c, k = key
        if abs(a - a0) > 6 or abs(c - c0) > 6:
            continue
        nx, ny, nz = node_xyz(key)
        d = math.hypot(nx - x, nz - z) + (abs(ny - y) if y is not None else 0)
        if d < bd:
            best, bd = key, d
    return best


# ------------------------------------------------------------------ sight

def visible_list(solid, A, Bp, step=0.75, chunk=6000):
    out = np.zeros(len(A), dtype=bool)
    for s in range(0, len(A), chunk):
        p, q = A[s: s + chunk], Bp[s: s + chunk]
        L = np.linalg.norm(q - p, axis=1)
        S = max(2, int(L.max() / step) + 1)
        t = np.linspace(0.0, 1.0, S)[None, :, None]
        pts = p[:, None, :] + (q - p)[:, None, :] * t
        gx = np.clip(((pts[..., 0] - XMIN) / R).astype(np.int32), 0, NX - 1)
        gy = np.clip(((pts[..., 1] - YMIN) / R).astype(np.int32), 0, NY - 1)
        gz = np.clip(((pts[..., 2] - ZMIN) / R).astype(np.int32), 0, NZ - 1)
        out[s: s + chunk] = ~solid[gx, gz, gy].any(axis=1)
    return out


def visible_pairs(solid, A, Bp):
    n, m = len(A), len(Bp)
    if n == 0 or m == 0:
        return np.zeros((n, m), dtype=bool)
    pa = np.repeat(np.arange(n), m)
    pb = np.tile(np.arange(m), n)
    return visible_list(solid, A[pa], Bp[pb]).reshape(n, m)


# ------------------------------------------------------------------ checks

def region(x, y, z):
    """A callout for a point (x, floor y, z)."""
    side = "B" if z > 0 else "A"
    ax, az = abs(x), abs(z)
    if az >= SPAWN_Z0 - 0.5 and ax < SPAWN_X + 0.5:
        return f"{side} spawn"
    if az >= VEST_Z0 - 0.5:
        return f"{side} vestibule"
    if y >= DECK - 1 and az < ATR + 0.5 and ax < ATR + 0.5:
        return "ring"
    if y >= DECK - 1:
        return f"{side} overlook"
    if ax < ATR and az < ATR:
        return "sunwell"
    if ax < GAL and az > ATR:
        return f"{side} gallery"
    if az < 16 and ax > ATR:
        return ("east" if x > 0 else "west") + " pump"
    east = x > 0
    own_east = east if side == "B" else not east  # rotated: A's lockers are on the west
    if ax >= COR_X0:
        return f"{side} {'east' if east else 'west'} corridor"
    return f"{side} {'lockers' if own_east else 'control'}"


def gap_report():
    print("\nGaps under 6 studs between cover and walls on the same floor (0 = touching):")
    # Cover standing on a floor (parapets on the decks are railings at a drop, not cover on a walkway).
    items = [b for b in BLOCKS if b.kind in ("cover", "low") and b.y0 < 1]
    walls = [b for b in BLOCKS if b.kind in ("wall", "cover", "low")]
    shown = set()

    def through_solid(a, b, p, q):
        # The gap runs through another block (a wall between two rooms): not a walking gap.
        y = a.y0 + 1.0
        for t in (0.25, 0.5, 0.75):
            x, z = p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t
            for o in BLOCKS:
                if o is a or o is b or o.kind in ("floor", "roof"):
                    continue
                if o.x0 - 1e-6 <= x <= o.x1 + 1e-6 and o.z0 - 1e-6 <= z <= o.z1 + 1e-6 and o.y0 <= y <= o.y1:
                    return True
        return False

    for a in items:
        for b in walls:
            if a is b:
                continue
            if a.y0 >= b.y1 or b.y0 >= a.y1 or b.y0 > a.y0 + 1.5:
                continue
            gx = max(0.0, max(a.x0, b.x0) - min(a.x1, b.x1))
            gz = max(0.0, max(a.z0, b.z0) - min(a.z1, b.z1))
            g = math.hypot(gx, gz) if gx and gz else max(gx, gz)
            # nearest points of the two footprints
            pa = (min(max(b.cx, a.x0), a.x1), min(max(b.cz, a.z0), a.z1))
            pb = (min(max(pa[0], b.x0), b.x1), min(max(pa[1], b.z0), b.z1))
            if 0 < g < 6 and not through_solid(a, b, pa, pb):
                key = tuple(sorted([(a.name, round(a.cx), round(a.cz)), (b.name, round(b.cx), round(b.cz))]))
                if key in shown:
                    continue
                shown.add(key)
                print(f"  {a.name} ({a.cx:.0f},{a.cz:.0f}) - {b.name} ({b.cx:.0f},{b.cz:.0f}): {g:.1f}")
    if not shown:
        print("  none")
    return len(shown)


def report():
    ok = True
    print(f"Blocks: {len(BLOCKS)} boxes, {len(RAMPS)} ramps")
    bad = overlap_check(BLOCKS)
    print(f"Greybox volume overlaps: {len(bad)}")
    for a, b in bad[:20]:
        print(f"  {a.name} {a.lo}-{a.hi}  x  {b.name} {b.lo}-{b.hi}")
    ok &= not bad
    fights = coplanar_check(visible_greybox())
    print(f"Coplanar check (greybox only, visible parts): {len(fights)} z-fighting pairs")
    for f in fights[:20]:
        print("  ", f)
    ok &= not fights

    solid = voxelise()
    nodes, run = build_nodes(solid)
    print(f"Grid {NX}x{NZ}x{NY} voxels, standing spots: {len(nodes)}")
    gaps = gap_report()

    sa = [nearest_node(nodes, x, z, FLOOR) for x, z in SPAWNS_A]
    sb = [nearest_node(nodes, x, z, FLOOR) for x, z in SPAWNS_B]
    assert all(sa) and all(sb), "a spawn is not on a floor"
    dA = dijkstra(run, sa)
    dB = dijkstra(run, sb)
    keys = list(nodes)
    reach = sum(1 for k in keys if k in dA)
    print(f"\nReachable from spawn A: {100 * reach / len(keys):.1f}% of standing spots")
    leaks = [k for k in dA if not (-42 < node_xyz(k)[0] < 42 and -SPAWN_Z1 < node_xyz(k)[2] < SPAWN_Z1 and node_xyz(k)[1] < HALL)]
    print(f"Sealed (no walkable spot outside the shell or above the ceilings): {not leaks}")
    ok &= not leaks
    unreached = [node_xyz(k) for k in keys if k not in dA]
    if unreached:
        print(f"  unreachable standing spots (e.g. on top of cover): {len(unreached)}, highest y {max(p[1] for p in unreached):.1f}")

    print("\nRoute times from the A spawns (sprint 22 / walk 16 studs/s):")
    routes = {}
    for name, (x, z, y) in WAYPOINTS.items():
        wp = nearest_node(nodes, x, z, y)
        if wp is None or wp not in dA:
            print(f"  {name}: NO ROUTE")
            ok = False
            continue
        total = dA[wp] + dB.get(wp, math.inf)
        routes[name] = (dA[wp], total)
        print(f"  to {name:14s} {dA[wp]:5.0f} studs = {dA[wp] / SPRINT:4.1f} s sprint, {dA[wp] / WALK:4.1f} s walk;"
              f"  spawn-to-spawn through it {total:4.0f} studs")
    target_b = min(sb, key=lambda k: dA.get(k, math.inf))
    direct = dA.get(target_b)
    print(f"  shortest spawn to spawn: {direct:.0f} studs = {direct / SPRINT:.1f} s sprint, {direct / WALK:.1f} s walk"
          f"  (straight line {math.hypot(SPAWNS_A[0][0] - SPAWNS_B[0][0], SPAWNS_A[0][1] - SPAWNS_B[0][1]):.0f})")

    meet_k = min((k for k in keys if k in dA and k in dB), key=lambda k: max(dA[k], dB[k]))
    meet = max(dA[meet_k], dB[meet_k])
    mp = node_xyz(meet_k)
    print(f"Earliest contact (both teams on one spot): {meet / SPRINT:.1f} s sprint, {meet / WALK:.1f} s walk at {region(*mp)}")

    V = [k for k in keys if k[0] % 8 == 0 and k[1] % 8 == 0 and k in dA and k in dB]
    P = np.array([node_xyz(k) for k in V])
    P[:, 1] += EYE
    vA = np.array([dA[k] for k in V])
    vB = np.array([dB[k] for k in V])

    def seen_by(D, cap):
        ia = np.nonzero(vA <= D)[0]
        ib = np.nonzero(vB <= D)[0]
        if len(ia) == 0 or len(ib) == 0:
            return None
        near = np.linalg.norm(P[ia][:, None, :] - P[ib][None, :, :], axis=2) <= cap
        if not near.any():
            return None
        pi, pj = np.nonzero(near)
        vis = visible_list(solid, P[ia[pi]], P[ib[pj]])
        if not vis.any():
            return None
        w = np.nonzero(vis)[0][0]
        return ia[pi[w]], ib[pj[w]]

    first = None
    for cap, label in ((1000.0, "any range"), (70.0, "within 70 studs")):
        lo, hi = 0.0, meet + 40
        found = seen_by(hi, cap)
        while found and hi - lo > 2.0:
            mid = (lo + hi) / 2
            f = seen_by(mid, cap)
            if f:
                hi, found = mid, f
            else:
                lo = mid
        if not found:
            print(f"First sight ({label}): none before contact")
            continue
        a, b = found
        pa, pb = P[a], P[b]
        first = first or (hi, pa, pb)
        print(f"First sight ({label}): {hi / SPRINT:.1f} s sprint, {hi / WALK:.1f} s walk  "
              f"({region(pa[0], pa[1] - EYE, pa[2])} ({pa[0]:.0f},{pa[2]:.0f}) sees "
              f"{region(pb[0], pb[1] - EYE, pb[2])} ({pb[0]:.0f},{pb[2]:.0f}), {np.linalg.norm(pb - pa):.0f} studs)")

    print("\nSpawn safety:")
    eyesA = np.array([[x, FLOOR + EYE, z] for x, z in SPAWNS_A])
    eyesB = np.array([[x, FLOOR + EYE, z] for x, z in SPAWNS_B])
    sees_spawn = bool(visible_pairs(solid, eyesA, eyesB).any())
    print("  any spawn A sees any spawn B:", sees_spawn)
    ok &= not sees_spawn
    half = np.nonzero(P[:, 2] < 0)[0]
    sees = visible_pairs(solid, P[half], eyesB).any(axis=1)
    print(f"  team A's half that can see a B spawn point: {100 * sees.mean():.1f}%")
    outside = np.nonzero(P[:, 2] < VEST_Z0)[0]
    sees = visible_pairs(solid, P[outside], eyesB).any(axis=1)
    print(f"  anywhere south of B's vestibule that sees a B spawn point: {100 * sees.mean():.1f}%")
    for w in outside[np.nonzero(sees)[0]][:6]:
        print(f"    e.g. {region(P[w, 0], P[w, 1] - EYE, P[w, 2])} ({P[w, 0]:.0f},{P[w, 1] - EYE:.0f},{P[w, 2]:.0f})")
    ok &= not sees.any()

    print("\nLong sightlines (eye to eye between standing spots outside the spawn rooms):")
    hv = np.nonzero(np.abs(P[:, 2]) < SPAWN_Z0)[0]
    ii, jj = np.triu_indices(len(hv), 1)
    dd = np.linalg.norm(P[hv[ii]] - P[hv[jj]], axis=1)
    far = dd > 60
    ii, jj, dd = ii[far], jj[far], dd[far]
    vis = visible_list(solid, P[hv[ii]], P[hv[jj]])
    print(f"  pairs over 60 studs apart that see each other: {100 * vis.mean():.1f}%; "
          f"over 80 apart: {100 * vis[dd > 80].mean() if (dd > 80).any() else 0:.1f}%")
    order = np.argsort(-dd * vis)
    longest, shown = [], []
    for o in order:
        if not vis[o]:
            break
        a, b = P[hv[ii[o]]], P[hv[jj[o]]]
        dup = any((np.linalg.norm(a - s0) < 16 and np.linalg.norm(b - s1) < 16) or
                  (np.linalg.norm(a - s1) < 16 and np.linalg.norm(b - s0) < 16) for s0, s1 in shown)
        if dup:
            continue
        shown.append((a, b))
        longest.append((dd[o], (a[0], a[2]), (b[0], b[2])))
        print(f"  {dd[o]:4.0f} studs  {region(a[0], a[1] - EYE, a[2])} ({a[0]:.0f},{a[2]:.0f}) <-> "
              f"{region(b[0], b[1] - EYE, b[2])} ({b[0]:.0f},{b[2]:.0f})")
        if len(longest) == 6:
            break

    print("\nThe ring (catwalk, +12):")
    ring = np.nonzero((P[:, 1] > DECK + 1) & (np.abs(P[:, 0]) < ATR) & (np.abs(P[:, 2]) < ATR))[0]
    floor = np.nonzero((P[:, 1] < DECK - 1) & (np.abs(P[:, 0]) < ATR) & (np.abs(P[:, 2]) < ATR))[0]
    if len(ring) and len(floor):
        seen_floor = visible_pairs(solid, P[ring], P[floor]).any(axis=0)
        print(f"  sunwell floor seen from somewhere on the ring: {100 * seen_floor.mean():.0f}%")
        ring_b = ring[P[ring, 2] > ATR - 7]
        seen_b = visible_pairs(solid, P[ring_b], P[floor]).any(axis=0)
        print(f"  ...from the B side of the ring alone: {100 * seen_b.mean():.0f}% (the far side's underside is hidden)")
        out_ring = np.nonzero(~((np.abs(P[:, 0]) < ATR + 2) & (np.abs(P[:, 2]) < ATR + 2)))[0]
        seen_out = visible_pairs(solid, P[ring], P[out_ring]).any(axis=0)
        print(f"  standing spots outside the sunwell the ring can see: {100 * seen_out.mean():.1f}%")

    print("\nCover spread (ground level, distance to the nearest full cover or wall corner on your floor):")
    full = [b for b in BLOCKS if b.kind in ("cover", "wall") and b.y1 - b.y0 >= 7 and b.y0 <= FLOOR + 0.5]
    worst, worst_at, dists = 0.0, None, []
    for k in keys:
        x, y, z = node_xyz(k)
        if y > 1 or k not in dA or abs(z) >= SPAWN_Z0:
            continue
        d = min(math.hypot(max(0.0, b.x0 - x, x - b.x1), max(0.0, b.z0 - z, z - b.z1)) for b in full)
        dists.append(d)
        if d > worst:
            worst, worst_at = d, (x, z)
    print(f"  average {sum(dists) / len(dists):.1f}, furthest {worst:.1f} at ({worst_at[0]:.0f},{worst_at[1]:.0f}) {region(worst_at[0], 0, worst_at[1])}")

    print("\nHeights: floors 0, ring and overlooks 12, ceilings 12 (rooms) and 26 (sunwell, galleries), skylight 64")
    print(f"Highest reach: deck 12 + jump 7.2 + Updraft 28 = 47.2 (three 14s: 61.2), skylight {SHAFT_TOP:g}")
    return ok, {"first": first, "longest": longest, "meet": meet, "direct": direct, "routes": routes, "gaps": gaps,
                "meet_at": region(*mp)}


# ------------------------------------------------------------------ SVG

FILL = {
    "floor": "#C8CCD6",
    "cover": "#5C6273",
    "low": "#9AA0B2",
    "wall": "#3A3F4C",
    "deck": "#E6D2A8",
    "dais": "#F2C76B",
}


def svg(res) -> str:
    sc = 3.6
    pad = 50
    W = (XMAX - XMIN) * sc + 2 * pad + 330
    Hh = (ZMAX - ZMIN) * sc + 2 * pad
    ox, oz = pad + (-XMIN) * sc, pad + ZMAX * sc

    def p(x, z):
        return ox + x * sc, oz - z * sc

    def rect(x0, x1, z0, z1, fill, stroke="none", sw=0, extra=""):
        a = p(x0, z1)
        return (f'<rect x="{a[0]:.1f}" y="{a[1]:.1f}" width="{(x1 - x0) * sc:.1f}" height="{(z1 - z0) * sc:.1f}" '
                f'fill="{fill}" stroke="{stroke}" stroke-width="{sw}" {extra}/>')

    out = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W:.0f} {Hh:.0f}" font-family="Segoe UI, Arial, sans-serif">',
        '<defs><marker id="up" markerWidth="8" markerHeight="8" refX="4" refY="4" orient="auto">'
        '<path d="M0,0 L8,4 L0,8 z" fill="#2F3545"/></marker>'
        '<radialGradient id="sun"><stop offset="0" stop-color="#FFE7A8" stop-opacity="0.95"/>'
        '<stop offset="1" stop-color="#FFE7A8" stop-opacity="0"/></radialGradient></defs>',
        f'<rect width="{W:.0f}" height="{Hh:.0f}" fill="#1B1E26"/>',
    ]
    # Floors (rooms light, tall halls lighter)
    for b in BLOCKS:
        if b.kind == "floor":
            tall = abs(b.cx) < GAL + 2 and abs(b.cz) < GAL_Z1 + 2 or b.name == "SunwellFloor"
            out.append(rect(b.x0, b.x1, b.z0, b.z1, "#E4E6EC" if tall else "#C3C7D1"))
    # Sunlit patch
    c = p(0, 0)
    out.append(f'<circle cx="{c[0]:.1f}" cy="{c[1]:.1f}" r="{14 * sc:.1f}" fill="url(#sun)"/>')
    out.append(rect(-SHAFT, SHAFT, -SHAFT, SHAFT, "none", "#E0A040", 1.5, 'stroke-dasharray="4 3"'))
    # Decks (ring, overlooks)
    for b in BLOCKS:
        if b.kind == "deck":
            out.append(rect(b.x0, b.x1, b.z0, b.z1, FILL["deck"], "#B89A60", 0.6, 'fill-opacity="0.75"'))
    for b in BLOCKS:
        if b.kind in ("floor", "roof", "deck", "glass") or b.section == "Shaft":
            continue
        if b.kind == "wall" and b.y0 >= DOOR_H - 0.01:
            continue  # lintels, the band over doors, the upper wall
        out.append(rect(b.x0, b.x1, b.z0, b.z1, FILL.get(b.kind, "#555"), "#20232C", 0.6))
    for r in RAMPS:
        out.append(rect(r.x0, r.x1, r.z0, r.z1, "#A9B4CC", "#596070", 1))
        n = int((r.z1 - r.z0) / 1.5)
        for i in range(1, n):
            z = r.z0 + i * (r.z1 - r.z0) / n
            a, b2 = p(r.x0, z), p(r.x1, z)
            out.append(f'<line x1="{a[0]:.1f}" y1="{a[1]:.1f}" x2="{b2[0]:.1f}" y2="{b2[1]:.1f}" stroke="#7D879E" stroke-width="0.8"/>')
        cx = (r.x0 + r.x1) / 2
        za, zb = (r.z0 + 2, r.z1 - 2) if r.up > 0 else (r.z1 - 2, r.z0 + 2)
        a, b2 = p(cx, za), p(cx, zb)
        out.append(f'<line x1="{a[0]:.1f}" y1="{a[1]:.1f}" x2="{b2[0]:.1f}" y2="{b2[1]:.1f}" stroke="#2F3545" stroke-width="2" marker-end="url(#up)"/>')
    # End colours
    for sign, colour, label in ((1, "#3D6FD6", "B · BLUE END"), (-1, "#D9A520", "A · YELLOW END")):
        a, b2 = p(-SPAWN_X - 2, sign * (SPAWN_Z1 + 2)), p(SPAWN_X + 2, sign * (SPAWN_Z1 + 2))
        out.append(f'<line x1="{a[0]:.1f}" y1="{a[1]:.1f}" x2="{b2[0]:.1f}" y2="{b2[1]:.1f}" stroke="{colour}" stroke-width="6"/>')
        t = p(0, sign * (SPAWN_Z1 + 4))
        out.append(f'<text x="{t[0]:.1f}" y="{t[1] + (0 if sign > 0 else 10):.1f}" text-anchor="middle" font-size="13" font-weight="700" fill="{colour}">{label}</text>')
    if res.get("longest"):
        _, a, b2 = res["longest"][0]
        pa, pb = p(*a), p(*b2)
        out.append(f'<line x1="{pa[0]:.1f}" y1="{pa[1]:.1f}" x2="{pb[0]:.1f}" y2="{pb[1]:.1f}" stroke="#D1495B" stroke-width="2" stroke-dasharray="7 5"/>')
    if res.get("first"):
        _, fa, fb = res["first"]
        pa, pb = p(fa[0], fa[2]), p(fb[0], fb[2])
        out.append(f'<line x1="{pa[0]:.1f}" y1="{pa[1]:.1f}" x2="{pb[0]:.1f}" y2="{pb[1]:.1f}" stroke="#3DDC84" stroke-width="2" stroke-dasharray="3 3"/>')
    for spawns, colour in ((SPAWNS_B, "#3D6FD6"), (SPAWNS_A, "#D9A520")):
        for x, z in spawns:
            cc = p(x, z)
            out.append(f'<circle cx="{cc[0]:.1f}" cy="{cc[1]:.1f}" r="5" fill="{colour}"/>')
    labels = {
        (0, -10): ("Sunwell", "#8A5A10"),
        (0, 17): ("Ring (+12)", "#6B5226"),
        (0, 26): ("B Overlook (+12)", "#6B5226"),
        (0, -26): ("A Overlook (+12)", "#6B5226"),
        (-5, 46): ("B Gallery", "#2A2F3C"),
        (5, -46): ("A Gallery", "#2A2F3C"),
        (22, 44): ("B Lockers", "#2A2F3C"),
        (-22, -44): ("A Lockers", "#2A2F3C"),
        (-22, 44): ("B Control", "#2A2F3C"),
        (22, -44): ("A Control", "#2A2F3C"),
        (31, 10): ("East Pump", "#2A2F3C"),
        (-31, -10): ("West Pump", "#2A2F3C"),
        (36, 36): ("East corridor", "#2A2F3C"),
        (-36, -36): ("West corridor", "#2A2F3C"),
        (-36, 36): ("West corridor", "#2A2F3C"),
        (36, -36): ("East corridor", "#2A2F3C"),
        (0, 60): ("B Vestibule", "#2A2F3C"),
        (0, -60): ("A Vestibule", "#2A2F3C"),
        (0, 76): ("B Spawn", "#2A2F3C"),
        (0, -76): ("A Spawn", "#2A2F3C"),
        (-8, 49): ("blast door", "#6B7080"),
        (8, -49): ("blast door", "#6B7080"),
    }
    for (x, z), (text, colour) in labels.items():
        t = p(x, z)
        rot = f' transform="rotate(-90 {t[0]:.1f} {t[1]:.1f})"' if "corridor" in text else ""
        out.append(f'<text x="{t[0]:.1f}" y="{t[1] + 4:.1f}" text-anchor="middle" font-size="11" font-weight="600" fill="{colour}"{rot}>{text}</text>')

    kx = pad + (XMAX - XMIN) * sc + 30
    y = pad + 10
    out.append(f'<text x="{kx:.0f}" y="{y}" font-size="26" font-weight="700" fill="#F4F5F9">Bunker2</text>')
    y += 22
    out.append(f'<text x="{kx:.0f}" y="{y}" font-size="13" fill="#B9BDCB">Layout, 180° rotation · 1v1-3v3</text>')
    y += 34
    rows = [
        ("#E4E6EC", "Sunwell + galleries (ceiling 26)"),
        ("#C3C7D1", "Rooms + corridors (ceiling 12)"),
        (FILL["deck"], "Ring catwalk + overlooks, +12"),
        ("#A9B4CC", "Stairs (arrow = up)"),
        (FILL["cover"], "Full cover (7-8)"),
        (FILL["low"], "Half cover (3)"),
        (FILL["wall"], "Walls (door gaps 8-10 wide)"),
    ]
    for colour, text in rows:
        out.append(f'<rect x="{kx:.0f}" y="{y}" width="18" height="18" fill="{colour}" stroke="#596070"/>')
        out.append(f'<text x="{kx + 28:.0f}" y="{y + 14}" font-size="13" fill="#F4F5F9">{text}</text>')
        y += 26
    out.append(f'<rect x="{kx:.0f}" y="{y}" width="18" height="18" fill="none" stroke="#E0A040" stroke-width="1.5" stroke-dasharray="4 3"/>')
    out.append(f'<text x="{kx + 28:.0f}" y="{y + 14}" font-size="13" fill="#F4F5F9">Light shaft to the skylight (+64)</text>')
    y += 26
    if res.get("longest"):
        out.append(f'<line x1="{kx:.0f}" y1="{y + 9}" x2="{kx + 18:.0f}" y2="{y + 9}" stroke="#D1495B" stroke-width="2" stroke-dasharray="7 5"/>')
        out.append(f'<text x="{kx + 28:.0f}" y="{y + 14}" font-size="13" fill="#F4F5F9">Longest eye-level line, {res["longest"][0][0]:.0f}</text>')
        y += 26
    if res.get("first"):
        D = res["first"][0]
        out.append(f'<line x1="{kx:.0f}" y1="{y + 9}" x2="{kx + 18:.0f}" y2="{y + 9}" stroke="#3DDC84" stroke-width="2" stroke-dasharray="3 3"/>')
        out.append(f'<text x="{kx + 28:.0f}" y="{y + 14}" font-size="13" fill="#F4F5F9">First sight, {D / WALK:.1f} s walk</text>')
        y += 40
        facts = [
            f"Spawn to spawn: {res['direct']:.0f} studs walked",
            f"  {res['direct'] / SPRINT:.1f} s sprint, {res['direct'] / WALK:.1f} s walk",
            f"First sight: {D / SPRINT:.1f} s sprint, {D / WALK:.1f} s walk",
            f"First contact: {res['meet'] / SPRINT:.1f} s sprint, {res['meet'] / WALK:.1f} s walk",
            f"Map 84 × {2 * (SPAWN_Z1 + 2):.0f}, sunwell 40 × 40 × 26",
        ]
        for f in facts:
            out.append(f'<text x="{kx:.0f}" y="{y}" font-size="13" fill="#B9BDCB">{f}</text>')
            y += 20
    y += 14
    bar = 16 * sc
    out.append(f'<rect x="{kx:.0f}" y="{y}" width="{bar:.0f}" height="5" fill="#F4F5F9"/>')
    out.append(f'<text x="{kx:.0f}" y="{y + 22}" font-size="12" fill="#B9BDCB">16 studs</text>')
    out.append("</svg>")
    return "\n".join(out)


# ------------------------------------------------------------------ greybox Luau

COLOURS = {
    "floor": "B9BCC4",
    "wall": "8E929C",
    "roof": "6E727C",
    "deck": "C9B48C",
    "low": "A3A9B8",
    "cover": "6B7286",
    "glass": "A9C9CF",
    "dais": "D9A13A",
    "ramp": "AEB5C6",
}


def num(v):
    return f"{v:g}"


def luau() -> str:
    lines = [
        "--!strict",
        "-- Bunker2 greybox: GENERATED by tools/maps/bunker2_layout.py --luau. Edit the layout there (the checks run",
        "-- on the same numbers), then regenerate and re-run this in the match place:",
        "--   python tools/studio/maps/bundle.py Bunker2 Greybox -o bunker2_greybox.luau",
        "-- Map space (MapKit.luau): origin on the sunwell floor at the map centre, +Z = team B's (blue) end.",
        "-- Every part here is collision; Art.luau hides the ones the kit replaces and finishes the rest.",
        "-- No two boxes overlap (they butt), so the greybox itself has no coplanar faces (bunker2_layout.py checks it).",
        "",
        f'newMap("Bunker2", CFrame.new({ORIGIN[0]}, {ORIGIN[1]}, {ORIGIN[2]}))',
        "",
        "local KIND: { [string]: Color3 } = {",
    ]
    for k, c in COLOURS.items():
        lines.append(f'\t{k} = Color3.fromHex("{c}"),')
    lines += [
        "}",
        "local MATERIAL: { [string]: Enum.Material } = {",
        "\tfloor = Enum.Material.Concrete,",
        "\twall = Enum.Material.Concrete,",
        "\troof = Enum.Material.Concrete,",
        "\tdeck = Enum.Material.Concrete,",
        "\tlow = Enum.Material.SmoothPlastic,",
        "\tcover = Enum.Material.SmoothPlastic,",
        "\tglass = Enum.Material.Glass,",
        "\tdais = Enum.Material.SmoothPlastic,",
        "\tramp = Enum.Material.Concrete,",
        "}",
        "",
        "-- { section, name, kind, x0, x1, y0, y1, z0, z1, art } boxes, both halves written out.",
        "local BOXES: { { any } } = {",
    ]
    for b in BLOCKS:
        lines.append(
            f'\t{{ "{b.section}", "{b.name}", "{b.kind}", {num(b.x0)}, {num(b.x1)}, {num(b.y0)}, {num(b.y1)}, {num(b.z0)}, {num(b.z1)}, "{b.art}" }},'
        )
    lines += ["}", "", "-- { section, name, x0, x1, y0, y1, z0, z1, up } ramps; up = +1 rises toward +Z.", "local RAMPS: { { any } } = {"]
    for r in RAMPS:
        lines.append(
            f'\t{{ "{r.section}", "{r.name}", {num(r.x0)}, {num(r.x1)}, {num(r.y0)}, {num(r.y1)}, {num(r.z0)}, {num(r.z1)}, {r.up} }},'
        )
    lines += ["}", "", "local SPAWNS: { { any } } = {"]
    for team, pts in (("A", SPAWNS_A), ("B", SPAWNS_B)):
        for i, (x, z) in enumerate(pts, 1):
            lines.append(f'\t{{ "{team}", {i}, {num(x)}, {num(z)} }},')
    lines += ["}", "", "local BARRIERS: { { number } } = {"]
    for b in BARRIERS_B + [b.rotated() for b in BARRIERS_B]:
        lines.append(f"\t{{ {num(b.x0)}, {num(b.x1)}, {num(b.y0)}, {num(b.y1)}, {num(b.z0)}, {num(b.z1)} }},")
    lines += [
        "}",
        "",
        "local sections: { [string]: Folder } = {}",
        "local function sec(name: string): Folder",
        "\tlocal f = sections[name]",
        "\tif not f then",
        '\t\tf = section("Greybox", name)',
        "\t\tsections[name] = f",
        "\tend",
        "\treturn f :: Folder",
        "end",
        "",
        "local count = 0",
        "for _, s in BOXES do",
        "\tlocal kind = s[3] :: string",
        "\tlocal x0, x1, y0, y1, z0, z1 = s[4] :: number, s[5] :: number, s[6] :: number, s[7] :: number, s[8] :: number, s[9] :: number",
        "\tlocal size = Vector3.new(x1 - x0, y1 - y0, z1 - z0)",
        "\tlocal small = math.min(size.X, size.Z) < 4 or size.Y < 4",
        "\tlocal p = box(sec(s[1] :: string), s[2] :: string, size, at((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), KIND[kind], {",
        "\t\tmaterial = MATERIAL[kind],",
        '\t\ttransparency = if kind == "glass" then 0.85 else 0,',
        '\t\tcastShadow = kind == "roof" or kind == "wall" or not small, -- roofs and walls keep the inside dark',
        "\t})",
        '\tp:SetAttribute("Kind", kind)',
        '\tp:SetAttribute("Art", s[10] :: string)',
        "\tcount += 1",
        "end",
        "",
        "-- WedgePart: low at local -Z, high at +Z, so a ramp rising toward -Z turns 180 degrees.",
        "for _, s in RAMPS do",
        "\tlocal x0, x1, y0, y1, z0, z1 = s[3] :: number, s[4] :: number, s[5] :: number, s[6] :: number, s[7] :: number, s[8] :: number",
        "\tlocal up = s[9] :: number",
        "\tlocal size = Vector3.new(x1 - x0, y1 - y0, z1 - z0)",
        "\tlocal p = wedge(sec(s[1] :: string), s[2] :: string, size, at((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2, if up > 0 then 0 else 180), KIND.ramp, {",
        "\t\tmaterial = MATERIAL.ramp,",
        "\t})",
        '\tp:SetAttribute("Kind", "ramp")',
        '\tp:SetAttribute("Art", "hide")',
        "\tcount += 1",
        "end",
        "",
        "spawnsClear()",
        "for _, s in SPAWNS do",
        "\tspawnPad(s[1] :: string, s[2] :: number, at(s[3] :: number, " + num(FLOOR) + ', s[4] :: number, if s[1] == "A" then 180 else 0))',
        "end",
        "for i, b in BARRIERS do",
        '\tbarrier("Barrier" .. i, Vector3.new(b[2] - b[1], b[4] - b[3], b[6] - b[5]), at((b[1] + b[2]) / 2, (b[3] + b[4]) / 2, (b[5] + b[6]) / 2))',
        "end",
        "",
        'report(string.format("Bunker2 greybox: %d parts, %d spawns, %d barriers", count, #SPAWNS, #BARRIERS))',
        "",
    ]
    return "\n".join(lines)


def main():
    ok, res = report()
    art_ok = True
    try:
        import bunker2_art  # noqa: WPS433 (needs the kit export; skipped before step 4)
    except ImportError:
        bunker2_art = None
    if bunker2_art is not None and bunker2_art.EXPORT.exists():
        art_ok = bunker2_art.check()
    SVG_OUT.parent.mkdir(parents=True, exist_ok=True)
    SVG_OUT.write_text(svg(res), encoding="utf-8")
    print(f"\nWrote {SVG_OUT}")
    if "--luau" in sys.argv:
        LUAU_OUT.parent.mkdir(parents=True, exist_ok=True)
        LUAU_OUT.write_text(luau(), encoding="utf-8")
        print(f"Wrote {LUAU_OUT}")
        if bunker2_art is not None:
            bunker2_art.write_luau()
    print("\nALL CHECKS PASS" if ok and art_ok else "\nCHECKS FAILED")
    return 0 if ok and art_ok else 1


if __name__ == "__main__":
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    sys.exit(main())
