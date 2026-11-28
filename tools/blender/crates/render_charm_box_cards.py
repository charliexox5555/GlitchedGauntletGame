"""Generate CharmBox Blender model, FBX, review sheet, and 512x512 Shop card icons."""

import os
import subprocess
from PIL import Image, ImageDraw, ImageFont

ROOT = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
BUILD_SCRIPT = os.path.join(ROOT, "tools", "blender", "crates", "build_charm_box.py")
SHOP_BOXES_DIR = os.path.join(ROOT, "art-source", "ui", "shop", "boxes")
CRATES_DIR = os.path.join(ROOT, "art-source", "lobby", "crates")


def make_label_tex(theme: str) -> str:
    os.makedirs(SHOP_BOXES_DIR, exist_ok=True)
    path = os.path.join(SHOP_BOXES_DIR, f"_label_{theme.lower()}.png")
    W, H = 512, 440
    img = Image.new("RGBA", (W, H), (14, 16, 22, 255))
    dr = ImageDraw.Draw(img)
    accent = (245, 194, 56, 255) if theme == "Strike" else (63, 224, 242, 255)
    dim_acc = (245, 194, 56, 54) if theme == "Strike" else (63, 224, 242, 54)

    dr.polygon([(0, 120), (W, 30), (W, 96), (0, 186)], fill=dim_acc)
    dr.polygon([(0, 250), (W, 160), (W, 198), (0, 288)], fill=dim_acc)
    dr.rectangle([16, 16, W - 16, H - 16], outline=accent, width=6)
    dr.rectangle([28, 28, W - 28, H - 28], outline=(60, 66, 80, 255), width=2)

    cx, cy = W // 2, 165
    dr.polygon([(cx, cy - 66), (cx + 66, cy), (cx, cy + 66), (cx - 66, cy)], fill=accent)
    dr.polygon([(cx, cy - 42), (cx + 42, cy), (cx, cy + 42), (cx - 42, cy)], fill=(14, 16, 22, 255))
    dr.polygon([(cx, cy - 22), (cx + 22, cy), (cx, cy + 22), (cx - 22, cy)], fill=accent)

    try:
        font_big = ImageFont.truetype(r"C:\Windows\Fonts\segoeuib.ttf", 58 if theme == "Strike" else 48)
        font_sub = ImageFont.truetype(r"C:\Windows\Fonts\segoeuib.ttf", 30)
    except Exception:
        font_big = ImageFont.load_default()
        font_sub = ImageFont.load_default()

    title = "STRIKE" if theme == "Strike" else "OVERDRIVE"
    tb = dr.textbbox((0, 0), title, font=font_big)
    dr.text(((W - (tb[2] - tb[0])) // 2, 265), title, fill=(246, 248, 252, 255), font=font_big)
    sub = "CHARM BOX"
    sb = dr.textbbox((0, 0), sub, font=font_sub)
    dr.text(((W - (sb[2] - sb[0])) // 2, 344), sub, fill=accent, font=font_sub)
    img.save(path)
    return path


def crop_rgba(path: str, pad: int = 16):
    im = Image.open(path).convert("RGBA")
    bbox = im.getbbox()
    if bbox:
        im = im.crop(bbox)
    side = max(im.size) + pad * 2
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
    sq.resize((512, 512), Image.LANCZOS).save(path)


def main():
    tmp_labels = [make_label_tex("Strike"), make_label_tex("Overdrive")]
    subprocess.run(
        [BLENDER, "--background", "--factory-startup", "--python", BUILD_SCRIPT],
        check=True,
    )
    for p in tmp_labels:
        if os.path.exists(p):
            os.remove(p)

    crop_rgba(os.path.join(SHOP_BOXES_DIR, "box_strike.png"), pad=18)
    crop_rgba(os.path.join(SHOP_BOXES_DIR, "box_overdrive.png"), pad=18)

    sheet = Image.new("RGBA", (1280, 1280), (12, 13, 18, 255))
    for i in range(4):
        qp = os.path.join(CRATES_DIR, f"_q{i + 1}.png")
        im = Image.open(qp).convert("RGBA")
        sheet.paste(im, ((i % 2) * 640, (i // 2) * 640))
        os.remove(qp)
    sheet.save(os.path.join(CRATES_DIR, "charm_box_review.png"))
    print("Done generating CharmBox assets!")


if __name__ == "__main__":
    main()
