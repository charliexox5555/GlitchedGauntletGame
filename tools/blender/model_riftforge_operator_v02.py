"""Build Riftforge Operator v02 (Phantom-v02-Grade Precision Plasma Rail-Sniper) in live Blender 5.2 MCP.

Complete ground-up resculpt matching Phantom v02's exact craft & gauntlet-model-joins:
- ZERO bare box_bm rectangles anywhere on the silhouette! Every hull, keel, trigger guard,
  scope mount, handguard, buttstock, and rail shroud is a swept compound-faceted multi-station loft.
- Octagonal Boolean cut-through Reactor Core Bay framed by raked bronze collars & swept
  rear shoulder cheek-armor blades (identical DNA to Phantom v02!), housing horizontal twisted
  hexagonal spindle CoreCrystal + dual tilted counter-rotating gimbal rings (CoreRingA/B).
- Solidly seats stock Operator_CharmLoop at (0.945, 0.092, 0.139) into a sculpted chassis boss
  with zero floating parts!
- Sleek monolithic tapered handguard with recessed glowing plasma vents bridged by swept slate
  baffle ribs (never flat neon blocks stuck to the outside!).
- Swept aerodynamic twin-rail plasma barrel + sculpted twin-fang faceted railgun muzzle brake.
- Sculpted raked cantilevered scope mount + sleek 12-sided ergonomic sniper optic with chamfered
  octagonal turrets and deeply recessed violet lenses.
- Precision compound-faceted skeletal sniper stock flowing seamlessly into grip & cheek riser.
- 100% closed-manifold single-material animated parts -> FLIPPED: {}, OPEN_FLIPPED: {}, ray_backfaces: [].
"""
import importlib
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = r"c:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
sys.path.insert(0, os.path.join(ROOT, "tools", "blender"))
import riftforge_kit as K
importlib.reload(K)

from riftforge_kit import (
    OBS, SLT, DRK, STL, BRZ, GRP, COR, HOT,
    hull_bm, facet_blade_bm, loft_rings_bm, prism_xz, oct_ring_x, merge_bms,
)

S = K.RiftforgeScene("Operator", "v02")

CORE_CX, CORE_CY, CORE_CZ = 0.640, 0.0, 0.340
BORE_Z = 0.385
SCOPE_Z = 0.618


def _spindle_crystal(cx, cy, cz, rx_tip=0.115, rx_mid=0.056, ry_w=0.062, rz_w=0.070, mat=COR):
    """Phantom-v02 signature twisted hexagonal spindle plasma prism (100% closed manifold)."""
    bm = bmesh.new()
    n = 6
    def ring(x, ry, rz, phase=0.0):
        return [bm.verts.new((x, cy + ry * math.cos(phase + 2 * math.pi * i / n),
                              cz + rz * math.sin(phase + 2 * math.pi * i / n))) for i in range(n)]
    tf = bm.verts.new((cx + rx_tip, cy, cz))
    tr = bm.verts.new((cx - rx_tip, cy, cz))
    rf = ring(cx + rx_mid, ry_w * 0.84, rz_w * 0.84, math.pi / 6)
    rw = ring(cx,          ry_w,        rz_w,        0.0)
    rr = ring(cx - rx_mid, ry_w * 0.84, rz_w * 0.84, math.pi / 6)
    for i in range(n):
        j = (i + 1) % n
        for tri in (
            (tf, rf[i], rf[j]),
            (rf[i], rw[i], rf[j]), (rf[j], rw[i], rw[j]),
            (rw[i], rr[i], rw[j]), (rw[j], rr[i], rr[j]),
            (tr, rr[j], rr[i]),
        ):
            f = bm.faces.new(tri)
            f.material_index = mat
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def _tilted_ring(cx, cy, cz, n_sides, r_in, r_out, hw, tilt_x, tilt_z, mat):
    """Phantom-v02 signature tilted counter-rotating gyroscopic gimbal ring (closed manifold)."""
    bm = bmesh.new()
    tilt = Matrix.Rotation(math.radians(tilt_x), 3, "X") @ Matrix.Rotation(math.radians(tilt_z), 3, "Z")
    ctr = Vector((cx, cy, cz))
    rings = []
    for i in range(n_sides):
        a = 2.0 * math.pi * i / n_sides
        ca, sa = math.cos(a), math.sin(a)
        rm = 0.5 * (r_in + r_out)
        sec = [
            (r_in, -hw * 0.6), (rm, -hw), (r_out, -hw * 0.6),
            (r_out, hw * 0.6), (rm,  hw), (r_in,   hw * 0.6),
        ]
        rings.append([ctr + tilt @ Vector((r * ca, y, r * sa)) for r, y in sec])
    bm.free()
    return loft_rings_bm(rings, face_role=lambda e, r: mat, loop=True)


