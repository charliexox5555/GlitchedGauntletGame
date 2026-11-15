"""Sealwork round two: Marshal, Guardian, Shorty, Sheriff as full sculpts in
the language of the approved Sealwork Vandal v02 (black jade, gold frame
lines on every rim, gold talons, gold-framed leaf windows onto vermilion,
red crystal magazines in gold shoes, carved grips, gold scrolls, the clipped
seal). Exec after model_giltfold_kit.py and model_vandal_shell_base.py (run_sfg
KIT chain), stock item open, ITEM_KEY set. Stock body parts are rebuilt from
their own side outlines (hull_solid) so grips, sights, magazine travel and
moving parts keep their stock fit; parts with moving-part channels (receivers,
revolver frame) stay stock in the line finishes and get carved cladding."""

_k = open(os.path.join(TB, "model_sealwork_kit.py")).read()
exec(_k[:_k.index("def sw_marshal")])          # Sealwork palette + seal()

JADE, GOLD, DARK, GROOVE, RED, GRIPM, STEELM = 0, 1, 2, 3, 4, 5, 6
GOLD_TABLE = [MATS[7], MATS[7], MATS[2], MATS[7], MATS[5], MATS[7], EXTRA["Neon"], EXTRA["Brass"]]
JADE_TABLE = [MATS[0], MATS[8], MATS[2], MATS[7], MATS[5], MATS[7], EXTRA["Neon"], EXTRA["Brass"]]

def talons(prefix, bases, bone="Root", out=(0, .55, 1), size=1.0):
    """Swept gold talons: bases = [(x, y, z, length, rise)], mirrored."""
    th = []
    for x, y, z, ln, rise in bases:
        path = [(x, y, z), (x - ln * .32, y + .012, z + rise * .55), (x - ln * .68, y + .022, z + rise * .88), (x - ln, y + .026, z + rise)]
        th.append(sweep(path, out, [.070 * size, .050 * size, .027 * size, .004], [.012, .010, .007, .002],
                        mats=[ACCENT, GOLD, GOLD, ACCENT, GOLD, GOLD]))
    o = join(prefix + "_Talons", th, bone)
    mirror_apply(o)
    return o

def leaf_windows(obj, wins, y_floor):
    cut(obj, [prism(w, y_floor, .3, floor=RED, side=DARK) for w in wins], rim=.0024)

def leaf(xa, xb, zc, h):
    return [(xa, zc), (xa + (xb - xa) * .30, zc + h / 2), (xb - (xb - xa) * .05, zc + h * .40), (xb, zc + h * .1),
            (xb - (xb - xa) * .32, zc - h / 2), (xa + (xb - xa) * .05, zc - h * .38)]

def sw_grip(prefix, src, keep=lambda P: True, y_half=None, cap_z=None, gem=None, bone="Root"):
    """Carved black grip: matte charcoal from the stock grip's own outline,
    gold rim, one gold line along its fold, gold cap cut from its outline."""
    o, hull = hull_solid(prefix + "_Grip", src, keep, y_half=y_half, mat=GRIPM, margin=.003, bone=bone, ch=.007)
    zs = [p[1] for p in hull]; xs = [p[0] for p in hull]
    z0, z1 = min(zs), max(zs)
    # line along the back third of the grip
    inner = hull_xz(src, keep, -.022)
    cx_, cz_ = outline_center(inner)
    rear = [q for q in inner if q[0] < cx_]
    rear.sort(key=lambda q: -q[1])
    lines = []
    if len(rear) >= 2:
        pts_ = [(x + .004, z) for x, z in rear if z > z0 + (z1 - z0) * .16]
        if len(pts_) >= 2:
            lines.append(inlay_line(prefix + "_GripLine", o, pts_, w=.008, h=.0035, mat=GOLD, bone=bone))
    if cap_z is None:
        cap_z = z0 + (z1 - z0) * .10
    cap = clip_poly(hull_xz(src, keep, .006), 0.0, -1.0, cap_z)
    c = None
    if len(cap) >= 3:
        yh = (y_half or max(abs(p.y) for p in comp_points(src, keep))) + .004
        c = link(prefix + "_GripCap", solid_plate(cap, 0, yh, ch=.004, mat=ACCENT, open_inner=True), bone)
        mirror_apply(c, merge=True)
    g = None
    if gem:
        gx, gz = gem
        y = surface_pt(o, gx, gz)
        if y is not None:
            g = seal(prefix + "Gem", o, gx, gz, s=.050)
    return o, c, g, lines

