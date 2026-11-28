"""Frostbite Havoc (Vandal) v03: Slipframe-inspired dark cold-forged chassis with swept
faceted glacial crystal slabs, exposed cryo-heart core bay, dorsal crystal crest ridges
(no thin needles), skeleton crystal stock, fang muzzle crown, cryo-sheathed magazine,
clean ADS silhouette, and zero coplanar faces.

Run in the live Blender MCP session with the stock
art-source/weapons/RemasterV2/Vandal/Vandal_RemasterV2_v05.blend open:
    VERSION = "v03"; exec(open("tools/blender/frostbite/10_vandal.py").read())
Left (+y) is the player-facing side. Stock sights, rig, locators and CharmLoop are kept.
"""

from pathlib import Path

import bpy

GUN = "Vandal"
VERSION = globals().get("VERSION", "v06")
exec((Path(bpy.data.filepath).parents[4] / "tools/blender/frostbite/frost_lib.py").read_text(encoding="utf-8"))

replace("Handguard", "Stock", "Barrel", "Neon")

# ---------------------------------------------------------------- retained stock + gap sweep
for name in ("Receiver", "Rail", "CharmLoop", "ChargingHandle", "Bolt",
             "FireSelector", "Trigger", "Grip", "RearSight", "FrontSight"):
    dress(name)

# Keep only receiver & front-sight pins so no stock pin floats inside the skeleton stock or shroud.
dress("Pins", keep=lambda island: (0.0 < limits(island, 0)[0] and limits(island, 0)[1] < 1.06) or limits(island, 0)[0] > 1.88)
dress("Mag", slots={"Dark": GRIP, "Body": ARMOR, "Panel": OBSIDIAN, "Accent": FROSTSTEEL})
# Barrel without stock muzzle brake (x < 2.38).
dress("Barrel", copy_name="FB_BarrelTube", keep=lambda island: limits(island, 0)[0] < 2.38)

GUARD = lambda lo, hi: lo.x > 0.11 and hi.x > 0.4
gap_moves = {
    "guard_post_forward": nudge(native("Grip"), lambda p: p.x > 0.36, (0.031, 0, 0), GUARD),
    "guard_post_up": nudge(native("Grip"), lambda p: p.z > 0.14, (0, 0, 0.031), GUARD),
    "guard_rear": nudge(native("Grip"), lambda p: p.x < 0.127, (-0.024, 0, 0), GUARD),
    "rail_spine": nudge(native("Rail"), lambda p: p.x < 0.801, (-0.025, 0, 0),
                        lambda lo, hi: lo.x > 0.79 and hi.x > 1.55 and hi.z < 0.43),
    "gas_tube": nudge(bpy.data.objects["FB_BarrelTube"], lambda p: p.x > 1.955, (0.020, 0, 0),
                      lambda lo, hi: lo.z > 0.31),
    "barrel_end": nudge(bpy.data.objects["FB_BarrelTube"], lambda p: p.x > 2.385, (0.012, 0, 0),
                        lambda lo, hi: hi.x > 2.3),
    "front_sight_tower": nudge(native("FrontSight"), lambda p: p.z < 0.3875, (0, 0, -0.018),
                               lambda lo, hi: lo.z > 0.38 and hi.z > 0.59),
    "rear_sight_post": nudge(native("RearSight"), lambda p: p.z < 0.459, (0, 0, -0.018),
                             lambda lo, hi: lo.z > 0.45 and hi.z < 0.5 and hi.y < 0.03),
}

