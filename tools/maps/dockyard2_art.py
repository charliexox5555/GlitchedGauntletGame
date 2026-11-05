#!/usr/bin/env python3
"""Dockyard2 art placements: every kit piece and art Part the art pass puts down, as data.
(Adapted from tools/maps/dockyard_art.py; the old map's file is untouched.)

One source of truth for three users:
  - tools/maps/dockyard2_layout.py --luau writes it into the ART block of
    tools/studio/maps/Dockyard2/Art.luau (what Studio places),
  - tools/blender/build_map_kit_dockyard2.py assembles the same list for its previews,
  - this file's own __main__ prints a summary.
Colours are roles, not hex: `lane` is a LANE key ("west" / "mid" / "east") or "bd<n>" (BACKDROP[n]) and
art Parts carry a PALETTE role, so Studio applies tools/maps/dockyard2_style.py at build time.

Map space (MapKit.luau): studs, origin on the deck at the map centre, +X across, +Z along, +Y up.
yaw is CFrame.Angles(0, rad(yaw), 0). Deterministic: the same seed gives the same colours.

Surface rules (vault/01 Design/Maps/00 Maps.md, "No z-fighting"):
  - paint on the deck sits 0.03-0.05 above it and no two lines overlap in one plane (cut, not crossed),
  - stacked boxes keep a 0.03 hairline gap, nothing shares a face plane with a neighbour it overlaps,
  - props on the quay wall sink into it (their bases are inside the wall, not on its paint).
"""

from __future__ import annotations

import math
import random
from dataclasses import dataclass, field

import dockyard2_layout as L
import dockyard2_style as S

SEED = 20261105

SHORT = 3.7  # the short quay wall segment (QuayBarrierShort) that finishes a run
STACK = 8.03  # container pitch in a stack: 8 tall + a 0.03 hairline gap
PROP_SINK = 0.1  # bollards and lamp masts stand this far into the quay wall top (3.0)
WALL_TOP = 3.0
LINE_Y0, LINE_Y1 = 0.03, 0.05  # deck paint
LINE_W = 0.5
SHED_FOOT = (42.0, 68.0, 24.0, 60.0)  # B Shed footprint (x0, x1, z0, z1); the A one is rotated
MASTS = ((-67, 40), (67, 84), (67, -40), (-67, -84))

# Skyline (east set; the west set is it rotated).
SKY_CRANES = ((158, 60, 180), (158, -12, 180))
SHIP = (108, 20)
SHIP_BAYS = (-50, -16, 18)
SHIP_ROWS = (-12, -4, 4, 12)
SHIP_HEIGHTS = ((2, 3, 3, 2), (3, 2, 3, 3), (2, 3, 2, 1))
SHIP_DECK = 9.4  # hatch-cover top in map space (waterline -9 + 18.4)
FAR_STACKS = ((190, -120, 2), (190, -86, 3), (222, -120, 1), (222, 100, 2), (190, 120, 3), (254, 40, 2))

# End walls (B end; the A end is it rotated): container faces toward the yard and the alcove, 7 high.
END_FACES = (
    (-51.3, 96, "C40", 90),  # stops 0.7 short of the deck edge, clear of the quay coping
    (-31, 100, "C20", 0),
    (-22, 102, "C20", 0),
    (51.3, 96, "C40", 90),
    (31, 100, "C20", 0),
    (22, 102, "C20", 0),
    (0, 114, "C40", 90),
)


@dataclass
class Put:
    piece: str
    x: float
    y: float
    z: float
    yaw: float = 0.0
    lane: str | None = None  # LANE key or bd<n>
    sec: str = "Yard"
    own: list[int] = field(default_factory=list)  # 1-based LAYOUT ids this placement dresses


@dataclass
class Part:
    name: str
    sec: str
    size: tuple[float, float, float]
    pos: tuple[float, float, float]
    role: str
    reflectance: float = 0.0
    shadow: bool = False


def shade(c: int, k: float) -> int:
    r, g, b = (c >> 16) & 255, (c >> 8) & 255, c & 255
    return (min(255, int(r * k)) << 16) | (min(255, int(g * k)) << 8) | min(255, int(b * k))


