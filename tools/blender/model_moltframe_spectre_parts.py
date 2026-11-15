"""Moltframe Spectre: the Vandal v05 language on the stock Spectre.

Exec order in the Blender MCP session (stock Spectre_RemasterV2_v05 open):
    RIG_NAME, COL_NAME, ITEM_KEY = "Spectre_Rig", "Moltframe Spectre", "Spectre"
    exec(model_moltframe_vandal_v04.py)         # materials + plate/loft/cut helpers
    exec(<helper half of model_moltframe_vandal_v04_parts.py>)
    exec(this file)

Brief (concept.md): two compact crescent plates and one short, wide fluid
window on the left; the suppressor silhouette stays clean. Line rules: faceted
graphite armour, polished folds, fluid recessed behind gasket walls with
sinews, integrated spine with violet slots, thorns, skeletal stock, leaf
window magazine and grip. Every cosmetic form is mirrored; the charging ring
(+Y), selector (+Y), bolt (-Y) and magazine release keep stock positions.
"""
from collections import defaultdict

STOCK_SET = ["Body", "Panel", "Dark", "Metal", "Grip", "Accent", "Neon", "Brass"]
EXTRA = {"Neon": pbsdf("MF4 Indicator", "BA63F2", 0.0, .3)[0], "Brass": pbsdf("MF4 Smoke Nickel", "63637A", 1.0, .30)[0]}
_ind = EXTRA["Neon"].node_tree.nodes["Principled BSDF"]
_ind.inputs["Emission Color"].default_value = (*_lin("BA63F2"), 1)
_ind.inputs["Emission Strength"].default_value = 2.0
SLOT_SKIN = [MATS[ARM], MATS[ARM], MATS[CORE], MATS[STEEL], MATS[GRIP], MATS[LILAC], EXTRA["Neon"], EXTRA["Brass"]]

def retain(src_name, keep, new_name, bone="Root"):
    """Copy the components of a stock mesh that `keep(points)` accepts."""
    for o in [o for o in bpy.data.objects if o.name == new_name]:
        bpy.data.objects.remove(o)
    src = bpy.data.objects[src_name]
    me = src.data
    adj = defaultdict(set)
    for p in me.polygons:
        for i in p.vertices:
            adj[i].update(p.vertices)
    keepv, seen = set(), set()
    for i in adj:
        if i in seen:
            continue
        g, st = {i}, [i]
        while st:
            f = adj[st.pop()] - g; g |= f; st += list(f)
        seen |= g
        if keep([src.matrix_world @ me.vertices[j].co for j in g]):
            keepv |= g
    bm = bmesh.new(); bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.index not in keepv], context="VERTS")
    for v in bm.verts:
        v.co = src.matrix_world @ v.co
    o = link(new_name, bm, bone)
    # keep the stock slot indices: overwrite slots in place (materials.clear()
    # resets every face to slot 0, which painted kept parts in the body colour)
    while len(o.data.materials) < len(SLOT_SKIN):
        o.data.materials.append(None)
    for i, m in enumerate(SLOT_SKIN):
        o.data.materials[i] = m
    return o

# ------------------------------------------------------------------ shapes
SLOT = (.12, .725, .318, .432)

def zt_spine(x):
    if x <= 0.0: return .432
    if x <= .06: return .432 + x / .06 * .038
    if x <= 1.10: return .470
    return .470 - (x - 1.10) / .12 * .018

def zb_mantle(x):
    pts = [(-1, .436), (.725, .436), (.80, .410), (1.10, .410), (1.22, .438)]
    for (x0, z0), (x1, z1) in zip(pts, pts[1:]):
        if x0 <= x <= x1:
            return z0 + (z1 - z0) * (x - x0) / (x1 - x0)
    return pts[-1][1]

def upper_half(x):
    zt, zb = zt_spine(x), zb_mantle(x)
    k = 1.0 if x <= 1.10 else 1 - (x - 1.10) / .12 * .45
    h = zt - zb
    wb = .082 + (.008 if zb < .40 else 0)
    return [
        (.050 * k, zb),
        (wb * k, zb),
        (wb * k + .005, zb + .20 * h),
        (.088 * k, zb + .42 * h),
        (.088 * k, zb + .52 * h),
        (.074 * k, zb + .74 * h),
        (.042 * k, zb + .92 * h),
        (.030 * k, zt - .001),
        (.022 * k, zt),
    ]
