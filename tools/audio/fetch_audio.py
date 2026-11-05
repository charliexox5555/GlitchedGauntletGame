"""Download Freesound CC0 recordings picked from freesound_search.py output,
each into its own new folder, after checking the licence on the sound page.

    python -I tools/audio/fetch_audio.py cands.json role:id[,id...] [role:id...]

For each id: reads the sound page, refuses anything whose page doesn't show
the CC0 licence, then saves the HQ OGG preview to
art-source/audio/downloads/freesound-<id>/ with source.json (page URL,
author, title, licence as read, description, date). Nothing downloaded is ever
run; the folder is gitignored (the ledger lives in the vault note).
"""

import datetime
import html
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art-source", "audio", "downloads")
UA = {"User-Agent": "Mozilla/5.0 (GlitchedGauntletGame sound sourcing)"}
CC0 = re.compile(r"creativecommons\.org/publicdomain/zero/1\.0|Creative Commons 0", re.I)


def get(url):
	# Usernames can be non-ASCII (e.g. "serøutōnin"): percent-encode the URL.
	url = urllib.parse.quote(url, safe=":/?=&%#")
	req = urllib.request.Request(url, headers=UA)
	with urllib.request.urlopen(req, timeout=60) as r:
		return r.read()


def main():
	cands = json.load(open(sys.argv[1]))
	by_id = {c["id"]: c for cs in cands.values() for c in cs}
	for arg in sys.argv[2:]:
		role, ids = arg.split(":")
		for sid in map(int, ids.split(",")):
			c = by_id.get(sid)
			if not c:
				print("unknown", sid)
				continue
			folder = os.path.join(OUT, f"freesound-{sid}")
			if os.path.exists(os.path.join(folder, "source.json")):
				print("have", sid)
				continue
			page = get(c["page"]).decode("utf8", "replace")
			lic = re.search(r'href="(https?://creativecommons\.org/[^"]+)"', page)
			if not CC0.search(page) or (lic and "publicdomain/zero" not in lic.group(1)):
				print("NOT CC0, skipped", sid, lic and lic.group(1))
				continue
			desc = re.search(r'id="soundDescriptionSection"[^>]*>(.*?)</div>', page, re.S)
			text = re.sub(r"<[^>]+>", " ", html.unescape(desc.group(1))) if desc else ""
			os.makedirs(folder, exist_ok=False)
			path = os.path.join(folder, f"{sid}.ogg")
			with open(path, "wb") as f:
				f.write(get(c["preview"]))
			json.dump(
				{
					"role": role,
					"source": "Freesound",
					"id": sid,
					"title": c["title"],
					"author": c["user"],
					"page": c["page"],
					"file": c["preview"],
					"file_note": "Freesound HQ preview (OGG ~192 kbps); the original needs a signed-in download",
					"licence": "CC0 1.0 (read on the sound page)",
					"licence_url": lic.group(1) if lic else "https://creativecommons.org/publicdomain/zero/1.0/",
					"duration": c["duration"],
					"samplerate": c["rate"],
					"description": " ".join(text.split())[:600],
					"downloaded": datetime.date.today().isoformat(),
				},
				open(os.path.join(folder, "source.json"), "w"),
				indent=1,
			)
			print("ok", role, sid, c["title"])
			time.sleep(0.7)


if __name__ == "__main__":
	main()
