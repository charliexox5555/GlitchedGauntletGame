"""Frostbite Deadeye (Operator) v01: Legendary sculpted cryo-armor remodel."""

from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

GUN = "Operator"
VERSION = globals().get("VERSION", "v02")
exec((Path(bpy.data.filepath).parents[4] / "tools/blender/frostbite/frost_lib.py").read_text(encoding="utf-8"))

replace("Handguard", "Stock", "Barrel", "Neon")

# ---------------------------------------------------------------- retained stock + gap sweep
for name in ("Receiver", "CharmLoop", "Bolt", "Trigger", "Grip", "Scope"):
    dress(name)
dress("Magazine", slots={"Dark": GRIP, "Body": ARMOR, "Panel": OBSIDIAN, "Accent": FROSTSTEEL})
dress("Stock", copy_name="FB_StockFrame", keep=lambda island: limits(island, 0)[0] > -1.09)
dress("Barrel", copy_name="FB_BarrelTube", keep=lambda island: limits(island, 0)[1] < 3.24)


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


RECEIVER = native("Receiver")
FRAME = bpy.data.objects["FB_StockFrame"]
gap_moves = {
    "grip_top": nudge(native("Grip"), lambda p: p.z > 0.13, (0, 0, 0.033)),
    "trigger_guard_top": nudge(RECEIVER, lambda p: p.z > 0.128, (0, 0, 0.022),
                               lambda lo, hi: abs(lo.x - 0.112) < 0.005 and abs(hi.z - 0.133) < 0.003),
    "magwell_top": nudge(RECEIVER, lambda p: p.z > 0.135, (0, 0, 0.016),
                         lambda lo, hi: abs(lo.x - 0.429) < 0.005 and abs(hi.z - 0.14) < 0.003),
    "tube_front": nudge(FRAME, lambda p: p.x > 0.05, (0.022, 0, 0),
                        lambda lo, hi: abs(lo.x + 0.333) < 0.005 and abs(hi.x - 0.06) < 0.005),
    "tube_rear": nudge(FRAME, lambda p: p.x < -0.32, (-0.022, 0, 0),
                       lambda lo, hi: abs(lo.x + 0.333) < 0.005 and abs(hi.x - 0.082) < 0.005),
    "riser_posts_top": nudge(FRAME, lambda p: p.z > 0.33, (0, 0, 0.020),
                             lambda lo, hi: hi.x - lo.x < 0.03 and abs(hi.z - 0.335) < 0.003),
    "riser_posts_foot": nudge(FRAME, lambda p: p.z < 0.295, (0, 0, -0.010),
                              lambda lo, hi: hi.x - lo.x < 0.03 and abs(lo.z - 0.29) < 0.003),
    "rail_foot": nudge(RECEIVER, lambda p: p.z < 0.45, (0, 0, -0.016),
                       lambda lo, hi: abs(lo.x - 0.235) < 0.005 and abs(lo.z - 0.446) < 0.003),
    "rail_teeth_feet": nudge(RECEIVER, lambda p: p.z < 0.4715, (0, 0, -0.019),
                             lambda lo, hi: hi.x - lo.x < 0.035 and abs(lo.z - 0.469) < 0.002),
    "scope_ring_bases": nudge(native("Scope"), lambda p: p.z < 0.48, (0, 0, -0.032),
                              lambda lo, hi: hi.x - lo.x > 0.06 and hi.x - lo.x < 0.08
                              and abs(lo.z - 0.478) < 0.003 and hi.y < 0.04),
    "scope_ring_bases_widen": sum(nudge(native("Scope"), lambda p, s=s: p.y * s > 0.03, (0, 0.002 * s, 0),
                                        lambda lo, hi: hi.x - lo.x > 0.06 and hi.x - lo.x < 0.08
                                        and abs(lo.z - 0.446) < 0.003 and hi.y < 0.04) for s in (1, -1)),
    "barrel_end": nudge(bpy.data.objects["FB_BarrelTube"], lambda p: p.x > 3.115, (0.012, 0, 0),
                        lambda lo, hi: lo.x < 2.21),
}

# ---------------------------------------------------------------- handguard cryo-shroud (x 1.070..2.240)
REAR = (1.070, 0.145, 0.451, 0.088, 0.430, 0.185, 0.066)
FRONT = (2.165, 0.245, 0.451, 0.088, 0.430, 0.285, 0.066)
hand = folded("FB_Handguard", (REAR, FRONT, (2.240, 0.300, 0.449, 0.082, 0.426, 0.325, 0.060)), ARMOR, bevel=0.004)
FORE_CHASM = [(1.245, 0.275), (1.425, 0.258), (2.015, 0.275), (2.115, 0.325),
              (2.065, 0.405), (1.305, 0.405), (1.225, 0.352)]
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(hand, f"FB_ForeChasm_{label}", FORE_CHASM, 0.080 * sign, 0.15 * sign, role=OBSIDIAN)

