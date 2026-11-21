#!/usr/bin/env python3
"""Arena + Big Arena layout (map redesign 2026-11-16): plans as data, checks, SVGs.

Run: python tools/maps/arena_layout.py [arena|bigarena|rivals]   (default: all three)

`rivals` is the RIVALS Arena measured read-only on 2026-11-16 (ServerStorage.Maps.Arena),
used only to calibrate the checks against a shipped map. It is never built.

Prints, against the brainstorm rules and the Jump Audit:
  spawn gap, longest eye-height sightline (target <= ~0.55 x gap on duel maps),
  lanes across the midline (>= 6 wide; 3-5 duel, 4-7 big) and whether one 20-stud
  Frost Wall / 40-stud Firewall can seal them, full-cover footprint and pieces per
  1000 sq studs, dead-band and jump checks (ledge 7.5 climbs, 8+ doesn't),
  pinch gaps, spawn safety, slide runs (20+ flat into cover), sprint times and
  time to first sight. Writes vault/02 Art/References/maps/arena/<map>-layout.svg.
Studs; X across, Z along the map, +Z is team A. 180-degree rotational symmetry.
"""

from __future__ import annotations

import heapq
import math
import sys
from dataclasses import dataclass, field
from pathlib import Path

EYE = 5.0
SPRINT = 22.0
LEDGE_OK = 7.5  # Jump Audit 2026-11-13: 7.5 climbs at sprint, 8.0 fails
GAP_OK = 9.0
FROST = 20.0
FIREWALL = 40.0


@dataclass
class Box:
    name: str
    x: float
    z: float
    sx: float
    sz: float
    h: float
    yaw: float = 0.0
    # full (blocks sight, not standable by plan), low (<= 3.5 shoot-over), pillar,
    # deck (planned standable top), ramp (walk up to `h`), plinth (low walkable step), baffle
    kind: str = "full"
    base: float = 0.0  # bottom height (a deck on stilts, a lintel)

    def _cs(self):
        r = math.radians(self.yaw)
        return math.cos(r), math.sin(r)

    def corners(self):
        c, s = self._cs()
        out = []
        for dx, dz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            lx, lz = dx * self.sx / 2, dz * self.sz / 2
            out.append((self.x + lx * c - lz * s, self.z + lx * s + lz * c))
        return out

    def contains(self, px, pz, pad=0.0):
        c, s = self._cs()
        dx, dz = px - self.x, pz - self.z
        return abs(dx * c + dz * s) <= self.sx / 2 + pad and abs(-dx * s + dz * c) <= self.sz / 2 + pad

    def rotated(self):
        return Box(self.name + "'", -self.x, -self.z, self.sx, self.sz, self.h, self.yaw, self.kind, self.base)

    @property
    def blocks_eye(self):
        return self.kind not in ("ramp", "low", "plinth", "void", "bridge", "decor") and self.base < EYE <= self.h

    @property
    def collides_floor(self):
        return self.base < 2.0  # you can't walk under it


@dataclass
class Plan:
    name: str
    title: str
    room: list  # polygon (x, z), the playable floor
    center: list
    half: list
    spawns_a: list
    duel: bool
    ceiling: float = 0.0  # 0 = open sky
    notes: list = field(default_factory=list)

    @property
    def boxes(self):
        return self.center + self.half + [b.rotated() for b in self.half]

    @property
    def spawns_b(self):
        return [(-x, -z) for x, z in self.spawns_a]


def poly_contains(poly, x, z):
    inside = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, zi = poly[i]
        xj, zj = poly[j]
        if (zi > z) != (zj > z) and x < (xj - xi) * (z - zi) / (zj - zi) + xi:
            inside = not inside
        j = i
    return inside


def poly_area(poly):
    return abs(sum(poly[i][0] * poly[i - 1][1] - poly[i - 1][0] * poly[i][1] for i in range(len(poly)))) / 2


def ngon(r, n, flat_top=True):
    off = math.pi / n if flat_top else 0.0
    return [(r * math.sin(off + 2 * math.pi * i / n), r * math.cos(off + 2 * math.pi * i / n)) for i in range(n)]


