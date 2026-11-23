"""Audit every saved Shop and Locker model against the shipped art registries.

Run from the repository with python tools/render/audit_shop_art.py.
The Studio companion also checks models added to the live manifest since its last export.
"""
import json
import re
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8-sig")


def ids(module):
    return {
        name: int(asset)
        for name, asset in re.findall(r'\["([\w/]+)"\]\s*=\s*"rbxassetid://(\d+)"', module)
    }


roster = set()
for row in read("tools/render/portrait-lists/round2_shop_sides.txt").splitlines():
    for name in row.split(";"):
        parts = name.split("/")
        if parts[0] == "Weapons":
            roster.add((parts[1], "Stock"))
        elif parts[0] == "WeaponSkins":
            roster.add((parts[2], parts[1]))
for export in ("LobbySkins", "MatchSkins"):
    for row in read(f"src/shared/Config/AssetData/{export}.luau").splitlines():
        if '["SkinReady"] = true' in row:
            match = re.search(r"\.WeaponSkins\.(\w+)\.(\w+)\s*$", row)
            if match:
                line, gun = match.groups()
                roster.add((gun, line))

icons = ids(read("src/shared/ItemIcons.luau"))
portraits = ids(read("src/shared/ItemPortraits.luau"))
locker = read("src/shared/Locker.luau").split("Locker.EMBLEMS = table.freeze({", 1)[1].split("})", 1)[0]
emblems = {
    line: int(asset)
    for line, asset in re.findall(r'(\w+)\s*=\s*"rbxassetid://(\d+)"', locker)
}
ledger = json.loads(read("art-source/uploads.json"))
direct = {entry["assetId"]: path for path, entry in ledger.items() if entry.get("type") == "Image"}
problems = []
for gun, line in sorted(roster):
    key = f"{gun}/{line}"
    art = icons.get(key)
    portrait_key = "Knife/PopCircuit" if key == "Bat/PopCircuit" else key
    pair = [("Locker icon", art, 1024)]
    if line != "Stock":
        pair.append(("Shop portrait", portraits.get(portrait_key), 768))
    for purpose, identifier, minimum in pair:
        if not identifier:
            problems.append(f"{purpose} missing: {key}")
            continue
        file = direct.get(identifier)
        if not file or not (ROOT / file).is_file():
            problems.append(f"{purpose} lacks a local HD source: {key}")
            continue
        with Image.open(ROOT / file) as image:
            size_ok = image.width == minimum if purpose == "Locker icon" else 768 <= image.width == image.height <= 1024
            if not size_ok or image.mode != "RGBA" or image.getchannel("A").getextrema() != (0, 255):
                problems.append(f"{purpose} has bad size or transparency: {key} ({image.size})")

lines = {line for _, line in roster}
for line in sorted(lines):
    if line not in emblems:
        problems.append(f"Collection emblem missing: {line}")
        continue
    slug = "default" if line == "Stock" else line.lower()
    file = ROOT / f"art-source/ui/collection-emblems/emblem_{slug}.png"
    if not file.is_file():
        problems.append(f"Collection emblem lacks a source: {line}")
        continue
    with Image.open(file).convert("RGBA") as image:
        if image.width != image.height or image.width < 256 or image.getchannel("A").getextrema() != (0, 255):
            problems.append(f"Collection emblem has bad size or transparency: {line}")

catalog = read("src/lobby/shared/ShopCatalog.luau")
for asset, filename in re.findall(r'hero\s*=\s*"rbxassetid://(\d+)",\s*--.*?/(hero_\w+\.png)', catalog):
    file = direct.get(int(asset))
    if not file or not (ROOT / file).is_file():
        problems.append(f"Missing HD bundle hero: {filename}")
        continue
    with Image.open(ROOT / file) as image:
        if image.width != 1600 or image.mode != "RGBA" or image.getchannel("A").getextrema() != (0, 255):
            problems.append(f"Bundle hero has bad size or transparency: {filename}")

stock = sum(line == "Stock" for _, line in roster)
print(f"Checked {stock} stock guns, {len(roster) - stock} skins, {len(lines)} collection badges.")
for message in problems:
    print(message)
print(f"{len(problems)} findings")
raise SystemExit(bool(problems))
