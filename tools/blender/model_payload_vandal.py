"""Payload Vandal v02: full flight-hardware shell (stock Vandal open). Exec
after model_giltfold_kit.py and model_vandal_shell_base.py (run_sfg KIT chain).

Owner 2026-11-14: v01 (white panels over the stock gun) read as a reskin.
v02 is a new body in the line's flight-hardware language, quality bar of the
Endeavour reference, original layout and marks: a white enamel upper with
engraved service seams, twin vents, a glowing mission-blue tube window and a
champagne pinstripe; a carbon-fibre lower and grip (raised grip squares); a
crumpled thermal-foil pillow in a graphite frame on the handguard; a quilted
white padded magazine on a smoked-steel base with a pull loop; a boxy white
stock with a quilted cheek pad, a foil strap and a buckle; a white muzzle
sleeve with a foil crown; mission-blue trigger and selector; the line's
clipped foil inset with two blue marks. Fit and moving parts per
model_vandal_shell_base."""

_k = open(os.path.join(TB, "model_payload_kit.py")).read()
exec(_k[:_k.index("def pl_bulldog")])          # Payload palette + panel(), foil_inset(), blue_marks()

def carbon():
    """Graphite carbon twill: a 45-degree checker of two close greys under a
    clear coat (reads as weave at first-person size, flat at range)."""
    m, nt, b = pbsdf("PL2 Carbon Twill", "22272E", 0.0, .38, .25)
    N = nt.nodes; L = nt.links.new
    tc = N.new("ShaderNodeTexCoord"); sep = N.new("ShaderNodeSeparateXYZ"); L(tc.outputs["Object"], sep.inputs[0])
    a = N.new("ShaderNodeMath"); a.operation = "ADD"; L(sep.outputs["X"], a.inputs[0]); L(sep.outputs["Z"], a.inputs[1])
    d = N.new("ShaderNodeMath"); d.operation = "SUBTRACT"; L(sep.outputs["X"], d.inputs[0]); L(sep.outputs["Z"], d.inputs[1])
    yz = N.new("ShaderNodeMath"); yz.operation = "ADD"; L(d.outputs[0], yz.inputs[0]); L(sep.outputs["Y"], yz.inputs[1])
    cv = N.new("ShaderNodeCombineXYZ"); L(a.outputs[0], cv.inputs[0]); L(yz.outputs[0], cv.inputs[1])
    ck = N.new("ShaderNodeTexChecker"); ck.inputs["Scale"].default_value = 70.0
    ck.inputs["Color1"].default_value = (*_lin("1A1E24"), 1); ck.inputs["Color2"].default_value = (*_lin("2E343D"), 1)
    L(cv.outputs[0], ck.inputs["Vector"]); L(ck.outputs["Color"], b.inputs["Base Color"])
    return m

def padding():
    m, nt, b = pbsdf("PL2 Quilted Padding", "E8EBEF", 0.0, .55, .0)
    b.inputs["Sheen Weight"].default_value = .4
    return m

def glow():
    m, nt, b = pbsdf("PL2 Blue Tube", "3E8BFF", 0.0, .2)
    b.inputs["Emission Color"].default_value = (*_lin("4A9BFF"), 1); b.inputs["Emission Strength"].default_value = 3.0
    return m

MATS += [carbon(), padding(), glow()]
WHITE, BEV, GRA, REC, FOIL, GRP, STL, BLUE, HOUS, CARB, PAD, GLOW = range(12)
P = "PLV"

def _h(i, j, k=0):
    """Deterministic hash in [-1, 1] for crumple offsets."""
    v = math.sin(i * 12.9898 + j * 78.233 + k * 37.719) * 43758.5453
    return (v - math.floor(v)) * 2 - 1

