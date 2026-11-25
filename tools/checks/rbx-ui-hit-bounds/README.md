---
name: rbx-ui-hit-bounds
description: Find controls that leave a safe area or collide with another target for Roblox development using captured measurements or traces.
---

# Find controls that leave a safe area or collide with another target

Read actual pixel rectangles for interactive buttons after layout at the tested viewport. Use visible target bounds and supply the screen safe-area rectangle. Include every active sibling that might intercept the same tap.

Copy [the working input fixture](references/example.json) and replace the example values with your capture. Run this command from the installed skill directory or point Python at the script.

```text
python scripts/check.py path/to/capture.json
```

Fix the smallest or clipped control and repeat after rotating or changing viewport. Intersections between intentional nested elements should be omitted or listed as one active target.
