"""Payload line kit + 8 guns. Exec after model_giltfold_kit.py (fold_plate,
surface_y) with the item's stock file open and ITEM_KEY set.
  0 ARM flight white enamel       4 INSET champagne thermal foil (folded, broad highlights)
  1 EDGE cool grey bevel rim      5 GRIP textured charcoal   6 STEEL smoked steel
  2 CORE graphite   3 GASKET recess wall   7 ACCENT mission blue   8 PANEL cool grey housing
Brief (vault/02 Art/Skins/Payload/concept.md): aerospace flight hardware;
white enamel over gently bevelled service panels, black insulation and
grips, one rectangular foil inset with a clipped corner and two short blue
alignment marks beside it, small blue fittings, static finishes, sparse
original markings. No Knife-slot variant (the stock Knife stays)."""

def enamel():
    m, nt, b = pbsdf("PL1 Flight White", "E2E7ED", 0.0, .32, .3)
    return m

def thermal_foil():
    """Champagne foil: metallic with a coarse crumple so a few broad
    highlights break across it (geometry adds two folds per inset)."""
    m, nt, b = pbsdf("PL1 Thermal Foil", "C89B49", 1.0, .18)
    tc = nt.nodes.new("ShaderNodeTexCoord"); vo = nt.nodes.new("ShaderNodeTexVoronoi")
    vo.inputs["Scale"].default_value = 24.0
    nt.links.new(tc.outputs["Object"], vo.inputs["Vector"])
    bump = nt.nodes.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = .12
    nt.links.new(vo.outputs["Distance"], bump.inputs["Height"]); nt.links.new(bump.outputs[0], b.inputs["Normal"])
    rp = nt.nodes.new("ShaderNodeValToRGB")
    rp.color_ramp.elements[0].color = (*_lin("B88A3C"), 1); rp.color_ramp.elements[1].color = (*_lin("D9B064"), 1)
    nt.links.new(vo.outputs["Distance"], rp.inputs[0]); nt.links.new(rp.outputs[0], b.inputs["Base Color"])
    return m

MATS = [
    enamel(),                                                  # 0
    pbsdf("PL1 Bevel Grey", "A8B4C2", .2, .35)[0],             # 1
    pbsdf("PL1 Graphite", "20262E", .1, .6)[0],                # 2
    pbsdf("PL1 Recess", "14181E", 0.0, .6)[0],                 # 3
    thermal_foil(),                                            # 4
    pbsdf("PL1 Charcoal Grip", "303743", 0.0, .75)[0],         # 5
    pbsdf("PL1 Smoked Steel", "6C7784", .9, .32)[0],           # 6
    pbsdf("PL1 Mission Blue", "2E67B2", .3, .35)[0],           # 7
    pbsdf("PL1 Cool Grey Housing", "A8B4C2", 0.0, .45)[0],     # 8
]
ACCENT, PANEL, INSET_IDX = 7, 8, 4
CHAMBER_MAT = MATS[4].name
EXTRA = {"Neon": pbsdf("PL1 Indicator", "8FC4FF", 0.0, .3)[0], "Brass": pbsdf("PL1 Casing", "9C8A5E", 1.0, .3)[0]}
SLOT_SKIN = [MATS[0], MATS[8], MATS[2], MATS[6], MATS[5], MATS[7], EXTRA["Neon"], EXTRA["Brass"]]
DARK_SKIN = [MATS[2], MATS[2], MATS[2], MATS[6], MATS[5], MATS[7], EXTRA["Neon"], EXTRA["Brass"]]
WHITE_SKIN = [MATS[0], MATS[0], MATS[2], MATS[6], MATS[5], MATS[7], EXTRA["Neon"], EXTRA["Brass"]]

def panel(name, outline, y0, y1, crease, amp=.004, reach=.10, bone="Root", lower=PANEL, **kw):
    """White enamel service panel, cool-grey bevel rim, grey second plane."""
    return fold_plate(name, outline, y0, y1, crease, amp=amp, reach=reach, lower=lower, upper=0, bone=bone, ch=.004, **kw)