def pillow(name, outline_fn, nu, nv, y0, puff, mat, bone="Root", crumple=0.0, seams_u=(), seams_v=(), edge=.35, mirror=True):
    """Closed padded / foil pillow: outer grid surface y = y0 + puff * bulge
    (+ crumple), seams pinch rows / columns; flat inner face at y0 - .006.
    outline_fn(u, v) -> (x, z) for u, v in [0, 1]."""
    bm = bmesh.new()
    outer, inner = {}, {}
    for i in range(nu + 1):
        for j in range(nv + 1):
            u, v = i / nu, j / nv
            x, z = outline_fn(u, v)
            bu = math.sin(math.pi * u) ** edge; bv = math.sin(math.pi * v) ** edge
            pinch = 1.0
            if i in seams_u or j in seams_v:
                pinch = .25
            y = y0 + puff * bu * bv * pinch + crumple * _h(i, j) * bu * bv
            outer[i, j] = bm.verts.new((x, y, z))
            inner[i, j] = bm.verts.new((x, y0 - .006, z))
    for i in range(nu):
        for j in range(nv):
            f = bm.faces.new((outer[i, j], outer[i + 1, j], outer[i + 1, j + 1], outer[i, j + 1])); f.material_index = mat
            g = bm.faces.new((inner[i, j + 1], inner[i + 1, j + 1], inner[i + 1, j], inner[i, j])); g.material_index = mat
    rim = [(i, 0) for i in range(nu)] + [(nu, j) for j in range(nv)] + [(i, nv) for i in range(nu, 0, -1)] + [(0, j) for j in range(nv, 0, -1)]
    for a_, b_ in zip(rim, rim[1:] + rim[:1]):
        f = bm.faces.new((outer[a_], inner[a_], inner[b_], outer[b_])); f.material_index = mat
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="FIXED", ngon_method="BEAUTY")
    o = link(name, bm, bone)
    if mirror:
        mirror_apply(o)
    return o

def quad_fn(p00, p10, p11, p01):
    """Bilinear patch: corners (u, v) = (0,0), (1,0), (1,1), (0,1)."""
    def f(u, v):
        x = (p00[0] * (1 - u) + p10[0] * u) * (1 - v) + (p01[0] * (1 - u) + p11[0] * u) * v
        z = (p00[1] * (1 - u) + p10[1] * u) * (1 - v) + (p01[1] * (1 - u) + p11[1] * u) * v
        return x, z
    return f

def zt_top(x):
    if x <= .16: return .408
    if x <= .26: return .408 + (x - .16) / .10 * .050
    if x <= 1.08: return .458
    if x <= 1.12: return .458 - (x - 1.08) / .04 * .022
    return .436 - max(0.0, (x - 1.62) / .08) * .040

def build_upper():
    xs = [-.178, -.17, .0, .16, .21, .26, .55, .86, 1.08, 1.12, 1.30, 1.50, 1.62, 1.70]
    st = []
    for x in xs:
        zt = zt_top(x); zb = .356 if x < 1.10 else .350
        k = 1 - max(0.0, (x - 1.62) / .08) * .20
        half = [(.060 * k, zb), (.088 * k, zb), (.094 * k, zb + .008), (.094 * k, zt - .028), (.084 * k, zt - .010), (.058 * k, zt)]
        st.append((x, ring(half)))
    x0, r0 = st[0]
    st[0] = (x0, [(y * .86, z) for y, z in r0])
    o = link(P + "_Upper", loft(st, ring_mats([GRA, BEV, WHITE, BEV, WHITE], bottom=GRA, top=WHITE), cap_mat=BEV))
    cuts = []
    for xa in (.884, .984):                                       # twin vents near the front
        v = [(xa, .396), (xa + .072, .396), (xa + .080, .404), (xa + .080, .422), (xa + .072, .430), (xa, .430), (xa - .008, .422), (xa - .008, .404)]
        cuts += [prism(v, .084, .3, floor=REC, side=REC), prism(v, -.084, -.3, floor=REC, side=REC)]
    tube = [(.30, .368), (.80, .368), (.808, .376), (.808, .388), (.80, .396), (.30, .396), (.292, .388), (.292, .376)]
    cuts += [prism(tube, .082, .3, floor=GLOW, side=REC), prism(tube, -.082, -.3, floor=GLOW, side=REC)]
    for xs_ in ((.26, .264), (1.104, 1.108)):                    # engraved service seams
        seam = [(xs_[0], .362), (xs_[1], .362), (xs_[1], .452), (xs_[0], .452)]
        cuts += [prism(seam, .088, .3, floor=REC, side=REC), prism(seam, -.088, -.3, floor=REC, side=REC)]
    cut(o, cuts, rim=.0015)
    return o

