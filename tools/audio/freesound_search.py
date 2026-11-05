"""List CC0 candidates on Freesound for each sound role, from the public
search pages (no API key, nothing downloaded here).

    python -I tools/audio/freesound_search.py roles.json out.json

roles.json: {"role": ["query one", "query two"], ...}. Each query is searched
with the licence filter set to Creative Commons 0, most downloaded first.
out.json: {"role": [{id, user, user_id, title, duration, rate, downloads,
rating, page, preview}]}, deduplicated per role. `preview` is the HQ OGG
preview (the original file needs a signed-in download). The licence filter is
the search's; tools/audio/fetch_audio.py checks each sound page again before
it downloads anything.
"""

import html
import json
import re
import sys
import time
import urllib.parse
import urllib.request

UA = {"User-Agent": "Mozilla/5.0 (GlitchedGauntletGame sound sourcing)"}
BASE = "https://freesound.org/search/?"
FIELDS = ("sound-id", "username", "user-id", "title", "duration", "samplerate", "num-downloads")


def fetch(url):
	req = urllib.request.Request(url, headers=UA)
	with urllib.request.urlopen(req, timeout=30) as r:
		return r.read().decode("utf8", "replace")


def search(query, pages=1):
	out = []
	for page in range(1, pages + 1):
		q = urllib.parse.urlencode(
			{
				"q": query,
				"f": 'license:"Creative Commons 0"',
				"s": "Downloads (most first)",
				"page": page,
			}
		)
		text = fetch(BASE + q)
		for chunk in text.split('class="bw-search__result"')[1:]:
			d = {k: html.unescape(m.group(1)) for k in FIELDS if (m := re.search(f'data-{k}="([^"]*)"', chunk))}
			if "sound-id" not in d:
				continue
			sid = d["sound-id"]
			avg = re.search(r'aria-label="Average rating of ([0-9.]+)"', chunk)
			out.append(
				{
					"id": int(sid),
					"user": d.get("username"),
					"user_id": d.get("user-id"),
					"title": d.get("title"),
					"duration": float(d.get("duration", 0)),
					"rate": float(d.get("samplerate", 0)),
					"downloads": int(d.get("num-downloads", 0) or 0),
					"rating": float(avg.group(1)) if avg else None,
					"page": f"https://freesound.org/people/{d.get('username')}/sounds/{sid}/",
					"preview": f"https://cdn.freesound.org/previews/{int(sid) // 1000}/{sid}_{d.get('user-id')}-hq.ogg",
					"query": query,
				}
			)
		time.sleep(1.0)
	return out


def main():
	roles = json.load(open(sys.argv[1]))
	result = {}
	for role, queries in roles.items():
		seen = {}
		for q in queries:
			for c in search(q):
				seen.setdefault(c["id"], c)
		result[role] = sorted(seen.values(), key=lambda c: -c["downloads"])
		print(role, len(result[role]))
	json.dump(result, open(sys.argv[2], "w"), indent=1)


if __name__ == "__main__":
	main()
