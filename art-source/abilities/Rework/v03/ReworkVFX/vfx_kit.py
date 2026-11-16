"""ReworkVFX kit: the 19 stylised VFX meshes of vault/02 Art/Ability VFX Direction.md (Mesh list) + T_FlameSheet.

Run through the LIVE Blender MCP only (never a background Blender):

    exec(open(r"<repo>/tools/blender/rework/rw_core.py").read())
    S = rw_scene("RW_VFX")
    exec(open(r"<repo>/art-source/abilities/Rework/v03/ReworkVFX/vfx_kit.py").read())
    result = vfx_kit(S)                      # rebuilds every mesh from scratch at the origin

Then: vfx_flame_sheet(S), vfx_sheets(S), rw_audit("ReworkVFX_"), rw_export(...), vfx_parts_md(audit).

Axes: +X forward, +Y left, +Z up, 1 unit = 1 stud. Every mesh: longest side 1, flat shaded, triangulated,
one Fx review material, simple UVs (U around / across, V along the travel). Flat pieces are single open
sheets with the object property fx_doubleSided = True (the note's triangle budgets count both sides).
Temporary render objects are named "RWVFXtmp_" and deleted after each render.
"""
import bpy, bmesh, math, os
from mathutils import Vector, Matrix

VFX_COL = "ReworkVFX"
VFX_PRE = "ReworkVFX_"
VFX_TMP = "RWVFXtmp_"
VFX_DIR = os.path.join(RW_WORK, "ReworkVFX")
VFX_ORDER = ["FX_Stroke", "FX_Ring", "FX_FloorStar", "Fire_TongueA", "Fire_TongueB", "Fire_TongueC", "Ice_PlateA",
             "Ice_PlateB", "Ice_PlateC", "Ice_Cap", "Heal_Leaf", "Heal_Crown", "Stim_Chevron", "Tele_Fold", "Tele_Ring",
             "Scan_Shell", "Impact_ChunkA", "Impact_ChunkB", "Shield_Plate"]


# --- helpers -----------------------------------------------------------------------------------------------
def _vx_want(face, c):
    if face == "radial":
        v = Vector((c.x, c.y, 0))
        return v.normalized() if v.length > 1e-6 else Vector((1, 0, 0))
    return Vector(face)


def vx_mesh(name, geo, anchor=None, uv=None, face=None, norm=True):
    """geo = ("vf", verts, faces) or ("hull", pts). face = None (closed: outward normals) or an axis / "radial"
    for open sheets. anchor: tip | floor | centre | base | base_c. norm: scale so the longest side is 1."""
    bm = bmesh.new()
    if geo[0] == "hull":
        for p in geo[1]:
            bm.verts.new(p)
        r = bmesh.ops.convex_hull(bm, input=bm.verts[:])
        kill = list({g for g in r["geom_interior"] + r["geom_unused"] if isinstance(g, bmesh.types.BMVert)})
        if kill:
            bmesh.ops.delete(bm, geom=kill, context="VERTS")
    else:
        vs = [bm.verts.new(v) for v in geo[1]]
        for f in geo[2]:
            bm.faces.new([vs[i] for i in f])
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    if face is None:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    else:
        bm.normal_update()
        bad = [f for f in bm.faces if f.normal.dot(_vx_want(face, f.calc_center_median())) < 0]
        if bad:
            bmesh.ops.reverse_faces(bm, faces=bad)
    co = [v.co for v in bm.verts]
    lo = Vector([min(c[i] for c in co) for i in range(3)])
    hi = Vector([max(c[i] for c in co) for i in range(3)])
    off = Vector((0, 0, 0))
    if anchor == "centre":
        off = -(lo + hi) / 2
    elif anchor == "floor":
        off = Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, 0))
    elif anchor == "base":
        off = Vector((0, 0, -lo.z))
    elif anchor == "base_c":
        off = Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
    k = 1.0 / max(hi - lo) if norm else 1.0
    for v in bm.verts:
        v.co = (v.co + off) * k
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = False
    if uv:
        vx_uv(me, uv)
    me.update()
    return me


