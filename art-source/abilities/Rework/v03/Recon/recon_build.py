"""Recon bow + sensor bolt (ability rework v03). Run in the LIVE Blender MCP only:

    exec(open(r"<repo>/tools/blender/rework/rw_core.py").read())
    S = rw_scene("RW_Recon")
    exec(open(r"<repo>/art-source/abilities/Rework/v03/Recon/recon_build.py").read())
    recon_build(S)

Axes: +X forward (target), +Y player's left, +Z up, 1 unit = 1 stud.
Bow origin = grip. Bolt origin = tip, body along -X.
"""
import bpy, bmesh, math
from mathutils import Vector, Matrix

RC_PIV = (0.035, 0.355)          # limb pivot (x, |z|), on the limb bolt axis (Y)
RC_TIP = (-0.335, 0.732)         # string nock at each limb tip (x, |z|), at rest
RC_NOCK = Vector((-0.335, 0.0, 0.11))
RC_DRAW = 0.55                   # nock travel at full draw (along -X)
RC_DART_X = 0.647                # dart tip x on the bow at rest (nock slot bottom on the string)
RC_STRING_R = 0.008              # string hex circumradius (0.0139 across flats)

RECON_SEATS = [
    ("Recon_Grip", "Recon_Riser"),          # grip wrap clamps round the riser throat
    ("Recon_Pocket", "Recon_Riser"),        # pocket base caps the riser end, sunk 0.01
    ("Recon_Bolt", "Recon_Pocket"),         # pivot bolt through both pocket cheeks
    ("Recon_BoltTop", "Recon_LimbTop"),     # pivot bolt through the limb knuckle
    ("Recon_BoltBottom", "Recon_LimbBottom"),
    ("Recon_TipCap", "Recon_Limb"),         # nock caps clamp the limb tips
    ("Recon_String", "Recon_TipCap"),       # string loops seat in the nock caps
    ("Recon_StringTop", "Recon_StringBottom"),  # the two string halves meet at the nocking point
    ("Recon_Rest", "Recon_Riser"),          # rest seated on the shelf and into the window wall
    ("Recon_Readout", "Recon_Riser"),       # read-out plate sunk into the rear face
    ("Recon_Charge_Energy", "Recon_Readout"),
    ("Recon_Bounce", "Recon_Readout"),
    ("Recon_Sensor", "Recon_Riser"),        # sensor housing sunk into the window cheek
    ("Recon_SensorLens", "Recon_Sensor"),
    ("Recon_Screw", "Recon_"),              # fixings are screwed into whatever they hold
    ("Recon_Dart_", "Recon_Dart_"),         # the nocked bolt's own seats (same as ReconDart)
    ("Recon_Dart_Nock", "Recon_String"),    # string sits in the nock throat
    ("Recon_Dart_Shaft", "Recon_String"),   # at full draw the string bears on the nock throat (shaft end inside the nock)
]
DART_SEATS = [
    ("Head", "Collar"), ("Light_Energy", "Collar"), ("Band", "Collar"),
    ("Shaft", "Collar"), ("Band", "Shaft"), ("Light_Energy", "Shaft"), ("Shaft", "Fletch"), ("Shaft", "Nock"), ("Fletch", "Nock"),
]


# --- small geometry helpers ---------------------------------------------------------------------
def _rings_bm(rings3d, cap=True):
    bm = bmesh.new()
    vr = [[bm.verts.new(p) for p in r] for r in rings3d]
    for a, b in zip(vr, vr[1:]):
        if len(a) == 1:
            n = len(b)
            for i in range(n):
                bm.faces.new((a[0], b[i], b[(i + 1) % n]))
        elif len(b) == 1:
            n = len(a)
            for i in range(n):
                bm.faces.new((a[i], a[(i + 1) % n], b[0]))
        else:
            n = len(a)
            for i in range(n):
                j = (i + 1) % n
                bm.faces.new((a[i], a[j], b[j], b[i]))
    if cap:
        if len(vr[0]) > 2:
            bm.faces.new(list(reversed(vr[0])))
        if len(vr[-1]) > 2:
            bm.faces.new(vr[-1])
    return bm


