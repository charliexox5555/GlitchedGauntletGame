#!/usr/bin/env python3
"""Dockyard2 map layout (the 2026-11-05 redesign of Dockyard): the top-down plan as data, its checks,
its SVG and the greybox data. Started from tools/maps/dockyard_layout.py (the old map, untouched); every
change against it is listed in CHANGES and justified by the numbers this script prints
(vault/01 Design/Maps/Dockyard2.md -> Layout).

CHANGES against Dockyard (each one measured by this script; old -> new):
  1. Crane stack 2-high -> 1-high, climbed from a crate at each end (Crane crate). The old Updraft-only
     top at 16 saw 61% of the floor and was the one place to stand (LihFolk Combat Arena and Encounter
     Layout §6); the 8-high top everyone can reach sees ~40%.
  2. Crane legs 3 -> 4 square (the chunkier stylized gantry) and the Crane box 2 in from the leg line, so
     the Shed screen can sit 2 further west without a pinch gap: together they close the old first-sight
     diagonal from the apron into the Shed alley (first sight 3.8 -> 4.3 s sprinting, 5.2 -> 5.9 s walking;
     the first look is now across the middle at ~42 studs instead of a 73-stud diagonal).
  3. The Shed roller door moves 4 west (x 46..56) so the screen covers it: no line from the enemy apron
     into a Shed, nor out of a Shed down the far apron.
  4. Quay crates (two 3.5 crates on the open quay) -> one 20-ft Quay stack 6 clear of the barrier: full
     cover mid-quay (worst distance to cover 17.9 -> 16.0) that keeps a 6-wide quay walk, and the Apron box
     moves in to the middle band (44, 6) to cut the band's lateral lines (longest lateral 138 -> 122).
  5. Flank routes come within 0.5 s of the middle (247 vs 237 studs; old 248 vs 226).

Run: python tools/maps/dockyard2_layout.py [--luau]
Prints gaps, sightlines (ground and from the stack tops), spawn safety, cover spread, route
times and the time to first sight, and writes
vault/02 Art/References/maps/dockyard2/dockyard2-layout.svg. With --luau it also rewrites the
generated LAYOUT block of tools/studio/maps/Dockyard2/Greybox.luau, so the greybox is always
the layout that passed these checks.

Map space (MapKit.luau): studs, origin on the pier deck at the map centre, +X across, +Z along
(team A spawns at -Z, team B at +Z), +Y up. 180-degree rotational symmetry: CENTER pieces are
their own partners, HALF lists the B half (Z > 0) and the A half is HALF rotated.
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

PIER_X = 68.0  # half width of the pier deck (water beyond)
YARD_Z = 92.0  # half length of the container yard
ALCOVE_X = 18.0  # half width of a spawn alcove
ALCOVE_END = 110.0  # alcove back wall
DECK_END = 118.0  # deck (and the backdrop stacks) end here
EYE = 5.0  # standing eye height
WALK = 16.0
SPRINT = 22.0
JUMP = 7.2
UPDRAFT_MAX = 28.0
BODY = 1.6  # body clearance for the walk grid
CELL = 1.0
CONTAINER_H = 8.0
REACH = 16.0 + JUMP + UPDRAFT_MAX  # highest stack top + jump + Updraft

import dockyard2_style as STYLE  # noqa: E402

LANE_HUE = {**{k: "#" + v for k, v in STYLE.LANE.items()}, "neutral": "#8A8C90"}


@dataclass
class Box:
    name: str
    x: float
    z: float
    sx: float
    sz: float
    h: float
    kind: str = "box"  # box, low, wall, office, rack, pillar, ramp, roof, beam, lintel, edge, backdrop
    y0: float = 0.0
    up: tuple[float, float] | None = None  # ramps: direction the ramp rises toward
    piece: str = ""  # art hint: C40 / C20 (stacked h / 8 high), Crate, ...

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

    def contains(self, px, pz, pad=0.0):
        return abs(px - self.x) <= self.sx / 2 + pad and abs(pz - self.z) <= self.sz / 2 + pad

    def rotated(self) -> "Box":
        up = (-self.up[0], -self.up[1]) if self.up else None
        return replace(self, name=self.name + "'", x=-self.x, z=-self.z, up=up)

    def lane(self) -> str:
        if self.kind in ("backdrop", "edge", "wall", "roof", "beam", "pillar", "office", "rack", "lintel"):
            return "neutral"
        if self.x < -24:
            return "west"
        if self.x > 24:
            return "east"
        return "mid"


def C40(name, x, z, along="z", stack=1):
    sx, sz = (8.0, 32.0) if along == "z" else (32.0, 8.0)
    return Box(name, x, z, sx, sz, CONTAINER_H * stack, piece="C40")


def C20(name, x, z, along="z", stack=1):
    sx, sz = (8.0, 16.0) if along == "z" else (16.0, 8.0)
    return Box(name, x, z, sx, sz, CONTAINER_H * stack, piece="C20")


def crate(name, x, z, s=4.0, h=3.5):
    return Box(name, x, z, s, s, h, "low", piece="Crate")


# ---------------------------------------------------------------- the layout

# Self-symmetric pieces on the centre point.
CENTER = [
    C40("Crane stack", 0, 0, along="x", stack=1),  # 1-high: blocks the spawn-to-spawn axis; climbed from its crates
    Box("Crane beam", 0, 16, 66, 3, 4, "beam", y0=52),
    Box("Crane beam", 0, -16, 66, 3, 4, "beam", y0=52),
]

# The B half (Z > 0). Lanes: west = X < -24 (red), mid (blue), east = X > 24 (green).
# Warehouse ("Shed") in the B half's east; its rotated copy is the A half's west.
WH_X0, WH_X1, WH_Z0, WH_Z1 = 42.0, 68.0, 24.0, 60.0
HALF = [
    # Crane legs (the RTG gantry straddles the middle; legs on the divider lines).
    Box("Crane leg", 30, 16, 4, 4, 52, "pillar"),
    crate("Crane crate", 12, 6),  # the step onto the Crane stack (its partner sits at the other end)
    Box("Crane leg", -30, 16, 4, 4, 52, "pillar"),
    # The crane stack's step: a 1-high box against the 2-high stack (its partner sits on the other side).
    C20("Stack step", -8, 8, along="x"),
    # Under the crane, on the divider lines: a box between the legs cuts the diagonals across the middle.
    C20("Crane box", 28, 0),
    # Mid lane: a slalom of 20-footers, each one touching nothing.
    # Mid lane: 20-footers that alternately touch the west divider and the ramp, so the lane is a slalom
    # with no straight line along either edge.
    C20("Mid box", -18, 28, along="x"),
    C20("Mid post box", 10, 24),  # along the lane: cuts the lateral lines just past the crane
    C20("Mid box", -18, 50, along="x"),
    C20("Ramp box", 18, 66, along="x"),
    C40("Spawn baffle", 0, 80, along="x", stack=2),  # 2-high: covers the alcove from every far angle and roof
    # East divider: a 40-footer whose top (8) is the high lane, a ramp up from the spawn side.
    C40("East divider", 30, 40),
    Box("Divider ramp", 30, 64, 8, 16, 8, "ramp", up=(0, -1)),
    C20("East end box", 30, 84),
    # West divider: a 40-footer climbed from a crate step, and a 2-high tower near spawn.
    C40("West divider", -30, 40),
    crate("Step crate", -24, 44),  # in the corner of the divider and the mid box: the step up to the top
    C20("West tower", -30, 74, stack=2),
    # West apron (the open quay, long lane).
    C20("Apron box", -44, 6),
    C20("Shed screen", 46, 14, along="x"),  # in front of the Shed's roller door: cuts lines across the middle
    C20("Apron gate box", -38, 32),  # touches the divider: kinks the Shed alley so it never lines up with the apron
    C20("Apron box", -50, 50, along="x"),  # with the Quay box: an L that stops lines from the Shed alley
    C20("Quay stack", -56, 28),  # full cover mid-quay, 6 clear of the barrier: cuts the lateral line, keeps the quay walk
    C20("Quay box", -62, 62),  # touches the barrier and the Apron box: cuts the quay line at the B end
    C20("Apron end box", -48, 80, along="x"),
    # East flank: the alley beside the Shed and the boxes north of it.
    C20("Shed yard box", 52, 76, along="x"),
    # The Shed: 26 x 36 walls 16 tall, gable roof; a roller door to the middle and two doors to the
    # alley (no door at the spawn end: two aligned doors made a line through the Shed and up the quay).
    Box("Shed wall S", 44, WH_Z0 + 0.5, 4, 1, 16, "wall"),
    Box("Shed wall S", 62, WH_Z0 + 0.5, 12, 1, 16, "wall"),
    Box("Shed wall N", 55, WH_Z1 - 0.5, 26, 1, 16, "wall"),
    Box("Shed wall W", WH_X0 + 0.5, 27.5, 1, 5, 16, "wall"),
    Box("Shed wall W", WH_X0 + 0.5, 42, 1, 8, 16, "wall"),
    Box("Shed wall W", WH_X0 + 0.5, 56.5, 1, 5, 16, "wall"),
    Box("Shed wall E", WH_X1 - 0.5, 42, 1, 36, 16, "wall"),
    # Door heads (overhead: they block sight and bullets above the openings, like the art shows).
    Box("Shed lintel S", 51, WH_Z0 + 0.5, 10, 1, 3, "lintel", y0=13),
    Box("Shed lintel W", WH_X0 + 0.5, 34, 1, 8, 7, "lintel", y0=9),
    Box("Shed lintel W", WH_X0 + 0.5, 50, 1, 8, 7, "lintel", y0=9),
    Box("Shed roof", (WH_X0 + WH_X1) / 2, (WH_Z0 + WH_Z1) / 2, WH_X1 - WH_X0 + 1, WH_Z1 - WH_Z0 + 1, 6, "roof", y0=16),
    Box("Shed rack", 55, 45, 2.5, 14, 8, "rack"),
    Box("Shed office", 63.5, 29, 7, 8, 9, "office"),
    crate("Shed crates", 45, 42),
    crate("Shed crates", 65, 46),
    # Map edges: the quay barrier (3 tall: low cover, stops dashes; over it is the harbour).
    # West edge Z -24..92 (its partner runs the east edge up to the B Shed); east edge north of the Shed.
    Box("Quay barrier", -67, 34, 2, 116, 3, "edge"),
    Box("Quay barrier", 67, 76, 2, 32, 3, "edge"),
    # The B end: 3-high backdrop stacks around the spawn alcove (water beyond).
    # 7-high container walls (56): out of reach (16 + jump + Updraft = 51.2), so the end is closed without
    # invisible walls. Only their faces are dressed.
    Box("Backdrop", -43, 105, 50, 26, 56, "backdrop"),
    Box("Backdrop", 43, 105, 50, 26, 56, "backdrop"),
    Box("Backdrop", 0, 114, 36, 8, 56, "backdrop"),
]

BOXES = CENTER + HALF + [b.rotated() for b in HALF]
SPAWNS_B = [(-6.0, 98.0), (6.0, 98.0), (-6.0, 104.0), (6.0, 104.0)]
SPAWNS_A = [(-x, -z) for x, z in SPAWNS_B]
BARRIER_Z = YARD_Z  # the alcove mouth


def on_deck(px, pz) -> bool:
    if abs(px) <= PIER_X and abs(pz) <= YARD_Z:
        return True
    return abs(px) <= ALCOVE_X and abs(pz) <= ALCOVE_END


# ---------------------------------------------------------------- grids

NX = int(2 * PIER_X / CELL) + 1
NZ = int(2 * DECK_END / CELL) + 1
XS = np.linspace(-PIER_X, PIER_X, NX)
ZS = np.linspace(-DECK_END, DECK_END, NZ)


def surface_height(b: Box, px, pz):
    """Top surface height of a piece at a point (ramps and gable roofs slope)."""
    if b.kind == "ramp":
        ux, uz = b.up
        # 0 at the low end, h at the high end
        t = ((px - b.x) * ux + (pz - b.z) * uz) / ((abs(ux) * b.sx + abs(uz) * b.sz) / 2)
        return b.y0 + b.h * (t + 1) / 2
    if b.kind == "roof":
        return b.y0 + b.h * (1 - abs(px - b.x) / (b.sx / 2))
    return b.y0 + b.h


def build_grids():
    gx, gz = np.meshgrid(XS, ZS, indexing="ij")
    ground_top = np.zeros(gx.shape)  # top of ground-standing solids (blocks sight below it)
    over_lo = np.full(gx.shape, np.inf)  # overhead solid (roof/beam) bottom
    over_hi = np.full(gx.shape, -np.inf)
    walk = np.zeros(gx.shape, dtype=bool)
    deck = np.vectorize(on_deck)(gx, gz)
    walk[:] = deck
    for b in BOXES:
        inside = (np.abs(gx - b.x) <= b.sx / 2) & (np.abs(gz - b.z) <= b.sz / 2)
        top = surface_height(b, gx, gz)
        if b.kind in ("roof", "beam", "lintel"):
            over_lo = np.where(inside, np.minimum(over_lo, b.y0), over_lo)
            over_hi = np.where(inside, np.maximum(over_hi, top), over_hi)
            continue
        ground_top = np.where(inside, np.maximum(ground_top, top), ground_top)
        if b.kind != "ramp":
            near = (np.abs(gx - b.x) <= b.sx / 2 + BODY) & (np.abs(gz - b.z) <= b.sz / 2 + BODY)
            walk &= ~near
    # off the deck: nothing stands (water), walls of the deck edge are the barrier pieces
    return gx, gz, ground_top, over_lo, over_hi, walk, deck


def to_idx(x, z):
    return int(round((x + PIER_X) / CELL)), int(round((z + DECK_END) / CELL))


class Sight:
    def __init__(self, ground_top, over_lo, over_hi):
        self.g, self.lo, self.hi = ground_top, over_lo, over_hi

    def clear_many(self, a: np.ndarray, b: np.ndarray, step=0.5) -> np.ndarray:
        """a, b: (n, 3) points (x, z, y). True where the straight line is unblocked."""
        n = len(a)
        if n == 0:
            return np.zeros(0, dtype=bool)
        d = np.linalg.norm((b - a)[:, :2], axis=1)
        steps = int(max(2, math.ceil(d.max() / step)))
        t = np.linspace(0.0, 1.0, steps + 1)[None, :]
        px = a[:, 0:1] + (b[:, 0:1] - a[:, 0:1]) * t
        pz = a[:, 1:2] + (b[:, 1:2] - a[:, 1:2]) * t
        py = a[:, 2:3] + (b[:, 2:3] - a[:, 2:3]) * t
        ix = np.clip(np.rint((px + PIER_X) / CELL).astype(int), 0, NX - 1)
        iz = np.clip(np.rint((pz + DECK_END) / CELL).astype(int), 0, NZ - 1)
        outside = (np.abs(px) > PIER_X) | (np.abs(pz) > DECK_END)
        blocked = (py < self.g[ix, iz] - 1e-6) | ((py >= self.lo[ix, iz]) & (py <= self.hi[ix, iz]))
        blocked &= ~outside
        # the end points themselves stand on/at their surfaces: ignore the first and last samples
        blocked[:, 0] = False
        blocked[:, -1] = False
        return ~blocked.any(axis=1)

    def clear(self, a, b) -> bool:
        return bool(self.clear_many(np.array([a], float), np.array([b], float))[0])


# ---------------------------------------------------------------- checks

def gap(a: Box, b: Box) -> float:
    dx = max(a.x0 - b.x1, b.x0 - a.x1, 0.0)
    dz = max(a.z0 - b.z1, b.z0 - a.z1, 0.0)
    return math.hypot(dx, dz)


def gap_mid(a: Box, b: Box) -> tuple[float, float]:
    """Middle of the gap between two boxes (to skip gaps that a third piece already fills)."""

    def axis(a0, a1, b0, b1):
        if a1 < b0:
            return (a1 + b0) / 2
        if b1 < a0:
            return (b1 + a0) / 2
        return (max(a0, b0) + min(a1, b1)) / 2

    return axis(a.x0, a.x1, b.x0, b.x1), axis(a.z0, a.z1, b.z0, b.z1)


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
                # no corner cutting through blocked cells
                if dx and dz and not (walk[i + dx, j] and walk[i, j + dz]):
                    continue
                nc = c + st
                if nc < dist[a, b]:
                    dist[a, b] = nc
                    heapq.heappush(q, (nc, (a, b)))
    return dist


def first_sight(sight, dist_a, dist_b, deck, speed, grid=3):
    """Earliest time both teams, sprinting/walking from their spawns at t = 0, can see each other."""
    pts = []
    for i in range(0, NX, grid):
        for j in range(0, NZ, grid):
            if deck[i, j] and np.isfinite(dist_a[i, j]) and np.isfinite(dist_b[i, j]):
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
        pairs = []
        ia, ib = np.nonzero(newA)[0], np.nonzero(B)[0]
        pairs += [(i, j) for i in ia for j in ib]
        ia2, ib2 = np.nonzero(prevA)[0], np.nonzero(newB)[0]
        pairs += [(i, j) for i in ia2 for j in ib2]
        prevA, prevB = A, B
        if not pairs:
            continue
        pr = np.array(pairs)
        for k in range(0, len(pr), 4000):
            chunk = pr[k : k + 4000]
            a = np.column_stack([P[chunk[:, 0], 0], P[chunk[:, 0], 1], np.full(len(chunk), EYE)])
            b = np.column_stack([P[chunk[:, 1], 0], P[chunk[:, 1], 1], np.full(len(chunk), EYE)])
            ok = sight.clear_many(a, b)
            if ok.any():
                h = np.nonzero(ok)[0][0]
                return T, (a[h][0], a[h][1]), (b[h][0], b[h][1])
    return None, None, None


def standable_tops():
    """Points on top of pieces a player can stand on (eye = surface + EYE)."""
    out = []
    for b in BOXES:
        if b.kind in ("beam", "pillar", "edge", "low", "rack", "wall", "lintel"):
            continue
        if b.y0 + b.h > REACH:
            continue  # out of reach (the backdrop walls)
        for x in np.arange(b.x0 + 1, b.x1, 2.0):
            for z in np.arange(b.z0 + 1, b.z1, 2.0):
                y = surface_height(b, x, z)
                if y < 4:
                    continue
                # covered by something higher (e.g. a stack inside the roof)?
                if any(o is not b and o.contains(x, z) and surface_height(o, x, z) > y for o in BOXES if o.kind not in ("beam",)):
                    continue
                out.append((x, z, y, b.name))
    return out


def report():
    gx, gz, gtop, olo, ohi, walk, deck = build_grids()
    sight = Sight(gtop, olo, ohi)
    out = {}
    print(f"Pieces: {len(BOXES)}  (containers {sum(1 for b in BOXES if b.piece in ('C40', 'C20'))})")

    print("\nGaps under 6 studs between ground pieces (0 = touching on purpose):")
    ground = [b for b in BOXES if b.y0 == 0 and b.kind not in ("roof", "ramp")]
    narrow = 0
    for i, a in enumerate(ground):
        for b in ground[i + 1 :]:
            g = gap(a, b)
            mx, mz = gap_mid(a, b)
            filled = any(o is not a and o is not b and o.contains(mx, mz) for o in ground)
            if 0 < g < 6 and not filled:
                narrow += 1
                print(f"  {a.name} - {b.name}: {g:.1f}")
    if not narrow:
        print("  none")

    # Sightlines through the yard (ground, eye height).
    best = []
    for x in range(-64, 65, 4):
        for z in range(-90, 91, 4):
            i, j = to_idx(x, z)
            if not walk[i, j]:
                continue
            for deg in range(0, 180, 3):
                dx, dz = math.cos(math.radians(deg)), math.sin(math.radians(deg))
                ends = []
                for sgn in (1, -1):
                    d = 0.0
                    while d < 300:
                        d += 0.5
                        px, pz = x + sgn * dx * d, z + sgn * dz * d
                        if not on_deck(px, pz):
                            break
                        ii, jj = to_idx(px, pz)
                        if gtop[ii, jj] >= EYE or (olo[ii, jj] <= EYE <= ohi[ii, jj]):
                            break
                    ends.append((x + sgn * dx * d, z + sgn * dz * d, d))
                total = ends[0][2] + ends[1][2]
                a, b = ends[1][:2], ends[0][:2]
                if abs(a[1]) <= YARD_Z and abs(b[1]) <= YARD_Z:
                    best.append((total, a, b))
    best.sort(key=lambda t: -t[0])
    over = sum(1 for t in best if t[0] > 100)
    print(f"\nSight rays over 100 studs: {100 * over / len(best):.1f}% of rays sampled; over 70: "
          f"{100 * sum(1 for t in best if t[0] > 70) / len(best):.1f}%")
    print("Longest ground sightlines (eye height, low cover ignored):")
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
    cross = any(sight.clear(a, b) for a in sa for b in sb)
    print("  any spawn A sees any spawn B:", cross)
    cells = [(XS[i], ZS[j]) for i in range(0, NX, 2) for j in range(0, NZ, 2) if walk[i, j] and abs(ZS[j]) <= YARD_Z]
    enemy_half = [p for p in cells if p[1] < -4]  # cells on A's side that see B's spawns
    A = np.array([(x, z, EYE) for x, z in enemy_half for _ in sb])
    B = np.array([s for _ in enemy_half for s in sb])
    seen = sight.clear_many(A, B).reshape(len(enemy_half), len(sb)).any(axis=1)
    print(f"  enemy-half floor that can see a spawn point: {100 * seen.mean():.1f}%")
    out["spawn_seen_from"] = [p for p, s in zip(enemy_half, seen) if s]
    tops = standable_tops()
    enemy_tops = [t for t in tops if t[1] < -4]
    A = np.array([(t[0], t[1], t[2] + EYE) for t in enemy_tops for _ in sb])
    B = np.array([s for _ in enemy_tops for s in sb])
    seen_t = sight.clear_many(A, B).reshape(len(enemy_tops), len(sb)).any(axis=1)
    hit = sorted({t[3] for t, s in zip(enemy_tops, seen_t) if s})
    print(f"  enemy-half stack tops that can see a spawn point: {100 * seen_t.mean():.1f}% "
          f"({', '.join(hit) if hit else 'none'})")

    # Sightlines from the high lane: from each top, the longest line to the ground in the other half.
    print("\nHigh lane (stack tops): what each top overlooks")
    by_top = {}
    for t in tops:
        by_top.setdefault(t[3], []).append(t)
    floor_pts = cells[::3]
    for name, ts in sorted(by_top.items()):
        if name.endswith("'"):
            continue
        y = ts[0][2]
        A = np.array([(t[0], t[1], t[2] + EYE) for t in ts[::2] for _ in floor_pts])
        B = np.array([(p[0], p[1], EYE) for _ in ts[::2] for p in floor_pts])
        ok = sight.clear_many(A, B)
        frac = ok.reshape(len(ts[::2]), len(floor_pts)).any(axis=0).mean()
        print(f"  {name:<16} top {y:>4.0f}: sees {100 * frac:4.1f}% of the walkable floor")

    full = [b for b in BOXES if b.y0 == 0 and b.h >= 7 and b.kind not in ("ramp", "edge")]
    dists = []
    worst, worst_at = 0.0, None
    for p in cells:
        if abs(p[1]) > YARD_Z:
            continue
        d = min(
            math.hypot(max(b.x0 - p[0], 0, p[0] - b.x1), max(b.z0 - p[1], 0, p[1] - b.z1)) for b in full
        )
        dists.append(d)
        if d > worst:
            worst, worst_at = d, p
    print("\nCover spread (distance to the nearest full cover):")
    print(f"  average {sum(dists) / len(dists):.1f}, furthest {worst:.1f} at ({worst_at[0]:.0f},{worst_at[1]:.0f})")

    dist_a = dijkstra(walk, SPAWNS_A)
    dist_b = dijkstra(walk, SPAWNS_B)
    print("\nRoutes (from spawn A, sprinting 22 / walking 16):")

    def at(dist, p):
        return dist[to_idx(*p)]

    routes = {
        "spawn to centre": at(dist_a, (0, 16)),
        "spawn to enemy spawn": at(dist_a, SPAWNS_B[0]),
    }
    for lane, wp in (("west lane", (-60, 0)), ("mid lane", (8, 9)), ("east lane", (60, 0))):
        routes[f"spawn to enemy spawn via {lane}"] = at(dist_a, wp) + at(dist_b, wp)
    for name, d in routes.items():
        print(f"  {name}: {d:.0f} studs, {d / SPRINT:.1f} s sprint / {d / WALK:.1f} s walk")
    meet = np.min(np.maximum(dist_a, dist_b)[np.isfinite(dist_a) & np.isfinite(dist_b)])
    print(f"  both teams sprinting meet after {meet / SPRINT:.1f} s (walking {meet / WALK:.1f} s)")
    out["route"] = routes["spawn to enemy spawn"]

    print("\nTime to first sight (both teams leave spawn at t = 0 on their shortest routes):")
    for label, speed in (("sprint", SPRINT), ("walk", WALK)):
        t, pa, pb = first_sight(sight, dist_a, dist_b, deck, speed)
        print(f"  {label}: {t:.1f} s, A at ({pa[0]:.0f},{pa[1]:.0f}) sees B at ({pb[0]:.0f},{pb[1]:.0f})")
        out["first_" + label] = (t, pa, pb)

    top_max = max(b.y0 + b.h for b in BOXES if b.kind in ("box", "office") and b.y0 == 0)
    reach = top_max + JUMP + UPDRAFT_MAX
    beam = min(b.y0 for b in BOXES if b.kind == "beam")
    back = min(b.y0 + b.h for b in BOXES if b.kind == "backdrop")
    print(f"\nHeights: layers 0 / 8 / 16 (stack tops), Shed eaves 16 and ridge 22, backdrop walls {back:.0f}")
    print(f"  highest reach: {top_max:.0f} + {JUMP} jump + {UPDRAFT_MAX:.0f} Updraft = {reach:.1f} "
          f"(crane beam from {beam:.0f}: {'clear' if beam > reach else 'REACHABLE'}; "
          f"backdrop {back:.0f}: {'clear' if back > reach else 'REACHABLE'})")
    return out


# ---------------------------------------------------------------- SVG

FILL = {
    "low": "#C9B48A",
    "wall": "#5D6066",
    "office": "#7A7D84",
    "rack": "#8C7A5A",
    "pillar": "#E0AE2E",
    "ramp": "#B8BCC6",
    "roof": "none",
    "lintel": "none",
    "beam": "none",
    "edge": "#9C9A94",
    "backdrop": "#55575C",
}


def svg(res) -> str:
    scale = 4.0
    pad = 50
    w = (2 * PIER_X + 40) * scale + 2 * pad + 300
    h = 2 * DECK_END * scale + 2 * pad
    ox, oz = pad + (PIER_X + 20) * scale, pad + DECK_END * scale

    def px(x, z):
        return ox + x * scale, oz - z * scale

    o = [
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w:.0f} {h:.0f}" font-family="Segoe UI, Arial, sans-serif">',
        f'<rect width="{w:.0f}" height="{h:.0f}" fill="#1B2233"/>',
    ]
    # water + deck
    x0, z0 = px(-PIER_X - 20, DECK_END)
    o.append(f'<rect x="{x0:.0f}" y="{z0:.0f}" width="{(2 * PIER_X + 40) * scale:.0f}" height="{2 * DECK_END * scale:.0f}" fill="#22385A"/>')
    x0, z0 = px(-PIER_X, DECK_END)
    o.append(f'<rect x="{x0:.0f}" y="{z0:.0f}" width="{2 * PIER_X * scale:.0f}" height="{2 * DECK_END * scale:.0f}" fill="#B7B3AA"/>')
    # bay markings every 16 studs
    for gx in range(-64, 65, 16):
        a, b = px(gx, -YARD_Z), px(gx, YARD_Z)
        o.append(f'<line x1="{a[0]:.0f}" y1="{a[1]:.0f}" x2="{b[0]:.0f}" y2="{b[1]:.0f}" stroke="#C9C4B8" stroke-width="1"/>')
    for gz in range(-80, 81, 16):
        a, b = px(-PIER_X, gz), px(PIER_X, gz)
        o.append(f'<line x1="{a[0]:.0f}" y1="{a[1]:.0f}" x2="{b[0]:.0f}" y2="{b[1]:.0f}" stroke="#C9C4B8" stroke-width="1"/>')
    # sight: floor cells that see a spawn
    for p in res["spawn_seen_from"]:
        a = px(p[0] - 1, p[1] + 1)
        o.append(f'<rect x="{a[0]:.1f}" y="{a[1]:.1f}" width="{2 * scale}" height="{2 * scale}" fill="#D1495B" opacity="0.5"/>')
    order = sorted(BOXES, key=lambda b: (b.kind in ("roof", "lintel"), b.kind == "beam"))
    for b in order:
        a = px(b.x0, b.z1)
        wv, hv = b.sx * scale, b.sz * scale
        if b.kind in ("roof", "beam", "lintel"):
            o.append(f'<rect x="{a[0]:.1f}" y="{a[1]:.1f}" width="{wv:.1f}" height="{hv:.1f}" fill="none" stroke="#E0AE2E" stroke-width="1.2" stroke-dasharray="5 4"/>')
            continue
        fill = LANE_HUE[b.lane()] if b.kind == "box" else FILL[b.kind]
        op = 1.0 if b.h < 16 else 1.0
        stroke = "#F4F1EA" if b.h >= 16 and b.kind == "box" else "#222"
        sw = 3 if b.h >= 16 and b.kind == "box" else 1
        o.append(f'<rect x="{a[0]:.1f}" y="{a[1]:.1f}" width="{wv:.1f}" height="{hv:.1f}" fill="{fill}" opacity="{op}" stroke="{stroke}" stroke-width="{sw}"/>')
        if b.kind == "ramp":
            ux, uz = b.up
            c = px(b.x - ux * b.sz * 0.3, b.z - uz * b.sz * 0.3)
            d = px(b.x + ux * b.sz * 0.3, b.z + uz * b.sz * 0.3)
            o.append(f'<line x1="{c[0]:.0f}" y1="{c[1]:.0f}" x2="{d[0]:.0f}" y2="{d[1]:.0f}" stroke="#222" stroke-width="2" marker-end="url(#arr)"/>')
    o.insert(1, '<defs><marker id="arr" markerWidth="8" markerHeight="8" refX="4" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="#222"/></marker></defs>')
    # barrier lines
    for sgn in (1, -1):
        a, b = px(-ALCOVE_X, sgn * BARRIER_Z), px(ALCOVE_X, sgn * BARRIER_Z)
        o.append(f'<line x1="{a[0]:.0f}" y1="{a[1]:.0f}" x2="{b[0]:.0f}" y2="{b[1]:.0f}" stroke="#3D8BFF" stroke-width="4" opacity="0.8"/>')
    # longest line + first sight
    _, a, b = res["longest"]
    a, b = px(*a), px(*b)
    o.append(f'<line x1="{a[0]:.0f}" y1="{a[1]:.0f}" x2="{b[0]:.0f}" y2="{b[1]:.0f}" stroke="#FF6B6B" stroke-width="2.5" stroke-dasharray="8 5"/>')
    t, pa, pb = res["first_sprint"]
    a, b = px(*pa), px(*pb)
    o.append(f'<line x1="{a[0]:.0f}" y1="{a[1]:.0f}" x2="{b[0]:.0f}" y2="{b[1]:.0f}" stroke="#FFD166" stroke-width="2.5"/>')
    for p in (a, b):
        o.append(f'<circle cx="{p[0]:.0f}" cy="{p[1]:.0f}" r="5" fill="#FFD166"/>')
    for spawns, colour in ((SPAWNS_A, "#00B8D4"), (SPAWNS_B, "#FF7A4D")):
        for s in spawns:
            c = px(*s)
            o.append(f'<circle cx="{c[0]:.0f}" cy="{c[1]:.0f}" r="6" fill="{colour}" stroke="#111"/>')
    labels = {
        (0, 0): "CRANE STACK (8)",
        (0, 13): "gantry crane",
        (55, 42): "SHED",
        (-55, -42): "SHED",
        (-52, 50): "APRON",
        (52, -50): "APRON",
        (30, 36): "HIGH",
        (-30, 36): "HIGH",
        (-30, 76): "TOWER 16",
        (30, -76): "TOWER 16",
        (0, 101): "B SPAWN",
        (0, -101): "A SPAWN",
        (-80, 0): "HARBOUR",
        (80, 0): "HARBOUR",
    }
    for (x, z), text in labels.items():
        c = px(x, z)
        o.append(f'<text x="{c[0]:.0f}" y="{c[1] + 4:.0f}" text-anchor="middle" font-size="11" font-weight="700" fill="#111" stroke="#F4F1EA" stroke-width="2.5" paint-order="stroke">{text}</text>')
    kx = pad + (2 * PIER_X + 40) * scale + 30
    y = pad + 10
    o.append(f'<text x="{kx}" y="{y}" font-size="26" font-weight="700" fill="#F4F1EA">Dockyard2</text>')
    o.append(f'<text x="{kx}" y="{y + 24}" font-size="13" fill="#B9BDCB">Layout v2 (redesign, checked), 180° rotation, 1v1 to 4v4</text>')
    y += 54
    rows = [
        (LANE_HUE["west"], "West lane containers (red)"),
        (LANE_HUE["mid"], "Mid lane containers (blue)"),
        (LANE_HUE["east"], "East lane containers (green)"),
        ("#888", "White edge: 2-high stack (16)"),
        (FILL["ramp"], "Ramp to a stack top (8)"),
        (FILL["low"], "Crates, low cover 3.5"),
        (FILL["wall"], "Shed walls 16 (roof dashed)"),
        (FILL["pillar"], "Crane legs"),
        (FILL["edge"], "Quay barrier 3 (harbour beyond)"),
        (FILL["backdrop"], "Container walls 56 (7-high)"),
    ]
    for colour, text in rows:
        o.append(f'<rect x="{kx}" y="{y}" width="20" height="16" fill="{colour}" stroke="#F4F1EA" stroke-width="{2 if "White" in text else 0.5}"/>')
        o.append(f'<text x="{kx + 30}" y="{y + 13}" font-size="13" fill="#F4F1EA">{text}</text>')
        y += 26
    o.append(f'<line x1="{kx}" y1="{y + 8}" x2="{kx + 20}" y2="{y + 8}" stroke="#FF6B6B" stroke-width="2.5" stroke-dasharray="8 5"/>')
    o.append(f'<text x="{kx + 30}" y="{y + 13}" font-size="13" fill="#F4F1EA">Longest line, {res["longest"][0]:.0f} studs</text>')
    y += 26
    o.append(f'<line x1="{kx}" y1="{y + 8}" x2="{kx + 20}" y2="{y + 8}" stroke="#FFD166" stroke-width="2.5"/>')
    o.append(f'<text x="{kx + 30}" y="{y + 13}" font-size="13" fill="#F4F1EA">First sight, {t:.1f} s sprinting</text>')
    y += 26
    o.append(f'<rect x="{kx}" y="{y}" width="20" height="16" fill="#D1495B" opacity="0.5"/>')
    o.append(f'<text x="{kx + 30}" y="{y + 13}" font-size="13" fill="#F4F1EA">Floor that sees an enemy spawn</text>')
    y += 26
    o.append(f'<line x1="{kx}" y1="{y + 8}" x2="{kx + 20}" y2="{y + 8}" stroke="#3D8BFF" stroke-width="4"/>')
    o.append(f'<text x="{kx + 30}" y="{y + 13}" font-size="13" fill="#F4F1EA">Spawn barrier</text>')
    y += 40
    o.append(f'<rect x="{kx}" y="{y}" width="{16 * scale:.0f}" height="6" fill="#F4F1EA"/>')
    o.append(f'<text x="{kx}" y="{y + 24}" font-size="13" fill="#B9BDCB">16 studs (one bay)</text>')
    o.append(f'<text x="{kx}" y="{y + 44}" font-size="13" fill="#B9BDCB">Deck {2 * PIER_X:.0f} × {2 * YARD_Z:.0f}, alcoves 36 × 18</text>')
    o.append(f'<text x="{kx}" y="{y + 64}" font-size="13" fill="#B9BDCB">Spawn to spawn {res["route"]:.0f} studs walked</text>')
    o.append("</svg>")
    return "\n".join(o)


# ---------------------------------------------------------------- greybox data (Luau)

def luau_layout() -> str:
    def num(v):
        return f"{v:g}"

    lines = ["local LAYOUT: { Piece } = {"]
    for b in BOXES:
        up = f", up = {{ {num(b.up[0])}, {num(b.up[1])} }}" if b.up else ""
        piece = f', piece = "{b.piece}"' if b.piece else ""
        lines.append(
            f'\t{{ name = "{b.name}", kind = "{b.kind}", lane = "{b.lane()}", x = {num(b.x)}, z = {num(b.z)}, '
            f"sx = {num(b.sx)}, sz = {num(b.sz)}, h = {num(b.h)}, y0 = {num(b.y0)}{up}{piece} }},"
        )
    lines.append("}")
    lines.append("local SPAWNS_A = { " + ", ".join(f"{{ {num(x)}, {num(z)} }}" for x, z in SPAWNS_A) + " }")
    lines.append("local SPAWNS_B = { " + ", ".join(f"{{ {num(x)}, {num(z)} }}" for x, z in SPAWNS_B) + " }")
    return "\n".join(lines)


def write_luau():
    path = ROOT / "tools/studio/maps/Dockyard2/Greybox.luau"
    text = path.read_text(encoding="utf-8")
    # The generated blocks are kept one entry per line (StyLua leaves them alone).
    block = (
        "-- BEGIN LAYOUT (generated by tools/maps/dockyard2_layout.py --luau; edit the layout there)\n"
        + "-- stylua: ignore start\n"
        + luau_layout()
        + "\n-- stylua: ignore end\n-- END LAYOUT"
    )
    new = re.sub(r"-- BEGIN LAYOUT.*?-- END LAYOUT", lambda m: block, text, flags=re.S)
    path.write_text(new, encoding="utf-8", newline="\n")
    print(f"Wrote the layout block of {path}")
    try:
        import dockyard2_art
    except ImportError:
        print("dockyard2_art.py not written yet: art block skipped")
        return

    path = ROOT / "tools/studio/maps/Dockyard2/Art.luau"
    text = path.read_text(encoding="utf-8")
    block = (
        "-- BEGIN ART (generated by tools/maps/dockyard2_art.py via dockyard2_layout.py --luau; edit it there)\n"
        + "-- stylua: ignore start\n"
        + dockyard2_art.luau_block()
        + "\n-- stylua: ignore end\n-- END ART"
    )
    new = re.sub(r"-- BEGIN ART.*?-- END ART", lambda m: block, text, flags=re.S)
    path.write_text(new, encoding="utf-8", newline="\n")
    print(f"Wrote the art block of {path}")


if __name__ == "__main__":
    res = report()
    target = ROOT / "vault/02 Art/References/maps/dockyard2/dockyard2-layout.svg"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(svg(res), encoding="utf-8")
    print(f"\nWrote {target}")
    if "--luau" in sys.argv:
        write_luau()
