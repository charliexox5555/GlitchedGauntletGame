"""ReworkVFX: the shared ability-effects mesh kit (2026-11-15 rework). LIVE Blender MCP only.

Every MCP call:

    exec(open(r"<repo>/tools/blender/rework/rw_core.py").read())
    S = rw_scene("RW_VFX")
    exec(open(r"<repo>/art-source/abilities/Rework/v03/ReworkVFX/vfx_build.py").read())
    vfx_build_fire(S)            # or vfx_build_all(S)

Spec: vault/02 Art/Ability VFX Direction.md (element signatures). Conventions follow the existing
FireVFX / IceVFX / GlitchVFX kits: every mesh sits at the world origin in its own anchor convention, is
authored at unit size, untextured and flat shaded; game code clones, sizes (from the installed Size),
colours and fades it. Blender +X forward, +Y left, +Z up; Studio maps (x, y, z) -> (-y, z, -x).

Orientation rules of this kit:
  * upright blades (flames, plates, leaf, chevron, fold panel) FACE +X: wide along Y, thin along X.
  * strokes and the ribbon run along X (strokes travel +X: head at the origin, tail at x = -1).
  * floor pieces lie in XY with their underside at z = 0; radius 1.
  * shells are centred on the origin, radius 1.
UVs: U across / around, V along the effect's travel (up, outward or along the stroke).
"""
import random
from mathutils import Euler
from mathutils import geometry as _vgeo

VFX_PRE = "ReworkVFX_"
VFX_REN = os.path.join(RW_WORK, "Renders")
VFX_WARN = []
VFX_DOUBLE_SIDED = ("ScanShell", "ScanBand", "SpikePulse")


# --- mapping 2D drawings into the kit's axes -----------------------------------------------------------
def up3(u, v, w):      # upright piece facing +X: u -> +Y (across), v -> +Z (up), w -> +X (thickness)
    return (w, u, v)


def flat3(u, v, w):    # lying piece: u -> +X, v -> +Y, w -> +Z
    return (u, v, w)


def pol(r, a_deg):
    a = math.radians(a_deg)
    return (r * math.cos(a), r * math.sin(a))


# --- mesh helpers ------------------------------------------------------------------------------------------
def vfx_finish(bm, name):
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-7, edges=bm.edges)
    loose = [v for v in bm.verts if not v.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.triangulate(bm, faces=bm.faces, quad_method="BEAUTY", ngon_method="BEAUTY")
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = False
    me.update()
    return me


def _vfx_inside(p, poly):
    x, y = p
    c = False
    n = len(poly)
    for i in range(n):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % n]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            c = not c
    return c


def vfx_relief(name, outline, ridge=(), redges=(), loops=(), map3=up3, back="mirror", fix_h=None):
    """Faceted relief solid from a drawn 2D outline (the designed silhouette).
    outline: [(u, v)] polygon, any winding, may be concave; its points stay at w = 0 (a knife edge).
    ridge: [(u, v, h)] interior points lifted to w = h. redges: index pairs into ridge kept as creases.
    loops: lists of ridge indices closed into crease loops (plateaus).
    back: "mirror" = the same relief on both faces (a blade), "flat" = flat underside at w = 0 (floor piece).
    Any triangle left flat between three outline points gets a lifted centre point, so the solid is only
    zero-thick on the outline itself."""
    out = [Vector((p[0], p[1])) for p in outline]
    area = sum(a.x * b.y - b.x * a.y for a, b in zip(out, out[1:] + out[:1]))
    if area < 0:
        out.reverse()
    n = len(out)
    poly = [(p.x, p.y) for p in out]
    for i, r in enumerate(ridge):
        if not _vfx_inside((r[0], r[1]), poly):
            VFX_WARN.append("%s: ridge point %d (%.3f, %.3f) is outside the outline" % (name, i, r[0], r[1]))
    pts = out + [Vector((r[0], r[1])) for r in ridge]
    hs = [0.0] * n + [float(r[2]) for r in ridge]
    edges = [(i, (i + 1) % n) for i in range(n)] + [(n + a, n + b) for a, b in redges]
    for lp in loops:
        lp = list(lp)
        edges += [(n + a, n + b) for a, b in zip(lp, lp[1:] + lp[:1])]
    hmax = max(hs) if ridge else 0.03
    fh = fix_h if fix_h is not None else hmax * 0.45
    for _ in range(8):
        vs, _es, fs, ov, _oe, _of = _vgeo.delaunay_2d_cdt(pts, edges, [list(range(n))], 1, 1e-7)
        src = [o[0] if o else -1 for o in ov]
        add = []
        for f in fs:
            if all(0 <= src[i] < n for i in f):
                a, b, c = (vs[i] for i in f)
                per = (a - b).length + (b - c).length + (c - a).length
                ar = abs((b - a).cross(c - a)) / 2
                inr = 2 * ar / per if per else 0.0
                add.append(((a + b + c) / 3, min(fh, inr * 0.9)))
        if not add:
            break
        for cen, h in add:
            pts.append(cen)
            hs.append(max(h, 0.002))
    h = [hs[s] if s >= 0 else 0.0 for s in src]
    bm = bmesh.new()
    top = [bm.verts.new(map3(v.x, v.y, h[i])) for i, v in enumerate(vs)]
    bot = [top[i] if h[i] <= 1e-9 else bm.verts.new(map3(v.x, v.y, -h[i] if back == "mirror" else 0.0))
           for i, v in enumerate(vs)]
    for f in fs:
        try:
            bm.faces.new([top[i] for i in f])
            bm.faces.new([bot[i] for i in reversed(f)])
        except ValueError:
            pass
    return vfx_finish(bm, name)


def vfx_sweep(name, secs, wrap=True, caps=False, closed=True):
    """Solid or strip from cross-sections. secs: loops of 3D points (same count each).
    closed: each loop closes on itself; wrap: the last section joins the first (rings)."""
    bm = bmesh.new()
    vr = [[bm.verts.new(p) for p in s] for s in secs]
    k = len(vr[0])
    m = len(vr)
    for i in range(m if wrap else m - 1):
        a, b = vr[i], vr[(i + 1) % m]
        for j in range(k if closed else k - 1):
            j2 = (j + 1) % k
            try:
                bm.faces.new((a[j], a[j2], b[j2], b[j]))
            except ValueError:
                pass
    if caps and not wrap:
        bm.faces.new(vr[0])
        bm.faces.new(list(reversed(vr[-1])))
    return vfx_finish(bm, name)


def vfx_hull(name, pts):
    bm = bmesh.new()
    for p in pts:
        bm.verts.new(p)
    bmesh.ops.convex_hull(bm, input=bm.verts)
    return vfx_finish(bm, name)


