"""Bunker kit (maps overnight run, 2026-11-16). Concrete corridors round a light shaft; white light = the accent.
Each piece fills its greybox box (tools/maps/map_plans.py BUNKER).
"""
import kitlib as K

ROOT = "BunkerKit"
K.PAL.update(
    {
        "BK_Concrete": ("#A5A8AD", 0.85),
        "BK_ConcreteDark": ("#7B7E83", 0.85),
        "BK_Steel": ("#5E646B", 0.6),
        "BK_SteelDark": ("#40454B", 0.6),
        "BK_Hazard": ("#C65A36", 0.6),
        "BK_Locker": ("#5E6E7E", 0.6),
        "BK_Olive": ("#5E6448", 0.8),
        "BK_LightGlow": ("#E9EEF2", 0.5),
        "BK_ScreenGlow": ("#7FB3C9", 0.5),
    }
)
m = K.mat


def generator():
    """10 x 10 x 10: a generator: a plinth, a ribbed housing, radiator fins, exhaust stacks, hazard band."""
    M = K.piece("Generator", ROOT)
    C, S, D, H, L = m("BK_ConcreteDark"), m("BK_Steel"), m("BK_SteelDark"), m("BK_Hazard"), m("BK_LightGlow")
    K.box(M, C, -5, 5, -5, 5, 0, 1.0, 0.3, top=0.2)
    K.box(M, S, -4.6, 4.6, -4.2, 4.2, 1.0, 8.0, 0.4)
    for k in range(9):
        x = -3.6 + k * 0.9
        K.box(M, D, x - 0.15, x + 0.15, -4.5, 4.5, 2.0, 7.2, 0.04)
    K.box(M, H, -4.7, 4.7, -4.3, 4.3, 1.0, 1.6, 0.1)
    K.box(M, D, -4.6, 4.6, -4.2, 4.2, 8.0, 8.8, 0.3)
    for x in (-2.4, 2.4):
        K.prism_n(M, D, x, 0, 0.9, 8.8, 10, 8)
    K.box(M, L, -0.8, 0.8, -4.45, -4.25, 5.5, 6.3, 0.05)
    return M.finish()


def blast_wall():
    """20 x 5 x 14: a blast wall with a sealed blast door in a heavy frame, hazard chevrons, a lamp."""
    M = K.piece("BlastWall", ROOT)
    C, CD, S, D, H, L = m("BK_Concrete"), m("BK_ConcreteDark"), m("BK_Steel"), m("BK_SteelDark"), m("BK_Hazard"), m("BK_LightGlow")
    K.box(M, CD, -10, 10, -2.5, 2.5, 0, 1.2, 0.3)
    K.box(M, C, -9.7, 9.7, -2.3, 2.3, 1.2, 13.2, 0.3)
    K.box(M, CD, -10, 10, -2.5, 2.5, 13.2, 14, 0.3)
    for sy in (-1, 1):
        y = sy * 2.3
        K.box(M, D, -4.4, 4.4, min(y, y + sy * 0.35), max(y, y + sy * 0.35), 1.2, 9.6, 0.2)
        K.box(M, S, -3.6, 3.6, min(y, y + sy * 0.55), max(y, y + sy * 0.55), 1.4, 8.8, 0.15)
        for k in range(6):
            x = -3.3 + k * 1.3
            M.loft([[(x, y + sy * 0.56, 1.6), (x + 0.6, y + sy * 0.56, 1.6), (x + 1.1, y + sy * 0.56, 2.6), (x + 0.5, y + sy * 0.56, 2.6)],
                    [(x, y + sy * 0.6, 1.6), (x + 0.6, y + sy * 0.6, 1.6), (x + 1.1, y + sy * 0.6, 2.6), (x + 0.5, y + sy * 0.6, 2.6)]], H)
        K.box(M, L, -1.0, 1.0, min(y, y + sy * 0.3), max(y, y + sy * 0.3), 10.4, 11.0, 0.05)
    return M.finish()


