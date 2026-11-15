"""Shared full-shell base for structural Vandal skins (stock
Vandal_RemasterV2_v05 open). Exec after a line kit (MATS, SLOT_SKIN, ACCENT
...) and the helper half of model_moltframe_vandal_v04_parts.py (+ the
retain/zcut slice of model_moltframe_spectre_parts.py).

What every line's Vandal keeps (fit and moving parts, verified on Moltframe
v05): the receiver core with the magazine well and trigger slot, the open
charging / ejection channel (x .150-.845, z .270-.356, both sides), the stock
barrel, sights, bolt, charging handle, trigger, selector and charm loop, the
trigger guard, the magazine catch and the magazine's feed lips and top round.
Everything else of the stock body (receiver shells, handguard, rail, stock,
grip, magazine body, pins, indicator strips) is hidden and rebuilt by the line.

Envelope (keep new shells inside it):
  upper shell     bottom >= .356 over x .15-.86; |y| <= .095; top <= .50
  lower side      top <= .266 over x .165-.845; |y| <= .090
  selector        x .017-.101, y >= .090, z .184-.306 stays clear (+Y)
  handguard       x 1.046-1.685, bottom near z .13-.18 (left hand at 1.32, .17)
  sight line      AimPoint (.078, .56) to the front post tip (2.02, .594)
"""

SLOT = (.150, .845, .270, .356)
VANDAL_HIDE = ["Vandal_Receiver", "Vandal_Handguard", "Vandal_Rail", "Vandal_Stock", "Vandal_Grip",
               "Vandal_Mag", "Vandal_Pins", "Vandal_Neon", "Vandal_Barrel"]

def vandal_core(mat_core, name="VSB_Core"):
    """Dark receiver core: magazine well, trigger slot, recessed channel."""
    def rec(x):
        b = .15 if x > -.10 else .178
        return [(.050, b), (.066, b + .016), (.066, SLOT[2]), (.044, SLOT[2] + .006),
                (.044, SLOT[3] - .004), (.066, SLOT[3] + .004), (.066, .40), (.05, .405)]
    st = [(x, ring(rec(x))) for x in (-.176, -.10, -.09, .40, .86, 1.10)]
    a = link(name, loft(st, ring_mats([mat_core] * 7, bottom=mat_core, top=mat_core), cap_mat=mat_core))
    well = zcut([(.438, -.064), (.835, -.064), (.835, .064), (.438, .064)], .06, .262, mat=mat_core)
    trig = zcut([(.176, -.0138), (.262, -.0138), (.262, .0138), (.176, .0138)], .10, .215, mat=mat_core)
    cut(a, [well, trig], rim=0)
    return a

def vandal_retained(prefix):
    """Trigger guard, magazine catch and the magazine's feed lips + top round
    (Mag bone), in the line's stock-slot finishes."""
    tg = retain("Vandal_Grip", lambda P: min(p.x for p in P) > .10 and max(p.z for p in P) < .16, prefix + "_TriggerGuard")
    mc = retain("Vandal_Receiver", lambda P: .40 < min(p.x for p in P) < .43 and max(p.z for p in P) < .17, prefix + "_MagCatch")
    mt = retain("Vandal_Mag", lambda P: min(p.z for p in P) > .08 and max(p.x for p in P) < .70, prefix + "_MagTop", bone="Mag")
    return tg, mc, mt

def vandal_barrel(prefix, mat, drop_muzzle=True):
    """Stock barrel + gas tube in the line finish; stock muzzle device removed
    when the line brings its own."""
    src = bpy.data.objects["Vandal_Barrel"]
    M = src.matrix_world
    bm = bmesh.new(); bm.from_mesh(src.data)
    bm.verts.ensure_lookup_table()
    if drop_muzzle:
        seen, drop = set(), []
        for v in bm.verts:
            if v.index in seen:
                continue
            g, st = {v}, [v]
            while st:
                cur = st.pop()
                for e in cur.link_edges:
                    w = e.other_vert(cur)
                    if w not in g:
                        g.add(w); st.append(w)
            seen |= {u.index for u in g}
            if min((M @ u.co).x for u in g) > 2.38:
                drop += list(g)
        bmesh.ops.delete(bm, geom=drop, context="VERTS")
    for v in bm.verts:
        v.co = M @ v.co
    for f in bm.faces:
        f.material_index = mat
    return link(prefix + "_Barrel", bm)

