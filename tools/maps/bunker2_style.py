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
    "Ceiling": ("5E5C59", "SmoothPlastic", ""),  # r5: Roblox Concrete read as brown smudges overhead  # r4: plain (the floor texture read as blotches overhead)  # precast slabs (tie holes on a ceiling read odd)
    "Olive": ("4C5244", "Plastic", "Bunk2_Paint"),  # lower wall paint
    "Band": ("6F6A62", "Plastic", "Bunk2_Paint"),  # the end band (recoloured per side in Studio from BAND)
    "Floor": ("57544F", "Concrete", "Bunk2_Floor"),  # r4: darker, so walls and lamps carry the contrast  # rooms and corridors
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
    "Locker": ("4A5143", "SmoothPlastic", ""),  # r5: clean enamel (the paint texture read lumpy on props)
    "LockerDoor": ("535B4B", "SmoothPlastic", ""),  # doors a step lighter than the body
    "Case": ("4D5043", "SmoothPlastic", ""),  # hard cases
    "Rack": ("4A5056", "Plastic", "Bunk2_Steel"),
    "Console": ("50564C", "SmoothPlastic", ""),  # olive-grey desk
    # accents
    "Brass": ("8A6E40", "Metal", ""),  # r4: real brass sheen indoors (not painted; env specular 0.1)  # r2: the brushed texture read as wood grain  # rails, trims, compass, case corners
    "Gold": ("B08A42", "Metal", ""),  # plinth cap (the landmark)
    "Hazard": ("E2B23E", "SmoothPlastic", ""),
    "Line": ("8E7A4A", "SmoothPlastic", ""),  # painted floor guide lines (muted amber)
    "Ink": ("2C2E31", "SmoothPlastic", ""),  # hazard stripes' dark, cable sheaths, rubber
    "Rubber": ("484B4F", "SmoothPlastic", ""),
    "Valve": ("B8473A", "SmoothPlastic", ""),  # valve wheels (tiny red, the pump room's story colour)
    "Sign": ("444B52", "SmoothPlastic", ""),  # sign plates (the decal carries the text)
    "Glass": ("BFD9E3", "Glass", ""),
    "Screen": ("1E2A30", "SmoothPlastic", ""),  # screen surround (glass dark)
    # Neon (thin strips only)
    "Cove": ("A89A86", "SmoothPlastic", ""),  # r4: unlit light-strip trim (reviewers: flat orange neon); the cage lamps carry the light  # Neon brightens hugely: this renders as an amber cove  # r3: amber (the white strips blew out and read cold; FFB45A goes yellow)  # warm cove strips (FFB45A renders saturated yellow in Roblox)
    "Lamp": ("FFD7A0", "Neon", ""),  # v1 r1: FFD49A read as yellow blobs  # cage lamps, bulkheads
    "ScreenGlow": ("2E4A4E", "Neon", ""),  # r2: 5F9FB0 rendered team-cyan  # A6DCEB blew out to white
    "Status": ("D9932F", "Neon", ""),  # tiny LEDs
}

# End bands: the route tone of each half (not a team colour). "N" = the shared middle (no colour, a warm grey).
BAND = {"B": "34445F", "A": "8F703A", "N": "6F6A62"}  # r3: calmer worn paint  # v1 r1: textured Plastic renders ~1.4x brighter and warmer than its hex
SIGN_INK = "E9E3D3"

# Room identity (r4): the lower-wall paint per room type, so rooms stop looking alike. Keys are the layout's region names.
ROOM_PAINT = {
    "lockers": "4C5244",  # olive
    "control": "485260",  # slate blue-grey
    "pump": "5E4A42",  # oxide red
    "corridor": "50564F",  # grey-green
    "vestibule": "4F5145",
    "spawn": "4C5244",
    "gallery": "4C5244",
    "sunwell": "5A564C",  # warm stone
    "ring": "5A564C",
    "overlook": "4C5244",
}

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
    "Ambient": (84, 82, 80),  # r5: more contrast; the lamp pools carry the rooms  # r3: lower, so the lamp pools and the sunwell carry the light  # v1 r1: local lights render in captures; ambient alone reads near-black indoors  # warm shade fill: rooms read at a glance (the v3/v4 maps read dark)
    "OutdoorAmbient": (120, 118, 116),
    "ColorShift_Top": (255, 240, 220),
    "ColorShift_Bottom": (0, 0, 0),
    "EnvironmentDiffuseScale": 0.15,  # the sky must not tint a sealed bunker
    "EnvironmentSpecularScale": 0.1,
    "ExposureCompensation": 0.15,  # v1 r1: 0.2 with a warm ambient read peach and yellow in captures
    "GlobalShadows": True,
    "ShadowSoftness": 0.15,
}
FX = {
    "Atmosphere": {"Density": 0.28, "Offset": 0.0, "Color": (214, 200, 180), "Decay": (120, 112, 102), "Glare": 0.0, "Haze": 1.2},
    "Bloom": {"Intensity": 0.55, "Size": 24, "Threshold": 1.1},
    "Grade": {"Brightness": 0.0, "Contrast": 0.16, "Saturation": -0.08, "TintColor": (255, 250, 244)},
    "SunRays": {"Intensity": 0.07, "Spread": 0.5},
}
LAMP = {"color": (255, 214, 168), "brightness": 0.8, "range": 14}  # r5: 1.6 blew the sunwell out  # r3: a warm pool at every cage lamp  # v1 r1: 1.6 warm washed every wall peach  # shadowless room lights (few)


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
    lines.append("local ROOM_PAINT: { [string]: string } = { " + ", ".join(f'{k} = "{v}"' for k, v in ROOM_PAINT.items()) + " }")
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
        if mat == "Metal" and role not in ("Brass", "Gold"):  # unpainted brass may be Metal indoors
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
