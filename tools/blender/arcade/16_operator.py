"""Arcade Deadeye (Operator): a tall cabinet deck with joystick, buttons and pixel screen on the left receiver
face under the bolt window, a coin door on the right, a side-art handguard with faceted vents, lit edge trim
and a raked cabinet nose, stock-frame art, a cabinet butt with marquee and side art, and a stepped
eight-sided brake with a light ring.

Run in a live Blender session with the stock
art-source/weapons/RemasterV2/Operator/Operator_RemasterV2_v05.blend open:
    exec(open("tools/blender/arcade/16_operator.py").read(), {"VERSION": "v01"})
Left (+y) is the player-facing side. The scope lens is untouched; the scope body is refinished only (and
its two ring bases are seated in the rail, see the gap sweep). Rig, locators and CharmLoop are kept.
Stock measurements (2026-11-27, ray-cast depth maps, rest pose):
  receiver x .052-1.095, face y +-.090, z .133-.448 (top chamfer .072 at .44); bolt window both sides
  x .09-.75, z .338-.435 (bolt seen at y .023-.048); lower side recess (floor .085) x .11-.71, z .165-.215;
  stock Neon x .167-.319, z .251-.277 in a .085 seat; rail base x .235-1.095 z .446-.47 (y +-.034),
  teeth z .469-.48 (y +-.036); magwell x .429-.835 z .10-.14 (y +-.078); trigger guard x .112-.42,
  z -.018-.133 (y +-.032); bolt handle (right) x .171-.243, y -.107/-.173, z .301-.367 at rest, the bolt
  runs .333 back (Fire, ReloadEmpty); CharmLoop x .929-.961, z .118-.16 on the left face, CharmPoint
  (.945, .092, .122); grip x -.191-.123, top z .137; stock tube x -.333-.060 (y .070, z .15-.312);
  stock frame face y .072 x -1.085/-.333, top bar z .24-.29, cheek riser x -1.005/-.498 z .33-.424 on two
  posts (z .29-.335); butt pad x -1.32/-1.085, y .082, z -.217/.38; handguard x 1.082-2.23, y .088,
  bottom .15 (rear) to .25 (front), top .451; barrel r .061 x 2.2-3.12, collar r .076 x 3.108-3.235,
  brake r .079 x 3.23-3.521, Muzzle x 3.521 z .385; magazine face y .060 with an inset (floor .057)
  x .52-.75, z -.05/.095 and two ridges (.059). Scope x -.077-1.592, bottom .464, ring bases
  x .356-.428 / .829-.90 at z .478. ADS: no adsDistance in Config/Weapons, so Viewmodel ADS_DISTANCE .70;
  AimPoint (-.0875, 0, .602), eye x -.9625. Stock tris 4950.
"""

from pathlib import Path

import bpy

GUN = "Operator"
VERSION = globals().get("VERSION", "v01")
exec((Path(bpy.data.filepath).parents[4] / "tools/blender/arcade/arcade_lib.py").read_text(encoding="utf-8"))

replace("Handguard", "Stock", "Barrel", "Neon")

# ---------------------------------------------------------------- retained stock
for name in ("Receiver", "CharmLoop", "Bolt", "Trigger", "Grip", "Scope"):
    dress(name)
dress("Magazine", slots={"Dark": GRIP})
# Stock frame, tube, cheek riser and posts without the butt pad (the cabinet butt replaces it).
dress("Stock", copy_name="AR_StockFrame", keep=lambda island: limits(island, 0)[0] > -1.09)
# Barrel: keep the tube and the collar; the stepped brake replaces the ported brake.
dress("Barrel", copy_name="AR_BarrelTube", keep=lambda island: limits(island, 0)[1] < 3.24)


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


