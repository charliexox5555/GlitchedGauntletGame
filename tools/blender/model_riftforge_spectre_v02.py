"""Build Riftforge Spectre v02 (Phantom-v02 AAA Craft Plasma PDW SMG) in live Blender 5.2 MCP.

Upgrades over v01 (per owner art review — matches Phantom v02 benchmark!):
- ZERO bare box_bm slabs or slapped-on rectangles anywhere on the chassis, sights, stock, or vents!
- Octagonal Boolean-carved cut-through Reactor Bay (prism_xz) framed by raked bronze collars cut
  by the exact same octagonal prism + horizontal twisted 6-sided spindle CoreCrystal + dual
  tilted counter-rotating gimbal rings (CoreRingA steel + CoreRingB bronze), 100% visible at idle!
- Unified sculpted lower receiver with Boolean-carved trigger guard & contoured magwell — zero
  floating bars, and clean clearance for stock Spectre_FireSelector at X=[0.14..0.24], Y=0.076..0.090, Z=0.196..0.229!
- Solidly seated Spectre_CharmLoop at X=[0.784..0.816], Y=[0.086..0.096], Z=[0.243..0.285]: sculpted
  handguard lower cheek & bronze mount boss reaches Y=0.092 across Z=0.23..0.30 at X=0.75..0.86!
- Carved recessed handguard & octagonal suppressor plasma channels bridged by swept diagonal
  bronze/slate armor ribs + true Boolean-bored hexagonal suppressor muzzle!
- Sculpted twin-spar collapsible PDW skeletal stock (multi-station lofted rods & buttpad, zero box_bm)
  + sleek faceted open hex-arch iron sights + beveled angled plasma stick mag.
- 100% closed-manifold single-material animated parts -> FLIPPED: {}, OPEN_FLIPPED: {}, ray_backfaces: [].
"""
import importlib
import json
import math
import os
import sys

import bmesh
from mathutils import Euler, Matrix, Vector

ROOT = r"c:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
sys.path.insert(0, os.path.join(ROOT, "tools", "blender"))
import riftforge_kit as K
importlib.reload(K)

from riftforge_kit import (
    OBS, SLT, DRK, STL, BRZ, GRP, COR, HOT,
    hull_bm, facet_blade_bm, loft_rings_bm, prism_xz, oct_ring_x, merge_bms,
)

S = K.RiftforgeScene("Spectre", "v02")

CORE_CX, CORE_CY, CORE_CZ = 0.305, 0.0, 0.338
BORE_Z = 0.353


def _spindle_crystal(cx, cy, cz, rx, ry, rz, mat=COR):
    """Phantom-v02 horizontal twisted 6-sided plasma spindle crystal."""
    stations = [
        (-1.00, 0.00, 0.00, 0.00),
        (-0.70, 0.64, 0.64, 0.16),
        (-0.24, 1.00, 1.00, 0.34),
        ( 0.24, 1.00, 1.00, 0.56),
        ( 0.70, 0.64, 0.64, 0.74),
        ( 1.00, 0.00, 0.00, 0.90),
    ]
    bm = bmesh.new()
    rings = []
    for tx, sy, sz, twist in stations:
        if sy <= 0.001:
            rings.append([bm.verts.new((cx + tx * rx, cy, cz))])
        else:
            r = []
            for j in range(6):
                a = 2.0 * math.pi * j / 6.0 + twist
                r.append(bm.verts.new((cx + tx * rx, cy + ry * sy * math.cos(a), cz + rz * sz * math.sin(a))))
            rings.append(r)
    for row in range(len(rings) - 1):
        a, b = rings[row], rings[row + 1]
        if len(a) == 1:
            for j in range(6):
                f = bm.faces.new((a[0], b[(j + 1) % 6], b[j]))
                f.material_index = mat
        elif len(b) == 1:
            for j in range(6):
                f = bm.faces.new((a[j], a[(j + 1) % 6], b[0]))
                f.material_index = mat
        else:
            for j in range(6):
                k = (j + 1) % 6
                f = bm.faces.new((a[j], a[k], b[k], b[j]))
                f.material_index = mat
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def _tilted_ring(cx, cy, cz, rad, thick, width, n, euler_deg, mat):
    """Phantom-v02 tilted faceted octagonal/hexagonal gimbal ring around the reactor core."""
    rot = Euler(tuple(math.radians(a) for a in euler_deg), "XYZ").to_matrix()
    center = Vector((cx, cy, cz))
    sec = [
        (-thick * 0.5, -width * 0.36),
        ( thick * 0.5, -width * 0.36),
        ( thick * 0.68, 0.0),
        ( thick * 0.5,  width * 0.36),
        (-thick * 0.5,  width * 0.36),
        (-thick * 0.68, 0.0),
    ]
    rings = []
    for i in range(n):
        a = 2.0 * math.pi * i / n + math.pi / n
        ca, sa = math.cos(a), math.sin(a)
        pts = []
        for dr, dw in sec:
            r = rad + dr
            p = center + (rot @ Vector((r * ca, dw, r * sa)))
            pts.append((p.x, p.y, p.z))
        rings.append(pts)
    return loft_rings_bm(rings, face_role=lambda e, r: mat, loop=True)


