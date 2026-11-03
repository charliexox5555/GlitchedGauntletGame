#!/usr/bin/env python3
"""Metro map layout: the plan as data, its checks, its SVG and the greybox it builds.

Run:  python tools/maps/metro_layout.py            checks + SVG
      python tools/maps/metro_layout.py --luau     ...and rewrites tools/studio/maps/Metro/Greybox.luau
                                                   (then: stylua tools/studio/maps/Metro/Greybox.luau)

The map is a list of collision blocks (boxes and ramps) in map space: studs, origin on the
platform floor at the centre of the hall, +X across (east), +Z along (team B's end, the blue
end), +Y up. Team A spawns at -Z. Only the centre and team B's half are listed: team A's half
is the same list turned 180 degrees about Y, so the map is fair by construction.

The checks are 2.5D: the blocks are rasterised into a 0.5-stud voxel grid, players are
5.5-stud columns that walk, step, jump (up to 7) and drop between floors, and every sight
test is a 3D line between eye points (floor + 5). It prints gaps, sightlines, spawn safety,
route times, the time to first sight and the time to first contact, and writes
vault/02 Art/References/maps/metro/metro-layout.svg. Needs numpy.
"""

from __future__ import annotations

import heapq
import math
import sys
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
SVG_OUT = ROOT / "vault/02 Art/References/maps/metro/metro-layout.svg"
LUAU_OUT = ROOT / "tools/studio/maps/Metro/Greybox.luau"

# ------------------------------------------------------------------ numbers

EYE = 5.0  # eye above the floor
BODY = 5.5  # standing height
JUMP = 7.0  # highest ledge you can jump onto (Config/Movement JUMP_HEIGHT 7.2)
SPRINT = 22.0  # Config/Movement SPRINT_SPEED
WALK = 16.0  # Config/Movement WALK_SPEED
R = 0.5  # voxel size
XMIN, XMAX = -52.0, 52.0
ZMIN, ZMAX = -132.0, 132.0
YMIN, YMAX = -6.0, 32.0

# Key heights
TRENCH = -4.0  # track bed
PLAT = 0.0  # platforms, corridors, train floor
TERR = 14.0  # terrace, ticket hall, spawn (the concourse level)
CEIL = 28.0  # hall and concourse ceiling
CORR_CEIL = 12.0  # service corridors

# Plan
TRENCH_X = 14.0  # trench is |x| < 14
PLAT_X = 34.0  # platforms (20 wide) run to the hall wall at |x| = 34
WALL_X = 36.0  # hall wall 34..36
OUT_X = 48.0  # corridors 36..48, outer wall 48..50
ESC_X = 25.0  # escalator well 25..34 (team B's, east)
TICKET_Z = 68.0  # concourse wall 66..68 between the terrace and the ticket hall
SPAWN_Z = 106.0  # spawn room front wall 106..107
HALL_Z = 48.0  # hall is |z| < 48 at platform level; terraces beyond
TRAIN = dict(x0=3.5, x1=13.5, z0=-6.0, z1=46.0, roof=9.0)  # team B's train (east track)


# ------------------------------------------------------------------ blocks

@dataclass
class Block:
    """A collision box. kind: floor, wall, ceiling, cover, low, train, rail, gantry, sign."""

    name: str
    section: str
    x0: float
    x1: float
    y0: float
    y1: float
    z0: float
    z1: float
    kind: str = "wall"

    def rotated(self) -> "Block":
        return Block(self.name, self.section, -self.x1, -self.x0, self.y0, self.y1, -self.z1, -self.z0, self.kind)

    @property
    def cx(self) -> float:
        return (self.x0 + self.x1) / 2

    @property
    def cz(self) -> float:
        return (self.z0 + self.z1) / 2


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

    def rotated(self) -> "Ramp":
        return Ramp(self.name, self.section, -self.x1, -self.x0, self.y0, self.y1, -self.z1, -self.z0, -self.up, self.kind)

    def height(self, z: float) -> float:
        t = (z - self.z0) / (self.z1 - self.z0)
        t = t if self.up > 0 else 1 - t
        return self.y0 + (self.y1 - self.y0) * min(max(t, 0.0), 1.0)


def B(name, section, x0, x1, y0, y1, z0, z1, kind="wall"):
    return Block(name, section, x0, x1, y0, y1, z0, z1, kind)


def train_doors(t: dict):
    """Door openings (z0, z1) of a train: four on the platform side; on the track side only the
    two next to the gangway are open (the rest of that side is dark glass: solid)."""
    z0, z1 = t["z0"], t["z1"]
    mid = (z0 + z1) / 2
    cars = [(z0, mid - 1), (mid + 1, z1)]
    platform = []
    for a, b in cars:
        platform += [(a + 4.5, a + 10.5), (b - 10.5, b - 4.5)]
    track = [platform[1], platform[2]]
    return platform, track, mid


def train_blocks(t: dict) -> list[Block]:
    """Two coupled cars on one track, flush with the platform: floor at platform level, doors
    and short windows (3.5 to 7, see- and shoot-through) on the platform side, two open doors
    on the track side, a roof you can stand on (Updraft, or a drop from your own terrace)."""
    x0, x1, z0, z1, roof = t["x0"], t["x1"], t["z0"], t["z1"], t["roof"]
    s = "Train"
    platform, track, mid = train_doors(t)
    out = [
        B("Underframe", s, x0, x1, TRENCH, PLAT, z0, z1, "train"),
        B("Roof", s, x0, x1, roof, roof + 1, z0, z1, "train"),
        B("EndCab", s, x0, x1, PLAT, roof, z1 - 0.5, z1, "train"),
        B("EndRear", s, x0, x1, PLAT, roof, z0, z0 + 0.5, "train"),
        B("Gangway", s, x0 + 0.5, x0 + 2, PLAT, roof, mid - 1, mid + 1, "train"),
        B("Gangway", s, x1 - 2, x1 - 0.5, PLAT, roof, mid - 1, mid + 1, "train"),
    ]
    for side, (wx0, wx1), doors, low in (
        ("Track", (x0, x0 + 0.5), track, 7.0),
        ("Platform", (x1 - 0.5, x1), platform, 3.5),
    ):
        out.append(B("Upper" + side, s, wx0, wx1, 7.0, roof, z0 + 0.5, z1 - 0.5, "train"))
        edges = [z0 + 0.5] + [e for d in doors for e in d] + [z1 - 0.5]
        for i in range(0, len(edges), 2):
            if edges[i + 1] - edges[i] > 0.01:
                out.append(B("Lower" + side, s, wx0, wx1, PLAT, low, edges[i], edges[i + 1], "train"))
        if side == "Platform":
            for da, db in doors:
                out.append(B("DoorPost", s, wx0, wx1, 3.5, 7.0, da - 1, da, "train"))
                out.append(B("DoorPost", s, wx0, wx1, 3.5, 7.0, db, db + 1, "train"))
    return out


