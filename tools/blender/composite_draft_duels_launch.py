"""Composite the Draft Duels launch plates, with editable transparent UI passes."""

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "art-source"
OUT = ART / "marketing/draft-duels"
GOLD = "#FFD23F"
INK = "#10141E"
WHITE = "#FFF7E9"
LOGO = ART / "ui/draft-duels/draft-ticket-lobby-gold/draft-ticket-lobby-gold.png"
UPDRAFT = ART / "ui/chatgpt/cards_v2/Updraft.png"
RESAMPLE = Image.Resampling.LANCZOS
SHOTS = {
    "01-lock-in": "Lock In / Mod draft",
    "02-foundry-duel": "Foundry Duel / first person",
    "03-blue-v-orange": "Blue vs. Orange / team rivalry",
    "04-rooftop-slide": "Rooftop Slide / movement",
    "05-tempest-inspect": "Tempest Inspect / cosmetic reveal",
}
ICONS = {"icon-lobby-gold": "Lobby Gold", "icon-bacon": "Bacon Hair", "icon-blue-v-orange": "Blue vs. Orange"}


def font(size):
    return ImageFont.truetype("C:/Windows/Fonts/bahnschrift.ttf", size)


def text(draw, xy, value, size, color, *, anchor=None, stroke=0):
    draw.text(xy, value, fill=color, font=font(size), anchor=anchor, stroke_width=stroke, stroke_fill=INK)


def stamp_logo(layer, x, y, width):
    logo = Image.open(LOGO).convert("RGBA")
    logo = logo.crop(logo.getbbox())
    logo.thumbnail((width, width), RESAMPLE)
    layer.alpha_composite(logo, (x, y))


def updraft_card():
    card = Image.new("RGBA", (430, 574))
    outline = [(22, 5), (386, 5), (415, 35), (415, 540), (389, 568), (14, 568), (4, 557), (4, 22)]
    mask = Image.new("L", card.size)
    ImageDraw.Draw(mask).polygon(outline, fill=255)
    card.paste(INK, (0, 0, *card.size), mask)
    art = Image.open(UPDRAFT).convert("RGB")
    art = art.crop((315, 110, 711, 506)).resize((398, 398), RESAMPLE)
    card.paste(art, (12, 15))
    draw = ImageDraw.Draw(card)
    draw.polygon([(12, 370), (408, 348), (408, 422), (12, 444)], fill="#76DFFF")
    text(draw, (33, 370), "HIGH RISE", 64, INK)
    text(draw, (34, 466), "UPDRAFT UPGRADE", 34, WHITE)
    text(draw, (35, 518), "LAUNCH HIGHER", 33, GOLD)
    draw.line(outline + [outline[0]], fill=GOLD, width=7, joint="curve")
    card.putalpha(ImageChops.multiply(card.getchannel("A"), mask))
    return card


def layer_for(name, size):
    layer = Image.new("RGBA", size)
    if name == "01-lock-in":
        card = updraft_card().rotate(9, Image.Resampling.BICUBIC, expand=True)
        shadow = Image.new("RGBA", card.size, (8, 14, 29, 255))
        shadow.putalpha(card.getchannel("A").point(lambda p: round(p * .79)))
        layer.alpha_composite(shadow, (140, 274))
        layer = layer.filter(ImageFilter.GaussianBlur(21))
        layer.alpha_composite(card, (116, 244))
        stamp_logo(layer, 126, 55, 381)
    if name == "03-blue-v-orange":
        draw = ImageDraw.Draw(layer)
        draw.polygon([(868, 745), (1075, 728), (1037, 895), (832, 914)], fill=INK, outline=GOLD, width=5)
        text(draw, (954, 824), "VS", 112, WHITE, anchor="mm")
    if name == "05-tempest-inspect":
        stamp_logo(layer, 89, 73, 325)
    return layer


def grade(plate, icon=False):
    plate = ImageEnhance.Color(plate).enhance(1.17 if icon else 1.22)
    plate = ImageEnhance.Contrast(plate).enhance(1.065)
    return plate.filter(ImageFilter.UnsharpMask(radius=1.25, percent=73, threshold=3))


def make_comps():
    plates, layers = OUT / "plates", OUT / "layers"
    exports = OUT / "exports"
    layers.mkdir(exist_ok=True)
    exports.mkdir(exist_ok=True)
    for name in SHOTS:
        plate = grade(Image.open(plates / f"{name}.png").convert("RGB"))
        assert plate.size == (1920, 1080), name
        ui = layer_for(name, plate.size)
        if ui.getbbox():
            ui.save(layers / f"{name}-ui.png", optimize=True)
        composite = Image.alpha_composite(plate.convert("RGBA"), ui).convert("RGB")
        path = exports / f"{name}.jpg"
        composite.save(path, quality=92, subsampling=0, optimize=True)
        assert path.stat().st_size < 3_000_000, path
    for name in ICONS:
        plate = grade(Image.open(plates / f"{name}.png").convert("RGB"), icon=True)
        plate.resize((512, 512), RESAMPLE).save(exports / f"{name}.png", optimize=True)


def make_review():
    exports = OUT / "exports"
    sheet = Image.new("RGB", (1440, 1500), "#141821")
    draw = ImageDraw.Draw(sheet)
    text(draw, (53, 31), "DRAFT DUELS / LAUNCH ART", 47, WHITE)
    for index, (name, label) in enumerate(SHOTS.items()):
        x = 53 + (index % 2) * 681
        y = 102 + (index // 2) * 386
        shot = Image.open(exports / f"{name}.jpg").resize((650, 366), RESAMPLE)
        sheet.paste(shot, (x, y))
        draw.rectangle((x, y + 321, x + 650, y + 365), fill=INK)
        text(draw, (x + 15, y + 328), label, 29, WHITE)
    x0, y0 = 734, 914
    text(draw, (x0, y0), "ICON CANDIDATES", 34, GOLD)
    for index, (name, label) in enumerate(ICONS.items()):
        x, y = x0 + index * 217, y0 + 55
        source = Image.open(exports / f"{name}.png")
        sheet.paste(source.resize((195, 195), RESAMPLE), (x, y))
        sheet.paste(source.resize((64, 64), RESAMPLE), (x, y + 212))
        text(draw, (x, y + 297), label, 23, WHITE)
    sheet = ImageOps.crop(sheet, (0, 0, 0, 163))
    sheet.save(OUT / "launch-art-review.jpg", quality=90, optimize=True)


if __name__ == "__main__":
    make_comps()
    make_review()
