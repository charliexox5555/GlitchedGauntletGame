"""Smoke (battle pass power, free tier 10) canister, built in a LIVE Blender MCP bridge (vault/02 Art/Mod Props - Smoke and
Electric Shock.md). Thrown prop: origin = centre; held in the right hand like the Frost / Flash canisters.

    python tools/blender/lobby_v4/send.py tools/blender/build_mod_smoke.py --port <port> --pid <pid>

Runs on rw_core (tools/blender/rework/rw_core.py) with its work folder pointed at art-source/abilities, so the export lands
in art-source/abilities/Exports/Smoke.{fbx,json} and the source in art-source/abilities/Smoke/Smoke_<VERSION>.blend
(+ Smoke.blend, the latest). Set VERSION in the exec globals for a new version; never overwrite one.

Look (gauntlet-build-style): a squat 8-facet smoke canister, matte charcoal with a pale-grey label band (reads as smoke,
not fire), two rubber grip rings, a chamfered shoulder up to a steel cap with four vent slots over a dark vent plate, a
fuse collar and striker on top, a spoon lever down the +X side and a pull pin + ring on the +Y side.
Parts: Foot, Body, Label, Grip0, Grip1, Band_Energy (team light), VentPlate, Cap, Fuse, Striker, Lever, PinLug, Pin
(flies off on the throw). Locators: Handle (centre; the builder adds RightGrip = Handle), Vent (top of the cap, where the
smoke pours out, facing +Z).
"""
import os

