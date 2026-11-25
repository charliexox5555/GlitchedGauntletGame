"""Build Riftforge Sheriff v01 (Heavy Reactor Revolver) in live Blender 5.2 MCP.

Signature Legendary hooks:
- Open-cage Suspended Plasma Core Drum on the Cylinder bone (glowing faceted dark-matter
  core crystal + 6 recessed plasma cells framed by antique-bronze end-plates & fluted slate
  cage ribs — swings out cleanly on Crane during reload!).
- Heavy tapered forged-obsidian hand-cannon barrel with exposed lateral plasma channels,
  bronze muzzle crown, and crisp open hex-arch iron sights.
- Articulated side barrel armor shrouds (CowlLeft / CowlRight) + upper/lower underlug plasma
  vents (VentTop / VentBottom) that flare wide on every thunderous shot & SLAM shut on lock!
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

S = K.RiftforgeScene("Sheriff", "v01")

CYL_CX, CYL_CY, CYL_CZ = 0.473, 0.0, 0.190
BORE_Z = 0.278


# 1. SCULPTED REVOLVER FRAME (Open Cylinder Window + Heavy Top Bridge + Trigger Guard)
def build_frame():
    def fr_role(edge, row):
        if edge in {11, 0, 10}:
            return DRK
        if edge in {4, 6}:
            return STL
        if edge in {1, 9}:
            return SLT
        return OBS

    # Rear receiver & recoil shield
    rear = hull_bm([
        (-0.075, 0.058,  0.040, 0.300, -0.18),
        (0.060,  0.072, -0.025, 0.345, -0.08),
        (0.240,  0.076, -0.045, 0.375,  0.00),
        (0.305,  0.076, -0.030, 0.382,  0.00),
    ], face_role=fr_role, ref_z=0.19)

    # Top strap bridge spanning cleanly above the spinning plasma cylinder!
    top_strap = hull_bm([
        (0.270, 0.064, 0.338, 0.388, 0.00),
        (0.473, 0.064, 0.340, 0.390, 0.00),
        (0.755, 0.068, 0.336, 0.386, 0.04),
    ], face_role=lambda e, r: STL if e in {4, 6} else OBS, ref_z=0.36)

    # Lower frame backbone + forged trigger guard
    lower = hull_bm([
        (0.180, 0.056, -0.065, 0.042, 0.00),
        (0.473, 0.060, -0.045, 0.042, 0.00),
        (0.745, 0.068,  0.045, 0.135, 0.08),
    ], face_role=lambda e, r: SLT if e in {1, 9} else DRK, ref_z=0.02)

    tg = merge_bms([
        box_bm(0.155, 0.510, -0.020, 0.020, -0.215, -0.185, ch=0.005, mat=SLT, bevel_mat=STL),
        box_bm(0.475, 0.515, -0.020, 0.020, -0.215, -0.035, ch=0.005, mat=SLT, bevel_mat=STL),
        box_bm(0.145, 0.185, -0.020, 0.020, -0.215, -0.055, ch=0.005, mat=SLT, bevel_mat=STL),
    ])

    # Antique-bronze recoil shield & barrel-throat structural collars
    collars = merge_bms([
        box_bm(0.285, 0.312, -0.078, 0.078, 0.045, 0.345, ch=0.006, mat=BRZ, bevel_mat=BRZ),
        box_bm(0.655, 0.765, -0.074, 0.074, 0.075, 0.348, ch=0.007, mat=OBS, bevel_mat=STL),
        box_bm(0.660, 0.705, -0.079, 0.079, 0.095, 0.342, ch=0.005, mat=BRZ, bevel_mat=BRZ),
    ])
    S.link("RFS_Frame", merge_bms([rear, top_strap, lower, tg, collars]))


# 2. SUSPENDED PLASMA CORE DRUM (Cylinder bone!) + ROUNDS + HAMMER
def build_cylinder_and_action():
    # Open hexagonal plasma reactor drum cage (front/rear bronze endplates + 6 fluted dark ribs)
    front_plate = loft_rings_bm([
        oct_ring_x(0.588, 0.126, 0.126, cz=CYL_CZ, n=6, phase=0.0),
        oct_ring_x(0.628, 0.118, 0.118, cz=CYL_CZ, n=6, phase=0.0),
    ], face_role=lambda e, r: BRZ, cap0_mat=DRK, cap1_mat=BRZ)
    rear_plate = loft_rings_bm([
        oct_ring_x(0.318, 0.118, 0.118, cz=CYL_CZ, n=6, phase=0.0),
        oct_ring_x(0.358, 0.126, 0.126, cz=CYL_CZ, n=6, phase=0.0),
    ], face_role=lambda e, r: BRZ, cap0_mat=BRZ, cap1_mat=DRK)

    ribs = [front_plate, rear_plate]
    for i in range(6):
        ang = math.pi / 6 + i * (math.pi / 3)
        ry = 0.118 * math.cos(ang)
        rz = CYL_CZ + 0.118 * math.sin(ang)
        ribs.append(loft_rings_bm([
            oct_ring_x(0.352, 0.018, 0.018, cy=ry, cz=rz, n=6),
            oct_ring_x(0.594, 0.018, 0.018, cy=ry, cz=rz, n=6),
        ], face_role=lambda e, r: SLT if e % 2 == 0 else STL, cap0_mat=DRK, cap1_mat=DRK))

        # Inner glowing violet plasma energy rod between each rib pair!
        ang_c = i * (math.pi / 3)
        cy = 0.088 * math.cos(ang_c)
        cz = CYL_CZ + 0.088 * math.sin(ang_c)
        ribs.append(loft_rings_bm([
            oct_ring_x(0.356, 0.020, 0.020, cy=cy, cz=cz, n=6),
            oct_ring_x(0.590, 0.020, 0.020, cy=cy, cz=cz, n=6),
        ], face_role=lambda e, r: HOT if e in {0, 3} else COR, cap0_mat=COR, cap1_mat=COR))

    S.link("RFS_CylinderCage", merge_bms(ribs), bone="Cylinder")

    # Central glowing faceted plasma core crystal inside the drum (Cylinder bone!)
    crys = crystal_bm(CYL_CX, CYL_CY, CYL_CZ, 0.095, 0.068, 0.068, mat=COR)
    S.link("RFS_CoreCrystal", crys, bone="Cylinder", flat_group="CoreCrystal")

    # Counter-rotating containment ring mounted right around the barrel-throat core axis
    ring_a = ring_bm(0.640, 0.0, CYL_CZ, rad=0.108, thick=0.012, width=0.016, n=8, axis="X", mat=STL)
    S.link("RFS_CoreRingA", ring_a, bone="Root", flat_group="CoreRingA")
    ring_b = ring_bm(0.312, 0.0, CYL_CZ, rad=0.104, thick=0.011, width=0.015, n=6, axis="X", mat=BRZ)
    S.link("RFS_CoreRingB", ring_b, bone="Root", flat_group="CoreRingB")

    # Glowing plasma energy cartridges on Rounds bone (visible when cylinder swings out!)
    r_bms = []
    for i in range(6):
        ang = i * (math.pi / 3)
        cy = 0.088 * math.cos(ang)
        cz = CYL_CZ + 0.088 * math.sin(ang)
        r_bms.append(loft_rings_bm([
            oct_ring_x(0.312, 0.020, 0.020, cy=cy, cz=cz, n=6),
            oct_ring_x(0.460, 0.019, 0.019, cy=cy, cz=cz, n=6),
        ], face_role=lambda e, r: BRZ if r == 0 else COR, cap0_mat=HOT, cap1_mat=COR))
    S.link("RFS_Rounds", merge_bms(r_bms), bone="Rounds")

    # Sculpted bronze/steel Reactor Hammer (Hammer bone!)
    hammer = merge_bms([
        box_bm(0.085, 0.165, -0.016, 0.016, 0.215, 0.345, ch=0.005, mat=BRZ, bevel_mat=STL),
        box_bm(0.018, 0.105, -0.018, 0.018, 0.315, 0.358, ch=0.005, mat=STL, bevel_mat=BRZ),
    ])
    S.link("RFS_Hammer", hammer, bone="Hammer")


# 3. HEAVY HAND-CANNON BARREL, PLASMA CHANNELS, ARTICULATED SHROUDS & SIGHTS
def build_barrel_and_sights():
    def brl_role(edge, row):
        if edge in {4, 6}:
            return STL
        if edge in {11, 0, 10}:
            return DRK
        if edge in {1, 9}:
            return SLT
        return OBS

    barrel = hull_bm([
        (0.745, 0.068, 0.105, 0.355,  0.00),
        (1.060, 0.066, 0.112, 0.354,  0.00),
        (1.360, 0.062, 0.132, 0.350,  0.06),
        (1.495, 0.056, 0.156, 0.344,  0.16),
    ], face_role=brl_role, ref_z=BORE_Z)

    # Exposed plasma accelerator channels running along both flanks of the heavy barrel
    glow = merge_bms([
        box_bm(0.775, 1.410,  0.056,  0.070, 0.228, 0.268, ch=0.003, mat=COR, bevel_mat=HOT),
        box_bm(0.775, 1.410, -0.070, -0.056, 0.228, 0.268, ch=0.003, mat=COR, bevel_mat=HOT),
        # Stepped antique-bronze muzzle crown & bore ring
        hull_bm([
            (1.390, 0.066, 0.148, 0.352, 0.04),
            (1.488, 0.062, 0.162, 0.346, 0.14),
        ], face_role=lambda e, r: BRZ if e not in {4, 6} else STL, cap0_mat=BRZ, cap1_mat=DRK, ref_z=BORE_Z),
    ])
    S.link("RFS_Barrel", merge_bms([barrel, glow]))

    # Articulated side barrel-rail cowls (CowlLeft / CowlRight — flare open on every shot!)
    for side, fg in ((+1, "CowlLeft"), (-1, "CowlRight")):
        slt_st = [
            (0.78, 0.060, 0.078, 0.140, 0.178, 0.215, -0.10),
            (1.06, 0.062, 0.086, 0.142, 0.180, 0.218,  0.00),
            (1.34, 0.056, 0.074, 0.158, 0.186, 0.216,  0.14),
        ]
        S.link(
            f"RFS_{fg}_Slt",
            facet_blade_bm(side, slt_st, face_role=lambda e, r: SLT, cap_mat=SLT, ref_z=0.18),
            bone="Root",
            flat_group=fg + "_Slt",
        )
        brz_st = [
            (0.84, 0.072, 0.090, 0.168, 0.180, 0.192, -0.04),
            (1.26, 0.070, 0.088, 0.172, 0.182, 0.192,  0.08),
        ]
        S.link(
            f"RFS_{fg}_Brz",
            facet_blade_bm(side, brz_st, face_role=lambda e, r: BRZ, cap_mat=BRZ, ref_z=0.18),
            bone="Root",
            flat_group=fg + "_Brz",
        )

    # Articulated top ventilated rail fin (VentTop) & lower underlug vent jaw (VentBottom)
    v_top_slt = hull_bm([
        (0.80, 0.030, 0.352, 0.382,  0.06),
        (1.06, 0.034, 0.352, 0.386,  0.00),
        (1.30, 0.028, 0.350, 0.380,  0.10),
    ], face_role=lambda e, r: SLT, cap0_mat=SLT, cap1_mat=SLT, ref_z=0.368)
    S.link("RFS_VentTop_Slt", v_top_slt, bone="Root", flat_group="VentTop_Slt")
    S.link("RFS_VentTop_Brz", box_bm(0.88, 1.24, -0.016, 0.016, 0.380, 0.394, ch=0.003, mat=BRZ, bevel_mat=BRZ),
           bone="Root", flat_group="VentTop_Brz")

    v_bot_slt = hull_bm([
        (0.78, 0.044, 0.078, 0.114, -0.08),
        (1.06, 0.048, 0.082, 0.118,  0.00),
        (1.32, 0.040, 0.102, 0.132,  0.12),
    ], face_role=lambda e, r: SLT, cap0_mat=SLT, cap1_mat=SLT, ref_z=0.10)
    S.link("RFS_VentBottom_Slt", v_bot_slt, bone="Root", flat_group="VentBottom_Slt")
    S.link("RFS_VentBottom_Brz", box_bm(0.86, 1.24, -0.024, 0.024, 0.068, 0.086, ch=0.004, mat=BRZ, bevel_mat=BRZ),
           bone="Root", flat_group="VentBottom_Brz")

    # Crisp open tactical iron sights (clean sight picture at Z = 0.415!)
    sights = merge_bms([
        # Rear twin-ear iron notch
        box_bm(0.245, 0.315,  0.014,  0.036, 0.376, 0.422, ch=0.004, mat=SLT, bevel_mat=STL),
        box_bm(0.245, 0.315, -0.036, -0.014, 0.376, 0.422, ch=0.004, mat=SLT, bevel_mat=STL),
        box_bm(0.248, 0.275,  0.018,  0.032, 0.402, 0.416, ch=0.002, mat=COR, bevel_mat=HOT),
        box_bm(0.248, 0.275, -0.032, -0.018, 0.402, 0.416, ch=0.002, mat=COR, bevel_mat=HOT),
        # Front hooded sight blade with glowing lilac dot
        box_bm(1.345, 1.435, -0.014,  0.014, 0.344, 0.420, ch=0.004, mat=SLT, bevel_mat=STL),
        box_bm(1.365, 1.420, -0.007,  0.007, 0.405, 0.426, ch=0.002, mat=HOT, bevel_mat=HOT),
    ])
    S.link("RFS_Sights", sights)


# 4. SCULPTED ERGONOMIC CARBON REVOLVER GRIP + BRONZE POMMEL HEEL
def build_grip():
    grip_rings = []
    for t in (0.0, 0.25, 0.65, 1.0):
        z = 0.165 - t * 0.565
        x0 = -0.045 - t * 0.215
        x1 = 0.165 - t * 0.145
        yw = 0.052 + 0.012 * math.sin(t * math.pi)
        xm = 0.5 * (x0 + x1)
        grip_rings.append([
            (x0, -yw * 0.62, z), (xm, -yw, z), (x1, -yw * 0.68, z),
            (x1,  yw * 0.68, z), (xm,  yw, z), (x0,  yw * 0.62, z),
        ])
    g_body = loft_rings_bm(grip_rings, face_role=lambda e, r: GRP if e in {0, 1, 3, 4} else DRK, cap0_mat=DRK, cap1_mat=DRK)
    pommel = box_bm(-0.275, 0.035, -0.062, 0.062, -0.435, -0.392, ch=0.008, mat=BRZ, bevel_mat=BRZ)
    S.link("RFS_Grip", merge_bms([g_body, pommel]))


build_frame()
build_cylinder_and_action()
build_barrel_and_sights()
build_grip()

res = S.finalize(
    replaced_prefixes=[
        "Neon", "Frame", "Barrel", "Cylinder", "Grip",
        "Hammer", "Rounds", "Sights", "Pins",
    ],
    center_checks=["RFS_Frame", "RFS_Barrel", "RFS_CoreCrystal", "RFS_Sights"],
    cam_specs={
        "center": (0.62, 0.0, 0.06),
        "span": 2.15,
        "hero_loc": (2.25, 2.05, 0.88),
        "hero_ortho": 2.35,
        "side_loc": (0.62, 2.85, 0.06),
        "side_ortho": 2.35,
        "fp_loc": (-0.92, 0.36, 0.44),
        "fp_tgt": (0.80, 0.0, 0.24),
        "close_loc": (0.76, 0.72, 0.34),
        "close_tgt": (0.47, 0.0, 0.19),
        "icon_loc": (1.35, 2.55, 0.36),
        "icon_ortho": 2.30,
        "portrait_loc": (2.00, 1.88, 0.78),
        "portrait_ortho": 2.15,
        "ray_x": (-0.2, 1.45),
        "ray_z": (-0.38, 0.42),
    },
)
result = res
print(json.dumps(res, indent=2))
