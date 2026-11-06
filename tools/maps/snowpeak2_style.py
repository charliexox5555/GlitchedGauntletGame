#!/usr/bin/env python3
"""Snowpeak2 style: the map's palette, materials, MaterialVariants and lighting in one place
(vault/01 Design/Maps/Snowpeak2.md -> Palette; the pattern of tools/maps/bunker2_style.py).

The Blender kit (tools/blender/build_map_kit_snowpeak2.py) builds its materials from MATS here (name -> colour,
Roblox material, variant), so the export carries the look of every part and kit_bundle applies it; Art.luau
creates the VARIANTS in MaterialService and finishes the visible greybox (snow, terrace, floor, ice) by role.

Run: python tools/maps/snowpeak2_style.py [--luau]   (rewrites the STYLE block of tools/studio/maps/Snowpeak2/Art.luau
     and the LIGHT block of Lighting.luau)
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# ---------------------------------------------------------------- identity
# "A warm timber lodge in a cold, bright saddle": honey-brown timber on a grey fieldstone plinth, dark standing-seam
# roofs under thick snow, amber light in every window, the red gondola cabins as the one hot accent, blue-white snow
# with soft shade, under a clear morning sky. Sides read by tone on the patrol huts and stations (B blue, A gold).

# Kit material name -> (hex, Roblox material, MaterialVariant). Names match the old kit's material keys.
MATS: dict[str, tuple[str, str, str]] = {
    "Snow": ("EEF2F8", "Snow", "Snow2_Snow"),
    "SnowShade": ("DCE4EE", "Snow", "Snow2_Snow"),
    "Timber": ("8A5E3C", "WoodPlanks", "Snow2_Timber"),  # honey larch (the concept's warm wall)
    "TimberDark": ("5A3C28", "WoodPlanks", "Snow2_Timber"),  # frames, posts, bargeboards
    "TimberLight": ("A8805A", "WoodPlanks", "Snow2_Timber"),
    "Oak": ("9A7450", "WoodPlanks", "Snow2_Plank"),  # deck boards
    "Stone": ("9A9388", "Cobblestone", "Snow2_Stone"),
    "StoneDark": ("6E6962", "Cobblestone", "Snow2_Stone"),
    "RoofSlate": ("4A535E", "Plastic", "Snow2_Roof"),  # standing-seam metal (Plastic base: no sky mirror)
    "Shutter": ("4A6650", "WoodPlanks", "Snow2_Timber"),
    "Concrete": ("A7A6A2", "Concrete", ""),
    "Steel": ("5E656D", "Plastic", ""),  # no Roblox Metal on painted steel
    "SteelDark": ("3E444B", "Plastic", ""),
    "Red": ("A8262E", "SmoothPlastic", ""),  # gondola red, the hero accent (far from team orange-red FF5A36)
    "White": ("D9DCDF", "SmoothPlastic", ""),
    "Rubber": ("38393C", "SmoothPlastic", ""),
    "Rock": ("A0A5AC", "Rock", "Snow2_Rock"),  # r4: lighter (blue shade read near-black)
    "RockDark": ("5E656E", "Rock", "Snow2_Rock"),
    "Boulder": ("B4B8BE", "Slate", ""),  # r4: Codex boulders (their small UVs made the rock variant read near-black)
    "Needles": ("2E4A3A", "Grass", ""),
    "Bark": ("5A4030", "Wood", ""),
    "Fabric": ("7A3B2E", "Fabric", ""),
    "Rug": ("8C4A32", "Fabric", ""),
    "Leather": ("5C3A28", "Leather", ""),
    "Brass": ("A8864A", "Metal", ""),
    "Iron": ("3A3937", "Plastic", ""),
    "MapBoard": ("E6E1D3", "SmoothPlastic", ""),
    "Ice": ("C9DDEA", "Ice", ""),  # icicles
}
GLASS = {"Glass": "B5C8D4", "CabGlass": "2A3440", "Bottle": "5C7A3A"}
# Neon: Roblox brightens Neon hugely; these dark values render as warm amber / fire (calibrated on Bunker2).
GLOW = {"Glow_Warm": "8C7660", "Glow_Fire": "A0502A", "Glow_Amber": "9C7A40"}  # r1: B07A48 rendered saturated yellow outdoors; desaturated warm reads as lamplight
END = {"B": "3D63A8", "A": "C9962E"}  # end paint (patrol huts, station bands)

# Greybox finishes in Studio (the parts that stay visible).
GREYBOX = {
    "ground": ("EEF2F8", "Snow", "Snow2_Snow"),
    "terrace": ("8E8578", "Cobblestone", "Snow2_Stone"),
    "floor": ("9A7450", "WoodPlanks", "Snow2_Plank"),
    "ice": ("B9D6E6", "Ice", ""),
}

VARIANTS = {
    "Snow2_Timber": ("WoodPlanks", 8, "132419806158171", "127590838417035", ""),
    "Snow2_Stone": ("Cobblestone", 8, "117006718223711", "123215852189966", ""),
    "Snow2_Snow": ("Snow", 16, "114271398131937", "111098192335248", ""),
    "Snow2_Roof": ("Plastic", 8, "80711795927408", "74968368388868", ""),
    "Snow2_Rock": ("Rock", 28,  # r4: calmer at backdrop scale
     "72465231073227", "133592237709177", ""),
    "Snow2_Plank": ("WoodPlanks", 8, "72356380118675", "113823686655015", ""),
}

# ---------------------------------------------------------------- lighting (Lighting.luau LIGHT block)
# A clear morning: sun ~37 deg up raking along X (neither team looks into it), cool blue shade, warm light only from
# the lodge, lamps and stations. v4 lesson: bright, not dark; snow keeps detail (exposure a touch under 0).
LIGHTING = {
    "ClockTime": 8.2,  # r3: a lower, warmer morning sun (reviewers: flat noon light)
    "GeographicLatitude": 0,
    "Brightness": 2.8,
    "Ambient": (128, 138, 160),
    "OutdoorAmbient": (182, 190, 210),  # r4: brighter shade fill
    "ColorShift_Top": (255, 206, 160),
    "ColorShift_Bottom": (140, 164, 210),
    "EnvironmentDiffuseScale": 0.5,
    "EnvironmentSpecularScale": 0.3,
    "ExposureCompensation": -0.15,
    "GlobalShadows": True,
    "ShadowSoftness": 0.2,
}
FX = {
    "Atmosphere": {"Density": 0.34, "Offset": 0.12, "Color": (230, 222, 214), "Decay": (140, 160, 200), "Glare": 0.5, "Haze": 1.8},
    "Bloom": {"Intensity": 0.6, "Size": 24, "Threshold": 1.0},
    "Grade": {"Brightness": 0.02, "Contrast": 0.12, "Saturation": 0.04, "TintColor": (250, 250, 255)},
    "SunRays": {"Intensity": 0.05, "Spread": 0.5},
}


def _lua(v) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return f"{v:g}"
    if isinstance(v, tuple) and len(v) == 3:
        return f"Color3.fromRGB({v[0]}, {v[1]}, {v[2]})"
    return json.dumps(v)


def style_block() -> str:
    lines = ["local VARIANTS: { [string]: { any } } = {"]
    for name, (base, tile, cm, nm, rm) in VARIANTS.items():
        lines.append(f'\t{name} = {{ "{base}", {tile}, "{cm}", "{nm}", "{rm}" }},')
    lines.append("}")
    lines.append("local GREYBOX: { [string]: { string } } = {")
    for k, (hx, mat, var) in GREYBOX.items():
        lines.append(f'\t{k} = {{ "{hx}", "{mat}", "{var}" }},')
    lines.append("}")
    lines.append("local END: { [string]: string } = { " + ", ".join(f'{k} = "{v}"' for k, v in END.items()) + " }")
    return "\n".join(lines)


def light_block() -> str:
    lines = ["local PROPS: { [string]: any } = {"]
    for k, v in LIGHTING.items():
        lines.append(f"\t{k} = {_lua(v)},")
    lines.append("}")
    lines.append("local FX: { [string]: { [string]: any } } = {")
    for k, d in FX.items():
        lines.append(f"\t{k} = {{ " + ", ".join(f"{p} = {_lua(v)}" for p, v in d.items()) + " },")
    lines.append("}")
    return "\n".join(lines)


def write_block(rel: str, tag: str, body: str) -> None:
    path = ROOT / rel
    text = path.read_text(encoding="utf-8")
    block = (
        f"-- BEGIN {tag} (generated by tools/maps/snowpeak2_style.py --luau; edit the values there)\n"
        "-- stylua: ignore start\n" + body + "\n-- stylua: ignore end\n" + f"-- END {tag}"
    )
    new, n = re.subn(rf"-- BEGIN {tag}.*?-- END {tag}", lambda m: block, text, flags=re.S)
    assert n == 1, f"no {tag} block in {rel}"
    path.write_text(new, encoding="utf-8", newline="\n")
    print(f"Wrote the {tag} block of {rel}")


if __name__ == "__main__":
    for role, (hx, mat, _v) in MATS.items():
        assert not (mat == "Metal" and role != "Brass"), role
    if "--luau" in sys.argv:
        write_block("tools/studio/maps/Snowpeak2/Art.luau", "STYLE", style_block())
        write_block("tools/studio/maps/Snowpeak2/Lighting.luau", "LIGHT", light_block())
    print("palette ok")
