#!/usr/bin/env python3
"""Greenhouse map layout: the plan as data, its checks, its SVG and the greybox it builds.

Run:  python tools/maps/greenhouse_layout.py            checks + SVG
      python tools/maps/greenhouse_layout.py --write    ...and rewrites tools/studio/maps/Greenhouse/Greybox.luau
                                                        and Art.luau (through greenhouse_art.py), then stylua them

The map is a list of solids in map space: studs, origin on the floor at the centre of the Dome, +X across (east),
+Z along (team B's end, the blue end), +Y up. Team A spawns at -Z. Only the centre and team B's set are listed: team
A's set is the same list turned 180 degrees about Y, so the map is fair by construction. ("Team B's set" is B's
half plus the whole east Wing; its turn is A's half plus the west Wing.)

Every solid is collision. `look` is the finish Art.luau gives a part that stays visible (a Roblox material and
colour); `look=None` means the Blender kit replaces it and Art.luau hides it (it keeps its collision).

The checks are 2.5D, like tools/maps/metro_layout.py: the solids are rasterised into a 0.5-stud voxel grid, players
are 5.5-stud columns that walk, step, jump (up to 7) and drop between floors, and every sight test is a 3D line
between eye points (floor + 5). It prints gaps, sightlines, spawn safety, route times, the time to first sight and to
first contact, how high Updraft can take you (and whether that leaves the map), and a coplanar check of every visible
Part's box faces (z-fighting; greenhouse_art.py extends it to every kit MeshPart). Writes
vault/02 Art/References/maps/greenhouse/greenhouse-layout.svg. Needs numpy.
"""

from __future__ import annotations

import heapq
import math
import subprocess
import sys
from dataclasses import dataclass, field, replace
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
SVG_OUT = ROOT / "vault/02 Art/References/maps/greenhouse/greenhouse-layout.svg"
LUAU_OUT = ROOT / "tools/studio/maps/Greenhouse/Greybox.luau"

# ------------------------------------------------------------------ numbers

EYE = 5.0  # eye above the floor
BODY = 5.5  # standing height
JUMP = 7.0  # highest ledge you can jump onto (Config/Movement JUMP_HEIGHT 7.2)
JUMP_REACH = 7.2
UPDRAFT = 28.0  # two 14-stud Updrafts or one strong one (the Whitebox / Old Town convention)
SPRINT = 22.0  # Config/Movement SPRINT_SPEED
WALK = 16.0  # Config/Movement WALK_SPEED
R = 0.5  # voxel size
XMIN, XMAX = -78.0, 78.0
ZMIN, ZMAX = -122.0, 122.0
YMIN, YMAX = -2.0, 82.0

HALL = 40.0  # every glass hall, the Dome base and the Orangery: the shell height
DOOR_H = 10.0  # every door is 8 wide and 10 tall
GAL = 12.0  # gallery and bridge deck top
SHED_CEIL = 14.0
ORANGERY_CEIL = 20.0
SPAWN_CEIL = 14.0
OUT = 74.0  # inner face of the perimeter
DOME = 40.0  # the Dome's inner half width (walls 40..42)
BED = 3.0  # raised beds, tubs, cold frames: half cover
FULL = 9.0  # rockeries, hedges, shelf racks, boilers, the Wardian case: full cover

# Dome roof profile (inner surface): (inradius of the octagon, height). Drum on the walls, then a faceted
# cloister dome in three rings, a flat lantern deck, the lantern and its cap. Blender builds the visual dome from
# these same numbers (art-source/maps/Greenhouse/plan.json), so glass and collision coincide.
DOME_PROFILE = [(40.0, 40.0), (40.0, 46.0), (35.0, 56.0), (26.0, 64.0), (14.0, 70.0), (7.0, 70.0), (7.0, 76.0), (0.6, 80.0)]

ACCENT = {"A": "#E0A82E", "B": "#3A6FC4"}  # yellow end (A, -Z) and blue end (B, +Z)


# ------------------------------------------------------------------ solids

@dataclass
class Solid:
    """A collision part. shape: box (axis-aligned or oriented), ramp (a WedgePart rising toward `up`), cyl.

    c: centre; s: size in the part's own axes (box: X, Y, Z; ramp: across, rise, along the climb; cyl: d, h, d).
    axes: None for an axis-aligned part, else (ux, uy, uz) unit vectors (an oriented box, the Dome's roof facets).
    """

    name: str
    section: str
    kind: str
    shape: str
    c: tuple
    s: tuple
    look: str | None = None
    up: str = ""
    axes: tuple | None = None
    tags: tuple = ()

    @property
    def x0(self):
        return self.c[0] - self.ext()[0] / 2

    @property
    def x1(self):
        return self.c[0] + self.ext()[0] / 2

    @property
    def y0(self):
        return self.c[1] - self.ext()[1] / 2

    @property
    def y1(self):
        return self.c[1] + self.ext()[1] / 2

    @property
    def z0(self):
        return self.c[2] - self.ext()[2] / 2

    @property
    def z1(self):
        return self.c[2] + self.ext()[2] / 2

    def ext(self):
        """World extents along X, Y, Z (exact for axis-aligned parts and ramps)."""
        if self.axes is not None:
            M = np.array(self.axes).T  # columns = axes
            h = np.abs(M) @ np.array(self.s) / 2
            return tuple(2 * h)
        if self.shape == "ramp" and self.up in ("+x", "-x"):
            return (self.s[2], self.s[1], self.s[0])
        return self.s

    def rotated(self) -> "Solid":
        c = (-self.c[0], self.c[1], -self.c[2])
        up = {"+x": "-x", "-x": "+x", "+z": "-z", "-z": "+z", "": ""}[self.up]
        axes = None
        if self.axes is not None:
            axes = tuple((-a[0], a[1], -a[2]) for a in self.axes)
        return replace(self, c=c, up=up, axes=axes)


def B(name, sec, x0, x1, y0, y1, z0, z1, kind, look=None, tags=()):
    assert x1 > x0 and y1 > y0 and z1 > z0, name
    return Solid(name, sec, kind, "box", ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), (x1 - x0, y1 - y0, z1 - z0), look, tags=tags)


def RAMP(name, sec, x0, x1, y0, y1, z0, z1, up, look=None):
    """A ramp whose top rises from y0 to y1 toward `up` (+x, -x, +z, -z)."""
    if up in ("+x", "-x"):
        s = (z1 - z0, y1 - y0, x1 - x0)
    else:
        s = (x1 - x0, y1 - y0, z1 - z0)
    return Solid(name, sec, "ramp", "ramp", ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), s, look, up=up)


def CYL(name, sec, cx, cz, d, y0, y1, kind, look=None):
    return Solid(name, sec, kind, "cyl", (cx, (y0 + y1) / 2, cz), (d, y1 - y0, d), look)


def OBB(name, sec, c, s, axes, kind, look=None):
    return Solid(name, sec, kind, "box", tuple(c), tuple(s), look, axes=tuple(tuple(a) for a in axes))


def wall_x(name, sec, x0, x1, z, y1, doors=(), look=None, y0=0.0, head=DOOR_H, thick=2.0):
    """A wall along X from x0 to x1, `thick` thick centred on z, with door openings (a, b) along X. Solid runs go
    floor to y1; over each door a lintel from `head` to y1."""
    out, cur = [], x0
    for a, b in sorted(doors):
        if a > cur:
            out.append(B(name, sec, cur, a, y0, y1, z - thick / 2, z + thick / 2, "wall", look))
        if y1 > head:
            out.append(B(name + "Lintel", sec, a, b, head, y1, z - thick / 2, z + thick / 2, "wall", look))
        cur = b
    if x1 > cur:
        out.append(B(name, sec, cur, x1, y0, y1, z - thick / 2, z + thick / 2, "wall", look))
    return out


def wall_z(name, sec, z0, z1, x, y1, doors=(), look=None, y0=0.0, head=DOOR_H, thick=2.0):
    out, cur = [], z0
    for a, b in sorted(doors):
        if a > cur:
            out.append(B(name, sec, x - thick / 2, x + thick / 2, y0, y1, cur, a, "wall", look))
        if y1 > head:
            out.append(B(name + "Lintel", sec, x - thick / 2, x + thick / 2, head, y1, a, b, "wall", look))
        cur = b
    if z1 > cur:
        out.append(B(name, sec, x - thick / 2, x + thick / 2, y0, y1, cur, z1, "wall", look))
    return out


# Wall runs with their art style, for greenhouse_art.py: (style, axis, a0, a1, at, y1, doors, faces). `faces` is
# which sides of the wall the art dresses: "both", or for single-faced runs the side that faces the play space.
WALL_RUNS: list = []


