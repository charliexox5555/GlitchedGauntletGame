"""Export the Rooftops4 kit (live Blender MCP, port 9897): art-source/maps/Rooftops4/Exports/Kit.fbx + Kit.json.

python tools/blender/lobby_v4/send.py tools/blender/maps_rooftops4/run_rooftops4_export.py --port 9897 --pid <pid>
Then: python tools/opencloud/upload_models.py --maps Rooftops4 --group 11116787 Kit
      python tools/studio/maps/kit_bundle.py Rooftops4 Kit -o <file>   (run in the match place)
"""
import importlib
import sys

import bpy

REPO = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
sys.path[:0] = [
	REPO + r"\tools\blender",
	REPO + r"\tools\blender\maps_rooftops4",
	REPO + r"\tools\blender\maps_snowpeak4",
	REPO + r"\tools\blender\maps_arena",
]
import arena_kit as A
import export_lobby_kit as E
import snowcat_model as SC
import rooftops4_pieces as K

for m in (A, SC, K, E):
	importlib.reload(m)

K.build_all()
res = E.main(["--maps", "Rooftops4", "Kit", *K.PIECES])
tmp = bpy.data.collections.get("_Export")
if tmp:
	for o in list(tmp.objects):
		bpy.data.objects.remove(o, do_unlink=True)
	bpy.data.collections.remove(tmp)
K.build_all()
result = {"export": res}
