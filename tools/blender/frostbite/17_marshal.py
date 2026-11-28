"""Frostbite Scout (Marshal) v01: Legendary sculpted cryo-armor remodel."""

from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

GUN = "Marshal"
VERSION = globals().get("VERSION", "v02")
exec((Path(bpy.data.filepath).parents[4] / "tools/blender/frostbite/frost_lib.py").read_text(encoding="utf-8"))

replace("ForeEnd", "Neon")

# ---------------------------------------------------------------- retained stock
for name in ("Receiver", "CharmLoop", "Bolt", "Hammer", "Lever", "Trigger", "Shell", "Scope"):
    dress(name)
dress("Barrel", keep=lambda island: not (limits(island, 0)[0] > 3.15 and limits(island, 0)[1] < 3.18))
dress("Pins", keep=lambda island: not (limits(island, 1)[0] > 0 and limits(island, 2)[0] > 0.1
                                       and 0.8 < limits(island, 0)[0] < 0.85))
dress("Stock", slots={"Dark": ARMOR, "Grip": OBSIDIAN, "Body": ARMOR, "Panel": FROSTSTEEL, "Accent": FROSTSTEEL},
      keep=lambda island: limits(island, 0)[1] > 0)
gap_moves = {}


def fore_section(x, bottom, keel, shoulder, top, width, base, crown):
    return [(x, y, z) for y, z in (
        (-crown, top), (crown, top), (width, shoulder), (width, keel),
        (base, bottom), (-base, bottom), (-width, keel), (-width, shoulder),
    )]


def sleeve(name, origin, profile, role, *, bone="Root"):
    ox, oy, oz = origin
    sections = [[(ox + t, oy + u, oz + v) for u, v in polygon(0, 0, r, 8)] for t, r in profile]
    return loft(name, sections, role, bone=bone, loop=True)


# ---------------------------------------------------------------- fore-end cryo shroud (x 0.866..1.926)
fore = loft("FB_ForeEnd", [
    fore_section(0.866, -0.013, 0.017, 0.184, 0.207, 0.068, 0.038, 0.045),
    fore_section(1.880, -0.013, 0.017, 0.184, 0.207, 0.068, 0.038, 0.045),
    fore_section(1.926, 0.060, 0.084, 0.176, 0.199, 0.052, 0.030, 0.035),
], ARMOR, bevel=0.003)
FORE_CHASM = [(0.960, 0.064), (0.974, 0.064), (0.974, 0.048), (0.988, 0.048), (0.988, 0.030),
              (1.812, 0.030), (1.840, 0.058), (1.840, 0.140), (1.812, 0.168), (0.980, 0.168), (0.960, 0.148)]
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(fore, f"FB_ForeChasm_{label}", FORE_CHASM, 0.060 * sign, 0.15 * sign, role=OBSIDIAN)

# ---------------------------------------------------------------- sculpted wing armor
# Left stays tight behind receiver's ADS shadow (eye x -.687, z .3333 -> max y ~.095..105);
# Right stays ABOVE Shell reload path (z >= 0.078, avoiding loading gate x .31..46 z .003..068).
for sign, label in ((1, "Left"), (-1, "Right")):
    armor_plate(
        f"FB_RecArmorRear_{label}",
        ([(0.155, 0.012), (0.315, 0.012), (0.365, 0.065), (0.295, 0.182), (0.165, 0.178)] if sign == 1
         else [(0.155, 0.085), (0.355, 0.085), (0.375, 0.182), (0.165, 0.178)]),
        0.058 * sign, 0.076 * sign, 0.082 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.006,
    )
    armor_plate(
        f"FB_BridgeWing_{label}",
        [(0.905, 0.035), (1.085, 0.045), (1.235, 0.135), (1.295, 0.178),
         (1.135, 0.185), (0.925, 0.175), (0.895, 0.105)],
        0.062 * sign, 0.084 * sign, 0.090 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.006,
    )
    armor_plate(
        f"FB_ForeJawFront_{label}",
        [(1.645, 0.040), (1.795, 0.048), (1.895, 0.085), (1.845, 0.165), (1.665, 0.172)],
        0.062 * sign, 0.086 * sign, 0.092 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.006,
    )
    armor_plate(
        f"FB_ForeChinPlate_{label}",
        [(0.985, 0.022), (1.295, 0.014), (1.665, 0.018), (1.745, 0.048), (1.585, 0.066), (0.985, 0.062)],
        0.058 * sign, 0.080 * sign, 0.086 * sign, ARMOR, rim_role=FROSTSTEEL, inset=0.006,
    )

