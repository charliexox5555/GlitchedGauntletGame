"""Sealwork Dagger v02 (Knife slot). Exec after the Sealwork kit's palette
(exec model_giltfold_kit.py, then the palette half of model_sealwork_kit.py),
stock Knife open.

v02 (owner 2026-11-14: "doesn't look anything like the example"): a full
sculpted dagger in the spirit of the Ruin reference's quality bar, original
shapes. A talon blade that rises to a raised tip with a hooked tooth near the
guard, gold edge and spine lines, a dark fuller; a gold guard with swept
flares; a new carved grip (stock section where the fist sits) with chevron
scales and gold studs; a carved pommel head holding a faceted vermilion gem in
a clipped-corner gold setting, ending in a gold-rimmed hook. Every curve is
flat facets. Stock grip point (RightGrip at the origin), blade base and reach
kept, so the stock Knife clips still fit."""

_k = open(os.path.join(TB, "model_sealwork_kit.py")).read()
exec(_k[:_k.index("def sw_marshal")])          # Sealwork palette + seal()

JADE, GOLD, DARK, GROOVE, RED = 0, 1, 2, 3, 4

def _pl(pts, x):
    for (x0, z0), (x1, z1) in zip(pts, pts[1:]):
        if x0 <= x <= x1:
            return z0 + (z1 - z0) * (x - x0) / (x1 - x0)
    return pts[-1][1] if x > pts[-1][0] else pts[0][1]

SPINE = [(.355, .060), (.45, .068), (.60, .084), (.75, .108), (.88, .140), (1.00, .180), (1.10, .222), (1.17, .258), (1.215, .282)]
EDGE_L = [(.355, -.066), (.383, -.068), (.425, -.116), (.452, -.088), (.50, -.094), (.58, -.095), (.68, -.081), (.80, -.051),
          (.90, -.009), (1.00, .050), (1.09, .118), (1.16, .200), (1.215, .282)]
XS = [.355, .383, .405, .425, .452, .50, .58, .68, .80, .90, 1.00, 1.09, 1.16, 1.20, 1.215]

def blade_t(x):
    return .0165 * (1 - max(0.0, (x - .80) / .42) * .70)

def build_blade():
    """Talon blade; the fuller is part of the section (no boolean): a dark
    recessed band between 52 and 68 % of the blade height."""
    st = []
    for x in XS:
        s, e = _pl(SPINE, x), _pl(EDGE_L, x)
        h = max(.004, s - e)
        t = blade_t(x)
        g = t * .70
        half = [(.0008, e), (.0045, e + min(.014, .20 * h)), (t * .82, e + .34 * h), (t, e + .48 * h),
                (g, e + .53 * h), (g, e + .66 * h), (t, e + .71 * h), (t, s - .015), (t * .72, s - .005), (.0035, s)]
        st.append((x, ring(half)))
    x, r = st[-1]
    st[-1] = (x, [(y * .12, z) for y, z in r])            # carved tip ridge, not a needle
    mats = [GOLD, JADE, JADE, DARK, DARK, DARK, JADE, JADE, JADE]
    o = link("SWD_Blade", loft(st, ring_mats(mats, bottom=GOLD, top=GOLD), cap_mat=GOLD))
    for p in o.data.polygons:                       # fuller only between the guard flare and the curl
        if p.material_index == DARK and not (.47 < p.center.x < 1.00):
            p.material_index = JADE
    return o

def build_spur():
    """Gold thorn on the spine just ahead of the guard, swept back."""
    f = sweep([(.392, 0, .058), (.425, 0, .074), (.452, 0, .094), (.462, 0, .114)], (0, 0, 1),
              [.034, .028, .018, .004], [.010, .009, .006, .002],
              section=[(1, 0), (.6, .8), (-.6, .8), (-1, 0), (-.6, -.8), (.6, -.8)],
              mats=[GOLD, ACCENT, GOLD, ACCENT, ACCENT, ACCENT])
    return join("SWD_Spur", [f])

def build_guard():
    out = [(.316, .074), (.350, .100), (.394, .090), (.394, -.080), (.404, -.104), (.392, -.136), (.350, -.158),
           (.366, -.126), (.352, -.108), (.316, -.098), (.306, -.060), (.306, .044)]
    o = link("SWD_Guard", solid_plate(out, 0, .034, ch=.005, mat=ACCENT, open_inner=True,
                                      fold=((.30, .0), (.40, .0), .004, .14)))
    mirror_apply(o, merge=True)
    slot = [(.336, .058), (.350, .072), (.364, .058), (.364, -.074), (.350, -.094), (.336, -.074)]
    cut(o, [prism(slot, .0285, .3, floor=DARK, side=DARK), prism(slot, -.0285, -.3, floor=DARK, side=DARK)], rim=.0012)
    # gold ferrule hugging the front grip band
    fr = [[(x, y, z) for y, z in ring(grip_half(.30, kk))] for x, kk in ((.286, .99), (.290, 1.04), (.302, 1.04), (.306, .99))]
    fer = link("SWD_Ferrule", loft3(fr, [ACCENT] * len(fr[0]), cap_mat=ACCENT))
    # flame flares on both blade faces: one under the spine, one into the tooth
    fl = []
    for pts in ([(.390, .022), (.45, .040), (.53, .060), (.632, .090), (.57, .086), (.48, .076), (.390, .066)],
                [(.390, -.032), (.412, -.058), (.430, -.098), (.410, -.084), (.390, -.068)]):
        fl.append(solid_plate(pts, .011, .0205, ch=.0016, mat=ACCENT))
    f = join("SWD_GuardFlare", fl)
    mirror_apply(f)
    return o, f, fer

