"""Electric Shock (battle pass power, premium tier 20) lock-on orb, built in a LIVE Blender MCP bridge (vault/02 Art/Mod
Props - Smoke and Electric Shock.md). Thrown prop: origin = centre; held in the right hand.

    python tools/blender/lobby_v4/send.py tools/blender/build_mod_electricshock.py --port <port> --pid <pid>

rw_core with its work folder pointed at art-source/abilities: export -> art-source/abilities/Exports/ElectricShock.{fbx,json},
source -> art-source/abilities/ElectricShock/ElectricShock_<VERSION>.blend. Set VERSION in the exec globals.

Look (gauntlet-build-style): a caged core. Two chamfered octagon caps (steel) joined by six bowed ribs, unioned into one
Cage; a dark Belt round the equator ties the ribs; a faceted Core_Energy crystal inside (team light, tinted per viewer);
three steel Prongs under the bottom cap (it latches onto a player). Parts: Cage, Belt, Core_Energy, Prongs, Node.
Locators: Handle (centre; the builder adds RightGrip = Handle) and Zap (the core centre: the strike's arcs start here).
"""
import os

exec(open(os.path.join(r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame", "tools", "blender", "rework", "rw_core.py")).read())
RW_WORK = os.path.join(RW_REPO, "art-source", "abilities")
VERSION = globals().get("VERSION", "v01")
MOD = "ElectricShock"
OUT = os.path.join(RW_REPO, "vault", "02 Art", "References", "mods")
N = 8
RIBS = 6


def _section(r, z, ang, w, t):
    """Four corners of a rib cross-section at radius r (outer face), height z, angle ang: w wide, t thick."""
    c, s = math.cos(ang), math.sin(ang)
    tx, ty = -s, c  # tangent
    pts = []
    for rr in (r - t, r):
        for k in (-w / 2, w / 2):
            pts.append((rr * c + tx * k, rr * s + ty * k, z))
    return pts


def build():
    S = rw_scene("FP_" + MOD)
    rw_clear(MOD + "_")
    col = rw_col(S, MOD)
    P = MOD + "_"
    # caps: chamfered octagon blocks top and bottom
    top = rw_obj(col, P + "Cage", rw_loft(P + "Cage", [(0.100, rw_ngon(0.086, N)), (0.118, rw_ngon(0.104, N)), (0.146, rw_ngon(0.104, N)), (0.164, rw_ngon(0.074, N))]), "Metal")
    bot = rw_obj(col, P + "CapB", rw_loft(P + "CapB", [(-0.164, rw_ngon(0.074, N)), (-0.146, rw_ngon(0.104, N)), (-0.118, rw_ngon(0.104, N)), (-0.100, rw_ngon(0.086, N))]), "Metal")
    rw_bool(top, bot, op="UNION")
    # six bowed ribs, each three straight segments (a faceted bow), seated into both caps
    path = [(0.086, 0.138), (0.160, 0.066), (0.160, -0.066), (0.086, -0.138)]
    for i in range(RIBS):
        ang = 2 * math.pi * i / RIBS
        for j in range(3):
            (r0, z0), (r1, z1) = path[j], path[j + 1]
            seg = rw_obj(col, P + "Rib%d_%d" % (i, j), rw_hull(P + "Rib%d_%d" % (i, j), _section(r0, z0, ang, 0.032, 0.024) + _section(r1, z1, ang, 0.032, 0.024)), "Metal")
            rw_bool(top, seg, op="UNION")
    # belt: a dark ring under the equator that ties the ribs (an annulus below the core's widest facets, so the core shows)
    belt = rw_obj(col, P + "Belt", rw_loft(P + "Belt", [(-0.072, rw_ngon(0.150, RIBS * 2)), (-0.064, rw_ngon(0.158, RIBS * 2)), (-0.046, rw_ngon(0.158, RIBS * 2)), (-0.038, rw_ngon(0.150, RIBS * 2))]), "Dark")
    hole = rw_obj(col, P + "BeltHole", rw_loft(P + "BeltHole", [(-0.10, rw_ngon(0.122, RIBS * 2)), (0.0, rw_ngon(0.122, RIBS * 2))]), None)
    rw_bool(belt, hole)
    # core: a faceted crystal (team light), its tips seated in the caps
    pts = [(0.0, 0.0, 0.118), (0.0, 0.0, -0.118)]
    for k in range(6):
        a = 2 * math.pi * k / 6
        pts.append((0.072 * math.cos(a), 0.072 * math.sin(a), 0.036))
        b = a + math.pi / 6
        pts.append((0.072 * math.cos(b), 0.072 * math.sin(b), -0.036))
    rw_obj(col, P + "Core_Energy", rw_hull(P + "Core_Energy", pts), "Energy")
    # node: a small stepped emitter on the top cap
    rw_obj(col, P + "Node", rw_loft(P + "Node", [(0.158, rw_ngon(0.040, N)), (0.176, rw_ngon(0.040, N)), (0.184, rw_ngon(0.028, N))]), "Dark")
    # prongs: three tapered claws under the bottom cap, between the ribs, angled down and out (it latches on)
    prong_meshes = []
    for k in range(3):
        a = 2 * math.pi * k / 3 + math.pi / RIBS
        c, s = math.cos(a), math.sin(a)
        tx, ty = -s, c

        def P3(r, z, w):
            return [(r * c + tx * w, r * s + ty * w, z), (r * c - tx * w, r * s - ty * w, z)]
        base = P3(0.050, -0.150, 0.016) + P3(0.084, -0.150, 0.016) + P3(0.050, -0.122, 0.016) + P3(0.084, -0.126, 0.016)
        knee = P3(0.118, -0.170, 0.012) + P3(0.126, -0.160, 0.012)
        tip = P3(0.150, -0.206, 0.005) + P3(0.154, -0.200, 0.005)
        a_ = rw_obj(col, P + "ProngA%d" % k, rw_hull(P + "ProngA%d" % k, base + knee), "Accent")
        b_ = rw_obj(col, P + "ProngB%d" % k, rw_hull(P + "ProngB%d" % k, knee + tip), "Accent")
        rw_bool(a_, b_, op="UNION")
        prong_meshes.append(a_)
    prongs = prong_meshes[0]
    prongs.name = P + "Prongs"
    for o in prong_meshes[1:]:
        rw_bool(prongs, o, op="UNION")
    rw_empty(col, P + "Handle", (0, 0, 0))
    rw_empty(col, P + "Zap", (0, 0, 0))
    return S


SEATS = [("Cage", "Belt"), ("Cage", "Core"), ("Cage", "Node"), ("Cage", "Prongs")]

S = build()
audit = rw_audit(MOD + "_", seats=SEATS)
shots = {}
for view, zoom, tgt in (("hero", 1.0, None), ("back", 1.0, None), ("hand", 1.0, None), ("top", 1.0, None), ("side", 1.0, None),
                        ((0.9, -0.5, 0.6), 2.4, (0.10, -0.05, 0.10)),  # rib into the top cap
                        ((0.9, 0.6, 0.15), 2.4, (0.15, 0.0, 0.0)),  # belt and ribs
                        ((0.6, -0.6, -0.9), 1.6, (0.0, 0.0, -0.15)),  # prongs from below
                        ((-0.8, 0.5, -0.4), 2.2, (0.0, 0.0, 0.0))):  # core through the cage, back side
    name = view if isinstance(view, str) else "close%d" % len(shots)
    shots[name] = rw_render(S, MOD + "_", os.path.join(OUT, "electricshock_%s_%s.jpg" % (VERSION, name)), view=view, zoom=zoom, target=tgt,
                            res=(1000, 1000) if not isinstance(view, str) else (1200, 1000))
src = rw_write_source(MOD, os.path.join(RW_WORK, MOD, "%s_%s.blend" % (MOD, VERSION)))
result = {"pid": os.getpid(), "audit": audit, "renders": shots, "source": src, "bounds": [list(v) for v in rw_bounds(MOD + "_")]}
