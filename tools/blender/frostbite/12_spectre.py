"""Frostbite Prowler (Spectre) v01: Legendary sculpted cryo-armor remodel."""

from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

GUN = "Spectre"
VERSION = globals().get("VERSION", "v02")
exec((Path(bpy.data.filepath).parents[4] / "tools/blender/frostbite/frost_lib.py").read_text(encoding="utf-8"))

replace("Handguard", "Stock", "Suppressor", "Neon")

# ---------------------------------------------------------------- retained stock + gap sweep
for name in ("Receiver", "Pins", "CharmLoop", "ChargingHandle", "Bolt",
             "FireSelector", "Trigger", "Grip", "Sights"):
    dress(name)
dress("Mag", slots={"Dark": GRIP, "Body": ARMOR, "Panel": OBSIDIAN, "Accent": FROSTSTEEL})

_flat = {}
exec((ROOT / "tools/blender/export_roblox_flat.py").read_text(encoding="utf-8"), _flat)
_flat["resolve_coplanar"]([native("FireSelector")])
dress("Neon", copy_name="FB_SightNeon", keep=lambda island: limits(island, 0)[0] > 0.5)
dress("Stock", copy_name="FB_StockFrame", keep=lambda island: limits(island, 0)[0] > -0.98)
dress("Suppressor", copy_name="FB_BarrelStub", keep=lambda island: limits(island, 0)[1] < 1.27)


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
gap_moves = {
    "grip_front_top": nudge(native("Grip"), lambda p: p.x > 0.11 and p.z > 0.118, (0.022, 0, 0)),
    "grip_top": nudge(native("Grip"), lambda p: p.z > 0.125 and p.x > -0.17, (0, 0, 0.020)),
    "buffer_mount": nudge(bpy.data.objects["FB_StockFrame"], lambda p: p.x > -0.325, (0.014, 0, 0),
                          lambda lo, hi: abs(lo.x + 0.43) < 0.01 and abs(hi.x + 0.322) < 0.01),
    "barrel_stub": nudge(bpy.data.objects["FB_BarrelStub"], lambda p: p.x < 1.14, (-0.030, 0, 0)),
    "front_sight_base": nudge(SIGHTS, lambda p: p.z < 0.471, (0, 0, -0.020),
                              lambda lo, hi: lo.x < 0.97 and hi.x > 1.06 and hi.z < 0.5),
    "front_sight_post": nudge(SIGHTS, lambda p: p.z < 0.487, (0, 0, -0.020),
                              lambda lo, hi: lo.x > 1.01 and hi.x < 1.025 and lo.z > 0.48 and hi.z < 0.53),
    "front_sight_wings": nudge(SIGHTS, lambda p: p.z < 0.48, (0, 0, -0.012),
                               lambda lo, hi: lo.x > 1.0 and hi.x < 1.035 and hi.y > 0.044),
    "rear_sight_post": nudge(SIGHTS, lambda p: p.z < 0.43, (0, 0, -0.010),
                             lambda lo, hi: lo.x < -0.06 and hi.x > -0.045 and lo.z < 0.43),
}

# ---------------------------------------------------------------- handguard shroud (sleeves x .650 over receiver)
hand = folded("FB_Handguard", (
    (0.650, 0.230, 0.473, 0.090, 0.443, 0.260, 0.056),
    (1.100, 0.230, 0.473, 0.090, 0.443, 0.260, 0.056),
    (1.146, 0.282, 0.470, 0.084, 0.440, 0.300, 0.052),
), ARMOR, bevel=0.004)
recess(hand, "FB_HandleSlotCut", [(0.637, 0.312), (0.716, 0.312), (0.716, 0.422), (0.637, 0.422)],
       0.062, 0.15, role=OBSIDIAN)
recess(hand, "FB_HandlePocketCut", [(0.637, 0.312), (0.730, 0.312), (0.730, 0.424), (0.637, 0.424)],
       -0.060, 0.066, role=OBSIDIAN)
# Fore chasm starts at x .842, leaving stock CharmLoop (x .784..816, z .243..285, left chamfer) cleanly open
FORE_CHASM = [(0.842, 0.292), (1.078, 0.284), (1.112, 0.322), (1.088, 0.424), (0.855, 0.424), (0.838, 0.372)]
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(hand, f"FB_ForeChasm_{label}", FORE_CHASM, 0.082 * sign, 0.15 * sign, role=OBSIDIAN)

