"""Frostbite Ghost (Hush) v01: Legendary sculpted cryo-armor suppressed pistol remodel."""

from pathlib import Path

import bpy
from mathutils import Vector

GUN = "Ghost"
VERSION = globals().get("VERSION", "v02")
exec((Path(bpy.data.filepath).parents[4] / "tools/blender/frostbite/frost_lib.py").read_text(encoding="utf-8"))

# ---------------------------------------------------------------- retained stock (CharmLoop dressed & kept clear)
for name in ("SlideNeon", "Frame", "Pins", "Trigger", "SlideCatch", "MagRelease", "CharmLoop", "Grip", "Mag"):
    dress(name)
dress("Slide", copy_name="FB_SlideSights", keep=lambda island: limits(island, 0)[1] - limits(island, 0)[0] < 1.0)
SLIDE = dress("Slide", keep=lambda island: limits(island, 0)[1] - limits(island, 0)[0] > 1.0)
BARREL = dress("Suppressor", keep=lambda island: limits(island, 0)[1] < 1.14)


def lift_faces(obj, normal, distance):
    normal = Vector(normal).normalized()
    matrix = obj.matrix_world
    inverse = matrix.inverted()
    turn = matrix.to_3x3().inverted().transposed()
    picked = {i for p in obj.data.polygons if (turn @ p.normal).normalized().dot(normal) > 0.999 for i in p.vertices}
    for i in picked:
        vertex = obj.data.vertices[i]
        vertex.co = inverse @ (matrix @ vertex.co + normal * distance)
    obj.data.update()
    return len(picked)


NEON_FIX = lift_faces(native("SlideNeon"), (0.883, 0, -0.469), 0.004)


def hex_along(name, origin, axis, profile, roles, *, bone="Root", flat_group=None):
    origin = Vector(origin)
    axis = Vector(axis).normalized()
    helper = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))
    u = axis.cross(helper).normalized()
    v = axis.cross(u).normalized()
    sections = [[tuple(origin + axis * t + u * a + v * b) for a, b in polygon(0, 0, radius, 6, 0)]
                for t, radius in profile]
    return loft(name, sections, roles, bone=bone, flat_group=flat_group)


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


A8 = math.cos(math.pi / 8)


def tube(name, z, outer, inner, roles, *, bone, flat_group=None):
    sections = [[(x, a / A8 * math.cos(t), z + a / A8 * math.sin(t)) for t in
                 (math.pi / 8 + math.pi / 4 * i for i in range(8))] for x, a in (*outer, *inner)]
    return loft(name, sections, roles, bone=bone, loop=True, flat_group=flat_group)


# ---------------------------------------------------------------- frame left core bay & right grip cryo armor
bay_l = side("FB_CoreBay_Left",
             [(-0.045, 0.138), (0.275, 0.138), (0.290, 0.160), (0.285, 0.218), (-0.032, 0.218), (-0.048, 0.190)],
             0.054, 0.074, ARMOR)
recess(bay_l, "FB_CoreChasm_Left",
       [(-0.030, 0.148), (0.262, 0.148), (0.274, 0.168), (0.270, 0.208), (-0.018, 0.208), (-0.034, 0.184)],
       0.064, 0.10, role=OBSIDIAN)
swept_rib("FB_CoreFissure_Left", [
    (-0.015, 0.068, 0.178, 0.004, 0.005),
    (0.115,  0.069, 0.176, 0.005, 0.006),
    (0.245,  0.068, 0.180, 0.004, 0.005),
], CRYO_GLOW, flat_group="FBCoreFissure")
glacier_cluster("FB_CoreCrystals_Left", [
    {"points_xz": [(-0.018, 0.156), (0.085, 0.146), (0.195, 0.164), (0.155, 0.202), (0.005, 0.196)],
     "base_y": 0.063, "shoulder_y": 0.082, "crest_y": 0.092, "ridge_bias": (-0.008, 0.003)},
])
glacier_shard(
    "FB_CoreHeart_Left",
    [(0.175, 0.178), (0.205, 0.164), (0.235, 0.176), (0.207, 0.194)],
    0.066, 0.086, 0.095, roles=(GLOW_WHITE, GLOW_WHITE, GLOW_WHITE),
    ridge_bias=(-0.003, 0.002), flat_group="FBCoreHeart",
)

RAKE, ZC = 0.25, -0.115


def shear(points):
    return [(x + RAKE * (z - ZC), z) for x, z in points]


