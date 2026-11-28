"""Arcade Mauler (Odin): the belt-fed machine gun as a cabinet. An L-shaped control deck sits in a seat cut
into the receiver's left face (the big first-person surface): a joystick and three buttons on a strip over
the charging slot, then a pixel screen ahead of it,
a coin door on the right of the feed section, side-art fields on both sides of the handguard with lit edge
trim, a side-art field on both faces of the ammo box (bone AmmoBox) with a flange that hides the box-to-gun
slot, stock top-bar art, a cabinet butt with marquee lights, and a stepped eight-sided brake with a light ring.

Run in the live Blender MCP session with the stock
art-source/weapons/RemasterV2/Odin/Odin_RemasterV2_v05.blend open:
    exec(open("tools/blender/arcade/15_odin.py").read(), {"VERSION": "v01"})
Left (+y) is the player-facing side. Stock sights, rig, locators and actions are kept. The stock CharmLoop is
left UNSKINNED (stock materials, not dressed or hidden): the owner moved the Odin's charm point in Studio to
Blender (1.18, 0.126, 0.435), so the install keeps the Studio ring; every Arcade part stays 0.09+ clear of it.
Stock measurements (2026-11-27, ray-cast depth maps and swept clips, Root-relative):
  main receiver (closed island) x -.168/.788, side face y .100 (z .166-.546, chamfers below and above),
  panel-line groove z .414-.424, top groove z .492-.518 (x .14-.53), rail x -.10/.78 on the top (.571);
  charging slot (left) x -.116/.35, z .306-.364; the knob (y to .158) runs back to x -.07 (Draw);
  ejection port (right) x .34-.59, z .314-.386; pins at (0, .24), (.65, .24) both sides, (1.40, .40) both
  sides; rear cap x -.28/-.157 with Neon squares; feed section (closed island) x .788-1.452, z .133-.49,
  belt window on the left x .79-1.06, z .135-.43; stock side plates (open) x 1.102-1.855, z .157-.35,
  y .114 with Neon chevrons; handguard (closed) x 1.44-2.272, face .100, bottom .175 with a 45 degree
  chamfer to .196, groove z .42-.428, a dark pocket (floor .088) x 1.856-2.10, z .278-.344, lug below
  x 1.855-2.03; CharmLoop (stock, Blender) x 2.119-2.151, z .178-.22; barrel r .08 at z .371, x 2.26-3.03;
  front sight block x 2.349-2.496; barrel ring 2.496-2.604; muzzle device x 3.027-3.364 (Muzzle 3.3635);
  stock body x -.987/-.378 (face .072, top bar z .27-.45 over a dark triangle), adapter -.385/-.273,
  butt pad x -1.2425/-.9625 (y .082); ammo box x .577-1.312, y .156 (recessed panel floor .148 with X
  ridges .154), lid z .065-.122 (y .162), handle (left) x .735-.98, z -.06/.02, y to .173; the box drops
  straight down in the reloads (pitch up to 4 degrees) and overshoots +.007 at the top; the belt reaches
  y .104. The feed cover (bone FeedCover) opens 77 degrees about x .805, z .56.
  ADS: adsDistance .39, adsFov 70 (Config/Weapons); eye x -.4665, z .6503 (= Odin_FP_ADS).
"""

from pathlib import Path

import bpy

GUN = "Odin"
VERSION = globals().get("VERSION", "v01")
exec((Path(bpy.data.filepath).parents[4] / "tools/blender/arcade/arcade_lib.py").read_text(encoding="utf-8"))

CHARM = Vector((1.18, 0.126, 0.435))  # the owner's moved Studio charm point (Blender coordinates)


def near(value, target, tolerance=0.003):
    return abs(value - target) < tolerance


def is_island(island, lo, hi):
    return all(near(limits(island, a)[0], lo[a]) and near(limits(island, a)[1], hi[a]) for a in range(3))


MAIN = ((-0.168, -0.1, 0.157), (0.788, 0.1, 0.571))
HANDGUARD = ((1.44, -0.1, 0.175), (2.272, 0.1, 0.501))

