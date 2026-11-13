"""Sunwell Works: build, audit, render and save (run through Blender MCP in the owner's open Blender).

    import sys; sys.path[:0] = [r"<repo>/tools/blender/sunwell_p1", r"<repo>/tools/blender/lobby_v3"]
    import sw_run as R; R.build_all(); R.audit(); R.shots(["01_spawn"]); R.save()
"""
import importlib
import os

import bpy
from mathutils import Vector

import lv3_core as C
import lv3_audit as A
import sw_core as S
import sw_hall as H
import sw_doors as DR
import sw_props as P
import sw_locker as LK
import sw_shop as SH
import sw_duels as DU
import sw_hub as HB

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(REPO, "vault", "02 Art", "References", "lobby", "sunwell-works", "build")
BLEND = os.path.join(REPO, "art-source", "lobby", "SunwellWorks.blend")

CAMS = {  # name: (position, target, lens mm)
	"01_spawn": ((0, -12.5, 10.5), (0, 60, 8.5), 14.5),
	"02_reverse": ((0, 92, 7.5), (0, 0, 7.0), 14.5),
	"03_duels": ((6, 30, 6.5), (-34, 34, 8.5), 16),
	"04_locker": ((-6, 30, 6.5), (34, 34, 8.5), 16),
	"05_range": ((6, 76, 6.5), (-34, 72, 8.5), 16),
	"06_shop": ((-6, 76, 6.5), (34, 72, 8.5), 16),
	"07_turbine": ((9, 78, 6.0), (0, 112, 11.0), 18),
	"08_bench": ((-22, 46, 4.2), (-35, 53.5, 2.4), 24),
	"09_hall_side": ((-26, 22, 9.0), (20, 78, 9.0), 14.5),
	"10_locker_in": ((45.5, 34, 6.5), (89, 34, 6.2), 14),
	"11_locker_bays": ((58, 44, 5.5), (84, 22, 6.0), 16),
	"12_shop_in": ((40.0, 72, 6.5), (89, 72, 5.5), 14),
	"13_shop_side": ((52, 86, 5.5), (80, 62, 5.0), 16),
	"14_duels_in": ((-45.5, 34, 6.5), (-120, 34, 1.0), 14),
	"15_duels_floor": ((-112, 26, 2.5), (-132, 56, 2.5), 16),
}
PROBES = {"alcove": (0, -9, 8), "landing": (0, 2, 8), "entry_bay": (22, 7, 5), "hall_near": (0, 34, 6), "hall_mid": (-20, 53, 6),
	"hall_far": (0, 90, 6), "duels": (-39, 34, 5), "locker": (39, 34, 5), "range": (-39, 72, 5), "shop": (39, 72, 5), "roof": (20, 60, 26),
	"locker": (55, 34, 6), "locker_far": (82, 34, 9), "shop": (55, 76, 6), "shop_far": (78, 98, 8),
	"duels_deck": (-50, 34, 5), "duels_floor": (-120, 34, 2), "duels_far": (-190, 30, 2)}
WINGS = {"Locker": LK, "Shop": SH, "Duels": DU}  # built wings: their doorways lose the temporary closure
MODULES = [S, H, DR, P, HB] + list(WINGS.values())


def reload():
	for m in [C, A] + MODULES:
		importlib.reload(m)


def new_file():
	"""Start from an empty file (the owner asked for a fresh scene) and name it."""
	bpy.ops.wm.read_homefile(use_empty=True)
	os.makedirs(os.path.dirname(BLEND), exist_ok=True)
	bpy.ops.wm.save_as_mainfile(filepath=BLEND)
	return BLEND


def render_setup():
	"""Daylight through the skylights for review renders (the Studio lighting is set separately)."""
	sc = bpy.context.scene
	col = C.coll("RenderAids", S.root())
	C.clear("RenderAids")
	C.light(col, "Sun", "SUN", (0, 60, 80), "#FFF1DC", 5.0, size=3.0, rot=(18, 12, 0))
	for y in (8, 34, 53, 72, 91):  # soft bounce so the walls are not black in a quick render
		C.light(col, f"Fill_{y}", "AREA", (0, y, 26.5), "#FFF6EA", 9000, size=16, rot=(0, 0, 0))
	C.light(col, "AlcoveFill", "AREA", (0, -9, 17.0), "#FFF0DC", 2500, size=8, rot=(0, 0, 0))
	bg = sc.world.node_tree.nodes.get("Background")
	if bg:
		bg.inputs[0].default_value = C.lin("#9CC4FF")
		bg.inputs[1].default_value = 2.0
	sc.cycles.samples = 64


def build_all(cams=True):
	reload()
	C.ROOT = S.ROOT
	C.COLLISION.clear()
	S.LIGHTS.clear()
	S.GUNS.clear()
	S.ANCHORS.clear()
	S.SCREENS.clear()
	S.ANIM.clear()
	S.SOUNDS.clear()
	S.OPEN = set(WINGS)
	C.setup_scene()
	S.make_materials()
	for m in MODULES[1:]:
		S.AREA = getattr(m, "AREA", "Hall")
		m.build()
	for col in bpy.data.collections[S.ROOT].children:  # weighted normals: flat faces stay flat next to a bevel
		for o in col.objects:
			if o.type == "MESH" and not any(m.type == "WEIGHTED_NORMAL" for m in o.modifiers):
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
		worst = (0, "")
		for o in col.objects:
			if o.type != "MESH":
				continue
			me = o.evaluated_get(dg).to_mesh()
			me.calc_loop_triangles()
			k = len(me.loop_triangles)
			o.evaluated_get(dg).to_mesh_clear()
			n += 1
			t += k
			worst = max(worst, (k, o.name))
		if n:
			out[col.name] = {"objects": n, "tris": t, "largest": worst}
	out["colliders"] = {k: len(v) for k, v in C.COLLISION.items()}
	out["lights"] = {k: len(v) for k, v in S.LIGHTS.items()}
	return out


def audit(n=30):
	col = bpy.data.collections.get("RenderAids")
	return A.run(n, root=S.ROOT, probes=PROBES)


def shots(names=None, samples=64, res=(1280, 720), exposure=0.0):
	os.makedirs(OUT, exist_ok=True)
	done = []
	for n in names or CAMS:
		done.append(C.render(n, os.path.join(OUT, n + ".jpg"), samples=samples, res=res, exposure=exposure))
	return done


def save():
	bpy.ops.wm.save_as_mainfile(filepath=BLEND)
	return BLEND