# Gap sweep (owner 2026-11-27: no gaps anywhere). Measured stock joins; each part now buried 0.02+:
# - grip top (.137) under the stock tube (bottom .150): a 0.013 see-through slot from the side; the grip top
#   rises to .170 (0.020 into the tube, 0.037 into the receiver);
# - trigger guard top (.133) met the receiver bottom (.133) flush: it rises to .155;
# - magwell top (.140) only 0.007 into the receiver: it rises to .156;
# - stock tube: front .060 only 0.008 into the receiver (now .082); rear met the frame flush at -.333 (now -.355);
# - cheek riser posts: 0.005 into the riser and 0.015 into the frame (now .355 / .280);
# - rail base sat 0.002 on the receiver top: its foot drops to .430 (0.018; the bolt's top at .428 runs
#   under it, so this is as deep as it can go); the teeth sat 0.001 on the rail: their feet drop to .450;
# - scope ring bases stood on the teeth and floated 0.008 over the rail between them: their feet drop to
#   .446 (0.024 into the rail, 0.004 under the teeth's feet) and widen 0.002 a side to clear the teeth's
#   side planes; the lens and the scope body above the bases are untouched;
# - barrel tube end 0.012 into the collar: it runs to 3.132 (0.024);
# - the handguard ran only 0.013 into the receiver (see the handguard) and the butt pad is replaced.
RECEIVER = native("Receiver")
FRAME = bpy.data.objects["AR_StockFrame"]
gap_moves = {
    "grip_top": nudge(native("Grip"), lambda p: p.z > 0.13, (0, 0, 0.033)),
    "trigger_guard_top": nudge(RECEIVER, lambda p: p.z > 0.128, (0, 0, 0.022),
                               lambda lo, hi: abs(lo.x - 0.112) < 0.005 and abs(hi.z - 0.133) < 0.003),
    "magwell_top": nudge(RECEIVER, lambda p: p.z > 0.135, (0, 0, 0.016),
                         lambda lo, hi: abs(lo.x - 0.429) < 0.005 and abs(hi.z - 0.14) < 0.003),
    "tube_front": nudge(FRAME, lambda p: p.x > 0.05, (0.022, 0, 0),
                        lambda lo, hi: abs(lo.x + 0.333) < 0.005 and abs(hi.x - 0.06) < 0.005),
    "tube_rear": nudge(FRAME, lambda p: p.x < -0.32, (-0.022, 0, 0),
                       lambda lo, hi: abs(lo.x + 0.333) < 0.005 and abs(hi.x - 0.082) < 0.005),
    "riser_posts_top": nudge(FRAME, lambda p: p.z > 0.33, (0, 0, 0.020),
                             lambda lo, hi: hi.x - lo.x < 0.03 and abs(hi.z - 0.335) < 0.003),
    "riser_posts_foot": nudge(FRAME, lambda p: p.z < 0.295, (0, 0, -0.010),
                              lambda lo, hi: hi.x - lo.x < 0.03 and abs(lo.z - 0.29) < 0.003),
    "rail_foot": nudge(RECEIVER, lambda p: p.z < 0.45, (0, 0, -0.016),
                       lambda lo, hi: abs(lo.x - 0.235) < 0.005 and abs(lo.z - 0.446) < 0.003),
    "rail_teeth_feet": nudge(RECEIVER, lambda p: p.z < 0.4715, (0, 0, -0.019),
                             lambda lo, hi: hi.x - lo.x < 0.035 and abs(lo.z - 0.469) < 0.002),
    "scope_ring_bases": nudge(native("Scope"), lambda p: p.z < 0.48, (0, 0, -0.032),
                              lambda lo, hi: hi.x - lo.x > 0.06 and hi.x - lo.x < 0.08
                              and abs(lo.z - 0.478) < 0.003 and hi.y < 0.04),
    # v03: the bases widen 0.002 a side (y +-.038) so their sides never share the teeth's planes (+-.036).
    "scope_ring_bases_widen": sum(nudge(native("Scope"), lambda p, s=s: p.y * s > 0.03, (0, 0.002 * s, 0),
                                       lambda lo, hi: hi.x - lo.x > 0.06 and hi.x - lo.x < 0.08
                                       and abs(lo.z - 0.446) < 0.003 and hi.y < 0.04) for s in (1, -1)),
    "barrel_end": nudge(bpy.data.objects["AR_BarrelTube"], lambda p: p.x > 3.115, (0.012, 0, 0),
                        lambda lo, hi: lo.x < 2.21),
}


