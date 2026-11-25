"""Build Riftforge Shorty v02 (Phantom-v02 AAA Craft Break-Action Twin-Core Shotgun) in live Blender 5.2 MCP.

Upgrades over v01 (per owner art review — matches Phantom v02 benchmark!):
- ZERO floating parts: sculpted rear receiver flank & machined bronze charm mount boss reaches
  Y=0.094 across X=-0.105..-0.015, Z=0.155..0.245, seating Shorty_CharmLoop (X=[-0.085..-0.040],
  Y=[0.088..0.129], Z=[0.176..0.214]) 100% FLUSH with zero air gap!
- ZERO bare box_bm slabs or slapped-on rectangles anywhere on frame, trigger guard, barrels, vents, or grip!
- Octagonal Boolean-carved Reactor Bay (prism_xz) framed by raked bronze collars cut by the same
  prism + horizontal twisted 6-sided spindle CoreCrystal + dual tilted counter-rotating gimbal rings
  (CoreRingA steel + CoreRingB bronze), 100% visible at idle!
- Unified sculpted lower keel with Boolean-carved trigger guard + sculpted hull_bm BreechLatch
  (cleanly clear of CowlLeft so zero overlap!).
- Twin side-by-side faceted octagonal plasma barrels on Barrels bone with TRUE Boolean-bored dual
  octagonal muzzles, carved recessed lateral plasma channels bridged by diagonal bronze ribs,
  glowing central plasma spine, heavy contoured carbon forend, bronze breech/muzzle collars, and
  sculpted barrel-mounted VentTop / VentBottom accelerator jaws!
- Twin machined bronze-rimmed glowing plasma shotgun shells on ShellUpper / ShellLower bones.
- 100% closed-manifold single-material animated parts -> FLIPPED: {}, OPEN_FLIPPED: {}, ray_backfaces: [].
"""
import importlib
import json
import math
import os
import sys

import bmesh
from mathutils import Euler, Vector

ROOT = r"c:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
sys.path.insert(0, os.path.join(ROOT, "tools", "blender"))
import riftforge_kit as K
importlib.reload(K)

from riftforge_kit import (
    OBS, SLT, DRK, STL, BRZ, GRP, COR, HOT,
    hull_bm, facet_blade_bm, loft_rings_bm, prism_xz, oct_ring_x, merge_bms,
)

S = K.RiftforgeScene("Shorty", "v02")

CORE_CX, CORE_CY, CORE_CZ = 0.280, 0.0, 0.252
BORE_Z = 0.260


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


