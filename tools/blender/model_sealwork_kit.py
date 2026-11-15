"""Sealwork line kit + guns. Exec after model_giltfold_kit.py (fold_plate,
surface_y) with the item's stock file open and ITEM_KEY set.
  0 ARM black jade (polished stone)   4 INSET vermilion seal (jewel; optional drift)
  1 EDGE warm gold (plate rims = the gold frame lines)
  2 CORE near-black   3 GASKET groove   5 GRIP charcoal   6 STEEL smoked alloy
  7 ACCENT gold (collars, settings)    8 PANEL dark charcoal green
Brief (vault/02 Art/Skins/Sealwork/concept.md): carved black-jade faces with
soft rounded highlights, paired sparse gold borders, one clipped-corner red
seal with an original offset groove in a stepped gold setting, gold collars,
large dark areas so the gold breaks read."""

def jade():
    m, nt, b = pbsdf("SW1 Black Jade", "202825", 0.0, .24, .4)
    b.inputs["Coat Roughness"].default_value = .14
    tc = nt.nodes.new("ShaderNodeTexCoord"); nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 4.0; nz.inputs["Detail"].default_value = 3.0
    nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
    rp = nt.nodes.new("ShaderNodeValToRGB")
    rp.color_ramp.elements[0].color = (*_lin("1A211E"), 1); rp.color_ramp.elements[1].color = (*_lin("2A3530"), 1)
    nt.links.new(nz.outputs["Fac"], rp.inputs[0]); nt.links.new(rp.outputs[0], b.inputs["Base Color"])
    return m

def vermilion():
    """Solid jewel crimson: a deep garnet body with brighter marbled veins,
    a soft satin coat (a mirror coat made the magazine read hollow / pink)."""
    m, nt, b = pbsdf("SW1 Vermilion Seal", "8F222D", 0.0, .30, .18)
    b.inputs["Coat Roughness"].default_value = .10
    b.inputs["Specular IOR Level"].default_value = .30
    N = nt.nodes; L = nt.links.new
    tc = N.new("ShaderNodeTexCoord"); nz = N.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 7.0; nz.inputs["Detail"].default_value = 4.0; nz.inputs["Distortion"].default_value = 1.2
    L(tc.outputs["Object"], nz.inputs["Vector"])
    rp = N.new("ShaderNodeValToRGB")
    rp.color_ramp.elements[0].position = .32; rp.color_ramp.elements[0].color = (*_lin("3C0510"), 1)
    rp.color_ramp.elements[1].position = .70; rp.color_ramp.elements[1].color = (*_lin("A3172A"), 1)
    L(nz.outputs["Fac"], rp.inputs[0]); L(rp.outputs[0], b.inputs["Base Color"])
    b.inputs["Emission Color"].default_value = (*_lin("4A0410"), 1); b.inputs["Emission Strength"].default_value = .30
    return m

def gold(name, rough):
    """Polished warm gold with a faint low-frequency roughness drift."""
    m, nt, b = pbsdf(name, "D2A04A", 1.0, rough)
    N = nt.nodes; L = nt.links.new
    tc = N.new("ShaderNodeTexCoord"); nz = N.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 9.0; nz.inputs["Detail"].default_value = 2.0
    L(tc.outputs["Object"], nz.inputs["Vector"])
    mr = N.new("ShaderNodeMapRange"); mr.inputs["To Min"].default_value = rough - .06; mr.inputs["To Max"].default_value = rough + .08
    L(nz.outputs["Fac"], mr.inputs["Value"]); L(mr.outputs[0], b.inputs["Roughness"])
    return m

MATS = [
    jade(),                                                   # 0
    gold("SW1 Gold Line", .22),                               # 1
    pbsdf("SW1 Near Black", "141816", .2, .4)[0],             # 2
    pbsdf("SW1 Groove", "0C0E0D", 0.0, .6)[0],                # 3
    vermilion(),                                              # 4
    pbsdf("SW1 Charcoal Grip", "1E211E", 0.0, .78)[0],         # 5
    pbsdf("SW1 Smoked Alloy", "67635A", .9, .35)[0],          # 6
    gold("SW1 Gold Fitting", .18),                            # 7
    pbsdf("SW1 Charcoal Green", "333D38", 0.0, .3, .3)[0],    # 8
]
ACCENT, PANEL, INSET_IDX = 7, 8, 4
CHAMBER_MAT = MATS[4].name
EXTRA = {"Neon": pbsdf("SW1 Indicator", "D9524C", 0.0, .3)[0], "Brass": pbsdf("SW1 Brass", "B08A4A", 1.0, .3)[0]}
SLOT_SKIN = [MATS[0], MATS[8], MATS[2], MATS[6], MATS[5], MATS[7], EXTRA["Neon"], EXTRA["Brass"]]
DARK_SKIN = [MATS[2], MATS[8], MATS[2], MATS[6], MATS[5], MATS[7], EXTRA["Neon"], EXTRA["Brass"]]

