#!/usr/bin/env python3
"""Snowpeak Lodge map layout: the plan as data, its 3D checks, its SVG and the greybox data.

Run: python tools/maps/snowpeak_layout.py [--luau]
Prints gaps, sightlines, spawn safety (from the floor, the lofts, balconies, decks and roofs), cover
spread, route times, time to first sight, highest reach and the coplanar (z-fighting) check, and
writes vault/02 Art/References/maps/snowpeak/snowpeak-layout.svg. With --luau it also rewrites the
generated LAYOUT block of tools/studio/maps/Snowpeak/Greybox.luau, so the greybox is always the
layout that passed these checks. Exit code 1 when the coplanar check fails.

Map space (MapKit.luau): studs, origin on the snow at the map centre, +X across, +Z along (team A
spawns at -Z, team B at +Z), +Y up. 180-degree rotational symmetry: CENTER pieces are their own
partners, HALF lists the B side (pieces may cross z = 0) and the A side is HALF rotated.

The sight model is 3D: every solid piece is voxelised at 0.5 studs, so overhead slabs, balcony rails,
window sills and lintels, stairs (wedges) and the gable roof all block exactly where they are.

Coplanar check (mirrors tools/studio/maps/Audit.luau): two box faces that point the same way, lie
within 0.02 studs of the same plane and overlap by at least 0.05 x 0.05 studs z-fight, unless the
shared patch is buried inside a third solid. Faces that touch back to back (a box resting on another)
point opposite ways and are fine.
"""

from __future__ import annotations

import heapq
import math
import re
import sys
from dataclasses import dataclass, replace
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]

FX = 64.0  # field half width (inner face of the side fences)
FZ = 80.0  # field half length (the cliff faces at the ends)
EDGE_X = 66.0  # outer face of the fences: the drop-off beyond
ALCOVE_X = 16.0  # half width of a spawn alcove
ALCOVE_END = 100.0  # alcove back (cliff face)
CLIFF_END = 106.0
CLIFF_H = 72.0
EYE = 5.0
WALK = 16.0
SPRINT = 22.0
JUMP = 7.2
UPDRAFT_MAX = 28.0
BODY = 1.6
STOREY = 10.0  # the upper layer (lofts, balconies, decks)
WALL_H = 20.0  # Lodge eaves
RIDGE = 30.0  # Lodge ridge

V = 0.5  # voxel size
XMIN, XMAX = -68.0, 68.0
ZMIN, ZMAX = -108.0, 108.0
YMAX = 80.0
NXV = int((XMAX - XMIN) / V)
NZV = int((ZMAX - ZMIN) / V)
NYV = int(YMAX / V)

NONSOLID = {"ground", "terrace", "floor", "ice"}  # floor tiles (below y = 0)


@dataclass
class Box:
    name: str
    x: float
    z: float
    sx: float
    sz: float
    h: float
    kind: str = "full"
    y0: float = 0.0
    up: tuple[float, float] | None = None  # ramps: the direction the ramp rises toward
    piece: str = ""  # art hint (Sofa, Cabin, ...)

    @property
    def x0(self):
        return self.x - self.sx / 2

    @property
    def x1(self):
        return self.x + self.sx / 2

    @property
    def z0(self):
        return self.z - self.sz / 2

    @property
    def z1(self):
        return self.z + self.sz / 2

    @property
    def top(self):
        return self.y0 + self.h

    def contains(self, px, pz, pad=0.0):
        return abs(px - self.x) <= self.sx / 2 + pad and abs(pz - self.z) <= self.sz / 2 + pad

    def rotated(self) -> "Box":
        up = (-self.up[0], -self.up[1]) if self.up else None
        return replace(self, name=self.name + "'", x=-self.x, z=-self.z, up=up)


def R(name, x0, x1, z0, z1, h, kind="full", y0=0.0, up=None, piece=""):
    """A box from its extents (x0..x1, z0..z1, y0..y0 + h)."""
    return Box(name, (x0 + x1) / 2, (z0 + z1) / 2, x1 - x0, z1 - z0, h, kind, y0, up, piece)


def wall(name, axis, t0, t1, a0, a1, bays, height=WALL_H):
    """A wall along `axis` ("x" or "z"), thickness t0..t1 across it, from a0 to a1 along it.
    bays: [(b0, b1, [(open_y0, open_y1), ...])]; between bays the wall is solid full height.
    Solid bits below an opening are sills, above it lintels (kinds sill / lintel)."""
    out = []
    edges = [a0]
    for b0, b1, _ in bays:
        edges += [b0, b1]
    edges.append(a1)

    def put(s0, s1, y0, y1, kind):
        if s1 - s0 <= 1e-6 or y1 - y0 <= 1e-6:
            return
        if axis == "x":
            out.append(R(name, s0, s1, t0, t1, y1 - y0, kind, y0))
        else:
            out.append(R(name, t0, t1, s0, s1, y1 - y0, kind, y0))

    for i in range(0, len(edges), 2):
        put(edges[i], edges[i + 1], 0.0, height, "wall")
    for b0, b1, opens in bays:
        y = 0.0
        for o0, o1 in sorted(opens):
            put(b0, b1, y, o0, "sill" if y == 0.0 else "lintel")
            y = o1
        put(b0, b1, y, height, "lintel")
    return out


def tiles(outer, holes, kind, y0, h, name):
    """Non-overlapping rectangles covering `outer` rectangles minus `holes` (x0, x1, z0, z1)."""
    xs = sorted({v for r in outer + holes for v in (r[0], r[1])})
    zs = sorted({v for r in outer + holes for v in (r[2], r[3])})

    def inside(rects, x, z):
        return any(r[0] < x < r[1] and r[2] < z < r[3] for r in rects)

    cells = {}
    for i in range(len(xs) - 1):
        for j in range(len(zs) - 1):
            cx, cz = (xs[i] + xs[i + 1]) / 2, (zs[j] + zs[j + 1]) / 2
            cells[(i, j)] = inside(outer, cx, cz) and not inside(holes, cx, cz)
    out = []
    used = set()
    for i in range(len(xs) - 1):
        j = 0
        while j < len(zs) - 1:
            if not cells[(i, j)] or (i, j) in used:
                j += 1
                continue
            j1 = j
            while j1 + 1 < len(zs) - 1 and cells[(i, j1 + 1)] and (i, j1 + 1) not in used:
                j1 += 1
            i1 = i
            while i1 + 1 < len(xs) - 1 and all(cells[(i1 + 1, k)] and (i1 + 1, k) not in used for k in range(j, j1 + 1)):
                i1 += 1
            for a in range(i, i1 + 1):
                for b in range(j, j1 + 1):
                    used.add((a, b))
            out.append(R(name, xs[i], xs[i1 + 1], zs[j], zs[j1 + 1], h, kind, y0))
            j = j1 + 1
    return out


# ---------------------------------------------------------------- the layout