# ---------------------------------------------------------------- swept cryo receiver mantle
# Clears Vandal_Receiver completely (top z_max=0.428 at 0.15..0.85, 0.400 at 1.00) with zero clipping,
# leaving Vandal_Rail teeth (z=0.435..0.476) crisp and proud, and flowing directly into FB_ForeShroud.
mantle = folded("FB_ReceiverMantle", (
    (-0.180, 0.352, 0.418, 0.088, 0.402, 0.366, 0.056),
    (-0.045, 0.350, 0.434, 0.100, 0.416, 0.368, 0.058),
    (0.795, 0.350, 0.434, 0.100, 0.416, 0.368, 0.058),
    (0.905, 0.292, 0.428, 0.100, 0.408, 0.318, 0.057),
    (1.035, 0.232, 0.420, 0.098, 0.398, 0.264, 0.055),
    (1.135, 0.214, 0.416, 0.096, 0.392, 0.246, 0.054),
), [ARMOR, ARMOR, ARMOR, FROSTSTEEL, ARMOR], bevel=0.0025)

for sign, label in ((1, "Left"), (-1, "Right")):
    recess(mantle, f"FB_MantleRecess_{label}",
           [(0.175, 0.382), (0.212, 0.408), (0.748, 0.408), (0.714, 0.382)],
           0.080 * sign, 0.13 * sign, role=OBSIDIAN)
    side(f"FB_MantlePlate_{label}",
         [(0.190, 0.386), (0.218, 0.404), (0.734, 0.404), (0.708, 0.386)],
         0.074 * sign, 0.091 * sign, FROSTSTEEL, bevel=0.0012)
    seam = side(f"FB_UpperSeam_{label}",
                [(0.230, 0.390), (0.242, 0.396), (0.692, 0.396), (0.680, 0.390)],
                0.085 * sign, 0.095 * sign, CRYO_GLOW)
    seam["flat_group"] = "FBUpperSeam"

# Sleek angled side wing cheek bridging receiver to fore-end cleanly below mantle shoulder (no coplanar overlap)
for sign, label in ((1, "Left"), (-1, "Right")):
    side(f"FB_BridgeCheek_{label}",
         [(0.835, 0.308), (1.035, 0.238), (1.125, 0.238), (1.125, 0.376), (0.935, 0.386), (0.835, 0.344)],
         0.084 * sign, 0.107 * sign, FROSTSTEEL, bevel=0.002)

# ---------------------------------------------------------------- lower receiver cryo-core chamber
# Below ChargingHandle/Bolt track (z <= 0.268) and clear of CharmPoint (x=0.93).
CHAMBER_OUTLINE = [(0.140, 0.178), (0.742, 0.178), (0.778, 0.214), (0.752, 0.266), (0.165, 0.266), (0.130, 0.232)]
for sign, label in ((1, "Left"), (-1, "Right")):
    housing = side(f"FB_CoreHousing_{label}", CHAMBER_OUTLINE, 0.078 * sign, 0.106 * sign, ARMOR, bevel=0.002)
    recess(housing, f"FB_CorePocket_{label}",
           [(0.180, 0.190), (0.698, 0.190), (0.732, 0.224), (0.708, 0.254), (0.195, 0.254), (0.170, 0.226)],
           0.088 * sign, 0.14 * sign, role=OBSIDIAN)
    fissure = side(f"FB_CoreFissure_{label}",
                   [(0.215, 0.217), (0.675, 0.217), (0.692, 0.223), (0.675, 0.229), (0.215, 0.229), (0.198, 0.223)],
                   0.081 * sign, 0.090 * sign, CRYO_GLOW)
    fissure["flat_group"] = "FBCoreFissure"
    # Containment jaw brackets gripping front & rear ends of the cryo bay
    side(f"FB_CoreJawFront_{label}",
         [(0.640, 0.176), (0.748, 0.176), (0.772, 0.216), (0.748, 0.268), (0.680, 0.268), (0.708, 0.224)],
         0.092 * sign, 0.114 * sign, FROSTSTEEL, bevel=0.0015)
    side(f"FB_CoreJawRear_{label}",
         [(0.136, 0.176), (0.215, 0.176), (0.190, 0.225), (0.225, 0.268), (0.160, 0.268), (0.128, 0.232)],
         0.092 * sign, 0.114 * sign, FROSTSTEEL, bevel=0.0015)