def vx_uv(me, mode):
    lay = me.uv_layers.new(name="UVMap")
    co = [v.co for v in me.vertices]
    lo = [min(c[i] for c in co) for i in range(3)]
    hi = [max(c[i] for c in co) for i in range(3)]
    rmax = max(max(Vector((c.x, c.y)).length for c in co), 1e-6)
    nz = lambda c, i: (c[i] - lo[i]) / max(hi[i] - lo[i], 1e-6)
    for p in me.polygons:
        uvs = []
        for li in p.loop_indices:
            c = co[me.loops[li].vertex_index]
            if mode == "around_z":
                uvs.append([math.atan2(c.y, c.x) / (2 * math.pi) + 0.5, nz(c, 2)])
            elif mode == "around_x":
                uvs.append([math.atan2(c.z, c.y) / (2 * math.pi) + 0.5, nz(c, 0)])
            elif mode == "radial":
                uvs.append([math.atan2(c.y, c.x) / (2 * math.pi) + 0.5, Vector((c.x, c.y)).length / rmax])
            elif mode == "yz":
                uvs.append([nz(c, 1), nz(c, 2)])
            else:  # xz
                uvs.append([nz(c, 0), nz(c, 2)])
        if mode in ("around_z", "around_x", "radial"):
            us = [a[0] for a in uvs]
            if max(us) - min(us) > 0.5:
                for a in uvs:
                    if a[0] < 0.5:
                        a[0] += 1
        for li, a in zip(p.loop_indices, uvs):
            lay.data[li].uv = a


def _poly_pt(R, n, rot, ang):
    """Point at polar angle ang (deg) on a regular n-gon of circumradius R with corners at rot + k*360/n."""
    step = 360.0 / n
    k = math.floor((ang - rot) / step)
    a0, a1 = math.radians(rot + k * step), math.radians(rot + (k + 1) * step)
    c0 = Vector((R * math.cos(a0), R * math.sin(a0)))
    e = Vector((R * math.cos(a1), R * math.sin(a1))) - c0
    d = Vector((math.cos(math.radians(ang)), math.sin(math.radians(ang))))
    t = (c0.x * e.y - c0.y * e.x) / (d.x * e.y - d.y * e.x)
    return (d.x * t, d.y * t)


def _ring_arcs(R, band, n, rot, gaps):
    """Flat faceted ring in XY: n-gon outline, uniform band, gaps = [(centre, width, slant)] with angled cuts."""
    Ri = R - band / math.cos(math.pi / n)
    step = 360.0 / n
    verts, faces = [], []
    gs = sorted(gaps)
    for gi, (gc, gw, sl) in enumerate(gs):
        nc, nw, _ = gs[(gi + 1) % len(gs)]
        if gi == len(gs) - 1:
            nc += 360
        a_s, a_e = gc + gw / 2, nc - nw / 2
        lo_, hi_ = max(a_s, a_s + sl), min(a_e, a_e + sl)
        corners, k = [], math.ceil((lo_ - rot) / step)
        while rot + k * step < hi_ - 1e-6:
            if rot + k * step > lo_ + 1e-6:
                corners.append(rot + k * step)
            k += 1
        oa, ia = [a_s] + corners + [a_e], [a_s + sl] + corners + [a_e + sl]
        b, m = len(verts), len(oa)
        verts += [(*_poly_pt(R, n, rot, a), 0.0) for a in oa]
        verts += [(*_poly_pt(Ri, n, rot, a), 0.0) for a in ia]
        faces += [(b + i, b + i + 1, b + m + i + 1, b + m + i) for i in range(m - 1)]
    return verts, faces


def _walk(segs, start=(0.0, 0.0)):
    """Spine in the XZ plane: segs = [(length, angle from vertical, + leans to +X)]."""
    pts, (x, z) = [start], start
    for L, a in segs:
        x += L * math.sin(math.radians(a))
        z += L * math.cos(math.radians(a))
        pts.append((x, z))
    return pts


def _dir(a, L=1.0):
    return (L * math.sin(math.radians(a)), L * math.cos(math.radians(a)))


def _dring(p, T, w, t):
    """Diamond section of a blade: [front, +Y side, back, -Y side]; w across the spine in XZ, t in Y."""
    N = (T[1], -T[0])
    x, z = p
    return [(x + N[0] * w / 2, 0.0, z + N[1] * w / 2), (x, t / 2, z), (x - N[0] * w / 2, 0.0, z - N[1] * w / 2), (x, -t / 2, z)]


def _tan(pts, i):
    if i == 0:
        return (0.0, 1.0)
    a = Vector(pts[i]) - Vector(pts[i - 1])
    d = a.normalized() + (Vector(pts[i + 1]) - Vector(pts[i])).normalized() if i + 1 < len(pts) else a
    d.normalize()
    return (d.x, d.y)


def _blade(pts, widths, thick):
    """Faceted blade: diamond rings along pts[:-1], pointed at pts[-1], flat base cap."""
    verts, faces, rings = [], [], []
    for i in range(len(pts) - 1):
        rings.append(list(range(len(verts), len(verts) + 4)))
        verts += _dring(pts[i], _tan(pts, i), widths[i], thick[i])
    tip = len(verts)
    verts.append((pts[-1][0], 0.0, pts[-1][1]))
    faces.append(tuple(reversed(rings[0])))
    for a, b in zip(rings, rings[1:]):
        faces += [(a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k]) for k in range(4)]
    faces += [(rings[-1][k], rings[-1][(k + 1) % 4], tip) for k in range(4)]
    return verts, faces


