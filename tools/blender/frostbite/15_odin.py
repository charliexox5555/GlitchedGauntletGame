"""Frostbite Mauler (Odin) v01: Legendary sculpted cryo-armor remodel.

Stock CharmLoop kept UNSKINNED at owner's Studio location; every Frostbite part stays 0.09+ clear of CHARM.
"""

from pathlib import Path

import bpy

GUN = "Odin"
VERSION = globals().get("VERSION", "v02")
exec((Path(bpy.data.filepath).parents[4] / "tools/blender/frostbite/frost_lib.py").read_text(encoding="utf-8"))

CHARM = Vector((1.18, 0.126, 0.435))


def near(value, target, tolerance=0.003):
    return abs(value - target) < tolerance


def is_island(island, lo, hi):
    return all(near(limits(island, a)[0], lo[a]) and near(limits(island, a)[1], hi[a]) for a in range(3))


MAIN = ((-0.168, -0.1, 0.157), (0.788, 0.1, 0.571))
HANDGUARD = ((1.44, -0.1, 0.175), (2.272, 0.1, 0.501))

# ---------------------------------------------------------------- retained stock + gap sweep
hand = dress("Receiver", copy_name="FB_Handguard", keep=lambda i: is_island(i, *HANDGUARD))
receiver = dress("Receiver", keep=lambda i: not (is_island(i, *HANDGUARD)
                                                  or (near(limits(i, 0)[0], 1.102) and abs(limits(i, 1)[0]) > 0.09)))
dress("Neon", keep=lambda i: limits(i, 0)[1] < 0.5)
dress("Barrel", keep=lambda i: limits(i, 0)[0] < 3.02)
dress("Stock", keep=lambda i: limits(i, 0)[0] > -1.2)
dress("Pins", keep=lambda i: not (0.63 < limits(i, 0)[0] < 0.64 and limits(i, 1)[0] > 0))
for name in ("Sights", "Grip", "FeedCover", "FeedBelt", "ChargingHandle", "Bolt", "Trigger"):
    dress(name)
dress("AmmoBox", slots={"Panel": ARMOR, "Dark": GRIP, "Body": ARMOR, "Accent": FROSTSTEEL})
_flat = {}
exec((ROOT / "tools/blender/export_roblox_flat.py").read_text(encoding="utf-8"), _flat)
for _name in ("FeedBelt", "FeedCover"):
    _flat["resolve_coplanar"]([native(_name)])


def nudge(obj, box, pick, delta):
    matrix = obj.matrix_world
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.transform(matrix)
    moved = 0
    for island in list(components(bm)):
        if box is not None and not is_island(island, *box):
            continue
        for vert in island:
            if pick(vert.co):
                vert.co += Vector(delta)
                moved += 1
    bm.transform(matrix.inverted())
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    return moved


