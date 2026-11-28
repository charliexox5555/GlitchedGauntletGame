"""Frostbite Havoc (Vandal) v08: Legendary-caliber sculpted cryo-armor remodel.

- Sweeping Moltframe/Giltfold-inspired multi-layered Armor + FrostSteel wing plates
  hugging the receiver, split-jaw fore-end, curved magazine, and swept wing stock.
- Chiseled asymmetric non-pencil glacier shard formations (glacier_cluster).
- Bespoke curved-arc Frostbite magazine with integrated curved CryoGlow channel and
  swept crystalline floorplate (zero floating pipes, zero boxy slabs).
- Stock rig, locators, CharmLoop, FireSelector/ChargingHandle/Bolt clearance, and
  clear *Sight* ADS window preserved.

Run in live Blender (port 9100) with Vandal_RemasterV2_v05.blend open:
    VERSION = "v08"; exec(open(".../tools/blender/frostbite/10_vandal.py").read())
"""

from pathlib import Path

import bpy

GUN = "Vandal"
VERSION = globals().get("VERSION", "v10")
exec((Path(bpy.data.filepath).parents[4] / "tools/blender/frostbite/frost_lib.py").read_text(encoding="utf-8"))

replace("Handguard", "Stock", "Barrel", "Neon")

# ---------------------------------------------------------------- retained stock + gap sweep
for name in ("Receiver", "Rail", "CharmLoop", "ChargingHandle", "Bolt",
             "FireSelector", "Trigger", "Grip", "RearSight", "FrontSight"):
    dress(name)

dress("Pins", keep=lambda island: (0.0 < limits(island, 0)[0] and limits(island, 0)[1] < 1.06) or limits(island, 0)[0] > 1.88)
dress("Mag", slots={"Dark": GRIP, "Body": ARMOR, "Panel": OBSIDIAN, "Accent": FROSTSTEEL})
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

# ---------------------------------------------------------------- continuous upper cryo-carapace
carapace = folded("FB_UpperCarapace", (
    (-0.185, 0.352, 0.418, 0.088, 0.402, 0.366, 0.056),
    (-0.040, 0.350, 0.434, 0.102, 0.416, 0.368, 0.058),
    (0.795,  0.348, 0.434, 0.102, 0.416, 0.366, 0.058),
    (0.920,  0.282, 0.428, 0.100, 0.408, 0.310, 0.056),
    (1.045,  0.215, 0.422, 0.102, 0.398, 0.252, 0.055),
    (1.260,  0.155, 0.420, 0.114, 0.394, 0.210, 0.062),
    (1.560,  0.168, 0.414, 0.106, 0.390, 0.224, 0.058),
    (1.945,  0.244, 0.368, 0.052, 0.352, 0.264, 0.032),
), [ARMOR, ARMOR, ARMOR, FROSTSTEEL, ARMOR, ARMOR, FROSTSTEEL], bevel=0.002)

FORE_CHASM = [
    (1.045, 0.236), (1.175, 0.210), (1.555, 0.228), (1.715, 0.308),
    (1.615, 0.378), (1.225, 0.378), (1.065, 0.328),
]
MANTLE_VENT = [(0.165, 0.382), (0.215, 0.408), (0.755, 0.406), (0.715, 0.380)]
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(carapace, f"FB_ForeChasm_{label}", FORE_CHASM, 0.082 * sign, 0.15 * sign, role=OBSIDIAN)
    recess(carapace, f"FB_MantleVent_{label}", MANTLE_VENT, 0.078 * sign, 0.14 * sign, role=OBSIDIAN)

# Nose collar bridging smoothly around barrel & gas tube at x=1.88..1.99
loft("FB_ForeNoseCollar", [
    [(1.885, y, z) for y, z in ((-0.032, 0.368), (0.032, 0.368), (0.052, 0.344), (0.052, 0.258),
                                (0.036, 0.236), (-0.036, 0.236), (-0.052, 0.258), (-0.052, 0.344))],
    [(1.985, y, z) for y, z in ((-0.026, 0.358), (0.026, 0.358), (0.044, 0.336), (0.044, 0.264),
                                (0.028, 0.244), (-0.028, 0.244), (-0.044, 0.264), (-0.044, 0.336))],
], FROSTSTEEL, bevel=0.002)