# ---------------------------------------------------------------- sculpted wing armor
# Left stays <= .110 under ADS cone (eye x -.9625, z .602) & behind CharmLoop (x .929); Right clears Bolt (.301+)
for sign, label in ((1, "Left"), (-1, "Right")):
    armor_plate(
        f"FB_RecArmorRear_{label}",
        [(0.075, 0.150), (0.315, 0.150), (0.365, 0.185), (0.285, 0.295), (0.075, 0.295)],
        0.082 * sign, 0.098 * sign, 0.104 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.007,
    )
    armor_plate(
        f"FB_BridgeWing_{label}",
        [(1.045, 0.220), (1.165, 0.245), (1.315, 0.355), (1.375, 0.415),
         (1.225, 0.422), (1.065, 0.412), (1.035, 0.310)],
        0.082 * sign, 0.108 * sign, 0.116 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.008,
    )
    armor_plate(
        f"FB_ForeJawFront_{label}",
        [(1.885, 0.268), (2.065, 0.282), (2.215, 0.318), (2.165, 0.398),
         (1.985, 0.418), (1.865, 0.398)],
        0.082 * sign, 0.108 * sign, 0.116 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.008,
    )
    armor_plate(
        f"FB_ForeChinPlate_{label}",
        [(1.215, 0.185), (1.515, 0.195), (1.925, 0.245), (1.845, 0.285),
         (1.425, 0.248), (1.205, 0.242)],
        0.076 * sign, 0.102 * sign, 0.109 * sign, ARMOR, rim_role=FROSTSTEEL, inset=0.007,
    )

# ---------------------------------------------------------------- cryo-core bay & crystals (x .35..77, z .160..308)
CORE_BAY = [(0.365, 0.160), (0.755, 0.160), (0.775, 0.225), (0.750, 0.295), (0.375, 0.295), (0.352, 0.228)]
for sign, label in ((1, "Left"), (-1, "Right")):
    bay = side(f"FB_CoreBay_{label}", CORE_BAY, 0.082 * sign, 0.104 * sign, ARMOR)
    recess(bay, f"FB_CoreChasm_{label}",
           [(0.382, 0.172), (0.735, 0.172), (0.752, 0.228), (0.732, 0.284), (0.392, 0.284), (0.370, 0.228)],
           0.092 * sign, 0.14 * sign, role=OBSIDIAN)
    swept_rib(f"FB_CoreFissure_{label}", [
        (0.395, 0.098 * sign, 0.228, 0.005, 0.006),
        (0.515, 0.099 * sign, 0.222, 0.006, 0.007),
        (0.635, 0.099 * sign, 0.232, 0.006, 0.007),
        (0.728, 0.098 * sign, 0.228, 0.005, 0.006),
    ], CRYO_GLOW, flat_group="FBCoreFissure")
    swept_rib(f"FB_ForeSeam_{label}", [
        (1.265, 0.088 * sign, 0.312, 0.005, 0.007),
        (1.565, 0.089 * sign, 0.332, 0.006, 0.008),
        (1.885, 0.089 * sign, 0.348, 0.006, 0.007),
        (2.045, 0.088 * sign, 0.358, 0.005, 0.006),
    ], CRYO_GLOW, flat_group="FBForeSeam")
    glacier_cluster(f"FB_CoreCrystals_{label}", [
        {"points_xz": [(0.392, 0.215), (0.468, 0.192), (0.545, 0.208), (0.512, 0.262), (0.415, 0.256)],
         "base_y": 0.088 * sign, "shoulder_y": 0.108 * sign, "crest_y": 0.120 * sign, "ridge_bias": (-0.012, 0.004)},
        {"points_xz": [(0.595, 0.212), (0.675, 0.194), (0.742, 0.220), (0.695, 0.268), (0.608, 0.258)],
         "base_y": 0.088 * sign, "shoulder_y": 0.110 * sign, "crest_y": 0.122 * sign,
         "roles": (ICE_MID, ICE_MID, ICE_BRIGHT), "ridge_bias": (-0.012, 0.004)},
    ])
    glacier_cluster(f"FB_ForeCrystals_{label}", [
        {"points_xz": [(1.275, 0.305), (1.425, 0.282), (1.595, 0.318), (1.535, 0.388), (1.325, 0.375)],
         "base_y": 0.080 * sign, "shoulder_y": 0.110 * sign, "crest_y": 0.126 * sign, "ridge_bias": (-0.022, 0.008)},
        {"points_xz": [(1.665, 0.305), (1.825, 0.285), (1.995, 0.322), (1.935, 0.392), (1.715, 0.378)],
         "base_y": 0.080 * sign, "shoulder_y": 0.112 * sign, "crest_y": 0.128 * sign,
         "roles": (ICE_MID, ICE_MID, ICE_BRIGHT), "ridge_bias": (-0.020, 0.006)},
    ])

