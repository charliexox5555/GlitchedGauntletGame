"""Sealwork Vandal v02: full sculpted shell (stock Vandal open). Exec after
model_giltfold_kit.py and model_vandal_shell_base.py (run_sfg KIT chain).

Owner 2026-11-14: the plate versions read as a reskin; the line needs the
same full-sculpt vibe as Moltframe, at the quality of the Ruin reference
(original shapes). Black-jade body framed by gold lines (every plate rim is a
gold chamfer), a gold ridge down the top, swept gold talons on the handguard
shoulders, gold-framed leaf windows onto a vermilion core, the clipped red
seal behind the magazine well, an open stock frame with a gold scroll, a red
crystal magazine in a gold shoe, a carved grip with gold studs, a gold
barrel and crown. Fit, channel and moving parts per model_vandal_shell_base."""

_k = open(os.path.join(TB, "model_sealwork_kit.py")).read()
exec(_k[:_k.index("def sw_marshal")])          # Sealwork palette + seal()

JADE, GOLD, DARK, GROOVE, RED, GRIPM, STEELM = 0, 1, 2, 3, 4, 5, 6
P = "SWV"

def zt_top(x):
    if x <= .16: return .408
    if x <= .26: return .408 + (x - .16) / .10 * .050
    if x <= 1.60: return .458
    return .458 - (x - 1.60) / .10 * .060

def zb_bot(x):
    pts = [(-1, .356), (.86, .356), (.90, .318), (.95, .262), (1.00, .262), (1.05, .318), (1.09, .345), (1.80, .345)]
    for (x0, z0), (x1, z1) in zip(pts, pts[1:]):
        if x0 <= x <= x1:
            return z0 + (z1 - z0) * (x - x0) / (x1 - x0)
    return pts[-1][1]

def build_upper():
    xs = [-.178, -.17, .0, .16, .21, .26, .55, .86, .90, .95, 1.00, 1.05, 1.09, 1.30, 1.45, 1.60, 1.65, 1.70]
    st = []
    for x in xs:
        zt, zb = zt_top(x), zb_bot(x)
        k = 1 - max(0.0, (x - 1.60) / .10) * .30
        half = [(.060 * k, zb), (.087 * k, zb), (.094 * k, zb + .010), (.094 * k, zt - .044), (.083 * k, zt - .024),
                (.052 * k, zt - .009), (.024 * k, zt)]
        st.append((x, ring(half)))
    x0, r0 = st[0]
    st[0] = (x0, [(y * .86, z) for y, z in r0])
    o = link(P + "_Upper", loft(st, ring_mats([DARK, GOLD, JADE, JADE, JADE, JADE], bottom=DARK, top=GOLD), cap_mat=GOLD))
    return o

def build_thorns():
    """Four swept gold talons on each handguard shoulder (outside the sight
    line: |y| >= .06, top <= .52)."""
    th = []
    for i, x in enumerate((1.25, 1.37, 1.49, 1.61)):
        s = 1 - .08 * i
        path = [(x, .062, .428), (x - .045 * s, .080, .458), (x - .095 * s, .098, .482), (x - .140 * s, .110, .494)]
        th.append(sweep(path, (0, .70, 1), [.084 * s, .060 * s, .032 * s, .004], [.014, .012, .008, .002],
                        mats=[ACCENT, GOLD, GOLD, ACCENT, GOLD, GOLD]))
    o = join(P + "_Talons", th)
    mirror_apply(o)
    return o

def build_handguard():
    def fe(k=1.0):
        return [(.036 * k, .176), (.058 * k, .190), (.064 * k, .232), (.064 * k, .318), (.056 * k, .348), (.040 * k, .358)]
    st = [(1.06, ring(fe())), (1.64, ring(fe())), (1.68, ring(fe(.86)))]
    core = link(P + "_HandguardCore", loft(st, ring_mats([DARK, RED, RED, RED, DARK], bottom=DARK, top=DARK), cap_mat=DARK))
    out = [(1.06, .350), (1.62, .350), (1.70, .312), (1.70, .214), (1.655, .168), (1.10, .168), (1.06, .205)]
    pl = link(P + "_HandguardFace", solid_plate(out, .060, .080, ch=.0045, fold=((1.06, .26), (1.70, .27), .006, .10)))
    wins = []
    for xa, xb in ((1.115, 1.355), (1.395, 1.630)):
        wins.append(prism([(xa, .268), (xa + .075, .306), (xb - .010, .300), (xb, .284), (xb - .085, .226), (xa + .012, .232)],
                          .0625, .3, floor=RED, side=DARK))
    cut(pl, wins, rim=.0024)
    mirror_apply(pl)
    keel = [(.026, .150), (.046, .160), (.050, .176), (.030, .186)]
    kst = [(1.08, ring([(y * .8, z) for y, z in keel])), (1.11, ring(keel)), (1.60, ring(keel)), (1.66, ring([(y * .6, z + .012) for y, z in keel]))]
    kl = link(P + "_Keel", loft(kst, ring_mats([JADE, JADE, JADE], bottom=GOLD, top=JADE), cap_mat=GOLD))
    return core, pl, kl