def loft_f(name, rings, O=(0, 0, 0), U=(1, 0, 0), A=(0, 1, 0), B=(0, 0, 1), cap=True):
    """Loft along U; each ring is (u, [(a, b), ...]) in the A/B plane. A ring of one point = apex."""
    O, U, A, B = (Vector(v) for v in (O, U, A, B))
    r3 = [[O + U * u + A * a + B * b for (a, b) in pts] for u, pts in rings]
    return _rw_finish(_rings_bm(r3, cap), name)


def _area(p):
    n = len(p)
    return 0.5 * sum(p[i][0] * p[(i + 1) % n][1] - p[(i + 1) % n][0] * p[i][1] for i in range(n))


def inset(pts, d):
    """Mitred inward offset of a simple polygon (negative d = outset)."""
    s = 1 if _area(pts) > 0 else -1
    n = len(pts)
    out = []
    for i in range(n):
        p0, p1, p2 = Vector(pts[i - 1]), Vector(pts[i]), Vector(pts[(i + 1) % n])
        e1, e2 = (p1 - p0).normalized(), (p2 - p1).normalized()
        n1, n2 = Vector((-e1.y, e1.x)) * s, Vector((-e2.y, e2.x)) * s
        b = n1 + n2
        b = n1 if b.length < 1e-6 else b.normalized()
        out.append(p1 + b * (d / max(b.dot(n1), 0.25)))
    return [(v.x, v.y) for v in out]


def prism_xz(name, pts, y0, y1, c0=0.0, c1=None):
    """Extrude an (x, z) outline along Y from y0 to y1, with flat chamfers c0 / c1 on the two cap edges."""
    c1 = c0 if c1 is None else c1
    rings = []
    rings.append((y0, inset(pts, c0) if c0 > 0 else pts))
    if c0 > 0:
        rings.append((y0 + c0, pts))
    if c1 > 0:
        rings.append((y1 - c1, pts))
    rings.append((y1, inset(pts, c1) if c1 > 0 else pts))
    return loft_f(name, rings, U=(0, 1, 0), A=(1, 0, 0), B=(0, 0, 1))


def slot_cutter(name, pts, y0, y1, c):
    """Through-slot cutter (along Y) with a flat c chamfer where it meets the faces at y0 and y1."""
    e = 0.012
    rings = [(y0 - e, inset(pts, -(c + e))), (y0 + c, pts), (y1 - c, pts), (y1 + e, inset(pts, -(c + e)))]
    return loft_f(name, rings, U=(0, 1, 0), A=(1, 0, 0), B=(0, 0, 1))


def sect8(h, w, c):
    """Chamfered rectangle: h along the section normal (a), w along Y (b), half sizes."""
    return [(h, -(w - c)), (h, w - c), (h - c, w), (-(h - c), w), (-h, w - c), (-h, -(w - c)), (-(h - c), -w), (h - c, -w)]


def sweep_xz(name, path, hw, hh, c, ext_end=0.012, ext_start=0.0):
    """Flat-plate sweep along an (x, z) polyline: each station is a mitred chamfered rectangle
    (half width hw[i] along Y, half thickness hh[i] across the path). Ends are carved back."""
    P = [Vector(p) for p in path]
    n = len(P)
    rings = []

    def ring(p, t, k, h, w, cc):
        nr = Vector((-t.y, t.x))
        return [Vector((p.x + a * nr.x * k, b, p.y + a * nr.y * k)) for a, b in sect8(h, w, cc)]

    t0 = (P[1] - P[0]).normalized()
    if ext_start > 0:
        rings.append(ring(P[0] - t0 * ext_start, t0, 1, hh[0] - ext_start * 0.6, hw[0] - ext_start, c * 0.5))
    for i in range(n):
        if i == 0:
            t, k = t0, 1.0
        elif i == n - 1:
            t, k = (P[-1] - P[-2]).normalized(), 1.0
        else:
            t1, t2 = (P[i] - P[i - 1]).normalized(), (P[i + 1] - P[i]).normalized()
            t = (t1 + t2).normalized()
            k = 1.0 / max(t.dot(t1), 0.3)
        rings.append(ring(P[i], t, k, hh[i], hw[i], c))
    te = (P[-1] - P[-2]).normalized()
    if ext_end > 0:
        rings.append(ring(P[-1] + te * ext_end, te, 1, max(hh[-1] - ext_end * 0.55, 0.004), max(hw[-1] - ext_end, 0.006), c * 0.5))
    return _rw_finish(_rings_bm(rings), name)


