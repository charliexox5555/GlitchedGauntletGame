"""Export the port kit (live maps Blender, port 9930): art-source/maps/Port/Exports/Kit.fbx + Kit.json.

python tools/blender/lobby_v4/send.py tools/blender/maps_port/run_export.py --port 9930 --pid <pid>
Then: python tools/opencloud/upload_models.py --maps Port --group 11116787 Kit
      python tools/studio/maps/kit_bundle.py Port Kit -o <file>   (run in the match place)
The exporter bakes and splits the masters, so the kit is rebuilt afterwards.
"""
import importlib
import sys

REPO = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
sys.path[:0] = [REPO + r"\tools\blender", REPO + r"\tools\blender\maps_port", REPO + r"\tools\blender\maps_arena"]
import arena_kit as A
import export_lobby_kit as E
import port_kit as P
import port_pieces as K

for m in (A, P, K, E):
	importlib.reload(m)

K.build_all()
res = E.main(["--maps", "Port", "Kit"])
import bpy

tmp = bpy.data.collections.get("_Export")
if tmp:
	for o in list(tmp.objects):
		bpy.data.objects.remove(o, do_unlink=True)
	bpy.data.collections.remove(tmp)
K.build_all()
result = res
