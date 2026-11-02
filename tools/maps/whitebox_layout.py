#!/usr/bin/env python3
"""Whitebox map layout: the proposed top-down plan, its checks and its SVG.

Run: python tools/maps/whitebox_layout.py
Writes vault/02 Art/References/maps/white-arena/whitebox-layout.svg and prints
gaps, sightlines, spawn safety, cover spread and route times, so a layout change
is checked before anything is built in Studio. Studs; X across, Z along the map.
The arena has 180-degree rotational symmetry: only one half is listed.
"""

from __future__ import annotations

import heapq
import math
from dataclasses import dataclass
from pathlib import Path

ROOM_X = 40.0  # half width of the main room
ROOM_Z = 56.0  # half length of the main room
ALCOVE_X = 15.0  # half width of the spawn alcove
ALCOVE_DEPTH = 16.0
EYE = 5.0  # standing eye height: anything shorter doesn't block sight
SPRINT = 22.0  # Config/Movement SPRINT_SPEED
CELL = 1.0  # grid resolution of the checks


@dataclass
class Box:
    name: str
    x: float
    z: float
    sx: float
    sz: float
    h: float
    yaw: float = 0.0
    kind: str = "full"  # full, low, pillar, perch, ramp, baffle, center

    def corners(self) -> list[tuple[float, float]]:
        c, s = math.cos(math.radians(self.yaw)), math.sin(math.radians(self.yaw))
        out = []
        for dx, dz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            lx, lz = dx * self.sx / 2, dz * self.sz / 2
            out.append((self.x + lx * c - lz * s, self.z + lx * s + lz * c))
        return out

    def contains(self, px: float, pz: float, pad: float = 0.0) -> bool:
        c, s = math.cos(math.radians(self.yaw)), math.sin(math.radians(self.yaw))
        dx, dz = px - self.x, pz - self.z
        return (
            abs(dx * c + dz * s) <= self.sx / 2 + pad
            and abs(-dx * s + dz * c) <= self.sz / 2 + pad
        )

    def rotated(self) -> "Box":
        return Box(self.name + "'", -self.x, -self.z, self.sx, self.sz, self.h, self.yaw, self.kind)


# Sits on the centre point, so it is its own rotated partner.
CENTER = [Box("Diamond", 0, 0, 16, 16, 14, 45, "center")]

# One half of the map (Z > 0, the Blue end). The other half is this list rotated.
HALF = [
    Box("Pillar", 11, 21, 6, 6, 48, 0, "pillar"),
    Box("Pillar", -11, 21, 6, 6, 48, 0, "pillar"),
    Box("Side block", 25, 0, 8, 10, 8),
    Box("Mid post", 3, 33, 12, 3, 8),
    Box("Low wall", -6.5, 33, 7, 3, 3, 0, "low"),
    Box("Angled slab", -27, 17, 14, 4, 8, 28),
    Box("Long wall box", 37, 14, 6, 10, 8),
    Box("Perch", 28, 46, 24, 20, 7, 0, "perch"),
    Box("Perch ramp", 35, 30, 10, 12, 7, 0, "ramp"),
    Box("Frame post", -24, 37, 4, 4, 10),
    Box("Frame post", -38, 37, 4, 4, 10),
    Box("Frame sill", -31, 37, 10, 4, 3, 0, "low"),
    Box("Corner cube", -36, 52, 8, 8, 8),
    Box("Spawn baffle", 0, 50, 16, 3, 10, 0, "baffle"),
]

BOXES = CENTER + HALF + [b.rotated() for b in HALF]
SPAWNS = [(-7.0, 66.0), (7.0, 66.0), (-7.0, 60.0), (7.0, 60.0)]
SPAWNS_B = [(-x, -z) for x, z in SPAWNS]


def in_room(px: float, pz: float) -> bool:
    if abs(px) <= ROOM_X and abs(pz) <= ROOM_Z:
        return True
    return abs(px) <= ALCOVE_X and abs(pz) <= ROOM_Z + ALCOVE_DEPTH