UPPER_MATS = [CORE, EDGE, ARM, EDGE, ARM, ARM, ARM, EDGE]

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
    xs = [-.33, -.322, -.10, .0, .03, .06, .30, .60, .725, .80, .95, 1.03, 1.10, 1.15, 1.19, 1.22]
    st = [(x, ring(upper_half(x))) for x in xs]
    x0, r0 = st[0]
    st[0] = (x0, [(y * .84, z - (.005 if z > .44 else 0)) for y, z in r0])
    o = link("MFS_UpperShell", loft(st, ring_mats(UPPER_MATS, bottom=CORE, top=ARM), cap_mat=EDGE))
    cutters = []
    for xa, xb in ((.16, .30), (.40, .54), (.60, .70)):
        sl = .012
        cutters.append(zcut([(xa, -sl), (xb, -sl), (xb - .012, sl), (xa - .012, sl)], .456, .6, floor=VIOLET))
    # no fuller here: the Spectre's mantle is only .034 tall over the channel
    cut(o, cutters, rim=.0018)
    return o

def build_core():
    def rec(x):
        b = .276
        return [(.050, b), (.066, b + .012), (.066, SLOT[2]), (.057, SLOT[2] + .006),
                (.057, SLOT[3] - .004), (.066, SLOT[3] + .004), (.066, .438), (.05, .442)]
    st = [(x, ring(rec(x))) for x in (-.328, .70, .74)]
    a = link("MFS_ReceiverCore", loft(st, ring_mats([CORE] * 7, bottom=CORE, top=CORE), cap_mat=CORE))
    def hg(k=1.0):
        return [(.040 * k, .226), (.056 * k, .240), (.058 * k, .300), (.058 * k, .405), (.045 * k, .44)]
    st = [(.70, ring(hg())), (1.13, ring(hg())), (1.15, ring(hg(.86)))]
    b = link("MFS_HandguardCore", loft(st, ring_mats([CORE] * 4, bottom=CORE, top=CORE), cap_mat=CORE))
    return a, b

def build_channel_rail():
    """Thin carved strip under the charging channel (both sides)."""
    out = [(.10, .272), (.70, .272), (.742, .292), (.70, .316), (.13, .316), (.10, .30)]
    o = link("MFS_ChannelRail", solid_plate(out, .060, .084, fold=((.10, .296), (.74, .296), .004, .05)))
    mirror_apply(o)
    return o

def build_handguard_plate():
    """Frame for the short, wide fluid window; tucks under the mantle and
    under crescent A at the rear, crescent B at the front."""
    out = [(.775, .418), (1.105, .418), (1.10, .236), (.80, .232), (.775, .26)]
    o = link("MFS_HandguardPlate", solid_plate(out, .064, .086, fold=((.77, .33), (1.11, .33), .006, .11)))
    win = [(.835, .305), (.855, .382), (.89, .395), (1.03, .395), (1.062, .375), (1.07, .33),
           (1.045, .300), (.88, .296)]
    cut(o, [prism(win, .068, .3), prism(win, -.068, -.3)])
    mirror_apply(o)
    sb = []
    for xa, xb in ((.915, .955), (.985, 1.025)):
        sb.append(sweep([(xa, .069, .298), ((xa + xb) / 2, .070, .345), (xb, .069, .393)],
                        (0, 1, 0), [.028, .020, .028], [.020, .018, .020]))
    s = join("MFS_HandguardSinews", sb)
    mirror_apply(s)
    def keel(k=1.0):
        return [(.030 * k, .220), (.050 * k, .228), (.054 * k, .246), (.034 * k, .258)]
    st = [(.70, ring(keel(.9))), (.73, ring(keel())), (1.10, ring(keel())), (1.15, ring(keel(.7)))]
    st[-1] = (st[-1][0], [(y, z + .010) for y, z in st[-1][1]])
    k = link("MFS_Keel", loft(st, ring_mats([ARM, ARM, ARM], bottom=ARM, top=ARM), cap_mat=EDGE))
    return o, s, k

def build_crescent_b():
    """Front crescent: drops from the spine at the collar and hooks back under
    the window, framing the suppressor joint."""
    out = [(1.085, .432), (1.13, .432), (1.168, .392), (1.178, .33), (1.158, .268), (1.108, .226),
           (1.06, .214), (1.088, .244), (1.122, .29), (1.132, .34), (1.118, .392)]
    o = link("MFS_CrescentB", solid_plate(out, .070, .093, ch=.005,
                                         fold=((1.10, .44), (1.16, .23), .006, .07)))
    win = [(1.142, .312), (1.152, .352), (1.16, .330), (1.150, .292)]
    cut(o, [prism(win, .076, .3)], rim=.002)
    mirror_apply(o)
    return o

def build_crescent_a():
    """Rear crescent: drops from the spine in front of the charging ring's
    travel (ring max x .70) and hooks forward under the fluid window."""
    out = [(.722, .446), (.772, .446), (.806, .405), (.822, .345), (.812, .282), (.782, .240),
           (.738, .218), (.752, .252), (.772, .300), (.776, .352), (.760, .405)]
    o = link("MFS_CrescentA", solid_plate(out, .070, .093, ch=.005,
                                         fold=((.74, .45), (.80, .22), .006, .07)))
    win = [(.788, .300), (.798, .338), (.806, .318), (.798, .282)]
    cut(o, [prism(win, .076, .3)], rim=.002)
    mirror_apply(o)
    return o

