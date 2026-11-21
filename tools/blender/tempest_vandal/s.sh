#!/bin/sh
# Send a script (or -c code) to the Tempest-Strike Blender instance (port 9999).
cd "$(dirname "$0")/../../.." && python tools/blender/lobby_v4/send.py --port 9999 --pid 35100 --timeout 900 "$@"
