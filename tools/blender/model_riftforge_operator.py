"""Build Riftforge Operator v01 (Heavy Dual-Rail Plasma Sniper Cannon) in live Blender 5.2 MCP.

Signature Legendary hooks:
- Removes stock Bolt completely: replaced by articulated Reactor Cowls + Twin Magnetic
  Rail Shrouds (VentTop / VentBottom) that split & recoil after every shot!
- Oversized cut-through mid-chassis Reactor Core Bay with CoreCrystal + dual counter-rotating
  gimbal rings (CoreRingA steel + CoreRingB bronze).
- Sculpted octagonal forged sniper scope with antique-bronze clamp collars, cantilevered
  mounts, and violet glowing lenses.
- Full compound-faceted closed-manifold geometry -> FLIPPED: {}, OPEN_FLIPPED: {}, ray_backfaces: [].
"""
import json
import math
import os
import sys

import bpy
from mathutils import Vector

ROOT = r"c:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
sys.path.insert(0, os.path.join(ROOT, "tools", "blender"))
import importlib
import riftforge_kit as K
importlib.reload(K)

from riftforge_kit import (
    OBS, SLT, DRK, STL, BRZ, GRP, COR, HOT,
    hull_bm, facet_blade_bm, loft_rings_bm, prism_xz, box_bm,
    oct_ring_x, crystal_bm, ring_bm, merge_bms,
)

S = K.RiftforgeScene("Operator", "v01")

CORE_CX, CORE_CY, CORE_CZ = 0.64, 0.0, 0.345
BORE_Z = 0.385
SCOPE_Z = 0.615


# 1. SCULPTED ARMORED RECEIVER & OPEN REACTOR BAY
def build_receiver():
    def rec_role(edge, row):
        if edge in {11, 0, 10}:
            return DRK
        if edge in {4, 6}:
            return STL
        if edge in {1, 9}:
            return SLT
        return OBS

    stations = [
        (0.040, 0.072, 0.140, 0.445, -0.10),
        (0.140, 0.090, 0.080, 0.472, -0.04),
        (0.360, 0.094, 0.075, 0.476,  0.00),
        (0.920, 0.094, 0.075, 0.476,  0.00),
        (1.090, 0.092, 0.125, 0.470,  0.10),
        (1.180, 0.086, 0.155, 0.456,  0.16),
    ]
    rec = S.link("RFO_Receiver", hull_bm(stations, face_role=rec_role, ref_z=0.32))

    # Cut open the cut-through Reactor Core Bay cleanly (exact Boolean difference)
    bay_cut = box_bm(0.415, 0.875, -0.16, 0.16, 0.238, 0.432)
    S.bool_cut(rec, [bay_cut])

    # Lower magwell collar & forged trigger guard
    mw = hull_bm([
        (0.395, 0.078, 0.012, 0.125, 0.04),
        (0.640, 0.082, 0.005, 0.125, 0.00),
        (0.865, 0.078, 0.018, 0.130, -0.06),
    ], face_role=lambda e, r: STL if e in {1, 9} else DRK, ref_z=0.08)
    S.link("RFO_Magwell", mw)

    tg = merge_bms([
        box_bm(0.105, 0.410, -0.022, 0.022, 0.026, 0.048, ch=0.005, mat=SLT, bevel_mat=STL),
        box_bm(0.382, 0.412, -0.022, 0.022, 0.026, 0.112, ch=0.004, mat=SLT, bevel_mat=STL),
    ])
    S.link("RFO_TriggerGuard", tg)

    # Recessed plasma conduit bars lining top & bottom of reactor bay
    bay_glow = merge_bms([
        box_bm(0.425, 0.865, -0.048, 0.048, 0.424, 0.440, ch=0.003, mat=COR, bevel_mat=HOT),
        box_bm(0.425, 0.865, -0.048, 0.048, 0.228, 0.244, ch=0.003, mat=COR, bevel_mat=HOT),
        box_bm(0.405, 0.425, -0.056, 0.056, 0.240, 0.430, ch=0.004, mat=BRZ, bevel_mat=BRZ),
        box_bm(0.865, 0.885, -0.056, 0.056, 0.240, 0.430, ch=0.004, mat=BRZ, bevel_mat=BRZ),
    ])
    S.link("RFO_BayFrame", bay_glow)

    # Dorsal bridge & bronze chassis clamps
    clamps = merge_bms([
        hull_bm([(0.24, 0.097, 0.20, 0.468, 0), (0.31, 0.097, 0.20, 0.468, 0)],
                face_role=lambda e, r: BRZ, cap0_mat=BRZ, cap1_mat=BRZ, ref_z=0.33),
        hull_bm([(0.95, 0.097, 0.19, 0.468, 0), (1.03, 0.097, 0.19, 0.468, 0)],
                face_role=lambda e, r: BRZ, cap0_mat=BRZ, cap1_mat=BRZ, ref_z=0.33),
    ])
    S.link("RFO_ChassisClamps", clamps)


