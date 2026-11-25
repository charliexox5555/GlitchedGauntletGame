"""Measured checks for every third-person clip, through the rbx-* checkers
(tools/checks/rbx-*/scripts/check.py), on the rig in tp_rig.py (the same
poses tp_clips bakes and uploads; the rig matches the engine to 0.001 studs,
Third Person Overhaul §4; tools/studio captures confirm it per pass).

    python -I tools/anim/tp_measure.py                 # every clip, one table
    python -I tools/anim/tp_measure.py RunF Reload     # some clips
    python -I tools/anim/tp_measure.py --json DIR ...  # also keep each checker input

Per clip, the effectors (both hands, both feet, the head) are sampled at 60 Hz:
    seam    loops: rbx-animation-loop-seam on the five effectors (pose gap
            <= 0.04 studs, velocity gap <= 1.5 studs/s)
    ease    rbx-curve-easing-audit on each effector axis; the worst axis is
            reported. A pop is a one-frame velocity change, so the limit is an
            acceleration (studs/s^2, ACCEL_LIMIT) measured over KEY_SPAN, not
            over one 60 Hz pair (the clips are keyed at 30 Hz and played back
            linearly between keys, so a pair-wise acceleration reads every key
            as a spike; see the rbx-curve-easing-audit change note)
    plant   ground clips: rbx-foot-plant-drift on each planted interval, in
            ground space (the body's travel added back)
    rate    ground clips: rbx-locomotion-rate-fit, stride over the cycle
            against the Config speed the clip is played at
"""

import json
import os
import subprocess
import sys
import tempfile

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))

import tp_clips  # noqa: E402
from tp_check import PLANTED, sole_corners  # noqa: E402
from tp_rig import FLOOR, fk  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SKILLS = os.path.join(ROOT, "tools", "checks")
FPS = 60
KEY_SPAN = 2 / 60  # acceleration measured across one 30 Hz key
ACCEL_LIMIT = 900.0  # studs/s^2 over KEY_SPAN: about a 0.5 stud/frame velocity change at 60 Hz
ENDS = ("RightHand", "LeftHand", "RightFoot", "LeftFoot", "Head")


def run(skill, data, keep=None, tag=""):
	path = None
	with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8") as f:
		json.dump(data, f)
		path = f.name
	if keep:
		os.makedirs(keep, exist_ok=True)
		with open(os.path.join(keep, "%s_%s.json" % (tag, skill)), "w", encoding="utf-8") as g:
			json.dump(data, g, indent=1)
	script = os.path.join(SKILLS, skill, "scripts", "check.py")
	out = subprocess.run([sys.executable, "-I", script, path], capture_output=True, text=True)
	os.unlink(path)
	lines = (out.stdout + out.stderr).strip().splitlines()
	return out.returncode, lines


def sample(clip):
	n = max(4, round(clip.length * FPS))
	times = [clip.length * i / n for i in range(n + 1)]
	frames = [fk(tp_clips.full_pose(clip, t)) for t in times]
	return times, frames


def pos(frame, part):
	return [float(x) for x in frame[part][:3, 3]]


def seam(clip, times, frames, keep):
	dt = times[1] - times[0]
	joints = []
	inner = {}
	for p in ENDS:
		x = np.array([pos(f, p) for f in frames])
		v = np.diff(x, axis=0) / dt
		inner[p] = float(np.linalg.norm(np.diff(v, axis=0), axis=1).max()) if len(v) > 2 else 0.0
	# A gait puts the right foot's landing on the loop point, so its own
	# interior never holds a landing; the left foot's (mid-cycle) is the same
	# event. Feet and hands are compared against the pair's larger interior.
	for a, b in (("RightFoot", "LeftFoot"), ("RightHand", "LeftHand")):
		inner[a] = inner[b] = max(inner[a], inner[b])
	for p in ENDS:
		interior = inner[p]
		joints.append(
			{
				"id": p,
				"start": pos(frames[0], p),
				"after_start": pos(frames[1], p),
				"before_end": pos(frames[-2], p),
				"end": pos(frames[-1], p),
				"interior_velocity_jump": interior,
			}
		)
	# A pose gap is only small next to the clip's own frame steps: a breathing
	# hold moves 0.0005 studs a frame, so a fixed 0.04 hid a 0.004 wrap step
	# (2026-11-20). Limit: three of the clip's largest steps, at most 0.04.
	step = max(float(np.linalg.norm(np.diff(np.array([pos(f, p) for f in frames]), axis=0), axis=1).max()) for p in ENDS)
	gap = min(0.04, max(0.0005, 3 * step))
	code, lines = run("rbx-animation-loop-seam", {"dt": dt, "max_pose_gap": gap, "max_velocity_gap": 1.5, "joints": joints}, keep, clip.name)
	return code, lines