# The centre: blocks that are their own 180-degree partner.
CENTER: list = [
    B("TrenchFloor", "Hall", -TRENCH_X, TRENCH_X, TRENCH - 1, TRENCH, -51, 51, "floor"),
    B("HallCeiling", "Hall", -48, 48, CEIL, CEIL + 1, -HALL_Z, HALL_Z, "ceiling"),
    # The departure gantry: the hall's landmark, and it closes terrace-to-terrace sight.
    B("Gantry", "Hall", -PLAT_X, PLAT_X, 11, CEIL, -1.5, 1.5, "gantry"),
    # Its centre clock hangs down between the two trains (head room 7 over the track bed).
    B("GantryClock", "Hall", -3.5, 3.5, 3, 11, -1.5, 1.5, "gantry"),
]

# Team B's half (+Z). Team A's half is this list rotated.
HALF: list = [
    # --- Platforms and corridor (each spans the whole hall; its rotation is the other side)
    B("PlatformEast", "Hall", TRENCH_X, PLAT_X, TRENCH - 1, PLAT, -HALL_Z, HALL_Z, "floor"),
    B("DoorSill", "Hall", PLAT_X, WALL_X, PLAT - 1, PLAT, -44, -36, "floor"),
    B("DoorSill", "Hall", PLAT_X, WALL_X, PLAT - 1, PLAT, -4, 4, "floor"),
    B("HallWallEast", "Hall", PLAT_X, WALL_X, PLAT, CEIL, -HALL_Z, -44),
    B("HallWallEast", "Hall", PLAT_X, WALL_X, 10, CEIL, -44, -36),  # over the far door
    B("HallWallEast", "Hall", PLAT_X, WALL_X, PLAT, CEIL, -36, -4),
    B("HallWallEast", "Hall", PLAT_X, WALL_X, 10, CEIL, -4, 4),  # over the mid door
    B("HallWallEast", "Hall", PLAT_X, WALL_X, PLAT, CEIL, 4, HALL_Z),
    B("CorridorFloor", "Corridor", WALL_X, OUT_X, PLAT - 1, PLAT, -HALL_Z, HALL_Z, "floor"),
    B("CorridorCeiling", "Corridor", WALL_X, OUT_X, CORR_CEIL, CORR_CEIL + 1, -HALL_Z, HALL_Z, "ceiling"),
    B("OuterWallEast", "Shell", OUT_X, OUT_X + 2, TRENCH - 1, CEIL, -SPAWN_Z - 2, SPAWN_Z + 2),
    # Pump rooms: two blocks that put a dog-leg in each corridor (no 96-stud corridor line).
    B("PumpRoom", "Corridor", 42, OUT_X, PLAT, CORR_CEIL, 14, 24, "cover"),
    B("PumpRoom", "Corridor", WALL_X, 42, PLAT, CORR_CEIL, -24, -14, "cover"),
    # --- Concourse level (team B): terrace over the hall end, ticket hall, spawn room
    B("TerraceBlock", "Concourse", -OUT_X, ESC_X - 1, TRENCH - 1, TERR, 51, 72, "floor"),
    B("TerraceFront", "Concourse", -OUT_X, -TRENCH_X, TRENCH - 1, TERR, HALL_Z, 51, "floor"),
    B("TerraceFront", "Concourse", TRENCH_X, ESC_X - 1, TRENCH - 1, TERR, HALL_Z, 51, "floor"),
    B("PortalLintel", "Concourse", -TRENCH_X, TRENCH_X, 10, TERR, HALL_Z, 51, "floor"),
    B("WingWall", "Concourse", -OUT_X, -WALL_X, TERR - 1, CEIL, HALL_Z - 1, HALL_Z),
    B("CorridorHead", "Corridor", WALL_X, OUT_X, CORR_CEIL, CEIL, HALL_Z - 1, HALL_Z),
    B("Parapet", "Concourse", -WALL_X, -22, TERR, TERR + 3, HALL_Z, HALL_Z + 1, "low"),
    B("Parapet", "Concourse", TRENCH_X, ESC_X - 1, TERR, TERR + 3, HALL_Z, HALL_Z + 1, "low"),
    # The station-name panel over the tunnel portal (the landmark): no drop from the terrace
    # straight into the trench, and no terrace view straight down the far trench.
    B("NamePanel", "Concourse", -TRENCH_X, TRENCH_X, TERR, 22, HALL_Z, HALL_Z + 1, "wall"),
    B("EscalatorBase", "Concourse", ESC_X, PLAT_X, TRENCH - 1, PLAT, HALL_Z, 72, "floor"),
    B("EscalatorRail", "Concourse", ESC_X - 1, ESC_X, TERR, TERR + 3.5, HALL_Z, 72, "low"),
    B("WellDivider", "Concourse", PLAT_X, WALL_X, TRENCH - 1, CEIL, HALL_Z, 72, "wall"),
    B("StairBase", "Corridor", WALL_X, OUT_X, PLAT - 1, PLAT, HALL_Z, 72, "floor"),
    # Concourse wall: two 10-wide portals from the ticket hall onto the terrace, and a lintel
    # over the escalator well, so the ticket hall and spawn never look out over the hall.
    B("ConcourseWall", "Concourse", -OUT_X, -14, TERR, CEIL, TICKET_Z - 2, TICKET_Z),
    B("ConcourseWall", "Concourse", -4, 4, TERR, CEIL, TICKET_Z - 2, TICKET_Z),
    B("ConcourseWall", "Concourse", 14, ESC_X - 1, TERR, CEIL, TICKET_Z - 2, TICKET_Z),
    B("PortalHead", "Concourse", -14, -4, TERR + 10, CEIL, TICKET_Z - 2, TICKET_Z),
    B("PortalHead", "Concourse", 4, 14, TERR + 10, CEIL, TICKET_Z - 2, TICKET_Z),
    B("PortalHead", "Concourse", ESC_X - 1, PLAT_X, 22, CEIL, TICKET_Z - 2, TICKET_Z),
    B("TicketFloor", "Concourse", -OUT_X, OUT_X, TERR - 1, TERR, 72, SPAWN_Z, "floor"),
    B("ConcourseCeiling", "Concourse", -50, 50, CEIL, CEIL + 1, HALL_Z, SPAWN_Z + 22, "ceiling"),
    B("TicketWallNorth", "Concourse", -OUT_X, -16, TERR, CEIL, SPAWN_Z, SPAWN_Z + 2),
    B("TicketWallNorth", "Concourse", 16, OUT_X, TERR, CEIL, SPAWN_Z, SPAWN_Z + 2),
    # Fare gates: a line of half cover with three wide gaps; the ticket office is full cover.
    B("FareGates", "Concourse", -30, -10, TERR, TERR + 3.5, 82, 83.5, "low"),
    B("FareGates", "Concourse", 10, 30, TERR, TERR + 3.5, 82, 83.5, "low"),
    B("TicketOffice", "Concourse", -OUT_X, -38, TERR, TERR + 10, 88, SPAWN_Z, "cover"),
    # Spawn room: two 8-wide doors either side of a 12-wide baffle wall.
    B("SpawnFloor", "Spawn", -16, 16, TERR - 1, TERR, SPAWN_Z, SPAWN_Z + 20, "floor"),
    B("SpawnWall", "Spawn", -16, -14, TERR, CEIL, SPAWN_Z + 1, SPAWN_Z + 20),
    B("SpawnWall", "Spawn", 14, 16, TERR, CEIL, SPAWN_Z + 1, SPAWN_Z + 20),
    B("SpawnWall", "Spawn", -16, 16, TERR, CEIL, SPAWN_Z + 20, SPAWN_Z + 22),
    B("SpawnBaffle", "Spawn", -6, 6, TERR, CEIL, SPAWN_Z, SPAWN_Z + 1),
    B("SpawnLintel", "Spawn", -14, -6, TERR + 10, CEIL, SPAWN_Z, SPAWN_Z + 1),
    B("SpawnLintel", "Spawn", 6, 14, TERR + 10, CEIL, SPAWN_Z, SPAWN_Z + 1),
    # --- Hall cover, team B's half: a row of columns down each platform, one kiosk each.
    B("Column", "Hall", 22, 26, PLAT, CEIL, 22, 26, "cover"),
    B("Column", "Hall", 22, 26, PLAT, CEIL, 38, 42, "cover"),
    B("Kiosk", "Hall", 21, 27, PLAT, 10, 5, 11, "cover"),
    B("Vending", "Hall", 32, PLAT_X, PLAT, 8, 15, 21, "cover"),
    B("Column", "Hall", -26, -22, PLAT, CEIL, 6, 10, "cover"),
    B("Column", "Hall", -26, -22, PLAT, CEIL, 22, 26, "cover"),
    B("Column", "Hall", -26, -22, PLAT, CEIL, 38, 42, "cover"),
    B("Bench", "Hall", -PLAT_X, -32, PLAT, 3, 13, 19, "low"),
    B("TrackBox", "Hall", -TRENCH_X, -11, TRENCH, -0.5, 28, 34, "low"),
]

