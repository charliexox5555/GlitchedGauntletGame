"""Build Riftforge Spectre v01 (Twin-Vent Compact Plasma SMG) in live Blender 5.2 MCP.

Signature Legendary hooks:
- Removes stock ChargingHandle & Bolt completely: replaced by articulated twin split
  reactor cowls (CowlLeft / CowlRight) + suppressor cooling louvers (VentTop / VentBottom)
  that flutter open rapidly during high-ROF sprays!
- Open cut-through mid-chassis Reactor Core Bay with CoreCrystal + dual counter-rotating
  gimbal rings (CoreRingA steel + CoreRingB bronze), 100% visible at idle.
- Sculpted tapered octagonal plasma suppressor with bronze collars & glowing flank channels.
- Swept angled plasma stick magazine (Mag bone), collapsible PDW stock, and open hex-arch sights.
- Full compound-faceted closed-manifold geometry -> FLIPPED: {}, OPEN_FLIPPED: {}, ray_backfaces: [].
"""
import json
import math
import os
import sys

ROOT = r"c:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
sys.path.insert(0, os.path.join(ROOT, "tools", "blender"))
import importlib
import riftforge_kit as K
importlib.reload(K)

from riftforge_kit import (
    OBS, SLT, DRK, STL, BRZ, GRP, COR, HOT,
    hull_bm, facet_blade_bm, loft_rings_bm, box_bm,
    oct_ring_x, crystal_bm, ring_bm, merge_bms,
)

S = K.RiftforgeScene("Spectre", "v01")

CORE_CX, CORE_CY, CORE_CZ = 0.30, 0.0, 0.335
BORE_Z = 0.353


# 1. SCULPTED COMPACT SMG RECEIVER & OPEN REACTOR BAY
def build_receiver():
    def rec_role(edge, row):
        if edge in {11, 0, 10}:
            return DRK
        if edge in {4, 6}:
            return STL
        if edge in {1, 9}:
            return SLT
        return OBS

    rec = S.link("RFSP_Receiver", hull_bm([
        (-0.330, 0.068, 0.175, 0.428, -0.14),
        (-0.220, 0.084, 0.145, 0.456, -0.05),
        (0.060,  0.088, 0.120, 0.464,  0.00),
        (0.680,  0.088, 0.120, 0.464,  0.00),
        (0.790,  0.086, 0.175, 0.462,  0.08),
    ], face_role=rec_role, ref_z=0.33))

    # Cut open the cut-through mid-chassis Reactor Core Bay!
    bay_cut = box_bm(0.115, 0.495, -0.16, 0.16, 0.240, 0.418)
    S.bool_cut(rec, [bay_cut])

    # Magwell housing + forged trigger guard
    mw = hull_bm([
        (0.425, 0.074, 0.015, 0.145,  0.12),
        (0.585, 0.076, 0.010, 0.145,  0.08),
        (0.745, 0.072, 0.030, 0.160,  0.02),
    ], face_role=lambda e, r: STL if e in {1, 9} else DRK, ref_z=0.08)
    tg = merge_bms([
        box_bm(0.095, 0.425, -0.020, 0.020, 0.025, 0.048, ch=0.004, mat=SLT, bevel_mat=STL),
        box_bm(0.395, 0.425, -0.020, 0.020, 0.025, 0.125, ch=0.004, mat=SLT, bevel_mat=STL),
    ])
    S.link("RFSP_Lower", merge_bms([mw, tg]))

    # Reactor bay plasma liners + bronze bulkhead clamps
    bay_acc = merge_bms([
        box_bm(0.122, 0.488, -0.046, 0.046, 0.410, 0.425, ch=0.003, mat=COR, bevel_mat=HOT),
        box_bm(0.122, 0.488, -0.046, 0.046, 0.232, 0.248, ch=0.003, mat=COR, bevel_mat=HOT),
        box_bm(0.098, 0.118, -0.054, 0.054, 0.242, 0.418, ch=0.004, mat=BRZ, bevel_mat=BRZ),
        box_bm(0.492, 0.512, -0.054, 0.054, 0.242, 0.418, ch=0.004, mat=BRZ, bevel_mat=BRZ),
        # Exterior bronze chassis collars flanking the cowls
        hull_bm([(-0.04, 0.092, 0.18, 0.456, 0), (0.02, 0.092, 0.18, 0.456, 0)],
                face_role=lambda e, r: BRZ, cap0_mat=BRZ, cap1_mat=BRZ, ref_z=0.33),
        hull_bm([(0.58, 0.092, 0.18, 0.456, 0), (0.64, 0.092, 0.18, 0.456, 0)],
                face_role=lambda e, r: BRZ, cap0_mat=BRZ, cap1_mat=BRZ, ref_z=0.33),
    ])
    S.link("RFSP_BayFrame", bay_acc)


