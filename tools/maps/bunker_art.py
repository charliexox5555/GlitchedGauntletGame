"""Bunker art placement: turns the checked layout (bunker_layout.py) into kit placements, checks them for
z-fighting, and writes tools/studio/maps/Bunker/Art.luau.

    python tools/maps/bunker_art.py            placement summary + the coplanar check (needs the kit export)
    python tools/maps/bunker_layout.py --luau  also writes Art.luau (and the greybox)

The kit pieces and their origins are documented in tools/blender/build_map_kit_bunker.py. Yaw is MapKit's:
at(x, y, z, yaw) turns a piece's local +X toward (cos yaw, -sin yaw) in (x, z): a piece facing +X / -Z / -X / +Z
has yaw 0 / 90 / 180 / 270. `sz` stretches a piece along its local Z (its length): Art.luau scales the MeshParts
(Size and offset), the previews scale the instance. Only uniform-along-Z pieces (cladding courses, pipes, rails,
beams, edges) are stretched, so nothing visibly distorts.

What gets placed (all generated from the layout, both halves at once, so it can't drift from the greybox):
- wall cladding on every wall face that bounds a walkable space, found by rasterising the wall blocks at two heights
  (y 5: the ground band, Clad12 or Clad10 under a deck; y 17: the upper band of tall rooms, Field14): runs break at
  doors and openings, the ones along X stop 0.32 short of inside corners (the ones along Z run into them), convex
  corners get a steel corner post;
- a steel lining + frame in every door, the blast doors, the shaft lining and skylight, the sun dais and plinth,
  the ring and overlook edges and rails, pilasters and beams, the gallery stairs;
- a kit prop on every cover block (lockers, racks, consoles, generators, pumps, manifolds, crates);
- fixtures: ceiling lights, wall lamps, pipes along the shell walls, signs.
"""

from __future__ import annotations

import json
import math
import sys
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bunker_layout as L  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
EXPORT = ROOT / "art-source/maps/Bunker/Exports/Bunker.json"
FACES = ROOT / "art-source/maps/Bunker/Exports/Bunker_faces.json"
ART_LUAU = ROOT / "tools/studio/maps/Bunker/Art.luau"

D_CLAD = 0.32  # cladding depth budget (skirt 0.3 + clearance): runs along X stop this short of inside corners
POST = 0.42  # corner post size


@dataclass
class Put:
    sec: str
    piece: str
    x: float
    y: float
    z: float
    yaw: float = 0.0
    sz: float = 1.0
    tint: str = ""  # end colour for *_Band / *_Trim parts: "B", "A" or "N" (neutral); "" = by z
    name: str = ""

    def rotated(self) -> "Put":
        return Put(self.sec, self.piece, -self.x, self.y, -self.z, (self.yaw + 180) % 360, self.sz,
                   {"B": "A", "A": "B"}.get(self.tint, self.tint), {"B": "A", "A": "B"}.get(self.name, self.name))


PLACES: list = []


def put(sec, piece, x, y, z, yaw=0.0, sz=1.0, tint="", name=""):
    p = Put(sec, piece, float(x), float(y), float(z), float(yaw) % 360, float(sz), tint, name)
    PLACES.append(p)
    return p


def both(sec, piece, x, y, z, yaw=0.0, sz=1.0, tint="", name=""):
    p = put(sec, piece, x, y, z, yaw, sz, tint, name)
    PLACES.append(p.rotated())


YAW = {(1, 0): 0.0, (0, -1): 90.0, (-1, 0): 180.0, (0, 1): 270.0}  # facing (x, z) -> yaw


# ------------------------------------------------------------------ wall runs

RES = 0.5
GX0, GZ0 = L.XMIN, L.ZMIN
NXg = int(round((L.XMAX - L.XMIN) / RES))
NZg = int(round((L.ZMAX - L.ZMIN) / RES))


def plan_mask(y, kinds=("wall",)):
    m = np.zeros((NXg, NZg), dtype=bool)
    for b in L.BLOCKS:
        if b.kind in kinds and b.y0 <= y < b.y1:
            m[int(round((b.x0 - GX0) / RES)): int(round((b.x1 - GX0) / RES)),
              int(round((b.z0 - GZ0) / RES)): int(round((b.z1 - GZ0) / RES))] = True
    return m