def jade_plate(name, outline, y0, y1, crease, amp=.004, reach=.10, bone="Root", **kw):
    """Black-jade face; the gold rim chamfer is the border line; the second
    plane is charcoal green (soft change, the polished highlight does the rest)."""
    return fold_plate(name, outline, y0, y1, crease, amp=amp, reach=reach, lower=PANEL, upper=0, bone=bone, ch=.0035, **kw)

def seal(prefix, target, x, z, s=.05, bone="Root", mirror=True):
    """Clipped-corner vermilion seal with an original offset groove, in a
    stepped gold setting, seated on the target plate (mirrored)."""
    def clipped(cx, cz, half, clip):
        return [(cx - half + clip, cz - half), (cx + half, cz - half), (cx + half, cz + half - clip),
                (cx + half - clip, cz + half), (cx - half, cz + half), (cx - half, cz - half + clip)]
    y = surface_y(target, x, z)
    if y is None:
        return []
    outs = []
    a = link(prefix + "_SealSet1", solid_plate(clipped(x, z, s * .62, s * .2), y - .003, y + .004, ch=.0015, mat=ACCENT), bone)
    b = link(prefix + "_SealSet2", solid_plate(clipped(x, z, s * .52, s * .17), y + .003, y + .0075, ch=.0012, mat=ACCENT), bone)
    r = link(prefix + "_Seal", solid_plate(clipped(x, z, s * .42, s * .14), y + .0065, y + .0105, ch=.001, mat=INSET_IDX), bone)
    g = [(x - s * .30, z + s * .06), (x + s * .20, z + s * .06), (x + s * .26, z + s * .12), (x + s * .20, z + s * .18),
         (x - s * .30, z + s * .18)]
    cut(r, [prism(g, y + .0085, .5, floor=GASKET, side=GASKET)], rim=0)
    for o in (a, b, r):
        if mirror:
            mirror_apply(o)
        outs.append(o)
    return outs

def collar(name, x0, x1, zc, ry, rz, bone="Root", n=12):
    """Narrow gold collar ring (elliptical section) around a part."""
    st = [[(x, ry * math.cos(2 * math.pi * (i + .5) / n), zc + rz * math.sin(2 * math.pi * (i + .5) / n)) for i in range(n)]
          for x in (x0, x0 + .004, x1 - .004, x1)]
    for k in (0, 3):
        st[k] = [(p[0], p[1] * .96, zc + (p[2] - zc) * .96) for p in st[k]]
    return link(name, loft3(st, [ACCENT] * n, cap_mat=ACCENT), bone)

def _r_of(name, xmin, zc):
    o = bpy.data.objects[name]; P = [o.matrix_world @ v.co for v in o.data.vertices]
    S = [q for q in P if q.x > xmin]
    return max(abs(q.y) for q in S), max(abs(q.z - zc) for q in S)

def sw_marshal():
    p = []
    rec = jade_plate("SWM_ReceiverFace", [(.20, .245), (.86, .245), (.885, .22), (.88, .095), (.84, .085), (.24, .085), (.20, .11)],
                     .066, .076, ((.20, .17), (.89, .21)))
    fe = jade_plate("SWM_ForeEndFace", [(.895, .200), (1.88, .200), (1.90, .17), (1.885, .0), (1.85, -.010), (.93, -.010), (.895, .03)],
                    .068, .077, ((.89, .14), (1.90, .06)), reach=.14)
    st = jade_plate("SWM_StockFace", [(-.05, .195), (-1.15, .06), (-1.19, .02), (-1.17, -.26), (-.95, -.24), (-.10, .03), (-.04, .10)],
                    .058, .074, ((-.05, .12), (-1.18, -.07)), reach=.14)
    p += [rec, fe, st]
    p += seal("SWM", rec, .30, .175, s=.06)
    ry, rz = _r_of("Marshal_Scope", 1.0, .333)
    p.append(collar("SWM_ScopeCollar", 1.00, 1.03, .333, ry + .004, rz + .004))
    return p

