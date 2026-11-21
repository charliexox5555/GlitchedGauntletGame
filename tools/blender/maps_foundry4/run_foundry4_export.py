"""Export the Foundry4 kit (live Blender MCP, port 9897): art-source/maps/Foundry4/Exports/Kit.fbx + Kit.json.

python tools/blender/lobby_v4/send.py tools/blender/maps_foundry4/run_foundry4_export.py --port 9897 --pid <pid>
Then: python tools/opencloud/upload_models.py --maps Foundry4 --group 11116787 Kit
      python tools/studio/maps/kit_bundle.py Foundry4 Kit -o <file>   (run in the match place)
"""
import importlib
import os
import sys

import bpy

REPO = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
BLEND = REPO + r"\art-source\maps\Foundry4\Kit_Foundry4.blend"
if os.path.normcase(bpy.data.filepath) != os.path.normcase(BLEND):
	assert not bpy.data.is_dirty, "the open file has unsaved changes"
	bpy.ops.wm.open_mainfile(filepath=BLEND)
sys.path[:0] = [
	REPO + r"\tools\blender",
	REPO + r"\tools\blender\maps_foundry4",
	REPO + r"\tools\blender\maps_greenhouse4",
	REPO + r"\tools\blender\maps_snowpeak4",
	REPO + r"\tools\blender\maps_arena",
]
import arena_kit as A
import export_lobby_kit as E
import snowcat_model as SC
import greenhouse4_pieces as G
import foundry4_pieces as K

for m in (A, SC, G, K, E):
	importlib.reload(m)

K.build_all()
res = E.main(["--maps", "Foundry4", "Kit", *K.PIECES])
tmp = bpy.data.collections.get("_Export")
if tmp:
	for o in list(tmp.objects):
		bpy.data.objects.remove(o, do_unlink=True)
	bpy.data.collections.remove(tmp)
K.build_all()
bpy.ops.wm.save_mainfile()
result = {"export": res}
