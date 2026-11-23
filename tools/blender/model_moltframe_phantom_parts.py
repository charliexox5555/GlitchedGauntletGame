"""Moltframe Phantom: the Vandal v05 carapace language on the stock Phantom rifle.

Exec order in the Blender MCP session (stock Phantom_RemasterV2_v05 open):
    RIG_NAME, COL_NAME, ITEM_KEY = "Phantom_Rig", "Moltframe Phantom", "Phantom"
    exec(model_moltframe_vandal_v04.py)         # materials + plate/loft/cut helpers
    exec(<helper half of model_moltframe_vandal_v04_parts.py>)
    exec(this file)

Brief: predator-stealth alien-carapace silenced rifle pairing with Moltframe
Vandal. Swept faceted dorsal spine seating stock Phantom_Sights (AimPoint clear)
with four raked violet dorsal slots; mirrored charging/ejection channel; folded
receiver carapace wrapping into an armored magwell with swept violet chambers
and raked sinews; rear cowl with three swept thorns and selector boss; twin
fore-end crescents framing a streamlined recessed violet handguard crossed by
four raked carapace ribs; 8-sided faceted Moltframe suppressor (same stock
envelope and length) with polished silver rings, lilac band, and sleek narrow
violet vent slits; skeletal Moltframe stock with buried receiver roots; leaf-
window straight tactical magazine (bone: Mag); folded grip carapace plates.
"""
from collections import defaultdict

STOCK_SET = ["Body", "Panel", "Dark", "Metal", "Grip", "Accent", "Neon", "Brass"]
EXTRA = {
    "Neon": pbsdf("MF4 Indicator", "BA63F2", 0.0, .3)[0],
    "Brass": pbsdf("MF4 Smoke Nickel", "63637A", 1.0, .30)[0],
}
_ind = EXTRA["Neon"].node_tree.nodes["Principled BSDF"]
_ind.inputs["Emission Color"].default_value = (*_lin("BA63F2"), 1)
_ind.inputs["Emission Strength"].default_value = 2.0
SLOT_SKIN = [
    MATS[ARM], MATS[ARM], MATS[CORE], MATS[STEEL],
    MATS[GRIP], MATS[LILAC], EXTRA["Neon"], EXTRA["Brass"],
]

def retain(src_name, keep, new_name, bone="Root"):
    """Copy the components of a stock mesh that `keep(points)` accepts."""
    for o in [o for o in bpy.data.objects if o.name == new_name]:
        bpy.data.objects.remove(o)
    src = bpy.data.objects[src_name]
    me = src.data
    adj = defaultdict(set)
    for p in me.polygons:
        for i in p.vertices:
            adj[i].update(p.vertices)
    keepv, seen = set(), set()
    for i in adj:
        if i in seen:
            continue
        g, st = {i}, [i]
        while st:
            f = adj[st.pop()] - g
            g |= f
            st += list(f)
        seen |= g
        if keep([src.matrix_world @ me.vertices[j].co for j in g]):
            keepv |= g
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.index not in keepv], context="VERTS")
    for v in bm.verts:
        v.co = src.matrix_world @ v.co
    o = link(new_name, bm, bone)
    while len(o.data.materials) < len(SLOT_SKIN):
        o.data.materials.append(None)
    for i, m in enumerate(SLOT_SKIN):
        o.data.materials[i] = m
    return o


def zcut(quad, z0, z1, mat=GASKET, floor=None):
    bmc = bmesh.new()
    lo = [bmc.verts.new((x, y, z0)) for x, y in quad]
    hi = [bmc.verts.new((x, y, z1)) for x, y in quad]
    f = bmc.faces.new(lo)
    f.material_index = mat if floor is None else floor
    f = bmc.faces.new(hi)
    f.material_index = mat
    n = len(quad)
    for i in range(n):
        f = bmc.faces.new((lo[i], lo[(i + 1) % n], hi[(i + 1) % n], hi[i]))
        f.material_index = mat
    bmesh.ops.recalc_face_normals(bmc, faces=bmc.faces)
    return bmc


# ------------------------------------------------------------------ shapes
SLOT = (0.155, 0.945, 0.336, 0.412)
BORE_Z = 0.352


