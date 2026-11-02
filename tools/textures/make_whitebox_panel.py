#!/usr/bin/env python3
"""Whitebox panel texture: one panel with thin edge lines and a small + at each corner.

Run: python tools/textures/make_whitebox_panel.py
Writes art-source/maps/whitebox/Whitebox_Panel.png. White on transparent: the Texture's
Color3 sets the line colour and StudsPerTile the panel size (8 studs in the map).
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
SS = 2  # drawn larger, then shrunk, for soft edges
LINE = 7  # edge line width at final size
ARM = 58  # + arm length from the corner
ARM_W = 13
LINE_ALPHA = 90
CROSS_ALPHA = 230

s = SIZE * SS
line, cross = LINE * SS / 2, ARM * SS
arm_w = ARM_W * SS / 2
img = Image.new("L", (s, s), 0)
d = ImageDraw.Draw(img)

# Edge lines sit half on each side of the tile border, so they meet across tiles.
d.rectangle((0, 0, s, line), fill=LINE_ALPHA)
d.rectangle((0, s - line, s, s), fill=LINE_ALPHA)
d.rectangle((0, 0, line, s), fill=LINE_ALPHA)
d.rectangle((s - line, 0, s, s), fill=LINE_ALPHA)

# Quarter of a + at each corner: the four tiles around a corner complete it.
for cx in (0, s):
    for cy in (0, s):
        d.rectangle((cx - cross, cy - arm_w, cx + cross, cy + arm_w), fill=CROSS_ALPHA)
        d.rectangle((cx - arm_w, cy - cross, cx + arm_w, cy + cross), fill=CROSS_ALPHA)

alpha = img.filter(ImageFilter.GaussianBlur(SS * 0.6)).resize((SIZE, SIZE), Image.LANCZOS)
out = Image.merge("RGBA", (Image.new("L", (SIZE, SIZE), 255),) * 3 + (alpha,))
target = Path(__file__).resolve().parents[2] / "art-source/maps/whitebox/Whitebox_Panel.png"
target.parent.mkdir(parents=True, exist_ok=True)
out.save(target)
print(f"Wrote {target}")
