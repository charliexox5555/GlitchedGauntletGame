"""Frostbite Sheriff (revolver) v01: Legendary sculpted cryo-armor remodel."""

from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

GUN = "Sheriff"
VERSION = globals().get("VERSION", "v02")
exec((Path(bpy.data.filepath).parents[4] / "tools/blender/frostbite/frost_lib.py").read_text(encoding="utf-8"))

# ---------------------------------------------------------------- retained stock + gap sweep
for name in ("Frame", "Barrel", "Sights", "Neon", "Grip", "Pins", "CharmLoop", "Crane", "Cylinder", "Rounds",
             "EjectorRod", "Hammer", "Trigger", "CylinderRelease", "Speedloader"):
    dress(name)


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


FRAME = native("Frame")
BARREL = native("Barrel")
SIGHTS = native("Sights")
gap_moves = {
    "guard_posts": nudge(FRAME, lambda p: -0.021 < p.z < 0 and abs(p.y) < 0.031 and 0.23 < p.x < 0.6,
                         (0, 0, 0.020), lambda lo, hi: hi.z < 0),
    "rear_sight_feet": nudge(SIGHTS, lambda p: p.z < 0.3715, (0, 0, -0.020), lambda lo, hi: hi.x < 0.5),
    "front_sight_feet": nudge(SIGHTS, lambda p: p.z < 0.3445, (0, 0, -0.016), lambda lo, hi: lo.x > 1.0),
    "lug_top": nudge(BARREL, lambda p: abs(p.z - 0.2152) < 0.0005, (0, 0, 0.012),
                     lambda lo, hi: hi.z < 0.22),
    "lug_rear": nudge(BARREL, lambda p: p.x < 0.76 and p.z < 0.12, (-0.020, 0, 0),
                      lambda lo, hi: hi.z < 0.23),
    "frame_front": nudge(FRAME, lambda p: p.x > 0.759, (0.013, 0, 0),
                         lambda lo, hi: lo.x < 0 and hi.x > 0.7),
}

# ---------------------------------------------------------------- barrel & underlug cryo shroud (x .835..1.41)
# Swept crane/speedloader stays clear for x > .78! Right frame below hammer (x .06..30, z .06..20) is also safe.
recess(BARREL, "FB_BarrelChasm_Right",
       [(0.860, 0.264), (0.868, 0.250), (1.380, 0.248), (1.396, 0.264), (1.396, 0.292), (1.381, 0.307), (0.875, 0.307), (0.860, 0.292)],
       -0.060, -0.150, role=OBSIDIAN)

for sign, label in ((1, "Left"), (-1, "Right")):
    armor_plate(
        f"FB_BarrelShroud_{label}",
        [(0.840, 0.238), (1.035, 0.238), (1.115, 0.312), (0.848, 0.312)],
        0.060 * sign, 0.078 * sign, 0.084 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.006,
    )
    armor_plate(
        f"FB_LugWing_{label}",
        [(0.838, 0.118), (1.165, 0.120), (1.238, 0.205), (1.185, 0.232), (0.838, 0.215)],
        0.042 * sign, 0.070 * sign, 0.076 * sign, ARMOR, rim_role=FROSTSTEEL, inset=0.006,
    )
    armor_plate(
        f"FB_ForeJawFront_{label}",
        [(1.215, 0.228), (1.375, 0.238), (1.415, 0.275), (1.385, 0.312), (1.235, 0.308)],
        0.060 * sign, 0.080 * sign, 0.086 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.005,
    )
    swept_rib(f"FB_ForeSeam_{label}", [
        (0.895, 0.065 * sign, 0.268, 0.004, 0.005),
        (1.135, 0.066 * sign, 0.274, 0.005, 0.006),
        (1.365, 0.065 * sign, 0.278, 0.004, 0.005),
    ], CRYO_GLOW, flat_group="FBForeSeam")

# Cryo-core bay on Left lug/barrel side (x .86..1.21, z .145..265, below barrel chamfer .318, hidden behind cylinder in ADS!)
bay_l = side("FB_CoreBay_Left",
             [(0.855, 0.138), (1.175, 0.142), (1.225, 0.205), (1.215, 0.268), (0.865, 0.268), (0.845, 0.195)],
             0.044, 0.074, ARMOR)
recess(bay_l, "FB_CoreChasm_Left",
       [(0.875, 0.152), (1.158, 0.156), (1.202, 0.208), (1.195, 0.256), (0.882, 0.256), (0.865, 0.198)],
       0.064, 0.10, role=OBSIDIAN)
