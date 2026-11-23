"""Moltframe Sheriff: the Vandal v05 carapace language on the stock Sheriff.

Exec order in the Blender MCP session (stock Sheriff_RemasterV2_v05 open):
    RIG_NAME, COL_NAME, ITEM_KEY = "Sheriff_Rig", "Moltframe Sheriff", "Sheriff"
    exec(model_moltframe_vandal_v04.py)         # materials + plate/loft/cut helpers
    exec(<helper half of model_moltframe_vandal_v04_parts.py>)
    exec(this file)

Brief: alien-alloy carapace hand cannon. Swept faceted graphite spine over the
top strap and heavy barrel with three violet dorsal slots; folded side shroud
over the heavy barrel framing a recessed violet fluid chamber crossed by three
raked carapace sinew ribs; segmented hexagonal Moltframe muzzle; front crescent
collar locking barrel to frame; faceted rear cowl with a player-facing violet
inlet window, rear-swept thorns clearing the hammer, and a clean release-latch
boss; 12-sided faceted graphite cylinder with polished fold hoops and six
recessed violet fluid flutes (bone: Cylinder); folded grip carapace plates with
a recessed diamond fluid window and horned heel spur.
"""
from collections import defaultdict
from mathutils import Matrix

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
CYL_Z = 0.1898
BORE_Z = 0.2782


def zt_spine(x):
    """Top crest stays under the stock rear (z .371) and front (z .344) sight bases."""
    if x <= 0.19:
        return 0.340
    if x <= 0.24:
        return 0.340 + (x - 0.19) / 0.05 * 0.033
    if x <= 0.72:
        return 0.373
    if x <= 0.82:
        return 0.373 - (x - 0.72) / 0.10 * 0.025
    if x <= 1.435:
        return 0.348
    return 0.348 - (x - 1.435) / 0.055 * 0.026


def zb_spine(x):
    """Bottom of the upper spine clears the cylinder (z max .3328) and seats into barrel core."""
    if x <= 0.29:
        return 0.312
    if x <= 0.31:
        return 0.312 + (x - 0.29) / 0.02 * 0.024
    if x <= 0.64:
        return 0.336
    if x <= 0.74:
        return 0.336 - (x - 0.64) / 0.10 * 0.030
    if x <= 1.43:
        return 0.306
    return 0.306 - (x - 1.43) / 0.06 * 0.008


def upper_half(x):
    zt, zb = zt_spine(x), zb_spine(x)
    h = max(0.018, zt - zb)
    k = 1.0 if x <= 1.41 else 1.0 - (x - 1.41) / 0.08 * 0.36
    w = 0.068 if x < 0.72 else 0.064
    return [
        (0.036 * k, zb),
        (w * k, zb),
        ((w + 0.005) * k, zb + 0.28 * h),
        ((w + 0.004) * k, zb + 0.46 * h),
        (w * k * 0.90, zb + 0.74 * h),
        (0.036 * k, zt - 0.004),
        (0.024 * k, zt),
    ]


UPPER_MATS = [CORE, EDGE, ARM, EDGE, ARM, EDGE]


def build_upper():
    xs = [
        0.190, 0.205, 0.240, 0.290, 0.310, 0.480, 0.640, 0.720,
        0.770, 0.820, 1.000, 1.200, 1.410, 1.435, 1.465, 1.490,
    ]
    st = [(x, ring(upper_half(x))) for x in xs]
    x0, r0 = st[0]
    st[0] = (x0, [(y * 0.78, z - (0.006 if z > 0.33 else 0.0)) for y, z in r0])
    o = link("MFSh_UpperShell", loft(st, ring_mats(UPPER_MATS, bottom=CORE, top=ARM), cap_mat=EDGE))
    cutters = []
    # Three raked violet dorsal slots along the barrel spine (stay behind front sight x=1.29)
    for xa, xb in ((0.86, 0.97), (1.01, 1.12), (1.16, 1.25)):
        sl = 0.011
        cutters.append(zcut([(xa, -sl), (xb, -sl), (xb - 0.010, sl), (xa - 0.010, sl)], 0.336, 0.50, floor=VIOLET))
    # One dorsal slot over the cylinder top strap (between rear sight x=.325 and front collar x=.72)
    sl = 0.011
    cutters.append(zcut([(0.41, -sl), (0.58, -sl), (0.57, sl), (0.40, sl)], 0.360, 0.50, floor=VIOLET))
    cut(o, cutters, rim=0.0018)
    return o


