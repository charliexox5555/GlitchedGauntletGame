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


def chronological(events, allow_empty=False):
    if not allow_empty:
        nonempty(events, "event")
    last = -math.inf
    for event in events:
        now = number(event["time"])
        require(now >= last, "Events must be ordered by time")
        last = now
    return events


def check(d):
    """Detect illegal or stale round phase transitions."""
    phase, round_id = d["initial"], d["initial_round"]
    failures = []
    for row in chronological(d["events"]):
        target = row["to"]
        expected_round = round_id + 1 if target == d["start_phase"] else round_id
        if row["round"] != expected_round or row["from"] != phase or target not in d["allowed"].get(phase, []):
            failures.append(f"Unexpected transition at {row['time']}s: {row['from']} -> {target}, round {row['round']}")
            continue
        phase, round_id = target, expected_round
    if phase != d["final"]:
        failures.append(f"Expected end phase {d['final']}, reached {phase}")
    return failures, [f"Last accepted phase: {phase}, round {round_id}"]


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