def interior(y, seed):
    """Air cells at height y connected to `seed` (flood fill through non-wall cells)."""
    solid = plan_mask(y, ("wall",))
    a0, c0 = int((seed[0] - GX0) / RES), int((seed[1] - GZ0) / RES)
    seen = np.zeros_like(solid)
    stack = [(a0, c0)]
    while stack:
        a, c = stack.pop()
        if a < 0 or c < 0 or a >= NXg or c >= NZg or seen[a, c] or solid[a, c]:
            continue
        seen[a, c] = True
        stack += [(a + 1, c), (a - 1, c), (a, c + 1), (a, c - 1)]
    return solid, seen


def runs_at(y, seeds):
    """Wall-face runs at height y: list of (normal (nx, nz), fixed coordinate, a0, a1) in studs, where the run
    lies along the other axis from a0 to a1. Normal points from the wall into the air."""
    solid, air = None, None
    for s in seeds:
        so, ai = interior(y, s)
        solid = so
        air = ai if air is None else (air | ai)
    out = []
    # faces with normal +x: solid at (a, c), air at (a+1, c)
    for nx, nz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        if nx:
            S = solid[:-1, :] if nx > 0 else solid[1:, :]
            A = air[1:, :] if nx > 0 else air[:-1, :]
            face = S & A  # index a: boundary between a and a+1
            for a in range(face.shape[0]):
                col = face[a]
                c = 0
                while c < len(col):
                    if col[c]:
                        c1 = c
                        while c1 < len(col) and col[c1]:
                            c1 += 1
                        out.append(((nx, nz), GX0 + (a + 1) * RES, GZ0 + c * RES, GZ0 + c1 * RES))
                        c = c1
                    else:
                        c += 1
        else:
            S = solid[:, :-1] if nz > 0 else solid[:, 1:]
            A = air[:, 1:] if nz > 0 else air[:, :-1]
            face = S & A
            for c in range(face.shape[1]):
                row = face[:, c]
                a = 0
                while a < len(row):
                    if row[a]:
                        a1 = a
                        while a1 < len(row) and row[a1]:
                            a1 += 1
                        out.append(((nx, nz), GZ0 + (c + 1) * RES, GX0 + a * RES, GX0 + a1 * RES))
                        a = a1
                    else:
                        a += 1
    return out, solid, air


def cell(mask, x, z):
    a, c = int(math.floor((x - GX0) / RES)), int(math.floor((z - GZ0) / RES))
    if a < 0 or c < 0 or a >= mask.shape[0] or c >= mask.shape[1]:
        return False
    return bool(mask[a, c])


def in_block(x, y, z, kinds):
    for b in L.BLOCKS:
        if b.kind in kinds and b.x0 < x < b.x1 and b.y0 < y < b.y1 and b.z0 < z < b.z1:
            return b
    return None


DOOR_JAMBS = set()  # (x, z) vertices of door jambs (no corner posts there)


def door_list(kind="door"):
    """Every opening of `kind` from the layout: (cx, y, cz, yaw, width) with yaw 0 = wall along Z (thickness along
    X), 90 = wall along X."""
    out = []
    for k, x0, x1, y0, y1, z0, z1 in L.DOORS:
        if k != kind:
            continue
        if abs((x1 - x0) - 2) < 1e-6:
            out.append(((x0 + x1) / 2, y0, (z0 + z1) / 2, 0.0, z1 - z0))
        else:
            assert abs((z1 - z0) - 2) < 1e-6
            out.append(((x0 + x1) / 2, y0, (z0 + z1) / 2, 90.0, x1 - x0))
    return out


def cut_openings(run, y):
    """Removes the parts of a wall-face run that are an opening's jamb faces (inside a door at height y)."""
    (nx, nz), fixed, a0, a1 = run
    pieces = [(a0, a1)]
    for k, x0, x1, y0, y1, z0, z1 in L.DOORS:
        if not (y0 <= y < y1):
            continue
        if nx:  # face plane x = fixed, run along z
            if not (x0 - 1e-6 <= fixed <= x1 + 1e-6):
                continue
            c0, c1 = z0, z1
        else:
            if not (z0 - 1e-6 <= fixed <= z1 + 1e-6):
                continue
            c0, c1 = x0, x1
        nxt = []
        for s0, s1 in pieces:
            if s1 <= c0 + 1e-6 or s0 >= c1 - 1e-6:
                nxt.append((s0, s1))
                continue
            if s0 < c0:
                nxt.append((s0, c0))
            if s1 > c1:
                nxt.append((c1, s1))
        pieces = nxt
    return [((nx, nz), fixed, s0, s1) for s0, s1 in pieces if s1 - s0 > 1e-6]


