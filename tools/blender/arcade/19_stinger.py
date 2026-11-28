"""Arcade Hornet (Stinger): cabinet control deck with joystick, buttons and pixel screen on the front
of the left receiver (ahead of the charging handle), a coin door on the rear right receiver, a rebuilt
fore-end box with side-art fields and lit edge trim, side-art fields on the stock adapter block, a
cabinet butt with marquee and side art, a stepped eight-sided brake with a light ring and a mag stripe.

Run in the live Blender MCP session with the stock
art-source/weapons/RemasterV2/Stinger/Stinger_RemasterV2_v05.blend open:
    exec(open("tools/blender/arcade/19_stinger.py").read(), {"VERSION": "v01"})
Left (+y) is the player-facing side (Cam_Hip y .61). Stock sights, rig, locators and CharmLoop are kept.
Stock measurements (2026-11-27, ray-cast depth maps and swept clips):
  receiver x -.51/.786, side face y .080 (z .16-.37), chamfer to .060 at .38, top .39; groove line
  z .19-.224 (y .076); charging-handle slot x -.198/.268, z .321-.347; the knob (y .068-.111) sweeps
  x -.027/.283 and never below z .308; the fire selector lever (pivot -.042/.204) sweeps up to z .263 at
  x -.10/.10 (y to .093); top rail x -.489/.546, y .052, z .386-.429; rear sight x -.418/-.398, y .066,
  z .371-.484; front cap x .78-.906 (y .070, z .189-.405); front sight base .792-.879 on the cap top,
  post .831-.84 to .466 under a Neon tip .462-.477; Neon squares at x -.462/-.417 and .288/.342
  (z .193-.221, both sides); fore-end box x .465-.825, z .105-.264, y .084; grip top .146 (receiver
  bottom .144); trigger guard x .126-.36, top .157-.162; mag in the grip, floor plate z -.585/-.532;
  stock adapter block x -.714/-.51, y .074, z .12-.384 with a round button (-.61, .25) each side; bars
  -1.41/-.708 (y .042); butt pad x -1.53/-1.398 (y .06); barrel collar .906-.984 r .05, muzzle device
  .98-1.14 r .043 on z .294, Muzzle x 1.14; bolt (right) runs back to x -.234 at y -.078/-.055,
  z .273-.314 and swings out to y -.121 in Draw at x > -.13.
ADS (adsDistance .30, eye x -.783, z .478): the rail (y .052, top .429) and the rear sight wings hide
the whole front of the left face; the rear of the receiver has no cover above the stock block (.384),
so the deck sits ahead of the charging handle and the joystick ball stays low (top .318).
"""

from pathlib import Path

import bpy

GUN = "Stinger"
VERSION = globals().get("VERSION", "v01")
exec((Path(bpy.data.filepath).parents[4] / "tools/blender/arcade/arcade_lib.py").read_text(encoding="utf-8"))

replace("Handguard", "Stock", "Barrel")

# ---------------------------------------------------------------- retained stock
for name in ("Receiver", "CharmLoop", "ChargingHandle", "Bolt", "FireSelector", "Trigger", "Grip",
             "Sights", "Neon"):
    dress(name)
dress("Mag", slots={"Dark": GRIP})
# The fore-end pins (x .49) sat on the stock fore-end box, which is rebuilt.
dress("Pins", keep=lambda island: not 0.48 < limits(island, 0)[0] < 0.52)
# Stock bars and adapter block without the butt pad (the cabinet butt replaces it) or the round
# adapter buttons (side-art fields take their place). The block is its own object: the exact boolean
# for its art fields drops the bars that run into it if they share the mesh.
dress("Stock", copy_name="AR_StockBlock", keep=lambda island: limits(island, 0)[0] > -0.72
      and limits(island, 1)[1] > 0.07 and limits(island, 1)[0] < -0.07)
dress("Stock", copy_name="AR_StockBars", keep=lambda island: -1.45 < limits(island, 0)[0] < -1.3)


def nudge(obj, pick, delta, island=None):
    """Move the vertices of a retained part that pick(world point) selects (rest pose, world space).
    island(lo, hi) limits the move to the connected pieces whose world bounds pass."""
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


