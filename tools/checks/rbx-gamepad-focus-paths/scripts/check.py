import argparse
from collections import defaultdict
import json
from pathlib import Path
import sys


def require(condition, message):
    if not condition:
        raise ValueError(message)


def nonempty(items, label):
    require(isinstance(items, list) and len(items) > 0, f"Record at least one {label}")
    return items


def check(d):
    """Find unreachable gamepad controls and focus traps."""
    edges = d["edges"]
    def visit(starts, graph):
        pending, visited = list(starts), set()
        while pending:
            node = pending.pop()
            if node not in visited:
                visited.add(node)
                pending.extend(graph.get(node, []))
        return visited
    forward = visit([d["start"]], edges)
    backwards = defaultdict(list)
    for source, targets in edges.items():
        for target in targets:
            backwards[target].append(source)
    reverse = visit(nonempty(d["escapes"], "escape"), backwards)
    missing = set(d["required"]) - forward
    trapped = forward - reverse
    return [f"Cannot reach {name}" for name in sorted(missing)] + [f"No route to exit from {name}" for name in sorted(trapped)], [f"Reachable controls: {len(forward)}"]


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
