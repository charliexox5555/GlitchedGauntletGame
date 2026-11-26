"""Vault map: a section-level search and link graph of the project vault, so an agent reads one section instead of a note.

No LLM, no install: it parses every project note's headings (with line ranges and sizes) and its links, caches the
result in tools/.cache/vault_map.json (rebuilt when any note changes, ~1 s), and answers in a few lines.

    python tools/vault_map.py find case opening shake sound   # best sections: path:lines, size, heading, a snippet
    python tools/vault_map.py outline "01 Design/Case Opening.md"   # headings with line ranges, links out, backlinks
    python tools/vault_map.py related "01 Design/Case Opening.md"   # notes linked to/from it, strongest first
    python tools/vault_map.py health    # big notes, broken links, notes nothing links to and INDEX misses

Then Read the path with offset = start line and limit = the range (vault/04 Tech/Vault Map.md).
Skips vault/LihFolk (own index), References, Attachments, Templates and .obsidian.
"""

from __future__ import annotations

import json
import math
import os
import re
import sys
from urllib.parse import unquote

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VAULT = os.path.join(ROOT, "vault")
CACHE = os.path.join(ROOT, "tools", ".cache", "vault_map.json")
SKIP = ("LihFolk", ".obsidian", ".trash", "Attachments", "Templates", os.path.join("02 Art", "References"))
BIG = 15 * 1024
VERSION = 2

HEADING = re.compile(r"^(#{1,6})\s+(.+?)\s*#*\s*$")
MD_LINK = re.compile(r"\]\(([^)\s]+?\.md)(?:#[^)]*)?\)")
WIKI_LINK = re.compile(r"\[\[([^\]|#]+)")
WORD = re.compile(r"[a-z0-9][a-z0-9_\-']*")
STOP = set(
	"a an and are as at be by do does for from has have how i in is it its of on or our that the this to was what when "
	"where which who why will with we you".split()
)


def rel(path: str) -> str:
	return os.path.relpath(path, VAULT).replace("\\", "/")


def notes() -> list[str]:
	out = []
	for dirpath, dirs, files in os.walk(VAULT):
		r = os.path.relpath(dirpath, VAULT)
		if r != "." and (r.split(os.sep)[0] in SKIP or any(r.startswith(s) for s in SKIP)):
			dirs[:] = []
			continue
		dirs[:] = [d for d in dirs if "third-party" not in d]
		out += [os.path.join(dirpath, f) for f in files if f.endswith(".md")]
	return sorted(out)


def stem(word: str) -> str:
	word = word.strip("'-")
	for suffix in ("ing", "es", "s", "ed"):
		if len(word) > len(suffix) + 3 and word.endswith(suffix):
			return word[: -len(suffix)]
	return word


def words(text: str) -> list[str]:
	return [stem(w) for w in WORD.findall(text.lower()) if w not in STOP]


def parse(path: str, by_name: dict[str, list[str]]) -> dict:
	with open(path, encoding="utf-8", errors="replace") as f:
		lines = f.read().split("\n")
	sections, links = [], set()
	fence = False
	current = {"h": "(top)", "lvl": 0, "start": 1}
	body: list[str] = []

	def close(end: int):
		text = "\n".join(body)
		if text.strip() or current["lvl"] > 0:
			counts: dict[str, int] = {}
			for w in words(text):
				counts[w] = counts.get(w, 0) + 1
			sections.append(
				{
					"h": current["h"],
					"lvl": current["lvl"],
					"start": current["start"],
					"end": end,
					"bytes": len(text.encode("utf-8")),
					"hw": sorted(set(words(current["h"]))),
					"tf": counts,
				}
			)

	for i, line in enumerate(lines, 1):
		if line.lstrip().startswith("```"):
			fence = not fence
		m = None if fence else HEADING.match(line)
		if m:
			close(i - 1)
			current = {"h": m.group(2), "lvl": len(m.group(1)), "start": i}
			body = []
		else:
			body.append(line)
		for target in MD_LINK.findall(line):
			if target.startswith("http"):
				continue
			links.add(os.path.normpath(os.path.join(os.path.dirname(path), unquote(target))))
		for target in WIKI_LINK.findall(line):
			for hit in by_name.get(target.strip().lower(), [])[:1]:
				links.add(hit)
	close(len(lines))
	return {"bytes": os.path.getsize(path), "mtime": os.path.getmtime(path), "sections": sections, "links": sorted(links)}