def crystal_mag(prefix, src, keep_body, y_half=.056, shoe_z=None, spine=True):
    """Red crystal magazine from the stock magazine's outline, gold shoe cut
    from its outline, gold spine on the back edge."""
    body, hull = hull_solid(prefix + "_MagCrystal", src, keep_body, y_half=y_half, mat=RED, margin=.001, bone="Mag", ch=.006,
                            rim=GOLD)
    zs = [p[1] for p in hull]
    if shoe_z is None:
        shoe_z = min(zs) + (max(zs) - min(zs)) * .12
    shoe = clip_poly(hull_xz(src, keep_body, .004), 0.0, -1.0, shoe_z)
    s = link(prefix + "_MagShoe", solid_plate(shoe, 0, y_half + .006, ch=.005, mat=ACCENT, open_inner=True), "Mag")
    mirror_apply(s, merge=True)
    return body, s, hull

def looped_stock(prefix, src, keep=lambda P: True, clip=(), inset=.075, open_x=None, y_half=None, scroll=True, through=True, relief=None):
    """Black-jade stock from the stock's outline with a gold-lipped loop
    window (through, or a red relief panel when the stock geometry stays
    inside) and a gold scroll springing from the loop's lower lip."""
    o, hull = hull_solid(prefix + "_Stock", src, keep, y_half=y_half, mat=JADE, margin=.003, clip=clip, ch=.007)
    loop = hull_xz(src, keep, -inset)
    for a, b, c in clip:
        loop = clip_poly(loop, a, b, c)
    if open_x is not None:
        loop = clip_poly(loop, -1.0, 0.0, open_x)                   # x <= open_x
    parts_ = [o]
    if len(loop) >= 3:
        if through:
            cut(o, [prism(loop, -.3, .3, floor=DARK, side=DARK, outer=DARK)], rim=.004)
        else:
            yh = y_half or max(abs(p.y) for p in comp_points(src, keep))
            rf = DARK if relief is None else relief
            cut(o, [prism(loop, yh - .005, .3, floor=rf, side=DARK), prism(loop, -(yh - .005), -.3, floor=rf, side=DARK)], rim=.003)
        if scroll:
            xs = [p[0] for p in loop]; zs = [p[1] for p in loop]
            cx = (min(xs) + max(xs)) / 2; cz = (min(zs) + max(zs)) / 2
            r0 = min(max(xs) - min(xs), max(zs) - min(zs)) * .40
            lowz = min(zs)
            yv = 0.0 if through else (y_half or max(abs(p.y) for p in comp_points(src, keep))) - .002
            sp = [(cx - r0 * .25, yv, lowz - .004)]
            n = 22
            for i in range(n + 1):
                a = -1.95 + i / n * 2 * math.pi * 1.30
                r = r0 - (r0 - .028) * i / n
                sp.append((cx + r * math.cos(a), yv, cz + r * math.sin(a)))
            w = [.026] + [.026 - .010 * i / n for i in range(n + 1)]
            t = [.016 if through else .007] + [(.016 if through else .007) - .003 * i / n for i in range(n + 1)]
            sc = link(prefix + "_Scroll", sweep(sp, (0, 1, 0), w, t, STRUT, [GOLD, ACCENT, ACCENT, ACCENT, ACCENT, ACCENT, ACCENT, GOLD]))
            if not through:
                mirror_apply(sc)
            gem = link(prefix + "_ScrollGem", loft3([[(cx + rr * math.cos(2 * math.pi * k / 8), yy, cz + rr * math.sin(2 * math.pi * k / 8)) for k in range(8)]
                                                     for rr, yy in ((.024, yv - .018), (.028, yv - .013), (.028, yv + .013), (.024, yv + .018))],
                                                    [RED] * 8, cap_mat=RED))
            if not through:
                mirror_apply(gem)
            parts_ += [sc, gem]
    return parts_, hull

