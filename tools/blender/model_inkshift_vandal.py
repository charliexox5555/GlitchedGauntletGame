"""Inkshift Vandal v02: full comic-mecha shell (stock Vandal open). Exec
after model_giltfold_kit.py and model_vandal_shell_base.py (run_sfg KIT chain).

Owner 2026-11-14: v01 (plates over the stock gun) read as a reskin. v02 is a
new body in the line's comic-mecha language at the quality bar of the Orion
reference, original panels and marks: a stepped white upper with an inked
step ledge, the broken cyan accent (one long + two short segments) glowing in
a dark channel, armour-blue lower plates over indigo shadow planes, vermilion
fins and tabs, flat comic highlight shapes, an angular open-frame stock, an
armour magazine with a white front plate and a cyan base strip, an indigo
grip with a white side plate, a stepped muzzle shroud. Black ink outlines are
inverted hulls (flipped, inflated copies): they read as comic line work in
Blender (backface culling) and in Roblox (MeshParts cull back faces).
Painted finish: soft brush streaks in the white and blue (static).
Fit, channel and moving parts per model_vandal_shell_base."""

_k = open(os.path.join(TB, "model_inkshift_kit.py")).read()
exec(_k)                                         # Inkshift palette + cyan_accent()

def painted(name, hexc, rough=.5, streak=.07):
    """Flat comic colour with soft brush streaks (stretched noise along the
    gun) and a little value drift, like a painted cel finish."""
    m, nt, b = pbsdf(name, hexc, 0.0, rough)
    b.inputs["Specular IOR Level"].default_value = .25
    N = nt.nodes; L = nt.links.new
    tc = N.new("ShaderNodeTexCoord"); mp = N.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (2.5, 14.0, 14.0)
    L(tc.outputs["Object"], mp.inputs["Vector"])
    nz = N.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 3.0; nz.inputs["Detail"].default_value = 3.0
    L(mp.outputs["Vector"], nz.inputs["Vector"])
    rp = N.new("ShaderNodeValToRGB")
    c = _lin(hexc)
    rp.color_ramp.elements[0].position = .35; rp.color_ramp.elements[0].color = (*[v * (1 - streak) for v in c], 1)
    rp.color_ramp.elements[1].position = .65; rp.color_ramp.elements[1].color = (*[min(1, v * (1 + streak)) for v in c], 1)
    L(nz.outputs["Fac"], rp.inputs[0]); L(rp.outputs[0], b.inputs["Base Color"])
    return m

def ink_material():
    m, nt, b = pbsdf("IK2 Ink Outline", "0B0E14", 0.0, .9)
    b.inputs["Specular IOR Level"].default_value = 0.0
    m.use_backface_culling = True
    return m

MATS[0] = painted("IK2 Painted White", "DFE4E9", .55, .06)
MATS[7] = painted("IK2 Painted Armour Blue", "3B57B0", .45, .08)
MATS[8] = painted("IK2 Painted Indigo", "2C3270", .5, .08)
MATS.append(ink_material())                     # 11
WHITE, INKL, CHAR, WALL, CYAN, GRAPH, SLATE, BLUE, INDG, VERM, HILITE, OUTL = range(12)
SLOT_SKIN = [MATS[0], MATS[7], MATS[2], MATS[6], MATS[5], MATS[9], MATS[4], EXTRA["Brass"]]
DARK_SKIN = [MATS[8], MATS[7], MATS[2], MATS[6], MATS[5], MATS[9], MATS[4], EXTRA["Brass"]]
P = "IKV"