# ---------------------------------------------------------------- sculpted wing armor
# Left upper receiver respects ChargingHandle slot (x .155..716, z .305..422) & FireSelector (x .18..25, z .21..295);
# Right side respects ejection port Bolt (x .23..52, z .35..41).
for sign, label in ((1, "Left"), (-1, "Right")):
    armor_plate(
        f"FB_RecArmorRear_{label}",
        [(-0.275, 0.278), (0.125, 0.278), (0.140, 0.398), (-0.235, 0.398), (-0.295, 0.345)],
        0.076 * sign, 0.098 * sign, 0.105 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.007,
    )
    armor_plate(
        f"FB_LowerSkirt_{label}",
        [(-0.145, 0.148), (0.165, 0.148), (0.165, 0.192), (-0.155, 0.192)]
        if sign == 1 else
        [(-0.145, 0.152), (0.355, 0.152), (0.375, 0.254), (-0.155, 0.252)],
        0.074 * sign, 0.095 * sign, 0.101 * sign, ARMOR, rim_role=FROSTSTEEL, inset=0.007,
    )
    armor_plate(
        f"FB_BridgeWing_{label}",
        [(0.732, 0.318), (0.915, 0.338), (0.960, 0.420), (0.742, 0.426)],
        0.082 * sign, 0.106 * sign, 0.114 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.007,
    )
    armor_plate(
        f"FB_ForeJawFront_{label}",
        [(0.965, 0.276), (1.078, 0.285), (1.132, 0.332), (1.095, 0.422), (0.985, 0.415)],
        0.082 * sign, 0.108 * sign, 0.116 * sign, ARMOR, rim_role=FROSTSTEEL, inset=0.007,
    )
    armor_plate(
        f"FB_ForeChinPlate_{label}",
        [(0.842, 0.242), (1.055, 0.240), (1.115, 0.275), (1.045, 0.296), (0.842, 0.290)],
        0.076 * sign, 0.099 * sign, 0.106 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.006,
    )

# ---------------------------------------------------------------- cryo-core bay & crystals
# On Left: core bay sits on the lower receiver ahead of FireSelector (x .265..670, z .148..258);
# On Right: core bay sits on upper receiver behind Bolt (x -.22..21, z .278..388) + mid-lower pocket!
for sign, label in ((1, "Left"), (-1, "Right")):
    bay_poly = (
        [(0.265, 0.148), (0.655, 0.148), (0.675, 0.195), (0.655, 0.256), (0.275, 0.256), (0.255, 0.202)]
        if sign == 1 else
        [(0.245, 0.148), (0.655, 0.148), (0.675, 0.195), (0.655, 0.256), (0.255, 0.256), (0.235, 0.202)]
    )
    bay = side(f"FB_CoreBay_{label}", bay_poly, 0.072 * sign, 0.094 * sign, ARMOR)
    recess(bay, f"FB_CoreChasm_{label}",
           [(0.285, 0.160), (0.635, 0.160), (0.652, 0.202), (0.632, 0.244), (0.295, 0.244), (0.278, 0.202)],
           0.080 * sign, 0.125 * sign, role=OBSIDIAN)
    swept_rib(f"FB_CoreFissure_{label}", [
        (0.295, 0.084 * sign, 0.202, 0.005, 0.006),
        (0.425, 0.085 * sign, 0.198, 0.006, 0.007),
        (0.555, 0.085 * sign, 0.206, 0.006, 0.007),
        (0.630, 0.084 * sign, 0.202, 0.005, 0.006),
    ], CRYO_GLOW, flat_group="FBCoreFissure")
    swept_rib(f"FB_UpperSeam_{label}", [
        (-0.215, 0.085 * sign, 0.398, 0.005, 0.005),
        (-0.045, 0.085 * sign, 0.402, 0.005, 0.006),
        (0.115, 0.085 * sign, 0.398, 0.005, 0.005),
    ], CRYO_GLOW, flat_group="FBUpperSeam")
    swept_rib(f"FB_ForeSeam_{label}", [
        (0.848, 0.090 * sign, 0.335, 0.005, 0.007),
        (0.965, 0.091 * sign, 0.352, 0.006, 0.008),
        (1.075, 0.090 * sign, 0.365, 0.005, 0.006),
    ], CRYO_GLOW, flat_group="FBForeSeam")
    glacier_cluster(f"FB_CoreCrystals_{label}", [
        {"points_xz": [(0.295, 0.195), (0.375, 0.172), (0.455, 0.188), (0.415, 0.232), (0.325, 0.226)],
         "base_y": 0.080 * sign, "shoulder_y": 0.102 * sign, "crest_y": 0.115 * sign, "ridge_bias": (-0.012, 0.004)},
        {"points_xz": [(0.505, 0.192), (0.585, 0.174), (0.642, 0.198), (0.598, 0.236), (0.518, 0.228)],
         "base_y": 0.080 * sign, "shoulder_y": 0.104 * sign, "crest_y": 0.117 * sign,
         "roles": (ICE_MID, ICE_MID, ICE_BRIGHT), "ridge_bias": (-0.012, 0.004)},
    ])
    glacier_cluster(f"FB_ForeCrystals_{label}", [
        {"points_xz": [(0.848, 0.312), (0.945, 0.294), (1.065, 0.325), (1.025, 0.395), (0.875, 0.382)],
         "base_y": 0.080 * sign, "shoulder_y": 0.108 * sign, "crest_y": 0.122 * sign, "ridge_bias": (-0.016, 0.006)},
    ])

