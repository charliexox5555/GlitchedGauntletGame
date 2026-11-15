"""Payload round two items (exec'd by model_payload_guns2.py)."""

def pl_stock(prefix, src, keep=lambda P: True, butt_w=.065, strap_x=None, window=True, clip=()):
    """Boxy white stock: carbon-floored window, graphite butt pad cut from the
    outline's rear, foil strap."""
    o, hull, ls = white_solid(prefix + "_Stock", src, keep, clip=clip)
    xs = [p[0] for p in hull]; zs = [p[1] for p in hull]
    x0, x1 = min(xs), max(xs)
    yh = max(abs(p.y) for p in comp_points(src, keep)) + .002
    out = [o]
    if window:
        win = clip_poly(clip_poly(hull_xz(src, keep, -.060), -1.0, 0.0, x1 - .20), 1.0, 0.0, -(x0 + .16))   # x0+.16 <= x <= x1-.20
        if len(win) >= 3:
            cut(o, [prism(win, yh - .006, .3, floor=CARB, side=REC), prism(win, -(yh - .006), -.3, floor=CARB, side=REC)], rim=.002)
    butt = clip_poly(hull_xz(src, keep, .006), -1.0, 0.0, x0 + butt_w)            # x <= x0 + butt_w
    if len(butt) >= 3:
        b = link(prefix + "_ButtPad", solid_plate(butt, 0, yh + .004, ch=.005, mat=GRA, open_inner=True))
        mirror_apply(b, merge=True)
        out.append(b)
    sx = strap_x if strap_x is not None else x0 + butt_w + .05
    out.append(strap(prefix + "_Strap", sx, sx + .03, o))
    return out, hull

def pl_handguard(prefix, src, keep=lambda P: True, clip=()):
    """Graphite handguard frame from the outline with a foil pillow set into
    each side."""
    o, hull = hull_solid(prefix + "_HandguardFrame", src, keep, mat=GRA, clip=clip, ch=.005)
    inner = hull_xz(src, keep, -.026)
    for a_, b_, c_ in clip:
        inner = clip_poly(inner, a_, b_, c_)
    xs = [p[0] for p in inner]; zs = [p[1] for p in inner]
    quad = [(min(xs) + .01, min(zs) + .01), (max(xs) - .01, min(zs) + .01), (max(xs) - .01, max(zs) - .01), (min(xs) + .01, max(zs) - .01)]
    pil = foil_pillow_on(prefix + "_FoilPillow", o, quad, nu=8, nv=3)
    return [o, pil], hull

def pl_grip(prefix, src, keep=lambda P: True, rake=(-.078, -.259)):
    o, hull = hull_solid(prefix + "_Grip", src, keep, mat=CARB, ch=.007)
    sq = grip_squares(prefix + "_GripSquares", o, hull_xz(src, keep, -.020), rake=rake)
    zs = [p[1] for p in hull]
    cap = clip_poly(hull_xz(src, keep, .006), 0.0, -1.0, min(zs) + (max(zs) - min(zs)) * .07)
    yh = max(abs(p.y) for p in comp_points(src, keep)) + .006
    c = None
    if len(cap) >= 3:
        c = link(prefix + "_GripCap", solid_plate(cap, 0, yh, ch=.004, mat=STL, open_inner=True))
        mirror_apply(c, merge=True)
    return [o, sq, c]

def pl_mag(prefix, src, keep_body, base_z, y_half=None):
    """Quilted white padded magazine with seam lines and a smoked-steel base."""
    o, hull = hull_solid(prefix + "_MagPad", src, keep_body, mat=PAD, bone="Mag", ch=.006, y_half=y_half, margin=.001)
    xs = [p[0] for p in hull]; zs = [p[1] for p in hull]
    rows = []
    for k in range(1, 5):
        z = base_z + (max(zs) - base_z) * k / 5
        rows.append([(min(xs) - .01, z), (max(xs) + .01, z - .01)])
    ql = quilt_lines(prefix + "_Quilt", o, rows, bone="Mag")
    base = clip_poly(hull_xz(src, keep_body, .005), 0.0, -1.0, base_z)
    yh = (y_half or max(abs(p.y) for p in comp_points(src, keep_body))) + .005
    b = None
    if len(base) >= 3:
        b = link(prefix + "_MagBase", solid_plate(base, 0, yh, ch=.005, mat=STL, open_inner=True), "Mag")
        mirror_apply(b, merge=True)
    return [o, ql, b]