def merge_meshes(name, meshes):
    bm = bmesh.new()
    for me in meshes:
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)
    return _rw_finish(bm, name, planar=False)


def hex_y(r):
    return rw_ngon(r, 6, rot_deg=0)


def fix_mats(o, role):
    """One material per part: rw_bool leaves an empty slot; zero every index onto the role material."""
    me = o.data
    me.materials.clear()
    me.materials.append(rw_mat(role))
    for p in me.polygons:
        p.material_index = 0
        p.use_smooth = False
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-6, edges=bm.edges)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    me.update()


def cutter(col, name, mesh):
    return rw_obj(col, name, mesh)


# --- the bow --------------------------------------------------------------------------------------
RISER = [
    (-0.012, 0.31), (0.072, 0.31),
    (0.108, 0.215), (0.12, 0.072), (0.088, 0.035), (0.08, -0.10), (0.108, -0.205), (0.072, -0.31),
    (-0.012, -0.31), (-0.048, -0.205), (-0.088, -0.13), (-0.105, -0.06), (-0.100, 0.03), (-0.085, 0.06),
    (-0.065, 0.26),
]
LIMB_PATH = [(0.035, 0.355), (0.024, 0.462), (-0.118, 0.592), (-0.302, 0.688), (-0.296, 0.742)]
LIMB_HW = [0.0475, 0.045, 0.038, 0.029, 0.025]
LIMB_HH = [0.024, 0.022, 0.019, 0.015, 0.0125]


def build_riser(col):
    R = rw_obj(col, "Recon_Riser", prism_xz("Recon_Riser", RISER, -0.062, 0.062, 0.012), "Body")
    # window cheek: the riser thickens on the left (+Y) where the bolt passes on its right
    chm = prism_xz("Recon_tmpCheek", RISER, 0.03, 0.098, 0.011)
    rw_plane_cut(chm, (0.03, 0, 0.285), (0.35, 0, 1))
    rw_plane_cut(chm, (0.03, 0, 0.025), (0.35, 0, -1))
    rw_plane_cut(chm, (0.0, 0.098, 0.262), (0, 0.6, 1))     # carved top outer edge
    rw_plane_cut(chm, (0.0, 0.098, 0.047), (0, 0.6, -1))    # carved bottom outer edge
    rw_bool(R, cutter(col, "Recon_tmpCheek", chm), "UNION")
    # sight window: everything right of y = 0.042 between the shelf and the window head
    win = [(-0.3, 0.072), (0.3, 0.072), (0.3, 0.236), (0.0, 0.252), (-0.3, 0.252)]
    rw_bool(R, cutter(col, "Recon_tmpWin", prism_xz("Recon_tmpWin", win, -0.2, 0.042, 0.0, 0.008)))
    # lightening slots through the lower riser, chamfered entries
    for i, s in enumerate((
        [(-0.034, -0.152), (0.062, -0.152), (0.078, -0.198), (-0.018, -0.198)],
        [(-0.010, -0.222), (0.078, -0.222), (0.060, -0.272), (0.006, -0.272)],
    )):
        rw_bool(R, cutter(col, f"Recon_tmpSlot{i}", slot_cutter(f"Recon_tmpSlot{i}", s, -0.062, 0.062, 0.006)))
    # slot through the window cheek (machined, shows the bolt behind it)
    s = [(-0.036, 0.112), (0.07, 0.112), (0.06, 0.165), (-0.026, 0.165)]
    rw_bool(R, cutter(col, "Recon_tmpSlotC", slot_cutter("Recon_tmpSlotC", s, 0.042, 0.098, 0.006)))
    fix_mats(R, "Body")
    return R