# ---------------------------------------------------------------- retained stock
# The handguard is copied out as its own closed part for the field cuts; the main receiver keeps its stock
# name (v02: as an AR_ copy the audit counted the stock bolt, trigger, handle and feed cover touching it,
# which they do in the stock gun). The side plates and their Neon chevrons go (the Arcade fields replace
# them). The CharmLoop is deliberately NOT dressed.
hand = dress("Receiver", copy_name="AR_Handguard", keep=lambda i: is_island(i, *HANDGUARD))
receiver = dress("Receiver", keep=lambda i: not (is_island(i, *HANDGUARD)
                                                  or (near(limits(i, 0)[0], 1.102) and abs(limits(i, 1)[0]) > 0.09)))
receiver_main = receiver
dress("Neon", keep=lambda i: limits(i, 0)[1] < 0.5)
dress("Barrel", keep=lambda i: limits(i, 0)[0] < 3.02)
dress("Stock", keep=lambda i: limits(i, 0)[0] > -1.2)
dress("Pins", keep=lambda i: not (0.63 < limits(i, 0)[0] < 0.64 and limits(i, 1)[0] > 0))
for name in ("Sights", "Grip", "FeedCover", "FeedBelt", "ChargingHandle", "Bolt", "Trigger"):
    dress(name)
dress("AmmoBox", slots={"Panel": BODY})
# The stock's flush pairs (belt links: Metal faces on Accent; feed cover: a Body face on Dark): lift them
# 0.004 in the build, the same lift the flat export would make.
_flat = {}
exec((ROOT / "tools/blender/export_roblox_flat.py").read_text(encoding="utf-8"), _flat)
for _name in ("FeedBelt", "FeedCover"):
    _flat["resolve_coplanar"]([native(_name)])


def nudge(obj, box, pick, delta):
    """Move the vertices pick(world point) selects, only in the islands whose world bounds match box."""
    matrix = obj.matrix_world
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.transform(matrix)
    moved = 0
    for island in list(components(bm)):
        if box is not None and not is_island(island, *box):
            continue
        for vert in island:
            if pick(vert.co):
                vert.co += Vector(delta)
                moved += 1
    bm.transform(matrix.inverted())
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    return moved