def jade_cladding(name, target_name, outline, y0, y1, crease, bone="Root"):
    """Carved black-jade plate (gold rim chamfer) on a kept stock part."""
    bm = solid_plate(outline, y0, y1, ch=.004, mat=JADE, fold=(crease[0], crease[1], .006, .10))
    o = link(name, bm, bone)
    mirror_apply(o)
    return o

def gold_band(name, x0, x1, src, zc, bone="Root", grow=.004, n=12):
    """Narrow gold collar fitted to a part's section between x0 and x1."""
    o = bpy.data.objects[src]
    P = [o.matrix_world @ v.co for v in o.data.vertices]
    S = [q for q in P if x0 - .02 <= q.x <= x1 + .02]
    ry = max(abs(q.y) for q in S) + grow
    rz = max(abs(q.z - zc) for q in S) + grow
    st = [[(x, ry * math.cos(2 * math.pi * (i + .5) / n), zc + rz * math.sin(2 * math.pi * (i + .5) / n)) for i in range(n)]
          for x in (x0, x0 + .004, x1 - .004, x1)]
    for k in (0, 3):
        st[k] = [(p[0], p[1] * .96, zc + (p[2] - zc) * .96) for p in st[k]]
    return link(name, loft3(st, [ACCENT] * n, cap_mat=ACCENT), bone)

# ------------------------------------------------------------------ guns
def sw2_guardian():
    p = {}
    HIDE = ["Guardian_Handguard", "Guardian_Stock", "Guardian_Grip", "Guardian_Mag", "Guardian_Pins", "Guardian_Neon"]
    hg, hgh = hull_solid("SWG_Handguard", "Guardian_Handguard", mat=JADE, ch=.006, fold=((1.12, .31), (2.36, .33), .007, .10))
    leaf_windows(hg, [leaf(1.24, 1.56, .300, .060), leaf(1.62, 1.94, .300, .060)], .086)
    p["hg"] = hg
    p["talons"] = talons("SWG", [(2.30, .056, .420, .13, .055), (2.16, .056, .420, .12, .050), (2.02, .056, .420, .11, .045)])
    p["stock"] = looped_stock("SWG", "Guardian_Stock", inset=.080, open_x=-.42)
    p["grip"] = sw_grip("SWG", "Guardian_Grip")
    p["mag"] = crystal_mag("SWG", "Guardian_Mag", lambda P: max(p_.z for p_ in P) < .23 and min(p_.z for p_ in P) < .0, y_half=.058)
    p["magtop"] = retain("Guardian_Mag", lambda P: min(q.z for q in P) > .20, "SWG_MagTop", bone="Mag")
    plate = [(-.06, .186), (.196, .186), (.212, .226), (.390, .226), (.390, .148), (.490, .148), (.490, .226), (.860, .226), (.876, .200), (.860, .052),
             (.820, .040), (-.040, .040), (-.066, .070)]
    p["clad"] = jade_cladding("SWG_LowerPlate", "Guardian_Receiver", plate, .080, .093, ((-.06, .14), (.88, .12)))
    p["seal"] = seal("SWG", p["clad"], .200, .120, s=.064)
    p["fil"] = [inlay_line("SWG_FiligreeA", p["clad"], [(-.03, .168), (.22, .168), (.36, .205)], w=.007, h=.004),
                inlay_line("SWG_FiligreeB", p["clad"], [(.52, .205), (.84, .205), (.855, .180), (.84, .160), (.822, .170)], w=.007, h=.004),
                inlay_line("SWG_FiligreeC", hg, [(1.16, .398), (2.10, .404), (2.30, .392)], w=.007, h=.004)]
    tables = {n: JADE_TABLE for n in ("Guardian_Receiver",)}
    tables.update({n: GOLD_TABLE for n in ("Guardian_Barrel", "Guardian_ChargingHandle", "Guardian_Trigger", "Guardian_FireSelector",
                                           "Guardian_BoltCatch", "Guardian_CharmLoop")})
    tables.update({n: DARK_SKIN for n in ("Guardian_Sights", "Guardian_Bolt")})
    return p, HIDE, tables

