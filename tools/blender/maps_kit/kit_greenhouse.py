"""Greenhouse kit (maps overnight run, 2026-11-16). Glass halls, green glass + white iron; plants. Each piece fills its
greybox box (tools/maps/map_plans.py GREENHOUSE). Foliage is faceted (frustum clusters), never round.
"""
import kitlib as K

ROOT = "GreenhouseKit"
K.PAL.update(
    {
        "GH_Iron": ("#E8E8E2", 0.5),
        "GH_IronDark": ("#9BA39B", 0.55),
        "GH_Wood": ("#6E4F3A", 0.8),
        "GH_Brick": ("#B07D5E", 0.85),
        "GH_Leaf": ("#3F7A47", 0.85),
        "GH_LeafLight": ("#5E9A55", 0.85),
        "GH_Glass": ("#A8D8C0", 0.3),
        "GH_Stone": ("#C9C3B6", 0.85),
        "GH_Water": ("#5C9FB0", 0.3),
        "GH_Terracotta": ("#B5643F", 0.75),
        "GH_Flower": ("#D9667A", 0.7),
    }
)
m = K.mat


def bed(name, sx, sz, hedge=True):
    """sx x sz x 10: a timber planting bed (3 high) with a faceted hedge mass to 10 and a few flowers."""
    M = K.piece(name, ROOT)
    W, L, LL, F = m("GH_Wood"), m("GH_Leaf"), m("GH_LeafLight"), m("GH_Flower")
    hx, hy = sx / 2, sz / 2
    K.box(M, W, -hx, hx, -hy, hy, 0, 3.0, 0.25, top=0.15)
    if hedge:
        M.loft([[(x, y, 3.0) for x, y in K.cham(-hx + 0.4, hx - 0.4, -hy + 0.4, hy - 0.4, 0.8)],
                [(x, y, 8.6) for x, y in K.cham(-hx + 0.2, hx - 0.2, -hy + 0.2, hy - 0.2, 1.0)],
                [(x, y, 10.0) for x, y in K.cham(-hx + 1.0, hx - 1.0, -hy + 1.0, hy - 1.0, 0.8)]], L)
        for i in range(max(2, int(max(sx, sz) // 4))):
            t = (i + 0.5) / max(2, int(max(sx, sz) // 4))
            x, y = (-hx + t * sx, hy * 0.2) if sx >= sz else (hx * 0.2, -hy + t * sz)
            K.frustum(M, LL, x, y, 1.2, 0.3, 9.6, 10.6, 6)
    return M.finish()


def palm():
    """5 x 5 x 16: a faceted palm: a ringed 6-sided trunk in a pot, a crown of angled fronds."""
    M = K.piece("Palm", ROOT)
    W, L, T = m("GH_Wood"), m("GH_Leaf"), m("GH_Terracotta")
    K.frustum(M, T, 0, 0, 2.4, 2.0, 0, 3.0, 8)
    for k in range(6):
        K.frustum(M, W, 0.1 * k, 0, 0.75 - 0.03 * k, 0.65 - 0.03 * k, 3.0 + k * 2.0, 5.0 + k * 2.0, 6)
    import math

    for i in range(7):
        a = 2 * math.pi * i / 7
        tip = (5.2 * math.cos(a) + 0.6, 5.2 * math.sin(a), 12.6)
        mid = (2.4 * math.cos(a) + 0.6, 2.4 * math.sin(a), 16.0)
        K.bar(M, L, (0.6, 0, 15.0), mid, 1.2, 0.25)
        K.bar(M, L, mid, tip, 1.0, 0.2)
    return M.finish()


def fountain():
    """15 x 15 x 3: a tiered octagonal fountain: a basin with water, a centre column and a top bowl (decor)."""
    M = K.piece("Fountain", ROOT)
    S, Wa, I = m("GH_Stone"), m("GH_Water"), m("GH_Iron")
    K.prism_n(M, S, 0, 0, 7.4, 0, 0.6, 8)
    ro, ri = K.ngon(0, 0, 7.0, 8), K.ngon(0, 0, 6.1, 8)
    for i in range(8):
        M.prism([ro[i], ro[(i + 1) % 8], ri[(i + 1) % 8], ri[i]], 0.6, 2.8, S)
    K.prism_n(M, Wa, 0, 0, 6.15, 0.6, 2.0, 8)
    K.prism_n(M, S, 0, 0, 1.0, 2.0, 5.5, 8)
    K.frustum(M, S, 0, 0, 1.2, 2.8, 5.5, 6.4, 8)
    K.prism_n(M, Wa, 0, 0, 2.5, 6.0, 6.45, 8)
    K.frustum(M, I, 0, 0, 0.5, 0.2, 6.4, 8.2, 6)
    return M.finish()


def iron_bridge():
    """60 x 10 deck from 7 to 10, built relative to its base (+7): a white iron bridge with a lattice railing."""
    M = K.piece("IronBridge", ROOT)
    I, D = m("GH_Iron"), m("GH_IronDark")
    K.box(M, D, -30, 30, -5, 5, 0, 2.4, 0.3)
    K.box(M, I, -30, 30, -5, 5, 2.4, 3.0, 0.2)
    for sy in (-1, 1):
        y = sy * 4.6
        K.bar(M, I, (-29.6, y, 6.2), (29.6, y, 6.2), 0.35)
        for k in range(20):
            x = -29 + k * 3.0
            K.bar(M, I, (x, y, 3.0), (x + 1.5, y, 6.2), 0.2)
            K.bar(M, I, (x + 3.0, y, 3.0), (x + 1.5, y, 6.2), 0.2)
    return M.finish()


def landing():
    """10 x 10 x 10: a white iron stair landing tower: four posts, cross braces, a deck with a railing."""
    M = K.piece("IronLanding", ROOT)
    I, D = m("GH_Iron"), m("GH_IronDark")
    for sx in (-1, 1):
        for sy in (-1, 1):
            K.box(M, I, sx * 4.4 - 0.5, sx * 4.4 + 0.5, sy * 4.4 - 0.5, sy * 4.4 + 0.5, 0, 9.0, 0.12)
    for sx in (-1, 1):
        K.bar(M, D, (sx * 4.4, -4.4, 1.0), (sx * 4.4, 4.4, 8.0), 0.25)
    K.box(M, D, -5, 5, -5, 5, 9.0, 10.0, 0.2)
    return M.finish()


def hall_wall(name, length):
    """5 x `length` x 3: a low brick wall with a stone coping; white iron mullions and glass above (decor to 14)."""
    M = K.piece(name, ROOT)
    B, S, I, G = m("GH_Brick"), m("GH_Stone"), m("GH_Iron"), m("GH_Glass")
    hy = length / 2
    K.box(M, B, -2.3, 2.3, -hy, hy, 0, 2.5, 0.2)
    K.box(M, S, -2.5, 2.5, -hy, hy, 2.5, 3.0, 0.25, top=0.15)
    n = int(length // 5)
    for k in range(n + 1):
        y = -hy + k * (length / n)
        K.box(M, I, -0.3, 0.3, y - 0.3, y + 0.3, 3.0, 14.0, 0.06)
    for z in (8.5, 13.6):
        K.box(M, I, -0.3, 0.3, -hy, hy, z, z + 0.4, 0.06)
    K.box(M, G, -0.08, 0.08, -hy + 0.3, hy - 0.3, 3.05, 13.6, 0.0)
    return M.finish()


def glass_case():
    """10 x 10 x 10: a glass display case on a wooden plinth with a plant inside."""
    M = K.piece("GlassCase", ROOT)
    W, I, G, L = m("GH_Wood"), m("GH_Iron"), m("GH_Glass"), m("GH_LeafLight")
    K.box(M, W, -5, 5, -5, 5, 0, 2.0, 0.25)
    for sx in (-1, 1):
        for sy in (-1, 1):
            K.box(M, I, sx * 4.6 - 0.3, sx * 4.6 + 0.3, sy * 4.6 - 0.3, sy * 4.6 + 0.3, 2.0, 9.5, 0.05)
    K.box(M, G, -4.5, 4.5, -4.5, 4.5, 2.0, 9.4, 0.05)
    K.box(M, I, -5, 5, -5, 5, 9.4, 10, 0.2, top=0.15)
    K.frustum(M, L, 0, 0, 2.2, 0.4, 2.0, 7.5, 6)
    return M.finish()


def cold_frame():
    """10 x 5 x 10: a cold frame: a brick base, a sloped glass lid on a white frame, seedlings."""
    M = K.piece("ColdFrame", ROOT)
    B, I, G, L = m("GH_Brick"), m("GH_Iron"), m("GH_Glass"), m("GH_LeafLight")
    K.box(M, B, -5, 5, -2.5, 2.5, 0, 6.0, 0.25)
    M.loft([[(-5, -2.5, 6.0), (5, -2.5, 6.0), (5, 2.5, 6.0), (-5, 2.5, 6.0)], [(-5, -2.5, 7.0), (5, -2.5, 7.0), (5, 2.5, 10.0), (-5, 2.5, 10.0)]], G)
    for x in (-4.8, 0, 4.8):
        K.bar(M, I, (x, -2.5, 7.0), (x, 2.5, 10.0), 0.3)
    return M.finish()


def potting_wall():
    """40 x 5 x 10: a potting shed wall: brick, a shelf of terracotta pots on both faces, a timber cap."""
    M = K.piece("PottingWall", ROOT)
    B, W, T, L = m("GH_Brick"), m("GH_Wood"), m("GH_Terracotta"), m("GH_Leaf")
    K.box(M, B, -20, 20, -2.2, 2.2, 0, 9.4, 0.3)
    K.box(M, W, -20, 20, -2.5, 2.5, 9.4, 10, 0.3, top=0.2)
    for sgn in (-1, 1):
        K.box(M, W, -19, 19, sgn * 2.2 - 0.3 if sgn > 0 else sgn * 2.2 - 0.0, sgn * 2.2 + 0.0 if sgn > 0 else sgn * 2.2 + 0.3, 4.6, 5.0, 0.05) if False else None
        y0, y1 = (2.2, 2.5) if sgn > 0 else (-2.5, -2.2)
        K.box(M, W, -19, 19, y0, y1, 4.6, 5.0, 0.05)
        for k in range(9):
            x = -16 + k * 4
            yc = (y0 + y1) / 2
            K.frustum(M, T, x, yc, 0.55, 0.7, 5.0, 6.0, 8)
            K.frustum(M, L, x, yc, 0.7, 0.2, 6.0, 6.9, 6)
    return M.finish()


def water_butt():
    """5 x 5 x 10: an 8-sided water butt with hoops on a brick stand, a tap."""
    M = K.piece("WaterButt", ROOT)
    W, I, B = m("GH_Wood"), m("GH_IronDark"), m("GH_Brick")
    K.box(M, B, -2.5, 2.5, -2.5, 2.5, 0, 1.6, 0.2)
    K.prism_n(M, W, 0, 0, 2.3, 1.6, 9.6, 8)
    for z in (3.0, 6.0, 9.0):
        K.prism_n(M, I, 0, 0, 2.38, z, z + 0.3, 8)
    K.prism_n(M, I, 0, 0, 2.1, 9.6, 10.0, 8)
    return M.finish()


def seed_crates():
    """5 x 10 x 7: three seed crates stacked (the top is a +7 step)."""
    M = K.piece("SeedCrates", ROOT)
    W, L = m("GH_Wood"), m("GH_LeafLight")
    K.box(M, W, -2.5, 2.5, -5, 5, 0, 3.5, 0.2)
    K.box(M, W, -2.3, 2.3, -4.8, 4.8, 3.5, 7.0, 0.2)
    for y in (-3, 0, 3):
        K.frustum(M, L, 0, y, 0.9, 0.2, 7.0, 7.6, 6)
    return M.finish()


def potting_bench():
    """15 x 5 x 3: a potting bench: a slatted top on legs, pots on it."""
    M = K.piece("PottingBench", ROOT)
    W, T, L = m("GH_Wood"), m("GH_Terracotta"), m("GH_Leaf")
    for x in (-6.8, 6.8):
        for y in (-2.0, 2.0):
            K.box(M, W, x - 0.3, x + 0.3, y - 0.3, y + 0.3, 0, 2.4, 0.05)
    for k in range(5):
        y = -2.4 + k * 1.2
        K.box(M, W, -7.5, 7.5, y, y + 1.0, 2.4, 3.0, 0.05)
    for x in (-4, 0, 4):
        K.frustum(M, T, x, 0, 0.5, 0.65, 3.0, 3.9, 8)
        K.frustum(M, L, x, 0, 0.7, 0.2, 3.9, 4.8, 6)
    return M.finish()


def dome():
    """Landmark (decor): a glass dome frame over the middle: 12 white iron ribs on a ring, faceted glass caps."""
    M = K.piece("GlassDome", ROOT)
    I, G = m("GH_Iron"), m("GH_Glass")
    import math

    R, H, n = 34.0, 30.0, 12
    levels = [(R, 14.0), (R * 0.88, 26.0), (R * 0.62, 36.0), (R * 0.3, 42.0), (2.0, 44.0)]
    ring = lambda r, z: [(r * math.cos(2 * math.pi * i / n), r * math.sin(2 * math.pi * i / n), z) for i in range(n)]
    for i in range(n):
        pts = [ring(r, z)[i] for r, z in levels]
        for a, b in zip(pts, pts[1:]):
            K.bar(M, I, a, b, 0.6)
    for r, z in levels[:-1]:
        rp = ring(r, z)
        for i in range(n):
            K.bar(M, I, rp[i], rp[(i + 1) % n], 0.5)
    for (r0, z0), (r1, z1) in zip(levels[2:], levels[3:]):
        M.loft([ring(r0 - 0.2, z0 + 0.1), ring(r1 - 0.2, z1 + 0.1)], G)
    for i in range(0, n, 3):
        p = ring(R, 14.0)[i]
        K.bar(M, I, (p[0], p[1], 0), p, 0.8)
    return M.finish()


def build_all():
    K.clear_theme(ROOT)
    made = [bed("Bed15x5", 15, 5), bed("Bed5x15", 5, 15), bed("Bed10x20", 10, 20), bed("Bed10x25", 10, 25), bed("Bed20x5", 20, 5),
            bed("Hedge5x20", 5, 20), bed("Hedge5x15", 5, 15), palm(), fountain(), iron_bridge(), landing(),
            hall_wall("HallWall60", 60), hall_wall("HallWall40", 40), glass_case(), cold_frame(), potting_wall(), water_butt(),
            seed_crates(), potting_bench(), dome()]
    K.tag("GH_")
    return K.tris(made)
