import argparse
from collections import Counter
import json
from pathlib import Path
import sys


def require(condition, message):
    if not condition:
        raise ValueError(message)


def check(d):
    """Catch duplicate or lost gameplay commits from a single action."""
    want, saw = d["expected"], Counter(d["commits"])
    require(bool(want), "Specify expected intent outcomes")
    for count in want.values():
        require(type(count) is int and count >= 0, "Expected commits must be nonnegative integers")
    differences = [f"{key}: wanted {want.get(key, 0)}, observed {saw.get(key, 0)} commits" for key in sorted(want.keys() | saw.keys()) if want.get(key, 0) != saw.get(key, 0)]
    return differences, [f"Observed {sum(saw.values())} commits"]


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