def rect_with_nooks(hx, hz, nx, nd):
    """Room hx*2 by hz*2 with a spawn nook nx*2 wide, nd deep at each end."""
    return [
        (-nx, hz + nd), (nx, hz + nd), (nx, hz), (hx, hz), (hx, -hz), (nx, -hz),
        (nx, -hz - nd), (-nx, -hz - nd), (-nx, -hz), (-hx, -hz), (-hx, hz), (-nx, hz),
    ]


# --------------------------------------------------------------------------- plans
# ARENA (duel, 1v1-2v2). Our own layout: a plain 92 x 136 panel court, no spawn nooks: players are
# held in place at open-floor markers behind the spawn screen (RIVALS-style ghost hold, owner 2026-11-16).
# Landmark: the Beacon, a faceted gold-crowned pylon on a +3 octagonal plinth (one per map,
# centre). Each team gets a +7 corner deck by its spawn (ramp + climbable face, a diagonal
# pair), a window frame on the far flank, and full-cover slabs that break every long line.
ARENA = Plan(
    name="arena",
    title="Arena",
    # Snapped to the 5-stud panel module (owner 2026-11-16: RIVALS sizes, grid lines meet across parts):
    # slabs 5 thick, lengths 10/15/20, full cover 10 high, edges on the 2.5 grid. Plain parts, two colours.
    room=[(-45, 70), (45, 70), (45, -70), (-45, -70)],
    center=[
        Box("Beacon plinth", 0, 0, 20, 20, 3, 0, "plinth"),
        Box("Beacon pylon", 0, 0, 5, 5, 35, 0, "pillar"),
    ],
    half=[
        Box("Spawn screen", 0, 47.5, 20, 5, 10, 0, "baffle"),
        Box("Spawn screen wing", 12.5, 45, 5, 10, 10, 0, "baffle"),
        Box("Corner deck", 35, 57.5, 20, 25, 7, 0, "deck"),
        Box("Deck ramp", 40, 37.5, 10, 15, 7, 0, "ramp"),
        Box("Frame post", -32.5, 27.5, 5, 5, 7.5, 0, "pillar"),
        Box("Frame post", -32.5, 42.5, 5, 5, 7.5, 0, "pillar"),
        Box("Frame sill", -32.5, 35, 5, 10, 3, 0, "low"),
        Box("Frame lintel", -32.5, 35, 5, 20, 10, 0, "full", 7.5),
        Box("Spawn wall", -27.5, 57.5, 15, 5, 10),
        Box("Mid wall", 7.5, 27.5, 15, 5, 10),
        Box("Mid low wall", -7.5, 27.5, 15, 5, 3, 0, "low"),
        # v3 (owner playtest 2026-11-21: "needs more levels, high ground"): the side block is now a +7 platform with a parapet on its enemy side and a step from your side
        Box("Side platform", 30, 10, 10, 10, 7, 0, "deck"),
        Box("Side parapet", 30, 2.5, 10, 5, 10),
        Box("Side step", 30, 17.5, 5, 5, 3.5, 0, "plinth"),
        Box("Angled slab", -15, 12.5, 15, 5, 10, 30),
        Box("Beacon wing", -12.5, -5, 5, 10, 10),
    ],
    spawns_a=[(-5, 65), (5, 65), (-5, 60), (5, 60)],
    duel=True,
    notes=["open sky: Updraft and Crash Down free everywhere; barrier ceiling at +60"],
)

