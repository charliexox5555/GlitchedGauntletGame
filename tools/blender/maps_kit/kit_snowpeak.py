"""Snowpeak kit (maps overnight run, 2026-11-16). A ski lodge in snow; red trim = the accent. Each piece fills its
greybox box (tools/maps/map_plans.py SNOWPEAK).
"""
import kitlib as K

ROOT = "SnowpeakKit"
K.PAL.update(
    {
        "SP_Log": ("#8A5A3C", 0.85),
        "SP_LogDark": ("#5F3E2A", 0.85),
        "SP_Red": ("#B33A2E", 0.7),
        "SP_Snow": ("#F2F5F8", 0.9),
        "SP_Stone": ("#8E949B", 0.85),
        "SP_Pine": ("#2F5E45", 0.85),
        "SP_PineDark": ("#244A37", 0.85),
        "SP_Glass": ("#3E4E5E", 0.4),
        "SP_Steel": ("#5A6068", 0.6),
        "SP_WarmGlow": ("#F2C98A", 0.5),
    }
)
m = K.mat


def lodge_wall(name, sx, sz, door=False):
    """sx x sz x 12: a log wall: stacked log courses (alternating, carved ends), red trim at the top, windows."""
    M = K.piece(name, ROOT)
    L, LD, R, G, Gl = m("SP_Log"), m("SP_LogDark"), m("SP_Red"), m("SP_Glass"), m("SP_WarmGlow")
    hx, hy = sx / 2, sz / 2
    K.box(M, m("SP_Stone"), -hx, hx, -hy, hy, 0, 1.2, 0.25)
    z, k = 1.2, 0
    while z < 11.0:
        inset = 0.15 if k % 2 else 0.0
        K.box(M, L if k % 2 else LD, -hx + inset, hx - inset, -hy + inset, hy - inset, z, z + 0.98, 0.35)
        z += 1.0
        k += 1
    K.box(M, R, -hx, hx, -hy, hy, 11.2, 12, 0.25, top=0.2)
    if sx > sz:
        for sgn in (-1, 1):
            K.box(M, R, -2.0, 2.0, sgn * hy - 0.12, sgn * hy + 0.12, 5.0, 8.4, 0.05)
            K.box(M, Gl, -1.6, 1.6, sgn * (hy + 0.13) - 0.03, sgn * (hy + 0.13) + 0.03, 5.4, 8.0, 0.02)
    return M.finish()


def lodge_roof():
    """40 x 30, from 12 up: a steep gable roof of plank panels with red bargeboards and a snow cap on the
    ridge, gable ends with a window. Decor (the greybox part is the collision)."""
    M = K.piece("LodgeRoof", ROOT)
    LD, R, S, G = m("SP_LogDark"), m("SP_Red"), m("SP_Snow"), m("SP_WarmGlow")
    K.gable_roof(M, LD, -20, 20, -15, 15, 0, 10, eave=1.2, thick=0.8, along="x")
    K.gable_roof(M, S, -20, 20, -15, 15, 0.8, 10, eave=1.0, thick=0.35, along="x")
    for sx in (-1, 1):
        K.gable_end(M, LD, -15, 15, 0, 0, 10, 0.6) if False else None
        x = sx * 20
        M.loft([[(x - 0.3, -15, 0), (x - 0.3, 15, 0), (x - 0.3, 0, 10)], [(x + 0.3, -15, 0), (x + 0.3, 15, 0), (x + 0.3, 0, 10)]], LD)
        K.box(M, G, x - 0.45 if sx > 0 else x + 0.15, x - 0.15 if sx > 0 else x + 0.45, -2.0, 2.0, 2.5, 6.0, 0.05)
        for sy in (-1, 1):
            K.bar(M, R, (x + sx * 0.4, sy * 16.2, -0.2), (x + sx * 0.4, 0, 10.5), 0.5)
    return M.finish()


