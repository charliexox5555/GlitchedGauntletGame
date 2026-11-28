"""Frostbite Hornet (Stinger) v01: Legendary sculpted cryo-armor remodel."""

from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

GUN = "Stinger"
VERSION = globals().get("VERSION", "v02")
exec((Path(bpy.data.filepath).parents[4] / "tools/blender/frostbite/frost_lib.py").read_text(encoding="utf-8"))

replace("Handguard", "Stock", "Barrel")

# ---------------------------------------------------------------- retained stock + gap sweep
for name in ("Receiver", "CharmLoop", "ChargingHandle", "Bolt", "FireSelector", "Trigger", "Grip",
             "Sights", "Neon"):
    dress(name)
dress("Mag", slots={"Dark": GRIP, "Body": ARMOR, "Panel": OBSIDIAN, "Accent": FROSTSTEEL})
dress("Pins", keep=lambda island: not 0.48 < limits(island, 0)[0] < 0.52)
dress("Stock", copy_name="FB_StockBlock", keep=lambda island: limits(island, 0)[0] > -0.72
      and limits(island, 1)[1] > 0.07 and limits(island, 1)[0] < -0.07)
dress("Stock", copy_name="FB_StockBars", keep=lambda island: -1.45 < limits(island, 0)[0] < -1.3)


def nudge(obj, pick, delta, island=None):
    matrix = obj.matrix_world
    inverse = matrix.inverted()
    allowed = None
    if island:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        allowed = set()
        for group in components(bm):
            points = [matrix @ v.co for v in group]
            lo = Vector([min(p[i] for p in points) for i in range(3)])
            hi = Vector([max(p[i] for p in points) for i in range(3)])
            if island(lo, hi):
                allowed.update(v.index for v in group)
        bm.free()
    moved = 0
    for vertex in obj.data.vertices:
        if allowed is not None and vertex.index not in allowed:
            continue
        point = matrix @ vertex.co
        if pick(point):
            vertex.co = inverse @ (point + Vector(delta))
            moved += 1
    obj.data.update()
    return moved


RECEIVER, SIGHTS = native("Receiver"), native("Sights")
BLOCK, BARS = bpy.data.objects["FB_StockBlock"], bpy.data.objects["FB_StockBars"]
gap_moves = {
    "grip_top": nudge(native("Grip"), lambda p: p.z > 0.14, (0, 0, 0.020),
                      lambda lo, hi: lo.z < -0.1),
    "guard_top": nudge(native("Grip"), lambda p: p.z > 0.152, (0, 0, 0.010),
                       lambda lo, hi: lo.x > 0.12 and lo.z > 0.0),
    "receiver_rear": nudge(RECEIVER, lambda p: p.x < -0.50, (-0.020, 0, 0),
                           lambda lo, hi: lo.x < -0.5 and hi.x > 0.7),
    "front_cap": nudge(RECEIVER, lambda p: p.x < 0.79, (-0.020, 0, 0),
                       lambda lo, hi: lo.x > 0.77 and hi.x > 0.9),
    "rail": nudge(RECEIVER, lambda p: p.z < 0.392, (0, 0, -0.020),
                  lambda lo, hi: lo.z > 0.38 and hi.z > 0.42),
    "rear_sight": nudge(SIGHTS, lambda p: p.z < 0.376, (0, 0, -0.015),
                        lambda lo, hi: lo.x < -0.39),
    "front_sight_base": nudge(SIGHTS, lambda p: p.z < 0.41, (0, 0, -0.020),
                              lambda lo, hi: lo.x < 0.8 and hi.x > 0.87),
    "front_sight_post_foot": nudge(SIGHTS, lambda p: p.z < 0.432, (0, 0, -0.020),
                                   lambda lo, hi: lo.z > 0.42 and hi.z < 0.47),
    "front_sight_post_top": nudge(SIGHTS, lambda p: p.z > 0.46, (0, 0, 0.008),
                                  lambda lo, hi: lo.z > 0.40 and hi.z < 0.47 and hi.x < 0.845),
    "front_sight_tip": nudge(SIGHTS, lambda p: p.z < 0.465, (0, 0, -0.008),
                             lambda lo, hi: lo.z > 0.46),
    "stock_bars": nudge(BARS, lambda p: p.x > -0.72, (0.020, 0, 0)),
    "block_front_top": nudge(BLOCK, lambda p: p.x > -0.52 and p.z > 0.36, (0, 0, -0.006)),
    "mag_floor": nudge(native("Mag"), lambda p: p.z < -0.52, (0, 0, -0.020),
                       lambda lo, hi: hi.z > -0.1 and lo.z < -0.5 and hi.y < 0.052),
}

