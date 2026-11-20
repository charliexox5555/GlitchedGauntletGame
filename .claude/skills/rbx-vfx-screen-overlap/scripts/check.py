import argparse
import json
import math
from pathlib import Path
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


def rect(values):
    left, top, width, height = vector(values, 4)
    require(width > 0 and height > 0, "Rectangle must have positive dimensions")
    return left, top, left + width, top + height


def check(d):
    """Measure how much of a critical target an effect covers on screen."""
    failures, notes = [], []
    for name, row in unique(d["frames"], "id").items():
        left, top, right, bottom = rect(row["target"])
        clipped = []
        for item in row["effects"]:
            a, b, c, e = rect(item)
            a, b, c, e = max(a, left), max(b, top), min(c, right), min(e, bottom)
            if c > a and e > b:
                clipped.append((a, b, c, e))
        xs = sorted({x for a, _, c, _ in clipped for x in (a, c)})
        covered = 0.0
        for x0, x1 in zip(xs, xs[1:]):
            bands = sorted((b, e) for a, b, c, e in clipped if a <= x0 and c >= x1)
            end = -math.inf
            for y0, y1 in bands:
                covered += (x1 - x0) * max(0, y1 - max(y0, end))
                end = max(end, y1)
        fraction = covered / ((right - left) * (bottom - top))
        notes.append(f"{name}: {fraction:.1%} target bounds covered")
        if fraction > number(d["max_cover"]):
            failures.append(f"{name}: effect covers too much of the target")
    return failures, notes


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
