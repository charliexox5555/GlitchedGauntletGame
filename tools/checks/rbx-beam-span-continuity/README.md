---
name: rbx-beam-span-continuity
description: Find gaps or width pops between visible Beam segments for Roblox development using captured measurements or traces.
---

# Find gaps or width pops between visible Beam segments

At a representative animation frame, measure neighboring endpoint positions and visible widths in studs. Supply the allowed positional gap and relative width step. List adjacent segments in travel order.

Copy [the working input fixture](references/example.json) and replace the example values with your capture. Run this command from the installed skill directory or point Python at the script.

```text
python scripts/check.py path/to/capture.json
```

Fix the attachment gap or width transition at the exact segment join. Replay with the actual texture and animation. This endpoint check does not measure texture phase or curve tangency.