# Gap sweep (owner 2026-11-27: no gaps anywhere). Measured stock joins that were under 0.02 deep:
# - grip top .146 on the receiver bottom .144 (0.002): the top rises 0.02;
# - trigger guard top .157-.162 into the receiver (.144): rises 0.01 (0.023 deep);
# - receiver rear face met the adapter block's front face at x -.51 (face to face): the receiver's rear
#   runs 0.02 back over the narrower block (y .080 over .074), and the block's front-top edge drops 0.006;
# - front cap (.78) only 0.006 into the receiver (.786): its rear runs 0.02 back inside;
# - top rail 0.004 on the receiver top (.39): its foot runs 0.02 down;
# - rear sight 0.006 into the receiver chamfer at its wings: its foot runs 0.015 down;
# - front sight base flush on the cap top (.405): its foot runs 0.02 down; post 0.002 into the base and
#   0.004 into the Neon tip: post foot 0.02 down, post top up 0.008, tip foot down 0.008 (tip top kept);
# - stock bars 0.006 into the adapter block: their fronts run 0.02 forward inside it;
# - mag body 0.002 into the floor plate: its bottom runs 0.02 down inside the plate;
# - barrel collar flush on the front cap (.906): replaced by the brake, 0.03 inside the cap.
RECEIVER, SIGHTS = native("Receiver"), native("Sights")
BLOCK, BARS = bpy.data.objects["AR_StockBlock"], bpy.data.objects["AR_StockBars"]
gap_moves = {
    "grip_top": nudge(native("Grip"), lambda p: p.z > 0.14, (0, 0, 0.020),
                      lambda lo, hi: lo.z < -0.1),
    "guard_top": nudge(native("Grip"), lambda p: p.z > 0.152, (0, 0, 0.010),
                       lambda lo, hi: lo.x > 0.12 and lo.z > 0.0),
    "receiver_rear": nudge(RECEIVER, lambda p: p.x < -0.50, (-0.020, 0, 0),
                           lambda lo, hi: lo.x < -0.5 and hi.x > 0.7),
    "front_cap": nudge(RECEIVER, lambda p: p.x < 0.79, (-0.020, 0, 0),
                       lambda lo, hi: lo.x > 0.77 and hi.x > 0.9),
    "rail": nudge(RECEIVER, lambda p: p.z < 0.392, (0, 0, -0.020),
                  lambda lo, hi: lo.z > 0.38 and hi.z > 0.42),
    "rear_sight": nudge(SIGHTS, lambda p: p.z < 0.376, (0, 0, -0.015),
                        lambda lo, hi: hi.x < -0.39),
    "front_sight_base": nudge(SIGHTS, lambda p: p.z < 0.41, (0, 0, -0.020),
                              lambda lo, hi: lo.x < 0.8 and hi.x > 0.87),
    "front_sight_post_foot": nudge(SIGHTS, lambda p: p.z < 0.432, (0, 0, -0.020),
                                   lambda lo, hi: lo.z > 0.42 and hi.z < 0.47),
    "front_sight_post_top": nudge(SIGHTS, lambda p: p.z > 0.46, (0, 0, 0.008),
                                  lambda lo, hi: lo.z > 0.40 and hi.z < 0.47 and hi.x < 0.845),
    "front_sight_tip": nudge(SIGHTS, lambda p: p.z < 0.465, (0, 0, -0.008),
                             lambda lo, hi: lo.z > 0.46),
    "stock_bars": nudge(BARS, lambda p: p.x > -0.72, (0.020, 0, 0)),
    # The block's top chamfer stood 0.002 outside the receiver's rear chamfer inside the new sleeve:
    # its front-top edge drops 0.006 (a slope of 0.006 over the block's length).
    "block_front_top": nudge(BLOCK, lambda p: p.x > -0.52 and p.z > 0.36, (0, 0, -0.006)),
    "mag_floor": nudge(native("Mag"), lambda p: p.z < -0.52, (0, 0, -0.020),
                       lambda lo, hi: hi.z > -0.1 and lo.z < -0.5 and hi.y < 0.052),
}


