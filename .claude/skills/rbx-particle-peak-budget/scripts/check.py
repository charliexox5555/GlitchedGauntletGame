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


def check(d):
    """Estimate peak live particles under overlapping bursts."""
    changes = []
    for row in nonempty(d["bursts"], "burst"):
        t, count, lifetime = number(row["time"]), row["count"], number(row["lifetime"])
        require(type(count) is int and count >= 0 and lifetime > 0, "Expected a nonnegative count and positive lifetime")
        changes.extend(((t, count), (t + lifetime, -count)))
    live = peak = peak_time = 0
    for t, delta in sorted(changes):
        live += delta
        if live > peak:
            peak, peak_time = live, t
    return ([f"Modeled peak exceeds {d['max_live']}"] if peak > number(d["max_live"]) else []), [f"Peak {peak} live particles at {peak_time:g}s"]


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