# BIG ARENA (3v3, also 2v2): the same kit on a faceted 12-sided court, 216 across.
# Three lanes split by two long divider walls a side; two high spots a side
# (a +7 deck by ramp, a +14 tower deck by stair + from the deck), the Beacon in the middle.
_R = 112.0
BIGARENA = Plan(
    name="bigarena",
    title="Big Arena",
    room=ngon(_R, 12),
    # Snapped to the 5-stud module like Arena (owner 2026-11-16), plain parts, two colours.
    center=[
        Box("Beacon plinth", 0, 0, 25, 25, 3, 0, "plinth"),
        Box("Beacon pylon", 0, 0, 5, 5, 45, 0, "pillar"),
    ],
    half=[
        Box("Spawn screen", 0, 77.5, 40, 5, 10, 0, "baffle"),
        Box("Spawn screen wing", -22.5, 82.5, 5, 15, 10, 0, "baffle"),
        Box("Spawn wall", 42.5, 77.5, 15, 5, 10, 0, "full"),
        Box("Spawn low", -45, 82.5, 10, 5, 3, 0, "low"),
        Box("Tower deck", -60, 60, 20, 20, 14, 0, "deck"),
        Box("Tower stair", -60, 40, 10, 20, 14, 0, "ramp"),
        Box("Tower step deck", -45, 57.5, 10, 15, 7, 0, "deck"),
        Box("Step crate", -37.5, 62.5, 5, 5, 3, 0, "plinth"),
        Box("Side deck", 65, 45, 20, 20, 7, 0, "deck"),
        Box("Side deck ramp", 65, 27.5, 10, 15, 7, 0, "ramp"),
        Box("Divider", -32.5, 15, 5, 20, 10, 0, "full"),
        Box("Divider sill", -32.5, 32.5, 5, 15, 3, 0, "low"),
        Box("Divider lintel", -32.5, 32.5, 5, 15, 10, 0, "full", 7.5),
        Box("Divider post", -32.5, 42.5, 5, 5, 10, 0, "pillar"),
        Box("Mid wall", 12.5, 52.5, 15, 5, 10, 0, "full"),
        Box("Mid low wall", 0, 52.5, 10, 5, 3, 0, "low"),
        Box("Mid slab", -15, 25, 15, 5, 10, 20, "full"),
        Box("Beacon wing", -25, -7.5, 10, 5, 10, 0, "full"),
        Box("Mid post", 17.5, 32.5, 5, 5, 10, 0, "pillar"),
        Box("Left slab", -65, 15, 15, 5, 10, -15, "full"),
        Box("Left low", -82.5, -7.5, 5, 15, 3, 0, "low"),
        # v3 (owner playtest 2026-11-21): the left block is a +7 platform (parapet toward the enemy, step behind)
        Box("Left platform", -50, -30, 10, 10, 7, 0, "deck"),
        Box("Left parapet", -50, -37.5, 10, 5, 10, 0, "full"),
        Box("Left step", -50, -22.5, 5, 5, 3.5, 0, "plinth"),
        Box("Outer slab", -90, 30, 5, 15, 10, 30, "full"),
        Box("Right platform", 60, 10, 10, 10, 7, 0, "deck"),
        Box("Right parapet", 60, 2.5, 10, 5, 10, 0, "full"),
        Box("Right step", 60, 17.5, 5, 5, 3.5, 0, "plinth"),
        Box("Right slab", 87.5, -7.5, 5, 15, 10, 0, "full"),
        Box("Outer post", 87.5, 32.5, 5, 5, 10, 0, "pillar"),
    ],
    spawns_a=[(-12, 94), (0, 96), (12, 94), (-6, 88), (6, 88)],
    duel=False,
    notes=["open sky; barrier ceiling at +80"],
)

# RIVALS Arena, measured read-only (calibration only, never built). Floor top = 0.
RIVALS = Plan(
    name="rivals",
    title="RIVALS Arena (calibration)",
    room=[(-45.5, 65.5), (45.5, 65.5), (45.5, -65.5), (-45.5, -65.5)],
    center=[
        Box("Canopy pillar", -8, -8, 5, 5, 15, 0, "pillar"),
        Box("Canopy pillar", 8, -8, 5, 5, 15, 0, "pillar"),
        Box("Canopy pillar", -8, 8, 5, 5, 15, 0, "pillar"),
        Box("Canopy pillar", 8, 8, 5, 5, 15, 0, "pillar"),
    ],
    half=[
        Box("Arch post", 42, -42, 5, 5, 15, 0, "pillar"),
        Box("Arch post", 28, -42, 5, 5, 15, 0, "pillar"),
        Box("Arch base", 35, -42, 20, 5, 3, 0, "low"),
        Box("Wall", 35, 38, 20, 5, 15),
        Box("Block", 35, 48, 20, 15, 15),
        Box("Arch post", 21, 22, 5, 5, 15, -150, "pillar"),
        Box("Arch post", 9, 29, 5, 5, 15, -150, "pillar"),
        Box("Arch base", 15, 26, 20, 5, 3, -150, "low"),
        Box("Slab", -15, 26, 20, 5, 20, 150),
        Box("Block", -28, 0, 15, 10, 20),
        Box("Slab", 0, 48, 20, 5, 20),
    ],
    spawns_a=[(0, 60)],
    duel=True,
)

PLANS = {p.name: p for p in (ARENA, BIGARENA, RIVALS)}