# The Lodge: walls on x = +-17..18 (long) and z = +-21..22 (ends), floor 0, lofts and balcony at 10,
# eaves 20, ridge 30 along Z. Openings: 6-wide bays on the long walls (centres +-6, +-16), the main
# door (8 wide) and two 5-wide windows on each end wall. Doors 0..8, upper doors 10..18, windows
# 3..8 below and 13..18 above (a regular rhythm: every opening in a storey shares its sill and head).
LODGE_X, LODGE_Z = 18.0, 22.0
BAL = 6.0  # balcony depth
TERR_X, TERR_Z = 25.0, 30.0  # timber-and-stone terrace round the Lodge
POND = (32.0, 60.0, 12.0, 52.0)  # B side frozen pond (ice), x0 x1 z0 z1
ICE_DROP = 0.4  # the ice sits this far below the snow
STATION = (-64.0, -40.0, 30.0, 54.0)  # B side gondola station footprint

CENTER = [
    R("Lodge floor", -LODGE_X, LODGE_X, -LODGE_Z, LODGE_Z, 1, "floor", y0=-1),
    R("Hearth", -5, 5, -3, 3, 12, "hearth", piece="Fireplace"),
    R("Chimney", -3, 3, -3, 3, 22, "chimney", y0=12, piece="Fireplace"),
    R("Lodge roof", -24, 24, -28, 28, RIDGE - WALL_H, "roof", y0=WALL_H, piece="Lodge"),
]

# Doors only in the under-loft rooms (z 14..20), never in the lounge: seen through the entry porch,
# the main door can only look straight in, so no line runs through the Lodge door to door.
EAST_WALL_BAYS = [
    (-20, -14, [(0, 8)]),  # into the A bar room (the partner of B's west door)
    (3, 9, [(13, 18)]),  # high window into the lounge (the west one is at z -9..-3: they never line up past the chimney)
    (14, 20, [(0, 8), (10, 18)]),  # into the B boot room; upper door from the B loft to the balcony
]
END_WALL_BAYS = [
    (-15, -10, [(13, 18)]),  # blank below (shutters closed in the art)
    (-4, 4, [(0, 8), (10, 18)]),  # main door (inside the entry porch), upper door to the end balcony
    (10, 15, [(13, 18)]),
]

sx0, sx1, sz0, sz1 = STATION
HALF = (
    wall("Lodge wall E", "z", LODGE_X - 1, LODGE_X, -LODGE_Z, LODGE_Z, EAST_WALL_BAYS)
    + wall("Lodge wall N", "x", LODGE_Z - 1, LODGE_Z, -LODGE_X + 1, LODGE_X - 1, END_WALL_BAYS)
    + [
        # Inside: the B loft (height 10), its rail over the lounge, the stair up to it beside the hearth.
        R("Loft", -LODGE_X + 1, LODGE_X - 1, 13, LODGE_Z - 1, 1, "slab", y0=STOREY - 1),
        R("Loft rail", -LODGE_X + 1, 5, 13, 13.6, 3, "rail", y0=STOREY, piece="LoftRail"),
        R("Loft rail", 11, LODGE_X - 1, 13, 13.6, 3, "rail", y0=STOREY, piece="LoftRail"),
        R("Lodge stair", 5, 11, -3, 13, STOREY, "ramp", up=(0, 1), piece="LodgeStair"),
        R("Sofa", -4, 4, 8.5, 10.5, 3, "low", piece="Sofa"),
        # Under the loft: the entry hall (10 wide) between the back bar (west, shelves up to the loft)
        # and the boot-room wall (east); the bar room (west door) and boot room (east door) either side.
        # The bar counter faces the back bar across a 2.5 bartender aisle.
        R("Back bar", -7, -5, 13, LODGE_Z - 1, STOREY - 1, "full", piece="BackBar"),
        R("Boot wall", 5, 7, 13, LODGE_Z - 1, STOREY - 1, "full", piece="BootWall"),
        R("Bar counter", -11, -9.5, 16, LODGE_Z - 1, 3.5, "low", piece="BarCounter"),        # The entry porch under the end balcony: side walls so the main door only looks straight in.
        R("Porch wall", -6, -5, LODGE_Z, LODGE_Z + BAL, STOREY - 1, "wall", piece="Porch"),
        R("Porch wall", 5, 6, LODGE_Z, LODGE_Z + BAL, STOREY - 1, "wall", piece="Porch"),
        # Firewood stacked under the end balcony at its west corner (closes the corner line).
        R("Firewood", -LODGE_X, -12, LODGE_Z, LODGE_Z + BAL, 7, "full", piece="Firewood"),
        # Outside: the balcony (east side and B end) and B's outside stair up to it.
        R("Balcony E", LODGE_X, LODGE_X + BAL, -LODGE_Z - BAL, LODGE_Z + BAL, 1, "slab", y0=STOREY - 1),
        R("Balcony N", -LODGE_X, LODGE_X, LODGE_Z, LODGE_Z + BAL, 1, "slab", y0=STOREY - 1),
        R("Balcony rail E", LODGE_X + BAL - 0.6, LODGE_X + BAL, -LODGE_Z - BAL, LODGE_Z + BAL - 0.6, 3, "rail", y0=STOREY, piece="BalconyRail"),
        R("Balcony rail N", -LODGE_X - BAL + 0.6, LODGE_X, LODGE_Z + BAL - 0.6, LODGE_Z + BAL, 3, "rail", y0=STOREY, piece="BalconyRail"),
        R("Deck stair", LODGE_X, LODGE_X + BAL, LODGE_Z + BAL, LODGE_Z + BAL + 16, STOREY, "ramp", up=(0, -1), piece="DeckStair"),
        # B's gondola station (west flank): base with a garage passage, deck at 10, housing, cabin.
        # The garage is an L under the deck: in at the south end, out through the east side (no straight line).
        R("Station base W", sx0, sx0 + 6, sz0, sz1, STOREY, "base", piece="Station"),
        R("Station base N", sx0 + 6, sx0 + 14, sz1 - 6, sz1, STOREY, "base", piece="Station"),
        R("Station base E", sx0 + 14, sx1, sz0, sz1 - 12, STOREY, "base", piece="Station"),
        R("Station base E", sx0 + 14, sx1, sz1 - 6, sz1, STOREY, "base", piece="Station"),
        R("Garage roof", sx0 + 6, sx0 + 14, sz0, sz1 - 6, 2, "slab", y0=STOREY - 2, piece="Station"),
        R("Garage roof", sx0 + 14, sx1, sz1 - 12, sz1 - 6, 2, "slab", y0=STOREY - 2, piece="Station"),
        R("Bullwheel housing", sx0, sx0 + 5, sz0, sz1, 8, "full", y0=STOREY, piece="Station"),
        R("Gondola", sx0 + 11, sx0 + 17, 37, 43, 8, "full", y0=STOREY, piece="Cabin"),
        R("Deck rail S", sx0 + 5, sx1, sz0, sz0 + 0.6, 3, "rail", y0=STOREY, piece="Station"),
        R("Deck rail E", sx1 - 0.6, sx1, sz0 + 0.6, sz1 - 0.6, 3, "rail", y0=STOREY, piece="Station"),
        R("Deck rail N", sx0 + 5, sx1 - 6, sz1 - 0.6, sz1, 3, "rail", y0=STOREY, piece="Station"),
        R("Station column", sx1 - 1.6, sx1 - 0.6, sz0 + 0.6, sz0 + 1.6, 10, "post", y0=STOREY, piece="Station"),
        R("Station column", sx1 - 7, sx1 - 6, sz1 - 1.6, sz1 - 0.6, 10, "post", y0=STOREY, piece="Station"),
        R("Station roof", sx0 - 1, sx1 + 1, sz0 - 1, sz1 + 1, 1.5, "roofflat", y0=2 * STOREY, piece="Station"),
        R("Station stair", sx1 - 6, sx1, sz1, sz1 + 16, STOREY, "ramp", up=(0, -1), piece="StationStair"),
        # B's pond (east flank): the ice, the rock island, the skating hut at the spawn end, a snow
        # pile ploughed against the deck stair.
        R("Pond ice", *POND, 1, "ice", y0=-ICE_DROP - 1, piece="Pond"),
        R("Island", 42, 50, 28, 36, 7 + ICE_DROP, "rock", y0=-ICE_DROP, piece="Island"),
        R("Skate hut", 44, 56, 60, 68, 9, "full", piece="SkateHut"),
        R("Snow pile", LODGE_X + BAL, 32, 34, 42, 8, "full", piece="SnowPile"),
        R("Boulder", 38, 44, 46, 52, 8 + ICE_DROP, "rock", y0=-ICE_DROP, piece="Boulder"),
        # Mid flank: the snowcat; the woodshed on the other flank (their partners sit opposite).
        R("Snowcat", 38, 46, -7, 7, 8, "full", piece="Snowcat"),
        R("Woodshed", -40, -28, 14, 22, 8, "full", piece="Woodshed"),
        R("Woodpile", -34, -26, 29, 32, 7, "full", piece="Woodpile"),
        R("Boulder", -FX, -56, 6, 14, 8, "rock", piece="Boulder"),
        # A snow pile against the far end of the side porch (the stair closes the other side).
        R("Snow pile", -LODGE_X - BAL - 6, -12, 40, 48, 8, "full", piece="SnowPile"),
        # Spawn side: the patrol hut screens the whole alcove mouth; ski racks by the station stair.
        R("Patrol hut", -ALCOVE_X - 4, ALCOVE_X + 4, 64, 70, 10, "full", piece="PatrolHut"),
        R("Rental kiosk", -34, -26, 56, 62, 8, "full", piece="Kiosk"),
        # The B plaza in front of the Lodge: the trail-map board and a fire pit with log benches.
        R("Trail map", 2, 10, 48, 49.5, 8, "full", piece="TrailMap"),
        R("Fire pit", -6, 0, 34, 40, 2.5, "low", piece="FirePit"),
        R("Ski rack", 26, 34, 58, 59.5, 3, "low", piece="SkiRack"),
        # Edges: the fence on the drop-off, the rock cliffs at the end with the spawn alcove.
        R("Fence", FX, EDGE_X, -FZ, FZ, 3, "edge", piece="Fence"),
        R("Cliff", -EDGE_X, -ALCOVE_X, FZ, CLIFF_END, CLIFF_H, "cliff"),
        R("Cliff", ALCOVE_X, EDGE_X, FZ, CLIFF_END, CLIFF_H, "cliff"),
        R("Cliff", -ALCOVE_X, ALCOVE_X, ALCOVE_END, CLIFF_END, CLIFF_H, "cliff"),
    ]
)
# Ground: snow over the field and the alcoves, with holes for the terrace (and Lodge floor) and ponds.
_px0, _px1, _pz0, _pz1 = POND
_FIELD = [(-EDGE_X, EDGE_X, -FZ, FZ), (-ALCOVE_X, ALCOVE_X, FZ, ALCOVE_END), (-ALCOVE_X, ALCOVE_X, -ALCOVE_END, -FZ)]
_HOLES = [(-TERR_X, TERR_X, -TERR_Z, TERR_Z), (_px0, _px1, _pz0, _pz1), (-_px1, -_px0, -_pz1, -_pz0)]
GROUND = tiles(_FIELD, _HOLES, "ground", -2.0, 2.0, "Snow") + tiles(
    [(-TERR_X, TERR_X, -TERR_Z, TERR_Z)], [(-LODGE_X, LODGE_X, -LODGE_Z, LODGE_Z)], "terrace", -1.0, 1.0, "Terrace"
)