def build(force: bool = False) -> dict:
	paths = notes()
	stamp = max((os.path.getmtime(p) for p in paths), default=0)
	if not force and os.path.exists(CACHE):
		with open(CACHE, encoding="utf-8") as f:
			cached = json.load(f)
		if cached.get("version") == VERSION and cached.get("stamp") == stamp and cached.get("count") == len(paths):
			return cached
	by_name: dict[str, list[str]] = {}
	for p in paths:
		by_name.setdefault(os.path.splitext(os.path.basename(p))[0].lower(), []).append(p)
	data: dict[str, dict] = {}
	broken: dict[str, list[str]] = {}
	for p in paths:
		note = parse(p, by_name)
		good = []
		for target in note["links"]:
			if os.path.exists(target):
				if target.endswith(".md") and target in by_name.get(os.path.splitext(os.path.basename(target))[0].lower(), []):
					good.append(rel(target))
			else:
				broken.setdefault(rel(p), []).append(os.path.relpath(target, VAULT).replace("\\", "/"))
		note["links"] = good
		data[rel(p)] = note
	backlinks: dict[str, list[str]] = {k: [] for k in data}
	for k, note in data.items():
		for t in note["links"]:
			if t in backlinks and t != k:
				backlinks[t].append(k)
	df: dict[str, int] = {}
	for note in data.values():
		for s in note["sections"]:
			for w in s["tf"]:
				df[w] = df.get(w, 0) + 1
	out = {
		"version": VERSION,
		"stamp": stamp,
		"count": len(paths),
		"notes": data,
		"backlinks": backlinks,
		"broken": broken,
		"df": df,
		"sections": sum(len(n["sections"]) for n in data.values()),
	}
	os.makedirs(os.path.dirname(CACHE), exist_ok=True)
	with open(CACHE, "w", encoding="utf-8") as f:
		json.dump(out, f)
	return out


def kb(n: int) -> str:
	return f"{n / 1024:.0f} KB" if n >= 1024 else f"{n} B"


def snippet(note: str, start: int, end: int, terms: list[str]) -> str:
	try:
		with open(os.path.join(VAULT, note), encoding="utf-8", errors="replace") as f:
			lines = f.read().split("\n")[start - 1 : end]
	except OSError:
		return ""
	best, best_n = "", 0
	for line in lines:
		ws = set(words(line))
		n = sum(1 for t in terms if t in ws)
		if n > best_n:
			best, best_n = line.strip(), n
	return (best[:140] + "…") if len(best) > 140 else best


def find(m: dict, query: str, limit: int = 8):
	terms = list(dict.fromkeys(words(query)))
	if not terms:
		print("no search words")
		return
	total = m["sections"]
	idf = {t: math.log(1 + total / (1 + m["df"].get(t, 0))) for t in terms}
	scored = []
	for path, note in m["notes"].items():
		title = set(words(os.path.splitext(os.path.basename(path))[0]))
		superseded = "archive" in path.lower() or "superseded" in path.lower()
		for s in note["sections"]:
			hw = set(s["hw"])
			score, hit = 0.0, 0
			for t in terms:
				tf = s["tf"].get(t, 0)
				part = (3 if t in hw else 0) + (2 if t in title else 0) + min(math.log1p(tf) * 1.4, 4)
				if part > 0:
					hit += 1
					score += part * idf[t]
			if hit == 0:
				continue
			score *= (hit / len(terms)) ** 2
			score /= 1 + max(s["bytes"] - 6000, 0) / 30000  # a huge section is a poor read
			if superseded:
				score *= 0.5
			scored.append((score, path, s))
	scored.sort(key=lambda x: -x[0])
	if not scored:
		print("no match; try other words or grep vault/INDEX.md")
		return
	seen_notes: list[str] = []
	for score, path, s in scored[:limit]:
		span = s["end"] - s["start"] + 1
		print(f"{path}:{s['start']}-{s['end']}  ({span} lines, {kb(s['bytes'])}, note {kb(m['notes'][path]['bytes'])})  {'#' * s['lvl']} {s['h']}")
		snip = snippet(path, s["start"], s["end"], terms)
		if snip:
			print(f"    {snip}")
		if path not in seen_notes:
			seen_notes.append(path)
	top = seen_notes[0]
	near = related_list(m, top)[:5]
	if near:
		print(f"linked to {top}: " + "; ".join(near))


