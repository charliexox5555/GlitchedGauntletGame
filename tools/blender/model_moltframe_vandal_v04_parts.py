"""Moltframe Vandal v04 parts. Exec after model_moltframe_vandal_v04.py
(which defines materials, collection, loft/plate/cut helpers).

Shape language taken from the owner's Hivemind reference (quality bar only):
raked ribs over a fluid fore-end, a swept receiver plate ending in a fang,
rear-swept thorns, a skeletal stock loop, a long leaf window in the magazine
and sinews across the chambers. Every curve is built from flat facets.
"""

# ------------------------------------------------------------ 3D builders
def loft3(stations, mats, caps=(True, True), cap_mat=EDGE):
    bm = bmesh.new()
    rings = [[bm.verts.new(tuple(p)) for p in r] for r in stations]
    n = len(rings[0])
    for i in range(len(rings) - 1):
        for j in range(n):
            f = bm.faces.new((rings[i][j], rings[i][(j + 1) % n],
                              rings[i + 1][(j + 1) % n], rings[i + 1][j]))
            f.material_index = mats[j % len(mats)]
    for k, on in zip((0, -1), caps):
        if on:
            f = bm.faces.new(rings[k])
            f.material_index = cap_mat
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm

# blade: lenticular rib with a crisp polished ridge (s across, t outward)
BLADE = [(-1, 0), (-.82, .72), (0, 1), (.82, .72), (1, 0), (0, -.35)]
BLADE_M = [EDGE, ARM, ARM, EDGE, ARM, ARM]
# strut: flattened octagon tube centred on the path
STRUT = [(1, 0), (.62, .8), (.0, 1), (-.62, .8), (-1, 0), (-.62, -.8), (0, -1), (.62, -.8)]
STRUT_M = [EDGE, ARM, ARM, ARM, ARM, ARM, ARM, EDGE]

def sweep(path, outward, widths, thicks, section=BLADE, mats=BLADE_M, caps=(True, True)):
    path = [Vector(p) for p in path]
    n = len(path)
    rings = []
    for i, p in enumerate(path):
        T = (path[min(i + 1, n - 1)] - path[max(i - 1, 0)]).normalized()
        O = Vector(outward[i] if isinstance(outward, list) else outward)
        O = (O - T * O.dot(T)).normalized()
        B = T.cross(O)
        rings.append([p + B * (s * widths[i] / 2) + O * (t * thicks[i]) for s, t in section])
    return loft3(rings, mats, caps)

def join(name, bms, bone="Root"):
    acc = bmesh.new()
    for b in bms:
        tmp = bpy.data.meshes.new("_j"); b.to_mesh(tmp); b.free()
        acc.from_mesh(tmp); bpy.data.meshes.remove(tmp)
    return link(name, acc, bone)

def lerp2(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)

def mirror_x_outline(win):
    return [(x, z) for x, z in win]

# ------------------------------------------------------------------ parts
SLOT = (.150, .845, .270, .356)      # charging / ejection channel x0 x1 z0 z1

def zt_spine(x):
    if x <= .16: return .409
    if x <= .26: return .409 + (x - .16) / .10 * .053
    if x <= 1.58: return .462
    return .462 - (x - 1.58) / .14 * .070

def zb_mantle(x):
    pts = [(-1, .356), (.86, .356), (.905, .30), (.95, .232), (.992, .176),
           (1.04, .232), (1.10, .300), (1.16, .345), (1.60, .336), (1.72, .345)]
    for (x0, z0), (x1, z1) in zip(pts, pts[1:]):
        if x0 <= x <= x1:
            return z0 + (z1 - z0) * (x - x0) / (x1 - x0)
    return pts[-1][1]

def upper_half(x):
    zt, zb = zt_spine(x), zb_mantle(x)
    k = 1.0
    if x > 1.60:
        k = 1 - (x - 1.60) / .12 * .40
    zr = max(zb + .026, zt - .070 if x >= .26 else zt - .056)
    wb = .086 + (.010 if zb < .34 else 0)
    return [
        (.060 * k, zb),
        (wb * k, zb),
        (wb * k + .007, zb + .010),
        (.093 * k, (zb + .010 + zr) / 2),
        (.091 * k, zr - .004),
        (.091 * k, zr + .004),
        (.080 * k, zt - .034),
        (.046 * k, zt - .014),
        (.032 * k, zt - .002),
        (.024 * k, zt),
    ]
UPPER_MATS = [CORE, EDGE, ARM, ARM, EDGE, ARM, ARM, ARM, EDGE]

