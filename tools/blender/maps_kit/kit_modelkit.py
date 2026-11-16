"""Model Kit kit (maps overnight run, 2026-11-16). Giant scale: a hobby workbench; bright, the fun one. Each piece
fills its greybox box (tools/maps/map_plans.py MODELKIT). Faceted: bottles and pots are 8-sided, pencils 6.
"""
import kitlib as K

ROOT = "ModelKitKit"
K.PAL.update(
    {
        "MK_White": ("#F0EEE6", 0.6),
        "MK_Orange": ("#E8823A", 0.55),
        "MK_Red": ("#C8443B", 0.55),
        "MK_Blue": ("#3B6FC8", 0.55),
        "MK_Yellow": ("#E3B33A", 0.6),
        "MK_Purple": ("#6B4FA0", 0.7),
        "MK_Rust": ("#C25B3A", 0.7),
        "MK_Grey": ("#B9BEC4", 0.4),
        "MK_Dark": ("#3A3E45", 0.6),
        "MK_Paper": ("#EDE6D6", 0.85),
        "MK_Wood": ("#C9A27A", 0.8),
        "MK_Sprue": ("#9AA0A6", 0.5),
        "MK_Tape": ("#D8CBA8", 0.6),
    }
)
m = K.mat


def glue_pot():
    """15 x 15 x 25 (+cap): a glue bottle: 8-sided body, a label band, shoulder, an orange cap and nozzle."""
    M = K.piece("GluePot", ROOT)
    W, O, R, D = m("MK_White"), m("MK_Orange"), m("MK_Red"), m("MK_Dark")
    K.frustum(M, W, 0, 0, 7.2, 7.4, 0, 2, 8)
    K.prism_n(M, W, 0, 0, 7.4, 2, 16, 8)
    K.prism_n(M, R, 0, 0, 7.5, 6, 12, 8)
    K.prism_n(M, D, 0, 0, 7.55, 8.6, 9.4, 8)
    K.frustum(M, W, 0, 0, 7.4, 3.2, 16, 20, 8)
    K.prism_n(M, O, 0, 0, 3.4, 20, 24, 8)
    K.frustum(M, O, 0, 0, 2.2, 0.6, 24, 29, 8)
    return M.finish()


def paint_pot(name, colour):
    """10 x 10 x 12: a paint jar, 8-sided, its colour showing through, a dark lid and a paper label."""
    M = K.piece(name, ROOT)
    C, D, P = m(colour), m("MK_Dark"), m("MK_Paper")
    K.prism_n(M, C, 0, 0, 4.8, 0, 9.6, 8)
    K.prism_n(M, P, 0, 0, 4.88, 3.0, 7.0, 8)
    K.frustum(M, C, 0, 0, 4.8, 4.2, 9.6, 10.2, 8)
    K.prism_n(M, D, 0, 0, 4.5, 10.2, 12, 8)
    return M.finish()


def parts_box():
    """25 x 5 x 10: a clear-lidded parts box: a body, a lid line, two latches, dividers showing."""
    M = K.piece("PartsBox", ROOT)
    Y, D, G = m("MK_Yellow"), m("MK_Dark"), m("MK_Grey")
    K.box(M, Y, -12.5, 12.5, -2.5, 2.5, 0, 7.5, 0.4)
    K.box(M, D, -12.6, 12.6, -2.6, 2.6, 7.5, 7.9, 0.4)
    K.box(M, G, -12.5, 12.5, -2.5, 2.5, 7.9, 10, 0.5, top=0.3)
    for x in (-6, 6):
        K.box(M, D, x - 1.0, x + 1.0, -2.75, 2.75, 6.2, 8.6, 0.15)
    return M.finish()


def ruler():
    """25 x 5 x 3: a steel ruler on its edge in a wooden foot, with tick marks."""
    M = K.piece("Ruler", ROOT)
    G, D, W = m("MK_Grey"), m("MK_Dark"), m("MK_Wood")
    K.box(M, W, -12.5, 12.5, -2.5, 2.5, 0, 0.8, 0.3)
    K.box(M, G, -12.3, 12.3, -0.4, 0.4, 0.8, 3.0, 0.08)
    for i in range(25):
        x = -12 + i
        h = 0.8 if i % 5 == 0 else 0.4
        for sy in (-1, 1):
            K.box(M, D, x - 0.05, x + 0.05, sy * 0.41 - 0.01, sy * 0.41 + 0.01, 3.0 - h, 2.95, 0.0)
    return M.finish()


