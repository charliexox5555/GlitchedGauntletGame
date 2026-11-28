"""Arcade Sheriff (revolver): a control deck (joystick, three buttons, pixel screen, light pipe) on the
left (+y) side of the barrel and its underlug, a coin door on the right frame under the hammer, a side-art
field and lit edge trim on the barrel's right side, and a stepped eight-sided muzzle collar with a light ring.
The cylinder, crane, ejector, hammer, trigger, release, rounds and speedloader keep their stock shapes
(recoloured only).

Run in a live Blender session with the stock
art-source/weapons/RemasterV2/Sheriff/Sheriff_RemasterV2_v05.blend open:
    exec(open("tools/blender/arcade/22_sheriff.py").read(), {"VERSION": "v01"})
Stock measurements (2026-11-27, Root-relative, rest pose):
  frame x -.08-.762, y +-.064 (top strap z .333-.372 over the cylinder window x .312-.637, z .052-.333);
  front ring island x .75-.80, y +-.074, z .15-.385; trigger guard island x .239-.585, y +-.03, its posts end
  at z -.016/-.010 against the frame bottom (-.016/-.018): 0.006-0.008 buried.
  barrel x .759-1.495, centre z .2772, flats y +-.068 (z .2362-.3182), top/bottom +-.038 at .3482/.2062,
  45 degree chamfers 0.030; bore r .0425 only from x 1.415; underlug x .759-1.3, y +-.046, z .104-.2152
  (front raked from (1.214, .115) to (1.297, .1736)); lug rear .759 sits 0.003 into the frame front (.762).
  sights: rear x .247-.325, base z .371 on the top strap (.372: 0.001); front x 1.29-1.436, base .3442 on the
  barrel top (.3482: 0.004). AimPoint (.26, 0, .418); Config/Weapons Sheriff adsDistance .42.
  Moving parts (swept over every clip): the crane swings the cylinder to +y; on Reload the rounds and the
  speedloader pass within y .04-.07 of the whole +y frame behind the cylinder (x -.1-.30) and the right frame
  above z .21, so nothing new can sit there. The barrel and lug (x > .78) and the right frame under the
  hammer (x .06-.30, z < .20) are never reached. Charm: CharmPoint (.68, .0658, -.0277), lower left front.
  No magazine, so no mag stripe; no stock, so no cabinet stock end.
"""

from pathlib import Path

import bpy

GUN = "Sheriff"
VERSION = globals().get("VERSION", "v01")
exec((Path(bpy.data.filepath).parents[4] / "tools/blender/arcade/arcade_lib.py").read_text(encoding="utf-8"))

