"""Arcade Scout (Marshal): a cabinet control deck over the left receiver panel (joystick, three buttons,
pixel screen, light pipe), a coin door on the right receiver above the loading gate, side-art fields cut
into both sides of the fore-end with lit edge trim, stock-body art, a cabinet butt with marquee and side
art, and a stepped eight-sided muzzle sleeve with a light ring.

Run in a live Blender session with the stock
art-source/weapons/RemasterV2/Marshal/Marshal_RemasterV2_v05.blend open:
    exec(open("tools/blender/arcade/17_marshal.py").read(), {"VERSION": "v01"})
Left (+y) is the player-facing side (Cam_Hip at y +.69). Stock scope, ScopeLens, rig, locators and CharmLoop
are kept. Stock measurements (2026-11-27, ray-cast depth maps, vertex lists and Root-relative clip sweeps):
  receiver x .099-.888, z -.049-.228, side face y .066 (top chamfer from z .212); a side panel recess
  (floor .061) x ~.17-.81, z .01-.188 on both sides with a stock Neon bar (x .30-.37, z .059-.086);
  right loading gate frame x .31-.46, z .003-.068; pins at (.495, -.026) and (.825, .165) both sides;
  fore-end x .888-1.904, flat face y .068 z .02-.177, bottom -.013, 45 degree lower chamfer (z = y - .051),
  a stock recess (floor .064) x 1.0-1.66, z .036-.159 and a Neon pocket x 1.675-1.82, z .063-.11;
  barrel r .044 on z .205 to x 3.1977 (bore r .024 back to 3.138), crown ring x 3.158-3.170 r .048,
  front sight x 3.003-3.119 (ramp tail r .042 at 3.119); Muzzle x 3.1977;
  stock body x -1.214-.172, top z .07 (rises from x -.30 to .214 at the wrist), bottom -.30, rear face
  y .066 (x < -1.10), a .062 band (x -1.10/-.32), butt plate x -1.246/-1.204;
  CharmLoop x .804-.836, z -.064/-.022, y .062-.072 (receiver lower front, left), CharmPoint z -.060.
  Moving parts relative to Root over every clip: Lever y +-.02, z <= -.003 (inside the receiver width);
  Bolt y +-.04, z .2-.236; Hammer y +-.014; Trigger y +-.011; Shell leaves through the right loading gate:
  x .218-.692, z -.198-.064, y down to -.339. No magazine (tube fed): no mag stripe.
  ADS: no adsDistance in Config/Weapons (scoped), so Viewmodel ADS_DISTANCE .70: eye x -.687, z .3333.
"""

from pathlib import Path

import bpy

GUN = "Marshal"
VERSION = globals().get("VERSION", "v01")
exec((Path(bpy.data.filepath).parents[4] / "tools/blender/arcade/arcade_lib.py").read_text(encoding="utf-8"))

replace("ForeEnd")

# ---------------------------------------------------------------- retained stock
for name in ("Receiver", "CharmLoop", "Bolt", "Hammer", "Lever", "Trigger", "Shell", "Scope"):
    dress(name)
# Barrel: the crown ring (x 3.158-3.170, r .048) is buried in the muzzle sleeve; it goes so the light ring
# shares no plane with it (v03).
dress("Barrel", keep=lambda island: not (limits(island, 0)[0] > 3.15 and limits(island, 0)[1] < 3.18))
# The left rear-top pin sits under the deck.
dress("Pins", keep=lambda island: not (limits(island, 1)[0] > 0 and limits(island, 2)[0] > 0.1
                                       and 0.8 < limits(island, 0)[0] < 0.85))
# Only the right receiver Neon bar stays (cyan, under the coin door, in its stock groove); the left one is
# under the deck and the fore-end ones went with the stock fore-end. Kept in place (stock object): the shell
# passes it in the reload clips exactly as in the stock gun.
dress("Neon", keep=lambda island: limits(island, 1)[1] < 0 and limits(island, 0)[1] < 0.5)
# Stock body without the butt plate (the cabinet butt replaces it). Kept in place (stock object): the lever,
# bolt and hammer pass through its wrist in the clips exactly as in the stock gun.
# v04: the stock is cabinet purple like the line's other stocks (its Dark faces take AR Body) and its
# recessed polymer panels (Grip) are AR Panel violet fields.
dress("Stock", slots={"Dark": BODY, "Grip": PANEL}, keep=lambda island: limits(island, 0)[1] > 0)
gap_moves = {}


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