def cladding():
    """Cladding runs for the ground band (y 5) and the tall rooms' upper band (y 17)."""
    seeds = [(-10.0, 0.0)]
    count = {"Clad12": 0, "Clad10": 0, "Field14": 0, "CornerPost12": 0, "CornerPost14": 0}
    for band, y_s, y_place in ((0, 5.0, 0.0), (1, 17.0, L.DECK)):
        raw, solid, air = runs_at(y_s, seeds)
        runs = [r for run in raw for r in cut_openings(run, y_s)]
        for (nx, nz), fixed, a0, a1 in runs:
            # split by deck adjacency (ground band only): Clad10 where a deck touches the wall above the run
            segs = []
            if band == 0:
                step = RES
                cur, start = None, a0
                t = a0
                while t < a1 - 1e-9:
                    mid = t + step / 2
                    px, pz = (fixed + nx * 0.25, mid) if nx else (mid, fixed + nz * 0.25)
                    deck = in_block(px, 11.25, pz, ("deck",)) is not None
                    kind = "Clad10" if deck else "Clad12"
                    if kind != cur:
                        if cur is not None:
                            segs.append((cur, start, t))
                        cur, start = kind, t
                    t += step
                segs.append((cur, start, a1))
            else:
                segs.append(("Field14", a0, a1))
            for kind, s0, s1 in segs:
                # inside corners: runs along X stop D_CLAD short; along Z they run into the corner
                if nz:
                    probe = 0.25
                    if cell(solid, s0 - probe, fixed + nz * probe):
                        s0 += D_CLAD
                    if cell(solid, s1 + probe, fixed + nz * probe):
                        s1 -= D_CLAD
                length = s1 - s0
                if length < 0.5:
                    continue
                mid = (s0 + s1) / 2
                x, z = (fixed, mid) if nx else (mid, fixed)
                yaw = YAW[(nx, nz)]
                put("Walls", kind, x, y_place, z, yaw, sz=length / 8.0)
                count[kind] += 1
        # convex corners: a grid vertex with exactly one solid cell around it (and not a door jamb)
        posts = 0
        for a in range(1, NXg):
            for c in range(1, NZg):
                q = (solid[a - 1, c - 1], solid[a, c - 1], solid[a - 1, c], solid[a, c])
                if sum(q) != 1:
                    continue
                aq = (air[a - 1, c - 1], air[a, c - 1], air[a - 1, c], air[a, c])
                if sum(aq) != 3:
                    continue
                vx, vz = GX0 + a * RES, GZ0 + c * RES
                if (round(vx, 2), round(vz, 2)) in DOOR_JAMBS:
                    continue
                k = q.index(True)
                # the solid cell's offset from the vertex -> the post goes in the opposite quadrant
                sx = -1 if k in (0, 2) else 1  # solid is at -x (k 0, 2) or +x
                sz_ = -1 if k in (0, 1) else 1
                n1 = (-sx, 0)  # post extends along -solid direction
                n2 = (0, -sz_)
                # local +X along n1 and local +Z along n2 needs n2 == (-n1.z, n1.x); else swap
                if (n2[0], n2[1]) != (-n1[1], n1[0]):
                    n1, n2 = n2, n1
                yaw = YAW[n1]
                put("Walls", "CornerPost12" if band == 0 else "CornerPost14", vx, y_place, vz, yaw)
                posts += 1
                count["CornerPost12" if band == 0 else "CornerPost14"] += 1
    return count


