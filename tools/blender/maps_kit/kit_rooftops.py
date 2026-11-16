"""Rooftops kit (maps overnight run, 2026-11-16). City roofs at golden hour; orange = the accent (crane,
billboards, a few hazard details). Each piece fills its greybox box (tools/maps/map_plans.py ROOFTOPS).
"""
import arena_kit as A
import kitlib as K

ROOT = "RooftopsKit"
K.PAL.update(
    {
        "RT_Concrete": ("#B7B9BE", 0.8),
        "RT_ConcreteDark": ("#8F9399", 0.8),
        "RT_Trim": ("#6E737B", 0.7),
        "RT_Steel": ("#4E545C", 0.6),
        "RT_Orange": ("#D9772E", 0.65),
        "RT_White": ("#E9E6DE", 0.7),
        "RT_Glass": ("#3D4C5C", 0.4),
        "RT_Wood": ("#7A5A40", 0.8),
        "RT_Tank": ("#6E7C88", 0.75),
        "RT_LampGlow": ("#E8D7B0", 0.5),
    }
)


def stair_hut():
    """20 x 10 x 10: a concrete stair hut, door on the -Y (spawn) side, corner pilasters, roof slab, lamp."""
    M = K.piece("StairHut", ROOT)
    C, D, T, S, G, L = (K.mat(n) for n in ("RT_Concrete", "RT_ConcreteDark", "RT_Trim", "RT_Steel", "RT_Glass", "RT_LampGlow"))
    K.box(M, D, -10, 10, -5, 5, 0, 0.8, 0.2)  # plinth
    K.box(M, C, -9.6, 9.6, -4.7, 4.7, 0.8, 9.0, 0.25)
    for sx in (-1, 1):
        K.box(M, D, sx * 9.0 - 1.0, sx * 9.0 + 1.0, -5, 5, 0.8, 9.2, 0.2)  # pilasters
    K.box(M, T, -10, 10, -5, 5, 9.2, 10.0, 0.3, top=0.25)  # roof slab
    # door: frame, leaf, step, lamp
    K.box(M, T, -2.6, 2.6, -5.0, -4.6, 0.8, 7.4, 0.08)
    K.box(M, S, -2.1, 2.1, -4.95, -4.75, 0.8, 6.9, 0.05)
    K.box(M, D, -3.0, 3.0, -5.0, -4.2, 0.0, 0.8, 0.1)
    K.box(M, T, -0.7, 0.7, -5.0, -4.65, 7.7, 8.4, 0.08)
    K.box(M, L, -0.5, 0.5, -5.0, -4.9, 7.8, 8.3, 0.04)
    # a vent louvre on the back
    for k in range(5):
        z = 3.0 + k * 0.7
        K.box(M, T, -3.0, 3.0, 4.6, 5.0, z, z + 0.35, 0.05)
    return M.finish()


def ac_unit():
    """10 x 10 x 10: a rooftop AC unit: plinth, louvred housing, two octagonal fan grilles on top."""
    M = K.piece("ACUnit", ROOT)
    C, D, T, S = (K.mat(n) for n in ("RT_ConcreteDark", "RT_White", "RT_Trim", "RT_Steel"))
    K.box(M, C, -5, 5, -5, 5, 0, 1.0, 0.25)
    K.box(M, D, -4.7, 4.7, -4.7, 4.7, 1.0, 9.4, 0.4)
    K.box(M, T, -5, 5, -5, 5, 9.4, 10, 0.4, top=0.2)
    for sy in (-1, 1):  # louvres on two faces
        for k in range(8):
            z = 2.0 + k * 0.85
            K.box(M, T, -3.8, 3.8, sy * 4.7 - 0.12, sy * 4.7 + 0.12, z, z + 0.4, 0.04)
    for cx in (-2.4, 2.4):  # fan grilles proud of the top only inside the box
        K.prism_n(M, S, cx, 0, 2.0, 9.7, 9.95, 8)
        for k in range(4):
            K.bar(M, T, (cx - 1.8, -0.15 + 0.1 * k, 9.96), (cx + 1.8, -0.15 + 0.1 * k, 9.96), 0.12, 0.04)
    return M.finish()