glacier_shard(
    "FB_CoreHeart_Left",
    [(0.452, 0.204), (0.484, 0.186), (0.516, 0.202), (0.486, 0.222)],
    0.084, 0.110, 0.122,
    roles=(GLOW_WHITE, GLOW_WHITE, GLOW_WHITE),
    ridge_bias=(-0.004, 0.002),
    flat_group="FBCoreHeart",
)

# ---------------------------------------------------------------- glacial suppressor can (1.236..1.904, z .353)
can = prism_along("FB_SuppressorCan", (1.236, 0, 0.353), (1, 0, 0), [
    (0.000, 0.058), (0.014, 0.084), (0.150, 0.084), (0.158, 0.078), (0.186, 0.078), (0.200, 0.096),
    (0.598, 0.096), (0.606, 0.090), (0.646, 0.090), (0.668, 0.068), (0.668, 0.030), (0.635, 0.030),
], ARMOR)
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(can, f"FB_CanVent_{label}", [(1.465, 0.328), (1.525, 0.376), (1.795, 0.376), (1.735, 0.328)],
           0.058 * sign, 0.115 * sign, role=OBSIDIAN)
    armor_plate(
        f"FB_CanFin_{label}",
        [(1.445, 0.304), (1.645, 0.290), (1.835, 0.314), (1.775, 0.352), (1.485, 0.348)],
        0.063 * sign, 0.096 * sign, 0.102 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.006,
    )
prism_along("FB_MuzzleGlow", (1.391, 0, 0.353), (1, 0, 0), [(0, 0.0825), (0.034, 0.0825)],
            CRYO_GLOW)["flat_group"] = "FBMuzzleGlow"
glacier_cluster("FB_MuzzleIce", [
    {"points_xz": [(1.255, 0.280), (1.395, 0.252), (1.545, 0.288), (1.435, 0.314)],
     "base_y": 0.024, "shoulder_y": -0.022, "crest_y": -0.034, "ridge_bias": (-0.014, -0.008)},
    {"points_xz": [(1.255, 0.280), (1.395, 0.252), (1.545, 0.288), (1.435, 0.314)],
     "base_y": -0.024, "shoulder_y": 0.022, "crest_y": 0.034, "ridge_bias": (-0.014, -0.008)},
])

# ---------------------------------------------------------------- swept glacial wing stock
butt = side("FB_StockButt", [
    (-0.925, 0.412), (-1.040, 0.436), (-1.068, 0.420), (-1.074, 0.374), (-1.056, 0.358),
    (-1.050, 0.200), (-1.074, 0.183), (-1.074, 0.145), (-1.058, 0.129), (-1.058, -0.100),
    (-1.036, -0.128), (-0.925, -0.128),
], -0.078, 0.078, ARMOR, bevel=0.007)
STOCK_REC = [(-0.956, -0.068), (-1.036, -0.068), (-1.036, 0.326), (-1.020, 0.342), (-0.956, 0.342)]
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(butt, f"FB_ButtRecess_{label}", STOCK_REC, 0.070 * sign, 0.12 * sign, role=OBSIDIAN)
    armor_plate(
        f"FB_StockWingCheek_{label}",
        [(-0.940, 0.366), (-1.044, 0.366), (-1.056, 0.414), (-1.040, 0.428), (-0.940, 0.406)],
        0.066 * sign, 0.084 * sign, 0.090 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.006,
    )
    armor_plate(
        f"FB_StockFrameWing_{label}",
        [(-0.620, 0.274), (-0.475, 0.274), (-0.435, 0.376), (-0.595, 0.376)],
        0.062 * sign, 0.076 * sign, 0.082 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.006,
    )