# ---------------------------------------------------------------- sculpted swept armor wing plates (NO floating pipes!)
# Multi-layered bevelled plates that completely reshape the receiver, bridge, and split-jaw fore-end,
# while staying clear of FireSelector (x=0.01..0.11, z=0.18..0.31), ChargingHandle, Bolt, and CharmPoint (x=0.93).
for sign, label in ((1, "Left"), (-1, "Right")):
    # Receiver rear-to-mid lower armored wing (sweeps cleanly in front of FireSelector x>=0.135)
    armor_plate(
        f"FB_RecArmorRear_{label}",
        [(0.125, 0.172), (0.345, 0.165), (0.445, 0.186), (0.285, 0.205),
         (0.195, 0.262), (0.122, 0.262), (0.108, 0.215)],
        0.078 * sign, 0.106 * sign, 0.114 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.009,
    )
    # Swept forward receiver-to-fore-end bridge armor wing (convex, x>=0.798 clears ChargingHandle in all clips!)
    armor_plate(
        f"FB_BridgeWing_{label}",
        [(0.798, 0.246), (0.955, 0.254), (1.205, 0.338), (1.375, 0.378),
         (1.215, 0.398), (0.965, 0.392), (0.808, 0.318)],
        0.080 * sign, 0.108 * sign, 0.116 * sign, ARMOR, rim_role=FROSTSTEEL, inset=0.008,
    )
    # Upper-receiver sculpted brow shoulder plate (frames mantle vent cleanly)
    armor_plate(
        f"FB_UpperBrowPlate_{label}",
        [(0.060, 0.352), (0.450, 0.350), (0.820, 0.350), (0.905, 0.382),
         (0.765, 0.415), (0.215, 0.416), (-0.065, 0.398)],
        0.080 * sign, 0.103 * sign, 0.109 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.008,
    )
    # Fore-end forward split-jaw fang cowl (sweeps cleanly over front of fore-end chasm)
    armor_plate(
        f"FB_ForeJawFront_{label}",
        [(1.545, 0.215), (1.765, 0.236), (1.895, 0.275), (1.845, 0.352),
         (1.665, 0.392), (1.515, 0.386), (1.665, 0.312)],
        0.076 * sign, 0.108 * sign, 0.116 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.009,
    )
    # Fore-end sculpted lower chin cowl
    armor_plate(
        f"FB_ForeChinPlate_{label}",
        [(1.035, 0.195), (1.265, 0.155), (1.535, 0.162), (1.665, 0.205),
         (1.515, 0.236), (1.165, 0.228), (1.035, 0.242)],
        0.076 * sign, 0.106 * sign, 0.114 * sign, ARMOR, rim_role=FROSTSTEEL, inset=0.009,
    )
    # Lower receiver magwell cheek skirt
    armor_plate(
        f"FB_LowerSkirt_{label}",
        [(0.435, 0.142), (0.765, 0.152), (0.815, 0.195), (0.745, 0.244), (0.455, 0.232)],
        0.076 * sign, 0.098 * sign, 0.104 * sign, ARMOR, rim_role=FROSTSTEEL, inset=0.007,
    )

