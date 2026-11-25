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


def subtract(a, b):
    return [x - y for x, y in zip(vector(a, 3), vector(b, 3))]


def check(d):
    """Measure pose and velocity jumps at an animation loop seam."""
    dt = number(d["dt"])
    require(dt > 0, "Sample step must be positive")
    failures, notes = [], []
    for name, row in unique(d["joints"], "id").items():
        pose = distance(row["start"], row["end"])
        velocity = distance(subtract(row["after_start"], row["start"]), subtract(row["end"], row["before_end"])) / dt
        # A fast effector (a running foot) changes velocity between ANY two
        # frames; the seam only pops when it changes more than the clip does
        # inside its own cycle. With "interior_velocity_jump" (the largest
        # frame-to-frame velocity change inside the loop), the limit is the
        # larger of max_velocity_gap and that baseline times interior_margin.
        limit = number(d["max_velocity_gap"])
        if "interior_velocity_jump" in row:
            interior = number(row["interior_velocity_jump"])
            limit = max(limit, interior * number(d.get("interior_margin", 1.25)))
            notes.append(f"{name}: {pose:.3f} studs pose gap, {velocity:.2f} studs/s velocity jump (interior {interior:.2f}, limit {limit:.2f})")
        else:
            notes.append(f"{name}: {pose:.3f} studs pose gap, {velocity:.2f} studs/s velocity jump")
        if pose > number(d["max_pose_gap"]) or velocity > limit:
            failures.append(f"{name}: visible seam risk")
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
