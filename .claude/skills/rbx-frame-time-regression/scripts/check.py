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


def percentile(values, fraction):
    values = sorted(number(value) for value in nonempty(values, "sample"))
    return values[max(0, math.ceil(len(values) * fraction) - 1)]


def check(d):
    """Compare repeatable frame-time captures before and after a change."""
    before = percentile(d["baseline_ms"], .95)
    after = percentile(d["candidate_ms"], .95)
    require(min(d["baseline_ms"]) > 0 and min(d["candidate_ms"]) > 0, "Frame times must be positive")
    delta = after - before
    findings = []
    if delta > number(d["max_p95_increase_ms"]):
        findings.append(f"p95 regressed {delta:+.2f} ms")
    if after > number(d["budget_ms"]):
        findings.append(f"Candidate p95 is above {d['budget_ms']} ms")
    return findings, [f"p95 {before:.2f} -> {after:.2f} ms; n={len(d['baseline_ms'])}/{len(d['candidate_ms'])}"]


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