def foil_inset(prefix, target, x, z, w=.16, h=.07, bone="Root"):
    """Rectangular recess with one clipped corner holding folded foil (two
    folds -> three broad facets), cut into both sides of a mirrored panel."""
    c = min(w, h) * .32
    rect = [(x, z), (x + w - c, z), (x + w, z + c), (x + w, z + h), (x, z + h)]
    y = surface_y(target, x + w / 2, z + h / 2)
    if y is None:
        return []
    fy = y - .0045          # shallow: these panels are thin over the stock surface
    cut(target, [prism(rect, fy, .5, floor=GASKET, side=GASKET), prism(rect, -fy, -.5, floor=GASKET, side=GASKET)], rim=.0015)
    inner = [(x + .004, z + .004), (x + w - c - .002, z + .004), (x + w - .004, z + c + .002), (x + w - .004, z + h - .004),
             (x + .004, z + h - .004)]
    bm = solid_plate(inner, fy - .0008, fy + .0016, ch=.0006, mat=INSET_IDX,
                     fold=((x + w * .35, z), (x + w * .55, z + h), .0025, w * .5))
    o = link(prefix + "_Foil", bm, bone)
    mirror_apply(o)
    return [o]

def blue_marks(prefix, target, x, z, bone="Root", vertical=True):
    """Two short mission-blue alignment marks seated on the white panel."""
    outs = []
    for i in range(2):
        if vertical:
            pts = [(x + i * .016, z), (x + i * .016 + .007, z), (x + i * .016 + .007, z + .03), (x + i * .016, z + .03)]
        else:
            pts = [(x, z + i * .016), (x + .03, z + i * .016), (x + .03, z + i * .016 + .007), (x, z + i * .016 + .007)]
        ys = [surface_y(target, px, pz) for px, pz in pts]
        ys = [yy for yy in ys if yy is not None]
        if not ys:
            continue
        o = link(f"{prefix}_Blue{i}", solid_plate(pts, min(ys) - .003, max(ys) + .002, ch=.0006, mat=ACCENT), bone)
        mirror_apply(o)
        outs.append(o)
    return outs

def ring_band(name, x0, x1, zc, r, mat, bone="Root", n=12):
    st = [[(x, r * math.cos(2 * math.pi * (i + .5) / n), zc + r * math.sin(2 * math.pi * (i + .5) / n)) for i in range(n)] for x in (x0, x1)]
    return link(name, loft3(st, [mat] * n, cap_mat=mat), bone)

# ------------------------------------------------------------------- guns
def pl_bulldog():
    p = []
    fwd = panel("PLB_FwdShoulder", [(.53, .50), (1.02, .50), (1.044, .47), (1.04, .30), (1.00, .29), (.56, .29), (.53, .32)],
                .092, .101, ((.53, .42), (1.044, .38)))
    rear = panel("PLB_RearShoulder", [(-1.20, .47), (-.60, .47), (-.595, .44), (-.60, .25), (-.64, .24), (-1.18, .24), (-1.205, .28)],
                 .088, .097, ((-1.205, .40), (-.595, .36)))
    p += [fwd, rear]
    p += foil_inset("PLB", fwd, .70, .36, w=.16, h=.07)
    p += blue_marks("PLB", fwd, .66, .37)
    return p

def pl_ghost():
    p = []
    sl = panel("PLG_SlideCap", [(-.20, .385), (1.10, .385), (1.12, .36), (1.115, .245), (1.09, .236), (-.18, .236), (-.205, .26)],
               .062, .071, ((-.205, .33), (1.12, .30)), bone="Slide")
    p.append(sl)
    p += foil_inset("PLG", sl, .96, .30, w=.11, h=.045, bone="Slide")
    p += blue_marks("PLG", sl, .55, .30, bone="Slide")
    sup = bpy.data.objects["Ghost_Suppressor"]
    P = [sup.matrix_world @ v.co for v in sup.data.vertices]
    r = max(abs(q.y) for q in P if q.x > 1.2)
    p.append(ring_band("PLG_SuppressorBreak", 1.135, 1.17, .296, r + .003, 2))
    return p

