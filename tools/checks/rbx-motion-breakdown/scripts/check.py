import argparse
import json
import math
from pathlib import Path
import statistics
import sys


def require(condition, message):
    if not condition:
        raise ValueError(message)


def nonempty(items, label):
    require(isinstance(items, list) and len(items) > 0, f"Record at least one {label}")
    return items


def number(value):
    require(type(value) in (int, float) and math.isfinite(value), "Expected a finite number")
    return value


def vector(items, size):
    require(isinstance(items, list) and len(items) == size, f"Expected a {size}-component vector")
    return [number(item) for item in items]


def unique(items, key):
    result = {}
    for row in nonempty(items, key):
        name = row[key]
        require(isinstance(name, str) and name.strip() and name not in result, f"Missing or duplicate {key}: {name!r}")
        result[name] = row
    return result


def check(d):
    """Break an animation into comparable motion curves."""
    phase = [number(x) for x in nonempty(d["phase"], "phase sample")]
    require(len(phase) >= 3 and phase[0] == 0 and phase[-1] == 1, "Use 3 or more samples covering phase 0 to 1")
    require(all(a < b for a, b in zip(phase, phase[1:])), "Phases must strictly increase")
    failures, notes = [], []
    for name, row in unique(d["channels"], "id").items():
        ref, act = vector(row["reference"], len(phase)), vector(row["actual"], len(phase))
        offset = number(row.get("target_offset", 0))
        require(row["mode"] in ("match", "diagnostic"), "Mode must be match or diagnostic")
        delta = [a - r - offset for r, a in zip(ref, act)]
        if row["unit"] == "deg":
            delta = [(x + 180) % 360 - 180 for x in delta]
        rms = math.sqrt(statistics.mean(x * x for x in delta))
        bias = statistics.mean(delta)
        notes.append(f"{name} ({row['mode']}): residual bias {bias:+.3f}, RMS {rms:.3f} {row['unit']} after target offset {offset:+g}")
        if row["mode"] == "match" and rms > number(row["tolerance"]):
            failures.append(f"{name}: RMS exceeds chosen tolerance")
    return failures, notes

def write_curve_report(d, path, findings, measurements):
    from html import escape
    parts = ['<!doctype html><html lang="en"><meta charset="utf-8">', '<meta name="viewport" content="width=device-width, initial-scale=1">', '<title>Motion breakdown</title>', '<style>body{font:16px system-ui;max-width:960px;margin:auto;padding:20px}svg{width:100%;height:auto}section{margin:22px 0}</style>', '<h1>Motion breakdown</h1><p>Blue: authored. Orange dashed: reference.</p>']
    if findings:
        parts.append("<ul>" + "".join(f"<li>{escape(item)}</li>" for item in findings) + "</ul>")
    for row, measurement in zip(d["channels"], measurements):
        reference, actual = row["reference"], row["actual"]
        if row["unit"] == "deg":
            def unwrap(values):
                result = [values[0]]
                for a, b in zip(values, values[1:]):
                    result.append(result[-1] + (b - a + 180) % 360 - 180)
                return result
            reference, actual = unwrap(reference), unwrap(actual)
        low, high = min(reference + actual), max(reference + actual)
        height = high - low or 1
        label = escape(f"{row['id']} ({row['unit']}, {row['mode']})")
        parts.append(f'<section><h2>{label}</h2><p>{escape(measurement)}</p><p>Axis range: {low:.3f} to {high:.3f}. Phase: 0 to 1.</p><svg role="img" aria-label="{label} curve comparison" viewBox="0 0 600 145"><rect x="10" y="10" width="580" height="122" fill="#f4f5f7"/>')
        for series, color, dash in ((reference, "#aa6312", "6 5"), (actual, "#1758a7", "none")):
            points = " ".join(f"{10+580*x:.2f},{132-122*(y-low)/height:.2f}" for x, y in zip(d["phase"], series))
            parts.append(f'<polyline points="{points}" fill="none" stroke="{color}" stroke-width="2" stroke-dasharray="{dash}"/>')
        parts.append('</svg></section>')
    path.write_text("\n".join(parts) + "</html>", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=check.__doc__)
    parser.add_argument("capture", type=Path)
    if "write_curve_report" in globals():
        parser.add_argument("--report", type=Path, help="Save an HTML motion-curve comparison")
    args = parser.parse_args()
    try:
        data = json.loads(args.capture.read_text(encoding="utf-8-sig"))
        require(isinstance(data, dict), "Expected a JSON object")
        data["_capture_dir"] = args.capture.resolve().parent
        findings, measurements = check(data)
        if getattr(args, "report", None):
            require(args.report.suffix.lower() == ".html", "Curve report must end in .html")
            require(args.report.resolve() != args.capture.resolve(), "Report must be separate from capture")
            write_curve_report(data, args.report, findings, measurements)
    except (OSError, ValueError, KeyError, TypeError, IndexError, ZeroDivisionError, OverflowError, AttributeError) as error:
        print(f"INVALID: {error}", file=sys.stderr)
        return 2
    for measurement in measurements:
        print(measurement)
    for finding in findings:
        print(f"FAIL: {finding}")
    print(f"{len(findings)} finding(s)." if findings else "PASS: recorded checks passed.")
    return int(bool(findings))


if __name__ == "__main__":
    sys.exit(main())
