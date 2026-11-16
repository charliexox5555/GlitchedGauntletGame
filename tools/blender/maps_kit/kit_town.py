"""Town kit for Courtyard + OldTown3 (maps overnight run, 2026-11-16). Warm stone and brick, terracotta = the
accent (awnings, roofs). Each piece fills its greybox box (tools/maps/map_plans.py COURTYARD / OLDTOWN).
"""
import kitlib as K

ROOT = "TownKit"
K.PAL.update(
    {
        "TW_Stone": ("#D8CEBD", 0.85),
        "TW_StoneDark": ("#B3A792", 0.85),
        "TW_Brick": ("#C9A48A", 0.85),
        "TW_Terracotta": ("#B5643F", 0.75),
        "TW_Cream": ("#EDE4D2", 0.8),
        "TW_Wood": ("#7E5D42", 0.8),
        "TW_WoodDark": ("#5E4430", 0.8),
        "TW_Iron": ("#3F4247", 0.6),
        "TW_Glass": ("#3E4B57", 0.4),
        "TW_Gold": ("#C9A24A", 0.5),
        "TW_Leaf": ("#5E8A4C", 0.85),
        "TW_Water": ("#5C8FA8", 0.3),
    }
)
M_ = K.mat


def clock_tower():
    """10 x 10 x 40 (+ spire to 47): stone base, brick shaft with corner pilasters and string courses, four
    octagonal clock faces with hands, a belfry with angled openings, a faceted spire."""
    M = K.piece("ClockTower", ROOT)
    S, SD, B, T, I, G, Cr = (M_(n) for n in ("TW_Stone", "TW_StoneDark", "TW_Brick", "TW_Terracotta", "TW_Iron", "TW_Gold", "TW_Cream"))
    K.box(M, SD, -5, 5, -5, 5, 0, 3, 0.3, top=0.3)
    K.box(M, B, -4.6, 4.6, -4.6, 4.6, 3, 31, 0.2)
    for sx in (-1, 1):
        for sy in (-1, 1):
            K.box(M, S, sx * 4.25 - 0.75, sx * 4.25 + 0.75, sy * 4.25 - 0.75, sy * 4.25 + 0.75, 3, 31, 0.15)
    for z in (12, 22):
        K.box(M, S, -5, 5, -5, 5, z, z + 0.8, 0.25, top=0.15)
    for (ax, at) in (("x", 4.6), ("x", -4.6), ("y", 4.6), ("y", -4.6)):
        sgn = 1 if at > 0 else -1
        if ax == "x":
            M.prism(K.ngon(0, 26.5, 2.8, 8), 0, 0, Cr) if False else None
        # clock: an octagonal plate on the face, ring, two hands
        import math
        def face_pts(r, depth):
            pts = []
            for i in range(8):
                a = math.pi / 8 + 2 * math.pi * i / 8
                u, v = r * math.cos(a), 26.5 + r * math.sin(a)
                pts.append((u, v))
            return pts
        for r, d0, d1, mm in ((3.0, 0.0, 0.25, S), (2.6, 0.25, 0.35, Cr)):
            ring = face_pts(r, 0)
            if ax == "x":
                M.loft([[(at + sgn * d0, u, v) for u, v in ring], [(at + sgn * d1, u, v) for u, v in ring]], mm)
            else:
                M.loft([[(u, at + sgn * d0, v) for u, v in ring], [(u, at + sgn * d1, v) for u, v in ring]], mm)
        if ax == "x":
            K.bar(M, I, (at + sgn * 0.4, 0, 26.5), (at + sgn * 0.4, 0, 28.5), 0.25)
            K.bar(M, I, (at + sgn * 0.4, 0, 26.5), (at + sgn * 0.4, 1.4, 26.0), 0.25)
        else:
            K.bar(M, I, (0, at + sgn * 0.4, 26.5), (0, at + sgn * 0.4, 28.5), 0.25)
            K.bar(M, I, (0, at + sgn * 0.4, 26.5), (1.4, at + sgn * 0.4, 26.0), 0.25)
    # belfry: corner posts and a cornice, angled lintels
    K.box(M, S, -5, 5, -5, 5, 31, 32, 0.3, top=0.2)
    for sx in (-1, 1):
        for sy in (-1, 1):
            K.box(M, S, sx * 4.0 - 1.0, sx * 4.0 + 1.0, sy * 4.0 - 1.0, sy * 4.0 + 1.0, 32, 38, 0.2)
    K.box(M, I, -1.0, 1.0, -1.0, 1.0, 33, 36, 0.2)  # the bell (an octagon-ish block)
    K.box(M, S, -5.2, 5.2, -5.2, 5.2, 38, 40, 0.4, top=0.4)
    M.loft([[(x, y, 40) for x, y in K.cham(-4.6, 4.6, -4.6, 4.6, 0.6)], [(x, y, 46) for x, y in K.cham(-0.4, 0.4, -0.4, 0.4, 0.1)]], T)
    K.prism_n(M, G, 0, 0, 0.25, 46, 47.5, 6)
    return M.finish()