# ---------------------------------------------------------------- cryo-core reactor bay & chiseled crystal formations
CORE_BAY = [(0.155, 0.180), (0.745, 0.180), (0.778, 0.216), (0.742, 0.264), (0.175, 0.264), (0.145, 0.230)]
for sign, label in ((1, "Left"), (-1, "Right")):
    bay = side(f"FB_CoreBay_{label}", CORE_BAY, 0.076 * sign, 0.100 * sign, ARMOR)
    recess(bay, f"FB_CoreChasm_{label}",
           [(0.192, 0.192), (0.700, 0.192), (0.732, 0.222), (0.702, 0.252), (0.205, 0.252), (0.182, 0.224)],
           0.084 * sign, 0.14 * sign, role=OBSIDIAN)
    swept_rib(f"FB_CoreFissure_{label}", [
        (0.210, 0.087 * sign, 0.222, 0.005, 0.006),
        (0.375, 0.088 * sign, 0.216, 0.006, 0.007),
        (0.535, 0.088 * sign, 0.228, 0.006, 0.007),
        (0.690, 0.087 * sign, 0.222, 0.005, 0.006),
    ], CRYO_GLOW, flat_group="FBCoreFissure")

    swept_rib(f"FB_UpperSeam_{label}", [
        (0.215, 0.087 * sign, 0.390, 0.005, 0.005),
        (0.455, 0.088 * sign, 0.396, 0.005, 0.006),
        (0.695, 0.087 * sign, 0.391, 0.005, 0.005),
    ], CRYO_GLOW, flat_group="FBUpperSeam")

    swept_rib(f"FB_ForeSeam_{label}", [
        (1.105, 0.088 * sign, 0.268, 0.005, 0.007),
        (1.315, 0.090 * sign, 0.286, 0.006, 0.008),
        (1.525, 0.090 * sign, 0.312, 0.006, 0.007),
        (1.655, 0.088 * sign, 0.326, 0.005, 0.006),
    ], CRYO_GLOW, flat_group="FBForeSeam")

# Asymmetric chiseled diamond cryo-heart inside the player-facing (+Y) reactor bay
glacier_shard(
    "FB_CoreHeart_Left",
    [(0.422, 0.224), (0.460, 0.206), (0.498, 0.222), (0.465, 0.240)],
    0.089, 0.117, 0.130,
    roles=(GLOW_WHITE, GLOW_WHITE, GLOW_WHITE),
    ridge_bias=(-0.006, 0.002),
    flat_group="FBCoreHeart",
)

# Chiseled, asymmetric overlapping glacier shard formations (NO pencils!)
for sign, label in ((1, "Left"), (-1, "Right")):
    glacier_cluster(f"FB_CoreCrystals_{label}", [
        {"points_xz": [(0.210, 0.218), (0.310, 0.194), (0.415, 0.204), (0.375, 0.248), (0.255, 0.244)],
         "base_y": 0.085 * sign, "shoulder_y": 0.106 * sign, "crest_y": 0.121 * sign,
         "ridge_bias": (-0.016, 0.006)},
        {"points_xz": [(0.505, 0.212), (0.615, 0.196), (0.710, 0.220), (0.645, 0.252), (0.525, 0.244)],
         "base_y": 0.086 * sign, "shoulder_y": 0.108 * sign, "crest_y": 0.123 * sign,
         "roles": (ICE_MID, ICE_MID, ICE_BRIGHT), "ridge_bias": (-0.015, 0.005)},
    ])

    glacier_cluster(f"FB_ForeCrystals_{label}", [
        {"points_xz": [(1.075, 0.285), (1.215, 0.258), (1.395, 0.292), (1.335, 0.358), (1.135, 0.342)],
         "base_y": 0.085 * sign, "shoulder_y": 0.110 * sign, "crest_y": 0.126 * sign,
         "ridge_bias": (-0.025, 0.010)},
        {"points_xz": [(1.305, 0.274), (1.465, 0.245), (1.645, 0.285), (1.585, 0.356), (1.375, 0.338)],
         "base_y": 0.086 * sign, "shoulder_y": 0.112 * sign, "crest_y": 0.128 * sign,
         "roles": (ICE_MID, ICE_MID, ICE_BRIGHT), "ridge_bias": (-0.022, 0.008)},
        {"points_xz": [(1.145, 0.228), (1.315, 0.220), (1.515, 0.242), (1.445, 0.286), (1.195, 0.268)],
         "base_y": 0.085 * sign, "shoulder_y": 0.105 * sign, "crest_y": 0.118 * sign,
         "ridge_bias": (-0.018, 0.004)},
    ])