def crect(x0, z0, x1, z1, c):
    return [(x0 + c, z0), (x1 - c, z0), (x1, z0 + c), (x1, z1 - c),
            (x1 - c, z1), (x0 + c, z1), (x0, z1 - c), (x0, z0 + c)]


def square(x, z, size):
    return [(x - size / 2, z - size / 2), (x + size / 2, z - size / 2),
            (x + size / 2, z + size / 2), (x - size / 2, z + size / 2)]


def inset(outline, d):
    """Offset a convex (x, z) outline inward by d (mitred corners)."""
    area = sum(x0 * z1 - x1 * z0 for (x0, z0), (x1, z1) in zip(outline, outline[1:] + outline[:1]))
    turn = 1 if area > 0 else -1
    out = []
    for i, (x, z) in enumerate(outline):
        normals = []
        for (ax, az), (bx, bz) in ((outline[i - 1], (x, z)), ((x, z), outline[(i + 1) % len(outline)])):
            ex, ez = bx - ax, bz - az
            length = math.hypot(ex, ez)
            normals.append((-ez * turn / length, ex * turn / length))
        (n1x, n1z), (n2x, n2z) = normals
        k = d / (1 + n1x * n2x + n1z * n2z)
        out.append((x + (n1x + n2x) * k, z + (n1z + n2z) * k))
    return out


def slab(name, outline, near, far, role, chamfer, *, bone="Root"):
    """A plate whose back (near) is buried: only the exposed front edge gets the flat chamfer."""
    step = chamfer if far > near else -chamfer
    return loft(name, [[(x, near, z) for x, z in outline], [(x, far - step, z) for x, z in outline],
                       [(x, far, z) for x, z in inset(outline, chamfer)]], role, bone=bone)


# ---------------------------------------------------------------- left: cabinet deck
# On the front of the receiver face (.080): back y .072 (buried), face .092. Ahead of the charging
# handle's furthest reach (x .283) and above the fore-end box (.264); under the receiver chamfer (.37).
DECK = [(0.300, 0.272), (0.764, 0.272), (0.772, 0.280), (0.772, 0.352), (0.758, 0.366),
        (0.310, 0.366), (0.292, 0.348), (0.292, 0.280)]
deck = slab("AR_ControlDeck_Left", DECK, 0.072, 0.092, PANEL, 0.0018)

# Joystick at the rear, low (ball top .318, under the rail's shadow from the ADS eye), then three
# faceted buttons in collars rising toward the muzzle.
JX, JZ = 0.335, 0.300
prism_along("AR_JoystickWasher", (JX, 0.088, JZ), (0, 1, 0), [(0, 0.021), (0.009, 0.0175)], DARK)
prism_along("AR_JoystickShaft", (JX, 0.094, JZ), (0, 1, 0), [(0, 0.0065), (0.034, 0.0065)], METAL)
stick_ball = prism_along("AR_JoystickBall", (JX, 0.094, JZ), (0, 1, 0), [
    (0.028, 0.009), (0.035, 0.018), (0.047, 0.018), (0.054, 0.009),
], BTN_MAGENTA)
stick_ball["flat_group"] = "ARStickBall"
for i, (x, z, role) in enumerate(((0.398, 0.304, BTN_CYAN), (0.456, 0.314, BTN_YELLOW),
                                  (0.514, 0.324, BTN_MAGENTA))):
    prism_along(f"AR_ButtonCollar_{i + 1}", (x, 0.088, z), (0, 1, 0),
                [(0, 0.026), (0.010, 0.0225)], DARK)
    button = prism_along(f"AR_Button_{i + 1}", (x, 0.094, z), (0, 1, 0),
                         [(0, 0.020), (0.016, 0.020), (0.021, 0.014)], role)
    button["flat_group"] = f"ARButton{i + 1}"