def run_x(style, name, sec, x0, x1, z, y1, doors=(), look=None, **kw):
    WALL_RUNS.append(dict(style=style, axis="x", a0=x0, a1=x1, at=z, y1=y1, doors=tuple(doors), name=name))
    return wall_x(name, sec, x0, x1, z, y1, doors, look, **kw)


def run_z(style, name, sec, z0, z1, x, y1, doors=(), look=None, **kw):
    WALL_RUNS.append(dict(style=style, axis="z", a0=z0, a1=z1, at=x, y1=y1, doors=tuple(doors), name=name))
    return wall_z(name, sec, z0, z1, x, y1, doors, look, **kw)


# ------------------------------------------------------------------ the plan

def octagon_facets(name, sec, profile, thick=1.0, kind="roof"):
    """Oriented plates for each ring of an octagonal cloister roof: inner faces on the profile."""
    out = []
    tan = math.tan(math.radians(22.5))
    for (ra, ya), (rb, yb) in zip(profile, profile[1:]):
        dr, dy = rb - ra, yb - ya
        slant = math.hypot(dr, dy)
        for k in range(8):
            phi = math.radians(45 * k)
            d = np.array([math.cos(phi), 0.0, math.sin(phi)])
            t = np.array([-math.sin(phi), 0.0, math.cos(phi)])
            n = dy * d + np.array([0.0, -dr, 0.0])  # outward (or up) normal in the d-Y plane
            n = n / np.linalg.norm(n)
            s_dir = (dr * d + np.array([0.0, dy, 0.0])) / slant
            mid = (ra + rb) / 2 * d + np.array([0.0, (ya + yb) / 2, 0.0])
            c = mid + n * thick / 2
            length = 2 * (max(ra, rb) + thick) * tan + 0.6
            ux, uy = t, n
            uz = np.cross(ux, uy)
            # Keep the "along" axis (uz) parallel to the slant (it is, up to sign).
            assert abs(abs(float(np.dot(uz, s_dir))) - 1) < 1e-6
            out.append(OBB(name, sec, c, (length, thick, slant + 0.2), (ux, uy, uz), kind))
    return out


