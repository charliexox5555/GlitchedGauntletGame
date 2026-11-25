"""Build the PowerDuels brand assets and the loading-screen image set."""

import sys
from pathlib import Path

from PIL import Image, ImageDraw
from psd_tools import PSDImage

from build_draft_duels_logo import group, path, preview_font, quake_out, render, svg
from explore_draft_duels_logo import faces, font, lettering, word_layers


OUT = Path(__file__).resolve().parents[1] / "art-source" / "ui" / "powerduels"
GOLD, LIGHT, AMBER, INK, RIM = "#FFD23F", "#FFF6DF", "#E48E28", "#211A22", "#62505B"
BG = "#201D25"
BADGE = ("M229 45 Q237 32 260 32 H786 Q817 32 828 54 L845 94 Q849 104 841 115 "
         "L797 170 Q784 185 760 185 H234 Q203 185 196 160 L186 117 Q181 100 194 84 Z")
INSET = ("M238 55 Q245 45 262 45 H783 Q805 45 814 61 L831 96 Q834 101 829 107 "
         "L787 161 Q779 172 759 172 H236 Q215 172 209 154 L199 115 Q196 104 204 93 Z")
TILT = "rotate(-4 515 108)"
BOLT = "M41 4H74L55 35H82L34 91 41 53H13Z"
ICON_BOX = (0, 0, 256, 256)
WIDE_BOX = (0, 0, 1000, 206)


def title_type(folder):
    return font(folder, "lilita.ttf")


def gold_parts(face):
    power = lettering(face, "POWER", (242, 69, 482, 94), 14, (-3, -1, 0, 1, 2))
    duels = lettering(face, "DUELS", (91, 188, 818, 154), 15, (-5, -2, 0, 2, 5))
    plate = {
        "Badge depth": group("power-depth", [path(BADGE, AMBER, INK, 13)], "translate(0 12)"),
        "Badge face": group("power-plate", [path(BADGE, GOLD, INK, 12)]),
        "Badge glint": group("power-glint", [
            path("M262 46H777Q795 46 801 55L804 60H258L251 65H240Z", LIGHT),
            path("M217 156H790L784 165Q778 173 758 173H235Q223 173 217 156Z", "#F4AF2C"),
        ]),
        "POWER letters": group("power-letters", faces(power, INK, prefix="power-letter")),
        "Bolt": group("power-bolt", [path(BOLT, INK)], "translate(730 58) scale(1.02)"),
    }
    lower = word_layers("duels", duels, LIGHT, INK, RIM, 16, 17)
    sparks = {"Sparks": group("sparks", [
        path("M145 63 160 85 139 80 126 64Z M150 119 166 130 142 138 126 133Z", GOLD, INK, 5),
        path("M866 54 884 38 886 55 870 72Z M878 105 902 94 914 102 897 114Z", GOLD, INK, 5),
    ])}
    return {"POWER": plate, "DUELS": lower, "Sparks": sparks}


def wrap(name, layers):
    return group(f"{name.lower()}-group", layers, TILT if name == "POWER" else None)


def flatten(parts):
    return [wrap(name, layers.values()) for name, layers in parts.items()]


def mono(face, color):
    power = lettering(face, "POWER", (242, 69, 482, 94), 14, (-3, -1, 0, 1, 2))
    duels = lettering(face, "DUELS", (91, 188, 818, 154), 15, (-5, -2, 0, 2, 5))
    return {
        "POWER": {
            "Badge outline": path(f"{BADGE} {INSET}", color),
            "POWER letters": group("mono-power", faces(power, color, prefix="mono-p")),
            "Bolt": group("mono-bolt", [path(BOLT, color)], "translate(730 58) scale(1.02)"),
        },
        "DUELS": {"DUELS letters": group("mono-duels", faces(duels, color, prefix="mono-d"))},
    }


def icon():
    shell = ("M72 26H191Q210 26 216 45L232 109Q235 121 227 135L186 210"
             "Q180 221 165 221H60Q42 221 37 204L23 141Q20 128 28 113L58 44Q64 26 72 26Z")
    return [
        group("icon-depth", [path(shell, AMBER, INK, 13)], "translate(0 9)"),
        path(shell, GOLD, INK, 12),
        path("M75 43H191Q201 43 204 52H71Z", LIGHT),
        group("icon-bolt", [path(BOLT, INK)], "translate(55 51) scale(1.5)"),
    ]


def horizontal(face):
    power = lettering(face, "POWER", (45, 59, 411, 91), 10)
    duels = lettering(face, "DUELS", (534, 51, 416, 105), 10)
    badge = "M51 38H475Q491 38 498 53L513 92Q516 103 507 113L477 154Q470 166 454 166H41Q25 166 21 152L9 111Q6 101 13 89L37 50Q42 38 51 38Z"
    return [
        group("wide-power", [
            group("wide-depth", [path(badge, AMBER, INK, 7)], "translate(0 7)"),
            path(badge, GOLD, INK, 8),
            *faces(power, INK, prefix="wide-p"),
        ], "translate(10 0)"),
        group("wide-duels", word_layers("wide-duels", duels, LIGHT, INK, RIM, 10, 10).values()),
    ]


def export_vector(name, art, box=None, scale=2):
    (OUT / f"{name}.svg").write_text(svg(art, box) if box else svg(art), encoding="utf-8")
    image = render(art, scale, box) if box else render(art, scale)
    image.save(OUT / f"{name}.png")
    return image