def tower_steps():
    """20 x 20 x 3: two stepped stone tiers round the tower base."""
    M = K.piece("TowerSteps", ROOT)
    S, SD = M_("TW_Stone"), M_("TW_StoneDark")
    K.box(M, SD, -10, 10, -10, 10, 0, 1.5, 0.4, top=0.15)
    K.box(M, S, -7.5, 7.5, -7.5, 7.5, 1.5, 3, 0.35, top=0.15)
    return M.finish()


def stall(name, sx, sz):
    """A market stall in an sx (X) by sz (Y) box, 10 tall: a counter with crates of produce, four posts, a
    sloped striped awning (terracotta and cream). The awning slopes toward the long front side."""
    M = K.piece(name, ROOT)
    W, WD, T, Cr, L = (M_(n) for n in ("TW_Wood", "TW_WoodDark", "TW_Terracotta", "TW_Cream", "TW_Leaf"))
    hx, hy = sx / 2, sz / 2
    long_x = sx >= sz
    K.box(M, WD, -hx + 0.2, hx - 0.2, -hy + 0.2, hy - 0.2, 0, 0.5, 0.1)
    K.box(M, W, -hx + 0.4, hx - 0.4, -hy + 0.4, hy - 0.4, 0.5, 3.4, 0.2)  # counter
    K.box(M, WD, -hx + 0.2, hx - 0.2, -hy + 0.2, hy - 0.2, 3.4, 3.8, 0.15, top=0.1)
    for px in (-hx + 0.5, hx - 0.5):
        for py in (-hy + 0.5, hy - 0.5):
            K.box(M, WD, px - 0.3, px + 0.3, py - 0.3, py + 0.3, 3.8, 8.6 if (py > 0 if long_x else px > 0) else 9.4, 0.08)
    # produce crates on the counter
    n = max(1, int((sx if long_x else sz) // 3.2))
    for i in range(n):
        if long_x:
            cx, cy = -hx + 1.6 + i * ((sx - 3.2) / max(1, n - 1) if n > 1 else 0), 0
        else:
            cx, cy = 0, -hy + 1.6 + i * ((sz - 3.2) / max(1, n - 1) if n > 1 else 0)
        K.box(M, W, cx - 1.1, cx + 1.1, cy - 0.9, cy + 0.9, 3.8, 4.8, 0.1)
        K.frustum(M, L if i % 2 else T, cx, cy, 0.95, 0.4, 4.8, 5.5, 7)
    # awning: stripes across the long side, low edge at the front (-Y for long_x, -X otherwise)
    stripes = max(3, int((sx if long_x else sz) // 1.6))
    for i in range(stripes):
        mm = T if i % 2 == 0 else Cr
        if long_x:
            x0 = -hx + i * sx / stripes
            x1 = x0 + sx / stripes
            M.loft([[(x0, -hy - 0.2, 8.4), (x1, -hy - 0.2, 8.4), (x1, -hy - 0.2, 8.65), (x0, -hy - 0.2, 8.65)],
                    [(x0, hy, 9.6), (x1, hy, 9.6), (x1, hy, 9.85), (x0, hy, 9.85)]], mm)
        else:
            y0 = -hy + i * sz / stripes
            y1 = y0 + sz / stripes
            M.loft([[(-hx - 0.2, y0, 8.4), (-hx - 0.2, y1, 8.4), (-hx - 0.2, y1, 8.65), (-hx - 0.2, y0, 8.65)],
                    [(hx, y0, 9.6), (hx, y1, 9.6), (hx, y1, 9.85), (hx, y0, 9.85)]], mm)
    return M.finish()


def arcade(name, length):
    """An arcade walkway 10 (X) by `length` (Y), deck from 7 to 10, built relative to its base (the builder places it at +7): a stone slab with a cornice, a balustrade on
    the plaza side (+X), angled arch plates between the piers under the slab (decor)."""
    M = K.piece(name, ROOT)
    S, SD, Cr = M_("TW_Stone"), M_("TW_StoneDark"), M_("TW_Cream")
    hy = length / 2
    K.box(M, S, -5, 5, -hy, hy, 0.2, 3, 0.3, top=0.15)
    K.box(M, SD, -5, 5.2, -hy, hy, 0.0, 0.6, 0.2)
    # arch plates on the +X face between piers every 10
    for k in range(int(length // 10)):
        y0 = -hy + k * 10 + 2.5
        y1 = y0 + 5
        ym = (y0 + y1) / 2
        M.loft([[(5.0, y0, 0.0), (5.0, ym - 1.2, -1.4), (5.0, ym + 1.2, -1.4), (5.0, y1, 0.0)],
                [(5.35, y0, 0.0), (5.35, ym - 1.2, -1.4), (5.35, ym + 1.2, -1.4), (5.35, y1, 0.0)]], SD)
    # balustrade (decor, top at 13): posts and a rail on the plaza edge
    K.railing(M, Cr, [(4.5, -hy + 0.5, 3), (4.5, hy - 0.5, 3)], h=3.0, post=0.45, every=2.0, rail=0.4)
    return M.finish()


def pier():
    """5 x 5 x 7: a stone column with a base and a capital."""
    M = K.piece("ArcadePier", ROOT)
    S, SD = M_("TW_Stone"), M_("TW_StoneDark")
    K.box(M, SD, -2.5, 2.5, -2.5, 2.5, 0, 0.8, 0.3, top=0.2)
    K.prism_n(M, S, 0, 0, 1.6, 0.8, 6.2, 8)
    K.box(M, SD, -2.5, 2.5, -2.5, 2.5, 6.2, 7, 0.3, top=0.2)
    return M.finish()


def well():
    """10 x 10 x 3: an octagonal stone well curb with water, two posts and a small roof (decor above)."""
    M = K.piece("Well", ROOT)
    S, SD, W, WD, T, Wa = (M_(n) for n in ("TW_Stone", "TW_StoneDark", "TW_Wood", "TW_WoodDark", "TW_Terracotta", "TW_Water"))
    K.prism_n(M, SD, 0, 0, 4.9, 0, 0.6, 8)
    ring_o, ring_i = K.ngon(0, 0, 4.4, 8), K.ngon(0, 0, 3.3, 8)
    for i in range(8):
        M.prism([ring_o[i], ring_o[(i + 1) % 8], ring_i[(i + 1) % 8], ring_i[i]], 0.6, 3.0, S)
    K.prism_n(M, Wa, 0, 0, 3.35, 0.6, 1.4, 8)
    for sx in (-1, 1):
        K.box(M, WD, sx * 3.85 - 0.3, sx * 3.85 + 0.3, -0.3, 0.3, 3.0, 7.0, 0.08)
    K.bar(M, W, (-3.85, 0, 6.2), (3.85, 0, 6.2), 0.35)
    K.gable_roof(M, T, -4.4, 4.4, -2.4, 2.4, 7.0, 1.6, eave=0.4, thick=0.3, along="x")
    return M.finish()


def planter():
    """10 x 5 x 3: a stone trough with low faceted shrubs."""
    M = K.piece("Planter", ROOT)
    S, SD, L = M_("TW_Stone"), M_("TW_StoneDark"), M_("TW_Leaf")
    K.box(M, SD, -5, 5, -2.5, 2.5, 0, 0.5, 0.2)
    K.box(M, S, -4.8, 4.8, -2.3, 2.3, 0.5, 2.2, 0.2, top=0.15)
    for x in (-3, -0.4, 2.4):
        K.frustum(M, L, x, 0, 1.5, 0.5, 2.2, 3.0, 7)
    return M.finish()


def cart():
    """5 x 10 x 7: a wooden market cart (its plank bed is the +7 step), hexagonal wheels, shafts."""
    M = K.piece("Cart", ROOT)
    W, WD, I = M_("TW_Wood"), M_("TW_WoodDark"), M_("TW_Iron")
    for sy in (-1, 1):
        for sx in (-1, 1):
            K.prism_n(M, WD, sx * 2.3, sy * 2.6, 0.01, 0, 0, 6) if False else None
    for sy in (-2.6, 2.6):  # wheels: hexagons in the YZ plane, on both sides
        for sx in (-1, 1):
            hexa = K.ngon(sy, 2.0, 2.0, 6)
            M.loft([[(sx * 2.5, u, v) for u, v in hexa], [(sx * 2.15, u, v) for u, v in hexa]], WD)
    K.box(M, I, -2.2, 2.2, -2.8, -2.4, 1.8, 2.2, 0.05)
    K.box(M, I, -2.2, 2.2, 2.4, 2.8, 1.8, 2.2, 0.05)
    K.box(M, W, -2.1, 2.1, -5, 5, 4.0, 6.4, 0.15)  # body
    K.box(M, WD, -2.5, 2.5, -5, 5, 6.4, 7.0, 0.15, top=0.1)  # bed top
    return M.finish()


def crate_stack(name, h=10.0):
    """5 x 5 x h: two crates, the top one turned."""
    M = K.piece(name, ROOT)
    W, WD = M_("TW_Wood"), M_("TW_WoodDark")
    K.box(M, W, -2.5, 2.5, -2.5, 2.5, 0, h / 2, 0.2)
    K.box(M, W, -2.3, 2.3, -2.3, 2.3, h / 2, h, 0.2)
    for z in (h / 4, 3 * h / 4):
        K.box(M, WD, -2.55, 2.55, -2.55, 2.55, z - 0.2, z + 0.2, 0.15)
    return M.finish()


def barrel_stack():
    """5 x 5 x 10: barrels, two tiers, octagonal with iron hoops."""
    M = K.piece("Barrels", ROOT)
    W, I = M_("TW_Wood"), M_("TW_Iron")
    for z0 in (0, 5):
        M.loft([[(x, y, z0) for x, y in K.ngon(0, 0, 2.0, 8)], [(x, y, z0 + 2.5) for x, y in K.ngon(0, 0, 2.45, 8)],
                [(x, y, z0 + 5.0) for x, y in K.ngon(0, 0, 2.0, 8)]], W)
        for z in (z0 + 0.8, z0 + 4.2):
            K.prism_n(M, I, 0, 0, 2.25, z, z + 0.25, 8)
    return M.finish()


def gate_wall(name, length):
    """`length` x 5 x 10: a stone wall with a plinth, a blind arched gate (angled plates) and a cornice."""
    M = K.piece(name, ROOT)
    S, SD, W = M_("TW_Stone"), M_("TW_StoneDark"), M_("TW_WoodDark")
    hx = length / 2
    K.box(M, SD, -hx, hx, -2.5, 2.5, 0, 1.0, 0.3)
    K.box(M, S, -hx + 0.2, hx - 0.2, -2.3, 2.3, 1.0, 9.0, 0.3)
    K.box(M, SD, -hx, hx, -2.5, 2.5, 9.0, 10, 0.35, top=0.3)
    for sy in (-1, 1):  # blind gate on both faces: a dark wood door under a stepped stone arch
        y = sy * 2.3
        K.box(M, W, -2.6, 2.6, y - 0.2 if sy < 0 else y, y if sy < 0 else y + 0.2, 1.0, 6.4, 0.06)
        M.loft([[(-3.4, y, 6.4), (-1.4, y, 8.0), (1.4, y, 8.0), (3.4, y, 6.4)], [(-3.4, y + sy * 0.3, 6.4), (-1.4, y + sy * 0.3, 8.0), (1.4, y + sy * 0.3, 8.0), (3.4, y + sy * 0.3, 6.4)]], SD)
    return M.finish()


def fountain():
    """10 x 10 x 3: an octagonal basin with water and a stepped centre spout (decor above)."""
    M = K.piece("Fountain", ROOT)
    S, SD, Wa = M_("TW_Stone"), M_("TW_StoneDark"), M_("TW_Water")
    K.prism_n(M, SD, 0, 0, 4.9, 0, 0.5, 8)
    ro, ri = K.ngon(0, 0, 4.6, 8), K.ngon(0, 0, 3.8, 8)
    for i in range(8):
        M.prism([ro[i], ro[(i + 1) % 8], ri[(i + 1) % 8], ri[i]], 0.5, 2.6, S)
    K.prism_n(M, Wa, 0, 0, 3.85, 0.5, 1.8, 8)
    K.prism_n(M, SD, 0, 0, 1.0, 1.8, 3.6, 8)
    K.frustum(M, S, 0, 0, 1.8, 1.2, 3.6, 4.2, 8)
    K.prism_n(M, SD, 0, 0, 0.5, 4.2, 5.4, 8)
    return M.finish()


def house_block(name, sx, sz, h=18.0):
    """A town house block filling sx by sz by h: a stone ground floor with doors and shop windows, brick upper
    floors with window rows, a cornice, a terracotta hip roof above (decor)."""
    M = K.piece(name, ROOT)
    S, SD, B, T, G, W, Cr = (M_(n) for n in ("TW_Stone", "TW_StoneDark", "TW_Brick", "TW_Terracotta", "TW_Glass", "TW_WoodDark", "TW_Cream"))
    hx, hy = sx / 2, sz / 2
    K.box(M, SD, -hx, hx, -hy, hy, 0, 1.0, 0.3)
    K.box(M, S, -hx + 0.15, hx - 0.15, -hy + 0.15, hy - 0.15, 1.0, 6.0, 0.3)
    K.box(M, SD, -hx, hx, -hy, hy, 6.0, 6.7, 0.3, top=0.15)
    K.box(M, B, -hx + 0.3, hx - 0.3, -hy + 0.3, hy - 0.3, 6.7, h - 1.2, 0.3)
    K.box(M, Cr, -hx, hx, -hy, hy, h - 1.2, h, 0.35, top=0.3)
    cols_x, cols_y = max(2, int(sx // 6)), max(2, int(sz // 6))
    K.window_grid(M, Cr, G, "x", hx - 0.3, -hy + 1, hy - 1, 7.5, h - 2.0, cols_y, 2, out=1)
    K.window_grid(M, Cr, G, "x", -hx + 0.3, -hy + 1, hy - 1, 7.5, h - 2.0, cols_y, 2, out=-1)
    K.window_grid(M, Cr, G, "y", hy - 0.3, -hx + 1, hx - 1, 7.5, h - 2.0, cols_x, 2, out=1)
    K.window_grid(M, Cr, G, "y", -hy + 0.3, -hx + 1, hx - 1, 7.5, h - 2.0, cols_x, 2, out=-1)
    for sgn in (-1, 1):  # doors and a shop window on the long faces
        K.box(M, W, -1.6, 1.6, sgn * (hy - 0.15) - 0.15, sgn * (hy - 0.15) + 0.15, 1.0, 5.0, 0.05)
        K.box(M, G, hx * 0.35 - 2.5, hx * 0.35 + 2.5, sgn * (hy - 0.15) - 0.12, sgn * (hy - 0.15) + 0.12, 1.8, 4.8, 0.05)
    # hip roof (decor above the box)
    M.loft([[(x, y, h) for x, y in K.cham(-hx - 0.6, hx + 0.6, -hy - 0.6, hy + 0.6, 0.3)],
            [(x, y, h + 0.4) for x, y in K.cham(-hx - 0.6, hx + 0.6, -hy - 0.6, hy + 0.6, 0.3)],
            [(x, y, h + min(sx, sz) * 0.28) for x, y in K.cham(-hx * 0.25, hx * 0.25, -hy * 0.25, hy * 0.25, 0.1)]], T)
    # chimney
    K.box(M, B, hx * 0.4 - 1.0, hx * 0.4 + 1.0, hy * 0.2 - 1.0, hy * 0.2 + 1.0, h, h + min(sx, sz) * 0.28 + 1.5, 0.15)
    return M.finish()


def build_all():
    K.clear_theme(ROOT)
    made = [
        clock_tower(), tower_steps(), stall("Stall15x5", 15, 5), stall("Stall10x15", 10, 15), stall("Stall10x5", 10, 5),
        stall("Stall5x15", 5, 15), arcade("Arcade40", 40), arcade("Arcade20", 20), pier(), well(), planter(), cart(),
        crate_stack("Crates"), barrel_stack(), gate_wall("GateWall20", 20), gate_wall("GateWall30", 30), fountain(),
        house_block("Block40", 40, 40), house_block("Block30", 30, 30),
    ]
    K.tag("TW_")
    return K.tris(made)
