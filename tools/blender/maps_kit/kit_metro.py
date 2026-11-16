"""Metro kit (maps overnight run, 2026-11-16). A station: concrete and tile, yellow line = the accent. Each piece
fills its greybox box (tools/maps/map_plans.py METRO).
"""
import kitlib as K

ROOT = "MetroKit"
K.PAL.update(
    {
        "MT_Tile": ("#E4E6EA", 0.6),
        "MT_Concrete": ("#C9CBD0", 0.85),
        "MT_ConcreteDark": ("#8D9197", 0.85),
        "MT_Steel": ("#5E646B", 0.6),
        "MT_SteelDark": ("#3E434A", 0.6),
        "MT_Yellow": ("#C2413A", 0.55),
        "MT_TrainBody": ("#D3D6DB", 0.5),
        "MT_TrainDark": ("#2F343B", 0.5),
        "MT_Glass": ("#33414F", 0.35),
        "MT_SignGlow": ("#F4F1E6", 0.5),
    }
)
m = K.mat


def train_car():
    """10 x 50 x 13 (from the trench floor): a train car: bogies, a body with a window band and doors, a yellow
    stripe, a roof with vents, cab ends cut back."""
    M = K.piece("TrainCar", ROOT)
    B, D, Y, G, S = m("MT_TrainBody"), m("MT_TrainDark"), m("MT_Yellow"), m("MT_Glass"), m("MT_Steel")
    for y in (-17, 17):
        K.box(M, D, -4.2, 4.2, y - 4, y + 4, 0, 2.4, 0.3)
        for yy in (y - 2.2, y + 2.2):
            for sx in (-1, 1):
                hexa = K.ngon(yy, 1.3, 1.2, 6)
                M.loft([[(sx * 4.3, u, v) for u, v in hexa], [(sx * 3.7, u, v) for u, v in hexa]], S)
    M.loft([[(x, y, 2.4) for x, y in K.cham(-5, 5, -24, 24, 0.5)], [(x, y, 11.6) for x, y in K.cham(-5, 5, -24, 24, 0.5)],
            [(x, y, 13) for x, y in K.cham(-4.2, 4.2, -23, 23, 0.6)]], B)
    for sgn in (-1, 1):  # cab ends
        M.loft([[(x, sgn * 24, z) for x, z in [(-4.6, 2.6), (4.6, 2.6), (4.6, 11.4), (-4.6, 11.4)]],
                [(x, sgn * 25, z) for x, z in [(-4.2, 3.0), (4.2, 3.0), (3.6, 10.2), (-3.6, 10.2)]]], B)
        K.box(M, G, -3.4, 3.4, sgn * 24.95 - 0.05, sgn * 24.95 + 0.05, 7.0, 9.8, 0.05) if False else None
    for sx in (-1, 1):
        K.box(M, Y, sx * 5.0 - 0.06, sx * 5.0 + 0.06, -24, 24, 4.0, 4.8, 0.02)
        K.window_grid(M, D, G, "x", sx * 5.0, -22, 22, 6.6, 10.6, 8, 1, out=sx, border=0.5)
        for y in (-12, 12):
            K.box(M, D, sx * 5.0 - 0.1 if sx < 0 else sx * 5.0, sx * 5.0 if sx < 0 else sx * 5.0 + 0.1, y - 2.0, y + 2.0, 2.6, 10.8, 0.05)
    for y in (-14, 0, 14):
        K.box(M, S, -2, 2, y - 3, y + 3, 12.8, 13.6, 0.3)
    return M.finish()


def column():
    """5 x 5 x 22: a tiled column with a base, a yellow band at head height and a flared capital."""
    M = K.piece("Column", ROOT)
    T, C, Y = m("MT_Tile"), m("MT_ConcreteDark"), m("MT_Yellow")
    K.box(M, C, -2.5, 2.5, -2.5, 2.5, 0, 1.2, 0.3, top=0.2)
    K.box(M, T, -2.1, 2.1, -2.1, 2.1, 1.2, 19.5, 0.35)
    K.box(M, Y, -2.15, 2.15, -2.15, 2.15, 6.5, 7.3, 0.35)
    M.loft([[(x, y, 19.5) for x, y in K.cham(-2.1, 2.1, -2.1, 2.1, 0.35)], [(x, y, 21.4) for x, y in K.cham(-2.5, 2.5, -2.5, 2.5, 0.35)]], C)
    K.box(M, C, -2.5, 2.5, -2.5, 2.5, 21.4, 22, 0.35)
    return M.finish()


