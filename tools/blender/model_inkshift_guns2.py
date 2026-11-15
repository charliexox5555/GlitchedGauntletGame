"""Inkshift round two: Odin, Phantom, Stinger, Shorty as intricate anime
pop-art mecha sculpts in the language of the Inkshift Vandal v02 (deep royal
blue over indigo shadow planes, layered white armour plates with angled cut
ends, vermilion stripes and swept fins, cyan glow lines and the broken cyan
accent, ink panel lines, flat comic highlight streaks, painted finish, black
inverted-hull ink outlines). Exec after model_giltfold_kit.py and
model_vandal_shell_base.py (run_sfg KIT chain), stock item open, ITEM_KEY set."""

_v = open(os.path.join(TB, "model_inkshift_vandal.py")).read()
exec(_v[_v.index('_k = open(os.path.join(TB, "model_inkshift_kit.py")).read()'):_v.index("def zt_top(x):")])
INK_T = globals().get("INK_T", .0055)
BLUE_T = [MATS[BLUE], MATS[INDG], MATS[CHAR], MATS[SLATE], MATS[GRAPH], MATS[VERM], MATS[CYAN], EXTRA["Brass"]]
WHITE_T = [MATS[WHITE], MATS[BLUE], MATS[CHAR], MATS[SLATE], MATS[GRAPH], MATS[VERM], MATS[CYAN], EXTRA["Brass"]]
INDG_T = [MATS[INDG], MATS[BLUE], MATS[CHAR], MATS[SLATE], MATS[GRAPH], MATS[VERM], MATS[CYAN], EXTRA["Brass"]]
SLATE_T = [MATS[SLATE], MATS[INDG], MATS[CHAR], MATS[SLATE], MATS[GRAPH], MATS[VERM], MATS[CYAN], EXTRA["Brass"]]
VERM_T = [MATS[VERM]] * 6 + [MATS[CYAN], EXTRA["Brass"]]

def armour_solid(name, src, keep=lambda P: True, clip=(), bone="Root", y_half=None, split=None, top=BLUE, low=INDG, rimmat=INKL):
    """Blue armour from a stock part's outline: ink rims, upper plane blue
    over an indigo shadow plane below the split line (side view)."""
    hull = hull_xz(src, keep, .003)
    for a_, b_, c_ in clip:
        hull = clip_poly(hull, a_, b_, c_)
    xs = [p[0] for p in hull]; zs = [p[1] for p in hull]
    if split is None:
        zc = min(zs) + (max(zs) - min(zs)) * .42
        split = ((min(xs), zc + .006), (max(xs), zc - .006))
    o, hull = hull_solid(name, src, keep, y_half=y_half, mat=top, margin=.003, clip=clip, bone=bone, ch=.0045, rim=rimmat,
                         fold=(split[0], split[1], .006, max(.05, (max(zs) - min(zs)) * .5)))
    (x0, z0), (x1, z1) = split
    for p in o.data.polygons:
        if abs(p.normal.y) > .3 and p.material_index == top:
            c = p.center
            if (x1 - x0) * (c.z - z0) - (z1 - z0) * (c.x - x0) < 0:
                p.material_index = low
    return o, hull

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

def flash(name, target, x, z, w=.06, h=.010, lean=.022):
    pts = [(x, z), (x + w, z), (x + w + lean, z + h), (x + lean, z + h)]
    ys = [surface_pt(target, px, pz) for px, pz in pts]
    ys = [y for y in ys if y is not None]
    if not ys:
        return None
    o = link(name, solid_plate(pts, min(ys) - .003, max(ys) + .0022, ch=.0008, mat=HILITE), target.parent_bone or "Root")
    mirror_apply(o)
    return o

def fin(name, x0, z0, y0, ln, hh, bone="Root", back=True):
    """Swept vermilion fin standing off a side shoulder (mirrored)."""
    s = -1 if back else 1
    bm = bmesh.new()
    a = bm.verts.new((x0, y0, z0)); b_ = bm.verts.new((x0 + s * ln, y0 + .004, z0 + .004)); c = bm.verts.new((x0 + s * ln * .78, y0 + .030, z0 + hh))
    a2 = bm.verts.new((x0, y0 - .010, z0 - .008)); b2 = bm.verts.new((x0 + s * ln, y0 - .006, z0 - .004)); c2 = bm.verts.new((x0 + s * ln * .78, y0 + .020, z0 + hh - .008))
    for f, m in (((a, b_, c), VERM), ((a2, c2, b2), VERM), ((a, a2, b2, b_), INKL), ((b_, b2, c2, c), VERM), ((c, c2, a2, a), VERM)):
        ff = bm.faces.new(f); ff.material_index = m
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = join(name, [bm], bone)
    mirror_apply(o)
    return o

def frame_stock(name, src, keep=lambda P: True, clip=(), inset=.075, open_x=None, y_half=None, white_above=None):
    """Angular open-frame stock: blue frame, white top beam, indigo butt,
    an ink-lined through window."""
    o, hull = hull_solid(name, src, keep, y_half=y_half, mat=BLUE, margin=.003, clip=clip, ch=.0055, rim=INKL)
    loop = inset_poly(hull, inset)
    if open_x is not None:
        loop = clip_poly(loop, -1.0, 0.0, open_x)
    if len(loop) >= 3:
        cut(o, [prism(loop, -.3, .3, floor=CHAR, side=CHAR, outer=CHAR)], rim=.004)
    zs = [p[1] for p in hull]; xs = [p[0] for p in hull]
    wa = white_above if white_above is not None else max(zs) - (max(zs) - min(zs)) * .14
    for p in o.data.polygons:
        if p.material_index == BLUE:
            if p.center.z > wa:
                p.material_index = WHITE
            elif p.center.x < min(xs) + .09:
                p.material_index = INDG
    return o, hull

def inset_poly(hull, d):
    cx, cz = outline_center(hull)
    out = []
    for x, z in hull:
        v = Vector((x - cx, z - cz)); L = v.length or 1
        out.append((x - v.x / L * d, z - v.y / L * d))
    return out

def ink_pass(names, mag_names=()):
    out = []
    for nm in names:
        o = bpy.data.objects.get(nm)
        if o:
            out.append(ink_outline(o, t=(.003 if (o.parent_bone == "Mag" or nm in mag_names) else INK_T)))
    return out

_IK2 = {}
exec(open(os.path.join(TB, "model_inkshift_guns2_items.py")).read())
parts, _hide, _tables, _inked = _IK2[ITEM_KEY]()
for n in _hide:
    o = bpy.data.objects.get(n)
    if o:
        o.hide_render = True; o.hide_set(True)
parts["ink"] = ink_pass(_inked)
for o in col.objects:
    flat_uv(o)
HARDWARE = [n for n in _tables if n in bpy.data.objects]
STOCK_PARTS = list(_hide)
set_skin = gun_set_skin_factory(_hide, _tables)
set_skin(True)
ensure_aim(ITEM_KEY)
result = {"objects": [(o.name, len(o.data.polygons)) for o in col.objects], "cut_failures": CUT_FAILURES}
