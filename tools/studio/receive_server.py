"""Tiny localhost receiver so Studio (via the MCP / Command Bar) can save
serialized models straight into the repo.

    python tools/studio/receive_server.py        # listens on 127.0.0.1:34999

Studio side: HttpService:PostAsync("http://127.0.0.1:34999/save?path=assets/Weapons/Bitrate.rbxm",
    base64(SerializationService:SerializeInstancesAsync({model})))

Only writes .rbxm/.rbxmx/.json files under assets/ or art-source/.
"""

import base64
import os
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlparse

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ALLOWED_DIRS = ("assets", "art-source")
ALLOWED_EXT = (".rbxm", ".rbxmx", ".json")


class Handler(BaseHTTPRequestHandler):
	def do_POST(self):
		url = urlparse(self.path)
		rel = parse_qs(url.query).get("path", [""])[0].replace("\\", "/")
		target = os.path.abspath(os.path.join(ROOT, rel))
		ok_dir = any(target.startswith(os.path.join(ROOT, d) + os.sep) for d in ALLOWED_DIRS)
		if url.path != "/save" or not ok_dir or not target.endswith(ALLOWED_EXT):
			self.send_response(400)
			self.end_headers()
			self.wfile.write(b"bad path")
			return
		body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
		data = base64.b64decode(body) if target.endswith((".rbxm",)) else body
		os.makedirs(os.path.dirname(target), exist_ok=True)
		with open(target, "wb") as f:
			f.write(data)
		self.send_response(200)
		self.end_headers()
		self.wfile.write(f"saved {rel} ({len(data)} bytes)".encode())

	def log_message(self, fmt, *args):
		print(fmt % args, flush=True)


if __name__ == "__main__":
	HTTPServer(("127.0.0.1", 34999), Handler).serve_forever()
