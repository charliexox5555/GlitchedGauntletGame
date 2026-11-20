import argparse
from collections import defaultdict
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
    """Find resources that survive their owning character generation."""
    active, ended, findings = defaultdict(set), set(), []
    for row in chronological(d["events"]):
        gen, event = row["generation"], row["event"]
        if event == "end":
            if gen in ended:
                findings.append(f"{gen} ended twice")
            if active[gen]:
                findings.append(f"{gen} ended with live resources {sorted(active[gen])}")
            ended.add(gen)
        elif event == "acquire":
            resource = row["id"]
            if gen in ended or resource in active[gen]:
                findings.append(f"Invalid acquire {gen}/{resource}")
            active[gen].add(resource)
        elif event == "release":
            resource = row["id"]
            if resource not in active[gen]:
                findings.append(f"Release without acquire {gen}/{resource}")
            active[gen].discard(resource)
        else:
            raise ValueError("Unknown lifecycle event")
    require(bool(ended), "Trace needs at least one character teardown")
    return findings, [f"Checked {len(ended)} ended character generations"]


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
