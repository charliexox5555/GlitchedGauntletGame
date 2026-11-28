"""Arcade Ghost (Hush, suppressed pistol): a cabinet deck on the fixed frame's left band (joystick, three
buttons, pixel screen, light pipe), a coin door on the right grip panel, a side-art field on the left of
the slide (with a pixel plus-star), a lit trim in the right dust-cover groove, a stepped eight-sided can with
a cyan light ring in place of the stock round suppressor (Root bone, as in stock), and a baseplate stripe.

Run in a live Blender session with the stock
art-source/weapons/RemasterV2/Ghost/Ghost_RemasterV2_v05.blend open:
    exec(open("tools/blender/arcade/24_ghost.py").read(), {"VERSION": "v01"})
Left (+y) is the player-facing side. Stock rig, locators, sights and actions are kept. The Ghost's charm
point was not moved: the stock CharmLoop (left dust-cover groove, x .844-.876) is kept and dressed in the
line's colours, and every Arcade part stays 0.09+ clear of the CharmPoint (0.86, 0.064, 0.16).
Stock measurements (2026-11-27, ray-cast depth maps, rest pose):
  frame left/right face y .062, x -.25/1.118, top z .229 (under the slide); visible band above the grip
  from z ~.14 (x -.2) / .125 (x 0) / .11 (x .2); slide catch x .337-.47, z .186-.222 (left); takedown lever
  x .52-.60, z .186-.222 (left); dust-cover underside z .168 for x .72-1.118, groove y .054 at
  z .1825-.195 for x .78-1.06 (both sides). Trigger guard island x .28-.70, z -.039/.11.
  slide x -.213/1.126, flat side y .066 from z .235 to .362, top chamfer to y .040 at z .39; rear
  serrations x -.07/-.01; SlideNeon x .909-1.006, z .272-.336; sights: rear x -.141/-.059 top z .43,
  front x 1.012-1.072 top z .424 (iron line). Slide wall is solid to the barrel channel (y < .03).
  grip side y .064, right recess panel y .060 (x -.12/.105 at z -.10, slanted ~0.25 x per z), top z .139;
  magazine body y +-.045; baseplate x -.261/.108, z -.462/-.394, face y .067 with a groove y .063 at
  z -.4225/-.4175. Stock Suppressor (Root) holds the barrel (x .54-1.13, r .029, centre z .2965), the
  chamber block (x .333-.505) and the can: collar r .069 x 1.118-1.167, step r .086 to 1.215, can r .099
  x 1.205-2.054, ring r .102 at x 1.40-1.412, end disc at 2.052-2.057. Muzzle locator (2.054, 0, .296).
"""

from pathlib import Path

import bpy

GUN = "Ghost"
VERSION = globals().get("VERSION", "v01")
exec((Path(bpy.data.filepath).parents[4] / "tools/blender/arcade/arcade_lib.py").read_text(encoding="utf-8"))

# ---------------------------------------------------------------- retained stock (charm loop dressed)
for name in ("SlideNeon", "Frame", "Pins", "Trigger", "SlideCatch", "MagRelease", "CharmLoop", "Grip", "Mag"):
    dress(name)
# As on the Classic: the unchanged stock sights move to their own object on the Slide bone so the exact
# boolean that cuts the side-art field never unions them into the body.
dress("Slide", copy_name="AR_SlideSights", keep=lambda island: limits(island, 0)[1] - limits(island, 0)[0] < 1.0)
SLIDE = dress("Slide", keep=lambda island: limits(island, 0)[1] - limits(island, 0)[0] > 1.0)
# The stock Suppressor object keeps the barrel and chamber block; its round can islands are replaced.
BARREL = dress("Suppressor", keep=lambda island: limits(island, 0)[1] < 1.14)


def lift_faces(obj, normal, distance):
    """Push the faces of a retained part that face `normal` (world) out along it (stock coplanar fix)."""
    normal = Vector(normal).normalized()
    matrix = obj.matrix_world
    inverse = matrix.inverted()
    turn = matrix.to_3x3().inverted().transposed()
    picked = {i for p in obj.data.polygons if (turn @ p.normal).normalized().dot(normal) > 0.999 for i in p.vertices}
    for i in picked:
        vertex = obj.data.vertices[i]
        vertex.co = inverse @ (matrix @ vertex.co + normal * distance)
    obj.data.update()
    return len(picked)


# Stock coplanar pair: the four slanted SlideNeon strips in the front serrations sit flush with the
# serration faces (normal (0.883, 0, -0.469)), so they z-fight. Their front faces now stand 0.004 proud.
NEON_FIX = lift_faces(native("SlideNeon"), (0.883, 0, -0.469), 0.004)


