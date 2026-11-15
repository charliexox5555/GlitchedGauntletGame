"""Payload round two: Bulldog, Ghost, Operator, Ares, Odin, Classic, Stinger
as full flight-hardware sculpts in the language of the approved Payload
Vandal v02: white enamel housings with engraved seams and vents, carbon-twill
lower parts and grips with raised square grids, crumpled thermal-foil pillows,
quilted white padding, smoked-steel fittings, mission-blue controls and tube
glows, the clipped foil inset with two blue marks, foil crowns. Exec after
model_giltfold_kit.py and model_vandal_shell_base.py (run_sfg KIT chain),
stock item open, ITEM_KEY set. Body parts are rebuilt from their own side
outlines (hull_solid); parts holding moving-part channels stay stock in the
line finishes with white cladding."""

_v = open(os.path.join(TB, "model_payload_vandal.py")).read()
exec(_v[_v.index('_k = open(os.path.join(TB, "model_payload_kit.py")).read()'):_v.index("def zt_top(x):")])
# defines: Payload palette + carbon/padding/glow, WHITE..GLOW indices, _h, pillow, quad_fn
WHITE_T = [MATS[WHITE], MATS[HOUS], MATS[GRA], MATS[STL], MATS[CARB], MATS[BLUE], EXTRA["Neon"], EXTRA["Brass"]]
CARB_T = [MATS[CARB], MATS[GRA], MATS[GRA], MATS[STL], MATS[CARB], MATS[BLUE], EXTRA["Neon"], EXTRA["Brass"]]
STEEL_T = [MATS[STL], MATS[GRA], MATS[GRA], MATS[STL], MATS[CARB], MATS[BLUE], EXTRA["Neon"], EXTRA["Brass"]]
BLUE_T = [MATS[BLUE]] * 6 + [EXTRA["Neon"], EXTRA["Brass"]]

def white_solid(name, src, keep=lambda P: True, clip=(), bone="Root", y_half=None, mat=WHITE, seams=(), crease=None):
    """White enamel housing from a stock part's outline (bevel-grey rims);
    seams = side-view polylines engraved as dark lines."""
    hull = hull_xz(src, keep, .003)
    xs = [p[0] for p in hull]; zs = [p[1] for p in hull]
    if crease is None:
        zc = (min(zs) + max(zs)) / 2
        crease = ((min(xs), zc + .01), (max(xs), zc - .01))
    o, hull = hull_solid(name, src, keep, y_half=y_half, mat=mat, margin=.003, clip=clip, bone=bone, ch=.006,
                         fold=(crease[0], crease[1], .004, max(.05, (max(zs) - min(zs)) * .6)))
    ls = []
    for i, pts in enumerate(seams):
        ln = inlay_line(name + "_Seam%d" % i, o, pts, w=.004, h=.0018, mat=REC, bone=bone)
        if ln:
            ls.append(ln)
    return o, hull, ls

def grip_squares(name, target, outline, bone="Root", rake=(-.078, -.259), step=(.038, .036), h=.0085, zlim=None):
    """Raised square grid aligned with a grip's rake, every square fully
    inside the inset outline (owner note: no square crosses an edge)."""
    def inside(poly, q):
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
    d = Vector(rake).normalized(); pp = Vector((-d.y, d.x))
    if pp.x < 0:
        pp = -pp
    cx, cz = outline_center(outline)
    studs = []
    for i in range(-12, 13):
        for j in range(-8, 9):
            c = Vector((cx, cz)) + d * (step[0] * i) + pp * (step[1] * j)
            if zlim and not (zlim[0] < c.y < zlim[1]):
                continue
            corners = [c + d * h + pp * h, c + d * h - pp * h, c - d * h - pp * h, c - d * h + pp * h]
            if all(inside(outline, (q.x, q.y)) for q in corners):
                ys = [surface_pt(target, q.x, q.y) for q in corners]
                ys = [y for y in ys if y is not None]
                if len(ys) == 4:
                    studs.append(solid_plate([(q.x, q.y) for q in corners], min(ys) - .002, max(ys) + .0045, ch=.0012, mat=GRA))
    if not studs:
        return None
    o = join(name, studs, bone)
    mirror_apply(o)
    return o

def foil_pillow_on(name, target, quad, bone="Root", nu=8, nv=3, puff=.014):
    """Crumpled thermal-foil pillow seated on a part side: quad = four
    side-view corners (0,0) (1,0) (1,1) (0,1)."""
    ys = [surface_pt(target, x, z) for x, z in quad]
    ys = [y for y in ys if y is not None]
    if not ys:
        return None
    return pillow(name, quad_fn(*quad), nu, nv, min(ys) - .002, puff, FOIL, bone=bone, crumple=.0022, edge=.45)

def quilt_lines(name, target, rows, bone="Root"):
    out = []
    for i, pts in enumerate(rows):
        ln = inlay_line(name + "%d" % i, target, pts, w=.0045, h=.0015, mat=HOUS, bone=bone)
        if ln:
            out.append(ln)
    return out

def strap(name, x0, x1, src, bone="Root", grow=.006, mat=FOIL):
    o = bpy.data.objects[src] if isinstance(src, str) else src
    P = [o.matrix_world @ v.co for v in o.data.vertices]
    S = [q for q in P if x0 - .02 <= q.x <= x1 + .02] or P
    y = max(abs(q.y) for q in S) + grow; z0 = min(q.z for q in S) - grow; z1 = max(q.z for q in S) + grow
    st = [(x, [(0.0, z0), (y, z0 + .010), (y, z1 - .010), (0.0, z1), (-y, z1 - .010), (-y, z0 + .010)]) for x in (x0, x1)]
    return link(name, loft(st, [mat] * 6, cap_mat=mat), bone)

def crown(name, x0, zc, r, bone="Root", length=.06):
    rings = [[(x, rr * math.cos(math.radians(22.5 + 45 * i)), zc + rr * math.sin(math.radians(22.5 + 45 * i))) for i in range(8)]
             for x, rr in ((x0, r * .94), (x0 + .008, r), (x0 + length - .006, r), (x0 + length, r * .94))]
    cr = link(name, loft3(rings, [FOIL] * 8, cap_mat=GRA), bone)
    teeth = []
    for i in range(8):
        a = math.radians(22.5 + 45 * i); b = math.radians(45 * i)
        tp = [(x0 + length - .006, r * 1.02 * math.cos(a), zc + r * 1.02 * math.sin(a)), (x0 + length - .006, r * .74 * math.cos(a), zc + r * .74 * math.sin(a)),
              (x0 + length + .02, r * .88 * math.cos(b), zc + r * .88 * math.sin(b))]
        bm = bmesh.new(); vs = [bm.verts.new(q) for q in tp]
        f = bm.faces.new(vs); f.material_index = FOIL
        bmesh.ops.solidify(bm, geom=[f], thickness=.004)
        teeth.append(bm)
    return cr, join(name + "Teeth", teeth, bone)

def part_r(src, x0, x1, zc):
    o = bpy.data.objects[src]
    P = [o.matrix_world @ v.co for v in o.data.vertices]
    S = [q for q in P if x0 <= q.x <= x1]
    return max(max(abs(q.y) for q in S), max(abs(q.z - zc) for q in S))

_PL2 = {}
exec(open(os.path.join(TB, "model_payload_guns2_items.py")).read())
parts, _hide, _tables = _PL2[ITEM_KEY]()
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
