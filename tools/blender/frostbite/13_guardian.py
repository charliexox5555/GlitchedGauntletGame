"""Frostbite Marksman (Guardian) v01: Legendary sculpted cryo-armor remodel."""

from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

GUN = "Guardian"
VERSION = globals().get("VERSION", "v02")
exec((Path(bpy.data.filepath).parents[4] / "tools/blender/frostbite/frost_lib.py").read_text(encoding="utf-8"))

replace("Handguard", "Stock", "Barrel", "Neon")

for name in ("Receiver", "CharmLoop", "ChargingHandle", "Bolt", "BoltCatch",
             "FireSelector", "Trigger", "Grip", "Sights"):
    dress(name)
dress("Mag", slots={"Dark": GRIP, "Body": ARMOR, "Panel": OBSIDIAN, "Accent": FROSTSTEEL})
dress("Pins", keep=lambda island: not (limits(island, 1)[1] < 0 and limits(island, 2)[1] < 0.21
                                       and 0.1 < limits(island, 0)[0] < 0.4))
dress("Stock", copy_name="FB_StockFrame", keep=lambda island: limits(island, 0)[0] > -1.2)
dress("Barrel", copy_name="FB_BarrelTube", keep=lambda island: limits(island, 0)[1] < 2.795)


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


SIGHTS = native("Sights")
FRAME = bpy.data.objects["FB_StockFrame"]
gap_moves = {
    "front_sight_base": nudge(SIGHTS, lambda p: p.z < 0.435, (0, 0, -0.020),
                              lambda lo, hi: lo.x > 2.2 and hi.x < 2.31 and lo.z > 0.43 and hi.z < 0.465),
    "front_sight_post": nudge(SIGHTS, lambda p: p.z < 0.459, (0, 0, -0.018),
                              lambda lo, hi: hi.y < 0.006 and lo.z > 0.45 and hi.z < 0.5),
    "rear_sight_base": nudge(SIGHTS, lambda p: p.z < 0.411, (0, 0, -0.014),
                             lambda lo, hi: hi.x < 0.2 and lo.z < 0.42),
    "castle_ring": nudge(FRAME, lambda p: True, (0.012, 0, 0),
                         lambda lo, hi: abs(lo.x + 0.03) < 0.005 and abs(hi.x + 0.003) < 0.005),
    "buffer_tube": nudge(FRAME, lambda p: p.x > -0.01, (0.016, 0, 0),
                         lambda lo, hi: abs(lo.x + 0.36) < 0.01 and abs(hi.x + 0.006) < 0.005),
    "barrel_end": nudge(bpy.data.objects["FB_BarrelTube"], lambda p: p.x > 2.785, (0.010, 0, 0)),
}

# ---------------------------------------------------------------- handguard cryo-shroud & rail riser
side("FB_RailRiser", [(0.870, 0.374), (1.143, 0.374), (1.143, 0.434), (0.870, 0.434)], -0.022, 0.022, OBSIDIAN)
hand = folded("FB_Handguard", (
    (1.115, 0.189, 0.432, 0.088, 0.410, 0.223, 0.066),
    (2.290, 0.189, 0.432, 0.088, 0.410, 0.223, 0.066),
    (2.362, 0.262, 0.428, 0.082, 0.406, 0.290, 0.060),
), ARMOR, bevel=0.004)
FORE_CHASM = [(1.245, 0.244), (1.415, 0.226), (2.145, 0.242), (2.255, 0.305),
              (2.185, 0.382), (1.345, 0.382), (1.245, 0.335)]
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(hand, f"FB_ForeChasm_{label}", FORE_CHASM, 0.081 * sign, 0.15 * sign, role=OBSIDIAN)

# ---------------------------------------------------------------- sculpted wing armor (keeps ChargingHandle x .48..767 z .318..375 clear!)
for sign, label in ((1, "Left"), (-1, "Right")):
    armor_plate(
        f"FB_RecArmorRear_{label}",
        [(-0.045, 0.140), (0.375, 0.136), (0.455, 0.165), (0.315, 0.192),
         (0.065, 0.194), (-0.045, 0.205)],
        0.075 * sign, 0.098 * sign, 0.105 * sign, ARMOR, rim_role=FROSTSTEEL, inset=0.007,
    )
    armor_plate(
        f"FB_UpperBrowPlate_{label}",
        [(0.065, 0.378), (0.425, 0.376), (0.795, 0.376), (0.875, 0.398),
         (0.755, 0.416), (0.185, 0.416), (0.045, 0.404)],
        0.074 * sign, 0.094 * sign, 0.099 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.006,
    )
    armor_plate(
        f"FB_BridgeWing_{label}",
        [(0.865, 0.248), (1.035, 0.256), (1.285, 0.345), (1.375, 0.388),
         (1.215, 0.405), (0.945, 0.395), (0.875, 0.318)],
        0.080 * sign, 0.106 * sign, 0.114 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.008,
    )
    armor_plate(
        f"FB_ForeJawFront_{label}",
        [(1.965, 0.242), (2.175, 0.256), (2.315, 0.295), (2.275, 0.368),
         (2.085, 0.402), (1.945, 0.392), (2.065, 0.320)],
        0.078 * sign, 0.106 * sign, 0.114 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.008,
    )
    armor_plate(
        f"FB_ForeChinPlate_{label}",
        [(1.215, 0.200), (1.465, 0.182), (2.045, 0.184), (2.215, 0.232),
         (2.055, 0.254), (1.345, 0.246), (1.215, 0.248)],
        0.076 * sign, 0.102 * sign, 0.110 * sign, ARMOR, rim_role=FROSTSTEEL, inset=0.008,
    )

