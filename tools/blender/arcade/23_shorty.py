"""Arcade Shorty: a small cabinet deck (joystick, three buttons, pixel screen, light pipe) on the frame's left
face over the breech-latch recess, a coin door in the frame's right recess, forend side art on the stock
forend fields with lit edge trim (Barrels bone), and a binocular stepped muzzle block with a light ring that
replaces the two thin muzzle tips (Barrels bone).

Run in a live Blender session with the stock
art-source/weapons/RemasterV2/Shorty/Shorty_RemasterV2_v05.blend open:
    exec(open("tools/blender/arcade/23_shorty.py").read(), {"VERSION": "v01"})
Left (+y) is the player-facing side (Shorty_Cam_Hip at y .38, FP_Hip at y .47). Stock rig, locators, actions
and CharmLoop are kept. Stock measurements (2026-11-27, ray-cast depth maps and swept clips, Root-relative):
  frame x -.10-.546, face y +-.090, z .052-.333 (top chamfer from z .313); recess both sides (floor .085,
  Panel) x .04-.37, z .07-.215; stock Neon strips x .128-.195, z .242-.25 (y .086-.089) both sides; rear
  sight x -.019-.084, z .333-.365 (Neon dots); BreechLatch (left, own bone) x .286-.434, y .086-.102,
  z .117-.164; CharmLoop (Root) x -.085 to -.04, y .088-.129, z .176-.214.
  Barrels bone (hinge x .546, z .114; breaks 36 deg muzzle-down in Reload / ReloadEmpty, 27 in Inspect):
  breech block x .546-.645 (y .104), barrel block x .64-1.04 (y .102, z .198-.322), forend x .645-1.25
  (face .088, Dark; field recess floor .084, Grip, x .703-1.21, z .052-.170; bottom z .031 from x .88,
  .005 lug x .66-.86), tubes r .046 x .99-1.36, band x 1.27-1.32 (y .104, Panel), muzzle tips r .049 with
  r .027 bores x 1.355-1.448, rib z .288-.312 to 1.36, front bead x 1.30-1.35 (top .348). Side-by-side
  barrels at y +-.05, z .26; Muzzle / MuzzleLower 1.4482. Shells eject from x .546.
  Config/Weapons Shorty: noAds = true (no adsDistance; the stock file has no AimPoint or Cam_ADS).
  Owner moved the Shorty charm point in Studio to Blender (0.74, 0.116, 0.215): the CharmLoop stays stock
  (untouched) and every Arcade part keeps ~0.09 clear of that point and below it.
"""

from pathlib import Path

import bpy

GUN = "Shorty"
VERSION = globals().get("VERSION", "v01")
exec((Path(bpy.data.filepath).parents[4] / "tools/blender/arcade/arcade_lib.py").read_text(encoding="utf-8"))

# ---------------------------------------------------------------- retained stock
# CharmLoop is NOT dressed (stock materials, visible): the exporter lists it untouched and Studio keeps the
# owner's moved ring.
for name in ("Frame", "Grip", "Trigger", "BreechLatch", "ShellUpper", "ShellLower", "BarrelNeon"):
    dress(name)
# Neon: drop the left frame strip (the deck covers it); keep the right strip and the rear sight dots.
dress("Neon", keep=lambda island: not (limits(island, 1)[0] > 0.08 and limits(island, 2)[0] > 0.2))
# Barrels: the forend turns cabinet purple and its fields violet; the two thin muzzle tips give way to the
# muzzle block.
dress("Barrels", slots={"Dark": BODY, "Grip": PANEL}, keep=lambda island: limits(island, 0)[0] < 1.35)


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


