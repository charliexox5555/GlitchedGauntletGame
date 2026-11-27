"""Arcade Lancer (Bulldog): the bullpup's stock body is the cabinet. A control deck with joystick, buttons
and pixel screen sits in the stock's left recess, a side-art field below it and in the right recess, a coin
door on the right stock, a side-art handguard with lit edge trim and a raked cabinet nose, a cabinet butt
with marquee and speaker grille, and a stepped eight-sided brake with a light ring.

Run in the live Blender MCP session with the stock
art-source/weapons/RemasterV2/Bulldog/Bulldog_RemasterV2_v05.blend open:
    exec(open("tools/blender/arcade/14_bulldog.py").read(), {"VERSION": "v01"})
Left (+y) is the player-facing side. Stock sights, rig, locators and CharmLoop are kept.
Stock measurements (2026-11-27, ray-cast depth maps and swept clips, Root-relative):
  stock body (one closed island) x -1.227/-.473, side face y .088, top .476 at the front falling to .43
  at the rear, bottom -.134; a side recess (floor .083, both sides) x -1.05/-.524, z .28-.41 with a
  raked front edge; a sling slot through the body at x -1.21/-1.185, z -.03/.10; magwell (open
  island) x -.799/-.437, z .06-.115; butt pad x -1.459/-1.219, z -.078/.445, y .092; pins at
  (-.92, .18) and (-.60, .43) on both sides; receiver upper face y .084 (z .291-.445, top .476),
  lower face .080, a violet panel with two Neon bars at x -.159/.044, z .14-.252 both sides; side box
  x .343-.611 (y .092, z .177-.38) with the CharmLoop on its lower left (x .536-.568, z .181-.222);
  charging handle (left) knob x .415-.501, z .372-.435, runs back to x .20 (Draw); bolt (right,
  inside) x -.568/-.338; ejection cover x -.36/-.325; handguard x .575-1.074, y .086, bottom .156,
  keel .186, top .291 (the receiver's underside), recessed panel (floor .082) x .64-1.02, z .194-.27;
  barrel r .034 x 1.03-1.255, round ported brake r .048 x 1.25-1.438, Muzzle x 1.4378, z .3614;
  magazine face y .056 with grooves (.052) at x -.730/-.714, -.670/-.654, -.610/-.594,
  -.550/-.534, -.490/-.474 (z -.2 to 0); the mag rises at most .009 in Reload/Inspect and drops out
  below. ADS: adsDistance .38, adsFov 68 (Config/Weapons), eye x -.6726, z .5838: the deck is behind
  or beside the eye, under the stock top. Cam_Hip (80 deg) sees the stock body ahead of x -.80.
"""

from pathlib import Path

import bpy

GUN = "Bulldog"
VERSION = globals().get("VERSION", "v01")
exec((Path(bpy.data.filepath).parents[4] / "tools/blender/arcade/arcade_lib.py").read_text(encoding="utf-8"))

replace("Handguard", "Barrel")

# ---------------------------------------------------------------- retained stock
for name in ("Receiver", "Neon", "CharmLoop", "ChargingHandle", "Bolt",
             "FireSelector", "Trigger", "Grip", "Sights"):
    dress(name)
dress("Mag", slots={"Dark": GRIP})
# The two lower-rear stock pins sit under the left side-art field and the coin door; the two handguard
# pins belonged to the replaced handguard (they would float over the new side-art field).
dress("Pins", keep=lambda island: not ((limits(island, 0)[0] < -0.9 and limits(island, 2)[1] < 0.2)
                                       or 0.68 < limits(island, 0)[0] < 0.72))
# Stock body and magwell without the butt pad (the cabinet butt replaces it). The body keeps its
# stock name: the magazine and bolt run inside it exactly as in the stock gun.
body = dress("Stock", keep=lambda island: limits(island, 0)[0] > -1.23)
# The stock's one flush pair (a Bolt face on the Receiver at rest): lift it 0.004 in the build,
# the same lift the flat export would make.
_flat = {}
exec((ROOT / "tools/blender/export_roblox_flat.py").read_text(encoding="utf-8"), _flat)
_flat["resolve_coplanar"]([native("Bolt"), native("Receiver")])
# Barrel: keep the tube; the stepped brake replaces the round ported brake.
tube = dress("Barrel", copy_name="AR_BarrelTube", keep=lambda island: limits(island, 0)[1] < 1.26)