def zt_spine(x):
    """Top crest stays cleanly under Phantom_Sights bases (rear z .468, front z .466)."""
    if x <= -0.02:
        return 0.436
    if x <= 0.08:
        return 0.436 + (x + 0.02) / 0.10 * 0.044
    if x <= 1.59:
        return 0.480
    return 0.480 - (x - 1.59) / 0.08 * 0.048


def zb_mantle(x):
    pts = [(-1.0, 0.412), (0.945, 0.412), (1.01, 0.386), (1.59, 0.386), (1.67, 0.405)]
    for (x0, z0), (x1, z1) in zip(pts, pts[1:]):
        if x0 <= x <= x1:
            return z0 + (z1 - z0) * (x - x0) / (x1 - x0)
    return pts[-1][1]


def upper_half(x):
    zt, zb = zt_spine(x), zb_mantle(x)
    h = max(0.022, zt - zb)
    k = 1.0 if x <= 1.58 else 1.0 - (x - 1.58) / 0.09 * 0.42
    w = 0.088 if x < 0.95 else 0.085
    return [
        (0.052 * k, zb),
        (w * k, zb),
        ((w + 0.006) * k, zb + 0.22 * h),
        ((w + 0.004) * k, zb + 0.44 * h),
        (w * k * 0.84, zb + 0.72 * h),
        (0.042 * k, zt - 0.004),
        (0.028 * k, zt),
    ]


UPPER_MATS = [CORE, EDGE, ARM, EDGE, ARM, EDGE]


def build_upper():
    xs = [
        -0.178, -0.170, -0.020, 0.030, 0.080, 0.250, 0.600, 0.945,
        1.010, 1.250, 1.500, 1.580, 1.620, 1.650, 1.670,
    ]
    st = [(x, ring(upper_half(x))) for x in xs]
    x0, r0 = st[0]
    st[0] = (x0, [(y * 0.84, z - (0.006 if z > 0.41 else 0.0)) for y, z in r0])
    o = link("MFPh_UpperShell", loft(st, ring_mats(UPPER_MATS, bottom=CORE, top=ARM), cap_mat=EDGE))
    cutters = []
    # Four raked violet dorsal slots between rear sight (x .214) and front sight (x 1.491)
    for xa, xb in ((0.33, 0.49), (0.57, 0.73), (1.03, 1.18), (1.26, 1.41)):
        sl = 0.013
        cutters.append(zcut([(xa, -sl), (xb, -sl), (xb - 0.012, sl), (xa - 0.012, sl)], 0.464, 0.62, floor=VIOLET))
    # Subtle side fuller groove along upper spine flanks
    fuller = [(0.24, 0.444), (0.28, 0.451), (1.46, 0.451), (1.50, 0.444), (1.46, 0.447), (0.28, 0.447)]
    cutters += [prism(fuller, 0.079, 0.30, floor=CORE), prism(fuller, -0.079, -0.30, floor=CORE)]
    cut(o, cutters, rim=0.0018)
    return o