def pencil_ramp():
    """15 (X) x 10 (Y), rising to 10 along +X: a giant hexagonal pencil leaning on the book stack (the greybox
    wedge is the walking surface): yellow body, a metal band, an eraser, a sharpened point at the floor."""
    M = K.piece("PencilRamp", ROOT)
    Y, G, R, W, D = m("MK_Yellow"), m("MK_Grey"), m("MK_Rust"), m("MK_Wood"), m("MK_Dark")
    from mathutils import Vector

    a, b = Vector((-7.5, 0, 0.0)), Vector((7.5, 0, 10.0))
    d = (b - a).normalized()
    up = Vector((0, 0, 1))
    s = d.cross(up).normalized()
    u = s.cross(d).normalized()

    import math

    # a fat pencil (11.6 across, flat-topped hexagon: corners at 0/60/120..., so the top is a 5.8-stud flat) whose top
    # face lies on the walking line; the greybox wedge underneath is hidden and keeps the collision
    R0 = 5.8
    drop = R0 * math.sin(math.pi / 3)

    def ring(c, r):
        return [tuple(c + s * (r * math.cos(t)) + u * (r * math.sin(t)) - u * drop) for t in [i * math.pi / 3 for i in range(6)]]

    L = (b - a).length
    p = lambda t: a + d * (t * L)
    M.loft([ring(p(0.0), 0.3), ring(p(0.16), R0)], W)
    M.loft([ring(p(0.0), 0.08), ring(p(0.04), 1.2)], D)
    M.loft([ring(p(0.16), R0), ring(p(0.8), R0)], Y)
    M.loft([ring(p(0.8), R0 + 0.1), ring(p(0.88), R0 + 0.1)], G)
    M.loft([ring(p(0.88), R0 - 0.15), ring(p(1.0), R0 - 0.15)], R)
    return M.finish()


def pencil_cup():
    """5 x 5 x 10: an 8-sided cup with pencils standing in it (they rise past the box: decor)."""
    M = K.piece("PencilCup", ROOT)
    B, Y, R = m("MK_Blue"), m("MK_Yellow"), m("MK_Red")
    K.prism_n(M, B, 0, 0, 2.45, 0, 10, 8)
    for i, (x, y) in enumerate(((-0.9, -0.6), (0.8, -0.4), (0.1, 1.0))):
        K.prism_n(M, Y if i != 1 else R, x, y, 0.55, 8, 14 + i, 6)
    return M.finish()


def book(M, mat_cover, x0, x1, y0, y1, z0, z1):
    P = m("MK_Paper")
    K.box(M, mat_cover, x0, x1, y0, y1, z0, z1, 0.25)
    K.box(M, P, x0 + 0.6, x1 + 0.05, y0 + 0.4, y1 - 0.4, z0 + 0.3, z1 - 0.3, 0.05)


def book_stack(name, sx, sz, h, mats):
    """sx x sz x h: books stacked flat, each a cover and a page block, slightly turned."""
    M = K.piece(name, ROOT)
    hx, hy = sx / 2, sz / 2
    n = len(mats)
    t = h / n
    for i, mm in enumerate(mats):
        j = 0.35 * ((-1) ** i)
        book(M, m(mm), -hx + abs(j), hx - abs(j) * 0.2, -hy + 0.2, hy - 0.2, i * t, (i + 1) * t)
    return M.finish()