def build_receiver_sides():
    out = [(.165, .266), (.845, .266), (.90, .262), (.948, .205), (.93, .150), (.825, .150), (.79, .104), (.49, .104),
           (.45, .150), (.215, .150), (.150, .205)]
    o = link(P + "_Carapace", solid_plate(out, .066, .086, ch=.0045, fold=((.16, .236), (.94, .246), .008, .14)))
    mirror_apply(o)
    cowl = [(-.176, .370), (.004, .370), (-.012, .30), (-.04, .192), (-.10, .168), (-.176, .178)]
    c = link(P + "_RearCowl", solid_plate(cowl, .066, .085, ch=.004, fold=((-.18, .262), (.0, .28), .006, .12)))
    mirror_apply(c)
    fr = [(.95, .344), (1.07, .344), (1.07, .176), (1.00, .162), (.955, .200)]
    f = link(P + "_FrontBlock", solid_plate(fr, .066, .084, ch=.004))
    mirror_apply(f)
    return o, c, f

def build_selector_ring():
    sel = bpy.data.objects["Vandal_FireSelector"]
    pts = [sel.matrix_world @ Vector(c) for c in sel.bound_box]
    cx = sum(p.x for p in pts) / 8; cz = sum(p.z for p in pts) / 8
    out = [(cx + .050 * math.cos(a), cz + .050 * math.sin(a)) for a in [math.radians(22.5 + 45 * i) for i in range(8)]]
    o = link(P + "_SelectorRing", solid_plate(out, .064, .0885, ch=.004, mat=ACCENT))
    mirror_apply(o)
    return o

def build_filigree(carapace, upper, hg):
    """Original gold line work: a long line under the channel ending in a
    scroll curl, a line along the upper shell that curls at the receiver
    step, and a short line on the handguard face."""
    lines = []
    curl = [(.86, .222), (.892, .208), (.900, .186), (.884, .170), (.866, .178), (.870, .194)]
    lines.append(inlay_line(P + "_FiligreeA", carapace, [(.20, .222), (.40, .228), (.60, .228), (.80, .224)] + curl, w=.0075, h=.0042))
    lines.append(inlay_line(P + "_FiligreeB", carapace, [(.52, .176), (.62, .132), (.74, .132), (.78, .150), (.765, .166)], w=.006, h=.004))
    up = [(.27, .424), (.50, .428), (.80, .428), (.88, .418), (.915, .392), (.910, .368), (.890, .362), (.880, .378)]
    lines.append(inlay_line(P + "_FiligreeC", upper, up, w=.007, h=.0045))
    up2 = [(1.10, .424), (1.40, .428), (1.60, .424), (1.66, .404)]
    lines.append(inlay_line(P + "_FiligreeD", upper, up2, w=.007, h=.0045))
    return [l for l in lines if l]

