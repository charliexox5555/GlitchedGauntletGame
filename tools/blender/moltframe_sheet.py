"""Compose the Moltframe Vandal v04 stock-vs-skin comparison sheet (system Python + PIL)."""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2] / "art-source/weapons/Skins"
REV = ROOT / "Moltframe/Vandal/v04/review"
ROWS = [
    ("hero", "Player-facing three-quarter (left side)"),
    ("opposite", "Opposite three-quarter (right side)"),
    ("profile_left", "Matched profile, left (ortho, same scale)"),
    ("profile_right", "Matched profile, right (ortho, same scale)"),
    ("held", "Matched held angle"),
    ("hip", "First-person hip, 80° viewmodel camera"),
    ("ads", "Blender ADS, 68° at the stock AimPoint"),
    ("reload", "Reload, magazine at its lowest"),
    ("inspect", "Inspect (mid clip)"),
]
W = 760
def font(size, bold=False):
    for name in (("segoeuib.ttf" if bold else "segoeui.ttf"), "arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()

MELEE_ROWS = [
    ("hero", "Player-facing three-quarter"), ("opposite", "Opposite three-quarter"),
    ("profile_left", "Matched profile, left (ortho, same scale)"), ("profile_right", "Matched profile, right (ortho, same scale)"),
    ("held", "Matched held angle"), ("fp", "Stock first-person camera"),
    ("inspect", "Inspect (mid clip)"), ("slash1", "Slash 1 (mid clip)"), ("heavystab", "Heavy stab (mid clip)"),
]

def main(out_name="matched_v04.jpg", rev=None, title="Moltframe Vandal  /  v04", melee=""):
    global ROWS
    if melee:
        ROWS = MELEE_ROWS
    global REV
    if rev:
        REV = ROOT / rev
    tiles = []
    for key, label in ROWS:
        a = Image.open(REV / f"{key}_stock.png").convert("RGB")
        b = Image.open(REV / f"{key}_moltframe.png").convert("RGB")
        h = round(a.height * W / a.width)
        tiles.append((label, a.resize((W, h), Image.LANCZOS), b.resize((W, h), Image.LANCZOS)))
    pad, head, lab = 24, 96, 34
    H = head + sum(t[1].height + lab + pad for t in tiles) + pad
    sheet = Image.new("RGB", (W * 2 + pad * 3, H), (22, 25, 33))
    d = ImageDraw.Draw(sheet)
    d.text((pad, 18), title, font=font(40, True), fill=(236, 238, 245))
    d.text((pad, 66), "Stock", font=font(20, True), fill=(170, 178, 196))
    d.text((pad * 2 + W, 66), title.split()[0], font=font(20, True), fill=(196, 150, 245))
    y = head
    for label, a, b in tiles:
        d.text((pad, y + 4), label, font=font(18), fill=(200, 205, 218))
        y += lab
        sheet.paste(a, (pad, y)); sheet.paste(b, (pad * 2 + W, y))
        y += a.height + pad
    sheet.save(REV / out_name, quality=90)
    return REV / out_name

if __name__ == "__main__":
    print(main(*sys.argv[1:]))