def water_tank():
    """10 x 10 x 10: a timber water tank on a braced steel stand, faceted (10 sides) with hoops and a cone lid."""
    M = K.piece("WaterTank", ROOT)
    S, W, T, O = (K.mat(n) for n in ("RT_Steel", "RT_Tank", "RT_Trim", "RT_Orange"))
    for sx in (-1, 1):
        for sy in (-1, 1):
            K.box(M, S, sx * 3.6 - 0.45, sx * 3.6 + 0.45, sy * 3.6 - 0.45, sy * 3.6 + 0.45, 0, 3.6, 0.1)
    for a, b in (((-3.6, -3.6, 0.6), (3.6, -3.6, 3.0)), ((3.6, 3.6, 0.6), (-3.6, 3.6, 3.0)), ((-3.6, 3.6, 0.6), (-3.6, -3.6, 3.0)), ((3.6, -3.6, 0.6), (3.6, 3.6, 3.0))):
        K.bar(M, S, a, b, 0.25)
    K.box(M, S, -4.3, 4.3, -4.3, 4.3, 3.6, 4.0, 0.3)
    K.prism_n(M, W, 0, 0, 4.5, 4.0, 8.6, 10)
    for z in (4.9, 6.3, 7.7):
        K.prism_n(M, T, 0, 0, 4.62, z, z + 0.25, 10)
    K.frustum(M, T, 0, 0, 4.75, 0.6, 8.6, 9.8, 10)
    K.prism_n(M, O, 0, 0, 0.6, 9.8, 10.0, 6)
    return M.finish()


def roof_shed():
    """10 x 10 x 10: a corrugated metal shed with a lean-to roof and a framed door."""
    M = K.piece("RoofShed", ROOT)
    C, S, T, R = (K.mat(n) for n in ("RT_ConcreteDark", "RT_Steel", "RT_Trim", "RT_Concrete"))
    K.box(M, C, -5, 5, -5, 5, 0, 0.6, 0.2)
    for sy in (-1, 1):
        K.corrugated(M, R, -4.6, 4.6, sy * 4.6, sy, 0.6, 8.6)
    for sx in (-1, 1):
        K.box(M, T, sx * 4.6 - 0.4, sx * 4.6 + 0.4, -4.6, 4.6, 0.6, 9.0, 0.08)
    M.loft([[(-5, -5, 8.6), (5, -5, 8.6), (5, 5, 9.4), (-5, 5, 9.4)], [(-5, -5, 9.2), (5, -5, 9.2), (5, 5, 10), (-5, 5, 10)]], S)
    K.box(M, T, -1.8, 1.8, -4.85, -4.55, 0.6, 6.6, 0.06)
    return M.finish()


def vent_stack():
    """5 x 5 x 10: an 8-sided flue on a base box, banded, with a stepped cap."""
    M = K.piece("VentStack", ROOT)
    C, S, T = (K.mat(n) for n in ("RT_ConcreteDark", "RT_Steel", "RT_Trim"))
    K.box(M, C, -2.5, 2.5, -2.5, 2.5, 0, 1.6, 0.25, top=0.2)
    K.prism_n(M, S, 0, 0, 1.6, 1.6, 8.8, 8)
    for z in (3.4, 6.2):
        K.prism_n(M, T, 0, 0, 1.75, z, z + 0.3, 8)
    K.frustum(M, T, 0, 0, 2.2, 1.4, 8.8, 9.6, 8)
    K.prism_n(M, S, 0, 0, 1.4, 9.6, 10.0, 8)
    return M.finish()


def parapet():
    """15 x 5 x 3: a parapet wall with a coping cap and a cut-back end at both ends."""
    M = K.piece("Parapet", ROOT)
    C, T = K.mat("RT_ConcreteDark"), K.mat("RT_Trim")
    M.prism([(-7.5, -2.0), (7.5, -2.0), (7.5, 2.0), (-7.5, 2.0)], 0, 2.4, C)
    K.box(M, T, -7.5, 7.5, -2.5, 2.5, 2.4, 3.0, 0.3, top=0.2)
    return M.finish()


def penthouse():
    """20 x 30 x 10: a rooftop penthouse (its top is the +10 deck): windows on the long faces, a door at the
    stair end, a flush coping band, a rooftop railing stub kept inside the box edges."""
    M = K.piece("Penthouse", ROOT)
    C, D, T, G = (K.mat(n) for n in ("RT_Concrete", "RT_ConcreteDark", "RT_Trim", "RT_Glass"))
    K.box(M, D, -10, 10, -15, 15, 0, 0.8, 0.25)
    K.box(M, C, -9.7, 9.7, -14.7, 14.7, 0.8, 9.2, 0.3)
    K.box(M, T, -10, 10, -15, 15, 9.2, 10.0, 0.35, top=0.2)
    K.window_grid(M, T, G, "x", 9.7, -12, 12, 2.5, 8.0, 4, 1, out=1)
    K.window_grid(M, T, G, "x", -9.7, -12, 12, 2.5, 8.0, 4, 1, out=-1)
    K.box(M, T, -2.6, 2.6, 14.6, 15.0, 0.8, 7.4, 0.08)  # door at the +Y (stair) end
    return M.finish()