# --------------------------------------------------------------------------- checks
class Grid:
    def __init__(self, plan: Plan, cell=1.0):
        self.plan = plan
        self.cell = cell
        xs = [p[0] for p in plan.room]
        zs = [p[1] for p in plan.room]
        self.x0, self.z0 = min(xs) - 2, min(zs) - 2
        self.nx = int((max(xs) - self.x0 + 2) / cell) + 1
        self.nz = int((max(zs) - self.z0 + 2) / cell) + 1
        boxes = plan.boxes
        self.inside, self.sight, self.walk = {}, {}, {}
        for ix in range(self.nx):
            x = self.x0 + ix * cell
            for iz in range(self.nz):
                z = self.z0 + iz * cell
                ins = poly_contains(plan.room, x, z)
                self.inside[(ix, iz)] = ins
                self.sight[(ix, iz)] = (not ins) or any(b.blocks_eye and b.contains(x, z) for b in boxes)
                self.walk[(ix, iz)] = (
                    ins
                    and not any(
                        b.kind not in ("ramp", "void", "bridge", "decor") and b.collides_floor and b.contains(x, z, 2.2)
                        for b in boxes
                    )
                    # a void (alley gap, molten channel) is walkable only where a bridge crosses it
                    and not (
                        any(b.kind == "void" and b.contains(x, z) for b in boxes)
                        and not any(b.kind == "bridge" and b.contains(x, z) for b in boxes)
                    )
                )

    def cell_of(self, x, z):
        return (round((x - self.x0) / self.cell), round((z - self.z0) / self.cell))

    def blocked(self, x, z):
        return self.sight.get(self.cell_of(x, z), True)

    def ray(self, x, z, dx, dz, maxd=400.0, step=0.5):
        d = 0.0
        while d < maxd:
            d += step
            if self.blocked(x + dx * d, z + dz * d):
                return d
        return maxd

    def clear(self, a, b):
        d = math.dist(a, b)
        n = max(1, int(d / 0.5))
        return not any(self.blocked(a[0] + (b[0] - a[0]) * i / n, a[1] + (b[1] - a[1]) * i / n) for i in range(n + 1))

    def path(self, start, goal):
        s, g = self.cell_of(*start), self.cell_of(*goal)
        seen, prev = {s: 0.0}, {}
        q = [(0.0, s)]
        while q:
            cost, cur = heapq.heappop(q)
            if cur == g:
                out = [cur]
                while cur in prev:
                    cur = prev[cur]
                    out.append(cur)
                return cost, [(self.x0 + c[0] * self.cell, self.z0 + c[1] * self.cell) for c in reversed(out)]
            if cost > seen[cur]:
                continue
            for dx in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    nx = (cur[0] + dx, cur[1] + dz)
                    st = math.hypot(dx, dz) * self.cell
                    if st and self.walk.get(nx) and cost + st < seen.get(nx, math.inf):
                        seen[nx] = cost + st
                        prev[nx] = cur
                        heapq.heappush(q, (cost + st, nx))
        return None, []


def seg_gap(a: Box, b: Box):
    def pts(box):
        cs = box.corners()
        for i in range(4):
            p, q = cs[i], cs[(i + 1) % 4]
            n = max(2, int(math.dist(p, q)))
            for t in range(n + 1):
                yield (p[0] + (q[0] - p[0]) * t / n, p[1] + (q[1] - p[1]) * t / n)

    pa, pb = list(pts(a)), list(pts(b))
    if any(a.contains(*p) for p in pb) or any(b.contains(*p) for p in pa):
        return 0.0
    return min(math.dist(p, q) for p in pa for q in pb)


def wall_gap(plan: Plan, b: Box):
    """Shortest distance from the box's corners/edges to the room outline (0 if touching)."""
    poly = plan.room
    best = math.inf
    for px, pz in b.corners():
        for i in range(len(poly)):
            (ax, az), (bx, bz) = poly[i - 1], poly[i]
            vx, vz = bx - ax, bz - az
            t = max(0.0, min(1.0, ((px - ax) * vx + (pz - az) * vz) / (vx * vx + vz * vz)))
            best = min(best, math.dist((px, pz), (ax + vx * t, az + vz * t)))
    return best