# ---------------------------------------------------------------- receiver cryo-core bay & crystals
# Left sits on upper receiver face (y .086, z .240..316, clear of FireSelector x<=.173 & BoltCatch x .404..470);
CORE_BAY_L = [(0.195, 0.240), (0.688, 0.240), (0.706, 0.264), (0.682, 0.316), (0.205, 0.316), (0.188, 0.278)]
CORE_BAY_R = [(0.195, 0.204), (0.688, 0.204), (0.706, 0.228), (0.682, 0.260), (0.205, 0.260), (0.188, 0.232)]
for sign, label in ((1, "Left"), (-1, "Right")):
    bay = side(f"FB_CoreBay_{label}", CORE_BAY_L if sign == 1 else CORE_BAY_R, 0.076 * sign, 0.098 * sign, ARMOR)
    recess(bay, f"FB_CoreChasm_{label}",
           ([(0.215, 0.249), (0.668, 0.249), (0.684, 0.276), (0.662, 0.307), (0.222, 0.307), (0.208, 0.278)]
            if sign == 1 else
            [(0.215, 0.212), (0.668, 0.212), (0.684, 0.234), (0.662, 0.252), (0.222, 0.252), (0.208, 0.232)]),
           0.084 * sign, 0.13 * sign, role=OBSIDIAN)
    fz = (0.276, 0.272, 0.282, 0.278) if sign == 1 else (0.232, 0.228, 0.236, 0.232)
    swept_rib(f"FB_CoreFissure_{label}", [
        (0.225, 0.087 * sign, fz[0], 0.005, 0.006),
        (0.385, 0.088 * sign, fz[1], 0.006, 0.007),
        (0.545, 0.088 * sign, fz[2], 0.006, 0.007),
        (0.665, 0.087 * sign, fz[3], 0.005, 0.006),
    ], CRYO_GLOW, flat_group="FBCoreFissure")
    swept_rib(f"FB_UpperSeam_{label}", [
        (0.185, 0.086 * sign, 0.394, 0.005, 0.005),
        (0.425, 0.086 * sign, 0.398, 0.005, 0.005),
        (0.685, 0.086 * sign, 0.394, 0.005, 0.005),
    ], CRYO_GLOW, flat_group="FBUpperSeam")
    swept_rib(f"FB_ForeSeam_{label}", [
        (1.315, 0.086 * sign, 0.286, 0.005, 0.007),
        (1.625, 0.088 * sign, 0.304, 0.006, 0.008),
        (1.945, 0.088 * sign, 0.324, 0.006, 0.007),
        (2.165, 0.086 * sign, 0.336, 0.005, 0.006),
    ], CRYO_GLOW, flat_group="FBForeSeam")

    dz = 0.0 if sign == 1 else -0.044
    glacier_cluster(f"FB_CoreCrystals_{label}", [
        {"points_xz": [(0.228, 0.270 + dz), (0.320, 0.254 + dz), (0.415, 0.264 + dz),
                       (0.375, 0.302 + dz), (0.265, 0.298 + dz)],
         "base_y": 0.0835 * sign, "shoulder_y": 0.104 * sign, "crest_y": 0.116 * sign, "ridge_bias": (-0.014, 0.004)},
        {"points_xz": [(0.498, 0.268 + dz), (0.588, 0.254 + dz), (0.670, 0.274 + dz),
                       (0.618, 0.304 + dz), (0.515, 0.298 + dz)],
         "base_y": 0.0835 * sign, "shoulder_y": 0.106 * sign, "crest_y": 0.118 * sign,
         "roles": (ICE_MID, ICE_MID, ICE_BRIGHT), "ridge_bias": (-0.012, 0.004)},
    ])
    glacier_cluster(f"FB_ForeCrystals_{label}", [
        {"points_xz": [(1.305, 0.296), (1.465, 0.272), (1.665, 0.302), (1.605, 0.365), (1.365, 0.352)],
         "base_y": 0.083 * sign, "shoulder_y": 0.108 * sign, "crest_y": 0.122 * sign, "ridge_bias": (-0.025, 0.008)},
        {"points_xz": [(1.625, 0.288), (1.815, 0.262), (2.015, 0.298), (1.945, 0.362), (1.705, 0.346)],
         "base_y": 0.084 * sign, "shoulder_y": 0.110 * sign, "crest_y": 0.124 * sign,
         "roles": (ICE_MID, ICE_MID, ICE_BRIGHT), "ridge_bias": (-0.022, 0.006)},
    ])

