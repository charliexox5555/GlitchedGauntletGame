"""Foundry kit (maps overnight run, 2026-11-16). Steel works at dusk; molten orange = the accent (glow only).
Each piece fills its greybox box (tools/maps/map_plans.py FOUNDRY).
"""
import kitlib as K

ROOT = "FoundryKit"
K.PAL.update(
    {
        "FD_Steel": ("#5A6068", 0.6),
        "FD_SteelDark": ("#3E434A", 0.6),
        "FD_Concrete": ("#8C9096", 0.85),
        "FD_Hazard": ("#D9A23A", 0.6),
        "FD_Ingot": ("#A9AEB5", 0.45),
        "FD_Rust": ("#7A5440", 0.8),
        "FD_MoltenGlow": ("#FF7A2A", 0.4),
    }
)
m = K.mat


def press():
    """10 x 15 x 10: a hydraulic press: a base, two columns, a crown, a ram over a die, hazard stripes."""
    M = K.piece("Press", ROOT)
    S, D, C, H = m("FD_Steel"), m("FD_SteelDark"), m("FD_Concrete"), m("FD_Hazard")
    K.box(M, C, -5, 5, -7.5, 7.5, 0, 1.2, 0.3, top=0.2)
    K.box(M, D, -4.4, 4.4, -6.8, 6.8, 1.2, 3.0, 0.3)
    for sy in (-1, 1):
        K.box(M, S, -3.6, 3.6, sy * 5.5 - 1.2, sy * 5.5 + 1.2, 3.0, 9.0, 0.3)
    K.box(M, D, -5, 5, -7.5, 7.5, 8.2, 10, 0.4, top=0.3)
    K.box(M, S, -3.0, 3.0, -4.0, 4.0, 5.2, 8.2, 0.3)  # ram
    K.box(M, H, -3.2, 3.2, -4.2, 4.2, 3.0, 3.5, 0.1)
    for k in range(4):
        K.bar(M, H, (-4.45, -6.6 + k * 3.6, 1.4), (-4.45, -5.4 + k * 3.6, 2.8), 0.5, 0.1)
    return M.finish()


def hopper():
    """10 x 10 x 10: a funnel hopper on four legs, an 8-sided bin over a chute."""
    M = K.piece("Hopper", ROOT)
    S, D, R = m("FD_Steel"), m("FD_SteelDark"), m("FD_Rust")
    for sx in (-1, 1):
        for sy in (-1, 1):
            K.box(M, D, sx * 4.0 - 0.5, sx * 4.0 + 0.5, sy * 4.0 - 0.5, sy * 4.0 + 0.5, 0, 6.0, 0.1)
    K.prism_n(M, S, 0, 0, 1.0, 1.5, 3.5, 8)
    K.frustum(M, R, 0, 0, 1.4, 4.9, 3.5, 6.5, 8)
    K.prism_n(M, R, 0, 0, 4.9, 6.5, 9.4, 8)
    K.prism_n(M, D, 0, 0, 5.0, 9.4, 10, 8)
    return M.finish()