def report(plan: Plan):
    big = not plan.duel
    g = Grid(plan, 1.0)
    boxes = plan.boxes
    sa = (sum(x for x, _ in plan.spawns_a) / len(plan.spawns_a), sum(z for _, z in plan.spawns_a) / len(plan.spawns_a))
    gap = math.dist(sa, (-sa[0], -sa[1]))
    area = poly_area(plan.room)
    print(f"\n==== {plan.title} ====")
    print(f"floor area {area:.0f} sq studs, boxes {len(boxes)}, spawns {len(plan.spawns_a)} a side")
    print(f"spawn gap (centroids): {gap:.0f}  (duel 120-160, big ~180-200)")

    # sightlines
    best = []
    step = 4 if plan.duel else 6
    xs = [p[0] for p in plan.room]
    zs = [p[1] for p in plan.room]
    for x in range(int(min(xs)), int(max(xs)) + 1, step):
        for z in range(int(min(zs)), int(max(zs)) + 1, step):
            if g.blocked(x, z):
                continue
            for deg in range(0, 180, 3):
                dx, dz = math.cos(math.radians(deg)), math.sin(math.radians(deg))
                d1, d2 = g.ray(x, z, dx, dz), g.ray(x, z, -dx, -dz)
                best.append((d1 + d2, (x - dx * d2, z - dz * d2), (x + dx * d1, z + dz * d1)))
    best.sort(key=lambda t: -t[0])
    target = 0.55 * gap if plan.duel else 250
    print(f"longest sightline: {best[0][0]:.0f}  (target <= {target:.0f}; ratio {best[0][0] / gap:.2f} of the gap)")
    shown, last = 0, None
    for tot, a, b in best:
        key = (round(a[0] / 10), round(a[1] / 10), round(b[0] / 10), round(b[1] / 10))
        if key == last:
            continue
        last = key
        print(f"   {tot:.0f}  ({a[0]:.0f},{a[1]:.0f}) -> ({b[0]:.0f},{b[1]:.0f})")
        shown += 1
        if shown == 4:
            break
    over = sum(1 for t in best if t[0] > target) / len(best)
    print(f"   rays over target: {100 * over:.1f}%")

    # lanes across the middle band at eye height (three cross-lines)
    for zl in ((-8.0, 0.0, 8.0) if plan.duel else (-12.0, 0.0, 12.0)):
        lanes, run = [], None
        xa = min(xs) - 1
        while xa <= max(xs) + 1:
            open_ = poly_contains(plan.room, xa, zl) and not g.blocked(xa, zl)
            if open_ and run is None:
                run = xa
            if not open_ and run is not None:
                lanes.append((run, xa))
                run = None
            xa += 0.5
        if run is not None:
            lanes.append((run, xa))
        wide = [(a, b) for a, b in lanes if b - a >= 6]
        print(f"lanes across z={zl:+.0f} (>= 6 wide): {len(wide)}  widths {[round(b - a) for a, b in wide]}"
              f"  Frost Wall seals {sum(1 for a, b in wide if b - a <= FROST)}, Firewall {sum(1 for a, b in wide if b - a <= FIREWALL)}")

    # cover
    full = [b for b in boxes if b.blocks_eye and b.collides_floor]
    low = [b for b in boxes if b.kind == "low"]
    foot = sum(b.sx * b.sz for b in full)
    eye_cells = sum(1 for k, v in g.inside.items() if v)
    blocked_cells = sum(1 for k, v in g.inside.items() if v and g.sight[k])
    print(f"full cover pieces {len(full)}, low {len(low)}; footprint {100 * foot / area:.1f}% of floor "
          f"(eye-height blocked {100 * blocked_cells / eye_cells:.1f}%); "
          f"{1000 * (len(full) + len(low)) / area:.1f} pieces per 1000 sq studs (RIVALS ~1.7-2.5)")

    # heights, dead band, jump
    print("heights:")
    for b in plan.center + plan.half:
        if not b.collides_floor:
            continue
        flag = ""
        if 4.0 < b.h <= 6.0:
            flag = "  DEAD BAND (4-6)"
        elif b.kind in ("full", "pillar", "baffle") and b.h <= LEDGE_OK:
            flag = "  climbable: unplanned perch"
        elif LEDGE_OK < b.h < 8.0:
            flag = "  coin-flip climb (7.5-8)"
        if b.kind == "deck":
            ways = ["climb" if b.h <= LEDGE_OK else None]
            for r in boxes:
                if r.kind == "ramp" and seg_gap(r, b) == 0.0 and abs(r.h - b.h) < 0.1:
                    ways.append("ramp")
                if r.kind in ("deck", "plinth") and r is not b and seg_gap(r, b) == 0.0 and 0 < b.h - r.h <= LEDGE_OK:
                    ways.append(f"from +{r.h:.0f}")
            ways = [w for w in ways if w]
            flag += f"  ways up: {', '.join(ways) or 'NONE'}" + ("" if len(ways) >= 2 else "  <2 WAYS")
        if flag or b.kind in ("deck", "plinth"):
            print(f"   {b.name}: +{b.h:g}{flag}")

    # pinch gaps
    print("pinch gaps (0 < gap < 6.5):")
    n = 0
    for i, a in enumerate(boxes):
        for b in boxes[i + 1 :]:
            if {"ramp", "plinth", "void", "bridge", "decor"} & {a.kind, b.kind} or not (a.collides_floor and b.collides_floor):
                continue
            gp = seg_gap(a, b)
            if 0 < gp < 6.5 and not (a.name.startswith("Frame") and b.name.startswith("Frame")):
                print(f"   {a.name} - {b.name}: {gp:.1f}")
                n += 1
    for b in boxes:
        if b.collides_floor and b.kind not in ("ramp", "void", "bridge", "decor"):
            wg = wall_gap(plan, b)
            if 0.3 < wg < 6.5:
                print(f"   {b.name} - room wall: {wg:.1f}")
                n += 1
    if not n:
        print("   none")

    # spawn safety
    sees = any(g.clear(a, b) for a in plan.spawns_a for b in plan.spawns_b)
    cells = [(x, z) for x in range(int(min(xs)), int(max(xs)) + 1, 3) for z in range(int(min(zs)), int(max(zs)) + 1, 3)
             if poly_contains(plan.room, x, z) and not g.blocked(x, z) and z < -4]
    seen = sum(1 for p in cells if any(g.clear(p, s) for s in plan.spawns_a))
    print(f"spawn A sees spawn B: {sees};  enemy-half floor that sees a spawn point: {100 * seen / max(1, len(cells)):.1f}%")

    # slide runs: straight flat runs of 20-45 that end in full cover (not the room wall)
    runs = 0
    for x in range(int(min(xs)), int(max(xs)) + 1, 4):
        for z in range(int(min(zs)), int(max(zs)) + 1, 4):
            if not g.walk.get(g.cell_of(x, z)):
                continue
            for deg in range(0, 360, 45):
                dx, dz = math.cos(math.radians(deg)), math.sin(math.radians(deg))
                d = 0.0
                while d < 45 and g.walk.get(g.cell_of(x + dx * d, z + dz * d)):
                    d += 1.0
                ex, ez = x + dx * (d + 3), z + dz * (d + 3)
                if d >= 20 and poly_contains(plan.room, ex, ez) and any(b.blocks_eye and b.contains(ex, ez) for b in full):
                    runs += 1
    print(f"slide runs (20-45 flat, ending in full cover), sampled: {runs}")

    # sprint + first contact
    centre = (0.0, 14.0 if plan.duel else 16.0)
    while not g.walk.get(g.cell_of(*centre)) and centre[1] < 60:
        centre = (0.0, centre[1] + 2.0)  # the nearest walkable spot north of the middle piece
    s0 = plan.spawns_a[0]
    c1, _ = g.path(s0, centre)
    c2, pa = g.path(s0, plan.spawns_b[-1])
    print(f"sprint: spawn to centre {c1 / SPRINT:.1f} s; spawn to enemy spawn {c2 / SPRINT:.1f} s" if c1 and c2 else "sprint: NO ROUTE")
    if pa:
        # both players rush the same lane head-on (route mirrored across the midline); first frame they see each other
        pb = [(x, -z) for x, z in pa]
        first = None
        for i in range(0, len(pa), 2):
            if g.clear(pa[i], pb[i]):
                first = i
                break
        if first is not None:
            t = sum(math.dist(pa[k], pa[k + 1]) for k in range(first)) / SPRINT
            print(f"first sight (both rush the direct route): {t:.1f} s at ({pa[first][0]:.0f},{pa[first][1]:.0f})  (target ~3-5)")
        else:
            print("first sight: never on the direct route")
    for nline in plan.notes:
        print(f"note: {nline}")
    return best[0]


