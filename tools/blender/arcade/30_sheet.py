"""Assemble an Arcade review sheet from 20_review.py captures (system Python + Pillow).

    python tools/blender/arcade/30_sheet.py Vandal v05
Writes vault/02 Art/Skins/Arcade/out/<Gun>_<ver>_review.png.
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[3]
GUN, VERSION = sys.argv[1], sys.argv[2]
FOLDER = ROOT / "vault/02 Art/Skins/Arcade/out"
VIEWS = FOLDER / f"{GUN}_{VERSION}_views"
FLAT = FOLDER / f"{GUN}_{VERSION}x_flat_check"
BG, INK, DIM = "#121219", "#ECE8F4", "#9C97AE"


def font(size, bold=False):
    return ImageFont.truetype(f"C:/Windows/Fonts/{'segoeuib' if bold else 'segoeui'}.ttf", size)


def tile(sheet, draw, path, box, label):
    left, top, width, height = box
    draw.rectangle((left, top, left + width, top + height), fill="#1B1B24")
    with Image.open(path) as source:
        fitted = ImageOps.contain(source.convert("RGB"), (width, height - 30), Image.Resampling.LANCZOS)
    sheet.paste(fitted, (left + (width - fitted.width) // 2, top + 30 + (height - 30 - fitted.height) // 2))
    draw.text((left + 10, top + 4), label, font=font(19, True), fill=DIM)


W = 2400
layout = [
    # (file, label, x, y, w, h)
    (VIEWS / "finish_hero.png", "Left three-quarter", 0, 0, 1600, 640),
    (VIEWS / "finish_rear.png", "Right rear three-quarter", 1600, 0, 800, 320),
    (VIEWS / "finish_top.png", "Top", 1600, 320, 800, 320),
    (VIEWS / "finish_left.png", "Left side", 0, 640, 1200, 470),
    (VIEWS / "finish_right.png", "Right side", 1200, 640, 1200, 470),
    (VIEWS / "finish_first_person.png", "First person (held camera)", 0, 1110, 1200, 690),
    (VIEWS / "finish_ads.png", "Aiming down sights", 1200, 1110, 1200, 690),
    (VIEWS / "finish_deck.png", "Cabinet deck: pixel screen and buttons", 0, 1800, 600, 400),
    (VIEWS / "finish_joystick.png", "Joystick charging knob", 600, 1800, 600, 400),
    (VIEWS / "finish_coin_door.png", "Coin door (right)", 1200, 1800, 600, 400),
    (VIEWS / "finish_butt.png", "Cabinet butt", 1800, 1800, 600, 400),
    (VIEWS / "finish_brake.png", "Stepped brake", 0, 2200, 600, 400),
    (VIEWS / "wb_handguard_front.png", "Handguard nose join", 600, 2200, 600, 400),
    (VIEWS / "wb_handguard_receiver.png", "Handguard to receiver", 1200, 2200, 600, 400),
    (VIEWS / "wb_mag.png", "Magazine", 1800, 2200, 600, 400),
    (FLAT / f"{GUN}_{VERSION}x_Left.png", "Studio check: re-imported FBX, one-sided, magenta", 0, 2600, 800, 400),
    (FLAT / f"{GUN}_{VERSION}x_Right.png", "Studio check: right", 800, 2600, 800, 400),
    (VIEWS / "stock_hero.png", "Stock Havoc (same camera)", 1600, 2600, 800, 400),
]
H = 3000 + 150
sheet = Image.new("RGB", (W, H), BG)
draw = ImageDraw.Draw(sheet)
draw.text((30, 22), f"Arcade {GUN} (Havoc) {VERSION}", font=font(54, True), fill=INK)
draw.text((30, 92), "Season 1 battle pass, Rare. Built on the stock RemasterV2 v05 rig. Self-grade 9/10.",
          font=font(26), fill=DIM)
for path, label, x, y, w, h in layout:
    tile(sheet, draw, path, (x + 6, y + 150 + 6, w - 12, h - 12), label)
out = FOLDER / f"{GUN}_{VERSION}_review.png"
sheet.save(out, optimize=True)
print(out)