# ---------------------------------------------------------------- fore-end box & stock block
hand = side("FB_ForeEnd", [(0.465, 0.112), (0.472, 0.105), (0.775, 0.105), (0.825, 0.150),
                           (0.825, 0.264), (0.465, 0.264)], -0.084, 0.084, ARMOR)
chamfer(hand, 0.004, angle=60)
FORE_CHASM = [(0.505, 0.145), (0.768, 0.145), (0.795, 0.175), (0.795, 0.236), (0.775, 0.252), (0.505, 0.246)]
BLOCK_CHASM = [(-0.690, 0.158), (-0.566, 0.158), (-0.550, 0.176), (-0.550, 0.336), (-0.566, 0.352), (-0.690, 0.338)]
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(hand, f"FB_ForeChasm_{label}", FORE_CHASM, 0.078 * sign, 0.15 * sign, role=OBSIDIAN)
    recess(BLOCK, f"FB_StockBlockChasm_{label}", BLOCK_CHASM, 0.068 * sign, 0.15 * sign, role=OBSIDIAN)

# ---------------------------------------------------------------- sculpted wing armor
# Left ChargingHandle x -.198..283, z .308..347 & FireSelector x -.12..12, z .19..27;
# Right Bolt x -.234..+inf, z .273..320 (swings y -.121 in Draw at x > -.13).
for sign, label in ((1, "Left"), (-1, "Right")):
    armor_plate(
        f"FB_RecArmorRear_{label}",
        [(-0.485, 0.235), (-0.255, 0.235), (-0.235, 0.358), (-0.475, 0.365)],
        0.076 * sign, 0.096 * sign, 0.102 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.006,
    )
    armor_plate(
        f"FB_UpperBrowPlate_{label}",
        ([(0.305, 0.336), (0.750, 0.336), (0.772, 0.366), (0.315, 0.366)] if sign == 1
         else [(0.115, 0.168), (0.445, 0.168), (0.455, 0.252), (0.115, 0.252)]),
        0.076 * sign, 0.096 * sign, 0.102 * sign, ARMOR, rim_role=FROSTSTEEL, inset=0.006,
    )
    armor_plate(
        f"FB_ForeJawFront_{label}",
        [(0.645, 0.135), (0.785, 0.145), (0.818, 0.185), (0.798, 0.256), (0.665, 0.254)],
        0.078 * sign, 0.102 * sign, 0.108 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.006,
    )
    armor_plate(
        f"FB_StockBlockWing_{label}",
        [(-0.695, 0.165), (-0.555, 0.165), (-0.545, 0.335), (-0.685, 0.335)],
        0.070 * sign, 0.088 * sign, 0.094 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.006,
    )

# ---------------------------------------------------------------- cryo-core bay & crystals (ahead of ChargingHandle Left; below Bolt Right)
for sign, label in ((1, "Left"), (-1, "Right")):
    bay_poly = (
        [(0.310, 0.270), (0.745, 0.270), (0.768, 0.318), (0.745, 0.365), (0.320, 0.365), (0.302, 0.318)]
        if sign == 1 else
        [(-0.475, 0.232), (-0.265, 0.232), (-0.248, 0.282), (-0.265, 0.338), (-0.475, 0.338), (-0.488, 0.282)]
    )
    bay = side(f"FB_CoreBay_{label}", bay_poly, 0.072 * sign, 0.096 * sign, ARMOR)
    chasm_poly = (
        [(0.325, 0.280), (0.728, 0.280), (0.746, 0.318), (0.728, 0.355), (0.335, 0.355), (0.318, 0.318)]
        if sign == 1 else
        [(-0.455, 0.242), (-0.282, 0.242), (-0.268, 0.284), (-0.282, 0.328), (-0.455, 0.328), (-0.468, 0.284)]
    )
    recess(bay, f"FB_CoreChasm_{label}", chasm_poly, 0.0825 * sign, 0.125 * sign, role=OBSIDIAN)
    if sign == 1:
        swept_rib("FB_CoreFissure_Left", [
            (0.340, 0.084, 0.318, 0.005, 0.006),
            (0.475, 0.085, 0.314, 0.006, 0.007),
            (0.605, 0.085, 0.322, 0.006, 0.007),
            (0.718, 0.084, 0.318, 0.005, 0.006),
        ], CRYO_GLOW, flat_group="FBCoreFissure")
        glacier_cluster("FB_CoreCrystals_Left", [
            {"points_xz": [(0.340, 0.305), (0.435, 0.288), (0.525, 0.304), (0.485, 0.348), (0.365, 0.342)],
             "base_y": 0.081, "shoulder_y": 0.102, "crest_y": 0.114, "ridge_bias": (-0.012, 0.004)},
            {"points_xz": [(0.565, 0.304), (0.645, 0.288), (0.725, 0.310), (0.680, 0.348), (0.580, 0.342)],
             "base_y": 0.081, "shoulder_y": 0.104, "crest_y": 0.116,
             "roles": (ICE_MID, ICE_MID, ICE_BRIGHT), "ridge_bias": (-0.010, 0.004)},
        ])
    else:
        swept_rib("FB_CoreFissure_Right", [
            (-0.445, -0.084, 0.284, 0.005, 0.006),
            (-0.365, -0.085, 0.280, 0.006, 0.007),
            (-0.292, -0.084, 0.286, 0.005, 0.006),
        ], CRYO_GLOW, flat_group="FBCoreFissure")
        glacier_cluster("FB_CoreCrystals_Right", [
            {"points_xz": [(-0.445, 0.268), (-0.370, 0.252), (-0.288, 0.274), (-0.325, 0.318), (-0.425, 0.312)],
             "base_y": -0.081, "shoulder_y": -0.102, "crest_y": -0.114, "ridge_bias": (-0.010, 0.004)},
        ])

    swept_rib(f"FB_ForeSeam_{label}", [
        (0.515, 0.082 * sign, 0.192, 0.005, 0.006),
        (0.645, 0.083 * sign, 0.200, 0.006, 0.007),
        (0.768, 0.082 * sign, 0.208, 0.005, 0.006),
    ], CRYO_GLOW, flat_group="FBForeSeam")
    glacier_cluster(f"FB_ForeCrystals_{label}", [
        {"points_xz": [(0.515, 0.172), (0.615, 0.155), (0.735, 0.182), (0.695, 0.236), (0.545, 0.228)],
         "base_y": 0.079 * sign, "shoulder_y": 0.102 * sign, "crest_y": 0.114 * sign, "ridge_bias": (-0.014, 0.005)},
    ])

