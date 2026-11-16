"""Shared helpers for the theme kits (maps overnight run, 2026-11-16). Faceted only: no round shapes (n-sided
prisms instead), chamfered edges, carved ends. Builds on arena_kit.Mesh (closed solids, flat shading).

Every piece is built at the origin, floor centre, X = Roblox X, Y = Roblox -Z (kit_bundle maps Blender (x, y, z)
to Roblox (x, z, -y)), so a piece made for a greybox box sx (X) by sz (Z) spans x +-sx/2, y +-sz/2.
"""
from math import cos, pi, radians, sin

import bpy

import arena_kit as A

PAL = A.PAL  # name -> (hex, roughness); themes add their own with a 2-letter prefix


def mat(name):
    return A.mat(name)


def cham(x0, x1, y0, y1, c):
    c = max(0.0, min(c, (x1 - x0) / 2 - 1e-3, (y1 - y0) / 2 - 1e-3))
    return A.cham(x0, x1, y0, y1, c)


def box(M, m, x0, x1, y0, y1, z0, z1, c=0.15, top=0.0):
    """A chamfered box; `top` leans the top edge in (a bevelled cap) by that much."""
    base = cham(x0, x1, y0, y1, c)
    if top <= 0:
        M.prism(base, z0, z1, m)
    else:
        t = cham(x0 + top, x1 - top, y0 + top, y1 - top, max(0.01, c - top * 0.5))
        M.loft([[(x, y, z0) for x, y in base], [(x, y, z1 - top) for x, y in base], [(x, y, z1) for x, y in t]], m)


def ngon(cx, cy, r, n=8, rot=None):
    rot = pi / n if rot is None else rot
    return [(cx + r * cos(rot + 2 * pi * i / n), cy + r * sin(rot + 2 * pi * i / n)) for i in range(n)]


def prism_n(M, m, cx, cy, r, z0, z1, n=8):
    M.prism(ngon(cx, cy, r, n), z0, z1, m)


def frustum(M, m, cx, cy, r0, r1, z0, z1, n=8):
    M.loft([[(x, y, z0) for x, y in ngon(cx, cy, r0, n)], [(x, y, z1) for x, y in ngon(cx, cy, max(r1, 0.02), n)]], m)


def bar(M, m, p, q, w=0.3, h=None):
    """A square bar from p to q (3D points), w wide, h tall (default w)."""
    from mathutils import Vector

    h = w if h is None else h
    p, q = Vector(p), Vector(q)
    d = (q - p).normalized()
    up = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
    s = d.cross(up).normalized() * (w / 2)
    u = s.cross(d).normalized() * (h / 2)
    ring = lambda c: [tuple(c - s - u), tuple(c + s - u), tuple(c + s + u), tuple(c - s + u)]
    M.loft([ring(p), ring(q)], m)


def window_grid(M, frame_m, pane_m, axis, at, a0, a1, z0, z1, cols, rows, depth=0.12, border=0.35, out=1):
    """Windows on a wall face: `axis` 'x' (face at x = at, spanning y a0..a1) or 'y' (face at y = at, spanning x).
    Panes are dark plates set `depth` proud, each ringed by a frame plate a little prouder (no booleans)."""
    w = (a1 - a0) / cols
    h = (z1 - z0) / rows
    for i in range(cols):
        for j in range(rows):
            u0, u1 = a0 + i * w + border, a0 + (i + 1) * w - border
            v0, v1 = z0 + j * h + border, z0 + (j + 1) * h - border
            for (pu0, pu1, pv0, pv1, d0, d1, mm) in (
                (u0 - 0.18, u1 + 0.18, v0 - 0.18, v1 + 0.18, 0.0, depth * 1.6, frame_m),
                (u0, u1, v0, v1, depth * 1.6, depth * 1.9, pane_m),
            ):
                if axis == "x":
                    xa, xb = (at + out * d0, at + out * d1)
                    M.prism(_rect(min(xa, xb), max(xa, xb), pu0, pu1), pv0, pv1, mm)
                else:
                    ya, yb = (at + out * d0, at + out * d1)
                    M.prism(_rect(pu0, pu1, min(ya, yb), max(ya, yb)), pv0, pv1, mm)


def _rect(x0, x1, y0, y1):
    return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


