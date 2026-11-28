"""The Arcade line's collection emblem (Locker.EMBLEMS): a faceted arcade joystick with a
coin slot cut through its base and one button. Flat white on transparent, 512 x 512, no
curves (octagons for round forms), chamfered corners, like the other emblems.

    python tools/render/arcade_emblem.py
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw

S = 4  # draw at 4x, then downsample for clean edges
OUT = Path(__file__).resolve().parents[2] / "art-source/ui/collection-emblems/emblem_arcade.png"


def octagon(cx, cy, r):
    return [(cx + r * math.cos(math.pi / 8 + i * math.pi / 4), cy + r * math.sin(math.pi / 8 + i * math.pi / 4))
            for i in range(8)]


def scaled(points):
    return [(x * S, y * S) for x, y in points]


img = Image.new("L", (512 * S, 512 * S), 0)
d = ImageDraw.Draw(img)
WHITE, CUT = 255, 0
# base: a chamfered cabinet-deck plate
d.polygon(scaled([(124, 318), (388, 318), (432, 362), (432, 418), (404, 448), (108, 448), (80, 418), (80, 362)]), WHITE)
# stick, seated into the base, with a faceted collar where it meets the plate
d.polygon(scaled([(240, 176), (272, 176), (272, 300), (240, 300)]), WHITE)
d.polygon(scaled([(214, 318), (226, 296), (286, 296), (298, 318)]), WHITE)
# the ball, with a cut facet highlight
d.polygon(scaled(octagon(256, 138, 94)), WHITE)
d.polygon(scaled([(196, 112), (214, 88), (238, 82), (222, 106)]), CUT)
# one arcade button beside the stick
d.polygon(scaled(octagon(372, 280, 30)), WHITE)
# the coin slot through the base
d.polygon(scaled([(198, 376), (314, 376), (322, 386), (314, 396), (198, 396), (190, 386)]), CUT)
alpha = img.resize((512, 512), Image.LANCZOS)
out = Image.new("RGBA", (512, 512), (255, 255, 255, 0))
out.putalpha(alpha)
OUT.parent.mkdir(parents=True, exist_ok=True)
out.save(OUT)
# preview at emblem sizes on the Locker's dark plate
prev = Image.new("RGB", (340, 140), (38, 38, 42))
for size, x in ((128, 10), (64, 160), (14, 250)):
    prev.paste(Image.new("RGB", (size, size), (214, 51, 156)), (x, 6), out.resize((size, size), Image.LANCZOS))
prev.save(Path(__file__).resolve().parents[2] / "art-source/ui/collection-emblems/emblem_arcade_preview.png")
print(OUT)