# Pixel screen: bezel ring, glowing screen floor, pixel graphic standing 0.004 proud.
inner = crect(0.568, 0.294, 0.750, 0.348, 0.008)
outer = crect(0.556, 0.284, 0.762, 0.358, 0.012)
loft("AR_ScreenBezel_Left", [
    [(x, 0.088, z) for x, z in outer], [(x, 0.102, z) for x, z in outer],
    [(x, 0.102, z) for x, z in inner], [(x, 0.088, z) for x, z in inner],
], DARK, loop=True)
plate("AR_Screen_Left", crect(0.566, 0.292, 0.752, 0.350, 0.008), 0.089, 0.095, SCREEN)["flat_group"] = "ARScreen"
PX = 0.0085
SX, SZ = 0.578, 0.2985
SHIP = {(0, 4), (1, 4), (0, 3), (1, 3), (2, 3), (3, 3), (1, 2), (2, 2), (3, 2), (4, 2), (5, 2), (6, 2),
        (0, 1), (1, 1), (2, 1), (3, 1), (0, 0), (1, 0)}
pixel_solid("AR_ScreenShip_Left", SHIP, SX, SZ, PX, 0.094, 0.099, CYAN)["flat_group"] = "ARScreenShip"
pixel_solid("AR_ScreenShot_Left", {(0, 0), (1, 0), (2, 0)}, SX + 8 * PX, SZ + 2 * PX, PX,
            0.094, 0.099, MAGENTA)["flat_group"] = "ARScreenShot"
PLUS = {(1, 0), (0, 1), (1, 1), (2, 1), (1, 2)}
pixel_solid("AR_ScreenStarA_Left", PLUS, 0.700, SZ + 2 * PX, PX, 0.094, 0.099, YELLOW)["flat_group"] = "ARScreenStars"
pixel_solid("AR_ScreenStarB_Left", {(0, 0)}, 0.735, SZ + 1 * PX, PX, 0.094, 0.099, YELLOW)["flat_group"] = "ARScreenStars"
pixel_solid("AR_ScreenStarC_Left", {(0, 0)}, 0.6895, SZ + 4 * PX, PX, 0.094, 0.099, CYAN)["flat_group"] = "ARScreenBlip"

# Cyan light pipe along the deck's top edge over the screen: back buried in the receiver chamfer,
# front 0.003 behind the deck face, 0.006 above the deck top.
side("AR_DeckLight_Left", [(0.556, 0.361), (0.752, 0.361), (0.758, 0.372), (0.562, 0.372)],
     0.066, 0.089, CYAN)["flat_group"] = "ARDeckLight"

# ---------------------------------------------------------------- right: coin door
# On the rear of the right receiver face (-.080), behind the bolt's furthest travel (x -.234) and
# above the groove line; the top-rear corner rakes down away from the ADS eye.
COIN = [(-0.458, 0.232), (-0.267, 0.232), (-0.255, 0.244), (-0.255, 0.328), (-0.267, 0.340),
        (-0.400, 0.340), (-0.470, 0.312), (-0.470, 0.244)]
coin = slab("AR_CoinDoor_Right", COIN, -0.072, -0.090, METAL, 0.0018)
for i, x in enumerate((-0.405, -0.325)):
    block = slab(f"AR_CoinEntry_{i + 1}", crect(x - 0.028, 0.262, x + 0.028, 0.312, 0.006),
                 -0.086, -0.102, ACCENT, 0.0015)
    recess(block, f"AR_CoinSlotCut_{i + 1}", crect(x - 0.004, 0.272, x + 0.004, 0.302, 0.002),
           -0.096, -0.122, role=DARK)
    side(f"AR_CoinSlotLight_{i + 1}", crect(x - 0.0055, 0.271, x + 0.0055, 0.303, 0.002),
         -0.092, -0.100, YELLOW)
side("AR_CoinStripe_Right", [(-0.290, 0.244), (-0.272, 0.244), (-0.263, 0.328), (-0.281, 0.328)],
     -0.086, -0.092, MAGENTA)

# ---------------------------------------------------------------- fore-end box
# The stock box envelope (x .465-.825, z .105-.264, y .084) with a raked cabinet front.
hand = side("AR_ForeEnd", [(0.465, 0.112), (0.472, 0.105), (0.775, 0.105), (0.825, 0.150),
                           (0.825, 0.264), (0.465, 0.264)], -0.084, 0.084, BODY)
# Budget: the chamfer takes the square edges only (60 degrees); the 45-degree outline corners are
# chamfers already.
chamfer(hand, 0.004, angle=60)
FIELD = [(0.505, 0.165), (0.517, 0.165), (0.517, 0.153), (0.529, 0.153), (0.529, 0.141),
         (0.770, 0.141), (0.790, 0.161), (0.790, 0.228), (0.775, 0.243), (0.520, 0.243), (0.505, 0.228)]
