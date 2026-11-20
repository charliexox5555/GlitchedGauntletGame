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
    """Catch active trails or emitters that survive an interrupted action."""
    active, findings, notes = {}, [], []
    cutoff = number(d["cutoff"])
    for row in chronological(d["events"]):
        name, t = row["id"], row["time"]
        require(t <= cutoff, "Event occurs after the test cutoff")
        if row["on"]:
            if name in active:
                findings.append(f"{name} turned on while already active at {t}s")
            else:
                active[name] = t
        elif name not in active:
            findings.append(f"{name} turned off without an active window")
        else:
            span = t - active.pop(name)
            notes.append(f"{name}: {span:.3f}s active")
            if span > number(d["budget_s"]):
                findings.append(f"{name} exceeded its active window")
    findings.extend(f"{name} still active at {cutoff}s" for name in sorted(active))
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
