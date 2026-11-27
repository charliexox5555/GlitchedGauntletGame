"""Arcade Marksman (Guardian): a long, low cabinet deck with joystick, buttons and pixel screen under the
charging channel on the upper receiver, a coin door on the lower receiver, a side-art handguard with
faceted vents, lit edge trim and a raked cabinet nose, stock-frame art, a cabinet butt with marquee and
side art, and a stepped eight-sided brake with a light ring.

Run in the live Blender MCP session with the stock
art-source/weapons/RemasterV2/Guardian/Guardian_RemasterV2_v05.blend open:
    exec(open("tools/blender/arcade/13_guardian.py").read(), {"VERSION": "v01"})
Left (+y) is the player-facing side. Stock sights, rig, locators and CharmLoop are kept.
Stock measurements (2026-11-27, ray-cast depth maps and swept clips, Root-relative):
  upper receiver side face y .086 (x -.013-.89, z .2336-.416, top chamfer to .064 at .416); panel
  lines (floor .082) at x .096-.104 and .826-.834; charging channel (floor .070) x .30-.79,
  z .326-.366; the handle knob (y .112-.136, z .318-.375) rests at x .688-.767 and comes back to
  x .48 (Draw); a stock Neon strip x .353-.557, z .282-.296 (removed under the deck);
  lower receiver face y .080 (x -.07-.877, z .13-.2336), side recess (floor .075) x -.05-.14,
  z .15-.215 on both sides; fire selector (left) x .09-.173, sweeps up to z .243 (Draw);
  bolt catch (left) x .404-.47, z .16-.235, y .078-.09; pins at x .21/.37, z .19 both sides;
  right: ejection port x .317-.637, z .268-.352, bolt runs back to x .193 (y -.082/-.062);
  front block x .877-1.136, y .092; handguard x 1.123-2.355, y .088, bottom .189, keel .223,
  shoulder .41, top .432; CharmLoop x 1.165-1.197, z .206-.248 on its rear lower-left;
  front sight x 2.214-2.301 on the rail; barrel r .04 x 2.34-2.79, brake r .058 x 2.78-2.998,
  Muzzle x 2.9984; stock body face y .070 (top bar z .243-.403, window from x -.52), cheek riser
  x -.553/-.98, rear member to x -1.085, butt pad x -1.08/-1.245; magazine face y .060 below the
  PANEL band (z -.075/-.045). ADS: adsDistance .33 (Config/Weapons), eye x -.275, z .4984,
  adsFov 58.
"""

from pathlib import Path

import bpy

GUN = "Guardian"
VERSION = globals().get("VERSION", "v01")
exec((Path(bpy.data.filepath).parents[4] / "tools/blender/arcade/arcade_lib.py").read_text(encoding="utf-8"))

replace("Handguard", "Stock", "Barrel", "Neon")

# ---------------------------------------------------------------- retained stock
for name in ("Receiver", "CharmLoop", "ChargingHandle", "Bolt", "BoltCatch",
             "FireSelector", "Trigger", "Grip", "Sights"):
    dress(name)
dress("Mag", slots={"Dark": GRIP})
# The two right-side lower-receiver pins sit under the coin door.
dress("Pins", keep=lambda island: not (limits(island, 1)[1] < 0 and limits(island, 2)[1] < 0.21
                                       and 0.1 < limits(island, 0)[0] < 0.4))