def _sz(verts, s):
    return [(x, y, z * s) for x, y, z in verts]


# --- the 19 builders -----------------------------------------------------------------------------------------
def b_stroke():
    # head tip at the origin, long tail to -X; flat diamond section, fattest a third back from the head
    xm, w, h = -0.3, 0.08, 0.045
    v = [(0, 0, 0), (xm, 0, h / 2), (xm, w / 2, 0), (xm, 0, -h / 2), (xm, -w / 2, 0), (-1.0, 0, 0)]
    f = []
    for i in range(4):
        a, b = 1 + i, 1 + (i + 1) % 4
        f += [(0, a, b), (5, b, a)]
    return ("vf", v, f)


def b_ring():
    return ("vf", *_ring_arcs(0.5, 0.03, 16, 11.25, [(45 + 90 * i, 8, 6) for i in range(4)]))


def b_floorstar():
    angs = [i * 40 + j for i, j in enumerate([0, 7, -5, 4, -8, 5, -3, 8, -4])]
    tr = [0.5, 0.33, 0.45, 0.30, 0.47, 0.36, 0.42, 0.31, 0.39]
    vr = [0.16, 0.12, 0.18, 0.13, 0.15, 0.11, 0.17, 0.14, 0.12]
    slits = {1: 5, 4: -4, 7: 3}  # valleys carved into narrow cuts toward the centre (slant in deg)
    out = []
    for i in range(9):
        a = math.radians(angs[i])
        out.append((tr[i] * math.cos(a), tr[i] * math.sin(a), 0.0))
        va = (angs[i] + angs[(i + 1) % 9] + (360 if i == 8 else 0)) / 2
        if i in slits:
            for r, da in ((vr[i], -4), (0.045, slits[i]), (vr[i], 4)):
                out.append((r * math.cos(math.radians(va + da)), r * math.sin(math.radians(va + da)), 0.0))
        else:
            out.append((vr[i] * math.cos(math.radians(va)), vr[i] * math.sin(math.radians(va)), 0.0))
    return ("vf", out, [tuple(range(len(out)))])


def tongue_a(k=1.0, s=1.0):
    pts = _walk([(0.5, 4), (0.24, 30 * k), (0.2, 75 * k), (0.16, 125 * k)])
    v, f = _blade(pts, [0.34, 0.26, 0.17, 0.09], [0.12, 0.10, 0.07, 0.045])
    return ("vf", _sz(v, s), f)


def tongue_b(k=1.0, s=1.0):
    p1 = _walk([(0.45, -6)])[1]
    r0 = _dring((0, 0), (0, 1), 0.30, 0.11)
    r1 = _dring(p1, _dir(-6), 0.26, 0.09)
    M = (p1[0], 0.0, p1[1] + 0.03)
    v = r0 + r1 + [M]  # 0-3 base, 4-7 F L B R, 8 crotch
    F, L, B, R = 4, 5, 6, 7
    f = [(3, 2, 1, 0)] + [(k_, (k_ + 1) % 4, 4 + (k_ + 1) % 4, 4 + k_) for k_ in range(4)]
    # prong 1: the big hook to -X (the other way from A), one mid ring
    loop1 = [L, B, R, 8]
    c1 = sum((Vector(v[i]) for i in loop1), Vector()) / 4
    d1 = _dir(-40 * k, 0.24)
    m1 = (c1.x + d1[0], c1.z + d1[1])
    mr = _dring(m1, _dir(-60 * k), 0.12, 0.06)
    b = len(v)
    v += [mr[1], mr[2], mr[3], mr[0]]
    mid = [b, b + 1, b + 2, b + 3]
    d2 = _dir(-115 * k, 0.2)
    v.append((m1[0] + d2[0], 0.0, m1[1] + d2[1]))
    t1 = len(v) - 1
    f += [(loop1[i], loop1[(i + 1) % 4], mid[(i + 1) % 4], mid[i]) for i in range(4)]
    f += [(mid[i], mid[(i + 1) % 4], t1) for i in range(4)]
    # prong 2: the short split spike up and forward
    loop2 = [F, L, 8, R]
    c2 = sum((Vector(v[i]) for i in loop2), Vector()) / 4
    d3 = _dir(18, 0.24)
    v.append((c2.x + d3[0], 0.0, c2.z + d3[1]))
    t2 = len(v) - 1
    f += [(loop2[i], loop2[(i + 1) % 4], t2) for i in range(4)]
    return ("vf", _sz(v, s), f)