# 2. FLOATING REACTOR CORE CRYSTAL + DUAL COUNTER-ROTATING GIMBAL RINGS
def build_reactor_core():
    S.link("RFSP_CoreCrystal", crystal_bm(CORE_CX, CORE_CY, CORE_CZ, 0.060, 0.058, 0.074, mat=COR),
           bone="Root", flat_group="CoreCrystal")
    S.link("RFSP_CoreRingA", ring_bm(CORE_CX, CORE_CY, CORE_CZ, rad=0.098, thick=0.013, width=0.017, n=8, axis="Y", mat=STL),
           bone="Root", flat_group="CoreRingA")
    S.link("RFSP_CoreRingB", ring_bm(CORE_CX, CORE_CY, CORE_CZ, rad=0.078, thick=0.011, width=0.015, n=6, axis="Y", mat=BRZ),
           bone="Root", flat_group="CoreRingB")


# 3. ARTICULATED SPLIT REACTOR COWLS (leave glowing core proudly visible!)
def build_cowls():
    for side, fg in ((+1, "CowlLeft"), (-1, "CowlRight")):
        slt_lo = [
            (0.06, 0.078, 0.098, 0.210, 0.236, 0.264, -0.14),
            (0.16, 0.082, 0.118, 0.202, 0.232, 0.260, -0.04),
            (0.45, 0.082, 0.118, 0.202, 0.232, 0.260,  0.04),
            (0.54, 0.078, 0.098, 0.212, 0.236, 0.262,  0.14),
        ]
        slt_hi = [
            (0.06, 0.078, 0.096, 0.402, 0.422, 0.446, -0.10),
            (0.16, 0.082, 0.114, 0.406, 0.426, 0.450, -0.04),
            (0.45, 0.082, 0.114, 0.406, 0.426, 0.450,  0.04),
            (0.54, 0.078, 0.096, 0.402, 0.422, 0.444,  0.10),
        ]
        S.link(
            f"RFSP_{fg}_Slt",
            merge_bms([
                facet_blade_bm(side, slt_lo, face_role=lambda e, r: SLT, cap_mat=SLT, ref_z=0.235),
                facet_blade_bm(side, slt_hi, face_role=lambda e, r: SLT, cap_mat=SLT, ref_z=0.425),
            ]),
            bone="Root",
            flat_group=fg + "_Slt",
        )
        brz_st = [
            (0.14, 0.098, 0.124, 0.222, 0.234, 0.246, -0.04),
            (0.47, 0.098, 0.124, 0.222, 0.234, 0.246,  0.04),
        ]
        S.link(
            f"RFSP_{fg}_Brz",
            facet_blade_bm(side, brz_st, face_role=lambda e, r: BRZ, cap_mat=BRZ, ref_z=0.234),
            bone="Root",
            flat_group=fg + "_Brz",
        )


