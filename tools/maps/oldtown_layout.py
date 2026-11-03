#!/usr/bin/env python3
"""Old Town map layout: the plan as 3D data, its checks, its SVG and its generated greybox.

Run:  python tools/maps/oldtown_layout.py            checks + SVG
      python tools/maps/oldtown_layout.py --write    also writes tools/studio/maps/OldTown/Greybox.luau
                                                     and Art.luau (tools/maps/oldtown_art.py)

Writes vault/02 Art/References/maps/oldtown/oldtown-layout.svg and prints gaps, sightlines,
spawn safety, route times, time to first sight and reach, so a layout change is checked
before anything is built in Studio (vault/01 Design/Maps/Old Town.md).

Map space (MapKit.luau): studs, origin on the floor at the map centre, +X across, +Z along,
+Y up; team A (Blue) spawns at -Z, team B (Green) at +Z. 180-degree rotational symmetry:
only the A half (z <= 0) is listed in HALF and BUILDINGS; the B half is that list rotated.

Every solid here is a collision Part in the greybox: boxes, wedges (ramps, stairs and roof
slopes; MapKit convention, low at local -Z, top at local +Z, local +Z = (sin yaw, cos yaw))
and cylinders. Buildings are an outer box minus voids (rooms, doors, stairwells), split
into boxes, so the checks see exactly what gets built.
"""

from __future__ import annotations

import heapq
import math
import sys
from dataclasses import dataclass, field, replace
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
SVG_OUT = ROOT / "vault/02 Art/References/maps/oldtown/oldtown-layout.svg"

# ---------------------------------------------------------------- numbers
PLAY_X = 80.0  # playable half width (the alleys end here; the perimeter houses beyond)
PLAY_Z = 136.0  # playable half length (behind the spawn cloisters)
OUT_X = 92.0  # outer edge of the perimeter houses
OUT_Z = 148.0
STOREY = 12.0
SLAB = 11.0  # underside of the upper floor (the upper floor stands at 12)
UPPER = 12.0
INNER_EAVE = 24.0  # two-storey houses round the plaza
PERIM_TOP = 52.0  # four storeys + attic: taller than anyone reaches
DOOR_W = 6.0
DOOR_H = 9.0
PITCH = math.tan(math.radians(30))

EYE = 5.0  # standing eye height
HEAD = 5.0  # clearance a player needs above a floor
STEP = 1.6  # walkable rise between neighbouring cells (stairs, kerbs)
JUMP = 7.2  # Config/Movement JUMP_HEIGHT
UPDRAFT_BUDGET = 28.0  # two 14-stud Updrafts, or one High Rise A3 (Whitebox convention)
SPRINT = 22.0  # Config/Movement SPRINT_SPEED
WALK = 16.0  # Config/Movement WALK_SPEED

ACCENT = {"A": "#2F6BB3", "B": "#4E8A3E"}  # Blue end (A) and Green end (B): shutters, awnings, banners


# ---------------------------------------------------------------- solids
@dataclass
class Solid:
    name: str
    kind: str  # ground, floor, perim, bldg, arcade, rail, stair, roof, cover, low, lintel, prop
    section: str
    cx: float
    cz: float
    sx: float
    sz: float
    y0: float
    y1: float
    yaw: float = 0.0
    shape: str = "box"  # box, wedge, cyl (sx = diameter)
    side: str = "A"
    owner: str = ""  # building name, for the art pass
    shell: bool = False  # touches its building's outer footprint (the facade art hides it)

    def rotated(self) -> "Solid":
        return replace(
            self,
            name=self.name.replace("_A", "_B") if "_A" in self.name else self.name + "'",
            cx=-self.cx,
            cz=-self.cz,
            yaw=(self.yaw + 180.0) % 360.0,
            side="B" if self.side == "A" else "A",
            owner=self.owner + "'" if self.owner else "",
        )

    def axes(self):
        r = math.radians(self.yaw)
        return (math.cos(r), -math.sin(r)), (math.sin(r), math.cos(r))  # local X, local Z in (x, z)

    def corners(self):
        (ax, az), (bx, bz) = self.axes()
        out = []
        for dx, dz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            lx, lz = dx * self.sx / 2, dz * self.sz / 2
            out.append((self.cx + lx * ax + lz * bx, self.cz + lx * az + lz * bz))
        return out


def B(name, x0, x1, z0, z1, y0, y1, kind, section, **kw) -> Solid:
    return Solid(name, kind, section, (x0 + x1) / 2, (z0 + z1) / 2, x1 - x0, z1 - z0, y0, y1, **kw)


def ramp(name, x0, x1, z0, z1, y0, y1, up, kind, section, **kw) -> Solid:
    # Wedge over the rectangle, rising toward `up` ("+x", "-x", "+z", "-z") from y0 to y1.
    yaw = {"+z": 0.0, "+x": 90.0, "-z": 180.0, "-x": 270.0}[up]
    w, l = (x1 - x0, z1 - z0) if up in ("+z", "-z") else (z1 - z0, x1 - x0)
    return Solid(name, kind, section, (x0 + x1) / 2, (z0 + z1) / 2, w, l, y0, y1, yaw, "wedge", **kw)


def cyl(name, cx, cz, d, y0, y1, kind, section, **kw) -> Solid:
    return Solid(name, kind, section, cx, cz, d, d, y0, y1, 0.0, "cyl", **kw)


# ---------------------------------------------------------------- buildings
Box3 = tuple  # (x0, x1, z0, z1, y0, y1)


def subtract(box: Box3, hole: Box3) -> list[Box3]:
    x0, x1, z0, z1, y0, y1 = box
    hx0, hx1, hz0, hz1, hy0, hy1 = hole
    if hx0 >= x1 or hx1 <= x0 or hz0 >= z1 or hz1 <= z0 or hy0 >= y1 or hy1 <= y0:
        return [box]
    out = []
    # Split along x, then z, then y: full-height wall pieces plus lintels over doors.
    if x0 < hx0:
        out.append((x0, hx0, z0, z1, y0, y1))
        x0 = hx0
    if x1 > hx1:
        out.append((hx1, x1, z0, z1, y0, y1))
        x1 = hx1
    if z0 < hz0:
        out.append((x0, x1, z0, hz0, y0, y1))
        z0 = hz0
    if z1 > hz1:
        out.append((x0, x1, hz1, z1, y0, y1))
        z1 = hz1
    if y0 < hy0:
        out.append((x0, x1, z0, z1, y0, hy0))
    if y1 > hy1:
        out.append((x0, x1, z0, z1, hy1, y1))
    return out


