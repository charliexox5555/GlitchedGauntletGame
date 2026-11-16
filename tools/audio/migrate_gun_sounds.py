"""Export the current game audio as standalone private assets and record their IDs.

    python -I tools/audio/migrate_gun_sounds.py export
    python -I tools/audio/migrate_gun_sounds.py upload --limit 1
    python -I tools/audio/migrate_gun_sounds.py generate

The source atlas, exported WAVs, and resumable upload ledger are git-ignored.
Only confirmed asset IDs and their playback metadata are emitted into Luau.
"""

import argparse
import csv
import hashlib
import json
from pathlib import Path
import re
import sys

import numpy as np
import soundfile as sf

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / "opencloud"))
import build_pro_atlas as atlas
from upload_models import API, multipart, poll, request

ROOT = Path(atlas.ROOT)
OUT = Path(atlas.OUT) / "standalone"
QUEUE = OUT / "queue.json"
LEDGER = OUT / "uploads.json"
LUAU = {
    "gun": ROOT / "src/shared/Config/GunSoundAssets.luau",
    "shared": ROOT / "src/shared/Config/SharedSoundAssets.luau",
}
GROUP = "11116787"
FOOTSTEPS = tuple(f"step_{surface}" for surface in ("concrete", "metal", "wood", "grass", "gravel"))
RIFLE = "gun_semi_auto_rifle_shot_"
PRIORITY = (
    RIFLE + "00_first_01",
    RIFLE + "00_tail_only_01",
    RIFLE + "00_last_with_tail_01",
    *(RIFLE + f"{n:02d}" for n in range(1, 9)),
)


def read_json(path, default=None):
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else default


def save_json(path, data):
    temp = path.with_suffix(".tmp")
    temp.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    temp.replace(path)


def active_names():
    weapons = set(FOOTSTEPS)
    shared = set()
    for slots in atlas.mapping(atlas.weapons()).values():
        for sound in slots.values():
            content = sound["id"]
            if content.startswith("gun:"):
                weapons.update(content.removeprefix("gun:").split("|"))
    for path in (ROOT / "src").rglob("*.luau"):
        for line in path.read_text(encoding="utf-8-sig").splitlines():
            code = line.split("--", 1)[0]
            for value in re.findall(r'"gun:([^"]+)"', code):
                weapons.update(value.split("|"))
            for value in re.findall(r'"(?:atlas|sfx):([^"]+)"', code):
                shared.update(value.split("|"))
    return [*PRIORITY, *sorted(weapons.difference(PRIORITY))], sorted(shared)


def export():
    OUT.mkdir(parents=True, exist_ok=True)
    weapons, shared = active_names()
    meta = read_json(Path(atlas.OUT_JSON))
    game = ROOT / "art-source/audio/GameAtlas.flac"
    # Cues that exist only as standalone files (not atlas regions; made by
    # tools/audio/hit_candidates.py final, 2026-11-15) are kept as they are.
    kept = [item for item in (read_json(QUEUE) or []) if item.get("standalone")]
    kept_cues = {item["cue"] for item in kept}
    weapons = [name for name in weapons if name not in kept_cues]
    queue = export_bank("gun", weapons, atlas.OUT_AUDIO, meta["regions"], meta["gains"])
    queue.extend(kept)
    queue.extend(export_bank("shared", shared, game, read_json(game.with_suffix(".json")), {}))
    save_json(QUEUE, queue)
    print(f"Exported {len(queue)} independent WAVs to {OUT}", flush=True)


def export_bank(bank, names, audio, regions_by_name, gains):
    source, rate = sf.read(audio, dtype="int16", always_2d=True)
    assert rate == 48000 and source.shape[1] == 2
    queue = []
    for name in names:
        regions = regions_by_name[name]
        for index, region in enumerate(regions, 1):
            first = round(region["start"] * rate)
            last = round((region["start"] + region["length"]) * rate)
            assert 0 <= first < last <= len(source), (name, index)
            stem = f"{name}-{index:02d}" if len(regions) > 1 else name
            path = OUT / (stem + ".wav")
            samples = source[first:last]
            sf.write(path, samples, rate, subtype="PCM_16")
            written, written_rate = sf.read(path, dtype="int16", always_2d=True)
            assert written_rate == rate and np.array_equal(samples, written), stem
            queue.append({
                "bank": bank,
                "cue": name,
                "variant": index,
                "filename": path.name,
                "duration": len(samples) / rate,
                "gain": gains.get(name, 1.0),
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            })
    return queue