def zcut(quad, z0, z1, mat=GASKET, floor=None):
    bmc = bmesh.new()
    lo = [bmc.verts.new((x, y, z0)) for x, y in quad]
    hi = [bmc.verts.new((x, y, z1)) for x, y in quad]
    f = bmc.faces.new(lo); f.material_index = mat if floor is None else floor
    f = bmc.faces.new(hi); f.material_index = mat
    n = len(quad)
    for i in range(n):
        f = bmc.faces.new((lo[i], lo[(i + 1) % n], hi[(i + 1) % n], hi[i])); f.material_index = mat
    bmesh.ops.recalc_face_normals(bmc, faces=bmc.faces)
    return bmc

def build_upper():
    xs = [-.178, -.17, .0, .16, .21, .26, .55, .845, .86, .88, .905, .93, .95, .97, .992,
          1.015, 1.04, 1.07, 1.10, 1.13, 1.16, 1.30, 1.45, 1.58, 1.62, 1.66, 1.70, 1.72]
    st = [(x, ring(upper_half(x))) for x in xs]
    x0, r0 = st[0]
    st[0] = (x0, [(y * .84, z - (.006 if z > .38 else 0)) for y, z in r0])
    o = link("MF4_UpperShell", loft(st, ring_mats(UPPER_MATS, bottom=CORE, top=ARM), cap_mat=EDGE))
    cutters = []
    for xa, xb in ((.36, .50), (.58, .72), (1.20, 1.31), (1.37, 1.48)):
        sl = .013
        cutters.append(zcut([(xa, -sl), (xb, -sl), (xb - .012, sl), (xa - .012, sl)], .446, .6, floor=VIOLET))
    # fuller groove along the upper armour face, both sides (breaks the long plain face).
    # One boolean pass with the slots: a second pass after the rim bevel drops them.
    fuller = [(.30, .405), (.345, .4135), (1.44, .4135), (1.50, .405), (1.44, .4085), (.345, .4085)]
    cutters += [prism(fuller, .0815, .3, floor=CORE), prism(fuller, -.0815, -.3, floor=CORE)]
    cut(o, cutters, rim=.002)
    return o

def build_core():
    def rec(x):
        b = .15 if x > -.10 else .178
        return [(.050, b), (.066, b + .016), (.066, SLOT[2]), (.044, SLOT[2] + .006),
                (.044, SLOT[3] - .004), (.066, SLOT[3] + .004), (.066, .40), (.05, .405)]
    st = [(x, ring(rec(x))) for x in (-.176, -.10, -.09, .40, .86, 1.10)]
    a = link("MF4_ReceiverCore", loft(st, ring_mats([CORE] * 7, bottom=CORE, top=CORE), cap_mat=CORE))
    # magazine well and trigger slot, as in the stock receiver
    well = zcut([(.438, -.064), (.835, -.064), (.835, .064), (.438, .064)], .06, .262, mat=CORE)
    trig = zcut([(.176, -.0138), (.262, -.0138), (.262, .0138), (.176, .0138)], .10, .215, mat=CORE)
    cut(a, [well, trig], rim=0)
    def fe(k=1.0):
        return [(.036 * k, .180), (.062 * k, .196), (.070 * k, .236), (.070 * k, .318),
                (.058 * k, .352), (.04 * k, .366)]
    st = [(1.06, ring(fe())), (1.62, ring(fe())), (1.66, ring(fe(.86)))]
    b = link("MF4_ForendFluid", loft(st, ring_mats([GASKET, GASKET, VIOLET, VIOLET, VIOLET], bottom=GASKET, top=VIOLET), cap_mat=CORE))
    return a, b

def build_ribs():
    zc, a, b = .274, .098, .070
    bms = []
    for i, x0 in enumerate((1.215, 1.30, 1.385, 1.47, 1.555, 1.635)):
        ph = [math.radians(d) for d in (78, 60, 38, 14, -10, -34, -58, -88)]
        path, outw, wid, th = [], [], [], []
        for p in ph:
            s = (math.sin(p) + 1) / 2
            path.append((x0 - .105 * s, b * math.cos(p) - .002, zc + a * math.sin(p)))
            outw.append((0, math.cos(p) / b, math.sin(p) / a))
            taper = 1 - .45 * max(0, (s - .80) / .20)
            wid.append(.056 * taper * (1 - .12 * i / 5))
            th.append(.013 * taper)
        bms.append(sweep(path, outw, wid, th))
    o = join("MF4_Ribs", bms)
    mirror_apply(o)
    def keel(k=1.0):
        return [(.030 * k, .164), (.050 * k, .174), (.054 * k, .190), (.034 * k, .202)]
    st = [(1.07, ring(keel(.85))), (1.10, ring(keel())), (1.60, ring(keel())), (1.665, ring(keel(.7)))]
    st[-1] = (st[-1][0], [(y, z + .012) for y, z in st[-1][1]])
    k = link("MF4_Keel", loft(st, ring_mats([ARM, ARM, ARM], bottom=ARM, top=ARM), cap_mat=EDGE))
    return o, k

