"""Frostbite Knife (Tier 30 chase melee) v01: Legendary sculpted cryo-crystalline combat dagger.

Built on Knife_RemasterV2_v05.blend keeping Knife_Rig, Root bone, Knife_RightGrip, Knife_BladeBase,
Knife_BladeTip, and all 7 Knife_* actions intact within the 1.5x triangle budget (<= 2106 tris).
"""

from pathlib import Path

import bpy
from mathutils import Vector

GUN = "Knife"
VERSION = globals().get("VERSION", "v02")
exec((Path(bpy.data.filepath).parents[4] / "tools/blender/frostbite/frost_lib.py").read_text(encoding="utf-8"))

replace("Blade", "Hilt", "Neon")

# ---------------------------------------------------------------- handle grip (x -.36..+.30, wraps RightGrip)
# Asymmetric faceted octagonal grip with recessed Obsidian palm channels & Grip wraps (joins buried 0.02+).
def grip_sec(x, hy, hz, waist=0.0):
    sy, sz = hy * (1.0 - waist), hz * (1.0 - waist)
    cy, cz = sy * 0.56, sz * 0.58
    return [
        (x,  cy,  sz), (x, -cy,  sz), (x, -sy,  cz), (x, -sy, -cz),
        (x, -cy, -sz), (x,  cy, -sz), (x,  sy, -cz), (x,  sy,  cz),
    ]


hilt = loft("FB_GripBody", [
    grip_sec(-0.375, 0.036, 0.044),
    grip_sec(-0.240, 0.044, 0.054),
    grip_sec(-0.080, 0.048, 0.060),
    grip_sec( 0.080, 0.046, 0.056),
    grip_sec( 0.215, 0.044, 0.054),
    grip_sec( 0.305, 0.052, 0.064),
], ARMOR)

# Faceted grip wrap ribs (buried inside grip)
for k, x in enumerate((-0.20, -0.09, 0.02, 0.13)):
    loft(f"FB_GripWrap_{k + 1}", [
        grip_sec(x - 0.022, 0.051, 0.062),
        grip_sec(x,         0.054, 0.066),
        grip_sec(x + 0.022, 0.051, 0.062),
    ], GRIP)

# Swept faceted pommel spike & glowing core ring (x -.46..-.34)
loft("FB_PommelCap", [
    grip_sec(-0.465, 0.016, 0.022),
    grip_sec(-0.415, 0.048, 0.060),
    grip_sec(-0.375, 0.056, 0.072),
    grip_sec(-0.345, 0.048, 0.060),
], FROSTSTEEL)
loft("FB_PommelGlow", [
    grip_sec(-0.412, 0.045, 0.056),
    grip_sec(-0.382, 0.045, 0.056),
], CRYO_GLOW, flat_group="FBKnifePommel")

# ---------------------------------------------------------------- swept cryo crossguard wings (x .265..385)
guard = side("FB_Crossguard", [
    (0.275, -0.098), (0.315, -0.116), (0.368, -0.090), (0.378, -0.040),
    (0.378,  0.048), (0.362,  0.120), (0.305,  0.132), (0.272,  0.096),
], -0.066, 0.066, FROSTSTEEL, bevel=0.005)

for sign, label in ((1, "Left"), (-1, "Right")):
    armor_plate(
        f"FB_GuardCollar_{label}",
        [(0.285, -0.076), (0.352, -0.068), (0.362, 0.072), (0.282, 0.082)],
        0.048 * sign, 0.074 * sign, 0.080 * sign, ARMOR, rim_role=FROSTSTEEL, inset=0.005,
    )
    glacier_shard(
        f"FB_GuardHeart_{label}",
        [(0.296, -0.018), (0.326, -0.036), (0.354, -0.014), (0.326, 0.026)],
        0.066 * sign, 0.084 * sign, 0.092 * sign,
        roles=(GLOW_WHITE, GLOW_WHITE, GLOW_WHITE),
        ridge_bias=(-0.004, 0.002),
        flat_group="FBCoreHeart",
    )

# ---------------------------------------------------------------- crystalline cryo blade (x .345..1.268, Knife_BladeTip at 1.2674)
# Spine armor collar gripping blade ricasso (buried into Crossguard to .330)
side("FB_BladeSpineCollar", [
    (0.330, 0.018), (0.640, 0.024), (0.695, 0.056), (0.640, 0.068), (0.330, 0.064),
], -0.022, 0.022, OBSIDIAN, bevel=0.003)

# Swept chiseled ice blade body (tapered faceted diamond profile along x .340..1.268)
# Each ring: top spine, left fuller bevel, bottom cutting edge, right fuller bevel.
def blade_sec(x, spine_z, edge_z, half_w, flat_off=0.0):
    mid_z = edge_z + (spine_z - edge_z) * 0.42
    return [
        (x, 0.0, spine_z),
        (x, half_w, mid_z + flat_off),
        (x, 0.0, edge_z),
        (x, -half_w, mid_z + flat_off),
    ]