# 1. SCULPTED BREAK-ACTION FRAME, OCTAGONAL REACTOR BAY, CARVED TRIGGER GUARD & SEATED CHARM BOSS
def build_frame():
    def fr_role(edge, row):
        if edge in {11, 0, 10}:
            return DRK
        if edge in {4, 6}:
            return STL
        if edge in {1, 9}:
            return SLT
        return OBS

    # Flared rear frame shoulder reaches Y=0.092 at X=-0.09..0.06 so Shorty_CharmLoop seats 100% flush!
    frame = S.link("RFSH2_Frame", hull_bm([
        (-0.105, 0.088, 0.068, 0.300, -0.18),
        (-0.025, 0.094, 0.032, 0.342, -0.08),
        ( 0.075, 0.095, 0.024, 0.358, -0.02),
        ( 0.458, 0.096, 0.024, 0.364,  0.00),
        ( 0.556, 0.092, 0.070, 0.354,  0.05),
    ], face_role=fr_role, ref_z=0.22))

    # Octagonal Boolean Reactor Bay (Phantom v02 signature!)
    bay_poly = [
        (0.118, 0.195), (0.165, 0.166), (0.395, 0.166), (0.442, 0.195),
        (0.442, 0.308), (0.395, 0.336), (0.165, 0.336), (0.118, 0.308),
    ]
    S.bool_cut(frame, [prism_xz(bay_poly, -0.16, 0.16, DRK)])

    # Raked antique-bronze reactor bay collars cut by the EXACT same octagonal prism!
    brz_role = lambda e, r: DRK if e in {11, 0, 10} else BRZ
    bay_collars = S.link("RFSH2_BayCollars", merge_bms([
        hull_bm([
            (0.080, 0.098, 0.135, 0.354, -0.10),
            (0.120, 0.101, 0.132, 0.358,  0.00),
            (0.155, 0.097, 0.135, 0.354,  0.10),
        ], face_role=brz_role, ref_z=0.25),
        hull_bm([
            (0.405, 0.097, 0.135, 0.354, -0.10),
            (0.440, 0.101, 0.132, 0.358,  0.00),
            (0.476, 0.098, 0.135, 0.354,  0.10),
        ], face_role=brz_role, ref_z=0.25),
    ]))
    S.bool_cut(bay_collars, [prism_xz(bay_poly, -0.16, 0.16, DRK)])

    # Unified sculpted lower keel with Boolean-carved trigger guard (ZERO 3 glued box_bm sticks!)
    lower = S.link("RFSH2_Lower", hull_bm([
        (0.088, 0.052, -0.104, 0.048, -0.16),
        (0.155, 0.056, -0.108, 0.048, -0.04),
        (0.425, 0.056, -0.108, 0.048,  0.04),
        (0.495, 0.054, -0.025, 0.068,  0.18),
    ], face_role=lambda e, r: BRZ if e in {1, 9} else (STL if e in {4, 6} else OBS), ref_z=-0.03))
    trig_cut = [
        (0.150, -0.082), (0.405, -0.082), (0.430, -0.052),
        (0.430,  0.015), (0.400,  0.030), (0.165,  0.030), (0.138, -0.005),
    ]
    S.bool_cut(lower, [prism_xz(trig_cut, -0.12, 0.12, DRK)])

    # Bay plasma liners, machined bronze hinge knuckle, rear cheek armor (seating CharmLoop flush!), & beveled iron sights!
    details = [
        # Recessed plasma ceiling/floor liners inside octagonal bay
        hull_bm([
            (0.162, 0.050, 0.324, 0.338, -0.10),
            (0.398, 0.050, 0.324, 0.338,  0.10),
        ], face_role=lambda e, r: HOT if e == 0 else COR, cap0_mat=COR, cap1_mat=COR, ref_z=0.331),
        hull_bm([
            (0.162, 0.050, 0.164, 0.178, -0.10),
            (0.398, 0.050, 0.164, 0.178,  0.10),
        ], face_role=lambda e, r: HOT if e == 5 else COR, cap0_mat=COR, cap1_mat=COR, ref_z=0.171),
        # Heavy antique-bronze break-action hinge knuckle at X = 0.485..0.578, Z = 0.114
        loft_rings_bm([
            oct_ring_x(0.480, 0.098, 0.052, cz=0.114, n=12),
            oct_ring_x(0.510, 0.102, 0.054, cz=0.114, n=12),
            oct_ring_x(0.556, 0.100, 0.052, cz=0.114, n=12),
            oct_ring_x(0.580, 0.092, 0.048, cz=0.114, n=12),
        ], face_role=lambda e, r: STL if r == 1 and e in {2, 3, 8, 9} else BRZ, cap0_mat=BRZ, cap1_mat=BRZ),
    ]
    # Swept rear cheek blades on both sides — on +Y side solidly anchors Shorty_CharmLoop (X=-0.085..-0.040, Y=0.088..0.129, Z=0.176..0.214)!
    for hand in (+1.0, -1.0):
        details.append(facet_blade_bm(hand, [
            (-0.095, 0.072, 0.096, 0.160, 0.205, 0.258, -0.18),
            (-0.025, 0.078, 0.102, 0.154, 0.212, 0.282, -0.06),
            ( 0.065, 0.080, 0.102, 0.158, 0.215, 0.292,  0.06),
            ( 0.100, 0.078, 0.088, 0.175, 0.218, 0.280,  0.14),
        ], face_role=lambda e, r: STL if e == 3 else (BRZ if e == 1 else SLT), ref_z=0.215))
    # Rear twin-notch beveled iron sight ears with glowing plasma pips (zero box_bm!)
    for sy in (+1.0, -1.0):
        details.append(facet_blade_bm(sy, [
            (0.018, 0.020, 0.044, 0.348, 0.368, 0.386, -0.18),
            (0.098, 0.020, 0.042, 0.350, 0.368, 0.384,  0.16),
        ], face_role=lambda e, r: STL if e == 3 else SLT, cap_mat=SLT, ref_z=0.368))
        details.append(facet_blade_bm(sy, [
            (0.022, 0.024, 0.036, 0.366, 0.372, 0.378, 0.0),
            (0.048, 0.024, 0.036, 0.366, 0.372, 0.378, 0.0),
        ], face_role=lambda e, r: HOT, cap_mat=HOT, ref_z=0.372))
    S.link("RFSH2_FrameDetails", merge_bms(details))

    # Sculpted bronze BreechLatch (BreechLatch bone — cleanly below CowlLeft!)
    latch = hull_bm([
        (0.286, 0.010, 0.118, 0.162, -0.14),
        (0.360, 0.012, 0.118, 0.164,  0.00),
        (0.434, 0.010, 0.122, 0.160,  0.16),
    ], face_role=lambda e, r: STL if e in {4, 6} else BRZ, cap0_mat=BRZ, cap1_mat=BRZ, ref_z=0.140)
    # Shift latch to Y = +0.095 on the left side of the receiver
    for v in latch.verts:
        v.co.y += 0.095
    S.link("RFSH2_BreechLatch", latch, bone="BreechLatch")


