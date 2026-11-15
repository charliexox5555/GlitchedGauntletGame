"""Giltfold Vandal v02: full origami shell (stock Vandal open). Exec after
model_giltfold_kit.py and model_vandal_shell_base.py (run_sfg KIT chain).

Owner 2026-11-14: v01 (fold plates over the stock gun) read as a reskin.
v02 follows the line's own concept board (ivory fold, slate shadow, ink
lacquer with the champagne wave pattern, champagne foil bar pairs) at the
quality bar of the SilkLeaf reference, original shapes: a long folded paper
upper shell whose faces break into triangles, a paper spike over the barrel
and a lower spike under it, folded fins, patterned lacquer showing between
the paper plates, a pleated fan stock, an origami magazine with a folded boat
base, a folded grip and a twisted paper muzzle shroud. Every fold is a flat
triangle (the meshes are triangulated on purpose, so each fold reads).
Fit, channel and moving parts per model_vandal_shell_base."""

IV, SL, INK, WALL, PAT, GRP, PEW, FOIL = 0, 1, 2, 3, 4, 5, 6, 7
P = "GFV"

def fold_tris(o, keep_quads_flat=True):
    """Triangulate so every fold is its own flat facet."""
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="FIXED", ngon_method="BEAUTY")
    bm.to_mesh(o.data); bm.free()
    o.data.update()
    return o

def zt_top(x):
    if x <= .16: return .408
    if x <= .26: return .408 + (x - .16) / .10 * .050
    return .458

def build_upper():
    """Long folded paper shell, read as two planes: an ivory upper plane
    over a slate shadow plane, split by ONE long shallow diagonal crease that
    climbs from the rear to the front (the line's signature fold); a dark
    lacquer rail strip on top frames the sight picture; past the collar the
    shell narrows into a paper spike over the barrel."""
    xs = [-.178, -.17, .0, .16, .26, .60, 1.00, 1.36, 1.64, 1.74, 1.84, 1.93]
    st = []
    for x in xs:
        zt = zt_top(x)
        zb = .356 if x < 1.06 else .350
        k = 1.0
        if x > 1.64:
            t = (x - 1.64) / (1.93 - 1.64)
            k = 1 - .86 * t
            zt = .458 - .046 * t; zb = .350 + .044 * t
        c = min(1.0, max(0.0, (x + .17) / 1.80))
        zc = zb + .026 + (zt - .040 - (zb + .026)) * c          # the crease climbs front-ward
        half = [(.050 * k, zb), (.086 * k, zb), (.095 * k, zb + .016), (.094 * k, zc), (.070 * k, zt - .012),
                (.030 * k, zt)]
        st.append((x, ring(half)))
    x0, r0 = st[0]
    st[0] = (x0, [(y * .84, z) for y, z in r0])
    o = link(P + "_Upper", loft(st, ring_mats([INK, SL, SL, IV, IV], bottom=INK, top=INK), cap_mat=SL))
    return o

def build_handguard():
    """Lower handguard: a patterned lacquer core under folded paper skirts
    that end in a pointed lower spike under the barrel."""
    def fe(k=1.0):
        return [(.036 * k, .176), (.058 * k, .190), (.064 * k, .232), (.064 * k, .318), (.056 * k, .348), (.040 * k, .358)]
    st = [(1.06, ring(fe())), (1.64, ring(fe())), (1.68, ring(fe(.86)))]
    core = link(P + "_HandguardCore", loft(st, ring_mats([INK, PAT, PAT, PAT, INK], bottom=INK, top=INK), cap_mat=INK))
    # one folded handguard plate: ivory over slate along a diagonal crease,
    # a long wave-pattern window, running forward into the lower paper spike
    out = [(1.06, .350), (1.64, .350), (1.70, .346), (1.93, .214), (1.66, .188), (1.10, .170), (1.06, .200)]
    bm = solid_plate(out, .060, .078, ch=.004, fold=((1.06, .31), (1.93, .214), .008, .10))
    for f in bm.faces:
        c = f.calc_center_median()
        if c.y > .069 and f.normal.y > .3 and f.material_index == IV:
            d = (c.x - 1.06) * (.214 - .31) - (c.z - .31) * (1.93 - 1.06)
            f.material_index = IV if d < 0 else SL
    o = link(P + "_HandguardPlate", bm)
    win = [(1.12, .300), (1.50, .316), (1.60, .304), (1.52, .232), (1.14, .222)]
    cut(o, [prism(win, .0625, .3, floor=PAT, side=WALL)], rim=.0024)
    mirror_apply(o)
    return core, o