def grip_half(x, k=1.0):
    zc = -.004 - max(0.0, -x - .05) * .10              # slight drop toward the pommel
    zt, zb = zc + .084 * k, zc - .092 * k
    w = .050 * k
    return [(.018 * k, zb), (.041 * k, zb + .014 * k), (w, zb + .046 * k), (w, zt - .040 * k), (.042 * k, zt - .013 * k), (.018 * k, zt)]

SLANT = .30            # carved bands lean back toward the pommel
BANDS = [.306, .196, .086, -.024, -.134, -.244, -.330]

def build_grip():
    """Overlapping carved bands: each band swells from its front edge to its
    back edge and steps down into the next one (stock section where the fist
    sits, about +-0.050 wide and 0.18 tall)."""
    st = []
    for i, (xa, xb) in enumerate(zip(BANDS, BANDS[1:])):
        st.append((xa - .0005 if i else xa, .90))
        st.append(((xa + xb) / 2, .965))
        st.append((xb + .0035, 1.0))
    st.append((BANDS[-1], .96))
    rings = []
    for x, k in st:
        rings.append([(x + SLANT * (z - (-.004)), y, z) for y, z in ring(grip_half(x, k))])
    o = link("SWD_Grip", loft3(rings, ring_mats([DARK, JADE, JADE, JADE, DARK], bottom=DARK, top=DARK), cap_mat=DARK))
    for p in o.data.polygons:                       # the step faces are the dark carve lines
        if abs(p.normal.x) > .55 and p.center.x < .30:
            p.material_index = DARK
    studs = []
    for xb in BANDS[1:-1]:
        zc = -.004 - max(0.0, -xb - .05) * .10
        sx, sz = xb + SLANT * .0 + .004, zc
        d = [(sx - .012, sz), (sx, sz - .013), (sx + .012, sz), (sx, sz + .013)]
        studs.append(solid_plate(d, .046, .0565, ch=.002, mat=ACCENT))
    g = join("SWD_Studs", studs)
    mirror_apply(g)
    return o, g

def build_pommel():
    """Faceted knob carrying the gem, then a gold-rimmed talon hook."""
    st = []
    for x, k in ((-.330, .96), (-.352, 1.06), (-.395, 1.06), (-.432, .90), (-.452, .62), (-.460, .34)):
        st.append([(x, y, z) for y, z in ring(grip_half(-.33, k))])
    h = link("SWD_PommelHead", loft3(st, ring_mats([DARK, JADE, JADE, JADE, GOLD], bottom=DARK, top=GOLD), cap_mat=GOLD))
    path = [(-.392, 0, -.074), (-.448, 0, -.098), (-.490, 0, -.136), (-.509, 0, -.186), (-.498, 0, -.232), (-.466, 0, -.264)]
    sec = [(1, 0), (.6, .8), (-.6, .8), (-1, 0), (-.6, -.8), (.6, -.8)]
    k = join("SWD_PommelHook", [sweep(path, (0, 1, 0), [.064, .056, .046, .036, .024, .006], [.026, .024, .021, .018, .013, .004],
                                      section=sec, mats=[GOLD, JADE, GOLD, GOLD, JADE, GOLD])])
    return h, k

def build_gem(cx, cz, y0, r=.028):
    """Faceted vermilion gem in a clipped-corner gold setting, both faces."""
    def clipped(half, clip):
        return [(cx - half + clip, cz - half), (cx + half - clip, cz - half), (cx + half, cz - half + clip),
                (cx + half, cz + half - clip), (cx + half - clip, cz + half), (cx - half + clip, cz + half),
                (cx - half, cz + half - clip), (cx - half, cz - half + clip)]
    s1 = solid_plate(clipped(r * 1.40, r * .50), y0 - .004, y0 + .0045, ch=.0016, mat=ACCENT)
    s2 = solid_plate(clipped(r * 1.16, r * .42), y0 + .004, y0 + .0085, ch=.0012, mat=ACCENT)
    setting = join("SWD_GemSetting", [s1, s2])
    mirror_apply(setting)
    n = 8
    def octo(rr, y):
        return [(cx + rr * math.cos(2 * math.pi * (i + .5) / n), y, cz + rr * math.sin(2 * math.pi * (i + .5) / n)) for i in range(n)]
    rings = [octo(r * .98, y0 + .006), octo(r, y0 + .011), octo(r * .62, y0 + .019)]
    g = link("SWD_Gem", loft3(rings, [RED] * n, caps=(True, True), cap_mat=RED))
    mirror_apply(g)
    return setting, g

parts = {}
parts["blade"] = build_blade()
parts["spur"] = build_spur()
parts["guard"] = build_guard()
parts["grip"] = build_grip()
parts["pommel"] = build_pommel()
parts["gem"] = build_gem(-.393, -.010, .0515)
for o in col.objects:
    flat_uv(o)

HARDWARE = []
STOCK_PARTS = ["Knife_Blade", "Knife_Hilt", "Knife_Neon"]

def set_skin(on):
    for n in STOCK_PARTS:
        o = bpy.data.objects[n]; o.hide_render = on; o.hide_set(on)
    col.hide_render = not on
    col.hide_viewport = not on

set_skin(True)
result = {"objects": [(o.name, len(o.data.polygons)) for o in col.objects], "cut_failures": CUT_FAILURES}