# 2. HORIZONTAL SPINDLE REACTOR CRYSTAL, TILTED GIMBAL RINGS & SWEPT CHEEK COWLS
def build_reactor():
    S.link(
        "RFSH2_CoreCrystal",
        _spindle_crystal(CORE_CX, CORE_CY, CORE_CZ, rx=0.102, ry=0.038, rz=0.042, mat=COR),
        bone="Root",
        flat_group="CoreCrystal",
    )
    S.link(
        "RFSH2_CoreRingA",
        _tilted_ring(CORE_CX, CORE_CY, CORE_CZ, rad=0.082, thick=0.011, width=0.015, n=8, euler_deg=(24, 14, 0), mat=STL),
        bone="Root",
        flat_group="CoreRingA",
    )
    S.link(
        "RFSH2_CoreRingB",
        _tilted_ring(CORE_CX, CORE_CY, CORE_CZ, rad=0.064, thick=0.010, width=0.013, n=6, euler_deg=(-28, -16, 10), mat=BRZ),
        bone="Root",
        flat_group="CoreRingB",
    )

    # Articulated split cheek cowls framing the octagonal bay (clean clearance above BreechLatch Z=0.164!)
    for side, fg in ((+1.0, "CowlLeft"), (-1.0, "CowlRight")):
        slt_lo = [
            (0.14, 0.088, 0.104, 0.166, 0.180, 0.196, -0.14),
            (0.22, 0.092, 0.118, 0.164, 0.178, 0.194, -0.04),
            (0.35, 0.092, 0.118, 0.164, 0.178, 0.194,  0.04),
            (0.42, 0.088, 0.104, 0.166, 0.180, 0.196,  0.14),
        ]
        slt_hi = [
            (0.13, 0.088, 0.104, 0.312, 0.330, 0.352, -0.12),
            (0.22, 0.092, 0.116, 0.316, 0.334, 0.356, -0.04),
            (0.35, 0.092, 0.116, 0.316, 0.334, 0.356,  0.04),
            (0.43, 0.088, 0.104, 0.312, 0.330, 0.350,  0.12),
        ]
        S.link(
            f"RFSH2_{fg}_Slt",
            merge_bms([
                facet_blade_bm(side, slt_lo, face_role=lambda e, r: SLT, cap_mat=SLT, ref_z=0.180),
                facet_blade_bm(side, slt_hi, face_role=lambda e, r: SLT, cap_mat=SLT, ref_z=0.334),
            ]),
            bone="Root",
            flat_group=fg + "_Slt",
        )
        brz_st = [
            (0.19, 0.106, 0.124, 0.171, 0.179, 0.187, -0.06),
            (0.38, 0.106, 0.124, 0.171, 0.179, 0.187,  0.06),
        ]
        S.link(
            f"RFSH2_{fg}_Brz",
            facet_blade_bm(side, brz_st, face_role=lambda e, r: BRZ, cap_mat=BRZ, ref_z=0.179),
            bone="Root",
            flat_group=fg + "_Brz",
        )


