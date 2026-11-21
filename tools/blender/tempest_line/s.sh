#!/bin/sh
# Send a script (or -c code) to the Tempest-Strike Blender instance (port 9999, owner-confirmed 2026-11-21).
# OUT=<file> saves the full JSON reply.
cd "$(dirname "$0")/../../.." && python tools/blender/tempest_line/send.py --port 9999 --pid 35100 --timeout 900 ${OUT:+--out "$OUT"} "$@"
