#!/usr/bin/env python3
"""Rooftops2 style: every colour, material, bevel and lighting value of the map in one place.

Same scheme as tools/maps/dockyard2_style.py (vault/01 Design/Maps/Rooftops2.md -> Restyle parameters):
  * colours, Roblox materials and MaterialVariants are applied in Studio by role (the STYLE block of
    tools/studio/maps/Rooftops2/Art.luau), so a palette change is: edit PALETTE / TONE here, run
        python tools/maps/rooftops2_style.py --luau
    and rerun the Art + Lighting bundle in Studio. No Blender, no upload.
  * LIGHTING / FX / LAMP go into the LIGHT block of tools/studio/maps/Rooftops2/Lighting.luau.
  * BEVEL / SEGMENTS are geometry: rebuild the Blender kit (tools/blender/build_map_kit_rooftops2.py), export,
    upload, reinstall.

Run: python tools/maps/rooftops2_style.py [--luau] [--svg]
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAP = "Rooftops2"

# ---------------------------------------------------------------- identity
# "Sunny terracotta rooftops at golden afternoon": a warm city of plaster blocks (apricot for team A, sage for team
# B, cream for the towers and the Pit building), terracotta tile roofs, white trims and one cobalt accent (the water
# tank, the awnings, the sign plates). Dockyard2 is a sand-and-yellow harbour, the Lobby a dark concrete bunker; this
# is warmer and rosier than both with a blue spike. Team colours (cyan, orange-red) and glitch magenta stay off it.
# Lessons from Dockyard2 built in from the start: no Roblox Metal on painted surfaces (it mirrors the sky), clean
# SmoothPlastic paint with the geometry carrying the detail, signage plates and painted words for wayfinding, warm
# practical glow strips, a neutral-cool shade against a warm sun.

PALETTE: dict[str, tuple[str, str, str]] = {
    # big calm surfaces
    "Roof": ("B5735A", "Slate", "Roof2_Tile"),  # team-roof tiles (the ground band)
    "RoofPit": ("B3A48C", "Slate", "Roof2_Gravel"),  # maps v4: lighter (the Pit read crushed dark under the trestles)  # the Pit's floor: tar and gravel (concept pass 2026-11-05)
    # Round 1: SmoothPlastic, not the Lobby concrete variant (its dark colour map made the plaster read as brick).
    "Wall": ("D4B98F", "Concrete", "Roof2_Plaster"),  # facades (tinted per building from TONE); our plaster row
    "Plinth": ("A8977F", "Concrete", "Roof2_Plaster"),  # street storey, hut plinths
    # clean SmoothPlastic trims
    "Trim": ("F2EEE4", "SmoothPlastic", ""),  # cornices, sills, frames, coping
    "Ledge": ("C9BFAE", "SmoothPlastic", ""),  # alley ledges and sills
    "Charcoal": ("3A3F47", "SmoothPlastic", ""),  # steel: stairs, stands, frames, hardware
    "Metal": ("A9A59C", "SmoothPlastic", ""),  # AC units, condensers, vents (round 5: warmer, read as heavy grey blocks)
    "Door": ("6C5442", "SmoothPlastic", ""),  # doors (round 5: warm mid-tone, black read as a void)
    "Window": ("4E5878", "SmoothPlastic", ""),  # concept pass: deep blue-violet glass in stone surrounds (was flat navy slabs)
    "Glass": ("BFD8E8", "Glass", ""),  # skylights
    "Accent": ("2F62C8", "SmoothPlastic", ""),  # cobalt: the tank and the sign plates (the 10% spike)
    "AccentSoft": ("5C79AE", "SmoothPlastic", ""),  # round 6: bands, awnings, billboard bands (softer than the tank)
    "Poster": ("EADFCB", "SmoothPlastic", ""),  # billboard panels (cream, not white)
    "Chevron": ("F3E6CC", "SmoothPlastic", ""),  # round 8: court chevrons, warm painted cream
    "PosterInk": ("5A79B2", "SmoothPlastic", ""),  # billboard words
    "White": ("F7F4EC", "SmoothPlastic", ""),  # sign faces, letters
    "Wood": ("A7744E", "WoodPlanks", "Roof2_Plank"),  # planks, crates, barrels, tank staves
    "Plant": ("6B9A55", "SmoothPlastic", ""),  # planter greenery
    "Hazard": ("E9D3A6", "SmoothPlastic", ""),  # lane lines (concept pass: cream paint, no yellow on this map)
    "SignWest": ("E89A3C", "SmoothPlastic", ""),  # west-side words (amber)
    "SignEast": ("5AA8D8", "SmoothPlastic", ""),  # east-side words (sky)
    "SignPit": ("2F62C8", "SmoothPlastic", ""),  # the middle (cobalt)
    "Asphalt": ("5C636C", "Asphalt", ""),  # the street far below (round 4: cool slate, it read muddy brown)
    "Sidewalk": ("A39D92", "Concrete", ""),
    "RoadLine": ("E8DFC2", "SmoothPlastic", ""),
    "Backfill": ("B9A992", "SmoothPlastic", ""),  # far city blocks
    # concept pass 2026-11-05 (vault/01 Design/Maps/Rooftops2.md -> Concept board)
    "Stone": ("E9D7B2", "Concrete", "Roof2_Plaster"),  # cream stone: surrounds, quoins, cornices, cheek walls
    "Shutter": ("4F7F5A", "SmoothPlastic", ""),  # louvred shutters (green; cobalt on the A roof by tone)
    "RoofTile": ("B8673F", "Slate", "Roof2_Terracotta"),  # A penthouse and hut roofs
    "RoofSlate": ("5F6B78", "Slate", "Roof2_Slate"),  # B penthouse mansard
    "Brick": ("A8644A", "Brick", "Roof2_Brick"),  # chimney stacks
    "Pot": ("B9653F", "SmoothPlastic", ""),  # terracotta pots and planters
    "Cloth": ("EFE3C8", "Fabric", ""),  # awning, chairs
    "Appliance": ("D9D1BF", "SmoothPlastic", ""),  # AC unit casings (cream enamel, as in the concept)
    # maps v4: floor breakup and the blank sign panels
    "Paver": ("D9BBA3", "Slate", "Roof2_Tile"),  # kerbed paving inlays on the team roofs (a lighter field)
    "Tar": ("6F6258", "Slate", "Roof2_Gravel"),  # tar-sealed repairs
    # Neon, thin only
    "GlowWarm": ("FFE2B8", "Neon", ""),
    "GlowWest": ("FFB14A", "Neon", ""),
    "GlowEast": ("7CD0FF", "Neon", ""),
}

# Facade plaster per building ("Wall" parts take these by the placement's tone).
TONE = {
    "teamA": "E3AA84",
    "teamB": "A9C2B0",
    "tower": "D4B98F",  # round 4: another step darker and warmer (cream washed out in sun)
    "pit": "C8A983",
    # the city around the block (round 1: varied, so the skyline isn't one cloned slab)
    "city0": "E8D3B4",
    "city1": "D9B49A",
    "city2": "BFCBC2",
    "city3": "E2C79C",
    # the far ring (fix round 1): pale, low-saturation, close to the haze (Atmosphere colour 246,204,166)
    "far0": "E6CDBB",
    "far1": "D9C6C0",
    "far2": "EAD7C2",
}
FRAME_SHADE = 0.8
BACKDROP = ["C9B79A", "B9A07F", "A9B5A2", "D2BFA0", "9FA9B3", "C4A48A"]

BEVEL = {"primary": 0.45, "secondary": 0.14, "tertiary": 0.05}
SEGMENTS = {"primary": 2, "secondary": 2, "tertiary": 1}

# Our own textures (concept pass 2026-11-05): rows cut from the approved trim sheet by
# tools/textures/make_map_variants.py, 512 colour + normal, near-white (BasePart.Color tints them). The ids are
# Image ids (the Decal uploads in art-source/uploads.json resolved in Studio). Roof2_Tile stays the Lobby's.
VARIANTS = {
    "Roof2_Plaster": ("Concrete", 12, "119615065244839", "100465385954786", ""),
    "Roof2_Brick": ("Brick", 6, "107246436113114", "126410814785821", ""),
    "Roof2_Terracotta": ("Slate", 9, "116071407612240", "86605748237639", ""),
    "Roof2_Slate": ("Slate", 8, "132940063953152", "92046096581530", ""),
    "Roof2_Gravel": ("Slate", 8, "76772826954213", "129961487573853", ""),
    "Roof2_Plank": ("WoodPlanks", 8, "115116285565924", "112670800725308", ""),
    "Roof2_Tile": ("Slate", 12, "73383285439881", "99655568297239", "99239709018479"),
}

# Golden afternoon (LihFolk Stylized Lighting Recipes 3.1 base, warm sun against cool shade). The sun stands across
# the map along X (GeographicLatitude chosen in Studio so GetSunDirection().Z ~ 0), lower than Dockyard2's.
LIGHTING = {
    "ClockTime": 17.1,  # round 1: lower, warmer sun (reviewers read 16.3 as neutral midday)
    "GeographicLatitude": 23.5,
    "Brightness": 3.2,
    "Ambient": (124, 118, 136),  # maps v4: one more step (the Pit under the trestles read crushed dark)
    "OutdoorAmbient": (150, 142, 172),  # round 8: deeper cool shade against the warm sun
    "ColorShift_Top": (255, 178, 110),
    "ColorShift_Bottom": (0, 0, 0),
    "EnvironmentDiffuseScale": 0.35,
    "EnvironmentSpecularScale": 0.15,
    "ExposureCompensation": -0.15,  # round 4: cream and peach were blowing out
    "GlobalShadows": True,
    "ShadowSoftness": 0.2,
}
FX = {
    "Atmosphere": {"Density": 0.3, "Offset": 0.25, "Color": (246, 204, 166), "Decay": (214, 160, 150), "Glare": 0.7, "Haze": 1.4},
    "Bloom": {"Intensity": 0.6, "Size": 24, "Threshold": 1.25},
    "Grade": {"Brightness": 0.02, "Contrast": 0.12, "Saturation": 0.08, "TintColor": (255, 236, 214)},
    "SunRays": {"Intensity": 0.18, "Spread": 0.7},
}
LAMP = {"color": (255, 214, 170), "brightness": 1.6, "range": 30}


def hex_rgb(h: str) -> tuple[int, int, int]:
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def shade(h: str, k: float) -> str:
    r, g, b = hex_rgb(h)
    return "%02X%02X%02X" % tuple(max(0, min(255, round(c * k))) for c in (r, g, b))


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
    lines.append("local TONE: { [string]: string } = { " + ", ".join(f'{k} = "{v}"' for k, v in TONE.items()) + " }")
    lines.append(f"local FRAME_SHADE = {FRAME_SHADE:g}")
    lines.append("local BACKDROP: { string } = { " + ", ".join(f'"{c}"' for c in BACKDROP) + " }")
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
    lines.append(
        f"local LAMP = {{ color = {_lua(LAMP['color'])}, brightness = {LAMP['brightness']:g}, range = {LAMP['range']:g} }}"
    )
    return "\n".join(lines)


def part_roles() -> dict[str, str]:
    path = ROOT / f"art-source/maps/{MAP}/Exports/Kit.json"
    if not path.exists():
        print("no kit export yet: PART_ROLE left empty")
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    out = {}
    for p in data["parts"]:
        m = p.get("material") or ""
        if m.startswith("R2_"):
            out[p["name"]] = m[3:]
    return out


def write_block(rel: str, tag: str, body: str) -> None:
    path = ROOT / rel
    text = path.read_text(encoding="utf-8")
    block = (
        f"-- BEGIN {tag} (generated by tools/maps/rooftops2_style.py --luau; edit the values there)\n"
        "-- stylua: ignore start\n" + body + "\n-- stylua: ignore end\n" + f"-- END {tag}"
    )
    new, n = re.subn(rf"-- BEGIN {tag}.*?-- END {tag}", lambda m: block, text, flags=re.S)
    assert n == 1, f"no {tag} block in {rel}"
    path.write_text(new, encoding="utf-8", newline="\n")
    print(f"Wrote the {tag} block of {rel}")


def palette_svg() -> str:
    rows = [(k, v[0], f"{v[1]}{' / ' + v[2] if v[2] else ''}") for k, v in PALETTE.items()]
    rows += [(f"Plaster {k}", v, "Concrete / Roof2_Plaster") for k, v in TONE.items()]
    w, rh = 760, 34
    h = 90 + rh * ((len(rows) + 1) // 2) + 110
    o = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" font-family="Segoe UI, Arial, sans-serif">',
         f'<rect width="{w}" height="{h}" fill="#1B2233"/>',
         '<text x="24" y="40" font-size="24" font-weight="700" fill="#F4F1EA">Rooftops2 palette</text>',
         '<text x="24" y="64" font-size="13" fill="#B9BDCB">tools/maps/rooftops2_style.py (roles; Studio applies them, so a change needs no upload)</text>']
    for i, (name, hx, mat) in enumerate(rows):
        x = 24 + (i % 2) * 370
        y = 86 + (i // 2) * rh
        o.append(f'<rect x="{x}" y="{y}" width="44" height="26" rx="4" fill="#{hx}" stroke="#0E1320"/>')
        o.append(f'<text x="{x + 54}" y="{y + 12}" font-size="13" font-weight="700" fill="#F4F1EA">{name}</text>')
        o.append(f'<text x="{x + 54}" y="{y + 25}" font-size="11" fill="#B9BDCB">#{hx}  {mat}</text>')
    y = 86 + rh * ((len(rows) + 1) // 2) + 16
    o.append(f'<text x="24" y="{y}" font-size="13" font-weight="700" fill="#F4F1EA">Far city blocks</text>')
    for i, hx in enumerate(BACKDROP):
        o.append(f'<rect x="{24 + i * 54}" y="{y + 10}" width="46" height="26" rx="4" fill="#{hx}" stroke="#0E1320"/>')
    o.append(f'<text x="24" y="{y + 62}" font-size="12" fill="#B9BDCB">Bevels: primary {BEVEL["primary"]}, secondary {BEVEL["secondary"]}, tertiary {BEVEL["tertiary"]} studs. Sun ClockTime {LIGHTING["ClockTime"]}, latitude {LIGHTING["GeographicLatitude"]}.</text>')
    o.append(f'<text x="24" y="{y + 80}" font-size="12" fill="#B9BDCB">Reserved, never on the map: team cyan #00E5FF, team orange-red #FF5A36.</text>')
    o.append("</svg>")
    return "\n".join(o)


if __name__ == "__main__":
    if "--svg" in sys.argv:
        out = ROOT / "vault/02 Art/References/maps/rooftops2/rooftops2-palette.svg"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(palette_svg(), encoding="utf-8")
        print(f"Wrote {out}")
    if "--luau" in sys.argv:
        write_block("tools/studio/maps/Rooftops2/Art.luau", "STYLE", style_block(part_roles()))
        write_block("tools/studio/maps/Rooftops2/Lighting.luau", "LIGHT", light_block())
