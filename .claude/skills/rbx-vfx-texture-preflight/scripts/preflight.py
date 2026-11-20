"""Generate an offline alpha and flipbook inspection sheet for VFX textures."""

import argparse
import base64
from html import escape
from io import BytesIO
import json
from pathlib import Path
import sys

from PIL import Image


STYLES = """
body { font: 16px system-ui; max-width: 1050px; margin: auto; padding: 24px; color: #222; }
section { border-top: 1px solid #ccc; margin: 24px 0; }
.grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(180px, 1fr)); gap: 12px; }
figure { margin: 0; } figcaption { padding: 3px 0; }
"""


def preview(frame):
    sample = frame.copy()
    sample.thumbnail((84, 84))
    result = Image.new("RGB", (168, 84))
    for index, color in enumerate(("#25262a", "#eeeef2")):
        board = Image.new("RGBA", (84, 84), color)
        board.alpha_composite(sample, ((84 - sample.width) // 2, (84 - sample.height) // 2))
        result.paste(board.convert("RGB"), (84 * index, 0))
    encoded = BytesIO()
    result.save(encoded, format="PNG")
    return base64.b64encode(encoded.getvalue()).decode("ascii")


def scan_texture(entry, root, output):
    path = (root / entry["file"]).resolve()
    if path == output:
        raise ValueError("Report output and source texture must be separate files")
    columns, rows = entry["columns"], entry["rows"]
    if any(type(axis) is not int or axis < 1 for axis in (columns, rows)):
        raise ValueError("Grid dimensions must be positive integers")
    with Image.open(path) as source:
        if source.format not in ("PNG", "WEBP") or getattr(source, "n_frames", 1) != 1:
            raise ValueError("Use a static PNG or WebP texture sheet")
        image = source.convert("RGBA")
    width, height = image.size
    title = f"{escape(entry['file'])} · {width} × {height} · {columns} × {rows} grid"
    source = escape(entry.get("source") or "Unrecorded")
    usage = escape(entry.get("usage") or "Unrecorded")
    summary = f"<section><h2>{title}</h2><p>Source: {source}<br>Usage: {usage}</p>"
    if width % columns or height % rows or columns > width or rows > height:
        return summary + "<p>Grid does not divide the sheet into equal cells.</p></section>", True

    cell_width, cell_height = width // columns, height // rows
    flags = not entry.get("source") or not entry.get("usage")
    frames = []
    for row in range(rows):
        for column in range(columns):
            x, y = column * cell_width, row * cell_height
            cell = image.crop((x, y, x + cell_width, y + cell_height))
            alpha = cell.getchannel("A")
            minimum, maximum = alpha.getextrema()
            bounds = alpha.point(lambda value: 255 if value >= 16 else 0).getbbox()
            notes = []
            if bounds is None:
                notes.append("Blank or faint")
            elif bounds[0] == 0 or bounds[1] == 0 or bounds[2] == cell_width or bounds[3] == cell_height:
                notes.append("Visible alpha touches edge")
            if minimum == 255:
                notes.append("Fully opaque")
            elif maximum < 64 and bounds is not None:
                notes.append("Low alpha throughout")
            flags = flags or bool(notes)
            label = f"Frame {len(frames) + 1}"
            detail = " · ".join(notes)
            frames.append(
                f'<figure><img alt="{label} on dark and light" src="data:image/png;base64,{preview(cell)}">'
                f"<figcaption>{label}{' · ' + detail if detail else ''}</figcaption></figure>"
            )
    return summary + "<div class='grid'>" + "".join(frames) + "</div></section>", flags


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("report", type=Path)
    args = parser.parse_args()
    if args.report.suffix.lower() != ".html":
        parser.error("report must end in .html")
    try:
        output = args.report.resolve()
        data = json.loads(args.manifest.read_text(encoding="utf-8-sig"))
        if not data["textures"]:
            raise ValueError("Include at least one texture")
        sections = [scan_texture(entry, args.manifest.parent, output) for entry in data["textures"]]
        flagged = sum(flag for _, flag in sections)
        output.write_text(
            '<!doctype html><html lang="en"><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width, initial-scale=1">'
            f"<title>VFX texture preflight</title><style>{STYLES}</style>"
            f"<h1>VFX texture preflight</h1><p>{flagged} of {len(sections)} textures flagged for inspection.</p>"
            + "".join(section for section, _ in sections)
            + "</html>",
            encoding="utf-8",
        )
        print(f"{flagged} of {len(sections)} textures flagged. Report: {output}")
        return int(bool(flagged))
    except (OSError, ValueError, KeyError, TypeError, Image.DecompressionBombError) as error:
        print(f"Invalid texture input: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