# 1. SCULPTED RECEIVER, CARVED KEEL (TRIGGER GUARD + MAGWELL + CHARM SEAT) & OCTAGONAL REACTOR BAY
def build_receiver():
    def rec_role(edge, row):
        if edge in {11, 0, 10}:
            return DRK
        if edge in {4, 6}:
            return STL
        if edge in {1, 9}:
            return SLT
        return OBS

    # Flowing 12-sided sculpted chassis hull matching Phantom v02 elegance
    rec = S.link("RFO2_Receiver", hull_bm([
        (0.020, 0.064, 0.195, 0.432, -0.18),
        (0.110, 0.088, 0.168, 0.464, -0.08),
        (0.320, 0.094, 0.165, 0.472,  0.00),
        (0.950, 0.094, 0.165, 0.472,  0.00),
        (1.095, 0.090, 0.180, 0.466,  0.10),
        (1.185, 0.084, 0.198, 0.456,  0.18),
    ], face_role=rec_role, ref_z=0.33))

    # Octagonal chamfered cut-through Reactor Core Bay (identical language to Phantom v02!)
    bay_cut = [
        (0.425, 0.238), (0.855, 0.238), (0.905, 0.285), (0.905, 0.392),
        (0.855, 0.436), (0.425, 0.436), (0.375, 0.392), (0.375, 0.285),
    ]
    S.bool_cut(rec, [prism_xz(bay_cut, -0.15, 0.15, DRK)])

    # Continuous sculpted lower keel: seamlessly integrates trigger guard, magwell & CharmLoop boss!
    # Note: Operator_CharmLoop lives at X=[0.929..0.961], Y=[0.086..0.096], Z=[0.118..0.160]!
    keel = S.link("RFO2_Keel", hull_bm([
        (0.085, 0.050, 0.095, 0.185, -0.12),
        (0.150, 0.056, 0.032, 0.185, -0.06),
        (0.405, 0.062, 0.032, 0.185,  0.06),
        (0.450, 0.080, 0.006, 0.195, -0.10),
        (0.840, 0.082, 0.006, 0.195,  0.04),
        (0.925, 0.092, 0.085, 0.205,  0.12),  # flares cleanly to Y=0.092 to SEAT CharmLoop flush!
        (0.995, 0.092, 0.105, 0.212,  0.14),
        (1.110, 0.072, 0.165, 0.225,  0.22),
    ], face_role=lambda e, r: BRZ if e in {1, 9} else (DRK if e in {11, 0, 10} else OBS), ref_z=0.12))

    # Carve clean trigger relief & magwell slot into the single unified keel (NO glued rectangles!)
    trig_cut = [(0.175, 0.052), (0.378, 0.052), (0.395, 0.162), (0.155, 0.162)]
    mag_slot = loft_rings_bm([
        [(0.635 + a * 0.205, b * 0.068, z) for a, b in
         [(0.84, -1), (-0.84, -1), (-1, -0.75), (-1, 0.75), (-0.84, 1), (0.84, 1), (1, 0.75), (1, -0.75)]]
        for z in (-0.01, 0.10, 0.21)
    ], face_role=lambda e, r: DRK, cap0_mat=DRK, cap1_mat=DRK)
    S.bool_cut(keel, [prism_xz(trig_cut, -0.12, 0.12, DRK), mag_slot])

    # Swept sculpted Dorsal Spine running seamlessly along top of receiver & handguard
    S.link("RFO2_DorsalSpine", hull_bm([
        (0.050, 0.042, 0.440, 0.472, -0.16),
        (0.160, 0.056, 0.456, 0.494,  0.00),
        (1.080, 0.056, 0.456, 0.494,  0.00),
        (1.360, 0.050, 0.448, 0.484,  0.10),
        (2.140, 0.042, 0.442, 0.472,  0.14),
        (2.240, 0.032, 0.432, 0.456,  0.20),
    ], face_role=lambda e, r: STL if e in {4, 6} else (SLT if e == 5 else OBS), ref_z=0.468))

    # Swept rear shoulder cheek-armor blades (Phantom v02 signature!)
    for hand, side in ((1.0, "L"), (-1.0, "R")):
        S.link(f"RFO2_RearCheek_{side}", facet_blade_bm(hand, [
            (0.055, 0.064, 0.090, 0.250, 0.340, 0.416, -0.14),
            (0.140, 0.076, 0.106, 0.242, 0.345, 0.432, -0.06),
            (0.280, 0.080, 0.108, 0.245, 0.345, 0.434,  0.00),
            (0.355, 0.078, 0.094, 0.258, 0.345, 0.422,  0.16),
        ], face_role=lambda e, r: STL if e in {2, 3} else (BRZ if e == 1 else SLT), ref_z=0.345))

    # Raked antique-bronze Reactor Bay framing collars (Boolean-matched to octagonal bay cut!)
    brz_role = lambda e, r: DRK if e in {11, 0, 10} else BRZ
    fc = S.link("RFO2_BayCollarFront", hull_bm([
        (0.885, 0.094, 0.200, 0.464, 0.10),
        (0.922, 0.103, 0.194, 0.476, 0.12),
        (0.962, 0.103, 0.196, 0.476, 0.14),
        (0.994, 0.094, 0.202, 0.466, 0.16),
    ], face_role=brz_role, ref_z=0.33))
    S.bool_cut(fc, [prism_xz(bay_cut, -0.15, 0.15, DRK)])

    rc = S.link("RFO2_BayCollarRear", hull_bm([
        (0.305, 0.094, 0.200, 0.464, -0.14),
        (0.338, 0.103, 0.194, 0.476, -0.12),
        (0.372, 0.103, 0.194, 0.476, -0.10),
        (0.400, 0.094, 0.200, 0.464, -0.08),
    ], face_role=brz_role, ref_z=0.33))
    S.bool_cut(rc, [prism_xz(bay_cut, -0.15, 0.15, DRK)])

    # Recessed glowing upper & lower reactor bay busbars (sculpted lofts, zero flat boxes!)
    S.link("RFO2_BayBusbars", merge_bms([
        hull_bm([(0.435, 0.032, 0.424, 0.440, 0), (0.845, 0.032, 0.424, 0.440, 0)],
                face_role=lambda e, r: COR, cap0_mat=COR, cap1_mat=COR, ref_z=0.432),
        hull_bm([(0.435, 0.030, 0.232, 0.248, 0), (0.845, 0.030, 0.232, 0.248, 0)],
                face_role=lambda e, r: COR, cap0_mat=COR, cap1_mat=COR, ref_z=0.240),
    ]))