# Stock join fixes (owner, 2026-11-27: "no gaps anywhere"; every join buried 0.02+). Each line names the
# stock overlap it replaces. Feet and posts that the ADS eye sees above their bases are unchanged.
moves = {
    # handguard 0.012 over the feed section -> its rear runs 0.032 in
    "handguard_rear": nudge(hand, None, lambda p: p.x < 1.445, (-0.020, 0, 0)),
    # feed section only touched the main receiver (0.000) -> its rear runs 0.02 in
    "feed_section_rear": nudge(receiver, ((0.788, -0.1, 0.133), (1.452, 0.1, 0.49)), lambda p: p.x < 0.79, (-0.020, 0, 0)),
    # rear cap 0.011 over the receiver -> 0.021 (front at -.147, 0.005 behind the deck seat's rear wall)
    "rear_cap_front": nudge(receiver, ((-0.28, -0.094, 0.192), (-0.157, 0.094, 0.565)), lambda p: p.x > -0.16, (0.010, 0, 0)),
    # trigger guard 0.003 into the receiver's underside -> 0.023
    "trigger_guard_top": nudge(receiver, ((0.175, -0.032, 0.0), (0.455, 0.032, 0.16)), lambda p: p.z > 0.155, (0, 0, 0.020)),
    # rail 0.001 on the receiver top -> 0.021
    "rail_foot": nudge(receiver, ((-0.1, -0.036, 0.57), (0.78, 0.036, 0.59)), lambda p: p.z < 0.575, (0, 0, -0.020)),
    # rail teeth 0.001 on the rail -> 0.02
    "rail_teeth": nudge(receiver, None, lambda p: abs(p.z - 0.589) < 0.0006 and abs(p.y) > 0.037, (0, 0, -0.019)),
    # under-handguard lug 0.004 -> 0.024
    "lug_top": nudge(receiver, ((1.855, -0.014, 0.09), (2.03, 0.014, 0.179)), lambda p: p.z > 0.17, (0, 0, 0.020)),
    # grip top 0.007 into the receiver -> 0.027
    "grip_top": nudge(native("Grip"), None, lambda p: p.z > 0.155, (0, 0, 0.020)),
    # pins 0.003 in their faces -> 0.023 (inner ends pushed in)
    "pins_left": nudge(native("Pins"), None, lambda p: 0 < p.y < 0.0985, (0, -0.020, 0)),
    "pins_right": nudge(native("Pins"), None, lambda p: -0.0985 < p.y < 0, (0, 0.020, 0)),
    # stock adapter 0.007 in the stock body and 0.007 in the rear cap -> 0.027 / 0.037
    "adapter_front": nudge(native("Stock"), ((-0.385, -0.074, 0.168), (-0.273, 0.074, 0.472)), lambda p: p.x < -0.38, (-0.020, 0, 0)),
    "adapter_rear": nudge(native("Stock"), ((-0.385 - 0.020, -0.074, 0.168), (-0.273, 0.074, 0.472)), lambda p: p.x > -0.28, (0.023, 0, 0)),
    # barrel 0.012 in the handguard -> 0.032; barrel ring touching the sight block -> 0.02 in
    "barrel_rear": nudge(native("Barrel"), ((2.26, -0.078, 0.291), (3.03, 0.078, 0.451)), lambda p: p.x < 2.265, (-0.020, 0, 0)),
    "barrel_ring_rear": nudge(native("Barrel"), ((2.496, -0.097, 0.271), (2.604, 0.097, 0.471)), lambda p: p.x < 2.5, (-0.020, 0, 0)),
    # front sight: post base 0.002 on the block, hood 0.002 and post 0.003 in the base -> 0.02 deeper (hidden)
    "front_sight_base": nudge(native("Sights"), ((2.383, -0.04, 0.505), (2.482, 0.04, 0.6)), lambda p: p.z < 0.51, (0, 0, -0.020)),
    "front_sight_hood": nudge(native("Sights"), ((2.408, -0.038, 0.598), (2.457, 0.038, 0.68)), lambda p: p.z < 0.6, (0, 0, -0.020)),
    "front_sight_post": nudge(native("Sights"), ((2.427, -0.006, 0.597), (2.438, 0.006, 0.65)), lambda p: p.z < 0.6, (0, 0, -0.020)),
    # the post's Neon dot sat 0.001 on the post's rear face -> its front runs 0.007 into the post
    "front_sight_dot": nudge(native("Sights"), ((2.424, -0.003, 0.631), (2.428, 0.003, 0.638)), lambda p: p.x > 2.426, (0.006, 0, 0)),
    # rear sight ring feet 0.007 in the receiver top -> 0.027
    "rear_sight_feet": nudge(native("Sights"), ((0.011, -0.062, 0.564), (0.031, 0.062, 0.722)), lambda p: p.z < 0.57, (0, 0, -0.020)),
}
# Rear-cap Neon squares sat 0.0005 off their pocket floor: their backs run 0.0075 into the cap, per side.
moves["cap_neon"] = (nudge(native("Neon"), None, lambda p: 0 < p.y < 0.0895, (0, -0.0075, 0))
                     + nudge(native("Neon"), None, lambda p: -0.0895 < p.y < 0, (0, 0.0075, 0)))


def crect(x0, z0, x1, z1, c):
    return [(x0 + c, z0), (x1 - c, z0), (x1, z0 + c), (x1, z1 - c),
            (x1 - c, z1), (x0 + c, z1), (x0, z1 - c), (x0, z0 + c)]


def square(x, z, size):
    return [(x - size / 2, z - size / 2), (x + size / 2, z - size / 2),
            (x + size / 2, z + size / 2), (x - size / 2, z + size / 2)]


def inset(outline, d):
    """Offset an (x, z) outline inward by d (mitred corners)."""
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


