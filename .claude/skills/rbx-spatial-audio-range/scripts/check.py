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


def unique(items, key):
    result = {}
    for row in nonempty(items, key):
        name = row[key]
        require(isinstance(name, str) and name.strip() and name not in result, f"Missing or duplicate {key}: {name!r}")
        result[name] = row
    return result


def interval(start, end):
    start, end = number(start), number(end)
    require(end >= start, "Interval end precedes start")
    return start, end


def check(d):
    """Find gameplay sounds that carry too far or vanish too early."""
    failures, notes = [], []
    for name, row in unique(d["samples"], "id").items():
        low, high = interval(row["min_db"], row["max_db"])
        actual = number(row["level_db"])
        notes.append(f"{name} at {number(row['distance']):g} studs: {actual:+.1f} dBFS")
        if actual < low:
            failures.append(f"{name}: softer than intended")
        if actual > high:
            failures.append(f"{name}: louder than intended")
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