@dataclass
class Building:
    name: str
    x0: float
    x1: float
    z0: float
    z1: float
    eave: float
    roof: tuple  # ("gable", "x"|"z") ridge axis, ("shed", up-direction), ("flat",), ("hero", piece)
    voids: list = field(default_factory=list)  # Box3 list
    klass: str = "inner"  # inner (two storeys) or perim (four storeys + attic)
    tone: str = "cream"
    side: str = "A"
    section: str = "Buildings"
    label: str = ""

    def rotated(self) -> "Building":
        roof = self.roof
        if roof[0] == "shed":
            roof = ("shed", {"+x": "-x", "-x": "+x", "+z": "-z", "-z": "+z"}[roof[1]])
        return replace(
            self,
            name=self.name.replace("_A", "_B") if "_A" in self.name else self.name + "'",
            x0=-self.x1,
            x1=-self.x0,
            z0=-self.z1,
            z1=-self.z0,
            voids=[(-v[1], -v[0], -v[3], -v[2], v[4], v[5]) for v in self.voids],
            side="B" if self.side == "A" else "A",
            roof=roof,
        )

    def rise(self) -> float:
        if self.roof[0] == "gable":
            half = (self.z1 - self.z0) / 2 if self.roof[1] == "x" else (self.x1 - self.x0) / 2
            return half * PITCH
        if self.roof[0] == "shed":
            run = (self.x1 - self.x0) if self.roof[1] in ("+x", "-x") else (self.z1 - self.z0)
            return min(run * PITCH, 8.0)
        return 0.0

    def solids(self) -> list[Solid]:
        parts = [(self.x0, self.x1, self.z0, self.z1, 0.0, self.eave)]
        for v in self.voids:
            nxt = []
            for p in parts:
                nxt += subtract(p, v)
            parts = nxt
        kind = "perim" if self.klass == "perim" else "bldg"
        out = []
        for i, (x0, x1, z0, z1, y0, y1) in enumerate(parts):
            if x1 - x0 < 1e-6 or z1 - z0 < 1e-6 or y1 - y0 < 1e-6:
                continue
            shell = x0 <= self.x0 + 1e-6 or x1 >= self.x1 - 1e-6 or z0 <= self.z0 + 1e-6 or z1 >= self.z1 - 1e-6
            out.append(
                B(f"{self.name}_{i + 1}", x0, x1, z0, z1, y0, y1, kind, self.section, side=self.side, owner=self.name, shell=shell)
            )
        e, r = self.eave, self.rise()
        if self.roof[0] == "gable" and self.roof[1] == "x":
            zm = (self.z0 + self.z1) / 2
            out.append(ramp(f"{self.name}_RoofS", self.x0, self.x1, self.z0, zm, e, e + r, "+z", "roof", "Roofs", side=self.side, owner=self.name))
            out.append(ramp(f"{self.name}_RoofN", self.x0, self.x1, zm, self.z1, e, e + r, "-z", "roof", "Roofs", side=self.side, owner=self.name))
        elif self.roof[0] == "gable":
            xm = (self.x0 + self.x1) / 2
            out.append(ramp(f"{self.name}_RoofW", self.x0, xm, self.z0, self.z1, e, e + r, "+x", "roof", "Roofs", side=self.side, owner=self.name))
            out.append(ramp(f"{self.name}_RoofE", xm, self.x1, self.z0, self.z1, e, e + r, "-x", "roof", "Roofs", side=self.side, owner=self.name))
        elif self.roof[0] == "shed":
            out.append(ramp(f"{self.name}_Roof", self.x0, self.x1, self.z0, self.z1, e, e + r, self.roof[1], "roof", "Roofs", side=self.side, owner=self.name))
        return out


# ---------------------------------------------------------------- the plan (A half, z <= 0)
#
#   z -148..-136  perimeter (behind the cloister)
#   z -136..-108  Blue Cloister (spawn), x -20..20, between two tall corner houses
#   z -108..-104  cloister front wall, gates at x +-12..20 (barriers)
#   z -104..-92   Blue Lane: the cross street in front of the spawn, wall to wall
#   z  -92..-36   front blocks: Bakery (east) / Market Court (west), the Forecourt between (x -12..12)
#   z  -40..-36   Blue Gate: the city gate onto the plaza, one 10-wide arch west of centre
#   z  -36..0     the plaza (x -34..34), arcades (|x| 34..44), houses (|x| 44..68), alleys (|x| 68..80)

BUILDINGS: list[Building] = [
    # Perimeter: four storeys + attic, never reachable (52 > 15 + 7.2 + 28).
    Building("PerimBack", -20, 20, -148, -136, PERIM_TOP, ("shed", "-z"), klass="perim", tone="ochre", label="Cloister back"),
    Building("PerimE", 80, 92, -148, 0, PERIM_TOP, ("shed", "+x"), klass="perim", tone="rose"),
    Building("PerimW", -92, -80, -148, 0, PERIM_TOP, ("shed", "-x"), klass="perim", tone="cream"),
    Building("CornerE", 20, 80, -136, -104, PERIM_TOP, ("gable", "x"), klass="perim", tone="cream", label="Corner house"),
    Building("CornerW", -80, -20, -136, -104, PERIM_TOP, ("gable", "x"), klass="perim", tone="ochre", label="Corner house"),
    # Cloister front: a one-storey wall that hides the spawn; the gates sit either side of it.
    Building("CloisterFront", -12, 12, -108, -104, STOREY, ("flat",), tone="ochre", section="Spawn", label=""),
    # East front block (Bakery side).
    Building("EFrontS", 12, 68, -92, -68, INNER_EAVE, ("gable", "x"), tone="ochre", label="Granary"),
    Building(
        "Bakery",
        12,
        68,
        -60,
        -36,
        INNER_EAVE,
        ("gable", "x"),
        voids=[
            (28, 52, -58, -38, 0, SLAB),  # the bakery hall
            (37, 43, -38, -36, 0, DOOR_H),  # door to the east arcade's end
            (29, 35, -60, -58, 0, DOOR_H),  # door to Bakery Lane
            (46, 52, -38, -36, 0, DOOR_H),  # inner door to the Cafe
        ],
        tone="cream",
        label="Bakery",
    ),
    # East plaza house: the Cafe, with the stair up to the Cafe Terrace (the arcade roof).
    Building(
        "Cafe",
        44,
        68,
        -36,
        -4,
        INNER_EAVE,
        ("gable", "z"),
        voids=[
            (46, 66, -34, -6, 0, SLAB),  # cafe room
            (44, 46, -27, -21, 0, DOOR_H),  # arcade door
            (46, 52, -36, -34, 0, DOOR_H),  # inner door from the Bakery
            (66, 68, -19, -13, 0, DOOR_H),  # alley door
            (54, 60, -28, -12, SLAB, 22),  # stairwell (the stair rises north)
            (46, 60, -12, -6, UPPER, 22),  # upstairs landing
            (44, 46, -11, -5, UPPER, UPPER + DOOR_H),  # terrace door
        ],
        tone="rose",
        label="Cafe",
    ),
    # Mid house between the arcades' halves; the arcade walk runs through it.
    # Solid: a walk straight through would join both arcades into one 100-stud corridor.
    Building("Pavilion", 34, 68, -4, 4, INNER_EAVE, ("hero", "Pavilion"), tone="cream", label="Pavilion"),
    # West plaza houses (no terrace on this side: a tiled arcade roof instead).
    Building("Chemist", -68, -44, -36, -24, INNER_EAVE, ("gable", "z"), tone="cream", label=""),
    Building(
        "Bookshop",
        -68,
        -44,
        -16,
        -4,
        INNER_EAVE,
        ("gable", "z"),
        voids=[
            (-66, -46, -14, -6, 0, SLAB),
            (-46, -44, -11, -5, 0, DOOR_H),  # arcade door
            (-59, -53, -16, -14, 0, DOOR_H),  # door to the lane
        ],
        tone="ochre",
        label="Bookshop",
    ),
    # West front block round the Market Court (flat roofs with parapets).
    Building("CourtSW", -68, -44, -92, -76, INNER_EAVE, ("flat",), tone="rose"),
    Building("CourtSE", -36, -12, -92, -76, INNER_EAVE, ("flat",), tone="cream"),
    Building("CourtW", -68, -52, -76, -60, INNER_EAVE, ("flat",), tone="ochre"),
    Building("CourtNW", -68, -52, -52, -36, INNER_EAVE, ("flat",), tone="cream"),
    Building("CourtE", -28, -12, -68, -36, INNER_EAVE, ("flat",), tone="rose"),
    Building(
        "Tavern",
        -52,
        -28,
        -52,
        -36,
        INNER_EAVE,
        ("flat",),
        voids=[
            (-50, -30, -50, -38, 0, SLAB),
            (-43, -37, -38, -36, 0, DOOR_H),  # door to the west arcade's end
            (-35, -29, -52, -50, 0, DOOR_H),  # door to the court
        ],
        tone="ochre",
        label="Tavern",
    ),
    # Alley jogs: house corners (inner side, I) and buttresses (outer side, O) that break the
    # alleys' long lines. Along each whole alley (this half + the rotated other) they alternate
    # O, I, O, I, ... about 30 studs apart, so no straight line runs more than two of them.
    Building("JutE1", 68, 74, -84, -76, INNER_EAVE, ("flat",), tone="cream", section="Alleys"),  # I
    Building("JutE2", 74, 80, -50, -42, PERIM_TOP, ("flat",), klass="perim", tone="rose", section="Alleys"),  # O
    Building("JutE3", 68, 74, -12, -4, INNER_EAVE, ("flat",), tone="ochre", section="Alleys"),  # I
    Building("JutW1", -80, -74, -84, -76, PERIM_TOP, ("flat",), klass="perim", tone="cream", section="Alleys"),  # O
    Building("JutW2", -74, -68, -50, -42, INNER_EAVE, ("flat",), tone="ochre", section="Alleys"),  # I
    Building("JutW3", -80, -74, -18, -10, PERIM_TOP, ("flat",), klass="perim", tone="rose", section="Alleys"),  # O
    # Blue Gate: the city gate between the Forecourt and the plaza, its arch west of centre.
    Building("Gate_A", -12, 12, -40, -36, INNER_EAVE, ("hero", "CityGate"), voids=[(-10, 0, -40, -36, 0, 12)], tone="ochre", section="Gate", label="Blue Gate"),
]

