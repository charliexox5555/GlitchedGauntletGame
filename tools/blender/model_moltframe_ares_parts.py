"""Moltframe Ares: the Vandal v05 language on the stock Ares (LMG, drum).

Exec order (stock Ares_RemasterV2_v05 open):
    RIG_NAME, COL_NAME, ITEM_KEY = "Ares_Rig", "Moltframe Ares", "Ares"
    exec(model_moltframe_vandal_v04.py); exec(<helper half of the Vandal parts file>)
    exec(model_moltframe_spectre_parts.py up to "# ---- build")   # retain(), zcut(), SLOT_SKIN
    exec(this file)

Brief: heavier segmented shoulder armour, a small visible fluid inlet on the
body, the folded edges echoed on the existing drum. Charging handle (+Y),
selector (+Y), bolt (-Y) keep stock positions inside a mirrored channel.
"""

SLOT = (.27, .905, .238, .416)

def zt_spine(x):
    if x <= .21: return .487
    if x <= .27: return .487 + (x - .21) / .06 * .028
    if x <= 1.99: return .515
    if x <= 2.03: return .515 - (x - 1.99) / .04 * .037
    if x <= 2.16: return .478            # seat for the front sight base (z .476)
    return .478 - (x - 2.16) / .12 * .036

def zb_mantle(x):
    pts = [(-1, .418), (.92, .418), (1.0, .44), (2.0, .44), (2.28, .420)]
    for (x0, z0), (x1, z1) in zip(pts, pts[1:]):
        if x0 <= x <= x1:
            return z0 + (z1 - z0) * (x - x0) / (x1 - x0)
    return pts[-1][1]

def upper_half(x):
    zt, zb = zt_spine(x), zb_mantle(x)
    k = 1.0 if x <= 2.0 else 1 - (x - 2.0) / .28 * .50
    h = zt - zb
    return [
        (.056 * k, zb), (.090 * k, zb), (.096 * k, zb + .16 * h),
        (.100 * k, zb + .40 * h), (.100 * k, zb + .50 * h),
        (.084 * k, zb + .72 * h), (.048 * k, zb + .90 * h), (.034 * k, zt - .002), (.024 * k, zt),
    ]
UPPER_MATS = [CORE, EDGE, ARM, EDGE, ARM, ARM, ARM, EDGE]

def build_upper():
    xs = [-.186, -.178, .0, .21, .24, .27, .60, .92, 1.0, 1.4, 1.8, 1.99, 2.03, 2.10, 2.16, 2.22, 2.28]
    st = [(x, ring(upper_half(x))) for x in xs]
    x0, r0 = st[0]
    st[0] = (x0, [(y * .84, z - (.006 if z > .47 else 0)) for y, z in r0])
    o = link("MFA_UpperShell", loft(st, ring_mats(UPPER_MATS, bottom=CORE, top=ARM), cap_mat=EDGE))
    cutters = []
    for xa, xb in ((.34, .50), (.58, .74), (1.30, 1.46), (1.54, 1.70), (1.78, 1.92)):
        sl = .013
        cutters.append(zcut([(xa, -sl), (xb, -sl), (xb - .012, sl), (xa - .012, sl)], .500, .7, floor=VIOLET))
    # fuller between crease band (top .4692) and shoulder (.4795) at the rail height
    fuller = [(.30, .4715), (.34, .4765), (1.90, .4765), (1.95, .4715), (1.90, .4735), (.34, .4735)]
    cutters += [prism(fuller, .0885, .3, floor=CORE), prism(fuller, -.0885, -.3, floor=CORE)]
    cut(o, cutters, rim=.0018)
    return o

def build_core():
    def rec(x):
        b = .202
        return [(.056, b), (.070, b + .012), (.070, SLOT[2]), (.0665, SLOT[2] + .006),
                (.0665, SLOT[3] - .004), (.070, SLOT[3] + .004), (.070, .47), (.05, .48)]
    st = [(x, ring(rec(x))) for x in (-.184, 1.0, 1.21)]
    a = link("MFA_ReceiverCore", loft(st, ring_mats([CORE] * 7, bottom=CORE, top=CORE), cap_mat=CORE))
    well = zcut([(.55, -.06), (1.08, -.06), (1.08, .06), (.55, .06)], .10, .26, mat=CORE)
    trig = zcut([(.24, -.014), (.33, -.014), (.33, .014), (.24, .014)], .12, .26, mat=CORE)
    cut(a, [well, trig], rim=0)
    def hg(k=1.0):
        return [(.040 * k, .190), (.060 * k, .205), (.066 * k, .250), (.066 * k, .42), (.05 * k, .46)]
    st = [(1.19, ring(hg())), (2.00, ring(hg())), (2.04, ring(hg(.86)))]
    b = link("MFA_HandguardFluid", loft(st, ring_mats([GASKET, VIOLET, VIOLET, VIOLET], bottom=GASKET, top=VIOLET),
                                        cap_mat=CORE))
    return a, b