def plan():
    ctr: list = []  # self-symmetric (listed once)
    hb: list = []  # team B's set (turned 180 degrees for team A)

    # ---------------- floors (the paving Art.luau finishes)
    ctr.append(B("DomeFloor", "Dome", -41, 41, -1, 0, -41, 41, "floor", "dome_floor"))
    hb += [
        B("WingFloor", "Wing", 41, OUT + 1, -1, 0, -41, 41, "floor", "paving"),
        B("FernFloor", "Fern", -25, 25, -1, 0, 41, 83, "floor", "paving"),
        B("OrangeryFloor", "Orangery", -41, 41, -1, 0, 83, 101, "floor", "flags"),
        B("LodgeFloor", "Lodge", -27, 27, -1, 0, 101, 119, "floor", "boards"),
        B("TerraceFloor", "Terrace", -OUT - 1, -25, -1, 0, 41, 83, "floor", "gravel"),
        B("LawnFloor", "Terrace", -OUT - 1, -41, -1, 0, 83, 101, "floor", "gravel"),
        B("ShedFloor", "Sheds", 41, OUT + 1, -1, 0, 41, 101, "floor", "shed_floor"),  # seams away from walls
        B("ShedFloorW", "Sheds", 25, 41, -1, 0, 41, 83, "floor", "shed_floor"),
    ]

    # ---------------- the Dome (80 x 80 inside, walls 40 tall, dome above)
    hb += run_x("glass", "DomeWallN", "Dome", -42, 42, 41, HALL, doors=[(2, 10)])
    hb += run_z("glass", "DomeWallE", "Dome", -40, 40, 41, HALL, doors=[(-12, -4), (20, 28)])
    # Roof: the four flat corners at 40 outside the octagon, the drum on the walls and the dome's rings.
    for k in range(4):
        phi = math.radians(45 + 90 * k)
        d = np.array([math.cos(phi), 0.0, math.sin(phi)])
        t = np.array([-math.sin(phi), 0.0, math.cos(phi)])
        ctr.append(OBB("RoofCorner", "DomeRoof", d * (DOME + 9) + np.array([0, HALL + 0.5, 0]), (36.0, 1.0, 18.0), (t, (0, 1, 0), np.cross(t, (0, 1, 0))), "roof"))
    ctr += octagon_facets("DomeRoof", "DomeRoof", DOME_PROFILE)
    # Fountain: an octagonal basin (rim 3, half cover you can stand on), a pedestal (full cover) and its bowl.
    for k in range(8):
        phi = math.radians(45 * k)
        d = np.array([math.cos(phi), 0.0, math.sin(phi)])
        t = np.array([-math.sin(phi), 0.0, math.cos(phi)])
        ctr.append(OBB("FountainRim", "Fountain", d * 11.5 + np.array([0, 1.5, 0]), (10.4, 3.0, 1.0), (t, (0, 1, 0), np.cross(t, (0, 1, 0))), "low"))
    # The fountain's tiers, each a cylinder matching the Blender piece: base, shaft, bowl, upper shaft, top basin.
    for nm, d, y0, y1 in (("FountainBase", 8, 0, 1.2), ("FountainShaft", 6, 1.2, 5), ("FountainBowl", 14, 5, 6), ("FountainUpper", 5, 6, 9.6), ("FountainTop", 6.4, 9.6, 10.2)):
        ctr.append(CYL(nm, "Fountain", 0, 0, d, y0, y1, "cover"))
    # Bridge over the fountain, gallery to gallery, open iron railings (top rail only stops you walking off).
    ctr.append(B("Bridge", "Gallery", -28, 28, GAL - 1, GAL, -4, 4, "deck"))
    ctr.append(B("BridgeRail", "Gallery", -28, 28, GAL + 3.2, GAL + 3.5, 3.7, 4, "rail"))
    ctr.append(B("BridgeRail", "Gallery", -28, 28, GAL + 3.2, GAL + 3.5, -4, -3.7, "rail"))
    for x in (-20, 20):
        ctr.append(CYL("BridgeColumn", "Gallery", x, 0, 1.4, 0, GAL - 1, "column"))
    # East gallery: deck along the east wall, a cast-iron balustrade (half cover) on its edge, columns under it.
    hb.append(B("GalleryDeck", "Gallery", 28, DOME, GAL - 1, GAL, -DOME, DOME, "deck"))
    hb.append(B("Balustrade", "Gallery", 28, 28.5, GAL, GAL + 3, -32, -4, "low"))
    hb.append(B("Balustrade", "Gallery", 28, 28.5, GAL, GAL + 3, 4, DOME, "low"))
    for z in (-24, -12, 12, 24):
        hb.append(B("GalleryColumn", "Gallery", 28.25, 29.75, 0, GAL - 1, z - 0.75, z + 0.75, "column"))
    # Team B's stair: along the Dome's north wall, up toward the west gallery (A's is its turn, to the east one).
    hb.append(RAMP("GalleryStair", "Gallery", -28, -10, 0, GAL, 32, DOME, "-x"))
    # Two statues on plinths (full cover) in team B's half of the Dome; A's are their turn.
    hb.append(B("Statue", "Dome", -4, 0, 0, FULL, 30, 34, "cover"))
    # Palm planters (rockwork, full cover) with a palm trunk each; the crown is far above the gallery.
    for bx in (19, -19):
        hb.append(B("PalmPlanter", "Dome", bx - 3, bx + 3, 0, FULL, 15, 24, "cover"))
        hb.append(CYL("PalmTrunk", "Dome", bx, 20, 1.6, FULL, 30, "trunk"))

    # ---------------- east Wing (32 x 80, B's set holds all of it; the west Wing is its turn)
    hb += run_x("glass", "WingWallN", "Wing", 42, OUT, 41, HALL, doors=[(46, 54), (62, 70)])
    hb += run_x("glass", "WingWallS", "Wing", 42, OUT, -41, HALL, doors=[(50, 58)])
    hb += run_z("glass", "PerimeterWing", "Shell", -42, 42, OUT + 1, HALL)
    hb.append(B("WingRoof", "Wing", 42, OUT, HALL, HALL + 1, -40, 40, "roof"))
    for nm, x0, x1, z0, z1 in (("LilyRimN", 54, 68, 6, 7), ("LilyRimS", 54, 68, -7, -6), ("LilyRimW", 54, 55, -6, 6), ("LilyRimE", 67, 68, -6, 6)):
        hb.append(B(nm, "Wing", x0, x1, 0, 1.2, z0, z1, "kerb"))
    hb += [
        B("WingBed", "Wing", OUT - 6, OUT, 0, BED, 14, 32, "low"),
        B("WingBed", "Wing", OUT - 6, OUT, 0, BED, -26, -14, "low"),
        B("WingBed", "Wing", 42, 48, 0, BED, 4, 16, "low"),
        Solid("LilyUrn", "Wing", "cover", "cyl", (61.0, FULL / 2, 0.0), (4.0, FULL, 4.0)),
        B("WingRockery", "Wing", 42, 54, 0, FULL + 1, 28, 34, "cover"),
        B("WingRockery", "Wing", 48, 60, 0, FULL + 1, -34, -28, "cover"),
    ]

    # ---------------- Fern House (B): 48 x 40 glass hall between the Dome and the Orangery
    hb += run_z("glass", "FernWallW", "Fern", 42, 82, -25, HALL, doors=[(66, 74)])
    hb += run_z("glass", "FernWallE", "Fern", 42, 82, 25, HALL, doors=[(50, 58)])
    hb.append(B("FernRoof", "Fern", -24, 24, HALL, HALL + 1, 42, 82, "roof"))
    hb += [
        B("Fernery", "Fern", -4, 4, 0, FULL, 54, 70, "cover"),
        B("FernBedW", "Fern", -24, -18, 0, BED, 42, 56, "low"),
        B("FernBedE", "Fern", 18, 24, 0, BED, 62, 82, "low"),
        B("FernBed", "Fern", -16, -10, 0, BED, 70, 76, "low"),
        B("FernBed", "Fern", 10, 16, 0, BED, 48, 54, "low"),
    ]
    for z in (58, 66):
        hb.append(CYL("TreeFernTrunk", "Fern", 0, z, 1.2, FULL, 16, "trunk"))

    # ---------------- Orangery (B): the cross hall in front of the Lodge
    hb += run_x("stucco", "OrangeryWallS", "Orangery", -42, 42, 83, HALL, doors=[(-36, -28), (-12, -4), (28, 36)])
    hb += run_z("stucco", "OrangeryWallW", "Orangery", 84, 100, -41, HALL, doors=[(84, 92)])
    hb += run_z("stucco", "OrangeryWallE", "Orangery", 84, 100, 41, HALL, doors=[(92, 100)])
    hb += run_x("stucco", "OrangeryWallN", "Orangery", -42, 42, 101, HALL, doors=[(-26, -18), (18, 26)])
    hb.append(B("OrangeryCeiling", "Orangery", -40, 40, ORANGERY_CEIL, ORANGERY_CEIL + 1, 84, 100, "ceiling", "plaster_ceiling"))
    hb.append(B("WardianCase", "Orangery", -4, 4, 0, FULL, 90, 94, "cover"))
    for cx in (-22, 22):  # statues on long plinths: they screen the Lodge vestibules from the Fern House door
        hb.append(B("StatuePlinth", "Orangery", cx - 4, cx + 4, 0, FULL, 90, 94, "cover"))
    for cx, cz in ((-38, 98), (38, 86)):
        hb.append(B("CitrusTub", "Orangery", cx - 2, cx + 2, 0, BED, cz - 2, cz + 2, "low"))

    # ---------------- Lodge (B spawn) and its vestibules
    hb += wall_x("LodgeFront", "Lodge", -18, 18, 103, SPAWN_CEIL, look="lodge_wall")
    hb += wall_z("LodgeSide", "Lodge", 104, 118, -17, SPAWN_CEIL, doors=[(106, 114)], look="lodge_wall")
    hb += wall_z("LodgeSide", "Lodge", 104, 118, 17, SPAWN_CEIL, doors=[(106, 114)], look="lodge_wall")
    hb += wall_z("VestibuleWall", "Lodge", 102, 118, -27, SPAWN_CEIL, look="lodge_wall")
    hb += wall_z("VestibuleWall", "Lodge", 102, 118, 27, SPAWN_CEIL, look="lodge_wall")
    hb += wall_x("LodgeBack", "Lodge", -28, 28, 119, SPAWN_CEIL, look="lodge_wall")
    hb.append(B("LodgeCeiling", "Lodge", -26, 26, SPAWN_CEIL, SPAWN_CEIL + 1, 102, 118, "ceiling", "lodge_ceiling"))

    # ---------------- Terrace (B, west): an open walled garden, glass walls 40 tall all round
    hb += run_z("glass", "PerimeterTerrace", "Shell", 42, 102, -OUT - 1, HALL)
    hb += run_x("glass", "LawnWallN", "Terrace", -OUT, -42, 101, HALL)
    for nm, x0, x1, z0, z1 in (("PondRimS", -64, -50, 52, 53), ("PondRimN", -64, -50, 63, 64), ("PondRimW", -64, -63, 53, 63), ("PondRimE", -51, -50, 53, 63)):
        hb.append(B(nm, "Terrace", x0, x1, 0, 1.2, z0, z1, "kerb"))
    hb += [
        B("Hedge", "Terrace", -44, -36, 0, FULL, 48, 52, "cover"),
        B("Hedge", "Terrace", -68, -60, 0, FULL, 70, 74, "cover"),
        B("Hedge", "Terrace", -42, -34, 0, FULL, 72, 76, "cover"),
        B("ColdFrame", "Terrace", -50, -42, 0, BED, 62, 65, "low"),
        B("ColdFrame", "Terrace", -OUT, -66, 0, BED, 97, 100, "low"),
    ]
    hb.append(CYL("Urn", "Terrace", -50, 77, 4, 0, FULL, "cover"))
    hb.append(CYL("Urn", "Terrace", -56, 92, 4, 0, FULL, "cover"))

    # ---------------- Sheds (B, east): a brick range with a ceiling at 14
    brick = "brick"
    hb += run_z("brick", "ShedPerimeter", "Shell", 42, 102, OUT + 1, SHED_CEIL + 1, look=brick)
    hb += run_x("brick", "ShedWallN", "Sheds", 42, OUT, 101, SHED_CEIL + 1, look=brick)
    hb += run_z("brick", "CorridorWall", "Sheds", 42, 100, 59, SHED_CEIL, doors=[(44, 52), (88, 96)], look=brick)
    hb += run_x("brick", "SeedWall", "Sheds", 26, 58, 63, SHED_CEIL, doors=[(28, 36), (48, 56)], look=brick)
    hb += run_x("brick", "SeedWallN", "Sheds", 42, 58, 83, SHED_CEIL, doors=[(44, 52)], look=brick)
    hb.append(B("ShedCeiling", "Sheds", 26, OUT, SHED_CEIL, SHED_CEIL + 1, 42, 82, "ceiling", "shed_ceiling"))
    hb.append(B("ShedCeiling", "Sheds", 42, OUT, SHED_CEIL, SHED_CEIL + 1, 82, 100, "ceiling", "shed_ceiling"))
    hb += [
        B("Boiler", "Sheds", 66, OUT, 0, 10, 56, 64, "cover"),
        B("Boiler", "Sheds", 60, 68, 0, 10, 74, 82, "cover"),
        B("PottingBench", "Sheds", 32, 38, 0, BED, 52, 55, "low"),
        B("PottingBench", "Sheds", 44, 50, 0, BED, 48, 51, "low"),
        B("ShelfRack", "Sheds", 34, 36, 0, FULL, 70, 76, "cover"),
        B("ShelfRack", "Sheds", 48, 50, 0, FULL, 70, 76, "cover"),
        B("CrateStack", "Sheds", 48, 52, 0, FULL, 90, 94, "cover"),
    ]
    return ctr, hb


CENTER, HALF = plan()
BLOCKS: list = CENTER + HALF + [s.rotated() for s in HALF]

SPAWNS_B = [(-6.0, 108.0), (6.0, 108.0), (-6.0, 114.0), (6.0, 114.0)]
SPAWNS_A = [(-x, -z) for x, z in SPAWNS_B]
# 0.1 inside each wall face, so the barrier never shares a plane with the door frame.
BARRIERS_B = [B("Barrier", "Barriers", -17.9, -16.1, 0, DOOR_H, 106, 114, "barrier"), B("Barrier", "Barriers", 16.1, 17.9, 0, DOOR_H, 106, 114, "barrier")]