HALF_RAMPS: list = [
    # Escalator bank (two escalators and a fixed stair), sunk in a well in the terrace: you
    # come down out of sight. Top in the ticket hall, bottom on the east platform.
    Ramp("Escalator", "Concourse", ESC_X, PLAT_X, PLAT, TERR, HALL_Z, 72, +1),
    # Fixed stairs out into the hall on the west platform: the visible way down.
    Ramp("HallStairs", "Hall", -22, -TRENCH_X, PLAT, TERR, 26, HALL_Z, +1),
    # The service corridor's stair up to the ticket hall (team B's flank route).
    Ramp("CorridorStair", "Corridor", WALL_X, OUT_X, PLAT, TERR, HALL_Z, 72, +1),
]

HALF += train_blocks(TRAIN)

BLOCKS: list = CENTER + HALF + [b.rotated() for b in HALF]
RAMPS: list = HALF_RAMPS + [r.rotated() for r in HALF_RAMPS]

SPAWNS_B = [(-3.0, SPAWN_Z + 5), (3.0, SPAWN_Z + 5), (-3.0, SPAWN_Z + 10), (3.0, SPAWN_Z + 10)]
SPAWNS_A = [(-x, -z) for x, z in SPAWNS_B]
BARRIERS_B = [
    B("Barrier", "Barriers", -14, -6, TERR, TERR + 10, SPAWN_Z, SPAWN_Z + 1),
    B("Barrier", "Barriers", 6, 14, TERR, TERR + 10, SPAWN_Z, SPAWN_Z + 1),
]

