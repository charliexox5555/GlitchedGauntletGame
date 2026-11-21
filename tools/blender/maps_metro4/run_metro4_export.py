"""Export the shared Props kit and the Metro4 kit (live Blender MCP, port 9897).

python tools/blender/lobby_v4/send.py tools/blender/maps_metro4/run_metro4_export.py --port 9897 --pid <pid>
Writes art-source/maps/Props/Exports/Kit.fbx + .json and art-source/maps/Metro4/Exports/Kit.fbx + .json. Then:
  python tools/opencloud/upload_models.py --maps Props --group 11116787 Kit
  python tools/opencloud/upload_models.py --maps Metro4 --group 11116787 Kit
  python tools/studio/maps/kit_bundle.py Props Kit -o <file>   /   ... Metro4 Kit -o <file>   (run in the match place)
"""
import importlib
import sys

import bpy

REPO = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
sys.path[:0] = [REPO + r"\tools\blender", REPO + r"\tools\blender\maps_metro4", REPO + r"\tools\blender\maps_arena"]
import arena_kit as A
import export_lobby_kit as E
import metro4_pieces as K

for m in (A, K, E):
	importlib.reload(m)


def clean():
	tmp = bpy.data.collections.get("_Export")
	if tmp:
		for o in list(tmp.objects):
			bpy.data.objects.remove(o, do_unlink=True)
		bpy.data.collections.remove(tmp)


res = []
K.build_all()
res.append(E.main(["--maps", "Props", "Kit", *K.PROPS]))
clean()
K.build_all()
res.append(E.main(["--maps", "Metro4", "Kit", *K.METRO]))
clean()
K.build_all()
result = {"exports": res}
