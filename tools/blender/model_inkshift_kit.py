"""Inkshift line kit. Exec model_giltfold_kit.py first (fold_plate, surface_y),
then this file: it swaps in the Inkshift palette.
  0 ARM  warm white plate        4 INSET cyan (the broken accent; low glow, optional glint)
  1 EDGE ink line (plate rims)   5 GRIP  graphite
  2 CORE ink charcoal recess     6 STEEL cool slate
  3 GASKET recess wall           7 ACCENT armour blue
  8 INDIGO shadow face           9 VERMILION tab      10 HIGHLIGHT flat reflection shape
Brief (vault/02 Art/Skins/Inkshift/concept.md): comic-panel mecha armour,
strongest ink lines at the major panel boundaries (the plate rims), smaller
surfaces read through flat colour changes (white plane / indigo plane at a
crease), a few flat reflection shapes, a broken cyan accent (one long
segment + two short offset marks) in a dark recess, sparse vermilion."""

def flat(name, hexc, rough=.5, metal=0.0):
    m, nt, b = pbsdf(name, hexc, metal, rough)
    b.inputs["Specular IOR Level"].default_value = .25          # comic: soft, flat highlights
    return m

def cyan():
    m, nt, b = pbsdf("IK1 Cyan Accent", "37E9FF", 0.0, .3)
    b.inputs["Emission Color"].default_value = (*_lin("37E9FF"), 1)
    b.inputs["Emission Strength"].default_value = 1.4
    return m

MATS = [
    flat("IK1 Warm White", "DFE4E9", .55),       # 0
    flat("IK1 Ink Line", "1D2431", .45),         # 1
    flat("IK1 Ink Charcoal", "1D2431", .5),      # 2
    flat("IK1 Recess Wall", "10141C", .6),       # 3
    cyan(),                                      # 4
    flat("IK1 Graphite", "323743", .7),          # 5
    flat("IK1 Cool Slate", "8796A8", .35, .6),   # 6
    flat("IK1 Armour Blue", "4867AD", .45),      # 7
    flat("IK1 Indigo Shadow", "323F73", .5),     # 8
    flat("IK1 Vermilion", "E46C40", .45),        # 9
    flat("IK1 Flat Highlight", "F7FAFC", .3),    # 10
]
ACCENT, INDIGO, VERMILION, HIGHLIGHT = 7, 8, 9, 10
INSET_IDX = 4
CHAMBER_MAT = MATS[4].name
EXTRA = {"Neon": MATS[4], "Brass": flat("IK1 Blue-Grey Casing", "6F7F98", .35, .7)}
SLOT_SKIN = [MATS[0], MATS[7], MATS[2], MATS[6], MATS[5], MATS[9], EXTRA["Neon"], EXTRA["Brass"]]
DARK_SKIN = [MATS[8], MATS[7], MATS[2], MATS[6], MATS[5], MATS[9], EXTRA["Neon"], EXTRA["Brass"]]

def ink_plate(name, outline, y0, y1, crease, amp=.006, reach=.10, bone="Root", lower=INDIGO, upper=0, **kw):
    """White plane over an indigo plane, inked rims (EDGE chamfer)."""
    return fold_plate(name, outline, y0, y1, crease, amp=amp, reach=reach, lower=lower, upper=upper, bone=bone, **kw)

def _seated(name, target, pts, mat, bone, lift=.003, mirror=True):
    ys = [surface_y(target, px, pz) for px, pz in pts]
    ys = [y for y in ys if y is not None]
    if not ys:
        return None
    o = link(name, solid_plate(pts, min(ys) - .003, max(ys) + lift, ch=.0012, mat=mat), bone)
    if mirror:
        mirror_apply(o)
    return o

def cyan_accent(prefix, target, x, z, length=.20, angle=0.0, bone="Root"):
    """Dark recess cut into the plate (both sides) holding the broken cyan
    accent: one long segment and two short marks offset from it."""
    ca, sa = math.cos(angle), math.sin(angle)
    def P(px, pz):
        return (x + px * ca - pz * sa, z + px * sa + pz * ca)
    h = .026
    win = [P(-.012, -h / 2), P(length + .012, -h / 2), P(length + .02, 0), P(length + .012, h / 2), P(-.012, h / 2), P(-.02, 0)]
    floor = surface_y(target, *P(length / 2, 0))
    if floor is None:
        return []
    fy = floor - .006
    cut(target, [prism(win, fy, .5, floor=CORE, side=GASKET), prism(win, -fy, -.5, floor=CORE, side=GASKET)], rim=.0015)
    segs = [(0.0, .58), (.64, .78), (.84, 1.0)]
    out = []
    for i, (a, b) in enumerate(segs):
        dz = 0 if i == 0 else -.004 + .008 * (i - 1)
        pts = [P(length * a, -.005 + dz), P(length * b, -.005 + dz), P(length * b + .004, dz), P(length * b, .005 + dz),
               P(length * a, .005 + dz), P(length * a - .004, dz)]
        o = link(f"{prefix}_Cyan{i}", solid_plate(pts, fy - .001, fy + .0035, ch=.0008, mat=INSET_IDX), bone)
        mirror_apply(o)
        out.append(o)
    return out

def flash(name, target, x, z, w=.05, h=.012, lean=.02, bone="Root"):
    """Flat comic reflection shape seated on a plate."""
    pts = [(x, z), (x + w, z), (x + w + lean, z + h), (x + lean, z + h)]
    return _seated(name, target, pts, HIGHLIGHT, bone, lift=.0025)

def tab(name, target, pts, bone="Root"):
    """Small vermilion end tab seated on a plate."""
    return _seated(name, target, pts, VERMILION, bone, lift=.005)
