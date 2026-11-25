import argparse
import json
import math
from pathlib import Path
import sys


def require(condition, message):
    if not condition:
        raise ValueError(message)


def number(value):
    require(type(value) in (int, float) and math.isfinite(value), "Expected a finite number")
    return value


def vector(items, size):
    require(isinstance(items, list) and len(items) == size, f"Expected a {size}-component vector")
    return [number(item) for item in items]


def angle(a, b):
    a, b = vector(a, 3), vector(b, 3)
    length = math.hypot(*a) * math.hypot(*b)
    require(length > 0, "Direction has zero length")
    cosine = sum(x * y for x, y in zip(a, b)) / length
    return math.degrees(math.acos(max(-1, min(1, cosine))))


def check(d):
    """Detect mesh scale and facing changes during Roblox import."""
    expected = vector(d["expected_size"], 3)
    require(all(x > 0 for x in expected), "Expected sizes must be positive")
    ratios = [x / y for x, y in zip(vector(d["observed_size"], 3), expected)]
    facing = angle(d["expected_front"], d["observed_front"])
    failures = [f"{axis} scale is {ratio:.3f}x" for axis, ratio in zip("XYZ", ratios) if abs(ratio - 1) > number(d["max_scale_error"])]
    if facing > number(d["max_front_error_deg"]):
        failures.append(f"Front direction differs by {facing:.2f} degrees")
    return failures, [f"Axis scale ratios: {ratios}", f"Front error: {facing:.2f} degrees"]


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