def sprue_frame():
    """15 x 5 x 10: a plastic model sprue on a stand: an outer frame, runners, small parts on gates."""
    M = K.piece("SprueFrame", ROOT)
    S, D = m("MK_Sprue"), m("MK_Dark")
    K.box(M, D, -7.5, 7.5, -2.5, 2.5, 0, 0.8, 0.3)
    for x in (-7.0, 7.0):
        K.box(M, S, x - 0.5, x + 0.5, -0.5, 0.5, 0.8, 10, 0.1)
    for z in (1.3, 9.5):
        K.box(M, S, -7.0, 7.0, -0.5, 0.5, z - 0.5, z + 0.5, 0.1)
    for z in (3.8, 6.6):
        K.box(M, S, -7.0, 7.0, -0.3, 0.3, z - 0.3, z + 0.3, 0.06)
    for x in (-4.5, 0, 4.5):
        K.box(M, S, x - 0.3, x + 0.3, -0.3, 0.3, 1.3, 9.5, 0.06)
        for z in (2.5, 5.2, 8.1):
            K.box(M, S, x + 0.8, x + 2.6, -0.45, 0.45, z - 0.7, z + 0.7, 0.15)
    return M.finish()


def craft_knife():
    """15 x 5 x 3: a craft knife lying on its side on a cutting block: a hex handle, a collet, a wedge blade."""
    M = K.piece("CraftKnife", ROOT)
    B, G, D = m("MK_Blue"), m("MK_Grey"), m("MK_Dark")
    hexa = K.ngon(0, 1.5, 1.4, 6)
    M.loft([[(-7.5, u, v) for u, v in hexa], [(3.0, u, v) for u, v in hexa]], B)
    ring = K.ngon(0, 1.5, 1.2, 6)
    M.loft([[(3.0, u, v) for u, v in ring], [(4.5, u, v) for u, v in ring]], D)
    M.loft([[(4.5, -0.15, 0.4), (4.5, 0.15, 0.4), (4.5, 0.15, 2.6), (4.5, -0.15, 2.6)], [(7.5, -0.05, 0.4), (7.5, 0.05, 0.4), (7.5, 0.05, 0.6), (7.5, -0.05, 0.6)]], G)
    return M.finish()


def tape_roll():
    """10 x 10 x 7: a roll of masking tape lying flat: an 8-sided ring with a cardboard core."""
    M = K.piece("TapeRoll", ROOT)
    T, W = m("MK_Tape"), m("MK_Wood")
    ro, ri, rc = K.ngon(0, 0, 4.95, 8), K.ngon(0, 0, 2.8, 8), K.ngon(0, 0, 2.4, 8)
    for i in range(8):
        M.prism([ro[i], ro[(i + 1) % 8], ri[(i + 1) % 8], ri[i]], 0, 7, T)
        M.prism([ri[i], ri[(i + 1) % 8], rc[(i + 1) % 8], rc[i]], 0, 7, W)
    return M.finish()


def desk_lamp():
    """Landmark (decor, beyond the edge): an angle-poise desk lamp: a heavy base, two arms, a faceted shade
    with a warm glow, towering over the bench."""
    M = K.piece("DeskLamp", ROOT)
    D, R, G = m("MK_Dark"), m("MK_Red"), m("MK_White")
    K.frustum(M, D, 0, 0, 9, 7, 0, 3, 8)
    K.bar(M, R, (0, 0, 3), (-8, 0, 32), 1.4)
    K.bar(M, R, (-8, 0, 32), (-30, 0, 44), 1.2)
    K.box(M, D, -9.5, -6.5, -1.5, 1.5, 30.5, 33.5, 0.4)
    K.frustum(M, R, -32, 0, 2.5, 8.0, 46, 36, 8)
    K.prism_n(M, G, -32, 0, 7.2, 35.6, 36.2, 8)
    return M.finish()


def build_all():
    K.clear_theme(ROOT)
    made = [glue_pot(), paint_pot("PaintPotRed", "MK_Red"), paint_pot("PaintPotBlue", "MK_Blue"), parts_box(), ruler(),
            pencil_ramp(), pencil_cup(), book_stack("BookTop", 15, 20, 10, ["MK_Purple", "MK_Rust", "MK_Blue"]),
            book_stack("BookStep", 15, 10, 7, ["MK_Rust", "MK_Purple"]), book_stack("BookStepLow", 10, 5, 3.5, ["MK_Rust"]),
            sprue_frame(), craft_knife(), tape_roll(), desk_lamp()]
    K.tag("MK_")
    return K.tris(made)