# Sculpted chiseled glacier fore-keel forward of LeftGrip (x=1.32)
glacier_cluster("FB_ForeKeel", [
    {"points_xz": [(1.415, 0.152), (1.575, 0.122), (1.755, 0.195), (1.665, 0.228), (1.485, 0.205)],
     "base_y": 0.026, "shoulder_y": -0.024, "crest_y": -0.036, "ridge_bias": (-0.018, -0.010)},
    {"points_xz": [(1.415, 0.152), (1.575, 0.122), (1.755, 0.195), (1.665, 0.228), (1.485, 0.205)],
     "base_y": -0.026, "shoulder_y": 0.024, "crest_y": 0.036, "ridge_bias": (-0.018, -0.010)},
])

# ---------------------------------------------------------------- dramatic swept glacial-wing skeleton stock
# Transforms the rear outline completely: sleek arched wing boom, raked forward-swept butt,
# sculpted FrostSteel cheek plates, and bold jagged crystal chasm bridging the cutout!
stock_frame = side("FB_StockFrame", [
    (-1.265, 0.424), (-0.820, 0.398), (-0.435, 0.412), (-0.105, 0.368),
    (-0.105, 0.220), (-0.435, 0.212), (-0.645, 0.175), (-1.015, -0.105), (-1.155, -0.175),
], -0.062, 0.062, ARMOR, bevel=0.006)
STOCK_WINDOW = [
    (-1.055, 0.045), (-0.695, 0.295), (-0.310, 0.326),
    (-0.425, 0.254), (-0.665, 0.212), (-1.055, -0.075),
]
recess(stock_frame, "FB_StockWindow", STOCK_WINDOW, -0.12, 0.12, role=OBSIDIAN)

# Swept FrostSteel wing cheek armor flanking the upper stock boom (tucks cleanly into butt at x=-1.115)
for sign, label in ((1, "Left"), (-1, "Right")):
    armor_plate(
        f"FB_StockWingCheek_{label}",
        [(-1.115, 0.345), (-0.795, 0.335), (-0.445, 0.352), (-0.125, 0.325),
         (-0.125, 0.376), (-0.435, 0.416), (-0.820, 0.402), (-1.115, 0.418)],
        0.045 * sign, 0.070 * sign, 0.076 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.008,
    )
side("FB_StockCollar", [(-0.225, 0.384), (-0.115, 0.374), (-0.115, 0.214), (-0.225, 0.210)],
     -0.074, 0.074, FROSTSTEEL, bevel=0.003)

# Multi-shard sculpted glacial crystal bridge across the stock chasm (buried >= 0.04 into butt & struts!)
STOCK_SHARD_A = [(-1.145, 0.015), (-0.715, 0.314), (-0.515, 0.318), (-0.635, 0.195), (-1.145, -0.145)]
STOCK_SHARD_B = [(-1.115, -0.045), (-0.865, 0.175), (-0.755, 0.165), (-0.985, -0.125)]
for sign, label in ((1, "L"), (-1, "R")):
    glacier_cluster(f"FB_StockCrystals_{label}", [
        {"points_xz": STOCK_SHARD_A, "base_y": -0.042 * sign, "shoulder_y": 0.044 * sign, "crest_y": 0.058 * sign,
         "ridge_bias": (0.015, 0.010)},
        {"points_xz": STOCK_SHARD_B, "base_y": -0.044 * sign, "shoulder_y": 0.048 * sign, "crest_y": 0.064 * sign,
         "roles": (ICE_MID, ICE_MID, ICE_BRIGHT), "ridge_bias": (0.010, 0.006)},
    ])
swept_rib("FB_StockGlow", [
    (-1.020, 0.0, -0.035, 0.048, 0.010),
    (-0.805, 0.0,  0.135, 0.048, 0.010),
    (-0.615, 0.0,  0.258, 0.048, 0.010),
], CRYO_GLOW, flat_group="FBStockGlow")

