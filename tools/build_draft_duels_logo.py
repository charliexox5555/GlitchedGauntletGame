"""Export the Draft Duels vector master, layered Photoshop and UI artwork."""

import io
import math
from pathlib import Path

from PIL import Image, ImageColor, ImageDraw, ImageFont
from psd_tools import PSDImage
import skia


OUT = Path(__file__).resolve().parents[1] / "art-source" / "ui" / "draft-duels"
SIZE = (1000, 410)
SCALE = 2

# Original letter outlines and counters, drawn on a shared cap-height grid.
GLYPHS = {
    "D": (103, "M0 7 7 0H76L102 23V74L79 100H0Z M27 25V75H65L75 64V36L64 25Z"),
    "R": (105, "M0 7 7 0H81L103 19V49L85 66 106 100H73L53 68H27V100H0Z M27 23V46H68L76 39V30L68 23Z"),
    "A": (110, "M34 0H79L112 100H83L77 80H35L28 100H0Z M44 56H69L58 23H55Z"),
    "F": (94, "M0 7 7 0H94V25H28V43H80V67H28V100H0Z"),
    "T": (104, "M6 0H104V26H65V100H37V26H0V7Z"),
    "U": (102, "M0 0H28V65L37 75H66L75 64V0H103V75L79 100H24L0 76Z"),
    "E": (96, "M0 7 7 0H96V24H28V38H82V61H28V76H96V100H0Z"),
    "L": (89, "M0 0H28V74H89V94L83 100H0Z"),
    "S": (101, "M19 0H94L101 8V25H33L27 30V35L33 39H79L101 58V80L82 100H6L0 93V75H69L74 70V66L69 62H22L0 44V20Z"),
}

PALETTES = {
    "lobby-gold": {
        "draft": ("#FFD23F", "#EAA71D", "#FFF0A1"),
        "duels": ("#F5F7FA", "#CCD2DE", "#FFFFFF"),
        "rim": "#52525E", "depth": "#292A33", "ink": "#121218",
        "rail": "#FFD23F", "bg": "#151518",
    },
    "arcade-mint": {
        "draft": ("#6EF1BD", "#35C49D", "#C7FFE1"),
        "duels": ("#FFF3DB", "#E5CDAE", "#FFFEF1"),
        "rim": "#43516E", "depth": "#28344E", "ink": "#15192A",
        "rail": "#FF9E77", "bg": "#181B2D",
    },
}


def path(d, fill, stroke=None, width=1):
    edge = f' stroke="{stroke}" stroke-width="{width}" stroke-linejoin="round"' if stroke else ""
    return f'<path d="{d}" fill="{fill}" fill-rule="evenodd"{edge}/>'


def group(name, contents, transform=None):
    transform = f' transform="{transform}"' if transform else ""
    return f'<g id="{name}"{transform}>{"".join(contents)}</g>'


def svg(contents, box=(0, 0, *SIZE)):
    x, y, w, h = box
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" '
        f'viewBox="{x} {y} {w} {h}">\n' + "\n".join(contents) + "\n</svg>\n"
    )


def glyph_positions(word, spacing):
    x = 0
    for letter, gap in zip(word, spacing, strict=True):
        width, outline = GLYPHS[letter]
        yield letter, x, width, outline
        x += width + gap


