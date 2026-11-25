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
    """Detect steady instance growth after repeated gameplay cycles."""
    counts = [number(value) for value in nonempty(d["settled_counts"], "settled count")]
    require(len(counts) >= 3 and min(counts) >= 0, "Record at least three settled nonnegative counts")
    midpoint = (len(counts) - 1) / 2
    trend = sum((index - midpoint) * count for index, count in enumerate(counts)) / sum((index - midpoint) ** 2 for index in range(len(counts)))
    growth = counts[-1] - counts[0]
    findings = []
    if growth > number(d["max_growth"]):
        findings.append(f"Settled count grew by {growth:g}")
    if trend > number(d["max_per_cycle"]):
        findings.append(f"Fitted growth {trend:.2f} instances per cycle")
    return findings, [f"Baseline to final: {counts[0]:g} -> {counts[-1]:g}, trend {trend:+.2f}/cycle"]


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