HALF: list[Solid] = [
    # Cloister gate lintels (stop bullets over the barriers; the art arch sits on them).
    B("GateLintel_E", 12, 20, -108, -104, 10, 13, "lintel", "Spawn"),
    B("GateLintel_W", -20, -12, -108, -104, 10, 13, "lintel", "Spawn"),
    # Passage arches over lane mouths (decorative arches; collision above head height).
    B("ArchBakeryW", 12, 14, -68, -60, 11, 15, "lintel", "Arches"),
    B("ArchBakeryE", 66, 68, -68, -60, 11, 15, "lintel", "Arches"),
    B("ArchCourtS", -44, -36, -94, -92, 11, 15, "lintel", "Arches"),
    B("ArchCourtE", -14, -12, -76, -68, 11, 15, "lintel", "Arches"),
    B("ArchCourtW", -70, -68, -60, -52, 11, 15, "lintel", "Arches"),
    B("ArchLaneW", -70, -68, -24, -16, 11, 15, "lintel", "Arches"),
    # East arcade + Cafe Terrace above it (the high layer at 12).
    B("PierE1", 34, 36, -29, -27, 0, SLAB, "arcade", "Arcades"),
    B("PierE2", 34, 36, -21, -19, 0, SLAB, "arcade", "Arcades"),
    B("PierE3", 34, 36, -13, -11, 0, SLAB, "arcade", "Arcades"),
    B("SpandrelE", 34, 36, -36, -4, 10, SLAB, "arcade", "Arcades"),
    B("TerraceE", 34, 44, -36, -4, SLAB, UPPER, "floor", "Arcades"),
    B("BalustradeE", 34, 35, -36, -4, UPPER, UPPER + 3, "rail", "Arcades"),
    # West arcade: same piers, a tiled lean-to roof instead of a terrace.
    B("PierW1", -36, -34, -29, -27, 0, SLAB, "arcade", "Arcades"),
    B("PierW2", -36, -34, -21, -19, 0, SLAB, "arcade", "Arcades"),
    B("PierW3", -36, -34, -13, -11, 0, SLAB, "arcade", "Arcades"),
    B("SpandrelW", -36, -34, -36, -4, 10, SLAB, "arcade", "Arcades"),
    B("CeilingW", -44, -34, -36, -4, SLAB, UPPER, "floor", "Arcades"),
    ramp("ArcadeRoofW", -44, -34, -36, -4, UPPER, UPPER + 3, "-x", "roof", "Roofs"),
    # Cafe stair (inside the Cafe, up to the landing and the terrace door).
    ramp("CafeStair", 54, 60, -28, -12, 0, UPPER, "+z", "stair", "Stairs"),
    # Gate shrines: a wall fountain beside each cloister gate screens the spawn from the Forecourt.
    B("ShrineE", 7, 13, -98, -91, 0, 8, "cover", "Spawn"),
    B("ShrineW", -13, -7, -98, -91, 0, 8, "cover", "Spawn"),
    # Plaza cover, A half. The kiosk faces Blue Gate's arch: step left or right into the plaza.
    B("Kiosk", -12, 0, -28, -24, 0, 8, "cover", "Cover"),
    B("StallW", -26, -18, -18, -14, 0, 8, "cover", "Cover"),
    B("StallE", 16, 20, -28, -17, 0, 8, "cover", "Cover"),
    B("StallMid", -24, -20, -4, 4, 0, 8, "cover", "Cover"),
    B("PlanterS", 0, 8, -29.5, -26.5, 0, 3, "low", "Cover"),
    B("CypressesW", -29.5, -26.5, -32, -24, 0, 8, "cover", "Cover"),  # a trough of cypresses
    B("CafeTable1", 25.5, 28.5, -31.5, -28.5, 0, 3, "low", "Cover"),
    B("CafeTable2", 25.5, 28.5, -19.5, -16.5, 0, 3, "low", "Cover"),
    B("CafeTable3", 25.5, 28.5, -9.5, -6.5, 0, 3, "low", "Cover"),
    # Forecourt.
    cyl("Well", 5, -80, 6, 0, 3, "low", "Cover"),
    Solid("Cart", "cover", "Cover", 2.5, -67, 7, 3.5, 0, 7, 10.0),
    B("PlanterF", 3, 11, -50.5, -47.5, 0, 3, "low", "Cover"),
    # Blue Lane: porches and a cart alternate north / south / north (with the shrines), so no
    # straight line runs the lane wall to wall.
    B("LanePorchW", -60, -52, -98, -92, 0, 7, "cover", "Cover"),
    B("LaneTrough", -34, -26, -104, -98, 0, 7, "cover", "Cover"),
    B("LaneCart", 40, 48, -104, -98, 0, 7, "cover", "Cover"),
    B("LanePorchE", 56, 64, -98, -92, 0, 7, "cover", "Cover"),
    # Market Court and the alleys.
    B("Crates", -46, -42, -68, -64, 0, 7, "cover", "Cover"),
    B("Barrels", -36, -32, -60, -57, 0, 3, "low", "Cover"),
    B("AlleyCratesE", 76, 80, -82, -78, 0, 7, "cover", "Cover"),
    B("AlleyBarrelsW", -72, -68, -34, -31, 0, 3, "low", "Cover"),
]

# On the centre point: their own rotated partners.
CENTER: list[Solid] = [
    B("Ground", -OUT_X, OUT_X, -OUT_Z, OUT_Z, -2, 0, "ground", "Ground"),
    cyl("FountainBasin", 0, 0, 22, 0, 3, "low", "Fountain"),
    cyl("FountainPedestal", 0, 0, 12, 3, 9, "cover", "Fountain"),
    cyl("FountainColumn", 0, 0, 4, 9, 22, "cover", "Fountain"),
]

SPAWNS_A = [(-6.0, -128.0), (6.0, -128.0), (-6.0, -118.0), (6.0, -118.0)]
SPAWNS_B = [(-x, -z) for x, z in SPAWNS_A]
BARRIERS_A = [("BarrierA_E", 12, 20, -108, -104), ("BarrierA_W", -20, -12, -108, -104)]

# Floors drawn over the ground (the art pass gives them their stone): plaza and interiors.
FLOORS_A = [
    ("PlazaFloor", -34, 34, -36, 0),
    ("ForecourtFloor", -12, 12, -92, -40),
    ("CloisterFloor", -20, 20, -136, -108),
]

# The clock tower: outside the east perimeter, centred on z = 0. Art only (out of reach);
# not rotated, so it also tells you which side is east.
TOWER = (80, 94, -7, 7, 104.0)


def all_buildings() -> list[Building]:
    return BUILDINGS + [b.rotated() for b in BUILDINGS]


def all_solids() -> list[Solid]:
    out = list(CENTER)
    for b in all_buildings():
        out += b.solids()
    out += HALF + [s.rotated() for s in HALF]
    return out