def crect(x0, z0, x1, z1, c):
    return [(x0 + c, z0), (x1 - c, z0), (x1, z0 + c), (x1, z1 - c),
            (x1 - c, z1), (x0 + c, z1), (x0, z1 - c), (x0, z0 + c)]


def square(x, z, size):
    return [(x - size / 2, z - size / 2), (x + size / 2, z - size / 2),
            (x + size / 2, z + size / 2), (x - size / 2, z + size / 2)]


def slot(x0, x1, zc, h):
    """A faceted vent: pointed (45 degree) ends instead of round ones."""
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


# ---------------------------------------------------------------- left: cabinet deck
# A tall control panel on the receiver's left face (.090) under the bolt window (bottom ~.338), over the
# stock lower recess and the removed Neon seat: back y .080 (buried), face .104 (0.014 proud). Raked
# ends; the deck ends at x .76, 0.17 behind the charm loop (x .929) so a hanging charm swings clear.
DECK = [(0.160, 0.165), (0.740, 0.165), (0.760, 0.185), (0.760, 0.300), (0.738, 0.322),
        (0.162, 0.322), (0.140, 0.300), (0.140, 0.185)]
deck = slab("AR_ControlDeck_Left", DECK, 0.080, 0.104, PANEL, 0.0018)

# Joystick at the rear, then three faceted buttons in collars rising toward the muzzle.
prism_along("AR_JoystickWasher", (0.205, 0.100, 0.244), (0, 1, 0), [(0, 0.027), (0.010, 0.0225)], DARK)
prism_along("AR_JoystickShaft", (0.205, 0.106, 0.244), (0, 1, 0), [(0, 0.0075), (0.034, 0.0075)], METAL)
stick_ball = prism_along("AR_JoystickBall", (0.205, 0.106, 0.244), (0, 1, 0), [
    (0.027, 0.010), (0.035, 0.021), (0.049, 0.021), (0.057, 0.010),
], BTN_MAGENTA)
stick_ball["flat_group"] = "ARStickBall"
for i, (x, z, role) in enumerate(((0.285, 0.222, BTN_CYAN), (0.351, 0.242, BTN_YELLOW),
                                  (0.417, 0.262, BTN_MAGENTA))):
    prism_along(f"AR_ButtonCollar_{i + 1}", (x, 0.100, z), (0, 1, 0),
                [(0, 0.031), (0.011, 0.027)], DARK)
    button = prism_along(f"AR_Button_{i + 1}", (x, 0.106, z), (0, 1, 0),
                         [(0, 0.024), (0.018, 0.024), (0.024, 0.017)], role)
    button["flat_group"] = f"ARButton{i + 1}"

# Pixel screen: bezel ring, glowing screen floor, pixel graphic standing 0.004 proud.
inner = crect(0.470, 0.199, 0.726, 0.291, 0.009)
outer = crect(0.456, 0.185, 0.740, 0.305, 0.014)
loft("AR_ScreenBezel_Left", [
    [(x, 0.100, z) for x, z in outer], [(x, 0.115, z) for x, z in outer],
    [(x, 0.115, z) for x, z in inner], [(x, 0.100, z) for x, z in inner],
], DARK, loop=True)
plate("AR_Screen_Left", crect(0.468, 0.197, 0.728, 0.293, 0.009), 0.101, 0.107, SCREEN)["flat_group"] = "ARScreen"
PX = 0.0115
SX, SZ = 0.482, 0.215
SHIP = {(0, 4), (1, 4), (0, 3), (1, 3), (2, 3), (3, 3), (1, 2), (2, 2), (3, 2), (4, 2), (5, 2), (6, 2),
        (0, 1), (1, 1), (2, 1), (3, 1), (0, 0), (1, 0)}
