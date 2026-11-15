"""Slipframe Dagger (Knife slot). Exec after model_slipframe_kit.py (stock Knife
open). Asymmetrical wedge (tanto) blade: brushed silver faces, a polished
cobalt edge bevel that is wider on the player-facing side, a swept graphite
spine; slim dark metal handle on the stock grip core (stock hold transform and
Knife clips reused); angular titanium guard and pommel with a cobalt band."""

def blade_heights(x):
    sp = [(.36, .062), (.80, .066), (1.04, .072), (1.27, .010)]
    ed = [(.36, -.058), (.44, -.080), (1.02, -.080), (1.15, -.052), (1.27, .004)]
    def lerp(pts):
        for (x0, z0), (x1, z1) in zip(pts, pts[1:]):
            if x0 <= x <= x1:
                return z0 + (z1 - z0) * (x - x0) / (x1 - x0)
        return pts[-1][1]
    return lerp(sp), lerp(ed)

def build_blade():
    xs = [.355, .44, .60, .80, .95, 1.04, 1.10, 1.15, 1.21, 1.27]
    st = []
    for x in xs:
        s, e = blade_heights(x)
        h = s - e
        t = .015 * (1 - max(0, (x - 1.04) / .23) * .85)
        # +Y (player side) has the wider cobalt grind, -Y the narrower one
        pos = [(.0006, e), (.0045, e + .30 * h), (t, e + .46 * h), (t, s - .014), (t * .55, s)]
        neg = [(-.0006, e), (-.0050, e + .18 * h), (-t, e + .30 * h), (-t, s - .014), (-t * .55, s)]
        ringp = pos + list(reversed(neg))
        st.append((x, ringp))
    x, r = st[-1]
    st[-1] = (x, [(y * .15, z) for y, z in r])
    mats = [ACCENT, ACCENT, STEEL, CORE, CORE, CORE, STEEL, ACCENT, ACCENT, ACCENT]
    return link("SFD_Blade", loft(st, mats, cap_mat=EDGE))

def build_guard():
    out = [(.315, .088), (.385, .088), (.405, .06), (.405, -.075), (.385, -.104), (.330, -.104), (.305, -.07), (.305, .055)]
    o = link("SFD_Guard", solid_plate(out, 0, .044, ch=.006, mat=ARM, open_inner=True))
    mirror_apply(o, merge=True)
    band = [(.322, .02), (.398, .02), (.398, -.02), (.322, -.02)]
    b = link("SFD_GuardBand", solid_plate(band, .043, .049, ch=.002, mat=ACCENT))
    mirror_apply(b)
    return o, b

def build_pommel():
    out = [(-.335, .090), (-.42, .090), (-.468, .052), (-.475, -.030), (-.44, -.092), (-.335, -.098)]
    o = link("SFD_Pommel", solid_plate(out, 0, .068, ch=.008, mat=ARM, open_inner=True))
    mirror_apply(o, merge=True)
    band = [(-.36, .07), (-.38, .07), (-.38, -.078), (-.36, -.078)]
    b = link("SFD_PommelBand", solid_plate(band, .066, .072, ch=.002, mat=ACCENT))
    mirror_apply(b)
    return o, b

def build_handle_inlay():
    """One short silver-blue inlay on the slim handle, ending at the guard."""
    out = [(-.25, .062), (.28, .062), (.30, .045), (.28, .030), (-.25, .030), (-.27, .045)]
    o = link("SFD_HandleSpine", solid_plate(out, .044, .054, ch=.003, mat=CORE))
    cut(o, [prism([(-.18, .041), (.24, .041), (.255, .046), (.24, .051), (-.18, .051), (-.19, .046)], .0505, .4,
                  floor=INSET_IDX, side=GASKET)], rim=.0015)
    mirror_apply(o)
    return o

hw = {}
hw["grip"] = retain("Knife_Hilt", lambda P: min(p.x for p in P) > -.35 and max(p.x for p in P) < .34, "SFD_GripCore")
for p in hw["grip"].data.polygons:
    p.material_index = 2          # slim dark metal handle (charcoal frame in the retained slot order)
parts = {}
parts["blade"] = build_blade()
parts["guard"] = build_guard()
parts["pommel"] = build_pommel()
parts["handle"] = build_handle_inlay()
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
result = {"objects": [(o.name, len(o.data.polygons)) for o in col.objects]}