def build_stock():
    """One sculpted black-jade stock growing out of the receiver rear (front
    edge inside the receiver core), with a large open loop whose lips are
    gold, a gold scroll springing from the loop's lower lip, and a butt with
    a red-floored slit."""
    out = [(-.140, .405), (-.60, .412), (-1.10, .420), (-1.16, .420), (-1.215, .402), (-1.252, .352), (-1.240, .20),
           (-1.252, .05), (-1.240, -.10), (-1.215, -.176), (-1.130, -.176), (-1.00, -.120), (-.72, .040), (-.44, .160),
           (-.140, .182)]
    bm = solid_plate(out, -.060, .060, ch=.007)
    o = link(P + "_Stock", bm)
    loop = [(-.360, .330), (-1.030, .342), (-1.070, .310), (-1.070, -.010), (-1.030, -.060), (-.720, .110), (-.460, .225)]
    cut(o, [prism(loop, -.3, .3, floor=DARK, side=DARK, outer=DARK)], rim=.004)
    # the loop lips: gold chamfers come from the cut rim; add gold borders on the outer rim too
    slit = [(-1.150, .330), (-1.180, .342), (-1.205, .30), (-1.212, .02), (-1.198, -.10), (-1.178, -.13), (-1.165, -.08),
            (-1.170, .02), (-1.165, .29)]
    cut(o, [prism(slit, .049, .3, floor=RED, side=DARK), prism(slit, -.049, -.3, floor=RED, side=DARK)], rim=.003)
    cx, cz = -.80, .160
    sp = [(-.86, 0, -.010)]
    n = 22
    for i in range(n + 1):
        a_ = -1.95 + i / n * 2 * math.pi * 1.30
        r = .130 - .100 * i / n
        sp.append((cx + r * math.cos(a_), 0, cz + r * math.sin(a_)))
    w = [.030] + [.030 - .012 * i / n for i in range(n + 1)]
    t = [.018] + [.018 - .005 * i / n for i in range(n + 1)]
    scroll = link(P + "_Scroll", sweep(sp, (0, 1, 0), w, t, STRUT, [GOLD, ACCENT, ACCENT, ACCENT, ACCENT, ACCENT, ACCENT, GOLD]))
    gem = link(P + "_ScrollGem", loft3([[(cx + rr * math.cos(2 * math.pi * k / 8), yy, cz + rr * math.sin(2 * math.pi * k / 8)) for k in range(8)]
                                       for rr, yy in ((.026, -.022), (.030, -.016), (.030, .016), (.026, .022))], [RED] * 8, cap_mat=RED))
    border = [inlay_line(P + "_StockBorderTop", o, [(-.20, .388), (-.60, .395), (-1.10, .402), (-1.19, .380)], w=.007, h=.004),
              inlay_line(P + "_StockBorderLow", o, [(-.20, .200), (-.44, .180), (-.72, .060), (-1.00, -.100), (-1.12, -.155)], w=.007, h=.004)]
    return o, scroll, gem, border

def build_mag():
    back = [(.47, .199), (.462, .12), (.49, .031), (.513, -.027), (.536, -.085), (.565, -.141),
            (.593, -.197), (.626, -.252), (.658, -.306), (.694, -.36), (.700, -.380)]
    front = [(.995, -.322), (.93, -.268), (.887, -.217), (.851, -.164), (.817, -.11), (.788, -.054),
             (.759, .001), (.737, .06), (.717, .12), (.708, .199)]
    body = link(P + "_MagCrystal", solid_plate(back + [(.86, -.40), (.985, -.352)] + front, 0, .050, ch=.006, mat=RED,
                                               open_inner=True, fold=((.47, .10), (.90, -.37), .006, .10)), bone="Mag")
    mirror_apply(body, merge=True)
    shoe = [(.676, -.330), (.700, -.380), (.74, -.430), (.86, -.428), (.96, -.406), (1.030, -.366), (.998, -.318),
            (.94, -.352), (.86, -.372), (.76, -.370)]
    s = link(P + "_MagShoe", solid_plate(shoe, 0, .062, ch=.006, mat=ACCENT, open_inner=True), bone="Mag")
    mirror_apply(s, merge=True)
    spine = [(.460, .195), (.454, .12), (.482, .031), (.528, -.085), (.585, -.197), (.650, -.306), (.672, -.336),
             (.700, -.330), (.676, -.300), (.612, -.196), (.556, -.088), (.512, .028), (.486, .12), (.490, .195)]
    sp = link(P + "_MagSpine", solid_plate(spine, 0, .060, ch=.004, mat=ACCENT, open_inner=True), bone="Mag")
    mirror_apply(sp, merge=True)
    ln = inlay_line(P + "_MagLine", body, [(.735, .150), (.705, .040), (.660, -.080), (.640, -.170), (.700, -.280), (.790, -.330)],
                    w=.008, h=.006, bone="Mag")
    return body, s, sp, ln