pixel_solid("AR_ScreenShip_Left", SHIP, SX, SZ, PX, 0.106, 0.111, CYAN)["flat_group"] = "ARScreenShip"
pixel_solid("AR_ScreenShot_Left", {(0, 0), (1, 0), (2, 0)}, SX + 8 * PX, SZ + 2 * PX, PX,
            0.106, 0.111, MAGENTA)["flat_group"] = "ARScreenShot"
PLUS = {(1, 0), (0, 1), (1, 1), (2, 1), (1, 2)}
pixel_solid("AR_ScreenStarA_Left", PLUS, 0.652, SZ + 2 * PX, PX, 0.106, 0.111, YELLOW)["flat_group"] = "ARScreenStars"
pixel_solid("AR_ScreenStarB_Left", {(0, 0)}, 0.694, SZ + 0 * PX, PX, 0.106, 0.111, YELLOW)["flat_group"] = "ARScreenStars"
pixel_solid("AR_ScreenStarC_Left", {(0, 0)}, 0.622, SZ + 5 * PX, PX, 0.106, 0.111, CYAN)["flat_group"] = "ARScreenBlip"

# Cyan light pipe along the deck's top edge over the screen: back buried in the receiver face, front
# 0.0045 behind the deck face, 0.010 above the deck top, still 0.006 under the bolt window.
side("AR_DeckLight_Left", [(0.462, 0.316), (0.734, 0.316), (0.7395, 0.332), (0.4675, 0.332)],
     0.084, 0.0995, CYAN)["flat_group"] = "ARDeckLight"

# ---------------------------------------------------------------- right: coin door
# On the right receiver face (-.090) over the lower recess and the removed Neon seat, under the bolt
# handle (bottom .301 at x .171-.243, out at y -.107): top .285, face -.104.
coin = slab("AR_CoinDoor_Right", crect(0.100, 0.150, 0.700, 0.285, 0.014), -0.082, -0.104, METAL, 0.0018)
for i, x in enumerate((0.250, 0.380)):
    block = slab(f"AR_CoinEntry_{i + 1}", crect(x - 0.036, 0.170, x + 0.036, 0.262, 0.008),
                 -0.100, -0.118, ACCENT, 0.0015)
    recess(block, f"AR_CoinSlotCut_{i + 1}", crect(x - 0.005, 0.185, x + 0.005, 0.247, 0.0025),
           -0.112, -0.14, role=DARK)
    side(f"AR_CoinSlotLight_{i + 1}", crect(x - 0.0065, 0.184, x + 0.0065, 0.248, 0.0025),
         -0.108, -0.116, YELLOW)
side("AR_CoinStripe_Right", [(0.520, 0.162), (0.560, 0.162), (0.612, 0.272), (0.572, 0.272)],
     -0.100, -0.108, MAGENTA)

# ---------------------------------------------------------------- handguard
# Stock envelope (y .088, bottom .15 rear to .25 front, top .451) from x 1.070 (0.025 into the receiver,
# which ends at 1.095; the stock ran only 0.013 in) to a raked cabinet nose at 2.240 that still swallows
# the barrel's rear end (2.20). Faceted vents behind the support hand (LeftGrip x 1.66), the side-art
# field ahead of it, a lit T-molding along each lower chamfer.
REAR = (1.070, 0.145, 0.451, 0.088, 0.430, 0.185, 0.066)
FRONT = (2.165, 0.245, 0.451, 0.088, 0.430, 0.285, 0.066)
hand = folded("AR_Handguard", (REAR, FRONT, (2.240, 0.300, 0.449, 0.082, 0.426, 0.325, 0.060)), BODY, bevel=0.004)
FIELD = [(1.740, 0.330), (1.756, 0.330), (1.756, 0.314), (1.772, 0.314), (1.772, 0.298),
         (2.100, 0.298), (2.128, 0.326), (2.128, 0.392), (2.104, 0.416), (1.760, 0.416), (1.740, 0.396)]
