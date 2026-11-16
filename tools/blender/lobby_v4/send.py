"""Send Python to a live Blender MCP bridge on a non-default port (the Lobby V4 instance).

    python tools/blender/lobby_v4/send.py <file.py | -c "code"> [--port 9999] [--pid 42336] [--timeout 600]

The bridge protocol: JSON {"type": "execute", "code": ..., "strict_json": false} + NUL, reply NUL-terminated JSON.
The code should assign a JSON-serialisable `result`. --pid guards against talking to the wrong Blender.
"""
import argparse
import json
import socket
import sys

ap = argparse.ArgumentParser()
ap.add_argument("src")
ap.add_argument("-c", action="store_true", help="src is code, not a file")
ap.add_argument("--port", type=int, default=9999)
ap.add_argument("--pid", type=int, default=0)
ap.add_argument("--timeout", type=float, default=600)
a = ap.parse_args()
code = a.src if a.c else open(a.src, encoding="utf-8").read()
if a.pid:
	code = f"import os as _os\nassert _os.getpid() == {a.pid}, 'wrong Blender instance'\n" + code
s = socket.create_connection(("127.0.0.1", a.port), timeout=a.timeout)
s.sendall(json.dumps({"type": "execute", "code": code, "strict_json": False}).encode() + b"\0")
buf = b""
while not buf.endswith(b"\0"):
	c = s.recv(1 << 20)
	if not c:
		break
	buf += c
out = buf.rstrip(b"\0").decode("utf-8", "replace")
try:
	d = json.loads(out)
	print(json.dumps(d, indent=1)[:20000])
	sys.exit(0 if d.get("status") == "ok" else 1)
except ValueError:
	print(out[:20000])