def doors():
    n = 0
    for kind, piece in (("door", "DoorLining"), ("blast", "BlastDoor")):
        for cx, y, cz, yaw, width in door_list(kind):
            assert abs(width - (8 if kind == "door" else 14)) < 1e-6, (kind, cx, cz, width)
            if kind == "blast":
                yaw = 90.0 if cz > 0 else 270.0  # the jammed leaf is on team B's +X side (A's -X)
            put("Doors", piece, cx, y, cz, yaw)
            n += 1
            # jamb vertices (both faces): no corner posts there
            h = width / 2
            for s in (-h, h):
                for t in (-1, 1):
                    vx, vz = (cx + t, cz + s) if yaw % 180 == 0 else (cx + s, cz + t)
                    DOOR_JAMBS.add((round(vx, 2), round(vz, 2)))
    return n


# ------------------------------------------------------------------ the rest of the dressing

def wall_prop(b, piece, sec, inset=0.0, stretch_to=None):
    """A prop whose back stands against the wall its block touches: origin at the wall face, facing away."""
    cx, cz = b.cx, b.cz
    best = None
    for (nx, nz) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        # wall behind = on the side opposite the facing
        bx = b.x0 - 0.25 if nx > 0 else b.x1 + 0.25 if nx < 0 else cx
        bz = b.z0 - 0.25 if nz > 0 else b.z1 + 0.25 if nz < 0 else cz
        if in_block(bx, b.y0 + 1.0, bz, ("wall",)):
            best = (nx, nz)
            break
    assert best, b
    nx, nz = best
    wx = b.x0 if nx > 0 else b.x1 if nx < 0 else cx
    wz = b.z0 if nz > 0 else b.z1 if nz < 0 else cz
    length = (b.z1 - b.z0) if nx else (b.x1 - b.x0)
    sz = (length - 2 * inset) / stretch_to if stretch_to else 1.0
    put(sec, piece, wx, b.y0, wz, YAW[(nx, nz)], sz)