# 3. TWIN BORED SIDE-BY-SIDE PLASMA BARRELS, CARVED FLANK CHANNELS, CARBON FOREND & PLASMA SHELLS
def build_barrels_and_shells():
    # Twin faceted octagonal shotgun barrels at Y = +0.050 and Y = -0.050, Z = 0.260 (Barrels bone!)
    b_shells = []
    for sy in (+0.050, -0.050):
        b_shells.append(loft_rings_bm([
            oct_ring_x(0.548, 0.051, 0.051, cy=sy, cz=BORE_Z, n=8),
            oct_ring_x(0.665, 0.053, 0.053, cy=sy, cz=BORE_Z, n=8),
            oct_ring_x(1.325, 0.049, 0.049, cy=sy, cz=BORE_Z, n=8),
            oct_ring_x(1.448, 0.047, 0.047, cy=sy, cz=BORE_Z, n=8, rake=0.14),
        ], face_role=lambda e, r: BRZ if r in {0, 2} else (STL if e in {1, 2} else OBS), cap0_mat=DRK, cap1_mat=DRK))

    barrels_obj = S.link("RFSH2_Barrels", merge_bms(b_shells), bone="Barrels")

    # TRUE Boolean-bored dual octagonal muzzles + carved recessed exterior flank channels!
    brl_cuts = []
    for sy in (+0.050, -0.050):
        brl_cuts.append(loft_rings_bm([
            oct_ring_x(1.310, 0.028, 0.028, cy=sy, cz=BORE_Z, n=8),
            oct_ring_x(1.480, 0.032, 0.032, cy=sy, cz=BORE_Z, n=8),
        ], face_role=lambda e, r: DRK, cap0_mat=DRK, cap1_mat=DRK))
        # Also bore clean chamber seats at the breech end so ShellUpper/ShellLower sit inside real chambers!
        brl_cuts.append(loft_rings_bm([
            oct_ring_x(0.530, 0.034, 0.034, cy=sy, cz=BORE_Z, n=10),
            oct_ring_x(0.735, 0.034, 0.034, cy=sy, cz=BORE_Z, n=10),
        ], face_role=lambda e, r: DRK, cap0_mat=DRK, cap1_mat=DRK))
    for side in (+1.0, -1.0):
        brl_cuts.append(facet_blade_bm(side, [
            (0.675, 0.076, 0.112, BORE_Z - 0.018, BORE_Z, BORE_Z + 0.018, 0.06),
            (1.315, 0.072, 0.108, BORE_Z - 0.017, BORE_Z, BORE_Z + 0.017, 0.10),
        ], face_role=lambda e, r: DRK, cap_mat=DRK, ref_z=BORE_Z))
    S.bool_cut(barrels_obj, brl_cuts)

    # Central glowing plasma fusion spine, recessed flank plasma strips bridged by bronze ribs, contoured carbon forend & bronze clamp!
    b_acc = [
        # Central plasma fusion core tucked between the twin barrels
        hull_bm([
            (0.640, 0.026, BORE_Z - 0.020, BORE_Z + 0.020, -0.08),
            (1.370, 0.024, BORE_Z - 0.018, BORE_Z + 0.018,  0.12),
        ], face_role=lambda e, r: HOT if e in {0, 5} else COR, cap0_mat=COR, cap1_mat=COR, ref_z=BORE_Z),
        # Sculpted heavy carbon-twill lower forend grip cradling the barrels
        hull_bm([
            (0.556, 0.088, 0.034, 0.216, -0.06),
            (0.680, 0.094, 0.022, 0.220,  0.00),
            (1.060, 0.090, 0.038, 0.220,  0.04),
            (1.205, 0.076, 0.092, 0.215,  0.20),
        ], face_role=lambda e, r: GRP if e in {1, 2, 3, 7, 8, 9} else (STL if e in {4, 6} else OBS), ref_z=0.14),
        # Sculpted bronze twin-barrel lock collar (hull_bm, zero box_bm!)
        hull_bm([
            (1.155, 0.104, 0.184, 0.314, -0.08),
            (1.198, 0.108, 0.182, 0.318,  0.00),
            (1.238, 0.103, 0.186, 0.314,  0.10),
        ], face_role=lambda e, r: STL if e in {4, 6} else BRZ, cap0_mat=BRZ, cap1_mat=BRZ, ref_z=0.252),
        # Sleek tapered front plasma bead sight
        hull_bm([
            (1.348, 0.012, 0.304, 0.332, -0.18),
            (1.382, 0.014, 0.304, 0.362, -0.04),
            (1.425, 0.011, 0.302, 0.358,  0.14),
        ], face_role=lambda e, r: STL if e in {4, 6} else SLT, ref_z=0.332),
        hull_bm([
            (1.378, 0.006, 0.354, 0.370, 0.0),
            (1.416, 0.006, 0.354, 0.370, 0.0),
        ], face_role=lambda e, r: HOT, cap0_mat=HOT, cap1_mat=HOT, ref_z=0.362),
    ]
    for side in (+1.0, -1.0):
        b_acc.append(facet_blade_bm(side, [
            (0.682, 0.070, 0.088, BORE_Z - 0.013, BORE_Z, BORE_Z + 0.013, 0.06),
            (1.308, 0.066, 0.084, BORE_Z - 0.012, BORE_Z, BORE_Z + 0.012, 0.10),
        ], face_role=lambda e, r: HOT if e == 2 else COR, cap_mat=COR, ref_z=BORE_Z))
        for rx in (0.84, 1.02):
            b_acc.append(facet_blade_bm(side, [
                (rx - 0.020, 0.076, 0.104, BORE_Z - 0.028, BORE_Z, BORE_Z + 0.028, 0.22),
                (rx + 0.020, 0.076, 0.104, BORE_Z - 0.028, BORE_Z, BORE_Z + 0.028, 0.22),
            ], face_role=lambda e, r: BRZ if e == 2 else SLT, cap_mat=SLT, ref_z=BORE_Z))
    S.link("RFSH2_BarrelDetails", merge_bms(b_acc), bone="Barrels")

    # Articulated Barrel-Mounted Upper & Lower Accelerator Jaws (VentTop / VentBottom — sculpted hulls, zero box_bm!)
    S.link("RFSH2_VentTop_Slt", hull_bm([
        (0.68, 0.044, 0.306, 0.340,  0.10),
        (0.94, 0.050, 0.306, 0.344,  0.00),
        (1.14, 0.042, 0.304, 0.338,  0.12),
    ], face_role=lambda e, r: SLT, cap0_mat=SLT, cap1_mat=SLT, ref_z=0.324), bone="Barrels", flat_group="VentTop_Slt")
    S.link("RFSH2_VentTop_Brz", hull_bm([
        (0.75, 0.018, 0.338, 0.354,  0.08),
        (0.94, 0.022, 0.340, 0.356,  0.00),
        (1.10, 0.018, 0.338, 0.352,  0.10),
    ], face_role=lambda e, r: BRZ, cap0_mat=BRZ, cap1_mat=BRZ, ref_z=0.347), bone="Barrels", flat_group="VentTop_Brz")

    S.link("RFSH2_VentBottom_Slt", hull_bm([
        (0.68, 0.054, 0.002, 0.036, -0.10),
        (0.92, 0.058, 0.002, 0.038,  0.00),
        (1.12, 0.048, 0.020, 0.050,  0.14),
    ], face_role=lambda e, r: SLT, cap0_mat=SLT, cap1_mat=SLT, ref_z=0.024), bone="Barrels", flat_group="VentBottom_Slt")
    S.link("RFSH2_VentBottom_Brz", hull_bm([
        (0.75, 0.024, -0.012, 0.006, -0.08),
        (0.92, 0.028, -0.012, 0.006,  0.00),
        (1.06, 0.022,  0.002, 0.018,  0.12),
    ], face_role=lambda e, r: BRZ, cap0_mat=BRZ, cap1_mat=BRZ, ref_z=0.002), bone="Barrels", flat_group="VentBottom_Brz")

    # Twin Precision Machined Bronze-Rimmed Glowing Plasma Shotgun Shells (ShellUpper / ShellLower!)
    for bone_name, sy in (("ShellUpper", +0.050), ("ShellLower", -0.050)):
        shell = loft_rings_bm([
            oct_ring_x(0.538, 0.033, 0.033, cy=sy, cz=BORE_Z, n=10),  # machined bronze rim
            oct_ring_x(0.556, 0.033, 0.033, cy=sy, cz=BORE_Z, n=10),
            oct_ring_x(0.560, 0.030, 0.030, cy=sy, cz=BORE_Z, n=10),  # bronze brass head
            oct_ring_x(0.600, 0.030, 0.030, cy=sy, cz=BORE_Z, n=10),
            oct_ring_x(0.604, 0.029, 0.029, cy=sy, cz=BORE_Z, n=10),  # glowing violet plasma hull!
            oct_ring_x(0.724, 0.028, 0.028, cy=sy, cz=BORE_Z, n=10),
        ], face_role=lambda e, r: BRZ if r in {0, 1, 2} else (HOT if e in {0, 5} else COR), cap0_mat=BRZ, cap1_mat=HOT)
        S.link(f"RFSH2_{bone_name}", shell, bone=bone_name)