def sleeve(name, origin, profile, role, *, bone="Root"):
    """A closed eight-sided ring along +x with a through bore: profile = [(t, radius), ...] walked
    round the cross-section (outer surface forward, then back along the bore)."""
    ox, oy, oz = origin
    sections = [[(ox + t, oy + u, oz + v) for u, v in polygon(0, 0, r, 8)] for t, r in profile]
    return loft(name, sections, role, bone=bone, loop=True)


# ---------------------------------------------------------------- left: cabinet deck
# v04 (orchestrator: nothing new in the ADS picture; the Havoc's joystick was moved for the same reason).
# Ray-cast bounds from the 0.70 eye (x -.687, z .3333) give the most a part may stand off the receiver
# side and stay hidden behind the receiver: about .069 at x .15, .076 at x .22, .083 at x .30, .092 at x .42,
# .100 at x .50 and .110 at x .66 (z .06-.14); above z .16 only .072-.094. So the deck is a raised panel
# 0.010 proud (face .076) whose rear rakes down into the receiver (.0675 at x .150 to .076 at x .270) and
# whose top slopes back like a cabinet control panel (.076 at z .150 to .068 at z .192, over the recess
# top .188). It still covers the whole left recess (x ~.17-.81, z .01-.188) and the stock left Neon bar and
# rear-top pin; back y .057 is buried in the recess floor (.061) and the face (.066). The controls sit
# where the receiver hides them, in the same order (rear to front): joystick, three buttons rising toward
# the muzzle, screen. The raked rear carries a band and line in the line's side-art language.


def deck_section(x, bottom, knee, top, face):
    rim = min(0.068, face - 0.001)
    return [(x, 0.057, bottom), (x, face - 0.0018, bottom), (x, face, bottom + 0.0018), (x, face, knee),
            (x, rim, top), (x, 0.057, top)]


deck = loft("AR_ControlDeck_Left", [
    deck_section(0.150, 0.014, 0.140, 0.178, 0.0675),
    deck_section(0.168, -0.004, 0.150, 0.192, 0.0688),
    deck_section(0.270, -0.004, 0.150, 0.192, 0.076),
    deck_section(0.813, -0.004, 0.150, 0.192, 0.076),
    deck_section(0.835, -0.004, 0.130, 0.170, 0.076),
], PANEL)

# Joystick (washer, shaft, faceted magenta ball, tip y .097 under the .100 bound), then three faceted
# buttons in collars rising toward the muzzle (tips .092), then the pixel screen.
prism_along("AR_JoystickWasher", (0.500, 0.072, 0.070), (0, 1, 0), [(0, 0.017), (0.008, 0.014)], DARK)
prism_along("AR_JoystickShaft", (0.500, 0.078, 0.070), (0, 1, 0), [(0, 0.0055), (0.008, 0.0055)], METAL)
stick_ball = prism_along("AR_JoystickBall", (0.500, 0.081, 0.070), (0, 1, 0), [
    (0.000, 0.007), (0.004, 0.012), (0.012, 0.012), (0.016, 0.007),
], BTN_MAGENTA)
stick_ball["flat_group"] = "ARStickBall"
for i, (x, z, role) in enumerate(((0.560, 0.062, BTN_CYAN), (0.612, 0.074, BTN_YELLOW),
                                  (0.664, 0.086, BTN_MAGENTA))):
    prism_along(f"AR_ButtonCollar_{i + 1}", (x, 0.072, z), (0, 1, 0),
                [(0, 0.022), (0.008, 0.019)], DARK)
    button = prism_along(f"AR_Button_{i + 1}", (x, 0.078, z), (0, 1, 0),
                         [(0, 0.017), (0.010, 0.017), (0.014, 0.012)], role)
    button["flat_group"] = f"ARButton{i + 1}"