def grip_ring(xb, xf, w, cb, cf):
    return [(xf, -(w - cf)), (xf, w - cf), (xf - cf, w), (xb + cb, w), (xb, w - cb), (xb, -(w - cb)), (xb + cb, -w), (xf - cf, -w)]


def build_grip(col):
    rings = [
        (-0.128, grip_ring(-0.096, 0.058, 0.060, 0.02, 0.008)),
        (-0.115, grip_ring(-0.108, 0.07, 0.072, 0.026, 0.01)),
        (-0.055, grip_ring(-0.122, 0.07, 0.074, 0.03, 0.01)),
        (0.015, grip_ring(-0.114, 0.07, 0.074, 0.03, 0.01)),
        (0.045, grip_ring(-0.104, 0.07, 0.072, 0.026, 0.01)),
        (0.056, grip_ring(-0.094, 0.06, 0.062, 0.02, 0.008)),
    ]
    G = rw_obj(col, "Recon_Grip", loft_f("Recon_Grip", rings, U=(0, 0, 1), A=(1, 0, 0), B=(0, 1, 0)), "Grip")
    # palm grooves: V cuts across the back of the wrap
    for i, zg in enumerate((-0.085, -0.05, -0.015, 0.02)):
        v = [(-0.16, zg - 0.007), (-0.1135, zg), (-0.16, zg + 0.007)]
        rw_bool(G, cutter(col, "Recon_tmpG%d" % i, prism_xz("Recon_tmpG%d" % i, v, -0.056, 0.056, 0.0, 0.0)))
    fix_mats(G, "Grip")
    return G


def build_screws(col):
    """Fixings: two screws hold each limb pocket to the riser, heads on the rear face (player side)."""
    ms = []
    for sgn in (1, -1):
        for y in (0.0645, -0.0645):
            ms.append(loft_f("Recon_tmpScr", [(0.0, rw_ngon(0.0078, 6, 90)), (-0.0095, rw_ngon(0.0078, 6, 90)), (-0.0125, rw_ngon(0.0055, 6, 90))],
                             O=(-0.0175, y, 0.3225 * sgn)))
    rw_obj(col, "Recon_Screws", merge_meshes("Recon_Screws", ms), "Metal")


def build_pocket(col, sgn):
    nm = "Recon_PocketTop" if sgn > 0 else "Recon_PocketBottom"
    pts = [(-0.022, 0.30), (0.094, 0.30), (0.10, 0.345), (0.072, 0.392), (0.005, 0.392), (-0.026, 0.345)]
    pts = [(x, z * sgn) for x, z in pts]
    P = rw_obj(col, nm, prism_xz(nm, pts, -0.081, 0.081, 0.008), "Dark")
    sl = [(-0.1, 0.315), (0.2, 0.315), (0.2, 0.5), (-0.1, 0.5)]
    sl = [(x, z * sgn) for x, z in sl]
    rw_bool(P, cutter(col, nm + "tmp", prism_xz(nm + "tmp", sl, -0.0535, 0.0535, 0.0, 0.0)))
    fix_mats(P, "Dark")
    return P


def build_bolt(col, sgn):
    nm = "Recon_BoltTop" if sgn > 0 else "Recon_BoltBottom"
    rings = [(-0.092, hex_y(0.015)), (-0.088, hex_y(0.019)), (-0.0805, hex_y(0.019)), (-0.0805, hex_y(0.011)),
             (0.0805, hex_y(0.011)), (0.0805, hex_y(0.019)), (0.088, hex_y(0.019)), (0.092, hex_y(0.015))]
    me = loft_f(nm, rings, U=(0, 1, 0), A=(1, 0, 0), B=(0, 0, 1))
    return rw_obj(col, nm, me, "Accent", loc=(RC_PIV[0], 0, RC_PIV[1] * sgn))