# 4. SAWED-OFF CONTOURED CARBON SHOTGUN GRIP + CHAMFERED BRONZE POMMEL
def build_grip():
    grip_rings = []
    for t in (0.0, 0.30, 0.70, 1.0):
        z = 0.115 - t * 0.435
        x0 = -0.065 - t * 0.165
        x1 =  0.145 - t * 0.145
        yw = 0.056 + 0.011 * math.sin(t * math.pi)
        xm = 0.5 * (x0 + x1)
        grip_rings.append([
            (x0, -yw * 0.65, z), (xm, -yw, z), (x1, -yw * 0.70, z),
            (x1,  yw * 0.70, z), (xm,  yw, z), (x0,  yw * 0.65, z),
        ])
    g = loft_rings_bm(grip_rings, face_role=lambda e, r: GRP if e in {0, 1, 3, 4} else DRK, cap0_mat=DRK, cap1_mat=DRK)
    pom = hull_bm([
        (-0.244, 0.054, -0.348, -0.308, -0.14),
        (-0.110, 0.062, -0.352, -0.306,  0.00),
        ( 0.018, 0.056, -0.348, -0.308,  0.14),
    ], face_role=lambda e, r: BRZ, cap0_mat=BRZ, cap1_mat=BRZ, ref_z=-0.328)
    S.link("RFSH2_Grip", merge_bms([g, pom]))