def ease(clip, times, frames, keep):
	"""The worst effector axis: largest acceleration over KEY_SPAN."""
	step = max(1, round(KEY_SPAN * FPS))
	worst = (0.0, None, None)
	for p in ENDS:
		track = np.array([pos(f, p) for f in frames])
		for axis in range(3):
			values = track[::step, axis]
			ts = times[::step]
			if len(values) < 4:
				continue
			v = np.diff(values) / np.diff(ts)
			a = np.abs(np.diff(v)) / np.diff(ts)[1:]
			peak = float(a.max()) if len(a) else 0.0
			if peak > worst[0]:
				worst = (peak, p, axis, values, ts)
	if worst[1] is None:
		return 0, ["static"], 0.0, ""
	peak, p, axis, values, ts = worst
	data = {
		"range": [float(values.min()) - 1, float(values.max()) + 1],
		"max_entry_speed": 1e9,  # clips start and end moving on purpose (they blend)
		"max_exit_speed": 1e9,
		"max_acceleration": ACCEL_LIMIT,
		"samples": [{"time": float(t), "value": float(x)} for t, x in zip(ts, values)],
	}
	code, lines = run("rbx-curve-easing-audit", data, keep, clip.name)
	return code, lines, peak, "%s.%s" % (p, "xyz"[axis])


def plants(clip, times, frames, travel, keep):
	"""Integrated slip per planted interval (see the rbx-foot-plant-drift note
	on feet that roll heel to toe): the corner in contact at one frame, how
	far that same corner moved over the ground by the next."""
	ground = np.array([travel[0], 0, travel[1]])
	intervals = []
	dt = times[1] - times[0]
	for side in ("Right", "Left"):
		corners = [sole_corners(w, side) for w in frames]
		lows = [min(c[1] for c in cs) + FLOOR for cs in corners]
		run_, at = [], None
		for i in range(len(frames) - 1):
			if lows[i] < PLANTED and lows[i + 1] < PLANTED:
				k = min(range(4), key=lambda j: corners[i][j][1])
				# Over the ground only; the height is the contact's own (sink / hover),
				# not the rolled-off corner rising.
				step = np.array(corners[i + 1][k]) - np.array(corners[i][k]) + ground * dt
				step[1] = 0
				if not run_:
					at = times[i]
					run_ = [np.array([corners[i][k][0], lows[i], corners[i][k][2]])]
				nxt = run_[-1] + step
				nxt[1] = lows[i + 1]
				run_.append(nxt)
			elif run_:
				if len(run_) >= 3:
					intervals.append({"id": "%s/%s@%.2f" % (clip.name, side, at), "positions": [[float(x) for x in p] for p in run_]})
				run_ = []
		if len(run_) >= 3:
			intervals.append({"id": "%s/%s@%.2f" % (clip.name, side, at), "positions": [[float(x) for x in p] for p in run_]})
	if not intervals:
		return 0, ["no plant"]
	return run("rbx-foot-plant-drift", {"max_horizontal": 0.12, "max_vertical": 0.04, "plants": intervals}, keep, clip.name)


def rate(clip, travel, keep):
	speed = float(np.hypot(*travel))
	data = {
		"cycle_distance": speed * clip.length,
		"cycle_seconds": clip.length,
		"root_drift": 0.0,
		"max_root_drift": 0.04,
		"max_rate_error": 0.08,
		"samples": [{"id": "authored", "speed": speed, "rate": 1.0}],
	}
	return run("rbx-locomotion-rate-fit", data, keep, clip.name)


def fails(lines):
	return [line[6:] for line in lines if line.startswith("FAIL")]


def main():
	args = sys.argv[1:]
	keep = None
	if args[:1] == ["--json"]:
		keep, args = args[1], args[2:]
	names = args or list(tp_clips.CLIPS)
	print("%-18s %-26s %-10s %-22s %s" % ("clip", "seam", "accel", "worst", "plant / rate"))
	for name in names:
		clip = tp_clips.CLIPS[name]
		times, frames = sample(clip)
		seam_txt = "-"
		if clip.loop:
			code, lines = seam(clip, times, frames, keep)
			seam_txt = "pass" if code == 0 else "; ".join(fails(lines))[:26]
		code, lines, peak, where = ease(clip, times, frames, keep)
		accel = "%.0f%s" % (peak, "" if code == 0 else "!")
		extra = ""
		travel = tp_clips.GROUND.get(name)
		if travel is not None:
			pc, pl = plants(clip, times, frames, travel, keep)
			rc, rl = rate(clip, travel, keep)
			worst = [line for line in pl if "excursion" in line.lower() or "max" in line.lower()]
			extra = ("plant pass" if pc == 0 else "plant %d fail" % len(fails(pl))) + (" / rate pass" if rc == 0 else " / rate fail")
			if pc != 0:
				extra += " (" + "; ".join(fails(pl))[:60] + ")"
		print("%-18s %-26s %-10s %-22s %s" % (name, seam_txt, accel, where, extra))


if __name__ == "__main__":
	main()