def slab(name, outline, near_y, far_y, role, chamfer, *, bone="Root"):
    """A plate whose back (near) is buried: only the exposed front edge gets the flat chamfer."""
    step = chamfer if far_y > near_y else -chamfer
    return loft(name, [[(x, near_y, z) for x, z in outline], [(x, far_y - step, z) for x, z in outline],
                       [(x, far_y, z) for x, z in inset(outline, chamfer)]], role, bone=bone)


def art(label, sign, near_y, band, line, star_at, star_r, trail, *, bone="Root"):
    """Line-language side art standing 0.004 proud of its floor: band, line, starburst, pixel trail."""
    far_y = near_y + 0.007
    side(f"AR_{label}Stripe", band, near_y * sign, far_y * sign, MAGENTA, bone=bone)
    side(f"AR_{label}Line", line, near_y * sign, far_y * sign, CYAN, bone=bone)
    if star_at:
        plate(f"AR_{label}Star", star(*star_at, star_r, star_r * 0.42), near_y * sign, far_y * sign, YELLOW, bone=bone)
    for k, (x, z, size) in enumerate(trail):
        side(f"AR_{label}Pixel_{k + 1}", square(x, z, size), near_y * sign, far_y * sign, MAGENTA, bone=bone)


# ---------------------------------------------------------------- left: cabinet deck
# An L-shaped seat cut 0.012 into the receiver's left face (floor .088): a control strip over the charging
# slot (x -.142 to .37, z .380-.482, 0.016 above the slot) and a screen block ahead of it (to x .758, down
# to z .200) whose rear edge rakes down clear of the slot's front end. The plate sits 0.008 inside the seat
# walls so a dark reveal runs round it: back .080 (buried), face .110 (0.010 proud of the receiver face).
# Rear to front: the joystick and three buttons rising toward the muzzle on the strip (the held camera sees
# it large), then the pixel screen in its bezel with a cyan light pipe over it. Every part is under the
# receiver's top-left edge as the ADS eye sees it (behind the rear cap for the joystick).
F = 0.110
SEAT = [(-0.130, 0.380), (0.370, 0.380), (0.438, 0.212), (0.450, 0.200), (0.746, 0.200), (0.758, 0.212),
        (0.758, 0.470), (0.746, 0.482), (-0.130, 0.482), (-0.142, 0.470), (-0.142, 0.392)]
recess(receiver_main, "AR_DeckSeat", SEAT, 0.088, 0.15, role=DARK)
deck = slab("AR_ControlDeck_Left", inset(SEAT, 0.008), 0.080, F, PANEL, 0.0018)

STICK_X, STICK_Z = -0.070, 0.429
prism_along("AR_JoystickWasher", (STICK_X, F - 0.004, STICK_Z), (0, 1, 0), [(0, 0.022), (0.009, 0.0185)], DARK)
prism_along("AR_JoystickShaft", (STICK_X, F + 0.002, STICK_Z), (0, 1, 0), [(0, 0.0065), (0.034, 0.0065)], METAL)
stick_ball = prism_along("AR_JoystickBall", (STICK_X, F + 0.002, STICK_Z), (0, 1, 0), [
    (0.028, 0.009), (0.035, 0.019), (0.047, 0.019), (0.054, 0.009),
], BTN_MAGENTA)
stick_ball["flat_group"] = "ARStickBall"
for i, (x, z, role) in enumerate(((0.035, 0.423, BTN_CYAN), (0.115, 0.429, BTN_YELLOW), (0.195, 0.435, BTN_MAGENTA))):
    prism_along(f"AR_ButtonCollar_{i + 1}", (x, F - 0.004, z), (0, 1, 0), [(0, 0.028), (0.010, 0.0245)], DARK)
    button = prism_along(f"AR_Button_{i + 1}", (x, F + 0.002, z), (0, 1, 0),
                         [(0, 0.022), (0.016, 0.022), (0.021, 0.0155)], role)
    button["flat_group"] = f"ARButton{i + 1}"

