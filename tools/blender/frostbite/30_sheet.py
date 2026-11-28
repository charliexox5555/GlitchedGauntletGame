"""Assemble a Frostbite review sheet from 20_review.py captures (system Python + Pillow).

    python tools/blender/frostbite/30_sheet.py Vandal v01 Havoc
Writes vault/02 Art/Skins/Frostbite/out/<Gun>_<ver>_review.png.
"""

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[3]
GUN, VERSION = sys.argv[1], sys.argv[2]
DISPLAY = sys.argv[3] if len(sys.argv) > 3 else GUN
GRADE = sys.argv[4] if len(sys.argv) > 4 else "9/10"
FOLDER = ROOT / "vault/02 Art/Skins/Frostbite/out"
VIEWS = FOLDER / f"{GUN}_{VERSION}_views"
FLAT = FOLDER / f"{GUN}_{VERSION}x_flat_check"
BG, INK, DIM = "#0D1118", "#E6F4FF", "#8BA8C2"


def font(size, bold=False):
    return ImageFont.truetype(f"C:/Windows/Fonts/{'segoeuib' if bold else 'segoeui'}.ttf", size)


def tile(sheet, draw, path, box, label):
    left, top, width, height = box
    draw.rectangle((left, top, left + width, top + height), fill="#131A24")
    if not Path(path).exists():
        draw.text((left + 10, top + 4), f"{label} (no capture)", font=font(19, True), fill=DIM)
        return
    with Image.open(path) as source:
        fitted = ImageOps.contain(source.convert("RGB"), (width, height - 30), Image.Resampling.LANCZOS)
    sheet.paste(fitted, (left + (width - fitted.width) // 2, top + 30 + (height - 30 - fitted.height) // 2))
    draw.text((left + 10, top + 4), label, font=font(19, True), fill=DIM)


W = 2400
layout = [
    (VIEWS / "finish_hero.png", "Left three-quarter", 0, 0, 1600, 640),
    (VIEWS / "finish_rear.png", "Right rear three-quarter", 1600, 0, 800, 320),
    (VIEWS / "finish_top.png", "Top", 1600, 320, 800, 320),
    (VIEWS / "finish_left.png", "Left side", 0, 640, 1200, 470),
    (VIEWS / "finish_right.png", "Right side", 1200, 640, 1200, 470),
    (VIEWS / "finish_first_person.png", "First person (held camera)", 0, 1110, 1200, 690),
    (VIEWS / "finish_ads.png", "Aiming down sights", 1200, 1110, 1200, 690),
    (VIEWS / "finish_core_left.png", "Cryo-core chamber & inspect spires", 0, 1800, 600, 400),
    (VIEWS / "finish_fore_left.png", "Fore-end glacial shroud & crystals", 600, 1800, 600, 400),
    (VIEWS / "finish_stock.png", "Glacial skeleton stock", 1200, 1800, 600, 400),
    (VIEWS / "finish_muzzle.png", "Glacial fang muzzle crown", 1800, 1800, 600, 400),
    (VIEWS / "finish_mag.png", "Cryo-sheathed magazine", 0, 2200, 600, 400),
    (VIEWS / "culled_stock_join.png", "Stock to receiver join (culled)", 600, 2200, 600, 400),
    (VIEWS / "culled_trigger_join_left.png", "Trigger guard & lower join (culled)", 1200, 2200, 600, 400),
    (VIEWS / "culled_fore_receiver.png", "Fore-end to receiver join (culled)", 1800, 2200, 600, 400),
    (FLAT / f"{GUN}_{VERSION}x_Left.png", "Studio check: re-imported FBX, one-sided, magenta", 0, 2600, 800, 400),
    (FLAT / f"{GUN}_{VERSION}x_Right.png", "Studio check: right", 800, 2600, 800, 400),
    (VIEWS / "stock_hero.png", f"Stock {DISPLAY} (same camera)", 1600, 2600, 800, 400),
]

override = ROOT / f"tools/blender/frostbite/sheet_{GUN.lower()}.json"
if override.exists():
    slots = [(0, 1800), (600, 1800), (1200, 1800), (1800, 1800), (0, 2200), (600, 2200), (1200, 2200), (1800, 2200)]
    keep = [row for row in layout if row[3] < 1800 or row[3] >= 2600]
    extra = [(VIEWS / f, label, x, y, 600, 400) for (f, label), (x, y) in zip(json.loads(override.read_text()), slots)]
    layout = keep + extra

H = 3000 + 150
sheet = Image.new("RGB", (W, H), BG)
draw = ImageDraw.Draw(sheet)
draw.text((30, 22), f"Frostbite {GUN} ({DISPLAY}) {VERSION}", font=font(54, True), fill=INK)
draw.text((30, 92), f"Season 1 battle pass, Legendary. Built on the stock RemasterV2 v05 rig. Self-grade {GRADE}.",
          font=font(26), fill=DIM)
for path, label, x, y, w, h in layout:
    tile(sheet, draw, path, (x + 6, y + 150 + 6, w - 12, h - 12), label)
out = FOLDER / f"{GUN}_{VERSION}_review.png"
sheet.save(out, optimize=True)
print(out)