def word_layers(name, transform, spacing, colors, palette):
    face, facet, highlight = colors
    letters = list(glyph_positions(name.upper(), spacing))
    layers = {"Keyline": [], "Depth": [], "Faces": [], "Facets": [], "Top edges": []}
    for letter, x, width, outline in letters:
        key = f"{name}-{letter}"
        silhouette = outline.split(" M", 1)[0]
        layers["Keyline"].append(group(f"{key}-keyline", [
            path(silhouette, palette["ink"], palette["rim"], 13),
            path(silhouette, palette["ink"], palette["ink"], 10),
        ], f"translate({x + 1} 10)"))
        layers["Depth"].append(group(f"{key}-depth", [
            path(outline, palette["depth"], palette["ink"], 8),
        ], f"translate({x + 1} 7)"))
        layers["Faces"].append(group(f"{key}-face", [
            path(outline, face, palette["ink"], 4),
        ], f"translate({x} 0)"))
        # Short bevels leave the main faces uninterrupted.
        layers["Facets"].append(group(f"{key}-facet", [
            f'<clipPath id="{key}-clip-low">{path(outline, "white")}</clipPath>',
            f'<path clip-path="url(#{key}-clip-low)" d="M-2 93H{width-18}L{width+3} 73V105H-2Z" fill="{facet}"/>',
            path(outline, "none", palette["ink"], 3),
        ], f"translate({x} 0)"))
        layers["Top edges"].append(group(f"{key}-edge", [
            f'<clipPath id="{key}-clip-top">{path(outline, "white")}</clipPath>',
            f'<path clip-path="url(#{key}-clip-top)" d="M-2 3H{width+2}V6H-2Z" fill="{highlight}"/>',
        ], f"translate({x} 0)"))
    return [(label, group(f"{name}-{i}", shapes, transform))
            for i, (label, shapes) in enumerate(layers.items())]


CARD = "M9 0H58L70 12V79L61 88H0V9Z"
CARD_SYMBOL = "M15 44 28 31 35 38 27 46 35 54 28 61Z M55 44 42 31 35 38 43 46 35 54 42 61Z"
REAR_TRANSFORM = "translate(801 52) rotate(-17 35 44)"
FRONT_TRANSFORM = "translate(856 52) rotate(13 35 44)"
DRAFT_TRANSFORM = "matrix(1.18 0 -.19 1.13 127 38)"
DUELS_TRANSFORM = "matrix(1.55 0 -.23 1.61 110 184)"
DRAFT_SPACING = (14, 15, 13, 12, 0)
DUELS_SPACING = (12, 13, 12, 12, 0)


def artwork(palette):
    draft = word_layers("draft", DRAFT_TRANSFORM, DRAFT_SPACING, palette["draft"], palette)
    duels = word_layers("duels", DUELS_TRANSFORM, DUELS_SPACING, palette["duels"], palette)
    rear = group("card-rear", [
        path(CARD, palette["depth"], palette["rim"], 12),
        path(CARD, palette["depth"], palette["ink"], 8),
        path("M10 15H16V63H10Z M10 70H16V76H10Z", palette["rail"]),
    ], REAR_TRANSFORM)
    front = group("card-front", [
        path(CARD, palette["ink"], palette["rim"], 13),
        path(CARD, palette["draft"][0], palette["ink"], 8),
        path("M4 74H66V78L59 84H4Z", palette["draft"][1]),
        path("M16 9H50L56 15H16Z", palette["draft"][2]),
        path(CARD_SYMBOL, palette["ink"]),
    ], FRONT_TRANSFORM)
    rail = group("selection-line-art", [
        path("M105 166H945L938 176H99L94 173Z", palette["depth"], palette["ink"], 4),
        path("M108 168H765L761 172H104Z M784 168H938L934 172H780Z", palette["rail"]),
    ])
    return {
        "Selection line": [("Selection line", rail)],
        "Draft": draft,
        "Cards": [("Rear card", rear), ("Selected card", front)],
        "Duels": duels,
    }


def render(contents, scale=SCALE, box=(0, 0, *SIZE)):
    _, _, w, h = box
    surface = skia.Surface(round(w * scale), round(h * scale))
    canvas = surface.getCanvas()
    canvas.scale(scale, scale)
    dom = skia.SVGDOM.MakeFromStream(skia.MemoryStream(svg(contents, box).encode()))
    if dom is None:
        raise ValueError("SVG failed to parse")
    dom.render(canvas)
    png = surface.makeImageSnapshot().encodeToData()
    return Image.open(io.BytesIO(bytes(png))).convert("RGBA")


def flatten(groups):
    return [markup for layers in groups.values() for _, markup in layers]


