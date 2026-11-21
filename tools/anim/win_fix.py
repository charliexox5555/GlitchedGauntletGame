"""Clears the win cutscene keys of clipping (vault/02 Art/Win Cutscene.md,
2026-11-20, owner: the hands look turned and often clip through the body).

For each key of a track, a small coordinate search moves only what the eye
won't miss:
    right arm   the gun's (pitch, yaw, roll, reach) about the shoulder: the
                rigid fist follows the gun, so this places the forearm, and
                the roll sets how far the forearm has to twist (the skinned
                forearm doesn't show twist, so a twisted one reads as a
                turned hand: `_twist_residual`)
    left arm    the fist target and the elbow pole
until no arm block or the gun sits more than ALLOW studs inside the torso,
hips, head, legs or the other arm (win_check's box test) and the wrist twist
is under TWIST degrees, staying as close to the authored key as it can.

The search is slow, so its result is cached per key in win_fix_cache.json
(keyed by the clip name, key index and the key's own values): editing a key
re-fixes only that key. `python tools/anim/win_clips.py fix Win1_1` refreshes.
"""

import hashlib
import json
import math
import os

import numpy as np

import tp_clips
from tp_rig import fk, solve
from win_geom import frame_hits

HERE = os.path.dirname(__file__)
CACHE = os.path.join(HERE, "win_fix_cache.json")
ALLOW = 0.1  # studs: blocks may kiss this much (the game's own rifle hold does)
TWIST = 20.0  # degrees of forearm twist before the hand reads as turned
LEFT = ("LeftUpperArm", "LeftLowerArm", "LeftHand")
RIGHT = ("RightUpperArm", "RightLowerArm", "RightHand", "Gun")

_cache = None


def _load():
	global _cache
	if _cache is None:
		try:
			with open(CACHE, encoding="utf-8") as f:
				_cache = json.load(f)
		except (OSError, ValueError):
			_cache = {}
	return _cache


def _save():
	with open(CACHE, "w", encoding="utf-8", newline="\n") as f:
		json.dump(_cache, f, indent=1, sort_keys=True)


def _sig(ctrl):
	def plain(v):
		if isinstance(v, np.ndarray):
			return [round(float(x), 4) for x in v.flatten()]
		if isinstance(v, dict):
			return {k: plain(v[k]) for k in sorted(v)}
		if isinstance(v, (list, tuple)):
			return [plain(x) for x in v]
		if isinstance(v, float):
			return round(v, 4)
		return v

	return hashlib.sha1(json.dumps(plain(ctrl), sort_keys=True).encode()).hexdigest()[:16]


def _cost(ctrl, side):
	c = dict(ctrl)
	pose = solve(c)
	world = fk(pose)
	hits = frame_hits(world)
	group = RIGHT if side == "right" else LEFT
	depth = 0.0
	for p, q, d in hits:
		if d <= ALLOW:
			continue
		if p in group or q in group:
			depth += (d - ALLOW) * (2.0 if q == "Head" else 1.0)
	twist = c.get("_twist_residual", 0.0) if side == "right" else 0.0
	return depth, twist


def _gun_of(ctrl):
	g = ctrl["gun"]
	p, y, r = g["shoulder"]
	return [p, y, r, g.get("reach", 0.0)]


def _with_gun(ctrl, v):
	c = dict(ctrl)
	c["gun"] = {"shoulder": (v[0], v[1], v[2]), "reach": v[3]}
	return c


def _with_left(ctrl, tip, pole):
	c = dict(ctrl)
	c["left_arm"] = {"tip": tuple(tip)}
	c["left_pole"] = tuple(pole)
	return c


