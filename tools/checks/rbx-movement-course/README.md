---
name: rbx-movement-course
description: Measure motion feel with repeatable course splits and stopping distances for Roblox development using captured measurements or traces.
---

# Measure motion feel with repeatable course splits and stopping distances

In the same test lane and control mode, time acceleration, traversal, and landing at named checkpoints. Measure distance from releasing the input to stopping. Record each segment as a row with min, max, and actual in the row's named unit.

Copy [the working input fixture](references/example.json) and replace the example values with your capture. Run this command from the installed skill directory or point Python at the script.

```text
python scripts/check.py path/to/capture.json
```

Use target bands agreed for the game. A clean time with excessive stopping distance signals a braking or traction concern. Compare the same lane before and after tuning and keep separate cases for touch or gamepad if applicable.
