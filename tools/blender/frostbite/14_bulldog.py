"""Frostbite Lancer (Bulldog) v01: Legendary sculpted cryo-armor remodel."""

from pathlib import Path

import bpy

GUN = "Bulldog"
VERSION = globals().get("VERSION", "v03")
exec((Path(bpy.data.filepath).parents[4] / "tools/blender/frostbite/frost_lib.py").read_text(encoding="utf-8"))

replace("Handguard", "Barrel")

for name in ("Receiver", "Neon", "CharmLoop", "ChargingHandle", "Bolt",
             "FireSelector", "Trigger", "Grip", "Sights"):
    dress(name)
dress("Mag", slots={"Dark": GRIP, "Body": ARMOR, "Panel": OBSIDIAN, "Accent": FROSTSTEEL})
dress("Pins", keep=lambda island: not ((limits(island, 0)[0] < -0.9 and limits(island, 2)[1] < 0.2)
                                       or 0.68 < limits(island, 0)[0] < 0.72))
body = dress("Stock", keep=lambda island: limits(island, 0)[0] > -1.23)

_flat = {}
exec((ROOT / "tools/blender/export_roblox_flat.py").read_text(encoding="utf-8"), _flat)
_flat["resolve_coplanar"]([native("Bolt"), native("Receiver")])
tube = dress("Barrel", copy_name="FB_BarrelTube", keep=lambda island: limits(island, 0)[1] < 1.26)


def nudge(obj, pick, delta):
    matrix = obj.matrix_world
    inverse = matrix.inverted()
    moved = 0
    for vertex in obj.data.vertices:
        point = matrix @ vertex.co
        if pick(point):
            vertex.co = inverse @ (point + Vector(delta))
            moved += 1
    obj.data.update()
    return moved


from mathutils import Vector
post_moves = nudge(native("Grip"), lambda p: p.x > 0.47 and p.z > 0.155 and abs(p.y) < 0.031, (0, 0, 0.037))
sight_moves = nudge(native("Sights"), lambda p: 0.82 < p.x < 0.93 and p.z < 0.506, (0, 0, -0.047))
tube_moves = nudge(tube, lambda p: p.x < 1.031, (-0.020, 0, 0))

