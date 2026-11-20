"""Compare modular seam anchors exported from a Roblox Studio place."""

import argparse
import json
import math
from pathlib import Path
import sys


def vector(values):
    if not isinstance(values, list) or len(values) != 3:
        raise ValueError("Expected a three-component vector")
    if any(type(value) not in (int, float) or not math.isfinite(value) for value in values):
        raise ValueError("Vector components must be finite numbers")
    return values


def angle(a, b, opposite=False):
    length = math.hypot(*a) * math.hypot(*b)
    if not length:
        raise ValueError("Seam direction has zero length")
    dot = sum(x * y for x, y in zip(a, b)) / length
    cosine = -dot if opposite else dot
    return math.degrees(math.acos(max(-1, min(1, cosine))))


def run(path):
    config = json.loads(path.read_text(encoding="utf-8-sig"))
    limits = [
        config["max_gap_studs"],
        config["max_facing_deg"],
        config["max_twist_deg"],
    ]
    for index, limit in enumerate(limits):
        if type(limit) not in (int, float) or not math.isfinite(limit) or limit < 0:
            raise ValueError("Tolerances must be finite nonnegative numbers")
        if index and limit > 180:
            raise ValueError("Angle tolerances must be at most 180 degrees")
    if not config["pairs"]:
        raise ValueError("Include at least one seam pair")

    failures = 0
    seen = set()
    for pair in config["pairs"]:
        pair_id, a, b = pair["id"], pair["a"], pair["b"]
        if not isinstance(pair_id, str) or not pair_id.strip() or pair_id in seen:
            raise ValueError(f"Missing or duplicate pair ID: {pair_id!r}")
        seen.add(pair_id)
        if a["path"] == b["path"]:
            raise ValueError(f"{pair_id} must refer to two distinct attachments")
        measured = (
            math.dist(vector(a["position"]), vector(b["position"])),
            angle(vector(a["forward"]), vector(b["forward"]), opposite=True),
            angle(vector(a["up"]), vector(b["up"])),
        )
        checks = ("gap", "facing", "twist")
        failed = [name for name, value, limit in zip(checks, measured, limits) if value > limit]
        failures += bool(failed)
        status = "PASS" if not failed else f"FAIL ({', '.join(failed)})"
        gap, facing, twist = measured
        print(f"{status} {pair_id}: {gap:.4f} studs, facing {facing:.2f} deg, twist {twist:.2f} deg")
        print(f"  {a['path']} <-> {b['path']}")
    return int(bool(failures))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("snapshot", type=Path)
    args = parser.parse_args()
    try:
        return run(args.snapshot)
    except (OSError, ValueError, KeyError, TypeError, OverflowError) as error:
        print(f"Invalid join snapshot: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