# 2. FLOATING SPINDLE CORE CRYSTAL, DUAL TILTED GIMBAL RINGS & SWEPT SPLIT COWLS
def build_reactor():
    S.link("RFO2_CoreCrystal", _spindle_crystal(CORE_CX, CORE_CY, CORE_CZ, mat=COR),
           bone="Root", flat_group="CoreCrystal")
    S.link("RFO2_CoreRingA", _tilted_ring(CORE_CX, CORE_CY, CORE_CZ, 8, 0.098, 0.114, 0.014, 18, 12, STL),
           bone="Root", flat_group="CoreRingA")
    S.link("RFO2_CoreRingB", _tilted_ring(CORE_CX, CORE_CY, CORE_CZ, 6, 0.078, 0.092, 0.012, -22, -14, BRZ),
           bone="Root", flat_group="CoreRingB")

    # Swept aerodynamic lower & upper split armor cowls (leave spinning spindle crystal wide open!)
    for side, fg in ((+1.0, "CowlLeft"), (-1.0, "CowlRight")):
        lo_st = [
            (0.395, 0.084, 0.106, 0.214, 0.238, 0.264, -0.14),
            (0.495, 0.088, 0.126, 0.208, 0.234, 0.258, -0.04),
            (0.795, 0.088, 0.128, 0.208, 0.234, 0.258,  0.04),
            (0.885, 0.084, 0.106, 0.216, 0.238, 0.262,  0.14),
        ]
        hi_st = [
            (0.395, 0.084, 0.104, 0.416, 0.436, 0.456, -0.12),
            (0.495, 0.088, 0.120, 0.420, 0.440, 0.460, -0.04),
            (0.795, 0.088, 0.122, 0.420, 0.440, 0.460,  0.04),
            (0.885, 0.084, 0.104, 0.416, 0.436, 0.454,  0.12),
        ]
        S.link(
            f"RFO2_{fg}_Slt",
            merge_bms([
                facet_blade_bm(side, lo_st, face_role=lambda e, r: SLT, cap_mat=SLT, ref_z=0.236),
                facet_blade_bm(side, hi_st, face_role=lambda e, r: SLT, cap_mat=SLT, ref_z=0.438),
            ]),
            bone="Root",
            flat_group=fg + "_Slt",
        )
        S.link(
            f"RFO2_{fg}_Brz",
            facet_blade_bm(side, [
                (0.485, 0.108, 0.132, 0.226, 0.236, 0.246, -0.04),
                (0.805, 0.108, 0.134, 0.226, 0.236, 0.246,  0.04),
            ], face_role=lambda e, r: BRZ, cap_mat=BRZ, ref_z=0.236),
            bone="Root",
            flat_group=fg + "_Brz",
        )


