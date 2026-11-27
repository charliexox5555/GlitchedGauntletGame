"""Arcade Havoc (Vandal): cabinet side deck with pixel screen and buttons, coin door,
side-art handguard, cabinet butt, stepped brake and a joystick charging knob.

Run in the live Blender MCP session with the stock
art-source/weapons/RemasterV2/Vandal/Vandal_RemasterV2_v05.blend open:
    VERSION = "v01"; exec(open("tools/blender/arcade/10_vandal.py").read())
Left (+y) is the player-facing side. Stock sights, rig, locators and CharmLoop are kept.
"""

from pathlib import Path

import bpy

GUN = "Vandal"
VERSION = globals().get("VERSION", "v01")
exec((Path(bpy.data.filepath).parents[4] / "tools/blender/arcade/arcade_lib.py").read_text(encoding="utf-8"))

replace("Handguard", "Stock", "Barrel")

# ---------------------------------------------------------------- retained stock
for name in ("Receiver", "Rail", "Pins", "CharmLoop", "ChargingHandle", "Bolt",
             "FireSelector", "Trigger", "Grip", "RearSight", "FrontSight", "Neon"):
    dress(name)
dress("Mag", slots={"Dark": GRIP})
# Stock handguard: keep only the sling lug and the barrel collar at the nose.
dress("Handguard", copy_name="AR_HandguardHardware",
      keep=lambda island: limits(island, 2)[1] < 0.18 or limits(island, 0)[0] > 1.62)
# Stock buttstock without its butt pad (the cabinet butt replaces it).
dress("Stock", copy_name="AR_StockFrame", keep=lambda island: limits(island, 0)[0] > -1.2)
# Barrel without the stock brake.
dress("Barrel", copy_name="AR_BarrelTube", keep=lambda island: limits(island, 0)[0] < 2.38)


def crect(x0, z0, x1, z1, c):
    return [(x0 + c, z0), (x1 - c, z0), (x1, z0 + c), (x1, z1 - c),
            (x1 - c, z1), (x0 + c, z1), (x0, z1 - c), (x0, z0 + c)]


# ---------------------------------------------------------------- left: cabinet deck
# The deck fills the stock receiver's 0.005 side recess (floor y .087) and stands
# 0.006 proud of the receiver face (.092); its edges overlap the recess walls.
DECK = [(0.179, 0.187), (0.649, 0.187), (0.671, 0.195), (0.730, 0.254),
        (0.725, 0.265), (0.180, 0.265), (0.167, 0.252), (0.167, 0.201)]
deck = side("AR_ControlDeck_Left", DECK, 0.083, 0.098, PANEL, bevel=0.0018)

# Three faceted arcade buttons in collars, rising toward the muzzle.
for i, (x, z, role) in enumerate(((0.218, 0.222, BTN_MAGENTA), (0.284, 0.228, BTN_CYAN),
                                  (0.350, 0.234, BTN_YELLOW))):
    prism_along(f"AR_ButtonCollar_{i + 1}", (x, 0.094, z), (0, 1, 0), [(0, 0.030), (0.010, 0.030)], DARK,
                bevel=0.0015)
    prism_along(f"AR_Button_{i + 1}", (x, 0.100, z), (0, 1, 0),
                [(0, 0.024), (0.016, 0.024), (0.021, 0.017)], role)

# Pixel screen: bezel ring, dark screen floor, pixel graphic standing 0.004 proud.
inner = crect(0.408, 0.204, 0.648, 0.250, 0.008)
outer = crect(0.396, 0.194, 0.660, 0.260, 0.014)
loft("AR_ScreenBezel_Left", [
    [(x, 0.094, z) for x, z in outer], [(x, 0.108, z) for x, z in outer],
    [(x, 0.108, z) for x, z in inner], [(x, 0.094, z) for x, z in inner],
], DARK, loop=True)
plate("AR_Screen_Left", crect(0.406, 0.202, 0.650, 0.252, 0.008), 0.095, 0.101, SCREEN)
PX = 0.0085
SHIP = {(0, 4), (1, 4), (0, 3), (1, 3), (2, 3), (3, 3), (1, 2), (2, 2), (3, 2), (4, 2), (5, 2), (6, 2),
        (0, 1), (1, 1), (2, 1), (3, 1), (0, 0), (1, 0)}