def build_frame_core():
    """Dark faceted core behind, under, and in front of the cylinder window,
    preserving the exact hammer slot (|y| <= .025 behind x=.19), cylinder window
    (x .304..0.642, z .044..0.336), and crane swing clearance."""
    # Rear standing breech block (x = 0.185 .. 0.304, |y| <= 0.056 so rear violet window clears cleanly)
    def breech(x):
        zb = -0.022 if x > 0.22 else 0.010
        zt = 0.348 if x > 0.21 else 0.320
        return [(0.044, zb), (0.056, zb + 0.014), (0.056, zt - 0.018), (0.040, zt)]
    st_b = [(x, ring(breech(x))) for x in (0.186, 0.210, 0.240, 0.304)]
    breech_o = link("MFSh_BreechCore", loft(st_b, ring_mats([CORE, CORE, CORE], bottom=CORE, top=CORE), cap_mat=CORE))

    # Rear tang side walls flanking the hammer slot (|y| = 0.026 .. 0.056, x = -0.075 .. 0.205)
    tang_out = [
        (-0.075, 0.140), (-0.015, 0.210), (0.110, 0.225), (0.195, 0.315),
        (0.205, 0.315), (0.205, 0.008), (0.105, -0.015), (-0.010, 0.050), (-0.075, 0.105),
    ]
    tang_o = link("MFSh_TangCore", solid_plate(tang_out, 0.026, 0.056, ch=0.003, mat=CORE))
    mirror_apply(tang_o)
    return breech_o, tang_o


def build_frame_under_clean():
    """Separate clean loft for the under-cylinder floor and front frame block."""
    # Under floor under cylinder (z = -0.020 .. 0.040)
    def floor_sec(k=1.0):
        return [(0.036 * k, -0.020), (0.056 * k, -0.008), (0.056 * k, 0.032), (0.042 * k, 0.040)]
    st_f = [(0.255, ring(floor_sec())), (0.655, ring(floor_sec())), (0.715, ring(floor_sec(0.95)))]
    fl = link("MFSh_UnderFloor", loft(st_f, ring_mats([CORE, CORE, CORE], bottom=CORE, top=CORE), cap_mat=CORE))

    # Front yoke wall in front of cylinder (x = 0.642 .. 0.776, clears cylinder x max 0.6292)
    def yoke_sec(x):
        zb = -0.016 if x < 0.735 else 0.045
        zt = 0.345
        w = 0.062 if x < 0.74 else 0.064
        return [(0.038, zb), (w, zb + 0.022), (w, zt - 0.018), (0.044, zt)]
    st_y = [(x, ring(yoke_sec(x))) for x in (0.642, 0.690, 0.735, 0.776)]
    yk = link("MFSh_FrontYoke", loft(st_y, ring_mats([CORE, CORE, CORE], bottom=CORE, top=CORE), cap_mat=CORE))
    return fl, yk