def build_channel_rail():
    out = [(.25, .214), (.92, .214), (.95, .227), (.92, .240), (.27, .240), (.25, .227)]
    o = link("MFA_ChannelRail", solid_plate(out, .062, .090, fold=((.25, .227), (.95, .227), .003, .03)))
    mirror_apply(o)
    return o

def build_segments():
    """Four heavy overlapping shoulder segments over the fore-end; raked V
    seams between them show the fluid core. The first one wraps the receiver
    front (feed block) and starts behind the drum's front edge."""
    plates = []
    segs = [(.905, 1.235), (1.215, 1.48), (1.46, 1.725), (1.705, 1.99)]
    for i, (xa, xb) in enumerate(segs):
        rake = .045
        lo = .214 if i == 0 else 0.0
        out = [(xa + (0 if i == 0 else .012), .446), (xb - .028, .446), (xb, .40), (xb - .012, .262),
               (xb - .045, max(.196, lo)), (xb - .09, max(.186, lo)), (xa + rake, max(.190, lo)),
               (xa + (0 if i == 0 else .02), .30)]
        o = link(f"MFA_Segment{i + 1}", solid_plate(out, .062 + .004 * (i % 2), .092 + .004 * (i % 2), ch=.0055,
                                                     fold=((xa, .33), (xb, .30), .006, .14)))
        if i == 0:
            win = [(.95, .33), (.99, .40), (1.18, .405), (1.205, .37), (1.16, .32), (.99, .31)]
            cut(o, [prism(win, .066, .3), prism(win, -.066, -.3)])
        mirror_apply(o)
        plates.append(o)
    def keel(k=1.0):
        return [(.030 * k, .156), (.052 * k, .166), (.056 * k, .186), (.036 * k, .198)]
    st = [(1.19, ring(keel(.85))), (1.22, ring(keel())), (1.96, ring(keel())), (2.02, ring(keel(.7)))]
    st[-1] = (st[-1][0], [(y, z + .012) for y, z in st[-1][1]])
    k = link("MFA_Keel", loft(st, ring_mats([ARM, ARM, ARM], bottom=ARM, top=ARM), cap_mat=EDGE))
    return plates, k

def build_rear_cowl():
    """Rear receiver plate with the small fluid inlet (the Ares' one body
    window, close to the player's eye) and rear-swept thorns."""
    out = [(-.184, .420), (.27, .420), (.27, .30), (.24, .285), (-.184, .285)]
    o = link("MFA_RearCowl", solid_plate(out, .064, .092, fold=((-.19, .35), (.27, .36), .008, .10)))
    win = [(-.10, .320), (-.06, .392), (.17, .396), (.205, .372), (.18, .322), (-.06, .312)]
    cut(o, [prism(win, .069, .3), prism(win, -.069, -.3)])
    mirror_apply(o)
    sb = []
    for xa, xb in ((.0, .04), (.09, .13)):
        sb.append(sweep([(xa, .070, .310), ((xa + xb) / 2, .071, .354), (xb, .070, .398)],
                        (0, 1, 0), [.030, .021, .030], [.022, .020, .022]))
    s = join("MFA_InletSinews", sb)
    mirror_apply(s)
    th = []
    for xb, zb, ln in ((-.02, .468, .10), (-.08, .460, .11), (-.14, .452, .11)):
        path = [(xb, .083, zb), (xb - ln * .45, .091, zb + .008), (xb - ln * .8, .091, zb + .015),
                (xb - ln, .088, zb + .021)]
        th.append(sweep(path, (0, 1, .3), [.038, .028, .012, .003], [.013, .011, .006, .002]))
    t = join("MFA_Thorns", th)
    mirror_apply(t)
    return o, s, t

def build_selector_boss():
    sel = bpy.data.objects["Ares_FireSelector"]
    pts = [sel.matrix_world @ Vector(c) for c in sel.bound_box]
    cx = sum(p.x for p in pts) / 8; cz = sum(p.z for p in pts) / 8
    r = .046
    out = [(cx + r * math.cos(a), cz + r * math.sin(a)) for a in [math.radians(22.5 + 45 * i) for i in range(8)]]
    o = link("MFA_SelectorBoss", solid_plate(out, .066, .0925, ch=.004))
    mirror_apply(o)
    return o