def _search(start, build, side, steps, scale, limit=40):
	"""Greedy coordinate descent on `start` (a list) to clear clipping."""
	cur = list(start)

	def score(v):
		depth, twist = _cost(build(v), side)
		move = sum(abs(a - b) / s for a, b, s in zip(v, start, scale))
		return 10.0 * depth + 0.05 * max(0.0, twist - TWIST) + 0.02 * move, depth, twist

	best = score(cur)
	if best[1] == 0 and best[2] <= TWIST:
		return cur, best
	for _ in range(limit):
		improved = False
		for i, step in enumerate(steps):
			if step == 0:
				continue
			for sgn in (1, -1):
				v = list(cur)
				v[i] += sgn * step
				s = score(v)
				if s[0] < best[0] - 1e-4:
					cur, best, improved = v, s, True
		if best[1] == 0 and best[2] <= TWIST:
			break
		if not improved:
			steps = [s / 2 for s in steps]
			if max(steps) < 0.01:
				break
	return cur, best


def fix_key(ctrl, fix_left=True):
	ctrl = dict(ctrl)
	# right arm: the gun
	if "gun" in ctrl and "shoulder" in ctrl["gun"]:
		v, _ = _search(_gun_of(ctrl), lambda g: _with_gun(ctrl, g), "right", [3.0, 4.0, 10.0, 0.08], [10, 10, 30, 0.3])
		ctrl = _with_gun(ctrl, v)
	# left arm: the fist target and pole
	if fix_left and "left_arm" in ctrl and "tip" in ctrl["left_arm"]:
		tip = list(ctrl["left_arm"]["tip"])
		pole = list(ctrl.get("left_pole", (-0.7, -1, 0.15)))

		def build(v):
			return _with_left(ctrl, v[:3], v[3:])

		v, _ = _search(tip + pole, build, "left", [0.08, 0.08, 0.08, 0.2, 0.2, 0.2], [0.3, 0.3, 0.3, 1, 1, 1])
		ctrl = build(v)
	return ctrl


def fixed(name, track, skip_left=(), refresh=False):
	"""The track with each key cleared (cached). `skip_left`: key times whose
	left hand is placed on the gun later (two_handed), left alone here."""
	cache = _load()
	out = []
	changed = False
	stale = 0
	for i, key in enumerate(track):
		t, ctrl = key[0], key[1]
		sig = "%s:%d:%s" % (name, i, _sig(ctrl))
		hit = cache.get(sig)
		if hit is not None and not refresh:
			c = dict(ctrl)
			c["gun"] = {"shoulder": tuple(hit["gun"][:3]), "reach": hit["gun"][3]}
			if "tip" in hit:
				c["left_arm"] = {"tip": tuple(hit["tip"])}
				c["left_pole"] = tuple(hit["pole"])
			out.append((t, c) + tuple(key[2:]))
			continue
		if not refresh and os.environ.get("WIN_FIX") != "1":
			stale += 1
			out.append(key)
			continue
		left = not any(abs(t - s) < 1e-6 for s in skip_left)
		c = fix_key(ctrl, fix_left=left)
		entry = {"gun": list(_gun_of(c))}
		if left and "tip" in c.get("left_arm", {}):
			entry["tip"] = list(c["left_arm"]["tip"])
			entry["pole"] = list(c["left_pole"])
		cache[sig] = entry
		changed = True
		out.append((t, c) + tuple(key[2:]))
	if changed:
		_save()
	if stale:
		print("[win_fix] %s: %d keys not cleared yet (run: win_clips.py fix %s)" % (name, stale, name))
	return out


def report(name, before, after):
	for (t, a), (_, b) in zip(before, after):
		ga, gb = _gun_of(a), _gun_of(b)
		ta = a.get("left_arm", {}).get("tip")
		tb = b.get("left_arm", {}).get("tip")
		moved = []
		if any(abs(x - y) > 1e-3 for x, y in zip(ga, gb)):
			moved.append("gun %s -> %s" % ([round(x, 1) for x in ga], [round(x, 2) for x in gb]))
		if ta and tb and any(abs(x - y) > 1e-3 for x, y in zip(ta, tb)):
			moved.append("tip %s -> %s" % ([round(x, 2) for x in ta], [round(x, 2) for x in tb]))
		if moved:
			print("  %.2f  %s" % (t, "; ".join(moved)))
	return math.nan