glacier_shard(
    "FB_CoreHeart_Left",
    [(0.422, 0.278), (0.458, 0.262), (0.494, 0.276), (0.462, 0.294)],
    0.088, 0.112, 0.123,
    roles=(GLOW_WHITE, GLOW_WHITE, GLOW_WHITE),
    ridge_bias=(-0.005, 0.002),
    flat_group="FBCoreHeart",
)

glacier_cluster("FB_ForeKeel", [
    {"points_xz": [(1.415, 0.184), (1.635, 0.146), (1.885, 0.205), (1.795, 0.236), (1.495, 0.218)],
     "base_y": 0.026, "shoulder_y": -0.024, "crest_y": -0.036, "ridge_bias": (-0.020, -0.010)},
    {"points_xz": [(1.415, 0.184), (1.635, 0.146), (1.885, 0.205), (1.795, 0.236), (1.495, 0.218)],
     "base_y": -0.026, "shoulder_y": 0.024, "crest_y": 0.036, "ridge_bias": (-0.020, -0.010)},
])

# ---------------------------------------------------------------- cryo muzzle brake (x 2.77..2.9984)
brake = prism_along("FB_Brake", (2.770, 0, 0.368), (1, 0, 0), [
    (0.000, 0.048), (0.010, 0.058), (0.052, 0.058), (0.052, 0.050), (0.086, 0.050), (0.086, 0.062),
    (0.196, 0.062), (0.206, 0.054), (0.222, 0.054), (0.230, 0.046), (0.230, 0.022), (0.200, 0.022),
], FROSTSTEEL)
for k, x in enumerate((2.876, 2.922)):
    recess(brake, f"FB_BrakePort_{k + 1}", [(x, 0.352), (x + 0.028, 0.352), (x + 0.028, 0.384), (x, 0.384)],
           -0.2, 0.2, role=OBSIDIAN)
prism_along("FB_MuzzleGlow", (2.820, 0, 0.368), (1, 0, 0), [(0, 0.055), (0.038, 0.055)],
            CRYO_GLOW)["flat_group"] = "FBMuzzleGlow"
glacier_cluster("FB_MuzzleIce", [
    {"points_xz": [(2.785, 0.312), (2.885, 0.285), (2.975, 0.316), (2.905, 0.340)],
     "base_y": 0.020, "shoulder_y": -0.018, "crest_y": -0.030, "ridge_bias": (-0.012, -0.006)},
    {"points_xz": [(2.785, 0.312), (2.885, 0.285), (2.975, 0.316), (2.905, 0.340)],
     "base_y": -0.020, "shoulder_y": 0.018, "crest_y": 0.030, "ridge_bias": (-0.012, -0.006)},
])

# ---------------------------------------------------------------- swept glacial wing stock
butt = side("FB_StockButt", [
    (-1.045, 0.414), (-1.205, 0.442), (-1.238, 0.424), (-1.245, 0.376), (-1.226, 0.360),
    (-1.220, 0.196), (-1.245, 0.178), (-1.245, 0.134), (-1.226, 0.116), (-1.226, -0.140),
    (-1.200, -0.176), (-1.045, -0.176),
], -0.076, 0.076, ARMOR, bevel=0.007)
STOCK_REC = [(-1.095, -0.115), (-1.195, -0.115), (-1.208, 0.315), (-1.188, 0.335), (-1.095, 0.335)]
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(butt, f"FB_ButtRecess_{label}", STOCK_REC, 0.068 * sign, 0.11 * sign, role=OBSIDIAN)
    armor_plate(
        f"FB_StockWingCheek_{label}",
        [(-1.075, 0.358), (-1.200, 0.358), (-1.216, 0.416), (-1.196, 0.434), (-1.075, 0.410)],
        0.064 * sign, 0.082 * sign, 0.088 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.007,
    )
    armor_plate(
        f"FB_StockFrameWing_{label}",
        [(-0.625, 0.258), (-0.495, 0.258), (-0.455, 0.378), (-0.595, 0.378)],
        0.064 * sign, 0.078 * sign, 0.084 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.006,
    )