# ---------------------------------------------------------------- retained stock (all of it, refinished)
for name in ("Frame", "Barrel", "Sights", "Neon", "Grip", "Pins", "CharmLoop", "Crane", "Cylinder", "Rounds",
             "EjectorRod", "Hammer", "Trigger", "CylinderRelease", "Speedloader"):
    dress(name)


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
# - trigger guard posts: 0.006-0.008 into the frame bottom: their tops move up 0.020;
# - rear sight base 0.001 onto the top strap, front sight base 0.004 onto the barrel top: feet down
#   0.020 / 0.016 (tops, blades and Neon dots unchanged; the bore starts at 1.415 under the front post);
# - underlug: top 0.009 into the barrel's bottom: up 0.012; rear 0.003 into the frame front: its lower
#   rear edge moves back 0.020 (the upper edge already sits in the front ring);
# - front ring 0.012 over the frame's front end: the frame's front end moves forward 0.013.
FRAME = native("Frame")
BARREL = native("Barrel")
SIGHTS = native("Sights")
gap_moves = {
    "guard_posts": nudge(FRAME, lambda p: -0.021 < p.z < 0 and abs(p.y) < 0.031 and 0.23 < p.x < 0.6,
                         (0, 0, 0.020), lambda lo, hi: hi.z < 0),
    "rear_sight_feet": nudge(SIGHTS, lambda p: p.z < 0.3715, (0, 0, -0.020), lambda lo, hi: hi.x < 0.5),
    "front_sight_feet": nudge(SIGHTS, lambda p: p.z < 0.3445, (0, 0, -0.016), lambda lo, hi: lo.x > 1.0),
    "lug_top": nudge(BARREL, lambda p: abs(p.z - 0.2152) < 0.0005, (0, 0, 0.012),
                     lambda lo, hi: hi.z < 0.22),
    "lug_rear": nudge(BARREL, lambda p: p.x < 0.76 and p.z < 0.12, (-0.020, 0, 0),
                      lambda lo, hi: hi.z < 0.23),
    "frame_front": nudge(FRAME, lambda p: p.x > 0.759, (0.013, 0, 0),
                         lambda lo, hi: lo.x < 0 and hi.x > 0.7),
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


# ---------------------------------------------------------------- left: control deck on the barrel and lug
# One raised plate over the lug's side (.046) and the barrel's lower side (.068): back at y .040 (buried in
# both), face .080 (0.012 proud of the barrel side). It starts 0.036 ahead of the front ring (.80), its raked
# front stays behind the lug's raked front, and its top (.300) stays under the barrel's top chamfer (.318).
# The joystick and buttons sit low (z .15-.18), where the cylinder hides them in the sight picture.
DECK = [(0.846, 0.124), (1.180, 0.124), (1.192, 0.132), (1.244, 0.204), (1.248, 0.216), (1.248, 0.290),
        (1.238, 0.300), (0.872, 0.300), (0.836, 0.140)]
deck = slab("AR_ControlDeck_Left", DECK, 0.040, 0.080, PANEL, 0.0016)

prism_along("AR_JoystickWasher", (0.890, 0.077, 0.165), (0, 1, 0), [(0, 0.016), (0.007, 0.0135)], DARK)
prism_along("AR_JoystickShaft", (0.890, 0.080, 0.165), (0, 1, 0), [(0, 0.005), (0.024, 0.005)], METAL)
stick_ball = prism_along("AR_JoystickBall", (0.890, 0.080, 0.165), (0, 1, 0), [
    (0.019, 0.007), (0.024, 0.014), (0.033, 0.014), (0.038, 0.007),
], BTN_MAGENTA)
stick_ball["flat_group"] = "ARStickBall"
for i, (x, z, role) in enumerate(((0.955, 0.150, BTN_CYAN), (1.010, 0.163, BTN_YELLOW),
                                  (1.065, 0.176, BTN_MAGENTA))):
    prism_along(f"AR_ButtonCollar_{i + 1}", (x, 0.077, z), (0, 1, 0), [(0, 0.019), (0.007, 0.0165)], DARK)
    button = prism_along(f"AR_Button_{i + 1}", (x, 0.080, z), (0, 1, 0),
                         [(0, 0.015), (0.011, 0.015), (0.0145, 0.0105)], role)
    button["flat_group"] = f"ARButton{i + 1}"

# Pixel screen over the controls: bezel ring, glowing floor, pixel graphic 0.004 proud of the floor.
inner = crect(0.909, 0.219, 1.223, 0.285, 0.006)
outer = crect(0.900, 0.212, 1.232, 0.292, 0.010)
loft("AR_ScreenBezel_Left", [
    [(x, 0.076, z) for x, z in outer], [(x, 0.090, z) for x, z in outer],
    [(x, 0.090, z) for x, z in inner], [(x, 0.076, z) for x, z in inner],
], DARK, loop=True)
plate("AR_Screen_Left", crect(0.907, 0.217, 1.225, 0.287, 0.006), 0.077, 0.083, SCREEN)["flat_group"] = "ARScreen"
PX = 0.0085
SX, SZ = 0.922, 0.229
SHIP = {(0, 4), (1, 4), (0, 3), (1, 3), (2, 3), (3, 3), (1, 2), (2, 2), (3, 2), (4, 2), (5, 2), (6, 2),
        (0, 1), (1, 1), (2, 1), (3, 1), (0, 0), (1, 0)}
pixel_solid("AR_ScreenShip_Left", SHIP, SX, SZ, PX, 0.082, 0.087, CYAN)["flat_group"] = "ARScreenShip"
pixel_solid("AR_ScreenShot_Left", {(0, 0), (1, 0), (2, 0)}, SX + 8 * PX, SZ + 2 * PX, PX,
            0.082, 0.087, MAGENTA)["flat_group"] = "ARScreenShot"
pixel_solid("AR_ScreenShotB_Left", {(0, 0), (1, 0)}, SX + 13 * PX, SZ + 2 * PX, PX,
            0.082, 0.087, MAGENTA)["flat_group"] = "ARScreenShot"
PLUS = {(1, 0), (0, 1), (1, 1), (2, 1), (1, 2)}
pixel_solid("AR_ScreenStarA_Left", PLUS, 1.120, SZ + 3 * PX, PX, 0.082, 0.087, YELLOW)["flat_group"] = "ARScreenStars"
pixel_solid("AR_ScreenStarB_Left", {(0, 0)}, 1.170, SZ, PX, 0.082, 0.087, YELLOW)["flat_group"] = "ARScreenStars"
pixel_solid("AR_ScreenStarC_Left", {(0, 0)}, 1.190, SZ + 5 * PX, PX, 0.082, 0.087, YELLOW)["flat_group"] = "ARScreenStars"
pixel_solid("AR_ScreenBlip_Left", {(0, 0)}, 1.095, SZ + 5 * PX, PX, 0.082, 0.087, CYAN)["flat_group"] = "ARScreenBlip"

# Cyan light pipe on the deck's top edge over the screen: back buried in the barrel side, front 0.0045
# behind the deck face, 0.006 above the deck top (stays under the barrel's top chamfer, .318).
side("AR_DeckLight_Left", [(0.906, 0.2945), (1.226, 0.2945), (1.2315, 0.306), (0.9115, 0.306)],
     0.062, 0.0755, CYAN)["flat_group"] = "ARDeckLight"

# ---------------------------------------------------------------- right: coin door under the hammer
# On the right frame flat (-.064) behind the cylinder window (.312) and under the swept zone (z .21+).
coin = slab("AR_CoinDoor_Right", crect(0.150, 0.082, 0.296, 0.200, 0.010), -0.058, -0.074, METAL, 0.0015)
for i, x in enumerate((0.185, 0.232)):
    block = slab(f"AR_CoinEntry_{i + 1}", crect(x - 0.017, 0.100, x + 0.017, 0.158, 0.004),
                 -0.070, -0.082, ACCENT, 0.0012)
    recess(block, f"AR_CoinSlotCut_{i + 1}", crect(x - 0.003, 0.111, x + 0.003, 0.147, 0.0015),
           -0.078, -0.096, role=DARK)
    side(f"AR_CoinSlotLight_{i + 1}", crect(x - 0.0042, 0.110, x + 0.0042, 0.148, 0.0015),
         -0.075, -0.080, YELLOW)
side("AR_CoinStripe_Right", [(0.258, 0.100), (0.271, 0.100), (0.284, 0.158), (0.271, 0.158)],
     -0.072, -0.077, MAGENTA)

# ---------------------------------------------------------------- right: barrel side art and lit trim
FIELD = [(0.860, 0.264), (0.868, 0.264), (0.868, 0.256), (0.876, 0.256), (0.876, 0.248), (1.380, 0.248),
         (1.396, 0.264), (1.396, 0.292), (1.381, 0.307), (0.875, 0.307), (0.860, 0.292)]
recess(BARREL, "AR_BarrelField_Right", FIELD, -0.060, -0.150, role=PANEL)
side("AR_BarrelStripe_Right", [(1.050, 0.252), (1.072, 0.252), (1.100, 0.303), (1.078, 0.303)],
     -0.057, -0.063, MAGENTA)
side("AR_BarrelLine_Right", [(1.082, 0.252), (1.089, 0.252), (1.117, 0.303), (1.110, 0.303)],
     -0.057, -0.063, CYAN)
plate("AR_BarrelStar_Right", star(1.320, 0.2775, 0.020, 0.0085), -0.057, -0.063, YELLOW)
for k, (x, size) in enumerate(((1.032, 0.006), (1.014, 0.009), (0.992, 0.012))):
    side(f"AR_BarrelPixel_Right_{k + 1}", square(x, 0.2775, size), -0.057, -0.063, MAGENTA)
# Cabinet T-molding in the barrel's lower right chamfer (surface y - z = -.1682 there), from inside the
# front ring (.80) into the muzzle collar (1.425): both ends buried.
trim = prism_along("AR_BarrelTrim_Right", (0.790, -0.0577, 0.2245), (1, 0, 0),
                   [(0, 0.0068), (0.645, 0.0068)], MAGENTA)
trim["flat_group"] = "ARTrim"

# ---------------------------------------------------------------- muzzle collar and light ring
# Sections follow the barrel's own chamfered box (flats .068 / .071, chamfer .030, centre z .2772), offset
# outward by ds on the sides and bottom and dt on top. The top stays at .355 or lower, under the line from
# the ADS eye over the front ring's top (.36 at the muzzle). The collar swallows the front sight's front
# foot and the barrel's last 0.07; its bore (inset 0.013, inside the barrel wall) leaves a 0.008 mouth
# over the barrel face, where the Muzzle locator (1.495) sits.
ZC, HW, HH, CH = 0.2772, 0.068, 0.071, 0.030


def boxsec(x, ds, dt):
    side_y = HW + ds
    kt = HW + HH - CH + math.sqrt(2) * (ds + dt) / 2
    kb = HW + HH - CH + math.sqrt(2) * ds
    top, bottom = HH + dt, HH + ds
    pts = [(kt - top, top), (-(kt - top), top), (-side_y, kt - side_y), (-side_y, -(kb - side_y)),
           (-(kb - bottom), -bottom), (kb - bottom, -bottom), (side_y, -(kb - side_y)), (side_y, kt - side_y)]
    return [(x, y, ZC + z) for y, z in pts]


X0 = 1.425
PROFILE = [(0.000, 0.005, 0.002), (0.006, 0.012, 0.006), (0.020, 0.012, 0.006), (0.020, 0.008, 0.003),
           (0.044, 0.008, 0.003), (0.044, 0.014, 0.007), (0.064, 0.014, 0.007), (0.071, 0.009, 0.004),
           (0.078, 0.009, 0.004)]
collar = loft("AR_MuzzleCollar", [boxsec(X0 + t, ds, dt) for t, ds, dt in PROFILE]
              + [boxsec(X0 + 0.078, -0.013, -0.013), boxsec(X0, -0.013, -0.013)], METAL, loop=True)
# v02: the ring is a band with a bore (v01's solid ring capped the barrel's bore: a cyan disc in the muzzle).
# v03: its bore sits 0.003 inside the collar's (v02's matched it: one coplanar pair).
loft("AR_BrakeLight", [boxsec(X0 + 0.017, 0.0105, 0.0048), boxsec(X0 + 0.047, 0.0105, 0.0048),
                       boxsec(X0 + 0.047, -0.016, -0.016), boxsec(X0 + 0.017, -0.016, -0.016)],
     CYAN, loop=True)["flat_group"] = "ARBrakeLight"


# ---------------------------------------------------------------- sight picture check
def ads_visible():
    """New parts whose vertices the ADS eye (and the audit's four offsets) can see directly."""
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    aim = bpy.data.objects[f"{GUN}_AimPoint"].matrix_world.translation
    eye = aim - Vector((0.42 / 0.8, 0, 0))
    offset = 0.012 / 0.8
    eyes = [eye + Vector((0, y, z)) for y, z in ((0, 0), (offset, 0), (-offset, 0), (0, offset), (0, -offset))]
    seen = {}
    for obj in shells.objects:
        if obj.type != "MESH" or obj.hide_render:
            continue
        eval_obj = obj.evaluated_get(depsgraph)
        mesh = eval_obj.to_mesh()
        for vertex in mesh.vertices:
            point = eval_obj.matrix_world @ vertex.co
            for origin in eyes:
                direction = point - origin
                distance = direction.length
                hit, location, _n, _i, hit_obj, _m = scene.ray_cast(depsgraph, origin, direction.normalized(),
                                                                    distance=distance - 1e-4)
                if not hit:
                    seen[obj.name] = seen.get(obj.name, 0) + 1
                    break
        eval_obj.to_mesh_clear()
    return seen


result = finish_master(deck)
result["gap_moves"] = gap_moves
result["ads_visible_vertices"] = ads_visible()