# Places, for routes and labels (team B's half; A's are rotated).
WAYPOINTS = {
    "west platform": (-24.0, 0.0),
    "trench (mid)": (0.0, 0.0),
    "east platform": (24.0, 0.0),
    "train (inside)": (8.5, 20.0),
    "east corridor": (42.0, 0.0),
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
        solid[ix(b.x0) : ix(b.x1), iz(b.z0) : iz(b.z1), iy(b.y0) : iy(b.y1)] = True
    for r in RAMPS:
        for k in range(iz(r.z0), iz(r.z1)):
            zc = ZMIN + (k + 0.5) * R
            h = r.height(zc)
            solid[ix(r.x0) : ix(r.x1), k, iy(r.y0 - 1) : iy(h + 0.25)] = True
    return solid


# ------------------------------------------------------------------ navigation

STEP = 2  # nodes every 2 voxels (1 stud)
H = int(round(BODY / R))


def erode_xz(free, rad):
    """Body clearance: a column is free only if every column within `rad` voxels is free."""
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
    """run[..., k] = how many voxels of air start at k (upward)."""
    run = np.zeros(air.shape, dtype=np.int16)
    run[:, :, -1] = air[:, :, -1]
    for k in range(NY - 2, -1, -1):
        run[:, :, k] = np.where(air[:, :, k], run[:, :, k + 1] + 1, 0)
    return run


def build_nodes(solid):
    """Standing spots: solid below, and a body-wide (1-stud radius) clear column from 1 stud up
    to 5.5 (the feet may sit on a slope or a small step)."""
    body = air_run(erode_xz(~solid, 2))
    raw = air_run(~solid)
    lift = 2
    under = np.concatenate([np.zeros((NX, NZ, 1), bool), solid[:, :, :-1]], axis=2)
    upper = np.concatenate([body[:, :, lift:], np.zeros((NX, NZ, lift), np.int16)], axis=2)
    stand = under & (raw >= lift) & (upper >= H - lift)
    run = raw
    nodes = {}
    for a in range(0, NX, STEP):
        for c in range(0, NZ, STEP):
            ks = np.nonzero(stand[a, c])[0]
            if len(ks):
                FLOORS[(a, c)] = [int(k) for k in ks]
            for k in ks:
                nodes[(a, c, int(k))] = len(nodes)
    return nodes, run


FLOORS: dict = {}  # (a, c) -> standing voxel heights in that column


def node_xyz(key):
    a, c, k = key
    return XMIN + (a + 0.5) * R, YMIN + k * R, ZMIN + (c + 0.5) * R


RING1 = [(da, dc) for da in (-STEP, 0, STEP) for dc in (-STEP, 0, STEP) if da or dc]
RING2 = [(da, dc) for da in range(-2 * STEP, 2 * STEP + 1, STEP) for dc in range(-2 * STEP, 2 * STEP + 1, STEP)
         if max(abs(da), abs(dc)) == 2 * STEP]


def neighbours(nodes, run, key):
    """Walk/step to the 8 neighbours; jump up or drop down to a floor up to 2 studs away (a
    ledge: standing spots keep 1 stud from walls, so the two floors are never adjacent)."""
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
                    continue  # level moves only
                ma, mc = a + da // 2, c + dc // 2
                if run[ma, mc][hi] < H:
                    continue  # something in the way between
            if nk < k and col[lo] < (hi - lo) + H:
                continue  # a ceiling over the lower floor
            if nk > k and run[a, c][k] < (nk - k) + H:
                continue  # no headroom to jump
            dist = math.hypot(da, dc) * R
            rise = (nk - k) * R
            cost = dist + (4.0 if rise > 1.2 else 0.0)  # a jump costs about 0.2 s
            yield (na, nc, nk), cost


def dijkstra(nodes, run, starts):
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
        for nxt, cost in neighbours(nodes, run, cur):
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

def visible_list(solid, A, B, step=0.75, chunk=6000):
    """A, B: (k,3) eye points, paired row by row. Returns (k,) bool: the line is clear."""
    out = np.zeros(len(A), dtype=bool)
    for s in range(0, len(A), chunk):
        p, q = A[s : s + chunk], B[s : s + chunk]
        L = np.linalg.norm(q - p, axis=1)
        S = max(2, int(L.max() / step) + 1)
        t = np.linspace(0.0, 1.0, S)[None, :, None]
        pts = p[:, None, :] + (q - p)[:, None, :] * t
        gx = np.clip(((pts[..., 0] - XMIN) / R).astype(np.int32), 0, NX - 1)
        gy = np.clip(((pts[..., 1] - YMIN) / R).astype(np.int32), 0, NY - 1)
        gz = np.clip(((pts[..., 2] - ZMIN) / R).astype(np.int32), 0, NZ - 1)
        out[s : s + chunk] = ~solid[gx, gz, gy].any(axis=1)
    return out


def visible_pairs(solid, A, B):
    """A: (n,3), B: (m,3) eye points. Returns an (n,m) bool matrix of clear lines."""
    n, m = len(A), len(B)
    if n == 0 or m == 0:
        return np.zeros((n, m), dtype=bool)
    pa = np.repeat(np.arange(n), m)
    pb = np.tile(np.arange(m), n)
    return visible_list(solid, A[pa], B[pb]).reshape(n, m)


def rays(solid, P, dirs, maxd=240.0, step=0.5):
    """Horizontal eye-level rays. Returns lengths (n, len(dirs))."""
    out = np.zeros((len(P), len(dirs)))
    d = np.arange(step, maxd, step)
    for j, (dx, dz) in enumerate(dirs):
        x = P[:, 0:1] + dx * d[None, :]
        z = P[:, 2:3] + dz * d[None, :]
        y = np.repeat(P[:, 1:2], len(d), axis=1)
        gx = np.clip(((x - XMIN) / R).astype(np.int32), 0, NX - 1)
        gy = np.clip(((y - YMIN) / R).astype(np.int32), 0, NY - 1)
        gz = np.clip(((z - ZMIN) / R).astype(np.int32), 0, NZ - 1)
        hit = solid[gx, gz, gy]
        first = np.where(hit.any(axis=1), hit.argmax(axis=1), len(d) - 1)
        out[:, j] = d[first]
    return out


# ------------------------------------------------------------------ checks

def region(x, y, z):
    """A callout for a point (x, floor y, z)."""
    side = "B" if z > 0 else "A"
    if abs(x) > WALL_X:
        return ("east" if x > 0 else "west") + " corridor"
    if abs(z) > SPAWN_Z and y >= TERR - 1:
        return f"{side} spawn"
    if y >= TERR - 1 and abs(z) > HALL_Z:
        return f"{side} terrace" if abs(z) < TICKET_Z - 2 and abs(x) < PLAT_X else f"{side} concourse"
    if abs(z) > HALL_Z:
        return f"{side} escalators" if abs(x) >= ESC_X else "trench"
    if y > 0.5 and TRENCH_X <= abs(x) <= 22:
        return f"{'A' if x > 0 else 'B'} stairs"
    if y >= TRAIN["roof"] and abs(x) < TRENCH_X:
        return "train roof"
    if abs(x) < TRENCH_X and y < -1:
        return "trench"
    if abs(x) < TRENCH_X:
        return "train"
    return ("east" if x > 0 else "west") + " platform"


def gap_report():
    print("\nGaps under 6 studs between blocks that stand on the same floor (0 = touching):")
    items = [b for b in BLOCKS if b.kind in ("cover", "low") and b.section != "Spawn"]
    walls = [b for b in BLOCKS if b.kind in ("wall", "train", "cover", "low") or b.section == "Spawn"]
    shown = set()
    for a in items:
        for b in walls:
            if a is b or (abs(a.cx) > WALL_X) != (abs(b.cx) > WALL_X and b.kind != "wall"):
                continue
            if a.y0 >= b.y1 or b.y0 >= a.y1 or abs(a.y0 - b.y0) > 1.5 and b.y0 > a.y0:
                continue
            if b.kind == "wall" and b.y0 >= 10 and b.y0 > a.y0 - 1.5 or b.kind == "wall" and b.y0 >= 10 and a.y0 >= TERR:
                continue  # a lintel over a door below, not a wall at this floor
            gx = max(0.0, max(a.x0, b.x0) - min(a.x1, b.x1))
            gz = max(0.0, max(a.z0, b.z0) - min(a.z1, b.z1))
            g = math.hypot(gx, gz) if gx and gz else max(gx, gz)
            if 0 < g < 6:
                key = tuple(sorted([(a.name, round(a.cx), round(a.cz)), (b.name, round(b.cx), round(b.cz))]))
                if key in shown:
                    continue
                shown.add(key)
                print(f"  {a.name} ({a.cx:.0f},{a.cz:.0f}) - {b.name} ({b.cx:.0f},{b.cz:.0f}): {g:.1f}")
    if not shown:
        print("  none")


def report():
    solid = voxelise()
    print(f"Blocks: {len(BLOCKS)} boxes, {len(RAMPS)} ramps; grid {NX}x{NZ}x{NY} voxels")
    nodes, run = build_nodes(solid)
    print(f"Standing spots: {len(nodes)}")

    gap_report()

    sa = [nearest_node(nodes, x, z, TERR) for x, z in SPAWNS_A]
    sb = [nearest_node(nodes, x, z, TERR) for x, z in SPAWNS_B]
    assert all(sa) and all(sb), "a spawn is not on a floor"
    dA = dijkstra(nodes, run, sa)
    dB = dijkstra(nodes, run, sb)
    keys = list(nodes)
    reach = sum(1 for k in keys if k in dA)
    print(f"\nReachable from spawn A: {100 * reach / len(keys):.1f}% of standing spots")
    leaks = [k for k in dA if not (-OUT_X < node_xyz(k)[0] < OUT_X and -SPAWN_Z - 20 < node_xyz(k)[2] < SPAWN_Z + 20 and node_xyz(k)[1] < CEIL)]
    print(f"Sealed (no walkable spot outside the shell or above the ceiling): {not leaks}")

    print("\nRoute times from the A spawns (sprint 22 / walk 16 studs/s):")
    routes = {}
    target_b = min(sb, key=lambda k: dA.get(k, math.inf))
    for name, (x, z) in WAYPOINTS.items():
        for label, (px, pz) in ((name, (-x, -z)),):
            wp = nearest_node(nodes, px, pz, PLAT if "trench" not in name else TRENCH)
            if wp is None or wp not in dA:
                print(f"  via {label}: NO ROUTE")
                continue
            # spawn A -> waypoint -> nearest B spawn
            total = dA[wp] + dB.get(wp, math.inf)
            routes[label] = total
            print(f"  to {label:16s} {dA[wp] / SPRINT:4.1f} s   spawn-to-spawn through it {total:5.0f} studs = {total / SPRINT:4.1f} s sprint, {total / WALK:4.1f} s walk")
    direct = dA.get(target_b)
    print(f"  shortest spawn to spawn: {direct:.0f} studs = {direct / SPRINT:.1f} s sprint, {direct / WALK:.1f} s walk")

    # Earliest meeting: the first moment both teams can stand on the same spot.
    meet = min(max(dA[k], dB[k]) for k in keys if k in dA and k in dB)
    print(f"Earliest contact (both teams on one spot): {meet / SPRINT:.1f} s sprint, {meet / WALK:.1f} s walk")

    # Vision nodes: every 4 studs.
    V = [k for k in keys if k[0] % 8 == 0 and k[1] % 8 == 0 and k in dA and k in dB]
    P = np.array([node_xyz(k) for k in V])
    P[:, 1] += EYE
    vA = np.array([dA[k] for k in V])
    vB = np.array([dB[k] for k in V])

    # First sight: smallest D such that someone within D of spawn A sees someone within D of spawn B.
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
        print(
            f"First sight ({label}): {hi / SPRINT:.1f} s sprint, {hi / WALK:.1f} s walk  "
            f"({region(pa[0], pa[1] - EYE, pa[2])} ({pa[0]:.0f},{pa[2]:.0f}) sees "
            f"{region(pb[0], pb[1] - EYE, pb[2])} ({pb[0]:.0f},{pb[2]:.0f}), {np.linalg.norm(pb - pa):.0f} studs)"
        )

    print("\nSpawn safety:")
    eyesA = np.array([[x, TERR + EYE, z] for x, z in SPAWNS_A])
    eyesB = np.array([[x, TERR + EYE, z] for x, z in SPAWNS_B])
    print("  any spawn A sees any spawn B:", bool(visible_pairs(solid, eyesA, eyesB).any()))
    half = np.nonzero(P[:, 2] < 0)[0]
    sees = visible_pairs(solid, P[half], eyesB).any(axis=1)
    print(f"  team A's half that can see a B spawn point: {100 * sees.mean():.1f}%")
    outside = np.nonzero(P[:, 2] < SPAWN_Z)[0]
    sees = visible_pairs(solid, P[outside], eyesB).any(axis=1)
    print(f"  anywhere outside the B spawn room that sees a B spawn point: {100 * sees.mean():.1f}% (should be the ticket hall only)")
    if sees.any():
        far = outside[np.nonzero(sees)[0]]
        print(f"    furthest such spot: z = {P[far, 2].min():.0f}")

    print("\nLong sightlines (eye to eye between standing spots in the hall, on the terraces and train roofs):")
    hv = np.nonzero((np.abs(P[:, 2]) < TICKET_Z - 2) & (np.abs(P[:, 0]) < WALL_X))[0]
    ii, jj = np.triu_indices(len(hv), 1)
    dd = np.linalg.norm(P[hv[ii]] - P[hv[jj]], axis=1)
    far = dd > 70
    ii, jj, dd = ii[far], jj[far], dd[far]
    vis = visible_list(solid, P[hv[ii]], P[hv[jj]])
    print(f"  pairs over 70 studs apart that see each other: {100 * vis.mean():.1f}%; "
          f"over 100 apart: {100 * vis[dd > 100].mean():.1f}%")
    order = np.argsort(-dd * vis)
    longest, shown = [], []
    for o in order:
        if not vis[o]:
            break
        a, b = P[hv[ii[o]]], P[hv[jj[o]]]
        dup = False
        for s0, s1 in shown:
            if (np.linalg.norm(a - s0) < 16 and np.linalg.norm(b - s1) < 16) or (
                np.linalg.norm(a - s1) < 16 and np.linalg.norm(b - s0) < 16
            ):
                dup = True
        if dup:
            continue
        shown.append((a, b))
        longest.append((dd[o], (a[0], a[2]), (b[0], b[2]), 0))
        print(f"  {dd[o]:4.0f} studs  {region(a[0], a[1] - EYE, a[2])} ({a[0]:.0f},{a[2]:.0f}) <-> "
              f"{region(b[0], b[1] - EYE, b[2])} ({b[0]:.0f},{b[2]:.0f})")
        if len(longest) == 6:
            break

    print("\nTerrace perch (team B's terrace front looking into the hall):")
    perch = np.nonzero((P[:, 2] > HALL_Z) & (P[:, 2] < 54) & (np.abs(P[:, 0]) < 22) & (P[:, 1] > TERR + 1))[0]
    floor = np.nonzero((np.abs(P[:, 2]) < HALL_Z) & (P[:, 1] < TERR) & (np.abs(P[:, 0]) < PLAT_X))[0]
    vis = visible_pairs(solid, P[perch], P[floor])
    seen_floor = vis.any(axis=0)
    zs = P[floor, 2]
    print(f"  hall floor seen from the B terrace: {100 * seen_floor.mean():.0f}% "
          f"(own half {100 * seen_floor[zs > 0].mean():.0f}%, enemy half {100 * seen_floor[zs < 0].mean():.0f}%)")
    if seen_floor[zs < 0].any():
        far = floor[np.nonzero(seen_floor & (zs < 0))[0]]
        dmax = max(np.linalg.norm(P[f] - P[perch].mean(axis=0)) for f in far)
        print(f"  furthest enemy-half spot it sees: z = {P[far, 2].min():.0f}, about {dmax:.0f} studs")
    terraceA = np.nonzero((P[:, 2] < -HALL_Z) & (P[:, 2] > -72) & (P[:, 1] > TERR + 1))[0]
    print("  B terrace sees A terrace:", bool(visible_pairs(solid, P[perch], P[terraceA]).any()))

    print("\nCover spread (hall floor, distance to the nearest full cover that stands on your floor):")
    full = [b for b in BLOCKS if b.kind in ("cover", "train") and b.y1 - b.y0 >= 7]
    full += [r for r in RAMPS]
    worst, worst_at, dists = 0.0, None, []
    for k in keys:
        x, y, z = node_xyz(k)
        if abs(z) >= HALL_Z or abs(x) >= PLAT_X or y > 1 or k not in dA:
            continue
        d = min(max(0.0, max(b.x0 - x, x - b.x1), 0) ** 2 + max(0.0, max(b.z0 - z, z - b.z1)) ** 2 for b in full) ** 0.5
        if y < -1:  # the trench walls are full cover for anyone in the trench
            d = min(d, TRENCH_X - abs(x))
        dists.append(d)
        if d > worst:
            worst, worst_at = d, (x, z)
    print(f"  average {sum(dists) / len(dists):.1f}, furthest {worst:.1f} at ({worst_at[0]:.0f},{worst_at[1]:.0f})")

    print("\nHeights: trench -4, platforms 0, train roof 10, terraces 14, ceilings 28 (corridors 12)")
    return {"first": first, "longest": longest, "meet": meet, "direct": direct, "routes": routes}


# ------------------------------------------------------------------ SVG

FILL = {
    "floor": "#C8CCD6",
    "cover": "#5C6273",
    "low": "#9AA0B2",
    "train": "#B8BEC9",
    "wall": "#3A3F4C",
    "gantry": "#F0A830",
}
LEVEL = {-4: "#3B4150", 0: "#D9DCE3", 14: "#EEF0F4"}


def svg(res) -> str:
    sc = 3.6
    pad = 50
    W = (XMAX - XMIN) * sc + 2 * pad + 300
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
        f'<rect width="{W:.0f}" height="{Hh:.0f}" fill="#1B1E26"/>',
    ]
    # Floors by level: platforms and corridors, then the trench, then the concourse.
    def both(x0, x1, z0, z1):
        return [(x0, x1, z0, z1), (-x1, -x0, -z1, -z0)]

    floors = [(-PLAT_X, PLAT_X, -HALL_Z, HALL_Z, 0), (WALL_X, OUT_X, -HALL_Z, HALL_Z, 0), (-OUT_X, -WALL_X, -HALL_Z, HALL_Z, 0)]
    floors += [(-TRENCH_X, TRENCH_X, -51, 51, -4)]
    for q in both(-OUT_X, ESC_X - 1, HALL_Z, 72) + both(-OUT_X, OUT_X, 72, SPAWN_Z) + both(-14, 14, SPAWN_Z, SPAWN_Z + 20):
        floors.append((*q, 14))
    for x0, x1, z0, z1, lv in floors:
        out.append(rect(x0, x1, z0, z1, LEVEL[lv]))
    # Door gaps in the hall wall
    for b in BLOCKS:
        if b.kind in ("floor", "ceiling") or b.section == "Shell":
            continue
        if b.y0 >= 10 and ("Lintel" in b.name or "Head" in b.name or b.name == "HallWallEast"):
            continue  # lintels over doors
        if b.kind == "gantry":
            continue
        if b.section == "Train" and b.name not in ("EndCab", "EndRear", "Gangway"):
            continue
        out.append(rect(b.x0, b.x1, b.z0, b.z1, FILL.get(b.kind, "#555"), "#20232C", 0.6))
    # Trains: a body with door marks
    for sign in (1, -1):
        t = TRAIN
        x0, x1 = (t["x0"], t["x1"]) if sign > 0 else (-t["x1"], -t["x0"])
        z0, z1 = (t["z0"], t["z1"]) if sign > 0 else (-t["z1"], -t["z0"])
        out.append(rect(x0, x1, z0, z1, FILL["train"], "#596070", 1.2, 'rx="4"'))
    for b in BLOCKS:
        if b.section == "Train" and b.name.startswith("DoorPost"):
            out.append(rect(b.x0, b.x1, b.z0, b.z1, "#596070"))
    # Ramps with an arrow pointing up-slope
    for r in RAMPS:
        out.append(rect(r.x0, r.x1, r.z0, r.z1, "#A9B4CC", "#596070", 1))
        n = int((r.z1 - r.z0) / 2)
        for i in range(1, n):
            z = r.z0 + i * (r.z1 - r.z0) / n
            a, b = p(r.x0, z), p(r.x1, z)
            out.append(f'<line x1="{a[0]:.1f}" y1="{a[1]:.1f}" x2="{b[0]:.1f}" y2="{b[1]:.1f}" stroke="#7D879E" stroke-width="0.8"/>')
        cx = (r.x0 + r.x1) / 2
        za, zb = (r.z0 + 3, r.z1 - 3) if r.up > 0 else (r.z1 - 3, r.z0 + 3)
        a, b = p(cx, za), p(cx, zb)
        out.append(f'<line x1="{a[0]:.1f}" y1="{a[1]:.1f}" x2="{b[0]:.1f}" y2="{b[1]:.1f}" stroke="#2F3545" stroke-width="2" marker-end="url(#up)"/>')
    out.insert(2, '<defs><marker id="up" markerWidth="8" markerHeight="8" refX="4" refY="4" orient="auto">'
                  '<path d="M0,0 L8,4 L0,8 z" fill="#2F3545"/></marker></defs>')
    # Gantry (overhead)
    g = [b for b in BLOCKS if b.kind == "gantry"][0]
    out.append(rect(g.x0, g.x1, g.z0, g.z1, "none", FILL["gantry"], 2, 'stroke-dasharray="6 4"'))
    # End colours: B (+Z) blue, A (-Z) yellow
    for sign, colour, label in ((1, "#3D6FD6", "B · BLUE END"), (-1, "#D9A520", "A · YELLOW END")):
        a, b = p(-OUT_X, sign * (SPAWN_Z + 22)), p(OUT_X, sign * (SPAWN_Z + 22))
        out.append(f'<line x1="{a[0]:.1f}" y1="{a[1]:.1f}" x2="{b[0]:.1f}" y2="{b[1]:.1f}" stroke="{colour}" stroke-width="6"/>')
        t = p(0, sign * (SPAWN_Z + 24))
        out.append(f'<text x="{t[0]:.1f}" y="{t[1] + (0 if sign > 0 else 10):.1f}" text-anchor="middle" font-size="13" font-weight="700" fill="{colour}">{label}</text>')
    # Longest sightline and first sight
    if res["longest"]:
        _, a, b, _ = res["longest"][0]
        pa, pb = p(*a), p(*b)
        out.append(f'<line x1="{pa[0]:.1f}" y1="{pa[1]:.1f}" x2="{pb[0]:.1f}" y2="{pb[1]:.1f}" stroke="#D1495B" stroke-width="2" stroke-dasharray="7 5"/>')
    _, fa, fb = res["first"]
    pa, pb = p(fa[0], fa[2]), p(fb[0], fb[2])
    out.append(f'<line x1="{pa[0]:.1f}" y1="{pa[1]:.1f}" x2="{pb[0]:.1f}" y2="{pb[1]:.1f}" stroke="#3DDC84" stroke-width="2" stroke-dasharray="3 3"/>')
    for spawns, colour in ((SPAWNS_B, "#3D6FD6"), (SPAWNS_A, "#D9A520")):
        for x, z in spawns:
            c = p(x, z)
            out.append(f'<circle cx="{c[0]:.1f}" cy="{c[1]:.1f}" r="5" fill="{colour}"/>')
    labels = {
        (0, 25): ("Trench", "#E8EAF0"),
        (23, 36): ("East platform", "#2A2F3C"),
        (-23, -36): ("West platform", "#2A2F3C"),
        (8.5, 10): ("Train B", "#2A2F3C"),
        (-8.5, -10): ("Train A", "#2A2F3C"),
        (0, 5): ("Departures", "#B87A10"),
        (-12, 60): ("B Terrace", "#2A2F3C"),
        (12, -60): ("A Terrace", "#2A2F3C"),
        (0, 86): ("Fare gates", "#2A2F3C"),
        (0, -86): ("Fare gates", "#2A2F3C"),
        (0, SPAWN_Z + 15): ("B Spawn", "#2A2F3C"),
        (0, -SPAWN_Z - 15): ("A Spawn", "#2A2F3C"),
        (27.5, 60): ("Escalators", "#2A2F3C"),
        (-27.5, -60): ("Escalators", "#2A2F3C"),
        (-18, 38): ("Stairs", "#2A2F3C"),
        (18, -38): ("Stairs", "#2A2F3C"),
        (42, 0): ("Service corridor", "#2A2F3C"),
        (-42, 0): ("Service corridor", "#2A2F3C"),
        (42, 60): ("Stair", "#2A2F3C"),
        (-42, -60): ("Stair", "#2A2F3C"),
        (0, 46): ("name panel above", "#9AA3B8"),
        (0, -46): ("name panel above", "#9AA3B8"),
        (-43, SPAWN_Z - 6): ("Ticket office", "#E8EAF0"),
        (43, -SPAWN_Z + 6): ("Ticket office", "#E8EAF0"),
    }
    for (x, z), (text, colour) in labels.items():
        t = p(x, z)
        rot = f' transform="rotate(-90 {t[0]:.1f} {t[1]:.1f})"' if text in ("Service corridor", "Stair", "Stairs", "Escalators", "Train A", "Train B", "Ticket office") else ""
        out.append(f'<text x="{t[0]:.1f}" y="{t[1] + 4:.1f}" text-anchor="middle" font-size="11" font-weight="600" fill="{colour}"{rot}>{text}</text>')

    kx = pad + (XMAX - XMIN) * sc + 30
    y = pad + 10
    out.append(f'<text x="{kx:.0f}" y="{y}" font-size="26" font-weight="700" fill="#F4F5F9">Metro</text>')
    y += 22
    out.append(f'<text x="{kx:.0f}" y="{y}" font-size="13" fill="#B9BDCB">Layout, 180° rotation · 2v2-4v4</text>')
    y += 34
    rows = [
        (LEVEL[14], "Concourse level, +14"),
        (LEVEL[0], "Platforms + corridors, 0"),
        (LEVEL[-4], "Track trench, −4"),
        (FILL["train"], "Train (doors, windows, roof +10)"),
        ("#A9B4CC", "Stairs / escalators (arrow = up)"),
        (FILL["cover"], "Full cover"),
        (FILL["low"], "Half cover (3–3.5)"),
        (FILL["wall"], "Walls"),
    ]
    for colour, text in rows:
        out.append(f'<rect x="{kx:.0f}" y="{y}" width="18" height="18" fill="{colour}" stroke="#596070"/>')
        out.append(f'<text x="{kx + 28:.0f}" y="{y + 14}" font-size="13" fill="#F4F5F9">{text}</text>')
        y += 26
    out.append(f'<rect x="{kx:.0f}" y="{y}" width="18" height="18" fill="none" stroke="{FILL["gantry"]}" stroke-width="2" stroke-dasharray="4 3"/>')
    out.append(f'<text x="{kx + 28:.0f}" y="{y + 14}" font-size="13" fill="#F4F5F9">Departure gantry (overhead, 11+)</text>')
    y += 26
    out.append(f'<line x1="{kx:.0f}" y1="{y + 9}" x2="{kx + 18:.0f}" y2="{y + 9}" stroke="#D1495B" stroke-width="2" stroke-dasharray="7 5"/>')
    out.append(f'<text x="{kx + 28:.0f}" y="{y + 14}" font-size="13" fill="#F4F5F9">Longest eye-level line, {res["longest"][0][0]:.0f}</text>')
    y += 26
    out.append(f'<line x1="{kx:.0f}" y1="{y + 9}" x2="{kx + 18:.0f}" y2="{y + 9}" stroke="#3DDC84" stroke-width="2" stroke-dasharray="3 3"/>')
    D = res["first"][0]
    out.append(f'<text x="{kx + 28:.0f}" y="{y + 14}" font-size="13" fill="#F4F5F9">First sight, {D / SPRINT:.1f} s sprint</text>')
    y += 40
    facts = [
        f"Spawn to spawn: {res['direct']:.0f} studs",
        f"  {res['direct'] / SPRINT:.1f} s sprint, {res['direct'] / WALK:.1f} s walk",
        f"First sight: {D / SPRINT:.1f} s sprint, {D / WALK:.1f} s walk",
        f"First contact: {res['meet'] / SPRINT:.1f} s sprint, {res['meet'] / WALK:.1f} s walk",
        f"Map 100 × {2 * SPAWN_Z + 16:.0f}, hall 68 × 96 × 28 tall",
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
    "ceiling": "6E727C",
    "cover": "6B7286",
    "low": "A3A9B8",
    "train": "C5CAD3",
    "gantry": "D9A13A",
    "ramp": "AEB5C6",
}