# 1. SCULPTED RECEIVER, OCTAGONAL BOOLEAN REACTOR BAY & CARVED LOWER KEEL
def build_receiver():
    def rec_role(edge, row):
        if edge in {11, 0, 10}:
            return DRK
        if edge in {4, 6}:
            return STL
        if edge in {1, 9}:
            return SLT
        return OBS

    rec = S.link("RFSP2_Receiver", hull_bm([
        (-0.335, 0.068, 0.175, 0.428, -0.18),
        (-0.220, 0.084, 0.140, 0.458, -0.06),
        ( 0.055, 0.088, 0.118, 0.466,  0.00),
        ( 0.675, 0.088, 0.118, 0.466,  0.00),
        ( 0.745, 0.086, 0.155, 0.464,  0.08),
    ], face_role=rec_role, ref_z=0.335))

    # Octagonal Boolean Reactor Bay (Phantom v02 signature!)
    bay_poly = [
        (0.110, 0.270), (0.165, 0.236), (0.445, 0.236), (0.500, 0.270),
        (0.500, 0.404), (0.445, 0.436), (0.165, 0.436), (0.110, 0.404),
    ]
    S.bool_cut(rec, [prism_xz(bay_poly, -0.16, 0.16, DRK)])

    # Raked antique-bronze reactor bay collars cut by the EXACT same octagonal prism!
    brz_role = lambda e, r: DRK if e in {11, 0, 10} else BRZ
    bay_collars = S.link("RFSP2_BayCollars", merge_bms([
        hull_bm([
            (0.068, 0.091, 0.182, 0.456, -0.12),
            (0.112, 0.094, 0.178, 0.460,  0.00),
            (0.152, 0.090, 0.182, 0.456,  0.10),
        ], face_role=brz_role, ref_z=0.335),
        hull_bm([
            (0.458, 0.090, 0.182, 0.456, -0.10),
            (0.498, 0.094, 0.178, 0.460,  0.00),
            (0.542, 0.091, 0.182, 0.456,  0.12),
        ], face_role=brz_role, ref_z=0.335),
    ]))
    S.bool_cut(bay_collars, [prism_xz(bay_poly, -0.16, 0.16, DRK)])

    # Glowing chamfered plasma ceiling/floor liners recessed cleanly inside the octagonal bay
    S.link("RFSP2_BayLiners", merge_bms([
        hull_bm([
            (0.162, 0.044, 0.422, 0.438, -0.12),
            (0.448, 0.044, 0.422, 0.438,  0.12),
        ], face_role=lambda e, r: HOT if e == 0 else COR, cap0_mat=COR, cap1_mat=COR, ref_z=0.430),
        hull_bm([
            (0.162, 0.044, 0.234, 0.250, -0.12),
            (0.448, 0.044, 0.234, 0.250,  0.12),
        ], face_role=lambda e, r: HOT if e == 5 else COR, cap0_mat=COR, cap1_mat=COR, ref_z=0.242),
    ]))

    # Swept rear cheek-armor blades flanking the upper rear receiver (clear of FireSelector!)
    cheeks = []
    for hand in (+1.0, -1.0):
        cheeks.append(facet_blade_bm(hand, [
            (-0.26, 0.062, 0.084, 0.280, 0.348, 0.415, -0.22),
            (-0.12, 0.072, 0.096, 0.270, 0.352, 0.432, -0.06),
            ( 0.04, 0.074, 0.096, 0.275, 0.352, 0.432,  0.08),
            ( 0.09, 0.070, 0.082, 0.292, 0.352, 0.415,  0.16),
        ], face_role=lambda e, r: STL if e == 3 else (BRZ if e == 1 else SLT), ref_z=0.350))
    S.link("RFSP2_RearCheeks", merge_bms(cheeks))

    # Unified sculpted lower receiver: integrates trigger guard + contoured angled magwell!
    lower = S.link("RFSP2_Lower", hull_bm([
        (0.060, 0.058,  0.016, 0.145, -0.16),
        (0.135, 0.062,  0.014, 0.145, -0.04),
        (0.395, 0.064,  0.014, 0.145,  0.04),
        (0.445, 0.074,  0.008, 0.155,  0.10),
        (0.610, 0.076,  0.004, 0.155,  0.08),
        (0.745, 0.070,  0.032, 0.175,  0.16),
    ], face_role=lambda e, r: BRZ if e in {1, 9} else (STL if e in {4, 6} else DRK), ref_z=0.085))
    trig_cut = [
        (0.118, 0.038), (0.378, 0.038), (0.402, 0.068),
        (0.402, 0.124), (0.372, 0.138), (0.128, 0.138), (0.106, 0.112),
    ]
    S.bool_cut(lower, [prism_xz(trig_cut, -0.12, 0.12, DRK)])