def ink_outline(obj, t=.0045, name=None, taper=None):
    """Inverted hull: copy, push every vertex out along its averaged normal,
    flip the faces. Same bone as the source. `taper(world_co) -> 0..1` scales
    the push per vertex (a blade tip: a full-width hull blunts the point into
    a round dark blob, owner 2026-11-14)."""
    bm = bmesh.new(); bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.normal_update()
    # outward faces only: the inner sides of side plates face the gun's centre
    # and their outline would bulge into channels and the magazine well
    M = obj.matrix_world
    inward = [f for f in bm.faces if abs((M @ f.calc_center_median()).y) > .02 and
              f.normal.y * (1 if (M @ f.calc_center_median()).y > 0 else -1) < -.3]
    bmesh.ops.delete(bm, geom=inward, context="FACES")
    bm.normal_update()
    for v in bm.verts:
        k = taper(obj.matrix_world @ v.co) if taper else 1.0
        v.co = v.co + v.normal * t * k
    for f in bm.faces:
        f.material_index = OUTL
    bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    for v in bm.verts:
        v.co = obj.matrix_world @ v.co
    return link(name or obj.name + "_Ink", bm, obj.parent_bone or "Root")

def zt_top(x):
    if x <= .16: return .408
    if x <= .26: return .408 + (x - .16) / .10 * .050
    if x <= 1.60: return .458
    return .458 - (x - 1.60) / .12 * .050

def build_upper():
    """Stepped white upper: an inked step ledge part-way down each side
    (white above, blue band below), lower lip in ink."""
    xs = [-.178, -.17, .0, .16, .26, .55, .86, .90, 1.06, 1.30, 1.50, 1.60, 1.66, 1.72]
    st = []
    for x in xs:
        zt = zt_top(x); zb = .356 if x < 1.06 else .350
        k = 1 - max(0.0, (x - 1.60) / .12) * .30
        zs = zt - .044
        half = [(.060 * k, zb), (.088 * k, zb), (.094 * k, zb + .008), (.094 * k, zs), (.082 * k, zs + .006),
                (.082 * k, zt - .012), (.064 * k, zt)]
        st.append((x, ring(half)))
    x0, r0 = st[0]
    st[0] = (x0, [(y * .86, z) for y, z in r0])
    o = link(P + "_Upper", loft(st, ring_mats([CHAR, INKL, BLUE, INKL, WHITE, WHITE], bottom=CHAR, top=WHITE), cap_mat=INKL))
    return o

def build_lower():
    out = [(.165, .266), (.845, .266), (.90, .262), (.948, .205), (.93, .150), (.825, .150), (.79, .104), (.49, .104),
           (.45, .150), (.215, .150), (.150, .205)]
    bm = solid_plate(out, .066, .086, ch=.004, mat=BLUE, fold=((.16, .200), (.94, .186), .008, .10))
    for f in bm.faces:
        c = f.calc_center_median()
        if c.y > .07 and f.normal.y > .3 and f.material_index == BLUE and c.z < .19 + (c.x - .16) * -.017:
            f.material_index = INDG
    o = link(P + "_Lower", bm)
    mirror_apply(o)
    cowl = [(-.176, .370), (.004, .370), (-.012, .30), (-.04, .192), (-.10, .168), (-.176, .178)]
    c = link(P + "_RearCowl", solid_plate(cowl, .066, .085, ch=.004, mat=WHITE, fold=((-.18, .262), (.0, .28), .006, .12)))
    mirror_apply(c)
    fr = [(.95, .346), (1.10, .346), (1.10, .176), (1.02, .160), (.955, .200)]
    f = link(P + "_FrontBlock", solid_plate(fr, .066, .086, ch=.004, mat=INDG))
    mirror_apply(f)
    return o, c, f

def build_selector_ring():
    sel = bpy.data.objects["Vandal_FireSelector"]
    pts = [sel.matrix_world @ Vector(c) for c in sel.bound_box]
    cx = sum(p.x for p in pts) / 8; cz = sum(p.z for p in pts) / 8
    out = [(cx + .048 * math.cos(a), cz + .048 * math.sin(a)) for a in [math.radians(22.5 + 45 * i) for i in range(8)]]
    o = link(P + "_SelectorRing", solid_plate(out, .064, .0885, ch=.004, mat=INDG))
    mirror_apply(o)
    return o