# Sculpted swept glacier crystal slabs framing the exposed glowing cryo-heart (distinct y planes = 0 coplanar!)
for sign, label in ((1, "Left"), (-1, "Right")):
    crystal_blade(
        f"FB_CoreGlacierRear_{label}",
        [(0.225, 0.208), (0.345, 0.196), (0.435, 0.220), (0.405, 0.246), (0.275, 0.242)],
        0.087 * sign, 0.106 * sign, 0.120 * sign,
    )
    crystal_blade(
        f"FB_CoreGlacierFront_{label}",
        [(0.475, 0.212), (0.665, 0.198), (0.705, 0.228), (0.645, 0.252), (0.495, 0.244)],
        0.089 * sign, 0.108 * sign, 0.123 * sign,
        roles=(ICE_MID, ICE_MID, ICE_BRIGHT),
    )

# Exposed faceted diamond cryo-heart nestled cleanly between Rear and Front glacier slabs (+Y player side)
crystal_blade(
    "FB_CoreHeart_Left",
    [(0.412, 0.223), (0.455, 0.209), (0.498, 0.223), (0.455, 0.237)],
    0.086, 0.116, 0.132,
    roles=(GLOW_WHITE, GLOW_WHITE, GLOW_WHITE),
    flat_group="FBCoreHeart",
)

# ---------------------------------------------------------------- swept glacial fore-end shroud
# Continuous Slipframe-inspired angular shroud (x=1.00..1.90) with sleek taper for clean ADS.
fore = folded("FB_ForeShroud", (
    (1.000, 0.192, 0.410, 0.094, 0.386, 0.228, 0.058),
    (1.095, 0.165, 0.418, 0.110, 0.394, 0.220, 0.064),
    (1.500, 0.160, 0.418, 0.110, 0.394, 0.218, 0.064),
    (1.665, 0.184, 0.412, 0.096, 0.386, 0.232, 0.056),
    (1.815, 0.218, 0.390, 0.070, 0.370, 0.250, 0.042),
    (1.905, 0.240, 0.368, 0.052, 0.354, 0.264, 0.034),
), [ARMOR, ARMOR, ARMOR, FROSTSTEEL, ARMOR], bevel=0.003)

# Forward nose collar embracing barrel + gas tube cleanly (x=1.84..1.97)
loft("FB_ForeNoseCollar", [
    [(1.835, y, z) for y, z in ((-0.036, 0.372), (0.036, 0.372), (0.056, 0.348), (0.056, 0.256),
                                (0.038, 0.232), (-0.038, 0.232), (-0.056, 0.256), (-0.056, 0.348))],
    [(1.970, y, z) for y, z in ((-0.028, 0.362), (0.028, 0.362), (0.046, 0.338), (0.046, 0.262),
                                (0.030, 0.242), (-0.030, 0.242), (-0.046, 0.262), (-0.046, 0.338))],
], FROSTSTEEL, bevel=0.002)

