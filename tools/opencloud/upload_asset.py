"""Upload one audio, image, animation or model file to Roblox with the Open Cloud Assets API.

    python tools/opencloud/upload_asset.py --group 11116787 --type Audio  art-source/audio/GunAtlas.wav "GG Gun Sound Atlas"
    python tools/opencloud/upload_asset.py --group 11116787 --type Decal  art-source/vfx/out/flash.png  "GG VFX Flash"
    python tools/opencloud/upload_asset.py --group 11116787 --type Animation art-source/animations/GG_Slide.rbxm "GG Slide"
    python tools/opencloud/upload_asset.py --group 11116787 --type Model art-source/viewmodel/Arms.fbx "GG Viewmodel Arms"

Key from ROBLOX_ASSETS_KEY. Records results in art-source/uploads.json
(keyed by file path) and prints the asset id. Audio quota: 10/month
without ID verification, so the game packs sounds into one atlas.
"""

import argparse
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))
from upload_models import API, multipart, poll, request  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RECORD = os.path.join(ROOT, "art-source", "uploads.json")

CONTENT_TYPES = {
	".wav": "audio/wav",
	".mp3": "audio/mpeg",
	".ogg": "audio/ogg",
	".flac": "audio/flac",
	".png": "image/png",
	".jpg": "image/jpeg",
	".jpeg": "image/jpeg",
	".tga": "image/tga",
	# Animations: a Studio-serialized KeyframeSequence (tools/studio/MakePoseAnimations.luau).
	".rbxm": "model/x-rbxm",
	".fbx": "model/fbx",
}


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("--group", type=str, required=True)
	ap.add_argument("--type", choices=["Audio", "Decal", "Animation", "Model"], required=True)
	ap.add_argument("file")
	ap.add_argument("name")
	args = ap.parse_args()
	path = os.path.abspath(args.file)
	ctype = CONTENT_TYPES[os.path.splitext(path)[1].lower()]
	meta = {
		"assetType": args.type,
		"displayName": args.name,
		"description": "GlitchedGauntletGame asset",
		"creationContext": {"creator": {"groupId": args.group}},
	}
	body, mp = multipart({"request": json.dumps(meta)}, "fileContent", path, ctype)
	op = request("POST", f"{API}/assets", body, mp)
	resp = poll(op["path"]) if "path" in op and not op.get("done") else op.get("response", op)
	asset_id = int(resp.get("assetId") or resp.get("path", "").split("/")[-1])
	record = json.load(open(RECORD)) if os.path.exists(RECORD) else {}
	rel = os.path.relpath(path, ROOT).replace("\\", "/")
	record[rel] = {"assetId": asset_id, "type": args.type, "name": args.name, "uploaded": time.strftime("%Y-%m-%d %H:%M:%S")}
	with open(RECORD, "w") as f:
		json.dump(record, f, indent=1, sort_keys=True)
	print(asset_id)


if __name__ == "__main__":
	main()