# 4. HANDGUARD, FLUTED PLASMA SUPPRESSOR, ARTICULATED VENTS & OPEN HEX-ARCH SIGHTS
def build_front_and_sights():
    hg = hull_bm([
        (0.690, 0.088, 0.215, 0.464,  0.00),
        (0.920, 0.086, 0.228, 0.462,  0.02),
        (1.135, 0.080, 0.245, 0.456,  0.12),
    ], face_role=lambda e, r: STL if e in {4, 6} else (SLT if e in {1, 9} else (DRK if e in {11, 0, 10} else OBS)), ref_z=0.35)
    hg_glow = merge_bms([
        box_bm(0.72, 1.09,  0.074,  0.090, 0.325, 0.365, ch=0.003, mat=COR, bevel_mat=HOT),
        box_bm(0.72, 1.09, -0.090, -0.074, 0.325, 0.365, ch=0.003, mat=COR, bevel_mat=HOT),
        box_bm(0.74, 1.06, -0.054,  0.054, 0.202, 0.232, ch=0.006, mat=GRP, bevel_mat=DRK),
    ])
    S.link("RFSP_Handguard", merge_bms([hg, hg_glow]))

    # Sleek tapered octagonal plasma suppressor (X = 1.13..1.90, bore Z = 0.353)
    supp_body = loft_rings_bm([
        oct_ring_x(1.130, 0.082, 0.082, cz=BORE_Z),
        oct_ring_x(1.220, 0.086, 0.086, cz=BORE_Z),
        oct_ring_x(1.780, 0.076, 0.076, cz=BORE_Z),
        oct_ring_x(1.900, 0.068, 0.068, cz=BORE_Z, rake=0.14),
    ], face_role=lambda e, r: BRZ if r in {0, 2} else (STL if e in {1, 2} else OBS), cap0_mat=DRK, cap1_mat=DRK)

    # Recessed glowing lateral plasma channels bridged by 2 slate baffle ribs
    supp_acc = [
        supp_body,
        box_bm(1.22, 1.78,  0.064,  0.086, BORE_Z - 0.020, BORE_Z + 0.020, ch=0.003, mat=COR, bevel_mat=HOT),
        box_bm(1.22, 1.78, -0.086, -0.064, BORE_Z - 0.020, BORE_Z + 0.020, ch=0.003, mat=COR, bevel_mat=HOT),
    ]
    for rx in (1.40, 1.62):
        supp_acc.append(loft_rings_bm([
            oct_ring_x(rx - 0.022, 0.090, 0.090, cz=BORE_Z),
            oct_ring_x(rx + 0.022, 0.090, 0.090, cz=BORE_Z),
        ], face_role=lambda e, r: SLT if e % 2 == 0 else STL, cap0_mat=SLT, cap1_mat=SLT))
    S.link("RFSP_Suppressor", merge_bms(supp_acc))

    # Articulated top/bottom suppressor accelerator vents (VentTop / VentBottom)
    for sign, fg in ((+1, "VentTop"), (-1, "VentBottom")):
        z0 = BORE_Z + sign * 0.074
        z1 = BORE_Z + sign * 0.104
        z_lo, z_hi = min(z0, z1), max(z0, z1)
        S.link(
            f"RFSP_{fg}_Slt",
            hull_bm([
                (1.24, 0.036, z_lo, z_hi, 0.08 * sign),
                (1.50, 0.042, z_lo, z_hi, 0.00),
                (1.74, 0.032, z_lo, z_hi, 0.10 * sign),
            ], face_role=lambda e, r: SLT, cap0_mat=SLT, cap1_mat=SLT, ref_z=0.5 * (z_lo + z_hi)),
            bone="Root",
            flat_group=fg + "_Slt",
        )
        bz_lo = BORE_Z + sign * 0.098 if sign > 0 else BORE_Z - 0.112
        bz_hi = BORE_Z + sign * 0.112 if sign > 0 else BORE_Z - 0.098
        S.link(
            f"RFSP_{fg}_Brz",
            box_bm(1.30, 1.68, -0.018, 0.018, bz_lo, bz_hi, ch=0.003, mat=BRZ, bevel_mat=BRZ),
            bone="Root",
            flat_group=fg + "_Brz",
        )

    # Crisp open hex-arch iron sights (clean unobstructed ADS window at Z = 0.56!)
    sights = merge_bms([
        # Rear hex-arch frame
        box_bm(-0.06, 0.12, -0.052,  0.052, 0.456, 0.486, ch=0.005, mat=DRK, bevel_mat=SLT),
        box_bm(-0.04, 0.08,  0.032,  0.056, 0.478, 0.580, ch=0.005, mat=SLT, bevel_mat=STL),
        box_bm(-0.04, 0.08, -0.056, -0.032, 0.478, 0.580, ch=0.005, mat=SLT, bevel_mat=STL),
        box_bm(-0.04, 0.08, -0.046,  0.046, 0.572, 0.592, ch=0.004, mat=BRZ, bevel_mat=STL),
        # Front hooded plasma post
        box_bm(0.95, 1.06,  0.022,  0.042, 0.454, 0.562, ch=0.004, mat=SLT, bevel_mat=STL),
        box_bm(0.95, 1.06, -0.042, -0.022, 0.454, 0.562, ch=0.004, mat=SLT, bevel_mat=STL),
        box_bm(0.98, 1.04, -0.007,  0.007, 0.458, 0.558, ch=0.002, mat=HOT, bevel_mat=HOT),
    ])
    S.link("RFSP_Sights", sights)