def build_muzzle():
    prof = [(2.700, .060), (2.73, .070), (2.775, .068), (2.787, .052), (2.802, .066), (2.85, .062),
            (2.862, .047), (2.877, .060), (2.93, .055), (2.942, .041), (2.957, .051), (3.03, .040), (3.075, .030)]
    st = [[(x, r * math.cos(math.radians(30 + 60 * i)), .371 + r * math.sin(math.radians(30 + 60 * i)))
           for i in range(6)] for x, r in prof]
    o = link("MFA_Muzzle", loft3(st, [ARM] * 6, cap_mat=CORE))
    for p in o.data.polygons:
        xs = [o.data.vertices[i].co.x for i in p.vertices]
        if max(xs) - min(xs) < .016:
            p.material_index = EDGE
    return o

def build_stock():
    path, wid, th = [], [], []
    for x in (-.186, -.23, -.30, -.42, -.60, -.80, -1.00, -1.09):
        t = min(1, (-.186 - x) / .25)
        zc = .34 + (.430 - .34) * (t ** .7)
        path.append((x, 0, zc)); wid.append(.20 - (.20 - .075) * (t ** .7)); th.append(.062 - .008 * t)
    top = link("MFA_StockTop", sweep(path, (0, 1, 0), wid, th, STRUT, STRUT_M))
    win = [(-.34, .418), (-.42, .434), (-1.00, .436), (-1.06, .428), (-1.00, .418), (-.42, .412)]
    cut(top, [prism(win, .040, .3), prism(win, -.040, -.3)], rim=.002)
    p0, p1 = Vector((-.13, 0, .341)), Vector((-1.10, 0, -.110))   # front buried in the receiver core (owner: gap, 2026-11-14)
    path = [p0.lerp(p1, t) for t in (0, .15, .5, .85, 1)]
    low = link("MFA_StockLow", sweep(path, (0, 1, 0), [.080, .062, .060, .062, .070],
                                     [.044, .040, .038, .040, .044], STRUT, STRUT_M))
    win2 = [(-.42, .186), (-.46, .172), (-.98, -.050), (-1.02, -.056), (-.99, -.070), (-.44, .162)]
    cut(low, [prism(win2, .025, .3), prism(win2, -.025, -.3)], rim=.002)
    out = [(-1.078, .480), (-1.14, .480), (-1.20, .462), (-1.232, .41), (-1.216, .34), (-1.232, .24),
           (-1.218, .13), (-1.232, .03), (-1.218, -.07), (-1.198, -.151), (-1.12, -.151), (-1.078, -.12)]
    butt = link("MFA_Butt", solid_plate(out, 0, .078, ch=.009, open_inner=True))
    mirror_apply(butt, merge=True)
    slit = [(-1.11, .40), (-1.145, .415), (-1.178, .36), (-1.188, .03), (-1.172, -.08), (-1.146, -.11),
            (-1.13, -.06), (-1.138, .03), (-1.13, .35)]
    cut(butt, [prism(slit, .062, .3), prism(slit, -.062, -.3)], rim=.003)
    sb = []
    for zc in (.22, .03):
        sb.append(sweep([(-1.12, .063, zc + .022), (-1.155, .064, zc), (-1.186, .063, zc - .022)],
                        (0, 1, 0), [.020, .015, .020], [.016, .015, .016]))
    sn = join("MFA_ButtSinews", sb)
    mirror_apply(sn)
    return top, low, butt, sn

def build_drum():
    """Rebuilt drum on the stock envelope (x .563-1.07, axis z -.08,
    r .278, hoops r .288): a 16-sided closed body (the stock drum is not
    watertight, so it can't take booleans), polished fold hoops, recessed
    fluid windows between the hoops on both sides, feed tower and knob."""
    zc, n = -.08, 16
    def circ(x, r, k0=0.0):
        return [(x, r * math.cos(2 * math.pi * (i + .5) / n), zc + r * math.sin(2 * math.pi * (i + .5) / n))
                for i in range(n)]
    body = loft3([circ(.565, .246), circ(.578, .270), circ(1.028, .270), circ(1.042, .246)], [ARM] * n, cap_mat=ARM)
    o = link("MFA_Drum", body, bone="Mag")
    cutters = []
    for xa, xb in ((.640, .705), (.758, .825), (.880, .945)):
        win = [(xa, zc), (xa + .012, zc + .072), (xb - .012, zc + .072), (xb, zc), (xb - .012, zc - .072), (xa + .012, zc - .072)]
        cutters += [prism(win, .250, .5), prism(win, -.250, -.5)]
    cut(o, cutters, rim=.003)
    hoops = []
    for xa, xb in ((.598, .626), (.718, .742), (.843, .867), (.963, .991)):
        hoops.append(loft3([circ(xa, .258), circ(xa + .005, .280), circ(xb - .005, .280), circ(xb, .258)],
                           [EDGE] * n, caps=(True, True), cap_mat=ARM))
    h = join("MFA_DrumHoops", hoops, bone="Mag")
    def box(x0, x1, y, z0, z1, c=.008):
        return [(x0, [(y - c, z0), (y, z0 + c), (y, z1 - c), (y - c, z1)]), (x1, [(y - c, z0), (y, z0 + c), (y, z1 - c), (y - c, z1)])]
    st = [(x, ring(pts)) for x, pts in box(.608, .94, .052, .12, .222)]
    tower = link("MFA_DrumFeed", loft(st, ring_mats([CORE, CORE, CORE], bottom=CORE, top=CORE), cap_mat=CORE), bone="Mag")
    kn = [[(x, r * math.cos(math.radians(30 + 60 * i)), zc + r * math.sin(math.radians(30 + 60 * i))) for i in range(6)]
          for x, r in ((1.036, .070), (1.052, .066), (1.068, .050))]
    knob = link("MFA_DrumKnob", loft3(kn, [LILAC] * 6, cap_mat=EDGE), bone="Mag")
    return o, h, tower, knob

