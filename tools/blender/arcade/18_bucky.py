"""Arcade Pump (Bucky): a tall cabinet deck with joystick, buttons and pixel screen in the receiver's
left recess panel, a coin door on the lower right receiver, a new faceted pump forend (rides the Pump
bone) with grip grooves, side-art fields and lit edge trim, stock-frame art, a cabinet butt with marquee
and side art, and a stepped eight-sided muzzle collar with a light ring.

Run in a live Blender session with the stock
art-source/weapons/RemasterV2/Bucky/Bucky_RemasterV2_v05.blend open:
    exec(open("tools/blender/arcade/18_bucky.py").read(), {"VERSION": "v01"})
Left (+y) is the player-facing side (Bucky_FP_Hip sits at y .6). Stock sights, rig, locators and CharmLoop are
kept. Stock measurements (2026-11-27, ray-cast depth maps and swept clips, Root-relative):
  receiver x -.099-.969, y +-.078 lower band z .132-.235; upper recess panel floor .073, z .235-.395, rear
  edge raked (.17, .24) to (.30, .395), to x .94; top chamfer .072/.062 to the flat top .42 (|y| < .035);
  pins at x .082-.106 / .923-.947, z .288-.312 (both sides); stock Neon strips x .132-.282, z .207-.225;
  right: ejection port x .44-.74, z .26-.35, bolt (y -.052/-.074, z .262-.348) runs back 0.26 to x .187;
  trigger guard x .18-.531, z 0-.144; grip x -.213-.159 under the receiver; CharmLoop x .899-.931,
  z .128-.17 on the lower left front (CharmPoint .915, .0798, .1323, Charm bone swings up to 21 deg);
  Pump: forend x 1.239-2.094, y +-.084, z .096-.315 (grooves .072, inner wall .072), action bars
  x .951-1.245 (y +-.04-.054, z .246-.276); the Pump and Bolt bones travel -0.26 / +0.004 in x
  (Draw, Fire, ReloadEmpty; Inspect -0.104), so the forend's rear comes to x .979 (receiver .969);
  magazine tube r .058 (centre z .216) x .95-2.73 into its cap x 2.72-2.79; barrel r .054 (centre z .369)
  x .95-2.832 (bore to 2.752), thin muzzle ring x 2.782-2.797; barrel band x 2.448-2.541; front bead
  x 2.6-2.734 (base z .418), rear sight x .238-.416 (base .418); Muzzle 2.832, Flash bone 2.842.
  Stock: skeleton body x -.873-.231 (face .070, top bar z .17-.31, window under it x -.77-.53),
  butt pad island x -.951-.86, wrist tube x -.25 to -.093 into the receiver's rear (-.099).
  No magazine (tube fed), so there is no mag stripe. Config/Weapons Bucky: noAds = true (no adsDistance);
  the stock file has no AimPoint, Cam_Hip or Cam_ADS (Bucky_FP_Hip is the held camera).
"""

from pathlib import Path

import bpy

GUN = "Bucky"
VERSION = globals().get("VERSION", "v01")
exec((Path(bpy.data.filepath).parents[4] / "tools/blender/arcade/arcade_lib.py").read_text(encoding="utf-8"))

replace("Stock")

# ---------------------------------------------------------------- retained stock
for name in ("Receiver", "CharmLoop", "Bolt", "Trigger", "Grip", "Sights", "Pins", "Neon", "Shell"):
    dress(name)
# Pump: keep the two action bars (on the stock object, so their stock slide into the receiver stays a stock
# pair); the new faceted forend replaces the grooved one.
dress("Pump", keep=lambda island: limits(island, 0)[1] < 1.3)
# Barrel: keep the barrel, tube, band and tube cap; the stepped muzzle collar replaces the thin ring.
dress("Barrel", keep=lambda island: not (limits(island, 0)[0] > 2.78 and limits(island, 0)[1] < 2.80))
# Stock skeleton body and wrist without the butt pad (the cabinet butt replaces it).
dress("Stock", copy_name="AR_StockFrame", keep=lambda island: limits(island, 0)[0] > -0.94)


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