# 3. MONOLITHIC TAPERED HANDGUARD, RECESSED PLASMA CHANNELS, DUAL-RAIL BARREL & TWIN-FANG MUZZLE
def build_front_end():
    def hg_role(edge, row):
        if edge in {4, 6}:
            return STL
        if edge in {11, 0, 10}:
            return DRK
        if edge in {1, 9}:
            return SLT
        return OBS

    hg = S.link("RFO2_Handguard", hull_bm([
        (1.060, 0.090, 0.168, 0.466,  0.00),
        (1.360, 0.088, 0.175, 0.462,  0.00),
        (1.860, 0.082, 0.205, 0.456,  0.06),
        (2.180, 0.076, 0.245, 0.450,  0.14),
        (2.280, 0.066, 0.285, 0.444,  0.22),
    ], face_role=hg_role, ref_z=0.35))

    # Carve recessed side plasma vent channels cleanly into the handguard flanks (NO glued neon slabs!)
    flank_cuts = []
    for sy in (+1.0, -1.0):
        flank_cuts.append(facet_blade_bm(sy, [
            (1.18, 0.066, 0.110, 0.305, 0.335, 0.365,  0.08),
            (2.08, 0.062, 0.106, 0.315, 0.340, 0.365,  0.12),
        ], face_role=lambda e, r: DRK, cap_mat=DRK, ref_z=0.335))
    S.bool_cut(hg, flank_cuts)

    # Recessed glowing plasma strips seated INSIDE the carved slots + swept bridging armor ribs!
    hg_acc = []
    for sy in (+1.0, -1.0):
        hg_acc.append(facet_blade_bm(sy, [
            (1.19, 0.056, 0.075, 0.314, 0.335, 0.356,  0.08),
            (2.07, 0.052, 0.071, 0.322, 0.340, 0.358,  0.12),
        ], face_role=lambda e, r: HOT if e == 2 else COR, cap_mat=COR, ref_z=0.335))
        # 3 swept diagonal armor ribs bridging the recessed plasma slot cleanly
        for rx in (1.42, 1.68, 1.94):
            hg_acc.append(facet_blade_bm(sy, [
                (rx - 0.032, 0.064, 0.092, 0.295, 0.336, 0.376, 0.22),
                (rx + 0.032, 0.064, 0.092, 0.295, 0.336, 0.376, 0.22),
            ], face_role=lambda e, r: BRZ if e == 2 else SLT, cap_mat=SLT, ref_z=0.336))

    # Tapered sculpted carbon foregrip under-keel
    hg_acc.append(hull_bm([
        (1.18, 0.056, 0.148, 0.195, -0.14),
        (1.30, 0.064, 0.140, 0.198,  0.00),
        (1.88, 0.058, 0.168, 0.218,  0.06),
        (2.06, 0.044, 0.205, 0.245,  0.20),
    ], face_role=lambda e, r: GRP if e in {1, 2, 3, 7, 8, 9} else DRK, ref_z=0.175))
    S.link("RFO2_HandguardAcc", merge_bms(hg_acc))

    # Precision octagonal inner sniper barrel + glowing recessed plasma accelerator core!
    inner_barrel = loft_rings_bm([
        oct_ring_x(2.16, 0.048, 0.048, cz=BORE_Z),
        oct_ring_x(3.26, 0.040, 0.040, cz=BORE_Z),
        oct_ring_x(3.52, 0.036, 0.036, cz=BORE_Z),
    ], face_role=lambda e, r: DRK if e % 2 == 0 else SLT, cap0_mat=DRK, cap1_mat=DRK)
    S.link("RFO2_InnerBarrel", inner_barrel)

    # Tapered glowing plasma accelerator conduit flanked between upper & lower rail shrouds
    S.link("RFO2_RailPlasma", loft_rings_bm([
        oct_ring_x(2.22, 0.056, 0.026, cz=BORE_Z, n=6, phase=0.0),
        oct_ring_x(3.24, 0.048, 0.022, cz=BORE_Z, n=6, phase=0.0),
    ], face_role=lambda e, r: HOT if e in {0, 3} else COR, cap0_mat=COR, cap1_mat=HOT))

    # 3 sculpted octagonal stepped antique-bronze accelerator collar rings along the barrel
    coils = []
    for cx, rw, rh in ((2.24, 0.072, 0.088), (2.64, 0.068, 0.082), (3.04, 0.064, 0.078)):
        coils.append(loft_rings_bm([
            oct_ring_x(cx - 0.034, rw * 0.88, rh * 0.88, cz=BORE_Z),
            oct_ring_x(cx - 0.016, rw,        rh,        cz=BORE_Z),
            oct_ring_x(cx + 0.016, rw,        rh,        cz=BORE_Z),
            oct_ring_x(cx + 0.034, rw * 0.88, rh * 0.88, cz=BORE_Z),
        ], face_role=lambda e, r: BRZ if r == 1 else STL, cap0_mat=DRK, cap1_mat=DRK))

    # Swept aerodynamic twin-prong faceted sniper muzzle brake (X = 3.20..3.52 — ZERO cube!)
    muzzle_collar = loft_rings_bm([
        oct_ring_x(3.19, 0.058, 0.064, cz=BORE_Z),
        oct_ring_x(3.26, 0.072, 0.076, cz=BORE_Z),
        oct_ring_x(3.38, 0.076, 0.074, cz=BORE_Z),
        oct_ring_x(3.52, 0.064, 0.058, cz=BORE_Z, rake=0.24),
    ], face_role=lambda e, r: BRZ if r == 0 else (STL if e in {1, 2, 5, 6} else OBS), cap0_mat=DRK, cap1_mat=DRK)
    # Pair of swept side railgun stabilizer prongs flanking the muzzle brake
    for sy in (+1.0, -1.0):
        coils.append(facet_blade_bm(sy, [
            (3.22, 0.056, 0.080, BORE_Z - 0.032, BORE_Z, BORE_Z + 0.032, 0.10),
            (3.38, 0.060, 0.088, BORE_Z - 0.028, BORE_Z, BORE_Z + 0.028, 0.16),
            (3.51, 0.048, 0.066, BORE_Z - 0.018, BORE_Z, BORE_Z + 0.018, 0.24),
        ], face_role=lambda e, r: COR if e == 2 else (STL if e in {1, 3} else SLT), cap_mat=SLT, ref_z=BORE_Z))
    S.link("RFO2_BarrelCoilsMuzzle", merge_bms([muzzle_collar] + coils))

    # ARTICULATED SWEPT UPPER & LOWER RAIL SHROUDS (VentTop / VentBottom — split & recoil on shot!)
    for sign, fg in ((+1.0, "VentTop"), (-1.0, "VentBottom")):
        z0 = BORE_Z + sign * 0.034
        z1 = BORE_Z + sign * 0.090
        zlo, zhi = min(z0, z1), max(z0, z1)
        S.link(f"RFO2_{fg}_Slt", hull_bm([
            (2.26, 0.042, zlo, zhi,  0.18 * sign),
            (2.40, 0.058, zlo, zhi,  0.04 * sign),
            (3.04, 0.054, zlo, zhi,  0.00),
            (3.18, 0.038, zlo + 0.008, zhi - 0.008, 0.20 * sign),
        ], face_role=lambda e, r: SLT, cap0_mat=SLT, cap1_mat=SLT, ref_z=0.5 * (zlo + zhi)),
               bone="Root", flat_group=fg + "_Slt")
        bz0 = BORE_Z + sign * 0.084
        bz1 = BORE_Z + sign * 0.100
        S.link(f"RFO2_{fg}_Brz", hull_bm([
            (2.38, 0.022, min(bz0, bz1), max(bz0, bz1), 0.14 * sign),
            (2.50, 0.028, min(bz0, bz1), max(bz0, bz1), 0.00),
            (2.96, 0.026, min(bz0, bz1), max(bz0, bz1), 0.00),
            (3.06, 0.018, min(bz0, bz1), max(bz0, bz1), 0.14 * sign),
        ], face_role=lambda e, r: BRZ, cap0_mat=BRZ, cap1_mat=BRZ, ref_z=0.5 * (bz0 + bz1)),
               bone="Root", flat_group=fg + "_Brz")