def pl_receiver_trim(prefix, target, glow, stripe, inset_at=None, marks_at=None, bone="Root"):
    """Blue glow tube line, champagne pinstripe, the clipped foil inset with
    two blue marks, all seated on a kept receiver / housing."""
    out = []
    if glow:
        out.append(inlay_line(prefix + "_GlowTube", target, glow, w=.010, h=.003, mat=GLOW, bone=bone))
    if stripe:
        out.append(inlay_line(prefix + "_Pinstripe", target, stripe, w=.005, h=.0025, mat=FOIL, bone=bone))
    if inset_at:
        x, z, w, h = inset_at
        q = [(x, z), (x + w * .78, z), (x + w, z + h * .30), (x + w, z + h), (x, z + h)]
        ys = [surface_pt(target, a, b) for a, b in q]
        ys = [y for y in ys if y is not None]
        if ys:
            o = link(prefix + "_FoilInset", solid_plate(q, min(ys) - .002, max(ys) + .003, ch=.0015, mat=FOIL,
                                                         fold=((x + w * .35, z), (x + w * .55, z + h), .0015, w * .5)), bone)
            mirror_apply(o)
            out.append(o)
    if marks_at:
        x, z = marks_at
        for i in range(2):
            q = [(x + i * .016, z), (x + i * .016 + .007, z), (x + i * .016 + .007, z + .03), (x + i * .016, z + .03)]
            ys = [surface_pt(target, a, b) for a, b in q]
            ys = [y for y in ys if y is not None]
            if ys:
                o = link(prefix + "_BlueMark%d" % i, solid_plate(q, min(ys) - .002, max(ys) + .0025, ch=.001, mat=BLUE), bone)
                mirror_apply(o)
                out.append(o)
    return out

def pl_crown(prefix, src, x_end, zc, length=.05):
    r = part_r(src, x_end - .05, x_end, zc) + .004
    return crown(prefix + "_Crown", x_end - length, zc, r, length=length - .015)

WHITE_DARK_T = [MATS[WHITE], MATS[HOUS], MATS[WHITE], MATS[STL], MATS[CARB], MATS[BLUE], EXTRA["Neon"], EXTRA["Brass"]]

# ------------------------------------------------------------------ guns
def pl2_bulldog():
    p = {}
    HIDE = ["Bulldog_Handguard", "Bulldog_Grip", "Bulldog_Mag", "Bulldog_Pins", "Bulldog_Neon"]
    p["hg"], _ = pl_handguard("PLB", "Bulldog_Handguard")
    p["grip"] = pl_grip("PLB", "Bulldog_Grip", lambda P: min(q.x for q in P) < 0)
    p["tg"] = retain("Bulldog_Grip", lambda P: min(q.x for q in P) > .10, "PLB_TriggerGuard")
    p["mag"] = pl_mag("PLB", "Bulldog_Mag", lambda P: min(q.z for q in P) < 0, -.215)
    p["magtop"] = retain("Bulldog_Mag", lambda P: min(q.z for q in P) > .15, "PLB_MagTop", bone="Mag")
    rec = bpy.data.objects["Bulldog_Receiver"]
    p["trim"] = pl_receiver_trim("PLB", rec, [(-.40, .455), (.90, .455)], [(-.40, .300), (.36, .300)], None, None)
    stk = bpy.data.objects["Bulldog_Stock"]
    p["strim"] = pl_receiver_trim("PLBS", stk, None, None, (-1.15, .200, .15, .060), (-.96, .205))
    p["pad"] = pillow("PLB_CheekPad", quad_fn((-1.16, .380), (-.56, .390), (-.56, .452), (-1.16, .452)), 8, 2, .086, .012, PAD, edge=.5)
    p["strap"] = strap("PLB_Strap", -1.20, -1.17, "Bulldog_Stock")
    p["crown"] = pl_crown("PLB", "Bulldog_Barrel", 1.438, .361)
    tables = {"Bulldog_Receiver": WHITE_T, "Bulldog_Stock": WHITE_T, "Bulldog_Sights": [MATS[GRA]] * 6 + [EXTRA["Neon"], EXTRA["Brass"]],
              "Bulldog_Barrel": STEEL_T, "Bulldog_Bolt": STEEL_T, "Bulldog_ChargingHandle": STEEL_T, "Bulldog_CharmLoop": STEEL_T,
              "Bulldog_Trigger": BLUE_T, "Bulldog_FireSelector": BLUE_T}
    return p, HIDE, tables

