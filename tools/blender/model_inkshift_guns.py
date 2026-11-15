"""Inkshift Odin (hero), Phantom, Vandal, Stinger, Shorty. Exec after
model_inkshift_kit.py with the item's stock file open and ITEM_KEY set.
Inked plates over the stock geometry; every moving part (charging handles,
bolts, feed cover, belt, ammo box, break-open barrels, shells, latches,
magazines) keeps its stock shape and travel."""

def ik_odin():
    p = []
    # front edge stays behind the feed cover (x .788) and its opening sweep
    sh = ink_plate("IKO_Shoulder", [(-.15, .565), (.72, .565), (.765, .54), (.765, .392), (-.10, .392), (-.155, .43)],
                   .100, .110, ((-.15, .50), (.765, .46)), amp=.005, reach=.08)
    p.append(sh)
    lo = ink_plate("IKO_LowerFace", [(-.15, .285), (.78, .285), (.80, .26), (.78, .165), (-.10, .165), (-.155, .20)],
                   .100, .110, ((-.15, .245), (.80, .21)), amp=.005, reach=.08)
    p.append(lo)
    tray = ink_plate("IKO_TrayFace", [(.80, .47), (1.10, .47), (1.10, .14), (.84, .14), (.80, .18)],
                     .100, .109, ((.80, .36), (1.10, .30)), amp=.004, reach=.10)
    p.append(tray)
    hg = ink_plate("IKO_HandguardFace", [(1.10, .48), (2.20, .48), (2.25, .44), (2.24, .20), (2.19, .18), (1.12, .16), (1.10, .20)],
                   .114, .122, ((1.10, .40), (2.25, .30)), amp=.005, reach=.14)
    p.append(hg)
    box = ink_plate("IKO_BoxFace", [(.62, .09), (1.36, .09), (1.38, .06), (1.37, -.32), (1.33, -.345), (.64, -.345), (.61, -.31)],
                    .160, .168, ((.61, -.05), (1.38, -.18)), amp=.004, reach=.16, bone="AmmoBox")
    p.append(box)
    st = ink_plate("IKO_StockFace", [(-.30, .44), (-.96, .44), (-.97, .02), (-.88, -.20), (-.60, -.01), (-.30, .20)],
                   .072, .080, ((-.30, .36), (-.96, .18)), amp=.005, reach=.14)
    p.append(st)
    p += cyan_accent("IKO_Shoulder", sh, .16, .49, length=.34)
    p.append(flash("IKO_Flash1", hg, 1.30, .43, w=.10))
    p.append(flash("IKO_Flash2", sh, .50, .54, w=.08))
    p.append(tab("IKO_TabHG", hg, [(2.13, .20), (2.21, .20), (2.23, .24), (2.15, .24)]))
    p.append(tab("IKO_TabStock", st, [(-.86, .40), (-.94, .40), (-.94, .43), (-.86, .43)]))
    return p

def ik_phantom():
    p = []
    rec = ink_plate("IKP_ReceiverFace", [(.15, .335), (.93, .335), (.935, .30), (.92, .17), (.86, .14), (.47, .14), (.45, .16), (.15, .16)],
                    .089, .099, ((.15, .27), (.94, .22)), amp=.005, reach=.10, lower=ACCENT)
    p.append(rec)
    hg = ink_plate("IKP_HandguardFace", [(.94, .425), (1.60, .425), (1.645, .40), (1.64, .22), (1.60, .20), (.96, .20), (.94, .23)],
                   .088, .098, ((.94, .36), (1.645, .29)), amp=.005, reach=.12, lower=ACCENT)
    p.append(hg)
    st = ink_plate("IKP_StockFace", [(-.30, .40), (-1.05, .40), (-1.06, .30), (-.95, .25), (-.35, .30)],
                   .066, .074, ((-.30, .37), (-1.06, .33)), amp=.004, reach=.08)
    p.append(st)
    p += cyan_accent("IKP_Rec", rec, .52, .30, length=.30)
    p.append(flash("IKP_Flash", hg, 1.05, .39, w=.10))
    p.append(tab("IKP_Tab", hg, [(1.55, .21), (1.63, .21), (1.64, .25), (1.56, .25)]))
    # suppressor: quiet blue can, one edge highlight ring
    zc, n = .352, 12
    sup = bpy.data.objects["Phantom_Suppressor"]
    P = [sup.matrix_world @ v.co for v in sup.data.vertices]
    r = max(abs(q.y) for q in P if q.x > 1.96)
    st_ = [[(x, (r + .002) * math.cos(2 * math.pi * (i + .5) / n), zc + (r + .002) * math.sin(2 * math.pi * (i + .5) / n)) for i in range(n)]
           for x in (2.40, 2.415)]
    p.append(link("IKP_SuppressorEdge", loft3(st_, [HIGHLIGHT] * n, cap_mat=HIGHLIGHT)))
    return p