def props():
    for b in L.BLOCKS:
        n = b.name
        if n == "Lockers":
            # 4 locker modules (4 wide each) along the wall, 0.32 clear of the side walls' cladding
            nx = 0
            span = b.x1 - b.x0
            w = (span - 2 * D_CLAD) / 4
            face_z = b.z1 if b.cz > 0 else b.z0
            yaw = 90.0 if b.cz > 0 else 270.0
            for i in range(4):
                x = b.x0 + D_CLAD + w * (i + 0.5)
                put("Lockers", "Lockers4", x, 0, face_z, yaw, sz=w / 4)
        elif n == "Racks":
            span = b.x1 - b.x0
            w = (span - 2 * D_CLAD) / 4
            face_z = b.z1 if b.cz > 0 else b.z0
            yaw = 90.0 if b.cz > 0 else 270.0
            for i in range(4):
                x = b.x0 + D_CLAD + w * (i + 0.5)
                put("Control", "Rack4", x, 0, face_z, yaw, sz=w / 4)
        elif n == "LockerIsland":
            put("Lockers", "LockerIsland", b.cx, 0, b.cz, 0.0 if b.cz > 0 else 180.0)
        elif n == "Console":
            put("Sunwell", "Console8", b.cx, 0, b.cz, 90.0 if b.cz > 0 else 270.0)
        elif n == "ControlDesk":
            s = 1 if b.cz > 0 else -1
            put("Control", "Console8", b.cx - s * 1, 0, b.cz, 180.0 if s > 0 else 0.0)
            put("Control", "Console8", b.cx + s * 1, 0, b.cz, 0.0 if s > 0 else 180.0)
        elif n == "Generator":
            w, d = b.x1 - b.x0, b.z1 - b.z0
            piece = "Gen46" if min(w, d) < 5 else "Gen66"
            put(b.section, piece, b.cx, 0, b.cz, 0.0 if b.cz > 0 else 180.0)
        elif n == "PumpUnit":
            wall_prop(b, "PumpUnit", "Pump")
        elif n == "Manifold":
            wall_prop(b, "Manifold", "Pump")
        elif n == "SupplyCage":
            wall_prop(b, "CrateStack", "Vestibule")
        elif n == "CrateRow":
            wall_prop(b, "CrateRow", "Vestibule")
    # Centre: dais, plinth, shaft lining, skylight.
    put("Sunwell", "SunDais", 0, 0, 0, 0, tint="N")
    put("Sunwell", "SunPlinth", 0, 0, 0, 0, tint="N")
    # Shaft lining: three 8-wide panels per side, from the roof underside (26) to the skylight (64). N/S sides full
    # 24, E/W sides stop D_CLAD short of the corners (stretched).
    for zc in (-8, 0, 8):
        pass
    for x in (-8, 0, 8):
        both("Shaft", "ShaftPanel8", x, L.HALL, L.SHAFT, 90.0)  # N side faces -Z (into the shaft)
    e_len = 2 * L.SHAFT - 2 * D_CLAD
    for i in range(3):
        z = -L.SHAFT + D_CLAD + e_len / 3 * (i + 0.5)
        both("Shaft", "ShaftPanel8", L.SHAFT, L.HALL, z, 180.0, sz=e_len / 24)  # E side faces -X
    put("Shaft", "ShaftTop", 0, L.SHAFT_TOP, 0, 0)
    # Sunwell ceiling: downstand beams at +-7 across each roof band, pilasters under their wall ends.
    for s in (-7, 7):
        z0, z1 = L.SHAFT, L.ATR - 0.15
        both("Sunwell", "Beam8", s, L.HALL, (z0 + z1) / 2, 0, sz=(z1 - z0) / 8)  # N band, along Z
        both("Sunwell", "Beam8", (z0 + z1) / 2, L.HALL, s, 90, sz=(z1 - z0) / 8)  # E band, along X
        both("Sunwell", "Pilaster14", s, L.DECK, L.ATR, 90)  # on the B wall, facing -Z
        both("Sunwell", "Pilaster14", L.ATR, L.DECK, s, 180)  # on the E wall, facing -X
    # Gallery ceiling beams across, on corbels on both side walls.
    for z in (34.0, 42.0, 50.0):
        w0, w1 = -L.GAL + 0.15, L.GAL - 0.15
        both("Gallery", "Beam8", 0, L.HALL, z, 90, sz=(w1 - w0) / 8)
        both("Gallery", "Corbel", -L.GAL, L.HALL - 1.5, z, 0)  # the beam ends sit on corbels
        both("Gallery", "Corbel", L.GAL, L.HALL - 1.5, z, 180)
    # Ring: an edge (fascia + cove light) on the deck's inner edge, and a coping + rail on every parapet.
    r = L.RING_IN
    e_in = r - 0.12
    both("Ring", "RingEdge8", 0, 0, r, 90, sz=2 * r / 8)  # N edge (x -13..13), faces -Z into the void
    both("Ring", "RingEdge8", r, 0, 0, 180, sz=2 * e_in / 8)  # E edge (z -12.88..12.88), faces -X
    both("Ring", "Rail8", (-r + 0.1 + r + 1.1) / 2, L.DECK + 3, r + 0.5, 90, sz=(2 * r + 1.0) / 8)  # N: x -12.9..14.1
    both("Ring", "Rail8", r + 0.5, L.DECK + 3, (-r - 1.1 + r - 0.1) / 2, 0, sz=(2 * r + 1.0) / 8)  # E: z -14.1..12.9
    # Overlook: its deck edge and parapet (x -12..6 at z 29..30 for B), rail clear of the gallery wall's cladding
    for b in L.BLOCKS:
        if b.name == "OverlookParapet" and b.cz > 0:
            x0, x1 = b.x0 + 0.17, b.x1
            both("Gallery", "Rail8", (x0 + x1) / 2, L.DECK + 3, b.cz, 90, sz=(x1 - x0) / 8)
            ex0, ex1 = b.x0 + 0.17, b.x1 - 0.2  # clear of the stair's stringer
            both("Gallery", "RingEdge8", (ex0 + ex1) / 2, 0, b.z1, 270, sz=(ex1 - ex0) / 8)
    # Gallery stairs (team B's rises toward -Z from z 48 to 30 along x 6..12).
    for rmp in L.RAMPS:
        if rmp.name == "GalleryStair" and rmp.up < 0:
            both("Gallery", "GalleryStair", (rmp.x0 + rmp.x1) / 2, 0, rmp.z1, 0)


