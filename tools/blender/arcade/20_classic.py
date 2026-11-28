"""Arcade Classic (starter pistol): a cabinet deck on the fixed frame's left band (joystick, three
buttons, pixel screen, light pipe), a coin door on the right grip panel, side-art fields on the slide
(left: the main slide, right: the nose block), a lit trim in the right dust-cover groove, a stepped
eight-sided muzzle collar with a light ring on the slide nose, and a magazine stripe.

Run in a live Blender session with the stock
art-source/weapons/RemasterV2/Classic/Classic_RemasterV2_v05.blend open:
    exec(open("tools/blender/arcade/20_classic.py").read(), {"VERSION": "v01"})
Left (+y) is the player-facing side. Stock rig, locators, sights and actions are kept. The stock
CharmLoop is left unskinned (stock materials, not dressed, not hidden): the owner moved the Classic's
charm point in Studio to Blender (0.74, 0.084, 0.205) and the Studio install keeps the moved ring.
Every Arcade part stays 0.09+ clear of that point (it hangs from the left dust-cover groove, so the
lit trim is on the right only).
Stock measurements (2026-11-27, ray-cast depth maps):
  slide x -.267/1.0, side face y .070 from z .289 (bottom) to .445, top chamfer to .48; a vertical
  groove at x .71-.715 both sides (slide/nose block); right ejection port x .35-.60 above z .38;
  rear serrations x -.25/-.07; SlideNeon strip x .003/.092, z .298/.308 (left).
  frame band side face y .072, z .19-.28 (chamfer .185-.19), x -.275/.97; dust cover underside z .185,
  a groove y .064 at z .20-.21 for x .64-.94 both sides; slide catch x .288-.432, z .236-.262 (left).
  grip side y .066 with a recessed panel y .062 (x about -.16/.15, z -.24/.06), top z .176;
  mag release x .169-.223, z .04-.098 (left); magazine body y +-.05 inside the grip;
  mag baseplate face y .070, z -.37/-.32, x -.27/.18; slide nose face x 1.0, slide hole r ~.028,
  barrel crown r .026 to x .997, recoil-spring hole centre z ~.30 r ~.012; iron line z .509.
  Stock CharmLoop x -.25/-.175, z .196/.25, y to .116 (rear left of the frame).
"""

from pathlib import Path

import bpy

GUN = "Classic"
VERSION = globals().get("VERSION", "v01")
exec((Path(bpy.data.filepath).parents[4] / "tools/blender/arcade/arcade_lib.py").read_text(encoding="utf-8"))

# ---------------------------------------------------------------- retained stock (CharmLoop untouched)
for name in ("SlideNeon", "Barrel", "Frame", "Pins", "Trigger", "SlideCatch", "MagRelease", "MagNeon"):
    dress(name)
dress("Grip")
# The slide body gets the recessed side-art fields. An exact boolean on the whole stock slide unions its
# separate sight islands into the body (and FLOAT leaves loose topology), so the unchanged stock sights
# move to their own object on the Slide bone (AR_SlideSights) and Classic_Slide keeps the body.
dress("Slide", copy_name="AR_SlideSights", keep=lambda island: limits(island, 0)[1] - limits(island, 0)[0] < 1.0)
SLIDE = dress("Slide", keep=lambda island: limits(island, 0)[1] - limits(island, 0)[0] > 1.0)


def hex_along(name, origin, axis, profile, roles, *, bone="Root"):
    """prism_along with six facets: the pistol's small round parts (budget 1.5x a small stock gun)."""
    origin = Vector(origin)
    axis = Vector(axis).normalized()
    helper = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))
    u = axis.cross(helper).normalized()
    v = axis.cross(u).normalized()
    sections = [[tuple(origin + axis * t + u * a + v * b) for a, b in polygon(0, 0, radius, 6, 0)]
                for t, radius in profile]
    return loft(name, sections, roles, bone=bone)


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