def hex_along(name, origin, axis, profile, roles, *, bone="Root"):
    """prism_along with six facets: the pistol's small round parts."""
    origin = Vector(origin)
    axis = Vector(axis).normalized()
    helper = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))
    u = axis.cross(helper).normalized()
    v = axis.cross(u).normalized()
    sections = [[tuple(origin + axis * t + u * a + v * b) for a, b in polygon(0, 0, radius, 6, 0)]
                for t, radius in profile]
    return loft(name, sections, roles, bone=bone)


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


A8 = math.cos(math.pi / 8)  # apothem / circumradius of the flat-topped octagon


def tube(name, z, outer, inner, roles, *, bone):
    """An eight-sided ring along +x with a bore: outer (x, apothem) back to front, inner front to back.
    Faces sit flat on top, bottom and both sides (apothem = the stock radius keeps the silhouette)."""
    sections = [[(x, a / A8 * math.cos(t), z + a / A8 * math.sin(t)) for t in
                 (math.pi / 8 + math.pi / 4 * i for i in range(8))] for x, a in (*outer, *inner)]
    return loft(name, sections, roles, bone=bone, loop=True)


# ---------------------------------------------------------------- left: cabinet deck (fixed frame)
# The Classic deck scaled 0.88 onto the Ghost's lower frame band (face .062; band z .14-.229 above the
# grip, slide bottom .229). Back y .054 (buried .008), face .074. Rear x -.091 is .008 above the grip top;
# front x .272 stops .065 behind the slide catch (x .337). Three buttons fit at this scale.
S = 0.88


def T(x, z):
    return (0.09 + S * (x - 0.056), 0.178 + S * (z - 0.224))


def TL(points):
    return [T(x, z) for x, z in points]


DECK = TL([(-0.150, 0.182), (0.248, 0.182), (0.262, 0.196), (0.262, 0.258), (0.254, 0.266),
           (-0.134, 0.266), (-0.150, 0.250)])
deck = slab("AR_ControlDeck_Left", DECK, 0.054, 0.074, PANEL, 0.0015)

sx, sz = T(-0.112, 0.224)
hex_along("AR_JoystickWasher", (sx, 0.070, sz), (0, 1, 0), [(0, 0.018 * S), (0.007, 0.015 * S)], DARK)
hex_along("AR_JoystickShaft", (sx, 0.074, sz), (0, 1, 0), [(0, 0.0045), (0.022, 0.0045)], METAL)
stick_ball = prism_along("AR_JoystickBall", (sx, 0.074, sz), (0, 1, 0), [
    (0.016, 0.0055), (0.023, 0.011), (0.032, 0.0055),
], BTN_MAGENTA)
stick_ball["flat_group"] = "ARStickBall"
for i, (x, z, role) in enumerate(((-0.066, 0.212, BTN_CYAN), (-0.030, 0.220, BTN_YELLOW),
                                  (0.006, 0.228, BTN_MAGENTA))):
    bx, bz = T(x, z)
    hex_along(f"AR_ButtonCollar_{i + 1}", (bx, 0.070, bz), (0, 1, 0),
              [(0, 0.0155 * S), (0.008, 0.0135 * S)], DARK)
    button = prism_along(f"AR_Button_{i + 1}", (bx, 0.074, bz), (0, 1, 0),
                         [(0, 0.0115 * S), (0.011, 0.0115 * S), (0.015, 0.0075 * S)], role)
    button["flat_group"] = f"ARButton{i + 1}"

# Pixel screen: bezel ring, glowing screen floor, pixel graphic standing 0.004 proud.
inner = TL(crect(0.040, 0.199, 0.242, 0.249, 0.006))
outer = TL(crect(0.030, 0.190, 0.252, 0.258, 0.010))
loft("AR_ScreenBezel_Left", [
    [(x, 0.070, z) for x, z in outer], [(x, 0.084, z) for x, z in outer],
    [(x, 0.084, z) for x, z in inner], [(x, 0.070, z) for x, z in inner],
], DARK, loop=True)
plate("AR_Screen_Left", TL(crect(0.038, 0.197, 0.244, 0.251, 0.006)), 0.071, 0.077, SCREEN)["flat_group"] = "ARScreen"
PX = 0.0055 * S
SX, SZ = T(0.050, 0.2085)
SHIP = {(0, 4), (1, 4), (0, 3), (1, 3), (2, 3), (3, 3), (1, 2), (2, 2), (3, 2), (4, 2), (5, 2), (6, 2),
        (0, 1), (1, 1), (2, 1), (3, 1), (0, 0), (1, 0)}