# --------------------------------------------------------------------------- svg
FILL = {"full": "#C9CCD8", "low": "#ECEEF3", "pillar": "#6F7488", "deck": "#AEB3C6", "ramp": "#D5D9E6",
        "plinth": "#E2D3A4", "baffle": "#C9CCD8"}


def svg(plan: Plan, longest):
    xs = [p[0] for p in plan.room]
    zs = [p[1] for p in plan.room]
    scale = 5.0 if plan.duel else 3.2
    pad = 50
    w = (max(xs) - min(xs)) * scale + 2 * pad + 240
    h = (max(zs) - min(zs)) * scale + 2 * pad

    def px(x, z):
        return pad + (x - min(xs)) * scale, pad + (max(zs) - z) * scale

    o = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w:.0f} {h:.0f}" font-family="Segoe UI, Arial, sans-serif">',
         f'<rect width="{w:.0f}" height="{h:.0f}" fill="#20242E"/>']
    o.append('<polygon points="%s" fill="#F4F5F9" stroke="#FFFFFF" stroke-width="4"/>' % " ".join("%.1f,%.1f" % px(*p) for p in plan.room))
    for b in sorted(plan.boxes, key=lambda b: (b.kind == "pillar", b.base > 0)):
        dash = ' stroke-dasharray="4 3"' if b.base > 0 else ""
        o.append('<polygon points="%s" fill="%s" fill-opacity="%s" stroke="#4D5266" stroke-width="1.2"%s/>' % (
            " ".join("%.1f,%.1f" % px(*c) for c in b.corners()), FILL.get(b.kind, "#C9CCD8"), "0.35" if b.base > 0 else "1", dash))
        if b.kind in ("deck", "ramp", "plinth") or b.h >= 9:
            cx, cz = px(b.x, b.z)
            o.append(f'<text x="{cx:.1f}" y="{cz + 4:.1f}" text-anchor="middle" font-size="10" fill="#20242E">+{b.h:g}</text>')
    _, a, b = longest
    ax, az = px(*a)
    bx, bz = px(*b)
    o.append(f'<line x1="{ax:.1f}" y1="{az:.1f}" x2="{bx:.1f}" y2="{bz:.1f}" stroke="#D1495B" stroke-width="2" stroke-dasharray="7 5"/>')
    for sp, col in ((plan.spawns_a, "#3D6FD6"), (plan.spawns_b, "#D9822B")):
        for s in sp:
            sx, sz = px(*s)
            o.append(f'<circle cx="{sx:.1f}" cy="{sz:.1f}" r="5" fill="{col}"/>')
    kx = w - 220
    o.append(f'<text x="{kx:.0f}" y="{pad + 8}" font-size="22" font-weight="700" fill="#F4F5F9">{plan.title}</text>')
    o.append(f'<text x="{kx:.0f}" y="{pad + 30}" font-size="12" fill="#B9BDCB">Layout v1, 180° rotation, 2026-11-16</text>')
    y = pad + 56
    for kind, text in (("pillar", "Pillar / post"), ("full", "Full cover, 9-10"), ("deck", "Deck, +7 / +14"),
                       ("ramp", "Ramp / stair"), ("plinth", "Beacon plinth, +3"), ("low", "Low cover, 3")):
        o.append(f'<rect x="{kx:.0f}" y="{y}" width="18" height="18" fill="{FILL[kind]}" stroke="#4D5266"/>')
        o.append(f'<text x="{kx + 26:.0f}" y="{y + 14}" font-size="13" fill="#F4F5F9">{text}</text>')
        y += 26
    o.append(f'<text x="{kx:.0f}" y="{y + 14}" font-size="13" fill="#F4F5F9">dashed = overhead (lintel)</text>')
    y += 26
    o.append(f'<line x1="{kx:.0f}" y1="{y + 8}" x2="{kx + 18:.0f}" y2="{y + 8}" stroke="#D1495B" stroke-width="2" stroke-dasharray="7 5"/>')
    o.append(f'<text x="{kx + 26:.0f}" y="{y + 13}" font-size="13" fill="#F4F5F9">Longest line {longest[0]:.0f}</text>')
    y += 30
    o.append(f'<rect x="{kx:.0f}" y="{y}" width="{20 * scale:.0f}" height="5" fill="#F4F5F9"/>')
    o.append(f'<text x="{kx:.0f}" y="{y + 22}" font-size="12" fill="#B9BDCB">20 studs</text>')
    o.append("</svg>")
    return "\n".join(o)


