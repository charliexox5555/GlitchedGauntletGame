"""Frostbite Spirit (Phantom) v01: Legendary sculpted cryo-armor remodel."""

from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

GUN = "Phantom"
VERSION = globals().get("VERSION", "v04")
exec((Path(bpy.data.filepath).parents[4] / "tools/blender/frostbite/frost_lib.py").read_text(encoding="utf-8"))

replace("Handguard", "Stock", "Suppressor", "Neon")

for name in ("Receiver", "Rail", "Pins", "CharmLoop", "ChargingHandle", "Bolt",
             "FireSelector", "Trigger", "Grip", "Sights"):
    dress(name)
dress("Mag", slots={"Dark": GRIP, "Body": ARMOR, "Panel": OBSIDIAN, "Accent": FROSTSTEEL})

_receiver = native("Receiver")
_bm = bmesh.new()
_bm.from_mesh(_receiver.data)
_cap = {v for f in _bm.faces
        if _receiver.data.materials[f.material_index].name == "FB FrostSteel" and f.normal.z < -0.999
        and abs(f.calc_center_median().z - 0.16) < 0.001 and f.calc_center_median().x < -0.1 for v in f.verts}
bmesh.ops.translate(_bm, verts=list(_cap), vec=(0, 0, 0.004))
_bm.to_mesh(_receiver.data)
_bm.free()

dress("Handguard", copy_name="FB_HandguardCap", keep=lambda island: limits(island, 0)[0] > 1.59)
dress("Stock", copy_name="FB_StockFrame", keep=lambda island: limits(island, 0)[0] > -1.0)
dress("Suppressor", copy_name="FB_BarrelStub", keep=lambda island: limits(island, 0)[1] < 1.75)


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


GUARD = lambda lo, hi: lo.x > 0.1 and hi.x > 0.45 and lo.z > 0.0
GRIP_ISLAND = lambda lo, hi: lo.z < -0.2
SIGHTS = native("Sights")
gap_moves = {
    "guard_rear": nudge(native("Grip"), lambda p: p.x < 0.19, (-0.035, 0, 0), GUARD),
    "guard_post_up": nudge(native("Grip"), lambda p: p.z > 0.15, (0, 0, 0.022), GUARD),
    "grip_top": nudge(native("Grip"), lambda p: p.z > 0.145, (0, 0, 0.020), GRIP_ISLAND),
    "front_sight_base": nudge(SIGHTS, lambda p: p.z < 0.487, (0, 0, -0.032),
                              lambda lo, hi: lo.x > 1.49 and lo.z > 0.48 and hi.z < 0.535),
    "front_sight_hood": nudge(SIGHTS, lambda p: p.z < 0.529, (0, 0, -0.020),
                              lambda lo, hi: lo.x > 1.5 and 0.52 < lo.z < 0.529 and hi.z > 0.6),
    "front_sight_blade": nudge(SIGHTS, lambda p: p.z < 0.526, (0, 0, -0.020),
                               lambda lo, hi: lo.x > 1.5 and 0.52 < lo.z < 0.526 and hi.z < 0.58 and hi.y < 0.01),
    "rear_sight_block": nudge(SIGHTS, lambda p: p.z < 0.497, (0, 0, -0.016),
                              lambda lo, hi: lo.x > 0.13 and hi.x < 0.17 and lo.z > 0.49 and hi.z < 0.52),
    "rear_sight_base": nudge(SIGHTS, lambda p: p.z < 0.469, (0, 0, -0.014),
                             lambda lo, hi: lo.x < 0.1 and hi.x > 0.2 and lo.z > 0.46 and hi.z < 0.505),
    "barrel_stub": nudge(bpy.data.objects["FB_BarrelStub"], lambda p: p.x < 1.648, (-0.028, 0, 0)),
    "buffer_tube": nudge(bpy.data.objects["FB_StockFrame"], lambda p: p.x > -0.175, (0.020, 0, 0),
                         lambda lo, hi: abs(lo.x + 0.39) < 0.01 and abs(hi.x + 0.17) < 0.01),
    "buffer_ring": nudge(bpy.data.objects["FB_StockFrame"], lambda p: True, (0.007, 0, 0),
                         lambda lo, hi: abs(lo.x + 0.19) < 0.005 and abs(hi.x + 0.164) < 0.005),
}