def pl2_operator():
    p = {}
    HIDE = ["Operator_Handguard", "Operator_Grip", "Operator_Stock", "Operator_Magazine", "Operator_Neon"]
    p["hg"], _ = pl_handguard("PLO", "Operator_Handguard", lambda P: max(q.x for q in P) < 2.24)
    p["grip"] = pl_grip("PLO", "Operator_Grip")
    p["stock"], _ = pl_stock("PLO", "Operator_Stock", lambda P: max(q.x for q in P) < -.30 and min(q.z for q in P) < .32)
    p["front"] = white_solid("PLO_StockNose", "Operator_Stock", lambda P: min(q.x for q in P) > -.34)[0]
    p["cheekcore"] = white_solid("PLO_Cheek", "Operator_Stock", lambda P: min(q.z for q in P) > .32 and max(q.x for q in P) < -.40)[0]
    p["cheek"] = pillow("PLO_CheekPad", quad_fn((-.99, .338), (-.51, .338), (-.51, .418), (-.99, .418)), 8, 2, .064, .012, PAD, edge=.5)
    p["mag"] = pl_mag("PLO", "Operator_Magazine", lambda P: max(q.z for q in P) < .19 and max(abs(q.y) for q in P) > .045, -.068)
    p["magtop"] = retain("Operator_Magazine", lambda P: min(q.z for q in P) > .16, "PLO_MagTop", bone="Mag")
    rec = bpy.data.objects["Operator_Receiver"]
    p["trim"] = pl_receiver_trim("PLO", rec, [(.30, .195), (1.04, .195)], [(.30, .175), (.80, .175)], (.86, .250, .15, .06), (.80, .260))
    p["crown"] = pl_crown("PLO", "Operator_Barrel", 3.521, .385)
    scope_t = [MATS[WHITE], MATS[HOUS], MATS[WHITE], MATS[STL], MATS[CARB], MATS[BLUE], EXTRA["Neon"], EXTRA["Brass"]]
    tables = {"Operator_Receiver": WHITE_T, "Operator_Scope": scope_t, "Operator_Barrel": STEEL_T, "Operator_Bolt": STEEL_T,
              "Operator_CharmLoop": STEEL_T, "Operator_Trigger": BLUE_T}
    return p, HIDE, tables

def pl2_ares():
    p = {}
    HIDE = ["Ares_Handguard", "Ares_Grip", "Ares_Stock", "Ares_Pins", "Ares_Neon"]
    p["hg"], _ = pl_handguard("PLA", "Ares_Handguard")
    p["grip"] = pl_grip("PLA", "Ares_Grip")
    p["stock"], _ = pl_stock("PLA", "Ares_Stock")
    rec = bpy.data.objects["Ares_Receiver"]
    p["trim"] = pl_receiver_trim("PLA", rec, [(.20, .470), (1.10, .470)], [(.12, .190), (.50, .190)], (.86, .330, .14, .06), (.80, .340))
    p["crown"] = pl_crown("PLA", "Ares_Barrel", 3.075, .371)
    drum_t = [MATS[WHITE], MATS[STL], MATS[WHITE], MATS[STL], MATS[CARB], MATS[BLUE], EXTRA["Neon"], EXTRA["Brass"]]
    tables = {"Ares_Receiver": WHITE_T, "Ares_Drum": drum_t, "Ares_Sights": [MATS[GRA]] * 6 + [EXTRA["Neon"], EXTRA["Brass"]],
              "Ares_Barrel": STEEL_T, "Ares_Bolt": STEEL_T, "Ares_ChargingHandle": STEEL_T, "Ares_CharmLoop": STEEL_T,
              "Ares_Trigger": BLUE_T, "Ares_FireSelector": BLUE_T}
    return p, HIDE, tables

def pl2_odin():
    p = {}
    HIDE = ["Odin_Grip", "Odin_Stock", "Odin_Pins", "Odin_Neon"]
    p["grip"] = pl_grip("PLD", "Odin_Grip")
    p["stock"], _ = pl_stock("PLD", "Odin_Stock")
    rec = bpy.data.objects["Odin_Receiver"]
    p["trim"] = pl_receiver_trim("PLD", rec, [(-.10, .540), (.76, .540)], [(.10, .180), (.70, .180)], (-.20, .205, .14, .06), (-.04, .212))
    box = bpy.data.objects["Odin_AmmoBox"]
    p["boxpillow"] = foil_pillow_on("PLD_BoxFoil", box, [(.70, -.30), (1.20, -.30), (1.20, -.04), (.70, -.04)], bone="AmmoBox")
    p["crown"] = pl_crown("PLD", "Odin_Barrel", 3.364, .371, length=.06)
    box_t = [MATS[WHITE], MATS[WHITE], MATS[GRA], MATS[STL], MATS[CARB], MATS[BLUE], EXTRA["Neon"], EXTRA["Brass"]]
    tables = {"Odin_Receiver": WHITE_T, "Odin_FeedCover": WHITE_DARK_T, "Odin_AmmoBox": box_t, "Odin_Sights": [MATS[GRA]] * 6 + [EXTRA["Neon"], EXTRA["Brass"]],
              "Odin_Barrel": STEEL_T, "Odin_Bolt": STEEL_T, "Odin_ChargingHandle": STEEL_T, "Odin_CharmLoop": STEEL_T, "Odin_Trigger": BLUE_T}
    return p, HIDE, tables

