"""Arcade Spirit (Phantom): cabinet side deck with joystick, buttons and pixel screen, coin door,
side-art handguard with lit edge trim, a cabinet butt with marquee and side art, and a stepped
eight-sided suppressor can with a light ring.

Run in the live Blender MCP session with the stock
art-source/weapons/RemasterV2/Phantom/Phantom_RemasterV2_v05.blend open:
    exec(open("tools/blender/arcade/11_phantom.py").read(), {"VERSION": "v01"})
Left (+y) is the player-facing side. Stock sights, rig, locators and CharmLoop are kept.
Stock measurements (2026-11-27, ray-cast depth maps):
  receiver side face y .080 (z .18-.30), side recess floor y .075 (x .04-.42, z .20-.28),
  upper receiver face y .083-.084 (z .31-.40); fire selector lever x .087-.136 (rotates 14 deg);
  handguard y .088, keel .238, shoulder .405, top .429, front cap x 1.598-1.645;
  stock frame face y .066, butt pad x -.98 to -1.098; suppressor r .077-.084, x 1.741-2.505;
  magazine face y .054, front groove x .78, cross groove z -.10.
"""

from pathlib import Path

import bpy

GUN = "Phantom"
VERSION = globals().get("VERSION", "v01")
exec((Path(bpy.data.filepath).parents[4] / "tools/blender/arcade/arcade_lib.py").read_text(encoding="utf-8"))

replace("Handguard", "Stock", "Suppressor")

# ---------------------------------------------------------------- retained stock
for name in ("Receiver", "Rail", "Pins", "CharmLoop", "ChargingHandle", "Bolt",
             "FireSelector", "Trigger", "Grip", "Sights", "Neon"):
    dress(name)
dress("Mag", slots={"Dark": GRIP})
# The stock receiver's rear cap underside (Panel) shares the plane of the receiver's underside
# (Body) at z .16: lift those cap faces 0.004, the same lift the flat export would make.
_receiver = native("Receiver")
_bm = bmesh.new()
_bm.from_mesh(_receiver.data)
_cap = {v for f in _bm.faces
        if _receiver.data.materials[f.material_index].name == "AR Panel" and f.normal.z < -0.999
        and abs(f.calc_center_median().z - 0.16) < 0.001 and f.calc_center_median().x < -0.1 for v in f.verts}
bmesh.ops.translate(_bm, verts=list(_cap), vec=(0, 0, 0.004))
_bm.to_mesh(_receiver.data)
_bm.free()
# Stock handguard: keep only the nose cap.
dress("Handguard", copy_name="AR_HandguardCap", keep=lambda island: limits(island, 0)[0] > 1.59)
# Stock skeleton frame, buffer tube and hardware without the butt pad (the cabinet butt replaces it).
dress("Stock", copy_name="AR_StockFrame", keep=lambda island: limits(island, 0)[0] > -1.0)
# Suppressor: keep only the barrel stub; the faceted can replaces the round can.
dress("Suppressor", copy_name="AR_BarrelStub", keep=lambda island: limits(island, 0)[1] < 1.75)


def crect(x0, z0, x1, z1, c):
    return [(x0 + c, z0), (x1 - c, z0), (x1, z0 + c), (x1, z1 - c),
            (x1 - c, z1), (x0 + c, z1), (x0, z1 - c), (x0, z0 + c)]


def square(x, z, size):
    return [(x - size / 2, z - size / 2), (x + size / 2, z - size / 2),
            (x + size / 2, z + size / 2), (x - size / 2, z + size / 2)]


# ---------------------------------------------------------------- left: cabinet deck
# The deck sits in the receiver's side recess (floor y .075) and over its face (.080):
# back at y .072 (buried), face at .092 (0.012 proud). It starts behind the fire selector.
DECK = [(0.183, 0.192), (0.700, 0.192), (0.722, 0.200), (0.756, 0.278),
        (0.750, 0.292), (0.184, 0.292), (0.170, 0.279), (0.170, 0.205)]
deck = side("AR_ControlDeck_Left", DECK, 0.072, 0.092, PANEL, bevel=0.0018)

