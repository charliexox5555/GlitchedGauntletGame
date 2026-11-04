"""Offline z-fighting check of a match map, before export/upload and before Studio.

    python tools/studio/maps/zfight_check.py Metro Station [--report out.json]

1. bundles tools/studio/maps/<Map>/{Greybox,Art,Lighting}.luau (bundle.py),
2. runs the bundle in Lune against a mock place with the kit mocked from the export JSON
   (tools/studio/maps/mock_place.luau) and dumps every placed piece and visible greybox part,
3. checks the assembled map in Blender twice, polygon by polygon and part bounds by part bounds
   (tools/blender/check_map_zfight.py [--bounds], on
   art-source/maps/<Map>/Kit_<Map>.blend).
Exits non-zero when any z-fighting pair is found. Run it after changing the layout, the kit or Art.luau,
and before exporting/uploading (the export JSON it reads must be current: re-export the kit first).
"""

import argparse
import os
import pathlib
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[3]
BLENDER = os.environ.get("BLENDER", "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe")
LUNE = os.environ.get("LUNE", os.path.expanduser("~/.rokit/tool-storage/lune-org/lune/0.11.0/lune.exe"))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("map")
    ap.add_argument("groups", nargs="+")
    ap.add_argument("--report")
    args = ap.parse_args()
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="zfight_"))
    bundle, dump = tmp / "bundle.luau", tmp / "dump.json"
    subprocess.run([sys.executable, str(ROOT / "tools/studio/maps/bundle.py"), args.map, "Greybox", "Art", "Lighting", "-o", str(bundle)], check=True)
    r = subprocess.run([LUNE, "run", str(ROOT / "tools/studio/maps/mock_place.luau"), str(bundle), args.map, *args.groups, "-o", str(dump)], cwd=ROOT, capture_output=True, text=True)
    print(r.stdout.strip().splitlines()[-1] if r.stdout.strip() else r.stderr)
    if r.returncode != 0:
        print(r.stdout, r.stderr)
        sys.exit(r.returncode)
    worst = 0
    # Two passes: the real meshes, then each kit part as its bounding box (what Studio's Audit.luau raycasts hit
    # on Box-fidelity parts: a part made of separate boxes counts as its whole bounds).
    for mode in ([], ["--bounds"]):
        cmd = [BLENDER, "--background", "--factory-startup", str(ROOT / f"art-source/maps/{args.map}/Kit_{args.map}.blend"),
               "--python", str(ROOT / "tools/blender/check_map_zfight.py"), "--", str(dump), *mode]
        if args.report:
            cmd += ["--report", args.report + (".bounds.json" if mode else "")]
        r = subprocess.run(cmd, capture_output=True, text=True)
        print("mesh pass:" if not mode else "bounds pass:")
        for line in r.stdout.splitlines():
            if line.startswith("ZFIGHT") or "Error" in line or "Traceback" in line:
                print(line)
        worst = max(worst, r.returncode)
    sys.exit(worst)


if __name__ == "__main__":
    main()
