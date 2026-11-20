---
name: rbx-animation-loop-seam
description: Measure pose and velocity jumps at an animation loop seam for Roblox development using captured measurements or traces.
---

# Measure pose and velocity jumps at an animation loop seam

For key bones or end effectors, sample positions just after the start, at the start, just before the end, and at the end. Convert positions into the intended loop space. Use cycle-relative root motion where locomotion intentionally translates.

Copy [the working input fixture](references/example.json) and replace the example values with your capture. Run this command from the installed skill directory or point Python at the script.

```text
python scripts/check.py path/to/capture.json
```

The checker compares the endpoint pose and incoming versus outgoing velocity. Fix the interpolation when the pose matches but the velocity pops. Playback at full speed and check rotations visually for joints whose endpoint does not move.

**Fast effectors (added 2026-11-20, GlitchedGauntletGame TP lane).** A running foot changes velocity by several studs/s between any two frames, so a fixed `max_velocity_gap` flags every locomotion loop. Give each joint `interior_velocity_jump` (the largest frame-to-frame velocity change inside the cycle, same `dt`): the limit becomes the larger of `max_velocity_gap` and that baseline × `interior_margin` (default 1.25). A seam is then a pop only when it is rougher than the clip itself. Measured on our RunF: foot seam 5.5 studs/s against 9.6 inside the cycle (clean), so the old rule was a false alarm. `tools/anim/tp_measure.py` fills the field. When a cycle puts an event on the loop point (a gait's right-foot landing at phase 0), that effector's own interior never contains the event; use the mirrored effector's interior (the left foot lands mid-cycle) or the larger of the pair. Our CrouchWalk: right foot 13.7 at the seam, left foot's landing 12.3 inside, so it is the landing, not a seam.