inner = crect(0.482, 0.248, 0.726, 0.440, 0.010)
outer = crect(0.470, 0.236, 0.738, 0.452, 0.016)
loft("AR_ScreenBezel_Left", [
    [(x, F - 0.004, z) for x, z in outer], [(x, F + 0.010, z) for x, z in outer],
    [(x, F + 0.010, z) for x, z in inner], [(x, F - 0.004, z) for x, z in inner],
], DARK, loop=True)
plate("AR_Screen_Left", crect(0.480, 0.246, 0.728, 0.442, 0.010), F - 0.003, F + 0.003, SCREEN)["flat_group"] = "ARScreen"
# Pixel scene (0.0085 pixels, as on every Arcade gun): the ship low left firing toward the muzzle, a cyan
# invader (the blip) high right, three yellow stars.
PX = 0.0085
SX, SZ = 0.496, 0.290
SHIP = {(0, 4), (1, 4), (0, 3), (1, 3), (2, 3), (3, 3), (1, 2), (2, 2), (3, 2), (4, 2), (5, 2), (6, 2),
        (0, 1), (1, 1), (2, 1), (3, 1), (0, 0), (1, 0)}
pixel_solid("AR_ScreenShip_Left", SHIP, SX, SZ, PX, F + 0.002, F + 0.007, CYAN)["flat_group"] = "ARScreenShip"
pixel_solid("AR_ScreenShot_Left", {(0, 0), (1, 0), (2, 0)}, SX + 8 * PX, SZ + 2 * PX, PX,
            F + 0.002, F + 0.007, MAGENTA)["flat_group"] = "ARScreenShot"
# No two cells meet only at a corner (v01's did: four non-manifold edges).
INVADER = {(1, 3), (3, 3), (0, 2), (1, 2), (2, 2), (3, 2), (4, 2), (0, 1), (1, 1), (3, 1), (4, 1), (0, 0), (4, 0)}
pixel_solid("AR_ScreenInvader_Left", INVADER, 0.662, 0.388, PX, F + 0.002, F + 0.007, CYAN)["flat_group"] = "ARScreenBlip"
PLUS = {(1, 0), (0, 1), (1, 1), (2, 1), (1, 2)}
pixel_solid("AR_ScreenStarA_Left", PLUS, 0.590, 0.396, PX, F + 0.002, F + 0.007, YELLOW)["flat_group"] = "ARScreenStars"
pixel_solid("AR_ScreenStarB_Left", {(0, 0)}, 0.512, 0.410, PX, F + 0.002, F + 0.007, YELLOW)["flat_group"] = "ARScreenStars"
pixel_solid("AR_ScreenStarC_Left", {(0, 0)}, 0.700, 0.272, PX, F + 0.002, F + 0.007, YELLOW)["flat_group"] = "ARScreenStars"
side("AR_DeckLight_Left", [(0.474, 0.4585), (0.734, 0.4585), (0.728, 0.4655), (0.480, 0.4655)],
     F - 0.003, F + 0.004, CYAN)["flat_group"] = "ARDeckLight"

# ---------------------------------------------------------------- right: coin door on the feed section
coin = slab("AR_CoinDoor_Right", crect(0.960, 0.215, 1.300, 0.425, 0.014), -0.090, -0.110, METAL, 0.0018)
for i, x in enumerate((1.040, 1.140)):
    block = slab(f"AR_CoinEntry_{i + 1}", crect(x - 0.030, 0.282, x + 0.030, 0.350, 0.006),
                 -0.106, -0.122, ACCENT, 0.0015)
    recess(block, f"AR_CoinSlotCut_{i + 1}", crect(x - 0.004, 0.296, x + 0.004, 0.336, 0.002),
           -0.116, -0.142, role=DARK)
    side(f"AR_CoinSlotLight_{i + 1}", crect(x - 0.0055, 0.295, x + 0.0055, 0.337, 0.002), -0.112, -0.120, YELLOW)
side("AR_CoinStripe_Right", [(1.195, 0.232), (1.225, 0.232), (1.273, 0.408), (1.243, 0.408)], -0.107, -0.114, MAGENTA)