blade = loft("FB_CryoBlade", [
    blade_sec(0.340,  0.060, -0.072, 0.020),
    blade_sec(0.520,  0.064, -0.084, 0.022),
    blade_sec(0.760,  0.060, -0.080, 0.020),
    blade_sec(1.010,  0.048, -0.062, 0.016),
    blade_sec(1.165,  0.028, -0.034, 0.010),
    blade_sec(1.268,  0.002, -0.004, 0.002),
], [ICE_DEEP, ICE_MID, ICE_MID, ICE_BRIGHT, ICE_BRIGHT])

# Dorsal FrostSteel spine ridge serrations along top back of blade (buried 0.01+ into blade body)
armor_plate("FB_BladeSpineFin", [
    (0.355, 0.042), (0.585, 0.048), (0.795, 0.044), (0.945, 0.032), (0.745, 0.020), (0.355, 0.024),
], -0.015, 0.015, 0.020, FROSTSTEEL, rim_role=ARMOR, inset=0.004)

# Glowing Cryo fuller channel running along both faces of the blade (x .375..1.11)
for sign, label in ((1, "Left"), (-1, "Right")):
    swept_rib(f"FB_BladeFuller_{label}", [
        (0.375, 0.016 * sign, -0.008, 0.005, 0.008),
        (0.640, 0.017 * sign, -0.006, 0.005, 0.009),
        (0.920, 0.014 * sign, -0.004, 0.004, 0.007),
        (1.105, 0.009 * sign, -0.002, 0.003, 0.005),
    ], CRYO_GLOW, flat_group="FBKnifeGlow")

# ---------------------------------------------------------------- animated inspect/kill crystal clusters (Root)
glacier_cluster("FB_GrowRear", [
    {"points_xz": [(0.355, -0.028), (0.455, -0.042), (0.565, -0.026), (0.525, 0.022), (0.385, 0.016)],
     "base_y": 0.014, "shoulder_y": 0.032, "crest_y": 0.040,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.010, 0.003)},
    {"points_xz": [(0.355, -0.028), (0.455, -0.042), (0.565, -0.026), (0.525, 0.022), (0.385, 0.016)],
     "base_y": -0.014, "shoulder_y": -0.032, "crest_y": -0.040,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.010, 0.003)},
], flat_group="FBGrowRear")

glacier_cluster("FB_GrowMid", [
    {"points_xz": [(0.595, -0.030), (0.715, -0.044), (0.835, -0.028), (0.785, 0.024), (0.625, 0.018)],
     "base_y": 0.013, "shoulder_y": 0.031, "crest_y": 0.039,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.010, 0.003)},
    {"points_xz": [(0.595, -0.030), (0.715, -0.044), (0.835, -0.028), (0.785, 0.024), (0.625, 0.018)],
     "base_y": -0.013, "shoulder_y": -0.031, "crest_y": -0.039,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.010, 0.003)},
], flat_group="FBGrowMid")

glacier_cluster("FB_GrowFront", [
    {"points_xz": [(0.865, -0.024), (0.975, -0.036), (1.085, -0.020), (1.035, 0.022), (0.895, 0.016)],
     "base_y": 0.011, "shoulder_y": 0.027, "crest_y": 0.034,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.008, 0.003)},
    {"points_xz": [(0.865, -0.024), (0.975, -0.036), (1.085, -0.020), (1.035, 0.022), (0.895, 0.016)],
     "base_y": -0.011, "shoulder_y": -0.027, "crest_y": -0.034,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.008, 0.003)},
], flat_group="FBGrowFront")

glacier_shard(
    "FB_Shard1", [(0.425, -0.016), (0.525, -0.030), (0.635, -0.014), (0.585, 0.024), (0.455, 0.018)],
    0.016, 0.034, 0.042, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.010, 0.003), flat_group="FBShard1",
)
glacier_shard(
    "FB_Shard2", [(0.745, -0.018), (0.855, -0.030), (0.975, -0.012), (0.925, 0.022), (0.775, 0.016)],
    0.014, 0.032, 0.040, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.010, 0.003), flat_group="FBShard2",
)
glacier_shard(
    "FB_Shard3", [(0.425, -0.016), (0.525, -0.030), (0.635, -0.014), (0.585, 0.024), (0.455, 0.018)],
    -0.016, -0.034, -0.042, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.010, 0.003), flat_group="FBShard3",
)
glacier_shard(
    "FB_Shard4", [(0.745, -0.018), (0.855, -0.030), (0.975, -0.012), (0.925, 0.022), (0.775, 0.016)],
    -0.014, -0.032, -0.040, roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.010, 0.003), flat_group="FBShard4",
)

result = finish_master(blade)