def pine():
    """5 x 5 x 16: a faceted pine with snow on its tiers."""
    M = K.piece("Pine", ROOT)
    K.pine(M, m("SP_Pine"), m("SP_LogDark"), 0, 0, 16, 2.6, tiers=4)
    K.frustum(M, m("SP_Snow"), 0, 0, 1.2, 0.2, 14.2, 16.2, 7)
    return M.finish()


def woodpile(name, sx, sz):
    """sx x sz x 10: split logs (hexagonal ends) stacked under a lean-to roof with snow."""
    M = K.piece(name, ROOT)
    L, LD, S, R = m("SP_Log"), m("SP_LogDark"), m("SP_Snow"), m("SP_Red")
    hx, hy = sx / 2, sz / 2
    for sx_ in (-1, 1):
        K.box(M, LD, sx_ * (hx - 0.4) - 0.3, sx_ * (hx - 0.4) + 0.3, -hy + 0.3, hy - 0.3, 0, 9.0, 0.08)
    n = int((sx - 1.2) // 1.4)
    for row in range(5):
        z = 0.7 + row * 1.35
        for i in range(n):
            x = -hx + 1.0 + i * 1.4 + (0.7 if row % 2 else 0)
            if x > hx - 1.0:
                continue
            hexa = K.ngon(x, z, 0.68, 6)
            M.loft([[(u, -hy + 0.4, v) for u, v in hexa], [(u, hy - 0.4, v) for u, v in hexa]], L)
    M.loft([[(-hx, -hy, 8.6), (hx, -hy, 8.6), (hx, hy, 9.6), (-hx, hy, 9.6)], [(-hx, -hy, 9.0), (hx, -hy, 9.0), (hx, hy, 10.0), (-hx, hy, 10.0)]], R)
    return M.finish()


def shed(name, sx, sz, color="SP_Red"):
    """sx x sz x 10: a plank shed (red or log) with a door, a snow-capped roof."""
    M = K.piece(name, ROOT)
    W, LD, S = m(color), m("SP_LogDark"), m("SP_Snow")
    hx, hy = sx / 2, sz / 2
    K.box(M, m("SP_Stone"), -hx, hx, -hy, hy, 0, 0.8, 0.2)
    K.box(M, W, -hx + 0.3, hx - 0.3, -hy + 0.3, hy - 0.3, 0.8, 7.6, 0.25)
    for k in range(int(sx // 1.25)):
        x = -hx + 0.6 + k * 1.25
        K.box(M, LD, x - 0.08, x + 0.08, -hy + 0.18, -hy + 0.32, 0.8, 7.6, 0.02)
    K.box(M, LD, -1.6, 1.6, -hy + 0.1, -hy + 0.3, 0.8, 6.0, 0.05)
    K.gable_roof(M, LD, -hx + 0.3, hx - 0.3, -hy + 0.3, hy - 0.3, 7.6, 2.0, eave=0.3, thick=0.35, along="x")
    K.gable_roof(M, S, -hx + 0.3, hx - 0.3, -hy + 0.3, hy - 0.3, 7.95, 2.0, eave=0.2, thick=0.25, along="x")
    return M.finish()


def snowbank():
    """15 x 5 x 3: a faceted snow mound with a few stones."""
    M = K.piece("Snowbank", ROOT)
    S, St = m("SP_Snow"), m("SP_Stone")
    M.loft([[(x, y, 0) for x, y in K.cham(-7.5, 7.5, -2.5, 2.5, 1.2)], [(x, y, 1.8) for x, y in K.cham(-6.6, 6.6, -1.9, 1.9, 1.0)],
            [(x, y, 3.0) for x, y in K.cham(-4.5, 4.5, -0.8, 0.8, 0.5)]], S)
    K.frustum(M, St, 5.5, 1.4, 0.9, 0.5, 0, 1.2, 6)
    return M.finish()


def ski_rack():
    """5 x 10 x 3: a rack with skis leaning on it (red skis, faceted)."""
    M = K.piece("SkiRack", ROOT)
    LD, R, St = m("SP_LogDark"), m("SP_Red"), m("SP_Steel")
    for sy in (-1, 1):
        K.box(M, LD, -0.3, 0.3, sy * 4.4 - 0.3, sy * 4.4 + 0.3, 0, 2.6, 0.06)
    K.bar(M, LD, (0, -4.6, 2.4), (0, 4.6, 2.4), 0.35)
    for k in range(5):
        y = -3.6 + k * 1.8
        K.bar(M, R, (-1.8, y, 0.05), (0.1, y + 0.3, 3.0), 0.5, 0.12)
    return M.finish()


def hearth():
    """5 x 5 x 12 (+ to 24): a stone chimney stack through the lodge roof with a cap."""
    M = K.piece("Hearth", ROOT)
    St, LD = m("SP_Stone"), m("SP_LogDark")
    K.box(M, St, -2.5, 2.5, -2.5, 2.5, 0, 23, 0.35)
    K.box(M, St, -2.8, 2.8, -2.8, 2.8, 23, 24, 0.4, top=0.3)
    K.box(M, LD, -1.6, 1.6, -2.55, -2.45, 0, 3.0, 0.05)
    return M.finish()


def porch():
    """10 x 5 x 3: plank steps up to the lodge door."""
    M = K.piece("Porch", ROOT)
    L, LD = m("SP_Log"), m("SP_LogDark")
    K.box(M, LD, -5, 5, -2.5, 2.5, 0, 1.5, 0.15)
    K.box(M, L, -4.6, 4.6, -2.5, 0.8, 1.5, 3.0, 0.15)
    return M.finish()


def gondola_station():
    """Landmark (decor, beyond the north-east corner): a red gondola station on stilts, a bull-wheel housing,
    the cable running off the map, one gondola cabin."""
    M = K.piece("GondolaStation", ROOT)
    R, LD, St, G, S = m("SP_Red"), m("SP_LogDark"), m("SP_Steel"), m("SP_Glass"), m("SP_Snow")
    for sx in (-1, 1):
        for sy in (-1, 1):
            K.box(M, St, sx * 8 - 0.6, sx * 8 + 0.6, sy * 6 - 0.6, sy * 6 + 0.6, 0, 14, 0.12)
    K.box(M, LD, -10, 10, -8, 8, 14, 15, 0.3)
    K.box(M, R, -9, 9, -7, 7, 15, 22, 0.3)
    K.window_grid(M, LD, G, "y", -7, -8, 8, 16, 21, 4, 1, out=-1)
    K.gable_roof(M, LD, -9, 9, -7, 7, 22, 4, eave=0.8, thick=0.5, along="x")
    K.gable_roof(M, S, -9, 9, -7, 7, 22.5, 4, eave=0.6, thick=0.3, along="x")
    K.prism_n(M, St, 12, 0, 3.5, 18, 20, 10)
    for sy in (-1.6, 1.6):
        K.bar(M, St, (12, sy, 19), (120, sy, 70), 0.25)
    K.bar(M, St, (40, -1.6, 32.2), (40, -1.6, 27), 0.3)
    K.box(M, R, 38.2, 41.8, -3.4, 0.2, 22.5, 27, 0.4)
    K.box(M, G, 38.1, 41.9, -3.2, 0.0, 24, 26.2, 0.05)
    return M.finish()


def build_all():
    K.clear_theme(ROOT)
    made = [lodge_wall("LodgeWall10x5", 10, 5), lodge_wall("LodgeWall5x10", 5, 10), lodge_roof(), pine(),
            woodpile("Woodpile20x5", 20, 5), shed("SledShed", 15, 10), shed("Woodshed", 10, 10, color="SP_Log"), snowbank(),
            ski_rack(), hearth(), porch(), gondola_station()]
    K.tag("SP_")
    return K.tris(made)
