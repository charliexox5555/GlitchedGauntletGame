#!/usr/bin/env python3
"""Bunker2 style: every colour, material, bevel and lighting value of the map in one place
(vault/01 Design/Maps/Bunker2.md -> Palette; the pattern of tools/maps/dockyard2_style.py).

  * Colours, Roblox materials and MaterialVariants are applied in Studio by role (Art.luau STYLE block), so a palette
    change is: edit PALETTE / BAND here, run `python tools/maps/bunker2_style.py --luau`, rerun the Art + Lighting
    bundle. No Blender, no upload.
  * Lighting values (LIGHTING, FX, LAMP) go the same way into Lighting.luau's LIGHT block.
  * Bevels (BEVEL) are geometry: change them here and rebuild + re-upload the kit.
The Blender kit (tools/blender/build_map_kit_bunker2.py) names its materials B2_<Role> from PALETTE, so its renders use
the same colours and the export carries the role of every part.

Run: python tools/maps/bunker2_style.py [--luau] [--svg]
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# ---------------------------------------------------------------- identity
# "A warm concrete shelter around one hot column of sunlight": warm board-formed concrete over olive bunker paint, dark
# painted steel structure, brass as the one warm metal, warm coves, and one gold landmark (the plinth cap in the sun).
# Sides read by tone: cobalt band at the B end, amber band at the A end, none in the shared middle.

# Roles: hex colour, Roblox material, MaterialVariant ("" = none). Kit materials are named B2_<Role>.
PALETTE: dict[str, tuple[str, str, str]] = {
    # big textured surfaces
    "Board": ("85817B", "Concrete", "Bunk2_Board"),  # board-formed concrete walls and piers
    "BoardLight": ("96928B", "Concrete", "Bunk2_Board"),  # sunwell, shaft, plinth, beams
    "Ceiling": ("6E6B67", "Concrete", "Bunk2_Floor"),  # precast slabs (tie holes on a ceiling read odd)
    "Olive": ("4C5244", "Plastic", "Bunk2_Paint"),  # lower wall paint
    "Band": ("6F6A62", "Plastic", "Bunk2_Paint"),  # the end band (recoloured per side in Studio from BAND)
    "Floor": ("64615C", "Concrete", "Bunk2_Floor"),  # rooms and corridors
    "FloorSun": ("9A948B", "Concrete", "Bunk2_Floor"),  # sunwell
    "Deck": ("7A766F", "Concrete", "Bunk2_Floor"),  # ring and overlooks
    "Dais": ("A39D93", "Concrete", "Bunk2_Floor"),
    # steel
    "Steel": ("586067", "Plastic", "Bunk2_Steel"),  # frames, headers, beams, doors
    "SteelDark": ("4A5056", "Plastic", "Bunk2_Steel"),  # kick plates, skirts, skids (lifted above lum 0.06)
    "Door": ("656D74", "Plastic", "Bunk2_Steel"),  # door leaves (a step lighter than their frames)
    "Machine": ("62686C", "Plastic", "Bunk2_Steel"),  # r1: brushed read smeary on big housings  # generator and pump housings
    "Pipe": ("6E757A", "Plastic", "Bunk2_Brushed"),
    "Fins": ("4E5458", "SmoothPlastic", ""),  # radiator fins (a value step under the housing)
    # painted props
    "Locker": ("4A5143", "Plastic", "Bunk2_Paint"),
    "LockerDoor": ("535B4B", "Plastic", "Bunk2_Paint"),  # doors a step lighter than the body
    "Case": ("4D5043", "Plastic", "Bunk2_Paint"),  # hard cases
    "Rack": ("4A5056", "Plastic", "Bunk2_Steel"),
    "Console": ("50564C", "Plastic", "Bunk2_Paint"),  # olive-grey desk
    # accents
    "Brass": ("957A48", "SmoothPlastic", ""),  # r2: the brushed texture read as wood grain  # rails, trims, compass, case corners
    "Gold": ("BE9A4C", "SmoothPlastic", ""),  # plinth cap (the landmark)
    "Hazard": ("E2B23E", "SmoothPlastic", ""),
    "Line": ("B9963F", "SmoothPlastic", ""),  # painted floor guide lines (muted amber)
    "Ink": ("2C2E31", "SmoothPlastic", ""),  # hazard stripes' dark, cable sheaths, rubber
    "Rubber": ("484B4F", "SmoothPlastic", ""),
    "Valve": ("B8473A", "SmoothPlastic", ""),  # valve wheels (tiny red, the pump room's story colour)
    "Sign": ("444B52", "SmoothPlastic", ""),  # sign plates (the decal carries the text)
    "Glass": ("BFD9E3", "Glass", ""),
    "Screen": ("1E2A30", "SmoothPlastic", ""),  # screen surround (glass dark)
    # Neon (thin strips only)
    "Cove": ("FFDDB0", "Neon", ""),  # warm cove strips (FFB45A renders saturated yellow in Roblox)
    "Lamp": ("FFF1DC", "Neon", ""),  # v1 r1: FFD49A read as yellow blobs  # cage lamps, bulkheads
    "ScreenGlow": ("3E5C5C", "Neon", ""),  # r2: 5F9FB0 rendered team-cyan  # A6DCEB blew out to white
    "Status": ("D9932F", "Neon", ""),  # tiny LEDs
}

# End bands: the route tone of each half (not a team colour). "N" = the shared middle (no colour, a warm grey).
BAND = {"B": "3A4C78", "A": "A8823F", "N": "6F6A62"}  # v1 r1: textured Plastic renders ~1.4x brighter and warmer than its hex
SIGN_INK = "E9E3D3"

# Reserved, never used on the map: team cyan #00E5FF, team orange-red #FF5A36, glitch magenta #FF3DCB.

# ---------------------------------------------------------------- geometry (Blender kit; rebuild + upload to change)
BEVEL = {
    "concrete": 0.35,  # piers, pilasters, plinth, dais (standard 0.3-0.45)
    "concrete_small": 0.18,  # courses, copings, steps
    "steel": 0.15,  # frames, headers, door leaves (standard 0.12-0.25)
    "steel_small": 0.06,  # bolts, rails' ends, handles
}

# MaterialVariants (match place MaterialService). Near-white colour maps from tools/textures/make_bunker2_textures.py,
# 512, colour + normal, no roughness/metalness map. Ids are the Image assets (resolved from the Decal uploads).
VARIANTS = {
    "Bunk2_Board": ("Concrete", 8, "125457681933017", "119552062112885", ""),
    "Bunk2_Paint": ("Plastic", 8, "127271836059451", "134694574089892", ""),
    "Bunk2_Floor": ("Concrete", 16, "98812008346798", "130734934184874", ""),
    "Bunk2_Steel": ("Plastic", 8, "97931256090766", "122607199786437", ""),
    "Bunk2_Brushed": ("Plastic", 8, "113550128416787", "73423826468490", ""),
    "Bunk2_Brass": ("Plastic", 8, "81611443013894", "87290245097724", ""),
}

# ---------------------------------------------------------------- lighting (Studio; Lighting.luau)
# The sun at the zenith (latitude 23.5, noon) drops straight down the 24-wide shaft onto the dais, the same for both
# teams. Indoors the roofs shade everything else, so Ambient carries the rooms: warm and bright (v4 "too dark").
LIGHTING = {
    "ClockTime": 12,
    "GeographicLatitude": 23.5,
    "Brightness": 3.0,
    "Ambient": (150, 148, 146),  # v1 r1: local lights render in captures; ambient alone reads near-black indoors  # warm shade fill: rooms read at a glance (the v3/v4 maps read dark)
    "OutdoorAmbient": (140, 140, 146),
    "ColorShift_Top": (255, 240, 220),
    "ColorShift_Bottom": (0, 0, 0),
    "EnvironmentDiffuseScale": 0.15,  # the sky must not tint a sealed bunker
    "EnvironmentSpecularScale": 0.1,
    "ExposureCompensation": 0.0,  # v1 r1: 0.2 with a warm ambient read peach and yellow in captures
    "GlobalShadows": True,
    "ShadowSoftness": 0.15,
}
FX = {
    "Atmosphere": {"Density": 0.28, "Offset": 0.0, "Color": (214, 200, 180), "Decay": (120, 112, 102), "Glare": 0.0, "Haze": 1.2},
    "Bloom": {"Intensity": 0.55, "Size": 24, "Threshold": 1.1},
    "Grade": {"Brightness": 0.0, "Contrast": 0.16, "Saturation": -0.08, "TintColor": (255, 250, 244)},
    "SunRays": {"Intensity": 0.07, "Spread": 0.5},
}
LAMP = {"color": (255, 238, 214), "brightness": 0.75, "range": 24}  # v1 r1: 1.6 warm washed every wall peach  # shadowless room lights (few)


def hex_rgb(h: str) -> tuple[int, int, int]:
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def luminance(h: str) -> float:
    def lin(c):
        c = c / 255
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    r, g, b = (lin(c) for c in hex_rgb(h))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


# ---------------------------------------------------------------- outputs

def _lua(v) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return f"{v:g}"
    if isinstance(v, str):
        return json.dumps(v)
    if isinstance(v, tuple) and len(v) == 3:
        return f"Color3.fromRGB({v[0]}, {v[1]}, {v[2]})"
    raise TypeError(v)


def style_block(parts: dict[str, str]) -> str:
    lines = ["local ROLE: { [string]: RoleLook } = {"]
    for role, (hx, mat, var) in PALETTE.items():
        lines.append(f'\t{role} = {{ color = "{hx}", material = "{mat}", variant = "{var}" }},')
    lines.append("}")
    lines.append("local BAND: { [string]: string } = { " + ", ".join(f'{k} = "{v}"' for k, v in BAND.items()) + " }")
    lines.append("local VARIANTS: { [string]: { any } } = {")
    for name, (base, tile, cm, nm, rm) in VARIANTS.items():
        lines.append(f'\t{name} = {{ "{base}", {tile}, "{cm}", "{nm}", "{rm}" }},')
    lines.append("}")
    lines.append("local PART_ROLE: { [string]: string } = {")
    for name in sorted(parts):
        lines.append(f'\t["{name}"] = "{parts[name]}",')
    lines.append("}")
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
    lines.append(f"local LAMP = {{ color = {_lua(LAMP['color'])}, brightness = {LAMP['brightness']:g}, range = {LAMP['range']:g} }}")
    return "\n".join(lines)


def part_roles() -> dict[str, str]:
    path = ROOT / "art-source/maps/Bunker2/Exports/Kit.json"
    if not path.exists():
        print("no kit export yet: PART_ROLE left empty")
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    out = {}
    for p in data["parts"]:
        m = p.get("material") or ""
        if m.startswith("B2_"):
            out[p["name"]] = m[3:]
    return out


def write_block(rel: str, tag: str, body: str) -> None:
    path = ROOT / rel
    text = path.read_text(encoding="utf-8")
    block = (
        f"-- BEGIN {tag} (generated by tools/maps/bunker2_style.py --luau; edit the values there)\n"
        "-- stylua: ignore start\n" + body + "\n-- stylua: ignore end\n" + f"-- END {tag}"
    )
    new, n = re.subn(rf"-- BEGIN {tag}.*?-- END {tag}", lambda m: block, text, flags=re.S)
    assert n == 1, f"no {tag} block in {rel}"
    path.write_text(new, encoding="utf-8", newline="\n")
    print(f"Wrote the {tag} block of {rel}")


def check() -> list[str]:
    bad = []
    for role, (hx, mat, _v) in PALETTE.items():
        if mat == "Metal":
            bad.append(f"{role}: Roblox Metal mirrors the sky")
        if mat != "Neon" and luminance(hx) < 0.06 and role not in ("Screen", "Ink"):
            bad.append(f"{role}: #{hx} is near-black (luminance {luminance(hx):.3f})")
    for team in ("00E5FF", "FF5A36"):
        for role, (hx, _m, _v) in PALETTE.items():
            if hx.upper() == team:
                bad.append(f"{role} uses a team colour")
    return bad


if __name__ == "__main__":
    problems = check()
    for p in problems:
        print("PALETTE:", p)
    if "--luau" in sys.argv:
        write_block("tools/studio/maps/Bunker2/Art.luau", "STYLE", style_block(part_roles()))
        write_block("tools/studio/maps/Bunker2/Lighting.luau", "LIGHT", light_block())
    print("palette ok" if not problems else "palette problems: %d" % len(problems))