for sign, label in ((1, "L"), (-1, "R")):
    glacier_cluster(f"FB_StockCrystals_{label}", [
        {"points_xz": [(-1.032, -0.045), (-0.965, 0.035), (-0.955, 0.285), (-1.028, 0.205)],
         "base_y": 0.068 * sign, "shoulder_y": 0.086 * sign, "crest_y": 0.098 * sign, "ridge_bias": (0.010, 0.006)},
    ])
swept_rib("FB_StockGlow", [
    (-1.015, 0.0, -0.035, 0.058, 0.010),
    (-1.000, 0.0,  0.125, 0.058, 0.010),
    (-0.985, 0.0,  0.285, 0.058, 0.010),
], CRYO_GLOW, flat_group="FBStockGlow")

# ---------------------------------------------------------------- sculpted frost magazine (bone Mag)
for sign, label in ((1, "Left"), (-1, "Right")):
    armor_plate(
        f"FB_MagCowl_{label}",
        [(0.645, -0.215), (0.765, -0.205), (0.798, -0.315), (0.665, -0.325)],
        0.044 * sign, 0.063 * sign, 0.068 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.005, bone="Mag",
    )
    swept_rib(f"FB_MagGlow_{label}", [
        (0.675, 0.053 * sign, -0.075, 0.005, 0.006),
        (0.715, 0.053 * sign, -0.205, 0.005, 0.007),
        (0.762, 0.053 * sign, -0.338, 0.005, 0.006),
    ], CRYO_GLOW, bone="Mag", flat_group="FBMagGlow")

# ---------------------------------------------------------------- animated flat_groups (Root, single-mat)
glacier_cluster("FB_GrowRear", [
    {"points_xz": [(-0.185, 0.335), (-0.035, 0.322), (0.115, 0.340), (0.065, 0.378), (-0.135, 0.372)],
     "base_y": 0.082, "shoulder_y": 0.102, "crest_y": 0.114,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.016, 0.005)},
    {"points_xz": [(-0.185, 0.335), (-0.035, 0.322), (0.115, 0.340), (0.065, 0.378), (-0.135, 0.372)],
     "base_y": -0.082, "shoulder_y": -0.102, "crest_y": -0.114,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.016, 0.005)},
], flat_group="FBGrowRear")

glacier_cluster("FB_GrowMid", [
    {"points_xz": [(0.745, 0.368), (0.875, 0.354), (1.015, 0.372), (0.965, 0.408), (0.785, 0.402)],
     "base_y": 0.084, "shoulder_y": 0.106, "crest_y": 0.118,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.016, 0.005)},
    {"points_xz": [(0.745, 0.368), (0.875, 0.354), (1.015, 0.372), (0.965, 0.408), (0.785, 0.402)],
     "base_y": -0.084, "shoulder_y": -0.106, "crest_y": -0.118,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.016, 0.005)},
], flat_group="FBGrowMid")

glacier_cluster("FB_GrowFront", [
    {"points_xz": [(0.865, 0.382), (0.985, 0.370), (1.105, 0.386), (1.055, 0.418), (0.905, 0.412)],
     "base_y": 0.084, "shoulder_y": 0.106, "crest_y": 0.118,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.014, 0.005)},
    {"points_xz": [(0.865, 0.382), (0.985, 0.370), (1.105, 0.386), (1.055, 0.418), (0.905, 0.412)],
     "base_y": -0.084, "shoulder_y": -0.106, "crest_y": -0.118,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.014, 0.005)},
], flat_group="FBGrowFront")

glacier_shard(
    "FB_Shard1", [(0.305, 0.196), (0.435, 0.180), (0.615, 0.198), (0.565, 0.228), (0.355, 0.222)],
    0.088, 0.110, 0.122, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.014, 0.004), flat_group="FBShard1",
)
glacier_shard(
    "FB_Shard2", [(0.865, 0.312), (0.965, 0.296), (1.095, 0.322), (1.045, 0.362), (0.905, 0.352)],
    0.091, 0.114, 0.127, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.014, 0.004), flat_group="FBShard2",
)
glacier_shard(
    "FB_Shard3", [(0.305, 0.196), (0.435, 0.180), (0.615, 0.198), (0.565, 0.228), (0.355, 0.222)],
    -0.088, -0.110, -0.122, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.014, 0.004), flat_group="FBShard3",
)
glacier_shard(
    "FB_Shard4", [(0.865, 0.312), (0.965, 0.296), (1.095, 0.322), (1.045, 0.362), (0.905, 0.352)],
    -0.091, -0.114, -0.127, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.014, 0.004), flat_group="FBShard4",
)

result = finish_master(hand)
result["gap_moves"] = gap_moves