glacier_shard(
    "FB_CoreHeart_Left",
    [(0.505, 0.320), (0.540, 0.302), (0.575, 0.318), (0.542, 0.338)],
    0.086, 0.112, 0.124,
    roles=(GLOW_WHITE, GLOW_WHITE, GLOW_WHITE),
    ridge_bias=(-0.004, 0.002),
    flat_group="FBCoreHeart",
)

# ---------------------------------------------------------------- swept glacial wing butt
butt = side("FB_StockButt", [
    (-1.375, 0.318), (-1.470, 0.340), (-1.500, 0.326), (-1.508, 0.285), (-1.492, 0.268),
    (-1.488, 0.130), (-1.510, 0.115), (-1.510, 0.075), (-1.494, 0.060), (-1.494, -0.075),
    (-1.474, -0.104), (-1.375, -0.104),
], -0.060, 0.060, ARMOR)
chamfer(butt, 0.006, angle=60)
STOCK_REC = [(-1.404, -0.056), (-1.472, -0.056), (-1.472, 0.226), (-1.460, 0.238), (-1.404, 0.238)]
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(butt, f"FB_ButtRecess_{label}", STOCK_REC, 0.052 * sign, 0.12 * sign, role=OBSIDIAN)
    armor_plate(
        f"FB_StockWingCheek_{label}",
        [(-1.388, 0.270), (-1.474, 0.270), (-1.488, 0.314), (-1.472, 0.328), (-1.388, 0.310)],
        0.048 * sign, 0.066 * sign, 0.072 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.005,
    )
for sign, label in ((1, "L"), (-1, "R")):
    glacier_cluster(f"FB_StockCrystals_{label}", [
        {"points_xz": [(-1.468, -0.032), (-1.412, 0.032), (-1.404, 0.205), (-1.464, 0.145)],
         "base_y": 0.050 * sign, "shoulder_y": 0.068 * sign, "crest_y": 0.078 * sign, "ridge_bias": (0.008, 0.005)},
    ])
swept_rib("FB_StockGlow", [
    (-1.454, 0.0, -0.025, 0.044, 0.008),
    (-1.442, 0.0,  0.095, 0.044, 0.008),
    (-1.430, 0.0,  0.215, 0.044, 0.008),
], CRYO_GLOW, flat_group="FBStockGlow")

# ---------------------------------------------------------------- cryo brake (0.876..1.140, z .294)
prism_along("FB_Brake", (0.876, 0, 0.294), (1, 0, 0), [
    (0.000, 0.050), (0.040, 0.050), (0.046, 0.054), (0.085, 0.054), (0.091, 0.046), (0.123, 0.046),
    (0.129, 0.054), (0.234, 0.054), (0.244, 0.044), (0.264, 0.044), (0.264, 0.020), (0.240, 0.020),
], FROSTSTEEL)
prism_along("FB_MuzzleGlow", (0.965, 0, 0.294), (1, 0, 0), [(0, 0.0505), (0.036, 0.0505)],
            CRYO_GLOW)["flat_group"] = "FBMuzzleGlow"