# Gap sweep: the magazine body (inside the grip) stopped 0.002 above the baseplate (top -.298), so the
# baseplate, its stock neon slits and the new stripes floated. The body's bottom now runs 0.02 down into
# the baseplate (hidden inside it). The 0.002 grip-to-baseplate seam itself is the magazine's parting
# line (it must part in the reloads) and has the magazine body behind it, so nothing shows through.
dress("Magazine", slots={"Dark": GRIP})
gap_moves = {
    "mag_body_into_baseplate": nudge(native("Magazine"), lambda p: p.z < -0.29, (0, 0, -0.022),
                                     lambda lo, hi: hi.y < 0.06 and lo.z > -0.30 and hi.z > 0.1),
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


def tube(name, z, outer, inner, role, *, bone):
    """An eight-sided ring along +x with a bore: outer (x, r) back to front, inner (x, r) front to back."""
    sections = [[(x, r * math.cos(a), z + r * math.sin(a)) for a in
                 (math.pi / 8 + math.pi / 4 * i for i in range(8))] for x, r in (*outer, *inner)]
    return loft(name, sections, role, bone=bone, loop=True)


# ---------------------------------------------------------------- left: cabinet deck (fixed frame)
# On the frame band's left face (.072) between the grip top (.176) and the slide bottom (.289):
# back y .064 (buried), face .084. The rear stops 0.025 ahead of the stock CharmLoop (x -.175);
# the front stops 0.026 behind the slide catch (x .288). Scaled for the pistol: three buttons fit.
DECK = [(-0.150, 0.182), (0.248, 0.182), (0.262, 0.196), (0.262, 0.258), (0.254, 0.266),
        (-0.134, 0.266), (-0.150, 0.250)]
deck = slab("AR_ControlDeck_Left", DECK, 0.064, 0.084, PANEL, 0.0015)

# Joystick at the rear, then three faceted buttons in collars rising toward the muzzle.
hex_along("AR_JoystickWasher", (-0.112, 0.080, 0.224), (0, 1, 0), [(0, 0.018), (0.007, 0.015)], DARK)
hex_along("AR_JoystickShaft", (-0.112, 0.084, 0.224), (0, 1, 0), [(0, 0.0045), (0.024, 0.0045)], METAL)
stick_ball = prism_along("AR_JoystickBall", (-0.112, 0.084, 0.224), (0, 1, 0), [
    (0.018, 0.006), (0.025, 0.012), (0.035, 0.006),
], BTN_MAGENTA)
stick_ball["flat_group"] = "ARStickBall"
for i, (x, z, role) in enumerate(((-0.066, 0.212, BTN_CYAN), (-0.030, 0.220, BTN_YELLOW),
                                  (0.006, 0.228, BTN_MAGENTA))):
    hex_along(f"AR_ButtonCollar_{i + 1}", (x, 0.080, z), (0, 1, 0),
                [(0, 0.0155), (0.008, 0.0135)], DARK)
    button = prism_along(f"AR_Button_{i + 1}", (x, 0.084, z), (0, 1, 0),
                         [(0, 0.0115), (0.012, 0.0115), (0.016, 0.0075)], role)
    button["flat_group"] = f"ARButton{i + 1}"

# Pixel screen: bezel ring, glowing screen floor, pixel graphic standing 0.004 proud.
inner = crect(0.040, 0.199, 0.242, 0.249, 0.006)
outer = crect(0.030, 0.190, 0.252, 0.258, 0.010)
loft("AR_ScreenBezel_Left", [
    [(x, 0.080, z) for x, z in outer], [(x, 0.094, z) for x, z in outer],
    [(x, 0.094, z) for x, z in inner], [(x, 0.080, z) for x, z in inner],
], DARK, loop=True)
plate("AR_Screen_Left", crect(0.038, 0.197, 0.244, 0.251, 0.006), 0.081, 0.087, SCREEN)["flat_group"] = "ARScreen"
PX = 0.0055
SX, SZ = 0.050, 0.2085
SHIP = {(0, 4), (1, 4), (0, 3), (1, 3), (2, 3), (3, 3), (1, 2), (2, 2), (3, 2), (4, 2), (5, 2), (6, 2),
        (0, 1), (1, 1), (2, 1), (3, 1), (0, 0), (1, 0)}
pixel_solid("AR_ScreenShip_Left", SHIP, SX, SZ, PX, 0.086, 0.091, CYAN)["flat_group"] = "ARScreenShip"
pixel_solid("AR_ScreenShot_Left", {(0, 0), (1, 0), (2, 0)}, SX + 8 * PX, SZ + 2 * PX, PX,
            0.086, 0.091, MAGENTA)["flat_group"] = "ARScreenShot"
PLUS = {(1, 0), (0, 1), (1, 1), (2, 1), (1, 2)}
pixel_solid("AR_ScreenStarA_Left", PLUS, 0.190, SZ + 2 * PX, PX, 0.086, 0.091, YELLOW)["flat_group"] = "ARScreenStars"
pixel_solid("AR_ScreenStarB_Left", {(0, 0)}, 0.226, SZ + 1 * PX, PX, 0.086, 0.091, YELLOW)["flat_group"] = "ARScreenStars"
pixel_solid("AR_ScreenStarC_Left", {(0, 0)}, 0.165, SZ + 5 * PX, PX, 0.086, 0.091, CYAN)["flat_group"] = "ARScreenBlip"

# Cyan light pipe along the deck's top edge over the screen: back buried 0.02 in the frame, front 0.003
# behind the deck face, 0.007 above the deck top; its top (.273) stays 0.016 under the slide (.289).
side("AR_DeckLight_Left", [(0.036, 0.261), (0.246, 0.261), (0.252, 0.273), (0.042, 0.273)],
     0.052, 0.081, CYAN)["flat_group"] = "ARDeckLight"

# ---------------------------------------------------------------- right: coin door (grip panel)
# Seated in the right grip panel (recess face -.062, border -.066). The back (-.056) stays clear of
# the magazine body (y -.05) that slides out of the grip in the reloads.
coin = slab("AR_CoinDoor_Right", crect(-0.100, -0.180, 0.090, -0.010, 0.012), -0.056, -0.072, METAL, 0.0015)
for i, x in enumerate((-0.052, 0.002)):
    # Lilac entry block with a lit coin slot standing 0.004 proud (no boolean: the pistol's budget is tight).
    side(f"AR_CoinEntry_{i + 1}", crect(x - 0.021, -0.128, x + 0.021, -0.072, 0.005),
         -0.068, -0.080, ACCENT)
    side(f"AR_CoinSlotLight_{i + 1}", [(x - 0.0045, -0.117), (x + 0.0045, -0.117), (x + 0.0045, -0.083), (x - 0.0045, -0.083)],
         -0.076, -0.084, YELLOW)
side("AR_CoinStripe_Right", [(0.034, -0.168), (0.056, -0.168), (0.074, -0.022), (0.052, -0.022)],
     -0.068, -0.076, MAGENTA)

# ---------------------------------------------------------------- slide side-art fields (ride the slide)
# Recessed 0.006 into the slide's flat side (.070) between its bottom (.289) and top chamfer (.445), on
# the player-facing main slide behind the nose groove (x .715). The band rakes forward as it rises; the
# pixel trail grows toward the rear. The right side has no slide field: the budget (1.5x a 2334-tri
# stock gun) goes to the deck, and the right side carries the coin door and the lit trim.
FIELD_L = [(0.300, 0.342), (0.312, 0.342), (0.312, 0.330), (0.324, 0.330), (0.324, 0.318),
           (0.668, 0.318), (0.690, 0.340), (0.690, 0.418), (0.670, 0.438), (0.316, 0.438), (0.300, 0.422)]
ART = {
    "Left": (FIELD_L, [(0.470, 0.322), (0.500, 0.322), (0.560, 0.434), (0.530, 0.434)],
             [(0.512, 0.322), (0.521, 0.322), (0.581, 0.434), (0.572, 0.434)], (0.632, 0.378, 0.026, 0.011),
             ((0.452, 0.008), (0.432, 0.012), (0.406, 0.016), (0.374, 0.020))),
}
for label, (field, band, line, (sx, sz, so, si), pixels) in ART.items():
    sign = 1 if label == "Left" else -1
    recess(SLIDE, f"AR_SlideField_{label}", field, 0.064 * sign, 0.15 * sign, role=PANEL, bone="Slide")
    side(f"AR_SlideStripe_{label}", band, 0.061 * sign, 0.068 * sign, MAGENTA, bone="Slide")
    side(f"AR_SlideLine_{label}", line, 0.061 * sign, 0.068 * sign, CYAN, bone="Slide")
    plate(f"AR_SlideStar_{label}", star(sx, sz, so, si), 0.061 * sign, 0.068 * sign, YELLOW, bone="Slide")
    for k, (x, size) in enumerate(pixels):
        side(f"AR_SlidePixel_{label}_{k + 1}", square(x, 0.384, size), 0.061 * sign, 0.068 * sign,
             MAGENTA, bone="Slide")

# ---------------------------------------------------------------- lit trim (right dust-cover groove)
# The left groove carries the owner's moved charm (0.74, 0.084, 0.205), so the lit bar is right-only.
trim = hex_along("AR_FrameTrim_Right", (0.655, -0.069, 0.205), (1, 0, 0),
                   [(0, 0.003), (0.008, 0.0068), (0.272, 0.0068), (0.280, 0.003)], MAGENTA)
trim["flat_group"] = "ARTrim"

# ---------------------------------------------------------------- muzzle collar and light ring (slide nose)
# A stepped eight-sided collar buried 0.021 into the slide's nose face (x 1.0) with a groove holding the
# cyan ring. Bore r .035 clears the barrel crown (r .026); the bottom (.320) clears the recoil-spring hole.
BORE_Z = 0.3654
tube("AR_MuzzleCollar", BORE_Z, [(0.979, 0.046), (1.012, 0.046), (1.012, 0.040), (1.022, 0.040),
                                 (1.022, 0.046), (1.031, 0.040)],
     [(1.031, 0.035), (0.979, 0.035)], METAL, bone="Slide")
tube("AR_BrakeLight", BORE_Z, [(1.011, 0.0445), (1.023, 0.0445)], [(1.023, 0.0375), (1.011, 0.0375)],
     CYAN, bone="Slide")["flat_group"] = "ARBrakeLight"

# ---------------------------------------------------------------- mag stripe (baseplate, both sides)
for sign, label in ((1, "Left"), (-1, "Right")):
    side(f"AR_MagStripe_{label}", [(0.030, -0.366), (0.052, -0.366), (0.078, -0.322), (0.056, -0.322)],
         0.067 * sign, 0.074 * sign, MAGENTA, bone="Mag")

result = finish_master(deck)