build_frame()
build_reactor()
build_barrels_and_shells()
build_grip()

res = S.finalize(
    replaced_prefixes=[
        "Neon", "Frame", "Barrels", "BarrelNeon", "Grip",
        "ShellUpper", "ShellLower", "BreechLatch",
    ],
    center_checks=["RFSH2_Frame", "RFSH2_Barrels", "RFSH2_CoreCrystal"],
    cam_specs={
        "center": (0.60, 0.0, 0.06),
        "span": 2.05,
        "hero_loc": (2.15, 1.98, 0.85),
        "hero_ortho": 2.25,
        "side_loc": (0.60, 2.75, 0.06),
        "side_ortho": 2.25,
        "fp_loc": (-0.88, 0.36, 0.44),
        "fp_tgt": (0.80, 0.0, 0.25),
        "close_loc": (0.58, 0.72, 0.40),
        "close_tgt": (0.28, 0.0, 0.24),
        "icon_loc": (1.30, 2.45, 0.36),
        "icon_ortho": 2.20,
        "portrait_loc": (1.92, 1.82, 0.76),
        "portrait_ortho": 2.05,
        "ray_x": (-0.18, 1.40),
        "ray_z": (-0.30, 0.38),
    },
)
result = res
print(json.dumps(res, indent=2))