def build_rear_cowl():
    out = [(-.328, .438), (.118, .438), (.118, .30), (.08, .276), (-.328, .276)]
    o = link("MFS_RearCowl", solid_plate(out, .062, .084, fold=((-.33, .36), (.12, .37), .007, .10)))
    th = []
    for xb, zb, ln in ((.06, .405, .09), (.0, .397, .105), (-.06, .389, .11)):
        path = [(xb, .078, zb), (xb - ln * .45, .085, zb + .008), (xb - ln * .8, .085, zb + .015),
                (xb - ln, .083, zb + .021)]
        th.append(sweep(path, (0, 1, .3), [.036, .026, .011, .003], [.012, .010, .006, .002]))
    t = join("MFS_Thorns", th)
    mirror_apply(o); mirror_apply(t)
    return o, t

def build_magwell_plate():
    out = [(.452, .262), (.684, .262), (.684, .085), (.66, .052), (.50, .052), (.452, .10)]
    o = link("MFS_MagwellPlate", solid_plate(out, .0795, .094, ch=.004,
                                            fold=((.45, .16), (.69, .16), .004, .12)))
    slit = [(.53, .225), (.62, .232), (.648, .205), (.63, .095), (.60, .085), (.555, .15)]
    cut(o, [prism(slit, .0825, .3)], rim=.0025)
    mirror_apply(o)
    return o

def build_stock():
    path, wid, th = [], [], []
    for x in (-.322, -.36, -.42, -.52, -.66, -.80, -.90, -.965):
        t = min(1, (-.322 - x) / .22)
        zc = .33 + (.368 - .33) * (t ** .7)
        path.append((x, 0, zc)); wid.append(.15 - (.15 - .060) * (t ** .7)); th.append(.056 - .008 * t)
    top = link("MFS_StockTop", sweep(path, (0, 1, 0), wid, th, STRUT, STRUT_M))
    win = [(-.44, .360), (-.50, .374), (-.88, .376), (-.93, .368), (-.88, .358), (-.50, .352)]
    cut(top, [prism(win, .034, .3), prism(win, -.034, -.3)], rim=.002)
    p0, p1 = Vector((-.26, 0, .3465)), Vector((-.97, 0, -.082))   # front buried in the receiver core (owner: gap, 2026-11-14)
    path = [p0.lerp(p1, t) for t in (0, .15, .5, .85, 1)]
    low = link("MFS_StockLow", sweep(path, (0, 1, 0), [.066, .050, .048, .050, .058],
                                     [.038, .034, .032, .034, .038], STRUT, STRUT_M))
    win2 = [(-.52, .178), (-.56, .166), (-.86, -.012), (-.90, -.016), (-.875, -.030), (-.54, .158)]
    cut(low, [prism(win2, .020, .3), prism(win2, -.020, -.3)], rim=.002)
    out = [(-.952, .402), (-1.0, .402), (-1.045, .388), (-1.067, .345), (-1.052, .29), (-1.067, .21),
           (-1.055, .12), (-1.067, .03), (-1.055, -.06), (-1.035, -.118), (-.975, -.118), (-.952, -.09)]
    butt = link("MFS_Butt", solid_plate(out, 0, .066, ch=.008, open_inner=True))
    mirror_apply(butt, merge=True)
    slit = [(-.972, .318), (-1.0, .332), (-1.025, .29), (-1.032, .02), (-1.02, -.07), (-.998, -.092),
            (-.985, -.05), (-.99, .02), (-.984, .28)]
    cut(butt, [prism(slit, .051, .3), prism(slit, -.051, -.3)], rim=.003)
    sb = []
    for zc in (.17, .0):
        sb.append(sweep([(-.976, .052, zc + .020), (-1.004, .053, zc), (-1.030, .052, zc - .020)],
                        (0, 1, 0), [.018, .014, .018], [.014, .013, .014]))
    sn = join("MFS_ButtSinews", sb)
    mirror_apply(sn)
    return top, low, butt, sn