# 4. SLEEK CANTILEVERED SCULPTED SNIPER SCOPE (ZERO SQUARE MOUNT BLOCKS!)
def build_scope():
    # Swept aerodynamic cantilevered bridge mount flowing cleanly from dorsal spine into scope rings!
    mount_rail = hull_bm([
        (0.16, 0.042, 0.470, 0.506, -0.18),
        (0.26, 0.048, 0.474, 0.514,  0.00),
        (1.02, 0.048, 0.474, 0.514,  0.00),
        (1.12, 0.040, 0.470, 0.504,  0.18),
    ], face_role=lambda e, r: STL if e in {4, 6} else DRK, ref_z=0.49)

    # Sculpted raked twin scope stanchions + octagonal ring clamps hugging the optic tube seamlessly
    stanchions = [mount_rail]
    for sx in (0.31, 0.95):
        stanchions.append(hull_bm([
            (sx - 0.058, 0.040, 0.492, 0.562, -0.16),
            (sx - 0.032, 0.048, 0.496, 0.570,  0.00),
            (sx + 0.032, 0.048, 0.496, 0.570,  0.00),
            (sx + 0.058, 0.040, 0.492, 0.562,  0.16),
        ], face_role=lambda e, r: STL if e in {4, 6} else SLT, ref_z=0.53))
        stanchions.append(loft_rings_bm([
            oct_ring_x(sx - 0.048, 0.088, 0.088, cz=SCOPE_Z, n=12, phase=math.pi / 12),
            oct_ring_x(sx - 0.028, 0.095, 0.095, cz=SCOPE_Z, n=12, phase=math.pi / 12),
            oct_ring_x(sx + 0.028, 0.095, 0.095, cz=SCOPE_Z, n=12, phase=math.pi / 12),
            oct_ring_x(sx + 0.048, 0.088, 0.088, cz=SCOPE_Z, n=12, phase=math.pi / 12),
        ], face_role=lambda e, r: BRZ if r == 1 else SLT, cap0_mat=DRK, cap1_mat=DRK))
    S.link("RFO2_ScopeMount", merge_bms(stanchions))

    # Sleek 12-sided ergonomic faceted sniper optic (raked sunshade hood, waisted tube, bronze collars)
    scope_rings = [
        oct_ring_x(-0.075, 0.092, 0.092, cz=SCOPE_Z, n=12, phase=math.pi / 12, rake=-0.12),
        oct_ring_x( 0.065, 0.102, 0.102, cz=SCOPE_Z, n=12, phase=math.pi / 12),
        oct_ring_x( 0.170, 0.076, 0.076, cz=SCOPE_Z, n=12, phase=math.pi / 12),
        oct_ring_x( 1.030, 0.076, 0.076, cz=SCOPE_Z, n=12, phase=math.pi / 12),
        oct_ring_x( 1.180, 0.118, 0.118, cz=SCOPE_Z, n=12, phase=math.pi / 12),
        oct_ring_x( 1.480, 0.124, 0.124, cz=SCOPE_Z, n=12, phase=math.pi / 12),
        oct_ring_x( 1.590, 0.114, 0.114, cz=SCOPE_Z, n=12, phase=math.pi / 12, rake=0.28),
    ]
    def sc_role(edge, row):
        if row in {1, 4}:
            return BRZ
        if edge in {2, 3, 8, 9}:
            return STL if edge in {2, 3} else SLT
        return OBS
    S.link("RFO2_ScopeBody", loft_rings_bm(scope_rings, face_role=sc_role, cap0_mat=DRK, cap1_mat=DRK))

    # Sculpted octagonal turret drums, swept cheek blades on objective bell & recessed glowing lenses!
    def turret(cx, cy, cz, r, h, axis="Z"):
        pts = []
        for s in (0.0, 0.15, 0.85, 1.0):
            rr = r * (0.86 if s in (0.0, 1.0) else 1.0)
            dd = h * s
            ring = []
            for i in range(8):
                a = math.pi / 8 + 2 * math.pi * i / 8
                ca, sa = math.cos(a), math.sin(a)
                if axis == "Z":
                    ring.append((cx + rr * ca, cy + rr * sa, cz + dd))
                else:
                    ring.append((cx + rr * ca, cy + dd, cz + rr * sa))
            pts.append(ring)
        return loft_rings_bm(pts, face_role=lambda e, r: BRZ if r == 1 else STL, cap0_mat=DRK, cap1_mat=SLT)

    sc_det = [
        turret(0.62, 0.0, SCOPE_Z + 0.068, 0.044, 0.056, "Z"),
        turret(0.62, 0.068, SCOPE_Z,       0.038, 0.048, "Y"),
        # Recessed ocular & objective violet lenses
        loft_rings_bm([
            oct_ring_x(-0.080, 0.076, 0.076, cz=SCOPE_Z, n=12, phase=math.pi / 12),
            oct_ring_x(-0.064, 0.078, 0.078, cz=SCOPE_Z, n=12, phase=math.pi / 12),
        ], face_role=lambda e, r: COR, cap0_mat=HOT, cap1_mat=COR),
        loft_rings_bm([
            oct_ring_x(1.545, 0.096, 0.096, cz=SCOPE_Z, n=12, phase=math.pi / 12),
            oct_ring_x(1.575, 0.092, 0.092, cz=SCOPE_Z, n=12, phase=math.pi / 12),
        ], face_role=lambda e, r: COR, cap0_mat=COR, cap1_mat=HOT),
    ]
    # Swept aerodynamic side shrouds on the objective bell framing sleek recessed plasma slits
    for sy in (+1.0, -1.0):
        sc_det.append(facet_blade_bm(sy, [
            (1.18, 0.106, 0.130, SCOPE_Z - 0.036, SCOPE_Z, SCOPE_Z + 0.036, -0.10),
            (1.48, 0.110, 0.134, SCOPE_Z - 0.032, SCOPE_Z, SCOPE_Z + 0.032,  0.14),
        ], face_role=lambda e, r: COR if e == 2 else (STL if e in {1, 3} else SLT), cap_mat=SLT, ref_z=SCOPE_Z))
    S.link("RFO2_ScopeDetails", merge_bms(sc_det))


