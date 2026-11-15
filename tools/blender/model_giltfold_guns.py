"""Giltfold Marshal, Stinger, Ghost and Classic. Exec after model_giltfold_kit.py
with the item's stock file open and ITEM_KEY set. Folded ivory/slate plates
over the stock geometry, lacquer pattern windows, offset foil pairs; all
moving parts (and their travel) stay stock and clear of the plates."""

def gf_marshal():
    p = []
    # receiver: upper fold above the -Y loading gate (z < .07) and clear of the hammer (|y| < .014)
    rec = fold_plate("GFM_ReceiverFace", [(.20, .245), (.86, .245), (.885, .22), (.88, .095), (.84, .085), (.24, .085), (.20, .11)],
                     .066, .076, ((.20, .17), (.89, .21)), amp=.005, reach=.09,
                     windows=[[(.50, .11), (.78, .11), (.82, .15), (.54, .15)]], win_floor=.0695)
    p.append(rec)
    fe = fold_plate("GFM_ForeEndFace", [(.895, .200), (1.88, .200), (1.90, .17), (1.885, .0), (1.85, -.010), (.93, -.010), (.895, .03)],
                    .068, .077, ((.89, .17), (1.90, .05)), amp=.005, reach=.14,
                    windows=[[(1.05, .02), (1.60, .02), (1.66, .06), (1.11, .06)]], win_floor=.0715)
    p.append(fe)
    st = fold_plate("GFM_StockFace", [(-.05, .195), (-1.15, .06), (-1.19, .02), (-1.17, -.26), (-.95, -.24), (-.10, .03), (-.04, .10)],
                    .066, .076, ((-.05, .14), (-1.18, -.05)), amp=.006, reach=.14,
                    windows=[[(-.30, .07), (-.95, -.03), (-.98, -.09), (-.33, .01)]], win_floor=.0695)
    p.append(st)
    p.append(foil_on("GFM_FoilRec", rec, .30, .215, length=.06))
    p.append(foil_on("GFM_FoilFE", fe, 1.70, .16, length=.07, angle=-.12))
    p.append(foil_on("GFM_FoilStock", st, -.55, .09, length=.06, angle=.12))
    return p

def gf_stinger():
    p = []
    # facet A: receiver front block (ahead of the charging handle's travel, x > .27)
    a = fold_plate("GFS_FacetA", [(.275, .388), (.78, .388), (.80, .36), (.79, .268), (.75, .262), (.30, .262), (.275, .29)],
                   .080, .090, ((.275, .37), (.80, .29)), amp=.006, reach=.10)
    p.append(a)
    # facet B: rear receiver behind the bolt's travel (x < -.21)
    b = fold_plate("GFS_FacetB", [(-.50, .385), (-.215, .385), (-.212, .30), (-.24, .15), (-.48, .15), (-.505, .20)],
                   .080, .090, ((-.505, .33), (-.21, .22)), amp=.006, reach=.10)
    p.append(b)
    hg = fold_plate("GFS_HandguardInset", [(.47, .262), (.82, .262), (.825, .24), (.80, .11), (.50, .11), (.47, .14)],
                    .084, .091, ((.47, .20), (.83, .20)), amp=.003, reach=.08, upper=2, lower=2,
                    windows=[[(.53, .135), (.74, .135), (.77, .17), (.56, .17)]], win_floor=.0865)
    p.append(hg)
    p.append(foil_on("GFS_FoilA", a, .62, .375, length=.06, angle=-.15))
    p.append(foil_on("GFS_FoilB", b, -.45, .37, length=.05))
    return p

def gf_ghost():
    p = []
    slide = fold_plate("GFG_SlideBevel", [(-.20, .385), (1.10, .385), (1.12, .36), (1.115, .245), (1.09, .236), (-.18, .236), (-.205, .26)],
                       .062, .071, ((-.205, .33), (1.12, .30)), amp=.004, reach=.10, bone="Slide")
    p.append(slide)
    p.append(foil_on("GFG_FoilSlide", slide, .82, .33, length=.05, bone="Slide"))
    # suppressor: a shallow colour break (slate band) and a small foil ring
    zc, n = .296, 12
    def band(x0, x1, r, mat):
        st = [[(x, r * math.cos(2 * math.pi * (i + .5) / n), zc + r * math.sin(2 * math.pi * (i + .5) / n)) for i in range(n)]
              for x in (x0, x1)]
        return loft3(st, [mat] * n, cap_mat=mat)
    sup = bpy.data.objects["Ghost_Suppressor"]
    P = [sup.matrix_world @ v.co for v in sup.data.vertices]
    # the can's tube has vertices only at its ends: take its radius from the extent
    r = max(abs(q.y) for q in P if q.x > 1.2)
    p.append(join("GFG_SuppressorBands", [band(1.48, 1.62, r + .002, 1), band(1.64, 1.655, r + .004, ACCENT)]))
    return p

