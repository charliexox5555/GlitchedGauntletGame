"""Send Python to the live Tempest-Strike Blender MCP bridge (port 9999). Adapted from tools/blender/lobby_v4/send.py:
adds --out <file> (full JSON reply) because the printed reply is truncated to 20,000 characters.

    python tools/blender/tempest_line/send.py <file.py | -c "code"> [--port 9999] [--pid 35100] [--out reply.json]
"""
import argparse, json, socket, sys

ap = argparse.ArgumentParser()
ap.add_argument("src")
ap.add_argument("-c", action="store_true")
ap.add_argument("--port", type=int, default=9999)
ap.add_argument("--pid", type=int, default=0)
ap.add_argument("--timeout", type=float, default=900)
ap.add_argument("--out", default="")
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
if a.out:
	open(a.out, "w", encoding="utf-8").write(out)
try:
	d = json.loads(out)
	print(json.dumps(d, indent=1)[:6000] if not a.out else json.dumps({"status": d.get("status"), "message": str(d.get("message", ""))[:3000]}))
	sys.exit(0 if d.get("status") == "ok" else 1)
except ValueError:
	print(out[:6000])