# ---------------------------------------------------------------- bullpup stock & receiver cryo reactor
# Recess left (y .083, x -1.05..-.524, z .28..41) & right; plus lower stock panels
CORE_RECESS = [(-1.034, 0.296), (-0.548, 0.296), (-0.540, 0.306), (-0.568, 0.390), (-0.584, 0.398), (-1.034, 0.398)]
LOWER_RECESS = [(-1.140, -0.035), (-0.840, -0.068), (-0.830, 0.218), (-1.140, 0.236)]
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(body, f"FB_StockLowerField_{label}", LOWER_RECESS, 0.082 * sign, 0.15 * sign, role=OBSIDIAN)
    recess(body, f"FB_StockCorePocket_{label}", CORE_RECESS, 0.079 * sign, 0.15 * sign, role=OBSIDIAN)
    armor_plate(
        f"FB_BullpupRearWing_{label}",
        [(-1.175, 0.250), (-0.985, 0.250), (-0.935, 0.405), (-1.155, 0.415)],
        0.080 * sign, 0.104 * sign, 0.112 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.008,
    )
    armor_plate(
        f"FB_BullpupMidWing_{label}",
        [(-0.855, 0.185), (-0.535, 0.185), (-0.495, 0.275), (-0.815, 0.275)],
        0.080 * sign, 0.104 * sign, 0.112 * sign, ARMOR, rim_role=FROSTSTEEL, inset=0.008,
    )
    armor_plate(
        f"FB_ReceiverBrow_{label}",
        ([(-0.345, 0.310), (-0.015, 0.310), (0.085, 0.398), (-0.315, 0.398)] if sign == 1
         else [(-0.345, 0.362), (0.015, 0.362), (0.085, 0.402), (-0.315, 0.402)]),
        0.078 * sign, 0.098 * sign, 0.104 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.007,
    )
    swept_rib(f"FB_CoreFissure_{label}", [
        (-1.005, 0.087 * sign, 0.342, 0.005, 0.007),
        (-0.845, 0.088 * sign, 0.336, 0.006, 0.008),
        (-0.695, 0.088 * sign, 0.348, 0.006, 0.008),
        (-0.568, 0.087 * sign, 0.344, 0.005, 0.006),
    ], CRYO_GLOW, flat_group="FBCoreFissure")
    swept_rib(f"FB_UpperSeam_{label}", [
        (-1.005, 0.087 * sign, 0.395, 0.005, 0.005),
        (-0.795, 0.087 * sign, 0.400, 0.005, 0.005),
        (-0.585, 0.087 * sign, 0.394, 0.005, 0.005),
    ], CRYO_GLOW, flat_group="FBUpperSeam")
    glacier_cluster(f"FB_CoreCrystals_{label}", [
        {"points_xz": [(-0.925, 0.315), (-0.855, 0.300), (-0.795, 0.320), (-0.835, 0.374), (-0.915, 0.368)],
         "base_y": 0.079 * sign, "shoulder_y": 0.104 * sign, "crest_y": 0.118 * sign, "ridge_bias": (-0.012, 0.005)},
        {"points_xz": ([(-0.725, 0.315), (-0.615, 0.302), (-0.548, 0.326), (-0.595, 0.376), (-0.705, 0.368)]
                       if sign == 1 else
                       [(-0.725, 0.320), (-0.635, 0.308), (-0.592, 0.328), (-0.625, 0.376), (-0.705, 0.368)]),
         "base_y": 0.079 * sign, "shoulder_y": 0.105 * sign, "crest_y": 0.119 * sign,
         "roles": (ICE_MID, ICE_MID, ICE_BRIGHT), "ridge_bias": (-0.012, 0.004)},
    ])

glacier_shard(
    "FB_CoreHeart_Left",
    [(-0.808, 0.342), (-0.772, 0.324), (-0.736, 0.340), (-0.768, 0.360)],
    0.086, 0.112, 0.124,
    roles=(GLOW_WHITE, GLOW_WHITE, GLOW_WHITE),
    ridge_bias=(-0.005, 0.002),
    flat_group="FBCoreHeart",
)

# ---------------------------------------------------------------- handguard cryo shroud
hand = folded("FB_Handguard", (
    (0.575, 0.156, 0.306, 0.086, 0.286, 0.186, 0.066),
    (1.020, 0.156, 0.306, 0.086, 0.286, 0.186, 0.066),
    (1.074, 0.206, 0.302, 0.080, 0.282, 0.228, 0.060),
), ARMOR, bevel=0.004)
HFIELD = [(0.650, 0.200), (0.992, 0.200), (1.012, 0.222), (1.012, 0.260), (0.992, 0.278), (0.650, 0.272)]
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(hand, f"FB_ForeChasm_{label}", HFIELD, 0.080 * sign, 0.15 * sign, role=OBSIDIAN)
    swept_rib(f"FB_ForeSeam_{label}", [
        (0.655, 0.084 * sign, 0.232, 0.005, 0.006),
        (0.835, 0.085 * sign, 0.240, 0.006, 0.007),
        (0.995, 0.084 * sign, 0.248, 0.005, 0.006),
    ], CRYO_GLOW, flat_group="FBForeSeam")
    armor_plate(
        f"FB_ForeJawFront_{label}",
        [(0.865, 0.195), (1.015, 0.205), (1.070, 0.238), (1.035, 0.284), (0.875, 0.282)],
        0.078 * sign, 0.104 * sign, 0.112 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.007,
    )
    glacier_cluster(f"FB_ForeCrystals_{label}", [
        {"points_xz": [(0.645, 0.214), (0.765, 0.202), (0.885, 0.224), (0.845, 0.268), (0.675, 0.258)],
         "base_y": 0.082 * sign, "shoulder_y": 0.104 * sign, "crest_y": 0.116 * sign, "ridge_bias": (-0.016, 0.005)},
    ])

