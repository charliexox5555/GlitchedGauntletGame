---
name: rbx-animation-layer-conflicts
description: Find unintended joints claimed by simultaneous animation layers for Roblox development using captured measurements or traces.
---

# Find unintended joints claimed by simultaneous animation layers

Record active clip windows, controlled channel names, and priority rank on the tested rig. Give a unique track label to each actual playing clip. Explicitly list planned blends as track pairs.

Copy [the working input fixture](references/example.json) and replace the example values with your capture. Run this command from the installed skill directory or point Python at the script.

```text
python scripts/check.py path/to/capture.json
```

A same-rank overlap can cause competing weights. A higher-rank overlap can replace or attenuate the expected layer. The tool flags overlapping ownership, not a prediction of all runtime weighting. Check the actual blend and trim unnecessary keyed joints.