def in_shed(x: float, z: float) -> bool:
    x0, x1, z0, z1 = SHED_FOOT
    return (x0 <= x <= x1 and z0 <= z <= z1) or (-x1 <= x <= -x0 and -z1 <= z <= -z0)


def cut(a: float, b: float, holes: list[tuple[float, float]]) -> list[tuple[float, float]]:
    """The interval a..b minus the holes."""
    out = [(a, b)]
    for h0, h1 in holes:
        nxt = []
        for s0, s1 in out:
            if h1 <= s0 or h0 >= s1:
                nxt.append((s0, s1))
                continue
            if h0 > s0:
                nxt.append((s0, h0))
            if h1 < s1:
                nxt.append((h1, s1))
        out = nxt
    return [(s0, s1) for s0, s1 in out if s1 - s0 > 0.2]


def build() -> tuple[list[Put], list[Part]]:
    rnd = random.Random(SEED)
    puts: list[Put] = []
    parts: list[Part] = []

    def lane_tint(lane: str) -> str:
        return lane if lane in S.LANE else "mid"

    def wall_tint() -> str:
        return "bd%d" % rnd.randrange(len(S.BACKDROP))

    def lane_of(b) -> str:
        # The containers that form the crane court belong to the middle (blue), whatever their x.
        if b.name.startswith("Crane box"):
            return "mid"
        return b.lane()

    shed_ids = {1: [], -1: []}
    crane_ids = []
    for i, b in enumerate(L.BOXES, start=1):
        if b.kind == "box":
            along_x = b.sx > b.sz
            for k in range(int(round(b.h / 8))):
                yaw = (90 if along_x else 0) + (180 if rnd.random() < 0.5 else 0)
                puts.append(Put(b.piece, b.x, STACK * k, b.z, yaw, lane_tint(lane_of(b)), "Containers", [i]))
        elif b.kind == "low":
            puts.append(Put("Crate", b.x, 0, b.z, 0 if rnd.random() < 0.5 else 90, None, "Yard", [i]))
        elif b.kind == "ramp":
            yaw = math.degrees(math.atan2(b.up[0], b.up[1]))
            puts.append(Put("Stair", b.x, 0, b.z, yaw, None, "Yard", [i]))
        elif b.kind == "rack":
            puts.append(Put("Rack", b.x, 0, b.z, 0 if b.z > 0 else 180, None, "Yard", [i]))
        elif b.kind == "office":
            puts.append(Put("Office", b.x, 0, b.z, 0 if b.x > 0 else 180, None, "Yard", [i]))
        elif b.kind in ("wall", "roof", "lintel"):
            shed_ids[1 if b.z > 0 else -1].append(i)
        elif b.kind in ("pillar", "beam"):
            crane_ids.append(i)
        elif b.kind == "edge":
            # Each run starts at a Shed wall and ends at an end wall (|z| = 92). Start 0.3 clear of the Shed's
            # plinth and corner trims, lay 8-long segments, then 3.7-long ones, never past the run's end.
            side = 1 if b.x > 0 else -1
            if abs(abs(b.z1) - L.YARD_Z) < 0.01:
                start, step = b.z0 + 0.3, 1
            else:
                start, step = b.z1 - 0.3, -1
            left = b.sz - 0.3
            segs, at = [], start
            for length, piece in ((8.0, "QuayBarrier8"), (SHORT, "QuayBarrierShort")):
                while left >= length - 1e-6:
                    segs.append((at + step * length / 2, piece))
                    at += step * length
                    left -= length
            for k, (z, piece) in enumerate(segs):
                puts.append(Put(piece, b.x + side, 0, z, 0 if side > 0 else 180, None, "Quay", [i]))
                near_mast = any(abs(mx - b.x) < 2 and abs(mz - z) < 4 for mx, mz in MASTS)
                if k % 2 == 0 and piece == "QuayBarrier8" and not near_mast:
                    puts.append(Put("Bollard", b.x, WALL_TOP - PROP_SINK, z, 0, None, "Quay", []))
        elif b.kind == "backdrop":
            pass  # dressed below as whole end walls

    for s in (1, -1):
        puts.append(Put("Shed", 55 * s, 0, 42 * s, 0 if s > 0 else 180, "east" if s > 0 else "west", "Sheds", shed_ids[s]))
        puts.append(Put("ShedSign%d" % (1 if s > 0 else 2), 55 * s, 0, 42 * s, 0 if s > 0 else 180, None, "Sheds", []))
    puts.append(Put("Crane", 0, 0, 0, 0, None, "Crane", crane_ids))

    # End walls, 7 high, with a dark filler behind so the gaps between boxes read as depth.
    backdrop_ids = [i for i, b in enumerate(L.BOXES, start=1) if b.kind == "backdrop"]
    first = len(puts)
    for s in (1, -1):
        for row in range(7):
            for x, z, piece, yaw in END_FACES:
                yaw2 = yaw + (180 if s < 0 else 0) + (180 if rnd.random() < 0.3 else 0)
                # The two rows at eye level get the full container; above them the light Lo version
                # (background: silhouette and colour only, LihFolk Spending Triangles Where the Camera Looks).
                name = piece if row < 2 else piece + "Lo"
                puts.append(Put(name, x * s, STACK * row, z * s, yaw2, wall_tint(), "EndWalls", []))
    # Round 1: the end walls' outer faces (seen over the water and from the far end) are dressed too, with the
    # light containers, so no raw filler slab shows from anywhere.
    for s in (1, -1):
        for row in range(7):
            # Over the two side blocks (x 18..68); the middle of the back is the alcove's own C40 (0, 114).
            for x, piece in ((-52, "C40Lo"), (-28, "C20Lo"), (28, "C20Lo"), (52, "C40Lo")):
                yaw2 = 90 + (180 if rnd.random() < 0.5 else 0)
                puts.append(Put(piece, x * s, STACK * row, (L.DECK_END - 4.05) * s, yaw2, wall_tint(), "EndWalls", []))
    for p in puts[first:]:
        p.own = list(backdrop_ids)
    # Spawn wayfinding (round 1): a framed sign on the baffle naming the dock and the lane each way round it,
    # and white chevrons on the deck from the alcove round both sides of the baffle.
    for s in (1, -1):
        puts.append(Put("SpawnSign" + ("B" if s > 0 else "A"), 0, 0, 84.0 * s, 0 if s > 0 else 180, None, "Spawn", []))
        for x in (-20.5, 20.5):
            for z in (89.0, 85.0):
                puts.append(Put("Chevron", x * s, 0, z * s, 0 if s > 0 else 180, None, "Spawn", []))
    for b in L.BOXES:
        if b.kind == "backdrop":
            parts.append(Part("Filler", "EndWalls", (b.sx - 1, b.h - 1, b.sz - 1), (b.x, (b.h - 1) / 2 + 0.01, b.z), "Roof"))

    # The deck edge all round: 29 faces down each long side (z -116..116) and 17 across each end.
    for s in (1, -1):
        for k in range(29):
            puts.append(Put("QuayFace8", L.PIER_X * s, 0, -112 + 8 * k, 0 if s > 0 else 180, None, "Quay", []))
        for k in range(17):
            # 0.5 out from the deck end, so the corner faces' ends don't lie in the deck's side planes.
            puts.append(Put("QuayFace8", -64 + 8 * k, 0, (L.DECK_END + 0.5) * s, -90 if s > 0 else 90, None, "Quay", []))

    for x, z in MASTS:
        puts.append(Put("LampMast", x, WALL_TOP - PROP_SINK, z, 0, None, "Quay", []))

    # Deck paint: bay lines on a 16 grid, cut around each other, the Sheds and the quay wall.
    zline_x = list(range(-64, 65, 16))
    for x in zline_x:
        holes = []
        if SHED_FOOT[0] - 1 <= abs(x) <= SHED_FOOT[1]:
            holes = [(SHED_FOOT[2] - 0.5, SHED_FOOT[3] + 0.5)] if x > 0 else [(-SHED_FOOT[3] - 0.5, -SHED_FOOT[2] + 0.5)]
        for z0, z1 in cut(-L.YARD_Z, L.YARD_Z, holes):
            parts.append(Part("BayLine", "Deck", (LINE_W, LINE_Y1 - LINE_Y0, z1 - z0), (x, (LINE_Y0 + LINE_Y1) / 2, (z0 + z1) / 2), "Hazard"))
    for z in range(-80, 81, 16):
        holes = [(x - LINE_W / 2, x + LINE_W / 2) for x in zline_x]  # butt-joined: no overlap, no gap
        for s in (1, -1):
            if SHED_FOOT[2] - 1 <= z * s <= SHED_FOOT[3]:
                holes.append((SHED_FOOT[0] - 0.5, SHED_FOOT[1]) if s > 0 else (-SHED_FOOT[1], -SHED_FOOT[0] + 0.5))
        for x0, x1 in cut(-65.8, 65.8, holes):
            parts.append(Part("BayLine", "Deck", (x1 - x0, LINE_Y1 - LINE_Y0, LINE_W), ((x0 + x1) / 2, (LINE_Y0 + LINE_Y1) / 2, z), "Hazard"))

    # Harbour water and the far quays.
    # 1000 wide: ends 24 short of the old Dockyard's water (origin 1500 east), and 0.1 lower, so the two never overlap.
    parts.append(Part("Water", "Deck", (1000, 1, 2040), (0, -9.6, 0), "Water", 0.15))
    for s in (1, -1):
        parts.append(Part("FarQuay", "Skyline", (268, 4, 1000), (266 * s, -10, 0), "ConcreteDark"))
        for x, z, yaw in SKY_CRANES:
            puts.append(Put("StsCrane", x * s, -8, z * s, yaw + (180 if s < 0 else 0), None, "Skyline", []))
        puts.append(Put("Ship", SHIP[0] * s, -9, SHIP[1] * s, 0 if s > 0 else 180, None, "Skyline", []))
        for bi, bz in enumerate(SHIP_BAYS):
            for ri, rx in enumerate(SHIP_ROWS):
                for k in range(SHIP_HEIGHTS[bi][ri]):
                    puts.append(Put("C40Lo", (SHIP[0] + rx) * s, SHIP_DECK + STACK * k, (SHIP[1] + bz) * s, 0, wall_tint(), "Skyline", []))
        for x, z, n in FAR_STACKS:
            for k in range(n):
                puts.append(Put("C40Lo", x * s, -8 + STACK * k, z * s, 90, wall_tint(), "Skyline", []))
    return puts, parts


