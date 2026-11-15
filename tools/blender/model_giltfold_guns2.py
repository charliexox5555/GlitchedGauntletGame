"""Giltfold round two: Marshal, Stinger, Ghost, Classic as full origami
sculpts in the language of the approved Giltfold Vandal v02 (ivory paper over
slate along one long diagonal fold, wave-pattern lacquer panels, accordion
pleats, folded boat bases, paper spikes, twisted paper shrouds, champagne
foil bar pairs). Exec after model_giltfold_kit.py and model_vandal_shell_base.py
(run_sfg KIT chain), stock item open, ITEM_KEY set. Stock body parts are
rebuilt from their own side outlines (hull_solid); parts that hold moving-part
channels stay stock in the line finishes and get folded cladding."""

IV, SL, INK, WALL, PAT, GRP, PEW, FOIL = 0, 1, 2, 3, 4, 5, 6, 7
IV_TABLE = [MATS[0], MATS[1], MATS[2], MATS[6], MATS[5], MATS[7], EXTRA["Neon"], EXTRA["Brass"]]
INK_TABLE = [MATS[2], MATS[1], MATS[2], MATS[6], MATS[5], MATS[7], EXTRA["Neon"], EXTRA["Brass"]]
PEW_TABLE = [MATS[6], MATS[1], MATS[2], MATS[6], MATS[5], MATS[7], EXTRA["Neon"], EXTRA["Brass"]]

def tri(o):
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="FIXED", ngon_method="BEAUTY")
    bm.to_mesh(o.data); bm.free(); o.data.update()
    return o

def paint_fold(o, a, b):
    """Side faces above the line a->b (side view) ivory, below it slate."""
    (x0, z0), (x1, z1) = a, b
    for p in o.data.polygons:
        if abs(p.normal.y) > .3 and p.material_index in (IV, SL):
            c = p.center
            d = (x1 - x0) * (c.z - z0) - (z1 - z0) * (c.x - x0)
            p.material_index = IV if d > 0 else SL

def paper_solid(name, src, keep=lambda P: True, crease=None, clip=(), bone="Root", y_half=None, amp=.009):
    """Ivory paper body from a stock part's outline, two planes along a
    diagonal crease (default: corner to corner, climbing forward)."""
    hull = hull_xz(src, keep, .003)
    for a_, b_, c_ in clip:
        hull = clip_poly(hull, a_, b_, c_)
    xs = [p[0] for p in hull]; zs = [p[1] for p in hull]
    if crease is None:
        zc = (min(zs) + max(zs)) / 2; h = max(zs) - min(zs)
        crease = ((min(xs), zc - h * .18), (max(xs), zc + h * .18))
    reach = max(.05, (max(zs) - min(zs)) * .7)
    o, hull = hull_solid(name, src, keep, y_half=y_half, mat=IV, margin=.003, clip=clip, bone=bone, ch=.005,
                         fold=(crease[0], crease[1], amp, reach))
    paint_fold(o, *crease)
    return o, hull

def pattern_window(o, outline, y_floor, both=True):
    cs = [prism(outline, y_floor, .3, floor=PAT, side=WALL)]
    if both:
        cs.append(prism(outline, -y_floor, -.3, floor=PAT, side=WALL))
    cut(o, cs, rim=.0025)

def inset(hull, d, clip=()):
    """Outline shrunk toward its centre by d, optionally clipped."""
    cx, cz = outline_center(hull)
    out = []
    for x, z in hull:
        v = Vector((x - cx, z - cz)); L = v.length or 1
        out.append((x - v.x / L * d, z - v.y / L * d))
    for a_, b_, c_ in clip:
        out = clip_poly(out, a_, b_, c_)
    return out

def pleats(name, x_in, x_out, zs, y, bone="Root"):
    """Accordion pleats down a butt face: alternate ridge/valley rows."""
    bm = bmesh.new()
    L_, R_ = [], []
    for i, z in enumerate(zs):
        xo = x_out if i % 2 == 0 else x_out + (x_in - x_out) * .35
        L_.append((bm.verts.new((x_in, y, z)), bm.verts.new((xo, y, z))))
        R_.append((bm.verts.new((x_in, -y, z)), bm.verts.new((xo, -y, z))))
    for i in range(len(zs) - 1):
        a, b_ = L_[i], L_[i + 1]; c, d = R_[i], R_[i + 1]
        f = bm.faces.new((a[1], b_[1], d[1], c[1])); f.material_index = IV if i % 2 == 0 else SL
        f = bm.faces.new((a[0], a[1], b_[1], b_[0])); f.material_index = SL
        f = bm.faces.new((c[0], d[0], d[1], c[1])); f.material_index = SL
        f = bm.faces.new((a[0], b_[0], d[0], c[0])); f.material_index = SL
    f = bm.faces.new((L_[0][0], R_[0][0], R_[0][1], L_[0][1])); f.material_index = IV
    f = bm.faces.new((L_[-1][1], R_[-1][1], R_[-1][0], L_[-1][0])); f.material_index = SL
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return tri(link(name, bm, bone))

def paper_plate(name, outline, y0, y1, crease, bone="Root", amp=.008):
    bm = solid_plate(outline, y0, y1, ch=.004, fold=(crease[0], crease[1], amp, .10))
    o = link(name, bm, bone)
    paint_fold(o, *crease)
    mirror_apply(o)
    return tri(o)

