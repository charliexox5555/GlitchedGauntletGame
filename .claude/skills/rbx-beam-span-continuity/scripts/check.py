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


def distance(a, b, size=3):
    return math.dist(vector(a, size), vector(b, size))


def unique(items, key):
    result = {}
    for row in nonempty(items, key):
        name = row[key]
        require(isinstance(name, str) and name.strip() and name not in result, f"Missing or duplicate {key}: {name!r}")
        result[name] = row
    return result


def check(d):
    """Find gaps or width pops between visible Beam segments."""
    segments = list(unique(d["segments"], "id").values())
    require(len(segments) >= 2, "Record at least two beam segments")
    failures, notes = [], []
    for a, b in zip(segments, segments[1:]):
        gap = distance(a["end"], b["start"])
        wa, wb = number(a["end_width"]), number(b["start_width"])
        require(max(wa, wb) > 0 and min(wa, wb) >= 0, "At least one positive join width is required")
        change = abs(wa - wb) / max(wa, wb)
        name = f"{a['id']} -> {b['id']}"
        notes.append(f"{name}: {gap:.3f} studs, width change {change:.1%}")
        if gap > number(d["max_gap"]) or change > number(d["max_width_step"]):
            failures.append(f"{name}: visible join discontinuity")
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
