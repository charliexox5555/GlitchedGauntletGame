#!/usr/bin/env python3
"""Compact Studio call for a theme kit (maps overnight run, 2026-11-16).

    python tools/maps/kit_compact.py <Kit>      -> prints the Luau call for ServerStorage.MapTools.InstallKit

Reads art-source/maps/<Kit>/Exports/Kit.json (export_lobby_kit) and assets.json (upload_models --maps <Kit>).
Same result as tools/studio/maps/kit_bundle.py, a fraction of the paste.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
kit = sys.argv[1]
ex = ROOT / "art-source/maps" / kit / "Exports"
data = json.loads((ex / "Kit.json").read_text(encoding="utf-8"))
asset = json.loads((ex / "assets.json").read_text(encoding="utf-8"))["Kit"]["assetId"]
rows = []
for p in data["parts"]:
    look = p.get("look") or {"material": "SmoothPlastic", "color": "9EA2AA"}
    c = p["center"]
    rows.append('{"%s","%s","%s","%s",%g,%g,%g,%g}' % (p["piece"], p["name"], look["color"], look["material"], c[0], c[1], c[2], max(p["size"])))
print('return require(game.ServerStorage.MapTools.InstallKit)("%s", %d, {%s})' % (kit, asset, ",".join(rows)))