def build_handguard():
    def fe(k=1.0):
        return [(.036 * k, .172), (.058 * k, .186), (.066 * k, .232), (.066 * k, .318), (.058 * k, .346), (.040 * k, .354)]
    st = [(1.10, ring(fe())), (1.64, ring(fe())), (1.70, ring(fe(.84)))]
    core = link(P + "_HandguardCore", loft(st, ring_mats([CHAR] * 5, bottom=CHAR, top=CHAR), cap_mat=CHAR))
    out = [(1.10, .350), (1.62, .350), (1.72, .300), (1.74, .214), (1.68, .168), (1.16, .168), (1.10, .200)]
    bm = solid_plate(out, .060, .080, ch=.0045, mat=BLUE, fold=((1.10, .262), (1.74, .250), .008, .10))
    for f in bm.faces:
        c = f.calc_center_median()
        if c.y > .07 and f.normal.y > .3 and f.material_index == BLUE and c.z < .258:
            f.material_index = INDG
    hg = link(P + "_HandguardPlate", bm)
    vents = []
    for xa in (1.20, 1.30, 1.40):
        vents.append(prism([(xa, .190), (xa + .060, .190), (xa + .075, .226), (xa + .015, .226)], .0625, .3, floor=CHAR, side=WALL))
    cut(hg, vents, rim=.0018)
    mirror_apply(hg)
    return core, hg

def build_fins():
    """Vermilion fins: a swept pair on the handguard shoulders (outside the
    sight line) and a short pair on the stock heel."""
    bms = []
    for x0, z0, ln, hh in ((1.70, .418, .24, .072), (1.02, .436, .16, .048)):
        bm = bmesh.new()
        a = bm.verts.new((x0, .070, z0)); b_ = bm.verts.new((x0 - ln, .074, z0 + .004)); c = bm.verts.new((x0 - ln * .78, .100, z0 + hh))
        a2 = bm.verts.new((x0, .060, z0 - .008)); b2 = bm.verts.new((x0 - ln, .066, z0 - .004)); c2 = bm.verts.new((x0 - ln * .78, .090, z0 + hh - .008))
        for f, m in (((a, b_, c), VERM), ((a2, c2, b2), VERM), ((a, a2, b2, b_), INKL), ((b_, b2, c2, c), VERM), ((c, c2, a2, a), VERM)):
            ff = bm.faces.new(f); ff.material_index = m
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bms.append(bm)
    o = join(P + "_Fins", bms)
    mirror_apply(o)
    return o

def build_stock():
    """Angular open-frame stock growing out of the receiver: white top beam,
    armour-blue frame, indigo butt, an ink-lined window, vermilion heel tab."""
    out = [(-.140, .405), (-1.12, .420), (-1.200, .400), (-1.252, .340), (-1.252, -.120), (-1.200, -.176), (-1.100, -.176),
           (-.800, .020), (-.450, .170), (-.140, .182)]
    o = link(P + "_Stock", solid_plate(out, -.060, .060, ch=.006, mat=BLUE))
    loop = [(-.360, .336), (-1.060, .348), (-1.100, .308), (-1.100, -.020), (-1.060, -.070), (-.800, .086), (-.500, .228)]
    cut(o, [prism(loop, -.3, .3, floor=CHAR, side=CHAR, outer=CHAR)], rim=.004)
    for p in o.data.polygons:
        if p.material_index == BLUE:
            if p.center.z > .338:
                p.material_index = WHITE
            elif p.center.x < -1.12:
                p.material_index = INDG
    tab_ = [(-1.252, -.060), (-1.290, -.110), (-1.282, -.168), (-1.220, -.190), (-1.200, -.176), (-1.252, -.120)]
    t = link(P + "_HeelTab", solid_plate(tab_, 0, .040, ch=.004, mat=VERM, open_inner=True))
    mirror_apply(t, merge=True)
    return o, t