# ---------------------------------------------------------------- handguard cryo-shroud
hand = folded("FB_Handguard", (
    (0.904, 0.206, 0.424, 0.079, 0.400, 0.242, 0.058),
    (0.938, 0.198, 0.431, 0.088, 0.405, 0.238, 0.064),
    (1.034, 0.184, 0.431, 0.088, 0.405, 0.228, 0.064),
    (1.505, 0.184, 0.431, 0.088, 0.405, 0.228, 0.064),
    (1.580, 0.198, 0.431, 0.088, 0.405, 0.238, 0.064),
    (1.626, 0.222, 0.431, 0.074, 0.392, 0.250, 0.052),
), ARMOR, bevel=0.004)
recess(hand, "FB_HandleSlotCut", [(0.888, 0.348), (0.948, 0.348), (0.948, 0.409), (0.888, 0.409)],
       0.064, 0.15, role=OBSIDIAN)
FORE_CHASM = [(1.045, 0.244), (1.175, 0.228), (1.465, 0.242), (1.555, 0.305),
              (1.485, 0.382), (1.135, 0.382), (1.045, 0.335)]
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(hand, f"FB_ForeChasm_{label}", FORE_CHASM, 0.081 * sign, 0.15 * sign, role=OBSIDIAN)

# ---------------------------------------------------------------- sculpted wing armor plates
for sign, label in ((1, "Left"), (-1, "Right")):
    armor_plate(
        f"FB_RecArmorRear_{label}",
        [(0.150, 0.176), (0.375, 0.172), (0.455, 0.198), (0.315, 0.224),
         (0.215, 0.278), (0.148, 0.278), (0.136, 0.224)],
        0.076 * sign, 0.102 * sign, 0.110 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.008,
    )
    armor_plate(
        f"FB_UpperBrowPlate_{label}",
        ([(0.065, 0.312), (0.425, 0.314), (0.415, 0.406), (0.185, 0.406), (-0.045, 0.388)] if sign == 1
         else [(0.065, 0.312), (0.455, 0.314), (0.765, 0.324), (0.845, 0.375),
               (0.715, 0.406), (0.185, 0.406), (-0.045, 0.388)]),
        0.078 * sign, 0.100 * sign, 0.106 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.008,
    )
    armor_plate(
        f"FB_BridgeWing_{label}",
        ([(0.962, 0.258), (1.035, 0.268), (1.205, 0.348), (1.285, 0.390),
          (1.145, 0.404), (0.985, 0.396), (0.962, 0.328)] if sign == 1
         else [(0.845, 0.258), (1.005, 0.268), (1.205, 0.348), (1.285, 0.390),
               (1.145, 0.404), (0.925, 0.396), (0.855, 0.328)]),
        0.080 * sign, 0.106 * sign, 0.114 * sign, ARMOR, rim_role=FROSTSTEEL, inset=0.008,
    )
    armor_plate(
        f"FB_ForeJawFront_{label}",
        [(1.365, 0.238), (1.515, 0.255), (1.605, 0.295), (1.565, 0.368),
         (1.425, 0.400), (1.315, 0.392), (1.435, 0.320)],
        0.078 * sign, 0.106 * sign, 0.114 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.008,
    )
    armor_plate(
        f"FB_ForeChinPlate_{label}",
        [(0.965, 0.205), (1.165, 0.184), (1.465, 0.188), (1.565, 0.226),
         (1.425, 0.254), (1.115, 0.246), (0.965, 0.252)],
        0.076 * sign, 0.103 * sign, 0.111 * sign, ARMOR, rim_role=FROSTSTEEL, inset=0.008,
    )
    armor_plate(
        f"FB_LowerSkirt_{label}",
        [(0.435, 0.156), (0.765, 0.162), (0.815, 0.205), (0.745, 0.256), (0.455, 0.244)],
        0.076 * sign, 0.098 * sign, 0.104 * sign, ARMOR, rim_role=FROSTSTEEL, inset=0.007,
    )