def sw2_marshal():
    p = {}
    HIDE = ["Marshal_ForeEnd", "Marshal_Pins", "Marshal_Neon"]
    fe, feh = hull_solid("SWM_ForeEnd", "Marshal_ForeEnd", mat=JADE, ch=.006, fold=((.89, .10), (1.91, .08), .007, .10))
    leaf_windows(fe, [leaf(1.00, 1.36, .095, .070), leaf(1.44, 1.80, .095, .070)], .066)
    p["fe"] = fe
    p["talons"] = talons("SWM", [(1.86, .052, .196, .13, .050), (1.72, .052, .200, .12, .046), (1.58, .052, .203, .11, .042)])
    # carved butt enclosing the stock's rear (the wrist stays stock in jade): red relief panel + scroll
    p["stock"] = looped_stock("SWM", "Marshal_Stock", clip=((-1.0, 0.0, -.15),), inset=.105, open_x=-.36, y_half=.074, through=False)
    rec = [(.20, .245), (.86, .245), (.885, .22), (.88, .095), (.84, .085), (.24, .085), (.20, .11)]
    p["clad"] = jade_cladding("SWM_ReceiverPlate", "Marshal_Receiver", rec, .066, .078, ((.20, .17), (.89, .21)))
    p["seal"] = seal("SWM", p["clad"], .300, .175, s=.062)
    p["fil"] = [inlay_line("SWM_FiligreeA", p["clad"], [(.42, .205), (.80, .205), (.835, .185), (.82, .165), (.80, .175)], w=.007, h=.004),
                inlay_line("SWM_FiligreeB", fe, [(.95, .190), (1.86, .186)], w=.007, h=.004)]
    p["collars"] = [gold_band("SWM_ScopeCollarA", 1.02, 1.05, "Marshal_Scope", .333), gold_band("SWM_ScopeCollarB", .30, .33, "Marshal_Scope", .333)]
    tables = {"Marshal_Stock": JADE_TABLE, "Marshal_Receiver": JADE_TABLE,
              "Marshal_Scope": [MATS[0], MATS[8], MATS[0], MATS[7], MATS[5], MATS[7], EXTRA["Neon"], EXTRA["Brass"]]}
    tables.update({n: GOLD_TABLE for n in ("Marshal_Barrel", "Marshal_Lever", "Marshal_Hammer", "Marshal_Trigger", "Marshal_CharmLoop", "Marshal_Bolt")})
    return p, HIDE, tables