glacier_cluster("FB_CoreCrystals_Left", [
    {"points_xz": [(0.882, 0.172), (0.985, 0.156), (1.085, 0.178), (1.045, 0.242), (0.905, 0.234)],
     "base_y": 0.060, "shoulder_y": 0.082, "crest_y": 0.092, "ridge_bias": (-0.010, 0.004)},
    {"points_xz": [(1.095, 0.210), (1.155, 0.196), (1.198, 0.222), (1.165, 0.252), (1.105, 0.246)],
     "base_y": 0.060, "shoulder_y": 0.083, "crest_y": 0.094,
     "roles": (ICE_MID, ICE_MID, ICE_BRIGHT), "ridge_bias": (-0.008, 0.003)},
])
glacier_shard(
    "FB_CoreHeart_Left",
    [(1.032, 0.205), (1.064, 0.188), (1.096, 0.204), (1.066, 0.224)],
    0.066, 0.090, 0.100, roles=(GLOW_WHITE, GLOW_WHITE, GLOW_WHITE),
    ridge_bias=(-0.004, 0.002), flat_group="FBCoreHeart",
)

# Right frame armor under hammer (x .115..295, z .075..198, safe from reload!)
armor_plate("FB_FrameArmor_Right", [(0.115, 0.075), (0.292, 0.075), (0.298, 0.196), (0.115, 0.192)],
            -0.058, -0.076, -0.082, FROSTSTEEL, rim_role=ARMOR, inset=0.005)
glacier_cluster("FB_FrameCrystals_Right", [
    {"points_xz": [(0.135, 0.095), (0.225, 0.085), (0.285, 0.125), (0.255, 0.182), (0.145, 0.175)],
     "base_y": -0.068, "shoulder_y": -0.088, "crest_y": -0.098, "ridge_bias": (-0.008, 0.004)},
])
glacier_cluster("FB_ForeCrystals_Right", [
    {"points_xz": [(0.925, 0.245), (1.115, 0.232), (1.295, 0.258), (1.235, 0.302), (0.965, 0.296)],
     "base_y": -0.062, "shoulder_y": -0.082, "crest_y": -0.093, "ridge_bias": (-0.012, 0.004)},
])
prism_along("FB_LugFissure_Right", (0.790, -0.0577, 0.2245), (1, 0, 0),
            [(0, 0.0068), (0.645, 0.0068)], CRYO_GLOW)["flat_group"] = "FBCoreFissure"

# ---------------------------------------------------------------- hollow muzzle collar (x 1.425..1.503, z .2772)
ZC, HW, HH, CH = 0.2772, 0.068, 0.071, 0.030


def boxsec(x, ds, dt):
    side_y = HW + ds
    kt = HW + HH - CH + math.sqrt(2) * (ds + dt) / 2
    kb = HW + HH - CH + math.sqrt(2) * ds
    top, bottom = HH + dt, HH + ds
    pts = [(kt - top, top), (-(kt - top), top), (-side_y, kt - side_y), (-side_y, -(kb - side_y)),
           (-(kb - bottom), -bottom), (kb - bottom, -bottom), (side_y, -(kb - side_y)), (side_y, kt - side_y)]
    return [(x, y, ZC + z) for y, z in pts]


X0 = 1.425
PROFILE = [(0.000, 0.005, 0.002), (0.006, 0.012, 0.006), (0.020, 0.012, 0.006), (0.020, 0.008, 0.003),
           (0.044, 0.008, 0.003), (0.044, 0.014, 0.007), (0.064, 0.014, 0.007), (0.071, 0.009, 0.004),
           (0.078, 0.009, 0.004)]
loft("FB_MuzzleCollar", [boxsec(X0 + t, ds, dt) for t, ds, dt in PROFILE]
     + [boxsec(X0 + 0.078, -0.013, -0.013), boxsec(X0, -0.013, -0.013)], FROSTSTEEL, loop=True)
loft("FB_MuzzleGlow", [boxsec(X0 + 0.017, 0.0105, 0.0048), boxsec(X0 + 0.047, 0.0105, 0.0048),
                       boxsec(X0 + 0.047, -0.016, -0.016), boxsec(X0 + 0.017, -0.016, -0.016)],
     CRYO_GLOW, loop=True)["flat_group"] = "FBMuzzleGlow"
glacier_cluster("FB_MuzzleIce", [
    {"points_xz": [(1.425, 0.195), (1.460, 0.180), (1.498, 0.198), (1.468, 0.216)],
     "base_y": 0.018, "shoulder_y": -0.018, "crest_y": -0.028, "ridge_bias": (-0.008, -0.005)},
    {"points_xz": [(1.425, 0.195), (1.460, 0.180), (1.498, 0.198), (1.468, 0.216)],
     "base_y": -0.018, "shoulder_y": 0.018, "crest_y": 0.028, "ridge_bias": (-0.008, -0.005)},
])

