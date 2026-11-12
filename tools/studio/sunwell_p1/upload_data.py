"""Pack the Sunwell Works build data and the build tool into one Roblox model and upload it (Open Cloud).

    python tools/studio/sunwell_p1/upload_data.py --group 11116787

Reads art-source/lobby/Exports/SW1Data/*.json (written by tools/blender/sunwell_p1/sw_export.py), the SW1_* asset ids
in art-source/lobby/Exports/assets.json (packed as "Assets") and tools/studio/sunwell_p1/Build_SW1.luau.
Writes art-source/lobby/Exports/SW1_Data.rbxmx: a Folder "SW1Data" of StringValues (JSON in chunks, named
<File>__<n>) and a ModuleScript "Build". The asset id is recorded in assets.json as "SW1_Data".
The API key comes from ROBLOX_ASSETS_KEY (see tools/opencloud/upload_models.py); it is never printed.
"""
import argparse
import json
import os
import sys
import time
from xml.sax.saxutils import escape

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "opencloud"))
import upload_models as U  # noqa: E402

EXPORTS = os.path.join(ROOT, "art-source", "lobby", "Exports")
DATA = os.path.join(EXPORTS, "SW1Data")
OUT = os.path.join(EXPORTS, "SW1_Data.rbxmx")
KEY = "SW1_Data"
CHUNK = 180000


def build_rbxmx(record):
	items = []
	ref = [0]

	def item(cls, name, prop):
		ref[0] += 1
		return f'<Item class="{cls}" referent="RBX{ref[0]}"><Properties><string name="Name">{name}</string>{prop}</Properties></Item>'

	def add_json(name, text):
		for k in range(0, len(text), CHUNK):
			items.append(item("StringValue", f"{name}__{k // CHUNK + 1}", f'<string name="Value">{escape(text[k:k + CHUNK])}</string>'))

	for fn in sorted(os.listdir(DATA)):
		if fn.endswith(".json"):
			add_json(fn[:-5], open(os.path.join(DATA, fn), encoding="utf-8").read())
	add_json("Assets", json.dumps({k: v["assetId"] for k, v in record.items() if k.startswith("SW1_") and k != KEY}))
	# MaterialVariants: [name, studs per tile, colour, normal, roughness] (decal asset ids from art-source/uploads.json)
	up_path = os.path.join(ROOT, "art-source", "uploads.json")
	ups = json.load(open(up_path)) if os.path.exists(up_path) else {}
	mats = []
	for name, studs in (("SW_Plaster", 16), ("SW_Floor", 20), ("SW_Steel", 10)):
		ids = [ups.get(f"art-source/lobby/textures/{name}_{m}.png", {}).get("assetId") for m in ("color", "normal", "roughness")]
		if all(ids):
			mats.append([name, studs] + ids)
	add_json("Materials", json.dumps(mats))
	src = open(os.path.join(HERE, "Build_SW1.luau"), encoding="utf-8").read()
	items.append(item("ModuleScript", "Build", f'<ProtectedString name="Source">{escape(src)}</ProtectedString>'))
	xml = ('<roblox version="4"><Item class="Folder" referent="RBX0"><Properties><string name="Name">SW1Data</string></Properties>'
		+ "".join(items) + "</Item></roblox>")
	with open(OUT, "w", encoding="utf-8", newline="\n") as f:
		f.write(xml)
	return len(items), len(xml)


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("--group", type=str)
	ap.add_argument("--user", type=str)
	args = ap.parse_args()
	if not (args.group or args.user):
		sys.exit("pass --group or --user")
	creator = {"groupId": args.group} if args.group else {"userId": args.user}
	record_path = os.path.join(EXPORTS, "assets.json")
	record = json.load(open(record_path)) if os.path.exists(record_path) else {}
	n, size = build_rbxmx(record)
	existing = record.get(KEY)
	if existing:
		meta = {"assetId": str(existing["assetId"])}
		body, ctype = U.multipart({"request": json.dumps(meta)}, "fileContent", OUT, "model/x-rbxm")
		op = U.request("PATCH", f"{U.API}/assets/{existing['assetId']}", body, ctype)
	else:
		meta = {"assetType": "Model", "displayName": "GG_Lobby_SW1_Data", "description": "GlitchedGauntletGame Sunwell Works build data",
			"creationContext": {"creator": creator}}
		body, ctype = U.multipart({"request": json.dumps(meta)}, "fileContent", OUT, "model/x-rbxm")
		op = U.request("POST", f"{U.API}/assets", body, ctype)
	resp = U.poll(op["path"]) if "path" in op and not op.get("done") else op.get("response", op)
	asset_id = int(resp.get("assetId") or resp.get("path", "").split("/")[-1])
	record[KEY] = {"assetId": asset_id, "uploaded": time.strftime("%Y-%m-%d %H:%M:%S")}
	with open(record_path, "w") as f:
		json.dump(record, f, indent=1, sort_keys=True)
	print(f"{KEY}: {asset_id} ({n} items, {size // 1024} KB)")


if __name__ == "__main__":
	main()