def build_core():
    """Dark receiver core with mirrored charging/bolt channel + magwell/trigger cuts,
    and recessed violet fluid fore-end core."""
    def rec(x):
        b = 0.162 if x > -0.10 else 0.180
        return [
            (0.052, b), (0.068, b + 0.014), (0.068, SLOT[2]),
            (0.050, SLOT[2] + 0.006), (0.050, SLOT[3] - 0.004),
            (0.068, SLOT[3] + 0.004), (0.068, 0.422), (0.050, 0.428),
        ]
    st = [(x, ring(rec(x))) for x in (-0.175, -0.100, -0.088, 0.45, 0.93, 0.96)]
    a = link("MFPh_ReceiverCore", loft(st, ring_mats([CORE] * 7, bottom=CORE, top=CORE), cap_mat=CORE))
    well = zcut([(0.535, -0.062), (0.835, -0.062), (0.835, 0.062), (0.535, 0.062)], 0.04, 0.25, mat=CORE)
    trig = zcut([(0.275, -0.014), (0.365, -0.014), (0.365, 0.014), (0.275, 0.014)], 0.08, 0.21, mat=CORE)
    cut(a, [well, trig], rim=0.0)

    # Solid dark-core magwell collar housing (front & rear walls enclosing the chute when mag drops)
    def mw_sec(x):
        return [(0.056, 0.048), (0.068, 0.060), (0.068, 0.168), (0.056, 0.175)]
    st_mw = [(0.498, ring(mw_sec(0.498))), (0.858, ring(mw_sec(0.858)))]
    mw = link("MFPh_MagwellCore", loft(st_mw, ring_mats([CORE, CORE, CORE], bottom=CORE, top=CORE), cap_mat=CORE))
    mw_hole = zcut([(0.542, -0.061), (0.828, -0.061), (0.828, 0.061), (0.542, 0.061)], 0.02, 0.20, mat=CORE)
    cut(mw, [mw_hole], rim=0.0)

    # Streamlined handguard fluid core (x = 0.95..1.645)
    def fe(k=1.0):
        return [
            (0.036 * k, 0.208), (0.062 * k, 0.224), (0.069 * k, 0.264),
            (0.069 * k, 0.368), (0.058 * k, 0.398), (0.042 * k, 0.410),
        ]
    st_fe = [(0.945, ring(fe())), (1.605, ring(fe())), (1.648, ring(fe(0.84)))]
    b = link("MFPh_ForendFluid", loft(st_fe, ring_mats([GASKET, GASKET, VIOLET, VIOLET, GASKET],
                                                       bottom=GASKET, top=CORE), cap_mat=CORE))
    return a, mw, b


def build_carapace():
    """Swept folded carapace under the charging channel (x=0.14..0.95) with
    a long recessed violet chamber, two raked sinews, armored magwell flank
    plate with diagonal violet slit, rear cowl with thorns, and selector boss."""
    # Main receiver side carapace plate
    out = [
        (0.158, 0.334), (0.930, 0.334), (0.962, 0.295), (0.946, 0.215),
        (0.862, 0.168), (0.852, 0.044), (0.525, 0.044), (0.485, 0.162),
        (0.195, 0.162), (0.148, 0.215),
    ]
    o = link("MFPh_Carapace", solid_plate(out, 0.066, 0.090, ch=0.005,
                                          fold=((0.15, 0.28), (0.95, 0.29), 0.010, 0.14)))
    # Upper receiver fluid chamber
    win_u = [
        (0.240, 0.242), (0.315, 0.304), (0.500, 0.312), (0.835, 0.310),
        (0.905, 0.280), (0.895, 0.232), (0.810, 0.205), (0.340, 0.205), (0.260, 0.222),
    ]
    # Lower diagonal magwell fluid window
    win_m = [
        (0.555, 0.155), (0.785, 0.158), (0.812, 0.125), (0.790, 0.070),
        (0.605, 0.070), (0.555, 0.112),
    ]
    cut(o, [prism(win_u, 0.072, 0.30), prism(win_m, 0.073, 0.30)], rim=0.0025)
    mirror_apply(o)

    # Two raked carapace sinews crossing the upper receiver fluid window
    sb = []
    for xa, xb in ((0.445, 0.515), (0.665, 0.735)):
        path = [
            (xa - 0.006, 0.069, 0.196),
            ((xa + xb) * 0.5, 0.075, 0.258),
            (xb + 0.006, 0.069, 0.320),
        ]
        sb.append(sweep(path, (0, 1, 0), [0.030, 0.021, 0.030], [0.022, 0.019, 0.022]))
    sin = join("MFPh_Sinews", sb)
    mirror_apply(sin)

    # Rear cowl notched cleanly around Phantom_FireSelector (x .087..0.136, z .209..0.299)
    rc_out = [
        (-0.175, 0.412), (0.152, 0.412), (0.152, 0.315), (0.068, 0.315),
        (0.068, 0.195), (0.150, 0.195), (0.145, 0.164), (-0.110, 0.168), (-0.175, 0.190),
    ]
    rc = link("MFPh_RearCowl", solid_plate(rc_out, 0.064, 0.088, ch=0.0045,
                                           fold=((-0.17, 0.31), (0.14, 0.33), 0.008, 0.12)))
    mirror_apply(rc)

    # Rear-swept carapace thorns off the upper rear shoulders
    th = []
    for xb, zb, ln in ((0.06, 0.398, 0.105), (-0.01, 0.388, 0.115), (-0.08, 0.378, 0.120)):
        path = [
            (xb, 0.080, zb),
            (xb - ln * 0.45, 0.089, zb + 0.008),
            (xb - ln * 0.80, 0.089, zb + 0.016),
            (xb - ln, 0.085, zb + 0.022),
        ]
        th.append(sweep(path, (0, 1, 0.3), [0.038, 0.027, 0.012, 0.003], [0.015, 0.013, 0.007, 0.002]))
    thorns = join("MFPh_Thorns", th)
    mirror_apply(thorns)

    # Octagonal boss seating Phantom_FireSelector cleanly
    sel = bpy.data.objects["Phantom_FireSelector"]
    pts = [sel.matrix_world @ Vector(c) for c in sel.bound_box]
    cx = sum(p.x for p in pts) / 8.0
    cz = sum(p.z for p in pts) / 8.0
    r = 0.044
    boss_out = [(cx + r * math.cos(a), cz + r * math.sin(a))
                for a in [math.radians(22.5 + 45 * i) for i in range(8)]]
    boss = link("MFPh_SelectorBoss", solid_plate(boss_out, 0.062, 0.077, ch=0.0035))
    mirror_apply(boss)
    return o, sin, rc, thorns, boss