def luau() -> str:
    def num(v):
        return f"{v:g}"

    lines = [
        "--!strict",
        "-- Metro greybox: GENERATED by tools/maps/metro_layout.py --luau. Edit the layout there",
        "-- (the checks run on the same numbers), then regenerate and re-run this in the match place:",
        "--   python tools/studio/maps/bundle.py Metro Greybox -o metro_greybox.luau",
        "-- Map space (MapKit.luau): origin on the platform floor at the hall centre, +Z = team B's",
        "-- (blue) end. Every part here is collision; Art.luau hides the ones the kit replaces.",
        "",
        'newMap("Metro", CFrame.new(1500, 200, 0))',
        'local CollectionServiceM = game:GetService("CollectionService")',
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
        "\tceiling = Enum.Material.Concrete,",
        "\tcover = Enum.Material.SmoothPlastic,",
        "\tlow = Enum.Material.SmoothPlastic,",
        "\ttrain = Enum.Material.Metal,",
        "\tgantry = Enum.Material.SmoothPlastic,",
        "\tramp = Enum.Material.Concrete,",
        "}",
        "",
        "-- { section, name, kind, x0, x1, y0, y1, z0, z1 } boxes, both halves written out.",
        "local BOXES: { { any } } = {",
    ]
    for b in BLOCKS:
        lines.append(
            f'\t{{ "{b.section}", "{b.name}", "{b.kind}", {num(b.x0)}, {num(b.x1)}, {num(b.y0)}, {num(b.y1)}, {num(b.z0)}, {num(b.z1)} }},'
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
        "\t\tcastShadow = not small and kind ~= \"ceiling\",",
        "\t})",
        "\tp:SetAttribute(\"Kind\", kind)",
        "\t-- Train side sheets: guns with ThinWall penetration shoot through them (Config/Combat).",
        "\tlocal name = s[2] :: string",
        "\tif kind == \"train\" and (string.sub(name, 1, 5) == \"Lower\" or string.sub(name, 1, 5) == \"Upper\") then",
        "\t\tCollectionServiceM:AddTag(p, \"ThinWall\")",
        "\tend",
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
        "\tp:SetAttribute(\"Kind\", \"ramp\")",
        "\tcount += 1",
        "end",
        "",
        "spawnsClear()",
        "for _, s in SPAWNS do",
        "\tspawnPad(s[1] :: string, s[2] :: number, at(s[3] :: number, " + num(TERR) + ", s[4] :: number, if s[1] == \"A\" then 180 else 0))",
        "end",
        "for i, b in BARRIERS do",
        "\tbarrier(\"Barrier\" .. i, Vector3.new(b[2] - b[1], b[4] - b[3], b[6] - b[5]), at((b[1] + b[2]) / 2, (b[3] + b[4]) / 2, (b[5] + b[6]) / 2))",
        "end",
        "",
        'report(string.format("Metro greybox: %d parts, %d spawns, %d barriers", count, #SPAWNS, #BARRIERS))',
        "",
    ]
    return "\n".join(lines)


if __name__ == "__main__":
    res = report()
    SVG_OUT.parent.mkdir(parents=True, exist_ok=True)
    SVG_OUT.write_text(svg(res), encoding="utf-8")
    print(f"\nWrote {SVG_OUT}")
    if "--luau" in sys.argv:
        LUAU_OUT.parent.mkdir(parents=True, exist_ok=True)
        LUAU_OUT.write_text(luau(), encoding="utf-8")
        print(f"Wrote {LUAU_OUT}")