# ---------------------------------------------------------------- cryo-core bay & crystals
for sign, label in ((1, "Left"), (-1, "Right")):
    bay_poly = (
        [(0.385, 0.024), (0.765, 0.024), (0.785, 0.085), (0.765, 0.178), (0.395, 0.178), (0.375, 0.102)]
        if sign == 1 else
        [(0.385, 0.082), (0.765, 0.082), (0.782, 0.130), (0.765, 0.178), (0.395, 0.178), (0.375, 0.130)]
    )
    bay = side(f"FB_CoreBay_{label}", bay_poly, 0.058 * sign, 0.078 * sign, ARMOR)
    chasm_poly = (
        [(0.402, 0.036), (0.748, 0.036), (0.764, 0.088), (0.746, 0.166), (0.412, 0.166), (0.392, 0.102)]
        if sign == 1 else
        [(0.402, 0.090), (0.748, 0.090), (0.762, 0.130), (0.746, 0.168), (0.412, 0.168), (0.392, 0.130)]
    )
    recess(bay, f"FB_CoreChasm_{label}", chasm_poly, 0.068 * sign, 0.12 * sign, role=OBSIDIAN)
    fz = (0.098, 0.094, 0.104, 0.100) if sign == 1 else (0.128, 0.125, 0.132, 0.128)
    swept_rib(f"FB_CoreFissure_{label}", [
        (0.415, 0.072 * sign, fz[0], 0.005, 0.006),
        (0.525, 0.073 * sign, fz[1], 0.006, 0.007),
        (0.635, 0.073 * sign, fz[2], 0.006, 0.007),
        (0.732, 0.072 * sign, fz[3], 0.005, 0.006),
    ], CRYO_GLOW, flat_group="FBCoreFissure")
    swept_rib(f"FB_ForeSeam_{label}", [
        (1.015, 0.069 * sign, 0.088, 0.005, 0.006),
        (1.365, 0.070 * sign, 0.102, 0.006, 0.007),
        (1.705, 0.069 * sign, 0.114, 0.005, 0.006),
    ], CRYO_GLOW, flat_group="FBForeSeam")
    dz = 0.0 if sign == 1 else 0.032
    glacier_cluster(f"FB_CoreCrystals_{label}", [
        {"points_xz": [(0.415, 0.075 + dz), (0.495, 0.062 + dz), (0.575, 0.076 + dz),
                       (0.540, 0.122 + dz), (0.435, 0.116 + dz)],
         "base_y": 0.062 * sign, "shoulder_y": 0.084 * sign, "crest_y": 0.095 * sign, "ridge_bias": (-0.012, 0.004)},
        {"points_xz": [(0.605, 0.078 + dz), (0.680, 0.064 + dz), (0.748, 0.084 + dz),
                       (0.705, 0.126 + dz), (0.620, 0.120 + dz)],
         "base_y": 0.062 * sign, "shoulder_y": 0.086 * sign, "crest_y": 0.097 * sign,
         "roles": (ICE_MID, ICE_MID, ICE_BRIGHT), "ridge_bias": (-0.010, 0.004)},
    ])
    glacier_cluster(f"FB_ForeCrystals_{label}", [
        {"points_xz": [(1.025, 0.075), (1.175, 0.058), (1.335, 0.088), (1.285, 0.148), (1.075, 0.138)],
         "base_y": 0.061 * sign, "shoulder_y": 0.086 * sign, "crest_y": 0.100 * sign, "ridge_bias": (-0.018, 0.006)},
        {"points_xz": [(1.405, 0.078), (1.565, 0.062), (1.725, 0.092), (1.665, 0.152), (1.455, 0.140)],
         "base_y": 0.061 * sign, "shoulder_y": 0.088 * sign, "crest_y": 0.102 * sign,
         "roles": (ICE_MID, ICE_MID, ICE_BRIGHT), "ridge_bias": (-0.016, 0.006)},
    ])