def photoshop(versions):
    psd = PSDImage.new("RGBA", (2000, 820))
    for name, art in versions.items():
        top = psd.create_group(name=name, open_folder=False)
        top.visible = name == "Lobby Gold"
        for part, layers in art.items():
            folder = top.create_group(name=part)
            for layer, markup in layers.items():
                image = render([wrap(part, [markup])])
                bounds = image.getbbox()
                folder.create_pixel_layer(image.crop(bounds), layer, top=bounds[1], left=bounds[0])
    psd.save(OUT / "powerduels.psd")


def make_ui(parts):
    folder = OUT / "ui"
    folder.mkdir(exist_ok=True)
    for part, layers in parts.items():
        render([wrap(part, layers.values())], 1).save(folder / f"{part.lower()}.png")
    mark = render(flatten(parts), 1)
    mark.save(folder / "full.png")
    mask = Image.new("RGBA", mark.size, "white")
    mask.putalpha(mark.getchannel("A"))
    mask.save(folder / "shine-mask.png")


def motion():
    frames = []
    power, duels, sparks = (Image.open(OUT / "ui" / f"{name}.png").resize((720, 295),
                            Image.Resampling.LANCZOS) for name in ("power", "duels", "sparks"))

    def paste(frame, art, amount, x=0, y=0, zoom=1):
        if not amount:
            return
        im = art.resize(tuple(round(v * zoom) for v in art.size), Image.Resampling.LANCZOS)
        im.putalpha(im.getchannel("A").point(lambda a: round(a * amount)))
        frame.alpha_composite(im, (round(40 + x + (art.width - im.width) / 2),
                                   round(58 + y + (art.height - im.height) / 2)))

    for i in range(25):
        t = i * 25
        p = quake_out(t / 235)
        d = quake_out((t - 185) / 315)
        s = quake_out((t - 340) / 180)
        pop = .028 * max(0, 1 - abs(t - 350) / 105)
        frame = Image.new("RGBA", (800, 405), BG)
        paste(frame, power, p, -46 * (1 - p), -32 * (1 - p), .93 + .07 * p)
        paste(frame, duels, d, 0, 48 * (1 - d), 1 + pop)
        paste(frame, sparks, s, 0, 0, .96 + .04 * s)
        frames.append(frame.convert("RGB"))
    frames[0].save(OUT / "powerduels-reveal.gif", save_all=True, append_images=frames[1:],
                   loop=0, duration=[25] * (len(frames) - 1) + [1400])


def sheet(primary, wide, bolt, white, black):
    board = Image.new("RGB", (1500, 1120), "#14121A")
    draw = ImageDraw.Draw(board)
    ivory = LIGHT
    muted = "#BDB6C6"

    def card(x, y, w, h, bg, art, image_size, label, label_color=ivory):
        draw.rounded_rectangle((x, y, x + w, y + h), 16, fill=bg, outline="#544854")
        draw.text((x + 22, y + 18), label, fill=label_color, font=preview_font(18, True))
        preview = art.copy()
        preview.thumbnail(image_size, Image.Resampling.LANCZOS)
        board.paste(preview, (x + (w - preview.width) // 2, y + 32 + (h - 32 - preview.height) // 2), preview)

    draw.text((48, 25), "POWERDUELS", fill=ivory, font=preview_font(53, True))
    draw.text((50, 95), "Logo and UI assets", fill=muted, font=preview_font(20))
    card(48, 139, 936, 455, BG, primary, (892, 368), "Primary logo")
    card(1006, 139, 446, 455, BG, bolt, (296, 296), "Power badge")
    card(48, 616, 820, 231, BG, wide, (730, 151), "Horizontal logo")
    card(890, 616, 562, 231, "#292532", white, (498, 172), "White base")
    card(48, 869, 610, 212, "#FFF6DF", black, (438, 154), "Black base", INK)
    colors = (("Lobby Gold", GOLD), ("Warm light", LIGHT), ("Amber", AMBER), ("Ink", INK))
    for i, (label, color) in enumerate(colors):
        x = 688 + i * 190
        draw.rounded_rectangle((x, 916, x + 168, 973), 9, fill=color, outline="#62505B")
        draw.text((x, 989), label, fill=ivory, font=preview_font(18, True))
        draw.text((x, 1017), color, fill=muted, font=preview_font(15))
    board.save(OUT / "powerduels-logo-sheet.png")


def main(font_dir):
    OUT.mkdir(parents=True, exist_ok=True)
    face = title_type(font_dir)
    parts = gold_parts(face)
    white, black = mono(face, "#FFFFFF"), mono(face, "#17141A")
    primary = export_vector("powerduels", flatten(parts))
    horizontal_logo = export_vector("powerduels-horizontal", horizontal(face), WIDE_BOX, 2)
    badge = export_vector("power-badge", icon(), ICON_BOX, 4)
    white_preview = export_vector("base-white", flatten(white))
    black_preview = export_vector("base-black", flatten(black))
    photoshop({"Black base": black, "White base": white, "Lobby Gold": parts})
    make_ui(parts)
    motion()
    sheet(primary, horizontal_logo, badge, white_preview, black_preview)


if __name__ == "__main__":
    main(Path(sys.argv[1]))