moves = {
    "handguard_rear": nudge(hand, None, lambda p: p.x < 1.445, (-0.020, 0, 0)),
    "feed_section_rear": nudge(receiver, ((0.788, -0.1, 0.133), (1.452, 0.1, 0.49)), lambda p: p.x < 0.79, (-0.020, 0, 0)),
    "rear_cap_front": nudge(receiver, ((-0.28, -0.094, 0.192), (-0.157, 0.094, 0.565)), lambda p: p.x > -0.16, (0.010, 0, 0)),
    "trigger_guard_top": nudge(receiver, ((0.175, -0.032, 0.0), (0.455, 0.032, 0.16)), lambda p: p.z > 0.155, (0, 0, 0.020)),
    "rail_foot": nudge(receiver, ((-0.1, -0.036, 0.57), (0.78, 0.036, 0.59)), lambda p: p.z < 0.575, (0, 0, -0.020)),
    "rail_teeth": nudge(receiver, None, lambda p: abs(p.z - 0.589) < 0.0006 and abs(p.y) > 0.037, (0, 0, -0.019)),
    "lug_top": nudge(receiver, ((1.855, -0.014, 0.09), (2.03, 0.014, 0.179)), lambda p: p.z > 0.17, (0, 0, 0.020)),
    "grip_top": nudge(native("Grip"), None, lambda p: p.z > 0.155, (0, 0, 0.020)),
    "pins_left": nudge(native("Pins"), None, lambda p: 0 < p.y < 0.0985, (0, -0.020, 0)),
    "pins_right": nudge(native("Pins"), None, lambda p: -0.0985 < p.y < 0, (0, 0.020, 0)),
    "adapter_front": nudge(native("Stock"), ((-0.385, -0.074, 0.168), (-0.273, 0.074, 0.472)), lambda p: p.x < -0.38, (-0.020, 0, 0)),
    "adapter_rear": nudge(native("Stock"), ((-0.385 - 0.020, -0.074, 0.168), (-0.273, 0.074, 0.472)), lambda p: p.x > -0.28, (0.023, 0, 0)),
    "barrel_rear": nudge(native("Barrel"), ((2.26, -0.078, 0.291), (3.03, 0.078, 0.451)), lambda p: p.x < 2.265, (-0.020, 0, 0)),
    "barrel_ring_rear": nudge(native("Barrel"), ((2.496, -0.097, 0.271), (2.604, 0.097, 0.471)), lambda p: p.x < 2.5, (-0.020, 0, 0)),
    "front_sight_base": nudge(native("Sights"), ((2.383, -0.04, 0.505), (2.482, 0.04, 0.6)), lambda p: p.z < 0.51, (0, 0, -0.020)),
    "front_sight_hood": nudge(native("Sights"), ((2.408, -0.038, 0.598), (2.457, 0.038, 0.68)), lambda p: p.z < 0.6, (0, 0, -0.020)),
    "front_sight_post": nudge(native("Sights"), ((2.427, -0.006, 0.597), (2.438, 0.006, 0.65)), lambda p: p.z < 0.6, (0, 0, -0.020)),
    "front_sight_dot": nudge(native("Sights"), ((2.424, -0.003, 0.631), (2.428, 0.003, 0.638)), lambda p: p.x > 2.426, (0.006, 0, 0)),
    "rear_sight_feet": nudge(native("Sights"), ((0.011, -0.062, 0.564), (0.031, 0.062, 0.722)), lambda p: p.z < 0.57, (0, 0, -0.020)),
}
moves["cap_neon"] = (nudge(native("Neon"), None, lambda p: 0 < p.y < 0.0895, (0, -0.0075, 0))
                     + nudge(native("Neon"), None, lambda p: -0.0895 < p.y < 0, (0, 0.0075, 0)))

# ---------------------------------------------------------------- handguard chasms & wing armor
HFIELD = [(1.480, 0.236), (1.494, 0.236), (1.494, 0.222), (1.508, 0.222), (1.508, 0.208), (2.050, 0.208),
          (2.110, 0.262), (2.110, 0.392), (2.096, 0.404), (1.494, 0.404), (1.480, 0.390)]
# Main receiver Left charging slot x -.116..35, z .306..364 -> keep core bay at x .39..75, z .21..39 and rear brow z .385..530;
# Right ejection port Bolt x .34..59, z .314..386 -> keep Right core bay & brow clear of z .305..400 around x .32..62!
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(hand, f"FB_ForeChasm_{label}", HFIELD, 0.084 * sign, 0.15 * sign, role=OBSIDIAN)
    armor_plate(
        f"FB_RecArmorUpper_{label}",
        [(-0.115, 0.382), (0.295, 0.382), (0.335, 0.420), (0.255, 0.538), (-0.115, 0.538)],
        0.092 * sign, 0.114 * sign, 0.122 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.008,
    )
    armor_plate(
        f"FB_RecArmorSkirt_{label}",
        [(-0.125, 0.175), (0.355, 0.175), (0.395, 0.275), (-0.125, 0.285)],
        0.092 * sign, 0.112 * sign, 0.119 * sign, ARMOR, rim_role=FROSTSTEEL, inset=0.008,
    )
    # Feed section plate (Right x .82..1.40; Left keeps clear >= .11 behind CHARM (1.18, .126, .435))
    armor_plate(
        f"FB_FeedWing_{label}",
        ([0.825, 1.045, 1.045, 0.825] if False else
         ([(0.825, 0.185), (1.035, 0.185), (1.065, 0.315), (0.825, 0.315)] if sign == 1
          else [(0.825, 0.185), (1.385, 0.185), (1.425, 0.425), (0.825, 0.425)])),
        0.092 * sign, 0.116 * sign, 0.124 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.008,
    )
    armor_plate(
        f"FB_ForeJawFront_{label}",
        [(1.945, 0.215), (2.155, 0.228), (2.255, 0.285), (2.215, 0.415), (2.015, 0.432), (1.925, 0.395)],
        0.092 * sign, 0.118 * sign, 0.126 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.008,
    )
    armor_plate(
        f"FB_ForeChinPlate_{label}",
        [(1.480, 0.195), (1.965, 0.195), (2.085, 0.235), (1.945, 0.272), (1.480, 0.265)],
        0.090 * sign, 0.114 * sign, 0.121 * sign, ARMOR, rim_role=FROSTSTEEL, inset=0.008,
    )