pixel_solid("AR_ScreenShip_Left", SHIP, 0.428, 0.2065, PX, 0.100, 0.105, CYAN)
pixel_solid("AR_ScreenShot_Left", {(0, 0), (1, 0), (2, 0)}, 0.428 + 9 * PX, 0.2065 + 2 * PX, PX,
            0.100, 0.105, MAGENTA)
PLUS = {(1, 0), (0, 1), (1, 1), (2, 1), (1, 2)}
pixel_solid("AR_ScreenStarA_Left", PLUS, 0.576, 0.2065 + 2 * PX, PX, 0.100, 0.105, YELLOW)
pixel_solid("AR_ScreenStarB_Left", {(0, 0)}, 0.628, 0.2065 + 1 * PX, PX, 0.100, 0.105, YELLOW)
pixel_solid("AR_ScreenStarC_Left", {(0, 0)}, 0.551, 0.2065 + 4 * PX, PX, 0.100, 0.105, CYAN)

# Cyan light pipe along the deck's top edge, run into the deck wall.
side("AR_DeckLight_Left", [(0.300, 0.259), (0.697, 0.259), (0.712, 0.274), (0.315, 0.274)],
     0.088, 0.096, CYAN)

# ---------------------------------------------------------------- right: coin door
coin = side("AR_CoinDoor_Right", DECK, -0.083, -0.098, METAL, bevel=0.0018)
for i, x in enumerate((0.320, 0.440)):
    block = side(f"AR_CoinEntry_{i + 1}", crect(x - 0.030, 0.203, x + 0.030, 0.252, 0.006),
                 -0.094, -0.110, ACCENT, bevel=0.0015)
    recess(block, f"AR_CoinSlotCut_{i + 1}", crect(x - 0.004, 0.214, x + 0.004, 0.242, 0.002),
           -0.104, -0.130, role=DARK)
    side(f"AR_CoinSlotLight_{i + 1}", crect(x - 0.0055, 0.213, x + 0.0055, 0.243, 0.002),
         -0.100, -0.108, YELLOW)
side("AR_CoinStripe_Right", [(0.540, 0.192), (0.575, 0.192), (0.612, 0.260), (0.577, 0.260)],
     -0.096, -0.102, MAGENTA)

# ---------------------------------------------------------------- handguard
hand = folded("AR_Handguard", (
    (1.046, 0.185, 0.405, 0.086, 0.392, 0.215, 0.060),
    (1.075, 0.165, 0.414, 0.100, 0.400, 0.205, 0.072),
    (1.555, 0.165, 0.414, 0.100, 0.400, 0.205, 0.072),
    (1.600, 0.185, 0.410, 0.098, 0.396, 0.222, 0.066),
    (1.645, 0.212, 0.392, 0.080, 0.378, 0.240, 0.052),
), [BODY, BODY, BODY, BODY], bevel=0.004)
FIELD = [(1.115, 0.262), (1.135, 0.262), (1.135, 0.244), (1.155, 0.244), (1.155, 0.226),
         (1.505, 0.226), (1.545, 0.262), (1.545, 0.352), (1.515, 0.382), (1.135, 0.382), (1.115, 0.362)]
MAG_STRIPE = [(1.250, 0.223), (1.305, 0.223), (1.395, 0.385), (1.340, 0.385)]
CYAN_STRIPE = [(1.322, 0.223), (1.340, 0.223), (1.430, 0.385), (1.412, 0.385)]
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(hand, f"AR_HandguardField_{label}", FIELD, 0.093 * sign, 0.15 * sign, role=PANEL)
    side(f"AR_HandguardStripe_{label}", MAG_STRIPE, 0.090 * sign, 0.097 * sign, MAGENTA)
    side(f"AR_HandguardLine_{label}", CYAN_STRIPE, 0.090 * sign, 0.097 * sign, CYAN)
    plate(f"AR_HandguardStar_{label}", star(1.476, 0.318, 0.032, 0.014), 0.090 * sign, 0.097 * sign, YELLOW)