# Joystick at the rear, then three faceted buttons in collars rising toward the muzzle.
prism_along("AR_JoystickWasher", (0.208, 0.088, 0.236), (0, 1, 0), [(0, 0.022), (0.009, 0.022)], DARK,
            bevel=0.0015)
prism_along("AR_JoystickShaft", (0.208, 0.094, 0.236), (0, 1, 0), [(0, 0.0065), (0.034, 0.0065)], METAL)
stick_ball = prism_along("AR_JoystickBall", (0.208, 0.094, 0.236), (0, 1, 0), [
    (0.028, 0.009), (0.033, 0.016), (0.041, 0.019), (0.049, 0.016), (0.054, 0.009),
], BTN_MAGENTA)
stick_ball["flat_group"] = "ARStickBall"
for i, (x, z, role) in enumerate(((0.288, 0.234, BTN_CYAN), (0.348, 0.240, BTN_YELLOW),
                                  (0.408, 0.246, BTN_MAGENTA))):
    prism_along(f"AR_ButtonCollar_{i + 1}", (x, 0.088, z), (0, 1, 0), [(0, 0.028), (0.010, 0.028)], DARK,
                bevel=0.0015)
    button = prism_along(f"AR_Button_{i + 1}", (x, 0.094, z), (0, 1, 0),
                         [(0, 0.022), (0.016, 0.022), (0.021, 0.0155)], role)
    button["flat_group"] = f"ARButton{i + 1}"

# Pixel screen: bezel ring, glowing screen floor, pixel graphic standing 0.004 proud.
inner = crect(0.458, 0.216, 0.688, 0.266, 0.008)
outer = crect(0.446, 0.206, 0.700, 0.276, 0.014)
loft("AR_ScreenBezel_Left", [
    [(x, 0.088, z) for x, z in outer], [(x, 0.102, z) for x, z in outer],
    [(x, 0.102, z) for x, z in inner], [(x, 0.088, z) for x, z in inner],
], DARK, loop=True)
plate("AR_Screen_Left", crect(0.456, 0.214, 0.690, 0.268, 0.008), 0.089, 0.095, SCREEN)["flat_group"] = "ARScreen"
PX = 0.0085
SX, SZ = 0.472, 0.2195
SHIP = {(0, 4), (1, 4), (0, 3), (1, 3), (2, 3), (3, 3), (1, 2), (2, 2), (3, 2), (4, 2), (5, 2), (6, 2),
        (0, 1), (1, 1), (2, 1), (3, 1), (0, 0), (1, 0)}
pixel_solid("AR_ScreenShip_Left", SHIP, SX, SZ, PX, 0.094, 0.099, CYAN)["flat_group"] = "ARScreenShip"
pixel_solid("AR_ScreenShot_Left", {(0, 0), (1, 0), (2, 0)}, SX + 9 * PX, SZ + 2 * PX, PX,
            0.094, 0.099, MAGENTA)["flat_group"] = "ARScreenShot"
PLUS = {(1, 0), (0, 1), (1, 1), (2, 1), (1, 2)}
pixel_solid("AR_ScreenStarA_Left", PLUS, 0.623, SZ + 2 * PX, PX, 0.094, 0.099, YELLOW)["flat_group"] = "ARScreenStars"
pixel_solid("AR_ScreenStarB_Left", {(0, 0)}, 0.670, SZ + 1 * PX, PX, 0.094, 0.099, YELLOW)["flat_group"] = "ARScreenStars"
pixel_solid("AR_ScreenStarC_Left", {(0, 0)}, 0.602, SZ + 4 * PX, PX, 0.094, 0.099, CYAN)["flat_group"] = "ARScreenBlip"

# Cyan light pipe along the deck's top edge over the screen (the stock cyan strip above the buttons
# carries on behind it), its back buried in the receiver face (.080).
side("AR_DeckLight_Left", [(0.450, 0.286), (0.716, 0.286), (0.728, 0.301), (0.462, 0.301)],
     0.076, 0.089, CYAN)["flat_group"] = "ARDeckLight"