def tongue_c(k=1.0, s=1.0):
    # stubby blade whose single tip droops over to +X (the ring is tilted so the back edge rises into the hook)
    p1 = (0.08, 0.5)
    r0 = _dring((0, 0), (0, 1), 0.36, 0.14)
    r1 = _dring(p1, _dir(55), 0.26, 0.10)
    d = _dir(40 + 80 * k, 0.36)
    v = r0 + r1 + [(p1[0] + d[0], 0.0, p1[1] + d[1])]
    f = [(3, 2, 1, 0)] + [(i, (i + 1) % 4, 4 + (i + 1) % 4, 4 + i) for i in range(4)] + [(4 + i, 4 + (i + 1) % 4, 8) for i in range(4)]
    return ("vf", _sz(v, s), f)


def b_ice_a():
    def pent(r, cx, rad, zs, sy=0.72, rot=18):
        return [(cx + r * rad[i] * math.cos(math.radians(rot + 72 * i)), r * rad[i] * sy * math.sin(math.radians(rot + 72 * i)), zs[i]) for i in range(5)]
    rad = [1.0, 0.86, 0.95, 0.8, 0.92]
    v = pent(0.24, 0, rad, [0] * 5) + pent(0.2, 0.05, rad, [0.55] * 5)
    v += pent(0.16, 0.09, [1.0, 0.86, 0.45, 0.8, 0.92], [0.84, 0.78, 0.68, 0.80, 0.90])  # vertex 2 chipped in and down
    v.append((0.13, 0.01, 1.0))
    f = [(a + i, a + (i + 1) % 5, b + (i + 1) % 5, b + i) for a, b in ((0, 5), (5, 10)) for i in range(5)]
    f.append((4, 3, 2, 1, 0))
    f += [(10 + i, 10 + (i + 1) % 5, 15) for i in range(5)]
    return ("vf", v, f)


def b_ice_b():
    # wide plate leaning to +X, two chips bitten out of the left edge; tapered extrusion so the rims are angled
    out = [(-0.42, 0.0), (0.40, 0.0), (0.44, 0.40), (0.18, 0.98), (-0.04, 0.62), (-0.30, 0.64), (-0.24, 0.36)]
    out = [(x + 0.26 * z, z) for x, z in out]
    cx = sum(p[0] for p in out) / len(out)
    back = [(x, -0.08, z) for x, z in out]
    front = [(cx + (x - cx) * 0.88, 0.08, z * 0.94) for x, z in out]
    n = len(out)
    f = [tuple(reversed(range(n))), tuple(range(n, 2 * n))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    return ("vf", back + front, f)


def b_ice_c():
    r0 = [(0.12 * math.cos(math.radians(90 + 120 * i)), 0.09 * math.sin(math.radians(90 + 120 * i)), 0.0) for i in range(3)]
    r1 = [(0.03 + x * 0.7, y * 0.7, 0.5) for x, y, _ in r0]
    v = r0 + r1 + [(0.08, 0.0, 1.0)]
    f = [(2, 1, 0)] + [(i, (i + 1) % 3, 3 + (i + 1) % 3, 3 + i) for i in range(3)] + [(3 + i, 3 + (i + 1) % 3, 6) for i in range(3)]
    return ("vf", v, f)


def b_ice_cap():
    br = [0.5, 0.44, 0.48, 0.42, 0.5, 0.45]
    rz = [0.24, 0.20, 0.27, 0.19, 0.23, 0.26]
    base = [(br[i] * math.cos(math.radians(60 * i)), br[i] * math.sin(math.radians(60 * i)), 0.0) for i in range(6)]
    rim = [(0.33 * math.cos(math.radians(60 * i + 30)), 0.33 * math.sin(math.radians(60 * i + 30)), rz[i]) for i in range(6)]
    f = [(5, 4, 3, 2, 1, 0), tuple(range(6, 12))]
    for i in range(6):
        j = (i + 1) % 6
        f += [(i, j, 6 + i), (j, 6 + j, 6 + i)]
    return ("vf", base + rim, f)


def b_leaf():
    v = [(0, 0, 0), (-0.2, 0.07, 0.34), (-0.12, 0.05, 0.72), (0, 0, 1.0), (0.12, 0.05, 0.74), (0.19, 0.07, 0.38)]
    return ("vf", v, [(0, 1, 2, 3), (0, 3, 4, 5)])


def b_crown():
    n, R = 16, 0.5
    cor = [math.radians(11.25 + 22.5 * k) for k in range(n)]
    bot = [(R * math.cos(a), R * math.sin(a), 0.0) for a in cor]
    top = [(x, y, 0.045) for x, y, _ in bot]
    peak = [((bot[k][0] + bot[(k + 1) % n][0]) / 2, (bot[k][1] + bot[(k + 1) % n][1]) / 2, 0.075) for k in range(n)]
    v = bot + top + peak
    f = [(k, (k + 1) % n, n + (k + 1) % n, 2 * n + k, n + k) for k in range(n)]
    return ("vf", v, f)


def b_chevron():
    yz = [(0.05, 0.24), (0.5, -0.22), (0.255, -0.22), (0.0, 0.02), (-0.255, -0.22), (-0.5, -0.22), (-0.05, 0.24)]
    # two arm quads + the cut apex, as explicit faces (the outline is concave)
    return ("vf", [(0.0, y, z) for y, z in yz], [(0, 1, 2, 3), (6, 3, 4, 5), (6, 0, 3)])


def b_fold():
    yz = [(0, 0.5), (-0.32, 0.22), (-0.32, -0.22), (0, -0.5), (0.32, -0.22), (0.32, 0.22)]
    return ("vf", [(0.0, y, z) for y, z in yz], [tuple(range(6))])


def b_tele_ring():
    return ("vf", *_ring_arcs(0.5, 0.075, 8, 22.5, [(90, 14, 10), (270, 14, 10)]))


def b_shell():
    t = (1 + 5 ** 0.5) / 2
    V = [Vector(p).normalized() for p in [(-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0), (0, -1, t), (0, 1, t), (0, -1, -t), (0, 1, -t), (t, 0, -1), (t, 0, 1), (-t, 0, -1), (-t, 0, 1)]]
    F = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6), (7, 1, 8),
         (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9), (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)]
    cache, F2 = {}, []

    def mid(a, b):
        key = (min(a, b), max(a, b))
        if key not in cache:
            V.append(((V[a] + V[b]) / 2).normalized())
            cache[key] = len(V) - 1
        return cache[key]
    for a, b, c in F:
        ab, bc, ca = mid(a, b), mid(b, c), mid(c, a)
        F2 += [(a, ab, ca), (b, bc, ab), (c, ca, bc), (ab, bc, ca)]
    return ("vf", [tuple(p * 0.5) for p in V], F2)