# ---------------------------------------------------------------- stock side art
for sign, label in ((1, "Left"), (-1, "Right")):
    side(f"AR_StockStripe_{label}", [(-0.800, 0.245), (-0.745, 0.245), (-0.685, 0.355), (-0.740, 0.355)],
         0.059 * sign, 0.067 * sign, MAGENTA)
    side(f"AR_StockLine_{label}", [(-0.728, 0.245), (-0.712, 0.245), (-0.652, 0.355), (-0.668, 0.355)],
         0.059 * sign, 0.067 * sign, CYAN)
    plate(f"AR_StockStar_{label}", star(-0.905, 0.300, 0.038, 0.016), 0.059 * sign, 0.067 * sign, YELLOW)

# ---------------------------------------------------------------- cabinet butt
butt = side("AR_CabinetButt", [
    (-1.090, 0.428), (-1.232, 0.428), (-1.266, 0.404), (-1.266, 0.352), (-1.246, 0.336),
    (-1.236, 0.215), (-1.268, 0.196), (-1.268, 0.160), (-1.250, 0.142), (-1.250, -0.152),
    (-1.226, -0.180), (-1.090, -0.180),
], -0.078, 0.078, BODY, bevel=0.008)
MARQUEE = [(-1.240, 0.362), (-1.112, 0.362), (-1.112, 0.404), (-1.222, 0.404), (-1.240, 0.390)]
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(butt, f"AR_MarqueeSeat_{label}", MARQUEE, 0.070 * sign, 0.12 * sign, role=DARK)
    side(f"AR_Marquee_{label}", [(-1.2425, 0.3595), (-1.1095, 0.3595), (-1.1095, 0.4065),
                                (-1.2235, 0.4065), (-1.2425, 0.3915)], 0.066 * sign, 0.0745 * sign, CYAN)

# ---------------------------------------------------------------- stepped brake
brake = prism_along("AR_Brake", (2.372, 0, 0.285), (1, 0, 0), [
    (0.000, 0.046), (0.014, 0.056), (0.083, 0.056), (0.083, 0.047), (0.103, 0.047), (0.103, 0.056),
    (0.248, 0.056), (0.275, 0.047), (0.275, 0.018), (0.233, 0.018),
], METAL)
for i, x in enumerate((2.500, 2.555)):
    recess(brake, f"AR_BrakePort_{i + 1}", crect(x, 0.264, x + 0.034, 0.306, 0.006), -0.12, 0.12, role=DARK)
prism_along("AR_BrakeLight", (2.453, 0, 0.285), (1, 0, 0), [(0, 0.0515), (0.024, 0.0515)], CYAN)

# ---------------------------------------------------------------- mag stripe
for sign, label in ((1, "Left"), (-1, "Right")):
    side(f"AR_MagStripe_{label}", [(0.698, -0.120), (0.722, -0.120), (0.716, 0.052), (0.692, 0.052)],
         0.054 * sign, 0.062 * sign, MAGENTA, bone="Mag")

# ---------------------------------------------------------------- joystick knob
STICK = (0, 0.866, 0.5)
prism_along("AR_JoystickWasher", (0.578, 0.122, 0.309), STICK, [(0, 0.020), (0.010, 0.020)], DARK,
            bone="ChargingHandle")
prism_along("AR_JoystickShaft", (0.578, 0.122, 0.309), STICK, [(0.006, 0.0075), (0.050, 0.0075)], METAL,
            bone="ChargingHandle")
prism_along("AR_JoystickBall", (0.578, 0.122, 0.309), STICK, [
    (0.044, 0.011), (0.050, 0.021), (0.062, 0.026), (0.074, 0.021), (0.080, 0.011),
], BTN_MAGENTA, bone="ChargingHandle")

result = finish_master(deck)