glacier_cluster("FB_MuzzleIce", [
    {"points_xz": [(0.895, 0.235), (0.985, 0.214), (1.095, 0.240), (1.015, 0.264)],
     "base_y": 0.018, "shoulder_y": -0.018, "crest_y": -0.028, "ridge_bias": (-0.010, -0.006)},
    {"points_xz": [(0.895, 0.235), (0.985, 0.214), (1.095, 0.240), (1.015, 0.264)],
     "base_y": -0.018, "shoulder_y": 0.018, "crest_y": 0.028, "ridge_bias": (-0.010, -0.006)},
])

# ---------------------------------------------------------------- mag glow & cowl (bone Mag)
for sign, label in ((1, "Left"), (-1, "Right")):
    armor_plate(
        f"FB_MagCowl_{label}",
        [(-0.025, -0.455), (0.035, -0.455), (0.045, -0.345), (-0.015, -0.345)],
        0.044 * sign, 0.056 * sign, 0.060 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.004, bone="Mag",
    )
    swept_rib(f"FB_MagGlow_{label}", [
        (-0.006, 0.053 * sign, -0.465, 0.005, 0.006),
        (0.006,  0.053 * sign, -0.370, 0.005, 0.007),
        (0.015,  0.053 * sign, -0.285, 0.005, 0.006),
    ], CRYO_GLOW, bone="Mag", flat_group="FBMagGlow")

# ---------------------------------------------------------------- animated flat_groups (Root, single-mat)
glacier_cluster("FB_GrowRear", [
    {"points_xz": [(-0.465, 0.265), (-0.355, 0.252), (-0.255, 0.268), (-0.285, 0.296), (-0.435, 0.292)],
     "base_y": 0.078, "shoulder_y": 0.098, "crest_y": 0.110,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.012, 0.004)},
    {"points_xz": [(-0.465, 0.265), (-0.355, 0.252), (-0.255, 0.268), (-0.285, 0.296), (-0.435, 0.292)],
     "base_y": -0.078, "shoulder_y": -0.098, "crest_y": -0.110,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.012, 0.004)},
], flat_group="FBGrowRear")

glacier_cluster("FB_GrowMid", [
    {"points_xz": [(0.345, 0.308), (0.475, 0.294), (0.615, 0.312), (0.565, 0.348), (0.395, 0.342)],
     "base_y": 0.080, "shoulder_y": 0.102, "crest_y": 0.114,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.014, 0.005)},
    {"points_xz": [(0.345, 0.308), (0.475, 0.294), (0.615, 0.312), (0.565, 0.348), (0.395, 0.342)],
     "base_y": -0.080, "shoulder_y": -0.102, "crest_y": -0.114,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.014, 0.005)},
], flat_group="FBGrowMid")

glacier_cluster("FB_GrowFront", [
    {"points_xz": [(0.525, 0.185), (0.635, 0.172), (0.755, 0.192), (0.715, 0.228), (0.565, 0.220)],
     "base_y": 0.082, "shoulder_y": 0.104, "crest_y": 0.116,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.014, 0.005)},
    {"points_xz": [(0.525, 0.185), (0.635, 0.172), (0.755, 0.192), (0.715, 0.228), (0.565, 0.220)],
     "base_y": -0.082, "shoulder_y": -0.104, "crest_y": -0.116,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.014, 0.005)},
], flat_group="FBGrowFront")

glacier_shard(
    "FB_Shard1", [(0.365, 0.285), (0.475, 0.270), (0.615, 0.288), (0.575, 0.318), (0.405, 0.312)],
    0.084, 0.106, 0.118, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.012, 0.004), flat_group="FBShard1",
)
glacier_shard(
    "FB_Shard2", [(0.535, 0.165), (0.635, 0.150), (0.745, 0.172), (0.705, 0.208), (0.575, 0.200)],
    0.084, 0.106, 0.118, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.012, 0.004), flat_group="FBShard2",
)
glacier_shard(
    "FB_Shard3", [(-0.445, 0.248), (-0.365, 0.235), (-0.285, 0.252), (-0.315, 0.282), (-0.425, 0.276)],
    -0.084, -0.106, -0.118, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.010, 0.004), flat_group="FBShard3",
)
glacier_shard(
    "FB_Shard4", [(0.535, 0.165), (0.635, 0.150), (0.745, 0.172), (0.705, 0.208), (0.575, 0.200)],
    -0.084, -0.106, -0.118, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.012, 0.004), flat_group="FBShard4",
)

result = finish_master(hand)
result["gap_moves"] = gap_moves