def build_limb(col, sgn):
    nm = "Recon_LimbTop" if sgn > 0 else "Recon_LimbBottom"
    px, pz = RC_PIV[0], RC_PIV[1] * sgn
    path = [(x - px, z * sgn - pz) for x, z in LIMB_PATH]
    me = sweep_xz(nm, path, LIMB_HW, LIMB_HH, 0.005, ext_end=0.012)
    L = rw_obj(col, nm, me, "Panel", loc=(px, 0, pz))
    # knuckle round the pivot: an octagonal boss, chamfered at both faces
    kn = loft_f(nm + "K", [(-0.0475, rw_ngon(0.026 / math.cos(math.pi / 8), 8)), (-0.0405, rw_ngon(0.032 / math.cos(math.pi / 8), 8)),
                           (0.0405, rw_ngon(0.032 / math.cos(math.pi / 8), 8)), (0.0475, rw_ngon(0.026 / math.cos(math.pi / 8), 8))],
                U=(0, 1, 0), A=(1, 0, 0), B=(0, 0, 1))
    k = rw_obj(col, nm + "K", kn, loc=(px, 0, pz))
    rw_bool(L, k, "UNION")
    # lightening slot through the lower limb (a long hexagon)
    a, b = Vector(path[1]), Vector(path[2])
    t = (b - a).normalized()
    nr = Vector((-t.y, t.x))
    m = (a + b) / 2
    w = 0.013
    # slot outline in (along t, across y): pointed hexagon, cut through the plate thickness (along nr)
    outline = [(-0.052, 0.0), (-0.036, -w), (0.036, -w), (0.052, 0.0), (0.036, w), (-0.036, w)]
    cut = loft_f(nm + "S", [(-0.05, outline), (0.05, outline)], O=(m.x + px, 0, m.y + pz),
                 U=(nr.x, 0, nr.y), A=(t.x, 0, t.y), B=(0, 1, 0))
    rw_bool(L, rw_obj(col, nm + "S", cut))
    fix_mats(L, "Panel")
    # nock cap on the tip: clamps the limb end and carries the string lug
    P = [Vector(p) for p in path]
    te = (P[-1] - P[-2]).normalized()
    nr = Vector((-te.y, te.x))
    pts = []
    for s_, extra in ((0.45, 0.006), (1.0, 0.006)):
        q = P[-2] + (P[-1] - P[-2]) * s_
        for a_ in (-1, 1):
            for b_ in (-1, 1):
                pts.append((q.x + nr.x * a_ * (LIMB_HH[-1] + extra), b_ * (LIMB_HW[-1] + extra - 0.004), q.y + nr.y * a_ * (LIMB_HH[-1] + extra)))
    qe = P[-1] + te * 0.024
    for b_ in (-1, 1):
        pts.append((qe.x - 0.006, b_ * 0.010, qe.y))
    tx, tz = RC_TIP[0] - px, RC_TIP[1] * sgn - pz
    for b_ in (-1, 1):
        for dz in (-0.012, 0.016):
            pts.append((tx - 0.009, b_ * 0.014, tz + dz * sgn))
    cm = rw_hull(nm.replace("Limb", "TipCap"), pts)
    rw_obj(col, nm.replace("Limb", "TipCap"), cm, "Metal", parent=L)
    rw_empty(col, "Recon_Tip" + ("Top" if sgn > 0 else "Bottom"), loc=(tx, 0, tz), parent=L, size=0.03)
    return L


def build_string(col, sgn):
    nm = "Recon_StringTop" if sgn > 0 else "Recon_StringBottom"
    tip = Vector((RC_TIP[0], 0, RC_TIP[1] * sgn))
    L = (RC_NOCK - tip).length
    me = loft_f(nm, [(0.0, hex_y(RC_STRING_R)), (L, hex_y(RC_STRING_R))])
    o = rw_obj(col, nm, me, "Dark", loc=tip, rot=(0, 90 if sgn > 0 else -90, 0))
    o["rest_length"] = L
    return o