def build_forend():
    """Twin predator crescents + four sleek raked carapace ribs over the glowing
    violet handguard + lower keel + beveled suppressor collar."""
    # Rear crescent at receiver/handguard junction (clears Phantom_CharmLoop at x=.985, z=.221..263!)
    ca_out = [
        (0.935, 0.410), (0.995, 0.410), (1.045, 0.365), (1.058, 0.310),
        (1.035, 0.268), (0.990, 0.278), (1.010, 0.318), (0.995, 0.365),
    ]
    ca = link("MFPh_CrescentA", solid_plate(ca_out, 0.068, 0.094, ch=0.0045,
                                            fold=((0.96, 0.41), (1.03, 0.27), 0.006, 0.07)))
    mirror_apply(ca)

    # Front crescent framing the suppressor joint (x=1.55..1.65)
    cb_out = [
        (1.545, 0.412), (1.605, 0.412), (1.652, 0.365), (1.662, 0.305),
        (1.640, 0.238), (1.585, 0.205), (1.535, 0.198), (1.568, 0.232),
        (1.604, 0.278), (1.612, 0.325), (1.595, 0.375),
    ]
    cb = link("MFPh_CrescentB", solid_plate(cb_out, 0.068, 0.094, ch=0.0045,
                                            fold=((1.57, 0.41), (1.64, 0.21), 0.006, 0.07)))
    win_cb = [(1.618, 0.292), (1.630, 0.338), (1.642, 0.312), (1.630, 0.268)]
    cut(cb, [prism(win_cb, 0.076, 0.30)], rim=0.002)
    mirror_apply(cb)

    # Five sleek raked carapace ribs sweeping across the violet handguard core
    zc, a, b = 0.306, 0.104, 0.072
    bms = []
    for i, x0 in enumerate((1.145, 1.245, 1.345, 1.445, 1.545)):
        ph = [math.radians(d) for d in (76, 58, 36, 12, -12, -36, -60, -88)]
        path, outw, wid, th = [], [], [], []
        for p in ph:
            s = (math.sin(p) + 1.0) / 2.0
            path.append((x0 - 0.105 * s, b * math.cos(p) - 0.002, zc + a * math.sin(p)))
            outw.append((0, math.cos(p) / b, math.sin(p) / a))
            taper = 1.0 - 0.42 * max(0.0, (s - 0.80) / 0.20)
            wid.append(0.058 * taper * (1.0 - 0.10 * i / 4.0))
            th.append(0.014 * taper)
        bms.append(sweep(path, outw, wid, th))
    ribs = join("MFPh_ForendRibs", bms)
    mirror_apply(ribs)

    # Lower armored keel under handguard
    def keel(k=1.0):
        return [(0.030 * k, 0.194), (0.052 * k, 0.204), (0.056 * k, 0.222), (0.036 * k, 0.234)]
    st_k = [(0.945, ring(keel(0.86))), (0.980, ring(keel())), (1.565, ring(keel())), (1.635, ring(keel(0.70)))]
    st_k[-1] = (st_k[-1][0], [(y, z + 0.012) for y, z in st_k[-1][1]])
    keel_o = link("MFPh_ForendKeel", loft(st_k, ring_mats([ARM, ARM, ARM], bottom=ARM, top=ARM), cap_mat=EDGE))

    # Front collar cap into suppressor neck
    def col_sec(k=1.0):
        return [(0.030 * k, 0.222), (0.058 * k, 0.244), (0.066 * k, 0.312), (0.058 * k, 0.398), (0.034 * k, 0.420)]
    st_c = [(1.605, ring(col_sec(0.95))), (1.648, ring(col_sec(0.92))), (1.682, ring(col_sec(0.76)))]
    col_o = link("MFPh_Collar", loft(st_c, ring_mats([ARM, ARM, ARM, ARM], bottom=ARM, top=ARM), cap_mat=EDGE))
    return ca, cb, ribs, keel_o, col_o