# Gap sweep (owner 2026-11-27: no gaps anywhere). Measured stock joins buried under 0.02, now 0.02+:
# - barrel: 0.019 into the receiver's front (.969): its rear end moves to .938 (the tube keeps .95: the
#   stock shell meets its rear end during Reload / ReloadInsert, a stock pair);
# - tube: 0.010 into its cap (2.72): its front end moves to 2.750;
# - rear sight and front bead bases: 0.002 / 0.005 onto round or chamfered tops (their base corners
#   sat proud at the sides): both feet move down 0.018;
# - wrist tube: 0.006 into the receiver's rear (-.099) and 0.019 over the skeleton body (-.231): its
#   front moves 0.016 forward and its rear 0.008 back;
# - action bars: 0.006 into the forend's rear (1.239): their front ends move 0.020 forward.
SIGHTS = native("Sights")
BARREL = native("Barrel")
FRAME = bpy.data.objects["AR_StockFrame"]
gap_moves = {
    "barrel_rear": nudge(BARREL, lambda p: p.x < 0.952, (-0.012, 0, 0),
                         lambda lo, hi: lo.x < 1.0 and hi.x > 2.8),
    "barrel_end": nudge(BARREL, lambda p: p.x > 2.82, (-0.042, 0, 0),
                        lambda lo, hi: lo.x < 1.0 and hi.x > 2.8),
    "tube_front": nudge(BARREL, lambda p: p.x > 2.725, (0.020, 0, 0),
                        lambda lo, hi: lo.x < 1.0 and abs(hi.x - 2.73) < 0.003),
    "rear_sight_base": nudge(SIGHTS, lambda p: p.z < 0.422, (0, 0, -0.018), lambda lo, hi: hi.x < 0.5),
    "front_bead_base": nudge(SIGHTS, lambda p: p.z < 0.422, (0, 0, -0.018), lambda lo, hi: lo.x > 2.5),
    "wrist_front": nudge(FRAME, lambda p: p.x > -0.095, (0.016, 0, 0),
                         lambda lo, hi: abs(lo.x + 0.25) < 0.005 and abs(hi.x + 0.093) < 0.005),
    "wrist_rear": nudge(FRAME, lambda p: p.x < -0.244, (-0.008, 0, 0),
                        lambda lo, hi: abs(lo.x + 0.25) < 0.005 and hi.x > -0.1),
    "pump_bars": nudge(native("Pump"), lambda p: p.x > 1.24, (0.020, 0, 0)),
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
# A tall control panel on the receiver's left recess panel (floor .073): back at y .066 (buried), face .088
# (0.015 proud of the floor, 0.010 of the band). Its rear edge rakes with the recess's own rear edge; it
# stays 0.011 under the recess's top wall (.395), 0.013 over its bottom wall (.235) and 0.037 behind the
# front pin (x .923). The joystick and buttons sit over the pump's action bars (y .054) with room.
DECK = [(0.225, 0.248), (0.872, 0.248), (0.886, 0.262), (0.886, 0.368), (0.870, 0.384),
        (0.333, 0.384), (0.217, 0.258)]
deck = slab("AR_ControlDeck_Left", DECK, 0.066, 0.088, PANEL, 0.0018)

prism_along("AR_JoystickWasher", (0.322, 0.084, 0.312), (0, 1, 0), [(0, 0.023), (0.009, 0.0195)], DARK)
prism_along("AR_JoystickShaft", (0.322, 0.090, 0.312), (0, 1, 0), [(0, 0.007), (0.032, 0.007)], METAL)
stick_ball = prism_along("AR_JoystickBall", (0.322, 0.090, 0.312), (0, 1, 0), [
    (0.026, 0.010), (0.033, 0.020), (0.046, 0.020), (0.053, 0.010),
], BTN_MAGENTA)
stick_ball["flat_group"] = "ARStickBall"
for i, (x, z, role) in enumerate(((0.404, 0.296, BTN_CYAN), (0.464, 0.310, BTN_YELLOW),
                                  (0.524, 0.324, BTN_MAGENTA))):
    prism_along(f"AR_ButtonCollar_{i + 1}", (x, 0.084, z), (0, 1, 0),
                [(0, 0.027), (0.010, 0.0235)], DARK)
    button = prism_along(f"AR_Button_{i + 1}", (x, 0.090, z), (0, 1, 0),
                         [(0, 0.021), (0.016, 0.021), (0.021, 0.015)], role)
    button["flat_group"] = f"ARButton{i + 1}"

# Pixel screen: bezel ring, glowing screen floor, pixel graphic standing 0.004 proud.
inner = crect(0.592, 0.2695, 0.854, 0.3645, 0.007)
outer = crect(0.580, 0.262, 0.866, 0.372, 0.012)
loft("AR_ScreenBezel_Left", [
    [(x, 0.084, z) for x, z in outer], [(x, 0.098, z) for x, z in outer],
    [(x, 0.098, z) for x, z in inner], [(x, 0.084, z) for x, z in inner],
], DARK, loop=True)
plate("AR_Screen_Left", crect(0.590, 0.2675, 0.856, 0.3665, 0.007), 0.085, 0.091, SCREEN)["flat_group"] = "ARScreen"
PX = 0.011
SX, SZ = 0.606, 0.281
SHIP = {(0, 4), (1, 4), (0, 3), (1, 3), (2, 3), (3, 3), (1, 2), (2, 2), (3, 2), (4, 2), (5, 2), (6, 2),
        (0, 1), (1, 1), (2, 1), (3, 1), (0, 0), (1, 0)}
pixel_solid("AR_ScreenShip_Left", SHIP, SX, SZ, PX, 0.090, 0.095, CYAN)["flat_group"] = "ARScreenShip"
pixel_solid("AR_ScreenShot_Left", {(0, 0), (1, 0), (2, 0)}, SX + 8 * PX, SZ + 2 * PX, PX,
            0.090, 0.095, MAGENTA)["flat_group"] = "ARScreenShot"
PLUS = {(1, 0), (0, 1), (1, 1), (2, 1), (1, 2)}
pixel_solid("AR_ScreenStarA_Left", PLUS, 0.790, SZ + 3 * PX, PX, 0.090, 0.095, YELLOW)["flat_group"] = "ARScreenStars"
pixel_solid("AR_ScreenStarB_Left", {(0, 0)}, 0.830, SZ, PX, 0.090, 0.095, YELLOW)["flat_group"] = "ARScreenStars"
pixel_solid("AR_ScreenStarC_Left", {(0, 0)}, 0.768, SZ + 6 * PX, PX, 0.090, 0.095, CYAN)["flat_group"] = "ARScreenBlip"

# Cyan light pipe along the deck's top edge over the screen: back buried in the recess floor, front 0.0045
# behind the deck face, 0.0055 above the deck top, 0.0055 under the recess's top wall.
side("AR_DeckLight_Left", [(0.586, 0.378), (0.860, 0.378), (0.8655, 0.3895), (0.5915, 0.3895)],
     0.068, 0.0835, CYAN)["flat_group"] = "ARDeckLight"

# ---------------------------------------------------------------- right: coin door
# On the lower receiver band (-.078) ahead of the stock Neon strip (x .282) and under the ejection port and
# the bolt's whole stroke (z .262+): top .229 stays 0.006 under the band's top step (.235).
coin = slab("AR_CoinDoor_Right", crect(0.300, 0.146, 0.820, 0.229, 0.012), -0.072, -0.094, METAL, 0.0018)
for i, x in enumerate((0.410, 0.530)):
    block = slab(f"AR_CoinEntry_{i + 1}", crect(x - 0.030, 0.158, x + 0.030, 0.214, 0.006),
                 -0.090, -0.106, ACCENT, 0.0015)
    recess(block, f"AR_CoinSlotCut_{i + 1}", crect(x - 0.004, 0.170, x + 0.004, 0.202, 0.002),
           -0.100, -0.126, role=DARK)
    side(f"AR_CoinSlotLight_{i + 1}", crect(x - 0.0055, 0.169, x + 0.0055, 0.203, 0.002),
         -0.096, -0.104, YELLOW)
side("AR_CoinStripe_Right", [(0.640, 0.154), (0.675, 0.154), (0.717, 0.221), (0.682, 0.221)],
     -0.090, -0.096, MAGENTA)

# ---------------------------------------------------------------- pump forend (bone Pump)
# A faceted sleeve in the stock envelope (x 1.239-2.094, y +-.084, z .096-.311; the stock top touched the
# barrel at .315, this one stays 0.004 under it) with chamfered ends and an eight-sided bore (inradius
# .062) round the magazine tube (r .058). Its rear comes to x .979 at the end of the stroke, 0.010 ahead
# of the receiver, and every groove, field, art piece and trim stays inside its x range.
TUBE_Z = 0.216
BORE = [(0.0671 * math.cos(math.radians(a)), TUBE_Z + 0.0671 * math.sin(math.radians(a)))
        for a in (112.5, 67.5, 22.5, -22.5, -67.5, -112.5, -157.5, 157.5)]
FOLD = (0.096, 0.311, 0.084, 0.285, 0.125, 0.050)
END = (0.104, 0.303, 0.076, 0.281, 0.129, 0.046)
forend = loft("AR_Forend", [
    fold(1.239, *END), fold(1.249, *FOLD), fold(2.082, *FOLD), fold(2.094, *END),
    [(2.094, y, z) for y, z in BORE], [(1.239, y, z) for y, z in BORE],
], BODY, bone="Pump", loop=True)


def groove(x):
    """A vertical grip groove with pointed (45 degree) ends."""
    return [(x, 0.150), (x + 0.007, 0.143), (x + 0.014, 0.150), (x + 0.014, 0.262),
            (x + 0.007, 0.269), (x, 0.262)]


FIELD = [(1.560, 0.175), (1.574, 0.175), (1.574, 0.160), (1.588, 0.160), (1.588, 0.145),
         (1.972, 0.145), (2.000, 0.173), (2.000, 0.236), (1.974, 0.262), (1.578, 0.262), (1.560, 0.244)]
MAG_STRIPE = [(1.700, 0.150), (1.736, 0.150), (1.800, 0.257), (1.764, 0.257)]
CYAN_STRIPE = [(1.750, 0.150), (1.761, 0.150), (1.825, 0.257), (1.814, 0.257)]
for sign, label in ((1, "Left"), (-1, "Right")):
    for k, x0 in enumerate((1.320, 1.375, 1.430, 1.485)):
        recess(forend, f"AR_ForendGroove_{label}_{k + 1}", groove(x0), 0.074 * sign, 0.15 * sign,
               role=DARK, bone="Pump")
    recess(forend, f"AR_ForendField_{label}", FIELD, 0.074 * sign, 0.15 * sign, role=PANEL, bone="Pump")
    side(f"AR_ForendStripe_{label}", MAG_STRIPE, 0.071 * sign, 0.078 * sign, MAGENTA, bone="Pump")
    side(f"AR_ForendLine_{label}", CYAN_STRIPE, 0.071 * sign, 0.078 * sign, CYAN, bone="Pump")
    plate(f"AR_ForendStar_{label}", star(1.928, 0.204, 0.026, 0.011), 0.071 * sign, 0.078 * sign, YELLOW,
          bone="Pump")
    for k, (x, size) in enumerate(((1.690, 0.008), (1.670, 0.012), (1.646, 0.016))):
        side(f"AR_ForendPixel_{label}_{k + 1}", square(x, 0.204, size), 0.071 * sign, 0.078 * sign, MAGENTA,
             bone="Pump")
    # Cabinet T-molding: a lit bar seated in the lower chamfer (surface y .0695 at z .110).
    trim = prism_along(f"AR_ForendTrim_{label}", (1.290, 0.0705 * sign, 0.110), (1, 0, 0),
                       [(0, 0.003), (0.008, 0.0068), (0.752, 0.0068), (0.760, 0.003)], MAGENTA, bone="Pump")
    trim["flat_group"] = "ARTrim"

# ---------------------------------------------------------------- stock frame art
# Raked band and line on the top bar (face .070, z .17-.31) over the window, a pixel trail growing back.
for sign, label in ((1, "Left"), (-1, "Right")):
    side(f"AR_StockStripe_{label}", [(-0.600, 0.190), (-0.574, 0.190), (-0.540, 0.300), (-0.566, 0.300)],
         0.067 * sign, 0.074 * sign, MAGENTA)
    side(f"AR_StockLine_{label}", [(-0.564, 0.190), (-0.554, 0.190), (-0.520, 0.300), (-0.530, 0.300)],
         0.067 * sign, 0.074 * sign, CYAN)
    for k, (x, size) in enumerate(((-0.612, 0.009), (-0.634, 0.014), (-0.664, 0.020))):
        side(f"AR_StockPixel_{label}_{k + 1}", square(x, 0.245, size), 0.067 * sign, 0.074 * sign, MAGENTA)

# ---------------------------------------------------------------- cabinet butt
# Front swallows the skeleton body's rear upright (x -.873) to -.835 (0.038); raked marquee top; stepped
# rear; top and bottom stepped clear of the body's (.33-.345 / -.283). y +-.082, so the recessed fields
# (floor .076) stay 0.006 clear of the body face (.070) buried inside it.
butt = side("AR_CabinetButt", [
    (-0.835, 0.348), (-0.912, 0.374), (-0.944, 0.360), (-0.955, 0.330), (-0.938, 0.314),
    (-0.934, 0.150), (-0.955, 0.134), (-0.955, 0.090), (-0.936, 0.074), (-0.936, -0.255),
    (-0.912, -0.298), (-0.835, -0.298),
], -0.082, 0.082, BODY, bevel=0.006)
MARQUEE = [(-0.852, 0.318), (-0.918, 0.318), (-0.928, 0.328), (-0.928, 0.350), (-0.914, 0.3607),
           (-0.852, 0.3397)]
BUTT_FIELD = [(-0.862, -0.240), (-0.900, -0.240), (-0.900, -0.228), (-0.912, -0.228), (-0.912, -0.216),
              (-0.922, -0.216), (-0.922, 0.270), (-0.908, 0.284), (-0.862, 0.284), (-0.850, 0.272),
              (-0.850, -0.228)]
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(butt, f"AR_MarqueeSeat_{label}", MARQUEE, 0.074 * sign, 0.12 * sign, role=DARK)
    # The light is 0.0025 bigger than its seat (edges buried) and its top rakes a little flatter.
    side(f"AR_Marquee_{label}", [(-0.8495, 0.3155), (-0.9205, 0.3155), (-0.9305, 0.3255), (-0.9305, 0.3515),
                                (-0.9145, 0.3632), (-0.8495, 0.3422)], 0.070 * sign, 0.0785 * sign, CYAN)
    recess(butt, f"AR_ButtField_{label}", BUTT_FIELD, 0.076 * sign, 0.12 * sign, role=PANEL)
    side(f"AR_ButtStripe_{label}", [(-0.914, -0.150), (-0.892, -0.150), (-0.866, 0.040), (-0.888, 0.040)],
         0.073 * sign, 0.080 * sign, MAGENTA)
    side(f"AR_ButtLine_{label}", [(-0.884, -0.150), (-0.875, -0.150), (-0.853, 0.010), (-0.862, 0.010)],
         0.073 * sign, 0.080 * sign, CYAN)

# ---------------------------------------------------------------- muzzle collar
# A stepped eight-sided collar over the barrel's end (now 2.790, buried 0.038): rear step, a light-ring
# groove with the cyan ring (ends buried in the groove walls), the main section, a stepped nose and a
# bore. It starts 0.018 ahead of the front bead (2.734) and stays 0.027 over the tube cap (top .277).
# The Muzzle locator (2.832) sits in the bore mouth (2.834).
collar = prism_along("AR_MuzzleCollar", (2.752, 0, 0.369), (1, 0, 0), [
    (0.000, 0.060), (0.006, 0.067), (0.024, 0.067), (0.024, 0.0625), (0.046, 0.0625), (0.046, 0.070),
    (0.070, 0.070), (0.076, 0.064), (0.082, 0.064), (0.082, 0.040), (0.056, 0.040),
], METAL)
prism_along("AR_BrakeLight", (2.773, 0, 0.369), (1, 0, 0), [(0, 0.065), (0.028, 0.065)], CYAN)["flat_group"] = "ARBrakeLight"


# ---------------------------------------------------------------- sight line check
# noAds gun: still keep the notch-to-bead line clear (rear notch top ~ z .466, bead ~ .465).
def sight_line_hits():
    depsgraph = bpy.context.evaluated_depsgraph_get()
    bpy.context.view_layer.update()
    hits = set()
    eye = Vector((-0.20, 0, 0.466))
    for dy, dz in ((0, 0), (0.012, 0), (-0.012, 0), (0, 0.012), (0, -0.006)):
        origin = eye + Vector((0, dy, dz))
        direction = (Vector((2.62, 0, 0.466)) - eye).normalized()
        hit, location, _n, _i, obj, _m = scene.ray_cast(depsgraph, origin, direction, distance=2.9)
        if hit and obj.name.startswith("AR_"):
            hits.add(obj.name)
    return sorted(hits)


result = finish_master(deck)
result["gap_moves"] = gap_moves
result["sight_line_new_hits"] = sight_line_hits()