def build_rest(col):
    """Shelf block with a side lip: the bolt rides on the flat, the lip stops it rolling right."""
    def box(y0, y1, top_pts):
        pts = []
        for x in (-0.106, -0.074):
            pts += [(x, y0, 0.068), (x, y1, 0.068)] + [(x, y, z) for y, z in top_pts]
        for x in (-0.111, -0.069):
            pts += [(x, y0 + 0.004, 0.080), (x, y1 - 0.004, 0.080)]
        return pts
    R = rw_obj(col, "Recon_Rest", rw_hull("Recon_Rest", box(-0.018, 0.046, [(-0.018, 0.088), (-0.014, 0.091), (0.046, 0.091)])), "Metal")
    lip = rw_hull("Recon_tmpLip", box(-0.027, -0.0155, [(-0.027, 0.094), (-0.023, 0.099), (-0.0155, 0.097)]))
    rw_bool(R, cutter(col, "Recon_tmpLip", lip), "UNION")
    fix_mats(R, "Metal")
    return R


def readout_frame():
    a, b = Vector((-0.085, 0.0, 0.06)), Vector((-0.065, 0.0, 0.26))
    U = (b - a).normalized()
    N = Vector((-U.z, 0, U.x))  # outward (-X)
    return a, U, N


def build_readout(col):
    O, U, N = readout_frame()
    Y = Vector((0, 1, 0))

    def plate(name, u0, u1, y0, y1, n0, n1, c, cn=None):
        cn = c if cn is None else cn
        uc, yc = (u0 + u1) / 2, (y0 + y1) / 2
        base = [(uc + du, yc + dy) for du, dy in rw_cham_rect(u1 - u0, y1 - y0, c)]
        top = [(uc + du, yc + dy) for du, dy in rw_cham_rect(u1 - u0 - 2 * cn, y1 - y0 - 2 * cn, max(c - cn, 0.001))]
        return loft_f(name, [(n0, base), (n1 - cn, base), (n1, top)], O=O, U=N, A=U, B=Y)

    rw_obj(col, "Recon_Readout", plate("Recon_Readout", 0.02, 0.196, 0.047, 0.085, -0.004, 0.006, 0.006, 0.003), "Dark")
    segs = [plate("Recon_Charge_Energy%d" % i, u, u + 0.027, 0.054, 0.078, 0.002, 0.0115, 0.004, 0.002)
            for i, u in enumerate((0.03, 0.063, 0.096, 0.129))]
    rw_obj(col, "Recon_Charge_Energy", merge_meshes("Recon_Charge_Energy", segs), "Energy")
    for i, y in ((1, 0.0745), (2, 0.0575)):  # Bounce1 on the player's left (+Y), Bounce2 right
        nm = "Recon_Bounce%d_Energy" % i
        rw_obj(col, nm, plate(nm, 0.166, 0.182, y - 0.0075, y + 0.0075, 0.002, 0.0115, 0.004, 0.002), "Energy")


def build_sensor(col):
    out = [(0.012, 0.192), (0.03, 0.18), (0.094, 0.18), (0.094, 0.232), (0.076, 0.25), (0.012, 0.25)]
    hs = loft_f("Recon_Sensor", [(0.092, out), (0.104, out), (0.109, inset(out, 0.005))], U=(0, 1, 0), A=(1, 0, 0), B=(0, 0, 1))
    rw_obj(col, "Recon_Sensor", hs, "Dark")
    lens = inset(out, 0.012)
    ln = loft_f("Recon_SensorLens", [(0.106, lens), (0.111, lens), (0.1135, inset(lens, 0.0025))], U=(0, 1, 0), A=(1, 0, 0), B=(0, 0, 1))
    rw_obj(col, "Recon_SensorLens", ln, "Scan")