MAG_STRIPE = [(1.880, 0.301), (1.920, 0.301), (1.974, 0.413), (1.934, 0.413)]
CYAN_STRIPE = [(1.933, 0.301), (1.945, 0.301), (1.999, 0.413), (1.987, 0.413)]
for sign, label in ((1, "Left"), (-1, "Right")):
    for row, zc in enumerate((0.392, 0.340)):
        for k, x0 in enumerate((1.170, 1.300, 1.430)):
            recess(hand, f"AR_HandguardVent_{label}_{row + 1}{k + 1}", slot(x0, x0 + 0.105, zc, 0.026),
                   0.072 * sign, 0.15 * sign, role=DARK)
    recess(hand, f"AR_HandguardField_{label}", FIELD, 0.082 * sign, 0.15 * sign, role=PANEL)
    side(f"AR_HandguardStripe_{label}", MAG_STRIPE, 0.079 * sign, 0.086 * sign, MAGENTA)
    side(f"AR_HandguardLine_{label}", CYAN_STRIPE, 0.079 * sign, 0.086 * sign, CYAN)
    plate(f"AR_HandguardStar_{label}", star(2.068, 0.357, 0.028, 0.012), 0.079 * sign, 0.086 * sign, YELLOW)
    for k, (x, size) in enumerate(((1.858, 0.009), (1.836, 0.013), (1.808, 0.017))):
        side(f"AR_HandguardPixel_{label}_{k + 1}", square(x, 0.357, size), 0.079 * sign, 0.086 * sign, MAGENTA)
    # Cabinet T-molding: a lit bar seated along the lower chamfer (its mid-line), following the slope.
    start = Vector((REAR[0], 0.0735 * sign, (REAR[1] + REAR[5]) / 2))
    end = Vector((FRONT[0], 0.0735 * sign, (FRONT[1] + FRONT[5]) / 2))
    axis = (end - start).normalized()
    span = (end - start).length
    trim = prism_along(f"AR_HandguardTrim_{label}", tuple(start + axis * 0.06), tuple(axis),
                       [(0, 0.003), (0.008, 0.0068), (span - 0.13, 0.0068), (span - 0.122, 0.003)], MAGENTA)
    trim["flat_group"] = "ARTrim"

# ---------------------------------------------------------------- stock frame art
# Raked band and line on the frame's top bar (face .072, z .24-.29; the window's top edge is near .238), a pixel trail growing back.
for sign, label in ((1, "Left"), (-1, "Right")):
    side(f"AR_StockStripe_{label}", [(-0.558, 0.250), (-0.530, 0.250), (-0.515, 0.282), (-0.543, 0.282)],
         0.069 * sign, 0.076 * sign, MAGENTA)
    side(f"AR_StockLine_{label}", [(-0.520, 0.250), (-0.510, 0.250), (-0.495, 0.282), (-0.505, 0.282)],
         0.069 * sign, 0.076 * sign, CYAN)
    for k, (x, size) in enumerate(((-0.574, 0.010), (-0.598, 0.015), (-0.628, 0.021))):
        side(f"AR_StockPixel_{label}_{k + 1}", square(x, 0.267, size), 0.069 * sign, 0.076 * sign, MAGENTA)

