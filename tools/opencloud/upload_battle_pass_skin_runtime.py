"""Upload the regular skin packages, resuming submitted Open Cloud operations."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import threading
import time

from upload_models import API, multipart, request

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art-source/weapons/Skins/Review/Battle Pass/Studio"
RECORD = OUT / "deployment-uploads.json"
MODERATE = OUT.parents[1] / "Moderate/Studio/deployment-uploads.json"
GROUP = "11116787"
LOCK = threading.Lock()


def read(path):
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


def write(path, data):
    temp = path.with_suffix(".tmp")
    temp.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    temp.replace(path)


def dig(path):
    return hashlib.sha256((ROOT / path).read_bytes()).hexdigest()


def upload(kind, path, title, entries):
    checksum = dig(path)
    with LOCK:
        previous = entries.get(checksum, {}).copy()
    if previous.get("id"):
        return previous["id"]
    operation = previous.get("operation")
    if not operation:
        metadata = {"assetType": kind, "displayName": title,
                    "description": "Glitched Gauntlet cosmetic",
                    "creationContext": {"creator": {"groupId": GROUP}}}
        ctype = "model/fbx" if kind == "Model" else "image/png"
        body, mime = multipart({"request": json.dumps(metadata)}, "fileContent", ROOT / path, ctype)
        for retry in range(7):
            try:
                response = request("POST", f"{API}/assets", body, mime)
                break
            except RuntimeError as exc:
                if "HTTP 429:" not in str(exc) or retry == 6:
                    raise
                time.sleep(5 * (retry + 1))
        operation = response["path"]
        previous = {"operation": operation, "type": kind, "path": path}
        with LOCK:
            entries[checksum] = previous
            write(RECORD, entries)
    for attempt in range(100):
        try:
            state = request("GET", f"{API}/operations/{operation.rsplit('/', 1)[-1]}")
        except (RuntimeError, OSError):
            if attempt == 99:
                raise
        else:
            if state.get("done"):
                if "response" not in state:
                    raise RuntimeError(f"Asset operation failed: {path} {state.get('error')}")
                item = state["response"]
                identifier = int(item.get("assetId") or item["path"].rsplit("/", 1)[-1])
                with LOCK:
                    entries[checksum] = {**previous, "id": identifier}
                    write(RECORD, entries)
                print(f"{kind} {title} = {identifier}", flush=True)
                return identifier
        time.sleep(min(5, 1 + attempt))
    raise TimeoutError(f"Pending asset operation {operation} for {path}")


def main():
    arguments = argparse.ArgumentParser()
    arguments.add_argument("targets", nargs="*")
    arguments.add_argument("--workers", type=int, default=6)
    opts = arguments.parse_args()
    jobs = [read(file) for file in sorted(OUT.glob("*_Runtime_*.json"))]
    if opts.targets:
        jobs = [job for job in jobs if f"{job['line']}/{job['item']}" in opts.targets]
        assert len(jobs) == len(opts.targets), "Some requested packages are missing"
    else:
        assert len(jobs) == 35, "Export all runtime packages before uploading"

    stored = read(RECORD)
    prior = read(MODERATE)
    files = {}
    for job in jobs:
        name = f"GG {job['line']} {job['item']}"
        candidates = [(job["file"], "Model", name)]
        candidates += [(path, "Decal", f"{name} {channel}") for channel, path in job["maps"].items()]
        for path, kind, title in candidates:
            digest = dig(path)
            if digest in prior and prior[digest].get("id") and digest not in stored:
                stored[digest] = prior[digest]
            files.setdefault(digest, (kind, path, title))
    write(RECORD, stored)
    failures = []
    with ThreadPoolExecutor(max_workers=opts.workers) as executor:
        work = [(name, executor.submit(upload, kind, path, title, stored))
                for name, (kind, path, title) in files.items()]
        for digest, result in work:
            try:
                result.result()
            except (RuntimeError, OSError, ValueError) as exc:
                failures.append((files[digest][1], str(exc)))
                print("FAILED", failures[-1], flush=True)
    ready = []
    for job in jobs:
        paths = [job["file"], *job["maps"].values()]
        if not all(stored.get(dig(path), {}).get("id") for path in paths):
            continue
        ready.append({**job, "assetId": stored[dig(job["file"])]["id"],
                      "maps": {k: stored[dig(p)]["id"] for k, p in job["maps"].items()}})
    label = "pilot-jobs.json" if opts.targets else "deployment-jobs.json"
    write(OUT / label, ready)
    print(f"{len(ready)}/{len(jobs)} skin packages ready", flush=True)
    if failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