def build_receiver_sides():
    """Lower receiver: one big folded paper triangle over the magazine well,
    a patterned lacquer panel behind it, a slate rear plate."""
    base = [(.165, .266), (.845, .266), (.90, .262), (.948, .205), (.93, .150), (.825, .150), (.79, .104), (.49, .104),
            (.45, .150), (.215, .150), (.150, .205)]
    pan = link(P + "_LacquerPanel", solid_plate(base, .066, .078, ch=.003, mat=PAT))
    mirror_apply(pan)
    tri = [(.40, .266), (.845, .266), (.90, .262), (.948, .205), (.93, .150), (.825, .150), (.79, .104), (.56, .104)]
    t = link(P + "_FoldTri", solid_plate(tri, .074, .090, ch=.004, fold=((.40, .266), (.80, .104), .010, .12)))
    mirror_apply(t)
    cowl = [(-.176, .370), (.004, .370), (-.012, .30), (-.04, .192), (-.10, .168), (-.176, .178)]
    c = link(P + "_RearCowl", solid_plate(cowl, .066, .085, ch=.004, fold=((-.18, .370), (.0, .19), .008, .10)))
    mirror_apply(c)
    fr = [(.95, .344), (1.07, .344), (1.07, .176), (1.00, .162), (.955, .200)]
    f = link(P + "_FrontBlock", solid_plate(fr, .066, .084, ch=.004, mat=SL))
    mirror_apply(f)
    return pan, fold_tris(t), fold_tris(c), f

def build_upper_blade():
    """A second paper layer: a long pointed blade lapped over the upper
    shell's side, ending in a point near the front sight."""
    out = [(.30, .432), (1.40, .446), (1.62, .436), (1.40, .424), (.42, .414)]
    o = link(P + "_UpperBlade", solid_plate(out, .072, .101, ch=.0025, fold=((.30, .432), (1.62, .436), .003, .02)))
    mirror_apply(o)
    return o

def build_selector_ring():
    sel = bpy.data.objects["Vandal_FireSelector"]
    pts = [sel.matrix_world @ Vector(c) for c in sel.bound_box]
    cx = sum(p.x for p in pts) / 8; cz = sum(p.z for p in pts) / 8
    out = [(cx + .050 * math.cos(a), cz + .050 * math.sin(a)) for a in [math.radians(22.5 + 45 * i) for i in range(8)]]
    o = link(P + "_SelectorRing", solid_plate(out, .064, .0885, ch=.004, mat=PEW))
    mirror_apply(o)
    return o