def png(plan: Plan, longest, path: Path):
    from PIL import Image, ImageDraw

    xs = [p[0] for p in plan.room]
    zs = [p[1] for p in plan.room]
    scale, pad = (6.0 if plan.duel else 3.6), 30
    w, h = int((max(xs) - min(xs)) * scale + 2 * pad), int((max(zs) - min(zs)) * scale + 2 * pad)
    im = Image.new("RGB", (w, h), "#20242E")
    d = ImageDraw.Draw(im)

    def px(x, z):
        return (pad + (x - min(xs)) * scale, pad + (max(zs) - z) * scale)

    d.polygon([px(*p) for p in plan.room], fill="#F4F5F9", outline="#FFFFFF")
    for b in sorted(plan.boxes, key=lambda b: (b.kind == "pillar", b.base > 0)):
        pts = [px(*c) for c in b.corners()]
        if b.base > 0:
            d.polygon(pts, outline="#4D5266")
        else:
            d.polygon(pts, fill=FILL.get(b.kind, "#C9CCD8"), outline="#4D5266")
        if b.kind in ("deck", "ramp", "plinth") or b.h >= 9:
            d.text(px(b.x - 2, b.z + 1), f"+{b.h:g}", fill="#20242E")
    _, a, bb = longest
    d.line([px(*a), px(*bb)], fill="#D1495B", width=2)
    for sp, col in ((plan.spawns_a, "#3D6FD6"), (plan.spawns_b, "#D9822B")):
        for s in sp:
            x, z = px(*s)
            d.ellipse([x - 4, z - 4, x + 4, z + 4], fill=col)
    im.save(path)