# ---------------------------------------------------------------- cabinet butt
# Front swallows the frame's rear member (x -1.085/-0.95) by 0.025; raked marquee top; stepped rear;
# the bottom steps 0.012 under the frame's (-.21). It sits behind the ADS eye (x -.9625).
butt = side("AR_CabinetButt", [
    (-1.060, 0.380), (-1.250, 0.418), (-1.290, 0.398), (-1.300, 0.352), (-1.282, 0.334),
    (-1.282, 0.182), (-1.318, 0.160), (-1.318, -0.150), (-1.300, -0.200), (-1.268, -0.222),
    (-1.060, -0.222),
], -0.082, 0.082, BODY, bevel=0.008)
MARQUEE = [(-1.095, 0.330), (-1.248, 0.330), (-1.262, 0.344), (-1.262, 0.382), (-1.248, 0.395), (-1.095, 0.365)]
BUTT_FIELD = [(-1.112, -0.170), (-1.236, -0.170), (-1.236, -0.154), (-1.252, -0.154), (-1.252, -0.138),
              (-1.268, -0.138), (-1.268, 0.280), (-1.250, 0.298), (-1.112, 0.298), (-1.094, 0.280),
              (-1.094, -0.152)]
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(butt, f"AR_MarqueeSeat_{label}", MARQUEE, 0.074 * sign, 0.12 * sign, role=DARK)
    # The light is 0.0025 bigger than its seat (edges buried) and its top rakes a little flatter.
    side(f"AR_Marquee_{label}", [(-1.0925, 0.3275), (-1.2505, 0.3275), (-1.2645, 0.3415), (-1.2645, 0.3835),
                                (-1.2495, 0.3975), (-1.0925, 0.3675)], 0.070 * sign, 0.0785 * sign, CYAN)
    recess(butt, f"AR_ButtField_{label}", BUTT_FIELD, 0.076 * sign, 0.12 * sign, role=PANEL)
    side(f"AR_ButtStripe_{label}", [(-1.236, -0.090), (-1.206, -0.090), (-1.166, 0.140), (-1.196, 0.140)],
         0.073 * sign, 0.080 * sign, MAGENTA)
    side(f"AR_ButtLine_{label}", [(-1.196, -0.090), (-1.184, -0.090), (-1.144, 0.140), (-1.156, 0.140)],
         0.073 * sign, 0.080 * sign, CYAN)
    plate(f"AR_ButtStar_{label}", star(-1.180, 0.232, 0.032, 0.014), 0.073 * sign, 0.080 * sign, YELLOW)

# ---------------------------------------------------------------- stepped brake
# The stock collar (x 3.108-3.235) is an open-ended band (r .078, ends chamfered to .0718): the brake's
# rear (r .074) starts 0.020 inside it and cuts through its front chamfer, closing the band's mouth (v02:
# at r .070 it floated inside the band). Then a stepped light-ring groove with the cyan ring (ends buried
# in the groove walls), the ported main section, a stepped nose and a bore; the Muzzle locator (x 3.521)
# sits 0.001 inside the bore mouth.
brake = prism_along("AR_Brake", (3.215, 0, 0.385), (1, 0, 0), [
    (0.000, 0.066), (0.006, 0.074), (0.050, 0.074), (0.050, 0.062), (0.090, 0.062), (0.090, 0.079),
    (0.262, 0.079), (0.272, 0.070), (0.290, 0.070), (0.299, 0.060), (0.307, 0.060), (0.307, 0.026),
    (0.275, 0.026),
], METAL)
for k, x in enumerate((3.360, 3.408, 3.456)):
    recess(brake, f"AR_BrakePort_{k + 1}", crect(x, 0.364, x + 0.030, 0.406, 0.007), -0.2, 0.2, role=DARK)
prism_along("AR_BrakeLight", (3.262, 0, 0.385), (1, 0, 0), [(0, 0.067), (0.046, 0.067)], CYAN)["flat_group"] = "ARBrakeLight"

# ---------------------------------------------------------------- mag stripe
# A raked stripe on the magazine's inset floor (.057), crossing its two ridges (.059), 0.007 proud.
for sign, label in ((1, "Left"), (-1, "Right")):
    side(f"AR_MagStripe_{label}", [(0.585, -0.045), (0.615, -0.045), (0.670, 0.086), (0.640, 0.086)],
         0.054 * sign, 0.064 * sign, MAGENTA, bone="Mag")

result = finish_master(deck)
result["gap_moves"] = gap_moves