def nudge(obj, pick, delta):
    """Move the vertices of a retained part that pick(world point) selects (rest pose, world space)."""
    matrix = obj.matrix_world
    inverse = matrix.inverted()
    moved = 0
    for vertex in obj.data.vertices:
        point = matrix @ vertex.co
        if pick(point):
            vertex.co = inverse @ (point + Vector(delta))
            moved += 1
    obj.data.update()
    return moved


# Stock join fixes (owner, 2026-11-27: "a gap in the trigger area that meets the body at the front"):
# - the trigger guard's front post stopped at z .164, 0.013 under the side box (bottom .177): its top
#   now runs 0.024 up into the box;
# - the front sight base floated 0.011 over the rail and 0.027 over the receiver top (.476) beyond the
#   rail's end: its foot now runs straight down to z .456 (0.02 into the receiver; the part above the
#   rail teeth, which is all the ADS eye sees, is unchanged);
# - the barrel tube ran only 0.015 into the receiver's front face (x 1.045): its rear now starts at 1.010.
post_moves = nudge(native("Grip"), lambda p: p.x > 0.47 and p.z > 0.155 and abs(p.y) < 0.031, (0, 0, 0.037))
sight_moves = nudge(native("Sights"), lambda p: 0.82 < p.x < 0.93 and p.z < 0.506, (0, 0, -0.047))
tube_moves = nudge(tube, lambda p: p.x < 1.031, (-0.020, 0, 0))


def crect(x0, z0, x1, z1, c):
    return [(x0 + c, z0), (x1 - c, z0), (x1, z0 + c), (x1, z1 - c),
            (x1 - c, z1), (x0 + c, z1), (x0, z1 - c), (x0, z0 + c)]


def square(x, z, size):
    return [(x - size / 2, z - size / 2), (x + size / 2, z - size / 2),
            (x + size / 2, z + size / 2), (x - size / 2, z + size / 2)]


def slot(x0, x1, zc, h):
    """A faceted slot: pointed (45 degree) ends instead of round ones."""
    return [(x0, zc), (x0 + h / 2, zc - h / 2), (x1 - h / 2, zc - h / 2), (x1, zc),
            (x1 - h / 2, zc + h / 2), (x0 + h / 2, zc + h / 2)]


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


def art(label, sign, near, band, line, star_at, star_r, trail):
    """Line-language side art standing 0.004 proud of its field floor: band, line, starburst, pixel trail."""
    far = near + 0.007
    side(f"AR_{label}Stripe", band, near * sign, far * sign, MAGENTA)
    side(f"AR_{label}Line", line, near * sign, far * sign, CYAN)
    plate(f"AR_{label}Star", star(*star_at, star_r, star_r * 0.42), near * sign, far * sign, YELLOW)
    for k, (x, z, size) in enumerate(trail):
        side(f"AR_{label}Pixel_{k + 1}", square(x, z, size), near * sign, far * sign, MAGENTA)


# ---------------------------------------------------------------- left: cabinet deck
# A raised plate in the stock's left recess (floor .083), 0.008 inside its walls so a dark reveal
# runs round it: back at y .078 (buried), face .100 (0.012 proud of the body face .088).
# Rear to front: joystick, three buttons rising toward the muzzle, the pixel screen at the front where
# the held camera sees it, and a cyan light pipe along the top edge over the screen.
DECK = [(-1.034, 0.288), (-0.540, 0.288), (-0.533, 0.297), (-0.563, 0.392), (-0.578, 0.402),
        (-1.034, 0.402), (-1.042, 0.394), (-1.042, 0.296)]
deck = slab("AR_ControlDeck_Left", DECK, 0.078, 0.100, PANEL, 0.0018)