armor_plate("FB_GripWing_Right", shear([(-0.085, -0.195), (0.062, -0.195), (0.068, -0.035), (-0.075, -0.035)]),
            -0.052, -0.070, -0.076, FROSTSTEEL, rim_role=ARMOR, inset=0.005)
glacier_cluster("FB_CoreCrystals_Right", [
    {"points_xz": shear([(-0.060, -0.170), (0.015, -0.180), (0.052, -0.065), (-0.042, -0.055)]),
     "base_y": -0.060, "shoulder_y": -0.080, "crest_y": -0.090, "ridge_bias": (-0.008, 0.004)},
])
hex_along("FB_CoreFissure_Right", (0.790, -0.0595, 0.1888), (1, 0, 0),
          [(0, 0.004), (0.010, 0.0085), (0.250, 0.0085), (0.260, 0.004)], CRYO_GLOW, flat_group="FBCoreFissure")

# ---------------------------------------------------------------- slide cryo shroud (bone Slide)
FIELD = [(0.100, 0.272), (0.110, 0.272), (0.110, 0.262), (0.120, 0.262), (0.120, 0.252),
         (0.780, 0.252), (0.800, 0.272), (0.800, 0.330), (0.782, 0.348), (0.116, 0.348), (0.100, 0.332)]
recess(SLIDE, "FB_SlideChasm_Left", FIELD, 0.060, 0.15, role=OBSIDIAN, bone="Slide")
armor_plate("FB_SlideJawFront_Left", [(0.665, 0.246), (0.845, 0.252), (0.875, 0.305), (0.845, 0.354), (0.675, 0.352)],
            0.060, 0.080, 0.086, FROSTSTEEL, rim_role=ARMOR, inset=0.006, bone="Slide")
armor_plate("FB_SlideJawRear_Left", [(0.085, 0.246), (0.255, 0.246), (0.275, 0.350), (0.105, 0.348)],
            0.060, 0.078, 0.084, ARMOR, rim_role=FROSTSTEEL, inset=0.006, bone="Slide")
swept_rib("FB_ForeSeam_Left", [
    (0.245, 0.067, 0.296, 0.004, 0.005),
    (0.495, 0.068, 0.302, 0.005, 0.006),
    (0.675, 0.067, 0.308, 0.004, 0.005),
], CRYO_GLOW, bone="Slide", flat_group="FBForeSeam")
glacier_cluster("FB_ForeCrystals_Left", [
    {"points_xz": [(0.265, 0.266), (0.435, 0.254), (0.635, 0.278), (0.585, 0.336), (0.295, 0.328)],
     "base_y": 0.060, "shoulder_y": 0.080, "crest_y": 0.091, "ridge_bias": (-0.012, 0.004)},
], bone="Slide")

# ---------------------------------------------------------------- glacial suppressor can (Root, x 1.129..2.054, BORE_Z .2965)
BORE_Z = 0.2965
gap_moves = {"barrel_into_can": nudge(BARREL, lambda p: p.x > 1.12 and p.y * p.y + (p.z - BORE_Z) ** 2 < 0.035 ** 2,
                                      (0.035, 0, 0))}
CAN_OUT = [(1.129, 0.060), (1.137, 0.068), (1.166, 0.068), (1.166, 0.078), (1.174, 0.084), (1.204, 0.084),
           (1.204, 0.091), (1.214, 0.099), (1.380, 0.099), (1.380, 0.092), (1.430, 0.092), (1.430, 0.099),
           (1.950, 0.099), (1.950, 0.093), (1.958, 0.091), (2.030, 0.091), (2.054, 0.074)]
CAN_IN = [(2.054, 0.036), (1.990, 0.036), (1.990, 0.022), (1.129, 0.022)]
CAN_ROLES = [FROSTSTEEL] * 6 + [ARMOR] * 6 + [FROSTSTEEL] * 9
can = tube("FB_Can", BORE_Z, CAN_OUT, CAN_IN, CAN_ROLES, bone="Root")
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(can, f"FB_CanVent_{label}", [(1.465, 0.270), (1.535, 0.324), (1.845, 0.324), (1.775, 0.270)],
           0.074 * sign, 0.12 * sign, role=OBSIDIAN)
    armor_plate(
        f"FB_CanFin_{label}",
        [(1.445, 0.250), (1.665, 0.236), (1.885, 0.260), (1.815, 0.302), (1.485, 0.296)],
        0.082 * sign, 0.110 * sign, 0.116 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.006,
    )
