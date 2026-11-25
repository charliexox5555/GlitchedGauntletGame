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


def overlap(a, b):
    return max(0, min(a[2], b[2]) - max(a[0], b[0])) * max(0, min(a[3], b[3]) - max(a[1], b[1]))


def check(d):
    """Find controls that leave a safe area or collide with another target."""
    safe = rect(d["safe"])
    min_width, min_height = vector(d["min_size"], 2)
    controls = {name: rect(row["bounds"]) for name, row in unique(d["controls"], "id").items()}
    failures = []
    for index, (name, bounds) in enumerate(controls.items()):
        a, b, c, e = bounds
        if min_width > c - a or min_height > e - b:
            failures.append(f"{name}: target dimensions are below the chosen minimum")
        if a < safe[0] or b < safe[1] or c > safe[2] or e > safe[3]:
            failures.append(f"{name}: target crosses the safe area")
        for other, area in list(controls.items())[index + 1:]:
            if overlap(bounds, area) > 0:
                failures.append(f"{name} overlaps active target {other}")
    return failures, [f"Checked {len(controls)} active controls"]


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
