"""Frostbite Classic v01: Legendary sculpted cryo-armor pistol remodel."""

from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

GUN = "Classic"
VERSION = globals().get("VERSION", "v02")
exec((Path(bpy.data.filepath).parents[4] / "tools/blender/frostbite/frost_lib.py").read_text(encoding="utf-8"))

# ---------------------------------------------------------------- retained stock (CharmLoop untouched)
for name in ("SlideNeon", "Barrel", "Frame", "Pins", "Trigger", "SlideCatch", "MagRelease", "MagNeon"):
    dress(name)
dress("Grip")
dress("Slide", copy_name="FB_SlideSights", keep=lambda island: limits(island, 0)[1] - limits(island, 0)[0] < 1.0)
SLIDE = dress("Slide", keep=lambda island: limits(island, 0)[1] - limits(island, 0)[0] > 1.0)


def hex_along(name, origin, axis, profile, roles, *, bone="Root", flat_group=None):
    origin = Vector(origin)
    axis = Vector(axis).normalized()
    helper = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))
    u = axis.cross(helper).normalized()
    v = axis.cross(u).normalized()
    sections = [[tuple(origin + axis * t + u * a + v * b) for a, b in polygon(0, 0, radius, 6, 0)]
                for t, radius in profile]
    return loft(name, sections, roles, bone=bone, flat_group=flat_group)


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


dress("Magazine", slots={"Dark": GRIP, "Body": ARMOR, "Panel": OBSIDIAN, "Accent": FROSTSTEEL})
gap_moves = {
    "mag_body_into_baseplate": nudge(native("Magazine"), lambda p: p.z < -0.29, (0, 0, -0.022),
                                     lambda lo, hi: hi.y < 0.06 and lo.z > -0.30 and hi.z > 0.1),
}


def tube(name, z, outer, inner, role, *, bone, flat_group=None):
    sections = [[(x, r * math.cos(a), z + r * math.sin(a)) for a in
                 (math.pi / 8 + math.pi / 4 * i for i in range(8))] for x, r in (*outer, *inner)]
    return loft(name, sections, role, bone=bone, loop=True, flat_group=flat_group)


# ---------------------------------------------------------------- frame left core bay & right grip cryo armor
bay_l = side("FB_CoreBay_Left",
             [(-0.145, 0.184), (0.242, 0.184), (0.258, 0.205), (0.254, 0.264), (-0.132, 0.264), (-0.148, 0.236)],
             0.064, 0.084, ARMOR)
recess(bay_l, "FB_CoreChasm_Left",
       [(-0.128, 0.194), (0.228, 0.194), (0.242, 0.212), (0.238, 0.254), (-0.118, 0.254), (-0.132, 0.224)],
       0.075, 0.11, role=OBSIDIAN)
swept_rib("FB_CoreFissure_Left", [
    (-0.112, 0.080, 0.224, 0.004, 0.005),
    (0.055,  0.081, 0.222, 0.005, 0.006),
    (0.215,  0.080, 0.226, 0.004, 0.005),
], CRYO_GLOW, flat_group="FBCoreFissure")
glacier_cluster("FB_CoreCrystals_Left", [
    {"points_xz": [(-0.115, 0.202), (-0.015, 0.192), (0.095, 0.208), (0.065, 0.246), (-0.085, 0.242)],
     "base_y": 0.074, "shoulder_y": 0.092, "crest_y": 0.102, "ridge_bias": (-0.010, 0.003)},
    {"points_xz": [(0.115, 0.204), (0.185, 0.194), (0.236, 0.214), (0.205, 0.248), (0.125, 0.244)],
     "base_y": 0.074, "shoulder_y": 0.093, "crest_y": 0.103,
     "roles": (ICE_MID, ICE_MID, ICE_BRIGHT), "ridge_bias": (-0.008, 0.003)},
])
glacier_shard(
    "FB_CoreHeart_Left",
    [(0.068, 0.226), (0.098, 0.212), (0.128, 0.224), (0.100, 0.240)],
    0.076, 0.098, 0.108, roles=(GLOW_WHITE, GLOW_WHITE, GLOW_WHITE),
    ridge_bias=(-0.004, 0.002), flat_group="FBCoreHeart",
)