def build_grids():
    xs = [(-ROOM_X - 2) + i * CELL for i in range(int((2 * ROOM_X + 4) / CELL) + 1)]
    zs = [
        -(ROOM_Z + ALCOVE_DEPTH + 2) + i * CELL
        for i in range(int((2 * (ROOM_Z + ALCOVE_DEPTH) + 4) / CELL) + 1)
    ]
    sight, walk = {}, {}
    for ix, x in enumerate(xs):
        for iz, z in enumerate(zs):
            inside = in_room(x, z)
            sight[(ix, iz)] = (not inside) or any(
                b.h >= EYE and b.kind != "ramp" and b.contains(x, z) for b in BOXES
            )
            # 2.2 studs of body clearance around anything you can't run through.
            walk[(ix, iz)] = inside and not any(
                b.kind != "ramp" and b.contains(x, z, 2.2) for b in BOXES
            )
    return xs, zs, sight, walk


def to_cell(x: float, z: float) -> tuple[int, int]:
    return (
        round((x + ROOM_X + 2) / CELL),
        round((z + ROOM_Z + ALCOVE_DEPTH + 2) / CELL),
    )


def ray(sight, x, z, dx, dz, maxd=200.0) -> float:
    d = 0.0
    while d < maxd:
        d += 0.5
        if sight.get(to_cell(x + dx * d, z + dz * d), True):
            return d
    return maxd


def clear_line(sight, a, b) -> bool:
    d = math.dist(a, b)
    steps = max(1, int(d / 0.5))
    return not any(
        sight.get(
            to_cell(a[0] + (b[0] - a[0]) * i / steps, a[1] + (b[1] - a[1]) * i / steps), True
        )
        for i in range(steps + 1)
    )


def seg_gap(a: Box, b: Box) -> float:
    def edge_points(box: Box):
        cs = box.corners()
        for i in range(4):
            p, q = cs[i], cs[(i + 1) % 4]
            n = max(2, int(math.dist(p, q)))
            for t in range(n + 1):
                yield (p[0] + (q[0] - p[0]) * t / n, p[1] + (q[1] - p[1]) * t / n)

    if any(a.contains(*p) for p in edge_points(b)) or any(b.contains(*p) for p in edge_points(a)):
        return 0.0
    pa, pb = list(edge_points(a)), list(edge_points(b))
    return min(math.dist(p, q) for p in pa for q in pb)


def route_time(walk, start, goal) -> float | None:
    start, goal = to_cell(*start), to_cell(*goal)
    seen = {start: 0.0}
    queue = [(0.0, start)]
    while queue:
        cost, cur = heapq.heappop(queue)
        if cur == goal:
            return cost / SPRINT
        if cost > seen[cur]:
            continue
        for dx in (-1, 0, 1):
            for dz in (-1, 0, 1):
                nxt = (cur[0] + dx, cur[1] + dz)
                step = math.hypot(dx, dz) * CELL
                if step and walk.get(nxt) and cost + step < seen.get(nxt, math.inf):
                    seen[nxt] = cost + step
                    heapq.heappush(queue, (cost + step, nxt))
    return None