# ---------------------------------------------------------------- cryo-core bay & crystals (x .39..75 Left; Right z .192..295 clears BoxFlange)
for sign, label in ((1, "Left"), (-1, "Right")):
    bay_poly = (
        [(0.405, 0.210), (0.745, 0.210), (0.768, 0.285), (0.745, 0.455), (0.415, 0.455), (0.395, 0.330)]
        if sign == 1 else
        [(0.345, 0.194), (0.745, 0.194), (0.765, 0.242), (0.745, 0.295), (0.355, 0.295), (0.338, 0.244)]
    )
    bay = side(f"FB_CoreBay_{label}", bay_poly, 0.088 * sign, 0.112 * sign, ARMOR)
    chasm_poly = (
        [(0.422, 0.224), (0.728, 0.224), (0.748, 0.288), (0.728, 0.438), (0.432, 0.438), (0.415, 0.330)]
        if sign == 1 else
        [(0.365, 0.204), (0.728, 0.204), (0.746, 0.244), (0.728, 0.285), (0.372, 0.285), (0.356, 0.244)]
    )
    recess(bay, f"FB_CoreChasm_{label}", chasm_poly, 0.098 * sign, 0.15 * sign, role=OBSIDIAN)
    fz = (0.332, 0.326, 0.338, 0.334) if sign == 1 else (0.246, 0.242, 0.250, 0.246)
    swept_rib(f"FB_CoreFissure_{label}", [
        (0.435, 0.108 * sign, fz[0], 0.006, 0.007),
        (0.535, 0.109 * sign, fz[1], 0.007, 0.008),
        (0.635, 0.109 * sign, fz[2], 0.007, 0.008),
        (0.718, 0.108 * sign, fz[3], 0.006, 0.007),
    ], CRYO_GLOW, flat_group="FBCoreFissure")
    swept_rib(f"FB_UpperSeam_{label}", [
        (-0.105, 0.104 * sign, 0.515, 0.006, 0.006),
        (0.085, 0.104 * sign, 0.520, 0.006, 0.006),
        (0.255, 0.104 * sign, 0.515, 0.006, 0.006),
    ], CRYO_GLOW, flat_group="FBUpperSeam")
    swept_rib(f"FB_ForeSeam_{label}", [
        (1.505, 0.092 * sign, 0.295, 0.006, 0.008),
        (1.755, 0.093 * sign, 0.312, 0.007, 0.009),
        (1.985, 0.092 * sign, 0.330, 0.006, 0.008),
    ], CRYO_GLOW, flat_group="FBForeSeam")

    dz = 0.0 if sign == 1 else -0.090
    glacier_cluster(f"FB_CoreCrystals_{label}", [
        {"points_xz": [(0.428, 0.305 + dz), (0.505, 0.285 + dz), (0.578, 0.302 + dz),
                       (0.545, 0.365 + dz), (0.455, 0.358 + dz)],
         "base_y": 0.097 * sign, "shoulder_y": 0.120 * sign, "crest_y": 0.135 * sign, "ridge_bias": (-0.014, 0.005)},
        {"points_xz": [(0.605, 0.305 + dz), (0.675, 0.288 + dz), (0.735, 0.312 + dz),
                       (0.695, 0.368 + dz), (0.618, 0.360 + dz)],
         "base_y": 0.097 * sign, "shoulder_y": 0.122 * sign, "crest_y": 0.137 * sign,
         "roles": (ICE_MID, ICE_MID, ICE_BRIGHT), "ridge_bias": (-0.012, 0.005)},
    ])
    glacier_cluster(f"FB_ForeCrystals_{label}", [
        {"points_xz": [(1.495, 0.265), (1.625, 0.238), (1.765, 0.275), (1.715, 0.358), (1.545, 0.345)],
         "base_y": 0.091 * sign, "shoulder_y": 0.118 * sign, "crest_y": 0.134 * sign, "ridge_bias": (-0.020, 0.008)},
        {"points_xz": [(1.815, 0.272), (1.945, 0.248), (2.095, 0.288), (2.025, 0.365), (1.845, 0.350)],
         "base_y": 0.091 * sign, "shoulder_y": 0.120 * sign, "crest_y": 0.136 * sign,
         "roles": (ICE_MID, ICE_MID, ICE_BRIGHT), "ridge_bias": (-0.018, 0.006)},
    ])

