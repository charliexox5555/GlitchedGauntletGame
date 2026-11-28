"""Combine individual charm review renders into labeled 4x2 contact sheets."""

import os
from PIL import Image, ImageDraw, ImageFont

REPO = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
ROOT = os.path.join(REPO, "art-source", "charms")
CHARMS = [
    ("ArcadeToken", "ARCADE TOKEN (Common)"),
    ("IceCube", "ICE CUBE (Rare)"),
    ("Joystick", "JOYSTICK (Rare)"),
    ("PixelHeart", "PIXEL HEART (Rare)"),
    ("SnowflakeShard", "SNOWFLAKE SHARD (Rare)"),
    ("GameCartridge", "GAME CARTRIDGE (Epic)"),
    ("ThunderOrb", "THUNDER ORB (Epic)"),
    ("HighScore", "HIGH SCORE (Legendary)"),
]


def make_sheet(shot_name: str, out_name: str):
    cell_w, cell_h = 520, 560
    cols, rows = 4, 2
    canvas = Image.new("RGB", (cell_w * cols, cell_h * rows), (18, 21, 28))
    draw = ImageDraw.Draw(canvas)
    try:
        font = ImageFont.truetype("arialbd.ttf", 22)
    except Exception:
        font = ImageFont.load_default()

    for idx, (cid, label) in enumerate(CHARMS):
        r, c = divmod(idx, cols)
        x0, y0 = c * cell_w, r * cell_h
        img_path = os.path.join(ROOT, cid, "review", f"{shot_name}.png")
        if os.path.exists(img_path):
            im = Image.open(img_path).convert("RGB").resize((cell_w - 8, cell_w - 8), Image.Resampling.LANCZOS)
            canvas.paste(im, (x0 + 4, y0 + 4))
        draw.rectangle([x0 + 4, y0 + cell_w - 4, x0 + cell_w - 4, y0 + cell_h - 4], fill=(26, 30, 40))
        draw.text((x0 + 16, y0 + cell_w + 6), label, fill=(240, 244, 250), font=font)

    out_path = os.path.join(ROOT, out_name)
    canvas.save(out_path)
    return out_path


if __name__ == "__main__":
    p1 = make_sheet("front_34", "review_all_8.png")
    p2 = make_sheet("side", "review_sides_8.png")
    p3 = make_sheet("closeup_join", "review_joins_8.png")
    print("WROTE", p1, p2, p3)