def build_mag():
    back = [(.47, .199), (.462, .12), (.49, .031), (.513, -.027), (.536, -.085), (.565, -.141),
            (.593, -.197), (.626, -.252), (.658, -.306), (.694, -.36), (.700, -.380)]
    front = [(.995, -.322), (.93, -.268), (.887, -.217), (.851, -.164), (.817, -.11), (.788, -.054),
             (.759, .001), (.737, .06), (.717, .12), (.708, .199)]
    bm = solid_plate(back + [(.86, -.40), (.985, -.352)] + front, 0, .056, ch=.006, mat=BLUE, open_inner=True)
    body = link(P + "_Mag", bm, bone="Mag")
    mirror_apply(body, merge=True)
    plate = [(.735, .120), (.755, .040), (.785, -.040), (.825, -.120), (.870, -.190), (.925, -.250), (.970, -.296),
             (.900, -.300), (.810, -.230), (.740, -.140), (.690, -.040), (.660, .060), (.650, .120)]
    plate = clip_poly(plate, 0.0, -1.0, .075)                    # stays below the magwell collar
    pl = link(P + "_MagPlate", solid_plate(plate, .050, .0605, ch=.003, mat=WHITE), bone="Mag")
    mirror_apply(pl)
    base = [(.676, -.330), (.700, -.380), (.74, -.430), (.86, -.428), (.96, -.406), (1.030, -.366), (.998, -.318),
            (.94, -.352), (.86, -.372), (.76, -.370)]
    bs = link(P + "_MagBase", solid_plate(base, 0, .062, ch=.005, mat=INDG, open_inner=True), bone="Mag")
    mirror_apply(bs, merge=True)
    strip = [(.720, -.330), (.880, -.352), (.950, -.336), (.946, -.326), (.880, -.340), (.722, -.320)]
    cy = link(P + "_MagCyan", solid_plate(strip, .052, .0625, ch=.001, mat=CYAN), bone="Mag")
    mirror_apply(cy)
    return body, pl, bs, cy

def build_grip():
    hull = vandal_grip_outline(.003)
    o = link(P + "_Grip", solid_plate(hull, 0, .062, ch=.006, mat=INDG, open_inner=True))
    mirror_apply(o, merge=True)
    side = clip_poly(clip_poly(vandal_grip_outline(-.018), 0.0, -1.0, .110), 0.0, 1.0, .200)   # -.200 <= z <= .110
    sp = link(P + "_GripPlate", solid_plate(side, .058, .0685, ch=.003, mat=WHITE))
    mirror_apply(sp)
    cap = clip_poly(vandal_grip_outline(.006), 0.0, -1.0, -.274)
    c_ = link(P + "_GripCap", solid_plate(cap, 0, .066, ch=.004, mat=BLUE, open_inner=True))
    mirror_apply(c_, merge=True)
    return o, sp, c_

def build_muzzle():
    rings = []
    for x, r, k in ((2.384, .050, 1.0), (2.44, .058, 1.0), (2.45, .050, 1.0), (2.52, .054, 1.0), (2.53, .046, 1.0), (2.59, .048, .95), (2.62, .038, .9), (2.647, .030, .8)):
        rings.append([(x, r * math.cos(math.radians(45 * i)), .285 + r * k * math.sin(math.radians(45 * i))) for i in range(8)])
    o = link(P + "_Shroud", loft3(rings, [WHITE, BLUE, BLUE, BLUE, WHITE, WHITE, WHITE, WHITE], cap_mat=CHAR))
    for pp in o.data.polygons:
        xs = [o.data.vertices[i].co.x for i in pp.vertices]
        if max(xs) - min(xs) < .012:
            pp.material_index = INKL
    tipt = [(2.56, .330), (2.62, .330), (2.656, .350), (2.60, .356)]
    t = link(P + "_MuzzleTab", solid_plate(tipt, -.010, .010, ch=.002, mat=VERM))
    return o, t

