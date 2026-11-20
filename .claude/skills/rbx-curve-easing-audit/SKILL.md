---
name: rbx-curve-easing-audit
description: Check sampled animation easing for hard edges, overshoot, and abrupt speed changes for Roblox development using captured measurements or traces.
---

# Check sampled animation easing for hard edges, overshoot, and abrupt speed changes

Sample a channel at a consistent cadence through one intended move or settle, using unwrapped rotation degrees for angular channels. Enter the allowed value range, expected maximum entry and exit speed, and an acceleration limit in units per second squared. Measure handles by their evaluated motion.

Copy [the working input fixture](references/example.json) and replace the example values with your capture. Run this command from the installed skill directory or point Python at the script.

```text
python scripts/check.py path/to/capture.json
```

A high endpoint speed means the transition is still moving at the cut. Localized acceleration spikes often point to a tangent or uneven spacing. Set intentional overshoot in the allowed range. Inspect the edit at full speed before flattening curves.

Optional checks (added 2026-11-21, first-person melee pass): `"hold": {"min_speed": 4, "max_seconds": 0.3, "window": [t0, t1]}` fails a stretch slower than `min_speed` for longer than `max_seconds` (a staged, frozen hold; the feel checklist's 4 deg/s for 0.3 s). `"contact": {"time": 0.168, "tolerance": 0.02, "min_share": 0.85}` fails when the fastest moment is more than `tolerance` from the contact or the contact runs under `min_share` of peak speed (a wind-up faster than the strike). For a deliberate snap, set `max_acceleration` from the measured strike and judge the snap with `contact` instead: the plain acceleration limit flags every intended strike.
