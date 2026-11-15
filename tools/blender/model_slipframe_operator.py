"""Slipframe Operator. Exec after model_slipframe_kit.py (stock Operator open).
Stock receiver (bolt channel, magwell) and scope are kept and re-finished;
the bolt (handle on -Y) slides back to x -.26, so nothing new sits in its
path. The scope gets faceted bevel collars outside the tube (optic view,
reticle and zoom untouched)."""

def build_receiver_faces():
    """Blue faces on both receiver sides below the bolt band, from ahead of
    the handle's travel (x > .30) to the handguard; the inlay runs along
    their lower edge and stops at a solid grey break at x .40."""
    out = [(.42, .300), (1.075, .300), (1.09, .268), (1.075, .148), (.52, .148), (.42, .20)]
    f = face_plate("SFO_ReceiverFace", out, .088, .100, fold=((.42, .225), (1.09, .225), .004, .09))
    band = [(.40, .148), (1.08, .148), (1.09, .136), (1.07, .118), (.50, .118), (.40, .14)]
    strip = [(.53, .127), (1.03, .127), (1.05, .133), (1.03, .140), (.53, .140), (.52, .133)]
    b = inlay_band("SFO_InsetBand", band, .086, .097, strip, .0905)
    sh = [(.30, .30), (.42, .30), (.44, .22), (.42, .118), (.33, .118), (.30, .20)]
    s = link("SFO_Shoulder", solid_plate(sh, .086, .102, ch=.006, mat=ARM, fold=((.30, .21), (.44, .21), .004, .08)))
    mirror_apply(s)
    return f, b, s

def build_handguard():
    sh = sf_loft("SFO_HandguardShell", [(1.085, .088, .150, .448), (1.12, .090, .142, .450), (2.15, .090, .142, .450),
                                         (2.23, .082, .160, .440), (2.27, .066, .200, .420)], end_scale=(1.0, .78))
    out = [(1.13, .424), (2.15, .424), (2.215, .37), (2.20, .20), (2.15, .176), (1.17, .176), (1.13, .22)]
    face = face_plate("SFO_HandguardFace", out, .086, .099, vents=raked_vents(1.74, 5, .075, .215, .385),
                      vent_floor=.090, fold=((1.12, .30), (2.22, .30), .004, .12))
    band = [(1.12, .176), (2.19, .176), (2.205, .162), (2.17, .146), (1.15, .146), (1.12, .16)]
    strip = [(1.17, .155), (2.12, .155), (2.145, .1615), (2.12, .168), (1.17, .168), (1.16, .1615)]
    b = inlay_band("SFO_HandguardInset", band, .084, .095, strip, .0885)
    return sh, face, b

def build_scope_collars():
    """Faceted blue bevel collars on the ocular and objective bells (outside
    the stock tube) with polished rims: the line's bevel echoed on the optic."""
    zc = .602
    def ring_at(x0, x1, r_in, r_out, n=10):
        st = []
        for x, r in ((x0, r_in), (x0 + .012, r_out), (x1 - .012, r_out), (x1, r_in)):
            st.append([(x, r * math.cos(2 * math.pi * (i + .5) / n), zc + r * math.sin(2 * math.pi * (i + .5) / n)) for i in range(n)])
        return loft3(st, [ACCENT] * n, caps=(True, True), cap_mat=EDGE)
    sc_o = bpy.data.objects["Operator_Scope"]
    P = [sc_o.matrix_world @ v.co for v in sc_o.data.vertices]
    def radius_at(x, w=.02):
        S = [p for p in P if abs(p.x - x) < w]
        return max(((p.y) ** 2 + (p.z - zc) ** 2) ** .5 for p in S) if S else .1
    rear_r = radius_at(.02); front_r = radius_at(1.48)
    a = ring_at(-.02, .07, rear_r - .004, rear_r + .010)
    b = ring_at(1.40, 1.50, front_r - .004, front_r + .010)
    o = join("SFO_ScopeCollars", [a, b])
    return o, (round(rear_r, 3), round(front_r, 3))

def build_mag():
    out = [(.455, .085), (.805, .085), (.812, -.045), (.79, -.066), (.47, -.066), (.45, -.045)]
    o = link("SFO_MagFace", solid_plate(out, .060, .0705, ch=.003, mat=ACCENT), "Mag")
    strip = [(.74, .07), (.76, .07), (.763, -.05), (.737, -.05)]
    cut(o, [prism(strip, .0635, .4, floor=INSET_IDX, side=GASKET)], rim=.0015)
    mirror_apply(o)
    return o

def build_stock():
    # top strut stays under the bolt line (z < .33) until x -.40, then rises
    # into the cheek riser behind the bolt's furthest travel (x -.26)
    top_path = [(x, 0, z) for x, z in ((.055, .235), (-.05, .240), (-.25, .250), (-.42, .300), (-.60, .372), (-.85, .378), (-1.09, .372))]
    top_w = [.15, .14, .13, .10, .095, .095, .10]
    top_t = [.066, .066, .064, .060, .058, .058, .060]
    butt = [(-1.078, .384), (-1.17, .384), (-1.28, .36), (-1.32, .30), (-1.32, -.16), (-1.29, -.217),
            (-1.13, -.217), (-1.078, -.18)]
    face = [(-1.10, .34), (-1.25, .34), (-1.285, .29), (-1.285, -.13), (-1.26, -.18), (-1.10, -.18)]
    return frame_stock("SFO", top_path, top_w, top_t, (-.30, 0, .18), (-1.09, 0, -.15), butt, .080, face)

parts = {}
parts["rfaces"] = build_receiver_faces()
parts["hg"] = build_handguard()
parts["scope"] = build_scope_collars()
parts["mag"] = build_mag()
parts["stock"] = build_stock()
for o in col.objects:
    flat_uv(o)

HARDWARE = ["Operator_Receiver", "Operator_Barrel", "Operator_Grip", "Operator_Scope", "Operator_ScopeLens", "Operator_CharmLoop",
            "Operator_Magazine", "Operator_Bolt", "Operator_Trigger"]
STOCK_PARTS = ["Operator_Neon", "Operator_Handguard", "Operator_Stock"]

def set_skin(on):
    for n in HARDWARE:
        o = bpy.data.objects[n]
        if n == "Operator_ScopeLens":
            continue                      # stock optic glass
        for i, sl in enumerate(o.material_slots):
            if i < 8:
                sl.material = SLOT_SKIN[i] if on else bpy.data.materials[STOCK_SET[i]]
    for n in STOCK_PARTS:
        o = bpy.data.objects[n]; o.hide_render = on; o.hide_set(on)
    col.hide_render = not on
    col.hide_viewport = not on

set_skin(True)
result = {"objects": [(o.name, len(o.data.polygons)) for o in col.objects], "scope_r": parts["scope"][1]}