# Pixel screen: bezel ring, glowing screen floor, pixel graphic standing 0.004 proud.
inner = crect(0.710, 0.040, 0.808, 0.124, 0.006)
outer = crect(0.698, 0.028, 0.820, 0.136, 0.010)
loft("AR_ScreenBezel_Left", [
    [(x, 0.072, z) for x, z in outer], [(x, 0.086, z) for x, z in outer],
    [(x, 0.086, z) for x, z in inner], [(x, 0.072, z) for x, z in inner],
], DARK, loop=True)
plate("AR_Screen_Left", crect(0.708, 0.038, 0.810, 0.126, 0.006), 0.073, 0.079, SCREEN)["flat_group"] = "ARScreen"
PX = 0.0075
SX, SZ = 0.714, 0.050
SHIP = {(0, 4), (1, 4), (0, 3), (1, 3), (2, 3), (3, 3), (1, 2), (2, 2), (3, 2), (4, 2), (5, 2), (6, 2),
        (0, 1), (1, 1), (2, 1), (3, 1), (0, 0), (1, 0)}
pixel_solid("AR_ScreenShip_Left", SHIP, SX, SZ, PX, 0.078, 0.083, CYAN)["flat_group"] = "ARScreenShip"
pixel_solid("AR_ScreenShot_Left", {(0, 0), (1, 0), (2, 0)}, SX + 8 * PX, SZ + 2 * PX, PX,
            0.078, 0.083, MAGENTA)["flat_group"] = "ARScreenShot"
PLUS = {(1, 0), (0, 1), (1, 1), (2, 1), (1, 2)}
pixel_solid("AR_ScreenStarA_Left", PLUS, 0.776, 0.095, PX, 0.078, 0.083, YELLOW)["flat_group"] = "ARScreenStars"
pixel_solid("AR_ScreenStarB_Left", {(0, 0)}, 0.794, 0.052, PX, 0.078, 0.083, YELLOW)["flat_group"] = "ARScreenStars"
pixel_solid("AR_ScreenStarC_Left", {(0, 0)}, 0.745, 0.110, PX, 0.078, 0.083, CYAN)["flat_group"] = "ARScreenBlip"

# Cyan light pipe lying along the deck's top slope (z .160-.182), 0.003 buried and 0.003 proud of it.


def on_slope(z, lift):
    return (0.076 - (z - 0.150) * (0.008 / 0.042) + lift * 0.982, z + lift * 0.189)


LIGHT_SECTION = [on_slope(0.160, -0.003), on_slope(0.160, 0.003), on_slope(0.182, 0.003), on_slope(0.182, -0.003)]
# Raked ends (the top runs 0.006 shorter than the bottom at each end).
loft("AR_DeckLight_Left", [[(x + rake * (z - 0.157), y, z) for y, z in LIGHT_SECTION]
                           for x, rake in ((0.300, 0.24), (0.800, -0.24))], CYAN)["flat_group"] = "ARDeckLight"

# Raked rear: band and line (lift 0.004 over the .076 face) and a pixel trail toward the joystick.
side("AR_DeckStripe_Left", [(0.300, 0.016), (0.326, 0.016), (0.372, 0.140), (0.346, 0.140)], 0.073, 0.080, MAGENTA)
side("AR_DeckLine_Left", [(0.336, 0.016), (0.346, 0.016), (0.392, 0.140), (0.382, 0.140)], 0.073, 0.080, CYAN)
for k, (x, size) in enumerate(((0.412, 0.008), (0.432, 0.012), (0.458, 0.016))):
    side(f"AR_DeckPixel_{k + 1}", square(x, 0.078, size), 0.073, 0.080, MAGENTA)

# ---------------------------------------------------------------- right: coin door
# v04: forward and lower so the ADS eye can't see it past the receiver (bounds as on the left): x .30-.64,
# z .092-.164, face -.076. Still above the loading gate (frame top .068), the shell's whole reload path
# (z <= .064) and the stock Neon bar (top .086). Back -.057 buried in the recess floor (-.061).
coin = slab("AR_CoinDoor_Right", crect(0.300, 0.092, 0.640, 0.164, 0.010), -0.057, -0.076, METAL, 0.0018)
for i, x in enumerate((0.440, 0.540)):
    block = slab(f"AR_CoinEntry_{i + 1}", crect(x - 0.028, 0.104, x + 0.028, 0.152, 0.006),
                 -0.072, -0.084, ACCENT, 0.0015)
    recess(block, f"AR_CoinSlotCut_{i + 1}", crect(x - 0.004, 0.114, x + 0.004, 0.142, 0.002),
           -0.080, -0.110, role=DARK)
    side(f"AR_CoinSlotLight_{i + 1}", crect(x - 0.0055, 0.113, x + 0.0055, 0.143, 0.002),
         -0.077, -0.082, YELLOW)
