"""Slipframe Vandal. Exec after model_slipframe_kit.py (stock Vandal open).
Broad blue face across the upper receiver (above the channel) and the
handguard, charcoal lower frame, the recessed inlay along the lower receiver
ending at a grey break ahead of the grip. The stock receiver, curved
magazine and triangle stock keep their profile (re-finished). Channel:
charging handle +Y x .24-.80 z .28-.34, bolt -Y x .12-.62 z .278-.35."""

def build():
    up = face_plate("SFV_UpperFace", [(-.17, .425), (1.05, .425), (1.06, .41), (1.05, .352), (-.15, .352), (-.17, .37)],
                    .092, .102, fold=((-.17, .388), (1.06, .388), .002, .06))
    hg = face_plate("SFV_HandguardFace", [(1.065, .405), (1.64, .405), (1.68, .37), (1.67, .20), (1.63, .18), (1.09, .18), (1.065, .22)],
                    .096, .106, vents=raked_vents(1.40, 4, .055, .215, .36, w=.022, lean=.028), vent_floor=.099,
                    fold=((1.06, .29), (1.68, .29), .004, .12))
    band = [(.30, .205), (1.04, .205), (1.055, .19), (1.03, .165), (.33, .165), (.30, .185)]
    strip = [(.36, .179), (.99, .179), (1.012, .185), (.99, .191), (.36, .191), (.35, .185)]
    ib = inlay_band("SFV_InsetBand", band, .090, .101, strip, .0945)
    brk = [(.20, .222), (.30, .222), (.315, .185), (.30, .150), (.21, .150), (.20, .185)]
    b = link("SFV_GreyBreak", solid_plate(brk, .086, .104, ch=.005, mat=ARM, fold=((.20, .185), (.315, .185), .003, .05)))
    mirror_apply(b)
    mag = link("SFV_MagFace", solid_plate([(.505, .03), (.700, .06), (.835, -.17), (.90, -.31), (.84, -.35), (.69, -.33), (.60, -.20)],
                                          .058, .0685, ch=.003, mat=ACCENT), "Mag")
    strip = [(.66, .02), (.68, .03), (.85, -.29), (.83, -.30)]
    cut(mag, [prism(strip, .0615, .4, floor=INSET_IDX, side=GASKET)], rim=.0015)
    mirror_apply(mag)
    butt = face_plate("SFV_ButtFace", [(-1.115, .38), (-1.22, .38), (-1.24, .34), (-1.24, -.12), (-1.22, -.15), (-1.115, -.15)],
                      .078, .088)
    return up, hg, ib, b, mag, butt

parts = {"all": build()}
for o in col.objects:
    flat_uv(o)

HARDWARE = ["Vandal_Neon", "Vandal_Receiver", "Vandal_Handguard", "Vandal_Rail", "Vandal_RearSight", "Vandal_FrontSight",
            "Vandal_Barrel", "Vandal_Grip", "Vandal_Stock", "Vandal_Pins", "Vandal_CharmLoop", "Vandal_Mag",
            "Vandal_ChargingHandle", "Vandal_Bolt", "Vandal_Trigger", "Vandal_FireSelector"]
STOCK_PARTS = []
DARK_SKIN = [MATS[2], MATS[2], MATS[2], MATS[6], MATS[5], MATS[4], EXTRA["Neon"], EXTRA["Brass"]]

def set_skin(on):
    for n in HARDWARE:
        o = bpy.data.objects[n]
        table = DARK_SKIN if n in ("Vandal_Grip", "Vandal_Mag", "Vandal_Rail") else SLOT_SKIN
        for i, sl in enumerate(o.material_slots):
            if i < 8:
                sl.material = table[i] if on else bpy.data.materials[STOCK_SET[i]]
    col.hide_render = not on
    col.hide_viewport = not on

set_skin(True)
result = {"objects": [(o.name, len(o.data.polygons)) for o in col.objects]}
