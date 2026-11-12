"""Lobby V3: build everything, audit, render. Run through Blender MCP:
    import sys; sys.path.insert(0, r"<repo>/tools/blender/lobby_v3")
    import lv3_run as R; R.build_all(); R.audit(); R.shots(["01_hub_spawn"])
"""
import importlib
import os
import bpy
import lv3_core as C
import lv3_hub as H
import lv3_duels as DU
import lv3_wings as W
import lv3_audit as A
import lv3_props as P

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(REPO, "vault", "02 Art", "References", "lobby", "v3")
BLEND = os.path.join(REPO, "art-source", "lobby", "LobbyV3.blend")

CAMS = {
	"01_hub_spawn": ((0, -17, 5.0), (0, 30, 7.5), 15),
	"02_hub_vault_mouth": ((-20, -8, 5.5), (34, 6, 7.0), 16),
	"03_hub_market_range": ((17, 15, 5.5), (-30, -24, 7.0), 15),
	"04_duels_entry": ((0, 53.5, 6.2), (0, 150, -1), 15),
	"05_duels_hall": ((6, 100, 2.0), (-22, 128, 1), 15),
	"06_duels_gauntlet_gate": ((-3, 205, 1.0), (1, 246, 6.0), 16),
	"07_market": ((-54, 0, 5), (-115, 0, 3), 15),
	"08_market_arcade": ((-100, -10, 3.5), (-70, 30, 4.5), 15),
	"09_vault": ((54, 0, 5.5), (90, 0, 5), 15),
	"10_vault_door": ((90, -12, 5), (60, 10, 6), 15),
	"11_range": ((0, -59, 4.0), (0, -96, 2.5), 15),
	"12_range_side": ((19, -68, 3.0), (-18, -95, 2.5), 15),
}


def reload():
	for m in (C, H, DU, W, A, P):
		importlib.reload(m)


def build_all():
	reload()
	C.COLLISION.clear()
	C.setup_scene()
	C.make_materials()
	H.build()
	H.shell()
	DU.build()
	W.build()
	P.build()
	for n, (a, b, lens) in CAMS.items():
		C.camera(n, a, b, lens)
	bpy.context.view_layer.update()


def audit():
	return A.run(40)


def shots(names=None, samples=128, res=(1600, 900)):
	os.makedirs(OUT, exist_ok=True)
	done = []
	for n in names or CAMS:
		done.append(C.render(n, os.path.join(OUT, n + ".jpg"), samples=samples, res=res))
	return done


def _ceilings(hide):
	for c in bpy.data.collections[C.ROOT].children:
		if c.name.endswith("_Ceil") or c.name in ("RenderShell", "Scale"):
			c.hide_render = hide


def plan(samples=64):
	"""Roof-off views: a top-down plan and a bird's-eye view. Daylight only."""
	os.makedirs(OUT, exist_ok=True)
	_ceilings(True)
	sc = bpy.context.scene
	bg = sc.world.node_tree.nodes["Background"]
	old = bg.inputs[1].default_value
	bg.inputs[1].default_value = 2.2
	try:
		C.camera("00_plan", (-10, 12, 300), (-10, 12, 0), ortho=300)
		bpy.data.objects["00_plan"].rotation_euler = (0, 0, 0)
		C.render("00_plan", os.path.join(OUT, "00_plan.jpg"), samples=samples, res=(1500, 1500))
		C.camera("00_birdseye", (150, -150, 170), (-5, 25, 0), 32)
		C.render("00_birdseye", os.path.join(OUT, "00_birdseye.jpg"), samples=samples, res=(1600, 900))
	finally:
		bg.inputs[1].default_value = old
		_ceilings(False)


def save():
	os.makedirs(os.path.dirname(BLEND), exist_ok=True)
	bpy.ops.wm.save_as_mainfile(filepath=BLEND)
	return BLEND