def surface_pt(obj, x, z, side=1.0):
    """Outer surface y of obj at (x, z) on the +Y (side=1) or -Y face."""
    from mathutils.bvhtree import BVHTree
    t = BVHTree.FromPolygons([obj.matrix_world @ v.co for v in obj.data.vertices], [p.vertices[:] for p in obj.data.polygons])
    hit = t.ray_cast(Vector((x, side * 1.0, z)), Vector((0, -side, 0)))
    return hit[0].y if hit[0] is not None else None

def inlay_line(name, target, pts, w=.008, h=.004, mat=None, bone="Root", step=.012):
    """Raised trim line (filigree / ink line / panel bead) seated on the
    target's +Y surface along a side-view polyline, then mirrored."""
    mat = ACCENT if mat is None else mat
    dense = []
    for (x0, z0), (x1, z1) in zip(pts, pts[1:]):
        n = max(1, int(math.hypot(x1 - x0, z1 - z0) / step))
        dense += [(x0 + (x1 - x0) * i / n, z0 + (z1 - z0) * i / n) for i in range(n)]
    dense.append(pts[-1])
    path, ok = [], []
    for x, z in dense:
        y = surface_pt(target, x, z)
        if y is not None:
            path.append((x, y + h * .35, z))
    if len(path) < 2:
        return None
    sec = [(1, -.6), (.6, 1), (-.6, 1), (-1, -.6)]
    bm = sweep(path, (0, 1, 0), [w] * len(path), [h] * len(path), section=sec, mats=[mat] * 4)
    o = join(name, [bm], bone)
    mirror_apply(o)
    return o

def vandal_hide_stock():
    for n in VANDAL_HIDE:
        o = bpy.data.objects[n]; o.hide_render = True; o.hide_set(True)

VANDAL_KEEP = ["Vandal_RearSight", "Vandal_FrontSight", "Vandal_ChargingHandle", "Vandal_Bolt", "Vandal_Trigger",
               "Vandal_FireSelector", "Vandal_CharmLoop"]

def vandal_set_skin_factory(table_for):
    """set_skin(on) for full-shell Vandals: stock body hidden, kept stock
    parts in the line finishes (table_for(name) -> 8-slot material list)."""
    def set_skin(on):
        for n in VANDAL_KEEP:
            o = bpy.data.objects[n]
            for i, sl in enumerate(o.material_slots):
                if i < 8:
                    sl.material = table_for(n)[i] if on else bpy.data.materials[STOCK_SET[i]]
        for n in VANDAL_HIDE:
            o = bpy.data.objects[n]; o.hide_render = on; o.hide_set(on)
        col.hide_render = not on
        col.hide_viewport = not on
    return set_skin

def convex_hull_xz(pts):
    """Indices of the convex hull of 2D points, counter-clockwise (Andrew's
    monotone chain). Replaces mathutils.geometry.convex_hull_2d, which in
    Blender 5.2 returned the first corner twice and dropped a real one on the
    stock grips (68 points with near-duplicates): the side outline then cut a
    diagonal through the part and left half its face missing (owner
    2026-11-14: the Inkshift and Payload Odin, Bulldog and Ares grips)."""
    order = sorted(range(len(pts)), key=lambda i: (pts[i][0], pts[i][1]))
    def cross(o, a, b):
        return (pts[a][0] - pts[o][0]) * (pts[b][1] - pts[o][1]) - (pts[a][1] - pts[o][1]) * (pts[b][0] - pts[o][0])
    lower, upper = [], []
    for i in order:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], i) <= 1e-12:
            lower.pop()
        lower.append(i)
    for i in reversed(order):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], i) <= 1e-12:
            upper.pop()
        upper.append(i)
    return lower[:-1] + upper[:-1]