# 5. PRECISION COMPOUND-FACETED SNIPER STOCK, ERGONOMIC GRIP & PLASMA CELL MAG
def build_stock_grip_mag():
    # Swept bronze stock-receiver coupling collar (identical to Phantom v02!)
    collar = hull_bm([
        (-0.025, 0.068, 0.185, 0.422, -0.16),
        ( 0.015, 0.082, 0.178, 0.440, -0.12),
        ( 0.060, 0.084, 0.175, 0.446, -0.08),
    ], face_role=lambda e, r: DRK if e in {11, 0, 10} else BRZ, ref_z=0.31)

    # Sculpted sweeping skeletal precision sniper stock (smoothly contoured comb, curved cheek
    # rest, swept buttpad, tapered lower strut meeting grip heel — ZERO boxy frame!)
    stock_body = hull_bm([
        (-1.315, 0.056, -0.195, 0.398, -0.06),
        (-1.225, 0.072, -0.178, 0.415, -0.02),
        (-1.050, 0.076,  0.180, 0.422, -0.14),
        (-0.360, 0.078,  0.228, 0.426, -0.04),
        ( 0.010, 0.074,  0.190, 0.436,  0.04),
    ], face_role=lambda e, r: BRZ if r == 0 else (STL if e in {4, 6} else (SLT if e in {1, 9} else OBS)), ref_z=0.30)

    # Swept lower stabilizer spar curving cleanly from buttpad toe into rear grip heel
    spar = hull_bm([
        (-1.235, 0.054, -0.185, -0.085,  0.00),
        (-0.920, 0.050, -0.168, -0.082,  0.04),
        (-0.460, 0.048, -0.142, -0.062,  0.08),
        (-0.155, 0.052, -0.110, -0.025,  0.12),
    ], face_role=lambda e, r: STL if e in {4, 6} else (SLT if e in {1, 9} else DRK), ref_z=-0.11)

    # Sculpted contoured carbon cheek pad & sleek glowing recessed stock power line
    cheek = hull_bm([
        (-1.04, 0.064, 0.382, 0.448, -0.16),
        (-0.92, 0.074, 0.388, 0.462,  0.00),
        (-0.46, 0.074, 0.388, 0.462,  0.00),
        (-0.36, 0.062, 0.382, 0.446,  0.16),
    ], face_role=lambda e, r: GRP if e in {2, 3, 4, 5, 6, 7, 8} else DRK, ref_z=0.42)

    st_glow = []
    for sy in (+1.0, -1.0):
        st_glow.append(facet_blade_bm(sy, [
            (-1.02, 0.060, 0.078, 0.285, 0.302, 0.318, -0.08),
            (-0.40, 0.062, 0.080, 0.295, 0.310, 0.325,  0.06),
        ], face_role=lambda e, r: COR if e == 2 else SLT, cap_mat=SLT, ref_z=0.305))
    S.link("RFO2_Stock", merge_bms([collar, stock_body, spar, cheek] + st_glow))

    # Contoured ergonomic carbon pistol grip with machined bronze heel cap
    grip_rings = []
    for t in (0.0, 0.25, 0.65, 1.0):
        z = 0.185 - t * 0.435
        x0 = -0.095 - t * 0.095
        x1 =  0.115 - t * 0.075
        yw = 0.052 + 0.010 * math.sin(t * math.pi)
        xm = 0.5 * (x0 + x1)
        grip_rings.append([
            (x0, -yw * 0.64, z), (xm, -yw, z), (x1, -yw * 0.70, z),
            (x1,  yw * 0.70, z), (xm,  yw, z), (x0,  yw * 0.64, z),
        ])
    S.link("RFO2_Grip", loft_rings_bm(grip_rings, face_role=lambda e, r: GRP if e in {0, 1, 3, 4} else DRK, cap0_mat=DRK, cap1_mat=BRZ))

    # Sculpted Plasma Cell Sniper Magazine (Mag bone — flush raked baseplate & inlaid plasma window!)
    mag_body = hull_bm([
        (0.452, 0.060, -0.085, 0.228,  0.06),
        (0.640, 0.064, -0.088, 0.230,  0.00),
        (0.818, 0.060, -0.080, 0.224, -0.06),
    ], face_role=lambda e, r: STL if e in {4, 6} else OBS, cap0_mat=DRK, cap1_mat=DRK, ref_z=0.07)
    mag_base = hull_bm([
        (0.436, 0.066, -0.108, -0.068,  0.08),
        (0.640, 0.070, -0.110, -0.068,  0.00),
        (0.834, 0.066, -0.104, -0.066, -0.08),
    ], face_role=lambda e, r: BRZ, cap0_mat=BRZ, cap1_mat=BRZ, ref_z=-0.088)
    mag_glow = []
    for sy in (+1.0, -1.0):
        mag_glow.append(facet_blade_bm(sy, [
            (0.500, 0.054, 0.067, -0.042, 0.020, 0.085, 0.02),
            (0.775, 0.054, 0.067, -0.040, 0.020, 0.085, -0.02),
        ], face_role=lambda e, r: HOT if e == 2 else COR, cap_mat=COR, ref_z=0.02))
    S.link("RFO2_Mag", merge_bms([mag_body, mag_base] + mag_glow), bone="Mag")


