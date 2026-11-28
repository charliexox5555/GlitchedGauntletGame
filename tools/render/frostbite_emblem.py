"""The Frostbite line's collection emblem (Locker.EMBLEMS): a crisp faceted six-point
glacial crystal star with a diamond core cut-out. Flat white on transparent, 512 x 512.

    python tools/render/frostbite_emblem.py
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw

S = 4
OUT = Path(__file__).resolve().parents[2] / "art-source/ui/collection-emblems/emblem_frostbite.png"


def s(points):
    return [(x * S, y * S) for x, y in points]


img = Image.new("L", (512 * S, 512 * S), 0)
d = ImageDraw.Draw(img)
WHITE, CUT = 255, 0
cx, cy = 256, 256

# Six chiseled hexagonal crystal arms radiating from a central hexagon
for i in range(6):
    ang = math.radians(i * 60 - 90)
    ux, uy = math.cos(ang), math.sin(ang)
    vx, vy = -uy, ux
    arm = [
        (cx + ux * 68 + vx * 24, cy + uy * 68 + vy * 24),
        (cx + ux * 165 + vx * 30, cy + uy * 165 + vy * 30),
        (cx + ux * 224, cy + uy * 224),
        (cx + ux * 165 - vx * 30, cy + uy * 165 - vy * 30),
        (cx + ux * 68 - vx * 24, cy + uy * 68 - vy * 24),
    ]
    d.polygon(s(arm), WHITE)
    # Side chevron crystal barbs near outer half
    for side in (-1, 1):
        bx, by = cx + ux * 138, cy + uy * 138
        barb = [
            (bx + ux * 12 + vx * 14 * side, by + uy * 12 + vy * 14 * side),
            (bx + ux * 46 + vx * 52 * side, by + uy * 46 + vy * 52 * side),
            (bx + ux * 58 + vx * 44 * side, by + uy * 58 + vy * 44 * side),
            (bx + ux * 26 + vx * 10 * side, by + uy * 26 + vy * 10 * side),
        ]
        d.polygon(s(barb), WHITE)

# Central hexagonal glacial shield + diamond cut-out core
hex_core = [(cx + 92 * math.cos(math.radians(i * 60)), cy + 92 * math.sin(math.radians(i * 60))) for i in range(6)]
d.polygon(s(hex_core), WHITE)
inner_hex = [(cx + 46 * math.cos(math.radians(i * 60)), cy + 46 * math.sin(math.radians(i * 60))) for i in range(6)]
d.polygon(s(inner_hex), CUT)
core_gem = [(cx, cy - 26), (cx + 22, cy), (cx, cy + 26), (cx - 22, cy)]
d.polygon(s(core_gem), WHITE)

alpha = img.resize((512, 512), Image.LANCZOS)
out = Image.new("RGBA", (512, 512), (255, 255, 255, 0))
out.putalpha(alpha)
OUT.parent.mkdir(parents=True, exist_ok=True)
out.save(OUT)
prev = Image.new("RGB", (340, 140), (24, 34, 52))
for size, x in ((128, 10), (64, 160), (14, 250)):
    prev.paste(Image.new("RGB", (size, size), (105, 215, 255)), (x, 6), out.resize((size, size), Image.LANCZOS))
prev.save(Path(__file__).resolve().parents[2] / "art-source/ui/collection-emblems/emblem_frostbite_preview.png")
print(OUT)