def vfx_retri(me):
    bm = bmesh.new()
    bm.from_mesh(me)
    loose = [v for v in bm.verts if not v.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bmesh.ops.triangulate(bm, faces=bm.faces, quad_method="BEAUTY", ngon_method="BEAUTY")
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = False
    me.update()
    return me


def vfx_warp(me, fn):
    for v in me.vertices:
        v.co = Vector(fn(v.co))
    me.update()
    return me


def vfx_center(me, unit_z=False):
    """Move the mesh so its bounding-box centre is the origin (unit_z: also scale it to 1 tall)."""
    cos = [v.co for v in me.vertices]
    lo = Vector([min(c[i] for c in cos) for i in range(3)])
    hi = Vector([max(c[i] for c in cos) for i in range(3)])
    cen = (lo + hi) / 2
    k = 1.0 / (hi.z - lo.z) if unit_z else 1.0
    for v in me.vertices:
        v.co = (v.co - cen) * k
    me.update()
    return me


def _vfx_ang(c, fa):
    a = math.atan2(c.y, c.x) if (abs(c.x) + abs(c.y)) > 1e-6 else fa
    while a - fa > math.pi:
        a -= 2 * math.pi
    while a - fa < -math.pi:
        a += 2 * math.pi
    return a / (2 * math.pi) + 0.5


def vfx_uv(me, mode):
    """up: U across Y, V up Z. along: U across Y, V along X. radial: U around, V outward (floor pieces).
    shell: U around, V up. spray: U around, V distance from the origin."""
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    uvl = me.uv_layers[0].data
    cos = [v.co.copy() for v in me.vertices]
    lo = Vector([min(c[i] for c in cos) for i in range(3)])
    hi = Vector([max(c[i] for c in cos) for i in range(3)])
    sz = Vector([max(hi[i] - lo[i], 1e-9) for i in range(3)])
    rmax = max(math.hypot(c.x, c.y) for c in cos) or 1.0
    lmax = max(c.length for c in cos) or 1.0
    for p in me.polygons:
        fa = math.atan2(p.center.y, p.center.x)
        for li in p.loop_indices:
            c = cos[me.loops[li].vertex_index]
            if mode == "up":
                uv = ((c.y - lo.y) / sz.y, (c.z - lo.z) / sz.z)
            elif mode == "along":
                uv = ((c.y - lo.y) / sz.y, (c.x - lo.x) / sz.x)
            elif mode == "radial":
                uv = (_vfx_ang(c, fa), math.hypot(c.x, c.y) / rmax)
            elif mode == "shell":
                uv = (_vfx_ang(c, fa), (c.z - lo.z) / sz.z)
            else:
                uv = (_vfx_ang(c, fa), c.length / lmax)
            uvl[li].uv = uv


def vfx_put(S, part, me, role, family, uv="up", ds=False):
    name = VFX_PRE + part
    old = bpy.data.objects.get(name)
    if old:
        om = old.data
        bpy.data.objects.remove(old, do_unlink=True)
        if om and om.users == 0:
            bpy.data.meshes.remove(om)
    stale = bpy.data.meshes.get(name)
    if stale and stale is not me and stale.users == 0:
        bpy.data.meshes.remove(stale)
    vfx_retri(me)
    me.name = name
    vfx_uv(me, uv)
    o = rw_obj(rw_col(S, "ReworkVFX"), name, me, role)
    o["fx_family"] = family
    o["fx_uv"] = uv
    if ds:
        o["fx_doubleSided"] = True
    return o


def vfx_clear_tmp(tag):
    """Delete this kit's temporary objects (sheet / mock copies): names ReworkVFX_<tag>..."""
    pre = VFX_PRE + tag
    for o in [o for o in bpy.data.objects if o.name.startswith(pre)]:
        dat = o.data
        bpy.data.objects.remove(o, do_unlink=True)
        if dat is not None and dat.users == 0 and dat.name.startswith(pre):
            if isinstance(dat, bpy.types.Mesh):
                bpy.data.meshes.remove(dat)
            elif isinstance(dat, bpy.types.Curve):
                bpy.data.curves.remove(dat)


def vfx_parts():
    c = bpy.data.collections.get("ReworkVFX")
    return sorted([o for o in c.objects if o.type == "MESH"], key=lambda o: o.name) if c else []


def vfx_info():
    rows = []
    for o in vfx_parts():
        me = o.data
        cos = [v.co for v in me.vertices]
        lo = [min(c[i] for c in cos) for i in range(3)]
        hi = [max(c[i] for c in cos) for i in range(3)]
        rows.append({
            "name": o.name[len(VFX_PRE):], "family": o.get("fx_family", ""), "tris": len(me.polygons),
            "size": [round(hi[i] - lo[i], 3) for i in range(3)],
            "min": [round(v, 3) for v in lo], "max": [round(v, 3) for v in hi],
            "rbx_size": [round(hi[1] - lo[1], 3), round(hi[2] - lo[2], 3), round(hi[0] - lo[0], 3)],
            "ds": bool(o.get("fx_doubleSided", False)), "role": me.materials[0].name if me.materials else "",
            "uv": o.get("fx_uv", ""),
        })
    return rows


# =============================================================================================================
# WIND: tapered strokes. Straight, very long, pointed at both ends, the tail longer than the head.
# Travel +X: head tip at the origin, tail tip at x = -1. Lying flat (wide in Y, thin in Z).
# =============================================================================================================
def vfx_build_wind(S):
    F = "Wind"
    # A: the plain flat blade, one edge straighter than the other
    out = [(0, 0), (-0.07, 0.030), (-0.20, 0.045), (-0.42, 0.034), (-1.0, 0.0), (-0.50, -0.012), (-0.22, -0.030),
           (-0.08, -0.024)]
    rid = [(-0.06, 0.004, 0.008), (-0.20, 0.008, 0.015), (-0.45, 0.010, 0.011), (-0.75, 0.004, 0.005)]
    vfx_put(S, "StrokeA", vfx_relief("a", out, rid, [(0, 1), (1, 2), (2, 3)], map3=flat3), "FxWind", F, "along")
    # B: the kinked blade: two offset blades joined by an angled step
    out = [(0, 0.012), (-0.09, 0.040), (-0.30, 0.038), (-0.40, 0.012), (-0.62, 0.008), (-1.0, -0.016),
           (-0.60, -0.030), (-0.46, -0.034), (-0.36, -0.012), (-0.10, -0.014)]
    rid = [(-0.08, 0.014, 0.012), (-0.28, 0.014, 0.019), (-0.42, -0.008, 0.017), (-0.60, -0.012, 0.011),
           (-0.82, -0.016, 0.005)]
    vfx_put(S, "StrokeB", vfx_relief("b", out, rid, [(0, 1), (1, 2), (2, 3), (3, 4)], map3=flat3), "FxWind", F,
            "along")
    # C: the split tail: one head, two prongs of different length
    out = [(0, 0), (-0.07, 0.032), (-0.20, 0.052), (-0.40, 0.052), (-1.0, 0.046), (-0.60, 0.022), (-0.40, 0.006),
           (-0.56, -0.016), (-0.80, -0.044), (-0.38, -0.046), (-0.18, -0.042), (-0.06, -0.026)]
    rid = [(-0.07, 0.004, 0.012), (-0.20, 0.006, 0.024), (-0.34, 0.006, 0.022), (-0.55, 0.034, 0.011),
           (-0.78, 0.042, 0.004), (-0.50, -0.030, 0.010), (-0.66, -0.038, 0.004)]
    vfx_put(S, "StrokeC", vfx_relief("c", out, rid, [(0, 1), (1, 2), (2, 3), (3, 4), (2, 5), (5, 6)], map3=flat3),
            "FxWind", F, "along")


# =============================================================================================================
# FIRE: hooked blade tongues. Wide belly low, a concave side, a tip that hooks over, a secondary lick.
# =============================================================================================================
def _vfx_chain(n, a=0):
    return [(a + i, a + i + 1) for i in range(n - 1)]


def vfx_build_fire(S):
    F = "Fire"
    # FlameA: leans right, strong hook, small barb on the right
    out = [(0.17, 0.0), (0.24, 0.14), (0.27, 0.30), (0.26, 0.44), (0.30, 0.61), (0.17, 0.52), (0.10, 0.49),
           (0.07, 0.60), (0.10, 0.73), (0.17, 0.84), (0.28, 0.905), (0.41, 0.90), (0.26, 1.0), (0.10, 0.90),
           (-0.04, 0.75), (-0.16, 0.58), (-0.25, 0.40), (-0.28, 0.24), (-0.25, 0.10), (-0.16, 0.0)]
    rid = [(0.0, 0.07, 0.05), (-0.02, 0.26, 0.07), (-0.05, 0.45, 0.065), (-0.04, 0.62, 0.05), (0.04, 0.78, 0.036),
           (0.17, 0.92, 0.02), (0.19, 0.36, 0.035), (0.23, 0.52, 0.014)]
    vfx_put(S, "FlameA", vfx_relief("a", out, rid, _vfx_chain(6) + [(1, 6), (6, 7)]), "FxFire", F)
    # FlameB: forked: a tall tongue hooking left and a shorter one kicking right
    out = [(0.15, 0.0), (0.24, 0.12), (0.27, 0.28), (0.25, 0.42), (0.28, 0.55), (0.35, 0.74), (0.24, 0.65),
           (0.15, 0.56), (0.08, 0.50), (0.06, 0.61), (0.03, 0.75), (-0.04, 0.87), (-0.13, 0.96), (-0.21, 1.0),
           (-0.33, 0.955), (-0.21, 0.93), (-0.14, 0.83), (-0.12, 0.69), (-0.17, 0.54), (-0.24, 0.40),
           (-0.27, 0.24), (-0.23, 0.10), (-0.14, 0.0)]
    rid = [(0.0, 0.07, 0.05), (-0.01, 0.25, 0.07), (-0.02, 0.42, 0.062), (-0.04, 0.60, 0.045),
           (-0.06, 0.76, 0.034), (-0.12, 0.90, 0.02), (0.17, 0.44, 0.04), (0.26, 0.62, 0.018)]
    vfx_put(S, "FlameB", vfx_relief("b", out, rid, _vfx_chain(6) + [(2, 6), (6, 7)]), "FxFire", F)
    # FlameC: squat and wind-blown: heavy belly, the tip rolls over to the left, a spur on the back
    out = [(0.20, 0.0), (0.31, 0.10), (0.36, 0.26), (0.33, 0.42), (0.28, 0.54), (0.37, 0.74), (0.23, 0.68),
           (0.15, 0.82), (0.03, 0.93), (-0.11, 1.0), (-0.26, 0.97), (-0.38, 0.87), (-0.43, 0.74), (-0.31, 0.83),
           (-0.18, 0.84), (-0.09, 0.76), (-0.07, 0.62), (-0.14, 0.48), (-0.26, 0.36), (-0.33, 0.22),
           (-0.30, 0.08), (-0.20, 0.0)]
    rid = [(0.0, 0.07, 0.055), (0.02, 0.25, 0.075), (0.07, 0.44, 0.07), (0.10, 0.62, 0.055), (0.03, 0.80, 0.04),
           (-0.12, 0.92, 0.03), (-0.30, 0.88, 0.016), (0.29, 0.66, 0.014)]
    vfx_put(S, "FlameC", vfx_relief("c", out, rid, _vfx_chain(7) + [(3, 7)]), "FxFire", F)
    # FlameTall: the wall tongue, 2.2 tall: an S-curve with a lick on each side and a hooked top
    out = [(0.22, 0.0), (0.33, 0.18), (0.36, 0.42), (0.31, 0.66), (0.36, 0.82), (0.47, 1.04), (0.31, 0.93),
           (0.23, 1.04), (0.21, 1.22), (0.24, 1.42), (0.22, 1.62), (0.14, 1.82), (0.02, 1.98), (-0.10, 2.12),
           (-0.21, 2.20), (-0.35, 2.13), (-0.21, 2.09), (-0.11, 1.95), (-0.06, 1.77), (-0.08, 1.60),
           (-0.15, 1.50), (-0.38, 1.63), (-0.31, 1.40), (-0.34, 1.16), (-0.30, 0.94), (-0.24, 0.76),
           (-0.31, 0.54), (-0.36, 0.30), (-0.31, 0.12), (-0.20, 0.0)]
    rid = [(0.0, 0.10, 0.07), (0.01, 0.36, 0.10), (0.02, 0.62, 0.09), (-0.03, 0.90, 0.08), (-0.06, 1.18, 0.08),
           (-0.02, 1.44, 0.07), (0.04, 1.68, 0.055), (0.02, 1.86, 0.04), (-0.09, 2.04, 0.025),
           (0.34, 0.90, 0.02), (-0.27, 1.48, 0.02)]
    vfx_put(S, "FlameTall", vfx_relief("t", out, rid, _vfx_chain(9) + [(3, 9), (5, 10)]), "FxFire", F)
    # FlameCrest: the rolling top edge of a wall: two curls breaking to +Y, tiles every 1 stud along Y
    out = [(-0.5, 0.0), (0.5, 0.0), (0.5, 0.20), (0.41, 0.27), (0.43, 0.33), (0.48, 0.33), (0.44, 0.40),
           (0.37, 0.42), (0.29, 0.38), (0.20, 0.30), (0.12, 0.27), (0.07, 0.36), (0.09, 0.45), (0.17, 0.50),
           (0.27, 0.45), (0.21, 0.56), (0.12, 0.62), (0.0, 0.64), (-0.14, 0.58), (-0.28, 0.46), (-0.40, 0.30),
           (-0.5, 0.20)]
    rid = [(-0.30, 0.12, 0.045), (0.0, 0.14, 0.05), (0.30, 0.12, 0.04), (-0.20, 0.34, 0.045), (-0.03, 0.48, 0.04),
           (0.12, 0.55, 0.025), (0.33, 0.33, 0.02)]
    vfx_put(S, "FlameCrest", vfx_relief("cr", out, rid, [(0, 1), (1, 2), (3, 4), (4, 5)]), "FxFire", F)
    # FlameLick: a small chunky lick that rides a limb, 0.5 tall
    out = [(0.09, 0.0), (0.145, 0.09), (0.14, 0.21), (0.09, 0.32), (0.03, 0.41), (-0.06, 0.50), (-0.15, 0.465),
           (-0.07, 0.445), (-0.03, 0.37), (-0.04, 0.27), (-0.10, 0.18), (-0.135, 0.09), (-0.09, 0.0)]
    rid = [(0.0, 0.05, 0.04), (0.01, 0.16, 0.05), (0.035, 0.28, 0.04), (0.0, 0.40, 0.025), (-0.07, 0.47, 0.012)]
    vfx_put(S, "FlameLick", vfx_relief("l", out, rid, _vfx_chain(5)), "FxFire", F)
    # Ember: a chunky diamond shard with one cut tip
    me = vfx_hull("e", [(0.03, 0.0, 0.62), (-0.03, 0.03, -0.50), (0.25, 0.04, 0.12), (0.0, 0.21, 0.05),
                        (-0.22, -0.03, 0.17), (0.03, -0.19, 0.02), (0.14, 0.14, 0.24)])
    rw_plane_cut(me, (0.0, 0.0, 0.40), (0.55, 0.25, 1.0))
    vfx_put(S, "Ember", vfx_center(vfx_retri(me), unit_z=True), "FxFireCore", F, "shell")
    # FirePool: the floor patch: flame-shaped teeth hooked the same way round, radius 1
    teeth = [(0, 1.00), (38, 0.80), (77, 0.95), (118, 0.76), (158, 1.0), (200, 0.84), (238, 0.97), (281, 0.78),
             (322, 0.90)]
    r0 = 0.60
    out, rid, red = [], [], []
    for i, (a, rk) in enumerate(teeth):
        w = (teeth[(i + 1) % len(teeth)][0] - a) % 360
        for fr, fa in ((0.0, 0.0), (0.62, 0.30), (1.0, 0.80), (0.42, 0.70)):
            out.append(pol(r0 + (rk - r0) * fr, a + w * fa))
    ring = []
    for j in range(12):
        ring.append(len(rid))
        rid.append(pol(0.40 + (0.03 if j % 2 else 0.0), j * 30 + 10) + (0.05,))
    for i, (a, rk) in enumerate(teeth):
        w = (teeth[(i + 1) % len(teeth)][0] - a) % 360
        rid.append(pol(r0 + (rk - r0) * 0.30, a + w * 0.45) + (0.03,))
    rid.append((0.0, 0.0, 0.03))
    vfx_put(S, "FirePool", vfx_relief("p", out, rid, red, [ring], map3=flat3, back="flat"), "FxFireDeep", F,
            "radial")


# =============================================================================================================
# ICE: angled plates and prisms. Only straight edges, slanted cut tops, V chips, big flat faces.
# =============================================================================================================
def vfx_build_ice(S):
    F = "Ice"
    # PlateA: the broad plate: peak on the right, stepped top, a chip in each edge
    out = [(-0.30, 0.0), (0.28, 0.0), (0.36, 0.28), (0.35, 0.45), (0.27, 0.51), (0.345, 0.60), (0.30, 0.84),
           (0.19, 1.0), (-0.02, 0.84), (-0.07, 0.74), (-0.23, 0.70), (-0.33, 0.56), (-0.36, 0.30),
           (-0.345, 0.23), (-0.28, 0.165), (-0.335, 0.09)]
    pl = [(-0.21, 0.07), (0.21, 0.07), (0.27, 0.28), (0.265, 0.40), (0.19, 0.50), (0.26, 0.63), (0.23, 0.80),
          (0.17, 0.89), (0.02, 0.77), (-0.04, 0.67), (-0.19, 0.63), (-0.25, 0.52), (-0.275, 0.30), (-0.21, 0.17)]
    rid = [p + (0.09,) for p in pl] + [(0.0, 0.25, 0.118), (0.08, 0.62, 0.112)]
    me = vfx_relief("a", out, rid, [(len(pl), len(pl) + 1)], [range(len(pl))])
    vfx_warp(me, lambda c: (c.x + 0.05 * c.z, c.y - 0.07 * c.z, c.z))
    vfx_put(S, "PlateA", me, "FxIce", F)
    # PlateB: twin prism: a tall shard and a shorter one fused at its side
    out = [(-0.22, 0.0), (0.24, 0.0), (0.30, 0.25), (0.275, 0.50), (0.215, 0.71), (0.13, 0.56), (0.085, 0.49),
           (0.10, 0.80), (-0.03, 1.0), (-0.20, 0.85), (-0.26, 0.60), (-0.245, 0.50), (-0.17, 0.45),
           (-0.25, 0.385), (-0.28, 0.15)]
    p1 = [(-0.15, 0.07), (0.03, 0.07), (0.035, 0.46), (0.045, 0.76), (-0.035, 0.90), (-0.15, 0.79), (-0.20, 0.60),
          (-0.115, 0.45), (-0.19, 0.30), (-0.21, 0.15)]
    p2 = [(0.10, 0.07), (0.21, 0.07), (0.25, 0.25), (0.235, 0.48), (0.205, 0.60), (0.15, 0.50), (0.10, 0.40)]
    rid = [p + (0.105,) for p in p1] + [p + (0.06,) for p in p2] + [(-0.07, 0.40, 0.13), (-0.06, 0.72, 0.125)]
    k = len(p1) + len(p2)
    me = vfx_relief("b", out, rid, [(k, k + 1)], [range(len(p1)), range(len(p1), k)])
    vfx_warp(me, lambda c: (c.x - 0.04 * c.z, c.y + 0.05 * c.z, c.z))
    vfx_put(S, "PlateB", me, "FxIce", F)
    # PlateC: the broken slab: short and wide, stepped up to a peak on the left
    out = [(-0.40, 0.0), (0.38, 0.0), (0.45, 0.20), (0.42, 0.38), (0.28, 0.50), (0.20, 0.455), (0.10, 0.60),
           (-0.06, 0.58), (-0.12, 0.70), (-0.30, 0.78), (-0.40, 0.60), (-0.46, 0.36), (-0.405, 0.285),
           (-0.45, 0.14)]
    pl = [(-0.31, 0.07), (0.30, 0.07), (0.36, 0.21), (0.335, 0.34), (0.25, 0.41), (0.18, 0.38), (0.07, 0.51),
          (-0.10, 0.495), (-0.17, 0.62), (-0.28, 0.67), (-0.33, 0.56), (-0.375, 0.385), (-0.33, 0.285),
          (-0.365, 0.15)]
    rid = [p + (0.085,) for p in pl] + [(-0.12, 0.22, 0.112), (0.14, 0.28, 0.105)]
    me = vfx_relief("c", out, rid, [(len(pl), len(pl) + 1)], [range(len(pl))])
    vfx_warp(me, lambda c: (c.x - 0.03 * c.z, c.y + 0.09 * c.z, c.z))
    vfx_put(S, "PlateC", me, "FxIce", F)
    # PlateCore: the slim inner prism (cold light), sits inside a plate
    me = vfx_hull("k", [(0.02, 0.0, 0.0), (-0.02, 0.0, 0.0), (0.0, 0.05, 0.0), (0.0, -0.05, 0.0),
                        (0.045, 0.0, 0.28), (-0.045, 0.0, 0.30), (0.0, 0.11, 0.26), (0.0, -0.10, 0.32),
                        (0.03, 0.02, 0.62), (-0.03, 0.02, 0.62), (0.0, 0.08, 0.60), (0.0, -0.05, 0.64),
                        (0.0, 0.03, 0.86)])
    vfx_put(S, "PlateCore", me, "FxIceLight", F)
    # Chips: flake, splinter, chunky wedge
    me = vfx_hull("c1", [(0.03, 0.19, 0.02), (0.0, -0.10, 0.14), (-0.02, -0.13, -0.12), (0.04, 0.02, 0.02),
                         (-0.04, 0.0, 0.0), (0.0, 0.07, -0.10)])
    vfx_put(S, "Chip1", vfx_center(me), "FxIce", F)
    me = vfx_hull("c2", [(0.0, 0.0, 0.24), (0.01, 0.01, -0.22), (0.03, 0.05, 0.04), (-0.03, 0.03, 0.0),
                         (0.025, -0.045, -0.02), (-0.02, -0.03, 0.06)])
    vfx_put(S, "Chip2", vfx_center(me), "FxIce", F)
    me = vfx_hull("c3", [(0.07, 0.10, -0.06), (0.07, -0.11, -0.08), (-0.07, -0.09, -0.07), (-0.06, 0.11, -0.05),
                         (0.04, 0.06, 0.10), (0.03, -0.05, 0.05), (-0.05, 0.02, 0.07)])
    vfx_put(S, "Chip3", vfx_center(me), "FxIce", F)
    # ShardSpray: a fan of 7 thin shards from one point (spray axis +Z, fanned in Y)
    bm = bmesh.new()
    fan = [(-58, 10, 0.55), (-38, -14, 0.82), (-20, 6, 0.68), (-3, -4, 1.0), (16, 12, 0.78), (34, -10, 0.90),
           (54, 16, 0.60)]
    for ay, tx, ln in fan:
        ay, tx = math.radians(ay), math.radians(tx)
        d = Vector((math.sin(tx), math.sin(ay) * math.cos(tx), math.cos(ay) * math.cos(tx)))
        wide = Vector((1, 0, 0)).cross(d).normalized()
        thin = d.cross(wide).normalized()
        g = d * (ln * 0.32)
        w, t = 0.047 * ln, 0.020 * ln
        root = bm.verts.new((0, 0, 0))
        ring = [bm.verts.new(g + wide * w), bm.verts.new(g + thin * t), bm.verts.new(g - wide * w),
                bm.verts.new(g - thin * t)]
        tip = bm.verts.new(d * ln)
        for j in range(4):
            bm.faces.new((root, ring[j], ring[(j + 1) % 4]))
            bm.faces.new((ring[(j + 1) % 4], ring[j], tip))
    vfx_put(S, "ShardSpray", vfx_finish(bm, "sp"), "FxIce", F, "spray")
    # FrostFront: the floor patch: straight spears with side branches, radius 1
    spikes = [(8, 1.0), (58, 0.74), (105, 0.93), (160, 0.80), (208, 1.0), (262, 0.72), (312, 0.90)]
    out, rid, red = [], [], []
    ring = []
    for j in range(14):
        ring.append(len(rid))
        rid.append(pol(0.36 if j % 2 else 0.33, j * 360 / 14) + (0.04,))
    for i, (a, R) in enumerate(spikes):
        L = R - 0.50
        rr = Vector(pol(1, a))
        tt = Vector((-rr.y, rr.x))
        for ra, ta in ((0.52, -0.060), (0.50 + 0.30 * L, -0.048), (0.50 + 0.56 * L, -0.05 - 0.21 * L),
                       (0.50 + 0.52 * L, -0.038), (R, 0.0), (0.50 + 0.74 * L, 0.032),
                       (0.50 + 0.82 * L, 0.035 + 0.16 * L), (0.50 + 0.60 * L, 0.042), (0.52, 0.060)):
            p = rr * ra + tt * ta
            out.append((p.x, p.y))
        an = (spikes[(i + 1) % len(spikes)][0] - a) % 360
        out.append(pol(0.44, a + an / 2))
        b = len(rid)
        rid.append(pol(0.50, a) + (0.034,))
        rid.append(pol(0.50 + 0.45 * L, a) + (0.022,))
        red.append((b, b + 1))
    vfx_put(S, "FrostFront", vfx_relief("f", out, rid, red, [ring], map3=flat3, back="flat"), "FxIce", F, "radial")
    # ShellFacet: one large angled facet panel (1 x 1.4) for building a shell round a posed body
    out = [(-0.42, -0.62), (0.30, -0.70), (0.50, -0.30), (0.47, 0.02), (0.40, 0.08), (0.46, 0.15), (0.44, 0.40),
           (0.12, 0.70), (-0.36, 0.56), (-0.50, 0.0)]
    pl = [(-0.33, -0.51), (0.25, -0.57), (0.39, -0.26), (0.36, 0.0), (0.31, 0.08), (0.34, 0.34), (0.08, 0.57),
          (-0.28, 0.455), (-0.39, 0.0)]
    rid = [p + (0.045,) for p in pl] + [(-0.12, 0.10, 0.085), (0.12, 0.22, 0.085)]
    n = len(pl)
    me = vfx_relief("sf", out, rid, [(8, n), (n, n + 1), (n + 1, 5)], [range(n)])
    vfx_put(S, "ShellFacet", me, "FxIce", F)


# =============================================================================================================
# HEALING: the only soft family. Softness from many shallow facets and tapered ends.
# =============================================================================================================
def vfx_build_healing(S):
    F = "Healing"
    # Leaf: a soft teardrop leaf, 1 tall, origin at the base point
    out = [(0.0, 0.0), (0.07, 0.06), (0.15, 0.16), (0.21, 0.29), (0.235, 0.43), (0.225, 0.57), (0.18, 0.71),
           (0.115, 0.84), (0.06, 0.94), (0.03, 1.0), (-0.03, 0.93), (-0.09, 0.82), (-0.15, 0.68), (-0.19, 0.53),
           (-0.195, 0.38), (-0.16, 0.24), (-0.10, 0.12), (-0.04, 0.04)]
    mid = [(0.045, 0.10), (0.09, 0.20), (0.12, 0.32), (0.13, 0.45), (0.125, 0.58), (0.10, 0.71), (0.07, 0.82),
           (0.045, 0.91), (0.0, 0.90), (-0.035, 0.80), (-0.07, 0.68), (-0.09, 0.54), (-0.09, 0.40), (-0.07, 0.27),
           (-0.04, 0.16), (-0.01, 0.08)]
    vein = [(0.015, 0.16, 0.046), (0.02, 0.32, 0.054), (0.02, 0.50, 0.054), (0.025, 0.68, 0.048),
            (0.025, 0.84, 0.042)]
    rid = [p + (0.034,) for p in mid] + vein
    k = len(mid)
    vfx_put(S, "Leaf", vfx_relief("l", out, rid, _vfx_chain(len(vein), k), [range(k)]), "FxHeal", F)
    # ChevronUp: a rounded-corner upward chevron, 1 wide, origin centre
    out = [(-0.47, -0.12), (-0.40, -0.06), (-0.10, 0.26), (-0.04, 0.31), (0.04, 0.31), (0.10, 0.26), (0.40, -0.06),
           (0.47, -0.12), (0.50, -0.20), (0.48, -0.28), (0.42, -0.31), (0.36, -0.28), (0.07, 0.03), (0.0, 0.07),
           (-0.07, 0.03), (-0.36, -0.28), (-0.42, -0.31), (-0.48, -0.28), (-0.50, -0.20)]
    rid = [(-0.43, -0.205, 0.03), (-0.23, 0.0, 0.045), (0.0, 0.20, 0.05), (0.23, 0.0, 0.045), (0.43, -0.205, 0.03)]
    vfx_put(S, "ChevronUp", vfx_relief("c", out, rid, _vfx_chain(5)), "FxHeal", F)
    # Ribbon: a gently arcing, slightly rolling band along +X. Tiles every 1.0 along X (the pointed head
    # of one nests in the notched tail of the next).
    hw, t = 0.09, 0.016
    prof = [(-1.0, 0.0), (-0.5, 1.0), (0.0, 1.25), (0.5, 1.0), (1.0, 0.0), (0.5, -1.0), (0.0, -1.25), (-0.5, -1.0)]
    n = 12
    secs = []
    for i in range(n + 1):
        x0 = i / n
        wm = 1.0 + 0.22 * math.sin(2 * math.pi * x0 + 0.6)
        ro = 0.30 * math.sin(2 * math.pi * x0)
        sec = []
        for py, pz in prof:
            x = x0 + 0.08 * (1 - abs(py))
            y, zl = py * hw * wm, pz * t
            sec.append((x, y * math.cos(ro) - zl * math.sin(ro),
                        0.07 * math.sin(2 * math.pi * x) + y * math.sin(ro) + zl * math.cos(ro)))
        secs.append(sec)
    vfx_put(S, "Ribbon", vfx_sweep("r", secs, wrap=False, caps=True), "FxHeal", F, "along")
    # PulseRing: a flat ring, radius 1, soft scalloped outer edge
    N = 40
    pat = [0.935, 0.985, 1.0, 0.985]
    secs = []
    for i in range(N):
        a = 360.0 * i / N
        secs.append([pol(0.80, a) + (0.0,), pol(0.895, a) + (0.035,), pol(pat[i % 4], a) + (0.0,)])
    vfx_put(S, "PulseRing", vfx_sweep("p", secs), "FxHeal", F, "radial")


# =============================================================================================================
# TELEPORT: strict symmetry. A line, a hinged panel, a toothed ring.
# =============================================================================================================
def vfx_build_teleport(S):
    F = "Teleport"

    def rh(z, ty, tx):
        return [(tx, 0, z), (0, ty, z), (-tx, 0, z), (0, -ty, z)]
    lv = [(-0.5, 0, 0), (-0.22, 0.016, 0.009), (-0.07, 0.026, 0.014), (0.0, 0.06, 0.032), (0.07, 0.026, 0.014),
          (0.22, 0.016, 0.009), (0.5, 0, 0)]
    vfx_put(S, "FoldLine", vfx_sweep("fl", [rh(*l) for l in lv], wrap=False), "FxTele", F)
    # FoldPanel: tall hexagonal panel, hinge edge on the Z axis (y = 0), opens toward +Y
    out = [(0.0, -0.30), (0.16, -0.50), (0.32, -0.30), (0.32, 0.30), (0.16, 0.50), (0.0, 0.30)]
    pl = [(0.045, -0.275), (0.16, -0.42), (0.275, -0.275), (0.275, 0.275), (0.16, 0.42), (0.045, 0.275)]
    rid = [p + (0.016,) for p in pl] + [(0.16, -0.26, 0.03), (0.16, 0.26, 0.03)]
    vfx_put(S, "FoldPanel", vfx_relief("fp", out, rid, [(6, 7)], [range(6)]), "FxTele", F)
    # PinchRing: flat ring radius 1, eight teeth pointing in (long / short)
    secs = []
    for k in range(8):
        a = k * 45.0
        tip = 0.56 if k % 2 == 0 else 0.70
        for da, rin in ((-7.0, 0.86), (0.0, tip), (7.0, 0.86), (22.5, 0.86)):
            secs.append([pol(rin, a + da) + (0.0,), pol(0.93, a + da) + (0.03,), pol(1.0, a + da) + (0.0,)])
    vfx_put(S, "PinchRing", vfx_sweep("pr", secs), "FxTele", F, "radial")
    vfx_put(S, "Mote", vfx_sweep("m", [rh(-0.5, 0, 0), rh(0.1, 0.16, 0.12), rh(0.5, 0, 0)], wrap=False), "FxTele",
            F, "shell")


# =============================================================================================================
# SCAN: open thin shells (DoubleSided). Flat bands, never a smooth sphere.
# =============================================================================================================
def _vfx_sph(lat, az, r=1.0):
    la, a = math.radians(lat), math.radians(az)
    return (r * math.cos(la) * math.cos(a), r * math.cos(la) * math.sin(a), r * math.sin(la))


def vfx_build_scan(S):
    F = "Scan"
    n = 16
    # ScanShell: 10 latitude bands with slits between them, open poles, a raised belt on the equator
    strips = []
    step, g = (78.0 - 7.5) / 5, 1.3
    for sgn in (1, -1):
        for b in range(5):
            strips.append([(sgn * (7.5 + b * step + g), 1.0), (sgn * (7.5 + (b + 1) * step - g), 1.0)])
    strips.append([(-6.5, 1.0), (-4.0, 1.05), (4.0, 1.05), (6.5, 1.0)])
    bm = bmesh.new()
    for prof in strips:
        rings = [[bm.verts.new(_vfx_sph(lat, 360.0 * j / n, r)) for j in range(n)] for lat, r in prof]
        for a, b in zip(rings, rings[1:]):
            for j in range(n):
                bm.faces.new((a[j], a[(j + 1) % n], b[(j + 1) % n], b[j]))
    vfx_put(S, "ScanShell", vfx_finish(bm, "ss"), "Energy", F, "shell", ds=True)
    # ScanBand: one horizontal band with V notches top and bottom, and a thin tracer line each side
    N = 24
    top = [0.10, 0.10, 0.10, 0.045]
    bot = [-0.10, -0.045, -0.10, -0.10]
    bm = bmesh.new()
    for z0s, z1s in ((bot, top), ([0.14] * 4, [0.165] * 4), ([-0.165] * 4, [-0.14] * 4)):
        lo = [bm.verts.new(pol(1.0, 360.0 * j / N) + (z0s[j % 4],)) for j in range(N)]
        hi = [bm.verts.new(pol(1.0, 360.0 * j / N) + (z1s[j % 4],)) for j in range(N)]
        for j in range(N):
            bm.faces.new((lo[j], lo[(j + 1) % N], hi[(j + 1) % N], hi[j]))
    vfx_put(S, "ScanBand", vfx_finish(bm, "sb"), "Energy", F, "shell", ds=True)
    # SpikePulse: eight vertical fins (pointed gores with a raised spine) and a spiked equator ring
    bm = bmesh.new()
    lats = [-80, -60, -40, -20, 0, 20, 40, 60, 80]
    for k in range(8):
        az = k * 45.0
        rows = []
        for lat in lats:
            f = 1.0 - (abs(lat) / 80.0) ** 2
            dl = 12.0 * f ** 0.8
            rows.append([bm.verts.new(_vfx_sph(lat, az - dl)), bm.verts.new(_vfx_sph(lat, az, 1.0 + 0.07 * f)),
                         bm.verts.new(_vfx_sph(lat, az + dl))])
        for a, b in zip(rows, rows[1:]):
            for j in range(2):
                bm.faces.new((a[j], a[j + 1], b[j + 1], b[j]))
    for sgn in (1, -1):
        inn = [bm.verts.new(pol(0.93, 22.5 * j) + (0.05 * sgn,)) for j in range(16)]
        outr = [bm.verts.new(pol(1.16 if j % 2 else 1.0, 22.5 * j) + (0.0,)) for j in range(16)]
        for j in range(16):
            bm.faces.new((inn[j], inn[(j + 1) % 16], outr[(j + 1) % 16], outr[j]))
    vfx_put(S, "SpikePulse", vfx_finish(bm, "sk"), "Energy", F, "shell", ds=True)


# =============================================================================================================
# IMPACT: a low wedge ring, chunky floor fragments, a skirt of angular dust puffs.
# =============================================================================================================
def vfx_build_impact(S):
    F = "Impact"
    # PressureRing: low wedge, thick chiselled leading (outer) edge, serrated trailing edge
    N = 24
    secs = []
    for i in range(N):
        a = 360.0 * i / N
        rin = 0.62 if i % 2 == 0 else 0.78
        ro = 1.0 if i % 2 == 0 else 0.975
        secs.append([pol(rin, a) + (0.0,), pol(0.90, a) + (0.10,), pol(ro - 0.03, a) + (0.062,), pol(ro, a) + (0.0,)])
    vfx_put(S, "PressureRing", vfx_sweep("pr", secs), "Energy", F, "radial")
    # Fragment1: the wedge
    me = vfx_hull("f1", [(-0.28, -0.14, -0.12), (-0.27, 0.12, -0.12), (0.27, -0.17, -0.12), (0.26, 0.16, -0.12),
                         (-0.28, -0.12, -0.06), (-0.27, 0.10, -0.07), (0.24, -0.14, 0.13), (0.22, 0.13, 0.11),
                         (0.08, -0.16, 0.06)])
    rw_plane_cut(me, (0.20, 0.12, 0.08), (0.3, 1.0, 0.6))
    vfx_put(S, "Fragment1", vfx_center(vfx_retri(me)), "FxStone", F)
    # Fragment2: the slab
    bot = [(-0.30, -0.10), (-0.18, -0.22), (0.20, -0.20), (0.30, -0.02), (0.16, 0.22), (-0.20, 0.18)]
    topp = [(-0.25, -0.08), (-0.15, -0.17), (0.17, -0.15), (0.24, 0.0), (0.12, 0.17), (-0.17, 0.13)]
    me = vfx_hull("f2", [p + (-0.065,) for p in bot] + [p + (0.065,) for p in topp])
    rw_plane_cut(me, (0.20, 0.10, 0.0), (1.0, 0.8, 0.5))
    vfx_put(S, "Fragment2", vfx_center(vfx_retri(me)), "FxStone", F)
    # Fragment3: the chunk
    me = vfx_hull("f3", [(0.20, 0.05, -0.16), (-0.05, 0.20, -0.18), (-0.21, -0.02, -0.15), (0.02, -0.19, -0.17),
                         (0.22, -0.08, 0.03), (0.05, 0.21, 0.06), (-0.19, 0.10, 0.08), (-0.12, -0.18, 0.05),
                         (0.06, 0.02, 0.22), (-0.08, -0.04, 0.19), (0.15, 0.12, 0.14)])
    vfx_put(S, "Fragment3", vfx_center(me), "FxStone", F)
    # Fragment4: the pointed shard chunk
    me = vfx_hull("f4", [(0.15, 0.10, -0.26), (-0.12, 0.14, -0.26), (-0.16, -0.10, -0.26), (0.12, -0.15, -0.26),
                         (0.17, 0.02, -0.08), (-0.05, 0.16, -0.05), (-0.15, -0.06, -0.10), (0.04, -0.02, 0.30)])
    rw_plane_cut(me, (0.03, 0.0, 0.20), (-0.6, 0.3, 1.0))
    vfx_put(S, "Fragment4", vfx_center(vfx_retri(me)), "FxStone", F)
    # DustSkirt: nine angular puffs fused into one low ring, radius 1
    sizes = [0.33, 0.29, 0.36, 0.30, 0.34, 0.37, 0.29, 0.35, 0.31]
    tmp = rw_col(S, "ReworkVFX_Mock")
    vfx_clear_tmp("tmp_")
    objs = []
    for k, s in enumerate(sizes):
        a = k * 40.0 + (5.0 if k % 2 else -4.0)
        h = s * (0.62 if k % 3 else 0.78)
        rc = (1.0 if k % 2 == 0 else 0.95) - 0.75 * s
        rr = Vector(pol(1, a))
        tt = Vector((-rr.y, rr.x))
        loc = [(0.55, -0.45, 0), (0.55, 0.45, 0), (0.0, 0.95, 0), (-0.6, 0.5, 0), (-0.6, -0.5, 0), (0.0, -0.95, 0),
               (0.75, -0.30, 0.42), (0.72, 0.38, 0.46), (0.05, 0.90, 0.38), (-0.5, 0.35, 0.50), (-0.5, -0.42, 0.44),
               (0.0, -0.88, 0.40), (0.38, -0.12, 1.0), (0.20, 0.30, 0.90), (-0.15, 0.0, 0.84)]
        pts = []
        for lx, ly, lz in loc:
            p = rr * (rc + lx * s) + tt * (ly * s)
            pts.append((p.x, p.y, lz * h))
        o = bpy.data.objects.new(VFX_PRE + "tmp_puff%d" % k, vfx_hull(VFX_PRE + "tmp_puff%d" % k, pts))
        tmp.objects.link(o)
        objs.append(o)
    bpy.context.view_layer.update()
    base = objs[0]
    for o in objs[1:]:
        rw_bool(base, o, "UNION")
    me = base.data.copy()
    vfx_clear_tmp("tmp_")
    vfx_put(S, "DustSkirt", me, "Pale", F, "radial")


def vfx_build_all(S):
    for fn in (vfx_build_wind, vfx_build_fire, vfx_build_ice, vfx_build_healing, vfx_build_teleport,
               vfx_build_scan, vfx_build_impact):
        fn(S)


# =============================================================================================================
# Review renders: contact sheets (colour + pure white on black) and mock scenes
# =============================================================================================================
def _vfx_mat(name, rgb, emit=0.0, alpha=1.0):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    col = (*rgb, 1.0)
    b.inputs["Base Color"].default_value = col
    b.inputs["Roughness"].default_value = 0.6
    if emit > 0:
        b.inputs["Emission Color"].default_value = col
        b.inputs["Emission Strength"].default_value = emit
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
        try:
            m.surface_render_method = "BLENDED"
        except Exception:
            pass
    m.diffuse_color = col
    return m


def _vfx_world(name, rgb):
    w = bpy.data.worlds.get(name)
    if not w:
        w = bpy.data.worlds.new(name)
        w.use_nodes = True
        bg = w.node_tree.nodes.get("Background")
        bg.inputs[0].default_value = (*rgb, 1.0)
        bg.inputs[1].default_value = 1.0
    return w


def _vfx_frame(view):
    d = Vector(view).normalized()
    f = -d
    right = f.cross(Vector((0, 0, 1))).normalized()
    upc = right.cross(f).normalized()
    return d, right, upc


def _vfx_render(S, out, d, right, upc, cen, span_w, span_h, res, ortho=True, lens=50, depth=0.0, sil=False):
    rig = rw_col(S, "RW_Rig_" + S.name)
    for o in list(rig.objects):
        dat = o.data
        bpy.data.objects.remove(o, do_unlink=True)
        if dat is not None and dat.users == 0:
            (bpy.data.cameras if isinstance(dat, bpy.types.Camera) else bpy.data.lights).remove(dat)
    cd = bpy.data.cameras.new(VFX_PRE + "rig_cam")
    cam = bpy.data.objects.new(VFX_PRE + "rig_cam", cd)
    rig.objects.link(cam)
    aspect = res[0] / res[1]
    need = max(span_w, span_h * aspect) if aspect >= 1 else max(span_h, span_w / aspect)
    cd.clip_start = 0.01
    cd.clip_end = 2000
    if ortho:
        cd.type = "ORTHO"
        cd.ortho_scale = need
        dist = 80.0 + depth
    else:
        cd.lens = lens
        dist = (need / 2) / math.tan(cd.angle / 2) + depth
    M = Matrix((right, upc, d)).transposed().to_4x4()
    M.translation = cen + d * dist
    cam.matrix_world = M
    S.camera = cam
    if not sil:
        for nm, L, energy in (("key", d * 0.7 + right * 0.6 + upc * 0.9, 3.2), ("fill", d * 0.6 - right * 1.0 + upc * 0.1, 1.0),
                              ("rim", -d * 0.8 - right * 0.3 + upc * 0.8, 2.0)):
            ld = bpy.data.lights.new(VFX_PRE + "rig_" + nm, "SUN")
            ld.energy = energy
            lo = bpy.data.objects.new(VFX_PRE + "rig_" + nm, ld)
            rig.objects.link(lo)
            lo.rotation_euler = L.normalized().to_track_quat("Z", "Y").to_euler()
    S.world = _vfx_world("ReworkVFX_WorldBlack", (0, 0, 0)) if sil else _vfx_world("ReworkVFX_World", tuple(_rw_hex("#0B0E14")[:3]))
    vl = S.view_layers[0]
    vl.material_override = _vfx_mat("ReworkVFX_SilWhite", (1, 1, 1), emit=1.0) if sil else None
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            S.render.engine = eng
            break
        except TypeError:
            continue
    S.render.resolution_x, S.render.resolution_y = res
    S.render.resolution_percentage = 100
    S.render.film_transparent = False
    S.render.image_settings.file_format = "PNG" if out.lower().endswith(".png") else "JPEG"
    S.render.image_settings.quality = 90
    S.view_settings.view_transform = "Standard"
    S.render.filepath = out
    os.makedirs(os.path.dirname(out), exist_ok=True)
    try:
        bpy.ops.render.render(write_still=True, scene=S.name)
    finally:
        vl.material_override = None
    return out


def _vfx_hide_kit(hide, also=()):
    for nm in ("ReworkVFX",) + tuple(also):
        c = bpy.data.collections.get(nm)
        if c:
            c.hide_render = hide


VFX_SHEETS = {
    "wind": dict(rows=[["StrokeA"], ["StrokeB"], ["StrokeC"]], view=(0, -0.45, 1), gap=0.05, label=0.022),
    "fire": dict(rows=[["FlameA", "FlameB", "FlameC", "FlameLick", "Ember"], ["FlameTall", "FlameCrest", "FirePool"]]),
    "ice": dict(rows=[["PlateA", "PlateB", "PlateC", "PlateCore", "ShardSpray"],
                      ["ShellFacet", "Chip1", "Chip2", "Chip3", "FrostFront"]]),
    "healing": dict(rows=[["Leaf", "ChevronUp", "Ribbon", "PulseRing"]], rot={"Ribbon": (0, 0, 90)}),
    "teleport": dict(rows=[["FoldLine", "FoldPanel", "Mote", "PinchRing"]], scale={"Mote": 0.4}),
    "scan": dict(rows=[["ScanShell", "ScanBand", "SpikePulse"]], view=(1, 0, 0.3)),
    "impact": dict(rows=[["Fragment1", "Fragment2", "Fragment3", "Fragment4"], ["PressureRing", "DustSkirt"]]),
}


def vfx_sheet(S, family, out=None, res_w=2000, tag="", colour=True, sil=True):
    """Contact sheet of one family: the pieces side by side (copies; the kit stays at the origin).
    Writes VFX_<family>.jpg and VFX_<family>_silhouette.jpg (pure white on black)."""
    spec = VFX_SHEETS[family]
    rows, view = spec["rows"], spec.get("view", (1, 0, 0.45))
    gap, label = spec.get("gap", 0.22), spec.get("label", 0.07)
    rot, scale = spec.get("rot", {}), spec.get("scale", {})
    vfx_clear_tmp("sheet_")
    col = rw_col(S, "ReworkVFX_Sheet")
    d, right, upc = _vfx_frame(view)
    lblm = _vfx_mat("ReworkVFX_Label", (0.75, 0.78, 0.82), emit=0.8)
    base = 0.0
    ext = [1e9, -1e9, 1e9, -1e9]
    labels = []
    for row in rows:
        items = []
        for part in row:
            src = bpy.data.objects[VFX_PRE + part]
            R = Euler([math.radians(a) for a in rot.get(part, (0, 0, 0))]).to_matrix()
            sc = scale.get(part, 1.0)
            cs = [R @ (Vector(c) * sc) for c in src.bound_box]
            pr = [c.dot(right) for c in cs]
            pu = [c.dot(upc) for c in cs]
            items.append((part, src, R, sc, min(pr), max(pr), min(pu), max(pu)))
        base -= max(i[7] - i[6] for i in items)
        cur = 0.0
        for part, src, R, sc, r0, r1, u0, u1 in items:
            o = bpy.data.objects.new(VFX_PRE + "sheet_" + part, src.data)
            col.objects.link(o)
            o.rotation_euler = R.to_euler()
            o.scale = (sc, sc, sc)
            o.location = right * (cur - r0) + upc * (base - u0)
            cu = bpy.data.curves.new(VFX_PRE + "sheet_lbl_" + part, "FONT")
            cu.body = part
            cu.size = label
            cu.align_x = "CENTER"
            cu.materials.append(lblm)
            t = bpy.data.objects.new(cu.name, cu)
            col.objects.link(t)
            M = Matrix((right, upc, d)).transposed().to_4x4()
            M.translation = right * (cur + (r1 - r0) / 2) + upc * (base - label * 1.7) + d * 3.0
            t.matrix_world = M
            labels.append(t)
            ext = [min(ext[0], cur), max(ext[1], cur + r1 - r0), min(ext[2], base - label * 2.4),
                   max(ext[3], base + u1 - u0)]
            cur += (r1 - r0) + gap
        base -= gap + label * 2.6
    sw, sh = (ext[1] - ext[0]) * 1.06, (ext[3] - ext[2]) * 1.08
    cen = right * ((ext[0] + ext[1]) / 2) + upc * ((ext[2] + ext[3]) / 2)
    res = (res_w, max(360, min(int(res_w * 1.3), int(res_w * sh / sw))))
    res = (res[0] - res[0] % 2, res[1] - res[1] % 2)
    outs = []
    _vfx_hide_kit(True, ("ReworkVFX_Mock",))
    try:
        if colour:
            p = out or os.path.join(VFX_REN, "VFX_%s%s.jpg" % (family, tag))
            outs.append(_vfx_render(S, p, d, right, upc, cen, sw, sh, res))
        if sil:
            for t in labels:
                t.hide_render = True
            p = os.path.join(VFX_REN, "VFX_%s%s_silhouette.jpg" % (family, tag))
            outs.append(_vfx_render(S, p, d, right, upc, cen, sw, sh, res, sil=True))
    finally:
        _vfx_hide_kit(False, ("ReworkVFX_Mock",))
        vfx_clear_tmp("sheet_")
    return outs


def vfx_copy(S, part, tag, loc=(0, 0, 0), rot=(0, 0, 0), scale=1.0, role=None, mat=None):
    src = bpy.data.objects[VFX_PRE + part]
    o = bpy.data.objects.new(VFX_PRE + "mock_" + tag, src.data)
    rw_col(S, "ReworkVFX_Mock").objects.link(o)
    o.location = loc
    o.rotation_euler = [math.radians(a) for a in rot]
    o.scale = scale if hasattr(scale, "__len__") else (scale, scale, scale)
    m = mat or (rw_mat(role) if role else None)
    if m:
        o.material_slots[0].link = "OBJECT"
        o.material_slots[0].material = m
    return o


def _vfx_mock_stage(S, floor=26.0, fig=None):
    vfx_clear_tmp("mock_")
    c = rw_col(S, "ReworkVFX_Mock")
    fl = rw_obj(c, VFX_PRE + "mock_floor", rw_cham_box(VFX_PRE + "mock_floor", floor, floor, 0.4, 0.1), "Body",
                loc=(0, 0, -0.2))
    if fig:
        rw_obj(c, VFX_PRE + "mock_figBody", rw_cham_box(VFX_PRE + "mock_figBody", 1.0, 2.0, 4.3, 0.22), "Panel",
               loc=(fig[0], fig[1], 2.15))
        rw_obj(c, VFX_PRE + "mock_figHead", rw_cham_box(VFX_PRE + "mock_figHead", 1.1, 1.1, 1.1, 0.2), "Panel",
               loc=(fig[0], fig[1], 4.95))
    return c


def vfx_mock_shot(S, out, view, res=(1600, 1000), lens=50, target=None, zoom=1.0, skip=("mock_floor",)):
    d, right, upc = _vfx_frame(view)
    pts = []
    for o in bpy.data.objects:
        if o.name.startswith(VFX_PRE + "mock_") and o.type == "MESH" and not any(o.name.startswith(VFX_PRE + s) for s in skip):
            pts += [o.matrix_world @ Vector(c) for c in o.bound_box]
    pr = [p.dot(right) for p in pts]
    pu = [p.dot(upc) for p in pts]
    pd = [p.dot(d) for p in pts]
    cen = right * ((min(pr) + max(pr)) / 2) + upc * ((min(pu) + max(pu)) / 2) + d * ((min(pd) + max(pd)) / 2)
    if target is not None:
        cen = Vector(target)
    sw, sh = (max(pr) - min(pr)) * 1.12 / zoom, (max(pu) - min(pu)) * 1.12 / zoom
    _vfx_hide_kit(True, ("ReworkVFX_Sheet",))
    try:
        return _vfx_render(S, out, d, right, upc, cen, sw, sh, res, ortho=False, lens=lens,
                           depth=(max(pd) - min(pd)) / 2)
    finally:
        _vfx_hide_kit(False, ("ReworkVFX_Sheet",))


def vfx_mock_fire(S, tag=""):
    """A Molly fire patch: pool, seven tongues in three nested value bands, embers."""
    _vfx_mock_stage(S, fig=(0.5, -6.6))
    rnd = random.Random(11)
    vfx_copy(S, "FirePool", "pool0", (0, 0, 0.0), (0, 0, 0), (4.6, 4.6, 3.0), "FxFireDeep")
    vfx_copy(S, "FirePool", "pool1", (0, 0, 0.03), (0, 0, 47), (3.0, 3.0, 4.0), "FxFire")
    flames = [("FlameC", (0.0, 0.0), 3.7, 0), ("FlameA", (1.5, 1.5), 2.7, 20), ("FlameB", (-1.4, 1.6), 3.0, -15),
              ("FlameA", (0.9, -2.0), 2.5, 170), ("FlameC", (-1.8, -1.2), 2.2, 195), ("FlameB", (2.3, -0.6), 2.0, 30),
              ("FlameA", (-0.4, 2.9), 2.0, -30), ("FlameB", (-0.2, -3.0), 1.7, 185)]
    for i, (part, (x, y), h, yaw) in enumerate(flames):
        for j, (role, k, tk) in enumerate((("FxFireDeep", 1.0, 1.0), ("FxFire", 0.72, 1.7), ("FxFireCore", 0.45, 2.3))):
            vfx_copy(S, part, "fl%d_%d" % (i, j), (x, y, 0.0), (0, 0, yaw), (h * tk, h * k, h * k), role)
    for i in range(10):
        a, r = rnd.uniform(0, 6.28), rnd.uniform(0.5, 3.6)
        s = rnd.uniform(0.28, 0.5)
        vfx_copy(S, "Ember", "em%d" % i, (r * math.cos(a), r * math.sin(a), rnd.uniform(2.2, 5.2)),
                 (rnd.uniform(-40, 40), rnd.uniform(-40, 40), rnd.uniform(0, 360)), s,
                 "FxFireCore" if i % 3 else "FxFire")
    return vfx_mock_shot(S, os.path.join(VFX_REN, "VFX_mock_fire%s.jpg" % tag), (1, -0.35, 0.30))


def vfx_mock_ice(S, tag=""):
    """A 12-stud Frost Wall section, front and back: plates, cores, chips."""
    _vfx_mock_stage(S, fig=(0.0, -8.2))
    rnd = random.Random(5)
    ice = _vfx_mat("ReworkVFX_MockIce", tuple(_rw_hex("#CFEFFF")[:3]), emit=0.12, alpha=0.62)
    row = [("PlateA", -5.0, 0, 9.6), ("PlateB", -3.0, 180, 10.6), ("PlateC", -0.9, 0, 11.2), ("PlateB", 1.1, 0, 10.0),
           ("PlateA", 3.1, 180, 9.2), ("PlateC", 5.0, 180, 10.4)]
    for i, (part, y, yaw, h) in enumerate(row):
        x = 0.18 if i % 2 else -0.18
        vfx_copy(S, part, "pl%d" % i, (x, y, 0.0), (0, 0, yaw), (5.2, 4.6, h), mat=ice)
        vfx_copy(S, "PlateCore", "co%d" % i, (x, y + (0.25 if yaw else -0.25), 0.3), (0, 0, yaw + (8 if i % 2 else -8)),
                 (4.2, 5.2, h * (0.92 if part != "PlateC" else 0.70)), "FxIceLight")
    chips = ["Chip1", "Chip2", "Chip3"]
    for i in range(14):
        side = 1 if i % 2 else -1
        s = rnd.uniform(2.4, 4.2)
        vfx_copy(S, chips[i % 3], "ch%d" % i, (side * rnd.uniform(0.9, 2.2), rnd.uniform(-6.2, 6.2), 0.12 * s),
                 (rnd.uniform(-25, 25) + 90, rnd.uniform(-25, 25), rnd.uniform(0, 360)), s, mat=ice)
    a = vfx_mock_shot(S, os.path.join(VFX_REN, "VFX_mock_icewall_front%s.jpg" % tag), (1, -0.5, 0.2))
    b = vfx_mock_shot(S, os.path.join(VFX_REN, "VFX_mock_icewall_back%s.jpg" % tag), (-1, -0.5, 0.2))
    return [a, b]


def vfx_mock_impact(S, tag=""):
    """A Crash Down impact: pressure ring racing out, fragments mid-air, the dust skirt, dive strokes."""
    _vfx_mock_stage(S, fig=(0.0, 0.0))
    rnd = random.Random(3)
    dust = _vfx_mat("ReworkVFX_MockDust", (0.62, 0.60, 0.56), alpha=0.88)
    vfx_copy(S, "PressureRing", "ring", (0, 0, 0.0), (0, 0, 0), (8.0, 8.0, 6.0), "Energy")
    vfx_copy(S, "DustSkirt", "dust", (0, 0, 0.0), (0, 0, 20), (4.4, 4.4, 5.5), mat=dust)
    for i in range(9):
        a = i * 40 + rnd.uniform(-12, 12)
        r = rnd.uniform(2.2, 5.6)
        s = rnd.uniform(1.7, 3.0)
        vfx_copy(S, "Fragment%d" % (i % 4 + 1), "fr%d" % i,
                 (r * math.cos(math.radians(a)), r * math.sin(math.radians(a)), rnd.uniform(0.9, 3.6)),
                 (rnd.uniform(-60, 60), rnd.uniform(-60, 60), rnd.uniform(0, 360)), s, "FxStone")
    for i, (part, x, y, ln) in enumerate((("StrokeA", 0.9, -1.6, 9.0), ("StrokeC", -0.6, 1.5, 7.5), ("StrokeB", 0.4, 0.3, 11.0))):
        # strokes travel +X: rotate so they travel straight down (-Z), head near the body
        vfx_copy(S, part, "st%d" % i, (x, y, 5.6 + i * 0.4), (0, 90, i * 60), (ln, 6.0, 6.0), "FxWind")
    return vfx_mock_shot(S, os.path.join(VFX_REN, "VFX_mock_impact%s.jpg" % tag), (1, -0.55, 0.42))