def fixtures():
    """Ceiling lights, wall lamps, pipes and signs (placed for team B's half and the east pump, then rotated)."""
    # Corridor ceiling lights: a line down each corridor (east B part and west B part; rotations do A's).
    for z in (22.0, 34.0, 46.0):
        both("Fixtures", "LinearLight", 36.0, L.LOW, z, 0)
        both("Fixtures", "LinearLight", -36.0, L.LOW, z, 0)
    # Rooms: lockers and control, two each.
    for z in (30.0, 42.0):
        both("Fixtures", "LinearLight", 22.0, L.LOW, z, 0)
        both("Fixtures", "LinearLight", -22.0, L.LOW, z, 0)
    # Vestibule: a row along its length; spawn room: four.
    for x in (-30.0, -10.0, 10.0, 30.0):
        both("Fixtures", "LinearLight", x, L.LOW, 60.0, 90)
    for x in (-8.0, 8.0):
        for z in (78.0, 92.0):
            both("Fixtures", "LinearLight", x, L.LOW, z, 0)
    # Pump room (east; the west one is its rotation): industrial cage lamps.
    for x, z in ((26.0, -8.0), (26.0, 8.0), (36.0, 10.0), (36.0, -10.0)):
        both("Fixtures", "CageLamp", x, L.LOW, z, 0)
    # Pipes along the shell (the corridors' and pump rooms' outer walls): one run, z -66..66 at x 40, facing -X.
    both("Fixtures", "PipeRun8", L.COR_X1, 0, 0, 180, sz=(2 * L.VEST_Z1 - 2 * D_CLAD) / 8)
    # Wall lamps beside the sunwell doors (sunwell side) and the gallery passage (gallery side).
    both("Fixtures", "WallLamp", -L.ATR, 0, 8.0, 0)  # sunwell W wall, beside the west pump door? (z 4..)
    both("Fixtures", "WallLamp", 0.0, 0, L.ATR, 90)  # sunwell B wall between the doors
    # Hazard sills either side of each blast-door passage (B: x -4..4 at z 52..54), the spawn letter panels.
    for z in (L.GAL_Z1 - 0.75, L.GAL_Z1 + 3.2):  # the vestibule side clears the frame's lip (0.45)
        both("Doors", "HazardSill", 0.0, 0, z, 90, sz=7.6 / 8)
    both("Spawn", "SpawnPanel", 0.0, 0, L.SPAWN_Z1, 90, tint="B", name="B")


NAMES = {"sunwell": "SUNWELL", "ring": "RING", "gallery": "GALLERY", "lockers": "LOCKERS", "control": "CONTROL",
         "pump": "PUMP", "corridor": "CORRIDOR", "vestibule": "VESTIBULE", "spawn": "SPAWN", "overlook": "OVERLOOK"}


def door_signs():
    """Each door's two lintel signs name the space beyond them (a sign under a deck is removed: "")."""
    for p in PLACES:
        if p.piece != "DoorLining":
            continue
        th = math.radians(p.yaw)
        ax, az = math.cos(th), -math.sin(th)  # the piece's +X in the map
        texts = []
        for s in (1, -1):
            # the sign on face s is read from side s; it names the space on the other side (-s)
            fx, fz = p.x + ax * s * 1.5, p.z + az * s * 1.5
            if in_block(fx, p.y + 11.2, fz, ("deck",)):
                texts.append("")
                continue
            bx, bz = p.x - ax * s * 4.0, p.z - az * s * 4.0
            reg = L.region(bx, p.y, bz)
            key = reg.split()[-1]
            texts.append(NAMES.get(key, reg.upper()))
        p.name = "|".join(texts)


def build():
    PLACES.clear()
    DOOR_JAMBS.clear()
    stats = {"doors": doors()}
    stats.update(cladding())
    props()
    fixtures()
    door_signs()
    return stats


# ------------------------------------------------------------------ the coplanar check on the dressed map

def _local_to_map(p: Put, c, s):
    """Kit part box (Roblox piece-local centre c, size s) -> map-space AABB (lo, hi) for a placement."""
    cx, cy, cz = c[0], c[1], c[2] * p.sz
    sx, sy, sz = s[0], s[1], s[2] * p.sz
    th = math.radians(p.yaw)
    co, si = round(math.cos(th)), round(math.sin(th))
    x = cx * co + cz * si
    z = -cx * si + cz * co
    if abs(si) > 0.5:
        sx, sz = sz, sx
    lo = (p.x + x - sx / 2, p.y + cy - sy / 2, p.z + z - sz / 2)
    hi = (p.x + x + sx / 2, p.y + cy + sy / 2, p.z + z + sz / 2)
    return lo, hi