# ---------------------------------------------------------------- cryo-core bay & crystals
CORE_BAY = [(0.170, 0.194), (0.725, 0.194), (0.758, 0.230), (0.722, 0.282), (0.185, 0.282), (0.160, 0.244)]
for sign, label in ((1, "Left"), (-1, "Right")):
    bay = side(f"FB_CoreBay_{label}", CORE_BAY, 0.074 * sign, 0.096 * sign, ARMOR)
    recess(bay, f"FB_CoreChasm_{label}",
           [(0.200, 0.204), (0.688, 0.204), (0.718, 0.236), (0.688, 0.270), (0.212, 0.270), (0.190, 0.238)],
           0.082 * sign, 0.13 * sign, role=OBSIDIAN)
    swept_rib(f"FB_CoreFissure_{label}", [
        (0.215, 0.085 * sign, 0.238, 0.005, 0.006),
        (0.375, 0.086 * sign, 0.232, 0.006, 0.007),
        (0.535, 0.086 * sign, 0.244, 0.006, 0.007),
        (0.682, 0.085 * sign, 0.238, 0.005, 0.006),
    ], CRYO_GLOW, flat_group="FBCoreFissure")
    swept_rib(f"FB_UpperSeam_{label}", [
        (0.215, (0.102 if sign == 1 else 0.085) * sign, 0.365, 0.004, 0.005),
        (0.320 if sign == 1 else 0.455, (0.103 if sign == 1 else 0.086) * sign, 0.370, 0.004, 0.006),
        (0.415 if sign == 1 else 0.685, (0.102 if sign == 1 else 0.085) * sign, 0.366, 0.004, 0.005),
    ], CRYO_GLOW, flat_group="FBUpperSeam")
    swept_rib(f"FB_ForeSeam_{label}", [
        (1.065, 0.086 * sign, 0.285, 0.005, 0.007),
        (1.255, 0.088 * sign, 0.302, 0.006, 0.008),
        (1.445, 0.088 * sign, 0.324, 0.006, 0.007),
        (1.535, 0.086 * sign, 0.334, 0.005, 0.006),
    ], CRYO_GLOW, flat_group="FBForeSeam")

    glacier_cluster(f"FB_CoreCrystals_{label}", [
        {"points_xz": [(0.218, 0.232), (0.315, 0.210), (0.415, 0.220), (0.375, 0.262), (0.260, 0.258)],
         "base_y": 0.083 * sign, "shoulder_y": 0.104 * sign, "crest_y": 0.118 * sign, "ridge_bias": (-0.015, 0.005)},
        {"points_xz": [(0.502, 0.228), (0.610, 0.212), (0.698, 0.234), (0.635, 0.266), (0.522, 0.258)],
         "base_y": 0.084 * sign, "shoulder_y": 0.106 * sign, "crest_y": 0.120 * sign,
         "roles": (ICE_MID, ICE_MID, ICE_BRIGHT), "ridge_bias": (-0.014, 0.004)},
    ])
    glacier_cluster(f"FB_ForeCrystals_{label}", [
        {"points_xz": [(1.060, 0.296), (1.185, 0.272), (1.335, 0.305), (1.285, 0.365), (1.115, 0.352)],
         "base_y": 0.083 * sign, "shoulder_y": 0.108 * sign, "crest_y": 0.122 * sign, "ridge_bias": (-0.022, 0.008)},
        {"points_xz": [(1.255, 0.288), (1.395, 0.262), (1.535, 0.298), (1.475, 0.362), (1.305, 0.346)],
         "base_y": 0.084 * sign, "shoulder_y": 0.110 * sign, "crest_y": 0.124 * sign,
         "roles": (ICE_MID, ICE_MID, ICE_BRIGHT), "ridge_bias": (-0.018, 0.006)},
    ])

glacier_shard(
    "FB_CoreHeart_Left",
    [(0.422, 0.238), (0.460, 0.220), (0.498, 0.236), (0.465, 0.254)],
    0.086, 0.114, 0.126,
    roles=(GLOW_WHITE, GLOW_WHITE, GLOW_WHITE),
    ridge_bias=(-0.005, 0.002),
    flat_group="FBCoreHeart",
)

glacier_cluster("FB_ForeKeel", [
    {"points_xz": [(1.145, 0.184), (1.315, 0.148), (1.495, 0.205), (1.415, 0.236), (1.215, 0.218)],
     "base_y": 0.026, "shoulder_y": -0.024, "crest_y": -0.036, "ridge_bias": (-0.018, -0.010)},
    {"points_xz": [(1.145, 0.184), (1.315, 0.148), (1.495, 0.205), (1.415, 0.236), (1.215, 0.218)],
     "base_y": -0.026, "shoulder_y": 0.024, "crest_y": 0.036, "ridge_bias": (-0.018, -0.010)},
])