prism_along("AR_JoystickWasher", (-1.004, 0.096, 0.344), (0, 1, 0), [(0, 0.022), (0.009, 0.0185)], DARK)
prism_along("AR_JoystickShaft", (-1.004, 0.102, 0.344), (0, 1, 0), [(0, 0.0065), (0.034, 0.0065)], METAL)
stick_ball = prism_along("AR_JoystickBall", (-1.004, 0.102, 0.344), (0, 1, 0), [
    (0.028, 0.009), (0.035, 0.019), (0.047, 0.019), (0.054, 0.009),
], BTN_MAGENTA)
stick_ball["flat_group"] = "ARStickBall"
for i, (x, z, role) in enumerate(((-0.933, 0.332, BTN_CYAN), (-0.873, 0.341, BTN_YELLOW),
                                  (-0.813, 0.350, BTN_MAGENTA))):
    prism_along(f"AR_ButtonCollar_{i + 1}", (x, 0.096, z), (0, 1, 0),
                [(0, 0.028), (0.010, 0.0245)], DARK)
    button = prism_along(f"AR_Button_{i + 1}", (x, 0.102, z), (0, 1, 0),
                         [(0, 0.022), (0.016, 0.022), (0.021, 0.0155)], role)
    button["flat_group"] = f"ARButton{i + 1}"

# Pixel screen: bezel ring, glowing screen floor, pixel graphic standing 0.004 proud.
inner = crect(-0.764, 0.312, -0.596, 0.372, 0.008)
outer = crect(-0.776, 0.300, -0.584, 0.384, 0.014)
loft("AR_ScreenBezel_Left", [
    [(x, 0.096, z) for x, z in outer], [(x, 0.110, z) for x, z in outer],
    [(x, 0.110, z) for x, z in inner], [(x, 0.096, z) for x, z in inner],
], DARK, loop=True)
plate("AR_Screen_Left", crect(-0.766, 0.310, -0.594, 0.374, 0.008), 0.097, 0.103, SCREEN)["flat_group"] = "ARScreen"
PX = 0.0085
SX, SZ = -0.754, 0.320
SHIP = {(0, 4), (1, 4), (0, 3), (1, 3), (2, 3), (3, 3), (1, 2), (2, 2), (3, 2), (4, 2), (5, 2), (6, 2),
        (0, 1), (1, 1), (2, 1), (3, 1), (0, 0), (1, 0)}
pixel_solid("AR_ScreenShip_Left", SHIP, SX, SZ, PX, 0.102, 0.107, CYAN)["flat_group"] = "ARScreenShip"
pixel_solid("AR_ScreenShot_Left", {(0, 0), (1, 0), (2, 0)}, SX + 8 * PX, SZ + 2 * PX, PX,
            0.102, 0.107, MAGENTA)["flat_group"] = "ARScreenShot"
PLUS = {(1, 0), (0, 1), (1, 1), (2, 1), (1, 2)}
pixel_solid("AR_ScreenStarA_Left", PLUS, -0.642, SZ + 1 * PX, PX, 0.102, 0.107, YELLOW)["flat_group"] = "ARScreenStars"
pixel_solid("AR_ScreenStarB_Left", {(0, 0)}, -0.612, SZ + 0 * PX, PX, 0.102, 0.107, YELLOW)["flat_group"] = "ARScreenStars"
pixel_solid("AR_ScreenStarC_Left", {(0, 0)}, -0.662, SZ + 4 * PX, PX, 0.102, 0.107, CYAN)["flat_group"] = "ARScreenBlip"

# Cyan light pipe along the deck's top edge over the screen: back buried 0.003 in the deck face,
# front 0.004 proud, angled ends.
side("AR_DeckLight_Left", [(-0.770, 0.389), (-0.576, 0.389), (-0.582, 0.396), (-0.764, 0.396)],
     0.097, 0.104, CYAN)["flat_group"] = "ARDeckLight"

# ---------------------------------------------------------------- stock side art
# Right: a violet field cut 0.003 below the stock recess floor (-.083), 0.010 inside its walls, so the
# dark recess shows as a reveal round it. Left: a field cut into the plain lower body (face .088,
# floor .082) behind the magwell. Both have a pixel-stepped rear-bottom corner.
FIELD_R = [(-1.040, 0.326), (-1.024, 0.326), (-1.024, 0.310), (-1.008, 0.310), (-1.008, 0.294),
           (-0.545, 0.294), (-0.538, 0.302), (-0.564, 0.388), (-0.580, 0.400), (-1.024, 0.400),
           (-1.040, 0.384)]