def report():
    xs, zs, sight, walk = build_grids()
    print(f"Boxes: {len(BOXES)}")

    print("\nGaps under 6.5 studs (a player needs room; 0 = touching on purpose):")
    for i, a in enumerate(BOXES):
        for b in BOXES[i + 1 :]:
            if "ramp" in (a.kind, b.kind):
                continue  # you walk up a ramp, so it can't pinch anyone
            g = seg_gap(a, b)
            if 0 < g < 6.5 and not a.name.startswith("Frame") and not b.name.startswith("Frame"):
                print(f"  {a.name} - {b.name}: {g:.1f}")
    for b in BOXES:
        if b.kind in ("baffle", "ramp"):
            continue  # the baffle faces the alcove mouth, not a wall
        walls = [min(ROOM_X - abs(px), ROOM_Z - abs(pz)) for px, pz in b.corners()]
        if min(walls) > 0 and min(walls) < 6.5:  # touching a wall on purpose leaves no gap
            print(f"  {b.name} - room wall: {min(walls):.1f}")

    best = []
    for x in range(-38, 39, 4):
        for z in range(-70, 71, 4):
            if abs(z) > ROOM_Z or not in_room(x, z) or sight.get(to_cell(x, z), True):
                continue
            for deg in range(0, 180, 3):
                dx, dz = math.cos(math.radians(deg)), math.sin(math.radians(deg))
                d1 = ray(sight, x, z, dx, dz)
                d2 = ray(sight, x, z, -dx, -dz)
                total = d1 + d2
                a, b = (x - dx * d2, z - dz * d2), (x + dx * d1, z + dz * d1)
                # Inside a spawn alcove doesn't count: the baffle covers it.
                if abs(a[1]) <= ROOM_Z and abs(b[1]) <= ROOM_Z:
                    best.append((total, a, b))
    best.sort(key=lambda t: -t[0])
    over = sum(1 for t in best if t[0] > 70)
    print(f"\nSight rays over 70 studs: {100 * over / len(best):.1f}% of all rays sampled")
    print("\nLongest sightlines through the room (eye height, low cover ignored):")
    shown = 0
    last = None
    for total, a, b in best:
        key = (round(a[0] / 8), round(a[1] / 8), round(b[0] / 8), round(b[1] / 8))
        if key == last:
            continue
        last = key
        print(f"  {total:.0f} studs  ({a[0]:.0f},{a[1]:.0f}) -> ({b[0]:.0f},{b[1]:.0f})")
        shown += 1
        if shown == 6:
            break

    print("\nSpawn safety:")
    print(
        "  any spawn A sees any spawn B:",
        any(clear_line(sight, a, b) for a in SPAWNS for b in SPAWNS_B),
    )
    open_cells = [
        (x, z)
        for x in range(-38, 39, 2)
        for z in range(-70, 71, 2)
        if in_room(x, z) and not sight.get(to_cell(x, z), True)
    ]
    enemy_half = [p for p in open_cells if p[1] < -4]
    seen_from = sum(1 for p in enemy_half if any(clear_line(sight, p, s) for s in SPAWNS))
    print(f"  enemy-half floor that can see a spawn point: {100 * seen_from / len(enemy_half):.1f}%")

    full = [b for b in BOXES if b.h >= EYE and b.kind != "ramp"]
    worst, worst_at, total = 0.0, (0, 0), []
    for p in open_cells:
        if abs(p[1]) > ROOM_Z:
            continue
        d = min(
            min(math.dist(p, c) for c in b.corners())
            if not b.contains(*p)
            else 0.0
            for b in full
        )
        total.append(d)
        if d > worst:
            worst, worst_at = d, p
    print("\nCover spread (distance to the nearest full-cover corner):")
    print(f"  average {sum(total) / len(total):.1f}, furthest {worst:.1f} at {worst_at}")

    print("\nSprint times:")
    centre_side = (0.0, 16.0)
    for name, a, b in (
        ("spawn to centre", (-7.0, 60.0), centre_side),
        ("spawn to enemy spawn", (-7.0, 60.0), (7.0, -60.0)),
    ):
        t = route_time(walk, a, b)
        print(f"  {name}: {t:.1f} s" if t else f"  {name}: NO ROUTE")

    jump = 7.2
    updraft = 14.0
    walkable = max(b.h for b in BOXES if b.kind in ("perch", "ramp", "low", "full") and b.h <= 8)
    print(
        f"\nHighest reach: {walkable} perch + {jump} jump + 2 x {updraft} Updraft = "
        f"{walkable + jump + 2 * updraft:.1f} studs (walls and pillars are 48)"
    )
    return best[0]