# ---------------------------------------------------------------- grid (1 stud)
NX, NZ = int(2 * OUT_X), int(2 * OUT_Z)
XS = np.arange(NX) - OUT_X + 0.5
ZS = np.arange(NZ) - OUT_Z + 0.5
GX, GZ = np.meshgrid(XS, ZS, indexing="ij")


def footprint(s: Solid):
    """Mask of grid cells inside the solid's footprint and the solid's top height there."""
    if s.shape == "cyl":
        m = (GX - s.cx) ** 2 + (GZ - s.cz) ** 2 <= (s.sx / 2) ** 2
        return m, np.full(m.shape, s.y1)
    (ax, az), (bx, bz) = s.axes()
    dx, dz = GX - s.cx, GZ - s.cz
    lx = dx * ax + dz * az
    lz = dx * bx + dz * bz
    m = (np.abs(lx) <= s.sx / 2) & (np.abs(lz) <= s.sz / 2)
    if s.shape == "wedge":
        t = np.clip((lz + s.sz / 2) / s.sz, 0, 1)
        return m, s.y0 + (s.y1 - s.y0) * t
    return m, np.full(m.shape, s.y1)


class Grid:
    def __init__(self, solids: list[Solid]):
        K = 8
        self.lo = np.full((K, NX, NZ), np.inf)
        self.hi = np.full((K, NX, NZ), -np.inf)
        count = np.zeros((NX, NZ), dtype=int)
        for s in solids:
            m, top = footprint(s)
            ii, jj = np.nonzero(m)
            if len(ii) == 0:
                continue
            k = count[ii, jj]
            assert k.max() < K, f"too many solids stacked at {s.name}"
            self.lo[k, ii, jj] = s.y0
            self.hi[k, ii, jj] = top[ii, jj]
            count[ii, jj] += 1
        self.count = count
        # What stops a standing player's view: anything spanning eye height.
        self.eye_block = self.solid_at(EYE)
        self.build_nodes()

    def solid_at(self, y):
        return np.any((self.lo < y) & (self.hi > y), axis=0)

    def blocked_band(self, h, a, b):
        """Cells where anything solid overlaps (h + a, h + b); h is a per-cell array."""
        return np.any((self.lo < h + b) & (self.hi > h + a), axis=0)

    def build_nodes(self):
        # Standable surfaces: the top of any solid with head room above it.
        tops = []
        for k in range(self.lo.shape[0]):
            h = self.hi[k]
            ok = np.isfinite(h) & (h > -0.5)
            ok &= ~self.blocked_band(np.where(ok, h, 0.0), 0.05, HEAD)
            # Body width: nothing at body height in the four neighbouring cells either.
            hh = np.where(ok, h, 0.0)
            for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                sh = np.roll(np.roll(self.lo, di, axis=1), dj, axis=2)
                sH = np.roll(np.roll(self.hi, di, axis=1), dj, axis=2)
                ok &= ~np.any((sh < hh + HEAD) & (sH > hh + STEP), axis=0)
            tops.append(np.where(ok, h, np.nan))
        self.tops = np.stack(tops)  # (K, NX, NZ), nan where not standable
        self.node_of = {}
        self.nodes = []  # (i, j, h)
        for k in range(self.tops.shape[0]):
            ii, jj = np.nonzero(~np.isnan(self.tops[k]))
            for i, j in zip(ii.tolist(), jj.tolist()):
                h = float(self.tops[k, i, j])
                # Inside the playable rectangle only (the perimeter roofs aren't the map).
                if abs(XS[i]) > PLAY_X or abs(ZS[j]) > PLAY_Z:
                    continue
                key = (i, j, round(h, 1))
                if key in self.node_of:
                    continue
                self.node_of[key] = len(self.nodes)
                self.nodes.append((i, j, h))
        self.by_cell: dict = {}
        for n, (i, j, h) in enumerate(self.nodes):
            self.by_cell.setdefault((i, j), []).append((h, n))

    def neighbours(self, n, jump=0.0):
        i, j, h = self.nodes[n]
        for di in (-1, 0, 1):
            for dj in (-1, 0, 1):
                if not di and not dj:
                    continue
                for h2, m in self.by_cell.get((i + di, j + dj), ()):
                    rise = h2 - h
                    if rise <= max(STEP, jump) and rise >= -14.0:
                        yield m, math.hypot(di, dj)

    def times(self, starts, speed=SPRINT, jump=0.0) -> np.ndarray:
        t = np.full(len(self.nodes), np.inf)
        q = []
        for x, z in starts:
            n = self.node_at(x, z, 0.0)
            t[n] = 0.0
            q.append((0.0, n))
        heapq.heapify(q)
        while q:
            c, n = heapq.heappop(q)
            if c > t[n]:
                continue
            for m, d in self.neighbours(n, jump):
                c2 = c + d / speed
                if c2 < t[m]:
                    t[m] = c2
                    heapq.heappush(q, (c2, m))
        return t

    def node_at(self, x, z, h):
        i, j = int(math.floor(x + OUT_X)), int(math.floor(z + OUT_Z))
        best = None
        for h2, n in self.by_cell.get((i, j), ()):
            if best is None or abs(h2 - h) < abs(self.nodes[best][2] - h):
                best = n
        assert best is not None, f"no standable node at ({x}, {z})"
        return best

    def pos(self, n, eye=EYE):
        i, j, h = self.nodes[n]
        return np.array([XS[i], h + eye, ZS[j]])

    def los_many(self, a, bs, step=0.5):
        """Line of sight from point a (x, y, z) to every point in bs (m x 3)."""
        d = bs - a
        L = np.sqrt(d[:, 0] ** 2 + d[:, 2] ** 2)
        n = int(max(2, math.ceil(L.max() / step))) if len(bs) else 2
        t = np.linspace(0.0, 1.0, n)[None, :]
        px = a[0] + d[:, 0:1] * t
        py = a[1] + d[:, 1:2] * t
        pz = a[2] + d[:, 2:3] * t
        i = np.clip(np.floor(px + OUT_X).astype(int), 0, NX - 1)
        j = np.clip(np.floor(pz + OUT_Z).astype(int), 0, NZ - 1)
        lo = self.lo[:, i, j]  # K x m x n
        hi = self.hi[:, i, j]
        hit = np.any((lo < py[None]) & (hi > py[None]), axis=0)
        # Ignore the first and last half stud (the two ends stand on their own floors).
        far = (t * L[:, None] > 0.6) & (t * L[:, None] < L[:, None] - 0.6)
        return ~np.any(hit & far, axis=1)


# ---------------------------------------------------------------- checks
def ground_rays(g: Grid):
    """Longest straight sightlines at standing eye height on the ground (whitebox_layout.py style)."""
    blocked = g.eye_block.copy()
    ii, jj = np.nonzero(blocked)
    out_of_play = (np.abs(GX) > PLAY_X) | (np.abs(GZ) > PLAY_Z)
    blocked |= out_of_play
    degs = np.arange(0, 180, 3)
    dirs = np.stack([np.cos(np.radians(degs)), np.sin(np.radians(degs))], axis=1)
    steps = np.arange(0.75, 320, 0.75)
    res = []
    for x in range(-78, 79, 4):
        for z in range(-134, 135, 4):
            i, j = int(x + OUT_X), int(z + OUT_Z)
            if blocked[i, j] or not g.by_cell.get((i, j)):
                continue
            if min(h for h, _ in g.by_cell[(i, j)]) > 0.5:
                continue
            ends = []
            for sgn in (1, -1):
                px = x + 0.5 + sgn * dirs[:, 0:1] * steps
                pz = z + 0.5 + sgn * dirs[:, 1:2] * steps
                pi = np.clip(np.floor(px + OUT_X).astype(int), 0, NX - 1)
                pj = np.clip(np.floor(pz + OUT_Z).astype(int), 0, NZ - 1)
                hit = blocked[pi, pj]
                first = np.where(hit.any(axis=1), hit.argmax(axis=1), len(steps) - 1)
                ends.append(steps[first])
            d1, d2 = ends
            for k in range(len(degs)):
                a = (x + 0.5 - dirs[k, 0] * d2[k], z + 0.5 - dirs[k, 1] * d2[k])
                b = (x + 0.5 + dirs[k, 0] * d1[k], z + 0.5 + dirs[k, 1] * d1[k])
                res.append((d1[k] + d2[k], a, b))
    res.sort(key=lambda r: -r[0])
    return res