def build_rear_cowl():
    """Swept folded side carapace over the rear frame with a player-facing violet
    inlet window, single raked sinew, rear-swept thorns clearing the hammer, and
    clean clearance around Sheriff_CylinderRelease (x .203..0.234, z .042..0.073)."""
    out = [
        (-0.048, 0.145), (0.035, 0.215), (0.130, 0.248), (0.205, 0.336),
        (0.298, 0.336), (0.304, 0.295), (0.298, 0.100),
        # Clean semicircular-faceted notch around Sheriff_CylinderRelease (x .192..0.252, z .024..0.094)
        (0.252, 0.096), (0.188, 0.096), (0.175, 0.058), (0.192, 0.020),
        (0.256, 0.020), (0.296, 0.018), (0.285, -0.016),
        (0.165, -0.016), (0.045, 0.045), (-0.048, 0.110),
    ]
    o = link("MFSh_RearCowl", solid_plate(out, 0.054, 0.080, ch=0.0045,
                                          fold=((0.02, 0.19), (0.30, 0.22), 0.008, 0.11)))
    # Player-facing violet fluid inlet window on the rear recoil shield (floor at y=0.063 clears core y=0.056!)
    win = [
        (0.068, 0.148), (0.145, 0.220), (0.225, 0.268), (0.272, 0.262),
        (0.275, 0.165), (0.238, 0.125), (0.135, 0.115),
    ]
    cut(o, [prism(win, 0.063, 0.30)], rim=0.0024)
    mirror_apply(o)

    # Raked carapace sinew crossing the rear inlet window (seated deeply into top/bottom frame walls)
    sb = [
        sweep([(0.156, 0.061, 0.108), (0.192, 0.066, 0.186), (0.226, 0.061, 0.278)],
              (0, 1, 0), [0.024, 0.017, 0.024], [0.018, 0.016, 0.018]),
    ]
    sn = join("MFSh_RearSinew", sb)
    mirror_apply(sn)

    # Three rear-swept carapace thorns off the upper recoil shield (clears hammer |y|<=0.019)
    th = []
    for xb, zb, ln in ((0.270, 0.320, 0.095), (0.215, 0.306, 0.105), (0.165, 0.285, 0.105)):
        path = [
            (xb, 0.071, zb),
            (xb - ln * 0.45, 0.079, zb + 0.007),
            (xb - ln * 0.80, 0.079, zb + 0.014),
            (xb - ln, 0.075, zb + 0.019),
        ]
        th.append(sweep(path, (0, 1, 0.3), [0.030, 0.022, 0.010, 0.0025], [0.012, 0.010, 0.005, 0.002]))
    t = join("MFSh_Thorns", th)
    mirror_apply(t)

    # Octagonal collar boss seating Sheriff_CylinderRelease cleanly (stays at y=0.064 under latch y=0.062..0.075)
    rel = bpy.data.objects["Sheriff_CylinderRelease"]
    pts = [rel.matrix_world @ Vector(c) for c in rel.bound_box]
    cx = sum(p.x for p in pts) / 8.0
    cz = sum(p.z for p in pts) / 8.0
    r = 0.029
    boss_out = [(cx + r * math.cos(a), cz + r * math.sin(a))
                for a in [math.radians(22.5 + 45 * i) for i in range(8)]]
    boss = link("MFSh_ReleaseBoss", solid_plate(boss_out, 0.052, 0.064, ch=0.003))
    mirror_apply(boss)
    return o, sn, t, boss


def build_crescent():
    """Raked Moltframe front collar crescent tying frame yoke to heavy barrel."""
    out = [
        (0.688, 0.354), (0.760, 0.354), (0.808, 0.306), (0.822, 0.220),
        (0.800, 0.132), (0.745, 0.086), (0.688, 0.062), (0.658, 0.095),
        (0.728, 0.145), (0.750, 0.225), (0.730, 0.305),
    ]
    o = link("MFSh_Crescent", solid_plate(out, 0.060, 0.090, ch=0.0045,
                                          fold=((0.72, 0.35), (0.79, 0.10), 0.006, 0.07)))
    # Violet accent slit sits over the yoke (y=0.079 clears BarrelShroud y=0.078 cleanly!)
    win = [(0.758, 0.195), (0.774, 0.252), (0.790, 0.224), (0.774, 0.168)]
    cut(o, [prism(win, 0.079, 0.30)], rim=0.002)
    mirror_apply(o)
    return o