def build_suppressor():
    """Sleek 8-sided faceted Moltframe carapace suppressor matching the exact
    stock Phantom suppressor envelope (x=1.645..2.502, bore z=0.352, r~0.080),
    with polished silver bevel steps, lilac collar ring, and sleek narrow
    recessed violet side vent slits."""
    n = 8
    def oct_ring(x, r):
        # 22.5 deg phase puts crisp vertical flat faces directly on +Y / -Y and +Z / -Z!
        return [
            (x, r * math.cos(math.radians(22.5 + 45 * i)), BORE_Z + r * math.sin(math.radians(22.5 + 45 * i)))
            for i in range(n)
        ]

    prof = [
        (1.645, 0.056), (1.740, 0.058), (1.758, 0.076),
        (1.935, 0.078), (1.946, 0.084), (1.968, 0.084), (1.978, 0.078),
        (2.435, 0.078), (2.452, 0.068), (2.468, 0.075), (2.490, 0.070), (2.504, 0.054),
    ]
    st = [oct_ring(x, r) for x, r in prof]
    o = link("MFPh_Suppressor", loft3(st, [ARM] * n, caps=(True, True), cap_mat=CORE))

    # Paint the stepped bevel rings EDGE and the central ring LILAC
    for p in o.data.polygons:
        xs = [o.data.vertices[i].co.x for i in p.vertices]
        cx = sum(xs) / len(xs)
        dx = max(xs) - min(xs)
        if 1.944 <= cx <= 1.970 and dx < 0.028:
            p.material_index = LILAC
        elif dx < 0.020 and (1.740 <= cx <= 1.762 or 2.432 <= cx <= 2.495):
            p.material_index = EDGE

    # Cut sleek narrow violet side vent slits on BOTH flat side faces (+Y / -Y) + dark bore cavity
    slit = [
        (2.015, BORE_Z - 0.012), (2.045, BORE_Z + 0.016), (2.345, BORE_Z + 0.016),
        (2.375, BORE_Z - 0.012), (2.345, BORE_Z - 0.018), (2.045, BORE_Z - 0.018),
    ]
    # Flat side faces of an 8-gon at r=0.078 lie at |y| = 0.078 * cos(22.5 deg) = 0.0721
    bore_st = [oct_ring(x, 0.024) for x in (2.410, 2.510)]
    cutters = [
        prism(slit, 0.060, 0.20),
        prism(slit, -0.060, -0.20),
        loft3(bore_st, [CORE] * n, caps=(True, True), cap_mat=CORE),
    ]
    cut(o, cutters, rim=0.0022)
    return o


