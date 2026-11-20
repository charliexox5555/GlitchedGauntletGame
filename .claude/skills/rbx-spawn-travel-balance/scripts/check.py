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


def check(d):
    """Compare spawn-to-objective travel times."""
    times = d["times_s"]
    require(len(times) >= 2, "Record two or more spawns")
    medians = {name: statistics.median(number(t) for t in nonempty(series, "run")) for name, series in times.items()}
    first, last = min(medians, key=medians.get), max(medians, key=medians.get)
    spread = medians[last] - medians[first]
    notes = [f"{name}: {value:.2f}s median (n={len(times[name])})" for name, value in medians.items()]
    notes.append(f"Spread: {spread:.2f}s ({first} to {last})")
    return ([f"Spawn travel spread exceeds {d['max_spread_s']}s"] if spread > number(d["max_spread_s"]) else []), notes


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