BOXES = CENTER + HALF + [b.rotated() for b in HALF] + GROUND
SOLIDS = [b for b in BOXES if b.kind not in NONSOLID]
SPAWNS_B = [(-6.0, 88.0), (6.0, 88.0), (-6.0, 94.0), (6.0, 94.0)]
SPAWNS_A = [(-x, -z) for x, z in SPAWNS_B]
BARRIER_Z = FZ  # the alcove mouth


def on_field(px, pz) -> bool:
    if abs(px) <= FX and abs(pz) <= FZ:
        return True
    return abs(px) <= ALCOVE_X and abs(pz) <= ALCOVE_END


def floor_at(px, pz) -> float:
    x0, x1, z0, z1 = POND
    if x0 < px < x1 and z0 < pz < z1 or -x1 < px < -x0 and -z1 < pz < -z0:
        return -ICE_DROP
    return 0.0


# ---------------------------------------------------------------- voxels (3D sight)

def ramp_height(b: Box, px, pz):
    ux, uz = b.up
    t = ((px - b.x) * ux + (pz - b.z) * uz) / ((abs(ux) * b.sx + abs(uz) * b.sz) / 2)
    return b.y0 + b.h * (np.clip(t, -1, 1) + 1) / 2


def roof_height(b: Box, px, pz):
    # Gable, ridge along Z at the box centre line.
    return b.y0 + b.h * (1 - np.abs(px - b.x) / (b.sx / 2))


def surface_height(b: Box, px, pz):
    if b.kind == "ramp":
        return ramp_height(b, px, pz)
    if b.kind == "roof":
        return roof_height(b, px, pz)
    return b.y0 + b.h


def voxelise():
    vox = np.zeros((NXV, NZV, NYV), dtype=bool)
    xc = XMIN + (np.arange(NXV) + 0.5) * V
    zc = ZMIN + (np.arange(NZV) + 0.5) * V
    yc = (np.arange(NYV) + 0.5) * V
    for b in SOLIDS:
        i = np.nonzero((xc > b.x0) & (xc < b.x1))[0]
        j = np.nonzero((zc > b.z0) & (zc < b.z1))[0]
        if len(i) == 0 or len(j) == 0:
            continue
        gx, gz = np.meshgrid(xc[i], zc[j], indexing="ij")
        top = np.broadcast_to(surface_height(b, gx, gz), gx.shape)
        mask = (yc[None, None, :] > max(b.y0, 0.0)) & (yc[None, None, :] < top[:, :, None])
        vox[i[0] : i[-1] + 1, j[0] : j[-1] + 1, :] |= mask
    return vox


