"""ShockVFX kit (the Electric Shock strike), built in a LIVE Blender MCP bridge (vault/02 Art/Mod Props - Smoke and
Electric Shock.md). Untextured, flat-shaded meshes the game clones, scales and colours in code.

    python tools/blender/lobby_v4/send.py tools/blender/build_mod_shockvfx.py --port <port> --pid <pid>

Export -> art-source/abilities/Exports/ShockVFX.{fbx,json}; source -> art-source/abilities/ShockVFX/ShockVFX_<VERSION>.blend.
Parts (each at the Blender origin; a MeshPart's CFrame is its box centre):
  Ring  the warning ring under the locked player: a flat faceted band, outer radius 1, inner 0.86, 0.04 thick, 20 facets,
        flat on Blender XY (Roblox XZ), centred on the origin.
  Bolt  the strike: a jagged faceted lightning bolt 1 stud tall along Blender +Z (Roblox +Y), base at the origin (box
        centre 0.5 up), six kinks and one short fork, tapering from 0.05 at the base to a point at the top.
"""
import os

exec(open(os.path.join(r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame", "tools", "blender", "rework", "rw_core.py")).read())
RW_WORK = os.path.join(RW_REPO, "art-source", "abilities")
RW_PALETTE["FxShock"] = ("#CFEBFF", 0.40, 0.0, 2.2, "Neon")  # review colour only: code colours the strike
VERSION = globals().get("VERSION", "v01")
MOD = "ShockVFX"
OUT = os.path.join(RW_REPO, "vault", "02 Art", "References", "mods")


def diamond(p, w, twist):
    c, s = math.cos(twist), math.sin(twist)
    return [(p[0] + w * c, p[1] + w * s, p[2]), (p[0] - w * s, p[1] + w * c, p[2]), (p[0] - w * c, p[1] - w * s, p[2]), (p[0] + w * s, p[1] - w * c, p[2])]


def bolt_segments(path, w0, w1, prefix):
    out = []
    n = len(path)
    for i in range(n - 1):
        wa = w0 + (w1 - w0) * i / (n - 1)
        wb = w0 + (w1 - w0) * (i + 1) / (n - 1)
        out.append(rw_hull(prefix + str(i), diamond(path[i], wa, 0.6 * i) + diamond(path[i + 1], max(wb, 0.003), 0.6 * i)))
    return out


def build():
    S = rw_scene("FP_" + MOD)
    rw_clear(MOD + "_")
    col = rw_col(S, MOD)
    P = MOD + "_"
    ring = rw_obj(col, P + "Ring", rw_loft(P + "Ring", [(-0.020, rw_ngon(0.988, 20)), (-0.010, rw_ngon(1.0, 20)), (0.010, rw_ngon(1.0, 20)), (0.020, rw_ngon(0.988, 20))]), "FxShock")
    hole = rw_obj(col, P + "RingHole", rw_loft(P + "RingHole", [(-0.05, rw_ngon(0.86, 20)), (0.05, rw_ngon(0.86, 20))]), None)
    rw_bool(ring, hole)
    main = [(0, 0, 0), (0.07, 0.015, 0.15), (-0.055, -0.02, 0.31), (0.08, 0.025, 0.47), (-0.045, 0.0, 0.62), (0.06, -0.015, 0.78), (-0.02, 0.01, 0.9), (0.0, 0.0, 1.0)]
    segs = bolt_segments(main, 0.05, 0.004, P + "BoltSeg")
    fork = bolt_segments([(0.08, 0.025, 0.47), (0.17, 0.03, 0.56), (0.15, 0.02, 0.68)], 0.022, 0.003, P + "ForkSeg")
    bolt = rw_obj(col, P + "Bolt", segs[0], "FxShock")
    for i, me in enumerate(segs[1:] + fork):
        o = rw_obj(col, P + "BoltTmp%d" % i, me, "FxShock")
        rw_bool(bolt, o, op="UNION")
    return S


S = build()
P = MOD + "_"
layout = {"Ring": (-1.3, 0, 0.0), "Bolt": (1.0, 0, -0.5)}
for k, v in layout.items():
    bpy.data.objects[P + k].location = v
shots = {}
for view in ("hero", "side", "top"):
    shots[view] = rw_render(S, P, os.path.join(OUT, "shockvfx_%s_%s.jpg" % (VERSION, view)), view=view, res=(1600, 900))
bpy.data.objects[P + "Ring"].location = (0, 0, 0)
bpy.data.objects[P + "Bolt"].location = (0, 0, 0)
shots["bolt"] = rw_render(S, P + "Bolt", os.path.join(OUT, "shockvfx_%s_bolt.jpg" % VERSION), view="side", res=(800, 1200))
audit = {}
for k in layout:
    a = rw_audit(P + k)
    audit[k] = {"tris": a["tris"], "open_edges": a["open_edges"], "style": a["style"]}
src = rw_write_source(MOD, os.path.join(RW_WORK, MOD, "%s_%s.blend" % (MOD, VERSION)))
result = {"pid": os.getpid(), "audit": audit, "renders": shots, "source": src}
