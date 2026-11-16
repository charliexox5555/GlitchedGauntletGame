"""Flash (free pack) prop, built in the LIVE Blender MCP (vault/01 Design/Abilities/Flash.md → Look).

    exec(open(r"<repo>/tools/blender/rework/rw_core.py").read())
    exec(open(r"<repo>/tools/blender/freepack/fp_flash.py").read())
    build_flash()

Owner's pick (2026-11-17 interview): a faceted flare canister, a big gold-glowing lens cap on top, a
pin lever and a grip band. Our design. Style: gauntlet-build-style (8-facet prisms, chamfered steps,
no round curves, carved ends). Thrown prop: origin = centre. The lens keeps its gold ("_Fire" suffix,
ModProps skips it); the thin band light takes the team colour ("_Energy").
"""

FP_F = "Flash"


def build_flash():
    S = rw_scene("FP_Flash")
    rw_clear(FP_F + "_")
    col = rw_col(S, FP_F)
    P = FP_F + "_"
    N = 8
    # foot: a chamfered octagon base step
    foot = rw_loft(P + "Foot", [(-0.30, rw_ngon(0.11, N)), (-0.28, rw_ngon(0.135, N)), (-0.24, rw_ngon(0.135, N)), (-0.22, rw_ngon(0.125, N))])
    rw_obj(col, P + "Foot", foot, "Panel")
    # body: an octagonal shell, slightly waisted (two flat facet bands)
    body = rw_loft(P + "Body", [(-0.225, rw_ngon(0.12, N)), (-0.05, rw_ngon(0.112, N)), (0.10, rw_ngon(0.112, N)), (0.17, rw_ngon(0.12, N))])
    rw_obj(col, P + "Body", body, "Body")
    # grip band: a raised 8-facet ring with grooves (three thin rings)
    for k, z in enumerate((-0.17, -0.11, -0.05)):
        ring = rw_loft(P + "Grip" + str(k), [(z, rw_ngon(0.118, N)), (z + 0.01, rw_ngon(0.13, N)), (z + 0.035, rw_ngon(0.13, N)), (z + 0.045, rw_ngon(0.118, N))])
        rw_obj(col, P + "Grip" + str(k), ring, "Grip")
    # team light: a thin band near the top of the body
    band = rw_loft(P + "Band_Energy", [(0.03, rw_ngon(0.113, N)), (0.04, rw_ngon(0.118, N)), (0.055, rw_ngon(0.118, N)), (0.065, rw_ngon(0.113, N))])
    rw_obj(col, P + "Band_Energy", band, "Energy")
    # collar: a metal step that seats the lens housing
    collar = rw_loft(P + "Collar", [(0.16, rw_ngon(0.125, N)), (0.175, rw_ngon(0.145, N)), (0.215, rw_ngon(0.145, N)), (0.225, rw_ngon(0.13, N))])
    rw_obj(col, P + "Collar", collar, "Metal")
    # lens housing: a dark crown with four guard teeth
    crown = rw_loft(P + "Crown", [(0.22, rw_ngon(0.13, N)), (0.26, rw_ngon(0.14, N)), (0.27, rw_ngon(0.125, N))])
    rw_obj(col, P + "Crown", crown, "Dark")
    for k in range(4):
        a = math.pi / 8 + k * math.pi / 2
        tooth = rw_hull(P + "Tooth" + str(k), [
            (0.10, -0.03, 0.0), (0.10, 0.03, 0.0), (0.145, -0.03, 0.0), (0.145, 0.03, 0.0),
            (0.115, -0.022, 0.10), (0.115, 0.022, 0.10), (0.14, -0.022, 0.085), (0.14, 0.022, 0.085)])
        rw_obj(col, P + "Tooth" + str(k), tooth, "Metal", loc=(0, 0, 0.255), rot=(0, 0, math.degrees(a)))
    # the lens: a stepped, faceted gold dome (3 rings, flat top facet), glowing
    lens = rw_loft(P + "Lens_Fire", [(0.262, rw_ngon(0.105, N)), (0.30, rw_ngon(0.098, N)), (0.33, rw_ngon(0.072, N)), (0.345, rw_ngon(0.035, N))])
    rw_obj(col, P + "Lens_Fire", lens, "Gold")
    # spoon lever: an angled plate down the side, hooked over the collar, carved end
    spoon = rw_hull(P + "Spoon", [
        (0.123, -0.03, -0.16), (0.123, 0.03, -0.16), (0.135, -0.035, 0.15), (0.135, 0.035, 0.15),
        (0.143, -0.03, -0.14), (0.143, 0.03, -0.14), (0.155, -0.035, 0.15), (0.155, 0.035, 0.15)])
    rw_obj(col, P + "Spoon", spoon, "Metal")
    hook = rw_hull(P + "SpoonHook", [
        (0.10, -0.035, 0.205), (0.10, 0.035, 0.205), (0.155, -0.035, 0.15), (0.155, 0.035, 0.15),
        (0.10, -0.035, 0.225), (0.10, 0.035, 0.225), (0.165, -0.035, 0.17), (0.165, 0.035, 0.17)])
    rw_obj(col, P + "SpoonHook", hook, "Metal")
    # pin: a square ring on edge through a lug on the collar (the free hand pulls it)
    lug = rw_cham_box(P + "PinLug", 0.04, 0.05, 0.04, 0.01)
    rw_obj(col, P + "PinLug", lug, "Metal", loc=(0.0, 0.15, 0.195))
    ring = rw_loft(P + "PinRing", [(-0.008, rw_ngon(0.045, 6)), (0.008, rw_ngon(0.045, 6))])
    rw_obj(col, P + "PinRing", ring, "Accent", loc=(0.0, 0.205, 0.195), rot=(0, 90, 0))
    hole = rw_loft(P + "PinRingHole", [(-0.02, rw_ngon(0.028, 6)), (0.02, rw_ngon(0.028, 6))])
    hole_o = rw_obj(col, P + "PinRingHole", hole, "Dark", loc=(0.0, 0.205, 0.195), rot=(0, 90, 0))
    rw_bool(bpy.data.objects[P + "PinRing"], hole_o)
    # locators
    rw_empty(col, P + "Fuse", (0, 0, 0.35))
    rw_empty(col, P + "Center", (0, 0, 0))
    return {"objects": len(col.objects)}