side("AR_CoinStripe_Right", [(0.576, 0.100), (0.606, 0.100), (0.626, 0.156), (0.596, 0.156)],
     -0.073, -0.080, MAGENTA)

# ---------------------------------------------------------------- fore-end
# The stock fore-end's recess (floor .064) covers nearly its whole flat side (z .02-.175), so it is rebuilt
# as one closed volume on the stock envelope: flat side y .068 from the lower chamfer (.017) to the top
# chamfer (.184), 45 degree chamfers to the bottom (-.013, y .038) and the top (.207, y .045, under the
# barrel). The rear runs 0.022 into the receiver (front .888; stock was a flush butt joint). The front rakes
# up under the magazine tube like a cabinet front and narrows to y .052 so it enters the barrel band
# (rear 1.904, y +-.06) inside the band's sides; it ends 0.022 into the band.


def fore_section(x, bottom, keel, shoulder, top, width, base, crown):
    return [(x, y, z) for y, z in (
        (-crown, top), (crown, top), (width, shoulder), (width, keel),
        (base, bottom), (-base, bottom), (-width, keel), (-width, shoulder),
    )]


fore = loft("AR_ForeEnd", [
    fore_section(0.866, -0.013, 0.017, 0.184, 0.207, 0.068, 0.038, 0.045),
    fore_section(1.880, -0.013, 0.017, 0.184, 0.207, 0.068, 0.038, 0.045),
    fore_section(1.926, 0.060, 0.084, 0.176, 0.199, 0.052, 0.030, 0.035),
], BODY, bevel=0.003)
# A pixel-cornered violet field cut 0.008 into each flat side (floor .060) with 0.013 lips to the
# chamfers. The art sits on the floor with 0.004 lift; the band and line run into the field walls (ends
# buried). A magenta T-molding bar sits on each lower 45 degree chamfer.
FIELD = [(0.960, 0.064), (0.974, 0.064), (0.974, 0.048), (0.988, 0.048), (0.988, 0.030),
         (1.812, 0.030), (1.840, 0.058), (1.840, 0.140), (1.812, 0.168), (0.980, 0.168), (0.960, 0.148)]
MAG_STRIPE = [(1.560, 0.024), (1.600, 0.024), (1.666, 0.174), (1.626, 0.174)]
CYAN_STRIPE = [(1.614, 0.024), (1.626, 0.024), (1.692, 0.174), (1.680, 0.174)]
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(fore, f"AR_ForeEndField_{label}", FIELD, 0.060 * sign, 0.15 * sign, role=PANEL)
    side(f"AR_ForeEndStripe_{label}", MAG_STRIPE, 0.057 * sign, 0.064 * sign, MAGENTA)
    side(f"AR_ForeEndLine_{label}", CYAN_STRIPE, 0.057 * sign, 0.064 * sign, CYAN)
    plate(f"AR_ForeEndStar_{label}", star(1.766, 0.099, 0.030, 0.013), 0.057 * sign, 0.064 * sign, YELLOW)
    for k, (x, size) in enumerate(((1.536, 0.008), (1.512, 0.012), (1.482, 0.016))):
        side(f"AR_ForeEndPixel_{label}_{k + 1}", square(x, 0.099, size), 0.057 * sign, 0.064 * sign, MAGENTA)
    trim = prism_along(f"AR_ForeEndTrim_{label}", (0.930, 0.0551 * sign, -0.0001), (1, 0, 0),
                       [(0, 0.003), (0.008, 0.0068), (0.922, 0.0068), (0.930, 0.003)], MAGENTA)
    trim["flat_group"] = "ARTrim"

# ---------------------------------------------------------------- stock body art
# Raked band and line on the .062 band ahead of the rear section, a pixel trail growing back from it.
for sign, label in ((1, "Left"), (-1, "Right")):
    side(f"AR_StockStripe_{label}", [(-0.760, -0.090), (-0.732, -0.090), (-0.700, 0.040), (-0.728, 0.040)],
         0.058 * sign, 0.0665 * sign, MAGENTA)
    side(f"AR_StockLine_{label}", [(-0.722, -0.090), (-0.712, -0.090), (-0.680, 0.040), (-0.690, 0.040)],
         0.058 * sign, 0.0665 * sign, CYAN)
    for k, (x, size) in enumerate(((-0.786, 0.009), (-0.810, 0.014), (-0.840, 0.020))):
        side(f"AR_StockPixel_{label}_{k + 1}", square(x, -0.025, size), 0.058 * sign, 0.0665 * sign, MAGENTA)