# ---------------------------------------------------------------- glacial suppressor shroud
can = prism_along("FB_SuppressorCan", (1.722, 0, 0.352), (1, 0, 0), [
    (0.000, 0.060), (0.018, 0.084), (0.205, 0.084), (0.214, 0.076), (0.252, 0.076), (0.264, 0.090),
    (0.665, 0.090), (0.680, 0.080), (0.762, 0.080), (0.783, 0.062), (0.783, 0.030), (0.750, 0.030),
], ARMOR)
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(can, f"FB_CanVent_{label}", [(1.995, 0.326), (2.065, 0.376), (2.345, 0.376), (2.285, 0.326)],
           0.056 * sign, 0.115 * sign, role=OBSIDIAN)
    armor_plate(
        f"FB_CanFin_{label}",
        [(1.965, 0.304), (2.185, 0.288), (2.405, 0.312), (2.335, 0.352), (2.015, 0.348)],
        0.066 * sign, 0.094 * sign, 0.100 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.007,
    )
prism_along("FB_MuzzleGlow", (1.930, 0, 0.352), (1, 0, 0), [(0, 0.081), (0.038, 0.081)],
            CRYO_GLOW)["flat_group"] = "FBMuzzleGlow"
glacier_cluster("FB_MuzzleIce", [
    {"points_xz": [(1.745, 0.284), (1.895, 0.256), (2.065, 0.292), (1.945, 0.318)],
     "base_y": 0.024, "shoulder_y": -0.022, "crest_y": -0.034, "ridge_bias": (-0.015, -0.008)},
    {"points_xz": [(1.745, 0.284), (1.895, 0.256), (2.065, 0.292), (1.945, 0.318)],
     "base_y": -0.024, "shoulder_y": 0.022, "crest_y": 0.034, "ridge_bias": (-0.015, -0.008)},
])

# ---------------------------------------------------------------- swept glacial wing stock
butt = side("FB_StockButt", [
    (-0.950, 0.420), (-1.096, 0.446), (-1.132, 0.428), (-1.138, 0.380), (-1.116, 0.362),
    (-1.110, 0.205), (-1.136, 0.186), (-1.136, 0.148), (-1.118, 0.132), (-1.118, -0.052),
    (-1.092, -0.078), (-0.950, -0.078),
], -0.076, 0.076, ARMOR, bevel=0.007)
STOCK_REC = [(-0.992, 0.025), (-1.088, 0.025), (-1.098, 0.325), (-1.078, 0.345), (-0.992, 0.345)]
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(butt, f"FB_ButtRecess_{label}", STOCK_REC, 0.068 * sign, 0.11 * sign, role=OBSIDIAN)
    armor_plate(
        f"FB_StockWingCheek_{label}",
        [(-0.968, 0.366), (-1.096, 0.366), (-1.114, 0.422), (-1.094, 0.440), (-0.968, 0.416)],
        0.064 * sign, 0.082 * sign, 0.088 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.007,
    )
    armor_plate(
        f"FB_StockFrameWing_{label}",
        [(-0.545, 0.270), (-0.395, 0.270), (-0.345, 0.382), (-0.515, 0.382)],
        0.060 * sign, 0.074 * sign, 0.080 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.006,
    )
for sign, label in ((1, "L"), (-1, "R")):
    glacier_cluster(f"FB_StockCrystals_{label}", [
        {"points_xz": [(-1.085, 0.015), (-1.005, 0.085), (-0.985, 0.295), (-1.082, 0.225)],
         "base_y": 0.066 * sign, "shoulder_y": 0.084 * sign, "crest_y": 0.096 * sign, "ridge_bias": (0.010, 0.006)},
    ])
swept_rib("FB_StockGlow", [
    (-1.065, 0.0, 0.035, 0.056, 0.010),
    (-1.045, 0.0, 0.165, 0.056, 0.010),
    (-1.025, 0.0, 0.295, 0.056, 0.010),
], CRYO_GLOW, flat_group="FBStockGlow")