def build_stock():
    """Folded paper stock: two broad planes (ivory over slate) meeting at a
    diagonal crease, one large wave-pattern panel set into the side, and an
    accordion-pleated butt."""
    out = [(-.150, .405), (-1.130, .424), (-1.150, .408), (-1.150, -.150), (-1.100, -.176), (-1.020, -.150),
           (-.700, .040), (-.420, .160), (-.150, .182)]
    bm = solid_plate(out, 0, .066, ch=.006, open_inner=True, fold=((-.15, .30), (-1.15, .02), .010, .16))
    mid = .033
    for f in bm.faces:
        c = f.calc_center_median()
        if c.y > mid and f.normal.y > .3 and f.material_index == IV:
            d = (c.x + .15) * (.02 - .30) - (c.z - .30) * (-1.15 + .15)
            f.material_index = SL if d > 0 else IV
    o = link(P + "_Stock", bm)
    mirror_apply(o, merge=True)
    win = [(-.36, .362), (-1.06, .380), (-1.06, .060), (-.98, .010), (-.62, .170), (-.44, .262)]
    cut(o, [prism(win, .058, .3, floor=PAT, side=WALL), prism(win, -.058, -.3, floor=PAT, side=WALL)], rim=.003)
    # accordion butt: pleats alternate ridge / valley down the butt face
    zs = [.424, .330, .236, .142, .048, -.046, -.140, -.180]
    bmb = bmesh.new()
    def pv(x, y, z):
        return bmb.verts.new((x, y, z))
    ridge = [i % 2 == 0 for i in range(len(zs))]
    L_, R_ = [], []
    for i, z in enumerate(zs):
        xo = -1.262 if ridge[i] else -1.232
        L_.append((pv(-1.140, .070, z), pv(xo, .070, z)))
        R_.append((pv(-1.140, -.070, z), pv(xo, -.070, z)))
    for i in range(len(zs) - 1):
        a, b_ = L_[i], L_[i + 1]; c, d = R_[i], R_[i + 1]
        m = IV if i % 2 == 0 else SL
        for quad in ((a[1], b_[1], d[1], c[1]),):
            f = bmb.faces.new(quad); f.material_index = m
        f = bmb.faces.new((a[0], a[1], b_[1], b_[0])); f.material_index = SL
        f = bmb.faces.new((c[0], d[0], d[1], c[1])); f.material_index = SL
        f = bmb.faces.new((a[0], b_[0], d[0], c[0])); f.material_index = SL
    f = bmb.faces.new((L_[0][0], R_[0][0], R_[0][1], L_[0][1])); f.material_index = IV
    f = bmb.faces.new((L_[-1][1], R_[-1][1], R_[-1][0], L_[-1][0])); f.material_index = SL
    bmesh.ops.recalc_face_normals(bmb, faces=bmb.faces)
    butt = link(P + "_ButtPleats", bmb)
    return o, fold_tris(butt)

def build_mag():
    """Full folded magazine: a solid paper body in two planes (diagonal
    crease), a wave-pattern band along the front edge, a folded boat base."""
    back = [(.47, .199), (.462, .12), (.49, .031), (.513, -.027), (.536, -.085), (.565, -.141),
            (.593, -.197), (.626, -.252), (.658, -.306), (.680, -.340)]
    front = [(.990, -.318), (.93, -.268), (.887, -.217), (.851, -.164), (.817, -.11), (.788, -.054),
             (.759, .001), (.737, .06), (.717, .12), (.708, .199)]
    bm = solid_plate(back + [(.70, -.330), (.98, -.300)] + front, 0, .058, ch=.005, open_inner=True,
                     fold=((.47, .12), (.84, -.30), .003, .10))
    for f in bm.faces:
        c = f.calc_center_median()
        if c.y > .03 and f.normal.y > .3 and f.material_index == IV:
            d = (c.x - .47) * (-.30 - .12) - (c.z - .12) * (.84 - .47)
            f.material_index = IV if d > 0 else SL
    body = link(P + "_Mag", bm, bone="Mag")
    mirror_apply(body, merge=True)
    band = [(.728, .090), (.744, .040), (.778, -.040), (.822, -.120), (.872, -.190), (.930, -.252), (.962, -.282),
            (.920, -.282), (.856, -.222), (.806, -.150), (.762, -.068), (.726, .010), (.712, .090)]
    band = clip_poly(band, 0.0, -1.0, -.020)                      # stays well below the receiver panels
    # one solid strip wrapping the front edge (two mirrored slabs left a see-through
    # slot where the strip runs past the magazine's front: read as a hole in Roblox)
    st_ = link(P + "_MagBand", solid_plate(band, -.0700, .0700, ch=.002, mat=PAT), bone="Mag")
    for f in st_.data.polygons:                        # slate rim round the lacquer strip
        if f.material_index == EDGE:
            f.material_index = SL
    boat = [(.62, -.270), (.70, -.300), (.99, -.290), (1.07, -.330), (.96, -.420), (.72, -.430), (.64, -.360)]
    b = link(P + "_MagBoat", solid_plate(boat, 0, .066, ch=.005, open_inner=True, fold=((.62, -.27), (1.07, -.33), .008, .08)),
             bone="Mag")
    mirror_apply(b, merge=True)
    return body, fold_tris(b)

