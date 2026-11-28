"""Frostbite Pump (Bucky) v01: Legendary sculpted cryo-armor remodel."""

from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

GUN = "Bucky"
VERSION = globals().get("VERSION", "v02")
exec((Path(bpy.data.filepath).parents[4] / "tools/blender/frostbite/frost_lib.py").read_text(encoding="utf-8"))

replace("Stock", "Neon")

# ---------------------------------------------------------------- retained stock + gap sweep
for name in ("Receiver", "CharmLoop", "Bolt", "Trigger", "Grip", "Sights", "Pins", "Shell"):
    dress(name)
dress("Pump", keep=lambda island: limits(island, 0)[1] < 1.3)
dress("Barrel", keep=lambda island: not (limits(island, 0)[0] > 2.78 and limits(island, 0)[1] < 2.80))
dress("Stock", copy_name="FB_StockFrame", keep=lambda island: limits(island, 0)[0] > -0.94)


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
BARREL = native("Barrel")
FRAME = bpy.data.objects["FB_StockFrame"]
gap_moves = {
    "barrel_rear": nudge(BARREL, lambda p: p.x < 0.952, (-0.012, 0, 0),
                         lambda lo, hi: lo.x < 1.0 and hi.x > 2.8),
    "barrel_end": nudge(BARREL, lambda p: p.x > 2.82, (-0.042, 0, 0),
                        lambda lo, hi: lo.x < 1.0 and hi.x > 2.8),
    "tube_front": nudge(BARREL, lambda p: p.x > 2.725, (0.020, 0, 0),
                        lambda lo, hi: lo.x < 1.0 and abs(hi.x - 2.73) < 0.003),
    "rear_sight_base": nudge(SIGHTS, lambda p: p.z < 0.422, (0, 0, -0.018), lambda lo, hi: hi.x < 0.5),
    "front_bead_base": nudge(SIGHTS, lambda p: p.z < 0.422, (0, 0, -0.018), lambda lo, hi: lo.x > 2.5),
    "wrist_front": nudge(FRAME, lambda p: p.x > -0.095, (0.016, 0, 0),
                         lambda lo, hi: abs(lo.x + 0.25) < 0.005 and abs(hi.x + 0.093) < 0.005),
    "wrist_rear": nudge(FRAME, lambda p: p.x < -0.244, (-0.008, 0, 0),
                        lambda lo, hi: abs(lo.x + 0.25) < 0.005 and hi.x > -0.1),
    "pump_bars": nudge(native("Pump"), lambda p: p.x > 1.24, (0.020, 0, 0)),
}

# ---------------------------------------------------------------- pump forend cryo-shroud (bone Pump, x 1.239..2.094)
TUBE_Z = 0.216
BORE = [(0.0671 * math.cos(math.radians(a)), TUBE_Z + 0.0671 * math.sin(math.radians(a)))
        for a in (112.5, 67.5, 22.5, -22.5, -67.5, -112.5, -157.5, 157.5)]
FOLD = (0.096, 0.311, 0.084, 0.285, 0.125, 0.050)
END = (0.104, 0.303, 0.076, 0.281, 0.129, 0.046)
forend = loft("FB_Forend", [
    fold(1.239, *END), fold(1.249, *FOLD), fold(2.082, *FOLD), fold(2.094, *END),
    [(2.094, y, z) for y, z in BORE], [(1.239, y, z) for y, z in BORE],
], ARMOR, bone="Pump", loop=True)

FORE_CHASM = [(1.495, 0.148), (1.972, 0.148), (2.002, 0.178), (2.002, 0.240), (1.974, 0.264), (1.495, 0.258)]
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(forend, f"FB_ForeChasm_{label}", FORE_CHASM, 0.074 * sign, 0.15 * sign, role=OBSIDIAN, bone="Pump")
    armor_plate(
        f"FB_ForeJawRear_{label}",
        [(1.260, 0.142), (1.455, 0.138), (1.515, 0.205), (1.465, 0.272), (1.260, 0.268)],
        0.076 * sign, 0.098 * sign, 0.104 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.006, bone="Pump",
    )
    armor_plate(
        f"FB_ForeJawFront_{label}",
        [(1.885, 0.145), (2.015, 0.155), (2.065, 0.205), (2.015, 0.265), (1.885, 0.262)],
        0.076 * sign, 0.100 * sign, 0.106 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.006, bone="Pump",
    )
    swept_rib(f"FB_ForeSeam_{label}", [
        (1.505, 0.083 * sign, 0.194, 0.005, 0.006),
        (1.735, 0.084 * sign, 0.204, 0.006, 0.007),
        (1.945, 0.083 * sign, 0.214, 0.005, 0.006),
    ], CRYO_GLOW, bone="Pump", flat_group="FBForeSeam")
    glacier_cluster(f"FB_ForeCrystals_{label}", [
        {"points_xz": [(1.515, 0.168), (1.665, 0.152), (1.865, 0.182), (1.805, 0.244), (1.545, 0.236)],
         "base_y": 0.074 * sign, "shoulder_y": 0.102 * sign, "crest_y": 0.116 * sign, "ridge_bias": (-0.016, 0.006)},
    ], bone="Pump")