def upload(limit, names):
    queue = read_json(QUEUE)
    ledger = read_json(LEDGER, {})
    completed = 0
    for item in queue:
        if names and item["cue"] not in names:
            continue
        key = item["filename"]
        existing = ledger.get(key)
        if existing and existing["sha256"] != item["sha256"]:
            raise RuntimeError(f"Export changed after submission: {key}")
        if existing and existing.get("assetId"):
            continue
        if limit is not None and completed >= limit:
            break
        if existing and existing.get("path"):
            response = poll(existing["path"])
        else:
            if existing:
                raise RuntimeError(f"Previous submission outcome is unknown for {key}. Confirm its asset ID before resuming.")
            source = OUT / key
            if hashlib.sha256(source.read_bytes()).hexdigest() != item["sha256"]:
                raise RuntimeError(f"File changed after export: {key}")
            name = f"GG {Path(key).stem}"
            if len(name) > 50:
                name = f"{name[:41]}-{item['sha256'][:8]}"
            payload = {
                "assetType": "Audio",
                "displayName": name,
                "description": "Private GlitchedGauntletGame audio",
                "creationContext": {"creator": {"groupId": GROUP}},
            }
            body, content_type = multipart(
                {"request": json.dumps(payload)}, "fileContent", str(source), "audio/wav"
            )
            print(f"Submitting {key} ({item['duration']:.3f} s)", flush=True)
            ledger[key] = {"sha256": item["sha256"], "state": "submitting"}
            save_json(LEDGER, ledger)
            try:
                operation = request("POST", f"{API}/assets", body, content_type)
            except RuntimeError as error:
                status = re.search(r"HTTP (4\d\d):", str(error))
                if status and status.group(1) != "408":
                    del ledger[key]
                    save_json(LEDGER, ledger)
                raise
            if operation.get("path") and not operation.get("done"):
                ledger[key] = {"path": operation["path"], "sha256": item["sha256"]}
                save_json(LEDGER, ledger)
                response = poll(operation["path"])
            else:
                response = operation.get("response", operation)
        asset_id = int(response.get("assetId") or response["path"].split("/")[-1])
        ledger[key] = {
            "assetId": asset_id, "sha256": item["sha256"],
            "group": GROUP, "moderation": response.get("moderationResult", {}),
        }
        save_json(LEDGER, ledger)
        completed += 1
        print(f"{key} -> {asset_id}", flush=True)


def generate(require_complete):
    queue = read_json(QUEUE)
    ledger = read_json(LEDGER, {})
    if require_complete:
        weapons, shared = active_names()
        expected = {("gun", cue) for cue in weapons} | {("shared", cue) for cue in shared}
        exported = {(item.get("bank", "gun"), item["cue"]) for item in queue}
        if missing := expected - exported:
            raise RuntimeError(f"Export the newly referenced cues first: {sorted(missing)}")
    assets = {"gun": {}, "shared": {}}
    rows = []
    for item in queue:
        entry = ledger.get(item["filename"], {})
        if not entry.get("assetId"):
            continue
        assert entry["sha256"] == item["sha256"], item["filename"]
        bank = item.get("bank", "gun")
        assets[bank].setdefault(item["cue"], []).append(
            (item["variant"], entry["assetId"], item["duration"], item["gain"])
        )
        rows.append((bank, item["cue"], item["variant"], f'rbxassetid://{entry["assetId"]}', item["duration"]))
    if require_complete and len(rows) != len(queue):
        raise RuntimeError(f"{len(queue) - len(rows)} takes still need confirmed IDs")
    for bank, path in LUAU.items():
        write_luau(path, assets[bank])
    with (OUT / "Sound IDs.tsv").open("w", encoding="utf-8", newline="") as output:
        writer = csv.writer(output, delimiter="\t")
        writer.writerow(("Bank", "Cue", "Take", "SoundId", "Seconds"))
        writer.writerows(rows)
    print(f"Mapped {len(rows)} of {len(queue)} takes")


def write_luau(path, assets):
    lines = [
        "--!strict",
        "-- Generated by tools/audio/migrate_gun_sounds.py. Private group audio IDs.",
        "export type Take = { asset: string, length: number, gain: number }",
        "local assets: { [string]: { [number]: Take } } = {",
    ]
    for name, takes in sorted(assets.items()):
        lines.append(f'\t["{name}"] = {{')
        for idx, asset_id, duration, gain in takes:
            lines.append(
                f'\t\t[{idx}] = {{ asset = "rbxassetid://{asset_id}", '
                f'length = {duration:.6f}, gain = {gain:.6f} }},'
            )
        lines.append("\t},")
    lines += ["}", "", "return table.freeze(assets)", ""]
    path.write_text("\n".join(lines), encoding="utf-8", newline="\n")


if __name__ == "__main__":
    cli = argparse.ArgumentParser()
    cli.add_argument("command", choices=["export", "upload", "generate"])
    cli.add_argument("--limit", type=int)
    cli.add_argument("--cue", action="append", default=[])
    cli.add_argument("--require-complete", action="store_true")
    args = cli.parse_args()
    if args.command == "export":
        export()
    elif args.command == "upload":
        upload(args.limit, set(args.cue))
    else:
        generate(args.require_complete)