def face_rects():
    """Every placed kit face rectangle (from Bunker_faces.json: per part, the axis-aligned planar faces of each
    mesh island) plus the visible greybox box faces, in map space: (label, axis, sign, plane, (u0, u1), (v0, v1))."""
    data = json.loads(FACES.read_text(encoding="utf-8"))
    out = []
    for i, p in enumerate(PLACES):
        parts = data["pieces"].get(p.piece)
        if parts is None:
            continue
        th = math.radians(p.yaw)
        co, si = round(math.cos(th)), round(math.sin(th))
        removed = set()
        if p.piece == "DoorLining":
            tp, tm = (p.name.split("|") + ["", ""])[:2]
            if not tp:
                removed.add("DoorLining_SignP")
            if not tm:
                removed.add("DoorLining_SignM")
        for part, rects in parts.items():
            if part in removed:
                continue
            for (ax, sign, plane, ua, ub) in rects:
                # piece-local Roblox: ax 0=x 1=y 2=z; ua/ub are the ranges on the two other axes (in order)
                lo = [0.0, 0.0, 0.0]
                hi = [0.0, 0.0, 0.0]
                others = [k for k in range(3) if k != ax]
                lo[ax] = hi[ax] = plane
                lo[others[0]], hi[others[0]] = ua
                lo[others[1]], hi[others[1]] = ub
                # stretch along local z
                lo[2] *= p.sz
                hi[2] *= p.sz
                if ax == 2:
                    pass
                # rotate (x, z) by yaw and translate
                def tr(v):
                    x = v[0] * co + v[2] * si
                    z = -v[0] * si + v[2] * co
                    return (p.x + x, p.y + v[1], p.z + z)
                a, b = tr(lo), tr(hi)
                mlo = tuple(min(a[k], b[k]) for k in range(3))
                mhi = tuple(max(a[k], b[k]) for k in range(3))
                n = [0, 0, 0]
                n[ax] = sign
                nn = (n[0] * co + n[2] * si, n[1], -n[0] * si + n[2] * co)
                wax = max(range(3), key=lambda k: abs(nn[k]))
                wsign = 1 if nn[wax] > 0 else -1
                o = [k for k in range(3) if k != wax]
                out.append((f"{p.sec}.{p.piece}#{i}.{part}", wax, wsign, mlo[wax], (mlo[o[0]], mhi[o[0]]), (mlo[o[1]], mhi[o[1]])))
    for label, lo, hi in L.visible_greybox():
        for ax in range(3):
            o = [k for k in range(3) if k != ax]
            out.append((label, ax, -1, lo[ax], (lo[o[0]], hi[o[0]]), (lo[o[1]], hi[o[1]])))
            out.append((label, ax, 1, hi[ax], (lo[o[0]], hi[o[0]]), (lo[o[1]], hi[o[1]])))
    return out


def coplanar_faces(rects, solids, samples=5, min_hits=3):
    """Same rule as bunker_layout.coplanar_check, on face rectangles: same axis, same facing, plane within
    PLANE_TOL, overlap >= MIN_SIDE on both sides, and at least min_hits of samples*samples spots not buried in a
    visible greybox block. Different labels only (one label = one Part/MeshPart)."""
    S = np.array([[*lo, *hi] for _, lo, hi in solids], dtype=float)
    buckets = {}
    for r in rects:
        label, ax, sign, plane, ur, vr = r
        key = (ax, sign, int(math.floor(plane / 0.5)))
        buckets.setdefault(key, []).append(r)
    fights = []
    seen = set()
    for (ax, sign, k), items in buckets.items():
        cand = items + buckets.get((ax, sign, k + 1), [])
        # sort by u start for a sweep
        cand.sort(key=lambda r: r[4][0])
        for i in range(len(cand)):
            la, _, _, pa, ua, va = cand[i]
            for j in range(i + 1, len(cand)):
                lb, _, _, pb, ub, vb = cand[j]
                if ub[0] > ua[1] - L.MIN_SIDE:
                    break
                if la == lb or abs(pa - pb) >= L.PLANE_TOL:
                    continue
                u0, u1 = max(ua[0], ub[0]), min(ua[1], ub[1])
                v0, v1 = max(va[0], vb[0]), min(va[1], vb[1])
                if u1 - u0 < L.MIN_SIDE or v1 - v0 < L.MIN_SIDE:
                    continue
                pair = (min(la, lb), max(la, lb), round(pa, 2))
                if pair in seen:
                    continue
                seen.add(pair)
                o = [kk for kk in range(3) if kk != ax]
                hits = 0
                for si in range(samples):
                    for sj in range(samples):
                        q = [0.0, 0.0, 0.0]
                        q[o[0]] = u0 + (u1 - u0) * (si + 0.5) / samples
                        q[o[1]] = v0 + (v1 - v0) * (sj + 0.5) / samples
                        q[ax] = (pa + pb) / 2 + sign * L.BURY_OFF
                        qa = np.array(q)
                        if not np.any(np.all((S[:, 0:3] < qa - 1e-9) & (S[:, 3:6] > qa + 1e-9), axis=1)):
                            hits += 1
                if hits >= min_hits:
                    fights.append((la, lb, "xyz"[ax], sign, round((pa + pb) / 2, 3), round((u1 - u0) * (v1 - v0), 3)))
    return fights