def build_barrel():
    """Faceted barrel core, recessed side violet fluid chamber, folded carapace
    barrel shroud, three raked lenticular sinew ribs, under-keel, and segmented
    hexagonal Moltframe muzzle."""
    # Inner dark core (strictly CORE, |y| <= 0.052 so it never interferes with shroud's violet chamber!)
    def bcore(k=1.0):
        return [
            (0.030 * k, 0.118), (0.048 * k, 0.134), (0.052 * k, 0.195),
            (0.052 * k, 0.292), (0.044 * k, 0.314), (0.032 * k, 0.320),
        ]
    st_c = [(0.745, ring(bcore())), (1.425, ring(bcore())), (1.468, ring(bcore(0.82)))]
    core = link("MFSh_BarrelCore", loft(st_c, ring_mats([CORE, CORE, CORE, CORE, CORE],
                                                        bottom=CORE, top=CORE), cap_mat=CORE))

    # Swept folded barrel carapace side plates with a bold recessed violet chamber
    out = [
        (0.770, 0.312), (1.430, 0.312), (1.466, 0.275), (1.450, 0.168),
        (1.390, 0.118), (0.810, 0.112), (0.770, 0.155),
    ]
    shroud = link("MFSh_BarrelShroud", solid_plate(out, 0.051, 0.078, ch=0.0045,
                                                   fold=((0.78, 0.245), (1.45, 0.235), 0.008, 0.11)))
    win = [
        (0.835, 0.220), (0.885, 0.278), (1.080, 0.286), (1.335, 0.282),
        (1.385, 0.245), (1.360, 0.172), (1.270, 0.150), (0.910, 0.150), (0.850, 0.178),
    ]
    cut(shroud, [prism(win, 0.059, 0.30)], rim=0.0026)
    mirror_apply(shroud)

    # Three raked lenticular carapace sinew ribs seated deeply into top/bottom shroud lips
    sb = []
    for xa, xb in ((0.945, 1.005), (1.100, 1.160), (1.250, 1.310)):
        path = [
            (xa - 0.006, 0.056, 0.136),
            ((xa + xb) * 0.5, 0.063, 0.216),
            (xb + 0.006, 0.056, 0.296),
        ]
        sb.append(sweep(path, (0, 1, 0), [0.030, 0.022, 0.030], [0.022, 0.020, 0.022]))
    ribs = join("MFSh_BarrelSinews", sb)
    mirror_apply(ribs)

    # Under-barrel faceted armored keel + ejector shroud
    def keel(k=1.0):
        return [(0.024 * k, 0.094), (0.044 * k, 0.104), (0.048 * k, 0.122), (0.030 * k, 0.134)]
    st_k = [
        (0.755, ring(keel(0.86))),
        (0.790, ring(keel())),
        (1.365, ring(keel())),
        (1.430, ring(keel(0.68))),
    ]
    st_k[-1] = (st_k[-1][0], [(y, z + 0.014) for y, z in st_k[-1][1]])
    keel_o = link("MFSh_BarrelKeel", loft(st_k, ring_mats([ARM, ARM, ARM], bottom=ARM, top=ARM), cap_mat=EDGE))

    # Segmented hexagonal Moltframe muzzle (aligns with bore z = 0.2782, muzzle x = 1.495)
    prof = [
        (1.425, 0.048), (1.448, 0.052), (1.466, 0.050), (1.474, 0.036),
        (1.484, 0.047), (1.504, 0.044), (1.512, 0.032), (1.522, 0.040),
        (1.536, 0.034), (1.544, 0.025),
    ]
    st_m = [
        [(x, r * math.cos(math.radians(30 + 60 * i)), BORE_Z + r * math.sin(math.radians(30 + 60 * i)))
         for i in range(6)]
        for x, r in prof
    ]
    muz = link("MFSh_Muzzle", loft3(st_m, [ARM] * 6, cap_mat=CORE))
    for p in muz.data.polygons:
        xs = [muz.data.vertices[i].co.x for i in p.vertices]
        if max(xs) - min(xs) < 0.012:
            p.material_index = EDGE
    # Recessed dark bore cavity inside muzzle front face
    bore_st = [
        [(x, r * math.cos(math.radians(30 + 60 * i)), BORE_Z + r * math.sin(math.radians(30 + 60 * i)))
         for i in range(6)]
        for x, r in ((1.495, 0.017), (1.548, 0.017))
    ]
    bore_bm = loft3(bore_st, [CORE] * 6, caps=(True, True), cap_mat=CORE)
    cut(muz, [bore_bm], rim=0.0)
    return core, shroud, ribs, keel_o, muz