def build_tube_caps(upper):
    """Small steel end caps at both ends of the blue tube window."""
    caps = []
    for x in (.296, .804):
        y = surface_pt(upper, x + (.010 if x < .5 else -.010), .382)
        if y is None:
            continue
        pts = [(x - .010, .368), (x + .010, .368), (x + .010, .396), (x - .010, .396)]
        caps.append(solid_plate(pts, y - .010, y + .003, ch=.0015, mat=STL))
    o = join(P + "_TubeCaps", caps)
    mirror_apply(o)
    return o

def build_lower():
    out = [(.165, .266), (.845, .266), (.90, .262), (.948, .205), (.93, .150), (.825, .150), (.79, .104), (.49, .104),
           (.45, .150), (.215, .150), (.150, .205)]
    o = link(P + "_CarbonLower", solid_plate(out, .066, .084, ch=.004, mat=CARB, fold=((.16, .236), (.94, .246), .004, .14)))
    mirror_apply(o)
    cowl = [(-.176, .370), (.004, .370), (-.012, .30), (-.04, .192), (-.10, .168), (-.176, .178)]
    c = link(P + "_RearCowl", solid_plate(cowl, .066, .085, ch=.004, mat=WHITE, fold=((-.18, .262), (.0, .28), .004, .12)))
    mirror_apply(c)
    fr = [(.95, .346), (1.10, .346), (1.10, .176), (1.02, .160), (.955, .200)]
    f = link(P + "_FrontBlock", solid_plate(fr, .066, .086, ch=.004, mat=WHITE))
    mirror_apply(f)
    return o, c, f

def build_selector_ring():
    sel = bpy.data.objects["Vandal_FireSelector"]
    pts = [sel.matrix_world @ Vector(c) for c in sel.bound_box]
    cx = sum(p.x for p in pts) / 8; cz = sum(p.z for p in pts) / 8
    out = [(cx + .048 * math.cos(a), cz + .048 * math.sin(a)) for a in [math.radians(22.5 + 45 * i) for i in range(8)]]
    o = link(P + "_SelectorRing", solid_plate(out, .064, .0885, ch=.004, mat=GRA))
    mirror_apply(o)
    return o

def build_handguard():
    def fe(k=1.0):
        return [(.036 * k, .172), (.058 * k, .186), (.066 * k, .232), (.066 * k, .318), (.058 * k, .346), (.040 * k, .354)]
    st = [(1.10, ring(fe())), (1.64, ring(fe())), (1.70, ring(fe(.84)))]
    frame = link(P + "_HandguardFrame", loft(st, ring_mats([GRA, GRA, GRA, GRA, GRA], bottom=GRA, top=GRA), cap_mat=GRA))
    rim = [(1.10, .350), (1.66, .350), (1.70, .320), (1.70, .200), (1.66, .168), (1.14, .168), (1.10, .200)]
    rp = link(P + "_HandguardRim", solid_plate(rim, .060, .072, ch=.003, mat=GRA))
    cut(rp, [prism([(1.135, .192), (1.635, .192), (1.665, .222), (1.665, .330), (1.135, .330)], .061, .3, floor=GRA, side=REC)], rim=.0015)
    mirror_apply(rp)
    foil = pillow(P + "_FoilPillow", quad_fn((1.150, .204), (1.620, .204), (1.620, .318), (1.150, .318)),
                  8, 3, .074, .014, FOIL, crumple=.0022, edge=.45)        # edges stand off the frame face (.066): no flicker
    return frame, rp, foil