def check() -> bool:
    stats = build()
    print("\nArt placements:", len(PLACES), "  ", stats)
    counts = {}
    for p in PLACES:
        counts[p.piece] = counts.get(p.piece, 0) + 1
    print("  by piece:", dict(sorted(counts.items())))
    if not FACES.exists():
        print("  (no kit face export yet: build the kit to run the dressed coplanar check)")
        return True
    data = json.loads(EXPORT.read_text(encoding="utf-8")) if EXPORT.exists() else None
    if data:
        n_parts = 0
        per_piece = {}
        for part in data["parts"]:
            per_piece[part["piece"]] = per_piece.get(part["piece"], 0) + 1
        tris = {}
        for part in data["parts"]:
            tris[part["piece"]] = tris.get(part["piece"], 0) + part["tris"]
        missing = sorted({p.piece for p in PLACES} - set(per_piece))
        n_parts = sum(per_piece.get(p.piece, 0) for p in PLACES)
        n_tris = sum(tris.get(p.piece, 0) for p in PLACES)
        print(f"  MeshParts placed: {n_parts}; triangles placed: {n_tris}; unique kit tris: {data['tris']}"
              + (f"; MISSING pieces: {missing}" if missing else ""))
    rects = face_rects()
    solids = L.visible_greybox()
    fights = coplanar_faces(rects, solids)
    print(f"Coplanar check (dressed map: {len(rects)} face rectangles of {len(PLACES)} kit placements + the visible"
          f" greybox): {len(fights)} z-fighting pairs")
    groups = {}
    for f in fights:
        a = f[0].split("#")[0].split(".")[-1] + "." + f[0].split(".")[-1] if "#" in f[0] else f[0].split("(")[0]
        b = f[1].split("#")[0].split(".")[-1] + "." + f[1].split(".")[-1] if "#" in f[1] else f[1].split("(")[0]
        g = " + ".join(sorted([a, b]))
        groups.setdefault(g, []).append(f)
    for g, fs in sorted(groups.items(), key=lambda kv: -len(kv[1]))[:30]:
        print(f"  {len(fs):3d}  {g}   e.g. {fs[0][2]}{'+' if fs[0][3] > 0 else '-'} at {fs[0][4]} area {fs[0][5]}")
    return not fights


# ------------------------------------------------------------------ Art.luau

def write_luau():
    build()
    rows = []
    for p in PLACES:
        rows.append(f'\t{{ "{p.sec}", "{p.piece}", {p.x:g}, {p.y:g}, {p.z:g}, {p.yaw:g}, {round(p.sz, 5):g}, "{p.tint}" }},')
    template = (Path(__file__).resolve().parent / "bunker_art_template.luau").read_text(encoding="utf-8")
    body = template.replace("--@PLACEMENTS@", "\n".join(rows))
    ART_LUAU.write_text(body, encoding="utf-8")
    print(f"Wrote {ART_LUAU} ({len(PLACES)} placements)")


if __name__ == "__main__":
    ok = check()
    print("\nALL ART CHECKS PASS" if ok else "\nART CHECKS FAILED")
    sys.exit(0 if ok else 1)