# Raked forward-swept ergonomic butt pad (replaces boxy vertical pad!)
side("FB_StockButt", [
    (-1.315, 0.382), (-1.275, 0.436), (-1.145, 0.432), (-1.095, 0.365),
    (-1.095, -0.152), (-1.165, -0.198), (-1.245, -0.165), (-1.265, 0.165),
], -0.076, 0.076, GRIP, bevel=0.008)
side("FB_StockHeelCap", [
    (-1.265, -0.090), (-1.175, -0.202), (-1.110, -0.198), (-1.110, -0.115), (-1.255, 0.005),
], -0.080, 0.080, FROSTSTEEL, bevel=0.003)

# ---------------------------------------------------------------- sculpted split-fin cryo muzzle crown
muzzle = folded("FB_MuzzleCrown", (
    (2.310, 0.244, 0.326, 0.038, 0.312, 0.256, 0.026),
    (2.368, 0.214, 0.356, 0.062, 0.340, 0.230, 0.044),
    (2.478, 0.216, 0.354, 0.066, 0.338, 0.232, 0.048),
    (2.625, 0.220, 0.350, 0.064, 0.334, 0.236, 0.048),
    (2.705, 0.238, 0.336, 0.048, 0.324, 0.250, 0.034),
    (2.705, 0.264, 0.306, 0.026, 0.300, 0.272, 0.018),
    (2.375, 0.262, 0.306, 0.025, 0.300, 0.270, 0.018),
    (2.310, 0.264, 0.306, 0.024, 0.300, 0.272, 0.017),
), [FROSTSTEEL, ARMOR, ARMOR, ARMOR, FROSTSTEEL, OBSIDIAN, OBSIDIAN, OBSIDIAN], loop=True)
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(muzzle, f"FB_MuzzleVent_{label}",
           [(2.425, 0.256), (2.482, 0.320), (2.605, 0.320), (2.555, 0.256)],
           0.028 * sign, 0.098 * sign, role=OBSIDIAN)
    armor_plate(
        f"FB_MuzzleFin_{label}",
        [(2.335, 0.238), (2.495, 0.224), (2.635, 0.242), (2.555, 0.270), (2.375, 0.268)],
        0.046 * sign, 0.072 * sign, 0.078 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.006,
    )
m_glow = prism_along("FB_MuzzleGlow", (2.455, 0, 0.285), (1, 0, 0), [(0, 0.046), (0.105, 0.046)], CRYO_GLOW)
m_glow["flat_group"] = "FBMuzzleGlow"
glacier_cluster("FB_MuzzleIce", [
    {"points_xz": [(2.325, 0.214), (2.455, 0.184), (2.605, 0.224), (2.495, 0.250)],
     "base_y": 0.024, "shoulder_y": -0.022, "crest_y": -0.036, "ridge_bias": (-0.015, -0.008)},
    {"points_xz": [(2.325, 0.214), (2.455, 0.184), (2.605, 0.224), (2.495, 0.250)],
     "base_y": -0.024, "shoulder_y": 0.022, "crest_y": 0.036, "ridge_bias": (-0.015, -0.008)},
])

# ---------------------------------------------------------------- bespoke curved-arc Frostbite magazine (bone Mag)
# Hugs the banana arc of Vandal_Mag cleanly (NO floating pipes, contoured curved cowl + glacier fissure!).
MAG_ARC = [
    (0.514, 0.752, 0.063,  0.020),
    (0.534, 0.778, 0.065, -0.050),
    (0.562, 0.815, 0.067, -0.130),
    (0.598, 0.865, 0.069, -0.220),
    (0.642, 0.928, 0.071, -0.315),
    (0.692, 0.996, 0.073, -0.395),
]
mag_sections = []
for rx, fx, hy, z in MAG_ARC:
    mag_sections.append([
        (rx + 0.014, -hy * 0.68, z), (fx - 0.018, -hy * 0.68, z),
        (fx, -hy * 0.30, z), (fx, hy * 0.30, z),
        (fx - 0.018, hy * 0.68, z), (rx + 0.014, hy * 0.68, z),
        (rx - 0.006, hy * 0.30, z), (rx - 0.006, -hy * 0.30, z),
    ])
mag_sleeve = loft("FB_MagSleeve", mag_sections, ARMOR, bone="Mag", bevel=0.002)