build_receiver()
build_reactor()
build_front_end()
build_scope()
build_stock_grip_mag()

res = S.finalize(
    replaced_prefixes=[
        "Neon", "Receiver", "Handguard", "Barrel", "Grip",
        "Stock", "Magazine", "Scope", "ScopeLens", "Bolt",
    ],
    center_checks=["RFO2_Receiver", "RFO2_ScopeBody", "RFO2_CoreCrystal", "RFO2_InnerBarrel"],
    cam_specs={
        "center": (1.05, 0.0, 0.33),
        "span": 4.9,
        "hero_loc": (4.40, 4.10, 1.95),
        "hero_ortho": 5.25,
        "side_loc": (1.05, 5.80, 0.33),
        "side_ortho": 5.35,
        "fp_loc": (-1.55, 0.72, 0.92),
        "fp_tgt": (1.35, 0.0, 0.38),
        "close_loc": (1.18, 1.15, 0.62),
        "close_tgt": (0.64, 0.0, 0.34),
        "icon_loc": (2.55, 5.20, 0.95),
        "icon_ortho": 5.20,
        "portrait_loc": (3.90, 3.85, 1.65),
        "portrait_ortho": 4.85,
        "ray_x": (-1.2, 3.4),
        "ray_z": (-0.15, 0.72),
    },
)
result = res
print(json.dumps(res, indent=2))