def railing(M, m, pts, h=3.0, post=0.3, every=3.0, rail=0.25):
    """Posts and two rails along a polyline at floor height pts[i] = (x, y, z)."""
    for a, b in zip(pts, pts[1:]):
        n = max(1, round(((b[0] - a[0]) ** 2 + (b[1] - a[1]) ** 2) ** 0.5 / every))
        for k in range(n + 1):
            t = k / n
            x, y, z = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t
            M.prism(cham(x - post / 2, x + post / 2, y - post / 2, y + post / 2, 0.05), z, z + h, m)
        for hh in (h * 0.5, h - rail / 2):
            bar(M, m, (a[0], a[1], a[2] + hh), (b[0], b[1], b[2] + hh), rail, rail)


def corrugated(M, m, x0, x1, y, sign, z0, z1, pitch=1.4, depth=0.25, skin=0.15):
    """Corrugated sheet along X at face y (ribs pressed toward -sign)."""
    n = max(2, round((x1 - x0) / pitch))
    p = (x1 - x0) / n
    out = []
    for i in range(n):
        a = x0 + i * p
        out += [(a, y), (a + p * 0.38, y), (a + p * 0.5, y - sign * depth), (a + p * 0.88, y - sign * depth)]
    out.append((x1, y))
    back = y - sign * (depth + skin)
    poly = out + [(x1, back), (x0, back)]
    M.prism(poly if sign > 0 else list(reversed(poly)), z0, z1, m)


def gable_roof(M, m, x0, x1, y0, y1, z0, ridge_h, eave=0.6, thick=0.5, along="x"):
    """A pitched roof: two sloped plates meeting at a ridge along `along`, with eaves past the walls."""
    if along == "x":
        ym = (y0 + y1) / 2
        for ya, yb in ((y0 - eave, ym), (y1 + eave, ym)):
            M.loft(
                [
                    [(x0 - eave, ya, z0), (x1 + eave, ya, z0), (x1 + eave, ya, z0 + thick), (x0 - eave, ya, z0 + thick)],
                    [(x0 - eave, yb, z0 + ridge_h), (x1 + eave, yb, z0 + ridge_h), (x1 + eave, yb, z0 + ridge_h + thick), (x0 - eave, yb, z0 + ridge_h + thick)],
                ],
                m,
            )
    else:
        xm = (x0 + x1) / 2
        for xa, xb in ((x0 - eave, xm), (x1 + eave, xm)):
            M.loft(
                [
                    [(xa, y0 - eave, z0), (xa, y1 + eave, z0), (xa, y1 + eave, z0 + thick), (xa, y0 - eave, z0 + thick)],
                    [(xb, y0 - eave, z0 + ridge_h), (xb, y1 + eave, z0 + ridge_h), (xb, y1 + eave, z0 + ridge_h + thick), (xb, y0 - eave, z0 + ridge_h + thick)],
                ],
                m,
            )


def gable_end(M, m, x0, x1, y, z0, ridge_h, t=0.4):
    """The triangular wall under a gable roof (at face y, spanning x0..x1)."""
    xm = (x0 + x1) / 2
    M.loft([[(x0, y - t / 2, z0), (x1, y - t / 2, z0), (xm, y - t / 2, z0 + ridge_h)], [(x0, y + t / 2, z0), (x1, y + t / 2, z0), (xm, y + t / 2, z0 + ridge_h)]], m)


def pine(M, needles, trunk, x, y, h, r, tiers=4):
    """A faceted pine: a square-ish trunk and stacked 7-sided frustum tiers."""
    prism_n(M, trunk, x, y, r * 0.16, 0, h * 0.3, 6)
    z = h * 0.18
    step = (h - z) / tiers
    for i in range(tiers):
        rr = r * (1 - i / (tiers + 0.6))
        frustum(M, needles, x, y, rr, rr * 0.2, z, z + step * 1.55, 7)
        z += step
    return M


def piece(name, root_name):
    """A Map_<name> collection under the theme root, and a Mesh writing into it."""
    root = A.coll(root_name)
    col = A.coll("Map_" + name, root)
    return A.Mesh(name, col)


def clear_theme(root_name):
    for c in [c for c in bpy.data.collections if c.name.startswith("Map_")]:
        for o in list(c.all_objects):
            me = o.data
            bpy.data.objects.remove(o, do_unlink=True)
            if me is not None and me.users == 0:
                bpy.data.meshes.remove(me)
        bpy.data.collections.remove(c)
    A.clear_coll(root_name)


def tag(prefix):
    for name, (hx, _r) in PAL.items():
        if name.startswith(prefix):
            m = bpy.data.materials.get(name)
            if m is not None:
                m["rbx_material"] = "Neon" if name.endswith("Glow") else "SmoothPlastic"
                m["rbx_color"] = hx.lstrip("#").upper()


def tris(objs):
    return {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs}