# 2. HORIZONTAL TWISTED SPINDLE CRYSTAL + DUAL TILTED GIMBAL RINGS + SWEPT COWLS
def build_reactor_core():
    S.link(
        "RFSP2_CoreCrystal",
        _spindle_crystal(CORE_CX, CORE_CY, CORE_CZ, rx=0.118, ry=0.042, rz=0.046, mat=COR),
        bone="Root",
        flat_group="CoreCrystal",
    )
    S.link(
        "RFSP2_CoreRingA",
        _tilted_ring(CORE_CX, CORE_CY, CORE_CZ, rad=0.094, thick=0.012, width=0.016, n=8, euler_deg=(24, 14, 0), mat=STL),
        bone="Root",
        flat_group="CoreRingA",
    )
    S.link(
        "RFSP2_CoreRingB",
        _tilted_ring(CORE_CX, CORE_CY, CORE_CZ, rad=0.074, thick=0.010, width=0.014, n=6, euler_deg=(-28, -16, 10), mat=BRZ),
        bone="Root",
        flat_group="CoreRingB",
    )

    # Articulated split reactor cowls (sleek upper/lower blades framing the open bay — clear of FireSelector!)
    for side, fg in ((+1.0, "CowlLeft"), (-1.0, "CowlRight")):
        slt_lo = [
            (0.12, 0.078, 0.094, 0.228, 0.244, 0.264, -0.14),
            (0.20, 0.082, 0.110, 0.224, 0.240, 0.260, -0.04),
            (0.42, 0.082, 0.110, 0.224, 0.240, 0.260,  0.04),
            (0.50, 0.078, 0.094, 0.228, 0.244, 0.264,  0.14),
        ]
        slt_hi = [
            (0.10, 0.078, 0.094, 0.408, 0.428, 0.452, -0.12),
            (0.20, 0.082, 0.108, 0.412, 0.432, 0.456, -0.04),
            (0.42, 0.082, 0.108, 0.412, 0.432, 0.456,  0.04),
            (0.51, 0.078, 0.094, 0.408, 0.428, 0.450,  0.12),
        ]
        S.link(
            f"RFSP2_{fg}_Slt",
            merge_bms([
                facet_blade_bm(side, slt_lo, face_role=lambda e, r: SLT, cap_mat=SLT, ref_z=0.242),
                facet_blade_bm(side, slt_hi, face_role=lambda e, r: SLT, cap_mat=SLT, ref_z=0.430),
            ]),
            bone="Root",
            flat_group=fg + "_Slt",
        )
        brz_st = [
            (0.18, 0.096, 0.116, 0.232, 0.241, 0.250, -0.06),
            (0.44, 0.096, 0.116, 0.232, 0.241, 0.250,  0.06),
        ]
        S.link(
            f"RFSP2_{fg}_Brz",
            facet_blade_bm(side, brz_st, face_role=lambda e, r: BRZ, cap_mat=BRZ, ref_z=0.241),
            bone="Root",
            flat_group=fg + "_Brz",
        )