# Places, for routes and labels (team B's set; A's are turned).
WAYPOINTS = {
    "fern house": (0.0, 48.0, 0.0),
    "dome centre": (0.0, -16.0, 0.0),
    "gallery": (-34.0, 10.0, GAL),
    "east wing": (66.0, 0.0, 0.0),
    "terrace": (-44.0, 58.0, 0.0),
    "sheds corridor": (66.0, 70.0, 0.0),
}


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
        if b.kind == "barrier":
            continue
        if b.shape == "cyl":
            r = b.s[0] / 2
            a0, a1, c0, c1 = ix(b.c[0] - r), ix(b.c[0] + r), iz(b.c[2] - r), iz(b.c[2] + r)
            xs = XMIN + (np.arange(a0, a1 + 1) + 0.5) * R
            zs = ZMIN + (np.arange(c0, c1 + 1) + 0.5) * R
            inside = (xs[:, None] - b.c[0]) ** 2 + (zs[None, :] - b.c[2]) ** 2 <= r * r
            for i, j in zip(*np.nonzero(inside)):
                solid[a0 + i, c0 + j, iy(b.y0) : iy(b.y1)] = True
        elif b.shape == "ramp":
            if b.up in ("+z", "-z"):
                for k in range(iz(b.z0), iz(b.z1)):
                    t = (ZMIN + (k + 0.5) * R - b.z0) / (b.z1 - b.z0)
                    h = b.y0 + (b.y1 - b.y0) * (t if b.up == "+z" else 1 - t)
                    solid[ix(b.x0) : ix(b.x1), k, iy(b.y0 - 1) : iy(h + 0.25)] = True
            else:
                for a in range(ix(b.x0), ix(b.x1)):
                    t = (XMIN + (a + 0.5) * R - b.x0) / (b.x1 - b.x0)
                    h = b.y0 + (b.y1 - b.y0) * (t if b.up == "+x" else 1 - t)
                    solid[a, iz(b.z0) : iz(b.z1), iy(b.y0 - 1) : iy(h + 0.25)] = True
        elif b.axes is None:
            solid[ix(b.x0) : ix(b.x1), iz(b.z0) : iz(b.z1), iy(b.y0) : iy(b.y1)] = True
        else:
            a0, a1 = max(ix(b.x0), 0), min(ix(b.x1) + 1, NX)
            c0, c1 = max(iz(b.z0), 0), min(iz(b.z1) + 1, NZ)
            k0, k1 = max(iy(b.y0), 0), min(iy(b.y1) + 1, NY)
            if a0 >= a1 or c0 >= c1 or k0 >= k1:
                continue
            X, Z, Y = np.meshgrid(XMIN + (np.arange(a0, a1) + 0.5) * R, ZMIN + (np.arange(c0, c1) + 0.5) * R, YMIN + (np.arange(k0, k1) + 0.5) * R, indexing="ij")
            P = np.stack([X - b.c[0], Y - b.c[1], Z - b.c[2]], axis=-1)
            inside = np.ones(X.shape, dtype=bool)
            for ax, sz in zip(b.axes, b.s):
                inside &= np.abs(P @ np.array(ax)) <= sz / 2 + 0.26
            solid[a0:a1, c0:c1, k0:k1] |= inside
    return solid


# ------------------------------------------------------------------ navigation (Metro's, unchanged in spirit)

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
RING2 = [(da, dc) for da in range(-2 * STEP, 2 * STEP + 1, STEP) for dc in range(-2 * STEP, 2 * STEP + 1, STEP) if max(abs(da), abs(dc)) == 2 * STEP]


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
            yield (na, nc, nk), dist + (4.0 if rise > 1.2 else 0.0)


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
        if abs(a - a0) > 8 or abs(c - c0) > 8:
            continue
        nx, ny, nz = node_xyz(key)
        d = math.hypot(nx - x, nz - z) + (abs(ny - y) * 3 if y is not None else 0)
        if d < bd:
            best, bd = key, d
    return best


# ------------------------------------------------------------------ sight

def visible_list(solid, A, Bp, step=0.75, chunk=6000):
    out = np.zeros(len(A), dtype=bool)
    for s in range(0, len(A), chunk):
        p, q = A[s : s + chunk], Bp[s : s + chunk]
        L = np.linalg.norm(q - p, axis=1)
        S = max(2, int(L.max() / step) + 1)
        t = np.linspace(0.0, 1.0, S)[None, :, None]
        pts = p[:, None, :] + (q - p)[:, None, :] * t
        gx = np.clip(((pts[..., 0] - XMIN) / R).astype(np.int32), 0, NX - 1)
        gy = np.clip(((pts[..., 1] - YMIN) / R).astype(np.int32), 0, NY - 1)
        gz = np.clip(((pts[..., 2] - ZMIN) / R).astype(np.int32), 0, NZ - 1)
        out[s : s + chunk] = ~solid[gx, gz, gy].any(axis=1)
    return out


def visible_pairs(solid, A, Bp):
    n, m = len(A), len(Bp)
    if n == 0 or m == 0:
        return np.zeros((n, m), dtype=bool)
    pa = np.repeat(np.arange(n), m)
    pb = np.tile(np.arange(m), n)
    return visible_list(solid, A[pa], Bp[pb]).reshape(n, m)


# ------------------------------------------------------------------ coplanar check (the Studio audit's rules)

def coplanar_boxes(boxes, label="parts"):
    """boxes: list of (name, (x0,y0,z0), (x1,y1,z1), solid_block) axis-aligned boxes in map space, every VISIBLE
    part. Mirrors tools/studio/maps/Audit.luau: for every pair of parallel faces within 0.02 of one plane whose
    rectangles overlap by 0.05+ both ways, 5 x 5 sample points; at each, a 1-stud ray from 0.5 off the plane (either
    side) must hit both boxes at the same distance (a ray that starts inside a box never hits it); a hit whose point is
    buried in another visible solid block doesn't count; 3+ hits = a z-fighting pair. Returns the failing pairs."""
    PLANE_TOL, HIT_TOL, SAMPLES, MIN_HITS = 0.02, 0.006, 5, 3
    lo = np.array([b[1] for b in boxes], dtype=float)
    hi = np.array([b[2] for b in boxes], dtype=float)
    solid_idx = [i for i, b in enumerate(boxes) if b[3]]
    # Spatial hash on 8-stud cells.
    cell = 8.0
    grid: dict = {}
    for i in range(len(boxes)):
        a = np.floor(lo[i] / cell).astype(int)
        b = np.floor(hi[i] / cell).astype(int)
        for gx in range(a[0], b[0] + 1):
            for gy in range(a[1], b[1] + 1):
                for gz in range(a[2], b[2] + 1):
                    grid.setdefault((gx, gy, gz), []).append(i)
    sgrid: dict = {}
    for i in solid_idx:
        a = np.floor(lo[i] / cell).astype(int)
        b = np.floor(hi[i] / cell).astype(int)
        for gx in range(a[0], b[0] + 1):
            for gy in range(a[1], b[1] + 1):
                for gz in range(a[2], b[2] + 1):
                    sgrid.setdefault((gx, gy, gz), []).append(i)

    def inside(i, p):
        return all(lo[i][k] < p[k] < hi[i][k] for k in range(3))

    def buried(p, a, b):
        key = tuple(np.floor(np.array(p) / cell).astype(int))
        for o in sgrid.get(key, ()):
            if o != a and o != b and inside(o, p):
                return True
        return False

    def hit(i, o, d):
        # Ray from o along d (unit axis vector * sign), length 1: distance to box i, None if it starts inside or misses.
        if inside(i, o):
            return None
        tmin, tmax = 0.0, 1.0
        for k in range(3):
            if abs(d[k]) < 1e-9:
                if not (lo[i][k] <= o[k] <= hi[i][k]):
                    return None
            else:
                t1 = (lo[i][k] - o[k]) / d[k]
                t2 = (hi[i][k] - o[k]) / d[k]
                t1, t2 = min(t1, t2), max(t1, t2)
                tmin, tmax = max(tmin, t1), min(tmax, t2)
                if tmin > tmax:
                    return None
        return tmin

    seen = set()
    found = []
    for key, members in grid.items():
        for ii in range(len(members)):
            for jj in range(ii + 1, len(members)):
                a, b = members[ii], members[jj]
                pair = (min(a, b), max(a, b))
                if pair in seen:
                    continue
                seen.add(pair)
                if np.any(lo[a] > hi[b] + 0.1) or np.any(lo[b] > hi[a] + 0.1):
                    continue
                best = 0
                where = None
                for ax in range(3):
                    u, v = [k for k in range(3) if k != ax]
                    for pa in (lo[a][ax], hi[a][ax]):
                        for pb in (lo[b][ax], hi[b][ax]):
                            if abs(pa - pb) > PLANE_TOL:
                                continue
                            u0, u1 = max(lo[a][u], lo[b][u]), min(hi[a][u], hi[b][u])
                            v0, v1 = max(lo[a][v], lo[b][v]), min(hi[a][v], hi[b][v])
                            if u1 - u0 < 0.05 or v1 - v0 < 0.05:
                                continue
                            hits = 0
                            for i in range(SAMPLES):
                                for j in range(SAMPLES):
                                    p = [0.0, 0.0, 0.0]
                                    p[ax] = pa
                                    p[u] = u0 + (u1 - u0) * (i + 0.5) / SAMPLES
                                    p[v] = v0 + (v1 - v0) * (j + 0.5) / SAMPLES
                                    for side in (1, -1):
                                        o = list(p)
                                        o[ax] += side * 0.5
                                        d = [0.0, 0.0, 0.0]
                                        d[ax] = -side
                                        da, db = hit(a, o, d), hit(b, o, d)
                                        if da is not None and db is not None and abs(da - db) < HIT_TOL:
                                            q = list(o)
                                            q[ax] += d[ax] * (da - 0.05)
                                            if not buried(q, a, b):
                                                hits += 1
                                            break
                            if hits > best:
                                best, where = hits, (ax, pa, (u0 + u1) / 2, (v0 + v1) / 2)
                if best >= MIN_HITS:
                    found.append((boxes[a][0], boxes[b][0], where, best))
    return found


