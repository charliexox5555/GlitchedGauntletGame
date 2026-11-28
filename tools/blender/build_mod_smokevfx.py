"""SmokeVFX kit (the Smoke power's dome), built in a LIVE Blender MCP bridge (vault/02 Art/Mod Props - Smoke and Electric
Shock.md). Untextured, flat-shaded meshes the game clones, scales, colours and fades in code.

    python tools/blender/lobby_v4/send.py tools/blender/build_mod_smokevfx.py --port <port> --pid <pid>

Export -> art-source/abilities/Exports/SmokeVFX.{fbx,json}; source -> art-source/abilities/SmokeVFX/SmokeVFX_<VERSION>.blend.
Parts (every one at the Blender origin, so code places them; a MeshPart's CFrame is its box centre):
  Puff1, Puff2, Puff3  faceted low-poly cloud lumps about 1 stud across, centred on the origin (round / long / flat)
  Dome                 a faceted hemisphere shell, radius 1, floor centre at the origin, open bottom, normals out
                       (box 2 x 1 x 2: its centre sits 0.5 above the floor). Seen from inside too: DoubleSided.
"""
import os, random

exec(open(os.path.join(r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame", "tools", "blender", "rework", "rw_core.py")).read())
RW_WORK = os.path.join(RW_REPO, "art-source", "abilities")
RW_PALETTE["FxSmoke"] = ("#8E949C", 0.95, 0.0, 0.0, "SmoothPlastic")  # review colour only: code colours the smoke
VERSION = globals().get("VERSION", "v01")
MOD = "SmokeVFX"
OUT = os.path.join(RW_REPO, "vault", "02 Art", "References", "mods")


def puff(name, n, scale, seed, lumpy=0.12):
    """A convex faceted lump: n points on a golden spiral, each pushed in or out a little (seeded), hulled."""
    rnd = random.Random(seed)
    pts = []
    for i in range(n):
        y = 1 - 2 * (i + 0.5) / n
        r = math.sqrt(max(0.0, 1 - y * y))
        a = i * math.pi * (3 - math.sqrt(5))
        k = 1 + rnd.uniform(-lumpy, lumpy)
        pts.append((0.5 * scale[0] * r * math.cos(a) * k, 0.5 * scale[1] * r * math.sin(a) * k, 0.5 * scale[2] * y * k))
    return rw_hull(name, pts)


def dome(name, segs=12, rings=(0, 24, 48, 70)):
    bm = bmesh.new()
    vr = []
    for el in rings:
        e = math.radians(el)
        vr.append([bm.verts.new((math.cos(e) * math.cos(2 * math.pi * i / segs + math.pi / segs),
                                 math.cos(e) * math.sin(2 * math.pi * i / segs + math.pi / segs), math.sin(e))) for i in range(segs)])
    pole = bm.verts.new((0, 0, 1))
    for a, b in zip(vr, vr[1:]):
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((a[i], a[j], b[j], b[i]))
    for i in range(segs):
        bm.faces.new((vr[-1][i], vr[-1][(i + 1) % segs], pole))
    bm.normal_update()
    for f in bm.faces:  # outward normals
        if f.normal.dot(f.calc_center_median()) < 0:
            f.normal_flip()
    return _rw_finish(bm, name)


def build():
    S = rw_scene("FP_" + MOD)
    rw_clear(MOD + "_")
    col = rw_col(S, MOD)
    P = MOD + "_"
    rw_obj(col, P + "Puff1", puff(P + "Puff1", 22, (1.0, 1.0, 0.86), 11), "FxSmoke")
    rw_obj(col, P + "Puff2", puff(P + "Puff2", 24, (1.25, 0.82, 0.78), 23), "FxSmoke")
    rw_obj(col, P + "Puff3", puff(P + "Puff3", 20, (1.05, 1.0, 0.6), 37, 0.16), "FxSmoke")
    rw_obj(col, P + "Dome", dome(P + "Dome"), "FxSmoke")
    return S


S = build()
P = MOD + "_"
layout = {"Puff1": (-2.6, 0, 0.5), "Puff2": (-1.2, 0, 0.5), "Puff3": (0.2, 0, 0.4), "Dome": (2.2, 0, 0)}
for k, v in layout.items():
    bpy.data.objects[P + k].location = v
shots = {}
for view in ("hero", "side", "top", (0.6, -0.8, -0.35)):
    name = view if isinstance(view, str) else "under"
    shots[name] = rw_render(S, P, os.path.join(OUT, "smokevfx_%s_%s.jpg" % (VERSION, name)), view=view, res=(1600, 900))
for k in layout:
    bpy.data.objects[P + k].location = (0, 0, 0)
audit = {}
for k in layout:  # one by one: they all sit on the origin for the export
    a = rw_audit(P + k)
    audit[k] = {"tris": a["tris"], "faces": len(bpy.data.objects[P + k].data.polygons), "open_edges": a["open_edges"], "style": a["style"]}
src = rw_write_source(MOD, os.path.join(RW_WORK, MOD, "%s_%s.blend" % (MOD, VERSION)))
result = {"pid": os.getpid(), "audit": audit, "renders": shots, "source": src}
