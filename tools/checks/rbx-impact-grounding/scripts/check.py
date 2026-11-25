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


def angle(a, b):
    a, b = vector(a, 3), vector(b, 3)
    length = math.hypot(*a) * math.hypot(*b)
    require(length > 0, "Direction has zero length")
    cosine = sum(x * y for x, y in zip(a, b)) / length
    return math.degrees(math.acos(max(-1, min(1, cosine))))


def unique(items, key):
    result = {}
    for row in nonempty(items, key):
        name = row[key]
        require(isinstance(name, str) and name.strip() and name not in result, f"Missing or duplicate {key}: {name!r}")
        result[name] = row
    return result


def check(d):
    """Check that effects sit on the intended surface after contact."""
    findings, notes = [], []
    for name, row in unique(d["contacts"], "id").items():
        offset = distance(row["origin"], row["point"])
        tilt = angle(row["effect_up"], row["normal"])
        notes.append(f"{name}: origin offset {offset:.3f} studs, normal error {tilt:.1f} deg")
        if offset > number(d["max_offset"]) or tilt > number(d["max_tilt_deg"]):
            findings.append(f"{name}: impact does not match contact surface")
    return findings, notes


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
