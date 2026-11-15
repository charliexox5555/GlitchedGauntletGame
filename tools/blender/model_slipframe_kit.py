"""Slipframe line kit: palette + shared part builders.

Exec after model_moltframe_vandal_v04.py (helpers, collection, link/cut/...)
and the helper half of model_moltframe_vandal_v04_parts.py, plus the
retain()/zcut() helpers. Overrides MATS with the Slipframe palette, keeping
the slot roles the bake/export pipeline expects:
  0 ARM    satin titanium shell        4 INSET  silver-blue inlay (the line's signature; glint motion)
  1 EDGE   polished bevel highlight    5 GRIP   matte graphite
  2 CORE   charcoal inner frame        6 STEEL  brushed silver
  3 GASKET seam shadow                 7 ACCENT smoky anodised blue face

Brief (vault/02 Art/Skins/Slipframe/concept.md): smooth satin titanium shell
around a darker inner frame, a broad anodised blue face, one shallow recessed
silver-blue inlay that stops at a solid metal break, crisp bevel highlights,
broad open surfaces, opaque alloy (no glass, no circuitry glow).
"""

def sf_material(name, hexc, metal, rough, coat=0.0):
    m, nt, b = pbsdf(name, hexc, metal, rough, coat)
    return m, nt, b

def brushed(name, hexc, metal, rough, scale=(2.0, 60.0, 60.0), spread=.05):
    """Faint directional brushing along the gun (x): low-contrast streaks."""
    m, nt, b = pbsdf(name, hexc, metal, rough)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping"); mp.inputs["Scale"].default_value = scale
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    nz = nt.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 3.0; nz.inputs["Detail"].default_value = 4.0
    nt.links.new(mp.outputs[0], nz.inputs["Vector"])
    rr = nt.nodes.new("ShaderNodeMapRange")
    rr.inputs["To Min"].default_value = rough - spread; rr.inputs["To Max"].default_value = rough + spread
    nt.links.new(nz.outputs["Fac"], rr.inputs["Value"]); nt.links.new(rr.outputs[0], b.inputs["Roughness"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (*[v * .95 for v in _lin(hexc)], 1)
    ramp.color_ramp.elements[1].color = (*[v * 1.05 for v in _lin(hexc)], 1)
    nt.links.new(nz.outputs["Fac"], ramp.inputs[0]); nt.links.new(ramp.outputs[0], b.inputs["Base Color"])
    return m

def inlay_material():
    """Brushed silver-blue strip with a short glint that travels along it and
    stops at the strip's end (seamless 144-frame loop; static at rest is a
    plain brushed strip, which is also the baked map)."""
    m = brushed("SF1 Silver-Blue Inlay", "A9C6DD", 1.0, .20, scale=(1.5, 90.0, 90.0), spread=.04)
    nt = m.node_tree; b = nt.nodes["Principled BSDF"]; N = nt.nodes; L = nt.links.new
    tc = N.new("ShaderNodeTexCoord"); sep = N.new("ShaderNodeSeparateXYZ"); L(tc.outputs["Object"], sep.inputs[0])
    t = N.new("ShaderNodeValue"); t.name = t.label = "glint_phase"
    fc = t.outputs[0].driver_add("default_value"); fc.driver.expression = "((frame-1) % 144)/144"
    # phase along the gun: one glint per loop, travelling front -> back
    sx = N.new("ShaderNodeMath"); sx.operation = "MULTIPLY"; sx.inputs[1].default_value = -.28; L(sep.outputs["X"], sx.inputs[0])
    ad = N.new("ShaderNodeMath"); ad.operation = "ADD"; L(sx.outputs[0], ad.inputs[0]); L(t.outputs[0], ad.inputs[1])
    fr = N.new("ShaderNodeMath"); fr.operation = "FRACT"; L(ad.outputs[0], fr.inputs[0])
    d = N.new("ShaderNodeMath"); d.operation = "SUBTRACT"; d.inputs[1].default_value = .5; L(fr.outputs[0], d.inputs[0])
    ab = N.new("ShaderNodeMath"); ab.operation = "ABSOLUTE"; L(d.outputs[0], ab.inputs[0])
    band = N.new("ShaderNodeMapRange"); band.inputs["From Min"].default_value = .035; band.inputs["From Max"].default_value = 0.0
    band.clamp = True; L(ab.outputs[0], band.inputs["Value"])
    b.inputs["Emission Color"].default_value = (*_lin("D9ECFF"), 1)
    L(band.outputs[0], b.inputs["Emission Strength"])
    em = N.new("ShaderNodeMath"); em.operation = "MULTIPLY"; em.inputs[1].default_value = 4.0
    L(band.outputs[0], em.inputs[0]); L(em.outputs[0], b.inputs["Emission Strength"])
    m["mf_hex"] = "A9C6DD"
    return m

MATS = [
    brushed("SF1 Titanium Shell", "8D96A3", .85, .34, scale=(1.0, 40.0, 40.0), spread=.035),   # 0 ARM
    pbsdf("SF1 Polished Bevel", "CFDBE7", 1.0, .13)[0],                                           # 1 EDGE
    pbsdf("SF1 Charcoal Frame", "212831", .45, .46)[0],                                           # 2 CORE
    pbsdf("SF1 Seam Shadow", "11161C", 0.0, .6)[0],                                               # 3 GASKET
    inlay_material(),                                                                             # 4 INSET
    pbsdf("SF1 Graphite Grip", "343C46", 0.0, .72)[0],                                            # 5 GRIP
    brushed("SF1 Brushed Silver", "A9B8C5", 1.0, .30),                                            # 6 STEEL
    pbsdf("SF1 Anodised Blue", "2E5E7D", .9, .26, .25)[0],                                        # 7 ACCENT
]
ACCENT = 7
CHAMBER_MAT = MATS[4].name
EXTRA = {"Neon": pbsdf("SF1 Ice Indicator", "97D8EB", 0.0, .3)[0], "Brass": pbsdf("SF1 Cool Grey Casing", "9CAAB6", 1.0, .3)[0]}
_ind = EXTRA["Neon"].node_tree.nodes["Principled BSDF"]
_ind.inputs["Emission Color"].default_value = (*_lin("97D8EB"), 1); _ind.inputs["Emission Strength"].default_value = 2.0
# stock slot order: Body, Panel, Dark, Metal, Grip, Accent, Neon, Brass
SLOT_SKIN = [MATS[0], MATS[ACCENT], MATS[2], MATS[6], MATS[5], MATS[4], EXTRA["Neon"], EXTRA["Brass"]]

# --------------------------------------------------------------- builders
def sf_section(W, zb, zt, notch=None, inner=.04):
    """+Y half section bottom -> top. Broad polished top bevel (the line's
    'crisp bevel highlight'), small lower bevel. notch=(z0, z1, depth_y)."""
    pts = [(inner, zb), (W - .010, zb), (W, zb + .012)]
    mats = [CORE, EDGE]
    if notch:
        z0, z1, dy = notch
        pts += [(W, z0), (dy, z0 + .006), (dy, z1 - .006), (W, z1)]
        mats += [ARM, CORE, CORE, CORE]
    pts += [(W, zt - .040), (W - .024, zt - .008), (W - .034, zt)]
    mats += [ARM, EDGE, EDGE]
    return pts, mats

def sf_loft(name, stations, notch=None, bone="Root", end_scale=(1.0, 1.0)):
    """stations: [(x, W, zb, zt)]. Carved ends: first/last ring scaled in."""
    st, mats = [], None
    for i, (x, W, zb, zt) in enumerate(stations):
        half, mats = sf_section(W, zb, zt, notch)
        k = end_scale[0] if i == 0 else end_scale[1] if i == len(stations) - 1 else 1.0
        if k != 1.0:
            zc = (zb + zt) / 2
            half = [(y * k, zc + (z - zc) * (.5 + .5 * k)) for y, z in half]
        st.append((x, ring(half)))
    return link(name, loft(st, ring_mats(mats, bottom=CORE, top=ARM), cap_mat=EDGE), bone)

def face_plate(name, outline, y0, y1, mat=None, vents=(), vent_floor=None, fold=None, bone="Root", rim=.0045):
    """Broad anodised face: polished rim, optional raked vents (dark floors)."""
    bm = solid_plate(outline, y0, y1, ch=rim, fold=fold, mat=ACCENT if mat is None else mat)
    o = link(name, bm, bone)
    if vents:
        cutters = []
        for v in vents:
            cutters.append(prism(v, vent_floor or (y0 + .004), .4, floor=CORE, side=GASKET))
            cutters.append(prism(v, -(vent_floor or (y0 + .004)), -.4, floor=CORE, side=GASKET))
        # vents cut before mirroring would only hit +Y; plates are built +Y then mirrored
        cut(o, cutters[0::2], rim=.002)
    mirror_apply(o)
    return o

def inlay_band(name, outline, y0, y1, strip, floor_y, bone="Root"):
    """Charcoal inset band carrying the recessed silver-blue inlay strip."""
    o = link(name, solid_plate(outline, y0, y1, ch=.003, mat=CORE), bone)
    cut(o, [prism(strip, floor_y, .4, floor=INSET_IDX, side=GASKET)], rim=.0018)
    mirror_apply(o)
    return o

INSET_IDX = 4

def raked_vents(x0, n, pitch, z0, z1, w=.026, lean=.03):
    return [[(x0 + i * pitch, z0), (x0 + i * pitch + w, z0), (x0 + i * pitch + w + lean, z1), (x0 + i * pitch + lean, z1)]
            for i in range(n)]

def frame_stock(prefix, top_path, top_w, top_t, low_p0, low_p1, butt_outline, butt_w, face=None):
    """Angular frame stock with an open triangle: titanium top strut,
    charcoal brace, titanium butt with an optional blue face plate."""
    STRUT_SF = [(1, 0), (.62, .8), (.0, 1), (-.62, .8), (-1, 0), (-.62, -.8), (0, -1), (.62, -.8)]
    top = link(prefix + "_StockTop", sweep(top_path, (0, 1, 0), top_w, top_t, STRUT_SF,
                                            [EDGE, ARM, ARM, ARM, ARM, ARM, ARM, EDGE]))
    path = [Vector(low_p0).lerp(Vector(low_p1), t) for t in (0, .15, .5, .85, 1)]
    low = link(prefix + "_StockLow", sweep(path, (0, 1, 0), [.064, .050, .048, .050, .058], [.036, .032, .030, .032, .036],
                                           STRUT_SF, [EDGE, CORE, CORE, CORE, CORE, CORE, CORE, EDGE]))
    butt = link(prefix + "_Butt", solid_plate(butt_outline, 0, butt_w, ch=.008, open_inner=True))
    mirror_apply(butt, merge=True)
    parts = [top, low, butt]
    if face:
        parts.append(face_plate(prefix + "_ButtFace", face, butt_w - .006, butt_w + .006))
    return parts