def sw2_shorty():
    """Frame and grip stay stock in Sealwork finishes (their cut-outs hold the
    barrels, latch, shells and trigger) with carved cladding; the barrels get
    a new jade shroud riding the Barrels bone (leaf windows, talons, collar)."""
    p = {}
    HIDE = ["Shorty_Barrels", "Shorty_Neon"]
    p["kept"] = retain("Shorty_Barrels", lambda P: max(q.x for q in P) < .66 or min(q.x for q in P) > .98, "SWH_BarrelHardware", bone="Barrels")
    sh, shh = hull_solid("SWH_Shroud", "Shorty_Barrels", lambda P: .63 < min(q.x for q in P) < .66 and max(q.x for q in P) > 1.0,
                         mat=JADE, ch=.006, bone="Barrels", fold=((.64, .16), (1.25, .14), .007, .10))
    leaf_windows(sh, [leaf(.70, .96, .150, .060), leaf(1.00, 1.20, .120, .050)], .100)
    p["shroud"] = sh
    plate = [(-.08, .330), (.50, .330), (.52, .31), (.52, .175), (.48, .170), (-.05, .170), (-.085, .20)]
    p["clad"] = jade_cladding("SWH_FramePlate", "Shorty_Frame", plate, .090, .100, ((-.08, .27), (.52, .23)))
    p["seal"] = seal("SWH", p["clad"], .200, .250, s=.066)
    p["fil"] = [inlay_line("SWH_FiligreeA", p["clad"], [(-.06, .310), (.40, .310), (.49, .292), (.505, .262), (.49, .240), (.47, .252)], w=.007, h=.004),
                inlay_line("SWH_FiligreeB", sh, [(.68, .300), (1.20, .292)], w=.007, h=.004, bone="Barrels")]
    p["talons"] = talons("SWH", [(1.22, .046, .300, .12, .044), (1.06, .046, .306, .11, .040)], bone="Barrels")
    p["collar"] = gold_band("SWH_Collar", 1.28, 1.31, "Shorty_Barrels", .260, bone="Barrels")
    grip_t = [MATS[5], MATS[7], MATS[5], MATS[7], MATS[5], MATS[7], EXTRA["Neon"], EXTRA["Brass"]]
    tables = {"Shorty_Frame": JADE_TABLE, "Shorty_Grip": grip_t, "Shorty_BarrelNeon": GOLD_TABLE}
    tables.update({n: GOLD_TABLE for n in ("Shorty_BreechLatch", "Shorty_Trigger", "Shorty_CharmLoop")})
    return p, HIDE, tables

def sw2_sheriff():
    p = {}
    HIDE = ["Sheriff_Barrel", "Sheriff_Grip", "Sheriff_Neon", "Sheriff_Pins"]
    br, brh = hull_solid("SWS_Barrel", "Sheriff_Barrel", mat=JADE, ch=.006, fold=((.76, .26), (1.50, .27), .006, .08))
    leaf_windows(br, [leaf(.86, 1.20, .170, .060)], .064)
    p["barrel"] = br
    p["talons"] = talons("SWS", [(1.22, .046, .340, .11, .036), (1.08, .046, .344, .10, .032)])
    p["grip"] = sw_grip("SWS", "Sheriff_Grip", cap_z=-.395, gem=(-.140, -.180))
    rear = [(.00, .356), (.296, .356), (.305, .345), (.305, .318), (.29, .312), (.01, .312), (.00, .32)]
    p["clad"] = jade_cladding("SWS_RearPlate", "Sheriff_Frame", rear, .064, .071, ((.0, .34), (.305, .33)))
    p["seal"] = seal("SWS", p["clad"], .160, .334, s=.042)
    tables = {"Sheriff_Frame": JADE_TABLE, "Sheriff_Cylinder": [MATS[0], MATS[8], MATS[0], MATS[7], MATS[5], MATS[7], EXTRA["Neon"], EXTRA["Brass"]]}
    tables.update({n: GOLD_TABLE for n in ("Sheriff_Hammer", "Sheriff_Trigger", "Sheriff_Crane", "Sheriff_CylinderRelease", "Sheriff_EjectorRod",
                                           "Sheriff_CharmLoop")})
    tables.update({"Sheriff_Sights": DARK_SKIN})
    return p, HIDE, tables

_SW2 = {"Guardian": sw2_guardian, "Marshal": sw2_marshal, "Shorty": sw2_shorty, "Sheriff": sw2_sheriff}
parts, _hide, _tables = _SW2[ITEM_KEY]()
for n in _hide:
    o = bpy.data.objects.get(n)
    if o:
        o.hide_render = True; o.hide_set(True)
for o in col.objects:
    flat_uv(o)
HARDWARE = [n for n in _tables if n in bpy.data.objects]
STOCK_PARTS = list(_hide)
set_skin = gun_set_skin_factory(_hide, _tables)
set_skin(True)
ensure_aim(ITEM_KEY)
result = {"objects": [(o.name, len(o.data.polygons)) for o in col.objects], "cut_failures": CUT_FAILURES}
