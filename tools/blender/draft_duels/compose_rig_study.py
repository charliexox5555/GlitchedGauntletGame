"""Composite launch icon variants and an avatar comparison from Blender plates."""

from io import BytesIO
from pathlib import Path
from xml.etree.ElementTree import Element, SubElement, tostring
from zipfile import ZIP_DEFLATED, ZIP_STORED, ZipFile

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[3]
STUDY = ROOT / "vault/03 Research/Rivals Reference/third-party/draft-duels-thumbnails/rig-study"
BRAND = ROOT / "art-source/ui/draft-duels"
OUTPUT = BRAND / "launch-art"
LOGO = BRAND / "draft-ticket-lobby-gold/draft-ticket-lobby-gold.png"
SIZE = 1024
LANCZOS = Image.Resampling.LANCZOS


def transparent(size=(SIZE, SIZE)):
    return Image.new("RGBA", size)


def wash(color, position, radius, intensity):
    mask = Image.radial_gradient("L").resize((radius, radius), LANCZOS)
    mask = ImageOps.invert(mask).point(lambda value: round(intensity * (value / 255) ** 2))
    glow = Image.new("RGBA", mask.size, (*color, 255))
    glow.putalpha(mask)
    layer = transparent()
    layer.alpha_composite(glow, (position[0] - radius//2, position[1] - radius//2))
    return layer


def background():
    base = Image.new("RGBA", (SIZE, SIZE), "#101015")
    base.alpha_composite(wash((144, 84, 25), (509, 435), 1810, 235))
    base.alpha_composite(wash((219, 133, 34), (389, 395), 1000, 125))
    draw = ImageDraw.Draw(base)
    for x in range(40, 1000, 26):
        for y in range(46, 810, 26):
            if (x-500) ** 2 + (y-400) ** 2 > 285**2:
                draw.point((x, y), fill="#875e36")
    return base


def ticket_shapes():
    layer = transparent()
    pen = ImageDraw.Draw(layer)
    back = [(236, 210), (548, 153), (621, 479), (594, 526), (301, 583),
            (281, 532), (266, 524), (222, 250)]
    front = [(468, 146), (760, 218), (789, 261), (714, 556), (675, 585),
             (363, 510), (351, 464), (414, 189)]
    pen.polygon(back, fill=(85, 52, 22, 198))
    pen.line(back + [back[0]], fill=(222, 150, 58, 178), width=4, joint="curve")
    pen.polygon(front, fill=(181, 119, 32, 178))
    pen.line(front + [front[0]], fill=(248, 183, 79, 215), width=4, joint="curve")
    pen.line([(46, 646), (247, 542)], fill=(255, 192, 76, 160), width=4)
    pen.line([(787, 390), (974, 293)], fill=(255, 192, 76, 175), width=4)
    pen.line([(827, 433), (921, 383)], fill=(255, 192, 76, 90), width=2)
    return layer


def trim():
    layer = transparent()
    draw = ImageDraw.Draw(layer)
    draw.polygon([(0, 0), (244, 0), (216, 18), (18, 18), (18, 165), (0, 179)], fill="#FFD23F")
    draw.polygon([(SIZE, SIZE), (SIZE-242, SIZE), (SIZE-215, SIZE-18), (SIZE-18, SIZE-18),
                  (SIZE-18, SIZE-165), (SIZE, SIZE-179)], fill="#E8A929")
    return layer


def insert(art, crop, width, position):
    result = transparent()
    art = art.crop(crop)
    art = art.resize((width, round(width*art.height/art.width)), LANCZOS)
    result.alpha_composite(art, position)
    return result


def light_spill(figure):
    mask = figure.getchannel("A")
    wide = ImageChops.subtract(mask.filter(ImageFilter.MaxFilter(15)).filter(ImageFilter.GaussianBlur(14)), mask)
    narrow = ImageChops.subtract(mask.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(3)), mask)
    light = Image.new("RGBA", figure.size, "#FFD163")
    light.putalpha(ImageChops.add(wide.point(lambda x: round(x*.66)), narrow))
    return light


def grade_gold(figure):
    source = figure.convert("RGB")
    # Keep the graphite rifle neutral. Increase the gold separation in pixels
    # already warmer than the rifle and cast-shadow blue.
    red, green, blue = source.split()
    warmth = ImageChops.subtract(red, blue).point(lambda value: min(180, value*3))
    gold = Image.merge("RGB", (red, green.point(lambda value: round(value*.89)),
                                blue.point(lambda value: round(value*.51))))
    graded = Image.composite(gold, source, warmth)
    graded.putalpha(figure.getchannel("A"))
    return graded


def footer():
    layer = transparent()
    fade = Image.linear_gradient("L").resize((SIZE, 385)).point(lambda x: min(245, round(x*1.36)))
    ink = Image.new("RGBA", fade.size, "#121116")
    ink.putalpha(fade)
    layer.alpha_composite(ink, (0, 642))
    return layer


def texture_logo(width, y):
    logo = Image.open(LOGO).convert("RGBA")
    return insert(logo, logo.getbbox(), width, ((SIZE-width)//2, y))


def flatten(layers):
    result = transparent(layers[0][1].size)
    for _, layer in layers:
        result.alpha_composite(layer)
    return result


def png_bytes(img):
    buffer = BytesIO()
    img.save(buffer, "PNG")
    return buffer.getvalue()


def layered_master(layers, merged):
    root = Element("image", w=str(SIZE), h=str(SIZE), version="0.0.3", name="Draft Duels · Gold icon")
    stack = SubElement(root, "stack")
    with ZipFile(STUDY / "Draft Duels - Gold Icon.ora", "w", ZIP_DEFLATED) as archive:
        archive.writestr("mimetype", "image/openraster", ZIP_STORED)
        for index, (name, layer) in enumerate(reversed(layers)):
            src = f"data/layer{index}.png"
            SubElement(stack, "layer", name=name, src=src, x="0", y="0", opacity="1.0",
                       visibility="visible", **{"composite-op": "svg:src-over"})
            archive.writestr(src, png_bytes(layer))
        archive.writestr("stack.xml", tostring(root, encoding="utf-8"))
        archive.writestr("mergedimage.png", png_bytes(merged))
        archive.writestr("Thumbnails/thumbnail.png", png_bytes(merged.resize((256, 256), LANCZOS)))


def icon(style):
    avatar = Image.open(STUDY / f"{style}-plate.png").convert("RGBA")
    top = avatar.getbbox()[1]
    scan_depth = 58 if style == "gold" else 106
    face_band = avatar.crop((0, top, avatar.width, top+scan_depth)).getbbox()
    left, right = face_band[0]-5, face_band[2]+5
    width = 510 if style == "gold" else 570
    depth = 188 if style == "gold" else 285
    portrait = avatar.crop((left, top-3, right, top+depth))
    fade = Image.new("L", portrait.size, 255)
    pen = ImageDraw.Draw(fade)
    for row in range(42):
        y = portrait.height-42+row
        pen.line(((0, y), (portrait.width, y)), fill=round(255*(1-row/41)**1.3))
    portrait.putalpha(ImageChops.multiply(portrait.getchannel("A"), fade))
    if style == "gold":
        # Remove the thin neutral gun-sight sliver crossing the portrait crop.
        red, _, blue = portrait.convert("RGB").split()
        warmth = ImageChops.subtract(red, blue).point(lambda level: min(255, max(0, level-12)*9))
        portrait.putalpha(ImageChops.multiply(portrait.getchannel("A"), warmth))
    avatar = insert(portrait, (0, 0, portrait.width, portrait.height), width, ((SIZE-width)//2, 160))
    if style == "gold":
        avatar = grade_gold(avatar)
    layers = [("Charcoal background", background()), ("Draft tickets", ticket_shapes()),
              ("Edge light", light_spill(avatar)), ("Blender avatar and Vandal", avatar),
              ("Logo shade", footer()), ("Draft Ticket wordmark", texture_logo(712, 670)),
              ("Corner accents", trim())]
    result = flatten(layers)
    result.convert("RGB").resize((512, 512), LANCZOS).save(OUTPUT / f"draft-duels-icon-{style}.png")
    if style == "gold":
        layered_master(layers, result)


def comparison():
    width, height = 1200, 640
    sheet = Image.new("RGB", (width, height), "#14151A")
    pen = ImageDraw.Draw(sheet)
    heading = ImageFont.truetype("arialbd.ttf", 37)
    label = ImageFont.truetype("arialbd.ttf", 23)
    small = ImageFont.truetype("arial.ttf", 18)
    pen.text((28, 24), "Draft Duels / avatar studies", font=heading, fill="#FFDD80")
    palettes = {"gold": ("#5C471C", "Gold silhouette"), "bacon": ("#413644", "Classic bacon"),
                "blue": ("#173750", "Blue team"), "orange": ("#512B21", "Orange team")}
    for index, (style, (color, name)) in enumerate(palettes.items()):
        x = 28 + index * 290
        panel = Image.new("RGBA", (274, 372), color)
        original = Image.open(STUDY / f"{style}-plate.png").convert("RGBA")
        avatar = original.crop((0, original.getbbox()[1]-4, 800, 800))
        avatar.thumbnail((275, 362), LANCZOS)
        panel.alpha_composite(avatar, ((274-avatar.width)//2, 64))
        sheet.paste(panel.convert("RGB"), (x, 86))
        pen.text((x, 472), name, font=label, fill="#F4EEE8")
    for index, style in enumerate(("gold", "bacon")):
        x = 28 + index * 190
        draft = Image.open(OUTPUT / f"draft-duels-icon-{style}.png")
        sheet.paste(draft.resize((96, 96), LANCZOS), (x, 525))
        sheet.paste(draft.resize((48, 48), LANCZOS), (x+107, 573))
    pen.text((426, 577), "Discovery size checks", font=small, fill="#B9B7BD")
    sheet.save(OUTPUT / "draft-duels-avatar-studies.jpg", quality=93, subsampling=0)


def package():
    """Collect the inputs that can travel independently of the licensed rig."""
    maps = ("CanyonOutpost", "Foundry4", "Rooftops4", "Snowpeak4")
    art = ROOT / "art-source"
    path = STUDY.parent / "Draft Duels - Thumbnail Handoff.zip"
    with ZipFile(path, "w", ZIP_DEFLATED, compresslevel=5) as archive:
        for name in ("Thumbnail Brief.md", "draft-duels-icon-gold.png",
                     "draft-duels-icon-bacon.png", "draft-duels-avatar-studies.jpg"):
            archive.write(OUTPUT / name, name)
        archive.write(STUDY / "Draft Duels - Gold Icon.ora", "Brand/Draft Duels - Gold Icon.ora")
        archive.write(LOGO, "Brand/Draft Ticket.png")
        archive.write(LOGO.with_suffix(".svg"), "Brand/Draft Ticket.svg")
        for name in maps:
            archive.write(STUDY / f"{name}.json", f"Maps/{name}/Studio Layout.json")
            for file in ("Kit.fbx", "Kit.json"):
                archive.write(art / "maps" / name / "Exports" / file, f"Maps/{name}/{file}")
        archive.write(STUDY / "materials.json", "Maps/Material Variants.json")
        for file in sorted((STUDY / "roblox-cache").glob("*.img")):
            with Image.open(file) as texture:
                suffix = texture.format.lower()
            archive.write(file, f"Maps/Textures/{file.stem}.{suffix}")
        for name in ("pal-hair.mesh", "pal-hair.png", "bacon-shirt.png", "bacon-pants.png"):
            archive.write(STUDY / name, f"Avatar/Bacon/{name}")
        for name in ("AimLevel", "AimDown", "Slide", "SlideIn", "SlideOut"):
            clip = f"GG_{name}.rbxm"
            archive.write(art / "animations" / clip, f"Avatar/Clips/{clip}")
        for source, name in (
            (art / "weapons/RemasterV2/Vandal/Vandal_RemasterV2_v05.blend", "Weapons/Vandal.blend"),
            (art / "weapons/Skins/Slipframe/Vandal/r03x/Vandal_Slipframe_r03x.blend",
             "Weapons/Vandal Slipframe r03x.blend"),
            (art / "abilities/FireVFX/FireVFX.blend", "Mods/FireVFX.blend"),
            (art / "abilities/Icons/Firewall.png", "Mods/Firewall icon.png"),
        ):
            archive.write(source, name)
    with ZipFile(path) as archive:
        bad_file = archive.testzip()
        if bad_file:
            raise ValueError(f"Invalid handoff archive member: {bad_file}")
        print(f"{len(archive.namelist())} verified handoff files: {path}")


if __name__ == "__main__":
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for style in ("gold", "bacon"):
        icon(style)
    comparison()
    package()