def build_carapace():
    out = [(.165, .266), (.845, .266), (.90, .262), (.948, .205), (.93, .150),
           (.825, .150), (.79, .104), (.49, .104), (.45, .150), (.215, .150), (.150, .205)]
    o = link("MF4_Carapace", solid_plate(out, .066, .088, fold=((.16, .236), (.94, .246), .011, .14)))
    win = [(.262, .214), (.33, .236), (.46, .247), (.64, .250), (.79, .243), (.865, .226),
           (.885, .200), (.855, .176), (.74, .163), (.55, .163), (.40, .174), (.31, .192)]
    cut(o, [prism(win, .070, .3)])
    mirror_apply(o)
    sin_bms = []
    for xa, xb in ((.47, .53), (.66, .73)):
        path = [(xa, .071, .160), (xa + (xb - xa) * .5, .072, .205), (xb, .071, .252)]
        sin_bms.append(sweep(path, (0, 1, 0), [.032, .022, .032], [.022, .020, .022]))
    s = join("MF4_Sinews", sin_bms)
    mirror_apply(s)
    return o, s

def build_rear_cowl():
    out = [(-.176, .368), (.004, .368), (-.012, .30), (-.04, .192), (-.10, .168), (-.176, .178)]
    o = link("MF4_RearCowl", solid_plate(out, .066, .086, fold=((-.18, .262), (.0, .28), .008, .12)))
    th = []
    for xb, zb, ln in ((-.005, .336, .10), (-.065, .326, .115), (-.125, .316, .12)):
        path = [(xb, .080, zb), (xb - ln * .45, .089, zb + .008), (xb - ln * .8, .089, zb + .016),
                (xb - ln, .086, zb + .022)]
        th.append(sweep(path, (0, 1, .3), [.040, .028, .012, .003], [.018, .015, .008, .002]))
    t = join("MF4_Thorns", th)
    mirror_apply(o); mirror_apply(t)
    return o, t

def build_selector_boss():
    sel = bpy.data.objects["Vandal_FireSelector.001"]
    pts = [sel.matrix_world @ Vector(c) for c in sel.bound_box]
    cx = sum(p.x for p in pts) / 8; cz = sum(p.z for p in pts) / 8
    r = .050
    out = [(cx + r * math.cos(a), cz + r * math.sin(a))
           for a in [math.radians(22.5 + 45 * i) for i in range(8)]]
    o = link("MF4_SelectorBoss", solid_plate(out, .064, .0885, ch=.004))
    mirror_apply(o)
    return o

def build_collar():
    def sec(k):
        return [(.030 * k, .232), (.054 * k, .248), (.060 * k, .300), (.054 * k, .352), (.030 * k, .372)]
    st = [(1.655, ring(sec(.90))), (1.675, ring(sec(1.0))), (1.735, ring(sec(1.0))), (1.78, ring(sec(.74)))]
    o = link("MF4_Collar", loft(st, ring_mats([ARM, ARM, ARM, ARM], bottom=ARM, top=ARM), cap_mat=EDGE))
    win = [(1.690, .292), (1.738, .306), (1.738, .278), (1.694, .268)]
    cut(o, [prism(win, .048, .3), prism(win, -.048, -.3)], rim=.0022)
    return o

def build_muzzle():
    prof = [(2.384, .046), (2.42, .052), (2.452, .050), (2.462, .036), (2.476, .048),
            (2.508, .045), (2.518, .033), (2.532, .043), (2.566, .039), (2.576, .029),
            (2.590, .036), (2.63, .028), (2.647, .022)]
    st = [[(x, r * math.cos(math.radians(30 + 60 * i)), .285 + r * math.sin(math.radians(30 + 60 * i)))
           for i in range(6)] for x, r in prof]
    o = link("MF4_Muzzle", loft3(st, [ARM] * 6, cap_mat=CORE))
    for p in o.data.polygons:
        xs = [o.data.vertices[i].co.x for i in p.vertices]
        if max(xs) - min(xs) < .012:
            p.material_index = EDGE
    return o