def build_mag():
    back = [(.47, .199), (.462, .12), (.49, .031), (.513, -.027), (.536, -.085), (.565, -.141),
            (.593, -.197), (.626, -.252), (.658, -.306), (.694, -.36)]
    front = [(.708, .199), (.717, .12), (.737, .06), (.759, .001), (.788, -.054), (.817, -.11),
             (.851, -.164), (.887, -.217), (.93, -.268), (.995, -.322)]
    n = len(back) - 1
    def fn(u, v):                      # u along the section (back -> front), v down the magazine
        t = v * n; i = min(int(t), n - 1); f = t - i
        b = lerp2(back[i], back[i + 1], f); fr = lerp2(front[i], front[i + 1], f)
        return lerp2(b, fr, u)
    body = pillow(P + "_MagPad", fn, 4, n * 2, .046, .012, PAD, bone="Mag", seams_u=(2,), seams_v=(4, 8, 12), edge=.5)
    core = link(P + "_MagCore", solid_plate(back + list(reversed(front)), 0, .044, ch=.003, mat=GRA, open_inner=True), bone="Mag")
    mirror_apply(core, merge=True)
    base = [(.680, -.335), (.694, -.36), (.708, -.404), (.74, -.428), (.86, -.426), (.96, -.404), (1.026, -.366),
            (1.010, -.330), (.995, -.322), (.93, -.300), (.80, -.320)]
    bs = link(P + "_MagBase", solid_plate(base, 0, .060, ch=.006, mat=STL, open_inner=True), bone="Mag")
    mirror_apply(bs, merge=True)
    loop = sweep([(.735, 0, -.425), (.725, 0, -.452), (.745, 0, -.474), (.785, 0, -.474), (.800, 0, -.452), (.790, 0, -.426)],
                 (0, 1, 0), [.012] * 6, [.006] * 6, section=STRUT, mats=[STL] * 8)
    lp = join(P + "_MagLoop", [loop], bone="Mag")
    spine = [(.468, .195), (.462, .12), (.49, .031), (.536, -.085), (.593, -.197), (.658, -.306), (.684, -.340),
             (.700, -.334), (.672, -.300), (.610, -.196), (.554, -.088), (.510, .028), (.484, .12), (.488, .195)]
    sp = link(P + "_MagSpine", solid_plate(spine, 0, .054, ch=.003, mat=CARB, open_inner=True), bone="Mag")
    mirror_apply(sp, merge=True)
    return body, bs, lp, sp

def _inside_convex(poly, q):
    sgn = 0
    for (x0, z0), (x1, z1) in zip(poly, poly[1:] + poly[:1]):
        c = (x1 - x0) * (q[1] - z0) - (z1 - z0) * (q[0] - x0)
        if abs(c) < 1e-12:
            continue
        if sgn == 0:
            sgn = 1 if c > 0 else -1
        elif (c > 0) != (sgn > 0):
            return False
    return True

def build_grip():
    """Carbon grip seated into the receiver (flat sides so the texture sits
    evenly), a grid of raised squares aligned with the grip's rake and kept
    fully inside the grip face (no square crosses an edge), steel base cap."""
    hull = vandal_grip_outline(.003)
    o = link(P + "_Grip", solid_plate(hull, 0, .064, ch=.007, mat=CARB, open_inner=True))
    mirror_apply(o, merge=True)
    inset = vandal_grip_outline(-.020)
    d = Vector((-.078, -.259)).normalized(); pp = Vector((-d.y, d.x))
    if pp.x < 0:
        pp = -pp
    studs = []
    h = .0085
    for i in range(-2, 10):
        for j in range(-3, 6):
            c = Vector((-.090, .090)) + d * (.038 * i) + pp * (.036 * j)
            corners = [c + d * h + pp * h, c + d * h - pp * h, c - d * h - pp * h, c - d * h + pp * h]
            if not (-.250 < c.y < .120):
                continue
            if all(_inside_convex(inset, (q.x, q.y)) for q in corners):
                studs.append(solid_plate([(q.x, q.y) for q in corners], .062, .0670, ch=.0012, mat=GRA))
    s_ = join(P + "_GripSquares", studs)
    mirror_apply(s_)
    cap = clip_poly(vandal_grip_outline(.006), 0.0, -1.0, -.274)
    c_ = link(P + "_GripCap", solid_plate(cap, 0, .068, ch=.005, mat=STL, open_inner=True))
    mirror_apply(c_, merge=True)
    return o, s_, c_