glacier_shard(
    "FB_CoreHeart_Left",
    [(0.555, 0.102), (0.588, 0.084), (0.620, 0.100), (0.590, 0.118)],
    0.070, 0.092, 0.102,
    roles=(GLOW_WHITE, GLOW_WHITE, GLOW_WHITE),
    ridge_bias=(-0.004, 0.002),
    flat_group="FBCoreHeart",
)

glacier_cluster("FB_ForeKeel", [
    {"points_xz": [(1.145, -0.002), (1.365, -0.028), (1.585, 0.015), (1.495, 0.036), (1.225, 0.022)],
     "base_y": 0.024, "shoulder_y": -0.022, "crest_y": -0.034, "ridge_bias": (-0.016, -0.008)},
    {"points_xz": [(1.145, -0.002), (1.365, -0.028), (1.585, 0.015), (1.495, 0.036), (1.225, 0.022)],
     "base_y": -0.024, "shoulder_y": 0.022, "crest_y": 0.034, "ridge_bias": (-0.016, -0.008)},
])

# ---------------------------------------------------------------- muzzle sleeve (hollow bore over barrel x 3.112..3.212, z .205)
SLEEVE_X = 3.112
sleeve("FB_MuzzleSleeve", (SLEEVE_X, 0, 0.205), [
    (0.000, 0.030), (0.000, 0.046), (0.008, 0.056), (0.028, 0.056), (0.028, 0.049), (0.054, 0.049),
    (0.054, 0.058), (0.088, 0.058), (0.094, 0.052), (0.100, 0.052), (0.100, 0.030),
], FROSTSTEEL)
sleeve("FB_MuzzleGlow", (SLEEVE_X + 0.022, 0, 0.205), [(0.000, 0.036), (0.000, 0.0535), (0.035, 0.0535),
                                                       (0.035, 0.036)], CRYO_GLOW)["flat_group"] = "FBMuzzleGlow"
glacier_cluster("FB_MuzzleIce", [
    {"points_xz": [(3.115, 0.142), (3.158, 0.125), (3.205, 0.146), (3.172, 0.166)],
     "base_y": 0.018, "shoulder_y": -0.018, "crest_y": -0.028, "ridge_bias": (-0.008, -0.005)},
    {"points_xz": [(3.115, 0.142), (3.158, 0.125), (3.205, 0.146), (3.172, 0.166)],
     "base_y": -0.018, "shoulder_y": 0.018, "crest_y": 0.028, "ridge_bias": (-0.008, -0.005)},
])

# ---------------------------------------------------------------- swept glacial wing butt & stock art
butt = side("FB_StockButt", [
    (-1.130, 0.086), (-1.252, 0.116), (-1.272, 0.104), (-1.276, 0.066), (-1.260, 0.052),
    (-1.260, -0.040), (-1.278, -0.058), (-1.278, -0.292), (-1.258, -0.318), (-1.130, -0.318),
], -0.076, 0.076, ARMOR, bevel=0.006)
STOCK_REC = [(-1.150, -0.260), (-1.242, -0.260), (-1.242, 0.010), (-1.232, 0.020), (-1.150, 0.010)]
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(butt, f"FB_ButtRecess_{label}", STOCK_REC, 0.068 * sign, 0.12 * sign, role=OBSIDIAN)
    armor_plate(
        f"FB_StockWingCheek_{label}",
        [(-1.148, 0.038), (-1.238, 0.038), (-1.246, 0.089), (-1.236, 0.099), (-1.148, 0.078)],
        0.064 * sign, 0.082 * sign, 0.088 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.005,
    )
    armor_plate(
        f"FB_StockBodyWing_{label}",
        [(-0.845, -0.075), (-0.615, -0.075), (-0.575, 0.045), (-0.805, 0.045)],
        0.060 * sign, 0.074 * sign, 0.080 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.006,
    )