def build_stock():
    path, wid, th = [], [], []
    for x in (-.17, -.24, -.33, -.45, -.62, -.85, -1.05, -1.13):
        t = min(1, (-.17 - x) / .30)
        zc = .30 + (.386 - .30) * (t ** .7)
        path.append((x, 0, zc)); wid.append(.16 - (.16 - .062) * (t ** .7)); th.append(.060 - .010 * t)
    top = link("MF4_StockTop", sweep(path, (0, 1, 0), wid, th, STRUT, STRUT_M))
    win = [(-.30, .366), (-.40, .378), (-1.00, .380), (-1.06, .372), (-1.00, .362), (-.40, .356)]
    cut(top, [prism(win, .036, .3), prism(win, -.036, -.3)], rim=.002)
    p0, p1 = Vector((-.135, 0, .254)), Vector((-1.14, 0, -.10))   # front seats inside the rear cowl (owner: gap, 2026-11-14)
    path = [p0.lerp(p1, t) for t in (0, .15, .5, .85, 1)]
    low = link("MF4_StockLow", sweep(path, (0, 1, 0), [.070, .052, .050, .052, .060],
                                     [.040, .036, .034, .036, .040], STRUT, STRUT_M))
    win2 = [(-.46, .155), (-.50, .145), (-.98, -.034), (-1.02, -.038), (-.99, -.050), (-.48, .137)]
    cut(low, [prism(win2, .021, .3), prism(win2, -.021, -.3)], rim=.002)
    out = [(-1.098, .418), (-1.16, .418), (-1.215, .40), (-1.252, .35), (-1.236, .29),
           (-1.252, .20), (-1.240, .10), (-1.252, .00), (-1.240, -.10), (-1.215, -.176),
           (-1.13, -.176), (-1.098, -.14)]
    butt = link("MF4_Butt", solid_plate(out, 0, .064, ch=.008, open_inner=True))
    mirror_apply(butt, merge=True)
    slit = [(-1.128, .330), (-1.168, .345), (-1.196, .30), (-1.205, .02), (-1.19, -.10), (-1.165, -.13),
            (-1.15, -.08), (-1.158, .02), (-1.150, .29)]
    cut(butt, [prism(slit, .049, .3), prism(slit, -.049, -.3)], rim=.003)
    sb = []
    for zc in (.17, -.01):
        sb.append(sweep([(-1.140, .050, zc + .022), (-1.172, .051, zc), (-1.203, .050, zc - .022)],
                        (0, 1, 0), [.020, .015, .020], [.014, .013, .014]))
    sn = join("MF4_ButtSinews", sb)
    mirror_apply(sn)
    return top, low, butt

def build_mag():
    back = [(.47, .199), (.462, .12), (.49, .031), (.513, -.027), (.536, -.085), (.565, -.141),
            (.593, -.197), (.626, -.252), (.658, -.306), (.694, -.36), (.708, -.404)]
    toe = [(.74, -.428), (.86, -.426), (.96, -.404), (1.026, -.366)]
    front = [(.995, -.322), (.93, -.268), (.887, -.217), (.851, -.164), (.817, -.11), (.788, -.054),
             (.759, .001), (.737, .06), (.717, .12), (.708, .199)]
    o = link("MF4_Magazine", solid_plate(back + toe + front, 0, .057, ch=.008, open_inner=True), bone="Mag")
    mirror_apply(o, merge=True)
    fr = list(reversed(front))
    pairs = [(back[i], fr[i]) for i in range(2, 10)]
    bk = [lerp2(b, f, .22) for b, f in pairs[1:-1]]
    fw = [lerp2(b, f, .76) for b, f in pairs[1:-1]]
    tip0 = lerp2(*pairs[0], .5); tip1 = lerp2(*pairs[-1], .52)
    win = [tip0] + bk + [tip1] + list(reversed(fw))
    cut(o, [prism(win, .040, .3), prism(win, -.040, -.3)], rim=.003)
    sin_bms = []
    for i in (3, 5):
        b, f = pairs[i]
        a = lerp2(b, f, .18); c = lerp2(b, f, .80); m = lerp2(a, c, .5)
        sin_bms.append(sweep([(a[0], .041, a[1] + .03), (m[0], .042, m[1] + .005), (c[0], .041, c[1] - .02)],
                             (0, 1, 0), [.018, .013, .018], [.016, .014, .016]))
    s = join("MF4_MagSinews", sin_bms, bone="Mag")
    mirror_apply(s)
    return o, s