glacier_cluster("FB_ForeKeel", [
    {"points_xz": [(1.465, 0.096), (1.665, 0.072), (1.865, 0.104), (1.785, 0.128), (1.535, 0.118)],
     "base_y": 0.026, "shoulder_y": -0.024, "crest_y": -0.036, "ridge_bias": (-0.014, -0.008)},
    {"points_xz": [(1.465, 0.096), (1.665, 0.072), (1.865, 0.104), (1.785, 0.128), (1.535, 0.118)],
     "base_y": -0.026, "shoulder_y": 0.024, "crest_y": 0.036, "ridge_bias": (-0.014, -0.008)},
], bone="Pump")

# ---------------------------------------------------------------- receiver wing armor & cryo-core bay
# Left recess x .217..886, z .248..384 (pin .923; CharmLoop x .899..931);
# Right lower band z .132..235 ONLY (above z .25 is ejection port & Bolt traveling back to x .187!).
for sign, label in ((1, "Left"), (-1, "Right")):
    armor_plate(
        f"FB_RecArmorLower_{label}",
        [(0.115, 0.145), (0.835, 0.145), (0.865, 0.185), (0.825, 0.225), (0.115, 0.225)],
        0.070 * sign, 0.090 * sign, 0.096 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.006,
    )
    bay_poly = (
        [(0.285, 0.244), (0.825, 0.244), (0.848, 0.310), (0.825, 0.382), (0.325, 0.382), (0.275, 0.312)]
        if sign == 1 else
        [(0.285, 0.142), (0.815, 0.142), (0.835, 0.186), (0.815, 0.228), (0.295, 0.228), (0.275, 0.186)]
    )
    bay = side(f"FB_CoreBay_{label}", bay_poly, 0.068 * sign, 0.092 * sign, ARMOR)
    chasm_poly = (
        [(0.305, 0.256), (0.805, 0.256), (0.824, 0.312), (0.805, 0.370), (0.335, 0.370), (0.295, 0.312)]
        if sign == 1 else
        [(0.305, 0.152), (0.795, 0.152), (0.812, 0.186), (0.795, 0.218), (0.315, 0.218), (0.295, 0.186)]
    )
    recess(bay, f"FB_CoreChasm_{label}", chasm_poly, 0.080 * sign, 0.13 * sign, role=OBSIDIAN)
    fz = (0.312, 0.308, 0.318, 0.314) if sign == 1 else (0.186, 0.182, 0.190, 0.186)
    swept_rib(f"FB_CoreFissure_{label}", [
        (0.325, 0.084 * sign, fz[0], 0.005, 0.006),
        (0.475, 0.085 * sign, fz[1], 0.006, 0.007),
        (0.625, 0.085 * sign, fz[2], 0.006, 0.007),
        (0.775, 0.084 * sign, fz[3], 0.005, 0.006),
    ], CRYO_GLOW, flat_group="FBCoreFissure")
    if sign == 1:
        glacier_cluster("FB_CoreCrystals_Left", [
            {"points_xz": [(0.325, 0.285), (0.425, 0.268), (0.525, 0.286), (0.485, 0.348), (0.355, 0.340)],
             "base_y": 0.075, "shoulder_y": 0.098, "crest_y": 0.112, "ridge_bias": (-0.014, 0.005)},
            {"points_xz": [(0.595, 0.288), (0.695, 0.270), (0.795, 0.294), (0.745, 0.352), (0.615, 0.342)],
             "base_y": 0.075, "shoulder_y": 0.100, "crest_y": 0.114,
             "roles": (ICE_MID, ICE_MID, ICE_BRIGHT), "ridge_bias": (-0.014, 0.005)},
        ])
    else:
        glacier_cluster("FB_CoreCrystals_Right", [
            {"points_xz": [(0.325, 0.165), (0.495, 0.154), (0.695, 0.174), (0.645, 0.214), (0.365, 0.208)],
             "base_y": -0.075, "shoulder_y": -0.098, "crest_y": -0.110, "ridge_bias": (-0.016, 0.004)},
        ])