def recon_bow(S, col):
    build_riser(col)
    build_grip(col)
    for sgn in (1, -1):
        build_pocket(col, sgn)
        build_bolt(col, sgn)
        build_limb(col, sgn)
        build_string(col, sgn)
    build_rest(col)
    build_readout(col)
    build_sensor(col)
    build_screws(col)
    rw_empty(col, "Recon_Handle", (0, 0, 0), size=0.06)
    rw_empty(col, "Recon_LeftGrip", tuple(RC_NOCK), size=0.04)
    rw_empty(col, "Recon_Nock", tuple(RC_NOCK), size=0.04)
    rw_empty(col, "Recon_NockDrawn", tuple(RC_NOCK - Vector((RC_DRAW, 0, 0))), size=0.04)
    rw_empty(col, "Recon_Muzzle", (RC_DART_X, 0, RC_NOCK.z), size=0.04)
    # pivots: local Y is the flex axis; a POSITIVE turn about local Y flexes the limb toward the string
    rw_empty(col, "Recon_LimbTopPivot", (RC_PIV[0], 0, RC_PIV[1]), rot=(0, 0, 180), size=0.04)
    rw_empty(col, "Recon_LimbBottomPivot", (RC_PIV[0], 0, -RC_PIV[1]), size=0.04)


# --- the bolt -------------------------------------------------------------------------------------
def _oct(apo):
    return rw_ngon(apo / math.cos(math.pi / 8), 8)


def dart_meshes(pre):
    """Bolt parts in bolt space: tip at the origin, body along -X. Returns [(suffix, mesh, role)]."""
    X = dict(U=(1, 0, 0), A=(0, 1, 0), B=(0, 0, 1))
    out = []

    def star(rb, rs):  # 3 blades: up, lower-left, lower-right
        pts = []
        for k in range(6):
            ang = math.radians(90 + 60 * k)
            r = rb if k % 2 == 0 else rs
            pts.append((r * math.cos(ang), r * math.sin(ang)))
        return pts

    def hex6(r):
        return [(r * math.cos(math.radians(90 + 60 * k)), r * math.sin(math.radians(90 + 60 * k))) for k in range(6)]

    out.append(("Head", loft_f(pre + "Head", [(0.0, [(0.0, 0.0)]), (-0.052, star(0.034, 0.012)), (-0.068, star(0.026, 0.0125)),
                                               (-0.082, hex6(0.013)), (-0.098, hex6(0.013))], **X), "Accent"))
    out.append(("Collar", loft_f(pre + "Collar", [(-0.086, _oct(0.019)), (-0.094, _oct(0.027)), (-0.148, _oct(0.027)), (-0.157, _oct(0.02))], **X), "Body"))
    out.append(("Light_Energy", loft_f(pre + "Light_Energy", [(-0.106, _oct(0.0285)), (-0.109, _oct(0.0325)), (-0.121, _oct(0.0325)), (-0.124, _oct(0.0285))], **X), "Energy"))
    out.append(("Band", loft_f(pre + "Band", [(-0.129, _oct(0.0285)), (-0.131, _oct(0.0325)), (-0.143, _oct(0.0325)), (-0.145, _oct(0.0285))], **X), "Metal"))
    out.append(("Shaft", loft_f(pre + "Shaft", [(-0.14, rw_ngon(0.0185, 6, rot_deg=0)), (-0.97, rw_ngon(0.0185, 6, rot_deg=0))], **X), "Dark"))
    # four angular vanes in an X (none in the string plane)
    prof = [(-0.80, 0.010), (-0.86, 0.086), (-0.935, 0.091), (-0.958, 0.072), (-0.962, 0.010)]
    vanes = []
    for k in range(4):
        ph = math.radians(45 + 90 * k)
        D = (0, math.cos(ph), math.sin(ph))
        T = (0, -math.sin(ph), math.cos(ph))
        c = 0.004
        vanes.append(loft_f(pre + "F%d" % k, [(-0.0075, inset(prof, c)), (-0.0075 + c, prof), (0.0075 - c, prof), (0.0075, inset(prof, c))],
                            U=T, A=(1, 0, 0), B=D))
    out.append(("Fletch", merge_meshes(pre + "Fletch", vanes), "Scan"))
    out.append(("Nock", loft_f(pre + "Nock", [(-0.962, _oct(0.0165)), (-0.968, _oct(0.0205)), (-0.993, _oct(0.0205)), (-1.0, _oct(0.0155))], **X), "Metal"))
    return out