# 2. FLOATING REACTOR CORE CRYSTAL + DUAL COUNTER-ROTATING GIMBAL RINGS
def build_reactor_core():
    crys = crystal_bm(CORE_CX, CORE_CY, CORE_CZ, 0.072, 0.068, 0.088, mat=COR)
    S.link("RFO_CoreCrystal", crys, bone="Root", flat_group="CoreCrystal")

    ring_a = ring_bm(CORE_CX, CORE_CY, CORE_CZ, rad=0.118, thick=0.015, width=0.020, n=8, axis="Y", mat=STL)
    S.link("RFO_CoreRingA", ring_a, bone="Root", flat_group="CoreRingA")

    ring_b = ring_bm(CORE_CX, CORE_CY, CORE_CZ, rad=0.094, thick=0.013, width=0.018, n=6, axis="Y", mat=BRZ)
    S.link("RFO_CoreRingB", ring_b, bone="Root", flat_group="CoreRingB")


# 3. ARTICULATED SWEPT REACTOR COWLS (CowlLeft & CowlRight — frame OPEN crystal window!)
def build_reactor_cowls():
    # Sculpted lower-swept predator armor cowls leaving the central floating CoreCrystal
    # & dual counter-rotating gimbal rings proudly visible at rest, then flaring wide on shot/reload!
    for side, fg in ((+1, "CowlLeft"), (-1, "CowlRight")):
        slt_st = [
            (0.34, 0.082, 0.104, 0.215, 0.248, 0.285, -0.14),
            (0.46, 0.086, 0.128, 0.205, 0.242, 0.278, -0.04),
            (0.80, 0.086, 0.130, 0.205, 0.242, 0.278,  0.04),
            (0.92, 0.082, 0.106, 0.218, 0.248, 0.282,  0.14),
        ]
        # Paired upper brow wing framing top of the reactor bay
        slt_hi = [
            (0.34, 0.082, 0.102, 0.410, 0.432, 0.458, -0.12),
            (0.46, 0.086, 0.122, 0.414, 0.436, 0.462, -0.04),
            (0.80, 0.086, 0.124, 0.414, 0.436, 0.462,  0.04),
            (0.92, 0.082, 0.102, 0.410, 0.432, 0.456,  0.12),
        ]
        S.link(
            f"RFO_{fg}_Slt",
            merge_bms([
                facet_blade_bm(side, slt_st, face_role=lambda e, r: SLT, cap_mat=SLT, ref_z=0.245),
                facet_blade_bm(side, slt_hi, face_role=lambda e, r: SLT, cap_mat=SLT, ref_z=0.435),
            ]),
            bone="Root",
            flat_group=fg + "_Slt",
        )
        # Bronze leading edge accent bar on lower cowl wing (separate closed manifold solid!)
        brz_st = [
            (0.44, 0.106, 0.134, 0.232, 0.245, 0.260, -0.04),
            (0.82, 0.108, 0.136, 0.232, 0.245, 0.260,  0.04),
            (0.90, 0.098, 0.118, 0.235, 0.245, 0.256,  0.10),
        ]
        S.link(
            f"RFO_{fg}_Brz",
            facet_blade_bm(side, brz_st, face_role=lambda e, r: BRZ, cap_mat=BRZ, ref_z=0.245),
            bone="Root",
            flat_group=fg + "_Brz",
        )