# Stock skeleton body, cheek riser, tube and ring without the butt pad (the cabinet butt replaces it).
dress("Stock", copy_name="AR_StockFrame", keep=lambda island: limits(island, 0)[0] > -1.2)
# Barrel: keep the tube; the stepped brake replaces the round-ported brake.
dress("Barrel", copy_name="AR_BarrelTube", keep=lambda island: limits(island, 0)[1] < 2.795)


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
# - the rail bridged 0.020 over the front block (top .394) from the receiver (x .89) to the handguard,
#   a see-through slot under it: a dark riser now carries it (see the rail riser);
# - front sight base: 0.002 into the rail (top .436): its foot is now .414; the post 0.004 into the base:
#   its foot is now .440;
# - rear sight base: 0.006 into the receiver top (.416): its foot is now .396;
# - castle ring and buffer tube: 0.010 / 0.007 into the receiver's rear (x -.013): the ring moves 0.012
#   forward and the tube's front runs to x .010;
# - barrel: 0.020 into the brake's collar: its end is now 2.800 (0.030);
# - the handguard ran only 0.013 over the front block, and the cabinet butt 0.018 over the stock's rear
#   member (see the handguard and the butt).
SIGHTS = native("Sights")
FRAME = bpy.data.objects["AR_StockFrame"]
gap_moves = {
    "front_sight_base": nudge(SIGHTS, lambda p: p.z < 0.435, (0, 0, -0.020),
                              lambda lo, hi: lo.x > 2.2 and hi.x < 2.31 and lo.z > 0.43 and hi.z < 0.465),
    "front_sight_post": nudge(SIGHTS, lambda p: p.z < 0.459, (0, 0, -0.018),
                              lambda lo, hi: hi.y < 0.006 and lo.z > 0.45 and hi.z < 0.5),
    "rear_sight_base": nudge(SIGHTS, lambda p: p.z < 0.411, (0, 0, -0.014),
                             lambda lo, hi: hi.x < 0.2 and lo.z < 0.42),
    "castle_ring": nudge(FRAME, lambda p: True, (0.012, 0, 0),
                         lambda lo, hi: abs(lo.x + 0.03) < 0.005 and abs(hi.x + 0.003) < 0.005),
    "buffer_tube": nudge(FRAME, lambda p: p.x > -0.01, (0.016, 0, 0),
                         lambda lo, hi: abs(lo.x + 0.36) < 0.01 and abs(hi.x + 0.006) < 0.005),
    "barrel_end": nudge(bpy.data.objects["AR_BarrelTube"], lambda p: p.x > 2.785, (0.010, 0, 0)),
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
# A long, low control panel on the upper receiver face (.086) under the charging channel: back at
# y .078 (buried), face .100 (0.014 proud). Top .316 stays under the channel (.326) and the handle
# knob (z .318+, y .112+); bottom .240 clears the bolt catch (top .235) and the fire selector
# (x < .173, up to z .243), and the deck starts ahead of the selector. Raked ends.
# ADS (eye x -.275, z .4984): every deck part stays under the receiver's top-left edge as seen from
# the eye ((.4984 - z) > 1.29 y) and the joystick sits far enough forward that the receiver's rear end
# hides it.
DECK = [(0.214, 0.240), (0.688, 0.240), (0.700, 0.252), (0.700, 0.296), (0.680, 0.316),
        (0.214, 0.316), (0.200, 0.302), (0.200, 0.254)]
deck = slab("AR_ControlDeck_Left", DECK, 0.078, 0.100, PANEL, 0.0018)

# Joystick at the rear, then three faceted buttons in collars rising toward the muzzle.
prism_along("AR_JoystickWasher", (0.244, 0.096, 0.276), (0, 1, 0), [(0, 0.021), (0.009, 0.0175)], DARK)
prism_along("AR_JoystickShaft", (0.244, 0.102, 0.276), (0, 1, 0), [(0, 0.0065), (0.030, 0.0065)], METAL)
stick_ball = prism_along("AR_JoystickBall", (0.244, 0.102, 0.276), (0, 1, 0), [
    (0.024, 0.009), (0.031, 0.018), (0.043, 0.018), (0.050, 0.009),
], BTN_MAGENTA)
stick_ball["flat_group"] = "ARStickBall"
for i, (x, z, role) in enumerate(((0.314, 0.272, BTN_CYAN), (0.368, 0.276, BTN_YELLOW),
                                  (0.422, 0.280, BTN_MAGENTA))):
    prism_along(f"AR_ButtonCollar_{i + 1}", (x, 0.096, z), (0, 1, 0),
                [(0, 0.026), (0.010, 0.0225)], DARK)
    button = prism_along(f"AR_Button_{i + 1}", (x, 0.102, z), (0, 1, 0),
                         [(0, 0.020), (0.016, 0.020), (0.021, 0.014)], role)
    button["flat_group"] = f"ARButton{i + 1}"

# Pixel screen: bezel ring, glowing screen floor, pixel graphic standing 0.004 proud.
inner = crect(0.474, 0.2545, 0.664, 0.3035, 0.007)
outer = crect(0.462, 0.247, 0.676, 0.311, 0.012)
loft("AR_ScreenBezel_Left", [
    [(x, 0.096, z) for x, z in outer], [(x, 0.110, z) for x, z in outer],
    [(x, 0.110, z) for x, z in inner], [(x, 0.096, z) for x, z in inner],
], DARK, loop=True)
plate("AR_Screen_Left", crect(0.472, 0.2525, 0.666, 0.3055, 0.007), 0.097, 0.103, SCREEN)["flat_group"] = "ARScreen"
PX = 0.0085
SX, SZ = 0.484, 0.2585
SHIP = {(0, 4), (1, 4), (0, 3), (1, 3), (2, 3), (3, 3), (1, 2), (2, 2), (3, 2), (4, 2), (5, 2), (6, 2),
        (0, 1), (1, 1), (2, 1), (3, 1), (0, 0), (1, 0)}
pixel_solid("AR_ScreenShip_Left", SHIP, SX, SZ, PX, 0.102, 0.107, CYAN)["flat_group"] = "ARScreenShip"
pixel_solid("AR_ScreenShot_Left", {(0, 0), (1, 0), (2, 0)}, SX + 8 * PX, SZ + 2 * PX, PX,
            0.102, 0.107, MAGENTA)["flat_group"] = "ARScreenShot"
PLUS = {(1, 0), (0, 1), (1, 1), (2, 1), (1, 2)}
pixel_solid("AR_ScreenStarA_Left", PLUS, 0.612, SZ + 1 * PX, PX, 0.102, 0.107, YELLOW)["flat_group"] = "ARScreenStars"
pixel_solid("AR_ScreenStarB_Left", {(0, 0)}, 0.648, SZ + 0 * PX, PX, 0.102, 0.107, YELLOW)["flat_group"] = "ARScreenStars"
pixel_solid("AR_ScreenStarC_Left", {(0, 0)}, 0.598, SZ + 4 * PX, PX, 0.102, 0.107, CYAN)["flat_group"] = "ARScreenBlip"

# Cyan light pipe along the deck's top edge over the screen: back buried in the receiver face,
# front 0.0045 behind the deck face, 0.0055 above the deck top, 0.0045 under the channel.
side("AR_DeckLight_Left", [(0.468, 0.310), (0.670, 0.310), (0.6755, 0.3215), (0.4735, 0.3215)],
     0.080, 0.0955, CYAN)["flat_group"] = "ARDeckLight"

# ---------------------------------------------------------------- right: coin door
# On the lower receiver face (-.080) over the stock side recess (floor -.075), behind the magwell.
coin = slab("AR_CoinDoor_Right", crect(-0.052, 0.138, 0.450, 0.229, 0.012), -0.072, -0.094, METAL, 0.0018)
for i, x in enumerate((0.085, 0.205)):
    block = slab(f"AR_CoinEntry_{i + 1}", crect(x - 0.030, 0.158, x + 0.030, 0.211, 0.006),
                 -0.090, -0.106, ACCENT, 0.0015)
    recess(block, f"AR_CoinSlotCut_{i + 1}", crect(x - 0.004, 0.169, x + 0.004, 0.200, 0.002),
           -0.100, -0.126, role=DARK)
    side(f"AR_CoinSlotLight_{i + 1}", crect(x - 0.0055, 0.168, x + 0.0055, 0.201, 0.002),
         -0.096, -0.104, YELLOW)
side("AR_CoinStripe_Right", [(0.312, 0.146), (0.347, 0.146), (0.389, 0.221), (0.354, 0.221)],
     -0.090, -0.096, MAGENTA)

# ---------------------------------------------------------------- handguard
# Stock envelope (y .088, keel .223, shoulder .41, top .432) from x 1.115 (gap sweep: 0.021 over the
# front block, which ends at 1.136; the stock started at 1.123) to x 2.362 (0.007
# past the rail base's front face at 2.355, so the two never share a plane); the front rakes
# back under the barrel like a cabinet front. Faceted vents behind the support hand keep the
# Marksman's read; the side-art field sits ahead of it.
hand = folded("AR_Handguard", (
    (1.115, 0.189, 0.432, 0.088, 0.410, 0.223, 0.066),
    (2.290, 0.189, 0.432, 0.088, 0.410, 0.223, 0.066),
    (2.362, 0.262, 0.428, 0.082, 0.406, 0.290, 0.060),
), BODY, bevel=0.004)
FIELD = [(1.760, 0.282), (1.776, 0.282), (1.776, 0.265), (1.792, 0.265), (1.792, 0.248),
         (2.232, 0.248), (2.260, 0.276), (2.260, 0.364), (2.232, 0.392), (1.780, 0.392), (1.760, 0.372)]
MAG_STRIPE = [(1.940, 0.251), (1.980, 0.251), (2.054, 0.389), (2.014, 0.389)]
CYAN_STRIPE = [(1.993, 0.251), (2.005, 0.251), (2.079, 0.389), (2.067, 0.389)]
for sign, label in ((1, "Left"), (-1, "Right")):
    for row, zc in enumerate((0.370, 0.300)):
        for k, x0 in enumerate((1.250, 1.390, 1.530)):
            recess(hand, f"AR_HandguardVent_{label}_{row + 1}{k + 1}", slot(x0, x0 + 0.110, zc, 0.028),
                   0.072 * sign, 0.15 * sign, role=DARK)
    recess(hand, f"AR_HandguardField_{label}", FIELD, 0.082 * sign, 0.15 * sign, role=PANEL)
    side(f"AR_HandguardStripe_{label}", MAG_STRIPE, 0.079 * sign, 0.086 * sign, MAGENTA)
    side(f"AR_HandguardLine_{label}", CYAN_STRIPE, 0.079 * sign, 0.086 * sign, CYAN)
    plate(f"AR_HandguardStar_{label}", star(2.200, 0.330, 0.026, 0.011), 0.079 * sign, 0.086 * sign, YELLOW)
    for k, (x, size) in enumerate(((1.938, 0.008), (1.918, 0.012), (1.892, 0.016))):
        side(f"AR_HandguardPixel_{label}_{k + 1}", square(x, 0.320, size), 0.079 * sign, 0.086 * sign, MAGENTA)
    # Cabinet T-molding: a lit bar seated along the lower chamfer, ahead of the charm loop.
    trim = prism_along(f"AR_HandguardTrim_{label}", (1.240, 0.0735 * sign, 0.206), (1, 0, 0),
                       [(0, 0.003), (0.008, 0.0068), (1.032, 0.0068), (1.040, 0.003)], MAGENTA)
    trim["flat_group"] = "ARTrim"

# ---------------------------------------------------------------- rail riser
# Gap sweep: the stock rail base (z .414-.436, y +-.03) bridged 0.020 over the front block (top .394)
# from the upper receiver (front x .89) to the handguard, a slot you could see through. A dark riser,
# narrower than the rail (y +-.022), now carries it: 0.020 into the front block, the rail, the receiver
# and the handguard. From the side it reads as the rail's spine, as on the Havoc.
side("AR_RailRiser", [(0.870, 0.374), (1.143, 0.374), (1.143, 0.434), (0.870, 0.434)], -0.022, 0.022, DARK)

# ---------------------------------------------------------------- stock frame art
# Raked band and line on the top bar ahead of the window, a pixel trail growing back from the band.
for sign, label in ((1, "Left"), (-1, "Right")):
    side(f"AR_StockStripe_{label}", [(-0.600, 0.262), (-0.572, 0.262), (-0.534, 0.374), (-0.562, 0.374)],
         0.067 * sign, 0.074 * sign, MAGENTA)
    side(f"AR_StockLine_{label}", [(-0.562, 0.262), (-0.552, 0.262), (-0.514, 0.374), (-0.524, 0.374)],
         0.067 * sign, 0.074 * sign, CYAN)
    for k, (x, size) in enumerate(((-0.612, 0.009), (-0.634, 0.014), (-0.664, 0.020))):
        side(f"AR_StockPixel_{label}_{k + 1}", square(x, 0.320, size), 0.067 * sign, 0.074 * sign, MAGENTA)

# ---------------------------------------------------------------- cabinet butt
# Front swallows the body's rear member (x -1.034/-1.085) by 0.04 (gap sweep: was -1.055, 0.018 measured
# past the bevel); raked marquee top; stepped rear; bottom and top stepped clear of the body's (-.16 / .403).
butt = side("AR_CabinetButt", [
    (-1.045, 0.414), (-1.205, 0.442), (-1.238, 0.424), (-1.245, 0.376), (-1.226, 0.360),
    (-1.220, 0.196), (-1.245, 0.178), (-1.245, 0.134), (-1.226, 0.116), (-1.226, -0.140),
    (-1.200, -0.176), (-1.045, -0.176),
], -0.078, 0.078, BODY, bevel=0.008)
MARQUEE = [(-1.095, 0.366), (-1.200, 0.366), (-1.212, 0.378), (-1.212, 0.416), (-1.198, 0.428), (-1.095, 0.409)]
BUTT_FIELD = [(-1.111, -0.140), (-1.180, -0.140), (-1.180, -0.126), (-1.194, -0.126), (-1.194, -0.112),
              (-1.208, -0.112), (-1.208, 0.314), (-1.192, 0.330), (-1.111, 0.330), (-1.095, 0.314),
              (-1.095, -0.124)]
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(butt, f"AR_MarqueeSeat_{label}", MARQUEE, 0.070 * sign, 0.12 * sign, role=DARK)
    # The light is 0.0025 bigger than its seat (edges buried) and its top rakes a little flatter.
    side(f"AR_Marquee_{label}", [(-1.0925, 0.3635), (-1.2025, 0.3635), (-1.2145, 0.3755), (-1.2145, 0.4185),
                                (-1.1995, 0.4305), (-1.0925, 0.4115)], 0.066 * sign, 0.0745 * sign, CYAN)
    recess(butt, f"AR_ButtField_{label}", BUTT_FIELD, 0.072 * sign, 0.12 * sign, role=PANEL)
    side(f"AR_ButtStripe_{label}", [(-1.190, -0.060), (-1.164, -0.060), (-1.134, 0.130), (-1.160, 0.130)],
         0.069 * sign, 0.076 * sign, MAGENTA)
    side(f"AR_ButtLine_{label}", [(-1.154, -0.060), (-1.144, -0.060), (-1.114, 0.130), (-1.124, 0.130)],
         0.069 * sign, 0.076 * sign, CYAN)
    plate(f"AR_ButtStar_{label}", star(-1.152, 0.250, 0.028, 0.012), 0.069 * sign, 0.076 * sign, YELLOW)

# ---------------------------------------------------------------- stepped brake
# Rear collar over the barrel's end, a stepped light-ring groove with the cyan ring (ends buried in the
# groove walls), the ported main section, a stepped nose and a bore; the Muzzle locator (x 2.9984)
# sits in the bore mouth.
brake = prism_along("AR_Brake", (2.770, 0, 0.368), (1, 0, 0), [
    (0.000, 0.048), (0.010, 0.058), (0.052, 0.058), (0.052, 0.050), (0.086, 0.050), (0.086, 0.062),
    (0.196, 0.062), (0.206, 0.054), (0.222, 0.054), (0.230, 0.046), (0.230, 0.022), (0.200, 0.022),
], METAL)
for k, x in enumerate((2.876, 2.922)):
    recess(brake, f"AR_BrakePort_{k + 1}", crect(x, 0.350, x + 0.030, 0.386, 0.006), -0.2, 0.2, role=DARK)
prism_along("AR_BrakeLight", (2.819, 0, 0.368), (1, 0, 0), [(0, 0.055), (0.040, 0.055)], CYAN)["flat_group"] = "ARBrakeLight"

# ---------------------------------------------------------------- mag stripe
# A raked stripe on the plain lower face, between the PANEL band and the base plate.
for sign, label in ((1, "Left"), (-1, "Right")):
    side(f"AR_MagStripe_{label}", [(0.660, -0.158), (0.684, -0.158), (0.722, -0.082), (0.698, -0.082)],
         0.057 * sign, 0.064 * sign, MAGENTA, bone="Mag")

result = finish_master(deck)
result["gap_moves"] = gap_moves
