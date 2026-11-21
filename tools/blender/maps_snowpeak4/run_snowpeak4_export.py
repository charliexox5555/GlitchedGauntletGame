"""Export the Snowpeak4 kit (live Blender MCP, port 9897): art-source/maps/Snowpeak4/Exports/Kit.fbx + Kit.json.

python tools/blender/lobby_v4/send.py tools/blender/maps_snowpeak4/run_snowpeak4_export.py --port 9897 --pid <pid>
Then: python tools/opencloud/upload_models.py --maps Snowpeak4 --group 11116787 Kit
      python tools/studio/maps/kit_bundle.py Snowpeak4 Kit -o <file>   (run in the match place)
"""
import importlib
import sys

import bpy

REPO = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
sys.path[:0] = [
	REPO + r"\tools\blender",
	REPO + r"\tools\blender\maps_snowpeak4",
	REPO + r"\tools\blender\maps_metro4",
	REPO + r"\tools\blender\maps_arena",
]
import arena_kit as A
import export_lobby_kit as E
import metro4_pieces as K
import snowpeak4_pieces as S

import snowcat_model as SC

for m in (A, K, SC, S, E):
	importlib.reload(m)

S.build_all()
res = E.main(["--maps", "Snowpeak4", "Kit", *S.PIECES])
tmp = bpy.data.collections.get("_Export")
if tmp:
	for o in list(tmp.objects):
		bpy.data.objects.remove(o, do_unlink=True)
	bpy.data.collections.remove(tmp)
S.build_all()
result = {"export": res}