def export_psd(versions):
    psd = PSDImage.new("RGBA", tuple(v * SCALE for v in SIZE))
    for name, groups in reversed(list(versions.items())):
        theme = psd.create_group(name=name, open_folder=False)
        for part_name, layers in groups.items():
            part = theme.create_group(name=part_name, open_folder=False)
            for label, markup in layers:
                image = render([markup])
                box = image.getbbox()
                if box is None:
                    raise ValueError(f"Empty layer {label}")
                part.create_pixel_layer(image.crop(box), name=label, left=box[0], top=box[1])
        theme.visible = name == "Lobby Gold"
    psd.save(OUT / "draft-duels.psd")


def mono_art(color):
    words = [
        group(name.lower(), [
            group(f"{name}-{letter}", [path(outline, color)], f"translate({x} 0)")
            for letter, x, _, outline in glyph_positions(name, spacing)
        ], transform)
        for name, spacing, transform in (
            ("DRAFT", DRAFT_SPACING, DRAFT_TRANSFORM), ("DUELS", DUELS_SPACING, DUELS_TRANSFORM)
        )
    ]
    # The shorter rear card preserves a transparent seam between the pieces.
    rear = group("back-card", [path("M9 0H54L34 88H0V9Z", color)], REAR_TRANSFORM)
    front = group("front-card", [path(f"{CARD} {CARD_SYMBOL}", color)], FRONT_TRANSFORM)
    rail = path("M108 168H765L761 172H104Z M784 168H938L934 172H780Z", color)
    return {
        "Selection line": [("Shape", rail)],
        "Draft": [("Letters", words[0])],
        "Cards": [("Rear card", rear), ("Selected card", front)],
        "Duels": [("Letters", words[1])],
    }


def quake_out(value):
    return 1 - (1 - max(0, min(1, value))) ** 5


def export_motion(groups):
    parts = {
        label: render([markup for _, markup in layers], scale=.72)
        for label, layers in groups.items()
    }
    rear, front = [render([markup], scale=.72) for _, markup in groups["Cards"]]
    stage = (800, 420)
    origin = (25, 63)
    frames = []

    def paste(frame, art, x=0, y=0, opacity=1, scale=1):
        image = art
        if scale != 1:
            image = image.resize(tuple(round(d * scale) for d in image.size), Image.Resampling.LANCZOS)
        if opacity < 1:
            image = image.copy()
            image.putalpha(image.getchannel("A").point(lambda a: round(a * max(0, opacity))))
        pos = (round(origin[0] + x + (art.width - image.width) / 2),
               round(origin[1] + y + (art.height - image.height) / 2))
        frame.alpha_composite(image, pos)

    backdrop = Image.new("RGBA", stage, PALETTES["lobby-gold"]["bg"])
    draw = ImageDraw.Draw(backdrop)
    draw.line((35, 364, 765, 364), fill="#3A3A43")
    font = preview_font(13, True)
    draw.text((35, 381), "DRAFT DUELS   /   LOBBY TITLE", fill="#B6B6C2", font=font)
    for i in range(31):
        ms = i * 30
        frame = backdrop.copy()
        draft = quake_out(ms / 220)
        picked = quake_out((ms - 105) / 170)
        backs = quake_out((ms - 45) / 185)
        duel = quake_out((ms - 265) / 220)
        rail = parts["Selection line"].copy()
        reveal = round(rail.width * quake_out((ms - 170) / 195))
        if reveal:
            paste(frame, rail.crop((0, 0, reveal, rail.height)), x=-(rail.width - reveal) / 2)
        paste(frame, parts["Draft"], x=-64 * (1 - draft), opacity=draft)
        paste(frame, rear, y=20 * (1 - backs), opacity=backs)
        paste(frame, front, x=19 * (1 - picked), y=-22 * (1 - picked), opacity=picked)
        if 235 <= ms < 385:
            spark = Image.new("RGBA", stage)
            light = ImageDraw.Draw(spark)
            opacity = round(255 * (1 - (ms - 235) / 150))
            radius = (ms - 235) / 12
            for angle in (-1.28, -.68, .08):
                x, y = 690 + math.cos(angle) * radius, 113 + math.sin(angle) * radius
                light.line((x, y, x + 8 * math.cos(angle), y + 8 * math.sin(angle)),
                           fill=(255, 220, 104, opacity), width=2)
            frame.alpha_composite(spark)
        settle = 1 + 0.024 * max(0, 1 - abs(ms - 405) / 100)
        paste(frame, parts["Duels"], y=55 * (1 - duel), opacity=duel, scale=settle)
        frames.append(frame.convert("RGB"))
    frames[0].save(OUT / "title-animation.gif", save_all=True, append_images=frames[1:],
                   duration=[30] * (len(frames) - 1) + [1500], loop=0, optimize=True)