def build_stock():
    """Skeletal Moltframe rifle stock (x=-0.11..-1.10, z=-0.064..0.410) with
    BOTH strut fronts deeply buried inside the rear receiver core."""
    path, wid, th = [], [], []
    for x in (-0.11, -0.19, -0.30, -0.45, -0.65, -0.86, -0.99):
        t = min(1.0, (-0.11 - x) / 0.28)
        zc = 0.305 + (0.376 - 0.305) * (t ** 0.7)
        path.append((x, 0.0, zc))
        wid.append(0.155 - (0.155 - 0.060) * (t ** 0.7))
        th.append(0.058 - 0.010 * t)
    top = link("MFPh_StockTop", sweep(path, (0, 1, 0), wid, th, STRUT, STRUT_M))
    win = [(-0.28, 0.362), (-0.36, 0.376), (-0.91, 0.378), (-0.96, 0.368), (-0.91, 0.358), (-0.36, 0.352)]
    cut(top, [prism(win, 0.036, 0.30), prism(win, -0.036, -0.30)], rim=0.002)

    # Lower strut front deeply buried inside rear receiver core (x = -0.09, z = 0.252)
    p0, p1 = Vector((-0.09, 0.0, 0.252)), Vector((-1.01, 0.0, -0.032))
    path_l = [p0.lerp(p1, t) for t in (0.0, 0.15, 0.5, 0.85, 1.0)]
    low = link("MFPh_StockLow", sweep(path_l, (0, 1, 0), [0.068, 0.050, 0.048, 0.050, 0.058],
                                      [0.038, 0.035, 0.033, 0.035, 0.038], STRUT, STRUT_M))
    win2 = [(-0.36, 0.168), (-0.40, 0.156), (-0.90, 0.005), (-0.94, -0.002), (-0.91, -0.016), (-0.38, 0.144)]
    cut(low, [prism(win2, 0.021, 0.30), prism(win2, -0.021, -0.30)], rim=0.002)

    out = [
        (-0.985, 0.412), (-1.045, 0.412), (-1.088, 0.394), (-1.110, 0.345),
        (-1.095, 0.280), (-1.110, 0.195), (-1.098, 0.105), (-1.110, 0.020),
        (-1.090, -0.045), (-1.062, -0.070), (-1.002, -0.070), (-0.985, -0.042),
    ]
    butt = link("MFPh_Butt", solid_plate(out, 0.0, 0.064, ch=0.0075, open_inner=True))
    mirror_apply(butt, merge=True)
    slit = [
        (-1.012, 0.340), (-1.044, 0.354), (-1.072, 0.300), (-1.080, 0.045),
        (-1.064, -0.022), (-1.040, -0.046), (-1.024, -0.012), (-1.032, 0.045), (-1.028, 0.295),
    ]
    cut(butt, [prism(slit, 0.050, 0.30), prism(slit, -0.050, -0.30)], rim=0.0028)
    sb = []
    for zc in (0.20, 0.06):
        sb.append(sweep([(-1.016, 0.051, zc + 0.018), (-1.048, 0.053, zc), (-1.076, 0.051, zc - 0.018)],
                        (0, 1, 0), [0.018, 0.014, 0.018], [0.014, 0.013, 0.014]))
    sn = join("MFPh_ButtSinews", sb)
    mirror_apply(sn)
    return top, low, butt, sn


def build_mag():
    """Straight tactical Phantom magazine (bone: Mag, x=0.555..0.818, z=-0.30..0.22)
    with Moltframe faceted armor, beveled floorplate, recessed leaf violet
    window, and two raked carapace sinews."""
    out = [
        (0.566, 0.215), (0.562, 0.060), (0.558, -0.100), (0.552, -0.245),
        (0.542, -0.268), (0.548, -0.302), (0.822, -0.302), (0.830, -0.268),
        (0.818, -0.242), (0.814, -0.100), (0.812, 0.060), (0.808, 0.215),
    ]
    o = link("MFPh_Magazine", solid_plate(out, 0.0, 0.056, ch=0.007, open_inner=True), bone="Mag")
    mirror_apply(o, merge=True)

    win = [
        (0.686, 0.065), (0.618, 0.018), (0.606, -0.110), (0.615, -0.215),
        (0.686, -0.250), (0.758, -0.215), (0.768, -0.110), (0.756, 0.018),
    ]
    cut(o, [prism(win, 0.041, 0.30), prism(win, -0.041, -0.30)], rim=0.0028)

    sb = []
    for zc in (-0.048, -0.148):
        sb.append(sweep([(0.602, 0.042, zc + 0.024), (0.686, 0.044, zc), (0.772, 0.042, zc - 0.024)],
                        (0, 1, 0), [0.020, 0.014, 0.020], [0.016, 0.014, 0.016]))
    sn = join("MFPh_MagSinews", sb, bone="Mag")
    mirror_apply(sn)
    return o, sn


