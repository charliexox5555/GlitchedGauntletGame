"""Arcade Prowler (Spectre): cabinet side deck with joystick, buttons and pixel screen on the upper
receiver, coin door on the lower receiver, a side-art handguard with lit edge trim and a raked
cabinet nose, stock-frame art, a cabinet butt with marquee and side art, and a stepped eight-sided
suppressor can with a light ring.

Run in the live Blender MCP session with the stock
art-source/weapons/RemasterV2/Spectre/Spectre_RemasterV2_v05.blend open:
    exec(open("tools/blender/arcade/12_spectre.py").read(), {"VERSION": "v01"})
Left (+y) is the player-facing side. Stock sights, rig, locators and CharmLoop are kept.
Stock measurements (2026-11-27, ray-cast depth maps and swept clips):
  upper receiver side face y .082 (z .277-.417), charging-handle slot floor .068 (x .16-.56,
  z .374-.404); the handle knob never comes behind x .45 (Fire); lower receiver face y .078
  (x -.18-.685, z .14-.265); the fire selector lever (pivot .221/.213) sweeps up to z .291 at
  y .080 in Reload; a stock Neon square at x -.162/-.095, z .291-.322 (removed under the deck);
  right side: ejection port x .24-.47 above z .36, mag release x .39-.43, pin heads y .082;
  handguard x .697-1.14, profile y .090, bottom .23, keel .26, shoulder .443, top .473;
  CharmLoop x .784-.816, z .243-.285 on the lower left chamfer; front sight base x .969-1.064
  on the top; barrel stub r .065 x 1.137-1.262, can r .091 x 1.257-1.904, Muzzle x 1.901;
  stock frame face y .066 (top bar z .28-.38, window x -.869/-.601), butt pad x -.955/-1.067;
  magazine face y .056 with a raked recessed panel (.052).
"""

from pathlib import Path

import bpy

GUN = "Spectre"
VERSION = globals().get("VERSION", "v01")
exec((Path(bpy.data.filepath).parents[4] / "tools/blender/arcade/arcade_lib.py").read_text(encoding="utf-8"))

replace("Handguard", "Stock", "Suppressor", "Neon")

# ---------------------------------------------------------------- retained stock
for name in ("Receiver", "Pins", "CharmLoop", "ChargingHandle", "Bolt",
             "FireSelector", "Trigger", "Grip", "Sights"):
    dress(name)
dress("Mag", slots={"Dark": GRIP})
# The stock fire selector has one flush pair (a Metal face on its Accent lever face): lift it 0.004
# in the build, the same lift the flat export would make.
_flat = {}
exec((ROOT / "tools/blender/export_roblox_flat.py").read_text(encoding="utf-8"), _flat)
_flat["resolve_coplanar"]([native("FireSelector")])
# Stock Neon: keep the front-sight strips; the side square sits under the new deck.
dress("Neon", copy_name="AR_SightNeon", keep=lambda island: limits(island, 0)[0] > 0.5)
# Stock skeleton frame and buffer mount without the butt pad (the cabinet butt replaces it).
dress("Stock", copy_name="AR_StockFrame", keep=lambda island: limits(island, 0)[0] > -0.98)
# Suppressor: keep only the barrel stub; the faceted can replaces the round can.
dress("Suppressor", copy_name="AR_BarrelStub", keep=lambda island: limits(island, 0)[1] < 1.27)


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


