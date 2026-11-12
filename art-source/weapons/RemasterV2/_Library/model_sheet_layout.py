"""model_sheet_layout.py <panels_dir> <meta.json> <out.png>

Lays the panels rendered by model_sheet.py out as one model-sheet page (plain Python + Pillow):
a title bar with the colour roles, the turnaround (hero, four sides, front, back, rear three-quarter),
then the detail row (magazine, round, sights, charm mount) and the two first-person views.
"""
import json
import os
import sys
from PIL import Image, ImageDraw, ImageFont

pdir, meta_path, out = sys.argv[1], sys.argv[2], sys.argv[3]
meta = json.load(open(meta_path))
W, H = 960, 540
PAD = 10
TITLE = 190
BG = (214, 217, 222)
CELL = (226, 229, 233)
INK = (28, 31, 38)
SUB = (88, 94, 106)


def font(size, bold=False):
    for name in (("seguisb.ttf" if bold else "segoeui.ttf"), "arialbd.ttf" if bold else "arial.ttf"):
        try:
            return ImageFont.truetype("C:/Windows/Fonts/" + name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def panel(name, size):
    path = os.path.join(pdir, name + ".png")
    cell = Image.new("RGB", size, CELL)
    if os.path.exists(path):
        im = Image.open(path).convert("RGBA")
        if im.size != size:
            im = im.resize(size, Image.LANCZOS)
        cell.paste(im, (0, 0), im)
    return cell


cols, rows = 4, 4
SW = cols * W + (cols + 1) * PAD
SH = TITLE + rows * H + (rows + 1) * PAD
sheet = Image.new("RGB", (SW, SH), BG)
d = ImageDraw.Draw(sheet)


def at(c, r):
    return PAD + c * (W + PAD), TITLE + PAD + r * (H + PAD)


def put(name, c, r, label, size=(W, H), dx=0):
    x, y = at(c, r)
    x += dx
    sheet.paste(panel(name, size), (x, y))
    f = font(24, True)
    tw = d.textlength(label.upper(), font=f)
    d.rounded_rectangle((x + 8, y + 8, x + 24 + tw, y + 44), 6, fill=(240, 242, 245))
    d.text((x + 16, y + 10), label.upper(), font=f, fill=INK)


L = meta["labels"]
put("hero", 0, 0, "Three-quarter, left side (the side the player sees)", (W * 2 + PAD, H * 2 + PAD))
put("left", 2, 0, "Left side")
put("right", 3, 0, "Right side")
put("top", 2, 1, "Top")
put("bottom", 3, 1, "Bottom")
put("rear34", 0, 2, "Three-quarter, rear right")
half = (W - PAD) // 2
put("front", 1, 2, "Front", (half, H))
put("back", 1, 2, "Back", (half, H), dx=half + PAD)
put("ammo", 2, 2, L.get("ammo", "Magazine"))
put("round", 3, 2, L.get("round", "Round"))
put("held", 0, 3, L.get("held", "Held view"))
put("aim", 1, 3, L.get("aim", "Aim view"))
put("sights", 2, 3, L.get("sights", "Sights"))
put("charm", 3, 3, L.get("charm", "Charm mount"))

# title bar
d.text((PAD + 14, 18), meta["gun"].upper(), font=font(92, True), fill=INK)
tw = d.textlength(meta["gun"].upper(), font=font(92, True))
d.text((PAD + 14 + tw + 36, 40), meta.get("class", ""), font=font(40), fill=SUB)
d.text((PAD + 16, 128), "Base model sheet. Stylised low-poly, flat colour per material role, no textures. %s triangles. Muzzle is to the left in the left, top and bottom views." % format(meta["tris"], ","), font=font(26), fill=SUB)
# palette
pal = meta.get("palette", [])
x = SW - PAD - len(pal) * 206
d.text((x, 16), "COLOUR ROLES (a skin recolours or patterns these)", font=font(24, True), fill=INK)
for name, hexv in pal:
    try:
        col = tuple(int(hexv[i:i + 2], 16) for i in (0, 2, 4))
    except ValueError:
        col = (128, 128, 128)
    d.rounded_rectangle((x, 56, x + 190, 116), 6, fill=col, outline=(120, 124, 132))
    d.text((x, 122), name, font=font(24, True), fill=INK)
    d.text((x, 150), "#" + hexv, font=font(22), fill=SUB)
    x += 206
sheet.save(out)
print(out, sheet.size)
