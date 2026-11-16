"""Send run_theme.py to the live maps Blender with THEME / KIT / EXPORT set.

    python tools/blender/maps_kit/run.py rooftops Rooftops [--no-export] [--port 9930] [--pid 41504]
"""
import argparse
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ap = argparse.ArgumentParser()
ap.add_argument("theme")
ap.add_argument("kit")
ap.add_argument("--no-export", action="store_true")
ap.add_argument("--port", default="9930")
ap.add_argument("--pid", default="41504")
a = ap.parse_args()
code = f"THEME = {a.theme!r}\nKIT = {a.kit!r}\nEXPORT = {not a.no_export}\n" + open(os.path.join(HERE, "run_theme.py"), encoding="utf-8").read()
send = os.path.join(HERE, "..", "lobby_v4", "send.py")
sys.exit(subprocess.call([sys.executable, send, "-c", code, "--port", a.port, "--pid", a.pid, "--timeout", "170"]))