# Gap sweep (owner 2026-11-27: "make sure there's no like gaps"). Culled magenta close-ups and measured
# joins found these stock gaps; each part is now buried 0.02+ in what it meets:
# - lower receiver to handguard: the lower receiver stops at x .683, the handguard started at .697, so a
#   0.014 see-through slot sat under the upper receiver, a daylight notch sat under the rail base at the
#   upper receiver's chamfered front-top corner, and the upper receiver's front face stood 0.003 off the
#   handguard (see the handguard);
# - grip: its open top was only 0.0036 into the receiver's underside (.131), and its front-top corner
#   stopped 0.004 short of the trigger guard's rear member (x .132): the top rises 0.02 and the front-top
#   corner runs 0.022 forward into the member;
# - buffer mount: 0.008 into the upper receiver (rear x -.33): its front is now -.308;
# - barrel stub: 0.009 into the handguard's nose: its rear is now 1.107;
# - front sight: the base sat 0.003 into the handguard top (.473) and the post 0.004 into the base: both
#   feet run 0.02 deeper; the hood wings' outer feet hung 0.006 over the handguard: they now reach it;
# - rear sight post: 0.013 into the receiver top: its foot is now .419.
SIGHTS = native("Sights")
gap_moves = {
    "grip_front_top": nudge(native("Grip"), lambda p: p.x > 0.11 and p.z > 0.118, (0.022, 0, 0)),
    "grip_top": nudge(native("Grip"), lambda p: p.z > 0.125 and p.x > -0.17, (0, 0, 0.020)),
    "buffer_mount": nudge(bpy.data.objects["AR_StockFrame"], lambda p: p.x > -0.325, (0.014, 0, 0),
                          lambda lo, hi: abs(lo.x + 0.43) < 0.01 and abs(hi.x + 0.322) < 0.01),
    "barrel_stub": nudge(bpy.data.objects["AR_BarrelStub"], lambda p: p.x < 1.14, (-0.030, 0, 0)),
    "front_sight_base": nudge(SIGHTS, lambda p: p.z < 0.471, (0, 0, -0.020),
                              lambda lo, hi: lo.x < 0.97 and hi.x > 1.06 and hi.z < 0.5),
    "front_sight_post": nudge(SIGHTS, lambda p: p.z < 0.487, (0, 0, -0.020),
                              lambda lo, hi: lo.x > 1.01 and hi.x < 1.025 and lo.z > 0.48 and hi.z < 0.53),
    "front_sight_wings": nudge(SIGHTS, lambda p: p.z < 0.48, (0, 0, -0.012),
                               lambda lo, hi: lo.x > 1.0 and hi.x < 1.035 and hi.y > 0.044),
    "rear_sight_post": nudge(SIGHTS, lambda p: p.z < 0.43, (0, 0, -0.010),
                             lambda lo, hi: lo.x < -0.06 and hi.x > -0.045 and lo.z < 0.43),
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
# On the upper receiver face (.082): back at y .074 (buried), face .094 (0.012 proud), behind the
# charging-handle slot (x .16). The bottom (.282) covers the stock's empty Neon-square pocket
# (x -.165/-.092, z .288-.325) and rakes up ahead of x .10 to clear the fire selector lever's
# reload sweep (z .287 at x .13, .294 at x .21).
# ADS (adsDistance .37, eye x -.5155, z .524, FOV up to 72): everything on the deck stays under the
# receiver's top-left edge as seen from the eye ((.524 - z) > 1.325 y), and the joystick ball sits
# far enough back and low enough to fall below the bottom of the ADS view.
# The top-rear corner is raked away: behind x -.33 nothing hides it from the ADS eye.
DECK = [(-0.303, 0.282), (0.100, 0.282), (0.130, 0.306), (0.146, 0.380), (0.140, 0.392),
        (-0.262, 0.392), (-0.316, 0.345), (-0.316, 0.295)]
deck = slab("AR_ControlDeck_Left", DECK, 0.074, 0.094, PANEL, 0.0018)

# Joystick at the rear, then three faceted buttons in collars rising toward the muzzle
# (scaled down for the SMG: buttons r .020 in r .026 collars).
prism_along("AR_JoystickWasher", (-0.282, 0.090, 0.328), (0, 1, 0), [(0, 0.021), (0.009, 0.0175)], DARK)
prism_along("AR_JoystickShaft", (-0.282, 0.096, 0.328), (0, 1, 0), [(0, 0.0065), (0.034, 0.0065)], METAL)
stick_ball = prism_along("AR_JoystickBall", (-0.282, 0.096, 0.328), (0, 1, 0), [
    (0.028, 0.009), (0.035, 0.018), (0.047, 0.018), (0.054, 0.009),
], BTN_MAGENTA)
stick_ball["flat_group"] = "ARStickBall"
for i, (x, z, role) in enumerate(((-0.215, 0.334, BTN_CYAN), (-0.160, 0.338, BTN_YELLOW),
                                  (-0.105, 0.342, BTN_MAGENTA))):
    prism_along(f"AR_ButtonCollar_{i + 1}", (x, 0.090, z), (0, 1, 0),
                [(0, 0.026), (0.010, 0.0225)], DARK)
    button = prism_along(f"AR_Button_{i + 1}", (x, 0.096, z), (0, 1, 0),
                         [(0, 0.020), (0.016, 0.020), (0.021, 0.014)], role)
    button["flat_group"] = f"ARButton{i + 1}"

# Pixel screen: bezel ring, glowing screen floor, pixel graphic standing 0.004 proud.
inner = crect(-0.054, 0.314, 0.110, 0.364, 0.008)
outer = crect(-0.066, 0.304, 0.122, 0.374, 0.014)
loft("AR_ScreenBezel_Left", [
    [(x, 0.090, z) for x, z in outer], [(x, 0.104, z) for x, z in outer],
    [(x, 0.104, z) for x, z in inner], [(x, 0.090, z) for x, z in inner],
], DARK, loop=True)
plate("AR_Screen_Left", crect(-0.056, 0.312, 0.112, 0.366, 0.008), 0.091, 0.097, SCREEN)["flat_group"] = "ARScreen"
PX = 0.0085
SX, SZ = -0.046, 0.3175
SHIP = {(0, 4), (1, 4), (0, 3), (1, 3), (2, 3), (3, 3), (1, 2), (2, 2), (3, 2), (4, 2), (5, 2), (6, 2),
        (0, 1), (1, 1), (2, 1), (3, 1), (0, 0), (1, 0)}
pixel_solid("AR_ScreenShip_Left", SHIP, SX, SZ, PX, 0.096, 0.101, CYAN)["flat_group"] = "ARScreenShip"
pixel_solid("AR_ScreenShot_Left", {(0, 0), (1, 0), (2, 0)}, SX + 8 * PX, SZ + 2 * PX, PX,
            0.096, 0.101, MAGENTA)["flat_group"] = "ARScreenShot"
PLUS = {(1, 0), (0, 1), (1, 1), (2, 1), (1, 2)}
pixel_solid("AR_ScreenStarA_Left", PLUS, 0.068, SZ + 2 * PX, PX, 0.096, 0.101, YELLOW)["flat_group"] = "ARScreenStars"
pixel_solid("AR_ScreenStarB_Left", {(0, 0)}, 0.100, SZ + 1 * PX, PX, 0.096, 0.101, YELLOW)["flat_group"] = "ARScreenStars"
pixel_solid("AR_ScreenStarC_Left", {(0, 0)}, 0.056, SZ + 4 * PX, PX, 0.096, 0.101, CYAN)["flat_group"] = "ARScreenBlip"

# Cyan light pipe along the deck's top edge over the screen: back buried in the receiver face,
# front 0.003 behind the deck face, 0.008 above the deck top.
side("AR_DeckLight_Left", [(-0.062, 0.388), (0.120, 0.388), (0.128, 0.400), (-0.054, 0.400)],
     0.078, 0.091, CYAN)["flat_group"] = "ARDeckLight"

# ---------------------------------------------------------------- right: coin door
# On the lower receiver face (-.078), behind the mag release (x .39) and below the upper receiver.
coin = slab("AR_CoinDoor_Right", crect(-0.165, 0.150, 0.362, 0.258, 0.012), -0.074, -0.092, METAL, 0.0018)
for i, x in enumerate((0.010, 0.130)):
    block = slab(f"AR_CoinEntry_{i + 1}", crect(x - 0.030, 0.178, x + 0.030, 0.231, 0.006),
                 -0.088, -0.104, ACCENT, 0.0015)
    recess(block, f"AR_CoinSlotCut_{i + 1}", crect(x - 0.004, 0.189, x + 0.004, 0.220, 0.002),
           -0.098, -0.124, role=DARK)
    side(f"AR_CoinSlotLight_{i + 1}", crect(x - 0.0055, 0.188, x + 0.0055, 0.221, 0.002),
         -0.094, -0.102, YELLOW)
side("AR_CoinStripe_Right", [(0.236, 0.160), (0.271, 0.160), (0.313, 0.248), (0.278, 0.248)],
     -0.088, -0.094, MAGENTA)

# ---------------------------------------------------------------- handguard
# Stock envelope (y .090, keel .260, shoulder .443, top .473); the front rakes back under the barrel stub
# like a cabinet front. Gap sweep: the rear starts at x .650, not at the receiver's front face (.697, as
# the stock), so it sleeves 0.047 over the upper receiver and 0.033 over the lower receiver (front .683),
# closing the slot between them and the notch under the rail base. The last rail tooth (x .63-.654) and
# the two lower-receiver pins beside it run 0.004 into the sleeve's rear wall instead of standing a
# hairline off it.
hand = folded("AR_Handguard", (
    (0.650, 0.230, 0.473, 0.090, 0.443, 0.260, 0.056),
    (1.100, 0.230, 0.473, 0.090, 0.443, 0.260, 0.056),
    (1.146, 0.282, 0.470, 0.084, 0.440, 0.300, 0.052),
), BODY, bevel=0.004)
# The charging-handle knob (rest x .70, up to .71 in the clips) runs on into a slot in the handguard's
# rear-left; a pocket behind the receiver's front face takes the handle's inward swing in Draw. Both start
# at .637 so they clear the sleeve.
recess(hand, "AR_HandleSlotCut", crect(0.637, 0.312, 0.716, 0.422, 0.002), 0.062, 0.15, role=DARK)
recess(hand, "AR_HandlePocketCut", crect(0.637, 0.312, 0.730, 0.424, 0.004), -0.060, 0.066, role=DARK)
FIELD = [(0.840, 0.312), (0.856, 0.312), (0.856, 0.295), (0.872, 0.295), (0.872, 0.278),
         (1.082, 0.278), (1.110, 0.306), (1.110, 0.404), (1.082, 0.432), (0.860, 0.432), (0.840, 0.412)]
MAG_STRIPE = [(0.905, 0.281), (0.945, 0.281), (1.025, 0.429), (0.985, 0.429)]
CYAN_STRIPE = [(0.958, 0.281), (0.970, 0.281), (1.050, 0.429), (1.038, 0.429)]
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(hand, f"AR_HandguardField_{label}", FIELD, 0.084 * sign, 0.15 * sign, role=PANEL)
    side(f"AR_HandguardStripe_{label}", MAG_STRIPE, 0.081 * sign, 0.088 * sign, MAGENTA)
    side(f"AR_HandguardLine_{label}", CYAN_STRIPE, 0.081 * sign, 0.088 * sign, CYAN)
    plate(f"AR_HandguardStar_{label}", star(1.075, 0.370, 0.026, 0.011), 0.081 * sign, 0.088 * sign, YELLOW)
    for k, (x, size) in enumerate(((0.862, 0.016), (0.885, 0.012), (0.903, 0.008))):
        side(f"AR_HandguardPixel_{label}_{k + 1}", square(x, 0.350, size), 0.081 * sign, 0.088 * sign, MAGENTA)
    # Cabinet T-molding: a lit bar seated along the lower chamfer, ahead of the charm loop.
    trim = prism_along(f"AR_HandguardTrim_{label}", (0.845, 0.075 * sign, 0.245), (1, 0, 0),
                       [(0, 0.003), (0.008, 0.0068), (0.242, 0.0068), (0.250, 0.003)], MAGENTA)
    trim["flat_group"] = "ARTrim"

# ---------------------------------------------------------------- stock frame art
# Raked band and line on the frame's solid front, a pixel trail back along the top bar
# (growing away from the band, as on the Havoc and Spirit).
for sign, label in ((1, "Left"), (-1, "Right")):
    side(f"AR_StockStripe_{label}", [(-0.560, 0.276), (-0.532, 0.276), (-0.494, 0.374), (-0.522, 0.374)],
         0.063 * sign, 0.070 * sign, MAGENTA)
    side(f"AR_StockLine_{label}", [(-0.522, 0.276), (-0.512, 0.276), (-0.474, 0.374), (-0.484, 0.374)],
         0.063 * sign, 0.070 * sign, CYAN)
    for k, (x, size) in enumerate(((-0.572, 0.009), (-0.594, 0.014), (-0.624, 0.020))):
        side(f"AR_StockPixel_{label}_{k + 1}", square(x, 0.330, size), 0.063 * sign, 0.070 * sign, MAGENTA)

# ---------------------------------------------------------------- cabinet butt
# Front swallows the frame's rear member; raked marquee top; stepped rear.
butt = side("AR_CabinetButt", [
    (-0.925, 0.412), (-1.040, 0.436), (-1.068, 0.420), (-1.074, 0.374), (-1.056, 0.358),
    (-1.050, 0.200), (-1.074, 0.183), (-1.074, 0.145), (-1.058, 0.129), (-1.058, -0.100),
    (-1.036, -0.128), (-0.925, -0.128),
], -0.078, 0.078, BODY, bevel=0.008)
MARQUEE = [(-0.940, 0.366), (-1.044, 0.366), (-1.054, 0.376), (-1.054, 0.412), (-1.040, 0.424), (-0.940, 0.403)]
BUTT_FIELD = [(-0.956, -0.090), (-1.008, -0.090), (-1.008, -0.076), (-1.022, -0.076), (-1.022, -0.062),
              (-1.036, -0.062), (-1.036, 0.326), (-1.020, 0.342), (-0.957, 0.342), (-0.941, 0.326),
              (-0.941, -0.076)]
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(butt, f"AR_MarqueeSeat_{label}", MARQUEE, 0.070 * sign, 0.12 * sign, role=DARK)
    # The light's top rakes a little flatter than the seat, so the two planes never coincide.
    side(f"AR_Marquee_{label}", [(-0.9375, 0.3635), (-1.0465, 0.3635), (-1.0565, 0.3745), (-1.0565, 0.4135),
                                (-1.0410, 0.4265), (-0.9375, 0.4045)], 0.066 * sign, 0.0745 * sign, CYAN)
    recess(butt, f"AR_ButtField_{label}", BUTT_FIELD, 0.072 * sign, 0.12 * sign, role=PANEL)
    side(f"AR_ButtStripe_{label}", [(-1.024, -0.040), (-1.000, -0.040), (-0.972, 0.130), (-0.996, 0.130)],
         0.069 * sign, 0.076 * sign, MAGENTA)
    side(f"AR_ButtLine_{label}", [(-0.990, -0.040), (-0.980, -0.040), (-0.952, 0.130), (-0.962, 0.130)],
         0.069 * sign, 0.076 * sign, CYAN)
    plate(f"AR_ButtStar_{label}", star(-0.989, 0.250, 0.028, 0.012), 0.069 * sign, 0.076 * sign, YELLOW)

# ---------------------------------------------------------------- stepped suppressor can
# Rear section over the barrel stub, light-ring groove with the cyan ring, the main can, a stepped
# end cap and a bore; the Muzzle locator (x 1.901) sits in the bore.
can = prism_along("AR_SuppressorCan", (1.236, 0, 0.353), (1, 0, 0), [
    (0.000, 0.058), (0.014, 0.084), (0.150, 0.084), (0.158, 0.078), (0.186, 0.078), (0.200, 0.096),
    (0.598, 0.096), (0.606, 0.090), (0.646, 0.090), (0.668, 0.068), (0.668, 0.030), (0.635, 0.030),
], METAL)
prism_along("AR_BrakeLight", (1.391, 0, 0.353), (1, 0, 0), [(0, 0.0825), (0.034, 0.0825)], CYAN)["flat_group"] = "ARBrakeLight"

# ---------------------------------------------------------------- mag stripe
# Along the raked front band of the magazine, between the recessed panel and the front edge.
for sign, label in ((1, "Left"), (-1, "Right")):
    side(f"AR_MagStripe_{label}", [(0.666, -0.070), (0.684, -0.070), (0.774, -0.350), (0.756, -0.350)],
         0.053 * sign, 0.060 * sign, MAGENTA, bone="Mag")

result = finish_master(deck)
result["gap_moves"] = gap_moves