def first_sight(g: Grid, tA, tB, sample=3):
    """Earliest time T when some point A can reach by T sees some point B can reach by T."""
    idx = [n for n, (i, j, h) in enumerate(g.nodes) if i % sample == 0 and j % sample == 0]
    idx = np.array(idx)
    ta, tb = tA[idx], tB[idx]
    P = np.stack([g.pos(n) for n in idx])

    def seen(T):
        A = np.nonzero(ta <= T)[0]
        Bn = np.nonzero(tb <= T)[0]
        if len(A) == 0 or len(Bn) == 0:
            return None
        PB = P[Bn]
        for a in A[np.argsort(-ta[A])]:
            d = np.hypot(PB[:, 0] - P[a, 0], PB[:, 2] - P[a, 2])
            near = d < 300
            if not near.any():
                continue
            ok = g.los_many(P[a], PB[near])
            if ok.any():
                b = Bn[near][ok][0]
                return (P[a], P[b])
        return None

    lo, hi = 0.0, 20.0
    pair = None
    for _ in range(9):
        mid = (lo + hi) / 2
        p = seen(mid)
        if p is not None:
            hi, pair = mid, p
        else:
            lo = mid
    return hi, pair


def spawn_safety(g: Grid, tA, tB):
    eyesA = np.array([[x, EYE, z] for x, z in SPAWNS_A])
    eyesB = np.array([[x, EYE, z] for x, z in SPAWNS_B])
    cross = any(g.los_many(a, eyesB).any() for a in eyesA)
    # Every point the enemy holds first (tB < tA) that sees an A spawn point.
    idx = [n for n, (i, j, h) in enumerate(g.nodes) if i % 2 == 0 and j % 2 == 0 and tB[n] < tA[n]]
    bad = []
    for n in idx:
        if g.los_many(g.pos(n), eyesA).any():
            bad.append(n)
    return cross, len(bad) / max(1, len(idx)), [g.pos(n) for n in bad[:5]]


def _unused_narrow_spots(g: Grid, tA):
    """Ground cells on the routes where the free width is under a door (6)."""
    reach = np.zeros((NX, NZ), bool)
    for n, (i, j, h) in enumerate(g.nodes):
        if h < 0.5 and np.isfinite(tA[n]):
            reach[i, j] = True
    free = reach.copy()
    # Chamfer distance to the nearest non-free cell (two passes).
    INF = 1e9
    d = np.where(free, INF, 0.0)
    for i in range(NX):
        for j in range(NZ):
            if d[i, j]:
                v = d[i, j]
                if i:
                    v = min(v, d[i - 1, j] + 1)
                if j:
                    v = min(v, d[i, j - 1] + 1)
                if i and j:
                    v = min(v, d[i - 1, j - 1] + 1.414)
                if i and j < NZ - 1:
                    v = min(v, d[i - 1, j + 1] + 1.414)
                d[i, j] = v
    for i in range(NX - 1, -1, -1):
        for j in range(NZ - 1, -1, -1):
            if d[i, j]:
                v = d[i, j]
                if i < NX - 1:
                    v = min(v, d[i + 1, j] + 1)
                if j < NZ - 1:
                    v = min(v, d[i, j + 1] + 1)
                if i < NX - 1 and j < NZ - 1:
                    v = min(v, d[i + 1, j + 1] + 1.414)
                if i < NX - 1 and j:
                    v = min(v, d[i + 1, j - 1] + 1.414)
                d[i, j] = v
    return d