glacier_shard(
    "FB_CoreHeart_Left",
    [(0.558, 0.335), (0.596, 0.315), (0.634, 0.332), (0.602, 0.356)],
    0.100, 0.130, 0.144,
    roles=(GLOW_WHITE, GLOW_WHITE, GLOW_WHITE),
    ridge_bias=(-0.005, 0.002),
    flat_group="FBCoreHeart",
)

glacier_cluster("FB_ForeKeel", [
    {"points_xz": [(1.545, 0.165), (1.715, 0.125), (1.845, 0.168), (1.775, 0.195), (1.605, 0.185)],
     "base_y": 0.028, "shoulder_y": -0.026, "crest_y": -0.038, "ridge_bias": (-0.016, -0.010)},
    {"points_xz": [(1.545, 0.165), (1.715, 0.125), (1.845, 0.168), (1.775, 0.195), (1.605, 0.185)],
     "base_y": -0.028, "shoulder_y": 0.026, "crest_y": 0.038, "ridge_bias": (-0.016, -0.010)},
])

# ---------------------------------------------------------------- ammo box cryo carapace & flange (bone AmmoBox)
for sign, label in ((1, "Left"), (-1, "Right")):
    armor_plate(
        f"FB_BoxCowl_{label}",
        [(0.650, -0.320), (1.225, -0.320), (1.242, -0.095), (1.035, -0.085), (0.650, -0.105)],
        0.148 * sign, 0.170 * sign, 0.178 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.008, bone="AmmoBox",
    )
    swept_rib(f"FB_BoxGlow_{label}", [
        (0.765, 0.164 * sign, -0.275, 0.006, 0.008),
        (0.955, 0.165 * sign, -0.205, 0.007, 0.009),
        (1.145, 0.164 * sign, -0.135, 0.006, 0.008),
    ], CRYO_GLOW, bone="AmmoBox", flat_group="FBMagGlow")
    glacier_cluster(f"FB_BoxCrystals_{label}", [
        {"points_xz": [(0.745, -0.245), (0.945, -0.275), (1.165, -0.225), (1.095, -0.145), (0.815, -0.155)],
         "base_y": 0.156 * sign, "shoulder_y": 0.180 * sign, "crest_y": 0.194 * sign,
         "ridge_bias": (-0.020, 0.008)},
    ], bone="AmmoBox")
    side(f"FB_BoxFlange_{label}", [(0.585, 0.100), (1.305, 0.100), (1.305, 0.160), (1.293, 0.172),
                                   (0.597, 0.172), (0.585, 0.160)], 0.108 * sign, 0.118 * sign, OBSIDIAN, bone="AmmoBox")