glacier_shard(
    "FB_CoreHeart_Left",
    [(0.522, 0.314), (0.558, 0.294), (0.594, 0.312), (0.562, 0.334)],
    0.082, 0.106, 0.118,
    roles=(GLOW_WHITE, GLOW_WHITE, GLOW_WHITE),
    ridge_bias=(-0.005, 0.002),
    flat_group="FBCoreHeart",
)

# ---------------------------------------------------------------- swept glacial wing stock & butt
butt = side("FB_StockButt", [
    (-0.835, 0.348), (-0.912, 0.374), (-0.944, 0.360), (-0.955, 0.330), (-0.938, 0.314),
    (-0.934, 0.150), (-0.955, 0.134), (-0.955, 0.090), (-0.936, 0.074), (-0.936, -0.255),
    (-0.912, -0.298), (-0.835, -0.298),
], -0.082, 0.082, ARMOR, bevel=0.006)
STOCK_REC = [(-0.862, -0.228), (-0.918, -0.228), (-0.922, 0.270), (-0.908, 0.284), (-0.862, 0.284)]
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(butt, f"FB_ButtRecess_{label}", STOCK_REC, 0.074 * sign, 0.12 * sign, role=OBSIDIAN)
    armor_plate(
        f"FB_StockWingCheek_{label}",
        [(-0.852, 0.316), (-0.918, 0.316), (-0.930, 0.352), (-0.914, 0.364), (-0.852, 0.342)],
        0.070 * sign, 0.088 * sign, 0.094 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.005,
    )
    armor_plate(
        f"FB_StockFrameWing_{label}",
        [(-0.735, 0.185), (-0.545, 0.185), (-0.505, 0.295), (-0.705, 0.295)],
        0.066 * sign, 0.080 * sign, 0.086 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.006,
    )
for sign, label in ((1, "L"), (-1, "R")):
    glacier_cluster(f"FB_StockCrystals_{label}", [
        {"points_xz": [(-0.916, -0.195), (-0.868, -0.125), (-0.862, 0.225), (-0.912, 0.145)],
         "base_y": 0.072 * sign, "shoulder_y": 0.090 * sign, "crest_y": 0.102 * sign, "ridge_bias": (0.008, 0.005)},
    ])
swept_rib("FB_StockGlow", [
    (-0.900, 0.0, -0.185, 0.062, 0.009),
    (-0.892, 0.0,  0.035, 0.062, 0.009),
    (-0.884, 0.0,  0.255, 0.062, 0.009),
], CRYO_GLOW, flat_group="FBStockGlow")

# ---------------------------------------------------------------- cryo muzzle collar (x 2.752..2.834, z .369)
collar = prism_along("FB_MuzzleCollar", (2.752, 0, 0.369), (1, 0, 0), [
    (0.000, 0.060), (0.006, 0.067), (0.024, 0.067), (0.024, 0.0625), (0.046, 0.0625), (0.046, 0.070),
    (0.070, 0.070), (0.076, 0.064), (0.082, 0.064), (0.082, 0.040), (0.056, 0.040),
], FROSTSTEEL)
prism_along("FB_MuzzleGlow", (2.773, 0, 0.369), (1, 0, 0), [(0, 0.065), (0.028, 0.065)],
            CRYO_GLOW)["flat_group"] = "FBMuzzleGlow"
glacier_cluster("FB_MuzzleIce", [
    {"points_xz": [(2.755, 0.295), (2.790, 0.278), (2.828, 0.298), (2.798, 0.318)],
     "base_y": 0.018, "shoulder_y": -0.018, "crest_y": -0.028, "ridge_bias": (-0.008, -0.005)},
    {"points_xz": [(2.755, 0.295), (2.790, 0.278), (2.828, 0.298), (2.798, 0.318)],
     "base_y": -0.018, "shoulder_y": 0.018, "crest_y": 0.028, "ridge_bias": (-0.008, -0.005)},
])

