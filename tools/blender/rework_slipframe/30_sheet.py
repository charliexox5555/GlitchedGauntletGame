"""Assemble the live Blender captures into the handoff review sheet."""

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps


def font(size, bold=False):
    filename = "segoeuib.ttf" if bold else "segoeui.ttf"
    return ImageFont.truetype(f"C:/Windows/Fonts/{filename}", size)


def fill_image(draw_to, image_path, box):
    left, top, width, height = box
    with Image.open(image_path) as source:
        fitted = ImageOps.contain(source.convert("RGB"), (width, height), Image.Resampling.LANCZOS)
        draw_to.paste(fitted, (left + (width - fitted.width) // 2, top + (height - fitted.height) // 2))


def make_sheet(version, tier):
    root = Path(__file__).resolve().parents[3]
    folder = root / "vault/02 Art/Skins/Slipframe/out"
    captures = folder / f"Guardian_{version}_views"
    rows = [
        ("hero", "Left three-quarter", 370), ("rear", "Right rear three-quarter", 370),
        ("left", "Left profile", 345), ("right", "Right profile", 345),
        ("top", "Top", 214), ("underside", "Underside", 240),
        ("first_person", "First-person hold", 493), ("ads", "Aiming down sights", 493),
        ("stock_join", "Stock and receiver join", 472), ("action_join", "Receiver and shroud join", 472),
        ("inspect_detail", "Inspect insert and recessed seam", 472),
        ("ejection_join", "Ejection side and sight seat", 472), ("grip_mag_join", "Grip and magazine joins", 472),
        ("fore_end_join", "Recessed face, inlay and relief cuts", 472),
        ("brake_join", "Shroud, exposed shaft and brake joins", 472),
    ]
    rows += [(name, title, 472) for name, title in (
        ("front_sight_join", "Front sight saddle and shroud seat"),
        ("rear_sight_join", "Rear hood and rail seat"),
    ) if (captures / f"slipframe_{name}.png").is_file()]
    rows += [(f"pose_{pose}", label, 408) for pose, label in (
        ("Draw", "Stock draw pose"), ("Fire", "Stock fire pose"), ("Inspect", "Stock inspect pose"),
        ("Reload", "Stock reload pose"), ("ReloadEmpty", "Stock empty reload pose"),
    ) if (captures / f"slipframe_pose_{pose}.png").is_file()]
    if not (captures / "slipframe_inspect_detail.png").is_file():
        rows = [row for row in rows if row[0] != "inspect_detail"]
    margin, width, gutter = 58, 2048, 20
    column = (width - 2 * margin - gutter) // 2
    height = 199 + sum(h + 57 for _, _, h in rows) + 34
    image = Image.new("RGB", (width, height), "#161D28")
    draw = ImageDraw.Draw(image)
    draw.rectangle((margin, 48, margin + 44, 53), fill="#86AABF")
    draw.text((margin, 64), "Slipframe Guardian", font=font(49, True), fill="#E7ECF2")
    draw.text((width - margin, 81), f"{tier.upper()} · {version.upper()}", anchor="ra", font=font(24, True), fill="#86AABF")
    draw.text((margin, 145), "SLIPFRAME", font=font(24, True), fill="#B7DBF0")
    draw.text((margin + column + gutter, 145), "REMASTERV2 V05", font=font(24, True), fill="#B3BDC9")
    top = 184
    for name, label, h in rows:
        draw.text((margin, top + 2), label, font=font(20, True), fill="#DBE3EA")
        top += 38
        for index, variant in enumerate(("slipframe", "stock")):
            left = margin + index * (column + gutter)
            draw.rectangle((left, top, left + column, top + h), fill="#2D3541")
            fill_image(image, captures / f"{variant}_{name}.png", (left, top, column, h))
        top += h + 19
    path = folder / f"Guardian_{version}_review.png"
    image.save(path, optimize=True)
    print(path)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version")
    parser.add_argument("--tier", choices=("Rare", "Epic"), default="Rare")
    args = parser.parse_args()
    make_sheet(args.version, args.tier)