for sign, label in ((1, "L"), (-1, "R")):
    glacier_cluster(f"FB_StockCrystals_{label}", [
        {"points_xz": [(-1.235, -0.220), (-1.162, -0.155), (-1.155, -0.010), (-1.232, -0.065)],
         "base_y": 0.066 * sign, "shoulder_y": 0.084 * sign, "crest_y": 0.096 * sign, "ridge_bias": (0.008, 0.005)},
    ])
swept_rib("FB_StockGlow", [
    (-1.215, 0.0, -0.215, 0.056, 0.009),
    (-1.202, 0.0, -0.090, 0.056, 0.009),
    (-1.190, 0.0,  0.035, 0.056, 0.009),
], CRYO_GLOW, flat_group="FBStockGlow")

# Marshal is tube-fed (no Mag bone): place under-barrel tube fissure in FBMagGlow flat_group
swept_rib("FB_TubeGlow", [
    (1.225, 0.0, 0.010, 0.046, 0.008),
    (1.525, 0.0, 0.010, 0.046, 0.008),
    (1.825, 0.0, 0.010, 0.046, 0.008),
], CRYO_GLOW, flat_group="FBMagGlow")

# ---------------------------------------------------------------- animated flat_groups (Root, single-mat)
glacier_cluster("FB_GrowRear", [
    {"points_xz": [(0.425, 0.132), (0.565, 0.120), (0.715, 0.136), (0.665, 0.168), (0.475, 0.162)],
     "base_y": 0.066, "shoulder_y": 0.082, "crest_y": 0.093,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.014, 0.004)},
    {"points_xz": [(0.425, 0.132), (0.565, 0.120), (0.715, 0.136), (0.665, 0.168), (0.475, 0.162)],
     "base_y": -0.066, "shoulder_y": -0.082, "crest_y": -0.093,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.014, 0.004)},
], flat_group="FBGrowRear")

glacier_cluster("FB_GrowMid", [
    {"points_xz": [(1.025, 0.138), (1.195, 0.124), (1.375, 0.140), (1.315, 0.174), (1.085, 0.168)],
     "base_y": 0.064, "shoulder_y": 0.086, "crest_y": 0.098,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.016, 0.005)},
    {"points_xz": [(1.025, 0.138), (1.195, 0.124), (1.375, 0.140), (1.315, 0.174), (1.085, 0.168)],
     "base_y": -0.064, "shoulder_y": -0.086, "crest_y": -0.098,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.016, 0.005)},
], flat_group="FBGrowMid")

glacier_cluster("FB_GrowFront", [
    {"points_xz": [(1.465, 0.142), (1.625, 0.128), (1.795, 0.144), (1.735, 0.178), (1.525, 0.172)],
     "base_y": 0.064, "shoulder_y": 0.088, "crest_y": 0.100,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.016, 0.005)},
    {"points_xz": [(1.465, 0.142), (1.625, 0.128), (1.795, 0.144), (1.735, 0.178), (1.525, 0.172)],
     "base_y": -0.064, "shoulder_y": -0.088, "crest_y": -0.100,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.016, 0.005)},
], flat_group="FBGrowFront")

glacier_shard(
    "FB_Shard1", [(0.455, 0.078), (0.585, 0.064), (0.725, 0.082), (0.675, 0.114), (0.495, 0.108)],
    0.074, 0.092, 0.102, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.012, 0.004), flat_group="FBShard1",
)
glacier_shard(
    "FB_Shard2", [(1.285, 0.086), (1.465, 0.070), (1.665, 0.094), (1.595, 0.132), (1.345, 0.124)],
    0.070, 0.092, 0.104, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.016, 0.005), flat_group="FBShard2",
)
glacier_shard(
    "FB_Shard3", [(0.455, 0.102), (0.585, 0.088), (0.725, 0.106), (0.675, 0.136), (0.495, 0.130)],
    -0.072, -0.092, -0.102, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.012, 0.004), flat_group="FBShard3",
)
glacier_shard(
    "FB_Shard4", [(1.285, 0.086), (1.465, 0.070), (1.665, 0.094), (1.595, 0.132), (1.345, 0.124)],
    -0.070, -0.092, -0.104, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.016, 0.005), flat_group="FBShard4",
)

result = finish_master(fore)
result["gap_moves"] = gap_moves