class Sight:
    def __init__(self, vox):
        self.v = vox

    def clear_many(self, a: np.ndarray, b: np.ndarray, step=0.25) -> np.ndarray:
        """a, b: (n, 3) points (x, z, y). True where the straight line is unblocked."""
        n = len(a)
        if n == 0:
            return np.zeros(0, dtype=bool)
        d = np.linalg.norm(b - a, axis=1)
        steps = int(max(2, math.ceil(d.max() / step)))
        t = np.linspace(0.0, 1.0, steps + 1)[None, :]
        px = a[:, 0:1] + (b[:, 0:1] - a[:, 0:1]) * t
        pz = a[:, 1:2] + (b[:, 1:2] - a[:, 1:2]) * t
        py = a[:, 2:3] + (b[:, 2:3] - a[:, 2:3]) * t
        ix = np.floor((px - XMIN) / V).astype(int)
        iz = np.floor((pz - ZMIN) / V).astype(int)
        iy = np.floor(py / V).astype(int)
        inside = (ix >= 0) & (ix < NXV) & (iz >= 0) & (iz < NZV) & (iy >= 0) & (iy < NYV)
        ix, iz, iy = np.clip(ix, 0, NXV - 1), np.clip(iz, 0, NZV - 1), np.clip(iy, 0, NYV - 1)
        blocked = self.v[ix, iz, iy] & inside
        # ignore the samples within 0.6 studs of either end (the points stand at their surfaces)
        near = (t * d[:, None] < 0.6) | ((1 - t) * d[:, None] < 0.6)
        blocked &= ~near
        return ~blocked.any(axis=1)

    def clear(self, a, b) -> bool:
        return bool(self.clear_many(np.array([a], float), np.array([b], float))[0])


def standable(vox, grid=2.0):
    """Points a player can stand on: (x, z, y_floor). Ground and the tops of solids with 6 studs
    of head room. Sampled every `grid` studs."""
    out = []
    head = int(6.0 / V)
    for x in np.arange(-EDGE_X + 1, EDGE_X, grid):
        for z in np.arange(-ALCOVE_END + 1, ALCOVE_END, grid):
            i = int((x - XMIN) / V)
            j = int((z - ZMIN) / V)
            col = vox[i, j]
            if on_field(x, z) and not col[: head].any():
                out.append((x, z, floor_at(x, z)))
            ks = np.nonzero(col[:-1] & ~col[1:])[0]
            for k in ks:
                if k + 1 + head <= NYV and not col[k + 1 : k + 1 + head].any():
                    y = (k + 1) * V
                    if abs(x) <= EDGE_X and abs(z) <= CLIFF_END:
                        out.append((x, z, y))
    return out


# ---------------------------------------------------------------- walk grid (ground level)

CELL = 1.0
NX = int(2 * EDGE_X / CELL) + 1
NZ = int(2 * ALCOVE_END / CELL) + 1
XS = np.linspace(-EDGE_X, EDGE_X, NX)
ZS = np.linspace(-ALCOVE_END, ALCOVE_END, NZ)


def walk_grid():
    gx, gz = np.meshgrid(XS, ZS, indexing="ij")
    walk = np.vectorize(on_field)(gx, gz)
    for b in SOLIDS:
        if b.y0 > 4.5 or b.kind in ("roof", "roofflat"):
            continue  # overhead: walk under it
        near = (np.abs(gx - b.x) <= b.sx / 2 + BODY) & (np.abs(gz - b.z) <= b.sz / 2 + BODY)
        walk &= ~near
    return walk


def to_idx(x, z):
    return int(round((x + EDGE_X) / CELL)), int(round((z + ALCOVE_END) / CELL))


def dijkstra(walk, starts):
    dist = np.full(walk.shape, np.inf)
    q = []
    for s in starts:
        i = to_idx(*s)
        dist[i] = 0.0
        q.append((0.0, i))
    heapq.heapify(q)
    nbr = [(dx, dz, math.hypot(dx, dz) * CELL) for dx in (-1, 0, 1) for dz in (-1, 0, 1) if dx or dz]
    W, H = walk.shape
    while q:
        c, (i, j) = heapq.heappop(q)
        if c > dist[i, j]:
            continue
        for dx, dz, st in nbr:
            a, b = i + dx, j + dz
            if 0 <= a < W and 0 <= b < H and walk[a, b]:
                if dx and dz and not (walk[i + dx, j] and walk[i, j + dz]):
                    continue
                nc = c + st
                if nc < dist[a, b]:
                    dist[a, b] = nc
                    heapq.heappush(q, (nc, (a, b)))
    return dist


def first_sight(sight, dist_a, dist_b, walk, speed, grid=2, max_range=1e9):
    pts = []
    for i in range(0, NX, grid):
        for j in range(0, NZ, grid):
            if walk[i, j] and np.isfinite(dist_a[i, j]) and np.isfinite(dist_b[i, j]):
                pts.append((XS[i], ZS[j], dist_a[i, j] / speed, dist_b[i, j] / speed))
    P = np.array(pts)
    ta, tb = P[:, 2], P[:, 3]
    T = 0.0
    prevA = np.zeros(len(P), bool)
    prevB = np.zeros(len(P), bool)
    while T < 20:
        T += 0.1
        A = ta <= T
        B = tb <= T
        newA = A & ~prevA
        newB = B & ~prevB
        pairs = [(i, j) for i in np.nonzero(newA)[0] for j in np.nonzero(B)[0]]
        pairs += [(i, j) for i in np.nonzero(prevA)[0] for j in np.nonzero(newB)[0]]
        prevA, prevB = A, B
        if not pairs:
            continue
        pr = np.array(pairs)
        for k in range(0, len(pr), 3000):
            chunk = pr[k : k + 3000]
            a = np.column_stack([P[chunk[:, 0], 0], P[chunk[:, 0], 1], np.full(len(chunk), EYE)])
            b = np.column_stack([P[chunk[:, 1], 0], P[chunk[:, 1], 1], np.full(len(chunk), EYE)])
            ok = sight.clear_many(a, b) & (np.hypot(a[:, 0] - b[:, 0], a[:, 1] - b[:, 1]) <= max_range)
            if ok.any():
                h = np.nonzero(ok)[0][0]
                return T, (a[h][0], a[h][1]), (b[h][0], b[h][1])
    return None, None, None


# ---------------------------------------------------------------- coplanar (z-fighting) check

def box_faces(b: Box):
    """Faces of a placed piece: (normal axis 0/1/2 = x/y/z, sign, plane, (u0, u1), (v0, v1)).
    u/v are the other two axes in x, y, z order. Wedges keep their bottom, the high end and the two
    side faces (as rectangles: conservative); the slope is not a box face. Gable roofs keep the
    bottom and their two gable ends."""
    x0, x1, y0, y1, z0, z1 = b.x0, b.x1, b.y0, b.top, b.z0, b.z1
    ext = ((x0, x1), (y0, y1), (z0, z1))
    out = []
    for ax in range(3):
        for sgn in (-1, 1):
            if b.kind == "ramp":
                ux, uz = b.up
                if ax == 1 and sgn == 1:
                    continue  # the slope
                if ax in (0, 2):
                    rises = (ux, uz)[0 if ax == 0 else 1]
                    if rises == -sgn:
                        continue  # the low end has no face
            if b.kind == "roof" and (ax == 0 or (ax == 1 and sgn == 1)):
                continue
            plane = ext[ax][1] if sgn > 0 else ext[ax][0]
            others = [k for k in range(3) if k != ax]
            out.append((ax, sgn, plane, ext[others[0]], ext[others[1]]))
    return out