def build_collar():
    def sec(k):
        return [(.030 * k, .232), (.054 * k, .248), (.062 * k, .300), (.054 * k, .352), (.030 * k, .372)]
    st = [(1.700, ring(sec(.90))), (1.712, ring(sec(1.0))), (1.760, ring(sec(1.0))), (1.775, ring(sec(.86)))]
    return link(P + "_Collar", loft(st, ring_mats([INDG] * 4, bottom=INDG, top=INDG), cap_mat=INKL))

def build_front_sight_cheeks():
    out = [(1.945, .224), (2.10, .224), (2.112, .252), (2.098, .352), (2.062, .374), (1.958, .374), (1.940, .330)]
    o = link(P + "_SightCheeks", solid_plate(out, .0575, .068, ch=.0035, mat=WHITE))
    mirror_apply(o)
    return o

# ------------------------------------------------------------------ build
vandal_hide_stock()
parts = {}
parts["core"] = vandal_core(CHAR, P + "_Core")
parts["kept"] = vandal_retained(P)
parts["barrel"] = vandal_barrel(P, SLATE)
parts["upper"] = build_upper()
parts["lower"] = build_lower()
parts["sel"] = build_selector_ring()
parts["hg"] = build_handguard()
parts["fins"] = build_fins()
parts["stock"] = build_stock()
parts["mag"] = build_mag()
parts["grip"] = build_grip()
parts["lip"] = vandal_magwell_lip(P, INDG)
parts["muzzle"] = build_muzzle()
parts["collar"] = build_collar()
parts["fs"] = build_front_sight_cheeks()
up = parts["upper"]
parts["cyan"] = cyan_accent(P, up, .36, .388, length=.52) if "cyan_accent" in globals() else []
INSET_IDX = CYAN
# comic highlight shapes and vermilion tabs
def _flash(name, target, x, z, w=.06, h=.010, lean=.022):
    pts = [(x, z), (x + w, z), (x + w + lean, z + h), (x + lean, z + h)]
    ys = [surface_pt(target, px, pz) for px, pz in pts]
    ys = [y for y in ys if y is not None]
    if not ys:
        return None
    o = link(name, solid_plate(pts, min(ys) - .003, max(ys) + .0022, ch=.0008, mat=HILITE), target.parent_bone or "Root")
    mirror_apply(o)
    return o
parts["flash"] = [_flash(P + "_Flash1", up, 1.20, .430, w=.10), _flash(P + "_Flash2", parts["stock"][0], -.70, .380, w=.12),
                  _flash(P + "_Flash3", parts["hg"][1], 1.48, .318, w=.07)]
# ---- intricate pass: layered armour, ink panel lines, stripes, glow line
INK_T = globals().get("INK_T", .0055)          # outline thickness (studs): tune in Studio
def layer_plate(name, target, outline, mat=WHITE, lift=.006, rim=INKL):
    ys = [surface_pt(target, x, z) for x, z in outline]
    ys = [y for y in ys if y is not None]
    if not ys:
        return None
    bm = solid_plate(outline, min(ys) - .004, max(ys) + lift, ch=.003, mat=mat)
    for f in bm.faces:
        if f.material_index == EDGE:
            f.material_index = rim
    o = link(name, bm, target.parent_bone or "Root")
    mirror_apply(o)
    return o
def panel_line(name, target, pts, mat=INKL, w=.0045):
    return inlay_line(name, target, pts, w=w, h=.0022, mat=mat, bone=target.parent_bone or "Root")