def ingot_stack(name, sx, sz):
    """sx x sz x 10: trapezoid ingots stacked crosswise in layers on pallets."""
    M = K.piece(name, ROOT)
    I, W = m("FD_Ingot"), m("FD_Rust")
    hx, hy = sx / 2, sz / 2
    K.box(M, W, -hx, hx, -hy, hy, 0, 0.8, 0.1)
    z = 0.8
    layer = 0
    while z + 1.6 <= 10.01:
        along_x = layer % 2 == 0
        n = int((sz if along_x else sx) // 1.6)
        for i in range(n):
            if along_x:
                y0 = -hy + i * (sz / n)
                y1 = y0 + sz / n
                M.loft([[(-hx, y0 + 0.1, z), (hx, y0 + 0.1, z), (hx, y1 - 0.1, z), (-hx, y1 - 0.1, z)],
                        [(-hx + 0.4, y0 + 0.4, z + 1.55), (hx - 0.4, y0 + 0.4, z + 1.55), (hx - 0.4, y1 - 0.4, z + 1.55), (-hx + 0.4, y1 - 0.4, z + 1.55)]], I)
            else:
                x0 = -hx + i * (sx / n)
                x1 = x0 + sx / n
                M.loft([[(x0 + 0.1, -hy, z), (x1 - 0.1, -hy, z), (x1 - 0.1, hy, z), (x0 + 0.1, hy, z)],
                        [(x0 + 0.4, -hy + 0.4, z + 1.55), (x1 - 0.4, -hy + 0.4, z + 1.55), (x1 - 0.4, hy - 0.4, z + 1.55), (x0 + 0.4, hy - 0.4, z + 1.55)]], I)
        z += 1.6
        layer += 1
    return M.finish()


def coil_stack():
    """5 x 5 x 10: steel coils (8-sided rings on edge? no: flat, banded) stacked two high."""
    M = K.piece("CoilStack", ROOT)
    I, D = m("FD_Ingot"), m("FD_SteelDark")
    for z0 in (0, 5):
        ro, ri = K.ngon(0, 0, 2.45, 8), K.ngon(0, 0, 1.1, 8)
        for i in range(8):
            M.prism([ro[i], ro[(i + 1) % 8], ri[(i + 1) % 8], ri[i]], z0, z0 + 4.8, I)
        for z in (z0 + 1.2, z0 + 3.6):
            K.prism_n(M, D, 0, 0, 2.5, z, z + 0.2, 8)
    return M.finish()


def ladle_cart():
    """10 x 5 x 10: a ladle (8-sided, rimmed, glowing inside) in a frame on a rail bogie."""
    M = K.piece("LadleCart", ROOT)
    S, D, R, G = m("FD_Steel"), m("FD_SteelDark"), m("FD_Rust"), m("FD_MoltenGlow")
    K.box(M, D, -5, 5, -2.5, 2.5, 0, 1.6, 0.3)
    for sx in (-1, 1):
        K.box(M, S, sx * 4.3 - 0.6, sx * 4.3 + 0.6, -2.0, 2.0, 1.6, 8.0, 0.15)
    K.frustum(M, R, 0, 0, 2.0, 3.2, 2.2, 8.6, 8)
    K.prism_n(M, D, 0, 0, 3.4, 8.6, 9.3, 8)
    K.prism_n(M, G, 0, 0, 2.8, 9.3, 9.45, 8)
    K.bar(M, S, (-4.3, 0, 7.6), (-3.1, 0, 7.6), 0.6)
    K.bar(M, S, (4.3, 0, 7.6), (3.1, 0, 7.6), 0.6)
    return M.finish()


def mould_row():
    """5 x 15 x 10: a mould rack: a frame with four stacked moulds and a guard."""
    M = K.piece("MouldRow", ROOT)
    S, D, R = m("FD_Steel"), m("FD_SteelDark"), m("FD_Rust")
    K.box(M, D, -2.5, 2.5, -7.5, 7.5, 0, 1.0, 0.2)
    for sy in (-1, 1):
        K.box(M, S, -2.4, 2.4, sy * 6.9 - 0.6, sy * 6.9 + 0.6, 1.0, 10, 0.15)
    for k in range(4):
        z = 1.4 + k * 2.15
        K.box(M, R, -2.2, 2.2, -6.2, 6.2, z, z + 1.8, 0.25, top=0.2)
    return M.finish()


def bridge():
    """10 x 10, 1 thick: a steel bridge over the channel with railings and toe boards."""
    M = K.piece("ChannelBridge", ROOT)
    S, D, H = m("FD_Steel"), m("FD_SteelDark"), m("FD_Hazard")
    K.box(M, D, -5, 5, -5, 5, 0, 1.0, 0.15)
    for sx in (-1, 1):
        K.railing(M, S, [(sx * 4.6, -4.8, 1.0), (sx * 4.6, 4.8, 1.0)], h=3.2, every=3.2)
        K.box(M, H, sx * 4.6 - 0.15, sx * 4.6 + 0.15, -5, 5, 1.0, 1.5, 0.04)
    return M.finish()


def catwalk(name, length):
    """5 (X) by `length` (Y) catwalk deck from 7 to 10, built relative to its base (+7): grating deck on
    stringers, a handrail on the open side (-X)."""
    M = K.piece(name, ROOT)
    S, D, H = m("FD_Steel"), m("FD_SteelDark"), m("FD_Hazard")
    hy = length / 2
    K.box(M, D, -2.5, 2.5, -hy, hy, 0, 2.4, 0.15)
    K.box(M, S, -2.5, 2.5, -hy, hy, 2.4, 3.0, 0.12)
    K.railing(M, S, [(-2.2, -hy + 0.3, 3.0), (-2.2, hy - 0.3, 3.0)], h=3.2, every=3.0)
    K.box(M, H, -2.5, -2.2, -hy, hy, 3.0, 3.4, 0.04)
    return M.finish()


def furnace():
    """The landmark (decor, beyond the east wall): a blast furnace: a stepped brick body, a glowing mouth
    toward the map, two chimneys 45 tall, a skip incline."""
    M = K.piece("Furnace", ROOT)
    C, S, D, R, G, H = m("FD_Concrete"), m("FD_Steel"), m("FD_SteelDark"), m("FD_Rust"), m("FD_MoltenGlow"), m("FD_Hazard")
    K.box(M, C, -10, 10, -15, 15, 0, 4, 0.5, top=0.4)
    K.frustum(M, R, 0, 0, 10, 7, 4, 22, 10)
    K.frustum(M, D, 0, 0, 7.2, 4.0, 22, 30, 10)
    K.box(M, D, -11, -9, -4, 4, 2, 10, 0.3)  # mouth frame (toward -X, the map)
    K.box(M, G, -11.4, -11.0, -3, 3, 3, 9, 0.1)
    for y in (-9, 9):
        K.prism_n(M, D, 6, y, 2.0, 0, 46, 8)
        K.prism_n(M, H, 6, y, 2.15, 40, 41.5, 8)
    K.bar(M, S, (-2, 14, 4), (2, 6, 28), 1.2)
    return M.finish()


def build_all():
    K.clear_theme(ROOT)
    made = [press(), hopper(), ingot_stack("IngotStack20x5", 20, 5), coil_stack(), ladle_cart(), mould_row(), bridge(),
            catwalk("Catwalk30", 30), furnace()]
    K.tag("FD_")
    return K.tris(made)