def inside_solid(p, skip):
    for o in SOLIDS + [g for g in GROUND]:
        if o in skip:
            continue
        if o.kind in ("ramp", "roof"):
            if o.x0 < p[0] < o.x1 and o.z0 < p[2] < o.z1 and o.y0 < p[1] < float(surface_height(o, p[0], p[2])):
                return True
            continue
        if o.x0 < p[0] < o.x1 and o.y0 < p[1] < o.top and o.z0 < p[2] < o.z1:
            return True
    return False


def coplanar_check(boxes, tol=0.02, min_overlap=0.05):
    """Pairs of same-facing faces in one plane that overlap (z-fighting). Returns a list of
    (a, b, axis, plane, area)."""
    faces = []
    for b in boxes:
        for f in box_faces(b):
            faces.append((b, f))
    buckets = {}
    for b, f in faces:
        key = (f[0], f[1], round(f[2] / tol))
        buckets.setdefault(key, []).append((b, f))
    bad = []
    seen = set()
    for (ax, sgn, k), lst in buckets.items():
        cand = list(lst)
        for kk in (k - 1, k + 1):
            cand += [c for c in buckets.get((ax, sgn, kk), []) if c not in lst]
        for i, (a, fa) in enumerate(lst):
            for b, fb in cand:
                if b is a or abs(fa[2] - fb[2]) > tol:
                    continue
                key = tuple(sorted((id(a), id(b))))
                if key in seen:
                    continue
                u0, u1 = max(fa[3][0], fb[3][0]), min(fa[3][1], fb[3][1])
                v0, v1 = max(fa[4][0], fb[4][0]), min(fa[4][1], fb[4][1])
                if u1 - u0 < min_overlap or v1 - v0 < min_overlap:
                    continue
                seen.add(key)
                # buried? sample the shared patch just outside the plane
                others = [kk for kk in range(3) if kk != ax]
                visible = 0
                for su in (0.25, 0.5, 0.75):
                    for sv in (0.25, 0.5, 0.75):
                        p = [0.0, 0.0, 0.0]
                        p[ax] = fa[2] + sgn * 0.05
                        p[others[0]] = u0 + (u1 - u0) * su
                        p[others[1]] = v0 + (v1 - v0) * sv
                        if not inside_solid(p, (a, b)):
                            visible += 1
                if visible >= 3:
                    bad.append((a, b, "xyz"[ax], fa[2], (u1 - u0) * (v1 - v0)))
    return bad


# ---------------------------------------------------------------- checks

def gap(a: Box, b: Box) -> float:
    dx = max(a.x0 - b.x1, b.x0 - a.x1, 0.0)
    dz = max(a.z0 - b.z1, b.z0 - a.z1, 0.0)
    return math.hypot(dx, dz)


def gap_mid(a: Box, b: Box):
    def axis(a0, a1, b0, b1):
        if a1 < b0:
            return (a1 + b0) / 2
        if b1 < a0:
            return (b1 + a0) / 2
        return (max(a0, b0) + min(a1, b1)) / 2

    return axis(a.x0, a.x1, b.x0, b.x1), axis(a.z0, a.z1, b.z0, b.z1)