def pl_vandal():
    p = []
    up = panel("PLV_UpperShell", [(-.17, .428), (1.05, .428), (1.062, .41), (1.05, .350), (-.15, .350), (-.172, .37)],
               .092, .102, ((-.17, .40), (1.06, .37)), reach=.07)
    lo = panel("PLV_LowerShell", [(.12, .276), (1.03, .276), (1.062, .25), (1.04, .152), (.80, .152), (.47, .155), (.15, .15), (.12, .19)],
               .090, .100, ((.12, .21), (1.06, .25)))
    hg = panel("PLV_Handguard", [(1.05, .410), (1.64, .410), (1.685, .37), (1.68, .21), (1.64, .172), (1.09, .172), (1.05, .20)],
               .095, .101, ((1.05, .33), (1.69, .28)), reach=.14)
    p += [up, lo, hg]
    p += foil_inset("PLV", hg, 1.22, .24, w=.20, h=.08)
    p += blue_marks("PLV", hg, 1.17, .25)
    trim = [(.715, -.39), (.86, -.395), (.88, -.375), (.86, -.36), (.72, -.355)]
    o = link("PLV_MagTrim", solid_plate(trim, .062, .068, ch=.0015, mat=0), "Mag"); mirror_apply(o); p.append(o)
    return p

def pl_operator():
    p = []
    rf = panel("PLO_ReceiverShell", [(.42, .300), (1.075, .300), (1.09, .268), (1.075, .148), (.52, .148), (.42, .20)],
               .088, .099, ((.42, .225), (1.09, .225)))
    hg = panel("PLO_ForeEnd", [(1.10, .446), (2.20, .446), (2.25, .40), (2.24, .17), (2.19, .145), (1.13, .145), (1.10, .18)],
               .088, .097, ((1.10, .26), (2.25, .24)), lower=2, reach=.16)
    p += [rf, hg]
    p += foil_inset("PLO", hg, 1.45, .18, w=.36, h=.05)
    p += blue_marks("PLO", hg, 1.40, .19)
    return p

def pl_ares():
    p = []
    # starts past the receiver front block (x .87-1.14, |y| .10) so no face sits coplanar with it
    sh = panel("PLA_Shoulder", [(1.15, .46), (1.98, .46), (2.0, .43), (1.99, .20), (1.95, .19), (1.19, .21), (1.15, .25)],
               .092, .101, ((1.15, .33), (2.0, .30)), lower=2, reach=.14)
    p.append(sh)
    p += foil_inset("PLA", sh, 1.30, .34, w=.20, h=.075)
    p += blue_marks("PLA", sh, 1.25, .35)
    return p

def pl_odin():
    p = []
    rear = panel("PLD_RearPanel", [(-.15, .565), (.72, .565), (.765, .54), (.765, .392), (-.10, .392), (-.155, .43)],
                 .100, .110, ((-.15, .50), (.765, .46)), reach=.08)
    lo = panel("PLD_LowerFace", [(-.15, .285), (.78, .285), (.80, .26), (.78, .165), (-.10, .165), (-.155, .20)],
               .100, .109, ((-.15, .245), (.80, .21)), lower=2, reach=.08)
    box = panel("PLD_BoxFace", [(.62, .09), (1.36, .09), (1.38, .06), (1.37, -.32), (1.33, -.345), (.64, -.345), (.61, -.31)],
                .160, .168, ((.61, -.20), (1.38, -.22)), lower=2, bone="AmmoBox", reach=.16)
    p += [rear, lo, box]
    p += foil_inset("PLD", rear, .48, .44, w=.18, h=.07)
    p += blue_marks("PLD", rear, .43, .45)
    return p