exec(open(os.path.join(r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame", "tools", "blender", "rework", "rw_core.py")).read())
RW_WORK = os.path.join(RW_REPO, "art-source", "abilities")
VERSION = globals().get("VERSION", "v01")
MOD = "Smoke"
OUT = os.path.join(RW_REPO, "vault", "02 Art", "References", "mods")
N = 8


def _join(name, meshes, role):
    """One object from several closed meshes (same material), unioned so the joins are real merged corners."""
    S = bpy.context.window.scene
    col = bpy.data.collections[MOD]
    base = rw_obj(col, name, meshes[0], role)
    for i, me in enumerate(meshes[1:]):
        o = rw_obj(col, name + "_tmp%d" % i, me, role)
        rw_bool(base, o, op="UNION")
    return base


def build():
    S = rw_scene("FP_" + MOD)
    rw_clear(MOD + "_")
    col = rw_col(S, MOD)
    P = MOD + "_"
    # foot: chamfered octagon base step (carved end, not a flat cut)
    rw_obj(col, P + "Foot", rw_loft(P + "Foot", [(-0.300, rw_ngon(0.122, N)), (-0.285, rw_ngon(0.150, N)), (-0.255, rw_ngon(0.150, N)), (-0.240, rw_ngon(0.140, N))]), "Metal")
    # body: the 8-facet can, a chamfered shoulder up to the vent plate seat
    rw_obj(col, P + "Body", rw_loft(P + "Body", [(-0.250, rw_ngon(0.146, N)), (0.170, rw_ngon(0.146, N)), (0.205, rw_ngon(0.124, N)), (0.214, rw_ngon(0.116, N))]), "Body")
    # label: a pale-grey painted band (smoke, not fire), raised 0.008 with chamfered edges
    rw_obj(col, P + "Label", rw_loft(P + "Label", [(-0.065, rw_ngon(0.148, N)), (-0.058, rw_ngon(0.156, N)), (0.055, rw_ngon(0.156, N)), (0.062, rw_ngon(0.148, N))]), "Pale")
    # rubber grip rings on the lower can
    for k, z in enumerate((-0.205, -0.140)):
        rw_obj(col, P + "Grip%d" % k, rw_loft(P + "Grip%d" % k, [(z, rw_ngon(0.148, N)), (z + 0.008, rw_ngon(0.158, N)), (z + 0.030, rw_ngon(0.158, N)), (z + 0.038, rw_ngon(0.148, N))]), "Grip")
    # team light: a thin band under the shoulder
    rw_obj(col, P + "Band_Energy", rw_loft(P + "Band_Energy", [(0.098, rw_ngon(0.148, N)), (0.104, rw_ngon(0.155, N)), (0.126, rw_ngon(0.155, N)), (0.132, rw_ngon(0.148, N))]), "Energy")
    # vent plate: the dark floor the vent slots show
    rw_obj(col, P + "VentPlate", rw_loft(P + "VentPlate", [(0.200, rw_ngon(0.110, N)), (0.238, rw_ngon(0.110, N))]), "Dark")
    # cap: a steel cap with a chamfered top edge; four vent slots cut through it (to the dark plate)
    cap = rw_obj(col, P + "Cap", rw_loft(P + "Cap", [(0.233, rw_ngon(0.128, N)), (0.252, rw_ngon(0.128, N)), (0.264, rw_ngon(0.114, N))]), "Metal")
    for k in range(4):
        a = 45 * k + 22.5
        cut = rw_obj(col, P + "SlotCut%d" % k, rw_cham_box(P + "SlotCut%d" % k, 0.060, 0.016, 0.080, 0.004), None,
                     loc=(0.078 * math.cos(math.radians(a)), 0.078 * math.sin(math.radians(a)), 0.262), rot=(0, 0, a))
        rw_bool(cap, cut)
    # fuse collar and striker head (chamfered top: no blunt end)
    rw_obj(col, P + "Fuse", rw_loft(P + "Fuse", [(0.258, rw_ngon(0.046, N)), (0.268, rw_ngon(0.050, N)), (0.286, rw_ngon(0.050, N)), (0.290, rw_ngon(0.044, N))]), "Metal")
    rw_obj(col, P + "Striker", rw_loft(P + "Striker", [(0.286, rw_ngon(0.034, N)), (0.296, rw_ngon(0.034, N)), (0.302, rw_ngon(0.024, N))]), "Dark")
    # spoon lever: a strap seated on the +X facet (apothem 0.135), over the label and band, hooked over the shoulder
    # into the fuse collar; carved (angled) foot
    strap = rw_hull(P + "LeverA", [(x, y, z) for x in (0.130, 0.149) for y in (-0.024, 0.024) for z in (-0.080, 0.172)] +
                    [(0.130, -0.024, -0.112), (0.130, 0.024, -0.112), (0.149, -0.020, -0.096), (0.149, 0.020, -0.096),
                     (0.138, -0.014, -0.122), (0.138, 0.014, -0.122)])  # carved, angled foot tucked into the grip ring
    hook = rw_hull(P + "LeverB", [(0.130, -0.024, 0.160), (0.130, 0.024, 0.160), (0.149, -0.024, 0.172), (0.149, 0.024, 0.172),
                                  (0.028, -0.022, 0.270), (0.028, 0.022, 0.270), (0.031, -0.022, 0.287), (0.031, 0.022, 0.287),
                                  (0.118, -0.024, 0.214), (0.118, 0.024, 0.214), (0.132, -0.024, 0.226), (0.132, 0.024, 0.226)])
    _join(P + "Lever", [strap, hook], "Metal")
    # pin lug on the +Y side of the fuse collar, the pull pin through it and the pull ring
    rw_obj(col, P + "PinLug", rw_cham_box(P + "PinLug", 0.030, 0.034, 0.026, 0.006), "Metal", loc=(0.0, 0.056, 0.278))
    rod = rw_loft(P + "PinRod", [(-0.030, rw_ngon(0.0055, 6)), (0.030, rw_ngon(0.0055, 6))])
    pin = rw_obj(col, P + "Pin", rod, "Accent", loc=(0.0, 0.075, 0.278), rot=(90, 0, 0))
    ring = rw_obj(col, P + "PinRing", rw_loft(P + "PinRing", [(-0.0045, rw_ngon(0.032, 8)), (0.0045, rw_ngon(0.032, 8))]), "Accent",
                  loc=(0.0, 0.125, 0.300), rot=(0, 90, 0))
    hole = rw_obj(col, P + "PinHole", rw_loft(P + "PinHole", [(-0.02, rw_ngon(0.020, 8)), (0.02, rw_ngon(0.020, 8))]), None,
                  loc=(0.0, 0.125, 0.300), rot=(0, 90, 0))
    rw_bool(ring, hole)
    rw_bool(pin, ring, op="UNION")  # pin + ring are one part (it flies off as one)
    # locators
    rw_empty(col, P + "Handle", (0, 0, 0))
    rw_empty(col, P + "Vent", (0, 0, 0.264))
    return S


SEATS = [("Foot", "Body"), ("Label", "Body"), ("Grip", "Body"), ("Band", "Body"), ("VentPlate", "Body"), ("VentPlate", "Cap"),
         ("Cap", "Fuse"), ("Fuse", "Striker"), ("Lever", "Body"), ("Lever", "Label"), ("Lever", "Band"), ("Lever", "Fuse"),
         ("Lever", "Cap"), ("Lever", "Grip"), ("Lever", "VentPlate"), ("Lever", "Striker"), ("PinLug", "Fuse"), ("Pin", "PinLug"), ("Pin", "Fuse")]

S = build()
audit = rw_audit(MOD + "_", seats=SEATS)
shots = {}
for view, zoom, tgt in (("hero", 1.0, None), ("back", 1.0, None), ("hand", 1.0, None), ("top", 1.0, None),
                        ("side", 1.0, None), ("left", 1.0, None),
                        ((0.7, 0.9, 0.5), 2.6, (0.0, 0.07, 0.27)),  # pin, lug, fuse
                        ((1.0, -0.4, 0.8), 2.4, (0.08, 0.0, 0.24)),  # lever hook, cap slots
                        ((1.0, 0.3, -0.5), 2.2, (0.12, 0.0, -0.15)),  # lever foot, grips, foot
                        ((-0.6, -0.8, -0.7), 2.0, (0.0, 0.0, -0.26))):  # base from below
    name = view if isinstance(view, str) else "close%d" % len(shots)
    shots[name] = rw_render(S, MOD + "_", os.path.join(OUT, "smoke_%s_%s.jpg" % (VERSION, name)), view=view, zoom=zoom, target=tgt,
                            res=(1000, 1000) if not isinstance(view, str) else (1200, 1000))
src = rw_write_source(MOD, os.path.join(RW_WORK, MOD, "%s_%s.blend" % (MOD, VERSION)))
result = {"pid": os.getpid(), "audit": audit, "renders": shots, "source": src, "bounds": [list(v) for v in rw_bounds(MOD + "_")]}