def hull_xz(obj_name, keep=lambda P: True, margin=0.0):
    """Convex side-view outline (x, z) of the accepted components of a stock
    mesh, pushed out by `margin` (keeps the stock footprint for the hands)."""
    src = bpy.data.objects[obj_name]; me = src.data
    adj = defaultdict(set)
    for p in me.polygons:
        for i in p.vertices:
            adj[i].update(p.vertices)
    pts, seen = [], set()
    for i in adj:
        if i in seen:
            continue
        g, st = {i}, [i]
        while st:
            f = adj[st.pop()] - g; g |= f; st += list(f)
        seen |= g
        P = [src.matrix_world @ me.vertices[j].co for j in g]
        if keep(P):
            pts += [(p.x, p.z) for p in P]
    idx = convex_hull_xz(pts)
    hull = [pts[i] for i in idx]
    if margin:
        cx = sum(p[0] for p in hull) / len(hull); cz = sum(p[1] for p in hull) / len(hull)
        out = []
        for x, z in hull:
            d = Vector((x - cx, z - cz)); L = d.length or 1
            out.append((x + d.x / L * margin, z + d.y / L * margin))
        hull = out
    # drop near-duplicate points
    clean = [hull[0]]
    for p in hull[1:]:
        if (Vector(p) - Vector(clean[-1])).length > .004:
            clean.append(p)
    return clean


def vandal_grip_outline(margin=.003, top=.186, cut=.12):
    """Stock grip side outline, cut flat at z = cut and extended straight up
    to z = top, into the receiver core (core underside z .150 ahead of
    x -.10, .178 behind it), so the new grip seats with no gap. Kept convex:
    an earlier version raised individual hull points and folded the outline
    over itself, which left holes in the grip's side face."""
    hull = hull_xz("Vandal_Grip", lambda P_: min(p.x for p in P_) < 0, margin=margin)
    low = clip_poly(hull, 0.0, -1.0, cut)                    # keep z <= cut
    tops = [(x, top) for x, z in low if abs(z - cut) < 1e-6]
    pts = low + tops
    idx = convex_hull_xz(pts)
    out = [pts[i] for i in idx]
    clean = [out[0]]
    for q in out[1:]:
        if (Vector(q) - Vector(clean[-1])).length > .004:
            clean.append(q)
    return clean

def clip_poly(poly, a, b, c):
    """Sutherland-Hodgman: keep the part of a side-view polygon where
    a*x + b*z + c >= 0."""
    out = []
    n = len(poly)
    for i in range(n):
        p, q = poly[i], poly[(i + 1) % n]
        fp, fq = a * p[0] + b * p[1] + c, a * q[0] + b * q[1] + c
        if fp >= 0:
            out.append(p)
        if (fp >= 0) != (fq >= 0):
            t = fp / (fp - fq)
            out.append((p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t))
    return out

def band_plates(hull, bands, slope, y0, y1, mat, ch=.004, rim=None, crease=.004):
    """Raised plates = the side outline cut into slanted bands
    (z_hi, z_lo at x = 0, lines z = z0 + slope * x). Each band is creased
    along its length so its face breaks into two planes."""
    bms = []
    for zh, zl in bands:
        poly = clip_poly(hull, -slope, 1.0, -zl)             # z - slope*x - zl >= 0
        poly = clip_poly(poly, slope, -1.0, zh)              # zh + slope*x - z >= 0
        if len(poly) < 3:
            continue
        xs = [p[0] for p in poly]
        x0, x1 = min(xs), max(xs)
        zm = (zh + zl) / 2
        bm = solid_plate(poly, y0, y1, ch=ch, mat=mat, fold=((x0, zm + slope * x0), (x1, zm + slope * x1), crease, (zh - zl) * .6))
        if rim is not None:
            for f in bm.faces:
                if f.material_index == EDGE:
                    f.material_index = rim
        bms.append(bm)
    return bms


def scale_plates(hull, bands, slope, y_in, y_out, mat, ch=.004, rim=None):
    """Overlapping scales: each band of the side outline becomes a wedge whose
    top edge sinks into the part (y_in) and whose lower edge stands proud
    (y_out), so every scale laps over the next one like a shingle."""
    bms = []
    for zh, zl in bands:
        poly = clip_poly(hull, -slope, 1.0, -zl)
        poly = clip_poly(poly, slope, -1.0, zh)
        if len(poly) < 3:
            continue
        bm = solid_plate(poly, y_in - .010, y_out, ch=ch, mat=mat)
        for v in bm.verts:
            if v.co.y > y_in - .005:
                t = (zh + slope * v.co.x - v.co.z) / (zh - zl)
                t = min(1.0, max(0.0, t))
                v.co.y = y_in + (y_out - y_in) * t - (y_out - v.co.y if v.co.y < y_out - 1e-6 else 0.0)
        if rim is not None:
            for f in bm.faces:
                if f.material_index == EDGE:
                    f.material_index = rim
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bms.append(bm)
    return bms