def build_grip():
    """Solid matte-charcoal grip seated into the receiver: two folded planes,
    gold rim, three gold diagonal lines, and a gold cap cut from the grip's
    own outline so it wraps the base (no separate tray)."""
    hull = vandal_grip_outline(.003)
    o = link(P + "_Grip", solid_plate(hull, 0, .062, ch=.007, mat=GRIPM, open_inner=True,
                                      fold=((-.13, .15), (-.16, -.30), .006, .10)))
    mirror_apply(o, merge=True)
    lines = []
    ln = inlay_line(P + "_GripLine", o, [(-.110, .135), (-.128, .040), (-.140, -.060), (-.150, -.160), (-.158, -.240)], w=.008, h=.0035, mat=GOLD)
    if ln:
        lines.append(ln)
    capo = clip_poly(vandal_grip_outline(.005), 0.0, -1.0, -.274)          # z <= -.274
    c = link(P + "_GripCap", solid_plate(capo, 0, .065, ch=.004, mat=ACCENT, open_inner=True))
    mirror_apply(c, merge=True)
    return o, lines, c

def build_muzzle():
    prof = [(2.384, .048), (2.43, .054), (2.462, .050), (2.470, .040), (2.486, .050), (2.53, .046), (2.540, .036),
            (2.556, .044), (2.60, .038), (2.647, .026)]
    st = [[(x, r * math.cos(math.radians(30 + 60 * i)), .285 + r * math.sin(math.radians(30 + 60 * i))) for i in range(6)]
          for x, r in prof]
    o = link(P + "_Crown", loft3(st, [ACCENT] * 6, cap_mat=DARK))
    for p in o.data.polygons:
        xs = [o.data.vertices[i].co.x for i in p.vertices]
        if max(xs) - min(xs) < .012:
            p.material_index = GOLD
    return o

def build_collar():
    def sec(k):
        return [(.030 * k, .232), (.054 * k, .248), (.060 * k, .300), (.054 * k, .352), (.030 * k, .372)]
    st = [(1.700, ring(sec(.90))), (1.715, ring(sec(1.0))), (1.765, ring(sec(1.0))), (1.80, ring(sec(.76)))]
    return link(P + "_Collar", loft(st, ring_mats([ACCENT] * 4, bottom=ACCENT, top=ACCENT), cap_mat=GOLD))

def build_front_sight_cheeks():
    out = [(1.945, .224), (2.10, .224), (2.112, .252), (2.098, .352), (2.062, .374), (1.958, .374), (1.940, .330)]
    o = link(P + "_SightCheeks", solid_plate(out, .0575, .068, ch=.0035, fold=((1.94, .30), (2.11, .30), .003, .08)))
    mirror_apply(o)
    return o

# ------------------------------------------------------------------ build
vandal_hide_stock()
parts = {}
parts["core"] = vandal_core(DARK, P + "_Core")
parts["kept"] = vandal_retained(P)
parts["barrel"] = vandal_barrel(P, ACCENT)
parts["upper"] = build_upper()
parts["talons"] = build_thorns()
parts["hg"] = build_handguard()
parts["sides"] = build_receiver_sides()
parts["sel"] = build_selector_ring()
parts["fil"] = build_filigree(parts["sides"][0], parts["upper"], parts["hg"][1])
parts["seal"] = seal(P, parts["sides"][0], .300, .205, s=.068)
parts["stock"] = build_stock()
parts["mag"] = build_mag()
parts["grip"] = build_grip()
parts["lip"] = vandal_magwell_lip(P, ACCENT)
parts["crown"] = build_muzzle()
parts["collar"] = build_collar()
parts["fs"] = build_front_sight_cheeks()
for o in col.objects:
    flat_uv(o)

HARDWARE = list(VANDAL_KEEP)
STOCK_PARTS = list(VANDAL_HIDE)
_gold_table = [MATS[7], MATS[7], MATS[2], MATS[7], MATS[5], MATS[7], EXTRA["Neon"], EXTRA["Brass"]]
set_skin = vandal_set_skin_factory(lambda n: DARK_SKIN if n in ("Vandal_RearSight", "Vandal_FrontSight") else
                                   (_gold_table if n in ("Vandal_ChargingHandle", "Vandal_Trigger") else SLOT_SKIN))
set_skin(True)
result = {"objects": [(o.name, len(o.data.polygons)) for o in col.objects], "cut_failures": CUT_FAILURES}