FORE_TRENCH = [(1.125, 0.242), (1.168, 0.228), (1.640, 0.240), (1.710, 0.322), (1.615, 0.378), (1.155, 0.378)]
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(fore, f"FB_ForeTrench_{label}", FORE_TRENCH, 0.086 * sign, 0.145 * sign, role=OBSIDIAN)
    fseam = side(f"FB_ForeSeam_{label}",
                 [(1.175, 0.288), (1.215, 0.278), (1.610, 0.288), (1.635, 0.302), (1.595, 0.310), (1.190, 0.304)],
                 0.081 * sign, 0.091 * sign, CRYO_GLOW)
    fseam["flat_group"] = "FBForeSeam"
    # Angled FrostSteel armor cheek framing the front edge of the glacial bay
    side(f"FB_ForeArmorCheek_{label}",
         [(1.595, 0.224), (1.755, 0.244), (1.815, 0.318), (1.705, 0.386), (1.575, 0.386), (1.665, 0.318)],
         0.083 * sign, 0.112 * sign, FROSTSTEEL, bevel=0.002)
    # Tucked faceted glacier crystal slabs inside the fore-end bay (y <= 0.120 so ADS silhouette stays razor-clean!)
    crystal_blade(
        f"FB_ForeGlacierUpper_{label}",
        [(1.165, 0.306), (1.335, 0.294), (1.655, 0.314), (1.585, 0.364), (1.235, 0.362)],
        0.087 * sign, 0.106 * sign, 0.120 * sign,
    )
    crystal_blade(
        f"FB_ForeGlacierLower_{label}",
        [(1.185, 0.248), (1.420, 0.238), (1.635, 0.260), (1.555, 0.296), (1.230, 0.292)],
        0.088 * sign, 0.105 * sign, 0.118 * sign,
        roles=(ICE_DEEP, ICE_MID, ICE_BRIGHT),
    )

# Sculpted faceted lower glacial keel blade ahead of LeftGrip (x=1.32)
crystal_blade(
    "FB_ForeKeel_R",
    [(1.475, 0.155), (1.635, 0.138), (1.775, 0.212), (1.645, 0.232), (1.495, 0.210)],
    0.026, -0.026, -0.036,
)
crystal_blade(
    "FB_ForeKeel_L",
    [(1.475, 0.155), (1.635, 0.138), (1.775, 0.212), (1.645, 0.232), (1.495, 0.210)],
    -0.026, 0.026, 0.036,
)

# ---------------------------------------------------------------- swept glacial skeleton stock
stock_frame = side("FB_StockFrame", [
    (-1.140, 0.408), (-0.490, 0.402), (-0.105, 0.362), (-0.105, 0.222),
    (-0.420, 0.215), (-0.610, 0.188), (-0.980, -0.092), (-1.140, -0.156),
], -0.064, 0.064, ARMOR, bevel=0.007)
STOCK_WINDOW = [
    (-1.035, 0.052), (-0.665, 0.292), (-0.330, 0.325),
    (-0.425, 0.258), (-0.655, 0.220), (-1.035, -0.062),
]
recess(stock_frame, "FB_StockWindow", STOCK_WINDOW, -0.12, 0.12, role=OBSIDIAN)

side("FB_StockTopRib", [(-1.130, 0.378), (-0.485, 0.372), (-0.135, 0.338), (-0.135, 0.372),
                        (-0.490, 0.410), (-1.130, 0.414)], -0.068, 0.068, FROSTSTEEL, bevel=0.003)

STOCK_CRYSTAL_PTS = [(-1.125, 0.035), (-0.700, 0.312), (-0.525, 0.316), (-0.625, 0.198), (-1.125, -0.135)]
crystal_blade("FB_StockCrystal", STOCK_CRYSTAL_PTS, -0.044, 0.044, 0.058)
crystal_blade("FB_StockCrystal_R", STOCK_CRYSTAL_PTS, 0.044, -0.044, -0.058)
stock_glow = side("FB_StockGlow", [
    (-0.960, -0.015), (-0.660, 0.256), (-0.625, 0.248), (-0.925, -0.025),
], -0.050, 0.050, CRYO_GLOW)
stock_glow["flat_group"] = "FBStockGlow"

side("FB_StockCollar", [(-0.220, 0.382), (-0.115, 0.372), (-0.115, 0.214), (-0.220, 0.212)],
     -0.072, 0.072, FROSTSTEEL, bevel=0.003)

side("FB_StockButt", [
    (-1.258, 0.355), (-1.224, 0.415), (-1.105, 0.420), (-1.085, 0.362),
    (-1.085, -0.148), (-1.158, -0.184), (-1.254, -0.146),
], -0.078, 0.078, GRIP, bevel=0.009)
side("FB_StockHeelCap", [
    (-1.264, -0.080), (-1.170, -0.186), (-1.115, -0.186), (-1.115, -0.115), (-1.258, -0.010),
], -0.081, 0.081, FROSTSTEEL, bevel=0.004)