def kiosk():
    """10 x 10 x 10: a news kiosk: a counter, glass sides, a yellow sign band, a flat canopy."""
    M = K.piece("Kiosk", ROOT)
    Y, D, G, C, S = m("MT_Yellow"), m("MT_SteelDark"), m("MT_Glass"), m("MT_Concrete"), m("MT_SignGlow")
    K.box(M, D, -5, 5, -5, 5, 0, 0.8, 0.3)
    K.box(M, C, -4.6, 4.6, -4.6, 4.6, 0.8, 3.6, 0.3)
    for sx in (-1, 1):
        K.box(M, D, sx * 4.4 - 0.25, sx * 4.4 + 0.25, -4.6, 4.6, 3.6, 8.2, 0.05)
        K.box(M, G, sx * 4.3 - 0.06, sx * 4.3 + 0.06, -4.2, 4.2, 3.8, 8.0, 0.02)
    K.box(M, Y, -5, 5, -5, 5, 8.2, 9.4, 0.3)
    K.box(M, S, -3.5, 3.5, -5.05, -4.95, 8.4, 9.2, 0.02)
    K.box(M, D, -5, 5, -5, 5, 9.4, 10, 0.35, top=0.2)
    return M.finish()


def vending():
    """5 x 10 x 10: two vending machines side by side, glowing fronts on the -X face."""
    M = K.piece("Vending", ROOT)
    Y, D, S, G = m("MT_Yellow"), m("MT_SteelDark"), m("MT_SignGlow"), m("MT_Glass")
    for y in (-2.5, 2.5):
        K.box(M, D, -2.5, 2.5, y - 2.4, y + 2.4, 0, 9.6, 0.25)
        K.box(M, G, -2.6, -2.5, y - 1.9, y + 0.9, 3.0, 8.6, 0.03)
        K.box(M, S, -2.62, -2.55, y + 1.2, y + 2.0, 5.0, 7.0, 0.02)
        K.box(M, Y, -2.55, 2.55, y - 2.45, y + 2.45, 9.0, 9.6, 0.25)
    return M.finish()


def stairwell():
    """15 x 20 x 10: a stair entrance down to the street: tiled walls, a glass roof canopy, a yellow sign."""
    M = K.piece("Stairwell", ROOT)
    T, C, Y, G, S, D = m("MT_Tile"), m("MT_ConcreteDark"), m("MT_Yellow"), m("MT_Glass"), m("MT_SignGlow"), m("MT_SteelDark")
    K.box(M, C, -7.5, 7.5, -10, 10, 0, 0.8, 0.3)
    K.box(M, T, -7.2, 7.2, -9.7, 9.7, 0.8, 8.8, 0.35)
    K.box(M, D, -7.5, 7.5, -10, 10, 8.8, 9.4, 0.3)
    K.box(M, G, -6.5, 6.5, -9.0, 9.0, 9.4, 10, 0.3, top=0.2)
    K.box(M, Y, -3.0, 3.0, -10.1, -9.7, 6.4, 8.2, 0.1)
    K.box(M, S, -2.4, 2.4, -10.15, -10.05, 6.7, 7.9, 0.02)
    return M.finish()


def map_board():
    """10 x 5 x 10: a network map board on two posts, a yellow frame, a glowing map panel both sides."""
    M = K.piece("MapBoard", ROOT)
    Y, D, S = m("MT_Yellow"), m("MT_SteelDark"), m("MT_SignGlow")
    for x in (-4.0, 4.0):
        K.box(M, D, x - 0.4, x + 0.4, -0.4, 0.4, 0, 3.0, 0.1)
    K.box(M, Y, -5, 5, -0.6, 0.6, 3.0, 10, 0.3)
    for sgn in (-1, 1):
        K.box(M, S, -4.2, 4.2, sgn * 0.6 - 0.05, sgn * 0.6 + 0.05, 3.8, 9.2, 0.02)
        for k in range(3):
            K.box(M, D, -3.8, 3.8, sgn * 0.66 - 0.02, sgn * 0.66 + 0.02, 5 + k * 1.4, 5.2 + k * 1.4, 0.0)
    return M.finish()


