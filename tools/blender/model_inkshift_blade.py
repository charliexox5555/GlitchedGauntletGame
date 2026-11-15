"""Inkshift Blade v02 (Knife slot): a sword-length one-handed blade in the
line's anime pop-art mecha language (owner 2026-11-14: "not as small as a
regular knife, almost a sword"), quality bar of the Orion sword, original
shapes. Exec after model_giltfold_kit.py (stock Knife open).

Long tanto-tipped blade (reach to x 2.20, about twice the stock blade) with
a glowing cyan edge and spine line, a deep-blue face, a layered grey-white
armour plate along the middle, a dark fuller slot with a cyan core line and a
vermilion stripe near the tip; a stepped white collar with two swept
vermilion guard wings; a blue armoured grip (stock section where the fist
sits) with white side plates and a cyan ring; an indigo pommel with a
glowing cyan cap and a vermilion tab. Black ink outlines (inverted hulls,
outward faces) on every main part. RightGrip stays at the origin."""

_v = open(os.path.join(TB, "model_inkshift_vandal.py")).read()
exec(_v[_v.index('_k = open(os.path.join(TB, "model_inkshift_kit.py")).read()'):_v.index("def zt_top(x):")])
P = "IKB"
INK_T = globals().get("INK_T", .0055)

def _pl(pts, x):
    for (x0, z0), (x1, z1) in zip(pts, pts[1:]):
        if x0 <= x <= x1:
            return z0 + (z1 - z0) * (x - x0) / (x1 - x0)
    return pts[-1][1] if x > pts[-1][0] else pts[0][1]

SPINE = [(.355, .060), (.45, .072), (1.96, .074), (2.20, -.016)]
EDGE_L = [(.355, -.062), (.45, -.084), (1.90, -.084), (2.06, -.070), (2.20, -.016)]
XS = [.355, .45, .70, 1.00, 1.30, 1.60, 1.80, 1.96, 2.06, 2.14, 2.20]

def blade_t(x):
    return .021 * (1 - max(0.0, (x - 1.80) / .40) * .72)

def build_blade():
    st = []
    for x in XS:
        s, e = _pl(SPINE, x), _pl(EDGE_L, x)
        h = max(.004, s - e); t = blade_t(x)
        half = [(.0010, e), (.0055, e + min(.016, .22 * h)), (t * .78, e + .30 * h), (t, e + .46 * h), (t, s - .016), (t * .62, s - .005), (.004, s)]
        st.append((x, ring(half)))
    x, r = st[-1]
    st[-1] = (x, [(y * .10, z) for y, z in r])
    o = link(P + "_Blade", loft(st, ring_mats([CYAN, BLUE, BLUE, INDG, INKL, INKL], bottom=CYAN, top=CYAN), cap_mat=CYAN))
    return o

def layer_on_blade(name, outline, mat, lift=.0055, rim=INKL):
    xs = [p[0] for p in outline]
    t = min(blade_t(x) for x in xs)
    bm = solid_plate(outline, t - .004, t + lift, ch=.0025, mat=mat)
    for f in bm.faces:
        if f.material_index == EDGE:
            f.material_index = rim
    o = link(name, bm)
    mirror_apply(o)
    return o

def build_blade_layers():
    out = []
    out.append(layer_on_blade(P + "_ArmourA", [(.40, .052), (1.30, .056), (1.42, .030), (1.30, .006), (.46, .004), (.40, .020)], WHITE))
    out.append(layer_on_blade(P + "_ArmourB", [(1.48, .056), (1.84, .058), (1.90, .040), (1.84, .026), (1.52, .026)], WHITE))
    out.append(layer_on_blade(P + "_Fuller", [(.62, -.030), (1.56, -.030), (1.62, -.044), (1.56, -.058), (.66, -.058)], CHAR, lift=.003))
    out.append(layer_on_blade(P + "_FullerGlow", [(.70, -.042), (1.50, -.042), (1.53, -.046), (1.50, -.050), (.70, -.050)], CYAN, lift=.0045))
    out.append(layer_on_blade(P + "_TipStripe", [(1.92, .066), (2.02, .044), (2.08, .030), (2.02, .030), (1.90, .054)], VERM, lift=.004))
    out.append(layer_on_blade(P + "_EdgeStripe", [(1.20, -.070), (1.86, -.072), (1.92, -.064), (1.86, -.062), (1.24, -.062)], VERM, lift=.003))
    return out

