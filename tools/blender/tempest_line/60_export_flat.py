# Run the shared flat exporter on a Tempest-Strike line item, then the one-sided re-import check.
# Set GUN, VER (e.g. "s02x"). Writes <Item>_TempestStrike_RobloxFlat.fbx + manifest_flat.json next to the blend,
# and check renders (magenta, backface culling) to the scratchpad.
import os, glob
TSROOT = r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/"
ITEMS = [("TempestStrike", GUN, VER)]
exec(open(TSROOT + "tools/blender/export_skin_items_flat.py").read())
exp = result
d = TSROOT + "art-source/weapons/Skins/TempestStrike/%s/%s/" % (GUN, VER)
fbx = glob.glob(d + "*_RobloxFlat.fbx")[0]
FBXS = [(GUN, fbx, d + "manifest_flat.json")]
OUT = r"C:/Users/charl/AppData/Local/Temp/claude/6f8bed3fe7c45255/6fc92333-7f52-4d25-b886-dff8b47c2843/scratchpad/flatcheck"
exec(open(TSROOT + "tools/blender/check_flat_export.py").read())
result = {"export": exp, "check": result}