def visible_part_boxes():
    """Every Part Art.luau leaves visible (axis-aligned, by construction), as coplanar_boxes input."""
    out = []
    for b in BLOCKS:
        if b.look is None or b.kind == "barrier":
            continue
        assert b.axes is None and b.shape == "box", "visible parts are axis-aligned boxes: " + b.name
        out.append(("G:" + b.name, (b.x0, b.y0, b.z0), (b.x1, b.y1, b.z1), True))
    return out


# ------------------------------------------------------------------ checks

def region(x, y, z):
    side = "B" if z > 0 else "A"
    other = "A" if z > 0 else "B"
    ax, az = abs(x), abs(z)
    if az <= DOME and ax <= DOME:
        if y > GAL - 1:
            return "gallery" if ax >= 28 else "bridge"
        return "dome"
    if az <= 42 and ax > 41:
        return ("east" if x > 0 else "west") + " wing"
    if az > 101:
        return f"{side} lodge"
    if az > 83 and ax < 41:
        return f"{side} orangery"
    if ax < 25:
        return f"{side} fern house"
    # B's terrace is west (x < 0) in B's half; turned, A's terrace is east in A's half.
    terrace = (x < 0) == (z > 0)
    return f"{side} terrace" if terrace else f"{side} sheds"


def gap_report():
    print("\nGaps under 6 studs between cover and anything on the same floor (0 = touching):")
    items = [b for b in BLOCKS if b.kind in ("cover", "low", "column", "kerb") and b.axes is None and b.y0 < 1]
    walls = [b for b in BLOCKS if b.kind in ("wall", "cover", "low", "column", "ramp", "kerb") and b.axes is None and b.y0 < 1]
    shown = set()
    for a in items:
        for b in walls:
            if a is b:
                continue
            gx = max(0.0, max(a.x0, b.x0) - min(a.x1, b.x1))
            gz = max(0.0, max(a.z0, b.z0) - min(a.z1, b.z1))
            g = math.hypot(gx, gz) if gx and gz else max(gx, gz)
            if 0 < g < 6:
                key = tuple(sorted([(a.name, round(a.c[0]), round(a.c[2])), (b.name, round(b.c[0]), round(b.c[2]))]))
                if key in shown:
                    continue
                shown.add(key)
                print(f"  {a.name} ({a.c[0]:.0f},{a.c[2]:.0f}) - {b.name} ({b.c[0]:.0f},{b.c[2]:.0f}): {g:.1f}")
    if not shown:
        print("  none")


def report():
    solid = voxelise()
    print(f"Solids: {len(BLOCKS)} ({sum(1 for b in BLOCKS if b.look is None)} replaced by the kit); grid {NX}x{NZ}x{NY} voxels")
    nodes, run = build_nodes(solid)
    print(f"Standing spots: {len(nodes)}")

    gap_report()

    sa = [nearest_node(nodes, x, z, 0.0) for x, z in SPAWNS_A]
    sb = [nearest_node(nodes, x, z, 0.0) for x, z in SPAWNS_B]
    assert all(sa) and all(sb), "a spawn is not on a floor"
    dA = dijkstra(run, sa)
    dB = dijkstra(run, sb)
    keys = list(nodes)
    reach = sum(1 for k in keys if k in dA)
    print(f"\nReachable from spawn A: {100 * reach / len(keys):.1f}% of standing spots")
    stray = [node_xyz(k) for k in keys if k not in dA and node_xyz(k)[1] < 1]
    if stray:
        by = {}
        for x, y, z in stray:
            by.setdefault(region(x, y, z), []).append((x, z))
        print(f"  unreachable floor spots: {len(stray)}: " + ", ".join(f"{r} {len(v)} (e.g. {v[0][0]:.0f},{v[0][1]:.0f})" for r, v in by.items()))
    leaks = [k for k in dA if not (-OUT < node_xyz(k)[0] < OUT and -119 < node_xyz(k)[2] < 119 and node_xyz(k)[1] < HALL)]
    print(f"Sealed (no walkable spot outside the shell or on a roof): {not leaks}")

    print("\nRoute times from the A spawns (sprint 22 / walk 16 studs/s):")
    routes = {}
    target_b = min(sb, key=lambda k: dA.get(k, math.inf))
    for name, (x, z, y) in WAYPOINTS.items():
        wp = nearest_node(nodes, -x, -z, y)
        if wp is None or wp not in dA:
            print(f"  via {name}: NO ROUTE")
            continue
        total = dA[wp] + dB.get(wp, math.inf)
        routes[name] = (dA[wp], total)
        print(f"  to {name:15s} {dA[wp] / SPRINT:4.1f} s   spawn-to-spawn through it {total:5.0f} studs = {total / SPRINT:4.1f} s sprint, {total / WALK:4.1f} s walk")
    direct = dA.get(target_b)
    print(f"  shortest spawn to spawn: {direct:.0f} studs = {direct / SPRINT:.1f} s sprint, {direct / WALK:.1f} s walk "
          f"(straight line {math.dist(SPAWNS_A[0], SPAWNS_B[3]):.0f})")
    meet = min(max(dA[k], dB[k]) for k in keys if k in dA and k in dB)
    print(f"Earliest contact (both teams on one spot): {meet / SPRINT:.1f} s sprint, {meet / WALK:.1f} s walk")

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
        lo, hi = 0.0, meet + 60
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
    eyesA = np.array([[x, EYE, z] for x, z in SPAWNS_A])
    eyesB = np.array([[x, EYE, z] for x, z in SPAWNS_B])
    print("  any spawn A sees any spawn B:", bool(visible_pairs(solid, eyesA, eyesB).any()))
    half = np.nonzero(P[:, 2] < 0)[0]
    sees = visible_pairs(solid, P[half], eyesB).any(axis=1)
    print(f"  team A's half that can see a B spawn point: {100 * sees.mean():.1f}%")
    outside = np.nonzero(P[:, 2] < 101)[0]
    sees = visible_pairs(solid, P[outside], eyesB).any(axis=1)
    print(f"  anywhere outside the B lodge that sees a B spawn point: {100 * sees.mean():.2f}%")

    print("\nLong sightlines (eye to eye between standing spots):")
    hv = np.arange(len(P))
    ii, jj = np.triu_indices(len(hv), 1)
    dd = np.linalg.norm(P[hv[ii]] - P[hv[jj]], axis=1)
    far = dd > 70
    ii, jj, dd = ii[far], jj[far], dd[far]
    vis = visible_list(solid, P[hv[ii]], P[hv[jj]])
    print(f"  pairs over 70 studs apart that see each other: {100 * vis.mean():.1f}%; over 100 apart: {100 * vis[dd > 100].mean():.2f}%")
    order = np.argsort(-dd * vis)
    longest, shown = [], []
    for o in order:
        if not vis[o]:
            break
        a, b = P[hv[ii[o]]], P[hv[jj[o]]]
        if any((np.linalg.norm(a - s0) < 16 and np.linalg.norm(b - s1) < 16) or (np.linalg.norm(a - s1) < 16 and np.linalg.norm(b - s0) < 16) for s0, s1 in shown):
            continue
        shown.append((a, b))
        longest.append((dd[o], (a[0], a[2]), (b[0], b[2])))
        print(f"  {dd[o]:4.0f} studs  {region(a[0], a[1] - EYE, a[2])} ({a[0]:.0f},{a[1] - EYE:.0f},{a[2]:.0f}) <-> "
              f"{region(b[0], b[1] - EYE, b[2])} ({b[0]:.0f},{b[1] - EYE:.0f},{b[2]:.0f})")
        if len(longest) == 8:
            break

    print("\nGallery (team B's west gallery, standing at its balustrade):")
    gal = np.nonzero((P[:, 1] > GAL + 1) & (P[:, 0] < -27) & (P[:, 0] > -33) & (np.abs(P[:, 2]) < DOME))[0]
    floor = np.nonzero((np.abs(P[:, 2]) < DOME) & (np.abs(P[:, 0]) < DOME) & (P[:, 1] < GAL - 2))[0]
    vis = visible_pairs(solid, P[gal], P[floor])
    seen_floor = vis.any(axis=0)
    print(f"  Dome floor seen from the west gallery: {100 * seen_floor.mean():.0f}%")
    other = np.nonzero((P[:, 1] > GAL + 1) & (P[:, 0] > 27) & (np.abs(P[:, 2]) < DOME))[0]
    print("  west gallery sees east gallery:", bool(visible_pairs(solid, P[gal], P[other]).any()))
    outside_dome = np.nonzero((np.abs(P[:, 2]) > DOME + 2) | (np.abs(P[:, 0]) > DOME + 2))[0]
    vis2 = visible_pairs(solid, P[gal], P[outside_dome]).any(axis=0)
    print(f"  spots outside the Dome it sees: {100 * vis2.mean():.1f}%")

    print("\nCover spread (ground floor, distance to the nearest full cover or wall on your floor):")
    full = [b for b in BLOCKS if b.kind in ("cover", "wall") and b.axes is None and b.y0 < 1 and b.y1 - b.y0 >= 7 and b.shape == "box"]
    full += [b for b in BLOCKS if b.shape == "cyl" and b.kind == "cover"]
    worst, worst_at, dists, by_zone = 0.0, None, [], {}
    for k in keys:
        x, y, z = node_xyz(k)
        if y > 1 or k not in dA:
            continue
        d = min(math.hypot(max(0.0, b.x0 - x, x - b.x1), max(0.0, b.z0 - z, z - b.z1)) for b in full)
        dists.append(d)
        by_zone.setdefault(region(x, y, z).replace("A ", "").replace("B ", ""), []).append(d)
        if d > worst:
            worst, worst_at = d, (x, z)
    print(f"  average {sum(dists) / len(dists):.1f}, furthest {worst:.1f} at ({worst_at[0]:.0f},{worst_at[1]:.0f})")
    for zname, ds in sorted(by_zone.items()):
        print(f"    {zname:12s} average {sum(ds) / len(ds):4.1f}, worst {max(ds):4.1f}")

    print("\nUpdraft (highest floor you stand on + 7.2 jump + 28): ")
    open_sky = []
    worst_ceiling = 0.0
    for k in keys:
        if k not in dA:
            continue
        a, c, kk = k
        x, y, z = node_xyz(k)
        apex = y + JUMP_REACH + UPDRAFT + BODY
        above = np.nonzero(solid[a, c, kk + H :])[0]
        if len(above):
            ceil = YMIN + (kk + H + above[0]) * R
            worst_ceiling = max(worst_ceiling, ceil - y)
        else:
            open_sky.append((x, y, z, apex))
    print(f"  spots with open sky above: {len(open_sky)} (the Terraces)")
    if open_sky:
        top = max(o[3] for o in open_sky)
        # The lowest wall top around the open-sky area: any solid column within 3 studs of an open-sky spot whose top
        # is below the apex would be a ledge to land on.
        risky = []
        heights = solid.any(axis=2)
        topk = np.where(heights, NY - 1 - np.argmax(solid[:, :, ::-1], axis=2), -1)
        dirs = [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)]
        for x, y, z, apex in open_sky[::2]:
            feet = apex - BODY
            for dx, dz in dirs:
                for step in range(1, 9):
                    a0, c0 = ix(x + dx * step * R), iz(z + dz * step * R)
                    ytop = YMIN + (topk[a0, c0] + 1) * R
                    if ytop > y + 1.5:
                        if ytop <= feet and ytop > 12:
                            risky.append((x, z, ytop))
                        break
        print(f"  highest Updraft apex from an open-sky spot: {top - BODY:.1f} (feet), walls round the Terrace are {HALL:.0f}")
        print(f"  open-sky spots with a ledge over 12 in reach: {len(risky)}" + (f" e.g. {risky[0]}" if risky else ""))

    print(f"\nHeights: floor 0, gallery and bridge {GAL:.0f}, Sheds and Lodge ceilings {SHED_CEIL:.0f}, Orangery {ORANGERY_CEIL:.0f}, halls {HALL:.0f}, Dome lantern {DOME_PROFILE[-1][1]:.0f}")

    print("\nCoplanar check (visible greybox Parts):")
    bad = coplanar_boxes(visible_part_boxes())
    print(f"  {len(bad)} z-fighting pairs" + ("" if not bad else ": " + "; ".join(f"{a} + {b}" for a, b, _, _ in bad[:12])))

    return {"first": first, "longest": longest, "meet": meet, "direct": direct, "routes": routes, "coplanar": len(bad)}