IDS = {"arena": "Arena", "bigarena": "BigArena"}
ORIGINS = {"arena": (4500, 200, 0), "bigarena": (4500, 200, -600)}  # match place, clear of every other map


def luau(plan: Plan) -> str:
    def row(b: Box):
        return '{"%s", "%s", %g, %g, %g, %g, %g, %g, %g}' % (b.name, b.kind, b.x, b.z, b.sx, b.sz, b.h, b.yaw, b.base)

    ox, oy, oz = ORIGINS[plan.name]
    lines = [
        "{",
        f'\tid = "{IDS[plan.name]}",',
        f'\ttitle = "{plan.title}",',
        f"\torigin = {{{ox:g}, {oy:g}, {oz:g}}},",
        "\troom = {" + ", ".join("{%g, %g}" % q for q in plan.room) + "},",
        "\tboxes = {",
        *["\t\t" + row(b) + "," for b in plan.boxes],
        "\t},",
        "\tspawnsA = {" + ", ".join("{%g, %g}" % q for q in plan.spawns_a) + "},",
        "\tspawnsB = {" + ", ".join("{%g, %g}" % q for q in plan.spawns_b) + "},",
        f"\tduel = {'true' if plan.duel else 'false'},",
        f"\tceiling = {60 if plan.duel else 80},",
        f"\twallHeight = {16 if plan.duel else 18},",
        "}",
    ]
    src = (Path(__file__).resolve().parents[2] / "tools/studio/maps/Arena/Greybox.luau").read_text(encoding="utf-8")
    return src.replace("nil :: any --@DATA", "\n".join(lines))


if __name__ == "__main__":
    if sys.argv[1:2] == ["--luau"]:
        for nm in sys.argv[2:]:
            out = Path(sys.argv[0]).resolve().parents[2] / f"art-source/maps/Arena/greybox_{nm}.luau"
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_text(luau(PLANS[nm]), encoding="utf-8")
            print("wrote", out)
        sys.exit(0)
    names = sys.argv[1:] or ["rivals", "arena", "bigarena"]
    out_dir = Path(__file__).resolve().parents[2] / "vault/02 Art/References/maps/arena"
    out_dir.mkdir(parents=True, exist_ok=True)
    for nm in names:
        p = PLANS[nm]
        longest = report(p)
        if nm != "rivals":
            (out_dir / f"{nm}-layout.svg").write_text(svg(p, longest), encoding="utf-8")
            png(p, longest, out_dir / f"{nm}-layout.png")
            print(f"wrote {out_dir / (nm + '-layout.svg')}")
