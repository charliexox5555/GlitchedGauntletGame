"""Export the Wharf kit (live Blender MCP, port 9897): art-source/maps/Wharf/Exports/Kit.fbx + Kit.json.

python tools/blender/lobby_v4/send.py tools/blender/maps_wharf/run_wharf_export.py --port 9897 --pid <pid>
Then: python tools/opencloud/upload_models.py --maps Wharf --group 11116787 Kit
      python tools/studio/maps/kit_bundle.py Wharf Kit -o <file>   (run in the match place)
"""
import importlib
import sys

REPO = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
sys.path[:0] = [REPO + r"\tools\blender", REPO + r"\tools\blender\maps_wharf", REPO + r"\tools\blender\maps_arena"]
import arena_kit as A
import export_lobby_kit as E
import wharf_pieces as W

for m in (A, W, E):
	importlib.reload(m)

W.build_all()
res = E.main(["--maps", "Wharf", "Kit", *W.PIECES])
import bpy

tmp = bpy.data.collections.get("_Export")
if tmp:
	for o in list(tmp.objects):
		bpy.data.objects.remove(o, do_unlink=True)
	bpy.data.collections.remove(tmp)
W.build_all()
result = res