MAG_STRIPE = [(0.592, 0.147), (0.624, 0.147), (0.664, 0.237), (0.632, 0.237)]
CYAN_STRIPE = [(0.636, 0.147), (0.646, 0.147), (0.686, 0.237), (0.676, 0.237)]
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(hand, f"AR_ForeEndField_{label}", FIELD, 0.078 * sign, 0.15 * sign, role=PANEL)
    side(f"AR_ForeEndStripe_{label}", MAG_STRIPE, 0.075 * sign, 0.082 * sign, MAGENTA)
    side(f"AR_ForeEndLine_{label}", CYAN_STRIPE, 0.075 * sign, 0.082 * sign, CYAN)
    plate(f"AR_ForeEndStar_{label}", star(0.744, 0.196, 0.026, 0.011), 0.075 * sign, 0.082 * sign, YELLOW)
    for k, (x, size) in enumerate(((0.533, 0.016), (0.554, 0.012), (0.571, 0.008))):
        side(f"AR_ForeEndPixel_{label}_{k + 1}", square(x, 0.200, size), 0.075 * sign, 0.082 * sign, MAGENTA)
    # Cabinet T-molding: a lit bar seated along the box's lower edge, ahead of the charm loop.
    trim = prism_along(f"AR_ForeEndTrim_{label}", (0.490, 0.0815 * sign, 0.1075), (1, 0, 0),
                       [(0, 0.003), (0.008, 0.0068), (0.262, 0.0068), (0.270, 0.003)], MAGENTA)
    trim["flat_group"] = "ARTrim"

# ---------------------------------------------------------------- stock adapter block art
STOCK_FIELD = [(-0.690, 0.180), (-0.678, 0.180), (-0.678, 0.168), (-0.666, 0.168), (-0.666, 0.156),
               (-0.566, 0.156), (-0.552, 0.170), (-0.552, 0.336), (-0.566, 0.350), (-0.676, 0.350),
               (-0.690, 0.336)]
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(BLOCK, f"AR_StockField_{label}", STOCK_FIELD, 0.068 * sign, 0.15 * sign, role=PANEL)
    side(f"AR_StockStripe_{label}", [(-0.664, 0.170), (-0.640, 0.170), (-0.600, 0.300), (-0.624, 0.300)],
         0.065 * sign, 0.072 * sign, MAGENTA)
    side(f"AR_StockLine_{label}", [(-0.632, 0.170), (-0.624, 0.170), (-0.584, 0.300), (-0.592, 0.300)],
         0.065 * sign, 0.072 * sign, CYAN)
    plate(f"AR_StockStar_{label}", star(-0.660, 0.318, 0.022, 0.009), 0.065 * sign, 0.072 * sign, YELLOW)
    for k, (x, z, size) in enumerate(((-0.574, 0.190, 0.014), (-0.570, 0.212, 0.010), (-0.567, 0.229, 0.007))):
        side(f"AR_StockPixel_{label}_{k + 1}", square(x, z, size), 0.065 * sign, 0.072 * sign, MAGENTA)