# ---------------------------------------------------------------- cabinet butt
# Swallows the stock body's rear 0.084 (body ends at -1.214, top .07, bottom -.30, y .066; v03: was 0.049,
# longer for presence); raked marquee top rising to the rear, a stepped rear; 0.010 wider than the body,
# lips 0.016 over the top and 0.018 under.
butt = side("AR_CabinetButt", [
    (-1.130, 0.086), (-1.252, 0.116), (-1.272, 0.104), (-1.276, 0.066), (-1.260, 0.052),
    (-1.260, -0.040), (-1.278, -0.058), (-1.278, -0.292), (-1.258, -0.318), (-1.130, -0.318),
], -0.076, 0.076, BODY, bevel=0.006)
MARQUEE = [(-1.152, 0.040), (-1.236, 0.040), (-1.244, 0.048), (-1.244, 0.088), (-1.236, 0.097), (-1.152, 0.077)]
BUTT_FIELD = [(-1.150, -0.290), (-1.224, -0.290), (-1.224, -0.278), (-1.236, -0.278), (-1.236, -0.266),
              (-1.248, -0.266), (-1.248, 0.010), (-1.238, 0.020), (-1.160, 0.020), (-1.150, 0.010)]
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(butt, f"AR_MarqueeSeat_{label}", MARQUEE, 0.068 * sign, 0.12 * sign, role=DARK)
    # The light is 0.0025 bigger than its seat (edges buried) and its top rakes a little flatter.
    side(f"AR_Marquee_{label}", [(-1.1495, 0.0375), (-1.2385, 0.0375), (-1.2465, 0.0465), (-1.2465, 0.0895),
                                (-1.2370, 0.0995), (-1.1495, 0.0795)], 0.064 * sign, 0.0725 * sign, CYAN)
    recess(butt, f"AR_ButtField_{label}", BUTT_FIELD, 0.068 * sign, 0.12 * sign, role=PANEL)
    side(f"AR_ButtStripe_{label}", [(-1.242, -0.200), (-1.218, -0.200), (-1.196, -0.040), (-1.220, -0.040)],
         0.065 * sign, 0.072 * sign, MAGENTA)
    side(f"AR_ButtLine_{label}", [(-1.212, -0.200), (-1.203, -0.200), (-1.190, -0.105), (-1.199, -0.105)],
         0.065 * sign, 0.072 * sign, CYAN)
    plate(f"AR_ButtStar_{label}", star(-1.212, -0.238, 0.024, 0.010), 0.065 * sign, 0.072 * sign, YELLOW)

# ---------------------------------------------------------------- muzzle sleeve
# A stepped eight-sided sleeve over the barrel's end: rear collar 0.007 over the front sight's ramp tail,
# a light-ring groove with the cyan ring (ends buried in the groove walls), the main band and a stepped
# nose; the bore (r .030) shows the barrel's own bore and face, the Muzzle locator (x 3.1977) sits 0.014
# inside the mouth.
SLEEVE_X = 3.112
sleeve("AR_MuzzleSleeve", (SLEEVE_X, 0, 0.205), [
    (0.000, 0.030), (0.000, 0.046), (0.008, 0.056), (0.028, 0.056), (0.028, 0.049), (0.054, 0.049),
    (0.054, 0.058), (0.088, 0.058), (0.094, 0.052), (0.100, 0.052), (0.100, 0.030),
], METAL)
# v03: the light ring is a hollow ring whose bore (r .036) lies inside the barrel wall (r .024-.044), so it
# no longer shows down the barrel's bore and no face is near a barrel plane; ends 0.006/0.003 into the
# groove walls.
sleeve("AR_BrakeLight", (SLEEVE_X + 0.022, 0, 0.205), [(0.000, 0.036), (0.000, 0.0535), (0.035, 0.0535),
                                                       (0.035, 0.036)], CYAN)["flat_group"] = "ARBrakeLight"

result = finish_master(deck)
result["gap_moves"] = gap_moves