def gf_classic():
    p = []
    out = [(-.255, .462), (.955, .462), (.985, .44), (.985, .318), (.965, .300), (-.235, .300), (-.258, .33)]
    cap = fold_plate("GFC_SlideFace", out, .066, .078, ((-.25, .43), (.30, .30)), amp=.004, reach=.10, bone="Slide")
    p.append(cap)
    p.append(foil_on("GFC_FoilSlide", cap, .70, .40, length=.05, bone="Slide"))
    return p

_GF_BUILD = {"Marshal": gf_marshal, "Stinger": gf_stinger, "Ghost": gf_ghost, "Classic": gf_classic}
parts = {"all": _GF_BUILD[ITEM_KEY]()}
for o in col.objects:
    flat_uv(o)

_STOCKS = {
    "Marshal": (["Marshal_Neon", "Marshal_Receiver", "Marshal_Barrel", "Marshal_ForeEnd", "Marshal_Scope", "Marshal_Stock",
                 "Marshal_Pins", "Marshal_CharmLoop", "Marshal_Lever", "Marshal_Bolt", "Marshal_Hammer", "Marshal_Trigger", "Marshal_Shell"],
                ("Marshal_Stock", "Marshal_Lever")),
    "Stinger": (["Stinger_Neon", "Stinger_Receiver", "Stinger_Handguard", "Stinger_Barrel", "Stinger_Sights", "Stinger_Grip",
                 "Stinger_Stock", "Stinger_Pins", "Stinger_CharmLoop", "Stinger_Mag", "Stinger_ChargingHandle", "Stinger_Bolt",
                 "Stinger_Trigger", "Stinger_FireSelector"], ("Stinger_Handguard", "Stinger_Grip", "Stinger_Mag")),
    "Ghost": (["Ghost_Slide", "Ghost_SlideNeon", "Ghost_Suppressor", "Ghost_Frame", "Ghost_Grip", "Ghost_Pins", "Ghost_CharmLoop",
               "Ghost_Mag", "Ghost_Trigger", "Ghost_SlideCatch", "Ghost_MagRelease"], ("Ghost_Frame", "Ghost_Grip", "Ghost_Mag")),
    "Classic": (["Classic_Slide", "Classic_SlideNeon", "Classic_Barrel", "Classic_Frame", "Classic_Grip", "Classic_Pins",
                 "Classic_CharmLoop", "Classic_Magazine", "Classic_MagNeon", "Classic_Trigger", "Classic_SlideCatch", "Classic_MagRelease"],
                ("Classic_Frame", "Classic_Grip", "Classic_Magazine")),
}
HARDWARE, _DARK = _STOCKS[ITEM_KEY]
STOCK_PARTS = []
if ITEM_KEY == "Ghost" and "MFR_Ghost_Aim" not in bpy.data.objects:
    _e = bpy.data.objects.new("MFR_Ghost_Aim", None); sc.collection.objects.link(_e); _e.location = (0.0, 0, .418)
if ITEM_KEY == "Classic" and "MFR_Classic_Aim" not in bpy.data.objects:
    _e = bpy.data.objects.new("MFR_Classic_Aim", None); sc.collection.objects.link(_e); _e.location = (0.0, 0, .512)

def set_skin(on):
    for n in HARDWARE:
        o = bpy.data.objects[n]
        if n.endswith("ScopeLens"):
            continue
        table = DARK_SKIN if n in _DARK else SLOT_SKIN
        if n == "Marshal_Scope":
            # brief: repeat ivory and slate on the outside of the scope housing
            table = [MATS[0], MATS[1], MATS[0], MATS[6], MATS[5], MATS[7], EXTRA["Neon"], EXTRA["Brass"]]
        for i, sl in enumerate(o.material_slots):
            if i < 8:
                sl.material = table[i] if on else bpy.data.materials[STOCK_SET[i]]
    col.hide_render = not on
    col.hide_viewport = not on

set_skin(True)
result = {"objects": [(o.name, len(o.data.polygons)) for o in col.objects], "cut_failures": CUT_FAILURES}