# ---------------------------------------------------------------- cabinet butt
# Front swallows the bars' rear ends (0.025+); raked marquee top; stepped rear.
butt = side("AR_CabinetButt", [
    (-1.375, 0.318), (-1.470, 0.340), (-1.500, 0.326), (-1.508, 0.285), (-1.492, 0.268),
    (-1.488, 0.130), (-1.510, 0.115), (-1.510, 0.075), (-1.494, 0.060), (-1.494, -0.075),
    (-1.474, -0.104), (-1.375, -0.104),
], -0.060, 0.060, BODY)
chamfer(butt, 0.006, angle=60)
MARQUEE = [(-1.388, 0.272), (-1.474, 0.272), (-1.488, 0.284), (-1.488, 0.314), (-1.472, 0.328), (-1.388, 0.310)]
BUTT_FIELD = [(-1.404, -0.074), (-1.448, -0.074), (-1.448, -0.062), (-1.460, -0.062), (-1.460, -0.050),
              (-1.472, -0.050), (-1.472, 0.226), (-1.460, 0.238), (-1.402, 0.238), (-1.390, 0.226),
              (-1.390, -0.062)]
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(butt, f"AR_MarqueeSeat_{label}", MARQUEE, 0.052 * sign, 0.12 * sign, role=DARK)
    # The light's top rakes a little flatter than the seat, so the two planes never coincide.
    side(f"AR_Marquee_{label}", [(-1.3855, 0.2695), (-1.4765, 0.2695), (-1.4905, 0.2825), (-1.4905, 0.3155),
                                (-1.4735, 0.3305), (-1.3855, 0.3135)], 0.048 * sign, 0.0565 * sign, CYAN)
    recess(butt, f"AR_ButtField_{label}", BUTT_FIELD, 0.052 * sign, 0.12 * sign, role=PANEL)
    side(f"AR_ButtStripe_{label}", [(-1.462, -0.040), (-1.440, -0.040), (-1.414, 0.120), (-1.436, 0.120)],
         0.049 * sign, 0.056 * sign, MAGENTA)
    side(f"AR_ButtLine_{label}", [(-1.430, -0.040), (-1.421, -0.040), (-1.395, 0.120), (-1.404, 0.120)],
         0.049 * sign, 0.056 * sign, CYAN)
    plate(f"AR_ButtStar_{label}", star(-1.431, 0.185, 0.026, 0.011), 0.049 * sign, 0.056 * sign, YELLOW)

# ---------------------------------------------------------------- stepped brake
# Rear collar 0.03 inside the front cap, light-ring groove with the cyan ring, the main brake, a
# stepped end and a bore; the Muzzle locator (x 1.14) sits at the bore mouth.
prism_along("AR_Brake", (0.876, 0, 0.294), (1, 0, 0), [
    (0.000, 0.050), (0.040, 0.050), (0.046, 0.054), (0.085, 0.054), (0.091, 0.046), (0.123, 0.046),
    (0.129, 0.054), (0.234, 0.054), (0.244, 0.044), (0.264, 0.044), (0.264, 0.020), (0.240, 0.020),
], METAL)
prism_along("AR_BrakeLight", (0.965, 0, 0.294), (1, 0, 0), [(0, 0.0505), (0.036, 0.0505)], CYAN)["flat_group"] = "ARBrakeLight"

# ---------------------------------------------------------------- mag stripe
# Along the raked front band of the magazine below the grip.
for sign, label in ((1, "Left"), (-1, "Right")):
    side(f"AR_MagStripe_{label}", [(-0.014, -0.490), (0.002, -0.490), (0.0215, -0.270), (0.0055, -0.270)],
         0.047 * sign, 0.055 * sign, MAGENTA, bone="Mag")

result = finish_master(deck)
result["gap_moves"] = gap_moves


def ads_exposed(ads_distance=0.30, fov_y=72, aspect=16 / 9):
    """New vertices the ADS eye can see inside the ADS frustum (first ray hit is the part itself)."""
    aim = native("AimPoint").matrix_world.translation
    eye = aim - Vector((ads_distance / 0.8, 0, 0))
    tan_v = math.tan(math.radians(fov_y / 2))
    tan_h = tan_v * aspect
    depsgraph = bpy.context.evaluated_depsgraph_get()
    seen = {}
    for obj in shells.objects:
        if obj.type != "MESH" or obj.hide_render:
            continue
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        for vertex in mesh.vertices:
            point = evaluated.matrix_world @ vertex.co
            ray = point - eye
            if ray.x <= 0 or abs(ray.z) / ray.x > tan_v or abs(ray.y) / ray.x > tan_h:
                continue
            hit, location, _n, _i, hit_obj, _m = scene.ray_cast(depsgraph, eye, ray.normalized(), distance=ray.length + 1e-4)
            if hit and hit_obj.name == obj.name and (location - point).length < 2e-3:
                seen.setdefault(obj.name, []).append(tuple(round(c, 3) for c in point))
        evaluated.to_mesh_clear()
    return {name: (len(points), points[:4]) for name, points in seen.items()}


result["ads_exposed"] = ads_exposed()
