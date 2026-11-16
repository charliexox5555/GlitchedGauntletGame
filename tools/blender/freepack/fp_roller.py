"""Roller (free pack) prop, built in the LIVE Blender MCP (vault/01 Design/Abilities/Roller.md → Look).

    exec(open(r"<repo>/tools/blender/rework/rw_core.py").read())
    exec(open(r"<repo>/tools/blender/freepack/fp_roller.py").read())
    build_roller()

Owner's picks (2026-11-17 interview): a cheeky bot slung between two big faceted side wheels, a
screen-face eye, a small antenna; charcoal shell with a hot fire glow in the eye and vents, yellow and
black hazard stripes, a small team light on the antenna. Our own design (Boom Bot is the feel, not the
look). Style: gauntlet-build-style (faceted, no round curves, carved ends, every joint seated).

Axes: +X forward, +Y left, +Z up; 1 unit = 1 stud. Placed prop: origin = floor centre. Parts that
keep their fire colour end in "_Fire" (ModProps skips them when team-tinting); "Light_Energy" takes the
team colour. Wheels are named Wheel* (RollerFx spins them about the model's X axle).
"""

FP_R = "Roller"


def build_roller():
    S = rw_scene("FP_Roller")
    rw_clear(FP_R + "_")
    col = rw_col(S, FP_R)
    P = FP_R + "_"
    WR = 0.50      # wheel radius
    WY = 0.66      # wheel centre, sideways
    WZ = WR        # wheel centre height (touches the floor)
    # --- wheels: a 12-facet tyre, a stepped 8-facet hub, a cap, tread notches as raised plates ---
    for side, sy in (("L", 1), ("R", -1)):
        # tyre: an n-gon in XZ swept along Y (build in XY then rotate 90 about X)
        tyre = rw_loft(P + "Wheel" + side + "_Tyre", [
            (-0.15, rw_ngon(WR - 0.05, 12)), (-0.11, rw_ngon(WR, 12)),
            (0.11, rw_ngon(WR, 12)), (0.15, rw_ngon(WR - 0.05, 12))])
        rw_obj(col, P + "Wheel" + side + "_Tyre", tyre, "Grip", loc=(0, sy * WY, WZ), rot=(90, 0, 0))
        hub = rw_loft(P + "Wheel" + side + "_Hub", [
            (-0.17, rw_ngon(0.30, 8)), (0.0, rw_ngon(0.33, 8)), (0.17, rw_ngon(0.30, 8))])
        rw_obj(col, P + "Wheel" + side + "_Hub", hub, "Panel", loc=(0, sy * WY, WZ), rot=(90, 0, 0))
        cap = rw_loft(P + "Wheel" + side + "_Cap", [
            (0.0, rw_ngon(0.16, 6)), (0.06, rw_ngon(0.13, 6)), (0.09, rw_ngon(0.08, 6))])
        rw_obj(col, P + "Wheel" + side + "_Cap", cap, "Metal", loc=(0, sy * (WY + 0.16), WZ), rot=(-90 * sy, 0, 0))
        # tread: 12 raised lugs round the tyre, each a chamfered block seated 0.02 into it
        for i in range(12):
            a = 2 * math.pi * i / 12
            lug = rw_cham_box(P + "Wheel" + side + "_Lug" + str(i), 0.16, 0.24, 0.06, 0.03, 0.02)
            o = rw_obj(col, P + "Wheel" + side + "_Lug" + str(i), lug, "Grip",
                       loc=(math.cos(a) * (WR + 0.01), sy * WY, WZ + math.sin(a) * (WR + 0.01)),
                       rot=(0, -math.degrees(a) + 90, 0))
    # --- axle collars between the body and the hubs ---
    for side, sy in (("L", 1), ("R", -1)):
        collar = rw_loft(P + "Axle" + side, [(-0.09, rw_ngon(0.13, 8)), (0.09, rw_ngon(0.13, 8))])
        rw_obj(col, P + "Axle" + side, collar, "Metal", loc=(0, sy * 0.45, WZ), rot=(90, 0, 0))
    # --- body: a faceted pod between the wheels (stacked chamfered rings, leaning front) ---
    body = rw_loft(P + "Body", [
        (0.18, [(x + 0.02, y) for x, y in rw_cham_rect(0.70, 0.62, 0.16)]),
        (0.34, [(x + 0.03, y) for x, y in rw_cham_rect(0.96, 0.78, 0.22)]),
        (0.86, [(x + 0.05, y) for x, y in rw_cham_rect(1.02, 0.80, 0.24)]),
        (1.12, [(x - 0.02, y) for x, y in rw_cham_rect(0.80, 0.64, 0.20)]),
        (1.20, [(x - 0.04, y) for x, y in rw_cham_rect(0.50, 0.40, 0.12)]),
    ])
    rw_obj(col, P + "Body", body, "Body")
    # --- face: a dark visor plate on the front, seated in the body, with the fire eye ---
    visor = rw_hull(P + "Visor", [
        (0.0, -0.30, 0.48), (0.0, 0.30, 0.48), (0.0, -0.34, 0.62), (0.0, 0.34, 0.62),
        (0.0, -0.28, 0.86), (0.0, 0.28, 0.86),
        (0.10, -0.26, 0.50), (0.10, 0.26, 0.50), (0.10, -0.30, 0.62), (0.10, 0.30, 0.62),
        (0.10, -0.24, 0.82), (0.10, 0.24, 0.82)])
    rw_obj(col, P + "Visor", visor, "Dark", loc=(0.50, 0, 0))
    # two slanted eye slits (a screen face), glowing fire
    for side, sy in (("L", 1), ("R", -1)):
        eye = rw_hull(P + "Eye" + side + "_Fire", [
            (0, sy * 0.06, 0.62), (0, sy * 0.21, 0.66), (0, sy * 0.21, 0.74), (0, sy * 0.06, 0.70),
            (0.03, sy * 0.06, 0.62), (0.03, sy * 0.21, 0.66), (0.03, sy * 0.21, 0.74), (0.03, sy * 0.06, 0.70)])
        rw_obj(col, P + "Eye" + side + "_Fire", eye, "Fire", loc=(0.595, 0, 0))
    # --- chin: a hazard band under the visor (yellow, two black bars), seated on the front ---
    chin = rw_hull(P + "Chin", [
        (0, -0.26, 0.30), (0, 0.26, 0.30), (0, -0.28, 0.40), (0, 0.28, 0.40),
        (0.05, -0.24, 0.31), (0.05, 0.24, 0.31), (0.05, -0.26, 0.39), (0.05, 0.26, 0.39)])
    rw_obj(col, P + "Chin", chin, "Hazard", loc=(0.505, 0, 0))
    for k in range(2):
        cb = rw_hull(P + "ChinBar" + str(k), [
            (0, -0.03, 0.31), (0, 0.04, 0.31), (0, 0.09, 0.39), (0, 0.02, 0.39),
            (0.015, -0.03, 0.31), (0.015, 0.04, 0.31), (0.015, 0.09, 0.39), (0.015, 0.02, 0.39)])
        rw_obj(col, P + "ChinBar" + str(k), cb, "Dark", loc=(0.553, -0.12 + k * 0.18, 0))
    # --- top: a raised spine plate and two fire vents either side of it ---
    spine = rw_cham_box(P + "Spine", 0.52, 0.16, 0.08, 0.04, 0.03)
    rw_obj(col, P + "Spine", spine, "Panel", loc=(-0.04, 0, 1.21))
    for side, sy in (("L", 1), ("R", -1)):
        housing = rw_cham_box(P + "Vent" + side, 0.36, 0.14, 0.06, 0.03, 0.02)
        rw_obj(col, P + "Vent" + side, housing, "Dark", loc=(-0.06, sy * 0.19, 1.135), rot=(sy * -14, 0, 0))
        for k in range(3):
            slat = rw_cham_box(P + "Vent" + side + str(k) + "_Fire", 0.07, 0.10, 0.03, 0.012, 0.01)
            rw_obj(col, P + "Vent" + side + str(k) + "_Fire", slat, "Fire",
                   loc=(-0.17 + k * 0.11, sy * 0.19, 1.158), rot=(sy * -14, 0, 0))
    # --- back: a hazard panel (yellow, three black bars) seated on the rear face ---
    hz = rw_hull(P + "Hazard", [
        (0, -0.30, 0.42), (0, 0.30, 0.42), (0, -0.33, 0.56), (0, 0.33, 0.56), (0, -0.30, 0.82), (0, 0.30, 0.82),
        (-0.05, -0.28, 0.44), (-0.05, 0.28, 0.44), (-0.05, -0.31, 0.56), (-0.05, 0.31, 0.56),
        (-0.05, -0.28, 0.80), (-0.05, 0.28, 0.80)])
    rw_obj(col, P + "Hazard", hz, "Hazard", loc=(-0.455, 0, 0))
    for k in range(3):
        bar = rw_hull(P + "HazardBar" + str(k), [
            (0, -0.04, 0.0), (0, 0.06, 0.0), (0, 0.16, 0.34), (0, 0.06, 0.34),
            (-0.02, -0.04, 0.0), (-0.02, 0.06, 0.0), (-0.02, 0.16, 0.34), (-0.02, 0.06, 0.34)])
        rw_obj(col, P + "HazardBar" + str(k), bar, "Dark", loc=(-0.50, -0.26 + k * 0.19, 0.455))
    # --- antenna: a hex rod through a gland, the team light on top ---
    gland = rw_loft(P + "Gland", [(0.0, rw_ngon(0.06, 6)), (0.05, rw_ngon(0.05, 6))])
    rw_obj(col, P + "Gland", gland, "Metal", loc=(-0.22, 0, 1.245))
    rod = rw_loft(P + "Antenna", [(0.0, rw_ngon(0.018, 6)), (0.42, rw_ngon(0.014, 6))])
    rw_obj(col, P + "Antenna", rod, "Accent", loc=(-0.22, 0, 1.285), rot=(0, -12, 0))
    tip = rw_loft(P + "Light_Energy", [(0.0, rw_ngon(0.03, 6)), (0.04, rw_ngon(0.045, 6)), (0.08, rw_ngon(0.025, 6))])
    rw_obj(col, P + "Light_Energy", tip, "Energy", loc=(-0.307, 0, 1.69))
    # --- locators ---
    rw_empty(col, P + "Center", (0, 0, 0.6))
    rw_empty(col, P + "Top", (0, 0, 1.25))
    return {"objects": len([o for o in col.objects])}