for sign, label in ((1, "L"), (-1, "R")):
    glacier_cluster(f"FB_StockCrystals_{label}", [
        {"points_xz": [(-1.195, -0.085), (-1.105, -0.005), (-1.095, 0.275), (-1.192, 0.195)],
         "base_y": 0.066 * sign, "shoulder_y": 0.084 * sign, "crest_y": 0.096 * sign, "ridge_bias": (0.010, 0.006)},
    ])
swept_rib("FB_StockGlow", [
    (-1.168, 0.0, -0.065, 0.056, 0.010),
    (-1.150, 0.0,  0.105, 0.056, 0.010),
    (-1.132, 0.0,  0.275, 0.056, 0.010),
], CRYO_GLOW, flat_group="FBStockGlow")

# ---------------------------------------------------------------- sculpted frost magazine (bone Mag)
for sign, label in ((1, "Left"), (-1, "Right")):
    armor_plate(
        f"FB_MagCowl_{label}",
        [(0.615, -0.195), (0.745, -0.180), (0.785, -0.255), (0.645, -0.265)],
        0.054 * sign, 0.067 * sign, 0.072 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.005, bone="Mag",
    )
    swept_rib(f"FB_MagGlow_{label}", [
        (0.665, 0.0615 * sign, -0.165, 0.006, 0.007),
        (0.688, 0.0625 * sign, -0.122, 0.006, 0.008),
        (0.712, 0.0615 * sign, -0.080, 0.006, 0.007),
    ], CRYO_GLOW, bone="Mag", flat_group="FBMagGlow")

# ---------------------------------------------------------------- animated flat_groups (Root, single-mat)
# FBGrowRear sits behind ChargingHandle rear extreme (x <= 0.45), FBGrowMid starts past nose (x >= 1.12),
# FBGrowFront sits ahead on fore-end shoulder (x 1.62..2.02).
glacier_cluster("FB_GrowRear", [
    {"points_xz": [(0.165, 0.372), (0.295, 0.360), (0.445, 0.376), (0.395, 0.404), (0.215, 0.400)],
     "base_y": 0.082, "shoulder_y": 0.102, "crest_y": 0.114,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.018, 0.005)},
    {"points_xz": [(0.165, 0.372), (0.295, 0.360), (0.445, 0.376), (0.395, 0.404), (0.215, 0.400)],
     "base_y": -0.082, "shoulder_y": -0.102, "crest_y": -0.114,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.018, 0.005)},
], flat_group="FBGrowRear")

glacier_cluster("FB_GrowMid", [
    {"points_xz": [(1.145, 0.358), (1.295, 0.342), (1.475, 0.360), (1.405, 0.394), (1.205, 0.388)],
     "base_y": 0.082, "shoulder_y": 0.106, "crest_y": 0.118,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.020, 0.007)},
    {"points_xz": [(1.145, 0.358), (1.295, 0.342), (1.475, 0.360), (1.405, 0.394), (1.205, 0.388)],
     "base_y": -0.082, "shoulder_y": -0.106, "crest_y": -0.118,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.020, 0.007)},
], flat_group="FBGrowMid")

glacier_cluster("FB_GrowFront", [
    {"points_xz": [(1.625, 0.358), (1.805, 0.344), (2.015, 0.360), (1.945, 0.392), (1.695, 0.388)],
     "base_y": 0.082, "shoulder_y": 0.106, "crest_y": 0.118,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.020, 0.006)},
    {"points_xz": [(1.625, 0.358), (1.805, 0.344), (2.015, 0.360), (1.945, 0.392), (1.695, 0.388)],
     "base_y": -0.082, "shoulder_y": -0.106, "crest_y": -0.118,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.020, 0.006)},
], flat_group="FBGrowFront")

glacier_shard(
    "FB_Shard1", [(0.245, 0.264), (0.375, 0.252), (0.545, 0.266), (0.495, 0.294), (0.285, 0.290)],
    0.092, 0.114, 0.126, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.014, 0.004), flat_group="FBShard1",
)
glacier_shard(
    "FB_Shard2", [(1.485, 0.302), (1.685, 0.284), (1.905, 0.312), (1.835, 0.352), (1.555, 0.342)],
    0.092, 0.116, 0.129, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.018, 0.005), flat_group="FBShard2",
)
glacier_shard(
    "FB_Shard3", [(0.245, 0.264), (0.375, 0.252), (0.545, 0.266), (0.495, 0.294), (0.285, 0.290)],
    -0.092, -0.114, -0.126, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.014, 0.004), flat_group="FBShard3",
)
glacier_shard(
    "FB_Shard4", [(1.485, 0.302), (1.685, 0.284), (1.905, 0.312), (1.835, 0.352), (1.555, 0.342)],
    -0.092, -0.116, -0.129, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.018, 0.005), flat_group="FBShard4",
)

result = finish_master(hand)
result["gap_moves"] = gap_moves