# ---------------------------------------------------------------- glacial fang muzzle crown
muzzle = folded("FB_MuzzleCrown", (
    (2.338, 0.244, 0.326, 0.038, 0.312, 0.256, 0.026),
    (2.382, 0.220, 0.352, 0.058, 0.336, 0.234, 0.044),
    (2.475, 0.222, 0.350, 0.062, 0.334, 0.236, 0.048),
    (2.605, 0.224, 0.348, 0.062, 0.332, 0.238, 0.048),
    (2.675, 0.238, 0.338, 0.048, 0.326, 0.250, 0.036),
    (2.675, 0.264, 0.306, 0.026, 0.300, 0.272, 0.018),
    (2.378, 0.262, 0.306, 0.025, 0.300, 0.270, 0.018),
    (2.338, 0.264, 0.306, 0.024, 0.300, 0.272, 0.017),
), [FROSTSTEEL, ARMOR, ARMOR, ARMOR, FROSTSTEEL, OBSIDIAN, OBSIDIAN, OBSIDIAN], loop=True)
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(muzzle, f"FB_MuzzleVent_{label}",
           [(2.435, 0.260), (2.482, 0.314), (2.592, 0.314), (2.552, 0.260)],
           0.030 * sign, 0.09 * sign, role=OBSIDIAN)
m_glow = prism_along("FB_MuzzleGlow", (2.460, 0, 0.285), (1, 0, 0), [(0, 0.044), (0.095, 0.044)], CRYO_GLOW)
m_glow["flat_group"] = "FBMuzzleGlow"
crystal_blade("FB_MuzzleIce_L", [(2.345, 0.212), (2.485, 0.192), (2.605, 0.228), (2.495, 0.252)], -0.024, 0.024, 0.038)
crystal_blade("FB_MuzzleIce_R", [(2.345, 0.212), (2.485, 0.192), (2.605, 0.228), (2.495, 0.252)], 0.024, -0.024, -0.038)

# ---------------------------------------------------------------- cryo-sheathed magazine & grip pommel
mag_shroud = side("FB_MagShroud", [
    (0.618, -0.378), (0.818, -0.418), (0.875, -0.315), (0.725, -0.060),
    (0.605, -0.060), (0.578, -0.255),
], -0.068, 0.068, ARMOR, bone="Mag", bevel=0.003)
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(mag_shroud, f"FB_MagSlot_{label}",
           [(0.660, -0.275), (0.708, -0.275), (0.698, -0.095), (0.650, -0.095)],
           0.056 * sign, 0.09 * sign, role=OBSIDIAN, bone="Mag")
    mg = side(f"FB_MagGlow_{label}", [(0.672, -0.262), (0.696, -0.262), (0.686, -0.108), (0.662, -0.108)],
              0.052 * sign, 0.063 * sign, CRYO_GLOW, bone="Mag")
    mg["flat_group"] = "FBMagGlow"
side("FB_MagRib", [
    (0.655, -0.392), (0.785, -0.418), (0.848, -0.345), (0.798, -0.285), (0.648, -0.325),
], -0.073, 0.073, FROSTSTEEL, bone="Mag", bevel=0.002)
MAG_ICE_PTS = [(0.605, -0.368), (0.675, -0.448), (0.805, -0.410), (0.745, -0.342)]
crystal_blade("FB_MagCrystal_L", MAG_ICE_PTS, -0.034, 0.034, 0.048, bone="Mag")
crystal_blade("FB_MagCrystal_R", MAG_ICE_PTS, 0.034, -0.034, -0.048, bone="Mag")

side("FB_GripPommel", [(-0.185, -0.315), (-0.015, -0.315), (0.010, -0.235), (-0.175, -0.235)],
     -0.066, 0.066, FROSTSTEEL, bevel=0.004)