def sw_vandal():
    p = []
    up = jade_plate("SWV_UpperFace", [(-.17, .428), (1.05, .428), (1.062, .41), (1.05, .350), (-.15, .350), (-.172, .37)],
                    .092, .102, ((-.17, .40), (1.06, .37)), reach=.07)
    lo = jade_plate("SWV_LowerFace", [(.12, .276), (1.03, .276), (1.062, .25), (1.04, .152), (.80, .152), (.47, .155), (.15, .15), (.12, .19)],
                    .090, .100, ((.12, .21), (1.06, .25)), reach=.10)
    hg = jade_plate("SWV_Handguard", [(1.05, .410), (1.64, .410), (1.685, .37), (1.68, .21), (1.64, .172), (1.09, .172), (1.05, .20)],
                    .095, .101, ((1.05, .33), (1.69, .28)), reach=.14)
    p += [up, lo, hg]
    p += seal("SWV", lo, .32, .215, s=.065)               # behind the magazine well
    base = [(.715, -.39), (.86, -.395), (.88, -.375), (.86, -.36), (.72, -.355)]
    p.append(link("SWV_MagAccent", solid_plate(base, .062, .068, ch=.0015, mat=INSET_IDX), "Mag"))
    mirror_apply(p[-1])
    return p

def sw_guardian():
    p = []
    # long side plane, gold border tapering toward the front
    hg = jade_plate("SWG_SideFace", [(.93, .40), (2.20, .40), (2.30, .34), (2.30, .28), (2.22, .22), (.97, .20), (.93, .24)],
                    .088, .097, ((.93, .33), (2.30, .30)), reach=.12)
    rc = jade_plate("SWG_ReceiverFace", [(-.006, .404), (.165, .404), (.165, .30), (.12, .262), (-.006, .262)],
                    .086, .094, ((-.01, .35), (.17, .33)), reach=.07)
    p += [hg, rc]
    p += seal("SWG", rc, .07, .33, s=.055)                # short vermilion insert below the rear profile
    return p

def sw_shorty():
    p = []
    fr = jade_plate("SWH_FramePlate", [(-.08, .330), (.50, .330), (.52, .31), (.52, .175), (.48, .170), (-.05, .170), (-.085, .20)],
                    .090, .098, ((-.08, .27), (.52, .23)))
    p.append(fr)
    p += seal("SWH", fr, .22, .25, s=.06)
    bars = bpy.data.objects["Shorty_Barrels"]
    P = [bars.matrix_world @ v.co for v in bars.data.vertices]
    S = [q for q in P if 1.25 < q.x < 1.40]
    zc = (max(q.z for q in S) + min(q.z for q in S)) / 2
    p.append(collar("SWH_Collar", 1.28, 1.31, zc, max(abs(q.y) for q in S) + .004, (max(q.z for q in S) - zc) + .004, bone="Barrels"))
    return p

def sw_sheriff():
    p = []
    # fixed face behind the cylinder (cylinder from x .317; hammer is central and |y| < .019)
    # the speedloader and rounds come in from behind at the cylinder-axis height
    # (z ~.08-.30) on both sides: the seal's fixed face is the upper rear band
    # behind the cylinder, above that path
    rear = jade_plate("SWS_RearFace", [(.00, .356), (.296, .356), (.305, .345), (.305, .318), (.29, .312), (.01, .312), (.00, .32)],
                      .064, .071, ((.0, .34), (.305, .33)), reach=.03)
    top = jade_plate("SWS_TopStrap", [(.30, .372), (.70, .372), (.72, .362), (.70, .348), (.31, .348)],
                     .046, .062, ((.30, .365), (.72, .36)), reach=.03)
    p += [rear, top]
    p += seal("SWS", rear, .16, .334, s=.042)
    ry, rz = _r_of("Sheriff_Barrel", 1.30, .278)
    p.append(collar("SWS_FrontBand", 1.40, 1.425, .278, ry + .004, rz + .004))
    return p

_SW_BUILD = {"Marshal": sw_marshal, "Vandal": sw_vandal, "Guardian": sw_guardian, "Shorty": sw_shorty, "Sheriff": sw_sheriff}
parts = {"all": [x for x in _SW_BUILD[ITEM_KEY]() if x is not None]}
for o in col.objects:
    flat_uv(o)

HARDWARE = [o.name for o in bpy.data.objects if o.type == "MESH" and o.name.startswith(ITEM_KEY + "_") and o.parent is not None
            and o.parent.name == ITEM_KEY + "_Rig" and not o.name.endswith(("ScopeLens", "Lens"))]
_DARK = {"Marshal": ("Marshal_Lever",), "Vandal": ("Vandal_Grip", "Vandal_Rail"), "Guardian": ("Guardian_Grip",),
         "Shorty": ("Shorty_Grip",), "Sheriff": ("Sheriff_Grip",)}[ITEM_KEY]
STOCK_PARTS = []

def set_skin(on):
    for n in HARDWARE:
        o = bpy.data.objects[n]
        table = DARK_SKIN if n in _DARK else SLOT_SKIN
        for i, sl in enumerate(o.material_slots):
            if i < 8:
                sl.material = table[i] if on else bpy.data.materials[STOCK_SET[i]]
    col.hide_render = not on
    col.hide_viewport = not on

set_skin(True)
result = {"objects": len(col.objects), "cut_failures": CUT_FAILURES}