# ---------------------------------------------------------------- sculpted frost magazine (bone Mag)
for sign, label in ((1, "Left"), (-1, "Right")):
    armor_plate(
        f"FB_MagCowl_{label}",
        [(0.595, -0.210), (0.765, -0.195), (0.815, -0.295), (0.615, -0.305)],
        0.050 * sign, 0.064 * sign, 0.069 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.006, bone="Mag",
    )
    swept_rib(f"FB_MagGlow_{label}", [
        (0.735, 0.054 * sign, -0.010, 0.006, 0.007),
        (0.745, 0.055 * sign, -0.105, 0.006, 0.008),
        (0.762, 0.055 * sign, -0.198, 0.006, 0.007),
    ], CRYO_GLOW, bone="Mag", flat_group="FBMagGlow")
    glacier_shard(
        f"FB_MagIce_{label}",
        [(0.615, -0.045), (0.715, -0.035), (0.735, -0.185), (0.635, -0.195)],
        0.049 * sign, 0.062 * sign, 0.072 * sign,
        ridge_bias=(-0.008, 0.018), bone="Mag",
    )

# ---------------------------------------------------------------- animated flat_groups (Root, single-mat)
glacier_cluster("FB_GrowRear", [
    {"points_xz": [(0.195, 0.365), (0.365, 0.354), (0.555, 0.370), (0.485, 0.398), (0.255, 0.394)],
     "base_y": 0.080, "shoulder_y": 0.102, "crest_y": 0.114,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.022, 0.006)},
    {"points_xz": [(0.195, 0.365), (0.365, 0.354), (0.555, 0.370), (0.485, 0.398), (0.255, 0.394)],
     "base_y": -0.080, "shoulder_y": -0.102, "crest_y": -0.114,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.022, 0.006)},
], flat_group="FBGrowRear")

glacier_cluster("FB_GrowMid", [
    {"points_xz": [(0.975, 0.355), (1.105, 0.340), (1.245, 0.358), (1.185, 0.392), (1.025, 0.386)],
     "base_y": 0.082, "shoulder_y": 0.106, "crest_y": 0.118,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.018, 0.007)},
    {"points_xz": [(0.975, 0.355), (1.105, 0.340), (1.245, 0.358), (1.185, 0.392), (1.025, 0.386)],
     "base_y": -0.082, "shoulder_y": -0.106, "crest_y": -0.118,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.018, 0.007)},
], flat_group="FBGrowMid")

glacier_cluster("FB_GrowFront", [
    {"points_xz": [(1.195, 0.358), (1.375, 0.344), (1.565, 0.362), (1.495, 0.392), (1.265, 0.388)],
     "base_y": 0.082, "shoulder_y": 0.106, "crest_y": 0.118,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.018, 0.006)},
    {"points_xz": [(1.195, 0.358), (1.375, 0.344), (1.565, 0.362), (1.495, 0.392), (1.265, 0.388)],
     "base_y": -0.082, "shoulder_y": -0.106, "crest_y": -0.118,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.018, 0.006)},
], flat_group="FBGrowFront")

glacier_shard(
    "FB_Shard1", [(0.245, 0.228), (0.375, 0.212), (0.565, 0.230), (0.515, 0.258), (0.295, 0.254)],
    0.090, 0.112, 0.125, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.014, 0.004), flat_group="FBShard1",
)
glacier_shard(
    "FB_Shard2", [(1.145, 0.305), (1.305, 0.288), (1.495, 0.316), (1.435, 0.352), (1.205, 0.344)],
    0.091, 0.114, 0.128, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.016, 0.005), flat_group="FBShard2",
)
glacier_shard(
    "FB_Shard3", [(0.245, 0.228), (0.375, 0.212), (0.565, 0.230), (0.515, 0.258), (0.295, 0.254)],
    -0.090, -0.112, -0.125, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.014, 0.004), flat_group="FBShard3",
)
glacier_shard(
    "FB_Shard4", [(1.145, 0.305), (1.305, 0.288), (1.495, 0.316), (1.435, 0.352), (1.205, 0.344)],
    -0.091, -0.114, -0.128, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.016, 0.005), flat_group="FBShard4",
)

result = finish_master(hand)
result["gap_moves"] = gap_moves
