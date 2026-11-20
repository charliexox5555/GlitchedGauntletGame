---
name: rbx-vfx-screen-overlap
description: Measure how much of a critical target an effect covers on screen for Roblox development using captured measurements or traces.
---

# Measure how much of a critical target an effect covers on screen

From a matched gameplay frame, measure a target screen rectangle and tight rectangles around obstructive effect regions in the same pixel space. Exclude negligible wisps. Use several timestamps if obstruction is transient.

Copy [the working input fixture](references/example.json) and replace the example values with your capture. Run this command from the installed skill directory or point Python at the script.

```text
python scripts/check.py path/to/capture.json
```

The union calculation avoids double-counting overlapping bounds. Move dense regions or reduce scale near the worst frame. Bounds give a conservative proxy if the supplied rectangles include transparent space.