# Right frame + grip cryo armor (staying clear of Mag inside y -.05)
armor_plate("FB_GripWing_Right", [(-0.105, -0.175), (0.088, -0.175), (0.096, -0.008), (-0.095, -0.008)],
            -0.056, -0.074, -0.080, FROSTSTEEL, rim_role=ARMOR, inset=0.006)
glacier_cluster("FB_CoreCrystals_Right", [
    {"points_xz": [(-0.075, -0.145), (0.025, -0.155), (0.075, -0.045), (-0.045, -0.035)],
     "base_y": -0.062, "shoulder_y": -0.084, "crest_y": -0.094, "ridge_bias": (-0.008, 0.004)},
])
hex_along("FB_CoreFissure_Right", (0.655, -0.069, 0.205), (1, 0, 0),
          [(0, 0.003), (0.008, 0.0068), (0.272, 0.0068), (0.280, 0.003)], CRYO_GLOW, flat_group="FBCoreFissure")

# ---------------------------------------------------------------- slide cryo shroud (bone Slide)
FIELD_L = [(0.300, 0.342), (0.312, 0.342), (0.312, 0.330), (0.324, 0.330), (0.324, 0.318),
           (0.668, 0.318), (0.690, 0.340), (0.690, 0.418), (0.670, 0.438), (0.316, 0.438), (0.300, 0.422)]
recess(SLIDE, "FB_SlideChasm_Left", FIELD_L, 0.064, 0.15, role=OBSIDIAN, bone="Slide")
armor_plate("FB_SlideJawRear_Left", [(0.085, 0.305), (0.305, 0.305), (0.325, 0.432), (0.105, 0.428)],
            0.064, 0.082, 0.088, FROSTSTEEL, rim_role=ARMOR, inset=0.006, bone="Slide")
armor_plate("FB_SlideJawFront_Left", [(0.725, 0.300), (0.945, 0.305), (0.965, 0.428), (0.735, 0.432)],
            0.064, 0.082, 0.088, FROSTSTEEL, rim_role=ARMOR, inset=0.006, bone="Slide")
armor_plate("FB_SlideJawFront_Right", [(0.725, 0.300), (0.945, 0.305), (0.965, 0.428), (0.735, 0.432)],
            -0.064, -0.082, -0.088, FROSTSTEEL, rim_role=ARMOR, inset=0.006, bone="Slide")
armor_plate("FB_SlideJawRear_Right", [(-0.085, 0.305), (0.295, 0.305), (0.315, 0.425), (-0.065, 0.422)],
            -0.064, -0.080, -0.086, ARMOR, rim_role=FROSTSTEEL, inset=0.006, bone="Slide")
swept_rib("FB_ForeSeam_Left", [
    (0.325, 0.071, 0.372, 0.004, 0.005),
    (0.505, 0.072, 0.378, 0.005, 0.006),
    (0.665, 0.071, 0.384, 0.004, 0.005),
], CRYO_GLOW, bone="Slide", flat_group="FBForeSeam")
glacier_cluster("FB_ForeCrystals_Left", [
    {"points_xz": [(0.335, 0.340), (0.485, 0.326), (0.655, 0.352), (0.615, 0.415), (0.365, 0.405)],
     "base_y": 0.064, "shoulder_y": 0.084, "crest_y": 0.096, "ridge_bias": (-0.012, 0.004)},
], bone="Slide")
glacier_cluster("FB_ForeCrystals_Right", [
    {"points_xz": [(-0.025, 0.325), (0.125, 0.315), (0.275, 0.335), (0.235, 0.395), (0.015, 0.388)],
     "base_y": -0.066, "shoulder_y": -0.086, "crest_y": -0.096, "ridge_bias": (-0.010, 0.004)},
], bone="Slide")

