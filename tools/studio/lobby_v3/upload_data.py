"""Pack the Lobby V3 build data and the build tool into one Roblox model and upload it (Open Cloud).

    python tools/studio/lobby_v3/upload_data.py --group 11116787

Reads art-source/lobby/Exports/V3Data/*.json (written by tools/blender/lobby_v3/lv3_export.py) and
tools/studio/lobby_v3/Build_V3.luau. Writes art-source/lobby/Exports/V3_Data.rbxmx: a Folder "V3Data" holding
StringValues (JSON split into chunks, named <File>__<n>) and a ModuleScript "Build". The asset id is recorded in
art-source/lobby/Exports/assets.json as "V3_Data". In Studio (Edit mode, through the MCP):

    local f = game:GetService("InsertService"):LoadAsset(<id>):FindFirstChild("V3Data", true)
    f.Parent = game.ServerStorage
    local B = require(f.Build:Clone())

This replaces the Rojo-synced copy: the Rojo plugin can stop syncing after a play test, and nothing has to live in src/.
The API key comes from ROBLOX_ASSETS_KEY (see upload_models.py); it is never printed.
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
DATA = os.path.join(EXPORTS, "V3Data")
OUT = os.path.join(EXPORTS, "V3_Data.rbxmx")
CHUNK = 180000


def build_rbxmx():
	items = []
	ref = [0]

	def item(cls, name, prop):
		ref[0] += 1
		return f'<Item class="{cls}" referent="RBX{ref[0]}"><Properties><string name="Name">{name}</string>{prop}</Properties></Item>'

	for fn in sorted(os.listdir(DATA)):
		if not fn.endswith(".json"):
			continue
		text = open(os.path.join(DATA, fn), encoding="utf-8").read()
		for k in range(0, len(text), CHUNK):
			items.append(item("StringValue", f"{fn[:-5]}__{k // CHUNK + 1}", f'<string name="Value">{escape(text[k:k + CHUNK])}</string>'))
	src = open(os.path.join(HERE, "Build_V3.luau"), encoding="utf-8").read()
	items.append(item("ModuleScript", "Build", f'<ProtectedString name="Source">{escape(src)}</ProtectedString>'))
	xml = ('<roblox version="4"><Item class="Folder" referent="RBX0"><Properties><string name="Name">V3Data</string></Properties>'
		+ "".join(items) + "</Item></roblox>")
	with open(OUT, "w", encoding="utf-8", newline="\n") as f:
		f.write(xml)
	return len(items), len(xml)


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("--group", type=str)
	ap.add_argument("--user", type=str)
	args = ap.parse_args()
	creator = {"groupId": args.group} if args.group else {"userId": args.user}
	if not (args.group or args.user):
		sys.exit("pass --group or --user")
	n, size = build_rbxmx()
	record_path = os.path.join(EXPORTS, "assets.json")
	record = json.load(open(record_path)) if os.path.exists(record_path) else {}
	existing = record.get("V3_Data")
	if existing:
		meta = {"assetId": str(existing["assetId"])}
		body, ctype = U.multipart({"request": json.dumps(meta)}, "fileContent", OUT, "model/x-rbxm")
		op = U.request("PATCH", f"{U.API}/assets/{existing['assetId']}", body, ctype)
	else:
		meta = {"assetType": "Model", "displayName": "GG_Lobby_V3_Data", "description": "GlitchedGauntletGame lobby V3 build data",
			"creationContext": {"creator": creator}}
		body, ctype = U.multipart({"request": json.dumps(meta)}, "fileContent", OUT, "model/x-rbxm")
		op = U.request("POST", f"{U.API}/assets", body, ctype)
	resp = U.poll(op["path"]) if "path" in op and not op.get("done") else op.get("response", op)
	asset_id = int(resp.get("assetId") or resp.get("path", "").split("/")[-1])
	record["V3_Data"] = {"assetId": asset_id, "uploaded": time.strftime("%Y-%m-%d %H:%M:%S")}
	with open(record_path, "w") as f:
		json.dump(record, f, indent=1, sort_keys=True)
	print(f"V3_Data: {asset_id} ({n} items, {size // 1024} KB)")


if __name__ == "__main__":
	main()
