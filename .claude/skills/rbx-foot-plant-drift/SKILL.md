---
name: rbx-foot-plant-drift
description: Measure foot sliding during an intended planted interval for Roblox development using captured measurements or traces.
---

# Measure foot sliding during an intended planted interval

On the actual animated rig, mark contact intervals from the first frame of planted contact to the last. Sample heel or foot marker positions in world space every few frames. Use platform-relative space on moving ground.

Copy [the working input fixture](references/example.json) and replace the example values with your capture. Run this command from the installed skill directory or point Python at the script.

```text
python scripts/check.py path/to/capture.json
```

The report gives maximum excursion from the first planted position and vertical bob. Retest the same intervals after tuning pose, stride, or IK. Include at least one interior sample to catch drift that returns by the last frame.
