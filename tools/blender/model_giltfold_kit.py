"""Giltfold line kit (exec after the shared helpers, like model_slipframe_kit).
Slot roles kept for the bake/export pipeline:
  0 ARM    warm paper ivory (lit plane of a fold)    4 INSET  ink lacquer with a champagne wave pattern
  1 EDGE   fold-shadow slate (second plane)          5 GRIP   dark graphite
  2 CORE   ink charcoal lacquer                      6 STEEL  cool pewter, brushed
  3 GASKET recess wall                               7 ACCENT champagne foil (trim and bar pairs only)
Brief (vault/02 Art/Skins/Giltfold/concept.md): two or three broad planes per
gun meeting at a shallow diagonal crease, dark lacquer recesses, pairs of
short offset foil bars, static finishes (no motion except the Fan's poses).
"""

def lacquer_pattern(S=12.0, rings=3.0, line=.24):
    """Ink lacquer with an original champagne wave-scale pattern: staggered
    rows of arches (top half of concentric rings round each cell centre), so
    the scales read like fanned paper. Static (the line has no motion)."""
    m, nt, b = pbsdf("GF1 Lacquer Pattern", "1E1C26", 0.0, .22, .6)
    N = nt.nodes; L = nt.links.new
    def mth(op, a_, b_=None):
        n = N.new("ShaderNodeMath"); n.operation = op
        for i, v in enumerate((a_, b_)):
            if v is None:
                continue
            if isinstance(v, (int, float)):
                n.inputs[i].default_value = v
            else:
                L(v, n.inputs[i])
        return n.outputs[0]
    tc = N.new("ShaderNodeTexCoord"); sep = N.new("ShaderNodeSeparateXYZ"); L(tc.outputs["Object"], sep.inputs[0])
    row = mth("FLOOR", mth("MULTIPLY", sep.outputs["Z"], S))
    odd = mth("MULTIPLY", mth("FRACT", mth("MULTIPLY", row, .5)), 2.0)          # 0 / 1
    xs = mth("ADD", sep.outputs["X"], mth("MULTIPLY", odd, .5 / S))
    xz = N.new("ShaderNodeCombineXYZ"); L(xs, xz.inputs[0]); L(sep.outputs["Z"], xz.inputs[1])
    vo = N.new("ShaderNodeTexVoronoi"); vo.inputs["Scale"].default_value = S
    vo.inputs["Randomness"].default_value = 0.0
    L(xz.outputs[0], vo.inputs["Vector"])
    fr = mth("FRACT", mth("MULTIPLY", vo.outputs["Distance"], rings * 2.0))
    ln = N.new("ShaderNodeMapRange"); ln.inputs["From Min"].default_value = .0; ln.inputs["From Max"].default_value = line
    ln.inputs["To Min"].default_value = 1.0; ln.inputs["To Max"].default_value = 0.0; ln.clamp = True
    L(fr, ln.inputs["Value"])
    cz = N.new("ShaderNodeSeparateXYZ"); L(vo.outputs["Position"], cz.inputs[0])
    up = mth("GREATER_THAN", mth("SUBTRACT", sep.outputs["Z"], cz.outputs["Y"]), -.08 / S)
    msk = mth("MULTIPLY", ln.outputs[0], up)
    mix = N.new("ShaderNodeMix"); mix.data_type = "RGBA"
    L(msk, mix.inputs["Factor"])
    mix.inputs["A"].default_value = (*_lin("1E1C26"), 1); mix.inputs["B"].default_value = (*_lin("D2AE66"), 1)
    L(mix.outputs["Result"], b.inputs["Base Color"])
    L(mth("MULTIPLY", msk, .9), b.inputs["Metallic"])
    L(mth("SUBTRACT", .30, mth("MULTIPLY", msk, .12)), b.inputs["Roughness"])
    m["mf_hex"] = "1E1C26"
    return m

def ivory():
    m, nt, b = pbsdf("GF1 Paper Ivory", "E8DAC0", 0.0, .42, .15)
    # faint paper tooth: very low-contrast value noise (about +-3%)
    tc = nt.nodes.new("ShaderNodeTexCoord"); nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 18.0; nz.inputs["Detail"].default_value = 3.0
    nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
    rp = nt.nodes.new("ShaderNodeValToRGB")
    rp.color_ramp.elements[0].color = (*[v * .96 for v in _lin("E8DAC0")], 1)
    rp.color_ramp.elements[1].color = (*[v * 1.03 for v in _lin("E8DAC0")], 1)
    nt.links.new(nz.outputs["Fac"], rp.inputs[0]); nt.links.new(rp.outputs[0], b.inputs["Base Color"])
    return m