# 3. HANDGUARD (SEATED CHARMLOOP!), CARVED RECESSED PLASMA SUPPRESSOR & OPEN HEX-ARCH SIGHTS
def build_front_and_sights():
    # Sculpted handguard reaching Y=0.092 across Z=0.22..0.46 at X=0.72..0.88 so Spectre_CharmLoop
    # (X=[0.784..0.816], Y=[0.086..0.096], Z=[0.243..0.285]) seats 100% FLUSH with ZERO float!
    hg = S.link("RFSP2_Handguard", hull_bm([
        (0.680, 0.090, 0.212, 0.466,  0.00),
        (0.840, 0.092, 0.218, 0.464,  0.00),  # solidly anchors Spectre_CharmLoop!
        (1.040, 0.086, 0.234, 0.460,  0.04),
        (1.140, 0.080, 0.252, 0.452,  0.14),
    ], face_role=lambda e, r: STL if e in {4, 6} else (SLT if e in {1, 9} else (DRK if e in {11, 0, 10} else OBS)), ref_z=0.352))

    # Carve recessed handguard flank plasma slots cleanly INTO the handguard!
    hg_cuts = []
    for sy in (+1.0, -1.0):
        hg_cuts.append(facet_blade_bm(sy, [
            (0.735, 0.062, 0.104, 0.326, 0.350, 0.376, 0.08),
            (1.085, 0.056, 0.098, 0.328, 0.352, 0.376, 0.14),
        ], face_role=lambda e, r: DRK, cap_mat=DRK, ref_z=0.352))
    S.bool_cut(hg, hg_cuts)

    # Recessed handguard plasma + diagonal bridging bronze ribs + contoured carbon lower grip + CharmLoop boss!
    hg_acc = [
        hull_bm([
            (0.740, 0.056, 0.200, 0.236, -0.10),
            (1.045, 0.052, 0.214, 0.248,  0.14),
        ], face_role=lambda e, r: GRP if e in {0, 1, 9, 10, 11} else DRK, cap0_mat=DRK, cap1_mat=DRK, ref_z=0.222),
        # Precision machined bronze charm mount cheek on left (+Y) flank seating Spectre_CharmLoop flush!
        facet_blade_bm(+1.0, [
            (0.752, 0.076, 0.092, 0.236, 0.264, 0.292, -0.14),
            (0.848, 0.076, 0.092, 0.236, 0.264, 0.292,  0.14),
        ], face_role=lambda e, r: BRZ if e in {1, 2} else SLT, cap_mat=BRZ, ref_z=0.264),
    ]
    for sy in (+1.0, -1.0):
        hg_acc.append(facet_blade_bm(sy, [
            (0.742, 0.054, 0.072, 0.334, 0.350, 0.368, 0.08),
            (1.078, 0.048, 0.066, 0.336, 0.352, 0.368, 0.14),
        ], face_role=lambda e, r: HOT if e == 2 else COR, cap_mat=COR, ref_z=0.352))
        for rx in (0.85, 0.99):
            hg_acc.append(facet_blade_bm(sy, [
                (rx - 0.022, 0.064, 0.090, 0.318, 0.352, 0.386, 0.22),
                (rx + 0.022, 0.064, 0.090, 0.318, 0.352, 0.386, 0.22),
            ], face_role=lambda e, r: BRZ if e == 2 else SLT, cap_mat=SLT, ref_z=0.352))
    S.link("RFSP2_HandguardDetails", merge_bms(hg_acc))

    # Sleek tapered octagonal plasma suppressor (X = 1.125..1.905, bore Z = 0.353) with carved flank slots + true muzzle bore!
    supp = S.link("RFSP2_Suppressor", loft_rings_bm([
        oct_ring_x(1.125, 0.082, 0.082, cz=BORE_Z),
        oct_ring_x(1.225, 0.086, 0.086, cz=BORE_Z),
        oct_ring_x(1.785, 0.076, 0.076, cz=BORE_Z),
        oct_ring_x(1.905, 0.068, 0.068, cz=BORE_Z, rake=0.14),
    ], face_role=lambda e, r: BRZ if r in {0, 2} else (STL if e in {1, 2} else OBS), cap0_mat=DRK, cap1_mat=DRK))

    supp_cuts = [
        # True recessed octagonal suppressor bore!
        loft_rings_bm([
            oct_ring_x(1.760, 0.030, 0.030, cz=BORE_Z, n=8),
            oct_ring_x(1.940, 0.034, 0.034, cz=BORE_Z, n=8),
        ], face_role=lambda e, r: DRK, cap0_mat=DRK, cap1_mat=DRK),
    ]
    for sy in (+1.0, -1.0):
        supp_cuts.append(facet_blade_bm(sy, [
            (1.235, 0.056, 0.096, BORE_Z - 0.022, BORE_Z, BORE_Z + 0.022, 0.06),
            (1.775, 0.048, 0.090, BORE_Z - 0.020, BORE_Z, BORE_Z + 0.020, 0.10),
        ], face_role=lambda e, r: DRK, cap_mat=DRK, ref_z=BORE_Z))
    S.bool_cut(supp, supp_cuts)

    # Recessed suppressor plasma channels + 2 precision octagonal baffle collars!
    supp_acc = []
    for sy in (+1.0, -1.0):
        supp_acc.append(facet_blade_bm(sy, [
            (1.242, 0.048, 0.068, BORE_Z - 0.016, BORE_Z, BORE_Z + 0.016, 0.06),
            (1.768, 0.040, 0.060, BORE_Z - 0.015, BORE_Z, BORE_Z + 0.015, 0.10),
        ], face_role=lambda e, r: HOT if e == 2 else COR, cap_mat=COR, ref_z=BORE_Z))
    for rx in (1.40, 1.62):
        supp_acc.append(loft_rings_bm([
            oct_ring_x(rx - 0.024, 0.088, 0.088, cz=BORE_Z),
            oct_ring_x(rx,         0.092, 0.092, cz=BORE_Z),
            oct_ring_x(rx + 0.024, 0.088, 0.088, cz=BORE_Z),
        ], face_role=lambda e, r: STL if e in {1, 2, 5, 6} else SLT, cap0_mat=SLT, cap1_mat=SLT))
    S.link("RFSP2_SuppressorDetails", merge_bms(supp_acc))

    # Articulated top/bottom suppressor accelerator vents (VentTop / VentBottom — sculpted hulls, zero box_bm!)
    for sign, fg in ((+1.0, "VentTop"), (-1.0, "VentBottom")):
        z0 = BORE_Z + sign * 0.072
        z1 = BORE_Z + sign * 0.102
        z_lo, z_hi = min(z0, z1), max(z0, z1)
        S.link(
            f"RFSP2_{fg}_Slt",
            hull_bm([
                (1.24, 0.036, z_lo, z_hi, 0.10 * sign),
                (1.50, 0.042, z_lo, z_hi, 0.00),
                (1.74, 0.030, z_lo, z_hi, 0.12 * sign),
            ], face_role=lambda e, r: SLT, cap0_mat=SLT, cap1_mat=SLT, ref_z=0.5 * (z_lo + z_hi)),
            bone="Root",
            flat_group=fg + "_Slt",
        )
        bz0 = BORE_Z + sign * 0.096
        bz1 = BORE_Z + sign * 0.112
        bz_lo, bz_hi = min(bz0, bz1), max(bz0, bz1)
        S.link(
            f"RFSP2_{fg}_Brz",
            hull_bm([
                (1.30, 0.016, bz_lo, bz_hi, 0.08 * sign),
                (1.50, 0.020, bz_lo, bz_hi, 0.00),
                (1.68, 0.015, bz_lo, bz_hi, 0.08 * sign),
            ], face_role=lambda e, r: BRZ, cap0_mat=BRZ, cap1_mat=BRZ, ref_z=0.5 * (bz_lo + bz_hi)),
            bone="Root",
            flat_group=fg + "_Brz",
        )

    # Sculpted open hex-arch iron sights (Boolean-carved arch, zero glued box_bm sticks!)
    rear_sight = S.link("RFSP2_RearSight", hull_bm([
        (-0.055, 0.056, 0.456, 0.590, -0.14),
        ( 0.015, 0.060, 0.456, 0.596,  0.00),
        ( 0.085, 0.054, 0.456, 0.588,  0.14),
    ], face_role=lambda e, r: BRZ if e == 5 else (STL if e in {4, 6} else SLT), ref_z=0.525))
    # Carve clean hexagonal ADS sight window straight through rear sight (X axis!)
    win_rings = [
        oct_ring_x(-0.08, 0.036, 0.046, cz=0.534, n=6),
        oct_ring_x( 0.11, 0.036, 0.046, cz=0.534, n=6),
    ]
    S.bool_cut(rear_sight, [loft_rings_bm(win_rings, face_role=lambda e, r: DRK, cap0_mat=DRK, cap1_mat=DRK)])

    # Front sculpted hooded twin-wing post + glowing lilac dot
    front_sights = [
        hull_bm([
            (0.955, 0.008, 0.454, 0.546, -0.10),
            (1.015, 0.009, 0.454, 0.546,  0.10),
        ], face_role=lambda e, r: SLT, cap0_mat=SLT, cap1_mat=SLT, ref_z=0.50),
        hull_bm([
            (0.972, 0.006, 0.538, 0.558, 0.0),
            (1.008, 0.006, 0.538, 0.558, 0.0),
        ], face_role=lambda e, r: HOT, cap0_mat=HOT, cap1_mat=HOT, ref_z=0.548),
    ]
    for sy in (+1.0, -1.0):
        front_sights.append(facet_blade_bm(sy, [
            (0.942, 0.022, 0.044, 0.452, 0.512, 0.562, -0.16),
            (1.042, 0.022, 0.042, 0.452, 0.512, 0.556,  0.18),
        ], face_role=lambda e, r: STL if e == 3 else SLT, cap_mat=SLT, ref_z=0.51))
    S.link("RFSP2_FrontSight", merge_bms(front_sights))


