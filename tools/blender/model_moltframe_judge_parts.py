"""Moltframe Judge: the Vandal v05 carapace language on the stock Judge shotgun.

Exec order in the Blender MCP session (stock Judge_RemasterV2_v05 open):
    RIG_NAME, COL_NAME, ITEM_KEY = "Judge_Rig", "Moltframe Judge", "Judge"
    exec(model_moltframe_vandal_v04.py)         # materials + plate/loft/cut helpers
    exec(<helper half of model_moltframe_vandal_v04_parts.py>)
    exec(this file)

Brief: heavy alien-carapace auto-shotgun. Swept faceted dorsal spine staying
below the top-mounted charging handle (z .632) and sights (z .628); bold
folded side carapace over the slab receiver with a wide recessed violet fluid
chamber crossed by three raked sinew ribs (right side cleanly recessed for the
ejection bolt); raked overlapping carapace fore-end ribs wrapping a glowing
violet fore-end core; heavy faceted hexagonal choke muzzle; iconic 16-sided
Moltframe wheel-drum (bone: Mag) with perimeter armor cleats, four recessed
violet fluid arc-windows on both flat side faces, and a hexagonal lilac alloy
hub; skeletal Moltframe shotgun stock with buried receiver roots and violet
slotted buttpad; folded grip plates with diamond fluid window.
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
BORE_Z = 0.5022
DRUM_X, DRUM_Z = 0.840, -0.034


def zt_spine(x):
    """Top crest stays cleanly under ChargingHandle (z .632) and Sights (z .628)."""
    if x <= -0.12:
        return 0.585
    if x <= 0.14:
        return 0.585 + (x + 0.12) / 0.26 * 0.044
    if x <= 1.88:
        return 0.629
    return 0.629 - (x - 1.88) / 0.10 * 0.046


def zb_mantle(x):
    pts = [(-1.0, 0.530), (1.22, 0.530), (1.30, 0.495), (1.88, 0.495), (1.98, 0.535)]
    for (x0, z0), (x1, z1) in zip(pts, pts[1:]):
        if x0 <= x <= x1:
            return z0 + (z1 - z0) * (x - x0) / (x1 - x0)
    return pts[-1][1]


def upper_half(x):
    zt, zb = zt_spine(x), zb_mantle(x)
    h = max(0.025, zt - zb)
    k = 1.0 if x <= 1.86 else 1.0 - (x - 1.86) / 0.12 * 0.42
    w = 0.102 if x < 1.26 else 0.094
    return [
        (0.060 * k, zb),
        (w * k, zb),
        ((w + 0.008) * k, zb + 0.24 * h),
        ((w + 0.006) * k, zb + 0.44 * h),
        (w * k * 0.86, zb + 0.72 * h),
        (0.052 * k, zt - 0.006),
        (0.036 * k, zt),
    ]


UPPER_MATS = [CORE, EDGE, ARM, EDGE, ARM, EDGE]


def build_upper():
    xs = [
        -0.185, -0.175, -0.120, 0.0, 0.140, 0.350, 0.700, 1.120,
        1.220, 1.300, 1.550, 1.860, 1.910, 1.950, 1.980,
    ]
    st = [(x, ring(upper_half(x))) for x in xs]
    x0, r0 = st[0]
    st[0] = (x0, [(y * 0.84, z - (0.006 if z > 0.56 else 0.0)) for y, z in r0])
    o = link("MFJ_UpperShell", loft(st, ring_mats(UPPER_MATS, bottom=CORE, top=ARM), cap_mat=EDGE))
    cutters = []
    # Dorsal violet slots fore of ChargingHandle (x > 1.15) and aft of RearSight (x < 0.14)
    for xa, xb in ((1.18, 1.34), (1.40, 1.56), (1.62, 1.75)):
        sl = 0.015
        cutters.append(zcut([(xa, -sl), (xb, -sl), (xb - 0.014, sl), (xa - 0.014, sl)], 0.612, 0.75, floor=VIOLET))
    # Side fuller groove along upper receiver flanks
    fuller = [(0.05, 0.576), (0.10, 0.584), (1.18, 0.584), (1.22, 0.576), (1.18, 0.579), (0.10, 0.579)]
    cutters += [prism(fuller, 0.095, 0.30, floor=CORE), prism(fuller, -0.095, -0.30, floor=CORE)]
    cut(o, cutters, rim=0.002)
    return o


def build_core():
    """Dark receiver core (with recessed right-side bolt ejection bay) and
    faceted violet-cored handguard interior."""
    def rec(x):
        zb = 0.252 if x > -0.10 else 0.278
        return [
            (0.068, zb), (0.088, zb + 0.016), (0.088, 0.542), (0.064, 0.568),
        ]
    st = [(x, ring(rec(x))) for x in (-0.180, -0.100, -0.085, 0.55, 1.24, 1.29)]
    a = link("MFJ_ReceiverCore", loft(st, ring_mats([CORE, CORE, CORE], bottom=CORE, top=CORE), cap_mat=CORE))
    # Cut right-side bolt ejection port recess (-Y, x=0.22..0.68, z=0.43..0.53) + drum well
    ej = prism([(0.22, 0.432), (0.675, 0.432), (0.675, 0.528), (0.22, 0.528)], -0.068, -0.30, side=CORE, floor=CORE)
    well = zcut([(0.68, -0.08), (1.00, -0.08), (1.00, 0.08), (0.68, 0.08)], 0.12, 0.32, mat=CORE)
    cut(a, [ej, well], rim=0.0)

    # Fore-end fluid core inside the raked ribs (x = 1.26 .. 1.92)
    def fe(k=1.0):
        return [
            (0.044 * k, 0.224), (0.074 * k, 0.244), (0.082 * k, 0.300),
            (0.082 * k, 0.456), (0.070 * k, 0.495), (0.052 * k, 0.512),
        ]
    st_fe = [(1.255, ring(fe())), (1.885, ring(fe())), (1.928, ring(fe(0.84)))]
    b = link("MFJ_ForendFluid", loft(st_fe, ring_mats([GASKET, GASKET, VIOLET, VIOLET, GASKET],
                                                      bottom=GASKET, top=CORE), cap_mat=CORE))
    return a, b


def build_carapace():
    """Heavy folded side carapace over the receiver (x=-0.16..1.25) with a wide
    recessed violet fluid chamber and three raked carapace sinews. Left side
    (+Y) is a full continuous chamber; right side (-Y) steps around Judge_Bolt
    so the ejection port stays clean and unobstructed."""
    # Left-side (+Y) full receiver carapace plate (clean notch around Judge_FireSelector x=.13..214, z=.298..335)
    out_l = [
        (-0.165, 0.538), (1.235, 0.538), (1.265, 0.485), (1.252, 0.310),
        (1.185, 0.258), (0.248, 0.258), (0.232, 0.340), (0.112, 0.340),
        (0.092, 0.268), (-0.150, 0.268), (-0.175, 0.330),
    ]
    ol = link("MFJ_CarapaceL", solid_plate(out_l, 0.086, 0.114, ch=0.0055,
                                           fold=((-0.16, 0.44), (1.24, 0.46), 0.011, 0.15)))
    win_l = [
        (0.060, 0.415), (0.145, 0.492), (0.380, 0.506), (1.060, 0.506),
        (1.160, 0.465), (1.160, 0.365), (1.045, 0.326), (0.295, 0.332), (0.245, 0.362), (0.110, 0.370),
    ]
    cut(ol, [prism(win_l, 0.094, 0.30)], rim=0.0028)

    # Three raked carapace sinew ribs crossing left receiver chamber
    sb_l = []
    for xa, xb in ((0.355, 0.435), (0.615, 0.695), (0.875, 0.955)):
        path = [
            (xa - 0.008, 0.091, 0.312),
            ((xa + xb) * 0.5, 0.097, 0.415),
            (xb + 0.008, 0.091, 0.518),
        ]
        sb_l.append(sweep(path, (0, 1, 0), [0.036, 0.025, 0.036], [0.025, 0.022, 0.025]))
    sl = join("MFJ_SinewsL", sb_l)

    # Right-side (-Y) carapace plate notched around Judge_Bolt ejection port (x=0.22..0.675, z=0.432..0.528)
    out_r = [
        (-0.165, 0.538), (0.215, 0.538), (0.220, 0.425), (0.680, 0.425),
        (0.685, 0.538), (1.235, 0.538), (1.265, 0.485), (1.252, 0.310),
        (1.185, 0.258), (-0.150, 0.268), (-0.175, 0.330),
    ]
    # Build on +Y then mirror onto -Y by negating Y in mesh
    bm_r = solid_plate(out_r, 0.086, 0.114, ch=0.0055,
                       fold=((-0.16, 0.39), (1.24, 0.40), 0.010, 0.14))
    for v in bm_r.verts:
        v.co.y = -v.co.y
    bmesh.ops.recalc_face_normals(bm_r, faces=bm_r.faces)
    o_r = link("MFJ_CarapaceR", bm_r)
    # Two crisp violet fluid chambers on right flank: front chamber (x=0.73..1.16) + lower chamber (x=0.10..0.65)
    win_rf = [
        (0.735, 0.355), (0.765, 0.496), (1.080, 0.502), (1.160, 0.462),
        (1.160, 0.365), (1.060, 0.326), (0.765, 0.326),
    ]
    win_rl = [
        (0.095, 0.345), (0.165, 0.398), (0.610, 0.398), (0.650, 0.355),
        (0.610, 0.312), (0.165, 0.312),
    ]
    cut(o_r, [prism(win_rf, -0.094, -0.30), prism(win_rl, -0.094, -0.30)], rim=0.0026)

    # Sinew across right-front chamber
    sb_r = []
    for xa, xb in ((0.880, 0.955),):
        path = [
            (xa - 0.008, -0.091, 0.312),
            ((xa + xb) * 0.5, -0.097, 0.415),
            (xb + 0.008, -0.091, 0.514),
        ]
        sb_r.append(sweep(path, (0, -1, 0), [0.036, 0.025, 0.036], [0.025, 0.022, 0.025]))
    sr = join("MFJ_SinewsR", sb_r)

    # Rear-swept shoulder thorns (both sides)
    th = []
    for xb, zb, ln in ((0.06, 0.558, 0.115), (-0.01, 0.548, 0.125), (-0.08, 0.538, 0.130)):
        path = [
            (xb, 0.104, zb),
            (xb - ln * 0.45, 0.114, zb + 0.009),
            (xb - ln * 0.80, 0.114, zb + 0.017),
            (xb - ln, 0.110, zb + 0.023),
        ]
        th.append(sweep(path, (0, 1, 0.3), [0.042, 0.030, 0.013, 0.003], [0.015, 0.013, 0.007, 0.002]))
    thorns = join("MFJ_Thorns", th)
    mirror_apply(thorns)

    # Selector boss cradling Judge_FireSelector
    sel = bpy.data.objects["Judge_FireSelector"]
    pts = [sel.matrix_world @ Vector(c) for c in sel.bound_box]
    cx = sum(p.x for p in pts) / 8.0
    cz = sum(p.z for p in pts) / 8.0
    r = 0.042
    boss_out = [(cx + r * math.cos(a), cz + r * math.sin(a))
                for a in [math.radians(22.5 + 45 * i) for i in range(8)]]
    boss = link("MFJ_SelectorBoss", solid_plate(boss_out, 0.082, 0.096, ch=0.0035))
    mirror_apply(boss)
    return ol, sl, o_r, sr, thorns, boss


def build_forend():
    """Raked overlapping Moltframe carapace ribs over the glowing violet shotgun
    fore-end, front crescent collar locking receiver to handguard, lower keel,
    and heavy faceted hexagonal shotgun choke muzzle."""
    # Front crescent collar at receiver/handguard seam (clears Judge_CharmLoop at x=1.202, z=0.245..0.282!)
    c_out = [
        (1.205, 0.538), (1.275, 0.538), (1.335, 0.482), (1.348, 0.395),
        (1.325, 0.312), (1.270, 0.292), (1.245, 0.320), (1.278, 0.395), (1.260, 0.482),
    ]
    cres = link("MFJ_Crescent", solid_plate(c_out, 0.088, 0.120, ch=0.005,
                                            fold=((1.24, 0.54), (1.32, 0.30), 0.007, 0.08)))
    mirror_apply(cres)

    # Five raked heavy carapace ribs sweeping down around the violet fore-end core
    zc, a, b = 0.370, 0.132, 0.086
    bms = []
    for i, x0 in enumerate((1.41, 1.525, 1.64, 1.755, 1.87)):
        ph = [math.radians(d) for d in (76, 56, 34, 10, -14, -38, -62, -88)]
        path, outw, wid, th = [], [], [], []
        for p in ph:
            s = (math.sin(p) + 1.0) / 2.0
            path.append((x0 - 0.125 * s, b * math.cos(p) - 0.002, zc + a * math.sin(p)))
            outw.append((0, math.cos(p) / b, math.sin(p) / a))
            taper = 1.0 - 0.40 * max(0.0, (s - 0.80) / 0.20)
            wid.append(0.072 * taper * (1.0 - 0.10 * i / 4.0))
            th.append(0.017 * taper)
        bms.append(sweep(path, outw, wid, th))
    ribs = join("MFJ_ForendRibs", bms)
    mirror_apply(ribs)

    # Armored lower keel under fore-end (x = 1.25..1.93)
    def keel(k=1.0):
        return [(0.036 * k, 0.200), (0.062 * k, 0.212), (0.068 * k, 0.234), (0.044 * k, 0.248)]
    st_k = [(1.255, ring(keel(0.88))), (1.29, ring(keel())), (1.87, ring(keel())), (1.935, ring(keel(0.70)))]
    st_k[-1] = (st_k[-1][0], [(y, z + 0.014) for y, z in st_k[-1][1]])
    keel_o = link("MFJ_ForendKeel", loft(st_k, ring_mats([ARM, ARM, ARM], bottom=ARM, top=ARM), cap_mat=EDGE))

    # Front fore-end cap collar sealing barrel/handguard face cleanly
    def cap_sec(k=1.0):
        return [
            (0.044 * k, 0.228), (0.078 * k, 0.252), (0.088 * k, 0.375),
            (0.080 * k, 0.515), (0.046 * k, 0.545),
        ]
    st_cap = [(1.885, ring(cap_sec(1.0))), (1.945, ring(cap_sec(0.96))), (1.985, ring(cap_sec(0.78)))]
    cap = link("MFJ_ForendCap", loft(st_cap, ring_mats([ARM, ARM, ARM, ARM], bottom=ARM, top=ARM), cap_mat=EDGE))

    # Heavy faceted hexagonal Moltframe shotgun choke muzzle (bore z = 0.5022, x = 1.92..2.14)
    prof = [
        (1.915, 0.072), (1.948, 0.082), (1.982, 0.080), (1.994, 0.064),
        (2.010, 0.078), (2.046, 0.074), (2.058, 0.058), (2.074, 0.070),
        (2.115, 0.062), (2.138, 0.050),
    ]
    st_m = [
        [(x, r * math.cos(math.radians(30 + 60 * i)), BORE_Z + r * math.sin(math.radians(30 + 60 * i)))
         for i in range(6)]
        for x, r in prof
    ]
    muz = link("MFJ_Muzzle", loft3(st_m, [ARM] * 6, cap_mat=CORE))
    for p in muz.data.polygons:
        xs = [muz.data.vertices[i].co.x for i in p.vertices]
        if max(xs) - min(xs) < 0.015:
            p.material_index = EDGE
    # Dark recessed shotgun bore cavity
    bore_st = [
        [(x, r * math.cos(math.radians(30 + 60 * i)), BORE_Z + r * math.sin(math.radians(30 + 60 * i)))
         for i in range(6)]
        for x, r in ((2.050, 0.036), (2.145, 0.036))
    ]
    cut(muz, [loft3(bore_st, [CORE] * 6, caps=(True, True), cap_mat=CORE)], rim=0.0)
    return cres, ribs, keel_o, cap, muz


def build_drum():
    """16-sided faceted Moltframe wheel-drum (bone: Mag, axis along Y at
    x=0.840, z=-0.034) with 12 perimeter armor cleats, 4 bold recessed violet
    fluid arc-windows on BOTH flat side faces, a hexagonal lilac hub, and
    a faceted feed tower entering the receiver cleanly."""
    n = 16
    r_main = 0.292
    y_half = 0.152

    def wheel_ring(y, r):
        return [
            (DRUM_X + r * math.cos(2.0 * math.pi * (i + 0.5) / n),
             y,
             DRUM_Z + r * math.sin(2.0 * math.pi * (i + 0.5) / n))
            for i in range(n)
        ]

    # Closed faceted drum cylinder along Y with crisp silver bevel rims
    st = [
        wheel_ring(-y_half, r_main - 0.022),
        wheel_ring(-y_half + 0.016, r_main),
        wheel_ring(y_half - 0.016, r_main),
        wheel_ring(y_half, r_main - 0.022),
    ]
    drum = link("MFJ_DrumBody", loft3(st, [ARM] * n, caps=(True, True), cap_mat=ARM), bone="Mag")
    # Paint the outer bevel rings EDGE for crisp silver light-catch
    for p in drum.data.polygons:
        ys = [abs(drum.data.vertices[i].co.y) for i in p.vertices]
        if max(ys) > y_half - 0.002 and min(ys) < y_half - 0.004:
            p.material_index = EDGE

    # Cut 4 symmetrical curved-faceted violet fluid windows into BOTH flat side faces (+Y and -Y)
    cutters = []
    for q in range(4):
        a0 = math.radians(16 + 90 * q)
        a1 = math.radians(74 + 90 * q)
        r_in, r_out = 0.118, 0.232
        pts_outer = [(DRUM_X + r_out * math.cos(a0 + (a1 - a0) * t / 4.0),
                      DRUM_Z + r_out * math.sin(a0 + (a1 - a0) * t / 4.0)) for t in range(5)]
        pts_inner = [(DRUM_X + r_in * math.cos(a1 - (a1 - a0) * t / 4.0),
                      DRUM_Z + r_in * math.sin(a1 - (a1 - a0) * t / 4.0)) for t in range(5)]
        win = pts_outer + pts_inner
        cutters += [prism(win, y_half - 0.024, y_half + 0.12),
                    prism(win, -(y_half - 0.024), -(y_half + 0.12))]
    cut(drum, cutters, rim=0.003)

    # 8 perimeter armored tread cleats around the drum circumference (echoing stock silhouette)
    cleats = []
    for k in range(8):
        ang = math.radians(22.5 + 45 * k)
        ca, sa = math.cos(ang), math.sin(ang)
        tx, tz = -sa, ca
        # Faceted bar running across Y (-0.132..+0.132) at radius r_main..r_main+0.024
        prof = [
            (-0.026, -0.006), (-0.018, 0.024), (0.018, 0.024), (0.026, -0.006),
        ]
        rings_c = []
        for yv, sc_t in ((-0.132, 0.72), (-0.114, 1.0), (0.114, 1.0), (0.132, 0.72)):
            rings_c.append([
                (DRUM_X + ca * (r_main + dr * sc_t) + tx * dt * sc_t,
                 yv,
                 DRUM_Z + sa * (r_main + dr * sc_t) + tz * dt * sc_t)
                for dt, dr in prof
            ])
        cleats.append(loft3(rings_c, [EDGE, ARM, EDGE, CORE], caps=(True, True), cap_mat=EDGE))
    cleat_o = join("MFJ_DrumCleats", cleats, bone="Mag")

    # Hexagonal lilac alloy hub boss on both flat sides of the drum
    hubs = []
    for sgn in (1.0, -1.0):
        st_h = [
            [(DRUM_X + r * math.cos(math.radians(30 + 60 * i)),
              sgn * yv,
              DRUM_Z + r * math.sin(math.radians(30 + 60 * i)))
             for i in range(6)]
            for yv, r in ((y_half - 0.006, 0.088), (y_half + 0.010, 0.082), (y_half + 0.020, 0.056))
        ]
        hubs.append(loft3(st_h, [LILAC] * 6, caps=(True, True), cap_mat=EDGE))
    hub_o = join("MFJ_DrumHub", hubs, bone="Mag")

    # Feed tower rising cleanly from top of drum into receiver magwell (z = 0.21..0.315)
    def tower_sec(k=1.0):
        return [(0.056 * k, 0.200), (0.068 * k, 0.215), (0.068 * k, 0.308), (0.056 * k, 0.320)]
    st_t = [(0.745, ring(tower_sec(0.95))), (0.935, ring(tower_sec(0.95)))]
    tower = link("MFJ_DrumFeed", loft(st_t, ring_mats([CORE, CORE, CORE], bottom=CORE, top=CORE), cap_mat=CORE), bone="Mag")
    return drum, cleat_o, hub_o, tower


def build_stock():
    """Skeletal Moltframe shotgun stock (x = -0.10..-1.03, z = -0.11..0.58)
    with BOTH struts buried deeply inside the rear receiver core (0 gaps)."""
    path, wid, th = [], [], []
    for x in (-0.12, -0.20, -0.32, -0.48, -0.68, -0.86, -0.96):
        t = min(1.0, (-0.12 - x) / 0.26)
        zc = 0.455 + (0.515 - 0.455) * (t ** 0.7)
        path.append((x, 0.0, zc))
        wid.append(0.18 - (0.18 - 0.072) * (t ** 0.7))
        th.append(0.066 - 0.010 * t)
    top = link("MFJ_StockTop", sweep(path, (0, 1, 0), wid, th, STRUT, STRUT_M))
    win = [(-0.28, 0.502), (-0.36, 0.518), (-0.88, 0.520), (-0.93, 0.510), (-0.88, 0.498), (-0.36, 0.492)]
    cut(top, [prism(win, 0.042, 0.30), prism(win, -0.042, -0.30)], rim=0.0022)

    # Lower strut front deeply buried inside rear receiver core (x = -0.08, z = 0.355)
    p0, p1 = Vector((-0.08, 0.0, 0.355)), Vector((-0.97, 0.0, -0.072))
    path_l = [p0.lerp(p1, t) for t in (0.0, 0.15, 0.5, 0.85, 1.0)]
    low = link("MFJ_StockLow", sweep(path_l, (0, 1, 0), [0.080, 0.062, 0.058, 0.060, 0.070],
                                     [0.046, 0.042, 0.040, 0.042, 0.046], STRUT, STRUT_M))
    win2 = [(-0.34, 0.230), (-0.38, 0.214), (-0.86, -0.016), (-0.90, -0.022), (-0.87, -0.038), (-0.36, 0.200)]
    cut(low, [prism(win2, 0.026, 0.30), prism(win2, -0.026, -0.30)], rim=0.0022)

    out = [
        (-0.945, 0.576), (-1.005, 0.576), (-1.055, 0.555), (-1.078, 0.495),
        (-1.062, 0.410), (-1.078, 0.290), (-1.065, 0.160), (-1.078, 0.040),
        (-1.058, -0.065), (-1.028, -0.115), (-0.960, -0.115), (-0.942, -0.080),
    ]
    butt = link("MFJ_Butt", solid_plate(out, 0.0, 0.076, ch=0.0085, open_inner=True))
    mirror_apply(butt, merge=True)
    slit = [
        (-0.975, 0.485), (-1.008, 0.500), (-1.038, 0.440), (-1.046, 0.040),
        (-1.028, -0.055), (-1.002, -0.082), (-0.985, -0.040), (-0.996, 0.040), (-0.992, 0.440),
    ]
    cut(butt, [prism(slit, 0.060, 0.30), prism(slit, -0.060, -0.30)], rim=0.003)
    sb = []
    for zc in (0.28, 0.08):
        sb.append(sweep([(-0.980, 0.061, zc + 0.022), (-1.015, 0.063, zc), (-1.044, 0.061, zc - 0.022)],
                        (0, 1, 0), [0.020, 0.015, 0.020], [0.016, 0.015, 0.016]))
    sn = join("MFJ_ButtSinews", sb)
    mirror_apply(sn)
    return top, low, butt, sn


def build_grip():
    """Folded carapace side plates hugging Judge_Grip with diamond violet window."""
    rows = [
        (-0.048, 0.165, 0.145, 0.095),
        (-0.072, 0.110, 0.128, 0.042),
        (-0.096, 0.055, 0.108, -0.012),
        (-0.120, 0.000, 0.088, -0.065),
        (-0.144, -0.055, 0.068, -0.118),
        (-0.168, -0.110, 0.054, -0.172),
        (-0.192, -0.165, 0.044, -0.225),
        (-0.214, -0.218, 0.036, -0.275),
    ]
    bk = [lerp2((bx, bz), (fx, fz), 0.08) for bx, bz, fx, fz in rows]
    fw = [lerp2((bx, bz), (fx, fz), 0.90) for bx, bz, fx, fz in rows]
    tip = lerp2((-0.232, -0.268), (0.025, -0.312), 0.30)
    out = [(-0.030, 0.195), (0.148, 0.155)] + fw + [tip] + list(reversed(bk))
    o = link("MFJ_GripPlate", solid_plate(out, 0.056, 0.072, ch=0.0038,
                                          fold=((-0.05, 0.17), (-0.20, -0.24), 0.005, 0.12)))
    w1 = [lerp2((bx, bz), (fx, fz), t) for (bx, bz, fx, fz), t in zip(rows[1:6], (0.34, 0.30, 0.28, 0.30, 0.34))]
    w2 = [lerp2((bx, bz), (fx, fz), t) for (bx, bz, fx, fz), t in zip(rows[1:6], (0.54, 0.60, 0.62, 0.60, 0.54))]
    w = [lerp2(w1[0], w2[0], 0.5)] + w1[1:-1] + [lerp2(w1[-1], w2[-1], 0.5)] + list(reversed(w2[1:-1]))
    cut(o, [prism(w, 0.0615, 0.30)], rim=0.0022)
    mirror_apply(o)
    return o


# ------------------------------------------------------------------- build
hw = {}
# Retain the stock lower trigger-guard housing island (island 1: min z < 0.15)
hw["rec"] = retain("Judge_Receiver", lambda P: min(p.z for p in P) < 0.15, "MFJ_ReceiverHardware")
hw["grip"] = retain("Judge_Grip", lambda P: True, "MFJ_GripHardware")
# Retain ONLY the glowing iron-sight dots (z > 0.65) in violet indicator material (keep "Sight" in name!)
hw["sneon"] = retain("Judge_Neon", lambda P: min(p.z for p in P) > 0.65, "MFJ_SightNeon")

parts = {}
parts["upper"] = build_upper()
parts["core"] = build_core()
parts["carapace"] = build_carapace()
parts["forend"] = build_forend()
parts["drum"] = build_drum()
parts["stock"] = build_stock()
parts["grip"] = build_grip()

for o in col.objects:
    flat_uv(o)

HARDWARE = [
    "Judge_Sights", "Judge_ChargingHandle", "Judge_Bolt",
    "Judge_Trigger", "Judge_FireSelector", "Judge_CharmLoop",
]
STOCK_PARTS = [
    "Judge_Neon", "Judge_Receiver", "Judge_Handguard", "Judge_Barrel",
    "Judge_Grip", "Judge_Stock", "Judge_Pins", "Judge_Mag",
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