# 4. HEAVY HANDGUARD, DUAL-RAIL ACCELERATOR BARREL & ARTICULATED RAIL SHROUDS
def build_handguard_and_barrel():
    def hg_role(edge, row):
        if edge in {4, 6}:
            return STL
        if edge in {11, 0, 10}:
            return DRK
        if edge in {1, 9}:
            return SLT
        return OBS

    hg = hull_bm([
        (1.08, 0.088, 0.150, 0.458,  0.00),
        (1.38, 0.086, 0.158, 0.456,  0.00),
        (1.88, 0.082, 0.188, 0.452,  0.04),
        (2.26, 0.074, 0.238, 0.448,  0.14),
    ], face_role=hg_role, ref_z=0.34)
    S.link("RFO_Handguard", hg)

    # Flank plasma vent rails embedded down both sides of the handguard
    hg_glow = merge_bms([
        box_bm(1.16, 2.18,  0.074,  0.090, 0.310, 0.352, ch=0.004, mat=COR, bevel_mat=HOT),
        box_bm(1.16, 2.18, -0.090, -0.074, 0.310, 0.352, ch=0.004, mat=COR, bevel_mat=HOT),
        # Lower handguard grip rib
        box_bm(1.20, 1.98, -0.056,  0.056, 0.135, 0.175, ch=0.008, mat=GRP, bevel_mat=DRK),
    ])
    S.link("RFO_HandguardVents", hg_glow)

    # Core octagonal dark-steel sniper barrel + glowing plasma accelerator conduit!
    core_tube = loft_rings_bm(
        [
            oct_ring_x(2.15, 0.046, 0.046, cz=BORE_Z),
            oct_ring_x(3.38, 0.040, 0.040, cz=BORE_Z),
            oct_ring_x(3.52, 0.036, 0.036, cz=BORE_Z),
        ],
        face_role=lambda e, r: DRK if e % 2 == 0 else SLT,
        cap0_mat=DRK,
        cap1_mat=DRK,
    )
    S.link("RFO_InnerBarrel", core_tube)

    # Exposed bright violet plasma accelerator spine running between the dual rails!
    plasma_core = loft_rings_bm(
        [
            oct_ring_x(2.22, 0.058, 0.030, cz=BORE_Z, n=6, phase=0.0),
            oct_ring_x(3.26, 0.052, 0.026, cz=BORE_Z, n=6, phase=0.0),
        ],
        face_role=lambda e, r: HOT if e in {0, 3} else COR,
        cap0_mat=COR,
        cap1_mat=HOT,
    )
    S.link("RFO_RailPlasmaCore", plasma_core)

    # 4 heavy stepped antique-bronze accelerator coil clamps along handguard & barrel
    coils = []
    for cx, rw, rh, cz in (
        (1.42, 0.092, 0.125, 0.315),
        (1.92, 0.088, 0.118, 0.335),
        (2.42, 0.072, 0.088, BORE_Z),
        (2.94, 0.068, 0.082, BORE_Z),
    ):
        coils.append(loft_rings_bm(
            [
                oct_ring_x(cx - 0.036, rw * 0.92, rh * 0.92, cz=cz),
                oct_ring_x(cx - 0.018, rw,        rh,        cz=cz),
                oct_ring_x(cx + 0.018, rw,        rh,        cz=cz),
                oct_ring_x(cx + 0.036, rw * 0.92, rh * 0.92, cz=cz),
            ],
            face_role=lambda e, r: BRZ if r == 1 else SLT,
            cap0_mat=DRK,
            cap1_mat=DRK,
        ))
    S.link("RFO_RailCoils", merge_bms(coils))

    # Aggressive dual-prong railgun muzzle brake right at X = 3.22..3.52!
    muzzle = merge_bms([
        hull_bm([
            (3.22, 0.066, BORE_Z - 0.078, BORE_Z + 0.078,  0.00),
            (3.36, 0.080, BORE_Z - 0.088, BORE_Z + 0.088,  0.04),
            (3.52, 0.072, BORE_Z - 0.072, BORE_Z + 0.072,  0.16),
        ], face_role=lambda e, r: STL if e in {4, 6} else (BRZ if r == 0 else OBS), ref_z=BORE_Z),
        # Side plasma exhaust ports on muzzle brake
        box_bm(3.28, 3.46,  0.066,  0.082, BORE_Z - 0.022, BORE_Z + 0.022, ch=0.003, mat=COR, bevel_mat=HOT),
        box_bm(3.28, 3.46, -0.082, -0.066, BORE_Z - 0.022, BORE_Z + 0.022, ch=0.003, mat=COR, bevel_mat=HOT),
    ])
    S.link("RFO_MuzzleBrake", muzzle)

    # ARTICULATED UPPER & LOWER RAIL SHROUDS (VentTop / VentBottom — split & recoil on shot!)
    for sign, fg in ((+1, "VentTop"), (-1, "VentBottom")):
        z0 = BORE_Z + sign * 0.034
        z1 = BORE_Z + sign * 0.094
        z_lo, z_hi = min(z0, z1), max(z0, z1)
        shroud_slt = hull_bm([
            (2.14, 0.056, z_lo, z_hi,  0.10 * sign),
            (2.36, 0.066, z_lo, z_hi,  0.00),
            (3.04, 0.062, z_lo, z_hi,  0.00),
            (3.22, 0.050, z_lo + 0.006, z_hi - 0.006, 0.14 * sign),
        ], face_role=lambda e, r: SLT, cap0_mat=SLT, cap1_mat=SLT, ref_z=0.5 * (z_lo + z_hi))
        S.link(f"RFO_{fg}_Slt", shroud_slt, bone="Root", flat_group=fg + "_Slt")

        bz_lo = BORE_Z + sign * 0.086 if sign > 0 else BORE_Z - 0.104
        bz_hi = BORE_Z + sign * 0.104 if sign > 0 else BORE_Z - 0.086
        shroud_brz = box_bm(2.30, 3.06, -0.032, 0.032, bz_lo, bz_hi, ch=0.006, mat=BRZ, bevel_mat=BRZ)
        S.link(f"RFO_{fg}_Brz", shroud_brz, bone="Root", flat_group=fg + "_Brz")