# 5. COMPACT PDW STOCK, GRIP & ANGLED PLASMA STICK MAG
def build_stock_grip_mag():
    # Collapsible twin-rod PDW skeletal stock (X = -1.06..-0.30)
    stock = merge_bms([
        # Twin upper & lower machined steel slide rods
        box_bm(-1.02, -0.30,  0.046,  0.068, 0.315, 0.355, ch=0.005, mat=STL, bevel_mat=STL),
        box_bm(-1.02, -0.30, -0.068, -0.046, 0.315, 0.355, ch=0.005, mat=STL, bevel_mat=STL),
        # Sculpted forged buttpad + carbon comb + bronze heel trim
        hull_bm([
            (-1.065, 0.062, -0.105, 0.388, 0.00),
            (-0.960, 0.070, -0.085, 0.398, 0.00),
            (-0.880, 0.066,  0.220, 0.395, 0.08),
        ], face_role=lambda e, r: BRZ if r == 0 else (STL if e in {4, 6} else OBS), ref_z=0.22),
        # Carbon cheek rest bridging rods
        hull_bm([
            (-0.92, 0.056, 0.345, 0.402, 0.0),
            (-0.42, 0.056, 0.345, 0.402, 0.0),
        ], face_role=lambda e, r: GRP, cap0_mat=DRK, cap1_mat=DRK, ref_z=0.37),
        box_bm(-0.94, -0.44, -0.034, 0.034, 0.318, 0.348, ch=0.003, mat=COR, bevel_mat=HOT),
    ])
    S.link("RFSP_Stock", stock)

    # Carbon ergonomic pistol grip
    grip_rings = []
    for t in (0.0, 0.30, 0.70, 1.0):
        z = 0.140 - t * 0.415
        x0 = -0.085 - t * 0.105
        x1 = 0.118 - t * 0.085
        yw = 0.050 + 0.008 * math.sin(t * math.pi)
        xm = 0.5 * (x0 + x1)
        grip_rings.append([
            (x0, -yw * 0.65, z), (xm, -yw, z), (x1, -yw * 0.72, z),
            (x1,  yw * 0.72, z), (xm,  yw, z), (x0,  yw * 0.65, z),
        ])
    S.link("RFSP_Grip", loft_rings_bm(grip_rings, face_role=lambda e, r: GRP if e in {0, 1, 3, 4} else DRK, cap0_mat=DRK, cap1_mat=BRZ))

    # Long angled SMG plasma stick magazine (bone="Mag"!)
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
    # Glowing plasma charge strip down both flanks of the stick mag
    mag_glow = []
    for side in (+1, -1):
        p_rings = []
        for t in (0.12, 0.88):
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
    S.link("RFSP_Mag", merge_bms([mag_body] + mag_glow), bone="Mag")


build_receiver()
build_reactor_core()
build_cowls()
build_front_and_sights()
build_stock_grip_mag()

res = S.finalize(
    replaced_prefixes=[
        "Neon", "Receiver", "Handguard", "Suppressor", "Grip",
        "Stock", "Mag", "Sights", "Pins", "ChargingHandle", "Bolt",
    ],
    center_checks=["RFSP_Receiver", "RFSP_Suppressor", "RFSP_CoreCrystal", "RFSP_Sights"],
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
