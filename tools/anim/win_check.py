"""Clipping check for the win cutscene clips (vault/02 Art/Win Cutscene.md),
2026-11-20, after the owner: "the way the hands are kind of turned, and a
lot of times they clip through the body".

Every 60 Hz frame of a clip, each arm block (upper arm, forearm, hand) and
the gun are tested against the body blocks they must not pass through
(torso, hips, head, legs, the other arm) as oriented boxes (separating axis
test) on the R15 block body's sizes; the depth is how far they overlap
(studs, along the axis of least overlap). Neighbours on a joint are skipped.
Also reports the wrist turn: the angle between the forearm and the hand
(the rigid fist follows the gun, so a big turn reads as a twisted wrist).

    python tools/anim/win_check.py Win1_1 [Win2_1 ...] [--all] [--limit=0.08]
"""

import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))

import win_clips  # noqa: E402,F401  (registers the clips)
import tp_clips  # noqa: E402
from tp_rig import fk  # noqa: E402
from win_geom import frame_hits, wrist  # noqa: E402,F401

def check(name, limit, show_all=False):
	clip = tp_clips.CLIPS[name]
	n = max(1, round(clip.length * 60))
	worst = {}
	spans = []
	cur = None
	max_wrist = (0.0, 0.0, "")
	for i in range(n + 1):
		t = clip.length * i / n
		w = fk(clip.pose(t))
		bad = [h for h in frame_hits(w) if h[2] > limit]
		for p, q, dep in bad:
			k = (p, q)
			if dep > worst.get(k, (0, 0))[0]:
				worst[k] = (dep, t)
		for side in ("Right", "Left"):
			a = wrist(w, side)
			if a > max_wrist[0]:
				max_wrist = (a, t, side)
		if bad and cur is None:
			cur = [t, t]
		elif bad:
			cur[1] = t
		elif cur is not None:
			spans.append(tuple(cur))
			cur = None
	if cur is not None:
		spans.append(tuple(cur))
	print("%s: %d clipping spans, worst wrist %.0f deg (%s at %.2f)" % (name, len(spans), max_wrist[0], max_wrist[2], max_wrist[1]))
	for s in spans:
		print("   %.2f-%.2f" % s)
	for (p, q), (dep, t) in sorted(worst.items(), key=lambda kv: -kv[1][0])[: (99 if show_all else 12)]:
		print("   %-14s in %-14s %.2f studs at %.2f" % (p, q, dep, t))
	return spans, worst


def main():
	limit = 0.08
	show_all = False
	names = []
	for a in sys.argv[1:]:
		if a.startswith("--limit="):
			limit = float(a[8:])
		elif a == "--all":
			show_all = True
		else:
			names.append(a)
	for name in names or win_clips.WIN:
		check(name, limit, show_all)


if __name__ == "__main__":
	main()