swept_rib("FB_MagSpineFront", [
    (0.750, 0.0,  0.015, 0.044, 0.015),
    (0.782, 0.0, -0.065, 0.046, 0.016),
    (0.824, 0.0, -0.155, 0.048, 0.017),
    (0.880, 0.0, -0.250, 0.050, 0.017),
    (0.946, 0.0, -0.340, 0.054, 0.018),
    (1.008, 0.0, -0.402, 0.058, 0.018),
], FROSTSTEEL, bone="Mag")

swept_rib("FB_MagSpineRear", [
    (0.512, 0.0,  0.015, 0.042, 0.014),
    (0.535, 0.0, -0.065, 0.044, 0.015),
    (0.566, 0.0, -0.155, 0.046, 0.015),
    (0.606, 0.0, -0.250, 0.048, 0.016),
    (0.654, 0.0, -0.340, 0.052, 0.017),
    (0.702, 0.0, -0.402, 0.056, 0.017),
], FROSTSTEEL, bone="Mag")

MAG_SLOT = [(0.595, -0.045), (0.685, -0.035), (0.865, -0.345), (0.745, -0.355)]
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(mag_sleeve, f"FB_MagChasm_{label}", MAG_SLOT, 0.050 * sign, 0.095 * sign, role=OBSIDIAN, bone="Mag")
    # Curved CryoGlow ammo fissure following the banana curve
    swept_rib(f"FB_MagGlow_{label}", [
        (0.642, 0.053 * sign, -0.058, 0.006, 0.007),
        (0.684, 0.056 * sign, -0.150, 0.006, 0.008),
        (0.738, 0.059 * sign, -0.245, 0.006, 0.008),
        (0.805, 0.061 * sign, -0.335, 0.006, 0.007),
    ], CRYO_GLOW, bone="Mag", flat_group="FBMagGlow")
    # Sculpted curved FrostSteel armor cowl wrapping the lower half of the magazine flank cleanly
    armor_plate(
        f"FB_MagCowl_{label}",
        [(0.645, -0.225), (0.795, -0.185), (0.915, -0.255), (0.985, -0.395),
         (0.715, -0.398), (0.665, -0.315)],
        0.056 * sign, 0.075 * sign, 0.080 * sign, FROSTSTEEL, rim_role=ARMOR, inset=0.008, bone="Mag",
    )
    # Contoured chiseled crystal ridge seated cleanly inside the upper curved mag channel
    glacier_shard(
        f"FB_MagIce_{label}",
        [(0.605, -0.055), (0.675, -0.048), (0.795, -0.265), (0.735, -0.295), (0.635, -0.165)],
        0.052 * sign, 0.068 * sign, 0.078 * sign,
        ridge_bias=(-0.010, 0.025), bone="Mag",
    )

# Contoured swept cryo-forged floorplate matching the magazine curve + subtle heel crystal edge
swept_rib("FB_MagFloorplate", [
    (0.678, 0.0, -0.388, 0.074, 0.018),
    (0.845, 0.0, -0.415, 0.076, 0.020),
    (1.018, 0.0, -0.410, 0.072, 0.016),
], ARMOR, bone="Mag")
glacier_cluster("FB_MagHeelCrystal", [
    {"points_xz": [(0.705, -0.392), (0.835, -0.418), (0.945, -0.416), (0.815, -0.456)],
     "base_y": 0.032, "shoulder_y": -0.030, "crest_y": -0.044, "ridge_bias": (-0.015, -0.008)},
    {"points_xz": [(0.705, -0.392), (0.835, -0.418), (0.945, -0.416), (0.815, -0.456)],
     "base_y": -0.032, "shoulder_y": 0.030, "crest_y": 0.044, "ridge_bias": (-0.015, -0.008)},
], bone="Mag")

