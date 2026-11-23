"""Render two Draft Duels logo concepts and their palette comparison."""

import sys
from pathlib import Path

from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
from PIL import Image, ImageDraw

from build_draft_duels_logo import OUT, artwork, group, path, preview_font, render


STUDIES = OUT / "round-2"
CREAM = "#FFF7E9"
PALETTES = {
    "Sky Blue": ("#87C1FF", "#4A77BA", "#162337", "#354864", "#202D48"),
    "Grape": ("#CBB3FF", "#896BCC", "#241C3B", "#50416D", "#2D2246"),
    "Tangerine": ("#FFAA76", "#C76443", "#36201C", "#694434", "#472B28"),
    "Lime": ("#DAEF91", "#89A451", "#23291C", "#4A5638", "#2D3929"),
    "Bubblegum": ("#FFADC9", "#BE638A", "#361D30", "#68445D", "#432639"),
    "Lobby Gold": ("#FFD23F", "#CB932C", "#19181D", "#48434D", "#26242A"),
}


def font(folder, filename, **axes):
    face = TTFont(folder / filename)
    if axes:
        face = instantiateVariableFont(face, axes, inplace=True)
    return face.getBestCmap(), face.getGlyphSet()


def lettering(face, word, box, spacing, angles=()):
    cmap, glyphs = face
    metrics = []
    for letter in word:
        glyph = glyphs[cmap[ord(letter)]]
        bounds = BoundsPen(glyphs)
        glyph.draw(bounds)
        metrics.append((glyph, bounds.bounds))
    x, y, width, height = box
    available = width - spacing * (len(word) - 1)
    sx = available / sum(right - left for _, (left, _, right, _) in metrics)
    max_y = max(top for _, (_, _, _, top) in metrics)
    min_y = min(bottom for _, (_, bottom, _, _) in metrics)
    sy = height / (max_y - min_y)
    result = []
    for index, (glyph, (left, _, right, _)) in enumerate(metrics):
        commands = SVGPathPen(glyphs, ntos=lambda value: f"{value:.2f}")
        glyph.draw(TransformPen(commands, (sx, 0, 0, -sy, x - left * sx, y + max_y * sy)))
        angle = angles[index] if angles else 0
        center = x + (right - left) * sx / 2
        transform = f"rotate({angle} {center:.2f} {y + height / 2:.2f})" if angle else None
        result.append((commands.getCommands(), transform))
        x += (right - left) * sx + spacing
    return result


def faces(letters, color, stroke=None, weight=0, prefix="letter"):
    return [
        group(f"{prefix}-{index}", [
            path(outline, color, stroke, weight).replace('fill-rule="evenodd"', 'fill-rule="nonzero"')
        ], transform)
        for index, (outline, transform) in enumerate(letters)
    ]


def word_layers(name, letters, color, ink, rim, weight, drop):
    return {
        "Rim": group(f"{name}-rim", faces(letters, ink, rim, weight + 4, f"{name}-rim-letter"),
                     f"translate(0 {drop})"),
        "Depth": group(f"{name}-depth", faces(letters, ink, ink, weight, f"{name}-depth-letter"),
                       f"translate(0 {drop})"),
        "Faces": group(f"{name}-face", faces(letters, color, ink, weight, f"{name}-face-letter")),
    }


def word(name, letters, color, ink, rim, weight, drop):
    return group(name, word_layers(name, letters, color, ink, rim, weight, drop).values())


def original_layout(palette, rounded):
    accent, shade, ink, rim, _ = palette
    reference = artwork({
        "draft": (accent, shade, CREAM),
        "duels": (CREAM, "#DDD1BF", "#FFFFFF"),
        "rim": rim, "depth": ink, "ink": ink, "rail": accent,
    })
    draft = lettering(rounded, "DRAFT", (102, 43, 653, 104), 15, (-2, -1, 0, 1, 2))
    duels = lettering(rounded, "DUELS", (92, 192, 839, 152), 18, (-2, -1, 0, 1, 2))
    return [
        *[markup for _, markup in reference["Selection line"]],
        word("draft", draft, accent, ink, rim, 10, 10),
        *[markup for _, markup in reference["Cards"]],
        word("duels", duels, CREAM, ink, rim, 14, 14),
    ]


