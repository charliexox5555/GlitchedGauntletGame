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