# 5. SCULPTED OCTAGONAL SNIPER SCOPE (X = -0.06..1.58, Z = 0.46..0.77)
def build_scope():
    # Dual cantilevered forged scope rings/mounts anchoring scope cleanly onto receiver
    mounts = merge_bms([
        box_bm(0.22, 0.34, -0.052, 0.052, 0.445, 0.545, ch=0.008, mat=SLT, bevel_mat=STL),
        box_bm(0.96, 1.08, -0.052, 0.052, 0.445, 0.545, ch=0.008, mat=SLT, bevel_mat=STL),
        box_bm(0.18, 1.12, -0.044, 0.044, 0.458, 0.492, ch=0.006, mat=DRK, bevel_mat=SLT),
    ])
    S.link("RFO_ScopeMounts", mounts)

    # Faceted octagonal sniper optic tube (flared ocular -> waisted mid -> massive armored objective bell!)
    scope_rings = [
        oct_ring_x(-0.075, 0.098, 0.098, cz=SCOPE_Z, rake=-0.08),
        oct_ring_x(0.080,  0.108, 0.108, cz=SCOPE_Z),
        oct_ring_x(0.200,  0.078, 0.078, cz=SCOPE_Z),
        oct_ring_x(0.980,  0.078, 0.078, cz=SCOPE_Z),
        oct_ring_x(1.160,  0.128, 0.128, cz=SCOPE_Z),
        oct_ring_x(1.520,  0.136, 0.136, cz=SCOPE_Z),
        oct_ring_x(1.590,  0.124, 0.124, cz=SCOPE_Z, rake=0.18),
    ]
    def sc_role(edge, row):
        if row in {1, 4}:
            return BRZ  # bronze stepped bell collars
        if edge in {1, 2, 5, 6}:
            return STL if edge in {1, 2} else SLT
        return OBS
    S.link("RFO_ScopeBody", loft_rings_bm(scope_rings, face_role=sc_role, cap0_mat=DRK, cap1_mat=DRK))

    # Top/side adjustment turrets + glowing violet lenses + side plasma charge bar
    scope_acc = merge_bms([
        # Elevation & windage turrets
        box_bm(0.54, 0.70, -0.044, 0.044, SCOPE_Z + 0.068, SCOPE_Z + 0.132, ch=0.010, mat=BRZ, bevel_mat=STL),
        box_bm(0.56, 0.68,  0.068, 0.118, SCOPE_Z - 0.038, SCOPE_Z + 0.038, ch=0.008, mat=BRZ, bevel_mat=STL),
        # Side plasma power strips on objective hood
        box_bm(1.18, 1.50,  0.124,  0.140, SCOPE_Z - 0.022, SCOPE_Z + 0.022, ch=0.003, mat=COR, bevel_mat=HOT),
        box_bm(1.18, 1.50, -0.140, -0.124, SCOPE_Z - 0.022, SCOPE_Z + 0.022, ch=0.003, mat=COR, bevel_mat=HOT),
        # Glowing violet ocular & objective glass lenses
        loft_rings_bm([
            oct_ring_x(-0.082, 0.082, 0.082, cz=SCOPE_Z),
            oct_ring_x(-0.068, 0.084, 0.084, cz=SCOPE_Z),
        ], face_role=lambda e, r: COR, cap0_mat=HOT, cap1_mat=COR),
        loft_rings_bm([
            oct_ring_x(1.572, 0.106, 0.106, cz=SCOPE_Z),
            oct_ring_x(1.596, 0.102, 0.102, cz=SCOPE_Z),
        ], face_role=lambda e, r: COR, cap0_mat=COR, cap1_mat=HOT),
    ])
    S.link("RFO_ScopeDetails", scope_acc)