pixel_solid("AR_ScreenShip_Left", SHIP, SX, SZ, PX, 0.076, 0.081, CYAN)["flat_group"] = "ARScreenShip"
pixel_solid("AR_ScreenShot_Left", {(0, 0), (1, 0), (2, 0)}, SX + 8 * PX, SZ + 2 * PX, PX,
            0.076, 0.081, MAGENTA)["flat_group"] = "ARScreenShot"
PLUS = {(1, 0), (0, 1), (1, 1), (2, 1), (1, 2)}
pixel_solid("AR_ScreenStarA_Left", PLUS, T(0.190, 0)[0], SZ + 2 * PX, PX, 0.076, 0.081, YELLOW)["flat_group"] = "ARScreenStars"
pixel_solid("AR_ScreenStarB_Left", {(0, 0)}, T(0.226, 0)[0], SZ + 1 * PX, PX, 0.076, 0.081, YELLOW)["flat_group"] = "ARScreenStars"
pixel_solid("AR_ScreenStarC_Left", {(0, 0)}, T(0.165, 0)[0], SZ + 5 * PX, PX, 0.076, 0.081, CYAN)["flat_group"] = "ARScreenBlip"

# Cyan light pipe along the deck's top edge over the screen: back buried in the frame (.042), front
# 0.003 behind the deck face; z .211-.2215 (buried .004 into the deck top .215), .0075 under the slide.
p0, p1 = T(0.036, 0)[0], T(0.246, 0)[0]
side("AR_DeckLight_Left", [(p0, 0.2110), (p1, 0.2110), (p1 + 0.005, 0.2215), (p0 + 0.005, 0.2215)],
     0.042, 0.071, CYAN)["flat_group"] = "ARDeckLight"

# ---------------------------------------------------------------- right: coin door (grip panel)
# Seated in the right grip recess (face -.060, border -.064), sheared to the grip's rake (0.25 x per z).
# The back (-.054) stays clear of the magazine body (y -.045) that slides out of the grip in the reloads.
RAKE, ZC = 0.25, -0.115


def shear(points):
    return [(x + RAKE * (z - ZC), z) for x, z in points]


coin = slab("AR_CoinDoor_Right", shear(crect(-0.085, -0.200, 0.065, -0.030, 0.011)), -0.054, -0.070, METAL, 0.0015)
for i, x in enumerate((-0.044, 0.006)):
    side(f"AR_CoinEntry_{i + 1}", shear(crect(x - 0.019, -0.146, x + 0.019, -0.094, 0.005)),
         -0.066, -0.078, ACCENT)
    side(f"AR_CoinSlotLight_{i + 1}", shear([(x - 0.004, -0.136), (x + 0.004, -0.136), (x + 0.004, -0.104),
                                             (x - 0.004, -0.104)]), -0.074, -0.082, YELLOW)
side("AR_CoinStripe_Right", shear([(0.022, -0.190), (0.042, -0.190), (0.058, -0.040), (0.038, -0.040)]),
     -0.066, -0.074, MAGENTA)

# ---------------------------------------------------------------- slide side-art field (rides the slide)
# Recessed 0.006 into the slide's flat left side (.066, z .235-.362) between the rear serrations and the
# SlideNeon (x .909). Decor .057-.064: 0.004 proud of the floor (.060), under the slide face. It never
# meets the frame: everything is above z .252 and the frame tops out at .231 (the slide only slides back).
FIELD = [(0.100, 0.272), (0.110, 0.272), (0.110, 0.262), (0.120, 0.262), (0.120, 0.252),
         (0.780, 0.252), (0.800, 0.272), (0.800, 0.330), (0.782, 0.348), (0.116, 0.348), (0.100, 0.332)]
recess(SLIDE, "AR_SlideField_Left", FIELD, 0.060, 0.15, role=PANEL, bone="Slide")
side("AR_SlideStripe_Left", [(0.500, 0.256), (0.530, 0.256), (0.578, 0.344), (0.548, 0.344)],
     0.057, 0.064, MAGENTA, bone="Slide")
side("AR_SlideLine_Left", [(0.542, 0.256), (0.551, 0.256), (0.599, 0.344), (0.590, 0.344)],
     0.057, 0.064, CYAN, bone="Slide")
plate("AR_SlideStar_Left", star(0.690, 0.300, 0.024, 0.010), 0.057, 0.064, YELLOW, bone="Slide")
for k, (x, size) in enumerate(((0.482, 0.007), (0.462, 0.010), (0.436, 0.013), (0.404, 0.016), (0.366, 0.019))):
    side(f"AR_SlidePixel_Left_{k + 1}", square(x, 0.300, size), 0.057, 0.064, MAGENTA, bone="Slide")