def boat(name, src, keep, z_cut, bone="Mag", y_half=None, grow=.008):
    """Folded boat base: the magazine outline below z_cut, a touch larger."""
    hull = clip_poly(hull_xz(src, keep, grow), 0.0, -1.0, z_cut)
    yh = (y_half or max(abs(p.y) for p in comp_points(src, keep))) + grow
    xs = [p[0] for p in hull]; zs = [p[1] for p in hull]
    o = link(name, solid_plate(hull, 0, yh, ch=.005, open_inner=True,
                               fold=((min(xs), max(zs)), (max(xs), min(zs) + .01), .008, .08)), bone)
    mirror_apply(o, merge=True)
    return tri(o)

def shroud(name, x0, x1, zc, r, bone="Root"):
    rings = []
    for i, (x, rr) in enumerate(((x0, r), (x0 + (x1 - x0) * .35, r * 1.10), (x0 + (x1 - x0) * .70, r * .98), (x1, r * .72))):
        a0 = math.radians(45 * i)
        rings.append([(x, rr * math.cos(a0 + math.pi / 2 * j), zc + rr * math.sin(a0 + math.pi / 2 * j)) for j in range(4)])
    return tri(link(name, loft3(rings, [IV, SL, IV, SL], cap_mat=INK), bone))

def foil_band(name, x0, x1, src, zc, bone="Root", grow=.004, n=10):
    o = bpy.data.objects[src]
    P = [o.matrix_world @ v.co for v in o.data.vertices]
    S = [q for q in P if x0 - .02 <= q.x <= x1 + .02] or P
    ry = max(abs(q.y) for q in S) + grow; rz = max(abs(q.z - zc) for q in S) + grow
    st = [[(x, ry * math.cos(2 * math.pi * (i + .5) / n), zc + rz * math.sin(2 * math.pi * (i + .5) / n)) for i in range(n)] for x in (x0, x1)]
    return link(name, loft3(st, [FOIL] * n, cap_mat=FOIL), bone)

def spike(name, base, tip, w, y, bone="Root"):
    """Flat paper spike: base edge (two points) to a tip, a thin folded blade."""
    (bx0, bz0), (bx1, bz1) = base
    out = [(bx0, bz0), (bx1, bz1), tip]
    bm = solid_plate(out, y - w, y + w, ch=.002, fold=((bx0, bz0), tip, .004, .05))
    o = link(name, bm, bone)
    paint_fold(o, (bx0, bz0), tip)
    if y > w:                                   # off-centre spikes come in mirrored pairs
        mirror_apply(o)
    return tri(o)

# ------------------------------------------------------------------ guns
def gf2_marshal():
    p = {}
    HIDE = ["Marshal_ForeEnd", "Marshal_Pins", "Marshal_Neon"]
    fe, feh = paper_solid("GFM_ForeEnd", "Marshal_ForeEnd", crease=((.89, .03), (1.91, .17)))
    pattern_window(fe, [(1.00, .150), (1.62, .168), (1.74, .130), (1.60, .040), (1.02, .040)], .066)
    p["fe"] = tri(fe)
    p["spike"] = spike("GFM_Spike", ((1.80, -.010), (1.904, .060)), (2.12, .040), .010, .060)
    # folded butt enclosing the stock's rear (the wrist stays stock in ivory), wave panel, pleated heel
    st, sth = paper_solid("GFM_Stock", "Marshal_Stock", clip=((-1.0, 0.0, -.15),), y_half=.074,
                          crease=((-.15, .16), (-1.22, -.20)))
    pattern_window(st, inset(sth, .085, clip=((-1.0, 0.0, -.32),)), .068)
    p["stock"] = tri(st)
    p["pleats"] = pleats("GFM_Pleats", -1.212, -1.262, [.060, -.010, -.080, -.150, -.220, -.290], .072)
    rec = [(.20, .245), (.86, .245), (.885, .22), (.88, .095), (.84, .085), (.24, .085), (.20, .11)]
    p["clad"] = paper_plate("GFM_ReceiverFold", rec, .066, .080, ((.20, .10), (.88, .24)))
    p["foil"] = [foil_on("GFM_FoilRec", p["clad"], .66, .130, length=.07), foil_on("GFM_FoilStock", st, -.30, .120, length=.06, angle=-.3)]
    p["bands"] = [foil_band("GFM_ScopeBandA", 1.02, 1.04, "Marshal_Scope", .333), foil_band("GFM_ScopeBandB", .30, .32, "Marshal_Scope", .333)]
    tables = {"Marshal_Stock": IV_TABLE, "Marshal_Receiver": IV_TABLE, "Marshal_Scope": [MATS[0], MATS[1], MATS[1], MATS[7], MATS[5], MATS[7], EXTRA["Neon"], EXTRA["Brass"]]}
    tables.update({n: PEW_TABLE for n in ("Marshal_Barrel", "Marshal_Lever", "Marshal_Hammer", "Marshal_Trigger", "Marshal_CharmLoop", "Marshal_Bolt")})
    return p, HIDE, tables

_GF2 = {"Marshal": gf2_marshal}
exec(open(os.path.join(TB, "model_giltfold_guns2_more.py")).read()) if os.path.exists(os.path.join(TB, "model_giltfold_guns2_more.py")) else None
parts, _hide, _tables = _GF2[ITEM_KEY]()
for n in _hide:
    o = bpy.data.objects.get(n)
    if o:
        o.hide_render = True; o.hide_set(True)
for o in col.objects:
    flat_uv(o)
HARDWARE = [n for n in _tables if n in bpy.data.objects]
STOCK_PARTS = list(_hide)
set_skin = gun_set_skin_factory(_hide, _tables)
set_skin(True)
ensure_aim(ITEM_KEY)
result = {"objects": [(o.name, len(o.data.polygons)) for o in col.objects], "cut_failures": CUT_FAILURES}