# 4. SCULPTED PDW SKELETAL STOCK, CONTOURED CARBON GRIP & ANGLED PLASMA STICK MAG
def build_stock_grip_mag():
    # Collapsible twin-rod PDW stock (octagonal steel guide rods + sculpted buttpad + recessed plasma bar!)
    stock_parts = [
        # Twin faceted octagonal steel slide rails
        loft_rings_bm([
            oct_ring_x(-1.015, 0.015, 0.022, cy=+0.056, cz=0.335, n=8),
            oct_ring_x(-0.295, 0.015, 0.022, cy=+0.056, cz=0.335, n=8),
        ], face_role=lambda e, r: STL if e in {1, 2, 5, 6} else SLT, cap0_mat=STL, cap1_mat=STL),
        loft_rings_bm([
            oct_ring_x(-1.015, 0.015, 0.022, cy=-0.056, cz=0.335, n=8),
            oct_ring_x(-0.295, 0.015, 0.022, cy=-0.056, cz=0.335, n=8),
        ], face_role=lambda e, r: STL if e in {1, 2, 5, 6} else SLT, cap0_mat=STL, cap1_mat=STL),
        # Lower angled skeletal strut tying buttpad heel back cleanly into rear receiver!
        hull_bm([
            (-1.020, 0.032, -0.055, 0.020,  0.00),
            (-0.740, 0.036,  0.075, 0.145, -0.08),
            (-0.315, 0.052,  0.185, 0.255, -0.14),
        ], face_role=lambda e, r: STL if e in {4, 6} else (SLT if e in {1, 9} else OBS), ref_z=0.12),
        # Sculpted forged buttpad + bronze heel trim
        hull_bm([
            (-1.068, 0.060, -0.108, 0.390, -0.04),
            (-0.968, 0.068, -0.088, 0.402,  0.00),
            (-0.885, 0.064,  0.195, 0.398,  0.12),
        ], face_role=lambda e, r: BRZ if r == 0 else (STL if e in {4, 6} else OBS), ref_z=0.21),
        # Contoured carbon cheek rest bridging the upper rods
        hull_bm([
            (-0.920, 0.054, 0.348, 0.404, -0.08),
            (-0.650, 0.058, 0.352, 0.408,  0.00),
            (-0.390, 0.052, 0.348, 0.402,  0.10),
        ], face_role=lambda e, r: GRP, cap0_mat=DRK, cap1_mat=DRK, ref_z=0.376),
        # Glowing violet stock spine cell tucked neatly under cheek rest
        hull_bm([
            (-0.890, 0.030, 0.318, 0.346, -0.08),
            (-0.430, 0.030, 0.318, 0.346,  0.08),
        ], face_role=lambda e, r: HOT if e == 0 else COR, cap0_mat=COR, cap1_mat=COR, ref_z=0.332),
    ]
    S.link("RFSP2_Stock", merge_bms(stock_parts))

    # Ergonomic contoured carbon pistol grip + bronze heel pommel
    grip_rings = []
    for t in (0.0, 0.30, 0.70, 1.0):
        z = 0.140 - t * 0.415
        x0 = -0.085 - t * 0.105
        x1 =  0.118 - t * 0.085
        yw = 0.050 + 0.009 * math.sin(t * math.pi)
        xm = 0.5 * (x0 + x1)
        grip_rings.append([
            (x0, -yw * 0.64, z), (xm, -yw, z), (x1, -yw * 0.70, z),
            (x1,  yw * 0.70, z), (xm,  yw, z), (x0,  yw * 0.64, z),
        ])
    g_body = loft_rings_bm(grip_rings, face_role=lambda e, r: GRP if e in {0, 1, 3, 4} else DRK, cap0_mat=DRK, cap1_mat=DRK)
    g_pom = hull_bm([
        (-0.205, 0.048, -0.302, -0.268, -0.14),
        (-0.080, 0.056, -0.304, -0.266,  0.00),
        ( 0.045, 0.050, -0.302, -0.268,  0.14),
    ], face_role=lambda e, r: BRZ, cap0_mat=BRZ, cap1_mat=BRZ, ref_z=-0.285)
    S.link("RFSP2_Grip", merge_bms([g_body, g_pom]))

    # Long angled SMG plasma stick magazine (Mag bone!) with beveled bronze baseplate & plasma flank channels
    mag_rings = []
    for t in (0.0, 0.35, 0.75, 1.0):
        z = 0.132 - t * 0.680
        x_fwd = 0.665 + t * 0.175
        x_aft = 0.445 + t * 0.155
        yw = 0.054 - t * 0.006
        xm = 0.5 * (x_aft + x_fwd)
        mag_rings.append([
            (x_aft, -yw * 0.72, z), (xm, -yw, z), (x_fwd, -yw * 0.72, z),
            (x_fwd,  yw * 0.72, z), (xm,  yw, z), (x_aft,  yw * 0.72, z),
        ])
    mag_body = loft_rings_bm(mag_rings, face_role=lambda e, r: STL if e in {2, 5} else OBS, cap0_mat=DRK, cap1_mat=BRZ)
    mag_base = hull_bm([
        (0.585, 0.054, -0.578, -0.538, -0.12),
        (0.725, 0.058, -0.582, -0.538,  0.00),
        (0.855, 0.054, -0.578, -0.538,  0.14),
    ], face_role=lambda e, r: BRZ, cap0_mat=BRZ, cap1_mat=BRZ, ref_z=-0.558)
    mag_glow = []
    for side in (+1, -1):
        p_rings = []
        for t in (0.12, 0.86):
            z = 0.132 - t * 0.680
            xm = 0.555 + t * 0.165
            yw = (0.054 - t * 0.006) * side
            p_rings.append([
                (xm - 0.036, yw * 0.88, z), (xm + 0.036, yw * 0.88, z),
                (xm + 0.028, yw * 1.12, z), (xm - 0.028, yw * 1.12, z),
            ])
        if side < 0:
            p_rings = [list(reversed(r)) for r in p_rings]
        mag_glow.append(loft_rings_bm(p_rings, face_role=lambda e, r: HOT if e == 2 else COR, cap0_mat=COR, cap1_mat=COR))
    S.link("RFSP2_Mag", merge_bms([mag_body, mag_base] + mag_glow), bone="Mag")