# 6. SCULPTED SNIPER STOCK, ERGONOMIC GRIP & PLASMA CELL MAGAZINE
def build_stock_grip_mag():
    # Armored skeletal sniper stock (X = -1.32..0.06)
    stock_upper = hull_bm([
        (-1.315, 0.064, -0.205, 0.405,  0.00),
        (-1.220, 0.074, -0.185, 0.416,  0.00),
        (-0.980, 0.078,  0.220, 0.422, -0.10),
        (-0.340, 0.080,  0.245, 0.424,  0.00),
        (0.065,  0.076,  0.185, 0.440,  0.06),
    ], face_role=lambda e, r: STL if e in {4, 6} else (BRZ if r == 0 else OBS), ref_z=0.30)

    # Lower skeletal tie strut & glowing rear power stabilizer bar
    stock_lower = merge_bms([
        hull_bm([
            (-1.24, 0.056, -0.190, -0.075, 0.0),
            (-0.56, 0.048, -0.145, -0.055, 0.0),
            (-0.08, 0.052, -0.055,  0.045, 0.0),
        ], face_role=lambda e, r: SLT if e in {4, 6} else DRK, ref_z=-0.10),
        # Sculpted carbon cheek pad
        hull_bm([
            (-1.02, 0.072, 0.378, 0.456, 0.0),
            (-0.42, 0.074, 0.382, 0.458, 0.0),
        ], face_role=lambda e, r: GRP, cap0_mat=DRK, cap1_mat=DRK, ref_z=0.42),
        # Glowing violet stock stabilizer accent
        box_bm(-1.14, -0.42, -0.064, 0.064, 0.285, 0.320, ch=0.004, mat=COR, bevel_mat=HOT),
    ])
    S.link("RFO_Stock", merge_bms([stock_upper, stock_lower]))

    # Ergonomic carbon-twill angled pistol grip
    grip_rings = []
    for t in (0.0, 0.25, 0.65, 1.0):
        z = 0.145 - t * 0.395
        x0 = -0.095 - t * 0.095
        x1 = 0.115 - t * 0.080
        yw = 0.054 + 0.008 * math.sin(t * math.pi)
        xm = 0.5 * (x0 + x1)
        grip_rings.append([
            (x0, -yw * 0.65, z), (xm, -yw, z), (x1, -yw * 0.72, z),
            (x1,  yw * 0.72, z), (xm,  yw, z), (x0,  yw * 0.65, z),
        ])
    S.link("RFO_Grip", loft_rings_bm(grip_rings, face_role=lambda e, r: GRP if e in {0, 1, 3, 4} else DRK, cap0_mat=DRK, cap1_mat=BRZ))

    # Plasma Energy Battery Magazine (parented to Mag bone!)
    mag_body = hull_bm([
        (0.445, 0.064, -0.088, 0.228, 0.04),
        (0.640, 0.066, -0.090, 0.230, 0.00),
        (0.822, 0.064, -0.082, 0.225, -0.04),
    ], face_role=lambda e, r: STL if e in {4, 6} else OBS, cap0_mat=DRK, cap1_mat=DRK, ref_z=0.07)
    mag_acc = merge_bms([
        box_bm(0.438, 0.832, -0.070, 0.070, -0.105, -0.070, ch=0.006, mat=BRZ, bevel_mat=BRZ),
        box_bm(0.495, 0.775,  0.056, 0.070, -0.045,  0.145, ch=0.003, mat=COR, bevel_mat=HOT),
        box_bm(0.495, 0.775, -0.070, -0.056, -0.045, 0.145, ch=0.003, mat=COR, bevel_mat=HOT),
    ])
    S.link("RFO_Mag", merge_bms([mag_body, mag_acc]), bone="Mag")


build_receiver()
build_reactor_core()
build_reactor_cowls()
build_handguard_and_barrel()
build_scope()
build_stock_grip_mag()

res = S.finalize(
    replaced_prefixes=[
        "Neon", "Receiver", "Handguard", "Barrel", "Grip",
        "Stock", "Magazine", "Scope", "ScopeLens", "Bolt",
    ],
    center_checks=["RFO_Receiver", "RFO_ScopeBody", "RFO_CoreCrystal", "RFO_InnerBarrel"],
    cam_specs={
        "center": (1.05, 0.0, 0.33),
        "span": 4.9,
        "hero_loc": (4.40, 4.10, 1.95),
        "hero_ortho": 5.25,
        "side_loc": (1.05, 5.80, 0.33),
        "side_ortho": 5.35,
        "fp_loc": (-1.55, 0.72, 0.92),
        "fp_tgt": (1.35, 0.0, 0.38),
        "close_loc": (1.15, 1.15, 0.68),
        "close_tgt": (0.64, 0.0, 0.36),
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