glacier_shard(
    "FB_CoreHeart_Left",
    [(0.535, 0.230), (0.568, 0.212), (0.602, 0.228), (0.572, 0.248)],
    0.092, 0.116, 0.128,
    roles=(GLOW_WHITE, GLOW_WHITE, GLOW_WHITE),
    ridge_bias=(-0.004, 0.002),
    flat_group="FBCoreHeart",
)

glacier_cluster("FB_ForeKeel", [
    {"points_xz": [(1.345, 0.172), (1.555, 0.145), (1.765, 0.202), (1.685, 0.232), (1.415, 0.210)],
     "base_y": 0.028, "shoulder_y": -0.026, "crest_y": -0.038, "ridge_bias": (-0.018, -0.010)},
    {"points_xz": [(1.345, 0.172), (1.555, 0.145), (1.765, 0.202), (1.685, 0.232), (1.415, 0.210)],
     "base_y": -0.028, "shoulder_y": 0.026, "crest_y": 0.038, "ridge_bias": (-0.018, -0.010)},
])

# ---------------------------------------------------------------- heavy ported cryo brake (x 3.215..3.522, z .385)
brake = prism_along("FB_Brake", (3.215, 0, 0.385), (1, 0, 0), [
    (0.000, 0.066), (0.006, 0.074), (0.050, 0.074), (0.050, 0.062), (0.090, 0.062), (0.090, 0.079),
    (0.262, 0.079), (0.272, 0.070), (0.290, 0.070), (0.299, 0.060), (0.307, 0.060), (0.307, 0.026),
    (0.275, 0.026),
], FROSTSTEEL)
for k, x in enumerate((3.360, 3.408, 3.456)):
    recess(brake, f"FB_BrakePort_{k + 1}", [(x, 0.366), (x + 0.028, 0.366), (x + 0.028, 0.404), (x, 0.404)],
           -0.2, 0.2, role=OBSIDIAN)
prism_along("FB_MuzzleGlow", (3.262, 0, 0.385), (1, 0, 0), [(0, 0.067), (0.046, 0.067)],
            CRYO_GLOW)["flat_group"] = "FBMuzzleGlow"
glacier_cluster("FB_MuzzleIce", [
    {"points_xz": [(3.235, 0.312), (3.355, 0.282), (3.485, 0.316), (3.395, 0.344)],
     "base_y": 0.022, "shoulder_y": -0.022, "crest_y": -0.034, "ridge_bias": (-0.014, -0.008)},
    {"points_xz": [(3.235, 0.312), (3.355, 0.282), (3.485, 0.316), (3.395, 0.344)],
     "base_y": -0.022, "shoulder_y": 0.022, "crest_y": 0.034, "ridge_bias": (-0.014, -0.008)},
])

# ---------------------------------------------------------------- swept glacial butt & stock wing
butt = side("FB_StockButt", [
    (-1.060, 0.380), (-1.250, 0.418), (-1.290, 0.398), (-1.300, 0.352), (-1.282, 0.334),
    (-1.282, 0.182), (-1.318, 0.160), (-1.318, -0.150), (-1.300, -0.200), (-1.268, -0.222),
    (-1.060, -0.222),
], -0.082, 0.082, ARMOR, bevel=0.008)
STOCK_REC = [(-1.094, -0.152), (-1.268, -0.152), (-1.268, 0.280), (-1.250, 0.298), (-1.094, 0.298)]
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(butt, f"FB_ButtRecess_{label}", STOCK_REC, 0.074 * sign, 0.12 * sign, role=OBSIDIAN)
    armor_plate(
        f"FB_StockWingCheek_{label}",
        [(-1.092, 0.330), (-1.250, 0.330), (-1.264, 0.384), (-1.248, 0.398), (-1.092, 0.368)],
        0.070 * sign, 0.088 * sign, 0.094 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.007,
    )
    armor_plate(
        f"FB_StockFrameWing_{label}",
        [(-0.785, 0.236), (-0.545, 0.236), (-0.495, 0.294), (-0.755, 0.294)],
        0.068 * sign, 0.082 * sign, 0.088 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.006,
    )