def locker_row():
    """15 x 5 x 10: a double-sided bank of lockers, five doors a side with vents and handles."""
    M = K.piece("LockerRow", ROOT)
    Lk, D, S = m("BK_Locker"), m("BK_SteelDark"), m("BK_Steel")
    K.box(M, D, -7.5, 7.5, -2.5, 2.5, 0, 0.6, 0.15)
    K.box(M, Lk, -7.4, 7.4, -2.3, 2.3, 0.6, 9.6, 0.15)
    K.box(M, D, -7.5, 7.5, -2.5, 2.5, 9.6, 10, 0.15)
    for sy in (-1, 1):
        for i in range(5):
            x = -7.4 + i * 2.96 + 0.15
            K.box(M, Lk, x, x + 2.66, min(sy * 2.3, sy * 2.42), max(sy * 2.3, sy * 2.42), 0.9, 9.3, 0.05)
            for k in range(3):
                K.box(M, D, x + 0.5, x + 2.1, min(sy * 2.42, sy * 2.46), max(sy * 2.42, sy * 2.46), 7.6 + k * 0.45, 7.8 + k * 0.45, 0.0)
            K.box(M, S, x + 2.0, x + 2.3, min(sy * 2.42, sy * 2.55), max(sy * 2.42, sy * 2.55), 4.4, 5.4, 0.03)
    return M.finish()


def crate_stack():
    """5 x 5 x 10: olive ammo crates, two high, banded, stencil blocks."""
    M = K.piece("CrateStack", ROOT)
    O, D, H = m("BK_Olive"), m("BK_SteelDark"), m("BK_Hazard")
    for z0, inset in ((0, 0.0), (5, 0.2)):
        K.box(M, O, -2.5 + inset, 2.5 - inset, -2.5 + inset, 2.5 - inset, z0, z0 + 5, 0.25)
        for z in (z0 + 1.0, z0 + 4.0):
            K.box(M, D, -2.55 + inset, 2.55 - inset, -2.55 + inset, 2.55 - inset, z - 0.15, z + 0.15, 0.2)
        K.box(M, H, -1.0, 1.0, -2.6 + inset, -2.5 + inset, z0 + 2.2, z0 + 2.8, 0.02)
    return M.finish()


def console():
    """10 x 5 x 3: a control console: a sloped desk with two glowing screens and button rows."""
    M = K.piece("Console", ROOT)
    S, D, Sc = m("BK_Steel"), m("BK_SteelDark"), m("BK_ScreenGlow")
    K.box(M, D, -5, 5, -2.5, 2.5, 0, 2.0, 0.2)
    M.loft([[(-5, -2.5, 2.0), (5, -2.5, 2.0), (5, 2.5, 2.0), (-5, 2.5, 2.0)], [(-5, -2.5, 2.3), (5, -2.5, 2.3), (5, 2.5, 3.0), (-5, 2.5, 3.0)]], S)
    for x in (-2.4, 2.4):
        M.loft([[(x - 1.8, -1.6, 2.35), (x + 1.8, -1.6, 2.35), (x + 1.8, 1.6, 2.92), (x - 1.8, 1.6, 2.92)],
                [(x - 1.8, -1.6, 2.4), (x + 1.8, -1.6, 2.4), (x + 1.8, 1.6, 2.97), (x - 1.8, 1.6, 2.97)]], Sc)
    return M.finish()


def overlook():
    """10 x 10 x 7: a steel overlook platform on posts with a railing on its two open sides."""
    M = K.piece("Overlook", ROOT)
    S, D, H = m("BK_Steel"), m("BK_SteelDark"), m("BK_Hazard")
    for sx in (-1, 1):
        for sy in (-1, 1):
            K.box(M, D, sx * 4.4 - 0.5, sx * 4.4 + 0.5, sy * 4.4 - 0.5, sy * 4.4 + 0.5, 0, 6.0, 0.1)
    K.box(M, S, -5, 5, -5, 5, 6.0, 7.0, 0.15)
    K.box(M, H, -5, 5, -5.05, -4.9, 6.0, 6.4, 0.02)
    K.railing(M, S, [(-4.6, -4.6, 7.0), (4.6, -4.6, 7.0)], h=3.0, every=3.0)
    K.railing(M, S, [(-4.6, -4.6, 7.0), (-4.6, 4.6, 7.0)], h=3.0, every=3.0)
    return M.finish()


def shaft_lamp():
    """A floodlight on a bracket for the shaft rim (decor, hung under the roof edge)."""
    M = K.piece("ShaftLamp", ROOT)
    D, L = m("BK_SteelDark"), m("BK_LightGlow")
    K.box(M, D, -0.6, 0.6, -0.3, 0.3, -1.6, 0.0, 0.08)
    K.box(M, D, -1.2, 1.2, -0.9, 0.9, -2.6, -1.6, 0.2)
    K.box(M, L, -1.0, 1.0, -0.7, 0.7, -2.7, -2.6, 0.05)
    return M.finish()


def build_all():
    K.clear_theme(ROOT)
    made = [generator(), blast_wall(), locker_row(), crate_stack(), console(), overlook(), shaft_lamp()]
    K.tag("BK_")
    return K.tris(made)