# ---------------------------------------------------------------- right: coin door
coin = side("AR_CoinDoor_Right", DECK, -0.072, -0.092, METAL, bevel=0.0018)
for i, x in enumerate((0.330, 0.450)):
    block = side(f"AR_CoinEntry_{i + 1}", crect(x - 0.030, 0.215, x + 0.030, 0.268, 0.006),
                 -0.088, -0.104, ACCENT, bevel=0.0015)
    recess(block, f"AR_CoinSlotCut_{i + 1}", crect(x - 0.004, 0.226, x + 0.004, 0.257, 0.002),
           -0.098, -0.124, role=DARK)
    side(f"AR_CoinSlotLight_{i + 1}", crect(x - 0.0055, 0.225, x + 0.0055, 0.258, 0.002),
         -0.094, -0.102, YELLOW)
side("AR_CoinStripe_Right", [(0.560, 0.204), (0.595, 0.204), (0.637, 0.282), (0.602, 0.282)],
     -0.090, -0.096, MAGENTA)

# ---------------------------------------------------------------- handguard
# Stock envelope (y .088, keel .238, shoulder .405), a cabinet kick under the middle, the rear
# seated 0.03 inside the upper receiver nose (front .934; the lower receiver stops at .912, where a
# chamfered collar fills the stock seam) and the front tapered into the stock nose cap.
hand = folded("AR_Handguard", (
    (0.904, 0.206, 0.424, 0.079, 0.400, 0.242, 0.058),
    (0.938, 0.198, 0.431, 0.088, 0.405, 0.238, 0.064),
    (1.002, 0.198, 0.431, 0.088, 0.405, 0.238, 0.064),
    (1.034, 0.184, 0.431, 0.088, 0.405, 0.228, 0.064),
    (1.505, 0.184, 0.431, 0.088, 0.405, 0.228, 0.064),
    (1.540, 0.198, 0.431, 0.088, 0.405, 0.238, 0.064),
    (1.580, 0.198, 0.431, 0.088, 0.405, 0.238, 0.064),
    (1.622, 0.222, 0.410, 0.074, 0.392, 0.250, 0.052),
), BODY, bevel=0.004)
FIELD = [(1.060, 0.280), (1.080, 0.280), (1.080, 0.263), (1.100, 0.263), (1.100, 0.246),
         (1.470, 0.246), (1.505, 0.280), (1.505, 0.362), (1.477, 0.390), (1.080, 0.390), (1.060, 0.370)]
MAG_STRIPE = [(1.195, 0.243), (1.248, 0.243), (1.331, 0.393), (1.278, 0.393)]
CYAN_STRIPE = [(1.265, 0.243), (1.282, 0.243), (1.365, 0.393), (1.348, 0.393)]
# The charging-handle slot runs on into the handguard (the handle's nose sits at x .935 at rest).
recess(hand, "AR_HandleSlotCut", crect(0.890, 0.350, 0.946, 0.407, 0.002), 0.064, 0.15, role=DARK)
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(hand, f"AR_HandguardField_{label}", FIELD, 0.082 * sign, 0.15 * sign, role=PANEL)
    side(f"AR_HandguardStripe_{label}", MAG_STRIPE, 0.079 * sign, 0.086 * sign, MAGENTA)
    side(f"AR_HandguardLine_{label}", CYAN_STRIPE, 0.079 * sign, 0.086 * sign, CYAN)
    plate(f"AR_HandguardStar_{label}", star(1.428, 0.318, 0.030, 0.013), 0.079 * sign, 0.086 * sign, YELLOW)
    for k, (x, size) in enumerate(((1.122, 0.022), (1.158, 0.016), (1.186, 0.010))):
        side(f"AR_HandguardPixel_{label}_{k + 1}", square(x, 0.318, size), 0.079 * sign, 0.086 * sign, MAGENTA)
    # Cabinet T-molding: a lit bar seated along the lower chamfer of the kick.
    trim = prism_along(f"AR_HandguardTrim_{label}", (1.046, 0.0735 * sign, 0.206), (1, 0, 0),
                       [(0, 0.003), (0.008, 0.0068), (0.439, 0.0068), (0.447, 0.003)], MAGENTA)
    trim["flat_group"] = "ARTrim"