# ---------------------------------------------------------------- tube seam glow & animated flat_groups
swept_rib("FB_MagTubeGlow", [
    (2.155, 0.0, 0.165, 0.042, 0.008),
    (2.355, 0.0, 0.165, 0.042, 0.008),
    (2.585, 0.0, 0.165, 0.042, 0.008),
], CRYO_GLOW, flat_group="FBMagGlow")

glacier_cluster("FB_GrowRear", [
    {"points_xz": [(0.265, 0.362), (0.415, 0.350), (0.575, 0.366), (0.515, 0.398), (0.315, 0.392)],
     "base_y": 0.070, "shoulder_y": 0.090, "crest_y": 0.102,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.014, 0.004)},
    {"points_xz": [(0.265, 0.362), (0.415, 0.350), (0.575, 0.366), (0.515, 0.398), (0.315, 0.392)],
     "base_y": -0.070, "shoulder_y": -0.090, "crest_y": -0.102,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.014, 0.004)},
], flat_group="FBGrowRear")

glacier_cluster("FB_GrowMid", [
    {"points_xz": [(0.625, 0.364), (0.765, 0.352), (0.915, 0.368), (0.855, 0.398), (0.675, 0.392)],
     "base_y": 0.070, "shoulder_y": 0.092, "crest_y": 0.104,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.014, 0.004)},
    {"points_xz": [(0.625, 0.364), (0.765, 0.352), (0.915, 0.368), (0.855, 0.398), (0.675, 0.392)],
     "base_y": -0.070, "shoulder_y": -0.092, "crest_y": -0.104,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.014, 0.004)},
], flat_group="FBGrowMid")

glacier_cluster("FB_GrowFront", [
    {"points_xz": [(2.425, 0.282), (2.545, 0.270), (2.675, 0.286), (2.625, 0.316), (2.465, 0.310)],
     "base_y": 0.048, "shoulder_y": 0.068, "crest_y": 0.078,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.012, 0.004)},
    {"points_xz": [(2.425, 0.282), (2.545, 0.270), (2.675, 0.286), (2.625, 0.316), (2.465, 0.310)],
     "base_y": -0.048, "shoulder_y": -0.068, "crest_y": -0.078,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.012, 0.004)},
], flat_group="FBGrowFront")

glacier_shard(
    "FB_Shard1", [(0.365, 0.292), (0.505, 0.276), (0.675, 0.294), (0.625, 0.328), (0.415, 0.322)],
    0.080, 0.102, 0.114, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.012, 0.004), flat_group="FBShard1",
)
glacier_shard(
    "FB_Shard2", [(0.625, 0.294), (0.725, 0.278), (0.835, 0.298), (0.785, 0.330), (0.655, 0.322)],
    0.080, 0.102, 0.114, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.010, 0.004), flat_group="FBShard2",
)
glacier_shard(
    "FB_Shard3", [(0.345, 0.168), (0.495, 0.154), (0.675, 0.172), (0.625, 0.206), (0.395, 0.198)],
    -0.083, -0.104, -0.116, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.012, 0.004), flat_group="FBShard3",
)
glacier_shard(
    "FB_Shard4", [(2.435, 0.265), (2.545, 0.252), (2.665, 0.270), (2.615, 0.300), (2.475, 0.294)],
    -0.052, -0.072, -0.082, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.010, 0.004), flat_group="FBShard4",
)


def sight_line_hits():
    depsgraph = bpy.context.evaluated_depsgraph_get()
    bpy.context.view_layer.update()
    hits = set()
    eye = Vector((-0.20, 0, 0.466))
    for dy, dz in ((0, 0), (0.012, 0), (-0.012, 0), (0, 0.012), (0, -0.006)):
        origin = eye + Vector((0, dy, dz))
        direction = (Vector((2.62, 0, 0.466)) - eye).normalized()
        hit, _loc, _n, _i, obj, _m = scene.ray_cast(depsgraph, origin, direction, distance=2.9)
        if hit and obj.name.startswith("FB_"):
            hits.add(obj.name)
    return sorted(hits)


result = finish_master(forend)
result["gap_moves"] = gap_moves
result["sight_line_new_hits"] = sight_line_hits()
