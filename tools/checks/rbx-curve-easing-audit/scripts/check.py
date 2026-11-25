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


def interval(start, end):
    start, end = number(start), number(end)
    require(end >= start, "Interval end precedes start")
    return start, end


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
    """Check sampled animation easing for hard edges, overshoot, and abrupt speed changes."""
    samples = chronological(d["samples"])
    require(len(samples) >= 4, "Record at least four samples")
    low, high = interval(*d["range"])
    failures, speeds, middles = [], [], []
    for a, b in zip(samples, samples[1:]):
        dt = b["time"] - a["time"]
        require(dt > 0, "Sample times must strictly increase")
        speeds.append((number(b["value"]) - number(a["value"])) / dt)
        middles.append((a["time"] + b["time"]) / 2)
    accelerations = [abs((b - a) / (tb - ta)) for a, b, ta, tb in zip(speeds, speeds[1:], middles, middles[1:])]
    peak = max(accelerations)
    if abs(speeds[0]) > number(d["max_entry_speed"]):
        failures.append("Entry velocity exceeds target")
    if abs(speeds[-1]) > number(d["max_exit_speed"]):
        failures.append("Exit velocity exceeds target")
    if peak > number(d["max_acceleration"]):
        i = accelerations.index(peak)
        # accelerations[i] sits between speed midpoints i and i + 1
        failures.append(f"Acceleration spike near {(middles[i] + middles[i + 1]) / 2:.3f}s")
    for sample in samples:
        if not low <= sample["value"] <= high:
            failures.append(f"Unexpected overshoot at {sample['time']:.3f}s")
    notes = [f"Entry {speeds[0]:+.2f}/s, exit {speeds[-1]:+.2f}/s, peak acceleration {peak:.2f}/s^2"]
    # Optional (added 2026-11-21 for first-person melee): a held pose that stops
    # moving reads as staged, and a strike must be fastest on its contact.
    hold = d.get("hold")
    if hold is not None:
        floor, longest = number(hold["min_speed"]), number(hold["max_seconds"])
        run_start, worst, worst_at = None, 0.0, None
        lo_t, hi_t = (number(x) for x in hold.get("window", [samples[0]["time"], samples[-1]["time"]]))
        for speed, mid in zip(speeds, middles):
            inside = lo_t <= mid <= hi_t
            if inside and abs(speed) < floor:
                run_start = mid if run_start is None else run_start
                if mid - run_start > worst:
                    worst, worst_at = mid - run_start, run_start
            else:
                run_start = None
        notes.append(f"Longest stretch under {floor:g}/s: {worst:.3f}s")
        if worst > longest:
            failures.append(f"Dead hold: under {floor:g}/s for {worst:.3f}s from {worst_at:.3f}s")
    contact = d.get("contact")
    if contact is not None:
        at, tolerance = number(contact["time"]), number(contact["tolerance"])
        fastest = max(range(len(speeds)), key=lambda i: abs(speeds[i]))
        near = min(range(len(speeds)), key=lambda i: abs(middles[i] - at))
        share = abs(speeds[near]) / abs(speeds[fastest]) if speeds[fastest] else 0
        notes.append(f"Peak speed at {middles[fastest]:.3f}s ({abs(speeds[fastest]):.2f}/s); at contact {share:.0%} of it")
        if abs(middles[fastest] - at) > tolerance:
            failures.append(f"Peak speed {middles[fastest] - at:+.3f}s from contact")
        if share < number(contact.get("min_share", 0)):
            failures.append(f"Contact speed only {share:.0%} of peak")
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