def vandal_magwell_lip(prefix, mat, y_in=.0625, y_out=.078, z0=.084, z1=.112):
    """Flared collar round the magazine well opening (static, Root): side
    bars outside the magazine's widest part, front and rear bars clear of its
    insertion path."""
    bars = []
    side = [(.432, z1), (.842, z1), (.852, z0 + .010), (.838, z0), (.444, z0), (.426, z0 + .010)]
    bars.append(solid_plate(side, y_in, y_out, ch=.004, mat=mat))
    o = join(prefix + "_MagwellLip", bars)
    mirror_apply(o)
    return o

def vandal_round_bands(prefix, bands, zc=.214, ry=.0162, rz=.0182, n=8):
    """Line ammunition trim on the magazine's visible top round (stock case
    x .49-.62, radius about .014 / .016): bands = [(x0, width, mat, slant)];
    slant tilts the band (a diagonal stripe). Mag bone, so it rides the mag."""
    bms = []
    for x0, w, mat, slant in bands:
        rings = []
        for xo in (0.0, w):
            rings.append([(x0 + xo + slant * math.sin(2 * math.pi * i / n), ry * math.cos(2 * math.pi * i / n),
                           zc + rz * math.sin(2 * math.pi * i / n)) for i in range(n)])
        bms.append(loft3(rings, [mat] * n, cap_mat=mat))
    return join(prefix + "_RoundTrim", bms, bone="Mag")

# ---------------------------------------------------------------- any gun
def comp_points(obj_name, keep=lambda P: True):
    """World points of the accepted connected components of a stock mesh."""
    src = bpy.data.objects[obj_name]; me = src.data
    adj = defaultdict(set)
    for p in me.polygons:
        for i in p.vertices:
            adj[i].update(p.vertices)
    pts, seen = [], set()
    for i in adj:
        if i in seen:
            continue
        g, st = {i}, [i]
        while st:
            f = adj[st.pop()] - g; g |= f; st += list(f)
        seen |= g
        P = [src.matrix_world @ me.vertices[j].co for j in g]
        if keep(P):
            pts += P
    return pts

def hull_solid(name, src, keep=lambda P: True, y_half=None, mat=0, margin=.003, clip=(), fold=None, bone="Root",
               ch=.006, rim=None, y_extra=.002):
    """New solid from the side outline of a stock part (accepted components),
    optionally clipped by half-planes (a, b, c: keep a*x + b*z + c >= 0),
    mirrored and closed. Returns (object, outline)."""
    hull = hull_xz(src, keep, margin)
    for a, b, c in clip:
        hull = clip_poly(hull, a, b, c)
    if y_half is None:
        P = comp_points(src, keep)
        y_half = max(abs(p.y) for p in P) + y_extra
    bm = solid_plate(hull, 0, y_half, ch=ch, mat=mat, open_inner=True, fold=fold)
    if rim is not None:
        for f in bm.faces:
            if f.material_index == EDGE:
                f.material_index = rim
    o = link(name, bm, bone)
    mirror_apply(o, merge=True)
    return o, hull

def outline_center(poly):
    return (sum(p[0] for p in poly) / len(poly), sum(p[1] for p in poly) / len(poly))

def gun_set_skin_factory(hide, tables):
    """set_skin(on) for full-shell guns: hide = stock meshes replaced by new
    parts; tables = {stock name: 8-slot material list} for kept parts."""
    def set_skin(on):
        for n, t in tables.items():
            o = bpy.data.objects.get(n)
            if not o:
                continue
            for i, sl in enumerate(o.material_slots):
                if i < 8:
                    sl.material = t[i] if on else bpy.data.materials[STOCK_SET[i]]
        for n in hide:
            o = bpy.data.objects.get(n)
            if o:
                o.hide_render = on; o.hide_set(on)
        col.hide_render = not on
        col.hide_viewport = not on
    return set_skin

AIM_FALLBACK = {"Ghost": .418, "Classic": .512}

def ensure_aim(item):
    """Guns without a stock AimPoint get the review's rear-notch-height aim
    empty (same values as round one)."""
    if item in AIM_FALLBACK and f"MFR_{item}_Aim" not in bpy.data.objects:
        e = bpy.data.objects.new(f"MFR_{item}_Aim", None)
        bpy.context.scene.collection.objects.link(e)
        e.location = (0.0, 0, AIM_FALLBACK[item])
