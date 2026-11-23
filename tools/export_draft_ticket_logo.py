"""Export the approved Lobby Gold Draft Ticket from its letter outlines."""

import sys
from pathlib import Path

from PIL import Image
from psd_tools import PSDImage

from build_draft_duels_logo import OUT, SIZE, group, path, quake_out, render, svg
from explore_draft_duels_logo import (
    PALETTES, TICKET, TICKET_ANGLE, faces, font, ticket_layers, ticket_lettering,
)


DEST = OUT / "draft-ticket-lobby-gold"
GOLD = PALETTES["Lobby Gold"]


def wrap(part, contents):
    if part == "DRAFT ticket":
        return group("draft-ticket", contents, TICKET_ANGLE)
    return group("duels", contents)


def flatten(logo):
    return [wrap(name, layers.values()) for name, layers in logo.items()]


def mono_layers(rounded, ticket_font, color):
    draft, duels = ticket_lettering(rounded, ticket_font)
    inset = ("M279 54H721Q732 54 732 65V141Q732 152 721 152H279"
             "Q268 152 268 141V65Q268 54 279 54Z")
    return {
        "DRAFT ticket": {
            "Ticket outline": path(f"{TICKET} {inset}", color),
            "DRAFT letters": group("draft-type", faces(draft, color, prefix="mono-draft")),
        },
        "DUELS": {"DUELS letters": group("duels-type", faces(duels, color, prefix="mono-duels"))},
    }


def write_art(name, markup):
    (DEST / f"{name}.svg").write_text(svg(markup), encoding="utf-8")
    render(markup).save(DEST / f"{name}.png")


def export_psd(artwork):
    master = PSDImage.new("RGBA", (2000, 820))
    for name, parts in artwork.items():
        version = master.create_group(name=name, open_folder=False)
        version.visible = name == "Lobby Gold"
        for part, layers in parts.items():
            folder = version.create_group(name=part, open_folder=True)
            for label, markup in layers.items():
                layer = render([wrap(part, [markup])])
                box = layer.getbbox()
                folder.create_pixel_layer(layer.crop(box), name=label, top=box[1], left=box[0])
    master.save(DEST / "draft-ticket-lobby-gold.psd")


def export_sprites(art):
    sprites = DEST / "ui"
    sprites.mkdir(exist_ok=True)
    draft = art["DRAFT ticket"]
    stamp = draft["DRAFT letters"]
    exports = {
        "full": flatten(art),
        "draft-ticket": [wrap("DRAFT ticket", draft.values())],
        "ticket-plate": [wrap("DRAFT ticket", [layer for key, layer in draft.items()
                                              if key != "DRAFT letters"])],
        "draft-letters": [wrap("DRAFT ticket", [stamp])],
        "duels": [wrap("DUELS", art["DUELS"].values())],
    }
    for name, markup in exports.items():
        render(markup, 1).save(sprites / f"{name}.png")


def backdrop(size):
    return Image.new("RGBA", size, GOLD[-1])


def export_preview_and_motion(art):
    full = render(flatten(art), 1)
    preview = backdrop((1040, 446))
    preview.alpha_composite(full, (20, 18))
    preview.convert("RGB").save(DEST / "preview.png")

    ticket = render([wrap("DRAFT ticket", art["DRAFT ticket"].values())], .72)
    duels = render([wrap("DUELS", art["DUELS"].values())], .72)
    frames = []
    origin = (40, 54)

    def place(frame, image, dx, dy, opacity, pivot, scale=1, angle=0):
        if opacity <= 0:
            return
        if scale != 1:
            image = image.resize(tuple(round(v * scale) for v in image.size), Image.Resampling.LANCZOS)
        if angle:
            image = image.rotate(angle, resample=Image.Resampling.BICUBIC,
                                 center=tuple(v * scale for v in pivot))
        if opacity < 1:
            image = image.copy()
            image.putalpha(image.getchannel("A").point(lambda value: round(value * opacity)))
        x = round(origin[0] + dx + pivot[0] * (1 - scale))
        y = round(origin[1] + dy + pivot[1] * (1 - scale))
        frame.alpha_composite(image, (x, y))

    for index in range(25):
        ms = index * 25
        frame = backdrop((800, 404))
        pick = quake_out(ms / 230)
        fight = quake_out((ms - 215) / 280)
        impact = .025 * max(0, 1 - abs(ms - 360) / 100)
        place(frame, ticket, -64 * (1 - pick), -39 * (1 - pick), pick, (360, 74),
              .95 + .05 * pick, 10 * (1 - pick))
        place(frame, duels, 0, 34 * (1 - fight), fight, (360, 194), 1 + impact)
        frames.append(frame.convert("RGB"))
    frames[0].save(DEST / "draft-ticket-reveal.gif", save_all=True, append_images=frames[1:],
                   duration=[25] * (len(frames) - 1) + [1500], loop=0)


def main(folder):
    rounded = font(folder, "lilita.ttf")
    ticket_font = font(folder, "bricolage.ttf", wght=800, opsz=72)
    art = ticket_layers(GOLD, rounded, ticket_font)
    white = mono_layers(rounded, ticket_font, "#FFFFFF")
    black = mono_layers(rounded, ticket_font, "#111111")
    DEST.mkdir(exist_ok=True)
    write_art("draft-ticket-lobby-gold", flatten(art))
    write_art("base-white", flatten(white))
    write_art("base-black", flatten(black))
    export_psd({"Black base": black, "White base": white, "Lobby Gold": art})
    export_sprites(art)
    export_preview_and_motion(art)


if __name__ == "__main__":
    main(Path(sys.argv[1]))
