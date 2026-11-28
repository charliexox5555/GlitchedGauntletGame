"""Frostbite Shorty v01: Legendary sculpted cryo-armor double-barrel shotgun remodel."""

from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

GUN = "Shorty"
VERSION = globals().get("VERSION", "v02")
exec((Path(bpy.data.filepath).parents[4] / "tools/blender/frostbite/frost_lib.py").read_text(encoding="utf-8"))

# ---------------------------------------------------------------- retained stock (CharmLoop untouched)
for name in ("Frame", "Grip", "Trigger", "BreechLatch", "ShellUpper", "ShellLower", "BarrelNeon"):
    dress(name)
dress("Neon", keep=lambda island: not (limits(island, 1)[0] > 0.08 and limits(island, 2)[0] > 0.2))
dress("Barrels", slots={"Dark": ARMOR, "Grip": OBSIDIAN, "Body": ARMOR, "Panel": FROSTSTEEL, "Accent": FROSTSTEEL},
      keep=lambda island: limits(island, 0)[0] < 1.35)


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


BARRELS = native("Barrels")
gap_moves = {
    "rib_and_web_front": nudge(BARRELS, lambda p: p.x > 1.355, (0.010, 0, 0),
                               lambda lo, hi: hi.y < 0.017 and lo.y > -0.017 and abs(hi.x - 1.36) < 0.002),
}

# ---------------------------------------------------------------- frame cryo-core bay (Root, y .0835+ clears Shell)
bay_l = side("FB_CoreBay_Left",
             [(0.025, 0.226), (0.502, 0.226), (0.515, 0.244), (0.515, 0.295), (0.045, 0.295), (0.010, 0.248)],
             0.0835, 0.102, ARMOR)
recess(bay_l, "FB_CoreChasm_Left",
       [(0.042, 0.236), (0.486, 0.236), (0.498, 0.252), (0.498, 0.286), (0.056, 0.286), (0.028, 0.248)],
       0.092, 0.13, role=OBSIDIAN)
swept_rib("FB_CoreFissure_Left", [
    (0.055, 0.097, 0.262, 0.004, 0.005),
    (0.275, 0.098, 0.260, 0.005, 0.006),
    (0.478, 0.097, 0.264, 0.004, 0.005),
], CRYO_GLOW, flat_group="FBCoreFissure")
glacier_cluster("FB_CoreCrystals_Left", [
    {"points_xz": [(0.058, 0.244), (0.165, 0.232), (0.285, 0.250), (0.245, 0.282), (0.085, 0.278)],
     "base_y": 0.091, "shoulder_y": 0.110, "crest_y": 0.120, "ridge_bias": (-0.010, 0.003)},
    {"points_xz": [(0.315, 0.244), (0.405, 0.232), (0.485, 0.250), (0.445, 0.282), (0.335, 0.278)],
     "base_y": 0.091, "shoulder_y": 0.112, "crest_y": 0.122,
     "roles": (ICE_MID, ICE_MID, ICE_BRIGHT), "ridge_bias": (-0.008, 0.003)},
])
glacier_shard(
    "FB_CoreHeart_Left",
    [(0.252, 0.264), (0.284, 0.248), (0.316, 0.262), (0.286, 0.278)],
    0.095, 0.116, 0.126, roles=(GLOW_WHITE, GLOW_WHITE, GLOW_WHITE),
    ridge_bias=(-0.004, 0.002), flat_group="FBCoreHeart",
)

# Right frame recess cryo armor (x .09..32, z .105..205)
armor_plate("FB_FrameWing_Right", [(0.090, 0.098), (0.315, 0.098), (0.325, 0.202), (0.090, 0.200)],
            -0.0835, -0.100, -0.106, FROSTSTEEL, rim_role=ARMOR, inset=0.005)
glacier_cluster("FB_CoreCrystals_Right", [
    {"points_xz": [(0.115, 0.118), (0.215, 0.108), (0.305, 0.135), (0.275, 0.188), (0.125, 0.180)],
     "base_y": -0.091, "shoulder_y": -0.110, "crest_y": -0.120, "ridge_bias": (-0.008, 0.004)},
])