up = parts["upper"]; lo = parts["lower"][0]; hgp = parts["hg"][1]; stk = parts["stock"][0]; mg = parts["mag"][0]
lay = []
lay.append(layer_plate(P + "_UpperArmourA", up, [(.30, .446), (.86, .446), (.92, .424), (.86, .414), (.36, .414)]))
lay.append(layer_plate(P + "_UpperArmourB", up, [(1.10, .446), (1.56, .446), (1.62, .430), (1.56, .418), (1.16, .418)]))
lay.append(layer_plate(P + "_HandguardArmour", hgp, [(1.14, .340), (1.52, .340), (1.62, .300), (1.50, .286), (1.18, .292)], mat=WHITE))
lay.append(layer_plate(P + "_LowerArmour", lo, [(.18, .258), (.44, .258), (.40, .200), (.20, .200)], mat=WHITE))
lay.append(layer_plate(P + "_StockArmour", stk, [(-.20, .400), (-.34, .400), (-.44, .356), (-.20, .330)], mat=INDG))
lay.append(layer_plate(P + "_ButtArmour", stk, [(-1.130, .300), (-1.238, .300), (-1.238, .020), (-1.130, .060)], mat=WHITE))
parts["layers"] = [l for l in lay if l]
stripes = []
stripes.append(layer_plate(P + "_StripeUpper", up, [(.94, .446), (.99, .446), (1.03, .414), (.98, .414)], mat=VERM, lift=.004))
stripes.append(layer_plate(P + "_StripeHG", hgp, [(1.60, .340), (1.66, .340), (1.70, .300), (1.64, .300)], mat=VERM, lift=.004))
stripes.append(layer_plate(P + "_StripeLower", lo, [(.70, .258), (.76, .258), (.80, .200), (.74, .200)], mat=VERM, lift=.004))
stripes.append(layer_plate(P + "_StripeGrip", parts["grip"][0], [(-.14, -.150), (-.06, -.165), (-.06, -.180), (-.15, -.165)], mat=VERM, lift=.004))
parts["stripes"] = [l for l in stripes if l]
lines = []
lines.append(panel_line(P + "_PL1", lo, [(.48, .258), (.56, .150)]))
lines.append(panel_line(P + "_PL2", lo, [(.62, .258), (.66, .200), (.84, .200)]))
lines.append(panel_line(P + "_PL3", hgp, [(1.12, .262), (1.70, .262)]))
lines.append(panel_line(P + "_PL4", stk, [(-.50, .380), (-1.05, .390)]))
lines.append(panel_line(P + "_PL5", stk, [(-.20, .200), (-.46, .186), (-.78, .050)]))
lines.append(panel_line(P + "_PL6", mg, [(.62, .10), (.66, -.10), (.74, -.26)]))
lines.append(panel_line(P + "_GlowHG", hgp, [(1.15, .250), (1.36, .250), (1.38, .244)], mat=CYAN, w=.006))
lines.append(panel_line(P + "_GlowStock", stk, [(-1.150, .250), (-1.150, .120)], mat=CYAN, w=.006))
parts["lines"] = [l for l in lines if l]
parts["flash2"] = [_flash(P + "_Flash4", lo, .52, .232, w=.08), _flash(P + "_Flash5", stk, -.92, .160, w=.06, lean=.04),
                   _flash(P + "_Flash6", mg, .76, -.20, w=.05, lean=.03), _flash(P + "_Flash7", hgp, 1.20, .196, w=.08)]
ink = []
for nm in ("_Upper", "_Lower", "_RearCowl", "_HandguardPlate", "_Stock", "_Mag", "_MagBase", "_Grip", "_Shroud", "_FrontBlock",
           "_UpperArmourA", "_UpperArmourB", "_HandguardArmour", "_Fins", "_HeelTab"):
    o = bpy.data.objects.get(P + nm)
    if o:
        ink.append(ink_outline(o, t=(.003 if o.parent_bone == "Mag" else INK_T)))
parts["ink"] = ink
for o in col.objects:
    flat_uv(o)

HARDWARE = list(VANDAL_KEEP)
STOCK_PARTS = list(VANDAL_HIDE)
set_skin = vandal_set_skin_factory(lambda n: DARK_SKIN if n in ("Vandal_RearSight", "Vandal_FrontSight") else SLOT_SKIN)
set_skin(True)
result = {"objects": [(o.name, len(o.data.polygons)) for o in col.objects], "cut_failures": CUT_FAILURES}
