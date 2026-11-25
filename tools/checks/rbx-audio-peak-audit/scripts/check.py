import argparse
import json
import math
from pathlib import Path
import sys


def require(condition, message):
    if not condition:
        raise ValueError(message)


def number(value):
    require(type(value) in (int, float) and math.isfinite(value), "Expected a finite number")
    return value


def check(d):
    """Measure peak signal and clipped sample counts in a gameplay audio file."""
    import array
    import wave
    path = d["_capture_dir"] / d["file"]
    threshold = number(d["max_peak_db"])
    require(threshold <= 0, "Peak target must be at or below 0 dBFS")
    longest = clips = total = 0
    with wave.open(str(path), "rb") as stream:
        require(stream.getsampwidth() == 2, "Use 16-bit PCM WAV")
        while True:
            chunk = stream.readframes(4096)
            if not chunk:
                break
            values = array.array("h")
            values.frombytes(chunk)
            if sys.byteorder != "little":
                values.byteswap()
            total += len(values)
            longest = max(longest, max(map(abs, values)))
            clips += sum(value in (-32768, 32767) for value in values)
    require(total > 0, "WAV is empty")
    peak = 20 * math.log10(longest / 32768) if longest else -math.inf
    findings = [f"Sample peak above {threshold:g} dBFS"] if peak > threshold else []
    if clips:
        findings.append(f"{clips} full-scale samples may be clipped")
    return findings, [f"Sample peak: {peak:.2f} dBFS ({total} samples)"]


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