# ---------------------------------------------------------------- stock frame art
# Raked band and line on the frame's solid front, a pixel trail back along the top bar.
for sign, label in ((1, "Left"), (-1, "Right")):
    side(f"AR_StockStripe_{label}", [(-0.500, 0.262), (-0.472, 0.262), (-0.432, 0.372), (-0.460, 0.372)],
         0.063 * sign, 0.070 * sign, MAGENTA)
    side(f"AR_StockLine_{label}", [(-0.462, 0.262), (-0.452, 0.262), (-0.412, 0.372), (-0.422, 0.372)],
         0.063 * sign, 0.070 * sign, CYAN)
    for k, (x, size) in enumerate(((-0.528, 0.009), (-0.553, 0.014), (-0.584, 0.020))):
        side(f"AR_StockPixel_{label}_{k + 1}", square(x, 0.372, size), 0.063 * sign, 0.070 * sign, MAGENTA)

# ---------------------------------------------------------------- cabinet butt
# Front buried 0.028 over the frame's rear member; raked marquee top; stepped rear.
butt = side("AR_CabinetButt", [
    (-0.962, 0.420), (-1.096, 0.446), (-1.124, 0.430), (-1.130, 0.382), (-1.112, 0.366),
    (-1.106, 0.205), (-1.130, 0.188), (-1.130, 0.150), (-1.114, 0.134), (-1.114, -0.052),
    (-1.092, -0.078), (-0.962, -0.078),
], -0.078, 0.078, BODY, bevel=0.008)
MARQUEE = [(-0.978, 0.372), (-1.098, 0.372), (-1.108, 0.382), (-1.108, 0.420), (-1.094, 0.432), (-0.978, 0.410)]
BUTT_FIELD = [(-0.994, 0.020), (-1.066, 0.020), (-1.066, 0.034), (-1.080, 0.034), (-1.080, 0.048),
              (-1.094, 0.048), (-1.094, 0.326), (-1.078, 0.342), (-0.996, 0.342), (-0.980, 0.326),
              (-0.980, 0.034)]
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(butt, f"AR_MarqueeSeat_{label}", MARQUEE, 0.070 * sign, 0.12 * sign, role=DARK)
    # The light's top rakes 2 degrees flatter than the butt top, so the two planes never coincide.
    side(f"AR_Marquee_{label}", [(-0.9755, 0.3695), (-1.0995, 0.3695), (-1.1105, 0.381), (-1.1105, 0.4215),
                                (-1.0950, 0.4345), (-0.9755, 0.4155)], 0.066 * sign, 0.0745 * sign, CYAN)
    recess(butt, f"AR_ButtField_{label}", BUTT_FIELD, 0.072 * sign, 0.12 * sign, role=PANEL)
    side(f"AR_ButtStripe_{label}", [(-1.078, 0.066), (-1.052, 0.066), (-1.022, 0.210), (-1.048, 0.210)],
         0.069 * sign, 0.076 * sign, MAGENTA)
    side(f"AR_ButtLine_{label}", [(-1.044, 0.066), (-1.034, 0.066), (-1.004, 0.210), (-1.014, 0.210)],
         0.069 * sign, 0.076 * sign, CYAN)
    plate(f"AR_ButtStar_{label}", star(-1.037, 0.282, 0.030, 0.013), 0.069 * sign, 0.076 * sign, YELLOW)

# ---------------------------------------------------------------- stepped suppressor can
# Rear section, light-ring groove, the main can, a stepped end cap and a bore; the Muzzle locator
# (x 2.502) sits in the bore.
can = prism_along("AR_SuppressorCan", (1.722, 0, 0.352), (1, 0, 0), [
    (0.000, 0.060), (0.016, 0.080), (0.200, 0.080), (0.208, 0.074), (0.236, 0.074), (0.250, 0.088),
    (0.690, 0.088), (0.698, 0.082), (0.760, 0.082), (0.783, 0.062), (0.783, 0.030), (0.750, 0.030),
], METAL)
prism_along("AR_BrakeLight", (1.927, 0, 0.352), (1, 0, 0), [(0, 0.0785), (0.034, 0.0785)], CYAN)["flat_group"] = "ARBrakeLight"

# ---------------------------------------------------------------- mag stripe
for sign, label in ((1, "Left"), (-1, "Right")):
    side(f"AR_MagStripe_{label}", [(0.735, -0.215), (0.759, -0.215), (0.759, -0.005), (0.735, -0.005)],
         0.049 * sign, 0.058 * sign, MAGENTA, bone="Mag")

result = finish_master(deck)