def pl_classic():
    p = []
    cap = panel("PLC_SlidePanel", [(-.255, .462), (.955, .462), (.985, .44), (.985, .318), (.965, .300), (-.235, .300), (-.258, .33)],
                .066, .078, ((-.25, .40), (.99, .36)), bone="Slide")
    p.append(cap)
    p += foil_inset("PLC", cap, .62, .35, w=.10, h=.045, bone="Slide")
    p += blue_marks("PLC", cap, .58, .355, bone="Slide")
    return p

def pl_stinger():
    p = []
    hg = panel("PLS_ForeEnd", [(.47, .262), (.82, .262), (.825, .24), (.80, .11), (.50, .11), (.47, .14)],
               .084, .092, ((.47, .20), (.83, .19)), lower=2)
    p.append(hg)
    p += foil_inset("PLS", hg, .50, .19, w=.13, h=.05)
    p += blue_marks("PLS", hg, .67, .20)
    return p

_PL_BUILD = {"Bulldog": pl_bulldog, "Ghost": pl_ghost, "Vandal": pl_vandal, "Operator": pl_operator, "Ares": pl_ares,
             "Odin": pl_odin, "Classic": pl_classic, "Stinger": pl_stinger}
parts = {"all": [x for x in _PL_BUILD[ITEM_KEY]() if x is not None]}
for o in col.objects:
    flat_uv(o)

HARDWARE = [o.name for o in bpy.data.objects if o.type == "MESH" and o.name.startswith(ITEM_KEY + "_") and o.parent is not None
            and o.parent.name == ITEM_KEY + "_Rig" and not o.name.endswith(("ScopeLens", "Lens"))]
_DARK = {"Bulldog": ("Bulldog_Handguard", "Bulldog_Grip", "Bulldog_Mag"), "Ghost": ("Ghost_Frame", "Ghost_Grip", "Ghost_Mag"),
         "Vandal": ("Vandal_Grip", "Vandal_Mag", "Vandal_Rail"), "Operator": ("Operator_Grip", "Operator_Magazine"),
         "Ares": ("Ares_Grip", "Ares_Drum"), "Odin": ("Odin_Grip", "Odin_FeedBelt"),
         "Classic": ("Classic_Frame", "Classic_Grip", "Classic_Magazine"), "Stinger": ("Stinger_Handguard", "Stinger_Grip", "Stinger_Mag")}[ITEM_KEY]
_WHITE = ("Ghost_Suppressor", "Operator_Scope", "Ghost_Slide", "Classic_Slide")
STOCK_PARTS = []
for _nm, _loc in (("Ghost", .418), ("Classic", .512)):
    if ITEM_KEY == _nm and f"MFR_{_nm}_Aim" not in bpy.data.objects:
        _e = bpy.data.objects.new(f"MFR_{_nm}_Aim", None); sc.collection.objects.link(_e); _e.location = (0.0, 0, _loc)

def set_skin(on):
    for n in HARDWARE:
        o = bpy.data.objects[n]
        table = DARK_SKIN if n in _DARK else WHITE_SKIN if n in _WHITE else SLOT_SKIN
        if n == "Operator_Scope":
            # white housing (the tube is in the Dark slot), blue on the panel slot
            table = [MATS[0], MATS[7], MATS[0], MATS[6], MATS[5], MATS[7], EXTRA["Neon"], EXTRA["Brass"]]
        if n == "Ghost_Suppressor":
            table = [MATS[0], MATS[0], MATS[0], MATS[6], MATS[5], MATS[7], EXTRA["Neon"], EXTRA["Brass"]]
        for i, sl in enumerate(o.material_slots):
            if i < 8:
                sl.material = table[i] if on else bpy.data.materials[STOCK_SET[i]]
    col.hide_render = not on
    col.hide_viewport = not on

set_skin(True)
result = {"objects": len(col.objects), "cut_failures": CUT_FAILURES}