def ticket_gates():
    """15 x 5 x 3: four ticket gates with yellow paddles."""
    M = K.piece("TicketGates", ROOT)
    D, Y, S = m("MT_SteelDark"), m("MT_Yellow"), m("MT_SignGlow")
    for i in range(5):
        x = -7.0 + i * 3.5
        K.box(M, D, x - 0.6, x + 0.6, -2.5, 2.5, 0, 3.0, 0.2, top=0.15)
        K.box(M, S, x - 0.3, x + 0.3, -2.0, -1.0, 3.0, 3.02, 0.0)
        if i < 4:
            K.box(M, Y, x + 0.6, x + 1.6, -0.15, 0.15, 1.2, 2.4, 0.1)
    return M.finish()


def spawn_wall():
    """30 x 5 x 12: a tiled wall with a station name sign (blank yellow band with a glowing plate)."""
    M = K.piece("SpawnWall", ROOT)
    T, C, Y, S = m("MT_Tile"), m("MT_ConcreteDark"), m("MT_Yellow"), m("MT_SignGlow")
    K.box(M, C, -15, 15, -2.5, 2.5, 0, 1.0, 0.3)
    K.box(M, T, -14.7, 14.7, -2.2, 2.2, 1.0, 11.4, 0.3)
    K.box(M, C, -15, 15, -2.5, 2.5, 11.4, 12, 0.3)
    for sgn in (-1, 1):
        K.box(M, Y, -15, 15, sgn * 2.2 - 0.06, sgn * 2.2 + 0.06, 6.6, 7.4, 0.02)
        K.box(M, S, -7, 7, sgn * 2.3 - 0.05, sgn * 2.3 + 0.05, 8.2, 10.2, 0.05)
    return M.finish()


def footbridge():
    """70 x 10 deck from 9 to 12, built relative to its base (+9): a steel truss bridge with handrails."""
    M = K.piece("Footbridge", ROOT)
    S, D, Y = m("MT_Steel"), m("MT_SteelDark"), m("MT_Yellow")
    K.box(M, D, -35, 35, -5, 5, 0, 2.4, 0.3)
    K.box(M, S, -35, 35, -5, 5, 2.4, 3.0, 0.2)
    for sy in (-1, 1):
        K.railing(M, S, [(-34.5, sy * 4.6, 3.0), (34.5, sy * 4.6, 3.0)], h=3.4, every=3.5)
        K.box(M, Y, -35, 35, sy * 4.8 - 0.1, sy * 4.8 + 0.1, 2.0, 2.4, 0.02)
        for k in range(14):
            x = -32.5 + k * 5
            K.bar(M, D, (x, sy * 5.1, 0.2), (x + 2.5, sy * 5.1, 2.2), 0.35)
    return M.finish()


def station_clock():
    """Landmark (decor): a two-faced station clock hanging from the roof on rods, yellow rim."""
    M = K.piece("StationClock", ROOT)
    Y, D, S = m("MT_Yellow"), m("MT_SteelDark"), m("MT_SignGlow")
    for x in (-1.5, 1.5):
        K.box(M, D, x - 0.15, x + 0.15, -0.15, 0.15, 3.0, 8.0, 0.03)
    import math

    face = [(4.2 * math.cos(math.pi / 12 + 2 * math.pi * i / 12), 4.2 * math.sin(math.pi / 12 + 2 * math.pi * i / 12)) for i in range(12)]
    inner = [(3.6 * u / 4.2, 3.6 * v / 4.2) for u, v in face]
    M.loft([[(u, -0.7, v) for u, v in face], [(u, 0.7, v) for u, v in face]], Y)
    for sgn in (-1, 1):
        M.loft([[(u, sgn * 0.7, v) for u, v in inner], [(u, sgn * 0.78, v) for u, v in inner]], S)
        K.bar(M, D, (0, sgn * 0.82, 0), (0, sgn * 0.82, 2.8), 0.25, 0.08)
        K.bar(M, D, (0, sgn * 0.82, 0), (1.9, sgn * 0.82, -0.6), 0.25, 0.08)
    return M.finish()


def build_all():
    K.clear_theme(ROOT)
    made = [train_car(), column(), kiosk(), vending(), stairwell(), map_board(), ticket_gates(), spawn_wall(), footbridge(),
            station_clock()]
    K.tag("MT_")
    return K.tris(made)