def report(write_svg=True):
    solids = all_solids()
    g = Grid(solids)
    print(f"Solids: {len(solids)} collision parts ({sum(1 for s in solids if s.shape == 'wedge')} wedges)")
    print(f"Standable nodes: {len(g.nodes)}")

    tA = g.times(SPAWNS_A)
    tB = g.times(SPAWNS_B)
    res = {}

    # Symmetry: the timing field must rotate onto itself.
    asym = 0.0
    for n in range(0, len(g.nodes), 37):
        i, j, h = g.nodes[n]
        for h2, m in g.by_cell.get((NX - 1 - i, NZ - 1 - j), ()):
            if abs(h2 - h) < 0.2 and np.isfinite(tA[n]):
                asym = max(asym, abs(tA[n] - tB[m]))
    print(f"Symmetry check (A times vs rotated B times): worst difference {asym:.2f} s")

    unreachable = sum(1 for n, (i, j, h) in enumerate(g.nodes) if h < 0.5 and not np.isfinite(tA[n]))
    print(f"Ground cells not reachable on foot: {unreachable}")

    print("\nSprint times from the Blue spawn (A):")
    targets = [
        ("plaza edge, through Blue Gate", (-5, -30, 0)),
        ("fountain", (0, -14, 0)),
        ("Cafe Terrace (high)", (40, -20, UPPER)),
        ("east alley, mid", (76, -26, 0)),
        ("west alley, mid", (-72, -26, 0)),
        ("east arcade, mid", (40, -16, 0)),
        ("west arcade, mid", (-40, -16, 0)),
        ("Green Gate (enemy side)", (5, 30, 0)),
        ("Green spawn (enemy)", (6, 118, 0)),
    ]
    for name, (x, z, h) in targets:
        n = g.node_at(x, z, h)
        t = tA[n]
        print(f"  {name:32s} {t:5.1f} s sprint, {t * SPRINT / WALK:5.1f} s walk")
        res[name] = t

    meet = np.min(np.maximum(tA, tB))
    print(f"\nEarliest meeting point (both arrive): {meet:.1f} s sprint, {meet * SPRINT / WALK:.1f} s walk")
    res["meet"] = meet

    T, pair = first_sight(g, tA, tB)
    res["first_sight"] = T
    if pair is not None:
        a, b = pair
        print(
            f"Time to first sight: {T:.1f} s sprint, {T * SPRINT / WALK:.1f} s walk "
            f"(A at ({a[0]:.0f}, {a[1] - EYE:.0f}, {a[2]:.0f}) sees B at ({b[0]:.0f}, {b[1] - EYE:.0f}, {b[2]:.0f}))"
        )
    res["first_pair"] = pair

    cross, frac, bad = spawn_safety(g, tA, tB)
    print("\nSpawn safety:")
    print(f"  any Blue spawn sees a Green spawn: {cross}")
    print(f"  enemy-held floor (Green gets there first) that sees a Blue spawn point: {100 * frac:.1f}%")
    for p in bad:
        print(f"    e.g. ({p[0]:.0f}, {p[1] - EYE:.0f}, {p[2]:.0f})")
    res["spawn_cross"], res["spawn_seen"] = cross, frac

    rays = ground_rays(g)
    over = sum(1 for r in rays if r[0] > 100)
    print(f"\nGround sight rays over 100 studs: {100 * over / len(rays):.1f}% of {len(rays)} sampled")
    print("Longest ground sightlines (eye height, low cover ignored):")
    shown, seen_keys = 0, set()
    for total, a, b in rays:
        key = (round(a[0] / 12), round(a[1] / 12), round(b[0] / 12), round(b[1] / 12))
        if key in seen_keys:
            continue
        seen_keys.add(key)
        print(f"  {total:.0f} studs  ({a[0]:.0f},{a[1]:.0f}) -> ({b[0]:.0f},{b[1]:.0f})")
        shown += 1
        if shown == 8:
            break
    res["longest"] = rays[0]
    res["rays_over_100"] = over / len(rays)

    # Cover spread in the plaza: distance from open ground to the nearest full-cover cell.
    blk = g.eye_block
    bi, bj = np.nonzero(blk & (np.abs(GX) < 50) & (np.abs(GZ) < 50))
    bpts = np.stack([XS[bi], ZS[bj]], axis=1)
    dists = []
    for x in range(-32, 33, 2):
        for z in range(-34, 35, 2):
            i, j = int(x + OUT_X), int(z + OUT_Z)
            if blk[i, j]:
                continue
            dists.append((float(np.min(np.hypot(bpts[:, 0] - x - 0.5, bpts[:, 1] - z - 0.5))), (x, z)))
    avg = sum(d for d, _ in dists) / len(dists)
    worst = max(dists)
    print(f"\nPlaza cover spread: average {avg:.1f} studs to full cover, furthest {worst[0]:.1f} at {worst[1]}")
    res["cover_avg"], res["cover_worst"] = avg, worst

    # Pinch check: erode the ground you can stand on by one more stud each side. Every
    # passage of a door's width (6) or more stays connected; floor that drops out of the
    # spawn's reach after the erosion is only reachable through something narrower.
    free = np.zeros((NX, NZ), bool)
    for n, (i, j, h) in enumerate(g.nodes):
        if h < 0.5 and np.isfinite(tA[n]):
            free[i, j] = True
    er = free.copy()
    for di in (-1, 0, 1):
        for dj in (-1, 0, 1):
            er &= np.roll(np.roll(free, di, axis=0), dj, axis=1)
    si, sj = int(SPAWNS_A[0][0] + OUT_X), int(SPAWNS_A[0][1] + OUT_Z)
    seen = np.zeros_like(er)
    stack = [(si, sj)]
    seen[si, sj] = True
    while stack:
        i, j = stack.pop()
        for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            a, b = i + di, j + dj
            if 0 <= a < NX and 0 <= b < NZ and er[a, b] and not seen[a, b]:
                seen[a, b] = True
                stack.append((a, b))
    lost = er & ~seen
    clusters = []
    for i, j in zip(*np.nonzero(lost)):
        x, z = XS[i], ZS[j]
        for c in clusters:
            if abs(c[0] - x) < 8 and abs(c[1] - z) < 8:
                c[2] += 1
                break
        else:
            clusters.append([x, z, 1])
    print(f"\nFloor reachable only through a gap under 6 studs: {int(lost.sum())} cells")
    for x, z, k in clusters[:10]:
        print(f"  near ({x:.0f}, {z:.0f}): {k} cells")
    res["pinch_cells"] = int(lost.sum())

    # Reach: highest floor reached on foot (with jumps), then 7.2 jump + 28 of Updraft.
    tj = g.times(SPAWNS_A, jump=JUMP - 0.7)
    hmax, at = 0.0, None
    for n, (i, j, h) in enumerate(g.nodes):
        if not np.isfinite(tj[n]):
            continue
        # Anything within two studs you can jump onto (a rail beside a terrace, a stall roof).
        near = g.tops[:, max(0, i - 2) : i + 3, max(0, j - 2) : j + 3]
        near = near[~np.isnan(near)]
        near = near[near <= h + JUMP - 0.7]
        top = float(near.max()) if near.size else h
        if top > hmax:
            hmax, at = top, (XS[i], ZS[j])
    reach = hmax + JUMP + UPDRAFT_BUDGET
    perim = min(b.eave for b in all_buildings() if b.klass == "perim")
    print(
        f"\nHighest floor without abilities: {hmax:.1f} at ({at[0]:.0f}, {at[1]:.0f}); + {JUMP} jump + "
        f"{UPDRAFT_BUDGET:.0f} Updraft = {reach:.1f} (perimeter houses are {perim:.0f})"
    )
    res["reach"], res["hmax"] = reach, hmax

    high = [n for n, (i, j, h) in enumerate(g.nodes) if h >= 10 and np.isfinite(tA[n])]
    print(f"High-layer floor (>= 10, on foot): {len(high)} cells")

    res["g"], res["tA"], res["tB"] = g, tA, tB
    if write_svg:
        SVG_OUT.parent.mkdir(parents=True, exist_ok=True)
        SVG_OUT.write_text(svg(res), encoding="utf-8")
        print(f"\nWrote {SVG_OUT.relative_to(ROOT)}")
    return res


# ---------------------------------------------------------------- SVG
FILL = {
    "perim": "#8C6E58",
    "bldg": "#D9C3A0",
    "arcade": "#B79C78",
    "floor": "#E8D8B8",
    "rail": "#F2E6CC",
    "stair": "#F5E9D0",
    "roof": "#B4532F",
    "cover": "#6F5B48",
    "low": "#CDB894",
    "lintel": "#A88E6E",
}