def ik_vandal():
    p = []
    up = ink_plate("IKV_UpperPlate", [(-.17, .428), (1.05, .428), (1.062, .41), (1.05, .350), (-.15, .350), (-.172, .37)],
                   .092, .103, ((-.17, .40), (1.06, .37)), amp=.004, reach=.07)
    p.append(up)
    # stepped second plate, slightly proud, over the front receiver
    st2 = ink_plate("IKV_StepPlate", [(.62, .428), (1.05, .428), (1.06, .41), (1.05, .365), (.66, .365)],
                    .103, .108, ((.62, .40), (1.06, .38)), amp=.002, reach=.05)
    p.append(st2)
    lo = ink_plate("IKV_Underside", [(.12, .276), (1.03, .276), (1.062, .25), (1.04, .152), (.80, .152), (.47, .155), (.15, .15), (.12, .19)],
                   .090, .101, ((.12, .27), (1.06, .27)), amp=.003, reach=.08, upper=INDIGO, lower=INDIGO)
    p.append(lo)
    hg = ink_plate("IKV_Handguard", [(1.05, .410), (1.64, .410), (1.685, .37), (1.68, .21), (1.64, .172), (1.09, .172), (1.05, .20)],
                   .095, .101, ((1.05, .33), (1.69, .28)), amp=.005, reach=.14)
    p.append(hg)
    mag = ink_plate("IKV_MagShadow", [(.505, .03), (.700, .06), (.835, -.17), (.90, -.31), (.84, -.35), (.69, -.33), (.60, -.20)],
                    .058, .0685, ((.62, .04), (.80, -.33)), amp=.004, reach=.10, bone="Mag", ch=.003, lower=ACCENT)
    p.append(mag)
    p += cyan_accent("IKV_Low", lo, .36, .215, length=.30)
    p.append(flash("IKV_Flash", hg, 1.15, .385, w=.10))
    p.append(tab("IKV_Tab", st2, [(.96, .40), (1.03, .40), (1.04, .42), (.97, .42)]))
    return p

def ik_stinger():
    p = []
    a = ink_plate("IKS_PlateA", [(.275, .388), (.78, .388), (.80, .36), (.79, .268), (.75, .262), (.30, .262), (.275, .29)],
                  .080, .090, ((.275, .35), (.80, .30)), amp=.005, reach=.10)
    p.append(a)
    b = ink_plate("IKS_PlateB", [(-.50, .385), (-.215, .385), (-.212, .30), (-.24, .15), (-.48, .15), (-.505, .20)],
                  .080, .090, ((-.505, .30), (-.21, .26)), amp=.005, reach=.10)
    p.append(b)
    p += cyan_accent("IKS_A", a, .36, .30, length=.18)
    p.append(tab("IKS_Tab", a, [(.70, .37), (.77, .37), (.78, .385), (.71, .385)]))
    return p

def ik_shorty():
    p = []
    # frame plate above the breech latch (latch +Y, z < .164); breaks into two ink-blue faces
    fr = ink_plate("IKH_FramePlate", [(-.08, .330), (.50, .330), (.52, .31), (.52, .175), (.48, .170), (-.05, .170), (-.085, .20)],
                   .090, .098, ((-.08, .28), (.52, .23)), amp=.004, reach=.08)
    p.append(fr)
    # barrels (Barrels bone): two ink-blue faces with the colour break between them
    br = ink_plate("IKH_BarrelFace", [(.62, .335), (1.36, .335), (1.40, .31), (1.40, .04), (1.36, .02), (.66, .02), (.62, .05)],
                   .104, .110, ((.62, .19), (1.40, .17)), amp=.003, reach=.10, bone="Barrels", upper=ACCENT, lower=INDIGO)
    p.append(br)
    p += cyan_accent("IKH_Fr", fr, .06, .30, length=.12)
    p.append(tab("IKH_Tab", br, [(1.30, .30), (1.37, .30), (1.38, .32), (1.31, .32)], bone="Barrels"))
    return p

_IK_BUILD = {"Odin": ik_odin, "Phantom": ik_phantom, "Vandal": ik_vandal, "Stinger": ik_stinger, "Shorty": ik_shorty}
parts = {"all": [x for x in _IK_BUILD[ITEM_KEY]() if x is not None]}
for o in col.objects:
    flat_uv(o)

def _stock_meshes(prefix):
    return [o.name for o in bpy.data.objects if o.type == "MESH" and o.name.startswith(prefix + "_") and o.parent is not None
            and o.parent.name == prefix + "_Rig"]
HARDWARE = [n for n in _stock_meshes(ITEM_KEY) if not n.endswith(("ScopeLens", "Lens"))]
_DARK = {"Odin": ("Odin_Grip",), "Phantom": ("Phantom_Grip", "Phantom_Mag", "Phantom_Suppressor"), "Vandal": ("Vandal_Grip", "Vandal_Mag", "Vandal_Rail"),
         "Stinger": ("Stinger_Handguard", "Stinger_Grip", "Stinger_Mag"), "Shorty": ("Shorty_Grip",)}[ITEM_KEY]
STOCK_PARTS = []

def set_skin(on):
    for n in HARDWARE:
        o = bpy.data.objects[n]
        table = DARK_SKIN if n in _DARK else SLOT_SKIN
        if n == "Phantom_Suppressor":
            table = [MATS[ACCENT]] * 3 + [MATS[6], MATS[5], MATS[9], EXTRA["Neon"], EXTRA["Brass"]]
        for i, sl in enumerate(o.material_slots):
            if i < 8:
                sl.material = table[i] if on else bpy.data.materials[STOCK_SET[i]]
    col.hide_render = not on
    col.hide_viewport = not on

set_skin(True)
result = {"objects": len(col.objects), "cut_failures": CUT_FAILURES}
