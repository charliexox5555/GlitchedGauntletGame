"""Molly canister (thrown fire grenade), ability rework v03.

Runs ONLY inside the live Blender MCP session, after rw_core:
    exec(open(r"<repo>/tools/blender/rework/rw_core.py").read())
    S = rw_scene("RW_MollyFrost")
    exec(open(r"<repo>/art-source/abilities/Rework/v03/Molly/molly_build.py").read())
    result = molly_build(S)

Axes: +X forward, +Y left, +Z up, 1 unit = 1 stud. Built around a working frame, then shifted so the
bounding-box centre is the origin (thrown prop). Moving parts keep their origin on their pivot.
"""
import bpy, bmesh, math
from mathutils import Vector, Matrix

SQ = 2 - math.sqrt(2)  # chamfer growth per unit of outward offset on a 45-degree corner


# --- helpers ---------------------------------------------------------------------------------------------
def m_loft(name, rings, mapf=None, cap=True):
    """Loft of 2D rings [(w, [(u, v), ...])]; mapf maps (u, v, w) -> world (x, y, z)."""
    mapf = mapf or (lambda u, v, w: (u, v, w))
    bm = bmesh.new()
    vr = [[bm.verts.new(mapf(u, v, w)) for (u, v) in pts] for w, pts in rings]
    n = len(vr[0])
    for a, b in zip(vr, vr[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if cap:
        bm.faces.new(list(reversed(vr[0])))
        bm.faces.new(vr[-1])
    return _rw_finish(bm, name)


XY_Z = lambda u, v, w: (u, v, w)   # profile in XY, extruded along Z
XZ_Y = lambda u, v, w: (u, w, v)   # profile in XZ, extruded along Y
YZ_X = lambda u, v, w: (w, u, v)   # profile in YZ, extruded along X


def ccw(pts):
    n = len(pts)
    a = sum(pts[i][0] * pts[(i + 1) % n][1] - pts[(i + 1) % n][0] * pts[i][1] for i in range(n))
    return pts if a > 0 else pts[::-1]


def poly_offset(pts, d):
    """Inset a convex polygon by d (d < 0 grows it). Keeps edges parallel, so facets stay planar."""
    pts = ccw(pts)
    n = len(pts)
    lines = []
    for i in range(n):
        a, b = Vector(pts[i]), Vector(pts[(i + 1) % n])
        e = (b - a).normalized()
        lines.append((a + Vector((-e.y, e.x)) * d, e))
    out = []
    for i in range(n):
        p1, e1 = lines[i - 1]
        p2, e2 = lines[i]
        den = e1.x * e2.y - e1.y * e2.x
        t = ((p2.x - p1.x) * e2.y - (p2.y - p1.y) * e2.x) / den
        q = p1 + e1 * t
        out.append((q.x, q.y))
    return out


def hull2d(pts):
    pts = sorted(set((round(x, 7), round(y, 7)) for x, y in pts))
    cr = lambda o, a, b: (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lo, up = [], []
    for p in pts:
        while len(lo) >= 2 and cr(lo[-2], lo[-1], p) <= 1e-12:
            lo.pop()
        lo.append(p)
    for p in reversed(pts):
        while len(up) >= 2 and cr(up[-2], up[-1], p) <= 1e-12:
            up.pop()
        up.append(p)
    return lo[:-1] + up[:-1]


def oct2(cu, cv, r, n=8):
    return [(cu + x, cv + y) for x, y in rw_ngon(r, n)]


def m_slab(name, poly, w0, w1, c, mapf=XY_Z):
    """Convex profile extruded from w0 to w1 with a flat chamfer c on both ends."""
    poly = ccw(poly)
    inner = poly_offset(poly, c)
    return m_loft(name, [(w0, inner), (w0 + c, poly), (w1 - c, poly), (w1, inner)], mapf)


def ring4(x0, x1, y0, y1, c):
    """Rectangle with four flat corner cuts c = (front-right, front-left, back-left, back-right)."""
    c0, c1, c2, c3 = c
    return [(x1 - c0, y0), (x1, y0 + c0), (x1, y1 - c1), (x1 - c1, y1),
            (x0 + c2, y1), (x0, y1 - c2), (x0, y0 + c3), (x0 + c3, y0)]


def edge_cham(me, pa, pb, n1, n2, d):
    """Flat chamfer on the straight edge pa-pb between faces with normals n1, n2 (d = depth along the bisector)."""
    pa, pb = Vector(pa), Vector(pb)
    e = (pb - pa).normalized()
    n = Vector(n1).normalized() + Vector(n2).normalized()
    n -= e * n.dot(e)
    n.normalize()
    rw_plane_cut(me, pa - n * d, n)


def seg_at_x(p, q, x):
    s = (p[0] - x) / (p[0] - q[0])
    return (p[0] + (q[0] - p[0]) * s, p[1] + (q[1] - p[1]) * s)


# --- the shell -----------------------------------------------------------------------------------------
XB, YH, CB, CF = -0.135, 0.165, 0.05, 0.08   # back plane (vertical: it carries the latch), half width, corner cuts
Z0, ZW, ZS = -0.15, 0.075, 0.115             # shell bottom, top of the walls, deck height
LEAN, TAPER, SH = 0.03, 0.016, 0.025        # front lean, side taper over the wall height, shoulder inset
ZL, RAKE = 0.056, 0.4                        # lid lip underside, slope of the raked front cut


def xf_at(z):
    return 0.135 - (z - Z0) * (LEAN / (ZW - Z0))


def yh_at(z):
    return YH - (z - Z0) * (TAPER / (ZW - Z0))


def body_ring(z, t=0.0):
    """Shell cross-section at height z, offset outward by t (negative = inside). Linear in z, so a
    two-ring loft of any offset is exact and every facet stays planar."""
    cb, cf = CB + t * SQ, CF + t * SQ
    yh = yh_at(z) + t
    return ring4(XB - t, xf_at(z) + t, -yh, yh, (cf, cf, cb, cb))


def lean_loft(name, t, z_lo=-0.3, z_hi=0.3):
    return m_loft(name, [(z_lo, body_ring(z_lo, t)), (z_hi, body_ring(z_hi, t))])


# layout
HX, HZ = -0.145, -0.105       # latch hinge axis (along Y)
PinX, PinZ = HX, 0.152        # pull-pin axis (along Y)
PX, PY = -0.052, 0.088        # arming pad centre
NX, NY = 0.04, -0.022         # burner nozzle foot on the raked cut
LX, FZ = -0.07, 0.168         # fuse light centre x, fuse-head top
XE, ZC, PT = XB + 0.012, 0.005, 0.006   # panel back end, its cut-corner start, panel proud height


# heat-panel back end: square to the back-left facet, parallel to the facet's back edge, END_E along it
END_E = 0.012
_r2 = 1 / math.sqrt(2)
END_N = Vector((0, -TAPER, ZW - Z0)).normalized().cross(Vector((-_r2, _r2, 0))).normalized()  # points at the corner
END_P = Vector((XB + END_E * _r2, YH - CB + END_E * _r2, Z0))
END_RN = Vector((END_N.x, -END_N.y, END_N.z))   # the same end on the back-right facet
END_RP = Vector((END_P.x, -END_P.y, END_P.z))
CUT_N = Vector((-0.5, -0.5, _r2))   # the 45-degree cut corner, top-back (left end only)
CUT_P = Vector((XB + END_E * _r2, YH - CB + END_E * _r2 - TAPER * (ZC - Z0) / (ZW - Z0), ZC))


def _half_region(name, gp, zr, side):
    me = rw_hull(name, [(x, y, z) for x in (-0.4, 0.4) for y in (-0.4, 0.4) for z in (-0.4, 0.4)])
    if side > 0:   # left half: left end (square to the back-left facet) + the cut corner
        rw_plane_cut(me, (0, -0.01, 0), (0, -1, 0))
        rw_plane_cut(me, END_P + END_N * gp, END_N)
        rw_plane_cut(me, CUT_P + CUT_N * gp, CUT_N)
    else:          # right half: right end only
        rw_plane_cut(me, (0, 0.01, 0), (0, 1, 0))
        rw_plane_cut(me, END_RP + END_RN * gp, END_RN)
    if zr:
        rw_plane_cut(me, (0, 0, zr[1]), (0, 0, 1))
        rw_plane_cut(me, (0, 0, zr[0]), (0, 0, -1))
    return me


def panel_region(C, name, gp, zr=None):
    """Region the heat jacket occupies: everything but the back (the latch side). It wraps about 270
    degrees, so it is the union of two convex halves. gp grows it by the shadow gap for the seat cut."""
    a = rw_obj(C, name, _half_region(name, gp, zr, 1))
    b = rw_obj(C, name + "_b", _half_region(name + "_b", gp, zr, -1))
    rw_bool(a, b, "UNION")
    return a


def seg_plane(p, q, z, P0, N):
    """Point on the horizontal segment p-q (2D, at height z) that lies on the plane (P0, N)."""
    A = Vector((p[0], p[1], z))
    B = Vector((q[0] - p[0], q[1] - p[1], 0))
    s = N.dot(Vector(P0) - A) / N.dot(B)
    return A + B * s


MOLLY_SCALE = 1.2   # parent review 2026-11-16: Molly read small in the hand; uniform scale about the origin


def scale_col(C, s):
    """Uniform scale of a built prop about the origin: mesh data, object and locator positions."""
    for o in C.objects:
        if o.type == "MESH":
            o.data.transform(Matrix.Scale(s, 4))
        o.location = o.location * s


# --- build ---------------------------------------------------------------------------------------------
def molly_build(S):
    rw_clear("Molly_")
    for e in [o for o in bpy.data.objects if o.name.startswith("Molly")]:
        bpy.data.objects.remove(e, do_unlink=True)
    C = rw_col(S, "Molly")

    def T(name, mesh, loc=(0, 0, 0)):
        return rw_obj(C, "Molly_tmp_" + name, mesh, None, loc)

    r2 = 1 / math.sqrt(2)

    # 1 BODY: tapered octagonal shell, vertical back, shoulder chamfer, flat back deck, raked cut at the front
    body = rw_obj(C, "Molly_Body", m_loft("Molly_Body", [(Z0, body_ring(Z0)), (ZL + 0.002, body_ring(ZL + 0.002))]), "Body")
    # LID: shoulder cap whose lip overhangs the shell by 0.006 (a real shadow line), flat deck, raked front cut
    lid = rw_obj(C, "Molly_Lid", m_loft("Molly_Lid", [
        (ZL, body_ring(ZL, 0.006)), (ZL + 0.01, body_ring(ZL + 0.01, 0.006)), (ZS, body_ring(ZW, -SH))]), "Panel")
    for o in (body, lid):
        rw_plane_cut(o.data, (0.0, 0, ZS), (RAKE, 0, 1))

    # heat-panel seat: the panel region grown by the shadow gap g, cut 0.010 deep
    g = 0.006
    seat = panel_region(C, "Molly_tmp_seat", g, (-0.115 - g, 0.045 + g))
    rw_bool(seat, T("shr", lean_loft("Molly_tmp_shr", -0.010)), "DIFFERENCE")
    rw_bool(body, seat, "DIFFERENCE")

    # latch channel down the back face, 0.008 deep: 45-degree run-out at the bottom, runs out through the lid at the top
    ch = T("ch", m_slab("Molly_tmp_ch", hull2d([(-0.4, -0.395), (-0.05, -0.045), (-0.05, 0.3), (-0.4, 0.3)]),
                        -0.052, 0.052, 0.0001, XZ_Y))
    rw_bool(ch, T("shr3", lean_loft("Molly_tmp_shr3", -0.008)), "DIFFERENCE")
    rw_bool(lid, ch, "DIFFERENCE", keep_cutter=True)
    rw_bool(body, ch, "DIFFERENCE")

    # pad pocket in the deck
    pad_in = ring4(PX - 0.026, PX + 0.026, PY - 0.021, PY + 0.021, (0.006, 0.012, 0.006, 0.006))
    rw_bool(lid, T("pocket", m_loft("Molly_tmp_pocket", [(0.085, pad_in), (0.3, pad_in)])), "DIFFERENCE")

    # 2 HEAT PANEL: warm jacket wrapping front, front-left, left and back-left; proud PT, seated in its cut
    pan = rw_obj(C, "Molly_Panel_Warm", m_loft("Molly_Panel_Warm", [
        (-0.115, body_ring(-0.115, 0.0)), (-0.109, body_ring(-0.109, PT)),
        (0.039, body_ring(0.039, PT)), (0.045, body_ring(0.045, 0.0))]), "Warm")
    rw_bool(pan, panel_region(C, "Molly_tmp_reg", 0.0, (-0.2, 0.1)), "INTERSECT")
    rw_bool(pan, T("shr2", lean_loft("Molly_tmp_shr2", -0.012)), "DIFFERENCE")
    d = 0.0035
    fn = Vector((-r2, r2, 0))   # back-left facet normal
    pts = [seg_plane(body_ring(z, PT)[5], body_ring(z, PT)[4], z, END_P, END_N) for z in (-0.1, -0.02)]
    edge_cham(pan.data, pts[0], pts[1], fn, END_N, d)
    pts = [seg_plane(body_ring(z, PT)[5], body_ring(z, PT)[4], z, CUT_P, CUT_N) for z in (0.016, 0.03)]
    edge_cham(pan.data, pts[0], pts[1], fn, CUT_N, d)
    # right end (on the back-right facet)
    pts = [seg_plane(body_ring(z, PT)[6], body_ring(z, PT)[7], z, END_RP, END_RN) for z in (-0.1, 0.03)]
    edge_cham(pan.data, pts[0], pts[1], (-r2, -r2, 0), END_RN, d)
    for p in pan.data.polygons:
        p.use_smooth = False

    # 3 FOOT: wider base collar; a back heel carrying the hinge ears
    foot = rw_obj(C, "Molly_Foot", m_loft("Molly_Foot", [
        (-0.2, body_ring(-0.2, 0.013)), (-0.193, body_ring(-0.193, 0.02)),
        (-0.151, body_ring(-0.151, 0.006)), (-0.142, body_ring(-0.142, -0.004))]), "Dark")
    rw_bool(foot, T("heel", m_slab("Molly_tmp_heel", [(-0.13, -0.2), (-0.13, -0.135), (-0.152, -0.135),
                                                       (-0.168, -0.151), (-0.168, -0.185), (-0.158, -0.2)],
                                   -0.046, 0.046, 0.004, XZ_Y)), "UNION")
    # raked toe: the front-bottom of the foot is cut back, echoing the raked cut on the lid
    rw_plane_cut(foot.data, (xf_at(-0.19) + 0.012, 0, -0.172), (1, 0, -0.8))
    ear_p = hull2d(oct2(HX, HZ, 0.017) + [(-0.162, -0.14), (-0.124, -0.14), (-0.124, -0.092)])
    for y0, y1 in ((0.028, 0.046), (-0.046, -0.028)):
        rw_bool(foot, T("ear", m_slab("Molly_tmp_ear", ear_p, y0, y1, 0.003, XZ_Y)), "UNION")

    # 4 ARMING HEAD: low raked block on the back deck (it echoes the lid's raked cut). It overhangs the back
    # shoulder, and a fork slot in its back takes the latch tongue; the pull pin runs through both cheeks.
    fh = rw_obj(C, "Molly_FuseHead", m_slab("Molly_FuseHead", [
        (-0.004, 0.111), (-0.004, 0.152), (-0.02, FZ), (-0.15, FZ), (-0.166, 0.152), (-0.166, 0.14), (-0.104, 0.111)],
        -0.05, 0.05, 0.005, XZ_Y), "Body")
    rw_bool(fh, T("fork", rw_hull("Molly_tmp_fork", [(x, y, z) for x in (-0.3, -0.128) for y in (-0.025, 0.025)
                                                      for z in (0.0, 0.3)])), "DIFFERENCE")

    # 5 FUSE bezel + light, set low into the head (not a knob)
    bez = rw_obj(C, "Molly_FuseBezel", m_loft("Molly_FuseBezel", [
        (FZ - 0.003, oct2(LX, 0, 0.026)), (FZ + 0.004, oct2(LX, 0, 0.026)), (FZ + 0.007, oct2(LX, 0, 0.022))]), "Dark")
    rw_bool(bez, T("hole", m_loft("Molly_tmp_hole", [(0.1, oct2(LX, 0, 0.0175)), (0.3, oct2(LX, 0, 0.0175))])), "DIFFERENCE")
    rw_obj(C, "Molly_Fuse_Energy", m_loft("Molly_Fuse_Energy", [
        (FZ - 0.005, oct2(LX, 0, 0.016)), (FZ + 0.008, oct2(LX, 0, 0.016)), (FZ + 0.011, oct2(LX, 0, 0.0125))]), "Energy")

    # 6 LATCH: slotted lever; knuckle on the heel hinge, tongue pinned between the fuse-head ears
    L = (HX, 0, HZ)
    lat = rw_obj(C, "Molly_Latch", m_loft("Molly_Latch", [
        (-0.025, rw_ngon(0.011, 8)), (-0.021, rw_ngon(0.015, 8)), (0.021, rw_ngon(0.015, 8)), (0.025, rw_ngon(0.011, 8))],
        XZ_Y), "Metal", L)
    TZ = PinZ - HZ
    rw_bool(lat, T("arm", m_slab("Molly_tmp_arm", [(0.025, 0.0), (0.025, 0.026), (0.042, 0.07), (0.042, TZ - 0.08), (0.026, TZ - 0.034),
                                                    (-0.026, TZ - 0.034), (-0.042, TZ - 0.08), (-0.042, 0.07), (-0.025, 0.026), (-0.025, 0.0)],
                                   -0.009, 0.009, 0.0045, YZ_X), L), "UNION")
    rw_bool(lat, T("tng", m_slab("Molly_tmp_tng", [(0.021, TZ - 0.035), (0.021, TZ - 0.002), (0.013, TZ + 0.006),
                                                    (-0.013, TZ + 0.006), (-0.021, TZ - 0.002), (-0.021, TZ - 0.035)],
                                   -0.008, 0.008, 0.004, YZ_X), L), "UNION")
    sl = [(0, 0.075), (0.011, 0.09), (0.011, 0.16), (0, 0.175), (-0.011, 0.16), (-0.011, 0.09)]
    rw_bool(lat, T("slot", m_loft("Molly_tmp_slot", [(-0.05, sl), (0.05, sl)], YZ_X), L), "DIFFERENCE")

    # 7 HINGE PIN through the heel ears and the knuckle
    rw_obj(C, "Molly_HingePin", m_loft("Molly_HingePin", [
        (-0.051, rw_ngon(0.007, 8)), (-0.048, rw_ngon(0.010, 8)), (-0.045, rw_ngon(0.010, 8)), (-0.045, rw_ngon(0.0062, 8, 0)),
        (0.045, rw_ngon(0.0062, 8, 0)), (0.045, rw_ngon(0.010, 8)), (0.048, rw_ngon(0.010, 8)), (0.051, rw_ngon(0.007, 8))],
        XZ_Y), "Metal", L)

    # 8 PULL PIN: shaft through ears + tongue, collar on the right, faceted ring hanging off the back-left
    P0 = (PinX, 0, PinZ)
    pin = rw_obj(C, "Molly_Pin", m_loft("Molly_Pin", [
        (-0.062, rw_ngon(0.0075, 8)), (-0.059, rw_ngon(0.0095, 8)), (-0.049, rw_ngon(0.0095, 8)),
        (-0.049, rw_ngon(0.0062, 8, 0)), (0.07, rw_ngon(0.0062, 8, 0))], XZ_Y), "Accent", P0)
    bm = bmesh.new()
    N, M, RC, RB, YA = 10, 6, 0.035, 0.0065, 0.064
    rows = []
    for i in range(N):
        ph = 2 * math.pi * i / N
        rad = Vector((0, math.cos(ph), math.sin(ph)))
        ctr = Vector((0, YA + RC, 0)) + rad * RC
        rows.append([bm.verts.new(ctr + (rad * math.cos(2 * math.pi * k / M + math.pi / M) + Vector((1, 0, 0))
                                         * math.sin(2 * math.pi * k / M + math.pi / M)) * RB) for k in range(M)])
    for i in range(N):
        a, b = rows[i], rows[(i + 1) % N]
        for k in range(M):
            bm.faces.new((a[k], a[(k + 1) % M], b[(k + 1) % M], b[k]))
    bmesh.ops.transform(bm, matrix=Matrix.Translation((0, YA, 0)) @ Matrix.Rotation(math.radians(-65), 4, "X")
                        @ Matrix.Translation((0, -YA, 0)), verts=bm.verts)
    rw_bool(pin, T("ring", _rw_finish(bm, "Molly_tmp_ring"), P0), "UNION")

    # 9 ARMING PAD: framed pocket in the deck, thumb pad on a plunger
    fo = ring4(PX - 0.036, PX + 0.036, PY - 0.03, PY + 0.03, (0.008, 0.018, 0.008, 0.008))
    fr = rw_obj(C, "Molly_PadFrame", m_loft("Molly_PadFrame", [
        (0.112, fo), (0.118, fo), (0.122, poly_offset(fo, 0.004))]), "Dark")
    rw_bool(fr, T("frh", m_loft("Molly_tmp_frh", [(0.05, pad_in), (0.3, pad_in)])), "DIFFERENCE")
    cap = [(x - PX, y - PY) for x, y in ring4(PX - 0.022, PX + 0.022, PY - 0.017, PY + 0.017, (0.004, 0.009, 0.004, 0.004))]
    PZ = 0.128
    pad = rw_obj(C, "Molly_ArmPad", m_loft("Molly_ArmPad", [
        (-0.010, cap), (-0.004, cap), (0.0, poly_offset(cap, 0.004))]), "Warm", (PX, PY, PZ))
    rw_bool(pad, T("stem", m_loft("Molly_tmp_stem", [(-0.045, rw_ngon(0.011, 8)), (-0.009, rw_ngon(0.011, 8))]),
                   (PX, PY, PZ)), "UNION")

    # 10 HEAT SLOTS: two closed machined slots through the jacket on the left flank (the dark seat shows through)
    for zs in (-0.062, -0.032):
        sp = [(-0.068, zs), (-0.062, zs - 0.006), (0.012, zs - 0.006), (0.018, zs), (0.012, zs + 0.006), (-0.062, zs + 0.006)]
        rw_bool(pan, T("slt", m_loft("Molly_tmp_slt", [(0.1, sp), (0.3, sp)], XZ_Y)), "DIFFERENCE")

    # 10b HEAT CHEVRONS: two upward chevron vents cut through the front of the jacket (heat rising)
    for za in (0.024, -0.004):
        for sgn in (1, -1):
            arm = [(0.0, za), (sgn * 0.03, za - 0.018), (sgn * 0.03, za - 0.027), (0.0, za - 0.009)]
            rw_bool(pan, T("chev", m_loft("Molly_tmp_chev", [(0.06, arm), (0.3, arm)], YZ_X)), "DIFFERENCE")

    # 11 BURNER NOZZLE: faceted outlet on the raked front cut, leaning forward 40 degrees, scarf-cut mouth with a bore
    NA = 50.0
    nax = Vector((math.sin(math.radians(NA)), 0, math.cos(math.radians(NA))))
    NP = Vector((NX, NY, ZS - RAKE * NX))
    col = rw_obj(C, "Molly_NozzleCollar", m_loft("Molly_NozzleCollar", [
        (-0.022, rw_ngon(0.034, 8)), (0.018, rw_ngon(0.034, 8)), (0.024, rw_ngon(0.029, 8))]), "Body", NP, (0, NA, 0))
    noz = rw_obj(C, "Molly_Nozzle", m_loft("Molly_Nozzle", [
        (0.014, rw_ngon(0.024, 8)), (0.032, rw_ngon(0.024, 8)), (0.038, rw_ngon(0.018, 8)), (0.05, rw_ngon(0.018, 8)),
        (0.072, rw_ngon(0.031, 8)), (0.084, rw_ngon(0.031, 8))]), "Metal", NP, (0, NA, 0))
    # scarf cut: the mouth is cut back at 30 degrees so it opens forward-up
    me = noz.data
    rw_plane_cut(me, (0, 0, 0.074), (0.42, 0, 0.906))
    bore = T("bore", m_loft("Molly_tmp_bore", [(0.03, rw_ngon(0.011, 8)), (0.05, rw_ngon(0.011, 8)), (0.072, rw_ngon(0.024, 8)), (0.2, rw_ngon(0.024, 8))]), NP)
    bore.rotation_euler = (0, math.radians(NA), 0)
    rw_bool(noz, bore, "DIFFERENCE")

    # 12 STRAP RIBS: two chamfered straps on the front corners clamp the jacket from foot to lid
    ribs = None
    for (i0, i1) in ((2, 3), (0, 1)):   # front-left and front-right corner facets of body_ring
        rings = []
        for z in (-0.15, 0.05):
            rg = body_ring(z)
            p, q = Vector(rg[i0]), Vector(rg[i1])
            m, u = (p + q) / 2, (q - p).normalized()
            n = Vector((u.y, -u.x)) if (Vector((u.y, -u.x))).dot(m) > 0 else Vector((-u.y, u.x))
            W, TI, TO, CH = 0.019, -0.004, 0.016, 0.005
            pts = [m - u * W + n * TI, m + u * W + n * TI, m + u * W + n * (TO - CH), m + u * (W - CH) + n * TO,
                   m - u * (W - CH) + n * TO, m - u * W + n * (TO - CH)]
            rings.append((z, [(v.x, v.y) for v in pts]))
        me = m_loft("Molly_Ribs", rings)
        nh = Vector((n.x, n.y, 0))
        top = Vector((m.x, m.y, 0.05)) + nh * 0.003
        rw_plane_cut(me, top, (nh + Vector((0, 0, 1))).normalized())
        if ribs is None:
            ribs = rw_obj(C, "Molly_Ribs", me, "Body")
        else:
            rw_bool(ribs, T("rib2", me), "UNION")

    # --- one material per part (rw_bool leaves an empty extra slot; cut faces can land on it), no slivers ---
    for o in [o for o in C.objects if o.type == "MESH"]:
        me = o.data
        mat = next(m for m in me.materials if m)
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.dissolve_degenerate(bm, dist=1e-6, edges=bm.edges)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
        bm.to_mesh(me)
        bm.free()
        me.materials.clear()
        me.materials.append(mat)
        for p in me.polygons:
            p.material_index = 0
            p.use_smooth = False
        me.update()

    # --- centre on the bounding box (thrown prop: origin = centre) ---
    bpy.context.view_layer.update()
    lo, hi = rw_bounds("Molly_")
    c = (lo + hi) / 2
    moving = {"Molly_Latch", "Molly_HingePin", "Molly_Pin", "Molly_ArmPad"}
    for o in [o for o in C.objects if o.type == "MESH"]:
        if o.name in moving or o.location.length > 0 or any(o.rotation_euler):
            o.location -= c
        else:
            o.data.transform(Matrix.Translation(-c))
    rw_empty(C, "Molly_Handle", (0, 0, 0), size=0.04)
    rw_empty(C, "Molly_Fuse", Vector((LX, 0, FZ + 0.011)) - c, size=0.03, kind="SINGLE_ARROW")
    # local Y = -world Y, so a POSITIVE turn about the locator's local Y swings the latch open (backwards)
    rw_empty(C, "Molly_LatchPivot", Vector(L) - c, rot=(0, 0, 180), size=0.04)
    rw_empty(C, "Molly_PinOut", Vector((PinX, 0.14, PinZ)) - c, size=0.03)
    rw_empty(C, "Molly_ArmPadDown", Vector((PX, PY, PZ - 0.016)) - c, size=0.03)
    scale_col(C, MOLLY_SCALE)
    bpy.context.view_layer.update()
    lo, hi = rw_bounds("Molly_")
    return {"shift": [round(v, 4) for v in c], "size": [round(v, 4) for v in (hi - lo)]}


MOLLY_SEATS = [("Molly_Body", "Molly_Foot"), ("Molly_Panel_Warm", "Molly_Body"), ("Molly_FuseHead", "Molly_Lid"),
               ("Molly_Lid", "Molly_Body"), ("Molly_PadFrame", "Molly_Lid"), ("Molly_ArmPad", "Molly_Lid"), ("Molly_HingePin", "Molly_Foot"),
               ("Molly_HingePin", "Molly_Latch"), ("Molly_Pin", "Molly_FuseHead"), ("Molly_Pin", "Molly_Latch"),
               ("Molly_Fuse_Energy", "Molly_FuseHead"), ("Molly_FuseBezel", "Molly_FuseHead"),
               ("Molly_NozzleCollar", "Molly_Lid"), ("Molly_Nozzle", "Molly_NozzleCollar"),
               ("Molly_Ribs", "Molly_Panel_Warm"), ("Molly_Ribs", "Molly_Body"), ("Molly_Ribs", "Molly_Foot")]


def molly_coplanar(a, b):
    """Debug: centres of faces of a that sit within 0.004 of a same-facing face of b."""
    dg = bpy.context.evaluated_depsgraph_get()
    A, B = _rw_bvh(bpy.data.objects[a], dg), _rw_bvh(bpy.data.objects[b], dg)
    out = []
    for nrm, cen in zip(A[2], A[3]):
        loc, hn, _i, _d = B[0].ray_cast(cen + nrm * 0.004, -nrm, 0.008)
        if loc is not None and hn.dot(nrm) > 0.999:
            out.append([round(v, 4) for v in cen] + [round(v, 2) for v in nrm])
    return out