def report():
    vox = voxelise()
    sight = Sight(vox)
    walk = walk_grid()
    out = {}
    print(f"Pieces: {len(BOXES)} ({len(SOLIDS)} solid, {len(GROUND)} floor tiles)")

    # Gaps between pieces on the same level (ground pieces, and the pieces on the decks at 10).
    print("\nGaps under 6 studs between pieces on one level (0 = touching on purpose):")
    narrow = 0
    for label, level in (("ground", lambda b: b.y0 <= 0 and b.kind not in ("roof", "cliff")), ("height 10", lambda b: b.y0 == STOREY and b.kind not in ("post",))):
        group = [b for b in SOLIDS if level(b)]
        for i, a in enumerate(group):
            for b in group[i + 1 :]:
                g = gap(a, b)
                if not 0 < g < 6:
                    continue
                mx, mz = gap_mid(a, b)
                if any(o is not a and o is not b and o.contains(mx, mz) for o in group):
                    continue
                if {a.piece, b.piece} == {"BarCounter", "BackBar"}:
                    continue  # the bartender aisle (2.5, behind a 3.5 counter) is meant to be tight
                if "Sofa" in (a.piece, b.piece):
                    continue  # a 3-tall sofa is hopped over (jump 7.2): it is not a passage edge
                if a.kind in ("wall", "sill", "lintel", "rail") and b.kind in ("wall", "sill", "lintel", "rail"):
                    continue  # openings in a wall are sized on purpose (doors 6-8, windows 5)
                narrow += 1
                print(f"  [{label}] {a.name} - {b.name}: {g:.1f}")
    if not narrow:
        print("  none")
    out["narrow"] = narrow

    # Ground sightlines through the field (eye height), 3D.
    print("\nSightlines (eye height, from the floor):")
    origins, dirs = [], []
    for x in range(-62, 63, 4):
        for z in range(-78, 79, 4):
            i, j = to_idx(x, z)
            if walk[i, j]:
                origins.append((x, z))
    best = []
    angles = np.radians(np.arange(0, 180, 4))
    for (x, z) in origins:
        for ang in angles:
            dx, dz = math.cos(ang), math.sin(ang)
            ends = []
            for sgn in (1, -1):
                d = np.arange(0.5, 260, 0.5)
                px, pz = x + sgn * dx * d, z + sgn * dz * d
                off = (np.abs(px) > FX) | (np.abs(pz) > FZ)
                ix = np.clip(((px - XMIN) / V).astype(int), 0, NXV - 1)
                iz = np.clip(((pz - ZMIN) / V).astype(int), 0, NZV - 1)
                hit = vox[ix, iz, int(EYE / V)] | off
                k = int(np.argmax(hit)) if hit.any() else len(d) - 1
                ends.append((x + sgn * dx * d[k], z + sgn * dz * d[k], d[k]))
            best.append((ends[0][2] + ends[1][2], ends[1][:2], ends[0][:2]))
    best.sort(key=lambda t: -t[0])
    n = len(best)
    print(f"  rays over 100 studs: {100 * sum(1 for t in best if t[0] > 100) / n:.1f}%, over 70: {100 * sum(1 for t in best if t[0] > 70) / n:.1f}%")
    shown, keys = 0, []
    for total, a, b in best:
        key = (round(a[0] / 12), round(a[1] / 12), round(b[0] / 12), round(b[1] / 12))
        rkey = (-key[2], -key[3], -key[0], -key[1])
        if key in keys or rkey in keys:
            continue
        keys.append(key)
        print(f"  {total:.0f} studs  ({a[0]:.0f},{a[1]:.0f}) -> ({b[0]:.0f},{b[1]:.0f})")
        shown += 1
        if shown == 8:
            break
    out["longest"] = best[0]

    print("\nSpawn safety:")
    sa = [(x, z, EYE) for x, z in SPAWNS_A]
    sb = [(x, z, EYE) for x, z in SPAWNS_B]
    print("  any spawn A sees any spawn B:", any(sight.clear(a, b) for a in sa for b in sb))
    stand = [p for p in standable(vox) if p[2] < CLIFF_H - 0.5]  # cliff tops are out of reach (checked below)
    enemy = [p for p in stand if p[1] < -4]
    A = np.array([(p[0], p[1], p[2] + EYE) for p in enemy for _ in sb])
    B = np.array([s for _ in enemy for s in sb])
    seen = sight.clear_many(A, B).reshape(len(enemy), len(sb)).any(axis=1)
    floor = [p for p, s in zip(enemy, seen) if s and p[2] <= 0]
    high = [p for p, s in zip(enemy, seen) if s and p[2] > 0]
    nfloor = sum(1 for p in enemy if p[2] <= 0)
    print(f"  enemy-half floor that can see a spawn point: {100 * len(floor) / max(nfloor, 1):.1f}%")
    print(f"  enemy-half high spots (lofts, balconies, decks, roofs) that see one: {len(high)} of {len(enemy) - nfloor}"
          + (" at " + ", ".join(f"({p[0]:.0f},{p[1]:.0f},{p[2]:.0f})" for p in high[:6]) if high else ""))
    out["spawn_seen_from"] = floor + high

    # What the high spots overlook.
    print("\nHigh spots: share of the walkable floor each one sees")
    floor_pts = [(XS[i], ZS[j]) for i in range(0, NX, 6) for j in range(0, NZ, 6) if walk[i, j] and abs(ZS[j]) <= FZ]
    spots = {
        "Loft (B)": (0, 17, STOREY),
        "Balcony E": (20.5, 0, STOREY),
        "Balcony N (B end)": (0, 24.5, STOREY),
        "Station deck (B)": (-46, 33, STOREY),
        "Lodge roof ridge": (0, 10, RIDGE),
        "Station roof (B)": (-52, 42, 2 * STOREY + 1.5),
        "Island top": (46, 32, 7),
        "Patrol hut roof": (0, 67, 10),
    }
    for name, (x, z, y) in spots.items():
        A = np.array([(x, z, y + EYE)] * len(floor_pts))
        B = np.array([(p[0], p[1], EYE) for p in floor_pts])
        frac = sight.clear_many(A, B).mean()
        print(f"  {name:<20} at {y:>4.1f}: {100 * frac:4.1f}%")

    full = [b for b in SOLIDS if b.y0 <= 0 and b.top >= 7 and b.kind not in ("ramp", "edge", "roof")]
    dists, worst, worst_at = [], 0.0, None
    for i in range(0, NX, 2):
        for j in range(0, NZ, 2):
            if not walk[i, j] or abs(ZS[j]) > FZ:
                continue
            p = (XS[i], ZS[j])
            d = min(math.hypot(max(b.x0 - p[0], 0, p[0] - b.x1), max(b.z0 - p[1], 0, p[1] - b.z1)) for b in full)
            dists.append(d)
            if d > worst:
                worst, worst_at = d, p
    print("\nCover spread (distance to the nearest full cover, 7+):")
    print(f"  average {sum(dists) / len(dists):.1f}, furthest {worst:.1f} at ({worst_at[0]:.0f},{worst_at[1]:.0f})")

    dist_a = dijkstra(walk, SPAWNS_A)
    dist_b = dijkstra(walk, SPAWNS_B)

    def at(dist, p):
        return dist[to_idx(*p)]

    print("\nRoutes (ground level, from spawn A, sprinting 22 / walking 16):")
    routes = {
        "spawn to the Fireplace": at(dist_a, (14, 0)),
        "spawn to enemy spawn": at(dist_a, SPAWNS_B[0]),
    }
    for lane, wp in (("west lane", (-52, 0)), ("the Lodge", (14, 0)), ("east lane", (52, 0))):
        routes[f"spawn to enemy spawn via {lane}"] = at(dist_a, wp) + at(dist_b, wp)
    for name, d in routes.items():
        print(f"  {name}: {d:.0f} studs, {d / SPRINT:.1f} s sprint / {d / WALK:.1f} s walk")
    both = np.isfinite(dist_a) & np.isfinite(dist_b)
    meet = np.min(np.maximum(dist_a, dist_b)[both])
    print(f"  both teams sprinting meet after {meet / SPRINT:.1f} s (walking {meet / WALK:.1f} s)")
    print(f"  spawn to spawn straight: {math.hypot(SPAWNS_B[0][0] - SPAWNS_A[0][0], SPAWNS_B[0][1] - SPAWNS_A[0][1]):.0f}")
    out["route"] = routes["spawn to enemy spawn"]

    print("\nTime to first sight (both teams leave spawn at t = 0 on their shortest routes, floor level):")
    for label, speed in (("sprint", SPRINT), ("walk", WALK)):
        t, pa, pb = first_sight(sight, dist_a, dist_b, walk, speed)
        dd = math.hypot(pa[0] - pb[0], pa[1] - pb[1])
        print(f"  {label}: {t:.1f} s, A at ({pa[0]:.0f},{pa[1]:.0f}) sees B at ({pb[0]:.0f},{pb[1]:.0f}), {dd:.0f} studs")
        out["first_" + label] = (t, pa, pb)
    for label, speed in (("sprint", SPRINT), ("walk", WALK)):
        t, pa, pb = first_sight(sight, dist_a, dist_b, walk, speed, max_range=70)
        print(f"  within 70 studs, {label}: {t:.1f} s, A at ({pa[0]:.0f},{pa[1]:.0f}) sees B at ({pb[0]:.0f},{pb[1]:.0f})")
        out["first70_" + label] = (t, pa, pb)

    tops = max(p[2] for p in stand if abs(p[1]) <= FZ + 20)
    reach = tops + JUMP + UPDRAFT_MAX
    print(f"\nHeights: layers 0 / {STOREY:.0f} (lofts, balconies, decks) / {WALL_H:.0f}-{RIDGE:.0f} (roofs, Updraft only); cliffs {CLIFF_H:.0f}")
    print(f"  highest standable {tops:.1f} + {JUMP} jump + {UPDRAFT_MAX:.0f} Updraft = {reach:.1f} "
          f"(cliffs {CLIFF_H:.0f}: {'clear' if CLIFF_H > reach else 'REACHABLE'})")
    out["reach"] = reach

    print("\nCoplanar check (z-fighting between visible greybox faces):")
    bad = coplanar_check(BOXES)
    if bad:
        for a, b, ax, plane, area in bad:
            print(f"  FAIL {a.name} / {b.name}: plane {ax} = {plane:.2f}, overlap {area:.2f} sq studs")
    else:
        print(f"  pass: 0 coplanar overlaps in {len(BOXES)} pieces")
    out["coplanar"] = len(bad)
    return out