def build_dart(col, pre, origin):
    objs = {}
    for suf, me, role in dart_meshes(pre):
        objs[suf] = rw_obj(col, pre + suf, me, role, loc=origin)
    # string slot through the nock: prongs either side (Y), open top and bottom
    sl = [(-1.03, -0.05), (-0.975, -0.05), (-0.975, 0.05), (-1.03, 0.05)]
    cm = prism_xz(pre + "tmpSlot", sl, -0.0085, 0.0085, 0.0, 0.0)
    c = rw_obj(col, pre + "tmpSlot", cm, loc=origin)
    rw_bool(objs["Nock"], c)
    fix_mats(objs["Nock"], "Metal")
    return objs


# --- scene control ----------------------------------------------------------------------------------
def rc_show(prefix):
    """Render only the parts with this prefix (Recon_ or ReconDart_)."""
    for o in bpy.data.objects:
        if o.name.startswith("Recon_") or o.name.startswith("ReconDart_"):
            o.hide_render = not o.name.startswith(prefix)


def recon_build(S):
    rw_clear("Recon_")
    rw_clear("ReconDart_")
    bow = rw_col(S, "Recon")
    dc = rw_col(S, "ReconDart")
    recon_bow(S, bow)
    build_dart(dc, "ReconDart_", (0, 0, 0))
    rw_empty(dc, "ReconDart_Handle", (0, 0, 0), size=0.04)
    rw_empty(dc, "ReconDart_Light", (-0.115, 0, 0), size=0.03)
    rw_empty(dc, "ReconDart_Tail", (-1.0, 0, 0), size=0.03)
    # the nocked bolt on the bow: same meshes, other prefix, nock slot on the string
    for o in [o for o in dc.objects if o.type == "MESH"]:
        me = o.data.copy()
        nm = "Recon_Dart_" + o.name[len("ReconDart_"):]
        me.name = nm
        rw_obj(bow, nm, me, loc=(RC_DART_X, 0, RC_NOCK.z))
    for o in bpy.data.objects:
        if o.name.startswith("Recon_tmp") or "tmp" in o.name and o.name.startswith("Recon"):
            bpy.data.objects.remove(o, do_unlink=True)
    return {"bow": len(bow.objects), "dart": len(dc.objects)}


# --- full draw check ------------------------------------------------------------------------------
def recon_pose(flex_deg=0.0, draw=0.0):
    """Pose the bow: limbs flexed flex_deg toward the string, nock and bolt pulled back by draw."""
    lt, lb = bpy.data.objects["Recon_LimbTop"], bpy.data.objects["Recon_LimbBottom"]
    lt.rotation_euler = (0, math.radians(-flex_deg), 0)
    lb.rotation_euler = (0, math.radians(flex_deg), 0)
    for o in bpy.data.objects:
        if o.name.startswith("Recon_Dart_"):
            o.location = (RC_DART_X - draw, 0, RC_NOCK.z)
    bpy.context.view_layer.update()
    nock = RC_NOCK - Vector((draw, 0, 0))
    for nm, tip in (("Recon_StringTop", "Recon_TipTop"), ("Recon_StringBottom", "Recon_TipBottom")):
        s = bpy.data.objects[nm]
        p = bpy.data.objects[tip].matrix_world.translation.copy()
        d = nock - p
        s.location = p
        s.rotation_euler = d.to_track_quat("X", "Y").to_euler()
        s.scale = (d.length / s["rest_length"], 1, 1)
    bpy.context.view_layer.update()