tube("FB_MuzzleGlow", BORE_Z, [(1.376, 0.0955), (1.434, 0.0955)], [(1.434, 0.088), (1.376, 0.088)],
     CRYO_GLOW, bone="Root", flat_group="FBMuzzleGlow")
glacier_cluster("FB_MuzzleIce", [
    {"points_xz": [(1.235, 0.222), (1.395, 0.194), (1.565, 0.230), (1.435, 0.258)],
     "base_y": 0.024, "shoulder_y": -0.024, "crest_y": -0.036, "ridge_bias": (-0.014, -0.008)},
    {"points_xz": [(1.235, 0.222), (1.395, 0.194), (1.565, 0.230), (1.435, 0.258)],
     "base_y": -0.024, "shoulder_y": 0.024, "crest_y": 0.036, "ridge_bias": (-0.014, -0.008)},
])

# ---------------------------------------------------------------- mag glow (bone Mag)
for sign, label in ((1, "Left"), (-1, "Right")):
    side(f"FB_MagGlow_{label}", [(0.018, -0.452), (0.038, -0.452), (0.060, -0.402), (0.040, -0.402)],
         0.061 * sign, 0.072 * sign, CRYO_GLOW, bone="Mag")["flat_group"] = "FBMagGlow"

# ---------------------------------------------------------------- animated flat_groups (Root, frame & can)
glacier_cluster("FB_GrowRear", [
    {"points_xz": [(-0.025, 0.172), (0.105, 0.160), (0.245, 0.178), (0.205, 0.208), (0.015, 0.202)],
     "base_y": 0.064, "shoulder_y": 0.084, "crest_y": 0.094,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.010, 0.003)},
    {"points_xz": [(-0.045, -0.140), (0.015, -0.150), (0.065, -0.115), (0.035, -0.075), (-0.035, -0.085)],
     "base_y": -0.062, "shoulder_y": -0.082, "crest_y": -0.092,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.006, 0.003)},
], flat_group="FBGrowRear")

glacier_cluster("FB_GrowMid", [
    {"points_xz": [(1.465, 0.260), (1.605, 0.244), (1.765, 0.264), (1.705, 0.302), (1.505, 0.296)],
     "base_y": 0.088, "shoulder_y": 0.112, "crest_y": 0.124,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.014, 0.004)},
    {"points_xz": [(1.465, 0.260), (1.605, 0.244), (1.765, 0.264), (1.705, 0.302), (1.505, 0.296)],
     "base_y": -0.088, "shoulder_y": -0.112, "crest_y": -0.124,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.014, 0.004)},
], flat_group="FBGrowMid")

glacier_cluster("FB_GrowFront", [
    {"points_xz": [(1.765, 0.266), (1.875, 0.252), (1.985, 0.270), (1.935, 0.306), (1.805, 0.300)],
     "base_y": 0.088, "shoulder_y": 0.112, "crest_y": 0.124,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.012, 0.004)},
    {"points_xz": [(1.765, 0.266), (1.875, 0.252), (1.985, 0.270), (1.935, 0.306), (1.805, 0.300)],
     "base_y": -0.088, "shoulder_y": -0.112, "crest_y": -0.124,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.012, 0.004)},
], flat_group="FBGrowFront")

glacier_shard(
    "FB_Shard1", [(0.015, 0.158), (0.115, 0.146), (0.225, 0.162), (0.185, 0.192), (0.045, 0.186)],
    0.068, 0.088, 0.098, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.008, 0.003), flat_group="FBShard1",
)
glacier_shard(
    "FB_Shard2", [(1.525, 0.272), (1.665, 0.256), (1.825, 0.276), (1.765, 0.312), (1.565, 0.306)],
    0.094, 0.116, 0.128, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.014, 0.004), flat_group="FBShard2",
)
glacier_shard(
    "FB_Shard3", [(-0.045, -0.155), (0.015, -0.165), (0.055, -0.120), (0.025, -0.075), (-0.035, -0.095)],
    -0.066, -0.086, -0.096, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.006, 0.003), flat_group="FBShard3",
)
glacier_shard(
    "FB_Shard4", [(1.525, 0.272), (1.665, 0.256), (1.825, 0.276), (1.765, 0.312), (1.565, 0.306)],
    -0.094, -0.116, -0.128, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.014, 0.004), flat_group="FBShard4",
)

result = finish_master(bay_l)
result["gap_moves"] = gap_moves
result["neon_fix_verts"] = NEON_FIX