def plank_bridge():
    """10 x 15, 1 thick: planks across two steel stringers (the bridge's top at +1 above its base)."""
    M = K.piece("PlankBridge", ROOT)
    W, S = K.mat("RT_Wood"), K.mat("RT_Steel")
    for sx in (-1, 1):
        K.box(M, S, sx * 4.2 - 0.5, sx * 4.2 + 0.5, -7.5, 7.5, 0, 0.6, 0.1)
    n = 15
    for i in range(n):
        y = -7.5 + i * 1.0
        K.box(M, W, -5, 5, y + 0.05, y + 0.95, 0.6, 1.0, 0.06)
    return M.finish()


def steel_bridge():
    """10 x 15, 1 thick: a steel grating bridge with orange-capped railings on both edges."""
    M = K.piece("SteelBridge", ROOT)
    S, T, O = K.mat("RT_Steel"), K.mat("RT_Trim"), K.mat("RT_Orange")
    K.box(M, S, -5, 5, -7.5, 7.5, 0, 1.0, 0.15)
    for k in range(7):
        y = -6.6 + k * 2.2
        K.box(M, T, -4.6, 4.6, y, y + 0.3, 1.0, 1.06, 0.03)
    for sx in (-1, 1):
        K.railing(M, T, [(sx * 4.6, -7.2, 1.0), (sx * 4.6, 7.2, 1.0)], h=3.2, every=3.6)
        K.box(M, O, sx * 4.6 - 0.2, sx * 4.6 + 0.2, -7.4, 7.4, 4.1, 4.3, 0.05)
    return M.finish()


def billboard():
    """15 x 2.5 from 3 to 18: an orange billboard on a steel frame; outrigger trusses reach both roof edges
    (decor past the box). Graphic: white chevrons and a slab, our own."""
    M = K.piece("Billboard", ROOT)
    S, T, O, Wh = (K.mat(n) for n in ("RT_Steel", "RT_Trim", "RT_Orange", "RT_White"))
    z0 = 0.0  # the piece sits at its base (3 above the roof)
    K.box(M, S, -7.5, 7.5, -0.4, 0.4, z0, z0 + 1.0, 0.15)  # bottom chord
    for sx in (-1, 1):
        K.box(M, S, sx * 6.2 - 0.5, sx * 6.2 + 0.5, -0.5, 0.5, z0, z0 + 15.0, 0.12)  # posts
        # outrigger over the alley to both roofs (decor)
        K.bar(M, S, (sx * 6.2, -9.0, z0 - 3.0), (sx * 6.2, 9.0, z0 - 3.0), 0.7, 0.9)
        K.bar(M, S, (sx * 6.2, -8.5, z0 - 2.6), (sx * 6.2, -0.4, z0 + 2.0), 0.4)
        K.bar(M, S, (sx * 6.2, 8.5, z0 - 2.6), (sx * 6.2, 0.4, z0 + 2.0), 0.4)
    K.box(M, T, -7.5, 7.5, -1.0, -0.2, z0 + 3.0, z0 + 15.0, 0.25)  # panel frame
    K.box(M, O, -7.0, 7.0, -1.25, -0.95, z0 + 3.5, z0 + 14.5, 0.2)  # panel
    for k in range(3):  # chevrons
        x = -4.5 + k * 2.6
        M.prism([(x, -1.3), (x + 1.0, -1.3), (x + 1.0, -1.28), (x, -1.28)], z0 + 6.0, z0 + 6.0, Wh) if False else None
        M.loft(
            [
                [(x, -1.32, z0 + 6.0), (x + 1.0, -1.32, z0 + 6.0), (x + 2.2, -1.32, z0 + 9.0), (x + 1.2, -1.32, z0 + 9.0)],
                [(x, -1.27, z0 + 6.0), (x + 1.0, -1.27, z0 + 6.0), (x + 2.2, -1.27, z0 + 9.0), (x + 1.2, -1.27, z0 + 9.0)],
            ],
            Wh,
        )
        M.loft(
            [
                [(x + 1.2, -1.32, z0 + 9.0), (x + 2.2, -1.32, z0 + 9.0), (x + 1.0, -1.32, z0 + 12.0), (x, -1.32, z0 + 12.0)],
                [(x + 1.2, -1.27, z0 + 9.0), (x + 2.2, -1.27, z0 + 9.0), (x + 1.0, -1.27, z0 + 12.0), (x, -1.27, z0 + 12.0)],
            ],
            Wh,
        )
    return M.finish()