def svg(res) -> str:
    scale = 3.4
    pad = 50
    W = 2 * OUT_X * scale + 2 * pad + 300
    H = 2 * OUT_Z * scale + 2 * pad
    ox, oz = pad + OUT_X * scale, pad + OUT_Z * scale

    def P(x, z):
        # +Z (Green end) at the top of the page, Blue at the bottom.
        return ox + x * scale, oz - z * scale

    out = [
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W:.0f} {H:.0f}" font-family="Segoe UI, Arial, sans-serif">',
        f'<rect width="{W:.0f}" height="{H:.0f}" fill="#1F1B18"/>',
    ]
    # Ground: streets darker, plaza light.
    x0, z0 = P(-PLAY_X, PLAY_Z)
    out.append(f'<rect x="{x0:.1f}" y="{z0:.1f}" width="{2 * PLAY_X * scale:.1f}" height="{2 * PLAY_Z * scale:.1f}" fill="#9C8D7A"/>')
    for name, a, b, c, d in [(n, *r) for n, *r in FLOORS_A] + [(n + "'", -b, -a, -d, -c) for n, a, b, c, d in FLOORS_A]:
        px0, pz0 = P(a, d)
        out.append(
            f'<rect x="{px0:.1f}" y="{pz0:.1f}" width="{(b - a) * scale:.1f}" height="{(d - c) * scale:.1f}" fill="#D8C9AA"/>'
        )
    # Solids, lowest first; roofs drawn faint so the floor plan reads.
    order = ["ground", "floor", "low", "stair", "lintel", "arcade", "rail", "cover", "bldg", "perim", "roof"]
    sol = sorted(all_solids(), key=lambda s: (order.index(s.kind) if s.kind in order else 0, s.y1))
    for s in sol:
        if s.kind in ("ground",):
            continue
        fill = FILL.get(s.kind, "#999")
        op = 1.0
        if s.kind == "roof":
            op = 0.22
        if s.kind == "bldg" and s.y0 >= SLAB - 0.01:
            continue  # upper storeys: the ground plan shows the rooms
        if s.kind in ("floor",):
            op = 0.55
        if s.shape == "cyl":
            cx, cz = P(s.cx, s.cz)
            out.append(f'<circle cx="{cx:.1f}" cy="{cz:.1f}" r="{s.sx / 2 * scale:.1f}" fill="{fill}" stroke="#3A302A" stroke-width="1"/>')
            continue
        pts = " ".join("%.1f,%.1f" % P(*c) for c in s.corners())
        stroke = ' stroke="#3A302A" stroke-width="0.8"' if s.kind != "roof" else ""
        out.append(f'<polygon points="{pts}" fill="{fill}" fill-opacity="{op}"{stroke}/>')
        if s.shape == "wedge" and s.kind == "stair":
            (ax, az), (bx, bz) = s.axes()
            a = P(s.cx - bx * s.sz / 2.5, s.cz - bz * s.sz / 2.5)
            b = P(s.cx + bx * s.sz / 2.5, s.cz + bz * s.sz / 2.5)
            out.append(
                f'<line x1="{a[0]:.1f}" y1="{a[1]:.1f}" x2="{b[0]:.1f}" y2="{b[1]:.1f}" stroke="#3A302A" stroke-width="2" marker-end="url(#arr)"/>'
            )
    out.insert(2, '<defs><marker id="arr" markerWidth="6" markerHeight="6" refX="3" refY="3" orient="auto"><path d="M0,0 L6,3 L0,6 z" fill="#3A302A"/></marker></defs>')
    # High layer (terraces) outlined.
    for s in all_solids():
        if s.kind == "floor" and "Terrace" in s.name:
            pts = " ".join("%.1f,%.1f" % P(*c) for c in s.corners())
            out.append(f'<polygon points="{pts}" fill="#F2D27A" fill-opacity="0.65" stroke="#E0A526" stroke-width="2"/>')
    # Tower.
    tx0, tx1, tz0, tz1, _ = TOWER
    a = P(tx0, tz1)
    out.append(f'<rect x="{a[0]:.1f}" y="{a[1]:.1f}" width="{(tx1 - tx0) * scale:.1f}" height="{(tz1 - tz0) * scale:.1f}" fill="#5B4636" stroke="#F2E6CC" stroke-width="2"/>')

    # Longest ground sightline + first sight.
    total, a, b = res["longest"]
    pa, pb = P(*a), P(*b)
    out.append(
        f'<line x1="{pa[0]:.1f}" y1="{pa[1]:.1f}" x2="{pb[0]:.1f}" y2="{pb[1]:.1f}" stroke="#D1495B" stroke-width="2" stroke-dasharray="7 5"/>'
    )
    if res.get("first_pair") is not None:
        fa, fb = res["first_pair"]
        pa, pb = P(fa[0], fa[2]), P(fb[0], fb[2])
        out.append(
            f'<line x1="{pa[0]:.1f}" y1="{pa[1]:.1f}" x2="{pb[0]:.1f}" y2="{pb[1]:.1f}" stroke="#F4F1EA" stroke-width="2" stroke-dasharray="3 4"/>'
        )

    for spawns, side in ((SPAWNS_A, "A"), (SPAWNS_B, "B")):
        for s in spawns:
            sx, sz = P(*s)
            out.append(f'<circle cx="{sx:.1f}" cy="{sz:.1f}" r="5" fill="{ACCENT[side]}" stroke="#F4F1EA" stroke-width="1.2"/>')
    for name, x0_, x1_, z0_, z1_ in BARRIERS_A + [(n + "'", -b, -a, -d, -c) for n, a, b, c, d in BARRIERS_A]:
        a = P(x0_, z1_)
        side = "A" if z0_ < 0 else "B"
        out.append(f'<rect x="{a[0]:.1f}" y="{a[1]:.1f}" width="{(x1_ - x0_) * scale:.1f}" height="{(z1_ - z0_) * scale:.1f}" fill="{ACCENT[side]}" fill-opacity="0.6"/>')

    labels = [
        ((0, -122), "Blue Cloister"),
        ((0, -98), "Blue Lane"),
        ((0, -66), "Forecourt"),
        ((-5, -43), "Blue Gate"),
        ((0, 0), ""),
        ((40, -76), "Granary"),
        ((40, -64), "Bakery Lane"),
        ((40, -48), "Bakery"),
        ((56, -20), "Cafe"),
        ((39, -24), "Terrace"),
        ((51, 0), "Pavilion"),
        ((-56, -30), "Chemist"),
        ((-56, -20), "Lane"),
        ((-56, -10), "Bookshop"),
        ((-40, -64), "Market Court"),
        ((-40, -44), "Tavern"),
        ((-39, -20), "Arcade"),
        ((74, -60), "Alley"),
        ((-74, -60), "Alley"),
        ((0, -20), "Plaza"),
        ((87, 0), "Tower"),
    ]
    for (x, z), text in labels + [((-x, -z), t) for (x, z), t in labels if t not in ("Tower", "Plaza", "")]:
        if not text:
            continue
        t = text
        if z > 0:
            t = t.replace("Blue", "Green")
        tx, tz = P(x, z)
        out.append(f'<text x="{tx:.1f}" y="{tz + 4:.1f}" text-anchor="middle" font-size="10" fill="#1F1B18" font-weight="600">{t}</text>')

    kx = pad + 2 * OUT_X * scale + 30
    y = pad + 10
    out.append(f'<text x="{kx:.0f}" y="{y}" font-size="24" font-weight="700" fill="#F4F1EA">Old Town</text>')
    out.append(f'<text x="{kx:.0f}" y="{y + 22}" font-size="12" fill="#C9BBA6">Layout plan, 180° rotation. Green end on top.</text>')
    rows = [
        (FILL["perim"], "Perimeter houses, 52 tall"),
        (FILL["bldg"], "Two-storey houses (rooms open)"),
        (FILL["arcade"], "Arcade piers"),
        ("#F2D27A", "Cafe Terrace, high layer (12)"),
        (FILL["stair"], "Stair (arrow points up)"),
        (FILL["cover"], "Full cover, 7-8 tall"),
        (FILL["low"], "Low cover, 3 tall"),
        ("#D8C9AA", "Plaza and forecourt paving"),
        ("#9C8D7A", "Streets and alleys"),
        ("#5B4636", "Clock tower (out of reach)"),
    ]
    y += 50
    for colour, text in rows:
        out.append(f'<rect x="{kx:.0f}" y="{y}" width="18" height="18" fill="{colour}" stroke="#3A302A"/>')
        out.append(f'<text x="{kx + 28:.0f}" y="{y + 14}" font-size="13" fill="#F4F1EA">{text}</text>')
        y += 26
    for side, text in (("A", "Blue spawns and barriers"), ("B", "Green spawns and barriers")):
        out.append(f'<circle cx="{kx + 9:.0f}" cy="{y + 9}" r="6" fill="{ACCENT[side]}"/>')
        out.append(f'<text x="{kx + 28:.0f}" y="{y + 14}" font-size="13" fill="#F4F1EA">{text}</text>')
        y += 26
    out.append(f'<line x1="{kx:.0f}" y1="{y + 9}" x2="{kx + 20:.0f}" y2="{y + 9}" stroke="#D1495B" stroke-width="2" stroke-dasharray="7 5"/>')
    out.append(f'<text x="{kx + 28:.0f}" y="{y + 14}" font-size="13" fill="#F4F1EA">Longest ground line, {res["longest"][0]:.0f} studs</text>')
    y += 26
    out.append(f'<line x1="{kx:.0f}" y1="{y + 9}" x2="{kx + 20:.0f}" y2="{y + 9}" stroke="#F4F1EA" stroke-width="2" stroke-dasharray="3 4"/>')
    out.append(f'<text x="{kx + 28:.0f}" y="{y + 14}" font-size="13" fill="#F4F1EA">First sight, {res["first_sight"]:.1f} s sprinting</text>')
    y += 40
    facts = [
        f"Spawn to spawn: {SPAWNS_B[0][1] - SPAWNS_A[0][1]:.0f} studs",
        f"Playable {2 * PLAY_X:.0f} x {2 * PLAY_Z:.0f}",
        f"Plaza 68 x 72, fountain centre",
        f"Meet at {res['meet']:.1f} s sprinting",
        f"Reach {res['reach']:.0f} vs perimeter {PERIM_TOP:.0f}",
    ]
    for f in facts:
        out.append(f'<text x="{kx:.0f}" y="{y}" font-size="13" fill="#C9BBA6">{f}</text>')
        y += 20
    y += 10
    bar = 16 * scale
    out.append(f'<rect x="{kx:.0f}" y="{y}" width="{bar:.0f}" height="5" fill="#F4F1EA"/>')
    out.append(f'<text x="{kx:.0f}" y="{y + 22}" font-size="12" fill="#C9BBA6">16 studs</text>')
    out.append("</svg>")
    return "\n".join(out)


# ---------------------------------------------------------------- Luau
def lua_num(v: float) -> str:
    v = round(float(v), 3)
    return str(int(v)) if v == int(v) else repr(v)