def b_chunk_a():
    top = [(0.5, 0.05), (0.12, 0.42), (-0.38, 0.30), (-0.45, -0.2), (0.1, -0.4)]
    mid = [(0.40, -0.12), (-0.18, 0.40), (-0.30, -0.34)]
    keel = [(0.15, 0.02), (-0.18, -0.03)]
    return ("hull", [(x, y, 0.5) for x, y in top] + [(x, y, 0.24) for x, y in mid] + [(x, y, 0.0) for x, y in keel])


def b_chunk_b():
    pts = [(-0.35, -0.2, 0), (0.33, -0.24, 0), (0.37, 0.2, 0), (-0.3, 0.22, 0),
           (-0.31, -0.17, 0.22), (0.30, -0.2, 0.22), (0.35, 0.18, 0.09), (-0.27, 0.19, 0.22)]  # +X+Y top corner broken away
    rot = Matrix.Rotation(math.radians(14), 3, "X") @ Matrix.Rotation(math.radians(-8), 3, "Y")
    return ("hull", [tuple(rot @ Vector(p)) for p in pts])


def b_shield():
    return ("vf", [(0.0, 0.5 * math.cos(math.radians(90 + 60 * i)), 0.5 * math.sin(math.radians(90 + 60 * i))) for i in range(6)], [tuple(range(6))])


# name: (builder, element, anchor text, anchor mode, uv mode, open-sheet facing (None = closed), role, note tris)
VFX_SPECS = {
    "FX_Stroke": (b_stroke, "Wind, strips, bolt", "Head tip (+X end), tail to -X", "tip", "around_x", None, "FxWind", 12),
    "FX_Ring": (b_ring, "Footprints, gust, impact", "Centre, floor plane", "floor", "radial", (0, 0, 1), "FxWind", 64),
    "FX_FloorStar": (b_floorstar, "Ice front, impact crack", "Centre, floor plane", "floor", "radial", (0, 0, 1), "FxIce", 40),
    "Fire_TongueA": (tongue_a, "Fire", "Base centre", "base", "around_z", None, "FxFireDeep", 28),
    "Fire_TongueB": (tongue_b, "Fire", "Base centre", "base", "around_z", None, "FxFire", 24),
    "Fire_TongueC": (tongue_c, "Fire", "Base centre", "base", "around_z", None, "FxFireCore", 14),
    "Ice_PlateA": (b_ice_a, "Ice", "Base centre", "base", "around_z", None, "FxIce", 28),
    "Ice_PlateB": (b_ice_b, "Ice", "Base centre", "base_c", "xz", None, "FxIce", 24),
    "Ice_PlateC": (b_ice_c, "Ice, shards, hand", "Base centre", "base", "around_z", None, "FxIce", 12),
    "Ice_Cap": (b_ice_cap, "Ice", "Base centre", "base", "around_z", None, "FxIce", 20),
    "Heal_Leaf": (b_leaf, "Healing", "Base tip, grows +Z", "tip", "xz", (0, 1, 0), "FxHeal", 8),
    "Heal_Crown": (b_crown, "Healing", "Centre, floor plane", "floor", "around_z", "radial", "FxHeal", 96),
    "Stim_Chevron": (b_chevron, "Stim", "Centre, faces +X", "centre", "yz", (1, 0, 0), "FxFireCore", 12),
    "Tele_Fold": (b_fold, "Teleport", "Centre, faces +X", "centre", "yz", (1, 0, 0), "FxTele", 8),
    "Tele_Ring": (b_tele_ring, "Teleport", "Centre, flat (XY)", "centre", "radial", (0, 0, 1), "FxTele", 48),
    "Scan_Shell": (b_shell, "Scan", "Centre", "centre", "around_z", "radial_shell", "FxIceLight", 160),
    "Impact_ChunkA": (b_chunk_a, "Impact", "Base centre", "base_c", "around_z", None, "FxStone", 16),
    "Impact_ChunkB": (b_chunk_b, "Impact", "Base centre", "base_c", "around_z", None, "FxStone", 12),
    "Shield_Plate": (b_shield, "Shield", "Centre, faces +X", "centre", "yz", (1, 0, 0), "FxIceLight", 8),
}