def build_grip():
    hull = vandal_grip_outline(.002)
    core = link(P + "_GripCore", solid_plate(hull, 0, .060, ch=.005, mat=PAT, open_inner=True), bone="Root")
    mirror_apply(core, merge=True)
    rear = [(-.190, .150), (-.04, .150), (-.10, -.05), (-.196, -.200), (-.205, -.300), (-.150, -.312), (-.10, -.24)]
    a = solid_plate(rear, .058, .068, ch=.004, fold=((-.19, .15), (-.15, -.30), .006, .08))
    toe = [(-.150, -.200), (.060, -.235), (.065, -.300), (-.160, -.318)]
    b = solid_plate(toe, .058, .070, ch=.004, mat=IV)
    o = join(P + "_GripWrap", [a, b])
    mirror_apply(o)
    return core, fold_tris(o)

def build_muzzle():
    """Twisted four-sided paper shroud (each ring turned 45 degrees)."""
    rings = []
    for i, (x, r) in enumerate(((2.384, .050), (2.47, .056), (2.56, .048), (2.647, .034))):
        a0 = math.radians(45 * i)
        rings.append([(x, r * math.cos(a0 + math.pi / 2 * j), .285 + r * math.sin(a0 + math.pi / 2 * j)) for j in range(4)])
    o = link(P + "_Shroud", loft3(rings, [IV, SL, IV, SL], cap_mat=INK))
    return fold_tris(o)

def build_collar():
    def sec(k):
        return [(.030 * k, .232), (.054 * k, .248), (.060 * k, .300), (.054 * k, .352), (.030 * k, .372)]
    st = [(1.700, ring(sec(.90))), (1.712, ring(sec(1.0))), (1.735, ring(sec(1.0))), (1.75, ring(sec(.86)))]
    return link(P + "_FoilCollar", loft(st, ring_mats([FOIL] * 4, bottom=FOIL, top=FOIL), cap_mat=FOIL))

def build_front_sight_cheeks():
    out = [(1.945, .224), (2.10, .224), (2.112, .252), (2.098, .352), (2.062, .374), (1.958, .374), (1.940, .330)]
    o = link(P + "_SightCheeks", solid_plate(out, .0575, .068, ch=.0035, fold=((1.94, .224), (2.11, .374), .006, .08)))
    mirror_apply(o)
    return fold_tris(o)

# ------------------------------------------------------------------ build
vandal_hide_stock()
parts = {}
parts["core"] = vandal_core(PAT, P + "_Core")
parts["kept"] = vandal_retained(P)
parts["barrel"] = vandal_barrel(P, PEW)
parts["upper"] = build_upper()
parts["hg"] = build_handguard()
parts["blade"] = build_upper_blade()
parts["sides"] = build_receiver_sides()
parts["sel"] = build_selector_ring()
parts["stock"] = build_stock()
parts["mag"] = build_mag()
parts["grip"] = build_grip()
parts["shroud"] = build_muzzle()
parts["collar"] = build_collar()
parts["fs"] = build_front_sight_cheeks()
parts["round"] = vandal_round_bands(P, [(.532, .016, IV, .010), (.580, .006, FOIL, 0.0)])   # smoked pewter case, ivory diagonal band, champagne stripe
up = parts["upper"]; tri = parts["sides"][1]; hg = parts["hg"][1]
parts["foil"] = [foil_on(P + "_FoilRear", tri, .70, .232, length=.075),
                 foil_on(P + "_FoilUpper", up, .52, .405, length=.07, angle=-.10),
                 foil_on(P + "_FoilStock", parts["stock"][0], -.26, .330, length=.06, angle=.02),
                 foil_on(P + "_FoilMag", parts["mag"][0], .60, -.06, length=.05, bone="Mag", angle=1.25)]
for o in col.objects:
    flat_uv(o)

HARDWARE = list(VANDAL_KEEP)
STOCK_PARTS = list(VANDAL_HIDE)
set_skin = vandal_set_skin_factory(lambda n: DARK_SKIN if n in ("Vandal_RearSight", "Vandal_FrontSight") else SLOT_SKIN)
set_skin(True)
result = {"objects": [(o.name, len(o.data.polygons)) for o in col.objects], "cut_failures": CUT_FAILURES}
