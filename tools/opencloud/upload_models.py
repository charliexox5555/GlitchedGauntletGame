"""Upload exported gun FBX files to Roblox with the Open Cloud Assets API.

Usage:
    python tools/opencloud/upload_models.py [--group 11116787 | --user <id>] [Id ...]

Reads the API key from the ROBLOX_ASSETS_KEY environment variable (never
from a file in the repo, never printed). Needs the key's "assets" API with
read + write. Uploads art-source/weapons/Exports/<Id>.fbx, polls the
operation until it finishes and records asset IDs in
art-source/weapons/Exports/assets.json. Already-uploaded guns are updated
in place (new version) instead of creating a duplicate asset.
"""

import argparse
import json
import mimetypes
import os
import sys
import time
import urllib.error
import urllib.request
import uuid

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
EXPORTS = os.path.join(ROOT, "art-source", "weapons", "Exports")
RECORD = os.path.join(EXPORTS, "assets.json")
API = "https://apis.roblox.com/assets/v1"


def api_key():
	key = os.environ.get("ROBLOX_ASSETS_KEY")
	if not key:
		sys.exit("ROBLOX_ASSETS_KEY is not set")
	return key


def multipart(fields, file_field, file_path, content_type):
	boundary = uuid.uuid4().hex
	parts = []
	for name, value in fields.items():
		parts.append(
			f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode()
		)
	with open(file_path, "rb") as f:
		blob = f.read()
	parts.append(
		(
			f'--{boundary}\r\nContent-Disposition: form-data; name="{file_field}"; '
			f'filename="{os.path.basename(file_path)}"\r\nContent-Type: {content_type}\r\n\r\n'
		).encode()
		+ blob
		+ b"\r\n"
	)
	parts.append(f"--{boundary}--\r\n".encode())
	return b"".join(parts), f"multipart/form-data; boundary={boundary}"


def request(method, url, body=None, content_type=None):
	req = urllib.request.Request(url, data=body, method=method)
	req.add_header("x-api-key", api_key())
	if content_type:
		req.add_header("Content-Type", content_type)
	try:
		with urllib.request.urlopen(req, timeout=120) as resp:
			return json.loads(resp.read() or b"{}")
	except urllib.error.HTTPError as e:
		detail = e.read().decode(errors="replace")[:500]
		raise RuntimeError(f"{method} {url} -> HTTP {e.code}: {detail}") from None


def poll(operation_path):
	op_id = operation_path.split("/")[-1]
	for attempt in range(60):
		op = request("GET", f"{API}/operations/{op_id}")
		if op.get("done"):
			if "response" in op:
				return op["response"]
			raise RuntimeError(f"operation failed: {json.dumps(op)[:500]}")
		time.sleep(min(2 + attempt, 10))
	raise RuntimeError(f"operation {op_id} timed out")


def upload(gid, creator, record):
	path = os.path.join(EXPORTS, gid + ".fbx")
	if not os.path.exists(path):
		raise RuntimeError(f"missing {path}")
	existing = record.get(gid)
	if existing:
		meta = {"assetId": str(existing["assetId"])}
		body, ctype = multipart({"request": json.dumps(meta)}, "fileContent", path, "model/fbx")
		op = request("PATCH", f"{API}/assets/{existing['assetId']}", body, ctype)
	else:
		meta = {
			"assetType": "Model",
			"displayName": f"GG_{gid}",
			"description": f"GlitchedGauntletGame weapon mesh: {gid}",
			"creationContext": {"creator": creator},
		}
		body, ctype = multipart({"request": json.dumps(meta)}, "fileContent", path, "model/fbx")
		op = request("POST", f"{API}/assets", body, ctype)
	resp = poll(op["path"]) if "path" in op and not op.get("done") else op.get("response", op)
	asset_id = resp.get("assetId") or resp.get("path", "").split("/")[-1]
	return {"assetId": int(asset_id), "uploaded": time.strftime("%Y-%m-%d %H:%M:%S")}


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("--group", type=str)
	ap.add_argument("--user", type=str)
	ap.add_argument("ids", nargs="*")
	args = ap.parse_args()
	creator = {"groupId": args.group} if args.group else {"userId": args.user}
	if not (args.group or args.user):
		sys.exit("pass --group or --user")
	record = json.load(open(RECORD)) if os.path.exists(RECORD) else {}
	ids = args.ids or sorted(f[:-4] for f in os.listdir(EXPORTS) if f.endswith(".fbx"))
	failed = []
	for gid in ids:
		try:
			record[gid] = upload(gid, creator, record)
			print(f"{gid}: {record[gid]['assetId']}")
		except Exception as e:  # keep going, report at the end
			failed.append(gid)
			print(f"{gid}: FAILED {e}")
		with open(RECORD, "w") as f:
			json.dump(record, f, indent=1, sort_keys=True)
	if failed:
		sys.exit(f"failed: {', '.join(failed)}")


if __name__ == "__main__":
	main()