def preview_font(size, bold=False):
    return ImageFont.truetype("segoeuib.ttf" if bold else "segoeui.ttf", size)


def export_preview(versions):
    image = Image.new("RGB", (1344, 655), "#101016")
    draw = ImageDraw.Draw(image)
    draw.text((45, 35), "DRAFT DUELS", font=preview_font(35, True), fill="#F5F7FA")
    draw.text((46, 86), "LOBBY TITLE  /  PALETTE STUDY", font=preview_font(14, True), fill="#A3A4B1")
    for index, (name, groups) in enumerate(versions.items()):
        x = 45 + index * 639
        colors = PALETTES[name.lower().replace(" ", "-")]
        draw.rounded_rectangle((x, 137, x+614, 440), radius=11, fill=colors["bg"], outline="#3A3A46")
        logo = render(flatten(groups), .62)
        image.paste(logo, (x-16, 162), logo)
        draw.text((x+1, 463), name, font=preview_font(25, True), fill="#F5F7FA")
        for px, color in enumerate((colors["draft"][0], colors["duels"][0], colors["rail"], colors["ink"])):
            if color in (colors["draft"][0],) and px == 2:
                continue
            px = x + 2 + (px - (name == "Lobby Gold" and px == 3)) * 91
            draw.rounded_rectangle((px, 512, px+71, 546), radius=5, fill=ImageColor.getrgb(color), outline="#535460")
            draw.text((px, 554), color, font=preview_font(13), fill="#B9BAC5")
        tiny = logo.resize((184, 75), Image.Resampling.LANCZOS)
        image.paste(tiny, (x+420, 471), tiny)
    draw.line((45, 598, 1298, 598), fill="#393941")
    draw.text((45, 613), "Original lettering  /  Paired draft cards  /  Two-beat reveal",
              font=preview_font(15), fill="#AAABB8")
    image.save(OUT / "palette-preview.png")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    versions = {}
    for slug, palette in PALETTES.items():
        groups = artwork(palette)
        versions[slug.replace("-", " ").title()] = groups
        merged = [
            group(part_name.lower().replace(" ", "-"), [markup for _, markup in layers])
            for part_name, layers in groups.items()
        ]
        (OUT / f"{slug}.svg").write_text(svg(merged), encoding="utf-8")
        render(merged).save(OUT / f"{slug}.png")
        ui = OUT / slug
        ui.mkdir(exist_ok=True)
        # The full and part images share one canvas, so their anchors match.
        for part_name, layers in groups.items():
            markup = [m for _, m in layers]
            render(markup, 1).save(ui / f"{part_name.lower().replace(' ', '-')}.png")
            if part_name == "Cards":
                for label, raw in layers:
                    render([raw], 1).save(ui / f"{label.lower().replace(' ', '-')}.png")
        render(merged, 1).save(ui / "full.png")
        render([m for _, m in groups["Cards"]], 4, (778, 28, 170, 143)).save(ui / "card-icon.png")
    for slug, color in (("base-white", "#FFFFFF"), ("base-black", "#111111")):
        base = flatten(mono_art(color))
        (OUT / f"{slug}.svg").write_text(svg(base), encoding="utf-8")
        render(base).save(OUT / f"{slug}.png")
    export_psd({**versions, "Monochrome": mono_art("#FFFFFF")})
    export_preview(versions)
    export_motion(versions["Lobby Gold"])


if __name__ == "__main__":
    main()
