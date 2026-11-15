"""Slipframe Guardian (hero). Exec after model_slipframe_kit.py with the stock
Guardian_RemasterV2_v05 open. Stock moving parts and locators untouched:
charging handle (+Y, x .48-.79 with travel), bolt (-Y, x .19-.63), selector
and bolt catch (+Y, on the retained lower receiver), magazine (Mag bone)."""

CH = (.18, .80, .272, .385, .0615)        # channel x0 x1 z0 z1 inner |y|

def build_shell():
    rear = sf_loft("SFG_ShellRear", [(-.013, .084, .236, .414), (.06, .086, .236, .414), (CH[0], .086, .236, .414)],
                   end_scale=(.82, 1.0))
    mid = sf_loft("SFG_ShellMid", [(CH[0], .086, .236, .414), (CH[1], .086, .236, .414)], notch=CH[2:])
    front = sf_loft("SFG_ShellFront", [(CH[1], .086, .236, .414), (.877, .088, .236, .414), (.92, .090, .211, .414),
                                       (1.14, .090, .192, .416), (2.20, .090, .190, .416), (2.30, .084, .200, .412),
                                       (2.355, .070, .222, .404)], end_scale=(1.0, .80))
    # magazine well (stock receiver cavity): the mag top rides up to z .258
    for o in (mid, front):
        cut(o, [zcut([(.46, -.072), (.86, -.072), (.86, .072), (.46, .072)], .20, .275, mat=CORE)], rim=0)
    return rear, mid, front

def build_faces():
    """Broad anodised face over the handguard, raked vents toward the
    muzzle; it ends at the solid grey shoulder (x .90) ahead of the grip."""
    out = [(.935, .396), (2.235, .396), (2.30, .345), (2.285, .255), (2.24, .236), (.985, .236), (.935, .27)]
    hg = face_plate("SFG_HandguardFace", out, .084, .097, vents=raked_vents(1.86, 5, .075, .262, .372),
                    vent_floor=.088, fold=((.93, .315), (2.30, .315), .004, .09))
    # rear receiver face above the bolt-catch, below the rail: the blue cap the
    # player sees in hip-fire, ending at the channel
    out2 = [(-.006, .404), (.165, .404), (.165, .30), (.12, .262), (-.006, .262)]
    rc = face_plate("SFG_ReceiverFace", out2, .082, .094, fold=((-.01, .33), (.17, .33), .003, .07))
    return hg, rc

def build_inlay():
    """Narrow charcoal inset below the blue face carrying the one recessed
    silver-blue inlay; it stops at a solid grey break at x .90."""
    band = [(.905, .236), (2.275, .236), (2.29, .222), (2.255, .196), (.93, .196), (.905, .215)]
    strip = [(.95, .206), (2.20, .206), (2.228, .2155), (2.20, .225), (.95, .225), (.938, .2155)]
    b = inlay_band("SFG_InsetBand", band, .082, .094, strip, .0875)
    # solid grey break: the shoulder block the seam runs into
    sh = [(.80, .236), (.905, .236), (.93, .214), (.905, .19), (.84, .19), (.80, .214)]
    s = link("SFG_Shoulder", solid_plate(sh, .080, .098, ch=.006, mat=ARM, fold=((.80, .213), (.93, .213), .004, .05)))
    mirror_apply(s)
    return b, s

def build_mag():
    """Blue face with a vertical inlay on the stock box magazine (Mag bone)."""
    out = [(.512, .07), (.776, .07), (.782, -.14), (.76, -.165), (.53, -.165), (.508, -.14)]
    o = link("SFG_MagFace", solid_plate(out, .060, .0705, ch=.003, mat=ACCENT), "Mag")
    strip = [(.715, .045), (.735, .045), (.738, -.135), (.712, -.135)]
    cut(o, [prism(strip, .0635, .4, floor=INSET_IDX, side=GASKET)], rim=.0015)
    mirror_apply(o)
    return o

def build_stock():
    top_path = [(x, 0, z) for x, z in ((-.06, .340), (-.12, .350), (-.30, .366), (-.55, .378), (-.80, .382), (-1.09, .382))]
    top_w = [.15, .13, .105, .098, .098, .100]
    top_t = [.062, .062, .060, .058, .058, .060]
    butt = [(-1.078, .414), (-1.15, .414), (-1.215, .396), (-1.245, .35), (-1.245, -.11), (-1.22, -.166),
            (-1.12, -.166), (-1.078, -.13)]
    face = [(-1.10, .372), (-1.185, .372), (-1.212, .33), (-1.212, -.08), (-1.19, -.124), (-1.10, -.124)]
    return frame_stock("SFG", top_path, top_w, top_t, (-.05, 0, .262), (-1.09, 0, -.10), butt, .074, face)

hw = {}
hw["pins"] = retain("Guardian_Pins", lambda P: .15 < min(p.x for p in P) and max(p.x for p in P) < .45, "SFG_PinsHardware")
hw["lower"] = retain("Guardian_Receiver", lambda P: max(p.z for p in P) < .24 or min(p.z for p in P) > .405,
                     "SFG_ReceiverHardware")
parts = {}
parts["shell"] = build_shell()
parts["faces"] = build_faces()
parts["inlay"] = build_inlay()
parts["mag"] = build_mag()
parts["stock"] = build_stock()
for o in col.objects:
    flat_uv(o)

HARDWARE = ["Guardian_Sights", "Guardian_Barrel", "Guardian_Grip", "Guardian_BoltCatch", "Guardian_CharmLoop",
            "Guardian_Mag", "Guardian_ChargingHandle", "Guardian_Bolt", "Guardian_Trigger", "Guardian_FireSelector"]
STOCK_PARTS = ["Guardian_Neon", "Guardian_Receiver", "Guardian_Handguard", "Guardian_Stock", "Guardian_Pins"]

def set_skin(on):
    for n in HARDWARE:
        o = bpy.data.objects[n]
        for i, sl in enumerate(o.material_slots):
            if i < 8:
                sl.material = SLOT_SKIN[i] if on else bpy.data.materials[STOCK_SET[i]]
    for n in STOCK_PARTS:
        o = bpy.data.objects[n]; o.hide_render = on; o.hide_set(on)
    col.hide_render = not on
    col.hide_viewport = not on

set_skin(True)
result = {"objects": [(o.name, len(o.data.polygons)) for o in col.objects]}