side("FB_BoxFlange_Rear", [(0.585, 0.100), (0.597, 0.100), (0.597, 0.145), (0.585, 0.145)],
     -0.113, 0.113, OBSIDIAN, bone="AmmoBox")

# ---------------------------------------------------------------- swept glacial heavy butt & frame wing
butt = side("FB_StockButt", [
    (-0.940, 0.502), (-1.160, 0.536), (-1.195, 0.518), (-1.205, 0.470), (-1.185, 0.452),
    (-1.180, 0.240), (-1.205, 0.222), (-1.205, 0.172), (-1.185, 0.155), (-1.185, -0.190),
    (-1.160, -0.244), (-0.965, -0.244), (-0.940, -0.215),
], -0.090, 0.090, ARMOR, bevel=0.008)
STOCK_REC = [(-0.990, -0.155), (-1.148, -0.155), (-1.158, 0.415), (-1.135, 0.438), (-0.990, 0.438)]
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(butt, f"FB_ButtRecess_{label}", STOCK_REC, 0.082 * sign, 0.12 * sign, role=OBSIDIAN)
    armor_plate(
        f"FB_StockWingCheek_{label}",
        [(-0.975, 0.455), (-1.150, 0.455), (-1.170, 0.512), (-1.148, 0.528), (-0.975, 0.502)],
        0.078 * sign, 0.098 * sign, 0.106 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.008,
    )
    armor_plate(
        f"FB_StockFrameWing_{label}",
        [(-0.845, 0.285), (-0.615, 0.285), (-0.565, 0.412), (-0.805, 0.412)],
        0.068 * sign, 0.084 * sign, 0.092 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.007,
    )
for sign, label in ((1, "L"), (-1, "R")):
    glacier_cluster(f"FB_StockCrystals_{label}", [
        {"points_xz": [(-1.138, -0.105), (-1.025, -0.005), (-1.015, 0.355), (-1.132, 0.255)],
         "base_y": 0.080 * sign, "shoulder_y": 0.102 * sign, "crest_y": 0.116 * sign, "ridge_bias": (0.012, 0.008)},
    ])
swept_rib("FB_StockGlow", [
    (-1.118, 0.0, -0.075, 0.068, 0.011),
    (-1.095, 0.0,  0.145, 0.068, 0.011),
    (-1.072, 0.0,  0.365, 0.068, 0.011),
], CRYO_GLOW, flat_group="FBStockGlow")

# ---------------------------------------------------------------- heavy ported cryo brake (3.005..3.365, z .371)
AXIS_Z = 0.371
brake = prism_along("FB_Brake", (3.005, 0, AXIS_Z), (1, 0, 0), [
    (0.000, 0.084), (0.012, 0.098), (0.062, 0.098), (0.062, 0.090), (0.104, 0.090), (0.104, 0.104),
    (0.296, 0.104), (0.320, 0.092), (0.344, 0.084), (0.360, 0.084), (0.360, 0.046), (0.330, 0.046),
], FROSTSTEEL)
for k, x in enumerate((3.150, 3.215)):
    recess(brake, f"FB_BrakePort_{k + 1}", [(x, AXIS_Z - 0.017), (x + 0.036, AXIS_Z - 0.017),
                                            (x + 0.036, AXIS_Z + 0.017), (x, AXIS_Z + 0.017)], -0.2, 0.2, role=OBSIDIAN)
prism_along("FB_MuzzleGlow", (3.065, 0, AXIS_Z), (1, 0, 0), [(0, 0.0955), (0.046, 0.0955)],
            CRYO_GLOW)["flat_group"] = "FBMuzzleGlow"
glacier_cluster("FB_MuzzleIce", [
    {"points_xz": [(3.025, 0.275), (3.165, 0.238), (3.325, 0.285), (3.225, 0.320)],
     "base_y": 0.026, "shoulder_y": -0.024, "crest_y": -0.038, "ridge_bias": (-0.016, -0.008)},
    {"points_xz": [(3.025, 0.275), (3.165, 0.238), (3.325, 0.285), (3.225, 0.320)],
     "base_y": -0.026, "shoulder_y": 0.024, "crest_y": 0.038, "ridge_bias": (-0.016, -0.008)},
])

