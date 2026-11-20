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
