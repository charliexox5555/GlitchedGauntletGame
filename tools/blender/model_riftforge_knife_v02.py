"""Build Riftfang Knife v02 (1-to-1 Faithful to Knife_Riftfang_concept_v01.png) in live Blender 5.2 MCP.

Upgrades over v01 (per owner art review):
- True razor needle-sharp predator tanto/spear tip where BOTH the upper clipped steel bevel
  and lower curved steel cutting edge converge cleanly to a sharp point!
- Exact concept hexagonal-diamond antique-bronze open crossguard housing floating CoreCrystal
  + counter-rotating CoreRing inside a crisp cut-through window.
- Concept-faithful V-splitting paired dorsal sawtooth armor scales (Scale1L/R, Scale2L/R,
  Scale3L/R) with bronze lower trim collars — sleek closed sawtooth silhouette at rest, flaring
  outward in a V-split during draw/slash/heavy/inspect (matching concept inset!).
- Waisted machined-steel-framed carbon grip flowing seamlessly into chamfered octagonal
  bronze pommel finger-twirl ring.
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
    loft_rings_bm, crystal_bm, ring_bm, merge_bms,
)

S = K.RiftforgeScene("Knife", "v02")

GUARD_CX, GUARD_CY, GUARD_CZ = 0.285, 0.0, 0.000


# 1. CHAMFERED OCTAGONAL BRONZE POMMEL RING & WAISTED STEEL-FRAMED CARBON GRIP
def build_handle_and_pommel():
    # Heavy chamfered octagonal bronze pommel finger-twirl ring (X = -0.355..-0.135)
    ring_cx = -0.245
    r_in, r_out = 0.072, 0.108
    hw = 0.025
    pom_rings = []
    n = 8
    # 6-point chamfered ring cross-section (dr from mid radius, y half-width)
    rm = 0.5 * (r_in + r_out)
    hr = 0.5 * (r_out - r_in)
    sec = [
        (-hr,        -hw * 0.58),
        (-hr * 0.65, -hw),
        ( hr * 0.65, -hw),
        ( hr,        -hw * 0.58),
        ( hr,         hw * 0.58),
        ( hr * 0.65,  hw),
        (-hr * 0.65,  hw),
        (-hr,         hw * 0.58),
    ]
    for i in range(n):
        a = 2.0 * math.pi * i / n + math.pi / n
        ca, sa = math.cos(a), math.sin(a)
        pts = [(ring_cx + (rm + dr) * ca, y, (rm + dr) * sa) for dr, y in sec]
        pom_rings.append(pts)
    pom_bm = loft_rings_bm(
        pom_rings,
        face_role=lambda e, r: STL if e in {1, 5} else BRZ,
        loop=True,
    )
    # Bronze neck collar smoothly bridging pommel ring into grip tang (zero gap!)
    neck_bm = loft_rings_bm([
        [(-0.158, -0.024, -0.044), (-0.158, 0.024, -0.044), (-0.158, 0.032, 0.0),
         (-0.158,  0.024,  0.044), (-0.158, -0.024, 0.044), (-0.158, -0.032, 0.0)],
        [(-0.120, -0.028, -0.056), (-0.120, 0.028, -0.056), (-0.120, 0.038, 0.0),
         (-0.120,  0.028,  0.056), (-0.120, -0.028, 0.056), (-0.120, -0.038, 0.0)],
    ], face_role=lambda e, r: BRZ, cap0_mat=BRZ, cap1_mat=DRK)
    S.link("RFK2_PommelRing", merge_bms([pom_bm, neck_bm]))

    # Sculpted contoured ergonomic handle: machined steel outer frame + inlaid carbon panels!
    # Stations: (x, half_w, z_bot, z_top) — contoured finger swell & narrow waist near guard
    grip_st = [
        (-0.128, 0.037, -0.056, 0.056),
        (-0.070, 0.042, -0.068, 0.062),  # palm swell
        ( 0.025, 0.044, -0.066, 0.060),  # mid contour
        ( 0.115, 0.038, -0.054, 0.054),  # ergonomic finger waist
        ( 0.195, 0.040, -0.062, 0.062),  # flares cleanly into diamond crossguard!
    ]
    g_rings = []
    for x, w, zb, zt in grip_st:
        zm = 0.5 * (zb + zt)
        g_rings.append([
            (x, -w * 0.58, zb),
            (x,  w * 0.58, zb),
            (x,  w * 0.92, zb + 0.016),
            (x,  w,        zm),
            (x,  w * 0.92, zt - 0.016),
            (x,  w * 0.58, zt),
            (x, -w * 0.58, zt),
            (x, -w * 0.92, zt - 0.016),
            (x, -w,        zm),
            (x, -w * 0.92, zb + 0.016),
        ])
    def grip_role(edge, row):
        if edge in {0, 5}:
            return STL  # gleaming machined steel spine & belly grip frame!
        if edge in {1, 4, 6, 9}:
            return SLT  # dark slate chamfered frame rim
        return GRP  # inlaid dark carbon-twill side grip panels!
    S.link("RFK2_Grip", loft_rings_bm(g_rings, face_role=grip_role, cap0_mat=DRK, cap1_mat=DRK))


# 2. CONCEPT-FAITHFUL DIAMOND-HEXAGON OPEN BRONZE CROSSGUARD + FLOATING CRYSTAL
def build_crossguard():
    cx, cz = GUARD_CX, GUARD_CZ
    # Elongated vertical diamond-hexagon frame matching Knife_Riftfang_concept_v01.png!
    # 6 outer vertices (XZ) around the open crystal eye
    outer_xz = [
        (cx - 0.105, cz + 0.000),  # rear point (joins grip cleanly!)
        (cx - 0.035, cz + 0.115),  # upper-rear shoulder
        (cx + 0.035, cz + 0.115),  # upper-front shoulder
        (cx + 0.105, cz + 0.000),  # front point (joins blade root cleanly!)
        (cx + 0.035, cz - 0.115),  # lower-front quillon
        (cx - 0.035, cz - 0.115),  # lower-rear quillon
    ]
    inner_xz = [
        (cx - 0.068, cz + 0.000),
        (cx - 0.020, cz + 0.072),
        (cx + 0.020, cz + 0.072),
        (cx + 0.068, cz + 0.000),
        (cx + 0.020, cz - 0.072),
        (cx - 0.020, cz - 0.072),
    ]

    # Build a closed beveled 6-sided frame loop around the open window!
    frame_rings = []
    hw = 0.044
    for i in range(6):
        ox, oz = outer_xz[i]
        ix, iz = inner_xz[i]
        mx, mz = 0.5 * (ox + ix), 0.5 * (oz + iz)
        frame_rings.append([
            (ix, -hw * 0.72, iz),
            (mx, -hw,        mz),
            (ox, -hw * 0.68, oz),
            (ox,  hw * 0.68, oz),
            (mx,  hw,        mz),
            (ix,  hw * 0.72, iz),
        ])
    guard_outer = loft_rings_bm(
        frame_rings,
        face_role=lambda e, r: STL if e in {0, 4} else BRZ,
        loop=True,
    )

    # Inner dark-obsidian structural collar seated inside the bronze diamond frame
    in_rings = []
    for i in range(6):
        ox, oz = inner_xz[i]
        ix = cx + (ox - cx) * 0.80
        iz = cz + (oz - cz) * 0.80
        in_rings.append([
            (ix, -0.028, iz),
            (ox, -0.034, oz),
            (ox,  0.034, oz),
            (ix,  0.028, iz),
        ])
    guard_inner = loft_rings_bm(in_rings, face_role=lambda e, r: OBS if e in {1, 3} else DRK, loop=True)

    # Solid forged ricasso bridge connecting guard front smoothly into the blade root
    ricasso = loft_rings_bm([
        [(0.345, -0.032, -0.068), (0.345, 0.032, -0.068), (0.345, 0.038, 0.0),
         (0.345,  0.032,  0.068), (0.345, -0.032, 0.068), (0.345, -0.038, 0.0)],
        [(0.430, -0.026, -0.088), (0.430, 0.026, -0.088), (0.430, 0.032, 0.005),
         (0.430,  0.024,  0.086), (0.430, -0.024, 0.086), (0.430, -0.032, 0.005)],
    ], face_role=lambda e, r: STL if e in {0, 3} else OBS, cap0_mat=DRK, cap1_mat=OBS)

    S.link("RFK2_Crossguard", merge_bms([guard_outer, guard_inner, ricasso]))

    # Floating faceted dark-matter core crystal right in the center of the open diamond window!
    crys = crystal_bm(cx, 0.0, cz, 0.036, 0.034, 0.044, mat=COR)
    S.link("RFK2_CoreCrystal", crys, bone="Root", flat_group="CoreCrystal")

    # Sleek counter-rotating hexagonal steel/bronze containment ring framing the crystal
    cring = ring_bm(cx, 0.0, cz, rad=0.052, thick=0.006, width=0.010, n=6, axis="Y", mat=STL)
    S.link("RFK2_CoreRing", cring, bone="Root", flat_group="CoreRing")


# 3. RAZOR NEEDLE-POINT PREDATOR TANTO/FANG BLADE (TRUE CONVERGING SHARP TIP!)
def build_blade():
    # Stations: (x, z_edge, z_bevel, z_mid, z_spine_lo, z_spine_hi, y_flat)
    # Notice: crisp choil notch at X=0.415 -> deep forged belly -> smooth sweeping curve
    # converging BOTH top false-edge and bottom razor cutting edge to a NEEDLE POINT at X=1.385!
    stations = [
        (0.395, -0.072, -0.052,  0.000,  0.062,  0.084, 0.030),  # root into ricasso
        (0.455, -0.104, -0.078, -0.004,  0.066,  0.088, 0.031),  # sharp choil tooth!
        (0.515, -0.082, -0.056, -0.004,  0.068,  0.090, 0.030),  # predator recurve dip
        (0.740, -0.092, -0.062, -0.002,  0.068,  0.088, 0.029),  # broad forged flat belly
        (0.960, -0.094, -0.062,  0.002,  0.062,  0.080, 0.027),  # widest swept tanto belly
        (1.130, -0.072, -0.044,  0.006,  0.046,  0.058, 0.022),  # start of gleaming steel clip-point
        (1.275, -0.034, -0.018,  0.008,  0.024,  0.030, 0.012),  # razor taper
        (1.365, -0.004,  0.002,  0.009,  0.011,  0.013, 0.003),  # needle convergence!
    ]
    rings = []
    for x, ze, zb, zm, zsl, zsh, yf in stations:
        rings.append([
            (x,  0.0,       ze),       # 0: razor lower cutting edge
            (x,  yf * 0.56, zb),       # 1: +Y lower cutting bevel shoulder
            (x,  yf,        zm),       # 2: +Y forged flat crest
            (x,  yf * 0.78, zsl),      # 3: +Y upper bevel shoulder
            (x,  yf * 0.25, zsh),      # 4: +Y spine edge
            (x, -yf * 0.25, zsh),      # 5: -Y spine edge
            (x, -yf * 0.78, zsl),      # 6: -Y upper bevel shoulder
            (x, -yf,        zm),       # 7: -Y forged flat crest
            (x, -yf * 0.56, zb),       # 8: -Y lower cutting bevel shoulder
        ])

    def blade_role(edge, row):
        # Gleaming wide steel cutting bevels (edges 0, 8) + steel upper false-edge clip & needle tip (row >= 4)!
        if edge in {0, 8} or row >= 5:
            return STL
        if edge in {3, 4, 5}:
            return STL if row >= 4 else DRK
        return OBS  # forged-obsidian hex-patterned primary flats!

    bm_blade = loft_rings_bm(rings, face_role=blade_role, cap0_mat=OBS, cap1_mat=STL)
    # Close the very front ring (row -1) into ONE true razor-sharp needle apex vertex at X = 1.390!
    # (cap1 already closed the 0.003x0.017 micro-tip cleanly, let's pull that cap to a razor pyramid tip!)
    bm_blade.faces.ensure_lookup_table()
    tip_face = bm_blade.faces[-1]
    res_ex = bmesh.ops.extrude_face_region(bm_blade, geom=[tip_face])
    ext_verts = [g for g in res_ex["geom"] if isinstance(g, bmesh.types.BMVert)]
    bmesh.ops.pointmerge(bm_blade, verts=ext_verts, merge_co=Vector((1.392, 0.0, 0.009)))
    bmesh.ops.delete(bm_blade, geom=[tip_face], context="FACES")
    for f in bm_blade.faces:
        if f.calc_center_median().x > 1.35:
            f.material_index = STL
    bmesh.ops.recalc_face_normals(bm_blade, faces=bm_blade.faces)
    S.link("RFK2_Blade", bm_blade)

    # Lower recessed glowing plasma fuller groove tapering to a sharp needle inside the blade flat!
    fuller_rings = []
    for x, z0, z1, yw in (
        (0.455, -0.022, -0.006, 0.0315),
        (0.740, -0.024, -0.007, 0.0305),
        (0.985, -0.020, -0.005, 0.0275),
        (1.135, -0.010, -0.001, 0.0205),
        (1.220, -0.003,  0.002, 0.0110),
    ):
        zm = 0.5 * (z0 + z1)
        fuller_rings.append([
            (x, -yw * 0.72, z0), (x,  yw * 0.72, z0),
            (x,  yw,        zm), (x,  yw * 0.72, z1),
            (x, -yw * 0.72, z1), (x, -yw,        zm),
        ])
    S.link("RFK2_BladeFullerPlasma", loft_rings_bm(fuller_rings, face_role=lambda e, r: HOT if e in {1, 4} else COR, cap0_mat=COR, cap1_mat=HOT))

    # Blazing dorsal plasma spine core running proudly beneath the 3 split V-flaring dorsal scales!
    spine_rings = []
    for x, z0, z1, yw in (
        (0.415, 0.058, 0.104, 0.0245),
        (0.640, 0.062, 0.106, 0.0235),
        (0.860, 0.056, 0.098, 0.0215),
        (1.030, 0.044, 0.076, 0.0165),
        (1.115, 0.036, 0.054, 0.0095),
    ):
        zm = 0.5 * (z0 + z1)
        spine_rings.append([
            (x, -yw * 0.75, z0), (x,  yw * 0.75, z0),
            (x,  yw,        zm), (x,  yw * 0.70, z1),
            (x, -yw * 0.70, z1), (x, -yw,        zm),
        ])
    S.link("RFK2_SpinePlasmaCore", loft_rings_bm(spine_rings, face_role=lambda e, r: HOT if e in {2, 3, 4} else COR, cap0_mat=COR, cap1_mat=HOT))


# 4. THREE PAIRED V-SPLITTING SAWTOOTH DORSAL SCALES (Scale1L/R, Scale2L/R, Scale3L/R!)
# Matches BOTH the sleek stepped sawtooth spine at rest AND the concept's V-split cutaway diagram!
def build_v_split_scales():
    scale_specs = [
        # (name, x_rear, x_front, z_lo_r, z_lo_f, z_hi_r, z_hi_f, half_w)
        ("Scale1", 0.435, 0.625, 0.088, 0.090, 0.162, 0.138, 0.029),
        ("Scale2", 0.642, 0.840, 0.086, 0.082, 0.156, 0.128, 0.028),
        ("Scale3", 0.858, 1.075, 0.076, 0.058, 0.138, 0.096, 0.025),
    ]
    for base_fg, xr, xf, zlr, zlf, zhr, zhf, w in scale_specs:
        xm = 0.5 * (xr + xf)
        zlm = 0.5 * (zlr + zlf)
        zhm = 0.5 * (zhr + zhf) + 0.008
        for side, tag_s in ((+1.0, "L"), (-1.0, "R")):
            fg = f"{base_fg}{tag_s}"
            # Sleek faceted half-scale armor fin (inner face hugs centerline Y=±0.002 so L+R close seamlessly!)
            s_rings = []
            for x, zl, zh, rw, rake in (
                (xr - 0.016, zlr, zhr,         w * 0.70, -0.52),
                (xr + 0.016, zlr, zhr + 0.008, w,        -0.48),
                (xm + 0.010, zlm, zhm,         w * 0.94, -0.36),
                (xf - 0.010, zlf, zhf,         w * 0.78, -0.24),
                (xf + 0.016, zlf, zlf + 0.014, w * 0.42, -0.14),
            ):
                zm = zl + 0.55 * (zh - zl)
                sec = [
                    (0.0015, zl),
                    (rw * 0.86, zl),
                    (rw, zm),
                    (rw * 0.48, zh),
                    (0.0015, zh),
                ]
                if side < 0:
                    sec = list(reversed(sec))
                s_rings.append([(x + rake * (z - zlm), side * y, z) for y, z in sec])
            S.link(
                f"RFK2_{fg}_Slt",
                loft_rings_bm(s_rings, face_role=lambda e, r: SLT, cap0_mat=SLT, cap1_mat=SLT),
                bone="Root",
                flat_group=fg + "_Slt",
            )

            # Matching antique-bronze lower rim trim hugging the bottom-outer edge of each half-scale!
            b_rings = []
            for x, zl, rw, rake in (
                (xr - 0.012, zlr - 0.005, w * 0.76, -0.52),
                (xr + 0.016, zlr - 0.005, w * 1.05, -0.48),
                (xf - 0.008, zlf - 0.005, w * 0.84, -0.24),
                (xf + 0.016, zlf - 0.004, w * 0.50, -0.14),
            ):
                zt = zl + 0.016
                sec = [
                    (rw * 0.55, zl),
                    (rw * 1.02, zl + 0.004),
                    (rw * 1.04, zt - 0.003),
                    (rw * 0.60, zt),
                ]
                if side < 0:
                    sec = list(reversed(sec))
                b_rings.append([(x + rake * (z - zlm), side * y, z) for y, z in sec])
            S.link(
                f"RFK2_{fg}_Brz",
                loft_rings_bm(b_rings, face_role=lambda e, r: BRZ, cap0_mat=BRZ, cap1_mat=BRZ),
                bone="Root",
                flat_group=fg + "_Brz",
            )


build_handle_and_pommel()
build_crossguard()
build_blade()
build_v_split_scales()

res = S.finalize(
    replaced_prefixes=["Blade", "Hilt", "Neon"],
    center_checks=["RFK2_Blade", "RFK2_Crossguard", "RFK2_CoreCrystal", "RFK2_PommelRing"],
    cam_specs={
        "center": (0.48, 0.0, 0.01),
        "span": 2.05,
        "hero_loc": (1.68, 1.85, 0.88),
        "hero_ortho": 2.10,
        "side_loc": (0.48, 2.65, 0.01),
        "side_ortho": 2.10,
        "fp_loc": (-0.65, 0.52, 0.42),
        "fp_tgt": (0.75, 0.0, 0.02),
        "close_loc": (1.32, 0.62, 0.22),
        "close_tgt": (1.12, 0.0, 0.01),
        "icon_loc": (1.08, 2.25, 0.42),
        "icon_ortho": 2.08,
        "portrait_loc": (1.45, 1.75, 0.72),
        "portrait_ortho": 1.95,
        "ray_x": (-0.32, 1.35),
        "ray_z": (-0.11, 0.15),
    },
)
result = res
print(json.dumps(res, indent=2))