# ---------------------------------------------------------------- SVG

FILL = {
    "wall": "#6E4B33",
    "sill": "#9C7656",
    "lintel": "none",
    "slab": "none",
    "rail": "#C9A27A",
    "ramp": "#B8BCC6",
    "low": "#C9B48A",
    "full": "#7A808A",
    "hearth": "#8C8883",
    "chimney": "#5E5B57",
    "base": "#A9ABAE",
    "post": "#5E656D",
    "roofflat": "none",
    "roof": "none",
    "rock": "#77808C",
    "edge": "#8A6A4A",
    "cliff": "#4F5560",
}


def svg(res) -> str:
    scale = 4.0
    pad = 50
    w = (2 * EDGE_X + 40) * scale + 2 * pad + 330
    h = 2 * CLIFF_END * scale + 2 * pad
    ox, oz = pad + (EDGE_X + 20) * scale, pad + CLIFF_END * scale

    def px(x, z):
        return ox + x * scale, oz - z * scale

    o = [
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w:.0f} {h:.0f}" font-family="Segoe UI, Arial, sans-serif">',
        '<defs><marker id="arr" markerWidth="8" markerHeight="8" refX="4" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="#222"/></marker></defs>',
        f'<rect width="{w:.0f}" height="{h:.0f}" fill="#1C2433"/>',
    ]
    # drop-off beyond the fences
    x0, z0 = px(-EDGE_X - 20, CLIFF_END)
    o.append(f'<rect x="{x0:.0f}" y="{z0:.0f}" width="{(2 * EDGE_X + 40) * scale:.0f}" height="{2 * CLIFF_END * scale:.0f}" fill="#2B3A52"/>')
    for b in GROUND:
        a = px(b.x0, b.z1)
        fill = "#E9EEF5" if b.kind == "ground" else "#B89C7E"
        o.append(f'<rect x="{a[0]:.1f}" y="{a[1]:.1f}" width="{b.sx * scale:.1f}" height="{b.sz * scale:.1f}" fill="{fill}"/>')
    for b in BOXES:
        if b.kind == "ice":
            a = px(b.x0, b.z1)
            o.append(f'<rect x="{a[0]:.1f}" y="{a[1]:.1f}" width="{b.sx * scale:.1f}" height="{b.sz * scale:.1f}" rx="14" fill="#A9CBDD"/>')
        if b.kind == "floor":
            a = px(b.x0, b.z1)
            o.append(f'<rect x="{a[0]:.1f}" y="{a[1]:.1f}" width="{b.sx * scale:.1f}" height="{b.sz * scale:.1f}" fill="#D8B48A"/>')
    for p in res["spawn_seen_from"]:
        a = px(p[0] - 1, p[1] + 1)
        o.append(f'<rect x="{a[0]:.1f}" y="{a[1]:.1f}" width="{2 * scale}" height="{2 * scale}" fill="#D1495B" opacity="0.55"/>')
    # Upper layer first (dashed outlines), then the ground pieces over it.
    for b in SOLIDS:
        if b.kind in ("slab", "roof", "roofflat"):
            a = px(b.x0, b.z1)
            col = {"slab": "#2E6FB0", "roof": "#3B434D", "roofflat": "#3B434D"}[b.kind]
            dash = "3 3" if b.kind == "slab" else "8 5"
            o.append(f'<rect x="{a[0]:.1f}" y="{a[1]:.1f}" width="{b.sx * scale:.1f}" height="{b.sz * scale:.1f}" fill="{"#2E6FB0" if b.kind == "slab" else "none"}" fill-opacity="0.12" stroke="{col}" stroke-width="1.3" stroke-dasharray="{dash}"/>')
    order = sorted([b for b in SOLIDS if b.kind not in ("slab", "roof", "roofflat", "lintel")], key=lambda b: (b.y0 > 0, b.top))
    for b in order:
        a = px(b.x0, b.z1)
        fill = FILL.get(b.kind, "#888")
        if b.piece == "Cabin":
            fill = "#A8262E"
        op = 0.85 if b.y0 > 0 else 1.0
        o.append(f'<rect x="{a[0]:.1f}" y="{a[1]:.1f}" width="{b.sx * scale:.1f}" height="{b.sz * scale:.1f}" fill="{fill}" opacity="{op}" stroke="#222" stroke-width="0.6"/>')
        if b.kind == "ramp":
            ux, uz = b.up
            L = (abs(ux) * b.sx + abs(uz) * b.sz) * 0.3
            c = px(b.x - ux * L, b.z - uz * L)
            d = px(b.x + ux * L, b.z + uz * L)
            o.append(f'<line x1="{c[0]:.0f}" y1="{c[1]:.0f}" x2="{d[0]:.0f}" y2="{d[1]:.0f}" stroke="#222" stroke-width="2" marker-end="url(#arr)"/>')
    # cable lines leaving the stations over the edge
    for s in (1, -1):
        for dz in (-3.5, 3.5):
            a, b = px(s * -64, s * (42 + dz)), px(s * -86, s * (42 + dz))
            o.append(f'<line x1="{a[0]:.0f}" y1="{a[1]:.0f}" x2="{b[0]:.0f}" y2="{b[1]:.0f}" stroke="#A8262E" stroke-width="2"/>')
    for sgn in (1, -1):
        a, b = px(-ALCOVE_X, sgn * BARRIER_Z), px(ALCOVE_X, sgn * BARRIER_Z)
        o.append(f'<line x1="{a[0]:.0f}" y1="{a[1]:.0f}" x2="{b[0]:.0f}" y2="{b[1]:.0f}" stroke="#3D8BFF" stroke-width="4" opacity="0.85"/>')
    _, a, b = res["longest"]
    a, b = px(*a), px(*b)
    o.append(f'<line x1="{a[0]:.0f}" y1="{a[1]:.0f}" x2="{b[0]:.0f}" y2="{b[1]:.0f}" stroke="#FF6B6B" stroke-width="2.5" stroke-dasharray="8 5"/>')
    t, pa, pb = res["first_walk"]
    a, b = px(*pa), px(*pb)
    o.append(f'<line x1="{a[0]:.0f}" y1="{a[1]:.0f}" x2="{b[0]:.0f}" y2="{b[1]:.0f}" stroke="#F2B705" stroke-width="2.5"/>')
    for p in (a, b):
        o.append(f'<circle cx="{p[0]:.0f}" cy="{p[1]:.0f}" r="5" fill="#F2B705"/>')
    for spawns, colour in ((SPAWNS_A, "#00B8D4"), (SPAWNS_B, "#FF7A4D")):
        for s in spawns:
            c = px(*s)
            o.append(f'<circle cx="{c[0]:.0f}" cy="{c[1]:.0f}" r="6" fill="{colour}" stroke="#111"/>')
    labels = {
        (0, 6): "LOUNGE",
        (0, 17): "LOFT / BAR",
        (0, -17): "LOFT / BAR",
        (0, -6): "FIREPLACE",
        (27, 12): "BALCONY",
        (-27, -12): "BALCONY",
        (-52, 48): "STATION",
        (52, -48): "STATION",
        (-54, 30): "garage",
        (54, -30): "garage",
        (46, 22): "POND",
        (-46, -22): "POND",
        (46, 32): "ISLAND",
        (-46, -32): "ISLAND",
        (50, 72): "HUT",
        (-50, -72): "HUT",
        (42, 0): "SNOWCAT",
        (-42, 0): "SNOWCAT",
        (0, 74): "PATROL",
        (0, -74): "PATROL",
        (0, 96): "B SPAWN",
        (0, -96): "A SPAWN",
        (-80, 0): "DROP",
        (80, 0): "DROP",
    }
    for (x, z), text in labels.items():
        c = px(x, z)
        o.append(f'<text x="{c[0]:.0f}" y="{c[1] + 4:.0f}" text-anchor="middle" font-size="11" font-weight="700" fill="#111" stroke="#F4F1EA" stroke-width="2.5" paint-order="stroke">{text}</text>')
    kx = pad + (2 * EDGE_X + 40) * scale + 30
    y = pad + 10
    o.append(f'<text x="{kx}" y="{y}" font-size="26" font-weight="700" fill="#F4F1EA">Snowpeak Lodge</text>')
    o.append(f'<text x="{kx}" y="{y + 24}" font-size="13" fill="#B9BDCB">Layout v1 (checked), 180° rotation, 1v1 to 3v3</text>')
    y += 54
    rows = [
        (FILL["wall"], "Lodge walls (20), stone fireplace"),
        ("#2E6FB0", "Height 10: lofts, balcony, station deck (dashed)"),
        (FILL["ramp"], "Stairs (arrow points up)"),
        (FILL["rail"], "Rails 3 (on the balcony / deck)"),
        (FILL["low"], "Low cover 3-3.5 (sofa, bar, ski racks)"),
        (FILL["full"], "Full cover 7+ (huts, snowcat, back bar)"),
        ("#A8262E", "Gondola cabin, cable lines"),
        (FILL["base"], "Station base (garage passage)"),
        ("#A9CBDD", "Frozen pond (0.4 below the snow)"),
        (FILL["rock"], "Island rock (7)"),
        (FILL["edge"], "Fence 3 (drop-off beyond)"),
        (FILL["cliff"], "Rock cliffs 72"),
    ]
    for colour, text in rows:
        o.append(f'<rect x="{kx}" y="{y}" width="20" height="16" fill="{colour}" stroke="#F4F1EA" stroke-width="0.5"/>')
        o.append(f'<text x="{kx + 30}" y="{y + 13}" font-size="13" fill="#F4F1EA">{text}</text>')
        y += 26
    for colour, dash, text in (("#FF6B6B", "8 5", f'Longest floor line, {res["longest"][0]:.0f} studs'), ("#F2B705", "", f"First sight, {t:.1f} s walking")):
        o.append(f'<line x1="{kx}" y1="{y + 8}" x2="{kx + 20}" y2="{y + 8}" stroke="{colour}" stroke-width="2.5" stroke-dasharray="{dash}"/>')
        o.append(f'<text x="{kx + 30}" y="{y + 13}" font-size="13" fill="#F4F1EA">{text}</text>')
        y += 26
    o.append(f'<rect x="{kx}" y="{y}" width="20" height="16" fill="#D1495B" opacity="0.55"/>')
    o.append(f'<text x="{kx + 30}" y="{y + 13}" font-size="13" fill="#F4F1EA">Spot that sees an enemy spawn</text>')
    y += 26
    o.append(f'<line x1="{kx}" y1="{y + 8}" x2="{kx + 20}" y2="{y + 8}" stroke="#3D8BFF" stroke-width="4"/>')
    o.append(f'<text x="{kx + 30}" y="{y + 13}" font-size="13" fill="#F4F1EA">Spawn barrier</text>')
    y += 40
    o.append(f'<rect x="{kx}" y="{y}" width="{16 * scale:.0f}" height="6" fill="#F4F1EA"/>')
    o.append(f'<text x="{kx}" y="{y + 24}" font-size="13" fill="#B9BDCB">16 studs</text>')
    o.append(f'<text x="{kx}" y="{y + 44}" font-size="13" fill="#B9BDCB">Field {2 * FX:.0f} × {2 * FZ:.0f}, alcoves {2 * ALCOVE_X:.0f} × {ALCOVE_END - FZ:.0f}</text>')
    o.append(f'<text x="{kx}" y="{y + 64}" font-size="13" fill="#B9BDCB">Spawn to spawn {res["route"]:.0f} studs walked</text>')
    o.append(f'<text x="{kx}" y="{y + 84}" font-size="13" fill="#B9BDCB">Coplanar check: {"pass" if res["coplanar"] == 0 else str(res["coplanar"]) + " FAIL"}</text>')
    o.append("</svg>")
    return "\n".join(o)


