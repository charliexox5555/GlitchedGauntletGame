"""Build Riftforge Shorty v01 (Break-Action Twin-Core Plasma Pocket Shotgun) in live Blender 5.2 MCP.

Signature Legendary hooks:
- Sculpted break-action receiver with cut-through Reactor Core Bay housing CoreCrystal +
  dual counter-rotating gimbal rings (CoreRingA steel + CoreRingB bronze) + split cheek cowls
  (CowlLeft / CowlRight), 100% visible at idle!
- Twin side-by-side faceted octagonal plasma barrels on Barrels bone (cracks open cleanly on
  reload!) with glowing central plasma spine, heavy carbon forend, bronze breech & muzzle
  collars, and articulated barrel-mounted VentTop / VentBottom jaw shrouds!
- Twin glowing violet plasma shotgun shells on ShellUpper / ShellLower bones + bronze BreechLatch.
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

S = K.RiftforgeScene("Shorty", "v01")

CORE_CX, CORE_CY, CORE_CZ = 0.275, 0.0, 0.245
BORE_Z = 0.260


# 1. SCULPTED BREAK-ACTION RECEIVER FRAME & CUT-THROUGH REACTOR BAY
def build_frame():
    def fr_role(edge, row):
        if edge in {11, 0, 10}:
            return DRK
        if edge in {4, 6}:
            return STL
        if edge in {1, 9}:
            return SLT
        return OBS

    frame = S.link("RFSH_Frame", hull_bm([
        (-0.095, 0.068,  0.045, 0.305, -0.16),
        (0.050,  0.092,  0.025, 0.352, -0.06),
        (0.460,  0.096,  0.025, 0.362,  0.00),
        (0.555,  0.092,  0.075, 0.352,  0.04),
    ], face_role=fr_role, ref_z=0.22))

    # Cut open the cut-through Reactor Core Bay cleanly behind the breech hinge!
    bay_cut = box_bm(0.115, 0.435, -0.16, 0.16, 0.162, 0.328)
    S.bool_cut(frame, [bay_cut])

    # Forged trigger guard, hinge knuckle & bay plasma floor/ceiling bars
    acc = merge_bms([
        # Trigger guard
        box_bm(0.120, 0.455, -0.022, 0.022, -0.098, -0.072, ch=0.005, mat=SLT, bevel_mat=STL),
        box_bm(0.425, 0.460, -0.022, 0.022, -0.098,  0.045, ch=0.005, mat=SLT, bevel_mat=STL),
        box_bm(0.115, 0.148, -0.022, 0.022, -0.098,  0.045, ch=0.005, mat=SLT, bevel_mat=STL),
        # Glowing bay plasma liners + bronze bulkhead cheeks
        box_bm(0.122, 0.428, -0.052, 0.052, 0.320, 0.335, ch=0.003, mat=COR, bevel_mat=HOT),
        box_bm(0.122, 0.428, -0.052, 0.052, 0.154, 0.170, ch=0.003, mat=COR, bevel_mat=HOT),
        box_bm(0.100, 0.120, -0.058, 0.058, 0.164, 0.326, ch=0.004, mat=BRZ, bevel_mat=BRZ),
        box_bm(0.430, 0.450, -0.058, 0.058, 0.164, 0.326, ch=0.004, mat=BRZ, bevel_mat=BRZ),
        # Heavy antique-bronze break-action hinge knuckle at X = 0.546, Z = 0.114
        loft_rings_bm([
            oct_ring_x(0.485, 0.098, 0.052, cz=0.114),
            oct_ring_x(0.578, 0.094, 0.048, cz=0.114),
        ], face_role=lambda e, r: BRZ, cap0_mat=BRZ, cap1_mat=BRZ),
        # Rear twin-notch iron sight ears
        box_bm(0.02, 0.10,  0.022,  0.044, 0.348, 0.382, ch=0.004, mat=SLT, bevel_mat=STL),
        box_bm(0.02, 0.10, -0.044, -0.022, 0.348, 0.382, ch=0.004, mat=SLT, bevel_mat=STL),
        box_bm(0.03, 0.06,  0.026,  0.040, 0.366, 0.378, ch=0.002, mat=COR, bevel_mat=HOT),
        box_bm(0.03, 0.06, -0.040, -0.026, 0.366, 0.378, ch=0.002, mat=COR, bevel_mat=HOT),
    ])
    S.link("RFSH_FrameDetails", acc)

    # Sculpted bronze BreechLatch (BreechLatch bone!)
    latch = box_bm(0.288, 0.432, 0.086, 0.104, 0.120, 0.162, ch=0.005, mat=BRZ, bevel_mat=STL)
    S.link("RFSH_BreechLatch", latch, bone="BreechLatch")


# 2. FLOATING REACTOR CORE CRYSTAL, DUAL RINGS & ARTICULATED CHEEK COWLS
def build_reactor():
    S.link("RFSH_CoreCrystal", crystal_bm(CORE_CX, CORE_CY, CORE_CZ, 0.055, 0.054, 0.066, mat=COR),
           bone="Root", flat_group="CoreCrystal")
    S.link("RFSH_CoreRingA", ring_bm(CORE_CX, CORE_CY, CORE_CZ, rad=0.086, thick=0.012, width=0.016, n=8, axis="Y", mat=STL),
           bone="Root", flat_group="CoreRingA")
    S.link("RFSH_CoreRingB", ring_bm(CORE_CX, CORE_CY, CORE_CZ, rad=0.068, thick=0.010, width=0.014, n=6, axis="Y", mat=BRZ),
           bone="Root", flat_group="CoreRingB")

    for side, fg in ((+1, "CowlLeft"), (-1, "CowlRight")):
        slt_lo = [
            (0.08, 0.088, 0.108, 0.125, 0.148, 0.172, -0.10),
            (0.18, 0.092, 0.126, 0.120, 0.144, 0.168, -0.04),
            (0.38, 0.092, 0.126, 0.120, 0.144, 0.168,  0.04),
            (0.46, 0.088, 0.106, 0.128, 0.148, 0.170,  0.10),
        ]
        slt_hi = [
            (0.08, 0.088, 0.106, 0.314, 0.334, 0.356, -0.08),
            (0.18, 0.092, 0.122, 0.318, 0.338, 0.360, -0.04),
            (0.38, 0.092, 0.122, 0.318, 0.338, 0.360,  0.04),
            (0.46, 0.088, 0.106, 0.314, 0.334, 0.354,  0.08),
        ]
        S.link(
            f"RFSH_{fg}_Slt",
            merge_bms([
                facet_blade_bm(side, slt_lo, face_role=lambda e, r: SLT, cap_mat=SLT, ref_z=0.146),
                facet_blade_bm(side, slt_hi, face_role=lambda e, r: SLT, cap_mat=SLT, ref_z=0.336),
            ]),
            bone="Root",
            flat_group=fg + "_Slt",
        )
        brz_st = [
            (0.16, 0.108, 0.132, 0.136, 0.146, 0.156, -0.04),
            (0.40, 0.108, 0.132, 0.136, 0.146, 0.156,  0.04),
        ]
        S.link(
            f"RFSH_{fg}_Brz",
            facet_blade_bm(side, brz_st, face_role=lambda e, r: BRZ, cap_mat=BRZ, ref_z=0.146),
            bone="Root",
            flat_group=fg + "_Brz",
        )


# 3. TWIN SIDE-BY-SIDE PLASMA BARRELS, CARBON FOREND, ARTICULATED JAWS & PLASMA SHELLS
def build_barrels_and_shells():
    # Twin faceted octagonal shotgun barrels at Y = +0.05 and Y = -0.05, Z = 0.260 (Barrels bone!)
    b_parts = []
    for sy in (+0.050, -0.050):
        b_parts.append(loft_rings_bm([
            oct_ring_x(0.550, 0.050, 0.050, cy=sy, cz=BORE_Z),
            oct_ring_x(0.660, 0.052, 0.052, cy=sy, cz=BORE_Z),
            oct_ring_x(1.330, 0.048, 0.048, cy=sy, cz=BORE_Z),
            oct_ring_x(1.448, 0.046, 0.046, cy=sy, cz=BORE_Z, rake=0.14),
        ], face_role=lambda e, r: BRZ if r in {0, 2} else (STL if e in {1, 2} else OBS), cap0_mat=DRK, cap1_mat=DRK))

    # Central glowing plasma fusion core bridging the twin barrels + side plasma flutes
    b_parts.append(box_bm(0.62, 1.38, -0.036,  0.036, BORE_Z - 0.022, BORE_Z + 0.022, ch=0.004, mat=COR, bevel_mat=HOT))
    b_parts.append(box_bm(0.66, 1.32,  0.088,  0.104, BORE_Z - 0.018, BORE_Z + 0.018, ch=0.003, mat=COR, bevel_mat=HOT))
    b_parts.append(box_bm(0.66, 1.32, -0.104, -0.088, BORE_Z - 0.018, BORE_Z + 0.018, ch=0.003, mat=COR, bevel_mat=HOT))

    # Sculpted heavy carbon-twill lower forend grip & steel lug cradling the barrels
    forend = hull_bm([
        (0.560, 0.088, 0.035, 0.218, -0.06),
        (0.680, 0.094, 0.022, 0.222,  0.00),
        (1.060, 0.090, 0.038, 0.222,  0.04),
        (1.200, 0.078, 0.085, 0.215,  0.18),
    ], face_role=lambda e, r: GRP if e in {1, 2, 3, 7, 8, 9} else (STL if e in {4, 6} else OBS), ref_z=0.14)
    b_parts.append(forend)

    # Heavy bronze barrel clamp & glowing front plasma bead sight
    b_parts.append(box_bm(1.16, 1.24, -0.106, 0.106, 0.185, 0.318, ch=0.005, mat=BRZ, bevel_mat=BRZ))
    b_parts.append(box_bm(1.36, 1.43, -0.012, 0.012, 0.305, 0.354, ch=0.003, mat=SLT, bevel_mat=STL))
    b_parts.append(box_bm(1.375, 1.418, -0.007, 0.007, 0.348, 0.368, ch=0.002, mat=HOT, bevel_mat=HOT))

    S.link("RFSH_Barrels", merge_bms(b_parts), bone="Barrels")

    # Articulated Barrel-Mounted Upper & Lower Accelerator Jaws (VentTop / VentBottom on Barrels bone!)
    v_top_slt = hull_bm([
        (0.68, 0.046, 0.306, 0.342,  0.08),
        (0.94, 0.052, 0.306, 0.346,  0.00),
        (1.15, 0.044, 0.304, 0.340,  0.10),
    ], face_role=lambda e, r: SLT, cap0_mat=SLT, cap1_mat=SLT, ref_z=0.325)
    S.link("RFSH_VentTop_Slt", v_top_slt, bone="Barrels", flat_group="VentTop_Slt")
    S.link("RFSH_VentTop_Brz", box_bm(0.74, 1.10, -0.022, 0.022, 0.340, 0.354, ch=0.003, mat=BRZ, bevel_mat=BRZ),
           bone="Barrels", flat_group="VentTop_Brz")

    v_bot_slt = hull_bm([
        (0.68, 0.056, 0.000, 0.036, -0.08),
        (0.92, 0.060, 0.000, 0.038,  0.00),
        (1.12, 0.050, 0.018, 0.050,  0.12),
    ], face_role=lambda e, r: SLT, cap0_mat=SLT, cap1_mat=SLT, ref_z=0.022)
    S.link("RFSH_VentBottom_Slt", v_bot_slt, bone="Barrels", flat_group="VentBottom_Slt")
    S.link("RFSH_VentBottom_Brz", box_bm(0.74, 1.06, -0.028, 0.028, -0.012, 0.006, ch=0.004, mat=BRZ, bevel_mat=BRZ),
           bone="Barrels", flat_group="VentBottom_Brz")

    # Twin Glowing Plasma Shotgun Shells (ShellUpper at Y=+0.05, ShellLower at Y=-0.05!)
    for bone_name, sy in (("ShellUpper", +0.050), ("ShellLower", -0.050)):
        shell = loft_rings_bm([
            oct_ring_x(0.540, 0.032, 0.032, cy=sy, cz=BORE_Z, n=8),
            oct_ring_x(0.585, 0.030, 0.030, cy=sy, cz=BORE_Z, n=8),
            oct_ring_x(0.722, 0.029, 0.029, cy=sy, cz=BORE_Z, n=8),
        ], face_role=lambda e, r: BRZ if r == 0 else (HOT if e in {0, 4} else COR), cap0_mat=BRZ, cap1_mat=HOT)
        S.link(f"RFSH_{bone_name}", shell, bone=bone_name)


# 4. SAWED-OFF CARBON SHOTGUN GRIP + BRONZE POMMEL
def build_grip():
    grip_rings = []
    for t in (0.0, 0.30, 0.70, 1.0):
        z = 0.115 - t * 0.435
        x0 = -0.065 - t * 0.165
        x1 = 0.145 - t * 0.145
        yw = 0.056 + 0.010 * math.sin(t * math.pi)
        xm = 0.5 * (x0 + x1)
        grip_rings.append([
            (x0, -yw * 0.65, z), (xm, -yw, z), (x1, -yw * 0.70, z),
            (x1,  yw * 0.70, z), (xm,  yw, z), (x0,  yw * 0.65, z),
        ])
    g = loft_rings_bm(grip_rings, face_role=lambda e, r: GRP if e in {0, 1, 3, 4} else DRK, cap0_mat=DRK, cap1_mat=DRK)
    pom = box_bm(-0.242, 0.015, -0.062, 0.062, -0.348, -0.308, ch=0.008, mat=BRZ, bevel_mat=BRZ)
    S.link("RFSH_Grip", merge_bms([g, pom]))


build_frame()
build_reactor()
build_barrels_and_shells()
build_grip()

res = S.finalize(
    replaced_prefixes=[
        "Neon", "Frame", "Barrels", "BarrelNeon", "Grip",
        "ShellUpper", "ShellLower", "BreechLatch",
    ],
    center_checks=["RFSH_Frame", "RFSH_Barrels", "RFSH_CoreCrystal"],
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