build_receiver()
build_reactor_core()
build_front_and_sights()
build_stock_grip_mag()

res = S.finalize(
    replaced_prefixes=[
        "Neon", "Receiver", "Handguard", "Suppressor", "Grip",
        "Stock", "Mag", "Sights", "Pins", "ChargingHandle", "Bolt",
    ],
    center_checks=["RFSP2_Receiver", "RFSP2_Suppressor", "RFSP2_CoreCrystal", "RFSP2_RearSight"],
    cam_specs={
        "center": (0.42, 0.0, 0.12),
        "span": 3.2,
        "hero_loc": (2.85, 2.75, 1.25),
        "hero_ortho": 3.45,
        "side_loc": (0.42, 3.85, 0.12),
        "side_ortho": 3.45,
        "fp_loc": (-1.20, 0.52, 0.72),
        "fp_tgt": (0.85, 0.0, 0.35),
        "close_loc": (0.65, 0.86, 0.52),
        "close_tgt": (0.30, 0.0, 0.335),
        "icon_loc": (1.65, 3.55, 0.62),
        "icon_ortho": 3.35,
        "portrait_loc": (2.55, 2.55, 1.08),
        "portrait_ortho": 3.15,
        "ray_x": (-0.95, 1.85),
        "ray_z": (-0.50, 0.55),
    },
)
result = res
print(json.dumps(res, indent=2))