def build_cylinder():
    """12-sided faceted alien-alloy cylinder (bone: Cylinder) with front/rear
    polished fold hoops and 6 recessed violet fluid flutes between the 6
    cartridge chambers (chamber r=0.088, max 0.118; flute floor r=0.123)."""
    n = 12
    x0, x1 = 0.319, 0.627

    def circ(x, r):
        # Phase offset so flats align squarely on the 6 mid-chamber flute angles (30 + 60*k deg)
        return [
            (x, r * math.sin(math.radians(15 + 30 * i)), CYL_Z + r * math.cos(math.radians(15 + 30 * i)))
            for i in range(n)
        ]

    body = loft3([circ(x0, 0.122), circ(x0 + 0.010, 0.137), circ(x1 - 0.010, 0.137), circ(x1, 0.122)],
                 [ARM] * n, cap_mat=CORE)
    o = link("MFSh_Cylinder", body, bone="Cylinder")

    # Cut 6 recessed violet fluid flutes at angles 30, 90, 150, 210, 270, 330 deg from +Z
    cutters = []
    for k in range(6):
        ang = math.radians(30 + 60 * k)
        ny, nz = math.sin(ang), math.cos(ang)
        ty, tz = math.cos(ang), -math.sin(ang)
        # Flute box in radial coordinates (length x .362..0.584, tangential half-width .024, depth r .123..0.22)
        prof_2d = [
            (0.362, 0.0), (0.376, 0.023), (0.570, 0.023),
            (0.584, 0.0), (0.570, -0.023), (0.376, -0.023),
        ]
        bmc = bmesh.new()
        r_in, r_out = 0.123, 0.220
        lo = [bmc.verts.new((px, ny * r_in + ty * pt, CYL_Z + nz * r_in + tz * pt)) for px, pt in prof_2d]
        hi = [bmc.verts.new((px, ny * r_out + ty * pt, CYL_Z + nz * r_out + tz * pt)) for px, pt in prof_2d]
        f0 = bmc.faces.new(lo); f0.material_index = VIOLET
        f1 = bmc.faces.new(hi); f1.material_index = GASKET
        m = len(prof_2d)
        for i in range(m):
            f = bmc.faces.new((lo[i], lo[(i + 1) % m], hi[(i + 1) % m], hi[i]))
            f.material_index = GASKET
        bmesh.ops.recalc_face_normals(bmc, faces=bmc.faces)
        cutters.append(bmc)

    # Also cut 6 shallow dark chamber recesses on front/rear faces at exact chamber centers (0, 60, ..., 300 deg)
    for k in range(6):
        ang = math.radians(60 * k)
        cy = 0.088 * math.sin(ang)
        cz = CYL_Z + 0.088 * math.cos(ang)
        # 8-sided bore pocket
        for xa, xb in ((x0 - 0.01, x0 + 0.025), (x1 - 0.025, x1 + 0.01)):
            ring_a = [(xa, cy + 0.025 * math.cos(math.radians(45 * j)), cz + 0.025 * math.sin(math.radians(45 * j))) for j in range(8)]
            ring_b = [(xb, cy + 0.025 * math.cos(math.radians(45 * j)), cz + 0.025 * math.sin(math.radians(45 * j))) for j in range(8)]
            cutters.append(loft3([ring_a, ring_b], [CORE] * 8, caps=(True, True), cap_mat=CORE))

    cut(o, cutters, rim=0.0022)

    # Front and rear polished silver fold hoops framing the flutes
    hoops = []
    for xa, xb in ((0.324, 0.348), (0.598, 0.622)):
        hoops.append(loft3([circ(xa, 0.130), circ(xa + 0.004, 0.1425), circ(xb - 0.004, 0.1425), circ(xb, 0.130)],
                           [EDGE] * n, caps=(True, True), cap_mat=ARM))
    # Central thin lilac ring accent
    hoops.append(loft3([circ(0.464, 0.133), circ(0.467, 0.141), circ(0.479, 0.141), circ(0.482, 0.133)],
                       [LILAC] * n, caps=(True, True), cap_mat=ARM))
    h = join("MFSh_CylinderHoops", hoops, bone="Cylinder")
    return o, h