# ---------------------------------------------------------------- contoured grip spine & pommel (Root)
swept_rib("FB_GripSpine", [
    (-0.118, 0.0,  0.055, 0.042, 0.015),
    (-0.105, 0.0, -0.015, 0.044, 0.015),
    (-0.132, 0.0, -0.145, 0.044, 0.015),
    (-0.165, 0.0, -0.255, 0.048, 0.017),
    (-0.188, 0.0, -0.305, 0.058, 0.018),
], FROSTSTEEL)
swept_rib("FB_GripPommel", [
    (-0.195, 0.0, -0.306, 0.068, 0.016),
    (-0.085, 0.0, -0.310, 0.068, 0.016),
    (0.012,  0.0, -0.294, 0.064, 0.014),
], ARMOR)

# ---------------------------------------------------------------- animated effect flat_groups (Root, single-mat)
# 3 staggered jagged glacier crest crowns seated cleanly along upper shoulders (no pencils, 1 mat/group).
glacier_cluster("FB_GrowRear", [
    {"points_xz": [(0.175, 0.378), (0.355, 0.365), (0.565, 0.382), (0.485, 0.412), (0.245, 0.408)],
     "base_y": 0.082, "shoulder_y": 0.106, "crest_y": 0.118,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.025, 0.006)},
    {"points_xz": [(0.175, 0.378), (0.355, 0.365), (0.565, 0.382), (0.485, 0.412), (0.245, 0.408)],
     "base_y": -0.082, "shoulder_y": -0.106, "crest_y": -0.118,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.025, 0.006)},
], flat_group="FBGrowRear")

glacier_cluster("FB_GrowMid", [
    {"points_xz": [(0.745, 0.350), (0.935, 0.332), (1.135, 0.354), (1.055, 0.392), (0.815, 0.386)],
     "base_y": 0.084, "shoulder_y": 0.110, "crest_y": 0.124,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.022, 0.008)},
    {"points_xz": [(0.745, 0.350), (0.935, 0.332), (1.135, 0.354), (1.055, 0.392), (0.815, 0.386)],
     "base_y": -0.084, "shoulder_y": -0.110, "crest_y": -0.124,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.022, 0.008)},
], flat_group="FBGrowMid")

glacier_cluster("FB_GrowFront", [
    {"points_xz": [(1.275, 0.356), (1.465, 0.342), (1.675, 0.358), (1.595, 0.390), (1.345, 0.386)],
     "base_y": 0.084, "shoulder_y": 0.108, "crest_y": 0.120,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.020, 0.006)},
    {"points_xz": [(1.275, 0.356), (1.465, 0.342), (1.675, 0.358), (1.595, 0.390), (1.345, 0.386)],
     "base_y": -0.084, "shoulder_y": -0.108, "crest_y": -0.120,
     "roles": (ICE_MID, ICE_MID, ICE_MID), "ridge_bias": (-0.020, 0.006)},
], flat_group="FBGrowFront")

# 4 outer breakaway kill-shatter glacier crust blades (single-mat ICE_BRIGHT, proud over crystal bays).
glacier_shard(
    "FB_Shard1",
    [(0.245, 0.214), (0.375, 0.198), (0.575, 0.216), (0.525, 0.244), (0.295, 0.240)],
    0.092, 0.116, 0.130,
    roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.015, 0.004),
    flat_group="FBShard1",
)
glacier_shard(
    "FB_Shard2",
    [(1.215, 0.295), (1.385, 0.278), (1.595, 0.308), (1.525, 0.348), (1.275, 0.338)],
    0.094, 0.118, 0.132,
    roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.018, 0.006),
    flat_group="FBShard2",
)
glacier_shard(
    "FB_Shard3",
    [(0.245, 0.214), (0.375, 0.198), (0.575, 0.216), (0.525, 0.244), (0.295, 0.240)],
    -0.092, -0.116, -0.130,
    roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.015, 0.004),
    flat_group="FBShard3",
)
glacier_shard(
    "FB_Shard4",
    [(1.215, 0.295), (1.385, 0.278), (1.595, 0.308), (1.525, 0.348), (1.275, 0.338)],
    -0.094, -0.118, -0.132,
    roles=(ICE_BRIGHT, ICE_BRIGHT, ICE_BRIGHT), ridge_bias=(-0.018, 0.006),
    flat_group="FBShard4",
)

result = finish_master(carapace)
result["gap_moves"] = gap_moves