# ---------------------------------------------------------------- greybox data (Luau)

def luau_layout() -> str:
    def num(v):
        return f"{round(v, 3):g}"

    lines = ["local LAYOUT: { Piece } = {"]
    for b in BOXES:
        up = f", up = {{ {num(b.up[0])}, {num(b.up[1])} }}" if b.up else ""
        piece = f', piece = "{b.piece}"' if b.piece else ""
        lines.append(
            f'\t{{ name = "{b.name}", kind = "{b.kind}", x = {num(b.x)}, z = {num(b.z)}, '
            f"sx = {num(b.sx)}, sz = {num(b.sz)}, h = {num(b.h)}, y0 = {num(b.y0)}{up}{piece} }},"
        )
    lines.append("}")
    lines.append("local SPAWNS_A = { " + ", ".join(f"{{ {num(x)}, {num(z)} }}" for x, z in SPAWNS_A) + " }")
    lines.append("local SPAWNS_B = { " + ", ".join(f"{{ {num(x)}, {num(z)} }}" for x, z in SPAWNS_B) + " }")
    return "\n".join(lines)


def write_luau():
    path = ROOT / "tools/studio/maps/Snowpeak/Greybox.luau"
    text = path.read_text(encoding="utf-8")
    block = "-- BEGIN LAYOUT (generated by tools/maps/snowpeak_layout.py --luau; edit the layout there)\n" + luau_layout() + "\n-- END LAYOUT"
    new = re.sub(r"-- BEGIN LAYOUT.*?-- END LAYOUT", lambda m: block, text, flags=re.S)
    path.write_text(new, encoding="utf-8", newline="\n")
    print(f"Wrote the layout block of {path}")


if __name__ == "__main__":
    res = report()
    target = ROOT / "vault/02 Art/References/maps/snowpeak/snowpeak-layout.svg"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(svg(res), encoding="utf-8")
    print(f"\nWrote {target}")
    if "--luau" in sys.argv:
        write_luau()
    sys.exit(1 if res["coplanar"] else 0)