# ------------------------------------------------------------------ SVG

FILL = {
    "cover": "#4E6B4A",
    "low": "#9DB58C",
    "kerb": "#8FB4C0",
    "wall": "#39414A",
    "column": "#E8ECEA",
    "trunk": "#7A6450",
}
FLOOR_FILL = {
    "dome_floor": "#E4E6DE",
    "paving": "#D8DAD0",
    "flags": "#E6DECB",
    "boards": "#C9B79A",
    "gravel": "#CFC4A4",
    "shed_floor": "#B7A493",
}


def svg(res) -> str:
    sc = 3.0
    pad = 46
    W = (XMAX - XMIN) * sc + 2 * pad + 330
    Hh = (ZMAX - ZMIN) * sc + 2 * pad
    ox, oz = pad + (-XMIN) * sc, pad + ZMAX * sc

    def p(x, z):
        return ox + x * sc, oz - z * sc

    def rect(x0, x1, z0, z1, fill, stroke="none", sw=0, extra=""):
        a = p(x0, z1)
        return (f'<rect x="{a[0]:.1f}" y="{a[1]:.1f}" width="{(x1 - x0) * sc:.1f}" height="{(z1 - z0) * sc:.1f}" '
                f'fill="{fill}" stroke="{stroke}" stroke-width="{sw}" {extra}/>')

    def poly(pts, fill, stroke="none", sw=0):
        s = " ".join(f"{p(x, z)[0]:.1f},{p(x, z)[1]:.1f}" for x, z in pts)
        return f'<polygon points="{s}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>'

    out = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W:.0f} {Hh:.0f}" font-family="Segoe UI, Arial, sans-serif">',
        '<defs><marker id="up" markerWidth="8" markerHeight="8" refX="4" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="#2F3545"/></marker></defs>',
        f'<rect width="{W:.0f}" height="{Hh:.0f}" fill="#1C2420"/>',
    ]
    for b in BLOCKS:
        if b.kind == "floor":
            out.append(rect(b.x0, b.x1, b.z0, b.z1, FLOOR_FILL.get(b.look, "#ccc")))
    # Glass halls get a faint mint tint, the dome an octagon outline.
    for b in BLOCKS:
        if b.kind == "roof" and b.axes is None:
            out.append(rect(b.x0, b.x1, b.z0, b.z1, "#BFE3D6", extra='fill-opacity="0.35"'))
    tan = math.tan(math.radians(22.5))
    octo = []
    for k in range(8):
        a0 = math.radians(45 * k - 22.5)
        rr = DOME / math.cos(math.radians(22.5))
        octo.append((rr * math.cos(a0), rr * math.sin(a0)))
    out.append(poly(octo, "#BFE3D6", "#7FB8A6", 1.2).replace("/>", ' fill-opacity="0.35" stroke-dasharray="5 4"/>'))
    # Lawn panels and the pond water.
    out.append(rect(-64, -50, 52, 64, "#8FC6D0"))
    out.append(rect(50, 66, -8, 8, "#8FC6D0"))
    out.append(rect(-66, -50, -8, 8, "#8FC6D0"))
    out.append(rect(50, 64, -64, -52, "#8FC6D0"))
    # Gallery decks (overhead).
    for b in BLOCKS:
        if b.kind == "deck":
            out.append(rect(b.x0, b.x1, b.z0, b.z1, "#F2E6B8", "#C9A24B", 1.0, 'fill-opacity="0.55"'))
    for b in BLOCKS:
        if b.kind in ("floor", "ceiling", "roof", "deck", "rail", "barrier") or b.axes is not None and b.kind != "low":
            continue
        if b.kind == "wall" and b.y0 >= DOOR_H - 0.01:
            continue  # lintels over doors
        if b.shape == "cyl":
            c = p(b.c[0], b.c[2])
            out.append(f'<circle cx="{c[0]:.1f}" cy="{c[1]:.1f}" r="{b.s[0] / 2 * sc:.1f}" fill="{FILL.get(b.kind, "#555")}" stroke="#20262A" stroke-width="0.6"/>')
            continue
        if b.shape == "ramp":
            out.append(rect(b.x0, b.x1, b.z0, b.z1, "#C9D2C4", "#596070", 1))
            if b.up in ("+x", "-x"):
                n = int((b.x1 - b.x0) / 1.5)
                for i in range(1, n):
                    x = b.x0 + i * (b.x1 - b.x0) / n
                    a, c = p(x, b.z0), p(x, b.z1)
                    out.append(f'<line x1="{a[0]:.1f}" y1="{a[1]:.1f}" x2="{c[0]:.1f}" y2="{c[1]:.1f}" stroke="#7D879E" stroke-width="0.7"/>')
                cz = (b.z0 + b.z1) / 2
                xa, xb = (b.x0 + 2, b.x1 - 2) if b.up == "+x" else (b.x1 - 2, b.x0 + 2)
                a, c = p(xa, cz), p(xb, cz)
            else:
                cx = (b.x0 + b.x1) / 2
                za, zb = (b.z0 + 2, b.z1 - 2) if b.up == "+z" else (b.z1 - 2, b.z0 + 2)
                a, c = p(cx, za), p(cx, zb)
            out.append(f'<line x1="{a[0]:.1f}" y1="{a[1]:.1f}" x2="{c[0]:.1f}" y2="{c[1]:.1f}" stroke="#2F3545" stroke-width="2" marker-end="url(#up)"/>')
            continue
        if b.axes is not None:  # fountain rim plates
            ux, _, uz = b.axes
            hx, hz = b.s[0] / 2, b.s[2] / 2
            pts = []
            for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                pts.append((b.c[0] + ux[0] * hx * sx + uz[0] * hz * sz, b.c[2] + ux[2] * hx * sx + uz[2] * hz * sz))
            out.append(poly(pts, FILL["low"], "#20262A", 0.5))
            continue
        out.append(rect(b.x0, b.x1, b.z0, b.z1, FILL.get(b.kind, "#555"), "#20262A", 0.5))
    # Sightlines
    if res["longest"]:
        _, a, b = res["longest"][0]
        pa, pb = p(*a), p(*b)
        out.append(f'<line x1="{pa[0]:.1f}" y1="{pa[1]:.1f}" x2="{pb[0]:.1f}" y2="{pb[1]:.1f}" stroke="#D1495B" stroke-width="2" stroke-dasharray="7 5"/>')
    if res["first"]:
        _, fa, fb = res["first"]
        pa, pb = p(fa[0], fa[2]), p(fb[0], fb[2])
        out.append(f'<line x1="{pa[0]:.1f}" y1="{pa[1]:.1f}" x2="{pb[0]:.1f}" y2="{pb[1]:.1f}" stroke="#3DDC84" stroke-width="2" stroke-dasharray="3 3"/>')
    for spawns, colour in ((SPAWNS_B, ACCENT["B"]), (SPAWNS_A, ACCENT["A"])):
        for x, z in spawns:
            c = p(x, z)
            out.append(f'<circle cx="{c[0]:.1f}" cy="{c[1]:.1f}" r="5" fill="{colour}" stroke="#fff" stroke-width="1"/>')
    for sign, colour, label in ((1, ACCENT["B"], "B · BLUE END"), (-1, ACCENT["A"], "A · YELLOW END")):
        a, b = p(-28, sign * 120.5), p(28, sign * 120.5)
        out.append(f'<line x1="{a[0]:.1f}" y1="{a[1]:.1f}" x2="{b[0]:.1f}" y2="{b[1]:.1f}" stroke="{colour}" stroke-width="5"/>')
    labels = [
        (0, 108, "B Lodge"), (0, 92, "Orangery"), (0, 76, "Fern House"), (-50, 70, "B Terrace"), (-58, 96, "Lawn"),
        (43, 52, "Potting Room"), (43, 74, "Seed Store"), (68, 90, "Corridor"), (51, 97, "Yard"),
        (58, 34, "East Wing"), (-58, -34, "West Wing"), (0, 30, "THE DOME"), (0, -13, "Fountain"), (-34, 0, "Gallery"),
        (34, 0, "Gallery"), (0, 5, "Bridge"), (-19, 36, "Stair"),
    ]
    for x, z, text in labels:
        for s in (1, -1) if text not in ("East Wing", "West Wing", "THE DOME", "Fountain", "Gallery", "Bridge") else (1,):
            t = p(x * s, z * s)
            name = text.replace("B ", "A ") if s < 0 else text
            out.append(f'<text x="{t[0]:.1f}" y="{t[1] + 4:.1f}" text-anchor="middle" font-size="11" font-weight="700" fill="#1E2A24" stroke="#F4F6F0" stroke-width="2.6" paint-order="stroke">{name}</text>')

    kx = pad + (XMAX - XMIN) * sc + 30
    y = pad + 10
    out.append(f'<text x="{kx:.0f}" y="{y}" font-size="26" font-weight="700" fill="#F4F5F0">Greenhouse</text>')
    y += 22
    out.append(f'<text x="{kx:.0f}" y="{y}" font-size="13" fill="#B9C4BC">Layout, 180° rotation · 2v2-4v4</text>')
    y += 32
    rows = [
        (FLOOR_FILL["paving"], "Glass halls (floor 0, glass to 40)"),
        (FLOOR_FILL["gravel"], "Terrace, open sky"),
        (FLOOR_FILL["shed_floor"], "Sheds, brick, ceiling 14"),
        (FLOOR_FILL["flags"], "Orangery, ceiling 20"),
        ("#F2E6B8", "Gallery and bridge, +12"),
        ("#C9D2C4", "Stair (arrow = up)"),
        (FILL["cover"], "Full cover (8+)"),
        (FILL["low"], "Half cover (3)"),
        (FILL["kerb"], "Kerb / pool rim (1.2)"),
        (FILL["wall"], "Walls (doors 8 wide)"),
    ]
    for colour, text in rows:
        out.append(f'<rect x="{kx:.0f}" y="{y}" width="18" height="18" fill="{colour}" stroke="#596070"/>')
        out.append(f'<text x="{kx + 28:.0f}" y="{y + 14}" font-size="13" fill="#F4F5F0">{text}</text>')
        y += 26
    if res["longest"]:
        out.append(f'<line x1="{kx:.0f}" y1="{y + 9}" x2="{kx + 18:.0f}" y2="{y + 9}" stroke="#D1495B" stroke-width="2" stroke-dasharray="7 5"/>')
        out.append(f'<text x="{kx + 28:.0f}" y="{y + 14}" font-size="13" fill="#F4F5F0">Longest eye-level line, {res["longest"][0][0]:.0f}</text>')
        y += 26
    if res["first"]:
        D = res["first"][0]
        out.append(f'<line x1="{kx:.0f}" y1="{y + 9}" x2="{kx + 18:.0f}" y2="{y + 9}" stroke="#3DDC84" stroke-width="2" stroke-dasharray="3 3"/>')
        out.append(f'<text x="{kx + 28:.0f}" y="{y + 14}" font-size="13" fill="#F4F5F0">First sight, {D / SPRINT:.1f} s sprint</text>')
        y += 40
        facts = [
            f"Spawn to spawn: {res['direct']:.0f} studs walked",
            f"  {res['direct'] / SPRINT:.1f} s sprint, {res['direct'] / WALK:.1f} s walk",
            f"First sight: {D / SPRINT:.1f} s sprint, {D / WALK:.1f} s walk",
            f"First contact: {res['meet'] / SPRINT:.1f} s sprint, {res['meet'] / WALK:.1f} s walk",
            f"Shell {2 * OUT:.0f} × 236, halls 40 tall",
            f"Coplanar (z-fighting) pairs: {res['coplanar']}",
        ]
        for f in facts:
            out.append(f'<text x="{kx:.0f}" y="{y}" font-size="13" fill="#B9C4BC">{f}</text>')
            y += 20
    y += 14
    bar = 16 * sc
    out.append(f'<rect x="{kx:.0f}" y="{y}" width="{bar:.0f}" height="5" fill="#F4F5F0"/>')
    out.append(f'<text x="{kx:.0f}" y="{y + 22}" font-size="12" fill="#B9C4BC">16 studs</text>')
    out.append("</svg>")
    return "\n".join(out)


