"""Slipframe Spectre. Exec after model_slipframe_kit.py (stock Spectre open).
Compact blue shell over the charcoal inner frame: the stock receiver, stock
skeletal stock and suppressor are kept and re-finished; blue faces go only
where no moving part travels (charging ring +Y x .44-.70 z .32-.40, bolt -Y
x .145-.468 z .364-.423). A short silver-blue seam runs below the sight line
on the handguard and stops at a grey break."""

def build():
    hg = face_plate("SFS_HandguardFace", [(.712, .462), (1.13, .462), (1.142, .44), (1.142, .30), (1.12, .282), (.74, .282), (.712, .31)],
                    .088, .099, vents=raked_vents(.98, 3, .045, .30, .44, w=.020, lean=.022), vent_floor=.091,
                    fold=((.71, .37), (1.15, .37), .003, .10))
    band = [(.70, .282), (1.135, .282), (1.142, .268), (1.12, .244), (.72, .244), (.70, .26)]
    strip = [(.76, .257), (1.08, .257), (1.10, .263), (1.08, .269), (.76, .269), (.75, .263)]
    ib = inlay_band("SFS_InsetBand", band, .086, .096, strip, .0895)
    brk = [(.62, .296), (.70, .296), (.712, .265), (.70, .236), (.63, .236), (.62, .26)]
    b = link("SFS_GreyBreak", solid_plate(brk, .080, .097, ch=.005, mat=ARM, fold=((.62, .265), (.712, .265), .003, .04)))
    mirror_apply(b)
    rear = face_plate("SFS_ReceiverFace", [(-.322, .432), (.10, .432), (.118, .41), (.118, .30), (.10, .285), (-.30, .285), (-.322, .31)],
                      .080, .092, fold=((-.33, .36), (.12, .36), .003, .08))
    mw = face_plate("SFS_MagwellFace", [(.452, .262), (.684, .262), (.684, .085), (.66, .052), (.50, .052), (.452, .10)],
                    .078, .089, mat=CORE)
    mag = link("SFS_MagFace", solid_plate([(.48, .02), (.65, .02), (.78, -.40), (.775, -.46), (.63, -.46), (.60, -.40)],
                                          .052, .0705, ch=.003, mat=ACCENT), "Mag")
    strip = [(.565, -.01), (.585, -.01), (.70, -.39), (.68, -.39)]
    cut(mag, [prism(strip, .0645, .4, floor=INSET_IDX, side=GASKET)], rim=.0015)
    mirror_apply(mag)
    butt = face_plate("SFS_ButtFace", [(-.97, .37), (-1.04, .37), (-1.058, .33), (-1.058, -.07), (-1.04, -.10), (-.97, -.10)],
                      .072, .082)
    return hg, ib, b, rear, mw, mag, butt

parts = {"all": build()}
for o in col.objects:
    flat_uv(o)

HARDWARE = ["Spectre_Receiver", "Spectre_Handguard", "Spectre_Suppressor", "Spectre_Sights", "Spectre_Grip", "Spectre_Stock",
            "Spectre_Pins", "Spectre_CharmLoop", "Spectre_Mag", "Spectre_ChargingHandle", "Spectre_Bolt", "Spectre_Trigger",
            "Spectre_FireSelector", "Spectre_Neon"]
STOCK_PARTS = []
DARK_SKIN = [MATS[2], MATS[2], MATS[2], MATS[6], MATS[5], MATS[4], EXTRA["Neon"], EXTRA["Brass"]]

def set_skin(on):
    for n in HARDWARE:
        o = bpy.data.objects[n]
        table = DARK_SKIN if n in ("Spectre_Grip", "Spectre_Mag") else SLOT_SKIN
        for i, sl in enumerate(o.material_slots):
            if i < 8:
                sl.material = table[i] if on else bpy.data.materials[STOCK_SET[i]]
    col.hide_render = not on
    col.hide_viewport = not on

set_skin(True)
result = {"objects": [(o.name, len(o.data.polygons)) for o in col.objects]}