def pl2_ghost():
    p = {}
    HIDE = ["Ghost_Suppressor", "Ghost_Pins", "Ghost_SlideNeon"]
    p["core"] = retain("Ghost_Suppressor", lambda P: max(q.x for q in P) < 1.14, "PLG_BarrelHardware")
    sup, suph, ls = white_solid("PLG_Suppressor", "Ghost_Suppressor", lambda P: min(q.x for q in P) > 1.10, clip=((1.0, 0.0, -1.132),),
                                seams=[[(1.50, .200), (1.50, .395)], [(1.80, .200), (1.80, .395)]])
    p["sup"] = [sup] + ls
    p["break"] = strap("PLG_BreakRing", 1.140, 1.175, sup, mat=GRA, grow=.004)
    p["crown"] = crown("PLG_Crown", 2.050, .296, .066, length=.04)
    slide = bpy.data.objects["Ghost_Slide"]
    p["trim"] = pl_receiver_trim("PLG", slide, [(-.10, .300), (.90, .300)], None, None, (.70, .330), bone="Slide")
    grip = bpy.data.objects["Ghost_Grip"]
    p["squares"] = grip_squares("PLG_GripSquares", grip, clip_poly(hull_xz("Ghost_Grip", lambda P: True, -.024), -1.0, 0.0, .160), rake=(-.06, -.26), zlim=(-.36, .08))
    tables = {"Ghost_Slide": WHITE_T, "Ghost_Frame": CARB_T, "Ghost_Grip": CARB_T, "Ghost_Mag": STEEL_T,
              "Ghost_Trigger": BLUE_T, "Ghost_SlideCatch": STEEL_T, "Ghost_MagRelease": BLUE_T, "Ghost_CharmLoop": STEEL_T}
    return p, HIDE, tables

def pl2_classic():
    p = {}
    HIDE = ["Classic_Pins", "Classic_SlideNeon"]
    slide = bpy.data.objects["Classic_Slide"]
    p["trim"] = pl_receiver_trim("PLC", slide, [(-.20, .360), (.90, .360)], [(-.20, .440), (.60, .440)], None, (.70, .400), bone="Slide")
    grip = bpy.data.objects["Classic_Grip"]
    p["squares"] = grip_squares("PLC_GripSquares", grip, clip_poly(hull_xz("Classic_Grip", lambda P: True, -.024), -1.0, 0.0, .140), rake=(-.06, -.26), zlim=(-.26, .10))
    tables = {"Classic_Slide": WHITE_T, "Classic_Frame": CARB_T, "Classic_Grip": CARB_T, "Classic_Magazine": STEEL_T, "Classic_Barrel": STEEL_T,
              "Classic_Trigger": BLUE_T, "Classic_SlideCatch": STEEL_T, "Classic_MagRelease": BLUE_T, "Classic_CharmLoop": STEEL_T,
              "Classic_MagNeon": BLUE_T}
    return p, HIDE, tables

def pl2_stinger():
    p = {}
    HIDE = ["Stinger_Stock", "Stinger_Handguard", "Stinger_Pins", "Stinger_Neon"]
    p["stock"], _ = pl_stock("PLS", "Stinger_Stock", window=True)
    p["hg"], _ = pl_handguard("PLS", "Stinger_Handguard")
    rec = bpy.data.objects["Stinger_Receiver"]
    p["trim"] = pl_receiver_trim("PLS", rec, [(.28, .372), (.76, .372)], [(-.45, .200), (-.12, .200)], (-.46, .240, .13, .05), (-.30, .250))
    grip = bpy.data.objects["Stinger_Grip"]
    p["squares"] = grip_squares("PLS_GripSquares", grip, hull_xz("Stinger_Grip", lambda P: min(q.x for q in P) < 0, -.022), zlim=(-.19, .12))
    p["crown"] = pl_crown("PLS", "Stinger_Barrel", 1.140, .294)
    tables = {"Stinger_Receiver": WHITE_T, "Stinger_Grip": CARB_T, "Stinger_Mag": STEEL_T, "Stinger_Sights": [MATS[GRA]] * 6 + [EXTRA["Neon"], EXTRA["Brass"]],
              "Stinger_Barrel": STEEL_T, "Stinger_Bolt": STEEL_T, "Stinger_ChargingHandle": STEEL_T, "Stinger_CharmLoop": STEEL_T,
              "Stinger_Trigger": BLUE_T, "Stinger_FireSelector": BLUE_T}
    return p, HIDE, tables

_PL2.update({"Bulldog": pl2_bulldog, "Operator": pl2_operator, "Ares": pl2_ares, "Odin": pl2_odin,
             "Ghost": pl2_ghost, "Classic": pl2_classic, "Stinger": pl2_stinger})