# ---------------------------------------------------------------- muzzle collar (bone Slide, x .979..1.031, z .3654)
BORE_Z = 0.3654
tube("FB_MuzzleCollar", BORE_Z, [(0.979, 0.046), (1.012, 0.046), (1.012, 0.040), (1.022, 0.040),
                                 (1.022, 0.046), (1.031, 0.040)],
     [(1.031, 0.035), (0.979, 0.035)], FROSTSTEEL, bone="Slide")
tube("FB_MuzzleGlow", BORE_Z, [(1.011, 0.0445), (1.023, 0.0445)], [(1.023, 0.0375), (1.011, 0.0375)],
     CRYO_GLOW, bone="Slide", flat_group="FBMuzzleGlow")

# ---------------------------------------------------------------- mag glow & cowl (bone Mag)
for sign, label in ((1, "Left"), (-1, "Right")):
    side(f"FB_MagGlow_{label}", [(0.030, -0.366), (0.052, -0.366), (0.078, -0.322), (0.056, -0.322)],
         0.067 * sign, 0.075 * sign, CRYO_GLOW, bone="Mag")["flat_group"] = "FBMagGlow"

# ---------------------------------------------------------------- animated flat_groups (Root, clear of moved Charm at (.74, .084, .205))
glacier_cluster("FB_GrowRear", [
    {"points_xz": [(-0.115, 0.218), (0.015, 0.208), (0.145, 0.222), (0.105, 0.248), (-0.085, 0.244)],
     "base_y": 0.070, "shoulder_y": 0.088, "crest_y": 0.098,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.010, 0.003)},
    {"points_xz": [(-0.085, -0.105), (-0.005, -0.115), (0.065, -0.095), (0.045, -0.055), (-0.065, -0.065)],
     "base_y": -0.066, "shoulder_y": -0.084, "crest_y": -0.094,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.008, 0.003)},
], flat_group="FBGrowRear")

glacier_cluster("FB_GrowMid", [
    {"points_xz": [(0.025, 0.225), (0.125, 0.215), (0.235, 0.230), (0.195, 0.255), (0.055, 0.250)],
     "base_y": 0.072, "shoulder_y": 0.090, "crest_y": 0.100,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.008, 0.003)},
    {"points_xz": [(0.655, 0.220), (0.765, 0.212), (0.895, 0.224), (0.855, 0.248), (0.695, 0.244)],
     "base_y": -0.070, "shoulder_y": -0.088, "crest_y": -0.098,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.010, 0.003)},
], flat_group="FBGrowMid")

glacier_cluster("FB_GrowFront", [
    {"points_xz": [(0.685, 0.212), (0.795, 0.204), (0.915, 0.218), (0.875, 0.244), (0.715, 0.238)],
     "base_y": -0.068, "shoulder_y": -0.088, "crest_y": -0.098,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.010, 0.003)},
], flat_group="FBGrowFront")

glacier_shard(
    "FB_Shard1", [(-0.085, 0.202), (0.025, 0.192), (0.145, 0.206), (0.105, 0.232), (-0.055, 0.228)],
    0.078, 0.094, 0.104, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.008, 0.003), flat_group="FBShard1",
)
glacier_shard(
    "FB_Shard2", [(0.085, 0.210), (0.165, 0.200), (0.235, 0.214), (0.205, 0.238), (0.105, 0.232)],
    0.078, 0.094, 0.104, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.008, 0.003), flat_group="FBShard2",
)
glacier_shard(
    "FB_Shard3", [(-0.075, -0.125), (-0.005, -0.135), (0.065, -0.115), (0.035, -0.075), (-0.055, -0.085)],
    -0.072, -0.088, -0.098, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.008, 0.003), flat_group="FBShard3",
)
glacier_shard(
    "FB_Shard4", [(0.685, 0.196), (0.795, 0.188), (0.905, 0.202), (0.865, 0.226), (0.715, 0.220)],
    -0.074, -0.090, -0.100, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.010, 0.003), flat_group="FBShard4",
)

result = finish_master(bay_l)
result["gap_moves"] = gap_moves