def skylight():
    """10 x 10 x 3: a curb with a faceted glass hip (a four-sided pyramid with a ridge)."""
    M = K.piece("Skylight", ROOT)
    C, T, G = K.mat("RT_ConcreteDark"), K.mat("RT_Trim"), K.mat("RT_Glass")
    K.box(M, C, -5, 5, -5, 5, 0, 1.4, 0.3, top=0.15)
    M.loft([[(x, y, 1.4) for x, y in K.cham(-4.4, 4.4, -4.4, 4.4, 0.2)], [(x, y, 2.9) for x, y in K.cham(-2.2, 2.2, -0.6, 0.6, 0.05)]], G)
    for sx in (-1, 1):
        K.bar(M, T, (sx * 4.3, -4.3, 1.45), (sx * 2.1, -0.55, 2.92), 0.2)
        K.bar(M, T, (sx * 4.3, 4.3, 1.45), (sx * 2.1, 0.55, 2.92), 0.2)
    return M.finish()


def duct_run():
    """10 x 5 x 3: a sheet duct on stands with flanged joints."""
    M = K.piece("DuctRun", ROOT)
    S, T = K.mat("RT_White"), K.mat("RT_Trim")
    for x in (-3.5, 3.5):
        K.box(M, T, x - 0.4, x + 0.4, -2.2, 2.2, 0, 0.8, 0.08)
    K.box(M, S, -5, 5, -2.0, 2.0, 0.8, 3.0, 0.35)
    for x in (-1.7, 1.7):
        K.box(M, T, x - 0.2, x + 0.2, -2.3, 2.3, 0.6, 3.0, 0.1)
    return M.finish()


def tower_crane():
    """The landmark (decor, outside the deck): an orange lattice mast 64 tall, a cab, a 70-long jib over the
    roofs and a counter-jib with weights. Faceted bars only."""
    M = K.piece("TowerCrane", ROOT)
    O, S, T, G = (K.mat(n) for n in ("RT_Orange", "RT_Steel", "RT_Trim", "RT_Glass"))
    H = 64
    K.box(M, T, -4, 4, -4, 4, -30, -28, 0.3)  # foot down on the street
    for sx in (-1, 1):
        for sy in (-1, 1):
            K.bar(M, O, (sx * 2, sy * 2, -28), (sx * 2, sy * 2, H), 0.5)
    z = -28
    k = 0
    while z < H - 4:
        for (a, b) in (((-2, -2), (2, -2)), ((2, -2), (2, 2)), ((2, 2), (-2, 2)), ((-2, 2), (-2, -2))):
            K.bar(M, O, (a[0], a[1], z), (b[0], b[1], z + 4) if k % 2 else (b[0], b[1], z), 0.3)
        z += 4
        k += 1
    K.box(M, S, -3, 3, -3, 3, H, H + 2, 0.4)  # slewing ring
    K.box(M, T, 1.5, 5.5, -2.5, 2.5, H - 4, H, 0.4)  # cab
    K.box(M, G, 5.4, 5.6, -2.0, 2.0, H - 3.4, H - 1.0, 0.05)
    for sy in (-1, 1):  # jib (toward -X, over the map) and counter-jib (+X)
        K.bar(M, O, (2, sy * 1.2, H + 2), (-70, sy * 1.2, H + 2), 0.45)
        K.bar(M, O, (2, sy * 1.2, H + 2), (18, sy * 1.2, H + 2), 0.45)
    K.bar(M, O, (0, 0, H + 6), (-70, 0, H + 2.5), 0.4)
    K.bar(M, O, (0, 0, H + 6), (18, 0, H + 2.5), 0.4)
    for x in range(-66, 0, 6):
        K.bar(M, O, (x, -1.2, H + 2), (x + 3, 0, H + 2 + (6 - 3.5) * (x + 70) / 70 + 0.6), 0.25)
    K.prism_n(M, O, 0, 0, 0.8, H + 2, H + 7, 6)  # A-frame top
    K.box(M, T, 12, 17, -2.2, 2.2, H - 1.5, H + 2, 0.3)  # counterweights
    K.bar(M, S, (-40, 0, H + 1.6), (-40, 0, H - 22), 0.2)  # hook line
    K.box(M, O, -41.2, -38.8, -1.0, 1.0, H - 24.5, H - 22, 0.3)
    return M.finish()


def build_all():
    K.clear_theme(ROOT)
    made = [stair_hut(), ac_unit(), water_tank(), roof_shed(), vent_stack(), parapet(), penthouse(), plank_bridge(),
            steel_bridge(), billboard(), skylight(), duct_run(), tower_crane()]
    K.tag("RT_")
    return K.tris(made)