# ---------------------------------------------------------------- handguard fields and lit trim
# Fields start at x 1.48 (0.30 ahead of the moved charm point) and stop before the stock CharmLoop (x 2.119):
# a raked front-bottom corner keeps 0.04 over it. The cut (floor .084) swallows the stock dark pocket.
HFIELD = [(1.480, 0.236), (1.494, 0.236), (1.494, 0.222), (1.508, 0.222), (1.508, 0.208), (2.050, 0.208),
          (2.110, 0.262), (2.110, 0.392), (2.096, 0.404), (1.494, 0.404), (1.480, 0.390)]
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(hand, f"AR_HandguardField_{label}", HFIELD, 0.084 * sign, 0.15 * sign, role=PANEL)
    art(f"Handguard{label}", sign, 0.081,
        [(1.700, 0.214), (1.740, 0.214), (1.800, 0.398), (1.760, 0.398)],
        [(1.752, 0.214), (1.764, 0.214), (1.824, 0.398), (1.812, 0.398)],
        (1.960, 0.306), 0.040,
        [(1.712, 0.306, 0.012), (1.684, 0.306, 0.018), (1.648, 0.306, 0.024)])
    # Cabinet T-molding: a lit bar half-buried along the 45 degree lower chamfer.
    trim = prism_along(f"AR_HandguardTrim_{label}", (1.500, 0.090 * sign, 0.186), (1, 0, 0),
                       [(0, 0.003), (0.008, 0.0068), (0.582, 0.0068), (0.590, 0.003)], MAGENTA)
    trim["flat_group"] = "ARTrim"

# ---------------------------------------------------------------- ammo box: side-art fields and flange
# A violet field plate over each recessed box panel (back .146, buried in the rim; face .1615), with a
# pixel-stepped top-rear corner; the stock handle stands through it. The art keeps below the handle.
BOXF = [(0.640, -0.338), (1.252, -0.338), (1.252, 0.020), (1.238, 0.034), (0.668, 0.034), (0.668, 0.020),
        (0.654, 0.020), (0.654, 0.006), (0.640, 0.006)]
for sign, label in ((1, "Left"), (-1, "Right")):
    slab(f"AR_BoxField_{label}", BOXF, 0.146 * sign, 0.1615 * sign, PANEL, 0.0018, bone="AmmoBox")
    art(f"Box{label}", sign, 0.1585,
        [(0.800, -0.326), (0.850, -0.326), (0.960, -0.080), (0.910, -0.080)],
        [(0.866, -0.326), (0.880, -0.326), (0.990, -0.080), (0.976, -0.080)],
        (1.130, -0.205), 0.055,
        [(0.836, -0.205, 0.014), (0.806, -0.205, 0.020), (0.770, -0.205, 0.026)], bone="AmmoBox")
    # Flange: a dark wall standing on the lid outside the receiver's sides (0.008 clear), so the stock
    # 0.011-0.035 running clearance between the lid and the gun no longer shows from the side.
    side(f"AR_BoxFlange_{label}", [(0.585, 0.100), (1.305, 0.100), (1.305, 0.160), (1.293, 0.172),
                                   (0.597, 0.172), (0.585, 0.160)], 0.108 * sign, 0.118 * sign, DARK, bone="AmmoBox")
side("AR_BoxFlange_Rear", [(0.585, 0.100), (0.597, 0.100), (0.597, 0.145), (0.585, 0.145)],
     -0.113, 0.113, DARK, bone="AmmoBox")

# ---------------------------------------------------------------- stock top-bar art
# The bar's top falls from z .4505 (x -.382) to .395 (x -.894) before the rear kick, and the window's top
# is z .27: the art keeps 0.018+ inside both (v02's band and line ran 0.015 over the falling top edge).
for sign, label in ((1, "Left"), (-1, "Right")):
    art(f"Stock{label}", sign, 0.068,
        [(-0.770, 0.288), (-0.742, 0.288), (-0.704, 0.392), (-0.732, 0.392)],
        [(-0.730, 0.288), (-0.718, 0.288), (-0.680, 0.392), (-0.692, 0.392)],
        None, 0, [(-0.763, 0.340, 0.010), (-0.784, 0.340, 0.014), (-0.810, 0.340, 0.018)])