# ---------------------------------------------------------------- forend cryo jaws & crystals (Barrels bone, clear of Charm at .74, .116, .215)
for sign, label in ((1, "Left"), (-1, "Right")):
    armor_plate(
        f"FB_ForeJawFront_{label}",
        [(0.965, 0.056), (1.165, 0.060), (1.205, 0.110), (1.175, 0.165), (0.975, 0.162)],
        0.080 * sign, 0.098 * sign, 0.104 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.006, bone="Barrels",
    )
    swept_rib(f"FB_ForeSeam_{label}", [
        (0.892, 0.092 * sign, 0.034, 0.004, 0.005),
        (1.045, 0.093 * sign, 0.034, 0.005, 0.006),
        (1.185, 0.092 * sign, 0.034, 0.004, 0.005),
    ], CRYO_GLOW, bone="Barrels", flat_group="FBForeSeam")
    glacier_cluster(f"FB_ForeCrystals_{label}", [
        {"points_xz": [(0.915, 0.075), (1.035, 0.062), (1.175, 0.092), (1.125, 0.150), (0.935, 0.142)],
         "base_y": 0.082 * sign, "shoulder_y": 0.106 * sign, "crest_y": 0.118 * sign, "ridge_bias": (-0.012, 0.004)},
    ], bone="Barrels")

# ---------------------------------------------------------------- binocular muzzle block (Barrels bone)
MZ = 0.26
BLOCK = [(-0.078, 0.056), (0.078, 0.056), (0.108, 0.026), (0.108, -0.026),
         (0.078, -0.056), (-0.078, -0.056), (-0.108, -0.026), (-0.108, 0.026)]


def ring(x, s):
    return [(x, y * s, MZ + z * s) for y, z in BLOCK]


block = loft("FB_MuzzleBlock", [ring(x, s) for x, s in (
    (1.338, 0.92), (1.346, 1.0), (1.392, 1.0), (1.392, 0.92), (1.418, 0.92), (1.418, 1.0),
    (1.440, 1.0), (1.450, 0.90),
)], FROSTSTEEL, bone="Barrels")
for i, cy in enumerate((0.05, -0.05)):
    cut = loft(f"FB_MuzzleBore_{i + 1}", [
        [(x, cy + u, MZ + v) for u, v in polygon(0, 0, 0.0292, 8)] for x in (1.300, 1.480)
    ], OBSIDIAN, bone="Barrels", cutter=True)
    bore = block.modifiers.new(f"Bore {i + 1}", "BOOLEAN")
    bore.operation = "DIFFERENCE"
    bore.solver = "EXACT"
    bore.object = cut
loft("FB_MuzzleGlow", [ring(1.389, 0.965), ring(1.421, 0.965), ring(1.421, 0.88), ring(1.389, 0.88)],
     CRYO_GLOW, bone="Barrels", loop=True)["flat_group"] = "FBMuzzleGlow"
glacier_cluster("FB_MuzzleIce", [
    {"points_xz": [(1.342, 0.190), (1.385, 0.174), (1.435, 0.194), (1.402, 0.214)],
     "base_y": 0.018, "shoulder_y": -0.018, "crest_y": -0.028, "ridge_bias": (-0.008, -0.005)},
    {"points_xz": [(1.342, 0.190), (1.385, 0.174), (1.435, 0.194), (1.402, 0.214)],
     "base_y": -0.018, "shoulder_y": 0.018, "crest_y": 0.028, "ridge_bias": (-0.008, -0.005)},
], bone="Barrels")

# ---------------------------------------------------------------- animated flat_groups (Root frame & Barrels forend)
glacier_cluster("FB_GrowRear", [
    {"points_xz": [(0.045, 0.242), (0.155, 0.230), (0.275, 0.246), (0.235, 0.276), (0.075, 0.272)],
     "base_y": 0.092, "shoulder_y": 0.112, "crest_y": 0.122,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.010, 0.003)},
    {"points_xz": [(0.115, 0.135), (0.205, 0.125), (0.295, 0.142), (0.265, 0.182), (0.135, 0.175)],
     "base_y": -0.090, "shoulder_y": -0.112, "crest_y": -0.122,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.008, 0.003)},
], flat_group="FBGrowRear")