crystal_blade("FB_GripIce_L", [(-0.195, -0.320), (-0.135, -0.362), (-0.035, -0.315), (-0.145, -0.275)],
              -0.028, 0.028, 0.040)
crystal_blade("FB_GripIce_R", [(-0.195, -0.320), (-0.135, -0.362), (-0.035, -0.315), (-0.145, -0.275)],
              0.028, -0.028, -0.040)

# ---------------------------------------------------------------- animated effect flat_groups (Root)
# 3 staggered inspect-growth faceted crystal crest ridges (broad sculpted slabs, NO thin needles!).
# Each flat_group exports as one MeshPart and therefore uses a single uniform material role.
def crest_fin(name, pts, near_y, far_y, ridge_y, *, flat_group=None):
    return crystal_blade(name, pts, near_y, far_y, ridge_y, roles=(ICE_MID, ICE_MID, ICE_MID), flat_group=flat_group)

# Combine left+right crest fins per inspect stage by matching flat_group name (export merges same bone+mat+flat_group)
crest_fin("FB_GrowRear_L", [(0.165, 0.373), (0.365, 0.363), (0.585, 0.379), (0.515, 0.405), (0.245, 0.403)],
          0.082, 0.103, 0.115, flat_group="FBGrowRear")
crest_fin("FB_GrowRear_R", [(0.165, 0.373), (0.365, 0.363), (0.585, 0.379), (0.515, 0.405), (0.245, 0.403)],
          -0.082, -0.103, -0.115, flat_group="FBGrowRear")

crest_fin("FB_GrowMid_L", [(0.745, 0.354), (0.935, 0.336), (1.135, 0.354), (1.065, 0.386), (0.815, 0.384)],
          0.074, 0.098, 0.112, flat_group="FBGrowMid")
crest_fin("FB_GrowMid_R", [(0.745, 0.354), (0.935, 0.336), (1.135, 0.354), (1.065, 0.386), (0.815, 0.384)],
          -0.074, -0.098, -0.112, flat_group="FBGrowMid")

crest_fin("FB_GrowFront_L", [(1.285, 0.358), (1.485, 0.348), (1.695, 0.360), (1.625, 0.386), (1.355, 0.384)],
          0.072, 0.095, 0.109, flat_group="FBGrowFront")
crest_fin("FB_GrowFront_R", [(1.285, 0.358), (1.485, 0.348), (1.695, 0.360), (1.625, 0.386), (1.355, 0.384)],
          -0.072, -0.095, -0.109, flat_group="FBGrowFront")

# 4 outer breakaway kill-shatter glacier crust blades seated cleanly over the crystal beds (>= 0.006 proud, <= 0.129y).
crystal_blade(
    "FB_Shard1",
    [(0.245, 0.214), (0.395, 0.200), (0.595, 0.216), (0.550, 0.242), (0.315, 0.238)],
    0.094, 0.114, 0.128,
    roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT),
    flat_group="FBShard1",
)
crystal_blade(
    "FB_Shard2",
    [(1.215, 0.308), (1.375, 0.296), (1.585, 0.320), (1.515, 0.350), (1.270, 0.346)],
    0.093, 0.113, 0.126,
    roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT),
    flat_group="FBShard2",
)
crystal_blade(
    "FB_Shard3",
    [(0.245, 0.214), (0.395, 0.200), (0.595, 0.216), (0.550, 0.242), (0.315, 0.238)],
    -0.094, -0.114, -0.128,
    roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT),
    flat_group="FBShard3",
)
crystal_blade(
    "FB_Shard4",
    [(1.215, 0.308), (1.375, 0.296), (1.585, 0.320), (1.515, 0.350), (1.270, 0.346)],
    -0.093, -0.113, -0.126,
    roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT),
    flat_group="FBShard4",
)

result = finish_master(fore)
result["gap_moves"] = gap_moves