def vfx_kit(S):
    rw_clear(VFX_PRE)
    col = rw_col(S, VFX_COL)
    out = {}
    for n in VFX_ORDER:
        build, _el, _an, anchor, uv, face, role, _bud = VFX_SPECS[n]
        ds = face is not None
        me = vx_mesh(VFX_PRE + n, build(), anchor, uv, None if face == "radial_shell" else face)
        o = rw_obj(col, VFX_PRE + n, me, role)
        if ds:
            o["fx_doubleSided"] = True
        me.calc_loop_triangles()
        out[n] = [len(me.loop_triangles)] + [round(x, 3) for x in o.dimensions]
    bpy.context.view_layer.update()
    return out


# --- T_FlameSheet --------------------------------------------------------------------------------------------
def _vx_emit(name, rgb, strength=1.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    e = nt.nodes.new("ShaderNodeEmission")
    e.inputs[0].default_value = (*rgb, 1.0)
    e.inputs[1].default_value = strength
    o = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(e.outputs[0], o.inputs[0])
    return m


def _vx_tmp_clear():
    for o in [o for o in bpy.data.objects if o.name.startswith(VFX_TMP)]:
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.curves, bpy.data.lights, bpy.data.cameras, bpy.data.materials, bpy.data.worlds):
        for d in [d for d in coll if d.name.startswith(VFX_TMP) and d.users == 0]:
            coll.remove(d)
    for c in [c for c in bpy.data.collections if c.name.startswith(VFX_TMP)]:
        bpy.data.collections.remove(c)


def _vx_render_prep(S, res, transparent):
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            S.render.engine = eng
            break
        except TypeError:
            continue
    S.render.resolution_x, S.render.resolution_y = res
    S.render.resolution_percentage = 100
    S.render.film_transparent = transparent
    S.view_settings.view_transform = "Standard"
    S.view_settings.look = "None"


def _vx_hide_others(S, keep):
    hid = []
    for o in S.objects:
        if o.name not in keep and not o.hide_render:
            o.hide_render = True
            hid.append(o)
    return hid


