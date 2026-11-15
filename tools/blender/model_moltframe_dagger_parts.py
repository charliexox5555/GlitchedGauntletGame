"""Moltframe Dagger (Knife slot): the line's language on the stock Knife.

Exec order (stock Knife_RemasterV2_v05 open):
    RIG_NAME, COL_NAME, ITEM_KEY = "Knife_Rig", "Moltframe Dagger", "Dagger"
    exec(model_moltframe_vandal_v04.py); exec(<helper half of the Vandal parts file>)
    exec(<retain/zcut helpers from model_moltframe_spectre_parts.py>)
    exec(this file)

Brief: compact, slightly hooked dagger, bright alloy edge, swept shell-shaped
guard (its upper horn the one spike), dark grip, one recessed violet insert. The stock grip core stays where
the fist sits (RightGrip at the origin), so the stock Knife clips and hold
transform can be reused; the blade keeps the stock base (x .35) and tip reach.
"""

def blade_station(x):
    """Spine (top) and edge (bottom) heights; the tip hooks up."""
    sp = [(.36, .062), (.70, .066), (.95, .076), (1.10, .098), (1.20, .132), (1.262, .168)]
    ed = [(.36, -.064), (.42, -.088), (.62, -.084), (.85, -.052), (1.05, .012), (1.18, .088), (1.262, .168)]
    def lerp(pts):
        # before the first station: hold the first height (the base ring at
        # x .355 used to fall through to the tip height, collapsing the blade
        # base into a sliver that left a gap in front of the guard and a fin
        # poking out of its top; owner 2026-11-14)
        if x <= pts[0][0]:
            return pts[0][1]
        for (x0, z0), (x1, z1) in zip(pts, pts[1:]):
            if x0 <= x <= x1:
                return z0 + (z1 - z0) * (x - x0) / (x1 - x0)
        return pts[-1][1]
    return lerp(sp), lerp(ed)

def build_blade():
    xs = [.355, .40, .48, .58, .70, .82, .95, 1.05, 1.13, 1.19, 1.235, 1.262]
    st = []
    for x in xs:
        s, e = blade_station(x)
        h = s - e
        t = .0165 * (1 - max(0, (x - 1.05) / .25) * .85)
        half = [(.0006, e), (.0055, e + .26 * h), (t, e + .50 * h), (t, s - .010), (t * .62, s)]
        st.append((x, ring(half)))
    # carved tip: last ring collapses to a short ridge, not a point
    x, r = st[-1]
    st[-1] = (x, [(y * .15, z) for y, z in r])
    # strips: edge grind, grind-to-flat, flat, spine chamfer
    mats = [EDGE, EDGE, EDGE, ARM]
    o = link("MFD_Blade", loft(st, ring_mats(mats, bottom=EDGE, top=ARM), cap_mat=EDGE))
    # (the swept spine fang was removed: owner 2026-11-14, "the spines look
    # weird"; the guard's upper horn is the dagger's one spike)
    return o

def build_guard():
    """Swept shell guard: an upper horn reaching forward over the blade spine
    and a lower horn sweeping back over the fingers."""
    # the upper horn's underside rests on the blade spine (z .063) instead of
    # arching over it: no open slot between horn and blade (owner 2026-11-14)
    out = [(.300, .100), (.345, .136), (.420, .132), (.478, .108), (.446, .058), (.378, .058),
           (.376, -.072), (.402, -.102), (.392, -.140), (.330, -.134), (.292, -.098), (.300, .060)]
    o = link("MFD_Guard", solid_plate(out, 0, .042, ch=.006, open_inner=True,
                                       fold=((.29, .0), (.48, .0), .008, .15)))
    mirror_apply(o, merge=True)
    return o

def build_grip_shell():
    """Graphite scale plates on both grip faces, with the line's one recessed
    violet insert; the stock grip core stays the hand surface."""
    out = [(-.300, .060), (-.20, .072), (.10, .074), (.26, .066), (.30, .040), (.27, .010),
           (.10, .018), (-.10, .016), (-.27, .020), (-.31, .040)]
    o = link("MFD_GripShell", solid_plate(out, .046, .060, ch=.0035, fold=((-.31, .045), (.30, .045), .004, .05)))
    win = [(-.18, .044), (-.13, .062), (.12, .064), (.18, .046), (.13, .028), (-.13, .026)]
    cut(o, [prism(win, .0505, .3), prism(win, -.0505, -.3)], rim=.002)
    mirror_apply(o)
    sb = []
    for xa in (-.05, .05):
        sb.append(sweep([(xa - .012, .051, .028), (xa, .052, .045), (xa + .012, .051, .062)],
                        (0, 1, 0), [.016, .012, .016], [.010, .009, .010]))
    s = join("MFD_GripSinews", sb)
    mirror_apply(s)
    return o, s

def build_pommel():
    """Carved pommel shell with a swept tail fang (replaces the hex cap)."""
    out = [(-.335, .095), (-.40, .098), (-.445, .070), (-.470, .010), (-.512, -.060), (-.450, -.050),
           (-.420, -.092), (-.335, -.098)]
    o = link("MFD_Pommel", solid_plate(out, 0, .072, ch=.008, open_inner=True))
    mirror_apply(o, merge=True)
    return o

hw = {}
hw["grip"] = retain("Knife_Hilt", lambda P: min(p.x for p in P) > -.35 and max(p.x for p in P) < .34,
                    "MFD_GripCore")
# retained hilt keeps its stock slot order (Dark -> core graphite, Grip -> grip)
parts = {}
parts["blade"] = build_blade()
parts["guard"] = build_guard()
parts["grip"] = build_grip_shell()
parts["pommel"] = build_pommel()
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