# ---------------------------------------------------------------- cabinet butt
# Front swallows the stock body's rear end (x -.987) by 0.047; 0.018 proud of the body sides; raked marquee
# top; stepped rear; a flat 0.006 chamfer round both side faces.
BUTT = [(-0.940, 0.502), (-1.160, 0.536), (-1.195, 0.518), (-1.205, 0.470), (-1.185, 0.452),
        (-1.180, 0.240), (-1.205, 0.222), (-1.205, 0.172), (-1.185, 0.155), (-1.185, -0.190),
        (-1.160, -0.244), (-0.965, -0.244), (-0.940, -0.215)]
BUTT_IN = inset(BUTT, 0.006)
butt = loft("AR_CabinetButt", [[(x, y, z) for x, z in ring] for y, ring in (
    (-0.096, BUTT_IN), (-0.090, BUTT), (0.090, BUTT), (0.096, BUTT_IN))], BODY)
MARQUEE = [(-0.990, 0.462), (-1.150, 0.462), (-1.162, 0.474), (-1.162, 0.512), (-1.150, 0.524), (-0.990, 0.500)]
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(butt, f"AR_MarqueeSeat_{label}", MARQUEE, 0.086 * sign, 0.12 * sign, role=DARK)
    side(f"AR_Marquee_{label}", [(-0.9875, 0.4595), (-1.1525, 0.4595), (-1.1645, 0.4715), (-1.1645, 0.5135),
                                (-1.1515, 0.5260), (-0.9875, 0.5010)], 0.082 * sign, 0.0905 * sign, CYAN)

# ---------------------------------------------------------------- stepped brake
# Rear collar over the barrel's end (0.025 overlap), a light-ring groove with the cyan ring (ends buried in
# the groove walls), a ported main section, a stepped nose and a bore; Muzzle (x 3.3635) sits in the bore.
AXIS_Z = 0.371
brake = prism_along("AR_Brake", (3.005, 0, AXIS_Z), (1, 0, 0), [
    (0.000, 0.084), (0.012, 0.098), (0.062, 0.098), (0.062, 0.090), (0.104, 0.090), (0.104, 0.104),
    (0.296, 0.104), (0.320, 0.092), (0.344, 0.084), (0.360, 0.084), (0.360, 0.046), (0.330, 0.046),
], METAL)
for k, x in enumerate((3.150, 3.215)):
    recess(brake, f"AR_BrakePort_{k + 1}", crect(x, AXIS_Z - 0.017, x + 0.036, AXIS_Z + 0.017, 0.006), -0.2, 0.2, role=DARK)
prism_along("AR_BrakeLight", (3.065, 0, AXIS_Z), (1, 0, 0), [(0, 0.0955), (0.046, 0.0955)], CYAN)["flat_group"] = "ARBrakeLight"

# ---------------------------------------------------------------- charm clearance check
bpy.context.view_layer.update()
_deps = bpy.context.evaluated_depsgraph_get()
charm_clearance = 9.0
for _obj in shells.objects:
    if _obj.type != "MESH" or _obj.parent_bone != "Root":
        continue
    _mesh = _obj.evaluated_get(_deps).to_mesh()
    for _v in _mesh.vertices:
        p = _obj.matrix_world @ _v.co
        # distance to the charm's swing zone: a 0.09 sphere round the point plus the column below it
        dz = max(0.0, p.z - CHARM.z)
        charm_clearance = min(charm_clearance, math.sqrt((p.x - CHARM.x) ** 2 + (p.y - CHARM.y) ** 2 + dz ** 2))
    _obj.evaluated_get(_deps).to_mesh_clear()

# DRY=True (exec globals) builds in the open stock file without saving, for a look before the version is cut.
result = {"dry": True} if globals().get("DRY") else finish_master(deck)
result["stock_join_moves"] = moves
result["charm_clearance"] = round(charm_clearance, 4)