# ---------------------------------------------------------------- animated flat_groups (Root, single-mat)
glacier_cluster("FB_GrowRear", [
    {"points_xz": [(-0.085, 0.442), (0.085, 0.428), (0.255, 0.445), (0.195, 0.482), (-0.025, 0.476)],
     "base_y": 0.096, "shoulder_y": 0.120, "crest_y": 0.134,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.018, 0.006)},
    {"points_xz": [(-0.085, 0.442), (0.085, 0.428), (0.255, 0.445), (0.195, 0.482), (-0.025, 0.476)],
     "base_y": -0.096, "shoulder_y": -0.120, "crest_y": -0.134,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.018, 0.006)},
], flat_group="FBGrowRear")

glacier_cluster("FB_GrowMid", [
    {"points_xz": [(1.485, 0.355), (1.665, 0.338), (1.865, 0.358), (1.795, 0.395), (1.555, 0.388)],
     "base_y": 0.096, "shoulder_y": 0.122, "crest_y": 0.136,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.020, 0.007)},
    {"points_xz": [(1.485, 0.355), (1.665, 0.338), (1.865, 0.358), (1.795, 0.395), (1.555, 0.388)],
     "base_y": -0.096, "shoulder_y": -0.122, "crest_y": -0.136,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.020, 0.007)},
], flat_group="FBGrowMid")

glacier_cluster("FB_GrowFront", [
    {"points_xz": [(1.885, 0.362), (2.045, 0.348), (2.215, 0.365), (2.155, 0.398), (1.945, 0.392)],
     "base_y": 0.096, "shoulder_y": 0.122, "crest_y": 0.136,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.018, 0.006)},
    {"points_xz": [(1.885, 0.362), (2.045, 0.348), (2.215, 0.365), (2.155, 0.398), (1.945, 0.392)],
     "base_y": -0.096, "shoulder_y": -0.122, "crest_y": -0.136,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.018, 0.006)},
], flat_group="FBGrowFront")

glacier_shard(
    "FB_Shard1", [(0.455, 0.315), (0.585, 0.296), (0.725, 0.318), (0.675, 0.354), (0.495, 0.348)],
    0.104, 0.128, 0.142, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.015, 0.005), flat_group="FBShard1",
)
glacier_shard(
    "FB_Shard2", [(1.645, 0.295), (1.825, 0.275), (2.015, 0.305), (1.945, 0.348), (1.715, 0.338)],
    0.102, 0.128, 0.144, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.018, 0.006), flat_group="FBShard2",
)
glacier_shard(
    "FB_Shard3", [(0.385, 0.215), (0.525, 0.198), (0.685, 0.220), (0.625, 0.254), (0.425, 0.248)],
    -0.102, -0.126, -0.140, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.015, 0.005), flat_group="FBShard3",
)
glacier_shard(
    "FB_Shard4", [(1.645, 0.295), (1.825, 0.275), (2.015, 0.305), (1.945, 0.348), (1.715, 0.338)],
    -0.102, -0.128, -0.144, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.018, 0.006), flat_group="FBShard4",
)

# ---------------------------------------------------------------- charm clearance assert
bpy.context.view_layer.update()
_deps = bpy.context.evaluated_depsgraph_get()
charm_clearance = 9.0
for _obj in shells.objects:
    if _obj.type != "MESH" or _obj.parent_bone != "Root":
        continue
    _mesh = _obj.evaluated_get(_deps).to_mesh()
    for _v in _mesh.vertices:
        p = _obj.matrix_world @ _v.co
        dz = max(0.0, p.z - CHARM.z)
        charm_clearance = min(charm_clearance, math.sqrt((p.x - CHARM.x) ** 2 + (p.y - CHARM.y) ** 2 + dz ** 2))
    _obj.evaluated_get(_deps).to_mesh_clear()
assert charm_clearance >= 0.088, f"Odin charm clearance too tight: {charm_clearance:.4f}"

result = finish_master(hand)
result["stock_join_moves"] = moves
result["charm_clearance"] = round(charm_clearance, 4)