def luau_block() -> str:
    puts, parts = build()

    def n(v):
        return f"{v:g}" if isinstance(v, float) else str(v)

    lines = ["local ART: { Put } = {"]
    for p in puts:
        tint = f', lane = "{p.lane}"' if p.lane is not None else ""
        own = "{ " + ", ".join(str(i) for i in p.own) + " }" if p.own else "{}"
        lines.append(
            f'\t{{ piece = "{p.piece}", sec = "{p.sec}", x = {n(round(p.x, 4))}, y = {n(round(p.y, 4))}, '
            f"z = {n(round(p.z, 4))}, yaw = {n(p.yaw)}{tint}, own = {own} }},"
        )
    lines.append("}")
    lines.append("local ART_PARTS: { ArtPart } = {")
    for q in parts:
        sx, sy, sz = (round(v, 4) for v in q.size)
        px, py, pz = (round(v, 4) for v in q.pos)
        lines.append(
            f'\t{{ name = "{q.name}", sec = "{q.sec}", size = {{ {n(sx)}, {n(sy)}, {n(sz)} }}, '
            f'pos = {{ {n(px)}, {n(py)}, {n(pz)} }}, role = "{q.role}", '
            f"reflectance = {n(q.reflectance)} }},"
        )
    lines.append("}")
    return "\n".join(lines)


if __name__ == "__main__":
    puts, parts = build()
    from collections import Counter

    print(Counter(p.piece for p in puts))
    print(Counter(q.name for q in parts))