def build_grip():
    """Folded carapace side plates hugging Phantom_Grip with diamond violet window."""
    rows = [
        (-0.075, 0.130, 0.118, 0.078),
        (-0.092, 0.078, 0.102, 0.024),
        (-0.108, 0.026, 0.084, -0.030),
        (-0.125, -0.026, 0.066, -0.084),
        (-0.142, -0.078, 0.048, -0.138),
        (-0.158, -0.130, 0.032, -0.192),
        (-0.174, -0.182, 0.020, -0.244),
        (-0.186, -0.232, 0.012, -0.285),
    ]
    bk = [lerp2((bx, bz), (fx, fz), 0.08) for bx, bz, fx, fz in rows]
    fw = [lerp2((bx, bz), (fx, fz), 0.90) for bx, bz, fx, fz in rows]
    tip = lerp2((-0.192, -0.282), (0.015, -0.314), 0.30)
    out = [(-0.060, 0.155), (0.125, 0.132)] + fw + [tip] + list(reversed(bk))
    o = link("MFPh_GripPlate", solid_plate(out, 0.054, 0.068, ch=0.0035,
                                           fold=((-0.08, 0.14), (-0.17, -0.25), 0.0045, 0.11)))
    w1 = [lerp2((bx, bz), (fx, fz), t) for (bx, bz, fx, fz), t in zip(rows[1:6], (0.34, 0.30, 0.28, 0.30, 0.34))]
    w2 = [lerp2((bx, bz), (fx, fz), t) for (bx, bz, fx, fz), t in zip(rows[1:6], (0.54, 0.60, 0.62, 0.60, 0.54))]
    w = [lerp2(w1[0], w2[0], 0.5)] + w1[1:-1] + [lerp2(w1[-1], w2[-1], 0.5)] + list(reversed(w2[1:-1]))
    cut(o, [prism(w, 0.0595, 0.30)], rim=0.0022)
    mirror_apply(o)
    return o


# ------------------------------------------------------------------- build
hw = {}
# Retain Phantom_Grip in full (both charcoal grip AND stock trigger guard!)
hw["grip"] = retain("Phantom_Grip", lambda P: True, "MFPh_GripHardware")

parts = {}
parts["upper"] = build_upper()
parts["core"] = build_core()
parts["carapace"] = build_carapace()
parts["forend"] = build_forend()
parts["supp"] = build_suppressor()
parts["stock"] = build_stock()
parts["mag"] = build_mag()
parts["grip"] = build_grip()

for o in col.objects:
    flat_uv(o)

HARDWARE = [
    "Phantom_Sights", "Phantom_ChargingHandle", "Phantom_Bolt",
    "Phantom_Trigger", "Phantom_FireSelector", "Phantom_CharmLoop",
]
STOCK_PARTS = [
    "Phantom_Neon", "Phantom_Receiver", "Phantom_Handguard", "Phantom_Rail",
    "Phantom_Suppressor", "Phantom_Grip", "Phantom_Stock", "Phantom_Pins", "Phantom_Mag",
]

def set_skin(on):
    for n in HARDWARE:
        o = bpy.data.objects[n]
        for i, sl in enumerate(o.material_slots):
            if i < 8:
                sl.material = SLOT_SKIN[i] if on else bpy.data.materials[STOCK_SET[i]]
    for n in STOCK_PARTS:
        o = bpy.data.objects[n]
        o.hide_render = on
        o.hide_set(on)
    col.hide_render = not on
    col.hide_viewport = not on

set_skin(True)
result = {
    "objects": [(o.name, len(o.data.polygons)) for o in col.objects],
    "cut_failures": list(CUT_FAILURES),
}