# ---------------------------------------------------------------- bullpup cryo butt
butt = side("FB_StockButt", [
    (-1.178, 0.452), (-1.400, 0.486), (-1.432, 0.468), (-1.440, 0.420), (-1.420, 0.404),
    (-1.414, 0.214), (-1.440, 0.196), (-1.440, 0.150), (-1.420, 0.132), (-1.420, -0.088),
    (-1.392, -0.140), (-1.116, -0.140), (-1.178, -0.068),
], -0.088, 0.088, ARMOR, bevel=0.006)
STOCK_REC = [(-1.235, -0.045), (-1.385, -0.045), (-1.400, 0.380), (-1.235, 0.380)]
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(butt, f"FB_ButtRecess_{label}", STOCK_REC, 0.078 * sign, 0.12 * sign, role=OBSIDIAN)
    armor_plate(
        f"FB_StockWingCheek_{label}",
        [(-1.215, 0.404), (-1.396, 0.404), (-1.412, 0.462), (-1.392, 0.478), (-1.215, 0.448)],
        0.076 * sign, 0.094 * sign, 0.100 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.007,
    )
    glacier_cluster(f"FB_StockCrystals_{label}", [
        {"points_xz": [(-1.385, 0.015), (-1.275, 0.095), (-1.255, 0.325), (-1.375, 0.245)],
         "base_y": 0.076 * sign, "shoulder_y": 0.096 * sign, "crest_y": 0.108 * sign, "ridge_bias": (0.012, 0.006)},
    ])
swept_rib("FB_StockGlow", [
    (-1.345, 0.0, 0.010, 0.068, 0.010),
    (-1.325, 0.0, 0.175, 0.068, 0.010),
    (-1.305, 0.0, 0.340, 0.068, 0.010),
], CRYO_GLOW, flat_group="FBStockGlow")

# ---------------------------------------------------------------- cryo muzzle brake (x 1.234..1.440, z .3614)
brake = prism_along("FB_Brake", (1.234, 0, 0.3614), (1, 0, 0), [
    (0.000, 0.040), (0.010, 0.050), (0.046, 0.050), (0.046, 0.043), (0.078, 0.043), (0.078, 0.054),
    (0.176, 0.054), (0.192, 0.046), (0.206, 0.040), (0.206, 0.020), (0.178, 0.020),
], FROSTSTEEL)
for k, x in enumerate((1.326, 1.366)):
    recess(brake, f"FB_BrakePort_{k + 1}", [(x, 0.348), (x + 0.024, 0.348), (x + 0.024, 0.375), (x, 0.375)],
           -0.2, 0.2, role=OBSIDIAN)
prism_along("FB_MuzzleGlow", (1.278, 0, 0.3614), (1, 0, 0), [(0, 0.0475), (0.036, 0.0475)],
            CRYO_GLOW)["flat_group"] = "FBMuzzleGlow"
glacier_cluster("FB_MuzzleIce", [
    {"points_xz": [(1.245, 0.312), (1.335, 0.290), (1.415, 0.316), (1.355, 0.338)],
     "base_y": 0.018, "shoulder_y": -0.018, "crest_y": -0.028, "ridge_bias": (-0.010, -0.006)},
    {"points_xz": [(1.245, 0.312), (1.335, 0.290), (1.415, 0.316), (1.355, 0.338)],
     "base_y": -0.018, "shoulder_y": 0.018, "crest_y": 0.028, "ridge_bias": (-0.010, -0.006)},
])