glacier_cluster("FB_GrowMid", [
    {"points_xz": [(0.305, 0.246), (0.395, 0.234), (0.485, 0.250), (0.455, 0.280), (0.325, 0.274)],
     "base_y": 0.092, "shoulder_y": 0.112, "crest_y": 0.122,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.008, 0.003)},
    {"points_xz": [(0.185, 0.140), (0.265, 0.130), (0.335, 0.148), (0.305, 0.188), (0.205, 0.180)],
     "base_y": -0.092, "shoulder_y": -0.112, "crest_y": -0.122,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.008, 0.003)},
], flat_group="FBGrowMid")

glacier_cluster("FB_GrowFront", [
    {"points_xz": [(0.925, 0.088), (1.035, 0.074), (1.165, 0.096), (1.125, 0.136), (0.955, 0.128)],
     "base_y": 0.086, "shoulder_y": 0.108, "crest_y": 0.120,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.012, 0.004)},
    {"points_xz": [(0.925, 0.088), (1.035, 0.074), (1.165, 0.096), (1.125, 0.136), (0.955, 0.128)],
     "base_y": -0.086, "shoulder_y": -0.108, "crest_y": -0.120,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.012, 0.004)},
], bone="Barrels", flat_group="FBGrowFront")

glacier_shard(
    "FB_Shard1", [(0.085, 0.244), (0.185, 0.232), (0.295, 0.248), (0.255, 0.278), (0.105, 0.272)],
    0.096, 0.116, 0.126, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.008, 0.003), flat_group="FBShard1",
)
glacier_shard(
    "FB_Shard2", [(0.945, 0.082), (1.045, 0.070), (1.155, 0.090), (1.115, 0.128), (0.965, 0.122)],
    0.092, 0.112, 0.124, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.010, 0.003), bone="Barrels", flat_group="FBShard2",
)
glacier_shard(
    "FB_Shard3", [(0.125, 0.122), (0.215, 0.110), (0.305, 0.132), (0.275, 0.172), (0.145, 0.165)],
    -0.096, -0.116, -0.126, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.008, 0.003), flat_group="FBShard3",
)
glacier_shard(
    "FB_Shard4", [(0.945, 0.082), (1.045, 0.070), (1.155, 0.090), (1.115, 0.128), (0.965, 0.122)],
    -0.092, -0.112, -0.124, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.010, 0.003), bone="Barrels", flat_group="FBShard4",
)


def sight_line_hits():
    depsgraph = bpy.context.evaluated_depsgraph_get()
    bpy.context.view_layer.update()
    hits = set()
    eye = Vector((-0.40, 0, 0.352))
    target = Vector((1.325, 0, 0.346))
    for dy, dz in ((0, 0), (0.010, 0), (-0.010, 0), (0, 0.010), (0, -0.004)):
        origin = eye + Vector((0, dy, dz))
        direction = (target + Vector((0, dy, dz)) - origin).normalized()
        hit, _loc, _n, _i, obj, _m = scene.ray_cast(depsgraph, origin, direction, distance=1.9)
        if hit and obj.name.startswith("FB_"):
            hits.add(obj.name)
    return sorted(hits)


def charm_clearance():
    from mathutils.bvhtree import BVHTree
    depsgraph = bpy.context.evaluated_depsgraph_get()
    point = Vector((0.74, 0.116, 0.215))
    probes = [point - Vector((0, 0, 0.015 * k)) for k in range(7)]
    best = (9.0, None)
    for obj in shells.objects:
        if obj.type != "MESH" or obj.hide_render:
            continue
        ev = obj.evaluated_get(depsgraph)
        mesh = ev.to_mesh()
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bm.transform(ev.matrix_world)
        tree = BVHTree.FromBMesh(bm)
        for probe in probes:
            hit = tree.find_nearest(probe)
            if hit[0] is not None and hit[3] < best[0]:
                best = (round(hit[3], 4), obj.name)
        bm.free()
        ev.to_mesh_clear()
    return best


result = finish_master(bay_l)
result["gap_moves"] = gap_moves
result["sight_line_new_hits"] = sight_line_hits()
result["charm_clearance"] = charm_clearance()