def build_stock():
    out = [(-.150, .405), (-1.08, .418), (-1.150, .400), (-1.195, .340), (-1.195, -.100), (-1.150, -.172), (-1.020, -.172),
           (-.700, .090), (-.420, .190), (-.150, .182)]
    o = link(P + "_Stock", solid_plate(out, 0, .064, ch=.008, mat=WHITE, open_inner=True, fold=((-.15, .30), (-1.19, .12), .006, .14)))
    mirror_apply(o, merge=True)
    cut(o, [prism([(-.46, .250), (-.88, .250), (-.95, .190), (-.95, .060), (-.80, .060)], .056, .3, floor=CARB, side=REC),
            prism([(-.46, .250), (-.88, .250), (-.95, .190), (-.95, .060), (-.80, .060)], -.056, -.3, floor=CARB, side=REC)], rim=.002)
    pad = pillow(P + "_CheekPad", quad_fn((-1.04, .350), (-.56, .360), (-.56, .414), (-1.04, .414)), 8, 2, .062, .012, PAD,
                 seams_u=(4,), edge=.5)
    bp = [(-1.180, .408), (-1.250, .400), (-1.262, .340), (-1.262, -.110), (-1.250, -.172), (-1.180, -.180)]
    butt = link(P + "_ButtPad", solid_plate(bp, 0, .066, ch=.006, mat=GRA, open_inner=True))
    mirror_apply(butt, merge=True)
    def band(x0, x1, mat, nm, grow=.004):
        sec = [(.068 + grow, .424 + grow), (.068 + grow, -.178 - grow)]
        st = []
        for x in (x0, x1):
            st.append((x, [(.0, -.180 - grow), (.068 + grow, -.170 - grow), (.068 + grow, .416 + grow), (.0, .424 + grow),
                           (-.068 - grow, .416 + grow), (-.068 - grow, -.170 - grow)]))
        return link(nm, loft(st, [mat] * 6, cap_mat=mat))
    strap = band(-1.10, -1.07, FOIL, P + "_Strap")
    buckle = [(-1.112, .205), (-1.058, .205), (-1.052, .215), (-1.052, .285), (-1.058, .295), (-1.112, .295), (-1.118, .285), (-1.118, .215)]
    bk = link(P + "_Buckle", solid_plate(buckle, .070, .080, ch=.003, mat=STL))
    cut(bk, [prism([(-1.100, .222), (-1.070, .222), (-1.070, .278), (-1.100, .278)], .074, .3, floor=FOIL, side=STL)], rim=0)
    mirror_apply(bk)
    return o, pad, butt, strap, bk