MATS = [
    ivory(),                                                  # 0 ARM
    pbsdf("GF1 Fold Slate", "C2B49A", 0.0, .45, .1)[0],       # 1 EDGE (second fold plane): warm ivory shadow (owner: no cool grey)
    pbsdf("GF1 Ink Lacquer", "26252D", 0.1, .22, .5)[0],      # 2 CORE
    pbsdf("GF1 Recess Wall", "17161C", 0.0, .5)[0],           # 3 GASKET
    lacquer_pattern(),                                        # 4 INSET
    pbsdf("GF1 Grip Graphite", "34323B", 0.0, .72)[0],        # 5 GRIP
    pbsdf("GF1 Pewter", "A89A7E", 1.0, .32)[0],               # 6 STEEL: warm champagne pewter
    pbsdf("GF1 Champagne Foil", "C9AA68", 1.0, .22)[0],       # 7 ACCENT
]
ACCENT = 7
INSET_IDX = 4
CHAMBER_MAT = MATS[4].name
EXTRA = {"Neon": pbsdf("GF1 Indicator", "BFD8FF", 0.0, .3)[0], "Brass": pbsdf("GF1 Smoked Pewter Casing", "6E737D", 1.0, .3)[0]}
_ind = EXTRA["Neon"].node_tree.nodes["Principled BSDF"]
_ind.inputs["Emission Color"].default_value = (*_lin("BFD8FF"), 1); _ind.inputs["Emission Strength"].default_value = 1.5
# stock slot order: Body, Panel, Dark, Metal, Grip, Accent, Neon, Brass
SLOT_SKIN = [MATS[0], MATS[1], MATS[2], MATS[6], MATS[5], MATS[7], EXTRA["Neon"], EXTRA["Brass"]]
DARK_SKIN = [MATS[2], MATS[1], MATS[2], MATS[6], MATS[5], MATS[7], EXTRA["Neon"], EXTRA["Brass"]]

def fold_plate(name, outline, y0, y1, crease, amp=.010, reach=.12, lower=1, upper=0, bone="Root", ch=.0045,
               windows=(), win_floor=None, mirror=True):
    """Folded card: two planes meeting at a diagonal crease (upper plane
    ivory, lower plane slate by default), dark lacquer windows with the
    pattern floor. crease = ((x0, z0), (x1, z1))."""
    bm = solid_plate(outline, y0, y1, ch=ch, fold=(crease[0], crease[1], amp, reach), mat=upper)
    (fx0, fz0), (fx1, fz1) = crease
    d = Vector((fx1 - fx0, fz1 - fz0)).normalized(); n = Vector((-d.y, d.x))
    mid = (y0 + y1) / 2
    for f in bm.faces:
        c = f.calc_center_median()
        if c.y > mid and f.normal.y > .3 and f.material_index in (upper, lower):
            side = (c.x - fx0) * n.x + (c.z - fz0) * n.y
            f.material_index = upper if side > 0 else lower
    o = link(name, bm, bone)
    if windows:
        cut(o, [prism(w, win_floor or (y0 + .004), .4, floor=INSET_IDX, side=GASKET) for w in windows], rim=.0018)
    if mirror:
        mirror_apply(o)
    return o

def foil_pair(name, x, z, length=.06, h=.010, gap=.008, offset=.012, y0=.0, y1=.006, bone="Root", angle=0.0):
    """Pair of short offset champagne bars (the line's original accent)."""
    bars = []
    ca, sa = math.cos(angle), math.sin(angle)
    for i in range(2):
        ox = x + i * offset; oz = z - i * (h + gap)
        pts = [(0, 0), (length, 0), (length + .004, h * .5), (length, h), (0, h), (-.004, h * .5)]
        pts = [(ox + px * ca - pz * sa, oz + px * sa + pz * ca) for px, pz in pts]
        bars.append(solid_plate(pts, y0, y1, ch=.0012, mat=ACCENT))
    o = join(name, bars, bone)
    mirror_apply(o)
    return o

def surface_y(obj, x, z):
    """+Y surface of a built (mirrored) plate at (x, z), by raycast."""
    from mathutils.bvhtree import BVHTree
    t = BVHTree.FromPolygons([obj.matrix_world @ v.co for v in obj.data.vertices], [p.vertices[:] for p in obj.data.polygons])
    hit = t.ray_cast(Vector((x, 1.0, z)), Vector((0, -1, 0)))
    return hit[0].y if hit[0] is not None else None

def foil_on(name, target, x, z, length=.06, h=.010, gap=.008, offset=.012, bone="Root", angle=0.0):
    """Foil bar pair seated on the target plate's surface (0.004 proud)."""
    bars = []
    ca, sa = math.cos(angle), math.sin(angle)
    for i in range(2):
        ox = x + i * offset; oz = z - i * (h + gap)
        pts = [(0, 0), (length, 0), (length + .004, h * .5), (length, h), (0, h), (-.004, h * .5)]
        pts = [(ox + px * ca - pz * sa, oz + px * sa + pz * ca) for px, pz in pts]
        ys = [surface_y(target, px, pz) for px, pz in pts]
        ys = [y for y in ys if y is not None]
        if not ys:
            continue
        bars.append(solid_plate(pts, min(ys) - .004, max(ys) + .004, ch=.0012, mat=ACCENT))
    o = join(name, bars, bone)
    mirror_apply(o)
    return o