def build_grip():
    rows = [(-.024, .136, .151, .057), (-.043, .096, .134, .016), (-.062, .056, .11, -.022),
            (-.081, .016, .086, -.059), (-.1, -.024, .066, -.099), (-.119, -.063, .049, -.14),
            (-.138, -.103, .031, -.18), (-.157, -.143, .023, -.225)]
    bk = [lerp2((bx, bz), (fx, fz), .08) for bx, bz, fx, fz in rows]
    fw = [lerp2((bx, bz), (fx, fz), .90) for bx, bz, fx, fz in rows]
    tip = lerp2((-.176, -.183), (.012, -.269), .3)
    out = [(-.005, .17), (.155, .15)] + fw + [tip] + list(reversed(bk))
    o = link("MFA_GripPlate", solid_plate(out, .062, .0735, ch=.0035, fold=((-.03, .15), (-.15, -.2), .004, .10)))
    w1 = [lerp2((bx, bz), (fx, fz), t) for (bx, bz, fx, fz), t in zip(rows[:5], (.32, .30, .30, .30, .32))]
    w2 = [lerp2((bx, bz), (fx, fz), t) for (bx, bz, fx, fz), t in zip(rows[:5], (.52, .56, .56, .56, .52))]
    w = [lerp2(w1[0], w2[0], .5)] + w1[1:-1] + [lerp2(w1[-1], w2[-1], .5)] + list(reversed(w2[1:-1]))
    cut(o, [prism(w, .0655, .3)], rim=.0022)
    mirror_apply(o)
    return o

hw = {}
hw["rec"] = retain("Ares_Receiver", lambda P: max(p.z for p in P) < .222 and max(abs(p.y) for p in P) < .09,
                   "MFA_ReceiverHardware")
hw["grip"] = retain("Ares_Grip", lambda P: True, "MFA_GripHardware")
hw["barrel"] = retain("Ares_Barrel", lambda P: max(p.x for p in P) < 2.75, "MFA_Barrel")
parts = {}
parts["upper"] = build_upper()
parts["core"] = build_core()
parts["rail"] = build_channel_rail()
parts["seg"] = build_segments()
parts["cowl"] = build_rear_cowl()
parts["boss"] = build_selector_boss()
parts["muzzle"] = build_muzzle()
parts["stock"] = build_stock()
parts["drum"] = build_drum()
parts["grip"] = build_grip()
for o in col.objects:
    flat_uv(o)

HARDWARE = ["Ares_Sights", "Ares_ChargingHandle", "Ares_Bolt", "Ares_Trigger", "Ares_FireSelector", "Ares_CharmLoop"]
STOCK_PARTS = ["Ares_Neon", "Ares_Receiver", "Ares_Handguard", "Ares_Barrel", "Ares_Grip", "Ares_Stock", "Ares_Pins", "Ares_Drum"]

def set_skin(on):
    for n in HARDWARE:
        o = bpy.data.objects[n]
        for i, sl in enumerate(o.material_slots):
            if i < 8:
                sl.material = SLOT_SKIN[i] if on else bpy.data.materials[STOCK_SET[i]]
    for n in STOCK_PARTS:
        o = bpy.data.objects[n]; o.hide_render = on; o.hide_set(on)
    col.hide_render = not on
    col.hide_viewport = not on

set_skin(True)
result = {"objects": [(o.name, len(o.data.polygons)) for o in col.objects]}
