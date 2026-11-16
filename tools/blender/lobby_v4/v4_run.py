"""Lobby V4: build, stats, review renders and save (run in the Lobby V4 Blender through tools/blender/lobby_v4/send.py).

    import sys; sys.path[:0] = [r"<repo>/tools/blender/lobby_v4", r"<repo>/tools/blender/sunwell_p1", r"<repo>/tools/blender/lobby_v3"]
    import v4_run as R; R.build_all(); R.shots(["c01_spawn"]); R.save()
"""
import importlib
import os

import bpy

import lv3_core as C
import sw_core as S
import v4_core as V
import v4_hub as HB
import v4_duels as DU
import v4_wings as WG
import lv3_audit as A

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(REPO, "vault", "02 Art", "References", "lobby", "v4", "build")
BLEND = os.path.join(REPO, "art-source", "lobby", "LobbyV4.blend")

CAMS = {  # name: (position, target, lens mm)
	"c01_spawn": ((0, -2.0, 7.5), (0, 60, 12.0), 14.5),
	"c02_reverse": ((0, 36, 7.0), (0, -40, 9.0), 14.5),
	"c03_oblique": ((-30, -30, 26), (8, 10, 6), 14.0),
	"c04_shop": ((-16, 4, 6.5), (46, 0, 12), 16),
	"c05_locker": ((16, -4, 6.5), (-46, 0, 12), 16),
	"c06_range": ((-6, 20, 6.5), (0, -46, 9), 16),
	"c07_niche": ((18, -6, 6.0), (34, -32, 5), 18),
	"c08_up": ((0, -20, 4), (0, 0, 40), 14),
	"c09_sign": ((0, 26, 14), (0, 46, 26), 22),
	"d01_enter": ((0, 63, 6.5), (0, 170, 6), 14.5),
	"d02_bays": ((18, 100, 4), (-42, 130, 6), 16),
	"d03_bay": ((-26, 82, 3.5), (-52, 82, 1), 20),
	"d04_trophy": ((0, 140, 4), (0, 173, 8), 18),
	"d05_back": ((0, 165, 8), (0, 62, 8), 14.5),
	"d06_high": ((30, 70, 22), (-10, 140, -2), 14),
	"l01_enter": ((-64, 4, 7), (-114, -2, 7), 15),
	"l02_cases": ((-76, -10, 6), (-96, 24, 7), 16),
	"s01_enter": ((64, -4, 7), (116, 4, 7), 15),
	"s02_pass": ((80, -14, 6), (90, 26, 9), 16),
}
MODULES = [HB, DU, WG]
OPEN = {"Duels", "Locker", "Shop"}  # wings built: the hub leaves their doorway open
PROBES = {"hub": (0, 0, 5), "hub_ring": (30, 12, 4), "hub_niche": (20, -20, 3), "duels_landing": (0, 64, 4), "duels_mid": (0, 100, 1),
	"duels_apse": (0, 165, 1), "duels_bay": (-50, 82, 1), "duels_bay_e": (50, 142, 1), "locker": (-88, 0, 5), "locker_case": (-80, 18, 4), "shop": (89, 0, 5), "shop_pass": (89, 14, 4)}


def reload():
	for m in (C, S, V, A) + tuple(MODULES):
		importlib.reload(m)
	V.register()
	HB.OPEN = set(OPEN)


def render_setup():
	sc = bpy.context.scene
	col = C.coll("RenderAids", S.root())
	C.clear("RenderAids")
	C.light(col, "Sun", "SUN", (0, 0, 90), "#FFF4E4", 4.0, size=2.0, rot=(8, 6, 0))
	for x, y in ((0, 30), (30, 0), (-30, 0), (0, -30), (21, 21), (-21, 21), (21, -21), (-21, -21)):
		C.light(col, f"Fill_{x}_{y}", "AREA", (x, y, 30.0), "#F4F1EA", 2600, size=10, rot=(0, 0, 0))
	for x in (-26, 0, 26):
		for y in (80, 112, 144, 168):
			C.light(col, f"DFill_{x}_{y}", "AREA", (x, y, 25.0), "#F4F1EA", 2200, size=10, rot=(0, 0, 0))
	for x, y in ((-100, 0), (-76, 0), (76, 0), (102, 0)):
		C.light(col, f"WFill_{x}_{y}", "AREA", (x, y, 25.0), "#F4F1EA", 2200, size=10, rot=(0, 0, 0))
	bg = sc.world.node_tree.nodes.get("Background")
	if bg:
		bg.inputs[0].default_value = C.lin("#9CC4FF")
		bg.inputs[1].default_value = 1.0
	sc.cycles.samples = 48


def build_all(cams=True):
	reload()
	C.ROOT = S.ROOT
	C.COLLISION.clear()
	C.reset_groups()
	C.Kit.SEQ = 0
	C.Kit.SEQS.clear()
	for t in (S.LIGHTS, S.GUNS, S.ANCHORS, S.SCREENS, S.SOUNDS):
		t.clear()
	S.ANIM.clear()
	C.setup_scene()
	S.make_materials()
	for m in (HB, DU, WG.Locker, WG.Shop):  # the Range is not built yet (owner 2026-11-16)
		S.AREA = m.AREA
		m.build()
	for col in bpy.data.collections[S.ROOT].children:
		for o in col.objects:
			if o.type == "MESH" and not any(md.type == "WEIGHTED_NORMAL" for md in o.modifiers):
				wn = o.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
				wn.keep_sharp = True
				wn.weight = 50
				wn.thresh = 0.01
	render_setup()
	if cams:
		for n, (a, b, lens) in CAMS.items():
			C.camera(n, a, b, lens)
	bpy.context.view_layer.update()
	return stats()


def stats():
	dg = bpy.context.evaluated_depsgraph_get()
	out = {}
	for col in bpy.data.collections[S.ROOT].children:
		n = t = 0
		for o in col.objects:
			if o.type != "MESH":
				continue
			me = o.evaluated_get(dg).to_mesh()
			me.calc_loop_triangles()
			t += len(me.loop_triangles)
			o.evaluated_get(dg).to_mesh_clear()
			n += 1
		if n:
			out[col.name] = {"objects": n, "tris": t}
	out["pieces"] = len(C.GROUPS)
	out["colliders"] = {k: len(v) for k, v in C.COLLISION.items()}
	out["lights"] = {k: len(v) for k, v in S.LIGHTS.items()}
	out["screens"] = len(S.SCREENS)
	out["anchors"] = len(S.ANCHORS)
	return out


def shots(names=None, samples=40, res=(1280, 720), exposure=0.0):
	os.makedirs(OUT, exist_ok=True)
	return [C.render(n, os.path.join(OUT, n + ".jpg"), samples=samples, res=res, exposure=exposure) for n in names or CAMS]


def audit(n=30):
	return A.run(n, root=S.ROOT, probes=PROBES)


def save():
	os.makedirs(os.path.dirname(BLEND), exist_ok=True)
	bpy.ops.wm.save_as_mainfile(filepath=BLEND)
	return BLEND