def build_grip():
    """Folded carapace side plates hugging the stock Sheriff grip with a
    recessed diamond violet window and an angular armored heel collar."""
    rows = [
        (-0.112, 0.095, 0.055, 0.045),
        (-0.130, 0.030, 0.095, -0.010),
        (-0.155, -0.035, 0.100, -0.070),
        (-0.180, -0.105, 0.088, -0.135),
        (-0.205, -0.175, 0.074, -0.200),
        (-0.226, -0.245, 0.064, -0.265),
        (-0.244, -0.315, 0.058, -0.335),
        (-0.252, -0.375, 0.052, -0.390),
    ]
    bk = [lerp2((bx, bz), (fx, fz), 0.10) for bx, bz, fx, fz in rows]
    fw = [lerp2((bx, bz), (fx, fz), 0.88) for bx, bz, fx, fz in rows]
    tip = lerp2((-0.256, -0.405), (0.045, -0.415), 0.35)
    out = [(-0.085, 0.125), (0.045, 0.090)] + fw + [tip] + list(reversed(bk))
    o = link("MFSh_GripPlate", solid_plate(out, 0.058, 0.0725, ch=0.0038,
                                           fold=((-0.11, 0.08), (-0.23, -0.35), 0.005, 0.12)))
    # Recessed violet leaf/diamond window on grip flank
    w1 = [lerp2((bx, bz), (fx, fz), t) for (bx, bz, fx, fz), t in zip(rows[1:6], (0.36, 0.30, 0.28, 0.30, 0.36))]
    w2 = [lerp2((bx, bz), (fx, fz), t) for (bx, bz, fx, fz), t in zip(rows[1:6], (0.56, 0.62, 0.64, 0.62, 0.56))]
    w = [lerp2(w1[0], w2[0], 0.5)] + w1[1:-1] + [lerp2(w1[-1], w2[-1], 0.5)] + list(reversed(w2[1:-1]))
    cut(o, [prism(w, 0.0625, 0.30)], rim=0.0022)
    mirror_apply(o)

    # Angular armored heel spur capping the bottom of the grip
    heel_out = [
        (-0.268, -0.382), (-0.258, -0.428), (-0.110, -0.436),
        (0.068, -0.422), (0.082, -0.390), (0.052, -0.368), (-0.240, -0.362),
    ]
    heel = link("MFSh_GripHeel", solid_plate(heel_out, 0.0, 0.072, ch=0.005, open_inner=True))
    mirror_apply(heel, merge=True)
    return o, heel


# ------------------------------------------------------------------- build
hw = {}
# Retain only the stock trigger guard island (max z < 0.0) from Sheriff_Frame
hw["tguard"] = retain("Sheriff_Frame", lambda P: max(p.z for p in P) < 0.0, "MFSh_TriggerGuard")
hw["grip"] = retain("Sheriff_Grip", lambda P: True, "MFSh_GripHardware")
# Retain stock glowing iron-sight dots in violet indicator material (keep "Sight" in name for ADS!)
hw["sneon"] = retain("Sheriff_Neon", lambda P: True, "MFSh_SightNeon")

parts = {}
parts["upper"] = build_upper()
parts["core"] = build_frame_core()
parts["under"] = build_frame_under_clean()
parts["cowl"] = build_rear_cowl()
parts["crescent"] = build_crescent()
parts["barrel"] = build_barrel()
parts["cyl"] = build_cylinder()
parts["grip"] = build_grip()

for o in col.objects:
    flat_uv(o)

HARDWARE = [
    "Sheriff_Sights", "Sheriff_Hammer", "Sheriff_Trigger",
    "Sheriff_CylinderRelease", "Sheriff_Crane", "Sheriff_EjectorRod",
    "Sheriff_CharmLoop", "Sheriff_Speedloader", "Sheriff_Rounds",
]
STOCK_PARTS = ["Sheriff_Neon", "Sheriff_Frame", "Sheriff_Barrel", "Sheriff_Grip", "Sheriff_Pins", "Sheriff_Cylinder"]

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