recess(body, "AR_StockField_Right", FIELD_R, -0.080, -0.15, role=PANEL)
art("StockR", -1, 0.077,
    [(-0.860, 0.298), (-0.822, 0.298), (-0.766, 0.396), (-0.804, 0.396)],
    [(-0.808, 0.298), (-0.796, 0.298), (-0.740, 0.396), (-0.752, 0.396)],
    (-0.640, 0.347), 0.034,
    [(-0.846, 0.347, 0.010), (-0.869, 0.347, 0.015), (-0.898, 0.347, 0.020)])
FIELD_L = [(-1.150, -0.040), (-1.134, -0.040), (-1.134, -0.058), (-1.118, -0.058), (-1.118, -0.076),
           (-0.846, -0.076), (-0.826, -0.056), (-0.826, 0.226), (-0.846, 0.246), (-1.130, 0.246),
           (-1.150, 0.226)]
recess(body, "AR_StockField_Left", FIELD_L, 0.082, 0.15, role=PANEL)
art("StockL", 1, 0.079,
    [(-1.090, -0.068), (-1.040, -0.068), (-0.880, 0.238), (-0.930, 0.238)],
    [(-1.024, -0.068), (-1.010, -0.068), (-0.850, 0.238), (-0.864, 0.238)],
    (-0.890, 0.020), 0.040,
    [(-1.006, 0.120, 0.012), (-1.030, 0.120, 0.018), (-1.060, 0.120, 0.024)])

# ---------------------------------------------------------------- right: coin door
# On the lower stock body (-.088) behind the magwell, under the side-art field.
coin = slab("AR_CoinDoor_Right", crect(-1.150, -0.020, -0.830, 0.165, 0.014), -0.080, -0.100, METAL, 0.0018)
for i, x in enumerate((-1.085, -0.975)):
    block = slab(f"AR_CoinEntry_{i + 1}", crect(x - 0.030, 0.040, x + 0.030, 0.108, 0.006),
                 -0.096, -0.112, ACCENT, 0.0015)
    recess(block, f"AR_CoinSlotCut_{i + 1}", crect(x - 0.004, 0.054, x + 0.004, 0.094, 0.002),
           -0.106, -0.132, role=DARK)
    side(f"AR_CoinSlotLight_{i + 1}", crect(x - 0.0055, 0.053, x + 0.0055, 0.095, 0.002),
         -0.102, -0.110, YELLOW)
side("AR_CoinStripe_Right", [(-0.930, -0.004), (-0.900, -0.004), (-0.852, 0.147), (-0.882, 0.147)],
     -0.097, -0.104, MAGENTA)

# ---------------------------------------------------------------- handguard
# Stock envelope (y .086, keel .186, bottom .156) from x .575, as stock; the top tucks in (shoulder
# .286, crown .066 at .306) so it runs 0.015 up into the receiver's underside (.291, face .084); the
# nose rakes up under the barrel like a cabinet front. The rear end is buried in the side box.
hand = folded("AR_Handguard", (
    (0.575, 0.156, 0.306, 0.086, 0.286, 0.186, 0.066),
    (1.020, 0.156, 0.306, 0.086, 0.286, 0.186, 0.066),
    (1.074, 0.206, 0.302, 0.080, 0.282, 0.228, 0.060),
), BODY, bevel=0.004)
HFIELD = [(0.650, 0.216), (0.661, 0.216), (0.661, 0.206), (0.672, 0.206), (0.672, 0.196), (0.992, 0.196),
          (1.010, 0.214), (1.010, 0.256), (0.992, 0.274), (0.668, 0.274), (0.650, 0.256)]
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(hand, f"AR_HandguardField_{label}", HFIELD, 0.081 * sign, 0.15 * sign, role=PANEL)
    art(f"Handguard{label}", sign, 0.078,
        [(0.820, 0.200), (0.848, 0.200), (0.884, 0.270), (0.856, 0.270)],
        [(0.857, 0.200), (0.866, 0.200), (0.902, 0.270), (0.893, 0.270)],
        (0.955, 0.235), 0.026,
        [(0.824, 0.235, 0.008), (0.806, 0.235, 0.012), (0.783, 0.235, 0.016)])
    # Cabinet T-molding: a lit bar seated along the lower chamfer, ahead of the charm loop.
    trim = prism_along(f"AR_HandguardTrim_{label}", (0.630, 0.0718 * sign, 0.171), (1, 0, 0),
                       [(0, 0.003), (0.008, 0.0068), (0.382, 0.0068), (0.390, 0.003)], MAGENTA)
    trim["flat_group"] = "ARTrim"