for sign, label in ((1, "L"), (-1, "R")):
    glacier_cluster(f"FB_StockCrystals_{label}", [
        {"points_xz": [(-1.252, -0.115), (-1.125, -0.025), (-1.115, 0.255), (-1.248, 0.175)],
         "base_y": 0.072 * sign, "shoulder_y": 0.092 * sign, "crest_y": 0.104 * sign, "ridge_bias": (0.012, 0.006)},
    ])
swept_rib("FB_StockGlow", [
    (-1.225, 0.0, -0.085, 0.062, 0.010),
    (-1.205, 0.0,  0.095, 0.062, 0.010),
    (-1.185, 0.0,  0.275, 0.062, 0.010),
], CRYO_GLOW, flat_group="FBStockGlow")

# ---------------------------------------------------------------- magazine glow & cowl (bone Mag)
for sign, label in ((1, "Left"), (-1, "Right")):
    armor_plate(
        f"FB_MagCowl_{label}",
        [(0.525, -0.035), (0.725, -0.025), (0.745, 0.045), (0.545, 0.035)],
        0.052 * sign, 0.066 * sign, 0.072 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.005, bone="Mag",
    )
    swept_rib(f"FB_MagGlow_{label}", [
        (0.585, 0.062 * sign, -0.045, 0.005, 0.006),
        (0.625, 0.063 * sign,  0.025, 0.006, 0.007),
        (0.665, 0.062 * sign,  0.086, 0.005, 0.006),
    ], CRYO_GLOW, bone="Mag", flat_group="FBMagGlow")

# ---------------------------------------------------------------- animated flat_groups (Root, single-mat)
glacier_cluster("FB_GrowRear", [
    {"points_xz": [(0.425, 0.285), (0.565, 0.272), (0.715, 0.290), (0.655, 0.326), (0.475, 0.320)],
     "base_y": 0.086, "shoulder_y": 0.106, "crest_y": 0.118,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.016, 0.005)},
    {"points_xz": [(0.425, 0.285), (0.565, 0.272), (0.715, 0.290), (0.655, 0.326), (0.475, 0.320)],
     "base_y": -0.086, "shoulder_y": -0.106, "crest_y": -0.118,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.016, 0.005)},
], flat_group="FBGrowRear")

glacier_cluster("FB_GrowMid", [
    {"points_xz": [(1.395, 0.365), (1.515, 0.348), (1.655, 0.368), (1.595, 0.405), (1.435, 0.398)],
     "base_y": 0.084, "shoulder_y": 0.108, "crest_y": 0.122,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.016, 0.006)},
    {"points_xz": [(1.395, 0.365), (1.515, 0.348), (1.655, 0.368), (1.595, 0.405), (1.435, 0.398)],
     "base_y": -0.084, "shoulder_y": -0.108, "crest_y": -0.122,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.016, 0.006)},
], flat_group="FBGrowMid")

glacier_cluster("FB_GrowFront", [
    {"points_xz": [(1.625, 0.368), (1.795, 0.354), (1.975, 0.372), (1.905, 0.408), (1.685, 0.402)],
     "base_y": 0.084, "shoulder_y": 0.108, "crest_y": 0.122,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.018, 0.006)},
    {"points_xz": [(1.625, 0.368), (1.795, 0.354), (1.975, 0.372), (1.905, 0.408), (1.685, 0.402)],
     "base_y": -0.084, "shoulder_y": -0.108, "crest_y": -0.122,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.018, 0.006)},
], flat_group="FBGrowFront")

glacier_shard(
    "FB_Shard1", [(0.425, 0.215), (0.555, 0.198), (0.715, 0.220), (0.665, 0.254), (0.465, 0.248)],
    0.096, 0.118, 0.130, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.014, 0.004), flat_group="FBShard1",
)
glacier_shard(
    "FB_Shard2", [(1.465, 0.315), (1.645, 0.295), (1.845, 0.322), (1.775, 0.365), (1.525, 0.355)],
    0.092, 0.116, 0.130, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.016, 0.005), flat_group="FBShard2",
)
glacier_shard(
    "FB_Shard3", [(0.425, 0.215), (0.555, 0.198), (0.715, 0.220), (0.665, 0.254), (0.465, 0.248)],
    -0.096, -0.118, -0.130, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.014, 0.004), flat_group="FBShard3",
)
glacier_shard(
    "FB_Shard4", [(1.465, 0.315), (1.645, 0.295), (1.845, 0.322), (1.775, 0.365), (1.525, 0.355)],
    -0.092, -0.116, -0.130, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.016, 0.005), flat_group="FBShard4",
)

result = finish_master(hand)
result["gap_moves"] = gap_moves
