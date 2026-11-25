"""Build an offline report from paired screenshots and a feature ledger."""

import argparse
import base64
from collections import Counter, defaultdict
import html
import json
import math
from pathlib import Path
import sys


FORMATS = {".png": "png", ".jpg": "jpeg", ".jpeg": "jpeg", ".webp": "webp"}
STATUSES = ("PASS", "MISMATCH", "UNVERIFIED")


def image_uri(root, name, output):
    if not name:
        return ""
    path = (root / name).resolve()
    if path == output:
        raise ValueError("Report output and source image must be separate files")
    kind = FORMATS.get(path.suffix.lower())
    if kind is None:
        raise ValueError(f"Unsupported screenshot format: {path.name}")
    if not path.is_file():
        return ""
    return f"data:image/{kind};base64,{base64.b64encode(path.read_bytes()).decode('ascii')}"


def normalized_point(values):
    if not isinstance(values, list) or len(values) != 2:
        raise ValueError("A point must be [x, y]")
    if any(type(value) not in (int, float) or not 0 <= value <= 1 for value in values):
        raise ValueError("Point coordinates must be numbers within 0–1")
    return values


def assess(row, view):
    note = row.get("note", "").strip()
    if not view["reference_uri"] or not view["capture_uri"]:
        return "UNVERIFIED", "Reference or build capture is missing."
    if "expected_count" in row:
        target, actual = row["expected_count"], row.get("observed_count")
        if type(target) is not int or target < 0:
            raise ValueError("expected_count must be a nonnegative integer")
        if actual is None:
            return "UNVERIFIED", note or "No observed count."
        if type(actual) is not int or actual < 0:
            raise ValueError("observed_count must be a nonnegative integer")
        return ("PASS" if target == actual else "MISMATCH",
                f"Expected {target}, observed {actual}. {note}".strip())
    if "reference_point" in row:
        target = normalized_point(row["reference_point"])
        if view.get("comparable") is not True or row.get("capture_point") is None:
            return "UNVERIFIED", "Matched framing or corresponding build landmark is unavailable."
        actual = normalized_point(row["capture_point"])
        tolerance = row.get("tolerance")
        if type(tolerance) not in (int, float) or not 0 <= tolerance <= 1:
            raise ValueError("Landmark checks require a tolerance in 0–1")
        drift = math.dist(target, actual)
        return ("PASS" if drift <= tolerance else "MISMATCH",
                f"Normalized drift {drift:.4f} / tolerance {tolerance:.4f}. {note}".strip())
    status = row.get("status", "unverified").upper()
    if status not in STATUSES:
        raise ValueError("Manual status must be pass, mismatch, or unverified")
    if not note:
        return "UNVERIFIED", "No observation recorded."
    return status, note


CSS = """
body { font: 16px system-ui; max-width: 1000px; padding: 24px; margin: auto; color: #222; }
section { margin: 30px 0; }
.pair { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; }
figure { margin: 0; } img { display: block; width: 100%; height: auto; }
figcaption { margin-bottom: 5px; font-weight: 650; }
li { margin: 9px 0; } .MISMATCH { color: #a02228; } .UNVERIFIED { color: #795000; }
.PASS { color: #155b38; } .overlay { position: relative; width: min(100%, 680px); }
.overlay img + img { position: absolute; top: 0; left: 0; opacity: .5; height: 100%; }
details { margin-top: 12px; }
"""


def report(manifest_path, output):
    manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    views = {}
    for key, view in manifest["views"].items():
        views[key] = {
            **view,
            "reference_uri": image_uri(manifest_path.parent, view.get("reference"), output),
            "capture_uri": image_uri(manifest_path.parent, view.get("capture"), output),
        }
    if not views or not manifest["checks"]:
        raise ValueError("Include at least one view and one feature check")
    rows = defaultdict(list)
    totals = Counter()
    seen = set()
    for row in manifest["checks"]:
        check_id = row["id"]
        if not isinstance(check_id, str) or not check_id.strip() or check_id in seen:
            raise ValueError(f"Missing or duplicate check ID: {check_id!r}")
        seen.add(check_id)
        modes = sum(key in row for key in ("expected_count", "reference_point", "status"))
        if modes != 1:
            raise ValueError(f"{check_id} must use exactly one check mode")
        view_id = row["view"]
        status, detail = assess(row, views[view_id])
        totals[status] += 1
        rows[view_id].append(
            f'<li><strong class="{status}">{status}</strong> '
            f"{html.escape(check_id)} · {html.escape(row['label'])}. {html.escape(detail)}</li>"
        )
    summary = " · ".join(f"{totals[status]} {status.lower()}" for status in STATUSES)
    parts = [
        '<!doctype html><html lang="en"><meta charset="utf-8">',
        '<meta name="viewport" content="width=device-width, initial-scale=1">',
        f"<title>Reference coverage</title><style>{CSS}</style>",
        f"<h1>Reference coverage</h1><p>{summary}</p>",
    ]
    for view_id, view in views.items():
        reference, capture = view["reference_uri"], view["capture_uri"]
        parts.append(f"<section><h2>{html.escape(view_id)}</h2><div class='pair'>")
        for label, uri in (("Reference", reference), ("Studio capture", capture)):
            preview = f'<img alt="{label}" src="{uri}">' if uri else "<p>Image unavailable.</p>"
            parts.append(f"<figure><figcaption>{label}</figcaption>{preview}</figure>")
        parts.append("</div>")
        if view.get("comparable") is True and reference and capture:
            parts.append(
                "<details><summary>Overlay matched framing</summary>"
                f'<div class="overlay"><img alt="Reference" src="{reference}">'
                f'<img alt="Studio capture overlay" src="{capture}"></div></details>'
            )
        parts.append(f"<ul>{''.join(rows[view_id])}</ul></section>")
    parts.append("</html>")
    output.write_text("\n".join(parts), encoding="utf-8")
    print(f"{summary.replace(' · ', ' | ')}. Report: {output}")
    return int(bool(totals["MISMATCH"] or totals["UNVERIFIED"]))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("report", type=Path)
    args = parser.parse_args()
    if args.report.suffix.lower() != ".html":
        parser.error("report must end in .html")
    try:
        return report(args.manifest, args.report.resolve())
    except (OSError, ValueError, KeyError, TypeError, AttributeError) as error:
        print(f"Invalid coverage input: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