TICKET = ("M256 36 H744 Q765 36 765 57 V82 Q747 88 747 103 Q747 118 765 124 "
          "V149 Q765 170 744 170 H256 Q235 170 235 149 V124 Q253 118 253 103 "
          "Q253 88 235 82 V57 Q235 36 256 36 Z")
TICKET_ANGLE = "rotate(-5 500 103)"


def ticket_lettering(rounded, ticket_font):
    draft = lettering(ticket_font, "DRAFT", (307, 64, 386, 80), 9)
    duels = lettering(rounded, "DUELS", (96, 188, 808, 156), 16, (-2, -1, 0, 1, 2))
    return draft, duels


def ticket_layers(palette, rounded, ticket_font):
    accent, shade, ink, rim, _ = palette
    draft, duels = ticket_lettering(rounded, ticket_font)
    return {
        "DRAFT ticket": {
            "Ticket depth": group("ticket-depth", [path(TICKET, shade, ink, 10)], "translate(0 8)"),
            "Ticket face": path(TICKET, accent, ink, 10),
            "Ticket highlight": path("M267 51H733", "none", CREAM, 2),
            "DRAFT letters": group("draft-face", faces(draft, ink, prefix="draft-letter")),
        },
        "DUELS": word_layers("duels", duels, CREAM, ink, rim, 14, 14),
    }


def ticket_layout(palette, rounded, ticket_font):
    layers = ticket_layers(palette, rounded, ticket_font)
    return [group("ticket", layers["DRAFT ticket"].values(), TICKET_ANGLE),
            group("duels", layers["DUELS"].values())]


def make_board(rounded, ticket_font):
    board = Image.new("RGB", (1540, 1090), "#11131C")
    draw = ImageDraw.Draw(board)
    title = preview_font(45, True)
    heading = preview_font(23, True)
    label = preview_font(19, True)
    secondary = preview_font(15)
    draw.text((45, 32), "Draft Duels logo concepts", font=title, fill=CREAM)
    draw.text((46, 95), "Softer lettering in two layouts", font=heading, fill="#B4BECF")

    def panel(x, y, width, height, color):
        draw.rounded_rectangle((x, y, x + width, y + height), radius=16, fill=color, outline="#3D4456")

    def paste_center(markup, scale, center):
        im = render(markup, scale)
        board.paste(im, (round(center[0] - im.width / 2), round(center[1] - im.height / 2)), im)

    blue = PALETTES["Sky Blue"]
    for column, (name, description, logo) in enumerate((
        ("Original Layout", "Fanned cards and lock-in line with rounder letters", original_layout(blue, rounded)),
        ("Draft Ticket", "One pick ticket above the heavier second word", ticket_layout(blue, rounded, ticket_font)),
    )):
        x = 45 + column * 732
        panel(x, 140, 717, 324, blue[-1])
        paste_center(logo, .682, (x + 358, 304))
        draw.text((x, 478), name, font=heading, fill=CREAM)
        draw.text((x, 513), description, font=secondary, fill="#B4BECF")
        render(logo, 2).save(STUDIES / f"{name.lower().replace(' ', '-')}-concept.png")

    draw.line((45, 554, 1494, 554), fill="#414858")
    draw.text((45, 575), "Six colors across both layouts", font=heading, fill="#B4BECF")
    for index, (name, palette) in enumerate(PALETTES.items()):
        x = 45 + index % 3 * 490
        y = 623 + index // 3 * 210
        panel(x, y, 467, 165, palette[-1])
        draw.line((x + 234, y + 27, x + 234, y + 138), fill="#616674", width=1)
        paste_center(original_layout(palette, rounded), .216, (x + 115, y + 84))
        paste_center(ticket_layout(palette, rounded, ticket_font), .216, (x + 351, y + 84))
        draw.text((x + 1, y + 174), name, font=label, fill=CREAM)
        draw.rounded_rectangle((x + 348, y + 176, x + 369, y + 197), radius=4, fill=palette[0])
        draw.text((x + 380, y + 176), palette[0], font=secondary, fill="#B4BECF")
    board.save(STUDIES / "logo-studies.png")


if __name__ == "__main__":
    folder = Path(sys.argv[1])
    STUDIES.mkdir(exist_ok=True)
    make_board(font(folder, "lilita.ttf"), font(folder, "bricolage.ttf", wght=800, opsz=72))