# ---------------------------------------------------------------- animated flat_groups (Root, clear of ADS & reload!)
glacier_cluster("FB_GrowRear", [
    {"points_xz": [(0.885, 0.240), (0.985, 0.230), (1.095, 0.244), (1.055, 0.270), (0.915, 0.264)],
     "base_y": 0.066, "shoulder_y": 0.084, "crest_y": 0.094,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.010, 0.003)},
    {"points_xz": [(0.885, 0.256), (0.985, 0.246), (1.095, 0.260), (1.055, 0.286), (0.915, 0.280)],
     "base_y": -0.066, "shoulder_y": -0.084, "crest_y": -0.094,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.010, 0.003)},
], flat_group="FBGrowRear")

glacier_cluster("FB_GrowMid", [
    {"points_xz": [(1.125, 0.244), (1.235, 0.234), (1.355, 0.248), (1.315, 0.276), (1.165, 0.270)],
     "base_y": 0.066, "shoulder_y": 0.086, "crest_y": 0.096,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.010, 0.003)},
    {"points_xz": [(1.125, 0.258), (1.235, 0.248), (1.355, 0.262), (1.315, 0.290), (1.165, 0.284)],
     "base_y": -0.066, "shoulder_y": -0.086, "crest_y": -0.096,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.010, 0.003)},
], flat_group="FBGrowMid")

glacier_cluster("FB_GrowFront", [
    {"points_xz": [(0.925, 0.140), (1.025, 0.130), (1.135, 0.145), (1.095, 0.172), (0.955, 0.165)],
     "base_y": 0.044, "shoulder_y": 0.066, "crest_y": 0.076,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.010, 0.003)},
    {"points_xz": [(0.925, 0.140), (1.025, 0.130), (1.135, 0.145), (1.095, 0.172), (0.955, 0.165)],
     "base_y": -0.044, "shoulder_y": -0.066, "crest_y": -0.076,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.010, 0.003)},
], flat_group="FBGrowFront")

glacier_shard(
    "FB_Shard1", [(0.895, 0.185), (1.005, 0.172), (1.125, 0.188), (1.085, 0.216), (0.935, 0.210)],
    0.068, 0.088, 0.098, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.010, 0.003), flat_group="FBShard1",
)
glacier_shard(
    "FB_Shard2", [(1.225, 0.242), (1.305, 0.232), (1.385, 0.248), (1.355, 0.278), (1.245, 0.270)],
    0.068, 0.088, 0.098, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.008, 0.003), flat_group="FBShard2",
)
glacier_shard(
    "FB_Shard3", [(0.155, 0.105), (0.215, 0.095), (0.275, 0.115), (0.255, 0.150), (0.165, 0.145)],
    -0.074, -0.092, -0.102, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.008, 0.003), flat_group="FBShard3",
)
glacier_shard(
    "FB_Shard4", [(1.025, 0.254), (1.135, 0.242), (1.255, 0.260), (1.215, 0.290), (1.055, 0.282)],
    -0.068, -0.088, -0.098, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.010, 0.003), flat_group="FBShard4",
)


def ads_visible():
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    aim = bpy.data.objects[f"{GUN}_AimPoint"].matrix_world.translation
    eye = aim - Vector((0.42 / 0.8, 0, 0))
    offset = 0.012 / 0.8
    eyes = [eye + Vector((0, y, z)) for y, z in ((0, 0), (offset, 0), (-offset, 0), (0, offset), (0, -offset))]
    seen = {}
    for obj in shells.objects:
        if obj.type != "MESH" or obj.hide_render:
            continue
        eval_obj = obj.evaluated_get(depsgraph)
        mesh = eval_obj.to_mesh()
        for vertex in mesh.vertices:
            point = eval_obj.matrix_world @ vertex.co
            for origin in eyes:
                direction = point - origin
                distance = direction.length
                hit, _loc, _n, _i, hit_obj, _m = scene.ray_cast(depsgraph, origin, direction.normalized(),
                                                                    distance=distance - 1e-4)
                if not hit:
                    seen[obj.name] = seen.get(obj.name, 0) + 1
                    break
        eval_obj.to_mesh_clear()
    return seen


result = finish_master(bay_l)
result["gap_moves"] = gap_moves
result["ads_visible_vertices"] = ads_visible()