# ---------------------------------------------------------------- magazine frost cowl & glow (bone Mag)
for sign, label in ((1, "Left"), (-1, "Right")):
    armor_plate(
        f"FB_MagCowl_{label}",
        [(-0.735, -0.185), (-0.545, -0.175), (-0.515, -0.225), (-0.705, -0.230)],
        0.050 * sign, 0.062 * sign, 0.066 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.005, bone="Mag",
    )
    swept_rib(f"FB_MagGlow_{label}", [
        (-0.690, 0.054 * sign, -0.175, 0.006, 0.007),
        (-0.648, 0.055 * sign, -0.095, 0.006, 0.008),
        (-0.606, 0.054 * sign, -0.015, 0.006, 0.007),
    ], CRYO_GLOW, bone="Mag", flat_group="FBMagGlow")

# ---------------------------------------------------------------- animated flat_groups (Root, single-mat)
glacier_cluster("FB_GrowRear", [
    {"points_xz": [(-1.025, 0.387), (-0.865, 0.373), (-0.695, 0.389), (-0.755, 0.419), (-0.975, 0.415)],
     "base_y": 0.0835, "shoulder_y": 0.106, "crest_y": 0.118,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.018, 0.006)},
    {"points_xz": [(-1.025, 0.387), (-0.865, 0.373), (-0.695, 0.389), (-0.755, 0.419), (-0.975, 0.415)],
     "base_y": -0.0835, "shoulder_y": -0.106, "crest_y": -0.118,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.018, 0.006)},
], flat_group="FBGrowRear")

glacier_cluster("FB_GrowMid", [
    {"points_xz": [(-0.445, 0.398), (-0.265, 0.384), (-0.085, 0.402), (-0.145, 0.432), (-0.385, 0.428)],
     "base_y": 0.080, "shoulder_y": 0.102, "crest_y": 0.114,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.018, 0.006)},
    {"points_xz": [(-0.445, 0.398), (-0.265, 0.384), (-0.085, 0.402), (-0.145, 0.432), (-0.385, 0.428)],
     "base_y": -0.080, "shoulder_y": -0.102, "crest_y": -0.114,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.018, 0.006)},
], flat_group="FBGrowMid")

glacier_cluster("FB_GrowFront", [
    {"points_xz": [(0.655, 0.256), (0.815, 0.244), (0.985, 0.262), (0.925, 0.290), (0.705, 0.284)],
     "base_y": 0.084, "shoulder_y": 0.106, "crest_y": 0.118,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.016, 0.005)},
    {"points_xz": [(0.655, 0.256), (0.815, 0.244), (0.985, 0.262), (0.925, 0.290), (0.705, 0.284)],
     "base_y": -0.084, "shoulder_y": -0.106, "crest_y": -0.118,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.016, 0.005)},
], flat_group="FBGrowFront")

glacier_shard(
    "FB_Shard1", [(-0.975, 0.320), (-0.845, 0.305), (-0.675, 0.322), (-0.725, 0.354), (-0.935, 0.348)],
    0.092, 0.114, 0.126, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.014, 0.004), flat_group="FBShard1",
)
glacier_shard(
    "FB_Shard2", [(0.675, 0.215), (0.825, 0.202), (0.985, 0.225), (0.925, 0.256), (0.725, 0.248)],
    0.090, 0.112, 0.124, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.014, 0.004), flat_group="FBShard2",
)
glacier_shard(
    "FB_Shard3", [(-0.975, 0.320), (-0.845, 0.305), (-0.675, 0.322), (-0.725, 0.354), (-0.935, 0.348)],
    -0.092, -0.114, -0.126, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.014, 0.004), flat_group="FBShard3",
)
glacier_shard(
    "FB_Shard4", [(0.675, 0.215), (0.825, 0.202), (0.985, 0.225), (0.925, 0.256), (0.725, 0.248)],
    -0.090, -0.112, -0.124, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.014, 0.004), flat_group="FBShard4",
)

result = finish_master(hand)
result["stock_join_moves"] = {"guard_post": post_moves, "front_sight_foot": sight_moves, "barrel_tube": tube_moves}