# ---------------------------------------------------------------- cabinet butt
# Front swallows the body's rear end and its sling slot (x > -1.21) by 0.03+; 0.008 proud of the body
# sides; raked marquee top; stepped rear; bottom on the body's bottom line. Its front foot rakes forward
# under the body's chamfered lower-rear corner (x -1.142/-1.21) so no notch is left between them. A flat 0.006 chamfer runs
# round both side faces (cheaper than a bevel modifier on every edge).
BUTT = [(-1.178, 0.452), (-1.400, 0.486), (-1.432, 0.468), (-1.440, 0.420), (-1.420, 0.404),
        (-1.414, 0.214), (-1.440, 0.196), (-1.440, 0.150), (-1.420, 0.132), (-1.420, -0.088),
        (-1.392, -0.140), (-1.116, -0.140), (-1.178, -0.068)]
BUTT_IN = inset(BUTT, 0.006)
butt = loft("AR_CabinetButt", [[(x, y, z) for x, z in ring] for y, ring in (
    (-0.096, BUTT_IN), (-0.090, BUTT), (0.090, BUTT), (0.096, BUTT_IN))], BODY)
MARQUEE = [(-1.236, 0.412), (-1.394, 0.412), (-1.406, 0.424), (-1.406, 0.462), (-1.394, 0.474), (-1.236, 0.450)]
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(butt, f"AR_MarqueeSeat_{label}", MARQUEE, 0.086 * sign, 0.12 * sign, role=DARK)
    # The light is 0.0025 bigger than its seat (edges buried) and its top rakes a little flatter.
    side(f"AR_Marquee_{label}", [(-1.2335, 0.4095), (-1.3965, 0.4095), (-1.4085, 0.4215), (-1.4085, 0.4635),
                                (-1.3955, 0.4760), (-1.2335, 0.4520)], 0.082 * sign, 0.0905 * sign, CYAN)

# ---------------------------------------------------------------- stepped brake
# Rear collar over the barrel tube's end (0.021 overlap), a stepped light-ring groove with the cyan ring
# (ends buried in the groove walls), a ported main section, a stepped nose and a bore; the Muzzle
# locator (x 1.4378) sits in the bore mouth.
brake = prism_along("AR_Brake", (1.234, 0, 0.3614), (1, 0, 0), [
    (0.000, 0.040), (0.010, 0.050), (0.046, 0.050), (0.046, 0.043), (0.078, 0.043), (0.078, 0.054),
    (0.176, 0.054), (0.192, 0.046), (0.206, 0.040), (0.206, 0.020), (0.178, 0.020),
], METAL)
for k, x in enumerate((1.326, 1.366)):
    recess(brake, f"AR_BrakePort_{k + 1}", crect(x, 0.346, x + 0.026, 0.377, 0.005), -0.2, 0.2, role=DARK)
prism_along("AR_BrakeLight", (1.2775, 0, 0.3614), (1, 0, 0), [(0, 0.0475), (0.036, 0.0475)], CYAN)["flat_group"] = "ARBrakeLight"

# ---------------------------------------------------------------- mag stripe
# Raked across the magazine's ribbed face (back buried in the rib floor .052), clear of the magwell.
for sign, label in ((1, "Left"), (-1, "Right")):
    side(f"AR_MagStripe_{label}", [(-0.700, -0.190), (-0.676, -0.190), (-0.592, -0.012), (-0.616, -0.012)],
         0.0515 * sign, 0.060 * sign, MAGENTA, bone="Mag")

result = finish_master(deck)
result["stock_join_moves"] = {"guard_post": post_moves, "front_sight_foot": sight_moves, "barrel_tube": tube_moves}
