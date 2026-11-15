"""Slipframe Classic (pistol). Exec after model_slipframe_kit.py (stock Classic
open). Blue cap plates ride the Slide bone (travel -.13 in x); the frame goes
charcoal; a short silver-blue inlay runs on the cap and stops at a grey break.
Slide catch (+Y, frame, z < .262), magazine release, sights and the
ejection port (slide top) are untouched."""

def build_slide_caps():
    out = [(-.255, .462), (.955, .462), (.985, .44), (.985, .318), (.965, .300), (-.235, .300), (-.258, .33)]
    o = face_plate("SFC_SlideCap", out, .066, .079, fold=((-.26, .385), (.99, .385), .003, .09), bone="Slide")
    # cut the inlay into the cap (+Y half cut before mirroring is not possible
    # here since face_plate already mirrored: cut both sides explicitly)
    strip = [(.06, .356), (.40, .356), (.42, .362), (.40, .368), (.06, .368), (.05, .362)]
    cut(o, [prism(strip, .0715, .4, floor=INSET_IDX, side=GASKET), prism(strip, -.0715, -.4, floor=INSET_IDX, side=GASKET)],
        rim=.0015)
    br = [(.42, .375), (.50, .375), (.52, .362), (.50, .349), (.42, .349)]
    b = link("SFC_SlideBreak", solid_plate(br, .074, .083, ch=.003, mat=ARM), "Slide")
    mirror_apply(b)
    # titanium top rails either side of the sight line (below the notch, z < .49)
    def rail(k=1.0):
        return [(.046 * k, .474), (.062 * k, .478), (.062 * k, .486), (.050 * k, .488)]
    st = [(-.13, [(y, z) for y, z in rail()]), (.89, [(y, z) for y, z in rail()])]
    rails = []
    for sgn in (1, -1):
        stx = [(x, [(y * sgn, z) for y, z in pts] + [(y * sgn * .55, z) for y, z in reversed(pts)]) for x, pts in st]
        bm = loft(stx, [EDGE, EDGE, ARM, ARM, ARM, ARM, ARM, ARM], cap_mat=EDGE)
        rails.append(bm)
    r = join("SFC_SlideRails", rails, bone="Slide")
    return o, b, r

def build_grip_panels():
    rows = [(-.193, .199, .225, .009), (-.212, .092, .201, -.095), (-.197, .027, .187, -.147),
            (-.208, -.025, .178, -.201), (-.222, -.077, .167, -.253)]
    bk = [lerp2((bx, bz), (fx, fz), .10) for bx, bz, fx, fz in rows]
    fw = [lerp2((bx, bz), (fx, fz), .82) for bx, bz, fx, fz in rows]
    out = bk + list(reversed(fw))
    o = link("SFC_GripPanel", solid_plate(out, .060, .0715, ch=.004, mat=CORE, fold=((-.20, .1), (-.22, -.25), .003, .08)))
    # the line's one short inlay lives on the slide cap; the grip panel stays plain
    mirror_apply(o)
    return o

# review aim point (the stock Classic has no AimPoint empty): rear-notch height
if "MFR_Classic_Aim" not in bpy.data.objects:
    _e = bpy.data.objects.new("MFR_Classic_Aim", None); sc.collection.objects.link(_e); _e.location = (0.0, 0, .512)

parts = {}
parts["slide"] = build_slide_caps()
parts["grip"] = build_grip_panels()
for o in col.objects:
    flat_uv(o)

HARDWARE = ["Classic_Slide", "Classic_SlideNeon", "Classic_Barrel", "Classic_Frame", "Classic_Grip", "Classic_Pins",
            "Classic_CharmLoop", "Classic_Magazine", "Classic_MagNeon", "Classic_Trigger", "Classic_SlideCatch", "Classic_MagRelease"]
STOCK_PARTS = []
FRAME_SKIN = [MATS[2], MATS[2], MATS[2], MATS[6], MATS[5], MATS[4], EXTRA["Neon"], EXTRA["Brass"]]   # charcoal frame

def set_skin(on):
    for n in HARDWARE:
        o = bpy.data.objects[n]
        table = FRAME_SKIN if n in ("Classic_Frame", "Classic_Grip", "Classic_Magazine") else SLOT_SKIN
        for i, sl in enumerate(o.material_slots):
            if i < 8:
                sl.material = table[i] if on else bpy.data.materials[STOCK_SET[i]]
    col.hide_render = not on
    col.hide_viewport = not on

set_skin(True)
result = {"objects": [(o.name, len(o.data.polygons)) for o in col.objects]}