# The line's own motif at the rear of the field (owner, v03: replaces v01-v02's pixel ghost): a yellow
# pixel plus-star with a short magenta pixel trail behind it, all 0.004 proud of the floor.
GP = 0.010
STAR = {(2, 0), (2, 1), (0, 2), (1, 2), (2, 2), (3, 2), (4, 2), (2, 3), (2, 4)}
pixel_solid("AR_SlidePlusStar_Left", STAR, 0.185, 0.275, GP, 0.057, 0.064, YELLOW, bone="Slide")
for k, (x, size) in enumerate(((0.171, 0.009), (0.157, 0.007), (0.146, 0.005))):
    side(f"AR_SlideStarTrail_Left_{k + 1}", square(x, 0.300, size), 0.057, 0.064, MAGENTA, bone="Slide")

# ---------------------------------------------------------------- lit trim (right dust-cover groove)
# The left groove carries the stock charm loop, so the lit bar is right-only. Groove floor -.054, face
# -.062, z .1825-.195: the hex bar (r .0085) buries .003 into the floor and .001 into both groove walls.
trim = hex_along("AR_FrameTrim_Right", (0.790, -0.0595, 0.1888), (1, 0, 0),
                 [(0, 0.004), (0.010, 0.0085), (0.250, 0.0085), (0.260, 0.004)], MAGENTA)
trim["flat_group"] = "ARTrim"

# ---------------------------------------------------------------- stepped eight-sided can (Root, as stock)
# Replaces the stock round can on the same bone and footprint (apothem = stock radius). The rear face
# (x 1.129) leaves a 0.003 parting line to the slide nose (1.126) so the slide never touches it; the
# barrel's front end is nudged 0.035 forward to bury in the can. Bore r .036 at the muzzle face (2.054).
BORE_Z = 0.2965
gap_moves = {"barrel_into_can": nudge(BARREL, lambda p: p.x > 1.12 and p.y * p.y + (p.z - BORE_Z) ** 2 < 0.035 ** 2,
                                      (0.035, 0, 0))}
CAN_OUT = [(1.129, 0.060), (1.137, 0.068), (1.166, 0.068), (1.166, 0.078), (1.174, 0.084), (1.204, 0.084),
           (1.204, 0.091), (1.214, 0.099), (1.380, 0.099), (1.380, 0.092), (1.430, 0.092), (1.430, 0.099),
           (1.950, 0.099), (1.950, 0.093), (1.958, 0.091), (2.030, 0.091), (2.054, 0.074)]
CAN_IN = [(2.054, 0.036), (1.990, 0.036), (1.990, 0.022), (1.129, 0.022)]
CAN_ROLES = [METAL] * 6 + [BODY] * 6 + [METAL] * 9
can = tube("AR_Can", BORE_Z, CAN_OUT, CAN_IN, CAN_ROLES, bone="Root")
tube("AR_BrakeLight", BORE_Z, [(1.376, 0.0955), (1.434, 0.0955)], [(1.434, 0.088), (1.376, 0.088)],
     CYAN, bone="Root")["flat_group"] = "ARBrakeLight"
# The slide's raked band and line, repeated on both flat side faces of the can near the front step
# (face y +-.099, flat for z .256-.337): back .096 buried, face .103 (0.004 proud).
for sign, label in ((1, "Left"), (-1, "Right")):
    side(f"AR_CanStripe_{label}", [(1.860, 0.262), (1.878, 0.262), (1.900, 0.331), (1.882, 0.331)],
         0.096 * sign, 0.103 * sign, MAGENTA)
    side(f"AR_CanLine_{label}", [(1.888, 0.262), (1.894, 0.262), (1.916, 0.331), (1.910, 0.331)],
         0.096 * sign, 0.103 * sign, CYAN)

# ---------------------------------------------------------------- mag stripe (baseplate, both sides)
# Raked across both baseplate bands (face .067, groove floor .063): back .061 buries into both, so no
# slot shows under it; top -.402 stays under the grip bottom (-.400).
for sign, label in ((1, "Left"), (-1, "Right")):
    side(f"AR_MagStripe_{label}", [(0.018, -0.452), (0.038, -0.452), (0.060, -0.402), (0.040, -0.402)],
         0.061 * sign, 0.071 * sign, MAGENTA, bone="Mag")

result = finish_master(deck)
result["gap_moves"] = gap_moves
result["neon_fix_verts"] = NEON_FIX