FILL = {
    "full": "#C9CCD8",
    "low": "#E9EBF2",
    "pillar": "#7D8296",
    "perch": "#AEB3C6",
    "ramp": "#D5D9E6",
    "baffle": "#C9CCD8",
    "center": "#9EA4BA",
}


def svg(longest) -> str:
    scale = 6.0
    pad = 70
    w = (2 * ROOM_X) * scale + 2 * pad + 250
    h = 2 * (ROOM_Z + ALCOVE_DEPTH) * scale + 2 * pad
    ox, oz = pad + ROOM_X * scale, pad + (ROOM_Z + ALCOVE_DEPTH) * scale

    def px(x, z):
        return ox + x * scale, oz - z * scale

    out = [
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w:.0f} {h:.0f}" '
        'font-family="Segoe UI, Arial, sans-serif">',
        f'<rect width="{w:.0f}" height="{h:.0f}" fill="#20242E"/>',
    ]
    room = [
        (-ALCOVE_X, ROOM_Z + ALCOVE_DEPTH),
        (ALCOVE_X, ROOM_Z + ALCOVE_DEPTH),
        (ALCOVE_X, ROOM_Z),
        (ROOM_X, ROOM_Z),
        (ROOM_X, -ROOM_Z),
        (ALCOVE_X, -ROOM_Z),
        (ALCOVE_X, -ROOM_Z - ALCOVE_DEPTH),
        (-ALCOVE_X, -ROOM_Z - ALCOVE_DEPTH),
        (-ALCOVE_X, -ROOM_Z),
        (-ROOM_X, -ROOM_Z),
        (-ROOM_X, ROOM_Z),
        (-ALCOVE_X, ROOM_Z),
    ]
    pts = " ".join("%.1f,%.1f" % px(*p) for p in room)
    out.append(f'<polygon points="{pts}" fill="#F4F5F9" stroke="#FFFFFF" stroke-width="6"/>')

    # 16-stud panel grid
    grid = []
    gx = -40
    while gx <= 40:
        grid.append(px(gx, -ROOM_Z) + px(gx, ROOM_Z))
        gx += 16
    gz = -56
    while gz <= 56:
        grid.append(px(-ROOM_X, gz) + px(ROOM_X, gz))
        gz += 16
    for a, b, c, d in grid:
        out.append(f'<line x1="{a:.1f}" y1="{b:.1f}" x2="{c:.1f}" y2="{d:.1f}" stroke="#DDE0EA"/>')

    # End colours
    for sign, colour, letter in ((1, "#3D6FD6", "BLUE END"), (-1, "#D9A520", "YELLOW END")):
        x1, z1 = px(-ROOM_X, sign * ROOM_Z)
        x2, z2 = px(ROOM_X, sign * ROOM_Z)
        out.append(
            f'<line x1="{x1:.1f}" y1="{z1:.1f}" x2="{x2:.1f}" y2="{z2:.1f}" '
            f'stroke="{colour}" stroke-width="7"/>'
        )
        lx, lz = px(0, sign * (ROOM_Z + ALCOVE_DEPTH))
        ty = lz + (-14 if sign > 0 else 26)
        out.append(
            f'<text x="{lx:.1f}" y="{ty:.1f}" text-anchor="middle" font-size="15" '
            f'font-weight="700" fill="{colour}">{letter}</text>'
        )

    for b in BOXES:
        pts = " ".join("%.1f,%.1f" % px(*c) for c in b.corners())
        out.append(
            f'<polygon points="{pts}" fill="{FILL[b.kind]}" stroke="#4D5266" stroke-width="1.5"/>'
        )

    # Longest sightline
    _, a, b = longest
    ax, az = px(*a)
    bx, bz = px(*b)
    out.append(
        f'<line x1="{ax:.1f}" y1="{az:.1f}" x2="{bx:.1f}" y2="{bz:.1f}" stroke="#D1495B" '
        'stroke-width="2" stroke-dasharray="7 5"/>'
    )

    for spawns, colour in ((SPAWNS, "#3D6FD6"), (SPAWNS_B, "#D9A520")):
        for s in spawns:
            sx, sz = px(*s)
            out.append(f'<circle cx="{sx:.1f}" cy="{sz:.1f}" r="7" fill="{colour}"/>')

    labels = {
        (0, 0): "Diamond",
        (11, 26): "Pillar",
        (-11, 26): "Pillar",
        (28, 46): "Perch",
        (35, 30): "ramp",
        (-31, 41): "Frame",
        (-36, 52): "Cube",
        (0, 37): "Mid wall (low on one side)",
        (25, 0): "Side",
        (-27, 17): "Slab",
        (0, 45): "Baffle",
    }
    for (x, z), text in labels.items():
        tx, tz = px(x, z)
        out.append(
            f'<text x="{tx:.1f}" y="{tz + 4:.1f}" text-anchor="middle" font-size="12" '
            f'fill="#20242E">{text}</text>'
        )

    kx = pad + 2 * ROOM_X * scale + 36
    out.append(
        f'<text x="{kx:.0f}" y="{pad + 8}" font-size="24" font-weight="700" fill="#F4F5F9">Whitebox</text>'
    )
    out.append(
        f'<text x="{kx:.0f}" y="{pad + 32}" font-size="13" fill="#B9BDCB">Proposed layout, 180° rotation</text>'
    )
    rows = [
        (FILL["pillar"], "Pillar, 48 tall"),
        (FILL["center"], "Diamond, 14 tall"),
        (FILL["full"], "Full cover, 8–10 tall"),
        (FILL["perch"], "Perch, 7 tall"),
        (FILL["ramp"], "Ramp up to the perch"),
        (FILL["low"], "Low cover, 3 tall"),
    ]
    y = pad + 66
    for colour, text in rows:
        out.append(f'<rect x="{kx:.0f}" y="{y}" width="20" height="20" fill="{colour}" stroke="#4D5266"/>')
        out.append(f'<text x="{kx + 30:.0f}" y="{y + 15}" font-size="14" fill="#F4F5F9">{text}</text>')
        y += 30
    out.append(f'<circle cx="{kx + 10:.0f}" cy="{y + 10}" r="7" fill="#3D6FD6"/>')
    out.append(f'<text x="{kx + 30:.0f}" y="{y + 15}" font-size="14" fill="#F4F5F9">Spawn points</text>')
    y += 30
    out.append(
        f'<line x1="{kx:.0f}" y1="{y + 10}" x2="{kx + 20:.0f}" y2="{y + 10}" stroke="#D1495B" '
        'stroke-width="2" stroke-dasharray="7 5"/>'
    )
    out.append(
        f'<text x="{kx + 30:.0f}" y="{y + 15}" font-size="14" fill="#F4F5F9">Longest line, {longest[0]:.0f} studs</text>'
    )
    y += 44
    bar = 16 * scale
    out.append(f'<rect x="{kx:.0f}" y="{y}" width="{bar:.0f}" height="6" fill="#F4F5F9"/>')
    out.append(f'<text x="{kx:.0f}" y="{y + 24}" font-size="13" fill="#B9BDCB">16 studs (one panel)</text>')
    out.append(f'<text x="{kx:.0f}" y="{y + 44}" font-size="13" fill="#B9BDCB">Room 80 × 112, alcoves 30 × 16</text>')
    out.append("</svg>")
    return "\n".join(out)


if __name__ == "__main__":
    longest = report()
    target = Path(__file__).resolve().parents[2] / "vault/02 Art/References/maps/white-arena/whitebox-layout.svg"
    target.write_text(svg(longest), encoding="utf-8")
    print(f"\nWrote {target}")