# Stock coplanar pair: the rib's and the centre web's front faces lay in the tubes' front plane (x 1.36, now
# the bore floors). Both end inside the muzzle block, so their fronts move 0.010 forward (buried 0.032; the
# bores stay clear of them: web |y| < .012, rib |y| < .016, bores |y| > .021).
BARRELS = native("Barrels")
gap_moves = {
    "rib_and_web_front": nudge(BARRELS, lambda p: p.x > 1.355, (0.010, 0, 0),
                               lambda lo, hi: hi.y < 0.017 and lo.y > -0.017 and abs(hi.x - 1.36) < 0.002),
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


# ---------------------------------------------------------------- left: cabinet deck (Root)
# A low control panel on the frame's left face (.090): back at y .0835 (buried 0.0065: the stock shells load
# through the frame out to |y| .082 in Reload / ReloadEmpty, so the back stays 0.0015 clear), face .100. It sits
# 0.011 over the latch recess's top wall (.215), 0.013 under the top chamfer (.313), 0.031 behind the
# breech block (.546) and 0.045 ahead of the CharmLoop (-.04); its rear edge rakes like a cabinet.
DECK = [(0.022, 0.226), (0.505, 0.226), (0.515, 0.236), (0.515, 0.290), (0.505, 0.300),
        (0.060, 0.300), (0.005, 0.245)]
deck = slab("AR_ControlDeck_Left", DECK, 0.0835, 0.100, PANEL, 0.0018)

prism_along("AR_JoystickWasher", (0.060, 0.096, 0.263), (0, 1, 0), [(0, 0.0145), (0.0085, 0.0120)], DARK)
prism_along("AR_JoystickShaft", (0.060, 0.102, 0.263), (0, 1, 0), [(0, 0.0038), (0.026, 0.0038)], METAL)
stick_ball = prism_along("AR_JoystickBall", (0.060, 0.102, 0.263), (0, 1, 0), [
    (0.020, 0.006), (0.024, 0.0112), (0.032, 0.0112), (0.036, 0.006),
], BTN_MAGENTA)
stick_ball["flat_group"] = "ARStickBall"
for i, (x, z, role) in enumerate(((0.106, 0.251, BTN_CYAN), (0.150, 0.260, BTN_YELLOW),
                                  (0.194, 0.269, BTN_MAGENTA))):
    prism_along(f"AR_ButtonCollar_{i + 1}", (x, 0.096, z), (0, 1, 0),
                [(0, 0.0195), (0.0085, 0.0170)], DARK)
    button = prism_along(f"AR_Button_{i + 1}", (x, 0.102, z), (0, 1, 0),
                         [(0, 0.0145), (0.011, 0.0145), (0.0145, 0.0105)], role)
    button["flat_group"] = f"ARButton{i + 1}"

# Pixel screen: bezel ring, glowing screen floor, pixel graphic standing 0.004 proud.
inner = crect(0.238, 0.2405, 0.497, 0.2855, 0.005)
outer = crect(0.228, 0.234, 0.507, 0.292, 0.009)
loft("AR_ScreenBezel_Left", [
    [(x, 0.096, z) for x, z in outer], [(x, 0.108, z) for x, z in outer],
    [(x, 0.108, z) for x, z in inner], [(x, 0.096, z) for x, z in inner],
], DARK, loop=True)
plate("AR_Screen_Left", crect(0.236, 0.2385, 0.499, 0.2875, 0.005), 0.097, 0.103, SCREEN)["flat_group"] = "ARScreen"
PX = 0.0072
SX, SZ = 0.250, 0.2465
SHIP = {(0, 4), (1, 4), (0, 3), (1, 3), (2, 3), (3, 3), (1, 2), (2, 2), (3, 2), (4, 2), (5, 2), (6, 2),
        (0, 1), (1, 1), (2, 1), (3, 1), (0, 0), (1, 0)}
pixel_solid("AR_ScreenShip_Left", SHIP, SX, SZ, PX, 0.102, 0.107, CYAN)["flat_group"] = "ARScreenShip"
pixel_solid("AR_ScreenShot_Left", {(0, 0), (1, 0), (2, 0)}, SX + 8 * PX, SZ + 2 * PX, PX,
            0.102, 0.107, MAGENTA)["flat_group"] = "ARScreenShot"
PLUS = {(1, 0), (0, 1), (1, 1), (2, 1), (1, 2)}
pixel_solid("AR_ScreenStarA_Left", PLUS, 0.430, SZ + 2 * PX, PX, 0.102, 0.107, YELLOW)["flat_group"] = "ARScreenStars"
pixel_solid("AR_ScreenStarB_Left", {(0, 0)}, 0.470, SZ, PX, 0.102, 0.107, YELLOW)["flat_group"] = "ARScreenStars"
pixel_solid("AR_ScreenStarC_Left", {(0, 0)}, 0.400, SZ + 4 * PX, PX, 0.102, 0.107, CYAN)["flat_group"] = "ARScreenBlip"

# Cyan light pipe along the deck's top edge over the screen: back .085 (buried 0.005 in the frame face, 0.0015
# off the deck's back plane so the two never share a plane), bottom
# 0.004 inside the deck, front 0.004 behind the deck face, top 0.006 under the frame's top chamfer.
side("AR_DeckLight_Left", [(0.232, 0.296), (0.503, 0.296), (0.508, 0.307), (0.237, 0.307)],
     0.0850, 0.096, CYAN)["flat_group"] = "ARDeckLight"

# ---------------------------------------------------------------- right: coin door (Root)
# Seated in the frame's right recess (floor -.085, top wall .215): back -.0835 (in the floor, 0.0015 clear of
# the stock lower shell's loading path at |y| .082), face -.097.
coin = slab("AR_CoinDoor_Right", crect(0.090, 0.105, 0.310, 0.200, 0.010), -0.0835, -0.097, METAL, 0.0018)
for i, x in enumerate((0.140, 0.212)):
    block = slab(f"AR_CoinEntry_{i + 1}", crect(x - 0.025, 0.122, x + 0.025, 0.183, 0.005),
                 -0.093, -0.109, ACCENT, 0.0015)
    recess(block, f"AR_CoinSlotCut_{i + 1}", crect(x - 0.0035, 0.135, x + 0.0035, 0.170, 0.0018),
           -0.103, -0.129, role=DARK)
    side(f"AR_CoinSlotLight_{i + 1}", crect(x - 0.005, 0.134, x + 0.005, 0.171, 0.0018),
         -0.099, -0.107, YELLOW)
side("AR_CoinStripe_Right", [(0.250, 0.115), (0.272, 0.115), (0.298, 0.190), (0.276, 0.190)],
     -0.093, -0.099, MAGENTA)

# ---------------------------------------------------------------- forend art (Barrels)
# On the stock forend fields (floor .084, x .703-1.21, z .052-.170): raked band, cyan line, starburst and
# a pixel trail standing 0.0085 proud, back 0.004 in the floor. Everything starts at x .87+ so the moved
# charm point (x .74) keeps its swing room.
for sign, label in ((1, "Left"), (-1, "Right")):
    side(f"AR_ForendStripe_{label}", [(0.950, 0.064), (0.976, 0.064), (1.014, 0.158), (0.988, 0.158)],
         0.080 * sign, 0.0925 * sign, MAGENTA, bone="Barrels")
    side(f"AR_ForendLine_{label}", [(0.986, 0.064), (0.995, 0.064), (1.033, 0.158), (1.024, 0.158)],
         0.080 * sign, 0.0925 * sign, CYAN, bone="Barrels")
    plate(f"AR_ForendStar_{label}", star(1.135, 0.111, 0.031, 0.013), 0.080 * sign, 0.0925 * sign, YELLOW,
          bone="Barrels")
    for k, (x, size) in enumerate(((0.932, 0.008), (0.912, 0.012), (0.887, 0.016))):
        side(f"AR_ForendPixel_{label}_{k + 1}", square(x, 0.111, size), 0.080 * sign, 0.0925 * sign, MAGENTA,
             bone="Barrels")
    # Cabinet T-molding: a lit bar seated in the forend's lower edge (face .088, bottom .031).
    trim = prism_along(f"AR_ForendTrim_{label}", (0.892, 0.0858 * sign, 0.0338), (1, 0, 0),
                       [(0, 0.0028), (0.007, 0.0062), (0.296, 0.0062), (0.303, 0.0028)], MAGENTA, bone="Barrels")
    trim["flat_group"] = "ARTrim"

# ---------------------------------------------------------------- muzzle block (Barrels)
# One stepped eight-sided block round both barrels' ends (centre z .26): rear step, a light-ring groove
# with the cyan ring (ends buried in the groove walls, inner face buried in the block), the main section and
# a chamfered nose, with two eight-sided bores (r .027) down to the barrels' faces (1.36). Its rear swallows
# the barrels, rib and web 0.022 (1.338) and the front bead's foot; the Muzzle locators (1.4482) sit in the
# bore mouths (1.450).
MZ = 0.26
BLOCK = [(-0.078, 0.056), (0.078, 0.056), (0.108, 0.026), (0.108, -0.026),
         (0.078, -0.056), (-0.078, -0.056), (-0.108, -0.026), (-0.108, 0.026)]


def ring(x, s):
    return [(x, y * s, MZ + z * s) for y, z in BLOCK]


block = loft("AR_MuzzleBlock", [ring(x, s) for x, s in (
    (1.338, 0.92), (1.346, 1.0), (1.392, 1.0), (1.392, 0.92), (1.418, 0.92), (1.418, 1.0),
    (1.440, 1.0), (1.450, 0.90),
)], METAL, bone="Barrels")
for i, cy in enumerate((0.05, -0.05)):
    cut = loft(f"AR_MuzzleBore_{i + 1}", [
        [(x, cy + u, MZ + v) for u, v in polygon(0, 0, 0.0292, 8)] for x in (1.300, 1.480)
    ], DARK, bone="Barrels", cutter=True)
    bore = block.modifiers.new(f"Bore {i + 1}", "BOOLEAN")
    bore.operation = "DIFFERENCE"
    bore.solver = "EXACT"
    bore.object = cut
loft("AR_BrakeLight", [ring(1.389, 0.965), ring(1.421, 0.965), ring(1.421, 0.88), ring(1.389, 0.88)],
     CYAN, bone="Barrels", loop=True)["flat_group"] = "ARBrakeLight"


# ---------------------------------------------------------------- checks
def sight_line_hits():
    """noAds gun: keep the rear-notch-to-bead line clear (notch ~ z .352, bead top .348)."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    bpy.context.view_layer.update()
    hits = set()
    eye = Vector((-0.40, 0, 0.352))
    target = Vector((1.325, 0, 0.346))
    for dy, dz in ((0, 0), (0.010, 0), (-0.010, 0), (0, 0.010), (0, -0.004)):
        origin = eye + Vector((0, dy, dz))
        direction = (target + Vector((0, dy, dz)) - origin).normalized()
        hit, location, _n, _i, obj, _m = scene.ray_cast(depsgraph, origin, direction, distance=1.9)
        if hit and obj.name.startswith("AR_"):
            hits.add(obj.name)
    return sorted(hits)


def charm_clearance():
    """Nearest Arcade surface to the moved charm point and to the 0.09 drop below it (rest pose)."""
    from mathutils.bvhtree import BVHTree
    depsgraph = bpy.context.evaluated_depsgraph_get()
    point = Vector((0.74, 0.116, 0.215))
    probes = [point - Vector((0, 0, 0.015 * k)) for k in range(7)]
    best = (9.0, None)
    for obj in shells.objects:
        if obj.type != "MESH" or obj.hide_render:
            continue
        ev = obj.evaluated_get(depsgraph)
        mesh = ev.to_mesh()
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bm.transform(ev.matrix_world)
        tree = BVHTree.FromBMesh(bm)
        for probe in probes:
            hit = tree.find_nearest(probe)
            if hit[0] is not None and hit[3] < best[0]:
                best = (round(hit[3], 4), obj.name)
        bm.free()
        ev.to_mesh_clear()
    return best


result = finish_master(deck)
result["gap_moves"] = gap_moves
result["sight_line_new_hits"] = sight_line_hits()
result["charm_clearance"] = charm_clearance()