def vfx_flame_sheet(S, out=None):
    """16 frames of the three tongues overlapped (A back / dark, B mid, C front / light), hooks curling up then
    breaking off at the top; flat greys, orthographic, one 4x4 sheet (frame 1 top left, rows). RGBA PNG."""
    out = out or os.path.join(RW_WORK, "Textures", "T_FlameSheet.png")
    _vx_tmp_clear()
    rig = bpy.data.collections.new(VFX_TMP + "Flame")
    S.collection.children.link(rig)
    greys = [_vx_emit(VFX_TMP + "G%d" % i, (g, g, g)) for i, g in enumerate((0.13, 0.40, 1.0))]
    lay = [(tongue_a, 0.0, 0.0, 0.25, 1.0), (tongue_b, 0.37, 0.18, 0.0, 0.82), (tongue_c, 0.71, -0.12, -0.25, 0.6)]
    cell, g = 1.0, 1.04  # g: group scale; fills about 90% of a cell with the rising broken tips still inside it
    for f in range(16):
        r, c = divmod(f, 4)
        cx, cz = (c - 1.5) * cell - 0.14, (1.5 - r) * cell - 0.46
        for j, (fn, ph, dx, dy, sc) in enumerate(lay):
            tt = (f / 16.0 + ph) % 1.0
            if tt < 0.6:
                u = tt / 0.6
                me = vx_mesh(VFX_TMP + "m", fn(0.35 + 0.85 * u, 0.62 + 0.38 * u), norm=False)
                parts = [(me, (0, 0, 0))]
            else:
                u = (tt - 0.6) / 0.4
                me = vx_mesh(VFX_TMP + "m", fn(1.2, 1.0), norm=False)
                zc = 0.6 if fn is not tongue_c else 0.42
                up = me.copy()
                rw_plane_cut(me, (0, 0, zc), (0, 0, 1))
                rw_plane_cut(up, (0, 0, zc), (0, 0, -1))
                for v in me.vertices:
                    v.co.z *= 1.0 - 0.3 * u
                cen = sum((v.co for v in up.vertices), Vector()) / max(len(up.vertices), 1)
                tilt = Matrix.Rotation(math.radians(30 * u), 3, "Y")
                for v in up.vertices:  # the broken tip shrinks and turns about its own centre
                    v.co = cen + tilt @ ((v.co - cen) * (1.0 - 0.8 * u))
                parts = [(me, (0, 0, 0)), (up, (0.05 * u, 0, 0.08 + 0.25 * u))]
            for me_, off in parts:
                if not len(me_.vertices):
                    continue
                me_.materials.clear()
                me_.materials.append(greys[j])
                o = bpy.data.objects.new(VFX_TMP + "F%02d_%d" % (f, j), me_)
                rig.objects.link(o)
                o.location = (cx + (dx + off[0] * sc) * g, dy, cz + off[2] * sc * g)
                o.scale = (sc * g,) * 3
    cam_d = bpy.data.cameras.new(VFX_TMP + "Cam")
    cam_d.type = "ORTHO"
    cam_d.ortho_scale = 4 * cell
    cam = bpy.data.objects.new(VFX_TMP + "Cam", cam_d)
    rig.objects.link(cam)
    cam.location = (0, -10, 0)
    cam.rotation_euler = (math.radians(90), 0, 0)
    old_cam, old_world = S.camera, S.world
    S.camera = cam
    hid = _vx_hide_others(S, {o.name for o in rig.objects})
    _vx_render_prep(S, (1024, 1024), True)
    S.render.image_settings.file_format = "PNG"
    S.render.image_settings.color_mode = "RGBA"
    S.render.filepath = out
    os.makedirs(os.path.dirname(out), exist_ok=True)
    try:
        bpy.ops.render.render(write_still=True, scene=S.name)
    finally:
        for o in hid:
            o.hide_render = False
        S.camera, S.world = old_cam, old_world
        _vx_tmp_clear()
    return out


# --- contact sheets -------------------------------------------------------------------------------------------
def vfx_sheets(S, res_w=1600, names=None, suffix=""):
    """Copies of the kit laid out in note order with name labels; review colours + white-on-black silhouette."""
    names = names or VFX_ORDER
    _vx_tmp_clear()
    tmp = bpy.data.collections.new(VFX_TMP + "Sheet")
    S.collection.children.link(tmp)
    white = _vx_emit(VFX_TMP + "White", (1, 1, 1))
    d = Vector((1.0, -0.9, 0.75)).normalized()
    rot = (-d).to_track_quat("-Z", "Y")
    R, U = rot @ Vector((1, 0, 0)), rot @ Vector((0, 1, 0))
    cols = 5
    rows = (len(names) + cols - 1) // cols
    cs, rs = 1.7, 1.9
    for i, n in enumerate(names):
        src = bpy.data.objects[VFX_PRE + n]
        co = [v.co for v in src.data.vertices]
        ctr = Vector([(min(c[k] for c in co) + max(c[k] for c in co)) / 2 for k in range(3)])
        r, c = divmod(i, cols)
        P = R * (c - (cols - 1) / 2) * cs + U * (((rows - 1) / 2 - r) * rs + 0.15)
        cp = src.copy()
        cp.name = VFX_TMP + n
        tmp.objects.link(cp)
        if VFX_SPECS[n][5] == (1, 0, 0):  # sheets facing +X: turn the review copy toward the camera
            cp.rotation_euler = (0, 0, math.atan2(d.y, d.x))
            ctr = cp.rotation_euler.to_matrix() @ ctr
        cp.location = P - ctr
        cu = bpy.data.curves.new(VFX_TMP + "T" + n, "FONT")
        cu.body = n
        cu.size = 0.15
        cu.align_x = "CENTER"
        cu.materials.append(white)
        t = bpy.data.objects.new(VFX_TMP + "T" + n, cu)
        tmp.objects.link(t)
        t.location = P - U * 0.78
        t.rotation_euler = rot.to_euler()
    cam_d = bpy.data.cameras.new(VFX_TMP + "Cam")
    cam_d.type = "ORTHO"
    w, h = cols * cs + 0.3, rows * rs + 0.2
    cam_d.ortho_scale = w
    cam = bpy.data.objects.new(VFX_TMP + "Cam", cam_d)
    tmp.objects.link(cam)
    cam.location = d * 30
    cam.rotation_euler = rot.to_euler()
    for nm, dirv, en in (("Sun", (0.4, -0.3, 1.0), 3.5), ("Fill", (-0.8, 0.5, 0.3), 1.2)):
        ld = bpy.data.lights.new(VFX_TMP + nm, "SUN")
        ld.energy = en
        lo_ = bpy.data.objects.new(VFX_TMP + nm, ld)
        tmp.objects.link(lo_)
        lo_.rotation_euler = (-Vector(dirv)).to_track_quat("-Z", "Y").to_euler()
    wd = bpy.data.worlds.new(VFX_TMP + "World")
    wd.use_nodes = True
    bg = wd.node_tree.nodes.get("Background")
    bg.inputs[0].default_value = (0.006, 0.008, 0.012, 1)
    old_cam, old_world = S.camera, S.world
    S.camera, S.world = cam, wd
    hid = _vx_hide_others(S, {o.name for o in tmp.objects})
    _vx_render_prep(S, (res_w, int(res_w * h / w)), False)
    S.render.image_settings.file_format = "JPEG"
    S.render.image_settings.color_mode = "RGB"
    S.render.image_settings.quality = 90
    vl = S.view_layers[0]
    outs = []
    try:
        for tag, over, bgc in (("sheet", None, (0.006, 0.008, 0.012, 1)), ("silhouette", white, (0, 0, 0, 1))):
            vl.material_override = over
            bg.inputs[0].default_value = bgc
            p = os.path.join(RW_WORK, "Renders", "VFX_kit_%s%s.jpg" % (tag, suffix))
            os.makedirs(os.path.dirname(p), exist_ok=True)
            S.render.filepath = p
            bpy.ops.render.render(write_still=True, scene=S.name)
            outs.append(p)
    finally:
        vl.material_override = None
        for o in hid:
            o.hide_render = False
        S.camera, S.world = old_cam, old_world
        _vx_tmp_clear()
    return outs