def build_grip():
    rows = [(-.096, .086, .112, .05), (-.124, .04, .102, -.035), (-.14, -.012, .09, -.09),
            (-.149, -.066, .078, -.14), (-.158, -.121, .064, -.19), (-.174, -.173, .05, -.235)]
    bk = [lerp2((bx, bz), (fx, fz), .07) for bx, bz, fx, fz in rows]
    fw = [lerp2((bx, bz), (fx, fz), .90) for bx, bz, fx, fz in rows]
    tip = lerp2((-.183, -.228), (.034, -.267), .25)
    out = [(-.07, .132), (.085, .118)] + fw + [tip] + list(reversed(bk))
    o = link("MF4_GripPlate", solid_plate(out, .060, .0715, ch=.0035,
                                          fold=((-.10, .12), (-.17, -.22), .004, .10)))
    w1 = [lerp2((bx, bz), (fx, fz), t) for (bx, bz, fx, fz), t in zip(rows[:4], (.30, .28, .28, .30))]
    w2 = [lerp2((bx, bz), (fx, fz), t) for (bx, bz, fx, fz), t in zip(rows[:4], (.52, .55, .55, .50))]
    w = [lerp2(w1[0], w2[0], .5)] + w1[1:-1] + [lerp2(w1[-1], w2[-1], .5)] + list(reversed(w2[1:-1]))
    cut(o, [prism(w, .064, .3)], rim=.0022)
    mirror_apply(o)
    return o

def build_barrel():
    """Stock barrel and gas tube kept, stock muzzle device removed."""
    src = bpy.data.objects["Vandal_Barrel.001"]
    M = src.matrix_world
    bm = bmesh.new(); bm.from_mesh(src.data)
    bm.verts.ensure_lookup_table()
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
        f.material_index = STEEL
    return link("MF4_Barrel", bm)

def build_shoulder():
    """Layered S-swept plate over the upper receiver; its front runs down
    the mantle fang so the two read as one carved transition."""
    out = [(.30, .370), (.42, .390), (.80, .394), (.905, .388), (.952, .330), (.988, .246),
           (1.004, .192), (.968, .252), (.925, .330), (.86, .362), (.62, .364), (.42, .362)]
    o = link("MF4_Shoulder", solid_plate(out, .082, .098, ch=.005,
                                        fold=((.30, .372), (1.0, .30), .006, .09)))
    mirror_apply(o)
    return o

def build_front_sight_armour():
    """Carved cheek plates on the stock front-sight block (below the sight
    line, flush on its flat sides), with a small fluid slit like the collar."""
    out = [(1.945, .224), (2.10, .224), (2.112, .252), (2.098, .352), (2.062, .374), (1.958, .374), (1.940, .330)]
    o = link("MF4_FrontSightArmour", solid_plate(out, .0575, .068, ch=.0035,
                                                fold=((1.94, .30), (2.11, .30), .003, .08)))
    win = [(1.975, .338), (2.072, .354), (2.072, .336), (1.986, .322)]
    cut(o, [prism(win, .0605, .3)], rim=.002)
    mirror_apply(o)
    return o

parts = {}
parts["fs"] = build_front_sight_armour()
parts["shoulder"] = build_shoulder()
parts["upper"] = build_upper()
parts["core"] = build_core()
parts["ribs"] = build_ribs()
parts["carapace"] = build_carapace()
parts["cowl"] = build_rear_cowl()
parts["boss"] = build_selector_boss()
parts["collar"] = build_collar()
parts["muzzle"] = build_muzzle()
parts["stock"] = build_stock()
parts["mag"] = build_mag()
parts["grip"] = build_grip()
parts["barrel"] = build_barrel()

for o in col.objects:
    flat_uv(o)

# the v04 magazine has its own toe plate: drop the stock baseplate from the
# retained magazine hardware (keeps the feed lips and the top cartridge)
_mh = bpy.data.objects["Moltframe_MagHardware"]
_bm = bmesh.new(); _bm.from_mesh(_mh.data)
_low = [v for v in _bm.verts if (_mh.matrix_world @ v.co).z < -.25 or (_mh.matrix_world @ v.co).z < .105]
if _low:
    bmesh.ops.delete(_bm, geom=_low, context="VERTS")
    _bm.to_mesh(_mh.data)
_bm.free()
# the stock ejection deflector sat on the stock receiver wall; v04 frames the
# port with the carapace and mantle instead, so drop that loose piece
_rh = bpy.data.objects["Moltframe_ReceiverHardware"]
_bm = bmesh.new(); _bm.from_mesh(_rh.data)
_dz = [v for v in _bm.verts if (_rh.matrix_world @ v.co).y < -.086 and .26 < (_rh.matrix_world @ v.co).z < .35]
if _dz:
    bmesh.ops.delete(_bm, geom=_dz, context="VERTS")
    _bm.to_mesh(_rh.data)
_bm.free()
set_skin(True)

result = {"objects": [(o.name, len(o.data.polygons)) for o in col.objects]}