def greybox_luau() -> str:
    solids = all_solids()
    rows = []
    for s in solids:
        if s.kind == "ground":
            continue
        rows.append(
            "\t{ %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s },"
            % (
                '"' + s.section + '"',
                '"' + s.name + '"',
                '"' + s.kind + '"',
                '"' + s.shape + '"',
                lua_num(s.cx),
                lua_num((s.y0 + s.y1) / 2),
                lua_num(s.cz),
                lua_num(s.sx),
                lua_num(s.y1 - s.y0),
                lua_num(s.sz),
                lua_num(s.yaw),
                '"' + s.side + '"',
                "true" if s.shell else "false",
            )
        )
    floors = []
    for name, a, b, c, d in FLOORS_A:
        floors.append(f'\t{{ "{name}_A", {lua_num(a)}, {lua_num(b)}, {lua_num(c)}, {lua_num(d)} }},')
        floors.append(f'\t{{ "{name}_B", {lua_num(-b)}, {lua_num(-a)}, {lua_num(-d)}, {lua_num(-c)} }},')
    spawns = []
    for team, pts in (("A", SPAWNS_A), ("B", SPAWNS_B)):
        for k, (x, z) in enumerate(pts):
            yaw = 180 if team == "A" else 0  # face the enemy end (-Z look for B, +Z for A)
            spawns.append(f'\t{{ "{team}", {k + 1}, {lua_num(x)}, {lua_num(z)}, {yaw} }},')
    barriers = []
    for name, a, b, c, d in BARRIERS_A:
        barriers.append(f'\t{{ "{name}", {lua_num((a + b) / 2)}, {lua_num((c + d) / 2)}, {lua_num(b - a)}, {lua_num(d - c)} }},')
        barriers.append(f'\t{{ "{name.replace("A_", "B_")}", {lua_num(-(a + b) / 2)}, {lua_num(-(c + d) / 2)}, {lua_num(b - a)}, {lua_num(d - c)} }},')
    return GREYBOX_TEMPLATE % {
        "rows": "\n".join(rows),
        "floors": "\n".join(floors),
        "spawns": "\n".join(spawns),
        "barriers": "\n".join(barriers),
        "out_x": lua_num(OUT_X),
        "out_z": lua_num(OUT_Z),
        "count": len(rows),
    }


GREYBOX_TEMPLATE = """--!strict
-- Old Town greybox (vault/01 Design/Maps/Old Town.md). GENERATED by
-- tools/maps/oldtown_layout.py --write from the checked layout: change the layout
-- there, rerun it, and this file follows. Bundle and run in the match place (edit mode):
--   python tools/studio/maps/bundle.py OldTown Greybox -o oldtown.luau
-- Builds Workspace.OldTown at (0, 200, 1500): Greybox (collision, %(count)s parts + floors),
-- Spawns (4 + 4, tagged) and Barriers (the cloister gates). Re-runnable: each section is
-- rebuilt. The art pass (Art.luau) hides what its meshes replace; nothing here is deleted.

newMap("OldTown", CFrame.new(0, 200, 1500))

-- section, name, kind, shape, centre x, y, z, size x, y, z (wedge: width, height, length;
-- cyl: diameter, height, diameter), yaw, side, shell (a building's outer wall: art covers it)
type Row = { any }
local ROWS: { Row } = {
%(rows)s
}

-- Paving zones over the ground slab (name, x0, x1, z0, z1).
local FLOORS: { { any } } = {
%(floors)s
}

-- Team, index, x, z, yaw (degrees; the pad faces the enemy end).
local SPAWNS: { { any } } = {
%(spawns)s
}

-- Name, centre x, z, width x, depth z (12 tall, in the cloister gates).
local BARRIERS: { { any } } = {
%(barriers)s
}

local function hex(s: string): Color3
	return Color3.fromHex(s)
end

-- Greybox looks by kind (warm greys: the art pass replaces most of them).
local LOOK: { [string]: { color: Color3, material: Enum.Material, castShadow: boolean? } } = {
	perim = { color = hex("#BFA98C"), material = Enum.Material.Plaster },
	bldg = { color = hex("#E3D3B5"), material = Enum.Material.Plaster },
	arcade = { color = hex("#D6C3A0"), material = Enum.Material.Limestone },
	floor = { color = hex("#E2D4B6"), material = Enum.Material.Limestone },
	rail = { color = hex("#EDE2C8"), material = Enum.Material.Limestone },
	stair = { color = hex("#D9C9A8"), material = Enum.Material.Limestone },
	roof = { color = hex("#B4532F"), material = Enum.Material.ClayRoofTiles },
	cover = { color = hex("#8A7259"), material = Enum.Material.WoodPlanks },
	low = { color = hex("#CDB894"), material = Enum.Material.Limestone, castShadow = false },
	lintel = { color = hex("#CDB894"), material = Enum.Material.Limestone },
}

local folders: { [string]: Folder } = {}
local function folder(name: string): Folder
	local f = folders[name]
	if f then
		return f
	end
	local made = section("Greybox", name)
	folders[name] = made
	return made
end

-- Ground: one slab under everything, then the paving zones (0.04 proud, no z-fighting).
local ground = folder("Ground")
box(ground, "Ground", Vector3.new(2 * %(out_x)s, 2, 2 * %(out_z)s), at(0, -1, 0), hex("#9C8D7A"), {
	material = Enum.Material.Cobblestone,
})
for _, f in FLOORS do
	local x0, x1, z0, z1 = f[2] :: number, f[3] :: number, f[4] :: number, f[5] :: number
	box(ground, f[1] :: string, Vector3.new(x1 - x0, 0.2, z1 - z0), at((x0 + x1) / 2, -0.06, (z0 + z1) / 2), hex("#D8C9AA"), {
		material = Enum.Material.Limestone,
		castShadow = false,
	})
end

local n = 0
for _, r in ROWS do
	local sec, name, kind, shape = r[1] :: string, r[2] :: string, r[3] :: string, r[4] :: string
	local x, y, z = r[5] :: number, r[6] :: number, r[7] :: number
	local sx, sy, sz, yaw = r[8] :: number, r[9] :: number, r[10] :: number, r[11] :: number
	local look = LOOK[kind] or LOOK.bldg
	local style = { material = look.material, castShadow = look.castShadow }
	local p: BasePart
	if shape == "wedge" then
		p = wedge(folder(sec), name, Vector3.new(sx, sy, sz), at(x, y, z, yaw), look.color, style)
	elseif shape == "cyl" then
		p = cyl(folder(sec), name, sy, sx, at(x, y, z), look.color, style)
	else
		p = box(folder(sec), name, Vector3.new(sx, sy, sz), at(x, y, z, yaw), look.color, style)
	end
	p:SetAttribute("Kind", kind)
	p:SetAttribute("Side", r[12] :: string)
	if r[13] then
		p:SetAttribute("Shell", true)
	end
	n += 1
end

spawnsClear()
for _, s in SPAWNS do
	spawnPad(s[1] :: string, s[2] :: number, at(s[3] :: number, 0, s[4] :: number, s[5] :: number))
end
for _, b in BARRIERS do
	barrier(b[1] :: string, Vector3.new(b[4] :: number, 10, b[5] :: number), at(b[2] :: number, 5, b[3] :: number))
end

report(string.format("OldTown greybox: %%d parts, %%d floors, %%d spawns, %%d barriers", n, #FLOORS, #SPAWNS, #BARRIERS))
"""


if __name__ == "__main__":
    res = report()
    if "--write" in sys.argv:
        out = ROOT / "tools/studio/maps/OldTown/Greybox.luau"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(greybox_luau(), encoding="utf-8")
        print(f"Wrote {out.relative_to(ROOT)}")
        try:
            sys.path.insert(0, str(Path(__file__).resolve().parent))
            import oldtown_art  # noqa: E402

            art = ROOT / "tools/studio/maps/OldTown/Art.luau"
            art.write_text(oldtown_art.art_luau(), encoding="utf-8")
            print(f"Wrote {art.relative_to(ROOT)}")
        except ImportError:
            print("oldtown_art.py not found: Art.luau not written")