# --- PARTS.md --------------------------------------------------------------------------------------------------
def vfx_parts_md(audit):
    rows, tot, bud = [], 0, 0
    for n in VFX_ORDER:
        o = bpy.data.objects[VFX_PRE + n]
        _b, el, an, _a, _uv, face, _r, budget = VFX_SPECS[n]
        o.data.calc_loop_triangles()
        tri = len(o.data.loop_triangles)
        x, y, z = o.dimensions
        ds = "yes" if o.get("fx_doubleSided") else "no"
        tot += tri
        bud += budget
        rows.append(f"| `{n}` | {el} | {an} | {x:.3f} x {y:.3f} x {z:.3f} | {y:.3f} x {z:.3f} x {x:.3f} | {tri} | {budget} | {ds} |")
    txt = ["# ReworkVFX parts", "",
           "Built by `vfx_kit.py` (live Blender MCP, scene `RW_VFX`, collection `ReworkVFX`) to the mesh list in "
           "[Ability VFX Direction](../../../../../vault/02%20Art/Ability%20VFX%20Direction.md). Export: `../Exports/ReworkVFX.fbx` + `.json` "
           "(prefix `ReworkVFX_` stripped). Longest side 1 stud; code scales in studs. Roblox size = Blender (x, y, z) -> (y, z, x).", "",
           "Double-sided pieces are single open sheets (or the one-surface shell) with `fx_doubleSided = True`: set "
           "`MeshPart.DoubleSided` in Studio. Their triangle count here is one side; the note's budget counts both sides.", "",
           "| Mesh | Element | Anchor | Size Blender (x y z) | Size Roblox (x y z) | Tris | Note budget | Double-sided |",
           "|---|---|---|---|---|---|---|---|"] + rows + [
           f"| **Total** | | | | | **{tot}** | {bud} | |", "",
           "## Audit (`rw_audit(\"ReworkVFX_\")`)", "",
           f"- objects {audit['objects']}, tris {audit['tris']}",
           f"- style: {audit['style'] or 'none'}",
           f"- open_edges (open sheets only): {', '.join(audit['open_edges']) or 'none'}",
           f"- overlap / coplanar / floating: ignored (every kit mesh sits at the origin; {len(audit['overlap'])} / {len(audit['coplanar'])} / {len(audit['floating'])} listed)", "",
           "Texture made here: `../Textures/T_FlameSheet.png` (1024 px, 4x4, frame 1 top left, RGBA: three flat greys on transparent; "
           "tongue A dark at the back, B mid, C light in front; each tongue grows and curls, then its tip breaks off and rises).", "",
           "Renders: `../Renders/VFX_kit_sheet.jpg`, `../Renders/VFX_kit_silhouette.jpg`."]
    p = os.path.join(VFX_DIR, "PARTS.md")
    os.makedirs(VFX_DIR, exist_ok=True)
    with open(p, "w", encoding="utf-8") as fh:
        fh.write("\n".join(txt) + "\n")
    return {"path": p, "tris": tot, "budget": bud}