# ------------------------------------------------------------------ greybox Luau

COLOURS = {
    "floor": "C9CCC2",
    "wall": "8E989A",
    "ceiling": "6E747A",
    "roof": "9FC9C0",
    "cover": "5F7A5A",
    "low": "A7BC98",
    "kerb": "8FB4C0",
    "column": "E3E6E2",
    "trunk": "7A6450",
    "deck": "D9CFA6",
    "rail": "D9CFA6",
    "ramp": "B5BEB0",
}


def lua_num(v: float) -> str:
    v = float(v)
    return f"{v:.4f}".rstrip("0").rstrip(".") if abs(v - round(v)) > 1e-9 else str(int(round(v)))


def greybox_luau() -> str:
    lines = [
        "--!strict",
        "-- Greenhouse greybox: GENERATED by tools/maps/greenhouse_layout.py --write. Edit the layout there (the checks",
        "-- run on the same numbers), then regenerate and re-run this in the match place:",
        "--   python tools/studio/maps/bundle.py Greenhouse Greybox -o greenhouse_greybox.luau",
        "-- Map space (MapKit.luau): origin on the floor at the Dome's centre, +Z = team B's (blue) end. Every part is",
        "-- collision. Attribute Look = the finish Art.luau gives it; parts without one are replaced by the kit (hidden).",
        "",
        'newMap("Greenhouse", CFrame.new(1500, 200, -1500))',
        "",
        "local KIND: { [string]: Color3 } = {",
    ]
    for k, c in COLOURS.items():
        lines.append(f'\t{k} = Color3.fromHex("{c}"),')
    lines += [
        "}",
        "",
        "-- Boxes { section, name, kind, look, cx, cy, cz, sx, sy, sz } (axis-aligned), both sets written out.",
        "local BOXES: { { any } } = {",
    ]
    oriented, ramps, cyls = [], [], []
    for b in BLOCKS:
        if b.kind == "barrier":
            continue
        if b.shape == "ramp":
            ramps.append(b)
        elif b.shape == "cyl":
            cyls.append(b)
        elif b.axes is not None:
            oriented.append(b)
        else:
            e = b.ext()
            lines.append(f'\t{{ "{b.section}", "{b.name}", "{b.kind}", "{b.look or ""}", {lua_num(b.c[0])}, {lua_num(b.c[1])}, {lua_num(b.c[2])}, {lua_num(e[0])}, {lua_num(e[1])}, {lua_num(e[2])} }},')
    lines += ["}", "", "-- Oriented boxes { section, name, kind, cx, cy, cz, sx, sy, sz, rx, ry, rz, ux, uy, uz } (right and up vectors).", "local ORIENTED: { { any } } = {"]
    for b in oriented:
        ux, uy, _ = b.axes
        vals = [*b.c, *b.s, *ux, *uy]
        lines.append(f'\t{{ "{b.section}", "{b.name}", "{b.kind}", ' + ", ".join(lua_num(v) for v in vals) + " },")
    lines += ["}", "", "-- Ramps { section, name, cx, cy, cz, across, rise, along, yaw } (WedgePart: rises toward its local +Z).", "local RAMPS: { { any } } = {"]
    yaw = {"+z": 0, "-z": 180, "+x": 90, "-x": -90}
    for r in ramps:
        lines.append(f'\t{{ "{r.section}", "{r.name}", {lua_num(r.c[0])}, {lua_num(r.c[1])}, {lua_num(r.c[2])}, {lua_num(r.s[0])}, {lua_num(r.s[1])}, {lua_num(r.s[2])}, {yaw[r.up]} }},')
    lines += ["}", "", "-- Cylinders { section, name, kind, cx, cy, cz, height, diameter } (upright).", "local CYLS: { { any } } = {"]
    for c in cyls:
        lines.append(f'\t{{ "{c.section}", "{c.name}", "{c.kind}", {lua_num(c.c[0])}, {lua_num(c.c[1])}, {lua_num(c.c[2])}, {lua_num(c.s[1])}, {lua_num(c.s[0])} }},')
    lines += ["}", "", "local SPAWNS: { { any } } = {"]
    for team, pts in (("A", SPAWNS_A), ("B", SPAWNS_B)):
        for i, (x, z) in enumerate(pts, 1):
            lines.append(f'\t{{ "{team}", {i}, {lua_num(x)}, {lua_num(z)} }},')
    lines += ["}", "", "local BARRIERS: { { number } } = {"]
    for b in BARRIERS_B + [b.rotated() for b in BARRIERS_B]:
        lines.append(f"\t{{ {lua_num(b.x0)}, {lua_num(b.x1)}, {lua_num(b.y0)}, {lua_num(b.y1)}, {lua_num(b.z0)}, {lua_num(b.z1)} }},")
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
        "local function tag(p: BasePart, kind: string, look: string?)",
        '\tp:SetAttribute("Kind", kind)',
        "\tif look and look ~= \"\" then",
        '\t\tp:SetAttribute("Look", look)',
        "\tend",
        "end",
        "",
        "local count = 0",
        "for _, s in BOXES do",
        "\tlocal kind = s[3] :: string",
        "\tlocal size = Vector3.new(s[8] :: number, s[9] :: number, s[10] :: number)",
        "\tlocal small = math.min(size.X, size.Z) < 4 or size.Y < 4",
        "\tlocal p = box(sec(s[1] :: string), s[2] :: string, size, at(s[5] :: number, s[6] :: number, s[7] :: number), KIND[kind], {",
        "\t\tmaterial = Enum.Material.SmoothPlastic,",
        '\t\tcastShadow = not small or kind == "ceiling",',
        "\t})",
        "\ttag(p, kind, s[4] :: string)",
        "\tcount += 1",
        "end",
        "",
        "for _, s in ORIENTED do",
        "\tlocal pos = Vector3.new(s[4] :: number, s[5] :: number, s[6] :: number)",
        "\tlocal right = Vector3.new(s[10] :: number, s[11] :: number, s[12] :: number)",
        "\tlocal up = Vector3.new(s[13] :: number, s[14] :: number, s[15] :: number)",
        "\tlocal cf = CFrame.fromMatrix(pos, right, up)",
        "\tlocal p = box(sec(s[1] :: string), s[2] :: string, Vector3.new(s[7] :: number, s[8] :: number, s[9] :: number), cf, KIND[s[3] :: string], {",
        "\t\tmaterial = Enum.Material.SmoothPlastic,",
        "\t\tcastShadow = false,",
        "\t})",
        "\ttag(p, s[3] :: string, nil)",
        "\tcount += 1",
        "end",
        "",
        "-- WedgePart: low at local -Z, high at +Z; yaw turns that toward the climb.",
        "for _, s in RAMPS do",
        "\tlocal size = Vector3.new(s[6] :: number, s[7] :: number, s[8] :: number)",
        "\tlocal p = wedge(sec(s[1] :: string), s[2] :: string, size, at(s[3] :: number, s[4] :: number, s[5] :: number, s[9] :: number), KIND.ramp, {",
        "\t\tmaterial = Enum.Material.SmoothPlastic,",
        "\t})",
        '\ttag(p, "ramp", nil)',
        "\tcount += 1",
        "end",
        "",
        "for _, s in CYLS do",
        "\tlocal p = cyl(sec(s[1] :: string), s[2] :: string, s[7] :: number, s[8] :: number, at(s[4] :: number, s[5] :: number, s[6] :: number), KIND[s[3] :: string], {",
        "\t\tmaterial = Enum.Material.SmoothPlastic,",
        "\t})",
        "\ttag(p, s[3] :: string, nil)",
        "\tcount += 1",
        "end",
        "",
        "spawnsClear()",
        "for _, s in SPAWNS do",
        '\tspawnPad(s[1] :: string, s[2] :: number, at(s[3] :: number, 0, s[4] :: number, if s[1] == "A" then 180 else 0))',
        "end",
        "for i, b in BARRIERS do",
        '\tbarrier("Barrier" .. i, Vector3.new(b[2] - b[1], b[4] - b[3], b[6] - b[5]), at((b[1] + b[2]) / 2, (b[3] + b[4]) / 2, (b[5] + b[6]) / 2))',
        "end",
        "",
        'report(string.format("Greenhouse greybox: %d parts, %d spawns, %d barriers", count, #SPAWNS, #BARRIERS))',
        "",
    ]
    return "\n".join(lines)


if __name__ == "__main__":
    res = report()
    SVG_OUT.parent.mkdir(parents=True, exist_ok=True)
    SVG_OUT.write_text(svg(res), encoding="utf-8")
    print(f"\nWrote {SVG_OUT}")
    if "--write" in sys.argv:
        LUAU_OUT.parent.mkdir(parents=True, exist_ok=True)
        LUAU_OUT.write_text(greybox_luau(), encoding="utf-8")
        print(f"Wrote {LUAU_OUT}")
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        import greenhouse_art

        greenhouse_art.write()
        subprocess.run(["stylua", str(LUAU_OUT.parent)], check=False)