def build_guard():
    col_ = [(.300, .086), (.380, .092), (.402, .060), (.402, -.072), (.380, -.104), (.300, -.100), (.290, -.060), (.290, .050)]
    c = link(P + "_Collar", solid_plate(col_, 0, .046, ch=.005, mat=WHITE, open_inner=True, fold=((.29, .0), (.40, .0), .004, .12)))
    for f in c.data.polygons:
        if f.material_index == EDGE:
            f.material_index = INKL
    mirror_apply(c, merge=True)
    wings = []
    for pts in ([(.300, .080), (.400, .086), (.566, .178), (.524, .198), (.330, .122)],
                [(.300, -.092), (.400, -.096), (.566, -.216), (.512, -.234), (.320, -.142)]):
        bm = solid_plate(pts, 0, .013, ch=.002, mat=VERM, open_inner=True)
        for f in bm.faces:
            if f.material_index == EDGE:
                f.material_index = INKL
        wings.append(bm)
    w = join(P + "_Wings", wings)
    mirror_apply(w, merge=True)
    return c, w

def grip_half(x, k=1.0):
    zc = -.004 - max(0.0, -x - .05) * .06
    zt, zb = zc + .084 * k, zc - .092 * k
    return [(.018 * k, zb), (.040 * k, zb + .014 * k), (.050 * k, zb + .046 * k), (.050 * k, zt - .040 * k), (.042 * k, zt - .013 * k), (.018 * k, zt)]

def build_grip():
    xs = [.296, .20, .06, -.08, -.22, -.334]
    st = [(x, ring(grip_half(x))) for x in xs]
    g = link(P + "_Grip", loft(st, ring_mats([INDG, BLUE, BLUE, BLUE, INDG], bottom=INDG, top=INDG), cap_mat=INDG))
    plates = []
    for xa, xb in ((.26, .06), (.02, -.20)):
        out = [(xa, .050), (xb + .02, .050), (xb, .020), (xb + .02, -.060), (xa, -.060), (xa + .02, -.005)]
        bm = solid_plate(out, .046, .0565, ch=.002, mat=WHITE)
        for f in bm.faces:
            if f.material_index == EDGE:
                f.material_index = INKL
        plates.append(bm)
    pl = join(P + "_GripPlates", plates)
    mirror_apply(pl)
    rg = [[(x, y * 1.06, z * 1.04 - .0002) for y, z in ring(grip_half(-.10))] for x in (-.112, -.104, -.088, -.080)]
    rn = link(P + "_GripRing", loft3(rg, [CYAN] * len(rg[0]), cap_mat=CYAN))
    return g, pl, rn

def build_pommel():
    st = []
    for x, k in ((-.334, .98), (-.360, 1.06), (-.420, 1.06), (-.452, .86), (-.470, .58)):
        st.append([(x, y, z) for y, z in ring(grip_half(-.334, k))])
    pm = link(P + "_Pommel", loft3(st, ring_mats([INDG, INDG, INDG, INDG, CYAN], bottom=INDG, top=CYAN), cap_mat=CYAN))
    tab_ = [(-.380, -.096), (-.450, -.096), (-.476, -.140), (-.420, -.150)]
    t = link(P + "_PommelTab", solid_plate(tab_, 0, .024, ch=.002, mat=VERM, open_inner=True))
    mirror_apply(t, merge=True)
    return pm, t

parts = {}
parts["blade"] = build_blade()
parts["layers"] = build_blade_layers()
parts["guard"] = build_guard()
parts["grip"] = build_grip()
parts["pommel"] = build_pommel()
ink = []
for nm in ("_Blade", "_Collar", "_Wings", "_Grip", "_Pommel", "_ArmourA", "_ArmourB"):
    o = bpy.data.objects.get(P + nm)
    if o:
        # the blade's outline thins to almost nothing over the last 0.2 studs so
        # the tanto point reads sharp (owner 2026-11-14: "no sharp edge")
        taper = (lambda w: max(.06, min(1.0, (2.20 - w.x) / .20))) if nm == "_Blade" else None
        ink.append(ink_outline(o, t=INK_T if nm not in ("_ArmourA", "_ArmourB") else .003, taper=taper))
for o in col.objects:
    flat_uv(o)

HARDWARE = []
STOCK_PARTS = ["Knife_Blade", "Knife_Hilt", "Knife_Neon"]

def set_skin(on):
    for n in STOCK_PARTS:
        o = bpy.data.objects[n]; o.hide_render = on; o.hide_set(on)
    col.hide_render = not on
    col.hide_viewport = not on

set_skin(True)
result = {"objects": [(o.name, len(o.data.polygons)) for o in col.objects], "cut_failures": CUT_FAILURES}