def related_list(m: dict, path: str) -> list[str]:
	note = m["notes"].get(path)
	if not note:
		return []
	out = set(note["links"])
	back = set(m["backlinks"].get(path, []))
	both = [p for p in out & back]
	return [f"{p} (both ways)" for p in sorted(both)] + sorted(out - back) + [f"{p} (links here)" for p in sorted(back - out)]


def resolve(m: dict, name: str) -> str | None:
	name = name.replace("\\", "/").removeprefix("vault/")
	if name in m["notes"]:
		return name
	low = name.lower().removesuffix(".md")
	hits = [p for p in m["notes"] if os.path.splitext(os.path.basename(p))[0].lower() == low] or [
		p for p in m["notes"] if low in p.lower()
	]
	if len(hits) > 1:
		print("several notes match: " + "; ".join(hits[:8]))
	return hits[0] if hits else None


def outline(m: dict, name: str):
	path = resolve(m, name)
	if not path:
		print("no such note")
		return
	note = m["notes"][path]
	print(f"{path}  ({kb(note['bytes'])}{', read by section' if note['bytes'] > BIG else ''})")
	for s in note["sections"]:
		print(f"  {s['start']}-{s['end']}  {kb(s['bytes']):>6}  {'  ' * max(s['lvl'] - 1, 0)}{'#' * s['lvl']} {s['h']}")
	near = related_list(m, path)
	if near:
		print("links: " + "; ".join(near))


def health(m: dict):
	notes_ = m["notes"]
	try:
		with open(os.path.join(VAULT, "INDEX.md"), encoding="utf-8") as f:
			index = unquote(f.read())
	except OSError:
		index = ""
	big = sorted(((n["bytes"], p) for p, n in notes_.items() if n["bytes"] > BIG), reverse=True)
	huge_sections = sorted(
		((s["bytes"], p, s) for p, n in notes_.items() for s in n["sections"] if s["bytes"] > BIG), key=lambda x: -x[0]
	)
	orphans = [
		p
		for p in notes_
		if not m["backlinks"].get(p) and p not in index and p not in ("INDEX.md", "00 Home.md")
		and "Daily Log" not in p
	]
	print(f"{len(notes_)} project notes, {m['sections']} sections, {kb(sum(n['bytes'] for n in notes_.values()))} of text")
	print(f"{len(big)} notes over 15 KB (read by section); biggest: " + "; ".join(f"{p} {kb(b)}" for b, p in big[:6]))
	print(f"{len(huge_sections)} single sections over 15 KB (no heading to jump to; worth splitting):")
	for b, p, s in huge_sections[:10]:
		print(f"  {p}:{s['start']}-{s['end']}  {kb(b)}  {s['h']}")
	n_broken = sum(len(v) for v in m["broken"].values())
	print(f"{n_broken} broken links in {len(m['broken'])} notes" + (":" if n_broken else ""))
	for p, targets in list(m["broken"].items())[:10]:
		print(f"  {p} -> " + "; ".join(sorted(set(targets))[:3]))
	print(f"{len(orphans)} notes nothing links to and INDEX misses:")
	for p in orphans[:15]:
		print(f"  {p}")


def main():
	if hasattr(sys.stdout, "reconfigure"):
		sys.stdout.reconfigure(encoding="utf-8")
	args = sys.argv[1:]
	if not args or args[0] in ("-h", "--help"):
		print(__doc__)
		return
	cmd, rest = args[0], args[1:]
	m = build(force=(cmd == "rebuild"))
	if cmd == "find":
		limit = 8
		if rest and rest[0].startswith("-n"):
			limit, rest = int(rest[0][2:] or rest[1]), rest[1:] if rest[0][2:] else rest[2:]
		find(m, " ".join(rest), limit)
	elif cmd == "outline":
		outline(m, " ".join(rest))
	elif cmd == "related":
		path = resolve(m, " ".join(rest))
		print("\n".join(related_list(m, path)) if path else "no such note")
	elif cmd == "health":
		health(m)
	elif cmd == "rebuild":
		print(f"rebuilt: {m['count']} notes, {m['sections']} sections")
	else:
		print(__doc__)


if __name__ == "__main__":
	main()