def build_mag():
    back = [(.445, .12), (.442, .058), (.458, -.005), (.477, -.067), (.497, -.13), (.517, -.192),
            (.536, -.254), (.556, -.316), (.576, -.378), (.597, -.44), (.61, -.504), (.628, -.566)]
    toe = [(.655, -.578), (.76, -.582), (.85, -.570), (.868, -.548)]
    front = [(.846, -.494), (.83, -.43), (.814, -.367), (.795, -.305), (.774, -.243), (.753, -.182),
             (.732, -.12), (.704, -.061), (.676, -.001), (.648, .058), (.62, .117), (.58, .14)]
    o = link("MFS_Magazine", solid_plate(back + toe + front, 0, .059, ch=.008, open_inner=True), bone="Mag")
    mirror_apply(o, merge=True)
    fr = list(reversed(front))
    pairs = [(back[i], fr[i]) for i in range(2, 11)]
    bk = [lerp2(b, f, .24) for b, f in pairs[1:-1]]
    fw = [lerp2(b, f, .76) for b, f in pairs[1:-1]]
    tip0 = lerp2(*pairs[0], .5); tip1 = lerp2(*pairs[-1], .5)
    win = [tip0] + bk + [tip1] + list(reversed(fw))
    cut(o, [prism(win, .042, .3), prism(win, -.042, -.3)], rim=.003)
    sb = []
    for i in (3, 6):
        b, f = pairs[i]
        a = lerp2(b, f, .2); c = lerp2(b, f, .8); m = lerp2(a, c, .5)
        sb.append(sweep([(a[0], .043, a[1] + .028), (m[0], .044, m[1] + .005), (c[0], .043, c[1] - .02)],
                        (0, 1, 0), [.018, .013, .018], [.016, .014, .016]))
    s = join("MFS_MagSinews", sb, bone="Mag")
    mirror_apply(s)
    return o, s

def build_grip():
    rows = [(-.052, .123, .105, .052), (-.067, .085, .092, .013), (-.082, .047, .079, -.026),
            (-.098, .009, .065, -.065), (-.113, -.029, .052, -.104), (-.128, -.066, .039, -.142),
            (-.143, -.104, .026, -.181), (-.159, -.142, .013, -.22)]
    bk = [lerp2((bx, bz), (fx, fz), .08) for bx, bz, fx, fz in rows]
    fw = [lerp2((bx, bz), (fx, fz), .90) for bx, bz, fx, fz in rows]
    tip = lerp2((-.172, -.181), (-.0, -.259), .3)
    out = [(-.035, .135), (.11, .118)] + fw + [tip] + list(reversed(bk))
    o = link("MFS_GripPlate", solid_plate(out, .058, .0695, ch=.0035, fold=((-.05, .13), (-.15, -.2), .004, .10)))
    w1 = [lerp2((bx, bz), (fx, fz), t) for (bx, bz, fx, fz), t in zip(rows[:5], (.32, .30, .30, .30, .32))]
    w2 = [lerp2((bx, bz), (fx, fz), t) for (bx, bz, fx, fz), t in zip(rows[:5], (.52, .56, .56, .56, .52))]
    w = [lerp2(w1[0], w2[0], .5)] + w1[1:-1] + [lerp2(w1[-1], w2[-1], .5)] + list(reversed(w2[1:-1]))
    cut(o, [prism(w, .0615, .3)], rim=.0022)
    mirror_apply(o)
    return o

# ------------------------------------------------------------------- build
hw = {}
hw["rec"] = retain("Spectre_Receiver", lambda P: max(p.z for p in P) < .30 or min(p.z for p in P) > .04 and max(p.z for p in P) < .08,
                   "MFS_ReceiverHardware")
hw["grip"] = retain("Spectre_Grip", lambda P: True, "MFS_GripHardware")
parts = {}
parts["upper"] = build_upper()
parts["core"] = build_core()
parts["rail"] = build_channel_rail()
parts["hg"] = build_handguard_plate()
parts["ca"] = build_crescent_a()
parts["cb"] = build_crescent_b()
parts["cowl"] = build_rear_cowl()
parts["mw"] = build_magwell_plate()
parts["stock"] = build_stock()
parts["mag"] = build_mag()
parts["grip"] = build_grip()
for o in col.objects:
    flat_uv(o)

HARDWARE = ["Spectre_Sights", "Spectre_Suppressor", "Spectre_Pins", "Spectre_ChargingHandle", "Spectre_Bolt",
            "Spectre_Trigger", "Spectre_FireSelector", "Spectre_CharmLoop"]
STOCK_PARTS = ["Spectre_Neon", "Spectre_Receiver", "Spectre_Handguard", "Spectre_Grip", "Spectre_Stock", "Spectre_Mag"]

def set_skin(on):
    for n in HARDWARE:
        o = bpy.data.objects[n]
        for i, sl in enumerate(o.material_slots):
            if i < 8:
                skin = SLOT_SKIN[i]
                if n == "Spectre_Suppressor" and i == 2:
                    skin = MATS[ARM]        # graphite can, so it reads as part of the armour
                sl.material = skin if on else bpy.data.materials[STOCK_SET[i]]
    for n in STOCK_PARTS:
        o = bpy.data.objects[n]; o.hide_render = on; o.hide_set(on)
    col.hide_render = not on
    col.hide_viewport = not on

set_skin(True)
result = {"objects": [(o.name, len(o.data.polygons)) for o in col.objects]}