def build_muzzle():
    prof = [(2.384, .050), (2.40, .054), (2.52, .054), (2.535, .050), (2.545, .046)]
    st = [[(x, r * math.cos(math.radians(22.5 + 45 * i)), .285 + r * math.sin(math.radians(22.5 + 45 * i))) for i in range(8)] for x, r in prof]
    sleeve = link(P + "_Sleeve", loft3(st, [WHITE] * 8, cap_mat=GRA))
    ring_ = [[(x, r * math.cos(math.radians(22.5 + 45 * i)), .285 + r * math.sin(math.radians(22.5 + 45 * i))) for i in range(8)]
             for x, r in ((2.545, .044), (2.55, .047), (2.585, .047), (2.59, .044))]
    rg = link(P + "_SleeveRing", loft3(ring_, [GRA] * 8, cap_mat=GRA))
    crown = []
    for x, r in ((2.59, .046), (2.60, .049), (2.630, .049), (2.636, .046)):
        crown.append([(x, r * math.cos(math.radians(22.5 + 45 * i)), .285 + r * math.sin(math.radians(22.5 + 45 * i))) for i in range(8)])
    cr = link(P + "_Crown", loft3(crown, [FOIL] * 8, cap_mat=GRA))
    teeth = []
    for i in range(8):
        a = math.radians(22.5 + 45 * i); b = math.radians(45 * i)
        c, s_ = math.cos(a), math.sin(a)
        tp = [(2.628, .047 * c, .285 + .047 * s_), (2.628, .034 * c, .285 + .034 * s_), (2.656, .041 * math.cos(b), .285 + .041 * math.sin(b))]
        bm = bmesh.new(); vs = [bm.verts.new(p) for p in tp]
        f = bm.faces.new(vs); f.material_index = FOIL
        bmesh.ops.solidify(bm, geom=[f], thickness=.004)
        teeth.append(bm)
    tt = join(P + "_CrownTeeth", teeth)
    return sleeve, rg, cr, tt

def build_collar():
    def sec(k):
        return [(.030 * k, .232), (.054 * k, .248), (.062 * k, .300), (.054 * k, .352), (.030 * k, .372)]
    st = [(1.700, ring(sec(.90))), (1.712, ring(sec(1.0))), (1.760, ring(sec(1.0))), (1.775, ring(sec(.86)))]
    return link(P + "_Collar", loft(st, ring_mats([GRA] * 4, bottom=GRA, top=GRA), cap_mat=GRA))

def build_front_sight_cheeks():
    out = [(1.945, .224), (2.10, .224), (2.112, .252), (2.098, .352), (2.062, .374), (1.958, .374), (1.940, .330)]
    o = link(P + "_SightCheeks", solid_plate(out, .0575, .068, ch=.0035, mat=WHITE))
    mirror_apply(o)
    return o

# ------------------------------------------------------------------ build
vandal_hide_stock()
parts = {}
parts["core"] = vandal_core(CARB, P + "_Core")
parts["kept"] = vandal_retained(P)
parts["barrel"] = vandal_barrel(P, STL)
parts["upper"] = build_upper()
parts["caps"] = build_tube_caps(parts["upper"])
parts["lower"] = build_lower()
parts["sel"] = build_selector_ring()
parts["hg"] = build_handguard()
parts["mag"] = build_mag()
parts["grip"] = build_grip()
parts["lip"] = vandal_magwell_lip(P, GRA)
parts["stock"] = build_stock()
parts["muzzle"] = build_muzzle()
parts["collar"] = build_collar()
parts["fs"] = build_front_sight_cheeks()
parts["stripe"] = inlay_line(P + "_Pinstripe", parts["upper"], [(.30, .440), (.84, .440), (.86, .430)], w=.006, h=.003, mat=FOIL)
parts["stripe2"] = inlay_line(P + "_Pinstripe2", parts["upper"], [(.30, .428), (.70, .428)], w=.004, h=.003, mat=FOIL)
parts["inset"] = foil_inset(P, parts["stock"][0], -.36, .300, w=.15, h=.060)
parts["marks"] = blue_marks(P, parts["stock"][0], -.19, .300)
for o in col.objects:
    flat_uv(o)

HARDWARE = list(VANDAL_KEEP)
STOCK_PARTS = list(VANDAL_HIDE)
_blue = [MATS[BLUE]] * 6 + [EXTRA["Neon"], EXTRA["Brass"]]
set_skin = vandal_set_skin_factory(lambda n: DARK_SKIN if n in ("Vandal_RearSight", "Vandal_FrontSight") else
                                   (_blue if n in ("Vandal_Trigger", "Vandal_FireSelector") else SLOT_SKIN))
set_skin(True)
result = {"objects": [(o.name, len(o.data.polygons)) for o in col.objects], "cut_failures": CUT_FAILURES}
