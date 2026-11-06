#!/usr/bin/env python3
"""Dockyard2 style: every colour, material, bevel and lighting value of the map in one place.

The user will ask for changes once they have seen the map (vault/05 Production/Day Plan 2026-11-05.md), so
the look is parameters, not modelling:
  * Colours, Roblox materials and MaterialVariants are applied in Studio by role (Art.luau STYLE block, from
    this file), so a palette change is: edit PALETTE / LANE / BACKDROP here, run
        python tools/maps/dockyard2_style.py --luau
    and rerun the Art + Lighting bundle in Studio. No Blender, no upload.
  * Lighting values (LIGHTING, FX) go the same way into Lighting.luau's generated block.
  * Bevel sizes (BEVEL) and shapes are geometry: change them here, rerun the Blender kit build, export, upload
    and reinstall (vault/01 Design/Maps/Dockyard2.md -> Build and run order).
The Blender kit (tools/blender/build_map_kit_dockyard2.py) reads this file too, so its renders use the same
palette.

Run: python tools/maps/dockyard2_style.py [--luau] [--svg]
  --svg   writes the palette board vault/02 Art/References/maps/dockyard2/dockyard2-palette.svg
  --luau  rewrites the STYLE block of tools/studio/maps/Dockyard2/Art.luau (needs the kit export
          art-source/maps/Dockyard2/Exports/Kit.json for the part -> role table) and the LIGHT block of
          tools/studio/maps/Dockyard2/Lighting.luau
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# ---------------------------------------------------------------- identity
# "Sunny harbour": warm sand-grey deck, lane-coloured containers (terracotta / harbour blue / sea green, one
# value band), a signal-yellow gantry crane as the landmark and accent, white-and-charcoal port trims, a teal
# harbour under a clear afternoon sky. The Lobby is a dark warm-concrete bunker with teal-slate structure;
# Dockyard2 is outdoor, lighter and cooler with one warm accent, so the two never read as the same place.

# Roles: hex colour, Roblox material, MaterialVariant ("" = none). Kit materials are named D2_<Role>.
PALETTE: dict[str, tuple[str, str, str]] = {
    # big calm textured surfaces
    "Deck": ("97958E", "Concrete", "Dock2_Concrete"),  # maps v4: a lighter, cooler grey (read brown under the warm sun)  # concept pass: our slab-joint concrete  # pier deck slabs (ground band, V ~49%)
    "Concrete": ("A59D90", "Concrete", "Dock2_Concrete"),  # plinths, quay coping, shed base
    "ConcreteDark": ("6E675E", "Concrete", "Dock2_Concrete"),  # quay face, footings
    "Cladding": ("D3D5D0", "Plastic", "Dock2_Cladding"),  # concept pass: our ribbed cladding row  # round 1: the brushed texture read as smears on big walls  # shed wall panels (structure band, one step over the deck)
    "Roof": ("7A848D", "Plastic", "Dock2_Cladding"),
    "Grate": ("4A525A", "DiamondPlate", "Dock2_Grate"),  # stair treads, landings
    # lane colour (set per container in Studio from LANE / BACKDROP; these are the kit defaults)
    "Lane": ("52708E", "CorrodedMetal", "Dock2_Corrugated"),  # concept pass: corrugation and edge wear (no metalness map)  # container body; round 1: clean paint, the ribs carry the detail
    "LaneFrame": ("2C5079", "SmoothPlastic", ""),  # container corner posts and rails (LANE x FRAME_SHADE)
    # clean SmoothPlastic trims
    "Crane": ("F2B632", "DiamondPlate", "Dock2_Plate"),  # riveted plate panels; DiamondPlate base keeps it apart from Grate  # the landmark and the map's accent
    "Charcoal": ("353A40", "SmoothPlastic", ""),  # structure trims, frames, hardware
    "White": ("ECE8DF", "SmoothPlastic", ""),  # cab, sign faces, bay numbers
    "Hazard": ("E9E4D8", "SmoothPlastic", ""),  # concept pass: white paint (the crane is the only yellow)  # bay lines, kick bands, nosings
    "Rubber": ("2A2D31", "SmoothPlastic", ""),  # fenders, tyres
    "Wood": ("B39A74", "WoodPlanks", "Dock2_Plank"),  # natural timber, desaturated (no second yellow)  # pallets, crates
    "Glass": ("9FD3E0", "Glass", ""),
    # maps v4: the concept's honey crates (boards in a darker frame), shed cartons, deck stains
    "CrateWood": ("C99C64", "WoodPlanks", "Dock2_Plank"),  # maps v5: a step calmer (no second yellow)
    "CrateFrame": ("8E6440", "WoodPlanks", "Dock2_Plank"),
    "Carton": ("C9A87A", "SmoothPlastic", ""),
    # maps v5: Codex's windsock and quay set
    "Metal": ("9AA0A4", "SmoothPlastic", ""),  # galvanised mast
    "SockOrange": ("E0703A", "SmoothPlastic", ""),  # windsock bands (signal orange, small)
    "Rope": ("B9A27E", "Fabric", ""),  # mooring rope
    "Stain": ("7E786F", "Concrete", "Dock2_Concrete"),
    "Backfill": ("4E555C", "SmoothPlastic", ""),  # maps v5 r2: dark (the light filler read as blank white slabs)  # end-wall filler between containers: reads as more stacks, not a slab
    "Water": ("2A6878", "SmoothPlastic", ""),  # pass 1: #2F8C9C read as a loud cyan
    # Neon accents (thin strips only)
    "SignWest": ("B0503A", "SmoothPlastic", ""),  # spawn sign lane words (keep equal to LANE)
    "SignEast": ("3F8C66", "SmoothPlastic", ""),
    "SignMid": ("4A73A6", "SmoothPlastic", ""),
    "Hull": ("4C5D70", "SmoothPlastic", ""),  # ships (round 2: the dark hull read as an unfinished slab)
    "GlowWarm": ("FFC488", "Neon", ""),  # lamp heads, cab light (maps v5: amber, as Rooftops2; FFE2B8 bloomed white)
    "GlowSignal": ("FF8A3D", "Neon", ""),  # crane beacons (tiny)
}

# Lane containers: one hue per lane, all in the same value band so no lane reads heavier (callouts:
# "red", "blue", "green"). The red is a terracotta, far from the enemy team colour #FF5A36.
# Studio pass 1 (2026-11-05): on Roblox Metal the painted boxes mirrored the blue sky and read far too saturated, so
# painted surfaces use Dock2_Paint (the same textures on a non-metal Plastic base) and the lanes sit a step calmer.
# maps v5 palette: weathered harbour lanes (the reviewers read the blue and green as loud): rust, steel blue, sea green
# maps v5 r3: back to the concept's saturated lane colours (sampled from 01-overview; r2's weathered set read muddy)
LANE = {"west": "B0503A", "mid": "4A73A6", "east": "3F8C66", "crane": "D2CBBB"}  # crane: the white reefers under the crane (round 2)
FRAME_SHADE = 0.72  # LaneFrame = lane colour x this
# The end walls and far stacks: the same hues, lighter and greyer (aerial perspective), never saturated.
# Warm-leaning on purpose: the first style frame read all blue with a cool backdrop behind the blue lane.
# Round 3: one step more saturated and darker (reviewers read the first set as washed-out pastel).
BACKDROP = ["9E988C", "C0B49C", "7F8C99", "B07E68", "7E9A8C", "C2A878", "6F7F92"]

# Reserved, never used on the map: team colours (cyan #00E5FF, orange-red #FF5A36) and glitch magenta
# #FF3DCB (none on Dockyard2 so far).

# ---------------------------------------------------------------- geometry (Blender kit; rebuild + upload to change)
# Lobby Style Guide bevel hierarchy, scaled for an outdoor map seen at 25-80 studs (LihFolk Bevels Chamfers
# and Edge Highlights: ~2 px at 40 studs is 0.15-0.3).
BEVEL = {
    "primary": 0.45,  # architecture, container bodies, crane members (2 segments)
    "secondary": 0.14,  # frames, rails, trims (1-2 segments)
    "tertiary": 0.05,  # strips, letters, nosings
}
SEGMENTS = {"primary": 2, "secondary": 2, "tertiary": 1}

# MaterialVariants (match place MaterialService). The Lobby's painted textures (tools/textures/
# make_lobby_textures_v2.py): near-neutral greys, so BasePart.Color sets the hue. Ids are the Image assets.
VARIANTS = {
    # concept pass 2026-11-05: our rows from the approved trim sheet (tools/textures/make_map_variants.py), 512,
    # colour + normal, no roughness / metalness map (so no sky-mirroring). Image ids resolved from the Decal uploads.
    "Dock2_Concrete": ("Concrete", 10, "138512001950745", "73132979624401", ""),
    "Dock2_Corrugated": ("CorrodedMetal", 8, "108069495941112", "120881089785960", ""),
    "Dock2_Cladding": ("Plastic", 8, "107512542593996", "111822254753465", ""),
    "Dock2_Plate": ("DiamondPlate", 8, "111577542877717", "140402758328054", ""),
    "Dock2_Plank": ("WoodPlanks", 8, "127950269589942", "78863884268912", ""),
    "Dock2_Grate": ("DiamondPlate", 4, "86861542591828", "124599360671077", ""),
}

# ---------------------------------------------------------------- lighting (Studio; Lighting.luau)
# LihFolk Stylized Lighting Recipes §3.1 "Bright cartoon" as the base, with the arena tweaks of §3.2 where
# readability needs them. Sun across the pier, ~45 deg up: measured in Studio 2026-11-05, latitude 0 gives a sun
# direction of (-0.65, 0.65, -0.40) at ClockTime 15 (Roblox tilts the sun's path), latitude 23.5 gives (-0.71, 0.71, 0.0),
# so every container has a lit side, a shadow side and a lit top, and neither team looks into it.
LIGHTING = {
    "ClockTime": 16.3,  # maps v5 r2: lower, warmer sun (reviewers: no mood)  # maps v4: a little lower, warmer sun with longer shadows
    "GeographicLatitude": 23.5,
    "Brightness": 3.0,  # maps v4: the user found v3 "a bit dark"
    "Ambient": (140, 142, 152),  # maps v5 r2: container shade sides read near-black  # maps v4: more fill  # pass 1: a bluer ambient pushed the blue lane to royal blue in shade
    "OutdoorAmbient": (178, 180, 194),  # maps v4: more fill, still cool against the warm sun  # round 3: cooler shade against a warmer sun (warm/cool contrast)
    "ColorShift_Top": (255, 214, 172),  # maps v5 r2: warmer sun  # maps v4: (255, 204, 150) turned the grey deck brown in the sun
    "ColorShift_Bottom": (0, 0, 0),
    "EnvironmentDiffuseScale": 0.2,
    "EnvironmentSpecularScale": 0.15,
    "ExposureCompensation": 0.2,  # maps v4: brighter (0.3 blew out the Shed inside)
    "GlobalShadows": True,
    "ShadowSoftness": 0.2,
}
FX = {
    "Atmosphere": {"Density": 0.3, "Offset": 0.18, "Color": (234, 220, 202), "Decay": (140, 176, 216), "Glare": 0.6, "Haze": 1.6},  # maps v5 r2: less milky  # maps v4: warm haze, cool depth
    "Bloom": {"Intensity": 0.6, "Size": 24, "Threshold": 1.25},
    "Grade": {"Brightness": 0.03, "Contrast": 0.13, "Saturation": 0.12, "TintColor": (255, 244, 228)},  # maps v4: clearer, warmer
    "SunRays": {"Intensity": 0.08, "Spread": 0.5},
}
LAMP = {"color": (255, 222, 176), "brightness": 2.3, "range": 40}  # maps v5 r3: the Shed read gloomy  # maps v4: 1.7 with the brighter exposure  # round 1: the Shed inside read murky  # mast floods and shed lamps (shadowless)


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
    lines.append("local LANE: { [string]: string } = { " + ", ".join(f'{k} = "{v}"' for k, v in LANE.items()) + " }")
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
    path = ROOT / "art-source/maps/Dockyard2/Exports/Kit.json"
    if not path.exists():
        print("no kit export yet: PART_ROLE left empty")
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    out = {}
    for p in data["parts"]:
        m = p.get("material") or ""
        if m.startswith("D2_"):
            out[p["name"]] = m[3:]
    return out


def write_block(rel: str, tag: str, body: str) -> None:
    path = ROOT / rel
    text = path.read_text(encoding="utf-8")
    block = (
        f"-- BEGIN {tag} (generated by tools/maps/dockyard2_style.py --luau; edit the values there)\n"
        "-- stylua: ignore start\n" + body + "\n-- stylua: ignore end\n" + f"-- END {tag}"
    )
    new, n = re.subn(rf"-- BEGIN {tag}.*?-- END {tag}", lambda m: block, text, flags=re.S)
    assert n == 1, f"no {tag} block in {rel}"
    path.write_text(new, encoding="utf-8", newline="\n")
    print(f"Wrote the {tag} block of {rel}")


def palette_svg() -> str:
    rows = [(k, v[0], f"{v[1]}{' / ' + v[2] if v[2] else ''}") for k, v in PALETTE.items()]
    rows += [(f"Lane {k}", v, "Metal / Dock2_Metal") for k, v in LANE.items()]
    rows += [(f"Lane {k} frame", shade(v, FRAME_SHADE), "SmoothPlastic") for k, v in LANE.items()]
    w, rh = 760, 34
    h = 90 + rh * ((len(rows) + 1) // 2) + 110
    o = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" font-family="Segoe UI, Arial, sans-serif">',
         f'<rect width="{w}" height="{h}" fill="#1B2233"/>',
         '<text x="24" y="40" font-size="24" font-weight="700" fill="#F4F1EA">Dockyard2 palette</text>',
         '<text x="24" y="64" font-size="13" fill="#B9BDCB">tools/maps/dockyard2_style.py (roles; Studio applies them, so a change needs no upload)</text>']
    for i, (name, hx, mat) in enumerate(rows):
        x = 24 + (i % 2) * 370
        y = 86 + (i // 2) * rh
        o.append(f'<rect x="{x}" y="{y}" width="44" height="26" rx="4" fill="#{hx}" stroke="#0E1320"/>')
        o.append(f'<text x="{x + 54}" y="{y + 12}" font-size="13" font-weight="700" fill="#F4F1EA">{name}</text>')
        o.append(f'<text x="{x + 54}" y="{y + 25}" font-size="11" fill="#B9BDCB">#{hx}  {mat}</text>')
    y = 86 + rh * ((len(rows) + 1) // 2) + 16
    o.append(f'<text x="24" y="{y}" font-size="13" font-weight="700" fill="#F4F1EA">Backdrop stacks (aerial perspective)</text>')
    for i, hx in enumerate(BACKDROP):
        o.append(f'<rect x="{24 + i * 54}" y="{y + 10}" width="46" height="26" rx="4" fill="#{hx}" stroke="#0E1320"/>')
    o.append(f'<text x="24" y="{y + 62}" font-size="12" fill="#B9BDCB">Bevels: primary {BEVEL["primary"]}, secondary {BEVEL["secondary"]}, tertiary {BEVEL["tertiary"]} studs. Sun ClockTime {LIGHTING["ClockTime"]}, latitude {LIGHTING["GeographicLatitude"]}.</text>')
    o.append(f'<text x="24" y="{y + 80}" font-size="12" fill="#B9BDCB">Reserved, never on the map: team cyan #00E5FF, team orange-red #FF5A36.</text>')
    o.append("</svg>")
    return "\n".join(o)


if __name__ == "__main__":
    if "--svg" in sys.argv:
        out = ROOT / "vault/02 Art/References/maps/dockyard2/dockyard2-palette.svg"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(palette_svg(), encoding="utf-8")
        print(f"Wrote {out}")
    if "--luau" in sys.argv:
        write_block("tools/studio/maps/Dockyard2/Art.luau", "STYLE", style_block(part_roles()))
        write_block("tools/studio/maps/Dockyard2/Lighting.luau", "LIGHT", light_block())
